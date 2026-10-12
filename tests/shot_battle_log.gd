extends SceneTree

## 2400×1080 phone fit: the log open on a hidden Gloam turn.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_battle_log.gd -- /opt/cursor/artifacts/battle_log --mobile-frame

var _dir := "/opt/cursor/artifacts/battle_log"
var _phase := "boot"
var _frames := 0
var _board: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	select.set("hotseat_map_id", "crosshaven")
	select.set("hotseat_classes", ["gloam", "kestrel"])
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 500:
		push_error("battle log shot timed out in %s" % _phase)
		return true
	if current_scene == null:
		return false
	_board = current_scene.get_node_or_null("BoardView")
	if _board == null or not bool(_board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 8:
			return false
		if not _play():
			return true
		_settle()
		_phase = "button"
		_frames = 0
		return false
	if _phase == "button":
		if _frames < 20:
			return false
		_frame("button")
		_save("fight_log_button.png")
		var hud: CombatHUD = _board._hud
		hud._toggle_log()
		hud._layout_chrome()
		_phase = "open"
		_frames = 0
		return false
	if _phase == "open":
		if _frames < 24:
			return false
		var hud: CombatHUD = _board._hud
		hud._scroll_log_end()
		_frame("open")
		_save("log_hidden_gloam.png")
		var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
		print("LOG\n%s" % body)
		if not hud._log_open:
			push_error("log panel did not open")
		if not body.contains("moves while hidden"):
			push_error("log is missing the hidden Gloam move")
		if body.contains("(4,") or body.contains("walks"):
			push_error("hidden Gloam turn leaked a step or a tile")
		return true
	return true


func _play() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1, 1, 1, 1, 1],
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(4, 4), Vector2i(8, 4)],
	})
	if not _act(sim, {"type": "cast", "spell": "fade", "seat": 0, "to": Vector2i(4, 4)}, "fade"):
		return false
	if not _act(sim, {"type": "move", "seat": 0, "to": Vector2i(4, 5)}, "hidden walk"):
		return false
	return true


func _act(sim: Node, intent: Dictionary, label: String) -> bool:
	var result: Dictionary = sim.submit(intent)
	if bool(result.get("ok", false)):
		return true
	push_error("%s failed: %s" % [label, str(result.get("reason", ""))])
	return false


func _settle() -> void:
	if _board.has_method("_rebuild_pawns"):
		_board._rebuild_pawns()
	if _board.has_method("_refresh"):
		_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud._layout_chrome()


func _frame(tag: String) -> void:
	var view := _board.get_viewport().get_visible_rect().size
	var zoom := 0.0
	if _board._camera != null:
		zoom = _board._camera.zoom.x
	print("FRAME %s zoom=%.3f view=%s" % [tag, zoom, view])


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
