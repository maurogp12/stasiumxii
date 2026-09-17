extends Node2D

## Thin client: input + presentation only. CombatSim owns HP/AP/MP/rolls.

const BOARD_SIZE: int = 8
const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")
const PAWN_SCENE: PackedScene = preload("res://units/pawn.tscn")

var tiles: Dictionary = {}
var selected_tile: BoardTile = null
var pawns_by_seat: Dictionary = {}
var _hud: CombatHUD
var _booted: bool = false


func _ready() -> void:
	_hud = $"../HUD" as CombatHUD
	_hud.spell_selected.connect(_on_spell_selected)
	_hud.face_requested.connect(_on_face_requested)
	_hud.end_turn_requested.connect(_on_end_turn_button_pressed)
	_hud.new_match_requested.connect(_on_new_match)

	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var tile := TILE_SCENE.instantiate() as BoardTile
			tile.grid_position = Vector2i(x, y)
			tile.position = _cell_to_local(tile.grid_position)
			tile.z_index = x + y
			$Tiles.add_child(tile)
			tiles[tile.grid_position] = tile

	call_deferred("_boot")


func _boot() -> void:
	CombatSim.reset_match({})
	_rebuild_pawns()
	_booted = true
	_refresh()


func local_to_grid(point: Vector2) -> Vector2i:
	var grid_x := point.x / 64.0 + point.y / 32.0
	var grid_y := point.y / 32.0 - point.x / 64.0
	return Vector2i(floori(grid_x + 0.5), floori(grid_y + 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_position: Vector2 = $Tiles.get_local_mouse_position()
		var cell := local_to_grid(mouse_position)
		if not _in_bounds(cell):
			return
		select_tile(cell)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_face_toward(cell)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(cell)


func select_tile(cell: Vector2i) -> void:
	if selected_tile != null:
		selected_tile.set_selected(false)
	selected_tile = tiles[cell] as BoardTile
	selected_tile.set_selected(true)


func _handle_left_click(cell: Vector2i) -> void:
	var spell_id := _hud.selected_spell()
	if spell_id == "":
		_submit({"type": "move", "to": cell})
		return
	_submit({"type": "cast", "spell": spell_id, "to": cell})
	if spell_id != SpellKits.ADVANCE:
		_hud.clear_spell()
		_paint_highlights()


func _face_toward(cell: Vector2i) -> void:
	var snap := CombatSim.snapshot()
	var actor := _active_unit(snap)
	if actor.is_empty():
		return
	var delta: Vector2i = cell - actor["pos"]
	if delta == Vector2i.ZERO:
		return
	var dir := "E"
	if absi(delta.x) >= absi(delta.y):
		dir = "E" if delta.x > 0 else "W"
	else:
		dir = "S" if delta.y > 0 else "N"
	_submit({"type": "face", "dir": dir})


func _on_spell_selected(_spell_id: String) -> void:
	_paint_highlights()


func _on_face_requested(dir: String) -> void:
	_submit({"type": "face", "dir": dir})


func _on_end_turn_button_pressed() -> void:
	_hud.clear_spell()
	_submit({"type": "end_turn"})


func _on_new_match() -> void:
	_hud.clear_spell()
	CombatSim.reset_match({})
	_rebuild_pawns()
	_refresh()


func _submit(intent: Dictionary) -> void:
	var result: Dictionary = CombatSim.submit(intent)
	if not result.get("ok", false) and str(result.get("reason", "")) in ["occupied", "same_tile", "out_of_bounds", "insufficient_mp", "missing_destination"]:
		# Keep idle tile clicks from drowning the coach when simply selecting.
		if _hud.selected_spell() == "" and str(intent.get("type", "")) == "move":
			_refresh()
			return
	_refresh()


func _refresh() -> void:
	var snap := CombatSim.snapshot()
	var legal: Array = CombatSim.legal_intents(int(snap.get("active_seat", 0)))
	_apply_units(snap)
	_hud.render(snap, legal)
	_paint_highlights()


func _rebuild_pawns() -> void:
	for child in $Units.get_children():
		$Units.remove_child(child)
		child.free()
	pawns_by_seat.clear()
	for unit in CombatSim.snapshot().get("units", []):
		var pawn := PAWN_SCENE.instantiate() as Pawn
		$Units.add_child(pawn)
		pawns_by_seat[int(unit["seat"])] = pawn


func _apply_units(snap: Dictionary) -> void:
	for unit in snap.get("units", []):
		var seat := int(unit["seat"])
		if not pawns_by_seat.has(seat):
			continue
		var pawn: Pawn = pawns_by_seat[seat]
		pawn.apply_snapshot(unit, int(snap.get("active_seat", 0)))
		pawn.position = _cell_to_local(unit["pos"])
		pawn.z_index = int(unit["pos"].x) + int(unit["pos"].y) + 16


func _paint_highlights() -> void:
	for tile in tiles.values():
		(tile as BoardTile).set_highlight("")
	var snap := CombatSim.snapshot()
	if snap.get("match_over", false):
		return
	var legal: Array = CombatSim.legal_intents(int(snap.get("active_seat", 0)))
	var spell_id := _hud.selected_spell()
	for intent in legal:
		var kind := str(intent.get("type", ""))
		if kind == "move" and spell_id == "" and intent.has("to"):
			_tile_at(intent["to"]).set_highlight("move")
		elif kind == "cast" and str(intent.get("spell", "")) == spell_id and intent.has("to"):
			var highlight := "advance" if spell_id == SpellKits.ADVANCE else "target"
			_tile_at(intent["to"]).set_highlight(highlight)


func _tile_at(cell: Vector2i) -> BoardTile:
	return tiles[cell] as BoardTile


func _active_unit(snap: Dictionary) -> Dictionary:
	var seat := int(snap.get("active_seat", 0))
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == seat:
			return unit
	return {}


func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * 32, (cell.x + cell.y) * 16)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD_SIZE and cell.y < BOARD_SIZE
