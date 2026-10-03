extends SceneTree

## L3b stills: rest, full grid, pulsed move tiles, elevated move tiles, glyph decals.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l3b.gd -- --out=/tmp/l3b_frames

var _out := "/tmp/l3b_frames"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			_out = str(arg).trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	_clear_highlights(board)
	board.apply_full_grid(false)
	await process_frame
	await _shot(_out.path_join("before.png"))
	board.apply_full_grid(true)
	await process_frame
	await _shot(_out.path_join("grid.png"))
	board.apply_full_grid(false)
	var painted := 0
	for cell in board.tiles.keys():
		if absi(cell.x - 7) + absi(cell.y - 7) <= 3 and cell != Vector2i(7, 7):
			board.tiles[cell].set_highlight("move")
			painted += 1
	for _i in 20:
		await process_frame
	BoardTile.set_move_pulse_time(0.48)
	await _shot(_out.path_join("move.png"))
	print("L3B_MOVE painted=%d pulse=%.3f" % [painted, BoardTile.move_pulse_scale()])

	sim.reset_match({
		"seed": 3,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	_clear_highlights(board)
	var heights := {
		0: [Vector2i(5, 6), Vector2i(9, 6), Vector2i(6, 9)],
		1: [Vector2i(6, 6), Vector2i(8, 6), Vector2i(7, 5)],
		2: [Vector2i(7, 6), Vector2i(6, 7), Vector2i(8, 7), Vector2i(7, 8)],
	}
	var lifted := 0
	for elev in heights.keys():
		for cell in heights[elev]:
			var tile: BoardTile = board.tiles[cell]
			if tile == null:
				continue
			tile.set_highlight("move")
			lifted += 1
			print("L3B_HEIGHT cell=%s elev=%s y=%.1f" % [cell, tile.elevation, tile.position.y])
	for _i in 20:
		await process_frame
	BoardTile.set_move_pulse_time(0.0)
	await _shot(_out.path_join("heights.png"))
	print("L3B_HEIGHTS painted=%d" % lifted)

	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	var legal: Array = sim.legal_deploy_cells(0)
	var placed := Vector2i(-1, -1)
	if not legal.is_empty():
		placed = legal[0]
		print("L3B_PLACE %s" % sim.place_unit(0, placed))
	board._refresh()
	for _i in 20:
		await process_frame
	await _shot(_out.path_join("glyphs.png"))
	print("L3B_GLYPHS placed=%s" % placed)
	quit(0 if painted > 0 and lifted > 0 else 1)


func _clear_highlights(board: Node2D) -> void:
	for tile in board.tiles.values():
		tile.set_highlight("")


func _shot(path: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("empty frame")
		quit(1)
		return
	image.save_png(path)
