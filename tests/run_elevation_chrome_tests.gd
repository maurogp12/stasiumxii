extends SceneTree

## Headless live-board elevation chrome checks.
## Adapter + tile paint + walk highlights from legal_intents.
## Stacked on Backend #36 snapshot.tiles. Hit / facing / LoS stay flat.
## Run: godot --headless --path . -s res://tests/run_elevation_chrome_tests.gd

const SNAPSHOT_TILES := preload("res://board/snapshot_tiles.gd")
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const TILE_SCRIPT := preload("res://board/tile.gd")
const HUD := preload("res://ui/hud.gd")

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	var script := load("res://backend/combat_sim.gd")
	_sim = script.new()
	_run()
	print("Elevation chrome tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_adapter_defaults_flat_ground()
	_test_adapter_reads_tile_array()
	_test_adapter_reads_named_fields()
	_test_adapter_reads_parallel_grids()
	_test_adapter_reads_terrain_cell_lists()
	_test_adapter_normalizes_terrain_aliases()
	_test_walk_dests_follow_legal_intents_only()
	_test_live_snapshot_tiles_from_combatsim()
	_test_demo_map_paints_from_snapshot()
	_test_live_tiles_paint_terrain_and_elevation()
	_test_visual_sort_is_view_only()
	_test_hud_legend_and_face_untouched()
	_test_deploy_chrome_untouched()
	_test_no_height_hit_facing_los()
	_test_board_view_wires_adapter()


func _test_adapter_defaults_flat_ground() -> void:
	var tiles: Dictionary = SNAPSHOT_TILES.from_snapshot({})
	eq(tiles.size(), 64, "adapter fills an 8x8 when snapshot has no tiles")
	var cell: Dictionary = tiles[Vector2i(3, 4)]
	eq(cell["terrain_type"], "ground", "missing tiles default to ground")
	eq(cell["elevation"], 0.0, "missing tiles default to elevation 0")
	eq(SNAPSHOT_TILES.has_board_data({}), false, "empty snap has no board data")
	eq(SNAPSHOT_TILES.has_board_data({"tiles": []}), true, "tiles key counts as board data")


func _test_adapter_reads_tile_array() -> void:
	var snap := {
		"tiles": [
			{"pos": Vector2i(1, 2), "elevation": 1.0, "terrain_type": "mud"},
			{"cell": Vector2i(2, 2), "elevation": 0.5, "terrain": "water"},
			{"grid_pos": Vector2i(3, 3), "height": 2, "type": "lava"},
		],
	}
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(1, 2)), "mud", "array record terrain_type")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(1, 2)), 1.0, "array record elevation")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 2)), "water", "array record terrain alias")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(2, 2)), 0.5, "half-level elevation is kept")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(3, 3)), "lava", "array record type=lava")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(3, 3)), 2.0, "height alias maps to elevation")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 0)), "ground", "unlisted cells stay ground")


func _test_adapter_reads_named_fields() -> void:
	var snap := {
		"board": {
			"tiles": {
				"1,1": {"elevation": 1.5, "terrain_type": "MUD"},
			},
		},
	}
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(1, 1)), "mud", "nested board.tiles dict")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(1, 1)), 1.5, "nested board.tiles elevation")
	eq(SNAPSHOT_TILES.has_board_data(snap), true, "board.tiles counts as board data")


func _test_adapter_reads_parallel_grids() -> void:
	var elev := []
	var terrain := []
	for y in range(8):
		var erow: Array = []
		var trow: Array = []
		for x in range(8):
			erow.append(1.0 if x == 5 and y == 3 else 0.0)
			trow.append("lava" if x == 6 and y == 3 else "ground")
		elev.append(erow)
		terrain.append(trow)
	var snap := {"elevation": elev, "terrain_type": terrain}
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(5, 3)), 1.0, "parallel elevation grid")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(6, 3)), "lava", "parallel terrain_type grid")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 0)), "ground", "parallel grid other cells stay ground")


func _test_adapter_reads_terrain_cell_lists() -> void:
	var snap := {
		"mud": [Vector2i(1, 1)],
		"water": [{"x": 2, "y": 5}],
		"lava": [[3, 6]],
	}
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(1, 1)), "mud", "mud cell list")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 5)), "water", "water cell list")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(3, 6)), "lava", "lava cell list")


func _test_adapter_normalizes_terrain_aliases() -> void:
	eq(SNAPSHOT_TILES.normalize_terrain("WATER"), "water", "upper-case terrain")
	eq(SNAPSHOT_TILES.normalize_terrain("W"), "water", "letter W is water")
	eq(SNAPSHOT_TILES.normalize_terrain(1), "mud", "int 1 is mud")
	eq(SNAPSHOT_TILES.normalize_terrain(3), "lava", "int 3 is lava")
	eq(SNAPSHOT_TILES.normalize_terrain("nope"), "ground", "unknown terrain falls back to ground")


func _test_walk_dests_follow_legal_intents_only() -> void:
	var legal: Array = [
		{"type": "move", "to": Vector2i(1, 0)},
		{"type": "move", "to": Vector2i(0, 1)},
		{"type": "cast", "spell": "mark_shot", "to": Vector2i(6, 6)},
		{"type": "face", "dir": "N"},
		{"type": "end_turn"},
	]
	var dests: Array[Vector2i] = SNAPSHOT_TILES.walk_dests(legal)
	eq(dests.size(), 2, "walk dests are move intents only")
	eq(dests[0], Vector2i(1, 0), "first walk dest")
	eq(dests[1], Vector2i(0, 1), "second walk dest")
	eq(dests.has(Vector2i(6, 6)), false, "cast dests are not walk highlights")

	_sim.reset_match({"seed": 1, "skip_deploy": true})
	var live: Array = _sim.legal_intents(0)
	var live_dests := SNAPSHOT_TILES.walk_dests(live)
	var counted := 0
	for intent in live:
		if str(intent.get("type", "")) == "move":
			counted += 1
			truthy(live_dests.has(intent["to"]), "live walk dest %s comes from legal_intents" % str(intent["to"]))
	eq(live_dests.size(), counted, "adapter dest count matches legal move intents")
	truthy(live_dests.size() > 0, "skip_deploy Kestrel has sim-legal walks")


func _test_live_snapshot_tiles_from_combatsim() -> void:
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	var snap: Dictionary = _sim.snapshot()
	eq(SNAPSHOT_TILES.has_board_data(snap), true, "live snapshot exposes tiles")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 0)), "ground", "unlisted live tile is ground")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(0, 0)), 0.0, "unlisted live elevation is 0")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 4)), "mud", "demo mud reaches chrome adapter")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 6)), "lava", "demo lava reaches chrome adapter")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(3, 6)), 1.0, "demo +1 step reaches chrome adapter")
	if _sim.has_method("set_tile"):
		_sim.set_tile(Vector2i(2, 1), "mud", 1.0)
		_sim.set_tile(Vector2i(3, 1), "lava", 2.0)
		var painted: Dictionary = _sim.snapshot()
		eq(SNAPSHOT_TILES.terrain_at(painted, Vector2i(2, 1)), "mud", "set_tile mud reaches chrome adapter")
		eq(SNAPSHOT_TILES.elevation_at(painted, Vector2i(2, 1)), 1.0, "set_tile elevation reaches chrome adapter")
		eq(SNAPSHOT_TILES.terrain_at(painted, Vector2i(3, 1)), "lava", "set_tile lava reaches chrome adapter")
		var mud := TILE_SCRIPT.new()
		var rec: Dictionary = SNAPSHOT_TILES.cell_record(painted, Vector2i(2, 1))
		mud.apply_board_data(str(rec["terrain_type"]), float(rec["elevation"]))
		eq(mud.terrain_letter(), "M", "live mud tile paints M")
		eq(mud.elevation_text(), "1", "live mud tile paints elevation 1")
		mud.free()


func _test_demo_map_paints_from_snapshot() -> void:
	_sim.reset_match({"seed": 1})
	var snap: Dictionary = _sim.snapshot()
	eq(str(snap.get("demo_map", "")), "phase_a_fixed", "live chrome snap stamps the demo map")
	var mud := TILE_SCRIPT.new()
	mud.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 4)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(2, 4)))
	eq(mud.terrain_letter(), "M", "Godot paints M on demo mud (2,4)")
	eq(mud.elevation_text(), "0", "demo mud elevation text is 0")
	mud.free()
	var water := TILE_SCRIPT.new()
	water.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(7, 1)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(7, 1)))
	eq(water.terrain_letter(), "W", "Godot paints W on demo water (7,1)")
	water.free()
	var lava := TILE_SCRIPT.new()
	lava.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 6)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(2, 6)))
	eq(lava.terrain_letter(), "L", "Godot paints L on demo lava (2,6)")
	lava.free()
	var ridge := TILE_SCRIPT.new()
	ridge.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 5)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(2, 5)))
	eq(ridge.terrain_letter(), "G", "Godot paints G on the +0.5 ridge")
	eq(ridge.elevation_text(), "0.5", "ridge elevation text is 0.5")
	ridge.free()
	var step := TILE_SCRIPT.new()
	step.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(3, 6)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(3, 6)))
	eq(step.elevation_text(), "1", "adjacent +1 step paints 1")
	step.free()


func _test_live_tiles_paint_terrain_and_elevation() -> void:
	var snap := {
		"tiles": [
			{"pos": Vector2i(0, 0), "terrain_type": "ground", "elevation": 0.0},
			{"pos": Vector2i(1, 0), "terrain_type": "mud", "elevation": 1.0},
			{"pos": Vector2i(2, 0), "terrain_type": "water", "elevation": 0.5},
			{"pos": Vector2i(3, 0), "terrain_type": "lava", "elevation": 2.0},
		],
	}
	var painted := SNAPSHOT_TILES.from_snapshot(snap)
	var mud := TILE_SCRIPT.new()
	mud.grid_position = Vector2i(1, 0)
	mud.apply_board_data(painted[Vector2i(1, 0)]["terrain_type"], painted[Vector2i(1, 0)]["elevation"])
	eq(mud.terrain_type, "mud", "tile stores mud")
	eq(mud.elevation, 1.0, "tile stores elevation 1")
	eq(mud.terrain_letter(), "M", "mud label letter")
	eq(mud.elevation_text(), "1", "whole-level elevation text")

	var water := TILE_SCRIPT.new()
	water.apply_board_data("water", 0.5)
	eq(water.terrain_letter(), "W", "water label letter")
	eq(water.elevation_text(), "0.5", "half-level elevation text")

	var lava := TILE_SCRIPT.new()
	lava.apply_board_data("lava", 2.0)
	eq(lava.terrain_letter(), "L", "lava label letter")
	eq(lava._terrain_color(), Color(0.86, 0.30, 0.12), "lava fill is proto red")

	var ground := TILE_SCRIPT.new()
	ground.grid_position = Vector2i(0, 0)
	ground.apply_board_data("ground", 0.0)
	eq(ground.terrain_letter(), "G", "ground label letter")
	eq(ground.highlight, "", "terrain paint does not invent a walk highlight")
	mud.free()
	water.free()
	lava.free()
	ground.free()


func _test_visual_sort_is_view_only() -> void:
	var low := VISUAL_SORT.tile_z_index(Vector2i(1, 1), 0.0)
	var high := VISUAL_SORT.tile_z_index(Vector2i(1, 1), 2.0)
	truthy(high > low, "higher elevation paints in front at the same cell")
	var south := VISUAL_SORT.tile_z_index(Vector2i(2, 2), 0.0)
	var north := VISUAL_SORT.tile_z_index(Vector2i(0, 0), 2.0)
	truthy(south > north, "iso world Y still dominates a small elevation bump")
	var lifted: Vector2 = VISUAL_SORT.cell_to_local(Vector2i(1, 0), 1.0)
	var flat: Vector2 = VISUAL_SORT.cell_to_local(Vector2i(1, 0), 0.0)
	truthy(lifted.y < flat.y, "view elevation lifts the sprite (smaller Y)")
	eq(VISUAL_SORT.cell_to_local(Vector2i(1, 0), 0.0), Vector2(32, 16), "flat iso matches the live board formula")

	var adapter := FileAccess.get_file_as_string("res://board/snapshot_tiles.gd")
	eq(adapter.contains("z_index"), false, "snapshot adapter does not set z_index")
	eq(adapter.contains("hit_chance"), false, "snapshot adapter does not touch hit bands")
	var sort_src := FileAccess.get_file_as_string("res://board/visual_sort.gd")
	truthy(sort_src.contains("VIEW ONLY"), "visual sort is stamped VIEW ONLY")
	eq(sort_src.contains("hit_chance"), false, "visual sort does not mention hit chance")
	eq(sort_src.contains("legal_intents"), false, "visual sort does not own walk legality")


func _test_hud_legend_and_face_untouched() -> void:
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	var hud = HUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(HUD.terrain_legend_text().contains("G Ground 1"), true, "legend names Ground")
	eq(HUD.terrain_legend_text().contains("Mud 2"), true, "legend names Mud")
	eq(HUD.terrain_legend_text().contains("Water 2"), true, "legend names Water")
	eq(HUD.terrain_legend_text().contains("Lava"), true, "legend names Lava")
	eq(hud._terrain_legend != null, true, "HUD hosts the terrain legend")
	eq(hud._terrain_legend.text, HUD.terrain_legend_text(), "legend label uses the helper")
	eq(hud._face_buttons.size(), 4, "Face N/E/S/W stay present")
	for dir in ["N", "E", "S", "W"]:
		eq(hud._face_buttons.has(dir), true, "Face button %s stays wired" % dir)
		eq((hud._face_buttons[dir] as Button).text, dir, "Face button label is %s" % dir)
	var pad := _face_pad(hud)
	eq(pad != null, true, "Face pad is still a GridContainer")
	eq(pad.columns, 3, "Face pad stays 3 columns")
	eq(pad.get_child(1), hud._face_buttons["N"], "N is still top-center")
	eq(pad.get_child(3), hud._face_buttons["W"], "W is still middle-left")
	eq(pad.get_child(5), hud._face_buttons["E"], "E is still middle-right")
	eq(pad.get_child(7), hud._face_buttons["S"], "S is still bottom-center")
	eq(hud.face_suppressed(), false, "Face stays usable after the terrain legend")
	eq(hud._action_bar is FlowContainer, true, "action bar still wraps")
	hud.free()


func _test_deploy_chrome_untouched() -> void:
	_sim.reset_match({"seed": 1})
	var zones: Dictionary = _sim.snapshot().get("deploy_zones", {})
	eq(_sim.deploy_zone_cells(0).size(), 6, "seat 0 blob stays 6 cells")
	eq(_sim.deploy_zone_cells(1).size(), 6, "seat 1 blob stays 6 cells")
	var p1: Vector2i = _sim.deploy_zone_cells(0)[0]
	var p2: Vector2i = _sim.deploy_zone_cells(1)[0]
	eq(HUD.deploy_seat_for_cell(p1, -1, zones), 0, "P1 blob click still routes to seat 0")
	eq(HUD.deploy_seat_for_cell(p2, -1, zones), 1, "P2 blob click still routes to seat 1")

	var hud = HUD.new()
	hud._build()
	hud.render(_sim.snapshot(), _sim.legal_intents(0))
	eq(hud.deploy_chrome_visible(), true, "Ready chrome still shows in DEPLOYMENT")
	eq(hud.face_suppressed(), true, "Face stays hidden during deploy")
	eq(hud.walk_suppressed(), true, "Walk stays hidden during deploy")
	hud.free()

	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("legal_deploy_cells"), "deploy highlights still bind legal_deploy_cells")
	truthy(view.contains("deploy_zone_cells"), "deploy highlights still bind deploy_zone_cells")
	eq(view.contains("DeploymentManager"), false, "live path still ignores proto DeploymentManager")


func _test_no_height_hit_facing_los() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	var adapter := FileAccess.get_file_as_string("res://board/snapshot_tiles.gd")
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	eq(view.contains("elevation_hit"), false, "board_view does not invent elevation hit")
	eq(view.contains("height_mod"), false, "board_view does not invent a height mod")
	eq(view.contains("los_height"), false, "board_view does not invent height LoS")
	eq(hud_src.contains("elevation_hit"), false, "HUD does not invent elevation hit")
	eq(hud_src.contains("height_mod"), false, "HUD does not invent a height mod")
	eq(adapter.contains("func reachable"), false, "adapter does not run a client reachability search")
	eq(adapter.contains("ElevationCost"), false, "adapter does not own climb costs")
	eq(view.contains("ProtoMoveSim"), false, "board_view does not use ProtoMoveSim")
	eq(view.contains("proto/elevation"), false, "board_view does not import proto/elevation")
	eq(view.contains("aim_hit_preview"), true, "hit % still comes from CombatSim.aim_hit_preview")
	eq(tile_src.contains("zone_p1"), true, "deploy zone highlight colors stay on tiles")
	eq(view.contains("kind == \"move\" and spell_id == \"\""), true, "walk highlights stay off while a spell is selected")


func _test_board_view_wires_adapter() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("SNAPSHOT_TILES"), "board_view preloads the snapshot adapter")
	truthy(view.contains("VISUAL_SORT"), "board_view preloads view-only z-sort")
	truthy(view.contains("from_snapshot"), "board_view applies snapshot tiles")
	truthy(view.contains("walk_dests"), "board_view paints walks from adapter dests")
	truthy(view.contains("apply_board_data"), "board_view applies terrain + elevation to tiles")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	eq(view.contains("randi"), false, "board_view still does not roll")

	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("TERRAIN_LEGEND"), "HUD declares the terrain legend")
	eq(hud_src.contains("Detonate"), false, "elevation HUD patch does not hardcode Detonate")
	eq(hud_src.contains("for dir in [\"N\", \"E\", \"S\", \"W\"]"), false, "Face pad stays a cardinal grid")


func _face_pad(hud: Node) -> GridContainer:
	if hud._face_bar == null:
		return null
	for child in hud._face_bar.get_children():
		if child is GridContainer:
			return child
	return null


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
