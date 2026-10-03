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
	eq(str(params.get("art_status", "")), "v4", "jungle art is the approved v4 set")
	truthy(FileAccess.file_exists(JUNGLE.art_root() + "README.md"), "the jungle folder ships the art readme")
	eq(str(params.get("sway_mode", "")), "mask_shader", "leaf sway is a mask shader")
	eq(bool(params.get("sway_mask", false)), true, "each leaf layer has a sway mask")
	eq(bool(params.get("flipbook", true)), false, "leaf sway is not a flipbook")
	eq(float(params["parallax"]["back_far"]), 0.12, "far parallax factor")
	eq(float(params["parallax"]["back_mid"]), 0.4, "mid parallax factor")
	eq(float(params["parallax"]["front_leaves"]), 0.0, "front leaves are screen-locked")
	eq(float(params.get("pan_limit_px", 0.0)), 220.0, "pan limit matches the camera")
	truthy(str(params.get("parallax_meaning", "")).contains("on screen"), "the parallax comment is the on-screen fraction")
	truthy(params.has("parallax"), "parallax block is in the backdrop json")
	truthy(params.has("sway_amplitude_px"), "sway amplitude is in the backdrop json")
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
		truthy(path.ends_with(slot + "@2x.png"), "%s resolves to the @2x master" % slot)
		var tex := load(path) as Texture2D
		truthy(tex != null, "%s loads" % slot)
		var spec: Dictionary = slots.get(slot, {})
		var px: Array = spec.get("px", [])
		if tex != null and px.size() >= 2:
			eq(tex.get_width(), int(px[0]), "%s width" % slot)
			eq(tex.get_height(), int(px[1]), "%s height" % slot)
		_check_import(path, str(spec.get("compress", "lossless")))
		var fallback := load(JUNGLE.slot_path_1x(slot)) as Texture2D
		truthy(fallback != null, "%s 1x fallback loads" % slot)
		if tex != null and fallback != null:
			eq(fallback.get_width() * 2, tex.get_width(), "%s 1x is half the master width" % slot)
			eq(fallback.get_height() * 2, tex.get_height(), "%s 1x is half the master height" % slot)
		_check_import(JUNGLE.slot_path_1x(slot), str(spec.get("compress", "lossless")))
	eq(JUNGLE.choose_path(JUNGLE.art_root(), "missing_slot"), "", "a missing slot resolves to empty")
	var src := FileAccess.get_file_as_string("res://board/pc/jungle_backdrop.gd")
	var hi := src.find("slot + \"@2x.png\"")
	var lo := src.find("slot + \".png\"")
	truthy(hi >= 0 and lo > hi, "@2x is checked before the 1x png")
	eq(JUNGLE.normalize_map_id("crosshaven_15"), "crosshaven", "ship suffix still means Crosshaven")
	eq(JUNGLE.normalize_map_id(""), "crosshaven", "an empty map id is the Crosshaven arena")
	var expected := {
		"back_far": [2048, 1280],
		"back_mid": [4096, 2560],
		"front_leaves_left": [1024, 1440],
		"front_leaves_right": [1024, 1440],
		"front_leaves_top": [2560, 480],
		"front_leaves_bottom": [2560, 480],
		"leaf_shadow": [1024, 1024],
	}
	for slot in expected.keys():
		var spec: Dictionary = slots.get(slot, {})
		var px: Array = spec.get("px", [])
		var want: Array = expected[slot]
		eq(px.size() >= 2 and int(px[0]) == int(want[0]) and int(px[1]) == int(want[1]), true, "%s contract" % slot)
	for slot in ["front_leaves_left", "front_leaves_right", "front_leaves_top", "front_leaves_bottom"]:
		var spec: Dictionary = slots.get(slot, {})
		var sway: Array = spec.get("sway", [])
		var sway_path: String = JUNGLE.art_root() + slot + "_sway.png"
		truthy(FileAccess.file_exists(sway_path), "%s sway mask is on disk" % slot)
		var sway_tex := load(sway_path) as Texture2D
		truthy(sway_tex != null, "%s sway mask loads" % slot)
		if sway_tex != null and sway.size() >= 2:
			eq(sway_tex.get_width(), int(sway[0]), "%s sway width" % slot)
			eq(sway_tex.get_height(), int(sway[1]), "%s sway height" % slot)
		_check_import(sway_path, "lossless")
	eq(src.contains("sway_tex"), true, "the sway shader samples the greyscale mask")
	var sway_at := src.find("const SWAY_SHADER")
	var sway_src := src.substr(sway_at, src.find("var _params") - sway_at)
	eq(sway_src.contains("source_color"), false, "the sway mask sampler has no color hint")
	truthy(sway_src.contains("void vertex()"), "the sway mask is sampled in the vertex shader")
	truthy(sway_src.contains("filter_linear"), "the sway mask uses a linear filter")
	eq(float(params.get("shadow_opacity", 0.0)), 0.55, "leaf shadow strength starts at 0.55")
	eq(float(params.get("top_fade_distance", 0.0)), 220.0, "the top canopy fades across the pan distance")
	var layers: Dictionary = params.get("layers", {})
	_assert_modulate(layers, "back_far", 0.75, "far canopy")
	_assert_modulate(layers, "back_mid", 0.80, "mid canopy")
	_assert_modulate(layers, "front_leaves", 0.68, "front leaves")
	var far_mod: Array = (layers["back_far"] as Dictionary)["modulate"]
	truthy(float(far_mod[2]) > float(far_mod[0]), "the far canopy modulate is cooler than neutral")
	var leaf_mod: Array = (layers["front_leaves"] as Dictionary)["modulate"]
	truthy(float(leaf_mod[2]) > float(leaf_mod[0]), "the front leaves carry a slight cool tint")
	eq(src.contains("COLOR.a *="), true, "front leaves fade in the shader")
	eq(src.contains("fighter_pos"), true, "the leaf shader cuts a hole per fighter")
	eq(src.contains("hover_on"), true, "the leaf shader cuts a hole on the hovered cell")
	eq(src.contains("MOUSE_FILTER_IGNORE"), true, "leaf controls do not pick the mouse")
	eq(src.contains("0.22, 0.48, 0.28"), true, "leaf shadows take a green tint")
	eq(src.contains("TIME * 0.012"), true, "leaf shadows scroll for canopy drift")


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
	cam.zoom = Vector2(0.64, 0.64)
	await _assert_back_plates_cover(layer, cam, board)
	var leaf := layer.get_node("front_leaves_left") as Control
	var leaf_at := leaf.position
	cam.position += Vector2(80, 0)
	layer.layout()
	truthy(leaf.position.x > leaf_at.x + 70.0, "front leaves stay locked to the screen")
	cam.position -= Vector2(80, 0)
	layer.layout()
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
	_assert_look_tunables(layer, cam, board)
	truthy(layer.pointer_passes(), "clicks pass through every leaf and backdrop control")
	var edge_cell := Vector2i(0, 14)
	var edge_tile: Node2D = board.tiles[edge_cell]
	layer.set_hover_cell(edge_cell)
	truthy(layer.leaf_cutout(edge_tile.position) < 0.02, "the hovered cell cuts the leaf")
	var beside := edge_tile.position + Vector2(-46.0, 0.0)
	truthy(layer.leaf_cutout(beside) < 0.55, "the hover hole reaches past the cell into the leaf")
	layer.set_hover_cell(Vector2i(-1, -1))
	truthy(layer.leaf_cutout(beside) > 0.9, "a point past the diamond stays painted when nothing is hovered")
	truthy(layer.leaf_cutout(Vector2(-1800, -1800)) > 0.95, "leaves stay opaque far from the board")
	var pawns: Dictionary = board.get("pawns_by_seat")
	truthy(layer.cutout_fighter_count() == pawns.size(), "each fighter gets a leaf hole")
	for pawn in pawns.values():
		var feet: Vector2 = board.to_local((pawn as Node2D).global_position)
		truthy(layer.leaf_cutout(feet) < 0.02, "a fighter's feet cut the leaf")
		truthy(layer.leaf_cutout(feet + Vector2(0, -70)) < 0.02, "a fighter's head cuts the leaf")
	var leaf_sprite := layer.get_node("front_leaves_left/Pivot/Art") as Sprite2D
	var leaf_mat := leaf_sprite.material as ShaderMaterial
	eq(int(leaf_mat.get_shader_parameter("fighter_count")), layer.cutout_fighter_count(), "the leaf shader receives the fighter count")
	eq(float(leaf_mat.get_shader_parameter("hover_on")), 0.0, "clearing the hover turns that hole off")
	layer.set_hover_cell(edge_cell)
	eq(float(leaf_mat.get_shader_parameter("hover_on")), 1.0, "the hovered cell is pushed to the leaf shader")
	var parked: Vector2 = cam.position
	var fit: Vector2 = board.get("_fit_camera_pos")
	cam.position = fit
	layer.layout()
	var step := Vector2(80, 0)
	cam.position = fit + step
	layer.layout()
	var far_screen: Vector2 = layer.back_art_position("back_far") - cam.position
	var mid_screen: Vector2 = layer.back_art_position("back_mid") - cam.position
	var far_fraction := float(JUNGLE.load_params()["parallax"]["back_far"])
	var mid_fraction := float(JUNGLE.load_params()["parallax"]["back_mid"])
	truthy(is_equal_approx(far_screen.x, -step.x * far_fraction), "far on-screen slide is its parallax fraction")
	truthy(is_equal_approx(mid_screen.x, -step.x * mid_fraction), "mid on-screen slide is its parallax fraction")
	truthy(absf(far_screen.x) + 0.5 < absf(mid_screen.x), "far canopy moves less on screen than the mid canopy")
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


func _assert_back_plates_cover(layer: Node, cam: Camera2D, board: Node2D) -> void:
	var saved_size := root.size
	var saved_pos := cam.position
	var saved_zoom := cam.zoom
	var fit: Vector2 = board.get("_fit_camera_pos")
	var limit := float(JUNGLE.load_params().get("pan_limit_px", 220.0))
	var aspects := {
		"16:9": Vector2i(1280, 720),
		"16:10": Vector2i(1152, 720),
		"21:9": Vector2i(1680, 720),
	}
	var pans: Array[Vector2] = [
		Vector2(limit, 0),
		Vector2(-limit, 0),
		Vector2(0, limit),
		Vector2(0, -limit),
		Vector2(limit, limit),
		Vector2(limit, -limit),
		Vector2(-limit, limit),
		Vector2(-limit, -limit),
	]
	cam.zoom = Vector2(0.64, 0.64)
	for aspect in aspects.keys():
		var want: Vector2i = aspects[aspect]
		root.size = want
		await process_frame
		layer.layout()
		var view_px := board.get_viewport_rect().size
		truthy(absf(view_px.x - float(want.x)) < 2.0 and absf(view_px.y - float(want.y)) < 2.0, "%s viewport is the window size" % aspect)
		for pan in pans:
			cam.position = fit + pan
			layer.layout()
			var world := Vector2(view_px.x / cam.zoom.x, view_px.y / cam.zoom.y)
			var view := Rect2(cam.position - world * 0.5, world)
			for slot in ["back_far", "back_mid"]:
				var plate_root := layer.get_node(slot) as Node2D
				var art := plate_root.get_node("Art") as Sprite2D
				var drawn := art.texture.get_size() * art.scale
				var center := plate_root.position + art.position
				var plate := Rect2(center - drawn * 0.5, drawn)
				var gap := 1.0
				truthy(plate.position.x <= view.position.x + gap, "%s %s pan %s hides the left edge" % [aspect, slot, pan])
				truthy(plate.position.y <= view.position.y + gap, "%s %s pan %s hides the top edge" % [aspect, slot, pan])
				truthy(plate.end.x >= view.end.x - gap, "%s %s pan %s hides the right edge" % [aspect, slot, pan])
				truthy(plate.end.y >= view.end.y - gap, "%s %s pan %s hides the bottom edge" % [aspect, slot, pan])
	root.size = saved_size
	cam.zoom = saved_zoom
	cam.position = saved_pos
	await process_frame
	layer.layout()


func _assert_modulate(layers: Dictionary, key: String, around: float, label: String) -> void:
	var spec: Dictionary = layers.get(key, {})
	var raw: Array = spec.get("modulate", [])
	eq(raw.size(), 3, "%s modulate is an rgb triple" % label)
	if raw.size() < 3:
		return
	var lum := 0.2126 * float(raw[0]) + 0.7152 * float(raw[1]) + 0.0722 * float(raw[2])
	truthy(absf(lum - around) <= 0.04, "%s modulate is about %.2f" % [label, around])


func _assert_look_tunables(layer: Node, cam: Camera2D, board: Node2D) -> void:
	var params := JUNGLE.load_params()
	var far := layer.get_node("back_far/Art") as CanvasItem
	var mid := layer.get_node("back_mid/Art") as CanvasItem
	var leaf := layer.get_node("front_leaves_left/Pivot/Art") as CanvasItem
	var far_mod: Array = params["layers"]["back_far"]["modulate"]
	var mid_mod: Array = params["layers"]["back_mid"]["modulate"]
	var leaf_mod: Array = params["layers"]["front_leaves"]["modulate"]
	truthy(_color_close(far.modulate, far_mod), "the far plate uses its json modulate")
	truthy(_color_close(mid.modulate, mid_mod), "the mid plate uses its json modulate")
	truthy(_color_close(leaf.modulate, leaf_mod), "a front leaf uses its json modulate")
	var skirt := layer.get_node_or_null("GroundSkirt") as Sprite2D
	truthy(skirt != null, "a procedural ground skirt sits under the board")
	if skirt != null:
		truthy(skirt.z_index < 0 and skirt.z_index > layer.back_z("back_mid"), "the skirt is under the board and over the mid canopy")
		var mat := skirt.material as ShaderMaterial
		truthy(is_equal_approx(float(mat.get_shader_parameter("strength")), float(params["ground_skirt"]["strength"])), "the skirt strength comes from the json")
	truthy(float(params["ground_skirt"]["strength"]) <= 0.2, "the cliff skirt no longer covers the clearing")
	truthy(float(params["ground_skirt"]["reach_cells"]) <= 1.5, "the cliff skirt stays shorter than a cell and a half")
	var contact := layer.get_node_or_null("ContactShadow") as Sprite2D
	truthy(contact != null, "a contact shadow rims the board where it meets the clearing")
	if contact != null:
		truthy(contact.z_index < 0 and contact.z_index > layer.back_z("back_mid"), "the contact shadow is under the board and over the mid canopy")
		var cmat := contact.material as ShaderMaterial
		truthy(is_equal_approx(float(cmat.get_shader_parameter("strength")), float(params["contact_shadow"]["strength"])), "the contact strength comes from the json")
		truthy(is_equal_approx(float(cmat.get_shader_parameter("width")), float(params["contact_shadow"]["width_cells"])), "the contact width comes from the json")
	truthy(is_equal_approx(layer.contact_rim_alpha(0.0), 0.0), "the contact rim is clear across cell interiors")
	var rim_width := float(params["contact_shadow"]["width_cells"])
	truthy(layer.contact_rim_alpha(rim_width) <= 0.02, "the contact rim ends at its json width")
	var rim_peak: float = layer.contact_rim_alpha(rim_width * 0.3)
	truthy(rim_peak > 0.2 and rim_peak < 0.55, "the contact rim is visible and stays subtle")
	var dapple: CanvasItem = (board.tiles[Vector2i(7, 7)] as Node).get_node_or_null("LeafDapple")
	truthy(dapple != null and dapple.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED, "the leaf shadow repeats on the cell")
	var fit: Vector2 = board.get("_fit_camera_pos")
	var saved := cam.position
	cam.position = fit
	layer.layout()
	truthy(is_equal_approx(layer.top_leaf_alpha(), 1.0), "the top canopy is fully visible at the default camera")
	var cover_default: float = layer.leaf_board_coverage()
	print("LEAF_COVERAGE default %.4f" % cover_default)
	truthy(cover_default <= 0.005, "front leaves cover none of the board at the default camera")
	var limit := float(params.get("pan_limit_px", 220.0))
	var pans := {
		"x+": Vector2(limit, 0),
		"x-": Vector2(-limit, 0),
		"y+": Vector2(0, limit),
		"y-": Vector2(0, -limit),
	}
	for name in pans.keys():
		cam.position = fit + pans[name]
		layer.layout()
		var cover: float = layer.leaf_board_coverage()
		print("LEAF_COVERAGE %s %.4f alpha %.3f" % [name, cover, layer.top_leaf_alpha()])
		truthy(cover <= 0.06, "front leaves stay off most of the board at pan %s" % name)
	cam.position = fit + Vector2(0, limit)
	layer.layout()
	truthy(layer.top_leaf_alpha() <= 0.02, "a full +y pan fades the top canopy out")
	cam.position = saved
	layer.layout()


func _color_close(got: Color, raw: Array) -> bool:
	return is_equal_approx(got.r, float(raw[0])) and is_equal_approx(got.g, float(raw[1])) and is_equal_approx(got.b, float(raw[2]))


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
