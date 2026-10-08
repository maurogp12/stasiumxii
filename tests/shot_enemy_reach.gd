extends SceneTree

## Hot-seat screenshot at the phone's default camera.
## Same fit BoardView uses when use_mobile_pick() is on: --mobile-frame,
## canvas_items expand from 960×720, window 2400×1080. Do not pan off that fit.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_enemy_reach.gd -- <out_dir> --mobile-frame

var _out := "user://"
var _frames := 0
var _stage := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if str(arg).begins_with("--"):
			continue
		_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out)
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["kestrel", "ironjaw"]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", "crosshaven")
	_apply_phone_frame()
	change_scene_to_file("res://main.tscn")


## What a 2400×1080 phone does: expand the 960×720 canvas so the viewport
## the camera fits is 1600×720, and the resting zoom is ~1.82.
func _apply_phone_frame() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(960, 720)
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
	if _stage == 0 and _frames >= 40:
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
		# The fight's own fit. No extra pan.
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera(false)
		var active := int(sim.snapshot().get("active_seat", 0))
		var foe := 1 if active == 0 else 0
		var preview: Dictionary = sim.foe_reach_preview(foe)
		print("reach seat ", foe, " mp ", preview.get("mp", -1), " cells ", (preview.get("cells", []) as Array).size())
		if board.has_method("show_enemy_reach"):
			board.show_enemy_reach(foe)
		var camera: Camera2D = board.get_node_or_null("BoardCamera")
		if camera != null:
			print("camera zoom ", camera.zoom)
		print("viewport ", root.get_viewport().get_visible_rect().size, " window ", DisplayServer.window_get_size())
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 30:
		var image := root.get_texture().get_image()
		print("frame ", image.get_width(), "x", image.get_height())
		var path := _out.path_join("enemy_reach.png")
		if image.get_width() != 2400 or image.get_height() != 1080:
			image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
			print("resized to 2400x1080")
		image.save_png(path)
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 3:
		return true
	return false
