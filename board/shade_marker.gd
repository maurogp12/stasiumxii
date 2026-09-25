extends Node2D

## Board-owned Shade. Not a shader pool and not a blink: Ambush is the relocate.
## TA token uses the unit foot pivot. The tile decal plus the plate stay
## readable after the cast floater fades. A live Shade that is the Ambush
## origin wears the louder "Ambush" plate. Invisible origin is Gloam, so the
## token stays a Neutral Shade. The node lives on ShadeMarkers so pawn rebuild
## cannot free it.

const TOKEN_PATH := "res://art/vfx/shade/neutral_shade_token.png"
const TILE_PATH := "res://art/vfx/shade/neutral_shade_tile_marker.png"
const TOKEN_OFFSET := Vector2(0, -72)
const TOKEN_SCALE := Vector2(0.5, 0.5)
const CLOAK_PEAK := 140.0
const LABEL_SIZE := 26
const ORIGIN_LABEL_SIZE := 36
const RIM := Color(0.97, 0.91, 1.0)
const REST_MODULATE := Color(1.35, 1.22, 1.55)
const ORIGIN_MODULATE := Color(1.9, 1.55, 2.2)

var turns: int = 3
var _as_origin: bool = false
var _pulse_t: float = 1.0
var _token: Sprite2D
var _tile: Sprite2D
var _plate: ShadePlate


func _ready() -> void:
	_ensure_art()
	set_process(false)


func show_token(at: Vector2, sort_z: int, remaining: int, spawned: bool = false, as_origin: bool = false) -> void:
	position = at
	z_index = sort_z
	z_as_relative = false
	turns = maxi(remaining, 0)
	_as_origin = as_origin
	_ensure_art()
	_apply_loudness()
	if spawned and is_inside_tree():
		_pulse_in()
	queue_redraw()
	if _plate != null:
		_plate.queue_redraw()


func plate_text() -> String:
	return "Ambush" if _as_origin else "Shade"


func _pulse_in() -> void:
	_pulse_t = 0.0
	scale = Vector2(0.72, 0.72)
	set_process(true)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_pulse_t = minf(_pulse_t + delta / 0.36, 1.0)
	queue_redraw()
	if _plate != null:
		_plate.queue_redraw()
	if _pulse_t >= 1.0:
		set_process(false)


func _ensure_art() -> void:
	if _tile == null or not is_instance_valid(_tile):
		_tile = Sprite2D.new()
		_tile.name = "TileMarker"
		_tile.centered = true
		_tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_tile.z_index = 0
		_tile.z_as_relative = true
		add_child(_tile)
	if _token == null or not is_instance_valid(_token):
		_token = Sprite2D.new()
		_token.name = "Token"
		_token.centered = true
		_token.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_token.z_index = 1
		_token.z_as_relative = true
		add_child(_token)
	_token.offset = TOKEN_OFFSET
	_token.scale = TOKEN_SCALE
	_apply_loudness()
	if _token.texture == null:
		_token.texture = load(TOKEN_PATH) as Texture2D
	if _tile.texture == null:
		_tile.texture = load(TILE_PATH) as Texture2D
	if _plate == null or not is_instance_valid(_plate):
		_plate = ShadePlate.new()
		_plate.name = "Plate"
		_plate.host = self
		_plate.z_index = 4
		_plate.z_as_relative = true
		add_child(_plate)


func _apply_loudness() -> void:
	if _token != null and is_instance_valid(_token):
		# Authored alpha is a soft silhouette. The origin lift beats map props.
		_token.modulate = ORIGIN_MODULATE if _as_origin else REST_MODULATE
	if _tile != null and is_instance_valid(_tile):
		_tile.modulate = Color(1.7, 1.35, 2.0) if _as_origin else Color.WHITE


func _draw() -> void:
	if _as_origin:
		var halo := _ellipse(62.0, 26.0)
		draw_colored_polygon(halo, Color(0.62, 0.28, 1.0, 0.42))
		draw_polyline(halo, RIM, 5.0, true)
	if _pulse_t >= 1.0:
		return
	var ring := _ellipse(lerpf(28.0, 58.0, _pulse_t), lerpf(12.0, 24.0, _pulse_t))
	var flash := Color(RIM.r, RIM.g, RIM.b, (1.0 - _pulse_t) * 0.9)
	draw_polyline(ring, flash, 4.0, true)


func paint_plate(canvas: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	var text := plate_text()
	var size := ORIGIN_LABEL_SIZE if _as_origin else LABEL_SIZE
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var origin := Vector2(-text_size.x * 0.5, -CLOAK_PEAK - 16.0)
	var ascent := font.get_ascent(size)
	var descent := font.get_descent(size)
	var plate := Rect2(origin.x - 10.0, origin.y - ascent - 6.0, text_size.x + 20.0, ascent + descent + 12.0)
	canvas.draw_rect(plate.grow(4.0 if _as_origin else 3.0), RIM)
	canvas.draw_rect(plate, Color(0.16, 0.04, 0.28, 0.96) if _as_origin else Color(0.07, 0.03, 0.12, 0.96))
	canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.97, 1.0))
	var n := mini(turns, 3)
	for i in n:
		var pip := Vector2(48.0, -96.0 + float(i) * 16.0)
		canvas.draw_circle(pip, 7.0, Color(0.05, 0.02, 0.08, 1.0))
		canvas.draw_circle(pip, 5.0, RIM)


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := 24
	for i in count:
		var ang := TAU * float(i) / float(count)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	pts.append(pts[0])
	return pts


class ShadePlate extends Node2D:
	var host: Node2D

	func _draw() -> void:
		if host != null and host.has_method("paint_plate"):
			host.paint_plate(self)
