extends Node2D

## VIEW ONLY. One blocking prop on a dungeon board (crate, sacks, barrel,
## throne...), standing on its cell's south tip like the board's units, plus
## the room backdrop (walls and lit edges on a dark surround) behind the board.
## Art from the manifest when present, else drawn placeholders.

const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")

var kind := ""
var cell := Vector2i.ZERO
var tex: Texture2D
var entry: Dictionary = {}


func setup(prop_kind: String, at: Vector2i, man: Dictionary, room_id: String) -> void:
	kind = prop_kind
	cell = at
	name = "Prop_%s_%d_%d" % [kind, at.x, at.y]
	for e in Art.room_props(man, room_id):
		if (e["cell"] as Vector2i) == at or (e["cells"] as Array).has(at):
			entry = e
			break
	if entry.is_empty():
		for e in Art.room_props(man, room_id):
			if str(e["text"]).contains(kind):
				entry = e
				break
	if entry.is_empty():
		entry = Art.find(man, ["prop", kind])
	tex = Art.texture(entry) if not entry.is_empty() else null
	queue_redraw()


func _draw() -> void:
	if tex != null:
		var size := tex.get_size()
		var s := float(entry.get("scale", 0.0))
		if s <= 0.0:
			s = 72.0 / maxf(size.x, 1.0)
		var pivot: Vector2 = entry.get("pivot", Vector2(-1, -1))
		if pivot.x < 0:
			pivot = Vector2(size.x * 0.5, size.y)
		draw_texture_rect(tex, Rect2(Vector2(0, 14) - pivot * s, size * s), false)
		return
	_draw_placeholder()


func _draw_placeholder() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(26, 0), Vector2(0, 13), Vector2(-26, 0)]), Color(0, 0, 0, 0.3))
	match kind:
		"crate", "crate_stack":
			var h := 30.0 if kind == "crate" else 54.0
			_box(Vector2(0, 8), 20.0, h, Color(0.62, 0.44, 0.24))
			if kind == "crate_stack":
				_box(Vector2(2, 8 - 30), 15.0, 22.0, Color(0.56, 0.39, 0.21))
		"barrel":
			_barrel(Vector2(0, 6), 15.0, 34.0)
		"sack", "sack_pile", "bone_pile":
			var col := Color(0.76, 0.66, 0.46) if kind != "bone_pile" else Color(0.86, 0.83, 0.74)
			_sack(Vector2(-8, 2), 13.0, col)
			_sack(Vector2(9, 4), 12.0, col.darkened(0.08))
			if kind == "sack_pile":
				_sack(Vector2(0, -14), 12.0, col.lightened(0.05))
			if kind == "bone_pile":
				draw_line(Vector2(-14, -10), Vector2(10, -2), Color(0.95, 0.93, 0.86), 3.0)
				draw_circle(Vector2(-2, -18), 6.0, Color(0.93, 0.9, 0.82))
		"lantern_post":
			draw_rect(Rect2(-3, -58, 6, 66), Color(0.35, 0.24, 0.13))
			draw_circle(Vector2(0, -62), 16.0, Color(1.0, 0.7, 0.3, 0.25))
			draw_rect(Rect2(-6, -68, 12, 12), Color(1.0, 0.82, 0.45))
		"tool_rack":
			draw_rect(Rect2(-22, -54, 44, 6), Color(0.4, 0.27, 0.14))
			for k in 3:
				var x := -14.0 + k * 14.0
				draw_line(Vector2(x, -50), Vector2(x, 6), Color(0.45, 0.31, 0.16), 3.0)
			draw_line(Vector2(-14, -50), Vector2(-24, -40), Color(0.75, 0.77, 0.8), 3.0)
			draw_line(Vector2(14, -50), Vector2(22, -34), Color(0.75, 0.77, 0.8), 3.0)
		"throne":
			_sack(Vector2(0, 2), 22.0, Color(0.62, 0.5, 0.34))
			_box(Vector2(0, -10), 14.0, 44.0, Color(0.45, 0.34, 0.22))
			draw_circle(Vector2(-10, -58), 5.0, Color(0.92, 0.9, 0.82))
			draw_circle(Vector2(10, -58), 5.0, Color(0.92, 0.9, 0.82))
		_:
			_box(Vector2(0, 8), 18.0, 26.0, Color(0.5, 0.42, 0.34))


func _box(base: Vector2, half: float, h: float, col: Color) -> void:
	var w := half
	var top := Vector2(0, -h)
	var s := base
	var e := base + Vector2(w, -w * 0.5)
	var n := base + Vector2(0, -w)
	var wv := base + Vector2(-w, -w * 0.5)
	draw_colored_polygon(PackedVector2Array([wv, s, s + top, wv + top]), col.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([s, e, e + top, s + top]), col)
	draw_colored_polygon(PackedVector2Array([wv + top, s + top, e + top, n + top]), col.lightened(0.18))
	draw_polyline(PackedVector2Array([wv + top, s + top, e + top, n + top, wv + top]), col.darkened(0.5), 1.0)
	draw_line(s, s + top, col.darkened(0.5), 1.0)


func _barrel(base: Vector2, r: float, h: float) -> void:
	var col := Color(0.55, 0.36, 0.2)
	draw_rect(Rect2(base.x - r, base.y - h, r * 2.0, h), col)
	_ellipse(base, Vector2(r, r * 0.45), col.darkened(0.2))
	_ellipse(base + Vector2(0, -h), Vector2(r, r * 0.45), col.lightened(0.15))
	for k in 2:
		var y := base.y - h * (0.3 + 0.4 * k)
		draw_line(Vector2(base.x - r, y), Vector2(base.x + r, y), Color(0.25, 0.22, 0.2), 2.0)


func _sack(c: Vector2, r: float, col: Color) -> void:
	_ellipse(c, Vector2(r, r * 0.85), col)
	draw_line(c + Vector2(-r * 0.3, -r * 0.7), c + Vector2(r * 0.3, -r * 0.75), col.darkened(0.35), 1.5)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * float(k) / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


## Backdrop node behind the board: manifest art or a drawn cellar.
static func make_backdrop(man: Dictionary, room_id: String, n: int) -> Node2D:
	var node := Backdrop.new()
	node.name = "Backdrop"
	node.n = n
	node.room_id = room_id
	node.entry = Art.room_entry(man, room_id, "backdrop")
	if node.entry.is_empty():
		node.entry = Art.room_entry(man, room_id, "background")
	node.tex = Art.texture(node.entry) if not node.entry.is_empty() else null
	node.z_as_relative = false
	node.z_index = -1000
	return node


class Backdrop extends Node2D:
	var n := 12
	var room_id := ""
	var entry: Dictionary = {}
	var tex: Texture2D
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if tex == null:
			queue_redraw()

	func _draw() -> void:
		var top := BoardVisualSort.cell_to_local(Vector2i(0, 0)) + Vector2(0, -16)
		var right := BoardVisualSort.cell_to_local(Vector2i(n - 1, 0)) + Vector2(32, 0)
		var bottom := BoardVisualSort.cell_to_local(Vector2i(n - 1, n - 1)) + Vector2(0, 16)
		var left := BoardVisualSort.cell_to_local(Vector2i(0, n - 1)) + Vector2(-32, 0)
		var center := (top + bottom) * 0.5
		if tex != null:
			var size := tex.get_size()
			var raw: Dictionary = entry.get("raw", {})
			var s := float(entry.get("scale", 0.0))
			if s <= 0.0 and raw.has("board_px"):
				s = (float(n) * 64.0) / maxf(float(raw["board_px"]), 1.0)
			if s <= 0.0:
				s = (right.x - left.x) * 1.45 / maxf(size.x, 1.0)
			var pivot: Vector2 = entry.get("pivot", Vector2(-1, -1))
			if raw.has("board_center"):
				var bc: Variant = raw["board_center"]
				if typeof(bc) == TYPE_ARRAY:
					pivot = Vector2(float(bc[0]), float(bc[1]))
			if pivot.x < 0:
				pivot = size * 0.5
			draw_texture_rect(tex, Rect2(center - pivot * s, size * s), false)
			return
		var boss := room_id == "room_b"
		draw_rect(Rect2(center - Vector2(2400, 1600), Vector2(4800, 3200)), Color(0.05, 0.04, 0.04))
		var wall_h := 170.0
		var up := Vector2(0, -wall_h)
		var stone := Color(0.3, 0.25, 0.21) if not boss else Color(0.27, 0.22, 0.2)
		# Lit floor apron round the board.
		var pad := 22.0
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -pad * 0.5), right + Vector2(pad, 0), bottom + Vector2(0, pad * 0.5), left + Vector2(-pad, 0)]), Color(0.16, 0.12, 0.1))
		# Back walls on the two far edges.
		draw_colored_polygon(PackedVector2Array([left, top, top + up, left + up]), stone.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([top, right, right + up, top + up]), stone)
		for k in range(1, 6):
			var y := wall_h * float(k) / 6.0
			draw_line(left + Vector2(0, -y), top + Vector2(0, -y), stone.darkened(0.35), 1.0)
			draw_line(top + Vector2(0, -y), right + Vector2(0, -y), stone.darkened(0.3), 1.0)
		# Timber beams and posts.
		for k in range(0, n + 1, 3):
			var t := float(k) / float(n)
			var a := left.lerp(top, t)
			var b := top.lerp(right, t)
			draw_line(a, a + up, Color(0.36, 0.24, 0.13), 7.0)
			draw_line(b, b + up, Color(0.4, 0.27, 0.14), 7.0)
		draw_line(left + up, top + up, Color(0.36, 0.24, 0.13), 9.0)
		draw_line(top + up, right + up, Color(0.4, 0.27, 0.14), 9.0)
		# Wall lanterns (warm light pools on the walls).
		var flicker := 0.85 + 0.15 * sin(_t * 7.0) * sin(_t * 3.1)
		for t2 in [0.3, 0.7]:
			for edge in [[left, top], [top, right]]:
				var p: Vector2 = (edge[0] as Vector2).lerp(edge[1], t2) + Vector2(0, -wall_h * 0.55)
				draw_circle(p, 46.0, Color(1.0, 0.62, 0.25, 0.10 * flicker))
				draw_circle(p, 22.0, Color(1.0, 0.7, 0.3, 0.18 * flicker))
				draw_circle(p, 5.0, Color(1.0, 0.86, 0.5))
		if boss:
			# Farm tools hung on the walls.
			for t3 in [0.15, 0.5, 0.85]:
				var q := top.lerp(right, t3) + Vector2(0, -wall_h * 0.4)
				draw_line(q + Vector2(-10, -30), q + Vector2(6, 26), Color(0.45, 0.31, 0.16), 3.0)
				draw_line(q + Vector2(-10, -30), q + Vector2(-26, -20), Color(0.75, 0.77, 0.8), 3.0)
