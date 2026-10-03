extends SceneTree

## Level zones sidecar: the 11 bands, chunk ownership, and the loader.
## Run: godot --headless --path . -s res://tests/run_world_levels_tests.gd

const Levels = preload("res://backend/world_levels.gd")
const PATH := "res://data/world/level_zones.json"
const SCHEMA_PATH := "res://data/world/schema/level_zones.schema.json"

const HEART_CHUNKS: Array[String] = [
	"crosshaven_crossroads",
	"crosshaven_road_north",
	"crosshaven_road_west",
	"crosshaven_road_east",
	"crosshaven_road_southwest",
	"crosshaven_road_south",
]
const TOWN_CHUNKS: Array[String] = [
	"crosshaven_northgate",
	"crosshaven_stoneford",
	"crosshaven_eastmarch",
	"crosshaven_westwatch",
	"crosshaven_southbridge",
]

## Proposed bands from the zone plan. Colours start at the spec example
## #3fbf4f and step toward purple. The map image was not in the repo.
const EXPECTED := [
	["crosshaven_heart", "Crosshaven Heart", 1, 5, "#3fbf4f", "old_granary_cellar"],
	["crosshaven_towns", "Crosshaven Towns", 5, 10, "#58bd3c", "threshgate"],
	["rowanvale", "Rowanvale", 10, 15, "#82bb3a", "rotting_orchard_barrow"],
	["windmere", "Windmere", 15, 20, "#acb937", "galevault"],
	["brinewake", "Brinewake", 20, 25, "#b79735", "tidehold"],
	["slagcrown", "Slagcrown", 25, 30, "#b56832", "ashmarch"],
	["eastmarch_fen_edge", "Eastmarch Fen Edge", 25, 30, "#b33930", "sunken_mill"],
	["gloomfen_mire", "Gloomfen Mire", 30, 38, "#b02e51", "drowned_abbey"],
	["stormspire", "Stormspire", 35, 40, "#ae2b7c", "coilgate"],
	["ashen_shardfields", "Ashen Shardfields", 38, 45, "#ac29a6", "shard_hollow"],
	["blightwood_hollow", "Blightwood Hollow", 45, 50, "#8227a9", "heart_of_the_blight"],
]

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("world levels tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_schema_file()
	_test_no_class_name()
	var loaded: Dictionary = Levels.load_default()
	eq(loaded["ok"], true, "level zones load (%s)" % str(loaded["errors"]))
	if not bool(loaded["ok"]):
		return
	var levels = loaded["levels"]
	_test_plan(levels)
	_test_chunks(levels)
	_test_rules(levels)
	eq(levels.validate()["ok"], true, "validate() accepts the shipped file")
	var map_loaded: Dictionary = WorldMap.load_default()
	eq(map_loaded["ok"], true, "Crosshaven index still loads")
	_test_rejects()


func _test_schema_file() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	eq(schema["additionalProperties"], false, "schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.level_zones", "schema format")
	eq(schema["properties"]["zones"]["items"]["additionalProperties"], false, "zone schema rejects unknown keys")


func _test_no_class_name() -> void:
	var src := FileAccess.get_file_as_string("res://backend/world_levels.gd")
	eq(src.find("class_name") < 0, true, "loader has no class_name")


func _test_plan(levels) -> void:
	eq(levels.zones.size(), 11, "eleven level zones")
	for i in EXPECTED.size():
		var want: Array = EXPECTED[i]
		var zone: Dictionary = levels.zones[i]
		eq(str(zone["id"]), str(want[0]), "zone %d id" % i)
		eq(str(zone["name"]), str(want[1]), "%s name" % want[0])
		eq(int(zone["level_min"]), int(want[2]), "%s level_min" % want[0])
		eq(int(zone["level_max"]), int(want[3]), "%s level_max" % want[0])
		eq(str(zone["color"]), str(want[4]), "%s color" % want[0])
		eq(str(zone["dungeon"]), str(want[5]), "%s dungeon" % want[0])
		var span: Dictionary = levels.band(str(want[0]))
		eq(int(span["level_min"]), int(want[2]), "band min %s" % want[0])
		eq(int(span["level_max"]), int(want[3]), "band max %s" % want[0])


func _test_chunks(levels) -> void:
	eq(_ids(levels.zone_for_chunk("crosshaven_crossroads")), "crosshaven_heart", "crossroads is Heart")
	for chunk in HEART_CHUNKS:
		var zone: Dictionary = levels.zone_for_chunk(chunk)
		eq(str(zone.get("id", "")), "crosshaven_heart", "%s is zone 1" % chunk)
		var span: Dictionary = levels.band(chunk)
		eq(int(span["level_min"]), 1, "%s band min" % chunk)
		eq(int(span["level_max"]), 5, "%s band max" % chunk)
	for chunk in TOWN_CHUNKS:
		var zone: Dictionary = levels.zone_for_chunk(chunk)
		eq(str(zone.get("id", "")), "crosshaven_towns", "%s is zone 2" % chunk)
		var span: Dictionary = levels.band(chunk)
		eq(int(span["level_min"]), 5, "%s band min" % chunk)
		eq(int(span["level_max"]), 10, "%s band max" % chunk)
	eq(levels.zone_for_chunk("not_a_chunk").is_empty(), true, "unknown chunk is an empty result")
	eq(levels.band("not_a_zone").is_empty(), true, "unknown band is an empty result")
	eq(levels.zone_for_chunk("").is_empty(), true, "empty chunk id does not crash")
	for i in EXPECTED.size():
		var zone_id := str(EXPECTED[i][0])
		var zone: Dictionary = levels.by_id[zone_id]
		if zone_id == "crosshaven_heart":
			eq(zone["chunks"], HEART_CHUNKS, "Heart chunks")
		elif zone_id == "crosshaven_towns":
			eq(zone["chunks"], TOWN_CHUNKS, "Towns chunks")
		else:
			eq((zone["chunks"] as Array).is_empty(), true, "%s has no chunks until its region exists" % zone_id)


func _test_rules(levels) -> void:
	for zone in levels.zones:
		var lo := int(zone["level_min"])
		var hi := int(zone["level_max"])
		eq(lo >= 1 and lo <= hi and hi <= 50, true, "%s band is inside 1-50" % zone["id"])
	eq(int(levels.by_id["gloomfen_mire"]["level_min"]) >= 30, true, "swamp starts at 30 or above")
	eq(int(levels.by_id["blightwood_hollow"]["level_min"]) >= 45, true, "dark zone starts at 45 or above")
	eq(int(levels.by_id["stormspire"]["level_min"]), 35, "Stormspire starts at 35")
	eq(int(levels.by_id["stormspire"]["level_max"]), 40, "Stormspire ends at 40")
	var owned := {}
	for zone in levels.zones:
		for chunk in zone["chunks"]:
			eq(owned.has(chunk), false, "chunk %s is in one zone" % chunk)
			owned[str(chunk)] = str(zone["id"])
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/crosshaven/index.json"))
	for entry in index["zones"]:
		var chunk := str(entry["zone_id"])
		eq(owned.has(chunk), true, "Crosshaven chunk %s is in a level zone" % chunk)
		var zone_id := str(owned[chunk])
		eq(zone_id == "crosshaven_heart" or zone_id == "crosshaven_towns", true, "%s resolves to zone 1 or 2" % chunk)


func _test_rejects() -> void:
	var extra := _doc()
	extra["note"] = "no"
	_rejects(extra, "unknown key note")
	var high := _doc()
	_zone(high, "rowanvale")["level_max"] = 51
	_rejects(high, "level_max out of range")
	var low := _doc()
	_zone(low, "rowanvale")["level_min"] = 0
	_rejects(low, "level_min out of range")
	var flipped := _doc()
	_zone(flipped, "rowanvale")["level_min"] = 15
	_zone(flipped, "rowanvale")["level_max"] = 10
	_rejects(flipped, "level_min above level_max")
	var dropped := _doc()
	var kept: Array = []
	for zone in dropped["zones"]:
		if str(zone["id"]) != "blightwood_hollow":
			kept.append(zone)
	dropped["zones"] = kept
	_rejects(dropped, "missing zone blightwood_hollow")
	var twice := _doc()
	_zone(twice, "crosshaven_towns")["chunks"].append("crosshaven_crossroads")
	_rejects(twice, "duplicate chunk crosshaven_crossroads")
	var spire := _doc()
	_zone(spire, "stormspire")["level_min"] = 36
	_rejects(spire, "stormspire must be 35-40")
	var swamp := _doc()
	_zone(swamp, "gloomfen_mire")["level_min"] = 29
	_rejects(swamp, "gloomfen_mire starts below 30")
	var dark := _doc()
	_zone(dark, "blightwood_hollow")["level_min"] = 44
	_rejects(dark, "blightwood_hollow starts below 45")
	var stranger := _doc()
	stranger["zones"].append({
		"id": "extra_zone",
		"name": "Extra",
		"level_min": 1,
		"level_max": 2,
		"chunks": [],
		"color": "#000000",
		"dungeon": "extra_door",
	})
	_rejects(stranger, "unexpected zone extra_zone")
	eq(Levels.parse([])["ok"], false, "an array is not a level-zone document")
	var dangling := _doc()
	_zone(dangling, "rowanvale")["chunks"] = ["rowanvale_meadow"]
	_rejects(dangling, "chunk rowanvale_meadow is not in a region index")
	var gap := _doc()
	var heart_chunks: Array = _zone(gap, "crosshaven_heart")["chunks"]
	heart_chunks.erase("crosshaven_crossroads")
	_rejects(gap, "chunk crosshaven_crossroads is not in a level zone")


func _doc() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return (parsed as Dictionary).duplicate(true)


func _zone(doc: Dictionary, id: String) -> Dictionary:
	for zone in doc["zones"]:
		if str(zone["id"]) == id:
			return zone
	return {}


func _ids(zone: Dictionary) -> String:
	return str(zone.get("id", ""))


func _rejects(doc: Dictionary, needle: String) -> void:
	var parsed: Dictionary = Levels.parse(doc)
	eq(parsed["ok"], false, "rejects when %s" % needle)
	var hit := false
	for err in parsed["errors"]:
		if str(err).find(needle) >= 0:
			hit = true
	truthy(hit, "error mentions %s (%s)" % [needle, parsed["errors"]])


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
