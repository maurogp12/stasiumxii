extends RefCounted
class_name MovementCost

## Phase B+ prototype. Proposed — not Locked.
## Isolated from Phase A CombatSim / main.tscn flat Manhattan walk.
##
## validate_move checks: board bounds, occupied, walkable, elevation caps, MP.
## Step MP = dest terrain cost + Proposed uphill surcharge.

static func step_mp(from_tile: BoardTileData, to_tile: BoardTileData) -> int:
	if from_tile == null or to_tile == null:
		return 0
	return int(to_tile.base_move_cost) + ElevationRules.uphill_surcharge(from_tile.elevation, to_tile.elevation)


## Single ortho edge. Does not apply an MP budget (Dijkstra accumulates).
static func validate_step(board: ProtoBoard, from: Vector2i, to: Vector2i) -> Dictionary:
	var out := {
		"ok": false,
		"reason": "",
		"cost": 0,
		"from": from,
		"to": to,
	}
	if board == null:
		out["reason"] = "no_board"
		return out
	if not board.in_bounds(from) or not board.in_bounds(to):
		out["reason"] = "out_of_bounds"
		return out
	if to == from:
		out["reason"] = "same_tile"
		return out
	if not board.is_ortho_step(from, to):
		out["reason"] = "not_ortho"
		return out
	if board.is_occupied(to):
		out["reason"] = "occupied"
		return out
	var dest := board.get_tile(to)
	var origin := board.get_tile(from)
	if dest == null or origin == null:
		out["reason"] = "out_of_bounds"
		return out
	if not dest.walkable:
		out["reason"] = "impassable"
		return out
	var elev_reason := ElevationRules.step_reject_reason(origin.elevation, dest.elevation)
	if elev_reason != "":
		out["reason"] = elev_reason
		return out
	out["ok"] = true
	out["cost"] = step_mp(origin, dest)
	return out


## Dest-click: cheapest Dijkstra path must fit remaining_mp.
static func validate_move(board: ProtoBoard, from: Vector2i, to: Vector2i, remaining_mp: int) -> Dictionary:
	var out := {
		"ok": false,
		"reason": "",
		"cost": 0,
		"path": [],
		"from": from,
		"to": to,
	}
	if board == null:
		out["reason"] = "no_board"
		return out
	if not board.in_bounds(from) or not board.in_bounds(to):
		out["reason"] = "out_of_bounds"
		return out
	if to == from:
		out["reason"] = "same_tile"
		return out
	if board.is_occupied(to):
		out["reason"] = "occupied"
		return out
	var dest := board.get_tile(to)
	if dest == null:
		out["reason"] = "out_of_bounds"
		return out
	if not dest.walkable:
		out["reason"] = "impassable"
		return out
	var found: Dictionary = MovementPathfinder.cheapest_path(board, from, to)
	if not bool(found.get("ok", false)):
		out["reason"] = str(found.get("reason", "no_path"))
		return out
	var cost := int(found["cost"])
	out["cost"] = cost
	out["path"] = found["path"]
	if cost > remaining_mp:
		out["reason"] = "insufficient_mp"
		return out
	out["ok"] = true
	return out
