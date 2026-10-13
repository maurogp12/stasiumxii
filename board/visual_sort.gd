class_name BoardVisualSort
extends RefCounted

## VIEW ONLY — not the gameplay elevation source.
## Gameplay elevation lives on the CombatSim snapshot (`elevation` / tile records).
## z_index / draw offset are iso world Y + an elevation offset so taller tiles
## paint in front. CombatSim / walk costs must not read this helper.
## Lifted from proto/elevation/proto_visual_sort.gd.
##
## A depth line (same x+y) used to share one z. Godot re-sorts equal z whenever
## a pawn, the camera, or a particle dirties the canvas, and the shared edges
## of tiles, lava, snow, and stacked props swapped. Each cell now owns a run
## of slots. Fighters on that line still share one z so screen position, not
## the class, breaks their tie.
##
## Slots inside one cell, low to high:
##   0 hazard (lava / snow / water decal)
##   1 tile body and its grid ink
##   2 highlight overlay (child of the tile)
##   3 elevation block
##   4 prop standing on that block (crystal, pillar, hay)
##   5 raised-top diamond
## The next cell on the line starts 6 above. Fighters sit above every slot on
## their line and under the next line's tiles.

const ELEVATION_PIXELS := 10.0
const TILE_Z_SCALE := 104
const ELEVATION_Z_SCALE := 56
const CELL_Z_STRIDE := 6
const TILE_SLOT := 1
const UNIT_Z_BIAS := 96
## Above the tile grid (child z 0) and the highlight overlay (z 1), under the fighter.
const OCCLUDER_Z_BIAS := 2
## A prop sharing the cell with an elevation block paints on top of that block.
const PROP_Z_BIAS := 3
## Weather, Shade, aim, and floating numbers stay above every board cell,
## including a fighter lifted over the Stormspire shaft. Godot clamps z at 4096.
const WEATHER_Z := 3720
const LIFE_Z := 3820
const SHADE_Z := 3920
const AIM_Z := 4000
const FLOAT_Z := 4080


static func cell_to_local(cell: Vector2i, elevation: float = 0.0) -> Vector2:
	var iso := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)
	iso.y -= elevation * ELEVATION_PIXELS
	return iso


static func _depth_z(cell: Vector2i, elevation: float) -> int:
	return (cell.x + cell.y) * TILE_Z_SCALE + int(round(elevation * float(ELEVATION_Z_SCALE)))


static func _cell_slot(cell: Vector2i) -> int:
	return cell.x * CELL_Z_STRIDE


static func tile_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return _depth_z(cell, elevation) + _cell_slot(cell) + TILE_SLOT


## Lava, snow, and water decals sit in the cell, under its grid ink.
static func hazard_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return tile_z_index(cell, elevation) - TILE_SLOT


static func unit_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return _depth_z(cell, elevation) + UNIT_Z_BIAS


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


static func prop_z_index(cell: Vector2i, elevation: float = 0.0) -> int:
	return tile_z_index(cell, elevation) + PROP_Z_BIAS


## Window pixels per canvas pixel. A 1080-tall phone stretches the 720-tall
## canvas by 1.5, so a whole canvas pixel is a half device pixel. Passing a
## zero window (a headless node with no frame yet) keeps the canvas snap.
static func viewport_pixel_scale(view_size: Vector2, window_size: Vector2) -> Vector2:
	if view_size.x < 1.0 or view_size.y < 1.0 or window_size.x < 64.0 or window_size.y < 64.0:
		return Vector2.ONE
	return Vector2(window_size.x / view_size.x, window_size.y / view_size.y)


## Whole device pixels. A fractional camera makes linear-filtered plates crawl.
## Snapping only the canvas pixel still lands on a half device pixel every
## other pan step when the phone scale is 1.5, and the ice edges swap
## brightness. `pixel_scale` is window pixels per canvas pixel. Idempotent.
static func snap_camera_position(pos: Vector2, zoom: Vector2, view_size: Vector2, pixel_scale: Vector2 = Vector2.ONE) -> Vector2:
	if is_zero_approx(zoom.x) or is_zero_approx(zoom.y):
		return pos
	var scale := pixel_scale
	if scale.x < 0.01 or scale.y < 0.01:
		scale = Vector2.ONE
	var center := view_size * 0.5
	var origin := Vector2(center.x - pos.x * zoom.x, center.y - pos.y * zoom.y)
	var device := Vector2(origin.x * scale.x, origin.y * scale.y)
	var snapped_device := Vector2(roundf(device.x), roundf(device.y))
	var snapped := Vector2(snapped_device.x / scale.x, snapped_device.y / scale.y)
	return Vector2((center.x - snapped.x) / zoom.x, (center.y - snapped.y) / zoom.y)


## Decor authored at half pixels shimmers under a linear filter. Land on a pixel.
static func snap_point(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x), roundf(point.y))


## Screen shake stays on a parent, not the camera. Whole screen pixels so the
## snapped canvas shifts every tile by the same amount. A fractional camera
## offset re-rounds each tile on its own and the shared edges swap or drop.
const SHAKE_CULL_MARGIN := 96.0
## Containers keep a stable rect. A merged child rect goes empty for a frame
## when the view shifts, and the whole diamond vanishes onto the sky.
const SHAKE_PARENT_RECT := Rect2(-2400, -2400, 4800, 4800)


static func shake_screen(raw: Vector2) -> Vector2:
	return Vector2(roundf(raw.x), roundf(raw.y))


## `screen` is phone pixels. The parent offset is world pixels, so the picture
## moves by exactly those screen pixels at the current zoom.
static func shake_world_offset(screen: Vector2, zoom: float) -> Vector2:
	return shake_screen(screen) / maxf(zoom, 0.001)


static func pin_cull_rect(item: CanvasItem) -> void:
	if item == null or not item.is_inside_tree():
		return
	RenderingServer.canvas_item_set_custom_rect(item.get_canvas_item(), true, SHAKE_PARENT_RECT)


## Grow a drawn tile or prop once. A second call would pad the already padded
## rect. Empty rects (not drawn yet) are left alone so a later pass can measure.
static func grow_cull_rect(item: CanvasItem) -> void:
	if item == null or not item.is_inside_tree() or item.has_meta("shake_cull"):
		return
	var rect := Rect2()
	if item is Sprite2D:
		rect = (item as Sprite2D).get_rect()
	else:
		rect = RenderingServer.debug_canvas_item_get_rect(item.get_canvas_item())
	if rect.size.x < 1.0 and rect.size.y < 1.0:
		return
	RenderingServer.canvas_item_set_custom_rect(item.get_canvas_item(), true, rect.grow(SHAKE_CULL_MARGIN))
	item.set_meta("shake_cull", true)


## Child order matches draw order, so an equal-z pair (two fighters on one
## depth line) stays put when the canvas sorts again.
static func order_children(parent: Node) -> void:
	if parent == null:
		return
	var items: Array[CanvasItem] = []
	for child in parent.get_children():
		if child is CanvasItem:
			items.append(child)
	if items.size() < 2:
		return
	items.sort_custom(func(a: CanvasItem, b: CanvasItem) -> bool:
		if a.z_index != b.z_index:
			return a.z_index < b.z_index
		if not is_equal_approx(a.position.y, b.position.y):
			return a.position.y < b.position.y
		if not is_equal_approx(a.position.x, b.position.x):
			return a.position.x < b.position.x
		return str(a.name) < str(b.name)
	)
	var same := true
	var index := 0
	for child in parent.get_children():
		if not (child is CanvasItem):
			continue
		if child != items[index]:
			same = false
			break
		index += 1
	if same:
		return
	for i in items.size():
		parent.move_child(items[i], i)
