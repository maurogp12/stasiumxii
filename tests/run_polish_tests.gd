extends SceneTree

## 0.1.143 feel pass: pan is applied once a frame, the turn bar names YOU /
## OPPONENT, occluders sit above the grid, and the room audit lists paintings
## that disagree with cell elevation. Gameplay numbers are not changed.
## Run: godot --headless --path . -s res://tests/run_polish_tests.gd

const VISUAL_SORT := preload("res://board/visual_sort.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_test_pan_is_queued()
	_test_turn_bar()
	_test_grid_and_occluders()
	_test_class_select_copy()
	_test_hud_does_not_overlap()
	_test_turn_targets_are_cards()
	_test_clock_and_pips_stay_put()
	_audit_rooms()
	print("Polish tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_pan_is_queued() -> void:
	var board: Node2D = load("res://board_view.gd").new()
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position = Vector2(10, 10)
	board._camera = cam
	board._fit_camera_pos = Vector2(10, 10)
	board._pan_limit = Vector2(100, 100)
	board._queue_pan(Vector2(4, 0))
	eq(cam.position, Vector2(10, 10), "a pan gesture does not move the camera during input")
	board._apply_pending_pan()
	near(cam.position.x, 8.0, "one apply moves by the queued screen delta")
	eq(board._pan_pending, Vector2.ZERO, "the queue is cleared after the frame")
	var src := FileAccess.get_file_as_string("res://board_view.gd")
	eq(src.contains("_camera.position -="), false, "pan handlers do not write the camera on each motion event")
	truthy(src.contains("func _apply_pending_pan"), "pan is applied from the frame")
	truthy(src.contains("func _apply_wheel_zoom"), "the mouse wheel uses the zoom limits")
	truthy(src.contains("func _follow_local_fighter"), "the camera only follows the local fighter")
	board.free()


func _test_turn_bar() -> void:
	eq(CombatHUD.turn_banner_text({"local_seat": -1, "active_seat": 0}), "YOUR TURN", "hot-seat turn line is YOUR TURN")
	eq(CombatHUD.turn_banner_text({"local_seat": 1, "active_seat": 1}), "YOUR TURN", "online local turn is YOUR TURN")
	eq(CombatHUD.turn_banner_text({"local_seat": 0, "active_seat": 1}), "OPPONENT'S TURN", "online watching is OPPONENT'S TURN")
	eq(CombatHUD.turn_status_text({"local_seat": -1}), "", "hot-seat status helper stays empty")
	var seats := CombatHUD.you_opp_seats({
		"local_seat": -1,
		"active_seat": 1,
		"units": [{"seat": 0, "name": "Kestrel"}, {"seat": 1, "name": "Ironjaw"}],
	})
	eq(seats, Vector2i(1, 0), "hot-seat YOU is the fighter who must act")
	var online := CombatHUD.you_opp_seats({
		"local_seat": 0,
		"active_seat": 1,
		"units": [{"seat": 0, "name": "Kestrel", "class_id": "kestrel"}, {"seat": 1, "name": "Ironjaw", "class_id": "ironjaw"}],
	})
	eq(online, Vector2i(0, 1), "online YOU is the local seat")
	eq(CombatHUD.seat_caption({"name": "Kestrel", "class_id": "kestrel"}), "Kestrel", "a class-named fighter is not repeated")


func _test_grid_and_occluders() -> void:
	eq(VISUAL_SORT.OCCLUDER_Z_BIAS, 2, "occluders sit two steps above the tile")
	eq(VISUAL_SORT.occluder_z_index(Vector2i(1, 2), 0.0), VISUAL_SORT.tile_z_index(Vector2i(1, 2), 0.0) + 2, "occluder z is the tile plus the bias")
	truthy(VISUAL_SORT.occluder_z_index(Vector2i(3, 3), 1.0) < VISUAL_SORT.unit_z_index(Vector2i(3, 3), 1.0), "a fighter still paints above the wall")
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	truthy(tile_src.contains("walk_block_kind == \"block\""), "grid ink skips blocked cells")
	var room_src := FileAccess.get_file_as_string("res://board/painted_room.gd")
	truthy(room_src.contains("occluder_z_index"), "painted walls use the occluder z")
	truthy(room_src.contains("set_occluder_covers_grid"), "a wall or prop cell hides its grid ink")
	truthy(room_src.contains("cell_to_local(cell, 0.0)"), "occluders anchor on the plate, not a second elevation lift")
	truthy(room_src.contains("set_raised_top"), "a raised block keeps its diamond on the painted top")
	eq(CombatHUD.coach_hint("REJECT — that path needs 5 MP (you have 1)."), "Needs 5 MP (have 1)", "the path reject is one short line")
	truthy(CombatHUD.PORTRAIT_CHIP.y >= 96.0, "turn portraits are at least 96px tall")


func _test_class_select_copy() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	eq(src.contains("Hot-seat picks classes"), false, "the long roster line is gone")
	truthy(src.contains("Play Online"), "Play Online stays")
	truthy(src.contains("Advanced"), "Advanced stays")
	truthy(src.contains("Cinzel-Semibold.ttf"), "class select uses the hub font")
	truthy(src.contains("func _stone_style"), "class cards use the stone panel")
	truthy(src.contains("painted_cells"), "class cards use the match idle, not the old select plate")


func _test_hud_does_not_overlap() -> void:
	for size in [Vector2i(2400, 1080), Vector2i(1920, 1080), Vector2i(1920, 822), Vector2i(1280, 800), Vector2i(1600, 720), Vector2i(1600, 20), Vector2i(400, 900)]:
		root.size = size
		var hud := CombatHUD.new()
		root.add_child(hud)
		hud._build()
		hud._layout_chrome(Vector2(size))
		var left: Rect2 = hud._banner_panels[0].get_rect()
		var right: Rect2 = hud._banner_panels[1].get_rect()
		var mid: Rect2 = hud._resource_panel.get_rect()
		eq(_overlap(left, mid), false, "left banner clears the center at %s" % size)
		eq(_overlap(right, mid), false, "right banner clears the center at %s" % size)
		eq(_overlap(left, right), false, "banners clear each other at %s" % size)
		eq(left.end.x <= size.x + 0.5 and right.end.x <= size.x + 0.5, true, "banners stay inside %s" % size)
		eq(left.position.y >= 0.0 and left.end.y <= size.y + 0.5, true, "left banner stays inside the height at %s" % size)
		hud.free()


func _test_turn_targets_are_cards() -> void:
	root.size = Vector2i(2400, 1080)
	var hud := CombatHUD.new()
	root.add_child(hud)
	hud._build()
	hud._layout_chrome(Vector2(2400, 1080))
	near(hud._banner_panels[0].size.x, 240.0, "the player plaque stays 240 wide")
	near(hud._banner_panels[0].size.y, 100.0, "the player plaque stays 100 tall")
	var classes := ["ironjaw", "bastion", "kestrel", "gloam", "mender", "kestrel"]
	var units: Array = []
	for i in classes.size():
		units.append({
			"seat": i,
			"team": 0 if i < 3 else 1,
			"class_id": classes[i],
			"name": classes[i],
			"alive": true,
			"hp": 100,
			"max_hp": 100,
			"ap": 6,
			"mp": 3,
		})
	hud.render({"team_size": 3, "active_seat": 0, "units": units}, [])
	eq(hud._turn_strip.get_child_count(), 6, "a full fight lists every fighter")
	for child in hud._turn_strip.get_children():
		var chip := child as Control
		truthy(chip.size.x >= 88.0 and chip.size.y >= 88.0, "each turn target is a finger card (%s)" % chip.size)
		truthy(chip.size.y <= chip.size.x + 16.0, "a turn target is not a tall empty bar (%s)" % chip.size)
	eq(_overlap(hud._banner_panels[0].get_rect(), hud._resource_panel.get_rect()), false, "the wider turn row stays off the player plaque")
	eq(hud._turn_strip.position.x + hud._turn_strip.size.x <= hud._resource_panel.size.x + 1.0, true, "portraits stay inside the turn plaque")
	hud.free()


func _test_clock_and_pips_stay_put() -> void:
	var hud := CombatHUD.new()
	root.add_child(hud)
	hud._build()
	var track_before: Vector2 = hud._clock_track.custom_minimum_size
	hud.set_turn_clock(20, true, 1.0)
	hud.set_turn_clock(9, true, 0.4)
	eq(hud._clock_track.custom_minimum_size, track_before, "the clock track does not reflow each frame")
	near(hud._clock_bar.size.x, track_before.x * 0.4, "the clock fill still follows the fraction")
	var unit := {"class_id": "kestrel", "marks": 1, "marks_cap": 3}
	hud._render_pips(hud._ap_pips, 4, 6, CombatHUD.DOFUS_AP, unit)
	var pip := hud._ap_pips.get_child(1)
	var pip_id := pip.get_instance_id()
	var count := hud._ap_pips.get_child_count()
	hud._render_pips(hud._ap_pips, 4, 6, CombatHUD.DOFUS_AP, unit)
	eq(hud._ap_pips.get_child_count(), count, "unchanged AP does not rebuild pips")
	eq(hud._ap_pips.get_child(1).get_instance_id(), pip_id, "the same pip stays on screen")
	hud.free()


func _audit_rooms() -> void:
	var rooms: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open("res://art/rooms")
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			rooms.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	rooms.sort()
	eq(rooms.size(), 15, "the audit covers all 15 painted rooms")
	var mismatches := 0
	for room_id in rooms:
		var place: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/rooms/%s/place.json" % room_id))
		var tags: Dictionary = _tags_for(room_id)
		var cells := {}
		var hist := {}
		for raw in tags.get("cells", []):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var elev := int(raw.get("elevation", 0))
			cells["%d,%d" % [int(raw.get("x", -1)), int(raw.get("y", -1))]] = elev
			hist[elev] = int(hist.get(elev, 0)) + 1
		var labeled := 0
		var bad := 0
		for raw in (place as Dictionary).get("occluders", []):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var painted := -1
			for bit in raw.get("what", []):
				var text := str(bit)
				if text.begins_with("elevation "):
					painted = int(text.trim_prefix("elevation "))
			if painted < 0:
				continue
			labeled += 1
			var cell: Array = raw.get("cell", [0, 0])
			var key := "%d,%d" % [int(cell[0]), int(cell[1])]
			if int(cells.get(key, -99)) != painted:
				bad += 1
		mismatches += bad
		print("ROOM_AUDIT %s labels %d mismatches %d cell_elev %s" % [room_id, labeled, bad, hist])
	eq(mismatches, 0, "occluder elevation labels match cell elevation in every room")


func _has_room(rows: PackedStringArray, room_id: String) -> bool:
	for row in rows:
		if str(row).begins_with(room_id):
			return true
	return false


func _tags_for(room_id: String) -> Dictionary:
	var path := ""
	if room_id.begins_with("stasis_"):
		var rest := room_id.trim_prefix("stasis_")
		path = "res://art/maps/stasis_v1/%s_15x15_tags.json" % rest
	else:
		path = "res://art/maps/arena_colosseum_v2/tiled/%s_15x15_tags.json" % room_id.trim_prefix("koliseo_")
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _overlap(a: Rect2, b: Rect2) -> bool:
	if not a.intersects(b):
		return false
	var hit := a.intersection(b)
	return hit.size.x > 1.0 and hit.size.y > 1.0


func eq(got: Variant, want: Variant, msg: String) -> void:
	if got != want:
		_failed += 1
		print("FAIL: %s  (got %s want %s)" % [msg, got, want])
	else:
		_passed += 1


func near(got: float, want: float, msg: String) -> void:
	if absf(got - want) > 0.05:
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
