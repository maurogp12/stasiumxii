extends SceneTree

## 2400×1080 phone fit: the fight log open on a Spark combo.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_spark_log.gd -- /opt/cursor/artifacts/spark_log --mobile-frame

var _dir := "/opt/cursor/artifacts/spark_log"
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
	select.set("hotseat_classes", ["ironjaw", "kestrel"])
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 500:
		push_error("spark log shot timed out in %s" % _phase)
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
		_phase = "open"
		_frames = 0
		return false
	if _phase == "open":
		if _frames < 24:
			return false
		var hud: CombatHUD = _board._hud
		hud._toggle_log()
		hud._layout_chrome()
		hud._scroll_log_end()
		_frame("open")
		_save("log_spark.png")
		_save_log_crop(hud, "log_spark_close.png")
		var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
		print("LOG\n%s" % body)
		if not hud._log_open:
			push_error("log panel did not open")
		if not body.contains("Spark"):
			push_error("log is missing the Spark combo")
		if not body.contains("10") or not body.contains("Healing"):
			push_error("log is missing the Spark damage or the healing debuff")
		if body.contains("(4,") or body.contains("(5,"):
			push_error("Spark log printed a tile")
		return true
	return true


func _play() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1, 1, 1, 1, 1],
		"classes": ["ironjaw", "kestrel"],
		"positions": [Vector2i(4, 4), Vector2i(4, 5)],
	})
	var actor: Dictionary = sim._unit_by_seat(0)
	actor["spell_elements"] = {"strike": "water", "shoulder": "air", "crush": "air"}
	var kestrel: Dictionary = sim._unit_by_seat(1)
	kestrel["residue"] = "air"
	kestrel["residue_seat"] = 0
	kestrel["residue_turns"] = 2
	return _act(sim, {"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(4, 5)}, "spark")


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


func _save_log_crop(hud: CombatHUD, file_name: String) -> void:
	var panel := hud._log_panel
	if panel == null:
		return
	var image := root.get_texture().get_image()
	var view := _board.get_viewport().get_visible_rect().size
	if view.x < 2.0:
		return
	var scale := float(image.get_width()) / view.x
	var rect := panel.get_global_rect()
	var origin := Vector2i(int(rect.position.x * scale), int(rect.position.y * scale))
	var size := Vector2i(maxi(int(rect.size.x * scale), 1), maxi(int(rect.size.y * scale), 1))
	origin.x = clampi(origin.x, 0, image.get_width() - 1)
	origin.y = clampi(origin.y, 0, image.get_height() - 1)
	size.x = mini(size.x, image.get_width() - origin.x)
	size.y = mini(size.y, image.get_height() - origin.y)
	var crop := image.get_region(Rect2i(origin, size))
	var path := _dir.path_join(file_name)
	var err := crop.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, crop.get_width(), crop.get_height(), err])
