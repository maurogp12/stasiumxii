extends SceneTree

## Kestrel's turn after Pitmaw's first hit (Slow −1 MP), then after a later hit
## (full MP, no Slow). 2400×1080.
## xvfb-run -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 -s res://tests/shot_pitmaw_slow.gd -- /opt/cursor/artifacts/pitmaw --mobile-frame

var _out := "/tmp/pitmaw_slow"
var _phase := "boot"
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--"):
			continue
		_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir() if _out.ends_with(".png") else _out)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	select.set("hotseat_classes", ["ironjaw", "kestrel"])
	select.set("hotseat_map_id", "slagcrown")
	change_scene_to_file("res://main.tscn")
	_phase = "fight"


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null or not bool(board.get("_booted")):
		return false
	if _phase == "fight":
		if _frames < 8:
			return false
		if not _first_hit(board):
			return true
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera()
		_phase = "hold_slow"
		_frames = 0
		return false
	if _phase == "hold_slow":
		if _frames < 24:
			return false
		_save(board, "pitmaw_first_slow.png")
		if not _later_hit(board):
			return true
		_phase = "hold_clear"
		_frames = 0
		return false
	if _phase == "hold_clear":
		if _frames < 24:
			return false
		_save(board, "pitmaw_later_hit.png")
		return true
	return false


func _save(board: Node, file_name: String) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	var coach := str(sim.snapshot().get("coach", ""))
	var hud: Node = board._hud
	var bar := ""
	if hud != null and hud.get("_coach_label") != null:
		bar = str(hud._coach_label.text)
	print("COACH ", file_name, " ", coach)
	print("BAR ", file_name, " ", bar)
	var path := _out if _out.ends_with(".png") else _out.path_join(file_name)
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("saved ", path, " ", image.get_width(), "x", image.get_height())


func _worn() -> Array:
	var out: Array = []
	for slot in ["weapon", "head", "chest", "legs", "boots"]:
		out.append({"item_id": "pitmaw.%s" % slot, "plus": 5})
	return out


func _paint(board: Node) -> void:
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()


func _first_hit(board: Node) -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"flat_board": true,
		"map_id": "slagcrown",
		"classes": ["ironjaw", "kestrel"],
		"positions": [Vector2i(5, 5), Vector2i(6, 5)],
		"seat_gear": {0: {"worn": _worn(), "flatten_plus": true}},
	})
	sim._scripted_rolls.clear()
	sim._scripted_rolls.append(1)
	sim._scripted_rolls.append(99)
	var hit: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(6, 5), "seat": 0})
	print("FIRST_HIT ", hit.get("ok", false), " ", hit.get("reason", ""))
	var ended: Dictionary = sim.submit({"type": "end_turn", "seat": 0})
	print("FIRST_END ", ended.get("ok", false), " ", sim.snapshot().get("coach", ""))
	_paint(board)
	return bool(hit.get("ok", false)) and bool(ended.get("ok", false))


func _later_hit(board: Node) -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var hers: Dictionary = sim.submit({"type": "end_turn", "seat": sim.snapshot().get("active_seat", 1)})
	print("HER_END ", hers.get("ok", false))
	sim._scripted_rolls.clear()
	sim._scripted_rolls.append(1)
	sim._scripted_rolls.append(99)
	var hit: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(6, 5), "seat": 0})
	print("LATER_HIT ", hit.get("ok", false), " ", hit.get("reason", ""), " slow ", sim._unit_by_seat(1).get("gear_slow", false))
	var ended: Dictionary = sim.submit({"type": "end_turn", "seat": 0})
	print("LATER_END ", ended.get("ok", false), " ", sim.snapshot().get("coach", ""))
	_paint(board)
	return bool(hit.get("ok", false)) and bool(ended.get("ok", false))
