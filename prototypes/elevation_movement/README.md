# Phase B+ elevation + terrain movement prototype

**Proposed — not Locked.** Isolated from the Phase A hot-seat duel.

Phase A behavior on `main.tscn` / `CombatSim` is **unchanged**. That scene still uses a flat 8×8 board and Manhattan `|dx|+|dy|` dest-click walk (pool 3, horizontal-first ortho expansion). Do not set this prototype as the project main scene.

## How to open

1. Open `project.godot` in Godot 4.7 or later.
2. Open `prototypes/elevation_movement/elevation_movement_demo.tscn`.
3. Run **this** scene (F6 / Run Current Scene). Leave `main.tscn` as the main scene.

Click a cyan tile to walk. Numbers on tiles are cheapest MP. Gold is the Dijkstra path. **R** or **Reset** refills the Proposed 6 MP pool and returns the pawn.

## Headless tests

```bash
godot --headless --path . -s res://tests/run_elevation_movement_tests.gd
```

Phase A duel tests are unchanged:

```bash
godot --headless --path . -s res://tests/run_combat_tests.gd
```

## Proposed rules (Director starters)

| Rule | Proposed value |
| --- | --- |
| Ground | 1 MP to enter |
| Mud | 2 MP to enter |
| Water | 2 MP to enter |
| Lava | impassable |
| Uphill | +1 MP per full elevation level; half-level (`+0.5`) counts as +1 |
| Downhill | +0 |
| Equal elevation | terrain cost only |
| Max climb | 1.0 (illegal beyond) |
| Max drop | 2.0 (illegal beyond) |
| Neighbors | ortho N/E/S/W only — no diagonal edges |
| Occupied tiles | blocked |
| Path | Dijkstra cheapest **MP**, not fewest tiles |
| Z-sort | draw order from world Y + elevation (+ unit offset). `z_index` is presentation only — **not** gameplay elevation |

## Modules

| Script | Role |
| --- | --- |
| `board_tile_data.gd` | Resource: `grid_position`, `world_position`, `elevation`, `terrain_type`, `base_move_cost` / `walkable` |
| `terrain_def.gd` / `terrain_catalog.gd` | TerrainDef Resource + Proposed enum table |
| `elevation_rules.gd` | delta, climb/drop caps, uphill surcharge |
| `movement_cost.gd` | `step_mp`, `validate_step`, `validate_move` (bounds, occupied, walkable, elev, MP) |
| `reachability.gd` | reachable tiles from remaining MP |
| `pathfinder.gd` | Dijkstra on ortho weighted edges |
| `z_sort.gd` | draw-order helper |
| `proto_board.gd` | in-memory board + occupancy |

This folder does not touch `backend/combat_sim.gd`, `board_view.gd`, or `board/tile.gd`.
