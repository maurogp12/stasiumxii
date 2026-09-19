class_name DeploymentManager
extends RefCounted

## Hot-seat sequential deploy brain. Pure data — does not touch CombatSim.
## Proposed (not Locked): P1 then P2, one fighter each, confirm-gated start.

signal start_match(snapshot: Dictionary)
signal changed()

const BOARD_SIZE := 8
const PLAYER_P1 := 0
const PLAYER_P2 := 1

var phase: int = MatchPhase.DEPLOYMENT
var board_size: int = BOARD_SIZE
var active_player: int = PLAYER_P1
var selected_unit_id: String = ""
var zones: Dictionary = {}
var units: Dictionary = {}
var confirmed: Dictionary = {}
var extra_occupied: Array[Vector2i] = []
var extra_blocked: Array[Vector2i] = []
## Optional walkable predicate. Elevation proto may pass ProtoMoveSim.is_walkable.
## Deploy does not charge elevation / terrain MP.
var is_walkable_fn: Callable = Callable()
var _start_emitted: bool = false


func _init() -> void:
	reset()


func reset() -> void:
	phase = MatchPhase.DEPLOYMENT
	board_size = BOARD_SIZE
	active_player = PLAYER_P1
	selected_unit_id = ""
	zones.clear()
	units.clear()
	confirmed = {PLAYER_P1: false, PLAYER_P2: false}
	extra_occupied.clear()
	extra_blocked.clear()
	_start_emitted = false
	_apply_default_zones()
	_apply_default_fighters()
	selected_unit_id = _first_unit_for(active_player)
	changed.emit()


func _apply_default_zones() -> void:
	for zone in DeploymentZone.opposite_2x3_on_8x8():
		zones[zone.player_id] = zone


func _apply_default_fighters() -> void:
	add_unit({
		"id": "kestrel",
		"player_id": PLAYER_P1,
		"name": "Kestrel",
		"class_id": "kestrel",
		"facing": "E",
		"required": true,
	})
	add_unit({
		"id": "ironjaw",
		"player_id": PLAYER_P2,
		"name": "Ironjaw",
		"class_id": "ironjaw",
		"facing": "W",
		"required": true,
	})


func add_unit(data: Dictionary) -> Dictionary:
	var unit := {
		"id": str(data.get("id", "")),
		"player_id": int(data.get("player_id", 0)),
		"name": str(data.get("name", "")),
		"class_id": str(data.get("class_id", "")),
		"facing": str(data.get("facing", "E")),
		"required": bool(data.get("required", true)),
		"placed": false,
		"cell": Vector2i(-1, -1),
		"locked": false,
	}
	if unit["id"] == "":
		return _fail("unknown_unit")
	units[unit["id"]] = unit
	if not confirmed.has(unit["player_id"]):
		confirmed[unit["player_id"]] = false
	return {"ok": true, "reason": "", "unit": unit.duplicate(true)}


func set_zone(zone: DeploymentZone) -> void:
	zones[zone.player_id] = zone


func zone_for(player_id: int) -> DeploymentZone:
	if zones.has(player_id):
		return zones[player_id]
	return null


func unit_by_id(unit_id: String) -> Dictionary:
	if units.has(unit_id):
		return units[unit_id]
	return {}


func select_unit(unit_id: String) -> Dictionary:
	var unit := unit_by_id(unit_id)
	if unit.is_empty():
		return _fail("unknown_unit")
	if int(unit["player_id"]) != active_player:
		return _fail("not_your_turn")
	if phase != MatchPhase.DEPLOYMENT:
		return _fail("wrong_phase")
	if bool(confirmed.get(active_player, false)):
		return _fail("side_locked")
	selected_unit_id = unit_id
	changed.emit()
	return {"ok": true, "reason": "", "unit_id": unit_id}


## Gate: phase, zone membership, in-bounds, walkable, not occupied.
## `unit` may be a unit id String or a unit Dictionary.
func can_deploy_unit(unit: Variant, cell: Vector2i) -> Dictionary:
	if phase != MatchPhase.DEPLOYMENT:
		return _fail("wrong_phase")
	var rec := _as_unit(unit)
	if rec.is_empty():
		return _fail("unknown_unit")
	var player_id := int(rec["player_id"])
	if player_id != active_player:
		return _fail("not_your_turn")
	if bool(confirmed.get(player_id, false)) or bool(rec.get("locked", false)):
		return _fail("side_locked")
	if not in_bounds(cell):
		return _fail("out_of_bounds")
	var zone := zone_for(player_id)
	if zone == null or not zone.contains(cell):
		return _fail("outside_zone")
	if not is_walkable(cell):
		return _fail("not_walkable")
	var occupant := occupant_at(cell)
	if occupant != "" and occupant != str(rec["id"]):
		return _fail("occupied")
	return {"ok": true, "reason": ""}


func place_unit(unit: Variant, cell: Vector2i) -> Dictionary:
	var rec := _as_unit(unit)
	var gate := can_deploy_unit(rec, cell)
	if not bool(gate.get("ok", false)):
		return gate
	var unit_id := str(rec["id"])
	var live: Dictionary = units[unit_id]
	var was_placed := bool(live.get("placed", false))
	live["cell"] = cell
	live["placed"] = true
	selected_unit_id = unit_id
	changed.emit()
	return {
		"ok": true,
		"reason": "",
		"unit_id": unit_id,
		"cell": cell,
		"repositioned": was_placed,
	}


func confirm(player_id: int = -1) -> Dictionary:
	if player_id < 0:
		player_id = active_player
	if phase != MatchPhase.DEPLOYMENT:
		return _fail("wrong_phase")
	if player_id != active_player:
		return _fail("not_your_turn")
	if bool(confirmed.get(player_id, false)):
		return _fail("already_confirmed")
	if not required_units_placed(player_id):
		return _fail("units_not_placed")
	confirmed[player_id] = true
	_lock_side(player_id)
	if both_confirmed():
		_begin_turn_1()
	else:
		active_player = _next_unconfirmed(player_id)
		selected_unit_id = _first_unit_for(active_player)
		changed.emit()
	return {"ok": true, "reason": "", "player_id": player_id}


func can_confirm(player_id: int = -1) -> bool:
	if player_id < 0:
		player_id = active_player
	if phase != MatchPhase.DEPLOYMENT:
		return false
	if player_id != active_player:
		return false
	if bool(confirmed.get(player_id, false)):
		return false
	return required_units_placed(player_id)


func required_units_placed(player_id: int) -> bool:
	var any_required := false
	for unit in units.values():
		if int(unit["player_id"]) != player_id:
			continue
		if not bool(unit.get("required", true)):
			continue
		any_required = true
		if not bool(unit.get("placed", false)):
			return false
	return any_required


func both_confirmed() -> bool:
	return bool(confirmed.get(PLAYER_P1, false)) and bool(confirmed.get(PLAYER_P2, false))


func combat_actions_enabled() -> bool:
	return phase == MatchPhase.TURN_1


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size and cell.y < board_size


func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	if extra_blocked.has(cell):
		return false
	if is_walkable_fn.is_valid():
		return bool(is_walkable_fn.call(cell))
	return true


func occupant_at(cell: Vector2i) -> String:
	for unit in units.values():
		if bool(unit.get("placed", false)) and unit["cell"] == cell:
			return str(unit["id"])
	if extra_occupied.has(cell):
		return "_blocked"
	return ""


func is_occupied(cell: Vector2i, ignore_unit_id: String = "") -> bool:
	var occupant := occupant_at(cell)
	if occupant == "":
		return false
	return occupant != ignore_unit_id


func legal_deploy_cells(unit: Variant = null) -> Array[Vector2i]:
	var rec := _as_unit(unit if unit != null else selected_unit_id)
	var out: Array[Vector2i] = []
	if rec.is_empty():
		return out
	var zone := zone_for(int(rec["player_id"]))
	if zone == null:
		return out
	for cell in zone.cells:
		if bool(can_deploy_unit(rec, cell).get("ok", false)):
			out.append(cell)
	return out


func snapshot() -> Dictionary:
	var unit_list: Array = []
	for unit in units.values():
		unit_list.append(unit.duplicate(true))
	return {
		"phase": phase,
		"phase_name": phase_name(),
		"board_size": board_size,
		"active_player": active_player,
		"selected_unit_id": selected_unit_id,
		"units": unit_list,
		"confirmed": confirmed.duplicate(true),
		"both_confirmed": both_confirmed(),
		"turn_index": 1 if phase == MatchPhase.TURN_1 else 0,
		"combat_enabled": combat_actions_enabled(),
		"walk_enabled": combat_actions_enabled(),
		"end_turn_enabled": combat_actions_enabled(),
		"positions_locked": phase == MatchPhase.TURN_1,
		"rules": "proposed_not_locked",
	}


func phase_name() -> String:
	if phase == MatchPhase.TURN_1:
		return "TURN_1"
	return "DEPLOYMENT"


func _begin_turn_1() -> void:
	phase = MatchPhase.TURN_1
	active_player = PLAYER_P1
	selected_unit_id = ""
	for unit in units.values():
		unit["locked"] = true
	if not _start_emitted:
		_start_emitted = true
		start_match.emit(snapshot())
	changed.emit()


func _lock_side(player_id: int) -> void:
	for unit in units.values():
		if int(unit["player_id"]) == player_id:
			unit["locked"] = true


func _next_unconfirmed(after_player: int) -> int:
	var order: Array[int] = [PLAYER_P1, PLAYER_P2]
	for player_id in order:
		if player_id == after_player:
			continue
		if not bool(confirmed.get(player_id, false)):
			return player_id
	return after_player


func _first_unit_for(player_id: int) -> String:
	for unit in units.values():
		if int(unit["player_id"]) == player_id:
			return str(unit["id"])
	return ""


func _as_unit(unit: Variant) -> Dictionary:
	if unit is Dictionary:
		var data: Dictionary = unit
		var unit_id := str(data.get("id", ""))
		if units.has(unit_id):
			return units[unit_id]
		return data
	return unit_by_id(str(unit))


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
