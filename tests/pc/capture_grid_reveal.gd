extends SceneTree

## Before and after the move-tile reveal on Crosshaven.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_grid_reveal.gd -- --out=/tmp/l3_frames

var _out := "/tmp/l3_frames"


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
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	root.get_node("CombatSim").reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	for tile in board.tiles.values():
		tile.set_highlight("")
	await process_frame
	await _shot(_out.path_join("before.png"))
	var painted := 0
	for cell in board.tiles.keys():
		if absi(cell.x - 7) + absi(cell.y - 7) <= 3 and cell != Vector2i(7, 7):
			board.tiles[cell].set_highlight("move")
			painted += 1
	for _i in 20:
		await process_frame
	await _shot(_out.path_join("after.png"))
	print("GRID_REVEAL painted=%d" % painted)
	quit(0 if painted > 0 else 1)


func _shot(path: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("empty frame")
		quit(1)
		return
	image.save_png(path)
