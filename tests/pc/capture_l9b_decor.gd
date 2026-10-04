extends SceneTree

## Fit-camera Crosshaven still for the v1 decor pass. Shipped light grade, HUD on.
## Leaves are frozen at rest so the frame can sit next to mock v1.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l9b_decor.gd -- --out=/tmp/l9b --size=1280x720 --name=game_1280

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")

var _out := "/tmp/l9b_decor"
var _size := Vector2i(1280, 720)
var _name := "game"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
		elif text.begins_with("--name="):
			_name = text.trim_prefix("--name=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	LIGHT.set_suppressed(false)
	LIGHT.set_outdoor_preset(LIGHT.SHIPPED_OUTDOOR_PRESET)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	DisplayServer.window_set_size(_size)
	await process_frame
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match(PAIR.args("crosshaven"))
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	var jungle = board.get_node_or_null("JungleBackdrop")
	_freeze(jungle)
	for _i in 8:
		await process_frame
		_freeze(jungle)
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	var path := _out.path_join(_name + ".png")
	image.save_png(path)
	var cam := board.get_node("BoardCamera") as Camera2D
	print("L9B_SHOT %s %dx%d zoom=%.4f" % [path, image.get_width(), image.get_height(), cam.zoom.x])
	HUD.set_pc_chrome_override(-1)
	main.free()
	quit(0)


func _freeze(jungle: Node) -> void:
	if jungle != null and jungle.has_method("preview_time"):
		jungle.preview_time(0.0)
		jungle.layout()
