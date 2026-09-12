extends Node2D

const BOARD_SIZE: int = 8
const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")
const PAWN_SCENE: PackedScene = preload("res://units/pawn.tscn")
const MAX_MP: int = 3


var tiles: Dictionary = {}
var selected_tile: BoardTile = null
var pawn: Pawn
var remaining_mp: int = MAX_MP

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
			tiles[tile.grid_position] = tile
			print(tile.grid_position)
	spawn_pawn()
	end_turn()

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
					select_tile(cell)
					try_move_pawn(cell)

func select_tile(cell: Vector2i) -> void:
	if selected_tile != null:
		selected_tile.set_selected(false)

	selected_tile = tiles[cell] as BoardTile
	selected_tile.set_selected(true)

func spawn_pawn() -> void:
	pawn = PAWN_SCENE.instantiate() as Pawn
	pawn.grid_position = Vector2i(1, 1)

	pawn.position = Vector2(
		(pawn.grid_position.x - pawn.grid_position.y) * 32,
		(pawn.grid_position.x + pawn.grid_position.y) * 16
	)

	$Units.add_child(pawn)

func try_move_pawn(destination: Vector2i) -> void:
	if remaining_mp <= 0:
		print("No movement points left.")
		return

	var difference := destination - pawn.grid_position
	var distance: int = abs(difference.x) + abs(difference.y)

	if distance != 1:
		return

	pawn.grid_position = destination
	remaining_mp -= 1

	pawn.position = Vector2(
		(destination.x - destination.y) * 32,
		(destination.x + destination.y) * 16
	)

	print("MP remaining: ", remaining_mp)
	
func end_turn() -> void:
	remaining_mp = MAX_MP
	print("MP remaining: ", remaining_mp)
