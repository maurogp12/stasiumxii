class_name WorldMap
extends RefCounted

## Loads a region index and its zone files. Crosshaven ships at
## res://data/world/crosshaven/index.json.
## max_climb_steps is copied from the index. -1 means no climb limit (Open).

const INDEX_PATH := "res://data/world/crosshaven/index.json"
const INDEX_FORMAT := "stasium.zone_index"
const FORMAT_VERSION := 1

var region: String = ""
var start_zone: String = ""
var start_cell: Vector2i = Vector2i.ZERO
var max_climb_steps: int = -1
var adjacency: String = ""
var zones: Dictionary = {}


static func load_default() -> Dictionary:
	return load_index(INDEX_PATH)


static func load_index(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return _fail("missing_index", ["missing index %s" % path])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("invalid_index", ["index is not a JSON object"])
	var index: Dictionary = parsed
	var shape := _validate_index(index)
	if not bool(shape["ok"]):
		return shape
	var map := WorldMap.new()
	map.region = str(index["region"])
	map.start_zone = str(index["start_zone"])
	map.max_climb_steps = int(index["max_climb_steps"])
	map.adjacency = str(index["movement"]["adjacency"])
	var start: Dictionary = index["start"]
	map.start_cell = Vector2i(int(start["x"]), int(start["y"]))
	var errors: Array = []
	var base := path.get_base_dir()
	var seen := {}
	for entry in index["zones"]:
		var zone_id := str(entry["zone_id"])
		if seen.has(zone_id):
			_err(errors, "duplicate zone %s" % zone_id)
			continue
		seen[zone_id] = true
		var file_name := str(entry["file"])
		if file_name != "zones/%s.json" % zone_id:
			_err(errors, "%s file path does not match its id" % zone_id)
		var zone_path := base.path_join(file_name)
		if not FileAccess.file_exists(zone_path):
			_err(errors, "missing zone file %s" % file_name)
			continue
		var zone_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(zone_path))
		var loaded: Dictionary = WorldZone.parse(zone_doc)
		if not bool(loaded["ok"]):
			_err(errors, "%s: %s" % [zone_id, ", ".join(loaded["errors"])])
			continue
		var zone: WorldZone = loaded["zone"]
		if zone.zone_id != zone_id:
			_err(errors, "%s zone_id does not match the index" % zone_id)
		if zone.region != map.region:
			_err(errors, "%s region is %s" % [zone_id, zone.region])
		if zone.width != int(entry["width"]) or zone.height != int(entry["height"]):
			_err(errors, "%s size does not match the index" % zone_id)
		map.zones[zone_id] = zone
	if str(start["zone_id"]) != map.start_zone:
		_err(errors, "start.zone_id does not match start_zone")
	if map.zones.has(map.start_zone):
		var origin: WorldZone = map.zones[map.start_zone]
		if origin.spawn != map.start_cell:
			_err(errors, "index start does not match the start zone spawn")
	else:
		_err(errors, "start zone is not loaded")
	if not errors.is_empty():
		return _fail("invalid_index", errors)
	var topology := map.validate_topology()
	if not bool(topology["ok"]):
		return topology
	return {"ok": true, "reason": "", "errors": [], "map": map}


func zone(id: String) -> WorldZone:
	return zones.get(id, null)


func validate_topology() -> Dictionary:
	var errors: Array = []
	for zone_id in zones.keys():
		var zone: WorldZone = zones[zone_id]
		for exit_rec in zone.exits:
			var edge := str(exit_rec["edge"])
			var target := str(exit_rec["target_zone"])
			if not zones.has(target):
				_err(errors, "%s exits to unknown zone %s" % [zone_id, target])
				continue
			var other: WorldZone = zones[target]
			for link in exit_rec["links"]:
				var frm := Vector2i(int(link["from"]["x"]), int(link["from"]["y"]))
				var dest := Vector2i(int(link["to"]["x"]), int(link["to"]["y"]))
				if not other.in_bounds(dest) or not other.passable_at(dest):
					_err(errors, "%s arrival %s in %s is not passable" % [zone_id, dest, target])
					continue
				var back := other.exit_link(dest)
				var opposite := str(WorldZone.OPPOSITE_EDGE.get(edge, ""))
				if back.is_empty() or str(back["target_zone"]) != zone_id or Vector2i(int(back["x"]), int(back["y"])) != frm:
					_err(errors, "%s exit %s has no reciprocal link" % [zone_id, frm])
				elif str(back["edge"]) != opposite:
					_err(errors, "%s exit %s reciprocal edge is %s" % [zone_id, frm, back["edge"]])
	if errors.is_empty():
		return {"ok": true, "reason": "", "errors": [], "map": self}
	return _fail("bad_topology", errors)


static func _validate_index(index: Dictionary) -> Dictionary:
	var errors: Array = []
	for key in index.keys():
		if not ["format", "format_version", "region", "start_zone", "start", "max_climb_steps", "movement", "zones"].has(str(key)):
			_err(errors, "index has unknown key %s" % key)
	if str(index.get("format", "")) != INDEX_FORMAT:
		_err(errors, "index format must be %s" % INDEX_FORMAT)
	if int(index.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "index format_version must be %d" % FORMAT_VERSION)
	if str(index.get("region", "")) == "" or str(index.get("start_zone", "")) == "":
		_err(errors, "index region and start_zone are required")
	if typeof(index.get("start", null)) != TYPE_DICTIONARY:
		_err(errors, "index start must be an object")
	else:
		var start: Dictionary = index["start"]
		if not start.has("zone_id") or not start.has("x") or not start.has("y"):
			_err(errors, "index start needs zone_id, x, and y")
	if typeof(index.get("max_climb_steps", null)) != TYPE_FLOAT and typeof(index.get("max_climb_steps", null)) != TYPE_INT:
		_err(errors, "max_climb_steps must be an integer")
	elif int(index.get("max_climb_steps", -2)) < -1:
		_err(errors, "max_climb_steps below -1 is invalid")
	if typeof(index.get("movement", null)) != TYPE_DICTIONARY or str(index["movement"].get("adjacency", "")) != "ortho":
		_err(errors, "movement.adjacency must be ortho")
	if typeof(index.get("zones", null)) != TYPE_ARRAY or (index.get("zones", []) as Array).is_empty():
		_err(errors, "zones must be a non-empty array")
	else:
		for entry in index["zones"]:
			if typeof(entry) != TYPE_DICTIONARY:
				_err(errors, "zone entry must be an object")
				continue
			for key in ["zone_id", "file", "width", "height"]:
				if not (entry as Dictionary).has(key):
					_err(errors, "zone entry misses %s" % key)
	if errors.is_empty():
		return {"ok": true, "reason": "", "errors": []}
	return _fail("invalid_index", errors)


static func _err(errors: Array, message: String) -> void:
	if errors.size() < 32:
		errors.append(message)


static func _fail(reason: String, errors: Array) -> Dictionary:
	return {"ok": false, "reason": reason, "errors": errors, "map": null}
