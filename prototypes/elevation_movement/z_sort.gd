extends RefCounted
class_name ZSortHelper

## Phase B+ prototype. Proposed — not Locked.
## Draw order is presentation only.
## Do NOT use Node2D.z_index as gameplay elevation — read BoardTileData.elevation.

## Proposed: pixels of visual rise per elevation unit (screen-up).
const ELEVATION_Y_PX: float = 14.0
## Proposed: bias so a unit paints in front of its own tile.
const UNIT_DRAW_BIAS: float = 8.0


static func visual_y_offset(elevation: float) -> float:
	return -elevation * ELEVATION_Y_PX


## Larger value draws in front. Uses footprint world Y + elevation, never z_index.
static func draw_order(world_position: Vector2, elevation: float, unit_offset: float = 0.0) -> float:
	return world_position.y + elevation * ELEVATION_Y_PX + unit_offset


static func draw_order_index(world_position: Vector2, elevation: float, unit_offset: float = 0.0) -> int:
	return int(round(draw_order(world_position, elevation, unit_offset) * 10.0))
