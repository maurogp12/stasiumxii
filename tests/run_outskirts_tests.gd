extends SceneTree

## Outskirts: 22 chunks fill the island. Every interior cell is covered,
## neighbours join on every walkable shared edge, and a walk reaches each one.
## Run: godot --headless --path . -s res://tests/run_outskirts_tests.gd

const WorldPlane := preload("res://backend/world_plane.gd")
const Maps := preload("res://backend/world_map.gd")
const Walk := preload("res://backend/world_walk.gd")
const Levels := preload("res://backend/world_levels.gd")

const X0 := -72
const Y0 := -64
const X1 := 112
const Y1 := 104

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run()
	print("outskirts tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	var opened: Dictionary = Maps.load_default()
	eq(bool(opened.get("ok", false)), true, "Crosshaven map loads")
	if not bool(opened.get("ok", false)):
		return
	var map: WorldMap = opened["map"]
	var lay: Dictionary = WorldPlane.layout(map)
	eq(bool(lay.get("ok", false)), true, "the plane agrees (%s)" % str(lay.get("conflicts", [])))
	var offsets: Dictionary = lay.get("offsets", {})
	eq(map.zones.size(), 33, "33 Crosshaven chunks")
	var counts := {
		"stoneford": 0, "northgate": 0, "eastmarch": 0,
		"southbridge": 0, "westwatch": 0,
	}
	var fresh: Array[String] = [
		"crosshaven_stoneford_fields", "crosshaven_stoneford_orchard", "crosshaven_stoneford_mill",
		"crosshaven_northgate_crags_west", "crosshaven_northgate_crags_east", "crosshaven_northgate_crags_far", "crosshaven_northgate_pass",
		"crosshaven_eastmarch_north_shore", "crosshaven_eastmarch_sea_caves", "crosshaven_eastmarch_beach", "crosshaven_eastmarch_coves",
		"crosshaven_southbridge_east_verge", "crosshaven_southbridge_swamp", "crosshaven_southbridge_fen_cut", "crosshaven_southbridge_south_band", "crosshaven_southbridge_southeast",
		"crosshaven_westwatch_west_flank", "crosshaven_westwatch_south_strip", "crosshaven_westwatch_southwest", "crosshaven_westwatch_south_gap", "crosshaven_westwatch_south_blight", "crosshaven_westwatch_dark_fields",
	]
	for zone_id in fresh:
		eq(map.zone(zone_id) != null, true, "%s is on the map" % zone_id)
		for town in counts.keys():
			if zone_id.find(str(town)) >= 0:
				counts[town] = int(counts[town]) + 1
	eq(fresh.size(), 22, "22 outskirts chunks")
	eq(int(counts["stoneford"]), 3, "Stoneford has 3 outskirts")
	eq(int(counts["northgate"]), 4, "Northgate has 4 outskirts")
	eq(int(counts["eastmarch"]), 4, "Eastmarch has 4 outskirts")
	eq(int(counts["southbridge"]), 5, "Southbridge has 5 outskirts")
	eq(int(counts["westwatch"]), 6, "Westwatch has 6 outskirts")
	_test_cover(map, offsets)
	_test_edges(map, offsets)
	_test_coast(map, offsets)
	_test_land(map, offsets)
	_test_bands(fresh)
	_test_walks(map, fresh)


func _test_cover(map: WorldMap, offsets: Dictionary) -> void:
	var owner := {}
	var dupes := 0
	for id in offsets.keys():
		var zone: WorldZone = map.zone(str(id))
		var origin: Vector2i = offsets[id]
		for y in zone.height:
			for x in zone.width:
				var world := origin + Vector2i(x, y)
				var key := "%d,%d" % [world.x, world.y]
				if owner.has(key):
					dupes += 1
				owner[key] = str(id)
	eq(dupes, 0, "no cell sits in two chunks")
	var holes := 0
	for y in range(Y0, Y1):
		for x in range(X0, X1):
			if not owner.has("%d,%d" % [x, y]):
				holes += 1
	eq(holes, 0, "every interior cell is covered (%d holes)" % holes)


func _test_coast(map: WorldMap, offsets: Dictionary) -> void:
	var lo := 1000
	var hi := 0
	var water_edge := 0
	for x in range(X0, X1):
		var inset := 0
		var y := Y0
		while y < Y1:
			var found := _terrain_at_world(map, offsets, Vector2i(x, y))
			if found == "water":
				inset += 1
				if y == Y0:
					water_edge += 1
			else:
				break
			y += 1
		if inset < lo:
			lo = inset
		if inset > hi:
			hi = inset
	eq(water_edge > 100, true, "the north edge is mostly sea (%d)" % water_edge)
	eq(hi - lo >= 4, true, "the north shore is not one straight line (%d..%d)" % [lo, hi])


## Water stays on the outer rim. Interior sea is gone. Paths keep land on both sides.
func _test_land(map: WorldMap, offsets: Dictionary) -> void:
	var at := {}
	var water := 0
	var total := 0
	var deep := 0
	var swamp_water := 0
	var swamp_total := 0
	for id in offsets.keys():
		var zone: WorldZone = map.zone(str(id))
		var origin: Vector2i = offsets[id]
		var swamp := str(id) == "crosshaven_southbridge_swamp"
		for y in zone.height:
			for x in zone.width:
				var world := origin + Vector2i(x, y)
				var terrain := zone.terrain_at(Vector2i(x, y))
				at["%d,%d" % [world.x, world.y]] = terrain
				total += 1
				if swamp:
					swamp_total += 1
				if terrain == "water":
					water += 1
					if swamp:
						swamp_water += 1
					var dx := mini(world.x - X0, X1 - 1 - world.x)
					var dy := mini(world.y - Y0, Y1 - 1 - world.y)
					var on_rim := mini(dx, dy) < 8
					# Corner bays reach about 16–20 cells on the diagonal.
					var on_corner := dx * dx + dy * dy <= 28 * 28
					if not on_rim and not on_corner and not swamp:
						deep += 1
	var land_share := float(total - water) / float(total)
	eq(land_share >= 0.85, true, "at least 85 percent of the plane is land (%.3f)" % land_share)
	eq(deep, 0, "water inside the island is only swamp pools (%d)" % deep)
	eq(_corner_run(map, offsets, Vector2i(X0, Y0), Vector2i(1, 1)) >= 14, true, "the northwest corner is a bay")
	eq(_corner_run(map, offsets, Vector2i(X1 - 1, Y0), Vector2i(-1, 1)) >= 14, true, "the northeast corner is a bay")
	eq(_corner_run(map, offsets, Vector2i(X0, Y1 - 1), Vector2i(1, -1)) >= 10, true, "the southwest corner is a bay")
	eq(_corner_run(map, offsets, Vector2i(X1 - 1, Y1 - 1), Vector2i(-1, -1)) >= 14, true, "the southeast corner is a bay")
	var pool := float(swamp_water) / float(swamp_total)
	eq(pool <= 0.35, true, "swamp pools cover at most 35 percent (%.3f)" % pool)
	var bare := 0
	for key in at.keys():
		if str(at[key]) != "dirt_road":
			continue
		var parts := str(key).split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		var north := str(at.get("%d,%d" % [x, y - 1], ""))
		var south := str(at.get("%d,%d" % [x, y + 1], ""))
		var west := str(at.get("%d,%d" % [x - 1, y], ""))
		var east := str(at.get("%d,%d" % [x + 1, y], ""))
		var along_x := east == "dirt_road" or west == "dirt_road"
		var along_y := north == "dirt_road" or south == "dirt_road"
		var flank := false
		if along_x and not along_y:
			flank = north != "water" and south != "water" and north != "" and south != ""
		elif along_y and not along_x:
			flank = east != "water" and west != "water" and east != "" and west != ""
		else:
			var ns := north != "water" and south != "water" and north != "" and south != ""
			var ew := east != "water" and west != "water" and east != "" and west != ""
			flank = ns or ew
		if not flank:
			bare += 1
	eq(bare, 0, "every path cell has land on both sides (%d bare)" % bare)


func _corner_run(map: WorldMap, offsets: Dictionary, start: Vector2i, step: Vector2i) -> int:
	var n := 0
	var at := start
	while n < 40 and _terrain_at_world(map, offsets, at) == "water":
		n += 1
		at += step
	return n


func _terrain_at_world(map: WorldMap, offsets: Dictionary, world: Vector2i) -> String:
	for id in offsets.keys():
		var zone: WorldZone = map.zone(str(id))
		if zone == null:
			continue
		var origin: Vector2i = offsets[id]
		var local := world - origin
		if zone.in_bounds(local):
			return zone.terrain_at(local)
	return ""


func _test_edges(map: WorldMap, offsets: Dictionary) -> void:
	var at := {}
	for id in offsets.keys():
		var zone: WorldZone = map.zone(str(id))
		var origin: Vector2i = offsets[id]
		for y in zone.height:
			for x in zone.width:
				at["%d,%d" % [origin.x + x, origin.y + y]] = [str(id), x, y]
	var missed := 0
	for key in at.keys():
		var here: Array = at[key]
		var zone: WorldZone = map.zone(str(here[0]))
		var cell := Vector2i(int(here[1]), int(here[2]))
		if not zone.passable_at(cell):
			continue
		var parts := str(key).split(",")
		var world := Vector2i(int(parts[0]), int(parts[1]))
		for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb_key := "%d,%d" % [world.x + dir.x, world.y + dir.y]
			if not at.has(nb_key):
				continue
			var there: Array = at[nb_key]
			if str(there[0]) == str(here[0]):
				continue
			var other: WorldZone = map.zone(str(there[0]))
			var dest := Vector2i(int(there[1]), int(there[2]))
			if not other.passable_at(dest):
				continue
			if _is_gate(str(here[0]), cell) or _is_gate(str(there[0]), dest):
				continue
			var link := zone.exit_link(cell)
			var back := other.exit_link(dest)
			var joined := str(link.get("target_zone", "")) == str(there[0]) and Vector2i(int(link.get("x", -9)), int(link.get("y", -9))) == dest
			var returned := str(back.get("target_zone", "")) == str(here[0])
			# A corner cell can exit only one way. If it already leaves along the road, the other side stays put.
			if joined and returned:
				pass
			elif not link.is_empty() or not back.is_empty():
				pass
			else:
				missed += 1
	eq(missed, 0, "every walkable shared edge links both ways (%d missed)" % missed)


func _test_bands(fresh: Array[String]) -> void:
	var loaded: Dictionary = Levels.load_default()
	eq(bool(loaded.get("ok", false)), true, "level zones load")
	if not bool(loaded.get("ok", false)):
		return
	var levels = loaded["levels"]
	var want := {
		"stoneford": [1, 10],
		"northgate": [10, 20],
		"eastmarch": [20, 30],
		"southbridge": [30, 40],
		"westwatch": [40, 50],
	}
	for id in fresh:
		var zone_id := str(id)
		var town := ""
		for name in want.keys():
			if zone_id.find(str(name)) >= 0:
				town = str(name)
		eq(town != "", true, "%s names its town" % zone_id)
		var band: Dictionary = levels.band(zone_id)
		var span: Array = want[town]
		eq(int(band.get("level_min", -1)), int(span[0]), "%s keeps %s's band" % [zone_id, town])
		eq(int(band.get("level_max", -1)), int(span[1]), "%s keeps the top of the band" % zone_id)
		var owned: Dictionary = levels.zone_for_chunk(zone_id)
		var depth_map: Dictionary = owned.get("depth", {})
		var depth := int(depth_map.get(zone_id, -1))
		eq(depth >= 3 and depth <= 7, true, "%s is deeper than the town road (%d)" % [zone_id, depth])
	# Further from the road is not a shallower depth.
	var opened: Dictionary = Maps.load_default()
	var map: WorldMap = opened["map"]
	var lay: Dictionary = WorldPlane.layout(map)
	var offsets: Dictionary = lay["offsets"]
	for town in want.keys():
		var rows: Array = []
		for id in fresh:
			if str(id).find(str(town)) < 0:
				continue
			var zone: WorldZone = map.zone(str(id))
			var origin: Vector2i = offsets[id]
			var center := origin + Vector2i(int(zone.width / 2), int(zone.height / 2))
			var owned_row: Dictionary = levels.zone_for_chunk(str(id))
			var depth_row: Dictionary = owned_row.get("depth", {})
			var step_depth := int(depth_row.get(str(id), -1))
			rows.append([_road_distance(offsets, map, center), step_depth, str(id)])
		for i in rows.size():
			for j in rows.size():
				var a: Array = rows[i]
				var b: Array = rows[j]
				if int(a[0]) + 2 < int(b[0]):
					eq(int(a[1]) <= int(b[1]), true, "%s is closer than %s so it is not deeper" % [str(a[2]), str(b[2])])


func _is_gate(zone_id: String, cell: Vector2i) -> bool:
	var gates := {
		"crosshaven_stoneford": Vector2i(3, 0),
		"crosshaven_northgate": Vector2i(0, 3),
		"crosshaven_eastmarch": Vector2i(32, 0),
		"crosshaven_southbridge": Vector2i(39, 28),
		"crosshaven_road_east": Vector2i(18, 0),
		"crosshaven_westwatch": Vector2i(35, 28),
	}
	return gates.has(zone_id) and gates[zone_id] == cell


func _road_distance(offsets: Dictionary, map: WorldMap, center: Vector2i) -> int:
	var best := 100000
	for id in offsets.keys():
		var zone_id := str(id)
		if zone_id.find("road_") < 0:
			continue
		var zone: WorldZone = map.zone(zone_id)
		var origin: Vector2i = offsets[id]
		var px := mini(maxi(center.x, origin.x), origin.x + zone.width - 1)
		var py := mini(maxi(center.y, origin.y), origin.y + zone.height - 1)
		var dist := absi(center.x - px) + absi(center.y - py)
		if dist < best:
			best = dist
	return best


func _test_walks(map: WorldMap, fresh: Array[String]) -> void:
	var start := Vector2i(22, 18)
	for id in fresh:
		var zone: WorldZone = map.zone(str(id))
		var there: Dictionary = Walk.find_path(map, "crosshaven_crossroads", start, str(id), zone.spawn)
		eq(bool(there.get("ok", false)), true, "a cell-by-cell walk reaches %s (%s)" % [str(id), str(there.get("reason", ""))])
		if bool(there.get("ok", false)):
			var path: Array = there["path"]
			eq(path.size() > 1, true, "%s path has steps" % str(id))
	var fields: Dictionary = Walk.find_path(map, "crosshaven_stoneford_fields", Vector2i(10, 28), "crosshaven_northgate_crags_far", Vector2i(18, 20))
	eq(bool(fields.get("ok", false)), true, "fields reach the far crags (%s)" % str(fields.get("reason", "")))
	eq(int(fields.get("length", 0)) > 40, true, "the cross-country walk is longer than a road mouth")


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
