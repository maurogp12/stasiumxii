extends SceneTree

## Coilgate floor theme: slots resolve, the layer loads, cells stay visible.
## Run: godot --headless --path . -s res://tests/run_coilgate_floor_tests.gd

const FLOOR := preload("res://board/pc/coilgate_floor.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_test_params_and_slots()
	_test_board_wires_the_theme()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_live_theme()
	print("Coilgate floor tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_params_and_slots() -> void:
	var params := FLOOR.load_params()
	eq(str(params.get("theme", "")), "coilgate", "the json names the coilgate theme")
	eq(str(params.get("display_name", "")), "Thunderwell Core", "the display name is Thunderwell Core")
	eq(float(params.get("cell_draw_scale", 0.0)), 0.5, "cell art is drawn at half size")
	eq(str(params.get("art_status", "")), "placeholder", "coilgate art is still the stand-in set")
	truthy(params.has("pulse_hz"), "pulse speed is in the floor json")
	truthy(params.has("pulse_amount"), "pulse amount is in the floor json")
	truthy(params.has("z_order"), "z order is in the floor json")
	var slots: Dictionary = params.get("slots", {})
	var expected := {
		"floor_tiles": [512, 64],
		"pad_blue": [128, 96],
		"pad_red": [128, 96],
		"light_pillar": [128, 512],
		"room_edge_dark": [1024, 640],
		"glow_mask": [512, 64],
	}
	for slot in expected.keys():
		var path := FLOOR.resolve_slot(slot)
		truthy(path.ends_with(slot + ".png"), "%s resolves to its slot file" % slot)
		var tex := load(path) as Texture2D
		truthy(tex != null, "%s loads" % slot)
		var spec: Dictionary = slots.get(slot, {})
		var px: Array = spec.get("px", [])
		var want: Array = expected[slot]
		eq(px.size() >= 2 and int(px[0]) == int(want[0]) and int(px[1]) == int(want[1]), true, "%s json size" % slot)
		if tex != null:
			eq(tex.get_width(), int(want[0]), "%s width" % slot)
			eq(tex.get_height(), int(want[1]), "%s height" % slot)
		_check_import(path, str(spec.get("compress", "lossless")))
	eq(FLOOR.choose_path(FLOOR.art_root(), "missing_slot"), "", "a missing slot resolves to empty")
	var src := FileAccess.get_file_as_string("res://board/pc/coilgate_floor.gd")
	truthy(src.contains("float intensity = tex.r;"), "glow intensity is the red channel")
	truthy(src.contains("float flow = tex.g;"), "the flow gradient is the green channel")
	eq(src.contains("max(tex.r"), false, "the glow shader does not collapse the mask to greyscale")
	truthy(src.contains("hole_mask"), "the room hole is a generated mask")
	truthy(src.contains("blend_add"), "pillars and pads stay additive")
	var room_spec: Dictionary = slots.get("room_edge_dark", {})
	eq(str(room_spec.get("layout", "")), "generated_footprint", "the surround hole comes from the cell footprint")
	var floor_spec: Dictionary = slots.get("floor_tiles", {})
	var glow_spec: Dictionary = slots.get("glow_mask", {})
	eq(floor_spec.get("slices", []), glow_spec.get("slices", []), "floor and glow strips share slot order")
	eq(str(glow_spec.get("format", "")), "rgb", "glow_mask is an RGB png")
	var channels: Dictionary = glow_spec.get("channels", {})
	eq(str(channels.get("r", "")), "glow_intensity", "red holds the glow intensity")
	eq(str(channels.get("g", "")), "flow_gradient", "green holds the flow gradient")
	var glow_tex := load(FLOOR.resolve_slot("glow_mask")) as Texture2D
	var glow_img := glow_tex.get_image()
	var fmt := glow_img.get_format()
	eq(fmt == Image.FORMAT_L8 or fmt == Image.FORMAT_LA8, false, "glow_mask is stored as color, not greyscale")
	var split := false
	for y in glow_img.get_height():
		for x in glow_img.get_width():
			var px := glow_img.get_pixel(x, y)
			if absf(px.r - px.g) > 0.04:
				split = true
				break
		if split:
			break
	truthy(split, "glow_mask red and green carry different data")


func _test_board_wires_the_theme() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	truthy(view.contains("res://board/pc/coilgate_floor.gd"), "board_view preloads the coilgate floor")
	truthy(view.contains("set_board_theme"), "board_view can select a theme")
	eq(view.contains("class_name"), false, "board_view does not declare a class_name")
	var sim := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim.contains("coilgate_floor"), false, "CombatSim does not know about the floor theme")
	var preview := FileAccess.get_file_as_string("res://scenes/pc/look_preview.gd")
	truthy(preview.contains("coilgate"), "the preview arena asks for the coilgate theme")
	truthy(preview.contains("stormspire"), "the preview loads an existing arena, not a dungeon run")
	eq(preview.contains("dungeon"), false, "the preview does not start a dungeon")
	truthy(preview.contains("use_hdr_2d"), "the preview can turn on 2D HDR")
	truthy(preview.contains("PreviewGlow"), "the preview adds a glow environment")
	var project := FileAccess.get_file_as_string("res://project.godot")
	eq(project.contains("hdr_2d"), false, "2D HDR stays off for the rest of the game")
	eq(FileAccess.get_file_as_string("res://main.tscn").contains("WorldEnvironment"), false, "the main scene has no glow environment")


func _test_live_theme() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	truthy(bool(board.get("_booted")), "board finished boot")
	var sim := root.get_node("CombatSim")
	sim.reset_match({
		"seed": 1,
		"map_id": "stormspire",
		"skip_deploy": true,
	})
	board._refresh()
	var before: Dictionary = sim.snapshot()
	var layer = board.get_node_or_null("CoilgateFloor")
	truthy(layer != null, "the floor node exists")
	if layer == null:
		main.free()
		return
	eq(layer.themed_cell_count(), 0, "the theme stays off until it is selected")
	FLOOR.request_theme("coilgate")
	board.set_board_theme("coilgate")
	eq(layer.themed_cell_count(), 225, "every cell wears a coilgate floor plate")
	var sample: Node = board.tiles[Vector2i(4, 4)]
	var plate: Texture2D = sample.look_floor()
	truthy(plate != null, "a cell keeps its floor texture")
	if plate != null:
		eq(plate.get_width(), 128, "the live floor plate is the @2x master")
		eq(plate.get_height(), 64, "the live floor plate is 64 tall at 2x")
	truthy(layer.room_is_behind(), "the dark room sits behind the cells")
	eq(int(layer.room_texture_size().x), 1024, "the room gradient is 1024 wide")
	eq(int(layer.room_texture_size().y), 640, "the room gradient is 640 tall")
	truthy(layer.room_scale() > 1.0, "the room gradient is scaled up")
	truthy(layer.hole_is_generated(), "the board hole is generated from the cells")
	var atlas: Vector2 = layer.floor_atlas_size()
	eq(int(atlas.x), 512, "floor tiles are one 512-wide strip")
	eq(int(atlas.y), 64, "the floor strip is 64 tall")
	truthy(is_equal_approx(layer.pad_offset_y(), -16.0), "the pad diamond sits on the cell and the cap rises")
	var room_at: Vector2 = layer.room_position()
	eq(layer.get_node_or_null("RoomEdge") != null, true, "the surround is one sprite")
	eq(layer.pillar_count(), 5, "five key cells raise a light pillar")
	truthy(is_equal_approx(layer.pillar_display_width(), 64.0), "a pillar is one cell wide at half size")
	var atlas_size: Vector2 = layer.glow_atlas_size()
	eq(int(atlas_size.x), 512, "glow_mask is one 512-wide strip")
	eq(int(atlas_size.y), 64, "glow_mask is 64 tall")
	var glow := 0
	var pads := 0
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		if tile.get_node_or_null("CoilGlow") != null:
			glow += 1
		if tile.get_node_or_null("CoilPad") != null:
			pads += 1
	truthy(glow > 0, "painted cells wear a glow prop")
	truthy(pads > 0, "the floor has glowing pads")
	var origin: Vector2 = (board.tiles[Vector2i(7, 7)] as Node2D).position
	layer.preview_time(0.0)
	var low: float = layer.floor_pulse()
	layer.preview_time(1.0 / float(FLOOR.load_params()["pulse_hz"]) * 0.25)
	var high: float = layer.floor_pulse()
	truthy(absf(high - low) > 0.02, "the floor pulse moves")
	eq((board.tiles[Vector2i(7, 7)] as Node2D).position, origin, "the theme does not move a cell")
	var cam := board.get_node("BoardCamera") as Camera2D
	var parked: Vector2 = cam.position
	cam.position = parked + Vector2(80, 40)
	await process_frame
	eq(layer.room_position(), room_at, "the surround stays on the board when the camera pans")
	cam.position = parked
	var after: Dictionary = sim.snapshot()
	eq(str(after.get("map_id", "")), str(before.get("map_id", "")), "the theme does not change the map id")
	eq(int(after.get("board_size", 0)), int(before.get("board_size", 0)), "the theme does not change the board size")
	var changed := 0
	for cell in before.get("tiles", {}).keys():
		var was: Dictionary = before["tiles"][cell]
		var now: Dictionary = after["tiles"][cell]
		if str(was.get("terrain_type", "")) != str(now.get("terrain_type", "")):
			changed += 1
		if int(was.get("elevation", 0)) != int(now.get("elevation", 0)):
			changed += 1
	eq(changed, 0, "terrain and elevation stay on the snapshot")
	board.set_board_theme("")
	eq(layer.themed_cell_count(), 0, "clearing the theme restores the arena dress")
	eq(layer.pillar_count(), 0, "clearing the theme removes the pillars")
	eq(layer.visible, false, "clearing the theme hides the room")
	main.free()
	FLOOR.request_theme("")


func _check_import(path: String, mode: String) -> void:
	var text := FileAccess.get_file_as_string(path + ".import")
	truthy(text.contains("mipmaps/generate=false"), "%s has no mipmaps" % path)
	if mode == "vram_bc7":
		truthy(text.contains("compress/mode=2"), "%s uses VRAM compression" % path)
		truthy(text.contains("compress/high_quality=true"), "%s asks for BC7 quality" % path)
	else:
		truthy(text.contains("compress/mode=0"), "%s stays lossless" % path)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
		return
	_failed += 1
	print("FAIL %s | expected %s | got %s" % [msg, str(expected), str(actual)])


func truthy(value: bool, msg: String) -> void:
	eq(value, true, msg)
