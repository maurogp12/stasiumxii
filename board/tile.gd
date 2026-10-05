extends Node2D
class_name BoardTile

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const _KoliseoArt := preload("res://board/koliseo_art.gd")
const _KoliseoLife := preload("res://board/koliseo_life.gd")
const _ArenaLook := preload("res://board/arena_look.gd")
const _SURFACE_SHADER := preload("res://board/arena_surface.gdshader")
## Relative to this tile. Stays under BoardVisualSort.UNIT_Z_BIAS so the
## seat ring and pawn sprite still paint after the overlay, including on
## elevated tiles (the overlay is a child, so it lifts with the diamond).
const OVERLAY_Z: int = 1
const HIGHLIGHT_FILL_ALPHA: float = 0.5
const LABEL_SETTING := "stasium/debug/show_tile_labels"
## Ambush back-tile chrome. Blue so the legal landing is not another gold range cell.
const LEGAL_BLUE := Color(0.32, 0.66, 0.98, 1.0)
## Dofus read: walk range is a bright green field; the two seats are blue and red.
## Pawn seat rings reuse the team colors so a zone and its fighter match.
const MOVE_GREEN := Color(0.40, 0.86, 0.30, 1.0)
const TEAM_BLUE := Color(0.26, 0.54, 1.0, 1.0)
const TEAM_RED := Color(0.94, 0.28, 0.26, 1.0)

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var highlight: String = ""
var elevation: int = 0
var terrain_type: String = "ground"
## Mauro 5 Oct 2026: a tile no fighter can walk onto is marked in the map's
## own style ("Instead of being red make look a style with the map ... maybe
## the water tiles you should already know ... put it like a glow").
## "liquid" (water / mud / lava): only a soft glow of its own colour.
## "block" (hole / solid obstacle): a shade plus a soft glow in the map accent.
var walk_blocked: bool = false
var walk_block_kind: String = ""
const LIQUID_GLOW := {
	"water": Color(0.45, 0.85, 1.0),
	"mud": Color(0.78, 0.62, 0.36),
	"lava": Color(1.0, 0.55, 0.18),
}
## Map accent for holes / obstacles (ArenaLook ids).
const BLOCK_GLOW := {
	"brinewake": Color(0.35, 0.95, 0.9),
	"slagcrown": Color(1.0, 0.5, 0.15),
	"windmere": Color(0.75, 0.92, 1.0),
	"stormspire": Color(0.7, 0.5, 1.0),
	"crosshaven": Color(1.0, 0.82, 0.42),
}
const BLOCK_GLOW_DEFAULT := Color(0.95, 0.85, 0.6)
const BLOCK_SHADE := Color(0.0, 0.0, 0.02, 0.38)
var _dress: String = ""
var _paint_props: Array = []
var _grade_key: String = ""
## Arena id for the look-picture stamps (empty on proto boards).
var _look_map: String = ""
## Animated surface (lava, runes...) drawn by a child behind the tile's props.
var _surface: SurfaceFx
var _surface_stamp: Texture2D
## Bits 0..3: edges (W-N, N-E, E-S, S-W) that touch the arena's glowing terrain.
var _edge_glow_mask: int = 0
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
		var style: Dictionary = host.grid_style()
		if (style.get("no_grid", []) as Array).has(host.terrain_type):
			return
		draw_polyline(loop, style.get("ink", KoliseoLife.GRID_INK), float(style.get("ink_px", KoliseoLife.GRID_INK_PX)), true)
		draw_polyline(loop, style.get("gleam", KoliseoLife.GRID_GLEAM), float(style.get("gleam_px", KoliseoLife.GRID_GLEAM_PX)), true)


class SurfaceFx extends Node2D:
	var host: BoardTile

	func _draw() -> void:
		if host != null:
			host.paint_surface(self)


class HighlightOverlay extends Node2D:
	var host: BoardTile
	var wall_t := -1.0

	func _process(delta: float) -> void:
		# Only a Snap Wall animates (rise, then the rune pulse).
		if host == null or host.highlight != "blocked":
			wall_t = -1.0
			set_process(false)
			return
		wall_t = maxf(wall_t, 0.0) + delta
		queue_redraw()

	func _draw() -> void:
		if host != null:
			host.paint_highlight_overlay(self)


func _ready() -> void:
	_ensure_grid()
	_ensure_overlay()


func _draw() -> void:
	var points := _diamond_points()
	var look := _ArenaLook.stamp_for(_look_map, terrain_type, grid_position) if _look_map != "" else null
	var tex := _KoliseoArt.terrain_texture_at(terrain_type, elevation, _dress, grid_position)
	if look != null:
		_paint_look(look)
		if not (grid_style().get("no_grid", []) as Array).has(terrain_type):
			_paint_depth_rim()
	elif tex == null:
		_hide_surface()
		draw_colored_polygon(points, fill_color())
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, Color(0.25, 0.15, 0.25), 1.0, true)
	else:
		_hide_surface()
		_paint_terrain(tex)
		_paint_depth_rim()
	var piece: Texture2D = _ArenaLook.centerpiece_for(_look_map, grid_position) if _look_map != "" else null
	if piece != null:
		# Centred on the cell, base a little below the diamond so it sits in the lava.
		var size := piece.get_size()
		draw_texture(piece, Vector2(-size.x * 0.5, float(TILE_HEIGHT) * 0.5 + 6.0 - size.y))
	for prop_name in _paint_props:
		if _look_map != "" and not _ArenaLook.prop_shown_at(_look_map, str(prop_name), grid_position):
			continue
		var prop_tex: Texture2D = _ArenaLook.prop_for(_look_map, str(prop_name)) if _look_map != "" else null
		if prop_tex == null:
			prop_tex = _KoliseoArt.prop_texture(str(prop_name), _dress)
		if prop_tex != null:
			_paint_prop(prop_tex)
	var label := drawn_label()
	if label == "":
		return
	var font := ThemeDB.fallback_font
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	draw_string(font, Vector2(-label_size.x * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.06, 0.06))


## Look-picture stamp on the diamond. A raised cell first drops two shaded
## faces to the ground line so it reads as a block, like the pictures.
func _paint_look(stamp: Texture2D) -> void:
	var pts := _diamond_points()
	var style := grid_style()
	if elevation > 0:
		var drop := Vector2(0, float(elevation) * BoardVisualSort.ELEVATION_PIXELS + 2.0)
		var left_col: Color = style.get("face_left", Color(0.3, 0.26, 0.22))
		var right_col: Color = style.get("face_right", Color(0.22, 0.19, 0.16))
		# Lit at the top, falling into shade at the foot: a block, not a hole.
		draw_polygon(PackedVector2Array([pts[3], pts[2], pts[2] + drop, pts[3] + drop]),
			PackedColorArray([left_col.lightened(0.18), left_col.lightened(0.12), left_col.darkened(0.45), left_col.darkened(0.4)]))
		draw_polygon(PackedVector2Array([pts[2], pts[1], pts[1] + drop, pts[2] + drop]),
			PackedColorArray([right_col.lightened(0.1), right_col.lightened(0.14), right_col.darkened(0.4), right_col.darkened(0.45)]))
		draw_line(pts[2], pts[2] + drop, Color(0, 0, 0, 0.35), 1.2, true)
	var surface := _ArenaLook.surface_for(_look_map, terrain_type)
	if surface.is_empty():
		_hide_surface()
		draw_texture_rect(stamp, Rect2(-TILE_WIDTH / 2.0, -TILE_HEIGHT / 2.0, TILE_WIDTH, TILE_HEIGHT), false)
	else:
		_show_surface(stamp, int(surface[0]), float(surface[1]))
	if elevation > 0 and style.has("lip"):
		var lip: Color = style["lip"]
		draw_line(pts[3], pts[2], lip, 1.6, true)
		draw_line(pts[2], pts[1], lip, 1.6, true)
	_paint_edge_glow(style)


## Terrain-side glow where this cell meets the arena's hot terrain (lava).
func _paint_edge_glow(style: Dictionary) -> void:
	if _edge_glow_mask == 0 or not style.has("edge_glow"):
		return
	var glow: Color = style["edge_glow"]
	var pts := _diamond_points()
	var center := Vector2.ZERO
	var edges := [[pts[3], pts[0]], [pts[0], pts[1]], [pts[1], pts[2]], [pts[2], pts[3]]]
	for i in 4:
		if (_edge_glow_mask >> i) & 1 == 0:
			continue
		var a: Vector2 = edges[i][0]
		var b: Vector2 = edges[i][1]
		var ia := a.lerp(center, 0.34)
		var ib := b.lerp(center, 0.34)
		var clear := Color(glow.r, glow.g, glow.b, 0.0)
		draw_polygon(PackedVector2Array([a, b, ib, ia]), PackedColorArray([glow, glow, clear, clear]))
		draw_line(a, b, Color(1.0, 0.85, 0.45, 0.9), 1.4, true)


func set_edge_glow(mask: int) -> void:
	if mask == _edge_glow_mask:
		return
	_edge_glow_mask = mask
	_request_paint()


func _show_surface(stamp: Texture2D, mode: int, gain: float) -> void:
	if _surface == null or not is_instance_valid(_surface):
		_surface = SurfaceFx.new()
		_surface.name = "Surface"
		_surface.host = self
		_surface.show_behind_parent = true
		var mat := ShaderMaterial.new()
		mat.shader = _SURFACE_SHADER
		_surface.material = mat
		add_child(_surface)
	var smat := _surface.material as ShaderMaterial
	smat.set_shader_parameter("mode", mode)
	smat.set_shader_parameter("gain", gain)
	_surface.visible = true
	if _surface_stamp != stamp:
		_surface_stamp = stamp
		_surface.queue_redraw()


func _hide_surface() -> void:
	if _surface != null and is_instance_valid(_surface):
		_surface.visible = false


func paint_surface(canvas: CanvasItem) -> void:
	if _surface_stamp == null:
		return
	canvas.draw_texture_rect(_surface_stamp, Rect2(-TILE_WIDTH / 2.0, -TILE_HEIGHT / 2.0, TILE_WIDTH, TILE_HEIGHT), false)


## Grid ink for this arena. Empty keeps the shared KoliseoLife ink.
func grid_style() -> Dictionary:
	return _ArenaLook.style_for(_look_map) if _look_map != "" else {}


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
	_look_map = _ArenaLook.normalize(map_id) if _ArenaLook.has_look(map_id) else ""
	var spec: Dictionary = _KoliseoLife.grade_for(map_id, terrain_type, elevation, grid_position)
	if _look_map != "" and bool(spec.get("ship", false)):
		# The stamps already carry the picture's color: keep the grade light.
		spec["contrast"] = 1.03
		spec["sat"] = 1.04
		spec["grade"] = Color.WHITE
		spec["lift"] = (1.0 + float(maxi(elevation, 0)) * _KoliseoLife.ELEV_LIFT) * (1.0 + 0.035 * float((grid_position.x + grid_position.y + 1) % 2))
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


func set_walk_blocked(kind: Variant) -> void:
	var next := ""
	if typeof(kind) == TYPE_BOOL:
		next = "block" if bool(kind) else ""
	else:
		next = str(kind)
	if walk_block_kind == next:
		return
	walk_block_kind = next
	walk_blocked = next != ""
	_request_paint()


func walk_glow_color() -> Color:
	if walk_block_kind == "liquid":
		return LIQUID_GLOW.get(terrain_type, LIQUID_GLOW["water"])
	return BLOCK_GLOW.get(_look_map, BLOCK_GLOW_DEFAULT)


## A soft inner glow: rings fading toward the middle of the diamond.
func _paint_walk_blocked(canvas: CanvasItem) -> void:
	var points := _diamond_points()
	var glow := walk_glow_color()
	var strength := 0.55 if walk_block_kind == "liquid" else 0.8
	if walk_block_kind == "block":
		canvas.draw_colored_polygon(points, BLOCK_SHADE)
	var rings := [[0.96, 3.0, 1.0], [0.88, 3.0, 0.55], [0.8, 3.0, 0.28], [0.72, 2.5, 0.12]]
	for ring in rings:
		var line := PackedVector2Array()
		for p in points:
			line.append(p * float(ring[0]))
		line.append(line[0])
		canvas.draw_polyline(line, Color(glow.r, glow.g, glow.b, strength * float(ring[2])), float(ring[1]), true)


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


## F3 toggles the project setting only when dev overlays are explicitly on.
## A debug sideload is still a debug build, so that alone must not arm the key.
static func consume_debug_label_key(event: InputEvent) -> bool:
	if not DebugChrome.overlays_enabled():
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
	if walk_blocked:
		_paint_walk_blocked(canvas)
	var color := overlay_color()
	if color.a <= 0.0:
		return
	if highlight == "blocked" and not is_selected:
		_paint_snap_wall(canvas)
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


## Bastion Snap Wall: a charcoal rampart with gold trim and a glowing shield
## rune, rising out of the tile when it appears. View only; the sim owns the
## blocked cell and its duration.
const WALL_RISE_SEC := 0.28
## Mauro (29 Sep 2026): "make it look like a realistic wall". Sprite baked
## by build_tools/art/snap_wall.py at 4x; anchor = base diamond centre.
const WALL_TEX := preload("res://art/vfx/wall/snap_wall.png")
const WALL_TEX_SCALE := 0.25
const WALL_TEX_ANCHOR := Vector2(160, 296)
## Carved shield on the lit face, in tile-local px.
const WALL_SHIELD := Vector2(-14.4, -13.6)


func _paint_snap_wall(canvas: CanvasItem) -> void:
	var t := 1.0
	var pulse := 0.5
	if _overlay != null and is_instance_valid(_overlay):
		if _overlay.wall_t < 0.0:
			_overlay.wall_t = 0.0
			_overlay.set_process(true)
		var e := _overlay.wall_t
		var u := clampf(e / WALL_RISE_SEC, 0.0, 1.0)
		# Overshoot a touch, then settle: the wall slams up.
		t = 1.0 - pow(1.0 - u, 3.0) + sin(u * PI) * 0.12
		pulse = 0.5 + 0.5 * sin(e * 3.0)
	# Baked stone masonry block (build_tools/art/snap_wall.py, 4x). The base
	# diamond centre is the tile origin; scaling Y from there raises it.
	var scale := WALL_TEX_SCALE
	var size := WALL_TEX.get_size() * scale
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, maxf(t, 0.02)))
	canvas.draw_texture_rect(WALL_TEX, Rect2(-WALL_TEX_ANCHOR * scale, size), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Bastion's shield rune breathes gold once the wall is up.
	if t > 0.8:
		var glow := Color(1.0, 0.8, 0.32, 0.10 + 0.22 * pulse)
		canvas.draw_circle(WALL_SHIELD, 7.5 + 1.5 * pulse, glow)
		canvas.draw_circle(WALL_SHIELD, 3.5, Color(1.0, 0.9, 0.55, 0.12 + 0.2 * pulse))


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
			color = MOVE_GREEN
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
			color = TEAM_BLUE
		"zone_p2":
			color = TEAM_RED
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
