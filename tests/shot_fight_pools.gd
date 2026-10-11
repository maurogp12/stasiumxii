extends SceneTree

## 2400×1080: Windmere, Kestrel vs Ironjaw, after the Ultra 5pc counts.
## Kestrel's card is 8 AP / 3 MP (level, Sandhawk, Hourglass Fist Intact).
## Ironjaw's card is 7 AP / 5 MP (level, Pitmaw, Hourglass Step Intact).
## godot --rendering-driver opengl3 -s res://tests/shot_fight_pools.gd -- <dir>

const BAG_PATH := "user://shot_fight_pools_bag.json"
const VAULT_PATH := "user://shot_fight_pools_vault.json"
const HERO_PATH := "user://shot_fight_pools_hero.json"

var _dir := "/opt/cursor/artifacts/fight_pools"
var _frames := 0
var _phase := 0
var _board: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("fight pool shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_board = current_scene.get_node_or_null("BoardView") if current_scene != null else null
		if _board == null or not bool(_board._booted):
			return false
		if not _arm():
			return true
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		_save("fight_cards.png")
		_log()
		return true
	return true


func _arm() -> bool:
	_seed()
	var select: Script = load("res://scenes/class_select.gd")
	select.hotseat_team_size = 1
	var roster: Array[String] = ["kestrel", "ironjaw"]
	select.hotseat_classes = roster
	select.hotseat_map_id = "windmere"
	var config: Dictionary = select.local_match_config()
	config["seed"] = 3
	config["skip_deploy"] = true
	config["positions"] = [Vector2i(4, 8), Vector2i(10, 8)]
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match(config)
	var kite: Dictionary = sim._unit_by_seat(0)
	var jaw: Dictionary = sim._unit_by_seat(1)
	print("POOLS kestrel %d/%d ironjaw %d/%d stills %s %s" % [
		int(kite.get("ap", -1)), int(kite.get("mp", -1)),
		int(jaw.get("ap", -1)), int(jaw.get("mp", -1)),
		str(kite.get("still", "")), str(jaw.get("still", "")),
	])
	if [int(kite.get("ap", -1)), int(kite.get("mp", -1))] != [8, 3]:
		push_error("Kestrel card is not 8 AP / 3 MP")
		return false
	if [int(jaw.get("ap", -1)), int(jaw.get("mp", -1))] != [7, 5]:
		push_error("Ironjaw card is not 7 AP / 5 MP")
		return false
	_board._rebuild_grid(15)
	_board._rebuild_pawns()
	_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera()
	return true


func _seed() -> void:
	for path in [BAG_PATH, VAULT_PATH, HERO_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GearBag.save_path = BAG_PATH
	StillVault.save_path = VAULT_PATH
	HeroProgress.save_path = HERO_PATH
	var bag := GearBag.new()
	for slot in GearBag.SLOTS:
		bag.equip(bag.add_item("sandhawk", slot, 5), "kestrel")
		bag.equip(bag.add_item("pitmaw", slot, 5), "ironjaw")
	bag.save()
	var hero := HeroProgress.new()
	hero.classes = {
		"kestrel": {"xp": 0, "level": 30, "spent": {}},
		"ironjaw": {"xp": 0, "level": 30, "spent": {}},
		"mender": {"xp": 0, "level": 1, "spent": {}},
		"gloam": {"xp": 0, "level": 1, "spent": {}},
		"bastion": {"xp": 0, "level": 1, "spent": {}},
	}
	hero.save()
	var vault := StillVault.new()
	vault.set_focus("kestrel")
	vault.socket = "hourglass_fist"
	vault.mode = "intact"
	vault.set_focus("ironjaw")
	vault.socket = "hourglass_step"
	vault.mode = "intact"
	vault.save()


func _log() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null:
		push_error("hud missing")
		return
	print("LEFT %s" % hud._kestrel_body.text)
	print("RIGHT %s" % hud._ironjaw_body.text)
	if not hud._kestrel_body.text.contains("AP 8  MP 3"):
		push_error("left card text is not AP 8 MP 3")
	if not hud._ironjaw_body.text.contains("AP 7  MP 5"):
		push_error("right card text is not AP 7 MP 5")


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized %s" % file_name)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
