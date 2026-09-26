extends "res://board_view.gd"

## Mobile Stasis duel. Room A is one combat with the trash pack, then Room B
## is the boss. Boards are the Stasis-1 room schematics, not the Koliseo arenas.
## CombatSim stays the authority. Not for PC main.

var _ai_running: bool = false
var _cleared: bool = false
var _overlay_status: Label
var _continue_button: Button
var _exit_button: Button


func _ready() -> void:
	super()
	_build_overlay()
	_capture_exit()


func _boot() -> void:
	if not StasisCatalog.ready_to_fight():
		call_deferred("_back_to_hub")
		return
	CombatSim.reset_match(StasisCatalog.fight_config())
	_finish_boot()
	_sync_overlay(_sim().snapshot())


func _can_control_seat(seat: int) -> bool:
	return seat == StasisCatalog.PLAYER_SEAT


func _on_new_match() -> void:
	_back_to_hub()


func _process(delta: float) -> void:
	super._process(delta)
	if not _booted or _ai_running:
		return
	var snap: Dictionary = _sim().snapshot()
	if _busy or _view_locked:
		return
	if bool(snap.get("match_over", false)) or _cleared:
		return
	if int(snap.get("active_seat", 0)) == StasisCatalog.PLAYER_SEAT:
		return
	_ai_running = true
	_run_enemy_step()


func _refresh() -> void:
	super._refresh()
	if not _booted:
		return
	var snap: Dictionary = _sim().snapshot()
	var over := bool(snap.get("match_over", false))
	var player_turn := int(snap.get("active_seat", 0)) == StasisCatalog.PLAYER_SEAT
	if not over and not player_turn:
		_hud.set_locked(true)
	if _exit_button != null:
		_exit_button.disabled = false
		_exit_button.text = "Back to hub"
	_sync_overlay(snap)


func _run_enemy_step() -> void:
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var snap: Dictionary = _sim().snapshot()
	if _busy or _view_locked or bool(snap.get("match_over", false)) or int(snap.get("active_seat", 0)) == StasisCatalog.PLAYER_SEAT:
		_ai_running = false
		return
	var seat := int(snap.get("active_seat", StasisCatalog.ENEMY_SEAT))
	var actor := _unit_from_seat(snap, seat)
	var foe := _unit_from_seat(snap, StasisCatalog.PLAYER_SEAT)
	var actor_pos: Vector2i = actor.get("pos", Vector2i.ZERO)
	var foe_pos: Vector2i = foe.get("pos", Vector2i.ZERO)
	var intent: Dictionary = StasisAi.choose(_sim().legal_intents(seat), actor_pos, foe_pos)
	if str(intent.get("type", "")) == "end_turn":
		_busy = true
		_hud.clear_spell()
		var result: Dictionary = CombatSim.submit({"type": "end_turn", "seat": seat})
		if bool(result.get("ok", false)):
			await _present_turn_handoff(result)
		elif is_instance_valid(self):
			_busy = false
			_refresh()
		if not is_instance_valid(self):
			return
		_ai_running = false
		return
	await _submit(intent)
	if is_instance_valid(self):
		_ai_running = false


func _continue_run() -> void:
	var snap: Dictionary = _sim().snapshot()
	if not bool(snap.get("match_over", false)) or int(snap.get("winner_seat", -1)) != StasisCatalog.PLAYER_SEAT:
		return
	var player := _unit_from_seat(snap, StasisCatalog.PLAYER_SEAT)
	StasisCatalog.carry_player_hp(int(player.get("hp", 0)))
	if StasisCatalog.advance_after_win() == "cleared":
		_cleared = true
		_sync_overlay(snap)
		return
	_restart_fight()


func _restart_fight() -> void:
	_stop_flash_tweens()
	_stop_walk_tween()
	_settle_motions()
	_view_locked = false
	_pending_motion_sec = 0.0
	_queued_net = false
	_busy = false
	_ai_running = false
	_clock_expired_pending = false
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_hud.clear_spell()
	CombatSim.reset_match(StasisCatalog.fight_config())
	_rebuild_pawns()
	_refresh()
	_hydrate_turn_clock()


func _back_to_hub() -> void:
	_ai_running = false
	StasisCatalog.clear_run()
	get_tree().change_scene_to_file(MobileHub.MOBILE_HUB)


func _capture_exit() -> void:
	_exit_button = _find_button(_hud, "New Match")
	if _exit_button != null:
		_exit_button.text = "Back to hub"


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.name = "StasisChrome"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := Panel.new()
	panel.position = Vector2(248, 8)
	panel.size = Vector2(464, 132)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.07, 0.92)
	panel_style.border_color = Color(0.55, 0.66, 0.74)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)
	_overlay_status = Label.new()
	_overlay_status.position = Vector2(256, 14)
	_overlay_status.size = Vector2(448, 58)
	_overlay_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_status.add_theme_font_size_override("font_size", 16)
	_overlay_status.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	_overlay_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay_status)
	var back := Button.new()
	back.text = "Back to hub"
	back.position = Vector2(256, 76)
	back.size = Vector2(210, 56)
	back.custom_minimum_size = Vector2(200, 48)
	back.focus_mode = Control.FOCUS_ALL
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_back_to_hub)
	root.add_child(back)
	_continue_button = Button.new()
	_continue_button.text = "Next foe"
	_continue_button.position = Vector2(476, 76)
	_continue_button.size = Vector2(228, 56)
	_continue_button.custom_minimum_size = Vector2(200, 48)
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_continue_button.add_theme_font_size_override("font_size", 18)
	_continue_button.visible = false
	_continue_button.pressed.connect(_continue_run)
	root.add_child(_continue_button)


func _sync_overlay(snap: Dictionary) -> void:
	if _overlay_status == null:
		return
	if _cleared:
		_overlay_status.text = "%s cleared. Back to hub." % StasisCatalog.door_name()
		if _continue_button != null:
			_continue_button.visible = false
		return
	var banner := StasisCatalog.room_banner()
	var note := StasisCatalog.provisional_line()
	if bool(snap.get("match_over", false)):
		if int(snap.get("winner_seat", -1)) == StasisCatalog.PLAYER_SEAT:
			_overlay_status.text = "%s\nFoe down. %s" % [banner, note]
			if _continue_button != null:
				_continue_button.text = StasisCatalog.continue_caption()
				_continue_button.visible = true
		else:
			_overlay_status.text = "%s\nDefeated. Back to hub." % banner
			if _continue_button != null:
				_continue_button.visible = false
		return
	if _continue_button != null:
		_continue_button.visible = false
	_overlay_status.text = "%s\n%s" % [banner, note]


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
