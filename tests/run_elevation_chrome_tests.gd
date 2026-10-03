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
	_test_cast_dests_follow_legal_intents_only()
	_test_live_snapshot_tiles_from_combatsim()
	_test_demo_map_paints_from_snapshot()
	_test_live_tiles_paint_terrain_and_elevation()
	_test_visual_sort_is_view_only()
	_test_hud_legend_and_face_untouched()
	_test_deploy_chrome_untouched()
	_test_no_height_hit_facing_los()
	_test_board_view_wires_adapter()
	_test_highlights_are_overlays_and_labels_are_debug()
	_test_grid_reveal()
	_test_l3b_grid_pulse_glyphs()


func _test_adapter_defaults_flat_ground() -> void:
	var tiles: Dictionary = SNAPSHOT_TILES.from_snapshot({})
	eq(tiles.size(), 225, "adapter fills a 15x15 when snapshot has no tiles")
	var cell: Dictionary = tiles[Vector2i(3, 4)]
	eq(cell["terrain_type"], "ground", "missing tiles default to ground")
	eq(cell["elevation"], 0, "missing tiles default to elevation 0")
	eq(SNAPSHOT_TILES.has_board_data({}), false, "empty snap has no board data")
	eq(SNAPSHOT_TILES.has_board_data({"tiles": []}), true, "tiles key counts as board data")


func _test_adapter_reads_tile_array() -> void:
	var snap := {
		"tiles": [
			{"pos": Vector2i(1, 2), "elevation": 1, "terrain_type": "mud"},
			{"cell": Vector2i(2, 2), "elevation": 2, "terrain": "water"},
			{"grid_pos": Vector2i(3, 3), "height": 3, "type": "lava"},
		],
	}
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(1, 2)), "mud", "array record terrain_type")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(1, 2)), 1, "array record elevation")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 2)), "water", "array record terrain alias")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(2, 2)), 2, "integer elevation is kept")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(3, 3)), "lava", "array record type=lava")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(3, 3)), 3, "height alias maps to elevation")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 0)), "ground", "unlisted cells stay ground")


func _test_adapter_reads_named_fields() -> void:
	var snap := {
		"board": {
			"tiles": {
				"1,1": {"elevation": 2, "terrain_type": "MUD"},
			},
		},
	}
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(1, 1)), "mud", "nested board.tiles dict")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(1, 1)), 2, "nested board.tiles elevation")
	eq(SNAPSHOT_TILES.has_board_data(snap), true, "board.tiles counts as board data")


func _test_adapter_reads_parallel_grids() -> void:
	var elev := []
	var terrain := []
	for y in range(8):
		var erow: Array = []
		var trow: Array = []
		for x in range(8):
			erow.append(1 if x == 5 and y == 3 else 0)
			trow.append("lava" if x == 6 and y == 3 else "ground")
		elev.append(erow)
		terrain.append(trow)
	var snap := {"elevation": elev, "terrain_type": terrain}
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(5, 3)), 1, "parallel elevation grid")
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


func _test_cast_dests_follow_legal_intents_only() -> void:
	var legal: Array = [
		{"type": "move", "to": Vector2i(2, 0)},
		{"type": "cast", "spell": "advance", "to": Vector2i(4, 3)},
		{"type": "cast", "spell": "advance", "to": Vector2i(3, 4)},
		{"type": "cast", "spell": "strike", "to": Vector2i(5, 5)},
		{"type": "end_turn"},
	]
	var advance: Array[Vector2i] = SNAPSHOT_TILES.cast_dests(legal, "advance")
	eq(advance.size(), 2, "cast_dests keeps only the named spell")
	eq(advance.has(Vector2i(4, 3)), true, "first Advance dest is kept")
	eq(advance.has(Vector2i(3, 4)), true, "second Advance dest is kept")
	eq(advance.has(Vector2i(2, 0)), false, "walk dests are not Advance highlights")
	eq(advance.has(Vector2i(5, 5)), false, "other casts are not Advance highlights")
	eq(SNAPSHOT_TILES.cast_dests(legal, "").is_empty(), true, "empty spell id paints nothing")


func _test_live_snapshot_tiles_from_combatsim() -> void:
	_sim.reset_match({"seed": 1, "skip_deploy": true})
	var snap: Dictionary = _sim.snapshot()
	eq(SNAPSHOT_TILES.has_board_data(snap), true, "live snapshot exposes tiles")
	eq(snap["board_size"], 15, "live chrome snap is 15×15")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 0)), "ground", "Crosshaven (0,0) is ground")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(0, 0)), 0, "Crosshaven (0,0) elevation is the tag")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(1, 1)), "mud", "Crosshaven mud reaches chrome adapter")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 4)), "water", "Crosshaven water reaches chrome adapter")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(7, 4)), 2, "Crosshaven ridge elevation is the tag")
	_sim.reset_match({"seed": 1, "skip_deploy": true, "board_size": 8})
	var crop: Dictionary = _sim.snapshot()
	eq(SNAPSHOT_TILES.terrain_at(crop, Vector2i(2, 0)), "mud", "proto crop mud reaches chrome adapter")
	eq(SNAPSHOT_TILES.terrain_at(crop, Vector2i(4, 1)), "lava", "proto crop lava reaches chrome adapter")
	eq(SNAPSHOT_TILES.elevation_at(crop, Vector2i(0, 0)), _noise_elev(1, Vector2i(0, 0)), "proto crop elevation is seeded noise")
	snap = _sim.snapshot()
	if _sim.has_method("set_tile"):
		_sim.set_tile(Vector2i(7, 3), "mud", 1)
		_sim.set_tile(Vector2i(7, 2), "lava", 0)
		var painted: Dictionary = _sim.snapshot()
		eq(SNAPSHOT_TILES.terrain_at(painted, Vector2i(7, 3)), "mud", "set_tile mud reaches chrome adapter")
		eq(SNAPSHOT_TILES.elevation_at(painted, Vector2i(7, 3)), 1, "set_tile elevation reaches chrome adapter")
		eq(SNAPSHOT_TILES.terrain_at(painted, Vector2i(7, 2)), "lava", "set_tile lava reaches chrome adapter")
		var mud := TILE_SCRIPT.new()
		var rec: Dictionary = SNAPSHOT_TILES.cell_record(painted, Vector2i(7, 3))
		mud.apply_board_data(str(rec["terrain_type"]), rec["elevation"])
		eq(mud.terrain_letter(), "M", "live mud tile paints M")
		eq(mud.elevation_text(), "1", "live mud tile paints elevation 1")
		mud.free()


func _test_demo_map_paints_from_snapshot() -> void:
	_sim.reset_match({"seed": 1})
	var snap: Dictionary = _sim.snapshot()
	eq(str(snap.get("demo_map", "")), "crosshaven_15", "live chrome snap stamps Crosshaven")
	eq(int(snap.get("board_size", 0)), 15, "live chrome board is 15×15")
	var mud := TILE_SCRIPT.new()
	mud.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(1, 1)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(1, 1)))
	eq(mud.terrain_letter(), "M", "Godot paints M on Crosshaven mud (1,1)")
	eq(mud.elevation_text(), "0", "Crosshaven mud elevation text is the tag")
	mud.free()
	var water := TILE_SCRIPT.new()
	water.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 4)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(0, 4)))
	eq(water.terrain_letter(), "W", "Godot paints W on Crosshaven water (0,4)")
	water.free()
	var ridge := TILE_SCRIPT.new()
	ridge.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(7, 4)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(7, 4)))
	eq(ridge.terrain_letter(), "G", "Godot paints G on Crosshaven ground (7,4)")
	eq(ridge.elevation_text(), "2", "Crosshaven ground elevation text is the tag")
	ridge.free()
	_sim.reset_match({"seed": 1, "board_size": 8})
	var crop: Dictionary = _sim.snapshot()
	eq(str(crop.get("demo_map", "")), "phase_a_fixed", "proto 8 chrome snap stamps the crop")
	var lava := TILE_SCRIPT.new()
	lava.apply_board_data(SNAPSHOT_TILES.terrain_at(crop, Vector2i(4, 0)), SNAPSHOT_TILES.elevation_at(crop, Vector2i(4, 0)))
	eq(lava.terrain_letter(), "L", "Godot paints L on proto crop lava (4,0)")
	lava.free()
	var step := TILE_SCRIPT.new()
	step.apply_board_data(SNAPSHOT_TILES.terrain_at(crop, Vector2i(2, 0)), SNAPSHOT_TILES.elevation_at(crop, Vector2i(2, 0)))
	eq(step.terrain_letter(), "M", "Godot paints M on proto crop mud")
	eq(step.elevation_text(), str(_noise_elev(1, Vector2i(2, 0))), "proto crop mud elevation text is seeded noise")
	step.free()


func _test_live_tiles_paint_terrain_and_elevation() -> void:
	var snap := {
		"tiles": [
			{"pos": Vector2i(0, 0), "terrain_type": "ground", "elevation": 0},
			{"pos": Vector2i(1, 0), "terrain_type": "mud", "elevation": 1},
			{"pos": Vector2i(2, 0), "terrain_type": "water", "elevation": 2},
			{"pos": Vector2i(3, 0), "terrain_type": "lava", "elevation": 3},
		],
	}
	var painted := SNAPSHOT_TILES.from_snapshot(snap)
	var mud := TILE_SCRIPT.new()
	mud.grid_position = Vector2i(1, 0)
	mud.apply_board_data(painted[Vector2i(1, 0)]["terrain_type"], painted[Vector2i(1, 0)]["elevation"])
	eq(mud.terrain_type, "mud", "tile stores mud")
	eq(mud.elevation, 1, "tile stores elevation 1")
	eq(mud.terrain_letter(), "M", "mud label letter")
	eq(mud.elevation_text(), "1", "integer elevation text")

	var water := TILE_SCRIPT.new()
	water.apply_board_data("water", 2)
	eq(water.terrain_letter(), "W", "water label letter")
	eq(water.elevation_text(), "2", "integer elevation text for water")

	var lava := TILE_SCRIPT.new()
	lava.apply_board_data("lava", 3)
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


func _test_grid_reveal() -> void:
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(tile_src.contains("Color(0.55, 0.93, 1.0, 0.88)"), "move tiles use the bright fill on every theme")
	truthy(tile_src.contains("Color(0.75, 1.0, 1.0, 1.0)"), "move tiles use the bright rim on every theme")
	eq(tile_src.contains("highlight == \"move\" and _look_floor"), false, "the bright move tile is not limited to one floor")
	truthy(tile_src.contains("set_soft_hover"), "the cell under the pointer can take a soft outline")
	truthy(tile_src.contains("func _paint_glyph"), "zones and deploy cells draw a glyph")
	truthy(view.contains("_set_hover_cell"), "the board tracks the cell under the pointer")
	eq(view.contains("KEY_ALT"), false, "the board does not hardcode Alt; the hold is an input action")
	var tile := TILE_SCRIPT.new() as BoardTile
	tile.highlight = "move"
	eq(tile.overlay_color(), Color(0.45, 0.78, 0.92, BoardTile.HIGHLIGHT_FILL_ALPHA), "overlay_color stays the flat cyan")
	tile.free()


func _test_l3b_grid_pulse_glyphs() -> void:
	var view_src := FileAccess.get_file_as_string("res://board_view.gd")
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	var glyph_src := FileAccess.get_file_as_string("res://board/pc/glyph_decals.gd")
	var proj := FileAccess.get_file_as_string("res://project.godot")
	eq(proj.count("board_show_grid"), 1, "the full grid is one input action")
	truthy(InputMap.has_action("board_show_grid"), "the action is loaded")
	var bindings := InputMap.action_get_events("board_show_grid")
	eq(bindings.size(), 1, "Alt is the one proposed binding, and it can be remapped")
	eq((bindings[0] as InputEventKey).keycode, KEY_ALT, "the proposed default is Alt")
	eq(view_src.contains("KEY_ALT"), false, "board_view does not name the Alt key")
	truthy(view_src.contains("GRID_ACTION"), "the board reads that one action")
	truthy(view_src.contains("is_action_pressed(GRID_ACTION)"), "a press shows the grid")
	truthy(view_src.contains("is_action_released(GRID_ACTION)"), "a release clears the grid")
	truthy(tile_src.contains("GRID_LINE_ALPHA"), "the grid line has its own alpha")
	eq(BoardTile.GRID_LINE_WIDTH <= 1.25, true, "the grid line is thin")
	eq(BoardTile.GRID_LINE_ALPHA < 0.30 and BoardTile.GRID_LINE_ALPHA > 0.05, true, "the grid line is low alpha")
	var view: Node2D = load("res://board_view.gd").new()
	var first := TILE_SCRIPT.new() as BoardTile
	var second := TILE_SCRIPT.new() as BoardTile
	view.tiles[Vector2i(0, 0)] = first
	view.tiles[Vector2i(1, 0)] = second
	var down := InputEventAction.new()
	down.action = "board_show_grid"
	down.pressed = true
	eq(view._grid_hold_state(down), 1, "holding the action asks for the grid")
	view.apply_full_grid(true)
	eq(first.shows_grid_line(), true, "every cell draws a line while the action is held")
	eq(second.shows_grid_line(), true, "the hold covers the whole board")
	var up := InputEventAction.new()
	up.action = "board_show_grid"
	up.pressed = false
	eq(view._grid_hold_state(up), 0, "releasing the action clears the grid")
	view.apply_full_grid(false)
	eq(first.shows_grid_line(), false, "the lines are gone on release")
	eq(second.shows_grid_line(), false, "release clears every cell")
	var other := InputEventAction.new()
	other.action = "ui_cancel"
	other.pressed = true
	eq(view._grid_hold_state(other), -1, "other actions do not toggle the grid")
	view.free()
	first.free()
	second.free()

	eq(BoardTile.MOVE_PULSE_HZ, 0.5, "the move tile breathes at about 0.5 Hz")
	eq(is_equal_approx(BoardTile.MOVE_PULSE_AMP, 0.08), true, "the breathe is about ±8%")
	BoardTile.set_move_pulse_frozen(false)
	BoardTile.set_move_pulse_time(0.0)
	eq(is_equal_approx(BoardTile.move_pulse_scale(), 1.0), true, "the pulse starts at the authored brightness")
	BoardTile.advance_move_pulse(0.5)
	var peak := BoardTile.move_pulse_scale()
	eq(is_equal_approx(peak, 1.08), true, "half a beat later the tile is about 8% brighter")
	var left := TILE_SCRIPT.new() as BoardTile
	var right := TILE_SCRIPT.new() as BoardTile
	eq(is_equal_approx(left.move_pulse_scale(), right.move_pulse_scale()), true, "every move tile shares one phase")
	eq(is_equal_approx(left.move_pulse_scale(), peak), true, "the shared phase is the board clock")
	BoardTile.set_move_pulse_frozen(true)
	BoardTile.advance_move_pulse(1.0)
	eq(is_equal_approx(BoardTile.move_pulse_scale(), peak), true, "the pulse stays put during a walk")
	eq(BoardTile.move_pulse_frozen(), true, "a walk freezes the clock")
	BoardTile.set_move_pulse_frozen(false)
	BoardTile.set_move_pulse_time(1.5)
	eq(is_equal_approx(BoardTile.move_pulse_scale(), 0.92), true, "the other half of the beat is about 8% dimmer")
	BoardTile.set_move_pulse_time(0.0)
	left.free()
	right.free()
	truthy(view_src.contains("set_move_pulse_frozen(_hop_seat >= 0)"), "the board freezes the pulse for the walk")

	eq(tile_src.contains("draw_arc"), false, "the occupied ring is not a line arc")
	eq(tile_src.contains("Vector2(-7, 0)"), false, "the zone mark is not a line cross")
	for id in ["zone", "deploy", "occupied"]:
		var master := load("res://art/pc/look/glyphs/glyph_%s@2x.png" % id) as Texture2D
		var one := load("res://art/pc/look/glyphs/glyph_%s.png" % id) as Texture2D
		truthy(master != null, "%s has a 2x master" % id)
		truthy(one != null, "%s has a 1x paint" % id)
		if master != null:
			eq(master.get_width(), 64, "%s master is 64 wide" % id)
			eq(master.get_height(), 40, "%s master is 40 tall" % id)
		if one != null:
			eq(one.get_width(), 32, "%s 1x is 32 wide" % id)
			eq(one.get_height(), 20, "%s 1x is 20 tall" % id)
	truthy(glyph_src.contains("return [\"zone\", \"deploy\"]"), "a zone cell draws the zone mark and the deploy cell")
	truthy(glyph_src.contains("return [\"occupied\"]"), "an occupied cell draws the ring")
	var zone := (load("res://art/pc/look/glyphs/glyph_zone@2x.png") as Texture2D).get_image()
	var zone_px := zone.get_pixel(32, 20)
	truthy(zone_px.a > 0.4, "the zone mark is painted, not empty")
	truthy(zone_px.b > zone_px.g and zone_px.r > zone_px.g, "the zone mark is purple")
	truthy(zone_px.a < 0.85, "the zone mark stays translucent")
	var ring := (load("res://art/pc/look/glyphs/glyph_occupied@2x.png") as Texture2D).get_image()
	eq(ring.get_pixel(32, 20).a < 0.08, true, "the occupied ring has a hole")
	var ring_px := ring.get_pixel(32, 12)
	truthy(ring_px.a > 0.3 and ring_px.b > ring_px.g, "the occupied ring is purple")
	var glyphs := load("res://board/pc/glyph_decals.gd")
	eq(is_equal_approx(float(glyphs.GLYPH_ALPHA), 0.65), true, "glyphs draw at about 65%")
	eq(is_equal_approx(glyphs.modulate_for("deploy", "zone_p1").a, float(glyphs.GLYPH_ALPHA)), true, "the deploy mark uses that alpha")
	eq(is_equal_approx(glyphs.modulate_for("zone", "zone_p1").a, float(glyphs.GLYPH_ALPHA)), true, "the zone mark uses that alpha")
	eq(is_equal_approx(glyphs.modulate_for("zone", "zone_p2").a, glyphs.modulate_for("deploy", "zone_p2").a), true, "both marks share one alpha on P2")
	eq(is_equal_approx(glyphs.modulate_for("occupied", "occupied").a, float(glyphs.GLYPH_ALPHA)), true, "the occupied ring uses that alpha")
	var held_a: Texture2D = glyphs.texture("zone")
	var held_b: Texture2D = glyphs.texture("zone")
	eq(held_a, held_b, "the zone texture stays referenced after the draw")
	eq(is_equal_approx(BoardTile.DEPLOY_FILL_ALPHA, 0.35), true, "open deploy cells share a 35% fill")
	eq(is_equal_approx(BoardTile.DEPLOY_LOCKED_ALPHA, 0.15), true, "locked deploy cells use a 15% fill")
	eq(BoardTile.DEPLOY_P1, Color(74.0 / 255.0, 143.0 / 255.0, 224.0 / 255.0), "P1 deploy fill is #4A8FE0")
	eq(BoardTile.DEPLOY_P2, Color(224.0 / 255.0, 90.0 / 255.0, 74.0 / 255.0), "P2 deploy fill is #E05A4A")
	truthy(view_src.contains("locked_p1"), "a locked P1 cell keeps the P1 tint")
	truthy(view_src.contains("locked_p2"), "a locked P2 cell keeps the P2 tint")
	_test_deploy_zone_paint()
	for id in ["zone", "deploy", "occupied"]:
		var painted := (load("res://art/pc/look/glyphs/glyph_%s@2x.png" % id) as Texture2D).get_image()
		truthy(_glyph_has_dark_rim(painted), "%s has the dark violet rim" % id)

	var flat := VISUAL_SORT.cell_to_local(Vector2i(7, 6), 0.0)
	var raised := VISUAL_SORT.cell_to_local(Vector2i(7, 6), 2.0)
	eq(is_equal_approx(raised.y, flat.y - 20.0), true, "two height steps lift the cell by 20 px")
	var high := TILE_SCRIPT.new() as BoardTile
	get_root().add_child(high)
	high.position = raised
	high.apply_board_data("ground", 2)
	high.set_highlight("move")
	var overlay := high.get_node("Highlight") as Node2D
	eq(overlay.global_position, high.global_position, "the move tile is drawn on the raised diamond")
	eq(is_equal_approx(overlay.global_position.y, raised.y), true, "the move tile follows the terrain height")
	eq(is_equal_approx(overlay.global_position.y, flat.y), false, "the move tile does not stay on the flat cell")
	high.free()


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


func _test_highlights_are_overlays_and_labels_are_debug() -> void:
	var mud := TILE_SCRIPT.new() as BoardTile
	mud.grid_position = Vector2i(1, 0)
	mud.apply_board_data("mud", 1)
	var mud_fill := Color(0.56, 0.38, 0.20)
	mud.set_highlight("move")
	eq(mud.fill_color(), mud_fill, "reachable highlight leaves the mud fill")
	eq(mud.overlay_color(), Color(0.45, 0.78, 0.92, BoardTile.HIGHLIGHT_FILL_ALPHA), "move overlay keeps the flat cyan")
	eq(mud.overlay_draws_outline(), true, "move overlay draws an outline")
	mud.set_highlight("target")
	eq(mud.fill_color(), mud_fill, "target highlight leaves the mud fill")
	eq(mud.overlay_color(), Color(0.95, 0.55, 0.28, BoardTile.HIGHLIGHT_FILL_ALPHA), "target overlay keeps the flat orange")
	mud.set_highlight("range")
	eq(mud.overlay_color(), Color(0.95, 0.78, 0.32, BoardTile.HIGHLIGHT_FILL_ALPHA), "range overlay keeps the flat gold")
	mud.set_selected(true)
	eq(mud.fill_color(), mud_fill, "selected highlight leaves the mud fill")
	eq(mud.overlay_color(), Color(1.0, 0.85, 0.2, BoardTile.HIGHLIGHT_FILL_ALPHA), "selected overlay keeps the flat yellow")
	mud.set_highlight("blocked")
	eq(mud.overlay_color(), Color(0.14, 0.14, 0.16, BoardTile.HIGHLIGHT_FILL_ALPHA), "blocked overlay stays put when the tile is also selected")
	mud.set_selected(false)
	mud.set_highlight("")
	eq(mud.overlay_color().a, 0.0, "an idle tile has no highlight overlay")
	eq(mud.overlay_draws_outline(), false, "an idle tile has no highlight outline")
	mud.free()

	var tile := TILE_SCRIPT.new() as BoardTile
	tile.grid_position = Vector2i(2, 3)
	tile.apply_board_data("ground", 3)
	tile.position = VISUAL_SORT.cell_to_local(Vector2i(2, 3), 3.0)
	tile.z_index = VISUAL_SORT.tile_z_index(Vector2i(2, 3), 3.0)
	get_root().add_child(tile)
	tile.set_highlight("move")
	var overlay := tile.get_node("Highlight") as Node2D
	eq(overlay != null, true, "highlight is a child layer")
	eq(overlay.z_index, BoardTile.OVERLAY_Z, "overlay sits one step above its tile")
	eq(overlay.z_as_relative, true, "overlay z stays relative so elevation sort still applies")
	eq(overlay.position, Vector2.ZERO, "overlay draws in the tile's local diamond")
	eq(overlay.global_position, tile.global_position, "an elevated tile carries its highlight")
	eq(BoardTile.OVERLAY_Z < VISUAL_SORT.UNIT_Z_BIAS, true, "overlay sorts under the seat ring and pawn")
	eq(tile.z_index + overlay.z_index < VISUAL_SORT.unit_z_index(Vector2i(2, 3), 3.0), true, "this elevated highlight stays under its pawn")
	var north_overlay := VISUAL_SORT.tile_z_index(Vector2i(0, 0), 2.0) + BoardTile.OVERLAY_Z
	var south_tile := VISUAL_SORT.tile_z_index(Vector2i(2, 2), 0.0)
	eq(north_overlay < south_tile, true, "an elevated highlight stays behind the tile in front")
	eq(tile.fill_color(), Color(0.48, 0.64, 0.34), "elevated ground keeps its checker fill under the overlay")
	tile.free()

	var proj := FileAccess.get_file_as_string("res://project.godot")
	truthy(proj.contains("debug/show_tile_labels=false"), "project setting stasium/debug/show_tile_labels defaults off")
	ProjectSettings.set_setting(BoardTile.LABEL_SETTING, false)
	eq(BoardTile.tile_labels_visible(), false, "tile labels are hidden by default")
	var labeled := TILE_SCRIPT.new() as BoardTile
	labeled.apply_board_data("ground", 0)
	eq(labeled.drawn_label(), "", "a ground tile does not draw G 0")
	eq(labeled.terrain_letter(), "G", "the letter helper stays available for the debug label")
	eq(labeled.elevation_text(), "0", "the elevation helper stays available for the debug label")
	ProjectSettings.set_setting(BoardTile.LABEL_SETTING, true)
	eq(labeled.drawn_label(), "G 0", "the debug setting shows the terrain label")
	eq(OS.is_debug_build(), true, "this suite runs in a debug build so F3 is live")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_F3
	eq(BoardTile.consume_debug_label_key(key), true, "F3 toggles tile labels in a debug build")
	eq(BoardTile.tile_labels_visible(), false, "F3 hides the labels again")
	eq(labeled.drawn_label(), "", "F3 clears the drawn label")
	key.echo = true
	eq(BoardTile.consume_debug_label_key(key), false, "a held F3 does not toggle twice")
	eq(BoardTile.tile_labels_visible(), false, "echo leaves the labels hidden")
	var other := InputEventKey.new()
	other.pressed = true
	other.keycode = KEY_F4
	eq(BoardTile.consume_debug_label_key(other), false, "other keys do not toggle tile labels")
	ProjectSettings.set_setting(BoardTile.LABEL_SETTING, false)
	labeled.free()

	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	var draw_start := tile_src.find("func _draw(")
	var draw_end := tile_src.find("func apply_board_data")
	var draw_src := tile_src.substr(draw_start, draw_end - draw_start)
	truthy(draw_src.contains("fill_color()"), "the base diamond uses the terrain fill")
	eq(draw_src.contains("\"move\""), false, "reachable highlight is not painted in the base draw")
	eq(draw_src.contains("\"target\""), false, "target highlight is not painted in the base draw")
	eq(draw_src.contains("\"selected\""), false, "selected highlight is not painted in the base draw")
	truthy(tile_src.contains("func paint_highlight_overlay"), "highlights draw on a separate overlay")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("consume_debug_label_key"), "the board toggles tile labels from the debug key")
	eq(view.contains("hp"), false, "board_view still does not mention hp")


func _noise_elev(seed: int, cell: Vector2i) -> int:
	return int(load("res://backend/match_flow.gd").generate_noise_elevations(seed)[cell])


func _face_pad(hud: Node) -> GridContainer:
	if hud._face_bar == null:
		return null
	for child in hud._face_bar.get_children():
		if child is GridContainer:
			return child
	return null


## Headless. The framebuffer check lives in tests/pc/capture_l3b.gd, which needs a display.
## This one composites the tile's own paint: team tint over the cell base, glyph at 0.65.
func _test_deploy_zone_paint() -> void:
	var glyphs: GDScript = load("res://board/pc/glyph_decals.gd")
	var floor_script: GDScript = load("res://board/pc/thunderwell_floor.gd")
	var zone_tex := glyphs.texture("zone") as Texture2D
	var deploy_tex := glyphs.texture("deploy") as Texture2D
	truthy(zone_tex != null and deploy_tex != null, "zone and deploy glyphs load for the colour check")
	if zone_tex == null or deploy_tex == null:
		return
	var zone_img := zone_tex.get_image()
	var deploy_img := deploy_tex.get_image()
	truthy(zone_img != null and deploy_img != null, "glyph images are readable without a viewport")
	if zone_img == null or deploy_img == null:
		return
	BoardTile.set_move_pulse_time(0.0)
	var mover := TILE_SCRIPT.new() as BoardTile
	mover.highlight = "move"
	var move_fill := mover.highlight_fill_color()
	mover.free()
	var cap := _lum(Color(move_fill.r, move_fill.g, move_fill.b, 1.0))
	truthy(cap > 0.80 and cap < 0.98, "the move fill cap is the painted cyan, not white")
	var floor_path := str(floor_script.resolve_slot("floor_tiles"))
	var floor_tex := load(floor_path) as Texture2D
	var floor_params: Dictionary = floor_script.load_params()
	truthy(floor_tex != null, "the thunderwell plate is readable without a viewport")
	_sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"classes": ["kestrel", "ironjaw"],
	})
	var snap: Dictionary = _sim.snapshot()
	_assert_deploy_paint(snap, glyphs, zone_img, deploy_img, cap, false, floor_tex, floor_params, floor_script)
	_assert_deploy_paint(snap, glyphs, zone_img, deploy_img, cap, true, floor_tex, floor_params, floor_script)


func _assert_deploy_paint(snap: Dictionary, glyphs: GDScript, zone_img: Image, deploy_img: Image, cap: float, thunderwell: bool, floor_tex: Texture2D, floor_params: Dictionary, floor_script: GDScript) -> void:
	var tag := "thunderwell" if thunderwell else "crosshaven"
	var legal0: Array[Vector2i] = _sim.legal_deploy_cells(0)
	var legal1: Array[Vector2i] = _sim.legal_deploy_cells(1)
	var tiles: Dictionary = {}
	var kinds: Dictionary = {}
	for seat in [0, 1]:
		var legal: Array[Vector2i] = legal0 if seat == 0 else legal1
		for cell in _sim.deploy_zone_cells(seat):
			var tile := TILE_SCRIPT.new() as BoardTile
			tile.grid_position = cell
			tile.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, cell), SNAPSHOT_TILES.elevation_at(snap, cell))
			if thunderwell and floor_tex != null:
				_wear_thunderwell(tile, cell, floor_tex, floor_params, floor_script)
			var open_kind := "zone_p1" if seat == 0 else "zone_p2"
			var locked_kind := "locked_p1" if seat == 0 else "locked_p2"
			tile.highlight = open_kind if legal.has(cell) else locked_kind
			tiles[cell] = tile
			kinds[cell] = tile.highlight
	_check_deploy_phase(tag, "open", tiles, kinds, glyphs, zone_img, deploy_img, cap)
	for cell in tiles.keys():
		var locked_tile: BoardTile = tiles[cell]
		var locked_kind := "locked_p2" if str(kinds[cell]).ends_with("p2") else "locked_p1"
		locked_tile.highlight = locked_kind
		kinds[cell] = locked_kind
	_check_deploy_phase(tag, "locked", tiles, kinds, glyphs, zone_img, deploy_img, cap)
	for cell in tiles.keys():
		(tiles[cell] as BoardTile).free()


func _check_deploy_phase(tag: String, phase: String, tiles: Dictionary, kinds: Dictionary, glyphs: GDScript, zone_img: Image, deploy_img: Image, cap: float) -> void:
	for cell in tiles.keys():
		var tile: BoardTile = tiles[cell]
		var kind := str(kinds[cell])
		var fill := tile.highlight_fill_color()
		eq(fill, _wanted_deploy_fill(kind), "%s %s %s paints %s" % [tag, phase, cell, kind])
		truthy(_lum(Color(fill.r, fill.g, fill.b, 1.0)) < 0.75, "%s %s %s fill is not white" % [tag, phase, cell])
		var with_glyph := kind.begins_with("zone_")
		var peak := _deploy_peak(tile.cell_base_color(), fill, zone_img, deploy_img, glyphs, with_glyph)
		truthy(peak < cap, "%s %s %s stays under the move fill (%.3f < %.3f)" % [tag, phase, cell, peak, cap])
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = (cell as Vector2i) + step
			if not tiles.has(other) or str(kinds[other]) != kind:
				continue
			var neighbour: BoardTile = tiles[other]
			eq(neighbour.highlight_fill_color(), fill, "%s %s %s and %s share one fill" % [tag, phase, cell, other])
			var here := _deploy_final(tile.cell_base_color(), fill, zone_img, deploy_img, glyphs, with_glyph)
			var swapped := _deploy_final(tile.cell_base_color(), neighbour.highlight_fill_color(), zone_img, deploy_img, glyphs, with_glyph)
			truthy(_colors_match(here, swapped), "%s %s %s matches %s" % [tag, phase, cell, other])


func _wanted_deploy_fill(kind: String) -> Color:
	var base := BoardTile.DEPLOY_P1
	if kind.ends_with("p2"):
		base = BoardTile.DEPLOY_P2
	if kind.begins_with("locked"):
		return Color(base.r * BoardTile.DEPLOY_LOCKED_SCALE, base.g * BoardTile.DEPLOY_LOCKED_SCALE, base.b * BoardTile.DEPLOY_LOCKED_SCALE, BoardTile.DEPLOY_LOCKED_ALPHA)
	return Color(base.r, base.g, base.b, BoardTile.DEPLOY_FILL_ALPHA)


func _wear_thunderwell(tile: BoardTile, cell: Vector2i, floor_tex: Texture2D, params: Dictionary, floor_script: GDScript) -> void:
	var count: int = floor_script.strip_slots(floor_tex.get_width(), floor_tex.get_height())
	var routes: Array = floor_script.board_routes(params)
	var plan: Dictionary = floor_script.tile_plan(cell, routes)
	var index := int(plan.get("slot", 0))
	var slice_w := float(floor_tex.get_width()) / float(maxi(count, 1))
	var atlas := AtlasTexture.new()
	atlas.atlas = floor_tex
	atlas.region = Rect2(slice_w * float(index), 0.0, slice_w, float(floor_tex.get_height()))
	var grade_raw: Array = params.get("floor_grade", [1.0, 1.0, 1.0])
	tile.set_look_grade(Color(float(grade_raw[0]), float(grade_raw[1]), float(grade_raw[2])))
	tile.set_look_lift(float(params.get("floor_lift", 1.0)))
	tile.set_look_floor(atlas)


func _deploy_final(base: Color, tint: Color, zone_img: Image, deploy_img: Image, glyphs: GDScript, with_glyph: bool) -> Color:
	var field := _over(Color(base.r, base.g, base.b, 1.0), tint)
	if not with_glyph:
		return field
	var alpha := float(glyphs.GLYPH_ALPHA)
	var zone_px := zone_img.get_pixel(int(zone_img.get_width() / 2), int(zone_img.get_height() / 2))
	var deploy_px := deploy_img.get_pixel(int(deploy_img.get_width() / 2), int(deploy_img.get_height() / 2))
	field = _over(field, Color(zone_px.r, zone_px.g, zone_px.b, zone_px.a * alpha))
	return _over(field, Color(deploy_px.r, deploy_px.g, deploy_px.b, deploy_px.a * alpha))


func _deploy_peak(base: Color, tint: Color, zone_img: Image, deploy_img: Image, glyphs: GDScript, with_glyph: bool) -> float:
	var field := _over(Color(base.r, base.g, base.b, 1.0), tint)
	var peak := _lum(field)
	if not with_glyph:
		return peak
	var alpha := float(glyphs.GLYPH_ALPHA)
	var height := mini(zone_img.get_height(), deploy_img.get_height())
	var width := mini(zone_img.get_width(), deploy_img.get_width())
	for y in height:
		for x in width:
			var zone_px := zone_img.get_pixel(x, y)
			var deploy_px := deploy_img.get_pixel(x, y)
			var stacked := _over(field, Color(zone_px.r, zone_px.g, zone_px.b, zone_px.a * alpha))
			stacked = _over(stacked, Color(deploy_px.r, deploy_px.g, deploy_px.b, deploy_px.a * alpha))
			peak = maxf(peak, _lum(stacked))
	return peak


func _over(dst: Color, src: Color) -> Color:
	var out_a := src.a + dst.a * (1.0 - src.a)
	if out_a <= 0.0001:
		return Color(0, 0, 0, 0)
	return Color(
		(src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / out_a,
		(src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / out_a,
		(src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / out_a,
		out_a
	)


func _colors_match(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 and absf(a.b - b.b) < 0.001 and absf(a.a - b.a) < 0.001


func _lum(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


func _glyph_has_dark_rim(image: Image) -> bool:
	var want := Color(58.0 / 255.0, 31.0 / 255.0, 85.0 / 255.0)
	for y in image.get_height():
		for x in image.get_width():
			var px := image.get_pixel(x, y)
			if px.a < 0.30 or px.a > 0.70:
				continue
			if absf(px.r - want.r) < 0.08 and absf(px.g - want.g) < 0.08 and absf(px.b - want.b) < 0.10:
				return true
	return false


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
