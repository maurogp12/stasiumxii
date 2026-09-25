extends Node2D

## Board-owned Shade. Not a shader pool and not a blink: Ambush is the teleport.
## The phone was resolving Drop Shade with a token too small and too dark to see,
## and the node used to live under Units where pawn rebuild freed it.

const CLOAK_PEAK := 140.0
const LABEL_SIZE := 26
const RIM := Color(0.97, 0.91, 1.0)
const RIM_WIDTH := 5.0

var turns: int = 3
var _pulse_t: float = 1.0


func _ready() -> void:
	set_process(false)


func show_token(at: Vector2, sort_z: int, remaining: int, spawned: bool = false) -> void:
	position = at
	z_index = sort_z
	z_as_relative = false
	turns = maxi(remaining, 0)
	if spawned and is_inside_tree():
		_pulse_in()
	queue_redraw()


func _pulse_in() -> void:
	_pulse_t = 0.0
	scale = Vector2(0.58, 0.58)
	set_process(true)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_pulse_t = minf(_pulse_t + delta / 0.36, 1.0)
	queue_redraw()
	if _pulse_t >= 1.0:
		set_process(false)


func _draw() -> void:
	if _pulse_t < 1.0:
		var ring := _ellipse(lerpf(22.0, 56.0, _pulse_t), lerpf(10.0, 24.0, _pulse_t))
		var flash := Color(RIM.r, RIM.g, RIM.b, (1.0 - _pulse_t) * 0.9)
		draw_polyline(ring, flash, 4.0, true)
	var tile := PackedVector2Array([
		Vector2(0, -22),
		Vector2(40, 0),
		Vector2(0, 22),
		Vector2(-40, 0),
	])
	var tile_fill := PackedVector2Array()
	for i in tile.size():
		tile_fill.append(tile[i])
	draw_colored_polygon(tile_fill, Color(0.42, 0.22, 0.72, 0.72))
	tile.append(tile[0])
	draw_polyline(tile, Color(0.08, 0.04, 0.12, 1.0), RIM_WIDTH + 2.0, true)
	draw_polyline(tile, RIM, RIM_WIDTH, true)
	var pool := _ellipse(34.0, 13.0)
	var wash := PackedVector2Array()
	for i in pool.size() - 1:
		wash.append(pool[i])
	draw_colored_polygon(wash, Color(0.55, 0.32, 0.86, 0.9))
	draw_polyline(pool, RIM, 3.2, true)
	var cloak := PackedVector2Array([
		Vector2(-30, -8),
		Vector2(30, -8),
		Vector2(44, -72),
		Vector2(0, -CLOAK_PEAK),
		Vector2(-44, -72),
	])
	draw_colored_polygon(cloak, Color(0.36, 0.16, 0.62, 1.0))
	cloak.append(cloak[0])
	draw_polyline(cloak, Color(0.06, 0.03, 0.1, 1.0), RIM_WIDTH + 1.5, true)
	draw_polyline(cloak, RIM, RIM_WIDTH, true)
	draw_line(Vector2(-16, -18), Vector2(-8, -CLOAK_PEAK + 28.0), Color(0.72, 0.58, 0.95, 0.9), 2.4, true)
	draw_line(Vector2(16, -18), Vector2(8, -CLOAK_PEAK + 28.0), Color(0.72, 0.58, 0.95, 0.9), 2.4, true)
	draw_circle(Vector2(-12, -88), 6.2, Color(0.05, 0.02, 0.08, 1.0))
	draw_circle(Vector2(12, -88), 6.2, Color(0.05, 0.02, 0.08, 1.0))
	draw_circle(Vector2(-12, -88), 3.4, RIM)
	draw_circle(Vector2(12, -88), 3.4, RIM)
	var font := ThemeDB.fallback_font
	var text := "Shade"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_SIZE)
	var origin := Vector2(-text_size.x * 0.5, -CLOAK_PEAK - 16.0)
	var ascent := font.get_ascent(LABEL_SIZE)
	var descent := font.get_descent(LABEL_SIZE)
	var plate := Rect2(origin.x - 10.0, origin.y - ascent - 6.0, text_size.x + 20.0, ascent + descent + 12.0)
	draw_rect(plate.grow(3.0), RIM)
	draw_rect(plate, Color(0.07, 0.03, 0.12, 0.96))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(1.0, 0.97, 1.0))
	var n := mini(turns, 3)
	for i in n:
		var pip := Vector2(52.0, -108.0 + float(i) * 18.0)
		draw_circle(pip, 7.0, Color(0.05, 0.02, 0.08, 1.0))
		draw_circle(pip, 5.0, RIM)


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := 24
	for i in count:
		var ang := TAU * float(i) / float(count)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	pts.append(pts[0])
	return pts
