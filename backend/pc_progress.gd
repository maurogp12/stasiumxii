extends RefCounted

## PC hero level from 1 to 50. Curve, counter, and a level-up event only.
## Open Q3: where XP comes from, and what a level gives, are not decided.
## This script does not change stats and does not import phone level code.
## Loaded with preload. No global class.

const CURVE_PATH := "res://data/world/level_curve.json"
const SAVE_PATH := "user://pc_progress.json"
const FORMAT := "stasium.level_curve"
const FORMAT_VERSION := 1
const DOC_KEYS: Array[String] = ["format", "format_version", "status", "max_level", "xp_to_next"]

var level: int = 1
var xp: int = 0
var max_level: int = 50
var xp_to_next: Array = []
var curve_ok: bool = false


func _init() -> void:
	var curve := load_curve()
	if bool(curve.get("ok", false)):
		max_level = int(curve["max_level"])
		xp_to_next = curve["xp_to_next"]
		curve_ok = true
	read_save()


static func load_curve() -> Dictionary:
	if not FileAccess.file_exists(CURVE_PATH):
		return _fail(["missing %s" % CURVE_PATH])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CURVE_PATH))
	return parse_curve(parsed)


static func parse_curve(doc: Variant) -> Dictionary:
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail(["level curve is not a JSON object"])
	var errors: Array = []
	_check_curve(doc, errors)
	if not errors.is_empty():
		return _fail(errors)
	var steps: Array = []
	for value in (doc as Dictionary)["xp_to_next"]:
		steps.append(int(value))
	return {
		"ok": true,
		"reason": "",
		"errors": [],
		"max_level": int((doc as Dictionary)["max_level"]),
		"xp_to_next": steps,
	}


## XP added toward the next level. At level 50 further XP is kept and does not level.
## Returns one {kind: level_up, level} event per level gained. No stat payload.
func add_xp(n: int) -> Array:
	var events: Array = []
	if n <= 0:
		return events
	xp += n
	while level < max_level and level - 1 < xp_to_next.size():
		var need := int(xp_to_next[level - 1])
		if need <= 0 or xp < need:
			break
		xp -= need
		level += 1
		events.append({"kind": "level_up", "level": level})
	return events


func save() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"level": level, "xp": xp}))
	return true


## Public load from user://pc_progress.json.
## Startup calls read_save() so this file does not call Godot's global load().
func load() -> bool:
	return read_save()


func read_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var doc: Dictionary = parsed
	if not doc.has("level") or not doc.has("xp"):
		return false
	if not _whole(doc["level"]) or not _whole(doc["xp"]):
		return false
	var next_level := int(doc["level"])
	var next_xp := int(doc["xp"])
	if next_level < 1 or next_level > max_level or next_xp < 0:
		return false
	level = next_level
	xp = next_xp
	return true


static func _check_curve(doc: Dictionary, errors: Array) -> void:
	_unknown(doc, DOC_KEYS, errors, "level curve")
	if str(doc.get("format", "")) != FORMAT:
		_err(errors, "format must be %s" % FORMAT)
	if not _whole(doc.get("format_version", null)) or int(doc.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "format_version must be %d" % FORMAT_VERSION)
	if str(doc.get("status", "")) != "proposed":
		_err(errors, "status must be proposed")
	if not _whole(doc.get("max_level", null)) or int(doc.get("max_level", -1)) != 50:
		_err(errors, "max_level must be 50")
	if typeof(doc.get("xp_to_next", null)) != TYPE_ARRAY:
		_err(errors, "xp_to_next must be an array")
		return
	var steps: Array = doc["xp_to_next"]
	if steps.size() != 49:
		_err(errors, "xp_to_next must have 49 entries")
	var prev := 0
	for i in steps.size():
		var value: Variant = steps[i]
		if not _whole(value) or int(value) < 1:
			_err(errors, "xp_to_next[%d] must be a positive integer" % i)
			continue
		if int(value) <= prev:
			_err(errors, "xp_to_next is not strictly increasing")
		prev = int(value)


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


static func _err(errors: Array, message: String) -> void:
	if errors.size() < 32:
		errors.append(message)


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "reason": "invalid_level_curve", "errors": errors, "max_level": 0, "xp_to_next": []}
