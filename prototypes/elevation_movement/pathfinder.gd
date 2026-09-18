extends RefCounted
class_name MovementPathfinder

## Phase B+ prototype. Proposed — not Locked.
## Isolated from Phase A CombatSim / main.tscn flat Manhattan walk.
##
## Dijkstra on ortho weighted edges. Cheapest MP path, not fewest tiles.

static func cheapest_path(board: ProtoBoard, from: Vector2i, to: Vector2i) -> Dictionary:
	var out := {
		"ok": false,
		"reason": "no_path",
		"cost": 0,
		"path": [],
	}
	if board == null or not board.in_bounds(from) or not board.in_bounds(to):
		out["reason"] = "out_of_bounds"
		return out
	if from == to:
		out["ok"] = true
		out["reason"] = ""
		return out
	var scan: Dictionary = dijkstra_map(board, from)
	var dist: Dictionary = scan["dist"]
	var prev: Dictionary = scan["prev"]
	if not dist.has(to):
		out["reason"] = str(scan.get("blocked_reason", {}).get(to, "no_path"))
		if out["reason"] == "":
			out["reason"] = "no_path"
		return out
	out["ok"] = true
	out["reason"] = ""
	out["cost"] = int(dist[to])
	out["path"] = _reconstruct(prev, from, to)
	return out


## dist: cell -> cheapest MP from origin. prev: cell -> parent cell.
## Origin is included at cost 0. Occupied dests and illegal edges are omitted.
static func dijkstra_map(board: ProtoBoard, origin: Vector2i) -> Dictionary:
	var dist: Dictionary = {}
	var prev: Dictionary = {}
	var blocked_reason: Dictionary = {}
	if board == null or not board.in_bounds(origin):
		return {"dist": dist, "prev": prev, "blocked_reason": blocked_reason}

	dist[origin] = 0
	var open: Array[Vector2i] = [origin]
	while not open.is_empty():
		var best_i := 0
		var best_cost: int = int(dist[open[0]])
		for i in range(1, open.size()):
			var c: int = int(dist[open[i]])
			if c < best_cost:
				best_cost = c
				best_i = i
		var cell: Vector2i = open[best_i]
		open.remove_at(best_i)
		for next in board.ortho_neighbors(cell):
			var step: Dictionary = MovementCost.validate_step(board, cell, next)
			if not bool(step.get("ok", false)):
				if not dist.has(next) and not blocked_reason.has(next):
					blocked_reason[next] = str(step.get("reason", "no_path"))
				continue
			var new_cost: int = best_cost + int(step["cost"])
			if dist.has(next) and new_cost >= int(dist[next]):
				continue
			dist[next] = new_cost
			prev[next] = cell
			blocked_reason.erase(next)
			if not open.has(next):
				open.append(next)
	return {"dist": dist, "prev": prev, "blocked_reason": blocked_reason}


static func _reconstruct(prev: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var rev: Array[Vector2i] = []
	var cursor := to
	while cursor != from:
		rev.append(cursor)
		if not prev.has(cursor):
			return []
		cursor = prev[cursor]
	rev.reverse()
	return rev
