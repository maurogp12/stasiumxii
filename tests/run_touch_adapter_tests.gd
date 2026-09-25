extends SceneTree

## Touch adapters for the mobile-branch duel. Helpers are pure. HUD hit
## targets are checked after the combat chrome builds. CombatSim is not retuned.
## Run: godot --headless --path . -s res://tests/run_touch_adapter_tests.gd

const TOUCH := preload("res://ui/touch_adapter.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Touch adapter tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_hit_floor_and_play_band()
	_test_board_gestures()
	_test_hud_targets_and_tooltip_tap()
	_test_sources_keep_desktop_and_hub()


func _test_hit_floor_and_play_band() -> void:
	eq(TOUCH.HIT_FLOOR, 48, "hit floor is 48px")
	eq(TOUCH.meets_hit_floor(Vector2(48, 48)), true, "48px square meets the floor")
	eq(TOUCH.meets_hit_floor(Vector2(72, 47)), false, "a 47px side misses the floor")
	eq(TOUCH.meets_hit_floor(TOUCH.FACE_BUTTON_SIZE), true, "face buttons meet the floor")
	eq(TOUCH.FACE_BUTTON_SIZE, Vector2(48, 48), "face cross stays at the 48px floor")
	eq(TOUCH.meets_preferred_height(TOUCH.WALK_BUTTON_SIZE), true, "Walk is in the preferred band")
	eq(TOUCH.meets_preferred_height(TOUCH.SPELL_BUTTON_SIZE), true, "spell buttons are in the preferred band")
	eq(TOUCH.meets_preferred_height(TOUCH.END_TURN_BUTTON_SIZE), true, "End Turn is in the preferred band")
	eq(TOUCH.ACTION_BUTTON_HEIGHT, 72, "primary actions use the 72px target")
	eq(TOUCH.WALK_BUTTON_SIZE.y, 72, "Walk height is 72")
	eq(TOUCH.SPELL_BUTTON_SIZE, Vector2(148, 72), "spell hosts stay wide enough to read and 72 tall")
	eq(TOUCH.END_TURN_BUTTON_SIZE.x >= 100, true, "End Turn keeps a readable width")
	eq(TOUCH.CELL_PICK_RADIUS, 22.0, "board diamond pick radius is unchanged")
	eq(TOUCH.play_band_fits_canvas(), true, "play band sits inside the 960×720 canvas")
	eq(TOUCH.VIEW_W, 960.0, "canvas width stays 960")
	eq(TOUCH.VIEW_H, 720.0, "canvas height stays 720")
	eq(TOUCH.PLAY_BOTTOM < TOUCH.VIEW_H, true, "board band ends above the bottom of the window")
	eq(TOUCH.HUD_BOTTOM_OFFSET < 0.0, true, "combat chrome anchors to the bottom edge")


func _test_board_gestures() -> void:
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	left.device = 0
	eq(TOUCH.board_gesture(left), TOUCH.COMMIT, "mouse left press commits a cell")
	var emulated := InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = TOUCH.EMULATED_DEVICE_ID
	eq(TOUCH.is_emulated_mouse(emulated), true, "device -1 is emulated mouse")
	eq(TOUCH.board_gesture(emulated), TOUCH.IGNORE, "emulated mouse is not a second click")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.device = 0
	eq(TOUCH.board_gesture(right), TOUCH.FACE, "right-click still faces")
	var motion := InputEventMouseMotion.new()
	motion.device = 0
	eq(TOUCH.board_gesture(motion), TOUCH.AIM, "mouse motion still previews aim")
	var emulated_motion := InputEventMouseMotion.new()
	emulated_motion.device = TOUCH.EMULATED_DEVICE_ID
	eq(TOUCH.board_gesture(emulated_motion), TOUCH.IGNORE, "emulated motion does not double-preview")
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	middle.device = 0
	eq(TOUCH.board_gesture(middle), TOUCH.PAN, "middle mouse still pans")
	middle.pressed = false
	eq(TOUCH.board_gesture(middle), TOUCH.PAN_STOP, "middle release stops the pan")
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(120, 200)
	eq(TOUCH.board_gesture(press), TOUCH.AIM, "finger down previews aim instead of committing")
	eq(TOUCH.is_touch_press(press), true, "index 0 down is a touch press")
	eq(TOUCH.pointer_position(press), Vector2(120, 200), "touch position is the event position")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(140, 210)
	eq(TOUCH.board_gesture(drag), TOUCH.AIM, "finger drag keeps previewing aim")
	eq(TOUCH.is_touch_contact(drag), true, "drag counts as contact")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(140, 210)
	eq(TOUCH.board_gesture(release), TOUCH.COMMIT, "finger up commits the cell")
	eq(TOUCH.is_touch_release(release), true, "index 0 up is a touch release")
	var extra := InputEventScreenTouch.new()
	extra.pressed = true
	extra.index = 1
	eq(TOUCH.board_gesture(extra), TOUCH.IGNORE, "a second finger does not commit")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	eq(TOUCH.board_gesture(key), TOUCH.IGNORE, "keys are not board taps")


func _test_hud_targets_and_tooltip_tap() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	sim.reset_match({"seed": 1, "skip_deploy": true})
	var hud := CombatHUD.new()
	hud._build()
	hud.set_preview_source(sim)
	hud.render(sim.snapshot(), sim.legal_intents(0))
	for dir in ["N", "E", "S", "W"]:
		var face: Button = hud._face_buttons[dir]
		eq(TOUCH.meets_hit_floor(face.custom_minimum_size), true, "Face %s is at least 48px" % dir)
		eq(face.custom_minimum_size, TOUCH.FACE_BUTTON_SIZE, "Face %s uses the adapter size" % dir)
	eq(TOUCH.meets_hit_floor(hud._walk_button.custom_minimum_size), true, "Walk meets the floor")
	eq(hud._walk_button.custom_minimum_size.y, 72, "Walk is 72px tall")
	eq(TOUCH.meets_hit_floor(hud._end_turn_button.custom_minimum_size), true, "End Turn meets the floor")
	eq(hud._end_turn_button.custom_minimum_size.y, 72, "End Turn is 72px tall")
	eq(hud._new_match_button.custom_minimum_size.y, 72, "New Match is 72px tall")
	eq(hud._ready_p1_button.custom_minimum_size.y, 72, "Ready P1 is 72px tall")
	eq(hud._ready_p2_button.custom_minimum_size.y, 72, "Ready P2 is 72px tall")
	eq(hud._action_bar.custom_minimum_size.y >= 72, true, "action bar still has room to wrap")
	truthy(hud._spell_buttons.has(SpellKits.MARK_SHOT), "Kestrel still offers Mark Shot")
	for spell_id in hud._spell_hosts.keys():
		var host: Control = hud._spell_hosts[spell_id]
		eq(TOUCH.meets_hit_floor(host.custom_minimum_size), true, "spell %s meets the floor" % spell_id)
		eq(host.custom_minimum_size.y, 72, "spell %s is 72px tall" % spell_id)
		eq(host.custom_minimum_size.x >= 140, true, "spell %s keeps a readable width" % spell_id)
	eq(hud.tooltip_visible(), false, "card starts hidden")
	eq(hud.tooltip_pinned(), false, "card starts unpinned")
	hud._on_spell_hover(SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), true, "hover still shows the card")
	hud._on_spell_unhover()
	eq(hud.tooltip_visible(), false, "mouse exit still hides an unpinned card")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2(8, 8)
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), true, "a finger press shows the card without hover")
	eq(hud.tooltip_pinned(), true, "the touch card stays pinned")
	eq(hud.tooltip_caption(), SpellTooltip.card_text(hud.preview_for_spell(SpellKits.MARK_SHOT)), "touch card is still preview_cast")
	hud._on_spell_unhover()
	eq(hud.tooltip_visible(), true, "synthetic mouse exit does not dismiss a touch card")
	hud.dismiss_pinned_tooltip()
	eq(hud.tooltip_visible(), false, "a board tap dismisses the pinned card")
	eq(hud.tooltip_pinned(), false, "dismiss clears the pin")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.device = 0
	hud._on_spell_host_input(mouse, SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), false, "a short mouse press still waits for hover or long-press")
	mouse.device = TOUCH.EMULATED_DEVICE_ID
	hud._on_spell_host_input(mouse, SpellKits.MARK_SHOT)
	eq(hud.tooltip_pinned(), false, "emulated mouse does not pin a second card")
	hud.free()
	sim.free()


func _test_sources_keep_desktop_and_hub() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var select := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	var hub := FileAccess.get_file_as_string("res://scenes/mobile_hub.gd")
	var sim := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(view.contains("res://ui/touch_adapter.gd"), "board routes pointers through the touch adapter")
	truthy(view.contains("MOUSE_BUTTON_RIGHT"), "right-click face source stays")
	truthy(view.contains("_face_toward"), "right-click still calls face")
	truthy(view.contains("func _handle_left_click"), "cell commit still goes through the left-click handler")
	truthy(hud.contains("mouse_entered"), "spell hover remains for desktop")
	truthy(hud.contains("text = \"Walk\""), "Walk button remains")
	truthy(hud.contains("text = \"End Turn\""), "End Turn button remains")
	truthy(select.contains("text = \"Back to hub\""), "class select keeps Back to hub")
	truthy(hub.contains("DOOR_MIN_HEIGHT := 72"), "hub doors stay fat")
	eq(sim.contains("TouchAdapter"), false, "CombatSim is not part of the touch adapter")
	eq(sim.contains("touch_adapter"), false, "CombatSim does not reference the adapter")
	truthy(project.contains("window/size/viewport_width=960"), "viewport width stays 960")
	truthy(project.contains("window/size/viewport_height=720"), "viewport height stays 720")
	truthy(project.contains('window/stretch/mode="canvas_items"'), "stretch mode stays canvas_items")
	truthy(project.contains('window/stretch/aspect="expand"'), "stretch aspect stays expand")
	var unhandled_idx := view.find("func _unhandled_input")
	var select_idx := view.find("func select_tile")
	var unhandled := view.substr(unhandled_idx, select_idx - unhandled_idx)
	eq(unhandled.find("ui_cancel") < unhandled.find("_face_toward"), true, "Esc still does not steal right-click face")


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s  (got %s)" % [msg, value])
	else:
		_passed += 1
