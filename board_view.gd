extends Node2D

const BOARD_SIZE: int = 8
const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")
const PAWN_SCENE: PackedScene = preload("res://units/pawn.tscn")
const MAX_MP: int = 3


var tiles: Dictionary = {}
var selected_tile: BoardTile = null

var pawns: Array[Pawn] = []
var pawn: Pawn
var active_pawn_index: int = 0
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
	pawn = spawn_pawn(Vector2i(6,6))
	var pawn_two = spawn_pawn(Vector2i(1,1))
	pawns.append(pawn)
	pawns.append(pawn_two)
	
	

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
			var mouse_position: Vector2 = $Tiles.get_local_mouse_position()
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

func spawn_pawn(start_cell: Vector2i) -> Pawn:
	var new_pawn = PAWN_SCENE.instantiate() as Pawn
	new_pawn.grid_position = start_cell

	new_pawn.position = Vector2(
		(new_pawn.grid_position.x - new_pawn.grid_position.y) * 32,
		(new_pawn.grid_position.x + new_pawn.grid_position.y) * 16
	)

	$Units.add_child(new_pawn)
	return new_pawn

func try_move_pawn(destination: Vector2i) -> void:
	if remaining_mp <= 0:
		print("No movement points left.")
		return

	var difference := destination - pawn.grid_position
	var distance: int = abs(difference.x) + abs(difference.y)

	if distance != 1:
		return
	
	if is_tile_occupied(destination):
		return
	
	pawn.grid_position = destination
	remaining_mp -= 1

	pawn.position = Vector2(
		(destination.x - destination.y) * 32,
		(destination.x + destination.y) * 16
	)

	print("MP remaining: ", remaining_mp)

func is_tile_occupied(cell: Vector2i) -> bool:
	for unit in pawns:
		if unit.grid_position == cell:
			return true
	return false

func end_turn() -> void:
	if active_pawn_index == 0:
		active_pawn_index = 1
	elif active_pawn_index == 1:
		active_pawn_index = 0
	remaining_mp = MAX_MP
	pawn = pawns[active_pawn_index]
	print("MP remaining: ", remaining_mp)


func _on_end_turn_button_pressed() -> void:
	end_turn()
