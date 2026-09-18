extends SceneTree

## Headless Phase B+ prototype checks. Proposed rules — not Locked.
## Does not mutate Phase A CombatSim walk.
## Run: godot --headless --path . -s res://tests/run_elevation_movement_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Elevation movement tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_cost_math()
	_test_climb_drop_reject()
	_test_lava_impassable()
	_test_dijkstra_prefers_cheap_long_path()
	_test_occupied_blocked()
	_test_reachability_respects_mp()
	_test_z_sort_is_not_gameplay_elevation()
	_test_phase_a_duel_untouched()


func _test_cost_math() -> void:
	var board := _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.GROUND, 0.0, 0.0)
	eq(MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(1, 0))), 1, "equal elev Ground is terrain 1 only")

	board = _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.MUD, 0.0, 0.0)
	eq(MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(1, 0))), 2, "equal elev Mud is terrain 2 only")

	board = _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.WATER, 0.0, 0.0)
	eq(MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(1, 0))), 2, "equal elev Water is terrain 2 only")

	# Proposed: half-level (+0.5) counts as +1 uphill MP.
	board = _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.GROUND, 0.0, 0.5)
	eq(ElevationRules.uphill_surcharge(0.0, 0.5), 1, "half-level +0.5 uphill surcharge is +1")
	eq(MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(1, 0))), 2, "Ground +0.5 climb is 1 terrain + 1 elev = 2")

	# Proposed: +1 MP per full elevation level.
	board = _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.GROUND, 0.0, 1.0)
	eq(ElevationRules.uphill_surcharge(0.0, 1.0), 1, "full level +1.0 uphill surcharge is +1")
	eq(MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(1, 0))), 2, "Ground +1.0 climb is 1 terrain + 1 elev = 2")

	# Proposed: downhill +0.
	board = _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.GROUND, 1.0, 0.0)
	eq(ElevationRules.uphill_surcharge(1.0, 0.0), 0, "downhill surcharge is 0")
	eq(MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(1, 0))), 1, "downhill Ground is terrain only")

	eq(ElevationRules.elevation_delta(1.0, 2.0), 1.0, "delta is dest - from")
	eq(TerrainCatalog.base_move_cost(TerrainCatalog.Type.GROUND), 1, "catalog Ground 1")
	eq(TerrainCatalog.base_move_cost(TerrainCatalog.Type.MUD), 2, "catalog Mud 2")
	eq(TerrainCatalog.base_move_cost(TerrainCatalog.Type.WATER), 2, "catalog Water 2")
	eq(TerrainCatalog.is_walkable(TerrainCatalog.Type.LAVA), false, "catalog Lava not walkable")


func _test_climb_drop_reject() -> void:
	# Proposed: max climb 1.0 inclusive; 1.5 is illegal.
	eq(ElevationRules.is_legal_step(0.0, 1.0), true, "climb 1.0 is legal")
	eq(ElevationRules.step_reject_reason(0.0, 1.5), "climb_too_steep", "climb 1.5 is rejected")
	var board := _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.GROUND, 0.0, 1.5)
	var step: Dictionary = MovementCost.validate_step(board, Vector2i(0, 0), Vector2i(1, 0))
	eq(step["ok"], false, "validate_step rejects climb 1.5")
	eq(step["reason"], "climb_too_steep", "climb reject reason is climb_too_steep")
	var move: Dictionary = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(1, 0), 6)
	eq(move["ok"], false, "validate_move rejects climb 1.5")
	eq(move["reason"], "climb_too_steep", "validate_move climb reason is climb_too_steep")

	# Proposed: max drop 2.0 inclusive; 2.5 is illegal.
	eq(ElevationRules.is_legal_step(2.0, 0.0), true, "drop 2.0 is legal")
	eq(ElevationRules.step_reject_reason(2.5, 0.0), "drop_too_steep", "drop 2.5 is rejected")
	board = _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.GROUND, 2.5, 0.0)
	step = MovementCost.validate_step(board, Vector2i(0, 0), Vector2i(1, 0))
	eq(step["ok"], false, "validate_step rejects drop 2.5")
	eq(step["reason"], "drop_too_steep", "drop reject reason is drop_too_steep")
	move = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(1, 0), 6)
	eq(move["ok"], false, "validate_move rejects drop 2.5")
	eq(move["reason"], "drop_too_steep", "validate_move drop reason is drop_too_steep")

	board = _flat_pair(TerrainCatalog.Type.MUD, TerrainCatalog.Type.MUD, 2.0, 0.0)
	step = MovementCost.validate_step(board, Vector2i(0, 0), Vector2i(1, 0))
	eq(step["ok"], true, "drop 2.0 onto Mud is legal")
	eq(step["cost"], 2, "legal drop still pays dest Mud 2")


func _test_lava_impassable() -> void:
	var board := _flat_pair(TerrainCatalog.Type.GROUND, TerrainCatalog.Type.LAVA, 0.0, 0.0)
	eq(board.get_tile(Vector2i(1, 0)).walkable, false, "Lava tile walkable is false")
	var step: Dictionary = MovementCost.validate_step(board, Vector2i(0, 0), Vector2i(1, 0))
	eq(step["ok"], false, "step onto Lava is illegal")
	eq(step["reason"], "impassable", "Lava reason is impassable")
	var move: Dictionary = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(1, 0), 6)
	eq(move["ok"], false, "move onto Lava is illegal")
	eq(move["reason"], "impassable", "validate_move Lava reason is impassable")
	var path: Dictionary = MovementPathfinder.cheapest_path(board, Vector2i(0, 0), Vector2i(1, 0))
	eq(path["ok"], false, "Dijkstra will not enter Lava")
	var reach: Dictionary = MovementReachability.tiles_within_mp(board, Vector2i(0, 0), 6)
	eq(reach.has(Vector2i(1, 0)), false, "Lava is not reachable")


func _test_dijkstra_prefers_cheap_long_path() -> void:
	# Short corridor: Water-Water-Water-Ground = 2+2+2+1 = 7 MP, 4 hops.
	# Long corridor: Ground around the south = 6×1 = 6 MP, 6 hops.
	# Dijkstra must pick the cheap long path.
	var board := ProtoBoard.new(5, 2)
	for x in range(5):
		board.set_cell(Vector2i(x, 0), 0.0, TerrainCatalog.Type.WATER if x > 0 and x < 4 else TerrainCatalog.Type.GROUND)
		board.set_cell(Vector2i(x, 1), 0.0, TerrainCatalog.Type.GROUND)

	var short_cost := 0
	short_cost += MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(1, 0)))
	short_cost += MovementCost.step_mp(board.get_tile(Vector2i(1, 0)), board.get_tile(Vector2i(2, 0)))
	short_cost += MovementCost.step_mp(board.get_tile(Vector2i(2, 0)), board.get_tile(Vector2i(3, 0)))
	short_cost += MovementCost.step_mp(board.get_tile(Vector2i(3, 0)), board.get_tile(Vector2i(4, 0)))
	eq(short_cost, 7, "expensive short water corridor is 7 MP")

	var long_cost := 0
	long_cost += MovementCost.step_mp(board.get_tile(Vector2i(0, 0)), board.get_tile(Vector2i(0, 1)))
	long_cost += MovementCost.step_mp(board.get_tile(Vector2i(0, 1)), board.get_tile(Vector2i(1, 1)))
	long_cost += MovementCost.step_mp(board.get_tile(Vector2i(1, 1)), board.get_tile(Vector2i(2, 1)))
	long_cost += MovementCost.step_mp(board.get_tile(Vector2i(2, 1)), board.get_tile(Vector2i(3, 1)))
	long_cost += MovementCost.step_mp(board.get_tile(Vector2i(3, 1)), board.get_tile(Vector2i(4, 1)))
	long_cost += MovementCost.step_mp(board.get_tile(Vector2i(4, 1)), board.get_tile(Vector2i(4, 0)))
	eq(long_cost, 6, "cheap long ground path is 6 MP")
	# Recheck: 6 steps of Ground 1 = 6, not 5. South path is (0,0)->(0,1)->(1,1)->(2,1)->(3,1)->(4,1)->(4,0) = 6 hops, 6 MP.
	# Short is 4 hops / 7 MP. Long is still cheaper. Update expectation to 6.

	var found: Dictionary = MovementPathfinder.cheapest_path(board, Vector2i(0, 0), Vector2i(4, 0))
	eq(found["ok"], true, "Dijkstra finds a path")
	eq(found["cost"], 6, "Dijkstra cost is the cheap long path (6), not the water short (7)")
	eq(found["path"].size() > 4, true, "chosen path has more hops than the 4-hop water corridor")
	eq(found["path"].has(Vector2i(1, 0)), false, "chosen path does not enter the first water tile")
	eq(found["path"].has(Vector2i(2, 0)), false, "chosen path does not enter the mid water tile")
	eq(found["path"].has(Vector2i(3, 0)), false, "chosen path does not enter the last water tile")
	eq(found["path"][found["path"].size() - 1], Vector2i(4, 0), "path ends on dest")

	var move: Dictionary = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(4, 0), 6)
	eq(move["ok"], true, "6 MP is enough for the cheap long path")
	eq(move["cost"], 6, "validate_move reports Dijkstra cost 6")
	move = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(4, 0), 5)
	eq(move["ok"], false, "5 MP cannot pay the cheap path")
	eq(move["reason"], "insufficient_mp", "over-budget dest is insufficient_mp")
	eq(move["cost"], 6, "rejected move still reports true cheapest cost")


func _test_occupied_blocked() -> void:
	var board := ProtoBoard.new(3, 1)
	board.set_cell(Vector2i(0, 0), 0.0, TerrainCatalog.Type.GROUND)
	board.set_cell(Vector2i(1, 0), 0.0, TerrainCatalog.Type.GROUND)
	board.set_cell(Vector2i(2, 0), 0.0, TerrainCatalog.Type.GROUND)
	board.set_occupied(Vector2i(1, 0), "blocker")
	var step: Dictionary = MovementCost.validate_step(board, Vector2i(0, 0), Vector2i(1, 0))
	eq(step["ok"], false, "occupied neighbor is illegal")
	eq(step["reason"], "occupied", "occupied reason is occupied")
	var move: Dictionary = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(2, 0), 6)
	eq(move["ok"], false, "cannot path through occupied tile on a 1-wide corridor")
	eq(move["reason"] in ["occupied", "no_path"], true, "blocked corridor is occupied or no_path")

	# Wider board: go around the occupied tile.
	board = ProtoBoard.new(3, 2)
	for y in range(2):
		for x in range(3):
			board.set_cell(Vector2i(x, y), 0.0, TerrainCatalog.Type.GROUND)
	board.set_occupied(Vector2i(1, 0), "blocker")
	move = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(2, 0), 6)
	eq(move["ok"], true, "Dijkstra goes around occupied")
	eq(move["path"].has(Vector2i(1, 0)), false, "path does not enter occupied")
	eq(move["cost"], 4, "around path is 4 MP (south, east, east, north)")


func _test_reachability_respects_mp() -> void:
	var board := ProtoBoard.new(4, 1)
	for x in range(4):
		board.set_cell(Vector2i(x, 0), 0.0, TerrainCatalog.Type.GROUND)
	var reach: Dictionary = MovementReachability.tiles_within_mp(board, Vector2i(0, 0), 2)
	eq(reach.has(Vector2i(1, 0)), true, "1 MP Ground is reachable with 2 MP")
	eq(reach.has(Vector2i(2, 0)), true, "2 MP Ground is reachable with 2 MP")
	eq(reach.has(Vector2i(3, 0)), false, "3 MP Ground is not reachable with 2 MP")
	eq(MovementReachability.cost_to(reach, Vector2i(2, 0)), 2, "reach cost to +2x is 2")
	eq(reach.has(Vector2i(0, 0)), false, "origin is not listed as a destination")

	var oob: Dictionary = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(9, 0), 6)
	eq(oob["reason"], "out_of_bounds", "off-board dest is out_of_bounds")
	var same: Dictionary = MovementCost.validate_move(board, Vector2i(0, 0), Vector2i(0, 0), 6)
	eq(same["reason"], "same_tile", "standing move is same_tile")
	var diag: Dictionary = MovementCost.validate_step(board, Vector2i(0, 0), Vector2i(1, 1))
	eq(diag["reason"] in ["not_ortho", "out_of_bounds"], true, "diagonal is not an edge")


func _test_z_sort_is_not_gameplay_elevation() -> void:
	var a := Vector2(0, 10)
	var b := Vector2(0, 40)
	truthy(ZSortHelper.draw_order(b, 0.0) > ZSortHelper.draw_order(a, 0.0), "larger world Y draws in front")
	truthy(ZSortHelper.draw_order(a, 1.0) > ZSortHelper.draw_order(a, 0.0), "elevation increases draw order")
	truthy(ZSortHelper.draw_order(a, 0.0, ZSortHelper.UNIT_DRAW_BIAS) > ZSortHelper.draw_order(a, 0.0, 0.0), "unit offset draws in front of its tile")
	eq(ZSortHelper.visual_y_offset(1.0), -ZSortHelper.ELEVATION_Y_PX, "visual offset raises the sprite, not gameplay elev")
	var src := FileAccess.get_file_as_string("res://prototypes/elevation_movement/z_sort.gd")
	truthy(src.contains("not gameplay elevation") or src.contains("NOT use Node2D.z_index as gameplay"), "Z-sort helper documents z_index is not elevation")
	var elev_src := FileAccess.get_file_as_string("res://prototypes/elevation_movement/elevation_rules.gd")
	eq(elev_src.contains("z_index"), false, "elevation rules do not read z_index")


func _test_phase_a_duel_untouched() -> void:
	var combat := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(combat.contains("ElevationRules"), false, "CombatSim does not import ElevationRules")
	eq(combat.contains("MovementPathfinder"), false, "CombatSim does not import prototype Dijkstra")
	eq(combat.contains("TerrainCatalog"), false, "CombatSim does not import TerrainCatalog")
	truthy(combat.contains("manhattan"), "CombatSim still documents Manhattan walk")
	truthy(combat.contains("expand_ortho_path"), "CombatSim still expands H-first ortho paths")

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("prototypes/elevation_movement"), false, "board_view does not load the prototype")
	eq(view.contains("ElevationRules"), false, "board_view does not use ElevationRules")

	var main_scene := FileAccess.get_file_as_string("res://main.tscn")
	eq(main_scene.contains("elevation_movement"), false, "main.tscn still hosts the Phase A duel")

	var project := FileAccess.get_file_as_string("res://project.godot")
	eq(project.contains("elevation_movement_demo"), false, "project main_scene was not pointed at the prototype")

	# Live Phase A walk still spends Manhattan, not terrain/elevation.
	var script := load("res://backend/combat_sim.gd")
	var sim: Node = script.new()
	sim.reset_match({"seed": 1, "kestrel_pos": Vector2i(2, 2), "ironjaw_pos": Vector2i(7, 7)})
	var result: Dictionary = sim.submit({"type": "move", "to": Vector2i(4, 2)})
	eq(result["ok"], true, "Phase A orthogonal Manhattan 2 still walks")
	eq(result["events"][0]["mp_spent"], 2, "Phase A walk still spends Manhattan 2, not terrain MP")
	eq(sim.snapshot()["units"][0]["pos"], Vector2i(4, 2), "Phase A pawn still lands on dest")
	sim.free()


func _flat_pair(from_t: TerrainCatalog.Type, to_t: TerrainCatalog.Type, from_e: float, to_e: float) -> ProtoBoard:
	var board := ProtoBoard.new(2, 1)
	board.set_cell(Vector2i(0, 0), from_e, from_t)
	board.set_cell(Vector2i(1, 0), to_e, to_t)
	return board


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
