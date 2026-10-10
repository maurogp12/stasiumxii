extends SceneTree

## Ultra PvP sets, the boss chest flag, and the global Vault change.
## Run: godot --headless --path . -s res://tests/run_ultra_tests.gd

const TEST_BAG := "user://test_ultra_bag.json"
const TEST_WALLET := "user://test_ultra_wallet.json"

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	GearBag.save_path = TEST_BAG
	KoliseoWallet.save_path = TEST_WALLET
	HeroProgress.save_path = "user://test_hero_run_ultra_tests.json"
	StillVault.save_path = "user://test_still_run_ultra_tests.json"
	_sim = root.get_node("/root/CombatSim")
	_test_budgets_and_switch()
	_test_shop_and_no_drop()
	_test_boss_chest_flag()
	_test_vault_rules()
	_test_gatewarden()
	_test_sandhawk()
	_test_pitmaw()
	_test_hushring()
	_test_mercywell()
	_test_gear_screen_tags()
	print("Ultra tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _worn(family: String, plus: int = 0) -> Array:
	var out: Array = []
	for slot in GearBag.SLOTS:
		out.append({"item_id": "%s.%s" % [family, slot], "plus": plus})
	return out


func _fight(family: String, pvp: bool) -> Dictionary:
	return {"worn": _worn(family), "flatten_plus": pvp}


func _points(family: String) -> float:
	var pts := 0.0
	for slot in GearBag.SLOTS:
		var part: Dictionary = GearBag.PARTS[GearBag.item_id_for(family, slot)]
		pts += float(part.get("mastery", 0))
		pts += float(part.get("hp", 0)) * 0.5
		pts += float(part.get("resist", 0)) * 2.0
		pts += float(part.get("init", 0)) * 0.5
		pts += float(part.get("crit", 0))
		pts += float(part.get("crit_dmg", 0)) * 0.2
		pts += float(part.get("back_pct", 0)) * 0.75
		pts += float(part.get("bow_range", 0)) * 10.0
		pts += float(part.get("ward_shield", 0)) * 0.5
		pts += float(part.get("extra_mark", 0)) * 4.0
		pts += float(part.get("unbound", 0)) * 3.0
		pts += float(part.get("melee_pct", 0))
		pts += float(part.get("push_flat", 0)) * 1.5
		pts += float(part.get("heal_pct", 0))
		pts += float(part.get("crit_heal", 0))
	return pts


func _test_budgets_and_switch() -> void:
	eq(_points("gatewarden"), 77.0, "Gatewarden is 77 points")
	eq(_points("sandhawk"), 77.0, "Sandhawk is 77 points")
	eq(_points("pitmaw"), 77.0, "Pitmaw is 77 points")
	eq(_points("hushring"), 76.5, "Hushring is 76.5 points (10% back is 7.5)")
	eq(_points("mercywell"), 77.0, "Mercywell is 77 points")
	var plain := {
		"gatewarden": [71, 6, 11, 2],
		"sandhawk": [56, 12, 6, 6],
		"pitmaw": [70, 6, 10, 0],
		"hushring": [62, 23, 0, 14],
		"mercywell": [68, 9, 10, 6],
	}
	for fam in plain:
		var row: Array = plain[fam]
		var off: Dictionary = GearBag.combat_stats(_worn(fam), {}, false, str(GearBag.FAMILIES[fam]["owner"]))
		var on: Dictionary = GearBag.combat_stats(_worn(fam), {}, true, str(GearBag.FAMILIES[fam]["owner"]))
		eq([int(off["hp_flat"]), int(off["mastery"]), int(off["resist"]), int(off["init"])], row, "%s dungeon keeps plain stats" % fam)
		eq([int(on["hp_flat"]), int(on["mastery"]), int(on["resist"]), int(on["init"])], row, "%s Koliseo keeps the same plain stats" % fam)
		eq(int(off["crit"]), 0, "%s crit is off outside PvP" % fam)
		eq(int(off["ap"]), 6, "%s dungeon AP stays 6" % fam)
		eq(int(off["mp"]), 3, "%s dungeon MP stays 3" % fam)
		eq(int(on["ap"]), 7, "%s 5pc is +1 AP in PvP" % fam)
		eq(int(on["mp"]), 4, "%s 5pc is +1 MP in PvP" % fam)
		for key in ["push_guard", "no_back", "crit_ward", "free_vault", "fade_cut", "detonate_strip", "berserk", "hit_slow", "shoulder_strip", "heal_suppress", "shield_burst", "long_fade", "cleanse_stun", "cheat_death", "rekindle_ultra", "bow_range", "extra_mark", "unbound", "melee_pct", "crit_dmg", "push_flat", "heal_pct", "crit_heal", "back_pct", "ward_shield"]:
			eq(int(off.get(key, 0)), 0, "%s %s is off outside PvP" % [fam, key])
	var gate: Dictionary = GearBag.combat_stats(_worn("gatewarden"), {}, true, "bastion")
	eq(int(gate["ward_shield"]), 25, "Gatewarden Ward is 25 in PvP")
	eq(int(gate["push_guard"]), 1, "Gatewarden 2pc")
	eq(int(gate["no_back"]), 1, "Gatewarden 4pc")
	eq(int(gate["crit_ward"]), 1, "Gatewarden 5pc crit ward")
	var hawk: Dictionary = GearBag.combat_stats(_worn("sandhawk"), {}, true, "kestrel")
	eq(int(hawk["crit"]), 5, "Sandhawk crit is 5%")
	eq(int(hawk["bow_range"]), 1, "Sandhawk bow range")
	eq(int(hawk["extra_mark"]), 1, "Sandhawk extra mark")
	eq(int(hawk["unbound"]), 1, "Sandhawk unbound")
	var pit: Dictionary = GearBag.combat_stats(_worn("pitmaw"), {}, true, "ironjaw")
	eq(int(pit["crit"]), 3, "Pitmaw crit is 3%")
	eq(int(pit["melee_pct"]), 8, "Pitmaw melee +8%")
	eq(int(pit["crit_dmg"]), 10, "Pitmaw crit damage +10")
	eq(int(pit["push_flat"]), 2, "Pitmaw push +2")
	var hush: Dictionary = GearBag.combat_stats(_worn("hushring"), {}, true, "gloam")
	eq(int(hush["crit"]), 6, "Hushring crit is 6%")
	eq(int(hush["back_pct"]), 10, "Hushring back +10%")
	eq(int(hush["crit_dmg"]), 10, "Hushring crit damage +10")
	eq(int(hush["resist"]), 0, "Hushring has no resist")
	var mercy: Dictionary = GearBag.combat_stats(_worn("mercywell"), {}, true, "mender")
	eq(int(mercy["heal_pct"]), 8, "Mercywell heal +8%")
	eq(int(mercy["crit_heal"]), 3, "Mercywell crit heal 3%")
	eq(int(mercy["crit"]), 0, "Mercywell has no damage crit")
	var fused_off: Dictionary = GearBag.combat_stats([{"item_id": "gatewarden.chest", "plus": 5}], {}, false, "bastion")
	var fused_on: Dictionary = GearBag.combat_stats([{"item_id": "gatewarden.chest", "plus": 5}], {}, true, "bastion")
	truthy(int(fused_off["hp_flat"]) > int(fused_on["hp_flat"]), "Koliseo still flattens +plus before the Ultra switch")
	eq(int(fused_on["hp_flat"]), 32, "a flattened Gate Plate is 32 HP")


func _test_shop_and_no_drop() -> void:
	for fam in GearBag.ULTRA_ORDER:
		eq(GearBag.families_of_rarity("Legendary").has(fam), false, "%s is not legendary loot" % fam)
		eq(GearBag.families_for_star(5).has(fam), false, "%s is not in a ★5 door" % fam)
	var wallet := KoliseoWallet.new()
	wallet.coins = 30
	var bag := GearBag.new()
	var bought: Dictionary = wallet.buy_ultra("sandhawk", "weapon", bag)
	eq(bool(bought.get("ok", false)), true, "30 coins buys one Ultra part")
	eq(wallet.coins, 0, "the part costs 30")
	eq(str(bag.items[0]["item_id"]), "sandhawk.weapon", "the bow is in the bag")
	eq(int(bag.items[0]["plus"]), 0, "shop parts are +0")
	var broke: Dictionary = wallet.buy_ultra("sandhawk", "head", bag)
	eq(str(broke.get("reason", "")), "not_enough_coins", "a second part needs another 30")
	eq(str(wallet.buy_ultra("ashmantle", "head", bag).get("reason", "")), "unknown", "ladder sets are not on the Ultra stall")


func _test_boss_chest_flag() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/stasis_fight.gd")
	truthy(src.contains("StasisCatalog.room == \"b\""), "a Room B clear passes the boss table")
	for map_id in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		truthy(StasisCatalog.boss_name(map_id) != "", "%s has a Room B boss" % map_id)
	eq(StasisCatalog.boss_name("crosshaven"), "Sheaf Sovereign", "Threshgate boss")
	eq(StasisCatalog.boss_name("brinewake"), "Tide-Lord Brineclaw", "Tidehold boss")
	eq(StasisCatalog.boss_name("slagcrown"), "Slagheart (Caldera Crown)", "Ashmarch boss")
	eq(StasisCatalog.boss_name("windmere"), "Serra White-Spire Regent", "Galevault boss")
	eq(StasisCatalog.boss_name("stormspire"), "High Coilspire", "Coilgate boss")


func _rolls(values: Array) -> void:
	_sim._scripted_rolls.clear()
	for value in values:
		_sim._scripted_rolls.append(int(value))


func _active() -> int:
	return int(_sim.snapshot().get("active_seat", -1))


func _end() -> void:
	_sim.submit({"type": "end_turn", "seat": _active()})


func _bring(seat: int) -> void:
	var guard := 0
	while _active() != seat and guard < 8:
		_end()
		guard += 1


func _cycle_pair() -> void:
	_end()
	_end()


func _test_vault_rules() -> void:
	eq(int(SpellKits.spell(SpellKits.VAULT).get("ap", 0)), 3, "Vault costs 3 AP")
	eq(int(SpellKits.spell(SpellKits.ADVANCE).get("ap", 0)), 3, "Advance stays 3 AP")
	eq(int(SpellKits.spell(SpellKits.VAULT).get("cooldown", 0)), 2, "Vault cooldown stays 2")
	_sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "classes": ["kestrel", "gloam"], "positions": [Vector2i(5, 5), Vector2i(6, 5)]})
	var first: Dictionary = _sim.submit({"type": "cast", "spell": "vault", "to": Vector2i(3, 5), "seat": 0})
	eq(bool(first.get("ok", false)), true, "the first Vault lands")
	eq(int(_sim._unit_by_seat(0)["ap"]), int(_sim._unit_by_seat(0)["max_ap"]) - 3, "it spent 3 AP")
	eq(int(_sim._unit_by_seat(0)["vaults_cast"]), 1, "it counts toward the match cap")
	for _i in 3:
		_cycle_pair()
	_sim._unit_by_seat(1)["pos"] = Vector2i(4, 5)
	var second: Dictionary = _sim.submit({"type": "cast", "spell": "vault", "to": Vector2i(3, 3), "seat": 0})
	eq(bool(second.get("ok", false)), true, "the second Vault is the match cap")
	eq(int(_sim._unit_by_seat(0)["vaults_cast"]), 2, "two Vaults are recorded")
	for _i in 3:
		_cycle_pair()
	_sim._unit_by_seat(1)["pos"] = Vector2i(3, 4)
	var third: Dictionary = _sim.submit({"type": "cast", "spell": "vault", "to": Vector2i(3, 1), "seat": 0})
	eq(str(third.get("reason", "")), "vault_match", "a third Vault is refused")


func _test_gatewarden() -> void:
	_sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "classes": ["bastion", "ironjaw"], "positions": [Vector2i(4, 4), Vector2i(5, 4)], "seat_gear": {0: _fight("gatewarden", true)}})
	var bast: Dictionary = _sim._unit_by_seat(0)
	var before := int(bast["hp"])
	var stagger: Dictionary = _sim._apply_bounce_stagger(bast, {"from": bast["pos"], "earth": false}, "out_of_bounds", {})
	eq(int(stagger.get("stagger_hp", -1)), 0, "Gatewarden takes no stagger")
	eq(int(bast["hp"]), before, "the push deals no extra HP")
	var jaw: Dictionary = _sim._unit_by_seat(1)
	jaw["push_flat"] = 2
	var open: Dictionary = _sim._apply_bounce_stagger(jaw, {"from": jaw["pos"], "earth": false}, "out_of_bounds", jaw)
	eq(int(open.get("stagger_hp", 0)), 6, "Pitmaw push +2 makes stagger 6")
	var wall: Dictionary = _sim._apply_bounce_stagger(jaw, {"from": jaw["pos"], "earth": true}, "out_of_bounds", jaw)
	eq(int(wall.get("stagger_hp", 0)), 10, "an earth wall slam is 8+2")
	_sim._active_seat = 1
	bast["resist"] = 0
	jaw["crit"] = 100
	jaw["crit_landed"] = false
	_rolls([1])
	var negated: int = _sim._phase_a_damage(20, 1.0, jaw, bast, "", true)
	eq(negated, 20, "a crit on Gatewarden deals normal damage")
	eq(bool(bast["crit_ward_used"]), true, "the ward is spent for this turn")
	eq(bool(jaw["crit_landed"]), true, "the attacker still spent the crit")
	jaw["crit_landed"] = false
	_rolls([1])
	var second: int = _sim._phase_a_damage(20, 1.0, jaw, bast, "", true)
	eq(second, 26, "the next crit this turn is a real crit")
	bast["pos"] = Vector2i(1, 1)
	bast["crit_ward_used"] = false
	jaw["crit_landed"] = false
	jaw["pos"] = Vector2i(8, 8)
	_rolls([1])
	var far: int = _sim._phase_a_damage(20, 1.0, jaw, jaw, "", true)
	eq(far, 26, "a crit outside 3 tiles is not warded")


func _test_sandhawk() -> void:
	_sim.reset_match({"seed": 3, "flat_board": true, "skip_deploy": true, "classes": ["kestrel", "ironjaw"], "positions": [Vector2i(2, 5), Vector2i(4, 5)], "seat_gear": {0: _fight("sandhawk", true)}})
	var kite: Dictionary = _sim._unit_by_seat(0)
	var shot: Dictionary = SpellKits.spell_for(kite, SpellKits.MARK_SHOT)
	var boom: Dictionary = SpellKits.spell_for(kite, SpellKits.DETONATE)
	eq(int(shot.get("max_range", 0)), 6, "Mark Shot reaches 6")
	eq(int((shot.get("hit_by_distance", {}) as Dictionary).get(6, 0)), 95, "distance 6 hits on 95")
	eq(int(boom.get("max_range", 0)), 5, "Detonate reaches 5")
	SpellKits.set_element_riders(false)
	eq(int(SpellKits.spell_for(kite, SpellKits.DETONATE).get("max_range", 0)), 5, "the bow sets Detonate to 5 without stacking Air")
	eq(int(SpellKits.spell_for({}, SpellKits.DETONATE).get("max_range", 0)), 4, "a normal Detonate stays 4 without Air")
	SpellKits.set_element_riders(true)
	_bring(1)
	var walked: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 5), "seat": 1})
	eq(bool(walked.get("ok", false)), true, "the enemy steps next to her")
	eq(bool(kite.get("vault_free", false)), true, "that banks a free Vault")
	eq(bool(kite.get("vault_bank_used", false)), true, "the bank is once per match")
	_bring(0)
	var ap_before := int(kite["ap"])
	var free: Dictionary = _sim.submit({"type": "cast", "spell": "vault", "to": Vector2i(2, 3), "seat": 0})
	eq(bool(free.get("ok", false)), true, "the free Vault resolves")
	eq(int(kite["ap"]), ap_before, "a free Vault costs 0 AP")
	eq(int(kite["vaults_cast"]), 1, "the free Vault counts as one of the two")
	eq(int((kite.get("spell_cd", {}) as Dictionary).get(SpellKits.VAULT, 0)), 0, "the free Vault skips the cooldown")
	_sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "classes": ["kestrel", "bastion"], "positions": [Vector2i(2, 2), Vector2i(5, 2)], "seat_gear": {0: _fight("sandhawk", true)}, "bastion_aegis": 3})
	_bring(0)
	_rolls([1, 99])
	var marked: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(5, 2), "seat": 0})
	eq(bool(marked.get("ok", false)), true, "Mark Shot connects")
	eq(int(_sim._unit_by_seat(1)["marks"]), 2, "the first Mark Shot on this enemy adds an extra Mark")
	_rolls([1, 99])
	_sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(5, 2), "seat": 0})
	eq(int(_sim._unit_by_seat(1)["marks"]), 3, "a later Mark Shot on the same enemy adds only one")
	_rolls([1, 99])
	var detonated: Dictionary = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(5, 2), "seat": 0})
	eq(bool(detonated.get("ok", false)), true, "Detonate connects")
	eq(int(_sim._unit_by_seat(1)["aegis"]), 2, "Detonate removes 1 Aegis")
	eq(bool(_sim._unit_by_seat(0).get("detonate_strip_ready", true)), false, "the strip is once per turn")
	var slow: Dictionary = _sim._unit_by_seat(0)
	slow["unbound"] = true
	slow["unbound_ready"] = true
	_sim._add_element_rider(slow, "water", [])
	eq(bool(slow.get("water_slow", false)), false, "the first Slow is ignored")
	eq(bool(slow.get("unbound_ready", true)), false, "Unbound is once per fight")
	_sim._add_element_rider(slow, "water", [])
	eq(bool(slow.get("water_slow", false)), true, "the next Slow lands")


func _test_pitmaw() -> void:
	_sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "classes": ["ironjaw", "bastion"], "positions": [Vector2i(4, 4), Vector2i(5, 4)], "seat_gear": {0: _fight("pitmaw", true)}, "bastion_aegis": 2})
	var jaw: Dictionary = _sim._unit_by_seat(0)
	var bast: Dictionary = _sim._unit_by_seat(1)
	_bring(0)
	_rolls([1, 99])
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(5, 4), "seat": 0})
	eq(bool(hit.get("ok", false)), true, "Shoulder connects")
	eq(int(bast["aegis"]), 1, "Shoulder removes 1 Aegis")
	eq(int(jaw.get("strip_cd", 0)), 2, "the next strip waits two turns")
	eq(bool(bast.get("gear_slow", false)), true, "the first hit applies a Slow")
	_end()
	eq(_active(), 1, "Bastion acts next")
	eq(int(bast["mp"]), int(bast["max_mp"]) - 1, "the Slow cuts 1 MP on his turn")
	_end()
	eq(int(jaw.get("strip_cd", 0)), 1, "his next turn ticks the strip clock to 1")
	_cycle_pair()
	eq(int(jaw.get("strip_cd", 0)), 0, "the strip is ready two turns later")
	jaw["hp"] = 50
	_sim._maybe_berserk(jaw)
	eq(int(jaw.get("berserk_queued", 0)), 2, "dropping under 35% HP queues Berserk")
	eq(bool(jaw.get("berserk_on", false)), false, "Berserk waits for his next turn")
	var mp := int(jaw["max_mp"])
	_end()
	_bring(0)
	eq(bool(jaw.get("berserk_on", false)), true, "Berserk is on for the first of two turns")
	eq(int(jaw["max_mp"]), mp + 1, "Berserk grants +1 MP")
	_rolls([1])
	jaw["resist"] = 0
	var taken: int = _sim._phase_a_damage(20, 1.0, bast, jaw, "", false)
	eq(taken, 21, "Berserk takes +5% damage")
	var melee: int = _sim._gear_strike_damage({"melee_pct": 8, "berserk_on": true}, {}, 100, 1, false, false)
	eq(melee, 123, "melee +8% and Berserk +15% stack")
	_cycle_pair()
	eq(bool(jaw.get("berserk_on", false)), true, "the second turn is still Berserk")
	_cycle_pair()
	eq(bool(jaw.get("berserk_on", false)), false, "Berserk ends after two turns")
	eq(int(jaw["max_mp"]), mp, "the extra MP leaves with it")


func _test_hushring() -> void:
	_sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "classes": ["gloam", "mender"], "positions": [Vector2i(3, 3), Vector2i(4, 3)], "seat_gear": {0: _fight("hushring", true)}})
	var gloam: Dictionary = _sim._unit_by_seat(0)
	var mender: Dictionary = _sim._unit_by_seat(1)
	_bring(0)
	_rolls([1, 99])
	var cut: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(4, 3), "seat": 0})
	if not bool(cut.get("ok", false)):
		_rolls([1, 99])
		cut = _sim.submit({"type": "cast", "spell": "cut", "to": Vector2i(4, 3), "seat": 0})
	eq(bool(cut.get("ok", false)), true, "Hushring lands a hit")
	eq(bool(mender.get("heal_cut", false)), true, "the target heals less until their turn")
	mender["hp"] = 10
	mender["max_hp"] = 200
	eq(_sim._apply_heal(mender, 100), 75, "the cut is 25%")
	_end()
	eq(bool(mender.get("heal_cut", false)), false, "the cut ends when their turn starts")
	mender["shield"] = 20
	mender["hp"] = int(mender["max_hp"])
	gloam["shield_burst_ready"] = true
	var report: Dictionary = _sim._mitigate_hit(gloam, mender, 10)
	eq(int(report.get("shield_absorbed", 0)), 15, "the first hit deals +50% to the shield")
	eq(int(mender["hp"]), int(mender["max_hp"]), "the extra shield damage does not spill into HP")
	eq(int(mender["shield"]), 5, "the shield keeps what the burst did not break")
	_bring(0)
	var faded: Dictionary = _sim.submit({"type": "cast", "spell": "fade", "to": gloam["pos"], "seat": 0})
	eq(bool(faded.get("ok", false)), true, "Fade resolves")
	eq(int(gloam.get("invisible_turns", 0)), 3, "Hushring Fade lasts 3 turns")
	gloam["marks"] = 2
	gloam["marks_seat"] = 1
	mender["fade_cut"] = 1
	eq(_sim._fade_turns(gloam), 1, "Sandhawk's fade cut wins over the 3-turn Fade")


func _test_mercywell() -> void:
	eq(int(SpellKits.spell(SpellKits.REKINDLE).get("ap", 0)), 6, "base Rekindle stays 6 AP")
	eq(int(SpellKits.spell(SpellKits.REKINDLE).get("requires_pulse", 0)), 6, "base Rekindle stays 6 Pulse")
	eq(int(SpellKits.spell(SpellKits.REKINDLE).get("max_range", 0)), 2, "base Rekindle stays range 2")
	eq(int(SpellKits.spell(SpellKits.REKINDLE).get("revive_pct", 0)), 30, "base Rekindle stays 30% HP")
	_sim.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "team_size": 2, "classes": ["mender", "ironjaw", "kestrel", "gloam"], "positions": [Vector2i(2, 2), Vector2i(8, 8), Vector2i(3, 2), Vector2i(9, 8)], "seat_gear": {0: _fight("mercywell", true)}})
	var mender: Dictionary = _sim._unit_by_seat(0)
	var ally: Dictionary = _sim._unit_by_seat(2)
	ally["stun_remaining"] = 1
	ally["stunned"] = true
	ally["slow_remaining"] = 1
	ally["slow_stacks"] = 1
	_bring(0)
	var cleansed: Dictionary = _sim.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(3, 2), "seat": 0})
	eq(bool(cleansed.get("ok", false)), true, "Cleanse resolves")
	eq(int(ally.get("stun_remaining", 1)), 0, "Mercywell Cleanse removes Stun")
	eq(bool(ally.get("stunned", true)), false, "the stun flag is gone")
	eq(int(ally.get("slow_remaining", 1)), 0, "and it still removes one other debuff")
	mender["hp"] = 0
	_sim._check_death(mender)
	eq(int(mender["hp"]), 1, "a lethal hit leaves her at 1 HP")
	eq(bool(mender.get("alive", false)), true, "she is still standing")
	eq(bool(mender.get("cheat_ready", true)), false, "the save is once per fight")
	ally["alive"] = false
	ally["hp"] = 0
	mender["pulse"] = 6
	mender["hp"] = int(mender["max_hp"])
	var ultra: Dictionary = SpellKits.spell_for(mender, SpellKits.REKINDLE)
	eq(int(ultra.get("ap", 0)), 5, "Ultra Rekindle costs 5 AP")
	eq(int(ultra.get("spend_pulse", 0)), 4, "Ultra Rekindle spends 4 Pulse")
	eq(int(ultra.get("max_range", 0)), 3, "Ultra Rekindle reaches 3")
	eq(int(ultra.get("revive_pct", 0)), 40, "Ultra Rekindle restores 40%")
	eq(int(ultra.get("revive_shield", 0)), 10, "Ultra Rekindle grants a 10 shield")
	_bring(0)
	var revived: Dictionary = _sim.submit({"type": "cast", "spell": "rekindle", "to": ally["pos"], "seat": 0})
	eq(bool(revived.get("ok", false)), true, "Ultra Rekindle brings the ally back")
	eq(bool(ally.get("alive", false)), true, "the ally is alive")
	eq(int(ally["hp"]), maxi(roundi(float(int(ally["max_hp"])) * 0.4), 1), "they return at 40% HP")
	eq(int(ally.get("shield", 0)), 10, "they return with a 10 shield")
	eq(int(mender["pulse"]), 2, "it spent 4 Pulse")


func _test_gear_screen_tags() -> void:
	var screen = (load("res://scenes/gear_screen.gd") as Script).new()
	screen.name = "UltraGear"
	root.add_child(screen)
	var equipped: Dictionary = screen._bag.debug_equip_set("bastion", "gatewarden")
	eq(bool(equipped.get("ok", false)), true, "debug equip wears Gatewarden")
	screen._refresh()
	var gold := _bonus_color(screen, true)
	eq(gold, Color(0.95, 0.82, 0.52), "PvP lines are gold on the hub sheet")
	screen.set_pvp_lines(false)
	var grey := _bonus_color(screen, false)
	eq(grey, Color(0.42, 0.42, 0.46), "the same lines are grey in a dungeon")
	truthy(screen.header_text().contains("AP 6/"), "the dungeon header hides the +1 AP")
	screen.set_pvp_lines(true)
	truthy(screen.header_text().contains("AP 7/"), "the PvP header shows the +1 AP")
	screen.queue_free()


func _bonus_color(screen: Control, _pvp: bool) -> Color:
	for child in screen._sets_box.get_children():
		var label := child as Label
		if label != null and label.text.contains("2pc:") and label.text.contains("PvP"):
			return label.get_theme_color("font_color")
	return Color(0, 0, 0, 0)


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
