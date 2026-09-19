extends RefCounted

## Live tile DATA. Ported from proto/elevation/board_tile_data.gd (reference).
## Locked schema: grid_pos, elevation (float), terrain_type, optional walkable override.

const _TerrainDef := preload("res://backend/terrain_def.gd")

var grid_pos: Vector2i = Vector2i.ZERO
var elevation: float = 0.0
var terrain_type: int = _TerrainDef.Id.GROUND
## Optional override. null = use terrain walkable.
var walkable_override: Variant = null


func is_walkable(terrain: Dictionary) -> bool:
	if walkable_override != null:
		return bool(walkable_override)
	return bool(terrain.get("walkable", true))


func snapshot() -> Dictionary:
	var terrain: Dictionary = _TerrainDef.by_id(terrain_type)
	return {
		"pos": grid_pos,
		"elevation": elevation,
		"terrain_type": _TerrainDef.name_of(terrain_type),
		"walkable": is_walkable(terrain),
	}
