extends Node2D

## Phase B+ deployment prototype SCENE.
## Does not call CombatSim.reset_match / submit. Phase A duel stays on main.tscn.
## Hot-seat sequential deploy: P1 Kestrel, then P2 Ironjaw. Both confirm → Turn 1 stub.

var _mgr := DeploymentManager.new()
var _terrain := ProtoMoveSim.new()
var _tiles: Dictionary = {}
var _pawns: Dictionary = {}
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _board := Node2D.new()
var _title: Label
var _phase_label: Label
var _coach: Label
var _status: Label
var _confirm_btn: Button
var _walk_btn: Button
var _combat_btn: Button
var _end_turn_btn: Button
var _started: bool = false


func _ready() -> void:
	_terrain = ProtoMoveSim.new(8, 8)
	_mgr.is_walkable_fn = Callable(_terrain, "is_walkable")
	_mgr.start_match.connect(_on_start_match)
	_mgr.changed.connect(_paint)
	_build_hud()
	_board.position = Vector2(480, 176)
	add_child(_board)
	_reset_board()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell(_board.get_local_mouse_position())
		if cell.x < 0:
			return
		_selected_cell = cell
		if _mgr.phase != MatchPhase.DEPLOYMENT:
			_coach.text = "Turn 1 stub — walk / combat / end-turn stay off CombatSim. Open main.tscn for the Phase A duel."
			_paint()
			return
		var occupant := _mgr.occupant_at(cell)
		if occupant != "" and occupant != "_blocked":
			var owned: Dictionary = _mgr.select_unit(occupant)
			if bool(owned.get("ok", false)):
				_coach.text = "Selected %s. Click another zone tile to reposition." % _mgr.unit_by_id(occupant).get("name", occupant)
				_paint()
				return
		var result: Dictionary = _mgr.place_unit(_mgr.selected_unit_id, cell)
		if bool(result.get("ok", false)):
			var unit: Dictionary = _mgr.unit_by_id(str(result["unit_id"]))
			_coach.text = "Placed %s on %s. Confirm to lock this side." % [unit.get("name", ""), _cell_text(cell)]
		else:
			_coach.text = _reject_text(str(result.get("reason", "")), cell)
		_paint()


func _reset_board() -> void:
	_started = false
	_selected_cell = Vector2i(-1, -1)
	_terrain = ProtoMoveSim.new(8, 8)
	_mgr.is_walkable_fn = Callable(_terrain, "is_walkable")
	_mgr.reset()
	_rebuild_tiles()
	_rebuild_pawns()
	_coach.text = "P1 Kestrel deploys first. Click a highlighted west-box tile, then Confirm. Proposed — not Locked."
	_paint()


func _confirm_pressed() -> void:
	var result: Dictionary = _mgr.confirm()
	if not bool(result.get("ok", false)):
		_coach.text = _reject_text(str(result.get("reason", "")), Vector2i(-1, -1))
		_paint()
		return
	if _mgr.phase == MatchPhase.DEPLOYMENT:
		_coach.text = "P1 locked. P2 Ironjaw: place in the east 2×3 box, then Confirm."
	_paint()


func _on_start_match(snap: Dictionary) -> void:
	_started = true
	_coach.text = "Both sides confirmed. Positions locked. %s — CombatSim is not wired (Phase A duel unchanged)." % snap.get("phase_name", "TURN_1")
	_paint()


func _stub_action(kind: String) -> void:
	if not _mgr.combat_actions_enabled():
		_coach.text = "REJECT — %s disabled until both sides confirm deploy." % kind
	else:
		_coach.text = "Turn 1 stub: %s is chrome-only. Phase A CombatSim still lives on main.tscn." % kind
	_paint()


func _rebuild_tiles() -> void:
	for child in _board.get_children():
		if child is DeploymentTileView:
			_board.remove_child(child)
			child.free()
	_tiles.clear()
	for y in range(_mgr.board_size):
		for x in range(_mgr.board_size):
			var cell := Vector2i(x, y)
			var view := DeploymentTileView.new()
			view.grid_pos = cell
			view.walkable = _mgr.is_walkable(cell)
			view.position = ProtoVisualSort.cell_to_local(cell, 0.0)
			view.z_index = ProtoVisualSort.tile_z_index(cell, 0.0)
			_board.add_child(view)
			_tiles[cell] = view


func _rebuild_pawns() -> void:
	for pawn in _pawns.values():
		if is_instance_valid(pawn):
			pawn.queue_free()
	_pawns.clear()


func _ensure_pawn(unit: Dictionary) -> ProtoPawnView:
	var unit_id := str(unit["id"])
	if _pawns.has(unit_id) and is_instance_valid(_pawns[unit_id]):
		return _pawns[unit_id]
	var pawn := ProtoPawnView.new()
	pawn.label = str(unit.get("name", unit_id))
	if str(unit.get("class_id", "")) == "ironjaw":
		pawn.fill = Color(0.72, 0.32, 0.32)
	else:
		pawn.fill = Color(0.28, 0.62, 0.44)
	_board.add_child(pawn)
	_pawns[unit_id] = pawn
	return pawn


func _paint() -> void:
	var legal := _mgr.legal_deploy_cells()
	for cell in _tiles.keys():
		var view: DeploymentTileView = _tiles[cell]
		view.walkable = _mgr.is_walkable(cell)
		var kind := ""
		if _mgr.phase == MatchPhase.DEPLOYMENT:
			if _in_zone(0, cell):
				kind = "zone_p1" if _mgr.active_player == 0 and legal.has(cell) else ("locked" if bool(_mgr.confirmed.get(0, false)) else "")
			elif _in_zone(1, cell):
				kind = "zone_p2" if _mgr.active_player == 1 and legal.has(cell) else ("locked" if bool(_mgr.confirmed.get(1, false)) else "")
			if not view.walkable and (_in_zone(0, cell) or _in_zone(1, cell)):
				kind = "invalid"
			if _mgr.occupant_at(cell) != "":
				kind = "occupied" if _mgr.phase == MatchPhase.DEPLOYMENT else "locked"
		elif _mgr.occupant_at(cell) != "":
			kind = "locked"
		view.set_highlight(kind)
		view.set_selected(cell == _selected_cell)
	_place_pawns()
	_sync_hud()


func _place_pawns() -> void:
	var live_ids: Dictionary = {}
	for unit in _mgr.units.values():
		if not bool(unit.get("placed", false)):
			continue
		live_ids[str(unit["id"])] = true
		var pawn := _ensure_pawn(unit)
		var cell: Vector2i = unit["cell"]
		pawn.position = ProtoVisualSort.cell_to_local(cell, 0.0)
		pawn.z_index = ProtoVisualSort.unit_z_index(cell, 0.0)
		pawn.visible = true
	for unit_id in _pawns.keys():
		if not live_ids.has(unit_id) and is_instance_valid(_pawns[unit_id]):
			_pawns[unit_id].visible = false


func _sync_hud() -> void:
	var snap := _mgr.snapshot()
	_phase_label.text = "Phase %s" % snap["phase_name"]
	if _mgr.phase == MatchPhase.TURN_1:
		_phase_label.text = "TURN 1  ·  positions locked  ·  Kestrel seat first (stub)"
	var p1 := "placed" if _unit_placed("kestrel") else "open"
	var p2 := "placed" if _unit_placed("ironjaw") else "open"
	if bool(_mgr.confirmed.get(0, false)):
		p1 = "locked"
	if bool(_mgr.confirmed.get(1, false)):
		p2 = "locked"
	_status.text = "Active P%d  ·  Kestrel %s  ·  Ironjaw %s  ·  selected %s" % [
		_mgr.active_player + 1, p1, p2, _mgr.selected_unit_id,
	]
	_confirm_btn.disabled = not _mgr.can_confirm()
	_confirm_btn.text = "Confirm P%d" % (_mgr.active_player + 1)
	if _mgr.phase == MatchPhase.TURN_1:
		_confirm_btn.text = "Both confirmed"
		_confirm_btn.disabled = true
	var combat_on := _mgr.combat_actions_enabled()
	_walk_btn.disabled = not combat_on
	_combat_btn.disabled = not combat_on
	_end_turn_btn.disabled = not combat_on


func _pick_cell(local: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 22.0
	for cell in _tiles.keys():
		var view: DeploymentTileView = _tiles[cell]
		var dist := local.distance_to(view.position)
		if dist < best_d:
			best_d = dist
			best = cell
	return best


func _in_zone(player_id: int, cell: Vector2i) -> bool:
	var zone := _mgr.zone_for(player_id)
	return zone != null and zone.contains(cell)


func _unit_placed(unit_id: String) -> bool:
	var unit := _mgr.unit_by_id(unit_id)
	return not unit.is_empty() and bool(unit.get("placed", false))


func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]


func _reject_text(reason: String, dest: Vector2i) -> String:
	var where := _cell_text(dest) if dest.x >= 0 else "that tile"
	match reason:
		"outside_zone":
			return "REJECT — %s is outside this side's deployment zone." % where
		"occupied":
			return "REJECT — %s is occupied." % where
		"not_walkable":
			return "REJECT — %s is not walkable (elevation proto walkable check; no deploy MP)." % where
		"out_of_bounds":
			return "REJECT — out of bounds."
		"units_not_placed":
			return "REJECT — place the required fighter before Confirm."
		"side_locked":
			return "REJECT — this side is already confirmed."
		"not_your_turn":
			return "REJECT — sequential hot-seat: wait for the active player."
		"wrong_phase":
			return "REJECT — deployment is over. Turn 1 stub only."
		"already_confirmed":
			return "REJECT — already confirmed."
		_:
			return "REJECT — %s." % reason


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.10, 0.10, 0.12, 0.92)
	backdrop.position = Vector2(0, 0)
	backdrop.size = Vector2(960, 148)
	hud.add_child(backdrop)

	_title = _hud_label(hud, Vector2(16, 8), 14)
	_title.text = "Phase B+ deployment prototype  ·  Proposed rules — not Locked  ·  Phase A duel is unchanged on main.tscn"
	_phase_label = _hud_label(hud, Vector2(16, 28), 18)
	_status = _hud_label(hud, Vector2(16, 52), 14)
	_coach = _hud_label(hud, Vector2(16, 74), 13)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm P1"
	_confirm_btn.position = Vector2(16, 104)
	_confirm_btn.size = Vector2(128, 28)
	_confirm_btn.pressed.connect(_confirm_pressed)
	hud.add_child(_confirm_btn)

	var reset := Button.new()
	reset.text = "Reset deploy"
	reset.position = Vector2(152, 104)
	reset.size = Vector2(120, 28)
	reset.pressed.connect(_reset_board)
	hud.add_child(reset)

	_walk_btn = Button.new()
	_walk_btn.text = "Walk"
	_walk_btn.position = Vector2(284, 104)
	_walk_btn.size = Vector2(72, 28)
	_walk_btn.pressed.connect(_stub_action.bind("Walk"))
	hud.add_child(_walk_btn)

	_combat_btn = Button.new()
	_combat_btn.text = "Combat"
	_combat_btn.position = Vector2(364, 104)
	_combat_btn.size = Vector2(80, 28)
	_combat_btn.pressed.connect(_stub_action.bind("Combat"))
	hud.add_child(_combat_btn)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.position = Vector2(452, 104)
	_end_turn_btn.size = Vector2(92, 28)
	_end_turn_btn.pressed.connect(_stub_action.bind("End Turn"))
	hud.add_child(_end_turn_btn)

	var legend := _hud_label(hud, Vector2(556, 108), 11)
	legend.size = Vector2(392, 24)
	legend.text = "Green west 2×3 = P1  ·  Red east 2×3 = P2  ·  gold = selected  ·  Walk/Combat/End Turn stub after both confirm"


func _hud_label(host: Node, pos: Vector2, font_size: int) -> Label:
	var lab := Label.new()
	lab.position = pos
	lab.size = Vector2(928, 22)
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", Color(0.94, 0.93, 0.90))
	host.add_child(lab)
	return lab
