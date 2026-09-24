extends Node2D

## Thin client: input + presentation only. CombatSim owns rolls and combat state.
## Walk: dest-click only. CombatSim expands the cheapest weighted ortho path; this
## view never sends intent.path. Pawns tween one ortho tile at a time along the
## returned walk path and face each hop (final facing = last hop, matching the snapshot).
## Live elevation chrome: tiles paint snapshot.tiles elevation + terrain_type.
## Walk highlights are CombatSim.legal_intents dests only (no client pathfinder).
## Z-sort is VIEW-only (BoardVisualSort). Hit bands / facing / spell LoS stay flat.
## Advance teleport does not auto-face.
## Locked deploy chrome: bind place_unit / ready_seat / legal_deploy_cells /
## deploy_zone_cells / can_ready / snapshot().phase. Hidden enemy stays Open.
## Advance: dest-click teleport snap. No hop playback; CombatSim ignores client path.
## After Advance, spell selection clears so walk chrome comes back from legal_intents.
## Walk is a dedicated action-bar mode (Walk button / Esc). Right-click still faces.
## Rolling enemy spells: selected chrome paints the Chebyshev range ring; walk chrome stays off.
## Aim preview shows Locked hit percent for rolling casts. Advance and walks have none.
## Proposed timers: ~1.0s client-only seat handoff banner. The 30s seat clock is
## host-owned (snapshot.turn_time_remaining). Guest hydrates; it does not tick.
## Walk hops lock input but do not pause the host clock.
## Locked Stun (A′): Walk / Face / spells grey on HUD; this view does not submit them.
## CombatSim auto-resolves end_turn when a stunned seat's turn starts.
## Client chrome: if CombatSim auto end_turns a stunned seat, show a skip banner.
## Occupied push dest toasts PushBlocked (no hop).
## Unwalkable / lava / OOB dest toasts Bounce (no hop) and emits stagger HP/MP.
## Online listen-host: NetSession owns submit when a peer is up. Hot-seat still
## calls CombatSim.submit directly. The view never rolls.
## The queue host is not a fighter and does not start the default hot-seat pair.
## A queue client paints when the paired snapshot arrives.

const BOARD_SIZE: int = 8
const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")
const PAWN_SCENE: PackedScene = preload("res://units/pawn.tscn")
const COMBAT_SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const STEP_SEC: float = 0.28
const STEP_PAUSE_SEC: float = 0.08
const HANDOFF_SEC: float = 1.0

var tiles: Dictionary = {}
var selected_tile: BoardTile = null
var pawns_by_seat: Dictionary = {}
var _hud: CombatHUD
var _booted: bool = false
var _busy: bool = false
var _clock_expired_pending: bool = false
var _walk_tween: Tween
var _turn_clock := TurnClock.new()
var _deploy_selected_seat: int = -1
var _board_data: Dictionary = {}
var _skip_local_net_echo: bool = false


func _ready() -> void:
	_hud = $"../HUD" as CombatHUD
	_hud.set_preview_source(_sim())
	_hud.spell_selected.connect(_on_spell_selected)
	_hud.face_requested.connect(_on_face_requested)
	_hud.end_turn_requested.connect(_on_end_turn_button_pressed)
	_hud.new_match_requested.connect(_on_new_match)
	_hud.ready_requested.connect(_on_ready_requested)

	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var tile := TILE_SCENE.instantiate() as BoardTile
			tile.grid_position = Vector2i(x, y)
			tile.apply_board_data("ground", 0.0)
			tile.position = VISUAL_SORT.cell_to_local(tile.grid_position, 0.0)
			tile.z_index = VISUAL_SORT.tile_z_index(tile.grid_position, 0.0)
			$Tiles.add_child(tile)
			tiles[tile.grid_position] = tile

	call_deferred("_boot")


func _boot() -> void:
	var net := _net()
	if net != null:
		if not net.state_changed.is_connected(_on_net_state):
			net.state_changed.connect(_on_net_state)
		if net.is_online() or net.is_connecting():
			if net.is_host():
				net.reset_match({})
			if net.is_host() or net.has_view_state():
				_finish_boot()
			return
	CombatSim.reset_match({})
	_finish_boot()


func _finish_boot() -> void:
	_rebuild_pawns()
	_booted = true
	_refresh()
	_hydrate_turn_clock()


func _net() -> Node:
	return get_node_or_null("/root/NetSession")


func _sim() -> Node:
	var net := _net()
	if net != null and net.is_online():
		return net
	return CombatSim


func _online() -> bool:
	var net := _net()
	return net != null and net.is_online()


func _can_control_seat(seat: int) -> bool:
	var net := _net()
	if net == null or not net.is_online():
		return true
	return net.owns_seat(seat)


func _mark_local_net_echo() -> void:
	if _online():
		_skip_local_net_echo = true


func _on_net_state(events: Array, _snap: Dictionary) -> void:
	if not _booted:
		_skip_local_net_echo = false
		_finish_boot()
		return
	if _skip_local_net_echo:
		_skip_local_net_echo = false
		return
	if _busy:
		return
	_play_combat_feedback(events)
	if CombatHUD.events_include_push_blocked(events):
		_hud.show_toast(CombatHUD.PUSH_BLOCKED_TOAST)
		_refresh()
		return
	if CombatHUD.events_include_push_bounce(events):
		_hud.show_toast(CombatHUD.BOUNCE_TOAST)
		_refresh()
		return
	if CombatHUD.should_play_walk_hops(events):
		var path_event := _path_event(events)
		if not path_event.is_empty():
			await _play_walk(int(path_event.get("seat", 0)), path_event["path"])
			return
	_refresh()
	_hydrate_turn_clock()
	if _has_turn_change(events) and not _busy:
		_present_turn_handoff({"events": events, "snapshot": _sim().snapshot()})


func local_to_grid(point: Vector2) -> Vector2i:
	# Nearest painted tile so elevated (view-offset) cells stay clickable.
	var best := Vector2i(-1, -1)
	var best_d := 22.0
	for cell in tiles.keys():
		var tile: BoardTile = tiles[cell]
		var dist := point.distance_to(tile.position)
		if dist < best_d:
			best_d = dist
			best = cell
	if best.x >= 0:
		return best
	var grid_x := point.x / 64.0 + point.y / 32.0
	var grid_y := point.y / 32.0 - point.x / 64.0
	return Vector2i(floori(grid_x + 0.5), floori(grid_y + 0.5))


func _process(delta: float) -> void:
	if not _booted:
		return
	var snap: Dictionary = _sim().snapshot()
	if CombatHUD.is_deployment_phase(snap) or bool(snap.get("match_over", false)):
		_hydrate_turn_clock(snap)
		return
	# Host / hot-seat tick CombatSim. Guest never ticks — remaining is snapshot-only.
	# Keep ticking during walk hop animations. _busy only locks input.
	var result: Dictionary = {}
	if not (_online() and _net().is_client()):
		if _sim().has_method("tick_turn_timer"):
			result = _sim().tick_turn_timer(delta)
	_hydrate_turn_clock(_sim().snapshot())
	if _timer_expired(result):
		_on_turn_clock_expired(result)


func _hydrate_turn_clock(snap: Dictionary = {}) -> void:
	if _hud == null:
		return
	var view: Dictionary = snap if not snap.is_empty() else _sim().snapshot()
	var remaining := float(view.get("turn_time_remaining", 0.0))
	var limit := float(view.get("turn_time_limit", TurnClock.DURATION_SEC))
	_turn_clock.hydrate(remaining, CombatHUD.turn_clock_running(view), limit)
	_sync_turn_clock(view)


func _sync_turn_clock(snap: Dictionary = {}) -> void:
	if _hud == null:
		return
	var view: Dictionary = snap if not snap.is_empty() else _sim().snapshot()
	var seconds := CombatHUD.turn_clock_seconds(view)
	if seconds < 0:
		seconds = _turn_clock.display_seconds()
	var running := CombatHUD.turn_clock_running(view) if CombatHUD.has_host_turn_clock(view) else _turn_clock.running
	var fraction := CombatHUD.turn_clock_fraction(view) if view.has("turn_time_remaining") else _turn_clock.fraction_left()
	_hud.set_turn_clock(seconds, running, fraction)


func _timer_expired(result: Dictionary) -> bool:
	if result.is_empty():
		return false
	if bool(result.get("expired", false)):
		return true
	for event in result.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "end_turn" and str(event.get("reason", "")) == "timer":
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("ui_cancel"):
		# Esc returns to Walk. Right-click stays face and is not a cancel.
		_return_to_walk()
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_position: Vector2 = $Tiles.get_local_mouse_position()
		var cell := local_to_grid(mouse_position)
		if not _in_bounds(cell):
			return
		select_tile(cell)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if CombatHUD.is_deployment_phase(_sim().snapshot()):
				return
			_face_toward(cell)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(cell)


func select_tile(cell: Vector2i) -> void:
	if selected_tile != null:
		selected_tile.set_selected(false)
	selected_tile = tiles[cell] as BoardTile
	selected_tile.set_selected(true)


func _handle_left_click(cell: Vector2i) -> void:
	if CombatHUD.is_deployment_phase(_sim().snapshot()):
		_handle_deploy_click(cell)
		return
	if not _can_control_seat(int(_sim().snapshot().get("active_seat", 0))):
		return
	if _active_is_stunned():
		return
	var spell_id := _hud.selected_spell()
	if spell_id == "":
		# Dest-click only. Do not send a client path.
		_submit({"type": "move", "to": cell})
		return
	var actor := _active_unit(_sim().snapshot())
	if actor.is_empty() or not CombatHUD.offered_cast_ids(actor).has(spell_id):
		_hud.clear_spell()
		_paint_highlights()
		return
	_submit({"type": "cast", "spell": spell_id, "to": cell})
	# After any dest-click cast (including Advance): drop spell chrome and
	# repaint walk tiles from legal_intents so remaining MP is selectable at 0 AP.
	_hud.clear_spell()
	_paint_highlights()


func _face_toward(cell: Vector2i) -> void:
	if _active_is_stunned():
		return
	var snap: Dictionary = _sim().snapshot()
	if not _can_control_seat(int(snap.get("active_seat", 0))):
		return
	var actor := _active_unit(snap)
	if actor.is_empty():
		return
	var delta: Vector2i = cell - actor["pos"]
	if delta == Vector2i.ZERO:
		return
	var dir := "E"
	if absi(delta.x) >= absi(delta.y):
		dir = "E" if delta.x > 0 else "W"
	else:
		dir = "S" if delta.y > 0 else "N"
	_submit({"type": "face", "dir": dir})


func _on_spell_selected(_spell_id: String) -> void:
	if _busy:
		return
	_paint_highlights()
	_sync_aim_preview()


func _return_to_walk() -> void:
	if _hud == null:
		return
	_hud.select_walk()
	_paint_highlights()


func _on_face_requested(dir: String) -> void:
	if CombatHUD.is_deployment_phase(_sim().snapshot()):
		return
	if not _can_control_seat(int(_sim().snapshot().get("active_seat", 0))):
		return
	if _active_is_stunned():
		return
	_submit({"type": "face", "dir": dir})


func _on_end_turn_button_pressed() -> void:
	if CombatHUD.is_deployment_phase(_sim().snapshot()):
		return
	if not _can_control_seat(int(_sim().snapshot().get("active_seat", 0))):
		return
	if _busy:
		return
	_busy = true
	_hud.clear_spell()
	_mark_local_net_echo()
	var result: Dictionary
	if _online() and _net().is_client():
		result = await _sim().submit_wait({"type": "end_turn"})
	elif _online():
		result = _sim().submit({"type": "end_turn"})
	else:
		result = CombatSim.submit({"type": "end_turn"})
	if not result.get("ok", false):
		_busy = false
		_refresh()
		return
	await _present_turn_handoff(result)


func _on_turn_clock_expired(result: Dictionary = {}) -> void:
	# Host already submitted end_turn. If hops are in flight, finish them first
	# then present the seat change. Do not submit again.
	if _busy:
		_clock_expired_pending = true
		return
	_clock_expired_pending = false
	await _present_turn_handoff(result)


func _present_turn_handoff(result: Dictionary) -> void:
	var snap: Dictionary = result.get("snapshot", _sim().snapshot())
	if snap.is_empty():
		snap = _sim().snapshot()
	if snap.get("match_over", false):
		_busy = false
		_refresh()
		_hydrate_turn_clock(snap)
		return
	# Proposed: client-only ~1.0s seat handoff. Host clock already advanced.
	# Locked A′: if the sim auto-skipped a stunned seat, present that event first.
	_busy = true
	_hud.set_locked(true)
	_refresh()
	_hydrate_turn_clock(snap)
	var skip: Dictionary = CombatHUD.stun_skip_event(result.get("events", []))
	if not skip.is_empty():
		var skip_unit := _unit_from_event(snap, skip)
		var skip_caption := CombatHUD.stun_skip_caption(skip, snap)
		_hud.show_turn_banner(str(skip_unit.get("name", "Seat")), str(skip_unit.get("class_id", "")), skip_caption)
		await get_tree().create_timer(HANDOFF_SEC).timeout
		if not is_inside_tree():
			return
	var next_unit := _active_unit(snap)
	var status := CombatHUD.turn_status_text(snap)
	var caption := status if status != "" else ""
	_hud.show_turn_banner(str(next_unit.get("name", "Next")), str(next_unit.get("class_id", "")), caption)
	await get_tree().create_timer(HANDOFF_SEC).timeout
	if not is_inside_tree():
		return
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_busy = false
	_refresh()
	_hydrate_turn_clock()


func _has_turn_change(events: Array) -> bool:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) in ["turn_start", "end_turn"]:
			return true
	return false


func _on_new_match() -> void:
	_stop_walk_tween()
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_busy = false
	_clock_expired_pending = false
	_deploy_selected_seat = -1
	_hud.clear_spell()
	_hud.clear_deploy_note()
	if _online() and not _sim().can_reset_match():
		return
	_mark_local_net_echo()
	_sim().reset_match({})
	_rebuild_pawns()
	_refresh()
	_hydrate_turn_clock()


func _submit(intent: Dictionary) -> void:
	if _busy:
		return
	_mark_local_net_echo()
	var result: Dictionary
	if _online() and _net().is_client():
		result = await _sim().submit_wait(intent)
	elif _online():
		result = _sim().submit(intent)
	else:
		result = CombatSim.submit(intent)
	if not result.get("ok", false) and str(result.get("reason", "")) in ["occupied", "same_tile", "out_of_bounds", "insufficient_mp", "missing_destination", "path_blocked", "not_walkable", "climb_too_steep", "drop_too_far", "unreachable"]:
		# Keep idle tile clicks from drowning the coach when simply selecting.
		if _hud.selected_spell() == "" and str(intent.get("type", "")) == "move":
			_refresh()
			return
	if result.get("ok", false):
		var events: Array = result.get("events", [])
		_play_combat_feedback(events)
		if CombatHUD.events_include_push_blocked(events):
			_hud.show_toast(CombatHUD.PUSH_BLOCKED_TOAST)
			# Occupied dest is a hard body-block. Snapshot already stayed put.
			_refresh()
			return
		if CombatHUD.events_include_push_bounce(events):
			_hud.show_toast(CombatHUD.BOUNCE_TOAST)
			# Bounce: unit stayed. Stagger HP/MP already applied in CombatSim.
			_refresh()
			return
		if CombatHUD.should_play_walk_hops(events):
			var path_event := _path_event(events)
			await _play_walk(int(path_event.get("seat", 0)), path_event["path"])
			return
	_refresh()


func _path_event(events: Array) -> Dictionary:
	for event in events:
		# Walk hops only. Advance is a teleport snap — do not play cell-by-cell path.
		# PushBlocked and bounce also never hop.
		if str(event.get("type", "")) == "move":
			return event
	return {}


func _play_combat_feedback(events: Array) -> void:
	# Hit flash on the target and Impact flash on the caster. Plays even when push is blocked.
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "hit":
			continue
		var target_seat := int(event.get("target_seat", -1))
		if pawns_by_seat.has(target_seat):
			var target_pawn: Pawn = pawns_by_seat[target_seat]
			target_pawn.flash_hit()
			_tween_pawn_modulate(target_pawn)
		if int(event.get("engine_gained", 0)) > 0 and str(event.get("engine", "")) == "impact":
			var caster_seat := int(event.get("seat", -1))
			if pawns_by_seat.has(caster_seat):
				var caster_pawn: Pawn = pawns_by_seat[caster_seat]
				caster_pawn.flash_impact()
				_tween_pawn_modulate(caster_pawn)


func _tween_pawn_modulate(pawn: Pawn) -> void:
	if pawn == null or not is_instance_valid(pawn) or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(pawn, "modulate", Color.WHITE, 0.28)


func _active_is_stunned(snap: Dictionary = {}) -> bool:
	if snap.is_empty():
		snap = _sim().snapshot()
	return CombatHUD.unit_is_stunned(_active_unit(snap))


func _play_walk(seat: int, path: Array) -> void:
	_busy = true
	_hud.set_locked(true)
	var snap: Dictionary = _sim().snapshot()
	_hud.render(snap, [])
	for tile in tiles.values():
		(tile as BoardTile).set_highlight("")
	for step in path:
		var cell: Vector2i = _as_cell(step)
		if tiles.has(cell):
			_tile_at(cell).set_highlight("move")
	await _animate_path(seat, path)
	if not is_inside_tree():
		return
	_hud.set_locked(false)
	_busy = false
	_refresh()
	if _clock_expired_pending:
		_clock_expired_pending = false
		_on_turn_clock_expired()


func _animate_path(seat: int, path: Array) -> void:
	if not pawns_by_seat.has(seat):
		return
	var pawn: Pawn = pawns_by_seat[seat]
	# One awaited hop per ortho tile so E/W-then-N/S cannot collapse into a diagonal slide.
	# Locked: facing follows each hop so the pointer matches CombatSim last-hop facing.
	var prev: Vector2i = pawn.grid_position
	for step in path:
		if not is_inside_tree() or pawn == null or not is_instance_valid(pawn):
			return
		var cell: Vector2i = _as_cell(step)
		var dir := COMBAT_SIM_SCRIPT.facing_from_step(prev, cell)
		if dir == "":
			dir = COMBAT_SIM_SCRIPT.hop_facing(prev, cell)
		pawn.set_facing(dir)
		_stop_walk_tween()
		_walk_tween = create_tween()
		_walk_tween.set_parallel(false)
		_walk_tween.set_trans(Tween.TRANS_LINEAR)
		_walk_tween.set_ease(Tween.EASE_IN_OUT)
		_walk_tween.tween_property(pawn, "position", _cell_to_local(cell), STEP_SEC)
		await _walk_tween.finished
		_set_pawn_cell(pawn, cell)
		prev = cell
		if STEP_PAUSE_SEC > 0.0:
			await get_tree().create_timer(STEP_PAUSE_SEC).timeout


func _set_pawn_cell(pawn: Pawn, cell: Vector2i) -> void:
	pawn.grid_position = cell
	pawn.z_index = VISUAL_SORT.unit_z_index(cell, _elev_at(cell))


func _stop_walk_tween() -> void:
	if _walk_tween != null and is_instance_valid(_walk_tween):
		_walk_tween.kill()
	_walk_tween = null


func _refresh() -> void:
	var snap: Dictionary = _sim().snapshot()
	var legal: Array = _sim().legal_intents(CombatHUD.kit_seat(snap))
	_apply_board_tiles(snap)
	_apply_units(snap)
	_hud.render(snap, legal)
	_paint_highlights()
	_hydrate_turn_clock(snap)


func _rebuild_pawns() -> void:
	for child in $Units.get_children():
		$Units.remove_child(child)
		child.free()
	pawns_by_seat.clear()
	for unit in _sim().snapshot().get("units", []):
		var pawn := PAWN_SCENE.instantiate() as Pawn
		$Units.add_child(pawn)
		pawns_by_seat[int(unit["seat"])] = pawn


func _apply_units(snap: Dictionary) -> void:
	for unit in snap.get("units", []):
		var seat := int(unit["seat"])
		if not pawns_by_seat.has(seat):
			continue
		var pawn: Pawn = pawns_by_seat[seat]
		var cell: Vector2i = _as_cell(unit.get("pos", Vector2i(-1, -1)))
		var placed := bool(unit.get("placed", true)) and cell.x >= 0 and cell.y >= 0
		pawn.visible = placed
		if not placed:
			continue
		pawn.apply_snapshot(unit, int(snap.get("active_seat", 0)))
		pawn.position = _cell_to_local(cell)
		pawn.z_index = VISUAL_SORT.unit_z_index(cell, _elev_at(cell))


func _paint_highlights() -> void:
	for tile in tiles.values():
		(tile as BoardTile).set_highlight("")
	var snap: Dictionary = _sim().snapshot()
	if snap.get("match_over", false) or _busy:
		return
	if CombatHUD.is_deployment_phase(snap):
		_paint_deploy_highlights(snap)
		return
	var legal: Array = _sim().legal_intents(CombatHUD.kit_seat(snap))
	var spell_id := _hud.selected_spell()
	var actor := _kit_unit(snap)
	if spell_id != "" and not CombatHUD.offered_cast_ids(actor, legal).has(spell_id):
		spell_id = ""
	# Enemy-targeted spells: paint the range ring as soon as the spell is selected.
	# Walk chrome stays off. Rolling casts also get Locked hit percent aim preview.
	if spell_id != "" and spell_id != SpellKits.ADVANCE:
		var def: Dictionary = SpellKits.spell(spell_id)
		if str(def.get("target", "")) == "enemy":
			for cell in _sim().range_highlight_cells(CombatHUD.kit_seat(snap), spell_id):
				_tile_at(cell).set_highlight("range")
	# Walk chrome follows sim-legal dests only. Do not invent weighted reachability here.
	# kind == "move" and spell_id == "" — walk highlights stay off while a spell is selected.
	for dest in SNAPSHOT_TILES.walk_dests(legal):
		if spell_id == "" and tiles.has(dest):
			_tile_at(dest).set_highlight("move")
	for intent in legal:
		var kind := str(intent.get("type", ""))
		if kind == "cast" and str(intent.get("spell", "")) == spell_id and intent.has("to"):
			var highlight := "advance" if spell_id == SpellKits.ADVANCE else "target"
			_tile_at(intent["to"]).set_highlight(highlight)
	_sync_aim_preview()


func _paint_deploy_highlights(snap: Dictionary) -> void:
	var ready: Dictionary = snap.get("ready", {})
	var legal0: Array[Vector2i] = _sim().legal_deploy_cells(0)
	var legal1: Array[Vector2i] = _sim().legal_deploy_cells(1)
	for cell in _sim().deploy_zone_cells(0):
		var kind := "locked" if bool(ready.get(0, false)) else "zone_p1"
		if not bool(ready.get(0, false)) and not legal0.has(cell):
			kind = "locked"
		_tile_at(cell).set_highlight(kind)
	for cell in _sim().deploy_zone_cells(1):
		var kind := "locked" if bool(ready.get(1, false)) else "zone_p2"
		if not bool(ready.get(1, false)) and not legal1.has(cell):
			kind = "locked"
		_tile_at(cell).set_highlight(kind)
	for unit in snap.get("units", []):
		if not bool(unit.get("placed", false)):
			continue
		var cell: Vector2i = _as_cell(unit.get("pos", Vector2i(-1, -1)))
		if tiles.has(cell):
			_tile_at(cell).set_highlight("occupied")


func _handle_deploy_click(cell: Vector2i) -> void:
	_hud.clear_deploy_note()
	var occupant := _placed_seat_at(cell)
	if occupant >= 0:
		var snap: Dictionary = _sim().snapshot()
		var ready: Dictionary = snap.get("ready", {})
		if not bool(ready.get(occupant, false)):
			if not _can_control_seat(occupant):
				_hud.set_deploy_note("That fighter belongs to the other seat.")
				return
			_deploy_selected_seat = occupant
			var unit := _unit_from_seat(snap, occupant)
			_hud.set_deploy_note("Selected %s. Click another zone tile on that side to reposition." % str(unit.get("name", "fighter")))
			_refresh()
			return
	var zones: Dictionary = _sim().snapshot().get("deploy_zones", {})
	var seat := CombatHUD.deploy_seat_for_cell(cell, _deploy_selected_seat, zones)
	if not _can_control_seat(seat):
		_hud.set_deploy_note("That deploy zone belongs to the other seat.")
		return
	var result: Dictionary
	_mark_local_net_echo()
	if _online() and _net().is_client():
		result = await _sim().place_unit_wait(seat, cell)
	elif _online():
		result = _sim().place_unit(seat, cell)
	else:
		result = CombatSim.place_unit(seat, cell)
	if result.get("ok", false):
		_deploy_selected_seat = -1
	_refresh()
	_maybe_enter_combat()


func _on_ready_requested(seat: int) -> void:
	if _busy:
		return
	_hud.clear_deploy_note()
	if not _can_control_seat(seat):
		return
	var result: Dictionary
	_mark_local_net_echo()
	if _online() and _net().is_client():
		result = await _sim().ready_seat_wait(seat)
	elif _online():
		result = _sim().ready_seat(seat)
	else:
		result = CombatSim.ready_seat(seat)
	if not result.get("ok", false):
		_refresh()
		return
	_refresh()
	_maybe_enter_combat()


func _maybe_enter_combat() -> void:
	if CombatHUD.is_deployment_phase(_sim().snapshot()):
		return
	_enter_combat_chrome()


func _enter_combat_chrome() -> void:
	_deploy_selected_seat = -1
	_hud.clear_deploy_note()
	_busy = true
	_hud.set_locked(true)
	_refresh()
	_hydrate_turn_clock()
	var snap: Dictionary = _sim().snapshot()
	var next_unit := _active_unit(snap)
	var status := CombatHUD.turn_status_text(snap)
	var caption := status if status != "" else "Turn 1"
	_hud.show_turn_banner(str(next_unit.get("name", "Kestrel")), str(next_unit.get("class_id", "")), caption)
	await get_tree().create_timer(HANDOFF_SEC).timeout
	if not is_inside_tree():
		return
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_busy = false
	_refresh()
	_hydrate_turn_clock()


func _placed_seat_at(cell: Vector2i) -> int:
	for unit in _sim().snapshot().get("units", []):
		if not bool(unit.get("placed", false)):
			continue
		if _as_cell(unit.get("pos", Vector2i(-1, -1))) == cell:
			return int(unit.get("seat", -1))
	return -1


func _unit_from_seat(snap: Dictionary, seat: int) -> Dictionary:
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == seat:
			return unit
	return {}


func _sync_aim_preview() -> void:
	if _hud == null:
		return
	var spell_id := _hud.selected_spell()
	if spell_id == "" or not SpellKits.rolls(spell_id):
		_hud.set_aim_preview({})
		return
	var snap: Dictionary = _sim().snapshot()
	_hud.set_aim_preview(_sim().aim_hit_preview(CombatHUD.kit_seat(snap), spell_id))


func _tile_at(cell: Vector2i) -> BoardTile:
	return tiles[cell] as BoardTile


func _active_unit(snap: Dictionary) -> Dictionary:
	return _unit_from_seat(snap, int(snap.get("active_seat", 0)))


func _kit_unit(snap: Dictionary) -> Dictionary:
	return _unit_from_seat(snap, CombatHUD.kit_seat(snap))


func _unit_from_event(snap: Dictionary, event: Dictionary) -> Dictionary:
	if event.has("seat"):
		for unit in snap.get("units", []):
			if int(unit.get("seat", -1)) == int(event["seat"]):
				return unit
	var named := str(event.get("name", event.get("unit_name", "")))
	if named != "":
		for unit in snap.get("units", []):
			if str(unit.get("name", "")) == named:
				return unit
	return {}


func _apply_board_tiles(snap: Dictionary) -> void:
	_board_data = SNAPSHOT_TILES.from_snapshot(snap, BOARD_SIZE)
	for cell in tiles.keys():
		var rec: Dictionary = _board_data.get(cell, SNAPSHOT_TILES.default_cell())
		var tile := _tile_at(cell)
		tile.apply_board_data(str(rec.get("terrain_type", "ground")), float(rec.get("elevation", 0.0)))
		tile.position = VISUAL_SORT.cell_to_local(cell, float(rec.get("elevation", 0.0)))
		tile.z_index = VISUAL_SORT.tile_z_index(cell, float(rec.get("elevation", 0.0)))


func _elev_at(cell: Vector2i) -> float:
	if _board_data.has(cell):
		return float(_board_data[cell].get("elevation", 0.0))
	return 0.0


func _cell_to_local(cell: Vector2i) -> Vector2:
	return VISUAL_SORT.cell_to_local(cell, _elev_at(cell))


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
