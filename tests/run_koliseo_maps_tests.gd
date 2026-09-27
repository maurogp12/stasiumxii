extends SceneTree

## Koliseo ship maps: tags load, lava stays on Slagcrown, solid props block
## movement, dress paint stays walkable, and hot-seat rolls one of the five arenas.
## Run: godot --headless --path . -s res://tests/run_koliseo_maps_tests.gd

const MAPS := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_catalog()
	_test_each_map()
	_test_paint_only_and_lava()
	_test_unknown_map_does_not_invent()
	_test_cell_tags_override()
	_test_random_ship_id()
	_test_hotseat_rolls_map()
	_test_alive_grade()
	_test_original_sheet()
	_test_brine_punch()
	_test_slag_punch()
	await _test_hotseat_navigates()
	print("Koliseo map tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_catalog() -> void:
	eq(CellTagMap.SHIP_MAPS, MAPS, "catalog order is the five Koliseo arenas")
	eq(CellTagMap.tags_path_for(""), CellTagMap.DEFAULT_TAGS, "empty map id is Crosshaven")
	eq(CellTagMap.normalize_id("Brinewake_15"), "brinewake", "map id normalizes the ship suffix")
	eq(CellTagMap.is_ship_map("stormspire"), true, "stormspire is a ship map")
	eq(CellTagMap.is_ship_map("mauro"), false, "proto ids are not ship maps")
	for map_id in MAPS:
		var path := CellTagMap.tags_path_for(map_id)
		truthy(FileAccess.file_exists(path), "%s tags file exists" % map_id)
		truthy(FileAccess.file_exists(CellTagMap.preview_path(map_id)), "%s preview exists" % map_id)
		eq(CellTagMap.label_of(map_id) != "", true, "%s has a label" % map_id)


func _test_each_map() -> void:
	var sim := _sim()
	var lava_maps: Array[String] = []
	for map_id in MAPS:
		var tags: Dictionary = CellTagMap.load_file(CellTagMap.tags_path_for(map_id))
		eq(bool(tags.get("ok", false)), true, "%s tags load" % map_id)
		eq(int(tags.get("width", 0)), 15, "%s width is 15" % map_id)
		eq(int(tags.get("height", 0)), 15, "%s height is 15" % map_id)
		eq((tags.get("cells", []) as Array).size(), 225, "%s has 225 cells" % map_id)
		eq(str(tags.get("map_id", "")), "%s_15" % map_id, "%s stamps the ship map id" % map_id)
		var checked: Dictionary = CellTagMap.cross_check_tmx(tags)
		eq(bool(checked.get("ok", false)), true, "%s tags match the tmx terrain and elevation" % map_id)
		var snap: Dictionary = sim.reset_match({"seed": 1, "map_id": map_id, "skip_deploy": true})
		eq(int(snap.get("board_size", 0)), 15, "%s match board is 15" % map_id)
		eq(str(snap.get("demo_map", "")), "%s_15" % map_id, "%s match stamps demo_map" % map_id)
		eq(str(snap.get("elevation_gen", "")), "tags", "%s uses tag elevation" % map_id)
		var lava := 0
		for cell in snap["tiles"].keys():
			if str(snap["tiles"][cell]["terrain_type"]) == "lava":
				lava += 1
		if lava > 0:
			lava_maps.append(map_id)
		else:
			eq(lava, 0, "%s has no lava" % map_id)
	eq(lava_maps, ["slagcrown"], "lava is only on Slagcrown among these maps")


func _test_paint_only_and_lava() -> void:
	var sim := _sim()
	for map_id in MAPS:
		var tags: Dictionary = CellTagMap.load_file(CellTagMap.tags_path_for(map_id))
		var step := _ground_paint_step(tags)
		truthy(not step.is_empty(), "%s has a painted ground step" % map_id)
		if step.is_empty():
			continue
		var origin: Vector2i = step["from"]
		var dest: Vector2i = step["to"]
		var prop := str(step["prop"])
		sim.reset_match({
			"seed": 1,
			"map_id": map_id,
			"skip_deploy": true,
			"kestrel_pos": origin,
			"ironjaw_pos": step["other"],
		})
		var tile: Dictionary = sim.tile_at(dest)
		eq(str(tile.get("terrain_type", "")), "ground", "%s painted step keeps its terrain tag" % map_id)
		var paint: Dictionary = sim.snapshot().get("paint_only", {})
		truthy(paint.has(dest), "%s stores paint_only beside the tile" % map_id)
		var blocks := CellTagMap.props_block_move(paint.get(dest, []))
		eq(bool(tile.get("walkable", false)), not blocks, "%s %s walkable matches the prop" % [map_id, prop])
		var moved: Dictionary = sim.submit({"type": "move", "to": dest})
		if blocks:
			eq(bool(moved.get("ok", true)), false, "%s walk onto %s is rejected" % [map_id, prop])
			eq(str(moved.get("reason", "")), "not_walkable", "%s %s reject is not_walkable" % [map_id, prop])
		else:
			eq(bool(moved.get("ok", false)), true, "%s dress paint %s stays walkable" % [map_id, prop])
			eq(int(moved["events"][0]["mp_spent"]), 1, "%s dress paint does not add MP" % map_id)
	var slag: Dictionary = sim.reset_match({"seed": 1, "map_id": "slagcrown", "skip_deploy": true})
	var lava_cell := Vector2i(-1, -1)
	var stand := Vector2i(-1, -1)
	for cell in slag["tiles"].keys():
		if str(slag["tiles"][cell]["terrain_type"]) != "lava":
			continue
		lava_cell = cell
		for dir in ORTHO:
			var neighbor: Vector2i = cell + dir
			if not slag["tiles"].has(neighbor):
				continue
			if str(slag["tiles"][neighbor]["terrain_type"]) == "ground" and int(slag["tiles"][neighbor]["elevation"]) == 0:
				stand = neighbor
				break
		if stand.x >= 0:
			break
	truthy(lava_cell.x >= 0, "Slagcrown has a lava cell")
	eq(bool(sim.tile_at(lava_cell).get("walkable", true)), false, "Slagcrown lava stays impassable")
	var painted_lava := false
	var paint: Dictionary = slag.get("paint_only", {})
	for cell in paint.keys():
		if str(slag["tiles"][cell]["terrain_type"]) == "lava":
			painted_lava = true
			eq(bool(sim.tile_at(cell).get("walkable", true)), false, "paint_only on lava does not make it walkable")
			break
	if painted_lava:
		eq(painted_lava, true, "Slagcrown lava can carry paint")
	if stand.x >= 0:
		sim.reset_match({
			"seed": 1,
			"map_id": "slagcrown",
			"skip_deploy": true,
			"kestrel_pos": stand,
			"ironjaw_pos": Vector2i(0, 0) if stand != Vector2i(0, 0) and lava_cell != Vector2i(0, 0) else Vector2i(14, 14),
		})
		var blocked: Dictionary = sim.submit({"type": "move", "to": lava_cell})
		eq(bool(blocked.get("ok", true)), false, "voluntary walk onto Slagcrown lava is rejected")
		eq(str(blocked.get("reason", "")), "not_walkable", "lava reject reason stays not_walkable")


func _test_unknown_map_does_not_invent() -> void:
	var snap: Dictionary = _sim().reset_match({"seed": 1, "map_id": "not_a_region", "skip_deploy": true})
	eq(str(snap.get("demo_map", "x")), "", "an unknown map id does not invent a board")
	eq(str(snap["tiles"][Vector2i(0, 0)]["terrain_type"]), "ground", "unknown map stays open ground")


func _test_cell_tags_override() -> void:
	var snap: Dictionary = _sim().reset_match({
		"seed": 1,
		"map_id": "slagcrown",
		"cell_tags": CellTagMap.DEFAULT_TAGS,
		"skip_deploy": true,
	})
	eq(str(snap.get("demo_map", "")), "crosshaven_15", "explicit cell_tags still wins over map_id")
	eq(int(snap["tiles"][Vector2i(1, 1)]["elevation"]) >= 0, true, "override tags still apply")


func _test_random_ship_id() -> void:
	for i in MAPS.size():
		eq(CellTagMap.ship_id_at(i), MAPS[i], "catalog index %d is %s" % [i, MAPS[i]])
	eq(CellTagMap.ship_id_at(MAPS.size()), MAPS[0], "catalog index wraps onto Crosshaven")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for _i in 80:
		var rolled := CellTagMap.random_ship_id(rng)
		truthy(MAPS.has(rolled), "seeded roll stays in the five ids")
		seen[rolled] = true
	eq(seen.size(), MAPS.size(), "seeded rolls cover every ship map")
	var live := CellTagMap.random_ship_id()
	truthy(MAPS.has(live), "live random selection returns one of the five ids")


func _test_hotseat_rolls_map() -> void:
	var script := load("res://scenes/class_select.gd")
	script.hotseat_classes.clear()
	script.hotseat_map_id = ""
	var picker := _picker(false)
	picker.choose_mode("hotseat")
	eq(picker.phase_name(), "hotseat_p1", "hot-seat opens class select")
	eq(picker.class_cards_visible(), true, "class cards are on screen")
	var src := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	eq(src.contains("func pick_map"), false, "class select has no map picker")
	eq(src.contains("Pick a Koliseo map"), false, "class select has no map prompt")
	picker.pick_class("kestrel")
	picker.go_back()
	eq(picker.phase_name(), "hotseat_p1", "back from P2 returns to P1")
	picker.choose_mode("hotseat")
	picker.pick_class("kestrel")
	picker.pick_class("ironjaw")
	var sealed := str(script.hotseat_map_id)
	truthy(MAPS.has(sealed), "sealed map is one of the five")
	var config: Dictionary = script.local_match_config()
	eq(str(config.get("map_id", "")), sealed, "match config carries the rolled map id")
	var snap: Dictionary = _sim().reset_match(config)
	eq(str(snap.get("demo_map", "")), "%s_15" % sealed, "rolled config loads that arena")
	eq(str(snap["units"][0]["class_id"]), "kestrel", "rolled config keeps P1")
	eq(str(snap["units"][1]["class_id"]), "ironjaw", "rolled config keeps P2")
	script.hotseat_map_id = "crosshaven"
	var again := str(script.roll_hotseat_map())
	truthy(MAPS.has(again), "New Match roll is a ship map")
	eq(str(script.hotseat_map_id), again, "New Match stores the fresh roll")
	eq(str(script.local_match_config().get("map_id", "")), again, "fresh roll replaces the previous map id")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var rematch := view.split("func _on_new_match")[1].split("func ")[0]
	truthy(rematch.contains("roll_hotseat_map()"), "New Match rolls before the next duel")
	truthy(rematch.find("roll_hotseat_map()") < rematch.find("local_match_config()"), "New Match rolls before reading the sealed config")
	var dress := str(load("res://board/koliseo_art.gd").dress_for("windmere_15"))
	eq(dress, "wind_", "Windmere paint uses the ice dress")
	var tex: Texture2D = load("res://board/koliseo_art.gd").terrain_texture("ground", 0, dress)
	truthy(tex != null, "Windmere ground art loads")
	if tex != null:
		eq(tex.get_width(), 64, "Windmere ground sheet is 64 px wide")
		truthy(tex.resource_path.contains("wind_ground"), "Windmere ground is the region sheet")
	var slag_lava: Texture2D = load("res://board/koliseo_art.gd").terrain_texture("lava", 0, "slag_")
	truthy(slag_lava != null, "Slagcrown lava art loads")
	if slag_lava != null:
		truthy(slag_lava.resource_path.contains("slag_lava"), "Slagcrown lava is the region sheet")
	picker.free()


func _test_hotseat_navigates() -> void:
	var script := load("res://scenes/class_select.gd")
	script.hotseat_classes.clear()
	script.hotseat_map_id = ""
	var picker := _picker(true)
	picker.choose_mode("hotseat")
	picker.pick_class("mender")
	picker.pick_class("bastion")
	var map_id := str(script.hotseat_map_id)
	truthy(MAPS.has(map_id), "launch sealed a ship map")
	var arrived := false
	for _i in 12:
		await process_frame
		if current_scene == null:
			continue
		if current_scene.scene_file_path != "res://main.tscn":
			continue
		var snap: Dictionary = _sim().snapshot()
		if str(snap.get("demo_map", "")) == "%s_15" % map_id and str(snap.get("phase", "")) == "DEPLOYMENT":
			arrived = true
			eq(str(snap["units"][0]["class_id"]), "mender", "navigated match seat 0 is mender")
			eq(str(snap["units"][1]["class_id"]), "bastion", "navigated match seat 1 is bastion")
			break
	eq(arrived, true, "hot-seat navigates into the rolled arena")


func _test_alive_grade() -> void:
	var life := load("res://board/koliseo_life.gd")
	eq(life.MOTE_AMOUNT <= 24, true, "arena motes stay a small weather field")
	eq(life.MOTE_AMOUNT >= 8, true, "arena motes are enough to read")
	var seen := {}
	for map_id in MAPS:
		var grade: Dictionary = life.grade_for(map_id, "ground", 0, Vector2i(2, 3))
		eq(bool(grade.get("ship", false)), true, "%s ground is a ship grade" % map_id)
		truthy(float(grade["contrast"]) > 1.05, "%s ground contrast is richer than flat" % map_id)
		truthy(float(grade["sat"]) > 1.05, "%s ground is more saturated" % map_id)
		truthy(float(grade["shimmer"]) > 0.0, "%s ground has a sheen" % map_id)
		var tint: Color = grade["grade"]
		seen["%0.2f,%0.2f,%0.2f" % [tint.r, tint.g, tint.b]] = true
		var ambient: Dictionary = life.ambient_for(map_id)
		truthy(not ambient.is_empty(), "%s has weather" % map_id)
		var mote: Color = ambient["mote"]
		truthy(mote.a > 0.2 and mote.a < 0.95, "%s motes stay subtle" % map_id)
	eq(seen.size(), MAPS.size(), "each arena tints the sheets differently")
	var brine_water: Dictionary = life.grade_for("brinewake", "water", 0, Vector2i(1, 1))
	var brine_ground: Dictionary = life.grade_for("brinewake", "ground", 0, Vector2i(1, 1))
	truthy(float(brine_water["shimmer"]) > float(brine_ground["shimmer"]), "Brinewake water shimmers more than stone")
	var slag_lava: Dictionary = life.grade_for("slagcrown", "lava", 1, Vector2i(4, 4))
	var slag_ground: Dictionary = life.grade_for("slagcrown", "ground", 1, Vector2i(4, 4))
	truthy(float(slag_lava["pulse"]) > float(slag_ground["pulse"]), "Slagcrown lava pulses harder than ash")
	var high: Dictionary = life.grade_for("windmere", "ground", 3, Vector2i(0, 1))
	var low: Dictionary = life.grade_for("windmere", "ground", 0, Vector2i(0, 1))
	truthy(float(high["lift"]) > float(low["lift"]), "a higher tile reads brighter")
	var quiet: Dictionary = life.grade_for("not_a_region", "ground", 2, Vector2i(0, 0))
	eq(bool(quiet.get("ship", true)), false, "an unknown map is not dressed as a biome")
	eq(float(quiet["shimmer"]), 0.0, "an unknown map does not invent shimmer")
	eq(float(quiet["pulse"]), 0.0, "an unknown map does not invent a light pulse")
	var wind_grade: Color = life.grade_for("windmere", "ground", 0, Vector2i(1, 1))["grade"]
	truthy(wind_grade.b >= wind_grade.r and wind_grade.b - wind_grade.r < 0.2, "Windmere stays painted snow")
	truthy(wind_grade.r > 0.85 and wind_grade.g > 0.85, "Windmere does not replace the sheet with a stain")
	var slag_grade: Color = life.grade_for("slagcrown", "ground", 0, Vector2i(1, 1))["grade"]
	truthy(slag_grade.r > slag_grade.b and slag_grade.r < 1.25, "Slagcrown stays warm stone")
	var haven_grade: Color = life.grade_for("crosshaven", "ground", 0, Vector2i(1, 1))["grade"]
	truthy(haven_grade.r >= haven_grade.g and haven_grade.g > haven_grade.b, "Crosshaven grade stays warm earth")
	eq(life.GRID_INK.a >= 0.7, true, "the tactical grid ink is dark enough to read")
	eq(life.GRID_GLEAM.a >= 0.4, true, "the tactical grid has a light edge")
	truthy(life.GRID_GLEAM.r >= life.GRID_GLEAM.b, "the grid gleam stays warm")
	eq(life.GRID_INK_PX >= 1.8 and life.GRID_INK_PX <= 2.8, true, "the grid line is readable and stays an ink stroke")
	var rim: PackedVector2Array = life.board_rim(15)
	eq(rim.size(), 4, "the board edge is the outer diamond")
	truthy(rim[2].y > rim[0].y, "the south tip sits below the north tip")
	truthy(rim[1].x > 0.0 and rim[3].x < 0.0, "east and west tips open the diamond")
	var wind_edge: Color = life.edge_tint("windmere")
	truthy(wind_edge.a > 0.5 and maxf(wind_edge.r, maxf(wind_edge.g, wind_edge.b)) < 0.2, "the board edge is ink")
	eq(life.edge_tint("not_a_region").a, 0.0, "an unknown map has no edge")
	var life_src := FileAccess.get_file_as_string("res://board/koliseo_life.gd")
	eq(life_src.contains("jewel"), false, "arena life does not stain jewels")
	eq(life_src.contains("paint_backdrop"), false, "arena life does not paint a glassy backdrop")
	eq(life_src.contains("_build_rim"), false, "arena life does not add a scenery ring")
	var src := FileAccess.get_file_as_string("res://board/koliseo_life.gd")
	eq(src.contains("hit_chance"), false, "arena life does not touch hit bands")
	eq(src.contains("legal_intents"), false, "arena life does not touch legality")
	eq(src.contains("line_of_sight"), false, "arena life does not invent LoS")
	eq(src.contains("fog"), false, "arena life does not invent fog")
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	truthy(tile_src.contains("_paint_depth_rim"), "ship sheets draw an iso depth rim")
	truthy(tile_src.contains("apply_koliseo_grade"), "tiles take the arena grade")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("apply_koliseo_grade"), "the board applies the grade with the tiles")
	truthy(view.contains("KoliseoLife"), "the board owns the weather layer")


func _test_original_sheet() -> void:
	var art := load("res://board/koliseo_art.gd")
	eq(art.PENDING_THEMES, [], "ice and electric packs are sliced")
	truthy(FileAccess.file_exists("res://art/tilesets/original/original-tileset-a.jpg"), "original sheet A is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/original-tileset-b.jpg"), "original sheet B is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/ice/stasium_tileset_ice.png"), "ice sheet is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/ice/punch/wind_ground_punch.png"), "Windmere ground punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/ice/punch/wind_elevation_punch.png"), "Windmere elevation punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/ice/punch/wind_props_punch.png"), "Windmere props punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/electric/stasium_tileset_electric.png"), "electric sheet is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/electric/storm_ground_punch.png"), "Stormspire ground punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/electric/storm_elevation_punch.png"), "Stormspire elevation punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/electric/storm_props_punch.png"), "Stormspire props punch is in the repo")
	var themes := FileAccess.get_file_as_string("res://art/tilesets/original/THEMES.md")
	truthy(themes.contains("crosshaven_ground_punch.png"), "earth punch is the Crosshaven source")
	truthy(FileAccess.file_exists("res://art/tilesets/original/crosshaven_ground_punch.png"), "Crosshaven ground punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/crosshaven_elevation_punch.png"), "Crosshaven elevation punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/crosshaven_props_punch.png"), "Crosshaven props punch is in the repo")
	truthy(themes.contains("stasium_tileset_ice.png"), "ice sheet stays noted beside the punch")
	truthy(themes.contains("wind_ground_punch.png"), "Windmere ground is the ice punch sheet")
	truthy(themes.contains("wind_elevation_punch.png"), "Windmere cliffs are the ice punch sheet")
	truthy(themes.contains("wind_props_punch.png"), "Windmere props are the ice punch sheet")
	truthy(themes.contains("stasium_tileset_electric.png"), "electric sheet stays noted beside the punch")
	truthy(themes.contains("storm_ground_punch.png"), "Stormspire ground is the algo-así punch sheet")
	truthy(themes.contains("storm_elevation_punch.png"), "Stormspire cliffs are the algo-así punch sheet")
	truthy(themes.contains("storm_props_punch.png"), "Stormspire props are the algo-así punch sheet")
	eq(FileAccess.file_exists("res://art/maps/arena_colosseum_v2/tiled/tiles/ice_ground.png"), false, "no invented ice ground pack")
	eq(FileAccess.file_exists("res://art/maps/arena_colosseum_v2/tiled/tiles/electric_ground.png"), false, "no invented electric ground pack")
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/tilesets/original/atlas_map.json"))
	var families: Dictionary = atlas["families"]
	eq(str(families["crosshaven"]["pack"]), "earth", "Crosshaven uses the earth pack")
	eq(str(families["brinewake"]["pack"]), "coast", "Brinewake uses the coast pack")
	eq(str(families["slagcrown"]["pack"]), "lava", "Slagcrown uses the lava pack")
	eq(str(families["windmere"]["pack"]), "ice", "Windmere uses the ice pack")
	eq(str(families["stormspire"]["pack"]), "electric", "Stormspire uses the electric pack")
	eq(families["windmere"]["pending_theme"], null, "Windmere ice pack is live")
	eq(families["stormspire"]["pending_theme"], null, "Stormspire electric pack is live")
	var ground: Texture2D = art.terrain_texture("ground", 0)
	var img := ground.get_image()
	truthy(img.get_pixel(48, 16).a > 0.2, "dirt diamond reaches the right half of the sheet")
	var mid := img.get_pixel(32, 16)
	truthy(mid.r > mid.g and mid.g > mid.b, "Crosshaven ground is dirt, not a lawn")
	truthy(_green_fraction(ground) < 0.02, "Crosshaven ground is not a lawn carpet")
	var wind_tex: Texture2D = art.terrain_texture("ground", 0, "wind_")
	var wind_px: Color = wind_tex.get_image().get_pixel(32, 16)
	truthy(wind_px.r > 0.7 and wind_px.b >= wind_px.r, "Windmere ground is snow from the ice sheet")
	var wind_water: Texture2D = art.terrain_texture("water", 0, "wind_")
	var wind_water_px: Color = wind_water.get_image().get_pixel(32, 16)
	truthy(wind_water_px.b > wind_water_px.g and wind_water_px.g > wind_water_px.r, "Windmere water is the ice-sheet water")
	truthy(_diamond_seam(wind_tex), "Windmere ground keeps a readable diamond edge")
	truthy(_diamond_seam(wind_water), "Windmere water keeps a readable diamond edge")
	var wind_crystal: Texture2D = art.prop_texture("crystal", "wind_")
	truthy(wind_crystal.get_width() <= 72, "Windmere crystal stays a sparse accent")
	var wind_e1: Texture2D = art.terrain_texture("ground", 1, "wind_")
	var wind_e2: Texture2D = art.terrain_texture("ground", 2, "wind_")
	truthy(wind_e1.get_height() > 32, "Windmere cliffs hang below the diamond")
	truthy(wind_e2.get_height() > wind_e1.get_height(), "Windmere high cliffs are taller")
	var slag_tex: Texture2D = art.terrain_texture("lava", 0, "slag_")
	var slag_px: Color = slag_tex.get_image().get_pixel(32, 16)
	truthy(slag_px.r > slag_px.b, "Slagcrown lava is the sheet lava")
	var slag_floor: Texture2D = art.terrain_texture("ground", 0, "slag_")
	var slag_floor_px: Color = slag_floor.get_image().get_pixel(32, 16)
	truthy(slag_floor_px.r > slag_floor_px.g and slag_floor_px.r > slag_floor_px.b, "Slagcrown ground is scorched dirt")
	truthy(_green_fraction(slag_floor) < 0.02, "Slagcrown floor has no lawn")
	var slag_pool: Texture2D = art.terrain_texture("water", 0, "slag_")
	var slag_pool_px: Color = slag_pool.get_image().get_pixel(32, 16)
	truthy(slag_pool_px.r > slag_pool_px.b and slag_pool_px.r > slag_pool_px.g, "Slagcrown pools are dark ash, not grass")
	var slag_e1: Texture2D = art.terrain_texture("ground", 1, "slag_")
	var slag_e2: Texture2D = art.terrain_texture("ground", 2, "slag_")
	var slag_cap: Color = slag_e1.get_image().get_pixel(32, 4)
	truthy(slag_cap.r > slag_cap.g and slag_cap.r > slag_cap.b, "Slagcrown cliff cap is scorched rock, not grass")
	truthy(slag_e2.get_height() > slag_e1.get_height(), "Slagcrown high cliffs are taller than the low ledge")
	var haven_cliff: Texture2D = art.terrain_texture("ground", 1, "")
	var haven_cap: Color = haven_cliff.get_image().get_pixel(32, 8)
	truthy(haven_cap.r > haven_cap.g and haven_cap.g > haven_cap.b, "Crosshaven cliff cap is dirt, not a lawn")
	truthy(_green_fraction(haven_cliff) < 0.02, "Crosshaven cliffs stay bare earth")
	var ruins_tex: Texture2D = art.prop_texture("ruins", "")
	var ruin_moss := _green_fraction(ruins_tex)
	truthy(ruin_moss > 0.06, "moss sits on the ruin walls")
	truthy(ruin_moss < 0.28, "ruin moss does not swallow the stone")
	var seal_tex: Texture2D = art.prop_texture("floor_seal", "")
	truthy(_green_fraction(seal_tex) < 0.02, "the floor seal is bare stone")
	for prop_name in ["hay", "fence", "rubble", "rock_pillar", "well"]:
		var prop_tex: Texture2D = art.prop_texture(prop_name, "")
		truthy(_green_fraction(prop_tex) < 0.02, "%s stays off the moss" % prop_name)
	truthy(_green_fraction(slag_e1) < 0.02, "Slagcrown cliffs stay off the grass wall")
	truthy(_green_fraction(slag_e2) < 0.02, "Slagcrown high cliffs stay off the grass wall")
	var slag_ash: Texture2D = art.prop_texture("ash_rock", "slag_")
	var slag_basalt: Texture2D = art.prop_texture("basalt_pillar", "slag_")
	var slag_rubble: Texture2D = art.prop_texture("rubble", "slag_")
	truthy(slag_ash.resource_path.ends_with("slag_prop_ash_rock.png"), "Slagcrown ash rock is the volcanic sheet")
	truthy(slag_basalt.resource_path.ends_with("slag_prop_basalt_pillar.png"), "Slagcrown basalt is the volcanic sheet")
	truthy(slag_rubble.resource_path.ends_with("slag_prop_rubble.png"), "Slagcrown rubble is the volcanic sheet")
	truthy(_green_fraction(slag_basalt) < _green_fraction(art.prop_texture("basalt_pillar", "")), "Slagcrown basalt has less moss than the forest pillar")
	truthy(_green_fraction(slag_ash) < _green_fraction(art.prop_texture("ash_rock", "")), "Slagcrown ash rock has less moss than the forest rock")
	var haven_ash: Texture2D = art.prop_texture("ash_rock", "")
	truthy(haven_ash.resource_path.ends_with("prop_ash_rock.png"), "Crosshaven keeps the original ash rock")
	var haven_basalt: Texture2D = art.prop_texture("basalt_pillar", "")
	truthy(haven_basalt.resource_path.ends_with("prop_basalt_pillar.png"), "Crosshaven keeps the mossy basalt pillar")
	var slag_pillar: Texture2D = art.prop_texture("rock_pillar", "slag_")
	truthy(slag_pillar.resource_path.ends_with("slag_prop_rock_pillar.png"), "Slagcrown rock pillar is the volcanic sheet")
	var slag_seal: Texture2D = art.prop_texture("floor_seal", "slag_")
	truthy(slag_seal.resource_path.ends_with("slag_prop_floor_seal.png"), "Slagcrown floor seal is dark ash, not forest stone")
	var slag_vent: Texture2D = art.prop_texture("steam_vent", "slag_")
	truthy(slag_vent.resource_path.ends_with("slag_prop_steam_vent.png"), "Slagcrown steam vent is a lava shard")
	truthy(_green_fraction(slag_pillar) < 0.02, "Slagcrown rock pillar has no moss")
	truthy(_green_fraction(slag_vent) < 0.02, "Slagcrown steam vent has no moss")
	var haven_pillar: Texture2D = art.prop_texture("rock_pillar", "")
	truthy(haven_pillar.resource_path.ends_with("prop_rock_pillar.png"), "Crosshaven keeps the shared rock pillar")
	var storm_tex: Texture2D = art.terrain_texture("ground", 0, "storm_")
	var storm_px: Color = storm_tex.get_image().get_pixel(32, 16)
	truthy(storm_px.r < 0.4 and storm_px.b < 0.45 and storm_px.g < 0.35, "Stormspire ground is dark stone, not grass")
	var storm_water: Texture2D = art.terrain_texture("water", 0, "storm_")
	var storm_water_px: Color = storm_water.get_image().get_pixel(32, 16)
	truthy(storm_water_px.b > storm_water_px.r and storm_water_px.b > storm_water_px.g, "Stormspire water is the violet energy tile")
	var storm_e1: Texture2D = art.terrain_texture("ground", 1, "storm_")
	truthy(storm_e1.get_height() > 32, "Stormspire cliffs hang below the diamond")
	var wind_spark: Texture2D = art.prop_texture("spark", "wind_")
	var storm_spark: Texture2D = art.prop_texture("spark", "storm_")
	truthy(wind_spark.resource_path.ends_with("wind_prop_spark.png"), "Windmere spark is the ice crystal")
	truthy(storm_spark.resource_path.ends_with("storm_prop_spark.png"), "Stormspire spark is the energy crystal")
	var ruins: Texture2D = art.prop_texture("ruins", "wind_")
	truthy(ruins.resource_path.ends_with("prop_ruins.png"), "shared props stay on the original sheet")
	var seen := {}
	for x in 5:
		for y in 4:
			var tex: Texture2D = art.terrain_texture_at("ground", 0, "", Vector2i(x, y))
			seen[tex.resource_path] = true
	truthy(seen.size() > 1, "Crosshaven cells use more than one dirt slice")


func _diamond_seam(tex: Texture2D) -> bool:
	var img := tex.get_image()
	if img == null or img.get_width() != 64 or img.get_height() < 32:
		return false
	var tips: Array[Vector2i] = [Vector2i(32, 0), Vector2i(63, 16), Vector2i(32, 31), Vector2i(0, 16)]
	for tip in tips:
		if img.get_pixel(tip.x, tip.y).a < 0.75:
			return false
	var corners: Array[Vector2i] = [Vector2i(0, 0), Vector2i(63, 0), Vector2i(0, 31), Vector2i(63, 31)]
	for corner in corners:
		if img.get_pixel(corner.x, corner.y).a > 0.08:
			return false
	return true


## Soft Lock agua + costa. Presentation only: wet sand, pier wood, tide scorch.
## Foam stays on the diamond seam. Tags and geometry are not part of this check.
func _test_brine_punch() -> void:
	var art := load("res://board/koliseo_art.gd")
	var ground: Texture2D = art.terrain_texture("ground", 0, "brine_")
	var mud: Texture2D = art.terrain_texture("mud", 0, "brine_")
	var water: Texture2D = art.terrain_texture("water", 0, "brine_")
	var low: Texture2D = art.terrain_texture("ground", 1, "brine_")
	var high: Texture2D = art.terrain_texture("ground", 2, "brine_")
	truthy(ground.resource_path.ends_with("brine_ground.png"), "Brinewake ground is the coast sheet")
	eq(ground.get_width(), 64, "Brinewake ground is 64 px wide")
	eq(ground.get_height(), 32, "Brinewake ground diamond is 32 px tall")
	var sand := ground.get_image().get_pixel(32, 16)
	truthy(sand.r > sand.g and sand.g > sand.b and sand.r > 0.55, "Brinewake ground is wet sand")
	var scorch := mud.get_image().get_pixel(32, 16)
	truthy(scorch.r > scorch.b and scorch.r < sand.r, "Brinewake mud is darker tide scorch")
	var agua := water.get_image().get_pixel(32, 16)
	truthy(agua.g > agua.r and agua.b > agua.r, "Brinewake water stays teal")
	truthy(_green_fraction(ground) < 0.04, "Brinewake sand is not a grass carpet")
	truthy(_crust_marks(ground) >= 4, "Brinewake sand keeps tide crust accents")
	var pillar: Texture2D = art.prop_texture("rock_pillar", "brine_")
	truthy(_green_fraction(pillar) < 0.08, "Brinewake rock pillar is stone, not moss")
	truthy(_interior_veil(ground) < 0.02, "foam does not haze the sand diamond")
	truthy(_interior_veil(water) < 0.02, "foam does not haze the water diamond")
	truthy(_seam_foam(ground) > 0, "wet sand keeps foam on the seam")
	truthy(low.get_height() > 32, "Brinewake low cliffs hang below the diamond")
	truthy(high.get_height() > low.get_height(), "Brinewake high cliffs are taller")
	truthy(low.get_image().get_pixel(32, 16).a > 0.8, "Brinewake cliff cap is opaque")
	truthy(_wall_meets_cap(low), "Brinewake low stair meets the deck")
	truthy(_wall_meets_cap(high), "Brinewake high stair meets the deck")
	truthy(_deck_foot(low), "Brinewake low stair lands on a deck")
	truthy(_deck_foot(high), "Brinewake high stair lands on a deck")
	for prop_name in ["driftwood", "rock_cluster", "rock_pillar", "rubble", "ruins", "fence", "waterfall"]:
		var prop_tex: Texture2D = art.prop_texture(prop_name, "brine_")
		truthy(prop_tex.get_height() <= 48, "%s stays about one tile tall" % prop_name)
		truthy(prop_tex.get_width() <= 48, "%s stays about one tile wide" % prop_name)
	var brine_seal: Texture2D = art.prop_texture("floor_seal", "brine_")
	truthy(brine_seal.get_width() <= 40 and brine_seal.get_height() <= 20, "Brinewake floor seal is a small mark")
	var drift: Texture2D = art.prop_texture("driftwood", "brine_")
	truthy(drift.resource_path.ends_with("brine_prop_driftwood.png"), "Brinewake driftwood is the coast prop")
	var shared: Texture2D = art.prop_texture("driftwood", "")
	truthy(shared.resource_path.ends_with("prop_driftwood.png"), "other arenas keep the shared driftwood")
	var pier: Texture2D = art.prop_texture("fence", "brine_")
	truthy(pier.resource_path.ends_with("brine_prop_fence.png"), "Brinewake fence is pier wood")
	var themes := FileAccess.get_file_as_string("res://art/tilesets/original/THEMES.md")
	truthy(themes.contains("brine_ground_punch.png"), "Brinewake punch sheet is the coast source")
	var tags: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/maps/arena_colosseum_v2/tiled/brinewake_15x15_tags.json"))
	eq((tags["cells"] as Array).size(), 225, "Brinewake tags keep 225 cells")
	eq(int((tags["size"] as Array)[0]), 15, "Brinewake tag width stays 15")


## Soft Lock fuego + lava. Presentation only. Hard diamonds, platform walls,
## sparse props. The floor seal is a mark, not a second floor.
func _test_slag_punch() -> void:
	var art := load("res://board/koliseo_art.gd")
	var ground: Texture2D = art.terrain_texture("ground", 0, "slag_")
	var lava: Texture2D = art.terrain_texture("lava", 0, "slag_")
	var water: Texture2D = art.terrain_texture("water", 0, "slag_")
	var mud: Texture2D = art.terrain_texture("mud", 0, "slag_")
	var low: Texture2D = art.terrain_texture("ground", 1, "slag_")
	var high: Texture2D = art.terrain_texture("ground", 2, "slag_")
	truthy(_diamond_seam(ground), "Slagcrown ground keeps a readable diamond edge")
	truthy(_diamond_seam(lava), "Slagcrown lava keeps a readable diamond edge")
	truthy(_diamond_seam(water), "Slagcrown ash pool keeps a readable diamond edge")
	truthy(_diamond_seam(mud), "Slagcrown scorch keeps a readable diamond edge")
	truthy(high.get_height() > low.get_height() + 12, "Slagcrown high platforms are clearly taller")
	truthy(_wall_meets_cap(low), "Slagcrown low wall meets the platform")
	truthy(_wall_meets_cap(high), "Slagcrown high wall meets the platform")
	var seal: Texture2D = art.prop_texture("floor_seal", "slag_")
	truthy(seal.get_width() <= 40 and seal.get_height() <= 20, "Slagcrown floor seal does not cover the diamond")
	var basalt: Texture2D = art.prop_texture("basalt_pillar", "slag_")
	var pillar: Texture2D = art.prop_texture("rock_pillar", "slag_")
	var banner: Texture2D = art.prop_texture("banner", "slag_")
	truthy(basalt.get_width() <= 48, "Slagcrown basalt pillar stays on one tile")
	truthy(pillar.get_width() <= 40, "Slagcrown rock pillar stays narrow")
	truthy(banner.get_width() <= 36 and banner.get_height() > banner.get_width(), "Slagcrown banner is a narrow standing prop")
	var rock := ground.get_image().get_pixel(32, 16)
	var melt := lava.get_image().get_pixel(32, 16)
	truthy(rock.r < 0.55 and rock.r > rock.g, "Slagcrown ground center is dark rock, not lava soup")
	truthy(melt.r > rock.r + 0.25 and melt.r > melt.b, "Slagcrown lava is brighter than the rock")
	eq(art.SLAG_TALL_DRESS.size(), 6, "Slagcrown draws six tall props")
	eq(str(art.visible_props("slagcrown", Vector2i(0, 0), ["basalt_pillar"])[0]), "basalt_pillar", "corner pillar stays tall")
	eq(str(art.visible_props("slagcrown", Vector2i(7, 0), ["basalt_pillar"])[0]), "banner", "north edge draws a banner")
	eq(str(art.visible_props("slagcrown", Vector2i(2, 2), ["basalt_pillar"])[0]), "ash_rock", "an interior pillar stays a small mark")
	eq(str(art.visible_props("windmere", Vector2i(0, 0), ["crystal"])[0]), "crystal", "other arenas keep their own props")
	var dress := [
		"slag_ground.png", "slag_ground_v1.png", "slag_ground_v2.png", "slag_ground_v3.png", "slag_ground_v4.png",
		"slag_mud.png", "slag_water.png",
		"slag_lava.png", "slag_lava_v1.png", "slag_lava_v2.png", "slag_lava_v3.png",
		"slag_lava_v4.png", "slag_lava_v5.png", "slag_lava_v6.png", "slag_lava_v7.png",
		"slag_ground_e1.png", "slag_ground_e1_v1.png", "slag_mud_e1.png", "slag_ground_e2.png",
		"slag_prop_basalt_pillar.png", "slag_prop_rock_pillar.png", "slag_prop_banner.png",
		"slag_prop_ash_rock.png", "slag_prop_rubble.png", "slag_prop_steam_vent.png", "slag_prop_floor_seal.png",
	]
	for file_name in dress:
		var path: String = "res://art/maps/arena_colosseum_v2/tiled/tiles/" + str(file_name)
		var tex: Texture2D = load(path)
		truthy(tex != null, "%s is wired" % file_name)
		truthy(_green_fraction(tex) < 0.005, "%s has no lawn" % file_name)
	var themes := FileAccess.get_file_as_string("res://art/tilesets/original/THEMES.md")
	truthy(themes.contains("pending/lava/ground_punch.png"), "Slagcrown ground punch is the lava source")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/lava/elevation_punch.png"), "Slagcrown elevation punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/lava/props_punch.png"), "Slagcrown props punch is in the repo")
	truthy(FileAccess.file_exists("res://art/tilesets/original/pending/lava/board_mood_punch.png"), "Slagcrown mood plate stays a reference")
	var tags: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/maps/arena_colosseum_v2/tiled/slagcrown_15x15_tags.json"))
	eq((tags["cells"] as Array).size(), 225, "Slagcrown tags keep 225 cells")
	var at := {}
	for cell in tags["cells"]:
		at[Vector2i(int(cell["x"]), int(cell["y"]))] = cell
	eq(int(at[Vector2i(5, 4)]["elevation"]), 2, "Slagcrown high platform cell stays elevation 2")
	eq(str(at[Vector2i(7, 7)]["terrain"]), "lava", "Slagcrown lava river stays lava")
	eq(str(at[Vector2i(1, 12)]["terrain"]), "water", "Slagcrown ash pool tag stays water")
	eq(str((at[Vector2i(0, 0)]["paint_only"] as Array)[0]), "basalt_pillar", "Slagcrown corner prop stays the basalt pillar")


## The foot of a stair sprite is a deck, not a tread dangling into empty space.
func _deck_foot(tex: Texture2D) -> bool:
	var img := tex.get_image()
	if img == null or img.get_height() < 36 or img.get_width() != 64:
		return false
	var foot := 0
	for y in range(img.get_height() - 1, 30, -1):
		var wide := 0
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.2:
				wide += 1
		if wide > 0:
			foot = wide
			break
	return foot >= 18


func _wall_meets_cap(tex: Texture2D) -> bool:
	var img := tex.get_image()
	if img == null or img.get_height() < 36 or img.get_width() != 64:
		return false
	if img.get_pixel(32, 16).a < 0.8:
		return false
	for x in img.get_width():
		if img.get_pixel(x, 31).a > 0.5 and img.get_pixel(x, 32).a > 0.5:
			return true
	return false


## Dark warm marks on the north half of the diamond. A south shade is not crust.
func _crust_marks(tex: Texture2D) -> int:
	var img := tex.get_image()
	var lums: Array[float] = []
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a > 0.15:
				lums.append((px.r + px.g + px.b) / 3.0)
	if lums.is_empty():
		return 0
	lums.sort()
	var med: float = lums[lums.size() / 2]
	var marks := 0
	var limit_y := img.get_height() / 2
	for y in limit_y:
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a < 0.15:
				continue
			var lum := (px.r + px.g + px.b) / 3.0
			if lum < med - 0.12 and px.r + 0.02 >= px.g:
				marks += 1
	return marks


func _interior_veil(tex: Texture2D) -> float:
	var img := tex.get_image()
	var width := img.get_width()
	var face_h := mini(32, img.get_height())
	var veil := 0
	var opaque := 0
	for y in face_h:
		for x in width:
			var px := img.get_pixel(x, y)
			if px.a < 0.15:
				continue
			opaque += 1
			var metric: float = absf(float(x) - float(width - 1) * 0.5) / (float(width) * 0.5)
			metric += absf(float(y) - float(face_h - 1) * 0.5) / (float(face_h) * 0.5)
			if metric >= 0.78:
				continue
			var lum := (px.r + px.g + px.b) / 3.0
			var sat := maxf(px.r, maxf(px.g, px.b)) - minf(px.r, minf(px.g, px.b))
			var warm := px.r > px.g + 0.06 and px.r > px.b + 0.11
			var teal := px.g > px.r + 0.05 or px.b > px.r + 0.05
			var foam := lum > 0.65 and sat < 0.16
			var gray := sat < 0.14 and lum > 0.25 and not warm and not teal
			if foam or gray:
				veil += 1
	return float(veil) / float(maxi(opaque, 1))


func _seam_foam(tex: Texture2D) -> int:
	var img := tex.get_image()
	var width := img.get_width()
	var face_h := mini(32, img.get_height())
	var foam := 0
	for y in face_h:
		for x in width:
			var px := img.get_pixel(x, y)
			if px.a < 0.15:
				continue
			var metric: float = absf(float(x) - float(width - 1) * 0.5) / (float(width) * 0.5)
			metric += absf(float(y) - float(face_h - 1) * 0.5) / (float(face_h) * 0.5)
			if metric < 0.78:
				continue
			var lum := (px.r + px.g + px.b) / 3.0
			var sat := maxf(px.r, maxf(px.g, px.b)) - minf(px.r, minf(px.g, px.b))
			if lum > 0.65 and sat < 0.2:
				foam += 1
	return foam


func _green_fraction(tex: Texture2D) -> float:
	var img := tex.get_image()
	var green := 0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a < 0.15:
				continue
			n += 1
			if px.g > px.r + 0.07 and px.g > px.b + 0.05 and px.g > 0.23:
				green += 1
	return float(green) / float(maxi(n, 1))


func _ground_paint_step(tags: Dictionary) -> Dictionary:
	var at := {}
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		at[item["pos"]] = item
	var paint: Dictionary = tags.get("paint_only", {})
	for cell in paint.keys():
		if not at.has(cell):
			continue
		var dest: Dictionary = at[cell]
		if str(dest.get("terrain", "")) != "ground" or int(dest.get("elevation", 0)) != 0:
			continue
		for dir in ORTHO:
			var origin: Vector2i = cell + dir
			if not at.has(origin):
				continue
			var src: Dictionary = at[origin]
			if str(src.get("terrain", "")) != "ground" or int(src.get("elevation", 0)) != 0:
				continue
			var other := Vector2i(14, 14)
			if other == origin or other == cell:
				other = Vector2i(0, 0)
			if other == origin or other == cell:
				continue
			var props: Array = paint[cell]
			return {"from": origin, "to": cell, "other": other, "prop": str(props[0]) if not props.is_empty() else ""}
	return {}


func _sim() -> Node:
	return root.get_node("CombatSim")


func _picker(auto_launch: bool) -> Node:
	var picker: Node = (load("res://scenes/class_select.tscn") as PackedScene).instantiate()
	picker._auto_launch = auto_launch
	root.add_child(picker)
	return picker


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
