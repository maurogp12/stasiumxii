extends RefCounted

## PC world atlas (sidecar). Preload. No global class.
## Loads every region index through WorldMap.load_index, resolves gates, and
## checks the WP4 rules. Placeholder regions may omit their index until WP5a.
## Crosshaven chunk files are not written here.

const Levels = preload("res://backend/world_levels.gd")

const INDEX_PATH := "res://data/world/world_index.json"
const GATES_PATH := "res://data/world/gates.json"
const INDEX_FORMAT := "stasium.world_index"
const GATES_FORMAT := "stasium.world_gates"
const FORMAT_VERSION := 1
const INDEX_KEYS: Array[String] = ["format", "format_version", "start_region", "regions"]
const REGION_KEYS: Array[String] = ["region", "index", "status"]
const GATES_KEYS: Array[String] = ["format", "format_version", "gates"]
const GATE_KEYS: Array[String] = ["id", "from", "to", "label", "two_way"]
const CELL_KEYS: Array[String] = ["zone_id", "x", "y"]

var start_region: String = ""
var regions: Array = []
var maps: Dictionary = {}
var gates: Array = []
var levels = null
var _by_cell: Dictionary = {}


static func load_default() -> Dictionary:
	return load_paths(INDEX_PATH, GATES_PATH)


static func load_paths(index_path: String, gates_path: String) -> Dictionary:
	var index_doc: Variant = _read_json(index_path)
	var gates_doc: Variant = _read_json(gates_path)
	if typeof(index_doc) != TYPE_DICTIONARY or typeof(gates_doc) != TYPE_DICTIONARY:
		return _fail("unreadable", ["world index and gates must be JSON objects"])
	return load_documents(index_doc, gates_doc)


static func load_documents(index_doc: Dictionary, gates_doc: Dictionary) -> Dictionary:
	var atlas = new()
	var errors: Array = []
	var level_doc: Dictionary = Levels.load_default()
	if not bool(level_doc.get("ok", false)):
		return _fail("levels", level_doc.get("errors", []))
	atlas.levels = level_doc["levels"]
	atlas._read_index(index_doc, errors)
	atlas._read_gates(gates_doc, errors)
	if not errors.is_empty():
		return _fail("invalid", errors, atlas)
	var checked: Dictionary = atlas.validate()
	if not bool(checked.get("ok", false)):
		return _fail(str(checked.get("reason", "invalid")), checked.get("errors", []), atlas)
	return {"ok": true, "reason": "", "errors": [], "atlas": atlas}


func validate() -> Dictionary:
	var errors: Array = []
	_check_regions(errors)
	_check_entries(errors)
	_check_chunks(errors)
	_check_gates(errors)
	_check_reach(errors)
	if errors.is_empty():
		return {"ok": true, "reason": "", "errors": []}
	return _fail("invalid_atlas", errors, self)


func region_of_chunk(chunk_id: String) -> String:
	if levels == null:
		return ""
	var zone: Dictionary = levels.zone_for_chunk(chunk_id)
	if zone.is_empty():
		return ""
	return str(Levels.REGION_OF.get(str(zone.get("id", "")), ""))


func entry_of(region: String) -> String:
	if region == "crosshaven":
		return "crosshaven_crossroads"
	return region + "_entry"


func gate_at(zone_id: String, cell: Vector2i) -> Dictionary:
	var key := "%s:%d:%d" % [zone_id, cell.x, cell.y]
	if not _by_cell.has(key):
		return {}
	return _by_cell[key]


func gates_from_zone(zone_id: String) -> Array:
	var rows: Array = []
	for gate in gates:
		var frm: Dictionary = gate["from"]
		if str(frm.get("zone_id", "")) == zone_id:
			rows.append(gate)
	return rows


func _chunks_in(region: String) -> Array:
	var rows: Array = []
	if levels == null or region == "":
		return rows
	for chunk_id in levels.by_chunk.keys():
		if region_of_chunk(str(chunk_id)) == region:
			rows.append(str(chunk_id))
	return rows


func map_for_chunk(chunk_id: String):
	var region := region_of_chunk(chunk_id)
	if not maps.has(region) or maps[region] == null:
		return null
	var found: WorldMap = maps[region]
	if found.zone(chunk_id) == null:
		return null
	return found


func _read_index(doc: Dictionary, errors: Array) -> void:
	_unknown(doc, INDEX_KEYS, errors, "world index")
	if str(doc.get("format", "")) != INDEX_FORMAT:
		_err(errors, "world index format must be %s" % INDEX_FORMAT)
	if int(doc.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "world index format_version must be %d" % FORMAT_VERSION)
	start_region = str(doc.get("start_region", ""))
	if start_region == "":
		_err(errors, "start_region is required")
	if typeof(doc.get("regions", null)) != TYPE_ARRAY:
		_err(errors, "regions must be an array")
		return
	var seen := {}
	for row in doc["regions"]:
		if typeof(row) != TYPE_DICTIONARY:
			_err(errors, "region must be an object")
			continue
		_unknown(row, REGION_KEYS, errors, "region")
		var region := str(row.get("region", ""))
		var path := str(row.get("index", ""))
		var status := str(row.get("status", ""))
		if region == "" or seen.has(region):
			_err(errors, "region id missing or duplicated")
			continue
		seen[region] = true
		if status != "built" and status != "placeholder":
			_err(errors, "%s status must be built or placeholder" % region)
		regions.append({"region": region, "index": path, "status": status})
		var loaded: Dictionary = WorldMap.load_index(path)
		if bool(loaded.get("ok", false)):
			var map: WorldMap = loaded["map"]
			if map.region != region:
				_err(errors, "%s index region is %s" % [region, map.region])
			maps[region] = map
		elif status == "placeholder" and not FileAccess.file_exists(path):
			maps[region] = null
		else:
			_err(errors, "%s index did not load (%s)" % [region, str(loaded.get("reason", ""))])
			maps[region] = null
	if start_region != "" and not seen.has(start_region):
		_err(errors, "start_region is not listed")


func _read_gates(doc: Dictionary, errors: Array) -> void:
	_unknown(doc, GATES_KEYS, errors, "gates")
	if str(doc.get("format", "")) != GATES_FORMAT:
		_err(errors, "gates format must be %s" % GATES_FORMAT)
	if int(doc.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "gates format_version must be %d" % FORMAT_VERSION)
	if typeof(doc.get("gates", null)) != TYPE_ARRAY:
		_err(errors, "gates must be an array")
		return
	var seen := {}
	for row in doc["gates"]:
		if typeof(row) != TYPE_DICTIONARY:
			_err(errors, "gate must be an object")
			continue
		_unknown(row, GATE_KEYS, errors, "gate")
		var gate_id := str(row.get("id", ""))
		if gate_id == "" or seen.has(gate_id):
			_err(errors, "gate id missing or duplicated")
			continue
		seen[gate_id] = true
		if typeof(row.get("two_way", null)) != TYPE_BOOL:
			_err(errors, "%s two_way must be a boolean" % gate_id)
		var frm := _cell(row.get("from", null), errors, gate_id + " from")
		var dest := _cell(row.get("to", null), errors, gate_id + " to")
		if frm.is_empty() or dest.is_empty():
			continue
		var label := str(row.get("label", ""))
		if label == "":
			_err(errors, "%s label is empty" % gate_id)
		var gate := {
			"id": gate_id,
			"from": frm,
			"to": dest,
			"label": label,
			"two_way": bool(row.get("two_way", false)),
		}
		gates.append(gate)
		var key := "%s:%d:%d" % [str(frm["zone_id"]), int(frm["x"]), int(frm["y"])]
		if _by_cell.has(key):
			_err(errors, "%s shares a from cell with another gate" % gate_id)
		else:
			_by_cell[key] = gate


func _check_regions(errors: Array) -> void:
	var wanted := {}
	for zone_id in Levels.REGION_OF.keys():
		wanted[str(Levels.REGION_OF[zone_id])] = true
	var got := {}
	for row in regions:
		got[str(row["region"])] = str(row["status"])
	for region in wanted.keys():
		if not got.has(region):
			_err(errors, "world index misses region %s" % region)
	for region in got.keys():
		if not wanted.has(region):
			_err(errors, "world index has unexpected region %s" % region)
	if str(got.get("crosshaven", "")) != "built":
		_err(errors, "crosshaven must be built")
	for region in got.keys():
		if region == "crosshaven":
			continue
		if str(got[region]) != "placeholder":
			_err(errors, "%s stays placeholder until its chunks exist" % region)


func _check_entries(errors: Array) -> void:
	var by_region := {}
	for row in regions:
		by_region[str(row["region"])] = []
	if levels == null:
		_err(errors, "level zones are missing")
		return
	for chunk_id in levels.by_chunk.keys():
		var region := region_of_chunk(str(chunk_id))
		if not by_region.has(region):
			_err(errors, "chunk %s has no world-index region" % chunk_id)
			continue
		var zone: Dictionary = levels.zone_for_chunk(str(chunk_id))
		var depth: Dictionary = zone.get("depth", {})
		if int(depth.get(chunk_id, -1)) == 0:
			(by_region[region] as Array).append(str(chunk_id))
	for region in by_region.keys():
		var entries: Array = by_region[region]
		if entries.size() != 1:
			_err(errors, "%s should have one entry chunk, found %d" % [region, entries.size()])
			continue
		var expect := entry_of(region)
		if str(entries[0]) != expect:
			_err(errors, "%s entry is %s" % [region, str(entries[0])])


func _check_chunks(errors: Array) -> void:
	if levels == null:
		return
	var count := int(levels.by_chunk.size())
	if count != 66:
		_err(errors, "expected 66 chunks in exactly one level zone, found %d" % count)
	var seen := {}
	for chunk_id in levels.by_chunk.keys():
		if seen.has(chunk_id):
			_err(errors, "chunk %s is in more than one level zone" % chunk_id)
		seen[chunk_id] = true


func _check_gates(errors: Array) -> void:
	for gate in gates:
		var frm: Dictionary = gate["from"]
		var dest: Dictionary = gate["to"]
		var from_region := region_of_chunk(str(frm["zone_id"]))
		var to_region := region_of_chunk(str(dest["zone_id"]))
		if from_region == "" or to_region == "":
			_err(errors, "%s names a chunk that is not in a level zone" % str(gate["id"]))
			continue
		if from_region == to_region:
			_err(errors, "%s stays inside %s" % [str(gate["id"]), from_region])
		if to_region != "crosshaven" and str(dest["zone_id"]) != entry_of(to_region):
			_err(errors, "%s does not land on the entry of %s" % [str(gate["id"]), to_region])
		_check_cell(frm, true, errors, str(gate["id"]) + " from")
		_check_cell(dest, false, errors, str(gate["id"]) + " to")
		_check_label(str(gate["label"]), str(dest["zone_id"]), errors, str(gate["id"]))
		if not bool(gate["two_way"]):
			_err(errors, "%s is not two-way" % str(gate["id"]))
			continue
		if _partner(gate).is_empty():
			_err(errors, "%s has no matching reverse" % str(gate["id"]))


func _check_cell(cell: Dictionary, must_edge: bool, errors: Array, label: String) -> void:
	var zone_id := str(cell["zone_id"])
	var at := Vector2i(int(cell["x"]), int(cell["y"]))
	var map: Variant = map_for_chunk(zone_id)
	if map == null:
		if must_edge and at.x != 0 and at.y != 0:
			_err(errors, "%s is not on a chunk edge" % label)
		return
	var zone: WorldZone = (map as WorldMap).zone(zone_id)
	if zone == null or not zone.in_bounds(at):
		_err(errors, "%s is out of bounds" % label)
		return
	if not zone.passable_at(at):
		_err(errors, "%s is not passable" % label)
	if must_edge and at.x != 0 and at.y != 0 and at.x != zone.width - 1 and at.y != zone.height - 1:
		_err(errors, "%s is not next to the chunk edge" % label)
	if must_edge and not zone.exit_link(at).is_empty():
		_err(errors, "%s is already a chunk exit" % label)


func _check_label(label: String, zone_id: String, errors: Array, gate_id: String) -> void:
	if levels == null:
		return
	var band: Dictionary = levels.band(zone_id)
	if band.is_empty():
		_err(errors, "%s label has no level band" % gate_id)
		return
	var want := "(%d-%d)" % [int(band["level_min"]), int(band["level_max"])]
	if not label.ends_with(want):
		_err(errors, "%s label should end with %s" % [gate_id, want])


func _partner(gate: Dictionary) -> Dictionary:
	var frm: Dictionary = gate["from"]
	var dest: Dictionary = gate["to"]
	var from_region := region_of_chunk(str(frm["zone_id"]))
	var to_region := region_of_chunk(str(dest["zone_id"]))
	for other in gates:
		if str(other["id"]) == str(gate["id"]):
			continue
		var ofrm: Dictionary = other["from"]
		var odest: Dictionary = other["to"]
		if region_of_chunk(str(ofrm["zone_id"])) != to_region:
			continue
		if region_of_chunk(str(odest["zone_id"])) != from_region:
			continue
		if not bool(other["two_way"]):
			continue
		if from_region == "crosshaven" or to_region == "crosshaven":
			if _same_cell(frm, odest) and _same_cell(dest, ofrm):
				return other
			continue
		if str(dest["zone_id"]) == entry_of(to_region) and str(odest["zone_id"]) == entry_of(from_region):
			return other
	return {}


func _check_reach(errors: Array) -> void:
	var seen := {}
	var queue: Array = []
	var cross: WorldMap = maps.get("crosshaven", null)
	if cross == null:
		_err(errors, "crosshaven is not loaded")
		return
	queue.append(cross.start_zone)
	while not queue.is_empty():
		var chunk_id := str(queue.pop_front())
		if chunk_id == "" or seen.has(chunk_id):
			continue
		seen[chunk_id] = true
		if cross.zones.has(chunk_id):
			var zone: WorldZone = cross.zones[chunk_id]
			for exit_rec in zone.exits:
				queue.append(str(exit_rec["target_zone"]))
		else:
			# Placeholder regions have no chunk exits yet (WP5a). Reaching the
			# entry reaches the region, so a gate on another of its chunks
			# still counts.
			var region := region_of_chunk(chunk_id)
			for other_id in _chunks_in(region):
				queue.append(other_id)
		for gate in gates_from_zone(chunk_id):
			queue.append(str((gate["to"] as Dictionary)["zone_id"]))
	var reached := {}
	for chunk_id in seen.keys():
		var region := region_of_chunk(str(chunk_id))
		if region != "":
			reached[region] = true
	for row in regions:
		var region := str(row["region"])
		if not reached.has(region):
			_err(errors, "%s is not reachable from the Crossroads" % region)


func _cell(value: Variant, errors: Array, label: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		_err(errors, "%s must be an object" % label)
		return {}
	var cell: Dictionary = value
	_unknown(cell, CELL_KEYS, errors, label)
	if str(cell.get("zone_id", "")) == "":
		_err(errors, "%s needs a zone_id" % label)
		return {}
	if not _whole(cell.get("x", null)) or not _whole(cell.get("y", null)):
		_err(errors, "%s needs integer x and y" % label)
		return {}
	if int(cell["x"]) < 0 or int(cell["y"]) < 0:
		_err(errors, "%s is negative" % label)
		return {}
	return {"zone_id": str(cell["zone_id"]), "x": int(cell["x"]), "y": int(cell["y"])}


static func _same_cell(a: Dictionary, b: Dictionary) -> bool:
	return str(a["zone_id"]) == str(b["zone_id"]) and int(a["x"]) == int(b["x"]) and int(a["y"]) == int(b["y"])


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _unknown(doc: Dictionary, allowed: Array, errors: Array, label: String) -> void:
	for key in doc.keys():
		if not allowed.has(str(key)):
			_err(errors, "%s has unknown key %s" % [label, str(key)])


static func _whole(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and float(value) == float(int(value)))


static func _err(errors: Array, message: String) -> void:
	errors.append(message)


static func _fail(reason: String, errors: Array, atlas = null) -> Dictionary:
	return {"ok": false, "reason": reason, "errors": errors, "atlas": atlas}
