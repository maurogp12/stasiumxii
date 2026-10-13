extends SceneTree

## Bastion's Hold the Line: the range preview is the straight cross, then a
## pull on an enemy who stands on that line.
## DISPLAY=:1 godot --path . --rendering-driver opengl3 -s res://tests/shot_hold_line.gd

const OUT := "/opt/cursor/artifacts/hold_line"

var _frames := 0
var _phase := 0
var _board: Node = null


func _initialize() -> void:
	GearBag.save_path = "user://shot_hold_line_gear.json"
	StillVault.save_path = "user://shot_hold_line_stills.json"
	HeroProgress.save_path = "user://shot_hold_line_hero.json"
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
		push_error("hold line shot timed out in phase %d" % _phase)
		return true
	if _board == null:
		_board = current_scene.get_node_or_null("BoardView") if current_scene != null else null
		return false
	if _board._hud == null:
		return false
	if _phase == 0:
		if not bool(_board.get("_booted")):
			return false
		var sim: Node = root.get_node("/root/CombatSim")
		sim.reset_match({
			"seed": 1,
			"flat_board": true,
			"skip_deploy": true,
			"classes": ["bastion", "kestrel"],
			"positions": [Vector2i(7, 7), Vector2i(11, 7)],
			"kestrel_facing": "W",
			"rolls": [1],
		})
		_board._rebuild_pawns()
		_board._refresh()
		_board._hud._selected_spell = "hold_line"
		_board._hud._refresh_spell_buttons()
		_board._paint_highlights()
		_frame()
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		if not _expect_cross():
			return true
		_shot("hold_line_range.png")
		var sim: Node = root.get_node("/root/CombatSim")
		var pulled: Dictionary = sim.submit({"type": "cast", "spell": "hold_line", "to": Vector2i(11, 7), "seat": 0})
		if not bool(pulled.get("ok", false)):
			push_error("in-line Hold Line did not resolve: %s" % str(pulled.get("reason", "")))
			return true
		var foe: Vector2i = _unit_pos(sim, 1)
		if foe != Vector2i(8, 7):
			push_error("pull landed on %s" % foe)
			return true
		_board._hud._selected_spell = ""
		_board._rebuild_pawns()
		_board._refresh()
		_frame()
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		if _frames < 8:
			return false
		_shot("hold_line_pull.png")
		return true
	return false


func _expect_cross() -> bool:
	var bastion := Vector2i(7, 7)
	var highlighted := 0
	for cell in _board.tiles.keys():
		var tile = _board.tiles[cell]
		var kind := str(tile.highlight)
		if kind == "":
			continue
		highlighted += 1
		var at: Vector2i = cell
		if at.x != bastion.x and at.y != bastion.y:
			push_error("off-line cell %s is highlighted as %s" % [at, kind])
			return false
	print("HOLD_LINE highlighted=%d" % highlighted)
	if highlighted < 8:
		push_error("the straight cross did not paint")
		return false
	var diagonal = _board.tiles.get(Vector2i(8, 8))
	if diagonal != null and str(diagonal.highlight) != "":
		push_error("the diagonal is highlighted")
		return false
	return true


func _unit_pos(sim: Node, seat: int) -> Vector2i:
	for unit in sim.snapshot()["units"]:
		if int(unit.get("seat", -1)) == seat:
			return unit["pos"]
	return Vector2i(-1, -1)


func _frame() -> void:
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera()
	var cam: Camera2D = _board.get("_camera")
	if cam == null:
		return
	cam.zoom = Vector2(1.15, 1.15)
	_board._pan_limit = Vector2(700.0, 700.0)
	if _board.has_method("_center_on_cell"):
		_board._center_on_cell(Vector2i(7, 7))


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
