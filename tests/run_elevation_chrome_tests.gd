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


func _test_adapter_defaults_flat_ground() -> void:
	var tiles: Dictionary = SNAPSHOT_TILES.from_snapshot({})
	eq(tiles.size(), 64, "adapter fills an 8x8 when snapshot has no tiles")
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
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(0, 0)), "ground", "crop (0,0) is ground")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(0, 0)), _noise_elev(1, Vector2i(0, 0)), "crop (0,0) elevation is seeded noise")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 0)), "mud", "crop mud reaches chrome adapter")
	eq(SNAPSHOT_TILES.terrain_at(snap, Vector2i(4, 1)), "lava", "crop lava reaches chrome adapter")
	eq(SNAPSHOT_TILES.elevation_at(snap, Vector2i(6, 5)), _noise_elev(1, Vector2i(6, 5)), "ridge elevation is seeded noise")
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
	eq(str(snap.get("demo_map", "")), "phase_a_fixed", "live chrome snap stamps the demo map")
	var mud := TILE_SCRIPT.new()
	mud.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(2, 0)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(2, 0)))
	eq(mud.terrain_letter(), "M", "Godot paints M on crop mud (2,0)")
	eq(mud.elevation_text(), str(_noise_elev(1, Vector2i(2, 0))), "crop mud elevation text is seeded noise")
	mud.free()
	var water := TILE_SCRIPT.new()
	water.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(3, 0)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(3, 0)))
	eq(water.terrain_letter(), "W", "Godot paints W on crop water (3,0)")
	water.free()
	var lava := TILE_SCRIPT.new()
	lava.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(4, 0)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(4, 0)))
	eq(lava.terrain_letter(), "L", "Godot paints L on crop lava (4,0)")
	lava.free()
	var ridge := TILE_SCRIPT.new()
	ridge.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(6, 5)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(6, 5)))
	eq(ridge.terrain_letter(), "G", "Godot paints G on the crop Ground cell")
	eq(ridge.elevation_text(), str(_noise_elev(1, Vector2i(6, 5))), "Ground elevation text is seeded noise")
	ridge.free()
	var step := TILE_SCRIPT.new()
	step.apply_board_data(SNAPSHOT_TILES.terrain_at(snap, Vector2i(5, 6)), SNAPSHOT_TILES.elevation_at(snap, Vector2i(5, 6)))
	eq(step.elevation_text(), str(_noise_elev(1, Vector2i(5, 6))), "adjacent cell paints seeded noise z")
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
