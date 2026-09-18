extends SceneTree

## Headless Phase B+ prototype checks. Does not exercise CombatSim walk rules
## except to prove submit(move) is still Locked Manhattan and unwired.
## Run: godot --headless --path . -s res://tests/run_elevation_proto_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Elevation proto tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_proposed_terrain_defs()
	_test_cost_math()
	_test_climb_reject()
	_test_drop_rules()
	_test_lava_impassable()
	_test_ortho_neighbor_weights()
	_test_cheaper_long_path_vs_mud()
	_test_z_sort_view_only()
	_test_not_wired_into_combat_sim()


func _test_proposed_terrain_defs() -> void:
	var ground: TerrainDef = TerrainDef.proposed(TerrainDef.Kind.GROUND)
	var mud: TerrainDef = TerrainDef.proposed(TerrainDef.Kind.MUD)
	var water: TerrainDef = TerrainDef.proposed(TerrainDef.Kind.WATER)
	var lava: TerrainDef = TerrainDef.proposed(TerrainDef.Kind.LAVA)
	eq(ground.base_move_cost, 1, "Proposed Ground MP is 1")
	eq(mud.base_move_cost, 2, "Proposed Mud MP is 2")
	eq(water.base_move_cost, 2, "Proposed Water MP is 2")
	eq(lava.walkable, false, "Proposed Lava is impassable")
	eq(lava.is_impassable(), true, "Lava reports impassable")
	var tile: ProtoBoardTile = ProtoBoardTile.proposed(Vector2i(2, 3), TerrainDef.Kind.MUD, 0.5)
	eq(tile.grid_pos, Vector2i(2, 3), "ProtoBoardTile.grid_pos")
	approx(tile.elevation, 0.5, "ProtoBoardTile.elevation")
	eq(tile.terrain_type, TerrainDef.Kind.MUD, "ProtoBoardTile.terrain_type")
	eq(tile.base_move_cost, 2, "ProtoBoardTile.base_move_cost from TerrainDef")
	eq(tile.walkable, true, "Mud is walkable")


func _test_cost_math() -> void:
	var g0 := _tile(0, 0, TerrainDef.Kind.GROUND, 0.0)
	var g0b := _tile(1, 0, TerrainDef.Kind.GROUND, 0.0)
	var mud := _tile(1, 0, TerrainDef.Kind.MUD, 0.0)
	var water := _tile(1, 0, TerrainDef.Kind.WATER, 0.0)
	var half := _tile(1, 0, TerrainDef.Kind.GROUND, 0.5)
	var full := _tile(1, 0, TerrainDef.Kind.GROUND, 1.0)
	var mud_full := _tile(1, 0, TerrainDef.Kind.MUD, 1.0)
	var down := _tile(1, 0, TerrainDef.Kind.GROUND, 0.0)
	var from_full := _tile(0, 0, TerrainDef.Kind.GROUND, 1.0)

	_expect_cost(MovementCost.calculate(g0, g0b), true, 1, 1, 0, "", "Ground 0 → Ground 0 is terrain 1")
	_expect_cost(MovementCost.calculate(g0, mud), true, 2, 2, 0, "", "Ground → Mud is Proposed terrain 2")
	_expect_cost(MovementCost.calculate(g0, water), true, 2, 2, 0, "", "Ground → Water is Proposed terrain 2")
	_expect_cost(MovementCost.calculate(g0, half), true, 2, 1, 1, "", "half step up is +1 elev MP")
	_expect_cost(MovementCost.calculate(g0, full), true, 2, 1, 1, "", "full level up is +1 elev MP")
	_expect_cost(MovementCost.calculate(from_full, down), true, 1, 1, 0, "", "downhill elev MP is 0")
	_expect_cost(MovementCost.calculate(g0, mud_full), true, 3, 2, 1, "", "Mud + full climb is 2+1")
	eq(ElevationRules.elevation_mp(0.0, 1.5), 2, "Proposed math: 1 full + half step = +2 (before climb gate)")
	eq(ElevationRules.elevation_mp(2.0, 0.0), 0, "Proposed downhill MP is 0")
	eq(ElevationRules.MAX_CLIMB, 1.0, "Proposed max climb is 1")
	eq(ElevationRules.MAX_DROP, 2.0, "Proposed max drop is 2")


func _test_climb_reject() -> void:
	var from := _tile(0, 0, TerrainDef.Kind.GROUND, 0.0)
	var steep := _tile(1, 0, TerrainDef.Kind.GROUND, 2.0)
	var one_half := _tile(1, 0, TerrainDef.Kind.GROUND, 1.5)
	var legal_full := _tile(1, 0, TerrainDef.Kind.GROUND, 1.0)
	var from_half := _tile(0, 0, TerrainDef.Kind.GROUND, 0.5)
	var to_one_half := _tile(1, 0, TerrainDef.Kind.GROUND, 1.5)
	var to_two := _tile(1, 0, TerrainDef.Kind.GROUND, 2.0)

	_expect_cost(MovementCost.calculate(from, steep), false, 3, 1, 2, "climb_exceeded", "climb 2 is rejected")
	_expect_cost(MovementCost.calculate(from, one_half), false, 3, 1, 2, "climb_exceeded", "climb 1.5 is rejected")
	_expect_cost(MovementCost.calculate(from, legal_full), true, 2, 1, 1, "", "climb 1 is allowed")
	_expect_cost(MovementCost.calculate(from_half, to_one_half), true, 2, 1, 1, "", "0.5 → 1.5 is climb 1")
	_expect_cost(MovementCost.calculate(from_half, to_two), false, 3, 1, 2, "climb_exceeded", "0.5 → 2.0 is climb 1.5")
	eq(ElevationRules.climb_allowed(1.0), true, "climb_allowed(1)")
	eq(ElevationRules.climb_allowed(1.5), false, "climb_allowed(1.5)")


func _test_drop_rules() -> void:
	var from2 := _tile(0, 0, TerrainDef.Kind.GROUND, 2.0)
	var from3 := _tile(0, 0, TerrainDef.Kind.GROUND, 3.0)
	var from25 := _tile(0, 0, TerrainDef.Kind.GROUND, 2.5)
	var to0 := _tile(1, 0, TerrainDef.Kind.GROUND, 0.0)
	_expect_cost(MovementCost.calculate(from2, to0), true, 1, 1, 0, "", "drop 2 is allowed")
	_expect_cost(MovementCost.calculate(from3, to0), false, 1, 1, 0, "drop_exceeded", "drop 3 is rejected")
	_expect_cost(MovementCost.calculate(from25, to0), false, 1, 1, 0, "drop_exceeded", "drop 2.5 is rejected")


func _test_lava_impassable() -> void:
	var ground := _tile(0, 0, TerrainDef.Kind.GROUND, 0.0)
	var lava := _tile(1, 0, TerrainDef.Kind.LAVA, 0.0)
	var step: Dictionary = MovementCost.calculate(ground, lava)
	eq(step["ok"], false, "Lava step is not ok")
	eq(step["reason"], "impassable", "Lava reason is impassable")

	var tiles := {
		Vector2i(0, 0): ground,
		Vector2i(1, 0): lava,
		Vector2i(0, 1): _tile(0, 1, TerrainDef.Kind.GROUND, 0.0),
	}
	var reach: Dictionary = ProtoPathfinder.reachable(tiles, Vector2i(0, 0), 6)
	eq(reach.has(Vector2i(1, 0)), false, "Dijkstra never enters lava")
	eq(reach.has(Vector2i(0, 1)), true, "Ground neighbor stays reachable")
	var edge: Dictionary = ProtoPathfinder.neighbor_weight(ground, lava)
	eq(edge["ok"], false, "Lava neighbor weight is rejected")
	eq(edge["weight"], -1, "Illegal edge weight is -1")


func _test_ortho_neighbor_weights() -> void:
	var a := _tile(0, 0, TerrainDef.Kind.GROUND, 0.0)
	var ortho := _tile(1, 0, TerrainDef.Kind.MUD, 0.0)
	var diag := _tile(1, 1, TerrainDef.Kind.GROUND, 0.0)
	var edge: Dictionary = ProtoPathfinder.neighbor_weight(a, ortho)
	eq(edge["ok"], true, "Ortho neighbor is a legal edge")
	eq(edge["weight"], 2, "Mud ortho weight is Proposed 2")
	eq(edge["ortho"], true, "Ortho flag is true")
	var diag_edge: Dictionary = ProtoPathfinder.neighbor_weight(a, diag)
	eq(diag_edge["ok"], false, "Diagonal is not an edge")
	eq(diag_edge["reason"], "not_ortho", "Diagonal reason is not_ortho")
	eq(ProtoPathfinder.ortho_neighbors(Vector2i(2, 2)).size(), 4, "Exactly four ortho neighbors")


func _test_cheaper_long_path_vs_mud() -> void:
	var tiles: Dictionary = ProtoBoard.mud_detour_board()
	var start := Vector2i(0, 0)
	var dest := Vector2i(4, 0)

	var short := _manual_path_cost(tiles, [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	])
	var long := _manual_path_cost(tiles, [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 0),
	])
	eq(short, 7, "Muddy short path is 7 MP")
	eq(long, 6, "Ground wrap is 6 MP")
	truthy(long < short, "Long Ground path is cheaper than muddy short path")

	var reach6: Dictionary = ProtoPathfinder.reachable(tiles, start, 6)
	eq(reach6.has(dest), true, "Dest is reachable with 6 MP via the wrap")
	eq(ProtoPathfinder.path_cost(reach6, dest), 6, "Dijkstra cost is the cheaper 6")
	var path: Array = ProtoPathfinder.reconstruct_path(reach6, dest)
	eq(path, [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 0),
	], "Cheapest path is the Ground wrap, not the muddy row")

	var reach5: Dictionary = ProtoPathfinder.reachable(tiles, start, 5)
	eq(reach5.has(dest), false, "Dest is not reachable with 5 MP")

	var reach7: Dictionary = ProtoPathfinder.reachable(tiles, start, 7)
	eq(ProtoPathfinder.path_cost(reach7, dest), 6, "Extra MP still prefers cost 6")


func _test_z_sort_view_only() -> void:
	var back := ElevationZSort.sort_key_for_tile(Vector2i(0, 0), 0.0)
	var front := ElevationZSort.sort_key_for_tile(Vector2i(1, 1), 0.0)
	truthy(front > back, "Larger world Y sorts in front")
	var low := ElevationZSort.sort_key(32.0, 0.0)
	var high := ElevationZSort.sort_key(32.0, 1.0)
	truthy(high > low, "Same world Y: higher visual elevation draws later")
	eq(ElevationZSort.compare(16.0, 0.0, 16.0, 1.0), -1, "compare: lower elev draws behind")
	var src := FileAccess.get_file_as_string("res://prototype/elevation/elevation_z_sort.gd")
	truthy(src.contains("view-only") or src.contains("View-only"), "Z-sort file is labeled view-only")
	eq(src.contains("CombatSim.submit"), false, "Z-sort helper does not call CombatSim")


func _test_not_wired_into_combat_sim() -> void:
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("prototype/elevation"), false, "CombatSim does not reference prototype/elevation")
	eq(sim_src.contains("MovementCost"), false, "CombatSim does not reference MovementCost")
	eq(sim_src.contains("ProtoBoardTile"), false, "CombatSim does not reference ProtoBoardTile")
	eq(sim_src.contains("ElevationRules"), false, "CombatSim does not reference ElevationRules")
	eq(sim_src.contains("ProtoPathfinder"), false, "CombatSim does not reference ProtoPathfinder")
	eq(sim_src.contains("TerrainDef"), false, "CombatSim does not reference TerrainDef")

	var script := load("res://backend/combat_sim.gd")
	var sim: Node = script.new()
	sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(1, 1)})
	eq(sim.snapshot()["walk"], "manhattan", "Live walk label stays Locked Manhattan")
	var result: Dictionary = sim.submit({"type": "move", "to": Vector2i(3, 1)})
	eq(result["ok"], true, "Phase A dest-click walk still accepts Manhattan 2")
	eq(sim.snapshot()["units"][0]["mp"], 1, "Phase A walk still spends Manhattan MP, not terrain weights")
	eq(sim.snapshot()["units"][0]["pos"], Vector2i(3, 1), "Phase A walk still lands on the dest")
	sim.free()


func _tile(x: int, y: int, kind_id: TerrainDef.Kind, elevation: float) -> ProtoBoardTile:
	return ProtoBoardTile.proposed(Vector2i(x, y), kind_id, elevation)


func _expect_cost(step: Dictionary, ok: bool, total_mp: int, terrain_mp: int, elev_mp: int, reason: String, msg: String) -> void:
	eq(step["ok"], ok, "%s (ok)" % msg)
	eq(step["total_mp"], total_mp, "%s (total_mp)" % msg)
	eq(step["terrain_mp"], terrain_mp, "%s (terrain_mp)" % msg)
	eq(step["elev_mp"], elev_mp, "%s (elev_mp)" % msg)
	eq(step["reason"], reason, "%s (reason)" % msg)


func _manual_path_cost(tiles: Dictionary, path: Array) -> int:
	var total := 0
	for i in range(1, path.size()):
		var step: Dictionary = MovementCost.calculate(tiles[path[i - 1]], tiles[path[i]])
		if not step["ok"]:
			fail("manual path step %s → %s rejected (%s)" % [path[i - 1], path[i], step["reason"]])
			return -1
		total += int(step["total_mp"])
	return total


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
