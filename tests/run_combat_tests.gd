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
	_test_manhattan_walk_costs()
	_test_horizontal_first_paths()
	_test_client_path_ignored()
	_test_spell_range_stays_chebyshev()
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
	_test_hud_chrome_kit_gated()
	_test_handoff_timer_is_client_only()
	_test_advance_teleport_costs()
	_test_advance_manhattan_range_gate()
	_test_mark_shot_range_highlights()
	_test_turn_clock_auto_end_turn()
	_test_turn_clock_ticks_during_hops()


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
	eq(snap["walk"], "manhattan", "walk is Locked Manhattan")
	eq(snap["walk_tie_break"], "horizontal_first", "walk tie-break is horizontal-first")
	eq(snap["spell_range"], "chebyshev", "spell range stays Chebyshev")
	eq(snap["advance_mp"], "none", "Advance spends no MP")
	eq(snap["advance_ap"], 3, "Advance costs 3 AP")
	eq(snap["advance_range"], "manhattan", "Advance range gate is Locked Manhattan 1–2")
	eq(snap["advance_path"], "teleport", "Advance is a dest-click teleport")
	eq(snap["open_decisions"].has("A02"), false, "A02 walk is Locked, not Open")
	truthy(snap["open_decisions"].has("A01"), "A01 listed as Open")


func _test_only_active_seat_acts() -> void:
	_sim.reset_match({"seed": 1})
	var result: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(result["illegal"], true, "Ironjaw cannot end Kestrel's turn")
	eq(result["reason"], "not_your_turn", "reject reason is not_your_turn")
	eq(_sim.snapshot()["active_seat"], 0, "seat unchanged after reject")


func _test_manhattan_walk_costs() -> void:
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	eq(_sim.manhattan(Vector2i(2, 2), Vector2i(3, 3)), 2, "diagonal is Manhattan 2")
	eq(_sim.chebyshev(Vector2i(2, 2), Vector2i(3, 3)), 1, "same diagonal is Chebyshev 1")
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "diagonal dest-click is legal when Manhattan 2 <= 3 MP")
	eq(_unit(0)["mp"], 1, "diagonal costs 2 MP, not 1")
	eq(_unit(0)["pos"], Vector2i(3, 3), "Kestrel landed on (3,3)")
	eq(result["events"][0]["mp_spent"], 2, "move event spends 2 MP")
	result = _sim.submit({"type": "move", "to": Vector2i(5, 3)})
	eq(result["illegal"], true, "orthogonal Manhattan 2 with 1 MP left is illegal")
	eq(result["reason"], "insufficient_mp", "reject reason is insufficient_mp")
	eq(_unit(0)["pos"], Vector2i(3, 3), "pawn did not move")
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	result = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "3-tile orthogonal walk spends the full MP pool")
	eq(_unit(0)["mp"], 0, "Manhattan 3 costs 3 MP")
	eq(_unit(0)["pos"], Vector2i(5, 2), "Kestrel landed on (5,2)")
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
	result = _sim.submit({"type": "move", "to": Vector2i(2, 2)})
	eq(result["illegal"], true, "Manhattan 4 exceeds the 3 MP pool")
	eq(_unit(0)["pos"], Vector2i(0, 0), "over-budget dest-click is rejected")


func _test_horizontal_first_paths() -> void:
	eq(
		_sim.expand_ortho_path(Vector2i(2, 2), Vector2i(4, 3)),
		[Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)],
		"NE dest expands E then N/S (H-first)"
	)
	eq(
		_sim.expand_ortho_path(Vector2i(4, 3), Vector2i(2, 2)),
		[Vector2i(3, 3), Vector2i(2, 3), Vector2i(2, 2)],
		"SW dest expands W then N"
	)
	eq(
		_sim.expand_ortho_path(Vector2i(1, 4), Vector2i(1, 2)),
		[Vector2i(1, 3), Vector2i(1, 2)],
		"pure vertical stays N/S only"
	)
	eq(
		_sim.expand_ortho_path(Vector2i(3, 1), Vector2i(1, 1)),
		[Vector2i(2, 1), Vector2i(1, 1)],
		"pure horizontal stays E/W only"
	)
	eq(_sim.expand_ortho_path(Vector2i(2, 2), Vector2i(2, 2)), [], "same tile expands to empty path")
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "H-first Manhattan 3 walk is legal")
	eq(result["events"][0]["path"], [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)], "returned path is E then S")
	eq(_unit(0)["mp"], 0, "H-first 3-step walk spends 3 MP")
	# Occupant sits on the H-first corridor. V-first would work; Locked walk must refuse.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(1, 0)})
	result = _sim.submit({"type": "move", "to": Vector2i(1, 1)})
	eq(result["illegal"], true, "H-first path through Ironjaw is blocked")
	eq(result["reason"], "path_blocked", "blocked corridor reason is path_blocked")
	eq(_unit(0)["pos"], Vector2i(0, 0), "Kestrel stays put when H-first is blocked")
	var found_blocked_dest := false
	for intent in _sim.legal_intents(0):
		if str(intent.get("type", "")) == "move" and intent.get("to") == Vector2i(1, 1):
			found_blocked_dest = true
	eq(found_blocked_dest, false, "legal_intents omit dests whose H-first path is blocked")
	result = _sim.submit({"type": "move", "to": Vector2i(0, 2)})
	eq(result["ok"], true, "pure-vertical dest around the occupant is legal")
	eq(result["events"][0]["path"], [Vector2i(0, 1), Vector2i(0, 2)], "vertical path does not go east first")


func _test_client_path_ignored() -> void:
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	var forged: Array = [Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4)]
	var result: Dictionary = _sim.submit({
		"type": "move",
		"to": Vector2i(4, 3),
		"path": forged,
	})
	eq(result["ok"], true, "dest-click still accepted when a client path is supplied")
	eq(result["events"][0]["path"], [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)], "CombatSim path is H-first, not the client path")
	eq(result["events"][0]["path"] == forged, false, "forged vertical-first path is not used")
	eq(_unit(0)["pos"], Vector2i(4, 3), "unit ends on the dest-click tile")


func _test_spell_range_stays_chebyshev() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 2),
	})
	eq(_sim.chebyshev(Vector2i(0, 0), Vector2i(2, 2)), 2, "Mark Shot diagonal is Chebyshev 2")
	eq(_sim.manhattan(Vector2i(0, 0), Vector2i(2, 2)), 4, "same tiles are Manhattan 4")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(2, 2)})
	eq(result["ok"], true, "Mark Shot uses Chebyshev range, so Chebyshev 2 is legal")
	eq(_unit(1)["hp"], 72, "8 Air on connect at Chebyshev 2")
	eq(result["events"][0]["range"], 2, "hit event range is Chebyshev")
	# Strike / Mark Shot stay Chebyshev. Advance range is Manhattan (see range-gate test).
	eq(SpellKits.spell(SpellKits.MARK_SHOT).get("range_mode", ""), "chebyshev", "Mark Shot range_mode is Chebyshev")
	eq(SpellKits.spell(SpellKits.ADVANCE).get("range_mode", ""), "manhattan", "Advance range_mode is Manhattan")
	eq(SpellKits.spell(SpellKits.ADVANCE).get("mp_mode", ""), "none", "Advance mp_mode is none")
	eq(SpellKits.spell(SpellKits.ADVANCE).get("move_mode", ""), "teleport", "Advance move_mode is teleport")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["ap"]), 3, "Advance costs 3 AP")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["mp"]), 0, "Advance costs 0 MP")


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
	eq(_unit(1)["ap"], 3, "Advance spends 3 AP")
	eq(_unit(1)["mp"], 3, "Advance spends 0 MP")
	eq(_unit(1)["impact"], 1, "ending Chebyshev 1 to Kestrel grants Impact")
	eq(_unit(0)["impact"], 0, "Kestrel never gains Impact")
	eq(result["events"][0]["rolled"], false, "Advance never rolls")
	eq(result["events"][0]["teleport"], true, "Advance event is a teleport")
	eq(result["events"][0].has("path"), false, "Advance event has no hop path")
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


func _test_hud_chrome_kit_gated() -> void:
	_sim.reset_match({"seed": 1})
	var kestrel_offered: Array = CombatHUD.offered_cast_ids(_unit(0), _sim.legal_intents(0))
	eq(kestrel_offered, ["mark_shot"], "Kestrel HUD offers Mark Shot only")
	eq(kestrel_offered.has("advance"), false, "Kestrel HUD does not offer Advance")
	var kestrel_legal := CombatHUD.legal_cast_ids(_sim.legal_intents(0))
	eq(kestrel_legal.has("mark_shot"), true, "Kestrel legal_intents enable Mark Shot")
	eq(kestrel_legal.has("advance"), false, "Kestrel legal_intents do not enable Advance")
	_sim.submit({"type": "end_turn"})
	var ironjaw_offered: Array = CombatHUD.offered_cast_ids(_unit(1), _sim.legal_intents(1))
	eq(ironjaw_offered, ["advance", "strike"], "Ironjaw HUD offers Advance and Strike")
	eq(ironjaw_offered.has("mark_shot"), false, "Ironjaw HUD does not offer Mark Shot")
	var ironjaw_legal := CombatHUD.legal_cast_ids(_sim.legal_intents(1))
	eq(ironjaw_legal.has("advance"), true, "Ironjaw legal_intents enable Advance")
	var fake_kestrel_advance := _unit(0).duplicate(true)
	fake_kestrel_advance["spells"] = ["advance", "mark_shot"]
	fake_kestrel_advance["class_id"] = "kestrel"
	eq(CombatHUD.offered_cast_ids(fake_kestrel_advance), ["mark_shot"], "Advance chrome stays Ironjaw-only even if kit array is wrong")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud.contains("SpellKits.ADVANCE, SpellKits.STRIKE, SpellKits.MARK_SHOT"), false, "HUD does not hardcode both kits on one action bar")
	eq(hud.contains("WindMod"), false, "HUD has no WindMod chrome")
	eq(hud.contains("Detonate"), false, "HUD has no Detonate chrome")
	eq(hud.contains("Shoulder"), false, "HUD has no Shoulder chrome")
	eq(hud.contains("Crush"), false, "HUD has no Crush chrome")


func _test_handoff_timer_is_client_only() -> void:
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("HANDOFF_SEC"), false, "CombatSim has no handoff timer")
	eq(sim_src.contains("show_turn_banner"), false, "CombatSim does not own the turn banner")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("HANDOFF_SEC"), "board_view declares the Proposed handoff pause")
	truthy(view.contains("1.0"), "handoff pause is ~1.0s")
	eq(view.contains("intent.path"), true, "client documents that intent.path is not sent")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud.contains("show_turn_banner"), "HUD can show the End Turn banner")
	eq(hud.contains("WindMod"), false, "HUD still has no WindMod chrome")


func _test_advance_teleport_costs() -> void:
	# Diagonal neighbor: Chebyshev 1 / Manhattan 2 is in the diamond; teleport spends 3 AP / 0 MP.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(2, 2)})
	_sim.submit({"type": "end_turn"})
	eq(_sim.manhattan(Vector2i(2, 2), Vector2i(3, 3)), 2, "Advance diagonal neighbor is Manhattan 2")
	eq(_sim.chebyshev(Vector2i(2, 2), Vector2i(3, 3)), 1, "Advance diagonal neighbor is Chebyshev 1")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "diagonal Advance dest-click is legal")
	eq(_unit(1)["pos"], Vector2i(3, 3), "Ironjaw snapped diagonally")
	eq(_unit(1)["ap"], 3, "Advance spends 3 AP")
	eq(_unit(1)["mp"], 3, "Advance spends 0 MP")
	eq(result["events"][0]["mp_spent"], 0, "advance event spends 0 MP")
	eq(result["events"][0]["ap_spent"], 3, "advance event spends 3 AP")
	eq(result["events"][0]["teleport"], true, "Advance is a teleport snap")
	eq(result["events"][0].has("path"), false, "Advance event has no hop path")
	eq(result["events"][0]["rolled"], false, "Advance never rolls")
	truthy(str(result["events"][0]["coach"]).contains("3 AP"), "coach names the 3 AP spend")
	eq(str(result["events"][0]["coach"]).contains("MP"), false, "coach does not mention MP spend")

	# Chebyshev 2 diagonal is outside the Manhattan 1–2 diamond (Manhattan 4).
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(0, 0)})
	_sim.submit({"type": "end_turn"})
	eq(_sim.chebyshev(Vector2i(0, 0), Vector2i(2, 2)), 2, "two-tile diagonal is Chebyshev 2")
	eq(_sim.manhattan(Vector2i(0, 0), Vector2i(2, 2)), 4, "two-tile diagonal is Manhattan 4")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 2)})
	eq(result["illegal"], true, "Chebyshev-2 diagonal Advance is rejected as out of Manhattan range")
	eq(result["reason"], "out_of_range", "reject reason is out_of_range, not MP")
	eq(_unit(1)["pos"], Vector2i(0, 0), "Ironjaw did not dash")
	eq(_unit(1)["ap"], 6, "out-of-range refunds AP")
	eq(_unit(1)["mp"], 3, "out-of-range refunds MP")

	# Orthogonal 3 is out of Manhattan range.
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 0)})
	eq(result["illegal"], true, "Manhattan 3 is out of Advance range")
	eq(result["reason"], "out_of_range", "range reject, not MP")
	eq(_unit(1)["pos"], Vector2i(0, 0), "out-of-range dest does not move Ironjaw")

	# Client path is ignored; teleport snaps to dest.
	var forged: Array = [Vector2i(0, 1), Vector2i(1, 1)]
	result = _sim.submit({
		"type": "cast",
		"spell": "advance",
		"to": Vector2i(1, 1),
		"path": forged,
	})
	eq(result["ok"], true, "Advance dest-click still accepted when a client path is supplied")
	eq(result["events"][0].has("path"), false, "CombatSim does not return a hop path for Advance")
	eq(result["events"][0]["teleport"], true, "forged client path still resolves as teleport")
	eq(result["events"][0]["mp_spent"], 0, "(1,1) dest spends 0 MP")
	eq(_unit(1)["pos"], Vector2i(1, 1), "Ironjaw ends on the dest-click tile")
	eq(_unit(1)["mp"], 3, "MP pool unchanged after teleport")

	# Occupant on the old H-first corridor does not block a teleport.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(1, 0), "ironjaw_pos": Vector2i(0, 0)})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(1, 1)})
	eq(result["ok"], true, "teleport Advance past Kestrel is legal")
	eq(_unit(1)["pos"], Vector2i(1, 1), "Ironjaw snapped past the occupant")
	eq(_unit(1)["ap"], 3, "teleport past occupant still spends 3 AP")
	eq(_unit(1)["mp"], 3, "teleport past occupant spends 0 MP")
	eq(_unit(1)["impact"], 1, "landing Chebyshev-adjacent still grants Impact")

	# 0 MP remaining: walk the pool away, then Advance still works.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(2, 2)})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "Ironjaw can walk the 3 MP pool first")
	eq(_unit(1)["mp"], 0, "walk spent the MP pool")
	eq(_unit(1)["ap"], 6, "walk spends no AP")
	var found_diagonal := false
	var found_ortho := false
	for intent in _sim.legal_intents(1):
		if str(intent.get("type", "")) != "cast" or str(intent.get("spell", "")) != "advance":
			continue
		if intent.get("to") == Vector2i(6, 3):
			found_diagonal = true
		if intent.get("to") == Vector2i(6, 2):
			found_ortho = true
	truthy(found_diagonal, "0 MP can Advance to a diagonal neighbor")
	truthy(found_ortho, "0 MP can Advance to an orthogonal neighbor")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(6, 3)})
	eq(result["ok"], true, "diagonal Advance with 0 MP is legal")
	eq(_unit(1)["pos"], Vector2i(6, 3), "Ironjaw teleported on empty MP")
	eq(_unit(1)["mp"], 0, "Advance did not spend or refund MP")
	eq(_unit(1)["ap"], 3, "0-MP Advance still spends 3 AP")

	# Two Advances per turn (6 AP); a third is insufficient_ap.
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(6, 2)})
	eq(result["ok"], true, "second Advance spends the remaining 3 AP")
	eq(_unit(1)["ap"], 0, "two Advances empty the AP pool")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(6, 1)})
	eq(result["illegal"], true, "third Advance is rejected")
	eq(result["reason"], "insufficient_ap", "0 AP Advance is insufficient_ap")
	eq(_unit(1)["pos"], Vector2i(6, 2), "Ironjaw stays after the rejected third Advance")

	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	var resolve_idx := sim_src.find("func _resolve_advance")
	var rolling_idx := sim_src.find("func _resolve_rolling_cast")
	truthy(resolve_idx >= 0 and rolling_idx > resolve_idx, "_resolve_advance and _resolve_rolling_cast exist")
	var resolve_src := sim_src.substr(resolve_idx, rolling_idx - resolve_idx)
	eq(resolve_src.contains("expand_ortho_path"), false, "Advance resolve no longer expands an ortho hop path")
	eq(resolve_src.contains('actor["mp"]'), false, "Advance resolve does not touch MP")
	eq(sim_src.contains("Advance costs %d MP"), false, "Advance no longer has an MP-cost reject")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains('kind == "move" or kind == "advance"'), false, "board_view does not hop-play Advance")
	truthy(view.contains('== "move"'), "board_view still hop-plays walk")
	eq(view.contains("Detonate"), false, "teleport patch does not add Detonate")
	eq(view.contains("Shoulder"), false, "teleport patch does not add Shoulder")
	eq(view.contains("Crush"), false, "teleport patch does not add Crush")


func _test_advance_manhattan_range_gate() -> void:
	# Mauro's diamond around the caster (Manhattan 1–2):
	#   0 0 1 0 0
	#   0 1 1 1 0
	#   1 1 x 1 1
	#   0 1 1 1 0
	#   0 0 1 0 0
	var origin := Vector2i(3, 3)
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": origin})
	_sim.submit({"type": "end_turn"})
	var expected: Dictionary = {}
	for cell in [
		Vector2i(3, 2), Vector2i(3, 4), Vector2i(2, 3), Vector2i(4, 3),
		Vector2i(3, 1), Vector2i(3, 5), Vector2i(1, 3), Vector2i(5, 3),
		Vector2i(2, 2), Vector2i(2, 4), Vector2i(4, 2), Vector2i(4, 4),
	]:
		expected[cell] = true
	eq(expected.size(), 12, "Manhattan 1–2 diamond has 12 tiles")
	var offered: Dictionary = {}
	for intent in _sim.legal_intents(1):
		if str(intent.get("type", "")) != "cast" or str(intent.get("spell", "")) != "advance":
			continue
		offered[intent["to"]] = true
	eq(offered.size(), 12, "legal_intents Advance dests match the diamond when unobstructed")
	for cell in expected.keys():
		truthy(offered.has(cell), "diamond tile %s is offered" % str(cell))
	for cell in offered.keys():
		truthy(expected.has(cell), "no extra Advance dest %s outside the diamond" % str(cell))

	# Chebyshev 2 / Manhattan 3 "knight" tiles used to be in the square gate.
	eq(_sim.chebyshev(origin, Vector2i(4, 5)), 2, "(1,2) offset is Chebyshev 2")
	eq(_sim.manhattan(origin, Vector2i(4, 5)), 3, "(1,2) offset is Manhattan 3")
	eq(offered.has(Vector2i(4, 5)), false, "Chebyshev-2 knight tile is not offered")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 5)})
	eq(result["illegal"], true, "Manhattan 3 Advance dest is rejected")
	eq(result["reason"], "out_of_range", "knight tile reject is out_of_range")
	eq(_unit(1)["pos"], origin, "Ironjaw stays put on a diamond miss")
	eq(_unit(1)["ap"], 6, "diamond miss refunds AP")
	eq(_unit(1)["mp"], 3, "diamond miss refunds MP")

	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 5)})
	eq(result["illegal"], true, "Chebyshev-2 corner (Manhattan 4) is out of range")
	eq(result["reason"], "out_of_range", "corner reject is out_of_range")

	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "orthogonal Manhattan 2 is inside the diamond")
	eq(_unit(1)["pos"], Vector2i(5, 3), "Ironjaw snapped two tiles east")
	eq(_unit(1)["mp"], 3, "ortho 2 teleport spends 0 MP")
	eq(_unit(1)["ap"], 3, "Advance spends 3 AP")
	eq(result["events"][0]["teleport"], true, "east dest is a teleport snap")
	eq(result["events"][0].has("path"), false, "east dest has no hop path")

	# Highlights come from legal_intents; board_view paints Advance dests as "advance".
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("legal_intents"), "board highlights come from CombatSim legal_intents")
	truthy(view.contains('highlight := "advance"'), "Advance dests use advance highlight")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud.contains("range %d–%d Chebyshev"), false, "Advance selected label is not hardcoded Chebyshev")
	truthy(hud.contains("range %d–%d %s"), "selected label uses range_mode metric")
	truthy(hud.contains("Manhattan"), "HUD still names Manhattan range")
	eq(hud.contains("%d AP + Manhattan MP"), false, "HUD no longer advertises Manhattan MP for Advance")
	eq(hud.contains("%dAP + MP"), false, "HUD Advance button is not AP + MP")
	eq(hud.contains("Detonate"), false, "range patch does not add Detonate")
	eq(hud.contains("Shoulder"), false, "range patch does not add Shoulder")
	eq(hud.contains("Crush"), false, "range patch does not add Crush")


func _test_mark_shot_range_highlights() -> void:
	# Selecting Mark Shot must show the Chebyshev 2–5 ring, not only the enemy tile.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(3, 3), "ironjaw_pos": Vector2i(5, 3)})
	var origin := Vector2i(3, 3)
	var expected: Dictionary = {}
	for y in range(8):
		for x in range(8):
			var cell := Vector2i(x, y)
			if cell == origin:
				continue
			var dist := int(_sim.chebyshev(origin, cell))
			if dist >= 2 and dist <= 5:
				expected[cell] = true
	eq(expected.has(Vector2i(3, 4)), false, "Chebyshev 1 is outside Mark Shot range")
	eq(expected.has(Vector2i(5, 3)), true, "enemy at Chebyshev 2 is inside the ring")
	eq(expected.has(Vector2i(3, 0)), true, "Chebyshev 3 ortho is inside the ring")
	eq(_sim.chebyshev(origin, Vector2i(0, 0)), 3, "(0,0) is Chebyshev 3 from (3,3)")
	eq(expected.has(Vector2i(0, 0)), true, "Chebyshev 3 corner is inside the ring")
	eq(expected.has(Vector2i(3, 3)), false, "caster tile is not in the ring")

	var painted: Dictionary = {}
	for cell in _sim.range_highlight_cells(0, SpellKits.MARK_SHOT):
		painted[cell] = true
	eq(painted.size(), expected.size(), "range_highlight_cells matches Chebyshev 2–5")
	for cell in expected.keys():
		truthy(painted.has(cell), "Chebyshev ring tile %s is highlighted" % str(cell))
	for cell in painted.keys():
		truthy(expected.has(cell), "no extra Mark Shot chrome %s outside 2–5" % str(cell))

	# legal_intents still only offer the enemy dest, not every ring tile.
	var legal_dests := 0
	for intent in _sim.legal_intents(0):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == "mark_shot":
			legal_dests += 1
			eq(intent.get("to"), Vector2i(5, 3), "legal Mark Shot dest is the enemy")
	eq(legal_dests, 1, "legal_intents still only list the enemy, not the whole ring")

	# Ironjaw never gets Mark Shot range chrome.
	eq(_sim.range_highlight_cells(1, SpellKits.MARK_SHOT).size(), 0, "Ironjaw has no Mark Shot range chrome")
	# Walk tiles are a different set; the ring is not the walk diamond.
	var walk_dests := {}
	for intent in _sim.legal_intents(0):
		if str(intent.get("type", "")) == "move":
			walk_dests[intent["to"]] = true
	eq(walk_dests.has(Vector2i(3, 4)), true, "ortho neighbor is a walk dest")
	eq(painted.has(Vector2i(3, 4)), false, "walk neighbor is not in Mark Shot chrome")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
	var has_r5 := false
	var has_r6 := false
	var has_r1 := false
	for cell in _sim.range_highlight_cells(0, SpellKits.MARK_SHOT):
		var dist := int(_sim.chebyshev(Vector2i(0, 0), cell))
		if dist == 5:
			has_r5 = true
		if dist == 6:
			has_r6 = true
		if dist == 1:
			has_r1 = true
	truthy(has_r5, "Chebyshev 5 tiles are in Mark Shot chrome")
	eq(has_r6, false, "Chebyshev 6 is outside Mark Shot chrome")
	eq(has_r1, false, "Chebyshev 1 is outside Mark Shot chrome")

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("range_highlight_cells"), "board_view paints Mark Shot from range_highlight_cells")
	truthy(view.contains("SpellKits.MARK_SHOT"), "board_view special-cases Mark Shot range chrome")
	truthy(view.contains('set_highlight("range")'), "Mark Shot ring uses range highlight")
	truthy(view.contains("kind == \"move\" and spell_id == \"\""), "walk highlights stay off while a spell is selected")
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	truthy(tile_src.contains("\"range\""), "tiles have a range highlight color")
	eq(view.contains("Detonate"), false, "Mark Shot chrome does not add Detonate")
	eq(view.contains("Shoulder"), false, "Mark Shot chrome does not add Shoulder")
	eq(view.contains("Crush"), false, "Mark Shot chrome does not add Crush")


func _test_turn_clock_auto_end_turn() -> void:
	eq(TurnClock.DURATION_SEC, 30.0, "seat clock is 30s; change TurnClock.DURATION_SEC to retune")
	var clock := TurnClock.new()
	clock.start()
	eq(clock.display_seconds(), 30, "fresh clock shows 30")
	eq(clock.tick(0.0), false, "zero delta does not expire")
	eq(clock.tick(29.0), false, "29s elapsed is still the same seat")
	eq(clock.display_seconds(), 1, "ceil remaining shows 1s left")
	eq(clock.running, true, "clock still running before expiry")
	eq(clock.tick(1.0), true, "clock expires at 30s")
	eq(clock.display_seconds(), 0, "expired clock shows 0")
	eq(clock.running, false, "expired clock stops")
	eq(clock.tick(1.0), false, "already-expired clock does not fire again")
	clock.start()
	clock.pause()
	eq(clock.tick(30.0), false, "paused clock does not expire")
	eq(clock.display_seconds(), 30, "pause keeps the remaining 30s")
	clock.resume()
	eq(clock.tick(30.0), true, "resume then 30s expires")

	# Expiry must submit the same end_turn as the HUD button, not a second rule.
	_sim.reset_match({"seed": 1})
	eq(_sim.snapshot()["active_seat"], 0, "Kestrel starts")
	var result: Dictionary = _sim.submit({"type": "end_turn"})
	eq(result["ok"], true, "clock expiry uses the same end_turn submit")
	eq(_sim.snapshot()["active_seat"], 1, "end_turn on expiry hands the seat to Ironjaw")
	eq(_unit(1)["ap"], 6, "next seat refills AP after auto end-turn")
	eq(_unit(1)["mp"], 3, "next seat refills MP after auto end-turn")

	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("DURATION_SEC"), false, "CombatSim does not own the 30s clock")
	eq(sim_src.contains("TurnClock"), false, "CombatSim does not reference TurnClock")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("func _on_turn_clock_expired"), "board_view handles clock expiry")
	truthy(view.contains("_on_end_turn_button_pressed()"), "expiry calls the End Turn button path")
	truthy(view.contains("HANDOFF_SEC"), "seat-handoff banner is kept")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud.contains("set_turn_clock"), "HUD has a visible clock indicator")
	eq(hud.contains("Detonate"), false, "clock patch does not add Detonate")
	eq(hud.contains("Shoulder"), false, "clock patch does not add Shoulder")
	eq(hud.contains("Crush"), false, "clock patch does not add Crush")
	eq(hud.contains("WindMod"), false, "clock patch does not add WindMod")
	eq(sim_src.contains("WIND_MOD"), false, "CombatSim still has no WIND_MOD constant")
	eq(sim_src.contains("* WindMod"), false, "CombatSim still does not multiply by WindMod")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")


func _test_turn_clock_ticks_during_hops() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var process_idx := view.find("func _process")
	var sync_idx := view.find("func _sync_turn_clock")
	truthy(process_idx >= 0 and sync_idx > process_idx, "_process and _sync_turn_clock exist")
	var process_src := view.substr(process_idx, sync_idx - process_idx)
	truthy(process_src.contains("_turn_clock.tick(delta)"), "_process ticks the 30s clock")
	eq(process_src.contains("if _busy"), false, "_process does not freeze the clock while hop-busy")

	var play_idx := view.find("func _play_walk")
	var animate_idx := view.find("func _animate_path")
	truthy(play_idx >= 0 and animate_idx > play_idx, "_play_walk and _animate_path exist")
	var play_src := view.substr(play_idx, animate_idx - play_idx)
	eq(play_src.contains("_turn_clock.pause"), false, "walk hops do not pause the seat clock")
	eq(play_src.contains("_turn_clock.stop"), false, "walk hops do not stop the seat clock")
	truthy(view.contains("_clock_expired_pending"), "expiry during hops is deferred, not dropped")
	truthy(view.contains("_on_end_turn_button_pressed()"), "queued expiry still uses the End Turn path")
	eq(view.contains('kind == "move" or kind == "advance"'), false, "Advance teleport is not hop-played")
	truthy(view.contains("teleport"), "board_view documents Advance as a teleport snap")

	# Handoff banner may remain; pause() is reserved for that next-seat hold, not hops.
	var end_idx := view.find("func _on_end_turn_button_pressed")
	var expired_idx := view.find("func _on_turn_clock_expired")
	truthy(end_idx >= 0 and expired_idx > end_idx, "end-turn and expiry handlers exist")
	var end_src := view.substr(end_idx, expired_idx - end_idx)
	truthy(end_src.contains("_turn_clock.pause()"), "handoff still pauses so the next 30s does not drain during the banner")
	truthy(end_src.contains("_turn_clock.start()"), "next seat clock starts at 30s on End Turn")

	eq(view.contains("Detonate"), false, "clock hop patch does not add Detonate")
	eq(view.contains("Shoulder"), false, "clock hop patch does not add Shoulder")
	eq(view.contains("Crush"), false, "clock hop patch does not add Crush")


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
