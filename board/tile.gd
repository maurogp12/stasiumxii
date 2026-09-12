extends Node2D
class_name BoardTile

var grid_position: Vector2i = Vector2i.ZERO

const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32

func _draw() -> void:
	var points := PackedVector2Array([
	Vector2(0, -TILE_HEIGHT / 2.0),
	Vector2(TILE_WIDTH / 2.0, 0),
	Vector2(0, TILE_HEIGHT / 2.0),
	Vector2(-TILE_WIDTH / 2.0, 0)
	])
	#var rectangle := Rect2(0, 0, TILE_WIDTH, TILE_HEIGHT)
	var color := Color(1.0, 0.689, 0.993, 1.0)
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])

	draw_polyline(outline, Color(0.25, 0.15, 0.25), 1.0, true)
