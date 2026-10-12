extends SceneTree

const SIM_SCRIPT := preload("res://backend/combat_sim.gd")

## 2400×1080 courtyard: Bound Hour target pick (allies highlighted, no walk
## cells), then the bind on Mender ("Bound to Mender" on Bastion's card).
## Phone fit, same as the other 2400×1080 shots. Without --mobile-frame the
## desktop zoom is fitted to 960×720 and the arena sits in a small rectangle.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_bound_target.gd -- /opt/cursor/artifacts/bound_target --mobile-frame

var _dir := "/opt/cursor/artifacts/bound_target"
var _phase := "boot"
var _frames := 0
var _board: Node
var _layout: Dictionary = {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	select.set("hotseat_map_id", "crosshaven")
	select.set("hotseat_classes", ["bastion", "ironjaw", "mender", "gloam", "kestrel", "kestrel"])
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 400:
		push_error("bound target shot timed out in %s" % _phase)
		return true
	if current_scene == null:
		return false
	_board = current_scene.get_node_or_null("BoardView")
	if _board == null or not bool(_board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 8:
			return false
		if not _arm_pick():
			return true
		_phase = "aim"
		_frames = 0
		return false
	if _phase == "aim":
		if _frames < 20:
			return false
		_save("bound_target_pick.png")
		_log_pick()
		if not _bind_mender():
			return true
		_phase = "bound"
		_frames = 0
		return false
	if _phase == "bound":
		if _frames < 20:
			return false
		_save("bound_on_mender.png")
		_log_card()
		return true
	return true


func _arm_pick() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	_layout = _courtyard_layout(sim)
	if _layout.is_empty():
		push_error("no courtyard layout for a 4-tile Bound Hour")
		return false
	sim.reset_match({
		"seed": 4,
		"map_id": "crosshaven",
		"team_size": 3,
		"skip_deploy": true,
		"classes": ["bastion", "ironjaw", "mender", "gloam", "kestrel", "kestrel"],
		"positions": _layout["positions"],
		"seat_gear": {0: {"worn": [], "still": {"id": "bound_hour", "mode": "intact"}}},
	})
	_board._rebuild_pawns()
	_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud == null or not hud._use_still_button.visible:
		push_error("Bound Hour button is hidden")
		return false
	hud._use_still_button.pressed.emit()
	hud._layout_chrome(Vector2(2400, 1080))
	var bastion: Vector2i = sim._unit_by_seat(0)["pos"]
	var mender: Vector2i = sim._unit_by_seat(2)["pos"]
	print("LAYOUT bastion=%s mender=%s chebyshev=%d ally=%s enemy=%s" % [
		bastion, mender, SIM_SCRIPT.chebyshev(bastion, mender),
		sim._unit_by_seat(4)["pos"], sim._unit_by_seat(1)["pos"],
	])
	var zoom := 0.0
	if _board._camera != null:
		zoom = _board._camera.zoom.x
	print("AIM label=%s zoom=%.3f view=%s" % [hud._selected_label.text, zoom, _board.get_viewport_rect().size])
	return hud.still_aiming()


func _courtyard_layout(sim: Node) -> Dictionary:
	sim.reset_match({
		"seed": 1,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"team_size": 3,
		"classes": ["bastion", "ironjaw", "mender", "gloam", "kestrel", "kestrel"],
	})
	var board = sim._board
	var n: int = sim._board_size
	var open: Array[Vector2i] = []
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if board.is_walkable(cell):
				open.append(cell)
	print("COURTYARD open=%d" % open.size())
	var best: Dictionary = {}
	var best_score := -1
	for origin in open:
		var mender := _first_open(open, origin, 4, [origin], true)
		var ally := _first_open(open, origin, 2, [origin, mender], false)
		var enemy := _first_open(open, origin, 4, [origin, mender, ally], false)
		if mender.x < 0 or ally.x < 0 or enemy.x < 0:
			continue
		var far := Vector2i(-1, -1)
		var other := Vector2i(-1, -1)
		var used: Array[Vector2i] = [origin, mender, ally, enemy]
		for cell in open:
			if used.has(cell) or cell == far:
				continue
			if far.x < 0 and SIM_SCRIPT.chebyshev(origin, cell) >= 6:
				far = cell
				continue
			if other.x < 0:
				other = cell
		if far.x < 0 or other.x < 0:
			continue
		var score := 40 - (absi(origin.x - 7) + absi(origin.y - 8))
		if mender.x == origin.x:
			score += 6
		if score > best_score:
			best_score = score
			best = {"positions": [origin, enemy, mender, other, ally, far]}
	return best


func _first_open(open: Array[Vector2i], origin: Vector2i, dist: int, used: Array, straight: bool) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for cell in open:
		if SIM_SCRIPT.chebyshev(origin, cell) != dist or used.has(cell):
			continue
		if straight and cell.x == origin.x and cell.y < origin.y:
			return cell
		if fallback.x < 0:
			fallback = cell
	return fallback


func _log_pick() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	var hud: CombatHUD = _board._hud
	var kinds := PackedStringArray()
	for seat in [0, 1, 2, 4]:
		var cell: Vector2i = sim._unit_by_seat(seat)["pos"]
		var tile: BoardTile = _board.tiles.get(cell, null)
		var kind := "" if tile == null else tile.highlight
		kinds.append("%s:%s" % [sim._unit_by_seat(seat)["name"], kind])
	var moves := 0
	var targets := 0
	for cell in _board.tiles.keys():
		var kind := (_board.tiles[cell] as BoardTile).highlight
		if kind == "move":
			moves += 1
		elif kind == "target":
			targets += 1
	print("PICK highlights=%s targets=%d walks=%d label=%s" % [" ".join(kinds), targets, moves, hud._selected_label.text])
	if targets < 2 or moves != 0:
		push_error("target pick is missing ally highlights or still showing walk cells")


func _bind_mender() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var mender: Vector2i = sim._unit_by_seat(2)["pos"]
	_board._handle_left_click(mender)
	_board._rebuild_pawns()
	_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud.focus_fighter(0)
		hud._layout_chrome(Vector2(2400, 1080))
	var name := str(sim._unit_by_seat(0).get("bound_name", ""))
	print("BOUND name=%s coach=%s" % [name, str(sim.snapshot().get("coach", ""))])
	if name != "Mender":
		push_error("Bound Hour did not name Mender")
		return false
	return true


func _log_card() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null or hud._kestrel_body == null:
		push_error("corner card is missing")
		return
	var card := hud._kestrel_body.get_parsed_text().replace("\n", " | ")
	var title := hud._banner_titles[0].text if hud._banner_titles.size() > 0 else ""
	print("CARD title=%s text=%s" % [title, card])
	if not card.contains("Bound to Mender"):
		push_error("corner card is missing Bound to Mender")


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized %s to 2400x1080" % file_name)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
