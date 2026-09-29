extends SceneTree

## Dev screenshot helper (not a test suite): phone frame at default zoom,
## then fully zoomed out. xvfb-run godot ... -s res://tests/shot_zoom.gd -- <out_dir> --mobile-frame

var _out := "user://"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["kestrel", "bastion"]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", "brinewake")
	root.size = Vector2i(1600, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if _frames == 30 and board != null:
		var sim: Node = root.get_node("/root/CombatSim")
		for seat in [0, 1]:
			var cells: Array = sim.legal_deploy_cells(seat)
			if not cells.is_empty():
				sim.place_unit(seat, cells[cells.size() / 2])
			sim.ready_seat(seat)
		board._rebuild_pawns()
		board._refresh()
	elif _frames == 90:
		root.get_texture().get_image().save_png(_out.path_join("zoom_default.png"))
		for _i in 12:
			board._on_zoom_step(-1)
	elif _frames == 120:
		root.get_texture().get_image().save_png(_out.path_join("zoom_out.png"))
	elif _frames == 125:
		return true
	return false
