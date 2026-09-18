extends Node2D

## Phase B+ prototype demo. Proposed — not Locked.
## Open this scene (F6). Do not change project main_scene — Phase A duel stays on main.tscn.
## Click a highlighted tile: Dijkstra cheapest-MP path, then spend MP.

const TILE_SCENE: PackedScene = preload("res://prototypes/elevation_movement/proto_tile.tscn")
const PAWN_SCENE: PackedScene = preload("res://prototypes/elevation_movement/proto_pawn.tscn")
## Proposed demo MP pool (Phase A duel still uses Locked 3 on main).
const DEMO_MP: int = 6
const STEP_SEC: float = 0.22
const HOME := Vector2i(1, 4)
const BLOCKER := Vector2i(3, 3)

var board: ProtoBoard
var tiles: Dictionary = {}
var pawn: ProtoPawn
var blocker: ProtoPawn
var remaining_mp: int = DEMO_MP
var _busy: bool = false
var _hover: Vector2i = Vector2i(-1, -1)
var _coach: Label
var _mp_label: Label


func _ready() -> void:
	board = _make_demo_board()
	_build_tiles()
	pawn = PAWN_SCENE.instantiate() as ProtoPawn
	$Board/Units.add_child(pawn)
	blocker = PAWN_SCENE.instantiate() as ProtoPawn
	$Board/Units.add_child(blocker)
	_coach = $HUD/Root/Coach as Label
	_mp_label = $HUD/Root/MP as Label
	$HUD/Root/Reset.pressed.connect(_reset)
	_reset()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset()
			return
		if event.keycode == KEY_ESCAPE:
			_hover = Vector2i(-1, -1)
			_paint()
			return
	if event is InputEventMouseMotion:
		var cell := _pick_cell($Board.get_local_mouse_position())
		if cell != _hover:
			_hover = cell
			_paint()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell($Board.get_local_mouse_position())
		if cell.x < 0:
			return
		_try_walk(cell)


func _reset() -> void:
	if _busy:
		return
	remaining_mp = DEMO_MP
	board.clear_occupied()
	board.set_occupied(BLOCKER, "blocker")
	board.set_occupied(HOME, "pawn")
	pawn.place(HOME, board.get_tile(HOME), "pawn")
	pawn.set_facing("E")
	blocker.place(BLOCKER, board.get_tile(BLOCKER), "blocker")
	_hover = Vector2i(-1, -1)
	_set_coach("Proposed prototype. Click a cyan tile — cheapest MP path, not fewest tiles. R resets.")
	_paint()


func _try_walk(dest: Vector2i) -> void:
	var from := pawn.grid_position
	var result: Dictionary = MovementCost.validate_move(board, from, dest, remaining_mp)
	if not bool(result.get("ok", false)):
		_set_coach("Illegal — %s." % str(result.get("reason", "no_path")))
		_paint()
		return
	var path: Array = result["path"]
	var cost: int = int(result["cost"])
	_busy = true
	board.set_occupied(from, "")
	await _animate_path(path)
	if not is_inside_tree():
		return
	remaining_mp -= cost
	board.set_occupied(pawn.grid_position, "pawn")
	_busy = false
	_set_coach("Walked to %s (−%d MP). Cheapest path was %d hops." % [_cell_text(dest), cost, path.size()])
	_paint()


func _animate_path(path: Array) -> void:
	var prev := pawn.grid_position
	for step in path:
		var cell: Vector2i = step
		var dir := _hop_facing(prev, cell)
		pawn.set_facing(dir)
		var dest_tile := board.get_tile(cell)
		var world := dest_tile.world_position + Vector2(0.0, ZSortHelper.visual_y_offset(dest_tile.elevation))
		pawn.z_index = ZSortHelper.draw_order_index(dest_tile.world_position, dest_tile.elevation, ZSortHelper.UNIT_DRAW_BIAS)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(pawn, "position", world, STEP_SEC)
		await tween.finished
		pawn.place(cell, dest_tile, "pawn")
		pawn.set_facing(dir)
		prev = cell


func _paint() -> void:
	_mp_label.text = "MP  %d / %d   (Proposed demo pool — Phase A duel still uses 3)" % [remaining_mp, DEMO_MP]
	var reach: Dictionary = MovementReachability.tiles_within_mp(board, pawn.grid_position, remaining_mp)
	var path_cells := {}
	if reach.has(_hover):
		for step in reach[_hover]["path"]:
			path_cells[step] = true
	for cell in tiles.keys():
		var view: ProtoTile = tiles[cell]
		var kind := ""
		var shown := -1
		if not board.get_tile(cell).walkable:
			kind = "blocked"
		elif path_cells.has(cell):
			kind = "path"
			shown = int(reach[_hover]["cost"]) if cell == _hover else -1
		elif reach.has(cell):
			kind = "move"
			shown = int(reach[cell]["cost"])
		view.set_highlight(kind, shown)
	if remaining_mp <= 0:
		_set_coach("0 MP left. Press Reset or R.")


func _pick_cell(local: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_order := -INF
	for cell in tiles.keys():
		var view: ProtoTile = tiles[cell]
		if view.contains_local_point(local - view.position):
			var tile := board.get_tile(cell)
			var order := ZSortHelper.draw_order(tile.world_position, tile.elevation, 0.0)
			if order >= best_order:
				best_order = order
				best = cell
	return best


func _build_tiles() -> void:
	for cell in board.tiles.keys():
		var view := TILE_SCENE.instantiate() as ProtoTile
		view.bind(board.get_tile(cell))
		$Board/Tiles.add_child(view)
		tiles[cell] = view


func _make_demo_board() -> ProtoBoard:
	# Proposed mixed board: flats, mud, water corridor, lava, half-step, plateau, cliff.
	# Water row is the expensive short corridor; ground south of it is the cheap long path.
	var b := ProtoBoard.new(7, 6)
	var layout := [
		["G0", "G0", "W0", "W0", "W0", "G0", "G0"],
		["G0", "G0", "G0", "L0", "G0", "G0", "G3"],
		["G0", "M0", "G0", "G0", "G05", "G1", "G3"],
		["G0", "M0", "G0", "G0", "G05", "G1", "G1"],
		["G0", "G0", "G0", "M0", "G0", "G0", "G0"],
		["G0", "G0", "G0", "G0", "G0", "W0", "G0"],
	]
	for y in range(layout.size()):
		for x in range(layout[y].size()):
			var parsed := _parse_token(str(layout[y][x]))
			b.set_cell(Vector2i(x, y), float(parsed["elev"]), parsed["terrain"])
	return b


func _parse_token(token: String) -> Dictionary:
	var kind := token.substr(0, 1)
	var elev := 0.0 if token.length() <= 1 else float(token.substr(1))
	var terrain := TerrainCatalog.Type.GROUND
	match kind:
		"M":
			terrain = TerrainCatalog.Type.MUD
		"W":
			terrain = TerrainCatalog.Type.WATER
		"L":
			terrain = TerrainCatalog.Type.LAVA
		_:
			terrain = TerrainCatalog.Type.GROUND
	return {"terrain": terrain, "elev": elev}


func _hop_facing(from: Vector2i, to: Vector2i) -> String:
	var d: Vector2i = to - from
	if d.x > 0:
		return "E"
	if d.x < 0:
		return "W"
	if d.y > 0:
		return "S"
	return "N"


func _set_coach(text: String) -> void:
	if _coach != null:
		_coach.text = text


func _cell_text(cell: Vector2i) -> String:
	return "(%d,%d)" % [cell.x, cell.y]
