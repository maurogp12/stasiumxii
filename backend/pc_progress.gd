extends RefCounted

## PC hero level from 1 to max_level in level_curve.json, plus the points,
## respec, and milestone flag from level_rewards.json (spec 4.11).
## Per-point combat values stay in that file. This script does not import
## phone level code. Loaded with preload. No global class.

const Duel = preload("res://backend/pc_duel.gd")
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


func _init() -> void:
	var curve := load_curve()
	if bool(curve.get("ok", false)):
		max_level = int(curve["max_level"])
		xp_to_next = curve["xp_to_next"]
		curve_ok = true
	_apply_rewards(load_rewards())
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


func sheet_view() -> Dictionary:
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
		"ap": base_ap + milestone_ap(),
		"ap_from_milestones": milestone_ap(),
		"mp": base_mp,
		"initiative": sheet.get("initiative", "Open"),
		"range_bonus": sheet.get("range_bonus", "Open"),
		"caps": caps,
		"titles": titles(),
		"respecs_used": respecs_used,
		"free_respecs": free_respecs,
		"respec_cost": next_respec_cost(),
		"initiative_from_swift": _swift_initiative(),
		"coins": coins,
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
	level = next_level
	xp = next_xp
	if not _apply_saved_spend(doc):
		level = prev_level
		xp = prev_xp
		spent = prev_spent
		respecs_used = prev_respecs
		coins = prev_coins
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
	if swift.has("follow_up") and not _rate(swift.get("follow_up", null)):
		_err(errors, "Swift follow_up must be a rate")


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
