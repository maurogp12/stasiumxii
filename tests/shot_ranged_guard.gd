extends SceneTree

## Pre-fight inventory: Gatewarden Ranged Guard names 15% less and 10% more.
## DISPLAY=:1 godot --path . --rendering-driver opengl3 -s res://tests/shot_ranged_guard.gd

const OUT := "/opt/cursor/artifacts/ranged_guard"

var _frames := 0
var _phase := 0
var _board: Node = null


func _initialize() -> void:
	GearBag.save_path = "user://shot_ranged_guard_gear.json"
	StillVault.save_path = "user://shot_ranged_guard_stills.json"
	HeroProgress.save_path = "user://shot_ranged_guard_hero.json"
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
		push_error("ranged guard shot timed out in phase %d" % _phase)
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
		screen.show_tab("sets")
		_phase = 3
		_frames = 0
		return false
	if _phase == 3:
		if _frames < 6:
			return false
		var screen := _inventory()
		var sets := screen.find_child("GearScreen", true, false) if screen != null else null
		if sets == null:
			push_error("sets tab missing")
			return true
		var picked: Dictionary = sets.choose_stance("ranged_guard")
		if not bool(picked.get("ok", false)):
			push_error("could not pick Ranged Guard")
			return true
		_phase = 4
		_frames = 0
		return false
	if _phase == 4:
		if _frames < 4:
			return false
		if not _expect_sentence():
			return true
		_phase = 5
		_frames = 0
		return false
	if _phase == 5:
		if _frames < 3:
			return false
		_shot("ranged_guard_stance.png")
		return true
	return false


func _inventory() -> InventoryScreen:
	return _board._hud.get_node_or_null("InventoryScreen") as InventoryScreen


func _expect_sentence() -> bool:
	var screen := _inventory()
	var line := screen.find_child("GatewardenStance", true, false) as Label if screen != null else null
	if line == null:
		push_error("Ranged Guard sentence is missing")
		return false
	print("STANCE %s" % line.text)
	if not line.text.contains("15%") or not line.text.contains("10%"):
		push_error("the sentence is missing the new rates: %s" % line.text)
		return false
	if line.text.contains("20%"):
		push_error("the sentence still says 20%")
		return false
	var scroll := line.get_parent()
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent()
	if scroll is ScrollContainer and scroll.has_method("ensure_control_visible"):
		scroll.ensure_control_visible(line)
	return true


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
	var path := OUT.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])


func _seed_loadout() -> void:
	var bag := GearBag.new()
	for slot in GearBag.SLOTS:
		bag.add_item("gatewarden", slot, 5)
	bag.wear_family("bastion", "gatewarden")
	bag.set_stance("ranged_guard")
	bag.save()
	var vault := StillVault.new()
	vault.set_focus("bastion")
	vault.save()
