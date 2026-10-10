extends RefCounted

## PC dungeon doors (data/world/dungeons.json, spec 4.6). Preload. No global class.
## Crosshaven phase (section 00): one dungeon per town band. A `built`
## dungeon has a door (the hatch cell) and a run file; a `planned` one has
## neither. The granary building stands on the cells just north of the hatch
## (building_cells), sized from the art manifest, and blocks walking.

const Levels = preload("res://backend/world_levels.gd")

const PATH := "res://data/world/dungeons.json"
const FORMAT := "stasium.world_dungeons"
const FORMAT_VERSION := 1
const DOC_KEYS: Array[String] = ["format", "format_version", "status", "notes", "dungeons"]
const DUNGEON_KEYS: Array[String] = [
	"id", "name", "level_zone", "level_min", "level_max", "door", "door_art", "theme",
	"boss", "rooms", "party", "keeper", "run", "status",
]
## The five Crosshaven town bands (section 00), in town order.
const TOWN_BANDS: Array[String] = ["stoneford", "northgate", "eastmarch", "southbridge", "westwatch"]
const STATUSES: Array[String] = ["built", "planned"]
## Building size when the art manifest gives none (placeholder art).
const DEFAULT_BUILDING := Vector2i(3, 3)

var rows: Array = []
var _by_id: Dictionary = {}


static func load_default() -> Dictionary:
	return load_path(PATH)


static func load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(["dungeons file is missing"])
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail(["dungeons file must be a JSON object"])
	return load_document(doc)


static func load_document(doc: Dictionary) -> Dictionary:
	var book = new()
	var errors: Array = []
	book._read(doc, errors)
	if not errors.is_empty():
		return _fail(errors)
	return {"ok": true, "errors": [], "dungeons": book}


func by_id(dungeon_id: String) -> Dictionary:
	return (_by_id.get(dungeon_id, {}) as Dictionary).duplicate(true)


func built() -> Array:
	var out: Array = []
	for row in rows:
		if str(row["status"]) == "built":
			out.append((row as Dictionary).duplicate(true))
	return out


## Built dungeons whose door is in this chunk.
func doors_in(zone_id: String) -> Array:
	var out: Array = []
	for row in built():
		var door: Dictionary = row.get("door", {})
		if str(door.get("zone_id", "")) == zone_id:
			out.append(row)
	return out


func for_keeper(npc_id: String) -> Dictionary:
	for row in rows:
		if str(row.get("keeper", "")) == npc_id:
			return (row as Dictionary).duplicate(true)
	return {}


static func door_cell(row: Dictionary) -> Vector2i:
	var door: Dictionary = row.get("door", {})
	if door.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(door.get("x", -1)), int(door.get("y", -1)))


## The building's cells: `size` wide (x) and tall (y), on the rows just north
## of the hatch. The hatch row itself stays open. `door_from_nw` is the door
## cell from the footprint's north-west cell (art manifest
## town_door.door_cell_from_nw, e.g. (2, 3) for the archive); without it the
## building is centred on the hatch column (the granary's (1, 3)).
static func building_cells(row: Dictionary, size: Vector2i = DEFAULT_BUILDING, door_from_nw: Vector2i = Vector2i(-1, -1)) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var door := door_cell(row)
	if door.x < 0:
		return out
	var w := maxi(size.x, 1)
	var h := maxi(size.y, 1)
	var left := door.x - int((w - 1) / 2)
	var top := door.y - h
	if door_from_nw.x >= 0:
		left = door.x - door_from_nw.x
		top = door.y - door_from_nw.y
	for dy in h:
		for dx in w:
			out.append(Vector2i(left + dx, top + dy))
	return out


## {size, door_from_nw} of a dungeon's building from its art manifest
## (town_door.footprint_size, door_cell_from_nw). Empty when the art has none.
static func building_shape(row: Dictionary) -> Dictionary:
	var run_path := str(row.get("run", ""))
	if run_path == "" or not FileAccess.file_exists(run_path):
		return {}
	var run: Variant = JSON.parse_string(FileAccess.get_file_as_string(run_path))
	var art := str((run as Dictionary).get("art", "")) if typeof(run) == TYPE_DICTIONARY else ""
	if art == "" or not FileAccess.file_exists(art):
		return {}
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(art))
	var td: Variant = (man as Dictionary).get("town_door", null) if typeof(man) == TYPE_DICTIONARY else null
	if typeof(td) != TYPE_DICTIONARY or not (td as Dictionary).has("footprint_size"):
		return {}
	var fs: Array = td["footprint_size"]
	var out := {"size": Vector2i(int(fs[0]), int(fs[1])), "door_from_nw": Vector2i(-1, -1)}
	var dc: Variant = (td as Dictionary).get("door_cell_from_nw", null)
	if typeof(dc) == TYPE_ARRAY and (dc as Array).size() == 2:
		out["door_from_nw"] = Vector2i(int(dc[0]), int(dc[1]))
	return out


## The building cells of a row: its art manifest's shape, else `size` centred.
static func building_cells_for(row: Dictionary, size: Vector2i = DEFAULT_BUILDING) -> Array[Vector2i]:
	var shape := building_shape(row)
	if shape.is_empty():
		return building_cells(row, size)
	return building_cells(row, shape["size"], shape["door_from_nw"])


## Section 4.6 and section 00 rules against the live world.
## `atlas` from world_atlas, `npcs` from world_npcs. `size` is the building
## size for a dungeon whose art manifest gives none.
func validate_world(atlas, npcs, size: Vector2i = DEFAULT_BUILDING) -> Dictionary:
	var errors: Array = []
	var levels = atlas.levels if atlas != null else null
	if levels == null:
		var lv: Dictionary = Levels.load_default()
		levels = lv.get("levels", null)
	var per_band := {}
	for row in rows:
		var id := str(row["id"])
		var band_id := str(row["level_zone"])
		per_band[band_id] = int(per_band.get(band_id, 0)) + 1
		if levels == null or not levels.by_id.has(band_id):
			errors.append("%s level_zone %s is not a level zone" % [id, band_id])
			continue
		var band: Dictionary = levels.by_id[band_id]
		if int(band["level_min"]) != int(row["level_min"]) or int(band["level_max"]) != int(row["level_max"]):
			errors.append("%s levels must equal the %s band" % [id, band_id])
		if str(band.get("dungeon", "")) != id:
			errors.append("%s is not the %s band's dungeon" % [id, band_id])
		var keeper: Dictionary = npcs.by_id(str(row["keeper"])) if npcs != null else {}
		if keeper.is_empty() or str(keeper.get("role", "")) != "door_keeper":
			errors.append("%s keeper is not a door keeper" % id)
		if str(row["status"]) != "built":
			continue
		var door := door_cell(row)
		var zone_id := str((row["door"] as Dictionary).get("zone_id", ""))
		if not (band["chunks"] as Array).has(zone_id):
			errors.append("%s door is not in a %s chunk" % [id, band_id])
		var map = atlas.map_for_chunk(zone_id) if atlas != null else null
		var zone: WorldZone = map.zone(zone_id) if map != null else null
		if zone == null:
			errors.append("%s door chunk %s is not loaded" % [id, zone_id])
			continue
		_check_cell(id, "door", zone, door, atlas, npcs, errors)
		if str(keeper.get("zone_id", "")) != zone_id:
			errors.append("%s keeper does not stand in the door chunk" % id)
		else:
			var at: Dictionary = keeper.get("cell", {})
			var keeper_cell := Vector2i(int(at.get("x", -9)), int(at.get("y", -9)))
			if absi(keeper_cell.x - door.x) + absi(keeper_cell.y - door.y) != 1:
				errors.append("%s keeper must stand beside the hatch" % id)
		var building := building_cells_for(row, size)
		for cell in building:
			if not zone.in_bounds(cell) or not zone.passable_at(cell):
				errors.append("%s building cell %s is not open ground" % [id, cell])
				continue
			_check_cell(id, "building", zone, cell, atlas, npcs, errors)
		if not building.has(door + Vector2i(0, -1)):
			errors.append("%s building must stand on the cells just north of the hatch" % id)
		if not _door_reachable(zone, door, building, npcs):
			errors.append("%s hatch cannot be walked to from the chunk spawn" % id)
		var run_path := str(row.get("run", ""))
		if run_path == "" or not FileAccess.file_exists(run_path):
			errors.append("%s run file is missing" % id)
	for band_id in TOWN_BANDS:
		if int(per_band.get(band_id, 0)) != 1:
			errors.append("band %s must have exactly one dungeon" % band_id)
	for band_id in per_band.keys():
		if not TOWN_BANDS.has(str(band_id)):
			errors.append("band %s is not a Crosshaven town band" % band_id)
	return {"ok": errors.is_empty(), "errors": errors}


func _check_cell(id: String, what: String, zone: WorldZone, cell: Vector2i, atlas, npcs, errors: Array) -> void:
	if not zone.in_bounds(cell) or not zone.passable_at(cell):
		errors.append("%s %s %s is not passable" % [id, what, cell])
	if not zone.exit_link(cell).is_empty():
		errors.append("%s %s %s is an exit cell" % [id, what, cell])
	if atlas != null and not atlas.gate_at(zone.zone_id, cell).is_empty():
		errors.append("%s %s %s is a gate cell" % [id, what, cell])
	if cell == zone.spawn:
		errors.append("%s %s %s is the spawn" % [id, what, cell])
	if npcs != null:
		for npc in npcs.for_zone(zone.zone_id):
			var at: Dictionary = npc.get("cell", {})
			if Vector2i(int(at.get("x", -9)), int(at.get("y", -9))) == cell:
				errors.append("%s %s %s is an NPC cell" % [id, what, cell])


## Ortho flood from the spawn over passable cells, round the building and NPC posts.
static func _door_reachable(zone: WorldZone, door: Vector2i, building: Array[Vector2i], npcs) -> bool:
	var blocked := {}
	for cell in building:
		blocked[cell] = true
	if npcs != null:
		for npc in npcs.for_zone(zone.zone_id):
			var at: Dictionary = npc.get("cell", {})
			blocked[Vector2i(int(at.get("x", -9)), int(at.get("y", -9)))] = true
	var seen := {zone.spawn: true}
	var queue: Array[Vector2i] = [zone.spawn]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == door:
			return true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + step
			if seen.has(nxt) or blocked.has(nxt) or not zone.passable_at(nxt):
				continue
			seen[nxt] = true
			queue.append(nxt)
	return false


func _read(doc: Dictionary, errors: Array) -> void:
	for key in doc.keys():
		if not DOC_KEYS.has(str(key)):
			errors.append("unknown key %s" % key)
	if str(doc.get("format", "")) != FORMAT:
		errors.append("format")
	if int(doc.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("format_version")
	if str(doc.get("status", "")) != "proposed":
		errors.append("status")
	var list: Variant = doc.get("dungeons", null)
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
		errors.append("dungeons")
		return
	for raw in list:
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("dungeon row")
			continue
		var row: Dictionary = raw
		var id := str(row.get("id", ""))
		for key in row.keys():
			if not DUNGEON_KEYS.has(str(key)):
				errors.append("%s unknown key %s" % [id, key])
		if id == "" or _by_id.has(id):
			errors.append("id %s" % id)
			continue
		for key in ["name", "level_zone", "door_art", "theme", "boss", "keeper"]:
			if str(row.get(key, "")) == "":
				errors.append("%s %s" % [id, key])
		if int(row.get("level_min", 0)) < 1 or int(row.get("level_max", 0)) < int(row.get("level_min", 0)):
			errors.append("%s levels" % id)
		if int(row.get("rooms", 0)) != 2:
			errors.append("%s rooms must be 2" % id)
		var party: Variant = row.get("party", {})
		if typeof(party) != TYPE_DICTIONARY or int(party.get("min", 0)) != 1 or int(party.get("max", 0)) != 4:
			errors.append("%s party must be 1-4" % id)
		var status := str(row.get("status", ""))
		if not STATUSES.has(status):
			errors.append("%s status" % id)
		if status == "built":
			var door: Variant = row.get("door", null)
			if typeof(door) != TYPE_DICTIONARY or str(door.get("zone_id", "")) == "" or not door.has("x") or not door.has("y"):
				errors.append("%s built dungeon needs a door" % id)
			if str(row.get("run", "")) == "":
				errors.append("%s built dungeon needs a run file" % id)
		elif row.has("door") or row.has("run"):
			errors.append("%s planned dungeon has no door yet" % id)
		rows.append(row.duplicate(true))
		_by_id[id] = row.duplicate(true)


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors, "dungeons": null}
