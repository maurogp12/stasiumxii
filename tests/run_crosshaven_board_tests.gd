extends SceneTree

## L9 Crosshaven board. PC and crosshaven_15 only. The phone path and the
## shared tiles stay as they are. Cell, height and prop-cell data do not change.
## Run: godot --headless --path . -s res://tests/run_crosshaven_board_tests.gd

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const HUD := preload("res://ui/hud.gd")
const SORT := preload("res://board/visual_sort.gd")
const TAGS := "res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json"
const GROUND := "res://art/maps/arena_colosseum_v2/tiled/tiles/ground.png"

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_test_ids_and_files()
	_test_terrace_schema()
	_test_data_stays()
	_test_locked_calls()
	_test_grounds_water_and_cover()
	_test_phone_gate()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_live()
	HUD.set_pc_chrome_override(-1)
	BOARD.set_suppressed(false)
	print("Crosshaven board tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_ids_and_files() -> void:
	var looks := BOARD.load_looks()
	eq(str(looks.get("map_id", "")), "crosshaven_15", "looks.json is the crosshaven_15 board")
	eq(int(looks.get("version", 0)), 1, "the kit version field stays an int")
	truthy(FileAccess.file_exists(BOARD.ART_ROOT + "README.md"), "the kit ships its readme")
	var readme := FileAccess.get_file_as_string(BOARD.ART_ROOT + "README.md")
	truthy(readme.begins_with("# l9_outdoor_board:") and readme.contains("— v1.3"), "the art on disk is the v1.3 pass")
	var pair_script := load("res://tests/pc/pair_match.gd")
	eq(int(pair_script.SEED), 1, "before/after pairs share match seed 1")
	for capture_path in ["res://tests/pc/capture_l9.gd", "res://tests/pc/capture_l9_clip.gd", "res://tests/pc/capture_l9_grade.gd", "res://tests/pc/capture_l7.gd", "res://tests/pc/capture_l7_clip.gd", "res://tests/pc/capture_l7_grade.gd"]:
		var capture := FileAccess.get_file_as_string(capture_path)
		truthy(capture.contains("pair_match.gd"), "%s boots from the shared match" % capture_path)
		eq(capture.contains("\"seed\":"), false, "%s does not pick a second match seed" % capture_path)
	var missing := BOARD.unresolved_ids()
	eq(missing.size(), 0, "every looks.json id resolves to a file (%s)" % " ".join(missing))
	eq(BOARD.load_catalog().size(), 15, "the kit lists 15 props")
	for spec in BOARD.load_catalog():
		if spec is Dictionary:
			eq(str(spec.get("blocks", "")), "none", "prop %s writes blocks none" % str(spec.get("id", "")))
			eq(BOARD.prop_blocks(spec), "none", "prop %s does not block" % str(spec.get("id", "")))
	var sample := BOARD.piece_path("tiles", "grass_top_a")
	truthy(sample.ends_with("grass_top_a@2x.png"), "the loader prefers the @2x master")
	eq(BOARD.draw_scale_for(sample), BOARD.DRAW_SCALE, "an @2x master draws at half scale")
	var ground := load(GROUND) as Texture2D
	truthy(ground != null and ground.get_width() == 64, "the shared ground sheet stays 64 px wide")
	var ruins := load("res://board/koliseo_art.gd").prop_texture("ruins") as Texture2D
	truthy(ruins != null and ruins.get_height() == 112, "the shared ruins sheet stays 112 px tall")
	var sim := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim.contains("crosshaven_board"), false, "CombatSim does not know about the board look")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("_sync_crosshaven_board"), "board_view syncs the Crosshaven look")
	var tile := FileAccess.get_file_as_string("res://board/tile.gd")
	truthy(tile.contains("_hide_stock"), "stock props hide through the tile, the Thunderwell way")
	var pngs := 0
	for folder in ["tiles", "terrace", "props"]:
		var dir := DirAccess.open(BOARD.ART_ROOT + folder)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.ends_with(".png") and not name.ends_with(".import"):
				pngs += 1
				var text := FileAccess.get_file_as_string(BOARD.ART_ROOT + folder + "/" + name + ".import")
				truthy(text.contains("compress/mode=0"), "%s stays lossless" % name)
				truthy(text.contains("mipmaps/generate=false"), "%s has no mipmaps" % name)
			name = dir.get_next()
	eq(pngs, 136, "the kit is 136 pngs, including the water faces and the stone-flag stand-ins")


func _test_terrace_schema() -> void:
	eq(BOARD.step_px_2x(), 20.0, "one terrace step is 20 px at 2x")
	var by_id := {}
	for entry in BOARD.terrace_entries():
		if entry is Dictionary:
			by_id[str(entry.get("id", ""))] = entry
	eq(BOARD.terrace_origin(by_id["cliff_left_h1"]), Vector2(-32, 0), "the left face hangs from the west edge")
	eq(BOARD.terrace_origin(by_id["cliff_right_h2"]), Vector2(0, 0), "the right face hangs from the east edge")
	eq(BOARD.terrace_origin(by_id["grass_overhang_left"]), Vector2(-32, -4), "the left lip sits on the atlas anchor")
	eq(BOARD.terrace_origin(by_id["grass_overhang_corner_front"]), Vector2(-10, 10), "the front corner sits on the south vertex")
	eq(BOARD.terrace_role(by_id["cliff_left_h2"]), "face", "a cliff is a face")
	eq(BOARD.terrace_role(by_id["grass_overhang_right"]), "strip", "an overhang is a strip")
	eq(BOARD.terrace_role(by_id["grass_overhang_corner_left"]), "corner", "a corner piece stays a corner")
	eq(BOARD.drop_step(by_id["cliff_left_h1"]), Vector2i(0, 1), "tile_axis x, the SW face, drops toward +y")
	eq(BOARD.drop_step(by_id["cliff_right_h1"]), Vector2i(1, 0), "tile_axis y, the SE face, drops toward +x")
	eq(str(by_id["cliff_left_h1_water"].get("foot", "")), "water", "the SW water face is a water foot")
	eq(str(by_id["cliff_right_h1_water"].get("foot", "")), "water", "the SE water face is a water foot")
	eq(BOARD.edge_side(by_id["cliff_left_h2"]), "left", "the 2-step SW face is the front-row edge")
	eq(BOARD.edge_side(by_id["cliff_right_h2"]), "right", "the 2-step SE face is the front-column edge")
	eq(BOARD.vertex_where(by_id["grass_overhang_corner_front"]), "front", "vertex S is the south corner")
	eq(BOARD.vertex_where(by_id["grass_overhang_corner_left"]), "left", "vertex W is the west corner")
	eq(BOARD.vertex_where(by_id["grass_overhang_corner_right"]), "right", "vertex E is the east corner")
	eq(BOARD.terrace_origin(by_id["grass_overhang_corner_left"]), Vector2(-42, -6), "the west corner uses offset_2x")
	eq(BOARD.terrace_origin(by_id["grass_overhang_corner_right"]), Vector2(22, -6), "the east corner uses offset_2x")
	var wall: Dictionary = {}
	for spec in BOARD.load_catalog():
		if spec is Dictionary and str(spec.get("id", "")) == "ruined_wall_2c":
			wall = spec
	var wall_anchor: Array = wall.get("anchor_px_2x", [])
	var wall_size: Array = wall.get("size_2x", [])
	eq(Vector2i(int(wall_anchor[0]), int(wall_anchor[1])), Vector2i(96, 160), "the 2c wall anchor stays (96, 160)")
	eq(Vector2i(int(wall_size[0]), int(wall_size[1])), Vector2i(192, 160), "the 2c wall canvas stays 192x160")


func _test_data_stays() -> void:
	var tags: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TAGS))
	var looks := BOARD.load_looks()
	var tag_at := {}
	for cell in tags.get("cells", []):
		tag_at[Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1)))] = cell
	eq(tag_at.size(), 225, "the tags file still has 225 cells")
	eq((looks.get("cells", []) as Array).size(), 225, "looks.json covers every cell")
	var height_ok := true
	var terrain_ok := true
	for cell in looks.get("cells", []):
		var at := Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1)))
		var tag: Dictionary = tag_at.get(at, {})
		if str(tag.get("terrain", "")) != str(cell.get("terrain", "")):
			terrain_ok = false
		if int(tag.get("elevation", -1)) != int(cell.get("height", -2)):
			height_ok = false
	truthy(terrain_ok, "looks.json does not change terrain")
	truthy(height_ok, "looks.json does not change height")
	var paint := {}
	for cell in tags.get("cells", []):
		var props: Array = cell.get("paint_only", [])
		if props.is_empty():
			continue
		paint[Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))] = props
	eq(paint.size(), 30, "the tags file still lists the old paint_only props")
	truthy((paint.get(Vector2i(0, 0), []) as Array).has("ruins"), "paint_only at (0,0) is still ruins")


func _test_locked_calls() -> void:
	eq(BOARD.board_edge(), "earth_h2", "the board edge is the kit's 2-step earth edge")
	eq(BOARD.tall_under_fighter(), true, "a tall stone draws under a fighter")
	eq(BOARD.tall_fade(), false, "a tall stone does not fade")
	eq(BOARD.decor_on_raised(), false, "raised cells get no decor")
	eq(BOARD.two_cell_cover(), "fences", "2-cell pieces stay the looks.json ids")
	var looks := BOARD.load_looks()
	var props := {}
	for entry in looks.get("props", []):
		if str(entry.get("layer", "")) != "prop":
			continue
		props[Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))] = str(entry.get("new_id", ""))
	eq(str(props.get(Vector2i(7, -1), "")), "ruined_wall_2c", "the 2-cell wall is on the northeast rim")
	eq(str(props.get(Vector2i(-1, 8), "")), "fallen_log_2c", "the 2-cell log is on the northwest rim")
	eq(str(props.get(Vector2i(-1, 1), "")), "standing_stone", "a standing stone frames the northwest rim")
	eq(props.has(Vector2i(0, 0)), false, "the corner cell is not a tall prop")
	var decor: Array = looks.get("decor", [])
	eq(decor.size(), 8, "low decor is three clusters, not the old scatter")
	var raised := 0
	for entry in decor:
		if int(entry.get("height", 0)) > 0:
			raised += 1
	eq(raised, 0, "no decor sits on a raised cell")
	var decor_at: Array[Vector2i] = []
	for entry in decor:
		decor_at.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	var clustered := true
	for at in decor_at:
		var near := false
		for other in decor_at:
			if other == at:
				continue
			if absi(other.x - at.x) <= 1 and absi(other.y - at.y) <= 1:
				near = true
		if not near:
			clustered = false
	truthy(clustered, "each decor piece sits in a cluster")


func _test_phone_gate() -> void:
	HUD.set_pc_chrome_override(0)
	eq(BOARD.applies_to({"map_id": "crosshaven_15"}), false, "the phone path does not take the look")
	HUD.set_pc_chrome_override(1)
	eq(BOARD.applies_to({"map_id": "crosshaven_15"}), true, "PC crosshaven_15 takes the look")
	eq(BOARD.applies_to({"map_id": "crosshaven"}), true, "the catalog id crosshaven is the same board")
	eq(BOARD.applies_to({"demo_map": "crosshaven_15"}), true, "a demo_map stamp still selects the board")
	for other in ["stormspire_15", "brinewake_15", "slagcrown_15", "windmere_15", ""]:
		eq(BOARD.applies_to({"map_id": other}), false, "the look stays off %s" % other)
	var phone_tile := BoardTile.new()
	var phone_child := Sprite2D.new()
	phone_child.set_meta("canopy_tint", true)
	phone_tile.add_child(phone_child)
	HUD.set_pc_chrome_override(0)
	phone_tile.set_canopy_tint(Color(0.55, 0.78, 0.62))
	eq(phone_child.modulate, Color.WHITE, "the phone path does not tint canopy children")
	HUD.set_pc_chrome_override(1)
	phone_tile.set_canopy_tint(Color(0.40, 0.70, 0.55))
	eq(phone_child.modulate, Color(0.40, 0.70, 0.55), "the PC board tints canopy children")
	phone_tile.free()
	BOARD.set_suppressed(true)
	eq(BOARD.applies_to({"map_id": "crosshaven_15"}), false, "the bench can turn the look off")
	BOARD.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)


func _test_grounds_water_and_cover() -> void:
	var looks := BOARD.load_looks()
	var grounds: Dictionary = looks.get("grounds", {})
	for family in ["grass", "sand", "stone", "water", "mud"]:
		truthy(grounds.has(family), "the looks schema names %s" % family)
	eq(str(grounds.get("sand", {}).get("stand_in", "")), "sandstone", "sand stands in on the sandstone masters")
	eq(str(grounds.get("mud", {}).get("look", "")), "wet_earth", "mud is the wet-earth family")
	var sand_path := BOARD.piece_path("tiles", "sand_a")
	var stone_path := BOARD.piece_path("tiles", "stone_flag_a")
	truthy(sand_path.ends_with("sandstone_a@2x.png"), "sand_a uses the sandstone master until v1.4")
	truthy(stone_path.ends_with("stone_flag_a@2x.png"), "stone_flag_a is its own stand-in")
	var sand_tex := load(sand_path) as Texture2D
	var stone_tex := load(stone_path) as Texture2D
	var sand_img: Image = sand_tex.get_image() if sand_tex != null else null
	var stone_img: Image = stone_tex.get_image() if stone_tex != null else null
	truthy(sand_img != null and stone_img != null, "sand and stone stand-ins load")
	if sand_img != null and stone_img != null:
		var sand_px := sand_img.get_pixel(sand_img.get_width() / 2, sand_img.get_height() / 2)
		var stone_px := stone_img.get_pixel(stone_img.get_width() / 2, stone_img.get_height() / 2)
		var apart := Vector3(sand_px.r - stone_px.r, sand_px.g - stone_px.g, sand_px.b - stone_px.b).length()
		truthy(apart > 0.15, "sand and the grey stone flag do not share a colour")
	var sand_n := 0
	var stone_n := 0
	for cell in looks.get("cells", []):
		var look := str(cell.get("look", ""))
		var tile := str(cell.get("tile", ""))
		if look == "sand":
			sand_n += 1
			truthy(tile.begins_with("sand_"), "a sand cell names a sand tile")
		elif look == "stone":
			stone_n += 1
			truthy(tile.begins_with("stone_flag_"), "a stone cell names a stone-flag tile")
	eq(sand_n, 53, "the path stays sand")
	eq(stone_n, 12, "the court is stone flag")
	var tile := BoardTile.new()
	tile.set_move_pulse_frozen(true)
	tile.set_move_pulse_time(0.0)
	tile.set_highlight("move")
	var move := tile.highlight_fill_color()
	tile.free()
	var kit := Color(90.0 / 255.0, 192.0 / 255.0, 171.0 / 255.0, 1.0)
	var light := preload("res://board/pc/look_light.gd")
	var move_under: Color = light.grade_color(move, light.PRESET_LIGHT)
	var range_tile := BoardTile.new()
	range_tile.set_highlight("range")
	var range_under: Color = light.grade_color(range_tile.highlight_fill_color(), light.PRESET_LIGHT)
	range_tile.free()
	var hover_under: Color = light.grade_color(Color(0.72, 0.90, 0.82, 1.0), light.PRESET_LIGHT)
	var move_luma := move_under.r * 0.2126 + move_under.g * 0.7152 + move_under.b * 0.0722
	truthy(move_luma > 0.7, "the move tile stays bright under light")
	var range_gap := Vector3(range_under.r - move_under.r, range_under.g - move_under.g, range_under.b - move_under.b).length()
	truthy(range_gap > 0.35, "range stays clear of the move tile under light")
	var hover_gap := Vector3(hover_under.r - move_under.r, hover_under.g - move_under.g, hover_under.b - move_under.b).length()
	truthy(hover_gap > 0.2, "hover stays clear of the move tile under light")
	for src in [kit, Color.WHITE]:
		var graded: Color = light.grade_color(BOARD.grade_water(src), light.PRESET_LIGHT)
		var dist := Vector3(graded.r - move_under.r, graded.g - move_under.g, graded.b - move_under.b).length()
		truthy(dist > 0.45, "graded water stays clear of the move-range cyan under light")
	var catalog := {}
	for spec in BOARD.load_catalog():
		if spec is Dictionary:
			catalog[str(spec.get("id", ""))] = spec
	var walkable := {}
	for cell in looks.get("cells", []):
		if str(cell.get("terrain", "")) == "lava":
			continue
		walkable[Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))] = true
	var tall_on := 0
	for entry in looks.get("props", []):
		if str(entry.get("layer", "")) != "prop":
			continue
		var spec: Dictionary = catalog.get(str(entry.get("new_id", "")), {})
		if not BOARD.prop_is_tall(spec):
			continue
		for at in BOARD.prop_footprint(entry, spec):
			if walkable.has(at):
				tall_on += 1
	for entry in looks.get("decor", []):
		var spec: Dictionary = catalog.get(str(entry.get("id", "")), {})
		if not BOARD.prop_is_tall(spec):
			continue
		var at := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if walkable.has(at):
			tall_on += 1
	eq(tall_on, 0, "no tall prop sits on a walkable cell")
	eq(BOARD.prop_blocks(catalog.get("standing_stone", {})), "none", "a tall stone still does not block")


func _test_live() -> void:
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node = main.get_node("BoardView")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	eq(bool(board.get("_booted")), true, "the live board boots")
	var sim: Node = root.get_node("CombatSim")
	sim.reset_match({
		"seed": 1,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._refresh()
	await process_frame
	var layer = board.get_node_or_null("CrosshavenBoard")
	truthy(layer != null, "the live board has the Crosshaven look")
	eq(layer.dressed_count(), 225, "every Crosshaven cell wears the new look")
	var snap: Dictionary = sim.snapshot()
	eq(str(snap.get("demo_map", "")), "crosshaven_15", "the live snap is still crosshaven_15")
	eq(str(snap.get("tiles", {}).get(Vector2i(0, 0), {}).get("terrain_type", "")), "ground", "(0,0) stays ground")
	eq(int(snap.get("tiles", {}).get(Vector2i(0, 0), {}).get("elevation", -1)), 0, "(0,0) stays height 0")
	eq(str(snap.get("paint_only", {}).get(Vector2i(0, 0), [])[0]), "ruins", "paint_only at (0,0) is still ruins")
	eq(int(snap.get("tiles", {}).get(Vector2i(7, 4), {}).get("elevation", -1)), 2, "(7,4) stays height 2")
	eq(str(snap.get("tiles", {}).get(Vector2i(1, 1), {}).get("terrain_type", "")), "mud", "(1,1) stays mud")
	var origin: Node = board.tiles[Vector2i(0, 0)]
	eq(origin.hide_stock(), true, "stock props are hidden on the new board")
	var dress = origin.get_node_or_null("CrosshavenDress")
	truthy(dress != null, "(0,0) has the new dress")
	var ids: PackedStringArray = dress.piece_ids()
	eq(ids[0], "grass_top_b", "(0,0) draws its grass top")
	eq(ids.has("standing_stone"), false, "(0,0) is open ground, not a standing stone")
	var floor: Dictionary = dress.piece("grass_top_b")
	var floor_dest: Rect2 = floor.get("dest", Rect2())
	eq(floor_dest.size, Vector2(64, 32), "the @2x grass top covers the 64x32 diamond")
	eq(floor_dest.position, Vector2(-32, -16), "the grass top is centred on the cell")
	var rim = board.tiles[Vector2i(0, 1)].get_node("CrosshavenDress")
	var stone: Dictionary = rim.piece("standing_stone")
	truthy(not stone.is_empty(), "the northwest rim cell carries the off-grid standing stone")
	var stone_dest: Rect2 = stone.get("dest", Rect2())
	eq(stone_dest.position, Vector2(-64, -112), "the standing stone is shifted off the walkable cell")
	eq(is_equal_approx((stone.get("tint", Color.WHITE) as Color).a, 1.0), true, "the standing stone does not fade")
	eq(rim.z_index < SORT.UNIT_Z_BIAS, true, "the stone draws under a fighter on its cell")
	var raised = board.tiles[Vector2i(4, 3)].get_node("CrosshavenDress")
	var raised_ids := PackedStringArray([
		"cliff_left_h1", "cliff_right_h1", "grass_top_b",
		"raised_rim_ne", "raised_rim_nw",
		"grass_overhang_left", "grass_overhang_right",
		"grass_overhang_corner_left", "grass_overhang_corner_right", "grass_overhang_corner_front",
	])
	eq(raised.piece_ids(), raised_ids, "a raised cell draws faces, then the top, then overlays, then the lip")
	eq(raised.piece("cliff_left_h1").get("dest", Rect2()).position, Vector2(-32, 0), "the left cliff hangs from the west edge")
	eq(raised.piece("grass_overhang_left").get("dest", Rect2()).position, Vector2(-32, -4), "the left lip uses the atlas anchor")
	eq(raised.piece("grass_overhang_corner_front").get("dest", Rect2()).position, Vector2(-10, 10), "the front corner uses the atlas anchor")
	var sw: PackedStringArray = board.tiles[Vector2i(10, 3)].get_node("CrosshavenDress").piece_ids()
	truthy(sw.has("cliff_left_h1_water"), "(10,3) uses the SW water face")
	eq(sw.has("cliff_left_h1"), false, "(10,3) does not also draw the dry SW face")
	truthy(sw.has("cliff_right_h1"), "(10,3) keeps the dry SE face over ground")
	for drop in [[Vector2i(9, 5), "cliff_right_h1"], [Vector2i(3, 7), "cliff_right_h1"], [Vector2i(11, 7), "cliff_right_h1"]]:
		var at: Vector2i = drop[0]
		var dry := str(drop[1])
		var got: PackedStringArray = board.tiles[at].get_node("CrosshavenDress").piece_ids()
		truthy(got.has(dry + "_water"), "%s uses the SE water face" % str(at))
		eq(got.has(dry), false, "%s does not also draw the dry SE face" % str(at))
	var shore_a: PackedStringArray = board.tiles[Vector2i(10, 4)].get_node("CrosshavenDress").piece_ids()
	eq(shore_a.has("water_edge_ne"), false, "(10,4) skips the stone lip under the SW water face")
	truthy(shore_a.has("water_edge_nw"), "(10,4) keeps the other shore lip")
	var shore_b: PackedStringArray = board.tiles[Vector2i(10, 5)].get_node("CrosshavenDress").piece_ids()
	eq(shore_b.has("water_edge_nw"), false, "(10,5) skips the stone lip under the SE water face")
	truthy(shore_b.has("water_edge_sw"), "(10,5) keeps the far shore lip")
	var shore_c: PackedStringArray = board.tiles[Vector2i(4, 7)].get_node("CrosshavenDress").piece_ids()
	eq(shore_c.has("water_edge_nw"), false, "(4,7) skips the stone lip under the SE water face")
	truthy(shore_c.has("water_edge_ne"), "(4,7) keeps the other shore lip")
	var shore_d: PackedStringArray = board.tiles[Vector2i(12, 7)].get_node("CrosshavenDress").piece_ids()
	eq(shore_d.has("water_edge_nw"), false, "(12,7) skips the stone lip under the SE water face")
	truthy(shore_d.has("water_edge_ne") and shore_d.has("water_edge_corner_s"), "(12,7) keeps the other shore pieces")
	var light := preload("res://board/pc/look_light.gd")
	var dress_node := board.tiles[Vector2i(0, 0)].get_node("CrosshavenDress") as CanvasItem
	eq(light.SHIPPED_OUTDOOR_PRESET, light.PRESET_LIGHT, "L9 ships the light grade")
	eq(light.outdoor_preset, light.PRESET_LIGHT, "the live board is on the shipped preset")
	eq(dress_node.material != null, true, "the shipped light grade is on the board")
	eq(is_equal_approx(float(dress_node.material.get_shader_parameter("grade_sat")), light.LIGHT_SAT), true, "light is saturation 1.10")
	eq(is_equal_approx(float(dress_node.material.get_shader_parameter("grade_contrast")), light.LIGHT_CONTRAST), true, "light is contrast 1.04")
	light.set_outdoor_preset(light.PRESET_MEDIUM)
	board._sync_look_light()
	eq(is_equal_approx(float(dress_node.material.get_shader_parameter("grade_sat")), light.MEDIUM_SAT), true, "medium is saturation 1.15")
	eq(is_equal_approx(float(dress_node.material.get_shader_parameter("grade_contrast")), light.MEDIUM_CONTRAST), true, "medium is contrast 1.07")
	light.set_outdoor_preset(light.PRESET_OFF)
	board._sync_look_light()
	eq(dress_node.material == null, true, "turning the preset off clears the board grade")
	eq(light.outdoor_preset, light.PRESET_OFF, "off stays in code and clears the grade")
	light.set_outdoor_preset(light.SHIPPED_OUTDOOR_PRESET)
	var corner = board.tiles[Vector2i(14, 14)].get_node("CrosshavenDress")
	var corner_ids: PackedStringArray = corner.piece_ids()
	truthy(corner_ids.has("cliff_left_h2") and corner_ids.has("cliff_right_h2"), "the south corner gets the 2-step earth edge")
	truthy(corner_ids.has("grass_overhang_left") and corner_ids.has("grass_overhang_corner_front"), "a grass edge keeps the overhang")
	var sand = board.tiles[Vector2i(14, 11)].get_node("CrosshavenDress")
	truthy(sand.piece_ids().has("cliff_right_h2"), "a sandstone edge still gets the earth face")
	eq(sand.piece_ids().has("grass_overhang_right"), false, "sandstone does not grow a grass overhang")
	var shrub: Node = board.tiles[Vector2i(2, 8)]
	eq(shrub.get_node("CrosshavenDress").piece("lilac_bush").is_empty(), true, "the old raised-cell bush is gone")
	truthy(board.tiles[Vector2i(12, 4)].get_node("CrosshavenDress").piece_ids().has("clover_patch"), "the water cluster keeps its clover")
	eq(board.tiles[Vector2i(3, 12)].get_node("CrosshavenDress").piece_ids().has("ruined_wall_2c"), false, "the old fence cell is not a wall")
	truthy(board.tiles[Vector2i(7, 0)].get_node("CrosshavenDress").piece_ids().has("ruined_wall_2c"), "the rim hosts the 2-cell wall")
	var jungle = board.get_node_or_null("JungleBackdrop")
	truthy(jungle != null and jungle.kit_edge(), "the kit edge replaces the jungle lip")
	eq(is_equal_approx(jungle.skirt_alpha(0.2), float(jungle.load_params()["ground_skirt"]["strength"])), true, "the jungle skirt math stays for its own tests")
	sim.reset_match({"seed": 1, "map_id": "stormspire", "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	board._refresh()
	eq(layer.dressed_count(), 0, "Stormspire does not wear the Crosshaven look")
	eq(board.tiles[Vector2i(0, 0)].hide_stock(), false, "Stormspire still draws its stock tiles")
	eq(jungle.kit_edge(), false, "the jungle lip comes back off Crosshaven")
	board.set_board_theme("thunderwell")
	await process_frame
	eq(board.tiles[Vector2i(0, 0)].hide_stock(), false, "Thunderwell does not use the Crosshaven hide")
	eq(board.tiles[Vector2i(0, 0)].look_floor() != null, true, "Thunderwell still sets its own floor")
	eq(board.tiles[Vector2i(0, 0)].get_node_or_null("CrosshavenDress"), null, "Thunderwell does not keep the outdoor dress")
	board.set_board_theme("")
	HUD.set_pc_chrome_override(0)
	sim.reset_match({"seed": 1, "map_id": "crosshaven", "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	board._refresh()
	eq(layer.dressed_count(), 0, "the phone path leaves Crosshaven on the stock tiles")
	eq(board.tiles[Vector2i(0, 0)].hide_stock(), false, "the phone path still draws stock props")
	eq(board.tiles[Vector2i(0, 0)].get_node_or_null("CrosshavenDress"), null, "the phone path adds no dress")
	eq(str(sim.snapshot().get("paint_only", {}).get(Vector2i(0, 0), [])[0]), "ruins", "the phone snap still says ruins")
	main.free()


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
		return
	_failed += 1
	print("FAIL %s | expected %s | got %s" % [msg, str(expected), str(actual)])


func truthy(value: bool, msg: String) -> void:
	eq(value, true, msg)
