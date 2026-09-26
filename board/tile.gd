extends Node2D
class_name BoardTile

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const _KoliseoArt := preload("res://board/koliseo_art.gd")
const _KoliseoLife := preload("res://board/koliseo_life.gd")
## Relative to this tile. Stays under BoardVisualSort.UNIT_Z_BIAS so the
## seat ring and pawn sprite still paint after the overlay, including on
## elevated tiles (the overlay is a child, so it lifts with the diamond).
const OVERLAY_Z: int = 1
const HIGHLIGHT_FILL_ALPHA: float = 0.5
const LABEL_SETTING := "stasium/debug/show_tile_labels"
## Ambush back-tile chrome. Blue so the legal landing is not another gold range cell.
const LEGAL_BLUE := Color(0.32, 0.66, 0.98, 1.0)

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var highlight: String = ""
var elevation: int = 0
var terrain_type: String = "ground"
var _dress: String = ""
var _paint_props: Array = []
var _grade_key: String = ""
var _grid_on: bool = false
var _life_mat: ShaderMaterial
var _grid: GridInk
var _overlay: HighlightOverlay


class GridInk extends Node2D:
	var host: BoardTile

	func _draw() -> void:
		if host == null or not host.grid_ink_on():
			return
		var pts := host.diamond_points()
		var loop := PackedVector2Array(pts)
		loop.append(pts[0])
		draw_polyline(loop, KoliseoLife.GRID_INK, KoliseoLife.GRID_INK_PX, true)
		draw_polyline(loop, KoliseoLife.GRID_GLEAM, KoliseoLife.GRID_GLEAM_PX, true)


class HighlightOverlay extends Node2D:
	var host: BoardTile

	func _draw() -> void:
		if host != null:
			host.paint_highlight_overlay(self)


func _ready() -> void:
	_ensure_grid()
	_ensure_overlay()


func _draw() -> void:
	var points := _diamond_points()
	var tex := _KoliseoArt.terrain_texture(terrain_type, elevation, _dress)
	if tex == null:
		draw_colored_polygon(points, fill_color())
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, Color(0.25, 0.15, 0.25), 1.0, true)
	else:
		_paint_terrain(tex)
		_paint_depth_rim()
	for prop_name in _paint_props:
		var prop_tex := _KoliseoArt.prop_texture(str(prop_name))
		if prop_tex != null:
			_paint_prop(prop_tex)
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
	_grade_key = ""
	_request_paint()


## Ship arenas get a contrast / sheen grade. Other boards keep the raw sheet.
func apply_koliseo_grade(map_id: String) -> void:
	var key := "%s|%s|%d|%d,%d" % [map_id, terrain_type, elevation, grid_position.x, grid_position.y]
	if key == _grade_key:
		return
	_grade_key = key
	var spec: Dictionary = _KoliseoLife.grade_for(map_id, terrain_type, elevation, grid_position)
	if not bool(spec.get("ship", false)):
		_set_grid_on(false)
		if material != null:
			material = null
			_life_mat = null
		return
	_set_grid_on(true)
	if _life_mat == null or not (material is ShaderMaterial):
		_life_mat = ShaderMaterial.new()
		_life_mat.shader = _KoliseoLife.GROUND_SHADER
		material = _life_mat
	var grade: Color = spec["grade"]
	var sheen: Color = spec["shimmer_color"]
	_life_mat.set_shader_parameter("contrast", float(spec["contrast"]))
	_life_mat.set_shader_parameter("sat_boost", float(spec["sat"]))
	_life_mat.set_shader_parameter("lift", float(spec["lift"]))
	_life_mat.set_shader_parameter("grade", Vector3(grade.r, grade.g, grade.b))
	_life_mat.set_shader_parameter("shimmer", float(spec["shimmer"]))
	_life_mat.set_shader_parameter("shimmer_color", Vector3(sheen.r, sheen.g, sheen.b))
	_life_mat.set_shader_parameter("shimmer_speed", float(spec["speed"]))
	_life_mat.set_shader_parameter("phase", float(spec["phase"]))
	_life_mat.set_shader_parameter("pulse_amp", float(spec["pulse"]))
	_life_mat.set_shader_parameter("pulse_speed", 0.9 + float(spec["pulse"]) * 4.0)


func apply_board_data(next_terrain: String, next_elevation: Variant = 0) -> void:
	terrain_type = SNAPSHOT_TILES.normalize_terrain(next_terrain)
	elevation = SNAPSHOT_TILES.normalize_elevation(next_elevation)
	_request_paint()


func set_paint_props(props: Array) -> void:
	_paint_props = props.duplicate()
	_request_paint()


func _draw_centered(tex: Texture2D) -> void:
	var size := tex.get_size()
	draw_texture(tex, Vector2(-size.x * 0.5, -size.y * 0.5))


func _paint_terrain(tex: Texture2D) -> void:
	var placed: Dictionary = _KoliseoArt.terrain_placement(tex)
	if placed.is_empty():
		_draw_centered(tex)
		return
	draw_texture_rect_region(tex, placed["dest"], placed["source"])


## North rim catches light, south rim separates the diamond from the tile behind it.
## Drawn only on a real sheet so the flat proto fill stays the terrain color.
func _paint_depth_rim() -> void:
	var pts := _diamond_points()
	var south := Color(0.05, 0.03, 0.06, 0.55)
	var north := Color(1.0, 0.97, 0.86, 0.42)
	draw_line(pts[1], pts[2], south, 2.4, true)
	draw_line(pts[2], pts[3], south, 2.4, true)
	draw_line(pts[3], pts[0], north, 1.6, true)
	draw_line(pts[0], pts[1], north, 1.6, true)
	if elevation <= 0:
		return
	var foot: Vector2 = pts[2]
	var drop := 1.5 + float(elevation) * 1.7
	draw_line(foot + Vector2(-7, 1), foot + Vector2(7, 1), Color(0, 0, 0, 0.28), 2.2, true)
	draw_line(foot, foot + Vector2(0, drop), Color(0, 0, 0, 0.18), 2.6, true)


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
		"void":
			return "V"
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
	canvas.draw_colored_polygon(points, color)
	if overlay_draws_outline():
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		var line := Color(color.r, color.g, color.b, 0.95)
		var width := 4.2 if highlight == "origin" or highlight == "landing" else (3.4 if highlight == "range" else 1.8)
		if is_selected:
			width = maxf(width, 5.0)
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


func grid_ink_on() -> bool:
	return _grid_on


func diamond_points() -> PackedVector2Array:
	return _diamond_points()


func _set_grid_on(enabled: bool) -> void:
	_grid_on = enabled
	_ensure_grid()
	if _grid != null and is_instance_valid(_grid):
		_grid.queue_redraw()


func _ensure_grid() -> void:
	if _grid != null and is_instance_valid(_grid):
		return
	_grid = GridInk.new()
	_grid.name = "GridInk"
	_grid.z_index = 0
	_grid.z_as_relative = true
	_grid.host = self
	add_child(_grid)


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
		"legal":
			# Ambush's Manhattan 1–2 cardinal cross, measured from the Shade.
			color = LEGAL_BLUE
		"target":
			color = Color(0.95, 0.55, 0.28, 1.0)
		"origin":
			color = Color(0.72, 0.32, 1.0, 1.0)
		"landing":
			# Rosebud legal cell. The back tile reads blue, measured from the
			# Shade (or from Gloam while Invisible). Not a kit number.
			color = LEGAL_BLUE
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
		"grey":
			# Illegal Drop Shade cells. Dim, and a selection does not arm them gold.
			color = Color(0.34, 0.33, 0.36, 1.0)
	if is_selected and highlight != "blocked" and highlight != "grey":
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
		"void":
			return Color(0.07, 0.07, 0.09)
		_:
			if (grid_position.x + grid_position.y) % 2 == 0:
				return Color(0.58, 0.74, 0.40)
			return Color(0.48, 0.64, 0.34)
