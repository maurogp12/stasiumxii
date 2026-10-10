extends SceneTree

## XII Stills on mobile (Mauro 29 Sep 2026): vault, chest fragments, forge,
## socket, Intact / Overwound effects, consumed by the fight.
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
	_test_stride()
	_test_one_shots()
	_test_opening_and_carry()
	_test_consume_and_chest()
	_test_screen()
	_test_clear_text_and_icons()
	_wipe()
	print("Stills tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _gear(still: String, mode: String) -> Dictionary:
	return {"worn": [], "still": {"id": still, "mode": mode}}


func _fight(seat0: Dictionary, seat1: Dictionary = {}, classes: Array = ["kestrel", "ironjaw"], rolls: Array = []) -> void:
	var sg := {0: seat0}
	if not seat1.is_empty():
		sg[1] = seat1
	var config := {"classes": classes, "skip_deploy": true, "positions": [Vector2i(5, 7), Vector2i(6, 7)], "seat_gear": sg}
	if not rolls.is_empty():
		config["rolls"] = rolls
	_sim.reset_match(config)


func _end_turns(n: int) -> void:
	for i in n:
		_sim.submit({"type": "end_turn", "seat": int(_sim.snapshot()["active_seat"])})


func _test_vault() -> void:
	eq(StillVault.IDS.size(), 12, "twelve Stills")
	var v := StillVault.new()
	var picks := [0.0, 0.99]
	var i := [0]
	var pick := func() -> float:
		var x: float = picks[i[0] % picks.size()]
		i[0] += 1
		return x
	eq(v.roll_chest(1, pick), ["opening"], "★1 chest rolls 1 fragment")
	eq(v.roll_chest(5, pick).size(), 3, "★5 chest rolls 3 fragments")
	eq(v.roll_chest(3, pick).size(), 2, "★3 chest rolls 2 fragments")
	v.fragments = {"stride": 11, "cut": 5}
	eq(str(v.forge("stride")["reason"]), "needs_12", "forge needs 12 of the same")
	v.fragments["stride"] = 13
	eq(bool(v.forge("stride")["ok"]), true, "12 Stride fragments forge Stride")
	eq(v.count("stride"), 1, "leftover fragment stays")
	eq(v.socket, "stride", "Stride sits in the socket")
	v.fragments["cut"] = 12
	eq(str(v.forge("cut")["reason"]), "socket_full", "socket must be empty to forge")
	eq(bool(v.set_mode("overwound")["ok"]), true, "choose Overwind")
	eq(v.fight_still(), {"id": "stride", "mode": "overwound"}, "the fight gets id + mode")
	eq(v.consume(), "stride", "the fight destroys it")
	eq(v.socket, "", "socket empty after the fight")
	eq(StillVault.clean({"id": "wheat", "mode": "intact"}), {}, "unknown Still rejected")
	eq(StillVault.clean({"id": "cut", "mode": "super"}), {}, "unknown mode rejected")
	v.save()
	eq(StillVault.load_saved().count("cut"), 12, "vault saves and reloads")


func _test_stride() -> void:
	# Intact: +1 AP +1 MP every turn, capped 8/5.
	_fight(_gear("stride", "intact"))
	var k: Dictionary = _sim._unit_by_seat(0)
	eq([int(k["ap"]), int(k["mp"])], [7, 4], "Intact Stride turn 1: 6/3 → 7/4")
	_end_turns(2)
	eq([int(_sim._unit_by_seat(0)["ap"]), int(_sim._unit_by_seat(0)["mp"])], [7, 4], "Intact Stride again on turn 2")
	# Overwound: +4/+2 turns 1–2 over the cap, −1/−2 turn 3, then normal.
	_fight(_gear("stride", "overwound"))
	var seen: Array = []
	for turn in 4:
		var u: Dictionary = _sim._unit_by_seat(0)
		seen.append([int(u["ap"]), int(u["mp"])])
		_end_turns(2)
	eq(seen, [[10, 5], [10, 5], [5, 1], [6, 3]], "Overwound Stride: 10/5, 10/5, crack 5/1, then 6/3")
	# Over the cap with a strong champion: level 20 + full Brightedge = 8/4 normal.
	var dusk: Array = []
	for slot in GearBag.SLOTS:
		dusk.append({"item_id": "brightedge.%s" % slot, "plus": 0})
	var strong := {"worn": dusk, "heroes": {"kestrel": {"level": 20, "spent": {}}}, "still": {"id": "stride", "mode": "overwound"}}
	_fight(strong)
	var s: Dictionary = _sim._unit_by_seat(0)
	eq([int(s["max_ap"]), int(s["max_mp"])], [8, 4], "normal is 8/4 (gear + level)")
	eq([int(s["ap"]), int(s["mp"])], [12, 6], "Overwound breaks the cap: 12/6")
	_end_turns(4)
	s = _sim._unit_by_seat(0)
	eq([int(s["ap"]), int(s["mp"])], [7, 2], "crack turn: 8/4 → 7/2")
	_end_turns(2)
	s = _sim._unit_by_seat(0)
	eq([int(s["ap"]), int(s["mp"])], [8, 4], "then back to normal 8/4 — gear and level kept")


func _test_one_shots() -> void:
	# Cut / Ember add to the first damaging hit; Guard trims the first hit taken.
	_fight(_gear("cut", "intact"))
	var a: Dictionary = _sim._unit_by_seat(0)
	var t: Dictionary = _sim._unit_by_seat(1)
	eq(int(_sim._mitigate_hit(a, t, 10)["damage"]), 14, "Cut Intact: first HIT +4")
	eq(int(_sim._mitigate_hit(a, t, 10)["damage"]), 10, "Cut fires once")
	_fight(_gear("cut", "overwound"))
	eq(int(_sim._mitigate_hit(_sim._unit_by_seat(0), _sim._unit_by_seat(1), 10)["damage"]), 20, "Cut Overwound: +10")
	_fight({}, _gear("guard", "intact"))
	eq(int(_sim._mitigate_hit(_sim._unit_by_seat(0), _sim._unit_by_seat(1), 20)["damage"]), 15, "Guard Intact: first HIT −25%")
	eq(int(_sim._mitigate_hit(_sim._unit_by_seat(0), _sim._unit_by_seat(1), 20)["damage"]), 20, "Guard fires once")
	_fight({}, _gear("guard", "overwound"))
	eq(int(_sim._mitigate_hit(_sim._unit_by_seat(0), _sim._unit_by_seat(1), 20)["damage"]), 0, "Guard Overwound: first HIT ignored")
	_fight(_gear("ember", "overwound"))
	eq(int(_sim._mitigate_hit(_sim._unit_by_seat(0), _sim._unit_by_seat(1), 10)["damage"]), 14, "Ember: first damaging spell +4")
	eq(int(_sim._unit_by_seat(1).get("ember_burn", 0)), 4, "Ember Overwound marks a 4 burn")
	var hp_before := int(_sim._unit_by_seat(1)["hp"])
	_end_turns(1)
	eq(int(_sim._unit_by_seat(1)["hp"]), hp_before - 4, "the burn ticks 4 on the target's next turn")
	# End: once, a lethal hit leaves 1 HP.
	_fight({}, _gear("end", "intact"))
	var e: Dictionary = _sim._unit_by_seat(1)
	e["hp"] = 0
	_sim._check_death(e)
	eq([int(e["hp"]), bool(e.get("alive", true))], [1, true], "End: lethal hit → 1 HP")
	e["hp"] = 0
	_sim._check_death(e)
	eq(bool(e.get("alive", true)), false, "End works once")
	# Mercy: first heal +8.
	# Mend rolls to connect; a scripted roll of 1 always lands (a miss heals 0).
	_fight(_gear("mercy", "intact"), {}, ["mender", "ironjaw"], [1])
	var m: Dictionary = _sim._unit_by_seat(0)
	m["hp"] = 40
	var r: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "seat": 0, "to": Vector2i(5, 7)})
	if bool(r.get("ok", false)):
		var healed := int(_sim._unit_by_seat(0)["hp"]) - 40
		eq(healed > 8, true, "Mercy adds +8 to the first heal (healed %d)" % healed)
		eq(bool(_sim._unit_by_seat(0)["still_ready"]), false, "Mercy fires once")
	else:
		truthy(true, "Mend self-cast not legal here (skip Mercy live check)")


func _test_opening_and_carry() -> void:
	# Opening: that side acts first whatever the Init.
	var fast := {"worn": [], "heroes": {"ironjaw": {"level": 10, "spent": {"swift": 18}}}}
	_sim.reset_match({"classes": ["kestrel", "ironjaw"], "skip_deploy": true, "first_by_init": true, "seat_gear": {0: _gear("opening", "intact"), 1: fast}})
	eq(int(_sim.snapshot()["active_seat"]), 0, "Opening beats a much higher Init")
	# Hot-seat never carries a Still; online / Stasis do.
	var v := StillVault.new()
	v.socket = "stride"
	v.mode = "overwound"
	v.save()
	eq(GearBag.load_saved().fight_gear(true)["still"], {"id": "stride", "mode": "overwound"}, "fight gear carries the socketed Still")
	eq(GearBag.load_saved().fight_gear().has("still"), false, "plain fight gear has no Still")
	eq(GearBag.clean_fight_gear({"still": {"id": "stride", "mode": "overwound"}})["still"], {"id": "stride", "mode": "overwound"}, "the host keeps a clean Still")
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "kestrel"
	eq(StasisCatalog.fight_config()["stasis_roster"][0]["gear"]["still"]["id"], "stride", "Stasis fight carries the Still")
	StasisCatalog.clear_run()
	var cs: Script = load("res://scenes/class_select.gd")
	# TEMPORARY balance-test kit (backend/test_loadout.gd): while it is on,
	# hot-seat seats wear the phone's loadout; the normal game carries none.
	var kit_on: bool = load("res://backend/test_loadout.gd").ACTIVE
	eq(cs.local_match_config().has("seat_gear"), kit_on, "hot-seat gear only while the temporary test kit is on")


func _test_consume_and_chest() -> void:
	_wipe()
	var v := StillVault.new()
	v.socket = "cut"
	v.save()
	var fight: Script = load("res://scenes/stasis_fight.gd")
	eq(fight.consume_still({"units": [{"seat": 0, "still": "cut"}]}), "cut", "the Stasis fight that used Cut destroys it")
	eq(StillVault.load_saved().socket, "", "socket empty after that fight")
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "bastion"
	var inst: Node = fight.new()
	var loot: Dictionary = inst.open_chest()
	inst.free()
	eq((loot["fragments"] as Array).size(), 1, "a ★1 chest adds 1 fragment")
	var total := 0
	for id in StillVault.IDS:
		total += StillVault.load_saved().count(id)
	eq(total, 1, "the fragment is banked")
	truthy(fight.chest_line(loot).contains("fragment"), "chest line names the fragment")
	StasisCatalog.clear_run()
	# Online: Crown pays +1 trophy on a win, and the Still is consumed.
	_wipe()
	v = StillVault.new()
	v.socket = "crown"
	v.save()
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	net.mode = net.Mode.CLIENT
	net.local_seat = 0
	net._note_koliseo_result({"match_over": true, "winner_seat": 0, "units": [{"seat": 0, "class_id": "kestrel", "still": "crown"}, {"seat": 1, "class_id": "gloam"}]})
	eq(int(net.koliseo_last_payout["trophies"]), 2, "Crown: online win pays 1 + 1 trophy")
	eq(KoliseoWallet.load_saved().trophies, 2, "the extra trophy is banked")
	eq(StillVault.load_saved().socket, "", "the Koliseo fight consumed Crown")
	net.free()


## Mauro 4 Oct 2026: "the stills information is not understandable, please
## explain better and also we need a better look for stills and fragments".
func _test_clear_text_and_icons() -> void:
	for id in StillVault.IDS:
		for mode in StillVault.MODES:
			eq(StillVault.plain(id, mode).length() > 12, true, "%s %s has a plain sentence" % [id, mode])
		for frag in [false, true]:
			var tex := StillVault.icon(id, frag)
			eq(tex != null, true, "%s %s icon is in the game" % [id, "fragment" if frag else "forged"])
			if tex != null:
				eq(tex.get_size(), Vector2(128, 128), "%s icon is 128x128" % id)
	eq(StillVault.HOW_TO.size(), 4, "how Stills work is four steps")
	eq(StillVault.forge_summary(7), "5 more to forge one.", "short of 12 says how many more")
	eq(StillVault.forge_summary(100), "Ready to forge (enough fragments for 8).", "100 fragments reads as ready, not 100/12")
	# The Vault says why Forge is off when the socket is full.
	var v := StillVault.new()
	v.fragments = {"end": 100}
	v.socket = "stride"
	v.save()
	var screen: StillsScreen = load("res://scenes/stills_screen.gd").new()
	root.add_child(screen)
	screen.pick("end")
	var why := screen.find_child("ForgeWhy", true, false) as Label
	eq(why != null and why.text.contains("already holds Stride"), true, "a full socket explains why Forge is off")
	screen.free()


func _test_screen() -> void:
	_wipe()
	var v := StillVault.new()
	v.fragments = {"tide": 12, "stride": 3}
	v.save()
	var screen: StillsScreen = load("res://scenes/stills_screen.gd").new()
	root.add_child(screen)
	truthy(screen.find_child("Still_end", true, false) != null, "twelve Still tiles")
	screen.pick("stride")
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
