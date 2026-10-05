extends Node

## Local Phase A combat brain. Godot nodes must not mutate HP or roll.
## API: reset_match(config), submit(intent), legal_intents(seat), snapshot(),
## preview_cast(spell_id, from, to, target_seat=-1) — also accepts an intent Dictionary.
## Locked deploy flow (live duel): place / reposition / ready, then Turn 1 combat.
## Proposed zones (shipped live): seed-sampled ~6-cell blobs, not #31 border halves.
## Godot chrome binds place_unit / ready_seat / legal_deploy_cells / can_ready.
## Locked walk: per-tile elevation + terrain_type; dest-click weighted pathfinder.
## Proto/elevation stays reference — this file does not import it.

## Mauro (29 Sep): Invisible from Fade lasts this many of Gloam's turns.
## Was 2; Mauro 29 Sep 2026: "make fade last 1 turn".
const INVISIBLE_TURNS := 1
const RULES_VERSION := "phase-a-gdd-0.2"
const UNPLACED := Vector2i(-1, -1)
const _MatchFlow := preload("res://backend/match_flow.gd")
const _WalkBoard := preload("res://backend/walk_board.gd")
const _TerrainDef := preload("res://backend/terrain_def.gd")
const _ElevationCost := preload("res://backend/elevation_cost.gd")
const _BoardSize := preload("res://backend/board_size.gd")
const _CellTagMap := preload("res://backend/cell_tag_map.gd")
const FoeKits := preload("res://backend/foe_kits.gd")
const _HitBands := preload("res://backend/hit_bands.gd")
## Ship default is 15×15. MatchConfig.board_size 8 and 12 are proto only.
const BOARD_SIZE := _BoardSize.SHIP
const MAX_AP := 6
const MAX_MP := 3
## Mauro 30 Sep 2026: class base HP. Replaces the flat 80.
const CLASS_BASE_HP := {
	"bastion": 110,  # Mauro 1 Oct 2026 balance (was 100)
	"ironjaw": 90,
	"mender": 85,
	"kestrel": 75,
	"gloam": 75,  # Mauro 1 Oct 2026 balance (was 70)
}


static func class_base_hp(class_id: String) -> int:
	var id := str(class_id)
	if CLASS_BASE_HP.has(id):
		return int(CLASS_BASE_HP[id])
	# A body with no roster class (before a Stasis HP override) is not one of the five.
	return 80
const CRIT_MULT := 1.0
const MASTERY := 0.0
const RESIST := 0.0
const PASSIVE := 1.0
## Characteristics sheet (Mauro 29 Sep 2026). If PvP breaks, lower Longshot
## to 1.10 — do not delete it.
const LONGSHOT_MULT := 1.15
const LONGSHOT_RANGE := 4
const MOMENTUM_MULT := 1.20
## Resist cap per element (100% would be immune).
const RESIST_CAP := 50.0
const BACK_FACING := 1.20
const FRONT_SIDE_FACING := 1.00
## Director Locked Shoulder stagger: 4 HP; +1 MP only when current MP >= 1.
const STAGGER_HP := 4
## Elements Step 2 (docs/BALANCE_PLAN_HANDOFF.md §3; Mauro 4 Oct 2026: "its time
## to continue on elements"). Residue lasts 2 of the target's own turns. An
## Earth push into a wall hits for 8 instead of the stagger 4, once per target
## per turn.
const RESIDUE_TURNS := 2
const EARTH_COLLISION_HP := 8
const FIRE_RIDER_BURN_TURNS := 1
const STAGGER_MP := 1
## Clean push (walkable empty, or lava land — not a bounce): +1 Impact.
## Bounce (OOB / truly blocked, not lava): +2 Impact only. Do not add +1 on top.
const SHOULDER_CONNECT_IMPACT := 1
const SHOULDER_BOUNCE_IMPACT := 2
## Map push stacks (Mauro, "STASIUM XII Map push stacks + Cleanse", 29 Sep
## 2026). A PUSH onto a hazard stacks 1–3 while that CC is live; walk-on never
## stacks (voluntary walks refuse hazards anyway). Index = stack.
## Crosshaven mud Slow · Brinewake water Breathless · Slagcrown lava Burn ·
## Windmere ice (its water tiles) Frozen · Stormspire charged pools (its
## water tiles) Electrocuted. Mud is Slow and water Breathless on the others.
const HAZARD_MAX_STACKS := 3
## Lava: enter damage (Fire) then Burn ticks at the victim's turn start.
const LAVA_ENTER_HP: Array[int] = [0, 10, 10, 15]
const BURN_STACK_HP: Array[int] = [0, 4, 5, 5]
const BURN_STACK_TURNS: Array[int] = [0, 2, 3, 4]
const BURN_MAX_STACKS := 3
const LAVA_LAND_HP := 10
const BURN_DURATION := 4
## Mud Slow: −1/−2/−3 MP on the victim's next turn (1 turn, refresh).
const SLOW_MP := 1
const SLOW_TURNS := 1
## Water Breathless: 1 random kit spell silenced (same slot on a re-push) for
## 1/2/3 of the victim's turns.
const BREATHLESS_TURNS: Array[int] = [0, 1, 2, 3]
## Ice Frozen: no melee (spells and walk OK) for 1/2 turns; stack 3 Paralyzed
## (auto End Turn, the Locked Stun skip).
const FROZEN_TURNS: Array[int] = [0, 1, 2, 1]
## Stormspire Electrocuted: −1/−2/−3 AP on the victim's next turn (clamp 0).
const ELECTRO_TURNS := 1

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
## Hit bands / facing cones do not read height. Spell line of sight (Mauro
## 30 Sep 2026): solid props, Snap Walls and tiles raised above both ends
## block a targeted spell (see spell_needs_sight). Locked Stun (A′):
## blocks move + cast + face; auto end_turn on that seat's turn start (player
## never presses End Turn). Director Locked Shoulder: occupied dest is
## push_blocked (hard body-block; hit Impact stays +1). Walkable empty dest
## pushes for +1 Impact. OOB / truly blocked (not lava) bounces and staggers
## for +2 Impact only (no stack with +1). Lava is hazardous, not a wall:
## forced push displaces onto lava and applies Burn. Voluntary walk onto
## lava stays impassable. Soft Lock: mud and water are voluntary impassable
## the same way. Walk and Advance refuse them. A forced push may land.
## Castigo is per terrain: lava is Soft Lock (6 HP on land, then stacked Burn),
## water silences one random spell (one-shot, no duration), mud is Slow −1 MP
## for 1 turn. Superseded by the Map push stacks sheet (see HAZARD_MAX_STACKS): Burn stacks tick 4/5/5 HP at the
## victim's turn start, duration 4, max 3. Re-push adds a stack up to 3 and
## refreshes duration. Cleanse clears Burn. Burn continues after leaving lava.
## Death is checked after each tick. burn_stacks and burn_remaining live on
## the unit snapshot for Godot chrome and host sync.
## Host-owned 30s turn clock: starts on turn begin, ticks only on the authority
## (listen-host / hot-seat). Expiry submits the same end_turn as the HUD button.
## Guest replicas hydrate remaining from snapshot and must not tick.
const OPEN_DECISIONS := ["A03", "A04", "A05", "A06", "A07"]
const TURN_TIME_LIMIT := 30.0

## Set by _tick_invisible during a turn start; the handoff coach names it.
var _invisible_wore_off := false
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
## Elements Step 3 Blend tiles: [{kind "magma"|"steam", pos, owner_seat}].
var _element_tiles: Array = []
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
## Mobile Stasis Room A only. True when the roster has more than one hostile.
## Koliseo never sets this. Death, turn order, and cast offers stay 1v1 without it.
var _stasis_pack: bool = false
## Koliseo teams (Mauro 1 Oct 2026: 2v2 and 3v3). 1 = the classic duel.
## Seat s plays on team s % 2 (seats 0, 2, 4 vs 1, 3, 5). Turns alternate
## between the teams, each team ordered by Init (Dofus style).
var _team_size: int = 1
## Stasis party (Mauro 1 Oct 2026): 1–4 heroes (team 0, seats 0..P-1) vs the
## monsters (team 1, seats P..). 1 = the classic solo run.
var _party_size: int = 1
var _turn_order: Array[int] = []
var _winner_team: int = -1
## Live matches (Koliseo, Stasis): higher Init acts first, tie = coin flip
## (Mauro 29 Sep 2026). Test fixtures that do not ask for it keep seat 0.
var _first_by_init: bool = false
var _init_note: String = ""
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
	_element_tiles.clear()
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
	_stasis_pack = false
	_team_size = clampi(int(config.get("team_size", 1)), 1, 3)
	_party_size = clampi(int(config.get("party_size", 1)), 1, 4) if config.has("stasis_roster") else 1
	_turn_order.clear()
	_winner_team = -1
	_first_by_init = bool(config.get("first_by_init", false))
	_init_note = ""
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
	var deploys := not (bool(config.get("skip_deploy", false)) or config.has("kestrel_pos") or config.has("ironjaw_pos") or config.has("positions"))
	if deploys and not config.has("deploy_zones") and _elevation_gen == "tags":
		_zone_components = _walk_components()
		_flow.resample_zones(_seed, Callable(self, "_zone_cell_ok"), Callable(self, "_zones_meet"))
	if config.has("rolls"):
		for roll in config["rolls"]:
			_scripted_rolls.append(int(roll))

	# Hot-seat default is Kestrel (seat 0) then Ironjaw (seat 1).
	# config.classes / seat_classes overrides both seats when every id is on
	# the Locked allowlist. Any unknown id falls back to that default pair.
	var roster: Array[String] = _roster_class_ids(config)
	var facing_used: Dictionary = {}
	for seat in roster.size():
		var class_id: String = roster[seat]
		var facing := _facing_for(config, class_id, facing_used)
		var made := _make_unit(seat, class_id, SpellKits.display_name(class_id), SpellKits.element_of(class_id), UNPLACED, facing, false)
		made["team"] = seat % 2
		if _party_size > 1:
			made["team"] = 0 if seat < _party_size else 1
		_units.append(made)
	_apply_setup_overrides(config)
	# Mobile Stasis only. Koliseo never passes stasis_roster, so a normal duel
	# is unchanged. Foe HP and attack_base in that payload are provisional Open
	# playtest numbers, not Locked kit law.
	_apply_stasis_roster(config)
	# Worn gear per seat (Koliseo and Stasis): {"seat_gear": {0: fight_gear, 1: ...}}.
	var seat_gear: Variant = config.get("seat_gear", {})
	if typeof(seat_gear) == TYPE_DICTIONARY:
		for key in seat_gear:
			var unit := _unit_by_seat(int(key))
			if not unit.is_empty():
				_apply_gear(unit, seat_gear[key])

	var skip_deploy := bool(config.get("skip_deploy", false)) or config.has("kestrel_pos") or config.has("ironjaw_pos") or config.has("positions")
	if skip_deploy:
		# Test/setup only. Live duel no longer defaults to (1,1)/(6,6).
		# kestrel_pos / ironjaw_pos still name that class, not a fixed seat.
		# Stasis Room A appends hostile seats after the Locked pair. Koliseo
		# stays two seats because it never sets _stasis_pack.
		var class_pos_used: Dictionary = {}
		var spawn_seats := _units.size() if (_stasis_pack or _team_size > 1) else 2
		for seat in spawn_seats:
			var class_id: String = str(_units[seat]["class_id"])
			_force_spawn(seat, _spawn_cell_for(config, seat, class_id, class_pos_used))
		_flow.skip_to_combat()
		_apply_shade_setup(config)
		_begin_combat(_opening_turn_coach(""))
	else:
		_last_coach = "Deployment. Place one fighter in your deploy zone, then Ready."
		if _team_size > 1:
			_last_coach = "Deployment. Each team places its %d fighters in its zone, then Ready." % _team_size
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
			var cast_result := _submit_cast(normalized, actor)
			if bool(cast_result.get("ok", false)):
				_note_attacks(actor)
			return cast_result
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
	var mp: int = maxi(int(actor["mp"]) - _walk_tax(actor), 0)
	# Drift-Pin: a Pinned fighter cannot walk this turn (Advance / Ambush can).
	if bool(actor.get("pinned", false)):
		mp = 0
	var ap: int = int(actor["ap"])
	# Walk dests whenever mp>0, regardless of remaining AP. Advance is 3 AP / 0 MP, so
	# leftover MP after teleport still offers moves (including at 0 AP). Walk facing
	# is applied on submit (each hop), not here. Legal cells = weighted reachable.
	if mp > 0:
		for cell in _board.reachable_dests(from, mp, Callable(self, "_walk_occupied")):
			out.append({"type": "move", "to": cell, "seat": seat})

	# Stasis monsters cast from their own kit (FoeKits), not a class card.
	var foe_kit: Array = actor.get("foe_kit", []) if actor.get("foe_kit", []) is Array else []
	if not foe_kit.is_empty():
		for cast in _foe_casts(actor):
			out.append(cast)
		out.append({"type": "end_turn", "seat": seat})
		return out
	for spell_id in actor["spells"]:
		if _is_spell_silenced(actor, str(spell_id)) or _is_spell_frozen(actor, str(spell_id)):
			continue
		if spell_id == SpellKits.ADVANCE and str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
			continue
		var def: Dictionary = SpellKits.spell_for(actor, str(spell_id))
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
		if target_kind == "fallen_ally":
			for body in _revivable_allies(actor, def):
				out.append({"type": "cast", "spell": spell_id, "to": body["pos"], "target_seat": body["seat"], "seat": seat})
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
			# Teams / party: every living teammate in reach is an ally target too.
			if _multi_side():
				for mate in _units:
					if int(mate["seat"]) == seat or not _allied(mate, actor) or not bool(mate.get("alive", false)):
						continue
					if _cast_gate_reason(actor, mate, def) != "":
						continue
					if _in_spell_reach(def, from, mate["pos"]):
						out.append({"type": "cast", "spell": spell_id, "to": mate["pos"], "target_seat": mate["seat"], "seat": seat})
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
			# A body on mud, water, or lava is still a target. Terrain does not
			# soft-block aim. Do not consult stand_on_gate for the occupied cell.
			# Koliseo still offers the one other seat. A Stasis trash pack
			# offers every living hostile to the player.
			for hostile in _hostile_cast_targets(seat):
				var enemy: Dictionary = hostile
				# An Invisible enemy is never a named target (it would give
				# its tile away); blind attacks below can still find it.
				if bool(enemy.get("invisible", false)):
					continue
				if _cast_gate_reason(actor, enemy, def) != "":
					continue
				if _in_spell_reach(def, from, enemy["pos"]):
					out.append({
						"type": "cast",
						"spell": spell_id,
						"to": enemy["pos"],
						"target_seat": enemy["seat"],
						"seat": seat,
					})

	_append_blind_casts(out, actor)
	out.append({"type": "end_turn", "seat": seat})
	return out


## Mauro 30 Sep 2026: "player should be able to throw punches in the air and
## if any of the hits does damage to Gloam, Gloam becomes visible". While an
## enemy is Invisible, every enemy-target attack may be aimed at any tile in
## reach that shows no visible body. An empty tile is a whiff (AP spent); the
## hidden unit's tile rolls normally and damage reveals it.
func _has_invisible_hostile(seat: int) -> bool:
	for hostile in _hostile_cast_targets(seat):
		if bool((hostile as Dictionary).get("invisible", false)) and bool((hostile as Dictionary).get("alive", false)):
			return true
	return false


func _append_blind_casts(out: Array, actor: Dictionary) -> void:
	var seat := int(actor["seat"])
	if not _has_invisible_hostile(seat):
		return
	var from: Vector2i = actor["pos"]
	for spell_id in actor.get("spells", []):
		var id := str(spell_id)
		var def: Dictionary = SpellKits.spell_for(actor, id)
		if def.is_empty() or str(def.get("target", "")) != "enemy" or id == SpellKits.AMBUSH:
			continue
		if _is_spell_silenced(actor, id) or _is_spell_frozen(actor, id) or SpellKits.is_gated(id):
			continue
		if int(actor.get("ap", 0)) < int(def.get("ap", 0)) or int(actor.get("mp", 0)) < int(def.get("mp", 0)):
			continue
		if _resource_gate(actor, def) != "" or _cast_gate_reason(actor, {}, def) != "":
			continue
		for y in range(_board_size):
			for x in range(_board_size):
				var cell := Vector2i(x, y)
				if cell == from or not _in_spell_reach(def, from, cell):
					continue
				var body := _living_unit_at(cell)
				if not body.is_empty() and not bool(body.get("invisible", false)):
					continue
				out.append({"type": "cast", "spell": id, "to": cell, "seat": seat, "blind": true})


## Air punch: the tile held no body. AP / MP are spent, nothing is hit.
func _resolve_whiff(intent: Dictionary, actor: Dictionary, def: Dictionary, dest: Vector2i, ap_cost: int, mp_cost: int) -> Dictionary:
	actor["ap"] = int(actor["ap"]) - ap_cost
	if mp_cost > 0:
		_spend_mp(actor, mp_cost)
	_intent_log.append(intent)
	var face := _dir_name(_sign_step(dest - actor["pos"]))
	if face != "":
		actor["facing"] = face
	_break_invisible_on_attack(actor)
	_last_coach = "%s strikes the empty air at %s (−%d AP)." % [actor["name"], _cell_text(dest), ap_cost]
	_last_events.append({
		"type": "miss",
		"blind": true,
		"seat": actor["seat"],
		"spell": str(def.get("id", intent.get("spell", ""))),
		"caster_cell": actor["pos"],
		"to": dest,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"damage": 0,
		"coach": _last_coach,
	})
	return _accept()


## Damage on an Invisible unit reveals it at once.
func _reveal_if_hurt(target: Dictionary, damage: int) -> void:
	if damage <= 0 or not bool(target.get("invisible", false)):
		return
	target["invisible"] = false
	target["invisible_turns"] = 0
	_emit_expire("invisible", target["pos"], int(target["seat"]), int(target["seat"]))
	_last_events.append({
		"type": "revealed",
		"seat": int(target["seat"]),
		"cell": target["pos"],
		"coach": "%s is hit and revealed!" % str(target.get("name", "Unit")),
	})


## Locked Ambush: 4 AP / 0 MP, Manhattan 1–2 cardinal from the origin, blink to the
## empty tile one step past the enemy on that axis. Visible uses a Shade origin.
## Invisible keeps self-origin (no arming delay) and also a Shade origin when that
## Shade is still legal. Invisible must not strip the Shade. A Shade origin is
## illegal until the opponent has completed one full turn since that Drop.
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
	# Offer each legal origin. A fresh Shade, a diagonal, or Manhattan 3 must
	# not arm that origin. Drop Shade's Chebyshev ring is a different spell.
	# A Stasis pack can arm Ambush on any living hostile. Koliseo still has one.
	for hostile in _hostile_cast_targets(seat):
		var enemy: Dictionary = hostile
		if enemy.is_empty() or not bool(enemy.get("alive", false)):
			continue
		if _cast_gate_reason(actor, enemy, def) != "":
			continue
		for item in _ambush_legal_picks(actor, enemy):
			var pick: Dictionary = item
			out.append({
				"type": "cast",
				"spell": SpellKits.AMBUSH,
				"to": enemy["pos"],
				"target_seat": enemy["seat"],
				"seat": seat,
				"origin": pick["origin"],
				"from_shade": bool(pick.get("from_shade", false)),
			})


## Godot bind: place / reposition this seat's one fighter. Simultaneous; no turn gate.
func place_unit(seat: int, cell: Variant) -> Dictionary:
	return submit({"type": "place", "seat": seat, "to": _as_cell(cell)})


## Godot bind: Ready this seat. Gated on unit placed. Both ready → lock → Turn 1.
func ready_seat(seat: int) -> Dictionary:
	return submit({"type": "ready", "seat": seat})


func can_ready(seat: int) -> bool:
	return _flow.can_ready(_side(seat))


func can_place(seat: int, cell: Variant) -> Dictionary:
	return _deploy_place_gate(seat, _as_cell(cell))


func legal_deploy_cells(seat: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _flow.legal_place_cells(_side(seat), Callable(self, "_deploy_occupant").bind(seat)):
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
	return _flow.zone_cells(_side(seat))


## Deploy side: the seat in a duel, the team in 2v2 / 3v3 (one zone and one
## Ready per team).
func _side(seat: int) -> int:
	return team_of_seat(seat) if _team_size > 1 else seat


## Occupant as the flow's place gate reads it: empty = -1, the placing
## fighter itself = its side (a reposition), anyone else = blocked.
func _deploy_occupant(cell: Vector2i, seat: int) -> int:
	var occ := _occupant_seat(cell)
	if occ < 0:
		return -1
	if occ == seat:
		return _side(seat)
	return 99


func _side_all_placed(side: int) -> bool:
	for unit in _units:
		if _side(int(unit["seat"])) == side and not bool(unit.get("placed", false)):
			return false
	return true


func match_phase_name() -> String:
	return _flow.phase_name()


## Presentation helper: in-bounds tiles in the spell's range ring (caster tile excluded).
## Mark Shot uses this for Chebyshev 2–7 chrome. Does not imply a legal cast dest.
## Advance is the exception: highlights are legal_intents dests only (exactly 2
## cardinal spaces that pass stand-on). Not a Manhattan 1 ring and not a diamond.
## Chrome only. Shown when Ambush is a legal arm: Manhattan 1–2 cardinal from the
## origin and the back tile can be landed on. Visible chrome is the Shade.
## Invisible chrome is the Shade when that jump is still legal, otherwise Gloam.
## A Shade the opponent has not yet finished a turn past does not open this chrome.
func ambush_origin(seat: int) -> Dictionary:
	var hidden := {"show": false, "from_self": false, "origin": Vector2i(-1, -1)}
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return hidden
	if str(actor.get("class_id", "")) != SpellKits.CLASS_GLOAM:
		return hidden
	var enemy := _ambush_primary_enemy(actor)
	var pick := _ambush_selected(actor, enemy, {})
	if pick.is_empty():
		return hidden
	return {
		"show": true,
		"from_self": not bool(pick.get("from_shade", false)),
		"origin": pick["origin"],
	}


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
	var def: Dictionary = SpellKits.spell_for(actor, spell_id)
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
				if not _spell_sees(def, from, cell):
					continue
				out.append(cell)
	return out


## In range but behind a wall: the board paints these grey (no sight).
func sight_blocked_cells(seat: int, spell_id: String) -> Array:
	var out: Array = []
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not actor["alive"] or not SpellKits.has_spell(str(actor["class_id"]), spell_id):
		return out
	var def: Dictionary = SpellKits.spell_for(actor, spell_id)
	if def.is_empty() or not spell_needs_sight(def):
		return out
	var from: Vector2i = actor["pos"]
	for y in range(_board_size):
		for x in range(_board_size):
			var cell := Vector2i(x, y)
			if cell != from and _in_spell_range(def, from, cell) and not _spell_sees(def, from, cell):
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
		"team_size": _team_size,
		"party_size": _party_size,
		"winner_team": _winner_team,
		"turn_order": _turn_order.duplicate(),
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
		"element_tiles": _element_tile_snapshot(),
		"map_steam": _map_steam_snapshot(),
		"shade_tokens": _placed_token_snapshot(_shade_tokens, false),
		"plant_tiles": _placed_token_snapshot(_plant_tiles, true),
		"umbral_cap": SpellKits.UMBRAL_CAP,
		"umbral_owner": SpellKits.CLASS_GLOAM,
		"wind": "calm",
		"crit_roll": false,
		"crit_mult": CRIT_MULT,
		"mastery": MASTERY,
		"momentum": true,
		"residue": SpellKits.element_riders,
		"blends": false,
		"gust": false,
		"longshot": true,
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
			"void": 0,
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
		"push_water": "displace_silence",
		"push_mud": "displace_slow",
		"slow_mp": SLOW_MP,
		"slow_turns": SLOW_TURNS,
		"push_stagger_hp": STAGGER_HP,
		"push_stagger_mp": STAGGER_MP,
		"shoulder_impact_connect": SHOULDER_CONNECT_IMPACT,
		"shoulder_impact_bounce": SHOULDER_BOUNCE_IMPACT,
		"burn": "soft_lock",
		"lava_land_hp": LAVA_LAND_HP,
		"lava_enter_hp": [LAVA_ENTER_HP[1], LAVA_ENTER_HP[2], LAVA_ENTER_HP[3]],
		"burn_stack_turns": [BURN_STACK_TURNS[1], BURN_STACK_TURNS[2], BURN_STACK_TURNS[3]],
		"hazard_push_stacks": "slow/breathless/burn/frozen/electrocuted, push while live stacks to 3",
		"burn_duration": BURN_DURATION,
		"burn_max_stacks": BURN_MAX_STACKS,
		"burn_stack_hp": [BURN_STACK_HP[1], BURN_STACK_HP[2], BURN_STACK_HP[3]],
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
			"A05": "Open: Resist 0, damage rounded to nearest int. WindMod omitted from the formula. Locked Stun (A′): stun_remaining on the unit; reject move/cast/face with stunned_cannot_act; auto end_turn on that seat's turn start (player never presses End Turn). Decrement at start of that unit's turn after setting stunned-this-turn so Stun 1 covers the incoming (skipped) turn. Director Locked Shoulder: occupied dest is push_blocked (hard body-block, no bounce/stagger; Impact stays the hit +1). Walkable empty dest pushes for +1 Impact. OOB / truly blocked (not lava) bounces (target stays) and staggers (4 HP; +1 MP if current MP >= 1) for +2 Impact only (no stack with +1). Map push stacks (Mauro 29 Sep 2026): a forced push onto a hazard stacks 1–3 while live. Lava enter 10/10/15 Fire then Burn 4×2 / 5×3 / 5×4; water Breathless (1 spell silenced 1/2/3 turns, same slot); mud Slow −1/−2/−3 MP; Windmere ice Frozen (no melee 1/2 turns, 3 = Paralyzed); Stormspire charge Electrocuted −1/−2/−3 AP. Cleanse strips one family. Voluntary walk onto hazards stays impassable.",
			"A06": "Advance (Locked teleport): dest-click snap, 3 AP / 0 MP, client path ignored. Range gate is exactly 2 cardinal spaces (N/S/E/W at Manhattan 2). Manhattan 1, diagonals, and any non-cardinal are rejected. Dest must pass the same stand-on gates as walk (not mud, water, or lava, not occupied, climb<=1 / drop<=2). Gate only — no terrain+elev MP spend. Illegal dest refunds. legal_intents / preview_cast use the shared helper. leftover MP still walks (legal_intents is mp>0, not AP). No hop path. +1 Impact if Chebyshev 1 to an enemy after landing. Facing unchanged — Advance does not auto-face.",
			"A07": "Provisional Open: back = 90° rear cone (facing-axis dominates and is opposite). Front/side ×1.00, back ×1.20.",
			"deploy": "Locked flow: simultaneous place/reposition, Ready gated on place, both ready → lock → Turn 1. Proposed (shipped live): seed-sampled ~6-cell blobs (2×3 or organic), interior allowed, min opening Chebyshev 3 (prefer 4–6), reject overlap and same-edge camping. Open: fog/hidden enemy, deploy timer, multi-unit. No networking.",
			"elevation": "Locked walk: per-tile integer elevation + terrain_type. Ship terrain + elevation load from the picked Koliseo tags file when size is 15×15 (default Crosshaven; map_id selects brinewake, slagcrown, windmere, or stormspire; no invented layout). paint_only is visual only. Proto board_size 8 keeps the 8×8 crop plus seeded noise. Proto board_size 12 keeps Mauro's token grid. Terrain MP Ground 1, Mud 2, Water 2, Lava impassable. Uphill +1 per integer z step; downhill 0. Max climb 1 / drop 2 (no z1→z3 hop); ortho-only. Walk cost = dest terrain + elev Δ. Weighted pathfinder; legal cells from remaining MP. Advance uses the same stand-on gates (no MP spend). Hit bands are Locked through Chebyshev 14 (see HitBands). Dist past 14 has no percent. Hit / facing unchanged — no height mods. Spell line of sight (Mauro 30 Sep 2026): a solid prop, a Snap Wall or a tile raised above both ends blocks a targeted spell. Open (do not invent): height→hit/facing, stairs/ramps/flying, hit % past 14.",
		},
		"open_elevation": ["height_hit", "height_facing", "stairs", "ramps", "flying"],
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
	_element_tiles.clear()
	for entry in snap.get("element_tiles", []):
		if typeof(entry) == TYPE_DICTIONARY:
			_element_tiles.append({"kind": str(entry.get("kind", "")), "pos": _blocked_entry_cell(entry), "owner_seat": int(entry.get("owner_seat", -1))})
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
	_CellTagMap.seal_blocking_props(_board, _paint_only, _map_id)
	_flow.apply_host_snapshot(snap)


func _apply_snapshot_tiles(raw: Variant) -> void:
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var rec: Dictionary = item
			_board.set_tile(_as_cell(rec.get("pos", rec)), str(rec.get("terrain_type", "ground")), int(rec.get("elevation", 0)), _walkable_override(rec))
		return
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var tiles: Dictionary = raw
	for key in tiles:
		var rec: Variant = tiles[key]
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var cell: Vector2i = key if key is Vector2i else _as_cell((rec as Dictionary).get("pos", key))
		_board.set_tile(cell, str(rec.get("terrain_type", "ground")), int(rec.get("elevation", 0)), _walkable_override(rec))


func _walkable_override(rec: Dictionary) -> Variant:
	if not rec.has("walkable"):
		return null
	return bool(rec["walkable"])


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
	var def: Dictionary = SpellKits.spell_for(_unit_by_seat(seat), spell_id)
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
		if enemy.is_empty() or not enemy["alive"] or bool(enemy.get("invisible", false)):
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
	# No sight behind a wall: no hit % either (the shot cannot be taken).
	if not _spell_sees(def, aim_from, cell):
		out["no_sight"] = true
		return out
	# Locked % for Chebyshev 1–14. Dist >14 stays hidden (no invented %).
	if chance >= 0 and dist >= 1 and dist <= _HitBands.MAX_DISTANCE:
		out["show"] = true
	return out


func _aim_hidden() -> Dictionary:
	return {
		"show": false,
		"from": UNPLACED,
		"to": UNPLACED,
		"from_shade": false,
		"float_text": "",
		"float_cell": UNPLACED,
		"kind": "",
	}


func _legal_has_cast(seat: int, spell_id: String) -> bool:
	for intent in legal_intents(seat):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == spell_id:
			return true
	return false


## Presentation only. Dashed aim line and the predicted float. Does not roll,
## spend, or move a body. Ambush is drawn from the legal origin (the Shade,
## including while Invisible when that Shade is still legal, otherwise Gloam)
## and only while that cast is in legal_intents.
## Other spells draw from the caster to the hovered in-range cell.
func aim_feel(seat: int, spell_id: String, hover: Variant = null) -> Dictionary:
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return _aim_hidden()
	if spell_id == "" or not SpellKits.has_spell(str(actor.get("class_id", "")), spell_id):
		return _aim_hidden()
	var def: Dictionary = SpellKits.spell_for(actor, spell_id)
	if def.is_empty():
		return _aim_hidden()
	if spell_id == SpellKits.AMBUSH:
		return _ambush_aim_feel(seat, actor, def)
	if spell_id == SpellKits.ADVANCE or hover == null:
		return _aim_hidden()
	var from_cell: Vector2i = actor["pos"]
	var cell := _as_cell(hover)
	if not _in_spell_reach(def, from_cell, cell):
		return _aim_hidden()
	var under := _living_unit_at(cell)
	# Hovering an Invisible enemy's tile must not name it or its damage.
	if not under.is_empty() and bool(under.get("invisible", false)) and team_of_seat(int(under.get("seat", -1))) != team_of_seat(seat):
		under = {}
	var floated: Dictionary = _aim_float(actor, under, def, from_cell)
	var text := str(floated.get("text", ""))
	if from_cell == cell and text == "":
		return _aim_hidden()
	return {
		"show": true,
		"from": from_cell,
		"to": cell,
		"from_shade": false,
		"float_text": text,
		"float_cell": cell,
		"kind": str(floated.get("kind", "")),
	}


## Ambush aim is the origin the cast will use. The line leaves the Shade when
## that Shade is the jump, including while Invisible. It leaves Gloam only for
## an Invisible self-origin. The float is the connect sample from the back tile,
## including Backstab, using the same Phase A product as the hit.
func _ambush_aim_feel(seat: int, actor: Dictionary, def: Dictionary) -> Dictionary:
	if not _legal_has_cast(seat, SpellKits.AMBUSH):
		return _aim_hidden()
	var origin: Dictionary = ambush_origin(seat)
	if not bool(origin.get("show", false)):
		return _aim_hidden()
	var enemy := _enemy_of(seat)
	if enemy.is_empty() or not bool(enemy.get("alive", false)):
		return _aim_hidden()
	var landing: Dictionary = _ambush_landing(actor, enemy)
	if not bool(landing.get("ok", false)):
		return _aim_hidden()
	var mult := SpellKits.BACKSTAB_MULT if bool(landing.get("backstab", false)) else FRONT_SIDE_FACING
	var amount := _phase_a_damage(int(def.get("base_damage", 22)), mult, actor, enemy, str(def.get("element", "")))
	if amount <= 0:
		return _aim_hidden()
	return {
		"show": true,
		"from": origin["origin"],
		"to": enemy["pos"],
		"from_shade": not bool(origin.get("from_self", false)),
		"float_text": "-%d" % amount,
		"float_cell": enemy["pos"],
		"kind": "damage",
	}


## Predicted connect text for the hovered body. Heals use the support formula.
## Damage uses preview_cast's Phase A sample. Neither call spends or rolls.
func _aim_float(actor: Dictionary, target: Dictionary, def: Dictionary, from_cell: Vector2i) -> Dictionary:
	var empty := {"text": "", "kind": ""}
	if target.is_empty() or not bool(target.get("alive", false)):
		return empty
	var same := not target.is_empty() and not actor.is_empty() and _allied(target, actor)
	if same and int(def.get("base_heal", 0)) > 0:
		var healed := _support_heal_amount(actor, target, def)
		if healed <= 0:
			return empty
		return {"text": "+%d" % healed, "kind": "heal"}
	if same and int(def.get("shield", 0)) > 0 and int(def.get("base_damage", 0)) <= 0:
		return {"text": "+%d" % int(def.get("shield", 0)), "kind": "shield"}
	if same:
		return empty
	var spell_id := str(def.get("id", ""))
	var preview: Dictionary = preview_cast(spell_id, from_cell, target["pos"], int(target.get("seat", -1)))
	if preview.get("sample_damage", null) == null:
		return empty
	var amount := int(preview["sample_damage"])
	if amount <= 0:
		return empty
	return {"text": "-%d" % amount, "kind": "damage"}


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

	var def: Dictionary = SpellKits.spell_for(actor, spell_id)
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
		var preview_enemy := _unit_by_seat(target_seat) if target_seat >= 0 else _living_unit_at(to_cell)
		var origin_cell := _ambush_measure_cell(actor, preview_enemy)
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
		# Same replacement as _resolve_rolling_cast. A foe sample must not
		# show the stand-in card's Locked base while the hit uses the
		# provisional attack. Facing stays the Locked Phase A product.
		if int(actor.get("stasis_attack_base", -1)) >= 0:
			base = int(actor["stasis_attack_base"])
		# Locked Phase A sample: CritMult=1.0, Passive=1, Mastery=0. WindMod omitted.
		# Resist 0 is not invented as Locked — provisional Open A05, labeled below.
		out["sample_damage"] = _phase_a_damage(base, facing_mult, actor, target, str(def.get("element", "")))
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
		notes.append("Push 1 along the line. Director Locked Shoulder: walkable empty dest pushes (+1 Impact). Occupied dest is push_blocked (hard body-block). OOB / truly blocked dest bounces + staggers (4 HP; +1 MP if MP>=1) for +2 Impact only (no stack with +1). Hazard pushes stack 1–3 (Map push stacks): lava 10/10/15 + Burn 4×2 / 5×3 / 5×4, water Breathless, mud Slow −1/−2/−3 MP, Windmere ice Frozen, Stormspire charge Electrocuted. Voluntary walk and Advance refuse mud and water.")

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
	if not _spell_sees(def, from_cell, to_cell):
		return "no_line_of_sight"
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
	if target_kind == "fallen_ally":
		if bool(def.get("once_per_match", false)) and bool(actor.get("used_" + spell_id, false)):
			return "once_per_match"
		var pulse_gate := _resource_gate(actor, def)
		if pulse_gate != "":
			return pulse_gate
		if _fallen_ally_at(actor, to_cell).is_empty():
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
	var ally_cast := target_kind == "ally" or (target_kind == "any" and not target.is_empty() and _allied(target, actor))
	if ally_cast:
		if target.is_empty() or not bool(target.get("alive", false)) or not _allied(target, actor):
			return "no_target"
		if spell_id == SpellKits.WARD and int(target.get("shield", 0)) > 0:
			return "open_can_wait"
		if spell_id == SpellKits.HEARTSTOP and int(target.get("hit_immunity", 0)) > 0:
			return "open_can_wait"
		return ""
	if target.is_empty() or not bool(target.get("alive", false)) or _allied(target, actor):
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
		SpellKits.REKINDLE:
			return {"on_connect": "Spends 6 Pulse. A fallen teammate stands up with 30% HP. Once per match.", "on_miss": "No roll."}
		SpellKits.MARK_SHOT:
			return {"on_connect": "8 Air. +1 Mark on the target.", "on_miss": "AP/MP stay spent. No Mark."}
		SpellKits.DETONATE:
			return {"on_connect": "6+6×M Air. Consumes Marks on the target.", "on_miss": "Marks stay. AP/MP stay spent."}
		SpellKits.STRIKE:
			return {"on_connect": "14 Earth. +1 Impact.", "on_miss": "AP/MP stay spent. No Impact."}
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


## Locked Phase A damage sample/resolve. CritMult 1.0, Passive 1.
## WindMod omitted (not invented as 1.0). Mastery / Resist are 0 on the
## proto body; worn gear set bonuses raise them (Mauro 29 Sep 2026: gear
## counts in Koliseo and Stasis). Ironveil attuned resist only against
## hits of the attuned element.
func _phase_a_damage(base: int, facing_mult: float, actor: Dictionary = {}, target: Dictionary = {}, element: String = "", resolve: bool = false) -> int:
	var mastery: float = MASTERY + float(actor.get("mastery", 0))
	var el := element.to_lower()
	var resist: float = RESIST + float(target.get("resist", 0))
	var by_elem: Variant = target.get("resist_elem", {})
	if typeof(by_elem) == TYPE_DICTIONARY and el != "":
		resist += float((by_elem as Dictionary).get(el, 0))
	var flex := _flex_bonus(actor, el, resolve)
	var passive := PASSIVE * _class_passive(actor, target)
	var raw: float = float(base) * CRIT_MULT * passive * (1.0 + mastery / 100.0) * (1.0 + flex / 100.0) * (1.0 - clampf(resist, 0.0, RESIST_CAP) / 100.0) * facing_mult
	return roundi(raw)


## Mauro 29 Sep 2026 (Characteristics sheet): Kestrel Longshot ×1.15 when the
## target is ≥4 tiles away (Chebyshev); Ironjaw Momentum ×1.20 after spending
## MP or casting Advance this turn. Backstab / Triage / Intercept unchanged.
func _class_passive(actor: Dictionary, target: Dictionary) -> float:
	if actor.is_empty() or target.is_empty():
		return 1.0
	match str(actor.get("class_id", "")):
		SpellKits.CLASS_KESTREL:
			var a: Vector2i = _as_cell(actor.get("pos", UNPLACED))
			var b: Vector2i = _as_cell(target.get("pos", UNPLACED))
			if maxi(absi(a.x - b.x), absi(a.y - b.y)) >= LONGSHOT_RANGE:
				return LONGSHOT_MULT
		SpellKits.CLASS_IRONJAW:
			if bool(actor.get("momentum", false)):
				return MOMENTUM_MULT
	return 1.0


## Every MP spend goes through here so Momentum knows the unit moved.
func _spend_mp(actor: Dictionary, amount: int) -> void:
	actor["mp"] = int(actor["mp"]) - amount
	if amount > 0:
		actor["momentum"] = true


## ---- Elements, Step 2: mono riders + Residue -------------------------------
## SpellKits.spell carries the data riders (Air +1 range, Water heals +4).
## These are the fight riders of a connecting FLEX hit by a hero's kit spell:
##   Air   melee (max range 2 or less: Cut, Ambush): +1 MP this turn.
##   Earth caster Grounded until its next turn. Bastion's Grounded blocks every
##         push; other Earth casters' Grounded only stops Gust (not in the game).
##         Earth pushes into a wall: 8 instead of the stagger 4, once per target
##         per turn (see _apply_bounce_stagger).
##   Water damage: the target loses 1 MP at the start of its next turn (once).
##   Fire  Burn 4 at the target's next turn start, no stack (no class is Fire yet).
## Residue: the hit writes its element on the target for 2 of the target's own
## turns; one per body, same element refreshes, a new one overwrites, death
## clears it, Cleanse does not. Heals to allies write none. Neutral: nothing.
func _rider_element(actor: Dictionary, def: Dictionary) -> String:
	if not SpellKits.element_riders:
		return ""
	# Hero kit spells only: Stasis foes that borrow a card do not ride.
	if int(actor.get("stasis_attack_base", -1)) >= 0 or not (actor.get("foe_kit", []) as Array).is_empty():
		return ""
	if not SpellKits.has_spell(str(actor.get("class_id", "")), str(def.get("id", ""))):
		return ""
	var el := str(def.get("element", "neutral")).to_lower()
	return "" if el == "" or el == "neutral" else el


## Per enemy body hit: Water slow, Fire burn, then the Blend test, then
## Residue (Elements PDF §5: riders + push first, dead check, pair test,
## Blend, clear, write Residue). Returns rider tags.
func _flex_target(actor: Dictionary, target: Dictionary, def: Dictionary) -> Array:
	var el := _rider_element(actor, def)
	var tags: Array = []
	if el == "" or target.is_empty() or _team_of(target) == _team_of(actor):
		return tags
	# Dead check: no Blend and no Residue on a body that just fell.
	if int(target.get("hp", 0)) <= 0:
		_add_element_rider(target, el, tags)
		return tags
	_add_element_rider(target, el, tags)
	var blend := _try_blend(actor, target, el)
	if blend != "":
		tags.append("blend")
		tags.append("blend_" + blend)
		return tags
	target["residue"] = el
	target["residue_turns"] = RESIDUE_TURNS
	target["residue_seat"] = int(actor["seat"])
	tags.append("residue")
	return tags


func _add_element_rider(target: Dictionary, el: String, tags: Array) -> void:
	match el:
		"water":
			target["water_slow"] = true
			tags.append("water_slow")
		"fire":
			if int(target.get("burn_stacks", 0)) <= 0:
				target["burn_stacks"] = 1
			target["burn_remaining"] = maxi(int(target.get("burn_remaining", 0)), FIRE_RIDER_BURN_TURNS)
			tags.append("fire_burn")


## Once per connecting cast: Air melee +1 MP, Earth Grounded.
func _flex_caster(actor: Dictionary, def: Dictionary) -> Array:
	var el := _rider_element(actor, def)
	var tags: Array = []
	match el:
		"air":
			if int(def.get("max_range", 0)) <= 2:
				actor["mp"] = int(actor.get("mp", 0)) + 1
				tags.append("air_mp")
		"earth":
			actor["grounded"] = true
			tags.append("grounded")
	return tags


func _stamp_riders(event: Dictionary, tags: Array, def: Dictionary) -> void:
	if tags.is_empty():
		return
	var seen: Array = []
	for t in tags:
		if not seen.has(t):
			seen.append(t)
	event["riders"] = seen
	if seen.has("residue"):
		event["residue"] = str(def.get("element", "")).to_lower()
	for t in seen:
		if str(t).begins_with("blend_"):
			event["blend"] = str(t).substr(6)


## ---- Elements Step 3: Blends (Mauro 5 Oct 2026) ---------------------------
## "1 attack plus other attack = element": a hit of one element on a body that
## holds this caster's Residue of another element fires the pair's Blend
## (0 AP, no crit, no mastery), then the Residue clears and this hit writes
## none. Only your own two hits make a Blend (Elements PDF §2), except Mender's
## heal (option A): the healed teammate's next hit Blends with Mender's element.
## Guard-rails (docs/BALANCE_PLAN_HANDOFF.md §4): one Blend per body until its
## own next turn ends; Pin never two turns running and blocks walking only;
## Spark 4; Sleet once per target turn.
const BLENDS := {
	"air+earth": "drift_pin",
	"air+fire": "spark",
	"air+water": "sleet",
	"earth+fire": "magma",
	"earth+water": "mire",
	"fire+water": "steam",
}
const BLEND_NAMES := {
	"drift_pin": "Drift-Pin", "spark": "Spark", "sleet": "Sleet",
	"magma": "Magma", "mire": "Mire", "steam": "Steam",
}
const SPARK_CHIP := 4
const DRIFT_COLLISION_HP := 8
const MAGMA_TICK_HP := 4
var _blend_queue: Array = []


static func blend_of(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	return str(BLENDS.get("%s+%s" % [pair[0], pair[1]], ""))


## Fires the Blend if this hit pairs with the caster's own Residue (or with a
## Mender infusion on the caster). Returns the Blend id or "".
func _try_blend(actor: Dictionary, target: Dictionary, el: String) -> String:
	if bool(target.get("blend_lock", false)):
		return ""
	var other := ""
	var used_infusion := false
	var residue := str(target.get("residue", ""))
	if residue != "" and residue != el and int(target.get("residue_seat", -1)) == int(actor["seat"]):
		other = residue
	elif str(actor.get("infusion", "")) != "" and str(actor["infusion"]) != el:
		other = str(actor["infusion"])
		used_infusion = true
	if other == "":
		return ""
	var blend := blend_of(el, other)
	if blend == "":
		return ""
	if used_infusion:
		actor["infusion"] = ""
		_emit_expire("infusion", actor["pos"], int(actor["seat"]), int(actor["seat"]))
	target["residue"] = ""
	target["residue_turns"] = 0
	target["blend_lock"] = true
	var event := {
		"type": "blend",
		"blend": blend,
		"name": BLEND_NAMES[blend],
		"elements": [other, el],
		"seat": int(actor["seat"]),
		"target_seat": int(target["seat"]),
		"to": target["pos"],
		"infused": used_infusion,
	}
	var note := ""
	match blend:
		"drift_pin":
			note = _blend_drift_pin(actor, target, event)
		"spark":
			note = _blend_spark(actor, target, event)
		"sleet":
			note = _blend_sleet(actor, target, event)
		"magma":
			target["magma_pending"] = int(actor["seat"])
			note = "the tile they end their next turn on burns for %d" % MAGMA_TICK_HP
		"mire":
			target["mire_cell"] = target["pos"]
			note = "leaving this tile costs +1 MP on their next turn"
		"steam":
			_add_element_tile("steam", target["pos"], int(actor["seat"]))
			note = "this tile blocks line of sight until %s's next turn" % str(actor.get("name", "the caster"))
	event["coach"] = "BLEND %s on %s: %s." % [BLEND_NAMES[blend], str(target.get("name", "")), note]
	_blend_queue.append(event)
	return blend


## Mender option A (Mauro 5 Oct 2026 "lets try a and b for mender"): a Mender
## heal on a teammate gives that teammate the heal's element until the end of
## its next turn. Its next hit of another element fires that pair's Blend.
func _infuse(actor: Dictionary, target: Dictionary, def: Dictionary) -> String:
	if str(actor.get("class_id", "")) != SpellKits.CLASS_MENDER or int(actor["seat"]) == int(target["seat"]):
		return ""
	var el := _rider_element(actor, def)
	if el == "":
		return ""
	target["infusion"] = el
	target["infusion_seat"] = int(actor["seat"])
	return el


## Drift-Pin (Air + Earth): slide 1 away from the caster; a wall or body in
## the way hits for 8 instead. Pin: no walking (MP) next turn; Advance and
## Ambush still work. Never two turns running.
func _blend_drift_pin(actor: Dictionary, target: Dictionary, event: Dictionary) -> String:
	var from: Vector2i = target["pos"]
	var result := _try_push(actor["pos"], target, 1, true)
	var note := ""
	if bool(result.get("moved", false)):
		_apply_landing_punishments(target, result)
		note = "slides 1"
	elif bool(result.get("bounced", false)):
		# _try_push(earth) hits a wall for 8 (once per target per turn).
		note = "slams into the wall (%d)" % int(result.get("stagger_hp", 0))
	elif str(result.get("reason", "")) == "occupied":
		target["hp"] = maxi(0, int(target["hp"]) - DRIFT_COLLISION_HP)
		event["collision_hp"] = DRIFT_COLLISION_HP
		note = "slams into a body (%d)" % DRIFT_COLLISION_HP
	else:
		note = "holds its ground"
	event["from"] = from
	event["to"] = target["pos"]
	event["slide"] = result.duplicate()
	if bool(target.get("pinned", false)) or bool(target.get("pinned_last", false)):
		note += "; no Pin (Pinned last turn)"
	else:
		target["pin_pending"] = true
		event["pin"] = true
		note += "; Pinned: cannot walk next turn"
	return note


## Sleet (Air + Water), Mauro 5 Oct 2026: "instead of taking away 1 mp pushes
## 2 spaces back". Two pushes of 1 away from the caster, one tile at a time:
## a body stops it (no damage), a wall / the edge bounces with the usual
## stagger, a hazard tile ends the slide there. Grounded / Plant: no push.
const SLEET_PUSH := 2


func _blend_sleet(actor: Dictionary, target: Dictionary, event: Dictionary) -> String:
	var from: Vector2i = target["pos"]
	var moved := 0
	var last := {}
	for i in SLEET_PUSH:
		last = _try_push(actor["pos"], target, 1, false)
		if not bool(last.get("moved", false)):
			break
		moved += 1
		_apply_landing_punishments(target, last)
		if str(last.get("reason", "")) != "":
			# Lava / water / mud: the slide ends in the hazard.
			break
	event["from"] = from
	event["to"] = target["pos"]
	event["pushed_tiles"] = moved
	event["push"] = last.duplicate()
	if moved > 0:
		return "pushed %d tile%s back" % [moved, "" if moved == 1 else "s"]
	if bool(last.get("bounced", false)):
		return "slams into the wall (%d)" % int(last.get("stagger_hp", 0))
	return "holds its ground"


## Spark (Air + Fire): 4 Neutral chip (no resist, eats shield first), then
## push 1 away from the caster (Grounded / Plant: chip lands, no push).
func _blend_spark(actor: Dictionary, target: Dictionary, event: Dictionary) -> String:
	var chip := SPARK_CHIP
	var shield := int(target.get("shield", 0))
	var soaked := mini(shield, chip)
	target["shield"] = shield - soaked
	target["hp"] = maxi(0, int(target["hp"]) - (chip - soaked))
	event["chip"] = chip
	event["shield_soaked"] = soaked
	var from: Vector2i = target["pos"]
	var result := _try_push(actor["pos"], target, 1, false)
	if bool(result.get("moved", false)):
		_apply_landing_punishments(target, result)
	event["from"] = from
	event["to"] = target["pos"]
	event["push"] = result.duplicate()
	return "%d chip%s" % [chip, ", pushed 1" if bool(result.get("moved", false)) else ""]


func _add_element_tile(kind: String, cell: Vector2i, owner_seat: int) -> void:
	for tile in _element_tiles:
		if str(tile["kind"]) == kind and tile["pos"] == cell:
			# Refresh, do not double.
			tile["owner_seat"] = owner_seat
			return
	_element_tiles.append({"kind": kind, "pos": cell, "owner_seat": owner_seat})


func element_tile_at(cell: Vector2i, kind: String) -> bool:
	for tile in _element_tiles:
		if str(tile["kind"]) == kind and tile["pos"] == cell:
			return true
	return false


## Slagcrown's boiling water: its steam blocks sight (CellTagMap.SIGHT_TERRAIN).
func _map_steam_at(cell: Vector2i) -> bool:
	if _map_id == "" or _board == null:
		return false
	var tile = _board.tile_at(cell)
	if tile == null:
		return false
	return _CellTagMap.terrain_blocks_sight(_map_id, str(_TerrainDef.NAMES.get(int(tile.terrain_type), "")))


## Cells that steam for the board view (looping steam over them): boiling
## terrain and the round pits that hold boiling water (CellTagMap.STEAM_PROPS).
func _map_steam_snapshot() -> Array:
	var out: Array = []
	var id := _CellTagMap.normalize_id(_map_id)
	if _map_id == "" or _board == null or not (_CellTagMap.SIGHT_TERRAIN.has(id) or _CellTagMap.STEAM_PROPS.has(id)):
		return out
	for y in int(_board.height):
		for x in int(_board.width):
			var cell := Vector2i(x, y)
			if _map_steam_at(cell) or _CellTagMap.props_steam(_map_id, _paint_only.get(cell, [])):
				out.append({"x": x, "y": y, "pos": cell})
	return out


func _element_tile_snapshot() -> Array:
	var out: Array = []
	for tile in _element_tiles:
		var cell: Vector2i = tile["pos"]
		out.append({"kind": str(tile["kind"]), "x": cell.x, "y": cell.y, "pos": cell, "owner_seat": int(tile["owner_seat"])})
	return out


## Magma and Steam last until the blender's next turn starts.
func _expire_element_tiles(owner: Dictionary) -> void:
	var keep: Array = []
	for tile in _element_tiles:
		if int(tile["owner_seat"]) == int(owner["seat"]):
			_emit_expire(str(tile["kind"]), tile["pos"], int(owner["seat"]), int(owner["seat"]))
		else:
			keep.append(tile)
	_element_tiles = keep


## A unit's own turn is ending: its pending Magma is painted, Magma ticks, and
## the one-turn Blend statuses (Pin, Mire, the Blend lock, Mender's infusion) end.
func _end_turn_elements(unit: Dictionary) -> void:
	if not bool(unit.get("alive", false)):
		return
	if unit.has("magma_pending"):
		_add_element_tile("magma", unit["pos"], int(unit["magma_pending"]))
		unit.erase("magma_pending")
	if element_tile_at(unit["pos"], "magma"):
		unit["hp"] = maxi(0, int(unit["hp"]) - MAGMA_TICK_HP)
		_last_events.append({
			"type": "magma",
			"target_seat": int(unit["seat"]),
			"to": unit["pos"],
			"damage": MAGMA_TICK_HP,
			"hp_delta": -MAGMA_TICK_HP,
			"hp": int(unit["hp"]),
			"coach": "%s ends the turn on Magma (−%d HP)." % [str(unit.get("name", "Unit")), MAGMA_TICK_HP],
		})
		_check_death(unit, "magma")
	unit["pinned_last"] = bool(unit.get("pinned", false))
	if bool(unit.get("pinned", false)):
		unit["pinned"] = false
		_emit_expire("pinned", unit["pos"], int(unit["seat"]), int(unit["seat"]))
	if unit.has("mire_cell"):
		unit.erase("mire_cell")
		_emit_expire("mire", unit["pos"], int(unit["seat"]), int(unit["seat"]))
	unit["blend_lock"] = false
	if str(unit.get("infusion", "")) != "":
		unit["infusion"] = ""
		_emit_expire("infusion", unit["pos"], int(unit["seat"]), int(unit["seat"]))


## A unit's turn starts: Pin arms.
func _start_turn_elements(unit: Dictionary) -> void:
	if bool(unit.get("pin_pending", false)):
		unit["pin_pending"] = false
		unit["pinned"] = true


## Extra MP to walk: Hold Line's exit tax and Mire (first step off its tile).
func _walk_tax(actor: Dictionary) -> int:
	var tax := 1 if int(actor.get("exit_tax", 0)) > 0 else 0
	if actor.has("mire_cell") and actor["mire_cell"] == actor["pos"]:
		tax += 1
	return tax


## Mauro 5 Oct 2026: "Marks and residue should dissapear if player does not
## attack for 1 turn ... if krestel attacks 1 turn leaves a residue and he gets
## marks but if the next turn he does not attack the enemy looses the marks".
## Every cast that hits or misses an enemy is noted for the caster's turn.
## When the caster's turn ends, the Marks and Residue it put on an enemy it did
## not attack this turn are gone. (The Residue clock of 2 target turns stays.)
func _note_attacks(actor: Dictionary) -> void:
	var seen: Array = actor.get("attacked_this_turn", [])
	for event in _last_events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var kind := str(event.get("type", ""))
		if kind != "hit" and kind != "miss":
			continue
		if int(event.get("seat", -1)) != int(actor["seat"]) or not event.has("target_seat"):
			continue
		var seat := int(event["target_seat"])
		var target := _unit_by_seat(seat)
		if target.is_empty() or _allied(target, actor) or seen.has(seat):
			continue
		seen.append(seat)
	actor["attacked_this_turn"] = seen


func _drop_unattended_marks(actor: Dictionary) -> void:
	var attacked: Array = actor.get("attacked_this_turn", [])
	var me := int(actor["seat"])
	for unit in _units:
		if not bool(unit.get("alive", false)) or _allied(unit, actor) or attacked.has(int(unit["seat"])):
			continue
		if int(unit.get("marks", 0)) > 0 and int(unit.get("marks_seat", -1)) == me:
			unit["marks"] = 0
			_emit_expire("marks", unit["pos"], me, int(unit["seat"]))
		if str(unit.get("residue", "")) != "" and int(unit.get("residue_seat", -1)) == me:
			unit["residue"] = ""
			unit["residue_turns"] = 0
			_emit_expire("residue", unit["pos"], me, int(unit["seat"]))
	actor["attacked_this_turn"] = []


## An Earth hero's push spell (Shoulder, Aegis Break).
func _earth_push(actor: Dictionary, def: Dictionary) -> bool:
	return _rider_element(actor, def) == "earth"


## Bastion Grounded (Earth, option C): no push moves him.
func _push_immune(target: Dictionary) -> bool:
	return bool(target.get("grounded", false)) and str(target.get("class_id", "")) == SpellKits.CLASS_BASTION


## The target's own turn ended: its Residue clock ticks.
func _tick_residue(unit: Dictionary) -> void:
	var left := int(unit.get("residue_turns", 0))
	if left <= 0 or str(unit.get("residue", "")) == "":
		return
	left -= 1
	unit["residue_turns"] = left
	if left <= 0:
		unit["residue"] = ""
		_emit_expire("residue", unit["pos"], int(unit["seat"]), int(unit["seat"]))


## Gear FLEX bonus (Mobile Sets): any non-neutral damage/heal spell gets the
## set flex_pct plus the 2-piece attune rider of its element. Stillcut 5:
## the first FLEX HIT of the fight +15% (spent on a resolved hit).
func _flex_bonus(actor: Dictionary, element: String, spend_first: bool) -> float:
	if element == "" or element == "neutral" or actor.is_empty():
		return 0.0
	var bonus := float(actor.get("flex_pct", 0))
	var riders: Variant = actor.get("flex_riders", {})
	if typeof(riders) == TYPE_DICTIONARY:
		bonus += float((riders as Dictionary).get(element, 0))
	if bool(actor.get("first_flex_ready", false)):
		bonus += float(actor.get("first_flex_pct", 0))
		if spend_first:
			actor["first_flex_ready"] = false
	return bonus


func _make_unit(seat: int, class_id: String, unit_name: String, element: String, pos: Vector2i, facing: String, placed: bool = true) -> Dictionary:
	var in_combat := placed
	return {
		"seat": seat,
		"team": 0 if seat == 0 else 1,
		"id": class_id,
		"name": unit_name,
		"class_id": class_id,
		"element": element,
		"pos": pos,
		"facing": facing,
		"hp": class_base_hp(class_id),
		"max_hp": class_base_hp(class_id),
		"ap": MAX_AP if in_combat else 0,
		"mp": MAX_MP if in_combat else 0,
		"max_ap": MAX_AP,
		"max_mp": MAX_MP,
		"marks": 0,
		"impact": 0,
		"marks_cap": SpellKits.MARKS_CAP,
		"impact_cap": SpellKits.IMPACT_CAP,
		# Mauro 30 Sep 2026: class base HP. Mastery 0, Resist 0. Combat refill stays 6 AP / 3 MP.
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
		"invisible_turns": 0,
		"shield": 0,
		"shield_turns": 0,
		"hit_immunity": 0,
		"skip_next_mp": false,
		"exit_tax": 0,
		"intercept_used": false,
		# Locked Stun (A′): stun_remaining + stunned-this-turn. Blocks move + cast + face.
		"stun_remaining": 0,
		"stunned": false,
		# Soft Lock lava Burn. Stacks 0–3 and turns left. Both 0 means not burning.
		"burn_stacks": 0,
		"burn_remaining": 0,
		# Soft Lock water: spell ids silenced on landing. One-shot, no duration.
		"silenced_spells": [],
		# Map push stacks. Slow (mud) −stack MP next turn.
		"slow_remaining": 0,
		"slow_stacks": 0,
		# Breathless (water): silenced spell slot and turns left.
		"breathless_stacks": 0,
		"breathless_remaining": 0,
		"breathless_spell": "",
		# Frozen (ice): no melee while > 0; stack 3 also Paralyzes.
		"frozen_stacks": 0,
		"frozen_remaining": 0,
		# Electrocuted (Stormspire): −stack AP next turn.
		"electro_stacks": 0,
		"electro_remaining": 0,
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
	# Mauro 5 Oct 2026 ("Players are not facing each other", deploy screenshot):
	# while placing, every placed fighter already looks at its nearest enemy.
	_face_opponents()
	if _side_all_placed(_side(seat)):
		_flow.mark_placed(_side(seat))
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
	var result := _flow.mark_ready(_side(seat))
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "units_not_placed"))
		var coach := "REJECT — place the required fighter before Ready."
		if reason == "already_ready":
			coach = "REJECT — already ready."
		elif reason == "wrong_phase":
			coach = "REJECT — deploy is over."
		return _reject(intent, reason, coach)
	var actor := _unit_by_seat(seat)
	for mate in _units:
		if _side(int(mate["seat"])) == _side(seat):
			mate["locked"] = true
	_intent_log.append(intent)
	if _flow.is_combat():
		_lock_all_units()
		# Mauro 5 Oct 2026: a match starts face to face (no free back hit).
		_face_opponents()
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
	if _flow.is_ready(_side(seat)):
		return out
	for cell in legal_deploy_cells(seat):
		out.append({"type": "place", "to": cell, "seat": seat})
	if _flow.can_ready(_side(seat)):
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


## Koliseo deploy draw: a zone tile is standable ground (not water, mud,
## lava, a prop or a wall tile).
func _zone_cell_ok(cell: Vector2i) -> bool:
	return _board.in_bounds(cell) and _board.is_walkable(cell) and not _board.is_voluntary_impassable(cell)


## Both zones reach each other on foot, both ways (same two-way walk area).
func _zones_meet(blob_a: Array, blob_b: Array) -> bool:
	var ca := int(_zone_components.get(blob_a[0], -1))
	return ca >= 0 and ca == int(_zone_components.get(blob_b[0], -2))


var _zone_components: Dictionary = {}


## Label every standable tile by its two-way walk area (one flood fill).
func _walk_components() -> Dictionary:
	var never := func(_a = null, _b = null) -> bool: return false
	var label := {}
	var next_id := 0
	for y in range(_board_size):
		for x in range(_board_size):
			var start := Vector2i(x, y)
			if label.has(start) or not _zone_cell_ok(start):
				continue
			label[start] = next_id
			var stack: Array = [start]
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				for dir in FACING_VEC.values():
					var n: Vector2i = cur + dir
					if label.has(n) or not _zone_cell_ok(n):
						continue
					if bool(_board.step_cost(cur, n, never).get("ok", false)) and bool(_board.step_cost(n, cur, never).get("ok", false)):
						label[n] = next_id
						stack.append(n)
			next_id += 1
	return label


func _force_spawn(seat: int, cell: Vector2i) -> void:
	var actor := _unit_by_seat(seat)
	if actor.is_empty():
		return
	actor["pos"] = cell
	actor["placed"] = true
	actor["locked"] = true
	actor["ap"] = int(actor.get("max_ap", MAX_AP))
	actor["mp"] = int(actor.get("max_mp", MAX_MP))
	_flow.mark_placed(_side(seat))


func _lock_all_units() -> void:
	for unit in _units:
		unit["locked"] = true
		unit["placed"] = true


## Mauro 5 Oct 2026 (deploy screenshot, Ironjaw's back to Kestrel): "When a
## match start player always have to be facing where the other opponent is
## face to face". After deployment every fighter turns to its nearest living
## enemy: the cardinal facing that points most toward it (a tie prefers the
## east-west axis).
func _face_opponents() -> void:
	for unit in _units:
		if not bool(unit.get("alive", true)) or not bool(unit.get("placed", true)):
			continue
		var best := {}
		var best_d := 1 << 30
		for other in _units:
			if _allied(other, unit) or not bool(other.get("alive", true)) or not bool(other.get("placed", true)):
				continue
			var d := absi(int(other["pos"].x) - int(unit["pos"].x)) + absi(int(other["pos"].y) - int(unit["pos"].y))
			if d < best_d:
				best_d = d
				best = other
		if best.is_empty():
			continue
		unit["facing"] = facing_toward(unit["pos"], best["pos"], str(unit.get("facing", "S")))


static func facing_toward(from: Vector2i, to: Vector2i, fallback: String = "S") -> String:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return fallback
	if absi(delta.x) >= absi(delta.y):
		return "E" if delta.x > 0 else "W"
	return "S" if delta.y > 0 else "N"


func _begin_combat(coach: String) -> void:
	_active_seat = 0
	_turn_index = 1
	for unit in _units:
		unit["ap"] = int(unit.get("max_ap", MAX_AP))
		unit["mp"] = int(unit.get("max_mp", MAX_MP))
		unit["locked"] = true
		unit["momentum"] = false
	if _first_by_init:
		_active_seat = _init_first_seat()
		coach = _init_coach(_opening_turn_coach(""))
	if _team_size > 1:
		_build_turn_order(_active_seat)
	_still_turn_start(_unit_by_seat(_active_seat))
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
	var next_seat := _next_turn_seat(int(actor.get("seat", _active_seat)))
	var next_unit := _unit_by_seat(next_seat)
	if next_seat < 0 or next_unit.is_empty() or not next_unit["alive"]:
		_finish_match(_active_seat)
		return {}

	if int(actor.get("exit_tax", 0)) > 0:
		actor["exit_tax"] = int(actor["exit_tax"]) - 1
	_expire_turn_statuses(actor)
	_tick_residue(actor)
	_end_turn_elements(actor)
	_drop_unattended_marks(actor)
	_active_seat = next_seat
	_turn_index += 1
	_invisible_wore_off = false
	_begin_unit_turn(next_unit)
	next_unit["ap"] = int(next_unit.get("max_ap", MAX_AP))
	next_unit["mp"] = int(next_unit.get("max_mp", MAX_MP))
	if bool(next_unit.get("skip_next_mp", false)):
		next_unit["mp"] = 0
		next_unit["skip_next_mp"] = false
		# Heartstop enemy badge ends when this turn consumes the skip. MP is already 0.
		_emit_expire("skip_next_mp", next_unit["pos"], int(next_unit["seat"]), int(next_unit["seat"]))
	_still_turn_start(next_unit)
	_start_turn_elements(next_unit)
	var water_cut := 0
	if bool(next_unit.get("water_slow", false)):
		# Water rider: −1 MP at the start of this turn (once, clamp 0).
		next_unit["water_slow"] = false
		water_cut = mini(1, int(next_unit["mp"]))
		next_unit["mp"] = int(next_unit["mp"]) - water_cut
	var slow_cut := 0
	if int(next_unit.get("slow_remaining", 0)) > 0:
		slow_cut = mini(SLOW_MP * maxi(int(next_unit.get("slow_stacks", 1)), 1), int(next_unit["mp"]))
	_start_turn_timer()
	var stunned := _is_stunned(next_unit)
	if stunned:
		_last_coach = "%s's turn skipped — stunned (Locked A′)." % next_unit["name"]
	elif slow_cut > 0:
		_last_coach = "%s's turn. AP/MP refilled to %d/%d (Slow −%d MP)." % [next_unit["name"], int(next_unit["ap"]), int(next_unit["mp"]) - slow_cut, slow_cut]
	else:
		_last_coach = "%s's turn. AP/MP refilled to %d/%d." % [next_unit["name"], int(next_unit["ap"]), int(next_unit["mp"])]
	if water_cut > 0:
		_last_coach += " Water: −1 MP."
	if bool(next_unit.get("pinned", false)):
		_last_coach += " Pinned: no walking."
	if _invisible_wore_off:
		_last_coach += " Invisible wore off — %s is visible." % next_unit["name"]
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
	# Mud Slow: −stack MP for this turn only. A stunned skip still consumes it.
	_consume_mud_slow(next_unit)
	_consume_electrocuted(next_unit)
	# Soft Lock Burn ticks once this turn has started, including a stunned skip.
	_tick_burn(next_unit)
	return next_unit


## Teams: a fighter that falls on its own turn (or at its turn start) passes
## the turn on; the match goes on until a whole team is down.
func _skip_fallen_active() -> void:
	if not _multi_side() or _match_over or not _flow.is_combat():
		return
	var depth := 0
	while not _match_over and depth < 6:
		var unit := _unit_by_seat(_active_seat)
		if unit.is_empty() or bool(unit.get("alive", false)):
			break
		_handoff_seat(unit, true, "fallen")
		depth += 1
	_auto_skip_stunned_turns()


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
	if bool(actor.get("pinned", false)):
		return _reject(intent, "pinned", "REJECT — %s is Pinned (Drift-Pin): no walking this turn." % actor["name"])
	var tax := _walk_tax(actor)
	var budget := maxi(int(actor["mp"]) - tax, 0)
	var planned: Dictionary = _board.validate_move(actor["pos"], dest, budget, Callable(self, "_walk_occupied"))
	if not bool(planned.get("ok", false)):
		var reason := str(planned.get("reason", "unreachable"))
		var coach := "REJECT — illegal move (%s)." % reason
		# MP 0 is a walk. Name it so the toast is not read as a failed Ambush.
		if reason == "insufficient_mp" and int(actor.get("mp", 0)) <= 0:
			coach = "REJECT — no MP to walk."
		elif reason == "insufficient_mp" and int(planned.get("cost", 0)) > 0:
			coach = "REJECT — that path needs %d MP (you have %d)." % [int(planned["cost"]), budget]
		return _reject(intent, reason, coach)
	var from: Vector2i = actor["pos"]
	var path: Array = planned.get("path", [])
	var dist := int(planned.get("cost", 0))
	var facing_from: String = str(actor["facing"])
	var facing_hops: Array = _face_along_walk(actor, from, path)
	actor["pos"] = dest
	_spend_mp(actor, dist + tax)
	if actor.has("mire_cell"):
		# Mire taxes only the first step off its tile.
		actor.erase("mire_cell")
		_emit_expire("mire", dest, int(actor["seat"]), int(actor["seat"]))
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
	if FoeKits.is_foe_spell(spell_id):
		return _submit_foe_cast(intent, actor)
	var def: Dictionary = SpellKits.spell_for(actor, spell_id)
	if def.is_empty():
		return _reject(intent, "unknown_spell", "REJECT — unknown spell.")
	if spell_id == SpellKits.ADVANCE and str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
		return _reject(intent, "spell_not_in_kit", "REJECT — Advance is Ironjaw-only (refund).")
	if not SpellKits.has_spell(str(actor["class_id"]), spell_id):
		return _reject(intent, "spell_not_in_kit", "REJECT — %s is not in %s's kit (refund)." % [def["name"], actor["name"]])
	if _is_spell_silenced(actor, spell_id):
		return _reject(intent, "spell_silenced", "REJECT — %s is silenced (refund)." % def["name"])
	if _is_spell_frozen(actor, spell_id):
		return _reject(intent, "frozen_no_melee", "REJECT — Frozen: no melee (%s) this turn (refund)." % def["name"])
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
		if reason == "advance_limit":
			return _reject(intent, "advance_limit", "REJECT — Advance is %d uses per turn (refund)." % ADVANCE_USES_PER_TURN)
		if reason != "":
			return _reject(intent, reason, "REJECT — illegal Advance (%s)." % reason)
		return _resolve_advance(intent, actor, def, dest, advance_ap, advance_mp)

	var range_from: Vector2i = actor["pos"]
	if spell_id == SpellKits.AMBUSH:
		var ambush_enemy := _ambush_focus_enemy(actor, dest)
		var origin_cell := _ambush_measure_cell(actor, ambush_enemy)
		if origin_cell != UNPLACED:
			range_from = origin_cell
		# The Shade plate and the Invisible self-cell are the origin, not a foe.
		# Confirming that cell used to measure distance 0 ("target at 0") while
		# the enemy was a legal cardinal 1–2 and the reticle sat on that enemy.
		# Either legal origin confirms the same enemy. An illegal body still rejects.
		if _ambush_cell_is_origin(actor, dest):
			var tapped_origin := dest
			var blocked := _ambush_block_reason(actor, ambush_enemy)
			if blocked != "":
				return _reject(intent, blocked, _ambush_reject_text(blocked))
			if not ambush_enemy.is_empty():
				dest = ambush_enemy["pos"]
			# Confirming a plate chooses that origin. The enemy tap does not.
			if not intent.has("origin"):
				intent["origin"] = tapped_origin
		var ambush_pick := _ambush_selected(actor, _ambush_focus_enemy(actor, dest), intent)
		if not ambush_pick.is_empty():
			range_from = ambush_pick["origin"]
	# Cardinal kits (Ambush) share the axis gate: one of Δx/Δy is 0 and
	# |Δx|+|Δy| is inside min/max (Ambush 1–2). Chebyshev would accept a diagonal.
	var dist := _range_distance(def, range_from, dest)
	if dist < int(def["min_range"]) or dist > int(def["max_range"]):
		return _reject(intent, "out_of_range", "REJECT — %s range %d–%d, target at %d (refund)." % [def["name"], def["min_range"], def["max_range"], dist])
	if dist > _HitBands.MAX_DISTANCE:
		return _reject(intent, "out_of_range", "REJECT — %s Chebyshev %d has no locked hit %% (refund)." % [def["name"], dist])
	if not _spell_sees(def, range_from, dest):
		var wall := sight_blocker(range_from, dest, _sight_bodies(def))
		return _reject(intent, "no_line_of_sight", "REJECT — %s has no line of sight: a wall at (%d,%d) blocks it (refund)." % [def["name"], wall.x, wall.y])

	var ap_cost := int(def["ap"])
	var mp_cost := int(def["mp"])
	if int(actor["ap"]) < ap_cost:
		return _reject(intent, "insufficient_ap", "REJECT — %s costs %d AP (refund)." % [def["name"], ap_cost])
	if int(actor["mp"]) < mp_cost:
		return _reject(intent, "insufficient_mp", "REJECT — %s costs %d MP (refund)." % [def["name"], mp_cost])
	if spell_id == SpellKits.WARD or spell_id == SpellKits.HEARTSTOP:
		var early := _living_unit_at(dest)
		if not early.is_empty() and _allied(early, actor):
			if spell_id == SpellKits.WARD and int(early.get("shield", 0)) > 0:
				return _reject(intent, "open_can_wait", "REJECT — shield stacking is open (can-wait).")
			if spell_id == SpellKits.HEARTSTOP and int(early.get("hit_immunity", 0)) > 0:
				return _reject(intent, "open_can_wait", "REJECT — immunity refresh is open (can-wait).")
	var resource_gate := _resource_gate(actor, def)
	if resource_gate != "":
		return _reject(intent, resource_gate, "REJECT — %s failed gate %s (refund)." % [def["name"], resource_gate])

	var target_kind := str(def.get("target", "enemy"))
	if target_kind == "fallen_ally":
		return _resolve_revive(intent, actor, def, dest, dist, ap_cost, mp_cost)
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
		if ambush_target.is_empty() or _allied(ambush_target, actor):
			return _reject(intent, "no_target", "REJECT — Ambush needs an enemy (refund).")
		return _resolve_ambush(intent, actor, ambush_target, def, dest, dist, ap_cost, mp_cost)

	# Soft Lock. An empty tile beside exactly one in-range legal enemy is that
	# enemy. Same Chebyshev neighborhood as the #194 trough snap. Ground uses
	# it too: the trough was the first case, not a separate rule. Zero neighbors
	# and two or more stay the tapped cell.
	if _living_unit_at(dest).is_empty() and (target_kind == "enemy" or target_kind == "any"):
		var beside := _soft_lock_neighbor_target(actor, def, range_from, dest)
		if not beside.is_empty():
			dest = beside["pos"]
			dist = _range_distance(def, range_from, dest)
	var target := _living_unit_at(dest)
	if target.is_empty() and target_kind == "enemy" and _has_invisible_hostile(int(actor["seat"])) and _in_spell_reach(def, range_from, dest):
		return _resolve_whiff(intent, actor, def, dest, ap_cost, mp_cost)
	if target.is_empty():
		return _reject(intent, "no_target", "REJECT — %s needs a living unit (refund)." % def["name"])
	var support := target_kind == "ally" or (target_kind == "any" and _allied(target, actor))
	if support:
		if target_kind == "ally" and not _allied(target, actor):
			return _reject(intent, "no_target", "REJECT — %s needs an ally (refund)." % def["name"])
		return _resolve_support(intent, actor, target, def, dest, dist, ap_cost, mp_cost)
	if _allied(target, actor):
		return _reject(intent, "no_target", "REJECT — %s needs an enemy (refund)." % def["name"])
	var gate := _cast_gate_reason(actor, target, def)
	if gate != "":
		return _reject(intent, gate, "REJECT — %s failed gate %s (refund)." % [def["name"], gate])
	return _resolve_rolling_cast(intent, actor, target, def, dest, dist, ap_cost, mp_cost)


func _resolve_advance(intent: Dictionary, actor: Dictionary, _def: Dictionary, dest: Vector2i, ap_cost: int, mp_cost: int) -> Dictionary:
	actor["momentum"] = true
	if str(actor["class_id"]) != SpellKits.CLASS_IRONJAW:
		return _reject(intent, "spell_not_in_kit", "REJECT — Advance is Ironjaw-only (refund).")
	var from: Vector2i = actor["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	actor["advance_uses"] = int(actor.get("advance_uses", 0)) + 1
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
	_spend_mp(actor, mp_cost)
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
		_break_invisible_on_attack(actor)
		_last_events.append(miss_event)
		return _accept()

	var base := _connect_base_damage(def, target)
	# Mobile Stasis foes only. Koliseo units never set stasis_attack_base.
	# This replaces the stand-in card's Locked base for that foe. The facing
	# multiplier below stays the Locked Phase A formula. Player casts do not
	# carry the key, so kit damage is unchanged.
	if int(actor.get("stasis_attack_base", -1)) >= 0:
		base = int(actor["stasis_attack_base"])
	var pre_mitigation := _phase_a_damage(base, facing_mult, actor, target, str(def.get("element", "")), true)
	var mitigation := _mitigate_hit(actor, target, pre_mitigation)
	var damage := int(mitigation["damage"])
	target["hp"] = int(target["hp"]) - damage
	if int(target["hp"]) < 0:
		target["hp"] = 0
	_reveal_if_hurt(target, damage)
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
			engine_gained = _gain_marks(target, 1, int(actor["seat"]))
			engine_name = "Mark"
		"consume_marks":
			# A01 Locked: consume Marks from the target on connect.
			marks_consumed = _consume_marks(target)
			engine_name = "Mark"
			engine_spent = marks_consumed
		"spend_impact":
			var spend_amount := int(def.get("spend_impact", 2))
			# Mauro 1 Oct 2026: a Crush that stuns (Impact 4 before) spends ALL
			# Impact, so Ironjaw cannot stun every other turn.
			if spell_id == SpellKits.CRUSH and impact_before >= int(def.get("stun_if_impact_before", 4)):
				spend_amount = impact_before
			engine_spent = _spend_impact(actor, spend_amount)
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
		# Lava displaces and Burns. Water silences one spell. Mud slows −1 MP.
		push_result = _try_push(actor["pos"], target, int(def["push_cells"]), _earth_push(actor, def))
	if defer_shoulder_impact:
		var impact_amount := SHOULDER_CONNECT_IMPACT
		if bool(push_result.get("bounced", false)):
			impact_amount = SHOULDER_BOUNCE_IMPACT
		engine_gained = _gain_impact(actor, impact_amount)
	var punish := _apply_landing_punishments(target, push_result)
	var burn_info: Dictionary = punish["burn"]
	var silence_info: Dictionary = punish["silence"]
	var slow_info: Dictionary = punish["slow"]

	var facing_note := "front/side ×1.00"
	if is_back:
		facing_note = "BACK ×1.35" if str(actor.get("class_id", "")) == SpellKits.CLASS_GLOAM else "BACK ×1.20"
	var extra_note := _connect_extra_note(engine_gained, engine_name, marks_consumed, engine_spent, stun_applied, push_result)
	# Coach label only. Spell id stays the stand-in card so VFX and legal
	# intents keep working. Set only when the provisional base is also set.
	var strike_name := str(def["name"])
	if int(actor.get("stasis_attack_base", -1)) >= 0 and str(actor.get("stasis_attack_name", "")) != "":
		strike_name = str(actor["stasis_attack_name"])
	_last_coach = "HIT %d %s — %s vs %s (%d vs %d%%) %s.%s" % [damage, str(def["element"]).capitalize(), strike_name, target["name"], roll, chance, facing_note, extra_note]
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
			hit_event["burn_stacks"] = int(burn_info.get("stacks", 0))
			hit_event["burn_previous_stacks"] = int(burn_info.get("previous_stacks", 0))
			hit_event["land_hp"] = int(burn_info.get("land_hp", 0))
		hit_event["silence_applied"] = not silence_info.is_empty()
		if not silence_info.is_empty():
			hit_event["silenced_spell"] = str(silence_info.get("spell", ""))
		hit_event["slow_applied"] = not slow_info.is_empty()
		if not slow_info.is_empty():
			hit_event["slow_remaining"] = int(slow_info.get("remaining", 0))
			hit_event["slow_refreshed"] = bool(slow_info.get("refreshed", false))
	if skip_next_mp:
		hit_event["skip_next_mp"] = true
	var rider_tags := _flex_target(actor, target, def)
	rider_tags.append_array(_flex_caster(actor, def))
	_stamp_riders(hit_event, rider_tags, def)
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
	_append_lava_castigo(target, burn_info)
	_append_soft_lock_status(target, silence_info, slow_info)
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
	_break_invisible_on_attack(actor)
	return _accept()


## Reached only after an existing HP loss. cause names that path for the view.
## "damage" is a spell hit, Hold Line, Ambush, or an Intercept transfer.
## "burn" is a Soft Lock Burn tick. Stagger and lava land do not call this.
## There is no separate execute path.
func _check_death(target: Dictionary, cause: String = "damage") -> void:
	if int(target["hp"]) > 0:
		return
	# End Still: once, a lethal hit leaves you at 1 HP.
	if str(target.get("still", "")) == "end" and bool(target.get("still_ready", false)):
		target["still_ready"] = false
		target["hp"] = 1
		_still_fired(target, "end")
		return
	target["alive"] = false
	# Death clears Residue and the element riders on this body.
	target["residue"] = ""
	target["residue_turns"] = 0
	target["water_slow"] = false
	target["grounded"] = false
	for key in ["pin_pending", "pinned", "magma_pending", "mire_cell", "infusion", "blend_lock"]:
		target.erase(key)
	_last_events.append({
		"type": "dead",
		"seat": target["seat"],
		"name": target["name"],
		"cause": cause,
		"coach": "%s falls." % target["name"],
	})
	# Stasis Room A keeps fighting until the player or every hostile is down.
	# Koliseo is still one death ends the match.
	if _stasis_pack:
		# A party loses only when every hero is down.
		if _team_of(target) == 0:
			if not _team_alive(0):
				_finish_match(_stasis_winner_hostile())
		elif _living_stasis_hostiles().is_empty():
			_finish_match(0)
		return
	if _team_size > 1:
		# Teams: the match ends when a whole team is down.
		var fallen_team := _team_of(target)
		if _team_alive(fallen_team):
			return
		for unit in _units:
			if _team_of(unit) != fallen_team and bool(unit.get("alive", false)):
				_finish_match(int(unit["seat"]))
				return
		return
	_finish_match(_enemy_of(int(target["seat"]))["seat"])


func _finish_match(winner: int) -> void:
	_match_over = true
	_winner_seat = winner
	_winner_team = team_of_seat(winner) if winner >= 0 else -1
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


## Mauro, 30 Sep 2026: "ironjaw spell advance only can be used 2 times"
## (per turn; the counter resets at each Ironjaw turn start).
const ADVANCE_USES_PER_TURN := 2


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
	if int(actor.get("advance_uses", 0)) >= ADVANCE_USES_PER_TURN:
		return "advance_limit"
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
	var gate := _flow.place_gate(_side(seat), cell, _deploy_occupant(cell, seat))
	if not bool(gate.get("ok", false)):
		return gate
	# Deploy: occupancy + walkable (lava / override). No elevation MP / climb cost.
	if not _board.is_walkable(cell):
		return {"ok": false, "reason": "not_walkable", "zone_kind": ""}
	return gate


func _seed_play_board(config: Dictionary) -> void:
	# flat_board: Ground z0. Proto 8: crop + noise. Proto 12: Mauro tokens.
	# Ship 15: Koliseo tags when the file size matches. Empty map_id is Crosshaven.
	# Dress paint stays visual. Solid props on the same tags are not walkable.
	# An explicit cell_tags path uses the same hook.
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


func _apply_stasis_roster(config: Dictionary) -> void:
	# Absent key: Koliseo / tests. Do not invent dungeon HP on those matches.
	if not config.has("stasis_roster"):
		return
	var roster: Variant = config["stasis_roster"]
	if typeof(roster) != TYPE_ARRAY:
		return
	var hostile_count := 0
	for entry in roster:
		if typeof(entry) == TYPE_DICTIONARY and int((entry as Dictionary).get("seat", -1)) >= _party_size:
			hostile_count += 1
	# Room A puts the trash pack on the board together. Room B stays one boss.
	# A party always walks the living seats in order (heroes, then monsters).
	_stasis_pack = hostile_count >= 2 or _party_size > 1
	for entry in roster:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = entry
		var seat := int(rec.get("seat", -1))
		var unit := _unit_by_seat(seat)
		if unit.is_empty() and seat > _party_size and _stasis_pack:
			var foe_name := str(rec.get("name", "Trash"))
			unit = _make_unit(seat, SpellKits.CLASS_IRONJAW, foe_name, SpellKits.element_of(SpellKits.CLASS_IRONJAW), UNPLACED, "S", false)
			unit["team"] = 1
			_units.append(unit)
		if unit.is_empty():
			continue
		if str(rec.get("name", "")) != "":
			unit["name"] = str(rec["name"])
		# Worn gear first, so a carried Room A hp clamps to the geared max.
		if rec.has("gear"):
			_apply_gear(unit, rec["gear"])
		if rec.has("max_hp"):
			var max_hp := maxi(int(rec["max_hp"]), 1)
			unit["max_hp"] = max_hp
			unit["hp"] = mini(int(unit.get("hp", max_hp)), max_hp)
		if rec.has("hp"):
			var cap := maxi(int(unit.get("max_hp", class_base_hp(str(unit.get("class_id", ""))))), 1)
			unit["hp"] = mini(maxi(int(rec["hp"]), 0), cap)
		if rec.has("facing"):
			var face := str(rec["facing"]).to_upper()
			if FACING_VEC.has(face):
				unit["facing"] = face
		# Provisional Open playtest base. Not Strike's 14 (Mauro 30 Sep 2026 balance).
		if rec.has("attack_base"):
			unit["stasis_attack_base"] = maxi(int(rec["attack_base"]), 0)
		if str(rec.get("attack_name", "")) != "":
			unit["stasis_attack_name"] = str(rec["attack_name"])
		# Package crop. The class id stays Ironjaw only so Strike is in the kit.
		# The pawn draws this path and does not play the Ironjaw sheet.
		if str(rec.get("sprite", "")) != "":
			unit["stasis_sprite"] = str(rec["sprite"])
		# View flag only (bigger body + aura on the board). No rule reads it.
		if bool(rec.get("boss", false)):
			unit["stasis_boss"] = true
		# Stasis monster kit (FoeKits ids), role, door and AP / MP.
		if rec.get("foe_kit", null) is Array:
			var kit: Array = []
			for spell_id in rec["foe_kit"]:
				if FoeKits.is_foe_spell(str(spell_id)):
					kit.append(str(spell_id))
			unit["foe_kit"] = kit
			unit["foe_cd"] = {}
			unit["foe_role"] = str(rec.get("role", ""))
			unit["foe_door"] = str(rec.get("door", ""))
			unit["foe_dmg_mult"] = float(rec.get("dmg_mult", 1.0))
		if rec.has("max_ap"):
			unit["max_ap"] = maxi(int(rec["max_ap"]), 1)
			unit["ap"] = int(unit["max_ap"])
		if rec.has("max_mp"):
			unit["max_mp"] = maxi(int(rec["max_mp"]), 0)
			unit["mp"] = int(unit["max_mp"])
		var raw_spells: Variant = rec.get("spells", null)
		if raw_spells is Array:
			var spells: Array = []
			for spell_id in raw_spells:
				var id := str(spell_id)
				if SpellKits.has_spell(str(unit.get("class_id", "")), id):
					spells.append(id)
			if not spells.is_empty():
				unit["spells"] = spells


## Online: a peer's gear can land after the host reset the match. It is
## applied while both sides are still deploying, never mid-combat.
func set_seat_gear(seat: int, gear: Dictionary) -> bool:
	if _flow == null or not _flow.is_deployment():
		return false
	var unit := _unit_by_seat(seat)
	if unit.is_empty():
		return false
	_apply_gear(unit, gear)
	return true


## Room Tonic (Mauro 29 Sep 2026): Stasis intermission only. The fight must
## be over and won by `seat`; heals floor(30% max HP), never over max. The
## healed HP is what Room B carries. Returns the HP actually restored.
func intermission_heal(seat: int, pct: int) -> int:
	if not _match_over or _winner_seat != seat:
		return 0
	var unit := _unit_by_seat(seat)
	if unit.is_empty():
		return 0
	var max_hp := int(unit.get("max_hp", class_base_hp(str(unit.get("class_id", "")))))
	var hp := int(unit.get("hp", 0))
	var healed := mini(int(floor(float(max_hp) * float(pct) / 100.0)), max_hp - hp)
	if healed <= 0:
		return 0
	unit["hp"] = hp + healed
	return healed


## Worn gear from the roster: {"worn": [{item_id, plus}], "attune": {family: element}}.
## GearBag.combat_stats sanitises it (valid ids, one per slot, +0–+5, AP/MP 8/5).
func _apply_gear(unit: Dictionary, raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var gear: Dictionary = raw
	var attune_raw: Variant = gear.get("attune", {})
	var stats := GearBag.combat_stats(gear.get("worn", []), attune_raw if typeof(attune_raw) == TYPE_DICTIONARY else {}, bool(gear.get("flatten_plus", false)))
	# Levels (HeroProgress): inherent growth + spent points, recomputed here.
	var class_id := str(unit.get("class_id", ""))
	var hero_raw: Variant = gear.get("hero", {})
	var heroes: Variant = gear.get("heroes", {})
	if typeof(heroes) == TYPE_DICTIONARY and (heroes as Dictionary).has(class_id):
		hero_raw = heroes[class_id]
	var hero := HeroProgress.combat_stats(hero_raw, class_id)
	# Elements Step 3: the player's spell → element picks. A hero entry with
	# no "elements" key (AI companions, tests) keeps the kit elements.
	if typeof(hero_raw) == TYPE_DICTIONARY and (hero_raw as Dictionary).has("elements"):
		unit["spell_elements"] = GearBag.clean_spell_elements(class_id, hero_raw["elements"])
	# Mauro 30 Sep 2026: class base HP. Final HP = (class base + level HP + part HP) × (1 + set HP%).
	var base_hp := class_base_hp(class_id)
	var max_hp := roundi(float(base_hp + int(hero["hp"]) + int(stats["hp_flat"])) * (1.0 + float(stats["hp_pct"]) / 100.0))
	var was_full := int(unit.get("hp", base_hp)) >= int(unit.get("max_hp", base_hp))
	unit["max_hp"] = max_hp
	unit["hp"] = max_hp if was_full else mini(int(unit.get("hp", max_hp)), max_hp)
	unit["mastery"] = int(stats["mastery"]) + int(hero["mastery"])
	unit["resist"] = int(stats["resist"])
	var resist_elem: Dictionary = (stats["resist_elem"] as Dictionary).duplicate()
	# Ward only guards the element of an active 2-piece attune.
	for element in stats["attuned"]:
		resist_elem[element] = int(resist_elem.get(element, 0)) + int(hero["ward"])
	unit["resist_elem"] = resist_elem
	unit["level"] = int(hero["level"])
	unit["flex_pct"] = int(stats["flex_pct"])
	unit["flex_riders"] = (stats["riders"] as Dictionary).duplicate()
	unit["first_flex_pct"] = int(stats["first_flex_pct"])
	unit["first_flex_ready"] = int(stats["first_flex_pct"]) > 0
	unit["init"] = int(stats["init"]) + int(hero["init"])
	unit["max_ap"] = mini(int(stats["ap"]) + int(hero["ap"]), GearBag.AP_CAP)
	unit["max_mp"] = int(stats["mp"])
	unit["gear"] = GearBag.clean_worn(gear.get("worn", []))
	# XII Still (one fight). Ready flags arm the one-shot effects.
	var still := StillVault.clean(gear.get("still", {}))
	unit["still"] = str(still.get("id", ""))
	unit["still_mode"] = str(still.get("mode", ""))
	unit["still_ready"] = unit["still"] != ""
	unit["own_turn"] = 0
	if bool(unit.get("placed", false)) and _flow != null and _flow.is_combat():
		unit["ap"] = mini(int(unit.get("ap", 0)), int(unit["max_ap"]))
		unit["mp"] = mini(int(unit.get("mp", 0)), int(unit["max_mp"]))


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
		unit["hp"] = mini(maxi(value, 0), int(unit.get("max_hp", class_base_hp(str(unit.get("class_id", ""))))))
		return
	var cap := int(unit.get("%s_cap" % field, value))
	unit[field] = mini(maxi(value, 0), cap)


func _roster_class_ids(config: Dictionary) -> Array[String]:
	var fallback: Array[String] = [SpellKits.CLASS_KESTREL, SpellKits.CLASS_IRONJAW]
	if _team_size > 1 and not (config.has("classes") or config.has("seat_classes")):
		var pad: Array[String] = []
		for i in 2 * _team_size:
			pad.append(fallback[i % 2])
		return pad
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
	var want := 2 * _team_size
	if _party_size > 1:
		want = _party_size + 1
	if (_team_size > 1 or _party_size > 1) and incoming.size() < want:
		var padded: Array[String] = []
		for i in want:
			padded.append(fallback[i % 2])
		return padded
	if incoming.size() < 2:
		return fallback
	var out: Array[String] = []
	for i in want:
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


## Seat 0's side against the best Init on the other side. Tie = coin flip
## from the sim RNG (host authority; never "host first").
## Teams: each team sorted by Init (high first, ties by seat), the starting
## team first, then A1 B1 A2 B2 A3 B3. A fallen fighter is skipped.
func _build_turn_order(first_seat: int) -> void:
	_turn_order.clear()
	var lists := [[], []]
	for unit in _units:
		lists[_team_of(unit)].append(unit)
	for team in 2:
		(lists[team] as Array).sort_custom(func(a, b):
			if int(a.get("init", 0)) != int(b.get("init", 0)):
				return int(a.get("init", 0)) > int(b.get("init", 0))
			return int(a["seat"]) < int(b["seat"]))
	var first_team := team_of_seat(first_seat)
	var a: Array = lists[first_team]
	var b: Array = lists[1 - first_team]
	# The chosen opener leads its own team's list.
	for i in a.size():
		if int(a[i]["seat"]) == first_seat:
			a.push_front(a.pop_at(i))
			break
	for i in maxi(a.size(), b.size()):
		if i < a.size():
			_turn_order.append(int(a[i]["seat"]))
		if i < b.size():
			_turn_order.append(int(b[i]["seat"]))


func turn_order() -> Array[int]:
	return _turn_order.duplicate()


func _init_first_seat() -> int:
	if _multi_side():
		return _init_first_team_seat()
	# Opening Still: that side acts first whatever the Init (both → Init).
	var openers: Array[int] = []
	for unit in _units:
		if str(unit.get("still", "")) == "opening" and bool(unit.get("alive", true)):
			openers.append(int(unit.get("seat", -1)))
	if openers.size() == 1:
		_init_note = "Opening Still"
		return openers[0]
	var mine := int(_unit_by_seat(0).get("init", 0))
	var theirs := -1
	var their_seat := -1
	for unit in _units:
		var seat := int(unit.get("seat", -1))
		if seat == 0 or not bool(unit.get("alive", true)):
			continue
		var v := int(unit.get("init", 0))
		if v > theirs or (v == theirs and seat < their_seat):
			theirs = v
			their_seat = seat
	if their_seat < 0:
		return 0
	if mine > theirs:
		_init_note = "Init %d vs %d" % [mine, theirs]
		return 0
	if theirs > mine:
		_init_note = "Init %d vs %d" % [theirs, mine]
		return their_seat
	_init_note = "Init tie %d — coin flip" % mine
	return 0 if _rng.randi_range(0, 1) == 0 else their_seat


## Teams: the team whose best Init is higher starts (Opening Still wins;
## tie = coin flip); that fighter opens.
func _init_first_team_seat() -> int:
	var best := [-1, -1]
	var best_seat := [-1, -1]
	var opener := -1
	for unit in _units:
		var team := _team_of(unit)
		var v := int(unit.get("init", 0))
		if str(unit.get("still", "")) == "opening" and opener < 0:
			opener = int(unit["seat"])
		if v > int(best[team]) or (v == int(best[team]) and int(unit["seat"]) < int(best_seat[team])):
			best[team] = v
			best_seat[team] = int(unit["seat"])
	if opener >= 0:
		_init_note = "Opening Still"
		return opener
	if int(best[0]) > int(best[1]):
		_init_note = "Init %d vs %d" % [best[0], best[1]]
		return int(best_seat[0])
	if int(best[1]) > int(best[0]):
		_init_note = "Init %d vs %d" % [best[1], best[0]]
		return int(best_seat[1])
	_init_note = "Init tie %d — coin flip" % int(best[0])
	return int(best_seat[0]) if _rng.randi_range(0, 1) == 0 else int(best_seat[1])


func _init_coach(_fallback: String) -> String:
	var actor := _unit_by_seat(_active_seat)
	return "%s: %s starts. %d AP / %d MP." % [_init_note, str(actor.get("name", "")), int(actor.get("max_ap", MAX_AP)), int(actor.get("max_mp", MAX_MP))]


func init_note() -> String:
	return _init_note


func _opening_turn_coach(lead: String) -> String:
	var actor := _unit_by_seat(0)
	var who := str(actor.get("name", "Kestrel"))
	if lead == "":
		return "%s's turn. 6 AP / 3 MP." % who
	return "%s %s's turn. 6 AP / 3 MP." % [lead, who]


func _begin_unit_turn(unit: Dictionary) -> void:
	unit["momentum"] = false
	_expire_element_tiles(unit)
	# Earth rider: Grounded lasts until the caster's next turn.
	if bool(unit.get("grounded", false)):
		unit["grounded"] = false
		_emit_expire("grounded", unit["pos"], int(unit["seat"]), int(unit["seat"]))
	unit["advance_uses"] = 0
	_tick_foe_cooldowns(unit)
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
	_tick_invisible(unit)
	_tick_snap_walls(unit)
	_tick_shield(unit)
	if str(unit.get("class_id", "")) == SpellKits.CLASS_BASTION:
		unit["intercept_used"] = false


## Owner turn-start clock for Invisible (see _resolve_fade).
func _tick_invisible(unit: Dictionary) -> void:
	var left := int(unit.get("invisible_turns", 0))
	if left <= 0 or not bool(unit.get("invisible", false)):
		return
	left -= 1
	unit["invisible_turns"] = left
	if left <= 0:
		unit["invisible"] = false
		_emit_expire("invisible", unit["pos"], int(unit["seat"]), int(unit["seat"]))
		_invisible_wore_off = true


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
				parts.append(" Lava %d HP, then Burn." % LAVA_LAND_HP)
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


func _gain_marks(unit: Dictionary, amount: int, owner_seat: int = -1) -> int:
	# A01 Locked: Marks live on the target unit this helper is called with.
	var before: int = int(unit["marks"])
	if owner_seat >= 0:
		unit["marks_seat"] = owner_seat
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


func _try_push(caster_pos: Vector2i, target: Dictionary, cells: int, earth: bool = false) -> Dictionary:
	# Chebyshev push 1 along the caster→target line.
	# Director Locked Shoulder:
	# - occupied dest: push_blocked (no bounce, no stagger)
	# - lava dest: displace and flag Burn
	# - water dest: displace and flag one-shot Silence
	# - mud dest: displace and flag Slow (−1 MP, 1 turn)
	# - OOB / truly blocked (not those tiles): bounce + stagger
	# - walkable empty ground: push
	# Do not invent climb/drop push rules. Voluntary walk rejects mud, water, and lava.
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
		"silence": false,
		"slow": false,
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
	if _push_immune(target):
		# Earth rider (Bastion only): Grounded blocks every push.
		result["blocked"] = true
		result["reason"] = "grounded"
		return result
	result["earth"] = earth
	if not _in_bounds(dest):
		return _apply_bounce_stagger(target, result, "out_of_bounds")
	if not _is_empty(dest):
		result["blocked"] = true
		result["reason"] = "occupied"
		return result
	if _board.is_voluntary_impassable(dest):
		target["pos"] = dest
		result["to"] = dest
		result["moved"] = true
		var terrain_id := int(_board.terrain_of(dest).get("id", _TerrainDef.Id.GROUND))
		result["reason"] = _TerrainDef.name_of(terrain_id)
		result["frozen"] = false
		result["electrocuted"] = false
		if terrain_id == _TerrainDef.Id.LAVA:
			result["burn"] = true
		elif terrain_id == _TerrainDef.Id.WATER:
			var family := hazard_family_at(dest)
			result[family if family != "breathless" else "silence"] = true
		elif terrain_id == _TerrainDef.Id.MUD:
			result["slow"] = true
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


func _burn_tick_hp(stacks: int) -> int:
	var index := clampi(stacks, 0, BURN_MAX_STACKS)
	if index <= 0 or index >= BURN_STACK_HP.size():
		return 0
	return BURN_STACK_HP[index]


## Which push stack a hazard tile applies on this map ("" for none).
func hazard_family_at(cell: Vector2i) -> String:
	var terrain_id := int(_board.terrain_of(cell).get("id", _TerrainDef.Id.GROUND))
	if terrain_id == _TerrainDef.Id.LAVA:
		return "burn"
	if terrain_id == _TerrainDef.Id.MUD:
		return "slow"
	if terrain_id == _TerrainDef.Id.WATER:
		var map := _CellTagMap.normalize_id(_map_id)
		if map == "windmere":
			return "frozen"
		if map == "stormspire":
			return "electrocuted"
		return "breathless"
	return ""


## Next stack for a family: +1 while that CC is live, else a fresh 1. Cap 3.
func _next_stack(unit: Dictionary, stacks_key: String, remaining_key: String) -> int:
	var live := int(unit.get(remaining_key, 0)) > 0 and int(unit.get(stacks_key, 0)) > 0
	return mini(int(unit.get(stacks_key, 0)) + 1, HAZARD_MAX_STACKS) if live else 1


func _apply_lava_land(unit: Dictionary, stacks: int = 1) -> int:
	# Immediate Fire on entering. Not the turn-start tick and not stagger.
	var hp := LAVA_ENTER_HP[clampi(stacks, 1, BURN_MAX_STACKS)]
	unit["hp"] = maxi(0, int(unit.get("hp", 0)) - hp)
	return hp


func _apply_burn(unit: Dictionary) -> Dictionary:
	# Re-push while burning adds a stack (cap 3); the DoT and length follow it.
	var previous_stacks := int(unit.get("burn_stacks", 0))
	var previous := int(unit.get("burn_remaining", 0))
	var stacks := _next_stack(unit, "burn_stacks", "burn_remaining")
	var turns := BURN_STACK_TURNS[stacks]
	unit["burn_stacks"] = stacks
	unit["burn_remaining"] = turns
	return {
		"applied": true,
		"refreshed": previous_stacks > 0 and previous > 0,
		"previous": previous,
		"previous_stacks": previous_stacks,
		"stacks": stacks,
		"remaining": turns,
		"hp_per_tick": _burn_tick_hp(stacks),
	}


## Lava Burn, water Silence, mud Slow. Empty dicts when that terrain did not land.
func _apply_landing_punishments(target: Dictionary, push_result: Dictionary) -> Dictionary:
	var burn := {}
	var silence := {}
	var slow := {}
	if target.is_empty():
		return {"burn": burn, "silence": silence, "slow": slow}
	if bool(push_result.get("burn", false)):
		burn = _apply_burn(target)
		burn["land_hp"] = _apply_lava_land(target, int(burn["stacks"]))
	if bool(push_result.get("silence", false)):
		silence = _apply_water_silence(target)
	if bool(push_result.get("slow", false)):
		slow = _apply_mud_slow(target)
	var frozen := {}
	var electro := {}
	if bool(push_result.get("frozen", false)):
		frozen = _apply_frozen(target)
		var paralyzed := bool(frozen.get("paralyzed", false))
		_last_events.append({
			"type": "status",
			"status": "frozen",
			"stacks": int(frozen["stacks"]),
			"remaining": int(frozen["remaining"]),
			"paralyzed": paralyzed,
			"target_seat": target["seat"],
			"coach": ("%s is Paralyzed (Frozen 3): next turn auto-ends." if paralyzed else "%s is Frozen %d: no melee for %d turn(s).") % ([target["name"]] if paralyzed else [target["name"], int(frozen["stacks"]), int(frozen["remaining"])]),
		})
	if bool(push_result.get("electrocuted", false)):
		electro = _apply_electrocuted(target)
		_last_events.append({
			"type": "status",
			"status": "electrocuted",
			"stacks": int(electro["stacks"]),
			"ap_delta": int(electro["ap_delta"]),
			"target_seat": target["seat"],
			"coach": "%s is Electrocuted %d: −%d AP next turn." % [target["name"], int(electro["stacks"]), int(electro["stacks"])],
		})
	return {"burn": burn, "silence": silence, "slow": slow, "frozen": frozen, "electro": electro}


## Breathless: one random kit spell silenced for 1/2/3 of the victim's turns.
## A re-push while Breathless keeps the same slot and lengthens it.
func _apply_water_silence(unit: Dictionary) -> Dictionary:
	var stacks := _next_stack(unit, "breathless_stacks", "breathless_remaining")
	var pick := str(unit.get("breathless_spell", "")) if stacks > 1 else ""
	if pick == "":
		var open: Array[String] = []
		for spell_id in unit.get("spells", []):
			if str(spell_id) != "":
				open.append(str(spell_id))
		if open.is_empty():
			return {}
		pick = open[_rng.randi_range(0, open.size() - 1)]
	unit["breathless_stacks"] = stacks
	unit["breathless_remaining"] = BREATHLESS_TURNS[stacks]
	unit["breathless_spell"] = pick
	unit["silenced_spells"] = [pick]
	var spell_name := str(SpellKits.spell(pick).get("name", pick))
	return {"applied": true, "spell": pick, "name": spell_name, "stacks": stacks, "remaining": BREATHLESS_TURNS[stacks]}


## Slow: −1/−2/−3 MP on the victim's next turn. A re-push while slowed stacks.
func _apply_mud_slow(unit: Dictionary) -> Dictionary:
	var previous := int(unit.get("slow_remaining", 0))
	var stacks := _next_stack(unit, "slow_stacks", "slow_remaining")
	unit["slow_stacks"] = stacks
	unit["slow_remaining"] = SLOW_TURNS
	return {
		"applied": true,
		"refreshed": previous > 0,
		"previous": previous,
		"stacks": stacks,
		"remaining": SLOW_TURNS,
		"mp_delta": -SLOW_MP * stacks,
	}


## Frozen: no melee for 1/2 turns; the third push Paralyzes (auto End Turn).
func _apply_frozen(unit: Dictionary) -> Dictionary:
	var stacks := _next_stack(unit, "frozen_stacks", "frozen_remaining")
	unit["frozen_stacks"] = stacks
	unit["frozen_remaining"] = FROZEN_TURNS[stacks]
	var paralyzed := stacks >= HAZARD_MAX_STACKS
	if paralyzed:
		unit["stun_remaining"] = maxi(int(unit.get("stun_remaining", 0)), 1)
	return {"applied": true, "stacks": stacks, "remaining": FROZEN_TURNS[stacks], "paralyzed": paralyzed}


## Electrocuted: −1/−2/−3 AP on the victim's next turn (clamp 0).
func _apply_electrocuted(unit: Dictionary) -> Dictionary:
	var stacks := _next_stack(unit, "electro_stacks", "electro_remaining")
	unit["electro_stacks"] = stacks
	unit["electro_remaining"] = ELECTRO_TURNS
	return {"applied": true, "stacks": stacks, "remaining": ELECTRO_TURNS, "ap_delta": -stacks}


## Melee = a range-1 spell aimed at another fighter (Frozen blocks these).
func _is_melee(def: Dictionary) -> bool:
	var kind := str(def.get("target", ""))
	if kind == "self" or kind == "ally" or kind == "tile" or kind == "empty_tile" or kind == "fallen_ally":
		return false
	return int(def.get("max_range", 0)) <= 1


func _is_spell_frozen(unit: Dictionary, spell_id: String) -> bool:
	if int(unit.get("frozen_remaining", 0)) <= 0:
		return false
	return _is_melee(SpellKits.spell_for(unit, spell_id))


## Breathless and Frozen count the victim's own turns: one ends here.
func _expire_turn_statuses(unit: Dictionary) -> void:
	if int(unit.get("breathless_remaining", 0)) > 0:
		unit["breathless_remaining"] = int(unit["breathless_remaining"]) - 1
		if int(unit["breathless_remaining"]) <= 0:
			unit["breathless_stacks"] = 0
			unit["breathless_spell"] = ""
			unit["silenced_spells"] = []
	if int(unit.get("frozen_remaining", 0)) > 0:
		unit["frozen_remaining"] = int(unit["frozen_remaining"]) - 1
		if int(unit["frozen_remaining"]) <= 0:
			unit["frozen_stacks"] = 0


## Electrocuted spends at the victim's turn start: −stack AP this turn.
func _consume_electrocuted(unit: Dictionary) -> void:
	if unit.is_empty() or not bool(unit.get("alive", false)):
		return
	if int(unit.get("electro_remaining", 0)) <= 0:
		return
	var stacks := maxi(int(unit.get("electro_stacks", 1)), 1)
	var cut := mini(stacks, int(unit.get("ap", 0)))
	unit["ap"] = int(unit["ap"]) - cut
	unit["electro_remaining"] = int(unit["electro_remaining"]) - 1
	if int(unit["electro_remaining"]) <= 0:
		unit["electro_stacks"] = 0
	_last_events.append({
		"type": "electrocuted",
		"status": "electrocuted",
		"target_seat": int(unit["seat"]),
		"ap_delta": -cut,
		"ap": int(unit["ap"]),
		"coach": "%s is Electrocuted (−%d AP this turn)." % [str(unit.get("name", "Unit")), cut],
	})


func _is_spell_silenced(unit: Dictionary, spell_id: String) -> bool:
	var silenced: Variant = unit.get("silenced_spells", [])
	if typeof(silenced) != TYPE_ARRAY:
		return false
	return (silenced as Array).has(spell_id)


func _append_lava_castigo(target: Dictionary, burn_info: Dictionary) -> void:
	if burn_info.is_empty():
		return
	var land_hp := int(burn_info.get("land_hp", 0))
	if land_hp > 0:
		_last_events.append({
			"type": "lava_land",
			"target_seat": target["seat"],
			"hp_delta": -land_hp,
			"land_hp": land_hp,
			"hp": int(target.get("hp", 0)),
			"coach": "%s takes %d lava damage." % [str(target.get("name", "Unit")), land_hp],
		})
	var stacks := int(burn_info.get("stacks", 0))
	var tick := int(burn_info.get("hp_per_tick", _burn_tick_hp(stacks)))
	var refreshed := bool(burn_info.get("refreshed", false))
	var turns := int(burn_info.get("remaining", BURN_STACK_TURNS[clampi(stacks, 1, BURN_MAX_STACKS)]))
	var burn_coach := "%s is burning (stack %d, %d HP at turn start for %d turns)." % [str(target.get("name", "Unit")), stacks, tick, turns]
	if refreshed:
		burn_coach = "%s's Burn is stack %d (%d HP × %d)." % [str(target.get("name", "Unit")), stacks, tick, turns]
	_last_events.append({
		"type": "status",
		"status": "burn",
		"stacks": stacks,
		"previous_stacks": int(burn_info.get("previous_stacks", 0)),
		"remaining": turns,
		"duration": turns,
		"hp_per_tick": tick,
		"land_hp": land_hp,
		"refreshed": refreshed,
		"previous": int(burn_info.get("previous", 0)),
		"target_seat": target["seat"],
		"soft_lock": "Map push stack — lava enter 10/10/15 Fire, Burn 4×2 / 5×3 / 5×4, max 3",
		"coach": burn_coach,
	})


func _append_soft_lock_status(target: Dictionary, silence_info: Dictionary, slow_info: Dictionary) -> void:
	if not silence_info.is_empty():
		_last_events.append({
			"type": "status",
			"status": "silence",
			"spell": str(silence_info.get("spell", "")),
			"target_seat": target["seat"],
			"coach": "%s's %s is silenced." % [target["name"], str(silence_info.get("name", "spell"))],
		})
	if slow_info.is_empty():
		return
	var slow_coach := "%s is slowed (−%d MP for %d turn)." % [target["name"], SLOW_MP, SLOW_TURNS]
	if bool(slow_info.get("refreshed", false)):
		slow_coach = "%s's Slow refreshes to %d turn (no stack)." % [target["name"], SLOW_TURNS]
	_last_events.append({
		"type": "status",
		"status": "slow",
		"remaining": int(slow_info.get("remaining", SLOW_TURNS)),
		"duration": SLOW_TURNS,
		"mp_delta": -SLOW_MP,
		"refreshed": bool(slow_info.get("refreshed", false)),
		"previous": int(slow_info.get("previous", 0)),
		"target_seat": target["seat"],
		"coach": slow_coach,
	})


## Spend the one Slow turn at this unit's turn start. Leaves the tile does not clear it.
func _consume_mud_slow(unit: Dictionary) -> void:
	if unit.is_empty() or not bool(unit.get("alive", false)):
		return
	var remaining := int(unit.get("slow_remaining", 0))
	if remaining <= 0:
		return
	unit["slow_remaining"] = remaining - 1
	var cut := mini(SLOW_MP * maxi(int(unit.get("slow_stacks", 1)), 1), int(unit.get("mp", 0)))
	unit["mp"] = int(unit["mp"]) - cut
	if int(unit["slow_remaining"]) <= 0:
		unit["slow_stacks"] = 0
	_last_events.append({
		"type": "slow",
		"status": "slow",
		"target_seat": int(unit["seat"]),
		"mp_delta": -cut,
		"mp": int(unit["mp"]),
		"remaining": int(unit["slow_remaining"]),
		"duration": SLOW_TURNS,
		"coach": "%s is slowed (−%d MP this turn)." % [str(unit.get("name", "Unit")), cut],
	})


func _tick_burn(unit: Dictionary) -> void:
	# Tick uses the current stack. Leaving lava does not clear it. Cleanse does.
	if unit.is_empty() or not bool(unit.get("alive", false)):
		return
	var stacks := int(unit.get("burn_stacks", 0))
	var remaining := int(unit.get("burn_remaining", 0))
	if stacks <= 0 or remaining <= 0:
		return
	var lost := _burn_tick_hp(stacks)
	unit["hp"] = maxi(0, int(unit["hp"]) - lost)
	var left := remaining - 1
	if left <= 0:
		unit["burn_remaining"] = 0
		unit["burn_stacks"] = 0
		left = 0
	else:
		unit["burn_remaining"] = left
	_last_events.append({
		"type": "burn",
		"status": "burn",
		"target_seat": int(unit["seat"]),
		"hp_delta": -lost,
		"damage": lost,
		"hp": int(unit["hp"]),
		"tick_stacks": stacks,
		"stacks": int(unit.get("burn_stacks", 0)),
		"remaining": left,
		"duration": BURN_DURATION,
		"soft_lock": "Soft Lock CASTIGO — Burn tick uses current stacks, duration 4",
		"coach": "%s burns for %d HP (stack %d, %d tick%s left)." % [
			str(unit.get("name", "Unit")),
			lost,
			stacks,
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
	# Earth rider: a wall collision hits for 8 and REPLACES the stagger 4, at
	# most once per target per turn.
	if bool(result.get("earth", false)) and int(target.get("earth_collision_turn", -1)) != _turn_index:
		target["earth_collision_turn"] = _turn_index
		hp_lost = EARTH_COLLISION_HP
		result["earth_collision"] = true
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
	# Blend events land after the hit / push rows of the cast that fired them.
	if not _blend_queue.is_empty():
		_last_events.append_array(_blend_queue)
		_blend_queue.clear()
	_skip_fallen_active()
	_broadcast()
	return {
		"ok": true,
		"illegal": false,
		"reason": "",
		"events": _last_events.duplicate(true),
		"snapshot": snapshot(),
	}


## ---- Stasis monster kits (FoeKits) ----------------------------------------
## Mauro's Stasis kit sheets (29 Sep 2026). Monsters cast from `foe_kit`;
## every offer comes from _foe_casts and a submit must match one of them.


func _tick_foe_cooldowns(unit: Dictionary) -> void:
	var cds: Variant = unit.get("foe_cd", null)
	if typeof(cds) != TYPE_DICTIONARY:
		return
	for id in (cds as Dictionary).keys():
		cds[id] = maxi(int(cds[id]) - 1, 0)


func _foe_cd_ready(actor: Dictionary, spell_id: String) -> bool:
	var cds: Variant = actor.get("foe_cd", {})
	return typeof(cds) != TYPE_DICTIONARY or int((cds as Dictionary).get(spell_id, 0)) <= 0


## Hostile bodies for a monster: the player's side (seat 0 and allies).
func _foe_victims(actor: Dictionary) -> Array:
	var out: Array = []
	var seat := int(actor.get("seat", -1))
	for unit in _units:
		if not bool(unit.get("alive", false)) or not bool(unit.get("placed", true)):
			continue
		if _allied(unit, actor):
			continue
		# Monsters cannot see an Invisible hero either.
		if bool(unit.get("invisible", false)):
			continue
		out.append(unit)
	return out


## Walking cost from every tile to the nearest source (bodies ignored, so a
## pack does not block its own route). Monsters use it to walk around walls
## instead of getting stuck behind them (Mauro 30 Sep 2026: "they get stuck").
func walk_field(sources: Array) -> Dictionary:
	var never := Callable(self, "_wall_only_occupied")
	var best := {}
	var frontier: Array = []
	for raw in sources:
		var cell: Vector2i = raw
		if _in_bounds(cell) and not best.has(cell):
			best[cell] = 0
			frontier.append(cell)
	while not frontier.is_empty():
		var pick := 0
		for i in frontier.size():
			if int(best[frontier[i]]) < int(best[frontier[pick]]):
				pick = i
		var current: Vector2i = frontier[pick]
		frontier.remove_at(pick)
		for dir in FACING_VEC.values():
			var nxt: Vector2i = current + dir
			if not _in_bounds(nxt):
				continue
			# Reverse step: can a walker on `nxt` step onto `current`?
			var step: Dictionary = _board.step_cost(nxt, current, never)
			if not bool(step.get("ok", false)) and not best.has(nxt):
				# Sources may be a body's tile (not standable); allow leaving it.
				if int(best[current]) != 0:
					continue
				if not _board.is_walkable(nxt) or _board.is_voluntary_impassable(nxt):
					continue
			var cost := int(best[current]) + maxi(int(step.get("cost", 1)), 1)
			if not best.has(nxt) or cost < int(best[nxt]):
				best[nxt] = cost
				frontier.append(nxt)
	return best


## Walls and blockers block a route; bodies do not (they move).
func _wall_only_occupied(cell: Vector2i, _ignore: Vector2i = UNPLACED) -> bool:
	if _snap_wall_blocks(cell):
		return true
	for blocked in _blocked_cells:
		if blocked == cell:
			return true
	return false


func _foe_free_cell(cell: Vector2i) -> bool:
	return _in_bounds(cell) and _is_empty(cell) and _board.is_walkable(cell) and not _board.is_voluntary_impassable(cell)


## Every legal monster cast this turn.
func _foe_casts(actor: Dictionary) -> Array:
	var out: Array = []
	var seat := int(actor["seat"])
	var from: Vector2i = actor["pos"]
	var ap := int(actor.get("ap", 0))
	var victims := _foe_victims(actor)
	for raw_id in actor.get("foe_kit", []):
		var id := str(raw_id)
		var def: Dictionary = FoeKits.spell(id)
		if def.is_empty() or ap < int(def.get("ap", 0)) or not _foe_cd_ready(actor, id):
			continue
		if _is_stunned(actor):
			continue
		var shape := str(def.get("shape", ""))
		match shape:
			"melee", "shot":
				for v in victims:
					var d := chebyshev(from, v["pos"])
					if d < int(def.get("min", 1)) or d > int(def.get("max", 1)):
						continue
					if d > 1 and not has_line_of_sight(from, v["pos"]):
						continue
					out.append({"type": "cast", "spell": id, "to": v["pos"], "target_seat": v["seat"], "seat": seat})
			"dash":
				for v in victims:
					var d := chebyshev(from, v["pos"])
					if d < int(def.get("min", 2)) or d > int(def.get("max", 2)):
						continue
					if d == 1 or _foe_dash_cell(from, v["pos"]) != UNPLACED:
						out.append({"type": "cast", "spell": id, "to": v["pos"], "target_seat": v["seat"], "seat": seat})
			"cone", "line":
				for dir in FACING_VEC.keys():
					if not _foe_area_victims(actor, def, FACING_VEC[dir]).is_empty():
						out.append({"type": "cast", "spell": id, "to": from + FACING_VEC[dir], "dir": dir, "seat": seat})
			"radius", "pads":
				if not _foe_area_victims(actor, def, Vector2i.ZERO).is_empty():
					out.append({"type": "cast", "spell": id, "to": from, "seat": seat})
			"blast":
				for v in victims:
					var d := chebyshev(from, v["pos"])
					if d < int(def.get("min", 2)) or d > int(def.get("max", 6)):
						continue
					if not has_line_of_sight(from, v["pos"]):
						continue
					out.append({"type": "cast", "spell": id, "to": v["pos"], "target_seat": v["seat"], "seat": seat})
			"self":
				out.append({"type": "cast", "spell": id, "to": from, "seat": seat})
			"step":
				for dir in FACING_VEC.keys():
					var cell: Vector2i = from + FACING_VEC[dir]
					if _foe_free_cell(cell):
						var gate: Dictionary = _board.stand_on_gate(from, cell, Callable(self, "_walk_occupied"))
						if bool(gate.get("ok", false)):
							out.append({"type": "cast", "spell": id, "to": cell, "seat": seat})
	return out


## Free tile beside the target that is one step from the caster (Lunge).
func _foe_dash_cell(from: Vector2i, target: Vector2i) -> Vector2i:
	var best := UNPLACED
	var best_d := 99
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := target + Vector2i(dx, dy)
			if cell == target or chebyshev(cell, from) != 1:
				continue
			if not _foe_free_cell(cell):
				continue
			var gate: Dictionary = _board.stand_on_gate(from, cell, Callable(self, "_walk_occupied"))
			if not bool(gate.get("ok", false)):
				continue
			var d := absi(cell.x - from.x) + absi(cell.y - from.y)
			if d < best_d:
				best_d = d
				best = cell
	return best


## Tiles an area spell covers. `dir` is the cardinal facing (cone / line).
func _foe_area_cells(actor: Dictionary, def: Dictionary, dir: Vector2i, center: Vector2i = UNPLACED) -> Array:
	var from: Vector2i = actor["pos"]
	var out: Array = []
	match str(def.get("shape", "")):
		"cone":
			for cell in FoeKits.cone_cells(from, dir, int(def.get("size", 2))):
				if _in_bounds(cell):
					out.append(cell)
		"line":
			var top := _elevation_at(from)
			for k in range(1, int(def.get("size", 5)) + 1):
				var cell: Vector2i = from + dir * k
				if not _in_bounds(cell) or _blocks_sight(cell, top, false):
					break
				out.append(cell)
		"radius":
			for cell in FoeKits.radius_cells(from, int(def.get("size", 1))):
				if _in_bounds(cell):
					out.append(cell)
		"blast":
			var at := from if center == UNPLACED else center
			if _in_bounds(at):
				out.append(at)
			for cell in FoeKits.radius_cells(at, int(def.get("size", 1))):
				if _in_bounds(cell):
					out.append(cell)
		"pads":
			for y in range(_board_size):
				for x in range(_board_size):
					var cell := Vector2i(x, y)
					if _is_charged_pad(cell) or _next_to_pad(cell):
						out.append(cell)
	return out


func _is_charged_pad(cell: Vector2i) -> bool:
	return _in_bounds(cell) and hazard_family_at(cell) == "electrocuted"


func _next_to_pad(cell: Vector2i) -> bool:
	for n in FoeKits.radius_cells(cell):
		if _is_charged_pad(n):
			return true
	return false


func _foe_area_victims(actor: Dictionary, def: Dictionary, dir: Vector2i) -> Array:
	var cells := _foe_area_cells(actor, def, dir)
	var out: Array = []
	for v in _foe_victims(actor):
		if cells.has(v["pos"]):
			out.append(v)
	return out


## Sheet damage x the star's damage scale; trash (damage 0) uses the room base.
func _foe_base_damage(actor: Dictionary, def: Dictionary) -> int:
	var base := int(def.get("damage", 0))
	if base <= 0:
		return maxi(int(actor.get("stasis_attack_base", 6)), 0)
	return roundi(float(base) * float(actor.get("foe_dmg_mult", 1.0)))


func _submit_foe_cast(intent: Dictionary, actor: Dictionary) -> Dictionary:
	var spell_id := str(intent.get("spell", ""))
	var def: Dictionary = FoeKits.spell(spell_id)
	if not (actor.get("foe_kit", []) as Array).has(spell_id):
		return _reject(intent, "spell_not_in_kit", "REJECT — %s is not in %s's kit." % [def.get("name", spell_id), actor["name"]])
	var dest: Vector2i = _as_cell(intent.get("to", actor["pos"]))
	var offer := {}
	for cast in _foe_casts(actor):
		if str(cast["spell"]) == spell_id and cast["to"] == dest:
			offer = cast
			break
	if offer.is_empty():
		return _reject(intent, "illegal_foe_cast", "REJECT — %s cannot be cast there." % def.get("name", spell_id))
	_last_events = []
	var ap_cost := int(def.get("ap", 0))
	actor["ap"] = int(actor["ap"]) - ap_cost
	var cd := FoeKits.cooldown(spell_id)
	if cd > 0:
		(actor["foe_cd"] as Dictionary)[spell_id] = cd
	_intent_log.append(intent)
	var shape := str(def.get("shape", ""))
	var caster_cell: Vector2i = actor["pos"]
	var name := str(def.get("name", spell_id))
	if shape == "self":
		actor["shield"] = int(actor.get("shield", 0)) + int(def.get("ward", 0))
		actor["shield_turns"] = maxi(int(actor.get("shield_turns", 0)), 2)
		_last_coach = "%s raises %s (+%d Ward)." % [actor["name"], name, int(def.get("ward", 0))]
		_last_events.append({"type": "cast", "spell": spell_id, "seat": actor["seat"], "caster_cell": caster_cell, "shield": int(actor["shield"]), "ap_spent": ap_cost, "foe": true, "coach": _last_coach})
		return _accept()
	if shape == "step":
		actor["pos"] = dest
		var face := _dir_name(dest - caster_cell)
		if face != "":
			actor["facing"] = face
		_last_coach = "%s: %s to %s." % [actor["name"], name, _cell_text(dest)]
		_last_events.append({"type": "move", "seat": actor["seat"], "from": caster_cell, "to": dest, "path": [dest], "facing_from": str(actor["facing"]), "facing": str(actor["facing"]), "facing_hops": [str(actor["facing"])], "mp_spent": 0, "ap_spent": ap_cost, "spell": spell_id, "foe": true, "coach": _last_coach})
		return _accept()
	var victims: Array = []
	var area: Array = []
	var dir := Vector2i.ZERO
	if shape in ["cone", "line"]:
		dir = FACING_VEC.get(str(offer.get("dir", "S")), Vector2i(0, 1))
		actor["facing"] = str(offer.get("dir", actor["facing"]))
	if shape in ["cone", "line", "radius", "pads"]:
		area = _foe_area_cells(actor, def, dir)
		victims = _foe_area_victims(actor, def, dir)
	elif shape == "blast":
		area = _foe_area_cells(actor, def, dir, dest)
		for v in _foe_victims(actor):
			if area.has(v["pos"]):
				victims.append(v)
		var face_blast := _dir_name(_sign_step(dest - caster_cell))
		if face_blast != "":
			actor["facing"] = face_blast
	else:
		var target := _living_unit_at(dest)
		if not target.is_empty():
			victims = [target]
		var face_to := _dir_name(_sign_step(dest - caster_cell))
		if face_to != "":
			actor["facing"] = face_to
	var dash_from := caster_cell
	if shape == "dash" and chebyshev(caster_cell, dest) == 2:
		var cell := _foe_dash_cell(caster_cell, dest)
		if cell != UNPLACED:
			actor["pos"] = cell
	var hits := 0
	var total := 0
	for raw in victims:
		var target: Dictionary = raw
		var dist := maxi(chebyshev(actor["pos"], target["pos"]), 1)
		var chance := hit_chance(dist)
		var roll := _roll_d100()
		var event := {
			"seat": actor["seat"],
			"spell": spell_id,
			"spell_name": name,
			"caster_cell": caster_cell,
			"target_seat": target["seat"],
			"to": target["pos"],
			"range": dist,
			"hit_chance": chance,
			"roll": roll,
			"ap_spent": ap_cost if hits == 0 and total == 0 else 0,
			"foe": true,
			"shape": shape,
			"element": _foe_element(actor, def),
			"door": str(actor.get("foe_door", "")),
			"boss": bool(actor.get("stasis_boss", false)),
		}
		if not area.is_empty():
			event["area"] = area.duplicate()
		if dash_from != actor["pos"]:
			event["dash_from"] = dash_from
			event["dash_to"] = actor["pos"]
		if roll > chance:
			event["type"] = "miss"
			event["damage"] = 0
			event["coach"] = "%s's %s misses %s." % [actor["name"], name, target["name"]]
			_last_events.append(event)
			continue
		var facing_mult := _facing_multiplier(actor["pos"], target["pos"], str(target.get("facing", "")))
		var pre := _phase_a_damage(_foe_base_damage(actor, def), facing_mult, actor, target, _foe_element(actor, def), true)
		var mitigation := _mitigate_hit(actor, target, pre)
		var damage := int(mitigation["damage"])
		target["hp"] = maxi(int(target["hp"]) - damage, 0)
		_reveal_if_hurt(target, damage)
		hits += 1
		total += damage
		event["type"] = "hit"
		event["damage"] = damage
		event["facing_mult"] = facing_mult
		_stamp_mitigation(event, mitigation)
		var push_result := {}
		if int(def.get("push", 0)) > 0:
			push_result = _try_push(actor["pos"], target, int(def["push"]))
		elif int(def.get("pull", 0)) > 0:
			push_result = _foe_pull(actor, target)
		if not push_result.is_empty():
			var punish := _apply_landing_punishments(target, push_result)
			_stamp_push_fields(event, push_result, punish["burn"], punish["silence"], punish["slow"])
			_last_events.append(event)
			_emit_push_followups(actor, target, push_result, punish["burn"])
			_append_soft_lock_status(target, punish["silence"], punish["slow"])
		else:
			_last_events.append(event)
		if bool(def.get("frozen_on_ice", false)) and hazard_family_at(target["pos"]) == "frozen" and bool(target.get("alive", true)):
			var frozen := _apply_frozen(target)
			_last_events.append({"type": "status", "status": "frozen", "stacks": int(frozen["stacks"]), "remaining": int(frozen["remaining"]), "paralyzed": bool(frozen["paralyzed"]), "target_seat": target["seat"], "coach": "%s is pinned on the ice (Frozen %d)." % [target["name"], int(frozen["stacks"])]})
		_emit_immunity_spent(target, mitigation)
		_check_death(target)
		if _match_over:
			break
	if victims.is_empty() and shape == "dash":
		_last_events.append({"type": "miss", "seat": actor["seat"], "spell": spell_id, "caster_cell": caster_cell, "to": dest, "damage": 0, "foe": true, "coach": "%s lunges at nothing." % actor["name"]})
	if bool(FoeKits.is_aoe(spell_id)) and hits > 0:
		_last_coach = "%s uses %s: %d hit for %d." % [actor["name"], name, hits, total]
	elif hits > 0:
		_last_coach = "%s: %s for %d." % [actor["name"], name, total]
	else:
		_last_coach = "%s: %s misses." % [actor["name"], name]
	for e in _last_events:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("spell", "")) == spell_id and not e.has("coach"):
			e["coach"] = _last_coach
	return _accept()


## Hook: drag the target 1 tile toward the caster. Landing on a hazard applies
## that tile's push stack (Brinewake water = Breathless). A body or wall stops it.
func _foe_pull(actor: Dictionary, target: Dictionary) -> Dictionary:
	var from: Vector2i = target["pos"]
	var dest: Vector2i = from + _sign_step(actor["pos"] - from)
	var result := {"from": from, "to": from, "attempted": dest, "moved": false, "blocked": false, "bounced": false, "staggered": false, "burn": false, "silence": false, "slow": false, "frozen": false, "electrocuted": false, "reason": "", "stagger_hp": 0, "stagger_mp": 0, "hp_delta": 0, "mp_delta": 0, "pulled": true}
	if dest == from or not _in_bounds(dest) or not _is_empty(dest):
		result["blocked"] = true
		result["reason"] = "occupied"
		return result
	if _board.is_voluntary_impassable(dest):
		target["pos"] = dest
		result["to"] = dest
		result["moved"] = true
		var family := hazard_family_at(dest)
		match family:
			"burn":
				result["burn"] = true
			"slow":
				result["slow"] = true
			"breathless":
				result["silence"] = true
			"frozen", "electrocuted":
				result[family] = true
		result["reason"] = family
		return result
	if not _board.is_walkable(dest):
		result["blocked"] = true
		result["reason"] = "wall"
		return result
	target["pos"] = dest
	result["to"] = dest
	result["moved"] = true
	return result


func _foe_element(actor: Dictionary, def: Dictionary) -> String:
	var el := str(def.get("element", "Neutral"))
	if el == "door":
		return str(FoeKits.DOOR_ELEMENT.get(str(actor.get("foe_door", "")), "Neutral"))
	return el


static func _sign_step(delta: Vector2i) -> Vector2i:
	return Vector2i(signi(delta.x), signi(delta.y))


## Cardinal facing name for a step (diagonals use the larger axis).
func _dir_name(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return ""
	if absi(delta.x) >= absi(delta.y):
		return "E" if delta.x > 0 else "W"
	return "S" if delta.y > 0 else "N"


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
	if not _multi_side():
		return _unit_by_seat(1 if seat == 0 else 0)
	# Teams: the nearest living enemy (any enemy once they are all down).
	var me := _unit_by_seat(seat)
	var best: Dictionary = {}
	var best_d := 999
	for unit in _units:
		if me.is_empty() or _allied(unit, me):
			continue
		if not bool(unit.get("alive", false)):
			if best.is_empty():
				best = unit
			continue
		var d := chebyshev(me["pos"], unit["pos"])
		if d < best_d:
			best_d = d
			best = unit
	return best


## Team of a unit: Koliseo teams set it; otherwise seat 0 vs every other seat
## (Stasis: the hero vs the monsters).
func _team_of(unit: Dictionary) -> int:
	return int(unit.get("team", 0 if int(unit.get("seat", 0)) == 0 else 1))


func _allied(a: Dictionary, b: Dictionary) -> bool:
	return _team_of(a) == _team_of(b)


func team_of_seat(seat: int) -> int:
	var unit := _unit_by_seat(seat)
	if unit.is_empty():
		return seat % 2 if _team_size > 1 else (0 if seat == 0 else 1)
	return _team_of(unit)


func team_size() -> int:
	return _team_size


func party_size() -> int:
	return _party_size


## More than one fighter on a side: Koliseo teams or a Stasis party.
func _multi_side() -> bool:
	return _team_size > 1 or _party_size > 1


func _team_alive(team: int) -> bool:
	for unit in _units:
		if _team_of(unit) == team and bool(unit.get("alive", false)):
			return true
	return false


## Koliseo: the other of seats 0 and 1 (teams: every living enemy).
## Stasis player: every living hostile.
func _hostile_cast_targets(seat: int) -> Array:
	if _multi_side():
		var me := _unit_by_seat(seat)
		var foes: Array = []
		for unit in _units:
			if not me.is_empty() and not _allied(unit, me) and bool(unit.get("alive", false)):
				foes.append(unit)
		return foes
	if _stasis_pack and seat == 0:
		return _living_stasis_hostiles()
	var enemy := _enemy_of(seat)
	if enemy.is_empty() or not bool(enemy.get("alive", false)):
		return []
	return [enemy]


func _living_stasis_hostiles() -> Array:
	var out: Array = []
	for unit in _units:
		if _team_of(unit) == 0:
			continue
		if bool(unit.get("alive", false)):
			out.append(unit)
	return out


func _stasis_winner_hostile() -> int:
	for unit in _living_stasis_hostiles():
		return int(unit.get("seat", 1))
	return 1


func _first_legal_ambush_target(actor: Dictionary) -> Dictionary:
	var pool: Array = _hostile_cast_targets(int(actor.get("seat", -1))) if _multi_side() else _living_stasis_hostiles()
	for hostile in pool:
		var enemy: Dictionary = hostile
		if _ambush_can_offer(actor, enemy):
			return enemy
	return {}


## 1v1 swaps seats. A Stasis pack walks the living seats in order, then wraps.
func _next_turn_seat(from_seat: int) -> int:
	if _team_size > 1:
		if _turn_order.is_empty():
			_build_turn_order(from_seat)
		var at := _turn_order.find(from_seat)
		for step in range(1, _turn_order.size() + 1):
			var seat: int = _turn_order[(at + step) % _turn_order.size()]
			var unit := _unit_by_seat(seat)
			if not unit.is_empty() and bool(unit.get("alive", false)):
				return seat
		return -1
	if not _stasis_pack:
		var other := 1 if from_seat == 0 else 0
		var unit := _unit_by_seat(other)
		if unit.is_empty() or not bool(unit.get("alive", false)):
			return -1
		return other
	var seats: Array[int] = []
	for unit in _units:
		if bool(unit.get("alive", false)):
			seats.append(int(unit.get("seat", -1)))
	if seats.is_empty():
		return -1
	seats.sort()
	for seat in seats:
		if seat > from_seat:
			return seat
	return int(seats[0])


## Selection snap for a living-unit cast. The tapped cell is unchanged when it
## already holds a unit, the spell is not an enemy cast, the tap is out of
## range, or the Chebyshev neighborhood (the #194 trough test, distance <= 1)
## does not hold exactly one in-range legal enemy. Ambush keeps its own origin
## snap. Two neighbors stay the empty tile.
func soft_lock_dest(seat: int, spell_id: String, dest: Vector2i) -> Vector2i:
	if spell_id == SpellKits.AMBUSH:
		return dest
	var def: Dictionary = SpellKits.spell_for(_unit_by_seat(seat), spell_id)
	if def.is_empty():
		return dest
	var target_kind := str(def.get("target", ""))
	if target_kind != "enemy" and target_kind != "any":
		return dest
	var actor := _unit_by_seat(seat)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return dest
	var beside := _soft_lock_neighbor_target(actor, def, actor["pos"], dest)
	if beside.is_empty():
		return dest
	return beside["pos"]


## Empty tile beside exactly one in-range legal enemy. Chebyshev <= 1, the
## same neighborhood the hazard trough used. The tap itself must be in range.
## A gate failure (Detonate with no Marks) is not a legal neighbor. Zero or
## two or more neighbors return empty so the cast keeps the empty-tile reject.
func _soft_lock_neighbor_target(actor: Dictionary, def: Dictionary, range_from: Vector2i, dest: Vector2i) -> Dictionary:
	if not _living_unit_at(dest).is_empty():
		return {}
	if not _in_spell_reach(def, range_from, dest):
		return {}
	var found := {}
	for hostile in _hostile_cast_targets(int(actor["seat"])):
		if typeof(hostile) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = hostile
		if not bool(enemy.get("alive", false)) or bool(enemy.get("invisible", false)):
			continue
		if chebyshev(dest, enemy["pos"]) > 1:
			continue
		if not _in_spell_reach(def, range_from, enemy["pos"]):
			continue
		if _cast_gate_reason(actor, enemy, def) != "":
			continue
		if not found.is_empty():
			return {}
		found = enemy
	return found


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
	if spell_id == SpellKits.AMBUSH and not _ambush_self_origin(actor) and _shade_count(actor) <= 0:
		return "no_shade"
	return ""


func _in_spell_range(def: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var dist := _range_distance(def, from_cell, to_cell)
	if dist > _HitBands.MAX_DISTANCE:
		return false
	return dist >= int(def.get("min_range", 0)) and dist <= int(def.get("max_range", 0))


## Line of sight (Mauro 30 Sep 2026: "Kestrel should not be able to attack in
## front of the wall, has to have vision; this applies for all classes").
## A spell aimed at another tile needs a clear line from the caster's tile
## centre to the target's. A tile the line passes through blocks it when it
## holds a solid prop (the same props that block walking) or a tall drawn
## prop (CellTagMap.SIGHT_PROPS: ruins, crystals, conduits, centrepieces), a
## Snap Wall or a blocker, or stands higher than both the caster's and the
## target's tiles (a raised wall), or — for a spell aimed at a fighter — a
## fighter stands on it (not an Invisible one). Water, mud, lava don't block. Self casts,
## Advance (a 2-tile step), Ambush (its own ray gate) and the cone / burst
## around the caster do not check sight.
func spell_needs_sight(def: Dictionary) -> bool:
	var spell_id := str(def.get("id", ""))
	if spell_id == SpellKits.ADVANCE or spell_id == SpellKits.AMBUSH:
		return false
	return ["enemy", "ally", "any", "tile", "empty_tile", "fallen_ally"].has(str(def.get("target", "")))


func has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, bodies: bool = true) -> bool:
	return sight_blocker(from_cell, to_cell, bodies) == Vector2i(-1, -1)


## Fighters on the line block spells aimed at a fighter. A placement on a tile
## (Drop Shade, Snap Wall, Plant) still needs a wall-free line but may pass
## beside / behind a body, so Gloam can still plant a Shade behind a foe.
func _sight_bodies(def: Dictionary) -> bool:
	return not ["tile", "empty_tile"].has(str(def.get("target", "")))


func _spell_sees(def: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return not spell_needs_sight(def) or has_line_of_sight(from_cell, to_cell, _sight_bodies(def))


## First tile that blocks the line, or (-1, -1) when the line is clear.
func sight_blocker(from_cell: Vector2i, to_cell: Vector2i, bodies: bool = true) -> Vector2i:
	var none := Vector2i(-1, -1)
	if from_cell == to_cell or not _in_bounds(from_cell) or not _in_bounds(to_cell):
		return none
	var top := maxi(_elevation_at(from_cell), _elevation_at(to_cell))
	var a := Vector2(from_cell)
	var b := Vector2(to_cell)
	var cells: Array = []
	for y in range(mini(from_cell.y, to_cell.y), maxi(from_cell.y, to_cell.y) + 1):
		for x in range(mini(from_cell.x, to_cell.x), maxi(from_cell.x, to_cell.x) + 1):
			var cell := Vector2i(x, y)
			if cell == from_cell or cell == to_cell:
				continue
			if _segment_crosses_cell(a, b, cell):
				cells.append(cell)
	cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return Vector2(p).distance_squared_to(a) < Vector2(q).distance_squared_to(a))
	for item in cells:
		var cell: Vector2i = item
		if _blocks_sight(cell, top, bodies):
			return cell
	return none


## Mauro 5 Oct 2026: "elevated ground should not affect vision only obstacles
## or players infront can affect vision". Raised tiles never block; `top` is
## kept for the callers' signature.
func _blocks_sight(cell: Vector2i, _top: int, bodies: bool = true) -> bool:
	if _CellTagMap.props_block_sight(_map_id, _paint_only.get(cell, []), cell):
		return true
	if _snap_wall_blocks(cell):
		return true
	if _map_steam_at(cell):
		return true
	# Steam (Fire + Water Blend): its tile blocks the line. The fighter on it
	# is still a legal target (the end cells are never tested).
	if element_tile_at(cell, "steam"):
		return true
	for blocked in _blocked_cells:
		if blocked == cell:
			return true
	# Mauro 30 Sep 2026 ("yes same here", as Dofus): a fighter standing on the
	# line blocks it. An Invisible fighter does not (it would give him away).
	if not bodies:
		return false
	var body := _living_unit_at(cell)
	if not body.is_empty() and not bool(body.get("invisible", false)):
		return true
	return false


func _elevation_at(cell: Vector2i) -> int:
	var tile = _board.tile_at(cell)
	return int(tile.elevation) if tile != null else 0


## The segment between two tile centres passes through the tile's inside. The
## tile is shrunk a hair so a line that only grazes a corner does not count.
static func _segment_crosses_cell(a: Vector2, b: Vector2, cell: Vector2i) -> bool:
	var h := 0.499
	var lo := Vector2(cell) - Vector2(h, h)
	var hi := Vector2(cell) + Vector2(h, h)
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var p := a[axis]
		var v := d[axis]
		if absf(v) < 0.000001:
			if p < lo[axis] or p > hi[axis]:
				return false
			continue
		var ta := (lo[axis] - p) / v
		var tb := (hi[axis] - p) / v
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


## Range, then sight when the spell needs it.
func _in_spell_reach(def: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not _in_spell_range(def, from_cell, to_cell):
		return false
	return _spell_sees(def, from_cell, to_cell)


func _append_ranged_cells(out: Array, actor: Dictionary, def: Dictionary, spell_id: String, empty_only: bool) -> void:
	var from_cell: Vector2i = actor["pos"]
	var seat := int(actor["seat"])
	for y in range(_board_size):
		for x in range(_board_size):
			var cell := Vector2i(x, y)
			if not _in_spell_reach(def, from_cell, cell):
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
			if unit.is_empty() or _allied(unit, actor):
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
		if unit.is_empty() or _allied(unit, actor):
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
## Stride per Mauro: Intact +1 AP +1 MP every turn (cap 8/5). Overwound
## +4 AP +2 MP on the unit's own turns 1–2 over any cap, then −1 AP −2 MP on
## turn 3 (floor 0), then normal. Only the Still's part ever changes;
## gear / level AP-MP stay. Ember Overwound's burn ticks here too.
func _still_turn_start(unit: Dictionary) -> void:
	if unit.is_empty():
		return
	unit["own_turn"] = int(unit.get("own_turn", 0)) + 1
	var burn := int(unit.get("ember_burn", 0))
	if burn > 0:
		unit["ember_burn"] = 0
		unit["hp"] = maxi(int(unit["hp"]) - burn, 0)
		_last_events.append({"type": "still", "still": "ember", "seat": int(unit["seat"]), "damage": burn, "pos": unit["pos"]})
		_check_death(unit, "ember")
	if str(unit.get("still", "")) != "stride":
		return
	var turn := int(unit["own_turn"])
	if str(unit.get("still_mode", "")) == "overwound":
		if turn <= 2:
			unit["ap"] = int(unit["ap"]) + 4
			unit["mp"] = int(unit["mp"]) + 2
			if turn == 1:
				_still_fired(unit, "stride")
		elif turn == 3:
			unit["ap"] = maxi(int(unit["ap"]) - 1, 0)
			unit["mp"] = maxi(int(unit["mp"]) - 2, 0)
			_last_events.append({"type": "still", "still": "stride_crack", "seat": int(unit["seat"]), "pos": unit["pos"]})
		return
	unit["ap"] = mini(int(unit["ap"]) + 1, maxi(GearBag.AP_CAP, int(unit.get("max_ap", MAX_AP))))
	unit["mp"] = mini(int(unit["mp"]) + 1, maxi(GearBag.MP_CAP, int(unit.get("max_mp", MAX_MP))))
	if turn == 1:
		_still_fired(unit, "stride")


## Cut / Ember on the attacker's first damaging hit, Guard on the target's
## first hit taken. Neutral bonus lands after resist.
func _still_on_hit(actor: Dictionary, target: Dictionary, damage: int) -> int:
	var over := str(actor.get("still_mode", "")) == "overwound"
	match str(actor.get("still", "")):
		"cut":
			if bool(actor.get("still_ready", false)):
				actor["still_ready"] = false
				damage += 10 if over else 4
				_still_fired(actor, "cut")
		"ember":
			if bool(actor.get("still_ready", false)):
				actor["still_ready"] = false
				damage += 4
				if over:
					target["ember_burn"] = 4
				_still_fired(actor, "ember")
	if str(target.get("still", "")) == "guard" and bool(target.get("still_ready", false)):
		target["still_ready"] = false
		damage = 0 if str(target.get("still_mode", "")) == "overwound" else roundi(float(damage) * 0.75)
		_still_fired(target, "guard")
	return damage


func _still_fired(unit: Dictionary, still_id: String) -> void:
	_last_events.append({"type": "still", "still": still_id, "seat": int(unit.get("seat", -1)), "mode": str(unit.get("still_mode", "")), "pos": unit.get("pos", UNPLACED)})


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
	if damage > 0:
		damage = _still_on_hit(actor, target, damage)
		report["damage"] = damage
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
	if _allied(actor, target):
		return 0
	var guards: Array = []
	for unit in _units:
		if str(unit.get("class_id", "")) != SpellKits.CLASS_BASTION:
			continue
		if not bool(unit.get("alive", false)):
			continue
		if not _allied(unit, target):
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
	var flex := _flex_bonus(actor, str(def.get("element", "")).to_lower(), false)
	var raw: float = float(base) * CRIT_MULT * passive * (1.0 + (MASTERY + float(actor.get("mastery", 0))) / 100.0) * (1.0 + flex / 100.0) * facing
	return roundi(raw)


## Locked Triage ×1.25 when the target is below 40% HP before the heal.
## Ally Heartstop uses it. Enemy Heartstop is a damage hit and does not.
func _triage_applied(target: Dictionary, def: Dictionary) -> bool:
	if not bool(def.get("triage", false)):
		return false
	var max_hp := maxi(int(target.get("max_hp", class_base_hp(str(target.get("class_id", ""))))), 1)
	return float(int(target.get("hp", 0))) / float(max_hp) < SpellKits.TRIAGE_HP_THRESHOLD


func _apply_heal(target: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var room := int(target.get("max_hp", class_base_hp(str(target.get("class_id", ""))))) - int(target.get("hp", 0))
	var healed := mini(amount, maxi(room, 0))
	target["hp"] = int(target["hp"]) + healed
	return healed


## Fallen teammates a revive can reach: on the board, in range and sight, and
## their cell not taken by a living body.
func _revivable_allies(actor: Dictionary, def: Dictionary) -> Array:
	var out: Array = []
	if bool(def.get("once_per_match", false)) and bool(actor.get("used_" + str(def.get("id", "")), false)):
		return out
	for unit in _units:
		if int(unit["seat"]) == int(actor["seat"]) or bool(unit.get("alive", false)) or not _allied(unit, actor):
			continue
		if not bool(unit.get("placed", true)) or not _in_bounds(unit["pos"]):
			continue
		if not _living_unit_at(unit["pos"]).is_empty():
			continue
		if _in_spell_reach(def, actor["pos"], unit["pos"]):
			out.append(unit)
	return out


func _fallen_ally_at(actor: Dictionary, cell: Vector2i) -> Dictionary:
	for unit in _units:
		if int(unit["seat"]) == int(actor["seat"]) or bool(unit.get("alive", false)) or not _allied(unit, actor):
			continue
		if bool(unit.get("placed", true)) and unit["pos"] == cell:
			return unit
	return {}


## Rekindle (Mauro 3 Oct 2026): a fallen teammate stands up with revive_pct of
## max HP, statuses cleared. Once per match per caster. No roll.
func _resolve_revive(intent: Dictionary, actor: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	var spell_id := str(def.get("id", ""))
	if bool(def.get("once_per_match", false)) and bool(actor.get("used_" + spell_id, false)):
		return _reject(intent, "once_per_match", "REJECT — %s is once per match (refund)." % def["name"])
	var body := _fallen_ally_at(actor, dest)
	if body.is_empty():
		return _reject(intent, "no_target", "REJECT — %s needs a fallen ally (refund)." % def["name"])
	if not _living_unit_at(dest).is_empty():
		return _reject(intent, "destination_occupied", "REJECT — someone is standing on %s's body (refund)." % body["name"])
	actor["ap"] = int(actor["ap"]) - ap_cost
	_spend_mp(actor, mp_cost)
	actor["used_" + spell_id] = true
	var pulse_spent := _spend_resource(actor, "pulse", int(def.get("spend_pulse", 0))) if int(def.get("spend_pulse", 0)) > 0 else 0
	var max_hp := maxi(int(body.get("max_hp", 1)), 1)
	var hp := maxi(roundi(float(max_hp) * float(def.get("revive_pct", 30)) / 100.0), 1)
	body["alive"] = true
	body["hp"] = hp
	for key in ["stun_remaining", "burn_remaining", "burn_stacks", "marks", "shield", "hit_immunity"]:
		if body.has(key):
			body[key] = 0
	body["stunned"] = false
	body["invisible"] = false
	_intent_log.append(intent)
	_last_coach = "%s Rekindles %s (−%d AP): back on their feet with %d HP." % [actor["name"], body["name"], ap_cost, hp]
	_last_events.append({
		"type": "hit",
		"seat": actor["seat"],
		"spell": spell_id,
		"caster_cell": actor["pos"],
		"target_seat": body["seat"],
		"to": dest,
		"range": dist,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"damage": 0,
		"healed": hp,
		"revived": true,
		"engine": "pulse",
		"engine_spent": pulse_spent,
		"coach": _last_coach,
	})
	return _accept()


func _resolve_support(intent: Dictionary, actor: Dictionary, target: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	var spell_id := str(def.get("id", ""))
	if spell_id == SpellKits.WARD and int(target.get("shield", 0)) > 0:
		return _reject(intent, "open_can_wait", "REJECT — shield stacking is open (can-wait).")
	if spell_id == SpellKits.HEARTSTOP and int(target.get("hit_immunity", 0)) > 0:
		return _reject(intent, "open_can_wait", "REJECT — immunity refresh is open (can-wait).")
	actor["ap"] = int(actor["ap"]) - ap_cost
	_spend_mp(actor, mp_cost)
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
		var heal_amount := _support_heal_amount(actor, target, def)
		if str(actor.get("still", "")) == "mercy" and bool(actor.get("still_ready", false)):
			# Mercy Still: first heal +8 (Overwound +16 and Cleanse).
			actor["still_ready"] = false
			var over := str(actor.get("still_mode", "")) == "overwound"
			heal_amount += 16 if over else 8
			if over:
				target["stun_remaining"] = 0
				target["stunned"] = false
				target["burn_remaining"] = 0
				target["burn_stacks"] = 0
			_still_fired(actor, "mercy")
		healed = _apply_heal(target, heal_amount)
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
		# Cleanse clears Stun, then strips ONE map family (Mauro's Map push
		# stacks sheet): the highest stack; ties go Slow, Breathless, Burn,
		# Frozen, Electrocuted.
		if int(target.get("stun_remaining", 0)) > 0 or bool(target.get("stunned", false)):
			cc_removed.append("stun")
		target["stun_remaining"] = 0
		target["stunned"] = false
		var family := cleanse_pick(target)
		if family != "":
			_strip_family(target, family)
			cc_removed.append(family)
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
	var infused := _infuse(actor, target, def)
	if infused != "":
		hit_event["infusion"] = infused
		hit_event["coach"] = str(hit_event["coach"]) + " %s carries %s: their next hit of another element fires a Blend." % [str(target.get("name", "")), infused.capitalize()]
	_last_events.append(hit_event)
	return _accept()


const CLEANSE_ORDER := ["slow", "breathless", "burn", "frozen", "electrocuted"]
const _FAMILY_KEYS := {
	"slow": ["slow_stacks", "slow_remaining"],
	"breathless": ["breathless_stacks", "breathless_remaining"],
	"burn": ["burn_stacks", "burn_remaining"],
	"frozen": ["frozen_stacks", "frozen_remaining"],
	"electrocuted": ["electro_stacks", "electro_remaining"],
}


## The family Cleanse strips: highest live stack, ties in CLEANSE_ORDER.
static func cleanse_pick(unit: Dictionary) -> String:
	var best := ""
	var best_stack := 0
	for family in CLEANSE_ORDER:
		var keys: Array = _FAMILY_KEYS[family]
		var stack := int(unit.get(keys[0], 0))
		if int(unit.get(keys[1], 0)) <= 0:
			stack = 0
		if family == "slow" and stack == 0 and int(unit.get("slow_remaining", 0)) > 0:
			stack = 1
		if stack > best_stack:
			best = family
			best_stack = stack
	return best


func _strip_family(unit: Dictionary, family: String) -> void:
	var keys: Array = _FAMILY_KEYS[family]
	unit[keys[0]] = 0
	unit[keys[1]] = 0
	if family == "breathless":
		unit["breathless_spell"] = ""
		unit["silenced_spells"] = []


## Mauro (29 Sep): Invisible lasts INVISIBLE_TURNS of Gloam's own turns.
## Fade sets invisible_turns; each Gloam turn start counts one down and at 0
## Gloam is revealed (expire "invisible"). With 1: cast on turn T, hidden
## through the enemy's next turn, visible from Gloam's turn T+1.
## An attack still reveals at once. A fixture with invisible but no
## invisible_turns has no clock (tests / old snapshots).
func _resolve_fade(intent: Dictionary, actor: Dictionary, def: Dictionary, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	_spend_mp(actor, mp_cost)
	var gained := _gain_resource(actor, "umbral", 1)
	actor["invisible"] = true
	actor["invisible_turns"] = INVISIBLE_TURNS
	_intent_log.append(intent)
	_last_coach = "%s Fade (−%d AP / −%d MP). Invisible for %d turn%s. +%d Umbral." % [actor["name"], ap_cost, mp_cost, INVISIBLE_TURNS, "" if INVISIBLE_TURNS == 1 else "s", gained]
	_last_events.append({
		"type": "cast",
		"spell": SpellKits.FADE,
		"seat": actor["seat"],
		"caster_cell": caster_cell,
		"rolled": false,
		"ap_spent": ap_cost,
		"mp_spent": mp_cost,
		"invisible": true,
		"invisible_turns": INVISIBLE_TURNS,
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
		_spend_mp(actor, mp_cost)
		_shade_tokens.append({
			"pos": dest,
			"turns": int(def.get("shade_turns", 3)),
			"owner_seat": int(actor["seat"]),
			# 0 until the opponent finishes a turn. Not a caster-turn comparison.
			"opponent_turns_completed": 0,
		})
		_sync_shade_flags()
		_intent_log.append(intent)
		# No tile in the coach: Shades are secret to their owner.
		_last_coach = "%s drops a Shade (−%d AP)." % [actor["name"], ap_cost]
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
		_spend_mp(actor, mp_cost)
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
	_spend_mp(actor, mp_cost)
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
	_spend_mp(actor, mp_cost)
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
		_break_invisible_on_attack(actor)
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
		var pre_mitigation := _phase_a_damage(int(def.get("base_damage", 26)), facing_mult, actor, target, str(def.get("element", "")), true)
		var mitigation := _mitigate_hit(actor, target, pre_mitigation)
		var damage := int(mitigation["damage"])
		target["hp"] = maxi(0, int(target["hp"]) - damage)
		var push_result: Dictionary = {}
		var burn_info: Dictionary = {}
		var silence_info: Dictionary = {}
		var slow_info: Dictionary = {}
		if int(def.get("push_cells", 0)) > 0:
			push_result = _try_push(actor["pos"], target, int(def["push_cells"]), _earth_push(actor, def))
			var punish := _apply_landing_punishments(target, push_result)
			burn_info = punish["burn"]
			silence_info = punish["silence"]
			slow_info = punish["slow"]
		var row := {
			"target_seat": int(target["seat"]),
			"cell": cell,
			"hit": true,
			"damage": damage,
			"facing_mult": facing_mult,
			"back": is_back,
		}
		_stamp_push_fields(row, push_result, burn_info, silence_info, slow_info)
		_stamp_mitigation(row, mitigation)
		_stamp_riders(row, _flex_target(actor, target, def), def)
		targets.append(row)
		if aim_row.is_empty() or cell == dest:
			aim_row = row
		total += damage
		hit_bodies += 1
		_emit_push_followups(actor, target, push_result, burn_info)
		_append_soft_lock_status(target, silence_info, slow_info)
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
	if hit_bodies > 0:
		var cast_tags: Array = (aim_row.get("riders", []) as Array).duplicate()
		cast_tags.append_array(_flex_caster(actor, def))
		_stamp_riders(hit_event, cast_tags, def)
	_last_events.append(hit_event)
	_break_invisible_on_attack(actor)
	return _accept()


func _stamp_push_fields(row: Dictionary, push_result: Dictionary, burn_info: Dictionary, silence_info: Dictionary = {}, slow_info: Dictionary = {}) -> void:
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
	if not burn_info.is_empty():
		row["burn_refreshed"] = bool(burn_info.get("refreshed", false))
		row["burn_remaining"] = int(burn_info.get("remaining", 0))
		row["burn_stacks"] = int(burn_info.get("stacks", 0))
		row["burn_previous_stacks"] = int(burn_info.get("previous_stacks", 0))
		row["land_hp"] = int(burn_info.get("land_hp", 0))
	row["silence_applied"] = not silence_info.is_empty()
	if not silence_info.is_empty():
		row["silenced_spell"] = str(silence_info.get("spell", ""))
	row["slow_applied"] = not slow_info.is_empty()
	if not slow_info.is_empty():
		row["slow_remaining"] = int(slow_info.get("remaining", 0))


func _copy_push_fields(hit_event: Dictionary, row: Dictionary) -> void:
	for key in ["pushed", "push_from", "push_to", "push_attempted", "push_blocked", "bounced", "staggered", "burn_applied", "burn_refreshed", "burn_remaining", "burn_stacks", "burn_previous_stacks", "land_hp", "silence_applied", "silenced_spell", "slow_applied", "slow_remaining"]:
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
	_append_lava_castigo(target, burn_info)


func _resolve_hold_line(intent: Dictionary, actor: Dictionary, def: Dictionary, ap_cost: int, mp_cost: int) -> Dictionary:
	var caster_cell: Vector2i = actor["pos"]
	if not _cone_enemies(actor, true).is_empty():
		return _reject(intent, "open_can_wait", "REJECT — AoE versus Invisible is open (can-wait).")
	var bodies: Array = _cone_enemies(actor, false)
	if bodies.is_empty():
		return _reject(intent, "no_target", "REJECT — Hold Line needs an enemy in the cone (refund).")
	actor["ap"] = int(actor["ap"]) - ap_cost
	_spend_mp(actor, mp_cost)
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
		_break_invisible_on_attack(actor)
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
		var pre_mitigation := _phase_a_damage(int(def.get("base_damage", 7)), facing_mult, actor, target, str(def.get("element", "")), true)
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
		_stamp_riders(row, _flex_target(actor, target, def), def)
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
	var hold_tags: Array = []
	if hit_bodies > 0:
		for r in targets:
			hold_tags.append_array(r.get("riders", []))
		hold_tags.append_array(_flex_caster(actor, def))
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
	_stamp_riders(_last_events[_last_events.size() - 1], hold_tags, def)
	_break_invisible_on_attack(actor)
	return _accept()


## A hit that has not relocated deals nothing. Presentation must not be the
## only thing keeping the 22 off the cast cell.
static func ambush_damage_if_planted(struck_from: Vector2i, landing: Vector2i, damage: int) -> int:
	if struck_from != landing:
		return 0
	return maxi(damage, 0)


## Soft Lock 2026-09-26: a resolved attack ends Invisible, hit or miss.
## Drop Shade, Fade, walks, and a rejected cast do not. Fade still grants it.
func _break_invisible_on_attack(actor: Dictionary) -> void:
	if bool(actor.get("invisible", false)):
		actor["invisible"] = false
	actor["invisible_turns"] = 0


func _resolve_ambush(intent: Dictionary, actor: Dictionary, target: Dictionary, def: Dictionary, dest: Vector2i, dist: int, ap_cost: int, mp_cost: int) -> Dictionary:
	var blocked := _ambush_block_reason(actor, target)
	if blocked != "":
		return _reject(intent, blocked, _ambush_reject_text(blocked))
	var caster_cell: Vector2i = actor["pos"]
	var pick := _ambush_selected(actor, target, intent)
	if pick.is_empty():
		return _reject(intent, "no_shade", "REJECT — Ambush has no legal origin (refund).")
	var landing: Dictionary = pick.get("landing", {})
	if not bool(landing.get("ok", false)):
		return _reject(intent, "illegal_back", "REJECT — Ambush back tile is occupied or illegal (refund).")
	# Shade origin spends a Shade. Invisible self-origin does not. Invisible
	# does not forbid the Shade: a legal armed Shade is still that origin.
	var from_shade := bool(pick.get("from_shade", false))
	var origin_cell: Vector2i = pick["origin"]
	actor["ap"] = int(actor["ap"]) - ap_cost
	_spend_mp(actor, mp_cost)
	var chance := hit_chance(dist)
	var roll := _roll_d100()
	var connected := roll <= chance
	_intent_log.append(intent)
	if not connected:
		# MISS does not teleport and does not spend Shade. It is still an attack,
		# so Invisible ends. A rejected cast never reaches this branch.
		var was_invisible := bool(actor.get("invisible", false))
		_break_invisible_on_attack(actor)
		var notes := "No teleport."
		if bool(actor.get("shade", false)):
			notes += " Shade stays."
		if was_invisible:
			notes += " Invisible ends."
		_last_coach = "MISS — Ambush (%d vs %d%%). %s −%d AP." % [roll, chance, notes, ap_cost]
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
	# Hit always plants on the back tile before damage. Adjacent, Invisible,
	# and Shade origins all take this branch. Identity (already standing there)
	# still counts as the teleport. A miss returned above and did not move.
	actor["pos"] = cell
	# Face the prey from the back tile. Miss keeps the old facing.
	var face_dir := facing_from_step(cell, target["pos"])
	if face_dir != "":
		actor["facing"] = face_dir
	if from_shade:
		_remove_shade_at(origin_cell, int(actor["seat"]))
		_sync_shade_flags()
	var facing_mult := SpellKits.BACKSTAB_MULT if backstab else FRONT_SIDE_FACING
	var pre_mitigation := _phase_a_damage(int(def.get("base_damage", 22)), facing_mult, actor, target, str(def.get("element", "")), true)
	var mitigation := _mitigate_hit(actor, target, pre_mitigation)
	var damage := int(mitigation["damage"])
	# Pos was assigned above. Damage is the strike from that tile. A reorder
	# that subtracts HP while the body is still on the cast cell deals nothing:
	# Invisible self-origin and Shade origin both have to land first.
	var struck_from: Vector2i = actor["pos"]
	damage = ambush_damage_if_planted(struck_from, cell, damage)
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	# Teleport and the hit are done. The attack ends Invisible after that.
	_break_invisible_on_attack(actor)
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
		"struck_from": struck_from,
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
	var ambush_tags := _flex_target(actor, target, def)
	ambush_tags.append_array(_flex_caster(actor, def))
	_stamp_riders(_last_events[_last_events.size() - 1], ambush_tags, def)
	_emit_immunity_spent(target, mitigation)
	_check_death(target)
	return _accept()


## Locked destination is one step past the enemy on the origin axis (the back
## tile). Facing-rear is not the landing: when the foe faces away, that tile is
## often the cell Gloam already occupies, so the hit reads as a body slash with
## no teleport. Occupied / OOB / unwalkable back tiles reject. Backstab follows
## the rear cone from the landing tile, not from the old body.
func _ambush_landing(actor: Dictionary, target: Dictionary) -> Dictionary:
	var pick := _ambush_selected(actor, target, {})
	if pick.is_empty():
		return {"ok": false}
	return pick.get("landing", {"ok": false})


func _ambush_landing_from(origin: Vector2i, actor: Dictionary, target: Dictionary) -> Dictionary:
	if origin == UNPLACED or target.is_empty():
		return {"ok": false}
	var step := _cardinal_unit_step(origin, target["pos"])
	if step == Vector2i.ZERO:
		return {"ok": false}
	var back: Vector2i = target["pos"] + step
	if not _ambush_cell_ok(back, actor["pos"]):
		return {"ok": false}
	var facing := str(target.get("facing", ""))
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
	# The back tile is a voluntary landing. Mud, water, and lava stay illegal
	# there. The enemy body can still stand on one of those tiles; that cell
	# is the target, not this landing.
	if _board.is_voluntary_impassable(cell):
		return false
	return _board.is_walkable(cell)


## Legal Ambush arm: some origin is Manhattan 1–2 cardinal from the foe, the back
## tile is an empty walkable landing, and a Shade origin has seen the opponent
## finish at least one turn. Invisible self-origin has no arming delay and does
## not remove a Shade that is still legal. Diagonals and Manhattan 3+ are not an
## arm. Landing uses the same cell as resolve. Offer, preview, origin chrome,
## and the HUD share this gate.
func _ambush_can_offer(actor: Dictionary, enemy: Dictionary) -> bool:
	return _ambush_block_reason(actor, enemy) == ""


## "" when Ambush may arm. Otherwise no_shade, shade_unarmed, out_of_range,
## wall_on_ray, illegal_back, or no_target. Visible needs an armed Shade. Invisible may use
## Gloam immediately, and an armed Shade as well. A Shade stays illegal until
## the opponent has completed ≥1 full turn since it was Dropped.
func _ambush_block_reason(actor: Dictionary, enemy: Dictionary) -> String:
	if enemy.is_empty() or not bool(enemy.get("alive", false)):
		return "no_target"
	if not _ambush_legal_picks(actor, enemy).is_empty():
		return ""
	var invisible := _ambush_self_origin(actor)
	if _live_shades(actor).is_empty() and not invisible:
		return "no_shade"
	var shade_block := ""
	var self_block := ""
	for item in _ambush_candidates(actor, enemy):
		var cand: Dictionary = item
		var reason := str(cand.get("block", ""))
		if bool(cand.get("from_shade", false)):
			if shade_block == "":
				shade_block = reason
		else:
			self_block = reason
	if not invisible:
		return shade_block if shade_block != "" else "no_shade"
	# The body has no arming delay. When the body is out of range, the Shade's
	# own reason (unarmed, blocked back, wall) is the more useful one.
	if self_block == "out_of_range" and shade_block != "" and shade_block != "out_of_range":
		return shade_block
	if self_block != "":
		return self_block
	return shade_block if shade_block != "" else "no_shade"


func _ambush_reject_text(reason: String) -> String:
	if reason == "illegal_back" or reason == "no_landing":
		return "REJECT — Ambush back tile is occupied or illegal (refund)."
	if reason == "wall_on_ray":
		return "REJECT — Snap Wall blocks the Ambush ray (refund)."
	if reason == "shade_unarmed":
		return "REJECT — Shade is not armed for Ambush until the opponent completes a turn (refund)."
	if reason == "no_shade":
		return "REJECT — Ambush has no legal origin (refund)."
	if reason == "no_target":
		return "REJECT — Ambush needs an enemy (refund)."
	return "REJECT — Ambush is Manhattan 1–2 cardinal from the origin (refund)."


## Range cell for highlights and the generic distance gate. A legal origin wins.
## Otherwise the Shade (or Gloam, while Invisible) so a far Shade still reads
## out_of_range instead of borrowing the body.
func _ambush_range_origin(actor: Dictionary) -> Vector2i:
	return _ambush_measure_cell(actor, _ambush_primary_enemy(actor))


func _ambush_primary_enemy(actor: Dictionary) -> Dictionary:
	if _stasis_pack or _team_size > 1:
		var legal := _first_legal_ambush_target(actor)
		if not legal.is_empty():
			return legal
	return _enemy_of(int(actor.get("seat", -1)))


func _ambush_focus_enemy(actor: Dictionary, dest: Vector2i) -> Dictionary:
	var at := _living_unit_at(dest)
	if not at.is_empty() and bool(at.get("alive", false)) and not _allied(at, actor):
		return at
	return _ambush_primary_enemy(actor)


func _ambush_cell_is_origin(actor: Dictionary, cell: Vector2i) -> bool:
	if _ambush_self_origin(actor) and cell == actor["pos"]:
		return true
	for item in _live_shades(actor):
		var token: Dictionary = item
		if token.get("pos") == cell:
			return true
	return false


func _ambush_measure_cell(actor: Dictionary, enemy: Dictionary) -> Vector2i:
	var selected := _ambush_selected(actor, enemy, {})
	if not selected.is_empty():
		return selected["origin"]
	for item in _ambush_candidates(actor, enemy):
		var cand: Dictionary = item
		if bool(cand.get("axis_ok", false)):
			return cand["origin"]
	if _ambush_self_origin(actor):
		return actor["pos"]
	var shade := _first_shade(actor)
	if shade.is_empty():
		return UNPLACED
	return shade["pos"]


## Mauro, 30 Sep 2026: "ambush can be used without being invisible". Gloam's
## own tile is always an Ambush origin (no arming delay); Invisible is no
## longer required. Armed Shades still add other angles.
const AMBUSH_SELF_ALWAYS := true


func _ambush_self_origin(actor: Dictionary) -> bool:
	return AMBUSH_SELF_ALWAYS or bool(actor.get("invisible", false))


## Every Shade, then Gloam's own tile. `block` is "" when that origin may resolve.
func _ambush_candidates(actor: Dictionary, enemy: Dictionary) -> Array:
	var out: Array = []
	if enemy.is_empty() or not bool(enemy.get("alive", false)):
		return out
	for item in _live_shades(actor):
		var token: Dictionary = item
		var armed := int(token.get("opponent_turns_completed", 0)) >= 1
		out.append(_ambush_candidate(actor, enemy, token["pos"], true, armed))
	if _ambush_self_origin(actor):
		out.append(_ambush_candidate(actor, enemy, actor["pos"], false, true))
	return out


func _ambush_candidate(actor: Dictionary, enemy: Dictionary, origin_cell: Vector2i, from_shade: bool, armed: bool) -> Dictionary:
	var def: Dictionary = SpellKits.spell_for(actor, SpellKits.AMBUSH)
	var axis := _cardinal_axis_len(origin_cell, enemy["pos"])
	var axis_ok := axis >= int(def.get("min_range", 1)) and axis <= int(def.get("max_range", 2))
	var landing := _ambush_landing_from(origin_cell, actor, enemy) if axis_ok else {"ok": false}
	var block := ""
	if not axis_ok:
		block = "out_of_range"
	elif _ambush_ray_walled(origin_cell, enemy["pos"]):
		block = "wall_on_ray"
	elif from_shade and not armed:
		block = "shade_unarmed"
	elif not bool(landing.get("ok", false)):
		block = "illegal_back"
	return {
		"origin": origin_cell,
		"from_shade": from_shade,
		"armed": 1 if armed else 0,
		"block": block,
		"landing": landing,
		"axis_ok": axis_ok,
	}


## Locked: the origin must see the target along the cardinal shot ray. A Snap
## Wall on any cell strictly between them blocks that origin (grey, 0 AP).
## Mauro 30 Sep 2026: Gloam cannot Ambush through a wall or obstacle; a
## Shade on another side may still give him a clear angle. Same walls as
## spell sight: Snap Wall / blocker, solid prop or a fighter (raised ground
## does not block since Mauro 5 Oct 2026).
func _ambush_ray_walled(origin_cell: Vector2i, target_cell: Vector2i) -> bool:
	var step := _cardinal_unit_step(origin_cell, target_cell)
	if step == Vector2i.ZERO:
		return false
	var top := maxi(_elevation_at(origin_cell), _elevation_at(target_cell))
	var cell: Vector2i = origin_cell + step
	while cell != target_cell:
		if _blocks_sight(cell, top):
			return true
		cell += step
	return false


func _ambush_legal_picks(actor: Dictionary, enemy: Dictionary) -> Array:
	var out: Array = []
	for item in _ambush_candidates(actor, enemy):
		var cand: Dictionary = item
		if str(cand.get("block", "x")) == "":
			out.append(cand)
	return out


## Shade jump that actually leaves the cast cell, then a self jump, then an
## identity landing. A Shade whose back tile is the tile Gloam already occupies
## must not win over a self-origin that plants somewhere else: that reads as a
## slash from the body.
func _ambush_prefer(picks: Array, caster_pos: Vector2i) -> Dictionary:
	var relocating_shade: Dictionary = {}
	var relocating_self: Dictionary = {}
	var identity_shade: Dictionary = {}
	var identity_self: Dictionary = {}
	for item in picks:
		var pick: Dictionary = item
		var landing: Dictionary = pick.get("landing", {})
		var land_cell: Vector2i = landing.get("cell", caster_pos)
		var away := land_cell != caster_pos
		var from_shade := bool(pick.get("from_shade", false))
		if from_shade and away and relocating_shade.is_empty():
			relocating_shade = pick
		elif not from_shade and away and relocating_self.is_empty():
			relocating_self = pick
		elif from_shade and identity_shade.is_empty():
			identity_shade = pick
		elif identity_self.is_empty():
			identity_self = pick
	if not relocating_shade.is_empty():
		return relocating_shade
	if not relocating_self.is_empty():
		return relocating_self
	if not identity_shade.is_empty():
		return identity_shade
	return identity_self


func _ambush_selected(actor: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	var picks := _ambush_legal_picks(actor, enemy)
	if picks.is_empty():
		return {}
	var caster_pos: Vector2i = actor["pos"]
	var preferred := _ambush_prefer(picks, caster_pos)
	if intent.has("origin"):
		var want := _as_cell(intent.get("origin"))
		for item in picks:
			var pick: Dictionary = item
			if pick.get("origin") != want:
				continue
			var landing: Dictionary = pick.get("landing", {})
			# An explicit plate that would slash in place loses to a jump.
			if landing.get("cell", caster_pos) == caster_pos and preferred.get("landing", {}).get("cell", caster_pos) != caster_pos:
				return preferred
			return pick
	return preferred


func _live_shades(actor: Dictionary) -> Array:
	var out: Array = []
	for item in _shade_tokens:
		var token: Dictionary = item
		if int(token.get("owner_seat", -1)) != int(actor.get("seat", -2)):
			continue
		if int(token.get("turns", 0)) <= 0:
			continue
		out.append(token)
	return out


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
		if team_of_seat(int(token.get("owner_seat", -1))) == team_of_seat(ending_seat):
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
## the owner — the same turn-start family as Soft Lock Burn (the affected
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
