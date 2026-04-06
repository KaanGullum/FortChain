import CoreGraphics
import Foundation

enum ResourceKind: String, CaseIterable, Identifiable {
    case ore
    case alloy
    case energy
    case ammo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ore:
            return "Ore"
        case .alloy:
            return "Alloy"
        case .energy:
            return "Energy"
        case .ammo:
            return "Ammo"
        }
    }
}

struct ResourceStock: Equatable {
    var ore: Int
    var alloy: Int
    var energy: Int
    var ammo: Int

    init(ore: Int = 0, alloy: Int = 0, energy: Int = 0, ammo: Int = 0) {
        self.ore = ore
        self.alloy = alloy
        self.energy = energy
        self.ammo = ammo
    }

    subscript(_ kind: ResourceKind) -> Int {
        get {
            switch kind {
            case .ore:
                return ore
            case .alloy:
                return alloy
            case .energy:
                return energy
            case .ammo:
                return ammo
            }
        }
        set {
            switch kind {
            case .ore:
                ore = newValue
            case .alloy:
                alloy = newValue
            case .energy:
                energy = newValue
            case .ammo:
                ammo = newValue
            }
        }
    }

    var isEmpty: Bool {
        ResourceKind.allCases.allSatisfy { self[$0] == 0 }
    }

    mutating func add(_ other: ResourceStock) {
        ore += other.ore
        alloy += other.alloy
        energy += other.energy
        ammo += other.ammo
    }

    mutating func subtract(_ other: ResourceStock) {
        ore = max(0, ore - other.ore)
        alloy = max(0, alloy - other.alloy)
        energy = max(0, energy - other.energy)
        ammo = max(0, ammo - other.ammo)
    }

    func canAfford(_ other: ResourceStock) -> Bool {
        ore >= other.ore &&
            alloy >= other.alloy &&
            energy >= other.energy &&
            ammo >= other.ammo
    }

    func compactDescription() -> String {
        ResourceKind.allCases.compactMap { kind in
            let amount = self[kind]
            guard amount > 0 else { return nil }
            return "\(kind.displayName.prefix(1))\(amount)"
        }
        .joined(separator: " ")
    }

    func lines() -> [String] {
        ResourceKind.allCases.compactMap { kind in
            let amount = self[kind]
            guard amount > 0 else { return nil }
            return "\(kind.displayName): \(amount)"
        }
    }
}

enum BuildingKind: String, CaseIterable, Identifiable {
    case core
    case depot
    case generator
    case mine
    case smelter
    case ammoFactory
    case gunTower
    case cannonTower

    var id: String { rawValue }
}

enum EnemyKind: String, CaseIterable, Identifiable {
    case runner
    case tank
    case saboteur

    var id: String { rawValue }
}

enum GamePhase: Equatable {
    case ready
    case playing
    case won
    case lost
}

enum StatusSeverity {
    case stable
    case warning
    case critical
}

struct GridCoordinate: Hashable {
    var x: Int
    var y: Int

    func distance(to other: GridCoordinate) -> CGFloat {
        hypot(CGFloat(x - other.x), CGFloat(y - other.y))
    }

    var point: CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

struct BuildingCatalogEntry: Identifiable {
    let kind: BuildingKind
    let name: String
    let shortLabel: String
    let description: String
    let buildCost: ResourceStock

    var id: BuildingKind { kind }
}

struct EnemyDefinition {
    let kind: EnemyKind
    let maxHealth: CGFloat
    let speed: CGFloat
    let coreDamage: CGFloat
    let reward: ResourceStock
}

struct WaveSpawn {
    let time: CGFloat
    let kind: EnemyKind
    let lane: Int
}

struct WaveDefinition {
    let name: String
    let prepTime: CGFloat
    let reward: ResourceStock
    let spawns: [WaveSpawn]
}

struct BuildingState: Identifiable {
    let id: UUID
    var kind: BuildingKind
    var coordinate: GridCoordinate
    var health: CGFloat
    var level: Int
    var inventory: ResourceStock
    var cooldownRemaining: CGFloat
    var productionProgress: CGFloat
    var connected: Bool
    var statusText: String
    var statusSeverity: StatusSeverity
}

struct EnemyState: Identifiable {
    let id: UUID
    var kind: EnemyKind
    var lane: Int
    var pathProgress: CGFloat
    var health: CGFloat
}

struct DroneState: Identifiable {
    let id: UUID
    var resource: ResourceKind
    var amount: Int
    var sourceID: UUID
    var destinationID: UUID
    var progress: CGFloat
    var speed: CGFloat
}

struct ProjectileState: Identifiable {
    let id: UUID
    var sourcePoint: CGPoint
    var destinationPoint: CGPoint
    var ttl: CGFloat
    var tintToken: ResourceKind
}

struct AlertState {
    var text: String
    var timeRemaining: CGFloat
}

struct PlacementCheck {
    let isValid: Bool
    let message: String
}

struct ActionResult {
    let success: Bool
    let message: String
}

struct SelectedBuildingSnapshot {
    let id: UUID
    let kind: BuildingKind
    let title: String
    let subtitle: String
    let level: Int
    let healthText: String
    let statusText: String
    let statusSeverity: StatusSeverity
    let inventoryLines: [String]
    let upgradeCostText: String?
    let canUpgrade: Bool
}

struct GameSnapshot {
    var stockpile: ResourceStock
    var phase: GamePhase
    var completedWaves: Int
    var totalWaves: Int
    var activeWaveNumber: Int?
    var countdown: CGFloat?
    var baseHealth: CGFloat
    var baseMaxHealth: CGFloat
    var alertText: String?
    var selectedBuilding: SelectedBuildingSnapshot?

    static let empty = GameSnapshot(
        stockpile: ResourceStock(),
        phase: .ready,
        completedWaves: 0,
        totalWaves: 0,
        activeWaveNumber: nil,
        countdown: nil,
        baseHealth: 0,
        baseMaxHealth: 0,
        alertText: nil,
        selectedBuilding: nil
    )
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
