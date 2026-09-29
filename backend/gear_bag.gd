class_name GearBag
extends RefCounted

## Mobile gear (Blueprint §9 daily limits, §10 six set families).
## Six families only — do not add a seventh. All-class, no off-class tax.
## Slots: weapon (Mastery), head (HP), chest (HP + resist), legs (resist),
## boots (Init). Per-item stat numbers live in Mobile_Sets.xlsx and are NOT
## in this file; only the Locked set bonuses and rules below are.
## Fuse: same item_id + same plus → plus+1, cap +5.
## Attune at 2 equipped pieces of a family: Air / Earth / Fire / Water.
## AP/MP: base 6/3 + Duskbrand 5pc + weapon .ap + boots .mp + rare gate,
## clamped to 8/5. Extra sources grey out.
## Stasis loot clears: 5 per UTC day shared across all five doors; clear 6+
## is allowed, chest empty (Soft Lock).
## Mauro 29 Sep 2026: gear counts in Koliseo PvP and in Stasis. Fights
## receive fight_gear() and CombatSim applies combat_stats(). Per-item
## numbers (Mobile_Sets.xlsx) are still missing, so only set bonuses count.

const SLOTS: Array[String] = ["weapon", "head", "chest", "legs", "boots"]
const SLOT_STAT := {
	"weapon": "Mastery", "head": "HP", "chest": "HP + resist", "legs": "resist", "boots": "Init",
}
const ELEMENTS: Array[String] = ["Air", "Earth", "Fire", "Water"]
const PLUS_CAP := 5
const ATTUNE_PIECES := 2
const BASE_AP := 6
const BASE_MP := 3
const AP_CAP := 8
const MP_CAP := 5
const LOOT_CLEARS_PER_DAY := 5
## Chest size for a Stasis 1 clear. Provisional: the Blueprint does not give
## the chest size (Stasis >1 chest loot is Open).
const STASIS_1_CHEST_PIECES := 1
const SECONDS_PER_DAY := 86400

## Blueprint §10. `bonus` tiers stack: 4 pieces also get the 2pc bonus.
## `stats` are the numeric parts; `effect` is the text-only 5pc rule.
const FAMILIES := {
	"sheaf": {
		"name": "Sheaf", "rarity": "Normal", "role": "Life", "source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+10% HP", 4: "+8 Mastery", 5: "+8% all resist"},
		"stats": {2: {"hp_pct": 10}, 4: {"mastery": 8}, 5: {"resist_pct": 8}},
	},
	"undertow": {
		"name": "Undertow", "rarity": "Normal", "role": "Tempo", "source": "Stasis ★1+", "min_star": 1,
		"bonus": {2: "+8 Init", 4: "+8 Mastery", 5: "Spend 1 MP: +10% dmg/heal"},
		"stats": {2: {"init": 8}, 4: {"mastery": 8}},
	},
	"ironveil": {
		"name": "Ironveil", "rarity": "Rare", "role": "Guard", "source": "Stasis ★3+", "min_star": 3,
		"bonus": {2: "+8% attuned resist", 4: "+12% HP", 5: "Once/fight delay 25% HIT on you"},
		"stats": {2: {"attuned_resist_pct": 8}, 4: {"hp_pct": 12}},
	},
	"stillcut": {
		"name": "Stillcut", "rarity": "Rare", "role": "Cut", "source": "Stasis ★3+", "min_star": 3,
		"bonus": {2: "+8% FLEX", 4: "+8 Mastery", 5: "First FLEX HIT of fight +15%"},
		"stats": {2: {"flex_pct": 8}, 4: {"mastery": 8}, 5: {"first_flex_pct": 15}},
	},
	"brightedge": {
		"name": "Brightedge", "rarity": "Legendary", "role": "Pressure", "source": "Stasis ★5 / boss", "min_star": 5,
		"bonus": {2: "+8% FLEX", 4: "+12 Mastery", 5: "FLEX HIT: 4 Neutral chip"},
		"stats": {2: {"flex_pct": 8}, 4: {"mastery": 12}},
	},
	"duskbrand": {
		"name": "Duskbrand", "rarity": "Ultra", "role": "Power", "source": "Koliseo 60 coins", "min_star": 99,
		"bonus": {2: "+12% Mastery", 4: "+8% HP +6 Init", 5: "+1 AP and +1 MP"},
		"stats": {2: {"mastery_pct": 12}, 4: {"hp_pct": 8, "init": 6}, 5: {"ap": 1, "mp": 1}},
	},
}
## Mobile Startup Sets v0.3 (Mauro's sheet, 29 Sep 2026), "Parts" page:
## +0 numbers per part. Weapon = Mastery, head = HP, chest = HP + resist,
## legs = resist, boots = Init. Part resist is resist to the element that
## family is attuned to. Rare .ap/.mp variants (★4+) are not dropped yet.
const PARTS := {
	"sheaf.weapon": {"name": "Sheaf Hook", "hp": 0, "mastery": 8, "resist": 0, "init": 0},
	"sheaf.head": {"name": "Sheaf Helm", "hp": 28, "mastery": 2, "resist": 2, "init": 0},
	"sheaf.chest": {"name": "Sheaf Coat", "hp": 40, "mastery": 0, "resist": 3, "init": 0},
	"sheaf.legs": {"name": "Sheaf Guards", "hp": 16, "mastery": 0, "resist": 8, "init": 0},
	"sheaf.boots": {"name": "Sheaf Treads", "hp": 14, "mastery": 0, "resist": 2, "init": 3},
	"undertow.weapon": {"name": "Undertow Edge", "hp": 0, "mastery": 8, "resist": 0, "init": 3},
	"undertow.head": {"name": "Undertow Helm", "hp": 18, "mastery": 3, "resist": 2, "init": 3},
	"undertow.chest": {"name": "Undertow Plate", "hp": 26, "mastery": 2, "resist": 2, "init": 2},
	"undertow.legs": {"name": "Undertow Guards", "hp": 12, "mastery": 2, "resist": 4, "init": 2},
	"undertow.boots": {"name": "Undertow Treads", "hp": 8, "mastery": 2, "resist": 1, "init": 8},
	"brightedge.weapon": {"name": "Brightedge", "hp": 0, "mastery": 12, "resist": 0, "init": 0},
	"brightedge.head": {"name": "Gleam Helm", "hp": 16, "mastery": 6, "resist": 1, "init": 0},
	"brightedge.chest": {"name": "Gleam Coat", "hp": 22, "mastery": 6, "resist": 2, "init": 0},
	"brightedge.legs": {"name": "Gleam Guards", "hp": 10, "mastery": 4, "resist": 3, "init": 0},
	"brightedge.boots": {"name": "Gleam Treads", "hp": 6, "mastery": 4, "resist": 1, "init": 4},
	"ironveil.weapon": {"name": "Veil Bit", "hp": 0, "mastery": 7, "resist": 2, "init": 0},
	"ironveil.head": {"name": "Veil Casque", "hp": 26, "mastery": 1, "resist": 5, "init": 0},
	"ironveil.chest": {"name": "Veil Plate", "hp": 34, "mastery": 0, "resist": 6, "init": 0},
	"ironveil.legs": {"name": "Veil Guards", "hp": 18, "mastery": 0, "resist": 10, "init": 0},
	"ironveil.boots": {"name": "Veil Treads", "hp": 12, "mastery": 0, "resist": 4, "init": 3},
	"stillcut.weapon": {"name": "Second-Edge", "hp": 0, "mastery": 14, "resist": 0, "init": 0},
	"stillcut.head": {"name": "Stillcut Helm", "hp": 28, "mastery": 6, "resist": 4, "init": 0},
	"stillcut.chest": {"name": "Hourplate", "hp": 32, "mastery": 4, "resist": 5, "init": 0},
	"stillcut.legs": {"name": "Pause Greaves", "hp": 22, "mastery": 4, "resist": 7, "init": 0},
	"stillcut.boots": {"name": "Stride", "hp": 10, "mastery": 4, "resist": 2, "init": 8},
	"duskbrand.weapon": {"name": "Duskbrand", "hp": 0, "mastery": 10, "resist": 0, "init": 2},
	"duskbrand.head": {"name": "Dusk Helm", "hp": 16, "mastery": 4, "resist": 2, "init": 2},
	"duskbrand.chest": {"name": "Dusk Coat", "hp": 22, "mastery": 4, "resist": 2, "init": 1},
	"duskbrand.legs": {"name": "Dusk Guards", "hp": 12, "mastery": 3, "resist": 4, "init": 1},
	"duskbrand.boots": {"name": "Dusk Treads", "hp": 8, "mastery": 3, "resist": 1, "init": 6},
}
## Fuse ladder: plus 0..5 multiplies the part numbers.
const FUSE_MULT: Array[float] = [1.00, 1.12, 1.26, 1.41, 1.58, 1.78]
## Attune page. Stillcut has no default (player must pick); Duskbrand has no
## attune row, so its part resist stays Neutral.
const DEFAULT_ATTUNE := {"sheaf": "Earth", "undertow": "Air", "brightedge": "Fire", "ironveil": "Earth"}
## 2-piece attune rider: +% FLEX dmg/heal of the attuned element.
const ATTUNE_RIDER := {"sheaf": 10, "undertow": 10, "stillcut": 15, "brightedge": 10, "ironveil": 10}
## Designer knobs slot_w_*: weapon is rarer.
const SLOT_WEIGHT := {"weapon": 18.0, "head": 20.5, "chest": 20.5, "legs": 20.5, "boots": 20.5}
const FAMILY_ORDER: Array[String] = ["sheaf", "undertow", "ironveil", "stillcut", "brightedge", "duskbrand"]
## Rare plus gate (Ironveil / Stillcut only). Not per item.
const RARE_GATE_FAMILIES: Array[String] = ["ironveil", "stillcut"]

static var save_path: String = "user://gear_bag.json"

## [{"uid": int, "item_id": "sheaf.head", "plus": 0}]
var items: Array = []
## slot → uid
var equipped: Dictionary = {}
## family → element
var attune: Dictionary = {}
var next_uid: int = 1
var loot_day: int = -1
var loot_clears_today: int = 0


static func item_id_for(family: String, slot: String) -> String:
	return "%s.%s" % [family, slot]


static func family_of(item_id: String) -> String:
	return item_id.get_slice(".", 0)


static func slot_of(item_id: String) -> String:
	return item_id.get_slice(".", 1)


static func is_valid_item_id(item_id: String) -> bool:
	return FAMILIES.has(family_of(item_id)) and SLOTS.has(slot_of(item_id)) and item_id.count(".") == 1


static func item_label(item: Dictionary) -> String:
	var item_id := str(item.get("item_id", ""))
	var part: Dictionary = PARTS.get(item_id, {})
	var name := str(part.get("name", ""))
	if name == "":
		name = "%s %s" % [str(FAMILIES.get(family_of(item_id), {}).get("name", "?")), slot_of(item_id).capitalize()]
	return "%s +%d" % [name, int(item.get("plus", 0))]


## One part's numbers at its plus (fuse ladder), rounded.
static func part_stats(item_id: String, plus: int) -> Dictionary:
	var part: Dictionary = PARTS.get(item_id, {})
	var mult: float = FUSE_MULT[clampi(plus, 0, PLUS_CAP)]
	var out := {}
	for key in ["hp", "mastery", "resist", "init"]:
		out[key] = roundi(float(part.get(key, 0)) * mult)
	return out


## Short stat line for a part, e.g. "HP 28 · Mastery 2 · Resist 2".
static func part_line(item_id: String, plus: int) -> String:
	var st := part_stats(item_id, plus)
	var bits: Array[String] = []
	for key in ["hp", "mastery", "resist", "init"]:
		if int(st[key]) > 0:
			bits.append("%s %d" % [{"hp": "HP", "mastery": "Mastery", "resist": "Resist", "init": "Init"}[key], int(st[key])])
	return " · ".join(bits)


## The element a family's attune gives while 2+ pieces are worn: the
## player's pick, else the family default. "" = none (Neutral).
static func element_for(family: String, worn_count: int, attune_map: Dictionary) -> String:
	if worn_count < ATTUNE_PIECES:
		return ""
	var pick := str(attune_map.get(family, ""))
	if ELEMENTS.has(pick):
		return pick
	return str(DEFAULT_ATTUNE.get(family, ""))


static func utc_day(unix_seconds: int) -> int:
	return int(floor(float(unix_seconds) / float(SECONDS_PER_DAY)))


static func load_saved() -> GearBag:
	var bag := GearBag.new()
	if not FileAccess.file_exists(save_path):
		return bag
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return bag
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		bag.from_dict(parsed)
	return bag


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"equipped": equipped.duplicate(),
		"attune": attune.duplicate(),
		"next_uid": next_uid,
		"loot_day": loot_day,
		"loot_clears_today": loot_clears_today,
	}


func from_dict(data: Dictionary) -> void:
	items = []
	var top_uid := 0
	for raw in data.get("items", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item_id := str(raw.get("item_id", ""))
		if not is_valid_item_id(item_id):
			continue
		var uid := int(raw.get("uid", 0))
		if uid <= 0 or find(uid) != -1:
			continue
		items.append({"uid": uid, "item_id": item_id, "plus": clampi(int(raw.get("plus", 0)), 0, PLUS_CAP)})
		top_uid = maxi(top_uid, uid)
	next_uid = maxi(int(data.get("next_uid", 1)), top_uid + 1)
	equipped = {}
	var raw_eq: Variant = data.get("equipped", {})
	if typeof(raw_eq) == TYPE_DICTIONARY:
		for slot in raw_eq:
			var uid := int(raw_eq[slot])
			var index := find(uid)
			if SLOTS.has(str(slot)) and index != -1 and slot_of(str(items[index]["item_id"])) == str(slot):
				equipped[str(slot)] = uid
	attune = {}
	var raw_att: Variant = data.get("attune", {})
	if typeof(raw_att) == TYPE_DICTIONARY:
		for fam in raw_att:
			if FAMILIES.has(str(fam)) and ELEMENTS.has(str(raw_att[fam])):
				attune[str(fam)] = str(raw_att[fam])
	loot_day = int(data.get("loot_day", -1))
	loot_clears_today = maxi(int(data.get("loot_clears_today", 0)), 0)


func find(uid: int) -> int:
	for i in items.size():
		if int(items[i]["uid"]) == uid:
			return i
	return -1


func item(uid: int) -> Dictionary:
	var index := find(uid)
	return {} if index == -1 else (items[index] as Dictionary).duplicate()


func add_item(family: String, slot: String, plus: int = 0) -> int:
	var item_id := item_id_for(family, slot)
	if not is_valid_item_id(item_id):
		return -1
	var uid := next_uid
	next_uid += 1
	items.append({"uid": uid, "item_id": item_id, "plus": clampi(plus, 0, PLUS_CAP)})
	return uid


func count_of(item_id: String) -> int:
	var count := 0
	for it in items:
		if str(it["item_id"]) == item_id:
			count += 1
	return count


func is_equipped(uid: int) -> bool:
	return equipped.values().has(uid)


func equip(uid: int) -> Dictionary:
	var index := find(uid)
	if index == -1:
		return _fail("no_item")
	var slot := slot_of(str(items[index]["item_id"]))
	equipped[slot] = uid
	return {"ok": true, "reason": "", "slot": slot}


func unequip(slot: String) -> Dictionary:
	if not equipped.has(slot):
		return _fail("empty_slot")
	equipped.erase(slot)
	return {"ok": true, "reason": ""}


func equipped_item(slot: String) -> Dictionary:
	if not equipped.has(slot):
		return {}
	return item(int(equipped[slot]))


## Fuse b into a: same item_id and same plus, below the +5 cap.
func can_fuse(uid_a: int, uid_b: int) -> Dictionary:
	if uid_a == uid_b:
		return _fail("same_item")
	var a := item(uid_a)
	var b := item(uid_b)
	if a.is_empty() or b.is_empty():
		return _fail("no_item")
	if str(a["item_id"]) != str(b["item_id"]):
		return _fail("different_item")
	if int(a["plus"]) != int(b["plus"]):
		return _fail("different_plus")
	if int(a["plus"]) >= PLUS_CAP:
		return _fail("plus_cap")
	return {"ok": true, "reason": ""}


func fuse(uid_a: int, uid_b: int) -> Dictionary:
	var gate := can_fuse(uid_a, uid_b)
	if not bool(gate["ok"]):
		return gate
	var slot := slot_of(str(item(uid_a)["item_id"]))
	var b_worn: bool = int(equipped.get(slot, -1)) == uid_b
	items.remove_at(find(uid_b))
	var a_index := find(uid_a)
	items[a_index]["plus"] = int(items[a_index]["plus"]) + 1
	if b_worn:
		equipped[slot] = uid_a
	return {"ok": true, "reason": "", "uid": uid_a, "plus": int(items[a_index]["plus"])}


## A partner to fuse `uid` with (same item_id and plus, not itself), or -1.
## Prefers a partner that is not worn.
func fuse_partner(uid: int) -> int:
	var base := item(uid)
	if base.is_empty():
		return -1
	var worn_match := -1
	for it in items:
		var other := int(it["uid"])
		if other == uid or str(it["item_id"]) != str(base["item_id"]) or int(it["plus"]) != int(base["plus"]):
			continue
		if not is_equipped(other):
			return other
		worn_match = other
	return worn_match


func set_counts() -> Dictionary:
	var counts := {}
	for slot in equipped:
		var fam := family_of(str(item(int(equipped[slot])).get("item_id", "")))
		counts[fam] = int(counts.get(fam, 0)) + 1
	return counts


func can_attune(family: String, element: String) -> Dictionary:
	if not FAMILIES.has(family):
		return _fail("unknown_family")
	if not ELEMENTS.has(element):
		return _fail("unknown_element")
	if int(set_counts().get(family, 0)) < ATTUNE_PIECES:
		return _fail("needs_2_pieces")
	return {"ok": true, "reason": ""}


func set_attune(family: String, element: String) -> Dictionary:
	var gate := can_attune(family, element)
	if not bool(gate["ok"]):
		return gate
	attune[family] = element
	return {"ok": true, "reason": ""}


## The chosen element (or the family default) — only while 2+ pieces are worn.
## A pick is kept when pieces come off.
func attune_active(family: String) -> String:
	return element_for(family, int(set_counts().get(family, 0)), attune)


## [{family, pieces, tier, text}] for every reached tier, family order.
func active_bonuses() -> Array:
	var out: Array = []
	var counts := set_counts()
	for fam in FAMILY_ORDER:
		var pieces := int(counts.get(fam, 0))
		var bonus: Dictionary = FAMILIES[fam]["bonus"]
		for tier in [2, 4, 5]:
			if pieces >= tier:
				out.append({"family": fam, "pieces": pieces, "tier": tier, "text": str(bonus[tier])})
	return out


## Worn pieces as a plain list [{item_id, plus}] (one per slot). This is
## what a fight receives; CombatSim recomputes the stats from it.
func worn_list() -> Array:
	var out: Array = []
	for slot in SLOTS:
		var it := equipped_item(slot)
		if not it.is_empty():
			out.append({"item_id": str(it["item_id"]), "plus": int(it["plus"])})
	return out


## Sanitised worn list: valid ids, one per slot, plus 0–5, at most 5.
static func clean_worn(raw: Variant) -> Array:
	var out: Array = []
	var used := {}
	if not raw is Array:
		return out
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := str(entry.get("item_id", ""))
		if not is_valid_item_id(item_id):
			continue
		var slot := slot_of(item_id)
		if used.has(slot):
			continue
		used[slot] = true
		out.append({"item_id": item_id, "plus": clampi(int(entry.get("plus", 0)), 0, PLUS_CAP)})
	return out


static func worn_counts(worn: Array) -> Dictionary:
	var counts := {}
	for entry in worn:
		var fam := family_of(str(entry["item_id"]))
		counts[fam] = int(counts.get(fam, 0)) + 1
	return counts


static func stats_of_worn(worn: Array) -> Dictionary:
	var total := {}
	var counts := worn_counts(worn)
	for fam in FAMILY_ORDER:
		var pieces := int(counts.get(fam, 0))
		var stats: Dictionary = FAMILIES[fam]["stats"]
		for tier in [2, 4, 5]:
			if pieces >= tier and stats.has(tier):
				for key in stats[tier]:
					total[key] = int(total.get(key, 0)) + int(stats[tier][key])
	return total


static func gate_of_worn(worn: Array) -> Dictionary:
	var out := {"ap": 0, "mp": 0}
	for fam in RARE_GATE_FAMILIES:
		var pluses: Array[int] = []
		for entry in worn:
			if family_of(str(entry["item_id"])) == fam:
				pluses.append(int(entry["plus"]))
		if pluses.size() >= 4:
			var fours := 0
			for p in pluses:
				if p >= 4:
					fours += 1
			if fours >= 4:
				out["mp"] = 1
		if pluses.size() == 5 and pluses.min() >= 5:
			out["ap"] = 1
	return out


static func ap_mp_of_worn(worn: Array) -> Dictionary:
	var stats := stats_of_worn(worn)
	var gate := gate_of_worn(worn)
	var raw_ap := BASE_AP + int(stats.get("ap", 0)) + int(gate["ap"])
	var raw_mp := BASE_MP + int(stats.get("mp", 0)) + int(gate["mp"])
	return {
		"ap": mini(raw_ap, AP_CAP), "mp": mini(raw_mp, MP_CAP),
		"raw_ap": raw_ap, "raw_mp": raw_mp,
		"ap_greyed": maxi(raw_ap - AP_CAP, 0), "mp_greyed": maxi(raw_mp - MP_CAP, 0),
	}


## What a fight uses from worn gear (Mauro 29 Sep 2026: gear counts in
## Koliseo PvP and in Stasis). Part numbers × fuse multiplier, plus the set
## bonuses. Part resist goes to the family's attuned element (Neutral when
## under 2 pieces or no element). FLEX = any non-neutral damage/heal spell:
## set flex_pct + the 2-piece attune rider of that element.
## `flatten_plus`: Koliseo arena flatten — parts count as +0.
## Not applied yet: Init turn order, Undertow/Ironveil/Brightedge 5pc.
static func combat_stats(raw_worn: Variant, attune_map: Dictionary = {}, flatten_plus: bool = false) -> Dictionary:
	var worn := clean_worn(raw_worn)
	if flatten_plus:
		for entry in worn:
			entry["plus"] = 0
	var stats := stats_of_worn(worn)
	var apmp := ap_mp_of_worn(worn)
	var counts := worn_counts(worn)
	var hp_flat := 0
	var mastery_flat := int(stats.get("mastery", 0))
	var init := int(stats.get("init", 0))
	var resist_elem := {}
	for entry in worn:
		var item_id := str(entry["item_id"])
		var fam := family_of(item_id)
		var st := part_stats(item_id, int(entry["plus"]))
		hp_flat += int(st["hp"])
		mastery_flat += int(st["mastery"])
		init += int(st["init"])
		var element := element_for(fam, int(counts.get(fam, 0)), attune_map).to_lower()
		if element == "":
			element = "neutral"
		resist_elem[element] = int(resist_elem.get(element, 0)) + int(st["resist"])
	var riders := {}
	for fam in ATTUNE_RIDER:
		var element := element_for(fam, int(counts.get(fam, 0)), attune_map).to_lower()
		if element != "":
			riders[element] = int(riders.get(element, 0)) + int(ATTUNE_RIDER[fam])
	# Elements with an active 2-piece attune (Ward from levels uses these).
	var attuned: Array = []
	for fam in FAMILY_ORDER:
		var element := element_for(fam, int(counts.get(fam, 0)), attune_map).to_lower()
		if element != "" and not attuned.has(element):
			attuned.append(element)
	var veil := int(stats.get("attuned_resist_pct", 0))
	if veil > 0:
		var veil_el := element_for("ironveil", int(counts.get("ironveil", 0)), attune_map).to_lower()
		if veil_el != "":
			resist_elem[veil_el] = int(resist_elem.get(veil_el, 0)) + veil
	return {
		"hp_flat": hp_flat,
		"hp_pct": int(stats.get("hp_pct", 0)),
		"mastery": roundi(float(mastery_flat) * (1.0 + float(stats.get("mastery_pct", 0)) / 100.0)),
		"resist": int(stats.get("resist_pct", 0)),
		"resist_elem": resist_elem,
		"flex_pct": int(stats.get("flex_pct", 0)),
		"riders": riders,
		"attuned": attuned,
		"first_flex_pct": int(stats.get("first_flex_pct", 0)),
		"init": init,
		"ap": int(apmp["ap"]),
		"mp": int(apmp["mp"]),
	}


## Summed numeric set stats of what is worn (tiers stack).
func bonus_stats() -> Dictionary:
	return stats_of_worn(worn_list())


## Rare plus gate: 4 worn pieces of Ironveil or Stillcut all ≥+4 → +1 MP;
## 5 worn pieces all +5 → +1 AP.
func rare_gate() -> Dictionary:
	return gate_of_worn(worn_list())


## AP/MP after gear, clamped 8/5. Weapon .ap and boots .mp rare affixes are
## not dropped yet, so they add 0 here.
func ap_mp() -> Dictionary:
	return ap_mp_of_worn(worn_list())


## Sanitised fight gear from any source (a peer, a save): worn + attune.
static func clean_fight_gear(raw: Variant) -> Dictionary:
	var out := {"worn": [], "attune": {}}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	out["worn"] = clean_worn(raw.get("worn", []))
	var att: Variant = raw.get("attune", {})
	if typeof(att) == TYPE_DICTIONARY:
		for fam in att:
			if FAMILIES.has(str(fam)) and ELEMENTS.has(str(att[fam])):
				out["attune"][str(fam)] = str(att[fam])
	# One XII Still for this fight (StillVault); cleaned again by the sim.
	var still := StillVault.clean(raw.get("still", {}))
	if not still.is_empty():
		out["still"] = still
	# Levels ride along; CombatSim recomputes them with HeroProgress.combat_stats.
	var heroes: Variant = raw.get("heroes", {})
	if typeof(heroes) == TYPE_DICTIONARY:
		out["heroes"] = {}
		for class_id in heroes:
			if HeroProgress.GROWTH.has(str(class_id)) and typeof(heroes[class_id]) == TYPE_DICTIONARY:
				var lvl := clampi(int(heroes[class_id].get("level", 1)), 1, HeroProgress.MAX_LEVEL)
				out["heroes"][str(class_id)] = {"level": lvl, "spent": HeroProgress.clean_spent(heroes[class_id].get("spent", {}), lvl)}
	return out


## Everything a fight needs from this bag: {"worn": [...], "attune": {...}}.
func fight_gear(with_still: bool = false) -> Dictionary:
	var out := {"worn": worn_list(), "attune": attune.duplicate(), "heroes": HeroProgress.load_saved().fight_heroes()}
	if with_still:
		var still := StillVault.load_saved().fight_still()
		if not still.is_empty():
			out["still"] = still
	return out


func loot_clears_left(unix_seconds: int) -> int:
	if utc_day(unix_seconds) != loot_day:
		return LOOT_CLEARS_PER_DAY
	return maxi(LOOT_CLEARS_PER_DAY - loot_clears_today, 0)


## A Stasis door cleared. The first 5 clears of the UTC day open a chest of
## +0 pieces from the families that door's star can drop; clear 6+ is empty.
## `pick` is 0..1 values (tests pass fixed ones; the game passes randf).
func record_stasis_clear(unix_seconds: int, star: int = 1, pick: Callable = Callable()) -> Dictionary:
	var today := utc_day(unix_seconds)
	if today != loot_day:
		loot_day = today
		loot_clears_today = 0
	loot_clears_today += 1
	if loot_clears_today > LOOT_CLEARS_PER_DAY:
		return {"chest": false, "items": [], "clears_today": loot_clears_today}
	var pool: Array[String] = []
	for fam in FAMILY_ORDER:
		if int(FAMILIES[fam]["min_star"]) <= star:
			pool.append(fam)
	var dropped: Array = []
	for i in STASIS_1_CHEST_PIECES:
		if pool.is_empty():
			break
		var r1 := float(pick.call()) if pick.is_valid() else randf()
		var r2 := float(pick.call()) if pick.is_valid() else randf()
		var fam := pool[mini(int(r1 * pool.size()), pool.size() - 1)]
		var slot := weighted_slot(r2)
		var uid := add_item(fam, slot, 0)
		dropped.append(item(uid))
	return {"chest": true, "items": dropped, "clears_today": loot_clears_today}


## Slot for a 0..1 roll using the slot_w_* weights (weapon 18%, others 20.5%).
static func weighted_slot(roll: float) -> String:
	var total := 0.0
	for slot in SLOTS:
		total += float(SLOT_WEIGHT[slot])
	var at := clampf(roll, 0.0, 0.999999) * total
	for slot in SLOTS:
		at -= float(SLOT_WEIGHT[slot])
		if at < 0.0:
			return slot
	return SLOTS[SLOTS.size() - 1]


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
