extends Node

## Local Phase A combat brain. Godot nodes must not mutate HP or roll.
## API: reset_match(config), submit(intent), legal_intents(seat), snapshot(),
## preview_cast(spell_id, from, to, target_seat=-1) — also accepts an intent Dictionary.
## Locked deploy flow (live duel): place / reposition / ready, then Turn 1 combat.
## Proposed zones (shipped live): seed-sampled ~6-cell blobs, not #31 border halves.
## Godot chrome binds place_unit / ready_seat / legal_deploy_cells / can_ready.
## Locked walk: per-tile elevation + terrain_type; dest-click weighted pathfinder.
## Proto/elevation stays reference — this file does not import it.

const RULES_VERSION := "phase-a-gdd-0.2"
const UNPLACED := Vector2i(-1, -1)
const _MatchFlow := preload("res://backend/match_flow.gd")
const _WalkBoard := preload("res://backend/walk_board.gd")
const _TerrainDef := preload("res://backend/terrain_def.gd")
const _ElevationCost := preload("res://backend/elevation_cost.gd")
const _BoardSize := preload("res://backend/board_size.gd")
const _CellTagMap := preload("res://backend/cell_tag_map.gd")
const _HitBands := preload("res://backend/hit_bands.gd")
## Ship default is 15×15. MatchConfig.board_size 8 and 12 are proto only.
const BOARD_SIZE := _BoardSize.SHIP
const MAX_AP := 6
const MAX_MP := 3
const START_HP := 80
const CRIT_MULT := 1.0
const MASTERY := 0.0
const RESIST := 0.0
const PASSIVE := 1.0
const BACK_FACING := 1.20
const FRONT_SIDE_FACING := 1.00
## Director Locked Shoulder stagger: 4 HP; +1 MP only when current MP >= 1.
const STAGGER_HP := 4
const STAGGER_MP := 1
## Clean push (walkable empty, or lava land — not a bounce): +1 Impact.
## Bounce (OOB / truly blocked, not lava): +2 Impact only. Do not add +1 on top.
const SHOULDER_CONNECT_IMPACT := 1
const SHOULDER_BOUNCE_IMPACT := 2
## Director Locked Burn: 4 HP at the start of the victim's turn, two ticks.
## Re-apply refreshes duration. It does not stack. Impact cap still applies.
const BURN_HP := 4
const BURN_DURATION := 2

const FACING_VEC := {
	"N": Vector2i(0, -1),
	"E": Vector2i(1, 0),
	"S": Vector2i(0, 1),
	"W": Vector2i(-1, 0),
}

## A03–A07 are Open (A05 Resist/rounding/WindMod still Open). A01 Marks-on-target
## is Locked. A02 walk is Locked (dest-click weighted pathfinder; cost = dest
## terrain MP + uphill elevation). Facing follows each hop of that path. Phase A
## flat Manhattan / H-first expansion is superseded. Advance range is Locked
## to exactly 2 cardinal spaces (N/S/E/W at Manhattan 2). Manhattan 1,
## diagonals, and any non-cardinal are rejected. Advance dest uses the same
## stand-on gates as walk.
## Hit bands / facing cones / spell LoS do not read height. Locked Stun (A′):
## blocks move + cast + face; auto end_turn on that seat's turn start (player
## never presses End Turn). Director Locked Shoulder: occupied dest is
## push_blocked (hard body-block; hit Impact stays +1). Walkable empty dest
## pushes for +1 Impact. OOB / truly blocked (not lava) bounces and staggers
## for +2 Impact only (no stack with +1). Lava is hazardous, not a wall:
## forced push displaces onto lava and applies Burn. Voluntary walk onto
## lava stays impassable.
## Director Locked Burn: 4 HP at the start of the victim's turn, duration 2.
## Re-apply refreshes duration and does not stack. Burn continues after
## leaving lava. Death is checked after each tick. burn_remaining lives on
## the unit snapshot for Godot chrome and host sync.
## Host-owned 30s turn clock: starts on turn begin, ticks only on the authority
## (listen-host / hot-seat). Expiry submits the same end_turn as the HUD button.
## Guest replicas hydrate remaining from snapshot and must not tick.
const OPEN_DECISIONS := ["A03", "A04", "A05", "A06", "A07"]
const TURN_TIME_LIMIT := 30.0

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
## Test/setup occupancy only. Occupied dest is hard body-block (push_blocked).
var _blocked_cells: Array[Vector2i] = []
## Snap Wall cells. They block walk (and would block Gust) only while a
## bastion is in the match. Each wall is one tile for wall_turns (Locked: 2
## owner Bastion turn-starts, same family as Burn). Gust itself is not
## implemented (A03). Walls exist only while Snap Wall placed them.
var _snap_wall_cells: Array[Vector2i] = []
var _snap_wall_state: Array = []
var _shade_tokens: Array = []
var _plant_tiles: Array = []
## Locked deploy. Live duel starts here; (1,1)/(6,6) are skip_deploy fixtures only.
var _flow = _MatchFlow.new()
## Per-tile integer elevation + terrain. Ship maps load a Koliseo tags file
## when its size is 15×15 (default Crosshaven; map_id selects the catalog).
## Proto 8 is the crop. Proto 12 is Mauro's token grid.
## Godot reads snapshot.tiles. paint_only is not walk data.
var _board = _WalkBoard.new()
var _board_size: int = BOARD_SIZE
var _paint_only: Dictionary = {}
var _map_id: String = ""
var _demo_map: String = ""
var _elev_seed: int = 0
var _elevation_gen: String = "tags"
var _turn_time_remaining: float = 0.0
var _turn_time_limit: float = TURN_TIME_LIMIT
var _turn_time_running: bool = false
## True after apply_host_snapshot. Replica may paint; it must not tick or submit.
var _replica: bool = false


func reset_match(config: Dictionary = {}) -> Dictionary:
	_units.clear()
	_blocked_cells.clear()
	_snap_wall_cells.clear()
	_snap_wall_state.clear()
	_shade_tokens.clear()
	_plant_tiles.clear()
	_active_seat = 0
	_turn_index = 0
	_match_over = false
	_winner_seat = -1
	_scripted_rolls.clear()
	_last_events.clear()
	_intent_log.clear()
	_replica = false
	_stop_turn_timer()
	_board_size = _BoardSize.resolve(config)
	_board = _WalkBoard.new(_board_size, _board_size)
	_paint_only = {}
	_map_id = ""
	_demo_map = ""
	# New Match generates a fresh seed unless MatchConfig.seed / elev_seed is set.
	_seed = int(config.get("seed", Time.get_ticks_usec()))
	_elev_seed = int(config.get("elev_seed", _seed))
	_rng.seed = _seed
	_elevation_gen = "flat"
	_seed_play_board(config)
	_apply_tile_overrides(config)
	var flow_config := config.duplicate(true)
	flow_config["board_size"] = _board_size
	flow_config["elev_seed"] = _elev_seed
	_flow.reset(_seed, flow_config)
	if config.has("rolls"):
		for roll in config["rolls"]:
			_scripted_rolls.append(int(roll))

	# Hot-seat default is Kestrel (seat 0) then Ironjaw (seat 1).
	# config.classes / seat_classes overrides both seats when every id is on
	# the Locked allowlist. Any unknown id falls back to that default pair.
	var roster: Array[String] = _roster_class_ids(config)
	var facing_used: Dictionary = {}
	for seat in 2:
		var class_id: String = roster[seat]
		var facing := _facing_for(config, class_id, facing_used)
		_units.append(_make_unit(seat, class_id, SpellKits.display_name(class_id), SpellKits.element_of(class_id), UNPLACED, facing, false))
	_apply_setup_overrides(config)

	var skip_deploy := bool(config.get("skip_deploy", false)) or config.has("kestrel_pos") or config.has("ironjaw_pos") or config.has("positions")
	if skip_deploy:
		# Test/setup only. Live duel no longer defaults to (1,1)/(6,6).
		# kestrel_pos / ironjaw_pos still name that class, not a fixed seat.
		var class_pos_used: Dictionary = {}
		for seat in 2:
			var class_id: String = str(_units[seat]["class_id"])
			_force_spawn(seat, _spawn_cell_for(config, seat, class_id, class_pos_used))
		_flow.skip_to_combat()
		_apply_shade_setup(config)
		_begin_combat(_opening_turn_coach(""))
	else:
		_last_coach = "Deployment. Place one fighter in your deploy zone, then Ready."
		_last_events = [{
			"type": "deploy_start",
			"phase": _flow.phase_name(),
			"coach": _last_coach,
		}]

	_broadcast()
	return snapshot()


func submit(intent: Dictionary) -> Dictionary:
	_last_events = []
	var normalized := _normalize_intent(intent)
	if _match_over:
		return _reject(normalized, "match_over", "REJECT — match is over.")

	var kind := str(normalized.get("type", ""))
	if _flow.is_deployment():
		return _submit_deploy(normalized, kind)
	if kind in ["place", "reposition", "ready", "confirm"]:
		return _reject(normalized, "wrong_phase", "REJECT — deploy is over.")

	var seat := _active_seat
	if normalized.has("seat") and int(normalized["seat"]) != seat:
		return _reject(normalized, "not_your_turn", "REJECT — only the active seat can act.")

	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not actor["alive"]:
		return _reject(normalized, "dead", "REJECT — dead units cannot act.")

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
		"place", "reposition", "ready", "confirm":
			return _reject(normalized, "wrong_phase", "REJECT — deploy is over.")
		_:
			return _reject(normalized, "unknown_intent", "REJECT — unknown intent.")


## Host / hot-seat only. Guest replicas no-op. On expiry, submit the same
## end_turn Intent as the HUD button for the active seat.
func tick_turn_timer(delta: float) -> Dictionary:
	if _replica:
		return _timer_tick_result(false)
	if _match_over or _flow.is_deployment():
		_stop_turn_timer()
		return _timer_tick_result(false)
	if not _turn_time_running:
		return _timer_tick_result(false)
	_turn_time_remaining = maxf(_turn_time_remaining - maxf(delta, 0.0), 0.0)
	if _turn_time_remaining > 0.0:
		return _timer_tick_result(false)
	_turn_time_running = false
	_turn_time_remaining = 0.0
	var result: Dictionary = submit({
		"type": "end_turn",
		"seat": _active_seat,
		"auto": true,
		"reason": "timer",
	})
	result["expired"] = true
	return result


func turn_time_seconds() -> int:
	return _clock_display_seconds(_turn_time_remaining)


func legal_intents(seat: int) -> Array:
	var out: Array = []
	if _match_over:
		return out
	if _flow.is_deployment():
		return _legal_deploy_intents(seat)
	if seat != _active_seat:
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
	if int(actor.get("exit_tax", 0)) > 0:
		mp = maxi(mp - 1, 0)
	var ap: int = int(actor["ap"])
	# Walk dests whenever mp>0, regardless of remaining AP. Advance is 3 AP / 0 MP, so
	# leftover MP after teleport still offers moves (including at 0 AP). Walk facing
	# is applied on submit (each hop), not here. Legal cells = weighted reachable.
	if mp > 0:
		for cell in _board.reachable_dests(from, mp, Callable(self, "_walk_occupied")):
			out.append({"type": "move", "to": cell, "seat": seat})

	for spell_id in actor["spells"]:
		if spell_id == SpellKits.ADVANCE and str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
			continue
		var def: Dictionary = SpellKits.spell(str(spell_id))
		if def.is_empty() or SpellKits.is_gated(str(spell_id)):
			continue
		# Ambush is a blink (4 AP / 0 MP), not a walk. Offer it before the
		# walk budget is consulted. MP 0 is legal when AP covers the card.
		if str(spell_id) == SpellKits.AMBUSH:
			_append_ambush_cast(out, actor, def)
			continue
		if ap < int(def["ap"]):
			continue
		if _resource_gate(actor, def) != "":
			continue
		if int(actor.get("mp", 0)) < int(def.get("mp", 0)):
			continue
		var target_kind := str(def.get("target", "enemy"))
		if target_kind == "self":
			out.append({"type": "cast", "spell": spell_id, "to": from, "seat": seat})
			continue
		if target_kind == "empty_tile" and str(spell_id) != SpellKits.ADVANCE:
			_append_ranged_cells(out, actor, def, str(spell_id), true)
			continue
		if target_kind == "tile":
			_append_ranged_cells(out, actor, def, str(spell_id), false)
			continue
		if target_kind == "cone":
			if _cone_enemies(actor, false).is_empty():
				continue
			if not _cone_enemies(actor, true).is_empty():
				continue
			out.append({"type": "cast", "spell": spell_id, "to": from + _facing_step(actor), "seat": seat})
			continue
		if target_kind == "burst":
			# AoE versus Invisible is open. Do not offer a cast that would resolve it.
			if not _burst_enemies(actor, def, true).is_empty():
				continue
			var burst_bodies: Array = _burst_enemies(actor, def, false)
			if burst_bodies.is_empty():
				continue
			for burst_body in burst_bodies:
				var burst_target: Dictionary = burst_body
				out.append({
					"type": "cast",
					"spell": spell_id,
					"to": burst_target["pos"],
					"target_seat": burst_target["seat"],
					"seat": seat,
				})
			continue
		if target_kind == "ally" or target_kind == "any":
			if _in_spell_range(def, from, from):
				out.append({"type": "cast", "spell": spell_id, "to": from, "target_seat": seat, "seat": seat})
			if target_kind == "ally":
				continue
		if def["target"] == "empty_tile":
			# Advance: exactly 2 cardinal spaces (N/S/E/W) that pass stand-on gates.
			var reach := int(def.get("max_range", 2))
			for dir in FACING_VEC.keys():
				var step: Vector2i = FACING_VEC[dir]
				var dest := from + step * reach
				if _validate_advance(actor, dest) == "":
					out.append({
						"type": "cast",
						"spell": spell_id,
						"to": dest,
						"seat": seat,
					})
		else:
			# Card MP was already compared to the unit's MP. Do not reuse the
			# walk budget here: exit tax shortens walks only. A 0 MP cast
			# such as Ambush stays legal at MP 0.
			var enemy := _enemy_of(seat)
			if enemy.is_empty() or not enemy["alive"]:
				continue
			if _cast_gate_reason(actor, enemy, def) != "":
				continue
			if _in_spell_range(def, from, enemy["pos"]):
				out.append({
					"type": "cast",
					"spell": spell_id,
					"to": enemy["pos"],
					"target_seat": enemy["seat"],
					"seat": seat,
				})

	out.append({"type": "end_turn", "seat": seat})
	return out


## Locked Ambush: 4 AP / 0 MP, Manhattan 1–2 cardinal from the origin, blink to the
## empty tile one step past the enemy on that axis. Origin is Gloam while Invisible,
## otherwise the first live Shade. A Shade origin is illegal until the opponent has
## completed one full turn since that Drop. Fade / Invisible self-origin has no delay.
## Spends a Shade only when the origin was a Shade. This offer does not call the
## pathfinder and does not read the walk budget, so MP 0 does not hide the cast.
func _append_ambush_cast(out: Array, actor: Dictionary, def: Dictionary) -> void:
	if int(actor.get("ap", 0)) < int(def.get("ap", 0)):
		return
	if int(actor.get("mp", 0)) < int(def.get("mp", 0)):
		return
	if _resource_gate(actor, def) != "":
		return
	var seat := int(actor["seat"])
	var enemy := _enemy_of(seat)
	if enemy.is_empty() or not bool(enemy.get("alive", false)):
		return
	if _cast_gate_reason(actor, enemy, def) != "":
		return
	# Offer only a legal Manhattan 1–2 cardinal target whose back tile can be
	# landed on, and only once a Shade origin has seen the opponent finish a
	# turn. A fresh Shade, a diagonal, or Manhattan 3 must not arm the cast.
	# Drop Shade's Chebyshev ring is a different spell.
	if not _ambush_can_offer(actor, enemy):
		return
	out.append({
		"type": "cast",
		"spell": SpellKits.AMBUSH,
		"to": enemy["pos"],
		"target_seat": enemy["seat"],
		"seat": seat,
	})


## Godot bind: place / reposition this seat's one fighter. Simultaneous; no turn gate.
func place_unit(seat: int, cell: Variant) -> Dictionary:
	return submit({"type": "place", "seat": seat, "to": _as_cell(cell)})


## Godot bind: Ready this seat. Gated on unit placed. Both ready → lock → Turn 1.
func ready_seat(seat: int) -> Dictionary:
	return submit({"type": "ready", "seat": seat})


func can_ready(seat: int) -> bool:
	return _flow.can_ready(seat)


func can_place(seat: int, cell: Variant) -> Dictionary:
	return _deploy_place_gate(seat, _as_cell(cell))


func legal_deploy_cells(seat: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _flow.legal_place_cells(seat, Callable(self, "_occupant_seat")):
		if _board.is_walkable(cell):
			out.append(cell)
	return out


## Test / setup: paint a live tile. Live reset seeds the Director Phase A demo.
func set_tile(cell: Variant, terrain_type: Variant, elevation: Variant = 0, walkable_override: Variant = null) -> void:
	_board.set_tile(_as_cell(cell), terrain_type, _ElevationCost.as_z(elevation), walkable_override)


func tile_at(cell: Variant) -> Dictionary:
	var tile = _board.tile_at(_as_cell(cell))
	if tile == null:
		return {}
	return tile.snapshot()


func deploy_zone_cells(seat: int) -> Array[Vector2i]:
	return _flow.zone_cells(seat)


func match_phase_name() -> String:
	return _flow.phase_name()


## Presentation helper: in-bounds tiles in the spell's range ring (caster tile excluded).
## Mark Shot uses this for Chebyshev 2–7 chrome. Does not imply a legal cast dest.
## Advance is the exception: highlights are legal_intents dests only (exactly 2
## cardinal spaces that pass stand-on). Not a Manhattan 1 ring and not a diamond.
## Chrome only. Shown when Ambush is a legal arm: Manhattan 1–2 cardinal from the
## origin (Gloam while Invisible, otherwise the first live Shade) and the back
## tile can be landed on. A Shade the opponent has not yet finished a turn past
## does not open this chrome.
func ambush_origin(seat: int) -> Dictionary:
	var hidden := {"show": false, "from_self": false, "origin": Vector2i(-1, -1)}
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return hidden
	if str(actor.get("class_id", "")) != SpellKits.CLASS_GLOAM:
		return hidden
	var enemy := _enemy_of(seat)
	if not _ambush_can_offer(actor, enemy):
		return hidden
	if bool(actor.get("invisible", false)):
		return {"show": true, "from_self": true, "origin": actor["pos"]}
	var shade := _first_shade(actor)
	if shade.is_empty():
		return hidden
	return {"show": true, "from_self": false, "origin": shade["pos"]}


## Chrome only. The locked empty back tile, for the aim highlight.
## Same range and landing gate as the offer. Illegal geometry stays dark.
func ambush_landing_preview(seat: int) -> Dictionary:
	var actor := _unit_by_seat(seat)
	var enemy := _enemy_of(seat)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return {"ok": false}
	if not _ambush_can_offer(actor, enemy):
		return {"ok": false}
	return _ambush_landing(actor, enemy)


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
	if spell_id == SpellKits.ADVANCE:
		for intent in legal_intents(seat):
			if typeof(intent) != TYPE_DICTIONARY:
				continue
			if str(intent.get("type", "")) != "cast" or str(intent.get("spell", "")) != SpellKits.ADVANCE:
				continue
			if intent.has("to"):
				out.append(intent["to"])
		return out
	var from: Vector2i = actor["pos"]
	if spell_id == SpellKits.AMBUSH:
		var origin_cell := _ambush_range_origin(actor)
		if origin_cell == UNPLACED:
			return out
		from = origin_cell
	# Cardinal kits share _range_distance: one axis is 0 and the other is in
	# [min, max]. Ambush is Manhattan 1–2 N/E/S/W. A Chebyshev ring is not legal.
	for y in range(_board_size):
		for x in range(_board_size):
			var cell := Vector2i(x, y)
			if cell == from:
				continue
			var dist := _range_distance(def, from, cell)
			if dist > _HitBands.MAX_DISTANCE:
				continue
			if dist >= int(def["min_range"]) and dist <= int(def["max_range"]):
				out.append(cell)
	return out


func snapshot() -> Dictionary:
	var units: Array = []
	for unit in _units:
		units.append(_unit_snapshot(unit))
	var flow_snap := _flow.snapshot()
	var class_ids: Array = _class_ids()
	var seat_classes: Dictionary = {0: "", 1: ""}
	if class_ids.size() > 0:
		seat_classes[0] = str(class_ids[0])
	if class_ids.size() > 1:
		seat_classes[1] = str(class_ids[1])
	return {
		"rules_version": RULES_VERSION,
		"board_size": _board_size,
		"active_seat": _active_seat,
		"turn_index": _turn_index,
		"match_over": _match_over,
		"winner_seat": _winner_seat,
		"seed": _seed,
		"elev_seed": _elev_seed,
		"elevation_gen": _elevation_gen,
		"match_config": {
			"seed": _seed,
			"elev_seed": _elev_seed,
			"board_size": _board_size,
			"map_id": _map_id,
			"classes": class_ids,
			"seat_classes": seat_classes,
		},
		"snap_walls": _cell_list(_snap_wall_cells),
		"snap_wall_active": _bastion_in_match(),
		"blocked_tiles": _blocked_tile_snapshot(),
		"shade_tokens": _placed_token_snapshot(_shade_tokens, false),
		"plant_tiles": _placed_token_snapshot(_plant_tiles, true),
		"umbral_cap": SpellKits.UMBRAL_CAP,
		"umbral_owner": SpellKits.CLASS_GLOAM,
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
		"walk": "weighted",
		"walk_cost": "terrain_plus_elevation",
		"walk_edges": "ortho",
		"walk_tie_break": "cheapest_mp",
		"walk_facing": "last_hop",
		"max_climb": _ElevationCost.MAX_CLIMB,
		"max_drop": _ElevationCost.MAX_DROP,
		"terrain_mp": {
			"ground": 1,
			"mud": 2,
			"water": 2,
			"lava": 0,
		},
		"tiles": _board.snapshot_tiles(),
		"paint_only": _paint_only_snapshot(),
		"demo_map": _demo_map,
		"map_id": _map_id,
		"spell_range": "chebyshev",
		"advance_mp": "none",
		"advance_ap": 3,
		"advance_range": "cardinal_2",
		"advance_path": "teleport",
		"advance_stand_on": "walk_gates",
		"marks_owner": "target",
		"stun": "locked_a_prime",
		"stun_blocks": "move_cast_face",
		"stun_auto_end_turn": true,
		"push": "locked_shoulder",
		"push_occupied": "push_blocked",
		"push_unwalkable": "bounce_stagger",
		"push_lava": "displace_burn",
		"push_stagger_hp": STAGGER_HP,
		"push_stagger_mp": STAGGER_MP,
		"shoulder_impact_connect": SHOULDER_CONNECT_IMPACT,
		"shoulder_impact_bounce": SHOULDER_BOUNCE_IMPACT,
		"burn": "locked",
		"burn_hp": BURN_HP,
		"burn_duration": BURN_DURATION,
		"phase": flow_snap["phase_name"],
		"phase_name": flow_snap["phase_name"],
		"deploy": "locked",
		"deploy_simultaneous": true,
		"deploy_legal_cells": "sampled_blob_6",
		"deploy_zone_split": "seeded_random_blobs",
		"deploy_zone_gen": "proposed_random_blobs",
		"deploy_blob_size": _MatchFlow.BLOB_SIZE,
		"deploy_min_chebyshev": _MatchFlow.MIN_ZONE_CHEBYSHEV,
		"deploy_zone_distance": _flow.zone_distance,
		"deploy_zones": {
			0: _flow.zone_cells(0).duplicate(),
			1: _flow.zone_cells(1).duplicate(),
		},
		"ready": flow_snap["ready"],
		"both_ready": flow_snap["both_ready"],
		"positions_locked": flow_snap["positions_locked"],
		"combat_enabled": flow_snap["combat_enabled"],
		"walk_enabled": flow_snap["walk_enabled"],
		"end_turn_enabled": flow_snap["end_turn_enabled"],
		"turn_time_remaining": _turn_time_remaining,
		"turn_time_limit": _turn_time_limit,
		"turn_time_running": _turn_time_running,
		"turn_time_seconds": _clock_display_seconds(_turn_time_remaining),
		"turn_timer": "host",
		"networking": false,
		"open_deploy": ["fog", "hidden_enemy", "deploy_timer", "multi_unit"],
		"open_notes": {
			"A03": "Omitted: Gust/wind heading. WindMod omitted (not invented as 1.0).",
			"A04": "Crit *roll* OFF. CritMult held at 1.0. No elemental riders.",
			"A05": "Open: Resist 0, damage rounded to nearest int. WindMod omitted from the formula. Locked Stun (A′): stun_remaining on the unit; reject move/cast/face with stunned_cannot_act; auto end_turn on that seat's turn start (player never presses End Turn). Decrement at start of that unit's turn after setting stunned-this-turn so Stun 1 covers the incoming (skipped) turn. Director Locked Shoulder: occupied dest is push_blocked (hard body-block, no bounce/stagger; Impact stays the hit +1). Walkable empty dest pushes for +1 Impact. OOB / truly blocked (not lava) bounces (target stays) and staggers (4 HP; +1 MP if current MP >= 1) for +2 Impact only (no stack with +1). Lava is hazardous for a forced push: displace onto lava and apply Burn. Director Locked Burn: 4 HP at the start of the victim's turn, duration 2, re-apply refreshes and does not stack, continues after leaving lava, death check after each tick. Voluntary walk onto lava stays impassable.",
			"A06": "Advance (Locked teleport): dest-click snap, 3 AP / 0 MP, client path ignored. Range gate is exactly 2 cardinal spaces (N/S/E/W at Manhattan 2). Manhattan 1, diagonals, and any non-cardinal are rejected. Dest must pass the same stand-on gates as walk (walkable, not occupied, not lava, climb<=1 / drop<=2). Gate only — no terrain+elev MP spend. Illegal dest refunds. legal_intents / preview_cast use the shared helper. leftover MP still walks (legal_intents is mp>0, not AP). No hop path. +1 Impact if Chebyshev 1 to an enemy after landing. Facing unchanged — Advance does not auto-face.",
			"A07": "Provisional Open: back = 90° rear cone (facing-axis dominates and is opposite). Front/side ×1.00, back ×1.20.",
			"deploy": "Locked flow: simultaneous place/reposition, Ready gated on place, both ready → lock → Turn 1. Proposed (shipped live): seed-sampled ~6-cell blobs (2×3 or organic), interior allowed, min opening Chebyshev 3 (prefer 4–6), reject overlap and same-edge camping. Open: fog/hidden enemy, deploy timer, multi-unit. No networking.",
			"elevation": "Locked walk: per-tile integer elevation + terrain_type. Ship terrain + elevation load from the picked Koliseo tags file when size is 15×15 (default Crosshaven; map_id selects brinewake, slagcrown, windmere, or stormspire; no invented layout). paint_only is visual only. Proto board_size 8 keeps the 8×8 crop plus seeded noise. Proto board_size 12 keeps Mauro's token grid. Terrain MP Ground 1, Mud 2, Water 2, Lava impassable. Uphill +1 per integer z step; downhill 0. Max climb 1 / drop 2 (no z1→z3 hop); ortho-only. Walk cost = dest terrain + elev Δ. Weighted pathfinder; legal cells from remaining MP. Advance uses the same stand-on gates (no MP spend). Hit bands are Locked through Chebyshev 14 (see HitBands). Dist past 14 has no percent. Facing / spell LoS unchanged — no height mods. Open (do not invent): height→hit/facing/LoS, stairs/ramps/flying, hit % past 14.",
		},
		"open_elevation": ["height_hit", "height_facing", "height_los", "stairs", "ramps", "flying"],
	}


## Client replica only. Restore view + read-only queries from a host snapshot.
## Does not roll, does not _broadcast, and is not authority. Host still owns submit.
func apply_host_snapshot(snap: Dictionary) -> void:
	_replica = true
	_seed = int(snap.get("seed", 0))
	_elev_seed = int(snap.get("elev_seed", _seed))
	_rng.seed = _seed
	_scripted_rolls.clear()
	_blocked_cells.clear()
	_snap_wall_cells.clear()
	_snap_wall_state.clear()
	_shade_tokens.clear()
	_plant_tiles.clear()
	if snap.has("shade_tokens"):
		_restore_placed_tokens(_shade_tokens, snap.get("shade_tokens", []))
	if snap.has("plant_tiles"):
		_restore_placed_tokens(_plant_tiles, snap.get("plant_tiles", []))
	_restore_blocked_tiles(snap)
	_intent_log.clear()
	_active_seat = int(snap.get("active_seat", 0))
	_turn_index = int(snap.get("turn_index", 0))
	_match_over = bool(snap.get("match_over", false))
	_winner_seat = int(snap.get("winner_seat", -1))
	_turn_time_limit = float(snap.get("turn_time_limit", TURN_TIME_LIMIT))
	_turn_time_remaining = float(snap.get("turn_time_remaining", 0.0))
	_turn_time_running = bool(snap.get("turn_time_running", false))
	_last_coach = str(snap.get("coach", ""))
	_last_events = []
	for event in snap.get("last_events", []):
		if typeof(event) == TYPE_DICTIONARY:
			_last_events.append((event as Dictionary).duplicate(true))
	_elevation_gen = str(snap.get("elevation_gen", "tags"))
	_board_size = int(snap.get("board_size", BOARD_SIZE))
	_map_id = str(snap.get("map_id", ""))
	_demo_map = str(snap.get("demo_map", _map_id))
	_paint_only = _paint_only_from_snap(snap.get("paint_only", {}))
	_units.clear()
	for raw in snap.get("units", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = (raw as Dictionary).duplicate(true)
		# Opponent wire sets pos to null when this unit is invisible to that seat.
		# Null is not a tile. Store UNPLACED so the replica does not invent (0,0).
		var raw_pos: Variant = unit.get("pos", UNPLACED)
		if raw_pos == null:
			unit["pos"] = UNPLACED
		else:
			unit["pos"] = _as_cell(raw_pos)
		_units.append(unit)
	if snap.has("shade_tokens"):
		_sync_shade_flags()
	_board = _WalkBoard.new(_board_size, _board_size)
	_apply_snapshot_tiles(snap.get("tiles", {}))
	_flow.apply_host_snapshot(snap)


func _apply_snapshot_tiles(raw: Variant) -> void:
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var rec: Dictionary = item
			_board.set_tile(_as_cell(rec.get("pos", rec)), str(rec.get("terrain_type", "ground")), int(rec.get("elevation", 0)))
		return
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var tiles: Dictionary = raw
	for key in tiles:
		var rec: Variant = tiles[key]
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var cell: Vector2i = key if key is Vector2i else _as_cell((rec as Dictionary).get("pos", key))
		_board.set_tile(cell, str(rec.get("terrain_type", "ground")), int(rec.get("elevation", 0)))


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## One orthogonal hop (walk). Not the Advance range gate.
static func is_cardinal_step(from: Vector2i, to: Vector2i) -> bool:
	var delta: Vector2i = to - from
	return absi(delta.x) + absi(delta.y) == 1


## Advance Locked range: exactly N tiles on one cardinal axis, N from the kit (2).
## False for any other distance, diagonals / (1,1), knights, and the caster tile.
static func is_advance_cardinal(from: Vector2i, to: Vector2i) -> bool:
	var def: Dictionary = SpellKits.spell(SpellKits.ADVANCE)
	var dist := int(def.get("max_range", 2))
	if int(def.get("min_range", dist)) != dist:
		return false
	return is_cardinal_exact(from, to, dist)


## Pure N/E/S/W of exactly dist tiles. Both axes nonzero is never cardinal.
static func is_cardinal_exact(from: Vector2i, to: Vector2i, dist: int) -> bool:
	return _cardinal_axis_len(from, to) == dist


## Axis length when one of Δx/Δy is 0. -1 when both axes are nonzero.
static func _cardinal_axis_len(from: Vector2i, to: Vector2i) -> int:
	var delta: Vector2i = to - from
	var ax := absi(delta.x)
	var ay := absi(delta.y)
	if ax != 0 and ay != 0:
		return -1
	return ax + ay


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
	return _HitBands.chance(distance)


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
	# Locked rolling aim: Mark Shot / Strike / Detonate / Shoulder / Crush / Ambush.
	# No +5. No Advance. No invented stun/push. Ambush % is origin-to-target.
	if def.is_empty() or not bool(def.get("rolls", false)):
		return out
	if not [
		SpellKits.MARK_SHOT,
		SpellKits.STRIKE,
		SpellKits.DETONATE,
		SpellKits.SHOULDER,
		SpellKits.CRUSH,
		SpellKits.AMBUSH,
	].has(spell_id):
		return out
	# Ambush has one legal body. A hover tile must not invent a second percent.
	if spell_id == SpellKits.AMBUSH:
		dest = null
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
	var aim_from: Vector2i = actor["pos"]
	if spell_id == SpellKits.AMBUSH:
		var origin_cell := _ambush_range_origin(actor)
		if origin_cell != UNPLACED:
			aim_from = origin_cell
	var dist := chebyshev(aim_from, cell)
	out["range"] = dist
	var chance := hit_chance(dist)
	out["hit_chance"] = chance
	# Locked % for Chebyshev 1–14. Dist >14 stays hidden (no invented %).
	if chance >= 0 and dist >= 1 and dist <= _HitBands.MAX_DISTANCE:
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
		"range_text": SpellKits.range_text(def),
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

	var range_from := from_cell
	if spell_id == SpellKits.AMBUSH and not actor.is_empty():
		var origin_cell := _ambush_range_origin(actor)
		if origin_cell != UNPLACED:
			range_from = origin_cell
	if spell_id == SpellKits.ADVANCE:
		# Exactly 2 cardinal spaces, dist read from the Advance kit. Manhattan 1 and (1,1) are out of range.
		out["in_range"] = is_advance_cardinal(from_cell, to_cell)
	else:
		var range_dist := _range_distance(def, range_from, to_cell)
		var in_kit := range_dist >= int(def["min_range"]) and range_dist <= int(def["max_range"])
		out["in_range"] = in_kit and range_dist <= _HitBands.MAX_DISTANCE
		if bool(def.get("rolls", false)):
			var chance := hit_chance(range_dist)
			if chance >= 0:
				out["hit_chance"] = chance

	var target := _preview_target(to_cell, target_seat, spell_id)
	var notes: Array = []
	if spell_id == SpellKits.ADVANCE:
		notes.append("Dest-click teleport. Exactly 2 cardinal spaces (N/S/E/W). 3 AP / 0 MP. Facing unchanged.")
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
		notes.append("Push 1 along the line. Director Locked Shoulder: walkable empty dest pushes (+1 Impact). Occupied dest is push_blocked (hard body-block). OOB / truly blocked dest bounces + staggers (4 HP; +1 MP if MP>=1) for +2 Impact only (no stack with +1). Lava is hazardous: forced push lands and applies Burn (4 HP at the victim's turn start, duration 2, refresh no stack). Voluntary walk onto lava stays impassable.")

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
		return _advance_stand_reason(from_cell, to_cell)
	if SpellKits.is_gated(spell_id):
		return "open_can_wait"
	var target_kind := str(def.get("target", "enemy"))
	if target_kind == "self":
		if to_cell != actor["pos"]:
			return "no_target"
		return ""
	if target_kind == "empty_tile":
		if not _is_empty(to_cell):
			return "destination_occupied"
		return ""
	if target_kind == "tile":
		return ""
	if target_kind == "cone":
		if not _cone_enemies(actor, true).is_empty():
			return "open_can_wait"
		if _cone_enemies(actor, false).is_empty():
			return "no_target"
		return ""
	if target_kind == "burst":
		if not _burst_enemies(actor, def, true).is_empty():
			return "open_can_wait"
		if _burst_enemies(actor, def, false).is_empty():
			return "no_target"
		return ""
	var ally_cast := target_kind == "ally" or (target_kind == "any" and not target.is_empty() and int(target.get("seat", -1)) == int(actor.get("seat", -2)))
	if ally_cast:
		if target.is_empty() or not bool(target.get("alive", false)) or int(target.get("seat", -1)) != int(actor.get("seat", -2)):
			return "no_target"
		if spell_id == SpellKits.WARD and int(target.get("shield", 0)) > 0:
			return "open_can_wait"
		if spell_id == SpellKits.HEARTSTOP and int(target.get("hit_immunity", 0)) > 0:
			return "open_can_wait"
		return ""
	if target.is_empty() or not bool(target.get("alive", false)) or int(target.get("seat", -1)) == int(actor.get("seat", -2)):
		return "no_target"
	if spell_id == SpellKits.AMBUSH:
		return _ambush_block_reason(actor, target)
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
		SpellKits.AEGIS_BREAK:
			return {"on_connect": "26 Earth per body in range 1–2. Push 1. Clears all Aegis.", "on_miss": "Spends 0 Aegis. Does not clear Aegis."}
		SpellKits.SNAP_WALL:
			return {"on_connect": "Blocked tile for 2 Bastion turn-starts. Spends 2 Aegis.", "on_miss": "No roll."}
		_:
			return {"on_connect": "", "on_miss": ""}


## Locked Phase A damage sample/resolve. CritMult 1.0, Passive 1, Mastery 0.
## WindMod omitted (not invented as 1.0). Resist 0 is Open A05.
func _phase_a_damage(base: int, facing_mult: float) -> int:
	var raw: float = float(base) * CRIT_MULT * PASSIVE * (1.0 + MASTERY / 100.0) * (1.0 - RESIST / 100.0) * facing_mult
	return roundi(raw)


func _make_unit(seat: int, class_id: String, unit_name: String, element: String, pos: Vector2i, facing: String, placed: bool = true) -> Dictionary:
	var in_combat := placed
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
		"ap": MAX_AP if in_combat else 0,
		"mp": MAX_MP if in_combat else 0,
		"max_ap": MAX_AP,
		"max_mp": MAX_MP,
		"marks": 0,
		"impact": 0,
		"marks_cap": SpellKits.MARKS_CAP,
		"impact_cap": SpellKits.IMPACT_CAP,
		# Workbook v0.6 proto: HP 80, Mastery 0, Resist 0. Combat refill stays 6 AP / 3 MP.
		"mastery": 0,
		"resist": 0,
		# Umbral 0–4 is Gloam only. Pulse 0–6 is Mender only. Aegis 0–4 is Bastion only.
		"umbral": 0,
		"umbral_cap": SpellKits.UMBRAL_CAP if class_id == SpellKits.CLASS_GLOAM else 0,
		"pulse": 0,
		"pulse_cap": SpellKits.PULSE_CAP if class_id == SpellKits.CLASS_MENDER else 0,
		"aegis": 0,
		"aegis_cap": SpellKits.AEGIS_CAP if class_id == SpellKits.CLASS_BASTION else 0,
		# shade bool mirrors shades > 0. Tokens live on the board (max 2).
		"shade": false,
		"shades": 0,
		"invisible": false,
		"shield": 0,
		"shield_turns": 0,
		"hit_immunity": 0,
		"skip_next_mp": false,
		"exit_tax": 0,
		"intercept_used": false,
		# Locked Stun (A′): stun_remaining + stunned-this-turn. Blocks move + cast + face.
		"stun_remaining": 0,
		"stunned": false,
		# Director Locked Burn. Duration ticks left; 0 means not burning.
		"burn_remaining": 0,
		"alive": true,
		"placed": placed,
		"locked": false,
		"spells": SpellKits.class_spells(class_id).duplicate(),
	}


func _submit_deploy(intent: Dictionary, kind: String) -> Dictionary:
	match kind:
		"place", "reposition":
			return _submit_place(intent)
		"ready", "confirm":
			return _submit_ready(intent)
		"move", "cast", "face", "end_turn":
			return _reject(intent, "wrong_phase", "REJECT — only place, reposition, or ready during deploy.")
		_:
			return _reject(intent, "unknown_intent", "REJECT — unknown intent.")


func _submit_place(intent: Dictionary) -> Dictionary:
	if not intent.has("seat"):
		return _reject(intent, "missing_seat", "REJECT — place needs a seat.")
	if not intent.has("to"):
		return _reject(intent, "missing_destination", "REJECT — place needs a destination.")
	var seat := int(intent["seat"])
	var dest: Vector2i = intent["to"]
	var gate := _deploy_place_gate(seat, dest)
	if not bool(gate.get("ok", false)):
		return _reject(intent, str(gate.get("reason", "outside_zone")), _deploy_reject_coach(seat, dest, gate))
	var actor := _unit_by_seat(seat)
	if actor.is_empty():
		return _reject(intent, "unknown_unit", "REJECT — unknown seat.")
	var was_placed := bool(actor.get("placed", false))
	var from: Vector2i = actor["pos"]
	actor["pos"] = dest
	actor["placed"] = true
	_flow.mark_placed(seat)
	_intent_log.append(intent)
	if was_placed:
		_last_coach = "%s repositions to %s." % [actor["name"], _cell_text(dest)]
	else:
		_last_coach = "%s places on %s." % [actor["name"], _cell_text(dest)]
	_last_events.append({
		"type": "reposition" if was_placed else "place",
		"seat": seat,
		"from": from,
		"to": dest,
		"repositioned": was_placed,
		"coach": _last_coach,
	})
	return _accept()


func _submit_ready(intent: Dictionary) -> Dictionary:
	if not intent.has("seat"):
		return _reject(intent, "missing_seat", "REJECT — ready needs a seat.")
	var seat := int(intent["seat"])
	var result := _flow.mark_ready(seat)
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "units_not_placed"))
		var coach := "REJECT — place the required fighter before Ready."
		if reason == "already_ready":
			coach = "REJECT — already ready."
		elif reason == "wrong_phase":
			coach = "REJECT — deploy is over."
		return _reject(intent, reason, coach)
	var actor := _unit_by_seat(seat)
	if not actor.is_empty():
		actor["locked"] = true
	_intent_log.append(intent)
	if _flow.is_combat():
		_lock_all_units()
		_begin_combat(_opening_turn_coach("Positions locked."))
		# _begin_combat replaces last_events; prepend the ready that triggered it.
		_last_events.insert(0, {
			"type": "ready",
			"seat": seat,
			"both_ready": true,
			"coach": "%s ready." % str(actor.get("name", "Seat %d" % seat)),
		})
		return _accept()
	_last_coach = "%s ready. Waiting for the other seat." % str(actor.get("name", "Seat %d" % seat))
	_last_events.append({
		"type": "ready",
		"seat": seat,
		"both_ready": false,
		"coach": _last_coach,
	})
	return _accept()


func _legal_deploy_intents(seat: int) -> Array:
	var out: Array = []
	if _flow.is_ready(seat):
		return out
	for cell in legal_deploy_cells(seat):
		out.append({"type": "place", "to": cell, "seat": seat})
	if _flow.can_ready(seat):
		out.append({"type": "ready", "seat": seat})
	return out


func _deploy_reject_coach(seat: int, dest: Vector2i, gate: Dictionary) -> String:
	var reason := str(gate.get("reason", ""))
	var kind := str(gate.get("zone_kind", ""))
	if reason == "out_of_bounds":
		return "REJECT — out of bounds."
	if reason == "occupied":
		return "REJECT — %s is occupied." % _cell_text(dest)
	if reason == "side_locked":
		return "REJECT — this side is already ready."
	if reason == "wrong_phase":
		return "REJECT — deploy is over."
	if reason == "outside_zone":
		if kind == "wrong_zone" or kind == "wrong_half":
			return "REJECT — %s is the other side's deploy zone." % _cell_text(dest)
		return "REJECT — %s is outside this side's deployment zone." % _cell_text(dest)
	if reason == "not_walkable":
		return "REJECT — %s is not walkable." % _cell_text(dest)
	return "REJECT — illegal place (%s)." % reason


func _force_spawn(seat: int, cell: Vector2i) -> void:
	var actor := _unit_by_seat(seat)
	if actor.is_empty():
		return
	actor["pos"] = cell
	actor["placed"] = true
	actor["locked"] = true
	actor["ap"] = MAX_AP
	actor["mp"] = MAX_MP
	_flow.mark_placed(seat)


func _lock_all_units() -> void:
	for unit in _units:
		unit["locked"] = true
		unit["placed"] = true


func _begin_combat(coach: String) -> void:
	_active_seat = 0
	_turn_index = 1
	for unit in _units:
		unit["ap"] = MAX_AP
		unit["mp"] = MAX_MP
		unit["locked"] = true
	_start_turn_timer()
	_last_coach = coach
	_last_events = [{
		"type": "combat_start",
		"phase": _flow.phase_name(),
		"positions_locked": true,
		"coach": coach,
	}, {
		"type": "turn_start",
		"seat": _active_seat,
		"turn": _turn_index,
		"turn_time_remaining": _turn_time_remaining,
		"turn_time_limit": _turn_time_limit,
		"coach": coach,
	}]


func _occupant_seat(cell: Vector2i) -> int:
	for unit in _units:
		if bool(unit.get("placed", false)) and unit["pos"] == cell:
			return int(unit["seat"])
	return -1


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
	_handoff_seat(actor, bool(intent.get("auto", false)), str(intent.get("reason", "")))
	# Locked Stun (A′): if the seat that just started is stunned, auto-resolve
	# end_turn. Tick already ran in _begin_unit_turn, so this is the skipped turn.
	_auto_skip_stunned_turns()
	return _accept()


func _handoff_seat(actor: Dictionary, auto_skip: bool, skip_reason: String = "") -> Dictionary:
	# The seat that is leaving has completed this turn, including a stunned skip.
	# Shades owned by the other seat count that completion toward Ambush arming.
	_note_opponent_shade_turns(int(actor.get("seat", -1)))
	var next_seat := 1 if _active_seat == 0 else 0
	var next_unit := _unit_by_seat(next_seat)
	if next_unit.is_empty() or not next_unit["alive"]:
		_finish_match(_active_seat)
		return {}

	if int(actor.get("exit_tax", 0)) > 0:
		actor["exit_tax"] = int(actor["exit_tax"]) - 1
	_active_seat = next_seat
	_turn_index += 1
	_begin_unit_turn(next_unit)
	next_unit["ap"] = MAX_AP
	next_unit["mp"] = MAX_MP
	if bool(next_unit.get("skip_next_mp", false)):
		next_unit["mp"] = 0
		next_unit["skip_next_mp"] = false
		# Heartstop enemy badge ends when this turn consumes the skip. MP is already 0.
		_emit_expire("skip_next_mp", next_unit["pos"], int(next_unit["seat"]), int(next_unit["seat"]))
	_start_turn_timer()
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
		if skip_reason == "timer":
			end_event["reason"] = "timer"
		else:
			end_event["reason"] = "stunned"
			end_event["locked"] = "Locked Stun (A′) — auto end_turn on turn start"
	_last_events.append(end_event)
	_last_events.append({
		"type": "turn_start",
		"seat": _active_seat,
		"turn": _turn_index,
		"stunned_skip": stunned,
		"turn_time_remaining": _turn_time_remaining,
		"turn_time_limit": _turn_time_limit,
		"coach": _last_coach,
	})
	# Director Locked Burn ticks once this turn has started, including a stunned skip.
	_tick_burn(next_unit)
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
	# Dest-click only. CombatSim expands the cheapest weighted ortho path; ignore client intent.path.
	# Locked: facing follows each ortho hop of that path; final facing = last hop direction.
	# Manual face intent stays for standing turns. Advance teleport does not auto-face.
	# Height does not change facing cones.
	intent.erase("path")
	if not intent.has("to"):
		return _reject(intent, "missing_destination", "REJECT — move needs a destination.")
	var dest: Vector2i = intent["to"]
	var tax := 1 if int(actor.get("exit_tax", 0)) > 0 else 0
	var budget := maxi(int(actor["mp"]) - tax, 0)
	var planned: Dictionary = _board.validate_move(actor["pos"], dest, budget, Callable(self, "_walk_occupied"))
	if not bool(planned.get("ok", false)):
		var reason := str(planned.get("reason", "unreachable"))
		var coach := "REJECT — illegal move (%s)." % reason
		# MP 0 is a walk. Name it so the toast is not read as a failed Ambush.
		if reason == "insufficient_mp" and int(actor.get("mp", 0)) <= 0:
			coach = "REJECT — no MP to walk."
		return _reject(intent, reason, coach)
	var from: Vector2i = actor["pos"]
	var path: Array = planned.get("path", [])
	var dist := int(planned.get("cost", 0))
	var facing_from: String = str(actor["facing"])
	var facing_hops: Array = _face_along_walk(actor, from, path)
	actor["pos"] = dest
	actor["mp"] = int(actor["mp"]) - dist - tax
	_intent_log.append(intent)
	_last_coach = "%s walks to %s (−%d MP)." % [actor["name"], _cell_text(dest), dist + tax]
	_last_events.append({
		"type": "move",
		"seat": actor["seat"],
		"from": from,
		"to": dest,
		"path": path.duplicate(),
		"facing_from": facing_from,
		"facing": str(actor["facing"]),
		"facing_hops": facing_hops.duplicate(),
		"mp_spent": dist + tax,
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
	if SpellKits.is_gated(spell_id):
		return _reject(intent, "open_can_wait", "REJECT — %s is open (can-wait) and is not resolved." % def["name"])
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
			var range_dist := manhattan(actor["pos"], dest)
			return _reject(intent, "out_of_range", "REJECT — Advance is exactly 2 cardinal spaces, target at Manhattan %d (refund)." % range_dist)
		if reason == "insufficient_ap":
			return _reject(intent, "insufficient_ap", "REJECT — Advance costs %d AP (refund)." % advance_ap)
		if reason == "destination_occupied":
			return _reject(intent, "destination_occupied", "REJECT — Advance needs an empty tile (refund).")
		if reason != "":
			return _reject(intent, reason, "REJECT — illegal Advance (%s)." % reason)
		return _resolve_advance(intent, actor, def, dest, advance_ap, advance_mp)

	var range_from: Vector2i = actor["pos"]
	if spell_id == SpellKits.AMBUSH:
		var origin_cell := _ambush_range_origin(actor)
		if origin_cell != UNPLACED:
			range_from = origin_cell
	# Cardinal kits (Ambush) share the axis gate: one of Δx/Δy is 0 and
	# |Δx|+|Δy| is inside min/max (Ambush 1–2). Chebyshev would accept a diagonal.
	var dist := _range_distance(def, range_from, dest)
	if dist < int(def["min_range"]) or dist > int(def["max_range"]):
		return _reject(intent, "out_of_range", "REJECT — %s range %d–%d, target at %d (refund)." % [def["name"], def["min_range"], def["max_range"], dist])
	if dist > _HitBands.MAX_DISTANCE:
		return _reject(intent, "out_of_range", "REJECT — %s Chebyshev %d has no locked hit %% (refund)." % [def["name"], dist])

	var ap_cost := int(def["ap"])
	var mp_cost := int(def["mp"])
	if int(actor["ap"]) < ap_cost:
		return _reject(intent, "insufficient_ap", "REJECT — %s costs %d AP (refund)." % [def["name"], ap_cost])
	if int(actor["mp"]) < mp_cost:
		return _reject(intent, "insufficient_mp", "REJECT — %s costs %d MP (refund)." % [def["name"], mp_cost])
	if spell_id == SpellKits.WARD or spell_id == SpellKits.HEARTSTOP:
		var early := _living_unit_at(dest)
		if not early.is_empty() and int(early["seat"]) == int(actor["seat"]):
			if spell_id == SpellKits.WARD and int(early.get("shield", 0)) > 0:
				return _reject(intent, "open_can_wait", "REJECT — shield stacking is open (can-wait).")
			if spell_id == SpellKits.HEARTSTOP and int(early.get("hit_immunity", 0)) > 0:
				return _reject(intent, "open_can_wait", "REJECT — immunity refresh is open (can-wait).")
	var resource_gate := _resource_gate(actor, def)
	if resource_gate != "":
		return _reject(intent, resource_gate, "REJECT — %s failed gate %s (refund)." % [def["name"], resource_gate])

	var target_kind := str(def.get("target", "enemy"))
	if target_kind == "empty_tile":
		return _resolve_empty_tile(intent, actor, def, dest, ap_cost, mp_cost)
	if target_kind == "tile":
		return _resolve_plant(intent, actor, def, dest, ap_cost, mp_cost)
	if target_kind == "self":
		if dest != actor["pos"]:
			return _reject(intent, "no_target", "REJECT — %s is self only (refund)." % def["name"])
		return _resolve_fade(intent, actor, def, ap_cost, mp_cost)
	if target_kind == "cone":
		return _resolve_hold_line(intent, actor, def, ap_cost, mp_cost)
	if target_kind == "burst":
		return _resolve_aegis_break(intent, actor, def, dest, dist, ap_cost, mp_cost)
	if spell_id == SpellKits.AMBUSH:
		var ambush_target := _living_unit_at(dest)
		if ambush_target.is_empty() or int(ambush_target["seat"]) == int(actor["seat"]):
			return _reject(intent, "no_target", "REJECT — Ambush needs an enemy (refund).")
		return _resolve_ambush(intent, actor, ambush_target, def, dest, dist, ap_cost, mp_cost)

	var target := _living_unit_at(dest)
	if target.is_empty():
		return _reject(intent, "no_target", "REJECT — %s needs a living unit (refund)." % def["name"])
	var support := target_kind == "ally" or (target_kind == "any" and int(target["seat"]) == int(actor["seat"]))
	if support:
		if target_kind == "ally" and int(target["seat"]) != int(actor["seat"]):
			return _reject(intent, "no_target", "REJECT — %s needs an ally (refund)." % def["name"])
		return _resolve_support(intent, actor, target, def, dest, dist, ap_cost, mp_cost)
	if int(target["seat"]) == int(actor["seat"]):
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
	var caster_cell: Vector2i = actor["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var chance: int = hit_chance(dist)
	var roll: int = _roll_d100()
	var connected: bool = roll <= chance
	var facing_mult: float = _facing_multiplier(actor["pos"], target["pos"], str(target["facing"]))
	var is_back: bool = facing_mult > FRONT_SIDE_FACING + 0.001
	if str(actor.get("class_id", "")) == SpellKits.CLASS_GLOAM and is_back:
		facing_mult = SpellKits.BACKSTAB_MULT
	var spell_id := str(def["id"])
	var marks_on_target: int = int(target.get("marks", 0))
	var impact_before: int = int(actor.get("impact", 0))
	_intent_log.append(intent)

	if not connected:
		_last_coach = "MISS — %d AP gone (%d vs %d%%, range %d)." % [ap_cost, roll, chance, dist]
		var miss_event: Dictionary = {
			"type": "miss",
			"seat": actor["seat"],
			"spell": spell_id,
			"caster_cell": caster_cell,
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
	var pre_mitigation := _phase_a_damage(base, facing_mult)
	var mitigation := _mitigate_hit(actor, target, pre_mitigation)
	var damage := int(mitigation["damage"])
	target["hp"] = int(target["hp"]) - damage
	if int(target["hp"]) < 0:
		target["hp"] = 0
	var engine_gained := 0
	var engine_spent := 0
	var engine_name := ""
	var marks_consumed := 0
	var defer_shoulder_impact := false
	match str(def["engine_on_connect"]):
		"impact":
			if spell_id == SpellKits.SHOULDER:
				# Amount depends on the push. Bounce is +2 only, not +1 stacked with +2.
				defer_shoulder_impact = true
				engine_name = "Impact"
			else:
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
		"umbral":
			engine_gained = _gain_resource(actor, "umbral", 1)
			engine_name = "Umbral"
		"aegis":
			engine_gained = _gain_resource(actor, "aegis", 1)
			engine_name = "Aegis"
		"pulse":
			engine_gained = _gain_resource(actor, "pulse", 1)
			engine_name = "Pulse"
		"spend_pulse":
			engine_spent = _spend_resource(actor, "pulse", int(def.get("spend_pulse", 1)))
			engine_name = "Pulse"
		"clear_aegis":
			engine_spent = _clear_resource(actor, "aegis")
			engine_name = "Aegis"

	var skip_next_mp := false
	if bool(def.get("enemy_skip_mp", false)):
		target["skip_next_mp"] = true
		skip_next_mp = true
	var stun_applied := 0
	if spell_id == SpellKits.CRUSH and impact_before >= int(def.get("stun_if_impact_before", 4)):
		# Locked Stun (A′): Stun 1 if Impact was 4 before the spend. Blocks move + cast + face.
		stun_applied = _apply_stun(target, int(def.get("stun_remaining", 1)))

	var push_result := {}
	if int(def.get("push_cells", 0)) > 0:
		# Director Locked Shoulder: occupied = push_blocked; OOB / truly blocked = bounce + stagger.
		# Lava is hazardous: displace and Burn. Walkable empty dest still pushes.
		push_result = _try_push(actor["pos"], target, int(def["push_cells"]))
	if defer_shoulder_impact:
		var impact_amount := SHOULDER_CONNECT_IMPACT
		if bool(push_result.get("bounced", false)):
			impact_amount = SHOULDER_BOUNCE_IMPACT
		engine_gained = _gain_impact(actor, impact_amount)
	var burn_info := {}
	if bool(push_result.get("burn", false)):
		burn_info = _apply_burn(target)

	var facing_note := "front/side ×1.00"
	if is_back:
		facing_note = "BACK ×1.35" if str(actor.get("class_id", "")) == SpellKits.CLASS_GLOAM else "BACK ×1.20"
	var extra_note := _connect_extra_note(engine_gained, engine_name, marks_consumed, engine_spent, stun_applied, push_result)
	_last_coach = "HIT %d %s — %s vs %s (%d vs %d%%) %s.%s" % [damage, str(def["element"]).capitalize(), def["name"], target["name"], roll, chance, facing_note, extra_note]
	var hit_event := {
		"type": "hit",
		"seat": actor["seat"],
		"spell": spell_id,
		"caster_cell": caster_cell,
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
		hit_event["push_attempted"] = push_result.get("attempted")
		hit_event["push_blocked"] = bool(push_result.get("blocked", false))
		hit_event["push_block_reason"] = str(push_result.get("reason", "")) if bool(push_result.get("blocked", false)) else ""
		hit_event["bounced"] = bool(push_result.get("bounced", false))
		hit_event["staggered"] = bool(push_result.get("staggered", false))
		hit_event["bounce_reason"] = str(push_result.get("reason", "")) if bool(push_result.get("bounced", false)) else ""
		hit_event["stagger_hp"] = int(push_result.get("stagger_hp", 0))
		hit_event["stagger_mp"] = int(push_result.get("stagger_mp", 0))
		hit_event["hp_delta"] = int(push_result.get("hp_delta", 0))
		hit_event["mp_delta"] = int(push_result.get("mp_delta", 0))
		hit_event["burn_applied"] = not burn_info.is_empty()
		if not burn_info.is_empty():
			hit_event["burn_refreshed"] = bool(burn_info.get("refreshed", false))
			hit_event["burn_remaining"] = int(burn_info.get("remaining", 0))
	if skip_next_mp:
		hit_event["skip_next_mp"] = true
	_stamp_mitigation(hit_event, mitigation)
	_last_events.append(hit_event)
	if bool(push_result.get("blocked", false)):
		_last_events.append({
			"type": "push_blocked",
			# Occupied dest is a hard body-block — no bounce, no stagger.
			"locked": "Director Locked Shoulder — occupied dest is hard body-block (push_blocked)",
			"seat": actor["seat"],
			"target_seat": target["seat"],
			"from": push_result.get("from"),
			"attempted": push_result.get("attempted"),
			"reason": str(push_result.get("reason", "")),
			"coach": "Push blocked (occupied). Hard body-block — no bounce, no stagger.",
		})
	if bool(push_result.get("bounced", false)):
		var mp_note := ""
		if int(push_result.get("stagger_mp", 0)) > 0:
			mp_note = " / %d MP" % int(push_result.get("stagger_mp", 0))
		_last_events.append({
			"type": "push_bounce",
			"locked": "Director Locked Shoulder — OOB / truly blocked bounce + stagger (+2 Impact)",
			"seat": actor["seat"],
			"target_seat": target["seat"],
			"from": push_result.get("from"),
			"attempted": push_result.get("attempted"),
			"to": push_result.get("to"),
			"reason": str(push_result.get("reason", "")),
			"staggered": true,
			"hp_delta": int(push_result.get("hp_delta", 0)),
			"mp_delta": int(push_result.get("mp_delta", 0)),
			"stagger_hp": int(push_result.get("stagger_hp", 0)),
			"stagger_mp": int(push_result.get("stagger_mp", 0)),
			"coach": "Bounce (%s) + stagger %d HP%s." % [
				str(push_result.get("reason", "")),
				int(push_result.get("stagger_hp", 0)),
				mp_note,
			],
		})
		var stagger_mp_note := ""
		if int(push_result.get("stagger_mp", 0)) > 0:
			stagger_mp_note = ", %d MP" % int(push_result.get("stagger_mp", 0))
		_last_events.append({
			"type": "stagger",
			"locked": "Director Locked Shoulder — stagger 4 HP + 1 MP if MP>=1",
			"target_seat": target["seat"],
			"hp_delta": int(push_result.get("hp_delta", 0)),
			"mp_delta": int(push_result.get("mp_delta", 0)),
			"stagger_hp": int(push_result.get("stagger_hp", 0)),
			"stagger_mp": int(push_result.get("stagger_mp", 0)),
			"hp": int(target["hp"]),
			"mp": int(target["mp"]),
			"reason": str(push_result.get("reason", "")),
			"coach": "%s staggers (%d HP%s)." % [
				target["name"],
				int(push_result.get("stagger_hp", 0)),
				stagger_mp_note,
			],
		})
	if not burn_info.is_empty():
		var burn_coach := "%s is burning (%d HP at turn start, duration %d)." % [target["name"], BURN_HP, BURN_DURATION]
		if bool(burn_info.get("refreshed", false)):
			burn_coach = "%s's Burn refreshes to %d (no stack)." % [target["name"], BURN_DURATION]
		_last_events.append({
			"type": "status",
			"status": "burn",
			"remaining": int(burn_info.get("remaining", BURN_DURATION)),
			"duration": BURN_DURATION,
			"hp_per_tick": BURN_HP,
			"refreshed": bool(burn_info.get("refreshed", false)),
			"previous": int(burn_info.get("previous", 0)),
			"target_seat": target["seat"],
			"locked": "Director Locked Burn — 4 HP at turn start, duration 2, refresh no stack",
			"coach": burn_coach,
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
	_emit_immunity_spent(target, mitigation)
	_check_death(target)
	return _accept()


## Reached only after an existing HP loss. cause names that path for the view.
## "damage" is a spell hit, Hold Line, Ambush, or an Intercept transfer.
## "burn" is a Director Locked Burn tick. Stagger does not call this.
## There is no separate execute path.
func _check_death(target: Dictionary, cause: String = "damage") -> void:
	if int(target["hp"]) > 0:
		return
	target["alive"] = false
	_last_events.append({
		"type": "dead",
		"seat": target["seat"],
		"name": target["name"],
		"cause": cause,
		"coach": "%s falls." % target["name"],
	})
	_finish_match(_enemy_of(int(target["seat"]))["seat"])


func _finish_match(winner: int) -> void:
	_match_over = true
	_winner_seat = winner
	_stop_turn_timer()
	var winner_unit := _unit_by_seat(winner)
	var winner_name := str(winner_unit.get("name", "Seat %d" % winner))
	_last_coach = "Match over. %s wins." % winner_name
	_last_events.append({
		"type": "match_over",
		"winner_seat": winner,
		"coach": _last_coach,
	})


func _validate_walk(actor: Dictionary, dest: Vector2i) -> String:
	var planned: Dictionary = _board.validate_move(actor["pos"], dest, int(actor["mp"]), Callable(self, "_walk_occupied"))
	if bool(planned.get("ok", false)):
		return ""
	return str(planned.get("reason", "unreachable"))


func _validate_advance(actor: Dictionary, dest: Vector2i) -> String:
	if str(actor.get("class_id", "")) != SpellKits.CLASS_IRONJAW:
		return "spell_not_in_kit"
	if not _in_bounds(dest):
		return "out_of_bounds"
	if dest == actor["pos"]:
		return "same_tile"
	# Range gate is exactly 2 cardinal spaces (N/S/E/W at Manhattan 2).
	# Manhattan 1, diagonals, and any non-cardinal are out of range.
	# Teleport: shared walk stand-on gates at dest. 0 MP is legal.
	# No terrain+elev MP spend — gate only. The tile between is not a path.
	if not is_advance_cardinal(actor["pos"], dest):
		return "out_of_range"
	var def: Dictionary = SpellKits.spell(SpellKits.ADVANCE)
	var range_dist := _range_distance(def, actor["pos"], dest)
	if range_dist < int(def["min_range"]) or range_dist > int(def["max_range"]):
		return "out_of_range"
	if int(actor["ap"]) < int(def["ap"]):
		return "insufficient_ap"
	return _advance_stand_reason(actor["pos"], dest)


func _advance_stand_reason(from: Vector2i, dest: Vector2i) -> String:
	var gate: Dictionary = _board.stand_on_gate(from, dest, Callable(self, "_walk_occupied"))
	if bool(gate.get("ok", false)):
		return ""
	var reason := str(gate.get("reason", "not_walkable"))
	if reason == "occupied":
		return "destination_occupied"
	return reason


func _range_distance(def: Dictionary, from: Vector2i, to: Vector2i) -> int:
	var mode := str(def.get("range_mode", "chebyshev"))
	# Cardinal is axis-only (Ambush 1–2, Advance exactly 2). A knight
	# such as (2,1) has both axes nonzero, so it is not in range. The sentinel
	# stays above every kit max and the hit-band cap.
	if mode == "cardinal":
		var axis := _cardinal_axis_len(from, to)
		if axis < 0:
			return _HitBands.MAX_DISTANCE + 1
		return axis
	if mode == "manhattan":
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


func _deploy_place_gate(seat: int, cell: Vector2i) -> Dictionary:
	if _snap_wall_blocks(cell):
		return {"ok": false, "reason": "occupied", "zone_kind": ""}
	var gate := _flow.place_gate(seat, cell, _occupant_seat(cell))
	if not bool(gate.get("ok", false)):
		return gate
	# Deploy: occupancy + walkable (lava / override). No elevation MP / climb cost.
	if not _board.is_walkable(cell):
		return {"ok": false, "reason": "not_walkable", "zone_kind": ""}
	return gate


func _seed_play_board(config: Dictionary) -> void:
	# flat_board: Ground z0. Proto 8: crop + noise. Proto 12: Mauro tokens.
	# Ship 15: Koliseo tags when the file size matches. Empty map_id is Crosshaven.
	# paint_only stays visual. An explicit cell_tags path uses the same hook.
	if bool(config.get("flat_board", false)):
		return
	if _board_size == _BoardSize.PROTO:
		var noise_elev := _wants_noise_elev(config)
		_MatchFlow.seed_phase_a_demo(_board, _elev_seed, noise_elev)
		_demo_map = _MatchFlow.PHASE_A_DEMO_MAP
		_map_id = _demo_map
		_elevation_gen = "seeded_noise" if noise_elev else "crop"
		return
	if _board_size == _BoardSize.PROTO_12:
		_MatchFlow.seed_mauro_12(_board)
		_map_id = _MatchFlow.MAURO_PROTO_MAP
		_demo_map = _map_id
		_elevation_gen = "mauro"
		return
	var tags_path := str(config.get("cell_tags", ""))
	if tags_path == "" and _board_size == _BoardSize.SHIP:
		tags_path = _CellTagMap.tags_path_for(str(config.get("map_id", "")))
	if tags_path == "":
		return
	var tags: Dictionary = _CellTagMap.load_file(tags_path)
	if not _CellTagMap.apply(_board, tags):
		return
	_paint_only = (tags.get("paint_only", {}) as Dictionary).duplicate(true)
	_map_id = str(tags.get("map_id", ""))
	_demo_map = _map_id
	_elevation_gen = "tags"


func _paint_only_snapshot() -> Dictionary:
	var out := {}
	for key in _paint_only.keys():
		var props: Variant = _paint_only[key]
		if props is Array:
			out[key] = (props as Array).duplicate()
	return out


func _paint_only_from_snap(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var paint: Dictionary = raw
	for key in paint.keys():
		var cell: Vector2i = key if key is Vector2i else _as_cell(key)
		var props: Variant = paint[key]
		if props is Array:
			out[cell] = (props as Array).duplicate()
	return out


func _wants_demo_map(config: Dictionary) -> bool:
	# Proto crop helper. The ship Crosshaven map does not use this flag.
	if config.has("demo_map"):
		return bool(config["demo_map"])
	if bool(config.get("flat_board", false)):
		return false
	return _board_size == _BoardSize.PROTO


func _wants_noise_elev(config: Dictionary) -> bool:
	# Default: regenerate z from elev_seed / seed. Fixtures may pin crop z or skip.
	if bool(config.get("flat_board", false)):
		return false
	if config.has("noise_elev"):
		return bool(config["noise_elev"])
	if bool(config.get("crop_elev", false)):
		return false
	return true


func _apply_tile_overrides(config: Dictionary) -> void:
	if not config.has("tiles"):
		return
	var painted: Variant = config["tiles"]
	if painted is Dictionary:
		for key in painted.keys():
			_paint_tile_entry(_as_cell(key), painted[key])
		return
	if painted is Array:
		for entry in painted:
			if entry is Dictionary:
				_paint_tile_entry(_as_cell(entry.get("pos", entry.get("cell", Vector2i.ZERO))), entry)


func _paint_tile_entry(cell: Vector2i, entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var terrain: Variant = entry.get("terrain", entry.get("terrain_type", _TerrainDef.Id.GROUND))
	var elevation := _ElevationCost.as_z(entry.get("elevation", 0))
	var walkable_override: Variant = entry.get("walkable", entry.get("walkable_override", null))
	_board.set_tile(cell, terrain, elevation, walkable_override)


func _walk_occupied(cell: Vector2i, ignore: Vector2i) -> bool:
	if cell == ignore:
		return false
	return not _is_empty(cell)


func _apply_setup_overrides(config: Dictionary) -> void:
	# Test/setup hooks only. Not a play default — matches start at 0 Marks/Impact/stun.
	# Keys still name the class. The first seat of that class receives them.
	for class_id in SpellKits.LOCKED_ROSTER:
		_apply_class_setup(config, "%s_marks" % class_id, class_id, "marks")
		_apply_class_setup(config, "%s_impact" % class_id, class_id, "impact")
		_apply_class_setup(config, "%s_stun" % class_id, class_id, "stun_remaining")
		_apply_class_setup(config, "%s_aegis" % class_id, class_id, "aegis")
		_apply_class_setup(config, "%s_umbral" % class_id, class_id, "umbral")
		_apply_class_setup(config, "%s_pulse" % class_id, class_id, "pulse")
		_apply_class_setup(config, "%s_hp" % class_id, class_id, "hp")
		_apply_class_setup(config, "%s_hit_immunity" % class_id, class_id, "hit_immunity")
		_apply_bool_setup(config, "%s_shade" % class_id, class_id, "shade")
		_apply_bool_setup(config, "%s_invisible" % class_id, class_id, "invisible")
	if config.has("blockers"):
		for cell in config["blockers"]:
			_blocked_cells.append(_as_cell(cell))
	if config.has("snap_walls"):
		var wall_owner := -1
		var bastion := _first_unit_of_class(SpellKits.CLASS_BASTION)
		if not bastion.is_empty():
			wall_owner = int(bastion["seat"])
		for cell in config["snap_walls"]:
			_add_snap_wall(_as_cell(cell), 2, wall_owner)


func _apply_bool_setup(config: Dictionary, key: String, class_id: String, field: String) -> void:
	if not config.has(key):
		return
	var unit := _first_unit_of_class(class_id)
	if unit.is_empty():
		return
	unit[field] = bool(config[key])


func _apply_class_setup(config: Dictionary, key: String, class_id: String, field: String) -> void:
	if not config.has(key):
		return
	var unit := _first_unit_of_class(class_id)
	if unit.is_empty():
		return
	var value := int(config[key])
	if field == "stun_remaining" or field == "hit_immunity":
		unit[field] = maxi(value, 0)
		return
	if field == "hp":
		unit["hp"] = mini(maxi(value, 0), int(unit.get("max_hp", START_HP)))
		return
	var cap := int(unit.get("%s_cap" % field, value))
	unit[field] = mini(maxi(value, 0), cap)


func _roster_class_ids(config: Dictionary) -> Array[String]:
	var fallback: Array[String] = [SpellKits.CLASS_KESTREL, SpellKits.CLASS_IRONJAW]
	var raw: Variant = null
	if config.has("classes"):
		raw = config["classes"]
	elif config.has("seat_classes"):
		raw = config["seat_classes"]
	var incoming: Array = []
	if raw is Array:
		incoming = raw
	elif raw is Dictionary:
		var keyed: Dictionary = raw
		incoming = [keyed.get(0, keyed.get("0", "")), keyed.get(1, keyed.get("1", ""))]
	else:
		return fallback
	if incoming.size() < 2:
		return fallback
	var out: Array[String] = []
	for i in 2:
		var id := SpellKits.normalize_class_id(str(incoming[i]))
		if not SpellKits.is_roster_class(id):
			return fallback
		out.append(id)
	return out


func _facing_for(config: Dictionary, class_id: String, facing_used: Dictionary) -> String:
	var key := ""
	if class_id == SpellKits.CLASS_KESTREL:
		key = "kestrel_facing"
	elif class_id == SpellKits.CLASS_IRONJAW:
		key = "ironjaw_facing"
	if key != "" and config.has(key) and not bool(facing_used.get(key, false)):
		facing_used[key] = true
		return str(config[key])
	if class_id == SpellKits.CLASS_IRONJAW:
		return "W"
	return "E"


func _spawn_cell_for(config: Dictionary, seat: int, class_id: String, class_pos_used: Dictionary) -> Vector2i:
	if config.has("positions"):
		var positions: Variant = config["positions"]
		if positions is Array and (positions as Array).size() > seat:
			return _as_cell((positions as Array)[seat])
	var key := ""
	if class_id == SpellKits.CLASS_KESTREL:
		key = "kestrel_pos"
	elif class_id == SpellKits.CLASS_IRONJAW:
		key = "ironjaw_pos"
	if key != "" and config.has(key) and not bool(class_pos_used.get(key, false)):
		class_pos_used[key] = true
		return _as_cell(config[key])
	if seat == 0:
		return Vector2i(1, 1)
	return Vector2i(6, 6)


func _first_unit_of_class(class_id: String) -> Dictionary:
	for unit in _units:
		if str(unit.get("class_id", "")) == class_id:
			return unit
	return {}


func _class_ids() -> Array:
	var ids: Array = []
	for unit in _units:
		ids.append(str(unit.get("class_id", "")))
	return ids


func _opening_turn_coach(lead: String) -> String:
	var actor := _unit_by_seat(0)
	var who := str(actor.get("name", "Kestrel"))
	if lead == "":
		return "%s's turn. 6 AP / 3 MP." % who
	return "%s %s's turn. 6 AP / 3 MP." % [lead, who]


func _begin_unit_turn(unit: Dictionary) -> void:
	# Locked Stun (A′): decrement stun at start of that unit's turn.
	# Stun 1 must cover this incoming (skipped) turn. Decrementing remaining and
	# then checking remaining would expire Stun 1 before the auto end_turn.
	# Set stunned-this-turn from remaining>0, then decrement remaining.
	var remaining := int(unit.get("stun_remaining", 0))
	var was_stunned := bool(unit.get("stunned", false))
	unit["stunned"] = remaining > 0
	if remaining > 0:
		unit["stun_remaining"] = remaining - 1
	elif was_stunned:
		# Stun 1 covers the skipped turn. The effect ends on the next turn start.
		_emit_expire("stun", unit["pos"], int(unit["seat"]), int(unit["seat"]))
	# Shade / Plant / Snap Wall share the owner turn-start clock. An enemy
	# turn-start must not burn a duration turn (Mauro: Shade must read as 3).
	_decay_board_durations(unit)
	_tick_snap_walls(unit)
	_tick_shield(unit)
	if str(unit.get("class_id", "")) == SpellKits.CLASS_BASTION:
		unit["intercept_used"] = false


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
		parts.append(" +%d %s." % [engine_gained, engine_name])
	if marks_consumed > 0:
		parts.append(" Marks consumed (%d)." % marks_consumed)
	if engine_spent > 0 and engine_name == "Impact":
		parts.append(" Impact spent (%d)." % engine_spent)
	if engine_spent > 0 and engine_name == "Aegis":
		parts.append(" Aegis cleared (%d)." % engine_spent)
	if engine_spent > 0 and engine_name == "Pulse":
		parts.append(" Pulse spent (%d)." % engine_spent)
	if stun_applied > 0:
		parts.append(" Stun %d (Locked A′)." % stun_applied)
	if not push_result.is_empty():
		if bool(push_result.get("blocked", false)):
			parts.append(" Push blocked (occupied — hard body-block).")
		elif bool(push_result.get("bounced", false)):
			var mp_bit := ""
			if int(push_result.get("stagger_mp", 0)) > 0:
				mp_bit = " + %d MP" % int(push_result.get("stagger_mp", 0))
			parts.append(" Bounce (%s) + stagger %d HP%s." % [
				str(push_result.get("reason", "")),
				int(push_result.get("stagger_hp", 0)),
				mp_bit,
			])
		elif bool(push_result.get("moved", false)):
			parts.append(" Pushed to %s." % _cell_text(push_result["to"]))
			if bool(push_result.get("burn", false)):
				parts.append(" Burn %d HP for %d turns." % [BURN_HP, BURN_DURATION])
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
	# Chebyshev push 1 along the caster→target line.
	# Director Locked Shoulder:
	# - occupied dest: push_blocked (no bounce, no stagger)
	# - lava dest: hazardous, not a wall — displace and flag Burn
	# - OOB / truly blocked (not lava): bounce + stagger
	# - walkable empty: push
	# Do not invent climb/drop push rules. Voluntary walk still rejects lava.
	var from: Vector2i = target["pos"]
	var dest := push_destination(caster_pos, from, cells)
	var result := {
		"from": from,
		"to": from,
		"attempted": dest,
		"moved": false,
		"blocked": false,
		"bounced": false,
		"staggered": false,
		"burn": false,
		"reason": "",
		"stagger_hp": 0,
		"stagger_mp": 0,
		"hp_delta": 0,
		"mp_delta": 0,
	}
	if _consume_plant_resist(target):
		result["blocked"] = true
		result["reason"] = "plant_resist"
		return result
	if not _in_bounds(dest):
		return _apply_bounce_stagger(target, result, "out_of_bounds")
	if not _is_empty(dest):
		result["blocked"] = true
		result["reason"] = "occupied"
		return result
	if _is_lava(dest):
		target["pos"] = dest
		result["to"] = dest
		result["moved"] = true
		result["burn"] = true
		result["reason"] = "lava"
		return result
	if not _board.is_walkable(dest):
		return _apply_bounce_stagger(target, result, _unwalkable_push_reason(dest))
	target["pos"] = dest
	result["to"] = dest
	result["moved"] = true
	return result


func _is_lava(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	var terrain: Dictionary = _board.terrain_of(cell)
	return int(terrain.get("id", _TerrainDef.Id.GROUND)) == _TerrainDef.Id.LAVA


func _apply_burn(unit: Dictionary) -> Dictionary:
	# Re-apply refreshes duration to 2. Do not add durations or stack tick damage.
	var previous := int(unit.get("burn_remaining", 0))
	unit["burn_remaining"] = BURN_DURATION
	return {
		"applied": true,
		"refreshed": previous > 0,
		"previous": previous,
		"remaining": BURN_DURATION,
		"hp_per_tick": BURN_HP,
	}


func _tick_burn(unit: Dictionary) -> void:
	# 4 HP at the start of this unit's turn. Leaving lava does not clear it.
	if unit.is_empty() or not bool(unit.get("alive", false)):
		return
	var remaining := int(unit.get("burn_remaining", 0))
	if remaining <= 0:
		return
	var lost := BURN_HP
	unit["hp"] = maxi(0, int(unit["hp"]) - lost)
	unit["burn_remaining"] = remaining - 1
	var left := int(unit["burn_remaining"])
	_last_events.append({
		"type": "burn",
		"status": "burn",
		"target_seat": int(unit["seat"]),
		"hp_delta": -lost,
		"damage": lost,
		"hp": int(unit["hp"]),
		"remaining": left,
		"duration": BURN_DURATION,
		"locked": "Director Locked Burn — 4 HP at start of turn, duration 2",
		"coach": "%s burns for %d HP (%d tick%s left)." % [
			str(unit.get("name", "Unit")),
			lost,
			left,
			"" if left == 1 else "s",
		],
	})
	_check_death(unit, "burn")


func _unwalkable_push_reason(dest: Vector2i) -> String:
	var terrain: Dictionary = _board.terrain_of(dest)
	if int(terrain.get("id", _TerrainDef.Id.GROUND)) == _TerrainDef.Id.LAVA:
		return "lava"
	return "not_walkable"


func _apply_bounce_stagger(target: Dictionary, result: Dictionary, reason: String) -> Dictionary:
	# Bounce: unit stays/returns. Stagger: 4 HP; +1 MP only when current MP >= 1.
	result["bounced"] = true
	result["staggered"] = true
	result["reason"] = reason
	result["to"] = result["from"]
	var hp_lost := STAGGER_HP
	var mp_lost := 0
	if int(target.get("mp", 0)) >= STAGGER_MP:
		mp_lost = STAGGER_MP
		target["mp"] = int(target["mp"]) - mp_lost
	target["hp"] = maxi(0, int(target["hp"]) - hp_lost)
	result["stagger_hp"] = hp_lost
	result["stagger_mp"] = mp_lost
	result["hp_delta"] = -hp_lost
	result["mp_delta"] = -mp_lost
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


func _start_turn_timer() -> void:
	_turn_time_limit = TURN_TIME_LIMIT
	_turn_time_remaining = TURN_TIME_LIMIT
	_turn_time_running = not _match_over and not _flow.is_deployment()


func _stop_turn_timer() -> void:
	_turn_time_running = false
	_turn_time_remaining = 0.0
	_turn_time_limit = TURN_TIME_LIMIT


func _timer_tick_result(expired: bool) -> Dictionary:
	return {
		"ok": true,
		"expired": expired,
		"illegal": false,
		"reason": "",
		"events": [],
		"snapshot": snapshot(),
	}


static func _clock_display_seconds(remaining: float) -> int:
	if remaining <= 0.0:
		return 0
	return int(ceili(remaining))


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
		if not bool(unit.get("placed", true)):
			continue
		if unit["pos"] == cell and unit["alive"]:
			return unit
	return {}


func _cell_list(cells: Array[Vector2i]) -> Array:
	var out: Array = []
	for cell in cells:
		out.append(cell)
	return out


func _resource_gate(actor: Dictionary, def: Dictionary) -> String:
	if int(def.get("requires_aegis", 0)) > int(actor.get("aegis", 0)):
		return "insufficient_aegis"
	if int(def.get("requires_pulse", 0)) > int(actor.get("pulse", 0)):
		return "insufficient_pulse"
	if int(def.get("requires_umbral", 0)) > int(actor.get("umbral", 0)):
		return "insufficient_umbral"
	var spell_id := str(def.get("id", ""))
	if spell_id == SpellKits.DROP_SHADE and _shade_count(actor) >= SpellKits.SHADE_CAP:
		return "shade_cap"
	if spell_id == SpellKits.AMBUSH and not bool(actor.get("invisible", false)) and _shade_count(actor) <= 0:
		return "no_shade"
	return ""


func _in_spell_range(def: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var dist := _range_distance(def, from_cell, to_cell)
	if dist > _HitBands.MAX_DISTANCE:
		return false
	return dist >= int(def.get("min_range", 0)) and dist <= int(def.get("max_range", 0))


func _append_ranged_cells(out: Array, actor: Dictionary, def: Dictionary, spell_id: String, empty_only: bool) -> void:
	var from_cell: Vector2i = actor["pos"]
	var seat := int(actor["seat"])
	for y in range(_board_size):
		for x in range(_board_size):
			var cell := Vector2i(x, y)
			if not _in_spell_range(def, from_cell, cell):
				continue
			if empty_only and (not _is_empty(cell) or not _board.is_walkable(cell)):
				continue
			out.append({"type": "cast", "spell": spell_id, "to": cell, "seat": seat})


func _facing_step(actor: Dictionary) -> Vector2i:
	var facing := str(actor.get("facing", "E"))
	if FACING_VEC.has(facing):
		return FACING_VEC[facing]
	return Vector2i.ZERO


func _cone_cells(actor: Dictionary) -> Array[Vector2i]:
	var facing := _facing_step(actor)
	var perp := Vector2i(-facing.y, facing.x)
	var origin: Vector2i = actor["pos"]
	return [origin + facing, origin + facing + perp, origin + facing - perp]


func _cone_payload(actor: Dictionary) -> Array:
	var out: Array = []
	for cell in _cone_cells(actor):
		out.append(cell)
	return out


func _hold_line_miss_rows(bodies: Array) -> Array:
	var rows: Array = []
	for body in bodies:
		var target: Dictionary = body
		rows.append({
			"target_seat": int(target["seat"]),
			"cell": target["pos"],
			"hit": false,
			"damage": 0,
			"exit_tax": int(target.get("exit_tax", 0)),
		})
	return rows


## Enemies standing in the spell's Chebyshev range band. That band is the
## Locked Aegis Break burst (card range 1–2, "per body"). invisible_only
## selects invisible enemies; otherwise visible enemies only.
func _burst_enemies(actor: Dictionary, def: Dictionary, invisible_only: bool) -> Array:
	var out: Array = []
	var origin: Vector2i = actor["pos"]
	var lo := int(def.get("min_range", 1))
	var hi := int(def.get("max_range", 2))
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var cell := Vector2i(x, y)
			var dist := chebyshev(origin, cell)
			if dist < lo or dist > hi:
				continue
			var unit := _living_unit_at(cell)
			if unit.is_empty() or int(unit["seat"]) == int(actor["seat"]):
				continue
			var invisible := bool(unit.get("invisible", false))
			if invisible_only == invisible:
				out.append(unit)
	return out


func _aegis_break_miss_rows(bodies: Array) -> Array:
	var rows: Array = []
	for body in bodies:
		var target: Dictionary = body
		rows.append({
			"target_seat": int(target["seat"]),
			"cell": target["pos"],
			"hit": false,
			"damage": 0,
			"pushed": false,
		})
	return rows


## invisible_only selects invisible enemies. Otherwise visible enemies only.
func _cone_enemies(actor: Dictionary, invisible_only: bool) -> Array:
	var out: Array = []
	for cell in _cone_cells(actor):
		if not _in_bounds(cell):
			continue
		var unit := _living_unit_at(cell)
		if unit.is_empty() or int(unit["seat"]) == int(actor["seat"]):
			continue
		var invisible := bool(unit.get("invisible", false))
		if invisible_only == invisible:
			out.append(unit)
	return out


func _gain_resource(unit: Dictionary, field: String, amount: int) -> int:
	var cap_key := "%s_cap" % field
	if not unit.has(cap_key):
		return 0
	var cap := int(unit[cap_key])
	if cap <= 0 or amount <= 0:
		return 0
	var before := int(unit.get(field, 0))
	unit[field] = mini(before + amount, cap)
	return int(unit[field]) - before


func _spend_resource(unit: Dictionary, field: String, amount: int) -> int:
	var before := int(unit.get(field, 0))
	var spent := mini(before, maxi(amount, 0))
	unit[field] = before - spent
	return spent


func _clear_resource(unit: Dictionary, field: String) -> int:
	var before := int(unit.get(field, 0))
	unit[field] = 0
	return before


## Immunity consumes the hit (damage 0, shield untouched). Then one adjacent
## same-seat Bastion may take 40% once. Shield absorbs the rest. Zero shield
## and zero immunity leave the formula damage unchanged.
## The returned damage is the HP actually lost. The other keys only describe it.
func _mitigate_hit(actor: Dictionary, target: Dictionary, damage: int) -> Dictionary:
	var report := {
		"damage": damage,
		"immunity_absorbed": false,
		"immunity_amount": 0,
		"shield_absorbed": 0,
		"shield_broken": false,
		"shield_remaining": int(target.get("shield", 0)),
		"intercepted": 0,
	}
	if int(target.get("hit_immunity", 0)) > 0:
		target["hit_immunity"] = int(target["hit_immunity"]) - 1
		report["immunity_absorbed"] = true
		report["immunity_amount"] = damage
		report["damage"] = 0
		return report
	var transferred := _intercept_transfer(actor, target, damage)
	report["intercepted"] = transferred
	var remaining := damage - transferred
	var shield := int(target.get("shield", 0))
	if shield > 0 and remaining > 0:
		var absorbed := mini(shield, remaining)
		target["shield"] = shield - absorbed
		remaining -= absorbed
		report["shield_absorbed"] = absorbed
		if int(target["shield"]) <= 0:
			target["shield"] = 0
			target["shield_turns"] = 0
			report["shield_broken"] = true
	report["damage"] = remaining
	report["shield_remaining"] = int(target.get("shield", 0))
	return report


func _stamp_mitigation(event: Dictionary, report: Dictionary) -> void:
	event["immunity_absorbed"] = bool(report.get("immunity_absorbed", false))
	event["immunity_amount"] = int(report.get("immunity_amount", 0))
	event["shield_absorbed"] = int(report.get("shield_absorbed", 0))
	event["shield_broken"] = bool(report.get("shield_broken", false))
	event["shield_remaining"] = int(report.get("shield_remaining", 0))
	event["intercepted"] = int(report.get("intercepted", 0))


## Heartstop ally immunity is a hit charge, not a turn clock. The badge ends
## when the last charge is spent. A leftover charge stays on the unit.
func _emit_immunity_spent(target: Dictionary, report: Dictionary) -> void:
	if not bool(report.get("immunity_absorbed", false)):
		return
	if int(target.get("hit_immunity", 0)) > 0:
		return
	_emit_expire("hit_immunity", target["pos"], int(target["seat"]), int(target["seat"]))


func _intercept_transfer(actor: Dictionary, target: Dictionary, damage: int) -> int:
	if damage <= 0:
		return 0
	if int(actor.get("seat", -1)) == int(target.get("seat", -2)):
		return 0
	var guards: Array = []
	for unit in _units:
		if str(unit.get("class_id", "")) != SpellKits.CLASS_BASTION:
			continue
		if not bool(unit.get("alive", false)):
			continue
		if int(unit.get("seat", -1)) != int(target.get("seat", -2)):
			continue
		if unit["pos"] == target["pos"]:
			continue
		if bool(unit.get("intercept_used", false)):
			continue
		if chebyshev(unit["pos"], target["pos"]) != 1:
			continue
		guards.append(unit)
	# Two Bastions on the same ally is open_can_wait. Do not transfer.
	if guards.size() != 1:
		return 0
	var bastion: Dictionary = guards[0]
	var moved := roundi(float(damage) * SpellKits.INTERCEPT_TRANSFER)
	if moved <= 0:
		return 0
	bastion["intercept_used"] = true
	bastion["hp"] = maxi(0, int(bastion["hp"]) - moved)
	var dealt := mini(moved, damage)
	_last_events.append({
		"type": "intercept",
		"interceptor_seat": int(bastion["seat"]),
		"for_seat": int(target["seat"]),
		"interceptor_cell": bastion["pos"],
		"for_cell": target["pos"],
		"damage": dealt,
		"hp": int(bastion["hp"]),
	})
	_check_death(bastion)
	return dealt


func _support_heal_amount(actor: Dictionary, target: Dictionary, def: Dictionary) -> int:
	var base := int(def.get("base_heal", 0))
	if base <= 0:
		return 0
	var facing := FRONT_SIDE_FACING
	if not bool(def.get("no_facing", false)):
		facing = _facing_multiplier(actor["pos"], target["pos"], str(target.get("facing", "E")))
	var passive := PASSIVE
	if _triage_applied(target, def):
		passive = SpellKits.TRIAGE_MULT
	var raw: float = float(base) * CRIT_MULT * passive * (1.0 + MASTERY / 100.0) * facing
	return roundi(raw)


## Locked Triage ×1.25 when the target is below 40% HP before the heal.
## Ally Heartstop uses it. Enemy Heartstop is a damage hit and does not.
func _triage_applied(target: Dictionary, def: Dictionary) -> bool:
	if not bool(def.get("triage", false)):
		return false
	var max_hp := maxi(int(target.get("max_hp", START_HP)), 1)
	return float(int(target.get("hp", 0))) / float(max_hp) < SpellKits.TRIAGE_HP_THRESHOLD


func _apply_heal(target: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var room := int(target.get("max_hp", START_HP)) - int(target.get("hp", 0))
	var healed := mini(amount, maxi(room, 0))
	target["hp"] = int(target["hp"]) + healed
	return healed


func _resolve_support(intent: Dictionary, actor: Dictionary, target: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	var spell_id := str(def.get("id", ""))
	if spell_id == SpellKits.WARD and int(target.get("shield", 0)) > 0:
		return _reject(intent, "open_can_wait", "REJECT — shield stacking is open (can-wait).")
	if spell_id == SpellKits.HEARTSTOP and int(target.get("hit_immunity", 0)) > 0:
		return _reject(intent, "open_can_wait", "REJECT — immunity refresh is open (can-wait).")
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var chance := 0
	var roll := 0
	var connected := true
	if bool(def.get("rolls", false)):
		chance = hit_chance(dist)
		roll = _roll_d100()
		connected = roll <= chance
	_intent_log.append(intent)
	if not connected:
		_last_coach = "MISS — %s (%d vs %d%%). Resources stay." % [def["name"], roll, chance]
		_last_events.append({
			"type": "miss",
			"seat": actor["seat"],
			"spell": spell_id,
			"caster_cell": caster_cell,
			"target_seat": target["seat"],
			"to": dest,
			"range": dist,
			"hit_chance": chance,
			"roll": roll,
			"ap_spent": ap_cost,
			"mp_spent": mp_cost,
			"damage": 0,
			"healed": 0,
			"coach": _last_coach,
		})
		return _accept()
	var healed := 0
	var triage := false
	if spell_id != SpellKits.WARD and spell_id != SpellKits.CLEANSE:
		# Read Triage before the heal so the threshold sees pre-heal HP.
		triage = _triage_applied(target, def)
		healed = _apply_heal(target, _support_heal_amount(actor, target, def))
	var engine_gained := 0
	var engine_spent := 0
	match str(def.get("engine_on_connect", "")):
		"pulse":
			engine_gained = _gain_resource(actor, "pulse", 1)
		"spend_pulse":
			engine_spent = _spend_resource(actor, "pulse", int(def.get("spend_pulse", 1)))
	if spell_id == SpellKits.WARD:
		target["shield"] = int(def.get("shield", 20))
		target["shield_turns"] = int(def.get("shield_turns", 2))
	var cc_removed: Array = []
	if spell_id == SpellKits.CLEANSE:
		# Cleanse clears Stun only. Burn and other statuses stay.
		if int(target.get("stun_remaining", 0)) > 0 or bool(target.get("stunned", false)):
			cc_removed.append("stun")
		target["stun_remaining"] = 0
		target["stunned"] = false
	if spell_id == SpellKits.HEARTSTOP:
		target["hit_immunity"] = int(def.get("ally_immunity_hits", 1))
	_last_coach = "HIT %s on %s." % [def["name"], target["name"]]
	var hit_event := {
		"type": "hit",
		"seat": actor["seat"],
		"spell": spell_id,
		"caster_cell": caster_cell,
		"target_seat": target["seat"],
		"to": dest,
		"range": dist,
		"hit_chance": chance,
		"roll": roll,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"healed": healed,
		"damage": 0,
		"shield": int(target.get("shield", 0)),
		"engine_gained": engine_gained,
		"engine_spent": engine_spent,
		"coach": _last_coach,
	}
	if triage:
		hit_event["triage"] = true
	if spell_id == SpellKits.CLEANSE:
		hit_event["cc_removed"] = cc_removed
	if spell_id == SpellKits.HEARTSTOP:
		hit_event["hit_immunity"] = int(target.get("hit_immunity", 0))
	_last_events.append(hit_event)
	return _accept()


## Invisible has no duration. The cast (invisible, seat, caster_cell) and the
## unit snapshot (invisible, seat, pos) are the linger. No turns field, no expire.
func _resolve_fade(intent: Dictionary, actor: Dictionary, def: Dictionary, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var gained := _gain_resource(actor, "umbral", 1)
	actor["invisible"] = true
	_intent_log.append(intent)
	_last_coach = "%s Fade (−%d AP / −%d MP). Invisible. +%d Umbral." % [actor["name"], ap_cost, mp_cost, gained]
	_last_events.append({
		"type": "cast",
		"spell": SpellKits.FADE,
		"seat": actor["seat"],
		"caster_cell": caster_cell,
		"rolled": false,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"invisible": true,
		"engine_gained": gained,
		"coach": _last_coach,
	})
	return _accept()


func _resolve_empty_tile(intent: Dictionary, actor: Dictionary, def: Dictionary, dest: Vector2i, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	if not _is_empty(dest) or not _board.is_walkable(dest):
		return _reject(intent, "destination_occupied", "REJECT — %s needs an empty tile (refund)." % def["name"])
	var spell_id := str(def.get("id", ""))
	if spell_id == SpellKits.DROP_SHADE:
		if _shade_count(actor) >= SpellKits.SHADE_CAP:
			return _reject(intent, "shade_cap", "REJECT — Shade cap is %d (refund)." % SpellKits.SHADE_CAP)
		actor["ap"] = int(actor["ap"]) - ap_cost
		actor["mp"] = int(actor["mp"]) - mp_cost
		_shade_tokens.append({
			"pos": dest,
			"turns": int(def.get("shade_turns", 3)),
			"owner_seat": int(actor["seat"]),
			# 0 until the opponent finishes a turn. Not a caster-turn comparison.
			"opponent_turns_completed": 0,
		})
		_sync_shade_flags()
		_intent_log.append(intent)
		_last_coach = "%s drops a Shade on %s (−%d AP)." % [actor["name"], _cell_text(dest), ap_cost]
		_last_events.append({
			"type": "cast",
			"spell": spell_id,
			"seat": actor["seat"],
			"caster_cell": caster_cell,
			"to": dest,
			"rolled": false,
			"ap_spent": ap_cost,
			"mp_spent": mp_cost,
			"shades": int(actor.get("shades", 0)),
			"coach": _last_coach,
		})
		return _accept()
	if spell_id == SpellKits.SNAP_WALL:
		var spent := _spend_resource(actor, "aegis", int(def.get("spend_aegis", 2)))
		actor["ap"] = int(actor["ap"]) - ap_cost
		actor["mp"] = int(actor["mp"]) - mp_cost
		_add_snap_wall(dest, int(def.get("wall_turns", 2)), int(actor["seat"]))
		_intent_log.append(intent)
		_last_coach = "%s Snap Wall on %s (−%d AP, −%d Aegis)." % [actor["name"], _cell_text(dest), ap_cost, spent]
		_last_events.append({
			"type": "snap_wall",
			"spell": spell_id,
			"seat": actor["seat"],
			"to": dest,
			"cells": [dest],
			"rolled": false,
			"ap_spent": ap_cost,
			"mp_spent": mp_cost,
			"aegis_spent": spent,
			"turns": int(def.get("wall_turns", 2)),
			"coach": _last_coach,
		})
		return _accept()
	return _reject(intent, "unknown_spell", "REJECT — unknown empty-tile spell.")


func _resolve_plant(intent: Dictionary, actor: Dictionary, def: Dictionary, dest: Vector2i, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var gained := _gain_resource(actor, "aegis", 1)
	_plant_tiles.append({
		"pos": dest,
		"turns": int(def.get("plant_turns", 3)),
		"owner_seat": int(actor["seat"]),
		"push_resist": true,
	})
	_intent_log.append(intent)
	_last_coach = "%s Plant on %s (−%d AP). +%d Aegis." % [actor["name"], _cell_text(dest), ap_cost, gained]
	_last_events.append({
		"type": "cast",
		"spell": SpellKits.PLANT,
		"seat": actor["seat"],
		"caster_cell": caster_cell,
		"to": dest,
		"rolled": false,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"engine_gained": gained,
		"coach": _last_coach,
	})
	return _accept()


## Locked v0.6 Aegis Break. One roll for every enemy body in the range band.
## HIT deals base damage per body, pushes 1, and clears the caster's whole
## Aegis stack. MISS spends 0 Aegis and does not clear it.
func _resolve_aegis_break(intent: Dictionary, actor: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	if not _burst_enemies(actor, def, true).is_empty():
		return _reject(intent, "open_can_wait", "REJECT — AoE versus Invisible is open (can-wait).")
	var bodies: Array = _burst_enemies(actor, def, false)
	if bodies.is_empty():
		return _reject(intent, "no_target", "REJECT — %s needs an enemy in the burst (refund)." % def["name"])
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var chance := hit_chance(dist)
	var roll := _roll_d100()
	var connected := roll <= chance
	_intent_log.append(intent)
	if not connected:
		_last_coach = "MISS — Aegis Break (%d vs %d%%). Spends 0 Aegis." % [roll, chance]
		_last_events.append({
			"type": "miss",
			"seat": actor["seat"],
			"spell": SpellKits.AEGIS_BREAK,
			"caster_cell": caster_cell,
			"to": dest,
			"range": dist,
			"hit_chance": chance,
			"roll": roll,
			"ap_spent": ap_cost,
			"mp_spent": mp_cost,
			"engine_refunded": true,
			"damage": 0,
			"bodies": 0,
			"targets": _aegis_break_miss_rows(bodies),
			"aegis_spent": 0,
			"aegis": int(actor.get("aegis", 0)),
			"stacks_cleared": false,
			"coach": _last_coach,
		})
		return _accept()
	var cleared := _clear_resource(actor, "aegis")
	var total := 0
	var hit_bodies := 0
	var targets: Array = []
	var aim_row: Dictionary = {}
	for body in bodies:
		var target: Dictionary = body
		var cell: Vector2i = target["pos"]
		var facing_mult := _facing_multiplier(actor["pos"], target["pos"], str(target.get("facing", "E")))
		var is_back := facing_mult > FRONT_SIDE_FACING + 0.001
		var pre_mitigation := _phase_a_damage(int(def.get("base_damage", 26)), facing_mult)
		var mitigation := _mitigate_hit(actor, target, pre_mitigation)
		var damage := int(mitigation["damage"])
		target["hp"] = maxi(0, int(target["hp"]) - damage)
		var push_result: Dictionary = {}
		var burn_info: Dictionary = {}
		if int(def.get("push_cells", 0)) > 0:
			push_result = _try_push(actor["pos"], target, int(def["push_cells"]))
		if bool(push_result.get("burn", false)):
			burn_info = _apply_burn(target)
		var row := {
			"target_seat": int(target["seat"]),
			"cell": cell,
			"hit": true,
			"damage": damage,
			"facing_mult": facing_mult,
			"back": is_back,
		}
		_stamp_push_fields(row, push_result, burn_info)
		_stamp_mitigation(row, mitigation)
		targets.append(row)
		if aim_row.is_empty() or cell == dest:
			aim_row = row
		total += damage
		hit_bodies += 1
		_emit_push_followups(actor, target, push_result, burn_info)
		_emit_immunity_spent(target, mitigation)
		_check_death(target)
		if _match_over:
			break
	_last_coach = "HIT Aegis Break %d across %d. Aegis cleared (%d)." % [total, hit_bodies, cleared]
	var hit_event := {
		"type": "hit",
		"seat": actor["seat"],
		"spell": SpellKits.AEGIS_BREAK,
		"caster_cell": caster_cell,
		"to": dest,
		"range": dist,
		"hit_chance": chance,
		"roll": roll,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"base_damage": int(def.get("base_damage", 26)),
		"damage": total,
		"bodies": hit_bodies,
		"targets": targets,
		"element": def["element"],
		"engine": "aegis",
		"engine_spent": cleared,
		"aegis_spent": cleared,
		"aegis": int(actor.get("aegis", 0)),
		"stacks_cleared": cleared > 0,
		"coach": _last_coach,
	}
	if not aim_row.is_empty():
		hit_event["target_seat"] = int(aim_row.get("target_seat", -1))
		hit_event["facing_mult"] = float(aim_row.get("facing_mult", FRONT_SIDE_FACING))
		hit_event["back"] = bool(aim_row.get("back", false))
		_copy_push_fields(hit_event, aim_row)
	_last_events.append(hit_event)
	return _accept()


func _stamp_push_fields(row: Dictionary, push_result: Dictionary, burn_info: Dictionary) -> void:
	if push_result.is_empty():
		return
	row["pushed"] = bool(push_result.get("moved", false))
	row["push_from"] = push_result.get("from")
	row["push_to"] = push_result.get("to")
	row["push_attempted"] = push_result.get("attempted")
	row["push_blocked"] = bool(push_result.get("blocked", false))
	row["bounced"] = bool(push_result.get("bounced", false))
	row["staggered"] = bool(push_result.get("staggered", false))
	row["burn_applied"] = not burn_info.is_empty()


func _copy_push_fields(hit_event: Dictionary, row: Dictionary) -> void:
	for key in ["pushed", "push_from", "push_to", "push_attempted", "push_blocked", "bounced", "staggered", "burn_applied"]:
		if row.has(key):
			hit_event[key] = row[key]


func _emit_push_followups(actor: Dictionary, target: Dictionary, push_result: Dictionary, burn_info: Dictionary) -> void:
	if push_result.is_empty():
		return
	if bool(push_result.get("blocked", false)):
		_last_events.append({
			"type": "push_blocked",
			"locked": "Director Locked Shoulder — occupied dest is hard body-block (push_blocked)",
			"seat": actor["seat"],
			"target_seat": target["seat"],
			"from": push_result.get("from"),
			"attempted": push_result.get("attempted"),
			"reason": str(push_result.get("reason", "")),
			"coach": "Push blocked (occupied). Hard body-block — no bounce, no stagger.",
		})
	if bool(push_result.get("bounced", false)):
		var mp_note := ""
		if int(push_result.get("stagger_mp", 0)) > 0:
			mp_note = " / %d MP" % int(push_result.get("stagger_mp", 0))
		_last_events.append({
			"type": "push_bounce",
			"locked": "Director Locked Shoulder — OOB / truly blocked bounce + stagger (+2 Impact)",
			"seat": actor["seat"],
			"target_seat": target["seat"],
			"from": push_result.get("from"),
			"attempted": push_result.get("attempted"),
			"to": push_result.get("to"),
			"reason": str(push_result.get("reason", "")),
			"staggered": true,
			"hp_delta": int(push_result.get("hp_delta", 0)),
			"mp_delta": int(push_result.get("mp_delta", 0)),
			"stagger_hp": int(push_result.get("stagger_hp", 0)),
			"stagger_mp": int(push_result.get("stagger_mp", 0)),
			"coach": "Bounce (%s) + stagger %d HP%s." % [
				str(push_result.get("reason", "")),
				int(push_result.get("stagger_hp", 0)),
				mp_note,
			],
		})
		var stagger_mp_note := ""
		if int(push_result.get("stagger_mp", 0)) > 0:
			stagger_mp_note = ", %d MP" % int(push_result.get("stagger_mp", 0))
		_last_events.append({
			"type": "stagger",
			"locked": "Director Locked Shoulder — stagger 4 HP + 1 MP if MP>=1",
			"target_seat": target["seat"],
			"hp_delta": int(push_result.get("hp_delta", 0)),
			"mp_delta": int(push_result.get("mp_delta", 0)),
			"stagger_hp": int(push_result.get("stagger_hp", 0)),
			"stagger_mp": int(push_result.get("stagger_mp", 0)),
			"hp": int(target["hp"]),
			"mp": int(target["mp"]),
			"reason": str(push_result.get("reason", "")),
			"coach": "%s staggers (%d HP%s)." % [
				target["name"],
				int(push_result.get("stagger_hp", 0)),
				stagger_mp_note,
			],
		})
	if not burn_info.is_empty():
		var burn_coach := "%s is burning (%d HP at turn start, duration %d)." % [target["name"], BURN_HP, BURN_DURATION]
		if bool(burn_info.get("refreshed", false)):
			burn_coach = "%s's Burn refreshes to %d (no stack)." % [target["name"], BURN_DURATION]
		_last_events.append({
			"type": "status",
			"status": "burn",
			"remaining": int(burn_info.get("remaining", BURN_DURATION)),
			"duration": BURN_DURATION,
			"hp_per_tick": BURN_HP,
			"refreshed": bool(burn_info.get("refreshed", false)),
			"previous": int(burn_info.get("previous", 0)),
			"target_seat": target["seat"],
			"locked": "Director Locked Burn — 4 HP at turn start, duration 2, refresh no stack",
			"coach": burn_coach,
		})


func _resolve_hold_line(intent: Dictionary, actor: Dictionary, def: Dictionary, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	if not _cone_enemies(actor, true).is_empty():
		return _reject(intent, "open_can_wait", "REJECT — AoE versus Invisible is open (can-wait).")
	var bodies: Array = _cone_enemies(actor, false)
	if bodies.is_empty():
		return _reject(intent, "no_target", "REJECT — Hold Line needs an enemy in the cone (refund).")
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var dist := 1
	var chance := hit_chance(dist)
	var roll := _roll_d100()
	var connected := roll <= chance
	_intent_log.append(intent)
	var cone := _cone_payload(actor)
	if not connected:
		_last_coach = "MISS — Hold Line (%d vs %d%%)." % [roll, chance]
		_last_events.append({
			"type": "miss",
			"seat": actor["seat"],
			"spell": SpellKits.HOLD_LINE,
			"caster_cell": caster_cell,
			"roll": roll,
			"hit_chance": chance,
			"ap_spent": ap_cost,
			"mp_spent": mp_cost,
			"damage": 0,
			"bodies": 0,
			"cone": cone,
			"targets": _hold_line_miss_rows(bodies),
			"coach": _last_coach,
		})
		return _accept()
	var total := 0
	var hit_bodies := 0
	var targets: Array = []
	for body in bodies:
		var target: Dictionary = body
		var cell: Vector2i = target["pos"]
		var facing_mult := _facing_multiplier(actor["pos"], target["pos"], str(target.get("facing", "E")))
		var is_back := facing_mult > FRONT_SIDE_FACING + 0.001
		if str(actor.get("class_id", "")) == SpellKits.CLASS_GLOAM and is_back:
			facing_mult = SpellKits.BACKSTAB_MULT
		var pre_mitigation := _phase_a_damage(int(def.get("base_damage", 7)), facing_mult)
		var mitigation := _mitigate_hit(actor, target, pre_mitigation)
		var damage := int(mitigation["damage"])
		target["hp"] = maxi(0, int(target["hp"]) - damage)
		target["exit_tax"] = maxi(int(target.get("exit_tax", 0)), int(def.get("exit_tax_turns", 1)))
		var row := {
			"target_seat": int(target["seat"]),
			"cell": cell,
			"hit": true,
			"damage": damage,
			"exit_tax": int(target["exit_tax"]),
			"facing_mult": facing_mult,
			"back": is_back,
		}
		_stamp_mitigation(row, mitigation)
		targets.append(row)
		total += damage
		hit_bodies += 1
		_emit_immunity_spent(target, mitigation)
		_check_death(target)
		if _match_over:
			break
	var gained := 0
	if hit_bodies > 0 and not _match_over:
		gained = _gain_resource(actor, "aegis", 1)
	_last_coach = "HIT Hold Line %d across %d." % [total, hit_bodies]
	_last_events.append({
		"type": "hit",
		"seat": actor["seat"],
		"spell": SpellKits.HOLD_LINE,
		"caster_cell": caster_cell,
		"roll": roll,
		"hit_chance": chance,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"damage": total,
		"bodies": hit_bodies,
		"cone": cone,
		"targets": targets,
		"engine_gained": gained,
		"coach": _last_coach,
	})
	return _accept()


func _resolve_ambush(intent: Dictionary, actor: Dictionary, target: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	var blocked := _ambush_block_reason(actor, target)
	if blocked != "":
		return _reject(intent, blocked, _ambush_reject_text(blocked))
	var caster_cell: Vector2i = actor["pos"]
	var landing: Dictionary = _ambush_landing(actor, target)
	if not bool(landing.get("ok", false)):
		return _reject(intent, "illegal_back", "REJECT — Ambush back tile is occupied or illegal (refund).")
	var from_shade := not bool(actor.get("invisible", false))
	var origin: Dictionary = {}
	if from_shade:
		origin = _first_shade(actor)
		if origin.is_empty():
			return _reject(intent, "no_shade", "REJECT — Ambush needs Invisible or a Shade (refund).")
	# v0.6: origin is Gloam's own cell while Invisible, otherwise the Shade cell.
	var origin_cell: Vector2i = caster_cell if not from_shade else origin["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["mp"] = int(actor["mp"]) - mp_cost
	var chance := hit_chance(dist)
	var roll := _roll_d100()
	var connected := roll <= chance
	_intent_log.append(intent)
	if not connected:
		_last_coach = "MISS — Ambush (%d vs %d%%). No teleport. Shade and Invisible stay. −%d AP." % [roll, chance, ap_cost]
		_last_events.append({
			"type": "miss",
			"seat": actor["seat"],
			"spell": SpellKits.AMBUSH,
			"caster_cell": caster_cell,
			"target_seat": target["seat"],
			"to": dest,
			"range": dist,
			"hit_chance": chance,
			"roll": roll,
			"ap_spent": ap_cost,
			"mp_spent": mp_cost,
			"origin": origin_cell,
			"teleported": false,
			"shade_retained": bool(actor.get("shade", false)),
			"invisible_retained": bool(actor.get("invisible", false)),
			"damage": 0,
			"coach": _last_coach,
		})
		return _accept()
	var cell: Vector2i = landing["cell"]
	var backstab: bool = bool(landing.get("backstab", false))
	actor["pos"] = cell
	# Face the prey from the back tile. Miss keeps the old facing.
	var face_dir := facing_from_step(cell, target["pos"])
	if face_dir != "":
		actor["facing"] = face_dir
	if from_shade:
		_remove_shade_at(origin["pos"], int(actor["seat"]))
		_sync_shade_flags()
	var facing_mult := SpellKits.BACKSTAB_MULT if backstab else FRONT_SIDE_FACING
	var pre_mitigation := _phase_a_damage(int(def.get("base_damage", 22)), facing_mult)
	var mitigation := _mitigate_hit(actor, target, pre_mitigation)
	var damage := int(mitigation["damage"])
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	_last_coach = "HIT Ambush %d at %s." % [damage, _cell_text(cell)]
	_last_events.append({
		"type": "hit",
		"seat": actor["seat"],
		"spell": SpellKits.AMBUSH,
		"caster_cell": caster_cell,
		"target_seat": target["seat"],
		"to": cell,
		"from": dest,
		"range": dist,
		"hit_chance": chance,
		"roll": roll,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"origin": origin_cell,
		"destination": cell,
		"teleported": true,
		"backstab": backstab,
		"facing": str(actor.get("facing", "")),
		"facing_mult": facing_mult,
		"damage": damage,
		"shade_retained": not from_shade and bool(actor.get("shade", false)),
		"invisible_retained": bool(actor.get("invisible", false)),
		"shades": int(actor.get("shades", 0)),
		"coach": _last_coach,
	})
	_stamp_mitigation(_last_events[_last_events.size() - 1], mitigation)
	_emit_immunity_spent(target, mitigation)
	_check_death(target)
	return _accept()


## Locked destination is the enemy's facing-rear tile (one step opposite their
## facing). Range stays Manhattan 1–2 cardinal from the Ambush origin; approach
## axis-past was wrong when the Shade sat behind the foe (that landed on the
## front). Occupied / OOB / illegal rear rejects. Landing on the rear tile is
## always a backstab when the rear cone math agrees (it should).
func _ambush_landing(actor: Dictionary, target: Dictionary) -> Dictionary:
	var origin := _ambush_range_origin(actor)
	if origin == UNPLACED:
		return {"ok": false}
	# Range gate still needs a cardinal origin↔enemy axis (checked in block_reason).
	if _cardinal_unit_step(origin, target["pos"]) == Vector2i.ZERO:
		return {"ok": false}
	var facing := str(target.get("facing", ""))
	if not FACING_VEC.has(facing):
		return {"ok": false}
	var back: Vector2i = target["pos"] - FACING_VEC[facing]
	if not _ambush_cell_ok(back, actor["pos"]):
		return {"ok": false}
	var facing_mult := _facing_multiplier(back, target["pos"], facing)
	var backstab := facing_mult > FRONT_SIDE_FACING + 0.001
	return {"ok": true, "cell": back, "backstab": backstab}


## Unit step from origin toward target when they share a row or column. Zero otherwise.
static func _cardinal_unit_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta: Vector2i = to - from
	if delta.x != 0 and delta.y != 0:
		return Vector2i.ZERO
	if delta.x > 0:
		return Vector2i(1, 0)
	if delta.x < 0:
		return Vector2i(-1, 0)
	if delta.y > 0:
		return Vector2i(0, 1)
	if delta.y < 0:
		return Vector2i(0, -1)
	return Vector2i.ZERO


func _ambush_cell_ok(cell: Vector2i, caster_pos: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	# Facing-rear can be the tile Gloam already stands on (enemy one step in
	# front, facing away). That landing is legal. Any other occupant rejects.
	if cell != caster_pos and not _is_empty(cell):
		return false
	return _board.is_walkable(cell)


## Legal Ambush arm: origin is Manhattan 1–2 cardinal from the foe, the back tile
## is an empty walkable landing, and a Shade origin has seen the opponent finish
## at least one turn. Diagonals and Manhattan 3+ are not an arm. Landing uses the
## same cell as resolve. Offer, preview, origin chrome, and the HUD share this gate.
func _ambush_can_offer(actor: Dictionary, enemy: Dictionary) -> bool:
	return _ambush_block_reason(actor, enemy) == ""


## "" when Ambush may arm. Otherwise no_shade, shade_unarmed, out_of_range,
## illegal_back, or no_target. Origin is Gloam while Invisible (no arming delay),
## otherwise the first live Shade. That Shade stays illegal until the opponent
## has completed ≥1 full turn since it was Dropped.
func _ambush_block_reason(actor: Dictionary, enemy: Dictionary) -> String:
	if enemy.is_empty() or not bool(enemy.get("alive", false)):
		return "no_target"
	var origin_cell := _ambush_range_origin(actor)
	if origin_cell == UNPLACED:
		return "no_shade"
	if not bool(actor.get("invisible", false)):
		var shade := _first_shade(actor)
		if shade.is_empty():
			return "no_shade"
		if int(shade.get("opponent_turns_completed", 0)) < 1:
			return "shade_unarmed"
	var def: Dictionary = SpellKits.spell(SpellKits.AMBUSH)
	var axis := _cardinal_axis_len(origin_cell, enemy["pos"])
	if axis < int(def.get("min_range", 1)) or axis > int(def.get("max_range", 2)):
		return "out_of_range"
	if not bool(_ambush_landing(actor, enemy).get("ok", false)):
		return "illegal_back"
	return ""


func _ambush_reject_text(reason: String) -> String:
	if reason == "illegal_back" or reason == "no_landing":
		return "REJECT — Ambush back tile is occupied or illegal (refund)."
	if reason == "shade_unarmed":
		return "REJECT — Shade is not armed for Ambush until the opponent completes a turn (refund)."
	if reason == "no_shade":
		return "REJECT — Ambush needs Invisible or a Shade (refund)."
	if reason == "no_target":
		return "REJECT — Ambush needs an enemy (refund)."
	return "REJECT — Ambush is Manhattan 1–2 cardinal from the origin (refund)."


## Locked range origin. Invisible uses Gloam. Otherwise the first live Shade.
## UNPLACED when Ambush has neither, so the no_shade gate still runs.
func _ambush_range_origin(actor: Dictionary) -> Vector2i:
	if bool(actor.get("invisible", false)):
		return actor["pos"]
	var shade := _first_shade(actor)
	if shade.is_empty():
		return UNPLACED
	return shade["pos"]


func _first_shade(actor: Dictionary) -> Dictionary:
	for item in _shade_tokens:
		var token: Dictionary = item
		if int(token.get("owner_seat", -1)) == int(actor["seat"]) and int(token.get("turns", 0)) > 0:
			return token
	return {}


func _remove_shade_at(cell: Vector2i, seat: int) -> void:
	var next: Array = []
	var removed := false
	for item in _shade_tokens:
		var token: Dictionary = item
		if not removed and token.get("pos") == cell and int(token.get("owner_seat", -1)) == seat:
			removed = true
			continue
		next.append(token)
	_shade_tokens = next


func _shade_count(actor: Dictionary) -> int:
	var count := 0
	for item in _shade_tokens:
		var token: Dictionary = item
		if int(token.get("owner_seat", -1)) == int(actor["seat"]) and int(token.get("turns", 0)) > 0:
			count += 1
	return count


func _sync_shade_flags() -> void:
	for unit in _units:
		var count := _shade_count(unit)
		unit["shades"] = count
		unit["shade"] = count > 0


func _apply_shade_setup(config: Dictionary) -> void:
	var unit := _first_unit_of_class(SpellKits.CLASS_GLOAM)
	if unit.is_empty():
		return
	var want := bool(config.get("gloam_shade", false)) or bool(unit.get("shade", false))
	if want and _shade_count(unit) <= 0:
		var cell := _shade_setup_cell(unit)
		if cell != UNPLACED:
			_shade_tokens.append({
				"pos": cell,
				"turns": 3,
				"owner_seat": int(unit["seat"]),
				"opponent_turns_completed": 0,
			})
	_sync_shade_flags()


func _shade_setup_cell(unit: Dictionary) -> Vector2i:
	var origin: Vector2i = unit["pos"]
	var best := UNPLACED
	for y in range(_board_size):
		for x in range(_board_size):
			var cell := Vector2i(x, y)
			var dist := chebyshev(origin, cell)
			if dist < 1 or dist > 2:
				continue
			if not _is_empty(cell) or not _board.is_walkable(cell):
				continue
			if best == UNPLACED or cell.x < best.x or (cell.x == best.x and cell.y < best.y):
				best = cell
	return best


func _add_snap_wall(cell: Vector2i, turns: int, owner_seat: int) -> void:
	_snap_wall_cells.append(cell)
	_snap_wall_state.append({
		"pos": cell,
		"turns": turns,
		"owner_seat": owner_seat,
	})


func _unit_snapshot(unit: Dictionary) -> Dictionary:
	var copy: Dictionary = unit.duplicate(true)
	# Unit fields are the live values. resources mirrors them for chrome readers.
	# Linger flags already on the unit: invisible (no turn count), hit_immunity
	# (Heartstop ally charges), skip_next_mp (Heartstop enemy, until next turn).
	copy["resources"] = {
		"pulse": int(unit.get("pulse", 0)),
		"umbral": int(unit.get("umbral", 0)),
		"shades": int(unit.get("shades", 0)),
		"aegis": int(unit.get("aegis", 0)),
	}
	return copy


func _placed_token_snapshot(items: Array, include_resist: bool) -> Array:
	var out: Array = []
	for item in items:
		var token: Dictionary = item
		var cell: Vector2i = token["pos"]
		var rec := {
			"x": cell.x,
			"y": cell.y,
			"pos": cell,
			"turns": int(token.get("turns", 0)),
			"owner_seat": int(token.get("owner_seat", -1)),
		}
		if include_resist:
			rec["push_resist"] = bool(token.get("push_resist", false))
		if token.has("opponent_turns_completed"):
			rec["opponent_turns_completed"] = int(token.get("opponent_turns_completed", 0))
		out.append(rec)
	return out


func _restore_placed_tokens(into: Array, raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = entry
		var token := {
			"pos": _blocked_entry_cell(rec),
			"turns": int(rec.get("turns", 0)),
			"owner_seat": int(rec.get("owner_seat", -1)),
		}
		if rec.has("push_resist"):
			token["push_resist"] = bool(rec.get("push_resist", false))
		if rec.has("opponent_turns_completed"):
			token["opponent_turns_completed"] = int(rec.get("opponent_turns_completed", 0))
		into.append(token)


func _blocked_tile_snapshot() -> Array:
	if not _bastion_in_match():
		return []
	var out: Array = []
	for item in _snap_wall_state:
		var wall: Dictionary = item
		var cell: Vector2i = wall["pos"]
		out.append({
			"x": cell.x,
			"y": cell.y,
			"pos": cell,
			"turns": int(wall.get("turns", 0)),
			"owner_seat": int(wall.get("owner_seat", -1)),
		})
	return out


func _blocked_entry_cell(entry: Dictionary) -> Vector2i:
	if entry.has("pos"):
		return _as_cell(entry.get("pos", Vector2i.ZERO))
	if entry.has("x") or entry.has("y"):
		return Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	return _as_cell(entry)


func _restore_blocked_tiles(snap: Dictionary) -> void:
	var seen: Dictionary = {}
	var blocked: Variant = snap.get("blocked_tiles", [])
	if blocked is Array:
		for entry in blocked:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var rec: Dictionary = entry
			var cell := _blocked_entry_cell(rec)
			var key := "%d,%d" % [cell.x, cell.y]
			if bool(seen.get(key, false)):
				continue
			seen[key] = true
			_add_snap_wall(cell, int(rec.get("turns", 2)), int(rec.get("owner_seat", -1)))
	var walls: Variant = snap.get("snap_walls", [])
	if walls is Array:
		for wall in walls:
			var cell := _as_cell(wall)
			var key := "%d,%d" % [cell.x, cell.y]
			if bool(seen.get(key, false)):
				continue
			seen[key] = true
			_add_snap_wall(cell, 2, -1)


func _emit_expire(status: String, pos: Vector2i, owner_seat: int, target_seat: int = -1) -> void:
	var event := {
		"type": "expire",
		"status": status,
		"pos": pos,
		"owner_seat": owner_seat,
	}
	if target_seat >= 0:
		event["target_seat"] = target_seat
	_last_events.append(event)


## Shade Ambush arming clock. Called when `ending_seat` finishes a turn
## (End Turn or a stunned skip, both via _handoff_seat). Every Shade owned by
## the other seat gains one completed opponent turn. A Shade may be an Ambush
## origin only once that count is ≥ 1. This is not "created_turn < caster turn".
func _note_opponent_shade_turns(ending_seat: int) -> void:
	for item in _shade_tokens:
		var token: Dictionary = item
		if int(token.get("owner_seat", -1)) == ending_seat:
			continue
		if int(token.get("turns", 0)) <= 0:
			continue
		token["opponent_turns_completed"] = int(token.get("opponent_turns_completed", 0)) + 1


## Shade and Plant durations tick on the owner's turn-start only — same family
## as Snap Wall. Kit "3 turns" means three owner turn-starts after Drop/Plant,
## not three seat-begins across both fighters (that read as ~2 turns).
func _decay_board_durations(unit: Dictionary) -> void:
	if unit.is_empty():
		return
	var seat := int(unit.get("seat", -2))
	var shades: Array = []
	for item in _shade_tokens:
		var token: Dictionary = item
		if int(token.get("owner_seat", -1)) != seat:
			shades.append(token)
			continue
		token["turns"] = int(token.get("turns", 0)) - 1
		if int(token["turns"]) > 0:
			shades.append(token)
		else:
			_emit_expire("shade", token["pos"], int(token.get("owner_seat", -1)))
	_shade_tokens = shades
	var plants: Array = []
	for item in _plant_tiles:
		var tile: Dictionary = item
		if int(tile.get("owner_seat", -1)) != seat:
			plants.append(tile)
			continue
		tile["turns"] = int(tile.get("turns", 0)) - 1
		if int(tile["turns"]) > 0:
			plants.append(tile)
		else:
			_emit_expire("plant", tile["pos"], int(tile.get("owner_seat", -1)))
	_plant_tiles = plants
	_sync_shade_flags()


## Gamedeveloper lock, Phase A. Snap Wall duration is 2 Bastion turn-starts of
## the owner — the same tick family as Director Locked Burn (the affected
## unit's turn start). An enemy turn-start does not consume a turn. Do not
## shorten a fresh wall so it dies after one enemy turn.
func _tick_snap_walls(unit: Dictionary) -> void:
	if unit.is_empty():
		return
	var seat := int(unit.get("seat", -2))
	var walls: Array = []
	_snap_wall_cells.clear()
	for item in _snap_wall_state:
		var wall: Dictionary = item
		var owner := int(wall.get("owner_seat", -1))
		if owner != seat:
			walls.append(wall)
			_snap_wall_cells.append(wall["pos"])
			continue
		wall["turns"] = int(wall.get("turns", 0)) - 1
		if int(wall["turns"]) > 0:
			walls.append(wall)
			_snap_wall_cells.append(wall["pos"])
		else:
			_emit_expire("wall", wall["pos"], owner)
	_snap_wall_state = walls


func _tick_shield(unit: Dictionary) -> void:
	var turns := int(unit.get("shield_turns", 0))
	if turns <= 0:
		return
	unit["shield_turns"] = turns - 1
	if int(unit["shield_turns"]) <= 0:
		unit["shield"] = 0
		unit["shield_turns"] = 0
		_emit_expire("shield", unit["pos"], int(unit["seat"]), int(unit["seat"]))


func _consume_plant_resist(target: Dictionary) -> bool:
	for item in _plant_tiles:
		var tile: Dictionary = item
		if tile.get("pos") != target["pos"]:
			continue
		if int(tile.get("owner_seat", -1)) != int(target.get("seat", -2)):
			continue
		if not bool(tile.get("push_resist", false)):
			continue
		tile["push_resist"] = false
		return true
	return false


func _bastion_in_match() -> bool:
	for unit in _units:
		if str(unit.get("class_id", "")) == SpellKits.CLASS_BASTION:
			return true
	return false


func _snap_wall_blocks(cell: Vector2i) -> bool:
	if not _bastion_in_match():
		return false
	for wall in _snap_wall_cells:
		if wall == cell:
			return true
	return false


func _is_empty(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	if _snap_wall_blocks(cell):
		return false
	for blocked in _blocked_cells:
		if blocked == cell:
			return false
	for unit in _units:
		if not bool(unit.get("placed", true)):
			continue
		if unit["pos"] == cell:
			return false
	return true


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _board_size and cell.y < _board_size


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
