extends RefCounted

## Visible gear (paper doll), PC. Which art strips a hero draws for the gear
## parts it wears, and the loaders for those strips.
##
## Data: data/pc/gear_looks.json (slots, stack order per art facing, the
## classes that draw a paper-doll base, the sets that have looks). Art and
## numbers: units/pc_gear_specs.gd, built by build_tools/pc_gear/.
##
## A class with a paper-doll base draws its unarmoured body. With nothing worn
## that is ONE sheet per kind (the "base" strip, the same cost as a locked
## look). Once a part is worn, the body is drawn as one strip per slot group
## (weapon, head, chest, legs, boots, plus the bare hands "skin"), and each
## slot with a worn look draws the look's strip instead of the base strip of
## that slot, so the tunic or trousers are never drawn under armour. Strips
## have the same cells, pivots and frame counts as the body; the game stacks
## them in "stack" order (strips ending in _back first: what lies behind the
## body, e.g. the far arm in the front view).
##
## Worn parts are mobile gear part ids "<family>.<slot>" (backend/gear_bag.gd
## on origin/mobile). A part draws the strip "<family>_<slot>" when its family
## is a set of that class in the data and the build made the strip; a part
## with no strip draws nothing and the base of that slot shows.
## Only the strips of the facing and kind on screen are loaded, on demand.

const SPECS := preload("res://units/pc_gear_specs.gd")
const PAINTED := preload("res://units/painted_looks.gd")
const DATA_PATH := "res://data/pc/gear_looks.json"
## Meta key on each strip cell: [class, strip, kind, letter, index].
const KEY_META := "gear_key"

static var _doc = null
static var _sheets: Dictionary = {}
static var _cells: Dictionary = {}
## Sheets loaded since the last clear_cache (tests: only worn strips load).
static var loaded_paths: Array[String] = []


static func clear_cache() -> void:
	_doc = null
	_sheets.clear()
	_cells.clear()
	loaded_paths.clear()


static func doc() -> Dictionary:
	if _doc == null:
		_doc = {}
		if FileAccess.file_exists(DATA_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
			if parsed is Dictionary:
				_doc = parsed
	return _doc


static func slots() -> Array:
	return doc().get("slots", ["weapon", "head", "chest", "legs", "boots"])


static func _class_row(class_id: String) -> Dictionary:
	var row: Variant = (doc().get("classes", {}) as Dictionary).get(class_id.strip_edges().to_lower(), {})
	return row if row is Dictionary else {}


## True when this class draws the paper-doll base (data on and art built).
static func base_enabled(class_id: String) -> bool:
	var cls := class_id.strip_edges().to_lower()
	return bool(_class_row(cls).get("enabled", false)) and SPECS.SPECS.has(cls) and SPECS.STRIPS.has(cls)


static func has_strip(class_id: String, strip: String) -> bool:
	var row: Variant = (SPECS.STRIPS.get(class_id.strip_edges().to_lower(), {}) as Dictionary).get(strip, {})
	return row is Dictionary and not (row as Dictionary).is_empty()


## The look strip of a worn part id, or "" when it has no art for this class.
## Accepts "family.slot" (mobile part ids) and "family_slot".
static func strip_of_part(class_id: String, part_id: String) -> String:
	var cls := class_id.strip_edges().to_lower()
	var pid := part_id.strip_edges().to_lower()
	var cut := pid.rfind(".")
	if cut < 0:
		cut = pid.rfind("_")
	if cut <= 0:
		return ""
	var family := pid.substr(0, cut)
	var slot := pid.substr(cut + 1)
	if not slots().has(slot):
		return ""
	var set_row: Variant = (doc().get("sets", {}) as Dictionary).get(family, {})
	if not (set_row is Dictionary) or str((set_row as Dictionary).get("class", "")) != cls:
		return ""
	var strip := "%s_%s" % [family, slot]
	return strip if has_strip(cls, strip) else ""


## slot -> look strip for the worn parts. `worn` is a Dictionary slot -> part
## id (mobile loadout shape) or an Array of part ids. Parts without art drop out.
static func looks_for(class_id: String, worn) -> Dictionary:
	var out := {}
	if not base_enabled(class_id):
		return out
	var ids: Array = []
	if worn is Dictionary:
		ids = (worn as Dictionary).values()
	elif worn is Array:
		ids = worn
	for raw in ids:
		var strip := strip_of_part(class_id, str(raw))
		if strip == "":
			continue
		var slot := strip.substr(strip.rfind("_") + 1)
		out[slot] = strip
	return out


## The strips to draw for an art facing ("S" or "E"), bottom to top, given
## slot -> look strip. Empty when nothing is worn: the single base sheet draws.
static func stack_for(class_id: String, looks: Dictionary, art: String) -> Array[String]:
	var out: Array[String] = []
	if looks.is_empty() or not base_enabled(class_id):
		return out
	var cls := class_id.strip_edges().to_lower()
	var base_strips: Dictionary = _class_row(cls).get("base_strips", {})
	var order: Array = (doc().get("stack", {}) as Dictionary).get(art, [])
	for suffix in ["_back", ""]:
		for group in order:
			var strip := str(looks.get(group, base_strips.get(group, "")))
			if strip == "":
				continue
			if has_strip(cls, strip + suffix):
				out.append(strip + suffix)
	return out


static func base_strip(class_id: String) -> String:
	return str(_class_row(class_id).get("base", "base"))


static func spec(class_id: String, kind: String) -> Dictionary:
	var row: Variant = SPECS.SPECS.get(class_id.strip_edges().to_lower(), {})
	if not (row is Dictionary):
		return {}
	var s: Variant = (row as Dictionary).get(kind, {})
	return s if s is Dictionary else {}


static func world(class_id: String) -> Dictionary:
	var row: Variant = SPECS.WORLD.get(class_id.strip_edges().to_lower(), {})
	return row if row is Dictionary else {}


## res:// path of a strip sheet. Strip "x_back" lives in folder "x".
static func sheet_path(class_id: String, strip: String, kind: String, art: String) -> String:
	var cls := class_id.strip_edges().to_lower()
	var folder := strip.trim_suffix("_back")
	return "%s%s/%s_%s_%s_%s.png" % [str(_class_row(cls).get("root", "")), folder, cls, strip, kind, art]


## A strip sheet (S or E, unmirrored), or null when it is not on disk or the
## wrong size. Loaded on first use only.
static func sheet(class_id: String, strip: String, kind: String, art: String) -> Texture2D:
	var cls := class_id.strip_edges().to_lower()
	var path := sheet_path(cls, strip, kind, art)
	if _sheets.has(path):
		var hit: Variant = _sheets[path]
		return hit if hit is Texture2D else null
	var tex: Texture2D = null
	var facings: Variant = ((SPECS.STRIPS.get(cls, {}) as Dictionary).get(strip, {}) as Dictionary).get(kind, [])
	var s := spec(cls, kind)
	var cell: Vector2i = s.get("cell", Vector2i.ZERO)
	var count := int(s.get("frames", 0))
	if facings is Array and (facings as Array).has(art) and cell.x > 0 and ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is Texture2D and (loaded as Texture2D).get_width() == cell.x * count and (loaded as Texture2D).get_height() == cell.y:
			tex = loaded
			loaded_paths.append(path)
	_sheets[path] = tex if tex != null else false
	return tex


## Cells of a strip for a pawn letter (mirrored copy for s and w), each with
## the cell pivot and KEY_META. [] when the strip has no art there.
static func cells(class_id: String, strip: String, kind: String, letter: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var cls := class_id.strip_edges().to_lower()
	var key := "%s|%s|%s|%s" % [cls, strip, kind, letter]
	if _cells.has(key):
		out.assign(_cells[key])
		return out
	var src := sheet(cls, strip, kind, PAINTED.art_letter(letter))
	var s := spec(cls, kind)
	if src != null:
		out = PAINTED.cut_cells(src, s.get("cell", Vector2i.ZERO), int(s.get("frames", 0)), PAINTED.pivot_from(s, letter), PAINTED.mirrored(letter))
		for i in out.size():
			out[i].set_meta(KEY_META, [cls, strip, kind, letter, i])
	_cells[key] = out
	return out


## Dev / pilot source of worn parts until the PC gear bag drives this: the
## command line `-- --gear-parts=cragmaw.head,cragmaw.chest` or set_worn_parts.
static var _worn = null


static func worn_parts() -> Array:
	if _worn == null:
		_worn = []
		for arg in OS.get_cmdline_user_args():
			var a := str(arg)
			if a.begins_with("--gear-parts="):
				for p in a.trim_prefix("--gear-parts=").split(",", false):
					(_worn as Array).append(p.strip_edges())
	return (_worn as Array).duplicate()


static func set_worn_parts(parts: Array) -> void:
	_worn = parts.duplicate()
