extends SceneTree

## Phone frame (1600×720): Bastion's idle-Aegis tooltip, a Plant turn that
## keeps Aegis, and a walk that drops it with the log line.
## xvfb-run -s "-screen 0 1600x720x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_idle_aegis.gd -- /opt/cursor/artifacts/idle_aegis

var _dir := "/opt/cursor/artifacts/idle_aegis"
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
	DisplayServer.window_set_size(Vector2i(1600, 720))
	root.size = Vector2i(1600, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 900:
		push_error("idle aegis shot timed out in %s" % _phase)
		return true
	if current_scene == null:
		return false
	_board = current_scene.get_node_or_null("BoardView")
	if _board == null or not bool(_board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 8:
			return false
		if not _boot_tooltip():
			return true
		_settle()
		var hud: CombatHUD = _board._hud
		hud.focus_fighter(0)
		hud._on_spell_pressed(SpellKits.PLANT)
		hud.show_spell_tooltip(SpellKits.PLANT)
		hud._layout_chrome()
		_phase = "tooltip"
		_frames = 0
		return false
	if _phase == "tooltip":
		if _frames < 16:
			return false
		var hud: CombatHUD = _board._hud
		var tip := "" if hud == null else hud.tooltip_caption()
		print("TOOLTIP %s" % tip.replace("\n", " | "))
		if not tip.contains("An idle turn (no attack and no Plant) loses all Aegis. Attacking or planting keeps it."):
			push_error("tooltip is missing the idle Aegis rule: %s" % tip)
			return true
		_save("tooltip_idle_aegis.png")
		hud.hide_spell_tooltip()
		if not _play_plant():
			return true
		_settle()
		_open_log()
		_phase = "plant"
		_frames = 0
		return false
	if _phase == "plant":
		if _frames < 20:
			return false
		var hud: CombatHUD = _board._hud
		hud._scroll_log_end()
		_phase = "plant_shot"
		_frames = 0
		return false
	if _phase == "plant_shot":
		if _frames < 8:
			return false
		if not _expect_card("Aegis 3/4", "plants a banner", false):
			return true
		_save("plant_keeps_aegis.png")
		if not _play_walk():
			return true
		_settle()
		_open_log()
		_phase = "walk"
		_frames = 0
		return false
	if _phase == "walk":
		if _frames < 20:
			return false
		var hud: CombatHUD = _board._hud
		hud._scroll_log_end()
		_phase = "walk_shot"
		_frames = 0
		return false
	if _phase == "walk_shot":
		if _frames < 8:
			return false
		if not _expect_card("Aegis 0/4", "Aegis lost: idle turn", true):
			return true
		_save("walk_drops_aegis.png")
		return true
	return true


func _boot_tooltip() -> bool:
	return _match(Vector2i(4, 5), Vector2i(8, 5), 2, [])


func _play_plant() -> bool:
	if not _match(Vector2i(4, 5), Vector2i(12, 5), 2, []):
		return false
	var sim: Node = root.get_node("/root/CombatSim")
	if not _act(sim, {"type": "cast", "spell": "plant", "to": Vector2i(5, 5), "seat": 0}, "plant"):
		return false
	if int(sim._unit_by_seat(0)["aegis"]) != 3:
		push_error("Plant did not leave 3 Aegis")
		return false
	if not _act(sim, {"type": "end_turn", "seat": 0}, "end after plant"):
		return false
	if int(sim._unit_by_seat(0)["aegis"]) != 3:
		push_error("Plant turn lost Aegis")
		return false
	return true


func _play_walk() -> bool:
	if not _match(Vector2i(4, 5), Vector2i(12, 5), 3, []):
		return false
	var sim: Node = root.get_node("/root/CombatSim")
	if not _act(sim, {"type": "move", "to": Vector2i(5, 5), "seat": 0}, "walk"):
		return false
	if not _act(sim, {"type": "end_turn", "seat": 0}, "end after walk"):
		return false
	if int(sim._unit_by_seat(0)["aegis"]) != 0:
		push_error("walk turn kept Aegis")
		return false
	return true


func _match(bastion: Vector2i, foe: Vector2i, aegis: int, rolls: Array) -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var spec := {
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [bastion, foe],
		"bastion_aegis": aegis,
	}
	if not rolls.is_empty():
		spec["rolls"] = rolls
	sim.reset_match(spec)
	return int(sim.snapshot().get("active_seat", -1)) == 0


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


func _open_log() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null:
		return
	if not hud._log_open:
		hud._toggle_log()
	hud._layout_chrome()


func _expect_card(aegis_text: String, log_needle: String, want_line: bool) -> bool:
	var hud: CombatHUD = _board._hud
	var left := "" if hud._kestrel_body == null else hud._kestrel_body.get_parsed_text().replace("\n", " | ")
	var right := "" if hud._ironjaw_body == null else hud._ironjaw_body.get_parsed_text().replace("\n", " | ")
	var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
	print("LEFT %s" % left)
	print("RIGHT %s" % right)
	print("LOG\n%s" % body)
	var cards := left + "\n" + right
	if not cards.contains(aegis_text):
		push_error("cards missing %s" % aegis_text)
		return false
	if want_line and not body.contains(log_needle):
		push_error("log missing %s" % log_needle)
		return false
	if not want_line and body.contains("Aegis lost: idle turn"):
		push_error("Plant turn logged an idle Aegis loss")
		return false
	if not want_line and not body.contains(log_needle):
		push_error("log missing %s" % log_needle)
		return false
	return true


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
