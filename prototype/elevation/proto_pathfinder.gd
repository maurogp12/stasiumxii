extends RefCounted
class_name ProtoPathfinder

## Proposed (not Locked) ortho edge weights + Dijkstra reachability.
## Phase B+ only. CombatSim.submit(move) still expands Locked Manhattan paths.

const ORTHO_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

const REASON_NOT_ORTHO := "not_ortho"


static func is_ortho_neighbor(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	return absi(from_pos.x - to_pos.x) + absi(from_pos.y - to_pos.y) == 1


static func ortho_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in ORTHO_DIRS:
		out.append(pos + dir)
	return out


## Neighbor edge weight for Dijkstra / A*. Ortho-only.
## Returns {ok, weight, total_mp, terrain_mp, elev_mp, reason, ortho}.
static func neighbor_weight(from_tile: ProtoBoardTile, to_tile: ProtoBoardTile) -> Dictionary:
	if from_tile == null or to_tile == null:
		return {
			"ok": false,
			"weight": -1,
			"total_mp": 0,
			"terrain_mp": 0,
			"elev_mp": 0,
			"reason": MovementCost.REASON_MISSING,
			"ortho": false,
		}
	var ortho := is_ortho_neighbor(from_tile.grid_pos, to_tile.grid_pos)
	if not ortho:
		return {
			"ok": false,
			"weight": -1,
			"total_mp": 0,
			"terrain_mp": 0,
			"elev_mp": 0,
			"reason": REASON_NOT_ORTHO,
			"ortho": false,
		}
	var step: Dictionary = MovementCost.calculate(from_tile, to_tile)
	var ok := bool(step["ok"])
	return {
		"ok": ok,
		"weight": int(step["total_mp"]) if ok else -1,
		"total_mp": int(step["total_mp"]),
		"terrain_mp": int(step["terrain_mp"]),
		"elev_mp": int(step["elev_mp"]),
		"reason": str(step["reason"]),
		"ortho": true,
	}


## Dijkstra: every tile whose cheapest ortho path costs <= remaining_mp.
## Origin is included at cost 0. Values are {total_mp, prev}.
static func reachable(tiles: Dictionary, origin: Vector2i, remaining_mp: int) -> Dictionary:
	var best: Dictionary = {}
	if remaining_mp < 0 or not tiles.has(origin):
		return best
	best[origin] = {"total_mp": 0, "prev": origin}

	var settled: Dictionary = {}
	while true:
		var cur_key: Variant = null
		var best_cost := remaining_mp + 1
		for key in best.keys():
			if settled.has(key):
				continue
			var cost := int(best[key]["total_mp"])
			if cost < best_cost:
				best_cost = cost
				cur_key = key
		if cur_key == null:
			break
		settled[cur_key] = true
		var cur: Vector2i = cur_key
		var from_tile: ProtoBoardTile = tiles[cur]
		for npos in ortho_neighbors(cur):
			if not tiles.has(npos):
				continue
			var edge: Dictionary = neighbor_weight(from_tile, tiles[npos])
			if not edge["ok"]:
				continue
			var next_cost := best_cost + int(edge["weight"])
			if next_cost > remaining_mp:
				continue
			if best.has(npos) and int(best[npos]["total_mp"]) <= next_cost:
				continue
			best[npos] = {"total_mp": next_cost, "prev": cur}
	return best


static func reconstruct_path(reach: Dictionary, dest: Vector2i) -> Array:
	if not reach.has(dest):
		return []
	var path: Array = []
	var cur: Vector2i = dest
	var guard := 0
	while guard < 4096:
		guard += 1
		path.push_front(cur)
		var rec: Dictionary = reach[cur]
		var prev_cell: Vector2i = rec["prev"]
		if prev_cell == cur:
			break
		cur = prev_cell
	return path


static func path_cost(reach: Dictionary, dest: Vector2i) -> int:
	if not reach.has(dest):
		return -1
	return int(reach[dest]["total_mp"])
