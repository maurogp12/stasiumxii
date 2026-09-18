extends Node2D

## Phase B+ prototype scene. Isolated from the live hot-seat duel.
## Open this scene (F6 / Run Current Scene). Do not change project.godot main_scene.
## CombatSim is not consulted; clicks never call submit(move).

const START := Vector2i(0, 0)
const DEMO_DEST := Vector2i(4, 0)

var _tiles: Dictionary = {}
var _views: Dictionary = {}
var _board_root: Node2D
var _hud: CanvasLayer
var _title: Label
var _body: Label
var _legend: Label
var _mp_budget: int = 6
var _origin: Vector2i = START
var _dest: Vector2i = Vector2i(-1, -1)
var _reach: Dictionary = {}
var _path: Array = []
var _hover: Vector2i = Vector2i(-99, -99)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.10, 0.12, 0.14))
	_tiles = ProtoBoard.demo_board()
	_board_root = Node2D.new()
	_board_root.name = "Board"
	_board_root.position = Vector2(480, 188)
	add_child(_board_root)
	_build_views()
	_build_hud()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_BRACKETLEFT, KEY_MINUS:
				_mp_budget = maxi(_mp_budget - 1, 0)
				_refresh()
			KEY_BRACKETRIGHT, KEY_EQUAL:
				_mp_budget = mini(_mp_budget + 1, 12)
				_refresh()
			KEY_R:
				_origin = START
				_dest = Vector2i(-1, -1)
				_refresh()
			KEY_ESCAPE:
				_dest = Vector2i(-1, -1)
				_refresh()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell(_board_root.get_local_mouse_position())
		if cell == Vector2i(-99, -99):
			return
		if cell == _origin:
			_dest = Vector2i(-1, -1)
		elif _reach.has(cell):
			_dest = cell
		else:
			_origin = cell
			_dest = Vector2i(-1, -1)
		_refresh()


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
	panel.color = Color(0.08, 0.07, 0.09, 0.82)
	panel.position = Vector2(12, 10)
	panel.size = Vector2(936, 118)
	_hud.add_child(panel)
	_title = _make_label(Vector2(24, 16), 16, Color(1.0, 0.92, 0.55))
	_body = _make_label(Vector2(24, 40), 13, Color(0.92, 0.90, 0.88))
	_legend = _make_label(Vector2(24, 86), 12, Color(0.78, 0.76, 0.72))
	_hud.add_child(_title)
	_hud.add_child(_body)
	_hud.add_child(_legend)
	var footer := _make_label(Vector2(24, 690), 12, Color(0.72, 0.70, 0.66))
	footer.text = "Main duel is unchanged: run res://main.tscn (F5). This scene is Proposed scaffolding only."
	_hud.add_child(footer)


func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(900, 40)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_update_copy()


func _update_copy() -> void:
	_title.text = "Phase B+ prototype  ·  Proposed (not Locked)  ·  not wired to CombatSim"
	var dest_txt := "click a cyan tile"
	if _dest != Vector2i(-1, -1):
		dest_txt = "%s  cost %d MP" % [_cell_text(_dest), ProtoPathfinder.path_cost(_reach, _dest)]
	_body.text = "Origin %s   MP budget %d  ([ ] or -/=)   Dest %s\nLeft-click a tile to move origin, or a reachable tile to preview the cheapest ortho path." % [
		_cell_text(_origin),
		_mp_budget,
		dest_txt,
	]
	var hover_txt := "Hover a tile for step cost."
	if _tiles.has(_hover) and _hover != _origin:
		var step: Dictionary = MovementCost.calculate(_tiles[_origin], _tiles[_hover])
		var edge: Dictionary = ProtoPathfinder.neighbor_weight(_tiles[_origin], _tiles[_hover])
		var data: ProtoBoardTile = _tiles[_hover]
		hover_txt = "Hover %s  %s elev %.1f  walkable %s  ·  step %s  ·  edge %s" % [
			_cell_text(_hover),
			TerrainDef.KIND_NAMES[data.terrain_type],
			data.elevation,
			data.walkable,
			_step_text(step),
			"weight %d" % int(edge["weight"]) if edge["ok"] else str(edge["reason"]),
		]
	elif _tiles.has(_hover):
		var here: ProtoBoardTile = _tiles[_hover]
		hover_txt = "Hover %s  %s elev %.1f (origin)" % [_cell_text(_hover), TerrainDef.KIND_NAMES[here.terrain_type], here.elevation]
	_legend.text = "Proposed: Ground 1 · Mud/Water 2 · Lava impassable · uphill +1/full, half +1 · downhill 0 · max climb 1 / drop 2 · ortho only.  " + hover_txt


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
