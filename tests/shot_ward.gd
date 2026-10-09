extends SceneTree

## Phone frame: Bastion at Aegis 2/4 with the Ward tooltip.
## godot --rendering-driver opengl3 -s res://tests/shot_ward.gd -- <png>

var _path := "/opt/cursor/artifacts/ward/ward_tooltip.png"
var _frames := 0
var _phase := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_path = text
	var folder := _path.get_base_dir()
	if folder != "":
		DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("ward shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		if not _boot(sim):
			return true
		board._rebuild_pawns()
		board._refresh()
		var hud: CombatHUD = board._hud
		if hud != null:
			hud.focus_fighter(_class_seat(sim, "bastion"))
			hud.show_spell_tooltip(SpellKits.WARD)
			hud._layout_chrome()
		_phase = 1
		_frames = 0
		return false
	if _frames < 12:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_path)
	var hud: CombatHUD = board._hud
	var card := hud._kestrel_body.get_parsed_text().replace("\n", " | ")
	var tip := hud.tooltip_caption().replace("\n", " | ")
	print("WARD %s %dx%d err=%s card=%s" % [_path, image.get_width(), image.get_height(), err, card])
	print("WARD tooltip=%s" % tip)
	if not card.contains("Aegis 2/4"):
		push_error("Bastion card is missing Aegis 2/4")
	if not tip.contains("2 AP / 2 Aegis"):
		push_error("Ward tooltip is missing 2 AP / 2 Aegis")
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
		"bastion_aegis": 2,
	})
	var guard := 0
	while int(sim.snapshot().get("active_seat", -1)) != _class_seat(sim, "bastion") and guard < 4:
		sim.submit({"type": "end_turn"})
		guard += 1
	for unit in sim._units:
		if str(unit.get("class_id", "")) != "bastion":
			continue
		unit["aegis"] = 2
		var bag: Variant = unit.get("resources", null)
		if typeof(bag) == TYPE_DICTIONARY:
			(bag as Dictionary)["aegis"] = 2
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
