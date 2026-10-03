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
const GLYPHS := preload("res://board/pc/glyph_decals.gd")
## Full-grid hold. Thin, and faint enough that a move tile still reads.
const GRID_LINE_WIDTH := 1.0
const GRID_LINE_ALPHA := 0.18
## One clock for every move tile. About ±8% at 0.5 Hz. Frozen while a walk plays.
const MOVE_PULSE_HZ := 0.5
const MOVE_PULSE_AMP := 0.08
## Deploy zones. Same hues as the L5 hex rings. One alpha for every open cell.
const DEPLOY_P1 := Color(74.0 / 255.0, 143.0 / 255.0, 224.0 / 255.0)
const DEPLOY_P2 := Color(224.0 / 255.0, 90.0 / 255.0, 74.0 / 255.0)
const DEPLOY_FILL_ALPHA := 0.35
const DEPLOY_LOCKED_ALPHA := 0.15
## Locked cells keep the team hue and sit a little darker.
const DEPLOY_LOCKED_SCALE := 0.72

static var _move_pulse_time: float = 0.0
static var _move_pulse_frozen: bool = false

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var highlight: String = ""
## Soft outline on the cell under the pointer. Not a grid.
var soft_hover: bool = false
## Alt-hold grid. One line per cell, cleared on release.
var grid_line: bool = false
var _reveal: float = 0.0
var _reveal_target: float = 0.0
var _shown_highlight: String = ""
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
## Thunderwell bevel: dark slate plus a green rim. Off for every other dress.
var _look_seam: bool = false
var _look_slot := Rect2(0, 0, 1, 1)
var _look_sprite: Sprite2D
var _look_mat: ShaderMaterial
var _seam: SeamPlate

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
	set_process(false)
	_ensure_overlay()


func set_look_floor(tex: Texture2D) -> void:
	_look_floor = tex
	_sync_look_sprite()
	_request_paint()


func clear_look_floor() -> void:
	_look_grade = Color(1, 1, 1, 1)
	_look_lift = 1.0
	_look_seam = false
	_look_flip_h = false
	_look_flip_v = false
	_look_diag = false
	_look_slot = Rect2(0, 0, 1, 1)
	set_look_floor(null)


func set_look_seam(on: bool) -> void:
	_look_seam = on
	_sync_look_sprite()


func look_seam() -> bool:
	return _look_seam


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
	_sync_seam()


## The light grey V is the viewport clear showing in the cracks around a diamond.
## Thunderwell fills that crack with dark slate and a thin green rim on the top edge.
func _sync_seam() -> void:
	var show := _look_seam and _look_floor != null
	if not show:
		if _seam != null:
			_seam.visible = false
		return
	if _seam == null:
		_seam = SeamPlate.new()
		_seam.name = "SeamPlate"
		# Behind every floor plate, in front of the room, so a neighbour cannot cover a cell.
		_seam.z_as_relative = false
		_seam.z_index = -80
		add_child(_seam)
	_seam.visible = true
	_seam.queue_redraw()


class SeamPlate extends Node2D:
	func _draw() -> void:
		var top := Vector2(0, -BoardTile.TILE_HEIGHT / 2.0)
		var right := Vector2(BoardTile.TILE_WIDTH / 2.0, 0)
		var bottom := Vector2(0, BoardTile.TILE_HEIGHT / 2.0)
		var left := Vector2(-BoardTile.TILE_WIDTH / 2.0, 0)
		var grow := 1.50
		draw_colored_polygon(PackedVector2Array([top * grow, right * grow, bottom * grow, left * grow]), Color(0.035, 0.062, 0.048, 1))
		var rim := Color(0.08, 0.42, 0.20, 1)
		var out := 1.04
		draw_line(top * out, left * out, rim, 1.8, true)
		draw_line(top * out, right * out, rim, 1.8, true)


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
	if highlight == kind:
		return
	var previous := highlight
	highlight = kind
	if kind != "":
		_shown_highlight = kind
		_reveal_target = 1.0
		# A same-frame clear-and-repaint keeps a tile that was already shown.
		if previous == "" and _reveal <= 0.0:
			_reveal = 0.0
	else:
		_reveal_target = 0.0
	set_process(true)
	_request_paint()


func set_soft_hover(on: bool) -> void:
	if soft_hover == on:
		return
	soft_hover = on
	_request_paint()


func set_grid_line(on: bool) -> void:
	if grid_line == on:
		return
	grid_line = on
	_request_paint()


func shows_grid_line() -> bool:
	return grid_line


static func move_pulse_scale_at(time: float) -> float:
	return 1.0 + MOVE_PULSE_AMP * sin(time * TAU * MOVE_PULSE_HZ)


static func move_pulse_scale() -> float:
	return move_pulse_scale_at(_move_pulse_time)


static func move_pulse_time() -> float:
	return _move_pulse_time


static func set_move_pulse_time(time: float) -> void:
	_move_pulse_time = time


static func advance_move_pulse(delta: float) -> void:
	if _move_pulse_frozen:
		return
	_move_pulse_time += delta


static func set_move_pulse_frozen(on: bool) -> void:
	_move_pulse_frozen = on


static func move_pulse_frozen() -> bool:
	return _move_pulse_frozen


func pulses_move() -> bool:
	var kind := highlight if highlight != "" else _shown_highlight
	return kind == "move" and _reveal > 0.001


func queue_move_pulse() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _process(delta: float) -> void:
	if is_equal_approx(_reveal, _reveal_target):
		if _reveal_target <= 0.0:
			_shown_highlight = ""
		set_process(false)
		_request_paint()
		return
	_reveal = move_toward(_reveal, _reveal_target, delta * 6.0)
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
	if grid_line:
		_paint_grid_line(canvas)
	var kind := highlight if highlight != "" else _shown_highlight
	if kind == "" and soft_hover:
		var hover_pts := _diamond_points()
		var hover_line := PackedVector2Array(hover_pts)
		hover_line.append(hover_pts[0])
		canvas.draw_polyline(hover_line, Color(0.72, 0.90, 0.82, 0.55), 1.6, true)
		return
	var saved := highlight
	highlight = kind
	var color := overlay_color()
	highlight = saved
	if color.a <= 0.0 or _reveal <= 0.001:
		return
	var points := _diamond_points()
	# Every theme uses the Thunderwell move tile: a bright fill and a rim that
	# sits on the overlay, above the floor. overlay_color() stays the flat cyan.
	# The overlay is a child of the tile, so a raised cell carries the move tile.
	var line := Color(color.r, color.g, color.b, 0.95)
	var width := 4.2 if kind == "origin" or kind == "landing" else (3.4 if kind == "range" else 1.8)
	if kind == "move":
		color = Color(0.55, 0.93, 1.0, 0.88)
		line = Color(0.75, 1.0, 1.0, 1.0)
		width = 4.0
		var breathe := move_pulse_scale()
		color.r = minf(color.r * breathe, 1.0)
		color.g = minf(color.g * breathe, 1.0)
		color.b = minf(color.b * breathe, 1.0)
		line.r = minf(line.r * breathe, 1.0)
		line.g = minf(line.g * breathe, 1.0)
		line.b = minf(line.b * breathe, 1.0)
	var deploy := _deploy_tint(kind)
	if deploy.a > 0.0:
		color = deploy
		line = Color(deploy.r, deploy.g, deploy.b, minf(0.55, deploy.a + 0.20))
		width = 1.6
	color.a *= _reveal
	line.a *= _reveal
	canvas.draw_colored_polygon(points, color)
	if color.a > 0.0:
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		canvas.draw_polyline(outline, line, width, true)
	_paint_glyph(canvas, kind)
	if kind == "blocked":
		canvas.draw_line(Vector2(-14, -6), Vector2(14, 6), Color(0.55, 0.52, 0.48, _reveal), 2.0, true)
		canvas.draw_line(Vector2(14, -6), Vector2(-14, 6), Color(0.55, 0.52, 0.48, _reveal), 2.0, true)


func _paint_grid_line(canvas: CanvasItem) -> void:
	var pts := _diamond_points()
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	canvas.draw_polyline(outline, Color(0.78, 0.90, 0.84, GRID_LINE_ALPHA), GRID_LINE_WIDTH, true)


func _paint_glyph(canvas: CanvasItem, kind: String) -> void:
	var ids: Array[String] = GLYPHS.ids_for_highlight(kind)
	if ids.is_empty() or _reveal <= 0.001:
		return
	for id in ids:
		var tex := GLYPHS.texture(id) as Texture2D
		if tex == null:
			continue
		var mod := GLYPHS.modulate_for(id, kind)
		var tint := Color(mod.r, mod.g, mod.b, mod.a * _reveal)
		var size: Vector2 = GLYPHS.draw_size(tex)
		canvas.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, tint)


## Open cells share one alpha. Locked cells use the same hue, darker and thinner.
func _deploy_tint(kind: String) -> Color:
	var base := DEPLOY_P1
	if kind.ends_with("p2"):
		base = DEPLOY_P2
	elif not kind.ends_with("p1"):
		return Color(0, 0, 0, 0)
	if kind.begins_with("locked"):
		return Color(base.r * DEPLOY_LOCKED_SCALE, base.g * DEPLOY_LOCKED_SCALE, base.b * DEPLOY_LOCKED_SCALE, DEPLOY_LOCKED_ALPHA)
	if kind.begins_with("zone_"):
		return Color(base.r, base.g, base.b, DEPLOY_FILL_ALPHA)
	return Color(0, 0, 0, 0)


func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = HighlightOverlay.new()
	_overlay.name = "Highlight"
	_overlay.z_index = OVERLAY_Z
	_overlay.z_as_relative = true
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
			color = Color(DEPLOY_P1.r, DEPLOY_P1.g, DEPLOY_P1.b, 1.0)
		"zone_p2":
			color = Color(DEPLOY_P2.r, DEPLOY_P2.g, DEPLOY_P2.b, 1.0)
		"occupied":
			color = Color(0.78, 0.62, 0.22, 1.0)
		"locked", "locked_p1":
			color = Color(DEPLOY_P1.r * DEPLOY_LOCKED_SCALE, DEPLOY_P1.g * DEPLOY_LOCKED_SCALE, DEPLOY_P1.b * DEPLOY_LOCKED_SCALE, 1.0)
		"locked_p2":
			color = Color(DEPLOY_P2.r * DEPLOY_LOCKED_SCALE, DEPLOY_P2.g * DEPLOY_LOCKED_SCALE, DEPLOY_P2.b * DEPLOY_LOCKED_SCALE, 1.0)
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
