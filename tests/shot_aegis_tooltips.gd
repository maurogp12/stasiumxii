extends SceneTree

## Phone frame: Bastion's Plant and Snap Wall hover cards, with the Aegis line.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_aegis_tooltips.gd -- /opt/cursor/artifacts/aegis_tooltips --mobile-frame

var _dir := "/opt/cursor/artifacts/aegis_tooltips"
var _frames := 0
var _phase := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	if not args.has("--mobile-frame"):
		push_error("pass --mobile-frame so the card is the phone layout")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("aegis tooltip shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	var hud: CombatHUD = board._hud
	if _phase == 0:
		if not _boot(sim):
			return true
		board._rebuild_pawns()
		board._refresh()
		if hud != null:
			hud.focus_fighter(_class_seat(sim, "bastion"))
			hud.show_spell_tooltip(SpellKits.PLANT)
			hud._layout_chrome()
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 12:
			return false
		if not _save(hud, "plant.png", "+1 Aegis (max 4)"):
			return true
		hud.show_spell_tooltip(SpellKits.SNAP_WALL)
		hud._layout_chrome()
		_phase = 2
		_frames = 0
		return false
	if _frames < 12:
		return false
	_save(hud, "snap_wall.png", "Uses 2 Aegis (max 4)")
	return true


func _save(hud: CombatHUD, file_name: String, needle: String) -> bool:
	var path := _dir.path_join(file_name)
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	var tip := ""
	if hud != null:
		tip = hud.tooltip_caption().replace("\n", " | ")
	print("AEGIS %s %dx%d err=%s tooltip=%s" % [path, image.get_width(), image.get_height(), err, tip])
	if err != OK:
		push_error("could not save %s" % path)
		return false
	if not tip.contains(needle):
		push_error("tooltip missing %s: %s" % [needle, tip])
		return false
	if not tip.contains("max 4"):
		push_error("tooltip missing the Aegis cap: %s" % tip)
		return false
	return true


func _boot(sim: Node) -> bool:
	var cells := _pair(sim)
	if cells.size() < 2:
		push_error("no pair of ground cells")
		return false
	sim.reset_match({
		"seed": 4,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": cells,
		"bastion_aegis": 3,
	})
	var guard := 0
	while int(sim.snapshot().get("active_seat", -1)) != _class_seat(sim, "bastion") and guard < 4:
		sim.submit({"type": "end_turn"})
		guard += 1
	for unit in sim._units:
		if str(unit.get("class_id", "")) != "bastion":
			continue
		unit["aegis"] = 3
		var bag: Variant = unit.get("resources", null)
		if typeof(bag) == TYPE_DICTIONARY:
			(bag as Dictionary)["aegis"] = 3
	return int(sim.snapshot().get("active_seat", -1)) == _class_seat(sim, "bastion")


func _class_seat(sim: Node, class_id: String) -> int:
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if str(unit.get("class_id", "")) == class_id:
			return int(unit.get("seat", -1))
	return -1


func _pair(sim: Node) -> Array:
	sim.reset_match({"seed": 1, "map_id": "slagcrown", "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	var n := int(sim.snapshot().get("board_size", 15))
	for y in range(2, n - 2):
		for x in range(2, n - 4):
			var a := Vector2i(x, y)
			var b := Vector2i(x + 3, y)
			if _open(sim, a) and _open(sim, b):
				return [a, b]
	return []


func _open(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"
