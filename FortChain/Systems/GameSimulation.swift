import CoreGraphics
import Foundation

@MainActor
final class GameSimulation {
    private(set) var phase: GamePhase = .ready
    private(set) var buildings: [UUID: BuildingState] = [:]
    private(set) var enemies: [UUID: EnemyState] = [:]
    private(set) var drones: [UUID: DroneState] = [:]
    private(set) var projectiles: [UUID: ProjectileState] = [:]
    private(set) var selectedBuildingID: UUID?

    private var baseID = UUID()
    private var connectedHubIDs: Set<UUID> = []
    private var alerts: [AlertState] = []
    private var alertCooldowns: [String: CGFloat] = [:]

    private var activeWaveIndex: Int?
    private var activeWaveElapsed: CGFloat = 0
    private var nextSpawnIndex = 0
    private var completedWaves = 0
    private var countdownUntilNextWave: CGFloat?

    init() {
        reset()
    }

    var selectedBuildingState: BuildingState? {
        guard let selectedBuildingID, let building = buildings[selectedBuildingID] else { return nil }
        return building
    }

    func reset() {
        phase = .ready
        buildings.removeAll()
        enemies.removeAll()
        drones.removeAll()
        projectiles.removeAll()
        selectedBuildingID = nil
        alerts.removeAll()
        alertCooldowns.removeAll()
        connectedHubIDs.removeAll()
        activeWaveIndex = nil
        activeWaveElapsed = 0
        nextSpawnIndex = 0
        completedWaves = 0
        countdownUntilNextWave = GameConfig.openingCountdown

        baseID = addBuilding(
            kind: .core,
            coordinate: GameConfig.baseCoordinate,
            inventory: GameConfig.startingCoreInventory
        )

        _ = addBuilding(
            kind: .depot,
            coordinate: GameConfig.starterDepotCoordinate,
            inventory: GameConfig.starterDepotInventory
        )

        _ = addBuilding(
            kind: .generator,
            coordinate: GameConfig.starterGeneratorCoordinate
        )

        _ = addBuilding(
            kind: .gunTower,
            coordinate: GameConfig.starterTowerCoordinate,
            inventory: GameConfig.starterTowerInventory
        )

        recalculateConnectivity()
        updateBuildingStatuses()
        postAlert("Mission ready. Launch when your supply chain is set.", key: "boot", cooldown: 0)
    }

    func start() {
        guard phase == .ready else { return }
        phase = .playing
        countdownUntilNextWave = GameConfig.waves.first?.prepTime ?? GameConfig.openingCountdown
        postAlert("Deployment live. First wave clock started.", key: "start", cooldown: 0)
    }

    func update(dt: CGFloat) {
        tickAlerts(dt: dt)
        guard phase == .playing else { return }

        recalculateConnectivity()
        updateWaveState(dt: dt)
        updateEnemies(dt: dt)
        updateDrones(dt: dt)
        updateBuildings(dt: dt)
        dispatchTransports()
        updateProjectiles(dt: dt)
        updateBuildingStatuses()
        evaluateEndState()
    }

    func clearSelection() {
        selectedBuildingID = nil
    }

    func selectBuilding(at coordinate: GridCoordinate) {
        selectedBuildingID = buildings.values.first(where: { $0.coordinate == coordinate })?.id
    }

    func placementCheck(for kind: BuildingKind, at coordinate: GridCoordinate) -> PlacementCheck {
        guard (0 ..< GameConfig.columns).contains(coordinate.x),
              (0 ..< GameConfig.rows).contains(coordinate.y) else {
            return PlacementCheck(isValid: false, message: "Outside build zone.")
        }

        if buildings.values.contains(where: { $0.coordinate == coordinate }) {
            return PlacementCheck(isValid: false, message: "Tile already occupied.")
        }

        if GameConfig.pathTiles.contains(coordinate) {
            return PlacementCheck(isValid: false, message: "Enemy lanes must stay open.")
        }

        let onNode = GameConfig.resourceNodes.contains(coordinate)
        if kind == .mine && !onNode {
            return PlacementCheck(isValid: false, message: "Mines only fit on ore nodes.")
        }

        if kind != .mine && onNode {
            return PlacementCheck(isValid: false, message: "Ore nodes are reserved for mines.")
        }

        let cost = GameConfig.catalog(for: kind).buildCost
        if !accessibleStockpile().canAfford(cost) {
            return PlacementCheck(isValid: false, message: "Supply shortfall. Build cost unavailable.")
        }

        if !isInBuildRadius(coordinate) {
            return PlacementCheck(isValid: false, message: "Expand with a connected depot first.")
        }

        return PlacementCheck(isValid: true, message: "Ready")
    }

    func placeBuilding(kind: BuildingKind, at coordinate: GridCoordinate) -> ActionResult {
        let check = placementCheck(for: kind, at: coordinate)
        guard check.isValid else {
            postAlert(check.message, key: "placement-denied", cooldown: 0.8)
            return ActionResult(success: false, message: check.message)
        }

        spendFromNetwork(GameConfig.catalog(for: kind).buildCost)
        let buildingID = addBuilding(kind: kind, coordinate: coordinate)
        selectedBuildingID = buildingID
        recalculateConnectivity()
        updateBuildingStatuses()

        let name = GameConfig.catalog(for: kind).name
        postAlert("\(name) deployed.", key: "place-\(kind.rawValue)", cooldown: 0.5)
        return ActionResult(success: true, message: "\(name) deployed.")
    }

    func upgradeSelectedBuilding() -> ActionResult {
        guard let selectedBuildingID, var building = buildings[selectedBuildingID] else {
            return ActionResult(success: false, message: "Select a structure first.")
        }

        guard let cost = GameConfig.upgradeCost(for: building) else {
            return ActionResult(success: false, message: "This structure is already maxed.")
        }

        guard accessibleStockpile().canAfford(cost) else {
            postAlert("Upgrade blocked. Supply chain cannot cover the cost.", key: "upgrade-cost", cooldown: 1.0)
            return ActionResult(success: false, message: "Supply chain cannot cover the upgrade cost.")
        }

        spendFromNetwork(cost)
        building.level += 1
        building.health = GameConfig.maxHealth(for: building.kind, level: building.level)
        buildings[selectedBuildingID] = building

        recalculateConnectivity()
        updateBuildingStatuses()
        postAlert("\(GameConfig.catalog(for: building.kind).name) upgraded to Mk \(building.level).", key: "upgrade-\(selectedBuildingID)", cooldown: 0.8)
        return ActionResult(success: true, message: "Upgrade complete.")
    }

    func snapshot() -> GameSnapshot {
        let base = buildings[baseID]
        return GameSnapshot(
            stockpile: accessibleStockpile(),
            phase: phase,
            completedWaves: completedWaves,
            totalWaves: GameConfig.waves.count,
            activeWaveNumber: activeWaveIndex.map { $0 + 1 },
            countdown: countdownUntilNextWave,
            baseHealth: base?.health ?? 0,
            baseMaxHealth: base.map { GameConfig.maxHealth(for: $0.kind, level: $0.level) } ?? 0,
            alertText: alerts.first?.text,
            selectedBuilding: selectedBuildingSnapshot()
        )
    }

    private func addBuilding(
        kind: BuildingKind,
        coordinate: GridCoordinate,
        level: Int = 1,
        inventory: ResourceStock = ResourceStock()
    ) -> UUID {
        let id = UUID()
        buildings[id] = BuildingState(
            id: id,
            kind: kind,
            coordinate: coordinate,
            health: GameConfig.maxHealth(for: kind, level: level),
            level: level,
            inventory: inventory,
            cooldownRemaining: 0,
            productionProgress: 0,
            connected: kind == .core,
            statusText: "Booting",
            statusSeverity: .stable
        )
        return id
    }

    private func updateWaveState(dt: CGFloat) {
        if let activeWaveIndex {
            activeWaveElapsed += dt
            let wave = GameConfig.waves[activeWaveIndex]

            while nextSpawnIndex < wave.spawns.count, wave.spawns[nextSpawnIndex].time <= activeWaveElapsed {
                spawnEnemy(wave.spawns[nextSpawnIndex])
                nextSpawnIndex += 1
            }

            if nextSpawnIndex >= wave.spawns.count, enemies.isEmpty {
                completedWaves += 1
                grantToBase(wave.reward)
                self.activeWaveIndex = nil
                activeWaveElapsed = 0
                nextSpawnIndex = 0

                if completedWaves >= GameConfig.waves.count {
                    phase = .won
                    postAlert("All waves cleared. Colony survived.", key: "victory", cooldown: 0)
                } else {
                    countdownUntilNextWave = GameConfig.waves[completedWaves].prepTime
                    postAlert("Wave \(completedWaves) cleared. Refit window open.", key: "wave-clear-\(completedWaves)", cooldown: 0)
                }
            }

            return
        }

        guard let countdownUntilNextWave else { return }
        self.countdownUntilNextWave = max(0, countdownUntilNextWave - dt)
        if self.countdownUntilNextWave == 0, completedWaves < GameConfig.waves.count {
            beginWave(index: completedWaves)
        }
    }

    private func beginWave(index: Int) {
        activeWaveIndex = index
        activeWaveElapsed = 0
        nextSpawnIndex = 0
        countdownUntilNextWave = nil
        postAlert("\(GameConfig.waves[index].name) incoming.", key: "wave-\(index)", cooldown: 0)
    }

    private func spawnEnemy(_ spawn: WaveSpawn) {
        let definition = GameConfig.enemyDefinition(for: spawn.kind)
        let id = UUID()
        enemies[id] = EnemyState(
            id: id,
            kind: spawn.kind,
            lane: spawn.lane,
            pathProgress: 0,
            health: definition.maxHealth
        )
    }

    private func updateEnemies(dt: CGFloat) {
        let enemyIDs = Array(enemies.keys)
        for enemyID in enemyIDs {
            guard var enemy = enemies[enemyID] else { continue }
            let definition = GameConfig.enemyDefinition(for: enemy.kind)
            enemy.pathProgress += definition.speed * dt
            let pathLength = laneLength(for: enemy.lane)

            if enemy.pathProgress >= pathLength {
                enemies.removeValue(forKey: enemyID)
                hitBase(with: enemy)
            } else {
                enemies[enemyID] = enemy
            }
        }
    }

    private func hitBase(with enemy: EnemyState) {
        guard var base = buildings[baseID] else { return }
        let definition = GameConfig.enemyDefinition(for: enemy.kind)
        base.health = max(0, base.health - definition.coreDamage)
        buildings[baseID] = base

        if enemy.kind == .saboteur {
            spendFromNetwork(GameConfig.saboteurDrain)
            postAlert("Saboteur pierced the lines and drained ammo + energy.", key: "sabotage", cooldown: 2.0)
        } else {
            postAlert("Base core hit for \(Int(definition.coreDamage)) damage.", key: "core-hit", cooldown: 1.5)
        }
    }

    private func updateDrones(dt: CGFloat) {
        let droneIDs = Array(drones.keys)
        for droneID in droneIDs {
            guard var drone = drones[droneID],
                  let source = buildings[drone.sourceID],
                  let destination = buildings[drone.destinationID] else {
                drones.removeValue(forKey: droneID)
                continue
            }

            let distance = max(0.25, source.coordinate.point.distance(to: destination.coordinate.point))
            drone.progress += (dt * drone.speed) / distance

            if drone.progress >= 1 {
                var updatedDestination = destination
                let capacity = GameConfig.storage(for: destination)[drone.resource]
                let accepted = min(drone.amount, max(0, capacity - updatedDestination.inventory[drone.resource]))

                updatedDestination.inventory[drone.resource] += accepted
                buildings[updatedDestination.id] = updatedDestination

                if accepted < drone.amount, var updatedSource = buildings[drone.sourceID] {
                    updatedSource.inventory[drone.resource] += (drone.amount - accepted)
                    buildings[updatedSource.id] = updatedSource
                    postAlert("\(GameConfig.catalog(for: updatedDestination.kind).name) storage is full.", key: "storage-\(updatedDestination.id)", cooldown: 2.0)
                }

                drones.removeValue(forKey: droneID)
            } else {
                drones[droneID] = drone
            }
        }
    }

    private func updateBuildings(dt: CGFloat) {
        let buildingIDs = Array(buildings.keys)
        for buildingID in buildingIDs {
            guard var building = buildings[buildingID] else { continue }

            building.cooldownRemaining = max(0, building.cooldownRemaining - dt)

            if !building.connected && building.kind != .core {
                building.statusText = "Out of network"
                building.statusSeverity = .critical
                buildings[buildingID] = building
                continue
            }

            switch building.kind {
            case .generator, .mine, .smelter, .ammoFactory:
                building = updateProduction(for: building, dt: dt)
            case .gunTower, .cannonTower:
                building = updateTower(for: building)
            case .core, .depot:
                break
            }

            clampInventory(&building)
            buildings[buildingID] = building
        }
    }

    private func updateProduction(for building: BuildingState, dt: CGFloat) -> BuildingState {
        guard let interval = GameConfig.productionInterval(for: building) else { return building }
        var building = building
        let storage = GameConfig.storage(for: building)

        switch building.kind {
        case .generator, .mine:
            let output = GameConfig.productionOutput(for: building)
            let resource = building.kind == .generator ? ResourceKind.energy : .ore
            if building.inventory[resource] >= storage[resource] {
                building.statusText = "Storage full"
                building.statusSeverity = .warning
                return building
            }

            building.productionProgress += dt
            while building.productionProgress >= interval {
                let amount = min(output[resource], storage[resource] - building.inventory[resource])
                guard amount > 0 else { break }
                building.inventory[resource] += amount
                building.productionProgress -= interval
            }

            building.statusText = building.kind == .generator ? "Charging cells" : "Extracting ore"
            building.statusSeverity = .stable
            return building

        case .smelter, .ammoFactory:
            let inputs = GameConfig.productionInput(for: building)
            let output = GameConfig.productionOutput(for: building)
            let outputKind: ResourceKind = building.kind == .smelter ? .alloy : .ammo

            guard building.inventory.canAfford(inputs) else {
                building.productionProgress = min(building.productionProgress, interval * 0.3)
                building.statusText = missingInputLabel(for: building)
                building.statusSeverity = .warning
                return building
            }

            guard building.inventory[outputKind] < storage[outputKind] else {
                building.statusText = "Output jammed"
                building.statusSeverity = .warning
                return building
            }

            building.productionProgress += dt
            while building.productionProgress >= interval,
                  building.inventory.canAfford(inputs),
                  building.inventory[outputKind] < storage[outputKind] {
                building.inventory.subtract(inputs)
                let amount = min(output[outputKind], storage[outputKind] - building.inventory[outputKind])
                building.inventory[outputKind] += amount
                building.productionProgress -= interval
            }

            building.statusText = building.kind == .smelter ? "Smelting alloy" : "Forging shells"
            building.statusSeverity = .stable
            return building

        default:
            return building
        }
    }

    private func updateTower(for building: BuildingState) -> BuildingState {
        var building = building
        let targetRange = GameConfig.range(for: building)
        let sourcePoint = building.coordinate.point
        let targets = enemies.values.filter { enemy in
            sourcePoint.distance(to: enemyPoint(for: enemy)) <= targetRange
        }

        guard let target = targets.max(by: { $0.pathProgress < $1.pathProgress }) else {
            building.statusText = "Watching lanes"
            building.statusSeverity = .stable
            return building
        }

        let shotCost = GameConfig.shotCost(for: building)
        guard building.inventory.canAfford(shotCost) else {
            building.statusText = missingAmmoLabel(for: building)
            building.statusSeverity = .critical
            postAlert("\(GameConfig.catalog(for: building.kind).name) is dry.", key: "tower-dry-\(building.id)", cooldown: 2.2)
            return building
        }

        guard building.cooldownRemaining <= 0 else {
            building.statusText = "Tracking target"
            building.statusSeverity = .stable
            return building
        }

        building.inventory.subtract(shotCost)
        building.cooldownRemaining = GameConfig.fireInterval(for: building)
        building.statusText = "Firing"
        building.statusSeverity = .stable

        let impactPoint = enemyPoint(for: target)
        let projectile = ProjectileState(
            id: UUID(),
            sourcePoint: sourcePoint,
            destinationPoint: impactPoint,
            ttl: 0.18,
            tintToken: building.kind == .gunTower ? .ammo : .energy
        )
        projectiles[projectile.id] = projectile

        if building.kind == .cannonTower {
            applySplashDamage(center: impactPoint, radius: GameConfig.splashRadius(for: building), damage: GameConfig.damage(for: building))
        } else {
            applyDamage(GameConfig.damage(for: building), to: target.id)
        }

        return building
    }

    private func applyDamage(_ damage: CGFloat, to enemyID: UUID) {
        guard var enemy = enemies[enemyID] else { return }
        enemy.health -= damage

        if enemy.health <= 0 {
            enemies.removeValue(forKey: enemyID)
            grantToBase(GameConfig.enemyDefinition(for: enemy.kind).reward)
        } else {
            enemies[enemyID] = enemy
        }
    }

    private func applySplashDamage(center: CGPoint, radius: CGFloat, damage: CGFloat) {
        let impactedEnemyIDs = enemies.values.compactMap { enemy -> UUID? in
            center.distance(to: enemyPoint(for: enemy)) <= radius ? enemy.id : nil
        }

        for enemyID in impactedEnemyIDs {
            applyDamage(damage, to: enemyID)
        }
    }

    private func dispatchTransports() {
        let maxDrones = connectedHubIDs.compactMap { buildings[$0] }.reduce(0) { $0 + GameConfig.transportCapacity(for: $1) }
        guard drones.count < maxDrones else { return }

        let consumers = buildings.values
            .filter { $0.connected }
            .sorted { lhs, rhs in
                transportPriority(for: lhs.kind) < transportPriority(for: rhs.kind)
            }

        var slotsRemaining = maxDrones - drones.count
        for consumer in consumers where slotsRemaining > 0 {
            let desired = GameConfig.desiredInventory(for: consumer)
            guard !desired.isEmpty else { continue }

            for resource in prioritizedResources(for: consumer) where slotsRemaining > 0 {
                let targetAmount = desired[resource]
                guard targetAmount > 0 else { continue }

                let incoming = drones.values
                    .filter { $0.destinationID == consumer.id && $0.resource == resource }
                    .reduce(0) { $0 + $1.amount }

                let deficit = targetAmount - consumer.inventory[resource] - incoming
                guard deficit > 0 else { continue }

                guard let sourceID = bestSourceID(for: resource, destination: consumer, minimumNeeded: deficit),
                      var source = buildings[sourceID] else {
                    continue
                }

                let reserve = shippingReserve(for: source, resource: resource)
                let available = max(0, source.inventory[resource] - reserve)
                let amount = min(deficit, available, packageSize(for: resource, destination: consumer))
                guard amount > 0 else { continue }

                source.inventory[resource] -= amount
                buildings[sourceID] = source

                let drone = DroneState(
                    id: UUID(),
                    resource: resource,
                    amount: amount,
                    sourceID: sourceID,
                    destinationID: consumer.id,
                    progress: 0,
                    speed: GameConfig.droneSpeed
                )
                drones[drone.id] = drone
                slotsRemaining -= 1
            }
        }
    }

    private func updateProjectiles(dt: CGFloat) {
        for projectileID in Array(projectiles.keys) {
            guard var projectile = projectiles[projectileID] else { continue }
            projectile.ttl -= dt
            if projectile.ttl <= 0 {
                projectiles.removeValue(forKey: projectileID)
            } else {
                projectiles[projectileID] = projectile
            }
        }
    }

    private func updateBuildingStatuses() {
        for buildingID in Array(buildings.keys) {
            guard var building = buildings[buildingID] else { continue }
            let storage = GameConfig.storage(for: building)

            if !building.connected && building.kind != .core {
                building.statusText = "Out of network"
                building.statusSeverity = .critical
            } else if GameConfig.isHub(building.kind) {
                let activeRoutes = drones.values.filter { $0.sourceID == buildingID || $0.destinationID == buildingID }.count
                building.statusText = activeRoutes > 0 ? "Routing \(activeRoutes) lanes" : "Hub stable"
                building.statusSeverity = .stable
            } else if building.kind == .generator, building.inventory.energy >= storage.energy {
                building.statusText = "Battery full"
                building.statusSeverity = .warning
            } else if building.kind == .mine, building.inventory.ore >= storage.ore {
                building.statusText = "Ore queue full"
                building.statusSeverity = .warning
            }

            buildings[buildingID] = building
        }
    }

    private func evaluateEndState() {
        guard let base = buildings[baseID] else { return }
        if base.health <= 0 {
            phase = .lost
            postAlert("Base core lost. Colony collapsed.", key: "loss", cooldown: 0)
        }
    }

    private func recalculateConnectivity() {
        connectedHubIDs.removeAll()
        guard let base = buildings[baseID] else { return }

        connectedHubIDs.insert(base.id)
        var frontier = [base.id]

        while let currentHubID = frontier.popLast(),
              let currentHub = buildings[currentHubID] {
            let radius = GameConfig.supplyRadius(for: currentHub)
            for candidate in buildings.values where GameConfig.isHub(candidate.kind) && !connectedHubIDs.contains(candidate.id) {
                if currentHub.coordinate.distance(to: candidate.coordinate) <= radius {
                    connectedHubIDs.insert(candidate.id)
                    frontier.append(candidate.id)
                }
            }
        }

        let connectedHubs = connectedHubIDs.compactMap { buildings[$0] }
        for buildingID in Array(buildings.keys) {
            guard var building = buildings[buildingID] else { continue }
            building.connected = connectedHubs.contains(where: { hub in
                buildingID == hub.id || hub.coordinate.distance(to: building.coordinate) <= GameConfig.supplyRadius(for: hub)
            })
            buildings[buildingID] = building
        }
    }

    private func accessibleStockpile() -> ResourceStock {
        buildings.values
            .filter { $0.connected }
            .reduce(into: ResourceStock()) { partial, building in
                partial.add(building.inventory)
            }
    }

    private func spendFromNetwork(_ cost: ResourceStock) {
        for resource in ResourceKind.allCases {
            var remaining = cost[resource]
            guard remaining > 0 else { continue }

            let orderedIDs = buildings.values
                .filter { $0.connected }
                .sorted { lhs, rhs in
                    spendingPriority(for: lhs.kind) < spendingPriority(for: rhs.kind)
                }
                .map(\.id)

            for buildingID in orderedIDs where remaining > 0 {
                guard var building = buildings[buildingID] else { continue }
                let taken = min(remaining, building.inventory[resource])
                building.inventory[resource] -= taken
                remaining -= taken
                buildings[buildingID] = building
            }
        }
    }

    private func grantToBase(_ stock: ResourceStock) {
        guard var base = buildings[baseID] else { return }
        base.inventory.add(stock)
        buildings[baseID] = base
    }

    private func isInBuildRadius(_ coordinate: GridCoordinate) -> Bool {
        connectedHubIDs.compactMap { buildings[$0] }.contains { hub in
            hub.coordinate.distance(to: coordinate) <= GameConfig.supplyRadius(for: hub)
        }
    }

    private func bestSourceID(for resource: ResourceKind, destination: BuildingState, minimumNeeded: Int) -> UUID? {
        buildings.values
            .filter { $0.connected && $0.id != destination.id }
            .filter { building in
                let reserve = shippingReserve(for: building, resource: resource)
                return building.inventory[resource] - reserve > 0
            }
            .sorted { lhs, rhs in
                let lhsDistance = lhs.coordinate.distance(to: destination.coordinate)
                let rhsDistance = rhs.coordinate.distance(to: destination.coordinate)
                if lhsDistance == rhsDistance {
                    return lhs.inventory[resource] > rhs.inventory[resource]
                }
                return lhsDistance < rhsDistance
            }
            .first?
            .id
    }

    private func shippingReserve(for building: BuildingState, resource: ResourceKind) -> Int {
        switch building.kind {
        case .core, .depot:
            return 0
        case .generator where resource == .energy:
            return 2
        case .mine where resource == .ore:
            return 2
        case .smelter where resource == .ore || resource == .energy:
            return max(1, GameConfig.desiredInventory(for: building)[resource] / 2)
        case .ammoFactory where resource == .alloy || resource == .energy:
            return max(1, GameConfig.desiredInventory(for: building)[resource] / 2)
        case .gunTower, .cannonTower:
            return GameConfig.desiredInventory(for: building)[resource]
        default:
            return 0
        }
    }

    private func packageSize(for resource: ResourceKind, destination: BuildingState) -> Int {
        switch destination.kind {
        case .gunTower, .cannonTower:
            return resource == .ammo ? 2 : 1
        case .smelter, .ammoFactory:
            return 3
        default:
            return 2
        }
    }

    private func transportPriority(for kind: BuildingKind) -> Int {
        switch kind {
        case .gunTower, .cannonTower:
            return 0
        case .ammoFactory:
            return 1
        case .smelter:
            return 2
        case .generator, .mine:
            return 3
        case .depot, .core:
            return 4
        }
    }

    private func prioritizedResources(for building: BuildingState) -> [ResourceKind] {
        switch building.kind {
        case .gunTower:
            return [.ammo]
        case .cannonTower:
            return [.ammo, .energy]
        case .ammoFactory:
            return [.alloy, .energy]
        case .smelter:
            return [.ore, .energy]
        default:
            return ResourceKind.allCases
        }
    }

    private func spendingPriority(for kind: BuildingKind) -> Int {
        switch kind {
        case .core:
            return 0
        case .depot:
            return 1
        case .generator, .mine, .smelter, .ammoFactory:
            return 2
        case .gunTower, .cannonTower:
            return 3
        }
    }

    private func laneLength(for lane: Int) -> CGFloat {
        let path = GameConfig.lanePaths[lane]
        guard path.count > 1 else { return 0 }

        return zip(path, path.dropFirst()).reduce(0) { partial, pair in
            partial + pair.0.distance(to: pair.1)
        }
    }

    private func enemyPoint(for enemy: EnemyState) -> CGPoint {
        point(on: GameConfig.lanePaths[enemy.lane], progress: enemy.pathProgress)
    }

    private func point(on path: [CGPoint], progress: CGFloat) -> CGPoint {
        guard path.count > 1 else { return path.first ?? .zero }

        var remaining = progress
        for pair in zip(path, path.dropFirst()) {
            let length = pair.0.distance(to: pair.1)
            if remaining <= length {
                let t = max(0, min(1, remaining / max(0.001, length)))
                return CGPoint(
                    x: pair.0.x + (pair.1.x - pair.0.x) * t,
                    y: pair.0.y + (pair.1.y - pair.0.y) * t
                )
            }
            remaining -= length
        }

        return path.last ?? .zero
    }

    private func clampInventory(_ building: inout BuildingState) {
        let storage = GameConfig.storage(for: building)
        for resource in ResourceKind.allCases {
            building.inventory[resource] = min(building.inventory[resource], storage[resource])
        }
    }

    private func missingInputLabel(for building: BuildingState) -> String {
        switch building.kind {
        case .smelter:
            if building.inventory.ore < 2 { return "Need ore" }
            if building.inventory.energy < 1 { return "Need energy" }
            return "Waiting on supply"
        case .ammoFactory:
            if building.inventory.alloy < 2 { return "Need alloy" }
            if building.inventory.energy < 1 { return "Need energy" }
            return "Waiting on supply"
        default:
            return "Supply blocked"
        }
    }

    private func missingAmmoLabel(for building: BuildingState) -> String {
        switch building.kind {
        case .gunTower:
            return "Out of ammo"
        case .cannonTower:
            if building.inventory.ammo < 2 { return "Need ammo" }
            return "Need energy"
        default:
            return "Supply blocked"
        }
    }

    private func selectedBuildingSnapshot() -> SelectedBuildingSnapshot? {
        guard let selectedBuildingID, let building = buildings[selectedBuildingID] else { return nil }
        let entry = GameConfig.catalog(for: building.kind)
        let maxHealth = Int(GameConfig.maxHealth(for: building.kind, level: building.level))
        let cost = GameConfig.upgradeCost(for: building)

        return SelectedBuildingSnapshot(
            id: building.id,
            kind: building.kind,
            title: entry.name,
            subtitle: entry.description,
            level: building.level,
            healthText: "\(Int(building.health))/\(maxHealth) HP",
            statusText: building.statusText,
            statusSeverity: building.statusSeverity,
            inventoryLines: building.inventory.lines().isEmpty ? ["No stored resources"] : building.inventory.lines(),
            upgradeCostText: cost?.compactDescription(),
            canUpgrade: cost.map { accessibleStockpile().canAfford($0) } ?? false
        )
    }

    private func tickAlerts(dt: CGFloat) {
        alerts = alerts.compactMap { alert in
            var alert = alert
            alert.timeRemaining -= dt
            return alert.timeRemaining > 0 ? alert : nil
        }

        for key in Array(alertCooldowns.keys) {
            let updated = max(0, (alertCooldowns[key] ?? 0) - dt)
            if updated == 0 {
                alertCooldowns.removeValue(forKey: key)
            } else {
                alertCooldowns[key] = updated
            }
        }
    }

    private func postAlert(_ text: String, key: String?, cooldown: CGFloat) {
        if let key, let remaining = alertCooldowns[key], remaining > 0 {
            return
        }

        if let key {
            alertCooldowns[key] = cooldown
        }

        alerts.insert(AlertState(text: text, timeRemaining: GameConfig.alertLifetime), at: 0)
        if alerts.count > 3 {
            alerts = Array(alerts.prefix(3))
        }
    }
}
