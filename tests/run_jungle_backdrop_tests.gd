extends SceneTree

## Crosshaven jungle backdrop: slots resolve, the layer loads, cells stay clear.
## Run: godot --headless --path . -s res://tests/run_jungle_backdrop_tests.gd

const JUNGLE := preload("res://board/pc/jungle_backdrop.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_test_params_and_slots()
	_test_board_wires_the_layer()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_live_layer()
	print("Jungle backdrop tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_params_and_slots() -> void:
	var params := JUNGLE.load_params()
	eq(str(params.get("art_status", "")), "placeholder", "jungle art is still the stand-in set")
	eq(float(params.get("draw_scale_2x", 0.0)), 0.5, "a 2x master is drawn at half size")
	eq(str(params.get("sway_mode", "")), "pivot_rotation", "leaf sway is a pivot rotation")
	eq(bool(params.get("sway_mask", true)), false, "leaf sway does not use a greyscale mask")
	eq(bool(params.get("flipbook", true)), false, "leaf sway is not a flipbook")
	eq(float(params["parallax"]["back_far"]), 0.12, "far parallax factor")
	eq(float(params["parallax"]["back_mid"]), 0.4, "mid parallax factor")
	truthy(params.has("parallax"), "parallax block is in the backdrop json")
	truthy(params.has("sway_amplitude_deg"), "sway amplitude is in the backdrop json")
	truthy(params.has("sway_speed"), "sway speed is in the backdrop json")
	truthy(params.has("shadow_opacity"), "shadow opacity is in the backdrop json")
	truthy(params.has("z_order"), "z order is in the backdrop json")
	var slots: Dictionary = params.get("slots", {})
	var names: Array[String] = [
		"back_far",
		"back_mid",
		"front_leaves_left",
		"front_leaves_right",
		"front_leaves_top",
		"front_leaves_bottom",
		"leaf_shadow",
	]
	for slot in names:
		var path := JUNGLE.resolve_slot(slot)
		truthy(path.ends_with(slot + "@2x.png"), "%s resolves to the @2x plate" % slot)
		var tex := load(path) as Texture2D
		truthy(tex != null, "%s @2x loads" % slot)
		var spec: Dictionary = slots.get(slot, {})
		var px: Array = spec.get("px_2x", [])
		if tex != null and px.size() >= 2:
			eq(tex.get_width(), int(px[0]), "%s @2x width" % slot)
			eq(tex.get_height(), int(px[1]), "%s @2x height" % slot)
		var low := JUNGLE.slot_path_1x(slot)
		truthy(FileAccess.file_exists(low), "%s 1x plate is on disk" % slot)
		var low_tex := load(low) as Texture2D
		truthy(low_tex != null, "%s 1x loads" % slot)
		var px1: Array = spec.get("px_1x", [])
		if low_tex != null and px1.size() >= 2:
			eq(low_tex.get_width(), int(px1[0]), "%s 1x width" % slot)
			eq(low_tex.get_height(), int(px1[1]), "%s 1x height" % slot)
	eq(JUNGLE.choose_path(JUNGLE.art_root(), "missing_slot"), "", "a missing slot resolves to empty")
	var src := FileAccess.get_file_as_string("res://board/pc/jungle_backdrop.gd")
	var hi := src.find("slot + \"@2x.png\"")
	var lo := src.find("slot + \".png\"")
	truthy(hi >= 0 and lo > hi, "@2x is checked before the 1x png")
	eq(JUNGLE.normalize_map_id("crosshaven_15"), "crosshaven", "ship suffix still means Crosshaven")
	eq(JUNGLE.normalize_map_id(""), "crosshaven", "an empty map id is the Crosshaven arena")
	var expected := {
		"back_far": [[2048, 1280], [4096, 2560]],
		"back_mid": [[2048, 1280], [4096, 2560]],
		"front_leaves_left": [[512, 720], [1024, 1440]],
		"front_leaves_right": [[512, 720], [1024, 1440]],
		"front_leaves_top": [[1280, 240], [2560, 480]],
		"front_leaves_bottom": [[1280, 240], [2560, 480]],
		"leaf_shadow": [[512, 512], [1024, 1024]],
	}
	for slot in expected.keys():
		var spec: Dictionary = slots.get(slot, {})
		var one: Array = spec.get("px_1x", [])
		var two: Array = spec.get("px_2x", [])
		var want: Array = expected[slot]
		eq(one.size() >= 2 and int(one[0]) == int(want[0][0]) and int(one[1]) == int(want[0][1]), true, "%s 1x contract" % slot)
		eq(two.size() >= 2 and int(two[0]) == int(want[1][0]) and int(two[1]) == int(want[1][1]), true, "%s 2x contract" % slot)
	eq(ResourceLoader.exists("res://art/pc/look/crosshaven_jungle/front_leaves_left_sway.png"), false, "there is no sway mask for the left leaves")
	eq(src.contains("pivot.rotation"), true, "the sway turns the leaf pivot")
	eq(src.contains("_sway.png"), false, "the backdrop script does not load a sway strip")


func _test_board_wires_the_layer() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	truthy(view.contains("res://board/pc/jungle_backdrop.gd"), "board_view preloads the jungle backdrop")
	truthy(view.contains("JUNGLE_BACKDROP.new()"), "board_view builds the backdrop layer")
	eq(view.contains("class_name"), false, "board_view does not declare a class_name")
	var sim := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim.contains("jungle_backdrop"), false, "CombatSim does not know about the backdrop")
	eq(sim.contains("crosshaven_backdrop"), false, "CombatSim does not read the look json")


func _test_live_layer() -> void:
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
		"map_id": "crosshaven",
		"skip_deploy": true,
	})
	board._refresh()
	var layer = board.get_node_or_null("JungleBackdrop")
	truthy(layer != null, "Crosshaven builds a JungleBackdrop")
	if layer == null:
		main.free()
		return
	truthy(layer.visible, "the jungle layer is showing on Crosshaven")
	var cam := board.get_node("BoardCamera") as Camera2D
	truthy(is_equal_approx(cam.zoom.x, 0.64), "the 15x15 fit zoom is 0.64")
	var far_art := layer.get_node("back_far/Art") as Sprite2D
	truthy(is_equal_approx(far_art.scale.x, 0.5), "the far plate is drawn at half the 2x master")
	var mid_art := layer.get_node("back_mid/Art") as Sprite2D
	truthy(is_equal_approx(mid_art.scale.x, 0.5), "the mid plate is drawn at half the 2x master")
	eq(layer.shadow_count(), 225, "every cell gets a leaf shadow")
	truthy(is_equal_approx(layer.shadow_opacity(), float(JUNGLE.load_params()["shadow_opacity"])), "shadow opacity comes from the json")
	truthy(layer.shadow_uses_multiply(), "leaf shadows use multiply")
	truthy(layer.back_z("back_far") < 0, "the far canopy sits behind the board")
	truthy(layer.back_z("back_mid") < 0, "the mid canopy sits behind the board")
	truthy(layer.back_z("back_far") < layer.back_z("back_mid"), "far canopy is behind the mid canopy")
	truthy(layer.front_z() > 400, "front leaves paint in front of the board")
	truthy(layer.front_z() < 900, "front leaves stay under combat numbers")
	var origin: Vector2 = (board.tiles[Vector2i(7, 7)] as Node2D).position
	layer.layout()
	eq((board.tiles[Vector2i(7, 7)] as Node2D).position, origin, "the backdrop does not move a cell")
	eq(layer.leaves_cover_play(), false, "front leaves do not cover the play cells")
	var parked: Vector2 = cam.position
	layer.layout()
	var far_0: Vector2 = layer.back_art_position("back_far")
	var mid_0: Vector2 = layer.back_art_position("back_mid")
	cam.position = parked + Vector2(80, 0)
	layer.layout()
	var far_d: Vector2 = layer.back_art_position("back_far") - far_0
	var mid_d: Vector2 = layer.back_art_position("back_mid") - mid_0
	truthy(far_d.x + 0.5 < mid_d.x, "far canopy parallax lags the mid canopy")
	truthy(mid_d.x < 70.0, "mid canopy lags a full camera step")
	truthy(far_d.x > 1.0, "far canopy still drifts a little")
	eq(layer.leaves_cover_play(), false, "a panned camera still keeps leaves off the cells")
	cam.position = parked
	layer.layout()
	sim.reset_match({
		"seed": 1,
		"map_id": "brinewake",
		"skip_deploy": true,
	})
	board._refresh()
	eq(layer.visible, false, "the jungle layer hides on other arenas")
	eq(layer.shadow_count(), 0, "other arenas do not keep leaf shadows")
	sim.reset_match({
		"seed": 1,
		"map_id": "crosshaven",
		"skip_deploy": true,
	})
	board._refresh()
	truthy(layer.visible, "Crosshaven brings the jungle layer back")
	eq(layer.shadow_count(), 225, "Crosshaven restores a shadow on every cell")
	eq(layer.leaves_cover_play(), false, "restored leaves still miss the cells")
	layer.set_enabled(false)
	eq(layer.visible, false, "the layer can be switched off for a before shot")
	eq(layer.shadow_count(), 0, "switching the layer off clears the shadows")
	layer.set_enabled(true)
	truthy(layer.visible, "the layer switches back on")
	eq(layer.leaves_cover_play(), false, "leaves still miss the cells after a toggle")
	main.free()


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
		return
	_failed += 1
	print("FAIL %s | expected %s | got %s" % [msg, str(expected), str(actual)])


func truthy(value: bool, msg: String) -> void:
	eq(value, true, msg)
