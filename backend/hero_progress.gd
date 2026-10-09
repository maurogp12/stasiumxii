class_name HeroProgress
extends RefCounted

## Levels 1–30 per class (Mauro 29 Sep 2026, Characteristics sheet +
## Blueprint §18, Soft Lock).
## XP to the next level: 80 + 40 × (level − 1)  (1→2 = 80 … 29→30 = 1200,
## 18560 total to 30). 2 spend points per level-up (58 at level 30), split
## or stacked, into Mastery (+2),
## Vitality (+8 HP), Swift (+1 Init) or Ward (+2 resist, only the element of
## an active 2-piece attune). Inherent growth per level by class on top.
## +1 AP at level 20. AP/MP still cap 8/5. No WP.
## XP: Stasis clear 60 × star, Stasis clear with no chest 20, online Koliseo
## win 50, online loss 15, dummy 0. The 2-coin cap never cuts XP.
## Levels are per class: XP goes to the class that fought.

const MAX_LEVEL := 30
## Mauro spec (29 Sep 2026): each level-up grants 2 spend points.
const POINTS_PER_LEVEL := 2
const AP_LEVEL := 20
const BUCKETS: Array[String] = ["mastery", "vitality", "swift", "ward"]
const PER_POINT := {"mastery": 2, "vitality": 8, "swift": 1, "ward": 2}
const BUCKET_LABEL := {"mastery": "Mastery +2", "vitality": "Vitality +8 HP", "swift": "Swift +1 Init", "ward": "Ward +2 resist"}
## Inherent growth per level above 1: [Mastery, HP, Init, Ward].
## Init +1 per level for ALL five classes (+29 at 30) — Ironjaw and Bastion
## are not 0 (Mauro spec, 29 Sep 2026).
const GROWTH := {
	"kestrel": [2, 3, 1, 0],
	# Mauro 30 Sep 2026 balance: Ironjaw HP per level 6 → 5; Mastery per level 2 → 1.
	"ironjaw": [1, 5, 1, 1],
	"mender": [1, 5, 1, 1],
	# Mauro 30 Sep 2026 balance: Gloam HP per level 3 → 2.
	"gloam": [2, 2, 1, 0],
	"bastion": [1, 7, 1, 2],  # Mauro 1 Oct 2026 balance round 2: HP +7 per level (was +8)
}
const XP_STASIS_PER_STAR := 60
const XP_STASIS_NO_CHEST := 20
const XP_KOLISEO_WIN := 50
const XP_KOLISEO_LOSS := 15

static var save_path: String = "user://hero_progress.json"
const _TestLoadout := preload("res://backend/test_loadout.gd")

## class_id → {"xp": int (inside the current level), "level": int, "spent": {bucket: n}}
var classes: Dictionary = {}
## Leftover balance-test kit bookkeeping. The kit no longer grants, and
## sync_hero does not copy test_backup back (ProgressEpoch owns the fresh start).
var test_backup: Dictionary = {}
var test_grant: bool = false


static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return 80 + 40 * (maxi(level, 1) - 1)


static func total_xp_to(level: int) -> int:
	var total := 0
	for l in range(1, clampi(level, 1, MAX_LEVEL)):
		total += xp_to_next(l)
	return total


static func load_saved() -> HeroProgress:
	ProgressEpoch.ensure()
	var hero := HeroProgress.new()
	if not FileAccess.file_exists(save_path):
		return _with_test_loadout(hero)
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return hero
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		hero.from_dict(parsed)
	return _with_test_loadout(hero)


## TEMPORARY (backend/test_loadout.gd): the real save only; tests use other paths.
static func _with_test_loadout(hero: HeroProgress) -> HeroProgress:
	if save_path == _TestLoadout.DEFAULT_HERO_PATH and _TestLoadout.sync_hero(hero):
		hero.save()
	return hero


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"classes": classes, "test_grant": test_grant, "test_backup": test_backup}, "\t"))
	return true


func from_dict(data: Dictionary) -> void:
	test_grant = bool(data.get("test_grant", false))
	test_backup = (data.get("test_backup", {}) as Dictionary).duplicate(true) if typeof(data.get("test_backup", {})) == TYPE_DICTIONARY else {}
	classes = {}
	var raw: Variant = data.get("classes", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for class_id in raw:
		if not GROWTH.has(str(class_id)) or typeof(raw[class_id]) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = raw[class_id]
		var level := clampi(int(rec.get("level", 1)), 1, MAX_LEVEL)
		var xp := clampi(int(rec.get("xp", 0)), 0, maxi(xp_to_next(level) - 1, 0))
		classes[str(class_id)] = {"xp": xp, "level": level, "spent": clean_spent(rec.get("spent", {}), level)}
		var picked := clean_elements(str(class_id), rec.get("elements", {}))
		if not picked.is_empty():
			classes[str(class_id)]["elements"] = picked


func record(class_id: String) -> Dictionary:
	var id := str(class_id)
	if not classes.has(id):
		classes[id] = {"xp": 0, "level": 1, "spent": {}}
	return classes[id]


func level_of(class_id: String) -> int:
	return int(record(class_id)["level"]) if GROWTH.has(class_id) else 1


func xp_of(class_id: String) -> int:
	return int(record(class_id)["xp"]) if GROWTH.has(class_id) else 0


func points_free(class_id: String) -> int:
	if not GROWTH.has(class_id):
		return 0
	var rec := record(class_id)
	var used := 0
	for b in rec["spent"]:
		used += int(rec["spent"][b])
	return maxi((int(rec["level"]) - 1) * POINTS_PER_LEVEL - used, 0)


## Adds XP to one class. Returns {xp, level_before, level, levels_gained}.
func add_xp(class_id: String, amount: int) -> Dictionary:
	if not GROWTH.has(class_id) or amount <= 0:
		return {"xp": 0, "level_before": level_of(class_id), "level": level_of(class_id), "levels_gained": 0}
	var rec := record(class_id)
	var before := int(rec["level"])
	var xp := int(rec["xp"]) + amount
	var level := before
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
	if level >= MAX_LEVEL:
		xp = 0
	rec["xp"] = xp
	rec["level"] = level
	return {"xp": amount, "level_before": before, "level": level, "levels_gained": level - before}


func spend(class_id: String, bucket: String) -> Dictionary:
	if not GROWTH.has(class_id):
		return {"ok": false, "reason": "unknown_class"}
	if not BUCKETS.has(bucket):
		return {"ok": false, "reason": "unknown_bucket"}
	if points_free(class_id) <= 0:
		return {"ok": false, "reason": "no_points"}
	var spent: Dictionary = record(class_id)["spent"]
	spent[bucket] = int(spent.get(bucket, 0)) + 1
	return {"ok": true, "reason": ""}


## Mauro 6 Oct 2026: "do a option to reset level characteristics". Every
## point spent on this class comes back as free points. Free of charge.
## Returns {ok, refunded}.
func reset_points(class_id: String) -> Dictionary:
	if not GROWTH.has(class_id):
		return {"ok": false, "reason": "unknown_class", "refunded": 0}
	var rec := record(class_id)
	var refunded := 0
	for b in rec["spent"]:
		refunded += int(rec["spent"][b])
	rec["spent"] = {}
	return {"ok": refunded > 0, "reason": "" if refunded > 0 else "nothing_spent", "refunded": refunded}


## What a fight receives: {"class_id", "level", "spent", "elements"}.
func fight_hero(class_id: String) -> Dictionary:
	if not GROWTH.has(class_id):
		return {}
	var rec := record(class_id)
	return {"class_id": class_id, "level": int(rec["level"]), "spent": (rec["spent"] as Dictionary).duplicate(), "elements": spell_elements(class_id)}


## Every class: {class_id: {level, spent, elements}}. A fight picks the entry
## for the class the seat plays. "elements" is that class's spell → element
## map (empty until the player picks: its FLEX spells fight Neutral).
func fight_heroes() -> Dictionary:
	var out := {}
	for class_id in GROWTH:
		var rec := record(class_id)
		out[class_id] = {"level": int(rec["level"]), "spent": (rec["spent"] as Dictionary).duplicate(), "elements": spell_elements(class_id)}
	return out


## ---- Elements Step 3 (Mauro 5 Oct 2026) -----------------------------------
## "everyone can change elements and build combos as they like in order to
## change elements they would need trophies each change its 2 trophies ...
## only 2 elements can be selected in whatever spell they want"; "there is no
## primary". Each class keeps its own pick: {"pair": [a, b], "spells": {id: a|b}}.
## The first pick is free; changing the pair costs 2 trophies. Moving a spell
## between the two picked elements is free.

## {"pair": [a, b], "spells": {spell_id: element}} or {} (not picked yet).
func elements_of(class_id: String) -> Dictionary:
	if not GROWTH.has(class_id):
		return {}
	var picked: Variant = record(class_id).get("elements", {})
	return (picked as Dictionary).duplicate(true) if typeof(picked) == TYPE_DICTIONARY else {}


func spell_elements(class_id: String) -> Dictionary:
	return (elements_of(class_id).get("spells", {}) as Dictionary).duplicate()


## Trophies this pick would cost (0 for the first pick or the same pair).
func element_change_cost(class_id: String, pair: Array) -> int:
	var old: Array = elements_of(class_id).get("pair", [])
	if old.size() != 2:
		return 0
	var a := pair.duplicate()
	a.sort()
	var b := old.duplicate()
	b.sort()
	return 0 if a == b else SpellKits.ELEMENT_CHANGE_TROPHIES


## Mauro 6 Oct 2026: "put for now a reset button on the elements so i can try
## every single one". Clears the class's pick; the next pick is free again
## (first pick rule). A testing aid for now.
func reset_elements(class_id: String) -> bool:
	if not GROWTH.has(class_id):
		return false
	var rec := record(class_id)
	if not rec.has("elements"):
		return false
	rec.erase("elements")
	return true


## Saves a pick. `spells` may leave spells out: they take the first element.
## `wallet` pays the change (KoliseoWallet; the caller saves both files).
## Returns {"ok", "reason", "cost"}.
func set_elements(class_id: String, pair: Array, spells: Dictionary, wallet: Variant) -> Dictionary:
	if not GROWTH.has(class_id):
		return {"ok": false, "reason": "unknown_class", "cost": 0}
	var raw := {"pair": pair, "spells": spells}
	var picked := clean_elements(class_id, raw)
	if picked.is_empty():
		return {"ok": false, "reason": "pick_two", "cost": 0}
	var cost := element_change_cost(class_id, picked["pair"])
	if cost > 0:
		if wallet == null or int(wallet.trophies) < cost:
			return {"ok": false, "reason": "no_trophies", "cost": cost}
		wallet.trophies = int(wallet.trophies) - cost
	record(class_id)["elements"] = picked
	return {"ok": true, "reason": "", "cost": cost}


## Two different elements from SpellKits.ELEMENTS, every FLEX spell of the
## class set to one of them. Anything else → {}.
static func clean_elements(class_id: String, raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var pair_raw: Variant = (raw as Dictionary).get("pair", [])
	if typeof(pair_raw) != TYPE_ARRAY or (pair_raw as Array).size() != 2:
		return {}
	var pair: Array = []
	for e in pair_raw:
		var el := str(e).to_lower()
		if not SpellKits.ELEMENTS.has(el) or pair.has(el):
			return {}
		pair.append(el)
	var spells_raw: Variant = (raw as Dictionary).get("spells", {})
	var spells := {}
	for id in SpellKits.flex_spells(class_id):
		var el: String = str(pair[0])
		if typeof(spells_raw) == TYPE_DICTIONARY and pair.has(str((spells_raw as Dictionary).get(id, "")).to_lower()):
			el = str(spells_raw[id]).to_lower()
		spells[id] = el
	return {"pair": pair, "spells": spells}


## Spent points cleaned: known buckets, 0+, total never above 2 × (level − 1).
static func clean_spent(raw: Variant, level: int) -> Dictionary:
	var out := {}
	var room := maxi(clampi(level, 1, MAX_LEVEL) - 1, 0) * POINTS_PER_LEVEL
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for b in BUCKETS:
		var n := mini(maxi(int(raw.get(b, 0)), 0), room)
		if n > 0:
			out[b] = n
			room -= n
	return out


## Combat numbers from a level + spend (sanitised; the host recomputes).
## Returns {mastery, hp, init, ward, ap}.
static func combat_stats(raw: Variant, class_id: String) -> Dictionary:
	var out := {"mastery": 0, "hp": 0, "init": 0, "ward": 0, "ap": 0, "level": 1}
	if typeof(raw) != TYPE_DICTIONARY or not GROWTH.has(class_id):
		return out
	var level := clampi(int(raw.get("level", 1)), 1, MAX_LEVEL)
	var spent := clean_spent(raw.get("spent", {}), level)
	var grow: Array = GROWTH[class_id]
	var steps := level - 1
	out["level"] = level
	out["mastery"] = int(grow[0]) * steps + int(spent.get("mastery", 0)) * int(PER_POINT["mastery"])
	out["hp"] = int(grow[1]) * steps + int(spent.get("vitality", 0)) * int(PER_POINT["vitality"])
	out["init"] = int(grow[2]) * steps + int(spent.get("swift", 0)) * int(PER_POINT["swift"])
	out["ward"] = int(grow[3]) * steps + int(spent.get("ward", 0)) * int(PER_POINT["ward"])
	out["ap"] = 1 if level >= AP_LEVEL else 0
	return out


static func stasis_xp(star: int, chest: bool) -> int:
	return XP_STASIS_PER_STAR * clampi(star, 1, 5) if chest else XP_STASIS_NO_CHEST
