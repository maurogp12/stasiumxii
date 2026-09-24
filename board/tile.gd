extends Node2D
class_name BoardTile

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var highlight: String = ""
var elevation: int = 0
var terrain_type: String = "ground"


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -TILE_HEIGHT / 2.0),
		Vector2(TILE_WIDTH / 2.0, 0),
		Vector2(0, TILE_HEIGHT / 2.0),
		Vector2(-TILE_WIDTH / 2.0, 0)
	])
	var color := _terrain_color()
	match highlight:
		"move":
			color = Color(0.45, 0.78, 0.92, 1.0)
		"advance":
			color = Color(0.72, 0.58, 0.95, 1.0)
		"range":
			color = Color(0.95, 0.78, 0.32, 1.0)
		"target":
			color = Color(0.95, 0.55, 0.28, 1.0)
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
	draw_colored_polygon(points, color)
	if highlight == "blocked":
		draw_line(Vector2(-14, -6), Vector2(14, 6), Color(0.55, 0.52, 0.48), 2.0, true)
		draw_line(Vector2(14, -6), Vector2(-14, 6), Color(0.55, 0.52, 0.48), 2.0, true)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.25, 0.15, 0.25), 1.0, true)

	var font := ThemeDB.fallback_font
	var label := "%s %s" % [terrain_letter(), elevation_text()]
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	draw_string(font, Vector2(-label_size.x * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.06, 0.06))


func apply_board_data(next_terrain: String, next_elevation: Variant = 0) -> void:
	terrain_type = SNAPSHOT_TILES.normalize_terrain(next_terrain)
	elevation = SNAPSHOT_TILES.normalize_elevation(next_elevation)
	queue_redraw()


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func set_highlight(kind: String) -> void:
	highlight = kind
	queue_redraw()


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
