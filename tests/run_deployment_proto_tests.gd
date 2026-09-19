extends SceneTree

## Headless Phase B+ deployment prototype checks.
## Proposed (not Locked). Does not load or mutate CombatSim match state.
## Run: godot --headless --path . -s res://tests/run_deployment_proto_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Deployment proto tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_match_phase_includes_deployment()
	_test_default_opposite_2x3_zones()
	_test_reject_out_of_zone()
	_test_reject_out_of_bounds()
	_test_reject_occupied()
	_test_confirm_gated()
	_test_place_reposition_then_lock()
	_test_both_confirm_changes_phase()
	_test_combat_disabled_until_both_confirm()
	_test_start_match_callback()
	_test_walkable_empty_in_zone_only()
	_test_phase_a_untouched()


func _test_match_phase_includes_deployment() -> void:
	eq(MatchPhase.Id.DEPLOYMENT, 0, "DEPLOYMENT is the first MatchPhase value")
	eq(MatchPhase.Id.COMBAT, 1, "COMBAT exists for the Turn 1 handoff")
	var mgr := DeploymentManager.new()
	eq(mgr.phase, MatchPhase.Id.DEPLOYMENT, "hot-seat proto starts in DEPLOYMENT")
	eq(mgr.phase_name(), "DEPLOYMENT", "phase_name is DEPLOYMENT")


func _test_default_opposite_2x3_zones() -> void:
	var boxes: Array[DeploymentZone] = DeploymentZone.opposite_2x3(8)
	eq(boxes.size(), 2, "starter layout is two zones")
	eq(boxes[0].player_id, 0, "west box is player 0")
	eq(boxes[1].player_id, 1, "east box is player 1")
	eq(boxes[0].cells.size(), 6, "2×3 is six cells")
	eq(boxes[1].cells.size(), 6, "opposite 2×3 is six cells")
	eq(boxes[0].contains(Vector2i(0, 2)), true, "P0 includes (0,2)")
	eq(boxes[0].contains(Vector2i(1, 4)), true, "P0 includes (1,4)")
	eq(boxes[1].contains(Vector2i(6, 2)), true, "P1 includes (6,2)")
	eq(boxes[1].contains(Vector2i(7, 4)), true, "P1 includes (7,4)")
	eq(boxes[0].contains(Vector2i(6, 2)), false, "zones do not overlap")

	var mgr := DeploymentManager.new()
	eq(mgr.zone_cells(0).size(), 6, "manager default P0 zone is 2×3")
	eq(mgr.zone_cells(1).size(), 6, "manager default P1 zone is 2×3")
	eq(mgr.units.has("kestrel"), true, "seat 0 has one fighter")
	eq(mgr.units.has("ironjaw"), true, "seat 1 has one fighter")
	eq(int(mgr.units["kestrel"]["player_id"]), 0, "Kestrel is player 0")
	eq(int(mgr.units["ironjaw"]["player_id"]), 1, "Ironjaw is player 1")


func _test_reject_out_of_zone() -> void:
	var mgr := DeploymentManager.new()
	var gate: Dictionary = mgr.can_deploy_unit("kestrel", Vector2i(3, 3))
	eq(gate["ok"], false, "center tile is not in the west 2×3")
	eq(gate["reason"], "not_in_zone", "out-of-zone reason is not_in_zone")
	var placed: Dictionary = mgr.place("kestrel", Vector2i(4, 4))
	eq(placed["ok"], false, "place rejects out-of-zone")
	eq(placed["reason"], "not_in_zone", "place reason is not_in_zone")
	eq(bool(mgr.units["kestrel"]["placed"]), false, "rejected place does not occupy")


func _test_reject_out_of_bounds() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_deploy_unit("kestrel", Vector2i(-1, 2))["reason"], "out_of_bounds", "negative x is OOB")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(8, 2))["reason"], "out_of_bounds", "x=8 is OOB")
	eq(mgr.place("kestrel", Vector2i(0, 8))["reason"], "out_of_bounds", "place rejects OOB")


func _test_reject_occupied() -> void:
	var mgr := DeploymentManager.new()
	# Overlap the two 2×3 boxes so the second fighter can target the first cell.
	mgr.set_zone(DeploymentZone.box(0, Vector2i(0, 2), 2, 3))
	mgr.set_zone(DeploymentZone.box(1, Vector2i(0, 2), 2, 3))
	eq(mgr.place("kestrel", Vector2i(0, 3))["ok"], true, "first place on a shared cell works")
	eq(mgr.confirm(0)["ok"], true, "seat 0 can confirm after placing")
	var gate: Dictionary = mgr.can_deploy_unit("ironjaw", Vector2i(0, 3))
	eq(gate["ok"], false, "second fighter cannot land on the occupied cell")
	eq(gate["reason"], "occupied", "occupied reason is occupied")
	eq(mgr.place("ironjaw", Vector2i(0, 3))["reason"], "occupied", "place rejects occupied")


func _test_confirm_gated() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_confirm(0), false, "Confirm is disabled before the fighter is placed")
	var gated: Dictionary = mgr.confirm(0)
	eq(gated["ok"], false, "confirm without a place is rejected")
	eq(gated["reason"], "confirm_gated", "reason is confirm_gated")
	eq(mgr.phase, MatchPhase.Id.DEPLOYMENT, "gated confirm stays in DEPLOYMENT")
	eq(bool(mgr.confirmed[0]), false, "seat 0 is not locked")
	eq(mgr.place("kestrel", Vector2i(0, 2))["ok"], true, "place the required unit")
	eq(mgr.can_confirm(0), true, "Confirm enables once the required unit is placed")


func _test_place_reposition_then_lock() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.select_unit("kestrel")["ok"], true, "select the active fighter")
	eq(mgr.select_unit("ironjaw")["reason"], "not_your_turn", "sequential: P1 cannot select first")
	eq(mgr.place("kestrel", Vector2i(1, 3))["ok"], true, "initial place")
	eq(mgr.units["kestrel"]["cell"], Vector2i(1, 3), "stored cell is (1,3)")
	eq(mgr.place("kestrel", Vector2i(0, 2))["reason"], "already_placed", "place again is rejected")
	eq(mgr.reposition("kestrel", Vector2i(0, 4))["ok"], true, "reposition inside the zone")
	eq(mgr.units["kestrel"]["cell"], Vector2i(0, 4), "cell moved to (0,4)")
	eq(mgr.reposition("kestrel", Vector2i(3, 3))["reason"], "not_in_zone", "reposition out of zone is rejected")
	var locked: Dictionary = mgr.confirm(0)
	eq(locked["ok"], true, "confirm locks seat 0")
	eq(bool(mgr.confirmed[0]), true, "seat 0 confirmed flag")
	eq(mgr.active_player_id, 1, "hot-seat hands to seat 1")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 2))["reason"], "side_locked", "confirmed side cannot redeploy")
	eq(mgr.reposition("kestrel", Vector2i(0, 2))["reason"], "side_locked", "reposition after confirm is locked")


func _test_both_confirm_changes_phase() -> void:
	var mgr := _deploy_both()
	eq(mgr.both_ready(), true, "both_ready after two confirms")
	eq(mgr.phase, MatchPhase.Id.COMBAT, "phase changes to COMBAT")
	eq(mgr.phase_name(), "COMBAT", "phase_name is COMBAT")
	eq(mgr.turn_index, 1, "handoff is Turn 1")


func _test_combat_disabled_until_both_confirm() -> void:
	var mgr := DeploymentManager.new()
	var early: Dictionary = mgr.start_combat()
	eq(early["ok"], false, "start_combat before any confirm is rejected")
	eq(early["reason"], "combat_disabled", "reason is combat_disabled")
	eq(mgr.phase, MatchPhase.Id.DEPLOYMENT, "phase stays DEPLOYMENT")
	eq(mgr.place("kestrel", Vector2i(0, 2))["ok"], true, "P0 places")
	eq(mgr.confirm(0)["ok"], true, "P0 confirms")
	var half: Dictionary = mgr.start_combat()
	eq(half["ok"], false, "one confirm is not enough")
	eq(half["reason"], "combat_disabled", "still combat_disabled")
	eq(mgr.phase, MatchPhase.Id.DEPLOYMENT, "still DEPLOYMENT after one confirm")


func _test_start_match_callback() -> void:
	var mgr := DeploymentManager.new()
	var seen: Array = []
	mgr.start_match_callback = func(payload: Dictionary) -> void:
		seen.append(payload)
	_deploy_both(mgr)
	eq(seen.size(), 1, "start_match callback fires once")
	eq(int(seen[0]["turn"]), 1, "callback payload is Turn 1")
	eq(int(seen[0]["phase"]), MatchPhase.Id.COMBAT, "callback phase is COMBAT")
	eq(seen[0]["placements"].size(), 2, "callback lists both fighters")
	eq(mgr.start_combat()["reason"], "already_in_combat", "second start_combat is rejected")


func _test_walkable_empty_in_zone_only() -> void:
	var mgr := DeploymentManager.new()
	mgr.set_walkable(Vector2i(1, 2), false)
	eq(mgr.can_deploy_unit("kestrel", Vector2i(1, 2))["reason"], "not_walkable", "unwalkable in-zone cell is rejected")
	eq(mgr.place("kestrel", Vector2i(0, 3))["ok"], true, "walkable empty in-zone still places")


func _test_phase_a_untouched() -> void:
	var combat := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(combat.contains("proto/deployment"), false, "CombatSim does not import proto/deployment")
	eq(combat.contains("DeploymentManager"), false, "CombatSim does not reference DeploymentManager")
	eq(combat.contains("MatchPhase"), false, "CombatSim does not reference MatchPhase")
	eq(combat.contains("DeploymentZone"), false, "CombatSim does not reference DeploymentZone")
	truthy(combat.contains("reset_match"), "Phase A still owns reset_match seats")

	var board := FileAccess.get_file_as_string("res://board_view.gd")
	eq(board.contains("DeploymentManager"), false, "Phase A board_view does not use DeploymentManager")
	eq(board.contains("proto/deployment"), false, "Phase A board_view does not import proto/deployment")

	var main_scene := FileAccess.get_file_as_string("res://main.tscn")
	eq(main_scene.contains("proto_deployment"), false, "main.tscn still points at the Phase A duel")
	eq(main_scene.contains("board_view.gd"), true, "main.tscn still uses Phase A board_view")

	var scene := FileAccess.get_file_as_string("res://scenes/proto_deployment_board.tscn")
	truthy(scene.contains("proto_deployment_board.gd"), "prototype scene exists")

	var proto_readme := FileAccess.get_file_as_string("res://proto/deployment/README.md")
	truthy(proto_readme.contains("Proposed"), "proto README stamps Proposed")
	truthy(proto_readme.contains("main.tscn"), "proto README says how to leave Phase A alone")
	truthy(proto_readme.contains("proto_deployment_board.tscn"), "proto README says how to open")

	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("Phase B+ deployment prototype"), "root README has the deployment section")
	truthy(readme.contains("Proposed"), "root README stamps Proposed")
	truthy(readme.contains("run_deployment_proto_tests.gd"), "root README lists the headless test")

	var mgr_src := FileAccess.get_file_as_string("res://proto/deployment/deployment_manager.gd")
	eq(mgr_src.contains("CombatSim"), false, "DeploymentManager does not name CombatSim")
	eq(mgr_src.contains("ElevationCost"), false, "no elevation placement gates")
	eq(mgr_src.contains("Multiplayer"), false, "no networking invented")


func _deploy_both(mgr: DeploymentManager = null) -> DeploymentManager:
	if mgr == null:
		mgr = DeploymentManager.new()
	eq(mgr.place("kestrel", Vector2i(0, 2))["ok"], true, "P0 places for both-confirm")
	eq(mgr.confirm(0)["ok"], true, "P0 confirms for both-confirm")
	eq(mgr.place("ironjaw", Vector2i(7, 4))["ok"], true, "P1 places for both-confirm")
	var done: Dictionary = mgr.confirm(1)
	eq(done["ok"], true, "P1 confirm succeeds")
	eq(int(done.get("phase", -1)), MatchPhase.Id.COMBAT, "last confirm starts combat")
	return mgr


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
