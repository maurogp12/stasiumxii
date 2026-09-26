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
	_test_pawn_body_cast_pick()
	_test_mobile_target_pick()
	_test_ability_cluster_layout()
	_test_ability_icons()
	_test_hud_targets_and_tooltip_tap()
	_test_hold_card_hides_when_drag_leaves()
	_test_sources_keep_desktop_and_hub()


func _test_hit_floor_and_play_band() -> void:
	eq(TOUCH.HIT_FLOOR, 48, "hit floor is 48px")
	eq(TOUCH.meets_hit_floor(Vector2(48, 48)), true, "48px square meets the floor")
	eq(TOUCH.meets_hit_floor(Vector2(72, 47)), false, "a 47px side misses the floor")
	eq(TOUCH.meets_hit_floor(TOUCH.FACE_BUTTON_SIZE), true, "face buttons meet the floor")
	eq(TOUCH.FACE_BUTTON_SIZE, Vector2(48, 48), "face cross stays at the 48px floor")
	eq(TOUCH.meets_preferred_height(TOUCH.WALK_BUTTON_SIZE), true, "Walk is in the preferred band")
	eq(TOUCH.meets_preferred_height(TOUCH.ABILITY_BUTTON_SIZE), true, "ability circles are in the preferred band")
	eq(TOUCH.meets_preferred_height(TOUCH.PRIMARY_BUTTON_SIZE), true, "primary attack circle is in the preferred band")
	eq(TOUCH.meets_preferred_height(TOUCH.END_TURN_BUTTON_SIZE), true, "End Turn is in the preferred band")
	eq(TOUCH.ACTION_BUTTON_HEIGHT, 72, "primary actions use the 72px target")
	eq(TOUCH.WALK_BUTTON_SIZE.y, 72, "Walk height is 72")
	eq(TOUCH.ABILITY_BUTTON_SIZE, Vector2(72, 72), "arc abilities are 72px circles")
	eq(TOUCH.PRIMARY_BUTTON_SIZE.x >= 96, true, "primary attack circle is the thumb rest")
	eq(TOUCH.PRIMARY_BUTTON_SIZE.y, TOUCH.PRIMARY_BUTTON_SIZE.x, "primary attack circle is square")
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


func _test_pawn_body_cast_pick() -> void:
	# Opening skip_deploy: Kestrel (1,1), Ironjaw (6,6), Chebyshev 5.
	# The sprite center is 72px above the feet. The 22px diamond pick lands on
	# the empty tile behind the fighter. A unit-targeted cast must use the body.
	var sort := preload("res://board/visual_sort.gd")
	var tiles := {}
	for y in 15:
		for x in 15:
			var cell := Vector2i(x, y)
			tiles[cell] = sort.cell_to_local(cell, 0.0)
	var foe := Vector2i(6, 6)
	var foe_origin: Vector2 = tiles[foe]
	var chest := foe_origin + Vector2(0, -72)
	var pawns := [{"cell": foe, "origin": foe_origin, "sort": foe.x + foe.y}]
	var behind := TOUCH.pick_board_cell(chest, tiles, pawns, false)
	eq(behind, Vector2i(4, 4), "diamond pick of the sprite chest is the empty tile behind")
	eq(TOUCH.hits_pawn_body(chest, foe_origin), true, "sprite chest hits the pawn body")
	var resolved := TOUCH.pick_board_cell(chest, tiles, pawns, true)
	eq(resolved, foe, "unit-targeted pick of the sprite chest is the living foe")
	var neighbor := Vector2i(7, 6)
	eq(TOUCH.hits_pawn_body(tiles[neighbor], foe_origin), false, "neighbor diamond center is outside the body")
	eq(TOUCH.pick_board_cell(tiles[neighbor], tiles, pawns, true), neighbor, "empty neighbor diamond stays a tile pick")
	eq(TOUCH.CELL_PICK_RADIUS, 22.0, "fix does not widen the diamond pick")
	var self_origin: Vector2 = tiles[Vector2i(1, 1)]
	var self_chest := self_origin + Vector2(0, -72)
	var both := pawns.duplicate()
	both.append({"cell": Vector2i(1, 1), "origin": self_origin, "sort": 2})
	eq(TOUCH.pick_board_cell(self_chest, tiles, both, true), Vector2i(1, 1), "own sprite resolves to the caster cell")
	eq(TOUCH.spell_targets_unit(SpellKits.MARK_SHOT), true, "Mark Shot targets a unit")
	eq(TOUCH.spell_targets_unit(SpellKits.ADVANCE), false, "Advance stays an empty-tile pick")
	eq(TOUCH.spell_targets_unit(""), false, "walk mode does not prefer a pawn body")

	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	sim.reset_match({"seed": 1, "skip_deploy": true, "rolls": [1]})
	var missed: Dictionary = sim.submit({"type": "cast", "spell": SpellKits.MARK_SHOT, "to": behind})
	eq(missed.get("ok", true), false, "casting the diamond behind the foe is illegal")
	eq(str(missed.get("reason", "")), "no_target", "that illegal cast is no living unit")
	truthy(str(sim.snapshot().get("coach", "")).contains("needs a living unit"), "coach names the living-unit refund")
	eq(int(sim.snapshot()["units"][0]["ap"]), 6, "the refund gives the AP back")
	var landed: Dictionary = sim.submit({"type": "cast", "spell": SpellKits.MARK_SHOT, "to": resolved})
	eq(landed.get("ok", false), true, "Mark Shot on the living foe in range resolves")
	eq(int(sim.snapshot()["units"][0]["ap"]), 4, "Mark Shot spends its 2 AP")
	sim.free()

	var far: Node = sim_script.new()
	far.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"positions": [Vector2i(0, 0), Vector2i(8, 8)],
	})
	var far_cell := Vector2i(8, 8)
	var far_pick := TOUCH.pick_board_cell(sort.cell_to_local(far_cell, 0.0) + Vector2(0, -72), _tile_map(sort), [{"cell": far_cell, "origin": sort.cell_to_local(far_cell, 0.0), "sort": 16}], true)
	eq(far_pick, far_cell, "a far sprite still resolves to that unit")
	var out_of_range: Dictionary = far.submit({"type": "cast", "spell": SpellKits.MARK_SHOT, "to": far_pick})
	eq(out_of_range.get("ok", true), false, "a living unit outside range still rejects")
	eq(str(out_of_range.get("reason", "")), "out_of_range", "range reject stays the locked range rule")
	eq(int(far.snapshot()["units"][0]["ap"]), 6, "out-of-range Mark Shot refunds AP")
	var self_cast: Dictionary = far.submit({"type": "cast", "spell": SpellKits.MARK_SHOT, "to": Vector2i(0, 0)})
	eq(self_cast.get("ok", true), false, "casting Mark Shot on yourself still rejects")
	eq(str(self_cast.get("reason", "")), "out_of_range", "self cell is inside Mark Shot's minimum range")
	eq(int(far.snapshot()["units"][1]["hp"]), 80, "a rejected self cast does not hit the foe")
	far.free()


func _test_mobile_target_pick() -> void:
	# Finger padding is opt-in. Desktop calls stay on the 22px circle and the 34px body.
	eq(TOUCH.PAWN_BODY_RADIUS, 34.0, "desktop body radius stays 34")
	eq(TOUCH.MOBILE_PAWN_BODY_RADIUS > TOUCH.PAWN_BODY_RADIUS, true, "a finger uses a fatter body")
	eq(TOUCH.MOBILE_CELL_PICK_RADIUS > TOUCH.CELL_PICK_RADIUS, true, "off-board finger pad is wider than 22px")
	eq(TOUCH.use_mobile_pick(), false, "headless does not force the finger pick")
	var sort := preload("res://board/visual_sort.gd")
	var tiles := _tile_map(sort)
	var foe := Vector2i(6, 6)
	var foe_origin: Vector2 = tiles[foe]
	var pawns := [{"cell": foe, "origin": foe_origin, "sort": foe.x + foe.y}]
	# Side of the painted diamond. The 22px circle gives this point to the east neighbor.
	var side := foe_origin + Vector2(22, 2)
	eq(TOUCH.diamond_metric(side, foe_origin) <= 1.0, true, "the side point sits on the painted diamond")
	eq(TOUCH.pick_board_cell(side, tiles, pawns, false), Vector2i(7, 6), "desktop still gives the diamond side to the neighbor")
	eq(TOUCH.pick_board_cell(side, tiles, pawns, false, true), foe, "a finger on the painted diamond selects that tile")
	var beside := foe_origin + Vector2(48, -72)
	eq(TOUCH.hits_pawn_body(beside, foe_origin), false, "a tap beside the chest misses the desktop body")
	eq(TOUCH.hits_pawn_body(beside, foe_origin, true), true, "a tap beside the chest hits the finger body")
	eq(TOUCH.pick_board_cell(beside, tiles, pawns, true) == foe, false, "desktop unit pick of that slop is not the foe")
	eq(TOUCH.pick_board_cell(beside, tiles, pawns, true, true), foe, "finger unit pick of that slop is the foe")
	var east: Vector2 = tiles[Vector2i(7, 6)]
	eq(TOUCH.hits_pawn_body(east, foe_origin, true), false, "the east neighbor diamond stays outside the finger body")
	eq(TOUCH.pick_board_cell(east, tiles, pawns, true, true), Vector2i(7, 6), "finger pick of the east diamond stays that tile")
	var north: Vector2 = tiles[Vector2i(6, 5)]
	eq(TOUCH.hits_pawn_body(north, foe_origin), false, "the north diamond stays outside the desktop body")
	eq(TOUCH.hits_pawn_body(north, foe_origin, true), true, "the figure covers the north diamond, so a finger cast hits the unit")
	eq(TOUCH.pick_board_cell(north, tiles, pawns, false, true), Vector2i(6, 5), "a walk tap on the north diamond stays that tile")
	var outside := Vector2(0, -22)
	eq(TOUCH.pick_board_cell(outside, tiles, [], false).x < 0, true, "desktop misses a tap 22px past the corner")
	eq(TOUCH.pick_board_cell(outside, tiles, [], false, true), Vector2i(0, 0), "a finger just off the corner still selects the edge tile")
	var desktop_zoom := TOUCH.board_zoom(960.0, 500.0, Vector2(960, 720), false)
	var tall_ignored := TOUCH.board_zoom(960.0, 500.0, Vector2(960, 1400), false)
	near(desktop_zoom, 0.64, "15×15 desktop zoom stays 0.64")
	near(tall_ignored, desktop_zoom, "desktop framing ignores a tall window")
	eq(TOUCH.play_band_for(Vector2(960, 1400), false), Vector2(TOUCH.PLAY_TOP, TOUCH.PLAY_BOTTOM), "desktop band stays 140..460")
	var portrait_band := TOUCH.play_band_for(Vector2(960, 1400), true)
	eq(portrait_band.x, TOUCH.PLAY_TOP, "portrait keeps the top chrome")
	eq(portrait_band.y, 1400.0 - (TOUCH.VIEW_H - TOUCH.PLAY_BOTTOM), "portrait keeps the bottom chrome reserve")
	var portrait := TOUCH.board_zoom(960.0, 500.0, Vector2(960, 1400), true)
	eq(portrait > desktop_zoom, true, "phone portrait frames the board larger")
	near(portrait, 928.0 / 960.0, "portrait zoom fills the width without cropping the diamond")
	eq(portrait <= TOUCH.MOBILE_BOARD_ZOOM_MAX, true, "portrait zoom stays inside the mobile cap")
	var pawn := Pawn.new()
	eq(pawn.target_marked, false, "a pawn starts unmarked")
	pawn.set_target_marked(true)
	eq(pawn.target_marked, true, "aiming a unit marks it")
	pawn.advance_target_pulse(0.2)
	pawn.set_target_marked(true)
	eq(pawn.target_marked, true, "a second mark does not clear the pulse")
	pawn.set_target_marked(false)
	eq(pawn.target_marked, false, "leaving the target clears the ring")
	pawn.free()

	var sim_script := load("res://backend/combat_sim.gd")
	var far: Node = sim_script.new()
	far.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"positions": [Vector2i(0, 0), Vector2i(8, 8)],
	})
	var far_cell := Vector2i(8, 8)
	var far_origin: Vector2 = sort.cell_to_local(far_cell, 0.0)
	var far_slop := far_origin + Vector2(48, -72)
	var far_pawns := [{"cell": far_cell, "origin": far_origin, "sort": 16}]
	eq(TOUCH.pick_board_cell(far_slop, _tile_map(sort), far_pawns, true) == far_cell, false, "desktop slop beside a far sprite is not that unit")
	var far_pick := TOUCH.pick_board_cell(far_slop, _tile_map(sort), far_pawns, true, true)
	eq(far_pick, far_cell, "finger slop beside a far sprite still resolves to that unit")
	var out_of_range: Dictionary = far.submit({"type": "cast", "spell": SpellKits.MARK_SHOT, "to": far_pick})
	eq(out_of_range.get("ok", true), false, "a fatter pick does not extend Mark Shot range")
	eq(str(out_of_range.get("reason", "")), "out_of_range", "the reject stays the locked range rule")
	eq(int(far.snapshot()["units"][0]["ap"]), 6, "the out-of-range finger pick refunds AP")
	far.free()


func _tile_map(sort) -> Dictionary:
	var tiles := {}
	for y in 15:
		for x in 15:
			var cell := Vector2i(x, y)
			tiles[cell] = sort.cell_to_local(cell, 0.0)
	return tiles


func _test_ability_cluster_layout() -> void:
	eq(TOUCH.primary_spell_id([SpellKits.MARK_SHOT, SpellKits.DETONATE]), SpellKits.MARK_SHOT, "Kestrel primary is Mark Shot")
	eq(TOUCH.primary_spell_id([SpellKits.ADVANCE, SpellKits.STRIKE, SpellKits.SHOULDER, SpellKits.CRUSH]), SpellKits.STRIKE, "Ironjaw primary is Strike")
	eq(TOUCH.primary_spell_id([SpellKits.MEND, SpellKits.PULSE_TAP]), SpellKits.MEND, "a kit with no enemy cast uses the first spell")
	var bounds := Rect2(Vector2.ZERO, TOUCH.CLUSTER_SIZE)
	for count in [1, 2, 3, 4]:
		var centers: Dictionary = TOUCH.cluster_centers(count)
		var primary: Vector2 = centers["primary"]
		var primary_rect := TOUCH.cluster_button_rect(primary, true)
		truthy(bounds.encloses(primary_rect), "primary circle stays inside the cluster for %d" % count)
		var arc: Array = centers["arc"]
		eq(arc.size(), count, "arc has one slot per other spell (%d)" % count)
		var prev := primary
		for i in arc.size():
			var center: Vector2 = arc[i]
			var rect := TOUCH.cluster_button_rect(center, false)
			truthy(bounds.encloses(rect), "ability %d stays inside the cluster" % i)
			eq(center.x < primary.x, true, "ability %d is left of the thumb button" % i)
			eq(center.y < primary.y, true, "ability %d is above the thumb button" % i)
			var gap := center.distance_to(primary)
			eq(gap + 0.5 >= TOUCH.PRIMARY_BUTTON_SIZE.x * 0.5 + TOUCH.ABILITY_BUTTON_SIZE.x * 0.5, true, "ability %d does not cover the thumb button" % i)
			if i > 0:
				eq(center.distance_to(prev) + 0.5 >= TOUCH.ABILITY_BUTTON_SIZE.x, true, "ability circles do not cover each other")
			prev = center
	eq(TOUCH.cluster_centers(0)["arc"].size(), 0, "a lone primary has no arc")


func _test_ability_icons() -> void:
	var ids := ["mark_shot", "detonate", "strike", "shoulder", "crush", "advance", "walk", "end_turn"]
	for spell_id in ids:
		var enabled_path := CombatHUD._ability_icon_path(spell_id, false)
		var disabled_path := CombatHUD._ability_icon_path(spell_id, true)
		eq(enabled_path, "res://art/ui/mobile/abilities/%s_icon.png" % spell_id, "%s enabled path" % spell_id)
		eq(disabled_path, "res://art/ui/mobile/abilities/%s_icon_disabled.png" % spell_id, "%s disabled path" % spell_id)
		truthy(FileAccess.file_exists(enabled_path), "%s enabled png is in the repo" % spell_id)
		truthy(FileAccess.file_exists(disabled_path), "%s disabled png is in the repo" % spell_id)
		truthy(ResourceLoader.exists(enabled_path), "%s enabled icon is a resource" % spell_id)
		truthy(ResourceLoader.exists(disabled_path), "%s disabled icon is a resource" % spell_id)
	eq(CombatHUD._ability_icon_path("mend", false), "res://art/ui/mobile/abilities/mend_icon.png", "future spells share the path contract")
	eq(ResourceLoader.exists(CombatHUD._ability_icon_path("mend", false)), false, "Mend has no stub yet")
	eq(FileAccess.file_exists(CombatHUD._ability_icon_path("bash", false)), false, "Bastion has no stub yet")

	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	sim.reset_match({"seed": 1, "skip_deploy": true})
	var hud := CombatHUD.new()
	hud._build()
	hud.set_preview_source(sim)
	hud.render(sim.snapshot(), sim.legal_intents(0))
	_assert_ability_chrome(hud, hud._spell_buttons[SpellKits.MARK_SHOT], SpellKits.MARK_SHOT)
	_assert_ability_chrome(hud, hud._spell_buttons[SpellKits.DETONATE], SpellKits.DETONATE)
	var mark: Button = hud._spell_buttons[SpellKits.MARK_SHOT]
	eq(mark.disabled, false, "opening Mark Shot stays a legal cast")
	_assert_shown_icon(hud, mark, SpellKits.MARK_SHOT, false)
	var detonate: Button = hud._spell_buttons[SpellKits.DETONATE]
	eq(detonate.disabled, true, "Detonate stays illegal at 0 Marks")
	_assert_shown_icon(hud, detonate, SpellKits.DETONATE, true)
	_assert_ability_chrome(hud, hud._walk_button, "walk")
	_assert_ability_chrome(hud, hud._end_turn_button, "end_turn")
	eq(hud._walk_button.disabled, false, "Walk is enabled on the opening turn")
	_assert_shown_icon(hud, hud._walk_button, "walk", false)
	eq(hud._end_turn_button.disabled, false, "End Turn is enabled on the opening turn")
	_assert_shown_icon(hud, hud._end_turn_button, "end_turn", false)
	eq(hud._new_match_button.text, "New Match", "New Match stays a text button")
	eq(hud._new_match_button.get_node_or_null("AbilityIcon"), null, "New Match does not take an ability icon")
	for dir in ["N", "E", "S", "W"]:
		var face: Button = hud._face_buttons[dir]
		eq(face.text, dir, "Face %s stays text" % dir)
		eq(face.get_node_or_null("AbilityIcon"), null, "Face %s has no ability icon" % dir)

	hud.set_locked(true)
	eq(hud._walk_button.disabled, true, "locked Walk is disabled")
	_assert_shown_icon(hud, hud._walk_button, "walk", true)
	eq(hud._end_turn_button.disabled, true, "locked End Turn is disabled")
	_assert_shown_icon(hud, hud._end_turn_button, "end_turn", true)
	hud.set_locked(false)
	hud.render(sim.snapshot(), sim.legal_intents(0))
	_assert_shown_icon(hud, hud._walk_button, "walk", false)

	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
	})
	sim.submit({"type": "end_turn"})
	hud.render(sim.snapshot(), sim.legal_intents(1))
	for spell_id in [SpellKits.STRIKE, SpellKits.SHOULDER, SpellKits.CRUSH, SpellKits.ADVANCE]:
		_assert_ability_chrome(hud, hud._spell_buttons[spell_id], spell_id)
	var strike: Button = hud._spell_buttons[SpellKits.STRIKE]
	eq(strike.disabled, false, "adjacent Strike is enabled")
	_assert_shown_icon(hud, strike, SpellKits.STRIKE, false)
	var crush: Button = hud._spell_buttons[SpellKits.CRUSH]
	eq(crush.disabled, true, "Crush stays disabled at 0 Impact")
	_assert_shown_icon(hud, crush, SpellKits.CRUSH, true)

	sim.reset_match({"seed": 1, "skip_deploy": true, "classes": ["mender", "bastion"]})
	hud.render(sim.snapshot(), sim.legal_intents(0))
	truthy(hud._spell_buttons.has(SpellKits.MEND), "Mender still offers Mend")
	for spell_id in hud._spell_buttons.keys():
		_assert_ability_chrome(hud, hud._spell_buttons[spell_id], str(spell_id))
		var button: Button = hud._spell_buttons[spell_id]
		var spell_name := str(SpellKits.spell(str(spell_id)).get("name", ""))
		truthy(spell_name != "" and button.text.contains(spell_name), "%s keeps its text label" % spell_id)
	eq(hud._new_match_button.text, "New Match", "New Match stays text on a kit without stubs")
	for dir in ["N", "E", "S", "W"]:
		eq((hud._face_buttons[dir] as Button).text, dir, "Face %s stays text on Mender" % dir)
	hud.free()
	sim.free()


func _assert_ability_chrome(hud: CombatHUD, button: Button, spell_id: String) -> void:
	var icon := button.get_node_or_null("AbilityIcon") as TextureRect
	var enabled_path := hud._ability_icon_path(spell_id, false)
	var loaded: Variant = load(enabled_path) if ResourceLoader.exists(enabled_path) else null
	if loaded is Texture2D:
		truthy(icon != null, "%s has an AbilityIcon" % spell_id)
		eq(icon.get_parent(), button, "%s icon is a child of the button" % spell_id)
		eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s icon does not steal taps" % spell_id)
		eq(icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "%s icon keeps aspect" % spell_id)
		eq(icon.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "%s icon fills the control rect" % spell_id)
		eq(button.text, "", "%s is icon-only when the stub loads" % spell_id)
		var use_disabled := button.disabled and ResourceLoader.exists(hud._ability_icon_path(spell_id, true))
		_assert_shown_icon(hud, button, spell_id, use_disabled)
		return
	if spell_id == "walk":
		eq(button.text, "Walk", "Walk stays text until its icon imports")
	elif spell_id == "end_turn":
		eq(button.text, "End Turn", "End Turn stays text until its icon imports")
	else:
		var spell_name := str(SpellKits.spell(spell_id).get("name", ""))
		truthy(spell_name != "" and button.text.contains(spell_name), "%s keeps its text label" % spell_id)
	if icon != null:
		eq(icon.visible, false, "%s hides a missing icon" % spell_id)
		eq(icon.texture, null, "%s does not invent art" % spell_id)


func _assert_shown_icon(hud: CombatHUD, button: Button, spell_id: String, disabled: bool) -> void:
	var expected := hud._ability_icon_path(spell_id, disabled)
	var loaded: Variant = load(expected)
	if not (loaded is Texture2D):
		return
	var icon := button.get_node_or_null("AbilityIcon") as TextureRect
	truthy(icon != null and icon.visible, "%s shows the %s icon" % [spell_id, "disabled" if disabled else "enabled"])
	eq(str(icon.texture.resource_path), expected, "%s texture path" % spell_id)
	eq(button.text, "", "%s label is clear while the icon shows" % spell_id)


func mark_host_primary(hud, spell_id: String) -> bool:
	var host: Control = hud._spell_hosts[spell_id]
	return bool(host.get_meta("cluster_primary", false))


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
	eq(bool(mark_host_primary(hud, SpellKits.MARK_SHOT)), true, "Kestrel thumb button is Mark Shot")
	var mark_host: Control = hud._spell_hosts[SpellKits.MARK_SHOT]
	eq(mark_host.get_parent(), hud._ability_cluster, "Mark Shot lives in the thumb cluster")
	eq(mark_host.custom_minimum_size, TOUCH.PRIMARY_BUTTON_SIZE, "Mark Shot uses the primary circle")
	var det_host: Control = hud._spell_hosts[SpellKits.DETONATE]
	eq(det_host.get_parent(), hud._ability_cluster, "Detonate lives in the arc")
	eq(det_host.custom_minimum_size, TOUCH.ABILITY_BUTTON_SIZE, "Detonate uses the 72px circle")
	eq(det_host.position.x < mark_host.position.x, true, "arc sits left of the thumb button")
	eq(det_host.position.y < mark_host.position.y, true, "arc sits above the thumb button")
	eq(hud._ability_cluster.anchor_left, 1.0, "cluster anchors to the right edge")
	eq(hud._ability_cluster.anchor_bottom, 1.0, "cluster anchors to the bottom edge")
	for spell_id in hud._spell_hosts.keys():
		var host: Control = hud._spell_hosts[spell_id]
		eq(TOUCH.meets_hit_floor(host.custom_minimum_size), true, "spell %s meets the floor" % spell_id)
		eq(host.custom_minimum_size.y >= 72, true, "spell %s is at least 72px" % spell_id)
		eq(host.get_parent(), hud._ability_cluster, "spell %s is not on the Walk row" % spell_id)
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
	eq(hud.tooltip_visible(), false, "a finger tap does not open the skill card")
	eq(hud.tooltip_pinned(), false, "a finger tap does not pin the card")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "a finger tap still arms the spell")
	truthy(hud._selected_label.text.contains("tap a cell"), "tap still shows the status line")
	hud._on_spell_hover(SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), false, "emulated hover during a tap does not open the card")
	hud._process(0.1)
	eq(hud.tooltip_visible(), false, "a short hold does not open the card")
	hud._on_spell_button_down(SpellKits.MARK_SHOT)
	hud._process(0.4)
	eq(hud.tooltip_visible(), true, "emulated button_down does not reset the hold")
	eq(hud.tooltip_pinned(), true, "the hold card stays up while the finger is down")
	eq(hud.tooltip_caption(), SpellTooltip.card_text(hud.preview_for_spell(SpellKits.MARK_SHOT)), "hold card is still preview_cast")
	hud._on_spell_unhover()
	eq(hud.tooltip_visible(), true, "synthetic mouse exit does not dismiss a hold card")
	hud.dismiss_pinned_tooltip()
	eq(hud.tooltip_visible(), false, "a board tap dismisses the pinned card")
	eq(hud.tooltip_pinned(), false, "dismiss clears the pin")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "dismissing the card leaves the spell armed")
	touch.pressed = false
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	hud._clear_press_lock(hud._press_release_token)
	eq(hud.tooltip_visible(), false, "releasing after a board dismiss keeps the card hidden")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "finger up keeps the armed spell")
	hud._on_spell_hover(SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), true, "desktop hover still works after the finger lifts")
	hud._on_spell_unhover()
	eq(hud.tooltip_visible(), false, "mouse exit still hides the hover card")
	touch.pressed = true
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	hud._process(SpellTooltip.LONG_PRESS_SEC)
	eq(hud.tooltip_visible(), true, "a second hold shows the card again")
	hud.select_walk()
	eq(hud.tooltip_visible(), false, "Walk dismisses the hold card")
	eq(hud.selected_spell(), "", "Walk still clears the armed spell")
	touch.pressed = true
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	hud._process(SpellTooltip.LONG_PRESS_SEC)
	eq(hud.tooltip_visible(), true, "hold after Walk shows the card")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "that hold still arms the spell")
	touch.pressed = false
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), false, "releasing the hold dismisses the card")
	eq(hud.tooltip_pinned(), false, "release clears the pin")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "release keeps the spell armed")
	hud._clear_press_lock(hud._press_release_token)
	touch.pressed = true
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	hud._process(SpellTooltip.LONG_PRESS_SEC)
	eq(hud.tooltip_visible(), true, "holding an armed spell shows the card")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "that hold leaves the spell armed")
	touch.pressed = false
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	hud._on_spell_pressed(SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), false, "releasing that hold dismisses the card")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "releasing a hold does not cancel the spell")
	touch.pressed = true
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	touch.pressed = false
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	hud._on_spell_pressed(SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), false, "a second tap does not open the card")
	eq(hud.selected_spell(), "", "a short second tap still cancels the spell")
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


func _test_hold_card_hides_when_drag_leaves() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	sim.reset_match({"seed": 1, "skip_deploy": true})
	var hud := CombatHUD.new()
	hud._build()
	hud.set_preview_source(sim)
	hud.render(sim.snapshot(), sim.legal_intents(0))
	var host: Control = hud._spell_hosts[SpellKits.MARK_SHOT]
	var inside := host.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = inside
	hud._on_spell_host_input(touch, SpellKits.MARK_SHOT)
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "drag test tap still arms Mark Shot")
	eq(hud.tooltip_visible(), false, "drag test tap does not open the card")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = inside
	hud._on_spell_host_input(drag, SpellKits.MARK_SHOT)
	hud._process(SpellTooltip.LONG_PRESS_SEC)
	eq(hud.tooltip_visible(), true, "a hold that stays on the circle still opens the card")
	drag.position = host.get_global_rect().position + Vector2(-80, -80)
	hud._on_spell_host_input(drag, SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), false, "dragging off the circle dismisses the hold card")
	eq(hud.selected_spell(), SpellKits.MARK_SHOT, "dragging off keeps the spell armed")
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
	truthy(view.contains("board_zoom"), "board camera uses the shared zoom")
	truthy(view.contains("use_mobile_pick"), "finger padding is gated on the mobile pick")
	truthy(view.contains("set_target_marked"), "a selected unit gets the aim ring")
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


func near(actual: float, expected: float, msg: String) -> void:
	if absf(actual - expected) > 0.001:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


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
