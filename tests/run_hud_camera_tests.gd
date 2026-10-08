extends SceneTree

## Walk, Fade, and the turn handoff must not present an empty HUD or a
## one-frame camera jump. Hot-seat goes through the board submit path.
## The snapshot path is the same handler an online state_changed uses.
## Run: godot --headless --path . -s res://tests/run_hud_camera_tests.gd
## Phone framing: add -- --mobile-frame

const NET_SCRIPT := preload("res://backend/net_session.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_test_source_contract()
	_test_turn_strip_stays_readable()
	_test_degenerate_layout_keeps_plaques()
	await _test_live_updates()
	print("HUD camera tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_source_contract() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("_hud.render(snap, [])"), false, "a walk does not clear the spell bar")
	truthy(view.contains("force_update_scroll"), "camera writes publish the canvas transform in the same frame")
	truthy(view.contains("_fit_board_camera(true)"), "a new turn still glides the camera to the active fighter")
	eq(view.contains("_camera.position -="), false, "pan handlers do not write the camera on each motion event")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud.contains("return Vector2(1, 1)"), false, "turn portraits are never built at 1×1")


func _test_turn_strip_stays_readable() -> void:
	CombatSim.reset_match({
		"seed": 3,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(4, 7), Vector2i(8, 7)],
	})
	var hud := CombatHUD.new()
	root.add_child(hud)
	hud._build()
	hud._layout_chrome(Vector2(2400, 1080))
	# The band has not been given a real height yet. A rebuild here used to
	# store 1×1 chips and leave the plaque empty until the next layout.
	hud._turn_strip.size = Vector2(272, 4)
	var snap: Dictionary = CombatSim.snapshot()
	hud.render(snap, CombatSim.legal_intents(0))
	_assert_cards(hud, "unready strip")
	_assert_chips(hud, "unready strip")
	hud._fit_turn_chips()
	_assert_chips(hud, "fit while the band is still short")
	snap["active_seat"] = 1 if int(snap.get("active_seat", 0)) == 0 else 0
	hud.render(snap, CombatSim.legal_intents(int(snap["active_seat"])))
	_assert_cards(hud, "turn flip")
	_assert_chips(hud, "turn flip")
	truthy(hud._spell_buttons.size() >= 1, "turn flip keeps a spell button")
	truthy(hud._ability_cluster.visible, "turn flip keeps the spell cluster")
	hud.free()


func _test_degenerate_layout_keeps_plaques() -> void:
	var hud := CombatHUD.new()
	root.add_child(hud)
	hud._build()
	hud._layout_chrome(Vector2(1920, 1080))
	var banner: Vector2 = hud._banner_panels[0].size
	var hand: Vector2 = hud._handoff_panel.size
	var saved := root.size
	root.size = Vector2i(120, 48)
	hud._layout_chrome()
	eq(hud._banner_panels[0].size, banner, "a collapsed viewport does not squash the stat plaques")
	eq(hud._handoff_panel.size, hand, "a collapsed viewport does not squash the turn banner")
	root.size = saved
	hud.free()


func _test_live_updates() -> void:
	GearBag.save_path = "user://test_hud_camera_bag.json"
	HeroProgress.save_path = "user://test_hud_camera_hero.json"
	StillVault.save_path = "user://test_hud_camera_still.json"
	KoliseoWallet.save_path = "user://test_hud_camera_wallet.json"
	var mobile := OS.get_cmdline_user_args().has("--mobile-frame")
	if mobile:
		root.size = Vector2i(2400, 1080)
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var board: Node = main.get_node("BoardView")
	var hud: CombatHUD = main.get_node("HUD")
	truthy(bool(board.get("_booted")), "board finished boot")
	CombatSim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(4, 7), Vector2i(8, 7)],
	})
	board._rebuild_pawns()
	board._refresh()
	hud._layout_chrome(Vector2(root.size))
	await process_frame
	await _watch(board, hud, "after boot", false, 4)
	var step := _legal_step()
	truthy(step.x >= 0, "Gloam has a legal step")
	board._submit({"type": "move", "to": step})
	await _watch(board, hud, "hot-seat walk", false, 0)
	var fade_at := _seat_pos(0)
	var faded: Dictionary = CombatSim.legal_intents(int(CombatSim.snapshot().get("active_seat", 0)))
	var fade_ok := false
	for intent in faded:
		if typeof(intent) == TYPE_DICTIONARY and str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == "fade":
			fade_ok = true
			break
	truthy(fade_ok, "Fade is legal after the step")
	board._submit({"type": "cast", "spell": "fade", "to": fade_at})
	await _watch(board, hud, "hot-seat Fade", false, 0)
	board._on_end_turn_button_pressed()
	await _watch(board, hud, "hot-seat turn change", false, 0, true)
	# Applied snapshot, including an enemy walk while this phone is Gloam's.
	# Dedicated skips the listen-host clock, which would otherwise rebroadcast
	# and re-enter the same handler mid-watch.
	var net := root.get_node("/root/NetSession")
	var prev_mode: int = int(net.mode)
	var prev_seat: int = int(net.local_seat)
	net.mode = NET_SCRIPT.Mode.DEDICATED
	net.local_seat = 0
	var enemy_step := _legal_step()
	truthy(enemy_step.x >= 0, "the snapshot walker has a legal step")
	var walked: Dictionary = CombatSim.submit({"type": "move", "to": enemy_step})
	eq(bool(walked.get("ok", false)), true, "snapshot walk is legal (%s)" % str(walked.get("reason", "")))
	board._on_net_state(walked.get("events", []), {})
	await _watch(board, hud, "snapshot enemy walk", false, 0)
	var follow := mobile and int(CombatSim.snapshot().get("active_seat", -1)) == int(net.local_seat)
	net.local_seat = int(CombatSim.snapshot().get("active_seat", 0))
	follow = mobile and int(net.local_seat) == int(CombatSim.snapshot().get("active_seat", -1))
	var local_step := _legal_step()
	if local_step.x >= 0:
		var local_walk: Dictionary = CombatSim.submit({"type": "move", "to": local_step})
		eq(bool(local_walk.get("ok", false)), true, "local snapshot walk is legal")
		board._on_net_state(local_walk.get("events", []), {})
		await _watch(board, hud, "snapshot local walk", follow, 0)
	var ended: Dictionary = CombatSim.submit({"type": "end_turn"})
	eq(bool(ended.get("ok", false)), true, "snapshot end turn is legal")
	board._on_net_state(ended.get("events", []), {})
	await _watch(board, hud, "snapshot turn change", false, 0, true)
	net.mode = prev_mode
	net.local_seat = prev_seat
	main.free()


func _watch(board: Node, hud: CombatHUD, label: String, allow_motion: bool, extra_frames: int, expect_banner: bool = false) -> void:
	var start := _cam_sample(board)
	var prev := start
	var idle := 0
	var saw_banner := false
	var guard := 480 if extra_frames == 0 else extra_frames
	for _i in guard:
		await process_frame
		if not _assert_hud(hud, label):
			return
		var cur := _cam_sample(board)
		if not _assert_cam(start, prev, cur, allow_motion, label):
			return
		prev = cur
		var banner := hud._handoff_overlay != null and hud._handoff_overlay.visible
		saw_banner = saw_banner or banner
		if extra_frames > 0:
			continue
		var locked := bool(board.get("_busy")) or bool(board.get("_view_locked"))
		if not locked and not banner:
			idle += 1
			if idle >= 3:
				break
		else:
			idle = 0
	if expect_banner:
		truthy(saw_banner, "%s shows the turn banner" % label)


func _assert_hud(hud: CombatHUD, label: String) -> bool:
	var before := _failed
	_assert_cards(hud, label)
	_assert_chips(hud, label)
	eq(str(hud._hub_button.text), "Hub", "%s Hub keeps its caption" % label)
	if hud._new_match_button.visible:
		eq(str(hud._new_match_button.text), "New Match", "%s New Match keeps its caption" % label)
	if hud._face_bar != null and hud._face_bar.visible:
		for dir in ["N", "W", "E", "S"]:
			var button: Button = hud._face_buttons[dir]
			truthy(button.visible and str(button.text) == dir, "%s face %s stays labeled" % [label, dir])
	if not hud._deploying:
		truthy(hud._ability_cluster.visible, "%s spell cluster stays up" % label)
		truthy(hud._spell_buttons.size() >= 1, "%s spell bar is not cleared" % label)
	if hud._handoff_overlay != null and hud._handoff_overlay.visible:
		truthy(str(hud._handoff_label.text).strip_edges() != "", "%s turn banner has a caption" % label)
		truthy(hud._handoff_panel.size.y >= 72.0, "%s turn banner is not a thin bar (%s)" % [label, hud._handoff_panel.size])
	return _failed == before


func _assert_cards(hud: CombatHUD, label: String) -> void:
	truthy(str(hud._kestrel_body.text).contains("HP"), "%s left card keeps HP" % label)
	truthy(str(hud._ironjaw_body.text).contains("HP"), "%s right card keeps HP" % label)
	truthy(str(hud._seat_titles[0].text).strip_edges() != "", "%s left title stays" % label)
	truthy(str(hud._seat_titles[1].text).strip_edges() != "", "%s right title stays" % label)


func _assert_chips(hud: CombatHUD, label: String) -> void:
	truthy(hud._turn_strip.get_child_count() >= 2, "%s turn plaque keeps both portraits" % label)
	for child in hud._turn_strip.get_children():
		var host := child as Control
		truthy(host != null and host.size.y >= 32.0, "%s portrait is not an empty dot (%s)" % [label, host.size if host != null else Vector2.ZERO])


func _assert_cam(start: Dictionary, prev: Dictionary, cur: Dictionary, allow_motion: bool, label: String) -> bool:
	var before := _failed
	var cap := 48.0 if allow_motion else 3.0
	var zoom_cap := 0.05 if allow_motion else 0.02
	var step: float = (prev["pos"] as Vector2).distance_to(cur["pos"])
	var from_start: float = (start["pos"] as Vector2).distance_to(cur["pos"])
	var canvas_step: float = (prev["origin"] as Vector2).distance_to(cur["origin"])
	var zoom_delta := absf(float(cur["zoom"]) - float(start["zoom"]))
	if not allow_motion:
		truthy(from_start <= cap, "%s camera position stays put (moved %.1f)" % [label, from_start])
	truthy(step <= cap, "%s camera step is smooth (%.1f)" % [label, step])
	truthy(canvas_step <= cap * maxf(float(cur["zoom"]), 0.25) + 4.0, "%s canvas transform stays smooth (%.1f)" % [label, canvas_step])
	truthy(zoom_delta <= zoom_cap, "%s zoom stays (delta %.3f)" % [label, zoom_delta])
	truthy((cur["offset"] as Vector2).length() <= 1.5, "%s camera offset stays clear" % label)
	return _failed == before


func _cam_sample(board: Node) -> Dictionary:
	var cam: Camera2D = board.get("_camera")
	var canvas := board.get_viewport().get_canvas_transform()
	return {
		"pos": cam.position,
		"zoom": cam.zoom.x,
		"offset": cam.offset,
		"origin": canvas.origin,
	}


func _legal_step() -> Vector2i:
	var snap: Dictionary = CombatSim.snapshot()
	var seat := int(snap.get("active_seat", 0))
	for intent in CombatSim.legal_intents(seat):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) != "move":
			continue
		var dest: Variant = intent.get("to", null)
		if dest is Vector2i:
			return dest
	return Vector2i(-1, -1)


func _seat_pos(seat: int) -> Vector2i:
	for unit in CombatSim.snapshot().get("units", []):
		if typeof(unit) == TYPE_DICTIONARY and int(unit.get("seat", -2)) == seat:
			var pos: Variant = unit.get("pos", Vector2i(-1, -1))
			if pos is Vector2i:
				return pos
	return Vector2i(-1, -1)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if got != want:
		_failed += 1
		print("FAIL: %s  (got %s want %s)" % [msg, got, want])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s" % msg)
	else:
		_passed += 1
