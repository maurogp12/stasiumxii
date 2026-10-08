extends Node2D

## Thin client: input + presentation only. CombatSim owns rolls and combat state.
## Walk: dest-click only. CombatSim expands the cheapest weighted ortho path; this
## view never sends intent.path. Pawns tween one ortho tile at a time along the
## returned walk path and face each hop before the translate (final facing snaps
## after the land, matching the snapshot's last hop).
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
## Mouse diamond pick stays 22px. A finger uses the painted diamond and a fatter
## sprite capsule. A phone shows most of the Koliseo diamond at a modest
## zoom, with the HUD over the edges. A walk-mode drag pans.
## A finger that starts on the ability cluster can drag onto the board and release to commit.
## Rolling enemy spells: selected chrome paints the Chebyshev range ring; walk chrome stays off.
## Aim preview shows Locked hit percent for rolling casts. Advance and walks have none.
## A dashed aim line and a predicted float follow the hover. Ambush draws that
## line from the Shade (Gloam only while Invisible) and only while the cast is legal.
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
## View motions (idle, step bounce, lunge, wind-up, recoil, lift, slump) tween the
## sprite only. Tunables live in ViewMotion. They never pause the host clock.
## One action locks input for at most ViewMotion.ACTION_LOCK_MAX.
## Mobile-track chrome. A walk plants the foot, then strides to the next cell
## in about 0.30s. The sprite root takes the hop and the plant squash. A 180
## turns while planted. Straight tiles do not settle. Advance stays a snap.
## Phone framing shows most of the diamond. Desktop fit stays.

const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")
const KOLISEO_ART := preload("res://board/koliseo_art.gd")
const COMBAT_RESULT := preload("res://ui/combat_result.gd")
## Death / finisher reads before the end-of-fight window opens.
const RESULT_DELAY := 1.1
## How long an online result stays up before both phones go back to the hub.
const RESULT_READ_SEC := 4.0
const KOLISEO_LIFE := preload("res://board/koliseo_life.gd")
const ARENA_SKY := preload("res://board/arena_sky.gd")
const ARENA_LOOK := preload("res://board/arena_look.gd")
const PAINTED := preload("res://board/painted_room.gd")
const SPELL_FLOURISH := preload("res://vfx/spell_flourish.gd")
const PAWN_SCENE: PackedScene = preload("res://units/pawn.tscn")
const COMBAT_SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const VIEW_MOTION := preload("res://units/view_motion.gd")
const VFX_DIRECTOR := preload("res://vfx/vfx_director.gd")
const SHADE_MARKER := preload("res://board/shade_marker.gd")
const AIM_LINE := preload("res://board/aim_line.gd")
const _TestLoadoutRef := preload("res://backend/test_loadout.gd")
## Marker z is this plus the cell, above every tile and pawn, under combat
## numbers (z 900) so the "Shade" floater still reads.
const SHADE_LAYER_Z := 640
const TOUCH := preload("res://ui/touch_adapter.gd")
const HANDOFF_SEC: float = 1.0
## Playable band between the top chrome and the touch-sized bottom bar.
const PLAY_TOP: float = TOUCH.PLAY_TOP
const PLAY_BOTTOM: float = TOUCH.PLAY_BOTTOM
const VIEW_W: float = TOUCH.VIEW_W
const VIEW_H: float = TOUCH.VIEW_H
const PAN_LIMIT := 220.0

var _fight_started_msec: int = 0
var _result_shown: bool = false
var _online_home_pending: bool = false
var _result_layer: CanvasLayer
var tiles: Dictionary = {}
var selected_tile: BoardTile = null
var pawns_by_seat: Dictionary = {}
var _hud: CombatHUD
var _booted: bool = false
var _busy: bool = false
var _clock_expired_pending: bool = false
var _walk_tween: Tween
## Seat whose body is mid hop. Refresh must not snap it to the destination.
var _hop_seat: int = -1
var _shade_markers: Dictionary = {}
var _aim_line: Node2D
## Last hovered cell while a spell is armed. Ambush ignores it and aims from the Shade.
var _aim_hover: Variant = null
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
var _koliseo_life: Node2D
var _arena_sky: Node2D
var _shake_tween: Tween
var _flourish: Node2D
## Pinch zoom (phone): finger index -> screen position, and the pinch start.
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _pinch_zoom := 0.0
var _board_px := Vector2(960, 500)
var _fit_camera_pos := Vector2.ZERO
var _pan_limit := Vector2(PAN_LIMIT, PAN_LIMIT)
## Screen-space pan accumulated during input. Applied once per frame so a
## gesture does not move the camera on every motion event.
var _pan_pending := Vector2.ZERO
## Turn focus glide (Mauro 4 Oct 2026: "the map focus whoever turn it is").
const FOCUS_GLIDE_SEC := 0.45
var _focus_tween: Tween
var _framed_cell := Vector2i(-999, -999)
var _panning := false
var _touch_panning := false
var _touch_down := Vector2.ZERO
var _pan_origin := Vector2.ZERO
## Finger went down on the board. Release commits only that gesture.
var _touch_on_board := false
## Spell was armed on the cluster and the finger dragged onto the board.
var _chrome_aim := false
var _touch_commit_open := true
## Bumps when a new Ambush arrival starts so a stale snap cannot fire late.
var _ambush_arrival_token := 0
var _ambush_arrival_tween: Tween
## Back-tile pose held until the slash. A refresh during that hold must not
## walk the body back to the cast cell or paint the post-hit vitals early.
var _ambush_hold_seat := -1
var _ambush_hold_cell := Vector2i(-1, -1)
var _ambush_hold_facing := ""
var _ambush_hold_pos := Vector2.ZERO
var _ambush_hold_event: Dictionary = {}
## Seat whose arrival is open. A second presenter must not restart it or slash.
var _ambush_open_seat := -1
var _ambush_contact_armed := false


func _ready() -> void:
	TOUCH.lock_landscape_frame(get_window())
	_hud = $"../HUD" as CombatHUD
	_hud.set_preview_source(_sim())
	_hud.spell_selected.connect(_on_spell_selected)
	_hud.face_requested.connect(_on_face_requested)
	_hud.end_turn_requested.connect(_on_end_turn_button_pressed)
	_hud.new_match_requested.connect(_on_new_match)
	_hud.hub_requested.connect(_on_hub_requested)
	_hud.unit_card_tapped.connect(_on_unit_card_tapped)
	_hud.elements_requested.connect(_on_elements_requested)
	_hud.ready_requested.connect(_on_ready_requested)
	_hud.aim_dragged.connect(_on_hud_aim_dragged)
	_hud.zoom_step_requested.connect(_on_zoom_step)
	# VFX pass 1. Motion pass owns pawn tweens. This node only plays pooled effects.
	_vfx = VFX_DIRECTOR.new()
	_vfx.name = "VfxDirector"
	add_child(_vfx)
	_vfx.bind_board(self)
	_shade_layer()
	_ensure_aim_line()
	_ensure_camera()
	_rebuild_grid(BoardSize.SHIP)
	if not get_viewport().size_changed.is_connected(_fit_board_camera):
		get_viewport().size_changed.connect(_fit_board_camera)
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


## Who is looking at the board. Online: the seat this device owns. Hot-seat:
## the player whose turn it is (one phone passed between two players).
func _viewer_sees_seat(seat: int, snap: Dictionary) -> bool:
	if int(snap.get("team_size", 1)) > 1:
		# Teams: a hidden fighter is visible to its own team only.
		var team := _snap_team(snap, seat)
		if _online():
			for unit in snap.get("units", []):
				if _snap_team(snap, int(unit["seat"])) == team and _can_control_seat(int(unit["seat"])):
					return true
			return false
		return team == _snap_team(snap, int(snap.get("active_seat", -1)))
	if _online():
		return _can_control_seat(seat)
	return seat == int(snap.get("active_seat", -1))


func _snap_team(snap: Dictionary, seat: int) -> int:
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == seat:
			return int(unit.get("team", 0 if seat == 0 else 1))
	return seat % 2


## Teams deploy: a tap on a team's zone places the selected fighter of that
## team, else its next unplaced fighter. -1 when the whole team is placed.
func _team_deploy_seat(snap: Dictionary, side: int) -> int:
	if _deploy_selected_seat >= 0 and _snap_team(snap, _deploy_selected_seat) == side:
		return _deploy_selected_seat
	for unit in snap.get("units", []):
		if _snap_team(snap, int(unit["seat"])) == side and not bool(unit.get("placed", false)):
			return int(unit["seat"])
	return -1


## Scenes where the computer plays a seat skip the big turn banner for it.
const QUIET_HANDOFF_SEC := 0.25


func _quiet_handoff(_seat: int) -> bool:
	return false


## Scenes where the computer plays a seat override this (walk chrome off).
func _shows_turn_chrome(_seat: int) -> bool:
	return true


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
		# The local slash can finish after the blink. Plant the back tile again.
		_snap_ambush_teleports(events)
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
			await _play_walk(int(path_event.get("seat", 0)), path_event["path"], _as_cell(path_event.get("from", Vector2i(-1, -1))))
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
	_apply_pending_pan()
	_pulse_target_marks(delta)
	_space_name_plates()
	var snap: Dictionary = _sim().snapshot()
	if CombatHUD.is_deployment_phase(snap) or bool(snap.get("match_over", false)):
		_hydrate_turn_clock(snap)
		# A net update dropped while _busy still has to open the result.
		# _refresh is the other caller; this covers the early return above.
		if bool(snap.get("match_over", false)):
			_track_result(snap)
		return
	# Hot-seat and a listen-host tick here. A phone only shows the server clock.
	# The headless authority ticks in NetSession (it never loads this board);
	# skip here too so the two never both run. Keep ticking during walk hops.
	var result: Dictionary = {}
	var net := _net()
	var server_clock := false
	if _online() and net != null:
		server_clock = bool(net.is_client()) or bool(net.is_dedicated())
	if not server_clock:
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


## Two-finger pinch zooms the board camera on a phone (continuous, inside the
## player zoom limits). While two fingers are down no cell is aimed or committed.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		if _touches.size() == 2:
			_pinch_dist = _touch_spread()
			_pinch_zoom = _camera.zoom.x if _camera != null else 1.0
			_cancel_touch_aim()
			get_viewport().set_input_as_handled()
		elif _touches.size() < 2 and _pinch_dist > 0.0:
			_pinch_dist = 0.0
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.has(d.index):
			_touches[d.index] = d.position
		if _touches.size() >= 2 and _pinch_dist > 0.0 and _camera != null:
			var ratio := _touch_spread() / maxf(_pinch_dist, 1.0)
			var view := get_viewport_rect().size
			TOUCH.set_player_zoom(_pinch_zoom * ratio, _board_px.x, _board_px.y, view)
			var z := TOUCH.player_board_zoom(_board_px.x, _board_px.y, view, true)
			_camera.zoom = Vector2(z, z)
			_pan_limit = TOUCH.pan_room(_board_px.x, _board_px.y, view, z, true)
			_clamp_camera()
			get_viewport().set_input_as_handled()


func _touch_spread() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _cancel_touch_aim() -> void:
	_touch_on_board = false
	_touch_commit_open = false
	_touch_panning = true
	_chrome_aim = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var wheel := event as InputEventMouseButton
		if wheel.pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_apply_wheel_zoom(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
			return
	if BoardTile.consume_debug_label_key(event):
		for tile in tiles.values():
			(tile as BoardTile).queue_redraw()
		return
	# Android Back is ui_cancel. After the fight it must leave for the hub
	# even while a result tween still has the board marked busy.
	if event.is_action_pressed("ui_cancel"):
		var cancel_net := _net()
		if cancel_net != null and cancel_net.is_client() and bool(_sim().snapshot().get("match_over", false)):
			if cancel_net.has_method("return_to_hub_now"):
				cancel_net.return_to_hub_now()
			get_viewport().set_input_as_handled()
			return
	if _busy or _view_locked:
		# Watching an AI or monster turn: a finger can still drag the map.
		_pan_while_watching(event)
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
		_queue_pan(delta)
		get_viewport().set_input_as_handled()
		return
	if _hud_claims_pointer(event):
		if TOUCH.is_touch_press(event):
			_touch_on_board = false
			_touch_commit_open = true
		return
	if gesture == TOUCH.AIM:
		if TOUCH.is_touch_press(event):
			_touch_down = TOUCH.pointer_position(event)
			_touch_panning = false
		elif event is InputEventScreenDrag and _pan_board_drag(event):
			return
		var hover := _cell_under_pointer(event)
		if _in_bounds(hover):
			_aim_hover = hover
			_sync_aim_preview(hover)
			if TOUCH.is_touch_press(event):
				_touch_on_board = true
				_chrome_aim = false
				_touch_commit_open = true
				if _cast_cell_armable(hover):
					select_tile(hover)
				if _hud != null:
					_hud.dismiss_pinned_tooltip()
			elif event is InputEventScreenDrag and (_touch_on_board or _spell_armed()):
				if not _touch_on_board:
					_chrome_aim = true
				if _cast_cell_armable(hover):
					select_tile(hover)
		else:
			_aim_hover = null
			_sync_aim_preview()
			if TOUCH.is_touch_press(event):
				_touch_on_board = false
		return
	if gesture != TOUCH.COMMIT:
		return
	if TOUCH.is_touch_release(event):
		var armed := _touch_on_board or _chrome_aim
		var panned := _touch_panning
		_touch_on_board = false
		_chrome_aim = false
		_touch_panning = false
		if panned or not armed:
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
	var cell := _pick_local(local, true)
	if not _in_bounds(cell):
		if committing:
			_chrome_aim = false
		return
	_chrome_aim = true
	_aim_hover = cell
	_sync_aim_preview(cell)
	if _cast_cell_armable(cell):
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
	# Snap walls are not a left-click / tap target, except Snap Wall on the
	# caster's own wall (knock it down, Mauro 6 Oct 2026). Right-click already returned.
	if _snap_wall_cell(cell) and not _snap_wall_break_cell(cell):
		return
	if not _cast_cell_armable(cell):
		return
	_touch_commit_open = false
	select_tile(cell)
	_handle_left_click(cell)


func _cell_under_pointer(event: InputEvent) -> Vector2i:
	var local: Vector2 = ($Tiles as Node2D).get_local_mouse_position()
	var finger := false
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		local = ($Tiles as Node2D).make_canvas_position_local(TOUCH.pointer_position(event))
		finger = true
	return _pick_local(local, finger)


func _pick_local(local: Vector2, mobile: bool = false) -> Vector2i:
	var spell := ""
	if _hud != null:
		spell = _hud.selected_spell()
	var prefer := TOUCH.spell_targets_unit(spell)
	var pawns: Array = _living_pawns_for_pick(spell) if prefer else []
	var cell := TOUCH.pick_board_cell(local, _tile_positions(), pawns, prefer, mobile or TOUCH.use_mobile_pick())
	return _soft_lock_cell(cell, spell, prefer)


## Hot-seat CombatSim snaps the empty neighbor onto the one legal enemy so the
## aim ring and the commit use that body. A net session resolves the same snap
## on submit; this window does not invent a second rule.
func _soft_lock_cell(cell: Vector2i, spell: String, prefer: bool) -> Vector2i:
	if not prefer or not _in_bounds(cell):
		return cell
	var sim := _sim()
	if sim == null or not sim.has_method("soft_lock_dest"):
		return cell
	return sim.soft_lock_dest(CombatHUD.kit_seat(sim.snapshot()), spell, cell)


func _tile_positions() -> Dictionary:
	var positions := {}
	for cell in tiles.keys():
		positions[cell] = (tiles[cell] as BoardTile).position
	return positions


## An enemy-only spell never picks the caster's own body: the drawing stands
## over the tiles behind it, and a tap there (a blind "punch in the air", or a
## foe standing behind) used to select the caster instead.
func _living_pawns_for_pick(spell: String = "") -> Array:
	var out: Array = []
	var skip_seat := -99
	if spell != "" and str(SpellKits.spell(spell).get("target", "")) == "enemy":
		var sim := _sim()
		if sim != null:
			skip_seat = CombatHUD.kit_seat(sim.snapshot())
	for seat in pawns_by_seat.keys():
		var pawn = pawns_by_seat[seat]
		if pawn == null or not is_instance_valid(pawn):
			continue
		if int(seat) == skip_seat:
			continue
		var body: Pawn = pawn
		if not body.visible:
			continue
		var cell: Vector2i = body.grid_position
		var entry := {
			"cell": cell,
			"origin": body.position,
			"sort": cell.x + cell.y,
		}
		if body.unit_name != "":
			entry["plate"] = body.name_plate_world_rect()
		out.append(entry)
	return out


func select_tile(cell: Vector2i) -> void:
	if selected_tile != null:
		selected_tile.set_selected(false)
	selected_tile = tiles[cell] as BoardTile
	selected_tile.set_selected(true)
	_sync_target_marks()


## Large ring on every living fighter a unit spell can legally hit.
## Walks and empty-tile spells leave the ring off. Rules are unchanged.
func _sync_target_marks() -> void:
	var spell := ""
	if _hud != null:
		spell = _hud.selected_spell()
	var show := spell != "" and TOUCH.spell_targets_unit(spell)
	var legal_cells := {}
	if show:
		var sim := _sim()
		if sim != null:
			var legal: Array = sim.legal_intents(CombatHUD.kit_seat(sim.snapshot()))
			for dest in SNAPSHOT_TILES.cast_dests(legal, spell):
				legal_cells[dest] = true
	for pawn in pawns_by_seat.values():
		if pawn == null or not is_instance_valid(pawn):
			continue
		var body: Pawn = pawn
		var marked := show and body.alive and body.visible and legal_cells.has(body.grid_position)
		body.set_target_marked(marked)


func _pulse_target_marks(delta: float) -> void:
	for pawn in pawns_by_seat.values():
		if pawn == null or not is_instance_valid(pawn):
			continue
		var body: Pawn = pawn
		if body.target_marked:
			body.advance_target_pulse(delta)


## Name plates of neighbours are spread apart (Pawn.spread_name_plates).
func _space_name_plates() -> void:
	Pawn.spread_name_plates(pawns_by_seat.values())


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
		# MP 0 still submits a walk. The coach says there is no MP to walk.
		_submit({"type": "move", "to": cell})
		return
	var actor := _active_unit(_sim().snapshot())
	if actor.is_empty() or not CombatHUD.offered_cast_ids(actor).has(spell_id):
		_hud.clear_spell()
		_paint_highlights()
		return
	if spell_id == SpellKits.DROP_SHADE and not _advance_click_accepted(cell, spell_id):
		# Out of range and other illegal Drop Shade cells are not a cast.
		# Do not arm them and do not flash the refund coach.
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


## Mauro 6 Oct 2026: with a spell armed, tapping a fighter's portrait or card
## in the top bar casts on that fighter, only when the sim says the cast is
## legal (range + line of sight). Same submit as tapping its tile.
func _on_unit_card_tapped(seat: int) -> void:
	if _busy or _view_locked or _hud == null:
		return
	var snap: Dictionary = _sim().snapshot()
	if CombatHUD.is_deployment_phase(snap) or bool(snap.get("match_over", false)):
		return
	if not _can_control_seat(int(snap.get("active_seat", 0))) or _active_is_stunned():
		return
	var spell_id := _hud.selected_spell()
	if spell_id == "":
		return
	var target := {}
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == seat:
			target = unit
	if target.is_empty() or not bool(target.get("alive", false)):
		return
	var actor := _active_unit(snap)
	var hidden := bool(target.get("invisible", false)) and CombatHUD.unit_team(target) != CombatHUD.unit_team(actor)
	var cell: Vector2i = target["pos"]
	var legal: Array = _sim().legal_intents(CombatHUD.kit_seat(snap))
	if hidden or not SNAPSHOT_TILES.cast_dests(legal, spell_id).has(cell):
		_hud.show_toast("%s can't reach %s: too far or no line of sight." % [SpellKits.spell(spell_id).get("name", "That spell"), SpellKits.display_name(str(target.get("class_id", "")))])
		return
	select_tile(cell)
	_handle_left_click(cell)


func _advance_click_accepted(cell: Vector2i, spell_id: String) -> bool:
	var legal: Array = _sim().legal_intents(CombatHUD.kit_seat(_sim().snapshot()))
	return SNAPSHOT_TILES.cast_dests(legal, spell_id).has(cell)


## Drop Shade only arms a sim-legal empty tile. Other spells still select freely.
## Advance keeps its refund submit. An illegal Drop Shade cell stays unselected.
func _cast_cell_armable(cell: Vector2i) -> bool:
	if _hud == null or _hud.selected_spell() != SpellKits.DROP_SHADE:
		return true
	return _advance_click_accepted(cell, SpellKits.DROP_SHADE)


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
	if _quiet_handoff(int(next_unit.get("seat", -1))):
		# Computer-run seat: no board-covering banner; the turn strip shows it.
		await get_tree().create_timer(QUIET_HANDOFF_SEC).timeout
	else:
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


## Mauro 5 Oct 2026: "put a option to go back to hub ... in koliseo". Leaves the
## fight (an online match closes its connection, like the class picker's back
## button) and opens the hub.
## Mauro 6 Oct 2026: elements can change before the fight (deployment only).
## The Elements screen keeps its own price (a new pair costs trophies); when it
## closes, the fighters of that class wear the new pick.
func _on_elements_requested() -> void:
	var snap: Dictionary = _sim().snapshot()
	if not CombatHUD.is_deployment_phase(snap) or _hud == null:
		return
	if _hud.get_node_or_null("ElementsScreen") != null:
		return
	var screen: ElementsScreen = load("res://scenes/elements_screen.gd").new()
	screen.name = "ElementsScreen"
	screen.font = _hud._ui_font
	_hud.add_child(screen)
	var class_id := _deploying_class(snap)
	if class_id != "":
		screen.pick_class(class_id)
	screen.closed.connect(_apply_prefight_elements)


## The class whose elements a pre-fight change is most likely for: this
## phone's seat online, else the first seat that is not ready yet.
## Snare Traps only the owner's side may see: this phone's seat online, else
## the side whose turn it is (hot-seat shares one screen).
func _own_traps(snap: Dictionary) -> Array:
	var viewer := CombatHUD.snap_local_seat(snap)
	if viewer < 0:
		viewer = int(snap.get("active_seat", -1))
	var viewer_team := -1
	for unit in snap.get("units", []):
		if int(unit.get("seat", -2)) == viewer:
			viewer_team = CombatHUD.unit_team(unit)
	var out: Array = []
	for trap in snap.get("trap_tiles", []):
		for unit in snap.get("units", []):
			if int(unit.get("seat", -2)) == int(trap.get("owner_seat", -1)) and CombatHUD.unit_team(unit) == viewer_team:
				out.append(trap)
	return out


func _deploying_class(snap: Dictionary) -> String:
	var local := CombatHUD.snap_local_seat(snap)
	var ready: Dictionary = snap.get("ready", {})
	for unit in snap.get("units", []):
		var seat := int(unit.get("seat", -1))
		if local >= 0 and seat != local:
			continue
		if local < 0 and bool(ready.get(CombatHUD.unit_team(unit), false)):
			continue
		return str(unit.get("class_id", ""))
	return ""


func _apply_prefight_elements() -> void:
	var snap: Dictionary = _sim().snapshot()
	if not CombatHUD.is_deployment_phase(snap):
		return
	var net := _net()
	if net != null and net.mode_name() == "client":
		net.resend_local_gear()
		return
	var kit := GearBag.load_saved().fight_gear(true)
	var local := CombatHUD.snap_local_seat(snap)
	for unit in snap.get("units", []):
		var seat := int(unit.get("seat", -1))
		if local >= 0 and seat != local:
			continue
		if local < 0 and not _TestLoadoutRef.ACTIVE:
			# Plain hot-seat fights without gear or picks.
			continue
		_sim().set_seat_gear(seat, kit.duplicate(true))
	_paint_highlights()


func _on_hub_requested() -> void:
	var net := _net()
	if net != null and net.mode_name() == "dedicated":
		return
	_stop_flash_tweens()
	_stop_walk_tween()
	if net != null and net.is_client() and net.has_method("return_to_hub_now"):
		net.return_to_hub_now()
		return
	if net != null and not net.is_hotseat():
		net.return_to_hotseat()
	get_tree().change_scene_to_file(MobileHub.MOBILE_HUB)


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
			_snap_ambush_teleports(events)
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
			await _play_walk(int(path_event.get("seat", 0)), path_event["path"], _as_cell(path_event.get("from", Vector2i(-1, -1))))
			_maybe_drain_net()
			return
	_refresh()
	_maybe_drain_net()


## Hot-seat and NetSession both call this. Toasts come from sim events; Burn icons come from the snapshot on refresh.
## Returns true when the pawn must not hop (occupied block or bounce).

func _snap_ambush_teleports(events: Array) -> void:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("spell", "")) != SpellKits.AMBUSH:
			continue
		# Hits plant on the back tile even when the wire drops `teleported`.
		# Misses are not hits. Their `to` is the enemy cell, so the body stays.
		if str(event.get("type", "")) != "hit":
			continue
		var seat := int(event.get("seat", -1))
		if not pawns_by_seat.has(seat):
			continue
		var dest := _ambush_event_dest(event)
		if not _in_bounds(dest):
			continue
		var pawn: Pawn = pawns_by_seat[seat]
		# Position first, then face the prey. The slash is armed only after
		# both, so Invisible cannot swing from the cast cell.
		pawn.grid_position = dest
		pawn.position = _cell_to_local(dest)
		pawn.z_index = _pawn_z(dest)
		var face := str(event.get("facing", ""))
		if face != "":
			pawn.set_facing(face)


func _event_cell(event: Dictionary, key: String) -> Vector2i:
	if not event.has(key):
		return Vector2i(-1, -1)
	var raw: Variant = event.get(key)
	if raw == null:
		return Vector2i(-1, -1)
	var cell := _as_cell(raw)
	if cell.x < 0 or cell.y < 0:
		return Vector2i(-1, -1)
	return cell


func _seat_cell(seat: int) -> Vector2i:
	for unit in _sim().snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -2)) != seat:
			continue
		var raw: Variant = unit.get("pos", null)
		if raw == null:
			return Vector2i(-1, -1)
		return _as_cell(raw)
	return Vector2i(-1, -1)


func _present_resolve(events: Array) -> bool:
	# A hit plants on the back tile in this call, before any slash, toast, or
	# damage float. Shade origin and Invisible origin share that snap. A miss
	# never moves. A second presenter for an open arrival must not restart it.
	var ambush_hit := _ambush_success_event(events)
	if _ambush_present_is_duplicate(ambush_hit):
		return false
	if ambush_hit.is_empty():
		_snap_ambush_teleports(events)
		_reveal_ambush_miss(events)
	# A hit has already snapped inside _begin_ambush_arrival. Marker, label,
	# and Shades count land in this beat. Do not wait out the lunge.
	_sync_shade_chrome(events)
	if ambush_hit.is_empty():
		_play_combat_feedback(events)
		_arm_view_motions(events)
		_arm_vfx(events)
		# Coach and vitals share this event with the float. Waiting for the
		# motion lock left the previous HIT line up under a new MISS.
		_commit_resolve_readout(events)
	else:
		_begin_ambush_arrival(ambush_hit, events)
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
		# An Ambush hit toast waits until the slash. Showing it on the snap
		# reads as damage in the same beat as the plant.
		if ambush_hit.is_empty():
			var toast := CombatHUD.toast_for_events(events)
			if toast != "":
				_hud.show_toast(toast)
	# Motion plays on the sprite first. Refresh (and the grey dead modulate) follows.
	if swallowed and _pending_motion_sec <= 0.0:
		_refresh()
	_resolve_hold_refresh = swallowed and _pending_motion_sec > 0.0
	return swallowed


func _ambush_success_event(events: Array) -> Dictionary:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("spell", "")) != SpellKits.AMBUSH:
			continue
		if str(event.get("type", "")) != "hit":
			continue
		# A hit is the arrival. Missing `teleported` used to take the immediate
		# slash while the body was still on the cast cell.
		return event
	return {}


func _ambush_present_is_duplicate(event: Dictionary) -> bool:
	# The face-hold is open from the instant snap until the slash. A second
	# presenter in that window must not restart the plant.
	if event.is_empty() or _ambush_contact_armed or _ambush_hold_seat < 0:
		return false
	return _ambush_hold_seat == int(event.get("seat", -2))


## Shade and Invisible share this arrival. Snap to the back tile and face
## the prey immediately. Origin dust is chrome from the Shade cell, or from
## the caster cell while Invisible — never a Shade marker for a self blink.
## The slash and the 22 wait until that plant has been on screen.
func _begin_ambush_arrival(event: Dictionary, events: Array) -> void:
	_ambush_arrival_token += 1
	var token := _ambush_arrival_token
	_stop_ambush_arrival_tween()
	_ambush_contact_armed = false
	# A hold left over from an earlier blink must not pin this body to the
	# cast cell while the new hit resolves.
	_ambush_hold_seat = -1
	_ambush_open_seat = int(event.get("seat", -1))
	if _vfx != null and _vfx.has_method("play_ambush_collapse"):
		_vfx.play_ambush_collapse(event)
	_commit_ambush_plant(event, token)
	var hold := VIEW_MOTION.AMBUSH_ARRIVE_HOLD_SEC
	if hold <= 0.0 or VIEW_MOTION.reduce_motion() or not is_inside_tree():
		_arm_ambush_contact(event, events, token)
		return
	_pending_motion_sec = maxf(_pending_motion_sec, hold)
	_ambush_arrival_tween = create_tween()
	_ambush_arrival_tween.tween_interval(hold)
	_ambush_arrival_tween.tween_callback(_arm_ambush_contact.bind(event, events, token))


## Snap, face, and reveal. The slash is a later beat. Calling this while the
## body is still on the cast cell is the plant, not the hit.
func _commit_ambush_plant(event: Dictionary, token: int) -> void:
	if token != _ambush_arrival_token or not is_inside_tree():
		return
	var seat := int(event.get("seat", -1))
	if pawns_by_seat.has(seat):
		var pawn: Pawn = pawns_by_seat[seat]
		if pawn != null and is_instance_valid(pawn):
			pawn.restore_ambush_body()
	# Hide first. A snapshot that already cleared Invisible must not draw a
	# solid slash on the cast cell. The reveal runs only after the foot is
	# on the back tile.
	_conceal_ambush_caster(event)
	_snap_ambush_teleports([event])
	_reveal_ambush_plant(event)
	if not pawns_by_seat.has(seat):
		return
	var planted: Pawn = pawns_by_seat[seat]
	if planted == null or not is_instance_valid(planted):
		return
	_ambush_hold_seat = seat
	_ambush_hold_cell = planted.grid_position
	_ambush_hold_facing = str(planted.facing)
	_ambush_hold_pos = planted.position
	_ambush_hold_event = event
	# The sim snapshot is already post-hit. Freeze the numbers on screen so a
	# refresh during the hold does not paint the 22 before the slash.
	var prey_seat := int(event.get("target_seat", -1))
	if pawns_by_seat.has(prey_seat):
		var prey: Pawn = pawns_by_seat[prey_seat]
		if prey != null and is_instance_valid(prey):
			prey.freeze_shown_vitals()


func _conceal_ambush_caster(event: Dictionary) -> void:
	var seat := int(event.get("seat", -1))
	if not pawns_by_seat.has(seat):
		return
	var pawn: Pawn = pawns_by_seat[seat]
	if pawn == null or not is_instance_valid(pawn):
		return
	var dest := _ambush_event_dest(event)
	# Still on the cast tile, or still faded. Either one would read as a
	# body slash if the strike started now.
	if pawn.invisible or not _in_bounds(dest) or pawn.grid_position != dest:
		pawn.conceal_for_ambush()


## A miss does not relocate. It still ends Invisible, and the body has to
## be drawn again. A slash stamp is not part of this beat.
func _reveal_ambush_miss(events: Array) -> void:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("spell", "")) != SpellKits.AMBUSH:
			continue
		if str(event.get("type", "")) != "miss":
			continue
		var seat := int(event.get("seat", -1))
		if not pawns_by_seat.has(seat):
			continue
		var pawn: Pawn = pawns_by_seat[seat]
		if pawn != null and is_instance_valid(pawn):
			pawn.reveal_after_ambush()


func _reveal_ambush_plant(event: Dictionary) -> void:
	if not _ambush_body_landed(event):
		return
	var seat := int(event.get("seat", -1))
	if not pawns_by_seat.has(seat):
		return
	var arrived: Pawn = pawns_by_seat[seat]
	if arrived != null and is_instance_valid(arrived):
		arrived.show_ambush_plant()


## Slash and the facing number only after the body is standing on the back tile.
func _arm_ambush_contact(event: Dictionary, events: Array, token: int) -> void:
	if token != _ambush_arrival_token or not is_inside_tree():
		return
	_ambush_arrival_tween = null
	_plant_ambush_body(event)
	if not _ambush_strike_ready(event):
		# No slash, no hit toast, no vitals drop, no damage float from the cast cell.
		# The submit tail plants from the snapshot, then the coach refresh runs.
		return
	_ambush_contact_armed = true
	_ambush_open_seat = -1
	_release_ambush_vitals()
	var shown := _events_for_ambush_contact(events)
	_publish_ambush_contact(shown)
	_commit_resolve_readout(shown)
	if _hud != null:
		var toast := CombatHUD.toast_for_events(shown)
		if toast != "":
			_hud.show_toast(toast)
	_play_combat_feedback(shown)
	_arm_view_motions(shown)
	_arm_vfx(shown)


## Contact plans treat a hit with no `teleported` flag as a whiff. Copy the
## batch and set the flag so the slash still plays on the back tile.
## The sim event itself is left unchanged.
func _events_for_ambush_contact(events: Array) -> Array:
	var shown: Array = []
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			shown.append(event)
			continue
		var row: Dictionary = event
		if str(row.get("spell", "")) == SpellKits.AMBUSH and str(row.get("type", "")) == "hit":
			row = row.duplicate(true)
			if not bool(row.get("teleported", false)):
				row["teleported"] = true
			# The origin puff already played on the collapse. Contact is the slash.
			row["present_phase"] = "contact"
		shown.append(row)
	return shown


## Position and the strike facing both have to be true before any hit chrome.
func _ambush_strike_ready(event: Dictionary) -> bool:
	if not _ambush_body_landed(event):
		return false
	var face := str(event.get("facing", ""))
	if face == "":
		return true
	var seat := int(event.get("seat", -1))
	if not pawns_by_seat.has(seat):
		return false
	var pawn: Pawn = pawns_by_seat[seat]
	return pawn != null and is_instance_valid(pawn) and str(pawn.facing) == face


## Coach, side HP, and the overhead bar. Only after the body is on the back tile.
func _publish_ambush_contact(events: Array) -> void:
	var snap: Dictionary = _sim().snapshot()
	if _hud != null:
		_hud.render(snap, _sim().legal_intents(CombatHUD.kit_seat(snap)))
	var event := _ambush_success_event(events)
	var target_seat := int(event.get("target_seat", -1))
	if not pawns_by_seat.has(target_seat):
		return
	var pawn: Pawn = pawns_by_seat[target_seat]
	if pawn == null or not is_instance_valid(pawn):
		return
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -2)) != target_seat:
			continue
		pawn.note_prey_vitals(unit)
		return


func _plant_ambush_body(event: Dictionary) -> void:
	var seat := int(event.get("seat", -1))
	if pawns_by_seat.has(seat):
		var pawn: Pawn = pawns_by_seat[seat]
		if pawn != null and is_instance_valid(pawn):
			pawn.restore_ambush_body()
	_snap_ambush_teleports([event])
	if seat == _ambush_hold_seat:
		_ambush_hold_seat = -1


func _capture_ambush_hold(event: Dictionary) -> void:
	_ambush_hold_event = event
	_ambush_hold_seat = -1
	var seat := int(event.get("seat", -1))
	if not pawns_by_seat.has(seat):
		return
	var pawn: Pawn = pawns_by_seat[seat]
	if pawn == null or not is_instance_valid(pawn):
		return
	_ambush_hold_seat = seat
	_ambush_hold_cell = pawn.grid_position
	_ambush_hold_facing = str(pawn.facing)
	_ambush_hold_pos = pawn.position
	var prey_seat := int(event.get("target_seat", -1))
	if not pawns_by_seat.has(prey_seat):
		return
	var prey: Pawn = pawns_by_seat[prey_seat]
	if prey != null and is_instance_valid(prey):
		prey.freeze_shown_vitals()


func _release_ambush_vitals() -> void:
	for pawn in pawns_by_seat.values():
		if pawn != null and is_instance_valid(pawn):
			(pawn as Pawn).release_frozen_vitals()


func _abandon_ambush_arrival() -> void:
	var running := _ambush_arrival_tween != null and is_instance_valid(_ambush_arrival_tween) and _ambush_arrival_tween.is_running()
	if running or _ambush_contact_armed:
		return
	if _ambush_open_seat < 0 and _ambush_hold_seat < 0:
		return
	_ambush_open_seat = -1
	_ambush_hold_seat = -1
	_release_ambush_vitals()


## Drop an in-flight plant. The callback token advances so a late slash cannot
## move the next body. Used when the pawn set itself is replaced.
func _cancel_ambush_arrival() -> void:
	_ambush_arrival_token += 1
	_stop_ambush_arrival_tween()
	_ambush_contact_armed = false
	_ambush_open_seat = -1
	_ambush_hold_seat = -1
	_ambush_hold_event = {}
	_release_ambush_vitals()


func _ambush_body_landed(event: Dictionary) -> bool:
	var seat := int(event.get("seat", -1))
	if not pawns_by_seat.has(seat):
		return false
	var pawn: Pawn = pawns_by_seat[seat]
	if pawn == null or not is_instance_valid(pawn):
		return false
	var dest := _ambush_event_dest(event)
	if not _in_bounds(dest) or pawn.grid_position != dest:
		return false
	# The logical cell can update before the sprite. A slash from the cast
	# tile is still a remote hit. The body has to be standing on the landing.
	return pawn.position.distance_to(_cell_to_local(dest)) <= 1.0


func _ambush_event_dest(event: Dictionary) -> Vector2i:
	var dest := _event_cell(event, "destination")
	if not _in_bounds(dest):
		dest = _event_cell(event, "to")
	if not _in_bounds(dest):
		dest = _seat_cell(int(event.get("seat", -1)))
	return dest


func _stop_ambush_arrival_tween() -> void:
	if _ambush_arrival_tween != null and is_instance_valid(_ambush_arrival_tween):
		_ambush_arrival_tween.kill()
	_ambush_arrival_tween = null


func _path_event(events: Array) -> Dictionary:
	for event in events:
		# Walk hops only. Advance is a teleport snap — do not play cell-by-cell path.
		# PushBlocked and bounce also never hop.
		if str(event.get("type", "")) == "move":
			return event
	return {}


func _play_combat_feedback(events: Array) -> void:
	# Hit flash on the target and Impact flash on the caster. Plays even when push is blocked.
	# Heal / Cleanse use a green-teal flash. Ward uses pale blue. Real damage flashes white.
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
					_shake_camera(float(event.get("dealt", event.get("damage", 0))), dying.has(target_seat))
			if not dying.has(target_seat):
				_tween_pawn_modulate(target_pawn)
		if int(event.get("engine_gained", 0)) > 0 and str(event.get("engine", "")) == "impact":
			var caster_seat := int(event.get("seat", -1))
			if pawns_by_seat.has(caster_seat):
				var caster_pawn: Pawn = pawns_by_seat[caster_seat]
				caster_pawn.flash_impact()
				_tween_pawn_modulate(caster_pawn)


## Wakfu-style per-class particle layer over the recipe VFX (view only).
func _ensure_flourish() -> void:
	if _flourish != null and is_instance_valid(_flourish):
		return
	_flourish = SPELL_FLOURISH.new()
	_flourish.name = "SpellFlourish"
	add_child(_flourish)
	_flourish.bind_elevation(_elev_at)


## Impact punch (view only): a short decaying camera wobble. Bigger hits and
## knockouts shake more. A sine wobble, not dice, so it never touches the sim.
func _shake_camera(dealt: float, knockout: bool) -> void:
	if _camera == null or not is_instance_valid(_camera) or not is_inside_tree():
		return
	if dealt <= 0.0 and not knockout:
		return
	var amp := clampf(1.5 + dealt * 0.12, 1.5, 5.0)
	if knockout:
		amp = 7.0
	if _shake_tween != null and is_instance_valid(_shake_tween):
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_apply_shake.bind(amp), 0.0, 1.0, 0.26 if not knockout else 0.4)
	_shake_tween.tween_callback(func() -> void: _camera.offset = Vector2.ZERO)


func _apply_shake(t: float, amp: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var fall := (1.0 - t) * (1.0 - t)
	_camera.offset = Vector2(sin(t * 57.0), cos(t * 43.0) * 0.6) * amp * fall / _camera.zoom.x


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


func _play_walk(seat: int, path: Array, origin: Vector2i = Vector2i(-1, -1)) -> void:
	_busy = true
	_hop_seat = seat
	_hud.set_locked(true)
	var snap: Dictionary = _sim().snapshot()
	_hud.render(snap, [])
	for tile in tiles.values():
		(tile as BoardTile).set_highlight("")
	for step in path:
		var cell: Vector2i = _as_cell(step)
		if tiles.has(cell):
			_tile_at(cell).set_highlight("move")
	await _animate_path(seat, path, origin)
	if not is_inside_tree():
		return
	_hop_seat = -1
	_hud.set_locked(false)
	_busy = false
	_refresh()
	if _clock_expired_pending:
		_clock_expired_pending = false
		_on_turn_clock_expired()


func _animate_path(seat: int, path: Array, origin: Vector2i = Vector2i(-1, -1)) -> void:
	if not pawns_by_seat.has(seat):
		return
	var pawn: Pawn = pawns_by_seat[seat]
	# One tween through cell centers. Equal time per cell keeps straight and
	# diagonal steps even, and a corner cannot collapse into one diagonal slide.
	# grid_position is the tactical cell and updates when the foot commits.
	# pawn.position is the visual foot. It eases in-out across the tile and
	# holds the arrival cell through the plant. It does not linear-slide.
	# The sim has already moved the unit. Put the body back on the departure tile
	# before the step, or a refresh snaps it and the walk reads as a teleport.
	# Face the step before the body moves. A cardinal uses that letter. Any other
	# segment faces the screen direction so the pawn does not slide sideways or
	# backwards. The first tile, and a direction change, take a short weight
	# shift after that facing is set. Middle tiles do not. Arrival keeps the
	# last segment's facing. Dust lands on a facing change and on the final plant.
	if _in_bounds(origin):
		pawn.position = _cell_to_local(origin)
		_set_pawn_cell(pawn, origin)
	pawn.hold_idle()
	var prev: Vector2i = pawn.grid_position
	var cells: Array[Vector2i] = []
	for step in path:
		cells.append(_as_cell(step))
	if cells.is_empty() or not is_inside_tree() or pawn == null or not is_instance_valid(pawn):
		if pawn != null and is_instance_valid(pawn):
			pawn.end_path_walk()
			pawn.release_idle()
		return
	var visual := pawn.facing
	_stop_walk_tween()
	_walk_tween = create_tween()
	_walk_tween.set_trans(Tween.TRANS_LINEAR)
	var walk_armed := false
	for cell_i in cells.size():
		var cell: Vector2i = cells[cell_i]
		var grid_dir := COMBAT_SIM_SCRIPT.facing_from_step(prev, cell)
		if grid_dir == "":
			grid_dir = COMBAT_SIM_SCRIPT.hop_facing(prev, cell)
		var dir := VIEW_MOTION.walk_segment_facing(prev, cell, _cell_to_local(cell) - _cell_to_local(prev))
		if dir == "":
			dir = grid_dir
		var facing_changed := dir != "" and dir != visual
		# 180 is plant, then the new facing, then the settle, then the tile.
		# The turn happens while the foot is still on the cell. No side facing.
		var about := VIEW_MOTION.is_about_face(visual, dir)
		var turn := facing_changed or cell_i == 0 or about
		if turn:
			_walk_tween.tween_callback(_snap_walk_facing.bind(pawn, dir))
		if not walk_armed:
			_walk_tween.tween_callback(_arm_path_walk.bind(pawn))
			walk_armed = true
		if VIEW_MOTION.anticipate_segment(cell_i, facing_changed) or about:
			_walk_tween.tween_method(_sample_step_anticipation.bind(pawn), 0.0, 1.0, VIEW_MOTION.STEP_SETTLE_SEC)
		if dir != "":
			visual = dir
		if turn:
			_walk_tween.tween_callback(_sync_step_plant.bind(pawn))
		else:
			# Straight seam. Cubic continues. The strip stays on the contact.
			_walk_tween.tween_callback(_bridge_straight_tile.bind(pawn))
		# The hop is airborne until Y returns to 0. Dust is that landing,
		# and only when the facing changed or this is the last plant.
		# The squash after the landing stays quiet, and so does takeoff.
		var dust := VIEW_MOTION.dust_on_plant(facing_changed, cell_i == cells.size() - 1)
		if VIEW_MOTION.glide:
			# One glide per tile: constant speed, ease only at the path ends.
			var first := cell_i == 0
			var last := cell_i == cells.size() - 1
			_walk_tween.tween_method(_sample_glide_step.bind(pawn, prev, cell, first, last), 0.0, 1.0, Pawn.WALK_TILE_SEC)
			if dust:
				_walk_tween.tween_callback(_puff_footstep.bind(pawn, cell))
		else:
			_walk_tween.tween_method(_sample_walk_step.bind(pawn, prev, cell), 0.0, VIEW_MOTION.HOP_PLANT_AT, Pawn.WALK_TILE_SEC * VIEW_MOTION.HOP_PLANT_AT)
			if dust:
				_walk_tween.tween_callback(_puff_footstep.bind(pawn, cell))
			_walk_tween.tween_method(_sample_walk_step.bind(pawn, prev, cell), VIEW_MOTION.HOP_PLANT_AT, 1.0, Pawn.WALK_TILE_SEC * (1.0 - VIEW_MOTION.HOP_PLANT_AT))
		_walk_tween.tween_callback(_commit_walk_cell.bind(pawn, cell))
		prev = cell
	# Landed contact, then one readable idle before the face pad unlocks.
	_walk_tween.tween_callback(_hold_stop_plant.bind(pawn))
	_walk_tween.tween_interval(VIEW_MOTION.STOP_IDLE_SEC)
	await _walk_tween.finished
	if pawn != null and is_instance_valid(pawn):
		var last: Vector2i = cells[cells.size() - 1]
		pawn.position = _cell_to_local(last)
		_set_pawn_cell(pawn, last)
		pawn.end_path_walk()
		pawn.release_idle()


func _arm_path_walk(pawn: Pawn) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	pawn.arm_driven_walk()


func _seat_facing(seat: int) -> String:
	for unit in _sim().snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -2)) == seat:
			return str(unit.get("facing", ""))
	return ""


func _bridge_straight_tile(pawn: Pawn) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	pawn.bridge_straight_tile()


func _hold_stop_plant(pawn: Pawn) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	pawn.hold_stop_plant()


func _sync_step_plant(pawn: Pawn) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	pawn.sync_walk_plant()


func _sample_step_anticipation(t: float, pawn: Pawn) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	pawn.sample_step_anticipation(t)


func _sample_walk_step(t: float, pawn: Pawn, src: Vector2i, dst: Vector2i) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var dir := VIEW_MOTION.walk_segment_facing(src, dst, _cell_to_local(dst) - _cell_to_local(src))
	if dir == "":
		dir = str(pawn.facing)
	var u := VIEW_MOTION.step_travel(t)
	pawn.position = _cell_to_local(src).lerp(_cell_to_local(dst), u)
	# Idle texture while the node moves is the slide. No walk strip means no
	# animated gait frame, but the node itself must still glide tile to tile —
	# begin_segment_walk() only gates the walk-cycle animation, never the move.
	if pawn.begin_segment_walk(dir):
		pawn.sample_driven_gait(t)
	_track_step_sort(t, pawn, src, dst)



## Glide sample: the body moves on the eased path; the stride and the
## footfall bob run on the tile's own clock so the legs never stop.
func _sample_glide_step(t: float, pawn: Pawn, src: Vector2i, dst: Vector2i, first: bool, last: bool) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var dir := VIEW_MOTION.walk_segment_facing(src, dst, _cell_to_local(dst) - _cell_to_local(src))
	if dir == "":
		dir = str(pawn.facing)
	var u := VIEW_MOTION.glide_travel(t, first, last)
	pawn.position = _cell_to_local(src).lerp(_cell_to_local(dst), u)
	if pawn.begin_segment_walk(dir):
		pawn.sample_driven_gait(u)
	_track_step_sort(u, pawn, src, dst)
	_follow_walker(pawn)


## Wakfu-style follow (Mauro 2 Oct 2026, second video): when the board is
## zoomed in, the camera drifts after the walking fighter, inside the pan
## limits. Fit-to-screen (no pan room) does not move.
func _follow_walker(pawn: Pawn) -> void:
	if _camera == null or _panning or _touch_panning or pawn == null:
		return
	var snap: Dictionary = _sim().snapshot()
	if not _follow_local_fighter(snap):
		return
	if pawn.seat != CombatHUD.snap_local_seat(snap):
		return
	if _pan_limit.x <= 1.0 and _pan_limit.y <= 1.0:
		return
	var target := (pawn.global_position - global_position)
	_camera.position = _camera.position.lerp(target, 0.08)
	_clamp_camera()


func _snap_walk_facing(pawn: Pawn, dir: String) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	if dir != "":
		pawn.set_facing(dir)
	pawn.retarget_walk_strip()


func _commit_walk_cell(pawn: Pawn, cell: Vector2i) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	_set_pawn_cell(pawn, cell)


## Dust at the destination feet, on the sample where hop Y returns to 0.
## Facing changes and the final plant only. Not takeoff, not mid-air,
## and not every straight tile.
func _puff_footstep(pawn: Pawn, cell: Vector2i) -> void:
	if _vfx == null or pawn == null or not _vfx.has_method("play_footstep"):
		return
	var intensity := 0.28 if VIEW_MOTION.reduce_motion() else 0.52
	_vfx.call("play_footstep", pawn.position, cell, intensity)


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
	var snap: Dictionary = _sim().snapshot()
	var block := float(_vfx.play(events, snap))
	_ensure_flourish()
	_flourish.play(events, snap)
	_pending_motion_sec = maxf(_pending_motion_sec, minf(block, VIEW_MOTION.ACTION_LOCK_MAX))


## Spell commit plays the caster attack or cast plan on hit and on miss.
## The target recoils or lifts only when the spell connects. VFX stays in _arm_vfx.
func _arm_view_motions(events: Array) -> void:
	_pending_motion_sec = 0.0
	if VIEW_MOTION.reduce_motion():
		return
	var plans: Dictionary = VIEW_MOTION.chrome_plans(events)
	var caster_event: Dictionary = VIEW_MOTION.caster_event(events)
	var longest := 0.0
	for seat in plans.keys():
		var seat_n := int(seat)
		if not pawns_by_seat.has(seat_n):
			continue
		var pawn: Pawn = pawns_by_seat[seat_n]
		if pawn == null or not is_instance_valid(pawn):
			continue
		var plan: Dictionary = plans[seat]
		if int(caster_event.get("seat", -2)) == seat_n and (bool(plan.get("attack", false)) or bool(plan.get("cast", false))):
			plan["aim"] = _aim_vector(seat_n, caster_event)
		if bool(plan.get("hit", false)):
			plan["away"] = _away_vector(seat_n, VIEW_MOTION.hit_event_for(events, seat_n))
		longest = maxf(longest, pawn.play_view_plan(plan))
	_pending_motion_sec = minf(longest, VIEW_MOTION.ACTION_LOCK_MAX)


func _aim_vector(seat: int, event: Dictionary) -> Vector2:
	var pawn: Pawn = pawns_by_seat[seat]
	# Ambush `to` is the back tile (where the body just snapped). The slash
	# aims at the struck enemy (`from`), not back along the blink.
	var aim_at: Variant = event.get("to", null)
	if str(event.get("spell", "")) == SpellKits.AMBUSH and event.has("from"):
		aim_at = event.get("from")
	if aim_at != null:
		var delta := _cell_to_local(_as_cell(aim_at)) - pawn.position
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
	var budget_sec := VIEW_MOTION.ACTION_LOCK_MAX
	if _ambush_open_seat >= 0 or (_ambush_arrival_tween != null and is_instance_valid(_ambush_arrival_tween)):
		# Collapse + plant hold + slash is longer than the 0.6s one-shot lock.
		# Cutting here used to settle the strike in the same beat as the snap.
		budget_sec = maxf(budget_sec, VIEW_MOTION.ambush_sequence_sec())
	var budget_ms := int(budget_sec * 1000.0)
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
	# Settle plants the sprite where it stands. If the arrival callback never
	# ran, that would be the cast cell. Snap first. Do not arm the slash here:
	# settle would kill it. The arrival tween still owns contact.
	if _ambush_hold_seat >= 0 and not _ambush_hold_event.is_empty():
		_plant_ambush_body(_ambush_hold_event)
	_settle_motions()
	_abandon_ambush_arrival()
	_pending_motion_sec = 0.0
	_view_locked = false
	if _hud != null and not _busy:
		_hud.set_locked(false)


func _motions_active() -> bool:
	if _ambush_arrival_tween != null and is_instance_valid(_ambush_arrival_tween) and _ambush_arrival_tween.is_running():
		return true
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
	_sync_shade_markers(snap)
	# Coach and the side cards stay on the pre-hit read until contact.
	# Painting them during the plant hold shows the 22 before the slash.
	var ambush_waiting := _ambush_open_seat >= 0 and not _ambush_contact_armed
	if _hud != null and not ambush_waiting:
		_hud.render(snap, legal)
	_paint_highlights()
	_hydrate_turn_clock(snap)
	_maybe_reframe(snap)
	if _vfx != null and _vfx.has_method("sync_snapshot"):
		snap["trap_tiles_visible"] = _own_traps(snap)
		_vfx.sync_snapshot(snap)
	_track_result(snap)


## Dofus-style end-of-fight window (ui/combat_result.gd). Clock starts when
## combat starts (after deploy); the window opens once per finished match.
func _track_result(snap: Dictionary) -> void:
	var net := _net()
	if net != null and net.has_method("is_dedicated") and net.is_dedicated():
		return
	if not bool(snap.get("match_over", false)):
		if _result_shown:
			_result_shown = false
			_fight_started_msec = 0
		if _fight_started_msec == 0 and not CombatHUD.is_deployment_phase(snap):
			_fight_started_msec = Time.get_ticks_msec()
		return
	if _result_shown:
		return
	_result_shown = true
	var secs := 0
	if _fight_started_msec > 0:
		secs = int((Time.get_ticks_msec() - _fight_started_msec) / 1000)
	_on_match_result(snap, secs)


## Koliseo: winners / losers, and the coins + trophies an online win paid.
func _on_match_result(snap: Dictionary, secs: int) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(RESULT_DELAY).timeout.connect(_show_koliseo_result.bind(snap.duplicate(true), secs))


func _show_koliseo_result(snap: Dictionary, secs: int) -> void:
	if not is_inside_tree():
		return
	var net := _net()
	var local_seat := -1
	var payout := {}
	if net != null and net.is_online():
		local_seat = int(net.local_seat)
		payout = net.koliseo_last_payout
	var window := show_result(CombatResult.koliseo_result(snap, local_seat, payout, secs, _portrait_of))
	if net != null and net.is_client():
		_schedule_online_home(window)


## After the result can be read, an online phone returns to the hub.
## CLOSE goes immediately. A normal match end never shows "server disconnected".
func _schedule_online_home(window: CombatResult) -> void:
	if _online_home_pending or not is_inside_tree():
		return
	_online_home_pending = true
	var net := _net()
	# The wait lives on the autoload. Closing the socket used to run first, and
	# change_scene on this node then no-op'd (tree busy, or this node already
	# leaving). CLOSE still returns immediately.
	if net != null and net.has_method("arm_hub_return"):
		net.arm_hub_return(RESULT_READ_SEC)
	elif net != null and net.has_method("note_match_finished"):
		net.note_match_finished()
	if window != null and net != null and net.has_method("return_to_hub_now"):
		if not window.closed.is_connected(net.return_to_hub_now):
			window.closed.connect(net.return_to_hub_now)
	elif window != null and not window.closed.is_connected(_go_hub_after_online_match):
		window.closed.connect(_go_hub_after_online_match)
		get_tree().create_timer(RESULT_READ_SEC).timeout.connect(_go_hub_after_online_match)


func _go_hub_after_online_match() -> void:
	if not _online_home_pending:
		return
	_online_home_pending = false
	var net := _net()
	if net != null and net.has_method("return_to_hub_now"):
		net.return_to_hub_now()
		return
	if not is_inside_tree():
		return
	_stop_flash_tweens()
	_stop_walk_tween()
	if net != null and net.has_method("leave_after_match"):
		net.leave_after_match()
	elif net != null and not net.is_hotseat():
		net.return_to_hotseat()
	get_tree().change_scene_to_file(MobileHub.MOBILE_HUB)


func _portrait_of(unit: Dictionary) -> Texture2D:
	if _hud != null and _hud.has_method("_portrait_for"):
		return _hud._portrait_for(unit)
	return null


func show_result(data: Dictionary) -> CombatResult:
	if _result_layer == null or not is_instance_valid(_result_layer):
		_result_layer = CanvasLayer.new()
		_result_layer.name = "ResultLayer"
		_result_layer.layer = 30
		add_child(_result_layer)
	for child in _result_layer.get_children():
		child.queue_free()
	var window: CombatResult = COMBAT_RESULT.new()
	window.name = "CombatResult"
	window.setup(data)
	_result_layer.add_child(window)
	return window


func _rebuild_pawns() -> void:
	# The previous arrival's tween still owns the old seat. A new pawn set must
	# not inherit that hold, or the next Ambush stays on the previous back tile.
	_cancel_ambush_arrival()
	_stop_flash_tweens()
	# Pawns only. Shade markers live on ShadeMarkers. A marker that raced onto
	# Units is moved, not freed — this pass used to free the token.
	var layer := _shade_layer()
	for child in $Units.get_children():
		if child.get_script() == SHADE_MARKER:
			child.reparent(layer)
			continue
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
		# Mauro 30 Sep 2026: an Invisible fighter is not drawn at all (no ghost,
		# ring or status dots) for the player whose turn it is not.
		var unseen := bool(unit.get("invisible", false)) and bool(unit.get("alive", true)) and not _viewer_sees_seat(seat, snap)
		pawn.visible = placed and not unseen
		if _vfx != null and _vfx.has_method("set_seat_hidden"):
			_vfx.call("set_seat_hidden", seat, unseen)
		if not placed:
			continue
		var raw_events: Variant = snap.get("last_events", [])
		var burn_events: Array = raw_events if typeof(raw_events) == TYPE_ARRAY else []
		var hopping := _busy and seat == _hop_seat
		var holding := _ambush_hold_seat == seat
		var kept_cell := pawn.grid_position
		var kept_pos := pawn.position
		var kept_face := str(pawn.facing)
		pawn.apply_snapshot(unit, int(snap.get("active_seat", 0)), burn_events)
		if holding:
			# The plant already happened. A refresh during the face-hold keeps
			# that back tile and the strike facing.
			pawn.grid_position = _ambush_hold_cell
			pawn.position = _ambush_hold_pos
			if _ambush_hold_facing != "":
				pawn.set_facing(_ambush_hold_facing)
			pawn.z_index = _pawn_z(_ambush_hold_cell)
		elif hopping:
			pawn.grid_position = kept_cell
			pawn.position = kept_pos
			if kept_face != "":
				pawn.hold_walk_facing(kept_face)
		else:
			pawn.position = _cell_to_local(cell)
			pawn.z_index = _pawn_z(cell)
		pawn.rewrite_frozen_vitals()


## Drop Shade's body lives on ShadeMarkers, not under Units. Rebuild frees every
## Units child, which used to delete the token before the next refresh. Shade is
## a standing token. Ambush is the blink.
func _sync_shade_markers(snap: Dictionary) -> void:
	var live: Dictionary = {}
	# Shades are secret: only their owner sees them (Mauro 29 Sep 2026).
	# Online the host already strips the opponent's; hot-seat shows the seat
	# holding the phone (kit_seat = local seat, else the active seat).
	var viewer := CombatHUD.kit_seat(snap)
	for token in snap.get("shade_tokens", []):
		if typeof(token) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = token
		var shade_owner := int(rec.get("owner_seat", -1))
		if shade_owner >= 0 and viewer >= 0 and shade_owner != viewer:
			continue
		var cell := _as_cell(rec.get("pos", Vector2i(int(rec.get("x", -1)), int(rec.get("y", -1)))))
		if not _in_bounds(cell) or int(rec.get("turns", 0)) <= 0:
			continue
		live[cell] = int(rec.get("turns", 3))
	var stale: Array = []
	for cell in _shade_markers.keys():
		if not live.has(cell):
			stale.append(cell)
	for cell in stale:
		var gone: Node = _shade_markers[cell]
		if gone != null and is_instance_valid(gone):
			gone.queue_free()
		_shade_markers.erase(cell)
	var layer := _shade_layer()
	var origin_cell := _ambush_shade_origin(_sim().ambush_origin(CombatHUD.kit_seat(snap)))
	for cell in live.keys():
		var marker: Node = _shade_markers.get(cell)
		var spawned := marker == null or not is_instance_valid(marker)
		if spawned:
			marker = SHADE_MARKER.new()
			layer.add_child(marker)
			_shade_markers[cell] = marker
		elif marker.get_parent() != layer:
			marker.reparent(layer)
		var at: Vector2i = cell
		marker.call("show_token", _cell_to_local(at), SHADE_LAYER_Z + at.x + at.y, int(live[cell]), spawned, at == origin_cell)


func _shade_layer() -> Node2D:
	var layer := get_node_or_null("ShadeMarkers") as Node2D
	if layer == null:
		layer = Node2D.new()
		layer.name = "ShadeMarkers"
		add_child(layer)
	layer.z_as_relative = false
	layer.z_index = SHADE_LAYER_Z
	return layer


func _includes_drop_shade(events: Array) -> bool:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "cast" and str(event.get("spell", "")) == SpellKits.DROP_SHADE:
			return true
	return false


## Drop Shade, a Shade-origin Ambush hit, or a Shade expire. Miss keeps the token.
func _shade_board_changed(events: Array) -> bool:
	if _includes_drop_shade(events):
		return true
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = event
		if str(rec.get("type", "")) == "expire" and str(rec.get("status", "")) == "shade":
			return true
		if str(rec.get("spell", "")) != SpellKits.AMBUSH:
			continue
		if str(rec.get("type", "")) == "hit" and bool(rec.get("teleported", false)) and not bool(rec.get("shade_retained", true)):
			return true
	return false


func _sync_shade_chrome(events: Array) -> void:
	if not _shade_board_changed(events):
		return
	var snap: Dictionary = _sim().snapshot()
	_sync_shade_markers(snap)
	# A hit has already subtracted HP in the sim. Painting the coach and the
	# HP cards here drops the prey while Gloam is still on the cast tile.
	# The contact beat publishes that after the snap and the facing.
	if _hud != null and _ambush_success_event(events).is_empty():
		_hud.render(snap, _sim().legal_intents(CombatHUD.kit_seat(snap)))


func _paint_highlights() -> void:
	for tile in tiles.values():
		(tile as BoardTile).set_highlight("")
	var snap: Dictionary = _sim().snapshot()
	if snap.get("match_over", false) or _busy:
		_paint_blocked(snap)
		_sync_aim_line()
		_sync_target_marks()
		return
	if CombatHUD.is_deployment_phase(snap):
		_paint_deploy_highlights(snap)
		_paint_blocked(snap)
		_sync_target_marks()
		return
	if not _shows_turn_chrome(CombatHUD.kit_seat(snap)):
		# A computer-run seat (Stasis monsters): no walk / range tiles on its turn.
		_paint_blocked(snap)
		_sync_aim_line()
		_sync_target_marks()
		return
	var legal: Array = _sim().legal_intents(CombatHUD.kit_seat(snap))
	var spell_id := _hud.selected_spell()
	var actor := _kit_unit(snap)
	if spell_id != "" and not CombatHUD.offered_cast_ids(actor, legal).has(spell_id):
		spell_id = ""
	# Paint the range ring as soon as the spell is selected. Enemy casts leave
	# empty in-range tiles gold. Empty-tile casts (Drop Shade, Snap Wall, Plant)
	# used to paint only legal dests, so the ring was wiped and a tap past the
	# edge looked like the spell did nothing. Advance stays legal-dest only.
	# Walk chrome stays off. Rolling casts also get Locked hit percent aim preview.
	var range_cells: Array = []
	var range_def: Dictionary = {}
	var stamp_rim := false
	var ambush_armed := CombatHUD.legal_cast_ids(legal).has(SpellKits.AMBUSH)
	# Ambush range chrome is the legal arm only. A fresh Shade, a diagonal, or
	# Manhattan 3 must not paint a teach ring while the cast is absent from legal_intents.
	if spell_id != "" and spell_id != SpellKits.ADVANCE and (spell_id != SpellKits.AMBUSH or ambush_armed):
		range_def = SpellKits.spell(spell_id)
		var target_kind := str(range_def.get("target", ""))
		if target_kind == "enemy" or target_kind == "ally" or target_kind == "any" or target_kind == "empty_tile" or target_kind == "tile":
			range_cells = _sim().range_highlight_cells(CombatHUD.kit_seat(snap), spell_id)
			stamp_rim = target_kind == "empty_tile" or target_kind == "tile"
			for cell in range_cells:
				if tiles.has(cell) and spell_id != SpellKits.AMBUSH:
					_tile_at(cell).set_highlight("range")
			# In range but behind a wall: grey, no sight (CombatSim decides).
			for cell in _sim().sight_blocked_cells(CombatHUD.kit_seat(snap), spell_id):
				if tiles.has(cell):
					_tile_at(cell).set_highlight("grey")
	# Walk chrome follows sim-legal dests only. Do not invent weighted reachability here.
	# Solid props are already not walkable, so a blue path cannot cross a rock, fence, or arch.
	# kind == "move" and spell_id == "" — walk highlights stay off while a spell is selected.
	for dest in SNAPSHOT_TILES.walk_dests(legal):
		if spell_id == "" and tiles.has(dest):
			_tile_at(dest).set_highlight("move")
	# Advance and other cast dest chrome: legal_intents only. No client range ring.
	for dest in SNAPSHOT_TILES.cast_dests(legal, spell_id):
		if tiles.has(dest):
			var highlight := "advance" if spell_id == SpellKits.ADVANCE else "target"
			_tile_at(dest).set_highlight(highlight)
	if stamp_rim and not actor.is_empty():
		_stamp_range_rim(range_cells, _as_cell(actor.get("pos", Vector2i.ZERO)), int(range_def.get("max_range", 0)))
	# Ambush's legal cross is blue and shade-centric. Paint it after cast dests
	# so the enemy cell stays in that cross instead of the orange target wash.
	if spell_id == SpellKits.AMBUSH and ambush_armed:
		for cell in range_cells:
			if tiles.has(cell):
				_tile_at(cell).set_highlight("legal")
	_paint_blocked(snap)
	_paint_ambush_chrome(snap, spell_id)
	if spell_id == SpellKits.DROP_SHADE:
		# Every cell that is not a legal empty dest is grey before confirm.
		# Out of range, occupied, and unwalkable stay unarmed. No REJECT flash.
		var shade_dests: Array = SNAPSHOT_TILES.cast_dests(legal, spell_id)
		for cell in tiles.keys():
			if shade_dests.has(cell):
				continue
			_tile_at(cell).set_highlight("grey")
		for dest in shade_dests:
			if tiles.has(dest):
				_tile_at(dest).set_highlight("target")
	_sync_aim_preview()
	_sync_target_marks()


## Locked chrome. Origin and landing highlights only while legal_intents has an
## Ambush cast. A Shade adjacent to a foe is not an origin. Invisible keeps the
## Shade highlight when that Shade is still the jump. Range is that origin.
func _paint_ambush_chrome(snap: Dictionary, spell_id: String) -> void:
	var seat := CombatHUD.kit_seat(snap)
	var legal: Array = _sim().legal_intents(seat)
	if not CombatHUD.legal_cast_ids(legal).has(SpellKits.AMBUSH):
		return
	var origin: Dictionary = _sim().ambush_origin(seat)
	if not bool(origin.get("show", false)):
		return
	var cell: Vector2i = origin["origin"]
	var walking := spell_id == "" and SNAPSHOT_TILES.walk_dests(_sim().legal_intents(seat)).has(cell)
	if tiles.has(cell) and not walking:
		_tile_at(cell).set_highlight("origin")
	if spell_id != SpellKits.AMBUSH:
		return
	var landing: Dictionary = _sim().ambush_landing_preview(seat)
	if bool(landing.get("ok", false)) and tiles.has(landing.get("cell", Vector2i(-1, -1))):
		_tile_at(landing["cell"]).set_highlight("landing")


## Shade cloaks sit on a layer above every unit z. A plant onto that tile used
## to slash under the cloak, which read as a body hit with no relocate.
func _pawn_z(cell: Vector2i) -> int:
	var z := VISUAL_SORT.unit_z_index(cell, _elev_at(cell))
	if _shade_markers.has(cell):
		z = maxi(z, SHADE_LAYER_Z + cell.x + cell.y + 2)
	return z


func _ambush_shade_origin(origin: Dictionary) -> Vector2i:
	if bool(origin.get("show", false)) and not bool(origin.get("from_self", false)):
		return origin["origin"]
	return Vector2i(-999, -999)


## Keep the max-range shell gold after legal dests repaint the interior.
## Drop Shade's legal tiles are the empty tiles, so a target pass used to erase
## the whole ring and the edge was invisible on the phone.
func _stamp_range_rim(cells: Array, origin: Vector2i, max_range: int) -> void:
	if max_range <= 0:
		return
	for cell in cells:
		var at := _as_cell(cell)
		if not tiles.has(at):
			continue
		if COMBAT_SIM_SCRIPT.chebyshev(origin, at) != max_range:
			continue
		_tile_at(at).set_highlight("range")


func _paint_blocked(snap: Dictionary) -> void:
	for cell in SNAPSHOT_TILES.blocked_cells(snap):
		if tiles.has(cell):
			_tile_at(cell).set_highlight("blocked")


func _snap_wall_cell(cell: Vector2i) -> bool:
	return SNAPSHOT_TILES.blocked_cells(_sim().snapshot()).has(cell)


## Snap Wall armed and this wall is a legal knock-down for the active seat.
func _snap_wall_break_cell(cell: Vector2i) -> bool:
	if _hud == null or _hud.selected_spell() != SpellKits.SNAP_WALL:
		return false
	var snap: Dictionary = _sim().snapshot()
	for intent in _sim().legal_intents(int(snap.get("active_seat", 0))):
		if str(intent.get("spell", "")) == SpellKits.SNAP_WALL and intent.get("to") == cell:
			return true
	return false


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
		var occupant_side := _snap_team(snap, occupant) if int(snap.get("team_size", 1)) > 1 else occupant
		if not bool(ready.get(occupant_side, ready.get(str(occupant_side), false))):
			if not _can_control_seat(occupant):
				_hud.set_deploy_note("That fighter belongs to the other seat.")
				return
			_deploy_selected_seat = occupant
			var unit := _unit_from_seat(snap, occupant)
			_hud.set_deploy_note("Selected %s. Click another zone tile on that side to reposition." % str(unit.get("name", "fighter")))
			_refresh()
			return
	var zones: Dictionary = _sim().snapshot().get("deploy_zones", {})
	var deploy_snap: Dictionary = _sim().snapshot()
	var side_pick := _deploy_selected_seat
	if int(deploy_snap.get("team_size", 1)) > 1 and side_pick >= 0:
		side_pick = _snap_team(deploy_snap, side_pick)
	var seat := CombatHUD.deploy_seat_for_cell(cell, side_pick, zones)
	if int(deploy_snap.get("team_size", 1)) > 1:
		seat = _team_deploy_seat(deploy_snap, seat)
		if seat < 0:
			_hud.set_deploy_note("Whole team placed. Tap a fighter to move it, or press Ready.")
			return
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
		_sync_aim_line()
		return
	var snap: Dictionary = _sim().snapshot()
	# Enemy swings must not keep the player's "HIT %%" caption on the board.
	if not _can_control_seat(int(snap.get("active_seat", 0))):
		_hud.set_aim_preview({})
		_sync_aim_line()
		return
	var spell_id := _hud.selected_spell()
	if spell_id == "" or not SpellKits.rolls(spell_id):
		_hud.set_aim_preview({})
		_sync_aim_line()
		return
	_hud.set_aim_preview(_sim().aim_hit_preview(CombatHUD.kit_seat(snap), spell_id, dest))
	_sync_aim_line()


## The float is already armed from these events. Paint the same snapshot now.
## A plant hold still owns the pre-contact read; contact calls this after release.
func _commit_resolve_readout(_events: Array) -> void:
	if _aim_line != null and is_instance_valid(_aim_line):
		_aim_line.clear_aim()
	var snap: Dictionary = _sim().snapshot()
	var ambush_waiting := _ambush_open_seat >= 0 and not _ambush_contact_armed
	if _hud != null and not ambush_waiting:
		_hud.set_aim_preview({})
		_hud.render(snap, _sim().legal_intents(CombatHUD.kit_seat(snap)))
	if ambush_waiting:
		return
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var seat := int(unit.get("seat", -1))
		if not pawns_by_seat.has(seat):
			continue
		var pawn: Pawn = pawns_by_seat[seat]
		if pawn == null or not is_instance_valid(pawn):
			continue
		pawn.note_resolved_vitals(unit)


func _ensure_aim_line() -> Node2D:
	if _aim_line != null and is_instance_valid(_aim_line):
		return _aim_line
	_aim_line = AIM_LINE.new()
	_aim_line.name = "AimLine"
	add_child(_aim_line)
	return _aim_line


## Shade-origin for Ambush. Caster-origin for every other armed spell.
## The float is the predicted connect text. It is not a resolved hit.
func _sync_aim_line() -> void:
	var line := _ensure_aim_line()
	if _hud == null or not _sim().has_method("aim_feel"):
		line.clear_aim()
		return
	var snap: Dictionary = _sim().snapshot()
	var spell_id := _hud.selected_spell()
	if _busy or _view_locked or spell_id == "" or bool(snap.get("match_over", false)) or CombatHUD.is_deployment_phase(snap):
		line.clear_aim()
		return
	if not _can_control_seat(int(snap.get("active_seat", 0))):
		line.clear_aim()
		return
	var spec: Dictionary = _sim().aim_feel(CombatHUD.kit_seat(snap), spell_id, _aim_hover)
	if not bool(spec.get("show", false)):
		line.clear_aim()
		return
	var from_cell: Vector2i = _as_cell(spec.get("from", Vector2i(-1, -1)))
	var to_cell: Vector2i = _as_cell(spec.get("to", Vector2i(-1, -1)))
	line.show_world(_cell_to_local(from_cell), _cell_to_local(to_cell), str(spec.get("float_text", "")), str(spec.get("kind", "")))


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
	var map_key := str(snap.get("map_id", snap.get("demo_map", "")))
	var dress := str(KOLISEO_ART.dress_for(map_key))
	for cell in tiles.keys():
		var rec: Dictionary = _board_data.get(cell, SNAPSHOT_TILES.default_cell())
		var tile := _tile_at(cell)
		tile.set_dress(dress)
		tile.apply_board_data(str(rec.get("terrain_type", "ground")), float(rec.get("elevation", 0.0)))
		tile.apply_koliseo_grade(map_key)
		tile.set_paint_props(_paint_props_at(paint, cell))
		tile.set_walk_blocked(SNAPSHOT_TILES.walk_block_kind(rec))
		tile.position = VISUAL_SORT.cell_to_local(cell, float(rec.get("elevation", 0.0)))
		tile.z_index = VISUAL_SORT.tile_z_index(cell, float(rec.get("elevation", 0.0)))
	var painted := PAINTED.bind($Tiles, PAINTED.room_id_for(map_key, _painted_room_letter()), tiles)
	if not painted:
		for cell in tiles.keys():
			if ARENA_LOOK.centerpiece_for(map_key, cell, _paint_props_at(paint, cell)) != null:
				# A big centrepiece (Brinewake wreck, volcano, tower) spills over the
				# row of tiles in front: draw it above them, still under the fighters
				# standing in that row. Painted occluders sort on their own.
				_tile_at(cell).z_index += VISUAL_SORT.TILE_Z_SCALE + 1
	_apply_edge_glow(map_key)
	_ensure_koliseo_life()
	if _koliseo_life != null:
		_koliseo_life.bind(map_key, _board_size)
	_ensure_arena_sky()
	_arena_sky.bind(map_key, _board_size)


## Koliseo leaves this empty. The dungeon fight overrides it with its room letter.
func _painted_room_letter() -> String:
	return ""


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


func _ensure_koliseo_life() -> void:
	if _koliseo_life != null and is_instance_valid(_koliseo_life):
		return
	_koliseo_life = KOLISEO_LIFE.new()
	_koliseo_life.name = "KoliseoLife"
	var units := get_node_or_null("Units")
	add_child(_koliseo_life)
	if units != null:
		move_child(_koliseo_life, units.get_index())


## Look-picture glow: a cell's edges that touch the arena's hot terrain
## (Slagcrown lava) light up on the rock side. View only.
func _apply_edge_glow(map_key: String) -> void:
	var style: Dictionary = ARENA_LOOK.style_for(map_key)
	var hot := str(style.get("edge_from", ""))
	var steps: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]
	for cell in tiles.keys():
		var tile := _tile_at(cell)
		var mask := 0
		if hot != "" and tile.terrain_type != hot:
			for i in 4:
				var rec: Dictionary = _board_data.get(cell + steps[i], {})
				if str(rec.get("terrain_type", "")) == hot:
					mask |= 1 << i
		tile.set_edge_glow(mask)


## Sky and island slab (view only). Sits first so every tile paints over it.
func _ensure_arena_sky() -> void:
	if _arena_sky != null and is_instance_valid(_arena_sky):
		return
	_arena_sky = ARENA_SKY.new()
	_arena_sky.name = "ArenaSky"
	add_child(_arena_sky)
	move_child(_arena_sky, 0)


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


## Zoom the diamond into the play band. Cell size stays 64×32.
## Desktop stays the 960×720 fit. A phone keeps most of the iso diamond
## on screen and frames the active fighter. Middle-mouse can pan past the
## fit. A phone drag stays inside the board.
func _fit_board_camera(glide: bool = false) -> void:
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
	_board_px = Vector2(board_w, board_h)
	var mobile := TOUCH.use_mobile_pick()
	var viewport := Vector2(VIEW_W, VIEW_H)
	if mobile:
		viewport = get_viewport_rect().size
	var band := TOUCH.play_band_for(viewport, mobile)
	var zoom := TOUCH.player_board_zoom(board_w, board_h, viewport, mobile)
	_camera.zoom = Vector2(zoom, zoom)
	var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var room := TOUCH.pan_room(board_w, board_h, viewport, zoom, mobile)
	_pan_limit = room
	var look := center
	if mobile and _follow_local_fighter(_sim().snapshot()):
		var focus := _frame_focus_local()
		if focus.x < 1.0e8:
			look = TOUCH.focus_point(center, focus, room)
	var play_center := Vector2(viewport.x * 0.5, (band.x + band.y) * 0.5)
	if mobile:
		# Centre the diamond in the clear space between the menus.
		var clear := TOUCH.clear_band_for(viewport)
		play_center.y = (clear.x + clear.y) * 0.5
	var view_center := Vector2(viewport.x * 0.5, viewport.y * 0.5)
	var world_center := global_position + center
	var camera_world := world_center - (play_center - view_center) / zoom
	_fit_camera_pos = camera_world - global_position
	var goal := _fit_camera_pos + (look - center)
	var dx := clampf(goal.x - _fit_camera_pos.x, -_pan_limit.x, _pan_limit.x)
	var dy := clampf(goal.y - _fit_camera_pos.y, -_pan_limit.y, _pan_limit.y)
	goal = _fit_camera_pos + Vector2(dx, dy)
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	if glide and is_inside_tree() and not _touch_panning and not _panning:
		# Turn focus: glide to the fighter whose turn it is.
		_focus_tween = create_tween()
		_focus_tween.tween_property(_camera, "position", goal, FOCUS_GLIDE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_camera.position = goal
		_clamp_camera()


func _on_zoom_step(direction: int) -> void:
	TOUCH.nudge_player_zoom(direction)
	_fit_board_camera()


func _frame_focus_local() -> Vector2:
	if not _booted:
		return Vector2(1.0e9, 1.0e9)
	var actor := _active_unit(_sim().snapshot())
	if actor.is_empty():
		return Vector2(1.0e9, 1.0e9)
	var cell := _as_cell(actor.get("pos", Vector2i(-1, -1)))
	if not _in_bounds(cell):
		return Vector2(1.0e9, 1.0e9)
	return _cell_to_local(cell)


func _maybe_reframe(snap: Dictionary) -> void:
	if not TOUCH.use_mobile_pick():
		return
	if not _follow_local_fighter(snap):
		return
	var actor := _active_unit(snap)
	if actor.is_empty():
		return
	var cell := _as_cell(actor.get("pos", Vector2i(-1, -1)))
	if cell == _framed_cell:
		return
	_framed_cell = cell
	_fit_board_camera(true)


func _pan_while_watching(event: InputEvent) -> void:
	if TOUCH.is_touch_press(event):
		_touch_down = TOUCH.pointer_position(event)
		_touch_panning = false
	elif TOUCH.is_touch_release(event):
		_touch_panning = false
	elif event is InputEventScreenDrag and _touches.size() < 2:
		_pan_board_drag(event)


func _pan_board_drag(event: InputEvent) -> bool:
	if _camera == null or not (event is InputEventScreenDrag):
		return false
	var pos := TOUCH.pointer_position(event)
	if not _touch_panning:
		if not TOUCH.drag_is_pan(_touch_down, pos, _spell_armed()):
			return false
		_touch_panning = true
		_touch_commit_open = false
		_pan_origin = pos
		# The finger wins over a turn-focus glide in progress.
		if _focus_tween != null and _focus_tween.is_valid():
			_focus_tween.kill()
		return true
	var delta := pos - _pan_origin
	_pan_origin = pos
	_queue_pan(delta)
	get_viewport().set_input_as_handled()
	return true


func _follow_local_fighter(snap: Dictionary) -> bool:
	var local_seat := CombatHUD.snap_local_seat(snap)
	if local_seat < 0:
		return false
	return local_seat == CombatHUD.snap_active_seat(snap)


func _queue_pan(screen_delta: Vector2) -> void:
	if _camera == null:
		return
	var z := _camera.zoom.x
	if is_zero_approx(z):
		return
	_pan_pending -= screen_delta / z


func _apply_pending_pan() -> void:
	if _camera == null or _pan_pending == Vector2.ZERO:
		return
	_camera.position += _pan_pending
	_pan_pending = Vector2.ZERO
	_clamp_camera()


func _apply_wheel_zoom(direction: int) -> void:
	if _camera == null:
		return
	var mobile := TOUCH.use_mobile_pick()
	var view := get_viewport_rect().size if mobile else Vector2(VIEW_W, VIEW_H)
	TOUCH.nudge_player_zoom(direction)
	var z := TOUCH.player_board_zoom(_board_px.x, _board_px.y, view, mobile)
	_camera.zoom = Vector2(z, z)
	_pan_limit = TOUCH.pan_room(_board_px.x, _board_px.y, view, z, mobile)
	_clamp_camera()


func _clamp_camera() -> void:
	if _camera == null:
		return
	var delta := _camera.position - _fit_camera_pos
	delta.x = clampf(delta.x, -_pan_limit.x, _pan_limit.x)
	delta.y = clampf(delta.y, -_pan_limit.y, _pan_limit.y)
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
	# A failed read must not become the origin. (0, 0) is a real tile.
	return Vector2i(-1, -1)
