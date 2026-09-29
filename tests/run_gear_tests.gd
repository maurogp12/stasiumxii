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
	_wipe()
	_test_families_and_slots()
	_test_equip()
	_test_fuse()
	_test_attune()
	_test_set_bonuses()
	_test_ap_mp_clamp()
	_test_stasis_loot()
	_test_save_roundtrip()
	_test_gear_screen()
	_test_stasis_chest_wiring()
	_test_combat_result()
	_wipe()
	print("Gear tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_families_and_slots() -> void:
	eq(GearBag.FAMILY_ORDER, ["sheaf", "undertow", "ironveil", "stillcut", "brightedge", "duskbrand"], "exactly the six families")
	eq(GearBag.FAMILIES.size(), 6, "no seventh family")
	eq(GearBag.SLOTS, ["weapon", "head", "chest", "legs", "boots"], "five slots")
	eq(GearBag.ELEMENTS, ["Air", "Earth", "Fire", "Water"], "four attune elements")
	eq(str(GearBag.FAMILIES["duskbrand"]["source"]), "Koliseo 60 coins", "Duskbrand comes from Koliseo")
	eq(str(GearBag.FAMILIES["brightedge"]["rarity"]), "Legendary", "Brightedge is Legendary")
	eq(GearBag.is_valid_item_id("sheaf.head"), true, "sheaf.head is valid")
	eq(GearBag.is_valid_item_id("wheat.head"), false, "unknown family rejected")
	eq(GearBag.is_valid_item_id("sheaf.cape"), false, "unknown slot rejected")


func _test_equip() -> void:
	var bag := GearBag.new()
	var a := bag.add_item("sheaf", "head")
	var b := bag.add_item("undertow", "head")
	eq(bool(bag.equip(a)["ok"]), true, "wear a head")
	eq(int(bag.equipped["head"]), a, "head slot holds it")
	bag.equip(b)
	eq(int(bag.equipped["head"]), b, "a new head replaces the old one")
	eq(bag.is_equipped(a), false, "old head back in the bag")
	eq(bool(bag.unequip("head")["ok"]), true, "take off the head")
	eq(str(bag.unequip("head")["reason"]), "empty_slot", "nothing left to take off")
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
	var h := bag.add_item("ironveil", "head")
	var c := bag.add_item("ironveil", "chest")
	bag.equip(h)
	eq(str(bag.set_attune("ironveil", "Fire")["reason"]), "needs_2_pieces", "attune needs 2 worn pieces")
	bag.equip(c)
	eq(str(bag.set_attune("ironveil", "Ice")["reason"]), "unknown_element", "only the four elements")
	eq(bool(bag.set_attune("ironveil", "Fire")["ok"]), true, "attune at 2 pieces")
	eq(bag.attune_active("ironveil"), "Fire", "Fire is active")
	bag.unequip("chest")
	eq(bag.attune_active("ironveil"), "", "attune rests under 2 pieces")
	eq(str(bag.attune.get("ironveil", "")), "Fire", "the choice is kept")
	bag.equip(c)
	eq(bag.attune_active("ironveil"), "Fire", "attune back at 2 pieces")


func _test_set_bonuses() -> void:
	var bag := GearBag.new()
	for slot in ["weapon", "head", "chest", "legs"]:
		bag.equip(bag.add_item("sheaf", slot))
	var tiers: Array = []
	for bonus in bag.active_bonuses():
		tiers.append([bonus["family"], bonus["tier"], bonus["text"]])
	eq(tiers, [["sheaf", 2, "+10% HP"], ["sheaf", 4, "+8 Mastery"]], "4 Sheaf pieces give the 2pc and 4pc bonuses")
	eq(bag.bonus_stats(), {"hp_pct": 10, "mastery": 8}, "Sheaf 4pc stats stack")
	bag.equip(bag.add_item("sheaf", "boots"))
	eq(bag.bonus_stats(), {"hp_pct": 10, "mastery": 8, "resist_pct": 8}, "Sheaf 5pc adds +8% all resist")
	var mixed := GearBag.new()
	mixed.equip(mixed.add_item("sheaf", "weapon"))
	mixed.equip(mixed.add_item("undertow", "head"))
	eq(mixed.active_bonuses().size(), 0, "1 + 1 pieces give nothing")


func _test_ap_mp_clamp() -> void:
	var bag := GearBag.new()
	eq(bag.ap_mp()["ap"], 6, "base 6 AP")
	eq(bag.ap_mp()["mp"], 3, "base 3 MP")
	for slot in GearBag.SLOTS:
		bag.equip(bag.add_item("duskbrand", slot))
	eq(bag.ap_mp()["ap"], 7, "Duskbrand 5pc +1 AP")
	eq(bag.ap_mp()["mp"], 4, "Duskbrand 5pc +1 MP")
	# Rare gate: 4 Stillcut pieces all ≥+4 → +1 MP.
	var rare := GearBag.new()
	for slot in ["weapon", "head", "chest", "legs"]:
		rare.equip(rare.add_item("stillcut", slot, 4))
	eq(rare.rare_gate(), {"ap": 0, "mp": 1}, "4 rare pieces at +4 → +1 MP")
	rare.equip(rare.add_item("stillcut", "boots", 4))
	eq(rare.rare_gate(), {"ap": 0, "mp": 1}, "5 pieces not all +5 → no AP")
	for slot in GearBag.SLOTS:
		rare.equip(rare.add_item("stillcut", slot, 5))
	eq(rare.rare_gate(), {"ap": 1, "mp": 1}, "5 rare pieces at +5 → +1 AP and +1 MP")
	var normal := GearBag.new()
	for slot in GearBag.SLOTS:
		normal.equip(normal.add_item("sheaf", slot, 5))
	eq(normal.rare_gate(), {"ap": 0, "mp": 0}, "the rare gate is Ironveil/Stillcut only")
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
	eq(str(first["items"][0]["item_id"]), "sheaf.weapon", "pick 0,0 = Sheaf weapon")
	eq(int(first["items"][0]["plus"]), 0, "drops are +0")
	var second := bag.record_stasis_clear(T0 + 10, 1, pick)
	eq(str(second["items"][0]["item_id"]), "undertow.boots", "pick .99,.99 = Undertow boots")
	var seen := {}
	for n in 3:
		var loot := bag.record_stasis_clear(T0 + 20 + n, 1, pick)
		for it in loot["items"]:
			seen[GearBag.family_of(str(it["item_id"]))] = true
	for fam in seen:
		eq(["sheaf", "undertow"].has(fam), true, "★1 drops only ★1+ families (%s)" % fam)
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
		eq(GearBag.family_of(str(it["item_id"])) != "duskbrand", true, "Stasis never drops Duskbrand")


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
	var h1 := seed.add_item("sheaf", "head")
	var h2 := seed.add_item("sheaf", "head")
	var c := seed.add_item("sheaf", "chest")
	seed.save()
	var hub: Node = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	var gear_button := hub.find_child("Gear", true, false) as Button
	truthy(gear_button != null, "hub has a Gear button")
	eq(gear_button.custom_minimum_size.y >= 48, true, "Gear hit target is at least 48px")
	eq(hub.door_count(), 6, "Gear is not a door")
	hub.open_gear()
	var screen := hub.find_child("GearScreen", true, false) as GearScreen
	truthy(screen != null, "Gear opens the overlay")
	truthy(screen.header_text().contains("AP 6/8"), "header shows AP against the 8 cap")
	truthy(screen.header_text().contains("MP 3/5"), "header shows MP against the 5 cap")
	eq(bool(screen.fuse(h1)["ok"]), true, "Fuse from the screen")
	eq(screen.bag().count_of("sheaf.head"), 1, "two heads became one")
	eq(int(screen.bag().item(h1)["plus"]), 1, "fused head is +1")
	screen.wear(h1)
	screen.wear(c)
	eq(screen.bag().set_counts(), {"sheaf": 2}, "two Sheaf pieces worn")
	truthy(screen.find_child("Attune_sheaf_Air", true, false) != null, "attune buttons appear at 2 pieces")
	eq(bool(screen.choose_attune("sheaf", "Earth")["ok"]), true, "attune from the screen")
	var saved := GearBag.load_saved()
	eq(saved.attune_active("sheaf"), "Earth", "screen saves the bag")
	eq(saved.find(h2), -1, "burned copy stays gone after save")
	screen.take_off("chest")
	eq(GearBag.load_saved().equipped.has("chest"), false, "take off saves")
	hub.free()


func _test_stasis_chest_wiring() -> void:
	var fight: Script = load("res://scenes/stasis_fight.gd")
	eq(fight.chest_line({"chest": false, "items": []}), "Chest empty — 5 loot clears used today.", "empty chest copy")
	eq(fight.chest_line({"chest": true, "items": [{"item_id": "undertow.legs", "plus": 0}]}), "Chest: Undertow Legs +0. Wear it in Gear.", "chest copy names the piece")
	var src := FileAccess.get_file_as_string("res://scenes/stasis_fight.gd")
	truthy(src.contains("record_stasis_clear"), "a Stasis clear opens the chest")
	eq(src.contains("KoliseoWallet"), false, "Stasis never pays Koliseo coins")
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
	eq(clear["winners"][0]["loot"], [{"kind": "gear", "item_id": "sheaf.boots", "plus": 0, "count": 1}], "chest piece shows as loot")
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
