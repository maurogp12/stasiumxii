extends Node

## Local Phase A combat brain. Godot nodes must not mutate HP or roll.
## API: reset_match(config), submit(intent), legal_intents(seat), snapshot(),
## preview_cast(spell_id, from, to, target_seat=-1) — also accepts an intent Dictionary.

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

## A03–A07 are Open (A05 Resist/rounding/WindMod still Open). A01 Marks-on-target
## is Locked. A02 walk is Locked (Manhattan dest-click, H-first ortho path,
## facing follows each hop). Advance range is Locked Manhattan 1–2 (diamond).
## MP is Locked Manhattan dest-click. Locked Stun (A′): blocks move + cast + face;
## auto end_turn on that seat's turn start (player never presses End Turn).
## Locked Push (1): occupied/OOB = no-move + push_blocked.
const OPEN_DECISIONS := ["A03", "A04", "A05", "A06", "A07"]

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
## Test/setup occupancy only. Locked Push (1): dest occupied/OOB is no-move + push_blocked.
var _blocked_cells: Array[Vector2i] = []


func reset_match(config: Dictionary = {}) -> Dictionary:
	_units.clear()
	_blocked_cells.clear()
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
	_apply_setup_overrides(config)

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
	# Locked Stun (A′): reject casts / moves / face while stunned.
	# end_turn is the auto path (player never presses it).
	if kind != "end_turn" and _is_stunned(actor):
		return _reject(normalized, "stunned_cannot_act", "REJECT — stunned (Locked A′ — move/cast/face blocked).")
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
	# Locked Stun (A′): no move/cast/face. Auto end_turn only — player never presses.
	if _is_stunned(actor):
		out.append({"type": "end_turn", "seat": seat, "auto": true})
		return out

	for dir in FACING_VEC.keys():
		if str(dir) == str(actor["facing"]):
			continue
		out.append({"type": "face", "dir": dir, "seat": seat})

	var from: Vector2i = actor["pos"]
	var mp: int = int(actor["mp"])
	var ap: int = int(actor["ap"])
	# Walk dests whenever mp>0, regardless of remaining AP. Advance is 3 AP / 0 MP, so
	# leftover MP after teleport still offers moves (including at 0 AP). Walk facing
	# is applied on submit (each hop), not here.
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
		if ap < int(def["ap"]):
			continue
		if def["target"] == "empty_tile":
			for y in range(BOARD_SIZE):
				for x in range(BOARD_SIZE):
					var dest := Vector2i(x, y)
					if _validate_advance(actor, dest) == "":
						out.append({
							"type": "cast",
							"spell": spell_id,
							"to": dest,
							"seat": seat,
						})
		else:
			if mp < int(def["mp"]):
				continue
			var enemy := _enemy_of(seat)
			if enemy.is_empty() or not enemy["alive"]:
				continue
			if _cast_gate_reason(actor, enemy, def) != "":
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


## Presentation helper: in-bounds tiles in the spell's range ring (caster tile excluded).
## Mark Shot uses this for Chebyshev 2–5 chrome. Does not imply a legal cast dest.
func range_highlight_cells(seat: int, spell_id: String) -> Array:
	var out: Array = []
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not actor["alive"]:
		return out
	if spell_id == SpellKits.ADVANCE and str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
		return out
	if not SpellKits.has_spell(str(actor["class_id"]), spell_id):
		return out
	var def: Dictionary = SpellKits.spell(spell_id)
	if def.is_empty():
		return out
	var from: Vector2i = actor["pos"]
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var cell := Vector2i(x, y)
			if cell == from:
				continue
			var dist := _range_distance(def, from, cell)
			if dist >= int(def["min_range"]) and dist <= int(def["max_range"]):
				out.append(cell)
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
		"walk_facing": "last_hop",
		"spell_range": "chebyshev",
		"advance_mp": "none",
		"advance_ap": 3,
		"advance_range": "manhattan",
		"advance_path": "teleport",
		"marks_owner": "target",
		"stun": "locked_a_prime",
		"stun_blocks": "move_cast_face",
		"stun_auto_end_turn": true,
		"push": "locked_1",
		"push_occupied_oob": "no_move",
		"open_notes": {
			"A03": "Omitted: Gust/wind heading. WindMod omitted (not invented as 1.0).",
			"A04": "Crit *roll* OFF. CritMult held at 1.0. No elemental riders.",
			"A05": "Open: Resist 0, damage rounded to nearest int. WindMod omitted from the formula. Locked Stun (A′): stun_remaining on the unit; reject move/cast/face with stunned_cannot_act; auto end_turn on that seat's turn start (player never presses End Turn). Decrement at start of that unit's turn after setting stunned-this-turn so Stun 1 covers the incoming (skipped) turn. Locked Push (1): dest occupied/OOB does not move the target; still deal damage/Impact; emit push_blocked.",
			"A06": "Advance (Locked teleport): dest-click snap, 3 AP / 0 MP, client path ignored. Range gate Manhattan 1–2 (diamond). No MP spend; legal at 0 MP; submit does not zero leftover MP. leftover MP still walks (legal_intents is mp>0, not AP). No hop path. +1 Impact if Chebyshev 1 to an enemy after landing. Facing unchanged — Advance does not auto-face.",
			"A07": "Provisional Open: back = 90° rear cone (facing-axis dominates and is opposite). Front/side ×1.00, back ×1.20.",
		},
	}


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Canonical walk path: dest-click only. Horizontal (E/W) first, then vertical (N/S).
## Client intent.path is never consulted. Locked: facing follows each ortho hop;
## final facing is the last hop direction.
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


## Facing for one orthogonal hop. Horizontal-first if both axes are nonzero.
static func hop_facing(from: Vector2i, to: Vector2i) -> String:
	var delta: Vector2i = to - from
	if delta == Vector2i.ZERO:
		return ""
	if delta.x != 0:
		return "E" if delta.x > 0 else "W"
	return "S" if delta.y > 0 else "N"


## Last-hop facing along the H-first ortho expansion. Walks only.
## Advance teleport does not auto-face.
static func last_hop_facing(from: Vector2i, to: Vector2i, fallback: String = "") -> String:
	var path: Array = expand_ortho_path(from, to)
	if path.is_empty():
		return fallback
	var cursor := from
	var facing := fallback
	for step in path:
		var cell: Vector2i = step
		var dir := hop_facing(cursor, cell)
		if dir != "":
			facing = dir
		cursor = cell
	return facing


static func hit_chance(distance: int) -> int:
	if distance <= 1:
		return 90
	if distance <= 3:
		return 80
	if distance <= 5:
		return 75
	return 70


## Presentation helper only. Locked Chebyshev bands; no +5. Advance / walks: show=false.
func aim_hit_preview(seat: int, spell_id: String, dest: Variant = null) -> Dictionary:
	var out := {
		"show": false,
		"hit_chance": 0,
		"range": 0,
		"rolls": false,
		"spell": spell_id,
	}
	var def: Dictionary = SpellKits.spell(spell_id)
	# Client chrome allowlist only. Kit resolve stays in CombatSim / #7.
	# Locked rolling aim: Mark Shot / Strike / Detonate / Shoulder / Crush.
	# No +5. No Advance. No invented stun/push.
	if def.is_empty() or not bool(def.get("rolls", false)):
		return out
	if not [
		SpellKits.MARK_SHOT,
		SpellKits.STRIKE,
		SpellKits.DETONATE,
		SpellKits.SHOULDER,
		SpellKits.CRUSH,
	].has(spell_id):
		return out
	out["rolls"] = true
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not actor["alive"]:
		return out
	var cell: Vector2i
	if dest == null:
		var enemy := _enemy_of(seat)
		if enemy.is_empty() or not enemy["alive"]:
			return out
		cell = enemy["pos"]
	else:
		cell = _as_cell(dest)
	var dist := chebyshev(actor["pos"], cell)
	out["range"] = dist
	out["hit_chance"] = hit_chance(dist)
	if dist >= int(def["min_range"]) and dist <= int(def["max_range"]):
		out["show"] = true
	return out


## Read-only cast preview. Does not mutate match state, RNG, or the intent log.
## Call as preview_cast(spell_id, from, to, target_seat=-1) or with an intent Dictionary
## (keys: spell / spell_id, from, to, target_seat, seat). Crit roll stays OFF.
func preview_cast(spell_or_intent: Variant, from: Variant = null, to: Variant = null, target_seat: int = -1) -> Dictionary:
	var spell_id := ""
	var seat_hint := -1
	if spell_or_intent is Dictionary:
		var intent: Dictionary = spell_or_intent
		spell_id = str(intent.get("spell", intent.get("spell_id", "")))
		if intent.has("from"):
			from = intent["from"]
		if intent.has("to"):
			to = intent["to"]
		if intent.has("target_seat"):
			target_seat = int(intent["target_seat"])
		if intent.has("seat"):
			seat_hint = int(intent["seat"])
	else:
		spell_id = str(spell_or_intent)

	spell_id = spell_id.to_lower()
	var from_cell := _as_cell(from) if from != null else Vector2i.ZERO
	var to_cell := _as_cell(to) if to != null else Vector2i.ZERO
	var actor := _preview_actor(from_cell, from != null, seat_hint)
	if from == null and not actor.is_empty():
		from_cell = actor["pos"]

	var def: Dictionary = SpellKits.spell(spell_id)
	var lines: Dictionary = _preview_kit_lines(spell_id)
	var out := {
		"spell_id": spell_id,
		"name": str(def.get("name", "")),
		"ap": int(def.get("ap", 0)),
		"mp": int(def.get("mp", 0)),
		"range_mode": str(def.get("range_mode", "")),
		"min_range": int(def.get("min_range", 0)),
		"max_range": int(def.get("max_range", 0)),
		"in_range": false,
		"hit_chance": null,
		"on_connect_text": str(lines.get("on_connect", "")),
		"on_miss_text": str(lines.get("on_miss", "")),
		"sample_damage": null,
		"notes": [],
		"rolling": bool(def.get("rolls", false)),
		"legal": false,
		"reason": "",
	}
	if def.is_empty():
		out["reason"] = "unknown_spell"
		return out

	var range_dist := _range_distance(def, from_cell, to_cell)
	out["in_range"] = range_dist >= int(def["min_range"]) and range_dist <= int(def["max_range"])
	if bool(def.get("rolls", false)):
		out["hit_chance"] = hit_chance(chebyshev(from_cell, to_cell))

	var target := _preview_target(to_cell, target_seat, spell_id)
	var notes: Array = []
	if spell_id == SpellKits.ADVANCE:
		notes.append("Dest-click teleport. Range Manhattan 1–2. 3 AP / 0 MP. Facing unchanged.")
		out["sample_damage"] = null
		out["hit_chance"] = null
	else:
		var facing_mult := FRONT_SIDE_FACING
		if not target.is_empty() and bool(target.get("alive", true)):
			facing_mult = _facing_multiplier(from_cell, target["pos"], str(target.get("facing", "")))
		var base := _connect_base_damage(def, target)
		# Locked Phase A sample: CritMult=1.0, Passive=1, Mastery=0. WindMod omitted.
		# Resist 0 is not invented as Locked — provisional Open A05, labeled below.
		out["sample_damage"] = _phase_a_damage(base, facing_mult)
		notes.append("Resist 0 (provisional Open A05)")

	if spell_id == SpellKits.DETONATE:
		var marks_on_target := int(target.get("marks", 0))
		out["marks_on_target"] = marks_on_target
		out["formula"] = "6+6*M"
		if marks_on_target < 1:
			# needs_marks: do not lead with sample_damage=6 (6+6×0).
			# notes / on_connect still explain 6+6×M for when Marks exist.
			out["sample_damage"] = null
			notes.append("Needs 1+ Marks. 6+6×M Air when Marks exist.")
	elif spell_id == SpellKits.CRUSH:
		var impact_before := int(actor.get("impact", 0))
		var spend := int(def.get("spend_impact", 2))
		out["impact_before"] = impact_before
		out["would_stun"] = impact_before == int(def.get("stun_if_impact_before", 4)) and impact_before >= spend
	elif spell_id == SpellKits.SHOULDER:
		notes.append("Push 1 cell along the line. Occupied/OOB dest is Locked Push (1): no-move + push_blocked.")

	out["notes"] = notes
	out["reason"] = _preview_reason(def, actor, target, from_cell, to_cell, out["in_range"])
	out["legal"] = str(out["reason"]) == ""
	return out


func _preview_actor(from_cell: Vector2i, has_from: bool, seat_hint: int) -> Dictionary:
	if seat_hint >= 0:
		var by_seat := _unit_by_seat(seat_hint)
		if not by_seat.is_empty():
			return by_seat
	if has_from:
		var at_from := _living_unit_at(from_cell)
		if not at_from.is_empty():
			return at_from
	return _unit_by_seat(_active_seat)


func _preview_target(to_cell: Vector2i, target_seat: int, spell_id: String) -> Dictionary:
	if target_seat >= 0:
		return _unit_by_seat(target_seat)
	if spell_id == SpellKits.ADVANCE:
		return {}
	return _living_unit_at(to_cell)


func _preview_reason(def: Dictionary, actor: Dictionary, target: Dictionary, from_cell: Vector2i, to_cell: Vector2i, in_range: bool) -> String:
	var spell_id := str(def.get("id", ""))
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return "no_actor"
	if str(actor.get("class_id", "")) != "" and not SpellKits.has_spell(str(actor["class_id"]), spell_id):
		return "spell_not_in_kit"
	if _is_stunned(actor):
		return "stunned_cannot_act"
	if not _in_bounds(to_cell):
		return "out_of_bounds"
	if not in_range:
		return "out_of_range"
	if int(actor.get("ap", 0)) < int(def.get("ap", 0)):
		return "insufficient_ap"
	if int(actor.get("mp", 0)) < int(def.get("mp", 0)):
		return "insufficient_mp"
	if spell_id == SpellKits.ADVANCE:
		if to_cell == from_cell or to_cell == actor["pos"]:
			return "same_tile"
		if not _is_empty(to_cell):
			return "destination_occupied"
		return ""
	if target.is_empty() or not bool(target.get("alive", false)) or int(target.get("seat", -1)) == int(actor.get("seat", -2)):
		return "no_target"
	if spell_id == SpellKits.DETONATE and int(target.get("marks", 0)) < int(def.get("requires_marks_on_target", 1)):
		return "needs_marks"
	if spell_id == SpellKits.CRUSH and int(actor.get("impact", 0)) < int(def.get("requires_impact", 2)):
		return "insufficient_impact"
	return ""


func _preview_kit_lines(spell_id: String) -> Dictionary:
	match spell_id:
		SpellKits.MARK_SHOT:
			return {"on_connect": "8 Air. +1 Mark on the target.", "on_miss": "AP/MP stay spent. No Mark."}
		SpellKits.DETONATE:
			return {"on_connect": "6+6×M Air. Consumes Marks on the target.", "on_miss": "Marks stay. AP/MP stay spent."}
		SpellKits.STRIKE:
			return {"on_connect": "16 Earth. +1 Impact.", "on_miss": "AP/MP stay spent. No Impact."}
		SpellKits.SHOULDER:
			return {"on_connect": "6 Earth. +1 Impact. Push 1.", "on_miss": "No push. No Impact. AP/MP stay spent."}
		SpellKits.CRUSH:
			return {"on_connect": "24 Earth. Spends 2 Impact. Stun 1 if Impact was 4.", "on_miss": "Impact retained. AP/MP stay spent."}
		SpellKits.ADVANCE:
			return {"on_connect": "Teleport snap. +1 Impact if adjacent. Facing unchanged.", "on_miss": "No roll."}
		_:
			return {"on_connect": "", "on_miss": ""}


## Locked Phase A damage sample/resolve. CritMult 1.0, Passive 1, Mastery 0.
## WindMod omitted (not invented as 1.0). Resist 0 is Open A05.
func _phase_a_damage(base: int, facing_mult: float) -> int:
	var raw: float = float(base) * CRIT_MULT * PASSIVE * (1.0 + MASTERY / 100.0) * (1.0 - RESIST / 100.0) * facing_mult
	return roundi(raw)


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
		# Locked Stun (A′): stun_remaining + stunned-this-turn. Blocks move + cast + face.
		"stun_remaining": 0,
		"stunned": false,
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
	_handoff_seat(actor, bool(intent.get("auto", false)))
	# Locked Stun (A′): if the seat that just started is stunned, auto-resolve
	# end_turn. Tick already ran in _begin_unit_turn, so this is the skipped turn.
	_auto_skip_stunned_turns()
	return _accept()


func _handoff_seat(actor: Dictionary, auto_skip: bool) -> Dictionary:
	var next_seat := 1 if _active_seat == 0 else 0
	var next_unit := _unit_by_seat(next_seat)
	if next_unit.is_empty() or not next_unit["alive"]:
		_finish_match(_active_seat)
		return {}

	_active_seat = next_seat
	_turn_index += 1
	_begin_unit_turn(next_unit)
	next_unit["ap"] = MAX_AP
	next_unit["mp"] = MAX_MP
	var stunned := _is_stunned(next_unit)
	if stunned:
		_last_coach = "%s's turn skipped — stunned (Locked A′)." % next_unit["name"]
	else:
		_last_coach = "%s's turn. AP/MP refilled to 6/3." % next_unit["name"]
	var end_event := {
		"type": "end_turn",
		"seat": actor["seat"],
		"next_seat": _active_seat,
		"coach": _last_coach,
	}
	if auto_skip:
		end_event["auto"] = true
		end_event["reason"] = "stunned"
		end_event["locked"] = "Locked Stun (A′) — auto end_turn on turn start"
	_last_events.append(end_event)
	_last_events.append({
		"type": "turn_start",
		"seat": _active_seat,
		"turn": _turn_index,
		"stunned_skip": stunned,
		"coach": _last_coach,
	})
	return next_unit


func _auto_skip_stunned_turns() -> void:
	# Locked Stun (A′): player never presses End Turn. Keep skipping while the
	# newly started seat is stunned. Depth-capped so a double-stun cannot loop.
	var depth := 0
	while not _match_over and depth < 4:
		var unit := _unit_by_seat(_active_seat)
		if unit.is_empty() or not _is_stunned(unit):
			break
		var auto_intent := {"type": "end_turn", "seat": int(unit["seat"]), "auto": true}
		_intent_log.append(auto_intent)
		_handoff_seat(unit, true)
		depth += 1
	if depth > 0 and not _match_over:
		var active := _unit_by_seat(_active_seat)
		if not active.is_empty() and not _is_stunned(active):
			_last_coach = "Stunned seat skipped (Locked A′). %s's turn. AP/MP refilled to 6/3." % active["name"]
			if not _last_events.is_empty():
				_last_events[_last_events.size() - 1]["coach"] = _last_coach


## Locked: one ortho hop → N/E/S/W. Empty if the step is not a single cardinal cell.
static func facing_from_step(from: Vector2i, to: Vector2i) -> String:
	var delta: Vector2i = to - from
	for dir in FACING_VEC.keys():
		if FACING_VEC[dir] == delta:
			return str(dir)
	return ""


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
	# Locked: facing follows each ortho hop; final facing = last hop direction.
	# Manual face intent stays for standing turns. Advance teleport does not auto-face.
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
	var facing_from: String = str(actor["facing"])
	var facing_hops: Array = _face_along_walk(actor, from, path)
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
		"facing_from": facing_from,
		"facing": str(actor["facing"]),
		"facing_hops": facing_hops.duplicate(),
		"mp_spent": dist,
		"coach": _last_coach,
	})
	return _accept()


## Locked A02: set actor facing from each hop. Final facing is the last hop dir.
func _face_along_walk(actor: Dictionary, from: Vector2i, path: Array) -> Array:
	var hops: Array = []
	var prev: Vector2i = from
	for cell in path:
		var dest: Vector2i = cell
		var dir := facing_from_step(prev, dest)
		if dir != "":
			actor["facing"] = dir
			hops.append(dir)
		prev = dest
	return hops


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

	if spell_id == SpellKits.ADVANCE:
		# Dest-click teleport. Ignore client intent.path. No MP spend.
		intent.erase("path")
		var advance_ap := int(def["ap"])
		var advance_mp := int(def["mp"])
		var reason := _validate_advance(actor, dest)
		if reason == "out_of_range":
			var range_dist := _range_distance(def, actor["pos"], dest)
			return _reject(intent, "out_of_range", "REJECT — Advance range %d–%d Manhattan, target at %d (refund)." % [def["min_range"], def["max_range"], range_dist])
		if reason == "insufficient_ap":
			return _reject(intent, "insufficient_ap", "REJECT — Advance costs %d AP (refund)." % advance_ap)
		if reason == "destination_occupied":
			return _reject(intent, "destination_occupied", "REJECT — Advance needs an empty tile (refund).")
		if reason != "":
			return _reject(intent, reason, "REJECT — illegal Advance (%s)." % reason)
		return _resolve_advance(intent, actor, def, dest, advance_ap, advance_mp)

	var dist := chebyshev(actor["pos"], dest)
	if dist < int(def["min_range"]) or dist > int(def["max_range"]):
		return _reject(intent, "out_of_range", "REJECT — %s range %d–%d, target at %d (refund)." % [def["name"], def["min_range"], def["max_range"], dist])

	var ap_cost := int(def["ap"])
	var mp_cost := int(def["mp"])
	if int(actor["ap"]) < ap_cost:
		return _reject(intent, "insufficient_ap", "REJECT — %s costs %d AP (refund)." % [def["name"], ap_cost])
	if int(actor["mp"]) < mp_cost:
		return _reject(intent, "insufficient_mp", "REJECT — %s costs %d MP (refund)." % [def["name"], mp_cost])

	var target := _living_unit_at(dest)
	if target.is_empty() or int(target["seat"]) == int(actor["seat"]):
		return _reject(intent, "no_target", "REJECT — %s needs an enemy (refund)." % def["name"])
	var gate := _cast_gate_reason(actor, target, def)
	if gate != "":
		return _reject(intent, gate, "REJECT — %s failed gate %s (refund)." % [def["name"], gate])
	return _resolve_rolling_cast(intent, actor, target, def, dest, dist, ap_cost, mp_cost)


func _resolve_advance(intent: Dictionary, actor: Dictionary, _def: Dictionary, dest: Vector2i, ap_cost: int, mp_cost: int) -> Dictionary:
	if str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
		return _reject(intent, "spell_not_in_kit", "REJECT — Advance is Ironjaw-only (refund).")
	var from: Vector2i = actor["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	# Teleport: dest-click snap. Never spend MP. Facing unchanged — no auto-face.
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
		_last_coach = "%s Advance to %s (−%d AP). +1 Impact (adjacent)." % [actor["name"], _cell_text(dest), ap_cost]
	elif adjacent:
		_last_coach = "%s Advance to %s (−%d AP). Adjacent, Impact already capped." % [actor["name"], _cell_text(dest), ap_cost]
	else:
		_last_coach = "%s Advance to %s (−%d AP). No Impact (not adjacent)." % [actor["name"], _cell_text(dest), ap_cost]
	_last_events.append({
		"type": "advance",
		"seat": actor["seat"],
		"from": from,
		"to": dest,
		"teleport": true,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"rolled": false,
		"adjacent": adjacent,
		"impact_gained": impact_gained,
		"coach": _last_coach,
	})
	return _accept()


func _resolve_rolling_cast(intent: Dictionary, actor: Dictionary, target: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	# Spend before the d100. Miss keeps AP/MP; engine cost would refund here (none prepaid in A).
	# Locked: miss retains Marks (Detonate) and Impact (Crush). AP/MP stay spent.
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var chance: int = hit_chance(dist)
	var roll: int = _roll_d100()
	var connected: bool = roll <= chance
	var facing_mult: float = _facing_multiplier(actor["pos"], target["pos"], str(target["facing"]))
	var is_back: bool = facing_mult > FRONT_SIDE_FACING + 0.001
	var spell_id := str(def["id"])
	var marks_on_target: int = int(target.get("marks", 0))
	var impact_before: int = int(actor.get("impact", 0))
	_intent_log.append(intent)

	if not connected:
		_last_coach = "MISS — %d AP gone (%d vs %d%%, range %d)." % [ap_cost, roll, chance, dist]
		var miss_event := {
			"type": "miss",
			"seat": actor["seat"],
			"spell": spell_id,
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
		}
		if spell_id == SpellKits.DETONATE:
			miss_event["marks_retained"] = true
			miss_event["marks_on_target"] = marks_on_target
		if spell_id == SpellKits.CRUSH:
			miss_event["impact_retained"] = true
			miss_event["impact"] = impact_before
		if spell_id == SpellKits.SHOULDER:
			miss_event["pushed"] = false
		_last_events.append(miss_event)
		return _accept()

	var base := _connect_base_damage(def, target)
	var damage := _phase_a_damage(base, facing_mult)
	target["hp"] = int(target["hp"]) - damage
	if int(target["hp"]) < 0:
		target["hp"] = 0
	var engine_gained := 0
	var engine_spent := 0
	var engine_name := ""
	var marks_consumed := 0
	match str(def["engine_on_connect"]):
		"impact":
			engine_gained = _gain_impact(actor, 1)
			engine_name = "Impact"
		"mark":
			engine_gained = _gain_marks(target, 1)
			engine_name = "Mark"
		"consume_marks":
			# A01 Locked: consume Marks from the target on connect.
			marks_consumed = _consume_marks(target)
			engine_name = "Mark"
			engine_spent = marks_consumed
		"spend_impact":
			engine_spent = _spend_impact(actor, int(def.get("spend_impact", 2)))
			engine_name = "Impact"

	var stun_applied := 0
	if spell_id == SpellKits.CRUSH and impact_before >= int(def.get("stun_if_impact_before", 4)):
		# Locked Stun (A′): Stun 1 if Impact was 4 before the spend. Blocks move + cast + face.
		stun_applied = _apply_stun(target, int(def.get("stun_remaining", 1)))

	var push_result := {}
	if int(def.get("push_cells", 0)) > 0:
		# Locked Push (1): occupied / off-board = no-move + push_blocked; damage/Impact still apply.
		push_result = _try_push(actor["pos"], target, int(def["push_cells"]))

	var facing_note := "BACK ×1.20" if is_back else "front/side ×1.00"
	var extra_note := _connect_extra_note(engine_gained, engine_name, marks_consumed, engine_spent, stun_applied, push_result)
	_last_coach = "HIT %d %s — %s vs %s (%d vs %d%%) %s.%s" % [damage, str(def["element"]).capitalize(), def["name"], target["name"], roll, chance, facing_note, extra_note]
	var hit_event := {
		"type": "hit",
		"seat": actor["seat"],
		"spell": spell_id,
		"target_seat": target["seat"],
		"to": dest,
		"range": dist,
		"hit_chance": chance,
		"roll": roll,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"base_damage": base,
		"facing_mult": facing_mult,
		"back": is_back,
		"crit_mult": CRIT_MULT,
		"damage": damage,
		"element": def["element"],
		"engine": engine_name.to_lower(),
		"engine_gained": engine_gained,
		"engine_spent": engine_spent,
		"coach": _last_coach,
	}
	if spell_id == SpellKits.DETONATE:
		hit_event["marks_consumed"] = marks_consumed
		hit_event["marks_remaining"] = int(target.get("marks", 0))
	if spell_id == SpellKits.CRUSH:
		hit_event["impact_before"] = impact_before
		hit_event["impact_spent"] = engine_spent
		hit_event["stun_applied"] = stun_applied
		# Locked Stun (A′): blocks move + cast + face; auto end_turn on turn start.
	if not push_result.is_empty():
		hit_event["pushed"] = bool(push_result.get("moved", false))
		hit_event["push_from"] = push_result.get("from")
		hit_event["push_to"] = push_result.get("to")
		hit_event["push_blocked"] = bool(push_result.get("blocked", false))
		hit_event["push_block_reason"] = str(push_result.get("reason", ""))
	_last_events.append(hit_event)
	if bool(push_result.get("blocked", false)):
		_last_events.append({
			"type": "push_blocked",
			# Locked Push (1): destination occupied or off-board — do not invent a slide/crush-into.
			"locked": "push into occupied/OOB is Locked (1) — no-move + push_blocked",
			"seat": actor["seat"],
			"target_seat": target["seat"],
			"from": push_result.get("from"),
			"attempted": push_result.get("attempted"),
			"reason": str(push_result.get("reason", "")),
			"coach": "Push blocked (%s). Locked (1): dest occupied/OOB." % str(push_result.get("reason", "")),
		})
	if stun_applied > 0:
		_last_events.append({
			"type": "status",
			"status": "stun",
			"remaining": stun_applied,
			"target_seat": target["seat"],
			# Locked Stun (A′): move/cast/face rejected; auto end_turn on turn start.
			"locked": "Locked Stun (A′) — move/cast/face rejected; auto end_turn on turn start",
			"suppress": ["move", "cast", "face"],
			"coach": "%s is stunned (Locked A′)." % target["name"],
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


func _validate_advance(actor: Dictionary, dest: Vector2i) -> String:
	if str(actor.get("class_id", "")) != SpellKits.CLASS_IRONJAW:
		return "spell_not_in_kit"
	if not _in_bounds(dest):
		return "out_of_bounds"
	if dest == actor["pos"]:
		return "same_tile"
	if not _is_empty(dest):
		return "destination_occupied"
	# Range gate is Manhattan 1–2 (diamond). Chebyshev (1,2) tiles are out of range.
	# Teleport: dest occupancy only; corridor occupants do not block. 0 MP is legal.
	var def: Dictionary = SpellKits.spell(SpellKits.ADVANCE)
	var range_dist := _range_distance(def, actor["pos"], dest)
	if range_dist < int(def["min_range"]) or range_dist > int(def["max_range"]):
		return "out_of_range"
	if int(actor["ap"]) < int(def["ap"]):
		return "insufficient_ap"
	return ""


func _range_distance(def: Dictionary, from: Vector2i, to: Vector2i) -> int:
	if str(def.get("range_mode", "chebyshev")) == "manhattan":
		return manhattan(from, to)
	return chebyshev(from, to)


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


func _apply_setup_overrides(config: Dictionary) -> void:
	# Test/setup hooks only. Not a play default — matches start at 0 Marks/Impact/stun.
	if config.has("kestrel_marks"):
		_units[0]["marks"] = mini(maxi(int(config["kestrel_marks"]), 0), int(_units[0]["marks_cap"]))
	if config.has("ironjaw_marks"):
		_units[1]["marks"] = mini(maxi(int(config["ironjaw_marks"]), 0), int(_units[1]["marks_cap"]))
	if config.has("kestrel_impact"):
		_units[0]["impact"] = mini(maxi(int(config["kestrel_impact"]), 0), int(_units[0]["impact_cap"]))
	if config.has("ironjaw_impact"):
		_units[1]["impact"] = mini(maxi(int(config["ironjaw_impact"]), 0), int(_units[1]["impact_cap"]))
	if config.has("kestrel_stun"):
		_units[0]["stun_remaining"] = maxi(int(config["kestrel_stun"]), 0)
	if config.has("ironjaw_stun"):
		_units[1]["stun_remaining"] = maxi(int(config["ironjaw_stun"]), 0)
	if config.has("blockers"):
		for cell in config["blockers"]:
			_blocked_cells.append(_as_cell(cell))


func _begin_unit_turn(unit: Dictionary) -> void:
	# Locked Stun (A′): decrement stun at start of that unit's turn.
	# Stun 1 must cover this incoming (skipped) turn. Decrementing remaining and
	# then checking remaining would expire Stun 1 before the auto end_turn.
	# Set stunned-this-turn from remaining>0, then decrement remaining.
	var remaining := int(unit.get("stun_remaining", 0))
	unit["stunned"] = remaining > 0
	if remaining > 0:
		unit["stun_remaining"] = remaining - 1


func _is_stunned(unit: Dictionary) -> bool:
	# Locked Stun (A′): remaining or this-turn flag. Blocks move + cast + face.
	return int(unit.get("stun_remaining", 0)) > 0 or bool(unit.get("stunned", false))


func _cast_gate_reason(actor: Dictionary, target: Dictionary, def: Dictionary) -> String:
	var spell_id := str(def.get("id", ""))
	if spell_id == SpellKits.DETONATE and int(target.get("marks", 0)) < int(def.get("requires_marks_on_target", 1)):
		return "insufficient_marks"
	if spell_id == SpellKits.CRUSH and int(actor.get("impact", 0)) < int(def.get("requires_impact", 2)):
		return "insufficient_impact"
	return ""


func _connect_base_damage(def: Dictionary, target: Dictionary) -> int:
	var spell_id := str(def.get("id", ""))
	if spell_id == SpellKits.DETONATE:
		# Locked: 6 + 6×M Air, M = Marks on the target consumed on connect.
		return int(def.get("base_damage", 6)) + int(def.get("damage_per_mark", 6)) * int(target.get("marks", 0))
	return int(def.get("base_damage", 0))


func _connect_extra_note(engine_gained: int, engine_name: String, marks_consumed: int, engine_spent: int, stun_applied: int, push_result: Dictionary) -> String:
	var parts: Array[String] = []
	if engine_gained > 0:
		parts.append(" +1 %s." % engine_name)
	if marks_consumed > 0:
		parts.append(" Marks consumed (%d)." % marks_consumed)
	if engine_spent > 0 and engine_name == "Impact":
		parts.append(" Impact spent (%d)." % engine_spent)
	if stun_applied > 0:
		parts.append(" Stun %d (Locked A′)." % stun_applied)
	if not push_result.is_empty():
		if bool(push_result.get("blocked", false)):
			parts.append(" Push blocked (Locked (1): dest occupied/OOB).")
		elif bool(push_result.get("moved", false)):
			parts.append(" Pushed to %s." % _cell_text(push_result["to"]))
	var note := ""
	for part in parts:
		note += part
	return note


func _gain_impact(unit: Dictionary, amount: int) -> int:
	if str(unit.get("class_id", "")) != SpellKits.CLASS_IRONJAW:
		return 0
	var before: int = int(unit["impact"])
	unit["impact"] = mini(before + amount, int(unit["impact_cap"]))
	return int(unit["impact"]) - before


func _spend_impact(unit: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var before: int = int(unit.get("impact", 0))
	if before < amount:
		return 0
	unit["impact"] = before - amount
	return amount


func _gain_marks(unit: Dictionary, amount: int) -> int:
	# A01 Locked: Marks live on the target unit this helper is called with.
	var before: int = int(unit["marks"])
	unit["marks"] = mini(before + amount, int(unit["marks_cap"]))
	return int(unit["marks"]) - before


func _consume_marks(unit: Dictionary) -> int:
	# A01 Locked: consume the target's Marks stack. Miss path never calls this.
	var consumed: int = int(unit.get("marks", 0))
	unit["marks"] = 0
	return consumed


func _apply_stun(unit: Dictionary, remaining: int) -> int:
	# Locked Stun (A′): store stun_remaining. Blocks move + cast + face; auto end_turn.
	if remaining <= 0:
		return 0
	unit["stun_remaining"] = maxi(int(unit.get("stun_remaining", 0)), remaining)
	return remaining


func _try_push(caster_pos: Vector2i, target: Dictionary, cells: int) -> Dictionary:
	# Chebyshev push 1 along the caster→target line. Locked Push (1) if dest occupied or OOB:
	# do not move; still keep damage/Impact from the hit; emit push_blocked.
	var from: Vector2i = target["pos"]
	var dest := push_destination(caster_pos, from, cells)
	var result := {
		"from": from,
		"to": from,
		"attempted": dest,
		"moved": false,
		"blocked": false,
		"reason": "",
	}
	if not _in_bounds(dest):
		result["blocked"] = true
		result["reason"] = "out_of_bounds"
		return result
	if not _is_empty(dest):
		result["blocked"] = true
		result["reason"] = "occupied"
		return result
	target["pos"] = dest
	result["to"] = dest
	result["moved"] = true
	return result


static func push_destination(caster_pos: Vector2i, target_pos: Vector2i, cells: int = 1) -> Vector2i:
	var delta: Vector2i = target_pos - caster_pos
	var step := Vector2i(
		0 if delta.x == 0 else (1 if delta.x > 0 else -1),
		0 if delta.y == 0 else (1 if delta.y > 0 else -1)
	)
	return target_pos + step * cells


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
	for blocked in _blocked_cells:
		if blocked == cell:
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
