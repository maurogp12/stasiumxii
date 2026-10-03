extends RefCounted

## PC level zones (sidecar stasium.level_zones v1).
## Loaded with preload. No global class: headless tests do not rebuild the class cache.
## stasium.zone files are not read or written here.

const PATH := "res://data/world/level_zones.json"
const CURVE_PATH := "res://data/world/level_curve.json"
const FORMAT := "stasium.level_zones"
const FORMAT_VERSION := 1
const DOC_KEYS: Array[String] = ["format", "format_version", "status", "zones"]
const ZONE_REQUIRED: Array[String] = ["id", "name", "level_min", "level_max", "chunks", "color", "dungeon"]
const ZONE_KEYS: Array[String] = ["id", "name", "level_min", "level_max", "chunks", "depth", "color", "dungeon"]
const ZONE_IDS: Array[String] = [
	"crosshaven_heart",
	"crosshaven_towns",
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
const REGION_OF := {
	"crosshaven_heart": "crosshaven",
	"crosshaven_towns": "crosshaven",
	"rowanvale": "rowanvale",
	"windmere": "windmere",
	"brinewake": "brinewake",
	"slagcrown": "slagcrown",
	"eastmarch_fen_edge": "eastmarch_fen_edge",
	"gloomfen_mire": "gloomfen_mire",
	"stormspire": "stormspire",
	"ashen_shardfields": "ashen_shardfields",
	"blightwood_hollow": "blightwood_hollow",
}

var source: Dictionary = {}
var zones: Array = []
var by_id: Dictionary = {}
var by_chunk: Dictionary = {}

static var _id_re: RegEx
static var _color_re: RegEx


static func load_default() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return _fail("missing_file", ["missing %s" % PATH])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parse(parsed)


static func parse(doc: Variant) -> Dictionary:
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail("invalid_level_zones", ["level zones are not a JSON object"])
	var errors: Array = []
	_check(doc, errors)
	if not errors.is_empty():
		return _fail("invalid_level_zones", errors)
	var levels = new()
	levels.source = (doc as Dictionary).duplicate(true)
	for zone in doc["zones"]:
		var copy: Dictionary = (zone as Dictionary).duplicate(true)
		copy["level_min"] = int(copy["level_min"])
		copy["level_max"] = int(copy["level_max"])
		levels.zones.append(copy)
		levels.by_id[str(copy["id"])] = copy
		for chunk in copy["chunks"]:
			levels.by_chunk[str(chunk)] = copy
	return {"ok": true, "reason": "", "errors": [], "levels": levels}


func zone_for_chunk(id: String) -> Dictionary:
	if not by_chunk.has(id):
		return {}
	return (by_chunk[id] as Dictionary).duplicate(true)


func band(id: String) -> Dictionary:
	var zone: Dictionary = {}
	if by_id.has(id):
		zone = by_id[id]
	elif by_chunk.has(id):
		zone = by_chunk[id]
	else:
		return {}
	return {
		"id": str(zone["id"]),
		"level_min": int(zone["level_min"]),
		"level_max": int(zone["level_max"]),
	}


func validate() -> Dictionary:
	var errors: Array = []
	_check(source, errors)
	if errors.is_empty():
		return {"ok": true, "reason": "", "errors": []}
	return _fail("invalid_level_zones", errors)


static func _check(doc: Dictionary, errors: Array) -> void:
	_unknown(doc, DOC_KEYS, errors, "level zones")
	if str(doc.get("format", "")) != FORMAT:
		_err(errors, "format must be %s" % FORMAT)
	if int(doc.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "format_version must be %d" % FORMAT_VERSION)
	if str(doc.get("status", "")) != "proposed":
		_err(errors, "status must be proposed")
	if typeof(doc.get("zones", null)) != TYPE_ARRAY:
		_err(errors, "zones must be an array")
		return
	var seen_ids := {}
	var seen_chunks := {}
	var seen_dungeons := {}
	var cap := curve_max_level()
	if cap < 2:
		_err(errors, "max_level could not be read from level_curve.json")
	for zone in doc["zones"]:
		if typeof(zone) != TYPE_DICTIONARY:
			_err(errors, "zone must be an object")
			continue
		_unknown(zone, ZONE_KEYS, errors, "zone")
		var complete := true
		for key in ZONE_REQUIRED:
			if not (zone as Dictionary).has(key):
				_err(errors, "zone misses %s" % key)
				complete = false
		if not complete:
			continue
		var zone_id := str(zone["id"])
		if not _is_id(zone_id):
			_err(errors, "zone id is invalid")
		elif not ZONE_IDS.has(zone_id):
			_err(errors, "unexpected zone %s" % zone_id)
		elif seen_ids.has(zone_id):
			_err(errors, "duplicate zone %s" % zone_id)
		else:
			seen_ids[zone_id] = true
		if typeof(zone["name"]) != TYPE_STRING or str(zone["name"]) == "":
			_err(errors, "name must be a non-empty string")
		var lo: Variant = zone["level_min"]
		var hi: Variant = zone["level_max"]
		if cap >= 2 and not _in_range(lo, 1, cap):
			_err(errors, "%s level_min out of range" % zone_id)
		if cap >= 2 and not _in_range(hi, 1, cap):
			_err(errors, "%s level_max out of range" % zone_id)
		if _whole(lo) and _whole(hi) and int(lo) > int(hi):
			_err(errors, "%s level_min above level_max" % zone_id)
		if zone_id == "gloomfen_mire" and _whole(lo) and int(lo) < 30:
			_err(errors, "gloomfen_mire starts below 30")
		if zone_id == "blightwood_hollow" and _whole(lo) and int(lo) < 45:
			_err(errors, "blightwood_hollow starts below 45")
		if zone_id == "stormspire" and _whole(lo) and _whole(hi) and (int(lo) != 35 or int(hi) != 40):
			_err(errors, "stormspire must be 35-40")
		if typeof(zone["color"]) != TYPE_STRING or _color_pattern().search(str(zone["color"])) == null:
			_err(errors, "%s color must be #rrggbb" % zone_id)
		var dungeon := str(zone["dungeon"])
		if typeof(zone["dungeon"]) != TYPE_STRING or not _is_id(dungeon):
			_err(errors, "%s dungeon id is invalid" % zone_id)
		elif seen_dungeons.has(dungeon):
			_err(errors, "duplicate dungeon %s" % dungeon)
		else:
			seen_dungeons[dungeon] = true
		if typeof(zone["chunks"]) != TYPE_ARRAY:
			_err(errors, "%s chunks must be an array" % zone_id)
			continue
		for chunk in zone["chunks"]:
			var chunk_id := str(chunk)
			if typeof(chunk) != TYPE_STRING or not _is_id(chunk_id):
				_err(errors, "chunk id is invalid")
				continue
			if seen_chunks.has(chunk_id):
				_err(errors, "duplicate chunk %s" % chunk_id)
			else:
				seen_chunks[chunk_id] = zone_id
		_check_depth(zone, zone_id, errors)
	for zone_id in ZONE_IDS:
		if not seen_ids.has(zone_id):
			_err(errors, "missing zone %s" % zone_id)
	## Chunks may be declared before their region index exists (WP5).
	## Every chunk that does exist in a region index must belong to one zone.
	var indexed := _region_chunks(errors)
	for chunk_id in indexed.keys():
		if not seen_chunks.has(chunk_id):
			_err(errors, "chunk %s is not in a level zone" % chunk_id)
	for chunk_id in seen_chunks.keys():
		if indexed.has(chunk_id):
			continue
		if not _wp5a_name(str(seen_chunks[chunk_id]), str(chunk_id)):
			_err(errors, "unbuilt chunk %s must use a WP5a name" % chunk_id)


## Proposed. When present, depth covers exactly this zone's chunks, 0..7.
## An `_entry` chunk, and the Crossroads, are 0. An `_door` chunk is the deepest.
static func _check_depth(zone: Dictionary, zone_id: String, errors: Array) -> void:
	if not zone.has("depth"):
		return
	if typeof(zone["depth"]) != TYPE_DICTIONARY:
		_err(errors, "%s depth must be an object" % zone_id)
		return
	if typeof(zone.get("chunks", null)) != TYPE_ARRAY:
		return
	var depth: Dictionary = zone["depth"]
	var chunks: Array = zone["chunks"]
	var known := {}
	for chunk in chunks:
		known[str(chunk)] = true
	var max_depth := -1
	var door_depth := -1
	var has_door := false
	for key in depth.keys():
		var chunk_id := str(key)
		if not known.has(chunk_id):
			_err(errors, "%s depth has unknown chunk %s" % [zone_id, chunk_id])
		if not _in_range(depth[key], 0, 7):
			_err(errors, "%s depth %s is outside 0-7" % [zone_id, chunk_id])
	for chunk in chunks:
		var chunk_id := str(chunk)
		if not depth.has(chunk_id):
			_err(errors, "%s depth misses %s" % [zone_id, chunk_id])
			continue
		if not _whole(depth[chunk_id]):
			continue
		var step := int(depth[chunk_id])
		if step > max_depth:
			max_depth = step
		if chunk_id.ends_with("_entry") or chunk_id == "crosshaven_crossroads":
			if step != 0:
				_err(errors, "%s entry depth must be 0" % chunk_id)
		if chunk_id.ends_with("_door"):
			has_door = true
			door_depth = step
	if has_door and door_depth >= 0 and door_depth != max_depth:
		_err(errors, "%s door chunk is not the deepest" % zone_id)


static func curve_max_level() -> int:
	if not FileAccess.file_exists(CURVE_PATH):
		return -1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CURVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	var value: Variant = (parsed as Dictionary).get("max_level", null)
	if not _whole(value) or int(value) < 2:
		return -1
	return int(value)


## Unbuilt ids follow WP5a: <region>_entry, <region>_door, <region>_hub, <region>_<name>.
static func _wp5a_name(zone_id: String, chunk_id: String) -> bool:
	var region := str(REGION_OF.get(zone_id, ""))
	if region == "":
		return false
	var prefix := region + "_"
	if not chunk_id.begins_with(prefix):
		return false
	return _is_id(chunk_id.substr(prefix.length()))


static func _region_chunks(errors: Array) -> Dictionary:
	var found := {}
	var dir := DirAccess.open("res://data/world")
	if dir == null:
		_err(errors, "data/world cannot be opened")
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			var index_path := "res://data/world/%s/index.json" % name
			if FileAccess.file_exists(index_path):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
				if typeof(parsed) != TYPE_DICTIONARY:
					_err(errors, "region index %s is not a JSON object" % name)
				elif str((parsed as Dictionary).get("format", "")) == "stasium.zone_index":
					for entry in (parsed as Dictionary).get("zones", []):
						if typeof(entry) == TYPE_DICTIONARY:
							var chunk_id := str((entry as Dictionary).get("zone_id", ""))
							if chunk_id != "":
								found[chunk_id] = name
		name = dir.get_next()
	dir.list_dir_end()
	return found


static func _unknown(doc: Dictionary, allowed: Array, errors: Array, label: String) -> void:
	for key in doc.keys():
		if not allowed.has(str(key)):
			_err(errors, "%s has unknown key %s" % [label, key])


static func _whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) == float(int(value))


static func _in_range(value: Variant, low: int, high: int) -> bool:
	return _whole(value) and int(value) >= low and int(value) <= high


static func _is_id(text: String) -> bool:
	return text != "" and _id_pattern().search(text) != null


static func _id_pattern() -> RegEx:
	if _id_re == null:
		_id_re = RegEx.new()
		_id_re.compile("^[a-z][a-z0-9_]*$")
	return _id_re


static func _color_pattern() -> RegEx:
	if _color_re == null:
		_color_re = RegEx.new()
		_color_re.compile("^#[0-9a-fA-F]{6}$")
	return _color_re


static func _err(errors: Array, message: String) -> void:
	if errors.size() < 32:
		errors.append(message)


static func _fail(reason: String, errors: Array) -> Dictionary:
	return {"ok": false, "reason": reason, "errors": errors, "levels": null}
