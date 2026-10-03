extends Node2D
class_name BoardTile

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const _KoliseoArt := preload("res://board/koliseo_art.gd")
## Relative to this tile. Stays under BoardVisualSort.UNIT_Z_BIAS so the
## seat ring and pawn sprite still paint after the overlay, including on
## elevated tiles (the overlay is a child, so it lifts with the diamond).
const OVERLAY_Z: int = 1
const HIGHLIGHT_FILL_ALPHA: float = 0.5
const LABEL_SETTING := "stasium/debug/show_tile_labels"

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var highlight: String = ""
var elevation: int = 0
var terrain_type: String = "ground"
var _dress: String = ""
var _paint_props: Array = []
var _overlay: HighlightOverlay
## Jungle canopy shade. White leaves the terrain untouched. Applied on the
## terrain draw itself so the diamonds do not grow a second canvas command.
var canopy_tint: Color = Color.WHITE
## View-only floor plate (Thunderwell Core and later themes). Null keeps the Koliseo dress.
var _look_floor: Texture2D = null
var _look_pulse: float = 1.0
## Per-channel tint after the shadow lift. White leaves the lifted paint unchanged.
var _look_grade: Color = Color(1, 1, 1, 1)
## Exponent on the linear plate. Below 1 lifts the dark stone without clipping the traces.
var _look_lift: float = 1.0
var _look_flip_h: bool = false
var _look_flip_v: bool = false
var _look_diag: bool = false
var _look_slot := Rect2(0, 0, 1, 1)
var _look_sprite: Sprite2D
var _look_mat: ShaderMaterial

const LOOK_FLOOR_SHADER := """shader_type canvas_item;
uniform vec3 floor_grade = vec3(1.0);
uniform float floor_lift = 1.0;
// Screen flips stay inside one strip slot. h mirrors x, v mirrors y.
uniform vec4 slot_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float flip_h = 0.0;
uniform float flip_v = 0.0;
vec2 slot_uv(vec2 uv) {
	if (flip_h < 0.5 && flip_v < 0.5)
		return uv;
	vec2 local = (uv - slot_rect.xy) / slot_rect.zw;
	if (flip_h > 0.5)
		local.x = 1.0 - local.x;
	if (flip_v > 0.5)
		local.y = 1.0 - local.y;
	return slot_rect.xy + local * slot_rect.zw;
}
void fragment() {
	vec4 tex = texture(TEXTURE, slot_uv(UV));
	float lift = clamp(floor_lift, 0.05, 1.0);
	vec3 rgb = pow(max(tex.rgb, vec3(0.0002)), vec3(lift));
	rgb *= floor_grade;
	COLOR = vec4(rgb, tex.a);
}
"""


class HighlightOverlay extends Node2D:
	var host: BoardTile

	func _draw() -> void:
		if host != null:
			host.paint_highlight_overlay(self)


func _ready() -> void:
	_ensure_overlay()


func set_look_floor(tex: Texture2D) -> void:
	_look_floor = tex
	_sync_look_sprite()
	_request_paint()


func clear_look_floor() -> void:
	_look_grade = Color(1, 1, 1, 1)
	_look_lift = 1.0
	_look_flip_h = false
	_look_flip_v = false
	_look_diag = false
	_look_slot = Rect2(0, 0, 1, 1)
	set_look_floor(null)


## Grid-axis flips for a route tile. h mirrors x and v mirrors y inside the slot.
func set_look_orient(flip_h: bool, flip_v: bool, diag: bool, slot_uv: Rect2) -> void:
	_look_flip_h = flip_h
	_look_flip_v = flip_v
	_look_diag = diag
	_look_slot = slot_uv
	_sync_look_sprite()


func look_floor() -> Texture2D:
	return _look_floor


func set_look_grade(color: Color) -> void:
	_look_grade = Color(color.r, color.g, color.b, 1.0)
	_sync_look_sprite()


func look_grade() -> Color:
	return _look_grade


func set_look_lift(amount: float) -> void:
	_look_lift = clampf(amount, 0.05, 1.0)
	_sync_look_sprite()


func look_lift() -> float:
	return _look_lift


func set_look_pulse(amount: float) -> void:
	var next := clampf(amount, 0.0, 2.0)
	if is_equal_approx(_look_pulse, next):
		return
	_look_pulse = next
	if _look_floor != null:
		_sync_look_sprite()


func _draw() -> void:
	var points := _diamond_points()
	if _look_floor != null:
		_paint_label()
		return
	var tex := _KoliseoArt.terrain_texture(terrain_type, elevation, _dress)
	if tex == null:
		draw_colored_polygon(points, fill_color())
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, Color(0.25, 0.15, 0.25), 1.0, true)
	else:
		_paint_terrain(tex)
	for prop_name in _paint_props:
		var prop_tex := _KoliseoArt.prop_texture(str(prop_name))
		if prop_tex != null:
			_paint_prop(prop_tex)
	_paint_label()


func _sync_look_sprite() -> void:
	if _look_floor == null:
		if _look_sprite != null:
			_look_sprite.visible = false
		return
	if _look_sprite == null:
		_look_sprite = Sprite2D.new()
		_look_sprite.name = "LookFloor"
		_look_sprite.centered = true
		_look_sprite.z_as_relative = true
		_look_sprite.z_index = -1
		_look_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_look_sprite)
	if _look_mat == null:
		var shader := Shader.new()
		shader.code = LOOK_FLOOR_SHADER
		_look_mat = ShaderMaterial.new()
		_look_mat.shader = shader
	_look_sprite.material = _look_mat
	_look_sprite.texture = _look_floor
	_look_sprite.visible = true
	var width := float(_look_floor.get_width())
	if width > 1.0:
		var scale := 64.0 / width
		_look_sprite.scale = Vector2(scale, scale)
	var pulse := _look_pulse
	_look_mat.set_shader_parameter("floor_grade", Vector3(_look_grade.r * pulse, _look_grade.g * pulse, _look_grade.b * pulse))
	_look_mat.set_shader_parameter("floor_lift", _look_lift)
	_look_mat.set_shader_parameter("flip_h", 1.0 if _look_flip_h else 0.0)
	_look_mat.set_shader_parameter("flip_v", 1.0 if _look_flip_v else 0.0)
	_look_mat.set_shader_parameter("slot_rect", Vector4(_look_slot.position.x, _look_slot.position.y, _look_slot.size.x, _look_slot.size.y))


func _paint_label() -> void:
	var label := drawn_label()
	if label == "":
		return
	var font := ThemeDB.fallback_font
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	draw_string(font, Vector2(-label_size.x * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.06, 0.06))


func set_dress(dress: String) -> void:
	if _dress == dress:
		return
	_dress = dress
	_request_paint()


func apply_board_data(next_terrain: String, next_elevation: Variant = 0) -> void:
	terrain_type = SNAPSHOT_TILES.normalize_terrain(next_terrain)
	elevation = SNAPSHOT_TILES.normalize_elevation(next_elevation)
	_request_paint()


func set_paint_props(props: Array) -> void:
	_paint_props = props.duplicate()
	_request_paint()


func _draw_centered(tex: Texture2D) -> void:
	var size := tex.get_size()
	draw_texture(tex, Vector2(-size.x * 0.5, -size.y * 0.5), canopy_tint)


func _paint_terrain(tex: Texture2D) -> void:
	var placed: Dictionary = _KoliseoArt.terrain_placement(tex)
	if placed.is_empty():
		_draw_centered(tex)
		return
	draw_texture_rect_region(tex, placed["dest"], placed["source"], canopy_tint)


## Flat canopy shade on the existing terrain draw. No extra polygon.
func set_canopy_tint(tint: Color) -> void:
	if canopy_tint.is_equal_approx(tint):
		return
	canopy_tint = tint
	queue_redraw()


## Props stand on the south tip of the diamond. paint_only never affects pathing.
func _paint_prop(tex: Texture2D) -> void:
	var size := tex.get_size()
	draw_texture(tex, Vector2(-size.x * 0.5, float(TILE_HEIGHT) * 0.5 - size.y))


func set_selected(value: bool) -> void:
	is_selected = value
	_request_paint()


func set_highlight(kind: String) -> void:
	highlight = kind
	_request_paint()


func terrain_letter() -> String:
	match terrain_type:
		"mud":
			return "M"
		"water":
			return "W"
		"lava":
			return "L"
		_:
			return "G"


func elevation_text() -> String:
	return str(int(elevation))


## Terrain fill only. Highlights never replace this.
func fill_color() -> Color:
	return _terrain_color()


## Semi-transparent copy of the flat highlight color, or alpha 0 when idle.
func overlay_color() -> Color:
	var flat := _highlight_flat_color()
	if flat.a <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(flat.r, flat.g, flat.b, HIGHLIGHT_FILL_ALPHA)


func overlay_draws_outline() -> bool:
	return overlay_color().a > 0.0


func drawn_label() -> String:
	if not tile_labels_visible():
		return ""
	return "%s %s" % [terrain_letter(), elevation_text()]


static func tile_labels_visible() -> bool:
	return bool(ProjectSettings.get_setting(LABEL_SETTING, false))


## F3 toggles the project setting in debug builds. Release builds ignore the key.
static func consume_debug_label_key(event: InputEvent) -> bool:
	if not OS.is_debug_build():
		return false
	if event == null or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	if key.keycode != KEY_F3 and key.physical_keycode != KEY_F3:
		return false
	ProjectSettings.set_setting(LABEL_SETTING, not tile_labels_visible())
	return true


func paint_highlight_overlay(canvas: CanvasItem) -> void:
	var color := overlay_color()
	if color.a <= 0.0:
		return
	var points := _diamond_points()
	# Thunderwell move tiles need a brighter fill than #73C7EB at 0.5, or the
	# full-pulse trace wins after bloom. Other themes keep overlay_color().
	var line := Color(color.r, color.g, color.b, 0.95)
	var width := 4.2 if highlight == "origin" or highlight == "landing" else (3.4 if highlight == "range" else 1.8)
	if highlight == "move" and _look_floor != null:
		color = Color(0.55, 0.93, 1.0, 0.88)
		line = Color(0.75, 1.0, 1.0, 1.0)
		width = 4.0
	canvas.draw_colored_polygon(points, color)
	if overlay_draws_outline():
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		canvas.draw_polyline(outline, line, width, true)
	if highlight == "blocked":
		canvas.draw_line(Vector2(-14, -6), Vector2(14, 6), Color(0.55, 0.52, 0.48), 2.0, true)
		canvas.draw_line(Vector2(14, -6), Vector2(-14, 6), Color(0.55, 0.52, 0.48), 2.0, true)


func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = HighlightOverlay.new()
	_overlay.name = "Highlight"
	_overlay.z_index = OVERLAY_Z
	_overlay.z_as_relative = true
	_overlay.host = self
	add_child(_overlay)


func _request_paint() -> void:
	_ensure_overlay()
	queue_redraw()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _diamond_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -TILE_HEIGHT / 2.0),
		Vector2(TILE_WIDTH / 2.0, 0),
		Vector2(0, TILE_HEIGHT / 2.0),
		Vector2(-TILE_WIDTH / 2.0, 0),
	])


func _highlight_flat_color() -> Color:
	var color := Color(0, 0, 0, 0)
	match highlight:
		"move":
			color = Color(0.45, 0.78, 0.92, 1.0)
		"advance":
			color = Color(0.72, 0.58, 0.95, 1.0)
		"range":
			color = Color(0.95, 0.78, 0.32, 1.0)
		"target":
			color = Color(0.95, 0.55, 0.28, 1.0)
		"origin":
			color = Color(0.72, 0.32, 1.0, 1.0)
		"landing":
			color = Color(0.86, 0.62, 1.0, 1.0)
		"selected":
			color = Color(1.0, 0.85, 0.2, 1.0)
		"zone_p1":
			color = Color(0.36, 0.72, 0.52, 1.0)
		"zone_p2":
			color = Color(0.78, 0.42, 0.42, 1.0)
		"occupied":
			color = Color(0.78, 0.62, 0.22, 1.0)
		"locked":
			color = Color(0.42, 0.40, 0.48, 1.0)
		"blocked":
			color = Color(0.14, 0.14, 0.16, 1.0)
	if is_selected and highlight != "blocked":
		color = Color(1.0, 0.85, 0.2, 1.0)
	return color


func _terrain_color() -> Color:
	match terrain_type:
		"mud":
			return Color(0.56, 0.38, 0.20)
		"water":
			return Color(0.28, 0.54, 0.80)
		"lava":
			return Color(0.86, 0.30, 0.12)
		_:
			if (grid_position.x + grid_position.y) % 2 == 0:
				return Color(0.58, 0.74, 0.40)
			return Color(0.48, 0.64, 0.34)
