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
	_test_default_zones_and_fighters()
	_test_zone_reject()
	_test_occupied_reject()
	_test_walkable_and_bounds()
	_test_confirm_gate()
	_test_sequential_hotseat()
	_test_both_confirm_starts_turn_1()
	_test_combat_disabled_until_both_confirm()
	_test_reposition_then_lock()
	_test_elevation_walkable_reuse()
	_test_scene_instantiates()
	_test_phase_a_untouched()


func _test_default_zones_and_fighters() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "starts in DEPLOYMENT")
	eq(mgr.active_player, 0, "P1 deploys first")
	eq(mgr.selected_unit_id, "kestrel", "Kestrel is selected first")
	var p1: DeploymentZone = mgr.zone_for(0)
	var p2: DeploymentZone = mgr.zone_for(1)
	eq(p1.cells.size(), 6, "P1 zone is a 2×3 (6 cells)")
	eq(p2.cells.size(), 6, "P2 zone is a 2×3 (6 cells)")
	eq(p1.contains(Vector2i(0, 2)), true, "P1 owns west box origin")
	eq(p1.contains(Vector2i(1, 4)), true, "P1 owns west box far cell")
	eq(p2.contains(Vector2i(6, 2)), true, "P2 owns east box origin")
	eq(p2.contains(Vector2i(7, 4)), true, "P2 owns east box far cell")
	eq(p1.contains(Vector2i(6, 2)), false, "zones do not overlap")
	eq(mgr.unit_by_id("kestrel")["name"], "Kestrel", "P1 stand-in is Kestrel")
	eq(mgr.unit_by_id("ironjaw")["name"], "Ironjaw", "P2 stand-in is Ironjaw")
	eq(mgr.can_confirm(), false, "Confirm starts disabled")


func _test_zone_reject() -> void:
	var mgr := DeploymentManager.new()
	var mid: Dictionary = mgr.can_deploy_unit("kestrel", Vector2i(3, 3))
	eq(mid["ok"], false, "center cell is rejected")
	eq(mid["reason"], "outside_zone", "center reason is outside_zone")
	var enemy_box: Dictionary = mgr.can_deploy_unit("kestrel", Vector2i(6, 3))
	eq(enemy_box["ok"], false, "P1 cannot place in P2's box")
	eq(enemy_box["reason"], "outside_zone", "enemy box reason is outside_zone")
	eq(mgr.place_unit("kestrel", Vector2i(4, 4))["reason"], "outside_zone", "place also zone-rejects")
	eq(mgr.unit_by_id("kestrel")["placed"], false, "failed place leaves Kestrel unplaced")


func _test_occupied_reject() -> void:
	var mgr := DeploymentManager.new()
	mgr.extra_occupied.append(Vector2i(0, 3))
	var blocked: Dictionary = mgr.can_deploy_unit("kestrel", Vector2i(0, 3))
	eq(blocked["ok"], false, "occupied zone cell is rejected")
	eq(blocked["reason"], "occupied", "occupied reason is occupied")

	mgr.extra_occupied.clear()
	eq(mgr.place_unit("kestrel", Vector2i(0, 2))["ok"], true, "first place on empty zone cell works")
	mgr.add_unit({
		"id": "kestrel_b",
		"player_id": 0,
		"name": "Kestrel B",
		"class_id": "kestrel",
		"required": false,
	})
	eq(mgr.can_deploy_unit("kestrel_b", Vector2i(0, 2))["reason"], "occupied", "second fighter cannot stack")
	eq(mgr.place_unit("kestrel", Vector2i(1, 2))["ok"], true, "same fighter may reposition")
	eq(mgr.unit_by_id("kestrel")["cell"], Vector2i(1, 2), "Kestrel moved to the new cell")
	eq(mgr.occupant_at(Vector2i(0, 2)), "", "old cell is vacated")


func _test_walkable_and_bounds() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_deploy_unit("kestrel", Vector2i(-1, 2))["reason"], "out_of_bounds", "negative x is out_of_bounds")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(8, 2))["reason"], "out_of_bounds", "x=8 is out_of_bounds")
	mgr.extra_blocked.append(Vector2i(1, 3))
	eq(mgr.can_deploy_unit("kestrel", Vector2i(1, 3))["reason"], "not_walkable", "blocked zone cell is not_walkable")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 4))["ok"], true, "other zone cell stays legal")


func _test_confirm_gate() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_confirm(), false, "Confirm disabled before place")
	eq(mgr.confirm()["reason"], "units_not_placed", "confirm without a unit is units_not_placed")
	eq(mgr.confirmed[0], false, "P1 is not confirmed after the reject")
	eq(mgr.place_unit("kestrel", Vector2i(0, 2))["ok"], true, "place enables the gate")
	eq(mgr.can_confirm(), true, "Confirm enabled after required unit is placed")
	eq(mgr.confirm()["ok"], true, "P1 confirm succeeds once placed")
	eq(mgr.confirmed[0], true, "P1 is locked after confirm")
	eq(mgr.can_confirm(0), false, "P1 cannot confirm again")
	eq(mgr.place_unit("kestrel", Vector2i(1, 2))["reason"], "side_locked", "P1 cannot reposition after confirm")


func _test_sequential_hotseat() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_deploy_unit("ironjaw", Vector2i(6, 2))["reason"], "not_your_turn", "P2 cannot place during P1 deploy")
	eq(mgr.confirm(1)["reason"], "not_your_turn", "P2 cannot confirm first")
	mgr.place_unit("kestrel", Vector2i(0, 2))
	mgr.confirm()
	eq(mgr.active_player, 1, "after P1 confirm, P2 becomes active")
	eq(mgr.selected_unit_id, "ironjaw", "Ironjaw is selected for P2")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(1, 2))["reason"], "side_locked", "P1 is done after confirm")
	eq(mgr.place_unit("ironjaw", Vector2i(7, 4))["ok"], true, "P2 can place in the east box")


func _test_both_confirm_starts_turn_1() -> void:
	var mgr := DeploymentManager.new()
	var started := {"count": 0, "phase": -1, "turn": -1}
	mgr.start_match.connect(func(snap: Dictionary):
		started["count"] = int(started["count"]) + 1
		started["phase"] = int(snap["phase"])
		started["turn"] = int(snap["turn_index"])
	)
	mgr.place_unit("kestrel", Vector2i(0, 2))
	mgr.confirm()
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "still DEPLOYMENT after only P1 confirm")
	eq(started["count"], 0, "start_match waits for both confirms")
	mgr.place_unit("ironjaw", Vector2i(6, 2))
	mgr.confirm()
	eq(mgr.phase, MatchPhase.TURN_1, "both confirm → TURN_1")
	eq(mgr.phase_name(), "TURN_1", "phase_name is TURN_1")
	eq(started["count"], 1, "start_match emits once")
	eq(started["phase"], MatchPhase.TURN_1, "start_match snapshot is TURN_1")
	eq(started["turn"], 1, "Turn index is 1")
	eq(mgr.snapshot()["positions_locked"], true, "positions lock after both confirm")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(1, 3))["reason"], "wrong_phase", "deploy is closed in TURN_1")


func _test_combat_disabled_until_both_confirm() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.combat_actions_enabled(), false, "combat off during deploy")
	eq(mgr.snapshot()["walk_enabled"], false, "walk chrome disabled during deploy")
	eq(mgr.snapshot()["end_turn_enabled"], false, "end-turn disabled during deploy")
	mgr.place_unit("kestrel", Vector2i(1, 4))
	mgr.confirm()
	eq(mgr.combat_actions_enabled(), false, "combat still off after only P1 confirm")
	mgr.place_unit("ironjaw", Vector2i(7, 2))
	mgr.confirm()
	eq(mgr.combat_actions_enabled(), true, "combat chrome enabled after both confirm")
	eq(mgr.snapshot()["walk_enabled"], true, "walk chrome enabled on Turn 1")
	eq(mgr.snapshot()["end_turn_enabled"], true, "end-turn chrome enabled on Turn 1")


func _test_reposition_then_lock() -> void:
	var mgr := DeploymentManager.new()
	var first: Dictionary = mgr.place_unit("kestrel", Vector2i(0, 2))
	eq(first["repositioned"], false, "first place is not a reposition")
	var moved: Dictionary = mgr.place_unit("kestrel", Vector2i(1, 4))
	eq(moved["ok"], true, "reposition before confirm is legal")
	eq(moved["repositioned"], true, "second place is a reposition")
	eq(mgr.unit_by_id("kestrel")["cell"], Vector2i(1, 4), "unit sits on the latest cell")
	mgr.confirm()
	eq(mgr.unit_by_id("kestrel")["locked"], true, "P1 fighter locks on confirm")
	eq(mgr.legal_deploy_cells("kestrel").is_empty(), true, "locked side has no legal cells")


func _test_elevation_walkable_reuse() -> void:
	var terrain := ProtoMoveSim.new(8, 8)
	terrain.set_tile(Vector2i(0, 2), TerrainDef.Id.LAVA, 0.0)
	var mgr := DeploymentManager.new()
	mgr.is_walkable_fn = Callable(terrain, "is_walkable")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 2))["reason"], "not_walkable", "reuses ProtoMoveSim lava as not_walkable")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(1, 2))["ok"], true, "ground zone cell stays deployable")
	# Deploy must not require elevation climb costs.
	terrain.set_tile(Vector2i(1, 2), TerrainDef.Id.GROUND, 2.0)
	eq(mgr.can_deploy_unit("kestrel", Vector2i(1, 2))["ok"], true, "high elevation is still deployable (no climb cost)")


func _test_scene_instantiates() -> void:
	var packed: PackedScene = load("res://scenes/proto_deployment_board.tscn")
	truthy(packed is PackedScene, "proto scene resource loads")
	var scene: Node = packed.instantiate()
	truthy(scene != null, "proto scene instantiates")
	eq(str(scene.get_script().resource_path), "res://proto/deployment/proto_deployment_board.gd", "scene script is proto_deployment_board")
	var mgr: DeploymentManager = scene._mgr
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "scene manager boots in DEPLOYMENT")
	eq(mgr.can_confirm(), false, "scene Confirm starts disabled")
	eq(mgr.place_unit("kestrel", Vector2i(0, 3))["ok"], true, "scene manager can place P1")
	scene.free()


func _test_phase_a_untouched() -> void:
	var combat := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(combat.contains("proto/deployment"), false, "CombatSim does not import proto/deployment")
	eq(combat.contains("DeploymentManager"), false, "CombatSim does not reference DeploymentManager")
	eq(combat.contains("MatchPhase"), false, "CombatSim does not reference proto MatchPhase")
	truthy(combat.contains("expand_ortho_path"), "Phase A still owns flat H-first walk expansion")
	truthy(combat.contains("reset_match"), "Phase A reset_match is still the live match start")

	var board := FileAccess.get_file_as_string("res://board_view.gd")
	eq(board.contains("DeploymentManager"), false, "Phase A board_view does not use DeploymentManager")
	eq(board.contains("proto/deployment"), false, "Phase A board_view does not import proto/deployment")

	var main_scene := FileAccess.get_file_as_string("res://main.tscn")
	eq(main_scene.contains("proto_deployment"), false, "main.tscn still points at the Phase A duel")

	var scene := FileAccess.get_file_as_string("res://scenes/proto_deployment_board.tscn")
	truthy(scene.contains("proto_deployment_board.gd"), "prototype scene exists")

	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("Phase B+ deployment prototype"), "README has the Phase B+ deployment section")
	truthy(readme.contains("Proposed"), "README stamps Proposed")
	truthy(readme.contains("opposite 2×3") or readme.contains("opposite 2x3"), "README lists opposite 2×3 boxes")


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
