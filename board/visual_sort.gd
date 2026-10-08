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
## Above the tile grid (child z 0) and the highlight overlay (z 1), under the fighter.
const OCCLUDER_Z_BIAS := 2


static func cell_to_local(cell: Vector2i, elevation: float = 0.0) -> Vector2:
	var iso := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)
	iso.y -= elevation * ELEVATION_PIXELS
	return iso


static func tile_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return (cell.x + cell.y) * TILE_Z_SCALE + int(round(elevation * float(ELEVATION_Z_SCALE)))


static func unit_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return tile_z_index(cell, elevation) + UNIT_Z_BIAS


## Same depth as unit_z_index when `local_pos` is that cell's drawn point.
## A walk tween can pass the feet between cells. Facing is not an input:
## the class never decides who is in front.
static func unit_z_from_local(local_pos: Vector2, elevation: float = 0.0) -> int:
	var depth := (local_pos.y + elevation * ELEVATION_PIXELS) / 16.0
	return int(round(depth * float(TILE_Z_SCALE))) + int(round(elevation * float(ELEVATION_Z_SCALE))) + UNIT_Z_BIAS


## True when A is drawn before B (A is behind). Lower depth first, then the
## farther screen point, then the left-hand point. Seat is only the last tie,
## so a class is never pinned to the front.
static func draws_behind(z_a: int, pos_a: Vector2, seat_a: int, z_b: int, pos_b: Vector2, seat_b: int) -> bool:
	if z_a != z_b:
		return z_a < z_b
	if not is_equal_approx(pos_a.y, pos_b.y):
		return pos_a.y < pos_b.y
	if not is_equal_approx(pos_a.x, pos_b.x):
		return pos_a.x < pos_b.x
	return seat_a < seat_b


## Base unit z keeps a fighter above their own tile, and a tall tile adds
## enough z to step in front of the cell one row nearer. That inverts the
## camera: the feet lower on screen are the nearer fighter and must paint
## last. Raise those z values. Never lower one, so a fighter stays above
## the tile they stand on. Shade boosts are applied after this and do not
## propagate. `items` entries are `{z, pos, seat}` and `z` is written back.
static func resolve_camera_z(items: Array) -> void:
	var order: Array = []
	for i in items.size():
		order.append(i)
	order.sort_custom(func(i: int, j: int) -> bool:
		var a: Dictionary = items[i]
		var b: Dictionary = items[j]
		var pa: Vector2 = a["pos"]
		var pb: Vector2 = b["pos"]
		if not is_equal_approx(pa.y, pb.y):
			return pa.y < pb.y
		if not is_equal_approx(pa.x, pb.x):
			return pa.x < pb.x
		return int(a["seat"]) < int(b["seat"])
	)
	var floor_z := -1000000
	for index in order:
		var item: Dictionary = items[index]
		var z := int(item["z"])
		if z <= floor_z:
			z = floor_z + 1
			item["z"] = z
			items[index] = item
		floor_z = z


static func occluder_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return tile_z_index(cell, elevation) + OCCLUDER_Z_BIAS
