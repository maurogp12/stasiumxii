extends SceneTree

## Phone-size online lobby (class picked, Advanced closed, Play Online visible).
## Does not press Play Online, so it never dials a server.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_online_join.gd -- <out_png>

var _out := "/opt/cursor/artifacts/online_lobby_phone.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not str(args[0]).begins_with("-"):
		_out = str(args[0])
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://scenes/class_select.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var picker := current_scene
	if _frames == 20 and picker != null and picker.has_method("choose_mode"):
		picker.choose_mode("online")
		picker.pick_class("gloam")
	elif _frames == 40:
		var image := root.get_texture().get_image()
		image.save_png(_out)
		print("ONLINE_SHOT %s %dx%d" % [_out, image.get_width(), image.get_height()])
		return true
	return false
