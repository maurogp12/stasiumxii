extends SceneTree

## 2400×1080: Koliseo Ultra stall, each class in full Ultra (gold PvP tags),
## the same sheet greyed for a dungeon, and Hushring's 3-turn Fade.
## godot --rendering-driver opengl3 -s res://tests/shot_ultra.gd -- <dir>

const ULTRA := {
	"bastion": "gatewarden",
	"kestrel": "sandhawk",
	"ironjaw": "pitmaw",
	"gloam": "hushring",
	"mender": "mercywell",
}

var _dir := "/opt/cursor/artifacts/ultra_sets"
var _frames := 0
var _phase := 0
var _class_index := 0
var _classes: Array[String] = []
var _screen: Control
var _shop: Control
var _mode := "pvp"


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
	GearBag.save_path = "user://shot_ultra_bag.json"
	KoliseoWallet.save_path = "user://shot_ultra_wallet.json"
	var bag := GearBag.new()
	bag.save()
	var wallet := KoliseoWallet.new()
	wallet.coins = 200
	wallet.save()
	_classes = GearBag.CLASS_IDS.duplicate()
	HeroProgress.save_path = "user://shot_ultra_hero.json"
	var heroes := HeroProgress.new()
	heroes.save()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 500:
		push_error("ultra shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		if _shop == null:
			_show_shop()
			return false
		if _frames < 4:
			return false
		_save_shop()
		return false
	if _phase == 1:
		_show_gear()
		return false
	if _phase == 2:
		if _frames < 4:
			return false
		_save_gear()
		return false
	if _phase == 3:
		return _combat_boot()
	if _phase == 4:
		if _frames < 8:
			return false
		_save_combat()
		return true
	return true


func _show_shop() -> void:
	_shop = (load("res://scenes/koliseo_shop.gd") as Script).new()
	_shop.name = "UltraShopShot"
	root.add_child(_shop)
	_shop.select_ultra_class("bastion")
	print("SHOP header=%s" % _shop._header.text)
	for cid in GearBag.CLASS_IDS:
		var tab := _shop.find_child("UltraTab_%s" % cid, true, false)
		print("TAB %s %s" % [cid, tab.text if tab != null else "MISSING"])
	var family := str(GearBag.ULTRA_BY_CLASS.get("bastion", ""))
	for slot in GearBag.SLOTS:
		var button := _shop.find_child("UltraSlot_%s" % slot, true, false)
		var item_id := GearBag.item_id_for(family, slot)
		print("ULTRA_SLOT %s %s" % [slot, button.text if button != null else "MISSING"])
		if button == null or not str(button.text).contains("30 coins"):
			push_error("ultra slot %s is not priced at 30" % slot)
		if button == null or not str(button.text).contains(str(GearBag.PARTS[item_id]["name"])):
			push_error("ultra slot %s is missing its part name" % slot)
	_phase = 0
	_frames = 0


func _save_shop() -> void:
	var path := _dir.path_join("koliseo_ultra_shop.png")
	_save(path)
	_shop.queue_free()
	_shop = null
	_phase = 1
	_frames = 0


func _show_gear() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		_screen = null
	var cid := _classes[_class_index]
	var fam := str(ULTRA[cid])
	_screen = (load("res://scenes/gear_screen.gd") as Script).new()
	_screen.name = "UltraGearShot"
	root.add_child(_screen)
	var result: Dictionary = _screen._bag.debug_equip_set(cid, fam)
	_screen.set_pvp_lines(_mode == "pvp")
	for child in _screen._sets_box.get_children():
		var label := child as Label
		if label != null and label.text.begins_with("Debug review"):
			label.visible = false
		if str(child.name).begins_with("DebugSet_"):
			child.visible = false
	print("EQUIP %s %s mode=%s ok=%s header=%s" % [cid, fam, _mode, result.get("ok", false), _screen.header_text()])
	var saw_tag := false
	for child in _screen._sets_box.get_children():
		var label := child as Label
		if label == null or not label.visible:
			continue
		print("LINE %s color=%s" % [label.text.replace("\n", " "), label.get_theme_color("font_color")])
		if label.text.contains("PvP"):
			saw_tag = true
	if not bool(result.get("ok", false)):
		push_error("debug equip failed for %s" % cid)
	if not saw_tag:
		push_error("%s sheet is missing the PvP tag" % cid)
	var header := str(_screen.header_text())
	if _mode == "pvp" and not header.contains("AP 7/"):
		push_error("%s PvP header is missing +1 AP: %s" % [cid, header])
	if _mode == "dungeon" and not header.contains("AP 6/"):
		push_error("%s dungeon header still shows the Ultra AP: %s" % [cid, header])
	_phase = 2
	_frames = 0


func _save_gear() -> void:
	var cid := _classes[_class_index]
	var path := _dir.path_join("gear_%s_%s.png" % [cid, _mode])
	_save(path)
	if _mode == "pvp":
		_mode = "dungeon"
		_phase = 1
		_frames = 0
		return
	_mode = "pvp"
	_class_index += 1
	if _class_index < _classes.size():
		_phase = 1
		_frames = 0
		return
	_screen.queue_free()
	_screen = null
	change_scene_to_file("res://main.tscn")
	_phase = 3
	_frames = 0


func _combat_boot() -> bool:
	if _frames < 2:
		return false
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	var pair := _pair(sim)
	if pair.size() < 2:
		push_error("no open Fade pair")
		return true
	sim.reset_match({
		"seed": 1,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"classes": ["gloam", "mender"],
		"positions": pair,
		"gloam_facing": "E",
		"mender_facing": "W",
	})
	var bag := GearBag.new()
	var equipped: Dictionary = bag.debug_equip_set("gloam", "hushring")
	if not bool(equipped.get("ok", false)):
		push_error("combat debug equip failed")
		return true
	var gloam: Dictionary = sim._unit_by_seat(0)
	var gear: Dictionary = bag.fight_gear(false, "gloam")
	gear["flatten_plus"] = true
	sim._apply_gear(gloam, gear)
	print("FADE_GEAR long_fade=%s ap=%s" % [gloam.get("long_fade", 0), gloam.get("max_ap", 0)])
	var faded: Dictionary = sim.submit({"type": "cast", "spell": "fade", "to": gloam["pos"], "seat": 0})
	print("FADE %s" % JSON.stringify(faded))
	print("INVISIBLE_TURNS %s" % gloam.get("invisible_turns", 0))
	if not bool(faded.get("ok", false)) or int(gloam.get("invisible_turns", 0)) != 3:
		push_error("Hushring Fade did not last 3 turns")
		return true
	board._rebuild_pawns()
	board._refresh()
	if board._camera != null:
		board._camera.zoom = Vector2(1.6, 1.6)
		board._center_on_cell(pair[0])
	board._arm_vfx(faded.get("events", []))
	_phase = 4
	_frames = 0
	return false


func _save_combat() -> void:
	var sim: Node = root.get_node("CombatSim")
	var coach := str(sim.snapshot().get("coach", ""))
	print("FADE_COACH %s" % coach)
	var path := _dir.path_join("hushring_fade.png")
	_save(path)
	if not coach.contains("3 turn"):
		push_error("coach does not say the Fade lasts 3 turns: %s" % coach)


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized to 2400x1080")
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])


func _pair(sim: Node) -> Array:
	sim.reset_match({"seed": 1, "map_id": "slagcrown", "skip_deploy": true, "classes": ["gloam", "mender"]})
	var n := int(sim.snapshot().get("board_size", 15))
	for y in range(4, n - 4):
		for x in range(4, n - 4):
			var a := Vector2i(x, y)
			var b := Vector2i(x + 1, y)
			if _open(sim, a) and _open(sim, b):
				print("PAIR %s %s" % [a, b])
				return [a, b]
	return []


func _open(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"
