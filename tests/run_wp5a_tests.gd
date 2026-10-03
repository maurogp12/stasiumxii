extends SceneTree

## WP5a critical paths. Run: godot --headless --path . -s res://tests/run_wp5a_tests.gd

const Atlas = preload("res://backend/world_atlas.gd")
const Walk = preload("res://backend/world_walk.gd")
const Map = preload("res://backend/world_map.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

const REGIONS: Array[String] = [
	"rowanvale",
	"windmere",
	"brinewake",
	"slagcrown",
	"eastmarch_fen_edge",
	"gloomfen_mire",
	"stormspire",
	"ashen_shardfields",
	"blightwood_hollow",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loaded: Dictionary = Atlas.load_default()
	eq(bool(loaded.get("ok", false)), true, "atlas loads with the built regions (%s)" % str(loaded.get("errors", [])))
	if not bool(loaded.get("ok", false)):
		print("wp5a tests: %d passed, %d failed" % [_passed, _failed])
		quit(1)
		return
	var atlas = loaded["atlas"]
	_test_regions(atlas)
	_test_banner(atlas)
	_test_grades(atlas)
	print("wp5a tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_regions(atlas) -> void:
	for region in REGIONS:
		var level: Dictionary = atlas.levels.by_id[region]
		var chunks: Array = level["chunks"]
		var src := FileAccess.get_file_as_string("res://data/world/%s/build_%s_zones.py" % [region, region])
		var mapped := 0
		var built_ids: Array[String] = []
		var roles := {"entry": 0, "door": 0}
		for raw in src.split("\n"):
			var line := raw.strip_edges()
			var role := _role_of(line)
			if role == "":
				continue
			mapped += 1
			if roles.has(role):
				roles[role] = int(roles[role]) + 1
			var chunk_id := line.split(" ")[0]
			eq(chunks.has(chunk_id), true, "%s text map names a real chunk %s" % [region, chunk_id])
			if line.find(" built ") >= 0 or line.ends_with(" built"):
				built_ids.append(chunk_id)
		eq(mapped, chunks.size(), "%s text map has the section 3.1 count" % region)
		for chunk_id in chunks:
			eq(src.find(str(chunk_id)) >= 0, true, "%s text map includes %s" % [region, str(chunk_id)])
		eq(int(roles["entry"]), 1, "%s has one entry" % region)
		eq(int(roles["door"]), 1, "%s has one door" % region)
		var index_path := "res://data/world/%s/index.json" % region
		var opened: Dictionary = Map.load_index(index_path)
		eq(bool(opened.get("ok", false)), true, "%s index loads (%s)" % [region, str(opened.get("errors", []))])
		if not bool(opened.get("ok", false)):
			continue
		var map: WorldMap = opened["map"]
		eq(map.region, region, "%s index region" % region)
		var listed: Array = []
		for entry in map.zones.keys():
			listed.append(str(entry))
		eq(listed.size(), built_ids.size(), "%s index lists the built chunks" % region)
		for chunk_id in built_ids:
			eq(map.zones.has(chunk_id), true, "%s built %s" % [region, chunk_id])
		var entry_id := region + "_entry"
		var door_id := region + "_door"
		var entry_zone: WorldZone = map.zone(entry_id)
		var door_zone: WorldZone = map.zone(door_id)
		eq(entry_zone != null and door_zone != null, true, "%s entry and door are built" % region)
		if entry_zone == null or door_zone == null:
			continue
		var path: Dictionary = Walk.find_path(map, entry_id, entry_zone.spawn, door_id, door_zone.spawn)
		eq(bool(path.get("ok", false)), true, "%s door is reachable from the entry (%s)" % [region, str(path.get("reason", ""))])
		for chunk_id in built_ids:
			var built: WorldZone = map.zone(chunk_id)
			eq(_one_landmark(built), true, "%s has one landmark" % chunk_id)
			eq(built.presentation.is_empty(), true, "%s keeps weather out of the zone file" % chunk_id)
			for poi in built.points_of_interest:
				var at := Vector2i(int(poi["x"]), int(poi["y"]))
				eq(built.passable_at(at), true, "%s poi %s is passable" % [chunk_id, str(poi["id"])])
			if chunk_id == entry_id:
				continue
			var reached: Dictionary = Walk.find_path(map, entry_id, entry_zone.spawn, chunk_id, built.spawn)
			eq(bool(reached.get("ok", false)), true, "%s reaches %s" % [region, chunk_id])
		var stand: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/%s/stand_in.json" % region))
		eq(typeof(stand) == TYPE_DICTIONARY, true, "%s has a stand-in sidecar" % region)
		if typeof(stand) == TYPE_DICTIONARY:
			var side: Dictionary = stand
			eq(side.has("grade") and side.has("weather"), true, "%s sidecar has grade and weather" % region)
			eq(side.has("presentation"), false, "%s sidecar is not a zone file" % region)


func _test_banner(atlas) -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.weather.auto_rotate = false
	eq(str(w._unbuilt_label("rowanvale_entry")), "Rowanvale (10–15): not open yet", "the unbuilt banner names the band")
	eq(str(w._unbuilt_label("blightwood_hollow_entry")), "Blightwood Hollow (45–50): not open yet", "Blightwood's banner names the band")
	w.atlas.maps["stormspire"] = null
	var reasons: Array = []
	w.walk_rejected.connect(func(reason: String) -> void: reasons.append(reason))
	var before: String = w.zone.zone_id
	w.enter_zone("stormspire_entry", Vector2i(0, 16), false)
	eq(reasons.has("region_not_built"), true, "a region with no map still rejects the gate")
	eq(str(w._banner.text), "Stormspire (35–40): not open yet", "the banner says the region is not open yet")
	eq(w.zone.zone_id, before, "a closed region leaves the current chunk")
	w.atlas.maps["stormspire"] = atlas.maps["stormspire"]
	w.queue_free()


func _test_grades(atlas) -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.weather.auto_rotate = false
	w.enter_zone("windmere_entry", Vector2i(16, 12), false)
	eq(w.zone.zone_id, "windmere_entry", "Windmere entry loads")
	eq(str(w.weather.rotation_pool[0]), "light_cloud", "Windmere weather comes from the sidecar")
	var cold: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	eq(cold is Color and (cold as Color).b > 1.0, true, "Windmere's grade is cold blue")
	w.enter_zone("slagcrown_entry", Vector2i(16, 12), false)
	var ember: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	eq(ember is Color and (ember as Color).r > (ember as Color).b, true, "Slagcrown's grade is ember")
	w.enter_zone("gloomfen_mire_entry", Vector2i(16, 12), false)
	eq(str(w.weather.rotation_pool[0]), "light_rain", "Gloomfen weather comes from the sidecar")
	var fog: Variant = w.fx._grade_mat.get_shader_parameter("haze_col")
	eq(fog is Color and (fog as Color).g > (fog as Color).r, true, "Gloomfen's grade is green fog")
	w.enter_zone("blightwood_hollow_entry", Vector2i(16, 12), false)
	var violet: Variant = w.fx._grade_mat.get_shader_parameter("haze_col")
	eq(violet is Color and (violet as Color).b > (violet as Color).g, true, "Blightwood's grade is violet")
	w.enter_zone("crosshaven_crossroads", Vector2i(22, 18), false)
	eq(w.weather.rotation_pool.has("clear"), true, "Crosshaven keeps its own weather pool")
	var restored: Variant = w.fx._grade_mat.get_shader_parameter("warm_mul")
	eq(restored is Color and absf((restored as Color).r - 1.02) < 0.02, true, "leaving a region restores the Crosshaven grade")
	w.queue_free()
	if atlas == null:
		return


func _role_of(line: String) -> String:
	for role in ["entry", "hub", "door", "middle"]:
		if line.find(" %s " % role) >= 0 or line.ends_with(" " + role):
			return role
	return ""


func _one_landmark(zone: WorldZone) -> bool:
	if zone.props.size() != 1:
		return false
	var prop: Dictionary = zone.props[0]
	return str(prop.get("type", "")) == "tavern_3x2"


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
