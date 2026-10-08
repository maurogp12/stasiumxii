extends SceneTree

## Phone shots of the Slagcrown lava-lake crust on the water cells.
## Match zoom is the fitted phone camera (steam over the pools). Wide is the
## pinch zoom-out floor. Dungeon room A uses the same ring.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_slagcrown_water.gd -- <out_dir> --mobile-frame

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
	cs.set("hotseat_map_id", "slagcrown")
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null or not bool(board.get("_booted")):
		return false
	if _shot < 2 and _hold == 0:
		_open(board)
		_hold = _frames
		return false
	var age := _frames - _hold
	if _shot == 0:
		if age < 90:
			return false
		_save("koliseo_slagcrown_pools.png")
		_zoom_wide(board)
		_shot = 1
		_hold = _frames
		return false
	if _shot == 1:
		if age < 24:
			return false
		_save("koliseo_slagcrown_wide.png")
		_shot = 2
		_hold = 0
		_frames = 0
		return false
	return _stasis(board)


func _stasis(board: Node) -> bool:
	if _hold == 0:
		StasisCatalog.clear_run()
		MobileHub.pending_biome_id = "slagcrown"
		StasisCatalog.begin("slagcrown")
		StasisCatalog.class_id = "kestrel"
		StasisCatalog.room = "a"
		change_scene_to_file(StasisCatalog.FIGHT_SCENE)
		_hold = 1
		_frames = 0
		return false
	if _frames < 80:
		return false
	_save("stasis_slagcrown_a.png")
	return true


func _open(board: Node) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	# Ground beside the boiling cluster: (2, 9) is the step above (2, 10),
	# (4, 12) is the stone under (4, 11). Neither cell is lava.
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": "slagcrown",
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(2, 9), Vector2i(4, 12)],
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
		print("pawn ", seat, " cell ", pawn.grid_position, " pos ", pawn.position, " z ", pawn.z_index)


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
