extends Node2D

## Phase B+ elevation prototype SCENE.
## Does not call CombatSim. Phase A mainline duel stays on main.tscn.
## Click a highlighted tile to spend MP along the cheapest ortho path.
##
## Z-sort: CanvasItem z_index comes from ProtoVisualSort (iso Y + elevation
## offset). That is a VIEW function — gameplay elevation is BoardTileData.elevation.

const STEP_SEC := 0.22
const PROTO_MP := 6
const START_CELL := Vector2i(0, 3)
const STONE_CELL := Vector2i(4, 3)

var _sim := ProtoMoveSim.new()
var _tiles: Dictionary = {}
var _pawn_cell: Vector2i = START_CELL
var _mp: int = PROTO_MP
var _busy: bool = false
var _selected: Vector2i = START_CELL
var _pawn: ProtoPawnView
var _stone: ProtoPawnView
var _board := Node2D.new()
var _title: Label
var _coach: Label
var _mp_label: Label
var _walk_tween: Tween


func _ready() -> void:
	_build_hud()
	_board.position = Vector2(480, 168)
	add_child(_board)
	_reset_board()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell(_board.get_local_mouse_position())
		if cell.x < 0:
			return
		_selected = cell
		_paint()
		if cell == _pawn_cell:
			return
		_try_move(cell)


func _try_move(dest: Vector2i) -> void:
	var result: Dictionary = _sim.validate_move(_pawn_cell, dest, _mp)
	if not bool(result.get("ok", false)):
		_coach.text = _reject_text(str(result.get("reason", "unreachable")), dest)
		_paint()
		return
	_busy = true
	var path: Array = result["path"]
	var cost := int(result["cost"])
	_coach.text = "Walk %s → %s along %d hop(s) (−%d MP). Cheapest ortho path (Proposed)." % [
		_cell_text(_pawn_cell), _cell_text(dest), path.size(), cost,
	]
	await _animate_path(path)
	if not is_inside_tree():
		return
	_sim.apply_move(_pawn_cell, dest, _mp)
	_pawn_cell = dest
	_mp -= cost
	_busy = false
	_paint()
	if _mp <= 0:
		_coach.text += "  MP empty — Refill MP to keep walking."


func _animate_path(path: Array) -> void:
	for step in path:
		var cell: Vector2i = step
		var elev := _elev_at(cell)
		if _walk_tween != null and is_instance_valid(_walk_tween):
			_walk_tween.kill()
		_walk_tween = create_tween()
		_walk_tween.tween_property(_pawn, "position", ProtoVisualSort.cell_to_local(cell, elev), STEP_SEC)
		await _walk_tween.finished
		if not is_inside_tree():
			return
		_pawn.z_index = ProtoVisualSort.unit_z_index(cell, elev)


func _reset_board() -> void:
	if _busy:
		return
	_sim = ProtoMoveSim.new()
	_sim.load_demo_map()
	_pawn_cell = START_CELL
	_mp = PROTO_MP
	_selected = START_CELL
	_sim.occupy(_pawn_cell)
	_sim.occupy(STONE_CELL)
	_rebuild_tiles()
	_rebuild_units()
	_coach.text = "Phase B+ prototype. Click a cyan tile to walk the cheapest MP path. Stone blocks (4,3)."
	_paint()


func _refill_mp() -> void:
	if _busy:
		return
	_mp = PROTO_MP
	_coach.text = "MP refilled to %d (Proposed proto pool — not Locked)." % PROTO_MP
	_paint()


func _rebuild_tiles() -> void:
	for child in _board.get_children():
		if child is ProtoTileView:
			_board.remove_child(child)
			child.free()
	_tiles.clear()
	for cell in _sim.tiles.keys():
		var tile: BoardTileData = _sim.tiles[cell]
		var view := ProtoTileView.new()
		view.apply_tile(tile)
		view.position = ProtoVisualSort.cell_to_local(tile.grid_pos, tile.elevation)
		# VIEW ONLY: z_index from iso Y + elevation offset. Not gameplay elevation.
		view.z_index = ProtoVisualSort.tile_z_index(tile.grid_pos, tile.elevation)
		_board.add_child(view)
		_tiles[cell] = view


func _rebuild_units() -> void:
	if _pawn != null and is_instance_valid(_pawn):
		_pawn.queue_free()
	if _stone != null and is_instance_valid(_stone):
		_stone.queue_free()
	_pawn = ProtoPawnView.new()
	_pawn.label = "Scout"
	_pawn.fill = Color(0.32, 0.58, 0.92)
	_board.add_child(_pawn)
	_stone = ProtoPawnView.new()
	_stone.label = "Stone"
	_stone.is_blocker = true
	_stone.position = ProtoVisualSort.cell_to_local(STONE_CELL, _elev_at(STONE_CELL))
	_stone.z_index = ProtoVisualSort.unit_z_index(STONE_CELL, _elev_at(STONE_CELL))
	_board.add_child(_stone)


func _paint() -> void:
	var reach := _sim.reachable(_pawn_cell, _mp)
	for cell in _tiles.keys():
		var view: ProtoTileView = _tiles[cell]
		var kind := ""
		if cell != _pawn_cell and reach.has(cell):
			kind = "move"
		view.set_highlight(kind)
		view.set_selected(cell == _selected)
	_place_pawn()
	_mp_label.text = "MP %d / %d  ·  Scout %s  ·  elev %s" % [
		_mp, PROTO_MP, _cell_text(_pawn_cell), _elev_label(_elev_at(_pawn_cell)),
	]


func _place_pawn() -> void:
	if _pawn == null:
		return
	var elev := _elev_at(_pawn_cell)
	_pawn.position = ProtoVisualSort.cell_to_local(_pawn_cell, elev)
	_pawn.z_index = ProtoVisualSort.unit_z_index(_pawn_cell, elev)


func _pick_cell(local: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 22.0
	for cell in _tiles.keys():
		var view: ProtoTileView = _tiles[cell]
		var dist := local.distance_to(view.position)
		if dist < best_d:
			best_d = dist
			best = cell
	return best


func _elev_at(cell: Vector2i) -> float:
	var tile := _sim.tile_at(cell)
	if tile == null:
		return 0.0
	return tile.elevation


func _elev_label(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(round(value)))
	return "%.1f" % value


func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]


func _reject_text(reason: String, dest: Vector2i) -> String:
	match reason:
		"not_walkable":
			return "REJECT — %s is impassable (Proposed Lava / override)." % _cell_text(dest)
		"occupied":
			return "REJECT — %s is occupied." % _cell_text(dest)
		"climb_too_steep":
			return "REJECT — climb exceeds max 1.0 (Proposed)."
		"drop_too_far":
			return "REJECT — drop exceeds max 2.0 (Proposed)."
		"insufficient_mp":
			return "REJECT — not enough MP for the cheapest path to %s." % _cell_text(dest)
		"out_of_bounds":
			return "REJECT — out of bounds."
		"same_tile":
			return "Already on %s." % _cell_text(dest)
		"not_ortho":
			return "REJECT — no diagonal edges (Proposed ortho-only)."
		_:
			return "REJECT — %s is not reachable with remaining MP (Proposed)." % _cell_text(dest)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 10)
	panel.size = Vector2(928, 140)
	hud.add_child(panel)

	_title = Label.new()
	_title.text = "Phase B+ elevation prototype  ·  Proposed numbers — not Locked  ·  Phase A duel is unchanged on main.tscn"
	_title.add_theme_font_size_override("font_size", 15)
	panel.add_child(_title)

	_mp_label = Label.new()
	_mp_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_mp_label)

	_coach = Label.new()
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach.custom_minimum_size = Vector2(900, 36)
	panel.add_child(_coach)

	var legend := Label.new()
	legend.text = "G Ground 1 MP   M Mud 2   W Water 2   L Lava impassable   ·   uphill +1/level (half-level +1)   downhill +0   climb≤1.0 drop≤2.0   ortho only"
	legend.add_theme_font_size_override("font_size", 12)
	panel.add_child(legend)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var refill := Button.new()
	refill.text = "Refill MP"
	refill.pressed.connect(_refill_mp)
	row.add_child(refill)
	var reset := Button.new()
	reset.text = "Reset board"
	reset.pressed.connect(_reset_board)
	row.add_child(reset)
	var note := Label.new()
	note.text = "  Tile labels: letter = terrain, number = elevation. Cyan = reachable. Z-sort is visual-only."
	row.add_child(note)
