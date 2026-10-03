extends SceneTree

## Crosshaven open-world zones: schema, exits, reachability, walk authority.
## Run: godot --headless --path . -s res://tests/run_crosshaven_zone_tests.gd

const SCHEMA_PATH := "res://data/world/crosshaven/schema/zone.schema.json"
const ARENA_TAGS := "res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json"
const SPIRE_HOME := {
	"northgate_spire": "crosshaven_northgate",
	"stoneford_spire": "crosshaven_stoneford",
	"eastmarch_spire": "crosshaven_eastmarch",
	"westwatch_spire": "crosshaven_westwatch",
	"southbridge_spire": "crosshaven_southbridge",
}

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Crosshaven zone tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_catalog_matches_schema()
	_test_schema_rejects()
	_test_arena_tags_remain()
	var loaded: Dictionary = WorldMap.load_default()
	if not bool(loaded["ok"]):
		eq(false, true, "Crosshaven index loads (%s)" % str(loaded["errors"]))
		return
	var map: WorldMap = loaded["map"]
	_test_index(map)
	_test_every_file(map)
	_test_reciprocal_exits(map)
	_test_art_ids(map)
	_test_reachability(map)
	_test_proposed_slope(map)
	_test_walk_on_map(map)
	_test_walk_fixtures()
	_test_climb_limit()
	_test_world_walk_stays_off_combat()


func _test_catalog_matches_schema() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	var tiles: Array = schema["$defs"]["tileCatalog"]["const"]
	var props: Array = schema["$defs"]["propCatalog"]["const"]
	var terrain_enum: Array = schema["properties"]["tiles"]["items"]["properties"]["terrain"]["enum"]
	var prop_enum: Array = schema["properties"]["props"]["items"]["properties"]["type"]["enum"]
	eq(tiles.size(), WorldZone.TILE_ORDER.size(), "schema tile catalog length")
	eq(props.size(), WorldZone.PROP_ORDER.size(), "schema prop catalog length")
	for i in tiles.size():
		eq(str(tiles[i]["id"]), WorldZone.TILE_ORDER[i], "tile catalog id %d" % i)
		eq(bool(tiles[i]["walkable"]), bool(WorldZone.TILE_WALKABLE[WorldZone.TILE_ORDER[i]]), "tile %s walkable" % tiles[i]["id"])
		eq(str(terrain_enum[i]), WorldZone.TILE_ORDER[i], "terrain enum %d" % i)
	for i in props.size():
		var prop_id := str(props[i]["id"])
		eq(prop_id, WorldZone.PROP_ORDER[i], "prop catalog id %d" % i)
		eq(str(prop_enum[i]), prop_id, "prop enum %d" % i)
		eq(bool(props[i]["blocks"]), true, "%s blocks" % prop_id)
		var shape: Array = props[i]["footprint"]
		var code: Array = WorldZone.PROP_FOOTPRINTS[prop_id]
		eq(shape.size(), code.size(), "%s footprint length" % prop_id)
		for j in shape.size():
			eq(int(shape[j][0]), int(code[j][0]), "%s footprint dx %d" % [prop_id, j])
			eq(int(shape[j][1]), int(code[j][1]), "%s footprint dy %d" % [prop_id, j])


func _test_schema_rejects() -> void:
	var lava := _min_doc()
	lava["tiles"][0]["terrain"] = "lava"
	_rejects(lava, "unknown terrain id")
	var wet := _min_doc()
	wet["tiles"][0]["terrain"] = "water"
	wet["tiles"][0]["walkable"] = true
	_rejects(wet, "water cannot be walkable")
	var version := _min_doc()
	version["format_version"] = 2
	_rejects(version, "unknown format version")
	var tree := _min_doc()
	tree["props"] = [{
		"id": "bad_tree",
		"type": "tree",
		"blocks": true,
		"origin": {"x": 0, "y": 0},
		"footprint": [{"x": 0, "y": 0}, {"x": 1, "y": 0}],
	}]
	_rejects(tree, "tree footprint is 1x1")
	var unknown := _min_doc()
	unknown["props"] = [{
		"id": "bush_01",
		"type": "bush",
		"blocks": true,
		"origin": {"x": 0, "y": 0},
		"footprint": [{"x": 0, "y": 0}],
	}]
	_rejects(unknown, "bush is not a prop id")
	eq(WorldZone.parse(_min_doc())["ok"], true, "minimal golden plains zone parses")
	_test_blocks_false()


func _test_blocks_false() -> void:
	var doc := _min_doc()
	doc["props"] = [{
		"id": "shade_tree",
		"type": "tree",
		"blocks": false,
		"origin": {"x": 0, "y": 0},
		"footprint": [{"x": 0, "y": 0}],
	}]
	doc["decor"] = [{"id": "flower_01", "type": "flowers_c", "x": 0, "y": 0}]
	var parsed: Dictionary = WorldZone.parse(doc)
	eq(parsed["ok"], true, "blocks false and decor parse")
	var zone: WorldZone = parsed["zone"]
	eq(zone.blocked_at(Vector2i.ZERO), false, "blocks false does not block the cell")
	eq(zone.passable_at(Vector2i.ZERO), true, "decor does not block the cell")
	eq(zone.decor.size(), 1, "decor is kept on the zone")
	var bad := _min_doc()
	bad["decor"] = [{"id": "nope", "type": "not_a_decor", "x": 0, "y": 0}]
	eq(WorldZone.parse(bad)["ok"], false, "unknown decor id is rejected")


func _test_arena_tags_remain() -> void:
	truthy(FileAccess.file_exists(ARENA_TAGS), "Koliseo crosshaven_15x15_tags.json stays in place")
	var tags: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARENA_TAGS))
	truthy(typeof(tags) == TYPE_DICTIONARY and (tags as Dictionary).has("size"), "arena tags keep their own schema")


func _test_index(map: WorldMap) -> void:
	eq(map.region, "crosshaven", "region is crosshaven")
	eq(map.start_zone, "crosshaven_crossroads", "player start zone is the crossroads")
	eq(map.adjacency, "ortho", "v1 movement is ortho")
	eq(map.max_climb_steps, -1, "shipped climb limit is no limit")
	eq(WorldWalk.OPEN_WORLD_MAX_CLIMB_STEPS, -1, "code default climb limit is no limit")
	eq(map.zones.size(), 33, "Crosshaven has 33 chunks")
	var files: PackedStringArray = DirAccess.get_files_at("res://data/world/crosshaven/zones")
	var json_count := 0
	for file_name in files:
		if str(file_name).ends_with(".json"):
			json_count += 1
			var stem := str(file_name).trim_suffix(".json")
			truthy(map.zones.has(stem), "zone file %s is in the index" % file_name)
	eq(json_count, map.zones.size(), "zone directory matches the index")
	eq(map.zone(map.start_zone).spawn, map.start_cell, "index start matches the crossroads spawn")
	eq(map.start_cell, Vector2i(22, 18), "player spawn is the crossroads stand")


func _test_every_file(map: WorldMap) -> void:
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zones[zone_id]
		eq(zone.region, "crosshaven", "%s region" % zone_id)
		eq(zone.width * zone.height > 0, true, "%s has a grid" % zone_id)
		truthy(zone.passable_at(zone.spawn), "%s spawn is passable" % zone_id)
		truthy(zone.presentation.get("status", "") == "proposed", "%s weather hook is proposed" % zone_id)
		truthy(zone.presentation.get("authority", "") == "client_visual", "%s weather is client visual" % zone_id)
		for poi in zone.points_of_interest:
			var cell := Vector2i(int(poi["x"]), int(poi["y"]))
			truthy(zone.passable_at(cell), "%s poi %s is passable" % [zone_id, poi["id"]])


func _test_reciprocal_exits(map: WorldMap) -> void:
	var links := 0
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zones[zone_id]
		for exit_rec in zone.exits:
			var edge := str(exit_rec["edge"])
			for link in exit_rec["links"]:
				links += 1
				var frm := Vector2i(int(link["from"]["x"]), int(link["from"]["y"]))
				var dest := Vector2i(int(link["to"]["x"]), int(link["to"]["y"]))
				var target := str(exit_rec["target_zone"])
				var other: WorldZone = map.zone(target)
				truthy(zone.passable_at(frm), "%s exit %s is passable" % [zone_id, frm])
				eq(zone.walkable_at(frm), true, "%s exit %s is walkable land" % [zone_id, frm])
				var outward: Vector2i = frm + WorldZone.EDGE_DIR[edge]
				eq(zone.in_bounds(outward), false, "%s exit %s steps off the %s edge" % [zone_id, frm, edge])
				var back := other.exit_link(dest)
				eq(str(back.get("target_zone", "")), zone_id, "%s %s returns to the source zone" % [zone_id, frm])
				eq(Vector2i(int(back.get("x", -1)), int(back.get("y", -1))), frm, "%s %s returns to the source tile" % [zone_id, frm])
				eq(str(back.get("edge", "")), str(WorldZone.OPPOSITE_EDGE[edge]), "%s %s uses the opposite edge" % [zone_id, frm])
				var gone: Dictionary = WorldWalk.validate_path(map, [_step(zone_id, frm), _step(target, dest)])
				eq(gone["ok"], true, "exit step %s -> %s is legal (%s)" % [frm, dest, gone["reason"]])
				var back_step: Dictionary = WorldWalk.validate_path(map, [_step(target, dest), _step(zone_id, frm)])
				eq(back_step["ok"], true, "return step is legal (%s)" % back_step["reason"])
	eq(links > 0 and links % 2 == 0, true, "exit links come in reciprocal pairs (%d)" % links)


func _test_art_ids(map: WorldMap) -> void:
	var counts := {}
	for prop_id in WorldZone.PROP_ORDER:
		counts[prop_id] = 0
	var terrains := {}
	for tile_id in WorldZone.TILE_ORDER:
		terrains[tile_id] = 0
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zones[zone_id]
		for y in zone.height:
			for x in zone.width:
				var terrain := zone.terrain_at(Vector2i(x, y))
				terrains[terrain] = int(terrains[terrain]) + 1
		for prop in zone.props:
			var prop_type := str(prop["type"])
			counts[prop_type] = int(counts.get(prop_type, 0)) + 1
			if SPIRE_HOME.has(prop_type):
				eq(zone_id, str(SPIRE_HOME[prop_type]), "%s stays in its town" % prop_type)
			if prop_type == "crossroads_centerpiece":
				eq(zone_id, "crosshaven_crossroads", "centerpiece stays on the crossroads")
	for tile_id in WorldZone.TILE_ORDER:
		truthy(int(terrains[tile_id]) > 0, "tile id %s is used" % tile_id)
	for prop_id in WorldZone.PROP_ORDER:
		truthy(int(counts[prop_id]) > 0, "prop id %s is used" % prop_id)
	for prop_id in SPIRE_HOME.keys():
		eq(int(counts[prop_id]), 1, "%s is placed once" % prop_id)
	eq(int(counts["crossroads_centerpiece"]), 1, "one crossroads centerpiece")


func _test_reachability(map: WorldMap) -> void:
	var reached := WorldWalk.reachable_keys(map, map.start_zone, map.start_cell, map.max_climb_steps)
	var passable := 0
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zones[zone_id]
		for y in zone.height:
			for x in zone.width:
				var cell := Vector2i(x, y)
				if not zone.passable_at(cell):
					continue
				passable += 1
				if not reached.has(WorldWalk.cell_key(zone_id, cell)):
					eq(false, true, "passable tile %s %s is unreachable from spawn" % [zone_id, cell])
					return
	eq(reached.size(), passable, "every passable tile is reachable from spawn")


func _test_proposed_slope(map: WorldMap) -> void:
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zones[zone_id]
		for y in zone.height:
			for x in zone.width:
				var cell := Vector2i(x, y)
				if not zone.passable_at(cell):
					continue
				for dir in WorldWalk.ORTHO:
					var nxt := cell + dir
					if zone.in_bounds(nxt) and zone.passable_at(nxt):
						if absi(zone.height_at(nxt) - zone.height_at(cell)) > 1:
							eq(false, true, "walkable slope %s %s -> %s exceeds 1" % [zone_id, cell, nxt])
							return
				var link := zone.exit_link(cell)
				if link.is_empty():
					continue
				var other: WorldZone = map.zone(str(link["target_zone"]))
				var dest := Vector2i(int(link["x"]), int(link["y"]))
				if absi(other.height_at(dest) - zone.height_at(cell)) > 1:
					eq(false, true, "exit slope %s %s exceeds 1" % [zone_id, cell])
					return
	eq(true, true, "walkable neighbors differ by at most one height step")


func _test_walk_on_map(map: WorldMap) -> void:
	var cross: WorldZone = map.zone("crosshaven_crossroads")
	var step := _ortho_passable_pair(cross)
	var accepted: Dictionary = WorldWalk.validate_path(map, [
		_step(cross.zone_id, step["from"]),
		_step(cross.zone_id, step["to"]),
	])
	eq(accepted["ok"], true, "ortho road step is accepted (%s)" % accepted["reason"])
	var diagonal := Vector2i(step["from"].x + 1, step["from"].y + 1)
	if cross.in_bounds(diagonal) and cross.passable_at(diagonal):
		var rejected: Dictionary = WorldWalk.validate_path(map, [
			_step(cross.zone_id, step["from"]),
			_step(cross.zone_id, diagonal),
		])
		eq(rejected["reason"], "not_adjacent", "diagonal step is rejected")
	var water_zone := _zone_with_terrain(map, "water")
	var water := _terrain_neighbor(water_zone, "water")
	if not water.is_empty():
		var wet: Dictionary = WorldWalk.validate_path(map, [
			_step(water_zone.zone_id, water["from"]),
			_step(water_zone.zone_id, water["to"]),
		])
		eq(wet["reason"], "not_walkable", "water step is rejected")
	var blocked := _blocked_neighbor(cross)
	if not blocked.is_empty():
		var hit: Dictionary = WorldWalk.validate_path(map, [
			_step(cross.zone_id, blocked["from"]),
			_step(cross.zone_id, blocked["to"]),
		])
		eq(hit["reason"], "blocked", "centerpiece step is rejected")
	var north: WorldZone = map.zone("crosshaven_northgate")
	var poi := _poi(north, "northgate_center")
	var found: Dictionary = WorldWalk.find_path(
		map, map.start_zone, map.start_cell, north.zone_id, Vector2i(int(poi["x"]), int(poi["y"]))
	)
	eq(found["ok"], true, "click-to-walk reaches Northgate (%s)" % found["reason"])
	var checked: Dictionary = WorldWalk.validate_path(map, found["path"])
	eq(checked["ok"], true, "Northgate path validates (%s)" % checked["reason"])
	var seen := {}
	for hop in found["path"]:
		seen[str(hop["zone_id"])] = true
	eq(bool(seen.get("crosshaven_crossroads", false)), true, "Northgate path includes the crossroads")
	eq(bool(seen.get("crosshaven_road_north", false)), true, "Northgate path includes the north road")
	eq(bool(seen.get("crosshaven_northgate", false)), true, "Northgate path includes the town")
	for town_id in ["crosshaven_stoneford", "crosshaven_eastmarch", "crosshaven_westwatch", "crosshaven_southbridge"]:
		var town: WorldZone = map.zone(town_id)
		var center: Dictionary = town.points_of_interest[0]
		for poi_rec in town.points_of_interest:
			if str(poi_rec["kind"]) == "town":
				center = poi_rec
		var town_path: Dictionary = WorldWalk.find_path(
			map, map.start_zone, map.start_cell, town_id, Vector2i(int(center["x"]), int(center["y"]))
		)
		eq(town_path["ok"], true, "click-to-walk reaches %s (%s)" % [town_id, town_path["reason"]])
		eq(WorldWalk.validate_path(map, town_path["path"])["ok"], true, "%s path validates" % town_id)
	var stay: Dictionary = WorldWalk.find_path(map, map.start_zone, map.start_cell, map.start_zone, map.start_cell)
	eq(stay["reason"], "same_tile", "clicking the current tile is same_tile")
	var cliff := _first_terrain(map.zone("crosshaven_northgate"), "cliff")
	var cliff_path: Dictionary = WorldWalk.find_path(map, map.start_zone, map.start_cell, "crosshaven_northgate", cliff)
	eq(cliff_path["reason"], "not_walkable", "a cliff click is not walkable")


func _test_walk_fixtures() -> void:
	var row := _zone("crosshaven_lane", [".r.", ".t.", ".r."], [_tree("lane_tree", 1, 1)])
	var map := _map([row], row.zone_id)
	var around: Dictionary = WorldWalk.find_path(map, row.zone_id, Vector2i(0, 1), row.zone_id, Vector2i(2, 1))
	eq(around["ok"], true, "pathfinding walks around a tree (%s)" % around["reason"])
	eq(around["length"], 4, "the detour is four steps")
	for hop in around["path"]:
		eq(Vector2i(int(hop["x"]), int(hop["y"])) == Vector2i(1, 1), false, "the path stays off the tree")
	eq(WorldWalk.validate_path(map, around["path"])["ok"], true, "the detour validates")
	var wall := _zone("crosshaven_hall", ["rtr"], [_tree("hall_tree", 1, 0)])
	var walled := _map([wall], wall.zone_id)
	var stuck: Dictionary = WorldWalk.find_path(walled, wall.zone_id, Vector2i(0, 0), wall.zone_id, Vector2i(2, 0))
	eq(stuck["reason"], "unreachable", "a sealed hall is unreachable")
	var pond := _zone("crosshaven_pond", ["rwr"])
	var wet := _map([pond], pond.zone_id)
	var splash: Dictionary = WorldWalk.validate_path(wet, [_step(pond.zone_id, Vector2i(0, 0)), _step(pond.zone_id, Vector2i(1, 0))])
	eq(splash["reason"], "not_walkable", "fixture water is rejected")
	var jump: Dictionary = WorldWalk.validate_path(wet, [_step(pond.zone_id, Vector2i(0, 0)), _step(pond.zone_id, Vector2i(0, 2))])
	eq(jump["reason"], "out_of_bounds", "a same-zone step off the grid is out of bounds")
	eq(WorldWalk.validate_path(wet, [_step(pond.zone_id, Vector2i(0, 0))])["reason"], "empty_path", "a single tile is not a walk")
	var gate_a := _zone("crosshaven_gate_a", ["rrr"], [], [{
		"id": "to_gate_b",
		"edge": "east",
		"target_zone": "crosshaven_gate_b",
		"links": [{"from": {"x": 2, "y": 0}, "to": {"x": 0, "y": 0}}],
	}], Vector2i(0, 0))
	var gate_b := _zone("crosshaven_gate_b", ["rrr"], [], [{
		"id": "to_gate_a",
		"edge": "west",
		"target_zone": "crosshaven_gate_a",
		"links": [{"from": {"x": 0, "y": 0}, "to": {"x": 2, "y": 0}}],
	}], Vector2i(2, 0))
	var gates := _map([gate_a, gate_b], gate_a.zone_id)
	var crossed: Dictionary = WorldWalk.validate_path(gates, [
		_step(gate_a.zone_id, Vector2i(2, 0)),
		_step(gate_b.zone_id, Vector2i(0, 0)),
	])
	eq(crossed["ok"], true, "a declared exit is accepted")
	var wrong: Dictionary = WorldWalk.validate_path(gates, [
		_step(gate_a.zone_id, Vector2i(2, 0)),
		_step(gate_b.zone_id, Vector2i(1, 0)),
	])
	eq(wrong["reason"], "bad_exit", "the wrong arrival tile is a bad exit")
	var searched: Dictionary = WorldWalk.find_path(gates, gate_a.zone_id, Vector2i(0, 0), gate_b.zone_id, Vector2i(2, 0))
	eq(searched["ok"], true, "pathfinding crosses the exit (%s)" % searched["reason"])
	eq(WorldWalk.validate_path(gates, searched["path"])["ok"], true, "the cross-zone path validates")


func _test_climb_limit() -> void:
	var ridge := _zone(
		"crosshaven_ridge",
		["rrr"],
		[],
		[],
		Vector2i(0, 0),
		[{"id": "mark", "name": "Mark", "kind": "landmark", "x": 0, "y": 0}],
		[[0, 0, 3]],
	)
	var map := _map([ridge], ridge.zone_id)
	var up := [_step(ridge.zone_id, Vector2i(1, 0)), _step(ridge.zone_id, Vector2i(2, 0))]
	eq(WorldWalk.validate_path(map, up)["ok"], true, "the default climb limit accepts a rise of 3")
	eq(WorldWalk.validate_path(map, up, -1)["ok"], true, "an explicit no-limit accepts a rise of 3")
	eq(WorldWalk.validate_path(map, up, 1)["reason"], "climb_too_steep", "a climb limit of 1 rejects a rise of 3")
	eq(WorldWalk.validate_path(map, up, 3)["ok"], true, "a climb limit of 3 accepts a rise of 3")
	var down := [_step(ridge.zone_id, Vector2i(2, 0)), _step(ridge.zone_id, Vector2i(1, 0))]
	eq(WorldWalk.validate_path(map, down, 0)["ok"], true, "a drop stays legal when climbing is forbidden")
	var sought: Dictionary = WorldWalk.find_path(map, ridge.zone_id, Vector2i(0, 0), ridge.zone_id, Vector2i(2, 0), 1)
	eq(sought["reason"], "unreachable", "pathfinding honors a climb limit of 1")
	var open: Dictionary = WorldWalk.find_path(map, ridge.zone_id, Vector2i(0, 0), ridge.zone_id, Vector2i(2, 0))
	eq(open["ok"], true, "pathfinding with no climb limit crosses the ridge")


func _test_world_walk_stays_off_combat() -> void:
	var walk := FileAccess.get_file_as_string("res://backend/world_walk.gd")
	var zone := FileAccess.get_file_as_string("res://backend/world_zone.gd")
	var world_map := FileAccess.get_file_as_string("res://backend/world_map.gd")
	for src in [walk, zone, world_map]:
		eq(src.contains("CombatSim"), false, "world data does not reference CombatSim")
		eq(src.contains("elevation_cost"), false, "world data does not use combat elevation_cost")
		eq(src.contains("WalkBoard"), false, "world data does not use WalkBoard")


func _rejects(doc: Dictionary, msg: String) -> void:
	var checked: Dictionary = WorldZone.validate_document(doc)
	eq(bool(checked["ok"]), false, msg)


func _min_doc() -> Dictionary:
	return {
		"format": "stasium.zone",
		"format_version": 1,
		"zone_id": "crosshaven_fixture",
		"region": "crosshaven",
		"width": 1,
		"height": 1,
		"spawn": {"x": 0, "y": 0},
		"points_of_interest": [{"id": "mark", "name": "Mark", "kind": "landmark", "x": 0, "y": 0}],
		"exits": [],
		"props": [],
		"tiles": [{"x": 0, "y": 0, "terrain": "golden_plains", "walkable": true, "height": 0}],
	}


func _zone(
	zone_id: String,
	rows: Array,
	props: Array = [],
	exits: Array = [],
	spawn: Vector2i = Vector2i.ZERO,
	pois: Array = [],
	heights: Array = [],
) -> WorldZone:
	var height := rows.size()
	var width := str(rows[0]).length()
	var tiles: Array = []
	for y in height:
		var row := str(rows[y])
		for x in width:
			var terrain := "golden_plains"
			var walkable := true
			match row.substr(x, 1):
				"r":
					terrain = "dirt_road"
				"w":
					terrain = "water"
					walkable = false
				"c":
					terrain = "cliff"
					walkable = false
				"t":
					terrain = "golden_plains"
				_:
					terrain = "golden_plains"
			var step := 0
			if not heights.is_empty():
				step = int(heights[y][x])
			tiles.append({
				"x": x,
				"y": y,
				"terrain": terrain,
				"walkable": walkable,
				"height": step,
			})
	if pois.is_empty():
		pois = [{"id": "mark", "name": "Mark", "kind": "landmark", "x": spawn.x, "y": spawn.y}]
	var parsed: Dictionary = WorldZone.parse({
		"format": "stasium.zone",
		"format_version": 1,
		"zone_id": zone_id,
		"region": "crosshaven",
		"width": width,
		"height": height,
		"spawn": {"x": spawn.x, "y": spawn.y},
		"points_of_interest": pois,
		"exits": exits,
		"props": props,
		"tiles": tiles,
	})
	if not bool(parsed["ok"]):
		push_error("%s failed to parse: %s" % [zone_id, str(parsed["errors"])])
	return parsed["zone"]


func _tree(prop_id: String, x: int, y: int) -> Dictionary:
	return {
		"id": prop_id,
		"type": "tree",
		"blocks": true,
		"origin": {"x": x, "y": y},
		"footprint": [{"x": x, "y": y}],
	}


func _map(zones: Array, start_id: String) -> WorldMap:
	var map := WorldMap.new()
	map.region = "crosshaven"
	map.start_zone = start_id
	map.max_climb_steps = WorldWalk.OPEN_WORLD_MAX_CLIMB_STEPS
	map.adjacency = "ortho"
	for zone in zones:
		map.zones[zone.zone_id] = zone
		if zone.zone_id == start_id:
			map.start_cell = zone.spawn
	return map


func _step(zone_id: String, cell: Vector2i) -> Dictionary:
	return {"zone_id": zone_id, "x": cell.x, "y": cell.y}


func _poi(zone: WorldZone, poi_id: String) -> Dictionary:
	for poi in zone.points_of_interest:
		if str(poi["id"]) == poi_id:
			return poi
	return {}


func _ortho_passable_pair(zone: WorldZone) -> Dictionary:
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if not zone.passable_at(cell):
				continue
			var east := Vector2i(x + 1, y)
			if zone.passable_at(east):
				return {"from": cell, "to": east}
	return {}


func _terrain_neighbor(zone: WorldZone, terrain: String) -> Dictionary:
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if zone.terrain_at(cell) != terrain:
				continue
			for dir in WorldWalk.ORTHO:
				var origin: Vector2i = cell - dir
				if zone.passable_at(origin):
					return {"from": origin, "to": cell}
	return {}


func _blocked_neighbor(zone: WorldZone) -> Dictionary:
	for prop in zone.props:
		if str(prop["type"]) != "crossroads_centerpiece":
			continue
		for footprint in prop["footprint"]:
			var cell := Vector2i(int(footprint["x"]), int(footprint["y"]))
			for dir in WorldWalk.ORTHO:
				var origin: Vector2i = cell + dir
				if zone.passable_at(origin):
					return {"from": origin, "to": cell}
	return {}


func _zone_with_terrain(map: WorldMap, terrain: String) -> WorldZone:
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zones[zone_id]
		if not _terrain_neighbor(zone, terrain).is_empty():
			return zone
	return null


func _first_terrain(zone: WorldZone, terrain: String) -> Vector2i:
	for y in zone.height:
		for x in zone.width:
			if zone.terrain_at(Vector2i(x, y)) == terrain:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


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
