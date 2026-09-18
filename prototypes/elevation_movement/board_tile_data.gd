extends Resource
class_name BoardTileData

## Phase B+ prototype tile payload. Proposed — not Locked.
## Named BoardTileData so Phase A's BoardTile Node2D stays untouched.
## Gameplay elevation lives here — never on Node2D.z_index.

@export var grid_position: Vector2i = Vector2i.ZERO
@export var world_position: Vector2 = Vector2.ZERO
@export var elevation: float = 0.0
@export var terrain_type: TerrainCatalog.Type = TerrainCatalog.Type.GROUND
@export var base_move_cost: int = 1
@export var walkable: bool = true


func apply_terrain_defaults() -> void:
	var d := TerrainCatalog.def(terrain_type)
	base_move_cost = d.base_move_cost
	walkable = d.walkable


static func make(cell: Vector2i, elev: float, terrain: TerrainCatalog.Type, world: Vector2 = Vector2.ZERO) -> BoardTileData:
	var tile := BoardTileData.new()
	tile.grid_position = cell
	tile.world_position = world
	tile.elevation = elev
	tile.terrain_type = terrain
	tile.apply_terrain_defaults()
	return tile
