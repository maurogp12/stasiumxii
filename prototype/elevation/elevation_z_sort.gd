extends RefCounted
class_name ElevationZSort

## Proposed view-only Z-sort. Separate from gameplay elevation on ProtoBoardTile.
## Phase A CombatSim / board_view still use flat `z_index = x + y`.
## sort_key = world_y + visual_elevation * pixels_per_level (Proposed).

## Proposed: one gameplay level lifts the sprite 16px and adds 16 to the sort key.
const PROPOSED_PIXELS_PER_LEVEL := 16.0
## Matches Phase A iso: (x + y) * 16.
const PROPOSED_ISO_HALF_HEIGHT := 16.0


static func world_y_from_grid(grid_pos: Vector2i, tile_half_height: float = PROPOSED_ISO_HALF_HEIGHT) -> float:
	return float(grid_pos.x + grid_pos.y) * tile_half_height


static func sort_key(world_y: float, visual_elevation: float, pixels_per_level: float = PROPOSED_PIXELS_PER_LEVEL) -> float:
	return world_y + visual_elevation * pixels_per_level


static func sort_key_for_tile(grid_pos: Vector2i, visual_elevation: float) -> float:
	return sort_key(world_y_from_grid(grid_pos), visual_elevation)


static func z_index_for_tile(grid_pos: Vector2i, visual_elevation: float) -> int:
	return int(round(sort_key_for_tile(grid_pos, visual_elevation)))


## Negative if a draws behind b, positive if a draws in front.
static func compare(a_world_y: float, a_visual_elev: float, b_world_y: float, b_visual_elev: float) -> int:
	var a := sort_key(a_world_y, a_visual_elev)
	var b := sort_key(b_world_y, b_visual_elev)
	if a < b:
		return -1
	if a > b:
		return 1
	return 0
