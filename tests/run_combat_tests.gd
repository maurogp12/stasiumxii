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
	call_deferred("_finish_shade_board")


func _finish_shade_board() -> void:
	await _test_shade_markers_survive_rebuild()
	print("Combat tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_reset_and_turn_order()
	_test_live_deploy_starts_before_turn_1()
	_test_deploy_zone_sampler_rules()
	_test_deploy_zones_and_rejects()
	_test_deploy_occupied_and_reposition()
	_test_deploy_ready_gate_and_combat_intents()
	_test_both_ready_starts_combat()
	_test_kits_still_pass_after_deploy()
	_test_only_active_seat_acts()
	_test_manhattan_walk_costs()
	_test_horizontal_first_paths()
	_test_client_path_ignored()
	_test_snapshot_exposes_tiles()
	_test_phase_a_demo_map()
	_test_mud_walk_cost()
	_test_lava_impassable()
	_test_climb_reject()
	_test_downhill_free()
	_test_weighted_prefers_flat()
	_test_deploy_rejects_lava()
	_test_hit_bands_ignore_height()
	_test_advance_stand_on_gates()
	_test_noise_elevation_per_match()
	_test_walk_facing_follows_hops()
	_test_spell_range_stays_chebyshev()
	_test_face_costs_zero()
	_test_end_turn_refills()
	_test_illegal_cast_refunds()
	_test_ambush_destination_locked()
	_test_ambush_arms_at_zero_mp()
	_test_ambush_origin_chrome()
	_test_ambush_range_from_origin()
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
	_test_advance_cardinal_range_gate()
	_test_advance_chrome_follows_legal_intents()
	_test_mark_shot_range_highlights()
	_test_turn_clock_auto_end_turn()
	_test_turn_clock_ticks_during_hops()
	_test_detonate_gates_and_damage()
	_test_drop_shade_range()
	_test_detonate_miss_retains_marks()
	_test_shoulder_push_and_impact()
	_test_shoulder_bounce_stagger_locked()
	_test_shoulder_lava_burn_locked()
	_test_shoulder_push_blocked_locked()
	_test_crush_spend_and_stun()
	_test_stun_auto_end_turn_after_crush()
	_test_stun_suppresses_actions_locked()
	_test_stun_hud_greys_walk_face_spells()
	_test_push_blocked_client_toast_no_hop()
	_test_shoulder_impact_lava_burn_chrome()
	_test_legal_intents_new_spell_gates()
	_test_kit_class_exclusions()
	_test_aim_hit_preview()
	_test_hud_marks_and_impact_pips()
	_test_preview_cast()
	_test_legal_moves_after_advance()
	_test_walk_facing_follows_last_hop()
	_test_advance_facing_unchanged()
	_test_walk_mode_cancel()
	_test_spell_tooltip_cards()
	_test_action_bar_wraps()
	_test_face_pad_layout()
	_test_stun_skip_chrome()
	_test_playtest_warning_hush()
	_test_deploy_main_chrome()
	_test_aegis_break_burst()
	_test_snap_wall_bastion_turns()


func _test_reset_and_turn_order() -> void:
	var snap: Dictionary = _sim.reset_match({"seed": 1, "skip_deploy": true})
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
	eq(snap["walk"], "weighted", "walk is Locked weighted pathfinder")
	eq(snap["walk_cost"], "terrain_plus_elevation", "walk cost is terrain + elevation")
	eq(snap["walk_edges"], "ortho", "walk edges are ortho-only")
	eq(snap["walk_tie_break"], "cheapest_mp", "walk tie-break is cheapest MP")
	eq(snap["walk_facing"], "last_hop", "walk facing is Locked last-hop")
	eq(snap["max_climb"], 1, "max climb is Locked 1")
	eq(snap["max_drop"], 2, "max drop is Locked 2")
	eq(snap["terrain_mp"]["ground"], 1, "Ground MP is 1")
	eq(snap["terrain_mp"]["mud"], 2, "Mud MP is 2")
	eq(snap["terrain_mp"]["water"], 2, "Water MP is 2")
	eq(snap["terrain_mp"]["lava"], 0, "Lava MP stamp is 0 / impassable")
	eq(snap["open_elevation"], ["height_hit", "height_facing", "height_los", "stairs", "ramps", "flying"], "height hit/facing/LoS, stairs/ramps/flying stay Open")
	eq(str(snap["open_elevation"]).contains("advance_climb"), false, "Advance stand-on is Locked, not Open")
	truthy(str(snap["open_notes"]["elevation"]).contains("no height mods"), "elevation note keeps hit/facing/LoS unchanged")
	eq(snap.has("tiles"), true, "snapshot exposes tiles for Godot")
	eq(snap["board_size"], 15, "ship board is 15×15")
	eq(snap["demo_map"], "crosshaven_15", "skip_deploy seeds Crosshaven tags")
	eq(snap["elevation_gen"], "tags", "skip_deploy uses tag elevation")
	eq(snap["elev_seed"], 1, "elev_seed is stored on the snapshot")
	eq(snap["match_config"]["seed"], 1, "MatchConfig.seed is stored for replay")
	eq(snap["match_config"]["elev_seed"], 1, "MatchConfig.elev_seed is stored for replay")
	eq(snap["advance_stand_on"], "walk_gates", "Advance reuses walk stand-on gates")
	eq(snap["tiles"][Vector2i(0, 0)]["terrain_type"], "ground", "Crosshaven (0,0) is Ground")
	eq(snap["tiles"][Vector2i(0, 0)]["elevation"], 0, "Crosshaven (0,0) elevation is the tag")
	eq(snap["tiles"][Vector2i(0, 0)]["walkable"], true, "ruins paint_only does not block (0,0)")
	eq(typeof(snap["tiles"][Vector2i(0, 0)]["elevation"]), TYPE_INT, "snapshot elevation is int")
	eq(snap["tiles"].size(), 225, "snapshot lists all 15×15 tiles")
	eq(snap["paint_only"][Vector2i(0, 0)][0], "ruins", "paint_only is stored beside the walk tile")
	eq(snap["spell_range"], "chebyshev", "spell range stays Chebyshev")
	eq(snap["advance_mp"], "none", "Advance spends no MP")
	eq(snap["advance_ap"], 3, "Advance costs 3 AP")
	eq(snap["advance_range"], "cardinal_2", "Advance range gate is exactly 2 cardinal spaces")
	eq(snap["advance_path"], "teleport", "Advance is a dest-click teleport")
	eq(snap["open_decisions"].has("A02"), false, "A02 walk is Locked, not Open")
	eq(snap["open_decisions"].has("A01"), false, "A01 Marks-on-target is Locked, not Open")
	eq(snap["marks_owner"], "target", "A01 Locked: Marks live on the target")
	eq(snap["stun"], "locked_a_prime", "Stun suppress is Locked (A′)")
	eq(snap["stun_blocks"], "move_cast_face", "Locked Stun (A′) blocks move + cast + face")
	eq(snap["stun_auto_end_turn"], true, "Locked A′ auto end_turn on turn start")
	eq(snap["push"], "locked_shoulder", "Shoulder dest outcomes are Director Locked")
	eq(snap["push_occupied"], "push_blocked", "occupied dest stays push_blocked")
	eq(snap["push_unwalkable"], "bounce_stagger", "OOB / truly blocked still bounce + stagger")
	eq(snap["push_lava"], "displace_burn", "lava forced push displaces and burns")
	eq(snap["push_stagger_hp"], 4, "stagger is 4 HP")
	eq(snap["push_stagger_mp"], 1, "stagger is 1 MP when MP>=1")
	eq(snap["shoulder_impact_connect"], 1, "clean Shoulder connect is +1 Impact")
	eq(snap["shoulder_impact_bounce"], 2, "Shoulder bounce is +2 Impact")
	eq(snap["burn"], "locked", "Burn is Locked")
	eq(snap["burn_hp"], 4, "Burn tick is 4 HP")
	eq(snap["burn_duration"], 2, "Burn duration is 2")
	eq(snap["units"][0]["burn_remaining"], 0, "units start with no Burn")
	eq(snap["units"][1]["burn_remaining"], 0, "Ironjaw starts with no Burn")
	eq(snap["open_decisions"].has("A05"), true, "A05 Resist/rounding/WindMod stays Open")
	truthy(str(snap["open_notes"]["A05"]).contains("Locked Stun (A′)"), "A05 note labels Stun Locked (A′)")
	truthy(str(snap["open_notes"]["A05"]).contains("auto end_turn"), "A05 note documents A′ auto end_turn")
	truthy(str(snap["open_notes"]["A05"]).contains("Director Locked Shoulder"), "A05 note labels Director Locked Shoulder")
	eq(str(snap["open_notes"]["A05"]).contains("Exact suppress list not locked"), false, "A05 note does not leave the suppress list Open")
	eq(str(snap["open_notes"]["A05"]).contains("provisional"), false, "A05 note does not call Stun/Push provisional")
	truthy(str(snap["open_notes"]["A05"]).contains("Resist 0"), "A05 still notes Open Resist 0")
	eq(snap["deploy"], "locked", "deploy is Locked")
	eq(snap["phase"], "TURN_1", "skip_deploy starts in TURN_1")
	eq(snap["combat_enabled"], true, "skip_deploy enables combat")
	eq(snap["open_deploy"], ["fog", "hidden_enemy", "deploy_timer", "multi_unit"], "fog/timer/multi-unit stay Open")
	eq(snap["networking"], false, "networking stays OFF")
	eq(snap.has("turn_time_remaining"), true, "snapshot exposes turn_time_remaining")
	eq(snap.has("turn_time_limit"), true, "snapshot exposes turn_time_limit")
	eq(is_equal_approx(float(snap["turn_time_remaining"]), 30.0), true, "combat clock starts at 30s")
	eq(is_equal_approx(float(snap["turn_time_limit"]), 30.0), true, "turn_time_limit is 30s")
	eq(snap["turn_time_running"], true, "combat clock is running")
	eq(int(snap["turn_time_seconds"]), 30, "turn_time_seconds is ceil remaining")
	eq(snap["turn_timer"], "host", "clock authority stamp is host")
	eq(snap["units"][0]["pos"], Vector2i(1, 1), "skip_deploy fixture still uses (1,1)")
	eq(snap["units"][1]["pos"], Vector2i(6, 6), "skip_deploy fixture still uses (6,6)")


func _test_live_deploy_starts_before_turn_1() -> void:
	var snap: Dictionary = _sim.reset_match({"seed": 1})
	eq(snap["phase"], "DEPLOYMENT", "live reset starts in DEPLOYMENT")
	eq(snap["phase_name"], "DEPLOYMENT", "phase_name is DEPLOYMENT")
	eq(snap["turn_index"], 0, "Turn 1 has not started")
	eq(snap["combat_enabled"], false, "combat off until both ready")
	eq(snap["walk_enabled"], false, "walk off during deploy")
	eq(snap["end_turn_enabled"], false, "end_turn off during deploy")
	eq(snap["turn_time_running"], false, "deploy clock is stopped")
	eq(is_equal_approx(float(snap["turn_time_remaining"]), 0.0), true, "deploy remaining is 0")
	eq(is_equal_approx(float(snap["turn_time_limit"]), 30.0), true, "deploy still exposes turn_time_limit")
	eq(snap["positions_locked"], false, "positions are open")
	eq(snap["both_ready"], false, "neither seat is ready")
	eq(snap["ready"][0], false, "seat 0 ready flag starts false")
	eq(snap["ready"][1], false, "seat 1 ready flag starts false")
	eq(snap["deploy"], "locked", "live deploy flow is Locked")
	eq(snap["deploy_simultaneous"], true, "deploy is simultaneous")
	eq(snap["deploy_legal_cells"], "sampled_blob_6", "legal cells are sampled ~6-cell blobs")
	eq(snap["deploy_zone_split"], "seeded_random_blobs", "zones are seed-sampled blobs")
	eq(snap["deploy_zone_gen"], "proposed_random_blobs", "random blobs are Proposed, shipped live")
	eq(snap["deploy_blob_size"], 6, "each seat blob is 6 cells")
	eq(snap["deploy_min_chebyshev"], 3, "opening Chebyshev floor is 3")
	eq(snap["units"][0]["placed"], false, "Kestrel is not pre-spawned")
	eq(snap["units"][1]["placed"], false, "Ironjaw is not pre-spawned")
	eq(snap["units"][0]["pos"], Vector2i(-1, -1), "live path does not use (1,1)")
	eq(snap["units"][1]["pos"], Vector2i(-1, -1), "live path does not use (6,6)")
	eq(snap["units"][0]["ap"], 0, "AP stays 0 until combat")
	eq(snap["units"][0]["mp"], 0, "MP stays 0 until combat")
	eq(_sim.legal_intents(0).is_empty(), false, "seat 0 has place dests")
	var combat_kinds := {}
	for intent in _sim.legal_intents(0):
		combat_kinds[str(intent["type"])] = true
	eq(combat_kinds.has("move"), false, "no move intents during deploy")
	eq(combat_kinds.has("cast"), false, "no cast intents during deploy")
	eq(combat_kinds.has("face"), false, "no face intents during deploy")
	eq(combat_kinds.has("end_turn"), false, "no end_turn intents during deploy")
	eq(combat_kinds.has("place"), true, "place intents are offered")
	eq(combat_kinds.has("ready"), false, "ready is gated until placed")
	eq(_sim.can_ready(0), false, "can_ready is false before place")
	eq(_sim.can_ready(1), false, "can_ready is false before P2 place")


func _test_deploy_zone_sampler_rules() -> void:
	var flow_script = load("res://backend/match_flow.gd")
	var west: Array[Vector2i] = _rect_blob(Vector2i(0, 1), 2, 3)
	var west_south: Array[Vector2i] = _rect_blob(Vector2i(0, 5), 2, 3)
	var overlap: Array[Vector2i] = _rect_blob(Vector2i(1, 1), 2, 3)
	var too_close: Array[Vector2i] = _rect_blob(Vector2i(3, 1), 2, 3)
	var far_east: Array[Vector2i] = _rect_blob(Vector2i(5, 1), 2, 3)
	var exact_three: Array[Vector2i] = _rect_blob(Vector2i(4, 1), 2, 3)
	var interior_a: Array[Vector2i] = _rect_blob(Vector2i(1, 2), 2, 3)
	var interior_b: Array[Vector2i] = _rect_blob(Vector2i(5, 2), 2, 3)

	eq(flow_script.pair_reject_reason(west, overlap), "overlap", "overlapping blobs reject")
	eq(flow_script.pair_reject_reason(west, west_south), "same_edge", "same-edge camping rejects")
	eq(flow_script.pair_reject_reason(west, too_close), "min_chebyshev", "opening Chebyshev 2 rejects")
	eq(flow_script.min_chebyshev_between(west, too_close), 2, "west vs x=3 is Chebyshev 2")
	eq(flow_script.pair_reject_reason(west, exact_three), "", "opening Chebyshev 3 is legal")
	eq(flow_script.min_chebyshev_between(west, exact_three), 3, "west vs x=4 is Chebyshev 3")
	eq(flow_script.pair_reject_reason(interior_a, interior_b), "", "interior pair at Chebyshev 3 is legal")
	eq(flow_script.has_interior_cell(interior_a), true, "interior 2×3 is not border-only")
	eq(flow_script.is_contiguous_blob(interior_a), true, "2×3 rectangle is contiguous")
	eq(flow_script.is_filled_rect(interior_a), true, "2×3 is a filled rectangle")

	var first: Dictionary = flow_script.sample_zone_pair(11)
	var again: Dictionary = flow_script.sample_zone_pair(11)
	eq(first["zones"][0], again["zones"][0], "same seed reseeds seat 0")
	eq(first["zones"][1], again["zones"][1], "same seed reseeds seat 1")

	var saw_interior := false
	var saw_rect := false
	var saw_organic := false
	var saw_preferred := false
	for seed in range(1, 49):
		var sampled: Dictionary = flow_script.sample_zone_pair(seed)
		var blob_a: Array[Vector2i] = sampled["zones"][0]
		var blob_b: Array[Vector2i] = sampled["zones"][1]
		eq(blob_a.size(), 6, "seed %d seat 0 blob is 6 cells" % seed)
		eq(blob_b.size(), 6, "seed %d seat 1 blob is 6 cells" % seed)
		eq(flow_script.is_contiguous_blob(blob_a), true, "seed %d seat 0 is contiguous" % seed)
		eq(flow_script.is_contiguous_blob(blob_b), true, "seed %d seat 1 is contiguous" % seed)
		eq(flow_script.pair_reject_reason(blob_a, blob_b), "", "seed %d pair is legal" % seed)
		var distance: int = int(sampled["distance"])
		eq(distance >= 3, true, "seed %d opening Chebyshev is at least 3" % seed)
		if distance >= 4 and distance <= 6:
			saw_preferred = true
		if flow_script.has_interior_cell(blob_a) or flow_script.has_interior_cell(blob_b):
			saw_interior = true
		if flow_script.is_filled_rect(blob_a) or flow_script.is_filled_rect(blob_b):
			saw_rect = true
		if not flow_script.is_filled_rect(blob_a) or not flow_script.is_filled_rect(blob_b):
			saw_organic = true
	eq(saw_interior, true, "sampler can place interior cells")
	eq(saw_rect, true, "sampler can emit a 2×3 rectangle")
	eq(saw_organic, true, "sampler can emit an organic blob")
	eq(saw_preferred, true, "sampler prefers opening Chebyshev 4–6 when it can")

	_sim.reset_match({"seed": 1})
	eq(_sim.snapshot()["deploy_zone_distance"] >= 3, true, "live seed 1 opening is at least Chebyshev 3")
	eq(_sim.snapshot()["deploy_zone_gen"], "proposed_random_blobs", "live snap stamps Proposed blobs")


func _test_deploy_zones_and_rejects() -> void:
	_sim.reset_match({"seed": 1})
	eq(_sim.deploy_zone_cells(0).size(), 6, "seat 0 blob is 6 cells")
	eq(_sim.deploy_zone_cells(1).size(), 6, "seat 1 blob is 6 cells")
	eq(_sim.legal_deploy_cells(0).size(), _walkable_zone_count(0), "legal deploy omits lava")
	eq(_sim.legal_deploy_cells(1).size(), _walkable_zone_count(1), "legal deploy omits lava")
	eq(_sim.legal_deploy_cells(0).size() >= 1, true, "seed 1 seat 0 still has a placeable blob")
	eq(_sim.legal_deploy_cells(1).size() >= 1, true, "seed 1 seat 1 still has a placeable blob")

	var oob: Dictionary = _sim.place_unit(0, Vector2i(-1, 2))
	eq(oob["illegal"], true, "negative x is rejected")
	eq(oob["reason"], "out_of_bounds", "OOB reason is out_of_bounds")
	eq(_sim.place_unit(0, Vector2i(15, 2))["reason"], "out_of_bounds", "x=15 is out_of_bounds on the ship board")
	eq(_sim.place_unit(0, Vector2i(8, 2))["reason"] != "out_of_bounds", true, "x=8 is inside the 15×15 board")
	eq(_sim.place_unit(1, Vector2i(3, -1))["reason"], "out_of_bounds", "negative y is out_of_bounds")

	var outside: Vector2i = _unclaimed_cell()
	var other: Vector2i = _zone_cell(1, 0)
	var own: Vector2i = _zone_cell(0, 0)
	var miss: Dictionary = _sim.place_unit(0, outside)
	eq(miss["illegal"], true, "unclaimed cell is rejected")
	eq(miss["reason"], "outside_zone", "unclaimed reason is outside_zone")
	eq(_sim.can_place(0, other)["reason"], "outside_zone", "other seat blob is outside_zone")
	eq(_sim.can_place(1, own)["reason"], "outside_zone", "seat 1 cannot sit in seat 0's blob")
	eq(_sim.can_place(0, own)["ok"], true, "seat 0 may place in its blob")
	eq(_sim.can_place(1, other)["ok"], true, "seat 1 may place in its blob")
	eq(_unit(0)["placed"], false, "failed places leave Kestrel unplaced")

	var interior_seed := _seed_with_interior_zone()
	_sim.reset_match({"seed": interior_seed})
	var interior_seat := 0
	var interior_cell: Vector2i = _interior_zone_cell(0)
	if interior_cell.x < 0:
		interior_seat = 1
		interior_cell = _interior_zone_cell(1)
	eq(interior_cell.x >= 0, true, "found an interior cell in a sampled blob")
	eq(_sim.can_place(interior_seat, interior_cell)["ok"], true, "interior blob cell is legal")
	eq(_sim.place_unit(interior_seat, interior_cell)["ok"], true, "interior place succeeds")
	eq(_unit(interior_seat)["pos"], interior_cell, "fighter sits on an interior deploy cell")


func _test_deploy_occupied_and_reposition() -> void:
	_sim.reset_match({"seed": 1})
	var home: Vector2i = _zone_cell(0, 0)
	var next_home: Vector2i = _zone_cell(0, 1)
	var enemy: Vector2i = _zone_cell(1, 0)
	eq(_sim.place_unit(0, home)["ok"], true, "seat 0 places in its blob")
	eq(_unit(0)["pos"], home, "Kestrel sits on the first blob cell")
	eq(_unit(0)["placed"], true, "Kestrel is placed")
	eq(_sim.place_unit(1, enemy)["ok"], true, "seat 1 places at the same time")
	eq(_sim.place_unit(1, home)["reason"], "outside_zone", "P2 on P1's blob is outside_zone")
	eq(_sim.can_place(0, home)["ok"], true, "same fighter may stay on their cell")
	var moved: Dictionary = _sim.place_unit(0, next_home)
	eq(moved["ok"], true, "reposition before ready is legal")
	eq(_unit(0)["pos"], next_home, "Kestrel moved to another blob cell")
	eq(moved["events"][0]["repositioned"], true, "second place is a reposition")
	_sim._force_spawn(1, home)
	eq(_sim.place_unit(0, home)["reason"], "occupied", "place rejects an occupied blob cell")
	eq(_unit(0)["pos"], next_home, "failed occupied place does not move Kestrel")


func _test_deploy_ready_gate_and_combat_intents() -> void:
	_sim.reset_match({"seed": 1})
	eq(_sim.ready_seat(0)["reason"], "units_not_placed", "ready without a unit is units_not_placed")
	eq(_sim.snapshot()["ready"][0], false, "failed ready does not set the flag")
	_sim.place_unit(0, _zone_cell(0, 0))
	eq(_sim.can_ready(0), true, "Ready enables after the required unit is placed")
	eq(_sim.can_ready(1), false, "Ready P2 stays gated")
	eq(_sim.submit({"type": "move", "seat": 0, "to": _zone_cell(0, 1)})["reason"], "wrong_phase", "move rejected during deploy")
	eq(_sim.submit({"type": "cast", "seat": 0, "spell": "mark_shot", "to": _zone_cell(1, 0)})["reason"], "wrong_phase", "cast rejected during deploy")
	eq(_sim.submit({"type": "face", "seat": 0, "dir": "N"})["reason"], "wrong_phase", "face rejected during deploy")
	eq(_sim.submit({"type": "end_turn", "seat": 0})["reason"], "wrong_phase", "end_turn rejected during deploy")
	eq(_sim.ready_seat(0)["ok"], true, "P1 ready succeeds once placed")
	eq(_sim.snapshot()["ready"][0], true, "P1 ready flag is set")
	eq(_sim.snapshot()["phase"], "DEPLOYMENT", "one ready does not start combat")
	eq(_sim.place_unit(0, _zone_cell(0, 1))["reason"], "side_locked", "ready side cannot reposition")
	eq(_sim.ready_seat(0)["reason"], "already_ready", "cannot ready twice")
	eq(_sim.place_unit(1, _zone_cell(1, 0))["ok"], true, "P2 can still place after P1 ready")
	eq(_sim.snapshot()["combat_enabled"], false, "combat still off after only one ready")


func _test_both_ready_starts_combat() -> void:
	_sim.reset_match({"seed": 1})
	var p2: Vector2i = _zone_cell(1, 0)
	var p1: Vector2i = _zone_cell(0, 0)
	var p1_move: Vector2i = _zone_cell(0, 1)
	eq(_sim.place_unit(1, p2)["ok"], true, "P2 can place first")
	eq(_sim.place_unit(0, p1)["ok"], true, "P1 places after P2")
	eq(_sim.ready_seat(1)["ok"], true, "P2 can ready first")
	eq(_sim.snapshot()["phase"], "DEPLOYMENT", "still DEPLOYMENT after only P2 ready")
	eq(_sim.place_unit(0, p1_move)["ok"], true, "P1 may reposition after P2 is ready")
	var started: Dictionary = _sim.ready_seat(0)
	eq(started["ok"], true, "second ready succeeds")
	var snap: Dictionary = _sim.snapshot()
	eq(snap["phase"], "TURN_1", "both ready → TURN_1")
	eq(snap["both_ready"], true, "both_ready is true")
	eq(snap["positions_locked"], true, "positions lock")
	eq(snap["combat_enabled"], true, "combat on")
	eq(snap["walk_enabled"], true, "walk on")
	eq(snap["end_turn_enabled"], true, "end_turn on")
	eq(snap["turn_index"], 1, "Turn index is 1")
	eq(snap["active_seat"], 0, "Kestrel acts first in combat")
	eq(_unit(0)["pos"], p1_move, "combat spawn is the confirmed P1 cell")
	eq(_unit(1)["pos"], p2, "combat spawn is the confirmed P2 cell")
	eq(_unit(0)["locked"], true, "P1 locks")
	eq(_unit(1)["locked"], true, "P2 locks")
	eq(_unit(0)["ap"], 6, "Kestrel refills 6 AP on combat start")
	eq(_unit(0)["mp"], 3, "Kestrel refills 3 MP on combat start")
	eq(_unit(1)["ap"], 6, "Ironjaw has 6 AP when combat starts")
	eq(_sim.place_unit(0, _zone_cell(0, 2))["reason"], "wrong_phase", "place closed in TURN_1")
	eq(_sim.ready_seat(1)["reason"], "wrong_phase", "ready closed in TURN_1")
	var kinds := {}
	for intent in _sim.legal_intents(0):
		kinds[str(intent["type"])] = true
	truthy(kinds.has("move"), "move is legal after deploy")
	truthy(kinds.has("face"), "face is legal after deploy")
	truthy(kinds.has("end_turn"), "end_turn is legal after deploy")
	var opening: int = _sim.chebyshev(_unit(0)["pos"], _unit(1)["pos"])
	eq(opening >= 3, true, "confirmed seats open at least Chebyshev 3")
	if opening >= 2 and opening <= 7:
		truthy(kinds.has("cast"), "Mark Shot is offered at opening Chebyshev 2–7")
	else:
		eq(kinds.has("cast"), false, "Kestrel has no in-range cast when the opening is outside 2–7")
	eq(kinds.has("place"), false, "place is not a combat intent")
	var events: Array = started.get("events", [])
	var saw_combat := false
	var saw_turn := false
	for event in events:
		if str(event.get("type", "")) == "combat_start":
			saw_combat = true
		if str(event.get("type", "")) == "turn_start":
			saw_turn = true
	eq(saw_combat, true, "both ready emits combat_start")
	eq(saw_turn, true, "both ready emits turn_start")


func _test_kits_still_pass_after_deploy() -> void:
	# Explicit zones on Crosshaven ground. Opening is Chebyshev 3; 3 MP walks into Strike.
	_sim.reset_match({
		"seed": 1,
		"rolls": [1, 1],
		"deploy_zones": {
			0: [
				Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6),
				Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8),
			],
			1: [
				Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6),
				Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
			],
		},
	})
	var p1 := Vector2i(11, 6)
	var p2 := Vector2i(8, 6)
	_sim.place_unit(0, p1)
	_sim.place_unit(1, p2)
	_sim.ready_seat(0)
	_sim.ready_seat(1)
	eq(_sim.snapshot()["phase"], "TURN_1", "kits run after both ready")
	eq(_unit(0)["spells"], ["mark_shot", "detonate"], "Kestrel kit is Mark Shot + Detonate after deploy")
	eq(_unit(1)["spells"], ["advance", "strike", "shoulder", "crush"], "Ironjaw kit is Advance + Strike + Shoulder + Crush after deploy")
	var kestrel_offered: Array = CombatHUD.offered_cast_ids(_unit(0), _sim.legal_intents(0))
	eq(kestrel_offered, ["mark_shot", "detonate"], "Kestrel HUD offers Mark Shot and Detonate after deploy")
	eq(_has_legal_cast(0, "detonate"), false, "Detonate stays gated at 0 Marks")
	var end_turn: Dictionary = _sim.submit({"type": "end_turn"})
	eq(end_turn["ok"], true, "end_turn works after deploy")
	eq(_sim.snapshot()["active_seat"], 1, "Ironjaw becomes active after deploy")
	_walk_seat_toward(1, p1, 1)
	var ironjaw_offered: Array = CombatHUD.offered_cast_ids(_unit(1), _sim.legal_intents(1))
	eq(ironjaw_offered, ["advance", "strike", "shoulder", "crush"], "Ironjaw HUD offers the Locked kit after deploy")
	eq(_has_legal_cast(1, "strike"), true, "Strike is legal after walking in from the opening")
	eq(_has_legal_cast(1, "advance"), true, "Advance is legal after deploy")
	eq(_has_legal_cast(1, "mark_shot"), false, "Ironjaw still cannot Mark Shot")
	var strike: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": _unit(0)["pos"]})
	eq(strike["ok"], true, "Strike resolves after deploy")
	eq(strike["illegal"], false, "Strike is not rejected")
	eq(_unit(0)["hp"] < 80, true, "Strike dealt damage after deploy")
	eq(_unit(1)["impact"], 1, "Strike still grants Impact after deploy")


func _test_only_active_seat_acts() -> void:
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	var result: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(result["illegal"], true, "Ironjaw cannot end Kestrel's turn")
	eq(result["reason"], "not_your_turn", "reject reason is not_your_turn")
	eq(_sim.snapshot()["active_seat"], 0, "seat unchanged after reject")


func _test_manhattan_walk_costs() -> void:
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
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
	eq(str(result["snapshot"].get("coach", "")), "REJECT — illegal move (insufficient_mp).", "short MP still names an illegal move")
	eq(_unit(0)["pos"], Vector2i(3, 3), "pawn did not move")
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	result = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "3-tile orthogonal walk spends the full MP pool")
	eq(_unit(0)["mp"], 0, "Manhattan 3 costs 3 MP")
	eq(_unit(0)["pos"], Vector2i(5, 2), "Kestrel landed on (5,2)")
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
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
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "H-first Manhattan 3 walk is legal")
	eq(result["events"][0]["path"], [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)], "returned path is E then S")
	eq(result["events"][0]["facing_hops"], ["E", "E", "S"], "H-first NE hop facing is E, E, then S")
	eq(result["events"][0]["facing"], "S", "final facing is the last hop")
	eq(_unit(0)["facing"], "S", "actor facing is last hop S")
	eq(_unit(0)["mp"], 0, "H-first 3-step walk spends 3 MP")
	# Occupant sits on the old H-first corridor. Weighted walk may route around.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(1, 0)})
	result = _sim.submit({"type": "move", "to": Vector2i(1, 1)})
	eq(result["ok"], true, "weighted path routes south then east around Ironjaw")
	eq(result["events"][0]["path"], [Vector2i(0, 1), Vector2i(1, 1)], "path is S then E, not through the occupant")
	eq(result["events"][0]["mp_spent"], 2, "two Ground hops cost 2")
	eq(_unit(0)["pos"], Vector2i(1, 1), "Kestrel lands on (1,1)")
	eq(_unit(0)["facing"], "E", "last hop around the occupant faces E")
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(1, 0)})
	eq(_has_legal_move_to(0, Vector2i(1, 1)), true, "legal_intents include dests reachable around an occupant")
	eq(_has_legal_move_to(0, Vector2i(1, 0)), false, "legal_intents omit the occupied dest")
	result = _sim.submit({"type": "move", "to": Vector2i(1, 0)})
	eq(result["illegal"], true, "walking onto Ironjaw is still occupied")
	eq(result["reason"], "occupied", "occupied dest reason is occupied")
	result = _sim.submit({"type": "move", "to": Vector2i(0, 2)})
	eq(result["ok"], true, "pure-vertical dest around the occupant is legal")
	eq(result["events"][0]["path"], [Vector2i(0, 1), Vector2i(0, 2)], "vertical path does not go east first")
	eq(result["events"][0]["facing_hops"], ["S", "S"], "pure-south hops face S then S")
	eq(_unit(0)["facing"], "S", "vertical walk ends facing last hop S")


func _test_client_path_ignored() -> void:
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
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


func _test_phase_a_demo_map() -> void:
	# Ship default loads Crosshaven 15×15 tags when the file size matches.
	# Proto board_size 8 keeps the crop + noise. Proto board_size 12 is Mauro tokens.
	var live: Dictionary = _sim.reset_match({"seed": 1})
	eq(live["phase"], "DEPLOYMENT", "live reset still starts in DEPLOYMENT")
	eq(live["board_size"], 15, "live reset is the 15×15 ship board")
	eq(live["demo_map"], "crosshaven_15", "live snap stamps Crosshaven")
	eq(live["elevation_gen"], "tags", "live reset uses tag elevation")
	eq(live["elev_seed"], 1, "live reset stores elev_seed")
	eq(live["tiles"].size(), 225, "live reset lists 225 tiles")
	var saw := {"ground": 0, "mud": 0, "water": 0, "lava": 0}
	var elev_hi := 0
	for cell in live["tiles"].keys():
		var rec: Dictionary = live["tiles"][cell]
		saw[str(rec["terrain_type"])] = int(saw.get(str(rec["terrain_type"]), 0)) + 1
		if int(rec["elevation"]) >= 1:
			elev_hi += 1
	eq(saw["ground"], 177, "Crosshaven ground count")
	eq(saw["mud"], 30, "Crosshaven mud count")
	eq(saw["water"], 18, "Crosshaven water count")
	eq(saw["lava"], 0, "Crosshaven has no lava")
	eq(elev_hi, 18, "Crosshaven elevation ≥1 count")
	eq(live["tiles"][Vector2i(0, 0)]["terrain_type"], "ground", "Crosshaven (0,0) is ground")
	eq(live["tiles"][Vector2i(0, 0)]["elevation"], 0, "Crosshaven (0,0) tag elevation is 0")
	eq(live["tiles"][Vector2i(0, 0)]["walkable"], true, "ruins paint_only does not block (0,0)")
	eq(live["paint_only"][Vector2i(0, 0)][0], "ruins", "paint_only stays off the walk tile")
	eq(live["tiles"][Vector2i(1, 1)]["terrain_type"], "mud", "Crosshaven (1,1) is mud")
	eq(live["tiles"][Vector2i(1, 1)]["walkable"], true, "Crosshaven (1,1) mud is walkable")
	eq(live["tiles"][Vector2i(0, 4)]["terrain_type"], "water", "Crosshaven (0,4) is water")
	eq(live["tiles"][Vector2i(7, 3)]["elevation"], 1, "Crosshaven (7,3) tag elevation is 1")
	eq(live["tiles"][Vector2i(7, 4)]["elevation"], 2, "Crosshaven (7,4) tag elevation is 2")
	var tags = load("res://backend/cell_tag_map.gd").load_default()
	var checked: Dictionary = load("res://backend/cell_tag_map.gd").cross_check_tmx(tags)
	eq(checked["ok"], true, "tags JSON matches the isometric tmx terrain and elevation")
	eq(int(checked["mismatches"]), 0, "tmx cross-check has no terrain mismatches")
	var art: Texture2D = load("res://board/koliseo_art.gd").terrain_texture("ground", 0)
	eq(art != null, true, "Crosshaven ground art loads")
	eq(art.get_width(), 64, "Crosshaven ground sheet is 64 px wide")
	var placed: Dictionary = load("res://board/koliseo_art.gd").terrain_placement(art)
	eq(placed.is_empty(), false, "painted ground uses the half-diamond placement")
	eq((placed["dest"] as Rect2).position, Vector2(-32, -16), "painted ground sits on the board diamond")
	eq((placed["dest"] as Rect2).size, Vector2(64, 32), "painted ground scales to the 64×32 diamond")
	var ruins_tex: Texture2D = load("res://board/koliseo_art.gd").prop_texture("ruins")
	eq(ruins_tex != null, true, "paint_only ruins art loads")
	eq(ruins_tex.get_height(), 112, "painted ruins sheet is the dress v1 height")
	var other: Dictionary = _sim.reset_match({"seed": 2})
	eq(other["tiles"][Vector2i(7, 4)]["elevation"], 2, "a new seed does not retune tag elevation")
	eq(other["tiles"][Vector2i(1, 1)]["terrain_type"], "mud", "a new seed keeps Crosshaven terrain")

	var proto: Dictionary = _sim.reset_match({"seed": 1, "board_size": 8})
	_assert_phase_a_demo_tiles(proto, "proto 8", 1)
	eq(proto["demo_map"], "phase_a_fixed", "proto 8 stamps the crop map id")
	eq(proto["elevation_gen"], "seeded_noise", "proto 8 generates noise elevation")

	var skip: Dictionary = _sim.reset_match({"seed": 1, "skip_deploy": true, "board_size": 8})
	_assert_phase_a_demo_tiles(skip, "proto skip_deploy", 1)
	eq(skip["units"][0]["pos"], Vector2i(1, 1), "skip_deploy fixture still uses (1,1)")
	eq(skip["tiles"][Vector2i(1, 1)]["terrain_type"], "ground", "proto skip_deploy (1,1) stays Ground")
	eq(skip["tiles"][Vector2i(1, 1)]["walkable"], true, "proto skip_deploy (1,1) stays walkable")
	eq(skip["tiles"][Vector2i(6, 6)]["walkable"], true, "proto skip_deploy (6,6) stays walkable")

	var flat: Dictionary = _sim.reset_match({"seed": 1, "skip_deploy": true, "flat_board": true})
	eq(flat["board_size"], 15, "flat_board still uses the ship size")
	eq(flat["demo_map"], "", "flat_board skips the demo seed")
	eq(flat["tiles"][Vector2i(4, 1)]["terrain_type"], "ground", "flat_board cell is Ground")
	eq(flat["tiles"][Vector2i(4, 1)]["elevation"], 0, "flat_board elevation is 0")

	# Deploy rejects a stamped lava cell when it sits in a proto crop zone.
	_sim.reset_match({
		"seed": 1,
		"board_size": 8,
		"deploy_zones": {
			0: [
				Vector2i(4, 0), Vector2i(3, 0), Vector2i(2, 0),
				Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 1),
			],
			1: [
				Vector2i(6, 6), Vector2i(7, 6), Vector2i(6, 7),
				Vector2i(7, 7), Vector2i(5, 6), Vector2i(5, 7),
			],
		},
	})
	eq(_sim.can_place(0, Vector2i(4, 0))["reason"], "not_walkable", "stamped lava in a blob is not_walkable")
	eq(_sim.place_unit(0, Vector2i(4, 0))["reason"], "not_walkable", "place onto stamped lava is rejected")
	eq(_sim.legal_deploy_cells(0).has(Vector2i(4, 0)), false, "legal deploy omits stamped lava")
	eq(_sim.place_unit(0, Vector2i(2, 0))["ok"], true, "mud blob cell is still deployable (no climb tax)")
	eq(_sim.tile_at(Vector2i(2, 0))["terrain_type"], "mud", "placed mud cell stays mud in snapshot")

	# Random blobs sample on the 15×15 ship board and leave a walkable place cell.
	for seed in [1, 2, 3, 7, 11]:
		_sim.reset_match({"seed": seed})
		eq(_sim.snapshot()["board_size"], 15, "seed %d board is 15×15" % seed)
		eq(_sim.deploy_zone_cells(0).size(), 6, "seed %d seat 0 blob is 6 cells" % seed)
		eq(_sim.deploy_zone_cells(1).size(), 6, "seed %d seat 1 blob is 6 cells" % seed)
		truthy(_walkable_zone_count(0) > 0, "seed %d seat 0 still has a walkable blob cell" % seed)
		truthy(_walkable_zone_count(1) > 0, "seed %d seat 1 still has a walkable blob cell" % seed)

	var twelve: Dictionary = _sim.reset_match({"seed": 1, "board_size": 12, "skip_deploy": true})
	eq(twelve["board_size"], 12, "explicit 12 is proto only")
	eq(twelve["tiles"].size(), 144, "explicit 12 is 144 Mauro cells")
	eq(twelve["demo_map"], "mauro_12", "explicit 12 seeds Mauro tokens")
	eq(twelve["elevation_gen"], "mauro", "explicit 12 uses Mauro elevation")
	eq(twelve["demo_map"] == "crosshaven_12", false, "explicit 12 does not load Crosshaven")
	eq(twelve["tiles"][Vector2i(1, 2)]["terrain_type"], "mud", "explicit 12 (1,2) is Mauro mud")
	eq(twelve["tiles"][Vector2i(0, 0)]["terrain_type"], "ground", "explicit 12 (0,0) is Mauro ground")
	eq(twelve["tiles"][Vector2i(0, 0)]["elevation"], 0, "explicit 12 (0,0) token elevation is 0")
	eq(twelve["paint_only"].is_empty(), true, "proto 12 has no Crosshaven paint_only")
	var other_size: Dictionary = _sim.reset_match({"seed": 1, "board_size": 10, "skip_deploy": true})
	eq(other_size["board_size"], 10, "a non-ship size stays an override")
	eq(other_size["tiles"].size(), 100, "a non-ship size does not invent a map")
	eq(other_size["demo_map"], "", "a non-ship size does not load Mauro or Crosshaven")
	eq(other_size["tiles"][Vector2i(0, 0)]["terrain_type"], "ground", "a non-ship size stays open ground")
	eq(other_size["tiles"][Vector2i(0, 0)]["elevation"], 0, "a non-ship size elevation is 0")

	# Tag elevation is walk authority. paint_only does not block.
	_sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(7, 3),
		"ironjaw_pos": Vector2i(14, 14),
	})
	eq(_sim.tile_at(Vector2i(7, 3))["elevation"], 1, "tag z at (7,3) is 1")
	eq(_sim.tile_at(Vector2i(7, 4))["elevation"], 2, "tag z at (7,4) is 2")
	var climb: Dictionary = _sim.submit({"type": "move", "to": Vector2i(7, 4)})
	eq(climb["ok"], true, "tag climb of 1 is legal")
	eq(climb["events"][0]["mp_spent"], 2, "ground + climb 1 costs 2 MP")
	_sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 4),
		"ironjaw_pos": Vector2i(14, 14),
	})
	var water: Dictionary = _sim.submit({"type": "move", "to": Vector2i(0, 4)})
	eq(water["ok"], true, "water hop is legal")
	eq(water["events"][0]["mp_spent"], 2, "water dest costs 2 MP")
	_sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(0, 1),
		"ironjaw_pos": Vector2i(14, 14),
	})
	var ruins: Dictionary = _sim.submit({"type": "move", "to": Vector2i(0, 0)})
	eq(ruins["ok"], true, "paint_only ruins does not block the step")
	eq(ruins["events"][0]["mp_spent"], 1, "ruins tile still costs ground MP")

	var flow := FileAccess.get_file_as_string("res://backend/match_flow.gd")
	truthy(flow.contains("PHASE_A_DEMO_TILES"), "MatchFlow owns the stamped cell list")
	truthy(flow.contains("PHASE_A_CROP_ORIGIN_ROW := 2"), "MatchFlow stamps crop origin row 2")
	truthy(flow.contains("PHASE_A_CROP_ORIGIN_COL := 2"), "MatchFlow stamps crop origin col 2")
	truthy(flow.contains("MAURO_12X12"), "MatchFlow keeps Mauro's 12×12 source")
	truthy(flow.contains("generate_noise_elevations"), "MatchFlow owns seeded noise elevation")
	truthy(flow.contains("BOARD_SIZE := BoardSize.SHIP"), "MatchFlow ship size is BoardSize.SHIP")
	var walk := FileAccess.get_file_as_string("res://backend/walk_board.gd")
	truthy(walk.contains("func stand_on_gate"), "WalkBoard exposes the shared stand-on helper")
	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("row **2**, col **2**"), "README documents crop origin (2, 2)")
	truthy(readme.contains("G3 G3 M3 W2 L2 W1 W1 M1"), "README documents the 8×8 ASCII crop")
	truthy(readme.contains("seeded noise"), "README documents seeded noise elevation")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(sim_src.contains("BOARD_SIZE := _BoardSize.SHIP"), "CombatSim BOARD_SIZE is the ship constant")
	eq(sim_src.contains("BOARD_SIZE := 8"), false, "CombatSim does not hardcode BOARD_SIZE 8")
	eq(sim_src.contains("crosshaven_12x12"), false, "CombatSim does not wire a 12×12 Crosshaven pack")
	eq(FileAccess.file_exists("res://art/maps/arena_colosseum_v2/tiled/crosshaven_12x12_tags.json"), false, "12×12 Crosshaven tags are not shipped")
	eq(FileAccess.file_exists("res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json"), true, "15×15 Crosshaven tags stay the loader target")


func _assert_phase_a_demo_tiles(snap: Dictionary, label: String, seed: int) -> void:
	var tiles: Dictionary = snap["tiles"]
	eq(tiles.size(), 64, "%s lists all 64 tiles" % label)
	var expected: Array = load("res://backend/match_flow.gd").phase_a_demo_tiles()
	var noise: Dictionary = load("res://backend/match_flow.gd").generate_noise_elevations(seed)
	eq(expected.size(), 64, "%s crop list is 64 cells" % label)
	var saw := {"mud": 0, "water": 0, "lava": 0, "ground": 0}
	var elevs := {}
	for row in expected:
		var cell: Vector2i = row["pos"]
		var rec: Dictionary = tiles[cell]
		eq(rec["terrain_type"], row["terrain"], "%s %s terrain" % [label, str(cell)])
		eq(rec["elevation"], int(noise[cell]), "%s %s elevation matches seed %d" % [label, str(cell), seed])
		eq(typeof(rec["elevation"]), TYPE_INT, "%s %s elevation is int" % [label, str(cell)])
		eq(int(rec["elevation"]) >= 0 and int(rec["elevation"]) <= 3, true, "%s %s elevation is z 0–3" % [label, str(cell)])
		if rec["terrain_type"] == "lava":
			eq(rec["walkable"], false, "%s lava %s is impassable" % [label, str(cell)])
		saw[str(rec["terrain_type"])] = int(saw.get(str(rec["terrain_type"]), 0)) + 1
		elevs[int(rec["elevation"])] = true
	eq(saw["mud"] > 0, true, "%s crop has Mud" % label)
	eq(saw["water"] > 0, true, "%s crop has Water" % label)
	eq(saw["lava"] > 0, true, "%s crop has Lava" % label)
	eq(elevs.size() >= 2, true, "%s noise elev has variety" % label)
	eq(tiles[Vector2i(4, 0)]["terrain_type"], "lava", "%s lava cluster at (4,0)" % label)
	eq(tiles[Vector2i(2, 0)]["terrain_type"], "mud", "%s mud at (2,0)" % label)
	eq(tiles[Vector2i(3, 0)]["terrain_type"], "water", "%s water at (3,0)" % label)
	eq(tiles[Vector2i(6, 5)]["terrain_type"], "ground", "%s SE ridge Ground" % label)


func _test_snapshot_exposes_tiles() -> void:
	_sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"flat_board": true,
		"tiles": [
			{"pos": Vector2i(3, 2), "terrain": "mud", "elevation": 1},
			{"pos": Vector2i(4, 2), "terrain": "water", "elevation": 0},
			{"pos": Vector2i(5, 2), "terrain": "lava", "elevation": 2},
		],
	})
	var snap: Dictionary = _sim.snapshot()
	eq(snap["tiles"][Vector2i(3, 2)]["terrain_type"], "mud", "painted mud is in the snapshot")
	eq(snap["tiles"][Vector2i(3, 2)]["elevation"], 1, "painted elevation is an int in the snapshot")
	eq(typeof(snap["tiles"][Vector2i(3, 2)]["elevation"]), TYPE_INT, "snapshot elevation type is int")
	eq(snap["tiles"][Vector2i(4, 2)]["terrain_type"], "water", "painted water is in the snapshot")
	eq(snap["tiles"][Vector2i(5, 2)]["terrain_type"], "lava", "painted lava is in the snapshot")
	eq(snap["tiles"][Vector2i(5, 2)]["walkable"], false, "lava snapshot walkable is false")
	eq(snap["tiles"][Vector2i(0, 0)]["terrain_type"], "ground", "unpainted tiles stay Ground")
	eq(_sim.tile_at(Vector2i(3, 2))["terrain_type"], "mud", "tile_at matches snapshot")
	var combat := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(combat.contains("proto/elevation"), false, "CombatSim does not import proto/elevation")
	eq(combat.contains("ProtoMoveSim"), false, "CombatSim does not reference ProtoMoveSim")


func _test_mud_walk_cost() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"tiles": [{"pos": Vector2i(3, 2), "terrain": "mud", "elevation": 0.0}],
	})
	eq(_has_legal_move_to(0, Vector2i(3, 2)), true, "adjacent mud is legal at 3 MP")
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 2)})
	eq(result["ok"], true, "mud hop is legal")
	eq(result["events"][0]["mp_spent"], 2, "mud dest costs 2 MP")
	eq(_unit(0)["mp"], 1, "3 MP minus mud 2 leaves 1")
	eq(_unit(0)["pos"], Vector2i(3, 2), "Kestrel landed on mud")
	eq(_has_legal_move_to(0, Vector2i(4, 2)), true, "1 MP still reaches adjacent Ground")
	_sim.set_tile(Vector2i(4, 2), "mud", 0.0)
	eq(_has_legal_move_to(0, Vector2i(4, 2)), false, "1 MP cannot pay a second mud hop")
	result = _sim.submit({"type": "move", "to": Vector2i(4, 2)})
	eq(result["illegal"], true, "second mud hop at 1 MP is rejected")
	eq(result["reason"], "insufficient_mp", "short mud hop reason is insufficient_mp")
	eq(_unit(0)["pos"], Vector2i(3, 2), "rejected mud hop leaves the pawn put")


func _test_lava_impassable() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"tiles": [
			{"pos": Vector2i(3, 2), "terrain": "lava", "elevation": 0.0},
			{"pos": Vector2i(4, 4), "terrain": "lava", "elevation": 0.0},
		],
	})
	var adjacent: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 2)})
	eq(adjacent["illegal"], true, "adjacent lava is rejected")
	eq(adjacent["reason"], "not_walkable", "lava reason is not_walkable")
	eq(_unit(0)["pos"], Vector2i(2, 2), "lava hop does not move the pawn")
	eq(_has_legal_move_to(0, Vector2i(3, 2)), false, "legal_intents omit lava")
	var far: Dictionary = _sim.submit({"type": "move", "to": Vector2i(4, 4)})
	eq(far["reason"], "not_walkable", "far lava is not_walkable, not merely unreachable")
	# Path around lava still works: east is lava, so go north then east.
	var around: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 1)})
	eq(around["ok"], true, "Ground next to lava is still walkable")
	eq(around["events"][0]["mp_spent"], 2, "two Ground hops around lava cost 2")


func _test_climb_reject() -> void:
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"flat_board": true,
		"tiles": [
			{"pos": Vector2i(3, 2), "terrain": "ground", "elevation": 2},
			{"pos": Vector2i(2, 3), "terrain": "ground", "elevation": 1},
			{"pos": Vector2i(1, 2), "terrain": "ground", "elevation": 1},
		],
	})
	var steep: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 2)})
	eq(steep["illegal"], true, "climb 2 (z1→z3 hop) is rejected")
	eq(steep["reason"], "climb_too_steep", "climb reject reason is climb_too_steep")
	eq(_has_legal_move_to(0, Vector2i(3, 2)), false, "legal_intents omit a climb-2 hop")
	eq(_unit(0)["pos"], Vector2i(2, 2), "steep climb leaves the pawn put")

	var full: Dictionary = _sim.submit({"type": "move", "to": Vector2i(2, 3)})
	eq(full["ok"], true, "integer climb 1 is legal")
	eq(full["events"][0]["mp_spent"], 2, "ground 1 + climb 1 = 2")
	eq(_unit(0)["mp"], 1, "climb spends 2 of 3 MP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"tiles": [{"pos": Vector2i(1, 2), "terrain": "ground", "elevation": 1}],
	})
	var step: Dictionary = _sim.submit({"type": "move", "to": Vector2i(1, 2)})
	eq(step["ok"], true, "integer z step climb is legal")
	eq(step["events"][0]["mp_spent"], 2, "climb of 1 costs +1 MP")


func _test_downhill_free() -> void:
	_sim.reset_match({
		"seed": 1,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"flat_board": true,
		"tiles": [
			{"pos": Vector2i(2, 2), "terrain": "ground", "elevation": 1},
			{"pos": Vector2i(3, 2), "terrain": "ground", "elevation": 0},
			{"pos": Vector2i(1, 2), "terrain": "ground", "elevation": 2},
			{"pos": Vector2i(2, 1), "terrain": "ground", "elevation": 3},
		],
	})
	var down: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 2)})
	eq(down["ok"], true, "downhill 1 is legal")
	eq(down["events"][0]["mp_spent"], 1, "downhill Ground costs terrain only")
	eq(_unit(0)["mp"], 2, "downhill spends 1 MP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"tiles": [
			{"pos": Vector2i(2, 2), "terrain": "ground", "elevation": 2},
			{"pos": Vector2i(3, 2), "terrain": "ground", "elevation": 0},
		],
	})
	var drop2: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 2)})
	eq(drop2["ok"], true, "drop of exactly 2 is legal")
	eq(drop2["events"][0]["mp_spent"], 1, "legal drop still pays dest terrain MP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"tiles": [
			{"pos": Vector2i(2, 2), "terrain": "ground", "elevation": 3},
			{"pos": Vector2i(3, 2), "terrain": "ground", "elevation": 0},
		],
	})
	var far: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 2)})
	eq(far["illegal"], true, "drop 3 is rejected")
	eq(far["reason"], "drop_too_far", "far drop reason is drop_too_far")
	eq(_unit(0)["pos"], Vector2i(2, 2), "illegal drop leaves the pawn put")


func _test_weighted_prefers_flat() -> void:
	# Start (2,2) G0. Dest (3,3) G0.
	# Flat: (2,2)->(3,2) G0 cost 1 ->(3,3) G0 cost 1  total 2
	# Mud+climb: (2,2)->(2,3) M1 cost 2+1=3 ->(3,3) drop/ground 1  total 4
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(2, 2),
		"ironjaw_pos": Vector2i(7, 7),
		"tiles": [{"pos": Vector2i(2, 3), "terrain": "mud", "elevation": 1.0}],
	})
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 3)})
	eq(result["ok"], true, "diagonal dest is reachable")
	eq(result["events"][0]["mp_spent"], 2, "cheapest path is flat Ground cost 2, not mud+climb 4")
	eq(result["events"][0]["path"], [Vector2i(3, 2), Vector2i(3, 3)], "reconstruct prefers the flat corridor")
	eq(_unit(0)["mp"], 1, "flat path leaves 1 MP")
	eq(_has_legal_move_to(0, Vector2i(2, 3)), false, "1 leftover MP cannot enter the mud+climb tile")


func _test_deploy_rejects_lava() -> void:
	# Paint lava onto a walkable blob cell. Demo lava may already sit in a zone.
	_sim.reset_match({"seed": 1})
	var before := _walkable_zone_count(0)
	var lava: Vector2i = _first_walkable_zone_cell(0)
	var ground: Vector2i = _next_walkable_zone_cell(0, lava)
	var p2: Vector2i = _first_walkable_zone_cell(1)
	eq(lava.x >= 0, true, "seed 1 seat 0 has a walkable blob cell to paint")
	eq(ground.x >= 0, true, "seed 1 seat 0 has a second walkable blob cell")
	_sim.set_tile(lava, "lava", 0.0)
	eq(_sim.snapshot()["phase"], "DEPLOYMENT", "live reset still starts in DEPLOYMENT")
	eq(_sim.can_place(0, lava)["reason"], "not_walkable", "lava blob cell is not_walkable")
	eq(_sim.place_unit(0, lava)["reason"], "not_walkable", "place onto lava is rejected")
	eq(_unit(0)["placed"], false, "failed lava place leaves Kestrel unplaced")
	eq(_sim.legal_deploy_cells(0).has(lava), false, "legal deploy cells omit lava")
	eq(_sim.legal_deploy_cells(0).size(), before - 1, "painting lava drops one legal blob cell")
	eq(_sim.place_unit(0, ground)["ok"], true, "remaining Ground blob cell still places")
	eq(_sim.place_unit(1, p2)["ok"], true, "P2 still places on Ground")
	eq(_sim.ready_seat(0)["ok"], true, "Ready P1 still works")
	eq(_sim.ready_seat(1)["ok"], true, "Ready P2 still works")
	eq(_sim.snapshot()["phase"], "TURN_1", "deploy+kits path still starts combat after lava paint")
	eq(_unit(0)["spells"], ["mark_shot", "detonate"], "Kestrel kit still loads after lava deploy")
	eq(_unit(1)["spells"], ["advance", "strike", "shoulder", "crush"], "Ironjaw kit still loads after lava deploy")


func _test_hit_bands_ignore_height() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 1),
		"tiles": [
			{"pos": Vector2i(1, 1), "terrain": "ground", "elevation": 2.0},
			{"pos": Vector2i(6, 1), "terrain": "ground", "elevation": 0.0},
		],
	})
	eq(_sim.chebyshev(Vector2i(1, 1), Vector2i(6, 1)), 5, "Chebyshev range is still 5")
	eq(_sim.hit_chance(5), 75, "band 4–5 stays 75% with a height delta")
	var preview: Dictionary = _sim.aim_hit_preview(0, "mark_shot", Vector2i(6, 1))
	eq(preview["hit_chance"], 75, "aim preview ignores elevation")
	eq(preview["range"], 5, "aim range stays Chebyshev, not height-adjusted")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	var hit_idx := sim_src.find("static func hit_chance")
	var hit_src := sim_src.substr(hit_idx, 220)
	eq(hit_src.contains("elevation"), false, "hit_chance does not read elevation")
	eq(hit_src.contains("terrain"), false, "hit_chance does not read terrain")


func _test_advance_stand_on_gates() -> void:
	# Locked: Advance dest uses the same stand-on gates as walk. Gate only — 0 MP.
	var walk := FileAccess.get_file_as_string("res://backend/walk_board.gd")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(walk.contains("func stand_on_gate"), "shared stand-on helper lives on WalkBoard")
	truthy(sim_src.contains("_advance_stand_reason"), "Advance validate calls the shared helper")
	eq(sim_src.contains("Open: Advance onto illegal climb"), false, "Advance climb is no longer Open")

	# Lava dest at Manhattan 2. The tile between is not a path.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(2, 2),
		"tiles": [{"pos": Vector2i(4, 2), "terrain": "lava", "elevation": 0}],
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim._validate_advance(_unit(1), Vector2i(4, 2)), "not_walkable", "Advance lava dest is not_walkable")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["ok"], false, "Advance onto lava is rejected")
	eq(result["illegal"], true, "illegal Advance is refunded")
	eq(result["reason"], "not_walkable", "lava Advance reason is not_walkable")
	eq(_unit(1)["pos"], Vector2i(2, 2), "lava Advance leaves Ironjaw put")
	eq(_unit(1)["ap"], 6, "lava Advance refunds AP")
	eq(_unit(1)["mp"], 3, "lava Advance spends 0 MP")
	eq(_has_legal_advance_to(1, Vector2i(4, 2)), false, "legal_intents omit lava Advance")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(4, 2))["reason"], "not_walkable", "preview_cast reflects lava gate")

	# Occupied dest at Manhattan 2.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(4, 2),
		"ironjaw_pos": Vector2i(2, 2),
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim._validate_advance(_unit(1), Vector2i(4, 2)), "destination_occupied", "Advance occupied dest is destination_occupied")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["illegal"], true, "occupied Advance is rejected")
	eq(result["reason"], "destination_occupied", "occupied Advance reason is destination_occupied")
	eq(_unit(1)["pos"], Vector2i(2, 2), "occupied Advance leaves Ironjaw put")
	eq(_unit(1)["ap"], 6, "occupied Advance refunds AP")
	eq(_unit(1)["mp"], 3, "occupied Advance spends 0 MP")
	eq(_has_legal_advance_to(1, Vector2i(4, 2)), false, "legal_intents omit occupied Advance")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(4, 2))["reason"], "destination_occupied", "preview_cast reflects occupied gate")

	# Climb > 1 (z0 → z2) measured from origin to the Manhattan-2 dest.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(2, 2),
		"tiles": [{"pos": Vector2i(4, 2), "terrain": "ground", "elevation": 2}],
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim._validate_advance(_unit(1), Vector2i(4, 2)), "climb_too_steep", "Advance climb 2 is climb_too_steep")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["illegal"], true, "climb-2 Advance is rejected")
	eq(result["reason"], "climb_too_steep", "climb Advance reason is climb_too_steep")
	eq(_unit(1)["pos"], Vector2i(2, 2), "climb Advance leaves Ironjaw put")
	eq(_unit(1)["ap"], 6, "climb Advance refunds AP")
	eq(_unit(1)["mp"], 3, "climb Advance spends 0 MP")
	eq(_has_legal_advance_to(1, Vector2i(4, 2)), false, "legal_intents omit climb-2 Advance")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(4, 2))["reason"], "climb_too_steep", "preview_cast reflects climb gate")

	# Drop > 2 (z3 → z0).
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(2, 2),
		"tiles": [
			{"pos": Vector2i(2, 2), "terrain": "ground", "elevation": 3},
			{"pos": Vector2i(4, 2), "terrain": "ground", "elevation": 0},
		],
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim._validate_advance(_unit(1), Vector2i(4, 2)), "drop_too_far", "Advance drop 3 is drop_too_far")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["illegal"], true, "drop-3 Advance is rejected")
	eq(result["reason"], "drop_too_far", "drop Advance reason is drop_too_far")
	eq(_unit(1)["pos"], Vector2i(2, 2), "drop Advance leaves Ironjaw put")
	eq(_unit(1)["ap"], 6, "drop Advance refunds AP")
	eq(_unit(1)["mp"], 3, "drop Advance spends 0 MP")
	eq(_has_legal_advance_to(1, Vector2i(4, 2)), false, "legal_intents omit drop-3 Advance")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(4, 2))["reason"], "drop_too_far", "preview_cast reflects drop gate")

	# Legal dest: climb 1 onto mud, 0 MP spent. Lava on the tile between does not block a snap.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(2, 2),
		"tiles": [
			{"pos": Vector2i(3, 2), "terrain": "lava", "elevation": 0},
			{"pos": Vector2i(4, 2), "terrain": "mud", "elevation": 1},
		],
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim._validate_advance(_unit(1), Vector2i(4, 2)), "", "legal Advance dest passes shared stand-on gates")
	eq(_sim._validate_advance(_unit(1), Vector2i(3, 2)), "out_of_range", "Manhattan 1 between is not an Advance dest")
	eq(_has_legal_advance_to(1, Vector2i(4, 2)), true, "legal_intents include a legal Advance dest")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(4, 2))["legal"], true, "preview_cast marks a legal dest")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["ok"], true, "legal Advance dest is accepted")
	eq(_unit(1)["pos"], Vector2i(4, 2), "Advance snapped onto the legal dest")
	eq(_unit(1)["ap"], 3, "legal Advance spends 3 AP")
	eq(_unit(1)["mp"], 3, "legal Advance spends 0 MP (gate only, no mud/climb tax)")
	eq(result["events"][0]["mp_spent"], 0, "advance event spends 0 MP")


func _test_noise_elevation_per_match() -> void:
	# Proto board_size 8: new seed → new elev, same crop terrain. Same seed replays.
	var a: Dictionary = _sim.reset_match({"seed": 1, "board_size": 8})
	var b: Dictionary = _sim.reset_match({"seed": 2, "board_size": 8})
	var again: Dictionary = _sim.reset_match({"seed": 1, "board_size": 8})
	eq(a["board_size"], 8, "noise elev stays on proto 8×8")
	eq(b["board_size"], 8, "second seed stays on proto 8×8")
	eq(a["elevation_gen"], "seeded_noise", "seed 1 uses seeded noise")
	eq(b["elevation_gen"], "seeded_noise", "seed 2 uses seeded noise")
	eq(a["elev_seed"], 1, "seed 1 stores elev_seed 1")
	eq(b["elev_seed"], 2, "seed 2 stores elev_seed 2")
	eq(a["seed"], 1, "snapshot.seed is 1")
	eq(again["elev_seed"], 1, "reset with the same seed stores elev_seed 1 again")
	eq(a["tiles"].size(), 64, "seed 1 still paints 64 tiles")
	var terrain_same := true
	var elev_diff := false
	var elev_same_replay := true
	for y in range(8):
		for x in range(8):
			var cell := Vector2i(x, y)
			eq(a["tiles"][cell]["terrain_type"], b["tiles"][cell]["terrain_type"], "seed 1 vs 2 keep crop terrain at %s" % str(cell))
			eq(a["tiles"][cell]["terrain_type"], again["tiles"][cell]["terrain_type"], "replay keeps crop terrain at %s" % str(cell))
			if a["tiles"][cell]["terrain_type"] != b["tiles"][cell]["terrain_type"]:
				terrain_same = false
			if int(a["tiles"][cell]["elevation"]) != int(b["tiles"][cell]["elevation"]):
				elev_diff = true
			if int(a["tiles"][cell]["elevation"]) != int(again["tiles"][cell]["elevation"]):
				elev_same_replay = false
			eq(int(a["tiles"][cell]["elevation"]), _noise_elev(1, cell), "seed 1 elev at %s is reproducible from helper" % str(cell))
	eq(terrain_same, true, "different seeds keep the same crop terrain")
	eq(elev_diff, true, "different seeds produce different elevation")
	eq(elev_same_replay, true, "reset with the same seed reproduces elevation")

	var pinned: Dictionary = _sim.reset_match({"seed": 1, "board_size": 8, "elev_seed": 7})
	eq(pinned["seed"], 1, "elev_seed override leaves match seed 1")
	eq(pinned["elev_seed"], 7, "MatchConfig.elev_seed override is stored")
	eq(int(pinned["tiles"][Vector2i(0, 0)]["elevation"]), _noise_elev(7, Vector2i(0, 0)), "elev_seed override drives noise")
	eq(pinned["tiles"][Vector2i(4, 0)]["terrain_type"], "lava", "elev_seed override keeps crop lava")

	var crop: Dictionary = _sim.reset_match({"seed": 1, "board_size": 8, "crop_elev": true})
	eq(crop["elevation_gen"], "crop", "crop_elev skips noise")
	eq(int(crop["tiles"][Vector2i(0, 0)]["elevation"]), 3, "crop_elev keeps #38 z at (0,0)")

	var live_a: Dictionary = _sim.reset_match({})
	var live_b: Dictionary = _sim.reset_match({})
	eq(live_a["board_size"], 15, "New Match without a size is 15×15")
	eq(live_a["elevation_gen"], "tags", "New Match without a seed uses Crosshaven tags")
	eq(live_a["demo_map"], "crosshaven_15", "New Match loads Crosshaven")
	eq(live_a.has("elev_seed"), true, "New Match stores elev_seed")
	eq(int(live_a["tiles"][Vector2i(7, 4)]["elevation"]), 2, "New Match keeps tag z at (7,4)")
	eq(int(live_b["tiles"][Vector2i(7, 4)]["elevation"]), int(live_a["tiles"][Vector2i(7, 4)]["elevation"]), "two New Matches share tag elevation")
	eq(live_a["tiles"][Vector2i(1, 1)]["terrain_type"], live_b["tiles"][Vector2i(1, 1)]["terrain_type"], "two New Matches share Crosshaven terrain")
	eq(live_a["seed"] == live_b["seed"], false, "New Match generates a new seed")

	var flow := FileAccess.get_file_as_string("res://backend/match_flow.gd")
	eq(flow.contains("12×12") or flow.contains("12x12") or flow.contains("MAURO_MAP_SIZE := 12"), true, "MatchFlow names the 12×12 grid")
	eq(flow.contains("BOARD_SIZE := BoardSize.SHIP"), true, "ship board size is BoardSize.SHIP")
	eq(flow.contains("BOARD_SIZE := 8"), false, "MatchFlow does not hardcode an 8×8 ship board")


func _test_walk_facing_follows_hops() -> void:
	# Locked: facing follows each ortho hop; final facing = last hop direction.
	# H-first means last cell step is the vertical remainder when both axes move.
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(3, 2)), "E", "east hop is E")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(1, 2)), "W", "west hop is W")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(2, 3)), "S", "south hop is S")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(2, 1)), "N", "north hop is N")
	eq(_sim.facing_from_step(Vector2i(2, 2), Vector2i(3, 3)), "", "diagonal is not a hop facing")

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "N"})
	eq(_unit(0)["facing"], "N", "Kestrel starts facing N")
	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "pure-east walk is legal")
	eq(result["events"][0]["facing_from"], "N", "move event records facing before the walk")
	eq(result["events"][0]["facing_hops"], ["E", "E", "E"], "east hops face E each step")
	eq(result["events"][0]["facing"], "E", "pure-east final facing is E")
	eq(_unit(0)["facing"], "E", "actor facing is E after east walk")

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
	result = _sim.submit({"type": "move", "to": Vector2i(0, 2)})
	eq(result["events"][0]["facing_hops"], ["W", "W"], "west hops face W")
	eq(_unit(0)["facing"], "W", "pure-west final facing is W")

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
	result = _sim.submit({"type": "move", "to": Vector2i(2, 0)})
	eq(result["events"][0]["facing_hops"], ["N", "N"], "north hops face N")
	eq(_unit(0)["facing"], "N", "pure-north final facing is N")

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "W"})
	result = _sim.submit({"type": "move", "to": Vector2i(4, 3)})
	eq(result["events"][0]["path"], [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)], "NE dest is H-first E then S")
	eq(result["events"][0]["facing_hops"], ["E", "E", "S"], "H-first NE faces E then S")
	eq(_unit(0)["facing"], "S", "H-first NE final facing is last hop S")

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(4, 3), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
	result = _sim.submit({"type": "move", "to": Vector2i(2, 2)})
	eq(result["events"][0]["path"], [Vector2i(3, 3), Vector2i(2, 3), Vector2i(2, 2)], "SW dest is H-first W then N")
	eq(result["events"][0]["facing_hops"], ["W", "W", "N"], "H-first SW faces W then N")
	eq(_unit(0)["facing"], "N", "H-first SW final facing is last hop N")

	# Illegal walk does not rotate.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "S"})
	result = _sim.submit({"type": "move", "to": Vector2i(6, 2)})
	eq(result["illegal"], true, "Manhattan 4 is over budget")
	eq(_unit(0)["facing"], "S", "rejected walk leaves facing unchanged")
	eq(_unit(0)["pos"], Vector2i(2, 2), "rejected walk leaves the pawn put")

	# Manual face intent still turns in place after a walk.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7), "kestrel_facing": "E"})
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
		"flat_board": true,
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
		"flat_board": true,
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
	# Strike / Mark Shot stay Chebyshev. Advance range is cardinal (see range-gate test).
	eq(SpellKits.spell(SpellKits.MARK_SHOT).get("range_mode", ""), "chebyshev", "Mark Shot range_mode is Chebyshev")
	eq(SpellKits.spell(SpellKits.ADVANCE).get("range_mode", ""), "cardinal", "Advance range_mode is cardinal")
	eq(SpellKits.spell(SpellKits.ADVANCE).get("mp_mode", ""), "none", "Advance mp_mode is none")
	eq(SpellKits.spell(SpellKits.ADVANCE).get("move_mode", ""), "teleport", "Advance move_mode is teleport")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["ap"]), 3, "Advance costs 3 AP")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["mp"]), 0, "Advance costs 0 MP")


func _test_face_costs_zero() -> void:
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	var ap: int = int(_unit(0)["ap"])
	var result: Dictionary = _sim.submit({"type": "face", "dir": "N"})
	eq(result["ok"], true, "face accepted")
	eq(_unit(0)["facing"], "N", "facing is N")
	eq(_unit(0)["ap"], ap, "face costs 0 AP")
	eq(_unit(0)["mp"], 3, "face costs 0 MP")
	eq(_unit(0)["pos"], Vector2i(1, 1), "manual face is in-place (standing turn)")


func _test_end_turn_refills() -> void:
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
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
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(1, 0)})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(1, 0)})
	eq(result["illegal"], true, "Mark Shot range 1 is illegal")
	eq(result["reason"], "out_of_range", "out_of_range")
	eq(_unit(0)["ap"], 6, "illegal cast refunds AP")
	eq(_unit(1)["hp"], 80, "illegal cast deals no damage")
	result = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(1, 0)})
	eq(result["illegal"], true, "Kestrel Strike is not in kit")
	eq(result["reason"], "spell_not_in_kit", "spell_not_in_kit")
	eq(_unit(0)["ap"], 6, "wrong-kit cast refunds")


func _test_ambush_destination_locked() -> void:
	var gloam := Vector2i(2, 2)
	var prey := Vector2i(5, 2)
	var back := Vector2i(6, 2)
	# Neighbors other than (6,1) are blocked, so a substitute landing would use (6,1).
	var blocked_setup: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"gloam_invisible": true,
		"rolls": [1],
		"blockers": [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(5, 1), Vector2i(5, 3), back, Vector2i(6, 3)],
	})
	var ap_before := int(blocked_setup["units"][0]["ap"])
	var mp_before := int(blocked_setup["units"][0]["mp"])
	var shades_before := int(blocked_setup["units"][0]["shades"])
	var blocked: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(bool(blocked.get("illegal", false)), true, "blocked back tile is an illegal Ambush")
	eq(bool(blocked.get("ok", true)), false, "blocked back is not a resolved cast")
	eq(str(blocked.get("reason", "")), "no_landing", "blocked back refunds as no_landing")
	eq(_unit(0)["pos"], gloam, "blocked back leaves Gloam on the cast cell")
	eq(int(_unit(0)["ap"]), ap_before, "blocked back refunds AP")
	eq(int(_unit(0)["mp"]), mp_before, "blocked back does not spend MP")
	eq(int(_unit(0)["shades"]), shades_before, "blocked back does not spend Shade")
	eq(bool(_unit(0)["shade"]), true, "blocked back keeps Shade")
	eq(bool(_unit(0)["invisible"]), true, "blocked back keeps Invisible")
	eq(int(_unit(1)["hp"]), 80, "blocked back deals no damage")
	eq(_unit(1)["pos"], prey, "blocked back does not move the target")

	var miss_setup: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"gloam_invisible": true,
		"rolls": [100],
	})
	var shades_miss := int(miss_setup["units"][0]["shades"])
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(bool(missed.get("ok", false)), true, "Ambush miss on a legal back tile resolves")
	eq(bool(missed.get("illegal", true)), false, "Ambush miss is not an illegal cast")
	eq(_unit(0)["pos"], gloam, "Ambush miss does not teleport")
	eq(int(_unit(0)["ap"]), 2, "Ambush miss spends 4 AP")
	eq(int(_unit(0)["mp"]), 3, "Ambush miss does not spend MP")
	eq(int(_unit(0)["shades"]), shades_miss, "Ambush miss keeps the Shade token")
	eq(bool(_unit(0)["shade"]), true, "Ambush miss keeps Shade")
	eq(bool(_unit(0)["invisible"]), true, "Ambush miss keeps Invisible")
	eq(int(_unit(1)["hp"]), 80, "Ambush miss deals no damage")
	var miss_event: Dictionary = missed["events"][0]
	eq(str(miss_event.get("type", "")), "miss", "Ambush miss emits miss")
	eq(bool(miss_event.get("teleported", true)), false, "Ambush miss teleported is false")
	eq(miss_event.has("destination"), false, "Ambush miss emits no destination")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"gloam_shade": true,
		"rolls": [1],
	})
	var shades_hit := int(_unit(0)["shades"])
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(bool(hit.get("ok", false)), true, "Ambush hit on an empty back tile resolves")
	eq(_unit(0)["pos"], back, "Invisible Ambush lands on the empty back tile")
	eq(int(_unit(0)["shades"]), shades_hit, "Invisible origin does not spend Shade")
	eq(bool(_unit(0)["invisible"]), true, "Ambush hit keeps Invisible")
	eq(int(_unit(1)["hp"]), 50, "empty back hit is 22 × 1.35 = 30")
	var hit_event: Dictionary = hit["events"][0]
	eq(hit_event.get("destination"), back, "Ambush hit destination is the back tile")
	eq(bool(hit_event.get("backstab", false)), true, "empty back tile is a backstab")
	eq(bool(hit_event.get("teleported", false)), true, "Ambush hit teleports")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	var planted: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(4, 2), "seat": 0})
	eq(bool(planted.get("ok", false)), true, "Shade-origin fixture plants a Shade inside 1–4 of the prey")
	var shade_hit: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(bool(shade_hit.get("ok", false)), true, "Shade-origin Ambush hit on an empty back tile resolves")
	eq(_unit(0)["pos"], back, "Shade-origin Ambush lands on the empty back tile")
	eq(int(_unit(0)["shades"]), 0, "Shade origin spends one Shade on hit")
	eq(int(_unit(1)["hp"]), 50, "Shade-origin back hit is 22 × 1.35 = 30")


func _test_ambush_arms_at_zero_mp() -> void:
	# Playtest 0.1.6: Walk at MP 0 coaches a move reject. Ambush is 4 AP / 0 MP
	# and stays grey until it is legal. 1 AP still cannot arm it.
	var gloam := Vector2i(2, 2)
	var prey := Vector2i(5, 2)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	var planted: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(4, 2), "seat": 0})
	eq(bool(planted.get("ok", false)), true, "MP 0 fixture plants a Shade inside Ambush range")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["ap"]), 4, "Ambush cost stays 4 AP")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["mp"]), 0, "Ambush cost stays 0 MP")
	eq(int(SpellKits.spell(SpellKits.FADE)["mp"]), 1, "Fade still costs 1 MP")
	var actor := _live_unit(0)
	actor["mp"] = 0
	actor["ap"] = 4
	actor["exit_tax"] = 1
	eq(_has_legal_move(0), false, "MP 0 with exit tax offers no walk")
	eq(_has_legal_cast(0, SpellKits.FADE), false, "Fade stays blocked on its own 1 MP")
	eq(_has_legal_cast(0, SpellKits.AMBUSH), true, "Ambush is legal at MP 0 with 4 AP and a Shade")
	eq(_has_legal_cast_to(0, SpellKits.AMBUSH, prey), true, "Ambush dest is the enemy, not a walk tile")
	var hud := CombatHUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	var ambush_button: Button = hud._spell_buttons[SpellKits.AMBUSH]
	eq(ambush_button.disabled, false, "Ambush arms on the cluster at MP 0")
	eq(ambush_button.modulate, CombatHUD.AMBUSH_SHADE_MODULATE, "legal Ambush keeps the shade highlight on Walk")
	truthy(hud._selected_label.text.contains(CombatHUD.AMBUSH_SHADE_TIP), "Walk names Ambush when the cast is legal")
	hud.free()
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(bool(hit.get("ok", false)), true, "Ambush resolves at MP 0")
	eq(str(hit.get("reason", "")), "", "Ambush at MP 0 is not an insufficient_mp reject")
	eq(_unit(0)["pos"], Vector2i(6, 2), "Shade-origin Ambush still lands on the empty back tile")
	eq(int(_unit(0)["ap"]), 0, "Ambush at MP 0 spends 4 AP")
	eq(int(_unit(0)["mp"]), 0, "Ambush at MP 0 spends 0 MP")
	eq(int(_unit(0)["shades"]), 0, "Shade origin still spends one Shade on hit")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
	})
	actor = _live_unit(0)
	actor["mp"] = 0
	actor["ap"] = 1
	eq(_has_legal_cast(0, SpellKits.AMBUSH), false, "1 AP does not arm Ambush")
	var walked: Dictionary = _sim.submit({"type": "move", "to": Vector2i(2, 3), "seat": 0})
	eq(str(walked.get("reason", "")), "insufficient_mp", "a walk at MP 0 is still an illegal move")
	eq(bool(walked.get("ok", true)), false, "the walk reject is not a resolved Ambush")
	var walk_coach := str(walked.get("snapshot", {}).get("coach", ""))
	eq(walk_coach, "REJECT — no MP to walk.", "MP 0 names the walk, not a failed cast")
	eq(walk_coach.contains("Ambush"), false, "the walk toast does not name Ambush")
	var grey_hud := CombatHUD.new()
	grey_hud._build()
	grey_hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(grey_hud._selected_label.text.contains(CombatHUD.AMBUSH_SHADE_TIP), false, "Walk at 0 MP does not say Ambush from Shade")
	var grey: Button = grey_hud._spell_buttons[SpellKits.AMBUSH]
	eq(grey.disabled, true, "Ambush stays grey when it is not a legal cast")
	eq(grey.modulate == CombatHUD.AMBUSH_SHADE_MODULATE, false, "a grey Ambush does not wear the shade highlight")
	grey_hud._selected_spell = SpellKits.AMBUSH
	grey_hud._update_selected_label()
	truthy(grey_hud._selected_label.text.contains(CombatHUD.AMBUSH_SHADE_TIP), "selecting Ambush shows the shade tip")
	grey_hud.free()
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var click_idx := view.find("func _handle_left_click")
	var next_idx := view.find("func _advance_click_accepted")
	var click_src := view.substr(click_idx, next_idx - click_idx)
	truthy(click_src.contains("_submit({\"type\": \"move\""), "Walk still submits a move when no spell is selected")


func _test_ambush_origin_chrome() -> void:
	# Chrome only. Ambush stays 4 AP / 0 MP / 22. Drop Shade stays a placement.
	# A live Shade is the aim origin. Invisible aims from Gloam and ignores the Shade.
	var gloam := Vector2i(2, 2)
	var prey := Vector2i(5, 2)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
	})
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["ap"]), 4, "origin chrome does not change Ambush AP")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["mp"]), 0, "origin chrome does not change Ambush MP")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["base_damage"]), 22, "origin chrome does not change Ambush damage")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["ap"]), 1, "origin chrome does not change Drop Shade AP")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["mp"]), 0, "origin chrome does not change Drop Shade MP")
	var shade_cell: Vector2i = _sim.snapshot()["shade_tokens"][0]["pos"]
	var chebyshev_shade := int(_sim.chebyshev(shade_cell, prey))
	var origin: Dictionary = _sim.ambush_origin(0)
	eq(bool(origin.get("show", false)), true, "a live Shade opens Ambush origin chrome")
	eq(bool(origin.get("from_self", true)), false, "a Shade origin is not Gloam")
	eq(origin.get("origin"), shade_cell, "Ambush origin chrome uses the Shade tile")
	var landing: Dictionary = _sim.ambush_landing_preview(0)
	eq(bool(landing.get("ok", false)), true, "Ambush aim preview names the empty back tile")
	eq(landing.get("cell"), Vector2i(6, 2), "Ambush aim preview lands on the locked back tile")
	var aim: Dictionary = _sim.aim_hit_preview(0, SpellKits.AMBUSH, shade_cell)
	eq(bool(aim.get("show", false)), true, "Ambush aim preview shows the locked hit percent")
	eq(int(aim.get("hit_chance", 0)), _sim.hit_chance(chebyshev_shade), "Ambush percent is Chebyshev from the Shade origin")
	eq(int(aim.get("range", 0)), chebyshev_shade, "hovering the Shade does not retarget the Ambush percent")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"gloam_invisible": true,
	})
	eq(_sim.snapshot()["shade_tokens"].size() > 0, true, "Invisible keeps the planted Shade on the board")
	origin = _sim.ambush_origin(0)
	eq(bool(origin.get("from_self", false)), true, "Invisible Ambush origin is Gloam")
	eq(origin.get("origin"), gloam, "Invisible chrome does not aim from the Shade")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
	})
	origin = _sim.ambush_origin(0)
	eq(bool(origin.get("show", true)), false, "Ambush origin chrome stays off with no Shade and no Invisible")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains('set_highlight("origin")'), "the board paints the Ambush origin tile")
	truthy(view.contains('set_highlight("landing")'), "the board paints the Ambush back tile while aiming")
	var marker := FileAccess.get_file_as_string("res://board/shade_marker.gd")
	truthy(marker.contains("Ambush"), "the Shade token plate can read as the Ambush origin")
	truthy(marker.contains("Shade"), "a Shade that is not the origin still labels itself Shade")


func _test_ambush_range_from_origin() -> void:
	# GDD v0.6: Chebyshev 1–4 is origin to target. Body can sit outside that band.
	var gloam := Vector2i(2, 8)
	var prey := Vector2i(6, 2)
	var shade_at := Vector2i(4, 2)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	eq(_sim.chebyshev(gloam, prey), 6, "the body sits outside Ambush 1–4")
	eq(_sim.chebyshev(shade_at, prey), 2, "the Shade sits inside Ambush 1–4")
	var planted: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": shade_at, "seat": 0})
	eq(bool(planted.get("ok", false)), true, "Drop Shade plants the origin inside range of the prey")
	eq(_has_legal_cast(0, SpellKits.AMBUSH), true, "Ambush is legal from the Shade when the body is out of range")
	var ring: Array = _sim.range_highlight_cells(0, SpellKits.AMBUSH)
	eq(ring.has(prey), true, "the Ambush ring includes the enemy measured from the Shade")
	eq(ring.has(Vector2i(0, 8)), false, "a tile near the body and far from the Shade is outside the ring")
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(bool(hit.get("ok", false)), true, "Ambush resolves from a Shade inside 1–4")
	eq(int(hit["events"][0].get("range", -1)), 2, "the roll distance is Shade to enemy")
	eq(_unit(0)["pos"], Vector2i(7, 2), "Shade-origin Ambush still lands on the empty back tile")
	eq(int(_unit(0)["shades"]), 0, "Shade origin still spends the Shade")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["ap"]), 4, "origin range does not change Ambush AP")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["base_damage"]), 22, "origin range does not change Ambush damage")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(2, 2), prey],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	var far_shade := Vector2i(0, 2)
	eq(_sim.chebyshev(Vector2i(2, 2), prey), 4, "this body is inside 1–4")
	eq(_sim.chebyshev(far_shade, prey), 6, "this Shade is outside 1–4")
	var far_plant: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": far_shade, "seat": 0})
	eq(bool(far_plant.get("ok", false)), true, "Drop Shade can plant outside Ambush range")
	eq(_has_legal_cast(0, SpellKits.AMBUSH), false, "a far Shade does not arm Ambush just because the body is in range")
	var rejected: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(str(rejected.get("reason", "")), "out_of_range", "Shade-origin range reject is out_of_range")
	_live_unit(0)["invisible"] = true
	eq(_has_legal_cast(0, SpellKits.AMBUSH), true, "Invisible Ambush uses the body, ignoring the far Shade")


func _test_miss_keeps_ap_no_engine() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
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
		"flat_board": true,
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
	eq(int(SpellKits.spell(SpellKits.MARK_SHOT)["min_range"]), 2, "Mark Shot min range stays 2")
	eq(int(SpellKits.spell(SpellKits.MARK_SHOT)["max_range"]), 7, "Mark Shot max range 7 Chebyshev")
	eq(int(SpellKits.spell(SpellKits.MARK_SHOT)["base_damage"]), 8, "Mark Shot base damage stays 8")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1, 1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(5, 0),
	})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(5, 0)})
	eq(result["ok"], true, "Mark Shot at range 5 is legal")
	eq(_unit(1)["hp"], 72, "8 Air on connect")
	eq(_unit(1)["marks"], 1, "Marks stored on the target (A01 Locked)")
	eq(result["events"][0]["hit_chance"], 75, "range 5 uses the 75% mid band")
	for dist in [6, 7]:
		_sim.reset_match({
			"seed": 1,
			"flat_board": true,
			"rolls": [1],
			"kestrel_pos": Vector2i(0, 0),
			"ironjaw_pos": Vector2i(dist, 0),
		})
		result = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(dist, 0)})
		eq(result["ok"], true, "Mark Shot at range %d is legal" % dist)
		eq(_unit(1)["hp"], 72, "8 Air on connect at range %d" % dist)
		eq(_unit(1)["marks"], 1, "Marks stored on the target at range %d" % dist)
		eq(result["events"][0]["hit_chance"], 70, "range %d uses the 70%% long band" % dist)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(8, 0),
	})
	result = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(8, 0)})
	eq(result["illegal"], true, "Mark Shot range 8 is illegal")
	eq(result["reason"], "out_of_range", "range 8 reject is out_of_range")
	eq(_unit(0)["ap"], 6, "range reject refunds")


func _test_advance_impact_adjacency() -> void:
	# Land on (3,0), Chebyshev 1 from Kestrel at (4,0). The hop is Manhattan 2.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(4, 0),
		"ironjaw_pos": Vector2i(1, 0),
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 0)})
	eq(result["ok"], true, "Ironjaw Advance two cardinal tiles with no roll")
	eq(_unit(1)["pos"], Vector2i(3, 0), "dash landed")
	eq(_unit(1)["ap"], 3, "Advance spends 3 AP")
	eq(_unit(1)["mp"], 3, "Advance spends 0 MP")
	eq(_unit(1)["impact"], 1, "ending Chebyshev 1 to Kestrel grants Impact")
	eq(_unit(0)["impact"], 0, "Kestrel never gains Impact")
	eq(result["events"][0]["rolled"], false, "Advance never rolls")
	eq(result["events"][0]["teleport"], true, "Advance event is a teleport")
	eq(result["events"][0].has("path"), false, "Advance event has no hop path")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
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
	var locked := {
		1: 90, 2: 80, 3: 80, 4: 75, 5: 75,
		6: 70, 7: 70, 8: 70,
		9: 65, 10: 60, 11: 55, 12: 50, 13: 45, 14: 40,
	}
	eq(_sim.hit_chance(1), 90, "melee 90%")
	eq(_sim.hit_chance(2), 80, "short 80%")
	eq(_sim.hit_chance(3), 80, "short 80% at 3")
	eq(_sim.hit_chance(4), 75, "mid 75% at 4")
	eq(_sim.hit_chance(5), 75, "mid 75% at 5")
	eq(_sim.hit_chance(6), 70, "long 70% at 6")
	eq(_sim.hit_chance(7), 70, "long 70% at 7")
	eq(_sim.hit_chance(8), 70, "long 70% at 8")
	eq(_sim.hit_chance(9), 65, "Chebyshev 9 is Locked 65%")
	eq(_sim.hit_chance(10), 60, "Chebyshev 10 is Locked 60%")
	eq(_sim.hit_chance(11), 55, "Chebyshev 11 is Locked 55%")
	eq(_sim.hit_chance(12), 50, "Chebyshev 12 is Locked 50%")
	eq(_sim.hit_chance(12) == 70, false, "dist 12 is not the old ≥6 clamp of 70%")
	eq(_sim.hit_chance(13), 45, "Chebyshev 13 is Locked 45%")
	eq(_sim.hit_chance(14), 40, "Chebyshev 14 is Locked 40%")
	eq(_sim.hit_chance(15), -1, "Chebyshev 15 has no invented hit percent")
	eq(_sim.hit_chance(0), 90, "self dist 0 shares the melee 90% band")
	var bands = load("res://backend/hit_bands.gd")
	for dist in [1, 2, 4, 6, 9, 10, 11, 12, 13, 14]:
		eq(bands.chance(dist), int(locked[dist]), "HitBands breakpoint %d" % dist)
		eq(_sim.hit_chance(dist), bands.chance(dist), "resolve hit_chance matches HitBands at %d" % dist)
		eq(CombatHUD.aim_hit_caption(int(locked[dist])), "HIT %d%%" % int(locked[dist]), "aim caption for dist %d" % dist)
	eq(CombatHUD.aim_hit_caption(-1), "", "aim caption hides a missing band")
	var band_src := FileAccess.get_file_as_string("res://backend/hit_bands.gd")
	eq(band_src.contains("9: 65"), true, "HitBands locks dist 9 at 65")
	eq(band_src.contains("14: 40"), true, "HitBands locks dist 14 at 40")
	eq(band_src.contains("is_open"), false, "HitBands no longer soft-blocks 9–14")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("is_open"), false, "CombatSim no longer rejects 9–14 as open")
	eq(sim_src.contains("BOARD_SIZE := 8"), false, "CombatSim BOARD_SIZE is not 8")
	var size_src := FileAccess.get_file_as_string("res://backend/board_size.gd")
	eq(size_src.contains("SHIP := 15"), true, "ship board constant is 15")
	eq(size_src.contains("SHIP := 12"), false, "ship board is not 12")

	_assert_aim_matches_resolve(1, SpellKits.STRIKE, 90)
	_assert_aim_matches_resolve(2, SpellKits.MARK_SHOT, 80)
	_assert_aim_matches_resolve(4, SpellKits.MARK_SHOT, 75)
	_assert_aim_matches_resolve(4, SpellKits.DETONATE, 75)
	_assert_aim_matches_resolve(6, SpellKits.MARK_SHOT, 70)
	_assert_aim_matches_resolve(7, SpellKits.MARK_SHOT, 70)
	for dist in [9, 10, 11, 12, 13, 14]:
		_assert_far_band_chrome(dist, int(locked[dist]))
	_assert_past_locked_band()


func _assert_aim_matches_resolve(dist: int, spell_id: String, chance: int) -> void:
	var ironjaw_acts := spell_id == SpellKits.STRIKE or spell_id == SpellKits.SHOULDER or spell_id == SpellKits.CRUSH
	var kestrel_pos := Vector2i(dist, 0) if ironjaw_acts else Vector2i(0, 0)
	var ironjaw_pos := Vector2i(0, 0) if ironjaw_acts else Vector2i(dist, 0)
	var target := kestrel_pos if ironjaw_acts else ironjaw_pos
	var seat := 1 if ironjaw_acts else 0
	var cfg := {
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": kestrel_pos,
		"ironjaw_pos": ironjaw_pos,
	}
	if spell_id == SpellKits.DETONATE:
		cfg["ironjaw_marks"] = 1
	_sim.reset_match(cfg)
	if ironjaw_acts:
		_sim.submit({"type": "end_turn"})
	var preview: Dictionary = _sim.aim_hit_preview(seat, spell_id, target)
	eq(preview["show"], true, "aim chrome shows Locked %% at dist %d" % dist)
	eq(preview["range"], dist, "aim range is Chebyshev %d" % dist)
	eq(preview["hit_chance"], chance, "aim chrome Locked %% at dist %d" % dist)
	eq(preview["hit_chance"], _sim.hit_chance(dist), "aim chrome matches hit_chance at dist %d" % dist)
	var hud := CombatHUD.new()
	hud._build()
	hud.set_aim_preview(preview)
	eq(hud._aim_hit_label.text, "HIT %d%%" % chance, "HUD aim label shows Locked %% at dist %d" % dist)
	eq(hud._aim_hit_label.visible, true, "HUD aim label is visible at dist %d" % dist)
	hud.free()
	var result: Dictionary = _sim.submit({"type": "cast", "spell": spell_id, "to": target})
	eq(result["ok"], true, "in-range cast at dist %d resolves" % dist)
	eq(result["events"][0]["hit_chance"], chance, "resolve uses Locked %% at dist %d" % dist)
	eq(result["events"][0]["hit_chance"], preview["hit_chance"], "aim chrome and resolve agree at dist %d" % dist)


func _assert_far_band_chrome(dist: int, chance: int) -> void:
	var target := Vector2i(dist, 0)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": target,
		"ironjaw_marks": 1,
	})
	eq(_sim.chebyshev(Vector2i(0, 0), target), dist, "fixture Chebyshev is %d" % dist)
	var preview: Dictionary = _sim.aim_hit_preview(0, SpellKits.MARK_SHOT, target)
	eq(preview["range"], dist, "far aim range is Chebyshev %d" % dist)
	eq(preview["show"], true, "aim chrome shows Locked %% at dist %d" % dist)
	eq(preview["hit_chance"], chance, "aim chrome Locked %% at dist %d" % dist)
	eq(preview["hit_chance"], _sim.hit_chance(dist), "aim chrome matches resolve table at dist %d" % dist)
	var cast_preview: Dictionary = _sim.preview_cast(SpellKits.MARK_SHOT, Vector2i(0, 0), target, 1)
	eq(cast_preview["hit_chance"], chance, "preview_cast uses the same Locked %% at dist %d" % dist)
	eq(cast_preview["in_range"], false, "Mark Shot max range still rejects dist %d" % dist)
	var hud := CombatHUD.new()
	hud._build()
	hud.set_aim_preview(preview)
	eq(hud._aim_hit_label.text, "HIT %d%%" % chance, "HUD shows Locked %% at dist %d" % dist)
	eq(hud._aim_hit_label.visible, true, "HUD aim label is visible at dist %d" % dist)
	hud.free()
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": target})
	eq(result["illegal"], true, "dist %d Mark Shot is illegal" % dist)
	eq(result["reason"], "out_of_range", "dist %d reject is ordinary out_of_range" % dist)
	eq(result["events"][0].has("hit_chance"), false, "dist %d reject carries no rolled hit chance" % dist)
	eq(str(result["events"][0]["coach"]).contains("open"), false, "dist %d coach does not call the band open" % dist)
	eq(_unit(0)["ap"], 6, "dist %d Mark Shot refunds AP" % dist)
	eq(_unit(1)["hp"], 80, "dist %d Mark Shot deals no damage" % dist)
	eq(_unit(1)["marks"], 1, "dist %d Mark Shot does not roll onto Marks" % dist)
	var detonate: Dictionary = _sim.submit({"type": "cast", "spell": "detonate", "to": target})
	eq(detonate["illegal"], true, "dist %d Detonate stays outside kit range" % dist)
	eq(detonate["reason"], "out_of_range", "dist %d Detonate reject is out_of_range" % dist)
	eq(_unit(0)["ap"], 6, "dist %d Detonate refunds AP" % dist)
	eq(_unit(1)["marks"], 1, "dist %d Detonate does not consume Marks" % dist)
	eq(_unit(1)["hp"], 80, "dist %d Detonate deals no damage" % dist)


func _assert_past_locked_band() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"board_size": 20,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(15, 0),
	})
	eq(_sim.hit_chance(15), -1, "dist 15 still has no invented percent")
	eq(_sim.hit_chance(15) == 70, false, "dist 15 is not clamped to 70%")
	var past: Dictionary = _sim.aim_hit_preview(0, SpellKits.MARK_SHOT, Vector2i(15, 0))
	eq(past["show"], false, "aim chrome hides a percent past 14")
	eq(int(past["hit_chance"]) < 0, true, "aim preview does not invent a percent past 14")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(15, 0)})
	eq(result["illegal"], true, "dist 15 Mark Shot is illegal")
	eq(result["events"][0].has("hit_chance"), false, "dist 15 reject carries no hit chance")
	eq(_unit(0)["ap"], 6, "dist 15 Mark Shot refunds AP")


func _test_class_kits() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
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
		"flat_board": true,
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
	_sim.reset_match({"seed": 1, "skip_deploy": true})
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
	_sim.reset_match({"seed": 1, "skip_deploy": true})
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
	# Exactly 2 cardinal spaces. Teleport spends 3 AP / 0 MP.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(2, 2)})
	_sim.submit({"type": "end_turn"})
	eq(_sim.manhattan(Vector2i(2, 2), Vector2i(4, 2)), 2, "Advance east dest is Manhattan 2")
	eq(_sim.chebyshev(Vector2i(2, 2), Vector2i(4, 2)), 2, "Advance east dest is Chebyshev 2")
	eq(_sim.is_advance_cardinal(Vector2i(2, 2), Vector2i(4, 2)), true, "two east is an Advance cardinal")
	eq(_sim.is_cardinal_step(Vector2i(2, 2), Vector2i(3, 2)), true, "the tile between is still one cardinal step")
	eq(_sim.is_advance_cardinal(Vector2i(2, 2), Vector2i(3, 2)), false, "Manhattan 1 is not an Advance dest")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 2)})
	eq(result["ok"], true, "cardinal-2 Advance dest-click is legal")
	eq(_unit(1)["pos"], Vector2i(4, 2), "Ironjaw snapped two tiles east")
	eq(_unit(1)["ap"], 3, "Advance spends 3 AP")
	eq(_unit(1)["mp"], 3, "Advance spends 0 MP")
	eq(result["events"][0]["mp_spent"], 0, "advance event spends 0 MP")
	eq(result["events"][0]["ap_spent"], 3, "advance event spends 3 AP")
	eq(result["events"][0]["teleport"], true, "Advance is a teleport snap")
	eq(result["events"][0].has("path"), false, "Advance event has no hop path")
	eq(result["events"][0]["rolled"], false, "Advance never rolls")
	eq(_unit(1)["facing"], "W", "cardinal Advance leaves default Face W unchanged")
	eq(result["events"][0].has("facing"), false, "Advance event does not auto-face")
	truthy(str(result["events"][0]["coach"]).contains("3 AP"), "coach names the 3 AP spend")
	eq(str(result["events"][0]["coach"]).contains("MP"), false, "coach does not mention MP spend")

	# Diagonal (1,1) is Chebyshev 1 / Manhattan 2 — rejected (not cardinal).
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(2, 2)})
	_sim.submit({"type": "end_turn"})
	eq(_sim.manhattan(Vector2i(2, 2), Vector2i(3, 3)), 2, "Advance diagonal is Manhattan 2")
	eq(_sim.chebyshev(Vector2i(2, 2), Vector2i(3, 3)), 1, "Advance diagonal is Chebyshev 1")
	eq(_sim.is_advance_cardinal(Vector2i(2, 2), Vector2i(3, 3)), false, "(1,1) is not an Advance cardinal")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 3)})
	eq(result["illegal"], true, "diagonal Advance is rejected")
	eq(result["reason"], "out_of_range", "diagonal reject is out_of_range")
	eq(_unit(1)["pos"], Vector2i(2, 2), "diagonal Advance leaves Ironjaw put")
	eq(_unit(1)["ap"], 6, "diagonal Advance refunds AP")
	eq(_unit(1)["mp"], 3, "diagonal Advance spends 0 MP")
	eq(_has_legal_advance_to(1, Vector2i(3, 3)), false, "legal_intents omit diagonal Advance")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(3, 3))["reason"], "out_of_range", "preview_cast rejects a diagonal Advance")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(3, 3))["legal"], false, "preview_cast marks diagonal Advance illegal")

	# Orthogonal Manhattan 1 is outside the 2-cardinal gate.
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 2)})
	eq(result["illegal"], true, "Manhattan 1 Advance is rejected")
	eq(result["reason"], "out_of_range", "Manhattan 1 reject is out_of_range, not MP")
	eq(_unit(1)["pos"], Vector2i(2, 2), "Manhattan 1 Advance does not move Ironjaw")
	eq(_unit(1)["ap"], 6, "Manhattan 1 Advance refunds AP")
	eq(_has_legal_advance_to(1, Vector2i(3, 2)), false, "legal_intents omit Manhattan 1 Advance")
	eq(_sim.preview_cast(SpellKits.ADVANCE, Vector2i(2, 2), Vector2i(3, 2))["in_range"], false, "preview_cast marks Manhattan 1 out of range")

	# Far diagonal stays out of range.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(0, 0)})
	_sim.submit({"type": "end_turn"})
	eq(_sim.chebyshev(Vector2i(0, 0), Vector2i(2, 2)), 2, "two-tile diagonal is Chebyshev 2")
	eq(_sim.manhattan(Vector2i(0, 0), Vector2i(2, 2)), 4, "two-tile diagonal is Manhattan 4")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 2)})
	eq(result["illegal"], true, "Chebyshev-2 diagonal Advance is rejected")
	eq(result["reason"], "out_of_range", "reject reason is out_of_range, not MP")
	eq(_unit(1)["pos"], Vector2i(0, 0), "Ironjaw did not dash")
	eq(_unit(1)["ap"], 6, "out-of-range refunds AP")
	eq(_unit(1)["mp"], 3, "out-of-range refunds MP")

	# Client path is ignored; teleport snaps to the cardinal-2 dest.
	var forged: Array = [Vector2i(0, 1), Vector2i(1, 0)]
	result = _sim.submit({
		"type": "cast",
		"spell": "advance",
		"to": Vector2i(2, 0),
		"path": forged,
	})
	eq(result["ok"], true, "Advance dest-click still accepted when a client path is supplied")
	eq(result["events"][0].has("path"), false, "CombatSim does not return a hop path for Advance")
	eq(result["events"][0]["teleport"], true, "forged client path still resolves as teleport")
	eq(result["events"][0]["mp_spent"], 0, "cardinal dest spends 0 MP")
	eq(_unit(1)["pos"], Vector2i(2, 0), "Ironjaw ends on the dest-click tile")
	eq(_unit(1)["mp"], 3, "MP pool unchanged after teleport")

	# A diagonal is out of range. An empty cardinal-2 tile still lands
	# and grants Impact when that tile is Chebyshev-adjacent to the enemy.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 1), "ironjaw_pos": Vector2i(0, 0)})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(1, 1)})
	eq(result["illegal"], true, "diagonal Advance beside an occupant is rejected")
	eq(result["reason"], "out_of_range", "diagonal beside an occupant is out_of_range")
	eq(_unit(1)["pos"], Vector2i(0, 0), "rejected diagonal does not move Ironjaw")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(0, 2)})
	eq(result["ok"], true, "empty cardinal-2 Advance is legal beside an occupant")
	eq(_unit(1)["pos"], Vector2i(0, 2), "Ironjaw snapped two tiles south")
	eq(_unit(1)["ap"], 3, "cardinal Advance still spends 3 AP")
	eq(_unit(1)["mp"], 3, "cardinal Advance spends 0 MP")
	eq(_sim.chebyshev(Vector2i(0, 2), Vector2i(2, 1)), 2, "this landing is not Chebyshev-adjacent")
	eq(_unit(1)["impact"], 0, "Chebyshev 2 landing grants no Impact")
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(2, 1), "ironjaw_pos": Vector2i(0, 0)})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 0)})
	eq(result["ok"], true, "east cardinal-2 Advance lands beside Kestrel")
	eq(_unit(1)["pos"], Vector2i(2, 0), "Ironjaw snapped two tiles east")
	eq(_sim.chebyshev(Vector2i(2, 0), Vector2i(2, 1)), 1, "landing tile is Chebyshev 1 to Kestrel")
	eq(_unit(1)["impact"], 1, "landing Chebyshev-adjacent still grants Impact")

	# 0 MP remaining: walk the pool away, then Advance still works at Manhattan 2.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(2, 2)})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(result["ok"], true, "Ironjaw can walk the 3 MP pool first")
	eq(_unit(1)["mp"], 0, "walk spent the MP pool")
	eq(_unit(1)["ap"], 6, "walk spends no AP")
	var found_diagonal := false
	var found_manhattan_1 := false
	var found_cardinal := false
	for intent in _sim.legal_intents(1):
		if str(intent.get("type", "")) != "cast" or str(intent.get("spell", "")) != "advance":
			continue
		if intent.get("to") == Vector2i(6, 3):
			found_diagonal = true
		if intent.get("to") == Vector2i(6, 2):
			found_manhattan_1 = true
		if intent.get("to") == Vector2i(7, 2):
			found_cardinal = true
	eq(found_diagonal, false, "0 MP cannot Advance to a diagonal")
	eq(found_manhattan_1, false, "0 MP cannot Advance Manhattan 1")
	truthy(found_cardinal, "0 MP can Advance exactly 2 cardinal spaces")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(7, 2)})
	eq(result["ok"], true, "cardinal Advance with 0 MP is legal")
	eq(_unit(1)["pos"], Vector2i(7, 2), "Ironjaw teleported on empty MP")
	eq(_unit(1)["mp"], 0, "Advance did not spend or refund MP")
	eq(_unit(1)["ap"], 3, "0-MP Advance still spends 3 AP")

	# Two Advances per turn (6 AP); a third is insufficient_ap.
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(7, 4)})
	eq(result["ok"], true, "second Advance spends the remaining 3 AP")
	eq(_unit(1)["ap"], 0, "two Advances empty the AP pool")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(7, 6)})
	eq(result["illegal"], true, "third Advance is rejected")
	eq(result["reason"], "insufficient_ap", "0 AP Advance is insufficient_ap")
	eq(_unit(1)["pos"], Vector2i(7, 4), "Ironjaw stays after the rejected third Advance")

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
		"flat_board": true,
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
		"flat_board": true,
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


func _test_advance_cardinal_range_gate() -> void:
	# Exactly 2 cardinal spaces around the caster:
	#   . . N . .
	#   . . . . .
	#   W . x . E
	#   . . . . .
	#   . . S . .
	var origin := Vector2i(3, 3)
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": origin})
	_sim.submit({"type": "end_turn"})
	var expected: Dictionary = {}
	for cell in [
		Vector2i(3, 1), Vector2i(3, 5), Vector2i(1, 3), Vector2i(5, 3),
	]:
		expected[cell] = true
	eq(expected.size(), 4, "cardinal Advance has 4 tiles")
	var offered: Dictionary = {}
	for intent in _sim.legal_intents(1):
		if str(intent.get("type", "")) != "cast" or str(intent.get("spell", "")) != "advance":
			continue
		offered[intent["to"]] = true
	eq(offered.size(), 4, "legal_intents Advance dests are the 4 cardinal-2 tiles")
	for cell in expected.keys():
		truthy(offered.has(cell), "cardinal tile %s is offered" % str(cell))
	for cell in offered.keys():
		truthy(expected.has(cell), "no extra Advance dest %s outside the 2-cardinal set" % str(cell))

	eq(_sim.manhattan(origin, Vector2i(4, 3)), 1, "one tile east is Manhattan 1")
	eq(offered.has(Vector2i(4, 3)), false, "Manhattan 1 ortho is not offered")
	eq(_sim.chebyshev(origin, Vector2i(4, 4)), 1, "(1,1) offset is Chebyshev 1")
	eq(_sim.manhattan(origin, Vector2i(4, 4)), 2, "(1,1) offset is Manhattan 2")
	eq(offered.has(Vector2i(4, 4)), false, "diagonal tile is not offered")
	eq(_sim.chebyshev(origin, Vector2i(4, 5)), 2, "(1,2) offset is Chebyshev 2")
	eq(_sim.manhattan(origin, Vector2i(4, 5)), 3, "(1,2) offset is Manhattan 3")
	eq(offered.has(Vector2i(4, 5)), false, "knight tile is not offered")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 3)})
	eq(result["illegal"], true, "Manhattan 1 Advance dest is rejected")
	eq(result["reason"], "out_of_range", "Manhattan 1 reject is out_of_range")
	eq(_unit(1)["pos"], origin, "Ironjaw stays put on a Manhattan 1 miss")
	eq(_unit(1)["ap"], 6, "Manhattan 1 miss refunds AP")
	eq(_unit(1)["mp"], 3, "Manhattan 1 miss refunds MP")
	eq(_sim.preview_cast(SpellKits.ADVANCE, origin, Vector2i(4, 3))["legal"], false, "preview_cast rejects Manhattan 1")

	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 4)})
	eq(result["illegal"], true, "diagonal Advance dest is rejected")
	eq(result["reason"], "out_of_range", "diagonal reject is out_of_range")
	eq(_sim.preview_cast(SpellKits.ADVANCE, origin, Vector2i(4, 4))["reason"], "out_of_range", "preview_cast rejects a diagonal")

	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 5)})
	eq(result["illegal"], true, "knight Advance dest is rejected")
	eq(result["reason"], "out_of_range", "knight tile reject is out_of_range")

	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "two-tile cardinal Advance is legal")
	eq(_unit(1)["pos"], Vector2i(5, 3), "Ironjaw snapped two tiles east")
	eq(_unit(1)["mp"], 3, "cardinal teleport spends 0 MP")
	eq(_unit(1)["ap"], 3, "Advance spends 3 AP")
	eq(result["events"][0]["teleport"], true, "east dest is a teleport snap")
	eq(result["events"][0].has("path"), false, "east dest has no hop path")

	# Highlights come from legal_intents; board_view paints Advance dests as "advance".
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("legal_intents"), "board highlights come from CombatSim legal_intents")
	truthy(view.contains('highlight := "advance"'), "Advance dests use advance highlight")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud.contains("Chebyshev"), false, "selected label does not name Chebyshev")
	truthy(hud.contains("SpellKits.range_text"), "selected label uses player-facing range_text")
	var kits := FileAccess.get_file_as_string("res://data/kits.gd")
	truthy(kits.contains("Manhattan"), "kit range_text still names Manhattan")
	eq(SpellKits.range_text(SpellKits.spell(SpellKits.ADVANCE)), "exactly 2 cardinal", "Advance selected range is exactly 2 cardinal")
	eq(SpellKits.range_text(SpellKits.spell(SpellKits.MARK_SHOT)), "range 2–7", "Mark Shot selected range omits Chebyshev")
	eq(hud.contains("%d AP + Manhattan MP"), false, "HUD no longer advertises Manhattan MP for Advance")
	eq(hud.contains("%dAP + MP"), false, "HUD Advance button is not AP + MP")
	eq(hud.contains("Detonate"), false, "range patch does not add Detonate")
	eq(hud.contains("Shoulder"), false, "range patch does not add Shoulder")
	eq(hud.contains("Crush"), false, "range patch does not add Crush")


func _test_advance_chrome_follows_legal_intents() -> void:
	# Board / HUD / range helper paint Advance only from legal_intents.
	var origin := Vector2i(3, 3)
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": origin})
	_sim.submit({"type": "end_turn"})
	var legal: Array = _sim.legal_intents(1)
	var painted: Array[Vector2i] = SnapshotTiles.cast_dests(legal, SpellKits.ADVANCE)
	var ring: Array = _sim.range_highlight_cells(1, SpellKits.ADVANCE)
	eq(painted.size(), 4, "Advance chrome lists the 4 cardinal-2 tiles")
	eq(ring.size(), painted.size(), "range highlighter matches legal Advance dests")
	for cell in painted:
		truthy(_sim.is_advance_cardinal(origin, cell), "highlighted Advance dest %s is exactly 2 cardinal" % str(cell))
		truthy(ring.has(cell), "range highlighter includes legal dest %s" % str(cell))
	eq(painted.has(Vector2i(4, 3)), false, "Manhattan 1 is not an Advance highlight")
	eq(painted.has(Vector2i(5, 3)), true, "Manhattan 2 east is an Advance highlight")
	eq(painted.has(Vector2i(4, 4)), false, "diagonal is not an Advance highlight")
	eq(ring.has(Vector2i(4, 3)), false, "range highlighter omits Manhattan 1")
	eq(ring.has(Vector2i(4, 4)), false, "range highlighter omits a diagonal")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": origin,
		"tiles": [
			{"pos": Vector2i(3, 1), "terrain": "lava", "elevation": 0},
			{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0},
			{"pos": Vector2i(3, 5), "terrain": "lava", "elevation": 0},
		],
	})
	_sim.submit({"type": "end_turn"})
	legal = _sim.legal_intents(1)
	painted = SnapshotTiles.cast_dests(legal, SpellKits.ADVANCE)
	ring = _sim.range_highlight_cells(1, SpellKits.ADVANCE)
	eq(painted.size(), 1, "illegal stand-on dests drop out of Advance chrome")
	eq(painted[0], Vector2i(1, 3), "the open west cardinal is the only Advance highlight")
	eq(ring.has(Vector2i(3, 1)), false, "lava north is not an Advance highlight")
	eq(ring.has(Vector2i(5, 3)), false, "lava east is not an Advance highlight")
	eq(ring.has(Vector2i(4, 3)), false, "Manhattan 1 stays unhighlighted beside lava")
	eq(ring.has(Vector2i(4, 4)), false, "diagonal stays unhighlighted beside lava")

	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 4)})
	eq(result["illegal"], true, "diagonal Advance click is rejected")
	eq(result["reason"], "out_of_range", "diagonal reject stays out_of_range")
	eq(_unit(1)["pos"], origin, "diagonal click does not move Ironjaw")
	eq(_unit(1)["ap"], 6, "diagonal click refunds AP")
	truthy(str(result["snapshot"].get("coach", "")).contains("refund"), "diagonal click uses the existing refund coach")
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 3)})
	eq(result["illegal"], true, "Manhattan 1 Advance click is rejected")
	eq(_unit(1)["ap"], 6, "Manhattan 1 click refunds AP")
	eq(_unit(1)["mp"], 3, "Manhattan 1 click spends 0 MP")
	truthy(str(_sim.snapshot().get("coach", "")).contains("refund"), "Manhattan 1 click uses the existing refund coach")

	var hud_node := CombatHUD.new()
	hud_node._build()
	hud_node.set_preview_source(_sim)
	hud_node.render(_sim.snapshot(), legal)
	eq(hud_node._advance_hover_dest(origin), Vector2i(1, 3), "Advance hover samples the sim-legal dest")
	var preview: Dictionary = hud_node.preview_for_spell(SpellKits.ADVANCE)
	eq(preview["legal"], true, "hover preview_cast uses a legal Advance dest")
	eq(preview["reason"], "", "hover preview has no reject reason")
	hud_node.free()

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("cast_dests"), "board paints Advance from cast_dests")
	truthy(view.contains('highlight := "advance"'), "Advance dests use advance highlight")
	truthy(view.contains("_advance_click_accepted"), "Advance clicks are gated on sim-legal dests")
	var click_idx := view.find("func _handle_left_click")
	var face_idx := view.find("func _face_toward")
	var click_src := view.substr(click_idx, face_idx - click_idx)
	truthy(click_src.contains("_submit("), "an off-set Advance click still reaches submit for the refund coach")
	eq(click_src.contains("Vector2i(1, 1)"), false, "click handler does not hardcode a diagonal hop")
	eq(click_src.contains("Vector2i(2, 0)"), false, "click handler does not hardcode Manhattan 2")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("cast_dests"), "HUD Advance hover reads cast_dests")
	eq(hud_src.contains("Vector2i(1, 0)"), false, "HUD does not scan client orthogonal deltas")
	eq(hud_src.contains("Vector2i(1, 1)"), false, "HUD does not scan client diagonal hops")
	eq(hud_src.contains("Chebyshev"), false, "HUD still does not name Chebyshev")


func _test_mark_shot_range_highlights() -> void:
	# Selecting Mark Shot must show the Chebyshev 2–7 ring, not only the enemy tile.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(3, 3), "ironjaw_pos": Vector2i(5, 3)})
	var origin := Vector2i(3, 3)
	var expected: Dictionary = {}
	var board_n := int(_sim.snapshot().get("board_size", 15))
	for y in range(board_n):
		for x in range(board_n):
			var cell := Vector2i(x, y)
			if cell == origin:
				continue
			var dist := int(_sim.chebyshev(origin, cell))
			if dist >= 2 and dist <= 7:
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
	eq(painted.size(), expected.size(), "range_highlight_cells matches Chebyshev 2–7")
	for cell in expected.keys():
		truthy(painted.has(cell), "Chebyshev ring tile %s is highlighted" % str(cell))
	for cell in painted.keys():
		truthy(expected.has(cell), "no extra Mark Shot chrome %s outside 2–7" % str(cell))

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

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
	var has_r5 := false
	var has_r6 := false
	var has_r7 := false
	var has_r8 := false
	var has_r1 := false
	for cell in _sim.range_highlight_cells(0, SpellKits.MARK_SHOT):
		var dist := int(_sim.chebyshev(Vector2i(0, 0), cell))
		if dist == 5:
			has_r5 = true
		if dist == 6:
			has_r6 = true
		if dist == 7:
			has_r7 = true
		if dist == 8:
			has_r8 = true
		if dist == 1:
			has_r1 = true
	truthy(has_r5, "Chebyshev 5 tiles are in Mark Shot chrome")
	truthy(has_r6, "Chebyshev 6 is inside Mark Shot chrome")
	truthy(has_r7, "Chebyshev 7 is inside Mark Shot chrome")
	eq(has_r8, false, "Chebyshev 8 is outside Mark Shot chrome")
	eq(has_r1, false, "Chebyshev 1 is outside Mark Shot chrome")

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("range_highlight_cells"), "board_view paints range rings from range_highlight_cells")
	truthy(view.contains('set_highlight("range")'), "enemy-spell ring uses range highlight")
	truthy(view.contains("empty_tile"), "empty-tile spells such as Drop Shade paint a range ring")
	truthy(view.contains("_stamp_range_rim"), "Drop Shade keeps a gold rim on the max-range shell")
	truthy(view.contains("_sync_shade_markers"), "a resolved Drop Shade places a board token")
	truthy(view.contains("ShadeMarkers"), "Shade markers live on their own layer")
	truthy(view.contains("_shade_layer"), "refresh parents Shade markers off Units")
	eq(view.contains("$Units.add_child(marker)"), false, "pawn rebuild cannot free a Shade marker parented under Units")
	truthy(view.contains("kind == \"move\" and spell_id == \"\""), "walk highlights stay off while a spell is selected")
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	truthy(tile_src.contains("\"range\""), "tiles have a range highlight color")
	eq(view.contains("Detonate"), false, "Mark Shot chrome does not add Detonate")
	eq(view.contains("Shoulder"), false, "Mark Shot chrome does not add Shoulder")
	eq(view.contains("Crush"), false, "Mark Shot chrome does not add Crush")


func _test_turn_clock_auto_end_turn() -> void:
	eq(TurnClock.DURATION_SEC, 30.0, "display helper is 30s; keep in sync with CombatSim.TURN_TIME_LIMIT")
	eq(is_equal_approx(float(_sim.TURN_TIME_LIMIT), TurnClock.DURATION_SEC), true, "CombatSim.TURN_TIME_LIMIT matches TurnClock.DURATION_SEC")
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
	clock.hydrate(12.2, true, 30.0)
	eq(clock.display_seconds(), 13, "hydrate ceils remaining for the HUD")
	eq(is_equal_approx(clock.fraction_left(), 12.2 / 30.0), true, "hydrate uses snapshot limit for the bar")

	# Host tick expiry submits the same end_turn as the HUD button, not a second rule.
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	eq(_sim.snapshot()["active_seat"], 0, "Kestrel starts")
	eq(int(_sim.snapshot()["turn_time_seconds"]), 30, "fresh host clock shows 30")
	var mid: Dictionary = _sim.tick_turn_timer(29.0)
	eq(bool(mid.get("expired", false)), false, "29s elapsed is still Kestrel")
	eq(_sim.snapshot()["active_seat"], 0, "seat unchanged before expiry")
	eq(int(_sim.snapshot()["turn_time_seconds"]), 1, "ceil remaining shows 1s left")
	var result: Dictionary = _sim.tick_turn_timer(1.0)
	eq(result["ok"], true, "clock expiry uses the same end_turn submit")
	eq(bool(result.get("expired", false)), true, "tick reports expired")
	eq(_sim.snapshot()["active_seat"], 1, "end_turn on expiry hands the seat to Ironjaw")
	eq(_unit(1)["ap"], 6, "next seat refills AP after auto end-turn")
	eq(_unit(1)["mp"], 3, "next seat refills MP after auto end-turn")
	eq(int(_sim.snapshot()["turn_time_seconds"]), 30, "next seat clock starts at 30s")
	var timer_event := {}
	for event in result.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "end_turn":
			timer_event = event
			break
	eq(str(timer_event.get("reason", "")), "timer", "expiry end_turn reason is timer")
	eq(bool(timer_event.get("auto", false)), true, "expiry end_turn is auto")
	eq(CombatHUD.events_include_stun_skip(result.get("events", [])), false, "timer expiry is not a stun skip")

	# Replica hydrate: guest copies remaining and must not tick.
	var view_script := load("res://backend/combat_sim.gd")
	var replica: Node = view_script.new()
	_sim.tick_turn_timer(5.0)
	replica.apply_host_snapshot(_sim.snapshot())
	eq(int(replica.snapshot()["turn_time_seconds"]), int(_sim.snapshot()["turn_time_seconds"]), "guest hydrate copies remaining")
	eq(int(replica.snapshot()["active_seat"]), 1, "guest hydrate copies active_seat")
	var replica_tick: Dictionary = replica.tick_turn_timer(30.0)
	eq(bool(replica_tick.get("expired", false)), false, "guest tick does not expire")
	eq(int(replica.snapshot()["active_seat"]), 1, "guest tick does not change the seat")
	eq(int(replica.snapshot()["turn_time_seconds"]), int(_sim.snapshot()["turn_time_seconds"]), "guest tick does not drain remaining")
	replica.free()

	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(sim_src.contains("TURN_TIME_LIMIT"), "CombatSim owns the 30s clock")
	truthy(sim_src.contains("func tick_turn_timer"), "CombatSim ticks the host clock")
	eq(sim_src.contains("TurnClock"), false, "CombatSim does not reference TurnClock")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("func _on_turn_clock_expired"), "board_view handles clock expiry")
	truthy(view.contains("tick_turn_timer"), "board_view ticks the host clock")
	truthy(view.contains("_hydrate_turn_clock"), "board_view hydrates the HUD from the snapshot")
	truthy(view.contains("HANDOFF_SEC"), "seat-handoff banner is kept")
	var hud := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud.contains("set_turn_clock"), "HUD has a visible clock indicator")
	truthy(hud.contains("Your Turn"), "HUD can show Your Turn")
	truthy(hud.contains("Opponent's Turn"), "HUD can show Opponent's Turn")
	eq(hud.contains("Detonate"), false, "clock patch does not add Detonate")
	eq(hud.contains("Shoulder"), false, "clock patch does not add Shoulder")
	eq(hud.contains("Crush"), false, "clock patch does not add Crush")
	eq(hud.contains("WindMod"), false, "clock patch does not add WindMod")
	eq(sim_src.contains("WIND_MOD"), false, "CombatSim still has no WIND_MOD constant")
	eq(sim_src.contains("* WindMod"), false, "CombatSim still does not multiply by WindMod")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")
	eq(sim_src.contains("dedicated"), false, "CombatSim does not invent a dedicated server")

	var host_snap: Dictionary = _sim.snapshot().duplicate(true)
	host_snap["local_seat"] = 0
	eq(CombatHUD.kit_seat(host_snap), 0, "host kit chrome is local_seat 0")
	eq(CombatHUD.is_local_turn(host_snap), false, "after expiry it is Ironjaw's turn; host is not local turn")
	eq(CombatHUD.turn_status_text(host_snap), "Opponent's Turn", "host HUD shows Opponent's Turn")
	var guest_snap: Dictionary = host_snap.duplicate(true)
	guest_snap["local_seat"] = 1
	eq(CombatHUD.kit_seat(guest_snap), 1, "guest kit chrome is local_seat 1")
	eq(CombatHUD.is_local_turn(guest_snap), true, "guest HUD is Your Turn when active_seat is 1")
	eq(CombatHUD.turn_status_text(guest_snap), "Your Turn", "guest HUD shows Your Turn")
	eq(CombatHUD.kit_seat(_sim.snapshot()), 1, "hot-seat kit chrome falls back to active_seat")
	eq(CombatHUD.turn_status_text(_sim.snapshot()), "", "hot-seat does not encode Your Turn")

	var hud_node := CombatHUD.new()
	hud_node._build()
	hud_node.render(guest_snap, _sim.legal_intents(1))
	truthy(hud_node._turn_label.text.contains("Your Turn"), "rendered guest label names Your Turn")
	eq(hud_node.end_turn_enabled(), true, "guest End Turn is on during their turn")
	hud_node.render(host_snap, _sim.legal_intents(0))
	truthy(hud_node._turn_label.text.contains("Opponent's Turn"), "rendered host label names Opponent's Turn")
	eq(hud_node.end_turn_enabled(), false, "host End Turn is off during the guest turn")
	eq(hud_node._spell_buttons.has("mark_shot"), true, "host still shows Kestrel kit on opponent turn")
	eq(hud_node.clock_visible(), true, "TIME stays visible on the watching host")
	eq(hud_node._selected_label.text, "Opponent's turn — watching", "watching host selected line")

	# Exact host fields: prefer turn_time_seconds; net.local_seat / net.active_seat fallbacks.
	eq(CombatHUD.turn_clock_seconds({
		"turn_time_remaining": 12.2,
		"turn_time_seconds": 17,
		"turn_time_limit": 30,
	}), 17, "visible countdown prefers turn_time_seconds")
	eq(CombatHUD.has_host_turn_clock(host_snap), true, "host snapshot carries the clock fields")
	eq(CombatHUD.turn_clock_running({"turn_time_running": true}), true, "turn_time_running paints the bar")
	var net_only: Dictionary = {
		"units": host_snap.get("units", []),
		"turn_index": 1,
		"net": {"local_seat": 1, "active_seat": 0},
		"turn_time_remaining": 9.1,
		"turn_time_limit": 30,
		"turn_time_running": true,
		"turn_time_seconds": 10,
		"turn_timer": "host",
	}
	eq(CombatHUD.snap_local_seat(net_only), 1, "net.local_seat is used when top-level local_seat is missing")
	eq(CombatHUD.snap_active_seat(net_only), 0, "net.active_seat is used when top-level active_seat is missing")
	eq(CombatHUD.kit_seat(net_only), 1, "kit chrome follows net.local_seat")
	eq(CombatHUD.turn_status_text(net_only), "Opponent's Turn", "status uses net.local_seat vs net.active_seat")
	eq(CombatHUD.turn_clock_seconds(net_only), 10, "net-only snap still prefers turn_time_seconds")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
	})
	var guest_watch: Dictionary = _sim.snapshot().duplicate(true)
	guest_watch["local_seat"] = 1
	guest_watch["net_active"] = true
	eq(int(guest_watch.get("active_seat", -1)), 0, "fixture is Kestrel's turn")
	eq(CombatHUD.kit_seat(guest_watch), 1, "guest kit stays Ironjaw while Kestrel acts")
	hud_node.free()
	hud_node = CombatHUD.new()
	hud_node._build()
	hud_node.render(guest_watch, _sim.legal_intents(1))
	eq(hud_node._spell_buttons.has("advance"), true, "guest keeps Ironjaw spells during Kestrel's turn")
	eq(hud_node._spell_buttons.has("mark_shot"), false, "guest does not swap to Kestrel spells")
	truthy(hud_node._turn_label.text.contains("Opponent's Turn"), "guest label is Opponent's Turn on seat 0")
	eq(hud_node.clock_visible(), true, "guest TIME is visible while watching")
	truthy(hud_node._turn_label.text.contains("%ds" % int(guest_watch.get("turn_time_seconds", 30))), "guest turn line paints turn_time_seconds")
	hud_node.free()


func _test_turn_clock_ticks_during_hops() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var process_idx := view.find("func _process")
	var hydrate_idx := view.find("func _hydrate_turn_clock")
	truthy(process_idx >= 0 and hydrate_idx > process_idx, "_process and _hydrate_turn_clock exist")
	var process_src := view.substr(process_idx, hydrate_idx - process_idx)
	truthy(process_src.contains("tick_turn_timer"), "_process ticks the host clock")
	eq(process_src.contains("if _busy"), false, "_process does not freeze the clock while hop-busy")
	truthy(process_src.contains("is_client()"), "guest _process does not tick")

	var play_idx := view.find("func _play_walk")
	var animate_idx := view.find("func _animate_path")
	truthy(play_idx >= 0 and animate_idx > play_idx, "_play_walk and _animate_path exist")
	var play_src := view.substr(play_idx, animate_idx - play_idx)
	eq(play_src.contains("_turn_clock.pause"), false, "walk hops do not pause the seat clock")
	eq(play_src.contains("_turn_clock.stop"), false, "walk hops do not stop the seat clock")
	truthy(view.contains("_clock_expired_pending"), "expiry during hops is deferred, not dropped")
	truthy(view.contains("_on_turn_clock_expired"), "queued expiry presents the host end_turn")
	eq(view.contains('kind == "move" or kind == "advance"'), false, "Advance teleport is not hop-played")
	truthy(view.contains("teleport"), "board_view documents Advance as a teleport snap")

	var end_idx := view.find("func _on_end_turn_button_pressed")
	var expired_idx := view.find("func _on_turn_clock_expired")
	truthy(end_idx >= 0 and expired_idx > end_idx, "end-turn and expiry handlers exist")
	var end_src := view.substr(end_idx, expired_idx - end_idx)
	eq(end_src.contains("_turn_clock.pause()"), false, "handoff does not pause the host clock")
	eq(end_src.contains("_turn_clock.start()"), false, "host clock restart lives in CombatSim, not the banner")
	truthy(view.contains("_present_turn_handoff"), "banner is presentation of the host seat change")

	eq(view.contains("Detonate"), false, "clock hop patch does not add Detonate")
	eq(view.contains("Shoulder"), false, "clock hop patch does not add Shoulder")
	eq(view.contains("Crush"), false, "clock hop patch does not add Crush")


func _test_detonate_gates_and_damage() -> void:
	eq(int(SpellKits.spell(SpellKits.DETONATE)["ap"]), 3, "Detonate costs 3 AP")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["mp"]), 0, "Detonate costs 0 MP")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["min_range"]), 1, "Detonate min range 1 Chebyshev")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["max_range"]), 4, "Detonate max range 4 Chebyshev")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["base_damage"]), 6, "Detonate base damage stays 6")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["damage_per_mark"]), 6, "Detonate stays 6 per Mark")
	eq(str(SpellKits.spell(SpellKits.DETONATE).get("range_mode", "")), "chebyshev", "Detonate range is Chebyshev")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["min_range"]), 1, "Drop Shade min range stays 1")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["max_range"]), 6, "Drop Shade max range 6 Chebyshev")

	# No Marks on the target: reject + refund. A01 Locked: Marks live on the target.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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

	# Locked max is 4. Dist 5–7 refund even with Marks.
	for dist in [5, 6, 7]:
		_sim.reset_match({
			"seed": 1,
			"flat_board": true,
			"kestrel_pos": Vector2i(0, 0),
			"ironjaw_pos": Vector2i(dist, 0),
			"ironjaw_marks": 2,
		})
		result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(dist, 0)})
		eq(result["illegal"], true, "Detonate range %d is illegal" % dist)
		eq(result["reason"], "out_of_range", "range %d reject is out_of_range" % dist)
		eq(_unit(0)["ap"], 6, "out-of-range Detonate at %d refunds" % dist)
		eq(_unit(1)["marks"], 2, "out-of-range at %d does not consume Marks" % dist)

	# Range 1 with 1 Mark: 6+6*1 = 12 Air, consume Marks.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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

	# 3 Marks: 6+18=24 at the new max (Chebyshev 4, Locked 75%). 5 Marks: 6+30=36.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(4, 0),
		"ironjaw_facing": "W",
		"ironjaw_marks": 3,
	})
	eq(_sim.chebyshev(Vector2i(0, 0), Vector2i(4, 0)), 4, "range 4 is the Detonate max")
	result = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(4, 0)})
	eq(result["ok"], true, "Detonate at Chebyshev 4 is legal")
	eq(result["events"][0]["base_damage"], 24, "3 Marks → base 24")
	eq(result["events"][0]["damage"], 24, "front 24 Air")
	eq(result["events"][0]["hit_chance"], 75, "range 4 uses the 75% mid band")
	eq(_unit(1)["marks"], 0, "3 Marks consumed")
	eq(_unit(1)["hp"], 56, "80-24=56")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
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


func _test_drop_shade_range() -> void:
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["ap"]), 1, "Drop Shade costs 1 AP")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["mp"]), 0, "Drop Shade costs 0 MP")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["min_range"]), 1, "Drop Shade min range stays 1")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["max_range"]), 6, "Drop Shade max range 6 Chebyshev")
	eq(str(SpellKits.spell(SpellKits.DROP_SHADE).get("range_mode", "")), "chebyshev", "Drop Shade range is Chebyshev")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["shade_turns"]), 3, "Drop Shade token lasts 3 turns")
	eq(bool(SpellKits.spell(SpellKits.DROP_SHADE)["rolls"]), false, "Drop Shade does not roll")
	eq(SpellKits.SHADE_CAP, 2, "Shade stack cap stays 2")
	eq(SpellKits.range_text(SpellKits.spell(SpellKits.DROP_SHADE)), "range 1–6", "Drop Shade range_text is 1–6")
	eq(int(SpellKits.spell(SpellKits.MARK_SHOT)["min_range"]), 2, "Mark Shot min range stays 2")
	eq(int(SpellKits.spell(SpellKits.MARK_SHOT)["max_range"]), 7, "Mark Shot max range stays 7")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["min_range"]), 1, "Detonate min range stays 1")
	eq(int(SpellKits.spell(SpellKits.DETONATE)["max_range"]), 4, "Detonate max range stays 4")

	for dist in [3, 4, 5, 6]:
		_sim.reset_match({
			"seed": 1,
			"flat_board": true,
			"skip_deploy": true,
			"classes": ["gloam", "kestrel"],
			"positions": [Vector2i(0, 0), Vector2i(14, 14)],
		})
		var dest := Vector2i(dist, 0)
		eq(_sim.chebyshev(Vector2i(0, 0), dest), dist, "Drop Shade fixture is Chebyshev %d" % dist)
		eq(_has_legal_cast_to(0, "drop_shade", dest), true, "Drop Shade at range %d is legal" % dist)
		var result: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": dest, "seat": 0})
		eq(result["ok"], true, "Drop Shade at range %d resolves" % dist)
		eq(int(_unit(0)["shades"]), 1, "Drop Shade places one token at range %d" % dist)
		eq(int(_unit(0)["ap"]), 5, "Drop Shade spends 1 AP at range %d" % dist)
		eq(int(_unit(0)["mp"]), 3, "Drop Shade spends 0 MP at range %d" % dist)
		var tokens: Array = _sim.snapshot()["shade_tokens"]
		eq(tokens.size(), 1, "one Shade token at range %d" % dist)
		eq(tokens[0].get("pos"), dest, "Shade token sits on the dest at range %d" % dist)
		eq(int(tokens[0].get("turns", 0)), 3, "Shade token lasts 3 turns at range %d" % dist)

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(0, 0), Vector2i(14, 14)],
	})
	eq(_has_legal_cast_to(0, "drop_shade", Vector2i(7, 0)), false, "Drop Shade range 7 is not offered")
	var far: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(7, 0), "seat": 0})
	eq(far["illegal"], true, "Drop Shade range 7 is illegal")
	eq(far["reason"], "out_of_range", "range 7 reject is out_of_range")
	eq(int(_unit(0)["ap"]), 6, "out-of-range Drop Shade refunds AP")
	eq(int(_unit(0)["mp"]), 3, "out-of-range Drop Shade refunds MP")
	eq(int(_unit(0)["shades"]), 0, "out-of-range Drop Shade places no token")
	eq(_sim.snapshot()["shade_tokens"].size(), 0, "range 7 leaves the board empty of Shades")

	var preview: Dictionary = _sim.preview_cast(SpellKits.DROP_SHADE, Vector2i(0, 0), Vector2i(6, 0))
	eq(preview["min_range"], 1, "Drop Shade preview min 1")
	eq(preview["max_range"], 6, "Drop Shade preview max 6")
	eq(preview["range_text"], "range 1–6", "Drop Shade preview_cast range_text is 1–6")
	eq(preview["in_range"], true, "Chebyshev 6 is in Drop Shade range")
	eq(preview["ap"], 1, "Drop Shade preview costs 1 AP")
	eq(preview["mp"], 0, "Drop Shade preview costs 0 MP")
	var card := SpellTooltip.card_text(preview)
	truthy(card.contains("range 1–6"), "Drop Shade card names range 1–6")
	eq(card.contains("range 1–2"), false, "Drop Shade card drops the old 1–2 band")
	var far_preview: Dictionary = _sim.preview_cast(SpellKits.DROP_SHADE, Vector2i(0, 0), Vector2i(7, 0))
	eq(far_preview["in_range"], false, "Chebyshev 7 is outside Drop Shade preview range")
	eq(far_preview["max_range"], 6, "Drop Shade preview max stays 6 at dist 7")
	var marker_script: Script = load("res://board/shade_marker.gd")
	eq(float(marker_script.CLOAK_PEAK) >= 120.0, true, "Shade silhouette is tall enough to read on a phone")
	eq(int(marker_script.LABEL_SIZE) >= 22, true, "Shade label plate is phone-readable")
	eq(marker_script.RIM.get_luminance() > VfxPalette.GLOAM_RIM.get_luminance(), true, "Shade rim is brighter than the gloam rim")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var scene := FileAccess.get_file_as_string("res://main.tscn")
	truthy(scene.contains("ShadeMarkers"), "main scene owns a ShadeMarkers layer")
	truthy(view.contains("func _sync_shade_markers"), "refresh still syncs shade markers")
	truthy(view.contains("_includes_drop_shade"), "Drop Shade accept syncs the marker in the same resolve")
	eq(view.contains("$Units.add_child(marker)"), false, "sync does not parent the marker under Units")
	_test_ambush_shade_affordance()


func _test_ambush_shade_affordance() -> void:
	var gloam := Vector2i(2, 2)
	var prey := Vector2i(5, 2)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
	})
	eq(CombatHUD.gloam_has_live_shade(_sim.snapshot()), false, "Ambush chrome stays quiet before a Shade")
	var hud := CombatHUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	var before: Button = hud._spell_buttons[SpellKits.AMBUSH]
	eq(before.disabled, true, "Ambush stays disabled until a Shade or Invisible exists")
	eq(hud._selected_label.text.contains(CombatHUD.AMBUSH_SHADE_TIP), false, "the Ambush tip stays off with no Shade")
	var dropped: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(3, 2), "seat": 0})
	eq(bool(dropped.get("ok", false)), true, "Drop Shade still plants a token for the Ambush cue")
	eq(_unit(0)["pos"], gloam, "Drop Shade still does not relocate Gloam")
	var snap: Dictionary = _sim.snapshot()
	eq(CombatHUD.gloam_has_live_shade(snap), true, "a live Shade flags the Ambush cue")
	eq(CombatHUD.legal_cast_ids(_sim.legal_intents(0)).has(SpellKits.AMBUSH), true, "Ambush is legal once a Shade and a back tile exist")
	hud.render(snap, _sim.legal_intents(0))
	var ambush: Button = hud._spell_buttons[SpellKits.AMBUSH]
	eq(ambush.disabled, false, "Ambush enables on the cluster when a Shade is live")
	eq(ambush.modulate, CombatHUD.AMBUSH_SHADE_MODULATE, "Ambush highlights when a Shade is live")
	truthy(hud._selected_label.text.contains(CombatHUD.AMBUSH_SHADE_TIP), "the status line says Ambush from Shade")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["ap"]), 4, "Ambush cost stays 4 AP")
	eq(int(SpellKits.spell(SpellKits.DROP_SHADE)["max_range"]), 6, "Drop Shade range stays 6")
	hud.free()


func _test_detonate_miss_retains_marks() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
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
	eq(result["events"][0]["bounced"], false, "walkable empty dest does not bounce")
	eq(result["events"][0]["staggered"], false, "walkable empty dest does not stagger")
	eq(_unit(0)["pos"], Vector2i(5, 3), "Kestrel landed one cell away")
	eq(_unit(0)["hp"], 74, "80-6=74")
	eq(_unit(0)["mp"], 3, "walkable empty dest does not spend target MP")
	eq(_unit(1)["impact"], 1, "Shoulder grants Impact on connect")
	eq(_unit(1)["ap"], 4, "Shoulder spends 2 AP")
	eq(_unit(1)["mp"], 3, "Shoulder spends 0 MP")

	# Diagonal push.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
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
		"flat_board": true,
		"kestrel_pos": Vector2i(5, 3),
		"ironjaw_pos": Vector2i(3, 3),
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(5, 3)})
	eq(result["illegal"], true, "Shoulder range 2 is illegal")
	eq(result["reason"], "out_of_range", "Shoulder range reject")
	eq(_unit(1)["ap"], 6, "range reject refunds")


func _test_shoulder_bounce_stagger_locked() -> void:
	# Director Locked Shoulder: OOB / truly blocked dest bounce + stagger.
	# Bounce grants +2 Impact only (not +1 stacked with +2).
	# Stagger is 4 HP + 1 MP when current MP >= 1; HP only when MP is 0.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"kestrel_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim.push_destination(Vector2i(1, 0), Vector2i(0, 0)), Vector2i(-1, 0), "west edge push is OOB")
	eq(_unit(0)["mp"], 3, "inactive Kestrel still has leftover MP")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(0, 0)})
	eq(result["ok"], true, "OOB bounce still resolves the hit")
	eq(_unit(0)["pos"], Vector2i(0, 0), "OOB bounce leaves the target put")
	eq(_unit(0)["hp"], 70, "OOB bounce is 6 Earth + 4 stagger HP")
	eq(_unit(0)["mp"], 2, "OOB bounce spends 1 stagger MP when MP>=1")
	eq(_unit(1)["impact"], 2, "OOB bounce grants +2 Impact only")
	eq(result["events"][0]["engine_gained"], 2, "OOB bounce engine gain is +2, not +1 and +2")
	eq(result["events"][0]["type"], "hit", "hit event is first")
	eq(result["events"][0]["damage"], 6, "Shoulder hit damage is unchanged")
	eq(result["events"][0]["push_blocked"], false, "OOB is bounce, not push_blocked")
	eq(result["events"][0]["bounced"], true, "hit records bounced")
	eq(result["events"][0]["staggered"], true, "hit records staggered")
	eq(result["events"][0]["bounce_reason"], "out_of_bounds", "bounce reason is out_of_bounds")
	eq(result["events"][0]["stagger_hp"], 4, "hit records 4 stagger HP")
	eq(result["events"][0]["stagger_mp"], 1, "hit records 1 stagger MP")
	eq(result["events"][0]["hp_delta"], -4, "hit records stagger HP delta")
	eq(result["events"][0]["mp_delta"], -1, "hit records stagger MP delta")
	eq(result["events"][1]["type"], "push_bounce", "OOB emits push_bounce")
	eq(result["events"][1]["reason"], "out_of_bounds", "push_bounce reason is out_of_bounds")
	eq(result["events"][1]["hp_delta"], -4, "push_bounce carries HP delta")
	eq(result["events"][1]["mp_delta"], -1, "push_bounce carries MP delta")
	truthy(str(result["events"][1].get("locked", "")).contains("Director Locked Shoulder"), "push_bounce is labeled Director Locked Shoulder")
	eq(result["events"][1].has("open"), false, "push_bounce is not labeled OPEN")
	eq(result["events"][2]["type"], "stagger", "OOB emits stagger after bounce")
	eq(result["events"][2]["hp_delta"], -4, "stagger HP delta is -4")
	eq(result["events"][2]["mp_delta"], -1, "stagger MP delta is -1")
	eq(result["events"][2]["hp"], 70, "stagger event reports remaining HP")
	eq(result["events"][2]["mp"], 2, "stagger event reports remaining MP")
	eq(_event_type_count(result["events"], "push_blocked"), 0, "OOB does not emit push_blocked")

	# OOB with 0 MP: HP only.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"kestrel_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	_live_unit(0)["mp"] = 0
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(0, 0)})
	eq(result["ok"], true, "0 MP OOB bounce still hits")
	eq(_unit(0)["pos"], Vector2i(0, 0), "0 MP OOB bounce stays put")
	eq(_unit(0)["hp"], 70, "0 MP OOB still applies 4 stagger HP")
	eq(_unit(0)["mp"], 0, "0 MP OOB does not apply stagger MP")
	eq(result["events"][0]["stagger_hp"], 4, "0 MP still records 4 stagger HP")
	eq(result["events"][0]["stagger_mp"], 0, "0 MP records 0 stagger MP")
	eq(result["events"][0]["mp_delta"], 0, "0 MP stagger MP delta is 0")
	eq(result["events"][2]["mp_delta"], 0, "stagger event MP delta is 0 at 0 MP")
	eq(result["events"][2]["mp"], 0, "stagger event remaining MP is 0")

	# Impact cap still clips a +2 bounce (3 + 2 cannot exceed 4).
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"kestrel_facing": "E",
		"ironjaw_impact": 3,
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(0, 0)})
	eq(result["events"][0]["engine_gained"], 1, "bounce +2 clips to the Impact cap")
	eq(_unit(1)["impact"], 4, "Impact cap stays 4 after a bounce")

	# Unwalkable override (not lava): same bounce + stagger, +2 Impact.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [{"pos": Vector2i(5, 3), "terrain": "ground", "elevation": 0, "walkable": false}],
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "unwalkable dest still resolves the hit")
	eq(_unit(0)["pos"], Vector2i(4, 3), "unwalkable dest bounce leaves the target put")
	eq(_unit(0)["hp"], 70, "unwalkable dest is 6 Earth + 4 stagger HP")
	eq(_unit(0)["mp"], 2, "unwalkable dest spends 1 stagger MP")
	eq(result["events"][0]["bounced"], true, "unwalkable dest records bounced")
	eq(result["events"][1]["type"], "push_bounce", "unwalkable dest emits push_bounce")
	eq(result["events"][1]["reason"], "not_walkable", "bounce reason is not_walkable")
	eq(result["events"][2]["type"], "stagger", "unwalkable dest emits stagger")
	eq(result["events"][2]["hp_delta"], -4, "unwalkable stagger HP delta is -4")
	eq(result["events"][0]["engine_gained"], 2, "truly blocked bounce is +2 Impact only")
	eq(_unit(1)["impact"], 2, "unwalkable bounce stores +2 Impact")
	eq(_event_type_count(result["events"], "push_blocked"), 0, "unwalkable dest does not emit push_blocked")
	eq(_unit(0)["burn_remaining"], 0, "a non-lava bounce does not apply Burn")


func _test_shoulder_lava_burn_locked() -> void:
	# Lava is hazardous for a forced Shoulder, not a wall. Voluntary walk still rejects it.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [
			{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0},
			{"pos": Vector2i(6, 3), "terrain": "lava", "elevation": 0},
			{"pos": Vector2i(3, 4), "terrain": "lava", "elevation": 0},
		],
	})
	_sim.submit({"type": "end_turn"})
	var walked: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 4)})
	eq(walked["illegal"], true, "voluntary walk onto lava is rejected")
	eq(walked["reason"], "not_walkable", "walk onto lava reason stays not_walkable")
	eq(_unit(1)["pos"], Vector2i(3, 3), "rejected lava walk does not move Ironjaw")
	eq(_has_legal_move_to(1, Vector2i(3, 4)), false, "legal_intents omit lava")

	var result: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "lava Shoulder still resolves the hit")
	eq(_unit(0)["pos"], Vector2i(5, 3), "forced push lands on lava")
	eq(_unit(0)["hp"], 74, "lava land is 6 Earth and no stagger")
	eq(_unit(0)["mp"], 3, "lava land does not spend stagger MP")
	eq(_unit(0)["burn_remaining"], 2, "landing on lava applies Burn duration 2")
	eq(_unit(1)["impact"], 1, "lava land is a clean connect (+1 Impact, not bounce +2)")
	eq(result["events"][0]["engine_gained"], 1, "lava hit records +1 Impact")
	eq(result["events"][0]["pushed"], true, "lava dest records a push")
	eq(result["events"][0]["bounced"], false, "lava dest does not bounce")
	eq(result["events"][0]["push_blocked"], false, "lava dest is not push_blocked")
	eq(result["events"][0]["staggered"], false, "lava dest does not stagger")
	eq(result["events"][0]["burn_applied"], true, "hit records Burn")
	eq(result["events"][0]["burn_refreshed"], false, "first Burn is not a refresh")
	eq(result["events"][0]["burn_remaining"], 2, "hit records Burn duration 2")
	eq(_event_type_count(result["events"], "push_bounce"), 0, "lava dest does not emit push_bounce")
	eq(_event_type_count(result["events"], "stagger"), 0, "lava dest does not emit stagger")
	eq(_event_type_count(result["events"], "push_blocked"), 0, "lava dest does not emit push_blocked")
	var applied := _first_event_where(result["events"], "status", "burn")
	eq(applied.is_empty(), false, "lava land emits a Burn status")
	eq(int(applied.get("remaining", 0)), 2, "Burn status duration is 2")
	eq(int(applied.get("hp_per_tick", 0)), 4, "Burn status exposes 4 HP per tick")
	eq(bool(applied.get("refreshed", true)), false, "first Burn status is not a refresh")
	truthy(str(applied.get("locked", "")).contains("Director Locked Burn"), "Burn status is labeled Director Locked Burn")
	eq(result["snapshot"]["units"][0]["burn_remaining"], 2, "snapshot unit exposes burn_remaining")
	eq(result["snapshot"]["burn"], "locked", "snapshot stamps Burn locked")
	var replica_script := load("res://backend/combat_sim.gd")
	var replica = replica_script.new()
	replica.apply_host_snapshot(result["snapshot"])
	eq(replica.snapshot()["units"][0]["burn_remaining"], 2, "host snapshot restores Burn")
	eq(_first_event_where(replica.snapshot()["last_events"], "status", "burn").is_empty(), false, "host snapshot keeps the Burn event")
	replica.free()

	var hud := CombatHUD.new()
	hud._build()
	hud.render(result["snapshot"], [])
	truthy(str(hud._kestrel_body.text).contains("[b]BURN[/b] 2"), "Kestrel card shows Burn duration")
	eq(str(hud._ironjaw_body.text).contains("BURN"), false, "caster card does not show Burn")
	hud.free()
	var pawn := Pawn.new()
	pawn.apply_snapshot(_unit(0), 1)
	eq(pawn.burning, true, "pawn reads Burn from the snapshot unit")
	eq(pawn.burn_remaining, 2, "pawn keeps Burn duration for chrome")
	pawn.free()

	# Burn does not tick on the caster's turn. It ticks at the victim's turn start.
	eq(_unit(0)["hp"], 74, "Burn does not damage on apply")
	var ticked: Dictionary = _sim.submit({"type": "end_turn"})
	eq(_sim.snapshot()["active_seat"], 0, "victim's turn starts after the push")
	eq(_unit(0)["hp"], 70, "first Burn tick is 4 HP (74-4)")
	eq(_unit(0)["burn_remaining"], 1, "first tick leaves duration 1")
	var burn_tick := _first_event_where(ticked["events"], "burn")
	eq(burn_tick.is_empty(), false, "turn start emits a burn tick")
	eq(int(burn_tick.get("hp_delta", 0)), -4, "burn tick hp_delta is -4")
	eq(int(burn_tick.get("hp", 0)), 70, "burn tick reports remaining HP")
	eq(int(burn_tick.get("remaining", -1)), 1, "burn tick reports duration left")
	eq(_event_type_count(ticked["events"], "dead"), 0, "a non-lethal tick does not kill")

	var onto_lava: Dictionary = _sim.submit({"type": "move", "to": Vector2i(6, 3)})
	eq(onto_lava["illegal"], true, "victim still cannot walk onto lava")
	eq(onto_lava["reason"], "not_walkable", "second lava step is not_walkable")
	eq(_unit(0)["pos"], Vector2i(5, 3), "rejected walk leaves them on the first lava")
	eq(_unit(0)["burn_remaining"], 1, "rejected walk does not clear Burn")

	var left: Dictionary = _sim.submit({"type": "move", "to": Vector2i(5, 2)})
	eq(left["ok"], true, "leaving lava onto ground is allowed")
	eq(_unit(0)["pos"], Vector2i(5, 2), "victim walked off lava")
	eq(_unit(0)["burn_remaining"], 1, "Burn continues after leaving lava")
	eq(_unit(0)["hp"], 70, "leaving lava does not tick Burn early")

	_sim.submit({"type": "end_turn"})
	var second: Dictionary = _sim.submit({"type": "end_turn"})
	eq(_sim.snapshot()["active_seat"], 0, "second victim turn starts")
	eq(_unit(0)["pos"], Vector2i(5, 2), "second tick does not pull them back onto lava")
	eq(_unit(0)["hp"], 66, "second Burn tick is another 4 HP")
	eq(_unit(0)["burn_remaining"], 0, "duration 2 expires after two ticks")
	eq(int(_first_event_where(second["events"], "burn").get("remaining", -1)), 0, "second tick reports duration 0")
	_sim.submit({"type": "end_turn"})
	var third: Dictionary = _sim.submit({"type": "end_turn"})
	eq(_event_type_count(third["events"], "burn"), 0, "Burn does not tick after duration 0")
	eq(_unit(0)["hp"], 66, "no third Burn tick")
	eq(_unit(0)["alive"], true, "two ticks at full HP do not kill")

	# Re-apply refreshes duration to 2 and does not stack the tick.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1, 1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [
			{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0},
			{"pos": Vector2i(6, 3), "terrain": "lava", "elevation": 0},
		],
	})
	_sim.submit({"type": "end_turn"})
	_sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	_sim.submit({"type": "end_turn"})
	eq(_unit(0)["burn_remaining"], 1, "refresh setup has one tick left")
	eq(_unit(0)["hp"], 70, "refresh setup HP is 70")
	_sim.submit({"type": "end_turn"})
	eq(_sim.submit({"type": "move", "to": Vector2i(4, 3)})["ok"], true, "Ironjaw steps next to the lava tile")
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "second Shoulder connects")
	eq(_unit(0)["pos"], Vector2i(6, 3), "second push lands on lava again")
	eq(_unit(0)["hp"], 64, "refresh deals the 6 Earth hit and no extra Burn tick")
	eq(_unit(0)["burn_remaining"], 2, "re-apply sets duration back to 2")
	eq(_unit(1)["impact"], 2, "second clean push adds +1 Impact (1+1)")
	applied = _first_event_where(result["events"], "status", "burn")
	eq(bool(applied.get("refreshed", false)), true, "re-apply is a refresh")
	eq(int(applied.get("previous", 0)), 1, "refresh replaces the leftover tick")
	eq(int(applied.get("remaining", 0)), 2, "refresh does not stack to 3")
	_sim.submit({"type": "end_turn"})
	eq(_unit(0)["hp"], 60, "tick after refresh is 4 HP, not 8")
	eq(_unit(0)["burn_remaining"], 1, "refresh still has one tick after the first new tick")

	# Occupied lava is still a body-block: no displace, no Burn.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0}],
		"blockers": [Vector2i(5, 3)],
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(_unit(0)["pos"], Vector2i(4, 3), "occupied lava does not displace")
	eq(result["events"][0]["push_blocked"], true, "occupied lava is push_blocked")
	eq(result["events"][0]["bounced"], false, "occupied lava does not bounce")
	eq(_unit(0)["burn_remaining"], 0, "occupied lava does not apply Burn")
	eq(_unit(0)["hp"], 74, "occupied lava is hit damage only")
	eq(_unit(1)["impact"], 1, "occupied lava keeps the hit +1 Impact")

	# Death is checked after the tick.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0}],
	})
	_sim.submit({"type": "end_turn"})
	_sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	_live_unit(0)["hp"] = 4
	var lethal: Dictionary = _sim.submit({"type": "end_turn"})
	eq(_unit(0)["hp"], 0, "Burn tick can reduce HP to 0")
	eq(_unit(0)["alive"], false, "death check after the tick marks the victim dead")
	eq(_sim.snapshot()["match_over"], true, "lethal Burn ends the match")
	eq(_sim.snapshot()["winner_seat"], 1, "Ironjaw wins when Burn kills Kestrel")
	eq(int(_first_event_where(lethal["events"], "burn").get("hp_delta", 0)), -4, "lethal tick still reports 4 HP")
	eq(_event_type_count(lethal["events"], "dead"), 1, "lethal tick emits dead")
	eq(_event_type_count(lethal["events"], "match_over"), 1, "lethal tick emits match_over")


func _test_shoulder_push_blocked_locked() -> void:
	# Occupied dest stays push_blocked — hard body-block, no bounce, no stagger.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"blockers": [Vector2i(5, 3)],
	})
	_sim.submit({"type": "end_turn"})
	var before_mp: int = int(_unit(0)["mp"])
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(result["ok"], true, "occupied push still resolves the hit")
	eq(_unit(0)["pos"], Vector2i(4, 3), "occupied dest does not move the target")
	eq(_unit(0)["hp"], 74, "occupied push deals hit damage only (no stagger)")
	eq(_unit(0)["mp"], before_mp, "occupied dest does not spend stagger MP")
	eq(_unit(1)["impact"], 1, "occupied push still grants Impact")
	eq(result["events"][0]["engine_gained"], 1, "occupied push does not invent Impact beyond +1")
	eq(_unit(0)["burn_remaining"], 0, "occupied push does not apply Burn")
	eq(result["events"][0]["push_blocked"], true, "hit records push_blocked")
	eq(result["events"][0]["bounced"], false, "occupied dest does not bounce")
	eq(result["events"][0]["staggered"], false, "occupied dest does not stagger")
	eq(result["events"][0]["stagger_hp"], 0, "occupied dest has no stagger HP")
	eq(result["events"][0]["stagger_mp"], 0, "occupied dest has no stagger MP")
	eq(result["events"][1]["type"], "push_blocked", "occupied dest emits push_blocked")
	eq(result["events"][1]["reason"], "occupied", "block reason is occupied")
	truthy(str(result["events"][1].get("locked", "")).contains("Director Locked Shoulder"), "occupied push_blocked is labeled Director Locked Shoulder")
	eq(result["events"][1].has("open"), false, "occupied push_blocked is not labeled OPEN")
	eq(_event_type_count(result["events"], "push_bounce"), 0, "occupied dest does not emit push_bounce")
	eq(_event_type_count(result["events"], "stagger"), 0, "occupied dest does not emit stagger")
	truthy(str(result["events"][0]["coach"]).contains("hard body-block"), "hit coach names hard body-block when occupied")


func _test_crush_spend_and_stun() -> void:
	eq(int(SpellKits.spell(SpellKits.CRUSH)["ap"]), 4, "Crush costs 4 AP")
	eq(int(SpellKits.spell(SpellKits.CRUSH)["mp"]), 0, "Crush costs 0 MP")
	eq(int(SpellKits.spell(SpellKits.CRUSH)["base_damage"]), 24, "Crush base is 24 Earth")

	# Gate: fewer than 2 Impact rejects and refunds.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
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
		"flat_board": true,
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

	# Impact 4 before spend: Stun 1 (Locked A′).
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
	eq(result["events"][0].has("open_a05_stun"), false, "Stun application is not labeled OPEN A05")
	eq(result["events"][0]["back"], true, "Crush still applies facing")
	eq(result["events"][0]["damage"], 29, "24 × 1.20 rounds to 29")
	eq(_unit(1)["impact"], 2, "4-2=2 Impact left")
	eq(_unit(0)["stun_remaining"], 1, "Stun 1 stored on the target")
	eq(result["events"][1]["type"], "status", "status event for Stun")
	eq(result["events"][1]["status"], "stun", "status id is stun")
	eq(result["events"][1]["remaining"], 1, "status remaining is 1")
	eq(result["events"][1]["suppress"], ["move", "cast", "face"], "Stun (A) suppress is move/cast/face")
	truthy(str(result["events"][1].get("locked", "")).contains("Locked Stun (A′)"), "Stun status event labeled Locked Stun (A′)")
	eq(result["events"][1].has("open"), false, "Stun status event is not labeled OPEN")
	truthy(str(result["events"][1].get("coach", "")).contains("Locked A"), "Stun coach names Locked A")

	# Miss retains Impact; no Stun.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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


func _test_stun_auto_end_turn_after_crush() -> void:
	# Locked Stun (A′): after Crush stun, that seat's next turn auto-ends.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
	eq(_sim.snapshot()["active_seat"], 1, "Crush leaves Ironjaw active")
	var result: Dictionary = _sim.submit({"type": "end_turn"})
	eq(result["ok"], true, "Ironjaw End Turn is accepted")
	eq(_sim.snapshot()["active_seat"], 1, "stunned Kestrel turn auto-ended; Ironjaw acts again")
	eq(_unit(0)["stunned"], true, "Kestrel served stunned-this-turn (tick at their turn start)")
	eq(_unit(0)["stun_remaining"], 0, "stun remaining decremented on the skipped turn")
	eq(_unit(1)["stunned"], false, "Ironjaw is not stunned")
	var auto_end := {}
	var kestrel_start := {}
	for event in result["events"]:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "end_turn" and bool(event.get("auto", false)):
			auto_end = event
		if str(event.get("type", "")) == "turn_start" and int(event.get("seat", -1)) == 0:
			kestrel_start = event
	eq(auto_end.is_empty(), false, "stunned seat emits auto end_turn")
	eq(int(auto_end.get("seat", -1)), 0, "auto end_turn is Kestrel's skipped turn")
	eq(kestrel_start.is_empty(), false, "Kestrel still got a turn_start (the skipped one)")
	eq(bool(kestrel_start.get("stunned_skip", false)), true, "Kestrel turn_start is the skipped stun turn")
	truthy(str(_sim.snapshot().get("coach", "")).contains("Locked A"), "coach names Locked A′ skip")
	var legal_ij: Array = _sim.legal_intents(1)
	var legal_k: Array = _sim.legal_intents(0)
	var ij_types := {}
	for intent in legal_ij:
		ij_types[str(intent["type"])] = true
	truthy(ij_types.has("move"), "Ironjaw can walk after the skip")
	truthy(ij_types.has("cast"), "Ironjaw can cast after the skip")
	eq(legal_k.is_empty(), true, "Kestrel legal_intents empty (not their turn)")
	eq(_unit(0)["ap"], 6, "skipped turn still refilled AP")
	eq(_unit(0)["mp"], 3, "skipped turn still refilled MP")

	_sim.submit({"type": "end_turn"})
	eq(_sim.snapshot()["active_seat"], 0, "Kestrel acts after the skipped stun turn")
	eq(_unit(0)["stunned"], false, "Stun 1 expired after the skipped turn")
	eq(_unit(0)["stun_remaining"], 0, "no leftover stun_remaining")
	var k_types := {}
	for intent in _sim.legal_intents(0):
		k_types[str(intent["type"])] = true
	truthy(k_types.has("move"), "after skip, walk is legal")
	truthy(k_types.has("cast"), "after skip, casts are legal")
	truthy(k_types.has("face"), "after skip, face is legal")


func _test_stun_suppresses_actions_locked() -> void:
	# Locked Stun (A′): move/cast/face never become legal. Auto end_turn only.
	# Force a stunned-active seat so the reject gate can be asserted without a Crush skip.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_marks": 1,
	})
	_live_unit(0)["stunned"] = true
	var legal: Array = _sim.legal_intents(0)
	var kinds := {}
	for intent in legal:
		kinds[str(intent.get("type", ""))] = intent
	eq(kinds.has("move"), false, "stunned legal_intents has no move")
	eq(kinds.has("cast"), false, "stunned legal_intents has no cast")
	eq(kinds.has("face"), false, "stunned legal_intents has no face")
	eq(kinds.has("end_turn"), true, "auto end_turn path is listed")
	eq(bool(kinds["end_turn"].get("auto", false)), true, "end_turn is the auto path")

	var result: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 4)})
	eq(result["illegal"], true, "stunned move is rejected")
	eq(result["reason"], "stunned_cannot_act", "move reason is stunned_cannot_act")
	eq(_unit(0)["pos"], Vector2i(3, 3), "stunned unit did not walk")
	eq(_unit(0)["mp"], 3, "stunned move refunds")
	truthy(str(result["events"][0].get("coach", "")).contains("Locked A"), "stun reject coach names Locked A")

	result = _sim.submit({"type": "face", "dir": "N"})
	eq(result["illegal"], true, "stunned face is rejected")
	eq(result["reason"], "stunned_cannot_act", "face reason is stunned_cannot_act")
	eq(_unit(0)["facing"], "E", "facing unchanged")

	result = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 3)})
	eq(result["illegal"], true, "stunned cast is rejected")
	eq(result["reason"], "stunned_cannot_act", "cast reason is stunned_cannot_act")
	eq(_unit(0)["ap"], 6, "stunned cast refunds")

	result = _sim.submit({"type": "end_turn"})
	eq(result["ok"], true, "end_turn is allowed as the auto path")
	eq(_sim.snapshot()["active_seat"], 1, "stunned seat hands off")

	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("OPEN A05"), false, "CombatSim does not label Stun as OPEN A05")
	eq(sim_src.contains("suppress list not locked"), false, "CombatSim does not leave the suppress list Open")
	truthy(sim_src.contains("Locked Stun (A"), "CombatSim labels Stun as Locked (A′)")
	truthy(sim_src.contains("auto end_turn"), "CombatSim stamps auto end_turn for Locked A′")
	truthy(sim_src.contains("Director Locked Shoulder"), "CombatSim labels Shoulder bounce/stagger Locked")
	truthy(sim_src.contains("stunned_cannot_act"), "CombatSim uses reserved reject stunned_cannot_act")
	eq(sim_src.contains("open_a05_stun"), false, "CombatSim no longer emits open_a05_stun")
	eq(sim_src.contains("Step-shot"), false, "Stun patch does not add Step-shot")
	eq(sim_src.contains("gust_heading"), false, "Stun patch does not invent Gust")
	truthy(sim_src.contains("func _resolve_advance") and sim_src.contains("_def: Dictionary"), "Advance kit arg is _def (unused-parameter silence)")


func _test_stun_hud_greys_walk_face_spells() -> void:
	# Locked Stun (A′) client: after Crush, the stunned turn auto-ends.
	# Kestrel card still shows STUN; Ironjaw can act. Forced stunned-active still greys chrome.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	_sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	_sim.submit({"type": "end_turn"})
	eq(_sim.snapshot()["active_seat"], 1, "A′ auto-skip leaves Ironjaw active")
	eq(_unit(0)["stunned"], true, "Kestrel is stunned-this-turn after the skip")
	var hud := CombatHUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(1))
	eq(hud.stun_badge_visible(), false, "center STUN badge follows the active seat")
	truthy(str(hud._kestrel_body.text).contains("[b]STUN[/b]"), "Kestrel card shows STUN after the skipped turn")
	eq(hud.walk_suppressed(), false, "Ironjaw Walk is not greyed after the skip")
	eq(hud.face_suppressed(), false, "Ironjaw Face is not greyed after the skip")
	eq(hud.end_turn_enabled(), true, "Ironjaw End Turn stays enabled")

	# Forced stunned-active chrome (gate still greys if that state is rendered).
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
	})
	_live_unit(0)["stunned"] = true
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud.stun_badge_visible(), true, "HUD shows STUN badge while the active seat is stunned")
	truthy(str(hud._kestrel_body.text).contains("[b]STUN[/b]"), "Kestrel card shows STUN badge")
	eq(hud.walk_suppressed(), true, "Walk is greyed/disabled while stunned")
	eq(hud.face_suppressed(), true, "Face is greyed/disabled while stunned")
	eq(hud.spells_suppressed(), true, "spells are greyed/disabled while stunned")
	eq(hud.end_turn_enabled(), true, "End Turn stays as a fallback")
	eq(hud._selected_label.text, "Stunned — turn auto-ends", "selected line names Locked A′ auto-end")
	eq(hud._walk_button.modulate, CombatHUD.STUN_GREY, "Walk modulate is stun grey")
	for dir in hud._face_buttons.keys():
		eq((hud._face_buttons[dir] as Button).modulate, CombatHUD.STUN_GREY, "Face %s modulate is stun grey" % dir)
	for spell_id in hud._spell_buttons.keys():
		eq((hud._spell_buttons[spell_id] as Button).disabled, true, "spell %s disabled while stunned" % spell_id)
		eq((hud._spell_buttons[spell_id] as Button).modulate, CombatHUD.STUN_GREY, "spell %s modulate is stun grey" % spell_id)

	hud._on_walk_pressed()
	eq(hud.selected_spell(), "", "disabled Walk does not select a spell")
	eq(_sim.submit({"type": "move", "to": Vector2i(3, 4)})["reason"], "stunned_cannot_act", "stunned move still rejected")

	_live_unit(0)["stunned"] = false
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud.stun_badge_visible(), false, "STUN badge hides when not stunned")
	eq(hud.walk_suppressed(), false, "Walk re-enables when not stunned")
	eq(hud.face_suppressed(), false, "Face re-enables when not stunned")
	eq(hud.end_turn_enabled(), true, "End Turn still enabled after Stun 1")
	hud.free()

	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("STUN_GREY"), "HUD greys stunned Walk/Face/spells")
	truthy(hud_src.contains("[b]STUN[/b]"), "HUD unit card includes a STUN badge")
	truthy(hud_src.contains("turn auto-ends"), "HUD names Locked A′ auto-end")
	eq(hud_src.contains("OPEN A05"), false, "HUD does not call Stun Open")
	eq(hud_src.contains("suppress list not locked"), false, "HUD does not leave Stun Open")
	eq(hud_src.contains("Step-shot"), false, "Stun HUD does not add Step-shot")
	eq(hud_src.contains("Detonate"), false, "Stun HUD still does not hardcode Detonate")

	var readme := FileAccess.get_file_as_string("res://README.md")
	eq(readme.contains("OPEN A05"), false, "README does not call Stun OPEN A05")
	eq(readme.contains("**OPEN:** if the dest"), false, "README does not call PushBlocked Open")
	truthy(readme.contains("Locked Stun (A"), "README stamps Locked Stun (A′)")
	truthy(readme.contains("auto-ends") or readme.contains("auto-resolves"), "README documents A′ auto end_turn")
	truthy(readme.contains("Director Locked Shoulder"), "README stamps Director Locked Shoulder")
	truthy(readme.contains("are no longer Open"), "README says Stun/Shoulder are no longer Open")

	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	truthy(pawn_src.contains("STUN"), "pawn draws a STUN badge")
	eq(pawn_src.contains("step_shot"), false, "pawn does not invent Step-shot")


func _test_push_blocked_client_toast_no_hop() -> void:
	# Client: occupied toasts PushBlocked; OOB bounce toasts Bounce plus +2 Impact. Neither hops.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"kestrel_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(0, 0)})
	eq(CombatHUD.events_include_push_blocked(result["events"]), false, "OOB Shoulder is not push_blocked")
	eq(CombatHUD.events_include_push_bounce(result["events"]), true, "OOB Shoulder is bounce")
	eq(CombatHUD.events_include_stagger(result["events"]), true, "OOB Shoulder emits stagger")
	eq(CombatHUD.should_play_walk_hops(result["events"]), false, "Bounce does not animate a hop")
	eq(CombatHUD.toast_for_events(result["events"]), "Bounce  +2 Impact", "OOB toast is Bounce plus +2 Impact")
	eq(CombatHUD.toast_for_events(result["events"]).contains("+1"), false, "OOB bounce toast is not also +1")
	eq(_unit(0)["pos"], Vector2i(0, 0), "target stayed put")
	eq(_unit(0)["hp"], 70, "hit + stagger HP still applied")
	eq(_unit(1)["impact"], 2, "OOB bounce Impact is +2")

	var walk_events: Array = [{
		"type": "move",
		"path": [Vector2i(1, 0), Vector2i(2, 0)],
	}]
	eq(CombatHUD.should_play_walk_hops(walk_events), true, "normal walks still hop")
	eq(CombatHUD.toast_for_events(walk_events), "", "walks do not toast PushBlocked or Bounce")
	eq(CombatHUD.should_play_walk_hops([{"type": "advance", "to": Vector2i(2, 0)}]), false, "Advance still does not hop")

	var occupied: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"blockers": [Vector2i(5, 3)],
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	eq(CombatHUD.events_include_push_blocked(result["events"]), true, "occupied dest is push_blocked")
	eq(CombatHUD.events_include_push_bounce(result["events"]), false, "occupied dest is not bounce")
	eq(CombatHUD.events_include_stagger(result["events"]), false, "occupied dest is not stagger")
	eq(CombatHUD.should_play_walk_hops(result["events"]), false, "occupied PushBlocked does not hop")
	eq(CombatHUD.toast_for_events(result["events"]), CombatHUD.PUSH_BLOCKED_TOAST, "occupied dest still toasts PushBlocked")

	var hud := CombatHUD.new()
	hud._build()
	hud.show_toast(CombatHUD.PUSH_BLOCKED_TOAST)
	eq(hud.toast_caption(), "PushBlocked", "HUD toast caption is PushBlocked")
	hud.show_toast(CombatHUD.BOUNCE_TOAST)
	eq(hud.toast_caption(), "Bounce", "HUD toast caption is Bounce")
	hud.free()

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("PUSH_BLOCKED_TOAST"), "board_view toasts PushBlocked")
	truthy(view.contains("BOUNCE_TOAST"), "board_view toasts Bounce")
	truthy(view.contains("events_include_push_blocked"), "board_view gates hops on push_blocked")
	truthy(view.contains("events_include_push_bounce"), "board_view gates hops on bounce")
	truthy(view.contains("should_play_walk_hops"), "board_view uses hop gate that excludes PushBlocked/Bounce")
	truthy(view.contains("flash_impact"), "board_view still plays Impact feedback")
	eq(view.contains("Step-shot"), false, "Shoulder client does not add Step-shot")
	eq(view.contains("Gust"), false, "Shoulder client does not invent Gust")
	eq(view.contains("longshot"), false, "Shoulder client does not invent Mark Shot +5")
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	truthy(pawn_src.contains("flash_hit"), "pawn can flash on hit")
	truthy(pawn_src.contains("flash_impact"), "pawn can flash Impact")
	eq(occupied["crit_roll"], false, "crit roll stays OFF")
	truthy(view.contains("_present_resolve"), "hot-seat and online share resolve chrome")
	eq(view.split("_present_resolve(").size() >= 3, true, "net state and submit both present resolve chrome")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	eq(pawn_src.contains("burn_remaining -"), false, "pawn does not tick Burn")
	eq(pawn_src.contains("tick_burn"), false, "pawn does not own Burn ticks")
	eq(pawn_src.contains("Pulse"), false, "pawn does not invent Pulse")


func _test_shoulder_impact_lava_burn_chrome() -> void:
	# Clean Shoulder: one +1 Impact toast. Not Bounce, not +2.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	var clean: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	var clean_toast := CombatHUD.toast_for_events(clean["events"])
	eq(clean_toast, "+1 Impact", "clean Shoulder toasts +1 Impact")
	eq(clean_toast.contains("+2"), false, "clean Shoulder toast is not +2")
	eq(clean_toast.contains(CombatHUD.BOUNCE_TOAST), false, "clean Shoulder toast is not Bounce")
	eq(CombatHUD.events_include_push_bounce(clean["events"]), false, "clean Shoulder is not a bounce")
	eq(CombatHUD.should_play_walk_hops(clean["events"]), false, "Shoulder push does not hop")

	# Advance adjacency Impact stays off this toast. Strike does too.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(4, 4),
		"kestrel_facing": "N",
	})
	_sim.submit({"type": "end_turn"})
	var advanced: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 4)})
	eq(advanced["ok"], true, "Advance still resolves")
	eq(CombatHUD.toast_for_events(advanced["events"]), "", "Advance does not toast Shoulder Impact")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	var struck: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(4, 3)})
	eq(struck["ok"], true, "Strike still resolves")
	eq(CombatHUD.toast_for_events(struck["events"]), "", "Strike does not use the Shoulder Impact toast")

	# Illegal Shoulder still refunds and keeps the REJECT coach. No Impact toast.
	var illegal: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(6, 3)})
	eq(illegal["illegal"], true, "out-of-range Shoulder stays illegal")
	eq(illegal["reason"], "out_of_range", "range reject reason is unchanged")
	eq(_unit(1)["ap"], 3, "range reject still refunds AP")
	eq(CombatHUD.toast_for_events(illegal["events"]), "", "illegal Shoulder does not toast Impact")
	truthy(str(illegal["snapshot"].get("coach", "")).begins_with("REJECT"), "illegal coach stays a REJECT line")

	# Capped bounce: one sim gain, not +1 and +2.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"kestrel_facing": "E",
		"ironjaw_impact": 3,
	})
	_sim.submit({"type": "end_turn"})
	var clipped: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(0, 0)})
	eq(int(clipped["events"][0]["engine_gained"]), 1, "capped bounce stores the clipped gain")
	var clipped_toast := CombatHUD.toast_for_events(clipped["events"])
	eq(clipped_toast, "Bounce  +1 Impact", "capped bounce toasts Bounce and the single sim gain")
	eq(clipped_toast.contains("+2"), false, "capped bounce does not also toast +2")

	# Lava land: +1 Impact and Burn, never Bounce. Both peers paint the same icon.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0}],
	})
	_sim.submit({"type": "end_turn"})
	var walked: Dictionary = _sim.submit({"type": "move", "to": Vector2i(5, 3)})
	eq(walked["illegal"], true, "walk onto lava stays rejected")
	eq(CombatHUD.toast_for_events(walked["events"]), "", "rejected lava walk does not toast Burn")
	var lava: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)})
	var lava_toast := CombatHUD.toast_for_events(lava["events"])
	eq(lava_toast, "+1 Impact  Lava - Burn", "lava land toasts +1 Impact and Burn")
	eq(lava_toast.contains(CombatHUD.BOUNCE_TOAST), false, "lava land toast is not Bounce")
	eq(lava_toast.contains("+2"), false, "lava land toast is not +2 Impact")
	eq(CombatHUD.events_include_push_bounce(lava["events"]), false, "lava land is not a bounce")
	eq(CombatHUD.events_include_lava_burn(lava["events"]), true, "lava land is a Burn apply")
	eq(CombatHUD.should_play_walk_hops(lava["events"]), false, "lava land does not hop")
	var hud := CombatHUD.new()
	hud._build()
	hud.show_toast(lava_toast)
	eq(hud.toast_caption(), "+1 Impact  Lava - Burn", "HUD shows the lava Burn toast")
	hud.render(lava["snapshot"], [])
	truthy(str(hud._kestrel_body.text).contains("[b]BURN[/b] 2"), "host card shows Burn duration")
	var replica_script := load("res://backend/combat_sim.gd")
	var replica = replica_script.new()
	replica.apply_host_snapshot(lava["snapshot"])
	var guest_snap: Dictionary = replica.snapshot()
	var guest_hud := CombatHUD.new()
	guest_hud._build()
	guest_hud.render(guest_snap, [])
	eq(str(guest_hud._kestrel_body.text), str(hud._kestrel_body.text), "guest card matches the host Burn line")
	var host_pawn := Pawn.new()
	host_pawn.apply_snapshot(lava["snapshot"]["units"][0], 1, lava["snapshot"]["last_events"])
	var guest_pawn := Pawn.new()
	guest_pawn.apply_snapshot(guest_snap["units"][0], 1, guest_snap["last_events"])
	eq(host_pawn.burn_badge_label(), "BURN 2", "host pawn badge shows remaining turns")
	eq(guest_pawn.burn_badge_label(), host_pawn.burn_badge_label(), "guest pawn badge matches the host")
	eq(host_pawn.burning, true, "host pawn is burning")
	eq(guest_pawn.burn_remaining, 2, "guest pawn remaining is the snapshot value")
	var partial: Dictionary = lava["snapshot"]["units"][0].duplicate(true)
	partial.erase("burn_remaining")
	var from_events := Pawn.new()
	from_events.apply_snapshot(partial, 1, lava["snapshot"]["last_events"])
	eq(from_events.burn_remaining, 2, "status events paint Burn when the unit field is absent")
	eq(from_events.burn_badge_label(), "BURN 2", "event fallback still shows remaining turns")
	var authoritative: Dictionary = lava["snapshot"]["units"][0].duplicate(true)
	authoritative["burn_remaining"] = 1
	var pinned := Pawn.new()
	pinned.apply_snapshot(authoritative, 1, lava["snapshot"]["last_events"])
	eq(pinned.burn_remaining, 1, "snapshot burn_remaining wins over older status events")
	eq(pinned.burn_badge_label(), "BURN 1", "badge follows the snapshot, not a client add")
	var held := host_pawn.burn_remaining
	var ticked: Dictionary = _sim.submit({"type": "end_turn"})
	eq(host_pawn.burn_remaining, held, "pawn does not tick Burn when the sim does")
	eq(CombatHUD.events_include_lava_burn(ticked["events"]), false, "a Burn tick is not a new lava land")
	eq(CombatHUD.toast_for_events(ticked["events"]), "", "a Burn tick does not toast Lava - Burn")
	var after := Pawn.new()
	after.apply_snapshot(_unit(0), int(_sim.snapshot()["active_seat"]))
	eq(after.burn_badge_label(), "BURN 1", "the next snapshot paints the ticked remaining")
	eq(after.burn_remaining, 1, "ticked remaining comes from the snapshot")
	host_pawn.free()
	guest_pawn.free()
	from_events.free()
	pinned.free()
	after.free()
	hud.free()
	guest_hud.free()
	replica.free()

	# A stray bounce flag must not stack +1 and +2 or win over lava.
	var mixed: Array = [
		{
			"type": "hit",
			"spell": "shoulder",
			"engine": "impact",
			"engine_gained": 1,
			"bounced": true,
			"burn_applied": true,
			"burn_remaining": 2,
		},
		{"type": "push_bounce"},
		{"type": "status", "status": "burn", "remaining": 2, "target_seat": 0},
	]
	eq(CombatHUD.events_include_push_bounce(mixed), false, "lava events are not Bounce")
	eq(CombatHUD.toast_for_events(mixed), "+1 Impact  Lava - Burn", "mixed lava events toast Burn once")
	eq(CombatHUD.toast_for_events(mixed).contains("+2"), false, "mixed lava events do not add +2")
	var stacked: Array = [
		{"type": "hit", "spell": "shoulder", "engine": "impact", "engine_gained": 2, "bounced": true},
		{"type": "push_bounce"},
		{"type": "hit", "spell": "shoulder", "engine": "impact", "engine_gained": 1},
	]
	eq(CombatHUD.toast_for_events(stacked), "Bounce  +2 Impact", "only the first Shoulder gain is toasted")
	eq(CombatHUD.toast_for_events(stacked).contains("+1"), false, "a second hit does not add +1")

	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("LAVA_BURN_TOAST"), "HUD names the lava Burn toast")
	eq(hud_src.contains("Pulse"), false, "HUD does not invent Pulse")
	eq(hud_src.contains("tick_burn"), false, "HUD does not tick Burn")


func _test_legal_intents_new_spell_gates() -> void:
	# Detonate appears only with 1+ Marks on the target and Chebyshev 1–4.
	# Mark Shot is Chebyshev 2–7.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
	})
	eq(_has_legal_cast(0, "detonate"), false, "legal_intents omit Detonate at 0 Marks")
	eq(_has_legal_cast(0, "mark_shot"), true, "Mark Shot still offered at range 2")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_marks": 1,
	})
	eq(_has_legal_cast(0, "detonate"), true, "legal_intents include Detonate with 1 Mark in range")
	eq(_has_legal_cast(0, "mark_shot"), true, "Mark Shot still offered alongside Detonate")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(1, 0),
		"ironjaw_marks": 2,
	})
	eq(_has_legal_cast(0, "detonate"), true, "Detonate offered at Chebyshev 1")
	eq(_has_legal_cast(0, "mark_shot"), false, "Mark Shot still min-range 2")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(4, 0),
		"ironjaw_marks": 1,
	})
	eq(_has_legal_cast(0, "detonate"), true, "Detonate offered at Chebyshev 4")
	eq(_has_legal_cast(0, "mark_shot"), true, "Mark Shot offered at Chebyshev 4")

	for dist in [5, 6, 7]:
		_sim.reset_match({
			"seed": 1,
			"flat_board": true,
			"kestrel_pos": Vector2i(0, 0),
			"ironjaw_pos": Vector2i(dist, 0),
			"ironjaw_marks": 1,
		})
		eq(_has_legal_cast(0, "detonate"), false, "Detonate out of range at Chebyshev %d" % dist)
		eq(_has_legal_cast(0, "mark_shot"), true, "Mark Shot legal at Chebyshev %d" % dist)

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(8, 0),
		"ironjaw_marks": 1,
	})
	eq(_has_legal_cast(0, "detonate"), false, "Detonate out of range at Chebyshev 8")
	eq(_has_legal_cast(0, "mark_shot"), false, "Mark Shot max-range 7")

	# Shoulder at range 1; Crush only with 2+ Impact.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
	})
	_sim.submit({"type": "end_turn"})
	eq(_has_legal_cast(1, "shoulder"), true, "Shoulder offered at range 1")
	eq(_has_legal_cast(1, "strike"), true, "Strike offered at range 1")
	eq(_has_legal_cast(1, "crush"), false, "Crush omitted at 0 Impact")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"ironjaw_impact": 2,
	})
	_sim.submit({"type": "end_turn"})
	eq(_has_legal_cast(1, "crush"), true, "Crush offered with 2 Impact at range 1")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(6, 3),
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	eq(_has_legal_cast(1, "crush"), false, "Crush omitted when out of range even at 4 Impact")
	eq(_has_legal_cast(1, "shoulder"), false, "Shoulder omitted when out of range")

	# Range chrome for Detonate is Chebyshev 1–4. Hit-percent chrome is tested separately.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(3, 3), "ironjaw_pos": Vector2i(5, 3)})
	var painted: Dictionary = {}
	for cell in _sim.range_highlight_cells(0, SpellKits.DETONATE):
		painted[cell] = true
	eq(painted.has(Vector2i(3, 4)), true, "Chebyshev 1 is inside Detonate chrome")
	eq(painted.has(Vector2i(3, 3)), false, "caster tile is not in Detonate chrome")
	truthy(painted.has(Vector2i(0, 3)), "Chebyshev 3 ortho is inside Detonate chrome")
	eq(painted.has(Vector2i(3, 7)), true, "Chebyshev 4 ortho is inside Detonate chrome")
	eq(painted.has(Vector2i(3, 8)), false, "Chebyshev 5 ortho is outside Detonate chrome")
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(7, 7)})
	var has_r4 := false
	var has_r5 := false
	var has_r6 := false
	var has_r1 := false
	for cell in _sim.range_highlight_cells(0, SpellKits.DETONATE):
		var d := int(_sim.chebyshev(Vector2i(0, 0), cell))
		if d == 4:
			has_r4 = true
		if d == 5:
			has_r5 = true
		if d == 6:
			has_r6 = true
		if d == 1:
			has_r1 = true
	truthy(has_r1, "Detonate chrome includes Chebyshev 1")
	truthy(has_r4, "Detonate chrome includes Chebyshev 4")
	eq(has_r5, false, "Detonate chrome excludes Chebyshev 5")
	eq(has_r6, false, "Detonate chrome excludes Chebyshev 6")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("aim_hit_preview"), "board_view feeds Locked hit-percent preview")
	eq(view.contains("hit_chance"), false, "board_view does not call hit_chance itself")
	eq(view.contains("hit-%"), false, "board_view has no hardcoded hit-percent label")


func _test_kit_class_exclusions() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
	eq(_sim.snapshot()["walk"], "weighted", "Walk stays weighted")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("WIND_MOD"), false, "CombatSim still has no WIND_MOD constant")
	eq(sim_src.contains("wind_mod"), false, "CombatSim still has no wind_mod term")
	eq(sim_src.contains("* WindMod"), false, "CombatSim still does not multiply by WindMod")


func _test_hud_marks_and_impact_pips() -> void:
	# Phone playtest: Mark Shot logs +1 Mark on Gloam, but Kestrel's Marks row
	# stayed empty because it read the caster. A01 stores the stack on the target.
	# Locked rules do not tick Marks off; Detonate consumes the stack.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "gloam"],
		"positions": [Vector2i(0, 0), Vector2i(4, 0)],
		"rolls": [1, 1, 1],
	})
	var hud := _hud_from_snap(_sim.snapshot())
	eq(_marks_row(hud, 0), "○○○○○", "Kestrel Marks row starts empty")
	eq(str(hud._ironjaw_body.text).contains("Marks"), false, "Gloam card keeps Umbral / Shades, not a second Marks row")
	hud.free()
	var marked: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 0)})
	eq(marked["ok"], true, "Mark Shot on Gloam connects")
	eq(int(_unit(1)["marks"]), 1, "the stack is on Gloam")
	eq(int(_unit(0)["marks"]), 0, "Kestrel's own marks field stays 0")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_marks_row(hud, 0), "●○○○○", "Kestrel Marks row shows 1/5 after the hit")
	hud.free()
	var stacked: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 0)})
	eq(stacked["ok"], true, "second Mark Shot connects")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_marks_row(hud, 0), "●●○○○", "Kestrel Marks row shows 2/5")
	hud.free()
	# Marks have no duration tick. They stay through the foe's turn, then Detonate clears them.
	eq(_sim.submit({"type": "end_turn"})["ok"], true, "Kestrel ends the turn with Marks still on Gloam")
	eq(_sim.submit({"type": "end_turn"})["ok"], true, "Gloam's turn does not expire Marks")
	eq(int(_unit(1)["marks"]), 2, "the stack is still on Gloam next Kestrel turn")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_marks_row(hud, 0), "●●○○○", "Kestrel Marks row still shows 2/5 after a full round")
	hud.free()
	var boom: Dictionary = _sim.submit({"type": "cast", "spell": "detonate", "to": Vector2i(4, 0)})
	eq(boom["ok"], true, "Detonate consumes the stack on Gloam")
	eq(int(_unit(1)["marks"]), 0, "Detonate clears target Marks")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_marks_row(hud, 0), "○○○○○", "Kestrel Marks row clears when Detonate spends the stack")
	hud.free()

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "gloam"],
		"positions": [Vector2i(0, 0), Vector2i(4, 0)],
		"rolls": [100],
	})
	var miss: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 0)})
	eq(str(miss["events"][0]["type"]), "miss", "scripted miss does not apply a Mark")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_marks_row(hud, 0), "○○○○○", "a miss leaves the Marks row empty")
	hud.free()

	# Ironjaw is the target: his own card already holds the stack, and Kestrel's row matches it.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(4, 0),
		"ironjaw_facing": "W",
	})
	eq(_sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 0)})["ok"], true, "Mark Shot on Ironjaw connects")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_marks_row(hud, 0), "●○○○○", "Kestrel row shows the Mark on Ironjaw")
	eq(_marks_row(hud, 1), "●○○○○", "Ironjaw row shows the Mark stored on him")
	hud.free()

	# Impact lives on Ironjaw. His card reads that field on gain and on Crush spend.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3)})["ok"], true, "Strike grants Impact")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_impact_row(hud, 1), "●○○○", "Ironjaw Impact row shows 1/4 after Strike")
	eq(_impact_row(hud, 0), "○○○○", "Kestrel does not display Ironjaw's Impact")
	hud.free()
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 3,
	})
	_sim.submit({"type": "end_turn"})
	eq(_sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})["ok"], true, "Crush spends Impact")
	eq(int(_unit(1)["impact"]), 1, "3-2 leaves 1 Impact")
	hud = _hud_from_snap(_sim.snapshot())
	eq(_impact_row(hud, 1), "●○○○", "Ironjaw Impact row shows the stack left after Crush")
	hud.free()


func _hud_from_snap(snap: Dictionary) -> CombatHUD:
	var hud := CombatHUD.new()
	hud._build()
	hud.render(snap, [])
	return hud


func _marks_row(hud: CombatHUD, seat: int) -> String:
	return _pip_row(hud, seat, "Marks ")


func _impact_row(hud: CombatHUD, seat: int) -> String:
	return _pip_row(hud, seat, "Impact ")


func _pip_row(hud: CombatHUD, seat: int, label: String) -> String:
	var body := str(hud._kestrel_body.text) if seat == 0 else str(hud._ironjaw_body.text)
	var at := body.find(label)
	if at < 0:
		return ""
	var rest := body.substr(at + label.length())
	var pips := ""
	for i in rest.length():
		var ch := rest.substr(i, 1)
		if ch != "●" and ch != "○":
			break
		pips += ch
	return pips


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

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(0, 0), "ironjaw_pos": Vector2i(5, 0)})
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

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(3, 3), "ironjaw_pos": Vector2i(4, 3)})
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


func _test_preview_cast() -> void:
	# Read-only Locked kit preview. Crit roll stays OFF. No kit number changes.
	eq(_sim.snapshot().get("crit_roll", true), false, "crit roll stays OFF before preview tests")

	# Mark Shot: Chebyshev 5 → Locked 75%, sample 8 Air front, rolling.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [100],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(5, 0),
		"ironjaw_facing": "W",
	})
	var before := _preview_state()
	var preview: Dictionary = _sim.preview_cast(SpellKits.MARK_SHOT, Vector2i(0, 0), Vector2i(5, 0), 1)
	eq(preview["spell_id"], "mark_shot", "Mark Shot spell_id")
	eq(preview["name"], "Mark Shot", "Mark Shot name")
	eq(preview["ap"], 2, "Mark Shot costs 2 AP")
	eq(preview["mp"], 0, "Mark Shot costs 0 MP")
	eq(preview["range_mode"], "chebyshev", "Mark Shot range_mode is Chebyshev")
	eq(preview["min_range"], 2, "Mark Shot min 2")
	eq(preview["max_range"], 7, "Mark Shot max 7")
	eq(preview["range_text"], "range 2–7", "Mark Shot HUD range_text omits Chebyshev")
	eq(preview["in_range"], true, "Chebyshev 5 is in Mark Shot range")
	eq(preview["rolling"], true, "Mark Shot is a rolling cast")
	eq(preview["hit_chance"], 75, "Mark Shot range 5 uses Locked 75% band")
	eq(preview["sample_damage"], 8, "front Mark Shot samples 8 Air (CritMult 1.0, Passive 1, Mastery 0)")
	eq(preview["on_connect_text"], "8 Air. +1 Mark on the target.", "Mark Shot connect kit line")
	eq(preview["on_miss_text"], "AP/MP stay spent. No Mark.", "Mark Shot miss kit line")
	eq(preview["legal"], true, "in-range Mark Shot with a target is legal")
	truthy(_notes_has(preview["notes"], "Resist 0"), "sample damage labels Resist 0")
	truthy(_notes_has(preview["notes"], "provisional"), "Resist 0 is labeled provisional")
	eq(_notes_has(preview["notes"], "WindMod"), false, "preview does not invent WindMod")
	_assert_preview_did_not_mutate(before, "Mark Shot preview is read-only")
	var miss: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(5, 0)})
	eq(miss["events"][0]["type"], "miss", "scripted 100 still misses after preview — RNG/rolls untouched")
	eq(_unit(1)["hp"], 80, "Mark Shot preview did not deal damage")
	eq(_unit(1)["marks"], 0, "Mark Shot preview did not apply Marks")

	# Intent Dictionary form uses the same Mark Shot preview.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(5, 0),
		"ironjaw_facing": "W",
	})
	preview = _sim.preview_cast({
		"type": "cast",
		"spell": "mark_shot",
		"to": Vector2i(5, 0),
		"target_seat": 1,
		"seat": 0,
	})
	eq(preview["hit_chance"], 75, "intent Dictionary Mark Shot still uses Locked 75%")
	eq(preview["sample_damage"], 8, "intent Dictionary Mark Shot still samples 8")
	eq(preview["rolling"], true, "intent Dictionary Mark Shot is rolling")

	# Back facing uses live target facing (8 × 1.20 → 10).
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_facing": "E",
	})
	preview = _sim.preview_cast(SpellKits.MARK_SHOT, Vector2i(0, 0), Vector2i(2, 0), 1)
	eq(preview["hit_chance"], 80, "Mark Shot Chebyshev 2 uses Locked 80% band")
	eq(preview["sample_damage"], 10, "back Mark Shot samples 8 × 1.20 = 10")

	# Detonate M=3 → 24 Air. Formula 6+6*M. Needs marks when M<1.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [50],
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_facing": "W",
		"ironjaw_marks": 3,
	})
	before = _preview_state()
	preview = _sim.preview_cast(SpellKits.DETONATE, Vector2i(0, 0), Vector2i(2, 0), 1)
	eq(preview["name"], "Detonate", "Detonate name")
	eq(preview["ap"], 3, "Detonate costs 3 AP")
	eq(preview["rolling"], true, "Detonate is rolling")
	eq(preview["marks_on_target"], 3, "Detonate preview reports current Marks")
	eq(preview["formula"], "6+6*M", "Detonate formula is 6+6*M")
	eq(preview["sample_damage"], 24, "Detonate M=3 samples 6+6*3 = 24")
	eq(preview["hit_chance"], 80, "Detonate Chebyshev 2 uses Locked 80%")
	eq(preview["legal"], true, "Detonate with M=3 is legal")
	eq(preview["on_connect_text"], "6+6×M Air. Consumes Marks on the target.", "Detonate connect kit line")
	eq(preview["on_miss_text"], "Marks stay. AP/MP stay spent.", "Detonate miss kit line")
	_assert_preview_did_not_mutate(before, "Detonate preview is read-only")
	eq(_unit(1)["marks"], 3, "Detonate preview does not consume Marks")
	eq(_unit(1)["hp"], 80, "Detonate preview does not deal 24")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_marks": 0,
	})
	preview = _sim.preview_cast(SpellKits.DETONATE, Vector2i(0, 0), Vector2i(2, 0), 1)
	eq(preview["legal"], false, "Detonate with M<1 is not legal")
	eq(preview["reason"], "needs_marks", "Detonate M<1 reason is needs_marks")
	eq(preview["marks_on_target"], 0, "Detonate M=0 still reports marks_on_target")
	eq(preview["sample_damage"], null, "Detonate M=0 does not lead with sample_damage=6")
	eq(preview["formula"], "6+6*M", "needs_marks still names 6+6*M for when Marks exist")
	eq(preview["on_connect_text"], "6+6×M Air. Consumes Marks on the target.", "needs_marks on_connect still explains 6+6×M")
	truthy(_notes_has(preview["notes"], "6+6×M"), "needs_marks notes explain 6+6×M when Marks exist")
	eq(_unit(0)["ap"], 6, "needs_marks preview does not spend AP")

	# Crush: would_stun when Impact is 4 and would spend 2. Sample 24 Earth front.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	before = _preview_state()
	preview = _sim.preview_cast(SpellKits.CRUSH, Vector2i(4, 3), Vector2i(3, 3), 0)
	eq(preview["name"], "Crush", "Crush name")
	eq(preview["ap"], 4, "Crush costs 4 AP")
	eq(preview["rolling"], true, "Crush is rolling")
	eq(preview["hit_chance"], 90, "Crush melee uses Locked 90%")
	eq(preview["impact_before"], 4, "Crush preview reports impact_before 4")
	eq(preview["would_stun"], true, "Crush would_stun at Impact 4 spending 2")
	eq(preview["sample_damage"], 24, "front Crush samples 24 Earth")
	eq(preview["on_connect_text"], "24 Earth. Spends 2 Impact. Stun 1 if Impact was 4.", "Crush connect kit line")
	eq(preview["on_miss_text"], "Impact retained. AP/MP stay spent.", "Crush miss kit line")
	eq(preview["legal"], true, "Crush at 4 Impact is legal")
	_assert_preview_did_not_mutate(before, "Crush preview is read-only")
	eq(_unit(1)["impact"], 4, "Crush preview does not spend Impact")
	eq(_unit(0)["stun_remaining"], 0, "Crush preview does not apply Stun")
	eq(_unit(0)["hp"], 80, "Crush preview does not deal 24")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 2,
	})
	_sim.submit({"type": "end_turn"})
	preview = _sim.preview_cast(SpellKits.CRUSH, Vector2i(4, 3), Vector2i(3, 3), 0)
	eq(preview["impact_before"], 2, "Crush at 2 Impact reports impact_before 2")
	eq(preview["would_stun"], false, "Crush does not stun when Impact before is 2")
	eq(preview["sample_damage"], 24, "Crush still samples 24 Earth at Impact 2")

	# Shoulder: sample 6 + push note.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	preview = _sim.preview_cast(SpellKits.SHOULDER, Vector2i(3, 3), Vector2i(4, 3), 0)
	eq(preview["sample_damage"], 6, "front Shoulder samples 6 Earth")
	eq(preview["rolling"], true, "Shoulder is rolling")
	eq(preview["hit_chance"], 90, "Shoulder melee uses Locked 90%")
	truthy(_notes_has(preview["notes"], "Push"), "Shoulder preview notes the push")
	eq(_notes_has(preview["notes"], "Chebyshev"), false, "Shoulder HUD note does not name Chebyshev")
	eq(preview["on_connect_text"], "6 Earth. +1 Impact. Push 1.", "Shoulder connect kit line")

	# Advance: teleport note, no hit_chance, sample_damage null.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	before = _preview_state()
	preview = _sim.preview_cast(SpellKits.ADVANCE, Vector2i(3, 3), Vector2i(5, 3))
	eq(preview["name"], "Advance", "Advance name")
	eq(preview["ap"], 3, "Advance costs 3 AP")
	eq(preview["mp"], 0, "Advance costs 0 MP")
	eq(preview["range_mode"], "cardinal", "Advance range_mode is cardinal")
	eq(preview["min_range"], 2, "Advance min 2")
	eq(preview["max_range"], 2, "Advance max 2")
	eq(preview["range_text"], "exactly 2 cardinal", "Advance HUD range_text is exactly 2 cardinal")
	eq(preview["in_range"], true, "two-tile cardinal is in Advance range")
	eq(preview["rolling"], false, "Advance is not a rolling cast")
	eq(preview["hit_chance"], null, "Advance has no hit_chance")
	eq(preview["sample_damage"], null, "Advance sample_damage is null")
	eq(preview["legal"], true, "empty cardinal-2 Advance dest is legal")
	var near_preview: Dictionary = _sim.preview_cast(SpellKits.ADVANCE, Vector2i(3, 3), Vector2i(4, 3))
	eq(near_preview["in_range"], false, "Manhattan 1 is out of Advance range")
	eq(near_preview["legal"], false, "empty Manhattan 1 Advance dest is illegal")
	eq(near_preview["reason"], "out_of_range", "preview_cast rejects Manhattan 1")
	var diag_preview: Dictionary = _sim.preview_cast(SpellKits.ADVANCE, Vector2i(3, 3), Vector2i(4, 4))
	eq(diag_preview["in_range"], false, "diagonal is out of Advance range")
	eq(diag_preview["legal"], false, "diagonal Advance dest is illegal")
	eq(diag_preview["reason"], "out_of_range", "preview_cast rejects a diagonal")
	truthy(_notes_has(preview["notes"], "teleport"), "Advance notes teleport")
	eq(preview["on_connect_text"], "Teleport snap. +1 Impact if adjacent. Facing unchanged.", "Advance connect kit line")
	eq(preview["on_miss_text"], "No roll.", "Advance has no roll")
	_assert_preview_did_not_mutate(before, "Advance preview is read-only")
	eq(_unit(1)["pos"], Vector2i(3, 3), "Advance preview does not teleport")
	eq(_unit(1)["ap"], 6, "Advance preview does not spend AP")
	eq(_unit(1)["impact"], 0, "Advance preview does not grant Impact")
	eq(_unit(1)["facing"], "W", "Advance preview does not change facing")

	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF after preview_cast")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(sim_src.contains("func preview_cast"), "CombatSim exposes preview_cast")
	truthy(sim_src.contains("func chebyshev"), "CombatSim still keeps the chebyshev metric")
	truthy(sim_src.contains("range_text"), "preview_cast exposes player-facing range_text")
	eq(sim_src.contains("WIND_MOD"), false, "preview patch does not add WIND_MOD")
	eq(sim_src.contains("* WindMod"), false, "preview patch does not multiply by WindMod")


func _preview_state() -> Dictionary:
	return {
		"snap": _sim.snapshot().duplicate(true),
		"log_size": _sim._intent_log.size(),
		"rolls": _sim._scripted_rolls.duplicate(),
		"rng": _sim._rng.state,
		"events": _sim._last_events.duplicate(true),
		"coach": str(_sim._last_coach),
		"turn": int(_sim._turn_index),
		"seat": int(_sim._active_seat),
	}


func _assert_preview_did_not_mutate(before: Dictionary, msg: String) -> void:
	var after := _preview_state()
	eq(after["log_size"], before["log_size"], "%s (intent log)" % msg)
	eq(after["rolls"], before["rolls"], "%s (scripted rolls)" % msg)
	eq(after["rng"], before["rng"], "%s (RNG state)" % msg)
	eq(after["events"], before["events"], "%s (last events)" % msg)
	eq(after["coach"], before["coach"], "%s (coach)" % msg)
	eq(after["turn"], before["turn"], "%s (turn index)" % msg)
	eq(after["seat"], before["seat"], "%s (active seat)" % msg)
	eq(after["snap"]["units"], before["snap"]["units"], "%s (units)" % msg)
	eq(after["snap"]["match_over"], before["snap"]["match_over"], "%s (match_over)" % msg)
	eq(after["snap"]["seed"], before["snap"]["seed"], "%s (seed)" % msg)
	eq(after["snap"]["crit_roll"], false, "%s (crit roll stays OFF)" % msg)


func _notes_has(notes: Variant, needle: String) -> bool:
	if typeof(notes) != TYPE_ARRAY:
		return false
	for note in notes:
		if str(note).contains(needle):
			return true
	return false


func _test_legal_moves_after_advance() -> void:
	# Godot Engineer: after Advance (or any cast), remaining MP still offers
	# Manhattan walks — including 0 AP / 3 MP. Client clears spell + repaints
	# from legal_intents. Crit roll stays OFF; this patch does not invent Stun/push.
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(3, 3)})
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")
	_sim.submit({"type": "end_turn"})
	eq(_unit(1)["ap"], 6, "Ironjaw starts at 6 AP")
	eq(_unit(1)["mp"], 3, "Ironjaw starts at 3 MP")
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "first Advance spends 3 AP")
	eq(_unit(1)["ap"], 3, "3 AP remain after Advance")
	eq(_unit(1)["mp"], 3, "Advance spends 0 MP")
	eq(_unit(1)["pos"], Vector2i(5, 3), "Ironjaw snapped two tiles east")
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
	truthy(moves.size() > 0, "0 AP / 3 MP still offers walks")
	truthy(moves.has(Vector2i(6, 5)), "walk dest after 0 AP Advance is legal")
	result = _sim.submit({"type": "move", "to": Vector2i(6, 5)})
	eq(result["ok"], true, "walk after Advance is accepted")
	eq(_unit(1)["mp"], 2, "walk spends MP after Advance")
	eq(_unit(1)["pos"], Vector2i(6, 5), "pawn walked after Advance")

	# Any dest-click cast, not only Advance: Strike spends AP, MP stays, walks remain.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
	eq(click_src.contains("stun_remaining"), false, "walk-after-cast dest-click does not invent Stun")
	eq(click_src.contains("push_blocked"), false, "walk-after-cast dest-click does not invent push")
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
		"flat_board": true,
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
		"flat_board": true,
		"kestrel_pos": Vector2i(2, 2),
		"kestrel_facing": "E",
		"ironjaw_pos": Vector2i(7, 7),
	})
	result = _sim.submit({"type": "move", "to": Vector2i(2, 0)})
	eq(_unit(0)["facing"], "N", "north walk faces N")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
	eq(anim_src.contains("stun_remaining"), false, "last-hop face anim does not invent Stun")
	eq(anim_src.contains("push_blocked"), false, "last-hop face anim does not invent push")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")


func _test_advance_facing_unchanged() -> void:
	# Locked: Advance teleport does not auto-face. Walk last-hop facing is separate.
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "cardinal Advance dest-click is legal")
	eq(_unit(1)["pos"], Vector2i(5, 3), "Advance still snaps to dest")
	eq(_unit(1)["facing"], "W", "east Advance leaves facing W unchanged")
	eq(result["events"][0].has("facing"), false, "Advance event does not set facing")
	eq(result["events"][0].has("path"), false, "Advance still emits no hop path")
	eq(result["events"][0]["teleport"], true, "Advance stays a teleport")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
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
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 1)})
	eq(_unit(1)["facing"], "E", "north Advance leaves facing E unchanged")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(3, 3),
		"ironjaw_facing": "E",
	})
	_sim.submit({"type": "end_turn"})
	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(2, 2)})
	eq(result["illegal"], true, "NW diagonal Advance is rejected")
	eq(result["reason"], "out_of_range", "diagonal Advance reject is out_of_range")
	eq(_unit(1)["facing"], "E", "rejected diagonal Advance leaves facing E unchanged")
	eq(_unit(1)["pos"], Vector2i(3, 3), "rejected diagonal Advance does not move")
	eq(_unit(1)["ap"], 6, "rejected diagonal Advance refunds AP")

	result = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(3, 1)})
	eq(result["ok"], true, "cardinal Advance after a rejected diagonal is legal")
	eq(_unit(1)["facing"], "E", "accepted cardinal Advance still does not auto-face")
	eq(_unit(1)["pos"], Vector2i(3, 1), "cardinal Advance snaps north")
	eq(_unit(1)["ap"], 3, "cardinal Advance spends 3 AP")

	result = _sim.submit({"type": "face", "dir": "N"})
	eq(result["ok"], true, "in-place face remains legal after Advance")
	eq(_unit(1)["facing"], "N", "manual face after Advance still works")
	eq(_unit(1)["pos"], Vector2i(3, 1), "manual face does not move")
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
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(3, 3)})
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
	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(3, 3)})
	_sim.submit({"type": "end_turn"})
	var result: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3)})
	eq(result["ok"], true, "Advance dest-click resolves")
	eq(_unit(1)["ap"], 3, "3 AP remain")
	eq(_unit(1)["mp"], 3, "MP remains after Advance")
	var moves := _legal_move_dests(1)
	truthy(moves.has(Vector2i(6, 3)), "after Advance, legal_intents still include walks")
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


func _test_spell_tooltip_cards() -> void:
	# Proposed hover/long-press chrome. Cards format preview_cast only.
	eq(SpellTooltip.card_text({}), "", "empty preview has no card")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll stays OFF")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(5, 0),
		"ironjaw_facing": "W",
	})
	var mark_preview: Dictionary = _sim.preview_cast(SpellKits.MARK_SHOT, Vector2i(0, 0), Vector2i(5, 0), 1)
	var mark := SpellTooltip.card_text(mark_preview)
	eq(mark_preview["sample_damage"], 8, "Mark Shot preview samples live facing 8")
	eq(mark_preview["hit_chance"], 75, "Mark Shot preview HIT is Locked 75 at range 5")
	truthy(mark.contains("Mark Shot"), "Mark Shot card names the spell")
	truthy(mark.contains("2 AP / 0 MP"), "Mark Shot card names AP/MP from preview")
	eq(mark_preview["range_text"], "range 2–7", "Mark Shot preview_cast range_text is player-facing")
	truthy(mark.contains("range 2–7"), "Mark Shot card names range from preview")
	eq(mark.contains("Chebyshev"), false, "Mark Shot card does not name Chebyshev")
	truthy(mark.contains("On hit: 8 Air. +1 Mark on the target."), "Mark Shot hit line is preview kit text")
	truthy(mark.contains("On miss: AP/MP stay spent. No Mark."), "Mark Shot miss line is preview kit text")
	truthy(mark.contains("HIT 75% (Locked)"), "Mark Shot card uses preview hit_chance")
	truthy(mark.contains("sample 8"), "Mark Shot card uses preview sample_damage")
	truthy(mark.contains("CritMult(1.0) × live Facing"), "Mark Shot sample names CritMult 1.0 and live Facing")
	eq(mark.contains("+5"), false, "Mark Shot card does not invent +5")
	eq(mark.contains("longshot"), false, "Mark Shot card does not invent longshot")
	eq(mark.contains("WindMod"), false, "tooltip does not invent WindMod")
	eq(mark.contains("Mastery"), false, "tooltip omits Mastery 0")
	truthy(mark.contains("Resist 0 (provisional Open A05)"), "Resist is preview's provisional Open note")
	eq(mark.contains("Step-shot"), false, "tooltip does not invent Step-shot")
	eq(mark.contains("Gust"), false, "tooltip does not invent Gust")
	eq(mark.contains("crit roll"), false, "tooltip does not turn crit roll ON")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_facing": "E",
	})
	var mark_back := SpellTooltip.card_text(_sim.preview_cast(SpellKits.MARK_SHOT, Vector2i(0, 0), Vector2i(2, 0), 1))
	truthy(mark_back.contains("HIT 80% (Locked)"), "Mark Shot back preview uses Locked 80% at range 2")
	truthy(mark_back.contains("sample 10"), "Mark Shot back preview samples 8 × 1.20 = 10")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_facing": "W",
		"ironjaw_marks": 3,
	})
	var detonate_preview: Dictionary = _sim.preview_cast(SpellKits.DETONATE, Vector2i(0, 0), Vector2i(2, 0), 1)
	var detonate := SpellTooltip.card_text(detonate_preview)
	eq(detonate_preview["marks_on_target"], 3, "Detonate preview uses current Marks")
	eq(detonate_preview["sample_damage"], 24, "Detonate M=3 samples 24")
	truthy(detonate.contains("3 AP / 0 MP"), "Detonate card names AP/MP from preview")
	eq(detonate_preview["range_text"], "range 1–4", "Detonate preview_cast range_text is player-facing")
	truthy(detonate.contains("range 1–4"), "Detonate card names range from preview")
	eq(detonate.contains("Chebyshev"), false, "Detonate card does not name Chebyshev")
	truthy(detonate.contains("On hit: 6+6×M Air. Consumes Marks on the target."), "Detonate hit line is preview kit text")
	truthy(detonate.contains("On miss: Marks stay. AP/MP stay spent."), "Detonate miss line is preview kit text")
	truthy(detonate.contains("HIT 80% (Locked)"), "Detonate card uses preview hit_chance")
	truthy(detonate.contains("sample 24"), "Detonate card uses current-M sample")
	truthy(detonate.contains("M=3 (6+6*M)"), "Detonate card names current Marks and formula")
	eq(detonate.contains("+5"), false, "Detonate card does not invent +5")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_marks": 0,
	})
	var detonate_m0_preview: Dictionary = _sim.preview_cast(SpellKits.DETONATE, Vector2i(0, 0), Vector2i(2, 0), 1)
	var detonate_m0 := SpellTooltip.card_text(detonate_m0_preview)
	eq(detonate_m0_preview["legal"], false, "Detonate M=0 preview is not legal")
	eq(detonate_m0_preview["reason"], "needs_marks", "Detonate M=0 card preview is needs_marks")
	eq(detonate_m0_preview["sample_damage"], null, "Detonate M=0 preview omits sample_damage")
	eq(detonate_m0.contains("sample 6"), false, "Detonate M=0 card does not lead with sample 6")
	eq(detonate_m0.contains("sample %d" % 6), false, "Detonate M=0 card has no numeric sample 6")
	truthy(detonate_m0.contains("6+6×M"), "Detonate M=0 card still explains 6+6×M")
	truthy(detonate_m0.contains("Needs 1+ Marks"), "Detonate M=0 card names the Marks gate")

	_sim.reset_match({"seed": 1, "flat_board": true, "kestrel_pos": Vector2i(7, 7), "ironjaw_pos": Vector2i(3, 3)})
	_sim.submit({"type": "end_turn"})
	var advance_preview: Dictionary = _sim.preview_cast(SpellKits.ADVANCE, Vector2i(3, 3), Vector2i(5, 3))
	var advance := SpellTooltip.card_text(advance_preview)
	eq(advance_preview["hit_chance"], null, "Advance preview has no hit_chance")
	eq(advance_preview["sample_damage"], null, "Advance preview has no sample_damage")
	eq(advance_preview["legal"], true, "Advance card preview dest is exactly 2 cardinal")
	truthy(advance.contains("Advance"), "Advance card names the spell")
	truthy(advance.contains("3 AP / 0 MP"), "Advance card names 3 AP / 0 MP from preview")
	truthy(advance.contains("exactly 2 cardinal"), "Advance card names the 2-cardinal range from preview")
	truthy(advance.contains("Facing unchanged"), "Advance card uses preview facing note")
	truthy(advance.contains("Teleport"), "Advance card uses preview teleport text")
	eq(advance.contains("HIT "), false, "Advance card has no HIT %")
	eq(advance.contains("sample "), false, "Advance card has no damage sample")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
	})
	_sim.submit({"type": "end_turn"})
	var strike := SpellTooltip.card_text(_sim.preview_cast(SpellKits.STRIKE, Vector2i(3, 3), Vector2i(4, 3), 0))
	truthy(strike.contains("range 1–1"), "Strike card names range 1 from preview")
	eq(strike.contains("Chebyshev"), false, "Strike card does not name Chebyshev")
	truthy(strike.contains("On hit: 16 Earth. +1 Impact."), "Strike hit line is preview kit text")
	truthy(strike.contains("HIT 90% (Locked)"), "Strike card uses preview melee 90%")
	truthy(strike.contains("sample 16"), "Strike card uses preview sample_damage")

	var shoulder_preview: Dictionary = _sim.preview_cast(SpellKits.SHOULDER, Vector2i(3, 3), Vector2i(4, 3), 0)
	var shoulder := SpellTooltip.card_text(shoulder_preview)
	truthy(shoulder.contains("On hit: 6 Earth. +1 Impact. Push 1."), "Shoulder hit line is preview kit text")
	truthy(shoulder.contains("Director Locked Shoulder"), "Shoulder card passes through Locked Shoulder note")
	eq(shoulder.contains("Open Push"), false, "Shoulder Push wording is Locked, not Open")
	truthy(shoulder.contains("HIT 90% (Locked)"), "Shoulder card uses preview melee 90%")
	truthy(shoulder.contains("sample 6"), "Shoulder card uses preview sample_damage")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	var crush_preview: Dictionary = _sim.preview_cast(SpellKits.CRUSH, Vector2i(4, 3), Vector2i(3, 3), 0)
	var crush := SpellTooltip.card_text(crush_preview)
	eq(crush_preview["would_stun"], true, "Crush preview flags stun at Impact 4")
	truthy(crush.contains("4 AP / 0 MP"), "Crush card names AP/MP from preview")
	truthy(crush.contains("On hit: 24 Earth. Spends 2 Impact. Stun 1 if Impact was 4."), "Crush hit line is preview kit text")
	truthy(crush.contains("On miss: Impact retained. AP/MP stay spent."), "Crush miss line is preview kit text")
	truthy(crush.contains("Stun 1 (Locked A′) this cast."), "Crush card shows stun flag when preview would_stun")
	eq(crush.contains("Stun 1 (Open"), false, "Crush Stun wording is Locked, not Open")
	truthy(crush.contains("HIT 90% (Locked)"), "Crush card uses preview melee 90%")
	truthy(crush.contains("sample 24"), "Crush card uses preview sample_damage")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 2,
	})
	_sim.submit({"type": "end_turn"})
	var crush_no_stun := SpellTooltip.card_text(_sim.preview_cast(SpellKits.CRUSH, Vector2i(4, 3), Vector2i(3, 3), 0))
	eq(crush_no_stun.contains("Stun 1 (Locked A′) this cast."), false, "Crush stun flag stays off when Impact is 2")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(5, 0),
		"ironjaw_facing": "W",
	})
	var hud := CombatHUD.new()
	hud._build()
	hud.set_preview_source(_sim)
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud.tooltip_visible(), false, "tooltip starts hidden")
	eq(CombatHUD.spell_card_text(mark_preview), mark, "HUD helper formats preview_cast")
	eq(hud.preview_for_spell(SpellKits.MARK_SHOT)["sample_damage"], 8, "HUD hover preview_cast samples live facing")
	eq((hud._spell_buttons[SpellKits.MARK_SHOT] as Button).disabled, false, "Mark Shot is enabled at start")
	eq((hud._spell_buttons[SpellKits.MARK_SHOT] as Button).mouse_entered.get_connections().is_empty(), false, "enabled Mark Shot button wires hover to preview_cast")
	hud._on_spell_hover(SpellKits.MARK_SHOT)
	eq(hud.tooltip_visible(), true, "hover shows the Mark Shot card")
	eq(hud.tooltip_caption(), SpellTooltip.card_text(hud.preview_for_spell(SpellKits.MARK_SHOT)), "hover caption is preview_cast formatted")
	truthy(hud._spell_hosts.has(SpellKits.MARK_SHOT), "Mark Shot button is wrapped for hover")
	hud._on_spell_unhover()
	eq(hud.tooltip_visible(), false, "unhover hides the card")
	hud._begin_long_press(SpellKits.MARK_SHOT)
	hud._process(0.1)
	eq(hud.tooltip_visible(), false, "short press does not open the card")
	hud._process(SpellTooltip.LONG_PRESS_SEC)
	eq(hud.tooltip_visible(), true, "long-press opens the card")
	hud.hide_spell_tooltip()
	eq(hud.tooltip_visible(), false, "hide clears the card")

	_sim.submit({"type": "end_turn"})
	hud.render(_sim.snapshot(), _sim.legal_intents(1))
	eq((hud._spell_buttons[SpellKits.CRUSH] as Button).disabled, true, "Crush stays grey at 0 Impact")
	eq((hud._spell_buttons[SpellKits.CRUSH] as Button).mouse_filter, Control.MOUSE_FILTER_IGNORE, "grey Crush still lets the host receive hover")
	hud._on_spell_hover(SpellKits.CRUSH)
	eq(hud.tooltip_visible(), true, "grey Crush still shows its card")
	eq(hud.tooltip_caption().contains("Stun 1 (Locked A′) this cast."), false, "grey Crush at 0 Impact does not flag this-cast Stun")
	eq((hud._spell_buttons[SpellKits.ADVANCE] as Button).disabled, false, "Advance is enabled on Ironjaw")
	eq((hud._spell_buttons[SpellKits.ADVANCE] as Button).mouse_entered.get_connections().is_empty(), false, "enabled Advance button wires hover to preview_cast")
	hud._on_spell_hover(SpellKits.ADVANCE)
	eq(hud.tooltip_caption().contains("HIT "), false, "Advance hover still has no HIT %")
	eq(hud.preview_for_spell(SpellKits.ADVANCE)["sample_damage"], null, "Advance hover preview has no sample")
	truthy(hud.tooltip_caption().contains("exactly 2 cardinal"), "Advance hover names the 2-cardinal range from preview")
	truthy(hud.tooltip_caption().contains("Teleport"), "Advance hover uses preview teleport text")
	hud._on_spell_hover(SpellKits.SHOULDER)
	truthy(hud.tooltip_caption().contains("Director Locked Shoulder"), "Shoulder hover names Director Locked Shoulder from preview")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"kestrel_pos": Vector2i(0, 0),
		"ironjaw_pos": Vector2i(2, 0),
		"ironjaw_facing": "W",
		"ironjaw_marks": 0,
	})
	hud.set_preview_source(_sim)
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	var gated_preview: Dictionary = hud.preview_for_spell(SpellKits.DETONATE)
	eq(gated_preview.get("reason", ""), "needs_marks", "Detonate hover preview_cast reports needs_marks at M=0")
	eq(int(gated_preview.get("marks_on_target", -1)), 0, "Detonate hover preview reports M=0")
	hud._on_spell_hover(SpellKits.DETONATE)
	var gated_card := hud.tooltip_caption()
	var gated_lines := gated_card.split("\n")
	truthy(gated_lines.size() >= 2, "M=0 Detonate card has a lead-in")
	eq(str(gated_lines[1]), "needs Marks", "M=0 Detonate card leads with needs Marks")
	truthy(gated_card.contains("3 AP / 0 MP"), "M=0 Detonate card keeps costs")
	truthy(gated_card.contains("range 1–4"), "M=0 Detonate card keeps range")
	eq(gated_card.contains("Chebyshev"), false, "M=0 Detonate card does not name Chebyshev")
	truthy(gated_card.contains("HIT "), "M=0 Detonate card keeps HIT%")
	eq(gated_card.contains("sample 6"), false, "M=0 Detonate card does not lead with sample 6")
	var sample_first := SpellTooltip.card_text({
		"name": "Detonate",
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 4,
		"hit_chance": 75,
		"on_connect_text": "6+6×M Air. Consumes Marks on the target.",
		"on_miss_text": "Marks stay. AP/MP stay spent.",
		"sample_damage": 6,
		"marks_on_target": 0,
		"reason": "needs_marks",
		"notes": ["Resist 0 (provisional Open A05)"],
	})
	eq(sample_first.split("\n")[1], "needs Marks", "formatter leads with needs Marks even if preview still samples 6")
	eq(sample_first.contains("sample 6"), false, "formatter hides sample 6 when preview is needs_marks")
	hud.free()

	var tooltip_src := FileAccess.get_file_as_string("res://data/spell_tooltip.gd")
	truthy(tooltip_src.contains("preview_cast"), "tooltip helper is wired to preview_cast")
	truthy(tooltip_src.contains("CritMult(1.0)"), "tooltip sample names CritMult(1.0)")
	eq(tooltip_src.contains("WindMod"), false, "tooltip source does not invent WindMod")
	eq(tooltip_src.contains("Step-shot"), false, "tooltip source does not invent Step-shot")
	eq(tooltip_src.contains("Gust"), false, "tooltip source does not invent Gust")
	eq(tooltip_src.contains("longshot"), false, "tooltip source does not invent longshot")
	eq(tooltip_src.contains("+5"), false, "tooltip source does not invent +5")
	truthy(tooltip_src.contains("Locked A"), "tooltip source stamps Locked Stun A")
	eq(tooltip_src.contains("OPEN A05"), false, "tooltip source does not hardcode OPEN A05")
	eq(tooltip_src.contains("Chebyshev"), false, "tooltip formatter does not name Chebyshev")
	truthy(tooltip_src.contains("range_text"), "tooltip formatter reads preview range_text")

	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("show_spell_tooltip"), "HUD can show the attack card")
	truthy(hud_src.contains("preview_cast"), "HUD calls preview_cast")
	truthy(hud_src.contains("mouse_entered"), "HUD wires hover on spell hosts")
	truthy(hud_src.contains("LONG_PRESS_SEC"), "HUD long-press uses the helper delay")
	eq(hud_src.contains("Detonate"), false, "HUD still does not hardcode Detonate")
	eq(hud_src.contains("Shoulder"), false, "HUD still does not hardcode Shoulder")
	eq(hud_src.contains("Crush"), false, "HUD still does not hardcode Crush")
	eq(hud_src.contains("WindMod"), false, "HUD still has no WindMod chrome")
	eq(hud_src.contains("Step-shot"), false, "HUD tooltip patch does not add Step-shot")

	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("attack cards"), "README documents Proposed attack cards")
	truthy(readme.contains("preview_cast"), "README says cards read preview_cast")
	eq(_sim.snapshot()["crit_roll"], false, "crit roll still OFF after tooltip tests")
	truthy(tooltip_src.contains("needs Marks"), "tooltip formatter can lead with needs Marks")
	eq(tooltip_src.contains("var connect :="), false, "tooltip no longer shadows Object.connect")
	truthy(hud_src.contains("_bind_spell_hover"), "HUD binds hover on enabled spell buttons")
	truthy(hud_src.contains("FlowContainer"), "HUD action bar wraps with FlowContainer")
	eq(hud_src.contains("var show :="), false, "HUD no longer shadows CanvasLayer.show")


func _test_action_bar_wraps() -> void:
	# 960×720 playtest: Ironjaw's kit must wrap instead of overlapping labels.
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	_sim.submit({"type": "end_turn"})
	var hud := CombatHUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(1))
	eq(hud._action_bar is FlowContainer, true, "action bar is a FlowContainer")
	eq(hud._action_bar.custom_minimum_size.y >= 72, true, "action bar has room for a wrapped row")
	eq(hud._walk_button.custom_minimum_size.x >= 80, true, "Walk keeps a readable min width")
	eq(hud._end_turn_button.custom_minimum_size.x >= 100, true, "End Turn keeps a readable min width")
	eq(hud._new_match_button.custom_minimum_size.x >= 100, true, "New Match keeps a readable min width")
	eq(hud._face_buttons.size(), 4, "Face N/E/S/W stay present")
	eq(hud.face_suppressed(), false, "Face stays usable while the bar wraps")
	for spell_id in hud._spell_hosts.keys():
		var host: Control = hud._spell_hosts[spell_id]
		eq(host.get_parent(), hud._ability_cluster, "spell host %s sits in the thumb cluster" % spell_id)
		eq(host.custom_minimum_size.x >= 72, true, "spell host %s keeps a fat hit target" % spell_id)
		eq(host.custom_minimum_size.y >= 72, true, "spell host %s keeps a fat hit height" % spell_id)
	var offered: Array = CombatHUD.offered_cast_ids(_unit(1), _sim.legal_intents(1))
	eq(offered.size(), 4, "Ironjaw offers four kit buttons")
	hud.free()

	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("FlowContainer"), "HUD source uses FlowContainer")
	truthy(hud_src.contains("h_separation"), "wrapped bar sets horizontal separation")
	eq(hud_src.contains("Detonate"), false, "wrap patch does not hardcode Detonate")


func _test_face_pad_layout() -> void:
	# Chrome-only: N/W/E/S sit on a cardinal pad. face_requested dirs stay N/E/S/W.
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	var hud := CombatHUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud._face_buttons.size(), 4, "Face N/E/S/W stay present")
	for dir in ["N", "E", "S", "W"]:
		eq(hud._face_buttons.has(dir), true, "Face button %s is wired" % dir)
		eq((hud._face_buttons[dir] as Button).text, dir, "Face button label is %s" % dir)
	var pad := _face_pad(hud)
	eq(pad != null, true, "Face bar hosts a GridContainer pad")
	eq(pad.columns, 3, "Face pad is 3 columns")
	eq(pad.get_child_count(), 9, "Face pad is a 3x3 with spacer cells")
	eq(pad.get_child(1), hud._face_buttons["N"], "N is top-center")
	eq(pad.get_child(3), hud._face_buttons["W"], "W is middle-left")
	eq(pad.get_child(5), hud._face_buttons["E"], "E is middle-right")
	eq(pad.get_child(7), hud._face_buttons["S"], "S is bottom-center")
	eq(pad.get_child(4) is Button, false, "center cell is a spacer, not a Face button")
	eq(hud.face_suppressed(), false, "Face stays usable after the pad layout")

	var got: Array = []
	hud.face_requested.connect(func(dir: String) -> void: got.append(dir))
	for dir in ["N", "E", "S", "W"]:
		(hud._face_buttons[dir] as Button).pressed.emit()
	eq(got, ["N", "E", "S", "W"], "Face buttons still emit N/E/S/W")

	hud.free()

	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("GridContainer"), "HUD Face pad uses GridContainer")
	truthy(hud_src.contains("face_requested.emit(dir)"), "_on_face_pressed still emits dir")
	eq(hud_src.contains("for dir in [\"N\", \"E\", \"S\", \"W\"]"), false, "Face buttons are not a single NESW row")
	eq(hud_src.contains("OPEN A05"), false, "Face pad does not invent Stun Open")


func _test_stun_skip_chrome() -> void:
	# Client presents CombatSim's auto-skip event. Does not submit end_turn itself.
	eq(CombatHUD.events_include_stun_skip([]), false, "empty events are not a skip")
	eq(CombatHUD.events_include_stun_skip([{"type": "status", "status": "stun", "coach": "Kestrel is stunned (Locked A)."}]), false, "Crush stun status is not a skip")
	eq(CombatHUD.events_include_stun_skip([{"type": "end_turn", "seat": 1, "next_seat": 0}]), false, "manual end_turn is not a skip")
	var skip_event := {
		"type": "end_turn",
		"seat": 0,
		"auto": true,
		"stunned": true,
		"name": "Kestrel",
		"coach": "Kestrel stunned (Locked A′) — turn skipped.",
	}
	eq(CombatHUD.events_include_stun_skip([skip_event]), true, "auto stunned end_turn is a skip")
	eq(CombatHUD.stun_skip_caption(skip_event), "Kestrel stunned — turn skipped", "skip banner names the stunned seat")
	eq(CombatHUD.events_include_stun_skip([{"type": "stun_skip", "seat": 1, "name": "Ironjaw"}]), true, "stun_skip type is presented")
	eq(CombatHUD.stun_skip_caption({"type": "stun_skip", "coach": "Ironjaw stunned (Locked A′) — turn skipped."}), "Ironjaw stunned (Locked A′) — turn skipped.", "coach-only skip events stay readable")
	eq(CombatHUD.events_include_stun_skip([{
		"type": "end_turn",
		"seat": 1,
		"next_seat": 0,
		"coach": "Kestrel's turn skipped — stunned (Locked A′).",
	}]), false, "handoff coach on the previous seat's end_turn is not itself the skip")
	eq(CombatHUD.events_include_stun_skip([{
		"type": "turn_start",
		"seat": 0,
		"stunned_skip": true,
		"coach": "Kestrel's turn skipped — stunned (Locked A′).",
	}]), true, "Locked A′ turn_start.stunned_skip is a skip")
	eq(CombatHUD.events_include_stun_skip([{
		"type": "status",
		"status": "stun",
		"coach": "Kestrel is stunned (Locked A′).",
	}]), false, "Crush Locked A′ status is not a skip")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn"})
	_sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3)})
	var live_skip_result: Dictionary = _sim.submit({"type": "end_turn"})
	eq(CombatHUD.events_include_stun_skip(live_skip_result.get("events", [])), true, "live Locked A′ auto end_turn is presented")
	var live_skip: Dictionary = CombatHUD.stun_skip_event(live_skip_result.get("events", []))
	eq(int(live_skip.get("seat", -1)), 0, "skip event belongs to the stunned seat")
	eq(CombatHUD.stun_skip_caption(live_skip, _sim.snapshot()), "Kestrel stunned — turn skipped", "live skip banner names Kestrel")

	var hud := CombatHUD.new()
	hud._build()
	hud.show_turn_banner("Kestrel", SpellKits.CLASS_KESTREL, "Kestrel stunned — turn skipped")
	eq(hud.banner_caption(), "Kestrel stunned — turn skipped", "skip banner caption is set")
	hud.hide_turn_banner()
	eq(hud.banner_caption(), "", "skip banner hides")
	hud.free()

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("stun_skip_event"), "board_view presents CombatSim skip events")
	truthy(view.contains("stun_skip_caption"), "board_view uses the skip caption helper")
	eq(view.contains("submit({\"type\": \"end_turn\"})"), true, "board_view still submits end_turn only on the existing path")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud_src.contains("auto end_turn"), false, "HUD does not auto-submit end_turn")
	eq(hud_src.contains("Step-shot"), false, "skip chrome does not invent Step-shot")


func _test_playtest_warning_hush() -> void:
	var tooltip_src := FileAccess.get_file_as_string("res://data/spell_tooltip.gd")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(tooltip_src.contains("var connect :="), false, "spell_tooltip does not shadow Object.connect")
	truthy(tooltip_src.contains("var on_connect :="), "spell_tooltip renamed the connect local")
	eq(hud_src.contains("var show :="), false, "hud does not shadow CanvasLayer.show")
	truthy(hud_src.contains("var stun_visible :="), "hud renamed the show local")
	truthy(view.contains("COMBAT_SIM_SCRIPT.facing_from_step"), "walk hops call facing_from_step on the script type")
	truthy(view.contains("COMBAT_SIM_SCRIPT.hop_facing"), "walk hops call hop_facing on the script type")
	eq(view.contains("CombatSim.facing_from_step"), false, "facing_from_step is not called on the autoload instance")
	eq(view.contains("CombatSim.hop_facing"), false, "hop_facing is not called on the autoload instance")


func _test_deploy_main_chrome() -> void:
	# Live main chrome binds CombatSim deploy API. No fog / deploy timer / proto manager.
	_sim.reset_match({"seed": 1})
	var zones: Dictionary = _sim.snapshot().get("deploy_zones", {})
	var p1: Vector2i = _zone_cell(0, 0)
	var p2: Vector2i = _zone_cell(1, 0)
	var unclaimed: Vector2i = _unclaimed_cell()
	eq(CombatHUD.is_deployment_phase(_sim.snapshot()), true, "live snap is DEPLOYMENT")
	eq(CombatHUD.can_ready_from_snap(_sim.snapshot(), 0), false, "HUD gate matches can_ready before place")
	eq(CombatHUD.deploy_seat_for_cell(p1, -1, zones), 0, "seat 0 blob click is seat 0")
	eq(CombatHUD.deploy_seat_for_cell(p2, -1, zones), 1, "seat 1 blob click is seat 1")
	eq(CombatHUD.deploy_seat_for_cell(unclaimed, -1, zones), 0, "unclaimed with no selection routes to seat 0")
	eq(CombatHUD.deploy_seat_for_cell(p2, 0, zones), 0, "selected P1 on P2 blob stays seat 0 for wrong_zone")
	eq(CombatHUD.deploy_seat_for_cell(p1, 1, zones), 1, "selected P2 on P1 blob stays seat 1 for wrong_zone")

	var outside_copy := CombatHUD.deploy_reject_copy("outside_zone", unclaimed, "outside")
	truthy(outside_copy.contains("outside this side"), "HUD coach names an unclaimed cell")
	var wrong_zone_copy := CombatHUD.deploy_reject_copy("outside_zone", p2, "wrong_zone")
	truthy(wrong_zone_copy.contains("other side"), "HUD coach names the other blob")
	eq(CombatHUD.deploy_reject_copy("outside_zone", unclaimed, "outside").contains("deployment zone"), true, "outside copy names the deploy zone")
	eq(CombatHUD.deploy_reject_copy("outside_zone", p2, "wrong_half").contains("other side"), true, "legacy wrong_half kind still names the other zone")

	var hud := CombatHUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud.deploy_chrome_visible(), true, "Ready buttons show during DEPLOYMENT")
	eq(hud.ready_p1_enabled(), false, "Ready P1 starts disabled")
	eq(hud.ready_p2_enabled(), false, "Ready P2 starts disabled")
	eq(hud.walk_suppressed(), true, "Walk is off during deploy")
	eq(hud.face_suppressed(), true, "Face is off during deploy")
	eq(hud.end_turn_enabled(), false, "End Turn is off during deploy")
	eq(hud.clock_visible(), false, "TIME clock is hidden during deploy")
	eq(hud._walk_button.visible, false, "Walk is hidden during deploy")
	eq(hud._end_turn_button.visible, false, "End Turn is hidden during deploy")
	eq(hud._face_bar.visible, false, "Face bar is hidden during deploy")
	eq(hud._spell_buttons.is_empty(), true, "kit casts are hidden during deploy")
	truthy(hud._turn_label.text.contains("DEPLOYMENT"), "turn label names DEPLOYMENT")
	eq(hud._turn_label.text.contains("Turn 1"), false, "Turn 1 is not shown before both Ready")
	truthy(hud._selected_label.text.contains("deploy zone"), "selected line names the deploy zone")
	truthy(str(hud._kestrel_body.text).contains("open"), "Kestrel card starts open")
	truthy(str(hud._ironjaw_body.text).contains("open"), "Ironjaw card starts open")

	_sim.place_unit(0, p1)
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud.ready_p1_enabled(), true, "Ready P1 enables after Kestrel is placed")
	eq(hud.ready_p2_enabled(), false, "Ready P2 stays gated")
	eq(CombatHUD.can_ready_from_snap(_sim.snapshot(), 0), true, "HUD can_ready follows place")
	truthy(str(hud._kestrel_body.text).contains("placed"), "Kestrel card shows placed")
	eq(hud.walk_suppressed(), true, "Walk stays off after a place")

	_sim.place_unit(1, p2)
	hud.render(_sim.snapshot(), _sim.legal_intents(1))
	eq(hud.ready_p2_enabled(), true, "Ready P2 enables after Ironjaw is placed")
	eq(hud.end_turn_enabled(), false, "End Turn stays off until both Ready")

	_sim.ready_seat(0)
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud.ready_p1_enabled(), false, "Ready P1 disables after ready")
	eq(hud._ready_p1_button.text, "P1 ready", "Ready P1 caption flips after ready")
	eq(hud.deploy_chrome_visible(), true, "deploy chrome stays until both Ready")
	truthy(str(hud._kestrel_body.text).contains("READY"), "Kestrel card shows READY")

	_sim.ready_seat(1)
	var combat_snap: Dictionary = _sim.snapshot()
	eq(combat_snap["phase"], "TURN_1", "both Ready leaves DEPLOYMENT")
	hud.render(combat_snap, _sim.legal_intents(0))
	eq(hud.deploy_chrome_visible(), false, "Ready buttons hide after deploy")
	eq(hud.walk_suppressed(), false, "Walk returns in Turn 1")
	eq(hud.face_suppressed(), false, "Face returns in Turn 1")
	eq(hud.end_turn_enabled(), true, "End Turn returns in Turn 1")
	eq(hud.clock_visible(), true, "TIME clock returns in combat")
	eq(hud._walk_button.visible, true, "Walk is shown in combat")
	eq(hud._end_turn_button.visible, true, "End Turn is shown in combat")
	eq(hud._face_bar.visible, true, "Face bar returns in Turn 1")
	truthy(hud._turn_label.text.contains("Turn 1"), "turn label shows Turn 1")
	eq(hud._spell_buttons.has("mark_shot"), true, "Kestrel kit returns after deploy")
	eq(_unit(0)["pos"], p1, "combat spawn is the confirmed P1 cell")
	eq(_unit(1)["pos"], p2, "combat spawn is the confirmed P2 cell")
	hud.free()

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("place_unit"), "board_view binds place_unit")
	truthy(view.contains("ready_seat"), "board_view binds ready_seat")
	truthy(view.contains("legal_deploy_cells"), "board_view paints from legal_deploy_cells")
	truthy(view.contains("deploy_zone_cells"), "board_view paints from deploy_zone_cells")
	truthy(view.contains("can_ready") or view.contains("ready_requested"), "board_view wires Ready")
	eq(view.contains("DeploymentManager"), false, "main path does not use DeploymentManager")
	eq(view.contains("proto/deployment"), false, "main path does not import proto/deployment")
	eq(view.contains("fog_of_war"), false, "main path does not invent hidden-enemy chrome")
	eq(view.contains("deploy_timer"), false, "main path does not invent a deploy timer")

	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("Ready P1"), "HUD has Ready P1")
	truthy(hud_src.contains("Ready P2"), "HUD has Ready P2")
	truthy(hud_src.contains("deploy_reject_copy"), "HUD still owns deploy reject copy")
	truthy(hud_src.contains("other side's deploy zone"), "HUD names the other blob")
	truthy(hud_src.contains("outside this side's deployment zone"), "HUD names an unclaimed cell")
	eq(hud_src.contains("1-deep border ring only"), false, "HUD no longer claims the 1-deep ring")
	eq(hud_src.contains("Detonate"), false, "deploy HUD still does not hardcode Detonate")

	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	truthy(tile_src.contains("zone_p1"), "board tiles can highlight P1 deploy half")
	truthy(tile_src.contains("zone_p2"), "board tiles can highlight P2 deploy half")

	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("Ready P1"), "README documents Ready P1 on main")
	truthy(readme.contains("main.tscn"), "README still points play at main.tscn")
	eq(readme.contains("Godot Engineer"), false, "README no longer leaves main chrome for later")


func _test_aegis_break_burst() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"kestrel_marks": 3,
		"bastion_aegis": 4,
		"rolls": [1],
	})
	var second: Dictionary = _sim._make_unit(1, "kestrel", "Second", "air", Vector2i(1, 3), "N", true)
	var outside: Dictionary = _sim._make_unit(1, "kestrel", "Outside", "air", Vector2i(4, 2), "W", true)
	_sim._units.append(second)
	_sim._units.append(outside)
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(hit.get("ok", false), true, "Aegis Break burst resolves")
	eq(int(_unit(0)["aegis"]), 0, "HIT clears all Aegis")
	eq(int(_unit(0)["ap"]), 2, "Aegis Break spends 4 AP")
	eq(int(_unit(1)["hp"]), 54, "aimed body takes 26")
	eq(_unit(1)["pos"], Vector2i(4, 1), "aimed body is pushed 1")
	eq(int(_unit(1)["marks"]), 3, "HIT does not clear Marks")
	eq(int(second["hp"]), 54, "body inside range 1–2 takes 26")
	eq(second["pos"], Vector2i(1, 4), "body inside range 1–2 is pushed 1")
	eq(int(outside["hp"]), 80, "body outside range 1–2 is not hit")
	eq(outside["pos"], Vector2i(4, 2), "body outside range 1–2 is not pushed")
	var event := _first_event_where(hit["events"], "hit")
	eq(int(event.get("bodies", 0)), 2, "hit event counts both bodies")
	eq(int(event.get("aegis_spent", 0)), 4, "HIT reports the cleared Aegis")
	eq(bool(event.get("stacks_cleared", false)), true, "HIT sets stacks_cleared")
	var rows: Array = event.get("targets", [])
	eq(rows.size(), 2, "hit event lists both bodies")
	eq(int(rows[0].get("damage", -1)), 26, "first body row is 26")
	eq(bool(rows[0].get("pushed", false)), true, "first body row records the push")
	eq(int(rows[1].get("damage", -1)), 26, "second body row is 26")
	eq(bool(rows[1].get("pushed", false)), true, "second body row records the push")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"bastion_aegis": 4,
		"rolls": [100],
	})
	var missed_second: Dictionary = _sim._make_unit(1, "kestrel", "Second", "air", Vector2i(1, 3), "N", true)
	_sim._units.append(missed_second)
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(missed.get("ok", false), true, "Aegis Break miss resolves")
	eq(int(_unit(0)["aegis"]), 4, "MISS spends 0 Aegis")
	eq(int(_unit(0)["ap"]), 2, "MISS still spends 4 AP")
	eq(int(_unit(1)["hp"]), 80, "MISS does not damage the aimed body")
	eq(_unit(1)["pos"], Vector2i(3, 1), "MISS does not push the aimed body")
	eq(int(missed_second["hp"]), 80, "MISS does not damage the other body")
	eq(missed_second["pos"], Vector2i(1, 3), "MISS does not push the other body")
	var miss := _first_event_where(missed["events"], "miss")
	eq(int(miss.get("aegis_spent", -1)), 0, "MISS event spends 0 Aegis")
	eq(bool(miss.get("stacks_cleared", true)), false, "MISS does not clear Aegis")
	eq(int(miss.get("aegis", -1)), 4, "MISS leaves the Aegis stack")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"bastion_aegis": 2,
	})
	var gated: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(str(gated.get("reason", "")), "insufficient_aegis", "Aegis Break requires 3 Aegis")
	eq(int(_unit(0)["ap"]), 6, "failed gate does not spend AP")
	eq(int(_unit(0)["aegis"]), 2, "failed gate does not spend Aegis")


func _test_snap_wall_bastion_turns() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"bastion_aegis": 2,
	})
	var casted: Dictionary = _sim.submit({"type": "cast", "spell": "snap_wall", "to": Vector2i(2, 1), "seat": 0})
	eq(casted.get("ok", false), true, "Snap Wall places")
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 2, "Snap Wall starts at 2 Bastion turn-starts")
	var enemy_turn: Dictionary = _sim.submit({"type": "end_turn", "seat": 0})
	eq(_sim.snapshot()["active_seat"], 1, "enemy turn starts after the cast")
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 2, "enemy turn-start does not tick Snap Wall")
	eq(_first_event_where(enemy_turn["events"], "expire", "wall").is_empty(), true, "wall does not expire on the enemy turn")
	var onto_wall: Dictionary = _sim.submit({"type": "move", "to": Vector2i(2, 1), "seat": 1})
	eq(onto_wall.get("illegal", false), true, "Snap Wall still blocks the enemy after their turn starts")
	_sim.submit({"type": "end_turn", "seat": 1})
	eq(_sim.snapshot()["active_seat"], 0, "first Bastion turn-start is the owner's next turn")
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 1, "first Bastion turn-start ticks 2 to 1")
	eq(_sim.snapshot()["blocked_tiles"].size(), 1, "wall is still up after one Bastion turn-start")
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 1, "the next enemy turn does not tick Snap Wall")
	var expired: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(_sim.snapshot()["blocked_tiles"].size(), 0, "wall expires on the second Bastion turn-start")
	eq(_first_event_where(expired["events"], "expire", "wall").get("pos"), Vector2i(2, 1), "expiry names the wall cell")
	eq(int(_first_event_where(expired["events"], "expire", "wall").get("owner_seat", -2)), 0, "expiry names the owning Bastion")
	var walked: Dictionary = _sim.submit({"type": "move", "to": Vector2i(2, 1), "seat": 0})
	eq(walked.get("ok", false), true, "the cell is walkable after the wall expires")


func _walkable_zone_count(seat: int) -> int:
	var n := 0
	for cell: Vector2i in _sim.deploy_zone_cells(seat):
		if bool(_sim.tile_at(cell).get("walkable", true)):
			n += 1
	return n


func _first_walkable_zone_cell(seat: int) -> Vector2i:
	return _next_walkable_zone_cell(seat, Vector2i(-99, -99))


func _next_walkable_zone_cell(seat: int, skip: Vector2i) -> Vector2i:
	for cell: Vector2i in _sim.deploy_zone_cells(seat):
		if cell == skip:
			continue
		if bool(_sim.tile_at(cell).get("walkable", true)):
			return cell
	return Vector2i(-1, -1)


func _zone_cell(seat: int, index: int = 0) -> Vector2i:
	# Prefer walkable blob cells so place/ready fixtures skip stamped lava.
	var cells: Array[Vector2i] = _sim.legal_deploy_cells(seat)
	if cells.is_empty():
		cells = _sim.deploy_zone_cells(seat)
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[clampi(index, 0, cells.size() - 1)]


func _unclaimed_cell() -> Vector2i:
	var z0: Array[Vector2i] = _sim.deploy_zone_cells(0)
	var z1: Array[Vector2i] = _sim.deploy_zone_cells(1)
	for y in range(8):
		for x in range(8):
			var cell := Vector2i(x, y)
			if not z0.has(cell) and not z1.has(cell):
				return cell
	return Vector2i(-1, -1)


func _interior_zone_cell(seat: int) -> Vector2i:
	var flow_script = load("res://backend/match_flow.gd")
	for cell: Vector2i in _sim.legal_deploy_cells(seat):
		if not flow_script.is_border_cell(cell):
			return cell
	return Vector2i(-1, -1)


func _seed_with_interior_zone() -> int:
	var flow_script = load("res://backend/match_flow.gd")
	for seed in range(1, 80):
		var sampled: Dictionary = flow_script.sample_zone_pair(seed)
		if flow_script.has_interior_cell(sampled["zones"][0]) or flow_script.has_interior_cell(sampled["zones"][1]):
			return seed
	return 1


func _rect_blob(origin: Vector2i, width: int, height: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			out.append(Vector2i(origin.x + x, origin.y + y))
	return out


func _closest_zone_pair() -> Array:
	var best_d := 999
	var pair: Array = [Vector2i.ZERO, Vector2i.ZERO]
	var a_cells: Array[Vector2i] = _sim.legal_deploy_cells(0)
	var b_cells: Array[Vector2i] = _sim.legal_deploy_cells(1)
	if a_cells.is_empty():
		a_cells = _sim.deploy_zone_cells(0)
	if b_cells.is_empty():
		b_cells = _sim.deploy_zone_cells(1)
	for a: Vector2i in a_cells:
		for b: Vector2i in b_cells:
			var d: int = _sim.chebyshev(a, b)
			if d < best_d:
				best_d = d
				pair = [a, b]
	return pair


func _walk_seat_toward(seat: int, target: Vector2i, want: int) -> void:
	var guard := 0
	while guard < 16:
		if int(_sim.snapshot().get("active_seat", -1)) != seat:
			_sim.submit({"type": "end_turn"})
			guard += 1
			continue
		var pos: Vector2i = _unit(seat)["pos"]
		if _sim.chebyshev(pos, target) <= want:
			return
		if _has_legal_cast(seat, "strike"):
			return
		var best: Variant = null
		var best_d := 999
		for intent in _sim.legal_intents(seat):
			if str(intent.get("type", "")) != "move":
				continue
			var dest: Vector2i = intent["to"]
			var d: int = _sim.chebyshev(dest, target)
			if d < best_d:
				best_d = d
				best = dest
		if best == null:
			_sim.submit({"type": "end_turn"})
		else:
			_sim.submit({"type": "move", "to": best})
		guard += 1


func _has_legal_cast(seat: int, spell_id: String) -> bool:
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == spell_id:
			return true
	return false


func _has_legal_cast_to(seat: int, spell_id: String, dest: Vector2i) -> bool:
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == spell_id and intent.get("to") == dest:
			return true
	return false


func _has_legal_advance_to(seat: int, dest: Vector2i) -> bool:
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == "advance" and intent.get("to") == dest:
			return true
	return false


func _noise_elev(seed: int, cell: Vector2i) -> int:
	return int(load("res://backend/match_flow.gd").generate_noise_elevations(seed)[cell])


func _face_pad(hud: Node) -> GridContainer:
	for child in hud._face_bar.get_children():
		if child is GridContainer:
			return child
	return null


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


func _has_legal_move_to(seat: int, dest: Vector2i) -> bool:
	return bool(_legal_move_dests(seat).get(dest, false))


func _first_event_where(events: Array, kind: String, status: String = "") -> Dictionary:
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != kind:
			continue
		if status != "" and str(event.get("status", "")) != status:
			continue
		return event
	return {}


func _event_type_count(events: Array, kind: String) -> int:
	var n := 0
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == kind:
			n += 1
	return n


func _unit(seat: int) -> Dictionary:
	for unit in _sim.snapshot()["units"]:
		if int(unit["seat"]) == seat:
			return unit
	return {}


func _live_unit(seat: int) -> Dictionary:
	for unit in _sim._units:
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


func _test_shade_markers_survive_rebuild() -> void:
	var live := load("res://tests/shade_marker_live.gd")
	await live.run(self)
