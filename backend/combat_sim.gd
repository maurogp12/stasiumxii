extends Node

## Local Phase A combat brain. Godot nodes must not mutate HP or roll.
## API: reset_match(config), submit(intent), legal_intents(seat), snapshot()

const RULES_VERSION := "phase-a-gdd-0.2"
const BOARD_SIZE := 8
const MAX_AP := 6
const MAX_MP := 3
const START_HP := 80
const CRIT_MULT := 1.0
const MASTERY := 0.0
const RESIST := 0.0
const PASSIVE := 1.0
const BACK_FACING := 1.20
const FRONT_SIDE_FACING := 1.00

const FACING_VEC := {
	"N": Vector2i(0, -1),
	"E": Vector2i(1, 0),
	"S": Vector2i(0, 1),
	"W": Vector2i(-1, 0),
}

## A01, A03–A07 are Open. A02 walk is Locked: dest-click Manhattan, H-first ortho path.
const OPEN_DECISIONS := ["A01", "A03", "A04", "A05", "A06", "A07"]

var _units: Array[Dictionary] = []
var _active_seat: int = 0
var _turn_index: int = 1
var _match_over: bool = false
var _winner_seat: int = -1
var _seed: int = 0
var _rng := RandomNumberGenerator.new()
var _scripted_rolls: Array[int] = []
var _last_events: Array = []
var _last_coach: String = ""
var _intent_log: Array = []


func reset_match(config: Dictionary = {}) -> Dictionary:
	_units.clear()
	_active_seat = 0
	_turn_index = 1
	_match_over = false
	_winner_seat = -1
	_scripted_rolls.clear()
	_last_events.clear()
	_intent_log.clear()
	_last_coach = "Kestrel's turn. 6 AP / 3 MP."

	_seed = int(config.get("seed", Time.get_ticks_usec()))
	_rng.seed = _seed
	if config.has("rolls"):
		for roll in config["rolls"]:
			_scripted_rolls.append(int(roll))

	var kestrel_pos: Vector2i = _as_cell(config.get("kestrel_pos", Vector2i(1, 1)))
	var ironjaw_pos: Vector2i = _as_cell(config.get("ironjaw_pos", Vector2i(6, 6)))
	var kestrel_facing: String = str(config.get("kestrel_facing", "E"))
	var ironjaw_facing: String = str(config.get("ironjaw_facing", "W"))

	_units.append(_make_unit(0, SpellKits.CLASS_KESTREL, "Kestrel", "air", kestrel_pos, kestrel_facing))
	_units.append(_make_unit(1, SpellKits.CLASS_IRONJAW, "Ironjaw", "earth", ironjaw_pos, ironjaw_facing))

	_last_events = [{
		"type": "turn_start",
		"seat": _active_seat,
		"turn": _turn_index,
		"coach": _last_coach,
	}]
	_broadcast()
	return snapshot()


func submit(intent: Dictionary) -> Dictionary:
	_last_events = []
	var normalized := _normalize_intent(intent)
	if _match_over:
		return _reject(normalized, "match_over", "REJECT — match is over.")

	var seat := _active_seat
	if normalized.has("seat") and int(normalized["seat"]) != seat:
		return _reject(normalized, "not_your_turn", "REJECT — only the active seat can act.")

	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not actor["alive"]:
		return _reject(normalized, "dead", "REJECT — dead units cannot act.")

	var kind := str(normalized.get("type", ""))
	match kind:
		"end_turn":
			return _submit_end_turn(normalized, actor)
		"face":
			return _submit_face(normalized, actor)
		"move":
			return _submit_move(normalized, actor)
		"cast":
			return _submit_cast(normalized, actor)
		_:
			return _reject(normalized, "unknown_intent", "REJECT — unknown intent.")


func legal_intents(seat: int) -> Array:
	var out: Array = []
	if _match_over or seat != _active_seat:
		return out
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not actor["alive"]:
		return out

	for dir in FACING_VEC.keys():
		if str(dir) == str(actor["facing"]):
			continue
		out.append({"type": "face", "dir": dir, "seat": seat})

	var from: Vector2i = actor["pos"]
	var mp: int = int(actor["mp"])
	var ap: int = int(actor["ap"])
	if mp > 0:
		for y in range(BOARD_SIZE):
			for x in range(BOARD_SIZE):
				var cell := Vector2i(x, y)
				if _validate_walk(actor, cell) == "":
					out.append({"type": "move", "to": cell, "seat": seat})

	for spell_id in actor["spells"]:
		if spell_id == SpellKits.ADVANCE and str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
			continue
		var def: Dictionary = SpellKits.spell(spell_id)
		if def.is_empty():
			continue
		if ap < int(def["ap"]) or mp < int(def["mp"]):
			continue
		if def["target"] == "empty_tile":
			for y in range(BOARD_SIZE):
				for x in range(BOARD_SIZE):
					var dest := Vector2i(x, y)
					var range_dist := chebyshev(from, dest)
					if range_dist >= int(def["min_range"]) and range_dist <= int(def["max_range"]) and _is_empty(dest):
						out.append({
							"type": "cast",
							"spell": spell_id,
							"to": dest,
							"seat": seat,
						})
		else:
			var enemy := _enemy_of(seat)
			if enemy.is_empty() or not enemy["alive"]:
				continue
			var range_dist := chebyshev(from, enemy["pos"])
			if range_dist >= int(def["min_range"]) and range_dist <= int(def["max_range"]):
				out.append({
					"type": "cast",
					"spell": spell_id,
					"to": enemy["pos"],
					"target_seat": enemy["seat"],
					"seat": seat,
				})

	out.append({"type": "end_turn", "seat": seat})
	return out


func snapshot() -> Dictionary:
	var units: Array = []
	for unit in _units:
		units.append(unit.duplicate(true))
	return {
		"rules_version": RULES_VERSION,
		"board_size": BOARD_SIZE,
		"active_seat": _active_seat,
		"turn_index": _turn_index,
		"match_over": _match_over,
		"winner_seat": _winner_seat,
		"seed": _seed,
		"wind": "calm",
		"crit_roll": false,
		"crit_mult": CRIT_MULT,
		"mastery": MASTERY,
		"momentum": false,
		"residue": false,
		"blends": false,
		"gust": false,
		"longshot": false,
		"units": units,
		"coach": _last_coach,
		"last_events": _last_events.duplicate(true),
		"open_decisions": OPEN_DECISIONS.duplicate(),
		"walk": "manhattan",
		"walk_tie_break": "horizontal_first",
		"spell_range": "chebyshev",
		"open_notes": {
			"A01": "Provisional Open: Marks live on the target; Impact lives on the caster. Caps 5 / 4.",
			"A03": "Omitted: Gust/wind heading. WindMod omitted (not invented as 1.0).",
			"A04": "Crit *roll* OFF. CritMult held at 1.0. No elemental riders.",
			"A05": "Provisional Open: Resist 0, damage rounded to nearest int. WindMod omitted from the formula.",
			"A06": "Provisional Open: Advance dashes to any empty Chebyshev 1–2 tile. +1 Impact if Chebyshev 1 to an enemy after landing. Facing unchanged.",
			"A07": "Provisional Open: back = 90° rear cone (facing-axis dominates and is opposite). Front/side ×1.00, back ×1.20.",
		},
	}


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Canonical walk path: dest-click only. Horizontal (E/W) first, then vertical (N/S).
## Client intent.path is never consulted.
static func expand_ortho_path(from: Vector2i, to: Vector2i) -> Array:
	var path: Array = []
	var cursor := from
	var step_x := 1 if to.x > from.x else -1
	while cursor.x != to.x:
		cursor = Vector2i(cursor.x + step_x, cursor.y)
		path.append(cursor)
	var step_y := 1 if to.y > from.y else -1
	while cursor.y != to.y:
		cursor = Vector2i(cursor.x, cursor.y + step_y)
		path.append(cursor)
	return path


static func hit_chance(distance: int) -> int:
	if distance <= 1:
		return 90
	if distance <= 3:
		return 80
	if distance <= 5:
		return 75
	return 70


func _make_unit(seat: int, class_id: String, unit_name: String, element: String, pos: Vector2i, facing: String) -> Dictionary:
	return {
		"seat": seat,
		"id": class_id,
		"name": unit_name,
		"class_id": class_id,
		"element": element,
		"pos": pos,
		"facing": facing,
		"hp": START_HP,
		"max_hp": START_HP,
		"ap": MAX_AP,
		"mp": MAX_MP,
		"max_ap": MAX_AP,
		"max_mp": MAX_MP,
		"marks": 0,
		"impact": 0,
		"marks_cap": SpellKits.MARKS_CAP,
		"impact_cap": SpellKits.IMPACT_CAP,
		"alive": true,
		"spells": SpellKits.class_spells(class_id).duplicate(),
	}


func _normalize_intent(intent: Dictionary) -> Dictionary:
	var out := intent.duplicate(true)
	out["type"] = str(out.get("type", "")).to_lower()
	if out.has("spell"):
		out["spell"] = str(out["spell"]).to_lower()
	if out.has("dir"):
		out["dir"] = str(out["dir"]).to_upper()
	if out.has("to"):
		out["to"] = _as_cell(out["to"])
	return out


func _submit_end_turn(intent: Dictionary, actor: Dictionary) -> Dictionary:
	_intent_log.append(intent)
	var next_seat := 1 if _active_seat == 0 else 0
	var next_unit := _unit_by_seat(next_seat)
	if next_unit.is_empty() or not next_unit["alive"]:
		_finish_match(_active_seat)
		return _accept()

	_active_seat = next_seat
	_turn_index += 1
	next_unit["ap"] = MAX_AP
	next_unit["mp"] = MAX_MP
	_last_coach = "%s's turn. AP/MP refilled to 6/3." % next_unit["name"]
	_last_events.append({
		"type": "end_turn",
		"seat": actor["seat"],
		"next_seat": _active_seat,
		"coach": _last_coach,
	})
	_last_events.append({
		"type": "turn_start",
		"seat": _active_seat,
		"turn": _turn_index,
		"coach": _last_coach,
	})
	return _accept()


func _submit_face(intent: Dictionary, actor: Dictionary) -> Dictionary:
	var dir := str(intent.get("dir", ""))
	if not FACING_VEC.has(dir):
		return _reject(intent, "invalid_facing", "REJECT — facing must be N, E, S or W.")
	var previous: String = actor["facing"]
	actor["facing"] = dir
	_intent_log.append(intent)
	_last_coach = "%s faces %s." % [actor["name"], dir]
	_last_events.append({
		"type": "face",
		"seat": actor["seat"],
		"from": previous,
		"dir": dir,
		"ap_spent": 0,
		"coach": _last_coach,
	})
	return _accept()


func _submit_move(intent: Dictionary, actor: Dictionary) -> Dictionary:
	# Dest-click only. CombatSim expands the ortho path; ignore client intent.path.
	intent.erase("path")
	if not intent.has("to"):
		return _reject(intent, "missing_destination", "REJECT — move needs a destination.")
	var dest: Vector2i = intent["to"]
	var reason := _validate_walk(actor, dest)
	if reason != "":
		return _reject(intent, reason, "REJECT — illegal move (%s)." % reason)
	var from: Vector2i = actor["pos"]
	var path: Array = expand_ortho_path(from, dest)
	var dist := manhattan(from, dest)
	actor["pos"] = dest
	actor["mp"] = int(actor["mp"]) - dist
	_intent_log.append(intent)
	_last_coach = "%s walks to %s (−%d MP)." % [actor["name"], _cell_text(dest), dist]
	_last_events.append({
		"type": "move",
		"seat": actor["seat"],
		"from": from,
		"to": dest,
		"path": path.duplicate(),
		"mp_spent": dist,
		"coach": _last_coach,
	})
	return _accept()


func _submit_cast(intent: Dictionary, actor: Dictionary) -> Dictionary:
	var spell_id := str(intent.get("spell", ""))
	var def: Dictionary = SpellKits.spell(spell_id)
	if def.is_empty():
		return _reject(intent, "unknown_spell", "REJECT — unknown spell.")
	if spell_id == SpellKits.ADVANCE and str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
		return _reject(intent, "spell_not_in_kit", "REJECT — Advance is Ironjaw-only (refund).")
	if not SpellKits.has_spell(str(actor["class_id"]), spell_id):
		return _reject(intent, "spell_not_in_kit", "REJECT — %s is not in %s's kit (refund)." % [def["name"], actor["name"]])
	if not intent.has("to"):
		return _reject(intent, "missing_target", "REJECT — %s needs a target (refund)." % def["name"])

	var dest: Vector2i = intent["to"]
	if not _in_bounds(dest):
		return _reject(intent, "out_of_bounds", "REJECT — %s target is off the board (refund)." % def["name"])

	var dist := chebyshev(actor["pos"], dest)
	if dist < int(def["min_range"]) or dist > int(def["max_range"]):
		return _reject(intent, "out_of_range", "REJECT — %s range %d–%d, target at %d (refund)." % [def["name"], def["min_range"], def["max_range"], dist])

	var ap_cost := int(def["ap"])
	var mp_cost := int(def["mp"])
	if int(actor["ap"]) < ap_cost:
		return _reject(intent, "insufficient_ap", "REJECT — %s costs %d AP (refund)." % [def["name"], ap_cost])
	if int(actor["mp"]) < mp_cost:
		return _reject(intent, "insufficient_mp", "REJECT — %s costs %d MP (refund)." % [def["name"], mp_cost])

	if def["target"] == "empty_tile":
		if not _is_empty(dest):
			return _reject(intent, "destination_occupied", "REJECT — Advance needs an empty tile (refund).")
		return _resolve_advance(intent, actor, def, dest, ap_cost, mp_cost)

	var target := _living_unit_at(dest)
	if target.is_empty() or int(target["seat"]) == int(actor["seat"]):
		return _reject(intent, "no_target", "REJECT — %s needs an enemy (refund)." % def["name"])
	return _resolve_rolling_cast(intent, actor, target, def, dest, dist, ap_cost, mp_cost)


func _resolve_advance(intent: Dictionary, actor: Dictionary, def: Dictionary, dest: Vector2i, ap_cost: int, mp_cost: int) -> Dictionary:
	if str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
		return _reject(intent, "spell_not_in_kit", "REJECT — Advance is Ironjaw-only (refund).")
	var from: Vector2i = actor["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	actor["pos"] = dest
	var enemy: Dictionary = _enemy_of(int(actor["seat"]))
	var adjacent: bool = false
	if not enemy.is_empty() and bool(enemy["alive"]):
		adjacent = chebyshev(dest, enemy["pos"]) == 1
	var impact_gained := 0
	if adjacent:
		impact_gained = _gain_impact(actor, 1)
	_intent_log.append(intent)
	if adjacent and impact_gained > 0:
		_last_coach = "%s Advance to %s. +1 Impact (adjacent)." % [actor["name"], _cell_text(dest)]
	elif adjacent:
		_last_coach = "%s Advance to %s. Adjacent, Impact already capped." % [actor["name"], _cell_text(dest)]
	else:
		_last_coach = "%s Advance to %s. No Impact (not adjacent)." % [actor["name"], _cell_text(dest)]
	_last_events.append({
		"type": "advance",
		"seat": actor["seat"],
		"from": from,
		"to": dest,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"rolled": false,
		"adjacent": adjacent,
		"impact_gained": impact_gained,
		"coach": _last_coach,
	})
	return _accept()


func _resolve_rolling_cast(intent: Dictionary, actor: Dictionary, target: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	# Spend before the d100. Miss keeps AP/MP; engine cost would refund here (none in A).
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var chance: int = hit_chance(dist)
	var roll: int = _roll_d100()
	var connected: bool = roll <= chance
	var facing_mult: float = _facing_multiplier(actor["pos"], target["pos"], str(target["facing"]))
	var is_back: bool = facing_mult > FRONT_SIDE_FACING + 0.001
	_intent_log.append(intent)

	if not connected:
		_last_coach = "MISS — %d AP gone (%d vs %d%%, range %d)." % [ap_cost, roll, chance, dist]
		_last_events.append({
			"type": "miss",
			"seat": actor["seat"],
			"spell": def["id"],
			"target_seat": target["seat"],
			"to": dest,
			"range": dist,
			"hit_chance": chance,
			"roll": roll,
			"ap_spent": ap_cost,
			"mp_spent": mp_cost,
			"engine_refunded": true,
			"engine_gained": 0,
			"damage": 0,
			"crit_mult": CRIT_MULT,
			"coach": _last_coach,
		})
		return _accept()

	var raw: float = float(def["base_damage"]) * CRIT_MULT * PASSIVE * (1.0 + MASTERY / 100.0) * (1.0 - RESIST / 100.0) * facing_mult
	var damage := roundi(raw)
	target["hp"] = int(target["hp"]) - damage
	if int(target["hp"]) < 0:
		target["hp"] = 0
	var engine_gained := 0
	var engine_name := ""
	match str(def["engine_on_connect"]):
		"impact":
			engine_gained = _gain_impact(actor, 1)
			engine_name = "Impact"
		"mark":
			engine_gained = _gain_marks(target, 1)
			engine_name = "Mark"

	var facing_note := "BACK ×1.20" if is_back else "front/side ×1.00"
	var engine_note := ""
	if engine_gained > 0:
		engine_note = " +1 %s." % engine_name
	_last_coach = "HIT %d %s — %s vs %s (%d vs %d%%) %s.%s" % [damage, str(def["element"]).capitalize(), def["name"], target["name"], roll, chance, facing_note, engine_note]
	_last_events.append({
		"type": "hit",
		"seat": actor["seat"],
		"spell": def["id"],
		"target_seat": target["seat"],
		"to": dest,
		"range": dist,
		"hit_chance": chance,
		"roll": roll,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"base_damage": def["base_damage"],
		"facing_mult": facing_mult,
		"back": is_back,
		"crit_mult": CRIT_MULT,
		"damage": damage,
		"element": def["element"],
		"engine": engine_name.to_lower(),
		"engine_gained": engine_gained,
		"coach": _last_coach,
	})
	_check_death(target)
	return _accept()


func _check_death(target: Dictionary) -> void:
	if int(target["hp"]) > 0:
		return
	target["alive"] = false
	_last_events.append({
		"type": "dead",
		"seat": target["seat"],
		"name": target["name"],
		"coach": "%s falls." % target["name"],
	})
	_finish_match(_enemy_of(int(target["seat"]))["seat"])


func _finish_match(winner: int) -> void:
	_match_over = true
	_winner_seat = winner
	var winner_unit := _unit_by_seat(winner)
	var winner_name := str(winner_unit.get("name", "Seat %d" % winner))
	_last_coach = "Match over. %s wins." % winner_name
	_last_events.append({
		"type": "match_over",
		"winner_seat": winner,
		"coach": _last_coach,
	})


func _validate_walk(actor: Dictionary, dest: Vector2i) -> String:
	if not _in_bounds(dest):
		return "out_of_bounds"
	if dest == actor["pos"]:
		return "same_tile"
	if not _is_empty(dest):
		return "occupied"
	var dist := manhattan(actor["pos"], dest)
	if dist < 1:
		return "same_tile"
	if dist > int(actor["mp"]):
		return "insufficient_mp"
	var path: Array = expand_ortho_path(actor["pos"], dest)
	for cell in path:
		if not _is_empty(cell):
			return "path_blocked"
	return ""


func _facing_multiplier(attacker_pos: Vector2i, target_pos: Vector2i, target_facing: String) -> float:
	# A07 provisional Open: 90° rear cone, not locked exact-rear-tile.
	if not FACING_VEC.has(target_facing):
		return FRONT_SIDE_FACING
	var facing: Vector2i = FACING_VEC[target_facing]
	var to_attacker: Vector2i = attacker_pos - target_pos
	if to_attacker == Vector2i.ZERO:
		return FRONT_SIDE_FACING
	var along: int = to_attacker.x * facing.x + to_attacker.y * facing.y
	var perp: int = absi(to_attacker.x * facing.y - to_attacker.y * facing.x)
	if along < 0 and absi(along) >= perp:
		return BACK_FACING
	return FRONT_SIDE_FACING


func _gain_impact(unit: Dictionary, amount: int) -> int:
	if str(unit.get("class_id", "")) != SpellKits.CLASS_IRONJAW:
		return 0
	var before: int = int(unit["impact"])
	unit["impact"] = mini(before + amount, int(unit["impact_cap"]))
	return int(unit["impact"]) - before


func _gain_marks(unit: Dictionary, amount: int) -> int:
	var before: int = int(unit["marks"])
	unit["marks"] = mini(before + amount, int(unit["marks_cap"]))
	return int(unit["marks"]) - before


func _roll_d100() -> int:
	if not _scripted_rolls.is_empty():
		return int(_scripted_rolls.pop_front())
	return _rng.randi_range(1, 100)


func _accept() -> Dictionary:
	_broadcast()
	return {
		"ok": true,
		"illegal": false,
		"reason": "",
		"events": _last_events.duplicate(true),
		"snapshot": snapshot(),
	}


func _reject(intent: Dictionary, reason: String, coach: String) -> Dictionary:
	_last_coach = coach
	_last_events = [{
		"type": "reject",
		"reason": reason,
		"intent": intent,
		"coach": coach,
	}]
	_broadcast()
	return {
		"ok": false,
		"illegal": true,
		"reason": reason,
		"events": _last_events.duplicate(true),
		"snapshot": snapshot(),
	}


func _broadcast() -> void:
	if not is_inside_tree():
		return
	var bus := get_tree().root.get_node_or_null("EventBus")
	if bus != null and bus.has_method("emit_combat"):
		bus.call("emit_combat", _last_events.duplicate(true), snapshot())


func _unit_by_seat(seat: int) -> Dictionary:
	for unit in _units:
		if int(unit["seat"]) == seat:
			return unit
	return {}


func _enemy_of(seat: int) -> Dictionary:
	return _unit_by_seat(1 if seat == 0 else 0)


func _living_unit_at(cell: Vector2i) -> Dictionary:
	for unit in _units:
		if unit["pos"] == cell and unit["alive"]:
			return unit
	return {}


func _is_empty(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	for unit in _units:
		if unit["pos"] == cell:
			return false
	return true


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD_SIZE and cell.y < BOARD_SIZE


func _as_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]
