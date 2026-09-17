extends SceneTree

## Headless CombatSim checks for the Phase A locked slice.
## Run: godot --headless --path . -s res://tests/run_combat_tests.gd

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	var script := load("res://backend/combat_sim.gd")
	_sim = script.new()
	_run()
	print("Combat tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_reset_and_turn_order()
	_test_only_active_seat_acts()
	_test_chebyshev_not_manhattan()
	_test_face_costs_zero()
	_test_end_turn_refills()
	_test_illegal_cast_refunds()
	_test_miss_keeps_ap_no_engine()
	_test_strike_hit_and_impact()
	_test_back_facing_multiplier()
	_test_mark_shot_range_and_marks()
	_test_advance_impact_adjacency()
	_test_kestrel_cannot_advance()
	_test_hit_bands()
	_test_class_kits()
	_test_match_over()
	_test_crit_mult_held()
	_test_wind_mod_omitted()
	_test_legal_intents_empty_for_other_seat()
	_test_view_does_not_roll_or_own_hp()


func _test_reset_and_turn_order() -> void:
	var snap: Dictionary = _sim.reset_match({"seed": 1})
	eq(snap["active_seat"], 0, "Kestrel (seat 0) acts first")
	eq(snap["units"][0]["name"], "Kestrel", "seat 0 is Kestrel")
	eq(snap["units"][1]["name"], "Ironjaw", "seat 1 is Ironjaw")
	eq(snap["units"][0]["hp"], 80, "Kestrel starts at 80 HP")
	eq(snap["units"][1]["hp"], 80, "Ironjaw starts at 80 HP")
	eq(snap["units"][0]["ap"], 6, "Kestrel 6 AP")
	eq(snap["units"][0]["mp"], 3, "Kestrel 3 MP")
	eq(snap["crit_roll"], false, "crit roll off")
	eq(snap["gust"], false, "Gust off")
	eq(snap["momentum"], false, "Momentum off")
	truthy(snap["open_decisions"].has("A01"), "A01 listed as Open")


func _test_only_active_seat_acts() -> void:
	_sim.reset_match({"seed": 1})
	var result: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(result["illegal"], true, "Ironjaw cannot end Kestrel's turn")
	eq(result["reason"], "not_your_turn", "reject reason is not_your_turn")
	eq(_sim.snapshot()["active_seat"], 0, "seat unchanged after reject")


func _test_chebyshev_not_manhattan() -> void:
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "diagonal king-step is legal (Chebyshev 1)")
	eq(_unit(0)["mp"], 2, "diagonal costs 1 MP, not 2")
	eq(_unit(0)["pos"], Vector2i(3, 3), "Kestrel landed on (3,3)")
	result = _sim.submit({"type": "move", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "orthogonal Chebyshev 2 costs 2 MP")
	eq(_unit(0)["mp"], 0, "2 MP spent on a 2-tile orthogonal walk")
	result = _sim.submit({"type": "move", "to": Vector2i(5, 4)})
	eq(result["illegal"], true, "no MP left")


func _test_face_costs_zero() -> void:
	_sim.reset_match({"seed": 1})
	var ap: int = int(_unit(0)["ap"])
	var result: Dictionary = _sim.submit({"type": "face", "dir": "N"})
	eq(result["ok"], true, "face accepted")
	eq(_unit(0)["facing"], "N", "facing is N")
	eq(_unit(0)["ap"], ap, "face costs 0 AP")
	eq(_unit(0)["mp"], 3, "face costs 0 MP")


func _test_end_turn_refills() -> void:
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
	_sim.submit({"type": "move", "to": Vector2i(2, 0)})
	eq(_unit(0)["mp"], 1, "spent 2 MP")
	var result: Dictionary = _sim.submit({"type": "end_turn"})
	eq(result["ok"], true, "end turn ok")
	eq(_sim.snapshot()["active_seat"], 1, "Ironjaw becomes active")
	eq(_unit(1)["ap"], 6, "Ironjaw refills 6 AP")
	eq(_unit(1)["mp"], 3, "Ironjaw refills 3 MP")
	eq(_unit(0)["mp"], 1, "Kestrel leftover MP is not refilled until their next turn")
	_sim.submit({"type": "end_turn"})
	eq(_sim.snapshot()["active_seat"], 0, "back to Kestrel")
	eq(_unit(0)["ap"], 6, "Kestrel refills 6 AP on their turn start")
	eq(_unit(0)["mp"], 3, "Kestrel refills 3 MP on their turn start")


func _test_illegal_cast_refunds() -> void:
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(1, 0)})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(1, 0)})
	eq(result["illegal"], true, "Mark Shot range 1 is illegal")
	eq(result["reason"], "out_of_range", "out_of_range")
	eq(_unit(0)["ap"], 6, "illegal cast refunds AP")
	eq(_unit(1)["hp"], 80, "illegal cast deals no damage")
	result = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(1, 0)})
	eq(result["illegal"], true, "Kestrel Strike is not in kit")
	eq(result["reason"], "spell_not_in_kit", "spell_not_in_kit")
	eq(_unit(0)["ap"], 6, "wrong-kit cast refunds")


func _test_miss_keeps_ap_no_engine() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [91],
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(4, 2),
		"ironjaw_facing": "E",
	})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 2)})
	eq(result["ok"], true, "miss is a legal resolution")
	eq(_unit(1)["hp"], 80, "miss deals 0")
	eq(_unit(1)["marks"], 0, "miss grants no Marks")
	eq(_unit(0)["ap"], 4, "miss keeps the 2 AP spend")
	var events: Array = result["events"]
	eq(events[0]["type"], "miss", "miss event")
	eq(events[0]["engine_refunded"], true, "engine refund flag on miss")


func _test_strike_hit_and_impact() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "Strike connects")
	eq(_unit(0)["hp"], 64, "front Strike deals 16 Earth")
	eq(_unit(1)["impact"], 1, "+1 Impact on connect")
	eq(_unit(1)["ap"], 3, "Strike spends 3 AP")
	eq(result["events"][0]["crit_mult"], 1.0, "CritMult 1.0 on hit")


func _test_back_facing_multiplier() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "W",
		"ironjaw_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "back Strike connects")
	eq(_unit(0)["hp"], 61, "16 × 1.20 rounds to 19, 80-19=61")
	eq(result["events"][0]["back"], true, "back flag")
	approx(result["events"][0]["facing_mult"], 1.20, "facing 1.20")


func _test_mark_shot_range_and_marks() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [1, 1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(5, 0),
	})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(5, 0)})
	eq(result["ok"], true, "Mark Shot at range 5 is legal")
	eq(_unit(1)["hp"], 72, "8 Air on connect")
	eq(_unit(1)["marks"], 1, "Marks stored on the target (A01 provisional)")
	eq(result["events"][0]["hit_chance"], 75, "range 5 uses the 75% mid band")
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(6, 0),
	})
	result = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(6, 0)})
	eq(result["illegal"], true, "Mark Shot range 6 is illegal")
	eq(_unit(0)["ap"], 6, "range reject refunds")


func _test_advance_impact_adjacency() -> void:
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(3, 0),
		"ironjaw_pos": Vector2i(0, 0),
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 0)})
	eq(result["ok"], true, "Ironjaw Advance 2 tiles with no roll")
	eq(_unit(1)["pos"], Vector2i(2, 0), "dash landed")
	eq(_unit(1)["ap"], 5, "Advance spends 1 AP")
	eq(_unit(1)["mp"], 2, "Advance spends 1 MP")
	eq(_unit(1)["impact"], 1, "ending Chebyshev 1 to Kestrel grants Impact")
	eq(_unit(0)["impact"], 0, "Kestrel never gains Impact")
	eq(result["events"][0]["rolled"], false, "Advance never rolls")
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(0, 0),
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 0)})
	eq(_unit(1)["impact"], 0, "Advance far from enemy grants no Impact")
	eq(_unit(0)["impact"], 0, "Kestrel still has 0 Impact")


func _test_kestrel_cannot_advance() -> void:
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(3, 0),
	})
	eq(_unit(0)["spells"].has("advance"), false, "Kestrel kit does not include Advance")
	eq(_unit(1)["spells"].has("advance"), true, "Ironjaw kit includes Advance")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 0)})
	eq(result["illegal"], true, "Kestrel Advance is rejected")
	eq(result["reason"], "spell_not_in_kit", "reject reason is spell_not_in_kit")
	eq(_unit(0)["pos"], Vector2i(0, 0), "Kestrel did not dash")
	eq(_unit(0)["ap"], 6, "Kestrel Advance refunds AP")
	eq(_unit(0)["mp"], 3, "Kestrel Advance refunds MP")
	eq(_unit(0)["impact"], 0, "Kestrel never gains Impact")
	for intent in _sim.legal_intents(0):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == "advance":
			fail("Kestrel legal_intents must not include advance")
			return
	_sim.submit({"type": "end_turn"})
	var found_advance := false
	for intent in _sim.legal_intents(1):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == "advance":
			found_advance = true
			break
	truthy(found_advance, "Ironjaw legal_intents include Advance")


func _test_hit_bands() -> void:
	eq(_sim.hit_chance(1), 90, "melee 90%")
	eq(_sim.hit_chance(2), 80, "short 80%")
	eq(_sim.hit_chance(3), 80, "short 80% at 3")
	eq(_sim.hit_chance(4), 75, "mid 75% at 4")
	eq(_sim.hit_chance(5), 75, "mid 75% at 5")
	eq(_sim.hit_chance(6), 70, "long 70% at 6")
	eq(_sim.hit_chance(8), 70, "long 70% at 8")


func _test_class_kits() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
	})
	eq(_unit(0)["spells"], ["mark_shot"], "Kestrel kit is Mark Shot only")
	eq(_unit(1)["spells"], ["advance", "strike"], "Ironjaw kit is Advance + Strike")
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(0, 0)})
	eq(result["illegal"], true, "Ironjaw cannot Mark Shot")
	eq(_unit(1)["ap"], 6, "Ironjaw Mark Shot refunds")


func _test_match_over() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [1, 1, 1, 1, 1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
	})
	# Two front Strikes = 32. Drive HP down by repeating turns.
	_unit_set_hp_via_hits()
	truthy(_sim.snapshot()["match_over"], "match ends when a seat has no living units")
	eq(_sim.snapshot()["winner_seat"], 1, "Ironjaw wins")
	var result: Dictionary = _sim.submit({"type": "end_turn"})
	eq(result["illegal"], true, "no actions after match_over")
	eq(_sim.legal_intents(1).size(), 0, "legal_intents empty after match")


func _unit_set_hp_via_hits() -> void:
	# Strike is 16; 5 connects kill 80 HP. Alternate turns: Ironjaw strikes, Kestrel ends.
	for i in range(5):
		if _sim.snapshot()["match_over"]:
			return
		if int(_sim.snapshot()["active_seat"]) == 0:
			_sim.submit({"type": "end_turn"})
		var kestrel: Dictionary = _unit(0)
		var result: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": kestrel["pos"]})
		if result.get("illegal", false):
			fail("expected legal Strike, got %s" % result.get("reason", ""))
			return
		if _sim.snapshot()["match_over"]:
			return
		_sim.submit({"type": "end_turn"})
		_sim.submit({"type": "end_turn"})


func _test_crit_mult_held() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
	})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(2, 0)})
	eq(result["events"][0]["crit_mult"], 1.0, "CritMult stays 1.0 even on a connect")
	eq(_sim.snapshot()["crit_mult"], 1.0, "snapshot exposes CritMult 1.0")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")


func _test_wind_mod_omitted() -> void:
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("WIND_MOD"), false, "CombatSim has no WIND_MOD constant")
	eq(sim_src.contains("wind_mod"), false, "CombatSim has no wind_mod term")
	eq(sim_src.contains("* WindMod"), false, "CombatSim does not multiply by WindMod")
	var hit_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(hit_src.contains("* facing_mult"), "damage still multiplies by facing")
	eq(hit_src.contains("* facing_mult *"), false, "facing is the last damage multiplier")


func _test_legal_intents_empty_for_other_seat() -> void:
	_sim.reset_match({"seed": 1})
	eq(_sim.legal_intents(1).size(), 0, "Ironjaw has no legal intents on Kestrel's turn")
	truthy(_sim.legal_intents(0).size() > 0, "Kestrel has legal intents")
	var types := {}
	for intent in _sim.legal_intents(0):
		types[str(intent["type"])] = true
	truthy(types.has("end_turn"), "end_turn is legal")
	truthy(types.has("move"), "move is legal")
	truthy(types.has("face"), "face is legal")
	truthy(types.has("cast"), "cast is legal")
	for intent in _sim.legal_intents(0):
		if str(intent.get("type", "")) == "cast":
			eq(str(intent.get("spell", "")), "mark_shot", "Kestrel legal casts are Mark Shot only")


func _test_view_does_not_roll_or_own_hp() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var pawn := FileAccess.get_file_as_string("res://units/pawn.gd")
	eq(view.contains("randi"), false, "board_view does not roll")
	eq(pawn.contains("randi"), false, "pawn does not roll")
	eq(view.contains("hp"), false, "board_view does not mention hp")


func _unit(seat: int) -> Dictionary:
	for unit in _sim.snapshot()["units"]:
		if int(unit["seat"]) == seat:
			return unit
	return {}


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func approx(actual: Variant, expected: float, msg: String) -> void:
	if abs(float(actual) - expected) > 0.001:
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


func fail(msg: String) -> void:
	_failed += 1
	print("FAIL: %s" % msg)
