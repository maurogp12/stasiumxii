extends SceneTree

## 2400×1080 phone fit: Detonate hits a shielded Bastion in Ranged Guard.
## The log says "pierces defenses" and his HP card shows the drop.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_detonate_pierce.gd -- /opt/cursor/artifacts/detonate_pierce --mobile-frame

var _dir := "/opt/cursor/artifacts/detonate_pierce"
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
	select.set("hotseat_classes", ["kestrel", "bastion"])
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 700:
		push_error("detonate shot timed out in %s" % _phase)
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
		return _shoot()
	return true


func _shoot() -> bool:
	var hud: CombatHUD = _board._hud
	var sim: Node = root.get_node("/root/CombatSim")
	var bastion: Dictionary = sim._unit_by_seat(1)
	var left := "" if hud._kestrel_body == null else hud._kestrel_body.get_parsed_text()
	var right := "" if hud._ironjaw_body == null else hud._ironjaw_body.get_parsed_text()
	var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
	var hp := int(bastion.get("hp", 0))
	var max_hp := int(bastion.get("max_hp", 0))
	var shield := int(bastion.get("shield", 0))
	print("LEFT %s" % left.replace("\n", " | "))
	print("RIGHT %s" % right.replace("\n", " | "))
	print("BASTION hp=%d/%d shield=%d stance=%s" % [hp, max_hp, shield, bastion.get("gate_stance", "")])
	print("LOG\n%s" % body)
	_frame("log")
	var image := root.get_texture().get_image()
	var path := _dir.path_join("detonate_pierce.png")
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	if image.get_width() != 2400 or image.get_height() != 1080:
		push_error("phone frame is %dx%d, want 2400x1080" % [image.get_width(), image.get_height()])
		return true
	if not hud._log_open:
		push_error("log panel did not stay open")
		return true
	if not body.contains("pierces defenses"):
		push_error("log is missing pierces defenses")
		return true
	if not body.contains("Detonate"):
		push_error("log is missing Detonate")
		return true
	var hp_line := "HP %d/%d" % [hp, max_hp]
	if not right.contains(hp_line):
		push_error("Bastion card does not show %s" % hp_line)
		return true
	if hp != max_hp - 28:
		push_error("HP drop is %d, want 28 off %d" % [max_hp - hp, max_hp])
		return true
	if shield != 25:
		push_error("Ward shield should still be 25, got %d" % shield)
		return true
	if str(bastion.get("gate_stance", "")) != "ranged_guard":
		push_error("Bastion is not in Ranged Guard")
		return true
	return true


func _play() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var worn: Array = []
	for slot in ["weapon", "head", "chest", "legs", "boots"]:
		worn.append({"item_id": "gatewarden.%s" % slot, "plus": 0})
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"flat_board": true,
		"rolls": [1, 1, 1, 1],
		"classes": ["kestrel", "bastion"],
		"positions": [Vector2i(8, 6), Vector2i(12, 6)],
		"kestrel_facing": "E",
		"bastion_facing": "W",
		"bastion_marks": 3,
		"bastion_aegis": 2,
		"seat_gear": {1: {"worn": worn, "stance": "ranged_guard", "flatten_plus": true}},
	})
	var bastion: Dictionary = sim._unit_by_seat(1)
	bastion["facing"] = "W"
	var elem: Dictionary = bastion.get("resist_elem", {})
	elem["air"] = int(elem.get("air", 0)) + 20
	bastion["resist_elem"] = elem
	if not _act(sim, {"type": "end_turn", "seat": 0}, "pass to bastion"):
		return false
	if not _act(sim, {"type": "cast", "spell": "ward", "to": Vector2i(12, 6), "seat": 1}, "ward"):
		return false
	if int(sim._unit_by_seat(1).get("shield", 0)) != 25:
		push_error("Ward did not leave a 25 shield")
		return false
	if not _act(sim, {"type": "end_turn", "seat": 1}, "end bastion"):
		return false
	var before := int(sim._unit_by_seat(1).get("hp", 0))
	if not _act(sim, {"type": "cast", "spell": "detonate", "to": Vector2i(12, 6), "seat": 0}, "detonate"):
		return false
	bastion = sim._unit_by_seat(1)
	if int(bastion.get("hp", 0)) != before - 28 or int(bastion.get("shield", 0)) != 25:
		push_error("Detonate hp=%s shield=%s, want %d and shield 25" % [bastion.get("hp", 0), bastion.get("shield", 0), before - 28])
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
		hud.render(root.get_node("/root/CombatSim").snapshot(), root.get_node("/root/CombatSim").legal_intents(0))
		hud._layout_chrome()


func _frame(tag: String) -> void:
	var view := _board.get_viewport().get_visible_rect().size
	var zoom := 0.0
	if _board._camera != null:
		zoom = _board._camera.zoom.x
	print("FRAME %s zoom=%.3f view=%s window=%s" % [tag, zoom, view, DisplayServer.window_get_size()])
