import SpriteKit
import UIKit

@MainActor
protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didUpdate snapshot: GameSnapshot)
    func gameSceneDidConsumeSelectedBlueprint(_ scene: GameScene)
}

private struct BuildingVisual {
    let container: SKNode
    let body: SKShapeNode
    let label: SKLabelNode
    let statusDot: SKShapeNode
}

@MainActor
final class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?

    var selectedBlueprint: BuildingKind? {
        didSet {
            updateTileHighlights()
        }
    }

    private let simulation = GameSimulation()
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: CGFloat = 0

    private let backdropLayer = SKNode()
    private let laneLayer = SKNode()
    private let tileLayer = SKNode()
    private let nodeLayer = SKNode()
    private let droneLayer = SKNode()
    private let enemyLayer = SKNode()
    private let effectLayer = SKNode()
    private let overlayLayer = SKNode()

    private var tileNodes: [GridCoordinate: SKShapeNode] = [:]
    private var buildingNodes: [UUID: BuildingVisual] = [:]
    private var enemyNodes: [UUID: SKShapeNode] = [:]
    private var droneNodes: [UUID: SKShapeNode] = [:]
    private var projectileNodes: [UUID: SKShapeNode] = [:]
    private let selectionRing = SKShapeNode()

    private struct BoardMetrics {
        let tileSize: CGFloat
        let topLeft: CGPoint
    }

    var currentSnapshot: GameSnapshot {
        simulation.snapshot()
    }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.03, green: 0.07, blue: 0.12, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        if children.isEmpty {
            setupLayers()
            rebuildStaticMap()
            renderWorld()
        }

        gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildStaticMap()
        renderWorld()
    }

    func startGame() {
        simulation.start()
        renderWorld()
        gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
    }

    func restartGame() {
        selectedBlueprint = nil
        simulation.reset()
        renderWorld()
        gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
    }

    func upgradeSelectedBuilding() {
        _ = simulation.upgradeSelectedBuilding()
        renderWorld()
        gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
    }

    func clearSelection() {
        simulation.clearSelection()
        renderWorld()
        gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
    }

    override func update(_ currentTime: TimeInterval) {
        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return
        }

        let rawDelta = min(max(currentTime - lastUpdateTime, 0), 0.05)
        lastUpdateTime = currentTime
        accumulator += rawDelta

        while accumulator >= GameConfig.fixedDelta {
            simulation.update(dt: GameConfig.fixedDelta)
            accumulator -= GameConfig.fixedDelta
        }

        renderWorld()
        gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        guard let coordinate = gridCoordinate(for: location) else {
            simulation.clearSelection()
            renderWorld()
            gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
            return
        }

        if let selectedBlueprint {
            let result = simulation.placeBuilding(kind: selectedBlueprint, at: coordinate)
            if result.success {
                self.selectedBlueprint = nil
                gameDelegate?.gameSceneDidConsumeSelectedBlueprint(self)
            }
        } else {
            simulation.selectBuilding(at: coordinate)
        }

        renderWorld()
        gameDelegate?.gameScene(self, didUpdate: simulation.snapshot())
    }

    private func setupLayers() {
        addChild(backdropLayer)
        addChild(laneLayer)
        addChild(tileLayer)
        addChild(nodeLayer)
        addChild(droneLayer)
        addChild(enemyLayer)
        addChild(effectLayer)
        addChild(overlayLayer)

        selectionRing.lineWidth = 2
        selectionRing.glowWidth = 1.5
        selectionRing.fillColor = .clear
        selectionRing.isHidden = true
        overlayLayer.addChild(selectionRing)
    }

    private func rebuildStaticMap() {
        tileLayer.removeAllChildren()
        laneLayer.removeAllChildren()
        backdropLayer.removeAllChildren()
        tileNodes.removeAll()

        drawBackdrop()
        drawBoard()
        drawEnemyLanes()
        drawResourceNodes()
        updateTileHighlights()
    }

    private func renderWorld() {
        renderBuildings()
        renderEnemies()
        renderDrones()
        renderProjectiles()
        updateSelectionRing()
        updateTileHighlights()
    }

    private func drawBackdrop() {
        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 1.1, height: size.height * 1.1), cornerRadius: 28)
        bg.fillColor = UIColor(red: 0.05, green: 0.09, blue: 0.14, alpha: 1)
        bg.strokeColor = UIColor(red: 0.10, green: 0.18, blue: 0.24, alpha: 1)
        bg.lineWidth = 3
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdropLayer.addChild(bg)

        let glows: [(CGPoint, CGFloat, UIColor)] = [
            (CGPoint(x: size.width * 0.18, y: size.height * 0.78), 150, UIColor(red: 0.16, green: 0.40, blue: 0.50, alpha: 0.22)),
            (CGPoint(x: size.width * 0.78, y: size.height * 0.22), 180, UIColor(red: 0.55, green: 0.28, blue: 0.12, alpha: 0.16)),
            (CGPoint(x: size.width * 0.72, y: size.height * 0.82), 120, UIColor(red: 0.14, green: 0.22, blue: 0.36, alpha: 0.20))
        ]

        for glow in glows {
            let orb = SKShapeNode(circleOfRadius: glow.1)
            orb.fillColor = glow.2
            orb.strokeColor = .clear
            orb.position = glow.0
            backdropLayer.addChild(orb)
        }
    }

    private func drawBoard() {
        for y in 0 ..< GameConfig.rows {
            for x in 0 ..< GameConfig.columns {
                let coordinate = GridCoordinate(x: x, y: y)
                let tile = SKShapeNode(rectOf: CGSize(width: metrics.tileSize * 0.94, height: metrics.tileSize * 0.94), cornerRadius: metrics.tileSize * 0.14)
                tile.position = point(for: coordinate)
                tile.fillColor = baseTileColor(for: coordinate)
                tile.strokeColor = UIColor(red: 0.16, green: 0.22, blue: 0.28, alpha: 0.8)
                tile.lineWidth = 1
                tileLayer.addChild(tile)
                tileNodes[coordinate] = tile
            }
        }
    }

    private func drawEnemyLanes() {
        for lanePath in GameConfig.lanePaths {
            let bezier = UIBezierPath()
            for (index, lanePoint) in lanePath.enumerated() {
                let scenePoint = point(forGridPoint: lanePoint)
                if index == 0 {
                    bezier.move(to: scenePoint)
                } else {
                    bezier.addLine(to: scenePoint)
                }
            }

            let lane = SKShapeNode(path: bezier.cgPath)
            lane.strokeColor = UIColor(red: 0.86, green: 0.32, blue: 0.18, alpha: 0.5)
            lane.lineWidth = metrics.tileSize * 0.18
            lane.lineCap = .round
            lane.glowWidth = 6
            laneLayer.addChild(lane)
        }
    }

    private func drawResourceNodes() {
        for node in GameConfig.resourceNodes {
            let marker = SKShapeNode(circleOfRadius: metrics.tileSize * 0.28)
            marker.position = point(for: node)
            marker.fillColor = UIColor(red: 0.55, green: 0.34, blue: 0.18, alpha: 0.95)
            marker.strokeColor = UIColor(red: 0.86, green: 0.63, blue: 0.30, alpha: 1)
            marker.lineWidth = 2
            tileLayer.addChild(marker)

            let label = SKLabelNode(fontNamed: "AvenirNextCondensed-Bold")
            label.text = "ORE"
            label.fontSize = metrics.tileSize * 0.18
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: -metrics.tileSize * 0.08)
            marker.addChild(label)
        }
    }

    private func renderBuildings() {
        let liveIDs = Set(simulation.buildings.keys)

        for staleID in buildingNodes.keys where !liveIDs.contains(staleID) {
            buildingNodes[staleID]?.container.removeFromParent()
            buildingNodes.removeValue(forKey: staleID)
        }

        for building in simulation.buildings.values {
            let visual = buildingNodes[building.id] ?? makeBuildingVisual(for: building)
            apply(building: building, to: visual)
            buildingNodes[building.id] = visual
        }
    }

    private func renderEnemies() {
        let liveIDs = Set(simulation.enemies.keys)

        for staleID in enemyNodes.keys where !liveIDs.contains(staleID) {
            enemyNodes[staleID]?.removeFromParent()
            enemyNodes.removeValue(forKey: staleID)
        }

        for enemy in simulation.enemies.values {
            let node = enemyNodes[enemy.id] ?? makeEnemyNode(for: enemy)
            node.position = point(forGridPoint: enemyPoint(for: enemy))
            enemyNodes[enemy.id] = node
        }
    }

    private func renderDrones() {
        let liveIDs = Set(simulation.drones.keys)

        for staleID in droneNodes.keys where !liveIDs.contains(staleID) {
            droneNodes[staleID]?.removeFromParent()
            droneNodes.removeValue(forKey: staleID)
        }

        for drone in simulation.drones.values {
            guard let source = simulation.buildings[drone.sourceID], let destination = simulation.buildings[drone.destinationID] else { continue }
            let node = droneNodes[drone.id] ?? makeDroneNode(for: drone)
            let sourcePoint = point(for: source.coordinate)
            let destinationPoint = point(for: destination.coordinate)
            node.position = CGPoint(
                x: sourcePoint.x + (destinationPoint.x - sourcePoint.x) * drone.progress,
                y: sourcePoint.y + (destinationPoint.y - sourcePoint.y) * drone.progress
            )
            droneNodes[drone.id] = node
        }
    }

    private func renderProjectiles() {
        let liveIDs = Set(simulation.projectiles.keys)

        for staleID in projectileNodes.keys where !liveIDs.contains(staleID) {
            projectileNodes[staleID]?.removeFromParent()
            projectileNodes.removeValue(forKey: staleID)
        }

        for projectile in simulation.projectiles.values {
            let node = projectileNodes[projectile.id] ?? makeProjectileNode(for: projectile)
            let progress = max(0, min(1, 1 - projectile.ttl / 0.18))
            let sourcePoint = point(forGridPoint: projectile.sourcePoint)
            let destinationPoint = point(forGridPoint: projectile.destinationPoint)
            node.position = CGPoint(
                x: sourcePoint.x + (destinationPoint.x - sourcePoint.x) * progress,
                y: sourcePoint.y + (destinationPoint.y - sourcePoint.y) * progress
            )
            projectileNodes[projectile.id] = node
        }
    }

    private func makeBuildingVisual(for building: BuildingState) -> BuildingVisual {
        let container = SKNode()

        let body = SKShapeNode(rectOf: CGSize(width: metrics.tileSize * 0.78, height: metrics.tileSize * 0.78), cornerRadius: metrics.tileSize * 0.18)
        body.lineWidth = 2.5
        container.addChild(body)

        let label = SKLabelNode(fontNamed: "AvenirNextCondensed-DemiBold")
        label.fontSize = metrics.tileSize * 0.18
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -1)
        container.addChild(label)

        let statusDot = SKShapeNode(circleOfRadius: metrics.tileSize * 0.08)
        statusDot.position = CGPoint(x: metrics.tileSize * 0.24, y: metrics.tileSize * 0.24)
        container.addChild(statusDot)

        nodeLayer.addChild(container)
        return BuildingVisual(container: container, body: body, label: label, statusDot: statusDot)
    }

    private func apply(building: BuildingState, to visual: BuildingVisual) {
        visual.container.position = point(for: building.coordinate)
        visual.body.fillColor = buildingColor(for: building.kind)
        visual.body.strokeColor = statusColor(for: building.statusSeverity)
        visual.body.alpha = building.connected || building.kind == .core ? 1.0 : 0.45

        visual.label.text = GameConfig.catalog(for: building.kind).shortLabel
        visual.label.fontColor = .white
        visual.statusDot.fillColor = statusColor(for: building.statusSeverity)
        visual.statusDot.strokeColor = UIColor(white: 1.0, alpha: 0.35)
        visual.statusDot.lineWidth = 1
    }

    private func makeEnemyNode(for enemy: EnemyState) -> SKShapeNode {
        let node: SKShapeNode
        switch enemy.kind {
        case .runner:
            node = SKShapeNode(circleOfRadius: metrics.tileSize * 0.18)
            node.fillColor = UIColor(red: 0.90, green: 0.46, blue: 0.26, alpha: 1)
        case .tank:
            node = SKShapeNode(rectOf: CGSize(width: metrics.tileSize * 0.42, height: metrics.tileSize * 0.42), cornerRadius: 6)
            node.fillColor = UIColor(red: 0.68, green: 0.24, blue: 0.16, alpha: 1)
        case .saboteur:
            let path = UIBezierPath()
            let radius = metrics.tileSize * 0.22
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: -radius, y: 0))
            path.close()
            node = SKShapeNode(path: path.cgPath)
            node.fillColor = UIColor(red: 0.93, green: 0.78, blue: 0.28, alpha: 1)
        }

        node.strokeColor = UIColor(white: 1.0, alpha: 0.45)
        node.lineWidth = 1.2
        enemyLayer.addChild(node)
        return node
    }

    private func makeDroneNode(for drone: DroneState) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: metrics.tileSize * 0.09)
        node.fillColor = resourceColor(for: drone.resource)
        node.strokeColor = UIColor(white: 1.0, alpha: 0.55)
        node.lineWidth = 1
        droneLayer.addChild(node)
        return node
    }

    private func makeProjectileNode(for projectile: ProjectileState) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: metrics.tileSize * 0.07)
        node.fillColor = resourceColor(for: projectile.tintToken)
        node.strokeColor = .clear
        effectLayer.addChild(node)
        return node
    }

    private func updateSelectionRing() {
        guard let building = simulation.selectedBuildingState else {
            selectionRing.isHidden = true
            return
        }

        selectionRing.isHidden = false
        selectionRing.position = point(for: building.coordinate)
        selectionRing.strokeColor = UIColor(white: 1.0, alpha: 0.9)

        let radiusInTiles: CGFloat
        switch building.kind {
        case .core, .depot:
            radiusInTiles = GameConfig.supplyRadius(for: building)
        case .gunTower, .cannonTower:
            radiusInTiles = GameConfig.range(for: building)
        default:
            radiusInTiles = 0.58
        }

        selectionRing.path = UIBezierPath(ovalIn: CGRect(
            x: -metrics.tileSize * radiusInTiles,
            y: -metrics.tileSize * radiusInTiles,
            width: metrics.tileSize * radiusInTiles * 2,
            height: metrics.tileSize * radiusInTiles * 2
        )).cgPath
    }

    private func updateTileHighlights() {
        for (coordinate, tile) in tileNodes {
            if let selectedBlueprint {
                let check = simulation.placementCheck(for: selectedBlueprint, at: coordinate)
                tile.fillColor = check.isValid ? UIColor(red: 0.13, green: 0.34, blue: 0.24, alpha: 0.85) : baseTileColor(for: coordinate)
                tile.strokeColor = check.isValid ? UIColor(red: 0.49, green: 0.84, blue: 0.66, alpha: 1) : UIColor(red: 0.16, green: 0.22, blue: 0.28, alpha: 0.8)
            } else {
                tile.fillColor = baseTileColor(for: coordinate)
                tile.strokeColor = UIColor(red: 0.16, green: 0.22, blue: 0.28, alpha: 0.8)
            }
        }
    }

    private var metrics: BoardMetrics {
        let horizontalPadding: CGFloat = 48
        let verticalPadding: CGFloat = 70
        let tileWidth = (size.width - horizontalPadding * 2) / CGFloat(GameConfig.columns)
        let tileHeight = (size.height - verticalPadding * 2) / CGFloat(GameConfig.rows)
        let tileSize = min(tileWidth, tileHeight)
        let boardWidth = tileSize * CGFloat(GameConfig.columns)
        let boardHeight = tileSize * CGFloat(GameConfig.rows)
        let topLeft = CGPoint(x: size.width / 2 - boardWidth / 2 + tileSize / 2, y: size.height / 2 + boardHeight / 2 - tileSize / 2)
        return BoardMetrics(tileSize: tileSize, topLeft: topLeft)
    }

    private func point(for coordinate: GridCoordinate) -> CGPoint {
        CGPoint(
            x: metrics.topLeft.x + CGFloat(coordinate.x) * metrics.tileSize,
            y: metrics.topLeft.y - CGFloat(coordinate.y) * metrics.tileSize
        )
    }

    private func point(forGridPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: metrics.topLeft.x + point.x * metrics.tileSize,
            y: metrics.topLeft.y - point.y * metrics.tileSize
        )
    }

    private func gridCoordinate(for point: CGPoint) -> GridCoordinate? {
        let left = metrics.topLeft.x - metrics.tileSize / 2
        let top = metrics.topLeft.y + metrics.tileSize / 2
        let relativeX = point.x - left
        let relativeY = top - point.y

        let x = Int(floor(relativeX / metrics.tileSize))
        let y = Int(floor(relativeY / metrics.tileSize))

        guard (0 ..< GameConfig.columns).contains(x),
              (0 ..< GameConfig.rows).contains(y) else {
            return nil
        }

        return GridCoordinate(x: x, y: y)
    }

    private func enemyPoint(for enemy: EnemyState) -> CGPoint {
        let path = GameConfig.lanePaths[enemy.lane]
        guard path.count > 1 else { return .zero }

        var remaining = enemy.pathProgress
        for pair in zip(path, path.dropFirst()) {
            let distance = pair.0.distance(to: pair.1)
            if remaining <= distance {
                let t = max(0, min(1, remaining / max(0.001, distance)))
                return CGPoint(
                    x: pair.0.x + (pair.1.x - pair.0.x) * t,
                    y: pair.0.y + (pair.1.y - pair.0.y) * t
                )
            }
            remaining -= distance
        }

        return path.last ?? .zero
    }

    private func baseTileColor(for coordinate: GridCoordinate) -> UIColor {
        if GameConfig.pathTiles.contains(coordinate) {
            return UIColor(red: 0.31, green: 0.16, blue: 0.12, alpha: 0.85)
        }

        if GameConfig.resourceNodes.contains(coordinate) {
            return UIColor(red: 0.19, green: 0.16, blue: 0.12, alpha: 0.85)
        }

        return UIColor(red: 0.09, green: 0.12, blue: 0.17, alpha: 0.9)
    }

    private func buildingColor(for kind: BuildingKind) -> UIColor {
        switch kind {
        case .core:
            return UIColor(red: 0.11, green: 0.46, blue: 0.50, alpha: 1)
        case .depot:
            return UIColor(red: 0.18, green: 0.34, blue: 0.46, alpha: 1)
        case .generator:
            return UIColor(red: 0.64, green: 0.54, blue: 0.18, alpha: 1)
        case .mine:
            return UIColor(red: 0.54, green: 0.30, blue: 0.14, alpha: 1)
        case .smelter:
            return UIColor(red: 0.66, green: 0.28, blue: 0.16, alpha: 1)
        case .ammoFactory:
            return UIColor(red: 0.56, green: 0.22, blue: 0.18, alpha: 1)
        case .gunTower:
            return UIColor(red: 0.12, green: 0.52, blue: 0.46, alpha: 1)
        case .cannonTower:
            return UIColor(red: 0.76, green: 0.38, blue: 0.12, alpha: 1)
        }
    }

    private func statusColor(for severity: StatusSeverity) -> UIColor {
        switch severity {
        case .stable:
            return UIColor(red: 0.46, green: 0.84, blue: 0.62, alpha: 1)
        case .warning:
            return UIColor(red: 0.94, green: 0.78, blue: 0.25, alpha: 1)
        case .critical:
            return UIColor(red: 0.92, green: 0.34, blue: 0.28, alpha: 1)
        }
    }

    private func resourceColor(for resource: ResourceKind) -> UIColor {
        switch resource {
        case .ore:
            return UIColor(red: 0.74, green: 0.48, blue: 0.22, alpha: 1)
        case .alloy:
            return UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1)
        case .energy:
            return UIColor(red: 0.98, green: 0.86, blue: 0.36, alpha: 1)
        case .ammo:
            return UIColor(red: 0.94, green: 0.46, blue: 0.26, alpha: 1)
        }
    }
}
