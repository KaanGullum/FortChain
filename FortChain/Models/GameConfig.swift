import CoreGraphics
import Foundation

enum GameConfig {
    static let columns = 12
    static let rows = 8

    static let openingCountdown: CGFloat = 18
    static let alertLifetime: CGFloat = 3.6
    static let fixedDelta: CGFloat = 1.0 / 30.0

    static let baseCoordinate = GridCoordinate(x: 6, y: 4)
    static let starterDepotCoordinate = GridCoordinate(x: 7, y: 3)
    static let starterGeneratorCoordinate = GridCoordinate(x: 6, y: 2)
    static let starterTowerCoordinate = GridCoordinate(x: 4, y: 3)

    static let resourceNodes: [GridCoordinate] = [
        GridCoordinate(x: 8, y: 1),
        GridCoordinate(x: 10, y: 4),
        GridCoordinate(x: 9, y: 6)
    ]

    static let pathTiles: Set<GridCoordinate> = [
        GridCoordinate(x: 0, y: 1),
        GridCoordinate(x: 1, y: 1),
        GridCoordinate(x: 2, y: 1),
        GridCoordinate(x: 3, y: 2),
        GridCoordinate(x: 4, y: 2),
        GridCoordinate(x: 5, y: 3),
        GridCoordinate(x: 6, y: 4),
        GridCoordinate(x: 0, y: 4),
        GridCoordinate(x: 1, y: 4),
        GridCoordinate(x: 2, y: 4),
        GridCoordinate(x: 3, y: 4),
        GridCoordinate(x: 4, y: 4),
        GridCoordinate(x: 5, y: 4),
        GridCoordinate(x: 0, y: 7),
        GridCoordinate(x: 1, y: 7),
        GridCoordinate(x: 2, y: 7),
        GridCoordinate(x: 3, y: 6),
        GridCoordinate(x: 4, y: 6),
        GridCoordinate(x: 5, y: 5)
    ]

    static let lanePaths: [[CGPoint]] = [
        [
            CGPoint(x: 0, y: 1),
            CGPoint(x: 2, y: 1),
            CGPoint(x: 3.8, y: 2.1),
            CGPoint(x: 5.2, y: 3.2),
            CGPoint(x: 6, y: 4)
        ],
        [
            CGPoint(x: 0, y: 4),
            CGPoint(x: 2.2, y: 4),
            CGPoint(x: 4.6, y: 4),
            CGPoint(x: 6, y: 4)
        ],
        [
            CGPoint(x: 0, y: 7),
            CGPoint(x: 2, y: 7),
            CGPoint(x: 3.8, y: 6.2),
            CGPoint(x: 5.2, y: 5),
            CGPoint(x: 6, y: 4)
        ]
    ]

    static let buildMenu: [BuildingKind] = [
        .mine,
        .generator,
        .smelter,
        .ammoFactory,
        .depot,
        .gunTower,
        .cannonTower
    ]

    static func catalog(for kind: BuildingKind) -> BuildingCatalogEntry {
        switch kind {
        case .core:
            return BuildingCatalogEntry(
                kind: .core,
                name: "Base Core",
                shortLabel: "HQ",
                description: "Anchors the supply network and must survive all waves.",
                buildCost: ResourceStock()
            )
        case .depot:
            return BuildingCatalogEntry(
                kind: .depot,
                name: "Depot",
                shortLabel: "DEP",
                description: "Extends the logistics frontier and adds more drone throughput.",
                buildCost: ResourceStock(ore: 4, alloy: 4, energy: 2)
            )
        case .generator:
            return BuildingCatalogEntry(
                kind: .generator,
                name: "Generator",
                shortLabel: "GEN",
                description: "Produces energy cells needed by factories and heavy defenses.",
                buildCost: ResourceStock(ore: 4, alloy: 2)
            )
        case .mine:
            return BuildingCatalogEntry(
                kind: .mine,
                name: "Mine",
                shortLabel: "MINE",
                description: "Extracts ore from a resource node over time.",
                buildCost: ResourceStock(alloy: 3, energy: 1)
            )
        case .smelter:
            return BuildingCatalogEntry(
                kind: .smelter,
                name: "Smelter",
                shortLabel: "SMELT",
                description: "Converts ore and energy into alloy for advanced production.",
                buildCost: ResourceStock(ore: 3, alloy: 4, energy: 2)
            )
        case .ammoFactory:
            return BuildingCatalogEntry(
                kind: .ammoFactory,
                name: "Ammo Foundry",
                shortLabel: "AMMO",
                description: "Turns alloy and energy into ammunition for towers.",
                buildCost: ResourceStock(ore: 4, alloy: 5, energy: 3)
            )
        case .gunTower:
            return BuildingCatalogEntry(
                kind: .gunTower,
                name: "Gun Tower",
                shortLabel: "GUN",
                description: "Fast lane defender. Stops firing when ammo runs dry.",
                buildCost: ResourceStock(alloy: 4, ammo: 3)
            )
        case .cannonTower:
            return BuildingCatalogEntry(
                kind: .cannonTower,
                name: "Cannon Tower",
                shortLabel: "CANN",
                description: "Heavy splash turret. Requires both ammo and energy.",
                buildCost: ResourceStock(alloy: 6, energy: 3, ammo: 4)
            )
        }
    }

    static func maxLevel(for kind: BuildingKind) -> Int {
        switch kind {
        case .core:
            return 1
        default:
            return 3
        }
    }

    static func upgradeCost(for building: BuildingState) -> ResourceStock? {
        guard building.level < maxLevel(for: building.kind) else { return nil }

        let tier = building.level
        switch building.kind {
        case .core:
            return nil
        case .depot:
            return scaled(ResourceStock(alloy: 4, energy: 3), factor: tier)
        case .generator:
            return scaled(ResourceStock(ore: 3, alloy: 3), factor: tier)
        case .mine:
            return scaled(ResourceStock(alloy: 4, energy: 2), factor: tier)
        case .smelter:
            return scaled(ResourceStock(ore: 3, alloy: 5, energy: 3), factor: tier)
        case .ammoFactory:
            return scaled(ResourceStock(ore: 4, alloy: 5, energy: 4), factor: tier)
        case .gunTower:
            return scaled(ResourceStock(alloy: 5, ammo: 4), factor: tier)
        case .cannonTower:
            return scaled(ResourceStock(alloy: 6, energy: 4, ammo: 4), factor: tier)
        }
    }

    static func maxHealth(for kind: BuildingKind, level: Int) -> CGFloat {
        switch kind {
        case .core:
            return 220
        case .depot:
            return 70 + CGFloat(level - 1) * 15
        case .generator:
            return 58 + CGFloat(level - 1) * 12
        case .mine:
            return 54 + CGFloat(level - 1) * 10
        case .smelter:
            return 68 + CGFloat(level - 1) * 14
        case .ammoFactory:
            return 68 + CGFloat(level - 1) * 14
        case .gunTower:
            return 74 + CGFloat(level - 1) * 12
        case .cannonTower:
            return 88 + CGFloat(level - 1) * 16
        }
    }

    static func storage(for building: BuildingState) -> ResourceStock {
        let bonus = max(0, building.level - 1)

        switch building.kind {
        case .core:
            return ResourceStock(ore: 120, alloy: 120, energy: 120, ammo: 120)
        case .depot:
            return ResourceStock(
                ore: 24 + bonus * 8,
                alloy: 24 + bonus * 8,
                energy: 24 + bonus * 8,
                ammo: 24 + bonus * 8
            )
        case .generator:
            return ResourceStock(energy: 16 + bonus * 6)
        case .mine:
            return ResourceStock(ore: 16 + bonus * 6)
        case .smelter:
            return ResourceStock(ore: 12 + bonus * 4, alloy: 14 + bonus * 4, energy: 8 + bonus * 2)
        case .ammoFactory:
            return ResourceStock(alloy: 12 + bonus * 4, energy: 8 + bonus * 2, ammo: 14 + bonus * 5)
        case .gunTower:
            return ResourceStock(ammo: 8 + bonus * 3)
        case .cannonTower:
            return ResourceStock(energy: 6 + bonus * 2, ammo: 6 + bonus * 2)
        }
    }

    static func desiredInventory(for building: BuildingState) -> ResourceStock {
        let bonus = max(0, building.level - 1)

        switch building.kind {
        case .smelter:
            return ResourceStock(ore: 6 + bonus * 2, energy: 4 + bonus)
        case .ammoFactory:
            return ResourceStock(alloy: 6 + bonus * 2, energy: 4 + bonus)
        case .gunTower:
            return ResourceStock(ammo: 5 + bonus * 2)
        case .cannonTower:
            return ResourceStock(energy: 3 + bonus, ammo: 4 + bonus)
        default:
            return ResourceStock()
        }
    }

    static func supplyRadius(for building: BuildingState) -> CGFloat {
        switch building.kind {
        case .core:
            return 3.1
        case .depot:
            return 2.8 + CGFloat(building.level - 1) * 0.45
        default:
            return 0
        }
    }

    static func transportCapacity(for building: BuildingState) -> Int {
        switch building.kind {
        case .core:
            return 3
        case .depot:
            return 1 + building.level
        default:
            return 0
        }
    }

    static func productionInterval(for building: BuildingState) -> CGFloat? {
        switch building.kind {
        case .generator:
            return 2.3 - CGFloat(building.level - 1) * 0.25
        case .mine:
            return 2.0 - CGFloat(building.level - 1) * 0.2
        case .smelter:
            return 3.2 - CGFloat(building.level - 1) * 0.25
        case .ammoFactory:
            return 3.4 - CGFloat(building.level - 1) * 0.25
        default:
            return nil
        }
    }

    static func productionInput(for building: BuildingState) -> ResourceStock {
        switch building.kind {
        case .smelter:
            return ResourceStock(ore: 2, energy: 1)
        case .ammoFactory:
            return ResourceStock(alloy: 2, energy: 1)
        default:
            return ResourceStock()
        }
    }

    static func productionOutput(for building: BuildingState) -> ResourceStock {
        let bonus = max(0, building.level - 1)

        switch building.kind {
        case .generator:
            return ResourceStock(energy: 2 + bonus)
        case .mine:
            return ResourceStock(ore: 2 + bonus)
        case .smelter:
            return ResourceStock(alloy: 2 + bonus)
        case .ammoFactory:
            return ResourceStock(ammo: 3 + bonus)
        default:
            return ResourceStock()
        }
    }

    static func shotCost(for building: BuildingState) -> ResourceStock {
        switch building.kind {
        case .gunTower:
            return ResourceStock(ammo: 1)
        case .cannonTower:
            return ResourceStock(energy: 1, ammo: 2)
        default:
            return ResourceStock()
        }
    }

    static func fireInterval(for building: BuildingState) -> CGFloat {
        switch building.kind {
        case .gunTower:
            return 0.82 - CGFloat(building.level - 1) * 0.08
        case .cannonTower:
            return 1.85 - CGFloat(building.level - 1) * 0.12
        default:
            return 99
        }
    }

    static func range(for building: BuildingState) -> CGFloat {
        switch building.kind {
        case .gunTower:
            return 2.35 + CGFloat(building.level - 1) * 0.22
        case .cannonTower:
            return 3.1 + CGFloat(building.level - 1) * 0.3
        default:
            return 0
        }
    }

    static func damage(for building: BuildingState) -> CGFloat {
        switch building.kind {
        case .gunTower:
            return 13 + CGFloat(building.level - 1) * 3
        case .cannonTower:
            return 24 + CGFloat(building.level - 1) * 6
        default:
            return 0
        }
    }

    static func splashRadius(for building: BuildingState) -> CGFloat {
        switch building.kind {
        case .cannonTower:
            return 0.8 + CGFloat(building.level - 1) * 0.1
        default:
            return 0
        }
    }

    static func enemyDefinition(for kind: EnemyKind) -> EnemyDefinition {
        switch kind {
        case .runner:
            return EnemyDefinition(
                kind: .runner,
                maxHealth: 28,
                speed: 1.08,
                coreDamage: 10,
                reward: ResourceStock(ore: 1)
            )
        case .tank:
            return EnemyDefinition(
                kind: .tank,
                maxHealth: 86,
                speed: 0.58,
                coreDamage: 18,
                reward: ResourceStock(ore: 2, alloy: 1)
            )
        case .saboteur:
            return EnemyDefinition(
                kind: .saboteur,
                maxHealth: 40,
                speed: 0.82,
                coreDamage: 8,
                reward: ResourceStock(alloy: 1, ammo: 1)
            )
        }
    }

    static let saboteurDrain = ResourceStock(energy: 4, ammo: 5)
    static let droneSpeed: CGFloat = 3.2

    static let waves: [WaveDefinition] = [
        WaveDefinition(
            name: "Calibration Raid",
            prepTime: 18,
            reward: ResourceStock(ore: 4, alloy: 2, energy: 4, ammo: 2),
            spawns: [
                WaveSpawn(time: 0.0, kind: .runner, lane: 1),
                WaveSpawn(time: 2.0, kind: .runner, lane: 0),
                WaveSpawn(time: 4.0, kind: .runner, lane: 2),
                WaveSpawn(time: 6.0, kind: .runner, lane: 1),
                WaveSpawn(time: 8.0, kind: .runner, lane: 0),
                WaveSpawn(time: 9.8, kind: .runner, lane: 2)
            ]
        ),
        WaveDefinition(
            name: "Pressure Test",
            prepTime: 14,
            reward: ResourceStock(ore: 5, alloy: 3, energy: 4, ammo: 3),
            spawns: [
                WaveSpawn(time: 0.0, kind: .runner, lane: 0),
                WaveSpawn(time: 1.5, kind: .runner, lane: 2),
                WaveSpawn(time: 3.5, kind: .tank, lane: 1),
                WaveSpawn(time: 5.2, kind: .runner, lane: 1),
                WaveSpawn(time: 6.8, kind: .tank, lane: 0),
                WaveSpawn(time: 8.4, kind: .runner, lane: 2)
            ]
        ),
        WaveDefinition(
            name: "Logistics Breach",
            prepTime: 13,
            reward: ResourceStock(ore: 6, alloy: 4, energy: 5, ammo: 4),
            spawns: [
                WaveSpawn(time: 0.0, kind: .runner, lane: 1),
                WaveSpawn(time: 1.2, kind: .saboteur, lane: 0),
                WaveSpawn(time: 3.5, kind: .runner, lane: 2),
                WaveSpawn(time: 5.0, kind: .tank, lane: 1),
                WaveSpawn(time: 7.0, kind: .saboteur, lane: 2),
                WaveSpawn(time: 9.5, kind: .tank, lane: 0),
                WaveSpawn(time: 11.0, kind: .runner, lane: 1)
            ]
        ),
        WaveDefinition(
            name: "Siege Run",
            prepTime: 12,
            reward: ResourceStock(ore: 8, alloy: 6, energy: 6, ammo: 6),
            spawns: [
                WaveSpawn(time: 0.0, kind: .runner, lane: 0),
                WaveSpawn(time: 0.8, kind: .runner, lane: 2),
                WaveSpawn(time: 2.5, kind: .tank, lane: 1),
                WaveSpawn(time: 4.0, kind: .saboteur, lane: 0),
                WaveSpawn(time: 5.3, kind: .runner, lane: 1),
                WaveSpawn(time: 7.2, kind: .tank, lane: 2),
                WaveSpawn(time: 9.0, kind: .saboteur, lane: 1),
                WaveSpawn(time: 10.2, kind: .tank, lane: 0),
                WaveSpawn(time: 12.4, kind: .runner, lane: 2)
            ]
        )
    ]

    static let startingCoreInventory = ResourceStock(ore: 18, alloy: 14, energy: 18, ammo: 12)
    static let starterTowerInventory = ResourceStock(ammo: 6)
    static let starterDepotInventory = ResourceStock(energy: 4)

    static func isHub(_ kind: BuildingKind) -> Bool {
        kind == .core || kind == .depot
    }

    static func scaled(_ stock: ResourceStock, factor: Int) -> ResourceStock {
        ResourceStock(
            ore: stock.ore * factor,
            alloy: stock.alloy * factor,
            energy: stock.energy * factor,
            ammo: stock.ammo * factor
        )
    }
}
