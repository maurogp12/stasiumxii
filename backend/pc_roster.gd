extends RefCounted

## PC character roster. One file for the list, one progress file per character.
## Preload. No global class.
##
## Section 11 (Mauro, 11 Oct 2026) replaces the old armour colour channels.
## A character stores gender plus the body: face, skin, hair, eyes.
## Those values are for the world and for combat later. This package only saves them.
## Armour dye is a later premium-shop package.

const LEGACY_SAVE := "user://pc_progress.json"
const ROSTER_PATH := "user://pc_characters.json"
const SCREEN_PATH := "res://data/pc/class_screen.json"
const INDEX_PATH := "res://data/world/crosshaven/index.json"
const VERSION := 1
## Mauro confirmed five characters on 11 Oct 2026 (section 11). One constant.
const SLOT_LIMIT := 5
const NAME_MIN := 3
const NAME_MAX := 16
const MIGRATED_NAME := "Hero"
const GENDER_MALE := "m"
const GENDER_FEMALE := "f"

## Set by the character screen just before it opens the world.
## The world reads it once so a fresh launch still opens this screen,
## and a return from a dungeon does not.
static var _armed_id := ""
static var _book: Dictionary = {}


static func has_roster() -> bool:
	return FileAccess.file_exists(ROSTER_PATH)


static func progress_path(id: String) -> String:
	var clean := str(id).strip_edges()
	if clean == "" or not clean.is_valid_filename():
		return ""
	if clean.contains(".") or clean.contains("/") or clean.contains("\\"):
		return ""
	return "user://pc_progress_%s.json" % clean


static func launch_screen(character_count: int) -> String:
	return "class" if character_count <= 0 else "list"


## Player launch of the world scene opens the character screen.
## Tests add the world as a child (not the current scene) and stay in the world.
## A movie, a headless run, an armed entry, or a dungeon return stays in the world.
static func should_open_front_door(is_current_scene: bool, headless: bool, movie: String, armed_entry: String, dungeon_outcome: bool) -> bool:
	if not is_current_scene or headless or movie != "" or armed_entry != "" or dungeon_outcome:
		return false
	return true


static func arm_world_entry(id: String) -> void:
	_armed_id = str(id)


static func peek_world_entry() -> String:
	return _armed_id


static func take_world_entry() -> String:
	var id := _armed_id
	_armed_id = ""
	return id


static func crossroads_spawn() -> Dictionary:
	var parsed: Variant = {}
	if FileAccess.file_exists(INDEX_PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	var zone_id := "crosshaven_crossroads"
	var cell := Vector2i(22, 18)
	if typeof(parsed) == TYPE_DICTIONARY:
		var start: Dictionary = (parsed as Dictionary).get("start", {})
		if not start.is_empty():
			zone_id = str(start.get("zone_id", zone_id))
			cell = Vector2i(int(start.get("x", cell.x)), int(start.get("y", cell.y)))
	return {"zone_id": zone_id, "cell": cell}


static func class_book() -> Dictionary:
	if not _book.is_empty():
		return _book
	if not FileAccess.file_exists(SCREEN_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCREEN_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_book = parsed
	return _book


static func clear_book_cache() -> void:
	_book = {}


static func class_order() -> Array:
	var book := class_book()
	var order: Variant = book.get("order", [])
	return order if typeof(order) == TYPE_ARRAY else []


static func class_row(class_id: String) -> Dictionary:
	var classes: Variant = class_book().get("classes", {})
	if typeof(classes) != TYPE_DICTIONARY:
		return {}
	var row: Variant = (classes as Dictionary).get(class_id.strip_edges().to_lower(), {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


static func radar_values(class_id: String) -> Array:
	var book := class_book()
	var axes: Array = book.get("axes", [])
	var radar: Dictionary = class_row(class_id).get("radar", {})
	var out: Array = []
	for axis in axes:
		out.append(int(radar.get(str(axis), 1)))
	return out


static func default_appearance() -> Dictionary:
	var defaults: Dictionary = class_book().get("defaults", {})
	return {
		"gender": GENDER_MALE if str(defaults.get("gender", GENDER_MALE)) != GENDER_FEMALE else GENDER_FEMALE,
		"face": str(defaults.get("face", "")),
		"skin": _hex(str(defaults.get("skin", ""))),
		"hair": _hex(str(defaults.get("hair", ""))),
		"eyes": _hex(str(defaults.get("eyes", ""))),
		"hair_custom": false,
		"eyes_custom": false,
	}


static func face_options() -> Array:
	var faces: Variant = class_book().get("faces", [])
	return faces if typeof(faces) == TYPE_ARRAY else []


static func skin_options() -> Array:
	return _hex_list(class_book().get("skin", []))


static func hair_options() -> Array:
	return _hex_list(class_book().get("hair", []))


static func eye_options() -> Array:
	return _hex_list(class_book().get("eyes", []))


static func validate_appearance(raw: Dictionary) -> Dictionary:
	var face := str(raw.get("face", "")).strip_edges()
	var known_face := false
	for row in face_options():
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == face:
			known_face = true
	if not known_face:
		return _no("Pick a face.")
	var gender := str(raw.get("gender", "")).strip_edges().to_lower()
	if gender != GENDER_MALE and gender != GENDER_FEMALE:
		return _no("Pick Male or Female.")
	var skin := _hex(str(raw.get("skin", "")))
	if not skin_options().has(skin):
		return _no("Pick a skin tone.")
	var hair_custom := bool(raw.get("hair_custom", false))
	var hair := _hex(str(raw.get("hair", "")))
	if hair == "":
		return _no("Pick a hair colour.")
	if not hair_custom and not hair_options().has(hair):
		return _no("Pick a hair colour.")
	var eyes_custom := bool(raw.get("eyes_custom", false))
	var eyes := _hex(str(raw.get("eyes", "")))
	if eyes == "":
		return _no("Pick an eye colour.")
	if not eyes_custom and not eye_options().has(eyes):
		return _no("Pick an eye colour.")
	return {
		"ok": true,
		"reason": "",
		"appearance": {
			"gender": gender,
			"face": face,
			"skin": skin,
			"hair": hair,
			"eyes": eyes,
			"hair_custom": hair_custom,
			"eyes_custom": eyes_custom,
		},
	}


static func validate_name(char_name: String, others: Array, except_id: String) -> Dictionary:
	var clean := char_name.strip_edges()
	if clean.length() < NAME_MIN or clean.length() > NAME_MAX:
		return _no("Use 3 to 16 characters.")
	if not _name_chars_ok(clean):
		return _no("Use letters, spaces, apostrophes and hyphens.")
	var folded := clean.to_lower()
	for row in others:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var ch: Dictionary = row
		if str(ch.get("id", "")) == except_id:
			continue
		if str(ch.get("name", "")).to_lower() == folded:
			return _no("That name is already taken.")
	return {"ok": true, "reason": "", "name": clean}


static func load_roster() -> Dictionary:
	if not has_roster():
		return _empty_roster()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _empty_roster()
	var doc: Dictionary = parsed
	var chars: Array = []
	var raw: Variant = doc.get("characters", [])
	if typeof(raw) == TYPE_ARRAY:
		for row in raw:
			if typeof(row) == TYPE_DICTIONARY:
				chars.append(_normalize_character(row))
	var last := str(doc.get("last", ""))
	var known := false
	for ch in chars:
		if str((ch as Dictionary).get("id", "")) == last:
			known = true
	if not known:
		last = str((chars[0] as Dictionary).get("id", "")) if not chars.is_empty() else ""
	return {"version": VERSION, "last": last, "characters": chars}


static func find_character(id: String) -> Dictionary:
	for ch in load_roster()["characters"]:
		if str((ch as Dictionary).get("id", "")) == id:
			return (ch as Dictionary).duplicate(true)
	return {}


static func last_id() -> String:
	return str(load_roster().get("last", ""))


static func migrate_legacy() -> Dictionary:
	if has_roster():
		return {"ok": true, "migrated": false, "reason": "roster exists"}
	if not FileAccess.file_exists(LEGACY_SAVE):
		return {"ok": true, "migrated": false, "reason": "no legacy save"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_SAVE))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _no("The old save could not be read.")
	var doc: Dictionary = parsed
	if not _whole(doc.get("level", null)) or not _whole(doc.get("xp", null)):
		return _no("The old save has no level.")
	var Kits = load("res://data/kits.gd")
	var shown := str(doc.get("hero_class", "")).strip_edges()
	var class_id := "ironjaw"
	if shown != "" and bool(Kits.is_roster_class(shown)):
		class_id = str(Kits.normalize_class_id(shown))
	else:
		doc["hero_class"] = "Ironjaw"
	var id := "1"
	var copy := FileAccess.open(progress_path(id), FileAccess.WRITE)
	if copy == null:
		return _no("Could not write the character file.")
	copy.store_string(JSON.stringify(doc))
	var appearance := default_appearance()
	appearance["gender"] = GENDER_MALE
	var character := _character_record(id, MIGRATED_NAME, class_id, appearance, int(doc["level"]))
	var roster := {
		"version": VERSION,
		"last": id,
		"characters": [character],
	}
	if not _write(roster):
		return _no("Could not write the roster.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE))
	return {"ok": true, "migrated": true, "reason": "", "id": id}


static func create_character(char_name: String, class_id: String, appearance: Dictionary) -> Dictionary:
	var Kits = load("res://data/kits.gd")
	var key := str(Kits.normalize_class_id(class_id))
	if not bool(Kits.is_roster_class(key)):
		return _no("Unknown class.")
	var look: Dictionary = validate_appearance(appearance)
	if not bool(look.get("ok", false)):
		return look
	var doc := load_roster()
	var chars: Array = doc["characters"]
	if chars.size() >= SLOT_LIMIT:
		return _no("The roster is full.")
	var named: Dictionary = validate_name(char_name, chars, "")
	if not bool(named.get("ok", false)):
		return named
	var id := _next_id(chars)
	var character := _character_record(id, str(named["name"]), key, look["appearance"], 1)
	chars.append(character)
	doc["characters"] = chars
	doc["last"] = id
	if not _write(doc):
		return _no("Could not save the roster.")
	if not _write_fresh_progress(id, key):
		chars.pop_back()
		doc["characters"] = chars
		doc["last"] = str((chars.back() as Dictionary).get("id", "")) if not chars.is_empty() else ""
		_write(doc)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path(id)))
		return _no("Could not save the character.")
	return {"ok": true, "reason": "", "id": id, "character": character.duplicate(true)}


static func rename_character(id: String, char_name: String) -> Dictionary:
	var doc := load_roster()
	var chars: Array = doc["characters"]
	var named: Dictionary = validate_name(char_name, chars, id)
	if not bool(named.get("ok", false)):
		return named
	var found := false
	for ch in chars:
		if str((ch as Dictionary).get("id", "")) == id:
			(ch as Dictionary)["name"] = str(named["name"])
			found = true
	if not found:
		return _no("That character is gone.")
	if not _write(doc):
		return _no("Could not save the roster.")
	return {"ok": true, "reason": "", "name": str(named["name"])}


static func delete_character(id: String) -> Dictionary:
	var doc := load_roster()
	var chars: Array = []
	var found := false
	for ch in doc["characters"]:
		if str((ch as Dictionary).get("id", "")) == id:
			found = true
			continue
		chars.append(ch)
	if not found:
		return _no("That character is gone.")
	doc["characters"] = chars
	if str(doc.get("last", "")) == id:
		doc["last"] = str((chars.back() as Dictionary).get("id", "")) if not chars.is_empty() else ""
	if not _write(doc):
		return _no("Could not save the roster.")
	var path := progress_path(id)
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return {"ok": true, "reason": ""}


static func set_last(id: String) -> bool:
	var doc := load_roster()
	var known := false
	for ch in doc["characters"]:
		if str((ch as Dictionary).get("id", "")) == id:
			known = true
	if not known:
		return false
	doc["last"] = id
	return _write(doc)


static func mirror_level(id: String, level: int) -> bool:
	if not has_roster():
		return false
	var doc := load_roster()
	var found := false
	for ch in doc["characters"]:
		if str((ch as Dictionary).get("id", "")) == id:
			(ch as Dictionary)["level"] = level
			found = true
	if not found:
		return false
	return _write(doc)


static func sync_levels() -> void:
	if not has_roster():
		return
	var doc := load_roster()
	var changed := false
	for ch in doc["characters"]:
		var path := progress_path(str((ch as Dictionary).get("id", "")))
		if path == "" or not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY or not _whole((parsed as Dictionary).get("level", null)):
			continue
		var level := int((parsed as Dictionary)["level"])
		if int((ch as Dictionary).get("level", -1)) != level:
			(ch as Dictionary)["level"] = level
			changed = true
	if changed:
		_write(doc)


static func _write_fresh_progress(id: String, class_id: String) -> bool:
	var Progress = load("res://backend/pc_progress.gd")
	var hero = Progress.new()
	hero.bind_character(id)
	if not bool(hero.set_hero_class(class_id)):
		return false
	var spawn := crossroads_spawn()
	hero.note_place(str(spawn["zone_id"]), spawn["cell"])
	return FileAccess.file_exists(progress_path(id))


static func _character_record(id: String, char_name: String, class_id: String, appearance: Dictionary, level: int) -> Dictionary:
	return {
		"id": id,
		"name": char_name,
		"class_id": class_id,
		"gender": str(appearance.get("gender", GENDER_MALE)),
		"face": str(appearance.get("face", "")),
		"skin": _hex(str(appearance.get("skin", ""))),
		"hair": _hex(str(appearance.get("hair", ""))),
		"eyes": _hex(str(appearance.get("eyes", ""))),
		"hair_custom": bool(appearance.get("hair_custom", false)),
		"eyes_custom": bool(appearance.get("eyes_custom", false)),
		"created": int(Time.get_unix_time_from_system()),
		"level": level,
	}


static func _normalize_character(raw: Dictionary) -> Dictionary:
	var appearance := default_appearance()
	for key in ["gender", "face", "skin", "hair", "eyes"]:
		if raw.has(key):
			appearance[key] = raw[key]
	appearance["hair_custom"] = bool(raw.get("hair_custom", false))
	appearance["eyes_custom"] = bool(raw.get("eyes_custom", false))
	var checked: Dictionary = validate_appearance(appearance)
	if bool(checked.get("ok", false)):
		appearance = checked["appearance"]
	else:
		appearance = default_appearance()
	return {
		"id": str(raw.get("id", "")),
		"name": str(raw.get("name", MIGRATED_NAME)),
		"class_id": str(raw.get("class_id", "ironjaw")).to_lower(),
		"gender": str(appearance["gender"]),
		"face": str(appearance["face"]),
		"skin": str(appearance["skin"]),
		"hair": str(appearance["hair"]),
		"eyes": str(appearance["eyes"]),
		"hair_custom": bool(appearance["hair_custom"]),
		"eyes_custom": bool(appearance["eyes_custom"]),
		"created": int(raw.get("created", 0)),
		"level": int(raw.get("level", 1)),
	}


static func _empty_roster() -> Dictionary:
	return {"version": VERSION, "last": "", "characters": []}


static func _write(doc: Dictionary) -> bool:
	var file := FileAccess.open(ROSTER_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(doc))
	return true


static func _next_id(chars: Array) -> String:
	var best := 0
	for ch in chars:
		var text := str((ch as Dictionary).get("id", ""))
		if text.is_valid_int():
			best = maxi(best, int(text))
	return str(best + 1)


static func _hex_list(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry in raw:
		var hex := _hex(str(entry))
		if hex != "":
			out.append(hex)
	return out


static func _hex(text: String) -> String:
	var clean := text.strip_edges().to_lower()
	if clean.length() != 7 or not clean.begins_with("#"):
		return ""
	for i in range(1, 7):
		var c := clean.substr(i, 1)
		var ok := (c >= "0" and c <= "9") or (c >= "a" and c <= "f")
		if not ok:
			return ""
	return clean


static func _name_chars_ok(text: String) -> bool:
	for i in text.length():
		var c := text.substr(i, 1)
		if c == " " or c == "'" or c == "-":
			continue
		if c.to_lower() == c.to_upper():
			return false
	return true


static func _whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) == float(int(value))


static func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
