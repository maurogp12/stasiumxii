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
		_test_extra_blocked(atlas_loaded["atlas"])
	_test_talk()
	_test_grades()
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
	w.queue_free()


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
