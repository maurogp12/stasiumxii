extends RefCounted
class_name MovementReachability

## Phase B+ prototype. Proposed — not Locked.
## Isolated from Phase A CombatSim / main.tscn flat Manhattan walk.
##
## Reachable tiles from a unit MP pool using Dijkstra weighted costs.

static func tiles_within_mp(board: ProtoBoard, origin: Vector2i, remaining_mp: int) -> Dictionary:
	var out: Dictionary = {} ## Vector2i -> {cost, path}
	if remaining_mp <= 0 or board == null:
		return out
	var scan: Dictionary = MovementPathfinder.dijkstra_map(board, origin)
	var dist: Dictionary = scan["dist"]
	var prev: Dictionary = scan["prev"]
	for cell in dist.keys():
		var dest: Vector2i = cell
		if dest == origin:
			continue
		var cost: int = int(dist[dest])
		if cost > remaining_mp:
			continue
		out[dest] = {
			"cost": cost,
			"path": MovementPathfinder._reconstruct(prev, origin, dest),
		}
	return out


static func cost_to(reach: Dictionary, cell: Vector2i) -> int:
	if not reach.has(cell):
		return -1
	return int(reach[cell]["cost"])
