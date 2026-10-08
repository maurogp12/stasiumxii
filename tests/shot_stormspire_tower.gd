extends SceneTree

## Phone shots of the Koliseo Stormspire tower after the slate-plinth pass.
## Match zoom is the fitted phone camera. Wide is the pinch zoom-out floor.
## One fighter stands on a raised block (6, 6); the other stands beside the pit (5, 6).
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_stormspire_tower.gd -- <out_dir> --mobile-frame

var _out := "user://"
var _frames := 0
var _hold := 0
var _shot := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("--"):
			_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var cs: GDScript = load("res://scenes/class_select.gd")
	cs.set("hotseat_classes", ["kestrel", "ironjaw"])
	cs.set("hotseat_map_id", "stormspire")
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null or not bool(board.get("_booted")):
		return false
	if _hold == 0:
		_open(board)
		_hold = _frames
		return false
	var age := _frames - _hold
	if _shot == 0:
		if age < 90:
			return false
		_save("koliseo_stormspire_tower.png")
		_zoom_wide(board)
		_shot = 1
		_hold = _frames
		return false
	if age < 24:
		return false
	_save("koliseo_stormspire_wide.png")
	return true


func _open(board: Node) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": "stormspire",
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(6, 6), Vector2i(4, 6)],
	})
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera()
	var pawns: Variant = board.get("pawns_by_seat")
	if typeof(pawns) != TYPE_DICTIONARY:
		return
	for seat in [0, 1]:
		if not pawns.has(seat):
			continue
		var pawn: Node2D = pawns[seat]
		var elev := 0.0
		if board.has_method("_elev_at"):
			elev = float(board.call("_elev_at", pawn.grid_position))
		print("pawn ", seat, " cell ", pawn.grid_position, " elev ", elev, " pos ", pawn.position, " z ", pawn.z_index)


func _zoom_wide(board: Node) -> void:
	var touch: GDScript = load("res://ui/touch_adapter.gd")
	var board_px: Vector2 = board.get("_board_px")
	var view := Vector2(root.size)
	var base := float(touch.board_zoom(board_px.x, board_px.y, view, true))
	var limits: Vector2 = touch.player_zoom_limits(board_px.x, board_px.y, view, true)
	touch.player_zoom_bias = limits.x / maxf(base, 0.01)
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera()
	var cam: Camera2D = board.get("_camera")
	print("wide zoom ", cam.zoom.x if cam != null else -1, " floor ", limits.x)


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(file_name))
	print("saved ", file_name, " ", image.get_size())
