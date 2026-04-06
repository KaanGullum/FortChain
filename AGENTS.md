# AGENTS.md

## Project Intent

This repository contains a playable iOS prototype for a logistics-driven base defense game.
The identity of the game is:

- logistics before firepower
- readable mobile controls
- modular SpriteKit gameplay with SwiftUI shell/HUD

If you change the game, preserve that identity.

## Tech Expectations

- Language: Swift
- Gameplay scene: SpriteKit
- HUD / shell: SwiftUI
- Platform: iOS
- Orientation: landscape
- Dependencies: avoid third-party packages unless clearly necessary

## Codebase Guide

- `FortChain/Models/GameModels.swift`
  Core data structures and shared types
- `FortChain/Models/GameConfig.swift`
  Content definitions and almost all balance values
- `FortChain/Systems/GameSimulation.swift`
  Deterministic update loop for economy, transport, combat, and waves
- `FortChain/Scenes/GameScene.swift`
  Rendering, touch mapping, and node synchronization
- `FortChain/UI/HUDOverlay.swift`
  SwiftUI HUD and selection overlays

## Working Rules

- Keep gameplay values centralized in `GameConfig.swift`
- Prefer explicit logic over abstract generic systems
- Do not turn `GameScene` into a god object
- Keep transport, wave, and combat rules understandable at a glance
- Favor readability over cleverness
- Use comments sparingly and only for non-obvious logic

## Gameplay Rules To Preserve

- At least one major tower must require ammo
- At least one major tower must require both ammo and energy
- Logistics breakdown should be visible and explainable
- Depots must matter for expansion
- The player should be able to lose because supply failed, not only because DPS was low

## Validation Expectations

Before calling a gameplay change done:

- build the project
- confirm placement still works
- confirm drones still move resources
- confirm towers still respect supply limits
- confirm wave progression still reaches win/lose outcomes
