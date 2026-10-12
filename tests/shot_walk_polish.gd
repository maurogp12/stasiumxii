extends SceneTree

## Phone-fit walk. Window 2400×1080, logical view 1600×720.
## Ironjaw walks east, turns the corner by climbing one elevation, and plants.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --fixed-fps 30 --path . -s res://tests/shot_walk_polish.gd -- <out_dir> [before|after] --mobile-frame

var _dir := "/opt/cursor/artifacts/walk_motion"
var _mode := "after"
var _board: Node
var _dump := false
var _clip_i := 0
var _saved := false
var _watchdog := 0
const CLIP_MAX := 240


func _initialize() -> void:
	var positional: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		positional.append(text)
	if positional.size() > 0:
		_dir = positional[0]
	if positional.size() > 1:
		_mode = positional[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	if _mode == "after":
		DirAccess.make_dir_recursive_absolute(_dir.path_join("frames"))
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	select.set("hotseat_map_id", "crosshaven")
	select.set("hotseat_classes", ["ironjaw", "gloam"])
	change_scene_to_file("res://main.tscn")
	call_deferred("_drive")


func _process(_delta: float) -> bool:
	_watchdog += 1
	if _watchdog > 900:
		push_error("walk shot timed out")
		quit(1)
		return true
	if _dump:
		_dump_frame()
		if not _saved and _on_climb():
			_save("walk_%s.png" % _mode)
			_saved = true
	return false


func _drive() -> void:
	while true:
		await process_frame
		if current_scene == null:
			continue
		_board = current_scene.get_node_or_null("BoardView")
		if _board != null and bool(_board.get("_booted")):
			break
	await _frames(6)
	_setup()
	if _mode == "after":
		_dump = true
	await _frames(8)
	await _board._submit({"type": "move", "to": Vector2i(7, 5), "seat": 0})
	await _frames(10)
	if not _saved:
		_save("walk_%s.png" % _mode)
		_saved = true
	print("WALK done saved=%s clip=%d" % [_saved, _clip_i])
	quit(0)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _setup() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 4,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(4, 4), Vector2i(10, 10)],
	})
	sim.set_tile(Vector2i(6, 4), "ground", 1)
	sim.set_tile(Vector2i(7, 4), "ground", 1)
	sim.set_tile(Vector2i(7, 5), "ground", 1)
	var unit: Dictionary = sim._unit_by_seat(0)
	unit["mp"] = 8
	unit["max_mp"] = 8
	if _board.has_method("_rebuild_pawns"):
		_board._rebuild_pawns()
	if _board.has_method("_refresh"):
		_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud._layout_chrome()


## Halfway across the step that climbs onto (6, 4). Horizontal only, so a
## late landing and a straight ramp both hit this window.
func _on_climb() -> bool:
	if _board == null or not _board.pawns_by_seat.has(0):
		return false
	var pawn: Pawn = _board.pawns_by_seat[0]
	if pawn.grid_position != Vector2i(5, 4):
		return false
	var src: Vector2 = _board._cell_to_local(Vector2i(5, 4))
	var progress := (pawn.position.x - src.x) / 32.0
	return progress > 0.42 and progress < 0.62


func _dump_frame() -> void:
	if _clip_i >= CLIP_MAX:
		return
	var image := root.get_texture().get_image()
	if image == null:
		return
	image.save_png(_dir.path_join("frames/f_%04d.png" % _clip_i))
	_clip_i += 1


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image")
		return
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [path, image.get_width(), image.get_height(), err])
