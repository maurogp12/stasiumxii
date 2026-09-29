extends SceneTree

## Levels, XP, passives on, resist cap, Init seat (Mauro 29 Sep 2026).
## Run: godot --headless --path . -s res://tests/run_levels_tests.gd

const TEST_HERO := "user://test_hero_progress.json"
const TEST_BAG := "user://test_levels_bag.json"
const TEST_WALLET := "user://test_levels_wallet.json"

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	HeroProgress.save_path = TEST_HERO
	GearBag.save_path = TEST_BAG
	KoliseoWallet.save_path = TEST_WALLET
	_wipe()
	_test_curve()
	_test_levels_and_points()
	_test_inherent_table()
	_test_passives_and_cap()
	_test_levels_in_fights()
	_test_init_seat()
	_test_xp_awards()
	_test_screens()
	_wipe()
	print("Levels tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_curve() -> void:
	eq(HeroProgress.xp_to_next(1), 80, "1→2 = 80 XP")
	eq(HeroProgress.xp_to_next(2), 120, "2→3 = 120 XP")
	eq(HeroProgress.xp_to_next(29), 1200, "29→30 = 1200 XP")
	eq(HeroProgress.xp_to_next(30), 0, "30 is the cap")
	eq(HeroProgress.total_xp_to(30), 18560, "18560 XP total to level 30")


func _test_levels_and_points() -> void:
	var hero := HeroProgress.new()
	eq(hero.level_of("kestrel"), 1, "new class starts at level 1")
	var gain := hero.add_xp("kestrel", 79)
	eq([gain["level"], hero.xp_of("kestrel")], [1, 79], "79 XP stays level 1")
	gain = hero.add_xp("kestrel", 1)
	eq([gain["level"], gain["levels_gained"], hero.xp_of("kestrel")], [2, 1, 0], "80 XP → level 2")
	gain = hero.add_xp("kestrel", 400)
	eq(gain["level"], 4, "400 more: 120 + 160 → level 4, 120 left")
	eq(hero.xp_of("kestrel"), 120, "leftover XP carries")
	eq(hero.points_free("kestrel"), 3, "level 4 = 3 points")
	eq(hero.level_of("ironjaw"), 1, "levels are per class")
	eq(bool(hero.spend("kestrel", "swift")["ok"]), true, "spend a point")
	hero.spend("kestrel", "swift")
	hero.spend("kestrel", "mastery")
	eq(str(hero.spend("kestrel", "ward")["reason"]), "no_points", "no points left")
	eq(str(hero.spend("kestrel", "luck")["reason"]), "unknown_bucket", "only the four buckets")
	hero.add_xp("mender", 999999)
	eq(hero.level_of("mender"), 30, "XP caps at level 30")
	eq(hero.points_free("mender"), 29, "29 points at 30")
	eq(HeroProgress.clean_spent({"mastery": 10, "vitality": 10}, 5), {"mastery": 4}, "spent points never exceed level − 1")
	truthy(hero.save(), "progress saves")
	var back := HeroProgress.load_saved()
	eq(back.level_of("kestrel"), 4, "level reloads")
	eq(back.record("kestrel")["spent"], {"swift": 2, "mastery": 1}, "spent points reload")


func _test_inherent_table() -> void:
	# Characteristics sheet "At 30, inherent only (0 spend)".
	var table := {
		"kestrel": [58, 87, 29, 0], "ironjaw": [58, 174, 0, 29], "mender": [29, 145, 29, 29],
		"gloam": [58, 87, 29, 0], "bastion": [29, 232, 0, 58],
	}
	for class_id in table:
		var st := HeroProgress.combat_stats({"level": 30}, class_id)
		eq([st["mastery"], st["hp"], st["init"], st["ward"]], table[class_id], "%s level 30 inherent matches the sheet" % class_id)
	eq(HeroProgress.combat_stats({"level": 19}, "kestrel")["ap"], 0, "no AP before 20")
	eq(HeroProgress.combat_stats({"level": 20}, "kestrel")["ap"], 1, "+1 AP at level 20")
	var spent := HeroProgress.combat_stats({"level": 5, "spent": {"mastery": 1, "vitality": 1, "swift": 1, "ward": 1}}, "kestrel")
	eq([spent["mastery"], spent["hp"], spent["init"], spent["ward"]], [8 + 2, 12 + 8, 4 + 1, 0 + 2], "spend adds Mastery +2, HP +8, Init +1, Ward +2")
	var cheat := HeroProgress.combat_stats({"level": 99, "spent": {"mastery": 500}}, "kestrel")
	eq([cheat["level"], cheat["mastery"]], [30, 58 + 29 * 2], "a forged level caps at 30 and 29 points")


func _test_passives_and_cap() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	var kestrel := {"class_id": "kestrel", "pos": Vector2i(0, 0)}
	eq(sim._class_passive(kestrel, {"pos": Vector2i(4, 1)}), 1.15, "Longshot ×1.15 at Chebyshev 4")
	eq(sim._class_passive(kestrel, {"pos": Vector2i(3, 3)}), 1.0, "no Longshot at 3")
	var jaw := {"class_id": "ironjaw", "pos": Vector2i(0, 0), "momentum": false}
	eq(sim._class_passive(jaw, {"pos": Vector2i(1, 0)}), 1.0, "Momentum off when he stood still")
	jaw["mp"] = 3
	sim._spend_mp(jaw, 0)
	eq(bool(jaw["momentum"]), false, "spending 0 MP is not moving")
	sim._spend_mp(jaw, 1)
	eq([jaw["mp"], jaw["momentum"]], [2, true], "spending MP arms Momentum")
	eq(sim._class_passive(jaw, {"pos": Vector2i(1, 0)}), 1.2, "Momentum ×1.20")
	eq(sim._phase_a_damage(20, 1.0, {}, {"resist": 80}), 10, "resist caps at 50%")
	eq(sim._phase_a_damage(20, 1.0, {}, {"resist": 30, "resist_elem": {"earth": 40}}, "earth"), 10, "all + element resist also caps at 50%")
	var snap: Dictionary = sim.snapshot()
	eq([snap["longshot"], snap["momentum"]], [true, true], "Longshot and Momentum are on")


func _test_levels_in_fights() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	var heroes := {"bastion": {"level": 30, "spent": {}}, "kestrel": {"level": 20, "spent": {"swift": 3}}}
	sim.reset_match({"classes": ["kestrel", "bastion"], "skip_deploy": true, "seat_gear": {
		0: {"worn": [], "heroes": heroes},
		1: {"worn": [{"item_id": "sheaf.head", "plus": 0}, {"item_id": "sheaf.chest", "plus": 0}], "heroes": heroes},
	}})
	var k: Dictionary = sim._unit_by_seat(0)
	var b: Dictionary = sim._unit_by_seat(1)
	eq(int(k["level"]), 20, "seat 0 fights as its Kestrel level")
	eq(int(k["max_hp"]), 80 + 19 * 3, "Kestrel 20: 80 + 57 HP")
	eq(int(k["mastery"]), 38, "Kestrel 20: 19 × 2 Mastery")
	eq(int(k["init"]), 19 + 3, "Kestrel 20: 19 Init + 3 Swift")
	eq(int(k["max_ap"]), 7, "Kestrel 20: +1 AP")
	eq(int(b["max_hp"]), roundi((80 + 232 + 68) * 1.10), "Bastion 30 + Sheaf helm/coat: (80+232+68)×1.10")
	eq(int(b["resist_elem"].get("earth", 0)), 5 + 58, "Ward 58 lands on the active Sheaf Earth attune")
	sim.reset_match({"classes": ["kestrel", "bastion"], "skip_deploy": true, "seat_gear": {1: {"worn": [], "heroes": heroes}}})
	eq(sim._unit_by_seat(1)["resist_elem"], {}, "no 2-piece attune: Ward does nothing")


func _test_init_seat() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	var fast := {"kestrel": {"level": 1, "spent": {}}, "bastion": {"level": 3, "spent": {"swift": 2}}}
	sim.reset_match({"classes": ["kestrel", "bastion"], "skip_deploy": true, "first_by_init": true, "seat_gear": {1: {"worn": [], "heroes": fast}}})
	eq(int(sim.snapshot()["active_seat"]), 1, "higher Init (seat 1) acts first")
	truthy(str(sim.snapshot()["coach"]).contains("Init 2 vs 0"), "coach names the Init")
	sim.reset_match({"classes": ["kestrel", "bastion"], "skip_deploy": true})
	eq(int(sim.snapshot()["active_seat"]), 0, "fixtures without first_by_init keep seat 0")
	var firsts := {}
	for seed in 30:
		sim.reset_match({"classes": ["kestrel", "bastion"], "skip_deploy": true, "first_by_init": true, "seed": seed})
		firsts[int(sim.snapshot()["active_seat"])] = true
	eq(firsts.size(), 2, "an Init tie is a coin flip (both seats start sometimes)")
	truthy(str(sim.init_note()).contains("coin flip"), "tie note says coin flip")
	var cs: Script = load("res://scenes/class_select.gd")
	eq(bool(cs.local_match_config()["first_by_init"]), true, "hot-seat uses Init / coin flip")
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "mender"
	eq(bool(StasisCatalog.fight_config()["first_by_init"]), true, "Stasis uses Init / coin flip")
	StasisCatalog.clear_run()


func _test_xp_awards() -> void:
	_wipe()
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.mode = net.Mode.CLIENT
	net.local_seat = 1
	var snap := {"match_over": true, "winner_seat": 1, "units": [{"seat": 0, "class_id": "kestrel"}, {"seat": 1, "class_id": "gloam"}]}
	net._note_koliseo_result(snap)
	eq(int(net.koliseo_last_payout["xp"]), 50, "online Koliseo win = 50 XP")
	eq(HeroProgress.load_saved().xp_of("gloam"), 50, "XP goes to the class that fought")
	net._note_koliseo_result({"match_over": false})
	snap["winner_seat"] = 0
	net._note_koliseo_result(snap)
	eq(int(net.koliseo_last_payout["xp"]), 15, "online Koliseo loss = 15 XP")
	eq(HeroProgress.load_saved().level_of("gloam"), 1, "65 XP: still level 1")
	net.mode = net.Mode.HOTSEAT
	net.local_seat = -1
	net._note_koliseo_result({"match_over": false})
	net._note_koliseo_result(snap)
	eq(net.koliseo_last_payout.has("xp"), false, "hot-seat gives no XP")
	net.free()
	eq(HeroProgress.stasis_xp(1, true), 60, "Stasis ★1 clear = 60 XP")
	eq(HeroProgress.stasis_xp(5, true), 300, "★5 = 300 XP")
	eq(HeroProgress.stasis_xp(1, false), 20, "clear with no chest = 20 XP")
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "bastion"
	var fight: Script = load("res://scenes/stasis_fight.gd")
	var inst: Node = fight.new()
	var loot: Dictionary = inst.open_chest()
	inst.free()
	eq(int(loot["xp"]), 60, "a Stasis clear with a chest pays 60 XP")
	eq(HeroProgress.load_saved().xp_of("bastion"), 60, "Stasis XP goes to the class that ran")
	StasisCatalog.clear_run()
	var result := CombatResult.koliseo_result({"winner_seat": 0, "units": [{"seat": 0, "name": "Kestrel", "hp": 5, "max_hp": 80}, {"seat": 1, "name": "Gloam", "hp": 0, "max_hp": 80}]}, 0, {"coins": 1, "trophies": 1, "xp": 50, "level": 2, "levels_gained": 1}, 30)
	eq([result["winners"][0]["xp"], result["winners"][0]["levels_gained"]], [50, 1], "result window gets the XP and level up")
	var window: CombatResult = load("res://ui/combat_result.gd").new()
	window.setup(result)
	root.add_child(window)
	var xp_label := window.find_child("XpLabel", true, false) as Label
	eq(xp_label.text, "+50 XP  Lv 2!", "XP column shows the gain and the level up")
	window.free()


func _test_screens() -> void:
	_wipe()
	var hero := HeroProgress.new()
	hero.add_xp("ironjaw", 80 + 120)
	hero.save()
	var screen: CharacterScreen = load("res://scenes/character_screen.gd").new()
	root.add_child(screen)
	screen.pick("ironjaw")
	var free := screen.find_child("FreePoints", true, false) as Label
	eq(free.text, "Free points: 2", "level 3 shows 2 free points")
	eq(bool(screen.spend("vitality")["ok"]), true, "spend from the screen")
	eq(HeroProgress.load_saved().record("ironjaw")["spent"], {"vitality": 1}, "screen saves the spend")
	truthy((screen.find_child("LevelStats", true, false) as Label).text.contains("HP +20"), "level 3 Ironjaw: 12 growth + 8 Vitality")
	screen.free()
	var gear: GearScreen = load("res://scenes/gear_screen.gd").new()
	root.add_child(gear)
	truthy(gear.find_child("OpenLevels", true, false) != null, "Gear screen has a Levels button")
	var opened := gear.open_levels()
	truthy(opened != null and opened.is_inside_tree(), "Levels opens from Gear")
	gear.free()


func _wipe() -> void:
	for path in [TEST_HERO, TEST_BAG, TEST_WALLET]:
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
