# Development Notes

## MVP Simplifications

- Logistics is hub-radius based rather than road-graph based.
- Drones travel directly from source to destination once both buildings are connected.
- Enemies follow handcrafted lane splines instead of pathfinding.
- The build/upgrade economy spends from the connected stockpile total.
- Combat uses immediate-hit projectiles with short-lived visual tracers.

## Balance Tuning Lives Here

Primary tuning values are centralized in:

- `FortChain/Models/GameConfig.swift`

That file controls:

- building costs
- upgrade costs
- storage capacities
- production intervals
- production inputs and outputs
- tower range, damage, and fire rate
- enemy health, speed, and breach damage
- wave spawn timing and rewards
- starting resources and starter structures

## Manual Validation Checklist

- Build mode: select a structure from the HUD and place it on a highlighted tile
- Logistics: place a mine, smelter, and ammo foundry and confirm drones move resources
- Combat: verify gun towers stop firing if ammo is missing
- Heavy defense: verify cannon towers need both ammo and energy
- Wave flow: verify countdowns, wave completion rewards, and final victory
- Failure state: let enemies leak through and confirm base loss triggers

## Best Next Engineering Steps

- Split the simulation into smaller economy/combat/wave subsystems if the prototype grows
- Add serialization for repeatable map scenarios
- Add a lightweight debug overlay for inventories and active transport reservations
- Add automated balance tests for wave solvability and economy startup pacing
