extends RefCounted

## PC hero level from 1 to max_level in level_curve.json, plus the points,
## respec, and milestone flag from level_rewards.json (spec 4.11).
## Per-point combat values stay in that file. This script does not import
## phone level code. Loaded with preload. No global class.

const Duel = preload("res://backend/pc_duel.gd")
const Catalog = preload("res://backend/pc_rewards.gd")
const Kits = preload("res://data/kits.gd")
const CURVE_PATH := "res://data/world/level_curve.json"
const REWARDS_PATH := "res://data/world/level_rewards.json"
const SAVE_PATH := "user://pc_progress.json"
const FORMAT := "stasium.level_curve"
const FORMAT_VERSION := 1
const REWARDS_FORMAT := "stasium.level_rewards"
const DOC_KEYS: Array[String] = [
	"format", "format_version", "status", "max_level", "xp_to_next",
	"pace_start", "pace_ratio",
]
const REWARD_KEYS: Array[String] = [
	"format", "format_version", "status", "points_per_level", "stats",
	"stat_per_point", "class_hp_per_level", "milestones", "titles", "respec", "sheet",
	"koliseo_duel",
]
const STAT_NAMES: Array[String] = ["Mastery", "Vitality", "Swift", "Resist"]
const EQUIP_SLOTS: Array[String] = [
	"head", "amulet", "ring", "ring_b", "cape", "belt", "boots", "weapon",
]

var level: int = 1
var xp: int = 0
var max_level: int = 1
var xp_to_next: Array = []
var curve_ok: bool = false
var rewards_ok: bool = false
var points_per_level: int = 0
var stat_names: Array = []
var stat_per_point: Dictionary = {}
var class_hp_per_level: Variant = "Open"
var milestones: Array = []
var title_rows: Array = []
var free_respecs: int = 0
var coin_per_level: Variant = "Open"
var duel_min: float = 0.0
var duel_max: float = 1.0
var sheet: Dictionary = {}
var spent: Dictionary = {}
var respecs_used: int = 0
var coins: int = 0
var bag: Array = []
var bank: Array = []
var equipped: Dictionary = {}
var hero_class := ""
var rare_choice := ""
var bag_slots := 0
var bank_slots := 0
var weight_base := 0
var weight_per_level := 0
var load_log: Array = []
var _uid := 1
var _equip_seq := 1
var _catalog = null


func _init() -> void:
	var curve := load_curve()
	if bool(curve.get("ok", false)):
		max_level = int(curve["max_level"])
		xp_to_next = curve["xp_to_next"]
		curve_ok = true
	_apply_rewards(load_rewards())
	_bind_catalog()
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


static func load_rewards() -> Dictionary:
	if not FileAccess.file_exists(REWARDS_PATH):
		return _fail_rewards(["missing %s" % REWARDS_PATH])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REWARDS_PATH))
	return parse_rewards(parsed)


static func parse_rewards(doc: Variant) -> Dictionary:
	if typeof(doc) != TYPE_DICTIONARY:
		return _fail_rewards(["level rewards are not a JSON object"])
	var errors: Array = []
	_check_rewards(doc, errors)
	if not errors.is_empty():
		return _fail_rewards(errors)
	return {
		"ok": true,
		"reason": "",
		"errors": [],
		"doc": doc,
	}


func points_earned() -> int:
	return points_per_level * maxi(level - 1, 0)


func points_spent() -> int:
	var total := 0
	for stat in stat_names:
		total += int(spent.get(stat, 0))
	return total


func points_free() -> int:
	return points_earned() - points_spent()


func spent_in(bucket: String) -> int:
	return int(spent.get(bucket, 0))


## Spend free characteristic points into one of the four stats.
func spend(bucket: String, n: int) -> bool:
	if not rewards_ok or n < 1 or not stat_names.has(bucket):
		return false
	if n > points_free():
		return false
	spent[bucket] = int(spent.get(bucket, 0)) + n
	_autosave()
	return true


## The first respecs are free. The next ones cost coin_per_level times the
## current level in Crypto Coins, taken from the hero's coin count.
func next_respec_cost() -> Variant:
	if respecs_used < free_respecs:
		return 0
	if not _whole(coin_per_level):
		return coin_per_level
	return int(coin_per_level) * level


func respec() -> Dictionary:
	if not rewards_ok:
		return {"ok": false, "reason": "rewards are missing", "cost": 0}
	var cost: Variant = next_respec_cost()
	if not _whole(cost):
		return {"ok": false, "reason": "respec cost is Open", "cost": cost}
	var price := int(cost)
	if price > 0 and coins < price:
		return {"ok": false, "reason": "not enough Crypto Coins", "cost": price}
	if price > 0:
		coins -= price
	for stat in stat_names:
		spent[stat] = 0
	respecs_used += 1
	_autosave()
	return {"ok": true, "reason": "", "cost": price}


func _swift_initiative() -> int:
	var swift: Variant = stat_per_point.get("Swift", {})
	if typeof(swift) != TYPE_DICTIONARY:
		return 0
	var each: Variant = (swift as Dictionary).get("initiative", 0)
	if not _whole(each):
		return 0
	return int(spent.get("Swift", 0)) * int(each)


## Win rate of spread A against spread B. Same class, both at the full budget.
## Seeded fights in CombatSim. Swift's Initiative is turn order only.
func duel_win_rate(left: Dictionary, right: Dictionary) -> float:
	var scored: Dictionary = Duel.win_rate(self, left, right)
	return float(scored["win"])


## Points of Resist that still do something. Past cap/rate the rest is wasted.
func resist_cap_points() -> float:
	var resist: Variant = stat_per_point.get("Resist", {})
	if typeof(resist) != TYPE_DICTIONARY:
		return 0.0
	var rate := _as_float((resist as Dictionary).get("damage_taken", 0))
	var cap := _as_float((resist as Dictionary).get("cap", 0))
	if rate <= 0.0:
		return 0.0
	return cap / rate


## Spread against spread for the points earned by max_level, fought in CombatSim.
## The listed pairs are the Koliseo check: the three single-stat corners, a
## half-and-half mix against each single-stat spend, and Swift against the other three.
func koliseo_duel_table() -> Dictionary:
	return Duel.table(self)


static func _as_float(value: Variant) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return 0.0


## Sum of milestone AP the hero has reached. The levels live in the rewards file.
func milestone_ap() -> int:
	var total := 0
	for row in milestones:
		if level >= int(row.get("level", 0)):
			total += int(row.get("ap", 0))
	return total


## Title levels reached, up to the current level and the curve cap.
func titles() -> Array:
	var got: Array = []
	for row in title_rows:
		var at := int(row.get("level", 0))
		if at >= 1 and at <= level and at <= max_level:
			got.append({"level": at, "name": str(row.get("name", ""))})
	return got


## koliseo drops worn gear and set stats. Open-world sheets keep them, then clamp.
func sheet_view(koliseo: bool = false) -> Dictionary:
	var need := 0
	if level < max_level and level - 1 < xp_to_next.size():
		need = int(xp_to_next[level - 1])
	var rows: Array = []
	for stat in stat_names:
		rows.append({
			"name": stat,
			"spent": int(spent.get(stat, 0)),
			"per_point": stat_per_point.get(stat, "Open"),
		})
	var caps: Dictionary = sheet.get("caps", {})
	var base_ap := int(sheet.get("ap", 0)) if _whole(sheet.get("ap", null)) else 0
	var base_mp := int(sheet.get("mp", 0)) if _whole(sheet.get("mp", null)) else 0
	var gear := gear_view()
	if koliseo:
		gear = {
			"stats": {"Mastery": 0, "Vitality": 0, "Swift": 0, "Resist": 0},
			"ap": 0,
			"mp": 0,
			"sets": [],
			"epic": "",
			"relic": "",
		}
	var ap_total := base_ap + milestone_ap() + int(gear.get("ap", 0))
	var mp_total := base_mp + int(gear.get("mp", 0))
	if _whole(caps.get("ap", null)) and int(caps["ap"]) > 0 and ap_total > int(caps["ap"]):
		ap_total = int(caps["ap"])
	if _whole(caps.get("mp", null)) and int(caps["mp"]) > 0 and mp_total > int(caps["mp"]):
		mp_total = int(caps["mp"])
	return {
		"level": level,
		"xp": xp,
		"xp_need": need,
		"at_cap": level >= max_level,
		"points_free": points_free(),
		"points_earned": points_earned(),
		"stats": rows,
		"hp": sheet.get("hp", "Open"),
		"class_hp_per_level": class_hp_per_level,
		"ap": ap_total,
		"ap_from_milestones": milestone_ap(),
		"mp": mp_total,
		"initiative": sheet.get("initiative", "Open"),
		"range_bonus": sheet.get("range_bonus", "Open"),
		"caps": caps,
		"titles": titles(),
		"respecs_used": respecs_used,
		"free_respecs": free_respecs,
		"respec_cost": next_respec_cost(),
		"initiative_from_swift": _swift_initiative(),
		"coins": coins,
		"gear": gear,
		"bag_slots_used": bag.size(),
		"bag_slots": bag_slots,
		"weight": bag_weight(),
		"weight_max": weight_max(),
		"koliseo": koliseo,
		"resist": _resist_fraction(gear),
		"hero_class": hero_class,
	}


## XP added toward the next level. At max_level further XP is kept and does not level.
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
	file.store_string(JSON.stringify({
		"level": level,
		"xp": xp,
		"spent": spent.duplicate(),
		"respecs_used": respecs_used,
		"coins": coins,
		"bag": bag.duplicate(true),
		"bank": bank.duplicate(true),
		"equipped": equipped.duplicate(true),
		"hero_class": hero_class,
		"rare_choice": rare_choice,
		"next_uid": _uid,
		"equip_seq": _equip_seq,
	}))
	return true


## Public load from user://pc_progress.json.
## Startup calls read_save() so this file does not call Godot's global load().
func load() -> bool:
	return read_save()


## Swap in a parsed curve (tests, and the next phase's longer file).
## Resets level and XP. Call read_save() afterwards to apply a save against this cap.
func bind_curve(doc: Dictionary) -> bool:
	var parsed := parse_curve(doc)
	if not bool(parsed.get("ok", false)):
		return false
	max_level = int(parsed["max_level"])
	xp_to_next = parsed["xp_to_next"]
	curve_ok = true
	level = 1
	xp = 0
	_reset_spend()
	return true


## Swap in a parsed rewards document (tests).
func bind_rewards(doc: Dictionary) -> bool:
	var parsed := parse_rewards(doc)
	if not bool(parsed.get("ok", false)):
		return false
	_apply_rewards(parsed)
	_reset_spend()
	return true


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
	var prev_level := level
	var prev_xp := xp
	var prev_spent: Dictionary = spent.duplicate()
	var prev_respecs := respecs_used
	var prev_coins := coins
	var prev_bag := bag.duplicate(true)
	var prev_bank := bank.duplicate(true)
	var prev_equipped := equipped.duplicate(true)
	var prev_class := hero_class
	var prev_choice := rare_choice
	var prev_uid := _uid
	var prev_log: Array = load_log.duplicate()
	level = next_level
	xp = next_xp
	if not _apply_saved_spend(doc) or not _apply_saved_items(doc):
		level = prev_level
		xp = prev_xp
		spent = prev_spent
		respecs_used = prev_respecs
		coins = prev_coins
		bag = prev_bag
		bank = prev_bank
		equipped = prev_equipped
		hero_class = prev_class
		rare_choice = prev_choice
		_uid = prev_uid
		load_log = prev_log
		return false
	return true


static func _check_curve(doc: Dictionary, errors: Array) -> void:
	_unknown(doc, DOC_KEYS, errors, "level curve")
	if str(doc.get("format", "")) != FORMAT:
		_err(errors, "format must be %s" % FORMAT)
	if not _whole(doc.get("format_version", null)) or int(doc.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "format_version must be %d" % FORMAT_VERSION)
	if str(doc.get("status", "")) != "proposed":
		_err(errors, "status must be proposed")
	var cap_ok := _whole(doc.get("max_level", null)) and int(doc.get("max_level", 0)) >= 2
	if not cap_ok:
		_err(errors, "max_level must be an integer of 2 or more")
	var has_pace_start := doc.has("pace_start")
	var has_pace_ratio := doc.has("pace_ratio")
	if has_pace_start != has_pace_ratio:
		_err(errors, "pace_start and pace_ratio are set together")
	if has_pace_start and not _positive_number(doc.get("pace_start", null)):
		_err(errors, "pace_start must be a positive number")
	if has_pace_ratio and not _positive_number(doc.get("pace_ratio", null)):
		_err(errors, "pace_ratio must be a positive number")
	if typeof(doc.get("xp_to_next", null)) != TYPE_ARRAY:
		_err(errors, "xp_to_next must be an array")
		return
	var steps: Array = doc["xp_to_next"]
	if cap_ok and steps.size() != int(doc["max_level"]) - 1:
		_err(errors, "xp_to_next must have one entry for each level below max_level")
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


static func _positive_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) > 0.0


static func _whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) == float(int(value))


static func _err(errors: Array, message: String) -> void:
	if errors.size() < 32:
		errors.append(message)


func _apply_rewards(parsed: Dictionary) -> void:
	rewards_ok = bool(parsed.get("ok", false))
	if not rewards_ok:
		points_per_level = 0
		stat_names = []
		stat_per_point = {}
		class_hp_per_level = "Open"
		milestones = []
		title_rows = []
		free_respecs = 0
		coin_per_level = "Open"
		duel_min = 0.0
		duel_max = 1.0
		sheet = {}
		return
	var doc: Dictionary = parsed["doc"]
	points_per_level = int(doc["points_per_level"])
	stat_names = []
	for stat in doc["stats"]:
		stat_names.append(str(stat))
	stat_per_point = (doc["stat_per_point"] as Dictionary).duplicate(true)
	class_hp_per_level = doc["class_hp_per_level"]
	milestones = (doc["milestones"] as Array).duplicate(true)
	title_rows = (doc["titles"] as Array).duplicate(true)
	var respec_doc: Dictionary = doc["respec"]
	free_respecs = int(respec_doc["free"])
	coin_per_level = respec_doc.get("coin_per_level", "Open")
	var duel: Dictionary = doc.get("koliseo_duel", {})
	duel_min = float(duel.get("win_min", 0))
	duel_max = float(duel.get("win_max", 1))
	sheet = (doc["sheet"] as Dictionary).duplicate(true)
	_reset_spend()


func _reset_spend() -> void:
	spent = {}
	for stat in stat_names:
		spent[stat] = 0
	respecs_used = 0


func _apply_saved_spend(doc: Dictionary) -> bool:
	var next := {}
	for stat in stat_names:
		next[stat] = 0
	if doc.has("spent"):
		if typeof(doc["spent"]) != TYPE_DICTIONARY:
			return false
		for key in doc["spent"].keys():
			var name := str(key)
			if not stat_names.has(name) or not _whole(doc["spent"][key]) or int(doc["spent"][key]) < 0:
				return false
			next[name] = int(doc["spent"][key])
	var used := 0
	if doc.has("respecs_used"):
		if not _whole(doc["respecs_used"]) or int(doc["respecs_used"]) < 0:
			return false
		used = int(doc["respecs_used"])
	var total := 0
	for stat in stat_names:
		total += int(next[stat])
	if total > points_per_level * maxi(level - 1, 0):
		return false
	var saved_coins := 0
	if doc.has("coins"):
		if not _whole(doc["coins"]) or int(doc["coins"]) < 0:
			return false
		saved_coins = int(doc["coins"])
	spent = next
	respecs_used = used
	coins = saved_coins
	return true


func _bind_catalog() -> void:
	var loaded: Dictionary = Catalog.load_default()
	if not bool(loaded.get("ok", false)):
		_catalog = null
		return
	_catalog = loaded["rewards"]
	var rules: Dictionary = _catalog.carry_rules()
	bag_slots = int(rules.get("bag_slots", 0))
	bank_slots = int(rules.get("bank_slots", 0))
	weight_base = int(rules.get("weight_base", 0))
	weight_per_level = int(rules.get("weight_per_level", 0))


func weight_max() -> int:
	return weight_base + weight_per_level * level


func bag_weight() -> int:
	var total := 0
	for entry in bag:
		total += _entry_weight(entry)
	return total


func gear_view() -> Dictionary:
	if _catalog == null:
		return {
			"stats": {"Mastery": 0, "Vitality": 0, "Swift": 0, "Resist": 0},
			"ap": 0, "mp": 0, "sets": [], "epic": "", "relic": "",
		}
	return _catalog.gear_for(equipped, hero_class, rare_choice)


func item_def(item_id: String) -> Dictionary:
	if _catalog == null:
		return {}
	return _catalog.item(item_id)


func grant(drop: Dictionary) -> Dictionary:
	var to_bag: Array = []
	var to_bank: Array = []
	var refused: Array = []
	if _whole(drop.get("coins", 0)) and int(drop.get("coins", 0)) > 0:
		coins += int(drop["coins"])
	var items: Variant = drop.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		for raw in items:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw
			var item_id := str(item.get("item_id", ""))
			if item_id == "":
				continue
			var rarity := str(item.get("rarity", "regular"))
			var count := int(item.get("count", 1))
			if count < 1:
				continue
			if _place(item_id, rarity, count):
				to_bag.append(item)
			elif _to_bank(item_id, rarity, count):
				to_bank.append(item)
			else:
				refused.append(item)
	var reason := ""
	if not refused.is_empty():
		reason = _bank_full_message()
	_autosave()
	return {
		"ok": refused.is_empty(),
		"to_bag": to_bag,
		"to_bank": to_bank,
		"refused": refused,
		"bank_over": false,
		"reason": reason,
	}


func open_mystery_box(rng: RandomNumberGenerator) -> Dictionary:
	if _catalog == null:
		return {"ok": false, "reason": "no catalog"}
	if _find_item("mystery_box", "regular").is_empty():
		return {"ok": false, "reason": "no box"}
	var got: Dictionary = _catalog.open_box({"level": level, "class_id": hero_class}, rng)
	if not _reward_fits(got):
		return {"ok": false, "reason": "bag full", "reward": got}
	var snap_coins := coins
	var snap_bag := bag.duplicate(true)
	var snap_bank := bank.duplicate(true)
	var snap_uid := _uid
	if not _consume_item("mystery_box", "regular"):
		return {"ok": false, "reason": "no box"}
	var placed: Dictionary = grant(got)
	if not bool(placed.get("ok", false)):
		coins = snap_coins
		bag = snap_bag
		bank = snap_bank
		_uid = snap_uid
		_autosave()
		return {"ok": false, "reason": "bag full", "reward": got, "placed": placed}
	return {"ok": true, "reason": "", "reward": got, "placed": placed}


func equip_uid(uid: int) -> Dictionary:
	if _catalog == null:
		return {"ok": false, "reason": "no catalog"}
	var entry := _find_bag(uid)
	if entry.is_empty():
		return {"ok": false, "reason": "not in bag"}
	var item_id := str(entry["item_id"])
	var rarity := str(entry["rarity"])
	var check: Dictionary = _catalog.can_wear(item_id, rarity, level, hero_class)
	if not bool(check.get("ok", false)):
		return check
	var def: Dictionary = _catalog.item(item_id)
	var slot := str(def.get("slot", ""))
	if slot == "ring":
		slot = _free_ring()
		if slot == "":
			slot = _older_ring()
	var kind := rarity
	if str(def.get("rarity", "")) != "":
		kind = str(def.get("rarity", ""))
	if kind == "epic" or kind == "relic":
		var occupied := _worn_kind(kind)
		if occupied != "" and occupied != slot:
			return {"ok": false, "reason": "only one %s" % kind}
	var incoming := int(entry.get("count", 1))
	if equipped.has(slot) and not _displaced_fits(equipped[slot], item_id, incoming):
		return {"ok": false, "reason": "bag full"}
	var snapshot: Dictionary = entry.duplicate(true)
	if not _consume_uid(uid):
		return {"ok": false, "reason": "not in bag"}
	if equipped.has(slot):
		var back := unequip(slot, false)
		if not bool(back.get("ok", false)):
			_restore_bag_row(snapshot)
			_autosave()
			return back
	equipped[slot] = {
		"uid": uid,
		"item_id": item_id,
		"rarity": rarity,
		"upgrade": int(entry.get("upgrade", 0)),
		"seq": _equip_seq,
	}
	_equip_seq += 1
	_autosave()
	return {"ok": true, "reason": "", "slot": slot}


func unequip(slot: String, write: bool = true) -> Dictionary:
	if not equipped.has(slot):
		return {"ok": false, "reason": "empty"}
	var inst: Dictionary = equipped[slot]
	var item_id := str(inst.get("item_id", ""))
	var rarity := str(inst.get("rarity", "regular"))
	var row := {
		"uid": int(inst.get("uid", 0)),
		"item_id": item_id,
		"rarity": rarity,
		"count": 1,
		"upgrade": int(inst.get("upgrade", 0)),
	}
	if bag.size() >= bag_slots or bag_weight() + _entry_weight(row) > weight_max():
		return {"ok": false, "reason": "bag full"}
	equipped.erase(slot)
	bag.append(row)
	if write:
		_autosave()
	return {"ok": true, "reason": "", "slot": slot}


func choose_rare(which: String) -> Dictionary:
	if which != "ap" and which != "mp":
		return {"ok": false, "reason": "choice"}
	if rare_choice == "" or rare_choice == which:
		rare_choice = which
		_autosave()
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "switch cost is Open"}


func _place(item_id: String, rarity: String, count: int) -> bool:
	var stack: bool = _catalog != null and _catalog.stacks(item_id)
	if stack:
		var weight := _entry_weight({"item_id": item_id, "count": count})
		for entry in bag:
			if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
				if bag_weight() + weight <= weight_max():
					entry["count"] = int(entry.get("count", 1)) + count
					return true
				return false
		if bag.size() >= bag_slots or bag_weight() + weight > weight_max():
			return false
		bag.append(_fresh(item_id, rarity, count))
		return true
	var one := _entry_weight({"item_id": item_id, "count": 1})
	if bag.size() + count > bag_slots or bag_weight() + one * count > weight_max():
		return false
	for _i in count:
		bag.append(_fresh(item_id, rarity, 1))
	return true


func _to_bank(item_id: String, rarity: String, count: int) -> bool:
	var stack: bool = _catalog != null and _catalog.stacks(item_id)
	if stack:
		for entry in bank:
			if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
				entry["count"] = int(entry.get("count", 1)) + count
				return true
		if not _bank_has_room(1):
			return false
		bank.append(_fresh(item_id, rarity, count))
		return true
	if not _bank_has_room(count):
		return false
	for _i in count:
		bank.append(_fresh(item_id, rarity, 1))
	return true


func _fresh(item_id: String, rarity: String, count: int) -> Dictionary:
	var uid := _uid
	_uid += 1
	return {"uid": uid, "item_id": item_id, "rarity": rarity, "count": count, "upgrade": 0}


func _entry_weight(entry: Dictionary) -> int:
	if _catalog == null:
		return 0
	return _catalog.weight_of(str(entry.get("item_id", ""))) * int(entry.get("count", 1))


func _find_bag(uid: int) -> Dictionary:
	for entry in bag:
		if int(entry.get("uid", -1)) == uid:
			return entry
	return {}


func _find_bank(uid: int) -> Dictionary:
	for entry in bank:
		if int(entry.get("uid", -1)) == uid:
			return entry
	return {}


func _find_item(item_id: String, rarity: String) -> Dictionary:
	for entry in bag:
		if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
			return entry
	return {}


func _remove_bank_uid(uid: int) -> bool:
	for i in bank.size():
		var entry: Dictionary = bank[i]
		if int(entry.get("uid", -1)) != uid:
			continue
		bank.remove_at(i)
		return true
	return false


func _bag_has_stack(item_id: String, rarity: String) -> bool:
	if _catalog == null or not _catalog.stacks(item_id):
		return false
	for entry in bag:
		if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
			return true
	return false


func _can_place(item_id: String, rarity: String, count: int) -> bool:
	return _room_for(item_id, rarity, count, bag.size(), bag_weight(), -1)


func _room_for(item_id: String, rarity: String, count: int, slots_used: int, weight_used: int, ignore_uid: int) -> bool:
	var stack: bool = _catalog != null and _catalog.stacks(item_id)
	var one := _entry_weight({"item_id": item_id, "count": 1})
	if stack:
		for entry in bag:
			if int(entry.get("uid", -1)) == ignore_uid:
				continue
			if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
				return weight_used + one * count <= weight_max()
		if slots_used >= bag_slots or weight_used + one * count > weight_max():
			return false
		return true
	if slots_used + count > bag_slots or weight_used + one * count > weight_max():
		return false
	return true


func _bank_can_take(item_id: String, rarity: String, count: int) -> bool:
	var stack: bool = _catalog != null and _catalog.stacks(item_id)
	if stack:
		for entry in bank:
			if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
				return true
		return _bank_has_room(1)
	return _bank_has_room(count)


func _reward_fits(drop: Dictionary) -> bool:
	var items: Variant = drop.get("items", [])
	if typeof(items) != TYPE_ARRAY or (items as Array).is_empty():
		return true
	var slots_used := bag.size()
	var weight_used := bag_weight()
	var box := _find_item("mystery_box", "regular")
	var ignore := -1
	if not box.is_empty():
		weight_used -= _entry_weight({"item_id": "mystery_box", "count": 1})
		if int(box.get("count", 1)) <= 1:
			slots_used -= 1
			ignore = int(box.get("uid", -1))
	if slots_used < 0:
		slots_used = 0
	if weight_used < 0:
		weight_used = 0
	for raw in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		var item_id := str(item.get("item_id", ""))
		if item_id == "":
			continue
		var rarity := str(item.get("rarity", "regular"))
		var count := int(item.get("count", 1))
		if count < 1:
			continue
		if _room_for(item_id, rarity, count, slots_used, weight_used, ignore):
			var one := _entry_weight({"item_id": item_id, "count": 1})
			var merges := false
			if _catalog != null and _catalog.stacks(item_id):
				for entry in bag:
					if int(entry.get("uid", -1)) == ignore:
						continue
					if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
						merges = true
			if merges:
				weight_used += one * count
			else:
				var stack: bool = _catalog != null and _catalog.stacks(item_id)
				slots_used += 1 if stack else count
				weight_used += one * count
			continue
		if _bank_can_take(item_id, rarity, count):
			continue
		return false
	return true


func _displaced_fits(worn: Dictionary, incoming_id: String, incoming_count: int) -> bool:
	var free_slots := bag_slots - bag.size()
	var free_weight := weight_max() - bag_weight()
	if incoming_count <= 1:
		free_slots += 1
	if _catalog != null:
		free_weight += _catalog.weight_of(incoming_id)
	var worn_weight := _entry_weight({"item_id": str(worn.get("item_id", "")), "count": 1})
	return free_slots >= 1 and free_weight >= worn_weight


func _restore_bag_row(snapshot: Dictionary) -> void:
	var uid := int(snapshot.get("uid", -1))
	for entry in bag:
		if int(entry.get("uid", -1)) != uid:
			continue
		entry["count"] = int(entry.get("count", 1)) + 1
		return
	bag.append(snapshot.duplicate(true))


func _cap_carried() -> void:
	load_log = []
	if bag_slots > 0:
		while bag.size() > bag_slots and bank.size() < bank_slots:
			var row: Dictionary = bag[bag.size() - 1]
			bag.remove_at(bag.size() - 1)
			bank.append(row)
			load_log.append("moved uid %d to the bank" % int(row.get("uid", 0)))
	if bag_slots > 0 and bag.size() > bag_slots:
		load_log.append("bag over cap, kept %d" % (bag.size() - bag_slots))
	if bank_slots > 0 and bank.size() > bank_slots:
		load_log.append("bank over cap, kept %d" % (bank.size() - bank_slots))


func _remove_uid(uid: int) -> bool:
	for i in bag.size():
		var entry: Dictionary = bag[i]
		if int(entry.get("uid", -1)) != uid:
			continue
		bag.remove_at(i)
		return true
	return false


func _bank_has_room(count: int) -> bool:
	if bank_slots < 1:
		return false
	return bank.size() + count <= bank_slots


func _bank_full_message() -> String:
	return "The bank is full (%d slots)." % bank_slots


func _drop_unwearable(write: bool) -> void:
	if _catalog == null:
		return
	var slots: Array = equipped.keys()
	for slot in slots:
		var inst: Dictionary = equipped[slot]
		var check: Dictionary = _catalog.can_wear(
			str(inst.get("item_id", "")),
			str(inst.get("rarity", "regular")),
			level,
			hero_class
		)
		if not bool(check.get("ok", false)):
			unequip(str(slot), false)
	if write:
		_autosave()


func _autosave() -> void:
	save()


func _resist_fraction(gear: Dictionary) -> float:
	var resist: Variant = stat_per_point.get("Resist", {})
	if typeof(resist) != TYPE_DICTIONARY:
		return 0.0
	var rate := _as_float((resist as Dictionary).get("damage_taken", 0))
	var cap := _as_float((resist as Dictionary).get("cap", 0))
	var points := float(int(spent.get("Resist", 0)))
	var block: Variant = gear.get("stats", {})
	if typeof(block) == TYPE_DICTIONARY:
		points += float(int((block as Dictionary).get("Resist", 0)))
	var raw := points * rate
	if cap > 0.0 and raw > cap:
		return cap
	return raw


func _consume_uid(uid: int) -> bool:
	for i in bag.size():
		var entry: Dictionary = bag[i]
		if int(entry.get("uid", -1)) != uid:
			continue
		var count := int(entry.get("count", 1))
		if count > 1:
			entry["count"] = count - 1
		else:
			bag.remove_at(i)
		return true
	return false


func _consume_item(item_id: String, rarity: String) -> bool:
	for entry in bag:
		if str(entry.get("item_id", "")) == item_id and str(entry.get("rarity", "")) == rarity:
			return _consume_uid(int(entry.get("uid", -1)))
	return false


func _free_ring() -> String:
	if not equipped.has("ring"):
		return "ring"
	if not equipped.has("ring_b"):
		return "ring_b"
	return ""


func _older_ring() -> String:
	var left: Dictionary = equipped.get("ring", {})
	var right: Dictionary = equipped.get("ring_b", {})
	var left_seq := int(left.get("seq", left.get("uid", 0)))
	var right_seq := int(right.get("seq", right.get("uid", 0)))
	if left_seq <= right_seq:
		return "ring"
	return "ring_b"


func set_hero_class(class_id: String) -> bool:
	var shown := str(Kits.display_name(class_id))
	if shown == "":
		return false
	if hero_class == shown:
		return true
	hero_class = shown
	_drop_unwearable(false)
	_autosave()
	return true


func note_zone(_zone_id: String) -> void:
	_autosave()


func destroy_uid(uid: int, count: int = 1) -> Dictionary:
	var entry := _find_bag(uid)
	if entry.is_empty():
		return {"ok": false, "reason": "not in bag", "count": 0}
	var take := maxi(count, 1)
	var have := int(entry.get("count", 1))
	if take > have:
		take = have
	if have - take > 0:
		entry["count"] = have - take
	else:
		_remove_uid(uid)
	_autosave()
	return {"ok": true, "reason": "", "count": take}


func deposit_uid(uid: int) -> Dictionary:
	var entry := _find_bag(uid)
	if entry.is_empty():
		return {"ok": false, "reason": "not in bag"}
	var item_id := str(entry.get("item_id", ""))
	var rarity := str(entry.get("rarity", "regular"))
	if not _consume_uid(uid):
		return {"ok": false, "reason": "not in bag"}
	if not _to_bank(item_id, rarity, 1):
		_place(item_id, rarity, 1)
		_autosave()
		return {"ok": false, "reason": _bank_full_message()}
	_autosave()
	return {"ok": true, "reason": ""}


func withdraw_uid(uid: int, count: int = 1) -> Dictionary:
	var entry := _find_bank(uid)
	if entry.is_empty():
		return {"ok": false, "reason": "not in bank", "count": 0}
	var have := int(entry.get("count", 1))
	var take := mini(maxi(count, 1), have)
	var item_id := str(entry.get("item_id", ""))
	var rarity := str(entry.get("rarity", "regular"))
	if not _can_place(item_id, rarity, take):
		return {"ok": false, "reason": "bag full", "count": 0}
	var snap_bag := bag.duplicate(true)
	var snap_bank := bank.duplicate(true)
	var snap_uid := _uid
	var whole := take == have
	if whole and not _bag_has_stack(item_id, rarity):
		var row: Dictionary = entry.duplicate(true)
		row["count"] = take
		if not _remove_bank_uid(uid):
			return {"ok": false, "reason": "not in bank", "count": 0}
		bag.append(row)
	else:
		if whole:
			if not _remove_bank_uid(uid):
				return {"ok": false, "reason": "not in bank", "count": 0}
		else:
			entry["count"] = have - take
		if not _place(item_id, rarity, take):
			bag = snap_bag
			bank = snap_bank
			_uid = snap_uid
			return {"ok": false, "reason": "bag full", "count": 0}
	_autosave()
	return {"ok": true, "reason": "", "count": take}


func _worn_kind(kind: String) -> String:
	for slot in equipped.keys():
		var inst: Dictionary = equipped[slot]
		var def: Dictionary = item_def(str(inst.get("item_id", "")))
		var rarity := str(inst.get("rarity", ""))
		var fixed := str(def.get("rarity", ""))
		if rarity == kind or fixed == kind:
			return str(slot)
	return ""


func _apply_saved_items(doc: Dictionary) -> bool:
	if not _apply_saved_class(doc):
		return false
	if doc.has("rare_choice"):
		var choice := str(doc["rare_choice"])
		if choice != "" and choice != "ap" and choice != "mp":
			return false
		rare_choice = choice
	else:
		rare_choice = ""
	if not doc.has("bag") and not doc.has("bank") and not doc.has("equipped"):
		bag = []
		bank = []
		equipped = {}
		_assign_next_uid(doc, 0)
		_cap_carried()
		return true
	var seen := {}
	var next_bag: Array = []
	var next_bank: Array = []
	if not _read_stack(doc.get("bag", []), next_bag, seen):
		return false
	if not _read_stack(doc.get("bank", []), next_bank, seen):
		return false
	var kept := {}
	var worn_epic := ""
	var worn_relic := ""
	if doc.has("equipped"):
		if typeof(doc["equipped"]) != TYPE_DICTIONARY:
			return false
		for slot in doc["equipped"].keys():
			if not EQUIP_SLOTS.has(str(slot)):
				return false
		for slot in EQUIP_SLOTS:
			if not doc["equipped"].has(slot):
				continue
			if typeof(doc["equipped"][slot]) != TYPE_DICTIONARY:
				return false
			var inst: Dictionary = doc["equipped"][slot]
			if typeof(inst.get("item_id", null)) != TYPE_STRING or str(inst["item_id"]) == "":
				return false
			if typeof(inst.get("rarity", null)) != TYPE_STRING:
				return false
			var uid := int(inst.get("uid", 0))
			if not _whole(inst.get("uid", null)) or uid < 1 or seen.has(uid):
				return false
			if item_def(str(inst["item_id"])).is_empty():
				return false
			seen[uid] = true
			var row := {
				"uid": uid,
				"item_id": str(inst["item_id"]),
				"rarity": str(inst["rarity"]),
				"upgrade": int(inst.get("upgrade", 0)) if _whole(inst.get("upgrade", 0)) else 0,
				"count": 1,
				"seq": int(inst.get("seq", 0)) if _whole(inst.get("seq", 0)) else 0,
			}
			var kind := _saved_kind(row)
			var check: Dictionary = {}
			if _catalog != null:
				check = _catalog.can_wear(row["item_id"], row["rarity"], level, hero_class)
			var wearable: bool = bool(check.get("ok", false))
			if kind == "epic" and worn_epic != "":
				wearable = false
			if kind == "relic" and worn_relic != "":
				wearable = false
			if wearable:
				kept[slot] = row
				if kind == "epic":
					worn_epic = slot
				elif kind == "relic":
					worn_relic = slot
			else:
				next_bag.append(row)
	var highest := 0
	for entry in next_bag:
		highest = maxi(highest, int(entry["uid"]))
	for entry in next_bank:
		highest = maxi(highest, int(entry["uid"]))
	for slot in kept.keys():
		highest = maxi(highest, int(kept[slot]["uid"]))
	if not _assign_next_uid(doc, highest):
		return false
	var seq := 1
	if doc.has("equip_seq") and _whole(doc["equip_seq"]) and int(doc["equip_seq"]) >= 1:
		seq = int(doc["equip_seq"])
	for slot in kept.keys():
		seq = maxi(seq, int(kept[slot].get("seq", 0)) + 1)
	_equip_seq = seq
	bag = next_bag
	bank = next_bank
	equipped = kept
	_cap_carried()
	return true


func _apply_saved_class(doc: Dictionary) -> bool:
	if not doc.has("hero_class"):
		return true
	if typeof(doc["hero_class"]) != TYPE_STRING:
		return false
	var raw := str(doc["hero_class"])
	if raw == "":
		hero_class = ""
		return true
	var shown := str(Kits.display_name(raw))
	if shown == "":
		return false
	hero_class = shown
	return true


func _assign_next_uid(doc: Dictionary, highest: int) -> bool:
	var next_id := highest + 1
	if doc.has("next_uid"):
		if not _whole(doc["next_uid"]) or int(doc["next_uid"]) < 1:
			return false
		if int(doc["next_uid"]) > highest:
			next_id = int(doc["next_uid"])
	_uid = next_id
	return true


func _saved_kind(row: Dictionary) -> String:
	var def := item_def(str(row.get("item_id", "")))
	var fixed := str(def.get("rarity", ""))
	if fixed == "epic" or fixed == "relic":
		return fixed
	var rarity := str(row.get("rarity", ""))
	if rarity == "epic" or rarity == "relic":
		return rarity
	return ""


func _read_stack(raw: Variant, into: Array, seen: Dictionary) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var row: Dictionary = entry
		if typeof(row.get("item_id", null)) != TYPE_STRING or str(row["item_id"]) == "":
			return false
		if item_def(str(row["item_id"])).is_empty():
			return false
		if typeof(row.get("rarity", null)) != TYPE_STRING:
			return false
		if not _whole(row.get("count", null)) or int(row["count"]) < 1:
			return false
		if not _whole(row.get("uid", null)) or int(row["uid"]) < 1:
			return false
		var uid := int(row["uid"])
		if seen.has(uid):
			return false
		seen[uid] = true
		into.append({
			"uid": uid,
			"item_id": str(row["item_id"]),
			"rarity": str(row["rarity"]),
			"count": int(row["count"]),
			"upgrade": int(row.get("upgrade", 0)) if _whole(row.get("upgrade", 0)) else 0,
		})
	return true


static func _check_rewards(doc: Dictionary, errors: Array) -> void:
	_unknown(doc, REWARD_KEYS, errors, "level rewards")
	if str(doc.get("format", "")) != REWARDS_FORMAT:
		_err(errors, "rewards format must be %s" % REWARDS_FORMAT)
	if not _whole(doc.get("format_version", null)) or int(doc.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "rewards format_version must be %d" % FORMAT_VERSION)
	if str(doc.get("status", "")) != "proposed":
		_err(errors, "rewards status must be proposed")
	if not _whole(doc.get("points_per_level", null)) or int(doc.get("points_per_level", -1)) < 0:
		_err(errors, "points_per_level must be a non-negative integer")
	var stats: Variant = doc.get("stats", null)
	if typeof(stats) != TYPE_ARRAY or (stats as Array).size() != STAT_NAMES.size():
		_err(errors, "stats must be the four characteristic buckets")
	else:
		for i in STAT_NAMES.size():
			if str(stats[i]) != STAT_NAMES[i]:
				_err(errors, "stats must be Mastery, Vitality, Swift, Resist")
				break
	var per: Variant = doc.get("stat_per_point", null)
	if typeof(per) != TYPE_DICTIONARY:
		_err(errors, "stat_per_point must be an object")
	else:
		_check_per_point(per, errors)
	if not _open_or_map(doc.get("class_hp_per_level", null)):
		_err(errors, "class_hp_per_level must be Open or an object")
	_check_milestones(doc.get("milestones", null), errors)
	_check_titles(doc.get("titles", null), errors)
	_check_respec(doc.get("respec", null), errors)
	_check_sheet(doc.get("sheet", null), errors)
	_check_duel(doc.get("koliseo_duel", null), errors)


static func _check_milestones(value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_ARRAY:
		_err(errors, "milestones must be an array")
		return
	for row in value:
		if typeof(row) != TYPE_DICTIONARY:
			_err(errors, "milestone must be an object")
			continue
		_unknown(row, ["level", "ap"], errors, "milestone")
		if not _whole(row.get("level", null)) or int(row.get("level", 0)) < 1:
			_err(errors, "milestone level must be a positive integer")
		if not _whole(row.get("ap", null)) or int(row.get("ap", 0)) < 1:
			_err(errors, "milestone ap must be a positive integer")


static func _check_titles(value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_ARRAY:
		_err(errors, "titles must be an array")
		return
	for row in value:
		if typeof(row) != TYPE_DICTIONARY:
			_err(errors, "title must be an object")
			continue
		_unknown(row, ["level", "name"], errors, "title")
		if not _whole(row.get("level", null)) or int(row.get("level", 0)) < 1:
			_err(errors, "title level must be a positive integer")
		if typeof(row.get("name", null)) != TYPE_STRING or str(row.get("name", "")) == "":
			_err(errors, "title name must be a non-empty string")


static func _check_per_point(per: Dictionary, errors: Array) -> void:
	for stat in STAT_NAMES:
		if not per.has(stat) or typeof(per[stat]) != TYPE_DICTIONARY:
			_err(errors, "stat_per_point %s must be an object" % stat)
	var mastery := _stat_row(per, "Mastery")
	var vitality := _stat_row(per, "Vitality")
	var resist := _stat_row(per, "Resist")
	var swift := _stat_row(per, "Swift")
	if not _rate(mastery.get("damage_done", null)) or not _rate(mastery.get("healing_done", null)):
		_err(errors, "Mastery needs damage_done and healing_done rates")
	if not _rate(vitality.get("max_hp", null)):
		_err(errors, "Vitality needs a max_hp rate")
	if not _rate(resist.get("damage_taken", null)) or not _rate(resist.get("cap", null)):
		_err(errors, "Resist needs a damage_taken rate and a cap")
	if not _whole(swift.get("initiative", null)) or int(swift.get("initiative", -1)) < 0:
		_err(errors, "Swift initiative must be a non-negative integer")
	if swift.has("bonus_damage") and not _rate(swift.get("bonus_damage", null)):
		_err(errors, "Swift bonus_damage must be a rate")
	if swift.has("follow_up"):
		_err(errors, "Swift follow_up is not a shipped effect")


static func _check_duel(value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_err(errors, "koliseo_duel must be an object")
		return
	_unknown(value, ["win_min", "win_max"], errors, "koliseo_duel")
	if not _rate(value.get("win_min", null)) or not _rate(value.get("win_max", null)):
		_err(errors, "koliseo win band must be two rates")
		return
	if float(value["win_min"]) >= float(value["win_max"]):
		_err(errors, "koliseo win_min must be below win_max")


static func _check_respec(value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_err(errors, "respec must be an object")
		return
	_unknown(value, ["free", "coin_per_level"], errors, "respec")
	if not _whole(value.get("free", null)) or int(value.get("free", -1)) < 0:
		_err(errors, "respec free must be a non-negative integer")
	if not _whole(value.get("coin_per_level", null)) or int(value.get("coin_per_level", -1)) < 0:
		_err(errors, "respec coin_per_level must be a non-negative integer")


static func _check_sheet(value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_err(errors, "sheet must be an object")
		return
	_unknown(value, ["hp", "ap", "mp", "initiative", "range_bonus", "caps"], errors, "sheet")
	for key in ["hp", "ap", "mp", "range_bonus"]:
		if not _whole(value.get(key, null)) or int(value.get(key, -1)) < 0:
			_err(errors, "sheet %s must be a non-negative integer" % key)
	if not _open_or_number(value.get("initiative", null)):
		_err(errors, "sheet initiative must be Open or a number")
	var caps: Variant = value.get("caps", null)
	if typeof(caps) != TYPE_DICTIONARY:
		_err(errors, "sheet caps must be an object")
		return
	_unknown(caps, ["ap", "mp", "range_bonus"], errors, "sheet caps")
	for key in ["ap", "mp", "range_bonus"]:
		if not _whole(caps.get(key, null)) or int(caps.get(key, -1)) < 0:
			_err(errors, "sheet cap %s must be a non-negative integer" % key)


static func _stat_row(per: Dictionary, stat: String) -> Dictionary:
	var value: Variant = per.get(stat, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value


static func _rate(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) >= 0.0


static func _open_or_number(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		return value == "Open"
	return _whole(value) and int(value) >= 0


static func _open_or_map(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		return value == "Open"
	return typeof(value) == TYPE_DICTIONARY


static func _fail(errors: Array) -> Dictionary:
	return {"ok": false, "reason": "invalid_level_curve", "errors": errors, "max_level": 0, "xp_to_next": []}


static func _fail_rewards(errors: Array) -> Dictionary:
	return {"ok": false, "reason": "invalid_level_rewards", "errors": errors, "doc": {}}
