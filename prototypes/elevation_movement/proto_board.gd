extends RefCounted
class_name ProtoBoard

## Phase B+ prototype. Proposed — not Locked.
## Isolated from Phase A CombatSim / main.tscn flat Manhattan walk.
## Ortho-only neighbors (N/E/S/W) — no diagonal edges.

const ORTHO: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var width: int = 0
var height: int = 0
var tiles: Dictionary = {} ## Vector2i -> BoardTileData
var occupied: Dictionary = {} ## Vector2i -> String occupant id


func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h


static func iso_world(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_tile(cell: Vector2i) -> BoardTileData:
	if not tiles.has(cell):
		return null
	return tiles[cell] as BoardTileData


func set_cell(cell: Vector2i, elev: float, terrain: TerrainCatalog.Type) -> BoardTileData:
	var tile := BoardTileData.make(cell, elev, terrain, iso_world(cell))
	tiles[cell] = tile
	width = maxi(width, cell.x + 1)
	height = maxi(height, cell.y + 1)
	return tile


func fill_ground(w: int, h: int, elev: float = 0.0) -> void:
	width = w
	height = h
	tiles.clear()
	for y in range(h):
		for x in range(w):
			set_cell(Vector2i(x, y), elev, TerrainCatalog.Type.GROUND)


func is_occupied(cell: Vector2i) -> bool:
	return occupied.has(cell)


func occupant_id(cell: Vector2i) -> String:
	return str(occupied.get(cell, ""))


func set_occupied(cell: Vector2i, occupant: String) -> void:
	if occupant == "":
		occupied.erase(cell)
	else:
		occupied[cell] = occupant


func clear_occupied() -> void:
	occupied.clear()


func ortho_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for step in ORTHO:
		var next: Vector2i = cell + step
		if in_bounds(next):
			out.append(next)
	return out


func is_ortho_step(from: Vector2i, to: Vector2i) -> bool:
	return absi(to.x - from.x) + absi(to.y - from.y) == 1
