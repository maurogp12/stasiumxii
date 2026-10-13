extends SceneTree

## Phone fight, default frame and a drag that slides the left-edge fighter
## out from under the side buttons and the Face pad.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_board_pan.gd -- /opt/cursor/artifacts/board_pan --mobile-frame

var _dir := "/opt/cursor/artifacts/board_pan"
var _frames := 0
var _phase := 0
var _board: Node


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
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 360:
		push_error("board pan shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_board = current_scene.get_node_or_null("BoardView") if current_scene != null else null
		if _board == null or not bool(_board._booted):
			return false
		if not _arm():
			return true
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 12:
			return false
		_save("default.png")
		_log("default")
		_pan_left_fighter_clear()
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		if _frames < 4:
			return false
		_save("panned.png")
		var clear := _log("panned")
		if not clear:
			push_error("the panned view still covers the left fighter")
			return true
		return true
	return true


func _arm() -> bool:
	var select: Script = load("res://scenes/class_select.gd")
	select.hotseat_team_size = 1
	var roster: Array[String] = ["kestrel", "bastion"]
	select.hotseat_classes = roster
	select.hotseat_map_id = "crosshaven"
	var config: Dictionary = select.local_match_config()
	config["seed"] = 4
	config["skip_deploy"] = true
	# Low-left and upper-right, the cells the fight buttons cover.
	config["positions"] = [Vector2i(1, 13), Vector2i(13, 2)]
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match(config)
	_board._rebuild_grid(15)
	_board._rebuild_pawns()
	_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null and hud.has_method("_layout_chrome"):
		hud._layout_chrome(Vector2(root.size))
	return _board.pawns_by_seat.has(0)


func _pan_left_fighter_clear() -> void:
	var hud: CombatHUD = _board._hud
	var pawn: Node2D = _board.pawns_by_seat[0]
	var body := _body_screen(pawn)
	var clear_x := _clear_x(hud)
	var clear_bottom := _clear_bottom(hud)
	# Finger drag follows the finger. Right and up slides the fighter into the open.
	var drag_x := clear_x - body.position.x
	var drag_y := 0.0
	if body.end.y > clear_bottom:
		drag_y = clear_bottom - body.end.y
	_board._queue_pan(Vector2(drag_x, drag_y))
	_board._apply_pending_pan()
	_board._flush_camera()


func _clear_x(hud: CombatHUD) -> float:
	var left := 160.0
	if hud._side_column != null:
		left = maxf(left, hud._side_column.get_global_rect().end.x + 24.0)
	for button in hud._face_buttons.values():
		left = maxf(left, (button as Control).get_global_rect().end.x + 16.0)
	return left


func _clear_bottom(hud: CombatHUD) -> float:
	var top := 900.0
	for button in hud._face_buttons.values():
		top = minf(top, (button as Control).get_global_rect().position.y - 12.0)
	return top


func _body_screen(pawn: Node2D) -> Rect2:
	var feet := _screen_of(pawn.position)
	var head := _screen_of(pawn.position + Vector2(0, -120))
	var left := _screen_of(pawn.position + Vector2(-48, -60))
	var right := _screen_of(pawn.position + Vector2(48, -60))
	var origin := Vector2(minf(left.x, right.x), minf(head.y, feet.y))
	var end := Vector2(maxf(left.x, right.x), maxf(head.y, feet.y))
	return Rect2(origin, end - origin)


func _screen_of(local_point: Vector2) -> Vector2:
	var cam: Camera2D = _board._camera
	var view: Vector2 = _board.get_viewport_rect().size
	return view * 0.5 + (local_point - cam.position) * cam.zoom


func _log(label: String) -> bool:
	var hud: CombatHUD = _board._hud
	var pawn: Node2D = _board.pawns_by_seat[0]
	var body := _body_screen(pawn)
	var column: Rect2 = hud._side_column.get_global_rect()
	var face := Rect2()
	for button in hud._face_buttons.values():
		var rect: Rect2 = (button as Control).get_global_rect()
		face = rect if face.size == Vector2.ZERO else face.merge(rect)
	var column_hit := column.intersects(body)
	var face_hit := face.intersects(body)
	print("PAN %s body %s column %s face %s overlap column %s face %s cam %s" % [
		label, body, column, face, column_hit, face_hit, (_board._camera as Camera2D).position,
	])
	return not column_hit and not face_hit


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _dir.path_join(name)
	image.save_png(path)
	print("PAN_SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])
