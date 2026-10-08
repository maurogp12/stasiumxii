extends SceneTree

## Phone shots: Windmere Koliseo (crowd) and the dungeon crypt on rooms A/B.
## Also a few aspect ratios, to check the crypt does not gap or stretch.
## Not a test suite.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_windmere_alive.gd -- <out_dir> --mobile-frame

const WIDE_ZOOM := 1525.0 / 960.0
const ASPECTS := [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(2400, 1200)]

var _out := "user://"
var _phase := "boot"
var _frames := 0
var _hold := 0
var _clock := 0.0
var _shot := 0
var _aspect := 0
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
	if _phase == "aspects":
		return _aspects(board, delta)
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
		_phase = "stasis"
		_hold = 0
		_shot = 0
		_frames = 0
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
		if rooms[_shot] == "a":
			_set_zoom(board, WIDE_ZOOM)
			_hold = 2
			_clock = 0.0
			return false
		_shot += 1
		_hold = 0
		if _shot >= rooms.size():
			_phase = "aspects"
			_hold = 0
			_aspect = 0
			_frames = 0
		return false
	if _clock >= 0.35:
		_save(board, "stasis_windmere_a_wide.png")
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


func _aspects(board: Node, delta: float) -> bool:
	if _aspect >= ASPECTS.size():
		_set_window(Vector2i(2400, 1080))
		return true
	if _hold == 0:
		_set_window(ASPECTS[_aspect])
		_hold = 1
		_frames = 0
		_clock = 0.0
		return false
	_clock += delta
	if _frames < 8:
		return false
	if _hold == 1:
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera()
		_hold = 2
		_clock = 0.0
		return false
	if _clock < 0.4:
		return false
	var size: Vector2i = ASPECTS[_aspect]
	_save(board, "dungeon_%dx%d.png" % [size.x, size.y])
	_aspect += 1
	_hold = 0
	return false


func _set_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size


func _set_zoom(board: Node, zoom: float) -> void:
	var cam: Camera2D = board.get("_camera")
	if cam == null:
		return
	_zoom_saved = cam.zoom.x
	cam.zoom = Vector2(zoom, zoom)
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
