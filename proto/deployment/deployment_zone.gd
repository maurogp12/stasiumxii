class_name DeploymentZone
extends RefCounted

## Configurable deployment zone: a player_id plus a set of cells.
## Proposed (not Locked). Starter layout is opposite 2×3 boxes.

var player_id: int = 0
var cells: Array[Vector2i] = []


func _init(owner_id: int = 0) -> void:
	player_id = owner_id


func contains(cell: Vector2i) -> bool:
	return cells.has(cell)


func duplicate_zone() -> DeploymentZone:
	var copy := DeploymentZone.new(player_id)
	copy.cells = cells.duplicate()
	return copy


static func box(owner_id: int, origin: Vector2i, width: int, height: int) -> DeploymentZone:
	var zone := DeploymentZone.new()
	zone.player_id = owner_id
	var boxed: Array[Vector2i] = []
	for y in range(origin.y, origin.y + height):
		for x in range(origin.x, origin.x + width):
			boxed.append(Vector2i(x, y))
	zone.cells = boxed
	return zone


static func opposite_2x3(board_size: int = 8) -> Array[DeploymentZone]:
	## West 2×3 vs east 2×3, vertically centered on an 8×8.
	var origin_y := int((board_size - 3) / 2)
	var east_x := board_size - 2
	var out: Array[DeploymentZone] = []
	out.append(box(0, Vector2i(0, origin_y), 2, 3))
	out.append(box(1, Vector2i(east_x, origin_y), 2, 3))
	return out
