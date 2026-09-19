class_name DeploymentTileView
extends Node2D

## Phase B+ deployment chrome. Iso diamond; highlight kinds are proto-local.
## Does not use Phase A BoardTile.

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32

var grid_pos: Vector2i = Vector2i.ZERO
var highlight: String = ""
var is_selected: bool = false
var walkable: bool = true


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
	var color := _base_color()
	match highlight:
		"zone_p1":
			color = Color(0.36, 0.72, 0.52)
		"zone_p2":
			color = Color(0.78, 0.42, 0.42)
		"occupied":
			color = Color(0.78, 0.62, 0.22)
		"locked":
			color = Color(0.42, 0.40, 0.48)
		"invalid":
			color = Color(0.28, 0.22, 0.24)
	if is_selected:
		color = Color(1.0, 0.84, 0.22)
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	var line := Color(0.16, 0.10, 0.12, 0.95)
	if is_selected:
		line = Color(1.0, 0.92, 0.25)
	draw_polyline(outline, line, 1.8 if is_selected else 1.0, true)

	var font := ThemeDB.fallback_font
	var label := "%d,%d" % [grid_pos.x, grid_pos.y]
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	draw_string(font, Vector2(-label_size.x * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.06, 0.06))


func _base_color() -> Color:
	if not walkable:
		return Color(0.32, 0.24, 0.26)
	if (grid_pos.x + grid_pos.y) % 2 == 0:
		return Color(0.58, 0.70, 0.48)
	return Color(0.48, 0.60, 0.40)
