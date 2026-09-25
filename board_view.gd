extends Node2D

## Thin client: input + presentation only. CombatSim owns rolls and combat state.
## Walk: dest-click only. CombatSim expands the cheapest weighted ortho path; this
## view never sends intent.path. Pawns tween one ortho tile at a time along the
## returned walk path and face each hop (final facing = last hop, matching the snapshot).
## Live elevation chrome: tiles paint snapshot.tiles elevation + terrain_type.
## Walk highlights are CombatSim.legal_intents dests only (no client pathfinder).
## Z-sort is VIEW-only (BoardVisualSort). Hit bands / facing / spell LoS stay flat.
## Advance teleport does not auto-face.
## Advance highlights and click-accept read CombatSim.legal_intents only
## (cast_dests). No client Manhattan-2 or diagonal ring. A click off that set
## is forwarded so the sim's existing refund coach runs (hot-seat and NetSession).
## Locked deploy chrome: bind place_unit / ready_seat / legal_deploy_cells /
## deploy_zone_cells / can_ready / snapshot().phase. Hidden enemy stays Open.
## Advance: dest-click teleport snap. No hop playback; CombatSim ignores client path.
## After Advance, spell selection clears so walk chrome comes back from legal_intents.
## Walk is a dedicated action-bar mode (Walk button / Esc). Right-click still faces.
## Touch: finger press/drag previews aim hit %; release commits the cell (walk,
## Advance, cast). The Face pad is the tap path for facing. Hover stays desktop.
## Unit-targeted casts resolve a tap on the fighter sprite to that living cell.
## The 22px diamond pick stays for walks and empty tiles. A finger that starts
## on the ability cluster can drag onto the board and release to commit.
## Rolling enemy spells: selected chrome paints the Chebyshev range ring; walk chrome stays off.
## Aim preview shows Locked hit percent for rolling casts. Advance and walks have none.
## Proposed timers: ~1.0s client-only seat handoff banner. The 30s seat clock is
## host-owned (snapshot.turn_time_remaining). Guest hydrates; it does not tick.
## Walk hops lock input but do not pause the host clock.
## Locked Stun (A′): Walk / Face / spells grey on HUD; this view does not submit them.
## CombatSim auto-resolves end_turn when a stunned seat's turn starts.
## Client chrome: if CombatSim auto end_turns a stunned seat, show a skip banner.
## Occupied push dest toasts PushBlocked (no hop).
## OOB / truly blocked dest toasts Bounce plus one Impact gain (no hop).
## Lava forced-push lands from the snapshot and toasts Burn, not Bounce.
## Online: NetSession owns submit when a peer is up. Listen-host and the dedicated
## process share that authority. Clients send Intent only. Hot-seat still calls
## CombatSim.submit directly. The view never rolls.
## The dedicated process does not start the default Kestrel / Ironjaw pair.
## It paints when the SELECT_CLASS queue has paired two Locked classes.
## Snap Wall chrome paints snapshot.blocked_tiles and snap_wall events as blocked.
## View motions (idle, step arc, lunge, wind-up, recoil, lift, slump) tween the
## sprite only. Tunables live in ViewMotion. They never pause the host clock.
## One action locks input for at most ViewMotion.ACTION_LOCK_MAX.

const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")
const KOLISEO_ART := preload("res://board/koliseo_art.gd")
const PAWN_SCENE: PackedScene = preload("res://units/pawn.tscn")
const COMBAT_SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const VIEW_MOTION := preload("res://units/view_motion.gd")
const VFX_DIRECTOR := preload("res://vfx/vfx_director.gd")
const TOUCH := preload("res://ui/touch_adapter.gd")
const STEP_PAUSE_SEC: float = 0.08
const HANDOFF_SEC: float = 1.0
## Playable band between the top chrome and the touch-sized bottom bar.
const PLAY_TOP: float = TOUCH.PLAY_TOP
const PLAY_BOTTOM: float = TOUCH.PLAY_BOTTOM
const VIEW_W: float = TOUCH.VIEW_W
const VIEW_H: float = TOUCH.VIEW_H
const PAN_LIMIT := 220.0

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
var _flash_tweens: Array = []
var _view_locked: bool = false
var _pending_motion_sec: float = 0.0
var _resolve_hold_refresh: bool = false
var _queued_net: bool = false
var _queued_net_events: Array = []
var _vfx: Node
var _board_size: int = BoardSize.SHIP
var _camera: Camera2D
var _fit_camera_pos := Vector2.ZERO
var _panning := false
var _pan_origin := Vector2.ZERO
## Finger went down on the board. Release commits only that gesture.
var _touch_on_board := false
## Spell was armed on the cluster and the finger dragged onto the board.
var _chrome_aim := false
var _touch_commit_open := true


func _ready() -> void:
	_hud = $"../HUD" as CombatHUD
	_hud.set_preview_source(_sim())
	_hud.spell_selected.connect(_on_spell_selected)
	_hud.face_requested.connect(_on_face_requested)
	_hud.end_turn_requested.connect(_on_end_turn_button_pressed)
	_hud.new_match_requested.connect(_on_new_match)
	_hud.ready_requested.connect(_on_ready_requested)
	_hud.aim_dragged.connect(_on_hud_aim_dragged)
	# VFX pass 1. Motion pass owns pawn tweens. This node only plays pooled effects.
	_vfx = VFX_DIRECTOR.new()
	_vfx.name = "VfxDirector"
	add_child(_vfx)
	_vfx.bind_board(self)
	_ensure_camera()
	_rebuild_grid(BoardSize.SHIP)
	call_deferred("_boot")


func _boot() -> void:
	var net := _net()
	if net != null:
		if not net.state_changed.is_connected(_on_net_state):
			net.state_changed.connect(_on_net_state)
		if net.is_online() or net.is_connecting():
			# Listen-host starts the fixed Kestrel / Ironjaw duel.
			# The dedicated process waits until two Locked classes are paired.
			if net.is_authority() and not net.is_dedicated():
				net.reset_match({})
			if net.is_dedicated():
				if net.has_method("match_is_live") and bool(net.match_is_live()):
					_finish_boot()
				return
			if net.is_authority() or net.has_view_state():
				_finish_boot()
			return
	# Picker roster when both seats chose. Empty keeps the default pair.
	CombatSim.reset_match(ClassSelect.local_match_config())
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
	if _view_locked:
		_queued_net_events = events.duplicate()
		_queued_net = true
		return
	var swallowed := _present_resolve(events)
	if _pending_motion_sec > 0.0:
		await _await_view_motions()
	if _resolve_hold_refresh:
		_resolve_hold_refresh = false
		_refresh()
		_maybe_drain_net()
		return
	if swallowed:
		_maybe_drain_net()
		return
	if CombatHUD.should_play_walk_hops(events):
		var path_event := _path_event(events)
		if not path_event.is_empty():
			await _play_walk(int(path_event.get("seat", 0)), path_event["path"])
			_maybe_drain_net()
			return
	_refresh()
	_hydrate_turn_clock()
	if _has_turn_change(events) and not _busy:
		_present_turn_handoff({"events": events, "snapshot": _sim().snapshot()})
		return
	_maybe_drain_net()


func local_to_grid(point: Vector2) -> Vector2i:
	# Nearest painted tile so elevated (view-offset) cells stay clickable.
	return TOUCH.pick_board_cell(point, _tile_positions(), [], false)


func _process(delta: float) -> void:
	if not _booted:
		return
	var snap: Dictionary = _sim().snapshot()
	if CombatHUD.is_deployment_phase(snap) or bool(snap.get("match_over", false)):
		_hydrate_turn_clock(snap)
		return
	# Authority / hot-seat tick CombatSim. Clients never tick — remaining is snapshot-only.
	# Dedicated is the authority and is not a client, so this process ticks the host clock.
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
	if BoardTile.consume_debug_label_key(event):
		for tile in tiles.values():
			(tile as BoardTile).queue_redraw()
		return
	if _busy or _view_locked:
		return
	if event.is_action_pressed("ui_cancel"):
		# Esc returns to Walk. Right-click stays face and is not a cancel.
		_return_to_walk()
		return
	# Desktop MOUSE_BUTTON_RIGHT still faces. Touch uses the Face pad.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if TOUCH.board_gesture(event) != TOUCH.FACE:
			return
		var faced := _cell_under_pointer(event)
		if not _in_bounds(faced):
			return
		if CombatHUD.is_deployment_phase(_sim().snapshot()):
			return
		select_tile(faced)
		_face_toward(faced)
		get_viewport().set_input_as_handled()
		return
	var gesture := TOUCH.board_gesture(event)
	if gesture == TOUCH.PAN or gesture == TOUCH.PAN_STOP:
		var middle := event as InputEventMouseButton
		_panning = gesture == TOUCH.PAN
		if _panning:
			_pan_origin = middle.position
		get_viewport().set_input_as_handled()
		return
	if _panning and event is InputEventMouseMotion and not TOUCH.is_emulated_mouse(event) and _camera != null:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _pan_origin
		_pan_origin = motion.position
		_camera.position -= delta / _camera.zoom
		_clamp_camera()
		get_viewport().set_input_as_handled()
		return
	if _hud_claims_pointer(event):
		if TOUCH.is_touch_press(event):
			_touch_on_board = false
			_touch_commit_open = true
		return
	if gesture == TOUCH.AIM:
		var hover := _cell_under_pointer(event)
		if _in_bounds(hover):
			_sync_aim_preview(hover)
			if TOUCH.is_touch_press(event):
				_touch_on_board = true
				_chrome_aim = false
				_touch_commit_open = true
				select_tile(hover)
				if _hud != null:
					_hud.dismiss_pinned_tooltip()
			elif event is InputEventScreenDrag and (_touch_on_board or _spell_armed()):
				if not _touch_on_board:
					_chrome_aim = true
				select_tile(hover)
		else:
			_sync_aim_preview()
			if TOUCH.is_touch_press(event):
				_touch_on_board = false
		return
	if gesture != TOUCH.COMMIT:
		return
	if TOUCH.is_touch_release(event):
		var armed := _touch_on_board or _chrome_aim
		_touch_on_board = false
		_chrome_aim = false
		if not armed:
			return
	else:
		# Mouse left press is its own gesture. It must not inherit a touch lock.
		_touch_commit_open = true
	_commit_pointer(event)


func _spell_armed() -> bool:
	return _hud != null and _hud.selected_spell() != ""


func _hud_claims_pointer(event: InputEvent) -> bool:
	if _hud == null:
		return false
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return false
	return _hud.claims_screen_point(TOUCH.pointer_position(event))


func _on_hud_aim_dragged(screen_pos: Vector2, committing: bool) -> void:
	if _busy or _view_locked:
		return
	if not committing:
		# A new press or drag opens a commit. The release itself must not.
		_touch_commit_open = true
	if _hud != null and _hud.claims_screen_point(screen_pos):
		if committing:
			_chrome_aim = false
		return
	var local := ($Tiles as Node2D).make_canvas_position_local(screen_pos)
	var cell := _pick_local(local)
	if not _in_bounds(cell):
		if committing:
			_chrome_aim = false
		return
	_chrome_aim = true
	_sync_aim_preview(cell)
	select_tile(cell)
	if _hud != null:
		_hud.dismiss_pinned_tooltip()
	if not committing:
		return
	_chrome_aim = false
	_touch_on_board = false
	_commit_cell(cell)


func _commit_pointer(event: InputEvent) -> void:
	_commit_cell(_cell_under_pointer(event))


func _commit_cell(cell: Vector2i) -> void:
	if not _touch_commit_open:
		return
	if not _in_bounds(cell):
		return
	# Snap walls are not a left-click / tap target. Right-click already returned.
	if _snap_wall_cell(cell):
		return
	_touch_commit_open = false
	select_tile(cell)
	_handle_left_click(cell)


func _cell_under_pointer(event: InputEvent) -> Vector2i:
	var local: Vector2 = ($Tiles as Node2D).get_local_mouse_position()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		local = ($Tiles as Node2D).make_canvas_position_local(TOUCH.pointer_position(event))
	return _pick_local(local)


func _pick_local(local: Vector2) -> Vector2i:
	var prefer := _hud != null and TOUCH.spell_targets_unit(_hud.selected_spell())
	var pawns: Array = _living_pawns_for_pick() if prefer else []
	return TOUCH.pick_board_cell(local, _tile_positions(), pawns, prefer)


func _tile_positions() -> Dictionary:
	var positions := {}
	for cell in tiles.keys():
		positions[cell] = (tiles[cell] as BoardTile).position
	return positions


func _living_pawns_for_pick() -> Array:
	var out: Array = []
	for pawn in pawns_by_seat.values():
		if pawn == null or not is_instance_valid(pawn):
			continue
		var body: Pawn = pawn
		if not body.visible:
			continue
		var cell: Vector2i = body.grid_position
		out.append({
			"cell": cell,
			"origin": body.position,
			"sort": cell.x + cell.y,
		})
	return out


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
	if spell_id == SpellKits.ADVANCE and not _advance_click_accepted(cell, spell_id):
		# Not a highlighted dest. Still submit so CombatSim / NetSession reject
		# it with the existing refund coach (pawn stays, AP unchanged).
		_submit({"type": "cast", "spell": spell_id, "to": cell})
		_hud.clear_spell()
		_paint_highlights()
		return
	_submit({"type": "cast", "spell": spell_id, "to": cell})
	# After any dest-click cast (including Advance): drop spell chrome and
	# repaint walk tiles from legal_intents so remaining MP is selectable at 0 AP.
	_hud.clear_spell()
	_paint_highlights()


func _advance_click_accepted(cell: Vector2i, spell_id: String) -> bool:
	var legal: Array = _sim().legal_intents(CombatHUD.kit_seat(_sim().snapshot()))
	return SNAPSHOT_TILES.cast_dests(legal, spell_id).has(cell)


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
	if _busy or _view_locked:
		return
	_paint_highlights()
	_sync_aim_preview()


func _return_to_walk() -> void:
	if _hud == null:
		return
	_hud.select_walk()
	_paint_highlights()


func _on_face_requested(dir: String) -> void:
	if _busy or _view_locked:
		return
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
	if _busy or _view_locked:
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
		_maybe_drain_net()
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
	_maybe_drain_net()


func _has_turn_change(events: Array) -> bool:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) in ["turn_start", "end_turn"]:
			return true
	return false


func _on_new_match() -> void:
	_stop_flash_tweens()
	_stop_walk_tween()
	_settle_motions()
	_view_locked = false
	_pending_motion_sec = 0.0
	_queued_net = false
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_busy = false
	_clock_expired_pending = false
	_deploy_selected_seat = -1
	_hud.clear_spell()
	_hud.clear_deploy_note()
	if _online() and _net().is_client():
		if not _net().can_reset_match():
			return
		# Seat 0 asks the dedicated authority. The snapshot arrives on state_changed.
		_skip_local_net_echo = false
		_net().reset_match({})
		return
	if _online() and not _sim().can_reset_match():
		return
	_mark_local_net_echo()
	var config := {}
	if not _online():
		# Fresh arena every hot-seat rematch. Online reset stays Crosshaven.
		ClassSelect.roll_hotseat_map()
		config = ClassSelect.local_match_config()
	_sim().reset_match(config)
	_rebuild_pawns()
	_refresh()
	_hydrate_turn_clock()


func _submit(intent: Dictionary) -> void:
	if _busy or _view_locked:
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
		var swallowed := _present_resolve(events)
		if _pending_motion_sec > 0.0:
			await _await_view_motions()
		if _resolve_hold_refresh:
			_resolve_hold_refresh = false
			_refresh()
			_maybe_drain_net()
			return
		if swallowed:
			_maybe_drain_net()
			return
		if CombatHUD.should_play_walk_hops(events):
			var path_event := _path_event(events)
			await _play_walk(int(path_event.get("seat", 0)), path_event["path"])
			_maybe_drain_net()
			return
	_refresh()
	_maybe_drain_net()


## Hot-seat and NetSession both call this. Toasts come from sim events; Burn icons come from the snapshot on refresh.
## Returns true when the pawn must not hop (occupied block or bounce).
func _present_resolve(events: Array) -> bool:
	_play_combat_feedback(events)
	_arm_view_motions(events)
	_arm_vfx(events)
	var swallowed := false
	if CombatHUD.events_include_push_blocked(events):
		# Occupied dest is a hard body-block. Snapshot already stayed put.
		_hud.show_toast(CombatHUD.PUSH_BLOCKED_TOAST)
		swallowed = true
	elif CombatHUD.events_include_push_bounce(events):
		# Bounce: unit stayed. The toast is Bounce plus the single sim Impact gain.
		var bounce_toast := CombatHUD.toast_for_events(events)
		if not bounce_toast.begins_with(CombatHUD.BOUNCE_TOAST):
			bounce_toast = CombatHUD.BOUNCE_TOAST
		_hud.show_toast(bounce_toast)
		swallowed = true
	else:
		var toast := CombatHUD.toast_for_events(events)
		if toast != "":
			_hud.show_toast(toast)
	# Motion plays on the sprite first. Refresh (and the grey dead modulate) follows.
	if swallowed and _pending_motion_sec <= 0.0:
		_refresh()
	_resolve_hold_refresh = swallowed and _pending_motion_sec > 0.0
	return swallowed


func _path_event(events: Array) -> Dictionary:
	for event in events:
		# Walk hops only. Advance is a teleport snap — do not play cell-by-cell path.
		# PushBlocked and bounce also never hop.
		if str(event.get("type", "")) == "move":
			return event
	return {}


func _play_combat_feedback(events: Array) -> void:
	# Hit flash on the target and Impact flash on the caster. Plays even when push is blocked.
	# Heal / Cleanse use a green-teal flash. Ward uses pale blue. Real damage stays orange.
	# Kind comes from the event spell id, healed amount, negative damage, or shield fields.
	# A dying pawn keeps the flash color for the slump; the grey state is applied after.
	var dying := _dying_seats(events)
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "hit":
			continue
		var target_seat := int(event.get("target_seat", -1))
		if pawns_by_seat.has(target_seat):
			var target_pawn: Pawn = pawns_by_seat[target_seat]
			match Pawn.resolve_flash_kind(event):
				"ward":
					target_pawn.flash_ward()
				"support":
					target_pawn.flash_support()
				_:
					target_pawn.flash_hit()
			if not dying.has(target_seat):
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
	var canvas := pawn.flash_canvas()
	var rest := pawn.rest_modulate()
	var tween := create_tween()
	_flash_tweens.append(tween)
	var seat := int(pawn.seat)
	tween.tween_property(canvas, "modulate", rest, 0.28)
	tween.finished.connect(_on_flash_settled.bind(seat), CONNECT_ONE_SHOT)


func _on_flash_settled(seat: int) -> void:
	if not pawns_by_seat.has(seat):
		return
	var pawn: Pawn = pawns_by_seat[seat]
	if pawn != null and is_instance_valid(pawn):
		pawn.note_flash_settled()


func _stop_flash_tweens() -> void:
	for tween in _flash_tweens:
		if tween != null and is_instance_valid(tween):
			tween.kill()
	_flash_tweens.clear()


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
	# The step arc is sprite-local and lasts Pawn.WALK_HOP_SEC, same as the tile slide.
	pawn.hold_idle()
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
		pawn.play_step_hop()
		_walk_tween = create_tween()
		_walk_tween.set_parallel(true)
		_walk_tween.set_trans(Tween.TRANS_LINEAR)
		_walk_tween.set_ease(Tween.EASE_IN_OUT)
		_walk_tween.tween_property(pawn, "position", _cell_to_local(cell), Pawn.WALK_HOP_SEC)
		_walk_tween.tween_method(_track_step_sort.bind(pawn, prev, cell), 0.0, 1.0, Pawn.WALK_HOP_SEC)
		await _walk_tween.finished
		pawn.position = _cell_to_local(cell)
		pawn.finish_step()
		_set_pawn_cell(pawn, cell)
		prev = cell
		if STEP_PAUSE_SEC > 0.0:
			await get_tree().create_timer(STEP_PAUSE_SEC).timeout
	if pawn != null and is_instance_valid(pawn):
		pawn.release_idle()


func _set_pawn_cell(pawn: Pawn, cell: Vector2i) -> void:
	pawn.grid_position = cell
	pawn.z_index = VISUAL_SORT.unit_z_index(cell, _elev_at(cell))


func _stop_walk_tween() -> void:
	if _walk_tween != null and is_instance_valid(_walk_tween):
		_walk_tween.kill()
	_walk_tween = null


func _track_step_sort(t: float, pawn: Pawn, src: Vector2i, dst: Vector2i) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var src_at := _cell_to_local(src)
	var dst_at := _cell_to_local(dst)
	var toward_dst := pawn.position.distance_squared_to(dst_at) <= pawn.position.distance_squared_to(src_at)
	if t <= 0.001:
		toward_dst = false
	var cell := dst if toward_dst else src
	pawn.z_index = VISUAL_SORT.unit_z_index(cell, _elev_at(cell))


func _dying_seats(events: Array) -> Dictionary:
	var dying := {}
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "dead":
			dying[int(event.get("seat", -1))] = true
	return dying


func _arm_vfx(events: Array) -> void:
	# Shares the motion input lock. Displacement beats only. Clock keeps running.
	if _vfx == null or not _vfx.has_method("play"):
		return
	var block := float(_vfx.play(events, _sim().snapshot()))
	_pending_motion_sec = maxf(_pending_motion_sec, minf(block, VIEW_MOTION.ACTION_LOCK_MAX))


func _arm_view_motions(events: Array) -> void:
	_pending_motion_sec = 0.0
	if VIEW_MOTION.reduce_motion():
		return
	var plans := {}
	var caster_armed := false
	var dying := _dying_seats(events)
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var typ := str(event.get("type", ""))
		var spell_id := str(event.get("spell", ""))
		if not caster_armed and spell_id != "" and typ in ["cast", "miss", "hit", "snap_wall"]:
			caster_armed = true
			var seat := int(event.get("seat", -1))
			var kind := str(VIEW_MOTION.caster_motion(spell_id))
			if kind != "" and pawns_by_seat.has(seat):
				var plan: Dictionary = plans.get(seat, {})
				if kind == "attack":
					plan["attack"] = true
					plan["aim"] = _aim_vector(seat, event)
				elif not bool(plan.get("attack", false)):
					plan["cast"] = true
				plans[seat] = plan
		if typ != "hit":
			continue
		var target := int(event.get("target_seat", -1))
		if not pawns_by_seat.has(target):
			continue
		var react := str(VIEW_MOTION.target_motion(Pawn.resolve_flash_kind(event)))
		if react == "":
			continue
		var plan: Dictionary = plans.get(target, {})
		if react == "hit":
			plan["hit"] = true
			plan["away"] = _away_vector(target, event)
			plan["delay"] = true
		elif react == "lift":
			plan["lift"] = true
			plan["delay"] = true
		plans[target] = plan
	for seat in dying.keys():
		if not pawns_by_seat.has(int(seat)):
			continue
		var plan: Dictionary = plans.get(seat, {})
		plan["death"] = true
		plan["tilt"] = -1.0 if int(seat) % 2 == 0 else 1.0
		plans[seat] = plan
	var longest := 0.0
	for seat in plans.keys():
		var pawn: Pawn = pawns_by_seat[seat]
		if pawn == null or not is_instance_valid(pawn):
			continue
		longest = maxf(longest, pawn.play_view_plan(plans[seat]))
	_pending_motion_sec = minf(longest, VIEW_MOTION.ACTION_LOCK_MAX)


func _aim_vector(seat: int, event: Dictionary) -> Vector2:
	var pawn: Pawn = pawns_by_seat[seat]
	if event.has("to"):
		var delta := _cell_to_local(_as_cell(event.get("to"))) - pawn.position
		if delta.length() > 2.0:
			return delta
	var target := int(event.get("target_seat", -1))
	if pawns_by_seat.has(target) and target != seat:
		var other: Pawn = pawns_by_seat[target]
		var gap: Vector2 = other.position - pawn.position
		if gap.length() > 2.0:
			return gap
	return pawn.facing_screen()


func _away_vector(target_seat: int, event: Dictionary) -> Vector2:
	var caster := int(event.get("seat", -1))
	if not pawns_by_seat.has(caster) or not pawns_by_seat.has(target_seat) or caster == target_seat:
		return Vector2.ZERO
	var actor: Pawn = pawns_by_seat[caster]
	var victim: Pawn = pawns_by_seat[target_seat]
	return victim.position - actor.position


func _await_view_motions() -> void:
	_view_locked = true
	if _hud != null:
		_hud.set_locked(true)
	var started := Time.get_ticks_msec()
	var budget_ms := int(VIEW_MOTION.ACTION_LOCK_MAX * 1000.0)
	while Time.get_ticks_msec() - started < budget_ms:
		if not _motions_active():
			break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if Time.get_ticks_msec() == started:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_settle_motions()
	_pending_motion_sec = 0.0
	_view_locked = false
	if _hud != null and not _busy:
		_hud.set_locked(false)


func _motions_active() -> bool:
	if _vfx != null and _vfx.has_method("is_blocking") and bool(_vfx.is_blocking()):
		return true
	for pawn in pawns_by_seat.values():
		if pawn != null and is_instance_valid(pawn) and (pawn as Pawn).motion_playing():
			return true
	return false


func _settle_motions() -> void:
	for pawn in pawns_by_seat.values():
		if pawn != null and is_instance_valid(pawn):
			(pawn as Pawn).settle_motion()


func _maybe_drain_net() -> void:
	if not _queued_net or _busy or _view_locked or not is_inside_tree():
		return
	var events: Array = _queued_net_events
	_queued_net = false
	_queued_net_events = []
	_on_net_state(events, {})


func _refresh() -> void:
	var snap: Dictionary = _sim().snapshot()
	var legal: Array = _sim().legal_intents(CombatHUD.kit_seat(snap))
	_apply_board_tiles(snap)
	_apply_units(snap)
	_hud.render(snap, legal)
	_paint_highlights()
	_hydrate_turn_clock(snap)
	if _vfx != null and _vfx.has_method("sync_snapshot"):
		_vfx.sync_snapshot(snap)


func _rebuild_pawns() -> void:
	_stop_flash_tweens()
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
		var raw_pos: Variant = unit.get("pos", Vector2i(-1, -1))
		var cell: Vector2i = _as_cell(raw_pos)
		# pos null / pos_hidden: opponent wire for an Invisible unit. Do not draw it.
		var placed := bool(unit.get("placed", true)) and not bool(unit.get("pos_hidden", false)) and raw_pos != null and cell.x >= 0 and cell.y >= 0
		pawn.visible = placed
		if not placed:
			continue
		var raw_events: Variant = snap.get("last_events", [])
		var burn_events: Array = raw_events if typeof(raw_events) == TYPE_ARRAY else []
		pawn.apply_snapshot(unit, int(snap.get("active_seat", 0)), burn_events)
		pawn.position = _cell_to_local(cell)
		pawn.z_index = VISUAL_SORT.unit_z_index(cell, _elev_at(cell))


func _paint_highlights() -> void:
	for tile in tiles.values():
		(tile as BoardTile).set_highlight("")
	var snap: Dictionary = _sim().snapshot()
	if snap.get("match_over", false) or _busy:
		_paint_blocked(snap)
		return
	if CombatHUD.is_deployment_phase(snap):
		_paint_deploy_highlights(snap)
		_paint_blocked(snap)
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
	# Advance and other cast dest chrome: legal_intents only. No client range ring.
	for dest in SNAPSHOT_TILES.cast_dests(legal, spell_id):
		if tiles.has(dest):
			var highlight := "advance" if spell_id == SpellKits.ADVANCE else "target"
			_tile_at(dest).set_highlight(highlight)
	_paint_blocked(snap)
	_sync_aim_preview()


func _paint_blocked(snap: Dictionary) -> void:
	for cell in SNAPSHOT_TILES.blocked_cells(snap):
		if tiles.has(cell):
			_tile_at(cell).set_highlight("blocked")


func _snap_wall_cell(cell: Vector2i) -> bool:
	return SNAPSHOT_TILES.blocked_cells(_sim().snapshot()).has(cell)


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


func _sync_aim_preview(dest: Variant = null) -> void:
	if _hud == null:
		return
	var spell_id := _hud.selected_spell()
	if spell_id == "" or not SpellKits.rolls(spell_id):
		_hud.set_aim_preview({})
		return
	var snap: Dictionary = _sim().snapshot()
	_hud.set_aim_preview(_sim().aim_hit_preview(CombatHUD.kit_seat(snap), spell_id, dest))


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
	var size := int(snap.get("board_size", _board_size))
	if size != _board_size or tiles.size() != size * size:
		_rebuild_grid(size)
	_board_data = SNAPSHOT_TILES.from_snapshot(snap, _board_size)
	var paint: Dictionary = snap.get("paint_only", {})
	var dress := str(KOLISEO_ART.dress_for(str(snap.get("map_id", snap.get("demo_map", "")))))
	for cell in tiles.keys():
		var rec: Dictionary = _board_data.get(cell, SNAPSHOT_TILES.default_cell())
		var tile := _tile_at(cell)
		tile.set_dress(dress)
		tile.apply_board_data(str(rec.get("terrain_type", "ground")), float(rec.get("elevation", 0.0)))
		tile.set_paint_props(_paint_props_at(paint, cell))
		tile.position = VISUAL_SORT.cell_to_local(cell, float(rec.get("elevation", 0.0)))
		tile.z_index = VISUAL_SORT.tile_z_index(cell, float(rec.get("elevation", 0.0)))


func _paint_props_at(paint: Dictionary, cell: Vector2i) -> Array:
	if paint.has(cell) and paint[cell] is Array:
		return paint[cell]
	var key := "%d,%d" % [cell.x, cell.y]
	if paint.has(key) and paint[key] is Array:
		return paint[key]
	return []


func _elev_at(cell: Vector2i) -> float:
	if _board_data.has(cell):
		return float(_board_data[cell].get("elevation", 0.0))
	return 0.0


func _cell_to_local(cell: Vector2i) -> Vector2:
	return VISUAL_SORT.cell_to_local(cell, _elev_at(cell))


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _board_size and cell.y < _board_size


func _ensure_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return
	_camera = Camera2D.new()
	_camera.name = "BoardCamera"
	add_child(_camera)
	_camera.make_current()


func _rebuild_grid(size: int) -> void:
	var next := size if size > 0 else BoardSize.SHIP
	if next == _board_size and tiles.size() == next * next and not tiles.is_empty():
		return
	_board_size = next
	for child in $Tiles.get_children():
		$Tiles.remove_child(child)
		child.free()
	tiles.clear()
	selected_tile = null
	for y in range(next):
		for x in range(next):
			var tile := TILE_SCENE.instantiate() as BoardTile
			tile.grid_position = Vector2i(x, y)
			tile.apply_board_data("ground", 0.0)
			tile.position = VISUAL_SORT.cell_to_local(tile.grid_position, 0.0)
			tile.z_index = VISUAL_SORT.tile_z_index(tile.grid_position, 0.0)
			$Tiles.add_child(tile)
			tiles[tile.grid_position] = tile
	_fit_board_camera()


## Zoom the 15×15 diamond into the 960×720 play band. Cell size stays 64×32.
## Middle-mouse pan is clamped around that fit.
func _fit_board_camera() -> void:
	_ensure_camera()
	var n := _board_size
	if n < 1:
		return
	var half_w := 32.0
	var half_h := 16.0
	var lift := 20.0
	var min_x := float(0 - (n - 1)) * 32.0 - half_w
	var max_x := float(n - 1) * 32.0 + half_w
	var min_y := -half_h - lift
	var max_y := float((n - 1) + (n - 1)) * 16.0 + half_h
	var board_w := maxf(max_x - min_x, 1.0)
	var board_h := maxf(max_y - min_y, 1.0)
	var play_w := VIEW_W - 32.0
	var play_h := PLAY_BOTTOM - PLAY_TOP
	var zoom := minf(play_w / board_w, play_h / board_h)
	zoom = clampf(zoom, 0.35, 1.25)
	_camera.zoom = Vector2(zoom, zoom)
	var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var play_center := Vector2(VIEW_W * 0.5, (PLAY_TOP + PLAY_BOTTOM) * 0.5)
	var view_center := Vector2(VIEW_W * 0.5, VIEW_H * 0.5)
	var world_center := global_position + center
	var camera_world := world_center - (play_center - view_center) / zoom
	_fit_camera_pos = camera_world - global_position
	_camera.position = _fit_camera_pos


func _clamp_camera() -> void:
	if _camera == null:
		return
	var delta := _camera.position - _fit_camera_pos
	delta.x = clampf(delta.x, -PAN_LIMIT, PAN_LIMIT)
	delta.y = clampf(delta.y, -PAN_LIMIT, PAN_LIMIT)
	_camera.position = _fit_camera_pos + delta


func _as_cell(value: Variant) -> Vector2i:
	if value == null:
		return Vector2i(-1, -1)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
