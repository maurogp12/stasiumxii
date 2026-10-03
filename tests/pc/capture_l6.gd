extends SceneTree

## L6 action-bar stills. Default frame is 1280×720. Pass --size=1920x1080
## for the wide frame. --phone shoots the phone HUD as the before plate.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l6.gd -- --out=/tmp/l6_frames --size=1280x720

var _out := "/tmp/l6_frames"
var _size := Vector2i(1280, 720)
var _phone := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
		elif text == "--phone":
			_phone = true
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	if _phone:
		CombatHUD.set_pc_chrome_override(0)
	else:
		CombatHUD.set_pc_chrome_override(1)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	await process_frame
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	_boot(sim, board, 80)
	board.set_board_theme("")
	for _i in 20:
		await process_frame
	await _shot(_out.path_join("bar.png"))
	_boot(sim, board, 16)
	for _i in 12:
		await process_frame
	await _shot(_out.path_join("low.png"))
	var image := root.get_viewport().get_texture().get_image()
	var got := image.get_size() if image != null else Vector2i.ZERO
	print("L6_SHOT %s size=%s frame=%s" % [_out.path_join("bar.png"), str(_size), str(got)])
	quit(0)


func _boot(sim: Node, board: Node2D, hp: int) -> void:
	var setup := {
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(7, 7), Vector2i(8, 7)],
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
	}
	if hp < 80:
		setup["kestrel_hp"] = hp
	sim.reset_match(setup)
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()


func _shot(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("empty frame")
		quit(1)
		return
	image.save_png(path)
