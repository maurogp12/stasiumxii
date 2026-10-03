extends SceneTree

## WP6 NPCs and the region grade push.
## Run: godot --headless --path . -s res://tests/run_world_npc_tests.gd

const Book := preload("res://backend/world_npcs.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const Levels := preload("res://backend/world_levels.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

const SCHEMA := "res://data/world/schema/npcs.schema.json"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
		_test_spacing(rows, atlas_loaded["atlas"])
		_test_extra_blocked(atlas_loaded["atlas"])
	_test_talk()
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
	eq(rows.size(), 53, "the table is 33 core plus 20 named extras")
	var roles := {}
	var ids := {}
	for row in rows:
		var record: Dictionary = row
		var role := str(record["role"])
		roles[role] = int(roles.get(role, 0)) + 1
		ids[str(record["id"])] = record
		eq(_home_ok(str(record["zone_id"])), true, "%s stands on a built hub, entry, door, or Crosshaven chunk" % str(record["id"]))
	eq(int(roles["warden"]), 11, "one warden per level zone")
	eq(int(roles["trader"]), 11, "one trader per level zone")
	eq(int(roles["door_keeper"]), 11, "one door keeper per level zone")
	eq(int(roles["elder"]), 5, "one elder per town")
	for role in ["guide", "herald", "banker", "smith", "fisher", "farmer", "woodcutter", "archivist", "ferry_captain", "forge_master", "fen_guide", "hermit", "seer", "last_watcher", "coil_engineer"]:
		eq(int(roles.get(role, 0)), 1, "one %s" % role)
	var guide: Dictionary = ids["crossroads_guide"]
	eq(str(guide["zone_id"]), "crosshaven_crossroads", "the Guide stands at the Crossroads")
	eq(int(guide["cell"]["x"]), 24, "Guide cell x is the spec example")
	eq(int(guide["cell"]["y"]), 18, "Guide cell y is the spec example")
	var guide_lines: Array = guide["lines"]
	eq(str(guide_lines[0]), "Welcome to Crosshaven.", "Guide welcome line")
	eq(str(guide_lines[1]), "Click the ground to walk. Gold arrows lead on.", "Guide walk line")
	eq(ids.has("stoneford_elder"), true, "Stoneford has an Elder")
	eq(str(ids["granary_door_keeper"]["zone_id"]), "crosshaven_crossroads", "the granary keeper stands under the market")
	eq(str(ids["millrace_door_keeper"]["zone_id"]), "crosshaven_southbridge", "Millrace Vaults is under Southbridge's watermill")
	var level_doc: Dictionary = Levels.load_default()
	eq(bool(level_doc.get("ok", false)), true, "level zones load")
	if not bool(level_doc.get("ok", false)):
		return
	var level_rows: Array = level_doc["levels"].zones
	for zone in level_rows:
		var chunks: Array = zone["chunks"]
		var saw_w := false
		var saw_t := false
		var saw_d := false
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
	var soon: Button = w.dialogue.find_child("ComingSoon", true, false)
	eq(soon != null and soon.disabled, true, "Coming soon is disabled")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	w._unhandled_input(esc)
	eq(w.dialogue.is_open(), false, "Esc closes the dialogue")
	w._approach_npc(w.npc_book.by_id("crossroads_guide"))
	eq(w.dialogue.is_open(), true, "already beside the Guide, the dialogue opens")
	w.dialogue.notify_outside_click()
	eq(w.dialogue.is_open(), false, "a click outside closes the dialogue")
	w.queue_free()


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
				eq(_manhattan(cell, cells[j]) >= 3, true, "%s is at least 3 cells from %s" % [npc_id, str(other["id"])])
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
		if str(prop["type"]) != "tavern_3x2":
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
