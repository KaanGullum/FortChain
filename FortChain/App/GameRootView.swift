import SpriteKit
import SwiftUI

struct GameRootView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            SpriteView(scene: viewModel.scene)
                .ignoresSafeArea()

            HUDOverlay(
                snapshot: viewModel.snapshot,
                selectedBlueprint: viewModel.selectedBlueprint,
                onSelectBuild: viewModel.toggleBlueprint,
                onStart: viewModel.startGame,
                onRestart: viewModel.restartGame,
                onUpgrade: viewModel.upgradeSelection
            )
        }
        .preferredColorScheme(.dark)
    }
}
