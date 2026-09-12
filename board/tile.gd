extends Node2D
class_name BoardTile

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32

var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false


func _draw() -> void:
	var points := PackedVector2Array([
	Vector2(0, -TILE_HEIGHT / 2.0),
	Vector2(TILE_WIDTH / 2.0, 0),
	Vector2(0, TILE_HEIGHT / 2.0),
	Vector2(-TILE_WIDTH / 2.0, 0)
	])
	#var rectangle := Rect2(0, 0, TILE_WIDTH, TILE_HEIGHT)
	var color := Color(1.0, 0.689, 0.993, 1.0)
	if is_selected:
		color = Color(1.0, 0.85, 0.2, 1.0)
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])

	draw_polyline(outline, Color(0.25, 0.15, 0.25), 1.0, true)

func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()
