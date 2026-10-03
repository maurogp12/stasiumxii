extends SceneTree

## Saves a Stormspire before/after frame run for the Thunderwell floor theme.
## godot --path . -s res://tests/pc/capture_thunderwell_look.gd -- --out=/tmp/l4_frames

var _out := "/tmp/l4_frames"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			_out = str(arg).trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	root.get_node("CombatSim").reset_match({
		"seed": 4,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	await _settle(4)
	await _shot(_out.path_join("before.png"))
	board.set_board_theme("thunderwell")
	var layer = board.get_node_or_null("ThunderwellFloor")
	if layer == null:
		push_error("ThunderwellFloor missing")
		quit(1)
		return
	_paint_range(board)
	var frames := 16
	var period := 1.0 / 0.22
	for i in frames:
		layer.preview_time(period * float(i) / float(frames))
		await _settle(1)
		await _shot(_out.path_join("after_%02d.png" % i))
	await _shot(_out.path_join("range_tiles.png"))
	print("THUNDERWELL_CAPTURE %s" % _out)
	quit(0)


func _paint_range(board: Node) -> void:
	var tiles: Dictionary = board.get("tiles")
	for cell in [Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6), Vector2i(7, 6)]:
		(tiles[cell] as Node).set_highlight("move")
	for cell in [Vector2i(8, 7), Vector2i(8, 8), Vector2i(9, 8), Vector2i(7, 8)]:
		(tiles[cell] as Node).set_highlight("range")
	(tiles[Vector2i(7, 7)] as Node).set_highlight("selected")


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame


func _shot(path: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	if image == null or image.get_width() < 2:
		push_error("empty frame %s" % path)
		return
	image.save_png(path)
