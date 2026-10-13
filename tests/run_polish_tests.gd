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
	_test_pan_clears_chrome()
	_test_turn_bar()
	_test_grid_and_occluders()
	_test_draw_slots_do_not_tie()
	_test_phone_pan_stays_on_device_pixels()
	_test_shake_stays_off_the_camera()
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


func _test_pan_clears_chrome() -> void:
	var board: Node2D = load("res://board_view.gd").new()
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position = Vector2.ZERO
	board._camera = cam
	board._fit_camera_pos = Vector2.ZERO
	board._pan_limit = Vector2.ZERO
	board._board_px = Vector2(960, 500)
	board._queue_pan(Vector2(4000, 0))
	board._apply_pending_pan()
	near(cam.position.x, -TouchAdapter.PAN_CHROME_LEFT / 2.0, "dragging right slides the left edge clear of the buttons")
	eq(board._user_panned, true, "a drag marks the view as player-panned")
	board._queue_pan(Vector2(-4000, 0))
	board._apply_pending_pan()
	near(cam.position.x, TouchAdapter.PAN_CHROME_RIGHT / 2.0, "dragging left slides the right edge clear of the spells")
	var stuck := cam.position.x
	board._queue_pan(Vector2(-4000, 0))
	board._apply_pending_pan()
	near(cam.position.x, stuck, "the board stops once that edge clears the buttons")
	board._queue_pan(Vector2(0, 4000))
	board._apply_pending_pan()
	# Desktop clamp has no vertical chrome. The portrait inset is phone-only.
	near(cam.position.y, 0.0, "desktop pan does not drag the board off the top of the play band")
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
	eq(PaintedRoom.CRYSTAL_DRAW_SCALE, 1.0, "Windmere crystals draw at the source pixel size")
	var pose: Dictionary = PaintedRoom.crystal_sprite_pose(Vector2i(3, 3), {"offset": [-21, -71], "size": [43, 84]})
	var half_top := VISUAL_SORT.cell_to_local(Vector2i(3, 3), 0.0) + Vector2(-10.5, -35.5)
	var foot := half_top + Vector2(43.0 * 0.25, 84.0 * 0.5)
	eq(pose["foot"], foot, "the bigger crystal keeps the old foot")
	truthy(float(pose["position"].y) < half_top.y, "the crystal grows up from that foot")
	var behind := Vector2i(2, 2)
	truthy(VISUAL_SORT.occluder_z_index(Vector2i(3, 3), 0.0) > VISUAL_SORT.unit_z_index(behind, 0.0), "a fighter behind the crystal paints under it")
	_assert_crystal_art_on_crystal_tiles(
		"res://art/rooms/koliseo_windmere/place.json",
		"res://art/maps/arena_colosseum_v2/tiled/windmere_15x15_tags.json"
	)
	_assert_crystal_art_on_crystal_tiles(
		"res://art/rooms/stasis_windmere_room_a/place.json",
		"res://art/maps/stasis_v1/windmere_room_a_15x15_tags.json"
	)
	eq(CombatHUD.coach_hint("REJECT — that path needs 5 MP (you have 1)."), "Needs 5 MP (have 1)", "the path reject is one short line")
	truthy(CombatHUD.PORTRAIT_CHIP.y >= 96.0, "turn portraits are at least 96px tall")


## Same-row tiles, lava, and a prop on a block each have their own z.
## Fighters on that row still tie, and the camera snap does not walk.
func _test_draw_slots_do_not_tie() -> void:
	var seen := {}
	for y in 15:
		for x in 15:
			var cell := Vector2i(x, y)
			var z := VISUAL_SORT.tile_z_index(cell, 0.0)
			eq(seen.has(z), false, "flat cell %s does not share a tile z" % cell)
			seen[z] = true
			var hazard := VISUAL_SORT.hazard_z_index(cell, 0.0)
			var block := VISUAL_SORT.occluder_z_index(cell, 0.0)
			var prop := VISUAL_SORT.prop_z_index(cell, 0.0)
			eq(hazard < z, true, "the hazard decal sits under its tile")
			eq(block, z + VISUAL_SORT.OCCLUDER_Z_BIAS, "the elevation block stays two above the tile")
			eq(prop, z + VISUAL_SORT.PROP_Z_BIAS, "a prop on the block is the next slot")
			truthy(prop < VISUAL_SORT.unit_z_index(cell, 0.0), "the fighter on the cell paints over its prop")
			truthy(z + 4 < VISUAL_SORT.tile_z_index(cell + Vector2i(1, 0), 0.0), "a raised diamond stays behind the next row")
	eq(VISUAL_SORT.unit_z_index(Vector2i(4, 6), 0.0), VISUAL_SORT.unit_z_index(Vector2i(6, 4), 0.0), "fighters on one depth line still tie")
	eq(VISUAL_SORT.tile_z_index(Vector2i(4, 6), 0.0) < VISUAL_SORT.tile_z_index(Vector2i(6, 4), 0.0), true, "the right-hand tile on that line paints in front")
	var worst := 0
	for tx in 15:
		for ty in 15:
			var tower := Vector2i(tx, ty)
			var cover := 0
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					var cell := tower + Vector2i(dx, dy)
					if cell.x < 0 or cell.y < 0 or cell.x > 14 or cell.y > 14:
						continue
					cover = maxi(cover, VISUAL_SORT.occluder_z_index(cell, 2.0))
					cover = maxi(cover, VISUAL_SORT.tile_z_index(cell, 2.0) + 3)
			var tower_z := cover + 1
			for fx in 15:
				for fy in 15:
					var ahead := fx + fy - tx - ty
					if ahead < 0:
						continue
					var lifted := tower_z + 1 + ahead * VISUAL_SORT.TILE_Z_SCALE + int(round(2.0 * float(VISUAL_SORT.ELEVATION_Z_SCALE)))
					worst = maxi(worst, lifted)
	truthy(worst < VISUAL_SORT.WEATHER_Z, "a fighter in front of the tower stays under the snow (%d)" % worst)
	truthy(VISUAL_SORT.unit_z_index(Vector2i(14, 14), 2.0) < VISUAL_SORT.SHADE_Z, "Shade paints above the far raised cell")
	truthy(VISUAL_SORT.WEATHER_Z < VISUAL_SORT.LIFE_Z, "the rim light stays above the snow")
	truthy(VISUAL_SORT.LIFE_Z < VISUAL_SORT.SHADE_Z, "Shade stays above the weather")
	truthy(VISUAL_SORT.SHADE_Z < VISUAL_SORT.AIM_Z, "the aim line stays above Shade")
	truthy(VISUAL_SORT.FLOAT_Z > VISUAL_SORT.AIM_Z and VISUAL_SORT.FLOAT_Z < 4096, "numbers stay above the aim line and under Godot's z clamp")
	var view := Vector2(2400, 1080)
	var zoom := Vector2(1.35, 1.35)
	var once := VISUAL_SORT.snap_camera_position(Vector2(12.4, -8.2), zoom, view)
	var twice := VISUAL_SORT.snap_camera_position(once, zoom, view)
	near(twice.x, once.x, "camera snap does not walk on x")
	near(twice.y, once.y, "camera snap does not walk on y")
	var center := view * 0.5
	var origin := Vector2(center.x - once.x * zoom.x, center.y - once.y * zoom.y)
	near(origin.x, roundf(origin.x), "the snapped camera lands on a whole pixel")
	near(origin.y, roundf(origin.y), "the snapped camera lands on a whole pixel vertically")
	var proj := FileAccess.get_file_as_string("res://project.godot")
	truthy(proj.contains("2d/snap/snap_2d_transforms_to_pixel=true"), "canvas transforms snap to pixels")
	var screen := VISUAL_SORT.shake_screen(Vector2(14.6, -3.2))
	eq(screen, Vector2(15, -3), "shake offsets round to whole screen pixels")
	var world := VISUAL_SORT.shake_world_offset(Vector2(14.6, -3.2), 1.55)
	near(world.x * 1.55, 15.0, "shake x is 15 screen pixels at this zoom")
	near(world.y * 1.55, -3.0, "shake y is -3 screen pixels at this zoom")
	eq(VISUAL_SORT.SHAKE_CULL_MARGIN >= 48.0, true, "the cull margin covers the punch")
	truthy(proj.contains("default_texture_filter=1"), "the canvas filter is linear, without mipmaps")


## A 1080p phone stretches the 720 canvas by 1.5. The camera has to land on a
## device pixel, or each pan step flips the ice onto a half pixel and back.
func _test_phone_pan_stays_on_device_pixels() -> void:
	var view := Vector2(1600, 720)
	var window := Vector2(2400, 1080)
	var scale := VISUAL_SORT.viewport_pixel_scale(view, window)
	near(scale.x, 1.5, "a 1080p phone is 1.5 device pixels per canvas pixel")
	near(scale.y, 1.5, "the phone stretch is the same on y")
	eq(VISUAL_SORT.viewport_pixel_scale(view, Vector2.ZERO), Vector2.ONE, "a headless window keeps the canvas snap")
	var zoom := Vector2(1.823529, 1.823529)
	var center := view * 0.5
	var prev_device := Vector2.ZERO
	var pos := Vector2(12.4, 194.7)
	for step in 8:
		var snapped := VISUAL_SORT.snap_camera_position(pos, zoom, view, scale)
		var again := VISUAL_SORT.snap_camera_position(snapped, zoom, view, scale)
		near(again.x, snapped.x, "phone snap does not walk on x")
		near(again.y, snapped.y, "phone snap does not walk on y")
		var origin := Vector2(center.x - snapped.x * zoom.x, center.y - snapped.y * zoom.y)
		var device := Vector2(origin.x * scale.x, origin.y * scale.y)
		near(device.x, roundf(device.x), "the pan lands on a whole device pixel")
		near(device.y, roundf(device.y), "the pan lands on a whole device pixel vertically")
		if step > 0:
			near(device.x - prev_device.x, roundf(device.x - prev_device.x), "the pan step is whole device pixels")
			near(device.y - prev_device.y, roundf(device.y - prev_device.y), "the pan step is whole device pixels vertically")
		prev_device = device
		# The same drag the phone uses: screen pixels divided by zoom.
		pos = snapped - Vector2(3.0, 2.0) / zoom.x
	var desk := Vector2(2400, 1080)
	var desk_zoom := Vector2(1.35, 1.35)
	var once := VISUAL_SORT.snap_camera_position(Vector2(12.4, -8.2), desk_zoom, desk)
	var desk_origin := Vector2(desk.x * 0.5 - once.x * desk_zoom.x, desk.y * 0.5 - once.y * desk_zoom.y)
	near(desk_origin.x, roundf(desk_origin.x), "a 1:1 window still snaps to a canvas pixel")
	var view_src := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view_src.contains("viewport_pixel_scale"), "the live camera snaps in device pixels")


## The punch moves the world parent in whole screen pixels. The camera offset
## stays zero, so the tile cull does not follow the wobble.
func _test_shake_stays_off_the_camera() -> void:
	var board: Node2D = load("res://board_view.gd").new()
	root.add_child(board)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.55, 1.55)
	board._camera = cam
	board.add_child(cam)
	board._set_view_shake(Vector2(14.4, -6.6))
	eq(cam.offset, Vector2.ZERO, "shake leaves the camera offset clear")
	var host: Node2D = board._world
	truthy(host != null, "shake has a world parent")
	var expect := VISUAL_SORT.shake_world_offset(Vector2(14.4, -6.6), 1.55)
	near(host.position.x, expect.x, "shake x lands on whole screen pixels")
	near(host.position.y, expect.y, "shake y lands on whole screen pixels")
	board._set_view_shake(Vector2.ZERO)
	eq(host.position, Vector2.ZERO, "the shake returns home")
	board.free()


## The painted crystal copy has to sit on the crystal tile. A corner park
## leaves the obstacle looking like empty snow.
func _assert_crystal_art_on_crystal_tiles(place_path: String, tags_path: String) -> void:
	var place: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(place_path))
	var tags: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(tags_path))
	var painted := {}
	for raw in place.get("occluders", []):
		var occ: Dictionary = raw
		var whats: Array = occ.get("what", [])
		if not whats.has("crystal"):
			continue
		var cell: Array = occ.get("cell", [])
		painted[Vector2i(int(cell[0]), int(cell[1]))] = true
	var tagged := 0
	for raw in tags.get("cells", []):
		var tile: Dictionary = raw
		var paint: Array = tile.get("paint_only", [])
		if not paint.has("crystal"):
			continue
		tagged += 1
		var cell := Vector2i(int(tile.get("x", -1)), int(tile.get("y", -1)))
		truthy(painted.has(cell), "crystal art sits on %s" % str(cell))
	truthy(tagged > 0, "the map has crystal tiles")
	eq(painted.size(), tagged, "every painted crystal is a crystal tile")


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
	near(hud._banner_panels[0].size.y, CombatHUD.CORNER_CARD_H, "the player plaque fits the stack lines")
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
	truthy(hud._ironjaw_body.text.contains("Aegis"), "the right card shows that foe's own Aegis")
	truthy(hud._ironjaw_body.text.contains("Marks") and hud._ironjaw_body.text.contains("4/5"), "the right card shows that foe's Marks")
	var disc := false
	for child in hud._turn_chips():
		for node_name in ["StackBadge", "MarksBadge"]:
			var badge := child.get_node_or_null(node_name) as CanvasItem
			if badge != null and badge.visible:
				disc = true
	eq(disc, false, "slim portraits have no stack discs")
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
