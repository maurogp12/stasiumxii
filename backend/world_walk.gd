class_name WorldWalk
extends RefCounted

## Authoritative open-world step check and click-to-walk search.
## Adjacency is the board grid's 4-neighbor ortho rule.
## OPEN_WORLD_MAX_CLIMB_STEPS is the code default. -1 means no climb limit.
## The shipped region config is index.json `max_climb_steps` (also -1).
## A negative limit means no limit. Drops are unlimited. This is not combat elevation.

const Regions = preload("res://backend/world_regions.gd")
const OPEN_WORLD_MAX_CLIMB_STEPS := -1
const ORTHO: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


static func validate_path(map: WorldMap, steps: Array, max_climb_steps: Variant = null) -> Dictionary:
	var limit := _limit(map, max_climb_steps)
	if steps.size() < 2:
		return _fail("empty_path")
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY or not (step as Dictionary).has("zone_id"):
			return _fail("bad_step")
		if not (step as Dictionary).has("x") or not (step as Dictionary).has("y"):
			return _fail("bad_step")
	var first: Dictionary = steps[0]
	var zone_id := str(first["zone_id"])
	var cell := Vector2i(int(first["x"]), int(first["y"]))
	if map == null or not map.zones.has(zone_id):
		return _fail("unknown_zone")
	var start_reason := _cell_reason(map.zone(zone_id), cell)
	if start_reason != "":
		return _fail(start_reason)
	for index in range(1, steps.size()):
		var nxt: Dictionary = steps[index]
		var next_zone := str(nxt["zone_id"])
		var next_cell := Vector2i(int(nxt["x"]), int(nxt["y"]))
		var reason := classify_step(map, zone_id, cell, next_zone, next_cell, limit)
		if reason != "":
			return _fail(reason)
		zone_id = next_zone
		cell = next_cell
	return _ok(steps, zone_id, cell)


static func find_path(
	map: WorldMap,
	from_zone: String,
	from_cell: Vector2i,
	to_zone: String,
	to_cell: Vector2i,
	max_climb_steps: Variant = null,
	extra_blocked: Dictionary = {},
) -> Dictionary:
	var limit := _limit(map, max_climb_steps)
	if map == null or not map.zones.has(from_zone) or not map.zones.has(to_zone):
		return _fail("unknown_zone")
	if from_zone == to_zone and from_cell == to_cell:
		return _fail("same_tile")
	var start_reason := _cell_reason(map.zone(from_zone), from_cell)
	if start_reason != "":
		return _fail(start_reason)
	var goal_reason := _cell_reason(map.zone(to_zone), to_cell)
	if goal_reason != "":
		return _fail(goal_reason)
	var start_key := cell_key(from_zone, from_cell)
	var goal_key := cell_key(to_zone, to_cell)
	if extra_blocked.has(goal_key):
		return _fail("blocked")
	var prev := {}
	var queue: Array = [start_key]
	var seen := {start_key: true}
	var head := 0
	while head < queue.size():
		var current: String = queue[head]
		head += 1
		if current == goal_key:
			var path := _rebuild(prev, start_key, goal_key)
			if path.is_empty():
				return _fail("unreachable")
			return _ok(path, to_zone, to_cell)
		var parts := _parse_key(current)
		var zone := map.zone(str(parts["zone_id"]))
		var cell: Vector2i = parts["cell"]
		for step in _candidates(zone, cell):
			var next_zone := str(step["zone_id"])
			var next_cell := Vector2i(int(step["x"]), int(step["y"]))
			if classify_step(map, str(parts["zone_id"]), cell, next_zone, next_cell, limit) != "":
				continue
			var key := cell_key(next_zone, next_cell)
			if extra_blocked.has(key):
				continue
			if seen.has(key):
				continue
			seen[key] = true
			prev[key] = current
			queue.append(key)
	return _fail("unreachable")


## Every passable tile reached from the start under the climb limit, including the start.
static func reachable_keys(map: WorldMap, from_zone: String, from_cell: Vector2i, max_climb_steps: Variant = null) -> Dictionary:
	var limit := _limit(map, max_climb_steps)
	var reached := {}
	if map == null or not map.zones.has(from_zone):
		return reached
	if _cell_reason(map.zone(from_zone), from_cell) != "":
		return reached
	var start_key := cell_key(from_zone, from_cell)
	var queue: Array = [start_key]
	reached[start_key] = true
	var head := 0
	while head < queue.size():
		var current: String = queue[head]
		head += 1
		var parts := _parse_key(current)
		var zone := map.zone(str(parts["zone_id"]))
		var cell: Vector2i = parts["cell"]
		for step in _candidates(zone, cell):
			var next_zone := str(step["zone_id"])
			var next_cell := Vector2i(int(step["x"]), int(step["y"]))
			if classify_step(map, str(parts["zone_id"]), cell, next_zone, next_cell, limit) != "":
				continue
			var key := cell_key(next_zone, next_cell)
			if reached.has(key):
				continue
			reached[key] = true
			queue.append(key)
	return reached


static func classify_step(
	map: WorldMap,
	from_zone: String,
	from_cell: Vector2i,
	to_zone: String,
	to_cell: Vector2i,
	max_climb: int,
) -> String:
	if map == null or not map.zones.has(from_zone):
		return "unknown_zone"
	var zone := map.zone(from_zone)
	if from_zone == to_zone:
		if not zone.in_bounds(to_cell):
			return "out_of_bounds"
		var delta := to_cell - from_cell
		if absi(delta.x) + absi(delta.y) != 1:
			return "not_adjacent"
		return _enter(zone, from_cell, zone, to_cell, max_climb)
	# Outer regions stay closed until world/regions_enabled. A step inside one
	# region (Rowanvale to Rowanvale) still counts. A step into a different
	# region does not, even when that chunk is not on this map.
	if not Regions.enabled() and Regions.is_outer(to_zone) and not Regions.same_region(from_zone, to_zone):
		return "regions_closed"
	if not map.zones.has(to_zone):
		return "unknown_zone"
	var link := zone.exit_link(from_cell)
	if link.is_empty() or str(link["target_zone"]) != to_zone or int(link["x"]) != to_cell.x or int(link["y"]) != to_cell.y:
		return "bad_exit"
	var dest := map.zone(to_zone)
	if not dest.in_bounds(to_cell):
		return "out_of_bounds"
	return _enter(zone, from_cell, dest, to_cell, max_climb)


static func cell_key(zone_id: String, cell: Vector2i) -> String:
	return "%s#%d#%d" % [zone_id, cell.x, cell.y]


static func _candidates(zone: WorldZone, cell: Vector2i) -> Array:
	var out: Array = []
	var link := zone.exit_link(cell)
	for dir in ORTHO:
		var nxt := cell + dir
		if zone.in_bounds(nxt):
			out.append({"zone_id": zone.zone_id, "x": nxt.x, "y": nxt.y})
			continue
		if link.is_empty() or WorldZone.EDGE_DIR[str(link["edge"])] != dir:
			continue
		out.append({
			"zone_id": str(link["target_zone"]),
			"x": int(link["x"]),
			"y": int(link["y"]),
		})
	return out


static func _enter(src: WorldZone, from_cell: Vector2i, dest: WorldZone, to_cell: Vector2i, max_climb: int) -> String:
	if not dest.walkable_at(to_cell):
		return "not_walkable"
	if dest.blocked_at(to_cell):
		return "blocked"
	if not _climb_ok(src.height_at(from_cell), dest.height_at(to_cell), max_climb):
		return "climb_too_steep"
	return ""


static func _cell_reason(zone: WorldZone, cell: Vector2i) -> String:
	if zone == null:
		return "unknown_zone"
	if not zone.in_bounds(cell):
		return "out_of_bounds"
	if not zone.walkable_at(cell):
		return "not_walkable"
	if zone.blocked_at(cell):
		return "blocked"
	return ""


static func _climb_ok(from_height: int, to_height: int, max_climb: int) -> bool:
	if max_climb < 0:
		return true
	return to_height - from_height <= max_climb


static func _limit(map: WorldMap, override: Variant) -> int:
	if override != null:
		return int(override)
	if map == null:
		return OPEN_WORLD_MAX_CLIMB_STEPS
	return int(map.max_climb_steps)


static func _parse_key(key: String) -> Dictionary:
	var parts := key.split("#")
	return {
		"zone_id": parts[0],
		"cell": Vector2i(int(parts[1]), int(parts[2])),
	}


static func _rebuild(prev: Dictionary, start_key: String, goal_key: String) -> Array:
	var keys: Array = []
	var cursor := goal_key
	var guard := 0
	while true:
		keys.append(cursor)
		if cursor == start_key:
			break
		if not prev.has(cursor):
			return []
		cursor = str(prev[cursor])
		guard += 1
		if guard > 20000:
			return []
	keys.reverse()
	var path: Array = []
	for key in keys:
		var parts := _parse_key(str(key))
		var cell: Vector2i = parts["cell"]
		path.append({"zone_id": str(parts["zone_id"]), "x": cell.x, "y": cell.y})
	return path


static func _ok(path: Array, end_zone: String, end_cell: Vector2i) -> Dictionary:
	return {
		"ok": true,
		"reason": "",
		"path": path,
		"length": path.size() - 1,
		"end_zone": end_zone,
		"end": {"x": end_cell.x, "y": end_cell.y},
	}


static func _fail(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"path": [],
		"length": 0,
	}
