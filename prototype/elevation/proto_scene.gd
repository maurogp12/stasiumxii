extends Node2D

## Phase B+ prototype scene. Isolated from the live hot-seat duel.
## Open this scene (F6 / Run Current Scene). Do not change project.godot main_scene.
## CombatSim is not consulted; clicks never call submit(move).

const START := Vector2i(0, 0)
const DEMO_DEST := Vector2i(4, 0)
const BOARD_SCALE := 1.85

var _tiles: Dictionary = {}
var _views: Dictionary = {}
var _board_root: Node2D
var _path_draw: Node2D
var _hud: CanvasLayer
var _title: Label
var _body: Label
var _legend: Label
var _hover_label: Label
var _mp_budget: int = 6
var _origin: Vector2i = START
var _dest: Vector2i = Vector2i(-1, -1)
var _reach: Dictionary = {}
var _path: Array = []
var _hover: Vector2i = Vector2i(-99, -99)
var _status: String = ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.09, 0.11, 0.13))
	_tiles = ProtoBoard.demo_board()
	_board_root = Node2D.new()
	_board_root.name = "Board"
	_board_root.position = Vector2(480, 250)
	_board_root.scale = Vector2(BOARD_SCALE, BOARD_SCALE)
	add_child(_board_root)
	_build_views()
	_path_draw = Node2D.new()
	_path_draw.z_index = 80
	_path_draw.draw.connect(_draw_path)
	_board_root.add_child(_path_draw)
	_build_hud()
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_BRACKETLEFT, KEY_MINUS:
				_mp_budget = maxi(_mp_budget - 1, 0)
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_BRACKETRIGHT, KEY_EQUAL:
				_mp_budget = mini(_mp_budget + 1, 12)
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_R:
				_origin = START
				_dest = Vector2i(-1, -1)
				_status = "Reset origin to (0,0)."
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_dest = Vector2i(-1, -1)
				_status = ""
				_refresh()
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell(_board_root.get_local_mouse_position())
		if cell == Vector2i(-99, -99):
			return
		var data: ProtoBoardTile = _tiles[cell]
		if not data.walkable:
			_status = "%s is impassable (%s)." % [_cell_text(cell), TerrainDef.KIND_NAMES[data.terrain_type]]
			_update_copy()
			get_viewport().set_input_as_handled()
			return
		if cell == _origin:
			_dest = Vector2i(-1, -1)
			_status = ""
		elif _reach.has(cell):
			_dest = cell
			_status = "Cheapest ortho path costs %d MP." % ProtoPathfinder.path_cost(_reach, cell)
		else:
			_origin = cell
			_dest = Vector2i(-1, -1)
			_status = "Origin moved. Cyan tiles are reachable."
		_refresh()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _board_root == null:
		return
	var cell := _pick_cell(_board_root.get_local_mouse_position())
	if cell != _hover:
		_hover = cell
		_update_copy()


func _build_views() -> void:
	for pos in _tiles.keys():
		var view := ProtoTileView.new()
		view.setup(_tiles[pos])
		_board_root.add_child(view)
		_views[pos] = view


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var panel := ColorRect.new()
	panel.color = Color(0.07, 0.08, 0.10, 0.94)
	panel.position = Vector2(16, 12)
	panel.size = Vector2(928, 148)
	_hud.add_child(panel)
	var accent := ColorRect.new()
	accent.color = Color(0.98, 0.82, 0.28)
	accent.position = Vector2(16, 12)
	accent.size = Vector2(6, 148)
	_hud.add_child(accent)
	_title = _make_label(Vector2(32, 18), 17, Color(1.0, 0.92, 0.55), 22)
	_body = _make_label(Vector2(32, 44), 14, Color(0.94, 0.92, 0.90), 40)
	_legend = _make_label(Vector2(32, 88), 13, Color(0.80, 0.78, 0.72), 22)
	_hover_label = _make_label(Vector2(32, 112), 13, Color(0.78, 0.90, 0.95), 36)
	_hud.add_child(_title)
	_hud.add_child(_body)
	_hud.add_child(_legend)
	_hud.add_child(_hover_label)
	var footer := _make_label(Vector2(24, 690), 13, Color(0.78, 0.76, 0.70), 22)
	footer.text = "Main duel is unchanged: run res://main.tscn (F5). This scene is Proposed scaffolding only."
	_hud.add_child(footer)


func _make_label(pos: Vector2, size: int, color: Color, height: float) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(900, height)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh() -> void:
	_reach = ProtoPathfinder.reachable(_tiles, _origin, _mp_budget)
	_path = []
	if _dest != Vector2i(-1, -1) and _reach.has(_dest):
		_path = ProtoPathfinder.reconstruct_path(_reach, _dest)
	for pos in _views.keys():
		var view: ProtoTileView = _views[pos]
		view.highlight = ""
		if _reach.has(pos) and pos != _origin:
			view.highlight = "reach"
		if pos in _path and pos != _origin:
			view.highlight = "path"
		if pos == _dest:
			view.highlight = "dest"
		if pos == _origin:
			view.highlight = "origin"
		view.queue_redraw()
	if _path_draw != null:
		_path_draw.queue_redraw()
	_update_copy()


func _draw_path() -> void:
	if _path.size() < 2:
		return
	var pts := PackedVector2Array()
	for cell in _path:
		var data: ProtoBoardTile = _tiles[cell]
		var p := ProtoTileView.iso_origin(cell)
		p.y -= data.elevation * ElevationZSort.PROPOSED_PIXELS_PER_LEVEL
		pts.append(p)
	_path_draw.draw_polyline(pts, Color(0.15, 0.10, 0.05, 0.55), 5.0, true)
	_path_draw.draw_polyline(pts, Color(1.0, 0.86, 0.20), 2.6, true)


func _update_copy() -> void:
	_title.text = "Phase B+ prototype   ·   Proposed (not Locked)   ·   not wired to CombatSim"
	var dest_txt := "click a cyan tile"
	if _dest != Vector2i(-1, -1):
		dest_txt = "%s   cost %d MP" % [_cell_text(_dest), ProtoPathfinder.path_cost(_reach, _dest)]
	var extra := _status
	if extra == "":
		extra = "Left-click a tile to move origin, or a reachable tile to preview the cheapest ortho path."
	_body.text = "Origin %s     MP budget %d  ([ ] or -/=)     Dest %s\n%s" % [
		_cell_text(_origin),
		_mp_budget,
		dest_txt,
		extra,
	]
	_legend.text = "Proposed: Ground 1 · Mud/Water 2 · Lava impassable · uphill +1/full, half +1 · downhill 0 · max climb 1 / drop 2 · ortho only"
	_hover_label.text = _hover_text()


func _hover_text() -> String:
	if not _tiles.has(_hover):
		return "Hover a tile for step cost from the origin."
	var data: ProtoBoardTile = _tiles[_hover]
	if _hover == _origin:
		return "Hover %s  %s  elev %.1f  (origin)" % [_cell_text(_hover), TerrainDef.KIND_NAMES[data.terrain_type], data.elevation]
	var step: Dictionary = MovementCost.calculate(_tiles[_origin], _tiles[_hover])
	var edge: Dictionary = ProtoPathfinder.neighbor_weight(_tiles[_origin], _tiles[_hover])
	var edge_txt := "weight %d" % int(edge["weight"]) if edge["ok"] else str(edge["reason"])
	return "Hover %s  %s  elev %.1f  walkable %s   ·   step %s   ·   edge %s" % [
		_cell_text(_hover),
		TerrainDef.KIND_NAMES[data.terrain_type],
		data.elevation,
		data.walkable,
		_step_text(step),
		edge_txt,
	]


func _pick_cell(local_mouse: Vector2) -> Vector2i:
	var ordered: Array = _views.values()
	ordered.sort_custom(func(a: ProtoTileView, b: ProtoTileView) -> bool:
		return a.z_index > b.z_index
	)
	for view in ordered:
		var v: ProtoTileView = view
		if v.contains_local(local_mouse - v.position):
			return v.tile.grid_pos
	return Vector2i(-99, -99)


func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]


func _step_text(step: Dictionary) -> String:
	if not step["ok"]:
		return "REJECT %s" % step["reason"]
	return "ok total %d (terrain %d + elev %d)" % [step["total_mp"], step["terrain_mp"], step["elev_mp"]]
