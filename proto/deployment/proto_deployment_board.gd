extends Node2D

## Phase B+ deployment prototype SCENE.
## Does not call CombatSim.reset_match / submit. Phase A duel stays on main.tscn.
## Simultaneous deploy: both seats place on opposite halves of the 1-deep border
## ring, then Ready. Both ready → Turn 1 stub.

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
var _ready_p1_btn: Button
var _ready_p2_btn: Button
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
				_coach.text = "Selected %s. Click another ring tile on that side to reposition." % _mgr.unit_by_id(occupant).get("name", occupant)
				_paint()
				return
			_coach.text = _reject_text(str(owned.get("reason", "")), cell)
			_paint()
			return
		var unit_id := _unit_for_cell(cell)
		if unit_id == "":
			_coach.text = _reject_text("outside_zone", cell)
			_paint()
			return
		var result: Dictionary = _mgr.place_unit(unit_id, cell)
		if bool(result.get("ok", false)):
			var unit: Dictionary = _mgr.unit_by_id(str(result["unit_id"]))
			_coach.text = "Placed %s on %s. Ready locks this side." % [unit.get("name", ""), _cell_text(cell)]
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
	_coach.text = "Both sides deploy at once. Green south+west ring = Kestrel; red north+east ring = Ironjaw. Ready when placed. Proposed — not Locked."
	_paint()


func _ready_pressed(player_id: int) -> void:
	var result: Dictionary = _mgr.confirm(player_id)
	if not bool(result.get("ok", false)):
		_coach.text = _reject_text(str(result.get("reason", "")), Vector2i(-1, -1))
		_paint()
		return
	if _mgr.phase == MatchPhase.DEPLOYMENT:
		var waiting := 2 if player_id == 0 else 1
		_coach.text = "P%d ready. Waiting for P%d." % [player_id + 1, waiting]
	_paint()


func _on_start_match(snap: Dictionary) -> void:
	_started = true
	_coach.text = "Both sides ready. Positions locked. %s — CombatSim is not wired (Phase A duel unchanged)." % snap.get("phase_name", "TURN_1")
	_paint()


func _stub_action(kind: String) -> void:
	if not _mgr.combat_actions_enabled():
		_coach.text = "REJECT — %s disabled until both sides are ready." % kind
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
	var legal_p1 := _mgr.legal_deploy_cells_for_player(0)
	var legal_p2 := _mgr.legal_deploy_cells_for_player(1)
	for cell in _tiles.keys():
		var view: DeploymentTileView = _tiles[cell]
		view.walkable = _mgr.is_walkable(cell)
		var kind := ""
		if _mgr.phase == MatchPhase.DEPLOYMENT:
			if legal_p1.has(cell):
				kind = "zone_p1"
			elif legal_p2.has(cell):
				kind = "zone_p2"
			elif _in_zone(0, cell) and bool(_mgr.ready.get(0, false)):
				kind = "locked"
			elif _in_zone(1, cell) and bool(_mgr.ready.get(1, false)):
				kind = "locked"
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
	var p1 := _side_status(0, "kestrel")
	var p2 := _side_status(1, "ironjaw")
	_status.text = "Simultaneous  ·  Kestrel %s  ·  Ironjaw %s  ·  selected %s" % [
		p1, p2, _mgr.selected_unit_id,
	]
	_ready_p1_btn.disabled = not _mgr.can_confirm(0)
	_ready_p2_btn.disabled = not _mgr.can_confirm(1)
	_ready_p1_btn.text = "P1 ready" if bool(_mgr.ready.get(0, false)) else "Ready P1"
	_ready_p2_btn.text = "P2 ready" if bool(_mgr.ready.get(1, false)) else "Ready P2"
	if _mgr.phase == MatchPhase.TURN_1:
		_ready_p1_btn.text = "P1 ready"
		_ready_p2_btn.text = "P2 ready"
		_ready_p1_btn.disabled = true
		_ready_p2_btn.disabled = true
	var combat_on := _mgr.combat_actions_enabled()
	_walk_btn.disabled = not combat_on
	_combat_btn.disabled = not combat_on
	_end_turn_btn.disabled = not combat_on


func _side_status(player_id: int, unit_id: String) -> String:
	if bool(_mgr.ready.get(player_id, false)):
		return "ready"
	if _unit_placed(unit_id):
		return "placed"
	return "open"


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


func _unit_for_cell(cell: Vector2i) -> String:
	if _in_zone(0, cell):
		return "kestrel"
	if _in_zone(1, cell):
		return "ironjaw"
	return ""


func _unit_placed(unit_id: String) -> bool:
	var unit := _mgr.unit_by_id(unit_id)
	return not unit.is_empty() and bool(unit.get("placed", false))


func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]


func _reject_text(reason: String, dest: Vector2i) -> String:
	var where := _cell_text(dest) if dest.x >= 0 else "that tile"
	match reason:
		"outside_zone":
			if dest.x >= 0 and not DeploymentZone.is_border_cell(dest, _mgr.board_size):
				return "REJECT — %s is interior. Legal cells are the 1-deep border ring only." % where
			return "REJECT — %s is the other side's half of the border ring." % where
		"occupied":
			return "REJECT — %s is occupied." % where
		"not_walkable":
			return "REJECT — %s is not walkable (elevation proto walkable check; no deploy MP)." % where
		"out_of_bounds":
			return "REJECT — out of bounds."
		"units_not_placed":
			return "REJECT — place the required fighter before Ready."
		"side_locked":
			return "REJECT — this side is already ready."
		"wrong_phase":
			return "REJECT — deployment is over. Turn 1 stub only."
		"already_confirmed":
			return "REJECT — already ready."
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

	_ready_p1_btn = Button.new()
	_ready_p1_btn.text = "Ready P1"
	_ready_p1_btn.position = Vector2(16, 104)
	_ready_p1_btn.size = Vector2(100, 28)
	_ready_p1_btn.pressed.connect(_ready_pressed.bind(0))
	hud.add_child(_ready_p1_btn)

	_ready_p2_btn = Button.new()
	_ready_p2_btn.text = "Ready P2"
	_ready_p2_btn.position = Vector2(124, 104)
	_ready_p2_btn.size = Vector2(100, 28)
	_ready_p2_btn.pressed.connect(_ready_pressed.bind(1))
	hud.add_child(_ready_p2_btn)

	var reset := Button.new()
	reset.text = "Reset deploy"
	reset.position = Vector2(232, 104)
	reset.size = Vector2(112, 28)
	reset.pressed.connect(_reset_board)
	hud.add_child(reset)

	_walk_btn = Button.new()
	_walk_btn.text = "Walk"
	_walk_btn.position = Vector2(352, 104)
	_walk_btn.size = Vector2(72, 28)
	_walk_btn.pressed.connect(_stub_action.bind("Walk"))
	hud.add_child(_walk_btn)

	_combat_btn = Button.new()
	_combat_btn.text = "Combat"
	_combat_btn.position = Vector2(432, 104)
	_combat_btn.size = Vector2(80, 28)
	_combat_btn.pressed.connect(_stub_action.bind("Combat"))
	hud.add_child(_combat_btn)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.position = Vector2(520, 104)
	_end_turn_btn.size = Vector2(92, 28)
	_end_turn_btn.pressed.connect(_stub_action.bind("End Turn"))
	hud.add_child(_end_turn_btn)

	var legend := _hud_label(hud, Vector2(624, 104), 11)
	legend.size = Vector2(328, 32)
	legend.text = "Green S+W ring = P1  ·  Red N+E ring = P2  ·  gold = selected  ·  Walk/Combat/End Turn stub after both Ready"


func _hud_label(host: Node, pos: Vector2, font_size: int) -> Label:
	var lab := Label.new()
	lab.position = pos
	lab.size = Vector2(928, 22)
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", Color(0.94, 0.93, 0.90))
	host.add_child(lab)
	return lab
