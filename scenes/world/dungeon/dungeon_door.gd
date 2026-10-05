extends Node2D

## VIEW ONLY. A dungeon entrance in town: the building on its footprint and
## the clickable hatch on the door cell, which glows while hovered.
## Art comes from the dungeon's art manifest (building entry); without it a
## drawn placeholder granary stands in. Walking rules live in the world
## (the footprint is blocked in the WorldZone, the hatch stays passable).

const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const Dungeons := preload("res://backend/world_dungeons.gd")

var dungeon_id := ""
var dungeon: Dictionary = {}
var door_cell := Vector2i(-1, -1)
var footprint: Array[Vector2i] = []
var hovered := false
var painted := false
var _building: Node2D
var _hatch: Node2D
var _tex: Texture2D
var _entry: Dictionary = {}
var _glow_t := 0.0


class Painter extends Node2D:
	var host
	var part := ""

	func _draw() -> void:
		if host == null:
			return
		if part == "building":
			host._draw_building(self)
		else:
			host._draw_hatch(self)


## `origin` is the chunk's plane offset (world cell of its 0,0).
func setup(row: Dictionary, man: Dictionary, origin: Vector2i = Vector2i.ZERO) -> void:
	dungeon = row.duplicate(true)
	dungeon_id = str(row.get("id", ""))
	door_cell = Dungeons.door_cell(row)
	var size := Art.building_size(man, Dungeons.DEFAULT_BUILDING)
	footprint = Dungeons.building_cells(row, size)
	_entry = Art.building(man)
	_tex = Art.texture(_entry) if not _entry.is_empty() else null
	painted = _tex != null
	name = "Door_%s" % dungeon_id
	z_as_relative = false
	var b := Painter.new()
	b.host = self
	b.part = "building"
	_building = b
	_building.name = "Building"
	_building.z_as_relative = false
	add_child(_building)
	var h := Painter.new()
	h.host = self
	h.part = "hatch"
	_hatch = h
	_hatch.name = "Hatch"
	_hatch.z_as_relative = false
	add_child(_hatch)
	place(origin)


func place(origin: Vector2i) -> void:
	var south := _south_cell()
	var world_south := origin + south
	_building.position = BoardVisualSort.cell_to_local(world_south) + Vector2(0, 16)
	_building.z_index = clampi((world_south.x + world_south.y) * BoardVisualSort.TILE_Z_SCALE + 2, -4096, 4096)
	var world_door := origin + door_cell
	_hatch.position = BoardVisualSort.cell_to_local(world_door)
	_hatch.z_index = clampi((world_door.x + world_door.y) * BoardVisualSort.TILE_Z_SCALE + 1, -4096, 4096)
	_building.queue_redraw()
	_hatch.queue_redraw()


func covers(cell: Vector2i) -> bool:
	return cell == door_cell or footprint.has(cell)


func set_hovered(on: bool) -> void:
	if hovered == on:
		return
	hovered = on
	_hatch.queue_redraw()
	_building.queue_redraw()


func _process(delta: float) -> void:
	_glow_t += delta
	if hovered or not painted:
		_hatch.queue_redraw()


func _south_cell() -> Vector2i:
	var best := door_cell + Vector2i(0, -1)
	for c in footprint:
		if c.x + c.y > best.x + best.y or (c.x + c.y == best.x + best.y and c.x > best.x):
			best = c
	return best


func _fp_size() -> Vector2i:
	var xs := {}
	var ys := {}
	for c in footprint:
		xs[c.x] = true
		ys[c.y] = true
	return Vector2i(maxi(xs.size(), 1), maxi(ys.size(), 1))


func _draw_building(c: CanvasItem) -> void:
	if _tex != null:
		var size := _tex.get_size()
		var scale_by := float(_entry.get("scale", 0.0))
		if scale_by <= 0.0:
			var fp := _fp_size()
			scale_by = float((fp.x + fp.y) * 32) / maxf(size.x, 1.0)
			if str(_entry.get("path", "")).contains("2x"):
				scale_by = minf(scale_by, 0.5)
		var pivot: Vector2 = _entry.get("pivot", Vector2(-1, -1))
		if pivot.x < 0:
			pivot = Vector2(size.x * 0.5, size.y)
		var dest := Rect2(-pivot * scale_by, size * scale_by)
		c.draw_texture_rect(_tex, dest, false, Color(1.12, 1.08, 1.0) if hovered else Color.WHITE)
		return
	_draw_placeholder_granary(c)


## Placeholder granary: stone footing, plank walls, a thatched hip roof, a rat
## sign and a lantern. Drawn on the footprint so its size matches the cells.
func _draw_placeholder_granary(c: CanvasItem) -> void:
	var fp := _fp_size()
	var w := float(fp.x)
	var d := float(fp.y)
	# Local frame: (0,0) is the footprint's south tip. Fewer y runs up-right
	# (p_e, d rows), fewer x runs up-left (p_w, w columns).
	var p_s := Vector2.ZERO
	var p_e := Vector2(32, -16) * d
	var p_w := Vector2(-32, -16) * w
	var p_n := p_w + Vector2(32, -16) * d
	var wall_h := 58.0
	var up := Vector2(0, -wall_h)
	var shadow := PackedVector2Array([p_s + Vector2(0, 6), p_e + Vector2(10, 4), p_n + Vector2(10, -2), p_w + Vector2(-8, 4)])
	c.draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	# Stone footing.
	var foot := Vector2(0, -10)
	c.draw_colored_polygon(PackedVector2Array([p_w, p_s, p_s + foot, p_w + foot]), Color(0.47, 0.45, 0.42))
	c.draw_colored_polygon(PackedVector2Array([p_s, p_e, p_e + foot, p_s + foot]), Color(0.56, 0.54, 0.5))
	# Plank walls (south-west face darker, south-east face lit).
	c.draw_colored_polygon(PackedVector2Array([p_w + foot, p_s + foot, p_s + up, p_w + up]), Color(0.46, 0.31, 0.18))
	c.draw_colored_polygon(PackedVector2Array([p_s + foot, p_e + foot, p_e + up, p_s + up]), Color(0.6, 0.42, 0.24))
	for k in range(1, 8):
		var t := float(k) / 8.0
		c.draw_line(p_w.lerp(p_s, t) + foot, p_w.lerp(p_s, t) + up, Color(0.32, 0.21, 0.12), 1.0)
		c.draw_line(p_s.lerp(p_e, t) + foot, p_s.lerp(p_e, t) + up, Color(0.42, 0.28, 0.15), 1.0)
	# Loft door on the lit face.
	var mid := p_s.lerp(p_e, 0.5)
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(-12, -18), mid + Vector2(12, -30), mid + Vector2(12, -52), mid + Vector2(-12, -40)]), Color(0.28, 0.18, 0.1))
	# Hip roof of thatch.
	var ridge := (p_w + p_e) * 0.5 + up + Vector2(0, -44)
	var eave := 8.0
	var rs := p_s + up + Vector2(0, eave)
	var re := p_e + up + Vector2(eave, 0)
	var rw := p_w + up + Vector2(-eave, 0)
	var rn := p_n + up
	c.draw_colored_polygon(PackedVector2Array([rw, rs, ridge]), Color(0.73, 0.58, 0.28))
	c.draw_colored_polygon(PackedVector2Array([rs, re, ridge]), Color(0.86, 0.7, 0.36))
	c.draw_colored_polygon(PackedVector2Array([re, rn, ridge]), Color(0.7, 0.55, 0.27))
	for k in range(1, 6):
		var t2 := float(k) / 6.0
		c.draw_line(rw.lerp(rs, t2), ridge, Color(0.6, 0.46, 0.2), 1.0)
		c.draw_line(rs.lerp(re, t2), ridge, Color(0.72, 0.56, 0.25), 1.0)
	# Rat sign on a post by the hatch side.
	var sign_at := p_s.lerp(p_w, 0.25) + Vector2(-6, -66)
	c.draw_rect(Rect2(sign_at + Vector2(-14, -10), Vector2(28, 18)), Color(0.55, 0.38, 0.2))
	c.draw_rect(Rect2(sign_at + Vector2(-14, -10), Vector2(28, 18)), Color(0.25, 0.15, 0.08), false, 1.5)
	c.draw_circle(sign_at + Vector2(-2, 0), 5.0, Color(0.2, 0.17, 0.15))
	c.draw_circle(sign_at + Vector2(5, -2), 3.0, Color(0.2, 0.17, 0.15))
	c.draw_line(sign_at + Vector2(-7, 2), sign_at + Vector2(-13, 6), Color(0.2, 0.17, 0.15), 1.5)
	# Lantern.
	var lamp := p_s + Vector2(-4, -44)
	var pulse := 0.85 + 0.15 * sin(_glow_t * 3.0)
	c.draw_circle(lamp, 13.0, Color(1.0, 0.7, 0.3, 0.18 * pulse))
	c.draw_circle(lamp, 4.5, Color(1.0, 0.82, 0.42))


func _draw_hatch(cv: CanvasItem) -> void:
	# Cellar hatch on the door cell: open boards, stairs down into a warm glow.
	var c := Vector2.ZERO
	var outer := PackedVector2Array([c + Vector2(0, -12), c + Vector2(24, 0), c + Vector2(0, 12), c + Vector2(-24, 0)])
	var inner := PackedVector2Array([c + Vector2(0, -8), c + Vector2(16, 0), c + Vector2(0, 8), c + Vector2(-16, 0)])
	if not painted:
		cv.draw_colored_polygon(outer, Color(0.42, 0.29, 0.16))
		cv.draw_colored_polygon(inner, Color(0.12, 0.08, 0.05))
		for k in 3:
			var t := 0.25 + 0.22 * float(k)
			cv.draw_line(inner[3].lerp(inner[0], t), inner[2].lerp(inner[1], t), Color(0.55, 0.37, 0.2), 2.0)
		cv.draw_colored_polygon(inner, Color(1.0, 0.62, 0.22, 0.18 + 0.06 * sin(_glow_t * 2.0)))
		# Open lid leaning back.
		cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 0), c + Vector2(0, -8), c + Vector2(-4, -30), c + Vector2(-20, -22)]), Color(0.5, 0.34, 0.18))
	if hovered:
		var pulse := 0.6 + 0.4 * sin(_glow_t * 5.0)
		var glow := PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0), c + Vector2(0, 16), c + Vector2(-32, 0)])
		cv.draw_colored_polygon(glow, Color(1.0, 0.75, 0.3, 0.22 + 0.18 * pulse))
		var ring := PackedVector2Array(glow)
		ring.append(glow[0])
		cv.draw_polyline(ring, Color(1.0, 0.85, 0.45, 0.95), 2.5)
