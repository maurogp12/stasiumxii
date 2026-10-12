extends SceneTree

## Blightwood Hollow is built and visible on this branch, with the regions
## flag still off. Run: godot --headless --path . -s res://tests/run_blightwood_world_tests.gd

const Atlas = preload("res://backend/world_atlas.gd")
const Flags = preload("res://backend/world_flags.gd")
const Map = preload("res://backend/world_map.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_flag()
	_test_chunks()
	_test_joins()
	_test_art()
	print("blightwood world tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_flag() -> void:
	eq(Flags.regions_enabled(), false, "regions_enabled stays false")
	var index: Dictionary = _json("res://data/world/world_index.json")
	var status := ""
	for row in index["regions"]:
		if str(row["region"]) == "blightwood_hollow":
			status = str(row["status"])
	eq(status, "placeholder", "the world index still marks the hollow placeholder")


func _test_chunks() -> void:
	var opened: Dictionary = Map.load_index("res://data/world/blightwood_hollow/index.json")
	eq(bool(opened.get("ok", false)), true, "the hollow index loads")
	if not bool(opened.get("ok", false)):
		return
	var map: WorldMap = opened["map"]
	eq(map.zones.size(), 8, "eight chunks are built")
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zone(str(zone_id))
		eq(zone != null, true, "%s loads" % zone_id)
		var marks := 0
		for prop in zone.props:
			if str(prop.get("id", "")).ends_with("_landmark"):
				marks += 1
		eq(marks, 1, "%s has one landmark" % zone_id)
	var door: WorldZone = map.zone("blightwood_hollow_door")
	var heart := ""
	for prop in door.props:
		if str(prop.get("id", "")).ends_with("_landmark"):
			heart = str(prop.get("type", ""))
	eq(heart, "tavern_3x2", "the Heart stays on the tavern footprint")


func _test_joins() -> void:
	var opened: Dictionary = Map.load_index("res://data/world/blightwood_hollow/index.json")
	var map: WorldMap = opened["map"]
	var entry: WorldZone = map.zone("blightwood_hollow_entry")
	eq(entry.terrain_at(Vector2i(0, 16)), "dirt_road", "the Rowanvale road reaches the west gate")
	eq(entry.terrain_at(Vector2i(16, 0)), "dirt_road", "the Windmere road reaches the north gate")
	eq(entry.terrain_at(Vector2i(16, 16)), "dirt_road", "the west road meets the north road")
	var towers := 0
	var walls := 0
	for prop in entry.props:
		var kind := str(prop.get("type", ""))
		if kind == "wall_tower":
			towers += 1
		elif kind.begins_with("stone_wall_high"):
			walls += 1
	eq(towers >= 2, true, "broken towers flank the joins (%d)" % towers)
	eq(walls > 10, true, "a ruined wall lines the entry borders")


func _test_art() -> void:
	var needed := [
		"res://art/world/blightwood_hollow/tiles/blight_soil_a.png",
		"res://art/world/blightwood_hollow/tiles/_2x/blight_soil_a.png",
		"res://art/world/blightwood_hollow/tiles/blend_meadow_nw_s1.png",
		"res://art/world/blightwood_hollow/tiles/road_gap_wall.png",
		"res://art/world/blightwood_hollow/tiles/watch_flagstone_a.png",
		"res://art/world/blightwood_hollow/props/heart_of_the_blight.png",
		"res://art/world/blightwood_hollow/props/_2x/tw_tree_giant.png",
		"res://art/world/blightwood_hollow/animated/ground_fog_drift_12f.png",
		"res://art/world/blightwood_hollow/animated/spores_drift_12f.png",
		"res://art/world/blightwood_hollow/animated/heart_sap_pulse_8f.png",
		"res://art/world/blightwood_hollow/MANIFEST.md",
		"res://art/world/blightwood_hollow/atlas_meta.json",
	]
	for path in needed:
		eq(FileAccess.file_exists(path), true, path)
	var meta: Dictionary = _json("res://art/world/blightwood_hollow/atlas_meta.json")
	var grammar: Array = meta["grammar"]
	eq(grammar.has("grass") and grammar.has("stone") and grammar.has("water") and grammar.has("ash") and grammar.has("dock"), true, "grammar is grass/stone/water/ash/dock")
	var notes := JSON.stringify(meta["open_points"])
	eq(notes.contains("watch_flagstone") and notes.contains("Proposed"), true, "watch_flagstone stays Proposed")
	eq(notes.contains("heart_of_the_blight_footprint") and notes.contains("Proposed"), true, "the Heart footprint stays Proposed")
	var loaded: Dictionary = Atlas.load_default()
	eq(bool(loaded.get("ok", false)), true, "atlas still loads (%s)" % str(loaded.get("errors", [])))


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func eq(got: Variant, want: Variant, label: String) -> void:
	if got == want:
		_passed += 1
		return
	_failed += 1
	print("FAIL %s (got %s, want %s)" % [label, got, want])
