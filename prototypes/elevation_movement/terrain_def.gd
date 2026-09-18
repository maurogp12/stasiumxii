extends Resource
class_name TerrainDef

## Phase B+ prototype. Proposed — not Locked.
## Isolated from Phase A CombatSim / main.tscn flat Manhattan walk.

@export var terrain_type: TerrainCatalog.Type = TerrainCatalog.Type.GROUND
@export var display_name: String = "Ground"
@export var base_move_cost: int = 1
@export var walkable: bool = true
