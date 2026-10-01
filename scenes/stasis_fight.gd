extends "res://board_view.gd"

## Mobile Stasis duel. Room A is one combat with the trash pack, then Room B
## is the boss. Boards are the Stasis-1 room schematics, not the Koliseo arenas.
## CombatSim stays the authority. Not for PC main.

const HeroAi := preload("res://backend/hero_ai.gd")

var _ai_running: bool = false
var _cleared: bool = false
var _chest: Dictionary = {}
var _overlay_status: Label
var _continue_button: Button
var _exit_button: Button
var _overlay_panel: Panel
var _overlay_back: Button
var _tonic_button: Button
var _tonic_note: String = ""


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
	var intent: Dictionary
	if _is_hero(actor):
		# Party seat filled by AI (Mauro 1 Oct 2026: "Fill with AI").
		intent = HeroAi.plan(_sim(), seat)
	elif not actor.get("foe_kit", []).is_empty():
		intent = StasisAi.plan(_sim(), seat)
	else:
		intent = StasisAi.choose(_sim().legal_intents(seat), actor_pos, foe_pos)
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
		_chest = open_chest()
		_sync_overlay(snap)
		show_result(stasis_result(player, _chest, true, _run_seconds(), _result_portrait))
		return
	_restart_fight()


## Room Tonic window: Room A won, Room B not loaded yet.
static func in_intermission(snap: Dictionary) -> bool:
	return StasisCatalog.room == "a" and bool(snap.get("match_over", false)) and int(snap.get("winner_seat", -1)) == StasisCatalog.PLAYER_SEAT


## Drink one Room Tonic: heal floor(30% max HP), never over max. A full-HP
## champion keeps the tonic. The healed HP carries into Room B.
func drink_tonic() -> Dictionary:
	var snap: Dictionary = _sim().snapshot()
	if not in_intermission(snap):
		return {"ok": false, "reason": "not_intermission"}
	var wallet := KoliseoWallet.load_saved()
	if wallet.tonics <= 0:
		return {"ok": false, "reason": "no_tonic"}
	var healed := CombatSim.intermission_heal(StasisCatalog.PLAYER_SEAT, KoliseoWallet.TONIC_HEAL_PCT)
	if healed <= 0:
		_tonic_note = "Already at full health."
		_sync_overlay(_sim().snapshot())
		return {"ok": false, "reason": "full"}
	wallet.use_tonic()
	wallet.save()
	_tonic_note = "Room Tonic: +%d." % healed
	_refresh()
	return {"ok": true, "reason": "", "healed": healed, "tonics": wallet.tonics}


## The Still the player carried into this fight is destroyed when it ends.
static func consume_still(snap: Dictionary) -> String:
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) != StasisCatalog.PLAYER_SEAT:
			continue
		var used := str(unit.get("still", ""))
		if used == "":
			return ""
		var vault := StillVault.load_saved()
		if vault.socket == used:
			vault.consume()
			vault.save()
		return used
	return ""


## Stasis ends a fight room by room: count turns and beaten foes; a defeat
## opens the result window at once, a win waits for the door to clear.
func _on_match_result(snap: Dictionary, _secs: int) -> void:
	consume_still(snap)
	StasisCatalog.run_turns += int(snap.get("turn_index", 0))
	for unit in snap.get("units", []):
		if not _is_hero(unit):
			StasisCatalog.run_foes.append((unit as Dictionary).duplicate(true))
	if int(snap.get("winner_seat", -1)) == StasisCatalog.PLAYER_SEAT:
		return
	if not is_inside_tree():
		return
	var player := _unit_from_seat(snap, StasisCatalog.PLAYER_SEAT)
	get_tree().create_timer(RESULT_DELAY).timeout.connect(func() -> void:
		if is_inside_tree():
			show_result(stasis_result(player, {}, false, _run_seconds(), _result_portrait)))


## Foes use their whole package portrait (the head crop is a sliver on
## the result row); the player keeps the class head.
func _result_portrait(unit: Dictionary) -> Texture2D:
	var art := str(unit.get("stasis_sprite", ""))
	if art != "" and ResourceLoader.exists(art):
		return load(art) as Texture2D
	return _portrait_of(unit)


func _run_seconds() -> int:
	if StasisCatalog.run_started_msec <= 0:
		return 0
	return int((Time.get_ticks_msec() - StasisCatalog.run_started_msec) / 1000)


static func stasis_result(player: Dictionary, chest: Dictionary, victory: bool, secs: int, portrait: Callable = Callable()) -> Dictionary:
	var you := {
		"name": str(player.get("name", "You")),
		"hp": int(player.get("hp", 0)),
		"max_hp": int(player.get("max_hp", 80)),
		"portrait": portrait.call(player) if portrait.is_valid() and not player.is_empty() else null,
		"you": true,
		"loot": [],
	}
	if chest.has("xp"):
		you["xp"] = int(chest["xp"])
		you["level"] = int(chest.get("level", 1))
		you["levels_gained"] = int(chest.get("levels_gained", 0))
	for frag in chest.get("fragments", []):
		you["loot"].append({"kind": "fragment", "still": str(frag), "count": 1})
	for it in chest.get("items", []):
		you["loot"].append({"kind": "gear", "item_id": str(it.get("item_id", "")), "plus": int(it.get("plus", 0)), "count": 1, "class_id": StasisCatalog.class_id})
	var foes: Array = []
	for unit in StasisCatalog.run_foes:
		foes.append({
			"name": str(unit.get("name", "")),
			"hp": int(unit.get("hp", 0)),
			"max_hp": int(unit.get("max_hp", 1)),
			"portrait": portrait.call(unit) if portrait.is_valid() else null,
			"you": false,
			"loot": [],
		})
	var note := ""
	if victory:
		note = chest_line(chest)
	return {
		"title": "%s %s — combat result" % [StasisCatalog.door_name(), StasisCatalog.star_label()],
		"outcome": "Victory" if victory else "Defeat",
		"victory": victory,
		"duration_sec": secs,
		"turns": StasisCatalog.run_turns,
		"winners": [you] if victory else foes,
		"losers": foes if victory else [you],
		"note": note,
	}


## Stasis 1 clear: one loot roll, 5 per UTC day across all doors (GearBag).
func open_chest() -> Dictionary:
	var bag := GearBag.load_saved()
	var loot := bag.record_stasis_clear(int(Time.get_unix_time_from_system()), StasisCatalog.star)
	bag.save()
	# XII Still fragments (Mauro, 29 Sep): only a loot-paying chest rolls them.
	if bool(loot.get("chest", false)):
		var vault := StillVault.load_saved()
		loot["fragments"] = vault.roll_chest(StasisCatalog.star)
		vault.save()
	# XP: 60 × star with a chest, 20 for a clear past the daily 5.
	var hero := HeroProgress.load_saved()
	var gained := hero.add_xp(StasisCatalog.class_id, HeroProgress.stasis_xp(StasisCatalog.star, bool(loot.get("chest", false))))
	hero.save()
	loot["xp"] = int(gained["xp"])
	loot["level"] = int(gained["level"])
	loot["levels_gained"] = int(gained["levels_gained"])
	return loot


static func chest_line(loot: Dictionary) -> String:
	if loot.is_empty():
		return "Back to hub."
	if not bool(loot.get("chest", false)):
		return "Chest empty — 5 loot clears used today."
	var names: Array[String] = []
	for it in loot.get("items", []):
		names.append(GearBag.item_label(it))
	for frag in loot.get("fragments", []):
		names.append("%s fragment" % StillVault.display_name(str(frag)))
	return "Chest: %s. Wear it in Gear." % ", ".join(names)


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
	# Leaving mid-fight (surrender) still destroys the Still that fought.
	consume_still(_sim().snapshot())
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
	_overlay_panel = panel
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
	_overlay_back = back
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
	_tonic_button = Button.new()
	_tonic_button.name = "DrinkTonic"
	_tonic_button.position = Vector2(256, 146)
	_tonic_button.size = Vector2(448, 52)
	_tonic_button.custom_minimum_size = Vector2(300, 48)
	_tonic_button.focus_mode = Control.FOCUS_ALL
	_tonic_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tonic_button.add_theme_font_size_override("font_size", 18)
	if ResourceLoader.exists(KoliseoShop.TONIC_ICON):
		_tonic_button.icon = load(KoliseoShop.TONIC_ICON)
		_tonic_button.add_theme_constant_override("icon_max_width", 36)
	_tonic_button.visible = false
	_tonic_button.pressed.connect(drink_tonic)
	root.add_child(_tonic_button)


## During a fight the door banner is a slim ribbon under the top HUD row, so
## it never hides the turn strip, AP / MP or the timer (the HUD keeps its own
## Back to hub). After the fight it grows into the full panel with the buttons.
## Monster turns: no "X's turn" box over the board (Dofus lights the
## timeline instead); the player's own turn keeps the banner.
## Stasis: the player always sees their own (Invisible) hero.
func _viewer_sees_seat(seat: int, snap: Dictionary) -> bool:
	# The player sees their own hero and every party member.
	return seat == StasisCatalog.PLAYER_SEAT or _is_hero(_unit_from_seat(snap, seat))


## A party hero (team 0). Solo runs: only the player's seat.
static func _is_hero(unit: Dictionary) -> bool:
	if unit.is_empty():
		return false
	return int(unit.get("team", 0 if int(unit.get("seat", -1)) == StasisCatalog.PLAYER_SEAT else 1)) == 0


func _quiet_handoff(seat: int) -> bool:
	return seat != StasisCatalog.PLAYER_SEAT


func _shows_turn_chrome(seat: int) -> bool:
	return seat == StasisCatalog.PLAYER_SEAT


func _layout_overlay(fighting: bool) -> void:
	if _overlay_panel == null:
		return
	if fighting:
		_overlay_panel.position = Vector2(248, 142)
		_overlay_panel.size = Vector2(464, 32)
		_overlay_status.position = Vector2(256, 142)
		_overlay_status.size = Vector2(448, 32)
		_overlay_status.add_theme_font_size_override("font_size", 14)
		if _overlay_back != null:
			_overlay_back.visible = false
	else:
		_overlay_panel.position = Vector2(248, 142)
		_overlay_panel.size = Vector2(464, 132)
		_overlay_status.position = Vector2(256, 148)
		_overlay_status.size = Vector2(448, 58)
		_overlay_status.add_theme_font_size_override("font_size", 16)
		if _overlay_back != null:
			_overlay_back.visible = true
			_overlay_back.position = Vector2(256, 210)
		if _continue_button != null:
			_continue_button.position = Vector2(476, 210)
		if _tonic_button != null:
			_tonic_button.position = Vector2(256, 280)


func _sync_overlay(snap: Dictionary) -> void:
	if _overlay_status == null:
		return
	_layout_overlay(not _cleared and not bool(snap.get("match_over", false)))
	_sync_tonic(snap)
	if _cleared:
		_overlay_status.text = "%s cleared. %s" % [StasisCatalog.door_name(), chest_line(_chest)]
		if _continue_button != null:
			_continue_button.visible = false
		return
	var banner := StasisCatalog.room_banner()
	# Playtest copy. The room banner and the continue buttons stay.
	# The provisional sentence is a dev overlay and stays off for APK cuts.
	var note := StasisCatalog.provisional_line() if DebugChrome.overlays_enabled() else ""
	if bool(snap.get("match_over", false)):
		if int(snap.get("winner_seat", -1)) == StasisCatalog.PLAYER_SEAT:
			var down := "Foe down."
			if _tonic_note != "" and in_intermission(snap):
				down = "%s %s" % [down, _tonic_note]
			if note != "":
				down = "%s %s" % [down, note]
			_overlay_status.text = "%s\n%s" % [banner, down]
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
	var ribbon := StasisCatalog.room_ribbon()
	_overlay_status.text = ribbon if note == "" else "%s\n%s" % [ribbon, note]


func _sync_tonic(snap: Dictionary) -> void:
	if _tonic_button == null:
		return
	var open := not _cleared and in_intermission(snap)
	if not open:
		_tonic_note = ""
		_tonic_button.visible = false
		return
	var have := KoliseoWallet.load_saved().tonics
	var player := _unit_from_seat(snap, StasisCatalog.PLAYER_SEAT)
	var full := int(player.get("hp", 0)) >= int(player.get("max_hp", 0))
	_tonic_button.visible = true
	_tonic_button.text = "Drink Room Tonic (%d/%d)" % [have, KoliseoWallet.TONIC_CARRY]
	_tonic_button.disabled = have <= 0 or full
	_tonic_button.tooltip_text = "Heal 30% of max HP before Room B. Buy them in the hub Shop (1 coin)." if have > 0 else "No Room Tonics — buy them in the hub Shop (1 coin)."


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
