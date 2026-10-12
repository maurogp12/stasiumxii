extends SceneTree

## Deployment inventory on the fight screen.
## DISPLAY=:1 godot --path . --rendering-driver opengl3 -s res://tests/shot_prefight_gear.gd

const OUT := "/opt/cursor/artifacts/prefight_gear"

var _frames := 0
var _phase := 0
var _board: Node = null


func _initialize() -> void:
	GearBag.save_path = "user://shot_prefight_gear.json"
	StillVault.save_path = "user://shot_prefight_stills.json"
	HeroProgress.save_path = "user://shot_prefight_hero.json"
	_seed_loadout()
	var select: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["bastion", "kestrel"]
	select.set("hotseat_classes", pair)
	select.set("hotseat_team_size", 1)
	select.set("hotseat_map_id", "crosshaven")
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1600, 720))
	root.size = Vector2i(1600, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("prefight inventory shot timed out in phase %d" % _phase)
		return true
	if _board == null:
		_board = current_scene.get_node_or_null("BoardView") if current_scene != null else null
		return false
	var hud: Node = _board._hud
	if hud == null or hud._gear_button == null:
		return false
	if _phase == 0:
		if not bool(_board.get("_booted")):
			return false
		var sim: Node = root.get_node("/root/CombatSim")
		var bag := GearBag.load_saved()
		var seat_gear := {}
		for seat in [0, 1]:
			var cid := "bastion" if seat == 0 else "kestrel"
			var kit := bag.fight_gear(true, cid)
			kit["flatten_plus"] = true
			seat_gear[seat] = kit
		sim.reset_match({
			"seed": 1,
			"flat_board": true,
			"classes": ["bastion", "kestrel"],
			"first_by_init": true,
			"seat_gear": seat_gear,
		})
		_board._rebuild_pawns()
		_board._refresh()
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		_board._on_gear_requested()
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		if _frames < 8:
			return false
		var screen := _inventory()
		if screen == null:
			push_error("inventory did not open")
			return true
		_expect_worn(screen)
		_shot("prefight_inventory_worn.png")
		var uid := _loose_uid(screen)
		if uid < 0:
			push_error("no loose piece to equip")
			return true
		screen.select({"kind": "item", "uid": uid})
		_phase = 3
		_frames = 0
		return false
	if _phase == 3:
		if _frames < 4:
			return false
		var screen := _inventory()
		if screen == null:
			push_error("inventory closed before Wear")
			return true
		var wear := screen.find_child("Wear", true, false) as Button
		if wear == null:
			push_error("Wear button missing")
			return true
		print("WEAR %s" % wear.text)
		_shot("prefight_inventory_wear.png")
		screen.select({})
		screen.choose_stance("ranged_guard")
		_phase = 4
		_frames = 0
		return false
	if _phase == 4:
		if _frames < 4:
			return false
		var screen := _inventory()
		if screen == null:
			push_error("inventory closed before stance")
			return true
		_expect_stance(screen)
		_shot("prefight_inventory_stance.png")
		return true
	return false


func _inventory() -> InventoryScreen:
	return _board._hud.get_node_or_null("InventoryScreen") as InventoryScreen


func _loose_uid(screen: InventoryScreen) -> int:
	for it in screen.bag().items:
		var uid := int(it["uid"])
		if screen.bag().is_equipped(uid):
			continue
		if GearBag.family_of(str(it["item_id"])) == "ironveil":
			return uid
	return -1


func _expect_worn(screen: InventoryScreen) -> void:
	var header := screen.find_child("InventoryHeader", true, false) as Label
	print("HEADER %s" % (header.text if header != null else "MISSING"))
	if header == null or header.text != "Inventory":
		push_error("header is %s" % (header.text if header != null else "missing"))
	for name in ["Champ_bastion", "Champ_kestrel", "Tab_equipment", "Tab_stills", "Slot_head", "Slot_weapon", "Socket", "OpenSets"]:
		if screen.find_child(name, true, false) == null:
			push_error("missing %s" % name)
	for name in ["Champ_ironjaw", "Tab_consumables", "Tab_cosmetics"]:
		if screen.find_child(name, true, false) != null:
			push_error("should be hidden: %s" % name)
	if screen.find_child("Stance_neutral", true, false) == null or screen.find_child("Stance_ranged_guard", true, false) == null:
		push_error("stance buttons missing on the worn view")


func _expect_stance(screen: InventoryScreen) -> void:
	for name in ["Stance_neutral", "Stance_ranged_guard", "Champ_bastion"]:
		var button := screen.find_child(name, true, false) as Button
		if button == null:
			push_error("missing %s" % name)
			continue
		print("BUTTON %s text=%s" % [name, button.text])
	var line := screen.find_child("StanceLine", true, false) as Label
	print("STANCE %s" % (line.text if line != null else "MISSING"))
	if line == null or not line.text.contains("20%") or not line.text.contains("15%"):
		push_error("ranged line is %s" % (line.text if line != null else "missing"))
	if str(GearBag.load_saved().stance_of()) != "ranged_guard":
		push_error("saved stance is %s" % GearBag.load_saved().stance_of())


func _shot(file_name: String) -> void:
	DisplayServer.window_set_size(Vector2i(1600, 720))
	var texture := root.get_texture()
	if texture == null:
		push_error("viewport texture is null for %s" % file_name)
		return
	var image := texture.get_image()
	if image == null:
		push_error("viewport image is null for %s" % file_name)
		return
	if image.get_width() != 1600 or image.get_height() != 720:
		image.resize(1600, 720, Image.INTERPOLATE_BILINEAR)
		print("resized %s from %dx%d" % [file_name, image.get_width(), image.get_height()])
	var path := OUT.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])


func _seed_loadout() -> void:
	var bag := GearBag.new()
	for fam in ["ashmantle", "rustward", "ironveil", "oathgrave", "gatewarden", "brightedge", "undertow", "gallowsight", "ravenmourn", "sandhawk"]:
		for slot in GearBag.SLOTS:
			bag.add_item(fam, slot, 5)
	bag.wear_family("bastion", "gatewarden")
	bag.wear_family("kestrel", "sandhawk")
	bag.set_stance("neutral")
	bag.save()
	var vault := StillVault.new()
	vault.set_focus("bastion")
	vault.socket = "gathered_sand"
	vault.set_mode("intact")
	vault.save()
