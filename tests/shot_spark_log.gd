extends SceneTree

## 2400×1080 phone fit: the fight log open on a Spark combo.
## The panel is opened, then the shot waits until that frame has drawn.
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
		_phase = "ready"
		_frames = 0
		return false
	if _phase == "ready":
		if _frames < 20:
			return false
		var hud: CombatHUD = _board._hud
		if not hud._log_open:
			hud._toggle_log()
		hud._layout_chrome()
		_phase = "open"
		_frames = 0
		return false
	if _phase == "open":
		# The screenshot is the frame already drawn. Wait until the open panel exists.
		if _frames < 16:
			return false
		var hud: CombatHUD = _board._hud
		hud._scroll_log_end()
		_phase = "scrolled"
		_frames = 0
		return false
	if _phase == "scrolled":
		if _frames < 8:
			return false
		return _shoot()
	return true


func _shoot() -> bool:
	var hud: CombatHUD = _board._hud
	var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
	var button := "" if hud._log_button == null else hud._log_button.text
	var rect := Rect2()
	if hud._log_panel != null:
		rect = hud._log_panel.get_global_rect()
	print("LOG OPEN %s BUTTON %s PANEL %s VISIBLE %s RECT %s" % [
		hud._log_open, button, hud._log_panel != null,
		hud._log_panel != null and hud._log_panel.visible, rect,
	])
	print("LOG\n%s" % body)
	_frame("open")
	if not hud._log_open or button != "Close":
		push_error("log panel did not stay open")
		return true
	if hud._log_panel == null or not hud._log_panel.visible:
		push_error("log panel is not visible")
		return true
	if rect.size.x < 40.0 or rect.size.y < 40.0:
		push_error("log panel has no size")
		return true
	if not body.contains("Spark") or not body.contains("Water slow"):
		push_error("log text is missing Spark or Water slow")
		return true
	var image := root.get_texture().get_image()
	var full := _dir.path_join("log_spark.png")
	var full_err := image.save_png(full)
	print("SHOT %s %dx%d err=%s" % [full, image.get_width(), image.get_height(), full_err])
	if image.get_width() != 2400 or image.get_height() != 1080:
		push_error("phone frame is %dx%d, want 2400x1080" % [image.get_width(), image.get_height()])
		return true
	var view := _board.get_viewport().get_visible_rect().size
	var scale := float(image.get_width()) / view.x
	var origin := Vector2i(int(rect.position.x * scale), int(rect.position.y * scale))
	var size := Vector2i(maxi(int(rect.size.x * scale), 1), maxi(int(rect.size.y * scale), 1))
	origin.x = clampi(origin.x, 0, image.get_width() - 1)
	origin.y = clampi(origin.y, 0, image.get_height() - 1)
	size.x = mini(size.x, image.get_width() - origin.x)
	size.y = mini(size.y, image.get_height() - origin.y)
	var crop := image.get_region(Rect2i(origin, size))
	var close := _dir.path_join("log_spark_close.png")
	var close_err := crop.save_png(close)
	print("CROP origin=%s size=%s scale=%.3f" % [origin, size, scale])
	print("SHOT %s %dx%d err=%s" % [close, crop.get_width(), crop.get_height(), close_err])
	var mid := image.get_pixel(origin.x + size.x / 2, origin.y + size.y / 2)
	print("PANEL PIXEL %s" % mid)
	if mid.r > 0.35 or mid.g > 0.35:
		push_error("log crop is not the dark panel")
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
	print("FRAME %s zoom=%.3f view=%s window=%s" % [tag, zoom, view, DisplayServer.window_get_size()])
