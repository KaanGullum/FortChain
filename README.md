# FortChain

FortChain is a landscape iOS prototype built with Swift, SwiftUI, and SpriteKit.
It mixes lane defense with a light supply-chain sim:

- Mines extract ore from exposed nodes.
- Smelters turn ore plus energy into alloy.
- Ammo foundries turn alloy plus energy into ammo.
- Towers only keep firing when logistics keeps them supplied.

The MVP goal is a clean, playable vertical slice instead of a one-off scene file.

## What Is Included

- 1 handcrafted map with 3 ore nodes
- 3 enemy lanes that converge on a central base core
- 8 structure types
- 3 enemy types: runner, tank, saboteur
- 4 waves with win and loss conditions
- Visible drone transport between producers and consumers
- A SwiftUI HUD for resources, build actions, alerts, and building inspection
- Upgrade flow for placed buildings

## Architecture

Project layout:

- `FortChain/App/`
  App entry, root view, and view model
- `FortChain/Scenes/`
  SpriteKit scene rendering, tile highlighting, touch handling
- `FortChain/Models/`
  Core enums, state structs, catalog data, balance values, wave definitions
- `FortChain/Systems/`
  Deterministic gameplay simulation for economy, logistics, combat, and waves
- `FortChain/UI/`
  SwiftUI HUD, selection panel, overlays
- `FortChain/Resources/`
  `Info.plist`

Key files:

- `FortChain/Models/GameConfig.swift`
  Central balance and content definitions
- `FortChain/Systems/GameSimulation.swift`
  Gameplay loop, logistics dispatch, production, combat, and wave flow
- `FortChain/Scenes/GameScene.swift`
  Scene rendering and touch-driven placement/select flow
- `FortChain/UI/HUDOverlay.swift`
  Build bar, resource HUD, status overlays, selected building panel

## Core Systems

### 1. Placement and map control

- Buildings can only be placed inside connected hub coverage.
- The base core and depots create the placement/logistics frontier.
- Mines can only be placed on ore nodes.
- Enemy lanes stay reserved and unbuildable.

### 2. Logistics network

- The core and depots form a connected hub graph.
- Buildings outside hub coverage are disconnected and stop functioning.
- Drones visibly move resources between source and destination buildings.
- Tower and factory demand is prioritized before lower-importance transfers.

### 3. Production chain

- Generator -> Energy
- Mine -> Ore
- Smelter consumes Ore + Energy -> Alloy
- Ammo Foundry consumes Alloy + Energy -> Ammo

### 4. Combat loop

- Gun Towers consume ammo per shot.
- Cannon Towers consume ammo and energy per shot.
- Enemies follow fixed lanes toward the base core.
- Saboteurs damage the base and drain supply on breach.

### 5. Wave flow

- Each wave has a countdown, then timed spawns.
- Clearing a wave grants a small refill reward.
- Victory triggers after wave 4 is cleared.
- Defeat triggers when base core health reaches zero.

## How To Run

### In Xcode

1. Open `FortChain.xcodeproj`.
2. Select the `FortChain` scheme.
3. Choose an iPhone or iPad simulator.
4. Run.

The app is built for landscape orientation on iPhone and iPad.

### From the terminal

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project /Users/kaangullu/Desktop/FortChain/FortChain.xcodeproj \
  -scheme FortChain \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FortChainDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## How To Play

1. Launch the mission from the intro overlay.
2. Use the bottom build bar to select a structure.
3. Tap a highlighted tile to place it.
4. Extend toward ore nodes with depots if you need more coverage.
5. Keep the chain flowing so towers do not run dry.
6. Tap a placed building to inspect status, storage, and upgrade options.

## Assumptions and Simplifications

- Transport uses direct drone deliveries instead of full road routing.
- Enemies do not dynamically pathfind around walls.
- Sabotage is represented by a supply drain on breach rather than building-specific hacking.
- Placeholder visuals are all programmatic shapes and colors.
- Economy spending for build/upgrade costs draws from the connected network total.

## Best Next Improvements

- Add a dedicated support structure or barrier unit
- Give saboteurs building-targeted disruption behavior
- Add more map variety and lane modifiers
- Add lightweight audio cues and richer hit feedback
- Surface throughput analytics and bottleneck heatmaps
- Add a between-wave shop or research layer
