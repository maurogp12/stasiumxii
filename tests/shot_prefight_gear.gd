extends SceneTree

## Deployment HUD and the one inventory screen (Equipment, Elements, Stills, Sets).
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
	if _frames > 360:
		push_error("prefight shot timed out in phase %d" % _phase)
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
		if _frames < 10:
			return false
		_expect_deploy_hud(hud)
		_shot("deploy_hud.png")
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
		_expect_equipment(screen)
		_shot("inventory_equipment.png")
		screen.set_rarity_filter("Legendary")
		_phase = 9
		_frames = 0
		return false
	if _phase == 9:
		if _frames < 4:
			return false
		var screen := _inventory()
		if screen == null or screen.rarity_filter != "Legendary":
			push_error("legendary filter did not stick")
			return true
		_expect_rarity(screen, "Legendary")
		_shot("inventory_filter_legendary.png")
		screen.set_rarity_filter("Ultra")
		_phase = 10
		_frames = 0
		return false
	if _phase == 10:
		if _frames < 4:
			return false
		var screen := _inventory()
		if screen == null or screen.rarity_filter != "Ultra":
			push_error("ultra filter did not stick")
			return true
		_expect_rarity(screen, "Ultra")
		_shot("inventory_filter_ultra.png")
		screen.set_rarity_filter("")
		screen.show_tab("elements")
		_phase = 3
		_frames = 0
		return false
	if _phase == 3:
		if _frames < 6:
			return false
		var screen := _inventory()
		if screen == null or screen.find_child("Element_air", true, false) == null:
			push_error("elements tab missing")
			return true
		_shot("inventory_elements.png")
		screen.show_tab("stills")
		screen.select({"kind": "still", "id": "tide"})
		_phase = 4
		_frames = 0
		return false
	if _phase == 4:
		if _frames < 4:
			return false
		var screen := _inventory()
		var swap: Button = null
		if screen != null:
			swap = screen.find_child("SocketStill", true, false) as Button
		if swap == null or swap.text != "Swap in":
			push_error("swap button missing")
			return true
		print("SWAP %s disabled=%s" % [swap.text, swap.disabled])
		_shot("inventory_stills_swap.png")
		screen.socket_still("tide")
		_phase = 5
		_frames = 0
		return false
	if _phase == 5:
		if _frames < 4:
			return false
		var screen := _inventory()
		if screen == null:
			push_error("inventory closed during swap")
			return true
		if StillVault.load_saved().socket_of("bastion") != "tide":
			push_error("socket did not become tide")
			return true
		_shot("inventory_stills_socketed.png")
		screen.show_tab("sets")
		_phase = 6
		_frames = 0
		return false
	if _phase == 6:
		if _frames < 6:
			return false
		var screen := _inventory()
		var sets := screen.find_child("GearScreen", true, false) if screen != null else null
		if sets == null or sets.find_child("Stance_neutral", true, false) == null:
			push_error("sets tab missing stance")
			return true
		_shot("inventory_sets.png")
		screen.close()
		_phase = 7
		_frames = 0
		return false
	if _phase == 7:
		if _frames < 4:
			return false
		if _inventory() != null:
			push_error("inventory still open")
			return true
		var sim: Node = root.get_node("/root/CombatSim")
		var a: Array = sim.legal_deploy_cells(0)
		var b: Array = sim.legal_deploy_cells(1)
		if a.is_empty() or b.is_empty():
			push_error("deploy zones empty")
			return true
		sim.place_unit(0, a[0])
		sim.place_unit(1, b[0])
		sim.ready_seat(0)
		sim.ready_seat(1)
		_board._rebuild_pawns()
		_board._refresh()
		_phase = 8
		_frames = 0
		return false
	if _phase == 8:
		if _frames < 8:
			return false
		var sim: Node = root.get_node("/root/CombatSim")
		if str(sim.snapshot().get("phase", "")) == "DEPLOYMENT":
			push_error("still deploying")
			return true
		_expect_combat_hud(hud)
		_shot("combat_hud.png")
		return true
	return false


func _inventory() -> InventoryScreen:
	return _board._hud.get_node_or_null("InventoryScreen") as InventoryScreen


func _expect_deploy_hud(hud: Node) -> void:
	var gear: Button = hud._gear_button
	var ready: Button = hud._ready_p2_button
	print("GEAR visible=%s parent=%s" % [gear.visible, gear.get_parent().name if gear.get_parent() != null else "none"])
	print("ELEMENTS parent=%s visible=%s" % [hud._elements_button.get_parent(), hud._elements_button.visible])
	print("READY text=%s visible=%s pos=%s size=%s row=%s" % [
		ready.text, ready.visible, ready.global_position, ready.size, hud._ready_row.global_position,
	])
	if not gear.visible or gear.get_parent().name != "SideColumn":
		push_error("gear should be the deployment button")
	if hud._elements_button.get_parent() != null or hud._elements_button.visible:
		push_error("elements button should be gone")
	if not ready.visible or ready.get_parent().name != "ReadyRow":
		push_error("ready should be in the centered row")
	var row: Control = hud._ready_row
	var view_x := 1600.0
	var mid := row.global_position.x + row.size.x * 0.5
	print("READY mid=%s" % mid)
	if absf(mid - view_x * 0.5) > 80.0:
		push_error("ready row is not centered (%s)" % mid)


func _expect_equipment(screen: InventoryScreen) -> void:
	var header := screen.find_child("InventoryHeader", true, false) as Label
	print("HEADER %s" % (header.text if header != null else "MISSING"))
	for name in ["Champ_bastion", "Champ_kestrel", "Tab_equipment", "Tab_elements", "Tab_stills", "Tab_sets", "Slot_weapon", "Socket"]:
		if screen.find_child(name, true, false) == null:
			push_error("missing %s" % name)
	for name in ["Champ_ironjaw", "Tab_consumables", "Tab_cosmetics", "OpenElements", "OpenSets"]:
		if screen.find_child(name, true, false) != null:
			push_error("should be hidden: %s" % name)


func _expect_rarity(screen: InventoryScreen, rarity: String) -> void:
	var node := "RarityUltra" if rarity == "Ultra" else "Rarity" + rarity
	var label := "Ultra Legendary" if rarity == "Ultra" else rarity
	var button := screen.find_child(node, true, false) as Button
	if button == null or button.text != label:
		push_error("filter button %s missing" % label)
		return
	print("FILTER BUTTON %s" % button.text)
	var grid := screen.find_child("ItemGrid", true, false)
	var count := 0
	if grid == null:
		push_error("item grid missing")
		return
	for child in grid.get_children():
		var tile_name := str(child.name)
		if not tile_name.begins_with("Item_"):
			continue
		count += 1
		var item: Dictionary = screen.bag().item(tile_name.trim_prefix("Item_").to_int())
		var got := str(GearBag.FAMILIES.get(GearBag.family_of(str(item.get("item_id", ""))), {}).get("rarity", ""))
		if got != rarity:
			push_error("tile %s is %s, wanted %s" % [str(item.get("item_id", "")), got, rarity])
	print("FILTER %s tiles=%d" % [rarity, count])
	if count == 0:
		push_error("filter %s showed no pieces" % rarity)


func _expect_combat_hud(hud: Node) -> void:
	print("COMBAT gear=%s ready=%s elements=%s row=%s" % [
		hud._gear_button.visible, hud._ready_p1_button.visible, hud._elements_button.visible, hud._ready_row.visible,
	])
	if hud._gear_button.visible or hud._ready_p1_button.visible or hud._ready_row.visible or hud._elements_button.visible:
		push_error("deployment chrome still visible after combat start")


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
	for id in StillVault.IDS:
		vault.fragments[id] = 24
	vault.set_focus("bastion")
	vault.socket = "gathered_sand"
	vault.set_mode("intact")
	vault.save()
