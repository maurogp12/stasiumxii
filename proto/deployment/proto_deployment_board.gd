extends Node2D

## Phase B+ deployment prototype SCENE.
## Does not call CombatSim. Phase A mainline duel stays on main.tscn.
## Hot-seat sequential: each side places one fighter in its zone, then Confirm.

const TILE_W := 64
const TILE_H := 32

var _mgr := DeploymentManager.new()
var _started: Dictionary = {}
var _title: Label
var _coach: Label
var _status: Label
var _confirm: Button
var _board := Node2D.new()
var _hover := Vector2i(-1, -1)


func _ready() -> void:
	_mgr.start_match_callback = _on_start_match
	_build_hud()
	_board.position = Vector2(480, 200)
	add_child(_board)
	_board.draw.connect(_draw_board)
	_reset()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _pick_cell(_board.get_local_mouse_position())
		_board.queue_redraw()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var cell := _pick_cell(_board.get_local_mouse_position())
	if cell.x < 0:
		return
	_try_place(cell)


func _try_place(cell: Vector2i) -> void:
	if _mgr.phase != MatchPhase.Id.DEPLOYMENT:
		_coach.text = "Turn 1 stub — deploy is locked. Phase A duel is on main.tscn."
		_paint()
		return
	var unit := _active_unit()
	if unit.is_empty():
		_coach.text = "REJECT — no fighter for this seat."
		_paint()
		return
	_mgr.select_unit(unit["id"])
	var result: Dictionary
	if bool(unit.get("placed", false)):
		result = _mgr.reposition(unit["id"], cell)
	else:
		result = _mgr.place(unit["id"], cell)
	_coach.text = str(result.get("coach", _mgr.last_coach))
	_paint()


func _on_confirm() -> void:
	var result: Dictionary = _mgr.confirm()
	_coach.text = str(result.get("coach", _mgr.last_coach))
	_paint()


func _on_start_match(payload: Dictionary) -> void:
	_started = payload.duplicate(true)


func _reset() -> void:
	_started.clear()
	_mgr = DeploymentManager.new()
	_mgr.start_match_callback = _on_start_match
	_mgr.select_unit("kestrel")
	_coach.text = "Phase B+ deploy prototype. Seat 0 (Kestrel, green zone) places one fighter, then Confirm."
	_paint()


func _paint() -> void:
	_board.queue_redraw()
	var snap: Dictionary = _mgr.snapshot()
	_status.text = "Phase %s  ·  active seat %d  ·  selected %s  ·  both_ready %s  ·  turn %d" % [
		str(snap.get("phase_name", "")),
		int(snap.get("active_player_id", 0)),
		str(snap.get("selected_unit_id", "-")),
		str(snap.get("both_ready", false)),
		int(snap.get("turn_index", 0)),
	]
	_confirm.disabled = not _mgr.can_confirm()
	if _mgr.phase == MatchPhase.Id.COMBAT:
		_confirm.text = "Turn 1"
		_confirm.disabled = true
	else:
		_confirm.text = "Confirm seat %d" % _mgr.active_player_id


func _active_unit() -> Dictionary:
	for unit in _mgr.snapshot()["units"]:
		if int(unit["player_id"]) == _mgr.active_player_id:
			return unit
	return {}


func _draw_board() -> void:
	for y in range(_mgr.board_size):
		for x in range(_mgr.board_size):
			_draw_tile(Vector2i(x, y))
	for unit in _mgr.snapshot()["units"]:
		if bool(unit.get("placed", false)):
			_draw_token(unit)


func _draw_tile(cell: Vector2i) -> void:
	var origin := _cell_to_local(cell)
	var points := PackedVector2Array([
		origin + Vector2(0, -TILE_H / 2.0),
		origin + Vector2(TILE_W / 2.0, 0),
		origin + Vector2(0, TILE_H / 2.0),
		origin + Vector2(-TILE_W / 2.0, 0),
	])
	var color := Color(0.42, 0.50, 0.44) if (cell.x + cell.y) % 2 == 0 else Color(0.36, 0.44, 0.38)
	if _mgr.zone_for(0) != null and _mgr.zone_for(0).contains(cell):
		color = Color(0.28, 0.58, 0.38)
	if _mgr.zone_for(1) != null and _mgr.zone_for(1).contains(cell):
		color = Color(0.62, 0.32, 0.32)
	if _mgr.phase == MatchPhase.Id.DEPLOYMENT:
		var unit := _active_unit()
		if not unit.is_empty() and bool(_mgr.can_deploy_unit(unit["id"], cell).get("ok", false)):
			color = Color(0.30, 0.78, 0.90) if int(unit["player_id"]) == 0 else Color(0.90, 0.55, 0.40)
	if cell == _hover:
		color = color.lightened(0.18)
	_board.draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	_board.draw_polyline(outline, Color(0.12, 0.10, 0.10, 0.9), 1.0, true)
	var font := ThemeDB.fallback_font
	var label := "%d,%d" % [cell.x, cell.y]
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	_board.draw_string(font, origin + Vector2(-size.x * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.08, 0.06, 0.06))


func _draw_token(unit: Dictionary) -> void:
	var cell: Vector2i = unit["cell"]
	var origin := _cell_to_local(cell)
	var fill := Color(0.28, 0.78, 0.48) if int(unit["player_id"]) == 0 else Color(0.86, 0.32, 0.32)
	_board.draw_circle(origin + Vector2(0, -10), 11.0, fill)
	_board.draw_arc(origin + Vector2(0, -10), 11.0, 0.0, TAU, 24, Color(0.08, 0.06, 0.06), 1.6, true)
	var font := ThemeDB.fallback_font
	var name := str(unit.get("name", "?"))
	var size := font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	_board.draw_string(font, origin + Vector2(-size.x * 0.5, 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.08, 0.06, 0.06))


func _pick_cell(local: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 22.0
	for y in range(_mgr.board_size):
		for x in range(_mgr.board_size):
			var cell := Vector2i(x, y)
			var dist := local.distance_to(_cell_to_local(cell))
			if dist < best_d:
				best_d = dist
				best = cell
	return best


func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.10, 0.10, 0.12, 0.92)
	backdrop.position = Vector2(0, 0)
	backdrop.size = Vector2(960, 124)
	hud.add_child(backdrop)

	_title = _hud_label(hud, Vector2(16, 8), 14)
	_title.text = "Phase B+ deployment prototype  ·  Proposed — not Locked  ·  Phase A duel is unchanged on main.tscn"
	_status = _hud_label(hud, Vector2(16, 30), 16)
	_coach = _hud_label(hud, Vector2(16, 54), 14)
	var legend := _hud_label(hud, Vector2(16, 76), 12)
	legend.text = "Green 2×3 = seat 0 zone    Red 2×3 = seat 1 zone    Cyan/orange = legal place    Sequential hot-seat    Combat off until both Confirm"

	_confirm = Button.new()
	_confirm.text = "Confirm seat 0"
	_confirm.position = Vector2(16, 96)
	_confirm.size = Vector2(150, 24)
	_confirm.pressed.connect(_on_confirm)
	hud.add_child(_confirm)
	var reset := Button.new()
	reset.text = "Reset deploy"
	reset.position = Vector2(176, 96)
	reset.size = Vector2(120, 24)
	reset.pressed.connect(_reset)
	hud.add_child(reset)
	var note := _hud_label(hud, Vector2(308, 100), 12)
	note.text = "Open main.tscn for the Phase A CombatSim duel. This scene never calls CombatSim."


func _hud_label(host: Node, pos: Vector2, font_size: int) -> Label:
	var lab := Label.new()
	lab.position = pos
	lab.size = Vector2(928, 22)
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", Color(0.94, 0.93, 0.90))
	host.add_child(lab)
	return lab
