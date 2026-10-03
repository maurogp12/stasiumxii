extends SceneTree

## Crosshaven open world, with world.regions_enabled off.
## Cell-by-cell walks use chunk exits only. A gate teleport is an enter_zone
## jump and fails this suite. Run:
## godot --headless --path . -s res://tests/run_crosshaven_walk_tests.gd

const Flags = preload("res://backend/world_flags.gd")
const Atlas = preload("res://backend/world_atlas.gd")
const Maps = preload("res://backend/world_map.gd")
const Walk = preload("res://backend/world_walk.gd")
const Levels = preload("res://backend/world_levels.gd")
const Missions = preload("res://backend/pc_missions.gd")
const Progress = preload("res://backend/pc_progress.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

const FLAGS_PATH := "res://data/world/world_flags.json"
const FLAGS_SCHEMA := "res://data/world/schema/world_flags.schema.json"

## Crossroads, five road chunks, five towns. Levels 1–10.
const CHUNKS: Array[String] = [
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

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_flag()
	_test_walk()
	_test_gates_closed()
	_test_task_pools()
	print("crosshaven walk tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_flag() -> void:
	var schema: Dictionary = _json(FLAGS_SCHEMA)
	eq(schema["additionalProperties"], false, "world flags schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.world_flags", "world flags format")
	eq(schema["properties"]["regions_enabled"]["type"], "boolean", "regions_enabled is a boolean")
	var loaded: Dictionary = Flags.load_default()
	eq(bool(loaded.get("ok", false)), true, "world flags load (%s)" % str(loaded.get("errors", [])))
	eq(bool(loaded.get("regions_enabled", true)), false, "world.regions_enabled defaults to false")
	eq(Flags.regions_enabled(), false, "the helper reads the shipped flag")
	var doc: Dictionary = _json(FLAGS_PATH)
	var extra := doc.duplicate(true)
	extra["bonus"] = 1
	var rejected: Dictionary = Flags.load_document(extra)
	eq(bool(rejected.get("ok", true)), false, "an unknown world-flags key is rejected")
	eq(bool(rejected.get("regions_enabled", true)), false, "a bad flags file stays closed")


func _test_walk() -> void:
	var opened: Dictionary = Maps.load_default()
	eq(bool(opened.get("ok", false)), true, "Crosshaven map loads")
	if not bool(opened.get("ok", false)):
		return
	var map: WorldMap = opened["map"]
	var atlas_doc: Dictionary = Atlas.load_default()
	eq(bool(atlas_doc.get("ok", false)), true, "atlas loads for the walk")
	if not bool(atlas_doc.get("ok", false)):
		return
	var atlas = atlas_doc["atlas"]
	var levels_doc: Dictionary = Levels.load_default()
	var levels = levels_doc["levels"]
	var blocked := _npc_blocked()
	var stands := {}
	for chunk_id in CHUNKS:
		eq(map.zones.has(chunk_id), true, "%s is a Crosshaven chunk" % chunk_id)
		var band: Dictionary = levels.band(chunk_id)
		eq(int(band.get("level_min", 0)) >= 1 and int(band.get("level_max", 99)) <= 10, true, "%s is levels 1-10" % chunk_id)
		var zone: WorldZone = map.zone(chunk_id)
		stands[chunk_id] = _stand(zone, blocked)
	var start_zone := map.start_zone
	var start_cell := map.start_cell
	eq(start_zone, "crosshaven_crossroads", "the walk starts at the Crossroads")
	for chunk_id in CHUNKS:
		if chunk_id == start_zone and stands[chunk_id] == start_cell:
			eq(true, true, "the Crossroads stand is the start cell")
			continue
		var there: Dictionary = Walk.find_path(map, start_zone, start_cell, chunk_id, stands[chunk_id], null, blocked)
		eq(bool(there.get("ok", false)), true, "Crossroads to %s (%s)" % [chunk_id, str(there.get("reason", ""))])
		if bool(there.get("ok", false)):
			var bad := _enter_zone_step(map, atlas, there["path"])
			eq(bad, "", "Crossroads to %s has no enter_zone (%s)" % [chunk_id, bad])
		if chunk_id == start_zone:
			continue
		var back: Dictionary = Walk.find_path(map, chunk_id, stands[chunk_id], start_zone, start_cell, null, blocked)
		eq(bool(back.get("ok", false)), true, "%s back to the Crossroads (%s)" % [chunk_id, str(back.get("reason", ""))])
		if bool(back.get("ok", false)):
			var bad_back := _enter_zone_step(map, atlas, back["path"])
			eq(bad_back, "", "%s back to the Crossroads has no enter_zone (%s)" % [chunk_id, bad_back])
	for from_id in CHUNKS:
		for to_id in CHUNKS:
			if from_id == to_id:
				continue
			var path: Dictionary = Walk.find_path(map, from_id, stands[from_id], to_id, stands[to_id], null, blocked)
			eq(bool(path.get("ok", false)), true, "%s to %s (%s)" % [from_id, to_id, str(path.get("reason", ""))])
			if not bool(path.get("ok", false)):
				continue
			var bad_town := _enter_zone_step(map, atlas, path["path"])
			eq(bad_town, "", "%s to %s has no enter_zone (%s)" % [from_id, to_id, bad_town])


func _test_gates_closed() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	eq(w.regions_enabled, false, "the world ships with regions off")
	eq(w._can_leave_to("rowanvale_entry"), false, "Rowanvale is closed")
	eq(w._can_leave_to("crosshaven_road_north"), true, "the north road stays open")
	w.regions_enabled = true
	eq(w._can_leave_to("rowanvale_entry"), true, "the stand-in is still reachable when the flag is on")
	w.regions_enabled = false
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
		var zone: WorldZone = w.map.zone(from_id)
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
	var cross: WorldZone = w.map.zone("crosshaven_crossroads")
	w._load_zone(cross.zone_id, cross.spawn)
	var north := _exit_cell(cross, "crosshaven_road_north")
	eq(north.x >= 0, true, "the north road exit is on the Crossroads")
	var crossed: Dictionary = w.walk_to(north)
	eq(bool(crossed.get("ok", false)), true, "the north exit is still a walk")
	_drive(w)
	eq(w.zone.zone_id, "crosshaven_road_north", "a Crosshaven exit still reaches the next chunk")
	eq(outer.is_empty(), true, "that chunk change stays inside Crosshaven")
	w.queue_free()


func _test_task_pools() -> void:
	var loaded: Dictionary = Missions.load_default()
	eq(bool(loaded.get("ok", false)), true, "missions load with the flag off (%s)" % str(loaded.get("errors", [])))
	if not bool(loaded.get("ok", false)):
		return
	var book = loaded["missions"]
	eq(book._regions_enabled, false, "task pools read world.regions_enabled false")
	var map_doc: Dictionary = Maps.load_default()
	var map: WorldMap = map_doc["map"]
	for npc_id in book._npc_roles.keys():
		if not book._gives_tasks(str(npc_id)):
			continue
		for band in ["crosshaven_heart", "crosshaven_towns"]:
			for row in book._pool_for(band, str(npc_id)):
				var mark: Dictionary = row
				var zone_id := str(mark.get("zone_id", ""))
				eq(CHUNKS.has(zone_id), true, "%s pool stays on a Crosshaven landmark (%s)" % [str(npc_id), zone_id])
				eq(bool(mark.get("pending_chunk", false)), false, "%s pool has no pending landmark" % str(npc_id))
		for level in [1, 9]:
			var hero = Progress.new()
			hero.mission_blob = {}
			hero.level = level
			var preview: Dictionary = book._preview_task(str(npc_id), hero)
			if preview.is_empty():
				continue
			var zone_id := str(preview.get("zone_id", ""))
			eq(CHUNKS.has(zone_id), true, "%s at level %d targets Crosshaven (%s)" % [str(npc_id), level, zone_id])
			var giver: Dictionary = book._npc_cells.get(npc_id, {})
			if map.zones.has(str(giver.get("zone_id", ""))):
				var at: Vector2i = Vector2i(int(giver.get("x", 0)), int(giver.get("y", 0)))
				var walked: Dictionary = Walk.find_path(
					map, str(giver.get("zone_id", "")), at, zone_id, Vector2i(int(preview["x"]), int(preview["y"]))
				)
				eq(bool(walked.get("ok", false)), true, "%s can walk the offered landmark" % str(npc_id))
				eq(int(walked.get("length", 0)) >= 40, true, "%s offer is at least 40 walk cells" % str(npc_id))
	var trader = Progress.new()
	trader.mission_blob = {}
	for level in [10, 11, 15, 25, 40]:
		trader.level = level
		eq(book._preview_task("crossroads_trader", trader).is_empty(), true, "level %d offers no task while regions are off" % level)
	var probe := {
		"level_zone": "crosshaven_heart",
		"zone_id": "rowanvale_entry",
		"landmark": "outer_probe",
		"name": "Outer",
		"x": 20,
		"y": 12,
		"proximity": "landmark",
		"pending_chunk": false,
	}
	book._reach.append(probe)
	book._map.zones["rowanvale_entry"] = book._map.zone("crosshaven_crossroads")
	var giver: Dictionary = book._npc_cells["crossroads_trader"]
	var cache_key := "%s#%d#%d>rowanvale_entry#20#12" % [str(giver["zone_id"]), int(giver["x"]), int(giver["y"])]
	book._walk_cache[cache_key] = 80
	var closed: Array = book._pool_for("crosshaven_heart", "crossroads_trader")
	eq(_has_zone(closed, "rowanvale_entry"), false, "flag off keeps an outer landmark out of the pool")
	book._regions_enabled = true
	var opened: Array = book._pool_for("crosshaven_heart", "crossroads_trader")
	eq(_has_zone(opened, "rowanvale_entry"), true, "the same landmark waits behind the flag")
	book._regions_enabled = false
	book._map.zones.erase("rowanvale_entry")


func _enter_zone_step(map: WorldMap, atlas, path: Array) -> String:
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
		var reason := Walk.classify_step(map, from_id, from_cell, to_id, to_cell, map.max_climb_steps)
		if reason != "":
			return "enter_zone %s (%s,%s) -> %s (%s,%s) %s" % [from_id, from_cell.x, from_cell.y, to_id, to_cell.x, to_cell.y, reason]
		var gate: Dictionary = atlas.gate_at(from_id, from_cell)
		if not gate.is_empty():
			var dest: Dictionary = gate["to"]
			if str(dest["zone_id"]) == to_id and int(dest["x"]) == to_cell.x and int(dest["y"]) == to_cell.y:
				return "enter_zone %s" % str(gate["id"])
		if from_id == to_id:
			var delta := to_cell - from_cell
			if absi(delta.x) + absi(delta.y) != 1:
				return "enter_zone gap %s %s -> %s" % [from_id, from_cell, to_cell]
			continue
		var link: Dictionary = map.zone(from_id).exit_link(from_cell)
		if link.is_empty() or str(link["target_zone"]) != to_id or int(link["x"]) != to_cell.x or int(link["y"]) != to_cell.y:
			return "enter_zone %s -> %s" % [from_id, to_id]
	return ""


func _npc_blocked() -> Dictionary:
	var blocked := {}
	var doc: Dictionary = _json("res://data/world/npcs.json")
	for row in doc["npcs"]:
		var npc: Dictionary = row
		var zone_id := str(npc.get("zone_id", ""))
		if not zone_id.begins_with("crosshaven_"):
			continue
		var at: Dictionary = npc["cell"]
		blocked[Walk.cell_key(zone_id, Vector2i(int(at["x"]), int(at["y"])))] = true
	return blocked


func _stand(zone: WorldZone, blocked: Dictionary) -> Vector2i:
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


func _exit_cell(zone: WorldZone, target: String) -> Vector2i:
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


func _has_zone(rows: Array, zone_id: String) -> bool:
	for row in rows:
		if str((row as Dictionary).get("zone_id", "")) == zone_id:
			return true
	return false


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
