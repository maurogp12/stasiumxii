extends SceneTree

## Dev screenshot helper (not a test suite): Bastion casts Snap Wall, frame saved
## mid-slam and settled. xvfb-run godot ... -s res://tests/shot_wall.gd -- <out_dir>

var _out := "user://"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["bastion", "kestrel"]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", "crosshaven")
	root.size = Vector2i(960, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if _frames == 20 and board != null:
		var sim: Node = root.get_node("/root/CombatSim")
		sim.reset_match({"seed": 1, "skip_deploy": true, "flat_board": true, "classes": ["bastion", "kestrel"], "positions": [Vector2i(6, 7), Vector2i(10, 7)], "bastion_aegis": 4})
		board._rebuild_grid(15)
		board._rebuild_pawns()
		board._refresh()
	elif _frames == 40:
		board._submit({"type": "cast", "spell": "snap_wall", "to": Vector2i(7, 7), "seat": 0})
	elif _frames == 46:
		root.get_texture().get_image().save_png(_out.path_join("wall_slam.png"))
	elif _frames == 100:
		root.get_texture().get_image().save_png(_out.path_join("wall_settled.png"))
	elif _frames == 102:
		return true
	return false
