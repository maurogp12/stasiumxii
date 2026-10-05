extends BoardTile

## VIEW ONLY. A dungeon room floor tile on the combat board. Paints the room's
## floor art (manifest floor tile, else a drawn stone placeholder) and the
## glowing pads, and keeps BoardTile's highlight chrome for walk / range.

var floor_tex: Texture2D
var pad := false
var pad_tex: Texture2D
var pad_color := Color(1.0, 0.72, 0.28)
var pad_kind := "wheat_pad"
var blocked := false
## A floor decal (the drain grate) is drawn under this tile; draw no floor.
var skip_floor := false
var pad_glow_tex: Texture2D
var pad_glow_scale := 1.0
var _t := 0.0
var _glow: Sprite2D


func set_pad_glow(tex: Texture2D, scale_by: float) -> void:
	pad_glow_tex = tex
	pad_glow_scale = scale_by
	if _glow != null and is_instance_valid(_glow):
		_glow.queue_free()
		_glow = null
	if tex == null or not pad:
		return
	_glow = Sprite2D.new()
	_glow.name = "PadGlow"
	_glow.texture = tex
	_glow.scale = Vector2(scale_by, scale_by)
	_glow.z_index = 2
	_glow.z_as_relative = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)


func _process(delta: float) -> void:
	if pad:
		_t += delta
		if _glow != null:
			_glow.modulate.a = 0.6 + 0.4 * sin(_t * 2.4 + float(grid_position.x + grid_position.y))
		elif pad_tex == null:
			queue_redraw()


func _draw() -> void:
	var pts := _diamond_points()
	if skip_floor:
		if pad and pad_tex == null and pad_kind != "drain_grate":
			_draw_pad(pts)
		return
	if floor_tex != null:
		var size := floor_tex.get_size()
		var h := 64.0 * size.y / maxf(size.x, 1.0)
		draw_texture_rect(floor_tex, Rect2(-32, -16, 64, h), false)
	else:
		_draw_stone(pts)
	if pad:
		_draw_pad(pts)


func _draw_stone(pts: PackedVector2Array) -> void:
	var h := absi(hash(Vector2i(grid_position.x * 7, grid_position.y * 13))) % 1000
	var shade := 0.9 + float(h % 7) * 0.025
	var base := Color(0.36, 0.3, 0.25) * shade
	base.a = 1.0
	draw_colored_polygon(pts, base)
	# Flagstone seams: one diagonal cut per tile, alternating.
	var seam := Color(0.18, 0.14, 0.11, 0.9)
	if (grid_position.x + grid_position.y) % 2 == 0:
		draw_line(pts[0].lerp(pts[3], 0.5), pts[1].lerp(pts[2], 0.5), seam, 1.2)
	else:
		draw_line(pts[0].lerp(pts[1], 0.5), pts[3].lerp(pts[2], 0.5), seam, 1.2)
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	draw_polyline(ring, Color(0.14, 0.11, 0.09, 0.95), 1.4)
	# Straw on the floor.
	for k in 3:
		var a := float((h >> (k * 3)) % 40) - 20.0
		var b := float((h >> (k * 2 + 1)) % 16) - 8.0
		draw_line(Vector2(a, b * 0.5), Vector2(a + 6, b * 0.5 - 2), Color(0.78, 0.64, 0.32, 0.6), 1.0)


func _draw_pad(pts: PackedVector2Array) -> void:
	var pulse := 0.55 + 0.45 * sin(_t * 2.4 + float(grid_position.x + grid_position.y))
	if pad_tex != null:
		var size := pad_tex.get_size()
		var h := 64.0 * size.y / maxf(size.x, 1.0)
		draw_texture_rect(pad_tex, Rect2(-32, -16, 64, h), false)
		return
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.72)
	var glow := pad_color
	glow.a = 0.28 + 0.22 * pulse
	draw_colored_polygon(pts, glow)
	var core := pad_color.lightened(0.25)
	core.a = 0.55 + 0.3 * pulse
	var ring := PackedVector2Array(inner)
	ring.append(inner[0])
	draw_polyline(ring, core, 2.0)
	if pad_kind == "drain_grate":
		for k in range(-2, 3):
			draw_line(Vector2(k * 8 - 8, -4 + k * 4 * 0.0), Vector2(k * 8 + 8, 4), Color(0.12, 0.1, 0.08, 0.9), 2.0)
	else:
		# Wheat sheaf mark.
		for k in range(-1, 2):
			draw_line(Vector2(0, 5), Vector2(k * 6, -6), core, 1.6)
			draw_circle(Vector2(k * 6, -7), 1.8, core)
