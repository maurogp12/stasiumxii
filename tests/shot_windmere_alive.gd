extends SceneTree

## Phone shots of the three Windmere rooms: match camera, zoomed-out crowd,
## and a 2s Koliseo frame sequence. Not a test suite.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_windmere_alive.gd -- <out_dir> --mobile-frame

var _out := "user://"
var _phase := "boot"
var _frames := 0
var _hold := 0
var _clock := 0.0
var _shot := 0
var _seq := 0
var _zoom_saved := 1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("--"):
			_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var cs: GDScript = load("res://scenes/class_select.gd")
	cs.set("hotseat_classes", ["kestrel", "ironjaw"])
	cs.set("hotseat_map_id", "windmere")
	change_scene_to_file("res://main.tscn")
	_phase = "koliseo"


func _process(delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null:
		return false
	if _phase == "koliseo":
		return _koliseo(board, delta)
	if _phase == "stasis":
		return _stasis(board, delta)
	return true


func _koliseo(board: Node, delta: float) -> bool:
	if not bool(board.get("_booted")):
		return false
	if _hold == 0:
		_open_koliseo(board)
		_hold = _frames
		return false
	var age := _frames - _hold
	if age < 90:
		return false
	if _shot == 0:
		_save(board, "koliseo_windmere_match.png")
		_shot = 1
		_zoom_out(board)
		_clock = 0.0
		return false
	_clock += delta
	if _shot == 1 and _clock >= 0.35:
		_save(board, "koliseo_windmere_wide.png")
		_shot = 2
		_clock = 0.0
		_seq = 0
		return false
	if _shot == 2:
		var step := 2.0 / 12.0
		if _clock >= float(_seq) * step:
			_save(board, "koliseo_windmere_f%02d.png" % _seq)
			_seq += 1
			if _seq >= 12:
				_zoom_restore(board)
				_phase = "stasis"
				_hold = 0
				_shot = 0
				_frames = 0
		return false
	return false


func _stasis(board: Node, delta: float) -> bool:
	var rooms := ["a", "b"]
	if _shot >= rooms.size():
		return true
	if _hold == 0:
		_open_stasis(rooms[_shot])
		_hold = 1
		_frames = 0
		_clock = 0.0
		return false
	if not bool(board.get("_booted")):
		return false
	_clock += delta
	if _frames < 100 or _clock < 1.2:
		return false
	if _hold == 1:
		_save(board, "stasis_windmere_%s_match.png" % rooms[_shot])
		_zoom_out(board)
		_hold = 2
		_clock = 0.0
		return false
	if _clock >= 0.35:
		_save(board, "stasis_windmere_%s_wide.png" % rooms[_shot])
		_zoom_restore(board)
		_shot += 1
		_hold = 0
	return false


func _open_koliseo(board: Node) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": "windmere",
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(2, 2), Vector2i(12, 12)],
	})
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera()


func _open_stasis(letter: String) -> void:
	StasisCatalog.clear_run()
	MobileHub.pending_biome_id = "windmere"
	StasisCatalog.begin("windmere")
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = letter
	change_scene_to_file(StasisCatalog.FIGHT_SCENE)


func _zoom_out(board: Node) -> void:
	var cam: Camera2D = board.get("_camera")
	if cam == null:
		return
	_zoom_saved = cam.zoom.x
	var z := _zoom_saved * 0.58
	cam.zoom = Vector2(z, z)
	if board.has_method("_flush_camera"):
		board._flush_camera()


func _zoom_restore(board: Node) -> void:
	var cam: Camera2D = board.get("_camera")
	if cam == null:
		return
	cam.zoom = Vector2(_zoom_saved, _zoom_saved)
	if board.has_method("_flush_camera"):
		board._flush_camera()


func _save(board: Node, file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(file_name))
	print("saved ", file_name, " ", image.get_size())
