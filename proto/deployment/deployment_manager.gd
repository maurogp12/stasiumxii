class_name DeploymentManager
extends RefCounted

## Phase B+ hot-seat sequential deploy brain. Pure data — does not touch CombatSim.
## Proposed (not Locked): each side one fighter; place / reposition / confirm;
## combat stays disabled until both sides confirm, then Turn 1 via start_match.

var phase: int = MatchPhase.Id.DEPLOYMENT
var board_size: int = 8
var zones: Dictionary = {}
var units: Dictionary = {}
var required_count: Dictionary = {}
var selected_unit_id: String = ""
var active_player_id: int = 0
var confirmed: Dictionary = {}
var unwalkable: Dictionary = {}
var start_match_callback: Callable
var last_coach: String = ""
var last_reason: String = ""
var turn_index: int = 0


func _init() -> void:
	setup_hotseat()


func setup_hotseat() -> void:
	phase = MatchPhase.Id.DEPLOYMENT
	board_size = 8
	zones.clear()
	units.clear()
	required_count.clear()
	confirmed.clear()
	unwalkable.clear()
	selected_unit_id = ""
	active_player_id = 0
	turn_index = 0
	last_coach = "Proposed hot-seat deploy. Seat 0 places one fighter, then confirms."
	last_reason = ""
	for zone in DeploymentZone.opposite_2x3(board_size):
		set_zone(zone)
	register_unit({"id": "kestrel", "player_id": 0, "name": "Kestrel"})
	register_unit({"id": "ironjaw", "player_id": 1, "name": "Ironjaw"})
	required_count[0] = 1
	required_count[1] = 1
	confirmed[0] = false
	confirmed[1] = false


func set_zone(zone: DeploymentZone) -> void:
	zones[int(zone.player_id)] = zone
	if not confirmed.has(int(zone.player_id)):
		confirmed[int(zone.player_id)] = false
	if not required_count.has(int(zone.player_id)):
		required_count[int(zone.player_id)] = 1


func register_unit(data: Dictionary) -> Dictionary:
	var unit := {
		"id": str(data.get("id", "")),
		"player_id": int(data.get("player_id", 0)),
		"name": str(data.get("name", data.get("id", "Unit"))),
		"placed": false,
		"cell": Vector2i(-1, -1),
	}
	if str(unit["id"]) == "":
		return _fail("missing_unit_id", "REJECT — unit needs an id.")
	units[str(unit["id"])] = unit
	var pid: int = int(unit["player_id"])
	if not required_count.has(pid):
		required_count[pid] = 1
	if not confirmed.has(pid):
		confirmed[pid] = false
	return _ok({"unit": _public_unit(unit)})


func select_unit(unit) -> Dictionary:
	if phase != MatchPhase.Id.DEPLOYMENT:
		return _fail("combat_started", "REJECT — combat already started. Deploy is locked.")
	var resolved := _resolve_unit(unit)
	if resolved.is_empty():
		return _fail("unknown_unit", "REJECT — unknown unit.")
	var pid: int = int(resolved["player_id"])
	if bool(confirmed.get(pid, false)):
		return _fail("side_locked", "REJECT — that side already confirmed.")
	if pid != active_player_id:
		return _fail("not_your_turn", "REJECT — hot-seat sequential: wait for the active side.")
	selected_unit_id = str(resolved["id"])
	last_coach = "Selected %s. Click a cell in the zone, or Confirm when placed." % resolved["name"]
	return _ok({"unit_id": selected_unit_id, "unit": _public_unit(resolved)})


func can_deploy_unit(unit, tile) -> Dictionary:
	var resolved := _resolve_unit(unit)
	if resolved.is_empty():
		return _gate(false, "unknown_unit")
	if phase != MatchPhase.Id.DEPLOYMENT:
		return _gate(false, "combat_started")
	var pid: int = int(resolved["player_id"])
	if bool(confirmed.get(pid, false)):
		return _gate(false, "side_locked")
	if pid != active_player_id:
		return _gate(false, "not_your_turn")
	var cell := _as_cell(tile)
	if not in_bounds(cell):
		return _gate(false, "out_of_bounds")
	var zone := zone_for(pid)
	if zone == null or not zone.contains(cell):
		return _gate(false, "not_in_zone")
	if not is_walkable(cell):
		return _gate(false, "not_walkable")
	var occupant := _unit_at(cell)
	if not occupant.is_empty() and str(occupant["id"]) != str(resolved["id"]):
		return _gate(false, "occupied")
	return _gate(true, "")


func place(unit, tile) -> Dictionary:
	var resolved := _resolve_unit(unit)
	if resolved.is_empty():
		return _fail("unknown_unit", "REJECT — unknown unit.")
	if bool(resolved.get("placed", false)):
		return _fail("already_placed", "REJECT — already placed; reposition instead.")
	var cell := _as_cell(tile)
	var gate := can_deploy_unit(resolved, cell)
	if not bool(gate["ok"]):
		return _fail(str(gate["reason"]), _reject_text(str(gate["reason"]), resolved, cell))
	resolved["placed"] = true
	resolved["cell"] = cell
	selected_unit_id = str(resolved["id"])
	last_coach = "%s placed at %s. Reposition or Confirm." % [resolved["name"], _cell_text(cell)]
	return _ok({"unit": _public_unit(resolved)})


func reposition(unit, tile) -> Dictionary:
	var resolved := _resolve_unit(unit)
	if resolved.is_empty():
		return _fail("unknown_unit", "REJECT — unknown unit.")
	if not bool(resolved.get("placed", false)):
		return _fail("not_placed", "REJECT — place the unit before repositioning.")
	var cell := _as_cell(tile)
	if cell == resolved["cell"]:
		return _fail("same_tile", "Already on %s." % _cell_text(cell))
	var gate := can_deploy_unit(resolved, cell)
	if not bool(gate["ok"]):
		return _fail(str(gate["reason"]), _reject_text(str(gate["reason"]), resolved, cell))
	resolved["cell"] = cell
	selected_unit_id = str(resolved["id"])
	last_coach = "%s repositioned to %s." % [resolved["name"], _cell_text(cell)]
	return _ok({"unit": _public_unit(resolved)})


func confirm(player_id: int = -1) -> Dictionary:
	if phase != MatchPhase.Id.DEPLOYMENT:
		return _fail("combat_started", "REJECT — combat already started.")
	var pid := active_player_id if player_id < 0 else player_id
	if pid != active_player_id:
		return _fail("not_your_turn", "REJECT — hot-seat sequential: only the active side confirms.")
	if bool(confirmed.get(pid, false)):
		return _fail("already_confirmed", "REJECT — that side is already locked.")
	if placed_count(pid) < required_for(pid):
		return _fail("confirm_gated", "REJECT — place the required fighter before Confirm.")
	confirmed[pid] = true
	selected_unit_id = ""
	if both_ready():
		return start_combat()
	active_player_id = _next_unconfirmed(pid)
	var nxt := _player_name(active_player_id)
	last_coach = "Seat %d locked. %s deploys next." % [pid, nxt]
	return _ok({
		"player_id": pid,
		"locked": true,
		"both_ready": false,
		"active_player_id": active_player_id,
	})


func both_ready() -> bool:
	if phase == MatchPhase.Id.COMBAT:
		return true
	var ids := _player_ids()
	if ids.is_empty():
		return false
	for pid in ids:
		if not bool(confirmed.get(int(pid), false)):
			return false
	return true


func start_combat() -> Dictionary:
	if phase == MatchPhase.Id.COMBAT:
		return _fail("already_in_combat", "REJECT — already handed off to Turn 1.")
	if not both_ready():
		return _fail("combat_disabled", "REJECT — combat stays disabled until both sides confirm.")
	phase = MatchPhase.Id.COMBAT
	turn_index = 1
	active_player_id = 0
	selected_unit_id = ""
	var payload := start_match_payload()
	last_coach = "Both sides confirmed. Turn 1 (start_match stub). Combat lives on main.tscn."
	if start_match_callback.is_valid():
		start_match_callback.call(payload)
	return _ok({
		"phase": phase,
		"turn": turn_index,
		"start_match": payload,
	})


func start_match_payload() -> Dictionary:
	var placements: Array = []
	for unit_id in units.keys():
		placements.append(_public_unit(units[unit_id]))
	return {
		"phase": MatchPhase.Id.COMBAT,
		"turn": 1,
		"active_player_id": 0,
		"placements": placements,
		"label": "Proposed",
	}


func snapshot() -> Dictionary:
	var zone_cells := {}
	for pid in zones.keys():
		var zone: DeploymentZone = zones[pid]
		zone_cells[int(pid)] = zone.cells.duplicate()
	var unit_list: Array = []
	for unit_id in units.keys():
		unit_list.append(_public_unit(units[unit_id]))
	return {
		"label": "Proposed",
		"phase": phase,
		"phase_name": phase_name(),
		"board_size": board_size,
		"active_player_id": active_player_id,
		"selected_unit_id": selected_unit_id,
		"confirmed": confirmed.duplicate(),
		"both_ready": both_ready(),
		"turn_index": turn_index,
		"zones": zone_cells,
		"units": unit_list,
		"coach": last_coach,
		"reason": last_reason,
	}


func phase_name() -> String:
	if phase == MatchPhase.Id.COMBAT:
		return "COMBAT"
	return "DEPLOYMENT"


func zone_for(player_id: int) -> DeploymentZone:
	if zones.has(player_id):
		return zones[player_id]
	return null


func zone_cells(player_id: int) -> Array[Vector2i]:
	var zone := zone_for(player_id)
	if zone == null:
		return [] as Array[Vector2i]
	return zone.cells.duplicate()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size and cell.y < board_size


func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return not unwalkable.has(cell)


func set_walkable(cell: Vector2i, walkable: bool) -> void:
	if walkable:
		unwalkable.erase(cell)
	else:
		unwalkable[cell] = true


func placed_count(player_id: int) -> int:
	var n := 0
	for unit_id in units.keys():
		var unit: Dictionary = units[unit_id]
		if int(unit["player_id"]) == player_id and bool(unit["placed"]):
			n += 1
	return n


func required_for(player_id: int) -> int:
	return int(required_count.get(player_id, 1))


func can_confirm(player_id: int = -1) -> bool:
	var pid := active_player_id if player_id < 0 else player_id
	if phase != MatchPhase.Id.DEPLOYMENT:
		return false
	if pid != active_player_id:
		return false
	if bool(confirmed.get(pid, false)):
		return false
	return placed_count(pid) >= required_for(pid)


func _resolve_unit(unit) -> Dictionary:
	if unit is Dictionary:
		var data: Dictionary = unit
		if data.has("id") and units.has(str(data["id"])):
			return units[str(data["id"])]
		if selected_unit_id != "" and units.has(selected_unit_id):
			if int(data.get("player_id", -1)) == int(units[selected_unit_id]["player_id"]):
				return units[selected_unit_id]
		return {}
	var unit_id := str(unit)
	if units.has(unit_id):
		return units[unit_id]
	return {}


func _unit_at(cell: Vector2i) -> Dictionary:
	for unit_id in units.keys():
		var unit: Dictionary = units[unit_id]
		if bool(unit["placed"]) and unit["cell"] == cell:
			return unit
	return {}


func _player_ids() -> Array[int]:
	var seen := {}
	for pid in zones.keys():
		seen[int(pid)] = true
	for unit_id in units.keys():
		seen[int(units[unit_id]["player_id"])] = true
	var ids: Array[int] = []
	for pid in seen.keys():
		ids.append(int(pid))
	ids.sort()
	return ids


func _next_unconfirmed(after_pid: int) -> int:
	var ids := _player_ids()
	for pid in ids:
		if int(pid) != after_pid and not bool(confirmed.get(int(pid), false)):
			return int(pid)
	return after_pid


func _player_name(player_id: int) -> String:
	for unit_id in units.keys():
		var unit: Dictionary = units[unit_id]
		if int(unit["player_id"]) == player_id:
			return str(unit["name"])
	return "Seat %d" % player_id


func _public_unit(unit: Dictionary) -> Dictionary:
	return {
		"id": str(unit.get("id", "")),
		"player_id": int(unit.get("player_id", 0)),
		"name": str(unit.get("name", "")),
		"placed": bool(unit.get("placed", false)),
		"cell": unit.get("cell", Vector2i(-1, -1)),
	}


func _as_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-99, -99)


func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]


func _reject_text(reason: String, unit: Dictionary, cell: Vector2i) -> String:
	match reason:
		"out_of_bounds":
			return "REJECT — %s is out of bounds." % _cell_text(cell)
		"not_in_zone":
			return "REJECT — %s is not in seat %d's zone." % [_cell_text(cell), int(unit.get("player_id", -1))]
		"occupied":
			return "REJECT — %s is occupied." % _cell_text(cell)
		"not_walkable":
			return "REJECT — %s is not walkable." % _cell_text(cell)
		"side_locked":
			return "REJECT — that side already confirmed."
		"not_your_turn":
			return "REJECT — hot-seat sequential: not that side's deploy."
		"combat_started":
			return "REJECT — combat already started. Deploy is locked."
		_:
			return "REJECT — cannot deploy %s on %s (%s)." % [unit.get("name", "unit"), _cell_text(cell), reason]


func _gate(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason}


func _ok(extra: Dictionary = {}) -> Dictionary:
	last_reason = ""
	var out := {
		"ok": true,
		"reason": "",
		"phase": phase,
		"coach": last_coach,
		"snapshot": snapshot(),
	}
	for key in extra.keys():
		out[key] = extra[key]
	return out


func _fail(reason: String, coach: String) -> Dictionary:
	last_reason = reason
	last_coach = coach
	return {
		"ok": false,
		"reason": reason,
		"phase": phase,
		"coach": coach,
		"snapshot": snapshot(),
	}
