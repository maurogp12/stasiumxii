extends RefCounted

## PC world NPCs (sidecar). Preload. No global class.
## Section 4.5 at spec 06e29dc. Shops, quests, storage, travel and healing
## stay Open: the dialogue only talks.

const PATH := "res://data/world/npcs.json"
const FORMAT := "stasium.world_npcs"
const FORMAT_VERSION := 1
const ROLES: Array[String] = [
	"warden", "trader", "door_keeper", "guide", "herald", "banker", "elder",
	"smith", "fisher", "farmer", "woodcutter", "archivist", "ferry_captain",
	"forge_master", "fen_guide", "hermit", "seer", "last_watcher", "coil_engineer",
]
const FACINGS: Array[String] = ["N", "E", "S", "W"]
const DOC_KEYS: Array[String] = ["format", "format_version", "status", "npcs"]
const NPC_KEYS: Array[String] = [
	"id", "name", "role", "zone_id", "cell", "facing", "body", "lines", "status",
]


static func load_default() -> Dictionary:
	return load_path(PATH)


static func load_path(path: String) -> Dictionary:
	var doc: Variant = _read_json(path)
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail(["npcs file must be a JSON object"])
	return load_document(doc)


static func load_document(doc: Dictionary) -> Dictionary:
	var book = new()
	var errors: Array = []
	book._read(doc, errors)
	if not errors.is_empty():
		return _fail(errors)
	return {"ok": true, "reason": "", "errors": [], "npcs": book}


func for_zone(zone_id: String) -> Array:
	var found: Array = _by_zone.get(zone_id, [])
	return found.duplicate(true)


func by_id(npc_id: String) -> Dictionary:
	var found: Variant = _by_id.get(npc_id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return (found as Dictionary).duplicate(true)


func all() -> Array:
	return _list.duplicate(true)


func _read(doc: Dictionary, errors: Array) -> void:
	for key in doc.keys():
		if not DOC_KEYS.has(str(key)):
			errors.append("unknown key %s" % str(key))
	if str(doc.get("format", "")) != FORMAT:
		errors.append("format")
	if int(doc.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("format_version")
	if str(doc.get("status", "")) != "proposed":
		errors.append("status")
	var rows: Variant = doc.get("npcs", null)
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty():
		errors.append("npcs")
		return
	var seen := {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("npc row")
			continue
		var record: Dictionary = row
		for key in record.keys():
			if not NPC_KEYS.has(str(key)):
				errors.append("unknown npc key %s" % str(key))
		var npc_id := str(record.get("id", ""))
		if npc_id == "" or seen.has(npc_id):
			errors.append("id %s" % npc_id)
		seen[npc_id] = true
		if str(record.get("name", "")) == "":
			errors.append("%s name" % npc_id)
		var role := str(record.get("role", ""))
		if not ROLES.has(role):
			errors.append("%s role" % npc_id)
		if str(record.get("zone_id", "")) == "":
			errors.append("%s zone" % npc_id)
		if not FACINGS.has(str(record.get("facing", ""))):
			errors.append("%s facing" % npc_id)
		if str(record.get("body", "")) == "":
			errors.append("%s body" % npc_id)
		if str(record.get("status", "")) != "proposed":
			errors.append("%s status" % npc_id)
		var lines: Variant = record.get("lines", null)
		if typeof(lines) != TYPE_ARRAY or (lines as Array).is_empty():
			errors.append("%s lines" % npc_id)
		else:
			for line in lines:
				if typeof(line) != TYPE_STRING or str(line) == "":
					errors.append("%s line" % npc_id)
		var cell: Variant = record.get("cell", null)
		if typeof(cell) != TYPE_DICTIONARY:
			errors.append("%s cell" % npc_id)
		else:
			var at: Dictionary = cell
			if not at.has("x") or not at.has("y"):
				errors.append("%s cell" % npc_id)
			elif int(at["x"]) < 0 or int(at["y"]) < 0:
				errors.append("%s cell" % npc_id)
		if not errors.is_empty() and errors.size() > 40:
			return
		_list.append(record.duplicate(true))
		_by_id[npc_id] = record.duplicate(true)
		var zone_id := str(record.get("zone_id", ""))
		if not _by_zone.has(zone_id):
			_by_zone[zone_id] = []
		(_by_zone[zone_id] as Array).append(record.duplicate(true))


var _list: Array = []
var _by_id: Dictionary = {}
var _by_zone: Dictionary = {}


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "reason": "invalid", "errors": errors, "npcs": null}
