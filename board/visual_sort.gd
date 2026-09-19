class_name BoardVisualSort
extends RefCounted

## VIEW ONLY — not the gameplay elevation source.
## Gameplay elevation lives on the CombatSim snapshot (`elevation` / tile records).
## z_index / draw offset are iso world Y + an elevation offset so taller tiles
## paint in front. CombatSim / walk costs must not read this helper.
## Lifted from proto/elevation/proto_visual_sort.gd.

const ELEVATION_PIXELS := 10.0
const TILE_Z_SCALE := 10
const ELEVATION_Z_SCALE := 8
const UNIT_Z_BIAS := 4


static func cell_to_local(cell: Vector2i, elevation: float = 0.0) -> Vector2:
	var iso := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)
	iso.y -= elevation * ELEVATION_PIXELS
	return iso


static func tile_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return (cell.x + cell.y) * TILE_Z_SCALE + int(round(elevation * float(ELEVATION_Z_SCALE)))


static func unit_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return tile_z_index(cell, elevation) + UNIT_Z_BIAS
