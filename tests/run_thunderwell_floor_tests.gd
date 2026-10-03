extends SceneTree

## Thunderwell floor theme: slots resolve, the layer loads, cells stay visible.
## Run: godot --headless --path . -s res://tests/run_thunderwell_floor_tests.gd

const FLOOR := preload("res://board/pc/thunderwell_floor.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_test_params_and_slots()
	_test_board_wires_the_theme()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_live_theme()
	print("Thunderwell floor tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_params_and_slots() -> void:
	var params := FLOOR.load_params()
	eq(str(params.get("theme", "")), "thunderwell", "the json names the thunderwell theme")
	eq(str(params.get("display_name", "")), "Thunderwell Core", "the display name is Thunderwell Core")
	eq(float(params.get("cell_draw_scale", 0.0)), 0.5, "cell art is drawn at half size")
	eq(str(params.get("art_status", "")), "v1", "thunderwell art is the approved v1 set")
	truthy(FileAccess.file_exists(FLOOR.art_root() + "README.md"), "the floor folder ships the art readme")
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
		truthy(path.ends_with(slot + "@2x.png"), "%s resolves to its @2x master" % slot)
		var tex := load(path) as Texture2D
		truthy(tex != null, "%s loads" % slot)
		var fallback := load(FLOOR.slot_path_1x(slot)) as Texture2D
		truthy(fallback != null, "%s 1x fallback loads" % slot)
		var spec: Dictionary = slots.get(slot, {})
		var px: Array = spec.get("px", [])
		var want: Array = expected[slot]
		eq(px.size() >= 2 and int(px[0]) == int(want[0]) and int(px[1]) == int(want[1]), true, "%s json size" % slot)
		if tex != null:
			eq(tex.get_width(), int(want[0]), "%s width" % slot)
			eq(tex.get_height(), int(want[1]), "%s height" % slot)
		if tex != null and fallback != null:
			eq(fallback.get_width() * 2, tex.get_width(), "%s 1x is half the master width" % slot)
			eq(fallback.get_height() * 2, tex.get_height(), "%s 1x is half the master height" % slot)
		_check_import(path, str(spec.get("compress", "lossless")))
		_check_import(FLOOR.slot_path_1x(slot), str(spec.get("compress", "lossless")))
	eq(FLOOR.choose_path(FLOOR.art_root(), "missing_slot"), "", "a missing slot resolves to empty")
	var src := FileAccess.get_file_as_string("res://board/pc/thunderwell_floor.gd")
	var glow_src := src.substr(src.find("const GLOW_SHADER"), src.find("const PAD_SHADER") - src.find("const GLOW_SHADER"))
	truthy(src.contains("float intensity = tex.r;"), "glow intensity is the red channel")
	truthy(src.contains("float flow = tex.g;"), "the flow gradient is the green channel")
	truthy(glow_src.contains("float glow = intensity * glow_strength * pulse;"), "trace glow is R times strength times pulse(G)")
	truthy(glow_src.contains("uniform sampler2D mask_tex : filter_linear, repeat_disable;"), "the mask is sampled with a linear filter")
	eq(glow_src.contains("source_color"), false, "the mask sampler has no source_color hint")
	eq(glow_src.contains("texture(TEXTURE"), false, "the mask is not sampled through the color texture")
	truthy(src.contains("texture(TEXTURE, UV)"), "floor pads, the pillar and the room keep the color sampler")
	eq(src.contains("coilgate"), false, "the floor script does not use the old phone name")
	eq(float(params.get("glow_strength", 0.0)), FLOOR.glow_strength(), "the trace strength loads from the json")
	eq(float(params.get("pad_strength", 0.0)), FLOOR.pad_strength(), "the pad strength loads from the json")
	eq(float(params.get("pillar_strength", 0.0)), FLOOR.pillar_strength(), "the pillar strength loads from the json")
	eq(float(params.get("pillar_strength", 0.0)), 0.45, "the pillar strength stays at 0.45 so it does not wash the cell")
	_assert_json_color(params, "glow_color", FLOOR.glow_color(), "glow")
	_assert_json_color(params, "pillar_color", FLOOR.pillar_color(), "pillar")
	_assert_json_color(params, "pad_blue_color", FLOOR.pad_blue_color(), "pad blue")
	_assert_json_color(params, "pad_red_color", FLOOR.pad_red_color(), "pad red")
	truthy(src.contains("uniform vec3 glow_color"), "the glow shader reads the theme colour")
	truthy(src.contains("uniform float glow_strength"), "the trace cap is a shader uniform")
	truthy(src.contains("uniform float pad_strength"), "the pad cap is a shader uniform")
	truthy(src.contains("uniform float pillar_strength"), "the pillar cap is a shader uniform")
	truthy(src.contains("uniform vec3 pillar_color"), "the pillar tint is a shader uniform")
	truthy(src.contains("tex.rgb * pad_strength"), "pads keep the painted hue and only scale it")
	eq(src.contains("vec3(0.55, 0.95, 1.0)"), false, "the floor glow is not a hardcoded sky cyan")
	eq(src.contains("Color(0.45, 0.85, 1.0)"), false, "pads are not a hardcoded sky cyan")
	eq(src.contains("Color(0.75, 1.0, 1.0)"), false, "pillars are not a hardcoded sky cyan")
	eq(src.contains("Color(1.0, 0.45, 0.4)"), false, "pads are not a hardcoded orange")
	var loaded := FLOOR.glow_color()
	truthy(absf(_hue_gap(_hue_deg(loaded), 140.0)) <= 6.0, "the trace tint is green near 140 degrees")
	_assert_hue_separated(loaded)
	var pillar := FLOOR.pillar_color()
	var pillar_span := maxf(pillar.r, maxf(pillar.g, pillar.b)) - minf(pillar.r, minf(pillar.g, pillar.b))
	truthy(pillar_span / maxf(pillar.r, maxf(pillar.g, pillar.b)) < 0.25, "the pillar tint is a pale low-saturation green-white")
	truthy(absf(_hue_gap(_hue_deg(pillar), 140.0)) <= 8.0, "the pillar tint stays on the green side of 140 degrees")
	_assert_hue_separated(pillar)
	truthy(absf(_hue_gap(_hue_deg(FLOOR.pad_blue_color()), 225.0)) <= 6.0, "the pad blue target is deep cobalt near 225 degrees")
	truthy(absf(_hue_gap(_hue_deg(FLOOR.pad_red_color()), 350.0)) <= 6.0, "the pad red target is crimson near 350 degrees")
	var move := BoardTile.new()
	move.highlight = "move"
	truthy(_rel_lum(FLOOR.pad_blue_color()) < _rel_lum(move.overlay_color()), "the pad blue target is darker than a move tile")
	move.free()
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
	var blue := 0.0
	for y in glow_img.get_height():
		for x in glow_img.get_width():
			var px := glow_img.get_pixel(x, y)
			blue = maxf(blue, px.b)
			if absf(px.r - px.g) > 0.04:
				split = true
	truthy(split, "glow_mask red and green carry different data")
	truthy(blue <= 0.004, "glow_mask blue channel is 0")


func _test_board_wires_the_theme() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	truthy(view.contains("res://board/pc/thunderwell_floor.gd"), "board_view preloads the thunderwell floor")
	eq(view.contains("coilgate"), false, "board_view does not use the old phone name")
	truthy(view.contains("set_board_theme"), "board_view can select a theme")
	eq(view.contains("class_name"), false, "board_view does not declare a class_name")
	var sim := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim.contains("thunderwell_floor"), false, "CombatSim does not know about the floor theme")
	var preview := FileAccess.get_file_as_string("res://scenes/pc/look_preview.gd")
	truthy(preview.contains("thunderwell"), "the preview arena asks for the thunderwell theme")
	truthy(preview.contains("stormspire"), "the preview loads an existing arena, not a dungeon run")
	eq(preview.contains("dungeon"), false, "the preview does not start a dungeon")
	truthy(preview.contains("use_hdr_2d"), "the preview can turn on 2D HDR")
	truthy(preview.contains("FLOOR.glow_strength()"), "the preview bloom follows the trace strength")
	truthy(preview.contains("FLOOR.pad_strength()"), "the preview bloom follows the pad strength")
	truthy(preview.contains("FLOOR.pillar_strength()"), "the preview bloom follows the pillar strength")
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
	var layer = board.get_node_or_null("ThunderwellFloor")
	truthy(layer != null, "the floor node exists")
	if layer == null:
		main.free()
		return
	eq(layer.themed_cell_count(), 0, "the theme stays off until it is selected")
	FLOOR.request_theme("thunderwell")
	board.set_board_theme("thunderwell")
	eq(layer.themed_cell_count(), 225, "every cell wears a thunderwell floor plate")
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
	var pillar_sprite := layer.get_node_or_null("ThunderPillar") as Sprite2D
	truthy(pillar_sprite != null and pillar_sprite.centered == false, "the pillar sprite anchors from its bottom")
	if pillar_sprite != null and pillar_sprite.texture != null:
		var cell: Vector2i = pillar_sprite.get_meta("cell")
		var anchor: Node2D = board.tiles[cell]
		eq(pillar_sprite.position, anchor.position, "the pillar stands on its cell")
		eq(pillar_sprite.z_index, (cell.x + cell.y) * 10, "the pillar sorts with its cell, under the fighter")
		eq(pillar_sprite.z_as_relative, false, "the pillar sort is in board space")
		eq(pillar_sprite.offset, Vector2(-pillar_sprite.texture.get_width() * 0.5, -float(pillar_sprite.texture.get_height())), "the pillar offset is bottom-centre")
	var atlas_size: Vector2 = layer.glow_atlas_size()
	eq(int(atlas_size.x), 512, "glow_mask is one 512-wide strip")
	eq(int(atlas_size.y), 64, "glow_mask is 64 tall")
	var glow := 0
	var pads := 0
	var glow_tile: Node = null
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		if tile.get_node_or_null("ThunderGlow") != null:
			glow += 1
			glow_tile = tile
		if tile.get_node_or_null("ThunderPad") != null:
			pads += 1
	truthy(glow > 0, "painted cells wear a glow prop")
	var glow_sprite: CanvasItem = null
	if glow_tile != null:
		glow_sprite = glow_tile.get_node_or_null("ThunderGlow") as CanvasItem
	truthy(glow_sprite != null, "a painted cell has a glow sprite")
	if glow_sprite != null:
		glow_tile.set_highlight("move")
		var overlay := glow_tile.get_node_or_null("Highlight") as CanvasItem
		truthy(overlay != null and overlay.z_index > glow_sprite.z_index, "move tiles draw above the floor glow")
		var mat := glow_sprite.material as ShaderMaterial
		_assert_trace_uniforms(mat)
	var pad_sprite: CanvasItem = null
	for cell in board.tiles.keys():
		var pad := (board.tiles[cell] as Node).get_node_or_null("ThunderPad") as CanvasItem
		if pad != null:
			pad_sprite = pad
			break
	if pad_sprite != null:
		_assert_pad_uniforms(pad_sprite.material as ShaderMaterial)
	truthy(layer.pillar_count() > 0, "a pillar is up for the colour check")
	var pillar := layer.get_node_or_null("ThunderPillar") as CanvasItem
	if pillar != null:
		_assert_pillar_uniforms(pillar.material as ShaderMaterial)
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


func _assert_json_color(params: Dictionary, key: String, loaded: Color, label: String) -> void:
	var raw: Array = params.get(key, [])
	eq(raw.size(), 3, "the %s colour is a json rgb triple" % label)
	if raw.size() < 3:
		return
	truthy(is_equal_approx(loaded.r, float(raw[0])) and is_equal_approx(loaded.g, float(raw[1])) and is_equal_approx(loaded.b, float(raw[2])), "the %s colour loads from the json" % label)


func _assert_trace_uniforms(mat: ShaderMaterial) -> void:
	truthy(mat != null, "the trace glow has a shader")
	if mat == null:
		return
	_assert_vec3(mat, "glow_color", FLOOR.glow_color(), "the trace glow")
	truthy(is_equal_approx(float(mat.get_shader_parameter("glow_strength")), FLOOR.glow_strength()), "the trace glow loads the json strength")


func _assert_pad_uniforms(mat: ShaderMaterial) -> void:
	truthy(mat != null, "the pad has a shader")
	if mat == null:
		return
	truthy(is_equal_approx(float(mat.get_shader_parameter("pad_strength")), FLOOR.pad_strength()), "the pad loads the json strength")
	eq(mat.get_shader_parameter("glow_color") == null, true, "the pad shader does not recolour with the glow tint")
	eq(mat.get_shader_parameter("pillar_color") == null, true, "the pad shader does not recolour with the pillar tint")


func _assert_pillar_uniforms(mat: ShaderMaterial) -> void:
	truthy(mat != null, "the pillar has a shader")
	if mat == null:
		return
	_assert_vec3(mat, "pillar_color", FLOOR.pillar_color(), "the pillar")
	truthy(is_equal_approx(float(mat.get_shader_parameter("pillar_strength")), FLOOR.pillar_strength()), "the pillar loads the json strength")


func _assert_vec3(mat: ShaderMaterial, key: String, want: Color, label: String) -> void:
	var got: Variant = mat.get_shader_parameter(key)
	truthy(got is Vector3, "%s colour is a vector" % label)
	if got is Vector3:
		var rgb: Vector3 = got
		truthy(is_equal_approx(rgb.x, want.r) and is_equal_approx(rgb.y, want.g) and is_equal_approx(rgb.z, want.b), "%s loads the json colour" % label)


func _rel_lum(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


func _assert_hue_separated(glow: Color) -> void:
	var tile := BoardTile.new()
	var kinds := ["move", "advance", "origin", "landing", "range", "target", "selected"]
	for kind in kinds:
		tile.highlight = kind
		tile.is_selected = false
		var flat := tile.overlay_color()
		var gap := _hue_gap(_hue_deg(glow), _hue_deg(flat))
		truthy(gap >= 40.0, "glow hue stays clear of the %s highlight (%s deg)" % [kind, snappedf(gap, 0.1)])
	tile.free()


func _hue_deg(color: Color) -> float:
	var max_c := maxf(color.r, maxf(color.g, color.b))
	var min_c := minf(color.r, minf(color.g, color.b))
	var span := max_c - min_c
	if span < 0.001:
		return 0.0
	var hue := 0.0
	if max_c == color.r:
		hue = fmod((color.g - color.b) / span, 6.0)
	elif max_c == color.g:
		hue = (color.b - color.r) / span + 2.0
	else:
		hue = (color.r - color.g) / span + 4.0
	return fmod(hue * 60.0 + 360.0, 360.0)


func _hue_gap(a: float, b: float) -> float:
	var gap := absf(a - b)
	return minf(gap, 360.0 - gap)


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
