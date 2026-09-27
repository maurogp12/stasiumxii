extends RefCounted

## Live walk board + weighted pathfinder. Ported from proto/elevation/proto_move_sim.gd.
## Proto stays reference. CombatSim owns occupancy and submit.
## Locked: dest terrain MP + elevation Δ, ortho-only, Dijkstra cheapest path.
## Legal dests = reachable within remaining MP.
## stand_on_gate is shared with Advance teleport (walkable / occupied / climb / drop).

const _TerrainDef := preload("res://backend/terrain_def.gd")
const _BoardTileData := preload("res://backend/board_tile_data.gd")
const _ElevationCost := preload("res://backend/elevation_cost.gd")

const ORTHO: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var width: int = BoardSize.SHIP
var height: int = BoardSize.SHIP
var terrains: Dictionary = {}
var tiles: Dictionary = {}


func _init(board_width: int = BoardSize.SHIP, board_height: int = BoardSize.SHIP) -> void:
	width = board_width
	height = board_height
	terrains = _TerrainDef.catalog()
	fill_ground()


func fill_ground() -> void:
	tiles.clear()
	for y in range(height):
		for x in range(width):
			set_tile(Vector2i(x, y), _TerrainDef.Id.GROUND, 0)


func set_tile(pos: Vector2i, terrain_type: Variant, elevation: Variant = 0, walkable_override: Variant = null) -> void:
	var tile = _BoardTileData.new()
	tile.grid_pos = pos
	tile.terrain_type = _TerrainDef.parse(terrain_type)
	tile.elevation = _ElevationCost.as_z(elevation)
	tile.walkable_override = walkable_override
	tiles[pos] = tile


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func tile_at(cell: Vector2i):
	if tiles.has(cell):
		return tiles[cell]
	return null


func terrain_of(cell: Vector2i) -> Dictionary:
	var tile = tile_at(cell)
	if tile == null:
		return terrains[_TerrainDef.Id.GROUND]
	return terrains[tile.terrain_type]


func is_walkable(cell: Vector2i) -> bool:
	var tile = tile_at(cell)
	if tile == null:
		return false
	return tile.is_walkable(terrain_of(cell))


## Mud, water, and lava. Voluntary Walk, path nodes, and Advance landings
## refuse these. Mud and water stay walkable for deploy and occupied bodies.
func is_voluntary_impassable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return bool(terrain_of(cell).get("voluntary_impassable", false))


func snapshot_tiles() -> Dictionary:
	var out := {}
	for cell in tiles.keys():
		var tile = tiles[cell]
		out[cell] = tile.snapshot()
	return out


## Shared dest stand-on gates for walk hops and Advance teleport.
## Refuses mud, water, and lava, plus other unwalkable cells.
## Not occupied, climb<=1 / drop<=2 from `from` to `dest`.
## Does not require ortho. Does not charge terrain or elevation MP.
## A unit already standing on mud or water may still step off onto ground.
func stand_on_gate(from: Vector2i, dest: Vector2i, occupied: Callable) -> Dictionary:
	if dest == from:
		return _stand_fail("same_tile")
	if not in_bounds(from) or not in_bounds(dest):
		return _stand_fail("out_of_bounds")
	var dest_tile = tile_at(dest)
	var src_tile = tile_at(from)
	if dest_tile == null or src_tile == null:
		return _stand_fail("out_of_bounds")
	var dest_def: Dictionary = terrains[dest_tile.terrain_type]
	if bool(dest_def.get("voluntary_impassable", false)) or not dest_tile.is_walkable(dest_def):
		return _stand_fail("not_walkable")
	if _is_occupied(dest, from, occupied):
		return _stand_fail("occupied")
	var elev: Dictionary = _ElevationCost.analyze(src_tile.elevation, dest_tile.elevation)
	if not bool(elev["legal"]):
		return {
			"ok": false,
			"reason": str(elev["reason"]),
			"terrain_mp": int(dest_def["base_mp"]),
			"climb_mp": 0,
			"delta": elev["delta"],
		}
	return {
		"ok": true,
		"reason": "",
		"terrain_mp": int(dest_def["base_mp"]),
		"climb_mp": int(elev["climb_mp"]),
		"delta": elev["delta"],
	}


func step_cost(from: Vector2i, to: Vector2i, occupied: Callable) -> Dictionary:
	var delta_cell: Vector2i = to - from
	if absi(delta_cell.x) + absi(delta_cell.y) != 1:
		return _step_fail("not_ortho")
	var gate: Dictionary = stand_on_gate(from, to, occupied)
	if not bool(gate.get("ok", false)):
		return {
			"ok": false,
			"cost": 0,
			"reason": str(gate.get("reason", "not_walkable")),
			"terrain_mp": int(gate.get("terrain_mp", 0)),
			"climb_mp": 0,
			"delta": gate.get("delta", 0),
		}
	var climb_mp := int(gate["climb_mp"])
	return {
		"ok": true,
		"cost": int(gate["terrain_mp"]) + climb_mp,
		"reason": "",
		"terrain_mp": int(gate["terrain_mp"]),
		"climb_mp": climb_mp,
		"delta": gate["delta"],
	}


func validate_move(from: Vector2i, dest: Vector2i, remaining_mp: int, occupied: Callable) -> Dictionary:
	if dest == from:
		return _move_fail("same_tile")
	if not in_bounds(dest):
		return _move_fail("out_of_bounds")
	if not in_bounds(from):
		return _move_fail("out_of_bounds")
	# Dest gates first so mud / water / lava / occupied clicks are not "insufficient_mp".
	if is_voluntary_impassable(dest) or not is_walkable(dest):
		return _move_fail("not_walkable")
	if _is_occupied(dest, from, occupied):
		return _move_fail("occupied")
	var reach := reachable(from, remaining_mp, occupied)
	if reach.has(dest):
		return {
			"ok": true,
			"reason": "",
			"cost": int(reach[dest]["cost"]),
			"path": reconstruct_path(reach, from, dest),
		}
	var adjacent := step_cost(from, dest, occupied)
	if str(adjacent.get("reason", "")) != "not_ortho":
		if bool(adjacent.get("ok", false)) and int(adjacent["cost"]) > remaining_mp:
			return _short_mp(dest, int(adjacent["cost"]))
		return _move_fail(str(adjacent.get("reason", "unreachable")))
	var unlimited := reachable(from, 9999, occupied)
	if unlimited.has(dest):
		return _short_mp(dest, int(unlimited[dest]["cost"]))
	return _move_fail("unreachable")


func reachable(from: Vector2i, remaining_mp: int, occupied: Callable) -> Dictionary:
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
			var step := step_cost(current, nxt, occupied)
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


func reconstruct_path(best: Dictionary, from: Vector2i, dest: Vector2i) -> Array:
	var path: Array = []
	if not best.has(dest):
		return path
	var cursor: Vector2i = dest
	while cursor != from:
		path.push_front(cursor)
		if not best.has(cursor):
			return []
		cursor = best[cursor]["prev"]
		if path.size() > width * height + 2:
			return []
	return path


func reachable_dests(from: Vector2i, remaining_mp: int, occupied: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach := reachable(from, remaining_mp, occupied)
	for cell in reach.keys():
		if cell == from:
			continue
		out.append(cell)
	return out


func _is_occupied(cell: Vector2i, ignore: Vector2i, occupied: Callable) -> bool:
	if cell == ignore:
		return false
	if occupied.is_valid():
		return bool(occupied.call(cell, ignore))
	return false


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


func _stand_fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"terrain_mp": 0,
		"climb_mp": 0,
		"delta": 0,
	}


func _step_fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"cost": 0,
		"reason": reason,
		"terrain_mp": 0,
		"climb_mp": 0,
		"delta": 0,
	}


## Path exists and the dest is walkable, but remaining MP cannot pay it.
## cost is the cheapest path. terrain_mp is the dest tile's own stamp
## (mud / water are 2) so a tap can name the price instead of a bare reject.
func _short_mp(dest: Vector2i, cost: int) -> Dictionary:
	var terrain := terrain_of(dest)
	return {
		"ok": false,
		"reason": "insufficient_mp",
		"cost": cost,
		"path": [],
		"terrain": str(terrain.get("name", "")),
		"terrain_mp": int(terrain.get("base_mp", 0)),
	}


func _move_fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"cost": 0,
		"path": [],
	}
