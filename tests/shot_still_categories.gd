extends SceneTree

## Stills tab with the category filter on Offensive, then Defensive.
## DISPLAY=:1 godot --path . --rendering-driver opengl3 -s res://tests/shot_still_categories.gd

const OUT := "/opt/cursor/artifacts/still_categories"

var _frames := 0
var _phase := 0
var _board: Node = null


func _initialize() -> void:
	GearBag.save_path = "user://shot_still_cat_gear.json"
	StillVault.save_path = "user://shot_still_cat_stills.json"
	HeroProgress.save_path = "user://shot_still_cat_hero.json"
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
		push_error("still category shot timed out in phase %d" % _phase)
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
		screen.show_tab("stills")
		screen.set_still_filter("offensive")
		_phase = 3
		_frames = 0
		return false
	if _phase == 3:
		if _frames < 4:
			return false
		var screen := _inventory()
		if screen == null or screen.still_filter != "offensive":
			push_error("offensive filter did not stick")
			return true
		_expect_filter(screen, "offensive")
		_shot("stills_filter_offensive.png")
		screen.set_still_filter("defensive")
		_phase = 4
		_frames = 0
		return false
	if _phase == 4:
		if _frames < 4:
			return false
		var screen := _inventory()
		if screen == null or screen.still_filter != "defensive":
			push_error("defensive filter did not stick")
			return true
		_expect_filter(screen, "defensive")
		_shot("stills_filter_defensive.png")
		return true
	return false


func _inventory() -> InventoryScreen:
	return _board._hud.get_node_or_null("InventoryScreen") as InventoryScreen


func _expect_filter(screen: InventoryScreen, category: String) -> void:
	var grid := screen.find_child("ItemGrid", true, false)
	if grid == null:
		push_error("still grid missing")
		return
	var count := 0
	for child in grid.get_children():
		var tile_name := str(child.name)
		if not tile_name.begins_with("Still_"):
			continue
		count += 1
		var id := tile_name.trim_prefix("Still_")
		var got := StillVault.category_of(id)
		if got != category:
			push_error("tile %s is %s, wanted %s" % [id, got, category])
		if str(child.tag) != StillVault.category_label(category):
			push_error("tile %s tag is %s" % [id, child.tag])
	print("FILTER %s tiles=%d" % [category, count])
	if count == 0:
		push_error("filter %s showed no Stills" % category)


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
