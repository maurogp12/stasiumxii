extends SceneTree

## WP4 world index, gates, and the atlas.
## Run: godot --headless --path . -s res://tests/run_world_atlas_tests.gd

const Atlas = preload("res://backend/world_atlas.gd")
const Levels = preload("res://backend/world_levels.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Regions := preload("res://backend/world_regions.gd")

const INDEX_PATH := "res://data/world/world_index.json"
const GATES_PATH := "res://data/world/gates.json"
const INDEX_SCHEMA := "res://data/world/schema/world_index.schema.json"
const GATES_SCHEMA := "res://data/world/schema/gates.schema.json"
const CHUNK_DIR := "res://data/world/crosshaven/zones"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_schemas()
	_test_atlas()
	_test_documents()
	_test_chunks_untouched()
	_test_gate_click()
	print("world atlas tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_schemas() -> void:
	var index_schema: Dictionary = _json(INDEX_SCHEMA)
	var gates_schema: Dictionary = _json(GATES_SCHEMA)
	eq(index_schema["additionalProperties"], false, "world index schema rejects unknown keys")
	eq(gates_schema["additionalProperties"], false, "gates schema rejects unknown keys")
	eq(index_schema["properties"]["format"]["const"], "stasium.world_index", "world index format")
	eq(gates_schema["properties"]["format"]["const"], "stasium.world_gates", "gates format")


func _test_atlas() -> void:
	var loaded: Dictionary = Atlas.load_default()
	eq(loaded["ok"], true, "atlas loads (%s)" % str(loaded["errors"]))
	if not bool(loaded["ok"]):
		return
	var atlas = loaded["atlas"]
	eq(str(atlas.start_region), "crosshaven", "the world starts in Crosshaven")
	eq(atlas.regions.size(), 10, "Crosshaven plus nine new regions")
	eq(atlas.maps["crosshaven"] != null, true, "Crosshaven loads through WorldMap.load_index")
	eq(atlas.maps["rowanvale"] != null, true, "Rowanvale's critical path loads")
	eq(atlas.maps["rowanvale"].zone("rowanvale_entry") != null, true, "Rowanvale entry is a real chunk")
	eq(atlas.gates.size(), 22, "eleven two-way links, both directions")
	var levels_doc: Dictionary = Levels.load_default()
	var levels = levels_doc["levels"]
	eq(int(levels.by_chunk.size()), 88, "all 88 chunks are in the level zones")
	var fen: Dictionary = atlas.gate_at("crosshaven_road_east", Vector2i(18, 0))
	eq(fen.is_empty(), false, "Fen Edge's gate stands on the east road")
	eq(str(fen["to"]["zone_id"]), "eastmarch_fen_edge_entry", "Fen Edge's gate lands on the entry chunk")
	var seen_from := {}
	for gate in atlas.gates:
		var frm: Dictionary = gate["from"]
		var dest: Dictionary = gate["to"]
		var from_region := str(atlas.region_of_chunk(str(frm["zone_id"])))
		var to_region := str(atlas.region_of_chunk(str(dest["zone_id"])))
		eq(from_region != to_region, true, "%s joins two regions" % str(gate["id"]))
		if to_region != "crosshaven":
			eq(str(dest["zone_id"]), str(atlas.entry_of(to_region)), "%s lands on the entry" % str(gate["id"]))
		var partner: Dictionary = atlas._partner(gate)
		eq(partner.is_empty(), false, "%s has a matching reverse" % str(gate["id"]))
		seen_from[str(gate["id"])] = true
		if from_region == "crosshaven" or to_region == "crosshaven":
			eq(str(partner["to"]["zone_id"]), str(frm["zone_id"]), "%s returns to the chunk it left" % str(gate["id"]))
	eq(seen_from.size(), 22, "every gate id is unique")
	for region_row in atlas.regions:
		var region := str(region_row["region"])
		var depth_zero := 0
		for chunk_id in levels.by_chunk.keys():
			if str(atlas.region_of_chunk(str(chunk_id))) != region:
				continue
			var zone: Dictionary = levels.zone_for_chunk(str(chunk_id))
			var depth: Dictionary = zone.get("depth", {})
			if int(depth.get(chunk_id, -1)) == 0:
				depth_zero += 1
				eq(str(chunk_id), str(atlas.entry_of(region)), "%s entry chunk" % region)
		eq(depth_zero, 1, "%s has one entry chunk" % region)


func _test_documents() -> void:
	var index_doc: Dictionary = _json(INDEX_PATH)
	var gates_doc: Dictionary = _json(GATES_PATH)
	var extra: Dictionary = index_doc.duplicate(true)
	extra["bonus"] = 1
	var rejected: Dictionary = Atlas.load_documents(extra, gates_doc)
	eq(rejected["ok"], false, "an unknown world-index key is rejected")
	var same: Dictionary = gates_doc.duplicate(true)
	var gates: Array = same["gates"]
	var bad: Dictionary = (gates[0] as Dictionary).duplicate(true)
	bad["id"] = "stoneford_loop"
	bad["to"] = (bad["from"] as Dictionary).duplicate(true)
	gates.append(bad)
	var inside: Dictionary = Atlas.load_documents(index_doc, same)
	eq(inside["ok"], false, "a gate inside one region is rejected")


func _test_chunks_untouched() -> void:
	var names := [
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
	eq(names.size(), 11, "Crosshaven still has its 11 chunks")
	for zone_id in names:
		var path := "%s/%s.json" % [CHUNK_DIR, zone_id]
		eq(FileAccess.file_exists(path), true, "%s chunk file is still there" % zone_id)
		var text := FileAccess.get_file_as_string(path)
		eq(text.find("rowanvale_entry") < 0, true, "%s chunk file has no gate landing" % zone_id)
		eq(text.find("stasium.world_gates") < 0, true, "%s chunk file is not a gate file" % zone_id)


func _test_gate_click() -> void:
	Regions.set_enabled(true)
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	eq(w.map != null, true, "the world loads through the atlas")
	eq(w.zone.zone_id, "crosshaven_crossroads", "the world still starts at the Crossroads")
	var src := FileAccess.get_file_as_string("res://scenes/world/crosshaven/crosshaven_world.gd")
	eq(src.find("world_atlas.gd") >= 0, true, "the world script loads the atlas")
	eq(src.find("walk_to") >= 0, true, "a gate click still uses walk_to")
	eq(src.find("enter_zone") >= 0, true, "arriving on a gate calls enter_zone")
	w.enter_zone("crosshaven_road_east", Vector2i(18, 1), false)
	eq(w.zone.zone_id, "crosshaven_road_east", "the east road still loads")
	var arrow: Vector2i = w.ground.call("marker_dir", Vector2i(18, 0))
	eq(arrow, Vector2i(0, -1), "the Fen Edge gate uses the exit-arrow direction")
	var reasons: Array = []
	w.walk_rejected.connect(func(reason: String) -> void: reasons.append(reason))
	var walked: Dictionary = w.walk_to(Vector2i(18, 0))
	eq(bool(walked.get("ok", false)), true, "the walker can reach the Fen Edge gate")
	var n := 0
	while w.walker.is_moving() and n < 400:
		w.walker.advance(0.05)
		n += 1
	eq(reasons.has("region_not_built"), false, "Fen Edge is built, so the gate does not reject the walk")
	eq(w.zone.zone_id, "eastmarch_fen_edge_entry", "the Fen Edge gate lands on the entry chunk")
	eq(w.walker.anchor_cell(), Vector2i(0, 16), "the landing cell is the gate cell")
	w.queue_free()
	Regions.set_enabled(false)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
