extends SceneTree

## 2400×1080 phone fit: Bastion burning with Ward refused, then the log open
## on the Magma line and the blocked-shield line.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_magma_log.gd -- /opt/cursor/artifacts/magma_burn --mobile-frame

var _dir := "/opt/cursor/artifacts/magma_burn"
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
	select.set("hotseat_classes", ["ironjaw", "bastion"])
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 700:
		push_error("magma shot timed out in %s" % _phase)
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
		if _frames < 16:
			return false
		var hud: CombatHUD = _board._hud
		var sim: Node = root.get_node("/root/CombatSim")
		var events: Array = sim.snapshot().get("battle_log", [])
		var toast := CombatHUD.toast_for_events(_tail_since_ward(events))
		hud.show_toast(toast)
		hud.focus_fighter(1)
		hud._layout_chrome()
		_phase = "toast"
		_frames = 0
		return false
	if _phase == "toast":
		if _frames < 12:
			return false
		if not _shoot_board():
			return true
		# Paint the Magma tile so the log also has its 4 HP line, then open it.
		var sim: Node = root.get_node("/root/CombatSim")
		if not _act(sim, {"type": "end_turn", "seat": 1}, "end bastion"):
			return true
		_settle()
		var hud: CombatHUD = _board._hud
		if not hud._log_open:
			hud._toggle_log()
		hud._layout_chrome()
		_phase = "open"
		_frames = 0
		return false
	if _phase == "open":
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
		return _shoot_log()
	return true


func _shoot_board() -> bool:
	var hud: CombatHUD = _board._hud
	var card := ""
	if hud._ironjaw_body != null:
		card = hud._ironjaw_body.get_parsed_text()
	var toast := hud.toast_caption()
	print("CARD %s" % card.replace("\n", " | "))
	print("TOAST %s" % toast)
	_frame("board")
	if not card.contains("BURN"):
		push_error("Bastion card is not burning")
		return false
	if not toast.contains("Ward refused"):
		push_error("Ward refused toast is missing")
		return false
	var image := root.get_texture().get_image()
	var path := _dir.path_join("magma_ward.png")
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	if image.get_width() != 2400 or image.get_height() != 1080:
		push_error("phone frame is %dx%d, want 2400x1080" % [image.get_width(), image.get_height()])
		return false
	return true


func _shoot_log() -> bool:
	var hud: CombatHUD = _board._hud
	var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
	var button := "" if hud._log_button == null else hud._log_button.text
	var rect := Rect2()
	if hud._log_panel != null:
		rect = hud._log_panel.get_global_rect()
	print("LOG OPEN %s BUTTON %s VISIBLE %s RECT %s" % [
		hud._log_open, button, hud._log_panel != null and hud._log_panel.visible, rect,
	])
	print("LOG\n%s" % body)
	_frame("log")
	if not hud._log_open or button != "Close":
		push_error("log panel did not stay open")
		return true
	if hud._log_panel == null or not hud._log_panel.visible:
		push_error("log panel is not visible")
		return true
	if not body.contains("Magma: Ironjaw on Bastion, Burn 3 stacks, no shields while burning"):
		push_error("log is missing the Magma line")
		return true
	if not body.contains("Shield blocked (Ward). Bastion is burning."):
		push_error("log is missing the blocked shield line")
		return true
	if not body.contains("Magma, 4 HP"):
		push_error("log is missing the Magma tile line")
		return true
	var image := root.get_texture().get_image()
	var full := _dir.path_join("magma_log.png")
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
	var close := _dir.path_join("magma_log_close.png")
	crop.save_png(close)
	var mid := image.get_pixel(origin.x + size.x / 2, origin.y + size.y / 2)
	print("PANEL PIXEL %s" % mid)
	print("CROP %s %dx%d" % [close, crop.get_width(), crop.get_height()])
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
		"classes": ["ironjaw", "bastion"],
		"positions": [Vector2i(4, 4), Vector2i(4, 5)],
		"bastion_aegis": 4,
	})
	var actor: Dictionary = sim._unit_by_seat(0)
	actor["spell_elements"] = {"strike": "fire", "shoulder": "earth", "crush": "earth"}
	var bastion: Dictionary = sim._unit_by_seat(1)
	bastion["residue"] = "earth"
	bastion["residue_seat"] = 0
	bastion["residue_turns"] = 2
	if not _act(sim, {"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(4, 5)}, "magma"):
		return false
	bastion = sim._unit_by_seat(1)
	bastion["shield"] = 18
	if not _act(sim, {"type": "end_turn", "seat": 0}, "end ironjaw"):
		return false
	bastion = sim._unit_by_seat(1)
	if int(bastion.get("burn_stacks", 0)) != 3 or int(bastion.get("shield", 0)) != 18:
		push_error("Bastion is not burning behind his old shield (stacks %s shield %s)" % [bastion.get("burn_stacks", 0), bastion.get("shield", 0)])
		return false
	bastion["aegis"] = 4
	bastion["ap"] = 6
	if not _act(sim, {"type": "cast", "spell": "ward", "seat": 1, "to": bastion["pos"]}, "ward"):
		return false
	if int(sim._unit_by_seat(1).get("shield", 0)) != 18:
		push_error("Ward changed the shield")
		return false
	return true


func _tail_since_ward(events: Array) -> Array:
	var out: Array = []
	for raw in events:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw
		if str(event.get("type", "")) == "shield_blocked" or str(event.get("spell", "")) == "ward":
			out.append(event)
	return out


func _act(sim: Node, intent: Dictionary, label: String) -> bool:
	var result: Dictionary = sim.submit(intent)
	if bool(result.get("ok", false)):
		return true
	push_error("%s failed: %s" % [label, str(result.get("reason", result.get("coach", "")))])
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
