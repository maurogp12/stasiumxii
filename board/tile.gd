extends Node2D
class_name BoardTile

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var highlight: String = ""


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -TILE_HEIGHT / 2.0),
		Vector2(TILE_WIDTH / 2.0, 0),
		Vector2(0, TILE_HEIGHT / 2.0),
		Vector2(-TILE_WIDTH / 2.0, 0)
	])
	var color := Color(0.93, 0.72, 0.86, 1.0)
	if (grid_position.x + grid_position.y) % 2 == 0:
		color = Color(0.86, 0.64, 0.80, 1.0)
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
	if is_selected:
		color = Color(1.0, 0.85, 0.2, 1.0)
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.25, 0.15, 0.25), 1.0, true)


func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()


func set_highlight(kind: String) -> void:
	highlight = kind
	queue_redraw()
