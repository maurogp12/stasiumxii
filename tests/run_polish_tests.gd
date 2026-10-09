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
	_test_full_party_scrolls()
	_test_turn_bar_options()
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
		truthy(chip.size.y <= CombatHUD.SLIM_CHIP + 0.5, "a small fight stays inside the thin strip (%s)" % chip.size)
		truthy(chip.size.x >= 48.0 and chip.size.y >= 48.0, "a thin-strip card stays tappable (%s)" % chip.size)
		near(chip.size.x, chip.size.y, "a thin-strip card stays square")
	truthy(hud._resource_panel.size.y <= CombatHUD.SLIM_CHIP + 1.0, "the strip has no plaque under the portraits (%s)" % hud._resource_panel.size.y)
	eq(hud._turn_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "a row that fits does not scroll")
	eq(_overlap(hud._banner_panels[0].get_rect(), hud._resource_panel.get_rect()), false, "the thin strip stays off the player plaque")
	eq(hud._turn_scroll.position.x + hud._turn_scroll.size.x <= hud._resource_panel.size.x + 1.0, true, "portraits stay inside the strip")
	hud.free()


func _test_full_party_scrolls() -> void:
	var hud := CombatHUD.new()
	root.add_child(hud)
	hud._build()
	hud.turn_bar_layout = CombatHUD.TURN_BAR_SCROLL
	hud._layout_chrome(Vector2(1600, 720))
	var names := ["ironjaw", "bastion", "kestrel", "mender", "gloam"]
	var units: Array = []
	for i in 10:
		units.append({
			"seat": i,
			"team": 0 if i < 5 else 1,
			"class_id": names[i % 5],
			"name": names[i % 5],
			"alive": true,
			"hp": 100,
			"max_hp": 100,
			"ap": 6,
			"mp": 3,
		})
	hud.render({"team_size": 1, "party_size": 5, "active_seat": 0, "units": units}, [])
	hud._layout_chrome(Vector2(1600, 720))
	eq(hud._turn_strip.get_child_count(), 10, "a full party and a full pack both sit on the bar")
	var chip := hud._turn_strip.get_child(0) as Control
	truthy(chip.size.x >= 140.0 and chip.size.y >= 140.0, "a full party keeps the large card (%s)" % chip.size)
	truthy(hud._turn_scroll.size.x + 8.0 < hud._turn_strip.custom_minimum_size.x, "ten cards scroll instead of shrinking")
	var gap := hud._chip_gap()
	var stride := chip.size.x + gap
	var shown := hud._turn_scroll.size.x
	var used := 0.0
	while used + chip.size.x <= shown + 0.5:
		used += stride
	var peek := shown - used
	truthy(peek >= chip.size.x * 0.25, "the next card peeks (%s of %s)" % [peek, chip.size.x])
	truthy(peek <= chip.size.x * 0.55, "the peek is a cut-off card (%s of %s)" % [peek, chip.size.x])
	eq(hud._turn_scroll.position.x + hud._turn_scroll.size.x <= hud._resource_panel.size.x + 1.0, true, "the scrolled row stays inside the turn plaque")
	hud.free()


func _test_turn_bar_options() -> void:
	var hud := CombatHUD.new()
	root.add_child(hud)
	hud._build()
	var names := ["ironjaw", "bastion", "kestrel", "mender", "gloam"]
	var units: Array = []
	for i in 10:
		units.append({
			"seat": i,
			"team": 0 if i < 5 else 1,
			"class_id": names[i % 5],
			"name": names[i % 5],
			"alive": true,
			"hp": 100,
			"max_hp": 100,
			"ap": 6,
			"mp": 3,
			"marks": 4 if i == 6 else 0,
		})
	var snap := {"team_size": 1, "party_size": 5, "active_seat": 0, "units": units}
	hud.turn_bar_layout = CombatHUD.TURN_BAR_SHRINK
	hud._layout_chrome(Vector2(1600, 720))
	hud.render(snap, [])
	hud._layout_chrome(Vector2(1600, 720))
	eq(hud._turn_strip.get_child_count(), 10, "shrink keeps every fighter on one row")
	eq(hud._turn_foe_strip.get_child_count(), 0, "shrink has no second row")
	var chip := hud._turn_strip.get_child(0) as Control
	truthy(chip.size.x < 120.0 and chip.size.y < 120.0, "shrink cards scale down (%s)" % chip.size)
	truthy(chip.size.x >= 48.0, "a shrunk card stays a tap target (%s)" % chip.size)
	var gap := hud._chip_gap()
	var content := chip.size.x * 10.0 + gap * 9.0
	truthy(content <= hud._turn_scroll.size.x + 4.0, "all ten shrunk cards fit the window (%s vs %s)" % [content, hud._turn_scroll.size.x])
	eq(hud._turn_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "shrink turns scrolling off")
	hud.turn_bar_layout = CombatHUD.TURN_BAR_ROWS
	hud._turn_strip_sig = ""
	hud.render(snap, [])
	hud._layout_chrome(Vector2(1600, 720))
	eq(hud._turn_strip.get_child_count(), 5, "the top row is the five allies")
	eq(hud._turn_foe_strip.get_child_count(), 5, "the second row is the five monsters")
	var ally := hud._turn_strip.get_child(0) as Control
	var foe := hud._turn_foe_strip.get_child(0) as Control
	truthy(ally.size.x >= 100.0 and ally.size.y >= 100.0, "two-row cards stay large (%s)" % ally.size)
	near(foe.size.x, ally.size.x, "both rows use the same card size")
	truthy(hud._resource_panel.size.y > 200.0, "two rows grow the plaque (%s)" % hud._resource_panel.size.y)
	var bottom := hud._resource_panel.position.y + hud._resource_panel.size.y
	truthy(bottom < 360.0, "the second row stays in the top half (%s)" % bottom)
	eq(hud._turn_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "two rows do not scroll")
	hud.turn_bar_layout = CombatHUD.TURN_BAR_SLIM
	hud._turn_strip_sig = ""
	hud._layout_chrome(Vector2(1600, 720))
	hud.render(snap, [])
	hud._layout_chrome(Vector2(1600, 720))
	eq(hud._turn_strip.get_child_count(), 10, "the slim strip keeps all ten on one row")
	eq(hud._turn_foe_strip.get_child_count(), 0, "the slim strip has no second row")
	var slim := hud._turn_strip.get_child(0) as Control
	near(slim.size.x, CombatHUD.SLIM_CHIP, "ten fighters use the thin-strip card")
	near(slim.size.y, slim.size.x, "the thin card stays square")
	truthy(hud._resource_panel.size.y <= CombatHUD.SLIM_CHIP + 1.0, "slim has no panel under the row (%s)" % hud._resource_panel.size.y)
	var slim_gap := hud._chip_gap()
	var slim_content := slim.size.x * 10.0 + slim_gap * 9.0
	truthy(slim_content <= hud._turn_scroll.size.x + 2.0, "all ten slim cards fit without scrolling")
	eq(hud._turn_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "slim turns scrolling off")
	eq(_overlap(hud._banner_panels[0].get_rect(), hud._resource_panel.get_rect()), false, "the slim row stays between the corner cards")
	hud.focus_fighter(6)
	truthy(hud._ironjaw_body.text.contains("HP"), "a tapped foe fills the right corner card")
	truthy(hud._ironjaw_body.text.contains("AP") and hud._ironjaw_body.text.contains("MP"), "the right card shows AP and MP")
	truthy(hud._ironjaw_body.text.contains("Marks 4"), "the right card shows that foe's Marks")
	var marked := false
	for child in hud._turn_chips():
		if int(child.get_meta("chip_seat", -2)) != 6:
			continue
		var badge := child.get_node_or_null("MarksBadge") as Label
		marked = badge != null and badge.visible and badge.text == "Marks 4"
	truthy(marked, "the slim portrait of a marked foe shows Marks 4")
	var bust := hud._banner_panels[1].get_node_or_null("Bust") as TextureRect
	truthy(bust != null and bust.texture != null, "the right card shows that foe's portrait")
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
