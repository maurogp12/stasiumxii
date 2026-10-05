extends SceneTree

## WP6 NPCs and the region grade push.
## Run: godot --headless --path . -s res://tests/run_world_npc_tests.gd

const Book := preload("res://backend/world_npcs.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const Levels := preload("res://backend/world_levels.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Regions := preload("res://backend/world_regions.gd")
const Art := preload("res://scenes/world/npc/npc_sprites.gd")
const Roam := preload("res://scenes/world/npc/npc_roam.gd")

const SCHEMA := "res://data/world/schema/npcs.schema.json"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Regions.set_enabled(true)
	_test_schema()
	var loaded: Dictionary = Book.load_default()
	eq(bool(loaded.get("ok", false)), true, "npc book loads")
	if not bool(loaded.get("ok", false)):
		_finish()
		return
	var book = loaded["npcs"]
	var rows: Array = book.all()
	_test_roster(rows)
	var atlas_loaded: Dictionary = Atlas.load_default()
	eq(bool(atlas_loaded.get("ok", false)), true, "atlas loads")
	if bool(atlas_loaded.get("ok", false)):
		_test_cells(rows, atlas_loaded["atlas"])
		_test_two_cells_apart_fails()
		_test_spacing(rows, atlas_loaded["atlas"])
		_test_extra_blocked(atlas_loaded["atlas"])
	_test_painted_art(rows)
	_test_talk()
	_test_plate_alignment()
	_test_painted_in_world()
	_test_roam_rules(atlas_loaded["atlas"] if bool(atlas_loaded.get("ok", false)) else null)
	_test_walkers()
	_test_click_stops_walker()
	_test_npc_cover()
	_test_northgate_snow_npcs()
	_test_grades()
	await _test_grade_hues()
	_finish()


func _finish() -> void:
	print("world npc tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_schema() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	eq(schema["additionalProperties"], false, "npc schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.world_npcs", "npc format")
	var role_enum: Array = schema["$defs"]["npc"]["properties"]["role"]["enum"]
	eq(role_enum.has("coil_engineer"), true, "Coil Engineer has a role; the 4.5 role list omitted them")
	var packed: Resource = load("res://scenes/world/npc/world_npc.tscn")
	eq(packed != null, true, "world npc scene loads")
	var panel: Resource = load("res://scenes/world/ui/npc_dialogue.tscn")
	eq(panel != null, true, "dialogue scene loads")


func _test_roster(rows: Array) -> void:
	# The 4.5 table names 20 extras on top of 33 core NPCs. The summary line says 51.
	eq(rows.size(), 74, "33 core, 20 outer extras, and the Crosshaven town roster")
	var roles := {}
	var ids := {}
	for row in rows:
		var record: Dictionary = row
		var role := str(record["role"])
		roles[role] = int(roles.get(role, 0)) + 1
		ids[str(record["id"])] = record
		eq(_home_ok(str(record["zone_id"])), true, "%s stands on a built hub, entry, door, or Crosshaven chunk" % str(record["id"]))
	eq(int(roles["warden"]), 15, "a warden in every section 00 town and every outer zone")
	eq(int(roles["trader"]), 15, "a trader in every section 00 town and every outer zone")
	eq(int(roles["door_keeper"]), 14, "a door keeper for every dungeon, and none at the Crossroads")
	eq(int(roles["elder"]), 5, "one elder per town")
	for role in ["guide", "herald", "banker", "smith", "fisher"]:
		eq(int(roles.get(role, 0)), 1, "one %s" % role)
	for role in ["farmer", "woodcutter", "archivist", "ferry_captain", "forge_master", "fen_guide", "hermit", "seer", "last_watcher", "coil_engineer"]:
		eq(int(roles.get(role, 0)), 2, "one %s in town and one in the outer region" % role)
	var guide: Dictionary = ids["crossroads_guide"]
	eq(str(guide["zone_id"]), "crosshaven_crossroads", "the Guide stands at the Crossroads")
	eq(int(guide["cell"]["x"]), 24, "Guide cell x is the spec example")
	eq(int(guide["cell"]["y"]), 18, "Guide cell y is the spec example")
	var guide_lines: Array = guide["lines"]
	eq(str(guide_lines[0]), "Welcome to Crosshaven.", "Guide welcome line")
	eq(str(guide_lines[1]), "Click the ground to walk. Gold arrows lead on.", "Guide walk line")
	eq(ids.has("stoneford_elder"), true, "Stoneford has an Elder")
	eq(str(ids["granary_door_keeper"]["zone_id"]), "crosshaven_stoneford", "the granary keeper stands in Stoneford")
	eq(int(ids["granary_door_keeper"]["cell"]["x"]), 15, "the granary keeper stands beside the cellar hatch (16, 11)")
	eq(int(ids["granary_door_keeper"]["cell"]["y"]), 11, "the granary keeper stands beside the cellar hatch (16, 11)")
	eq(str(ids["drowned_abbey_door_keeper"]["zone_id"]), "crosshaven_southbridge", "the Drowned Abbey keeper stands in Southbridge")
	var level_doc: Dictionary = Levels.load_default()
	eq(bool(level_doc.get("ok", false)), true, "level zones load")
	if not bool(level_doc.get("ok", false)):
		return
	var level_rows: Array = level_doc["levels"].zones
	var town_ids: Array[String] = ["stoneford", "northgate", "eastmarch", "southbridge", "westwatch"]
	for zone in level_rows:
		var chunks: Array = zone["chunks"]
		var saw_w := false
		var saw_t := false
		var saw_d := false
		var saw_elder := false
		for row in rows:
			var record: Dictionary = row
			if not chunks.has(str(record["zone_id"])):
				continue
			var role := str(record["role"])
			if role == "warden":
				saw_w = true
			elif role == "trader":
				saw_t = true
			elif role == "door_keeper":
				saw_d = true
			elif role == "elder":
				saw_elder = true
		if str(zone["id"]) == "crossroads":
			eq(saw_w and saw_t and not saw_d, true, "the Crossroads has a warden and a trader, and no door keeper")
		elif town_ids.has(str(zone["id"])):
			eq(saw_elder and saw_w and saw_t and saw_d, true, "%s has an elder, a warden, a trader, and a door keeper" % str(zone["id"]))
		else:
			eq(saw_w and saw_t and saw_d, true, "%s has a warden, a trader, and a door keeper" % str(zone["id"]))


func _home_ok(zone_id: String) -> bool:
	if zone_id.begins_with("crosshaven_"):
		return true
	return zone_id.ends_with("_entry") or zone_id.ends_with("_hub") or zone_id.ends_with("_door")


func _test_cells(rows: Array, atlas) -> void:
	var seen := {}
	for row in rows:
		var record: Dictionary = row
		var zone_id := str(record["zone_id"])
		var region: String = str(atlas.region_of_chunk(zone_id))
		var map: WorldMap = atlas.maps[region]
		eq(map != null, true, "%s region is loaded" % zone_id)
		if map == null:
			continue
		var zone: WorldZone = map.zone(zone_id)
		eq(zone != null, true, "%s chunk exists" % zone_id)
		if zone == null:
			continue
		var cell := Vector2i(int(record["cell"]["x"]), int(record["cell"]["y"]))
		var key := zone_id + "#%d#%d" % [cell.x, cell.y]
		eq(seen.has(key), false, "%s does not share a cell" % str(record["id"]))
		seen[key] = true
		eq(zone.passable_at(cell), true, "%s stands on a passable cell" % str(record["id"]))
		eq(zone.exit_link(cell).is_empty(), true, "%s is not on an exit" % str(record["id"]))
		eq(atlas.gate_at(zone_id, cell).is_empty(), true, "%s is not on a gate" % str(record["id"]))
		eq(cell != zone.spawn, true, "%s is not on the spawn" % str(record["id"]))
		var on_poi := false
		for poi in zone.points_of_interest:
			if int(poi["x"]) == cell.x and int(poi["y"]) == cell.y:
				on_poi = true
		eq(on_poi, false, "%s is not on a door or other point of interest" % str(record["id"]))
		if str(record["role"]) == "door_keeper" and zone_id.ends_with("_door"):
			var beside := false
			for poi in zone.points_of_interest:
				var poi_cell := Vector2i(int(poi["x"]), int(poi["y"]))
				if absi(poi_cell.x - cell.x) + absi(poi_cell.y - cell.y) == 1:
					beside = true
			eq(beside, true, "%s stands next to the dungeon mark" % str(record["id"]))


func _test_extra_blocked(atlas) -> void:
	var map: WorldMap = atlas.maps["crosshaven"]
	var guide := Vector2i(24, 18)
	var start := Vector2i(22, 18)
	var blocked := {WorldWalk.cell_key("crosshaven_crossroads", guide): true}
	var onto: Dictionary = WorldWalk.find_path(map, "crosshaven_crossroads", start, "crosshaven_crossroads", guide, null, blocked)
	eq(bool(onto.get("ok", true)), false, "an NPC cell is not a walk target")
	eq(str(onto.get("reason", "")), "blocked", "the blocked reason is blocked")
	var around: Dictionary = WorldWalk.find_path(map, "crosshaven_crossroads", start, "crosshaven_crossroads", Vector2i(25, 18), null, blocked)
	eq(bool(around.get("ok", false)), true, "a path can go around the NPC")
	var open: Dictionary = WorldWalk.find_path(map, "crosshaven_crossroads", start, "crosshaven_crossroads", guide)
	eq(bool(open.get("ok", false)), true, "find_path without extra_blocked is unchanged")


func _test_talk() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	eq(w.npc_book != null, true, "the world loads the npc book")
	eq(w.npcs_root.get_child_count() > 0, true, "the Crossroads spawns its NPCs")
	eq(w.npc_plates is CanvasLayer and w.npc_plates.layer > 6, true, "name plates draw above the fog")
	eq(w.npc_plates.get_child_count() == w.npcs_root.get_child_count(), true, "every NPC has a plate above the fog")
	var plate: Variant = w.npc_plates.get_child(0)
	eq(str(plate.plate_text) != "", true, "the plate shows the NPC name")
	var guide_cell := Vector2i(24, 18)
	eq(w._npc_at(guide_cell).is_empty(), false, "the Guide occupies the spec cell")
	var blocked: Dictionary = w.walk_to(guide_cell)
	eq(bool(blocked.get("ok", true)), false, "clicking the Guide's cell does not walk onto it")
	eq(w.walker.cell == Vector2i(22, 18), true, "the hero stays on the spawn")
	w._approach_npc(w.npc_book.by_id("crossroads_guide"))
	eq(w.dialogue.is_open(), false, "dialogue stays closed until the hero arrives")
	eq(w.walker.is_moving(), true, "the hero walks to a free neighbour")
	_drive(w)
	eq(w.walker.is_moving(), false, "the approach finishes")
	eq(w.dialogue.is_open(), true, "dialogue opens after arrival")
	eq(w.walker.facing == "e" or w.walker.facing == "w" or w.walker.facing == "n" or w.walker.facing == "s", true, "the hero faces the Guide")
	var npc_facing := ""
	for node in w.npcs_root.get_children():
		if str(node.npc_id) == "crossroads_guide":
			npc_facing = str(node.facing)
	eq(npc_facing != "" and npc_facing != w.walker.facing, true, "the Guide turns to face the hero")
	var guide_node: Node2D = w._npc_node("crossroads_guide")
	eq(str(guide_node.facing), _opposite(str(w.walker.facing)), "the Guide faces straight back at the hero")
	eq(str(guide_node.anim), "talk", "the Guide plays the talk gesture when the dialogue opens")
	eq(guide_node.is_held(), true, "the Guide holds still while the dialogue is open")
	for _i in 20:
		guide_node.tick(0.05)
	eq(str(guide_node.anim), "idle", "talk plays once, then the Guide idles")
	var soon: Button = w.dialogue.find_child("ComingSoon", true, false)
	eq(soon != null and soon.disabled, true, "Coming soon is disabled")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	w._unhandled_input(esc)
	eq(w.dialogue.is_open(), false, "Esc closes the dialogue")
	eq(guide_node.is_held(), false, "closing the dialogue lets the Guide go back to the post routine")
	w._approach_npc(w.npc_book.by_id("crossroads_guide"))
	eq(w.dialogue.is_open(), true, "already beside the Guide, the dialogue opens")
	w.dialogue.notify_outside_click()
	eq(w.dialogue.is_open(), false, "a click outside closes the dialogue")
	w.queue_free()


func _test_plate_alignment() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.weather.auto_rotate = false
	_assert_plate_geometry(w, "crossroads")
	w.enter_zone("gloomfen_mire_entry", Vector2i(8, 8), false)
	_assert_plate_geometry(w, "gloomfen")
	var heads := {}
	var names := {}
	for node in w.npcs_root.get_children():
		heads[str(node.npc_id)] = float(node._plate.head_y)
		names[str(node.display_name)] = true
	eq(names.has("Warden") and names.has("Trader") and names.has("Hermit"), true, "Gloomfen entry shows the Warden, Trader, and Hermit")
	# Painted NPCs: the plate sits on the role's highest idle row, so it does
	# not bob per frame. This replaces the stand-in check that compared the
	# texture tops of two tinted class sprites (Hermit vs Warden).
	for node in w.npcs_root.get_children():
		var art: Dictionary = node.art
		var expect := -(float(art["pivot"].y) - float(art["head_top"])) * Art.DRAW_SCALE_1X
		eq(absf(float(node._head_local_y()) - expect) < 0.01, true, "%s plate rides the painted head line" % str(node.npc_id))
	var crosshaven: WorldMap = w.atlas.maps["crosshaven"]
	w.enter_zone("crosshaven_eastmarch", crosshaven.zone("crosshaven_eastmarch").spawn, false)
	var tall := 0.0
	var plain := 0.0
	for node in w.npcs_root.get_children():
		if str(node.role) == "ferry_captain":
			tall = float(node._head_local_y())
		elif str(node.role) == "trader":
			plain = float(node._head_local_y())
	eq(tall < plain, true, "the Ferry Captain's hat lifts the plate above the Trader's")
	w.queue_free()


func _assert_plate_geometry(w: Node2D, where: String) -> void:
	var gap0 := -1.0
	var saw := 0
	for node in w.npcs_root.get_children():
		node._sync_plate()
		var plate: Variant = node._plate
		eq(plate != null, true, "%s has a plate (%s)" % [str(node.npc_id), where])
		if plate == null:
			continue
		var box: Rect2 = plate.backing_rect()
		var label: Rect2 = plate.label_rect()
		eq(box.encloses(label), true, "%s label rect lies inside the backing (%s)" % [str(node.npc_id), where])
		var pads: Array[float] = [
			label.position.x - box.position.x,
			label.position.y - box.position.y,
			box.end.x - label.end.x,
			box.end.y - label.end.y,
		]
		var pad_ok := true
		for pad in pads:
			if pad < 4.0 or pad > 6.0:
				pad_ok = false
		eq(pad_ok, true, "%s backing wraps the label with 4–6 px padding (%s)" % [str(node.npc_id), where])
		var base_y: float = plate.baseline_y()
		eq(base_y > box.position.y and base_y < box.end.y, true, "%s baseline sits inside the backing (%s)" % [str(node.npc_id), where])
		var gap: float = float(plate.head_y) - box.end.y
		eq(gap >= 6.0 and gap <= 8.0, true, "%s plate is 6–8 px above the head (%s)" % [str(node.npc_id), where])
		if gap0 < 0.0:
			gap0 = gap
		eq(absf(gap - gap0) < 0.05, true, "%s keeps the same gap above the head (%s)" % [str(node.npc_id), where])
		saw += 1
	eq(saw > 0, true, "%s has plates to measure" % where)


func _test_grades() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.weather.auto_rotate = false
	w.enter_zone("windmere_entry", Vector2i(16, 12), false)
	var cold: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	var cold_sat: float = float(w.fx._grade_mat.get_shader_parameter("saturation"))
	eq(cold is Color and (cold as Color).b > 1.05, true, "Windmere reads cold blue")
	eq(cold_sat < 0.7, true, "Windmere is desaturated")
	eq(float(w.fx._grade_mat.get_shader_parameter("grade_mix")) == 1.0, true, "a region grade stays on in any weather")
	w.enter_zone("brinewake_entry", Vector2i(16, 12), false)
	var sea: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	var sea_haze: Variant = w.fx._grade_mat.get_shader_parameter("haze_col")
	eq(sea is Color and (sea as Color).g > (sea as Color).r and (sea as Color).b > (sea as Color).r, true, "Brinewake reads sea teal")
	eq(sea_haze is Color and (sea_haze as Color).b > 0.8, true, "Brinewake has a light blue haze")
	w.enter_zone("stormspire_entry", Vector2i(16, 12), false)
	var slate: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	eq(slate is Color and (slate as Color).r < 0.7 and (slate as Color).b > (slate as Color).r, true, "Stormspire reads darker slate violet")
	eq(str(w.weather.rotation_pool[0]), "wind", "Stormspire keeps the wind")
	w.enter_zone("gloomfen_mire_entry", Vector2i(16, 12), false)
	var murk: float = float(w.fx._grade_mat.get_shader_parameter("haze_max"))
	var fog: Variant = w.fx._grade_mat.get_shader_parameter("haze_col")
	eq(murk > 0.4, true, "Gloomfen's haze is high enough to read as murk")
	eq(fog is Color and (fog as Color).g > (fog as Color).r, true, "Gloomfen's fog is green-grey")
	w.enter_zone("eastmarch_fen_edge_entry", Vector2i(16, 12), false)
	var fen: float = float(w.fx._grade_mat.get_shader_parameter("haze_max"))
	eq(fen > 0.2 and fen < murk, true, "Fen Edge sits between Crosshaven and Gloomfen")
	w.enter_zone("slagcrown_entry", Vector2i(16, 12), false)
	var ember: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	eq(ember is Color and (ember as Color).r > (ember as Color).b, true, "Slagcrown stays ember")
	w.enter_zone("blightwood_hollow_entry", Vector2i(16, 12), false)
	var violet: Variant = w.fx._grade_mat.get_shader_parameter("haze_col")
	eq(violet is Color and (violet as Color).b > (violet as Color).g, true, "Blightwood stays violet")
	w.enter_zone("crosshaven_crossroads", Vector2i(22, 18), false)
	var restored: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	eq(restored is Color and absf((restored as Color).r - 1.02) < 0.02, true, "Crosshaven grade restores")
	eq(float(w.fx._grade_mat.get_shader_parameter("grade_mix")) == 0.0, true, "Crosshaven rain still drops its own gold")
	eq(float(w.fx._grade_mat.get_shader_parameter("tint_amount")) == 0.0, true, "Crosshaven has no luminance tint")
	w.queue_free()


func _test_two_cells_apart_fails() -> void:
	eq(_cells_apart(Vector2i(0, 0), Vector2i(2, 0)) >= 3, false, "two cells apart in a straight line fails")
	eq(_cells_apart(Vector2i(19, 16), Vector2i(18, 18)) >= 3, false, "the old town-square diagonal of 2 fails")
	eq(_cells_apart(Vector2i(0, 0), Vector2i(3, 0)) >= 3, true, "three cells apart passes")
	eq(_cells_apart(Vector2i(0, 0), Vector2i(3, 2)) >= 3, true, "three cells apart on a diagonal passes")


func _test_spacing(rows: Array, atlas) -> void:
	var by_zone := {}
	for row in rows:
		var record: Dictionary = row
		var zone_id := str(record["zone_id"])
		if not by_zone.has(zone_id):
			by_zone[zone_id] = []
		(by_zone[zone_id] as Array).append(record)
	for zone_id in by_zone.keys():
		var group: Array = by_zone[zone_id]
		var region: String = str(atlas.region_of_chunk(zone_id))
		var map: WorldMap = atlas.maps[region]
		var zone: WorldZone = map.zone(zone_id)
		var gates: Array = _gate_cells(atlas, zone_id)
		var cells: Array = []
		for row in group:
			var record: Dictionary = row
			cells.append(Vector2i(int(record["cell"]["x"]), int(record["cell"]["y"])))
		for i in group.size():
			var record: Dictionary = group[i]
			var cell: Vector2i = cells[i]
			var npc_id := str(record["id"])
			eq(_manhattan(cell, zone.spawn) >= 2, true, "%s is at least 2 cells from the spawn" % npc_id)
			for gate_cell in gates:
				eq(_manhattan(cell, gate_cell) >= 2, true, "%s is at least 2 cells from the gate" % npc_id)
			for j in range(i + 1, group.size()):
				var other: Dictionary = group[j]
				var apart := _cells_apart(cell, cells[j])
				eq(apart >= 3, true, "%s is at least 3 cells from %s" % [npc_id, str(other["id"])])
			var role := str(record["role"])
			if role == "door_keeper" and zone_id.ends_with("_door"):
				var door := _door_cell(zone)
				eq(_manhattan(cell, door) == 1, true, "%s stands beside the door" % npc_id)
				eq(cell.y != door.y, true, "%s is off the door path" % npc_id)
				eq(zone.terrain_at(cell) != "dirt_road", true, "%s is not standing on the road into the door" % npc_id)
			if role == "warden" and not gates.is_empty():
				var nearest := _nearest(cell, gates)
				eq(nearest >= 2 and nearest <= 6, true, "%s stands near the gate arrival" % npc_id)
			if role == "warden" and zone_id.ends_with("_hub"):
				var arrival := _entry_exits(zone)
				var near_arrival := _nearest(cell, arrival)
				eq(near_arrival >= 2 and near_arrival <= 6, true, "%s stands near the path in from the entry" % npc_id)
			if role == "trader" and (zone_id.ends_with("_hub") or zone_id.ends_with("_entry")):
				eq(zone.terrain_at(cell) != "dirt_road", true, "%s keeps the stall off the road" % npc_id)
				eq(_beside_road(zone, cell), true, "%s stands at the side of the path" % npc_id)
			if role == "trader" and zone_id.begins_with("crosshaven_"):
				eq(_beside_stall(zone, cell), true, "%s stands beside a market stall" % npc_id)
			if (zone_id.ends_with("_hub") or zone_id.ends_with("_entry")) and role != "warden" and role != "trader" and role != "door_keeper":
				eq(_nearest(cell, _landmark_cells(zone)) <= 3, true, "%s stands near the chunk landmark" % npc_id)


func _test_grade_hues() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.weather.auto_rotate = false
	w.weather.time_of_day = 12.0
	if w._hud_label != null:
		w._hud_label.visible = false
	var bands := {
		"windmere_entry": {"min": 185.0, "max": 225.0},
		"brinewake_entry": {"min": 160.0, "max": 190.0},
		"stormspire_entry": {"min": 220.0, "max": 270.0},
		"slagcrown_entry": {"min": 15.0, "max": 35.0},
		"blightwood_hollow_entry": {"min": 280.0, "max": 330.0},
	}
	var headless := DisplayServer.get_name() == "headless"
	for zone_id in bands.keys():
		w.enter_zone(zone_id, Vector2i(16, 12), false)
		w.weather.time_of_day = 12.0
		w.weather.settle()
		if w._banner != null:
			w._banner.modulate.a = 0.0
		var mean := Color.BLACK
		if headless:
			# The dummy renderer has no viewport texture. Grade the entry's
			# own ground tile with the live shader uniforms.
			mean = _apply_grade(_terrain_mean(w.zone), w.fx._grade_mat)
		else:
			for _i in 4:
				await process_frame
			var image := w.get_viewport().get_texture().get_image()
			mean = _mean_rgb(image)
		var hsv := _hsv(mean)
		print("grade %s hue %.1f sat %.3f rgb %.3f %.3f %.3f" % [zone_id, hsv.x, hsv.y, mean.r, mean.g, mean.b])
		eq(mean.get_luminance() > 0.05, true, "%s render is not black" % zone_id)
		var band: Dictionary = bands[zone_id]
		var hue_ok := hsv.x >= float(band["min"]) and hsv.x <= float(band["max"])
		if zone_id == "stormspire_entry":
			eq(hue_ok or hsv.y < 0.2, true, "Stormspire mean is slate grey-violet")
		else:
			eq(hue_ok, true, "%s mean hue is in band" % zone_id)
	var cold_amt: float = 0.0
	w.enter_zone("windmere_entry", Vector2i(16, 12), false)
	cold_amt = float(w.fx._grade_mat.get_shader_parameter("tint_amount"))
	eq(cold_amt >= 0.35 and cold_amt <= 0.55, true, "Windmere tint amount is in the thumbnail range")
	w.queue_free()


func _gate_cells(atlas, zone_id: String) -> Array:
	var cells: Array = []
	var seen := {}
	for gate in atlas.gates:
		var frm: Dictionary = gate["from"]
		var dest: Dictionary = gate["to"]
		for side in [frm, dest]:
			if str(side["zone_id"]) != zone_id:
				continue
			var cell := Vector2i(int(side["x"]), int(side["y"]))
			var key := "%d#%d" % [cell.x, cell.y]
			if seen.has(key):
				continue
			seen[key] = true
			cells.append(cell)
	return cells


func _entry_exits(zone: WorldZone) -> Array:
	var cells: Array = []
	for exit_rec in zone.exits:
		if not str(exit_rec["target_zone"]).ends_with("_entry"):
			continue
		for link in exit_rec["links"]:
			var frm: Dictionary = link["from"]
			cells.append(Vector2i(int(frm["x"]), int(frm["y"])))
	return cells


func _door_cell(zone: WorldZone) -> Vector2i:
	for poi in zone.points_of_interest:
		if str(poi["id"]).ends_with("_door"):
			return Vector2i(int(poi["x"]), int(poi["y"]))
	return Vector2i(-1, -1)


func _landmark_cells(zone: WorldZone) -> Array:
	var cells: Array = []
	for prop in zone.props:
		if not str(prop.get("id", "")).ends_with("_landmark"):
			continue
		for foot in prop["footprint"]:
			cells.append(Vector2i(int(foot["x"]), int(foot["y"])))
	return cells


func _beside_road(zone: WorldZone, cell: Vector2i) -> bool:
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = cell + dir
		if zone.in_bounds(next) and zone.terrain_at(next) == "dirt_road":
			return true
	return false


func _beside_stall(zone: WorldZone, cell: Vector2i) -> bool:
	for prop in zone.props:
		if str(prop["type"]) != "market_stall":
			continue
		for foot in prop["footprint"]:
			var at := Vector2i(int(foot["x"]), int(foot["y"]))
			if _manhattan(cell, at) == 1:
				return true
	return false


func _nearest(cell: Vector2i, others: Array) -> int:
	var best := 1000000
	for other in others:
		best = mini(best, _manhattan(cell, other))
	return best


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Column gap or row gap, whichever is larger. A diagonal of 2 is two cells apart.
func _cells_apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _terrain_mean(zone: WorldZone) -> Color:
	var counts := {}
	for y in zone.height:
		for x in zone.width:
			var id := zone.terrain_at(Vector2i(x, y))
			counts[id] = int(counts.get(id, 0)) + 1
	var best := ""
	var best_n := -1
	for id in counts.keys():
		if int(counts[id]) > best_n:
			best = str(id)
			best_n = int(counts[id])
	var img: Image = null
	for path in [
		"res://art/world/crosshaven/tiles/_2x/%s_a.png" % best,
		"res://art/world/crosshaven/tiles/_2x/%s.png" % best,
		"res://art/world/crosshaven/tiles/%s_a.png" % best,
		"res://art/world/crosshaven/tiles/%s.png" % best,
	]:
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex != null:
			img = tex.get_image()
			break
	if img == null:
		return Color.BLACK
	var acc := Vector3.ZERO
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var px := img.get_pixel(x, y)
			if px.a < 0.05:
				continue
			acc += Vector3(px.r, px.g, px.b)
			n += 1
	if n == 0:
		return Color.BLACK
	acc /= float(n)
	return Color(acc.x, acc.y, acc.z)


## The grade shader, in the same order, so a headless run can score the entry.
func _apply_grade(src: Color, mat: ShaderMaterial) -> Color:
	var warmth := _param_float(mat, "warmth", 1.0)
	var grade_amt := maxf(warmth, _param_float(mat, "grade_mix", 0.0))
	var warm: Color = mat.get_shader_parameter("warm_mul")
	var sat_u := _param_float(mat, "saturation", 1.06)
	var tint: Color = mat.get_shader_parameter("tint_col")
	var tint_amt := _param_float(mat, "tint_amount", 0.0) * grade_amt
	var contrast := _param_float(mat, "contrast", 1.04)
	var haze: Color = mat.get_shader_parameter("haze_col")
	var haze_max := _param_float(mat, "haze_max", 0.15)
	var c := Color(src.r * lerpf(1.0, warm.r, grade_amt), src.g * lerpf(1.0, warm.g, grade_amt), src.b * lerpf(1.0, warm.b, grade_amt))
	var luma := _luma(c)
	var sat := lerpf(1.06, sat_u, grade_amt)
	c = Color(lerpf(luma, c.r, sat), lerpf(luma, c.g, sat), lerpf(luma, c.b, sat))
	luma = _luma(c)
	c = Color(lerpf(c.r, luma * tint.r, tint_amt), lerpf(c.g, luma * tint.g, tint_amt), lerpf(c.b, luma * tint.b, tint_amt))
	c = Color((c.r - 0.5) * contrast + 0.5, (c.g - 0.5) * contrast + 0.5, (c.b - 0.5) * contrast + 0.5)
	var veil := maxf(haze_max - 0.2, 0.0) * 0.65
	c = Color(lerpf(c.r, haze.r, veil), lerpf(c.g, haze.g, veil), lerpf(c.b, haze.b, veil))
	return Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0))


func _param_float(mat: ShaderMaterial, param: String, fallback: float) -> float:
	var value: Variant = mat.get_shader_parameter(param)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _mean_rgb(image: Image) -> Color:
	var acc := Vector3.ZERO
	var n := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var px := image.get_pixel(x, y)
			acc += Vector3(px.r, px.g, px.b)
			n += 1
	if n == 0:
		return Color.BLACK
	acc /= float(n)
	return Color(acc.x, acc.y, acc.z)


func _hsv(c: Color) -> Vector2:
	var maxc := maxf(c.r, maxf(c.g, c.b))
	var minc := minf(c.r, minf(c.g, c.b))
	var d := maxc - minc
	var sat := 0.0
	if maxc > 0.0001:
		sat = d / maxc
	var hue := 0.0
	if d > 0.0001:
		if maxc == c.r:
			hue = fposmod((c.g - c.b) / d, 6.0)
		elif maxc == c.g:
			hue = (c.b - c.r) / d + 2.0
		else:
			hue = (c.r - c.g) / d + 4.0
		hue *= 60.0
	return Vector2(hue, sat)


## Every role in npcs.json has a painted folder that matches its json.
func _test_painted_art(rows: Array) -> void:
	var roles := {}
	for row in rows:
		roles[str((row as Dictionary)["role"])] = true
	eq(Art.folder_for("seer"), "shard_seer", "the seer role uses the Shard Seer art")
	for role in roles.keys():
		var folder := Art.folder_for(str(role))
		var root := "res://art/characters/world/npc/%s/" % folder
		var meta_path := root + folder + ".json"
		eq(FileAccess.file_exists(meta_path), true, "%s has a painted folder and json" % str(role))
		if not FileAccess.file_exists(meta_path):
			continue
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		var art: Dictionary = Art.load_role(str(role))
		eq(art.is_empty(), false, "%s painted art loads" % str(role))
		if art.is_empty():
			continue
		var size_2x: Array = meta["frame_size_2x"]
		var pivot_2x: Array = meta["pivot_px_2x"]
		eq(art["frame"], Vector2i(int(size_2x[0]) / 2, int(size_2x[1]) / 2), "%s 1x frame is half the json 2x frame" % str(role))
		eq(art["pivot"], Vector2(float(pivot_2x[0]) * 0.5, float(pivot_2x[1]) * 0.5), "%s 1x pivot is half the json 2x pivot" % str(role))
		var mirror: Dictionary = meta["mirror"]
		eq(str(mirror["W"]["src"]) == "S" and bool(mirror["W"]["flip_h"]), true, "%s mirror: W is S flipped" % str(role))
		eq(str(mirror["E"]["src"]) == "N" and bool(mirror["E"]["flip_h"]), true, "%s mirror: E is N flipped" % str(role))
		var anims: Dictionary = meta["anims"]
		for need in ["idle", "walk", "talk"]:
			eq(anims.has(need), true, "%s ships %s" % [str(role), need])
		eq(int(anims["walk"]["frames"]), 8, "%s walk is 8 frames" % str(role))
		eq(bool(anims["talk"]["loop"]), false, "%s talk is one-shot" % str(role))
		eq(str(art["work"]) != "", true, "%s has a work or patrol_look anim for pauses" % str(role))
		for anim_name in anims.keys():
			var spec: Dictionary = anims[anim_name]
			var frames := int(spec["frames"])
			for src in ["s", "n"]:
				var one: Texture2D = load("%s%s_%s.png" % [root, str(anim_name), src])
				var two: Texture2D = load("%s_2x/%s_%s.png" % [root, str(anim_name), src])
				eq(one != null and two != null, true, "%s %s_%s has 1x and 2x strips" % [str(role), str(anim_name), src])
				if one == null or two == null:
					continue
				eq(Vector2i(one.get_width(), one.get_height()), Vector2i(frames * int(size_2x[0]) / 2, int(size_2x[1]) / 2), "%s %s_%s 1x strip is frames x half frame" % [str(role), str(anim_name), src])
				eq(Vector2i(two.get_width(), two.get_height()), Vector2i(frames * int(size_2x[0]), int(size_2x[1])), "%s %s_%s 2x strip is frames x json frame" % [str(role), str(anim_name), src])
		# Locked rule: S front down-right (+x), W front down-left (+y),
		# N back up-left (-x), E back up-right (-y).
		eq(Art.source_for(art, "e"), {"src": "s", "flip": false}, "%s step e draws S as painted" % str(role))
		eq(Art.source_for(art, "s"), {"src": "s", "flip": true}, "%s step s draws W = S flipped" % str(role))
		eq(Art.source_for(art, "w"), {"src": "n", "flip": false}, "%s step w draws N as painted" % str(role))
		eq(Art.source_for(art, "n"), {"src": "n", "flip": true}, "%s step n draws E = N flipped" % str(role))
	eq(Art.load_role("no_such_role").is_empty(), true, "a role with no folder has no painted art (stand-in fallback)")


## NPCs in the world draw the painted art, not the tinted stand-in.
func _test_painted_in_world() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	var hero_h := _hero_height(w)
	eq(hero_h > 40.0, true, "the hero has a measurable height")
	var heights: Array[float] = []
	var crosshaven: WorldMap = w.atlas.maps["crosshaven"]
	for zid in ["crosshaven_crossroads", "crosshaven_stoneford", "crosshaven_eastmarch", "crosshaven_westwatch"]:
		w.enter_zone(zid, crosshaven.zone(zid).spawn, false)
		for node in w.npcs_root.get_children():
			var sprite: Sprite2D = node.get_node("Sprite")
			eq(node.is_painted(), true, "%s draws painted art" % str(node.npc_id))
			eq(sprite.modulate, Color.WHITE, "%s has no role tint" % str(node.npc_id))
			eq(sprite.region_enabled and sprite.region_rect.size == Vector2(128, 128), true, "%s draws one 1x frame" % str(node.npc_id))
			eq(is_equal_approx(sprite.scale.x, Art.DRAW_SCALE_1X), true, "%s uses the shared NPC draw scale" % str(node.npc_id))
			eq(str(node.anim), "idle", "%s idles by default" % str(node.npc_id))
			var src := Art.source_for(node.art, str(node.facing))
			eq(sprite.flip_h, bool(src["flip"]), "%s mirror follows its facing" % str(node.npc_id))
			heights.append(-float(node._head_local_y()))
	heights.sort()
	var median: float = heights[heights.size() / 2]
	print("npc height median %.1f px, hero %.1f px" % [median, hero_h])
	eq(median <= hero_h, true, "NPCs read no taller than the hero (median)")
	eq(median >= hero_h * 0.8, true, "NPCs are not tiny next to the hero")
	for h in heights:
		eq(h <= hero_h * 1.05, true, "no NPC towers over the hero")
	w.queue_free()


func _hero_height(w: Node2D) -> float:
	var sprite: Sprite2D = null
	for child in w.walker.get_children():
		if child is Sprite2D and (child as Sprite2D).visible and (child as Sprite2D).texture != null:
			sprite = child
			break
	if sprite == null:
		return 0.0
	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var top := -1
	var bottom := -1
	var x0 := 0
	var y0 := 0
	var wide := image.get_width()
	var tall := image.get_height()
	if sprite.region_enabled:
		x0 = int(sprite.region_rect.position.x)
		y0 = int(sprite.region_rect.position.y)
		wide = int(sprite.region_rect.size.x)
		tall = int(sprite.region_rect.size.y)
	for y in tall:
		for x in wide:
			if image.get_pixel(x0 + x, y0 + y).a > 0.2:
				if top < 0:
					top = y
				bottom = y
				break
	if top < 0:
		return 0.0
	return float(bottom - top) * absf(sprite.scale.y)


## Behaviour per spec 4.5a, from role.
func _test_roam_rules(atlas) -> void:
	for role in ["farmer", "woodcutter", "fisher", "smith", "hermit", "coil_engineer"]:
		eq(Roam.behaviour_for(role), Roam.WANDER, "%s wanders near home" % role)
	eq(Roam.behaviour_for("warden"), Roam.PATROL, "wardens patrol")
	for role in ["guide", "banker", "herald", "trader", "door_keeper", "elder", "archivist", "ferry_captain", "last_watcher"]:
		eq(Roam.behaviour_for(role), Roam.POST, "%s stays at the post" % role)
	eq(Roam.WANDER_RADIUS >= 4 and Roam.WANDER_RADIUS <= 6, true, "wander radius is 4–6 cells")
	eq(Roam.path({Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true}, Vector2i(0, 0), Vector2i(2, 0)), [Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i], "roam path walks the allowed cells")
	eq(Roam.path({Vector2i(0, 0): true, Vector2i(2, 0): true}, Vector2i(0, 0), Vector2i(2, 0)).is_empty(), true, "roam path never crosses a cell outside the area")
	if atlas == null:
		return
	var map: WorldMap = atlas.maps["crosshaven"]
	var zone: WorldZone = map.zone("crosshaven_stoneford")
	var home := Vector2i(16, 18)
	var allowed := Roam.area(zone, home, 5, {})
	for c in allowed.keys():
		eq(zone.passable_at(c) and Roam.manhattan(c, home) <= 5, true, "roam area cell %s is passable and within 5" % str(c))


## Movers stay on passable cells, inside their radius, off doors and exits,
## and keep the spacing. Post NPCs never leave their cell.
func _test_walkers() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	var crosshaven: WorldMap = w.atlas.maps["crosshaven"]
	for zid in ["crosshaven_stoneford", "crosshaven_southbridge", "crosshaven_eastmarch"]:
		var z: WorldZone = crosshaven.zone(zid)
		w.enter_zone(zid, z.spawn, false)
		var hero: Vector2i = w.walker.cell
		var moved := {}
		var worked := {}
		var walked := {}
		var bad := 0
		var nodes: Array = w.npcs_root.get_children()
		var reach_at_start := {}
		for node in nodes:
			if w._talk_stand(node.cell).x >= 0:
				reach_at_start[node.npc_id] = true
		for t in 2400:
			for node in nodes:
				node.tick(0.05)
			for node in nodes:
				var c: Vector2i = node.cell
				if c != node.home:
					moved[node.npc_id] = true
				if str(node.anim) == "walk":
					walked[node.npc_id] = true
				if str(node.anim) == str(node.art.get("work", "-")):
					worked[node.npc_id] = true
				if node.behaviour == Roam.POST:
					if c != node.home:
						bad += 1
						print("FAIL detail: post %s left home" % node.npc_id)
					continue
				var paused: bool = node.is_dwelling()
				if paused:
					var spot_ok: bool = c == node.home or node.patrol_stops().has(c)
					for spot in node.pause_spots():
						spot_ok = spot_ok or spot["cell"] == c
					if not spot_ok:
						bad += 1
						print("FAIL detail: %s dwells on %s, not a spot" % [node.npc_id, str(c)])
				for at in node.occupied_cells():
					var ok: bool = z.passable_at(at) and z.exit_link(at).is_empty() and (node.allowed_cells() as Dictionary).has(at)
					ok = ok and Roam.manhattan(at, node.home) <= Roam.radius_for(node.behaviour)
					ok = ok and at != hero and at != z.spawn
					var clear := 2 if paused else 1
					for poi in z.points_of_interest:
						ok = ok and Roam.manhattan(at, Vector2i(int(poi["x"]), int(poi["y"]))) >= clear
					if paused:
						ok = ok and Roam.manhattan(at, z.spawn) >= 2
					if not ok:
						bad += 1
						if bad < 5:
							print("FAIL detail: %s at %s" % [node.npc_id, str(at)])
					for other in nodes:
						if other == node:
							continue
						# Bodies never touch; a paused walker keeps 3 cells
						# from every NPC that stands at a post (4.5).
						var need := 3 if paused and other.behaviour == Roam.POST else 2
						for oc in other.occupied_cells():
							if Roam.cells_apart(at, oc) < need:
								bad += 1
								if bad < 5:
									print("FAIL detail: %s %s too close to %s %s" % [node.npc_id, str(at), other.npc_id, str(oc)])
		eq(bad, 0, "%s movers stay on allowed cells, in radius, off doors/exits/spawn/hero, 3+ cells apart" % zid)
		var movers := 0
		for node in nodes:
			if node.behaviour == Roam.POST:
				continue
			movers += 1
			var roomy: bool = node.pause_spots().size() > 1 or node.patrol_stops().size() > 1
			if roomy:
				eq(moved.has(node.npc_id), true, "%s moves in two minutes" % str(node.npc_id))
				eq(walked.has(node.npc_id), true, "%s plays walk while moving" % str(node.npc_id))
			else:
				# A warden on a one-cell ledge has no loop; it looks around in place.
				eq(moved.has(node.npc_id), false, "%s has no room and stays on its cell" % str(node.npc_id))
			eq(worked.has(node.npc_id), true, "%s plays %s when it pauses" % [str(node.npc_id), str(node.art["work"])])
		eq(movers > 0, true, "%s has moving NPCs" % zid)
		# Every mover's area keeps its pause cells clear of lanes.
		for node in nodes:
			for spot in node.pause_spots():
				var sc: Vector2i = spot["cell"]
				if sc != node.home:
					eq(Roam.dwell_ok(z, sc), true, "%s pause spot %s does not cut a lane" % [str(node.npc_id), str(sc)])
		# Whoever the hero could reach at the start can still be reached.
		var blocked: Dictionary = w._extra_blocked()
		for node in nodes:
			if not reach_at_start.has(node.npc_id):
				continue
			var target: Vector2i = w._talk_stand(node.cell)
			eq(target.x >= 0, true, "%s can still be reached by the hero" % str(node.npc_id))
		eq(blocked.size() >= nodes.size(), true, "every NPC body blocks walking")
	w.queue_free()


## Clicking a walking NPC stops it; the dialogue opens with the talk gesture;
## it resumes after the dialogue closes.
func _test_click_stops_walker() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	var crosshaven: WorldMap = w.atlas.maps["crosshaven"]
	var z: WorldZone = crosshaven.zone("crosshaven_stoneford")
	w.enter_zone("crosshaven_stoneford", z.spawn, false)
	var farmer: Node2D = w._npc_node("stoneford_farmer")
	eq(farmer != null, true, "the Stoneford Farmer spawns")
	if farmer == null:
		w.queue_free()
		return
	var n := 0
	while not farmer.is_walking() and n < 4000:
		farmer.tick(0.05)
		n += 1
	eq(farmer.is_walking(), true, "the Farmer sets off on the wander route")
	var record: Dictionary = w.npc_book.by_id("stoneford_farmer")
	w._approach_npc(record)
	eq(farmer.is_held(), true, "a click holds the Farmer")
	var stop: Vector2i = farmer.stop_cell()
	for _i in 200:
		farmer.tick(0.05)
	eq(farmer.cell, stop, "the Farmer finishes the step and stands still")
	eq(farmer.is_walking(), false, "the Farmer is not walking while the hero comes")
	_drive(w)
	if not w.dialogue.is_open():
		w._approach_npc(record)
		_drive(w)
	eq(w.dialogue.is_open(), true, "the Farmer dialogue opens")
	eq(str(farmer.anim), "talk", "the Farmer plays talk once")
	eq(str(farmer.facing), _opposite(str(w.walker.facing)), "the Farmer faces the hero")
	for _i in 200:
		farmer.tick(0.05)
	eq(farmer.cell, stop, "the Farmer stays put while the dialogue is open")
	w.dialogue.close()
	eq(farmer.is_held(), false, "closing the dialogue releases the Farmer")
	var resumed := false
	for _i in 4000:
		farmer.tick(0.05)
		if farmer.is_walking():
			resumed = true
			break
	eq(resumed, true, "the Farmer resumes the route after the dialogue")
	w.queue_free()


## A building or tall prop over an NPC fades like it does over the hero, and
## lets go once nothing stands behind it. The Eastmarch Ferry Captain stands
## right behind a house.
func _test_npc_cover() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	w.npc_roam = false
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	var crosshaven: WorldMap = w.atlas.maps["crosshaven"]
	w.enter_zone("crosshaven_eastmarch", crosshaven.zone("crosshaven_eastmarch").spawn, false)
	var captain: Node2D = w._npc_node("eastmarch_ferry_captain")
	eq(captain != null, true, "the Eastmarch Ferry Captain spawns")
	if captain == null:
		w.queue_free()
		return
	# Park the hero on an open cell no prop or decor covers, so every fade
	# seen below comes from the NPC.
	var open_cell := Vector2i(-1, -1)
	for y in w.zone.height:
		for x in w.zone.width:
			var c := Vector2i(x, y)
			if open_cell.x >= 0 or not w.zone.passable_at(c) or not w.zone.exit_link(c).is_empty():
				continue
			if not w._npc_at(c).is_empty() or Roam.cells_apart(c, captain.cell) < 6:
				continue
			var spot: Vector2 = w.Pick.cell_center(w.zone, c)
			var hidden := false
			for root_node in [w.props_root, w.decor_root]:
				for child in root_node.get_children():
					if child.hides_feet(spot):
						hidden = true
			if not hidden:
				open_cell = c
	eq(open_cell.x >= 0, true, "Eastmarch has an open cell for the hero")
	w.enter_zone("crosshaven_eastmarch", open_cell, false)
	captain = w._npc_node("eastmarch_ferry_captain")
	var feet: Vector2 = w.props_root.to_local(captain.global_position)
	var hero_feet: Vector2 = w.props_root.to_local(w.to_global(w.walker.position))
	var cover: Node2D = null
	for prop in w.props_root.get_children():
		if prop.hides_feet(feet) and not prop.hides_feet(hero_feet):
			cover = prop
			break
	eq(cover != null, true, "a building stands in front of the Ferry Captain")
	if cover == null:
		w.queue_free()
		return
	print("ferry captain cover: %s" % str(cover.prop_type))
	eq(cover.cover_rect.size.y > 36.0, true, "the Ferry Captain's cover is a tall prop")
	eq(int(cover.z_index) > int(captain.z_index), true, "unfaded, the building draws over the Ferry Captain")
	eq(w._npc_cover_feet().size(), w.npcs_root.get_child_count(), "cover checks only this chunk's NPCs")
	w._process(0.016)
	eq(bool(cover.covering_npc), true, "the building knows an NPC is behind it")
	eq(cover.modulate.a < 0.9, true, "the building over the Ferry Captain fades")
	eq(int(cover.z_index) > int(captain.z_index), true, "the faded building still sorts over the Ferry Captain")
	eq(int(cover.z_index), maxi(int(cover.base_z), int(captain.z_index) + 1), "an NPC-only fade keeps the building's own depth")
	eq(bool(w.walker._covered), false, "an NPC behind a building does not give the hero the cover rim")
	var faded := 0
	for root_node in [w.props_root, w.decor_root]:
		for prop in root_node.get_children():
			if prop.modulate.a < 0.9 and not prop.covering_npc and not bool(prop.get("night_only")):
				faded += 1
	eq(faded, 0, "no prop fades with nothing behind it")
	# Step the captain out in front of the house: the fade lets go.
	var at := captain.position
	captain.position = at + Vector2(0, 400)
	w._process(0.016)
	eq(bool(cover.covering_npc), false, "the building lets go once the Ferry Captain is out")
	eq(is_equal_approx(cover.modulate.a, 1.0), true, "the building is opaque again with nothing behind it")
	eq(int(cover.z_index), int(cover.base_z), "the building sorts back to its own depth")
	captain.position = at
	w._process(0.016)
	eq(cover.modulate.a < 0.9, true, "the fade comes back with the Ferry Captain")
	captain.visible = false
	w._process(0.016)
	eq(is_equal_approx(cover.modulate.a, 1.0), true, "a hidden NPC holds no fade")
	w.queue_free()


## Northgate snow with NPCs: the snowfall sits under the name plates and the
## HUD, and no ring pine lands on an NPC post or a walker's cells.
func _test_northgate_snow_npcs() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.enter_zone("crosshaven_northgate", Vector2i(20, 14), false)
	var snow_layer: CanvasLayer = w.get_node("SnowfallLayer")
	var hud_layer := 0
	for child in w.get_children():
		if child is CanvasLayer and child.find_child("HudSheet", false, false) != null:
			hud_layer = child.layer
	eq(snow_layer.layer < w.npc_plates.layer, true, "snowfall draws under the NPC name plates")
	eq(hud_layer > 0 and snow_layer.layer < hud_layer, true, "snowfall draws under the HUD")
	eq(w.npcs_root.get_child_count() > 0, true, "Northgate spawns its NPCs")
	var pines: Array = w._snow_pines_for(w.zone)
	eq(pines.size() > 4, true, "pines still ring Northgate")
	var pine_set := {}
	for c in pines:
		pine_set[c] = true
	var on_npc := 0
	var on_route := 0
	for node in w.npcs_root.get_children():
		var home: Vector2i = node.home
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if pine_set.has(home + Vector2i(dx, dy)):
					on_npc += 1
		for c in node.allowed_cells().keys():
			if pine_set.has(c):
				on_route += 1
		for spot in node.pause_spots():
			if pine_set.has(spot["cell"]):
				on_route += 1
		for stop in node.patrol_stops():
			if pine_set.has(stop):
				on_route += 1
	eq(on_npc, 0, "no Northgate pine stands on or beside an NPC post")
	eq(on_route, 0, "no Northgate pine stands on a walker's cells")
	var keep: Dictionary = w.npc_keep_clear(w.zone, w.npc_book.for_zone(w.zone.zone_id))
	var clash := 0
	for c in w.snow_pine_cells(w.zone, keep):
		if keep.has(c):
			clash += 1
	eq(clash, 0, "snow_pine_cells honours the NPC keep-clear set")
	var forbid: Dictionary = w._roam_forbidden(w.zone, w.npc_book.for_zone(w.zone.zone_id)[0], false)
	var open := 0
	for c in pines:
		if not forbid.has(c):
			open += 1
	eq(open, 0, "pine cells are forbidden to NPC walkers")
	var decor_pines := 0
	for d in w.decor_root.get_children():
		if str(d.decor_type).begins_with("tree_pine_snow"):
			decor_pines += 1
	eq(decor_pines, pines.size(), "every kept pine is planted in Northgate")
	w.queue_free()


func _opposite(dir: String) -> String:
	match dir:
		"n":
			return "s"
		"s":
			return "n"
		"e":
			return "w"
		"w":
			return "e"
	return ""


func _drive(w: Node2D) -> void:
	var n := 0
	while w.walker.is_moving() and n < 4000:
		w.walker.advance(0.05)
		n += 1


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
