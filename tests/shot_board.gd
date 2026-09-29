extends SceneTree

## Dev screenshot helper (not a test suite). Opens main.tscn for a hot-seat
## pair, deploys both seats on adjacent legal cells, and saves PNGs.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_board.gd -- <out_dir> <class_a> <class_b> [map_id]

var _out := "user://"
var _frames := 0
var _stage := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var a := args[1] if args.size() > 1 else "gloam"
	var b := args[2] if args.size() > 2 else "bastion"
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = [a, b]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", args[3] if args.size() > 3 else "crosshaven")
	root.size = Vector2i(1600, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames == 30:
		var sim: Node = root.get_node("/root/CombatSim")
		for seat in [0, 1]:
			var cells: Array = sim.legal_deploy_cells(seat)
			if not cells.is_empty():
				print("place ", seat, " ", sim.place_unit(seat, cells[cells.size() / 2]).get("ok"))
			print("ready ", seat, " ", sim.ready_seat(seat).get("ok"))
		var board := current_scene.get_node_or_null("BoardView")
		if board != null and board.has_method("_rebuild_pawns"):
			board._rebuild_pawns()
			board._refresh()
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames == 60:
		root.get_texture().get_image().save_png(_out.path_join("board.png"))
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames == 5:
		return true
	return false
