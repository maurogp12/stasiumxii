class_name ProtoMoveSim
extends RefCounted

## Phase B+ prototype move brain. Pure data — does not touch CombatSim.
## Proposed (not Locked): terrain MP + elevation climb/drop on ortho edges only.
## Dest-click uses Dijkstra / uniform-cost; reconstructs the cheapest MP path.

const ORTHO: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var width: int = 8
var height: int = 8
var terrains: Dictionary = {}
var tiles: Dictionary = {}
var occupied: Dictionary = {}


func _init(board_width: int = 8, board_height: int = 8) -> void:
	width = board_width
	height = board_height
	terrains = TerrainDef.catalog()
	_fill_ground()


func _fill_ground() -> void:
	tiles.clear()
	for y in range(height):
		for x in range(width):
			set_tile(Vector2i(x, y), TerrainDef.Id.GROUND, 0.0)


func set_tile(pos: Vector2i, terrain_type: TerrainDef.Id, elevation: float, walkable_override: Variant = null) -> void:
	var tile := BoardTileData.new()
	tile.grid_pos = pos
	tile.terrain_type = terrain_type
	tile.elevation = elevation
	tile.walkable_override = walkable_override
	tiles[pos] = tile


func occupy(cell: Vector2i) -> void:
	occupied[cell] = true


func vacate(cell: Vector2i) -> void:
	occupied.erase(cell)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func tile_at(cell: Vector2i) -> BoardTileData:
	if tiles.has(cell):
		return tiles[cell]
	return null


func terrain_of(cell: Vector2i) -> TerrainDef:
	var tile := tile_at(cell)
	if tile == null:
		return terrains[TerrainDef.Id.GROUND]
	return terrains[tile.terrain_type]


func is_walkable(cell: Vector2i) -> bool:
	var tile := tile_at(cell)
	if tile == null:
		return false
	return tile.is_walkable(terrain_of(cell))


func is_occupied(cell: Vector2i, ignore: Vector2i = Vector2i(9999, 9999)) -> bool:
	if cell == ignore:
		return false
	return occupied.has(cell)


func step_cost(from: Vector2i, to: Vector2i, ignore_occupant: Vector2i = Vector2i(9999, 9999)) -> Dictionary:
	var delta_cell: Vector2i = to - from
	if absi(delta_cell.x) + absi(delta_cell.y) != 1:
		return _step_fail("not_ortho")
	if not in_bounds(from) or not in_bounds(to):
		return _step_fail("out_of_bounds")
	var dest_tile := tile_at(to)
	var src_tile := tile_at(from)
	if dest_tile == null or src_tile == null:
		return _step_fail("out_of_bounds")
	var dest_def: TerrainDef = terrains[dest_tile.terrain_type]
	if not dest_tile.is_walkable(dest_def):
		return _step_fail("not_walkable")
	if is_occupied(to, ignore_occupant):
		return _step_fail("occupied")
	var elev: Dictionary = ElevationCost.analyze(src_tile.elevation, dest_tile.elevation)
	if not bool(elev["legal"]):
		return {
			"ok": false,
			"cost": 0,
			"reason": str(elev["reason"]),
			"terrain_mp": dest_def.base_mp,
			"climb_mp": 0,
			"delta": elev["delta"],
		}
	var climb_mp := int(elev["climb_mp"])
	return {
		"ok": true,
		"cost": dest_def.base_mp + climb_mp,
		"reason": "",
		"terrain_mp": dest_def.base_mp,
		"climb_mp": climb_mp,
		"delta": elev["delta"],
	}


func validate_step(from: Vector2i, to: Vector2i, remaining_mp: int, ignore_occupant: Vector2i = Vector2i(9999, 9999)) -> Dictionary:
	var step := step_cost(from, to, ignore_occupant)
	if not bool(step["ok"]):
		return step
	if int(step["cost"]) > remaining_mp:
		step["ok"] = false
		step["reason"] = "insufficient_mp"
	return step


func validate_move(from: Vector2i, dest: Vector2i, remaining_mp: int) -> Dictionary:
	if dest == from:
		return _move_fail("same_tile")
	if not in_bounds(dest):
		return _move_fail("out_of_bounds")
	if not in_bounds(from):
		return _move_fail("out_of_bounds")
	var reach := reachable(from, remaining_mp)
	if reach.has(dest):
		return {
			"ok": true,
			"reason": "",
			"cost": int(reach[dest]["cost"]),
			"path": reconstruct_path(reach, from, dest),
		}
	var adjacent := step_cost(from, dest, from)
	if str(adjacent.get("reason", "")) != "not_ortho":
		if bool(adjacent.get("ok", false)) and int(adjacent["cost"]) > remaining_mp:
			return _move_fail("insufficient_mp")
		return _move_fail(str(adjacent.get("reason", "unreachable")))
	var unlimited := reachable(from, 9999)
	if unlimited.has(dest):
		return _move_fail("insufficient_mp")
	return _move_fail("unreachable")


func reachable(from: Vector2i, remaining_mp: int) -> Dictionary:
	# Uniform-cost / Dijkstra on ortho edges. Keys are dest cells (start included at 0).
	var best := {}
	if not in_bounds(from):
		return best
	best[from] = {"cost": 0, "prev": from}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var current := _pop_cheapest(frontier, best)
		var spent := int(best[current]["cost"])
		for dir in ORTHO:
			var nxt: Vector2i = current + dir
			var step := step_cost(current, nxt, from)
			if not bool(step["ok"]):
				continue
			var total := spent + int(step["cost"])
			if total > remaining_mp:
				continue
			if best.has(nxt) and int(best[nxt]["cost"]) <= total:
				continue
			best[nxt] = {"cost": total, "prev": current}
			frontier.append(nxt)
	return best


func cheapest_path(from: Vector2i, dest: Vector2i, remaining_mp: int) -> Dictionary:
	return validate_move(from, dest, remaining_mp)


func reconstruct_path(best: Dictionary, from: Vector2i, dest: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not best.has(dest):
		return path
	var cursor: Vector2i = dest
	while cursor != from:
		path.push_front(cursor)
		if not best.has(cursor):
			return [] as Array[Vector2i]
		cursor = best[cursor]["prev"]
		if path.size() > width * height + 2:
			return [] as Array[Vector2i]
	return path


func apply_move(from: Vector2i, dest: Vector2i, remaining_mp: int) -> Dictionary:
	var check := validate_move(from, dest, remaining_mp)
	if not bool(check["ok"]):
		return check
	vacate(from)
	occupy(dest)
	check["mp_left"] = remaining_mp - int(check["cost"])
	check["from"] = from
	check["to"] = dest
	return check


func reachable_dests(from: Vector2i, remaining_mp: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach := reachable(from, remaining_mp)
	for cell in reach.keys():
		if cell == from:
			continue
		out.append(cell)
	return out


func load_demo_map() -> void:
	## Proposed demo layout — not Locked. 8×8 with mud/water/lava and a ridge.
	width = 8
	height = 8
	occupied.clear()
	terrains = TerrainDef.catalog()
	_fill_ground()
	var marks: Array = [
		[1, 1, TerrainDef.Id.MUD, 0.0],
		[1, 2, TerrainDef.Id.MUD, 1.0],
		[2, 5, TerrainDef.Id.WATER, 0.0],
		[3, 2, TerrainDef.Id.WATER, 0.0],
		[3, 3, TerrainDef.Id.WATER, 0.0],
		[3, 5, TerrainDef.Id.WATER, 0.0],
		[3, 6, TerrainDef.Id.LAVA, 2.0],
		[5, 1, TerrainDef.Id.GROUND, 0.5],
		[5, 2, TerrainDef.Id.GROUND, 0.5],
		[5, 3, TerrainDef.Id.GROUND, 1.0],
		[5, 4, TerrainDef.Id.GROUND, 1.0],
		[5, 5, TerrainDef.Id.GROUND, 0.5],
		[6, 0, TerrainDef.Id.GROUND, 1.0],
		[6, 1, TerrainDef.Id.GROUND, 1.0],
		[6, 2, TerrainDef.Id.GROUND, 1.0],
		[6, 3, TerrainDef.Id.LAVA, 2.0],
		[6, 4, TerrainDef.Id.GROUND, 0.0],
		[7, 0, TerrainDef.Id.GROUND, 2.0],
		[7, 1, TerrainDef.Id.GROUND, 0.0],
	]
	for row in marks:
		set_tile(Vector2i(int(row[0]), int(row[1])), row[2], float(row[3]))


func _pop_cheapest(frontier: Array[Vector2i], best: Dictionary) -> Vector2i:
	var best_i := 0
	var best_cost := int(best[frontier[0]]["cost"])
	for i in range(1, frontier.size()):
		var cost := int(best[frontier[i]]["cost"])
		if cost < best_cost:
			best_cost = cost
			best_i = i
	var cell: Vector2i = frontier[best_i]
	frontier.remove_at(best_i)
	return cell


func _step_fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"cost": 0,
		"reason": reason,
		"terrain_mp": 0,
		"climb_mp": 0,
		"delta": 0.0,
	}


func _move_fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"cost": 0,
		"path": [] as Array[Vector2i],
	}
