extends SceneTree

## Phone frame, Ironjaw's turn, right after Magma. Bastion's card shows
## BURN and NO SHIELD on separate lines. His turn has not started, so the
## 1-turn lock is still up.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_no_shield.gd -- /opt/cursor/artifacts/no_shield --mobile-frame

var _dir := "/opt/cursor/artifacts/no_shield"
var _frames := 0
var _phase := "boot"
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
	if _frames > 400:
		push_error("no-shield shot timed out in %s" % _phase)
		return true
	if current_scene == null:
		return false
	_board = current_scene.get_node_or_null("BoardView")
	if _board == null or not bool(_board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 8:
			return false
		if not _arm():
			return true
		_settle()
		_phase = "ready"
		_frames = 0
		return false
	if _phase == "ready":
		if _frames < 12:
			return false
		return _shoot()
	return true


func _arm() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1],
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
	var cast: Dictionary = sim.submit({"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(4, 5)})
	if not bool(cast.get("ok", false)):
		push_error("Magma failed: %s" % str(cast.get("reason", "")))
		return false
	bastion = sim._unit_by_seat(1)
	if int(bastion.get("burn_stacks", 0)) != 3 or int(bastion.get("burn_remaining", 0)) != 2 or int(bastion.get("no_shield", 0)) != 1:
		push_error("expected Burn 3 for 2 and NO SHIELD 1, got %s/%s lock %s" % [
			bastion.get("burn_stacks", 0), bastion.get("burn_remaining", 0), bastion.get("no_shield", 0),
		])
		return false
	if int(sim.snapshot().get("active_seat", -1)) != 0:
		push_error("the shot must be before Bastion's turn")
		return false
	return true


func _shoot() -> bool:
	var hud: CombatHUD = _board._hud
	hud.focus_fighter(1)
	hud._layout_chrome()
	hud._fit_corner_cards()
	var right := "" if hud._ironjaw_body == null else hud._ironjaw_body.get_parsed_text()
	print("RIGHT %s" % right.replace("\n", " | "))
	if not right.contains("BURN") or not right.contains("NO SHIELD 1"):
		push_error("the status panel is missing BURN or NO SHIELD 1: %s" % right.replace("\n", " | "))
		return true
	if hud._banner_panels.size() < 2:
		push_error("corner cards are missing")
		return true
	var panel: Control = hud._banner_panels[1]
	var rect := panel.get_global_rect()
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		push_error("phone frame is %dx%d" % [image.get_width(), image.get_height()])
		return true
	var full := _dir.path_join("status_board.png")
	image.save_png(full)
	print("SHOT %s" % full)
	var view := _board.get_viewport().get_visible_rect().size
	var scale := float(image.get_width()) / view.x
	var origin := Vector2i(int(rect.position.x * scale), int(rect.position.y * scale))
	var size := Vector2i(maxi(int(rect.size.x * scale), 1), maxi(int(rect.size.y * scale), 1))
	origin.x = clampi(origin.x, 0, image.get_width() - 1)
	origin.y = clampi(origin.y, 0, image.get_height() - 1)
	size.x = mini(size.x, image.get_width() - origin.x)
	size.y = mini(size.y, image.get_height() - origin.y)
	var crop := image.get_region(Rect2i(origin, size))
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var path := _dir.path_join("status_panel.png")
	var err := crop.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, crop.get_width(), crop.get_height(), err])
	print("CARD %s" % right.replace("\n", " | "))
	return true


func _settle() -> void:
	if _board.has_method("_rebuild_grid"):
		_board._rebuild_grid(15)
	if _board.has_method("_rebuild_pawns"):
		_board._rebuild_pawns()
	if _board.has_method("_refresh"):
		_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud._layout_chrome()
		hud._fit_corner_cards()
