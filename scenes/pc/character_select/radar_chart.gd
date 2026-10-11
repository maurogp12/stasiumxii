extends Control

## Five-axis radar. Values are spec 4.1, approved (section 11). 1 to 5.

const AXES_MAX := 5.0

var axes: PackedStringArray = PackedStringArray()
var shown: Array = []
var _from: Array = []
var _to: Array = []
var _t := 1.0
var anim_sec := 0.25


func set_values(next: Array, instant: bool) -> void:
	_from = shown.duplicate()
	_to = next.duplicate()
	if instant or shown.is_empty() or _from.size() != _to.size():
		shown = next.duplicate()
		_t = 1.0
		set_process(false)
		queue_redraw()
		return
	_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	var step := 1.0 if anim_sec <= 0.0 else delta / anim_sec
	_t = minf(_t + step, 1.0)
	shown.clear()
	for i in _to.size():
		var start := float(_to[i])
		if i < _from.size():
			start = float(_from[i])
		shown.append(lerpf(start, float(_to[i]), _t))
	queue_redraw()
	if _t >= 1.0:
		set_process(false)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	var n := maxi(axes.size(), shown.size())
	if n < 3:
		return
	var font := ThemeDB.fallback_font
	var font_size := 14
	for step in range(1, int(AXES_MAX) + 1):
		var ring_pts := _poly(center, radius * (float(step) / AXES_MAX), n)
		ring_pts.append(ring_pts[0])
		draw_polyline(ring_pts, Color(0.93, 0.86, 0.7, 0.4), 1.0)
	for i in n:
		var tip := _at(center, radius, i, n)
		draw_line(center, tip, Color(0.93, 0.86, 0.7, 0.45), 1.0)
		if i < axes.size():
			var label_at := _at(center, radius + 16.0, i, n)
			var text := str(axes[i])
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, label_at - Vector2(width * 0.5, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.93, 0.84))
	if shown.is_empty():
		return
	var fill := _value_poly(center, radius, n)
	if fill.size() >= 3:
		draw_colored_polygon(fill, Color(0.85, 0.62, 0.28, 0.55))
		var edge := fill.duplicate()
		edge.append(edge[0])
		draw_polyline(edge, Color(0.98, 0.86, 0.45), 2.0)


func _value_poly(center: Vector2, radius: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var value := 0.0
		if i < shown.size():
			value = clampf(float(shown[i]), 0.0, AXES_MAX)
		pts.append(_at(center, radius * (value / AXES_MAX), i, n))
	return pts


func _poly(center: Vector2, radius: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(_at(center, radius, i, n))
	return pts


func _at(center: Vector2, radius: float, index: int, n: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / float(n)
	return center + Vector2(cos(angle), sin(angle)) * radius
