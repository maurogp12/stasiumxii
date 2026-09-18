class_name ProtoVisualSort
extends RefCounted

## VIEW ONLY — not the gameplay elevation source.
## Gameplay elevation lives on BoardTileData.elevation and ElevationCost.
## z_index / draw offset are a function of iso world Y + an elevation offset
## so taller tiles/pawns paint in front. ProtoMoveSim must not read this.

const ELEVATION_PIXELS := 10.0
const TILE_Z_SCALE := 10
const ELEVATION_Z_SCALE := 8
const UNIT_Z_BIAS := 4


static func cell_to_local(cell: Vector2i, elevation: float) -> Vector2:
	var iso := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)
	iso.y -= elevation * ELEVATION_PIXELS
	return iso


static func tile_z_index(cell: Vector2i, elevation: float) -> int:
	return (cell.x + cell.y) * TILE_Z_SCALE + int(round(elevation * float(ELEVATION_Z_SCALE)))


static func unit_z_index(cell: Vector2i, elevation: float) -> int:
	return tile_z_index(cell, elevation) + UNIT_Z_BIAS
