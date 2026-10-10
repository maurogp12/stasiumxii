extends SceneTree

## Locked Stills (Mauro 9 Oct 2026): 14 hours, Intact and Overwound,
## forge / socket / online carry, and one fight check per Still per mode.
## Run: godot --headless --path . -s res://tests/run_stills_tests.gd

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
	_test_hourglass()
	_test_steadfast()
	_test_tide()
	_test_rewind()
	_test_long_shadow()
	_test_withering()
	_test_shatterglass()
	_test_tolling_bell()
	_test_bleeding_hour()
	_test_mirror_hour()
	_test_held_hour()
	_test_bound_hour()
	_test_gathered_sand()
	_test_carry_and_online()
	_test_clear_text_and_icons()
	_test_screen()
	_test_card_lines()
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
	eq(StillVault.clean({"id": "wheat", "mode": "intact"}), {}, "unknown Still rejected")
	eq(StillVault.clean({"id": "tide", "mode": "super"}), {}, "unknown mode rejected")
	eq(StillVault.clean({"id": "mirror_hour", "mode": "overwound"}), {"id": "mirror_hour", "mode": "overwound"}, "the host keeps a new id")
	v.save()
	eq(StillVault.load_saved().count("tide"), 12, "vault saves and reloads")


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
	_fight({}, _gear("long_shadow", "intact"), ["kestrel", "ironjaw"], [], [Vector2i(2, 7), Vector2i(6, 7)])
	eq(_sim.chebyshev(_u(0)["pos"], _u(1)["pos"]), 4, "the hit is from 4 tiles")
	var far := int(_sim._mitigate_hit(_u(0), _u(1), 20)["damage"])
	eq(far, 20, "Long Shadow Intact does not change the hit")
	eq(int(_u(1).get("shadow_mp_next", 0)), 2, "the next turn gains +2 MP")
	_sim._mitigate_hit(_u(0), _u(1), 20)
	eq(int(_u(1).get("shadow_hits", 0)), 1, "Intact grants the bonus once")
	_end_turns(1)
	eq(int(_u(1)["mp"]), 5, "the +2 MP is capped at 5")
	_fight({}, _gear("long_shadow", "overwound"))
	var near := int(_sim._mitigate_hit(_u(0), _u(1), 20)["damage"])
	eq(near, 22, "adjacent enemies deal +10% even before a long hit")
	_fight({}, _gear("long_shadow", "overwound"), ["kestrel", "ironjaw"], [], [Vector2i(2, 7), Vector2i(6, 7)])
	for n in 3:
		_sim._mitigate_hit(_u(0), _u(1), 10)
	eq(int(_u(1).get("shadow_mp_next", 0)), 6, "the first 3 long hits each store +2 MP")
	_end_turns(1)
	eq(int(_u(1)["mp"]), 9, "Overwound MP may pass 5")


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
	eq(bool(_u(0).get("alive", true)), false, "the HP cost can knock you out")


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
	_fight(_gear("gathered_sand", "intact"))
	_sim._mitigate_hit(_u(0), _u(1), 10)
	eq(bool(_u(0).get("sand_released", false)), false, "a hit while empty does not spend the release")
	_sim._lose_hp(_u(0), 40)
	eq(int(_u(0).get("sand_stored", 0)), 6, "15% of 40 is stored")
	eq(int(_sim._mitigate_hit(_u(0), _u(1), 10)["damage"]), 16, "the next hit releases the store")
	eq(int(_u(0).get("sand_stored", 0)), 0, "the store is empty")
	eq(bool(_u(0).get("sand_released", false)), true, "the release is once")
	_fight(_gear("gathered_sand", "overwound"))
	_sim._lose_hp(_u(0), 40)
	eq(int(_u(0).get("sand_stored", 0)), 10, "Overwound stores 25%")
	_u(0)["hp"] = 40
	eq(int(_sim._apply_heal(_u(0), 12, _u(0))), 0, "no heals while sand is stored")
	_sim._mitigate_hit(_u(0), _u(1), 10)
	eq(int(_sim._apply_heal(_u(0), 12, _u(0))), 12, "heals work again after the release")


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
	var cs: Script = load("res://scenes/class_select.gd")
	var kit_on: bool = load("res://backend/test_loadout.gd").ACTIVE
	eq(cs.local_match_config().has("seat_gear"), kit_on, "hot-seat gear only while the temporary test kit is on")
	_wipe()
	v = StillVault.new()
	v.socket = "tide"
	v.save()
	var fight: Script = load("res://scenes/stasis_fight.gd")
	eq(fight.consume_still({"units": [{"seat": 0, "still": "tide"}]}), "tide", "the Stasis fight that used Tide destroys it")
	_wipe()
	v = StillVault.new()
	v.socket = "tide"
	v.save()
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.mode = net.Mode.CLIENT
	net.local_seat = 0
	net._note_koliseo_result({"match_over": true, "winner_seat": 0, "units": [{"seat": 0, "class_id": "kestrel", "still": "tide"}, {"seat": 1, "class_id": "gloam"}]})
	eq(int(net.koliseo_last_payout["trophies"]), 1, "a win pays the normal trophy, with no Crown bonus")
	eq(StillVault.load_saved().socket, "", "the Koliseo fight consumed the Still")
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
	eq(hud._unit_card_text(sand, true).contains("Gathered Sand 9/15"), true, "the corner card shows stored sand")
	var bound := {
		"hp": 75, "max_hp": 75, "ap": 4, "mp": 3, "alive": true, "class_id": "kestrel",
		"still": "bound_hour", "still_mode": "intact", "bound_seat": 2, "bound_name": "Bastion", "name": "Kestrel",
	}
	eq(hud._unit_card_text(bound, true).contains("Bound to Bastion"), true, "the corner card names the bind")
	hud.queue_free()


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
