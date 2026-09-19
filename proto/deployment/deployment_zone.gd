class_name DeploymentZone
extends RefCounted

## Configurable deployment zone: one player + a set of cells.
## Proposed — not Locked.
##
## 1v1 default is the 1-deep border ring, split into opposite halves:
##   Seat 0 (P1): south + west
##   Seat 1 (P2): north + east
## Corner cells belong to the north/south edge so the halves never overlap:
##   NW (0,0) and NE (N-1,0) → seat 1
##   SW (0,N-1) and SE (N-1,N-1) → seat 0
## Same-edge camp is impossible: the seats share no edge.

var player_id: int = 0
var cells: Array[Vector2i] = []


func _init(p_player_id: int = 0, p_cells: Array = []) -> void:
	player_id = p_player_id
	cells.clear()
	for cell in p_cells:
		cells.append(cell as Vector2i)


func contains(cell: Vector2i) -> bool:
	return cells.has(cell)


func duplicate_zone() -> DeploymentZone:
	return DeploymentZone.new(player_id, cells)


static func box(origin: Vector2i, width: int, height: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(origin.y, origin.y + height):
		for x in range(origin.x, origin.x + width):
			out.append(Vector2i(x, y))
	return out


## 1-deep map border ring: every outer-edge cell of an N×N board.
static func border_ring(board_size: int = 8) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board_size <= 0:
		return out
	for x in range(board_size):
		out.append(Vector2i(x, 0))
		if board_size > 1:
			out.append(Vector2i(x, board_size - 1))
	for y in range(1, board_size - 1):
		out.append(Vector2i(0, y))
		if board_size > 1:
			out.append(Vector2i(board_size - 1, y))
	return out


static func is_border_cell(cell: Vector2i, board_size: int = 8) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= board_size or cell.y >= board_size:
		return false
	return cell.x == 0 or cell.y == 0 or cell.x == board_size - 1 or cell.y == board_size - 1


## Seat 0 owns south (incl. SW/SE) + west exclusive of corners.
static func owns_south_west_half(cell: Vector2i, board_size: int = 8) -> bool:
	if not is_border_cell(cell, board_size):
		return false
	if cell.y == board_size - 1:
		return true
	if cell.x == 0 and cell.y > 0 and cell.y < board_size - 1:
		return true
	return false


## Seat 1 owns north (incl. NW/NE) + east exclusive of corners.
static func owns_north_east_half(cell: Vector2i, board_size: int = 8) -> bool:
	return is_border_cell(cell, board_size) and not owns_south_west_half(cell, board_size)


## Opposite-half split of the 1-deep border ring (1v1).
static func opposite_half_ring(board_size: int = 8) -> Array[DeploymentZone]:
	var p1: Array[Vector2i] = []
	var p2: Array[Vector2i] = []
	for cell in border_ring(board_size):
		if owns_south_west_half(cell, board_size):
			p1.append(cell)
		else:
			p2.append(cell)
	return [
		DeploymentZone.new(0, p1),
		DeploymentZone.new(1, p2),
	]
