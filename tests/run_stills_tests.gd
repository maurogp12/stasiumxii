extends SceneTree

## Locked Stills (Mauro 9 Oct 2026): 14 hours, Intact and Overwound,
## forge / socket / online carry, and one fight check per Still per mode.
## Run: godot --headless --path . -s res://tests/run_stills_tests.gd

const SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const TEST_STILL := "user://test_stills_vault.json"
const TEST_BAG := "user://test_stills_bag.json"
const TEST_HERO := "user://test_stills_hero.json"
const TEST_WALLET := "user://test_stills_wallet.json"

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	StillVault.save_path = TEST_STILL
	GearBag.save_path = TEST_BAG
	HeroProgress.save_path = TEST_HERO
	KoliseoWallet.save_path = TEST_WALLET
	_sim = root.get_node("/root/CombatSim")
	_wipe()
	_test_vault()
	_test_still_categories()
	_test_hourglass()
	_test_set_still_pools()
	_test_steadfast()
	_test_tide()
	_test_rewind()
	_test_long_shadow()
	_test_withering()
	_test_shatterglass()
	_test_tolling_bell()
	_test_bleeding_hour()
	_test_still_own_turn()
	_test_mirror_hour()
	_test_held_hour()
	_test_bound_hour()
	_test_gathered_sand()
	_test_carry_and_online()
	_test_clear_text_and_icons()
	_test_screen()
	_test_card_lines()
	_test_still_action_button()
	_test_still_target_rules()
	await _test_still_target_board()
	_wipe()
	print("Stills tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _gear(still: String, mode: String) -> Dictionary:
	return {"worn": [], "still": {"id": still, "mode": mode}}


func _fight(seat0: Dictionary, seat1: Dictionary = {}, classes: Array = ["kestrel", "ironjaw"], rolls: Array = [], positions: Array = []) -> void:
	var sg := {0: seat0}
	if not seat1.is_empty():
		sg[1] = seat1
	var config := {"classes": classes, "skip_deploy": true, "positions": [Vector2i(5, 7), Vector2i(6, 7)], "seat_gear": sg}
	if not positions.is_empty():
		config["positions"] = positions
	if not rolls.is_empty():
		config["rolls"] = rolls
	_sim.reset_match(config)


func _team(gear0: Dictionary, classes: Array, positions: Array) -> void:
	_sim.reset_match({
		"team_size": 2,
		"classes": classes,
		"skip_deploy": true,
		"positions": positions,
		"seat_gear": {0: gear0},
	})


func _end_turns(n: int) -> void:
	for i in n:
		_sim.submit({"type": "end_turn", "seat": int(_sim.snapshot()["active_seat"])})


func _u(seat: int) -> Dictionary:
	return _sim._unit_by_seat(seat)


func _test_vault() -> void:
	eq(StillVault.IDS.size(), 14, "fourteen Stills")
	eq(StillVault.display_name("hourglass_fist"), "Hourglass Fist", "names are words, not ids")
	eq(StillVault.clean({"id": "opening", "mode": "intact"}), {}, "old Opening id is rejected")
	eq(StillVault.clean({"id": "crown", "mode": "intact"}), {}, "old Crown id is rejected")
	var v := StillVault.new()
	var picks := [0.0, 0.99]
	var i := [0]
	var pick := func() -> float:
		var x: float = picks[i[0] % picks.size()]
		i[0] += 1
		return x
	eq(v.roll_chest(1, pick), ["steadfast"], "★1 chest rolls 1 fragment")
	eq(v.roll_chest(5, pick).size(), 3, "★5 chest rolls 3 fragments")
	eq(v.roll_chest(3, pick).size(), 2, "★3 chest rolls 2 fragments")
	v.fragments = {"steadfast": 11, "tide": 5}
	eq(str(v.forge("steadfast")["reason"]), "needs_12", "forge needs 12 of the same")
	v.fragments["steadfast"] = 13
	eq(bool(v.forge("steadfast")["ok"]), true, "12 Steadfast fragments forge Steadfast")
	eq(v.count("steadfast"), 1, "leftover fragment stays")
	eq(v.socket, "steadfast", "Steadfast sits in the socket")
	v.fragments["tide"] = 12
	eq(str(v.forge("tide")["reason"]), "socket_full", "socket must be empty to forge")
	eq(bool(v.set_mode("overwound")["ok"]), true, "choose Overwind")
	eq(v.fight_still(), {"id": "steadfast", "mode": "overwound"}, "the fight gets id + mode")
	eq(v.consume(), "steadfast", "the fight destroys it")
	eq(v.socket, "", "socket empty after the fight")
	v.fragments["tide"] = 12
	v.fragments["mirror_hour"] = 12
	v.set_focus("ironjaw")
	eq(bool(v.forge("tide")["ok"]), true, "Ironjaw forges into his own socket")
	eq(v.socket_of("ironjaw"), "tide", "Tide is on Ironjaw")
	eq(v.socket_of("kestrel"), "", "Kestrel's socket stays empty")
	eq(bool(v.set_mode("overwound")["ok"]), true, "Ironjaw can Overwind")
	v.set_focus("kestrel")
	eq(bool(v.forge("mirror_hour")["ok"]), true, "Kestrel forges while Ironjaw's socket is full")
	eq(v.fight_still("ironjaw"), {"id": "tide", "mode": "overwound"}, "a fight uses Ironjaw's socket")
	eq(v.fight_still("kestrel"), {"id": "mirror_hour", "mode": "intact"}, "a fight uses Kestrel's socket")
	eq(v.consume("ironjaw"), "tide", "the fight breaks only Ironjaw's Still")
	eq(v.socket_of("kestrel"), "mirror_hour", "Kestrel's Still survives Ironjaw's fight")
	var legacy := StillVault.new()
	legacy.from_dict({"socket": "bound_hour", "mode": "overwound", "fragments": {}})
	eq(legacy.socket_of("kestrel"), "bound_hour", "an old socket is kept on Kestrel")
	eq(legacy.mode_of("kestrel"), "overwound", "the old mode is kept")
	eq(legacy.socket_of("gloam"), "", "the old socket is not copied onto every class")
	eq(StillVault.clean({"id": "wheat", "mode": "intact"}), {}, "unknown Still rejected")
	eq(StillVault.clean({"id": "tide", "mode": "super"}), {}, "unknown mode rejected")
	eq(StillVault.clean({"id": "mirror_hour", "mode": "overwound"}), {"id": "mirror_hour", "mode": "overwound"}, "the host keeps a new id")
	v.fragments["tide"] = 12
	v.save()
	var reloaded := StillVault.load_saved()
	eq(reloaded.count("tide"), 12, "vault saves and reloads")
	eq(reloaded.socket_of("kestrel"), "mirror_hour", "Kestrel's socket reloads")
	eq(reloaded.socket_of("ironjaw"), "", "Ironjaw's broken socket stays empty")


func _test_still_categories() -> void:
	var counts := {"offensive": 0, "defensive": 0, "support": 0}
	for id in StillVault.IDS:
		var cat := StillVault.category_of(id)
		truthy(StillVault.CATEGORIES.has(cat), "%s has one category" % id)
		counts[cat] += 1
		eq(StillVault.category_label(cat) != "", true, "%s has a category label" % id)
	eq(counts["offensive"] + counts["defensive"] + counts["support"], 14, "every Still is in one category")
	eq(counts["offensive"], 5, "five Offensive Stills")
	eq(counts["defensive"], 4, "four Defensive Stills")
	eq(counts["support"], 5, "five Support Stills")
	eq(StillVault.category_of("gathered_sand"), "defensive", "Gathered Sand reflect is Defensive")
	eq(StillVault.category_of("hourglass_fist"), "offensive", "Hourglass Fist is Offensive")
	eq(StillVault.category_of("bound_hour"), "support", "Bound Hour is Support")
	_wipe()
	var vault := StillVault.new()
	for id in StillVault.IDS:
		vault.fragments[id] = 24
	vault.set_focus("bastion")
	vault.socket = "gathered_sand"
	vault.save()
	for fight in [true, false]:
		var screen := InventoryScreen.new()
		screen.champion = "bastion"
		if fight:
			screen.set_fight_classes(["bastion"])
		root.add_child(screen)
		var where := "fight" if fight else "hub"
		screen.show_tab("stills")
		eq(screen.still_filter, "", "%s Stills start on All" % where)
		eq((screen.find_child("StillFilterAll", true, false) as Button).text, "All", "%s filter starts with All" % where)
		eq((screen.find_child("StillFilterDefensive", true, false) as Button).text, "Defensive", "%s filter offers Defensive" % where)
		var listed := 0
		for id in StillVault.IDS:
			if screen.find_child("Still_" + id, true, false) != null:
				listed += 1
		eq(listed, 14, "%s All lists every Still" % where)
		var compact := screen.find_child("Still_gathered_sand", true, false) as InventoryScreen.InvTile
		eq(compact.custom_minimum_size, InventoryScreen.STILL_TILE, "%s Still tiles use the compact size" % where)
		eq(compact.custom_minimum_size.x < 112, true, "%s Still tiles are smaller than the old grid" % where)
		eq((screen.find_child("Still_gathered_sand", true, false) as InventoryScreen.InvTile).tag, "Defensive", "%s Gathered Sand is tagged Defensive" % where)
		screen.set_still_filter("offensive")
		eq(screen.find_child("Still_shatterglass", true, false) != null, true, "%s Offensive keeps Shatterglass" % where)
		eq(screen.find_child("Still_gathered_sand", true, false), null, "%s Offensive hides Gathered Sand" % where)
		eq(screen.find_child("Socket", true, false) != null, true, "%s paperdoll socket stays while the grid filters" % where)
		screen.set_still_filter("defensive")
		eq(screen.find_child("Still_gathered_sand", true, false) != null, true, "%s Defensive keeps Gathered Sand" % where)
		eq(screen.find_child("Still_shatterglass", true, false), null, "%s Defensive hides Shatterglass" % where)
		eq(screen.find_child("Still_steadfast", true, false) != null, true, "%s Defensive keeps Steadfast" % where)
		screen.set_still_filter("support")
		eq(screen.find_child("Still_bound_hour", true, false) != null, true, "%s Support keeps Bound Hour" % where)
		eq(screen.find_child("Still_gathered_sand", true, false), null, "%s Support hides Gathered Sand" % where)
		screen.show_tab("equipment")
		eq((screen.find_child("RarityRow", true, false) as Control).visible, true, "%s equipment keeps the rarity row" % where)
		eq(screen.find_child("StillFilterOffensive", true, false), null, "%s equipment hides the Still filter" % where)
		eq(screen.still_filter, "support", "%s Still filter stays when the tab returns" % where)
		screen.show_tab("stills")
		eq(screen.find_child("Still_bound_hour", true, false) != null, true, "%s Support is still on when Stills returns" % where)
		screen.set_still_filter("")
		eq(screen.find_child("Still_gathered_sand", true, false) != null, true, "%s All shows Gathered Sand again" % where)
		if not fight:
			screen.show_tab("consumables")
			eq((screen.find_child("RarityRow", true, false) as Control).visible, false, "the filter hides off Equipment and Stills")
		screen.free()
	_wipe()


func _test_hourglass() -> void:
	_fight(_gear("hourglass_fist", "intact"))
	eq([int(_u(0)["max_ap"]), int(_u(0)["max_mp"])], [8, 2], "Fist Intact: 6/3 → 8/2, AP stays at the cap")
	eq([int(_u(0)["ap"]), int(_u(0)["mp"])], [8, 2], "Fist Intact fills from the new max")
	_end_turns(2)
	eq([int(_u(0)["ap"]), int(_u(0)["mp"])], [8, 2], "Fist Intact is the whole fight, not a turn buff")
	_fight(_gear("hourglass_fist", "overwound"))
	eq([int(_u(0)["max_ap"]), int(_u(0)["max_mp"])], [9, 1], "Fist Overwound: +3 AP past 8, −2 MP")
	_fight(_gear("hourglass_step", "intact"))
	eq([int(_u(0)["max_ap"]), int(_u(0)["max_mp"])], [5, 5], "Step Intact: −1 AP, +2 MP at the cap")
	_fight(_gear("hourglass_step", "overwound"))
	eq([int(_u(0)["max_ap"]), int(_u(0)["max_mp"])], [4, 6], "Step Overwound: −2 AP, +3 MP past 5")
	var dusk: Array = []
	for slot in GearBag.SLOTS:
		dusk.append({"item_id": "brightedge.%s" % slot, "plus": 0})
	var strong := {"worn": dusk, "heroes": {"kestrel": {"level": 20, "spent": {}}}, "still": {"id": "hourglass_fist", "mode": "overwound"}}
	_fight(strong)
	eq(int(_u(0)["max_ap"]) > 8, true, "Fist Overwound still passes 8 on a capped build (got %d)" % int(_u(0)["max_ap"]))


func _worn(family: String) -> Array:
	var out: Array = []
	for slot in GearBag.SLOTS:
		out.append({"item_id": "%s.%s" % [family, slot], "plus": 5})
	return out


## Level 30, Pitmaw on Ironjaw, Sandhawk on Kestrel, Hourglass Step and
## Fist Intact. Dungeon and Koliseo both start at 8/3 and 7/5, matching
## the inventory sheet.
func _test_set_still_pools() -> void:
	var heroes := {"kestrel": {"level": 30, "spent": {}}, "ironjaw": {"level": 30, "spent": {}}}
	var kite := {"worn": _worn("sandhawk"), "heroes": heroes, "still": {"id": "hourglass_fist", "mode": "intact"}}
	var jaw := {"worn": _worn("pitmaw"), "heroes": heroes, "still": {"id": "hourglass_step", "mode": "intact"}}
	_fight(kite, jaw)
	eq([int(_u(0)["max_ap"]), int(_u(0)["max_mp"])], [8, 3], "a dungeon keeps Kestrel's Ultra 5pc (8/3)")
	eq([int(_u(1)["max_ap"]), int(_u(1)["max_mp"])], [7, 5], "a dungeon keeps Ironjaw's Ultra 5pc (7/5)")
	kite["flatten_plus"] = true
	jaw["flatten_plus"] = true
	_fight(kite, jaw)
	eq([int(_u(0)["ap"]), int(_u(0)["max_ap"]), int(_u(0)["mp"]), int(_u(0)["max_mp"])], [8, 8, 3, 3], "Koliseo Kestrel is the same 8 AP / 3 MP")
	eq([int(_u(1)["ap"]), int(_u(1)["max_ap"]), int(_u(1)["mp"]), int(_u(1)["max_mp"])], [7, 7, 5, 5], "Koliseo Ironjaw is the same 7 AP / 5 MP")
	eq(StillVault.adjust_ap_mp(8, 4, "hourglass_fist", "intact"), {"ap": 8, "mp": 3}, "Fist Intact from a 5pc pool")
	eq(StillVault.adjust_ap_mp(8, 4, "hourglass_step", "intact"), {"ap": 7, "mp": 5}, "Step Intact from a 5pc pool")
	eq(StillVault.adjust_ap_mp(8, 4, "tide", "intact"), {"ap": 8, "mp": 4}, "Tide does not move AP or MP")
	var bag := GearBag.new()
	for slot in GearBag.SLOTS:
		bag.equip(bag.add_item("pitmaw", slot, 5), "ironjaw")
		bag.equip(bag.add_item("sandhawk", slot, 5), "kestrel")
	var hero := HeroProgress.new()
	hero.classes = {"ironjaw": {"xp": 0, "level": 30, "spent": {}}, "kestrel": {"xp": 0, "level": 30, "spent": {}}}
	var vault := StillVault.new()
	vault.set_focus("ironjaw")
	vault.socket = "hourglass_step"
	vault.mode = "intact"
	vault.set_focus("kestrel")
	vault.socket = "hourglass_fist"
	vault.mode = "intact"
	vault.save()
	var sheet: Script = load("res://scenes/inventory_screen.gd")
	var jaw_sheet: Dictionary = sheet.champion_stats(bag, hero, "ironjaw")
	var kite_sheet: Dictionary = sheet.champion_stats(bag, hero, "kestrel")
	eq([int(jaw_sheet["ap"]), int(jaw_sheet["mp"])], [7, 5], "Ironjaw's inventory matches his fight card")
	eq([int(kite_sheet["ap"]), int(kite_sheet["mp"])], [8, 3], "Kestrel's inventory matches her fight card")


func _test_steadfast() -> void:
	_fight(_gear("steadfast", "intact"))
	eq(int(_sim._apply_stun(_u(0), 1)), 0, "Steadfast Intact eats the first Stun")
	eq(int(_u(0).get("stun_remaining", 0)), 0, "the turn is not skipped")
	eq(int(_u(0).get("steadfast_ap", 0)), 3, "that turn will be −3 AP")
	_end_turns(2)
	eq(int(_u(0)["ap"]), 3, "the skipped turn became 6 − 3 AP")
	eq(int(_sim._apply_stun(_u(0), 1)), 1, "the next Stun lands")
	_fight(_gear("steadfast", "overwound"))
	eq(int(_sim._apply_stun(_u(0), 1)), 0, "Steadfast Overwound ignores the first Stun")
	eq(int(_u(0).get("steadfast_ap", 0)), 0, "ignored, with no AP cut")
	var before := int(_u(0).get("burn_remaining", 0))
	_sim._apply_burn(_u(0))
	eq(int(_u(0)["burn_remaining"]), before + 2 + 1, "other debuffs last +1 turn")
	eq(int(_sim._apply_stun(_u(0), 1)), 1, "a later Stun is a real skip")


func _test_tide() -> void:
	_fight(_gear("tide", "intact"))
	_sim._apply_burn(_u(0))
	_sim._apply_mud_slow(_u(0))
	eq(int(_u(0).get("burn_remaining", 0)), 0, "Tide Intact removes the first debuff")
	eq(int(_u(0).get("slow_remaining", 0)), 0, "Tide Intact removes the second debuff")
	eq(int(_u(0).get("tide_stripped", 0)), 2, "two charges spent")
	_sim._apply_burn(_u(0))
	eq(int(_u(0).get("burn_remaining", 0)) > 0, true, "the third debuff sticks")
	_fight(_gear("tide", "overwound"))
	_sim._apply_burn(_u(0))
	eq(int(_u(0).get("burn_remaining", 0)) > 0, true, "Tide Overwound lets the first debuff land")
	eq(int(_u(0).get("tide_window", 0)), 3, "the next 3 turns will clear debuffs")
	_end_turns(2)
	eq(int(_u(0).get("burn_remaining", 0)), 0, "debuffs are gone at the next turn start")
	eq(int(_u(0).get("tide_window", 0)), 2, "two clears remain")
	_end_turns(4)
	eq(bool(_u(0).get("tide_heal_weak", false)), true, "after the third clear, heals are weaker")
	_u(0)["hp"] = 40
	eq(int(_sim._apply_heal(_u(0), 20)), 15, "heals on you are 25% weaker")


func _test_rewind() -> void:
	_fight(_gear("rewind", "intact"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 100
	_end_turns(1)
	_sim._lose_hp(_u(0), 40)
	eq(int(_u(0).get("rewind_loss", 0)), 40, "the loss counts during the enemy turn")
	_end_turns(1)
	eq(int(_u(0)["hp"]), 80, "Rewind Intact gives half back at your next turn")
	eq(bool(_u(0).get("rewind_used", false)), true, "Rewind fires once")
	_fight(_gear("rewind", "overwound"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 100
	_end_turns(1)
	_sim._lose_hp(_u(0), 20)
	_end_turns(1)
	eq(int(_u(0)["hp"]), 80, "under 30% does not rewind")
	eq(bool(_u(0).get("rewind_used", false)), false, "the charge is still there")
	_u(0)["hp"] = 100
	_end_turns(1)
	_sim._lose_hp(_u(0), 40)
	_end_turns(1)
	eq(int(_u(0)["hp"]), 100, "Rewind Overwound gives all of it back")
	eq(bool(_u(0).get("rewind_block_ally", false)), true, "allies cannot heal you after that burst")
	_team(_gear("rewind", "overwound"), ["kestrel", "ironjaw", "bastion", "gloam"], [Vector2i(5, 7), Vector2i(8, 7), Vector2i(6, 7), Vector2i(9, 7)])
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 100
	_end_turns(1)
	_sim._lose_hp(_u(0), 40)
	_end_turns(1)
	_u(0)["hp"] = 50
	eq(int(_sim._apply_heal(_u(0), 10, _u(2))), 0, "an ally heal is refused")
	eq(int(_sim._apply_heal(_u(0), 10, _u(0))), 10, "a self heal still lands")


func _test_long_shadow() -> void:
	truthy(StillVault.plain("long_shadow", "intact").contains("3 or more tiles"), "inventory text says 3 or more tiles")
	truthy(StillVault.plain("long_shadow", "overwound").contains("3 or more tiles"), "Overwound inventory text says 3 or more tiles")
	eq(StillVault.plain("long_shadow", "intact").contains("4 or more"), false, "the old 4-tile line is gone")
	_fight({}, _gear("long_shadow", "intact"), ["kestrel", "bastion"], [], [Vector2i(2, 7), Vector2i(4, 7)])
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 2, "2 tiles is not a long hit")
	_sim._mitigate_hit(_u(0), _u(1), 20)
	eq(int(_u(1).get("shadow_mp_kept", 0)), 0, "Long Shadow does not trigger at 2 tiles")
	_fight({}, _gear("long_shadow", "intact"), ["kestrel", "bastion"], [], [Vector2i(2, 7), Vector2i(5, 7)])
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 3, "the hit is from 3 tiles")
	var pool := int(_u(1)["mp"])
	var far := int(_sim._mitigate_hit(_u(0), _u(1), 20)["damage"])
	eq(far, 20, "Long Shadow Intact does not change the hit")
	eq(int(_u(1)["mp"]), pool + 2, "a 3-tile hit adds +2 MP immediately")
	eq(int(_u(1).get("shadow_mp_kept", 0)), 2, "that +2 is remembered through the refill")
	eq(bool(_u(1).get("shadow_this_turn", false)), true, "the first far hit spends this turn's grant")
	_sim._mitigate_hit(_u(0), _u(1), 20)
	_sim._mitigate_hit(_u(0), _u(1), 20)
	eq(int(_u(1).get("shadow_hits", 0)), 1, "later far hits in the same turn do not grant")
	eq(int(_u(1)["mp"]), pool + 2, "three far hits in one turn add +2 MP total")
	_end_turns(1)
	eq(int(_u(1)["mp"]), int(_u(1)["max_mp"]) + 2, "the refill keeps the MP the hit added")
	eq(int(_u(1).get("shadow_mp_kept", 0)), 0, "the kept MP is folded into the refilled pool")
	eq(bool(_u(1).get("shadow_this_turn", false)), false, "the next turn starts with the grant available")
	_fight({}, _gear("long_shadow", "intact"), ["kestrel", "bastion"], [], [Vector2i(2, 7), Vector2i(6, 7)])
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 4, "4 tiles still counts")
	pool = int(_u(1)["mp"])
	_sim._mitigate_hit(_u(0), _u(1), 20)
	eq(int(_u(1)["mp"]), pool + 2, "a 4-tile hit still grants +2 MP")
	_fight({}, _gear("long_shadow", "overwound"), ["kestrel", "bastion"])
	var near := int(_sim._mitigate_hit(_u(0), _u(1), 20)["damage"])
	eq(near, 22, "adjacent enemies deal +10% even before a long hit")
	_fight({}, _gear("long_shadow", "overwound"), ["kestrel", "bastion"], [], [Vector2i(2, 7), Vector2i(6, 7)])
	_u(1)["max_mp"] = 5
	_u(1)["mp"] = 5
	for n in 4:
		_sim._mitigate_hit(_u(0), _u(1), 10)
	eq(int(_u(1).get("shadow_hits", 0)), 1, "Overwound still grants once per turn")
	eq(int(_u(1).get("shadow_mp_kept", 0)), 2, "four far hits add +2 MP, not +2 each")
	eq(int(_u(1)["mp"]), 7, "the MP is on Bastion before his turn")
	_end_turns(1)
	eq(int(_u(1)["mp"]), 7, "Overwound MP stays past 5 after the refill")
	_fight({}, _gear("long_shadow", "intact"), ["kestrel", "bastion"], [], [Vector2i(2, 7), Vector2i(4, 9)])
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 2, "a diagonal of 2 is still 2 tiles")
	eq(_sim.manhattan(_u(0)["pos"], _u(1)["pos"]), 4, "that same gap is 4 by Manhattan")
	_sim._mitigate_hit(_u(0), _u(1), 20)
	eq(int(_u(1).get("shadow_mp_kept", 0)), 0, "Long Shadow uses Chebyshev, so 2 tiles does not grant")
	_fight({}, _gear("long_shadow", "intact"), ["kestrel", "bastion"], [], [Vector2i(2, 7), Vector2i(5, 9)])
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 3, "a diagonal of 3 counts")
	_sim._mitigate_hit(_u(0), _u(1), 20)
	eq(int(_u(1)["mp"]), int(_u(1)["max_mp"]) + 2, "Chebyshev 3 grants even when the steps are not in a straight line")
	_test_long_shadow_casts()


## Kestrel's turn, distance 3 (two empty tiles between). Mark Shot soaked by
## the shield, a second Mark Shot, then Detonate. The first far hit adds +2 MP.
## The other two in that same turn do not. The next enemy turn can add +2 again.
func _test_long_shadow_casts() -> void:
	_sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "bastion"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"rolls": [1],
		"seat_gear": {1: _gear("long_shadow", "intact")},
	})
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 2, "Mark Shot at 2 tiles is in range")
	var close: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "seat": 0, "to": _u(1)["pos"]})
	eq(bool(close.get("ok", false)), true, "the 2-tile Mark Shot connects")
	eq(int(_u(1).get("shadow_mp_kept", 0)), 0, "a 2-tile Mark Shot does not grant Bastion MP")
	_sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "bastion"],
		"positions": [Vector2i(1, 1), Vector2i(4, 1)],
		"rolls": [1, 1, 1, 1, 1],
		"seat_gear": {1: _gear("long_shadow", "intact")},
	})
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 3, "two empty tiles between them is distance 3")
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]) >= 3, true, "the check is 3 or more, not 4 or more")
	_u(0)["ap"] = 8
	_u(1)["mp"] = 1
	_u(1)["aegis"] = 1
	_u(1)["shield"] = 80
	var hp := int(_u(1)["hp"])
	var soaked: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "seat": 0, "to": _u(1)["pos"]})
	var soaked_hit := _hit_event(soaked.get("events", []))
	eq(bool(soaked.get("ok", false)), true, "the soaked Mark Shot connects")
	eq(int(soaked_hit.get("damage", -1)), 0, "the shield takes the whole hit")
	eq(int(_u(1)["hp"]), hp, "Bastion loses no HP")
	eq(int(_u(1)["aegis"]), 1, "Aegis is not what soaked the hit")
	eq(int(_u(1)["mp"]), 3, "the soaked hit still gives +2 MP")
	eq(_gained_mp(soaked.get("events", [])), 2, "the log records +2 MP on the soaked hit")
	eq(_float_says_mp(soaked_hit), true, "the soaked hit shows +2 MP")
	_u(1)["shield"] = 0
	var shot: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "seat": 0, "to": _u(1)["pos"]})
	var shot_hit := _hit_event(shot.get("events", []))
	eq(int(shot_hit.get("damage", 0)) > 0, true, "the second Mark Shot deals HP damage")
	eq(int(_u(1)["mp"]), 3, "the second Mark Shot does not give more MP")
	eq(_gained_mp(shot.get("events", [])), 0, "the second hit records no MP")
	eq(_float_says_mp(shot_hit), false, "the second hit does not show +2 MP")
	var boom: Dictionary = _sim.submit({"type": "cast", "spell": "detonate", "seat": 0, "to": _u(1)["pos"]})
	var boom_hit := _hit_event(boom.get("events", []))
	eq(bool(boom.get("ok", false)), true, "Detonate connects from 3 tiles")
	eq(int(boom_hit.get("damage", 0)) > 0, true, "Detonate deals HP damage")
	eq(int(_u(1)["mp"]), 3, "three far hits in one turn add +2 MP total")
	eq(int(_u(1).get("shadow_hits", 0)), 1, "only the first far hit granted MP")
	eq(_gained_mp(boom.get("events", [])), 0, "Detonate records no MP after the first hit")
	eq(_float_says_mp(boom_hit), false, "Detonate does not show +2 MP after the first hit")
	var hud := CombatHUD.new()
	eq(hud._still_state_line(_u(1)).contains("Long Shadow +2 MP"), true, "Bastion's card names the gained MP")
	hud.free()
	var guest_script := load("res://backend/combat_sim.gd")
	var guest: Node = guest_script.new()
	guest.apply_host_snapshot(_sim.snapshot())
	var guest_mp := -1
	var guest_kept := -1
	var guest_spent := false
	for unit in guest.snapshot()["units"]:
		if int(unit.get("seat", -1)) == 1:
			guest_mp = int(unit.get("mp", -1))
			guest_kept = int(unit.get("shadow_mp_kept", -1))
			guest_spent = bool(unit.get("shadow_this_turn", false))
	eq(guest_mp, 3, "the other phone shows the MP gained on her turn")
	eq(guest_kept, 2, "the other phone keeps the bonus through the refill")
	eq(guest_spent, true, "the other phone already spent this turn's grant")
	guest.free()
	var cap := int(_u(1)["max_mp"])
	_end_turns(1)
	eq(int(_sim.snapshot()["active_seat"]), 1, "it is Bastion's turn")
	eq(int(_u(1)["mp"]), cap + 2, "his refill does not throw away the +2 MP")
	eq(int(_u(1).get("shadow_mp_kept", 0)), 0, "the bonus now lives in his MP")
	eq(bool(_u(1).get("shadow_this_turn", false)), false, "his turn start clears the once-per-turn flag")
	_end_turns(1)
	eq(int(_sim.snapshot()["active_seat"]), 0, "it is Kestrel's turn again")
	var again_mp := int(_u(1)["mp"])
	var again_shot: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "seat": 0, "to": _u(1)["pos"]})
	eq(bool(again_shot.get("ok", false)), true, "the next turn's Mark Shot connects")
	eq(int(_u(1)["mp"]), again_mp + 2, "a far hit on a later turn gives +2 MP again")
	eq(int(_u(1).get("shadow_hits", 0)), 2, "each turn can grant once")
	eq(_gained_mp(again_shot.get("events", [])), 2, "the later turn records +2 MP")
	# Detonate is the first far hit of the turn, so it is the one that grants.
	_sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "bastion"],
		"positions": [Vector2i(1, 1), Vector2i(4, 1)],
		"rolls": [1],
		"seat_gear": {1: _gear("long_shadow", "intact")},
	})
	_u(0)["ap"] = 8
	_u(1)["mp"] = 1
	_u(1)["marks"] = 2
	var only_boom: Dictionary = _sim.submit({"type": "cast", "spell": "detonate", "seat": 0, "to": _u(1)["pos"]})
	var only_hit := _hit_event(only_boom.get("events", []))
	eq(bool(only_boom.get("ok", false)), true, "Detonate is a hit from 3 tiles")
	eq(int(_u(1)["mp"]), 3, "Detonate grants +2 MP when it is the first far hit")
	eq(_gained_mp(only_boom.get("events", [])), 2, "Detonate records +2 MP")
	eq(_float_says_mp(only_hit), true, "Detonate shows +2 MP")
	# Another Bastion yanks this one from 4 tiles. The pull ends next door, so
	# the distance has to be the gap at the hit, not the tile he lands on.
	_sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["bastion", "bastion"],
		"positions": [Vector2i(1, 1), Vector2i(5, 1)],
		"rolls": [1, 1],
		"seat_gear": {1: _gear("long_shadow", "intact")},
	})
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 4, "Hold the Line starts 4 tiles away")
	var pulled_mp := int(_u(1)["mp"])
	var pulled: Dictionary = _sim.submit({"type": "cast", "spell": "hold_line", "to": Vector2i(5, 1), "seat": 0})
	eq(bool(pulled.get("ok", false)), true, "Hold the Line from 4 tiles connects")
	eq(_u(1)["pos"], Vector2i(2, 1), "the pull lands Bastion next to the caster")
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 1, "after the pull he is adjacent")
	eq(int(_u(1)["mp"]), pulled_mp + 2, "the 4-tile gap still grants +2 MP")
	eq(int(_u(1).get("shadow_hits", 0)), 1, "the pull counted as one far hit")
	var again: Dictionary = _sim.submit({"type": "cast", "spell": "hold_line", "to": _u(1)["pos"], "seat": 0})
	eq(bool(again.get("ok", false)), true, "a second Hold the Line connects from next door")
	eq(int(_u(1)["mp"]), pulled_mp + 2, "the adjacent follow-up does not grant MP")
	eq(int(_u(1).get("shadow_hits", 0)), 1, "only the hit that started 4 tiles away counted")
	_sim.reset_match({
		"seed": 1, "flat_board": true, "skip_deploy": true,
		"classes": ["kestrel", "bastion"],
		"positions": [Vector2i(1, 1), Vector2i(5, 1)],
		"rolls": [1, 1],
		"seat_gear": {1: _gear("long_shadow", "intact")},
	})
	var hero_ai = load("res://backend/hero_ai.gd")
	var bot: Dictionary = hero_ai.plan(_sim, 0)
	eq(str(bot.get("spell", "")), "mark_shot", "the bot shoots Mark Shot from 4 tiles")
	var bot_mp := int(_u(1)["mp"])
	var bot_hit: Dictionary = _sim.submit(bot)
	eq(bool(bot_hit.get("ok", false)), true, "the bot's Mark Shot connects")
	eq(int(_u(1)["mp"]), bot_mp + 2, "the bot's hit adds Bastion's MP too")


func _test_withering() -> void:
	_fight(_gear("withering_sand", "intact"))
	_u(1)["hp"] = 40
	eq(int(_sim._apply_heal(_u(1), 20, _u(0))), 20, "the enemy is healed")
	eq(int(_u(0).get("wither_bonus", 0)), 10, "half the heal is stored, max 15")
	eq(int(_sim._mitigate_hit(_u(0), _u(1), 10)["damage"]), 20, "the next hit on that enemy adds it")
	eq(int(_u(0).get("wither_bonus", 0)), 0, "the bonus is spent")
	_sim._apply_heal(_u(1), 20, _u(0))
	eq(int(_u(0).get("wither_bonus", 0)), 0, "only the first heal arms Withering Sand")
	_fight(_gear("withering_sand", "overwound"))
	_u(1)["hp"] = 40
	_sim._apply_heal(_u(1), 30, _u(0))
	eq(int(_u(0).get("wither_bonus", 0)), 25, "Overwound stores the full heal, max 25")
	eq(_sim._still_can_shield(_u(0)), false, "Overwound cannot gain shields")
	eq(_sim._still_gain_shield(_u(0), 20), 0, "a shield grant is ignored")


func _test_shatterglass() -> void:
	_fight(_gear("shatterglass", "intact"))
	_u(1)["shield"] = 30
	var hit: Dictionary = _sim._mitigate_hit(_u(0), _u(1), 10)
	eq(int(hit["damage"]), 10, "the hit is not soaked")
	eq(int(_u(1).get("shield", 0)), 0, "the whole shield breaks")
	_u(1)["shield"] = 30
	eq(int(_sim._mitigate_hit(_u(0), _u(1), 10)["damage"]), 0, "later hits are soaked again")
	_fight(_gear("shatterglass", "overwound"))
	_u(1)["shield"] = 40
	var doubled: Dictionary = _sim._mitigate_hit(_u(0), _u(1), 10)
	eq(int(doubled["damage"]), 0, "the extra shield damage does not spill into HP")
	eq(int(_u(1).get("shield", 0)), 20, "the shield takes double")
	_u(1)["shield"] = 40
	_sim._mitigate_hit(_u(0), _u(1), 10)
	eq(int(_u(1).get("shield", 0)), 20, "every hit doubles into the shield")
	eq(_sim._still_can_shield(_u(0)), false, "Shatterglass Overwound cannot gain shields")


func _test_tolling_bell() -> void:
	_fight({}, _gear("tolling_bell", "intact"), ["gloam", "kestrel"])
	var faded: Dictionary = _sim.submit({"type": "cast", "spell": "fade", "to": _u(0)["pos"], "seat": 0})
	eq(bool(faded.get("ok", false)), true, "Gloam can Fade next to Tolling Bell")
	eq(bool(_u(0).get("invisible", false)), false, "Intact reveals that Fade immediately")
	_u(0)["invisible"] = true
	_sim._still_on_invisible(_u(0))
	eq(bool(_u(0).get("invisible", false)), true, "Intact reveals only the first")
	_fight(_gear("tolling_bell", "overwound"), {}, ["kestrel", "gloam"])
	eq(int(_sim._mitigate_hit(_u(0), _u(1), 10)["damage"]), 9, "Overwound hits deal −10%")
	_end_turns(1)
	var again: Dictionary = _sim.submit({"type": "cast", "spell": "fade", "to": _u(1)["pos"], "seat": 1})
	eq(bool(again.get("ok", false)), true, "the enemy Gloam Fades")
	eq(bool(_u(1).get("invisible", false)), false, "Overwound reveals every Fade")
	_u(1)["invisible"] = true
	_sim._still_on_invisible(_u(1))
	eq(bool(_u(1).get("invisible", false)), false, "Overwound keeps revealing all fight")


func _test_bleeding_hour() -> void:
	_fight(_gear("bleeding_hour", "intact"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 100
	var used: Dictionary = _sim.submit({"type": "use_still", "seat": 0})
	eq(bool(used.get("ok", false)), true, "Bleeding Hour is a use-Still intent")
	eq([int(_u(0)["hp"]), int(_u(0)["ap"])], [80, 8], "Intact: −20% HP, +2 AP, capped at 8")
	eq(bool(_u(0).get("still_ready", true)), false, "once per fight")
	eq(bool(_sim.submit({"type": "use_still", "seat": 0}).get("ok", false)), false, "a second tap is refused")
	_fight(_gear("bleeding_hour", "overwound"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 100
	eq(bool(_sim.submit({"type": "use_still", "seat": 0}).get("ok", false)), true, "Overwound Bleeding Hour resolves")
	eq([int(_u(0)["hp"]), int(_u(0)["ap"])], [70, 9], "Overwound: −30% HP, +3 AP past 8")
	eq(int(_sim._apply_heal(_u(0), 10, _u(0))), 0, "no heals until the next turn ends")
	_end_turns(2)
	eq(int(_sim._apply_heal(_u(0), 10, _u(0))), 0, "the next own turn is still locked")
	_end_turns(2)
	_u(0)["hp"] = 40
	eq(int(_sim._apply_heal(_u(0), 10, _u(0))), 10, "heals return after that turn ends")
	_fight(_gear("bleeding_hour", "intact"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 10
	_sim.submit({"type": "use_still", "seat": 0})
	eq([int(_u(0)["hp"]), bool(_u(0).get("alive", false))], [1, true], "Intact stops at 1 HP")
	eq(int(_u(0)["ap"]), 8, "Intact still grants +2 AP at 1 HP")
	_fight(_gear("bleeding_hour", "overwound"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 1
	_sim.submit({"type": "use_still", "seat": 0})
	eq([int(_u(0)["hp"]), bool(_u(0).get("alive", false))], [1, true], "Overwound already at 1 HP stays there")
	eq(int(_u(0)["ap"]), 9, "Overwound still grants +3 AP at 1 HP")


func _offers_still(seat: int) -> bool:
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "use_still":
			return true
	return false


func _test_still_own_turn() -> void:
	# The wearer is seat 1. Seat 0 is acting, so the button's intent is refused.
	for id in ["bleeding_hour", "mirror_hour"]:
		_fight({}, _gear(id, "intact"))
		var hp := int(_u(1)["hp"])
		var ap := int(_u(1)["ap"])
		var off: Dictionary = _sim.submit({"type": "use_still", "seat": 1, "target_seat": 0})
		eq(bool(off.get("ok", false)), false, "%s is refused off-turn" % id)
		eq(str(off.get("reason", "")), "not_your_turn", "%s off-turn reason is not_your_turn" % id)
		eq([int(_u(1)["hp"]), int(_u(1)["ap"]), bool(_u(1).get("still_ready", false))], [hp, ap, true], "%s is unchanged off-turn" % id)
		eq(_offers_still(1), false, "%s is not offered on the other seat's turn" % id)
		_end_turns(1)
		eq(_offers_still(1), true, "%s is offered on your turn" % id)
		var on: Dictionary = _sim.submit({"type": "use_still", "seat": 1, "target_seat": 0})
		eq(bool(on.get("ok", false)), true, "%s resolves on your turn" % id)
	var spots := [Vector2i(5, 7), Vector2i(8, 7), Vector2i(6, 7), Vector2i(9, 7)]
	_team(_gear("bound_hour", "intact"), ["kestrel", "ironjaw", "bastion", "gloam"], spots)
	var bound_ap := int(_u(0)["ap"])
	_end_turns(1)
	var bound_off: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	eq(bool(bound_off.get("ok", false)), false, "Bound Hour is refused off-turn")
	eq(str(bound_off.get("reason", "")), "not_your_turn", "Bound Hour off-turn reason is not_your_turn")
	eq([int(_u(0)["ap"]), int(_u(0).get("bound_seat", -1)), bool(_u(0).get("still_ready", false))], [bound_ap, -1, true], "Bound Hour is unchanged off-turn")
	eq(_offers_still(0), false, "Bound Hour is not offered on the other seat's turn")
	_end_turns(3)
	eq(int(_sim.snapshot()["active_seat"]), 0, "the wearer's turn comes back around")
	eq(_offers_still(0), true, "Bound Hour is offered on your turn")
	eq(bool(_sim.submit({"type": "use_still", "seat": 0, "target_seat": 2}).get("ok", false)), true, "Bound Hour resolves on your turn")
	# Online: the host stamps the sender's seat, then the sim refuses the wrong turn.
	_fight(_gear("bleeding_hour", "intact"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 100
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.attach_sim(_sim)
	net.enter_host_offline()
	var remote: Dictionary = net.submit_for_seat({"type": "use_still"}, 1)
	eq(bool(remote.get("ok", false)), false, "the server refuses Bleeding Hour off-turn")
	eq(str(remote.get("reason", "")), "not_your_turn", "online off-turn reason is not_your_turn")
	eq([int(_u(0)["hp"]), bool(_u(0).get("still_ready", false))], [100, true], "online off-turn does not spend the Still")
	var accepted: Dictionary = net.submit_for_seat({"type": "use_still"}, 0)
	eq(bool(accepted.get("ok", false)), true, "the server accepts Bleeding Hour on your turn")
	eq(int(_u(0)["hp"]), 80, "online on-turn pays the HP")
	net.free()
	_fight({}, _gear("mirror_hour", "intact"), ["kestrel", "ironjaw"], [], [Vector2i(5, 7), Vector2i(8, 7)])
	var there: Vector2i = _u(1)["pos"]
	net = (load("res://backend/net_session.gd") as Script).new()
	net.attach_sim(_sim)
	net.enter_host_offline()
	var early: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 0}, 1)
	eq(str(early.get("reason", "")), "not_your_turn", "the server refuses Mirror Hour off-turn")
	eq(_u(1)["pos"], there, "online Mirror Hour does not swap off-turn")
	net.submit_for_seat({"type": "end_turn"}, 0)
	var swapped: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 0}, 1)
	eq(bool(swapped.get("ok", false)), true, "the server accepts Mirror Hour on your turn")
	eq(_u(1)["pos"] != there, true, "online Mirror Hour swaps on your turn")
	net.free()


func _test_mirror_hour() -> void:
	var spots := [Vector2i(5, 7), Vector2i(8, 7), Vector2i(6, 7), Vector2i(9, 7)]
	_team(_gear("mirror_hour", "intact"), ["kestrel", "ironjaw", "bastion", "gloam"], spots)
	var before_a: Vector2i = _u(0)["pos"]
	var before_b: Vector2i = _u(2)["pos"]
	var swapped: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	eq(bool(swapped.get("ok", false)), true, "Mirror Hour swaps with an ally")
	eq(_u(0)["pos"], before_b, "you stand where the ally stood")
	eq(_u(2)["pos"], before_a, "the ally stands where you stood")
	eq(int(_u(0)["ap"]), 4, "Intact costs 2 AP")
	_team(_gear("mirror_hour", "overwound"), ["kestrel", "ironjaw", "bastion", "gloam"], spots)
	var foe_before: Vector2i = _u(1)["pos"]
	eq(bool(_sim.submit({"type": "use_still", "seat": 0, "target_seat": 1}).get("ok", false)), true, "Overwound can swap an enemy")
	eq(int(_u(0)["ap"]), 6, "Overwound costs 0 AP")
	eq(int(_u(0)["mp"]), 0, "Overwound spends the remaining MP")
	eq(_u(0)["pos"], foe_before, "you stand on the enemy's tile")
	var toward := str(_sim.facing_toward(_u(1)["pos"], _u(0)["pos"], "S"))
	eq(str(_u(1)["facing"]) != toward, true, "the enemy ends facing away from you")
	_u(1)["invisible"] = true
	_team(_gear("mirror_hour", "intact"), ["kestrel", "ironjaw", "bastion", "gloam"], spots)
	_u(1)["invisible"] = true
	eq(bool(_sim.submit({"type": "use_still", "seat": 0, "target_seat": 1}).get("ok", false)), false, "an Invisible fighter is not a Mirror target")


func _test_held_hour() -> void:
	_fight(_gear("held_hour", "intact"))
	_u(1)["hp"] = 90
	eq(int(_sim._mitigate_hit(_u(0), _u(1), 10)["damage"]), 10, "Intact still deals the hit now")
	eq(int(_u(1).get("held_echo", 0)), 5, "half of it is waiting")
	_sim._mitigate_hit(_u(0), _u(1), 10)
	eq(int(_u(1).get("held_echo", 0)), 5, "only the first hit echoes")
	_end_turns(1)
	eq(int(_u(1)["hp"]), 85, "the echo hits for half at the target's next turn")
	_fight(_gear("held_hour", "overwound"))
	_u(1)["hp"] = 90
	eq(int(_sim._mitigate_hit(_u(0), _u(1), 10)["damage"]), 0, "Overwound deals 0 now")
	eq(int(_u(1).get("shield", 0)), 0, "and it does not touch a shield it never had")
	eq(int(_u(1).get("held_echo", 0)), 20, "double waits on the target")
	_sim._mitigate_hit(_u(1), _u(0), 8)
	eq(int(_u(1).get("held_echo", 0)), 0, "the echo is lost if they hit you first")
	_end_turns(1)
	eq(int(_u(1)["hp"]), 90, "nothing lands on their turn")


func _test_bound_hour() -> void:
	var spots := [Vector2i(5, 7), Vector2i(8, 7), Vector2i(6, 7), Vector2i(9, 7)]
	_team(_gear("bound_hour", "intact"), ["kestrel", "ironjaw", "bastion", "gloam"], spots)
	var bound: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	eq(bool(bound.get("ok", false)), true, "Bound Hour binds an ally")
	eq(int(_u(0)["ap"]), 4, "Bound Hour costs 2 AP")
	eq(str(_u(0).get("bound_name", "")), str(_u(2).get("name", "")), "the card can name the ally")
	var wearer_hp := int(_u(0)["hp"])
	var ally_hp := int(_u(2)["hp"])
	_sim._lose_hp(_u(2), 10)
	eq(int(_u(2)["hp"]), ally_hp - 5, "the ally takes half")
	eq(int(_u(0)["hp"]), wearer_hp - 5, "you take the other half")
	_team(_gear("bound_hour", "overwound"), ["kestrel", "ironjaw", "bastion", "gloam"], spots)
	_sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	wearer_hp = int(_u(0)["hp"])
	ally_hp = int(_u(2)["hp"])
	_sim._lose_hp(_u(2), 10)
	eq(int(_u(0)["hp"]), wearer_hp - 6, "Overwound you take 60%")
	eq(int(_u(2)["hp"]), ally_hp - 4, "the ally takes the rest")
	_u(0)["pos"] = Vector2i(1, 1)
	_u(2)["pos"] = Vector2i(12, 12)
	_end_turns(1)
	eq(int(_u(0).get("bound_seat", -1)), -1, "ending a turn more than 4 tiles apart breaks the bind")
	eq(int(_u(0).get("bound_ap_pen", 0)), 1, "you lose 1 AP next turn")
	eq(int(_u(2).get("bound_ap_pen", 0)), 1, "so does the ally")


func _test_gathered_sand() -> void:
	truthy(StillVault.plain("gathered_sand", "intact").contains("reflects 10%"), "inventory text says 10%")
	truthy(StillVault.plain("gathered_sand", "overwound").contains("reflects 20%"), "inventory text says 20%")
	truthy(StillVault.plain("gathered_sand", "overwound").contains("cannot be healed"), "Overwound names the heal lock")
	eq(StillVault.plain("gathered_sand", "intact").contains("stored"), false, "the store sentence is gone")
	_fight(_gear("gathered_sand", "intact"))
	var foe_hp := int(_u(1)["hp"])
	_sim._lose_hp(_u(0), 40)
	eq(int(_u(1)["hp"]), foe_hp, "plain HP loss does not reflect")
	eq(_u(0).has("sand_stored"), false, "nothing is stored")
	_u(0)["burn_stacks"] = 2
	_u(0)["burn_remaining"] = 3
	_sim._tick_burn(_u(0))
	eq(int(_u(1)["hp"]), foe_hp, "a burn tick does not reflect")
	_sim._apply_lava_land(_u(0), 1)
	eq(int(_u(1)["hp"]), foe_hp, "lava does not reflect")
	_u(0)["hp"] = 40
	eq(int(_sim._apply_heal(_u(0), 12, _u(0))), 12, "Intact can still be healed")
	eq(int(_sim._mitigate_hit(_u(0), _u(1), 10)["damage"]), 10, "the next hit does not release a store")
	var first := _enemy_strike()
	var hit: Dictionary = first["hit"]
	var sand: Dictionary = first["sand"]
	var basis := int(hit.get("damage", 0)) + int(hit.get("shield_absorbed", 0))
	var expect := mini(12, roundi(float(basis) * 0.1))
	eq(expect > 0, true, "the strike is big enough to reflect")
	eq(int(sand.get("damage", 0)), expect, "Intact reflects 10% of the hit")
	eq(int(_u(1)["hp"]), int(first["foe_hp"]) - expect, "the attacker loses that much")
	var log: Script = load("res://ui/battle_log.gd")
	var snap: Dictionary = _sim.snapshot()
	var mine := snap.duplicate(true)
	mine["local_seat"] = 0
	var theirs := snap.duplicate(true)
	theirs["local_seat"] = 1
	var line := str(log.plain(sand, mine))
	eq(line, str(log.plain(sand, theirs)), "both phones show the same reflect line")
	eq(line, "Gathered Sand: Kestrel reflects %d to Ironjaw." % expect, "log line: %s" % line)
	eq(line.contains("("), false, "the reflect line has no tile")
	var again := _enemy_strike()
	eq(int(again["sand"].get("damage", 0)), mini(12, roundi(float(int(again["hit"].get("damage", 0)) + int(again["hit"].get("shield_absorbed", 0))) * 0.1)), "a later hit reflects too")
	var capped_hp := int(_u(1)["hp"])
	_sim._reflect_gathered_sand(_u(1), _u(0), {"thorns_basis": 200})
	eq(int(_u(1)["hp"]), capped_hp - 12, "the reflect caps at 12")
	var quiet := int(_u(1)["hp"])
	var before_events := int(_sim._last_events.size())
	_sim._reflect_gathered_sand(_u(1), _u(0), {"thorns_basis": 4})
	eq(int(_u(1)["hp"]), quiet, "10% of 4 rounds to 0 and does not reflect")
	eq(_sim._last_events.size(), before_events, "a zero reflect writes no log line")
	_fight(_gear("gathered_sand", "intact"), {}, ["kestrel", "gloam"], [1])
	_u(0)["shield"] = 80
	_u(0)["shield_turns"] = 2
	var wearer_hp := int(_u(0)["hp"])
	var shielded := _enemy_strike("cut")
	eq(int(_u(0)["hp"]), wearer_hp, "the shield takes the hit")
	eq(int(shielded["hit"].get("damage", 0)), 0, "no HP gets through the shield")
	eq(int(shielded["sand"].get("damage", 0)) > 0, true, "a shielded hit still reflects")
	_fight(_gear("gathered_sand", "overwound"))
	_u(0)["hp"] = 40
	eq(int(_sim._apply_heal(_u(0), 12, _u(0))), 0, "Overwound blocks heals all fight")
	eq(int(_sim._apply_heal(_u(0), 12, _u(1))), 0, "an enemy heal is blocked too")
	var heavy := _enemy_strike()
	var heavy_basis := int(heavy["hit"].get("damage", 0)) + int(heavy["hit"].get("shield_absorbed", 0))
	eq(int(heavy["sand"].get("damage", 0)), mini(12, roundi(float(heavy_basis) * 0.2)), "Overwound reflects 20%")
	_fight(_gear("gathered_sand", "intact"), {}, ["bastion", "ironjaw"], [1])
	var stacked := _enemy_strike()
	var stack_basis := int(stacked["hit"].get("damage", 0)) + int(stacked["hit"].get("shield_absorbed", 0))
	eq(int(stacked["hit"].get("thorns", 0)), maxi(1, roundi(float(stack_basis) * _sim.THORNS_REFLECT)), "Thorns still takes its 20%")
	eq(int(stacked["sand"].get("damage", 0)), mini(12, roundi(float(stack_basis) * 0.1)), "Gathered Sand adds its own 10%")
	eq(int(_u(1)["hp"]), int(stacked["foe_hp"]) - int(stacked["hit"]["thorns"]) - int(stacked["sand"]["damage"]), "both come off the attacker")
	_fight(_gear("gathered_sand", "intact"), {}, ["ironjaw", "kestrel"], [1], [Vector2i(2, 7), Vector2i(6, 7)])
	_sim._active_seat = 1
	_u(1)["ap"] = 6
	var far_hp := int(_u(1)["hp"])
	var far: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "seat": 1, "to": _u(0)["pos"]})
	eq(bool(far.get("ok", false)), true, "a ranged hit resolves")
	var far_sand := _sand_event(far.get("events", []))
	eq(int(far_sand.get("damage", 0)) > 0, true, "a ranged hit reflects")
	eq(int(_u(1)["hp"]), far_hp - int(far_sand["damage"]), "the ranged attacker takes the reflect")
	eq(int(_hit_event(far.get("events", [])).get("thorns", 0)), 0, "Thorns does not reach that shot")
	_fight(_gear("gathered_sand", "intact"), _gear("gathered_sand", "intact"))
	var once := _enemy_strike()
	eq(_sand_count(once["events"]), 1, "the reflect does not bounce back")
	_fight(_gear("gathered_sand", "intact"))
	_sim._trap_tiles.append({"pos": _u(0)["pos"], "owner_seat": 1, "turns": 3})
	var trap_hp := int(_u(1)["hp"])
	eq(_sim._trigger_trap(_u(0)), true, "the snare springs")
	eq(int(_u(1)["hp"]), trap_hp - mini(12, roundi(6.0 * 0.1)), "a sprung trap reflects")
	_fight(_gear("gathered_sand", "intact"))
	_u(0)["hp"] = 1
	var killer := int(_u(1)["hp"])
	var trade := _enemy_strike()
	eq(bool(_u(0).get("alive", true)), false, "the hit kills the wearer")
	eq(int(_u(1)["hp"]), killer, "a killing blow does not reflect")
	eq(trade["sand"].is_empty(), true, "a killing blow writes no Gathered Sand line")


func _enemy_strike(spell: String = "strike") -> Dictionary:
	_sim._active_seat = 1
	_u(1)["ap"] = 6
	var foe_hp := int(_u(1)["hp"])
	var result: Dictionary = _sim.submit({"type": "cast", "spell": spell, "seat": 1, "to": _u(0)["pos"]})
	eq(bool(result.get("ok", false)), true, "the enemy strike resolves")
	return {
		"events": result.get("events", []),
		"hit": _hit_event(result.get("events", [])),
		"sand": _sand_event(result.get("events", [])),
		"foe_hp": foe_hp,
	}


func _hit_event(events: Array) -> Dictionary:
	for raw in events:
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("type", "")) == "hit":
			return raw
	return {}


func _gained_mp(events: Array) -> int:
	var total := 0
	for raw in events:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("type", "")) == "still" and str(raw.get("still", "")) == "long_shadow":
			total += int(raw.get("mp_gained", 0))
	return total


func _float_says_mp(hit: Dictionary) -> bool:
	var router = load("res://vfx/vfx_router.gd")
	for spec in router.recipes_for([hit]):
		if typeof(spec) == TYPE_DICTIONARY and str(spec.get("text", "")) == "+2 MP":
			return true
	return false


func _sand_event(events: Array) -> Dictionary:
	for raw in events:
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("type", "")) == "still" and str(raw.get("still", "")) == "gathered_sand":
			return raw
	return {}


func _sand_count(events: Array) -> int:
	var n := 0
	for raw in events:
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("type", "")) == "still" and str(raw.get("still", "")) == "gathered_sand":
			n += 1
	return n


func _test_carry_and_online() -> void:
	var v := StillVault.new()
	v.socket = "mirror_hour"
	v.mode = "overwound"
	v.save()
	eq(GearBag.load_saved().fight_gear(true)["still"], {"id": "mirror_hour", "mode": "overwound"}, "fight gear carries the socketed Still")
	eq(GearBag.load_saved().fight_gear().has("still"), false, "plain fight gear has no Still")
	eq(GearBag.clean_fight_gear({"still": {"id": "bound_hour", "mode": "intact"}})["still"], {"id": "bound_hour", "mode": "intact"}, "the host keeps a clean new Still")
	eq(GearBag.clean_fight_gear({"still": {"id": "stride", "mode": "intact"}}).has("still"), false, "the host drops an old id")
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "kestrel"
	eq(StasisCatalog.fight_config()["stasis_roster"][0]["gear"]["still"]["id"], "mirror_hour", "Stasis fight carries the Still")
	StasisCatalog.clear_run()
	v.set_focus("ironjaw")
	v.socket = "tide"
	v.mode = "intact"
	v.set_focus("kestrel")
	v.save()
	eq(GearBag.load_saved().fight_gear(true, "ironjaw")["still"], {"id": "tide", "mode": "intact"}, "Ironjaw's fight gear is his Still")
	eq(GearBag.load_saved().fight_gear(true, "kestrel")["still"]["id"], "mirror_hour", "Kestrel's fight gear stays Mirror Hour")
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.set_party(["kestrel", "ironjaw"], [1])
	var party: Dictionary = StasisCatalog.fight_config()
	var party_roster: Array = party.get("stasis_roster", [])
	eq(party_roster.size() >= 2, true, "a party fight has both heroes")
	eq(party_roster[0]["gear"]["still"]["id"], "mirror_hour", "seat 0 uses Kestrel's socket")
	eq(party_roster[1]["gear"]["still"]["id"], "tide", "seat 1 uses Ironjaw's socket")
	StasisCatalog.clear_run()
	StasisCatalog.clear_run_party()
	var cs: Script = load("res://scenes/class_select.gd")
	var kit_on: bool = load("res://backend/test_loadout.gd").ACTIVE
	eq(cs.local_match_config().has("seat_gear"), kit_on, "hot-seat gear only while the temporary test kit is on")
	if kit_on:
		var local_gear: Dictionary = cs.local_match_config()["seat_gear"]
		eq(bool(local_gear[0].get("flatten_plus", false)), true, "a test-kit local fight counts an Ultra 5pc")
	_wipe()
	v = StillVault.new()
	v.socket = "tide"
	v.save()
	var fight: Script = load("res://scenes/stasis_fight.gd")
	eq(fight.consume_still({"units": [{"seat": 0, "still": "tide"}]}), "tide", "the Stasis fight that used Tide destroys it")
	_wipe()
	v = StillVault.new()
	v.set_focus("kestrel")
	v.socket = "mirror_hour"
	v.set_focus("ironjaw")
	v.socket = "tide"
	v.save()
	eq(fight.consume_still({"units": [
		{"seat": 0, "team": 0, "class_id": "kestrel", "still": "mirror_hour"},
		{"seat": 1, "team": 0, "class_id": "ironjaw", "still": "tide"},
		{"seat": 2, "team": 1, "class_id": "gloam", "still": "bound_hour"},
	]}), "mirror_hour", "a party fight breaks each hero's Still")
	var after_party := StillVault.load_saved()
	eq(after_party.socket_of("kestrel"), "", "Kestrel's socket broke")
	eq(after_party.socket_of("ironjaw"), "", "Ironjaw's socket broke")
	_wipe()
	v = StillVault.new()
	v.set_focus("ironjaw")
	v.socket = "mirror_hour"
	v.set_focus("kestrel")
	v.socket = "tide"
	v.save()
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.mode = net.Mode.CLIENT
	net.local_seat = 0
	net._note_koliseo_result({"match_over": true, "winner_seat": 0, "units": [{"seat": 0, "class_id": "kestrel", "still": "tide"}, {"seat": 1, "class_id": "gloam"}]})
	eq(int(net.koliseo_last_payout["trophies"]), 1, "a win pays the normal trophy, with no Crown bonus")
	eq(StillVault.load_saved().socket_of("kestrel"), "", "the Koliseo fight consumed Kestrel's Still")
	eq(StillVault.load_saved().socket_of("ironjaw"), "mirror_hour", "Ironjaw's Still stays socketed")
	net.free()
	_fight(_gear("bleeding_hour", "intact"))
	_u(0)["max_hp"] = 100
	_u(0)["hp"] = 100
	var synced: Dictionary = _sim.submit({"type": "use_still", "seat": 0})
	var snap: Dictionary = synced.get("snapshot", {})
	var units: Array = snap.get("units", [])
	eq(bool(units[0].get("still_ready", true)), false, "the snapshot the other client reads has spent the Still")
	eq(int(units[0].get("hp", 0)), 80, "the snapshot carries the HP the Still spent")
	var offered: Array = _sim.legal_intents(0)
	var saw := false
	for intent in offered:
		if str(intent.get("type", "")) == "use_still":
			saw = true
	eq(saw, false, "a spent Still is not offered again")
	_fight(_gear("mirror_hour", "intact"), {}, ["kestrel", "ironjaw"], [], [Vector2i(5, 7), Vector2i(8, 7)])
	saw = false
	for intent in _sim.legal_intents(0):
		if str(intent.get("type", "")) == "use_still" and int(intent.get("target_seat", -1)) == 1:
			saw = true
	eq(saw, true, "Mirror Hour offers the enemy as a target")


func _test_clear_text_and_icons() -> void:
	for id in StillVault.IDS:
		for mode in StillVault.MODES:
			var line := StillVault.plain(id, mode)
			eq(line.length() > 12, true, "%s %s has a plain sentence" % [id, mode])
			eq(line.contains("\n"), false, "%s %s is one line" % [id, mode])
		eq(bool(StillVault.EFFECTS[id]["built"]), true, "%s is built" % id)
		for frag in [false, true]:
			var tex := StillVault.icon(id, frag)
			eq(tex != null, true, "%s %s icon is in the game" % [id, "fragment" if frag else "forged"])
			if tex != null:
				eq(tex.get_size(), Vector2(128, 128), "%s icon is 128x128" % id)
	eq(StillVault.HOW_TO.size(), 4, "how Stills work is four steps")
	eq(StillVault.HOW_TO[2].contains("drawback"), true, "Overwound is stronger, with a drawback")
	eq(StillVault.forge_summary(7), "5 more to forge one.", "short of 12 says how many more")
	eq(StillVault.forge_summary(100), "Ready to forge (enough fragments for 8).", "100 fragments reads as ready, not 100/12")
	var v := StillVault.new()
	v.fragments = {"gathered_sand": 100}
	v.socket = "steadfast"
	v.save()
	var screen: StillsScreen = load("res://scenes/stills_screen.gd").new()
	root.add_child(screen)
	screen.pick("gathered_sand")
	var why := screen.find_child("ForgeWhy", true, false) as Label
	eq(why != null and why.text.contains("already holds Steadfast"), true, "a full socket explains why Forge is off")
	screen.free()


func _test_screen() -> void:
	_wipe()
	var v := StillVault.new()
	v.fragments = {"tide": 12, "hourglass_fist": 3}
	v.save()
	var screen: StillsScreen = load("res://scenes/stills_screen.gd").new()
	root.add_child(screen)
	var tiles := 0
	for id in StillVault.IDS:
		if screen.find_child("Still_" + id, true, false) != null:
			tiles += 1
	eq(tiles, 14, "fourteen Still tiles")
	screen.pick("hourglass_fist")
	eq((screen.find_child("Forge", true, false) as Button).disabled, true, "3/12: Forge off")
	screen.pick("tide")
	eq((screen.find_child("Forge", true, false) as Button).disabled, false, "12/12: Forge on")
	eq(bool(screen.forge()["ok"]), true, "forge from the screen")
	eq(StillVault.load_saved().socket, "tide", "screen saves the socket")
	truthy(screen.find_child("Mode_overwound", true, false) != null, "Overwind choice appears")
	screen.choose_mode("overwound")
	eq(StillVault.load_saved().mode, "overwound", "mode saved")
	screen.free()
	var gear: GearScreen = load("res://scenes/gear_screen.gd").new()
	root.add_child(gear)
	truthy(gear.find_child("OpenStills", true, false) != null, "Gear screen has a Stills button")
	truthy(gear.open_stills() != null, "Stills opens from Gear")
	gear.free()


func _test_card_lines() -> void:
	var hud := CombatHUD.new()
	root.add_child(hud)
	var sand := {
		"hp": 40, "max_hp": 75, "ap": 6, "mp": 3, "alive": true, "class_id": "kestrel",
		"still": "gathered_sand", "still_mode": "intact", "sand_stored": 9, "name": "Kestrel",
	}
	eq(hud._unit_card_text(sand, true).contains("Gathered Sand 9/15"), false, "the corner card no longer meters stored sand")
	var bound := {
		"hp": 75, "max_hp": 75, "ap": 4, "mp": 3, "alive": true, "class_id": "kestrel", "seat": 0,
		"still": "bound_hour", "still_mode": "intact", "bound_seat": 2, "bound_name": "Bastion", "name": "Kestrel",
	}
	eq(hud._unit_card_text(bound, true).contains("Bound to Bastion"), true, "the corner card names the bind")
	var watching := {
		"phase": "COMBAT",
		"local_seat": 1,
		"active_seat": 0,
		"match_over": false,
		"units": [bound, {"hp": 90, "max_hp": 90, "ap": 6, "mp": 3, "alive": true, "class_id": "ironjaw", "seat": 1, "name": "Ironjaw"}],
	}
	hud.render(watching, [{"type": "use_still", "seat": 0}])
	eq(hud._use_still_button.visible, false, "Use Still is hidden on the opponent's turn")
	eq(hud._use_still_button.disabled, true, "Use Still is disabled on the opponent's turn")
	watching["local_seat"] = 0
	hud.render(watching, [{"type": "use_still", "seat": 0}])
	eq(hud._use_still_button.visible, true, "Use Still shows on your turn")
	eq(hud._use_still_button.disabled, false, "Use Still is enabled on your turn")
	var bare := {
		"hp": 90, "max_hp": 90, "ap": 6, "mp": 3, "alive": true, "class_id": "ironjaw",
		"seat": 1, "name": "Ironjaw", "held_echo": 12, "bound_name": "Kestrel", "bound_seat": 0,
	}
	var fight := {
		"phase": "COMBAT",
		"local_seat": 0,
		"active_seat": 0,
		"match_over": false,
		"units": [bound, bare],
	}
	hud.render(fight, [{"type": "use_still", "seat": 0}])
	var owner := hud._seat_panels[0].get_node_or_null("StillIcon") as TextureRect
	var other := hud._seat_panels[1].get_node_or_null("StillIcon") as TextureRect
	eq(owner != null and owner.visible, true, "the socketed fighter shows a Still icon")
	eq(owner.texture, StillVault.icon("bound_hour"), "that icon is their own Still, not a fragment")
	eq(other != null and other.visible, false, "a fighter without a Still shows no icon")
	eq(hud._unit_card_text(bare, false).contains("Echo"), false, "another player's Still leaves no state line")
	eq(hud._unit_card_text(bare, false).contains("Bound"), false, "a stray bind name is not a Still on this fighter")
	var bound_icon := hud._use_still_button.get_node_or_null("StillButtonIcon") as TextureRect
	eq(bound_icon != null and bound_icon.texture == StillVault.icon("bound_hour"), true, "the round button shows Bound Hour")
	eq(hud._use_still_button.text, "", "the Still button has no Use Still label")
	eq(hud._use_still_button.icon, null, "the Still icon is the round button, not a side icon")
	fight["local_seat"] = 1
	hud.render(fight, [{"type": "use_still", "seat": 0}])
	eq(hud._use_still_button.visible, false, "the other fighter does not get Use Still")
	eq((hud._use_still_button.get_node_or_null("StillButtonIcon") as TextureRect).texture, null, "their button does not keep the first fighter's icon")
	eq((hud._seat_panels[0].get_node_or_null("StillIcon") as TextureRect).texture, StillVault.icon("bound_hour"), "the owner's card still shows only their Still")
	eq((hud._seat_panels[1].get_node_or_null("StillIcon") as TextureRect).visible, false, "the other card stays blank")
	bare["still"] = "tide"
	bare["still_mode"] = "intact"
	fight["local_seat"] = 0
	fight["active_seat"] = 0
	hud.render(fight, [{"type": "use_still", "seat": 0}])
	var left := hud._seat_panels[0].get_node_or_null("StillIcon") as TextureRect
	var right := hud._seat_panels[1].get_node_or_null("StillIcon") as TextureRect
	eq(left.texture, StillVault.icon("bound_hour"), "the left card keeps Bound Hour")
	eq(right.visible and right.texture == StillVault.icon("tide"), true, "the other fighter shows only Tide")
	eq(left.texture == right.texture, false, "the two cards do not share one Still")
	hud.queue_free()


func _until_seat(seat: int) -> void:
	var guard := 0
	while int(_sim.snapshot().get("active_seat", -1)) != seat and guard < 6:
		_sim.submit({"type": "end_turn", "seat": int(_sim.snapshot()["active_seat"])})
		guard += 1


func _test_still_action_button() -> void:
	var hud := CombatHUD.new()
	root.add_child(hud)
	var kids: Array = hud._action_bar.get_children()
	eq(kids.find(hud._use_still_button), kids.find(hud._end_turn_button) + 1, "the Still button sits beside Pass Turn")
	eq(hud._use_still_button.custom_minimum_size, Vector2(72, 72), "the Still button is the same size as the round neighbors")
	var box := hud._use_still_button.get_theme_stylebox("normal") as StyleBoxFlat
	eq(box != null and box.corner_radius_top_left == 36, true, "the Still button is a circle")
	_fight(_gear("tide", "intact"))
	_until_seat(0)
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud._use_still_button.visible, false, "a passive Still has no button")
	eq((hud._seat_panels[0].get_node_or_null("StillIcon") as TextureRect).visible, true, "Tide stays on the corner card")
	_fight(_gear("mirror_hour", "intact"))
	_until_seat(0)
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud._use_still_button.visible, true, "Mirror Hour shows on your turn")
	var mark := hud._use_still_button.get_node_or_null("StillButtonIcon") as TextureRect
	eq(mark != null and mark.texture == StillVault.icon("mirror_hour"), true, "the button icon is Mirror Hour")
	hud._use_still_button.pressed.emit()
	eq(hud.still_aiming(), true, "Mirror Hour then asks for a fighter")
	eq(hud._selected_label.text.contains("tap a fighter"), true, "the hint says to tap a fighter")
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.attach_sim(_sim)
	net.enter_host_offline()
	var off: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 1}, 1)
	eq(str(off.get("reason", "")), "not_your_turn", "online Mirror Hour is refused off-turn")
	eq(bool(_u(0).get("still_ready", false)), true, "the off-turn tap does not spend it")
	var watching: Dictionary = _sim.snapshot()
	watching["local_seat"] = 1
	hud.render(watching, _sim.legal_intents(0))
	eq(hud._use_still_button.visible, false, "online, the other fighter does not see the button")
	var used: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 1}, 0)
	eq(bool(used.get("ok", false)), true, "online Mirror Hour resolves on your turn")
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud._use_still_button.visible, false, "the button disappears after the Still is used")
	eq((hud._seat_panels[0].get_node_or_null("StillIcon") as TextureRect).visible, true, "the corner icon stays after the button is gone")
	_end_turns(2)
	_until_seat(0)
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud._use_still_button.visible, false, "it stays gone for the rest of the match")
	net.free()
	hud.queue_free()


## Bound and Mirror use the same Chebyshev count as every other range
## (4 is legal, 5 is not). A diagonal of 4 is not Manhattan 8.
## The bar text is the short coach, local and on the host sim.
func _test_still_target_rules() -> void:
	eq(SIM_SCRIPT.chebyshev(Vector2i(0, 0), Vector2i(4, 4)), 4, "a diagonal of 4 tiles is Chebyshev 4")
	eq(SIM_SCRIPT.chebyshev(Vector2i(7, 9), Vector2i(7, 5)), 4, "four steps on one axis is 4")
	eq(SIM_SCRIPT.chebyshev(Vector2i(7, 9), Vector2i(7, 3)), 6, "six steps on one axis is 6")
	var spots := [
		Vector2i(5, 5), Vector2i(9, 5), Vector2i(9, 9), Vector2i(1, 1), Vector2i(5, 10), Vector2i(12, 12),
	]
	_sim.reset_match({
		"team_size": 3,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "ironjaw", "mender", "gloam", "kestrel", "kestrel"],
		"positions": spots,
		"seat_gear": {0: _gear("bound_hour", "intact")},
	})
	eq(str(_u(2).get("name", "")), "Mender", "the ally's name is Mender")
	eq(SIM_SCRIPT.chebyshev(_u(0)["pos"], _u(2)["pos"]), 4, "Mender stands 4 tiles away")
	var offered := false
	var enemy_offered := false
	var far_offered := false
	for intent in _sim.legal_intents(0):
		if str(intent.get("type", "")) != "use_still":
			continue
		var who := int(intent.get("target_seat", -1))
		if who == 2:
			offered = true
		if who == 1:
			enemy_offered = true
		if who == 4:
			far_offered = true
	eq(offered, true, "Bound Hour offers the ally at 4 tiles")
	eq(enemy_offered, false, "Bound Hour does not offer an enemy")
	eq(far_offered, false, "Bound Hour does not offer an ally at 5 tiles")
	var diagonal: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	eq(bool(diagonal.get("ok", false)), true, "Chebyshev 4, including a diagonal, binds")
	eq(str(_u(0).get("bound_name", "")), "Mender", "the bind names Mender")
	_sim.reset_match({
		"team_size": 3,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "ironjaw", "mender", "gloam", "kestrel", "kestrel"],
		"positions": spots,
		"seat_gear": {0: _gear("bound_hour", "intact")},
	})
	var enemy: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 1})
	eq(bool(enemy.get("ok", false)), false, "an enemy is not a Bound Hour target")
	eq(str(enemy.get("reason", "")), "not_ally", "the reason is not an ally")
	eq(CombatHUD.coach_hint(str(enemy.get("snapshot", {}).get("coach", ""))), "not an ally", "the bar says not an ally")
	eq(bool(_u(0).get("still_ready", false)), true, "a refused bind does not spend the Still")
	var far: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 4})
	eq(str(far.get("reason", "")), "out_of_range", "5 tiles is out of range")
	eq(CombatHUD.coach_hint(str(far.get("snapshot", {}).get("coach", ""))), "too far", "the bar says too far")
	eq(str(far.get("snapshot", {}).get("coach", "")).contains("illegal"), false, "a far ally is not an illegal move")
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.attach_sim(_sim)
	net.enter_host_offline()
	var online_far: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 4}, 0)
	eq(str(online_far.get("reason", "")), "out_of_range", "the server says 5 tiles is too far")
	eq(CombatHUD.coach_hint(str(online_far.get("snapshot", {}).get("coach", ""))), "too far", "the server coach is too far")
	var online_enemy: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 1}, 0)
	eq(str(online_enemy.get("reason", "")), "not_ally", "the server refuses an enemy bind")
	eq(CombatHUD.coach_hint(str(online_enemy.get("snapshot", {}).get("coach", ""))), "not an ally", "the server coach is not an ally")
	var online_ok: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 2}, 0)
	eq(bool(online_ok.get("ok", false)), true, "the server binds an ally at 4 tiles")
	eq(str(_u(0).get("bound_name", "")), "Mender", "the server bind names Mender")
	net.free()
	var mirror_spots := [Vector2i(5, 5), Vector2i(9, 9), Vector2i(6, 5), Vector2i(5, 11)]
	_sim.reset_match({
		"team_size": 2,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw", "bastion", "gloam"],
		"positions": mirror_spots,
		"seat_gear": {0: _gear("mirror_hour", "intact")},
	})
	eq(SIM_SCRIPT.chebyshev(_u(0)["pos"], _u(1)["pos"]), 4, "the Mirror foe is 4 tiles away")
	_u(1)["invisible"] = true
	var unseen: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 1})
	eq(str(unseen.get("reason", "")), "invisible", "Mirror Hour refuses an invisible fighter")
	eq(CombatHUD.coach_hint(str(unseen.get("snapshot", {}).get("coach", ""))), "not visible", "the bar says not visible")
	var mirror_far: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 3})
	eq(str(mirror_far.get("reason", "")), "out_of_range", "Mirror Hour uses the same 4-tile range")
	eq(CombatHUD.coach_hint(str(mirror_far.get("snapshot", {}).get("coach", ""))), "too far", "a far Mirror target says too far")
	var mirror_ok: Dictionary = _sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	eq(bool(mirror_ok.get("ok", false)), true, "Mirror Hour swaps with a visible fighter inside 4")
	net = (load("res://backend/net_session.gd") as Script).new()
	net.attach_sim(_sim)
	net.enter_host_offline()
	_sim.reset_match({
		"team_size": 2,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw", "bastion", "gloam"],
		"positions": mirror_spots,
		"seat_gear": {0: _gear("mirror_hour", "intact")},
	})
	_u(1)["invisible"] = true
	var online_hidden: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 1}, 0)
	eq(str(online_hidden.get("reason", "")), "invisible", "the server refuses an invisible Mirror target")
	eq(CombatHUD.coach_hint(str(online_hidden.get("snapshot", {}).get("coach", ""))), "not visible", "the server coach is not visible")
	var online_mirror: Dictionary = net.submit_for_seat({"type": "use_still", "target_seat": 2}, 0)
	eq(bool(online_mirror.get("ok", false)), true, "the server swaps with a visible fighter inside 4")
	net.free()


## On the board: the Still pick highlights allies, hides walk cells, and a
## tap on the fighter (cell or sprite) binds. An empty cell does not walk.
func _test_still_target_board() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	var board: Node = main.get_node("BoardView")
	var guard := 0
	while not bool(board.get("_booted")) and guard < 180:
		await process_frame
		guard += 1
	truthy(bool(board.get("_booted")), "the board is up for a Still target pick")
	if not bool(board.get("_booted")):
		main.free()
		return
	var bastion := Vector2i(6, 8)
	var mender := Vector2i(6, 4)
	var ally := Vector2i(8, 7)
	var enemy := Vector2i(10, 8)
	var empty := Vector2i(7, 8)
	_sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"team_size": 3,
		"skip_deploy": true,
		"classes": ["bastion", "ironjaw", "mender", "gloam", "kestrel", "kestrel"],
		"positions": [bastion, enemy, mender, Vector2i(2, 2), ally, Vector2i(12, 12)],
		"seat_gear": {0: _gear("bound_hour", "intact")},
	})
	board._rebuild_pawns()
	board._refresh()
	var hud: CombatHUD = board._hud
	eq(hud._use_still_button.visible, true, "Bound Hour shows its button")
	var walk_before := (board.tiles[empty] as BoardTile).highlight
	eq(walk_before, "move", "the empty neighbor is a walk cell before the pick")
	hud._use_still_button.pressed.emit()
	eq(hud.still_aiming(), true, "the button arms the target pick")
	eq(hud._selected_label.text.contains("tap a fighter"), true, "the bar asks for a fighter")
	eq(hud._coach_label.text.contains("illegal"), false, "arming the pick clears a stale illegal-move line")
	eq((board.tiles[mender] as BoardTile).highlight, "target", "Mender's cell is a highlighted target")
	eq((board.tiles[ally] as BoardTile).highlight, "target", "the other ally inside 4 is highlighted")
	eq((board.tiles[enemy] as BoardTile).highlight == "target", false, "an enemy inside 4 is not a Bound target")
	eq((board.tiles[empty] as BoardTile).highlight == "move", false, "walk cells hide while picking a Still target")
	var tile_pos: Vector2 = (board.tiles[mender] as BoardTile).position
	eq(board._pick_local(tile_pos, true), mender, "a tap on Mender's cell selects her")
	var pawn: Pawn = board.pawns_by_seat[2]
	eq(board._pick_local(pawn.position + Vector2(0, -70), true), mender, "a tap on Mender's sprite selects her")
	var stood: Vector2i = _u(0)["pos"]
	board._handle_left_click(empty)
	eq(_u(0)["pos"], stood, "an empty cell does not walk during the pick")
	eq(str(_sim.snapshot().get("coach", "")).contains("illegal"), false, "an empty cell is not an illegal move")
	eq(hud.still_aiming(), true, "the pick stays up after an empty tap")
	board._handle_left_click(enemy)
	eq(CombatHUD.coach_hint(hud._coach_label.text), "not an ally", "tapping the enemy says not an ally")
	eq(hud.still_aiming(), true, "a bad target leaves the pick up")
	eq(int(_u(0).get("bound_seat", -1)) < 0, true, "the enemy tap does not bind")
	eq(hud.cancel_spell_selection(), true, "Back cancels the pick")
	eq(hud.still_aiming(), false, "cancel leaves the Still unarmed")
	eq((board.tiles[empty] as BoardTile).highlight, "move", "walk cells come back after cancel")
	hud._use_still_button.pressed.emit()
	board._handle_left_click(mender)
	eq(str(_u(0).get("bound_name", "")), "Mender", "tapping Mender binds Bastion to her")
	eq(hud.still_aiming(), false, "a successful bind leaves the pick")
	eq(hud._kestrel_body.text.contains("Bound to Mender"), true, "Bastion's card says Bound to Mender")
	eq((board.tiles[empty] as BoardTile).highlight, "move", "walk cells return once Bound Hour resolves")
	main.free()


func _wipe() -> void:
	for path in [TEST_STILL, TEST_BAG, TEST_HERO, TEST_WALLET]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
