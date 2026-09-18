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
	_test_walk_facing_follows_hops()
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
	_test_advance_then_remaining_mp_still_walks()
	_test_advance_manhattan_range_gate()
	_test_mark_shot_range_highlights()
	_test_turn_clock_auto_end_turn()
	_test_turn_clock_ticks_during_hops()
	_test_detonate_gates_and_damage()
	_test_detonate_miss_retains_marks()
	_test_shoulder_push_and_impact()
	_test_shoulder_push_blocked_open()
	_test_crush_spend_and_stun()
	_test_stun_suppresses_actions_open_a05()
	_test_legal_intents_new_spell_gates()
	_test_kit_class_exclusions()
	_test_aim_hit_preview()
	_test_legal_moves_after_advance()
	_test_walk_facing_follows_last_hop()
	_test_advance_facing_unchanged()
	_test_walk_mode_cancel()


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
	eq(snap["walk_facing"], "last_hop", "walk facing is Locked last-hop")
	eq(snap["spell_range"], "chebyshev", "spell range stays Chebyshev")
	eq(snap["advance_mp"], "none", "Advance spends no MP")
	eq(snap["advance_ap"], 3, "Advance costs 3 AP")
	eq(snap["advance_range"], "manhattan", "Advance range gate is Locked Manhattan 1–2")
	eq(snap["advance_path"], "teleport", "Advance is a dest-click teleport")
	eq(snap["open_decisions"].has("A02"), false, "A02 walk is Locked, not Open")
	eq(snap["open_decisions"].has("A01"), false, "A01 Marks-on-target is Locked, not Open")
	eq(snap["marks_owner"], "target", "A01 Locked: Marks live on the target")


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
	eq(_unit(0)["facing"], "S", "H-first diagonal (E then S) faces last hop S")
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
	eq(result["events"][0]["facing_hops"], ["E", "E", "S"], "H-first NE hop facing is E, E, then S")
	eq(result["events"][0]["facing"], "S", "final facing is the last hop")
	eq(_unit(0)["facing"], "S", "actor facing is last hop S")
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
	eq(result["events"][0]["facing_hops"], ["S", "S"], "pure-south hops face S then S")
	eq(_unit(0)["facing"], "S", "vertical walk ends facing last hop S")


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
	eq(result["events"][0]["facing"], "S", "facing follows CombatSim last hop, not forged last hop E")
	eq(_unit(0)["facing"], "S", "actor facing is H-first last hop S")
	eq(_unit(0)["pos"], Vector2i(4, 3), "unit ends on the dest-click tile")


func _test_walk_facing_follows_hops() -> void:
	# Locked: facing follows each ortho hop; final facing = last hop direction.
	# H-first means last cell step is the vertical remainder when both axes move.
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(3, 2)), "E", "east hop is E")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(1, 2)), "W", "west hop is W")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(2, 3)), "S", "south hop is S")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(2, 1)), "N", "north hop is N")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(3, 3)), "", "diagonal is not a hop facing")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "N"})
	eq(_unit(0)["facing"], "N", "Kestrel starts facing N")
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "pure-east walk is legal")
	eq(result["events"][0]["facing_from"], "N", "move event records facing before the walk")
	eq(result["events"][0]["facing_hops"], ["E", "E", "E"], "east hops face E each step")
	eq(result["events"][0]["facing"], "E", "pure-east final facing is E")
	eq(_unit(0)["facing"], "E", "actor facing is E after east walk")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
	result = _sim.submit({"type": "move", "to": Vector2i(0, 2)})
	eq(result["events"][0]["facing_hops"], ["W", "W"], "west hops face W")
	eq(_unit(0)["facing"], "W", "pure-west final facing is W")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
	result = _sim.submit({"type": "move", "to": Vector2i(2, 0)})
	eq(result["events"][0]["facing_hops"], ["N", "N"], "north hops face N")
	eq(_unit(0)["facing"], "N", "pure-north final facing is N")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "W"})
	result = _sim.submit({"type": "move", "to": Vector2i(4, 3)})
	eq(result["events"][0]["path"], [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)], "NE dest is H-first E then S")
	eq(result["events"][0]["facing_hops"], ["E", "E", "S"], "H-first NE faces E then S")
	eq(_unit(0)["facing"], "S", "H-first NE final facing is last hop S")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(4, 3), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
	result = _sim.submit({"type": "move", "to": Vector2i(2, 2)})
	eq(result["events"][0]["path"], [Vector2i(3, 3), Vector2i(2, 3), Vector2i(2, 2)], "SW dest is H-first W then N")
	eq(result["events"][0]["facing_hops"], ["W", "W", "N"], "H-first SW faces W then N")
	eq(_unit(0)["facing"], "N", "H-first SW final facing is last hop N")

	# Illegal walk does not rotate.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "S"})
	result = _sim.submit({"type": "move", "to": Vector2i(6, 2)})
	eq(result["illegal"], true, "Manhattan 4 is over budget")
	eq(_unit(0)["facing"], "S", "rejected walk leaves facing unchanged")
	eq(_unit(0)["pos"], Vector2i(2, 2), "rejected walk leaves the pawn put")

	# Manual face intent still turns in place after a walk.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
	_sim.submit({"type": "move", "to": Vector2i(4, 2)})
	eq(_unit(0)["facing"], "E", "east walk ends facing E")
	result = _sim.submit({"type": "face", "dir": "N"})
	eq(result["ok"], true, "manual face after a walk is legal")
	eq(_unit(0)["facing"], "N", "standing face overrides last-hop facing")
	eq(_unit(0)["pos"], Vector2i(4, 2), "manual face does not walk")
	eq(_unit(0)["mp"], 1, "manual face spends 0 MP")

	# Advance teleport does not auto-face.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(2, 2),
		"ironjaw_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["ok"], true, "Advance east teleport is legal")
	eq(_unit(1)["pos"], Vector2i(4, 2), "Advance snapped east")
	eq(_unit(1)["facing"], "W", "Advance teleport leaves facing unchanged")
	eq(result["events"][0].has("facing_hops"), false, "Advance event has no hop facing trail")

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("facing_from_step"), "walk hop playback applies CombatSim hop facing")
	eq(view.contains("do not invent auto-face"), false, "board_view does not keep the Open no-auto-face note")


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
	eq(_unit(0)["pos"], Vector2i(1, 1), "manual face is in-place (standing turn)")


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
	eq(_unit(1)["marks"], 1, "Marks stored on the target (A01 Locked)")
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
	eq(_unit(0)["spells"], ["mark_shot", "detonate"], "Kestrel kit is Mark Shot + Detonate")
	eq(_unit(1)["spells"], ["advance", "strike", "shoulder", "crush"], "Ironjaw kit is Advance + Strike + Shoulder + Crush")
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
			eq(str(intent.get("spell", "")), "mark_shot", "Kestrel legal casts at 0 Marks are Mark Shot only")


func _test_view_does_not_roll_or_own_hp() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var pawn := FileAccess.get_file_as_string("res://units/pawn.gd")
	eq(view.contains("randi"), false, "board_view does not roll")
	eq(pawn.contains("randi"), false, "pawn does not roll")
	eq(view.contains("hp"), false, "board_view does not mention hp")


func _test_hud_chrome_kit_gated() -> void:
	_sim.reset_match({"seed": 1})
	var kestrel_offered: Array = CombatHUD.offered_cast_ids(_unit(0), _sim.legal_intents(0))
	eq(kestrel_offered, ["mark_shot", "detonate"], "Kestrel HUD offers Mark Shot and Detonate")
	eq(kestrel_offered.has("advance"), false, "Kestrel HUD does not offer Advance")
	eq(kestrel_offered.has("shoulder"), false, "Kestrel HUD does not offer Shoulder")
	eq(kestrel_offered.has("crush"), false, "Kestrel HUD does not offer Crush")
	var kestrel_legal := CombatHUD.legal_cast_ids(_sim.legal_intents(0))
	eq(kestrel_legal.has("mark_shot"), true, "Kestrel legal_intents enable Mark Shot")
	eq(kestrel_legal.has("detonate"), false, "Detonate stays gated at 0 Marks")
	eq(kestrel_legal.has("advance"), false, "Kestrel legal_intents do not enable Advance")
	_sim.submit({"type": "end_turn"})
	var ironjaw_offered: Array = CombatHUD.offered_cast_ids(_unit(1), _sim.legal_intents(1))
	eq(ironjaw_offered, ["advance", "strike", "shoulder", "crush"], "Ironjaw HUD offers Advance, Strike, Shoulder, Crush")
	eq(ironjaw_offered.has("mark_shot"), false, "Ironjaw HUD does not offer Mark Shot")
	eq(ironjaw_offered.has("detonate"), false, "Ironjaw HUD does not offer Detonate")
	var ironjaw_legal := CombatHUD.legal_cast_ids(_sim.legal_intents(1))
	eq(ironjaw_legal.has("advance"), true, "Ironjaw legal_intents enable Advance")
	eq(ironjaw_legal.has("strike"), false, "Strike stays gated until range 1")
	eq(ironjaw_legal.has("crush"), false, "Crush stays gated at 0 Impact")
	var fake_kestrel_advance := _unit(0).duplicate(true)
	fake_kestrel_advance["spells"] = ["advance", "mark_shot", "detonate"]
	fake_kestrel_advance["class_id"] = "kestrel"
	eq(CombatHUD.offered_cast_ids(fake_kestrel_advance), ["mark_shot", "detonate"], "Advance chrome stays Ironjaw-only even if kit array is wrong")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud.contains("SpellKits.ADVANCE, SpellKits.STRIKE, SpellKits.MARK_SHOT"), false, "HUD does not hardcode both kits on one action bar")
	eq(hud.contains("WindMod"), false, "HUD has no WindMod chrome")
	# Names come from SpellKits at runtime; HUD source does not hardcode the new spell labels.
	eq(hud.contains("Detonate"), false, "HUD does not hardcode Detonate label")
	eq(hud.contains("Shoulder"), false, "HUD does not hardcode Shoulder label")
	eq(hud.contains("Crush"), false, "HUD does not hardcode Crush label")
	truthy(hud.contains("aim_hit_caption"), "HUD exposes Locked hit-percent aim chrome")
	truthy(hud.contains("HIT %d%%"), "HUD hit-percent caption uses Locked bands")
	truthy(hud.contains("engine_pips"), "HUD shows Marks/Impact as pips")


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
	eq(_unit(1)["facing"], "W", "diagonal Advance leaves default Face W unchanged")
	eq(result["events"][0].has("facing"), false, "Advance event does not auto-face")
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
	eq(resolve_src.contains("expand_ortho_path"), false, "Advance resolve does not hop-expand a path itself")
	eq(resolve_src.contains("last_hop_facing"), false, "Advance resolve does not auto-face from H-first hops")
	eq(resolve_src.contains('actor["facing"]'), false, "Advance resolve does not write facing")
	eq(resolve_src.contains('actor["mp"]'), false, "Advance resolve does not touch MP")
	eq(sim_src.contains("Advance costs %d MP"), false, "Advance no longer has an MP-cost reject")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains('kind == "move" or kind == "advance"'), false, "board_view does not hop-play Advance")
	truthy(view.contains('== "move"'), "board_view still hop-plays walk")
	eq(view.contains("Detonate"), false, "teleport patch does not add Detonate")
	eq(view.contains("Shoulder"), false, "teleport patch does not add Shoulder")
	eq(view.contains("Crush"), false, "teleport patch does not add Crush")


func _test_advance_then_remaining_mp_still_walks() -> void:
	# Advance is 3 AP / 0 MP teleport. leftover MP>0 must still offer at least one move.
	# legal_intents enumerates walks on mp>0 regardless of AP. submit must not zero MP.
	# Advance does not auto-face. The leftover walk then faces last hop (Locked).
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(2, 2),
		"ironjaw_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	eq(_unit(1)["ap"], 6, "Ironjaw starts the turn at 6 AP")
	eq(_unit(1)["mp"], 3, "Ironjaw starts the turn at 3 MP")
	eq(_unit(1)["facing"], "W", "Ironjaw starts facing W")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["ok"], true, "Ironjaw Advance teleport is legal")
	eq(_unit(1)["pos"], Vector2i(4, 2), "Advance snapped two tiles east")
	eq(_unit(1)["ap"], 3, "Advance spends 3 AP")
	eq(_unit(1)["mp"], 3, "submit Advance does not zero leftover MP")
	eq(result["events"][0]["mp_spent"], 0, "advance event mp_spent is 0")
	eq(result["events"][0]["ap_spent"], 3, "advance event ap_spent is 3")
	eq(_unit(1)["facing"], "W", "Advance teleport leaves facing unchanged")

	var move_count := 0
	var found_ortho := false
	for intent in _sim.legal_intents(1):
		if str(intent.get("type", "")) != "move":
			continue
		move_count += 1
		if intent.get("to") == Vector2i(5, 2):
			found_ortho = true
	truthy(move_count > 0, "after Advance with MP>0, legal_intents still includes a move")
	truthy(found_ortho, "after Advance, orthogonal neighbor is a walk dest")

	# Walk after Advance still spends leftover MP; facing follows the east hop.
	result = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "walk after Advance is legal")
	eq(_unit(1)["pos"], Vector2i(5, 2), "Ironjaw walked one tile east")
	eq(_unit(1)["mp"], 2, "walk spends 1 MP from leftover pool")
	eq(_unit(1)["ap"], 3, "walk spends no AP")
	eq(_unit(1)["facing"], "E", "walk after Advance faces last hop E")
	eq(result["events"][0]["facing_hops"], ["E"], "one-tile leftover walk is a single E hop")
	eq(result["events"][0]["facing_from"], "W", "leftover walk started from Advance facing W")

	# Two Advances empty AP; leftover MP still enumerates walks (mp-gated, not ap-gated).
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(2, 2),
		"ironjaw_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["ok"], true, "first Advance spends 3 AP")
	eq(_unit(1)["mp"], 3, "first Advance leaves MP at 3")
	eq(_unit(1)["facing"], "W", "first Advance still does not auto-face")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 4)})
	eq(result["ok"], true, "second Advance spends remaining AP")
	eq(_unit(1)["ap"], 0, "two Advances empty the AP pool")
	eq(_unit(1)["mp"], 3, "second Advance still does not zero MP")
	eq(_unit(1)["pos"], Vector2i(4, 4), "Ironjaw snapped after the second Advance")
	eq(_unit(1)["facing"], "W", "second Advance still leaves facing unchanged")
	eq(_has_legal_move(1), true, "at 0 AP with MP>0, legal_intents still includes a move")
	result = _sim.submit({"type": "move", "to": Vector2i(4, 5)})
	eq(result["ok"], true, "walk at 0 AP is legal when leftover MP remains")
	eq(_unit(1)["mp"], 2, "0-AP walk spends leftover MP")
	eq(_unit(1)["ap"], 0, "0-AP walk does not invent AP spend")
	eq(_unit(1)["facing"], "S", "0-AP leftover walk faces last hop S")

	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	var legal_idx := sim_src.find("func legal_intents")
	var range_idx := sim_src.find("func range_highlight_cells")
	truthy(legal_idx >= 0 and range_idx > legal_idx, "legal_intents and range_highlight_cells exist")
	var legal_src := sim_src.substr(legal_idx, range_idx - legal_idx)
	truthy(legal_src.contains("if mp > 0:"), "legal_intents enumerates walks when mp>0")
	eq(legal_src.contains("if ap > 0:"), false, "legal_intents does not gate walks on AP")
	truthy(legal_src.contains("regardless of remaining AP"), "legal_intents documents walks are mp-gated not ap-gated")
	var move_idx := sim_src.find("func _submit_move")
	var cast_idx := sim_src.find("func _submit_cast")
	truthy(move_idx >= 0 and cast_idx > move_idx, "_submit_move and _submit_cast exist")
	var move_src := sim_src.substr(move_idx, cast_idx - move_idx)
	truthy(move_src.contains('actor["facing"]'), "_submit_move sets facing from walk hops")
	truthy(move_src.contains("last hop"), "_submit_move documents last-hop facing")
	eq(move_src.contains("do not invent auto-face"), false, "walk last-hop facing is Locked, not Open")
	var resolve_idx := sim_src.find("func _resolve_advance")
	var rolling_idx := sim_src.find("func _resolve_rolling_cast")
	truthy(resolve_idx >= 0 and rolling_idx > resolve_idx, "_resolve_advance exists")
	var resolve_src := sim_src.substr(resolve_idx, rolling_idx - resolve_idx)
	eq(resolve_src.contains('actor["mp"]'), false, "Advance resolve still does not touch MP")
	eq(resolve_src.contains("actor[\"facing\"]"), false, "Advance resolve does not change facing")
	truthy(resolve_src.contains("Facing unchanged"), "Advance resolve documents no auto-face")


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
	truthy(view.contains("range_highlight_cells"), "board_view paints range rings from range_highlight_cells")
	truthy(view.contains('set_highlight("range")'), "enemy-spell ring uses range highlight")
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


func _test_detonate_gates_and_damage() -> void:
	eq(int(SpellKits.spell(SpellKits.DETONATE)["ap"]), 3, "Detonate costs 3 AP")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["mp"]), 0, "Detonate costs 0 MP")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["min_range"]), 1, "Detonate min range 1 Chebyshev")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["max_range"]), 6, "Detonate max range 6 Chebyshev")
	eq(str(SpellKits.spell(SpellKits.DETONATE).get("range_mode", "")), "chebyshev", "Detonate range is Chebyshev")

	# No Marks on the target: reject + refund. A01 Locked: Marks live on the target.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
	})
	eq(_unit(1)["marks"], 0, "Ironjaw starts with 0 Marks")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(2, 0)})
	eq(result["illegal"], true, "Detonate without Marks is illegal")
	eq(result["reason"], "insufficient_marks", "reject reason is insufficient_marks")
	eq(_unit(0)["ap"], 6, "Detonate gate refunds AP")
	eq(_unit(1)["hp"], 80, "Detonate gate deals no damage")
	eq(_unit(1)["marks"], 0, "Detonate gate does not invent Marks")

	# Range 7 is illegal even with Marks.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(7, 0),
		"ironjaw_marks": 2,
	})
	result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(7, 0)})
	eq(result["illegal"], true, "Detonate range 7 is illegal")
	eq(result["reason"], "out_of_range", "range 7 reject is out_of_range")
	eq(_unit(0)["ap"], 6, "out-of-range Detonate refunds")
	eq(_unit(1)["marks"], 2, "out-of-range does not consume Marks")

	# Range 1 with 1 Mark: 6+6*1 = 12 Air, consume Marks.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"ironjaw_facing": "W",
		"ironjaw_marks": 1,
	})
	eq(_sim.chebyshev(Vector2i(3, 3), Vector2i(4, 3)), 1, "adjacent is Chebyshev 1")
	result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "Detonate at range 1 with 1 Mark connects")
	eq(result["events"][0]["type"], "hit", "Detonate hit event")
	eq(result["events"][0]["base_damage"], 12, "Detonate base is 6+6*1")
	eq(result["events"][0]["damage"], 12, "front Detonate deals 12 Air")
	eq(result["events"][0]["marks_consumed"], 1, "connect consumes 1 Mark")
	eq(_unit(1)["marks"], 0, "A01: target Marks consumed on connect")
	eq(_unit(0)["marks"], 0, "caster Marks stay 0 (stack is on the target)")
	eq(_unit(1)["hp"], 68, "80-12=68")
	eq(_unit(0)["ap"], 3, "Detonate spends 3 AP")
	eq(_unit(0)["mp"], 3, "Detonate spends 0 MP")

	# 3 Marks: 6+18=24. 5 Marks: 6+30=36.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(6, 0),
		"ironjaw_facing": "W",
		"ironjaw_marks": 3,
	})
	eq(_sim.chebyshev(Vector2i(0, 0), Vector2i(6, 0)), 6, "range 6 is legal for Detonate")
	result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(6, 0)})
	eq(result["ok"], true, "Detonate at Chebyshev 6 is legal")
	eq(result["events"][0]["base_damage"], 24, "3 Marks → base 24")
	eq(result["events"][0]["damage"], 24, "front 24 Air")
	eq(result["events"][0]["hit_chance"], 70, "range 6 uses the 70% band")
	eq(_unit(1)["marks"], 0, "3 Marks consumed")
	eq(_unit(1)["hp"], 56, "80-24=56")

	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_facing": "E",
		"ironjaw_marks": 5,
	})
	result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(2, 0)})
	eq(result["events"][0]["base_damage"], 36, "5 Marks → base 36")
	eq(result["events"][0]["back"], true, "Detonate still applies facing")
	eq(result["events"][0]["damage"], 43, "36 × 1.20 rounds to 43")
	eq(_unit(1)["marks"], 0, "cap stack consumed")
	eq(_unit(1)["hp"], 37, "80-43=37")

	# Mark Shot then Detonate same turn: +1 Mark on target, then consume.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1, 1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_facing": "E",
	})
	result = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(2, 0)})
	eq(_unit(1)["marks"], 1, "Mark Shot writes Marks on the target")
	eq(_unit(0)["ap"], 4, "Mark Shot spent 2 AP")
	result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(2, 0)})
	eq(result["ok"], true, "same-turn Detonate after Mark Shot")
	eq(result["events"][0]["base_damage"], 12, "consumes the Mark just applied")
	eq(_unit(1)["marks"], 0, "same-turn consume clears the target stack")
	eq(_unit(0)["ap"], 1, "2+3 AP spent")


func _test_detonate_miss_retains_marks() -> void:
	_sim.reset_match({
		"seed": 1,
		"rolls": [100],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(3, 0),
		"ironjaw_marks": 4,
	})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(3, 0)})
	eq(result["ok"], true, "Detonate miss is a legal resolution")
	eq(result["events"][0]["type"], "miss", "miss event")
	eq(result["events"][0]["marks_retained"], true, "miss retains Marks")
	eq(result["events"][0]["marks_on_target"], 4, "miss event reports retained stack")
	eq(_unit(1)["marks"], 4, "A01: miss does not consume target Marks")
	eq(_unit(1)["hp"], 80, "miss deals 0")
	eq(_unit(0)["ap"], 3, "miss keeps the 3 AP spend")
	eq(_unit(0)["mp"], 3, "miss keeps the 0 MP spend")


func _test_shoulder_push_and_impact() -> void:
	eq(int(SpellKits.spell(SpellKits.SHOULDER)["ap"]), 2, "Shoulder costs 2 AP")
	eq(int(SpellKits.spell(SpellKits.SHOULDER)["mp"]), 0, "Shoulder costs 0 MP")
	eq(int(SpellKits.spell(SpellKits.SHOULDER)["min_range"]), 1, "Shoulder range 1")
	eq(int(SpellKits.spell(SpellKits.SHOULDER)["max_range"]), 1, "Shoulder range max 1")

	# Orthogonal push east: Ironjaw (3,3) → Kestrel (4,3) → (5,3).
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim.push_destination(Vector2i(3, 3), Vector2i(4, 3)), Vector2i(5, 3), "Chebyshev push is one cell away along the line")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "Shoulder connects")
	eq(result["events"][0]["type"], "hit", "Shoulder hit event")
	eq(result["events"][0]["damage"], 6, "front Shoulder deals 6 Earth")
	eq(result["events"][0]["engine_gained"], 1, "+1 Impact on connect")
	eq(result["events"][0]["pushed"], true, "Shoulder pushed the target")
	eq(result["events"][0]["push_to"], Vector2i(5, 3), "pushed one cell east")
	eq(result["events"][0]["push_blocked"], false, "empty in-bounds dest is not blocked")
	eq(_unit(0)["pos"], Vector2i(5, 3), "Kestrel landed one cell away")
	eq(_unit(0)["hp"], 74, "80-6=74")
	eq(_unit(1)["impact"], 1, "Shoulder grants Impact on connect")
	eq(_unit(1)["ap"], 4, "Shoulder spends 2 AP")
	eq(_unit(1)["mp"], 3, "Shoulder spends 0 MP")

	# Diagonal push.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 4),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim.chebyshev(Vector2i(3, 3), Vector2i(4, 4)), 1, "diagonal neighbor is range 1")
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 4)})
	eq(result["ok"], true, "diagonal Shoulder connects")
	eq(result["events"][0]["push_to"], Vector2i(5, 5), "diagonal push continues along the line")
	eq(_unit(0)["pos"], Vector2i(5, 5), "Kestrel moved diagonally away")

	# Miss: no push, no Impact, AP stays spent.
	_sim.reset_match({
		"seed": 1,
		"rolls": [100],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "Shoulder miss is legal")
	eq(result["events"][0]["type"], "miss", "Shoulder miss event")
	eq(result["events"][0]["pushed"], false, "miss does not push")
	eq(_unit(0)["pos"], Vector2i(4, 3), "miss leaves the target in place")
	eq(_unit(0)["hp"], 80, "miss deals 0")
	eq(_unit(1)["impact"], 0, "miss grants no Impact")
	eq(_unit(1)["ap"], 4, "miss keeps the 2 AP spend")

	# Range 2 is illegal.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(5, 3),
		"ironjaw_pos": Vector2i(3, 3),
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(5, 3)})
	eq(result["illegal"], true, "Shoulder range 2 is illegal")
	eq(result["reason"], "out_of_range", "Shoulder range reject")
	eq(_unit(1)["ap"], 6, "range reject refunds")


func _test_shoulder_push_blocked_open() -> void:
	# OPEN: push off-board — do not move; still deal damage/Impact; emit push_blocked.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"kestrel_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim.push_destination(Vector2i(1, 0), Vector2i(0, 0)), Vector2i(-1, 0), "west edge push is OOB")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(0, 0)})
	eq(result["ok"], true, "OOB push still resolves the hit")
	eq(_unit(0)["pos"], Vector2i(0, 0), "OPEN: OOB push does not move the target")
	eq(_unit(0)["hp"], 74, "OOB push still deals 6 Earth")
	eq(_unit(1)["impact"], 1, "OOB push still grants Impact")
	eq(result["events"][0]["push_blocked"], true, "hit records push_blocked")
	eq(result["events"][0]["push_block_reason"], "out_of_bounds", "block reason is out_of_bounds")
	eq(result["events"][1]["type"], "push_blocked", "OPEN event type is push_blocked")
	eq(result["events"][1]["reason"], "out_of_bounds", "push_blocked reason is out_of_bounds")
	truthy(str(result["events"][1].get("open", "")).contains("OPEN"), "push_blocked event is labeled OPEN")

	# OPEN: push into occupied — blockers are a test fixture, not a locked board feature.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"blockers": [Vector2i(5, 3)],
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "occupied push still resolves the hit")
	eq(_unit(0)["pos"], Vector2i(4, 3), "OPEN: occupied dest does not move the target")
	eq(_unit(0)["hp"], 74, "occupied push still deals damage")
	eq(_unit(1)["impact"], 1, "occupied push still grants Impact")
	eq(result["events"][1]["type"], "push_blocked", "occupied dest emits push_blocked")
	eq(result["events"][1]["reason"], "occupied", "block reason is occupied")
	truthy(str(result["events"][1].get("open", "")).contains("OPEN"), "occupied push_blocked is labeled OPEN")


func _test_crush_spend_and_stun() -> void:
	eq(int(SpellKits.spell(SpellKits.CRUSH)["ap"]), 4, "Crush costs 4 AP")
	eq(int(SpellKits.spell(SpellKits.CRUSH)["mp"]), 0, "Crush costs 0 MP")
	eq(int(SpellKits.spell(SpellKits.CRUSH)["base_damage"]), 24, "Crush base is 24 Earth")

	# Gate: fewer than 2 Impact rejects and refunds.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"ironjaw_impact": 1,
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	eq(result["illegal"], true, "Crush with 1 Impact is illegal")
	eq(result["reason"], "insufficient_impact", "reject reason is insufficient_impact")
	eq(_unit(1)["ap"], 6, "Crush gate refunds AP")
	eq(_unit(1)["impact"], 1, "Crush gate does not spend Impact")
	eq(_unit(0)["hp"], 80, "Crush gate deals no damage")

	# Connect at Impact 2: spend 2, 24 Earth, no Stun.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 2,
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "Crush at 2 Impact connects")
	eq(result["events"][0]["damage"], 24, "front Crush deals 24 Earth")
	eq(result["events"][0]["impact_before"], 2, "Impact before spend is 2")
	eq(result["events"][0]["impact_spent"], 2, "connect spends 2 Impact")
	eq(result["events"][0]["stun_applied"], 0, "Impact 2 before spend does not Stun")
	eq(_unit(1)["impact"], 0, "2-2=0 Impact left")
	eq(_unit(0)["hp"], 56, "80-24=56")
	eq(_unit(0)["stun_remaining"], 0, "no Stun stored")
	eq(_unit(1)["ap"], 2, "Crush spends 4 AP")
	eq(_unit(1)["mp"], 3, "Crush spends 0 MP")

	# Impact 3 before spend: spend 2, no Stun.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 3,
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	eq(result["events"][0]["stun_applied"], 0, "Impact 3 before spend does not Stun")
	eq(_unit(1)["impact"], 1, "3-2=1 Impact left")
	eq(_unit(0)["stun_remaining"], 0, "no Stun at Impact 3")

	# Impact 4 before spend: Stun 1 (OPEN A05).
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "W",
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "Crush at Impact 4 connects")
	eq(result["events"][0]["impact_before"], 4, "Impact was 4 before the spend")
	eq(result["events"][0]["impact_spent"], 2, "still spends 2")
	eq(result["events"][0]["stun_applied"], 1, "Stun 1 when Impact was 4 before spend")
	eq(result["events"][0]["open_a05_stun"], true, "Stun application labeled OPEN A05")
	eq(result["events"][0]["back"], true, "Crush still applies facing")
	eq(result["events"][0]["damage"], 29, "24 × 1.20 rounds to 29")
	eq(_unit(1)["impact"], 2, "4-2=2 Impact left")
	eq(_unit(0)["stun_remaining"], 1, "Stun 1 stored on the target")
	eq(result["events"][1]["type"], "status", "status event for Stun")
	eq(result["events"][1]["status"], "stun", "status id is stun")
	eq(result["events"][1]["remaining"], 1, "status remaining is 1")
	truthy(str(result["events"][1].get("open", "")).contains("A05"), "Stun status event labeled OPEN A05")

	# Miss retains Impact; no Stun.
	_sim.reset_match({
		"seed": 1,
		"rolls": [100],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "Crush miss is legal")
	eq(result["events"][0]["type"], "miss", "Crush miss event")
	eq(result["events"][0]["impact_retained"], true, "miss retains Impact")
	eq(_unit(1)["impact"], 4, "miss does not spend Impact")
	eq(_unit(0)["stun_remaining"], 0, "miss does not Stun")
	eq(_unit(0)["hp"], 80, "miss deals 0")
	eq(_unit(1)["ap"], 2, "miss keeps the 4 AP spend")


func _test_stun_suppresses_actions_open_a05() -> void:
	# OPEN A05: provisional suppress = casts/moves/face. end_turn allowed.
	# Decrement at start of the stunned unit's turn after setting stunned-this-turn.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 4,
		"ironjaw_marks": 1,
	})
	_sim.submit({"type": "end_turn"})
	_sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	eq(_unit(0)["stun_remaining"], 1, "Kestrel carries Stun 1 into the handoff")
	_sim.submit({"type": "end_turn"})
	eq(_sim.snapshot()["active_seat"], 0, "Kestrel's stunned turn starts")
	eq(_unit(0)["stunned"], true, "OPEN A05: stunned-this-turn is set at turn start")
	eq(_unit(0)["stun_remaining"], 0, "OPEN A05: remaining decremented at start after the flag")
	var legal: Array = _sim.legal_intents(0)
	eq(legal.size(), 1, "stunned legal_intents is end_turn only")
	eq(str(legal[0].get("type", "")), "end_turn", "only end_turn is offered while stunned")

	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 4)})
	eq(result["illegal"], true, "stunned move is rejected")
	eq(result["reason"], "stunned_cannot_act", "move reason is stunned_cannot_act")
	eq(_unit(0)["pos"], Vector2i(3, 3), "stunned unit did not walk")
	eq(_unit(0)["mp"], 3, "stunned move refunds")

	result = _sim.submit({"type": "face", "dir": "N"})
	eq(result["illegal"], true, "stunned face is rejected")
	eq(result["reason"], "stunned_cannot_act", "face reason is stunned_cannot_act")
	eq(_unit(0)["facing"], "E", "facing unchanged")

	result = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 3)})
	eq(result["illegal"], true, "stunned cast is rejected")
	eq(result["reason"], "stunned_cannot_act", "cast reason is stunned_cannot_act")
	eq(_unit(0)["ap"], 6, "stunned cast refunds")

	result = _sim.submit({"type": "end_turn"})
	eq(result["ok"], true, "end_turn is allowed while stunned")
	eq(_sim.snapshot()["active_seat"], 1, "stunned seat can hand off")
	_sim.submit({"type": "end_turn"})
	eq(_sim.snapshot()["active_seat"], 0, "Kestrel acts again after serving Stun 1")
	eq(_unit(0)["stunned"], false, "Stun 1 expired after one turn")
	eq(_unit(0)["stun_remaining"], 0, "no leftover stun_remaining")
	var types := {}
	for intent in _sim.legal_intents(0):
		types[str(intent["type"])] = true
	truthy(types.has("move"), "after Stun 1, walk is legal again")
	truthy(types.has("cast"), "after Stun 1, casts are legal again")
	truthy(types.has("face"), "after Stun 1, face is legal again")

	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(sim_src.contains("OPEN A05"), "CombatSim labels Stun as OPEN A05")
	truthy(sim_src.contains("stunned_cannot_act"), "CombatSim uses reserved reject stunned_cannot_act")


func _test_legal_intents_new_spell_gates() -> void:
	# Detonate appears only with 1+ Marks on the target and Chebyshev 1–6.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
	})
	eq(_has_legal_cast(0, "detonate"), false, "legal_intents omit Detonate at 0 Marks")
	eq(_has_legal_cast(0, "mark_shot"), true, "Mark Shot still offered at range 2")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_marks": 1,
	})
	eq(_has_legal_cast(0, "detonate"), true, "legal_intents include Detonate with 1 Mark in range")
	eq(_has_legal_cast(0, "mark_shot"), true, "Mark Shot still offered alongside Detonate")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"ironjaw_marks": 2,
	})
	eq(_has_legal_cast(0, "detonate"), true, "Detonate offered at Chebyshev 1")
	eq(_has_legal_cast(0, "mark_shot"), false, "Mark Shot still min-range 2")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(6, 0),
		"ironjaw_marks": 1,
	})
	eq(_has_legal_cast(0, "detonate"), true, "Detonate offered at Chebyshev 6")
	eq(_has_legal_cast(0, "mark_shot"), false, "Mark Shot max-range 5")

	# Shoulder at range 1; Crush only with 2+ Impact.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
	})
	_sim.submit({"type": "end_turn"})
	eq(_has_legal_cast(1, "shoulder"), true, "Shoulder offered at range 1")
	eq(_has_legal_cast(1, "strike"), true, "Strike offered at range 1")
	eq(_has_legal_cast(1, "crush"), false, "Crush omitted at 0 Impact")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"ironjaw_impact": 2,
	})
	_sim.submit({"type": "end_turn"})
	eq(_has_legal_cast(1, "crush"), true, "Crush offered with 2 Impact at range 1")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(6, 3),
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	eq(_has_legal_cast(1, "crush"), false, "Crush omitted when out of range even at 4 Impact")
	eq(_has_legal_cast(1, "shoulder"), false, "Shoulder omitted when out of range")

	# Range chrome for Detonate is Chebyshev 1–6. Hit-percent chrome is tested separately.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(3, 3), "ironjaw_pos": Vector2i(5, 3)})
	var painted: Dictionary = {}
	for cell in _sim.range_highlight_cells(0, SpellKits.DETONATE):
		painted[cell] = true
	eq(painted.has(Vector2i(3, 4)), true, "Chebyshev 1 is inside Detonate chrome")
	eq(painted.has(Vector2i(3, 3)), false, "caster tile is not in Detonate chrome")
	truthy(painted.has(Vector2i(0, 3)), "Chebyshev 3 ortho is inside Detonate chrome")
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
	var has_r6 := false
	var has_r7 := false
	var has_r1 := false
	for cell in _sim.range_highlight_cells(0, SpellKits.DETONATE):
		var d := int(_sim.chebyshev(Vector2i(0, 0), cell))
		if d == 6:
			has_r6 = true
		if d == 7:
			has_r7 = true
		if d == 1:
			has_r1 = true
	truthy(has_r1, "Detonate chrome includes Chebyshev 1")
	truthy(has_r6, "Detonate chrome includes Chebyshev 6")
	eq(has_r7, false, "Detonate chrome excludes Chebyshev 7")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("aim_hit_preview"), "board_view feeds Locked hit-percent preview")
	eq(view.contains("hit_chance"), false, "board_view does not call hit_chance itself")
	eq(view.contains("hit-%"), false, "board_view has no hardcoded hit-percent label")


func _test_kit_class_exclusions() -> void:
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"ironjaw_marks": 2,
		"ironjaw_impact": 4,
	})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(result["illegal"], true, "Kestrel cannot Shoulder")
	eq(result["reason"], "spell_not_in_kit", "Kestrel Shoulder is spell_not_in_kit")
	eq(_unit(0)["ap"], 6, "wrong-kit Shoulder refunds")
	result = _sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(4, 3)})
	eq(result["illegal"], true, "Kestrel cannot Crush")
	eq(result["reason"], "spell_not_in_kit", "Kestrel Crush is spell_not_in_kit")
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(3, 3)})
	eq(result["illegal"], true, "Ironjaw cannot Detonate")
	eq(result["reason"], "spell_not_in_kit", "Ironjaw Detonate is spell_not_in_kit")
	eq(_unit(1)["ap"], 6, "wrong-kit Detonate refunds")
	eq(_unit(1)["impact"], 4, "wrong-kit Detonate does not spend Impact")
	for intent in _sim.legal_intents(1):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == "detonate":
			fail("Ironjaw legal_intents must not include detonate")
			return

	# Locked slice still holds: Advance teleport, Walk Manhattan, crit off, WindMod omitted.
	eq(_sim.snapshot()["advance_path"], "teleport", "Advance stays teleport")
	eq(_sim.snapshot()["advance_ap"], 3, "Advance stays 3 AP")
	eq(_sim.snapshot()["advance_mp"], "none", "Advance stays 0 MP")
	eq(_sim.snapshot()["walk"], "manhattan", "Walk stays Manhattan")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("WIND_MOD"), false, "CombatSim still has no WIND_MOD constant")
	eq(sim_src.contains("wind_mod"), false, "CombatSim still has no wind_mod term")
	eq(sim_src.contains("* WindMod"), false, "CombatSim still does not multiply by WindMod")


func _test_aim_hit_preview() -> void:
	eq(CombatHUD.aim_hit_caption(90), "HIT 90%", "melee aim caption is HIT 90%")
	eq(CombatHUD.aim_hit_caption(80), "HIT 80%", "short aim caption is HIT 80%")
	eq(CombatHUD.aim_hit_caption(75), "HIT 75%", "mid aim caption is HIT 75%")
	eq(CombatHUD.aim_hit_caption(70), "HIT 70%", "long aim caption is HIT 70%")
	eq(CombatHUD.aim_hit_caption(-1), "", "hidden aim caption is empty")
	eq(CombatHUD.engine_pips(1, 5), "●○○○○", "A01 Marks pips show 1/5 on the target")
	eq(CombatHUD.engine_pips(4, 4), "●●●●", "Impact pips show a full stack")
	eq(_sim.hit_chance(1), 90, "Locked band 1 stays 90%")
	eq(_sim.hit_chance(3), 80, "Locked band 2–3 stays 80%")
	eq(_sim.hit_chance(5), 75, "Locked band 4–5 stays 75%")
	eq(_sim.hit_chance(5) == 80, false, "Mark Shot has no +5 longshot on the 4–5 band")
	eq(_sim.hit_chance(6), 70, "Locked band 6–8 stays 70%")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(5, 0)})
	var preview: Dictionary = _sim.aim_hit_preview(0, SpellKits.MARK_SHOT)
	eq(preview["show"], true, "Mark Shot in Chebyshev 5 shows hit percent")
	eq(preview["rolls"], true, "Mark Shot preview is a rolling cast")
	eq(preview["hit_chance"], 75, "Mark Shot range 5 previews Locked 75%")
	eq(preview.has("stun_telegraph"), false, "aim preview does not invent stun chrome")
	preview = _sim.aim_hit_preview(0, SpellKits.DETONATE)
	eq(preview["show"], true, "Detonate in Chebyshev 5 shows hit percent even without Marks")
	eq(preview["hit_chance"], 75, "Detonate range 5 previews Locked 75%")
	preview = _sim.aim_hit_preview(0, SpellKits.ADVANCE)
	eq(preview["show"], false, "Advance never shows hit percent")
	eq(preview["rolls"], false, "Advance preview is not a rolling cast")
	preview = _sim.aim_hit_preview(0, "")
	eq(preview["show"], false, "walk / empty spell has no hit percent")

	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(3, 3), "ironjaw_pos": Vector2i(4, 3)})
	_sim.submit({"type": "end_turn"})
	preview = _sim.aim_hit_preview(1, SpellKits.STRIKE)
	eq(preview["show"], true, "Strike in melee shows hit percent")
	eq(preview["hit_chance"], 90, "melee rolling casts preview Locked 90%")
	preview = _sim.aim_hit_preview(1, SpellKits.SHOULDER)
	eq(preview["show"], true, "Shoulder melee shows Locked hit percent")
	eq(preview["hit_chance"], 90, "Shoulder melee previews Locked 90%")
	preview = _sim.aim_hit_preview(1, SpellKits.CRUSH)
	eq(preview["show"], true, "Crush melee shows Locked hit percent")
	eq(preview["hit_chance"], 90, "Crush melee previews Locked 90%")
	preview = _sim.aim_hit_preview(1, SpellKits.ADVANCE)
	eq(preview["show"], false, "Advance still has no hit percent when adjacent")

	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud.contains("set_aim_preview"), "HUD can show pre-cast hit percent")
	eq(hud.contains("Detonate"), false, "aim chrome still does not hardcode Detonate")
	eq(hud.contains("WindMod"), false, "aim chrome does not add WindMod")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("_sync_aim_preview"), "board_view syncs Locked hit-percent aim preview")
	eq(view.contains("Detonate"), false, "aim chrome does not hardcode Detonate in the view")


func _test_legal_moves_after_advance() -> void:
	# Godot Engineer: after Advance (or any cast), remaining MP still offers
	# Manhattan walks — including 0 AP / 3 MP. Client clears spell + repaints
	# from legal_intents. Crit roll stays OFF; this patch does not invent Stun/push.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(3, 3)})
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")
	_sim.submit({"type": "end_turn"})
	eq(_unit(1)["ap"], 6, "Ironjaw starts at 6 AP")
	eq(_unit(1)["mp"], 3, "Ironjaw starts at 3 MP")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "first Advance spends 3 AP")
	eq(_unit(1)["ap"], 3, "3 AP remain after Advance")
	eq(_unit(1)["mp"], 3, "Advance spends 0 MP")
	eq(_unit(1)["pos"], Vector2i(5, 3), "Ironjaw snapped east 2")
	var moves := _legal_move_dests(1)
	truthy(moves.size() > 0, "after Advance, legal_intents still includes moves while MP>0")
	truthy(moves.has(Vector2i(6, 3)), "Manhattan 1 ortho walk is still offered")
	truthy(moves.has(Vector2i(5, 6)), "Manhattan 3 walk is still offered at 3 MP")
	eq(moves.has(Vector2i(5, 7)), false, "Manhattan 4 is still over the MP pool")

	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 5)})
	eq(result["ok"], true, "second Advance spends the remaining 3 AP")
	eq(_unit(1)["ap"], 0, "0 AP remain after two Advances")
	eq(_unit(1)["mp"], 3, "MP pool still full at 0 AP")
	eq(_has_legal_cast(1, "advance"), false, "0 AP Advance is not offered")
	moves = _legal_move_dests(1)
	truthy(moves.size() > 0, "0 AP / 3 MP still offers Manhattan walks")
	truthy(moves.has(Vector2i(6, 5)), "walk dest after 0 AP Advance is legal")
	result = _sim.submit({"type": "move", "to": Vector2i(6, 5)})
	eq(result["ok"], true, "walk after Advance is accepted")
	eq(_unit(1)["mp"], 2, "walk spends Manhattan MP after Advance")
	eq(_unit(1)["pos"], Vector2i(6, 5), "pawn walked after Advance")

	# Any dest-click cast, not only Advance: Strike spends AP, MP stays, walks remain.
	_sim.reset_match({
		"seed": 1,
		"rolls": [100, 100],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "Strike dest-click is a cast, not Advance")
	eq(_unit(1)["ap"], 3, "Strike spends 3 AP")
	eq(_unit(1)["mp"], 3, "Strike spends 0 MP")
	moves = _legal_move_dests(1)
	truthy(moves.has(Vector2i(3, 4)), "after Strike, Manhattan walks remain while MP>0")
	result = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(4, 3)})
	eq(_unit(1)["ap"], 0, "second Strike reaches 0 AP")
	eq(_unit(1)["mp"], 3, "MP still full at 0 AP after casts")
	moves = _legal_move_dests(1)
	truthy(moves.has(Vector2i(3, 4)), "0 AP / 3 MP after a non-Advance cast still offers Manhattan walks")
	result = _sim.submit({"type": "move", "to": Vector2i(3, 4)})
	eq(result["ok"], true, "walk after a rolling cast is accepted")

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var click_idx := view.find("func _handle_left_click")
	var face_idx := view.find("func _face_toward")
	truthy(click_idx >= 0 and face_idx > click_idx, "_handle_left_click exists")
	var click_src := view.substr(click_idx, face_idx - click_idx)
	eq(click_src.contains("if spell_id != SpellKits.ADVANCE:"), false, "cast dest-click is not Advance-gated for chrome clear")
	truthy(click_src.contains("_hud.clear_spell()"), "any dest-click cast clears spell selection")
	truthy(click_src.contains("_paint_highlights()"), "any dest-click cast repaints chrome from legal_intents")
	eq(view.contains("stun_remaining"), false, "walk-after-cast patch does not invent Stun")
	eq(view.contains("push_blocked"), false, "walk-after-cast patch does not invent push")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF after walk-after-cast checks")


func _test_walk_facing_follows_last_hop() -> void:
	# Godot Engineer Locked last-hop: each ortho hop faces that hop; final = last hop.
	# Client anim uses hop_facing per hop. Manual face intent stays for standing turns.
	eq(_sim.hop_facing(Vector2i(2, 2), Vector2i(3, 2)), "E", "east hop faces E")
	eq(_sim.hop_facing(Vector2i(2, 2), Vector2i(1, 2)), "W", "west hop faces W")
	eq(_sim.hop_facing(Vector2i(2, 2), Vector2i(2, 1)), "N", "north hop faces N")
	eq(_sim.hop_facing(Vector2i(2, 2), Vector2i(2, 3)), "S", "south hop faces S")
	eq(_sim.last_hop_facing(Vector2i(2, 2), Vector2i(4, 3), "N"), "S", "H-first NE last hop is S")
	eq(_sim.last_hop_facing(Vector2i(2, 2), Vector2i(1, 1), "E"), "N", "H-first SW last hop is N")
	eq(_sim.last_hop_facing(Vector2i(2, 2), Vector2i(2, 2), "W"), "W", "empty path keeps fallback facing")
	var path: Array = _sim.expand_ortho_path(Vector2i(2, 2), Vector2i(4, 1))
	eq(path, [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 1)], "H-first NE path is E, E, N")
	eq(_sim.hop_facing(Vector2i(2, 2), path[0]), "E", "hop 1 faces E")
	eq(_sim.hop_facing(path[0], path[1]), "E", "hop 2 faces E")
	eq(_sim.hop_facing(path[1], path[2]), "N", "hop 3 faces N — final face is last hop")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(2, 2),
		"kestrel_facing": "N",
		"ironjaw_pos": Vector2i(7, 7),
	})
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "pure east walk is legal")
	eq(_unit(0)["facing"], "E", "east walk faces E")
	eq(result["events"][0]["facing"], "E", "move event facing is E")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(2, 2),
		"kestrel_facing": "E",
		"ironjaw_pos": Vector2i(7, 7),
	})
	result = _sim.submit({"type": "move", "to": Vector2i(2, 0)})
	eq(_unit(0)["facing"], "N", "north walk faces N")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(2, 2),
		"kestrel_facing": "E",
		"ironjaw_pos": Vector2i(7, 7),
	})
	result = _sim.submit({"type": "move", "to": Vector2i(4, 1)})
	eq(result["events"][0]["path"], [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 1)], "H-first NE is E, E, N")
	eq(_unit(0)["facing"], "N", "multi-hop walk snapshot facing is last hop")
	eq(result["events"][0]["facing"], "N", "multi-hop move event facing is last hop")

	var ap_before: int = int(_unit(0)["ap"])
	var mp_before: int = int(_unit(0)["mp"])
	result = _sim.submit({"type": "face", "dir": "W"})
	eq(result["ok"], true, "in-place face remains legal after a walk")
	eq(_unit(0)["facing"], "W", "manual face still sets in-place facing")
	eq(_unit(0)["pos"], Vector2i(4, 1), "in-place face does not move")
	eq(_unit(0)["ap"], ap_before, "standing face costs 0 AP")
	eq(_unit(0)["mp"], mp_before, "standing face costs 0 MP")

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var anim_idx := view.find("func _animate_path")
	var set_cell_idx := view.find("func _set_pawn_cell")
	truthy(anim_idx >= 0 and set_cell_idx > anim_idx, "_animate_path exists")
	var anim_src := view.substr(anim_idx, set_cell_idx - anim_idx)
	truthy(anim_src.contains("hop_facing"), "walk anim faces each ortho hop")
	truthy(anim_src.contains("set_facing"), "walk anim updates pawn facing with hops")
	var pawn := FileAccess.get_file_as_string("res://units/pawn.gd")
	truthy(pawn.contains("func set_facing"), "pawn can update facing mid-hop")
	eq(view.contains("stun_remaining"), false, "last-hop face patch does not invent Stun")
	eq(view.contains("push_blocked"), false, "last-hop face patch does not invent push")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")


func _test_advance_facing_unchanged() -> void:
	# Locked: Advance teleport does not auto-face. Walk last-hop facing is separate.
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 4)})
	eq(result["ok"], true, "diagonal Advance dest-click is legal")
	eq(_unit(1)["pos"], Vector2i(4, 4), "Advance still snaps to dest")
	eq(_unit(1)["facing"], "W", "SE Advance leaves facing W unchanged")
	eq(result["events"][0].has("facing"), false, "Advance event does not set facing")
	eq(result["events"][0].has("path"), false, "Advance still emits no hop path")
	eq(result["events"][0]["teleport"], true, "Advance stays a teleport")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "S",
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(1, 3)})
	eq(_unit(1)["facing"], "S", "west Advance leaves facing S unchanged")
	eq(_unit(1)["pos"], Vector2i(1, 3), "west Advance snaps")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 1)})
	eq(_unit(1)["facing"], "E", "north Advance leaves facing E unchanged")

	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 2)})
	eq(_unit(1)["facing"], "E", "NW Advance leaves facing E unchanged")
	eq(result["events"][0].has("path"), false, "NW Advance still has no hop path")
	eq(result["events"][0].has("facing"), false, "NW Advance event has no facing field")

	result = _sim.submit({"type": "face", "dir": "N"})
	eq(result["ok"], true, "in-place face remains legal after Advance")
	eq(_unit(1)["facing"], "N", "manual face after Advance still works")
	eq(_unit(1)["pos"], Vector2i(2, 2), "manual face does not move")
	eq(_unit(1)["ap"], 3, "standing face after Advance costs 0 AP")

	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	var resolve_idx := sim_src.find("func _resolve_advance")
	var rolling_idx := sim_src.find("func _resolve_rolling_cast")
	var resolve_src := sim_src.substr(resolve_idx, rolling_idx - resolve_idx)
	eq(resolve_src.contains("last_hop_facing"), false, "Advance submit does not call last_hop_facing")
	eq(resolve_src.contains("hop_facing"), false, "Advance submit does not call hop_facing")
	eq(resolve_src.contains('actor["facing"]'), false, "Advance submit does not write actor facing")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains('kind == "move" or kind == "advance"'), false, "Advance teleport is not hop-played")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")
	eq(_sim.snapshot()["crit_mult"], 1.0, "CritMult stays 1.0")


func _test_walk_mode_cancel() -> void:
	# Walk is a dedicated mode, not only a default. After selecting Advance,
	# Walk / Esc returns to walk chrome without End Turn. Right-click stays face.
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(3, 3)})
	_sim.submit({"type": "end_turn"})
	var hud := CombatHUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(1))
	eq(hud.selected_spell(), "", "default mode is Walk")
	eq(hud.cancel_spell_selection(), false, "Esc is a no-op already in Walk")
	hud._on_spell_pressed("advance")
	eq(hud.selected_spell(), "advance", "Advance can be selected")
	eq(hud.cancel_spell_selection(), true, "Esc/cancel returns to Walk")
	eq(hud.selected_spell(), "", "after Esc, Walk mode")
	hud._on_spell_pressed("advance")
	eq(hud.selected_spell(), "advance", "Advance selected again")
	hud.select_walk()
	eq(hud.selected_spell(), "", "Walk button returns to Walk without End Turn")
	hud._on_spell_pressed("advance")
	hud._on_spell_pressed("advance")
	eq(hud.selected_spell(), "", "clicking Advance again also returns to Walk")
	hud.free()

	# Cast Advance then remaining MP walks (same contract as the sibling test).
	_sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(3, 3)})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "Advance dest-click resolves")
	eq(_unit(1)["ap"], 3, "3 AP remain")
	eq(_unit(1)["mp"], 3, "MP remains after Advance")
	var moves := _legal_move_dests(1)
	truthy(moves.has(Vector2i(6, 3)), "after Advance, legal_intents still include Manhattan walks")
	result = _sim.submit({"type": "move", "to": Vector2i(6, 3)})
	eq(result["ok"], true, "walk with remaining MP after Advance is accepted")

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains('text = "Walk"'), "HUD has a dedicated Walk button")
	truthy(hud_src.contains("func select_walk"), "HUD exposes Walk mode")
	truthy(hud_src.contains("ui_cancel"), "HUD Esc/ui_cancel clears spell selection")
	truthy(hud_src.contains("func cancel_spell_selection"), "cancel is spell-only")
	truthy(view.contains("ui_cancel"), "board_view Esc returns to Walk")
	truthy(view.contains("func _return_to_walk"), "Walk cancel does not require End Turn")
	var unhandled_idx := view.find("func _unhandled_input")
	var select_idx := view.find("func select_tile")
	truthy(unhandled_idx >= 0 and select_idx > unhandled_idx, "_unhandled_input exists")
	var unhandled := view.substr(unhandled_idx, select_idx - unhandled_idx)
	truthy(unhandled.contains("MOUSE_BUTTON_RIGHT"), "right-click is still handled")
	truthy(unhandled.contains("_face_toward"), "right-click still faces")
	truthy(unhandled.contains("_return_to_walk"), "Esc cancel is in the same input path")
	eq(unhandled.find("ui_cancel") < unhandled.find("_face_toward"), true, "Esc cancel does not steal right-click face")
	eq(hud_src.contains("Detonate"), false, "Walk-mode patch does not hardcode Detonate")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")


func _has_legal_cast(seat: int, spell_id: String) -> bool:
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == spell_id:
			return true
	return false


func _legal_move_dests(seat: int) -> Dictionary:
	var dests := {}
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "move" and intent.has("to"):
			dests[intent["to"]] = true
	return dests


func _has_legal_move(seat: int) -> bool:
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "move":
			return true
	return false


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
