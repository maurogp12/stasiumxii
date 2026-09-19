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
	_test_border_ring_only()
	_test_half_split()
	_test_zone_reject()
	_test_occupied_reject()
	_test_walkable_and_bounds()
	_test_confirm_gate()
	_test_simultaneous_deploy()
	_test_both_ready_starts_turn_1()
	_test_combat_disabled_until_both_ready()
	_test_reposition_then_lock()
	_test_elevation_walkable_reuse()
	_test_scene_instantiates()
	_test_phase_a_untouched()


func _test_default_zones_and_fighters() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "starts in DEPLOYMENT")
	eq(mgr.selected_unit_id, "kestrel", "Kestrel is selected first")
	eq(mgr.snapshot()["simultaneous"], true, "snapshot marks simultaneous deploy")
	eq(mgr.snapshot()["legal_cells"], "border_ring_1_deep", "snapshot stamps the 1-deep ring")
	eq(mgr.snapshot()["zone_split"], "p1_south_west_p2_north_east", "snapshot stamps S+W vs N+E")
	var p1: DeploymentZone = mgr.zone_for(0)
	var p2: DeploymentZone = mgr.zone_for(1)
	eq(p1.cells.size(), 14, "P1 half-ring is 14 cells on 8×8")
	eq(p2.cells.size(), 14, "P2 half-ring is 14 cells on 8×8")
	eq(p1.contains(Vector2i(0, 3)), true, "P1 owns west ring cell")
	eq(p1.contains(Vector2i(3, 7)), true, "P1 owns south ring cell")
	eq(p1.contains(Vector2i(0, 7)), true, "P1 owns SW corner")
	eq(p1.contains(Vector2i(7, 7)), true, "P1 owns SE corner")
	eq(p2.contains(Vector2i(3, 0)), true, "P2 owns north ring cell")
	eq(p2.contains(Vector2i(7, 3)), true, "P2 owns east ring cell")
	eq(p2.contains(Vector2i(0, 0)), true, "P2 owns NW corner")
	eq(p2.contains(Vector2i(7, 0)), true, "P2 owns NE corner")
	eq(p1.contains(Vector2i(3, 0)), false, "P1 does not own north")
	eq(p2.contains(Vector2i(3, 7)), false, "P2 does not own south")
	eq(mgr.unit_by_id("kestrel")["name"], "Kestrel", "P1 stand-in is Kestrel")
	eq(mgr.unit_by_id("ironjaw")["name"], "Ironjaw", "P2 stand-in is Ironjaw")
	eq(mgr.can_confirm(0), false, "Ready P1 starts disabled")
	eq(mgr.can_confirm(1), false, "Ready P2 starts disabled")
	eq(mgr.is_ready(0), false, "P1 ready flag starts false")
	eq(mgr.is_ready(1), false, "P2 ready flag starts false")


func _test_border_ring_only() -> void:
	var ring := DeploymentZone.border_ring(8)
	eq(ring.size(), 28, "8×8 border ring is 28 cells (64 − 36 interior)")
	eq(DeploymentZone.is_border_cell(Vector2i(0, 0), 8), true, "NW is on the ring")
	eq(DeploymentZone.is_border_cell(Vector2i(3, 0), 8), true, "north mid is on the ring")
	eq(DeploymentZone.is_border_cell(Vector2i(7, 4), 8), true, "east mid is on the ring")
	eq(DeploymentZone.is_border_cell(Vector2i(1, 1), 8), false, "first interior cell is not on the ring")
	eq(DeploymentZone.is_border_cell(Vector2i(3, 3), 8), false, "center is not on the ring")
	eq(DeploymentZone.is_border_cell(Vector2i(1, 3), 8), false, "old 2×3 inner cell is not on the ring")

	var mgr := DeploymentManager.new()
	for y in range(8):
		for x in range(8):
			var cell := Vector2i(x, y)
			var on_ring := DeploymentZone.is_border_cell(cell, 8)
			var p1 := mgr.can_deploy_unit("kestrel", cell)
			var p2 := mgr.can_deploy_unit("ironjaw", cell)
			if not on_ring:
				eq(p1["ok"], false, "P1 rejected off-ring %s" % str(cell))
				eq(p1["reason"], "outside_zone", "P1 off-ring reason %s" % str(cell))
				eq(p2["ok"], false, "P2 rejected off-ring %s" % str(cell))
				eq(p2["reason"], "outside_zone", "P2 off-ring reason %s" % str(cell))
			else:
				var any_ok: bool = bool(p1.get("ok", false)) or bool(p2.get("ok", false))
				eq(any_ok, true, "some seat can deploy on ring cell %s" % str(cell))

	eq(mgr.can_deploy_unit("kestrel", Vector2i(1, 3))["reason"], "outside_zone", "superseded west-box inner cell is outside_zone")
	eq(mgr.can_deploy_unit("ironjaw", Vector2i(6, 3))["reason"], "outside_zone", "superseded east-box inner cell is outside_zone")


func _test_half_split() -> void:
	var zones := DeploymentZone.opposite_half_ring(8)
	var p1: DeploymentZone = zones[0]
	var p2: DeploymentZone = zones[1]
	eq(p1.player_id, 0, "first zone is seat 0")
	eq(p2.player_id, 1, "second zone is seat 1")

	var seen: Dictionary = {}
	for cell in p1.cells:
		eq(seen.has(cell), false, "P1 cell %s is unique" % str(cell))
		seen[cell] = 0
		eq(DeploymentZone.owns_south_west_half(cell, 8), true, "P1 cell %s is S+W" % str(cell))
		eq(p2.contains(cell), false, "halves do not share %s" % str(cell))
	for cell in p2.cells:
		eq(seen.has(cell), false, "P2 cell %s is unique" % str(cell))
		seen[cell] = 1
		eq(DeploymentZone.owns_north_east_half(cell, 8), true, "P2 cell %s is N+E" % str(cell))
	eq(seen.size(), 28, "halves union is the full 28-cell ring")

	for x in range(8):
		eq(p2.contains(Vector2i(x, 0)), true, "entire north edge is P2 (no same-edge camp)")
		eq(p1.contains(Vector2i(x, 0)), false, "P1 cannot camp north %s" % x)
		eq(p1.contains(Vector2i(x, 7)), true, "entire south edge is P1 (no same-edge camp)")
		eq(p2.contains(Vector2i(x, 7)), false, "P2 cannot camp south %s" % x)
	for y in range(1, 7):
		eq(p1.contains(Vector2i(0, y)), true, "west exclusive of corners is P1")
		eq(p2.contains(Vector2i(0, y)), false, "P2 cannot camp west %s" % y)
		eq(p2.contains(Vector2i(7, y)), true, "east exclusive of corners is P1's opposite")
		eq(p1.contains(Vector2i(7, y)), false, "P1 cannot camp east %s" % y)

	var mgr := DeploymentManager.new()
	eq(mgr.can_deploy_unit("kestrel", Vector2i(3, 0))["reason"], "outside_zone", "P1 rejected on P2 north half")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(7, 3))["reason"], "outside_zone", "P1 rejected on P2 east half")
	eq(mgr.can_deploy_unit("ironjaw", Vector2i(3, 7))["reason"], "outside_zone", "P2 rejected on P1 south half")
	eq(mgr.can_deploy_unit("ironjaw", Vector2i(0, 3))["reason"], "outside_zone", "P2 rejected on P1 west half")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 3))["ok"], true, "P1 legal on west half")
	eq(mgr.can_deploy_unit("ironjaw", Vector2i(7, 3))["ok"], true, "P2 legal on east half")


func _test_zone_reject() -> void:
	var mgr := DeploymentManager.new()
	var mid: Dictionary = mgr.can_deploy_unit("kestrel", Vector2i(3, 3))
	eq(mid["ok"], false, "center cell is rejected")
	eq(mid["reason"], "outside_zone", "center reason is outside_zone")
	var enemy_half: Dictionary = mgr.can_deploy_unit("kestrel", Vector2i(7, 3))
	eq(enemy_half["ok"], false, "P1 cannot place on P2's east half")
	eq(enemy_half["reason"], "outside_zone", "enemy half reason is outside_zone")
	eq(mgr.place_unit("kestrel", Vector2i(4, 4))["reason"], "outside_zone", "place also zone-rejects")
	eq(mgr.unit_by_id("kestrel")["placed"], false, "failed place leaves Kestrel unplaced")


func _test_occupied_reject() -> void:
	var mgr := DeploymentManager.new()
	mgr.extra_occupied.append(Vector2i(0, 3))
	var blocked: Dictionary = mgr.can_deploy_unit("kestrel", Vector2i(0, 3))
	eq(blocked["ok"], false, "occupied zone cell is rejected")
	eq(blocked["reason"], "occupied", "occupied reason is occupied")

	mgr.extra_occupied.clear()
	eq(mgr.place_unit("kestrel", Vector2i(0, 2))["ok"], true, "first place on empty ring cell works")
	mgr.add_unit({
		"id": "kestrel_b",
		"player_id": 0,
		"name": "Kestrel B",
		"class_id": "kestrel",
		"required": false,
	})
	eq(mgr.can_deploy_unit("kestrel_b", Vector2i(0, 2))["reason"], "occupied", "second fighter cannot stack")
	eq(mgr.place_unit("kestrel", Vector2i(0, 4))["ok"], true, "same fighter may reposition")
	eq(mgr.unit_by_id("kestrel")["cell"], Vector2i(0, 4), "Kestrel moved to the new cell")
	eq(mgr.occupant_at(Vector2i(0, 2)), "", "old cell is vacated")


func _test_walkable_and_bounds() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_deploy_unit("kestrel", Vector2i(-1, 2))["reason"], "out_of_bounds", "negative x is out_of_bounds")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(8, 2))["reason"], "out_of_bounds", "x=8 is out_of_bounds")
	mgr.extra_blocked.append(Vector2i(0, 3))
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 3))["reason"], "not_walkable", "blocked ring cell is not_walkable")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 4))["ok"], true, "other ring cell stays legal")


func _test_confirm_gate() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_confirm(0), false, "Ready P1 disabled before place")
	eq(mgr.confirm(0)["reason"], "units_not_placed", "ready without a unit is units_not_placed")
	eq(mgr.ready[0], false, "P1 is not ready after the reject")
	eq(mgr.place_unit("kestrel", Vector2i(0, 2))["ok"], true, "place enables the gate")
	eq(mgr.can_confirm(0), true, "Ready P1 enabled after required unit is placed")
	eq(mgr.can_confirm(1), false, "Ready P2 stays disabled until Ironjaw is placed")
	eq(mgr.confirm(0)["ok"], true, "P1 ready succeeds once placed")
	eq(mgr.ready[0], true, "P1 ready flag is set")
	eq(mgr.is_ready(0), true, "is_ready(0) matches the flag")
	eq(mgr.can_confirm(0), false, "P1 cannot ready again")
	eq(mgr.place_unit("kestrel", Vector2i(0, 4))["reason"], "side_locked", "P1 cannot reposition after ready")


func _test_simultaneous_deploy() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.can_deploy_unit("ironjaw", Vector2i(7, 2))["ok"], true, "P2 can place before P1")
	eq(mgr.place_unit("ironjaw", Vector2i(7, 2))["ok"], true, "P2 places first")
	eq(mgr.place_unit("kestrel", Vector2i(0, 2))["ok"], true, "P1 can still place after P2")
	eq(mgr.can_confirm(1), true, "P2 can ready first")
	eq(mgr.confirm(1)["ok"], true, "P2 readies while P1 is still open")
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "one ready does not start combat")
	eq(mgr.ready[1], true, "P2 ready flag is set")
	eq(mgr.ready[0], false, "P1 is not ready yet")
	eq(mgr.place_unit("kestrel", Vector2i(3, 7))["ok"], true, "P1 may still reposition after P2 is ready")
	eq(mgr.place_unit("ironjaw", Vector2i(7, 4))["reason"], "side_locked", "ready P2 cannot reposition")
	eq(mgr.unit_by_id("kestrel")["cell"], Vector2i(3, 7), "P1 sits on the latest south-ring cell")


func _test_both_ready_starts_turn_1() -> void:
	var mgr := DeploymentManager.new()
	var started := {"count": 0, "phase": -1, "turn": -1}
	mgr.start_match.connect(func(snap: Dictionary):
		started["count"] = int(started["count"]) + 1
		started["phase"] = int(snap["phase"])
		started["turn"] = int(snap["turn_index"])
	)
	mgr.place_unit("ironjaw", Vector2i(7, 2))
	mgr.place_unit("kestrel", Vector2i(0, 2))
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "still DEPLOYMENT after both placed")
	eq(started["count"], 0, "start_match waits for both ready flags")
	mgr.confirm(0)
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "still DEPLOYMENT after only P1 ready")
	eq(started["count"], 0, "start_match still waits for P2")
	mgr.confirm(1)
	eq(mgr.phase, MatchPhase.TURN_1, "both ready → TURN_1")
	eq(mgr.phase_name(), "TURN_1", "phase_name is TURN_1")
	eq(mgr.both_ready(), true, "both_ready is true")
	eq(mgr.both_confirmed(), true, "both_confirmed aliases both_ready")
	eq(started["count"], 1, "start_match emits once")
	eq(started["phase"], MatchPhase.TURN_1, "start_match snapshot is TURN_1")
	eq(started["turn"], 1, "Turn index is 1")
	eq(mgr.snapshot()["positions_locked"], true, "positions lock after both ready")
	eq(mgr.snapshot()["both_ready"], true, "snapshot both_ready is true")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 4))["reason"], "wrong_phase", "deploy is closed in TURN_1")


func _test_combat_disabled_until_both_ready() -> void:
	var mgr := DeploymentManager.new()
	eq(mgr.combat_actions_enabled(), false, "combat off during deploy")
	eq(mgr.snapshot()["walk_enabled"], false, "walk chrome disabled during deploy")
	eq(mgr.snapshot()["end_turn_enabled"], false, "end-turn disabled during deploy")
	mgr.place_unit("kestrel", Vector2i(0, 4))
	mgr.confirm(0)
	eq(mgr.combat_actions_enabled(), false, "combat still off after only P1 ready")
	mgr.place_unit("ironjaw", Vector2i(7, 2))
	eq(mgr.combat_actions_enabled(), false, "combat still off after P2 place, before ready")
	mgr.confirm(1)
	eq(mgr.combat_actions_enabled(), true, "combat chrome enabled after both ready")
	eq(mgr.snapshot()["walk_enabled"], true, "walk chrome enabled on Turn 1")
	eq(mgr.snapshot()["end_turn_enabled"], true, "end-turn chrome enabled on Turn 1")


func _test_reposition_then_lock() -> void:
	var mgr := DeploymentManager.new()
	var first: Dictionary = mgr.place_unit("kestrel", Vector2i(0, 2))
	eq(first["repositioned"], false, "first place is not a reposition")
	var moved: Dictionary = mgr.place_unit("kestrel", Vector2i(4, 7))
	eq(moved["ok"], true, "reposition before ready is legal")
	eq(moved["repositioned"], true, "second place is a reposition")
	eq(mgr.unit_by_id("kestrel")["cell"], Vector2i(4, 7), "unit sits on the latest cell")
	mgr.confirm(0)
	eq(mgr.unit_by_id("kestrel")["locked"], true, "P1 fighter locks on ready")
	eq(mgr.legal_deploy_cells("kestrel").is_empty(), true, "ready side has no legal cells")


func _test_elevation_walkable_reuse() -> void:
	var terrain := ProtoMoveSim.new(8, 8)
	terrain.set_tile(Vector2i(0, 2), TerrainDef.Id.LAVA, 0.0)
	var mgr := DeploymentManager.new()
	mgr.is_walkable_fn = Callable(terrain, "is_walkable")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 2))["reason"], "not_walkable", "reuses ProtoMoveSim lava as not_walkable")
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 3))["ok"], true, "ground ring cell stays deployable")
	# Deploy must not require elevation climb costs.
	terrain.set_tile(Vector2i(0, 3), TerrainDef.Id.GROUND, 2.0)
	eq(mgr.can_deploy_unit("kestrel", Vector2i(0, 3))["ok"], true, "high elevation is still deployable (no climb cost)")


func _test_scene_instantiates() -> void:
	var packed: PackedScene = load("res://scenes/proto_deployment_board.tscn")
	truthy(packed is PackedScene, "proto scene resource loads")
	var scene: Node = packed.instantiate()
	truthy(scene != null, "proto scene instantiates")
	# SceneTree -s scripts do not enter the editor tree; call _ready to build HUD.
	scene._ready()
	eq(str(scene.get_script().resource_path), "res://proto/deployment/proto_deployment_board.gd", "scene script is proto_deployment_board")
	var mgr: DeploymentManager = scene._mgr
	eq(mgr.phase, MatchPhase.DEPLOYMENT, "scene manager boots in DEPLOYMENT")
	eq(mgr.can_confirm(0), false, "scene Ready P1 starts disabled")
	eq(scene._ready_p1_btn.disabled, true, "Ready P1 starts disabled before a place")
	eq(scene._ready_p2_btn.disabled, true, "Ready P2 starts disabled before a place")
	eq(mgr.place_unit("kestrel", Vector2i(0, 3))["ok"], true, "scene manager can place P1 on the west ring")
	eq(mgr.place_unit("ironjaw", Vector2i(7, 3))["ok"], true, "scene manager can place P2 on the east ring at the same time")
	eq(scene._ready_p1_btn.disabled, false, "Ready P1 enables after Kestrel is placed")
	eq(scene._ready_p2_btn.disabled, false, "Ready P2 enables after Ironjaw is placed")
	var interior_copy: String = scene._reject_text("outside_zone", Vector2i(3, 3))
	truthy(interior_copy.contains("interior"), "scene coach distinguishes interior reject")
	var wrong_half_copy: String = scene._reject_text("outside_zone", Vector2i(7, 3))
	truthy(wrong_half_copy.contains("other side"), "scene coach distinguishes wrong-half reject")
	scene.free()


func _test_phase_a_untouched() -> void:
	var combat := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(combat.contains("proto/deployment"), false, "CombatSim does not import proto/deployment")
	eq(combat.contains("DeploymentManager"), false, "CombatSim does not reference DeploymentManager")
	eq(combat.contains("MatchPhase"), false, "CombatSim does not reference proto MatchPhase")
	truthy(combat.contains("expand_ortho_path"), "Phase A still owns flat H-first walk expansion")
	truthy(combat.contains("reset_match"), "Phase A reset_match is still the live match start")
	truthy(combat.contains("kestrel_pos"), "Phase A still has a fixed Kestrel seat override")
	truthy(combat.contains("ironjaw_pos"), "Phase A still has a fixed Ironjaw seat override")
	truthy(combat.contains("Vector2i(1, 1)"), "Phase A default Kestrel seat stays (1,1)")
	truthy(combat.contains("Vector2i(6, 6)"), "Phase A default Ironjaw seat stays (6,6)")

	var board := FileAccess.get_file_as_string("res://board_view.gd")
	eq(board.contains("DeploymentManager"), false, "Phase A board_view does not use DeploymentManager")
	eq(board.contains("proto/deployment"), false, "Phase A board_view does not import proto/deployment")

	var main_scene := FileAccess.get_file_as_string("res://main.tscn")
	eq(main_scene.contains("proto_deployment"), false, "main.tscn still points at the Phase A duel")

	var scene := FileAccess.get_file_as_string("res://scenes/proto_deployment_board.tscn")
	truthy(scene.contains("proto_deployment_board.gd"), "prototype scene exists")
	truthy(scene.contains("south+west") or scene.contains("border-ring"), "proto scene stamps the half-split")

	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("Phase B+ deployment prototype"), "README has the Phase B+ deployment section")
	truthy(readme.contains("Proposed"), "README stamps Proposed")
	truthy(readme.contains("simultaneous") or readme.contains("Simultaneous"), "README lists simultaneous deploy")
	truthy(readme.contains("border ring") or readme.contains("1-deep"), "README lists the 1-deep border ring")
	truthy(readme.contains("south") and readme.contains("west"), "README documents the S+W / N+E half split")
	truthy(readme.contains("supersede"), "README notes that sequential 2×3 is superseded")


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
