extends Node2D

## Board-owned Shade. Not a shader pool: the phone was resolving Drop Shade
## (AP, log, HUD) with nothing on the tile. This node is the token.

var turns: int = 3


func show_token(at: Vector2, sort_z: int, remaining: int) -> void:
	position = at
	z_index = sort_z
	z_as_relative = true
	turns = maxi(remaining, 0)
	queue_redraw()


func _draw() -> void:
	var pool := _ellipse(22.0, 9.0)
	var fill := PackedVector2Array()
	for i in pool.size() - 1:
		fill.append(pool[i])
	var wash := Color(VfxPalette.GLOAM.r, VfxPalette.GLOAM.g, VfxPalette.GLOAM.b, 0.88)
	draw_colored_polygon(fill, wash)
	draw_polyline(pool, VfxPalette.GLOAM_RIM, 2.4, true)
	var cloak := PackedVector2Array([
		Vector2(-16, -6),
		Vector2(16, -6),
		Vector2(22, -40),
		Vector2(0, -78),
		Vector2(-22, -40),
	])
	draw_colored_polygon(cloak, VfxPalette.GLOAM)
	cloak.append(cloak[0])
	draw_polyline(cloak, VfxPalette.OUTLINE, 3.6, true)
	draw_polyline(cloak, VfxPalette.GLOAM_RIM, 2.0, true)
	draw_circle(Vector2(-7, -48), 3.2, VfxPalette.GLOAM_RIM)
	draw_circle(Vector2(7, -48), 3.2, VfxPalette.GLOAM_RIM)
	var font := ThemeDB.fallback_font
	var text := "Shade"
	var font_size := 16
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var origin := Vector2(-text_size.x * 0.5, -90.0)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var plate := Rect2(origin.x - 6.0, origin.y - ascent - 2.0, text_size.x + 12.0, ascent + descent + 4.0)
	draw_rect(plate, Color(0.08, 0.05, 0.12, 0.94))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.92, 1.0))
	var n := mini(turns, 3)
	for i in n:
		var pip := Vector2(26.0, -62.0 + float(i) * 12.0)
		draw_circle(pip, 4.4, VfxPalette.OUTLINE)
		draw_circle(pip, 3.2, VfxPalette.GLOAM_RIM)


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := 24
	for i in count:
		var ang := TAU * float(i) / float(count)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	pts.append(pts[0])
	return pts
