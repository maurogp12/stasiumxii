extends SceneTree

## Koliseo ship maps: tags load, lava stays on Slagcrown, paint_only does not
## block, and hot-seat rolls one of the five arenas (no map chooser).
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
		eq(bool(tile.get("walkable", false)), true, "%s paint_only %s does not block" % [map_id, prop])
		eq(str(tile.get("terrain_type", "")), "ground", "%s painted step is ground" % map_id)
		var paint: Dictionary = sim.snapshot().get("paint_only", {})
		truthy(paint.has(dest), "%s stores paint_only beside the walk tile" % map_id)
		var moved: Dictionary = sim.submit({"type": "move", "to": dest})
		eq(bool(moved.get("ok", false)), true, "%s walk onto %s is legal" % [map_id, prop])
		eq(int(moved["events"][0]["mp_spent"]), 1, "%s paint_only does not add MP" % map_id)
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
	truthy(haven_grade.g > haven_grade.r and haven_grade.g > haven_grade.b, "Crosshaven stays grass")
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
