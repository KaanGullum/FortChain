import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var snapshot: GameSnapshot
    @Published var selectedBlueprint: BuildingKind?

    let scene: GameScene

    init() {
        let scene = GameScene(size: CGSize(width: 1366, height: 768))
        self.scene = scene
        self.snapshot = scene.currentSnapshot
        scene.gameDelegate = self
    }

    func toggleBlueprint(_ kind: BuildingKind) {
        if selectedBlueprint == kind {
            selectedBlueprint = nil
            scene.selectedBlueprint = nil
        } else {
            selectedBlueprint = kind
            scene.selectedBlueprint = kind
        }
    }

    func startGame() {
        scene.startGame()
    }

    func restartGame() {
        selectedBlueprint = nil
        scene.selectedBlueprint = nil
        scene.restartGame()
    }

    func upgradeSelection() {
        scene.upgradeSelectedBuilding()
    }

    func clearSelection() {
        scene.clearSelection()
    }
}

extension GameViewModel: GameSceneDelegate {
    func gameScene(_ scene: GameScene, didUpdate snapshot: GameSnapshot) {
        self.snapshot = snapshot
    }

    func gameSceneDidConsumeSelectedBlueprint(_ scene: GameScene) {
        selectedBlueprint = nil
        scene.selectedBlueprint = nil
    }
}
