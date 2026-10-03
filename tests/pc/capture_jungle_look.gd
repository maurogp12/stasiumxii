extends SceneTree

## Saves a Crosshaven before/after frame run for the jungle backdrop.
## godot --path . -s res://tests/pc/capture_jungle_look.gd -- --out=/tmp/l2_frames

var _out := "/tmp/l2_frames"


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
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	var layer = board.get_node_or_null("JungleBackdrop")
	if layer == null:
		push_error("JungleBackdrop missing")
		quit(1)
		return
	layer.set_enabled(false)
	await _settle(4)
	await _shot(_out.path_join("before.png"))
	layer.set_enabled(true)
	# One full sway cycle so the clip loops.
	var frames := 16
	var period := TAU / 0.9
	for i in frames:
		layer.preview_time(period * float(i) / float(frames))
		await _settle(1)
		await _shot(_out.path_join("after_%02d.png" % i))
	print("JUNGLE_CAPTURE %s" % _out)
	quit(0)


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(path)
