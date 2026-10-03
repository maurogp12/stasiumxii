extends SceneTree

## WP10a dressing placer. Run: godot --headless --path . -s res://tests/run_region_dressing_tests.gd

const Atlas = preload("res://backend/world_atlas.gd")
const Walk = preload("res://backend/world_walk.gd")

const REGIONS: Array[String] = [
	"rowanvale",
	"windmere",
	"brinewake",
	"slagcrown",
	"eastmarch_fen_edge",
	"gloomfen_mire",
	"stormspire",
	"ashen_shardfields",
	"blightwood_hollow",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/schema/region_dressing.schema.json"))
	eq(str(schema["properties"]["format"]["const"]), "stasium.region_dressing", "dressing schema format")
	eq(schema["additionalProperties"], false, "dressing schema rejects unknown keys")
	var loaded: Dictionary = Atlas.load_default()
	eq(bool(loaded.get("ok", false)), true, "atlas loads dressed regions (%s)" % str(loaded.get("errors", [])))
	if not bool(loaded.get("ok", false)):
		_finish()
		return
	var atlas = loaded["atlas"]
	var npc_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/npcs.json"))
	var gate_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/gates.json"))
	for region in REGIONS:
		_test_region(atlas, region, npc_doc, gate_doc)
	_finish()


func _finish() -> void:
	print("region dressing tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_region(atlas, region: String, npc_doc: Dictionary, gate_doc: Dictionary) -> void:
	var dressing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/%s/dressing.json" % region))
	eq(str(dressing["format"]), "stasium.region_dressing", "%s dressing format" % region)
	eq(int(dressing["format_version"]), 1, "%s dressing version" % region)
	eq(str(dressing["region"]), region, "%s dressing region" % region)
	eq(int(dressing["seed"]) > 0, true, "%s dressing seed is fixed" % region)
	var prop_rows: Array = dressing["props"]
	eq(prop_rows.size() >= 6 and prop_rows.size() <= 10, true, "%s lists 6 to 10 stand-in props" % region)
	var limits: Dictionary = dressing["limits"]
	var block_limit := float(limits["blocking"])
	var decor_limit := float(limits["decor"])
	eq(block_limit <= 0.08 and decor_limit <= 0.25, true, "%s caps match the placement rules" % region)
	var cluster_rule: Dictionary = dressing["cluster"]
	var spacing := int(cluster_rule["spacing"])
	var glade := int(cluster_rule["glade"])
	var clearance := int(dressing["clearance"])
	var hero: Dictionary = dressing["hero"]
	var hero_chunk := str(hero["chunk_id"])
	var map: WorldMap = atlas.maps[region]
	var entry_id := region + "_entry"
	var door_id := region + "_door"
	var entry_zone: WorldZone = map.zone(entry_id)
	var door_zone: WorldZone = map.zone(door_id)
	eq(entry_zone != null and door_zone != null, true, "%s entry and door stay built" % region)
	if entry_zone == null or door_zone == null:
		return
	var to_door: Dictionary = Walk.find_path(map, entry_id, entry_zone.spawn, door_id, door_zone.spawn)
	eq(bool(to_door.get("ok", false)), true, "%s door is still reachable (%s)" % [region, str(to_door.get("reason", ""))])
	var on_path := {}
	for step in to_door.get("path", []):
		var rec: Dictionary = step
		on_path["%s#%d#%d" % [str(rec["zone_id"]), int(rec["x"]), int(rec["y"])]] = true
	var hero_count := 0
	for zone_id in map.zones.keys():
		var zone: WorldZone = map.zone(str(zone_id))
		if zone.zone_id != entry_id:
			var reached: Dictionary = Walk.find_path(map, entry_id, entry_zone.spawn, zone.zone_id, zone.spawn)
			eq(bool(reached.get("ok", false)), true, "%s still reaches %s" % [region, zone.zone_id])
		_test_chunk(zone, dressing, npc_doc, gate_doc, block_limit, decor_limit, spacing, glade, clearance, on_path)
		if zone.zone_id == hero_chunk:
			hero_count += 1
			_test_hero(zone, hero, on_path)
		else:
			eq(_landmark_type(zone), "tavern_3x2", "%s keeps the stand-in tavern off the hero chunk" % zone.zone_id)
	eq(hero_count, 1, "%s has one hero landmark" % region)


func _test_chunk(zone: WorldZone, dressing: Dictionary, npc_doc: Dictionary, gate_doc: Dictionary, block_limit: float, decor_limit: float, spacing: int, glade: int, clearance: int, on_path: Dictionary) -> void:
	var lane := _lane(zone)
	var protected := _protected(zone, npc_doc, gate_doc, clearance)
	var path_n := 0
	var terrains := {}
	var mix := {}
	for row in dressing["ground_mix"]:
		mix[str(row["terrain"])] = true
	for y in zone.height:
		for x in zone.width:
			var at := Vector2i(x, y)
			var terrain := zone.terrain_at(at)
			if terrain == "dirt_road":
				path_n += 1
			else:
				terrains[terrain] = true
				eq(mix.has(terrain), true, "%s ground %s is in the mix" % [zone.zone_id, terrain])
	eq(terrains.size() >= 2, true, "%s ground is a mix" % zone.zone_id)
	var non_path := zone.width * zone.height - path_n
	var blocked := 0
	var clusters := {}
	var residues := {}
	var landmarks := 0
	for prop in zone.props:
		var prop_id := str(prop.get("id", ""))
		var cells: Array[Vector2i] = []
		for foot in prop["footprint"]:
			cells.append(Vector2i(int(foot["x"]), int(foot["y"])))
		for cell in cells:
			eq(lane.has(_key(cell)), false, "%s %s stays off the path and its sides" % [zone.zone_id, prop_id])
			eq(protected.has(_key(cell)), false, "%s %s stays 2 cells from npc, gate, door, spawn, and exit" % [zone.zone_id, prop_id])
			if bool(prop.get("blocks", true)):
				blocked += 1
		if prop_id.ends_with("_landmark"):
			landmarks += 1
			continue
		var kind := ""
		if prop_id.find("_border_") >= 0:
			kind = "border"
		elif prop_id.find("_cluster_") >= 0:
			kind = "cluster"
		eq(kind != "", true, "%s dressing prop %s is a border or a cluster" % [zone.zone_id, prop_id])
		if kind == "":
			continue
		var tail := prop_id.split("_")
		var group := "%s_%s" % [kind, tail[tail.size() - 2]]
		if not clusters.has(group):
			clusters[group] = []
		for cell in cells:
			(clusters[group] as Array).append(cell)
		var origin := Vector2i(int(prop["origin"]["x"]), int(prop["origin"]["y"]))
		residues["%d,%d" % [posmod(origin.x, 3), posmod(origin.y, 3)]] = true
		if kind == "border":
			var depth := mini(mini(origin.x, origin.y), mini(zone.width - 1 - origin.x, zone.height - 1 - origin.y))
			eq(depth <= 1, true, "%s border prop sits in the 1–2 cell band" % zone.zone_id)
	eq(landmarks, 1, "%s has one landmark prop" % zone.zone_id)
	eq(float(blocked) / float(non_path) <= block_limit, true, "%s blocking props stay within the cap" % zone.zone_id)
	eq(float(zone.decor.size()) / float(non_path) <= decor_limit, true, "%s decor stays within the cap" % zone.zone_id)
	eq(residues.size() >= 3, true, "%s dressing is not one lattice" % zone.zone_id)
	for dec in zone.decor:
		var at := Vector2i(int(dec["x"]), int(dec["y"]))
		eq(lane.has(_key(at)), false, "%s decor stays off the path" % zone.zone_id)
		eq(protected.has(_key(at)), false, "%s decor stays clear of npc, gate, door, spawn, and exit" % zone.zone_id)
	var names: Array = clusters.keys()
	for name in names:
		var cells: Array = clusters[name]
		eq(cells.size() >= 3 and cells.size() <= 5, true, "%s %s is a cluster of 3 to 5" % [zone.zone_id, str(name)])
		for i in cells.size():
			for j in range(i + 1, cells.size()):
				eq(_apart(cells[i], cells[j]) >= spacing, true, "%s %s keeps the cluster spacing" % [zone.zone_id, str(name)])
	for i in names.size():
		for j in range(i + 1, names.size()):
			var gap := _group_gap(clusters[names[i]], clusters[names[j]])
			eq(gap >= glade, true, "%s clusters leave an open glade" % zone.zone_id)
	_test_border(zone, clusters)
	for npc_cell in _npc_cells(zone.zone_id, npc_doc):
		eq(zone.passable_at(npc_cell), true, "%s npc cell stays passable" % zone.zone_id)
	for gate_cell in _gate_cells(zone.zone_id, gate_doc):
		eq(zone.passable_at(gate_cell), true, "%s gate cell stays passable" % zone.zone_id)


func _test_border(zone: WorldZone, clusters: Dictionary) -> void:
	var exit_edges := {}
	for exit_rec in zone.exits:
		exit_edges[str(exit_rec["edge"])] = true
	for edge in ["north", "east", "south", "west"]:
		if exit_edges.has(edge):
			continue
		var framed := false
		for prop in zone.props:
			if str(prop.get("id", "")).find("_border_") < 0:
				continue
			var origin := Vector2i(int(prop["origin"]["x"]), int(prop["origin"]["y"]))
			if _owner_edge(zone, origin, exit_edges) == edge:
				framed = true
		eq(framed, true, "%s frames the %s edge" % [zone.zone_id, edge])


func _test_hero(zone: WorldZone, hero: Dictionary, on_path: Dictionary) -> void:
	eq(_landmark_type(zone), str(hero["type"]), "%s hero replaces the stand-in tavern" % zone.zone_id)
	var nearest := 1000000
	for prop in zone.props:
		if not str(prop.get("id", "")).ends_with("_landmark"):
			continue
		var origin := Vector2i(int(prop["origin"]["x"]), int(prop["origin"]["y"]))
		for foot in prop["footprint"]:
			var cell := Vector2i(int(foot["x"]), int(foot["y"]))
			nearest = mini(nearest, _apart(zone.spawn, cell))
			eq(on_path.has("%s#%d#%d" % [zone.zone_id, cell.x, cell.y]), false, "%s hero stays off the critical path" % zone.zone_id)
		for cell in _line(zone.spawn, origin):
			var on_hero := false
			for foot in prop["footprint"]:
				if int(foot["x"]) == cell.x and int(foot["y"]) == cell.y:
					on_hero = true
			if on_hero:
				continue
			eq(zone.passable_at(cell), true, "%s hero is visible from the entry spawn" % zone.zone_id)
	eq(nearest <= 8, true, "%s hero is within sight of the spawn" % zone.zone_id)


func _landmark_type(zone: WorldZone) -> String:
	for prop in zone.props:
		if str(prop.get("id", "")).ends_with("_landmark"):
			return str(prop.get("type", ""))
	return ""


func _lane(zone: WorldZone) -> Dictionary:
	var lane := {}
	for y in zone.height:
		for x in zone.width:
			var at := Vector2i(x, y)
			if zone.terrain_at(at) != "dirt_road":
				continue
			lane[_key(at)] = true
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var side: Vector2i = at + dir
				if zone.in_bounds(side):
					lane[_key(side)] = true
	return lane


func _protected(zone: WorldZone, npc_doc: Dictionary, gate_doc: Dictionary, clearance: int) -> Dictionary:
	var seeds: Array[Vector2i] = [zone.spawn]
	for cell in _npc_cells(zone.zone_id, npc_doc):
		seeds.append(cell)
	for cell in _gate_cells(zone.zone_id, gate_doc):
		seeds.append(cell)
	for exit_rec in zone.exits:
		for link in exit_rec["links"]:
			var frm: Dictionary = link["from"]
			seeds.append(Vector2i(int(frm["x"]), int(frm["y"])))
	for poi in zone.points_of_interest:
		if str(poi["id"]).ends_with("_door"):
			seeds.append(Vector2i(int(poi["x"]), int(poi["y"])))
	var protected := {}
	for seed in seeds:
		for dy in range(-clearance, clearance + 1):
			for dx in range(-clearance, clearance + 1):
				if maxi(absi(dx), absi(dy)) > clearance:
					continue
				var at := Vector2i(seed.x + dx, seed.y + dy)
				if zone.in_bounds(at):
					protected[_key(at)] = true
	return protected


func _npc_cells(zone_id: String, npc_doc: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in npc_doc["npcs"]:
		var record: Dictionary = row
		if str(record["zone_id"]) != zone_id:
			continue
		var at: Dictionary = record["cell"]
		cells.append(Vector2i(int(at["x"]), int(at["y"])))
	return cells


func _gate_cells(zone_id: String, gate_doc: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in gate_doc["gates"]:
		var gate: Dictionary = row
		for side_name in ["from", "to"]:
			var side: Dictionary = gate[side_name]
			if str(side["zone_id"]) != zone_id:
				continue
			cells.append(Vector2i(int(side["x"]), int(side["y"])))
	return cells


func _owner_edge(zone: WorldZone, cell: Vector2i, exit_edges: Dictionary) -> String:
	var depths := {
		"north": cell.y,
		"east": zone.width - 1 - cell.x,
		"south": zone.height - 1 - cell.y,
		"west": cell.x,
	}
	var best := mini(mini(int(depths["north"]), int(depths["east"])), mini(int(depths["south"]), int(depths["west"])))
	if best > 1:
		return ""
	for edge in ["north", "east", "south", "west"]:
		if int(depths[edge]) == best and not exit_edges.has(edge):
			return edge
	return ""


func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - x0)
	var dy := absi(b.y - y0)
	var sx := 1 if x0 < b.x else -1
	var sy := 1 if y0 < b.y else -1
	var err := dx - dy
	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == b.x and y0 == b.y:
			return cells
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return cells


func _group_gap(a: Array, b: Array) -> int:
	var best := 1000000
	for left in a:
		for right in b:
			best = mini(best, _apart(left, right))
	return best


func _apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _key(cell: Vector2i) -> String:
	return "%d#%d" % [cell.x, cell.y]


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
