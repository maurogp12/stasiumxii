# Phase B+ deployment prototype

**Prototype only. Proposed — not Locked.** Does not change the Phase A live CombatSim duel, fixed seats, or `main.tscn`.

This folder is a sibling of `proto/elevation/`. It is unused by the Phase A combat path.

## How to open

1. Open `project.godot` in Godot 4.7+.
2. Run `scenes/proto_deployment_board.tscn` (File → Open, or `godot --path . res://scenes/proto_deployment_board.tscn`).
3. Do **not** run `main.tscn` for this proto — that scene is still the Phase A hot-seat duel with CombatSim seats already placed.

## How to play the proto

1. Seat 0 (Kestrel) deploys first into the **green** 2×3 box (west, vertically centered).
2. Click a highlighted zone cell to **place**. Click another in-zone empty cell to **reposition**.
3. **Confirm** is enabled only after that seat’s required fighter is placed. Confirm **locks** the side.
4. Seat 1 (Ironjaw) then deploys into the **red** opposite 2×3 box.
5. After both confirm, phase becomes `COMBAT` and the stub `start_match` callback fires (**Turn 1**). There is no combat in this scene.

Occupied / out-of-bounds / not-in-zone clicks are rejected. Walkable means empty in-zone on this flat proto board — no elevation placement gates.

## Headless tests

```bash
godot --headless --path . -s res://tests/run_deployment_proto_tests.gd
```

## Modules

1. `MatchPhase` — enum including `DEPLOYMENT` and `COMBAT`
2. `DeploymentZone` — `player_id` + `Array[Vector2i]` cells; starter `opposite_2x3`
3. `DeploymentManager` — `select_unit`, `can_deploy_unit(unit, tile)`, `place`, `reposition`, `confirm`, `both_ready` → `start_combat`
