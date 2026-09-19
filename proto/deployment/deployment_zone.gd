class_name DeploymentZone
extends RefCounted

## Configurable deployment zone: one player + a set of cells.
## Proposed — not Locked.

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


## Opposite 2×3 boxes on an 8×8, vertically centered.
## P1 (west): x=0–1, y=2–4. P2 (east): x=6–7, y=2–4.
static func opposite_2x3_on_8x8() -> Array[DeploymentZone]:
	return [
		DeploymentZone.new(0, box(Vector2i(0, 2), 2, 3)),
		DeploymentZone.new(1, box(Vector2i(6, 2), 2, 3)),
	]
