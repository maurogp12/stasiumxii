extends Node2D
class_name Pawn

var grid_position: Vector2i = Vector2i.ZERO

func _draw() -> void:
	draw_circle(Vector2(0, -12), 10.0, Color.DODGER_BLUE)
