extends Node2D
class_name BoardTile

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const _KoliseoArt := preload("res://board/koliseo_art.gd")
const AMBIENT := preload("res://board/board_ambient.gd")
## Relative to this tile. Stays under BoardVisualSort.UNIT_Z_BIAS so the
## seat ring and pawn sprite still paint after the overlay, including on
## elevated tiles (the overlay is a child, so it lifts with the diamond).
const OVERLAY_Z: int = 1
const HIGHLIGHT_FILL_ALPHA: float = 0.5
const LABEL_SETTING := "stasium/debug/show_tile_labels"

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var is_hovered: bool = false
var highlight: String = ""
var elevation: int = 0
var terrain_type: String = "ground"
var _dress: String = ""
var _paint_props: Array = []
var _overlay: HighlightOverlay
var _shimmer_mat: ShaderMaterial
var _ambient_pivots: Array[Node2D] = []
var _breathe_alpha: float = HIGHLIGHT_FILL_ALPHA


class HighlightOverlay extends Node2D:
	var host: BoardTile

	func _draw() -> void:
		if host != null:
			host.paint_highlight_overlay(self)


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	for prop_name in _paint_props:
		var prop_id := str(prop_name)
		if AMBIENT.prop_is_ambient(prop_id):
			continue
		var prop_tex := _KoliseoArt.prop_texture(prop_id)
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
	_sync_shimmer_material()
	_request_paint()


func apply_board_data(next_terrain: String, next_elevation: Variant = 0) -> void:
	terrain_type = SNAPSHOT_TILES.normalize_terrain(next_terrain)
	elevation = SNAPSHOT_TILES.normalize_elevation(next_elevation)
	_sync_shimmer_material()
	_request_paint()


func set_paint_props(props: Array) -> void:
	if _same_props(props):
		return
	_paint_props = props.duplicate()
	_rebuild_ambient_props()
	_request_paint()


## Placement from KoliseoArt, grown by SEAM_BLEED_PX so linear samples meet.
func painted_terrain_dest(placed: Dictionary, tex: Texture2D) -> Rect2:
	if placed.is_empty():
		var size := tex.get_size()
		return Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y).grow(AMBIENT.SEAM_BLEED_PX)
	return (placed["dest"] as Rect2).grow(AMBIENT.SEAM_BLEED_PX)


func _paint_terrain(tex: Texture2D) -> void:
	var placed: Dictionary = _KoliseoArt.terrain_placement(tex)
	var dest := painted_terrain_dest(placed, tex)
	if placed.is_empty():
		draw_texture_rect(tex, dest, false)
		return
	draw_texture_rect_region(tex, dest, placed["source"])


## Props stand on the south tip of the diamond. paint_only never affects pathing.
func _paint_prop(tex: Texture2D) -> void:
	var size := tex.get_size()
	draw_texture(tex, Vector2(-size.x * 0.5, float(TILE_HEIGHT) * 0.5 - size.y))


func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	_request_paint()


func set_hovered(value: bool) -> void:
	if is_hovered == value:
		return
	is_hovered = value
	_request_paint()


func set_highlight(kind: String) -> void:
	if highlight == kind:
		return
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


func draws_crisp_outline() -> bool:
	if highlight == "blocked":
		return false
	return is_hovered or is_selected or highlight == "selected"


func breathe_fill_alpha() -> float:
	return _breathe_alpha


func resync_shimmer() -> void:
	_sync_shimmer_material()


func apply_ambient_frame(time_sec: float) -> void:
	_apply_overlay_breathe(time_sec)
	_apply_prop_breathe(time_sec)
	_apply_flat_shimmer(time_sec)


func paint_highlight_overlay(canvas: CanvasItem) -> void:
	var color := _fill_color_now()
	var points := _diamond_points()
	if color.a > 0.0:
		canvas.draw_colored_polygon(points, color)
		if overlay_draws_outline() and not draws_crisp_outline():
			var outline := PackedVector2Array(points)
			outline.append(points[0])
			var line := Color(color.r, color.g, color.b, 0.95)
			var width := 4.2 if highlight == "origin" or highlight == "landing" else (3.4 if highlight == "range" else 1.8)
			canvas.draw_polyline(outline, line, width, true)
		if highlight == "blocked":
			canvas.draw_line(Vector2(-14, -6), Vector2(14, 6), Color(0.55, 0.52, 0.48), 2.0, true)
			canvas.draw_line(Vector2(14, -6), Vector2(-14, 6), Color(0.55, 0.52, 0.48), 2.0, true)
	if draws_crisp_outline():
		_paint_crisp_outline(canvas, points, color)


func _fill_color_now() -> Color:
	var base := overlay_color()
	if base.a <= 0.0:
		return base
	if not AMBIENT.overlay_breathes(highlight, is_selected) or AMBIENT.motion_reduced():
		return base
	return Color(base.r, base.g, base.b, _breathe_alpha)


func _paint_crisp_outline(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	var rim := Color(0.06, 0.04, 0.03, 0.88)
	var line := Color(1.0, 0.97, 0.86, 0.96)
	if color.a > 0.0:
		line = Color(color.r, color.g, color.b, 0.98)
	canvas.draw_polyline(outline, rim, AMBIENT.CRISP_OUTLINE_PX, true)
	canvas.draw_polyline(outline, line, AMBIENT.CRISP_INNER_PX, true)


func _apply_overlay_breathe(time_sec: float) -> void:
	var next := HIGHLIGHT_FILL_ALPHA
	if AMBIENT.overlay_breathes(highlight, is_selected) and not AMBIENT.motion_reduced():
		next = AMBIENT.overlay_fill_alpha(time_sec, AMBIENT.phase_for(grid_position))
	if is_equal_approx(next, _breathe_alpha):
		return
	_breathe_alpha = next
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _apply_prop_breathe(time_sec: float) -> void:
	if _ambient_pivots.is_empty():
		return
	var reduced := AMBIENT.motion_reduced()
	var phase := AMBIENT.phase_for(grid_position)
	var i := 0
	for pivot in _ambient_pivots:
		if pivot == null or not is_instance_valid(pivot):
			i += 1
			continue
		var local_phase := phase + float(i) * 0.8
		var local := 1.0 if reduced else AMBIENT.prop_scale(time_sec, local_phase)
		if not is_equal_approx(pivot.scale.x, local):
			pivot.scale = Vector2(local, local)
		var sprite := pivot.get_node_or_null("Sprite") as CanvasItem
		if sprite != null:
			var gain := 1.0 if reduced else AMBIENT.prop_gain(time_sec, local_phase)
			var tint := Color(gain, gain, gain, 1.0)
			if sprite.self_modulate != tint:
				sprite.self_modulate = tint
		i += 1


func _apply_flat_shimmer(time_sec: float) -> void:
	var gain := 1.0
	if material == null and AMBIENT.shimmers(terrain_type) and not AMBIENT.motion_reduced():
		gain = AMBIENT.shimmer_gain(time_sec, AMBIENT.phase_for(grid_position), terrain_type)
	var next := Color(gain, gain, gain, 1.0)
	if self_modulate != next:
		self_modulate = next


func _sync_shimmer_material() -> void:
	if not AMBIENT.shimmers(terrain_type) or AMBIENT.motion_reduced():
		material = null
		self_modulate = Color.WHITE
		return
	var tex := _KoliseoArt.terrain_texture(terrain_type, elevation, _dress)
	var shader := AMBIENT.shimmer_shader()
	if tex == null or shader == null:
		material = null
		return
	if _shimmer_mat == null:
		_shimmer_mat = ShaderMaterial.new()
		_shimmer_mat.shader = shader
	_shimmer_mat.set_shader_parameter("phase", AMBIENT.phase_for(grid_position))
	_shimmer_mat.set_shader_parameter("amplitude", AMBIENT.shimmer_amplitude(terrain_type))
	_shimmer_mat.set_shader_parameter("uv_amp", AMBIENT.shimmer_uv(terrain_type))
	_shimmer_mat.set_shader_parameter("speed", AMBIENT.shimmer_speed())
	material = _shimmer_mat
	self_modulate = Color.WHITE


func _same_props(props: Array) -> bool:
	if props.size() != _paint_props.size():
		return false
	for i in props.size():
		if str(props[i]) != str(_paint_props[i]):
			return false
	return true


func _rebuild_ambient_props() -> void:
	_clear_ambient_props()
	var i := 0
	for prop_name in _paint_props:
		var prop_id := str(prop_name)
		if not AMBIENT.prop_is_ambient(prop_id):
			continue
		var tex := _KoliseoArt.prop_texture(prop_id)
		if tex == null:
			continue
		var pivot := Node2D.new()
		pivot.name = "AmbientProp%d" % i
		pivot.position = Vector2(0, float(TILE_HEIGHT) * 0.5)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = tex
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = Vector2(0, -tex.get_height() * 0.5)
		pivot.add_child(sprite)
		add_child(pivot)
		_ambient_pivots.append(pivot)
		i += 1


func _clear_ambient_props() -> void:
	for pivot in _ambient_pivots:
		if pivot == null or not is_instance_valid(pivot):
			continue
		if pivot.get_parent() == self:
			remove_child(pivot)
		pivot.free()
	_ambient_pivots.clear()


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
