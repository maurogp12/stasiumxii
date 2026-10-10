extends SceneTree

## 2400×1080: the test-kit gear bag (every set, including Ultra, at +5)
## and the Stills vault ready to forge and swap.
## godot --rendering-driver opengl3 -s res://tests/shot_test_kit.gd -- <dir>

const BAG_PATH := "user://shot_test_kit_bag.json"
const VAULT_PATH := "user://shot_test_kit_vault.json"
const HERO_PATH := "user://shot_test_kit_hero.json"

var _dir := "/opt/cursor/artifacts/test_kit"
var _frames := 0
var _phase := 0
var _gear: Control
var _stills: Control


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
	if _frames > 240:
		push_error("test-kit shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_show_gear()
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		_scroll_bag()
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		if _frames < 4:
			return false
		_save("gear_bag.png")
		_log_gear()
		_gear.queue_free()
		_gear = null
		_phase = 3
		_frames = 0
		return false
	if _phase == 3:
		_show_stills()
		return false
	if _phase == 4:
		if _frames < 8:
			return false
		_save("stills_vault.png")
		_log_stills()
		return true
	return true


func _seed() -> void:
	var TL := preload("res://backend/test_loadout.gd")
	for path in [BAG_PATH, VAULT_PATH, HERO_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GearBag.save_path = BAG_PATH
	StillVault.save_path = VAULT_PATH
	HeroProgress.save_path = HERO_PATH
	var bag := GearBag.new()
	if not TL.sync_bag(bag):
		push_error("bag grant failed")
	for slot in GearBag.SLOTS:
		for it in bag.items:
			if str(it["item_id"]) == "sandhawk.%s" % slot:
				bag.equip(int(it["uid"]), "kestrel")
	bag.save()
	var vault := StillVault.new()
	if not TL.sync_vault(vault):
		push_error("vault grant failed")
	vault.forge("steadfast")
	vault.set_mode("overwound")
	vault.save()


func _show_gear() -> void:
	_gear = (load("res://scenes/gear_screen.gd") as Script).new()
	_gear.name = "GearShot"
	root.add_child(_gear)
	_phase = 1
	_frames = 0


func _scroll_bag() -> void:
	var anchor: Button = null
	for it in _gear._bag.items:
		if str(it["item_id"]) == "gatewarden.weapon":
			anchor = _gear.find_child("Item_%d" % int(it["uid"]), true, false) as Button
	var scroll := _gear._bag_box.get_parent() as ScrollContainer
	if anchor != null and scroll != null:
		var row := anchor.get_parent() as Control
		scroll.scroll_vertical = int(row.position.y) - 80
		print("ANCHOR_Y %s SCROLL_MAX %s" % [row.position.y, scroll.get_v_scroll_bar().max_value])
	for child in _gear._sets_box.get_children():
		if str(child.name).begins_with("DebugSet_"):
			child.visible = false
		var label := child as Label
		if label != null and label.text.begins_with("Debug review"):
			label.visible = false


func _show_stills() -> void:
	_stills = (load("res://scenes/stills_screen.gd") as Script).new()
	_stills.name = "StillsShot"
	root.add_child(_stills)
	_stills.pick("mirror_hour")
	_phase = 4
	_frames = 0


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized %s" % file_name)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])


func _log_gear() -> void:
	print("HEADER %s" % _gear.header_text())
	var scroll := _gear._bag_box.get_parent() as ScrollContainer
	print("BAG_SCROLL %s" % scroll.scroll_vertical)
	var shown := 0
	for child in _gear._bag_box.get_children():
		for sub in child.get_children():
			if sub is Button and str(sub.name).begins_with("Item_"):
				var top: float = sub.global_position.y
				if top > 80.0 and top < 1040.0:
					print("ROW %s" % sub.text)
					shown += 1
	print("VISIBLE_ROWS %d" % shown)
	for child in _gear._sets_box.get_children():
		var label := child as Label
		if label != null and label.visible:
			print("BONUS %s" % label.text.replace("\n", " "))


func _log_stills() -> void:
	var forge := _stills.find_child("Forge", true, false) as Button
	var note := _stills.find_child("KitSwap", true, false) as Label
	var socket := _stills.find_child("SocketLabel", true, false) as Label
	print("FORGE %s disabled=%s" % [forge.text if forge != null else "MISSING", forge.disabled if forge != null else true])
	print("NOTE %s" % (note.text if note != null else "MISSING"))
	print("SOCKET %s" % (socket.text if socket != null else "MISSING"))
	for id in StillVault.IDS:
		var tile = _stills.find_child("Still_" + id, true, false)
		if tile == null:
			push_error("missing tile %s" % id)
			continue
		print("TILE %s count=%d" % [id, tile.count])
	if forge == null or forge.disabled or not forge.text.begins_with("Swap to"):
		push_error("vault is not ready to swap")
	if note == null:
		push_error("kit swap note missing")
