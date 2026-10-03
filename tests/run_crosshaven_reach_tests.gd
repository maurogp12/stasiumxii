extends SceneTree

## Crosshaven walk with world/regions_enabled off.
## Run: godot --headless --path . -s res://tests/run_crosshaven_reach_tests.gd

const Maps = preload("res://backend/world_map.gd")
const Walk = preload("res://backend/world_walk.gd")
const Regions = preload("res://backend/world_regions.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

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
	eq(zone_ids.size(), 11, "Crosshaven has its 11 chunks")
	for zone_id in zone_ids:
		eq(goals.has(str(zone_id)), true, "%s has a walk goal" % str(zone_id))
		var goal: Vector2i = goals[str(zone_id)]
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
	eq(seen.size(), 11, "every reached chunk is one of the 11")
	for zone_id in seen.keys():
		eq(str(zone_id).begins_with("crosshaven_"), true, "%s is inside Crosshaven" % str(zone_id))
		eq(Regions.is_outer(str(zone_id)), false, "%s is not an outer region" % str(zone_id))
	var closed := Walk.classify_step(map, "crosshaven_stoneford", Vector2i(3, 0), "rowanvale_entry", Vector2i(0, 16), -1)
	eq(closed, "regions_closed", "a step into Rowanvale is closed")
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


func _test_gate_hidden() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.enter_zone("crosshaven_stoneford", Vector2i(3, 1), false)
	eq(w.zone.zone_id, "crosshaven_stoneford", "Stoneford still loads")
	var arrow: Vector2i = w.ground.call("marker_dir", Vector2i(3, 0))
	eq(arrow, Vector2i.ZERO, "the Rowanvale gate arrow is hidden")
	var reasons: Array = []
	w.walk_rejected.connect(func(reason: String) -> void: reasons.append(reason))
	var walked: Dictionary = w.walk_to(Vector2i(3, 0))
	eq(bool(walked.get("ok", false)), true, "the gate cell is still walkable")
	var n := 0
	while w.walker.is_moving() and n < 400:
		w.walker.advance(0.05)
		n += 1
	eq(w.zone.zone_id, "crosshaven_stoneford", "walking the gate does not leave Stoneford")
	eq(reasons.has("regions_closed") or reasons.is_empty(), true, "the closed gate does not jump")
	w.queue_free()


func _finish() -> void:
	print("crosshaven reach tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
