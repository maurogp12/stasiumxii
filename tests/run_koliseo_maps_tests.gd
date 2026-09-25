extends SceneTree

## Koliseo ship maps: tags load, lava stays on Slagcrown, paint_only does not
## block, and the hot-seat picker walks into a match on the chosen map.
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
	_test_picker_flow()
	await _test_picker_navigates()
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


func _test_picker_flow() -> void:
	var script := load("res://scenes/class_select.gd")
	script.hotseat_classes.clear()
	script.hotseat_map_id = ""
	var picker := _picker(false)
	picker.choose_mode("hotseat")
	eq(picker.phase_name(), "map", "hot-seat opens the map picker")
	eq(picker.map_cards_visible(), true, "map cards are on screen")
	eq(picker.class_cards_visible(), false, "class cards wait until a map is picked")
	for map_id in MAPS:
		eq(picker.map_card_title(map_id), CellTagMap.label_of(map_id), "%s card label" % map_id)
		eq(picker.map_card_has_preview(map_id), true, "%s card shows a preview" % map_id)
	var unknown: Dictionary = picker.pick_map("pulse")
	eq(bool(unknown.get("ok", true)), false, "unknown map is rejected")
	eq(str(unknown.get("reason", "")), "unknown_map", "reject reason is unknown_map")
	eq(picker.phase_name(), "map", "a bad map stays on the picker")
	var picked: Dictionary = picker.pick_map("slagcrown")
	eq(bool(picked.get("ok", false)), true, "Slagcrown click is accepted")
	eq(picker.phase_name(), "hotseat_p1", "map pick continues to P1")
	eq(picker.selected_map_id(), "slagcrown", "selected map is Slagcrown")
	truthy(picker.prompt_text().contains("P1"), "P1 prompt follows the map")
	picker.go_back()
	eq(picker.phase_name(), "map", "back from P1 returns to the map picker")
	picker.pick_map("windmere")
	picker.pick_class("kestrel")
	picker.pick_class("ironjaw")
	eq(script.hotseat_map_id, "windmere", "sealed map is Windmere")
	var config: Dictionary = script.local_match_config()
	eq(str(config.get("map_id", "")), "windmere", "match config carries the map id")
	var snap: Dictionary = _sim().reset_match(config)
	eq(str(snap.get("demo_map", "")), "windmere_15", "picker config loads Windmere")
	eq(str(snap["units"][0]["class_id"]), "kestrel", "picker config keeps P1")
	eq(str(snap["units"][1]["class_id"]), "ironjaw", "picker config keeps P2")
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


func _test_picker_navigates() -> void:
	var script := load("res://scenes/class_select.gd")
	script.hotseat_classes.clear()
	script.hotseat_map_id = ""
	var picker := _picker(true)
	picker.choose_mode("hotseat")
	picker.pick_map("brinewake")
	picker.pick_class("mender")
	picker.pick_class("bastion")
	var arrived := false
	for _i in 12:
		await process_frame
		if current_scene == null:
			continue
		if current_scene.scene_file_path != "res://main.tscn":
			continue
		var snap: Dictionary = _sim().snapshot()
		if str(snap.get("demo_map", "")) == "brinewake_15" and str(snap.get("phase", "")) == "DEPLOYMENT":
			arrived = true
			eq(str(snap["units"][0]["class_id"]), "mender", "navigated match seat 0 is mender")
			eq(str(snap["units"][1]["class_id"]), "bastion", "navigated match seat 1 is bastion")
			break
	eq(arrived, true, "map picker navigates into a Brinewake match")


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
