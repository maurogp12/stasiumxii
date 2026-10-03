extends RefCounted

## PC world flags (sidecar). Preload. No global class.
## world.regions_enabled defaults to false. While it is off, an exit or a gate
## does not reach the nine outer regions. Stand-in chunks stay loadable.

const PATH := "res://data/world/world_flags.json"
const FORMAT := "stasium.world_flags"
const FORMAT_VERSION := 1
const KEYS: Array[String] = ["format", "format_version", "regions_enabled"]


static func load_default() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return _fail(["missing %s" % PATH])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return load_document(parsed)


static func load_document(doc: Variant) -> Dictionary:
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail(["world flags must be a JSON object"])
	var raw: Dictionary = doc
	var errors: Array = []
	for key in raw.keys():
		if not KEYS.has(str(key)):
			errors.append("unknown key %s" % str(key))
	if str(raw.get("format", "")) != FORMAT:
		errors.append("format must be %s" % FORMAT)
	if int(raw.get("format_version", -1)) != FORMAT_VERSION:
		errors.append("format_version must be %d" % FORMAT_VERSION)
	if typeof(raw.get("regions_enabled", null)) != TYPE_BOOL:
		errors.append("regions_enabled must be a boolean")
	if not errors.is_empty():
		return _fail(errors)
	return {
		"ok": true,
		"reason": "",
		"errors": [],
		"regions_enabled": bool(raw["regions_enabled"]),
	}


## Missing or unreadable flags stay closed. A bad file does not open the regions.
static func regions_enabled() -> bool:
	var loaded := load_default()
	if not bool(loaded.get("ok", false)):
		return false
	return bool(loaded.get("regions_enabled", false))


static func _fail(errors: Array) -> Dictionary:
	var reason := ""
	if not errors.is_empty():
		reason = str(errors[0])
	return {"ok": false, "reason": reason, "errors": errors, "regions_enabled": false}
