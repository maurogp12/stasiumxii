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
	_test_save_roundtrip()
	_test_gear_screen()
	_test_stasis_chest_wiring()
	_test_combat_result()
	_test_gear_in_fights()
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


## Mauro 29 Sep 2026: "dungs with 1 star should only loot normal gear, above
## 3 star is when start looting rare and only 5 legendary".
func _test_loot_by_star() -> void:
	var want := {
		1: ["sheaf", "undertow"],
		2: ["sheaf", "undertow"],
		3: ["ironveil", "sheaf", "stillcut", "undertow"],
		4: ["ironveil", "sheaf", "stillcut", "undertow"],
		5: ["brightedge", "ironveil", "sheaf", "stillcut", "undertow"],
	}
	for star in want:
		var bag := GearBag.new()
		var n := [0]
		var pick := func() -> float:
			n[0] += 1
			return fposmod(float(n[0]) * 0.1373, 1.0)
		var seen := {}
		for d in 40:
			for it in bag.record_stasis_clear(T0 + d * DAY, int(star), pick)["items"]:
				seen[GearBag.family_of(str(it["item_id"]))] = true
		var got: Array = seen.keys()
		got.sort()
		eq(got, want[star], "★%d drops exactly %s" % [star, ", ".join(want[star])])
	eq(str(GearBag.FAMILIES["sheaf"]["rarity"]), "Normal", "Sheaf is Normal")
	eq(str(GearBag.FAMILIES["ironveil"]["rarity"]), "Rare", "Ironveil is Rare")
	eq(str(GearBag.FAMILIES["brightedge"]["rarity"]), "Legendary", "Brightedge is Legendary")
	var a := GearBag.icon("sheaf.chest")
	eq(a != null, true, "Sheaf chest icon loads")
	eq(a == GearBag.icon("sheaf.chest"), true, "icons are cached so result/inventory draws keep them alive")


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
	_test_inventory_screen()


func _test_inventory_screen() -> void:
	_wipe()
	HeroProgress.save_path = "user://test_hero_inventory.json"
	KoliseoWallet.save_path = "user://test_wallet_inventory.json"
	for p in [HeroProgress.save_path, KoliseoWallet.save_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var seed := GearBag.new()
	var a := seed.add_item("sheaf", "head")
	var b := seed.add_item("sheaf", "head")
	var w := seed.add_item("duskbrand", "weapon")
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
	eq(inv.stats()["hp"], 80, "bare champion has 80 HP")
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
	eq(inv.stats()["hp"], 80 + int(GearBag.part_stats("sheaf.head", 1)["hp"]), "worn head adds its HP")
	inv.wear(w)
	eq(inv.stats()["mastery"], int(GearBag.part_stats("duskbrand.weapon", 0)["mastery"]) + int(GearBag.part_stats("sheaf.head", 1)["mastery"]), "worn weapon adds Mastery")
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
	eq(stage.rune_tint, GearScreen.RARITY_TINT["Ultra"], "runes glow with the rarest worn piece (Duskbrand = Ultra)")
	inv.pick_champion("bastion")
	eq(inv.champion, "bastion", "pick another champion")
	eq(stage.class_id, "bastion", "the stage shows the picked champion")
	eq(stage.facing(), "s", "a new champion faces you")
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
	inv.show_tab("equipment")
	var tile := inv.find_child("Item_%d" % w, true, false)
	truthy(tile != null and tile.icon_tex != null, "bag tiles draw the set art")
	var weapon_slot := inv.find_child("Slot_weapon", true, false)
	eq(weapon_slot.icon_tex.resource_path.get_file(), "duskbrand_weapon_bastion.png", "the worn weapon shows the picked champion's weapon")
	inv.pick_champion("kestrel")
	weapon_slot = inv.find_child("Slot_weapon", true, false)
	eq(weapon_slot.icon_tex.resource_path.get_file(), "duskbrand_weapon_kestrel.png", "switching champion swaps the weapon art")
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
	eq([int(plain["max_hp"]), int(plain["max_ap"]), int(plain["max_mp"]), int(plain["mastery"]), int(plain["resist"])], [80, 6, 3, 0, 0], "no gear = 80 HP, 6/3, Mastery 0, Resist 0")
	# Sheaf 5pc on seat 0, Duskbrand 5pc on seat 1.
	sim.reset_match({"classes": ["kestrel", "ironjaw"], "skip_deploy": true, "seat_gear": {
		0: {"worn": _worn("sheaf", GearBag.SLOTS)},
		1: {"worn": _worn("duskbrand", GearBag.SLOTS)},
	}})
	var sheaf: Dictionary = sim._unit_by_seat(0)
	var dusk: Dictionary = sim._unit_by_seat(1)
	eq(int(sheaf["max_hp"]), 196, "Sheaf 5: (80 + 98 part HP) × 1.10 = 196")
	eq(int(sheaf["hp"]), 196, "fight starts at full geared HP")
	eq(int(sheaf["mastery"]), 18, "Sheaf 5: 10 part Mastery + 8 (4pc) = 18")
	eq(int(sheaf["resist"]), 8, "Sheaf 5pc +8% all resist")
	eq(sheaf["resist_elem"], {"earth": 15}, "Sheaf part resist 15 goes to its default Earth attune")
	eq(sheaf["flex_riders"], {"earth": 10}, "Sheaf 2-piece rider +10% Earth FLEX")
	eq(int(sheaf["init"]), 3, "Sheaf boots Init 3")
	eq(int(dusk["max_ap"]), 7, "Duskbrand 5pc → 7 AP")
	eq(int(dusk["max_mp"]), 4, "Duskbrand 5pc → 4 MP")
	eq(int(dusk["max_hp"]), 149, "Duskbrand: (80 + 58) × 1.08 = 149")
	eq(int(dusk["mastery"]), 27, "Duskbrand: 24 part Mastery × 1.12 = 27")
	eq(dusk["resist_elem"], {"neutral": 9}, "Duskbrand has no attune — resist stays Neutral")
	eq(int(dusk["init"]), 18, "Duskbrand Init 12 parts + 6 (4pc) = 18")
	var snap: Dictionary = sim.snapshot()
	sim.submit({"type": "end_turn", "seat": int(snap["active_seat"])})
	var after: Dictionary = sim._unit_by_seat(1)
	eq([int(after["ap"]), int(after["mp"])], [7, 4], "Duskbrand refills 7 AP / 4 MP at turn start")
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
	var att := GearBag.combat_stats(_worn("ironveil", ["head", "chest"]), {"ironveil": "Fire"})
	eq(att["resist_elem"], {"fire": 19}, "Ironveil pick Fire: parts 5+6 plus 2pc +8 = 19 vs fire")
	eq(att["riders"], {"fire": 10}, "Ironveil Fire rider +10%")
	var neutral := GearBag.combat_stats(_worn("ironveil", ["head"]), {"ironveil": "Fire"})
	eq(neutral["resist_elem"], {"neutral": 5}, "1 piece: attune grey, resist Neutral")
	var still := GearBag.combat_stats(_worn("stillcut", ["head", "chest"]), {})
	eq(still["riders"], {}, "Stillcut has no default element — player must pick")
	# Sheet page 23 "Same parts, same numbers": full +0 set part totals.
	var sheet := {"sheaf": [98, 10, 15, 3], "undertow": [64, 17, 9, 18], "ironveil": [90, 8, 27, 3], "stillcut": [92, 32, 18, 8], "brightedge": [54, 32, 7, 4], "duskbrand": [58, 24, 9, 12]}
	for fam in sheet:
		var tot := [0, 0, 0, 0]
		for slot in GearBag.SLOTS:
			var st := GearBag.part_stats("%s.%s" % [fam, slot], 0)
			tot = [tot[0] + int(st["hp"]), tot[1] + int(st["mastery"]), tot[2] + int(st["resist"]), tot[3] + int(st["init"])]
		eq(tot, sheet[fam], "%s part totals match the sheet (HP, Mastery, Resist, Init)" % fam)
	# Fuse ladder multipliers.
	eq(GearBag.part_stats("sheaf.head", 5)["hp"], 50, "Sheaf Helm 28 HP × 1.78 at +5 = 50")
	eq(GearBag.part_stats("stillcut.weapon", 3)["mastery"], 20, "Second-Edge 14 × 1.41 at +3 = 20")
	var flat := GearBag.combat_stats(_worn("sheaf", ["head"], 5), {}, true)
	eq(int(flat["hp_flat"]), 28, "Koliseo flatten: a +5 helm counts as +0")
	eq(GearBag.item_label({"item_id": "stillcut.chest", "plus": 2}), "Hourplate +2", "items use the sheet names")
	eq(GearBag.weighted_slot(0.0), "weapon", "slot roll 0 → weapon")
	eq(GearBag.weighted_slot(0.17), "weapon", "weapon is the first 18%")
	eq(GearBag.weighted_slot(0.19), "head", "then head")
	eq(GearBag.weighted_slot(0.999), "boots", "boots last")
	# Cheats and junk are cleaned: bad ids, duplicate slots, +9, AP cap.
	var junk := GearBag.combat_stats([{"item_id": "duskbrand.head", "plus": 9}, {"item_id": "duskbrand.head"}, {"item_id": "wheat.legs"}, "x"])
	eq([junk["ap"], junk["mp"], junk["hp_pct"]], [6, 3, 0], "one Duskbrand head gives nothing")
	var capped := GearBag.ap_mp_of_worn(_worn("stillcut", GearBag.SLOTS, 5))
	eq([capped["ap"], capped["mp"]], [7, 4], "rare gate +1/+1 at full +5 Stillcut")
	eq(int(GearBag.ap_mp_of_worn(_worn("duskbrand", GearBag.SLOTS))["ap"]) <= 8, true, "AP never above 8")
	# Mid-combat gear is refused; deployment accepts it.
	eq(sim.set_seat_gear(0, {"worn": _worn("sheaf", ["head", "chest"])}), false, "gear cannot change mid-combat")
	sim.reset_match({"classes": ["kestrel", "ironjaw"]})
	eq(sim.set_seat_gear(1, {"worn": _worn("sheaf", ["head", "chest"])}), true, "gear applies during deployment")
	eq(int(sim._unit_by_seat(1)["max_hp"]), 163, "late gear raised seat 1 HP to (80+28+40)×1.10")
	# Authority: a reset config cannot smuggle gear; each seat's own gear is used.
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.mode = net.Mode.DEDICATED
	net._seat_gear[1] = {"worn": _worn("sheaf", ["head", "chest"]), "attune": {}}
	var cfg: Dictionary = net._authority_gear_config({"seat_gear": {0: {"worn": _worn("duskbrand", GearBag.SLOTS)}}})
	eq(cfg["seat_gear"].has(0), false, "smuggled seat 0 gear is dropped")
	eq(cfg["seat_gear"][1]["worn"].size(), 2, "seat 1 keeps the gear it sent")
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
	eq(int(sim._unit_by_seat(0)["max_hp"]), 163, "Stasis player gets helm + coat HP and Sheaf 2pc +10%")
	StasisCatalog.player_hp = 60
	sim.reset_match(StasisCatalog.fight_config())
	eq(int(sim._unit_by_seat(0)["hp"]), 60, "Room B carries Room A HP under the geared max")
	StasisCatalog.clear_run()
	_wipe()


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
