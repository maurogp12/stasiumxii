extends SceneTree

## Phone frame (1600×720): Ironjaw throws Strike (Air) and Shoulder (Fire)
## into empty tiles. Flare fires on the second tile and reveals Gloam.
## xvfb-run -s "-screen 0 1600x720x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_air_blend.gd -- /opt/cursor/artifacts/air_blend

var _dir := "/opt/cursor/artifacts/air_blend"
var _phase := "boot"
var _frames := 0
var _board: Node
var _flare_events: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(1600, 720))
	root.size = Vector2i(1600, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 900:
		push_error("air blend shot timed out in %s" % _phase)
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
		if _board.has_method("_present_resolve"):
			_board._present_resolve(_flare_events)
		_open_log()
		_phase = "flare"
		_frames = 0
		return false
	if _phase == "flare":
		if _frames < 18:
			return false
		var hud: CombatHUD = _board._hud
		if hud != null and hud.has_method("_scroll_log_end"):
			hud._scroll_log_end()
		_phase = "shot"
		_frames = 0
		return false
	if _phase == "shot":
		if _frames < 6:
			return false
		var hud: CombatHUD = _board._hud
		var body := "" if hud == null or hud._log_body == null else hud._log_body.get_parsed_text()
		print("LOG\n%s" % body)
		if not body.contains("Flare"):
			push_error("log is missing Flare")
			return true
		if not body.contains("in the air"):
			push_error("log is missing the air Blend")
			return true
		if not body.contains("reveals") or not body.contains("Gloam"):
			push_error("log is missing the Gloam reveal")
			return true
		if not body.contains("Gloam is visible"):
			push_error("log is missing the visible line")
			return true
		_save("flare_reveals_gloam.png")
		return true
	return true


func _play() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1, 1],
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(4, 5), Vector2i(7, 5)],
		"gloam_invisible": true,
	})
	sim._unit_by_seat(0)["spell_elements"] = {"strike": "air", "shoulder": "fire", "crush": "fire", "advance": "air"}
	if not bool(sim._unit_by_seat(1).get("invisible", false)):
		push_error("Gloam did not start hidden")
		return false
	var first: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(5, 5), "seat": 0})
	if not bool(first.get("ok", false)):
		push_error("Strike into air failed: %s" % str(first.get("reason", "")))
		return false
	if str(sim._unit_by_seat(0).get("cast_element", "")) != "air":
		push_error("Air did not hang")
		return false
	var second: Dictionary = sim.submit({"type": "cast", "spell": "shoulder", "to": Vector2i(5, 6), "seat": 0})
	if not bool(second.get("ok", false)):
		push_error("Shoulder into air failed: %s" % str(second.get("reason", "")))
		return false
	_flare_events = second.get("events", [])
	if bool(sim._unit_by_seat(1).get("invisible", true)):
		push_error("Gloam stayed hidden")
		return false
	var blend := ""
	for event in _flare_events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "blend":
			blend = str(event.get("blend", ""))
	if blend != "flare":
		push_error("expected Flare, got %s" % blend)
		return false
	print("PLAY flare on (5, 6), Gloam revealed at (7, 5)")
	return true


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


func _open_log() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null:
		return
	if not hud._log_open:
		hud._toggle_log()
	hud._layout_chrome()


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 1600 or image.get_height() != 720:
		image.resize(1600, 720, Image.INTERPOLATE_BILINEAR)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	if err != OK:
		push_error("could not save %s" % path)
		quit(1)
