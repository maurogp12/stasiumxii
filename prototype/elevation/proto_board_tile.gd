extends RefCounted
class_name ProtoBoardTile

## Proposed BoardTile-like *data* class for Phase B+ (not the Phase A visual
## `BoardTile` in board/tile.gd). Fields: grid_pos, elevation, terrain_type,
## base_move_cost, walkable.
## Gameplay elevation lives here. View Z-sort uses ElevationZSort separately.

var grid_pos: Vector2i = Vector2i.ZERO
## Proposed gameplay elevation: Ground 0, half 0.5, full 1, …
var elevation: float = 0.0
var terrain_type: TerrainDef.Kind = TerrainDef.Kind.GROUND
## Proposed MP to enter this tile (copied from TerrainDef).
var base_move_cost: int = 1
var walkable: bool = true


static func from_def(pos: Vector2i, def: TerrainDef, elevation: float = 0.0) -> ProtoBoardTile:
	var tile := ProtoBoardTile.new()
	tile.grid_pos = pos
	tile.elevation = elevation
	tile.terrain_type = def.kind
	tile.base_move_cost = def.base_move_cost
	tile.walkable = def.walkable
	return tile


static func proposed(pos: Vector2i, kind_id: TerrainDef.Kind, elevation: float = 0.0) -> ProtoBoardTile:
	return from_def(pos, TerrainDef.proposed(kind_id), elevation)


func duplicate_tile() -> ProtoBoardTile:
	var copy := ProtoBoardTile.new()
	copy.grid_pos = grid_pos
	copy.elevation = elevation
	copy.terrain_type = terrain_type
	copy.base_move_cost = base_move_cost
	copy.walkable = walkable
	return copy
