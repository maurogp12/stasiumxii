extends SceneTree

## 2400×1080: Inventory with Ironjaw's Still, then Kestrel's different Still.
## godot --rendering-driver opengl3 -s res://tests/shot_class_stills.gd -- <dir>

const BAG_PATH := "user://shot_class_stills_bag.json"
const VAULT_PATH := "user://shot_class_stills_vault.json"
const HERO_PATH := "user://shot_class_stills_hero.json"
const WALLET_PATH := "user://shot_class_stills_wallet.json"

var _dir := "/opt/cursor/artifacts/class_stills"
var _frames := 0
var _phase := 0
var _screen: InventoryScreen


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
	_seed()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 180:
		push_error("class still shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_screen = (load("res://scenes/inventory_screen.gd") as Script).new()
		_screen.name = "InventoryShot"
		root.add_child(_screen)
		_show("ironjaw", "mirror_hour")
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		_save("inventory_ironjaw.png")
		_log("ironjaw")
		_show("kestrel", "tide")
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		if _frames < 8:
			return false
		_save("inventory_kestrel.png")
		_log("kestrel")
		return true
	return true


func _seed() -> void:
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
	vault.set_focus("ironjaw")
	vault.socket = "mirror_hour"
	vault.mode = "overwound"
	vault.set_focus("kestrel")
	vault.socket = "tide"
	vault.mode = "intact"
	vault.fragments = {"mirror_hour": 20, "tide": 20}
	vault.save()


func _show(class_id: String, still_id: String) -> void:
	_screen.pick_champion(class_id)
	_screen.show_tab("stills")
	_screen.select({"kind": "still", "id": still_id})


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized %s" % file_name)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])


func _log(class_id: String) -> void:
	var level := _screen.find_child("ChampionLevel", true, false) as Label
	var head := _screen.find_child("StillHead", true, false) as Label
	var sock := _screen.find_child("Socket", true, false)
	print("CLASS %s LEVEL %s" % [class_id, level.text if level != null else "MISSING"])
	print("HEAD %s" % (head.text if head != null else "MISSING"))
	print("SOCKET filled=%s badge=%s" % [sock.filled if sock != null else false, sock.badge if sock != null else ""])
	for child in _screen._detail.get_children():
		var label := child as Label
		if label != null:
			print("DETAIL %s" % label.text)
	if level == null or not level.text.begins_with(SpellKits.display_name(class_id)):
		push_error("inventory is not showing %s" % class_id)
	if sock == null or not sock.filled:
		push_error("%s socket is empty" % class_id)
