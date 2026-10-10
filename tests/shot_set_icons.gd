extends SceneTree

## 2400×1080: each class in its Legendary set, then a bag of Normal / Rare / Legendary.
## godot --rendering-driver opengl3 -s res://tests/shot_set_icons.gd -- <dir>

const LEGENDARY := {
	"bastion": "oathgrave",
	"kestrel": "ravenmourn",
	"ironjaw": "tyrantjaw",
	"gloam": "gravewhisper",
	"mender": "hallowmourn",
}
const BAG_SETS := ["undertow", "gallowsight", "ravenmourn"]

var _dir := "/opt/cursor/artifacts/set_icons"
var _frames := 0
var _phase := 0
var _class_index := 0
var _classes: Array[String] = []
var _screen: Control


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
	GearBag.save_path = "user://shot_set_icons.json"
	var bag := GearBag.new()
	bag.save()
	_classes = GearBag.CLASS_IDS.duplicate()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("set-icon shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_show_class()
		return false
	if _phase == 1:
		if _frames < 6:
			return false
		_save_class()
		return false
	if _phase == 2:
		_show_bag()
		return false
	if _phase == 3:
		if _frames < 6:
			return false
		_save_bag()
		return true
	return true


func _show_class() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		_screen = null
	var cid := _classes[_class_index]
	var fam := str(LEGENDARY[cid])
	_screen = (load("res://scenes/gear_screen.gd") as Script).new()
	_screen.name = "GearShot"
	root.add_child(_screen)
	var result: Dictionary = _screen._bag.debug_equip_set(cid, fam)
	_screen._refresh()
	_hide_debug()
	print("EQUIP %s %s ok=%s header=%s" % [cid, fam, result.get("ok", false), _screen.header_text()])
	for slot in GearBag.SLOTS:
		var button := _screen.find_child("Slot_" + slot, true, false) as Button
		var icon_name := ""
		if button != null and button.icon != null:
			icon_name = button.icon.resource_path.get_file()
		print("SLOT %s %s icon=%s" % [slot, button.text if button != null else "MISSING", icon_name])
		if button == null or button.icon == null or not icon_name.begins_with(fam + "_"):
			push_error("%s %s is missing its own icon (%s)" % [cid, slot, icon_name])
	if not bool(result.get("ok", false)):
		push_error("debug equip failed for %s" % cid)
	_phase = 1
	_frames = 0


func _save_class() -> void:
	var cid := _classes[_class_index]
	var image := _frame()
	var path := _dir.path_join("gear_%s.png" % cid)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	_class_index += 1
	if _class_index < _classes.size():
		_phase = 0
		_frames = 0
		return
	_screen.queue_free()
	_screen = null
	_phase = 2
	_frames = 0


func _show_bag() -> void:
	_screen = (load("res://scenes/gear_screen.gd") as Script).new()
	_screen.name = "BagShot"
	root.add_child(_screen)
	_screen._bag.set_focus("kestrel")
	for fam in BAG_SETS:
		for slot in GearBag.SLOTS:
			_screen._bag.add_item(fam, slot, 0)
	_screen._bag.save()
	_screen._refresh()
	_hide_debug()
	print("BAG header=%s" % _screen.header_text())
	var seen := {}
	for child in _screen._bag_box.get_children():
		for sub in child.get_children():
			if not (sub is Button) or not str(sub.name).begins_with("Item_"):
				continue
			var button := sub as Button
			var icon_name := button.icon.resource_path.get_file() if button.icon != null else ""
			print("BAG %s icon=%s" % [button.text, icon_name])
			for fam in BAG_SETS:
				if icon_name.begins_with(fam + "_"):
					seen[fam] = true
	for fam in BAG_SETS:
		if not bool(seen.get(fam, false)):
			push_error("bag is missing %s art" % fam)
	_phase = 3
	_frames = 0


func _save_bag() -> void:
	var image := _frame()
	var path := _dir.path_join("bag_rarities.png")
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])


func _hide_debug() -> void:
	for child in _screen._sets_box.get_children():
		var label := child as Label
		if label != null and label.text.begins_with("Debug review"):
			label.visible = false
		if str(child.name).begins_with("DebugSet_"):
			child.visible = false


func _frame() -> Image:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized to 2400x1080")
	return image
