extends SceneTree

## Phone-fit crit. Window 2400×1080, logical view 1600×720.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --fixed-fps 30 --path . -s res://tests/shot_crit.gd -- <out_dir> [before|after] --mobile-frame

var _dir := "/opt/cursor/artifacts/crit_hit"
var _mode := "after"
var _board: Node
var _dump := false
var _clip_i := 0
var _saved := false
var _watchdog := 0
const CLIP_MAX := 180


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
	if _watchdog > 700:
		push_error("crit shot timed out")
		quit(1)
		return true
	if _dump:
		_dump_frame()
		if not _saved and _crit_label_up():
			_save("crit_%s.png" % _mode)
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
	await _frames(12)
	await _board._submit({"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(5, 4)})
	await _frames(8)
	if not _saved:
		_save("crit_%s.png" % _mode)
		_saved = true
	_open_log()
	await _frames(36)
	var hud: CombatHUD = _board._hud
	var body := "" if hud == null or hud._log_body == null else hud._log_body.get_parsed_text()
	print("LOG\n%s" % body)
	if _mode == "after" and not body.to_lower().contains("crit"):
		push_error("log is missing the crit")
	print("CRIT done saved=%s clip=%d" % [_saved, _clip_i])
	quit(0)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _setup() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 3,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1, 1, 1, 1, 1, 1, 1],
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(4, 4), Vector2i(5, 4)],
	})
	sim._unit_by_seat(0)["crit"] = 100
	if _board.has_method("_rebuild_pawns"):
		_board._rebuild_pawns()
	if _board.has_method("_refresh"):
		_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud._layout_chrome()


func _crit_label_up() -> bool:
	if _board == null:
		return false
	var vfx: Node = _board.get("_vfx")
	if vfx == null:
		return false
	var pools: Variant = vfx.get("_pools")
	if typeof(pools) != TYPE_DICTIONARY:
		return false
	for node in pools.get("number", []):
		if node == null or not bool(node.get("in_use")):
			continue
		if str(node.get("_text")).contains("CRIT"):
			return true
	return false


func _open_log() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null:
		return
	if not hud._log_open:
		hud._toggle_log()
	hud._layout_chrome()
	hud._scroll_log_end()


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
	var view := _board.get_viewport().get_visible_rect().size
	var zoom := 0.0
	if _board._camera != null:
		zoom = _board._camera.zoom.x
	print("FRAME zoom=%.3f view=%s" % [zoom, view])
