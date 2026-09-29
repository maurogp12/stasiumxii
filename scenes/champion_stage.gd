extends Control
class_name ChampionStage

## Inventory turntable (Mauro 29 Sep 2026: "Lets do the 3d"). The champion
## stands on a lit stone pedestal and turns through its four painted facings
## (front → right → back → left) with a squash spin, so the flat art reads as
## a figure turning in place. Swipe on it or tap ◀ ▶ to turn. Idle breath,
## a gold rim light, a contact shadow and a rune ring circling the pedestal;
## the runes take the colour of the rarest piece the champion wears.
## View only: it never touches saves or fight numbers.

signal turned(facing: String)

## Clockwise order seen from the front.
const FACINGS: Array[String] = ["s", "e", "n", "w"]
const TURN_SEC := 0.32
const SWIPE_PX := 36.0
const RUNES := 24
const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)

var class_id: String = "kestrel"
## Rune colour (rarity of the best worn piece; dim gold when nothing is worn).
var rune_tint: Color = Color(1.0, 0.84, 0.47)
var facing_index: int = 0

var _tex: Array[Texture2D] = []
var _time := 0.0
## -1 / +1 while turning, 0 at rest.
var _dir := 0
var _progress := 0.0
var _drag_from := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_textures()
	for side in [-1, 1]:
		var b := Button.new()
		b.name = "TurnLeft" if side < 0 else "TurnRight"
		b.text = "◀" if side < 0 else "▶"
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(48, 48)
		b.size = Vector2(48, 48)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", GOLD_BRIGHT)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(turn.bind(side))
		add_child(b)
	resized.connect(_place_buttons)
	_place_buttons()


func set_class(id: String) -> void:
	if id == class_id and not _tex.is_empty():
		return
	class_id = id
	facing_index = 0
	_dir = 0
	_load_textures()
	queue_redraw()


func facing() -> String:
	return FACINGS[facing_index]


func is_turning() -> bool:
	return _dir != 0


## +1 turns the champion to its right, -1 to its left.
func turn(dir: int) -> void:
	if dir == 0:
		return
	if _dir != 0:
		_finish_turn()
	_dir = 1 if dir > 0 else -1
	_progress = 0.0


## Tests and screenshots: jump to the end of a running turn.
func settle() -> void:
	if _dir != 0:
		_finish_turn()


func _finish_turn() -> void:
	facing_index = posmod(facing_index + _dir, FACINGS.size())
	_dir = 0
	_progress = 0.0
	turned.emit(facing())
	queue_redraw()


func _load_textures() -> void:
	_tex.clear()
	for f in FACINGS:
		var path := "res://art/characters/%s/%s_%s.png" % [class_id, class_id, f]
		_tex.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)


func _place_buttons() -> void:
	var left := get_node_or_null("TurnLeft") as Button
	var right := get_node_or_null("TurnRight") as Button
	if left == null or right == null:
		return
	var y := size.y * 0.52 - 24
	left.position = Vector2(4, y)
	right.position = Vector2(size.x - 52, y)


func _process(delta: float) -> void:
	_time += delta
	if _dir != 0:
		_progress += delta / TURN_SEC
		if _progress >= 1.0:
			_finish_turn()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var press := false
	var release := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		press = event.pressed
		release = not event.pressed
		pos = event.position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		pos = event.position
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _dragging:
		var dx: float = event.position.x - _drag_from.x
		if absf(dx) >= SWIPE_PX:
			# Drag right = the figure spins toward you from its left.
			turn(-1 if dx > 0 else 1)
			_drag_from = event.position
		accept_event()
		return
	if press:
		_dragging = true
		_drag_from = pos
		accept_event()
	elif release:
		_dragging = false


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var top_y := h * 0.80
	var rx := minf(w * 0.40, 170.0)
	var ry := rx * 0.22
	# Warm halo and a light shaft from above.
	# Kept inside the stage so the clip never shows a hard box edge.
	var halo := minf(w * 0.5, h * 0.42)
	for i in 14:
		var k := float(i) / 14.0
		var r := lerpf(halo, halo * 0.15, k)
		_ellipse(Vector2(cx, h * 0.5), Vector2(r, r * 1.15), Color(0.47, 0.34, 0.16, 0.02 + 0.035 * k))
	var shaft := PackedVector2Array([Vector2(cx - rx * 0.25, 0), Vector2(cx + rx * 0.25, 0), Vector2(cx + rx * 0.85, top_y), Vector2(cx - rx * 0.85, top_y)])
	draw_polygon(shaft, PackedColorArray([Color(1.0, 0.86, 0.6, 0.0), Color(1.0, 0.86, 0.6, 0.0), Color(1.0, 0.86, 0.6, 0.09), Color(1.0, 0.86, 0.6, 0.09)]))
	# Stone drum: side, then the lit top with a gold rim.
	var depth := ry * 1.1
	draw_rect(Rect2(cx - rx, top_y, rx * 2.0, depth), Color(0.18, 0.15, 0.11))
	_ellipse(Vector2(cx, top_y + depth), Vector2(rx, ry), Color(0.13, 0.11, 0.08))
	_ellipse(Vector2(cx, top_y), Vector2(rx, ry), Color(0.28, 0.23, 0.17))
	_ellipse_line(Vector2(cx, top_y), Vector2(rx, ry), GOLD, 2.5)
	_ellipse_line(Vector2(cx, top_y), Vector2(rx * 0.86, ry * 0.8), Color(0.6, 0.46, 0.25, 0.7), 1.0)
	# Back half of the rune ring (behind the champion).
	_runes(Vector2(cx, top_y), Vector2(rx * 0.74, ry * 0.62), false)
	# Contact shadow under the feet.
	var spin := _spin_scale()
	_ellipse(Vector2(cx, top_y + 2), Vector2(rx * 0.42 * (0.7 + 0.3 * spin), ry * 0.5), Color(0, 0, 0, 0.45))
	_draw_champion(Vector2(cx, top_y + ry * 0.35), h * 0.74, spin)
	# Front half of the rune ring (over the champion's feet).
	_runes(Vector2(cx, top_y), Vector2(rx * 0.74, ry * 0.62), true)


## 1 at rest, dips to 0.32 at the half-turn (the edge-on moment).
func _spin_scale() -> float:
	if _dir == 0:
		return 1.0
	return 0.32 + 0.68 * absf(cos(_progress * PI))


func _current_texture() -> Texture2D:
	if _tex.is_empty():
		return null
	var idx := facing_index
	if _dir != 0 and _progress >= 0.5:
		idx = posmod(facing_index + _dir, FACINGS.size())
	return _tex[idx]


func _draw_champion(feet: Vector2, max_h: float, spin: float) -> void:
	var tex := _current_texture()
	if tex == null:
		return
	var tsize := tex.get_size()
	var scale := max_h / tsize.y
	var breath := 1.0 + 0.015 * sin(_time * 2.2)
	var sz := Vector2(tsize.x * scale * spin, tsize.y * scale * breath)
	var rect := Rect2(feet.x - sz.x * 0.5, feet.y - sz.y, sz.x, sz.y)
	# Gold rim light: the silhouette, tinted and a touch larger, behind.
	for grow in [7.0, 4.0]:
		draw_texture_rect(tex, rect.grow(grow), false, Color(1.0, 0.8, 0.45, 0.10))
	draw_texture_rect(tex, rect, false)


func _runes(center: Vector2, radii: Vector2, front: bool) -> void:
	for i in RUNES:
		var a := _time * 0.6 + float(i) * TAU / float(RUNES)
		var is_front := sin(a) > 0.0
		if is_front != front:
			continue
		var p := center + Vector2(cos(a) * radii.x, sin(a) * radii.y)
		var big := i % 3 == 0
		var r := 3.2 if big else 1.8
		var alpha := 0.95 if is_front else 0.45
		draw_circle(p, r * 2.4, Color(rune_tint.r, rune_tint.g, rune_tint.b, 0.12 * alpha))
		_ellipse(p, Vector2(r, r * 0.55), Color(rune_tint.r, rune_tint.g, rune_tint.b, alpha))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, r: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, width, true)
