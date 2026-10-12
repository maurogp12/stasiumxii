extends SceneTree

## 2400×1080 phone fit: Long Shadow and Gathered Sand inventory text, then
## Plant, Snap Wall, Fade and Vault leaving Residue. The Snap Wall log shows
## that line, then Mire. Gathered Sand's log shows the reflect line.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_spell_residue.gd -- /opt/cursor/artifacts/spell_residue --mobile-frame

const BAG_PATH := "user://shot_spell_residue_bag.json"
const VAULT_PATH := "user://shot_spell_residue_vault.json"
const HERO_PATH := "user://shot_spell_residue_hero.json"
const WALLET_PATH := "user://shot_spell_residue_wallet.json"

var _dir := "/opt/cursor/artifacts/spell_residue"
var _phase := "inv"
var _frames := 0
var _screen: InventoryScreen
var _board: Node
var _failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	_seed_inventory()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 400:
		return _fail("timed out in %s" % _phase)
	match _phase:
		"inv":
			if _frames == 1:
				_screen = (load("res://scenes/inventory_screen.gd") as Script).new()
				_screen.name = "InventoryShot"
				root.add_child(_screen)
				_screen.pick_champion("kestrel")
				_screen.show_tab("stills")
				_screen.select({"kind": "still", "id": "long_shadow"})
			if _frames < 20:
				return false
			if not _shoot_inventory():
				return true
			_screen.select({"kind": "still", "id": "gathered_sand"})
			_phase = "sand_inv"
			_frames = 0
			return false
		"sand_inv":
			if _frames < 16:
				return false
			if not _shoot_sand_inventory():
				return true
			_screen.queue_free()
			var select: GDScript = load("res://scenes/class_select.gd")
			select.set("hotseat_map_id", "crosshaven")
			select.set("hotseat_classes", ["bastion", "kestrel"])
			_phase = "boot"
			_frames = 0
			change_scene_to_file("res://main.tscn")
			return false
		"boot":
			if current_scene == null:
				return false
			_board = current_scene.get_node_or_null("BoardView")
			if _board == null or not bool(_board.get("_booted")):
				return false
			if _frames < 8:
				return false
			if not _cast_wall():
				return true
			_settle()
			_phase = "wall"
			_frames = 0
			return false
		"wall":
			if _frames < 16:
				return false
			if not _shoot_cards("snap_wall_residue.png", "kestrel", "WATER", "residue"):
				return true
			if not _cast_bash():
				return true
			_settle()
			var hud: CombatHUD = _board._hud
			if not hud._log_open:
				hud._toggle_log()
			hud._layout_chrome()
			_phase = "log"
			_frames = 0
			return false
		"log":
			if _frames < 16:
				return false
			var hud: CombatHUD = _board._hud
			hud._scroll_log_end()
			_phase = "log_scrolled"
			_frames = 0
			return false
		"log_scrolled":
			if _frames < 8:
				return false
			if not _shoot_log():
				return true
			if not _setup_plant():
				return true
			_settle()
			_phase = "plant"
			_frames = 0
			return false
		"plant":
			if _frames < 16:
				return false
			if not _shoot_cards("plant_residue.png", "kestrel", "WATER", "residue"):
				return true
			if not _setup_fade():
				return true
			_settle()
			_phase = "fade"
			_frames = 0
			return false
		"fade":
			if _frames < 16:
				return false
			if not _shoot_cards("fade_residue.png", "kestrel", "WATER", "residue"):
				return true
			if not _setup_vault():
				return true
			_settle()
			_phase = "vault"
			_frames = 0
			return false
		"vault":
			if _frames < 16:
				return false
			if not _shoot_cards("vault_residue.png", "ironjaw", "WATER", "residue"):
				return true
			if not _setup_sand():
				return true
			_settle()
			var sand_hud: CombatHUD = _board._hud
			if not sand_hud._log_open:
				sand_hud._toggle_log()
			sand_hud._layout_chrome()
			_phase = "sand_log"
			_frames = 0
			return false
		"sand_log":
			if _frames < 16:
				return false
			var sand_log: CombatHUD = _board._hud
			sand_log._scroll_log_end()
			_phase = "sand_log_scrolled"
			_frames = 0
			return false
		"sand_log_scrolled":
			if _frames < 8:
				return false
			if not _shoot_sand_log():
				return true
			print("DONE")
			quit(0)
			return true
	return true


func _seed_inventory() -> void:
	for path in [BAG_PATH, VAULT_PATH, HERO_PATH, WALLET_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GearBag.save_path = BAG_PATH
	StillVault.save_path = VAULT_PATH
	HeroProgress.save_path = HERO_PATH
	KoliseoWallet.save_path = WALLET_PATH
	GearBag.new().save()
	HeroProgress.new().save()
	KoliseoWallet.new().save()
	var vault := StillVault.new()
	vault.set_focus("kestrel")
	vault.socket = "long_shadow"
	vault.mode = "intact"
	vault.fragments = {"long_shadow": StillVault.FORGE_COST}
	vault.save()


func _shoot_inventory() -> bool:
	var detail := ""
	for child in _screen._detail.get_children():
		var label := child as Label
		if label != null:
			detail += label.text + "\n"
			print("DETAIL %s" % label.text)
	if not detail.contains("3 or more tiles"):
		return _fail("inventory is missing the 3-tile Long Shadow line: %s" % detail)
	if detail.contains("4 or more"):
		return _fail("inventory still says 4 or more")
	return _save("long_shadow_inventory.png")


func _shoot_sand_inventory() -> bool:
	var detail := ""
	for child in _screen._detail.get_children():
		var label := child as Label
		if label != null:
			detail += label.text + "\n"
			print("SAND DETAIL %s" % label.text)
	if not detail.contains("reflects 10%"):
		return _fail("inventory is missing the 10% reflect: %s" % detail)
	if not detail.contains("reflects 20%"):
		return _fail("inventory is missing the 20% reflect: %s" % detail)
	if not detail.contains("cannot be healed"):
		return _fail("inventory is missing the heal lock: %s" % detail)
	if detail.contains("stored"):
		return _fail("inventory still describes the store")
	return _save("gathered_sand_inventory.png")


func _cast_wall() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1, 1, 1, 1],
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(4, 4), Vector2i(5, 4)],
		"bastion_aegis": 4,
	})
	sim._active_seat = 0
	var bastion: Dictionary = sim._unit_by_seat(0)
	bastion["spell_elements"] = {"bash": "earth", "plant": "water", "hold_line": "earth", "snap_wall": "water", "ward": "earth"}
	bastion["aegis"] = 4
	bastion["ap"] = 6
	return _act(sim, {"type": "cast", "spell": "snap_wall", "seat": 0, "to": Vector2i(4, 5)}, "snap wall")


func _cast_bash() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim._unit_by_seat(0)["ap"] = 6
	return _act(sim, {"type": "cast", "spell": "bash", "seat": 0, "to": Vector2i(5, 4)}, "bash")


func _setup_plant() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1],
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(4, 4), Vector2i(5, 4)],
		"bastion_aegis": 2,
	})
	sim._active_seat = 0
	var bastion: Dictionary = sim._unit_by_seat(0)
	bastion["spell_elements"] = {"bash": "earth", "plant": "water", "hold_line": "earth", "snap_wall": "water", "ward": "earth"}
	bastion["ap"] = 6
	return _act(sim, {"type": "cast", "spell": "plant", "seat": 0, "to": Vector2i(4, 6)}, "plant")


func _setup_fade() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1],
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(4, 4), Vector2i(5, 4)],
	})
	sim._active_seat = 0
	var gloam: Dictionary = sim._unit_by_seat(0)
	gloam["spell_elements"] = {"cut": "air", "drop_shade": "air", "ambush": "air", "fade": "water"}
	gloam["ap"] = 6
	return _act(sim, {"type": "cast", "spell": "fade", "seat": 0, "to": Vector2i(4, 4)}, "fade")


func _setup_sand() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1],
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(4, 4), Vector2i(5, 4)],
		"seat_gear": {0: {"worn": [], "still": {"id": "gathered_sand", "mode": "intact"}}},
	})
	sim._active_seat = 1
	sim._unit_by_seat(1)["ap"] = 6
	return _act(sim, {"type": "cast", "spell": "strike", "seat": 1, "to": Vector2i(4, 4)}, "gathered sand strike")


func _shoot_sand_log() -> bool:
	var hud: CombatHUD = _board._hud
	var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
	var button := "" if hud._log_button == null else hud._log_button.text
	print("SAND LOG\n%s" % body)
	if not hud._log_open or button != "Close":
		return _fail("Gathered Sand log panel did not stay open")
	var at := body.find("Gathered Sand:")
	var tail := body.substr(at)
	var end := tail.find("\n")
	var sand_line := tail if end < 0 else tail.substr(0, end)
	if at < 0 or not sand_line.contains("reflects"):
		return _fail("log is missing the Gathered Sand reflect line: %s" % body)
	if sand_line.contains("("):
		return _fail("the reflect line has a tile: %s" % sand_line)
	print("SAND LINE %s" % sand_line)
	if not _save("gathered_sand_log.png"):
		return true
	return _crop_log("gathered_sand_log_close.png")


func _setup_vault() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 11,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1],
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(4, 4), Vector2i(5, 4)],
	})
	sim._active_seat = 0
	var kestrel: Dictionary = sim._unit_by_seat(0)
	kestrel["spell_elements"] = {"mark_shot": "air", "detonate": "air", "vault": "water", "snare_trap": "air"}
	kestrel["ap"] = 6
	return _act(sim, {"type": "cast", "spell": "vault", "seat": 0, "to": Vector2i(6, 4)}, "vault")


func _shoot_cards(file_name: String, who: String, element: String, mark: String) -> bool:
	var hud: CombatHUD = _board._hud
	hud.focus_fighter(0)
	hud._layout_chrome()
	var left := "" if hud._kestrel_body == null else hud._kestrel_body.get_parsed_text()
	var right := "" if hud._ironjaw_body == null else hud._ironjaw_body.get_parsed_text()
	var titles := ""
	for title in hud._banner_titles:
		titles += title.text + " | "
	print("TITLES %s" % titles)
	print("LEFT %s" % left.replace("\n", " | "))
	print("RIGHT %s" % right.replace("\n", " | "))
	var both := titles + "\n" + left + "\n" + right
	if not both.to_lower().contains(who):
		return _fail("%s is not on a card" % who)
	if not both.contains(element) or not both.to_lower().contains(mark):
		return _fail("%s card is missing %s %s" % [file_name, element, mark])
	return _save(file_name)


func _shoot_log() -> bool:
	var hud: CombatHUD = _board._hud
	var body := "" if hud._log_body == null else hud._log_body.get_parsed_text()
	var button := "" if hud._log_button == null else hud._log_button.text
	print("LOG\n%s" % body)
	if not hud._log_open or button != "Close":
		return _fail("log panel did not stay open")
	if not body.contains("Snap Wall: Residue Water on Kestrel"):
		return _fail("log is missing the Snap Wall residue line")
	if not body.contains("Mire:"):
		return _fail("log is missing Mire")
	var residue_at := body.find("Snap Wall: Residue Water on Kestrel")
	var mire_at := body.find("Mire:")
	if mire_at < residue_at:
		return _fail("Mire is above the Snap Wall residue line")
	if not _save("snap_wall_log.png"):
		return true
	return _crop_log("snap_wall_log_close.png")


func _crop_log(file_name: String) -> bool:
	var hud: CombatHUD = _board._hud
	var rect := Rect2()
	if hud._log_panel != null:
		rect = hud._log_panel.get_global_rect()
	var image := root.get_texture().get_image()
	var view := _board.get_viewport().get_visible_rect().size
	var scale := float(image.get_width()) / view.x
	var origin := Vector2i(int(rect.position.x * scale), int(rect.position.y * scale))
	var size := Vector2i(maxi(int(rect.size.x * scale), 1), maxi(int(rect.size.y * scale), 1))
	origin.x = clampi(origin.x, 0, image.get_width() - 1)
	origin.y = clampi(origin.y, 0, image.get_height() - 1)
	size.x = mini(size.x, image.get_width() - origin.x)
	size.y = mini(size.y, image.get_height() - origin.y)
	var crop := image.get_region(Rect2i(origin, size))
	var close := _dir.path_join(file_name)
	crop.save_png(close)
	var dark := 0
	for gy in range(1, 4):
		for gx in range(1, 4):
			var px := origin.x + size.x * gx / 4
			var py := origin.y + size.y * gy / 4
			var pixel := image.get_pixel(px, py)
			if pixel.r < 0.2 and pixel.g < 0.25 and pixel.b < 0.35:
				dark += 1
			print("PANEL PIXEL %s,%s %s" % [px, py, pixel])
	print("CROP %s %dx%d dark %d/9" % [close, crop.get_width(), crop.get_height(), dark])
	if dark < 2:
		return _fail("log crop is not the dark panel")
	return true


func _save(file_name: String) -> bool:
	var image := root.get_texture().get_image()
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	if image.get_width() != 2400 or image.get_height() != 1080:
		return _fail("phone frame is %dx%d, want 2400x1080" % [image.get_width(), image.get_height()])
	return true


func _act(sim: Node, intent: Dictionary, label: String) -> bool:
	var result: Dictionary = sim.submit(intent)
	if bool(result.get("ok", false)):
		print("OK %s" % label)
		return true
	return _fail("%s failed: %s" % [label, str(result.get("reason", result.get("coach", "")))])


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


func _fail(msg: String) -> bool:
	_failed = true
	push_error(msg)
	print("FAIL %s" % msg)
	quit(1)
	return false
