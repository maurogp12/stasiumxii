extends SceneTree

## Crosshaven walk with world/regions_enabled off.
## Run: godot --headless --path . -s res://tests/run_crosshaven_reach_tests.gd

const Maps = preload("res://backend/world_map.gd")
const Walk = preload("res://backend/world_walk.gd")
const Regions = preload("res://backend/world_regions.gd")
const Flags = preload("res://backend/world_flags.gd")
const Atlas = preload("res://backend/world_atlas.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const FLAGS_PATH := "res://data/world/world_flags.json"
const FLAGS_SCHEMA := "res://data/world/schema/world_flags.schema.json"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Regions.set_enabled(false)
	eq(Regions.enabled(), false, "regions start closed")
	var loaded: Dictionary = Maps.load_default()
	eq(bool(loaded.get("ok", false)), true, "the Crosshaven map loads")
	if not bool(loaded.get("ok", false)):
		_finish()
		return
	var map = loaded["map"]
	var blocked := _npc_blocks()
	var start_zone := "crosshaven_crossroads"
	var start := Vector2i(22, 18)
	var goals := {
		"crosshaven_crossroads": _free_near(map, start_zone, start, blocked),
		"crosshaven_road_north": Vector2i(12, 16),
		"crosshaven_road_west": Vector2i(18, 12),
		"crosshaven_road_east": Vector2i(18, 12),
		"crosshaven_road_southwest": Vector2i(22, 28),
		"crosshaven_road_south": Vector2i(12, 22),
		"crosshaven_northgate": Vector2i(20, 12),
		"crosshaven_stoneford": Vector2i(16, 16),
		"crosshaven_eastmarch": Vector2i(16, 16),
		"crosshaven_westwatch": Vector2i(16, 10),
		"crosshaven_southbridge": Vector2i(20, 10),
	}
	var zone_ids: Array = map.zones.keys()
	eq(zone_ids.size(), 33, "Crosshaven has its 33 chunks")
	for zone_id in zone_ids:
		var goal: Vector2i = map.zone(str(zone_id)).spawn
		if goals.has(str(zone_id)):
			goal = goals[str(zone_id)]
		var there: Dictionary = Walk.find_path(map, start_zone, start, str(zone_id), goal, null, blocked)
		_assert_walk(map, there, "Crossroads to %s" % str(zone_id))
		var back: Dictionary = Walk.find_path(map, str(zone_id), goal, start_zone, start, null, blocked)
		_assert_walk(map, back, "%s back to the Crossroads" % str(zone_id))
	var ring: Array[String] = [
		"crosshaven_northgate",
		"crosshaven_stoneford",
		"crosshaven_westwatch",
		"crosshaven_southbridge",
		"crosshaven_eastmarch",
		"crosshaven_northgate",
	]
	for i in range(ring.size() - 1):
		var frm := ring[i]
		var to := ring[i + 1]
		var hopped: Dictionary = Walk.find_path(map, frm, goals[frm], to, goals[to], null, blocked)
		_assert_walk(map, hopped, "%s to %s" % [frm, to])
	var reached: Dictionary = Walk.reachable_keys(map, start_zone, start)
	var seen := {}
	for key in reached.keys():
		seen[str(key).split("#")[0]] = true
	eq(seen.size(), 33, "every reached chunk is one of the 33")
	for zone_id in seen.keys():
		eq(str(zone_id).begins_with("crosshaven_"), true, "%s is inside Crosshaven" % str(zone_id))
		eq(Regions.is_outer(str(zone_id)), false, "%s is not an outer region" % str(zone_id))
	var closed := Walk.classify_step(map, "crosshaven_stoneford", Vector2i(3, 0), "rowanvale_entry", Vector2i(0, 16), -1)
	eq(closed, "regions_closed", "a step into Rowanvale is closed")
	_test_flag()
	_test_every_pair(map, blocked)
	_test_gate_hidden()
	_finish()


func _assert_walk(map, result: Dictionary, label: String) -> void:
	eq(bool(result.get("ok", false)), true, label)
	if not bool(result.get("ok", false)):
		print("  reason: ", str(result.get("reason", "")))
		return
	var path: Array = result["path"]
	eq(path.size() >= 2, true, "%s has steps" % label)
	for i in range(1, path.size()):
		var prev: Dictionary = path[i - 1]
		var nxt: Dictionary = path[i]
		var from_zone := str(prev["zone_id"])
		var to_zone := str(nxt["zone_id"])
		var from_cell := Vector2i(int(prev["x"]), int(prev["y"]))
		var to_cell := Vector2i(int(nxt["x"]), int(nxt["y"]))
		eq(to_zone.begins_with("crosshaven_"), true, "%s stays in Crosshaven" % label)
		var reason := Walk.classify_step(map, from_zone, from_cell, to_zone, to_cell, -1)
		eq(reason, "", "%s step %d is a walk (%s)" % [label, i, reason])
		if from_zone == to_zone:
			eq(absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y), 1, "%s step %d is ortho" % [label, i])
		else:
			var link: Dictionary = map.zone(from_zone).exit_link(from_cell)
			eq(str(link.get("target_zone", "")), to_zone, "%s step %d uses the exit link" % [label, i])


func _free_near(map, zone_id: String, origin: Vector2i, blocked: Dictionary) -> Vector2i:
	var zone = map.zone(zone_id)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in dirs:
		var cell: Vector2i = origin + dir
		if not zone.passable_at(cell) or zone.blocked_at(cell):
			continue
		if blocked.has(Walk.cell_key(zone_id, cell)):
			continue
		return cell
	return origin


func _npc_blocks() -> Dictionary:
	var blocked := {}
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/npcs.json"))
	for row_value in doc["npcs"]:
		var row: Dictionary = row_value
		var zone_id := str(row["zone_id"])
		if not zone_id.begins_with("crosshaven_"):
			continue
		var at: Dictionary = row["cell"]
		blocked[Walk.cell_key(zone_id, Vector2i(int(at["x"]), int(at["y"])))] = true
	return blocked


func _test_flag() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLAGS_SCHEMA))
	eq(schema["additionalProperties"], false, "world flags schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.world_flags", "world flags format")
	eq(schema["properties"]["regions_enabled"]["type"], "boolean", "regions_enabled is a boolean")
	var loaded: Dictionary = Flags.load_default()
	eq(bool(loaded.get("ok", false)), true, "world flags load (%s)" % str(loaded.get("errors", [])))
	eq(bool(loaded.get("regions_enabled", true)), false, "regions_enabled defaults to false")
	eq(Flags.regions_enabled(), false, "the helper reads the shipped flag")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLAGS_PATH))
	var extra := doc.duplicate(true)
	extra["bonus"] = 1
	var rejected: Dictionary = Flags.load_document(extra)
	eq(bool(rejected.get("ok", true)), false, "an unknown world-flags key is rejected")
	eq(bool(rejected.get("regions_enabled", true)), false, "a bad flags file stays closed")


func _test_every_pair(map, blocked: Dictionary) -> void:
	var opened: Dictionary = Atlas.load_default()
	eq(bool(opened.get("ok", false)), true, "atlas loads for the pair walk")
	if not bool(opened.get("ok", false)):
		return
	var atlas = opened["atlas"]
	var stands := {}
	for zone_id in map.zones.keys():
		stands[str(zone_id)] = _stand(map.zone(str(zone_id)), blocked)
	for from_id in map.zones.keys():
		for to_id in map.zones.keys():
			if str(from_id) == str(to_id):
				continue
			var path: Dictionary = Walk.find_path(map, str(from_id), stands[str(from_id)], str(to_id), stands[str(to_id)], null, blocked)
			eq(bool(path.get("ok", false)), true, "%s to %s (%s)" % [str(from_id), str(to_id), str(path.get("reason", ""))])
			if not bool(path.get("ok", false)):
				continue
			var bad := _enter_zone_step(map, atlas, path["path"])
			eq(bad, "", "%s to %s has no enter_zone (%s)" % [str(from_id), str(to_id), bad])


func _stand(zone, blocked: Dictionary) -> Vector2i:
	var spawn: Vector2i = zone.spawn
	if zone.passable_at(spawn) and not blocked.has(Walk.cell_key(zone.zone_id, spawn)):
		return spawn
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if not zone.passable_at(cell):
				continue
			if blocked.has(Walk.cell_key(zone.zone_id, cell)):
				continue
			return cell
	return spawn


func _enter_zone_step(map, atlas, path: Array) -> String:
	if path.size() < 2:
		return ""
	for index in range(1, path.size()):
		var prev: Dictionary = path[index - 1]
		var nxt: Dictionary = path[index]
		var from_id := str(prev["zone_id"])
		var to_id := str(nxt["zone_id"])
		var from_cell := Vector2i(int(prev["x"]), int(prev["y"]))
		var to_cell := Vector2i(int(nxt["x"]), int(nxt["y"]))
		if not from_id.begins_with("crosshaven_") or not to_id.begins_with("crosshaven_"):
			return "enter_zone %s -> %s" % [from_id, to_id]
		var reason := Walk.classify_step(map, from_id, from_cell, to_id, to_cell, -1)
		if reason != "":
			return "%s (%s,%s) -> %s (%s,%s) %s" % [from_id, from_cell.x, from_cell.y, to_id, to_cell.x, to_cell.y, reason]
		var gate: Dictionary = atlas.gate_at(from_id, from_cell)
		if not gate.is_empty():
			var dest: Dictionary = gate["to"]
			if str(dest["zone_id"]) == to_id and int(dest["x"]) == to_cell.x and int(dest["y"]) == to_cell.y:
				return "enter_zone %s" % str(gate["id"])
		if from_id == to_id:
			var delta := to_cell - from_cell
			if absi(delta.x) + absi(delta.y) != 1:
				return "gap %s %s -> %s" % [from_id, from_cell, to_cell]
	return ""


func _test_gate_hidden() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	eq(Regions.enabled(), false, "the world ships with regions off")
	eq(w._open_gate({"to": {"zone_id": "rowanvale_entry"}}), false, "Rowanvale is closed")
	eq(w._open_gate({"to": {"zone_id": "crosshaven_road_north"}}), true, "the north road stays open")
	Regions.set_enabled(true)
	eq(w._open_gate({"to": {"zone_id": "rowanvale_entry"}}), true, "the stand-in is reachable when the flag is on")
	Regions.set_enabled(false)
	var outer: Array = []
	w.zone_entered.connect(func(zone_id: String, _cell: Vector2i) -> void:
		if not zone_id.begins_with("crosshaven_"):
			outer.append(zone_id)
	)
	var gates := 0
	for gate in w.atlas.gates:
		var frm: Dictionary = gate["from"]
		var from_id := str(frm["zone_id"])
		if not from_id.begins_with("crosshaven_"):
			continue
		var dest_id := str((gate["to"] as Dictionary)["zone_id"])
		if dest_id.begins_with("crosshaven_"):
			continue
		gates += 1
		var cell := Vector2i(int(frm["x"]), int(frm["y"]))
		var zone = w.map.zone(from_id)
		w._load_zone(from_id, zone.spawn)
		var arrow: Vector2i = w.ground.call("marker_dir", cell)
		eq(arrow, Vector2i.ZERO, "%s arrow stays hidden" % str(gate["id"]))
		var walked: Dictionary = w.walk_to(cell)
		eq(bool(walked.get("ok", false)), true, "%s cell is still walkable" % str(gate["id"]))
		_drive(w)
		eq(w.zone.zone_id, from_id, "%s does not leave Crosshaven" % str(gate["id"]))
		eq(w.walker.anchor_cell(), cell, "%s stops on the gate cell" % str(gate["id"]))
	eq(gates, 6, "Crosshaven has six gates into outer regions")
	eq(outer.is_empty(), true, "no enter_zone reached an outer region")
	var cross = w.map.zone("crosshaven_crossroads")
	w._load_zone(cross.zone_id, cross.spawn)
	var north := _exit_cell(cross, "crosshaven_road_north")
	eq(north.x >= 0, true, "the north road exit is on the Crossroads")
	var crossed: Dictionary = w.walk_to(north)
	eq(bool(crossed.get("ok", false)), true, "the north exit is still a walk")
	_drive(w)
	eq(w.zone.zone_id, "crosshaven_road_north", "a Crosshaven exit still reaches the next chunk")
	eq(outer.is_empty(), true, "that chunk change stays inside Crosshaven")
	w.queue_free()


func _exit_cell(zone, target: String) -> Vector2i:
	for exit_rec in zone.exits:
		if str(exit_rec["target_zone"]) != target:
			continue
		var link: Dictionary = exit_rec["links"][0]
		var frm: Dictionary = link["from"]
		return Vector2i(int(frm["x"]), int(frm["y"]))
	return Vector2i(-1, -1)


func _drive(w: Node2D) -> void:
	var n := 0
	while w.walker.is_moving() and n < 8000:
		w.walker.advance(0.05)
		n += 1
	eq(n < 8000, true, "the walker finished")


func _finish() -> void:
	print("crosshaven reach tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
