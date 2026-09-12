extends Node2D

const BOARD_SIZE: int = 8
const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")

func _ready() -> void:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var tile := TILE_SCENE.instantiate() as BoardTile

			tile.grid_position = Vector2i(x, y)

			tile.position = Vector2(
			(x - y) * 32,
			(x + y) * 16
			)

			$Tiles.add_child(tile)
			print(tile.grid_position)

func local_to_grid(point: Vector2) -> Vector2i:
	var grid_x := point.x / 64.0 + point.y / 32.0
	var grid_y := point.y / 32.0 - point.x / 64.0

	return Vector2i(
		floori(grid_x + 0.5),
		floori(grid_y + 0.5)
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_position = $Tiles.get_local_mouse_position()
			var cell := local_to_grid(mouse_position)

			if cell.x >= 0 and cell.x < BOARD_SIZE:
				if cell.y >= 0 and cell.y < BOARD_SIZE:
					print("Clicked tile: ", cell)
