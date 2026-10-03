extends RefCounted

## Crypto Coins, set parts and Mystery Boxes (spec 4.9, WP14).
## Preload. No global class. Rolls are pure: the same seed returns the same
## drop. Wallet and inventory live on pc_progress.gd. Five-part effects are
## stored and not applied.

const PATH := "res://data/world/rewards.json"
const Levels := preload("res://backend/world_levels.gd")
const FORMAT := "stasium.world_rewards"
const FORMAT_VERSION := 1
const STATS: Array[String] = ["Mastery", "Vitality", "Swift", "Resist"]
const DOC_KEYS: Array[String] = [
	"format", "format_version", "status", "notes", "coins", "carry", "weights",
	"class_bias", "world_part_chance", "classes", "set_slots", "equip_slots",
	"rare_full", "rarity_colors", "mission_ranks", "box",
	"dungeon_rare_by_stars", "dungeon_box_by_stars", "guaranteed_split",
	"sets", "items", "zones", "dungeons",
]

var _doc: Dictionary = {}
var _sets: Array = []
var _set_by_id: Dictionary = {}
var _items: Dictionary = {}
var _zones: Dictionary = {}
var _dungeons: Dictionary = {}
var _levels = null


static func load_default() -> Dictionary:
	return load_path(PATH)


static func load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(["missing %s" % path])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail(["rewards file must be a JSON object"])
	return load_document(parsed)


static func load_document(doc: Variant) -> Dictionary:
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail(["rewards file must be a JSON object"])
	var book = new()
	var errors: Array = []
	book._read(doc, errors)
	if not errors.is_empty():
		return _fail(errors)
	var levels_loaded: Dictionary = Levels.load_default()
	if bool(levels_loaded.get("ok", false)):
		book._levels = levels_loaded["levels"]
	return {"ok": true, "reason": "", "errors": [], "rewards": book}


func roll(source: String, context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var coins := _coins_for(source, context, rng)
	var items: Array = []
	if source == "mission" and _is_tenth(context):
		items.append(_box_item())
	elif source == "mission":
		_roll_mission(context, rng, items)
	elif source == "dungeon":
		_roll_dungeon(context, rng, items)
	elif source == "world":
		_roll_world(context, rng, items)
	return {"coins": coins, "items": items, "source": source}


func open_box(context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rows: Array = _doc["box"]
	var x := rng.randf()
	var acc := 0.0
	var chosen: Dictionary = {}
	for row in rows:
		var entry: Dictionary = row
		acc += float(entry["chance"])
		if x < acc:
			chosen = entry
			break
	if chosen.is_empty() and not rows.is_empty():
		chosen = rows[rows.size() - 1]
	if str(chosen.get("kind", "")) == "coins":
		var band := _mission_band(int(context.get("level", 1)))
		var rolled := rng.randi_range(int(band["min"]), int(band["max"]))
		var coins := rolled * int(_doc["coins"]["box_times_mission"])
		return {"coins": coins, "items": []}
	var part_id := _pick_box_part(context, rng)
	if part_id == "":
		var band_fallback := _mission_band(int(context.get("level", 1)))
		var fallback := rng.randi_range(int(band_fallback["min"]), int(band_fallback["max"]))
		return {"coins": fallback * int(_doc["coins"]["box_times_mission"]), "items": []}
	return {
		"coins": 0,
		"items": [{
			"item_id": part_id,
			"rarity": str(chosen.get("rarity", "regular")),
			"count": 1,
		}],
	}


func pick_class(rng: RandomNumberGenerator, hero: String, classes: Array) -> String:
	if classes.is_empty():
		return hero
	if rng.randf() < float(_doc["class_bias"]) and classes.has(hero):
		return hero
	var others: Array = []
	for entry in classes:
		if str(entry) != hero:
			others.append(str(entry))
	if others.is_empty():
		return hero
	return str(others[rng.randi() % others.size()])


func item(item_id: String) -> Dictionary:
	var found: Variant = _items.get(item_id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return (found as Dictionary).duplicate(true)


func set_by_id(set_id: String) -> Dictionary:
	var found: Variant = _set_by_id.get(set_id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return (found as Dictionary).duplicate(true)


func sets() -> Array:
	return _sets.duplicate(true)


func dungeons() -> Array:
	var rows: Array = []
	for key in _dungeons.keys():
		rows.append((_dungeons[key] as Dictionary).duplicate(true))
	return rows


func carry_rules() -> Dictionary:
	return (_doc["carry"] as Dictionary).duplicate(true)


func can_wear(item_id: String, rarity: String, level: int, hero_class: String) -> Dictionary:
	var def := item(item_id)
	if def.is_empty():
		return {"ok": false, "reason": "unknown item"}
	if str(def.get("slot", "")) == "":
		return {"ok": false, "reason": "not equipment"}
	if int(def.get("min_level", 1)) > level:
		return {"ok": false, "reason": "level"}
	var classes: Array = def.get("classes", [])
	if not classes.is_empty() and not classes.has(hero_class):
		return {"ok": false, "reason": "class"}
	var allowed: Array = def.get("rarities", [])
	if not allowed.has(rarity):
		return {"ok": false, "reason": "rarity"}
	return {"ok": true, "reason": ""}


func weight_of(item_id: String) -> int:
	var def := item(item_id)
	return int(def.get("weight", 0))


func stacks(item_id: String) -> bool:
	var def := item(item_id)
	return bool(def.get("stack", false))


## Part stats plus 2-part and 3-part bonuses. Five-part texts are reported
## and not added. A full Rare class set of the approved tier adds AP or MP
## once the hero has chosen.
func gear_for(equipped: Dictionary, _hero_class: String, rare_choice: String) -> Dictionary:
	var stats := {"Mastery": 0, "Vitality": 0, "Swift": 0, "Resist": 0}
	var counts: Dictionary = {}
	var epic := ""
	var relic := ""
	for slot in equipped.keys():
		var inst: Dictionary = equipped[slot]
		var def := item(str(inst.get("item_id", "")))
		if def.is_empty():
			continue
		var rarity := str(inst.get("rarity", "regular"))
		_add_block(stats, _stat_block(def, rarity))
		var set_id := str(def.get("set_id", ""))
		if set_id != "":
			if not counts.has(set_id):
				counts[set_id] = {"count": 0, "rares": 0}
			counts[set_id]["count"] = int(counts[set_id]["count"]) + 1
			if rarity == "rare":
				counts[set_id]["rares"] = int(counts[set_id]["rares"]) + 1
		if rarity == "epic" or str(def.get("rarity", "")) == "epic":
			epic = str(def.get("name", ""))
		if rarity == "relic" or str(def.get("rarity", "")) == "relic":
			relic = str(def.get("name", ""))
	var ap := 0
	var mp := 0
	var shown: Array = []
	var rare_full: Dictionary = _doc.get("rare_full", {})
	for set_id in counts.keys():
		var row: Dictionary = counts[set_id]
		var set_def := set_by_id(str(set_id))
		if set_def.is_empty():
			continue
		var count := int(row["count"])
		var bonuses: Dictionary = set_def.get("bonuses", {})
		if count >= 2 and typeof(bonuses.get("2", null)) == TYPE_DICTIONARY:
			_add_block(stats, bonuses["2"])
		if count >= 3 and typeof(bonuses.get("3", null)) == TYPE_DICTIONARY:
			_add_block(stats, bonuses["3"])
		var five: Dictionary = {}
		if typeof(bonuses.get("5", null)) == TYPE_DICTIONARY:
			five = bonuses["5"]
		if count >= 5 and str(set_def.get("kind", "")) == "class" and int(set_def.get("tier", 0)) == int(rare_full.get("tier", -1)) and int(row["rares"]) >= 5:
			if rare_choice == "ap":
				ap += int(rare_full.get("ap", 0))
			elif rare_choice == "mp":
				mp += int(rare_full.get("mp", 0))
		shown.append({
			"id": str(set_id),
			"name": str(set_def.get("name", "")),
			"count": count,
			"five_applies": false,
			"five_text": str(five.get("text", "")),
		})
	return {
		"stats": stats,
		"ap": ap,
		"mp": mp,
		"sets": shown,
		"epic": epic,
		"relic": relic,
	}


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
	if typeof(doc.get("sets", null)) != TYPE_ARRAY:
		errors.append("sets")
		return
	_doc = doc
	_sets = doc["sets"]
	var seen := {}
	var part_seen := {}
	for row in _sets:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("set row")
			continue
		var set_def: Dictionary = row
		var set_id := str(set_def.get("id", ""))
		if set_id == "" or seen.has(set_id):
			errors.append("set id %s" % set_id)
			continue
		seen[set_id] = true
		_set_by_id[set_id] = set_def
		var budget := int(set_def.get("budget", -1))
		var stats: Dictionary = set_def.get("stats", {})
		if _sum_stats(stats.get("regular", {})) != budget:
			errors.append("budget %s" % set_id)
		var rare_expect := int(round(1.5 * float(budget))) + 1
		if _sum_stats(stats.get("rare", {})) != rare_expect:
			errors.append("rare budget %s" % set_id)
		var five: Dictionary = (set_def.get("bonuses", {}) as Dictionary).get("5", {})
		if bool(five.get("applies", true)):
			errors.append("five-part applies %s" % set_id)
		var parts: Array = set_def.get("parts", [])
		if parts.size() != 5:
			errors.append("parts %s" % set_id)
		for part in parts:
			var piece: Dictionary = part
			var part_id := str(piece.get("id", ""))
			if part_id == "" or part_seen.has(part_id):
				errors.append("part id %s" % part_id)
				continue
			part_seen[part_id] = true
			_items[part_id] = {
				"id": part_id,
				"name": str(piece.get("name", part_id)),
				"category": "equipment",
				"weight": int((_doc["weights"] as Dictionary).get("equipment", 10)),
				"stack": false,
				"slot": str(piece.get("slot", "")),
				"min_level": int(set_def.get("tier", 1)),
				"classes": (set_def.get("classes", []) as Array).duplicate(),
				"rarity": "",
				"rarities": ["regular", "rare"],
				"set_id": set_id,
				"stats": (stats as Dictionary).duplicate(true),
				"effect": {"applies": false, "text": ""},
				"drop": "rolled",
			}
	var box_sum := 0.0
	for row in doc.get("box", []):
		box_sum += float((row as Dictionary).get("chance", 0))
	if absf(box_sum - 1.0) > 0.001:
		errors.append("box chances")
	for row in doc.get("mission_ranks", []):
		var rank: Dictionary = row
		var total := float(rank.get("regular", 0)) + float(rank.get("rare", 0)) + float(rank.get("box", 0))
		if total > 1.0 + 0.001:
			errors.append("mission rank %s" % str(rank.get("rank", "")))
	var split: Dictionary = doc.get("guaranteed_split", {})
	var split_sum := float(split.get("dungeon_set", 0)) + float(split.get("class_set", 0))
	if absf(split_sum - 1.0) > 0.001:
		errors.append("guaranteed split")
	_zones = doc.get("zones", {})
	for row in doc.get("dungeons", []):
		var dungeon: Dictionary = row
		var dung_id := str(dungeon.get("id", ""))
		if dung_id == "" or _dungeons.has(dung_id):
			errors.append("dungeon %s" % dung_id)
			continue
		_dungeons[dung_id] = dungeon
	for row in doc.get("items", []):
		var loose: Dictionary = row
		var item_id := str(loose.get("id", ""))
		if item_id == "" or _items.has(item_id):
			errors.append("item %s" % item_id)
			continue
		var copy := loose.duplicate(true)
		var fixed := str(copy.get("rarity", ""))
		if fixed == "":
			copy["rarities"] = ["regular"]
		else:
			copy["rarities"] = [fixed]
		_items[item_id] = copy


func _coins_for(source: String, context: Dictionary, rng: RandomNumberGenerator) -> int:
	var coins_doc: Dictionary = _doc["coins"]
	if source == "dungeon":
		var dungeon := _dungeon(str(context.get("dungeon_id", "")))
		var at := int(dungeon.get("coin_level", context.get("level", 1)))
		var stars := maxi(int(context.get("stars", 1)), 1)
		return _world_coins(at) * int(coins_doc["dungeon_times_world"]) * stars
	if source == "mission":
		var band := _mission_band(int(context.get("level", 1)))
		return rng.randi_range(int(band["min"]), int(band["max"]))
	return _world_coins(int(context.get("level", 1)))


func _world_coins(level: int) -> int:
	var coins_doc: Dictionary = _doc["coins"]
	return int(round(float(coins_doc["world_base"]) + float(coins_doc["world_per_level"]) * float(level)))


func _mission_band(level: int) -> Dictionary:
	var rows: Array = _doc["coins"]["mission_tiers"]
	var chosen: Dictionary = rows[0]
	for row in rows:
		var band: Dictionary = row
		if level >= int(band["level_min"]) and level <= int(band["level_max"]):
			return band
		if level >= int(band["level_min"]):
			chosen = band
	return chosen


func _rank_for(finished: int) -> Dictionary:
	var rows: Array = _doc["mission_ranks"]
	var chosen: Dictionary = rows[0]
	for row in rows:
		var rank: Dictionary = row
		var high := int(rank["finished_max"])
		if finished >= int(rank["finished_min"]) and (high < 0 or finished <= high):
			return rank
		if finished >= int(rank["finished_min"]):
			chosen = rank
	return chosen


func _is_tenth(context: Dictionary) -> bool:
	var index := int(context.get("missions_finished", 0)) + 1
	return index > 0 and index % 10 == 0


func _roll_world(context: Dictionary, rng: RandomNumberGenerator, items: Array) -> void:
	if rng.randf() >= float(_doc["world_part_chance"]):
		return
	var set_def := _pick_zone_set(context, "world", rng)
	if set_def.is_empty():
		return
	items.append(_part_drop(set_def, "regular", rng))


func _roll_mission(context: Dictionary, rng: RandomNumberGenerator, items: Array) -> void:
	var rank := _rank_for(int(context.get("missions_finished", 0)))
	var box_p := float(rank.get("box", 0))
	var rare_p := float(rank.get("rare", 0))
	var reg_p := float(rank.get("regular", 0))
	var x := rng.randf()
	var rarity := ""
	if x < box_p:
		items.append(_box_item())
		return
	if x < box_p + rare_p:
		rarity = "rare"
	elif x < box_p + rare_p + reg_p:
		rarity = "regular"
	else:
		return
	var set_def := _pick_zone_set(context, "mission", rng)
	if set_def.is_empty():
		return
	items.append(_part_drop(set_def, rarity, rng))


func _roll_dungeon(context: Dictionary, rng: RandomNumberGenerator, items: Array) -> void:
	var dungeon := _dungeon(str(context.get("dungeon_id", "")))
	if dungeon.is_empty():
		return
	var regular := _part_drop(_dungeon_part_set(dungeon, context, rng), "regular", rng)
	if str(regular.get("item_id", "")) != "":
		items.append(regular)
	var stars := str(maxi(int(context.get("stars", 1)), 1))
	var rare_p := float((_doc["dungeon_rare_by_stars"] as Dictionary).get(stars, 0))
	if rng.randf() < rare_p:
		var rare_drop := _part_drop(_dungeon_part_set(dungeon, context, rng), "rare", rng)
		if str(rare_drop.get("item_id", "")) != "":
			items.append(rare_drop)
	var box_p := float((_doc["dungeon_box_by_stars"] as Dictionary).get(stars, 0))
	if rng.randf() < box_p:
		items.append(_box_item())


func _dungeon_part_set(dungeon: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var split: Dictionary = _doc["guaranteed_split"]
	if rng.randf() < float(split.get("dungeon_set", 0)):
		return set_by_id(str(dungeon.get("set_id", "")))
	var hero := str(context.get("class_id", ""))
	var classes: Array = _doc["classes"]
	var picked := pick_class(rng, hero, classes)
	return _class_set(picked, int(dungeon.get("class_tier", 0)))


func _pick_zone_set(context: Dictionary, which: String, rng: RandomNumberGenerator) -> Dictionary:
	var zone_id := _zone_id(str(context.get("zone_id", "")))
	var zone: Dictionary = _zones.get(zone_id, {})
	var rows: Array = zone.get(which, [])
	if rows.is_empty():
		return {}
	var picked := _weighted(rng, rows)
	if str(picked.get("kind", "")) == "shared":
		return set_by_id(str(picked.get("set_id", "")))
	var hero := str(context.get("class_id", ""))
	var class_id := pick_class(rng, hero, _doc["classes"])
	return _class_set(class_id, int(picked.get("tier", 0)))


func _pick_box_part(context: Dictionary, rng: RandomNumberGenerator) -> String:
	var level := int(context.get("level", 1))
	var hero := str(context.get("class_id", ""))
	var own: Array = []
	var other: Array = []
	for row in _sets:
		var set_def: Dictionary = row
		if int(set_def.get("tier", 1)) > level:
			continue
		var classes: Array = set_def.get("classes", [])
		if not classes.is_empty() and classes.has(hero):
			own.append(set_def)
		else:
			other.append(set_def)
	var pool: Array = []
	if not own.is_empty() and (other.is_empty() or rng.randf() < float(_doc["class_bias"])):
		pool = own
	else:
		pool = other if not other.is_empty() else own
	if pool.is_empty():
		return ""
	var chosen: Dictionary = pool[rng.randi() % pool.size()]
	return _part_id(chosen, rng)


func _class_set(class_id: String, tier: int) -> Dictionary:
	for row in _sets:
		var set_def: Dictionary = row
		if str(set_def.get("kind", "")) != "class":
			continue
		if int(set_def.get("tier", -1)) != tier:
			continue
		var classes: Array = set_def.get("classes", [])
		if classes.has(class_id):
			return set_def
	return {}


func _part_drop(set_def: Dictionary, rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	if set_def.is_empty():
		return {}
	return {"item_id": _part_id(set_def, rng), "rarity": rarity, "count": 1}


func _part_id(set_def: Dictionary, rng: RandomNumberGenerator) -> String:
	var parts: Array = set_def.get("parts", [])
	if parts.is_empty():
		return ""
	var piece: Dictionary = parts[rng.randi() % parts.size()]
	return str(piece.get("id", ""))


func _weighted(rng: RandomNumberGenerator, rows: Array) -> Dictionary:
	var total := 0.0
	for row in rows:
		total += float((row as Dictionary).get("weight", 0))
	var x := rng.randf() * total
	var acc := 0.0
	for row in rows:
		var entry: Dictionary = row
		acc += float(entry.get("weight", 0))
		if x < acc:
			return entry
	return rows[rows.size() - 1]


func _dungeon(dungeon_id: String) -> Dictionary:
	var found: Variant = _dungeons.get(dungeon_id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return found


func _zone_id(raw: String) -> String:
	if _zones.has(raw):
		return raw
	if _levels == null:
		return ""
	var found: Dictionary = _levels.zone_for_chunk(raw)
	if found.is_empty():
		return ""
	return str(found.get("id", ""))


func _box_item() -> Dictionary:
	return {"item_id": "mystery_box", "rarity": "regular", "count": 1}


func _stat_block(def: Dictionary, rarity: String) -> Dictionary:
	var stats: Variant = def.get("stats", {})
	if typeof(stats) != TYPE_DICTIONARY:
		return {}
	var table: Dictionary = stats
	var block: Variant = table.get(rarity, {})
	if typeof(block) != TYPE_DICTIONARY:
		return {}
	return block


func _add_block(stats: Dictionary, block: Dictionary) -> void:
	for stat in STATS:
		stats[stat] = int(stats[stat]) + int(block.get(stat, 0))


func _sum_stats(block: Variant) -> int:
	if typeof(block) != TYPE_DICTIONARY:
		return -1
	var total := 0
	for stat in block.keys():
		total += int(block[stat])
	return total


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "reason": "invalid_world_rewards", "errors": errors}
