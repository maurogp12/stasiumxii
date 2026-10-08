extends SceneTree

## Hot-seat screenshot: deploy, ready, then tap the enemy with no spell armed.
## The board paints that fighter's next-turn reach and an "MP n" label.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_enemy_reach.gd -- <out_dir>

var _out := "user://"
var _frames := 0
var _stage := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["kestrel", "ironjaw"]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", "crosshaven")
	_force_frame()
	change_scene_to_file("res://main.tscn")


func _force_frame() -> void:
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)


func _inset_cell(cells: Array) -> Vector2i:
	var best: Vector2i = cells[0]
	var best_score := -1
	for item in cells:
		var cell: Vector2i = item
		var score := mini(mini(cell.x, cell.y), mini(14 - cell.x, 14 - cell.y))
		if score > best_score:
			best_score = score
			best = cell
	return best


func _process(_delta: float) -> bool:
	_frames += 1
	_force_frame()
	if _stage == 0 and _frames >= 30:
		var sim: Node = root.get_node("/root/CombatSim")
		for seat in [0, 1]:
			var cells: Array = sim.legal_deploy_cells(seat)
			if cells.is_empty():
				print("no deploy cells for ", seat)
				return true
			var cell: Vector2i = _inset_cell(cells)
			print("place ", seat, " ", cell, " ", sim.place_unit(seat, cell).get("ok"))
			print("ready ", seat, " ", sim.ready_seat(seat).get("ok"))
		var board := current_scene.get_node_or_null("BoardView")
		if board == null:
			print("no BoardView")
			return true
		if board.has_method("_rebuild_pawns"):
			board._rebuild_pawns()
			board._refresh()
		var active := int(sim.snapshot().get("active_seat", 0))
		var foe := 1 if active == 0 else 0
		var preview: Dictionary = sim.foe_reach_preview(foe)
		print("reach seat ", foe, " mp ", preview.get("mp", -1), " cells ", (preview.get("cells", []) as Array).size())
		if board.has_method("show_enemy_reach"):
			board.show_enemy_reach(foe)
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera(false)
		if board.has_method("_center_on_cell"):
			var foe_unit := {}
			for unit in sim.snapshot().get("units", []):
				if int(unit.get("seat", -1)) == foe:
					foe_unit = unit
			var stand: Variant = foe_unit.get("pos", null)
			if stand is Vector2i:
				board._center_on_cell(stand)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 20:
		var image := root.get_texture().get_image()
		print("frame ", image.get_width(), "x", image.get_height())
		image.save_png(_out.path_join("enemy_reach.png"))
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 3:
		return true
	return false
