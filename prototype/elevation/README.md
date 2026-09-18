# Phase B+ elevation / terrain prototype (Proposed)

This folder is **scaffolding only**. It does **not** change the live Phase A hot-seat duel.

- Phase A walk stays Locked Manhattan dest-click (`CombatSim.submit(move)`).
- `project.godot` `run/main_scene` is still `res://main.tscn`.
- Nothing in `backend/combat_sim.gd` imports these scripts.

All MP, climb, and drop numbers here are **Proposed**, not Locked.

## How to open (without affecting the main duel)

1. Open `project.godot` in Godot 4.7+ as usual.
2. **File → Open** `prototype/elevation/proto_scene.tscn`.
3. **Run Current Scene** (F6). Do **not** use F5 / Run Project if you want the duel — F5 still launches `main.tscn`.

Headless / CLI:

```bash
# Isolated prototype scene (does not replace the duel)
godot --path . res://prototype/elevation/proto_scene.tscn

# Prototype tests only
godot --headless --path . -s res://tests/run_elevation_proto_tests.gd

# Phase A duel tests (unchanged)
godot --headless --path . -s res://tests/run_combat_tests.gd
```

## What the scene shows

- Iso tiles colored by **Proposed** terrain: Ground, Mud (2 MP), Water (2 MP), Lava (impassable).
- Pillar height is **view elevation** (Z-sort helper). Gameplay elevation is the 0 / 0.5 / 1 / 2 values on `ProtoBoardTile`.
- Default origin `(0,0)` with MP budget **6**: dest `(4,0)` is reachable on the long Ground wrap (6 MP), not the muddy short row (7 MP).
- Left-click a tile to set origin. Click a cyan reachable tile to preview the cheapest ortho path.
- `[` / `]` or `-` / `=` change remaining MP. `R` resets to `(0,0)`.

## Proposed starters (not Locked)

| Rule | Proposed value |
| --- | --- |
| Terrain MP | Ground 1, Mud 2, Water 2, Lava impassable |
| Elevation | Ground 0, half 0.5, full 1, … |
| Uphill | +1 MP per full level; leftover half step +1 |
| Downhill | 0 |
| Max climb / drop | 1 / 2 |
| Neighbors | Ortho only |
| Z-sort | `world_y + visual_elevation * 16` (view only) |

## Scripts

| File | Role |
| --- | --- |
| `terrain_def.gd` | `TerrainDef` Resource + `Kind` enum |
| `proto_board_tile.gd` | BoardTile-like data: `grid_pos`, `elevation`, `terrain_type`, `base_move_cost`, `walkable` |
| `elevation_rules.gd` | Elevation MP + max climb/drop checks |
| `movement_cost.gd` | `MovementCost.calculate(from, to)` |
| `proto_pathfinder.gd` | Ortho edge weight + Dijkstra reachable tiles |
| `elevation_z_sort.gd` | View-only sort key |
| `proto_board.gd` | Sample maps (mud detour + demo) |
| `proto_scene.tscn` | Minimal playground |

Do not call these from `CombatSim.submit(move)` until a later Locked slice.
