extends SceneTree

## Level zones sidecar: the 11 bands, chunk ownership, and the loader.
## Run: godot --headless --path . -s res://tests/run_world_levels_tests.gd

const Levels = preload("res://backend/world_levels.gd")
const PATH := "res://data/world/level_zones.json"
const SCHEMA_PATH := "res://data/world/schema/level_zones.schema.json"

const BUILT_CHUNKS: Array[String] = [
	"crosshaven_crossroads",
	"crosshaven_road_north",
	"crosshaven_road_west",
	"crosshaven_road_east",
	"crosshaven_road_southwest",
	"crosshaven_road_south",
	"crosshaven_northgate",
	"crosshaven_stoneford",
	"crosshaven_eastmarch",
	"crosshaven_westwatch",
	"crosshaven_southbridge",
]
const HOME_IDS: Array[String] = [
	"crossroads",
	"stoneford",
	"northgate",
	"eastmarch",
	"southbridge",
	"westwatch",
]

## Section 00 bands, then the nine outer zones. Colours start at the spec
## example #3fbf4f and step toward purple.
const EXPECTED := [
	["crossroads", "Crossroads", 1, 1, "#3fbf4f", "millrace_vaults"],
	["stoneford", "Stoneford", 1, 10, "#58bd3c", "old_granary_cellar"],
	["northgate", "Northgate", 10, 20, "#82bb3a", "frostspire_archive"],
	["eastmarch", "Eastmarch", 20, 30, "#acb937", "saltmaw_grotto"],
	["southbridge", "Southbridge", 30, 40, "#b33930", "drowned_abbey"],
	["westwatch", "Westwatch", 40, 50, "#8227a9", "heart_of_the_blight"],
	["rowanvale", "Rowanvale", 10, 15, "#82bb3a", "rotting_orchard_barrow"],
	["windmere", "Windmere", 15, 20, "#acb937", "frostspire_archive"],
	["brinewake", "Brinewake", 20, 25, "#b79735", "saltmaw_grotto"],
	["slagcrown", "Slagcrown", 25, 30, "#b56832", "cinderforge_depths"],
	["eastmarch_fen_edge", "Eastmarch Fen Edge", 25, 30, "#b33930", "sunken_mill"],
	["gloomfen_mire", "Gloomfen Mire", 30, 38, "#b02e51", "drowned_abbey"],
	["stormspire", "Stormspire", 35, 40, "#ae2b7c", "thunderwell_core"],
	["ashen_shardfields", "Ashen Shardfields", 38, 45, "#ac29a6", "shard_hollow"],
	["blightwood_hollow", "Blightwood Hollow", 45, 50, "#8227a9", "heart_of_the_blight"],
]

## Phone Stasis door ids from spec 4.6 at c037429. PC dungeons are PC's own.
## These strings may appear only on the denylist lines below.
const PHONE_DUNGEON_NAMES: Array[String] = [
	"threshgate",
	"galevault",
	"tidehold",
	"ashmarch",
	"coilgate",
]
const PHONE_SCAN_ROOTS: Array[String] = [
	"res://data",
	"res://backend",
	"res://tests",
	"res://scenes",
]
const PHONE_SCAN_EXT: Array[String] = ["gd", "json", "tscn", "tres", "cfg", "godot"]

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
	_test_fen_edge_placement(levels)
	eq(levels.validate()["ok"], true, "validate() accepts the shipped file")
	var map_loaded: Dictionary = WorldMap.load_default()
	eq(map_loaded["ok"], true, "Crosshaven index still loads")
	_test_rejects()
	_test_no_phone_dungeon_names()


func _test_schema_file() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	eq(schema["additionalProperties"], false, "schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.level_zones", "schema format")
	eq(schema["properties"]["zones"]["items"]["additionalProperties"], false, "zone schema rejects unknown keys")
	var required: Array = schema["properties"]["zones"]["items"]["required"]
	eq(required.has("depth"), false, "depth is optional in the schema")
	eq(schema["properties"]["zones"]["items"]["properties"].has("depth"), true, "schema allows depth")
	var props: Dictionary = schema["properties"]["zones"]["items"]["properties"]
	eq(props["level_min"].has("maximum"), false, "schema does not freeze level_min")
	eq(props["level_max"].has("maximum"), false, "schema does not freeze level_max")


func _test_no_class_name() -> void:
	var src := FileAccess.get_file_as_string("res://backend/world_levels.gd")
	eq(src.find("class_name") < 0, true, "loader has no class_name")
	eq(src.find(str(5 * 10)) < 0, true, "loader does not hardcode the phase-1 cap")


func _test_plan(levels) -> void:
	eq(levels.zones.size(), 15, "fifteen level zones")
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
	eq(_ids(levels.zone_for_chunk("crosshaven_crossroads")), "crossroads", "the Crossroads is its own zone")
	var bands := {
		"crosshaven_crossroads": ["crossroads", 1, 1],
		"crosshaven_road_west": ["stoneford", 1, 10],
		"crosshaven_stoneford": ["stoneford", 1, 10],
		"crosshaven_road_north": ["northgate", 10, 20],
		"crosshaven_northgate": ["northgate", 10, 20],
		"crosshaven_road_east": ["eastmarch", 20, 30],
		"crosshaven_eastmarch": ["eastmarch", 20, 30],
		"crosshaven_road_south": ["southbridge", 30, 40],
		"crosshaven_southbridge": ["southbridge", 30, 40],
		"crosshaven_road_southwest": ["westwatch", 40, 50],
		"crosshaven_westwatch": ["westwatch", 40, 50],
	}
	for chunk in bands.keys():
		var want: Array = bands[chunk]
		var zone: Dictionary = levels.zone_for_chunk(str(chunk))
		eq(str(zone.get("id", "")), str(want[0]), "%s zone" % str(chunk))
		var span: Dictionary = levels.band(str(chunk))
		eq(int(span["level_min"]), int(want[1]), "%s band min" % str(chunk))
		eq(int(span["level_max"]), int(want[2]), "%s band max" % str(chunk))
	eq(levels.zone_for_chunk("not_a_chunk").is_empty(), true, "unknown chunk is an empty result")
	eq(levels.band("not_a_zone").is_empty(), true, "unknown band is an empty result")
	eq(levels.zone_for_chunk("").is_empty(), true, "empty chunk id does not crash")
	_test_sixty_six(levels)


## Soft Lock counts from spec 3.1. Middle names are Proposed: the spec names
## the entry / door / hub roles and the shape, not each middle id.
const COUNTS := {
	"crossroads": 1,
	"stoneford": 2,
	"northgate": 2,
	"eastmarch": 2,
	"southbridge": 2,
	"westwatch": 2,
	"rowanvale": 6,
	"windmere": 6,
	"brinewake": 6,
	"slagcrown": 6,
	"eastmarch_fen_edge": 3,
	"gloomfen_mire": 8,
	"stormspire": 5,
	"ashen_shardfields": 7,
	"blightwood_hollow": 8,
}
const HUB_ZONES: Array[String] = ["rowanvale", "windmere", "brinewake", "slagcrown"]


func _test_sixty_six(levels) -> void:
	var owned := {}
	for zone in levels.zones:
		var zone_id := str(zone["id"])
		var chunks: Array = zone["chunks"]
		eq(chunks.size(), int(COUNTS[zone_id]), "%s chunk count" % zone_id)
		var depth: Dictionary = zone["depth"]
		eq(depth.size(), chunks.size(), "%s depth covers its chunks" % zone_id)
		var entries := 0
		var doors := 0
		var hubs := 0
		var door_depth := -1
		var max_depth := -1
		for chunk in chunks:
			var chunk_id := str(chunk)
			eq(owned.has(chunk_id), false, "%s sits in one zone" % chunk_id)
			owned[chunk_id] = zone_id
			eq(str(levels.zone_for_chunk(chunk_id).get("id", "")), zone_id, "%s resolves" % chunk_id)
			var step := int(depth[chunk_id])
			eq(step >= 0 and step <= 7, true, "%s depth is 0-7" % chunk_id)
			if step > max_depth:
				max_depth = step
			if chunk_id.ends_with("_entry") or chunk_id == "crosshaven_crossroads":
				entries += 1
				eq(step, 0, "%s entry depth is 0" % chunk_id)
			if chunk_id.ends_with("_door"):
				doors += 1
				door_depth = step
			if chunk_id.ends_with("_hub"):
				hubs += 1
		if not HOME_IDS.has(zone_id):
			eq(entries, 1, "%s has one entry chunk" % zone_id)
			eq(doors, 1, "%s has one door chunk" % zone_id)
			eq(door_depth, max_depth, "%s door chunk is the deepest" % zone_id)
			var want_hub := 1 if HUB_ZONES.has(zone_id) else 0
			eq(hubs, want_hub, "%s hub count" % zone_id)
	eq(owned.size(), 66, "66 chunk ids in all")
	eq(levels.zone_for_chunk("rowanvale_entry").get("id", ""), "rowanvale", "a chunk with no file yet still resolves")
	var built := {}
	for chunk in BUILT_CHUNKS:
		built[chunk] = true
	var unbuilt := 0
	for chunk_id in owned.keys():
		if built.has(chunk_id):
			continue
		unbuilt += 1
		var home := str(owned[chunk_id])
		var prefix := home + "_"
		eq(str(chunk_id).begins_with(prefix), true, "%s uses its region prefix" % chunk_id)
		eq(str(chunk_id).substr(prefix.length()) != "", true, "%s has a WP5a suffix" % chunk_id)
	eq(unbuilt, 55, "55 chunks are declared before they are built")


func _test_rules(levels) -> void:
	var cap := Levels.curve_max_level()
	eq(cap >= 2, true, "the curve file supplies max_level")
	for zone in levels.zones:
		var lo := int(zone["level_min"])
		var hi := int(zone["level_max"])
		eq(lo >= 1 and lo <= hi and hi <= cap, true, "%s band is inside 1..max_level" % zone["id"])
	_test_explicit_bands(levels)
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
		eq(HOME_IDS.has(zone_id), true, "%s resolves to a section 00 zone" % chunk)


## c037429 Q8 option 1: Fen Edge branches off the east road, before Eastmarch town.
## The gate itself is WP4. This package keeps the chunks in the right zones.
func _test_fen_edge_placement(levels) -> void:
	eq(str(levels.zone_for_chunk("crosshaven_road_east").get("id", "")), "eastmarch", "the east road takes the Eastmarch band")
	eq(str(levels.zone_for_chunk("crosshaven_eastmarch").get("id", "")), "eastmarch", "Eastmarch town stays out of Fen Edge")
	var fen: Dictionary = levels.by_id["eastmarch_fen_edge"]
	eq(int(fen["level_min"]), 25, "Fen Edge starts at 25")
	eq(int(fen["level_max"]), 30, "Fen Edge ends at 30")
	eq(str(fen["dungeon"]), "sunken_mill", "Fen Edge dungeon is Sunken Mill")
	eq(int(fen["depth"]["eastmarch_fen_edge_entry"]), 0, "Fen Edge entry depth is 0")
	eq(str(levels.zone_for_chunk("eastmarch_fen_edge_entry").get("id", "")), "eastmarch_fen_edge", "Fen Edge entry is its own zone")


func _test_explicit_bands(levels) -> void:
	eq(int(levels.by_id["stormspire"]["level_min"]), 35, "Stormspire starts at 35")
	eq(int(levels.by_id["stormspire"]["level_max"]), 40, "Stormspire ends at 40")
	eq(int(levels.by_id["gloomfen_mire"]["level_min"]) >= 30, true, "Gloomfen starts at 30 or higher")
	eq(int(levels.by_id["blightwood_hollow"]["level_min"]) >= 45, true, "Blightwood starts at 45 or higher")


func _test_rejects() -> void:
	var extra := _doc()
	extra["note"] = "no"
	_rejects(extra, "unknown key note")
	var high := _doc()
	_zone(high, "rowanvale")["level_max"] = Levels.curve_max_level() + 1
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
	_zone(twice, "stoneford")["chunks"].append("crosshaven_crossroads")
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
	var ahead := _doc()
	_zone(ahead, "rowanvale")["chunks"].append("rowanvale_meadow")
	_zone(ahead, "rowanvale")["depth"]["rowanvale_meadow"] = 3
	var accepted: Dictionary = Levels.parse(ahead)
	eq(accepted["ok"], true, "a declared chunk with no region file yet is allowed (%s)" % str(accepted["errors"]))
	var bare := _doc()
	_zone(bare, "rowanvale")["chunks"].append("meadow")
	_zone(bare, "rowanvale")["depth"]["meadow"] = 3
	_rejects(bare, "unbuilt chunk meadow must use a WP5a name")
	var shallow := _doc()
	_zone(shallow, "rowanvale")["depth"]["rowanvale_entry"] = 1
	_rejects(shallow, "rowanvale_entry entry depth must be 0")
	var buried := _doc()
	_zone(buried, "rowanvale")["depth"]["rowanvale_door"] = 1
	_rejects(buried, "rowanvale door chunk is not the deepest")
	var deep := _doc()
	_zone(deep, "gloomfen_mire")["depth"]["gloomfen_mire_door"] = 8
	_rejects(deep, "depth gloomfen_mire_door is outside 0-7")
	var optional := _doc()
	_zone(optional, "stormspire").erase("depth")
	var still: Dictionary = Levels.parse(optional)
	eq(still["ok"], true, "depth may be omitted (%s)" % str(still["errors"]))
	var gap := _doc()
	var heart_chunks: Array = _zone(gap, "crossroads")["chunks"]
	heart_chunks.erase("crosshaven_crossroads")
	_rejects(gap, "chunk crosshaven_crossroads is not in a level zone")


func _test_no_phone_dungeon_names() -> void:
	var hits := PackedStringArray()
	for root in PHONE_SCAN_ROOTS:
		_scan_phone_tree(root, hits)
	eq(hits.is_empty(), true, "no phone dungeon names in PC data, code, or tests (%s)" % ", ".join(hits))


func _scan_phone_tree(path: String, hits: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_navigational = false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var child := path.path_join(name)
		if dir.current_is_dir():
			_scan_phone_tree(child, hits)
		else:
			_scan_phone_file(child, hits)
		name = dir.get_next()
	dir.list_dir_end()


func _scan_phone_file(path: String, hits: PackedStringArray) -> void:
	if not PHONE_SCAN_EXT.has(path.get_extension().to_lower()):
		return
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i]
		if _is_phone_denylist_line(line):
			continue
		var lower := line.to_lower()
		for phone in PHONE_DUNGEON_NAMES:
			if lower.find(phone) >= 0:
				hits.append("%s:%d" % [path, i + 1])
				break


func _is_phone_denylist_line(line: String) -> bool:
	var trimmed := line.strip_edges()
	for phone in PHONE_DUNGEON_NAMES:
		if trimmed == "\"%s\"," % phone or trimmed == "\"%s\"" % phone:
			return true
	return false


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
