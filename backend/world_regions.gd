extends RefCounted

## Phase flag for the nine outer regions. Preload. No global class.
## Default off: Crosshaven is the only region a walk or a gate can enter.

const Levels = preload("res://backend/world_levels.gd")
const Flags = preload("res://backend/world_flags.gd")

const HOME := "crosshaven"

static var _region_of: Dictionary = {}
static var _loaded := false
static var _override: Variant = null


static func enabled() -> bool:
	if _override != null:
		return bool(_override)
	return Flags.regions_enabled()


static func set_enabled(on: bool) -> void:
	_override = on


static func is_outer(zone_id: String) -> bool:
	var region := region_of(zone_id)
	return region != "" and region != HOME


static func same_region(a: String, b: String) -> bool:
	var left := region_of(a)
	var right := region_of(b)
	return left != "" and left == right


static func region_of(zone_id: String) -> String:
	_ensure()
	return str(_region_of.get(zone_id, ""))


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var loaded: Dictionary = Levels.load_default()
	if not bool(loaded.get("ok", false)):
		return
	var levels = loaded["levels"]
	for chunk in levels.by_chunk.keys():
		var zone: Dictionary = levels.by_chunk[chunk]
		var zone_id := str(zone.get("id", ""))
		_region_of[str(chunk)] = str(Levels.REGION_OF.get(zone_id, ""))
