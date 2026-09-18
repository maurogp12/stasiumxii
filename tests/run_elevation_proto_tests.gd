extends SceneTree

## Headless Phase B+ elevation prototype checks.
## Proposed (not Locked). Does not load or mutate CombatSim match state.
## Run: godot --headless --path . -s res://tests/run_elevation_proto_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Elevation proto tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_terrain_table()
	_test_elevation_cost_and_legality()
	_test_step_costs()
	_test_climb_drop_reject()
	_test_validate_gates()
	_test_no_diagonal_edges()
	_test_reachable_prefers_flat_over_mud_climb()
	_test_path_reconstruct()
	_test_walkable_override()
	_test_demo_map_loads()
	_test_visual_sort_is_view_only()
	_test_phase_a_untouched()


func _test_terrain_table() -> void:
	var catalog: Dictionary = TerrainDef.catalog()
	eq(catalog[TerrainDef.Id.GROUND].base_mp, 1, "Proposed Ground MP is 1")
	eq(catalog[TerrainDef.Id.GROUND].walkable, true, "Ground is walkable")
	eq(catalog[TerrainDef.Id.GROUND].display_name, "Ground", "Ground display name")
	eq(catalog[TerrainDef.Id.MUD].base_mp, 2, "Proposed Mud MP is 2")
	eq(catalog[TerrainDef.Id.MUD].walkable, true, "Mud is walkable")
	eq(catalog[TerrainDef.Id.WATER].base_mp, 2, "Proposed Water MP is 2")
	eq(catalog[TerrainDef.Id.WATER].walkable, true, "Water is walkable")
	eq(catalog[TerrainDef.Id.LAVA].walkable, false, "Proposed Lava is impassable")
	eq(catalog.size(), 4, "catalog is only the four Proposed terrains")


func _test_elevation_cost_and_legality() -> void:
	var flat: Dictionary = ElevationCost.analyze(0.0, 0.0)
	eq(flat["legal"], true, "flat step is legal")
	eq(flat["climb_mp"], 0, "flat climb MP is 0")

	var full: Dictionary = ElevationCost.analyze(0.0, 1.0)
	eq(full["legal"], true, "full-level climb 1.0 is legal (max climb 1.0)")
	eq(full["climb_mp"], 1, "full-level climb costs +1")

	var half: Dictionary = ElevationCost.analyze(0.0, 0.5)
	eq(half["legal"], true, "half-level climb is legal")
	eq(half["climb_mp"], 1, "Proposed: half-level climb counts as +1")

	var down: Dictionary = ElevationCost.analyze(1.0, 0.0)
	eq(down["legal"], true, "downhill 1.0 is legal")
	eq(down["climb_mp"], 0, "Proposed downhill is +0")

	var drop2: Dictionary = ElevationCost.analyze(2.0, 0.0)
	eq(drop2["legal"], true, "drop of 2.0 is legal (max drop 2.0)")
	eq(drop2["climb_mp"], 0, "drop costs 0")

	var steep: Dictionary = ElevationCost.analyze(0.0, 1.5)
	eq(steep["legal"], false, "climb 1.5 exceeds max climb 1.0")
	eq(steep["reason"], "climb_too_steep", "steep climb reason")

	var far: Dictionary = ElevationCost.analyze(2.5, 0.0)
	eq(far["legal"], false, "drop 2.5 exceeds max drop 2.0")
	eq(far["reason"], "drop_too_far", "far drop reason")


func _test_step_costs() -> void:
	var sim := _blank(3, 3)
	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.GROUND, 1.0)
	var climb := sim.step_cost(Vector2i(0, 0), Vector2i(1, 0))
	eq(climb["ok"], true, "ground + full climb is a legal step")
	eq(climb["terrain_mp"], 1, "ground terrain MP is 1")
	eq(climb["climb_mp"], 1, "climb adds +1")
	eq(climb["cost"], 2, "move cost is terrain + elevation")

	sim.set_tile(Vector2i(0, 1), TerrainDef.Id.MUD, 1.0)
	var mud_climb := sim.step_cost(Vector2i(0, 0), Vector2i(0, 1))
	eq(mud_climb["ok"], true, "mud + climb is legal when Δelev is 1.0")
	eq(mud_climb["cost"], 3, "mud 2 + climb 1 = 3")

	sim.set_tile(Vector2i(1, 1), TerrainDef.Id.GROUND, 0.0)
	var down := sim.step_cost(Vector2i(1, 0), Vector2i(1, 1))
	eq(down["ok"], true, "downhill ground is legal")
	eq(down["climb_mp"], 0, "downhill climb MP is 0")
	eq(down["cost"], 1, "downhill ground costs terrain only")

	sim.set_tile(Vector2i(2, 0), TerrainDef.Id.WATER, 0.0)
	var water := sim.step_cost(Vector2i(1, 0), Vector2i(2, 0))
	eq(water["cost"], 2, "water downhill from 1.0 costs 2 (terrain only)")


func _test_climb_drop_reject() -> void:
	var sim := _blank(3, 2)
	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.GROUND, 1.5)
	var climb := sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 6)
	eq(climb["ok"], false, "climb 1.5 is rejected")
	eq(climb["reason"], "climb_too_steep", "climb reject reason is climb_too_steep")

	sim.set_tile(Vector2i(0, 0), TerrainDef.Id.GROUND, 2.5)
	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.GROUND, 0.0)
	var drop := sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 6)
	eq(drop["ok"], false, "drop 2.5 is rejected")
	eq(drop["reason"], "drop_too_far", "drop reject reason is drop_too_far")

	sim.set_tile(Vector2i(0, 0), TerrainDef.Id.GROUND, 2.0)
	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.GROUND, 0.0)
	var ok_drop := sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 6)
	eq(ok_drop["ok"], true, "drop of exactly 2.0 is legal")
	eq(ok_drop["cost"], 1, "legal drop still pays dest terrain MP")


func _test_validate_gates() -> void:
	var sim := _blank(3, 3)
	eq(sim.validate_move(Vector2i(0, 0), Vector2i(5, 0), 6)["reason"], "out_of_bounds", "OOB dest is out_of_bounds")
	eq(sim.validate_move(Vector2i(0, 0), Vector2i(0, 0), 6)["reason"], "same_tile", "self dest is same_tile")

	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.LAVA, 0.0)
	eq(sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 6)["reason"], "not_walkable", "Lava dest is not_walkable")

	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.GROUND, 0.0)
	sim.occupy(Vector2i(1, 0))
	eq(sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 6)["reason"], "occupied", "occupied dest is occupied")
	sim.vacate(Vector2i(1, 0))

	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.MUD, 0.0)
	var short := sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 1)
	eq(short["ok"], false, "mud hop costs 2 so 1 MP is rejected")
	eq(short["reason"], "insufficient_mp", "short MP reason is insufficient_mp")

	var applied: Dictionary = sim.apply_move(Vector2i(0, 0), Vector2i(1, 0), 4)
	eq(applied["ok"], true, "mud hop with 4 MP is legal")
	eq(applied["cost"], 2, "applied mud hop spends 2")
	eq(applied["mp_left"], 2, "apply_move returns remaining MP")
	eq(sim.is_occupied(Vector2i(1, 0)), true, "dest becomes occupied")
	eq(sim.is_occupied(Vector2i(0, 0)), false, "origin is vacated")


func _test_no_diagonal_edges() -> void:
	var sim := _blank(3, 3)
	var diag := sim.step_cost(Vector2i(0, 0), Vector2i(1, 1))
	eq(diag["ok"], false, "diagonal is not a legal edge")
	eq(diag["reason"], "not_ortho", "diagonal reason is not_ortho")
	# Dest-click to a diagonal tile can still be legal via two ortho hops.
	var via: Dictionary = sim.validate_move(Vector2i(0, 0), Vector2i(1, 1), 3)
	eq(via["ok"], true, "diagonal dest is legal as two ortho hops")
	eq(via["path"].size(), 2, "diagonal dest reconstructs two hops")
	eq((via["path"][0] as Vector2i).x == 1 or (via["path"][0] as Vector2i).y == 1, true, "first hop is ortho")


func _test_reachable_prefers_flat_over_mud_climb() -> void:
	# Start (0,0) G0. Dest (1,1) G0.
	# Flat: (0,0)->(1,0) G0 cost 1 ->(1,1) G0 cost 1  total 2
	# Mud+climb: (0,0)->(0,1) M1 cost 2+1=3 ->(1,1) drop/ground 1  total 4
	var sim := _blank(3, 3)
	sim.set_tile(Vector2i(0, 1), TerrainDef.Id.MUD, 1.0)
	var dest := Vector2i(1, 1)
	var move: Dictionary = sim.cheapest_path(Vector2i(0, 0), dest, 6)
	eq(move["ok"], true, "dest is reachable")
	eq(move["cost"], 2, "cheapest path is flat Ground cost 2, not mud+climb 4")
	eq(move["path"], [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i], "reconstruct prefers the flat corridor")

	var reach2 := sim.reachable(Vector2i(0, 0), 2)
	eq(reach2.has(dest), true, "MP 2 still reaches dest via the flat path")
	eq(reach2.has(Vector2i(0, 1)), false, "MP 2 cannot enter the mud+climb tile (cost 3)")
	eq(int(reach2[dest]["cost"]), 2, "reachable records flat cost 2")

	var reach3 := sim.reachable(Vector2i(0, 0), 3)
	eq(reach3.has(Vector2i(0, 1)), true, "MP 3 can enter mud+climb")
	eq(int(reach3[Vector2i(0, 1)]["cost"]), 3, "mud+climb step costs 3")
	eq(int(reach3[dest]["cost"]), 2, "even with MP 3, dest still prefers cost 2")


func _test_path_reconstruct() -> void:
	var sim := _blank(4, 2)
	var move: Dictionary = sim.cheapest_path(Vector2i(0, 0), Vector2i(3, 0), 5)
	eq(move["ok"], true, "3-step ground corridor is legal at 5 MP")
	eq(move["cost"], 3, "three Ground hops cost 3")
	eq(move["path"], [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i], "path is reconstructed hop-by-hop")
	eq(sim.cheapest_path(Vector2i(0, 0), Vector2i(3, 0), 2)["reason"], "insufficient_mp", "MP 2 cannot pay 3 Ground hops")


func _test_walkable_override() -> void:
	var sim := _blank(2, 1)
	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.GROUND, 0.0, false)
	eq(sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 3)["reason"], "not_walkable", "walkable override can close Ground")
	sim.set_tile(Vector2i(1, 0), TerrainDef.Id.LAVA, 0.0, true)
	var forced: Dictionary = sim.validate_move(Vector2i(0, 0), Vector2i(1, 0), 3)
	eq(forced["ok"], true, "walkable override can open Lava for proto fixtures")
	eq(forced["cost"], 0, "Lava base_mp stays 0 even when forced walkable")


func _test_demo_map_loads() -> void:
	var sim := ProtoMoveSim.new()
	sim.load_demo_map()
	eq(sim.width, 8, "demo map is 8 wide")
	eq(sim.height, 8, "demo map is 8 tall")
	eq(sim.terrain_of(Vector2i(1, 2)).id, TerrainDef.Id.MUD, "demo mud tile present")
	eq(sim.terrain_of(Vector2i(3, 6)).id, TerrainDef.Id.LAVA, "demo lava tile present")
	eq(sim.tile_at(Vector2i(7, 0)).elevation, 2.0, "demo ridge peak is elevation 2")
	eq(sim.is_walkable(Vector2i(6, 3)), false, "demo lava is not walkable")
	var reach := sim.reachable(Vector2i(0, 3), 6)
	truthy(reach.size() > 1, "demo start with 6 MP has reachable tiles")


func _test_visual_sort_is_view_only() -> void:
	var low := ProtoVisualSort.tile_z_index(Vector2i(1, 1), 0.0)
	var high := ProtoVisualSort.tile_z_index(Vector2i(1, 1), 2.0)
	truthy(high > low, "higher elevation paints in front at the same grid cell")
	var south := ProtoVisualSort.tile_z_index(Vector2i(2, 2), 0.0)
	var north := ProtoVisualSort.tile_z_index(Vector2i(0, 0), 2.0)
	truthy(south > north, "iso world Y still dominates z-sort vs a small elevation bump")
	eq(ProtoVisualSort.unit_z_index(Vector2i(1, 1), 0.0) > low, true, "units sit above their tile")
	var pos: Vector2 = ProtoVisualSort.cell_to_local(Vector2i(1, 0), 1.0)
	var flat: Vector2 = ProtoVisualSort.cell_to_local(Vector2i(1, 0), 0.0)
	truthy(pos.y < flat.y, "visual elevation lifts the sprite on screen (smaller Y)")

	var sim_src := FileAccess.get_file_as_string("res://proto/elevation/proto_move_sim.gd")
	eq(sim_src.contains("ProtoVisualSort"), false, "ProtoMoveSim does not read the view z-sort helper")
	eq(sim_src.contains("z_index"), false, "ProtoMoveSim does not set z_index")
	var cost_src := FileAccess.get_file_as_string("res://proto/elevation/elevation_cost.gd")
	eq(cost_src.contains("z_index"), false, "ElevationCost is gameplay-only")
	truthy(cost_src.contains("Proposed"), "ElevationCost is stamped Proposed")


func _test_phase_a_untouched() -> void:
	var combat := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(combat.contains("proto/elevation"), false, "CombatSim does not import proto/elevation")
	eq(combat.contains("ProtoMoveSim"), false, "CombatSim does not reference ProtoMoveSim")
	eq(combat.contains("ElevationCost"), false, "CombatSim does not reference ElevationCost")
	eq(combat.contains("TerrainDef"), false, "CombatSim does not reference TerrainDef")
	truthy(combat.contains("expand_ortho_path"), "Phase A still owns flat H-first walk expansion")

	var board := FileAccess.get_file_as_string("res://board_view.gd")
	eq(board.contains("ProtoMoveSim"), false, "Phase A board_view does not use ProtoMoveSim")
	eq(board.contains("proto/elevation"), false, "Phase A board_view does not import proto/elevation")

	var main_scene := FileAccess.get_file_as_string("res://main.tscn")
	eq(main_scene.contains("proto_elevation"), false, "main.tscn still points at the Phase A duel")

	var scene := FileAccess.get_file_as_string("res://scenes/proto_elevation_board.tscn")
	truthy(scene.contains("proto_elevation_board.gd"), "prototype scene exists")

	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("Phase B+ elevation prototype"), "README has the Phase B+ section")
	truthy(readme.contains("Proposed"), "README stamps Proposed")
	truthy(readme.contains("Ground 1"), "README lists Ground 1")
	truthy(readme.contains("Max climb"), "README lists max climb")


func _blank(width: int, height: int) -> ProtoMoveSim:
	return ProtoMoveSim.new(width, height)


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
