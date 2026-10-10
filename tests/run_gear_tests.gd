extends SceneTree

## Mobile gear (Blueprint §9 + §10) and the Stasis chest.
## Run: godot --headless --path . -s res://tests/run_gear_tests.gd

const TEST_BAG := "user://test_gear_bag.json"
const DAY := 86400
const T0 := 20000 * DAY + 43200

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	GearBag.save_path = TEST_BAG
	HeroProgress.save_path = "user://test_hero_run_gear_tests.json"
	StillVault.save_path = "user://test_still_run_gear_tests.json"
	_wipe()
	_test_families_and_slots()
	_test_equip()
	_test_fuse()
	_test_attune()
	_test_set_bonuses()
	_test_ap_mp_clamp()
	_test_stasis_loot()
	_test_loot_by_star()
	_test_drop_chances()
	_test_temporary_kit()
	_test_save_roundtrip()
	_test_gear_screen()
	_test_stasis_chest_wiring()
	_test_combat_result()
	_test_gear_in_fights()
	_test_loadouts()
	_test_crit_cap_and_stun()
	_wipe()
	print("Gear tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_families_and_slots() -> void:
	eq(GearBag.FAMILY_ORDER.size(), 17, "five classes × 3 plus Ashmantle and Brightedge")
	eq(GearBag.FAMILIES.size(), 22, "seventeen ladder families plus five Ultra sets")
	eq(GearBag.FAMILIES.has("duskbrand"), false, "Duskbrand is gone")
	eq(GearBag.is_valid_item_id("duskbrand.weapon"), false, "Duskbrand is not a valid item")
	eq(GearBag.SLOTS, ["weapon", "head", "chest", "legs", "boots"], "five slots")
	eq(GearBag.ELEMENTS, ["Air", "Earth", "Fire", "Water"], "four attune elements")
	eq(str(GearBag.FAMILIES["ashmantle"]["rarity"]), "Normal", "Ashmantle is the shared Normal")
	eq(str(GearBag.FAMILIES["ashmantle"]["owner"]), "", "Ashmantle fits any class")
	eq(str(GearBag.FAMILIES["brightedge"]["rarity"]), "Legendary", "Brightedge is the shared Legendary")
	eq(str(GearBag.FAMILIES["oathgrave"]["owner"]), "bastion", "Oathgrave is Bastion")
	eq(str(GearBag.FAMILIES["ravenmourn"]["owner"]), "kestrel", "Ravenmourn is Kestrel")
	eq(str(GearBag.FAMILIES["tyrantjaw"]["owner"]), "ironjaw", "Tyrantjaw is Ironjaw")
	eq(str(GearBag.FAMILIES["gravewhisper"]["owner"]), "gloam", "Gravewhisper is Gloam")
	eq(str(GearBag.FAMILIES["hallowmourn"]["owner"]), "mender", "Hallowmourn is Mender")
	eq(GearBag.is_valid_item_id("sheaf.head"), true, "sheaf.head is valid")
	eq(GearBag.is_valid_item_id("wheat.head"), false, "unknown family rejected")
	eq(GearBag.is_valid_item_id("sheaf.cape"), false, "unknown slot rejected")
	for fam in GearBag.FAMILY_ORDER:
		var rarity := str(GearBag.FAMILIES[fam]["rarity"])
		var budget := 60 if rarity == "Normal" else (70 if rarity == "Rare" else 77)
		eq(GearBag.budget_points(fam), budget, "%s %s budget is %d" % [fam, rarity, budget])


func _test_equip() -> void:
	var bag := GearBag.new()
	var a := bag.add_item("undertow", "head")
	var b := bag.add_item("gallowsight", "head")
	eq(bool(bag.equip(a)["ok"]), true, "wear a head")
	eq(int(bag.equipped["head"]), a, "head slot holds it")
	bag.equip(b)
	eq(int(bag.equipped["head"]), b, "a new head replaces the old one")
	eq(bag.is_equipped(a), false, "old head back in the bag")
	var foreign := bag.add_item("sheaf", "chest")
	eq(str(bag.equip(foreign, "kestrel")["reason"]), "wrong_class", "Sheaf will not equip on Kestrel")
	eq(bool(bag.equip(bag.add_item("brightedge", "weapon"), "bastion")["ok"]), true, "Brightedge fits Bastion")
	eq(bool(bag.unequip("head", "kestrel")["ok"]), true, "take off the head")
	eq(str(bag.unequip("head", "kestrel")["reason"]), "empty_slot", "nothing left to take off")
	eq(str(bag.equip(999)["reason"]), "no_item", "unknown item")


func _test_fuse() -> void:
	var bag := GearBag.new()
	var a := bag.add_item("sheaf", "weapon")
	var b := bag.add_item("sheaf", "weapon")
	var c := bag.add_item("sheaf", "head")
	eq(str(bag.can_fuse(a, c)["reason"]), "different_item", "fuse needs the same item_id")
	eq(str(bag.can_fuse(a, a)["reason"]), "same_item", "cannot fuse with itself")
	bag.equip(b)
	eq(bag.fuse_partner(a), b, "partner found")
	var fused := bag.fuse(a, b)
	eq(bool(fused["ok"]), true, "two +0 fuse")
	eq(int(bag.item(a)["plus"]), 1, "result is +1")
	eq(bag.find(b), -1, "the second copy is burned")
	eq(int(bag.equipped["weapon"]), a, "a worn copy that burns hands its slot to the result")
	var d := bag.add_item("sheaf", "weapon")
	eq(str(bag.can_fuse(a, d)["reason"]), "different_plus", "fuse needs the same plus")
	# One slot to +5 burns 32 × +0 (Blueprint §10).
	var fresh := GearBag.new()
	for i in 32:
		fresh.add_item("undertow", "boots")
	var rounds := 0
	while true:
		var did := false
		for it in fresh.items.duplicate():
			var uid := int(it["uid"])
			if fresh.find(uid) == -1:
				continue
			var partner := fresh.fuse_partner(uid)
			if partner != -1 and bool(fresh.can_fuse(uid, partner)["ok"]):
				fresh.fuse(uid, partner)
				did = true
		rounds += 1
		if not did or rounds > 40:
			break
	eq(fresh.items.size(), 1, "32 × +0 become one item")
	eq(int(fresh.items[0]["plus"]), 5, "32 × +0 make +5")
	var top := int(fresh.items[0]["uid"])
	var extra := fresh.add_item("undertow", "boots", 5)
	eq(str(fresh.can_fuse(top, extra)["reason"]), "plus_cap", "+5 is the cap")


func _test_attune() -> void:
	var bag := GearBag.new()
	bag.equip(bag.add_item("ironveil", "head"))
	bag.equip(bag.add_item("ironveil", "chest"))
	eq(str(bag.set_attune("ironveil", "Fire")["reason"]), "no_attune", "the ladder has no attune")
	eq(bag.attune_active("ironveil"), "", "no element is active")


func _test_set_bonuses() -> void:
	var bag := GearBag.new()
	for slot in ["weapon", "head", "chest", "legs"]:
		bag.equip(bag.add_item("sheaf", slot))
	var tiers: Array = []
	for bonus in bag.active_bonuses():
		tiers.append([bonus["family"], bonus["tier"], bonus["text"]])
	eq(tiers, [["sheaf", 2, "+10% HP"], ["sheaf", 4, "Heals +6"]], "4 Sheaf pieces give the 2pc and 4pc bonuses")
	eq(bag.bonus_stats(), {"hp_pct": 10, "heal_flat": 6}, "Sheaf 4pc stats stack")
	bag.equip(bag.add_item("sheaf", "boots"))
	eq(bag.bonus_stats(), {"hp_pct": 10, "heal_flat": 6, "resist": 4}, "Sheaf 5pc adds +4 Resist")
	var mixed := GearBag.new()
	mixed.equip(mixed.add_item("sheaf", "weapon"))
	mixed.equip(mixed.add_item("undertow", "head"))
	eq(mixed.active_bonuses().size(), 0, "1 + 1 pieces give nothing")


func _test_ap_mp_clamp() -> void:
	var bag := GearBag.new()
	eq(bag.ap_mp()["ap"], 6, "base 6 AP")
	eq(bag.ap_mp()["mp"], 3, "base 3 MP")
	for slot in GearBag.SLOTS:
		bag.equip(bag.add_item("brightedge", slot))
	eq(bag.ap_mp()["ap"], 7, "Brightedge 5pc +1 AP")
	eq(bag.ap_mp()["mp"], 4, "Brightedge 5pc +1 MP")
	# Rare gate: +5 weapon → +1 AP, +5 boots → +1 MP. +4 does nothing.
	var rare := GearBag.new()
	rare.equip(rare.add_item("stillcut", "weapon", 4))
	rare.equip(rare.add_item("stillcut", "boots", 4))
	eq(rare.rare_gate(), {"ap": 0, "mp": 0}, "+4 rare pieces do not open the gate")
	rare.equip(rare.add_item("stillcut", "weapon", 5))
	eq(rare.rare_gate(), {"ap": 1, "mp": 0}, "Rare +5 weapon → +1 AP")
	rare.equip(rare.add_item("stillcut", "boots", 5))
	eq(rare.rare_gate(), {"ap": 1, "mp": 1}, "Rare +5 boots → +1 MP")
	var normal := GearBag.new()
	normal.equip(normal.add_item("nightglass", "weapon", 5))
	normal.equip(normal.add_item("nightglass", "boots", 5))
	eq(normal.rare_gate(), {"ap": 0, "mp": 0}, "a Normal +5 does not open the gate")
	var flat := GearBag.combat_stats(_worn("stillcut", ["weapon", "boots"], 5), {}, true, "gloam")
	eq([int(flat["ap"]), int(flat["mp"])], [6, 3], "Koliseo flatten closes the +5 gates")
	var legend := GearBag.combat_stats(_worn("gravewhisper", GearBag.SLOTS), {}, true, "gloam")
	eq([int(legend["ap"]), int(legend["mp"])], [7, 4], "Legendary 5pc +1/+1 survives flatten")
	eq(GearBag.AP_CAP, 8, "AP clamp 8")
	eq(GearBag.MP_CAP, 5, "MP clamp 5")
	var over := rare.ap_mp()
	eq(int(over["ap"]) <= 8 and int(over["mp"]) <= 5, true, "never above 8/5")


func _test_stasis_loot() -> void:
	var bag := GearBag.new()
	var picks := [0.0, 0.0, 0.99, 0.99, 0.5, 0.3, 0.1, 0.9, 0.7, 0.2]
	var i := [0]
	var pick := func() -> float:
		var v: float = picks[i[0] % picks.size()]
		i[0] += 1
		return v
	eq(bag.loot_clears_left(T0), 5, "5 loot clears a day")
	var first := bag.record_stasis_clear(T0, 1, pick)
	eq(bool(first["chest"]), true, "first clear opens a chest")
	eq(first["items"].size(), 1, "Stasis 1 chest holds one piece")
	eq(str(first["items"][0]["item_id"]), "ashmantle.boots", "★1 picks 0, 0, .99 = Ashmantle boots")
	eq(int(first["items"][0]["plus"]), 0, "drops are +0")
	var second := bag.record_stasis_clear(T0 + 10, 1, pick)
	eq(str(second["items"][0]["item_id"]), "cragmaw.head", "★1 picks .99, .5, .3 = Cragmaw head")
	var seen := {}
	for n in 3:
		var loot := bag.record_stasis_clear(T0 + 20 + n, 1, pick)
		for it in loot["items"]:
			seen[GearBag.family_of(str(it["item_id"]))] = true
	for fam in seen:
		eq(GearBag.families_for_star(1).has(fam), true, "★1 drops only Normals (%s)" % fam)
	eq(bag.loot_clears_left(T0 + 60), 0, "5 used")
	var sixth := bag.record_stasis_clear(T0 + 70, 1, pick)
	eq(bool(sixth["chest"]), false, "clear 6 is allowed but the chest is empty")
	eq(sixth["items"].size(), 0, "no items on clear 6")
	eq(bag.items.size(), 5, "5 pieces from 5 chests")
	eq(bag.loot_clears_left(T0 + DAY), 5, "next UTC day resets")
	eq(bool(bag.record_stasis_clear(T0 + DAY, 1, pick)["chest"]), true, "next day pays again")
	var never := GearBag.new()
	for n in 50:
		never.record_stasis_clear(T0 + n * DAY, 5)
	for it in never.items:
		eq(GearBag.FAMILIES.has(GearBag.family_of(str(it["item_id"]))), true, "Stasis only drops ladder families")
		eq(GearBag.family_of(str(it["item_id"])) != "duskbrand", true, "Stasis never drops Duskbrand")


## Mauro 29 Sep 2026: "dungs with 1 star should only loot normal gear, above
## 3 star is when start looting rare and only 5 legendary".
func _test_loot_by_star() -> void:
	var normals: Array = ["ashmantle", "rustward", "undertow", "cragmaw", "nightglass", "vesperwell"]
	var rares: Array = ["ironveil", "gallowsight", "maulgrave", "stillcut", "sheaf"]
	var legends: Array = ["oathgrave", "ravenmourn", "tyrantjaw", "gravewhisper", "hallowmourn", "brightedge"]
	eq(GearBag.families_for_star(1), normals, "★1 drops the Normals")
	eq(GearBag.families_for_star(2), normals, "★2 stays on the Normals")
	var up_to_rare: Array = normals.duplicate()
	up_to_rare.append_array(rares)
	eq(GearBag.families_for_star(3), up_to_rare, "★3 adds the Rares")
	eq(GearBag.families_for_star(4), up_to_rare, "★4 stays on Normal + Rare")
	var all: Array = up_to_rare.duplicate()
	all.append_array(legends)
	eq(GearBag.families_for_star(5), all, "★5 can drop every ladder family")
	for star in [1, 3, 5]:
		var bag := GearBag.new()
		var pool: Array = GearBag.families_for_star(int(star))
		var n := [0]
		var pick := func() -> float:
			n[0] += 1
			return fposmod(float(n[0]) * 0.1373, 1.0)
		for d in 24:
			for it in bag.record_stasis_clear(T0 + d * DAY, int(star), pick)["items"]:
				var fam := GearBag.family_of(str(it["item_id"]))
				eq(pool.has(fam), true, "★%d drop %s is in the pool" % [star, fam])
	eq(str(GearBag.FAMILIES["sheaf"]["rarity"]), "Rare", "Sheaf is Rare")
	eq(str(GearBag.FAMILIES["ironveil"]["rarity"]), "Rare", "Ironveil is Rare")
	eq(str(GearBag.FAMILIES["brightedge"]["rarity"]), "Legendary", "Brightedge is Legendary")
	eq(GearBag.families_for_star(5).has("brightedge"), true, "★5 can drop Brightedge")
	var a := GearBag.icon("sheaf.chest")
	eq(a != null, true, "Sheaf chest icon loads")
	eq(a == GearBag.icon("sheaf.chest"), true, "icons are cached so result/inventory draws keep them alive")


## Mauro locked the chest odds: tier first, then a family of that tier, then a slot.
## ★2 uses ★1, ★4 uses ★3. Boss is its own row. Ultra never drops.
func _test_drop_chances() -> void:
	eq(GearBag.drop_weights(1), {"Normal": 100, "Rare": 0, "Legendary": 0}, "★1 is 100% Normal")
	eq(GearBag.drop_weights(2), GearBag.drop_weights(1), "★2 uses the ★1 table")
	eq(GearBag.drop_weights(3), {"Normal": 70, "Rare": 30, "Legendary": 0}, "★3 is 70% Normal, 30% Rare")
	eq(GearBag.drop_weights(4), GearBag.drop_weights(3), "★4 uses the ★3 table")
	eq(GearBag.drop_weights(5), {"Normal": 60, "Rare": 30, "Legendary": 10}, "★5 is 60/30/10")
	eq(GearBag.drop_weights(5, true), {"Normal": 50, "Rare": 30, "Legendary": 20}, "boss is 50/30/20")
	eq(GearBag.drop_weights(1, true), GearBag.drop_weights(5, true), "the boss row ignores the door star")
	eq(GearBag.roll_tier(GearBag.drop_weights(1), 0.99), "Normal", "★1 has no other tier")
	eq(GearBag.roll_tier(GearBag.drop_weights(3), 0.699), "Normal", "★3 stays Normal under 70%")
	eq(GearBag.roll_tier(GearBag.drop_weights(3), 0.70), "Rare", "★3 becomes Rare at 70%")
	eq(GearBag.roll_tier(GearBag.drop_weights(5), 0.899), "Rare", "★5 stays Rare under 90%")
	eq(GearBag.roll_tier(GearBag.drop_weights(5), 0.90), "Legendary", "★5 becomes Legendary at 90%")
	eq(GearBag.roll_tier(GearBag.drop_weights(1, true), 0.799), "Rare", "boss stays Rare under 80%")
	eq(GearBag.roll_tier(GearBag.drop_weights(1, true), 0.80), "Legendary", "boss becomes Legendary at 80%")
	eq(GearBag.roll_drop(1, _picks([0.0, 0.0, 0.0]))["item_id"], "ashmantle.weapon", "tier 0, family 0, slot 0 is Ashmantle weapon")
	eq(GearBag.roll_drop(1, _picks([0.0, 0.99, 0.99]))["item_id"], "vesperwell.boots", "a high Normal roll is still Vesperwell boots")
	eq(GearBag.roll_drop(3, _picks([0.95, 0.0, 0.0]))["item_id"], "ironveil.weapon", "★3 above 70% is the first Rare")
	eq(GearBag.roll_drop(5, _picks([0.95, 0.0, 0.0]))["item_id"], "oathgrave.weapon", "★5 above 90% is the first Legendary")
	eq(GearBag.roll_drop(1, _picks([0.85, 0.0, 0.0]), true)["item_id"], "oathgrave.weapon", "boss above 80% is Legendary")
	var wired := GearBag.new()
	var seq := [0.95, 0.0, 0.0]
	var at := [0]
	var pick := func() -> float:
		var v: float = seq[at[0]]
		at[0] += 1
		return v
	var got := wired.record_stasis_clear(T0, 5, pick)
	eq(str(got["items"][0]["item_id"]), "oathgrave.weapon", "the chest uses the same tier-then-family-then-slot roll")
	eq(int(got["items"][0]["plus"]), 0, "weighted drops stay +0")
	var ultras := ["gatewarden", "sandhawk", "pitmaw", "hushring", "mercywell"]
	for ultra in ultras:
		eq(GearBag.FAMILIES.has(ultra), true, "%s is a wired Ultra set" % ultra)
		eq(GearBag.FAMILY_ORDER.has(ultra), false, "%s stays off the drop ladder" % ultra)
		eq(GearBag.families_of_rarity("Legendary").has(ultra), false, "%s is not in the Legendary pool" % ultra)
	eq(_drop_sample(1, false, 64, 337)["ids"], _drop_sample(2, false, 64, 337)["ids"], "★2 repeats the ★1 sequence")
	eq(_drop_sample(3, false, 64, 337)["ids"], _drop_sample(4, false, 64, 337)["ids"], "★4 repeats the ★3 sequence")
	eq(_drop_sample(1, true, 64, 337)["ids"], _drop_sample(5, true, 64, 337)["ids"], "a boss chest repeats regardless of star")
	var trials := 8000
	var tables := [
		{"star": 1, "boss": false, "want": {"Normal": 100, "Rare": 0, "Legendary": 0}},
		{"star": 2, "boss": false, "want": {"Normal": 100, "Rare": 0, "Legendary": 0}},
		{"star": 3, "boss": false, "want": {"Normal": 70, "Rare": 30, "Legendary": 0}},
		{"star": 4, "boss": false, "want": {"Normal": 70, "Rare": 30, "Legendary": 0}},
		{"star": 5, "boss": false, "want": {"Normal": 60, "Rare": 30, "Legendary": 10}},
		{"star": 5, "boss": true, "want": {"Normal": 50, "Rare": 30, "Legendary": 20}},
		{"star": 1, "boss": true, "want": {"Normal": 50, "Rare": 30, "Legendary": 20}},
	]
	for spec in tables:
		var once := _drop_sample(int(spec["star"]), bool(spec["boss"]), trials, 337)
		var twice := _drop_sample(int(spec["star"]), bool(spec["boss"]), trials, 337)
		eq(once["ids"], twice["ids"], "★%d boss=%s repeats under the same seed" % [int(spec["star"]), bool(spec["boss"])])
		var want: Dictionary = spec["want"]
		for rarity in GearBag.RARITIES:
			_near_percent(int(once["rarity"].get(rarity, 0)), trials, int(want[rarity]), "★%d boss=%s %s" % [int(spec["star"]), bool(spec["boss"]), rarity])
		for rarity in GearBag.RARITIES:
			if int(want[rarity]) <= 0:
				continue
			var families: Array = GearBag.families_of_rarity(rarity)
			var total := 0
			for fam in families:
				total += int(once["family"].get(fam, 0))
			var mean := float(total) / float(families.size())
			for fam in families:
				var n := int(once["family"].get(fam, 0))
				truthy(mean > 0.0 and absf(float(n) - mean) / mean <= 0.40, "★%d %s %s spread %d vs %.0f" % [int(spec["star"]), rarity, fam, n, mean])
		for ultra in ultras:
			eq(int(once["family"].get(ultra, 0)), 0, "★%d never drops %s" % [int(spec["star"]), ultra])
		eq(int(once["family"].get("duskbrand", 0)), 0, "★%d never drops Duskbrand" % int(spec["star"]))


func _picks(values: Array) -> Callable:
	var at := [0]
	return func() -> float:
		var v: float = values[at[0]]
		at[0] += 1
		return v


func _drop_sample(star: int, boss: bool, trials: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pick := func() -> float:
		return rng.randf()
	var rarity := {}
	var family := {}
	var ids: Array[String] = []
	for _i in trials:
		var rolled := GearBag.roll_drop(star, pick, boss)
		var rare := str(rolled["rarity"])
		var fam := str(rolled["family"])
		rarity[rare] = int(rarity.get(rare, 0)) + 1
		family[fam] = int(family.get(fam, 0)) + 1
		ids.append(str(rolled["item_id"]))
	return {"rarity": rarity, "family": family, "ids": ids}


func _near_percent(count: int, trials: int, percent: int, msg: String) -> void:
	if percent == 0:
		eq(count, 0, "%s is never rolled" % msg)
		return
	var got := float(count) / float(trials) * 100.0
	truthy(absf(got - float(percent)) <= 2.0, "%s is %.2f%% (want %d%% ±2)" % [msg, got, percent])


## The balance-test kit is on for this build. One flag turns it off.
## ProgressEpoch is still the one-time fresh start.
func _test_temporary_kit() -> void:
	var TL := preload("res://backend/test_loadout.gd")
	eq(TL.ACTIVE, true, "the test kit is on")
	var plain_hero := HeroProgress.new()
	eq(TL.sync_hero(plain_hero), true, "kit grants max level")
	for cid in HeroProgress.GROWTH:
		eq(plain_hero.level_of(cid), HeroProgress.MAX_LEVEL, "%s is level 30" % cid)
		eq(plain_hero.record(cid)["spent"], TL.DUEL_BUILDS[cid], "%s has the duel build" % cid)
	eq(plain_hero.test_grant, true, "hero grant flag")
	eq(TL.sync_hero(plain_hero), false, "a second hero sync does not grant")
	var kept_level := HeroProgress.new()
	kept_level.test_grant = true
	kept_level.test_backup = {"kestrel": {"xp": 10, "level": 4, "spent": {}}}
	kept_level.record("kestrel")["level"] = 30
	TL.revoke_hero(kept_level)
	eq(kept_level.level_of("kestrel"), 30, "turning the kit off does not copy test_backup back")
	eq(kept_level.test_grant, false, "hero grant flag cleared")
	eq(kept_level.test_backup, {}, "hero backup discarded")
	var bag := GearBag.new()
	var real := bag.add_item("sheaf", "head", 1)
	eq(TL.sync_bag(bag), true, "kit grants every set piece")
	var families: int = GearBag.FAMILY_ORDER.size() + GearBag.ULTRA_ORDER.size()
	eq(bag.items.size(), families * GearBag.SLOTS.size() + 1, "ladder, Ultra, and the real piece")
	eq(bag.find(real) != -1, true, "real loot stays")
	var all_plus := true
	var all_tagged := true
	var saw := {}
	for it in bag.items:
		if int(it["uid"]) == real:
			continue
		if int(it["plus"]) != GearBag.PLUS_CAP:
			all_plus = false
		if not bool(it.get("test", false)):
			all_tagged = false
		saw[GearBag.family_of(str(it["item_id"]))] = true
	eq(all_plus, true, "every kit piece is +5")
	eq(all_tagged, true, "kit pieces stay tagged in the bag")
	for fam in GearBag.ULTRA_ORDER:
		eq(bool(saw.get(fam, false)), true, "%s Ultra is in the bag" % fam)
	for fam in ["ashmantle", "undertow", "gallowsight", "ravenmourn", "brightedge"]:
		eq(bool(saw.get(fam, false)), true, "%s is in the bag" % fam)
	eq(TL.sync_bag(bag), false, "a second bag sync does not grant")
	var sample := -1
	for it in bag.items:
		if str(it["item_id"]) == "brightedge.weapon":
			sample = int(it["uid"])
	eq(bool(bag.equip(sample, "kestrel")["ok"]), true, "any class can wear the shared Legendary")
	var before := bag.items.size()
	TL.revoke_bag(bag)
	eq(bag.equipped.is_empty(), true, "the off switch takes the kit piece off")
	eq(bag.find(real) != -1 and bag.items.size() == 1, true, "the off switch keeps real loot")
	eq(bag.test_grant, false, "bag grant flag cleared")
	eq(before > 1, true, "the grant had more than the real piece")
	var tagged := GearBag.new()
	var test_uid := tagged.add_item("brightedge", "weapon", 5)
	tagged.items[tagged.find(test_uid)]["test"] = true
	tagged.equip(test_uid, "kestrel")
	var real_uid := tagged.add_item("sheaf", "head", 0)
	tagged.equip(real_uid, "mender")
	var worn: Array = tagged.fight_gear(false, "kestrel")["worn"]
	eq(worn.size(), 1, "kit on: the test piece is sent")
	eq(str(worn[0]["item_id"]), "brightedge.weapon", "Brightedge is a normal item id")
	eq(int(worn[0]["plus"]), 5, "it is still +5")
	eq(worn[0].has("test"), false, "the wire has no test flag")
	var mender_worn: Array = tagged.fight_gear(false, "mender")["worn"]
	eq(mender_worn.size(), 1, "the real piece is sent too")
	eq(str(mender_worn[0]["item_id"]), "sheaf.head", "Sheaf stays")
	var full := GearBag.new()
	eq(TL.sync_bag(full), true, "a fresh bag receives the kit")
	for slot in GearBag.SLOTS:
		var uid := -1
		for it in full.items:
			if str(it["item_id"]) == "sandhawk.%s" % slot:
				uid = int(it["uid"])
		eq(bool(full.equip(uid, "kestrel")["ok"]), true, "kestrel wears Sandhawk %s" % slot)
	var gate := -1
	for it in full.items:
		if str(it["item_id"]) == "gatewarden.weapon":
			gate = int(it["uid"])
	eq(str(full.equip(gate, "kestrel")["reason"]), "wrong_class", "Bastion's Ultra stays on Bastion")
	eq(bool(full.equip(gate, "bastion")["ok"]), true, "Bastion wears Gatewarden")
	var sent: Array = full.fight_gear(false, "kestrel")["worn"]
	eq(sent.size(), 5, "the full Ultra set leaves the phone")
	for row in sent:
		eq(row.has("test"), false, "Ultra row %s has no test flag" % str(row["item_id"]))
		eq(int(row["plus"]), GearBag.PLUS_CAP, "Ultra row is +5")
	var host := GearBag.clean_fight_gear({"worn": sent, "still": {"id": "mirror_hour", "mode": "overwound"}})
	eq((host["worn"] as Array).size(), 5, "the server keeps the untagged Ultra set")
	eq(host["still"], {"id": "mirror_hour", "mode": "overwound"}, "the server keeps the Still")
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.mode = net.Mode.DEDICATED
	net.accept_seat_gear(0, {"worn": sent, "still": {"id": "bound_hour", "mode": "intact"}})
	eq((net._seat_gear[0]["worn"] as Array).size(), 5, "dedicated accept keeps the Ultra set")
	eq(net._seat_gear[0]["still"]["id"], "bound_hour", "dedicated accept keeps the Still")
	net.accept_seat_gear(1, {"worn": [{"item_id": "sandhawk.weapon", "plus": 5, "test": true}]})
	eq((net._seat_gear[1]["worn"] as Array).size(), 0, "a test flag is still dropped")
	net.free()
	var cleaned := GearBag.clean_fight_gear({"worn": [
		{"item_id": "sheaf.head", "plus": 5, "test": true},
		{"item_id": "sheaf.chest", "plus": 1},
	]})
	eq(cleaned["worn"].size(), 1, "clean_fight_gear drops test pieces")
	eq(str(cleaned["worn"][0]["item_id"]), "sheaf.chest", "clean_fight_gear keeps the real piece")
	var vault := StillVault.new()
	eq(TL.sync_vault(vault), true, "kit grants every Still")
	for id in StillVault.IDS:
		eq(vault.count(id), TL.STILL_FRAGMENTS, "%s has enough fragments" % id)
	eq(TL.sync_vault(vault), false, "a second vault sync does not grant")
	eq(bool(vault.forge("tide")["ok"]), true, "forge Tide from the grant")
	eq(vault.socket, "tide", "Tide is socketed")
	eq(bool(vault.set_mode("overwound")["ok"]), true, "Overwound is available")
	eq(bool(vault.forge("mirror_hour")["ok"]), true, "swap to Mirror Hour")
	eq(vault.socket, "mirror_hour", "the socket followed the swap")
	eq(vault.mode, "overwound", "the mode stays")
	eq(vault.count("tide"), TL.STILL_FRAGMENTS, "Tide's fragments came back")
	eq(vault.count("mirror_hour"), TL.STILL_FRAGMENTS - StillVault.FORGE_COST, "Mirror Hour spent 12")
	var earned := StillVault.new()
	earned.fragments["steadfast"] = 20
	earned.test_grant["steadfast"] = 5
	TL.revoke_vault(earned)
	eq(earned.count("steadfast"), 15, "fragments the player earned stay")
	eq(earned.socket, "", "the off switch clears the socket")
	eq(earned.test_grant, {}, "still grant cleared")
	_test_progress_epoch()


func _remove_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_progress_epoch() -> void:
	var marker := "user://test_progress_epoch.json"
	var wallet_path := "user://test_epoch_wallet.json"
	_remove_save(marker)
	_remove_save(wallet_path)
	var prev_marker := ProgressEpoch.marker_path
	var prev_wallet := KoliseoWallet.save_path
	ProgressEpoch.marker_path = marker
	ProgressEpoch.enforce_real_paths = true
	var hero := HeroProgress.new()
	for cid in HeroProgress.GROWTH:
		hero.record(cid)["level"] = 30
		hero.record(cid)["spent"] = {"mastery": 4}
		hero.record(cid)["elements"] = {"pair": ["air", "fire"], "spells": {}}
	hero.test_grant = true
	hero.test_backup = {"kestrel": {"level": 4, "xp": 1, "spent": {}}}
	hero.save()
	var bag := GearBag.new()
	var uid := bag.add_item("sheaf", "head", 5)
	bag.equip(uid)
	bag.attune["sheaf"] = "Fire"
	bag.test_grant = true
	bag.loot_day = 4242
	bag.loot_clears_today = 9
	bag.save()
	var vault := StillVault.new()
	vault.fragments = {"mercy": 99}
	vault.socket = "mercy"
	vault.mode = "overwound"
	vault.test_grant = {"mercy": 99}
	vault.save()
	KoliseoWallet.save_path = wallet_path
	var wallet := KoliseoWallet.new()
	wallet.coins = 12
	wallet.trophies = 40
	wallet.tonics = 2
	wallet.day = 7
	wallet.wins_today = 1
	wallet.total_wins = 9
	wallet.owned = {"pet.mote": 1, "cos.frame.iron": 1, "food.hearth": 3}
	wallet.save()
	var wallet_before: Dictionary = wallet.to_dict()
	eq(ProgressEpoch.ensure(), false, "redirected test paths do not run the epoch")
	eq(HeroProgress.load_saved().level_of("kestrel"), 30, "a skipped epoch leaves the seeded level")
	ProgressEpoch.enforce_real_paths = false
	eq(ProgressEpoch.ensure(), true, "the first launch applies the epoch")
	eq(ProgressEpoch.saved_epoch(), ProgressEpoch.EPOCH, "the marker records the epoch")
	eq(ProgressEpoch.ensure(), false, "the marker blocks a second pass")
	var wiped := HeroProgress.load_saved()
	for cid in HeroProgress.GROWTH:
		eq(wiped.level_of(cid), 1, "%s is the level floor (1)" % cid)
		eq(wiped.xp_of(cid), 0, "%s xp is 0" % cid)
		eq(wiped.record(cid)["spent"], {}, "%s has no spent points" % cid)
		eq(wiped.points_free(cid), 0, "%s has no free points at level 1" % cid)
		eq(wiped.elements_of(cid), {}, "%s elements are unset" % cid)
	eq(wiped.test_grant, false, "epoch clears the hero grant")
	eq(wiped.test_backup, {}, "epoch discards the hero backup")
	var bag_back := GearBag.load_saved()
	eq(bag_back.items.is_empty(), true, "epoch wipes gear")
	eq(bag_back.equipped.is_empty(), true, "epoch wipes equipped")
	eq(bag_back.attune.is_empty(), true, "epoch wipes attune")
	eq(bag_back.test_grant, false, "epoch clears the bag grant")
	eq(bag_back.loot_day, 4242, "loot day is kept")
	eq(bag_back.loot_clears_today, GearBag.LOOT_CLEARS_PER_DAY, "loot clears clamp to the daily cap")
	eq(bag_back.next_uid, 1, "uids restart after the wipe")
	var still_back := StillVault.load_saved()
	eq(still_back.fragments.is_empty(), true, "epoch wipes Still fragments")
	eq(still_back.socket, "", "epoch clears the socket")
	eq(still_back.mode, "intact", "epoch resets the Still mode")
	eq(still_back.test_grant, {}, "epoch clears the Still grant")
	eq(KoliseoWallet.load_saved().to_dict(), wallet_before, "wallet coins, trophies, tonics, and cosmetics stay")
	bag_back.loot_day = -8
	bag_back.loot_clears_today = -3
	bag_back.save()
	eq(ProgressEpoch.reset_saves(), true, "reset_saves writes the three files")
	var sane := GearBag.load_saved()
	eq(sane.loot_day, -1, "a nonsense loot day becomes unset")
	eq(sane.loot_clears_today, 0, "negative loot clears become 0")
	eq(KoliseoWallet.load_saved().to_dict(), wallet_before, "reset_saves does not write the wallet")
	var earned := HeroProgress.load_saved()
	earned.add_xp("ironjaw", 40)
	earned.save()
	eq(ProgressEpoch.ensure(), false, "xp earned after the marker is not wiped")
	eq(HeroProgress.load_saved().xp_of("ironjaw"), 40, "post-epoch xp stays")
	eq(HeroProgress.load_saved().level_of("ironjaw"), 1, "40 xp is still level 1")
	ProgressEpoch.enforce_real_paths = true
	ProgressEpoch.marker_path = prev_marker
	KoliseoWallet.save_path = prev_wallet
	_remove_save(marker)
	_remove_save(wallet_path)
	_remove_save(HeroProgress.save_path)
	_remove_save(StillVault.save_path)


func _test_save_roundtrip() -> void:
	_wipe()
	eq(GearBag.load_saved().items.size(), 0, "no file = empty bag")
	var bag := GearBag.new()
	var a := bag.add_item("ironveil", "head", 2)
	var b := bag.add_item("ironveil", "legs")
	bag.equip(a)
	bag.equip(b)
	bag.set_attune("ironveil", "Water")
	bag.record_stasis_clear(T0)
	truthy(bag.save(), "bag saves")
	var back := GearBag.load_saved()
	eq(back.to_dict(), bag.to_dict(), "bag reloads the same")
	var bad := GearBag.new()
	bad.from_dict({"items": [{"uid": 1, "item_id": "wheat.head"}, {"uid": 2, "item_id": "sheaf.head", "plus": 9}], "equipped": {"head": 1, "legs": 2}, "attune": {"sheaf": "Ice"}})
	eq(bad.items.size(), 1, "unknown items dropped on load")
	eq(int(bad.items[0]["plus"]), 5, "plus clamps to +5")
	eq(bad.equipped.size(), 0, "a head cannot sit in the legs slot")
	eq(bad.attune.size(), 0, "unknown element dropped")
	eq(bad.add_item("sheaf", "boots") > 2, true, "new uids never reuse old ones")


func _test_gear_screen() -> void:
	_wipe()
	var seed := GearBag.new()
	var h1 := seed.add_item("undertow", "head")
	var h2 := seed.add_item("undertow", "head")
	var c := seed.add_item("undertow", "chest")
	seed.save()
	var hub: Node = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	var gear_button := hub.find_child("Inventory", true, false) as Button
	truthy(gear_button != null, "hub has an Inventory button")
	eq(gear_button.custom_minimum_size.y >= 48, true, "Inventory hit target is at least 48px")
	eq(hub.door_count(), 6, "Inventory is not a door")
	hub.open_gear()
	var screen := hub.find_child("GearScreen", true, false) as GearScreen
	truthy(screen != null, "Gear opens the overlay")
	truthy(screen.header_text().contains("AP 6/8"), "header shows AP against the 8 cap")
	truthy(screen.header_text().contains("MP 3/5"), "header shows MP against the 5 cap")
	eq(bool(screen.fuse(h1)["ok"]), true, "Fuse from the screen")
	eq(screen.bag().count_of("undertow.head"), 1, "two heads became one")
	eq(int(screen.bag().item(h1)["plus"]), 1, "fused head is +1")
	screen.wear(h1)
	screen.wear(c)
	eq(screen.bag().set_counts(), {"undertow": 2}, "two Undertow pieces worn")
	var bow := screen.bag().add_item("undertow", "weapon")
	screen.wear(bow)
	var weapon_icon := screen.find_child("Slot_weapon", true, false) as Button
	eq(weapon_icon.icon.resource_path.get_file(), "undertow_weapon_kestrel.png", "the gear screen draws the focused class weapon")
	eq(screen.find_child("Attune_undertow_Air", true, false), null, "no attune buttons")
	eq(int(screen.bag().bonus_stats().get("init", 0)), 4, "Undertow 2pc +4 Init shows in the set stats")
	eq(str(screen.choose_attune("undertow", "Earth")["reason"]), "no_attune", "attune is refused")
	var saved := GearBag.load_saved()
	eq(saved.attune_active("undertow"), "", "screen did not save an attune")
	eq(saved.find(h2), -1, "burned copy stays gone after save")
	screen.take_off("chest")
	eq(GearBag.load_saved().equipped.has("chest"), false, "take off saves")
	hub.free()
	_test_inventory_screen()


func _test_inventory_screen() -> void:
	_wipe()
	HeroProgress.save_path = "user://test_hero_inventory.json"
	KoliseoWallet.save_path = "user://test_wallet_inventory.json"
	for p in [HeroProgress.save_path, KoliseoWallet.save_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var seed := GearBag.new()
	var a := seed.add_item("undertow", "head")
	var b := seed.add_item("undertow", "head")
	var w := seed.add_item("brightedge", "weapon")
	seed.save()
	var wallet := KoliseoWallet.new()
	wallet.tonics = 2
	wallet.save()
	var hub: Node = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	hub.open_inventory()
	var inv := hub.find_child("InventoryScreen", true, false) as InventoryScreen
	truthy(inv != null, "Inventory opens from the hub")
	eq(inv.stats()["hp"], 75, "bare Kestrel has 75 HP")
	eq(inv.stats()["ap"], 6, "bare champion has 6 AP")
	truthy(inv.find_child("Item_%d" % a, true, false) != null, "bag items show as grid tiles")
	truthy(inv.find_child("Slot_head", true, false) != null, "the doll has a head slot")
	truthy(inv.find_child("Socket", true, false) != null, "the doll has the Still socket")
	inv.select({"kind": "item", "uid": a})
	var fuse_button := inv.find_child("Fuse", true, false) as Button
	eq(fuse_button.disabled, false, "two alike heads can fuse")
	eq(bool(inv.fuse(a)["ok"]), true, "fuse from the inventory")
	eq(int(inv.bag().item(a)["plus"]), 1, "fused head is +1")
	eq(GearBag.load_saved().find(b), -1, "fuse is saved")
	eq(bool(inv.wear(a)["ok"]), true, "wear from the inventory")
	eq(inv.stats()["hp"], 75 + int(GearBag.part_stats("undertow.head", 1)["hp"]), "worn head adds its HP")
	inv.wear(w)
	eq(inv.stats()["mastery"], int(GearBag.part_stats("brightedge.weapon", 0)["mastery"]), "worn weapon adds Mastery")
	inv.select({"kind": "slot", "slot": "head"})
	truthy(inv.find_child("TakeOff", true, false) != null, "a worn slot offers Take off")
	eq(bool(inv.take_off("head")["ok"]), true, "take off from the doll")
	eq(GearBag.load_saved().equipped.has("head"), false, "take off is saved")
	inv.show_tab("consumables")
	truthy(inv.find_child("Sku_consumable_room_tonic", true, false) != null, "Room Tonics show under Consumables")
	inv.show_tab("stills")
	inv.show_tab("cosmetics")
	var stage := inv.find_child("ChampionStage", true, false) as ChampionStage
	truthy(stage != null, "the champion stands on the turning stage")
	eq(stage.facing(), "s", "the champion starts facing you")
	stage.turn(1)
	truthy(stage.is_turning(), "a turn animates")
	stage.settle()
	eq(stage.facing(), "e", "turn right shows the right side")
	stage.turn(1)
	stage.settle()
	eq(stage.facing(), "n", "then the back")
	stage.turn(-1)
	stage.settle()
	stage.turn(-1)
	stage.settle()
	stage.turn(-1)
	stage.settle()
	eq(stage.facing(), "w", "turning left wraps to the left side")
	truthy(stage.find_child("TurnLeft", true, false) != null and stage.find_child("TurnRight", true, false) != null, "stage has ◀ ▶ turn buttons")
	eq(stage.rune_tint, GearScreen.RARITY_TINT["Legendary"], "runes glow with the rarest worn piece (Brightedge = Legendary)")
	inv.pick_champion("bastion")
	eq(inv.champion, "bastion", "pick another champion")
	eq(stage.class_id, "bastion", "the stage shows the picked champion")
	eq(stage.facing(), "s", "a new champion faces you")
	eq(inv.bag().equipped_item("weapon", "bastion").is_empty(), true, "Bastion does not inherit Kestrel's weapon")
	eq(str(inv.bag().equipped_item("weapon", "kestrel").get("item_id", "")), "brightedge.weapon", "the Kestrel piece stays on Kestrel")
	for f in ChampionStage.FACINGS:
		truthy(ResourceLoader.exists("res://art/characters/bastion/bastion_%s.png" % f), "bastion has the %s facing" % f)
	# Set art icons (Blueprint set sheets): every family / slot, weapon per class.
	for fam in GearBag.FAMILY_ORDER:
		for slot in GearBag.SLOTS:
			truthy(GearBag.icon(GearBag.item_id_for(fam, slot)) != null, "%s %s has set art" % [fam, slot])
		for cls in ["kestrel", "ironjaw", "mender", "gloam", "bastion"]:
			truthy(ResourceLoader.exists(GearBag.icon_path(GearBag.item_id_for(fam, "weapon"), cls)), "%s weapon art for %s" % [fam, cls])
	eq(GearBag.icon_path("sheaf.weapon", "kestrel").get_file(), "sheaf_weapon_kestrel.png", "a Kestrel sees the Sheaf bow")
	eq(GearBag.icon_path("sheaf.weapon").get_file(), "sheaf_weapon_ironjaw.png", "no class shows the axes")
	eq(GearBag.icon_path("nope.head"), "", "unknown items have no art")
	eq(GearBag.ICON_ALIAS, {}, "set sheets are not aliased")
	eq(GearBag.icon_path("oathgrave.head").get_file(), "oathgrave_head.png", "Oathgrave uses its own head")
	eq(GearBag.icon_path("ashmantle.chest").get_file(), "ashmantle_chest.png", "Ashmantle uses its own chest")
	eq(GearBag.icon_path("ravenmourn.weapon", "kestrel").get_file(), "ravenmourn_weapon_kestrel.png", "Ravenmourn uses its own bow")
	eq(GearBag.FAMILIES.has("gatewarden"), true, "Gatewarden is a wired Ultra set")
	eq(GearBag.icon_path("gatewarden.weapon", "bastion").get_file(), "gatewarden_weapon.png", "Ultra weapons are one sheet, not per class")
	eq(GearBag.icon_path("sandhawk.head").get_file(), "sandhawk_head.png", "Ultra armour lives under art/items/ultra")
	for ultra in ["gatewarden", "sandhawk", "pitmaw", "hushring", "mercywell"]:
		truthy(FileAccess.file_exists("res://art/items/ultra/%s/%s_head.png" % [ultra, ultra]), "%s head art is in the repo" % ultra)
		truthy(FileAccess.file_exists("res://art/items/ultra/%s/%s_weapon.png" % [ultra, ultra]), "%s weapon art is in the repo" % ultra)
	inv.show_tab("equipment")
	var tile := inv.find_child("Item_%d" % w, true, false)
	truthy(tile != null and tile.icon_tex != null, "bag tiles draw the set art")
	var weapon_slot := inv.find_child("Slot_weapon", true, false)
	eq(weapon_slot.icon_tex, null, "Bastion's weapon slot is empty")
	inv.pick_champion("kestrel")
	weapon_slot = inv.find_child("Slot_weapon", true, false)
	eq(weapon_slot.icon_tex.resource_path.get_file(), "brightedge_weapon_kestrel.png", "Kestrel still shows the Brightedge bow")
	inv.pick_champion("bastion")
	var levels := inv.open_levels()
	eq(levels.selected, "bastion", "Levels opens on the picked champion")
	levels.close()
	var sets := inv.open_sets()
	truthy(sets != null, "Sets opens the full gear list")
	sets.close()
	hub.free()


func _test_stasis_chest_wiring() -> void:
	var fight: Script = load("res://scenes/stasis_fight.gd")
	eq(fight.chest_line({"chest": false, "items": []}), "Chest empty — 5 loot clears used today.", "empty chest copy")
	eq(fight.chest_line({"chest": true, "items": [{"item_id": "undertow.legs", "plus": 0}]}), "Chest: Undertow Guards +0. Wear it in Gear.", "chest copy names the piece")
	var src := FileAccess.get_file_as_string("res://scenes/stasis_fight.gd")
	truthy(src.contains("record_stasis_clear"), "a Stasis clear opens the chest")
	truthy(src.contains("StasisCatalog.room == \"b\""), "only a Room B boss clear uses the boss table")
	eq(src.contains("record_human_win") or src.contains(".coins"), false, "Stasis never pays Koliseo coins")
	eq(StasisCatalog.STAR, 1, "doors are Stasis 1 (★1)")


func _test_combat_result() -> void:
	var snap := {
		"match_over": true, "winner_seat": 1, "turn_index": 7,
		"units": [
			{"seat": 0, "name": "Kestrel", "hp": 0, "max_hp": 80},
			{"seat": 1, "name": "Gloam", "hp": 33, "max_hp": 80},
		],
	}
	var online := CombatResult.koliseo_result(snap, 1, {"coins": 1, "trophies": 1, "wins_today": 1}, 237)
	eq(str(online["outcome"]), "Victory", "online winner sees Victory")
	eq(online["winners"].size(), 1, "one winner row")
	eq(str(online["winners"][0]["name"]), "Gloam", "winner row is the winner")
	eq(bool(online["winners"][0]["you"]), true, "the local player is marked")
	eq(online["winners"][0]["loot"], [{"kind": "coin", "count": 1}, {"kind": "trophy", "count": 1}], "loot shows the coin and trophy paid")
	eq(str(online["losers"][0]["name"]), "Kestrel", "loser row")
	eq(int(online["turns"]), 7, "turn count from the match")
	var lost := CombatResult.koliseo_result(snap, 0, {}, 60)
	eq(str(lost["outcome"]), "Defeat", "online loser sees Defeat")
	eq(lost["winners"][0]["loot"], [], "no loot shown for the other player")
	var capped := CombatResult.koliseo_result(snap, 1, {"coins": 0, "trophies": 1, "wins_today": 3}, 60)
	truthy(str(capped["note"]).contains("Daily coin limit"), "3rd win explains the daily limit")
	var hot := CombatResult.koliseo_result(snap, -1, {}, 60)
	eq(str(hot["outcome"]), "Gloam wins", "hot-seat names the winner")
	truthy(str(hot["note"]).contains("only online wins pay"), "hot-seat explains no pay")
	eq(CombatResult.format_duration(237), "03:57", "duration reads mm:ss")
	StasisCatalog.run_turns = 9
	StasisCatalog.run_foes = [{"name": "Grain Hound", "hp": 0, "max_hp": 22}]
	var fight: Script = load("res://scenes/stasis_fight.gd")
	var clear: Dictionary = fight.stasis_result({"name": "Mender", "hp": 51, "max_hp": 80}, {"chest": true, "items": [{"item_id": "sheaf.boots", "plus": 0}]}, true, 200)
	eq(str(clear["outcome"]), "Victory", "Stasis clear is a Victory")
	eq(clear["winners"][0]["loot"], [{"kind": "gear", "item_id": "sheaf.boots", "plus": 0, "count": 1, "class_id": StasisCatalog.class_id}], "chest piece shows as loot (with the class, for the weapon art)")
	eq(str(clear["losers"][0]["name"]), "Grain Hound", "beaten foes listed as losers")
	eq(int(clear["turns"]), 9, "turns over the whole run")
	var wipe: Dictionary = fight.stasis_result({"name": "Mender", "hp": 0, "max_hp": 80}, {}, false, 90)
	eq(str(wipe["outcome"]), "Defeat", "a wipe is a Defeat")
	eq(str(wipe["losers"][0]["name"]), "Mender", "the player is in the losers block")
	StasisCatalog.clear_run()
	var window: CombatResult = load("res://ui/combat_result.gd").new()
	window.setup(clear)
	root.add_child(window)
	eq(window.row_count(), 2, "window draws one row per fighter")
	truthy(window.find_child("CloseResult", true, false) != null, "window has a Close button")
	eq(window.duration_text(), "Duration 03:20 (9 turns)", "duration line")
	var icons := 0
	for node in window.find_children("*", "", true, false):
		if node is CombatResult.LootIcon:
			icons += 1
	eq(icons, 1, "one loot icon for the chest piece")
	window.close()
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("hp"), false, "board_view still does not read hp")


func _worn(family: String, slots: Array, plus: int = 0) -> Array:
	var out: Array = []
	for slot in slots:
		out.append({"item_id": "%s.%s" % [family, slot], "plus": plus})
	return out


func _test_gear_in_fights() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	# No gear: the Locked proto body is unchanged.
	sim.reset_match({"classes": ["kestrel", "ironjaw"], "skip_deploy": true})
	var plain: Dictionary = sim._unit_by_seat(0)
	eq([int(plain["max_hp"]), int(plain["max_ap"]), int(plain["max_mp"]), int(plain["mastery"]), int(plain["resist"])], [75, 6, 3, 0, 0], "no gear = Kestrel 75 HP, 6/3, Mastery 0, Resist 0")
	# Undertow (Kestrel) on seat 0. Sheaf on that seat does nothing (wrong class).
	# Tyrantjaw (Ironjaw) on seat 1.
	sim.reset_match({"classes": ["kestrel", "ironjaw"], "skip_deploy": true, "seat_gear": {
		0: {"worn": _worn("sheaf", GearBag.SLOTS)},
		1: {"worn": _worn("tyrantjaw", GearBag.SLOTS)},
	}})
	eq(int(sim._unit_by_seat(0)["max_hp"]), 75, "Sheaf on a Kestrel seat adds nothing")
	sim.reset_match({"classes": ["kestrel", "ironjaw"], "skip_deploy": true, "seat_gear": {
		0: {"worn": _worn("undertow", GearBag.SLOTS)},
		1: {"worn": _worn("tyrantjaw", GearBag.SLOTS)},
	}})
	var kite: Dictionary = sim._unit_by_seat(0)
	var jaw: Dictionary = sim._unit_by_seat(1)
	eq(int(kite["max_hp"]), 115, "Undertow: 75 + 40 part HP")
	eq(int(kite["hp"]), 115, "fight starts at full geared HP")
	eq(int(kite["mastery"]), 22, "Undertow part Mastery 22")
	eq(int(kite["resist"]), 1, "Undertow part resist counts against every element")
	eq(kite["resist_elem"], {}, "elementless resist is not stored as Neutral")
	eq(int(kite["init"]), 16, "Undertow Init 12 parts + 4 (2pc)")
	eq(int(kite["crit"]), 14, "Undertow crit 10 parts + 4 (4pc)")
	eq(int(kite["first_hit"]), 4, "Undertow 5pc first hit +4")
	eq(int(jaw["max_ap"]), 7, "Tyrantjaw 5pc → 7 AP")
	eq(int(jaw["max_mp"]), 4, "Tyrantjaw 5pc → 4 MP")
	eq(int(jaw["max_hp"]), 184, "Tyrantjaw: (90 + 74) × 1.12 = 184")
	eq(int(jaw["mastery"]), 14, "Tyrantjaw part Mastery 14")
	eq(int(jaw["resist"]), 9, "Tyrantjaw part resist is universal")
	eq(jaw["resist_elem"], {}, "Tyrantjaw has no attuned element")
	eq(int(jaw["init"]), 2, "Tyrantjaw Init 2")
	eq(int(jaw["crit"]), 11, "Tyrantjaw crit 7 parts + 4 (4pc)")
	var snap: Dictionary = sim.snapshot()
	sim.submit({"type": "end_turn", "seat": int(snap["active_seat"])})
	var after: Dictionary = sim._unit_by_seat(1)
	eq([int(after["ap"]), int(after["mp"])], [7, 4], "Tyrantjaw refills 7 AP / 4 MP at turn start")
	# Damage formula: (1 + Mastery/100) × (1 − Resist/100).
	eq(sim._phase_a_damage(20, 1.0, {}, {}), 20, "base damage unchanged without gear")
	eq(sim._phase_a_damage(20, 1.0, {"mastery": 8}, {}), 22, "+8 Mastery → 21.6 → 22")
	eq(sim._phase_a_damage(20, 1.0, {}, {"resist": 8}), 18, "+8% resist → 18.4 → 18")
	eq(sim._phase_a_damage(20, 1.0, {}, {"resist_elem": {"fire": 8}}, "fire"), 18, "element resist vs its element")
	eq(sim._phase_a_damage(20, 1.0, {}, {"resist_elem": {"fire": 8}}, "air"), 20, "element resist ignores other elements")
	eq(sim._phase_a_damage(20, 1.0, {"flex_riders": {"air": 10}}, {}, "air"), 22, "Air rider +10% on an Air hit")
	eq(sim._phase_a_damage(20, 1.0, {"flex_riders": {"air": 10}}, {}, "neutral"), 20, "neutral spells take no rider")
	var first := {"first_flex_pct": 15, "first_flex_ready": true}
	eq(sim._phase_a_damage(20, 1.0, first, {}, "air"), 23, "Stillcut 5 first FLEX hit +15% (preview)")
	eq(bool(first["first_flex_ready"]), true, "a preview does not spend it")
	sim._phase_a_damage(20, 1.0, first, {}, "air", true)
	eq(bool(first["first_flex_ready"]), false, "a resolved hit spends it")
	eq(sim._phase_a_damage(20, 1.0, first, {}, "air"), 20, "only the first FLEX hit")
	var att := GearBag.combat_stats(_worn("ironveil", ["head", "chest"]), {"ironveil": "Fire"}, false, "bastion")
	eq(int(att["resist"]), 7, "Ironveil head+chest resist 3+4 counts against every element")
	eq(att["resist_elem"], {}, "resist_all does not fill resist_elem")
	eq(att["riders"], {}, "no attune rider")
	eq(int(att["hp_pct"]), 10, "Ironveil 2pc +10% HP")
	var one := GearBag.combat_stats(_worn("ironveil", ["head"]), {}, false, "bastion")
	eq(int(one["resist"]), 3, "one piece of resist still counts")
	eq(one["resist_elem"], {}, "one piece does not park resist on Neutral")
	var still_crit := GearBag.combat_stats(_worn("stillcut", GearBag.SLOTS), {}, false, "gloam")
	eq(int(still_crit["crit"]), 12, "Stillcut 8% parts + 4pc 4% is 12, under the cap")
	var legend_crit := GearBag.combat_stats(_worn("gravewhisper", GearBag.SLOTS), {}, false, "gloam")
	eq(int(legend_crit["crit"]), 12, "Gravewhisper full sheet is 12% (no set-bonus crit)")
	var night_crit := GearBag.combat_stats(_worn("nightglass", GearBag.SLOTS), {}, false, "gloam")
	eq(int(night_crit["crit"]), 12, "Nightglass 8% parts + 4pc 4% is 12")
	# +0 part totals (HP, Mastery, Resist, Init, Crit).
	var sheet := {
		"ashmantle": [60, 14, 6, 4, 2], "rustward": [70, 4, 10, 2, 0], "ironveil": [78, 6, 12, 2, 0],
		"oathgrave": [84, 6, 14, 2, 0], "undertow": [40, 22, 1, 12, 10], "gallowsight": [44, 26, 2, 12, 12],
		"ravenmourn": [44, 31, 2, 16, 12], "cragmaw": [62, 12, 6, 2, 4], "maulgrave": [70, 12, 8, 2, 6],
		"tyrantjaw": [74, 14, 9, 2, 7], "nightglass": [36, 25, 0, 18, 8], "stillcut": [40, 27, 1, 26, 8],
		"gravewhisper": [36, 31, 1, 28, 12], "vesperwell": [62, 13, 7, 2, 1], "sheaf": [68, 14, 9, 4, 2],
		"hallowmourn": [70, 16, 10, 4, 4], "brightedge": [56, 29, 4, 10, 7],
	}
	for fam in sheet:
		var tot := [0, 0, 0, 0, 0]
		for slot in GearBag.SLOTS:
			var st := GearBag.part_stats("%s.%s" % [fam, slot], 0)
			tot = [tot[0] + int(st["hp"]), tot[1] + int(st["mastery"]), tot[2] + int(st["resist"]), tot[3] + int(st["init"]), tot[4] + int(st["crit"])]
		eq(tot, sheet[fam], "%s part totals (HP, Mastery, Resist, Init, Crit)" % fam)
	eq(GearBag.part_stats("sheaf.head", 5)["hp"], 32, "Sheaf Helm 18 HP × 1.78 at +5 = 32")
	eq(GearBag.part_stats("sheaf.head", 5)["crit"], 0, "crit% does not fuse")
	eq(GearBag.part_stats("stillcut.weapon", 3)["mastery"], 25, "Stillcut Edge 18 × 1.41 at +3 = 25")
	eq(GearBag.part_stats("stillcut.weapon", 3)["crit"], 4, "Stillcut Edge crit stays 4 at +3")
	var flat := GearBag.combat_stats(_worn("sheaf", ["head"], 5), {}, true, "mender")
	eq(int(flat["hp_flat"]), 18, "Koliseo flatten: a +5 helm counts as +0")
	eq(GearBag.item_label({"item_id": "stillcut.chest", "plus": 2}), "Stillcut Plate +2", "items use the part names")
	eq(GearBag.weighted_slot(0.0), "weapon", "slot roll 0 → weapon")
	eq(GearBag.weighted_slot(0.17), "weapon", "weapon is the first 18%")
	eq(GearBag.weighted_slot(0.19), "head", "then head")
	eq(GearBag.weighted_slot(0.999), "boots", "boots last")
	# Cheats and junk are cleaned: bad ids, duplicate slots, +9, AP cap.
	var junk := GearBag.combat_stats([{"item_id": "duskbrand.head", "plus": 9}, {"item_id": "duskbrand.head"}, {"item_id": "wheat.legs"}, "x"])
	eq([junk["ap"], junk["mp"], junk["hp_pct"]], [6, 3, 0], "a retired Duskbrand head gives nothing")
	var capped := GearBag.ap_mp_of_worn(_worn("stillcut", GearBag.SLOTS, 5))
	eq([capped["ap"], capped["mp"]], [7, 4], "rare +5 weapon and boots → +1 AP +1 MP")
	eq(int(GearBag.ap_mp_of_worn(_worn("brightedge", GearBag.SLOTS))["ap"]) <= 8, true, "AP never above 8")
	# Mid-combat gear is refused; deployment accepts it.
	eq(sim.set_seat_gear(0, {"worn": _worn("sheaf", ["head", "chest"])}), false, "gear cannot change mid-combat")
	sim.reset_match({"classes": ["kestrel", "ironjaw"]})
	eq(sim.set_seat_gear(1, {"worn": _worn("cragmaw", ["head", "chest"])}), true, "gear applies during deployment")
	eq(int(sim._unit_by_seat(1)["max_hp"]), 143, "late gear raised seat 1 HP to (90+18+24)×1.08")
	# Authority: a reset config cannot smuggle gear; each seat's own gear is used.
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.mode = net.Mode.DEDICATED
	net._seat_gear[1] = {"worn": _worn("sheaf", ["head", "chest"]), "attune": {}}
	var cfg: Dictionary = net._authority_gear_config({"seat_gear": {0: {"worn": _worn("duskbrand", GearBag.SLOTS)}}})
	eq(cfg["seat_gear"].has(0), false, "smuggled seat 0 gear is dropped")
	eq(cfg["seat_gear"][1]["worn"].size(), 2, "seat 1 keeps the gear it sent")
	net.accept_seat_gear(1, {"worn": [
		{"item_id": "sheaf.head", "plus": 5, "test": true},
		{"item_id": "sheaf.chest", "plus": 0},
	]})
	eq((net._seat_gear[1]["worn"] as Array).size(), 1, "dedicated server drops test-tagged gear")
	eq(str(net._seat_gear[1]["worn"][0]["item_id"]), "sheaf.chest", "dedicated server keeps the real piece")
	net.accept_seat_gear(0, {"worn": [{"item_id": "duskbrand.weapon", "plus": 5, "test": true}]})
	eq((net._seat_gear[0]["worn"] as Array).size(), 0, "a seat of only test gear arrives empty")
	net.mode = net.Mode.HOTSEAT
	net._seat_gear.clear()
	net.free()
	# Stasis: the player's worn gear rides in the fight roster.
	_wipe()
	var bag := GearBag.new()
	bag.equip(bag.add_item("sheaf", "head"))
	bag.equip(bag.add_item("sheaf", "chest"))
	bag.save()
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "mender"
	var fight_cfg := StasisCatalog.fight_config()
	var player_rec: Dictionary = fight_cfg["stasis_roster"][0]
	eq(player_rec["gear"]["worn"].size(), 2, "Stasis fight carries the worn gear")
	sim.reset_match(fight_cfg)
	eq(int(sim._unit_by_seat(0)["max_hp"]), 144, "Stasis Mender gets Sheaf helm + coat and 2pc +10%")
	StasisCatalog.player_hp = 60
	sim.reset_match(StasisCatalog.fight_config())
	eq(int(sim._unit_by_seat(0)["hp"]), 60, "Room B carries Room A HP under the geared max")
	StasisCatalog.clear_run()
	_wipe()


func _test_loadouts() -> void:
	var bag := GearBag.new()
	var sheaf := bag.add_item("sheaf", "head")
	var shared := bag.add_item("brightedge", "weapon")
	var kite := bag.add_item("undertow", "boots")
	bag.from_dict({
		"items": bag.items.duplicate(true),
		"equipped": {"head": sheaf, "weapon": shared, "boots": kite},
		"next_uid": bag.next_uid,
	})
	eq(int(bag.equipped_item("head", "mender").get("uid", -1)), sheaf, "a class piece migrates onto its class")
	eq(bag.equipped_item("boots", "kestrel").is_empty(), false, "Undertow migrates onto Kestrel")
	eq(bag.is_equipped(shared), false, "a shared piece from the old single loadout stays in the bag")
	var locked := GearBag.new()
	locked.from_dict({
		"items": [{"uid": 1, "item_id": "sheaf.head", "plus": 0}],
		"loadouts": {"kestrel": {"head": 1}, "mender": {}},
		"focus_class": "kestrel",
		"next_uid": 2,
	})
	eq(locked.is_equipped(1), false, "a Sheaf head saved on Kestrel is dropped")
	var twice := GearBag.new()
	twice.from_dict({
		"items": [{"uid": 7, "item_id": "brightedge.weapon", "plus": 0}],
		"loadouts": {"kestrel": {"weapon": 7}, "mender": {"weapon": 7}},
		"focus_class": "mender",
		"next_uid": 8,
	})
	eq(int(twice.equipped_item("weapon", "kestrel").get("uid", -1)), 7, "one uid stays on the first class")
	eq(twice.equipped_item("weapon", "mender").is_empty(), true, "the same uid is not on a second class")
	var live := GearBag.new()
	var u := live.add_item("undertow", "weapon")
	var s := live.add_item("sheaf", "weapon")
	var b := live.add_item("brightedge", "chest")
	eq(bool(live.equip(u, "kestrel")["ok"]), true, "Undertow equips on Kestrel")
	eq(str(live.equip(s, "kestrel")["reason"]), "wrong_class", "Sheaf stays off Kestrel")
	eq(bool(live.equip(s)["ok"]), true, "Sheaf equips on Mender by itself")
	eq(bool(live.equip(b, "bastion")["ok"]), true, "Brightedge equips on Bastion")
	eq(str(live.equipped_item("weapon", "kestrel").get("item_id", "")), "undertow.weapon", "Kestrel keeps its own weapon")
	eq(str(live.equipped_item("weapon", "mender").get("item_id", "")), "sheaf.weapon", "Mender keeps its own weapon")
	eq(live.focus_class, "bastion", "equipping focuses that class")
	eq(OS.is_debug_build(), true, "this test binary is a debug build")
	eq(bool(live.debug_equip_set("kestrel", "oathgrave")["ok"]), true, "debug can wear any full set")
	eq(live.worn_list("kestrel").size(), 5, "the debug set fills five slots")
	eq(bool(live.worn_list("kestrel")[0].get("debug", false)), true, "debug pieces are tagged")
	var local := live.fight_gear(false, "kestrel")
	eq((local["worn"] as Array).size(), 5, "a local fight keeps debug pieces")
	var cleaned := GearBag.clean_fight_gear(local)
	eq((cleaned["worn"] as Array).size(), 0, "clean_fight_gear never sends debug pieces")
	# Proposed set bonuses that are not the locked 5pc lines.
	eq(str(GearBag.FAMILIES["oathgrave"]["bonus"][5]).begins_with("+1 AP +1 MP"), true, "Oathgrave 5pc leads with +1 AP +1 MP")
	eq(int(GearBag.FAMILIES["oathgrave"]["stats"][5]["ward_shield"]), 25, "Oathgrave Ward shield is 25")
	eq(int(GearBag.FAMILIES["oathgrave"]["stats"][5]["start_aegis"]), 1, "Oathgrave starts with 1 Aegis")
	eq(int(GearBag.FAMILIES["gravewhisper"]["stats"][4]["back_pct"]), 6, "Gravewhisper 4pc back damage +6%")
	eq(int(GearBag.FAMILIES["rustward"]["stats"][5]["guard_flat"]), 4, "Rustward 5pc guards the first hit")
	eq(int(GearBag.FAMILIES["undertow"]["stats"][5]["first_hit"]), 4, "Undertow 5pc first hit +4")
	eq(int(GearBag.FAMILIES["cragmaw"]["stats"][5]["melee"]), 4, "Cragmaw 5pc melee +4")
	eq(int(GearBag.FAMILIES["nightglass"]["stats"][5]["first_back"]), 4, "Nightglass 5pc first back hit +4")
	eq(int(GearBag.FAMILIES["vesperwell"]["stats"][4]["heal_flat"]), 4, "Vesperwell 4pc heals +4")


func _test_crit_cap_and_stun() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(3, 0),
		"kestrel_facing": "E", "ironjaw_facing": "W",
		"rolls": [1, 50],
	})
	var calm: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(3, 0), "seat": 0})
	eq(bool(calm["ok"]), true, "a 0% crit Mark Shot connects")
	var calm_hit: Dictionary = calm["events"][0]
	eq(int(calm_hit["damage"]), 8, "0% crit leaves Mark Shot at 8")
	eq(float(calm_hit["crit_mult"]), 1.0, "a non-crit event stores crit_mult 1.0")
	eq(bool(calm_hit.get("crit", false)), false, "the hit is not a crit")
	eq(sim._scripted_rolls.size(), 1, "0% crit does not consume a roll")
	sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(3, 0),
		"kestrel_facing": "E", "ironjaw_facing": "W",
		"rolls": [1, 21, 1, 20],
	})
	sim._unit_by_seat(0)["crit"] = 100
	var under: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(3, 0), "seat": 0})
	eq(int(under["events"][0]["damage"]), 8, "a roll of 21 misses the 20% cap")
	var over: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(3, 0), "seat": 0})
	eq(int(over["events"][0]["damage"]), 10, "a roll of 20 crits: 8 × 1.3 = 10")
	eq(bool(over["events"][0]["crit"]), true, "the second hit crits")
	eq(float(over["events"][0]["crit_mult"]), 1.3, "a crit stores 1.3")
	sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(3, 0),
		"kestrel_facing": "E", "ironjaw_facing": "W",
		"rolls": [1, 1, 1, 1, 1],
	})
	sim._unit_by_seat(0)["crit"] = 20
	var first: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(3, 0), "seat": 0})
	eq(int(first["events"][0]["damage"]), 10, "the first hit of the turn crits")
	var second: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(3, 0), "seat": 0})
	eq(int(second["events"][0]["damage"]), 8, "the second hit of the turn does not crit")
	eq(sim._scripted_rolls.size(), 2, "a spent crit does not roll again")
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "end_turn", "seat": 1})
	var again: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(3, 0), "seat": 0})
	eq(int(again["events"][0]["damage"]), 10, "the next turn can crit again")
	# Mender heals crit. A Kestrel with the same chance does not.
	sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "classes": ["mender", "kestrel"], "rolls": [1]})
	var mend := SpellKits.spell(SpellKits.MEND)
	var healer: Dictionary = sim._unit_by_seat(0)
	var preview := int(sim._support_heal_amount(healer, healer, mend, false))
	healer["crit"] = 20
	var crit_heal := int(sim._support_heal_amount(healer, healer, mend, true))
	eq(crit_heal, roundi(float(preview) * 1.3), "a Mender heal crits at 1.3")
	healer["heal_flat"] = 6
	healer["crit"] = 0
	eq(int(sim._support_heal_amount(healer, healer, mend, false)), preview + 6, "heal_flat adds after the formula")
	sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "classes": ["kestrel", "mender"], "rolls": [1, 1]})
	var hawk: Dictionary = sim._unit_by_seat(0)
	hawk["crit"] = 100
	var hawk_preview := int(sim._support_heal_amount(hawk, hawk, mend, false))
	eq(int(sim._support_heal_amount(hawk, hawk, mend, true)), hawk_preview, "a Kestrel heal does not crit")
	eq(sim._scripted_rolls.size(), 2, "a non-Mender heal does not roll")
	# Stun immunity: the skipped turn plus the next real turn.
	sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(3, 3), "ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E", "ironjaw_facing": "W",
		"ironjaw_impact": 5,
		"rolls": [1],
	})
	sim.submit({"type": "end_turn", "seat": 0})
	var crush: Dictionary = sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3), "seat": 1})
	eq(bool(crush["ok"]), true, "Crush connects")
	eq(int(crush["events"][0].get("stun_applied", 0)), 1, "a full-Impact Crush stuns")
	sim.submit({"type": "end_turn", "seat": 1})
	var stunned: Dictionary = sim._unit_by_seat(0)
	eq(bool(stunned.get("stun_immune", false)), true, "the skipped turn arms stun immunity")
	eq(int(sim._apply_stun(stunned, 1)), 0, "immunity blocks another stun")
	eq(int(stunned.get("stun_remaining", 0)), 0, "immunity does not store a new stun")
	eq(int(sim.snapshot()["active_seat"]), 1, "the skip handed the turn back")
	sim.submit({"type": "end_turn", "seat": 1})
	eq(bool(sim._unit_by_seat(0).get("stunned", false)), false, "the next Kestrel turn is real")
	eq(bool(sim._unit_by_seat(0).get("stun_immune", false)), true, "immunity lasts through that real turn")
	eq(int(sim._apply_stun(sim._unit_by_seat(0), 1)), 0, "a stun during the real turn still fails")
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim._unit_by_seat(0).get("stun_immune", false)), false, "immunity ends with the real turn")
	eq(int(sim._apply_stun(sim._unit_by_seat(0), 1)), 1, "a later stun lands")
	# Oathgrave: Ward 25, start with 1 Aegis, breaking the shield does not refund.
	sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"seat_gear": {0: {"worn": _worn("oathgrave", GearBag.SLOTS)}},
	})
	var bastion: Dictionary = sim._unit_by_seat(0)
	eq(int(bastion["aegis"]), 1, "Oathgrave starts with 1 Aegis")
	eq(int(bastion["ward_shield"]), 25, "Oathgrave Ward shield is 25")
	bastion["aegis"] = 2
	sim._resolve_team_ward({"type": "cast", "spell": "ward", "seat": 0}, bastion, SpellKits.spell(SpellKits.WARD), 2, 0)
	eq(int(bastion["shield"]), 25, "Ward grants 25, not 20")
	eq(int(bastion["aegis"]), 0, "Ward spent the 2 Aegis")
	sim._mitigate_hit(sim._unit_by_seat(1), bastion, 40)
	eq(int(bastion["shield"]), 0, "the shield breaks")
	eq(int(bastion["aegis"]), 0, "breaking Ward does not refund Aegis")
	eq(int(sim._gear_strike_damage({"back_pct": 6}, {}, 100, 2, true, true)), 106, "Gravewhisper back hits +6%")
	eq(int(sim._gear_strike_damage({"melee": 4}, {}, 10, 1, false, true)), 14, "melee +4 at range 1")
	eq(int(sim._gear_strike_damage({"melee": 4}, {}, 10, 2, false, true)), 10, "melee does not add at range 2")
	var guarded := {"guard_ready": true, "guard_flat": 4}
	eq(int(sim._gear_strike_damage({}, guarded, 10, 2, false, true)), 6, "the first hit taken deals 4 less")
	eq(bool(guarded["guard_ready"]), false, "the guard is spent")


func _wipe() -> void:
	if FileAccess.file_exists(TEST_BAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BAG))


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s  (got %s)" % [msg, value])
	else:
		_passed += 1
