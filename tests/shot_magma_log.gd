extends SceneTree

## 2400×1080 phone fit: Bastion's next turn, still burning, Ward available
## (the 1-turn shield lock already ended), then the log open on the Magma line.
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
		hud.focus_fighter(1)
		hud._layout_chrome()
		if not _shoot_board():
			return true
		# Paint the Magma tile so the log also has its 4 HP line, then open it.
		var sim: Node = root.get_node("/root/CombatSim")
		if not _act(sim, {"type": "end_turn", "seat": 1}, "end bastion"):
			return true
		_settle()
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
	# The left card is whoever is acting. Bastion's turn puts him there.
	var left := "" if hud._kestrel_body == null else hud._kestrel_body.get_parsed_text()
	var right := "" if hud._ironjaw_body == null else hud._ironjaw_body.get_parsed_text()
	var titles := ""
	for title in hud._banner_titles:
		titles += title.text + " | "
	var coach := "" if hud._coach_label == null else hud._coach_label.text
	var button: Button = hud._spell_buttons.get("ward") as Button
	var badge := ""
	var disabled := false
	if button != null:
		disabled = button.disabled
		var badge_label := button.get_node_or_null("CooldownBadge") as Label
		badge = "" if badge_label == null else badge_label.text
	var sim: Node = root.get_node("/root/CombatSim")
	var bastion: Dictionary = sim._unit_by_seat(1)
	print("LEFT %s" % left.replace("\n", " | "))
	print("RIGHT %s" % right.replace("\n", " | "))
	print("TITLES %s" % titles)
	print("COACH %s" % coach)
	print("WARD disabled=%s badge=%s" % [disabled, badge])
	print("BASTION ap=%s aegis=%s shield=%s burn=%s/%s" % [
		bastion.get("ap", 0), bastion.get("aegis", 0), bastion.get("shield", 0),
		bastion.get("burn_stacks", 0), bastion.get("burn_remaining", 0),
	])
	_frame("board")
	if not titles.contains("Bastion"):
		push_error("Bastion's name is not on a card")
		return false
	if not left.contains("BURN"):
		push_error("Bastion's card is not burning")
		return false
	if left.contains("NO SHIELD"):
		push_error("the shield lock is still on his card after his turn opened")
		return false
	if button == null or disabled or badge != "":
		push_error("Ward should be available while he is still burning (disabled=%s badge=%s)" % [disabled, badge])
		return false
	if coach.contains("Ward:") or coach.contains("+20") or coach.contains("shield on"):
		push_error("the bottom bar still claims a shield landed: %s" % coach)
		return false
	if int(bastion.get("shield", 0)) != 0:
		push_error("Bastion has a shield, so the dome would draw")
		return false
	if int(bastion.get("ap", 0)) != 6 or int(bastion.get("aegis", 0)) != 4:
		push_error("Ward spent AP or Aegis")
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
	if not body.contains("Magma: Ironjaw on Bastion, Burn 3 stacks for 2 turns, no shields for 1 turn"):
		push_error("log is missing the Magma line")
		return true
	if body.contains("Ward:") or body.contains("+20 shield") or body.contains("wards "):
		push_error("the log claims a shield landed")
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
	# The panel center can land on a colored name. The fill around it is navy.
	var dark := 0
	var samples := 0
	for gy in range(1, 4):
		for gx in range(1, 4):
			var px := origin.x + size.x * gx / 4
			var py := origin.y + size.y * gy / 4
			var pixel := image.get_pixel(px, py)
			samples += 1
			if pixel.r < 0.2 and pixel.g < 0.25 and pixel.b < 0.35:
				dark += 1
			print("PANEL PIXEL %s,%s %s" % [px, py, pixel])
	print("CROP %s %dx%d dark %d/%d" % [close, crop.get_width(), crop.get_height(), dark, samples])
	# A text-filled panel still has navy fill. A crop of the board does not.
	if dark < 2:
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
	if not _act(sim, {"type": "end_turn", "seat": 0}, "end ironjaw"):
		return false
	bastion = sim._unit_by_seat(1)
	if int(bastion.get("burn_stacks", 0)) != 3 or int(bastion.get("shield", 0)) != 0:
		push_error("Bastion should be burning with no shield (stacks %s shield %s)" % [bastion.get("burn_stacks", 0), bastion.get("shield", 0)])
		return false
	if int(bastion.get("ap", 0)) != 6 or int(bastion.get("aegis", 0)) != 4:
		push_error("turn start spent AP or Aegis (ap %s aegis %s)" % [bastion.get("ap", 0), bastion.get("aegis", 0)])
		return false
	var offered := false
	for intent in sim.legal_intents(1):
		if str(intent.get("spell", "")) == "ward":
			offered = true
	if not offered:
		push_error("Ward should be offered on his next turn while he is still burning")
		return false
	if int(bastion.get("no_shield", 0)) != 0:
		push_error("the shield lock should have ended at his turn start")
		return false
	return true


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
