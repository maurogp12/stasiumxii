class_name ProtoTileView
extends Node2D

## Phase B+ prototype tile VIEW. Paints terrain + elevation label.
## z_index is set by the board from ProtoVisualSort (visual-only).

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32

var grid_pos: Vector2i = Vector2i.ZERO
var elevation: float = 0.0
var terrain_type: TerrainDef.Id = TerrainDef.Id.GROUND
var highlight: String = ""
var is_selected: bool = false


func apply_tile(tile: BoardTileData) -> void:
	grid_pos = tile.grid_pos
	elevation = tile.elevation
	terrain_type = tile.terrain_type
	queue_redraw()


func set_highlight(kind: String) -> void:
	highlight = kind
	queue_redraw()


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -TILE_HEIGHT / 2.0),
		Vector2(TILE_WIDTH / 2.0, 0),
		Vector2(0, TILE_HEIGHT / 2.0),
		Vector2(-TILE_WIDTH / 2.0, 0),
	])
	var color := _terrain_color()
	if highlight == "move":
		color = color.lerp(Color(0.35, 0.85, 0.95, 1.0), 0.55)
	if is_selected or highlight == "selected":
		color = color.lerp(Color(1.0, 0.88, 0.25, 1.0), 0.45)
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	var line := Color(0.18, 0.12, 0.12, 0.95)
	if is_selected:
		line = Color(1.0, 0.9, 0.2)
	draw_polyline(outline, line, 1.4 if is_selected else 1.0, true)

	var font := ThemeDB.fallback_font
	var elev_text := _elev_text()
	var elev_size := font.get_string_size(elev_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2(-elev_size.x * 0.5, 3), elev_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.08, 0.06, 0.06))
	var name_text := _terrain_letter()
	var name_size := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
	draw_string(font, Vector2(-name_size.x * 0.5, -6), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.12, 0.08, 0.08, 0.85))


func _terrain_color() -> Color:
	match terrain_type:
		TerrainDef.Id.MUD:
			return Color(0.56, 0.38, 0.20)
		TerrainDef.Id.WATER:
			return Color(0.28, 0.54, 0.80)
		TerrainDef.Id.LAVA:
			return Color(0.86, 0.30, 0.12)
		_:
			if (grid_pos.x + grid_pos.y) % 2 == 0:
				return Color(0.58, 0.74, 0.40)
			return Color(0.48, 0.64, 0.34)


func _elev_text() -> String:
	if is_equal_approx(elevation, roundf(elevation)):
		return str(int(round(elevation)))
	return "%.1f" % elevation


func _terrain_letter() -> String:
	match terrain_type:
		TerrainDef.Id.MUD:
			return "M"
		TerrainDef.Id.WATER:
			return "W"
		TerrainDef.Id.LAVA:
			return "L"
		_:
			return "G"
