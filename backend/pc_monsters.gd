extends RefCounted

## PC dungeon monsters (data/world/dungeon_monsters.json). Preload. No global class.
## Numbers are Proposed (WP8: propose monster HP / damage, do not make them
## final). stats_at(level) scales from the band's first level the way the
## file's `scaling` block says. check() is a pc_balance-style sanity pass.

const PATH := "res://data/world/dungeon_monsters.json"
const FORMAT := "stasium.dungeon_monsters"
const FORMAT_VERSION := 1
const DOC_KEYS: Array[String] = ["format", "format_version", "status", "notes", "scaling", "monsters"]
const MONSTER_KEYS: Array[String] = [
	"id", "name", "dungeon", "role", "level_min", "level_max", "hp", "ap", "mp", "attack", "signature", "art",
]
const ATTACK_KEYS: Array[String] = ["id", "name", "ap", "min_range", "max_range", "damage", "element"]
const SIGNATURE_KEYS: Array[String] = [
	"id", "name", "kind", "ap", "summon", "count", "first_turn", "every", "cap_alive", "cap_total",
]
## The hero side a level 1 run is checked against (CombatSim unit defaults).
const HERO_HP := 80
const HERO_AP := 6

var _by_id: Dictionary = {}
var _order: Array[String] = []
var _scaling: Dictionary = {}


static func load_default() -> Dictionary:
	return load_path(PATH)


static func load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(["monster file is missing"])
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail(["monster file must be a JSON object"])
	return load_document(doc)


static func load_document(doc: Dictionary) -> Dictionary:
	var book = new()
	var errors: Array = []
	book._read(doc, errors)
	if not errors.is_empty():
		return _fail(errors)
	return {"ok": true, "errors": [], "monsters": book}


func ids() -> Array:
	return _order.duplicate()


func has(monster_id: String) -> bool:
	return _by_id.has(monster_id)


func raw(monster_id: String) -> Dictionary:
	return (_by_id.get(monster_id, {}) as Dictionary).duplicate(true)


## Combat-ready numbers at a dungeon level, clamped to the monster's band.
func stats_at(monster_id: String, level: int) -> Dictionary:
	var row: Dictionary = _by_id.get(monster_id, {})
	if row.is_empty():
		return {}
	var lo := int(row["level_min"])
	var hi := int(row["level_max"])
	var at := clampi(level, lo, hi)
	var steps := float(at - lo)
	var hp_mult := 1.0 + float(_scaling.get("hp_per_level", 0.0)) * steps
	var dmg_mult := 1.0 + float(_scaling.get("damage_per_level", 0.0)) * steps
	var attack: Dictionary = (row["attack"] as Dictionary).duplicate(true)
	attack["damage"] = int(round(float(attack["damage"]) * dmg_mult))
	var out := {
		"monster": monster_id,
		"name": str(row["name"]),
		"level": at,
		"hp": int(round(float(row["hp"]) * hp_mult)),
		"ap": int(row["ap"]),
		"mp": int(row["mp"]),
		"attack": attack,
		"boss": str(row.get("role", "")) == "boss",
		"art": str(row.get("art", monster_id)),
		"element": str(attack.get("element", "earth")),
	}
	if row.has("signature"):
		out["signature"] = (row["signature"] as Dictionary).duplicate(true)
	return out


## Sanity pass in the pc_balance style. Not a simulator: expected damage per
## turn at the locked melee hit chance, against the hero's 80 HP.
func check(level: int = 1) -> Dictionary:
	var findings: Array = []
	var melee_hit := 0.9
	for monster_id in _order:
		var s := stats_at(monster_id, level)
		var attack: Dictionary = s["attack"]
		var swings := 0
		if int(attack["ap"]) > 0:
			swings = int(s["ap"]) / int(attack["ap"])
		var per_turn := float(swings) * float(attack["damage"]) * melee_hit
		var turns_to_kill_hero := INF if per_turn <= 0.0 else float(HERO_HP) / per_turn
		if swings < 1:
			findings.append("%s cannot afford its attack" % monster_id)
		if turns_to_kill_hero < 4.0 and not bool(s["boss"]):
			findings.append("%s kills a hero alone in under 4 turns" % monster_id)
		if int(s["mp"]) < 1:
			findings.append("%s cannot move" % monster_id)
	return {"ok": findings.is_empty(), "findings": findings}


func _read(doc: Dictionary, errors: Array) -> void:
	for key in doc.keys():
		if not DOC_KEYS.has(str(key)):
			errors.append("unknown key %s" % key)
	if str(doc.get("format", "")) != FORMAT:
		errors.append("format")
	if int(doc.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("format_version")
	if str(doc.get("status", "")) != "proposed":
		errors.append("status")
	_scaling = doc.get("scaling", {}) if typeof(doc.get("scaling", {})) == TYPE_DICTIONARY else {}
	var rows: Variant = doc.get("monsters", null)
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty():
		errors.append("monsters")
		return
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			errors.append("monster row")
			continue
		var row: Dictionary = raw_row
		var id := str(row.get("id", ""))
		for key in row.keys():
			if not MONSTER_KEYS.has(str(key)):
				errors.append("%s unknown key %s" % [id, key])
		if id == "" or _by_id.has(id):
			errors.append("id %s" % id)
			continue
		for key in ["hp", "ap", "mp", "level_min", "level_max"]:
			if int(row.get(key, 0)) <= 0:
				errors.append("%s %s" % [id, key])
		var attack: Variant = row.get("attack", null)
		if typeof(attack) != TYPE_DICTIONARY:
			errors.append("%s attack" % id)
			continue
		for key in ATTACK_KEYS:
			if not (attack as Dictionary).has(key):
				errors.append("%s attack %s" % [id, key])
		if row.has("signature"):
			var sig: Variant = row["signature"]
			if typeof(sig) != TYPE_DICTIONARY:
				errors.append("%s signature" % id)
			else:
				for key in SIGNATURE_KEYS:
					if not (sig as Dictionary).has(key):
						errors.append("%s signature %s" % [id, key])
		_by_id[id] = row.duplicate(true)
		_order.append(id)
	for id in _order:
		var row: Dictionary = _by_id[id]
		if row.has("signature"):
			var summon := str((row["signature"] as Dictionary).get("summon", ""))
			if summon != "" and not _by_id.has(summon):
				errors.append("%s summons an unknown monster %s" % [id, summon])


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors, "monsters": null}
