extends RefCounted

## Crypto Coins, gear chests and Mystery Boxes (spec 4.9, WP14), with the
## mobile gear ladder (backend/pc_gear.gd) as the set parts. Preload. No
## global class. Rolls are pure: the same seed returns the same drop. Wallet
## and inventory live on pc_progress.gd.
## Gear pieces are the mobile part ids ("cragmaw.head"). Their instance rarity
## is the set tier in lower case (normal, rare, legendary, ultra) and they
## carry a "plus" (0..5). Epics, relics, the Mystery Box and star_drops are a
## separate layer from rewards.json and keep their old rules.

const PATH := "res://data/world/rewards.json"
const Gear := preload("res://backend/pc_gear.gd")
const FORMAT := "stasium.world_rewards"
const FORMAT_VERSION := 2
## star_drops: what an item above the run level does (see _roll_star_drops).
const ABOVE_RUN_LEVEL: Array[String] = ["drop", "skip"]
const DOC_KEYS: Array[String] = [
	"format", "format_version", "status", "notes", "coins", "carry", "weights",
	"classes", "gear_slots", "equip_slots", "gear", "legacy_gear",
	"rarity_colors", "mission_ranks", "box", "dungeon_box_by_stars",
	"items", "dungeons",
]
const CHEST_ROWS: Array[String] = ["star", "boss"]

var _doc: Dictionary = {}
var _items: Dictionary = {}
var _dungeons: Dictionary = {}


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
	return {"ok": true, "reason": "", "errors": [], "rewards": book}


## Coins and items for one source: "dungeon", "mission" or "world".
## Dungeon context: dungeon_id, level, stars. Mission: level,
## missions_finished. World: level. class_id is not read: gear drops are
## uniform over sets (Mauro: "las piezas deberian ser random para cada clase").
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
	var tiers: Dictionary = gear_rules().get("box_tiers", {})
	var piece := gear_piece(str(tiers.get(str(chosen.get("rarity", "regular")), "Normal")), rng)
	if piece.is_empty():
		var band_fallback := _mission_band(int(context.get("level", 1)))
		var fallback := rng.randi_range(int(band_fallback["min"]), int(band_fallback["max"]))
		return {"coins": fallback * int(_doc["coins"]["box_times_mission"]), "items": []}
	return {"coins": 0, "items": [piece]}


func item(item_id: String) -> Dictionary:
	var found: Variant = _items.get(item_id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return (found as Dictionary).duplicate(true)


## The gear sets as rows (id, name, rarity, owner, source, parts, bonus).
func sets() -> Array:
	var rows: Array = []
	var order: Array = []
	order.append_array(Gear.FAMILY_ORDER)
	order.append_array(Gear.ULTRA_ORDER)
	for fam in order:
		rows.append(set_by_id(str(fam)))
	return rows


func set_by_id(set_id: String) -> Dictionary:
	if not Gear.FAMILIES.has(set_id):
		return {}
	var def: Dictionary = Gear.FAMILIES[set_id]
	var parts: Array = []
	for slot in Gear.SLOTS:
		var part_id := Gear.item_id_for(set_id, slot)
		parts.append({"id": part_id, "slot": slot, "name": Gear.part_name(part_id)})
	return {
		"id": set_id,
		"name": str(def["name"]),
		"rarity": str(def["rarity"]),
		"owner": str(def["owner"]),
		"source": str(def["source"]),
		"parts": parts,
		"bonus": (def["bonus"] as Dictionary).duplicate(true),
	}


func dungeons() -> Array:
	var rows: Array = []
	for key in _dungeons.keys():
		rows.append((_dungeons[key] as Dictionary).duplicate(true))
	return rows


func carry_rules() -> Dictionary:
	return (_doc["carry"] as Dictionary).duplicate(true)


func gear_rules() -> Dictionary:
	return (_doc.get("gear", {}) as Dictionary).duplicate(true)


func legacy_rules() -> Dictionary:
	return (_doc.get("legacy_gear", {}) as Dictionary).duplicate(true)


## Gear: the class lock only (mobile has no level gate on parts). Epics and
## relics keep their min_level.
func can_wear(item_id: String, rarity: String, level: int, hero_class: String) -> Dictionary:
	var def := item(item_id)
	if def.is_empty():
		return {"ok": false, "reason": "unknown item"}
	if str(def.get("slot", "")) == "":
		return {"ok": false, "reason": "not equipment"}
	if Gear.is_valid_item_id(item_id):
		if not Gear.can_wear(Gear.family_of(item_id), hero_class):
			return {"ok": false, "reason": "class"}
		return {"ok": true, "reason": ""}
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


## Worn gear as the fight and the sheet read it. `equipped` is pc_progress's
## slot map. `extra_ap` is the level milestone AP. ap / mp are the bonus over
## the base 6 / 3 (gear plus milestone), before the 8 / 5 cap; ap_total and
## mp_total are capped.
func gear_for(equipped: Dictionary, hero_class: String, extra_ap: int = 0) -> Dictionary:
	var worn: Array = []
	var epic := ""
	var relic := ""
	for slot in equipped.keys():
		var inst: Dictionary = equipped[slot]
		var item_id := str(inst.get("item_id", ""))
		if Gear.is_valid_item_id(item_id):
			worn.append({"item_id": item_id, "plus": int(inst.get("plus", 0))})
			continue
		var def := item(item_id)
		if def.is_empty():
			continue
		var rarity := str(inst.get("rarity", "regular"))
		if rarity == "epic" or str(def.get("rarity", "")) == "epic":
			epic = str(def.get("name", ""))
		if rarity == "relic" or str(def.get("rarity", "")) == "relic":
			relic = str(def.get("name", ""))
	var cls := Gear.class_key(hero_class)
	var stats: Dictionary = Gear.combat_stats(worn, cls, false, extra_ap)
	var shown: Array = []
	var counts := Gear.worn_counts(stats["worn"])
	for fam in counts.keys():
		var tiers: Array = []
		for row in Gear.active_bonuses(stats["worn"]):
			if str(row["family"]) == str(fam):
				tiers.append({"tier": int(row["tier"]), "text": str(row["text"]), "koliseo_only": bool(row["koliseo_only"])})
		shown.append({
			"id": str(fam),
			"name": str(Gear.FAMILIES[fam]["name"]),
			"rarity": Gear.rarity_of(str(fam)),
			"count": int(counts[fam]),
			"bonuses": tiers,
			"bonus_text": (Gear.FAMILIES[fam]["bonus"] as Dictionary).duplicate(),
		})
	return {
		"stats": {
			"HP": int(stats["hp_flat"]),
			"HP %": int(stats["hp_pct"]),
			"Mastery": int(stats["mastery"]),
			"Resist": int(stats["resist"]),
			"Init": int(stats["init"]),
			"Crit %": int(stats["crit"]),
		},
		"combat": stats,
		"worn": stats["worn"],
		"ap": int(stats["raw_ap"]) - Gear.BASE_AP,
		"mp": int(stats["raw_mp"]) - Gear.BASE_MP,
		"ap_total": int(stats["ap"]),
		"mp_total": int(stats["mp"]),
		"sets": shown,
		"epic": epic,
		"relic": relic,
	}


## One gear piece of a fixed tier (Normal, Rare, Legendary) at +0.
func gear_piece(rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	return _piece_row(Gear.roll_tier_chest(rarity, rng), "")


## One dungeon chest piece: the star row, or the boss row.
func chest_piece(star: int, boss: bool, rng: RandomNumberGenerator) -> Dictionary:
	return _piece_row(Gear.roll_chest(star, boss, rng), "b" if boss else "a")


func _piece_row(rolled: Dictionary, chest: String) -> Dictionary:
	if rolled.is_empty():
		return {}
	var row := {
		"item_id": str(rolled["item_id"]),
		"rarity": str(rolled["rarity"]).to_lower(),
		"count": 1,
		"plus": int(rolled.get("plus", 0)),
	}
	if chest != "":
		row["chest"] = chest
	return row


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
	if typeof(doc.get("gear", null)) != TYPE_DICTIONARY:
		errors.append("gear")
		return
	_doc = doc
	var slots: Array = doc.get("gear_slots", [])
	if slots != Array(Gear.SLOTS):
		errors.append("gear_slots must be %s" % str(Gear.SLOTS))
	var gear: Dictionary = doc["gear"]
	var chests: Array = gear.get("dungeon_chests", [])
	if chests.is_empty():
		errors.append("gear dungeon_chests")
	for row in chests:
		if typeof(row) != TYPE_DICTIONARY or not CHEST_ROWS.has(str((row as Dictionary).get("row", ""))):
			errors.append("gear dungeon_chests row")
	for key in ["mission_tiers", "box_tiers"]:
		var map: Variant = gear.get(key, {})
		if typeof(map) != TYPE_DICTIONARY:
			errors.append("gear %s" % key)
			continue
		for tier in (map as Dictionary).values():
			if not Gear.RARITIES.has(str(tier)):
				errors.append("gear %s tier %s" % [key, str(tier)])
	if not Gear.RARITIES.has(str(gear.get("world_tier", ""))):
		errors.append("gear world_tier")
	var chance := float(gear.get("world_chance", -1))
	if chance < 0.0 or chance > 1.0:
		errors.append("gear world_chance")
	var legacy: Variant = doc.get("legacy_gear", {})
	if typeof(legacy) != TYPE_DICTIONARY or not Gear.FAMILIES.has(str((legacy as Dictionary).get("to_set", ""))):
		errors.append("legacy_gear")
	else:
		for to_slot in ((legacy as Dictionary).get("slot_map", {}) as Dictionary).values():
			if not Gear.SLOTS.has(str(to_slot)):
				errors.append("legacy_gear slot %s" % str(to_slot))
	var equip_weight := int((doc.get("weights", {}) as Dictionary).get("equipment", 10))
	for item_id in Gear.all_item_ids():
		var fam := Gear.family_of(str(item_id))
		var tier := Gear.rarity_of(fam).to_lower()
		var owner := Gear.owner_of(fam)
		_items[item_id] = {
			"id": item_id,
			"name": Gear.part_name(str(item_id)),
			"category": "equipment",
			"weight": equip_weight,
			"stack": false,
			"slot": Gear.slot_of(str(item_id)),
			"min_level": 1,
			"classes": [] if owner == "" else [owner.capitalize()],
			"rarity": "",
			"rarities": [tier],
			"tier": Gear.rarity_of(fam),
			"set_id": fam,
			"part_id": item_id,
			"gear": true,
			"source": str(Gear.FAMILIES[fam]["source"]),
			"drop": "Open" if Gear.is_ultra(fam) else "rolled",
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
	for key in _dungeons.keys():
		_check_star_drops(_dungeons[key], errors)


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




## World fight (Proposed): world_chance of one Normal-tier piece.
func _roll_world(_context: Dictionary, rng: RandomNumberGenerator, items: Array) -> void:
	var gear: Dictionary = _doc["gear"]
	if rng.randf() >= float(gear.get("world_chance", 0)):
		return
	var piece := gear_piece(str(gear.get("world_tier", "Normal")), rng)
	if not piece.is_empty():
		items.append(piece)


## Mission (Proposed): the rank's box share is a Mystery Box, its rare share
## a Rare-tier piece, its regular share a Normal-tier piece.
func _roll_mission(context: Dictionary, rng: RandomNumberGenerator, items: Array) -> void:
	var rank := _rank_for(int(context.get("missions_finished", 0)))
	var box_p := float(rank.get("box", 0))
	var rare_p := float(rank.get("rare", 0))
	var reg_p := float(rank.get("regular", 0))
	var x := rng.randf()
	var share := ""
	if x < box_p:
		items.append(_box_item())
		return
	if x < box_p + rare_p:
		share = "rare"
	elif x < box_p + rare_p + reg_p:
		share = "regular"
	else:
		return
	var tiers: Dictionary = (_doc["gear"] as Dictionary).get("mission_tiers", {})
	var piece := gear_piece(str(tiers.get(share, "Normal")), rng)
	if not piece.is_empty():
		items.append(piece)


## Dungeon win: one chest per gear.dungeon_chests row (room A at the star
## row, room B at the boss row), then the Mystery Box chance by star, then
## the dungeon's star_drops.
func _roll_dungeon(context: Dictionary, rng: RandomNumberGenerator, items: Array) -> void:
	var dungeon := _dungeon(str(context.get("dungeon_id", "")))
	if dungeon.is_empty():
		return
	var star := clampi(int(context.get("stars", 1)), 1, 5)
	for raw in (_doc["gear"] as Dictionary).get("dungeon_chests", []):
		var row: Dictionary = raw
		for _i in Gear.CHEST_PIECES:
			var piece := chest_piece(star, str(row.get("row", "star")) == "boss", rng)
			if not piece.is_empty():
				piece["chest"] = str(row.get("room", piece.get("chest", "")))
				items.append(piece)
	var box_p := float((_doc["dungeon_box_by_stars"] as Dictionary).get(str(star), 0))
	if rng.randf() < box_p:
		items.append(_box_item())
	_roll_star_drops(dungeon, context, rng, items)


## A dungeon row's star_drops (Proposed): per group, one draw against the
## pools' chances at this star, so a group gives at most one item a run. A
## group with no chance at this star draws nothing (and uses no roll). In a
## picked pool, one item is chosen evenly. above_run_level "drop" keeps items
## above the run level (they wait in the bag, as can_wear says); "skip" leaves
## them out, and a pool with nothing left gives nothing.
func _roll_star_drops(dungeon: Dictionary, context: Dictionary, rng: RandomNumberGenerator, items: Array) -> void:
	var table: Dictionary = dungeon.get("star_drops", {})
	if table.is_empty():
		return
	var stars := str(maxi(int(context.get("stars", 1)), 1))
	var level := int(context.get("level", 1))
	for raw in table.get("groups", []):
		var group: Dictionary = raw
		var live: Array = []
		for pool in group.get("pools", []):
			var chance := float(((pool as Dictionary).get("chance_by_stars", {}) as Dictionary).get(stars, 0))
			if chance > 0.0:
				live.append([pool, chance])
		if live.is_empty():
			continue
		var x := rng.randf()
		var acc := 0.0
		for pair in live:
			acc += float(pair[1])
			if x >= acc:
				continue
			var pool: Dictionary = pair[0]
			var ids := _star_pool_ids(pool)
			if str(group.get("above_run_level", "drop")) == "skip":
				ids = ids.filter(func(id): return int(item(str(id)).get("min_level", 1)) <= level)
			if not ids.is_empty():
				var picked := str(ids[rng.randi() % ids.size()])
				var rarity := str(pool.get("rarity", item(picked).get("rarity", "")))
				items.append({"item_id": picked, "rarity": rarity if rarity != "" else "regular", "count": 1})
			break


func _star_pool_ids(pool: Dictionary) -> Array:
	if pool.has("set_id"):
		var ids: Array = []
		for part in set_by_id(str(pool["set_id"])).get("parts", []):
			ids.append(str((part as Dictionary).get("id", "")))
		return ids
	return (pool.get("items", []) as Array).duplicate()


func _check_star_drops(dungeon: Dictionary, errors: Array) -> void:
	var table: Variant = dungeon.get("star_drops", {})
	if typeof(table) != TYPE_DICTIONARY:
		errors.append("star_drops %s" % str(dungeon.get("id", "")))
		return
	var dung_id := str(dungeon.get("id", ""))
	for raw in (table as Dictionary).get("groups", []):
		var group: Dictionary = raw
		var where := "%s %s" % [dung_id, str(group.get("id", ""))]
		if int(group.get("max_per_run", 0)) != 1:
			errors.append("star_drops max_per_run %s" % where)
		if not ABOVE_RUN_LEVEL.has(str(group.get("above_run_level", ""))):
			errors.append("star_drops above_run_level %s" % where)
		var sums: Dictionary = {}
		for pool_raw in group.get("pools", []):
			var pool: Dictionary = pool_raw
			if pool.has("set_id") and set_by_id(str(pool["set_id"])).is_empty():
				errors.append("star_drops set %s" % where)
			var ids := _star_pool_ids(pool)
			if ids.is_empty():
				errors.append("star_drops empty pool %s" % where)
			for id in ids:
				if item(str(id)).is_empty():
					errors.append("star_drops item %s %s" % [where, str(id)])
			var by_star: Dictionary = pool.get("chance_by_stars", {})
			for star in by_star.keys():
				var chance := float(by_star[star])
				if chance < 0.0:
					errors.append("star_drops chance %s" % where)
				sums[star] = float(sums.get(star, 0.0)) + chance
		for star in sums.keys():
			if float(sums[star]) > 1.0 + 0.001:
				errors.append("star_drops chances over 1 %s star %s" % [where, str(star)])



func _dungeon(dungeon_id: String) -> Dictionary:
	var found: Variant = _dungeons.get(dungeon_id, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return found


func _box_item() -> Dictionary:
	return {"item_id": "mystery_box", "rarity": "regular", "count": 1}


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "reason": "invalid_world_rewards", "errors": errors}
