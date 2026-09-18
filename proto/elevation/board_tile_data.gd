class_name BoardTileData
extends RefCounted

## Phase B+ tile DATA (not the Phase A BoardTile view node).
## Proposed schema: grid_pos, elevation (float), terrain_type, optional walkable override.

var grid_pos: Vector2i = Vector2i.ZERO
var elevation: float = 0.0
var terrain_type: TerrainDef.Id = TerrainDef.Id.GROUND
## Optional override. null = use TerrainDef.walkable.
var walkable_override: Variant = null


func is_walkable(terrain: TerrainDef) -> bool:
	if walkable_override != null:
		return bool(walkable_override)
	return terrain.walkable


func duplicate_data() -> BoardTileData:
	var copy := BoardTileData.new()
	copy.grid_pos = grid_pos
	copy.elevation = elevation
	copy.terrain_type = terrain_type
	copy.walkable_override = walkable_override
	return copy
