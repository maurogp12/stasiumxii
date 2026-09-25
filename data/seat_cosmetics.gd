extends RefCounted
class_name SeatCosmetics

## Presentation-only seat cosmetics for Kestrel and Ironjaw.
## Kits, hit bands, and net payloads stay untouched.
## Flip `stasium/cosmetics/gender_palette` off to yank the tray and the custom strips.
## If that setting is absent, a mobile debug build stays on and every other build stays off.

const COSMETICS_GENDER_PALETTE := "stasium/cosmetics/gender_palette"
const PALETTES_PATH := "res://art/export_2x/characters_custom/palettes.json"

const GENDER_DEFAULT := "default"
const GENDER_ALT := "alt"
const PALETTE_LOCKED := "locked"
const GENDERS: Array[String] = [GENDER_DEFAULT, GENDER_ALT]

## UI copy. Ids stay `default` / `alt`. Do not label these M/F.
const GENDER_LABELS := {
	GENDER_DEFAULT: "Locked default",
	GENDER_ALT: "Alt",
}

## Proposed chip colors used only when palettes.json cannot be read.
const _FALLBACK_SWATCHES := {
	"kestrel/locked": ["#2a4a28", "#c4a24a"],
	"kestrel/storm": ["#2a3a55", "#9aa8b8"],
	"kestrel/ember": ["#5a2828", "#c47848"],
	"ironjaw/locked": ["#8a3a32"],
	"ironjaw/slate": ["#4a525c"],
	"ironjaw/moss": ["#3a5a38"],
}

static var _seats: Array = []
static var _doc_read: bool = false
static var _doc: Dictionary = {}


static func enabled() -> bool:
	if ProjectSettings.has_setting(COSMETICS_GENDER_PALETTE):
		return bool(ProjectSettings.get_setting(COSMETICS_GENDER_PALETTE))
	return OS.has_feature("mobile") and OS.is_debug_build()


static func set_enabled(on: bool) -> void:
	ProjectSettings.set_setting(COSMETICS_GENDER_PALETTE, on)


static func supports(class_id: String) -> bool:
	var cls := SpellKits.normalize_class_id(class_id)
	return cls == SpellKits.CLASS_KESTREL or cls == SpellKits.CLASS_IRONJAW


static func palettes_for(class_id: String) -> Array[String]:
	var cls := SpellKits.normalize_class_id(class_id)
	if cls == SpellKits.CLASS_KESTREL:
		return ["locked", "storm", "ember"]
	if cls == SpellKits.CLASS_IRONJAW:
		return ["locked", "slate", "moss"]
	return []


static func normalize_gender(gender_id: String) -> String:
	var key := gender_id.strip_edges().to_lower()
	if key == GENDER_ALT:
		return GENDER_ALT
	return GENDER_DEFAULT


static func normalize_palette(class_id: String, palette_id: String) -> String:
	var key := palette_id.strip_edges().to_lower()
	if palettes_for(class_id).has(key):
		return key
	return PALETTE_LOCKED


static func gender_label(gender_id: String) -> String:
	return str(GENDER_LABELS.get(normalize_gender(gender_id), "Locked default"))


## Palette chips show the folder id (`locked`, `storm`, `ember`, `slate`, `moss`).
static func palette_label(palette_id: String) -> String:
	return palette_id.strip_edges().to_lower()


static func make(class_id: String, gender_id: String, palette_id: String) -> Dictionary:
	var cls := SpellKits.normalize_class_id(class_id)
	return {
		"class_id": cls,
		"gender": normalize_gender(gender_id),
		"palette": normalize_palette(cls, palette_id),
	}


static func seal_hotseat(specs: Array) -> void:
	_seats = []
	for spec in specs:
		if spec is Dictionary and not (spec as Dictionary).is_empty():
			var row: Dictionary = spec
			_seats.append(make(str(row.get("class_id", "")), str(row.get("gender", "")), str(row.get("palette", ""))))
		else:
			_seats.append({})


static func clear_hotseat() -> void:
	_seats = []


## Empty when the flag is off, the seat has no pick, or the class does not match.
static func for_seat(seat: int, class_id: String) -> Dictionary:
	if not enabled():
		return {}
	if seat < 0 or seat >= _seats.size():
		return {}
	var spec: Variant = _seats[seat]
	if not (spec is Dictionary):
		return {}
	var row: Dictionary = spec
	if row.is_empty() or not supports(class_id):
		return {}
	if SpellKits.normalize_class_id(str(row.get("class_id", ""))) != SpellKits.normalize_class_id(class_id):
		return {}
	return row.duplicate(true)


static func swatch_colors(class_id: String, palette_id: String) -> Array[Color]:
	var cls := SpellKits.normalize_class_id(class_id)
	var palette := normalize_palette(cls, palette_id)
	var hexes := _hexes_from_doc(cls, palette)
	if hexes.is_empty():
		var fallback: Array = _FALLBACK_SWATCHES.get("%s/%s" % [cls, palette], [])
		for hex in fallback:
			hexes.append(str(hex))
	var colors: Array[Color] = []
	for hex in hexes:
		colors.append(Color(hex))
	return colors


static func _hexes_from_doc(class_id: String, palette_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var classes: Dictionary = _palette_doc().get("classes", {})
	var block: Variant = classes.get(class_id, {})
	if not (block is Dictionary):
		return out
	var regions: Variant = (block as Dictionary).get("regions", {})
	if not (regions is Dictionary):
		return out
	var palette: Variant = (regions as Dictionary).get(palette_id, {})
	if not (palette is Dictionary):
		return out
	var row: Dictionary = palette
	for key in ["primary_cloth", "primary_armor", "accent_wings", "accent_metal"]:
		var region: Variant = row.get(key, {})
		if not (region is Dictionary):
			continue
		var hex := str((region as Dictionary).get("hex", ""))
		if hex == "":
			continue
		out.append(hex)
		if out.size() >= 2:
			break
	return out


static func _palette_doc() -> Dictionary:
	if _doc_read:
		return _doc
	_doc_read = true
	if not FileAccess.file_exists(PALETTES_PATH):
		return _doc
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTES_PATH))
	if parsed is Dictionary:
		_doc = parsed
	return _doc
