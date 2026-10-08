extends SceneTree

## Phone-resolution combat HUD (20:9, the project's 1600×720 phone canvas).
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_hud_phone.gd -- <out_png> --mobile-frame

var _out := "/tmp/hud_phone.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not str(args[0]).begins_with("-"):
		_out = str(args[0])
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["kestrel", "ironjaw"]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", "crosshaven")
	DisplayServer.window_set_size(Vector2i(1600, 720))
	root.size = Vector2i(1600, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if _frames == 40 and board != null:
		var sim: Node = root.get_node("/root/CombatSim")
		for seat in [0, 1]:
			var cells: Array = sim.legal_deploy_cells(seat)
			if not cells.is_empty():
				sim.place_unit(seat, cells[cells.size() / 2])
		board._rebuild_pawns()
		board._refresh()
	elif _frames == 70:
		var image := root.get_texture().get_image()
		image.save_png(_out)
		print("HUD_SHOT %s %dx%d" % [_out, image.get_width(), image.get_height()])
		return true
	return false
