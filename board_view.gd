extends Node2D

## Thin client: input + presentation only. CombatSim owns HP/AP/MP/rolls.
## Walk: dest-click only. CombatSim expands the ortho path; this view never sends
## intent.path. Pawns tween one ortho tile at a time along the returned walk path.
## Advance: dest-click teleport snap. No hop playback; CombatSim ignores client path.
## Mark Shot: selected chrome paints the Chebyshev 2–5 range ring; walk chrome stays off.
## Proposed timers: ~1.0s client-only seat handoff banner, plus a 30s seat clock
## (TurnClock.DURATION_SEC) that auto End Turns on expiry. Walk hops lock input
## but do not pause the clock.

const BOARD_SIZE: int = 8
const TILE_SCENE: PackedScene = preload("res://board/tile.tscn")
const PAWN_SCENE: PackedScene = preload("res://units/pawn.tscn")
const STEP_SEC: float = 0.28
const STEP_PAUSE_SEC: float = 0.08
const HANDOFF_SEC: float = 1.0

var tiles: Dictionary = {}
var selected_tile: BoardTile = null
var pawns_by_seat: Dictionary = {}
var _hud: CombatHUD
var _booted: bool = false
var _busy: bool = false
var _clock_expired_pending: bool = false
var _walk_tween: Tween
var _turn_clock := TurnClock.new()


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
	_turn_clock.start()
	_refresh()
	_sync_turn_clock()


func local_to_grid(point: Vector2) -> Vector2i:
	var grid_x := point.x / 64.0 + point.y / 32.0
	var grid_y := point.y / 32.0 - point.x / 64.0
	return Vector2i(floori(grid_x + 0.5), floori(grid_y + 0.5))


func _process(delta: float) -> void:
	if not _booted:
		return
	var snap := CombatSim.snapshot()
	if snap.get("match_over", false):
		_turn_clock.stop()
		_sync_turn_clock()
		return
	# Keep ticking during walk hop animations. _busy only locks input.
	# Advance is an instant snap (no hop). The ~1s handoff banner still uses
	# pause() so the next seat's 30s does not drain while they cannot act.
	if _turn_clock.tick(delta):
		_sync_turn_clock()
		_on_turn_clock_expired()
		return
	_sync_turn_clock()


func _sync_turn_clock() -> void:
	if _hud == null:
		return
	_hud.set_turn_clock(_turn_clock.display_seconds(), _turn_clock.running, _turn_clock.fraction_left())


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
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
		# Dest-click only. Do not send a client path.
		_submit({"type": "move", "to": cell})
		return
	var actor := _active_unit(CombatSim.snapshot())
	if actor.is_empty() or not CombatHUD.offered_cast_ids(actor).has(spell_id):
		_hud.clear_spell()
		_paint_highlights()
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
	if _busy:
		return
	_paint_highlights()


func _on_face_requested(dir: String) -> void:
	_submit({"type": "face", "dir": dir})


func _on_end_turn_button_pressed() -> void:
	if _busy:
		return
	_busy = true
	_turn_clock.pause()
	_hud.clear_spell()
	var result: Dictionary = CombatSim.submit({"type": "end_turn"})
	if not result.get("ok", false):
		_busy = false
		_turn_clock.resume()
		_refresh()
		return
	var snap := CombatSim.snapshot()
	if snap.get("match_over", false):
		_turn_clock.stop()
		_busy = false
		_refresh()
		return
	# Proposed: client-only ~1.0s seat handoff. CombatSim already advanced.
	# Start the next seat's clock at 30s but pause it through the banner.
	_turn_clock.start()
	_turn_clock.pause()
	_hud.set_locked(true)
	_refresh()
	_sync_turn_clock()
	var next_unit := _active_unit(snap)
	_hud.show_turn_banner(str(next_unit.get("name", "Next")), str(next_unit.get("class_id", "")))
	await get_tree().create_timer(HANDOFF_SEC).timeout
	if not is_inside_tree():
		return
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_busy = false
	_turn_clock.resume()
	_refresh()
	_sync_turn_clock()


func _on_turn_clock_expired() -> void:
	# Same path as pressing End Turn. If hops are in flight, finish them first
	# so the already-applied dest is visible, then auto End Turn.
	if _busy:
		_clock_expired_pending = true
		return
	_clock_expired_pending = false
	_on_end_turn_button_pressed()


func _on_new_match() -> void:
	_stop_walk_tween()
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_busy = false
	_clock_expired_pending = false
	_hud.clear_spell()
	CombatSim.reset_match({})
	_rebuild_pawns()
	_turn_clock.start()
	_refresh()
	_sync_turn_clock()


func _submit(intent: Dictionary) -> void:
	if _busy:
		return
	var result: Dictionary = CombatSim.submit(intent)
	if not result.get("ok", false) and str(result.get("reason", "")) in ["occupied", "same_tile", "out_of_bounds", "insufficient_mp", "missing_destination", "path_blocked"]:
		# Keep idle tile clicks from drowning the coach when simply selecting.
		if _hud.selected_spell() == "" and str(intent.get("type", "")) == "move":
			_refresh()
			return
	if result.get("ok", false):
		var path_event := _path_event(result.get("events", []))
		if not path_event.is_empty() and path_event.has("path"):
			var path: Array = path_event["path"]
			if not path.is_empty():
				await _play_walk(int(path_event.get("seat", 0)), path)
				return
	_refresh()


func _path_event(events: Array) -> Dictionary:
	for event in events:
		# Walk hops only. Advance is a teleport snap — do not play cell-by-cell path.
		if str(event.get("type", "")) == "move":
			return event
	return {}


func _play_walk(seat: int, path: Array) -> void:
	_busy = true
	_hud.set_locked(true)
	var snap := CombatSim.snapshot()
	_hud.render(snap, [])
	for tile in tiles.values():
		(tile as BoardTile).set_highlight("")
	for step in path:
		var cell: Vector2i = _as_cell(step)
		if tiles.has(cell):
			_tile_at(cell).set_highlight("move")
	await _animate_path(seat, path)
	if not is_inside_tree():
		return
	_hud.set_locked(false)
	_busy = false
	_refresh()
	if _clock_expired_pending:
		_clock_expired_pending = false
		_on_end_turn_button_pressed()


func _animate_path(seat: int, path: Array) -> void:
	if not pawns_by_seat.has(seat):
		return
	var pawn: Pawn = pawns_by_seat[seat]
	# One awaited hop per ortho tile so E/W-then-N/S cannot collapse into a diagonal slide.
	for step in path:
		if not is_inside_tree() or pawn == null or not is_instance_valid(pawn):
			return
		var cell: Vector2i = _as_cell(step)
		_stop_walk_tween()
		_walk_tween = create_tween()
		_walk_tween.set_parallel(false)
		_walk_tween.set_trans(Tween.TRANS_LINEAR)
		_walk_tween.set_ease(Tween.EASE_IN_OUT)
		_walk_tween.tween_property(pawn, "position", _cell_to_local(cell), STEP_SEC)
		await _walk_tween.finished
		_set_pawn_cell(pawn, cell)
		if STEP_PAUSE_SEC > 0.0:
			await get_tree().create_timer(STEP_PAUSE_SEC).timeout


func _set_pawn_cell(pawn: Pawn, cell: Vector2i) -> void:
	pawn.grid_position = cell
	pawn.z_index = cell.x + cell.y + 16


func _stop_walk_tween() -> void:
	if _walk_tween != null and is_instance_valid(_walk_tween):
		_walk_tween.kill()
	_walk_tween = null


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
	if snap.get("match_over", false) or _busy:
		return
	var legal: Array = CombatSim.legal_intents(int(snap.get("active_seat", 0)))
	var spell_id := _hud.selected_spell()
	var actor := _active_unit(snap)
	if spell_id != "" and not CombatHUD.offered_cast_ids(actor, legal).has(spell_id):
		spell_id = ""
	# Enemy-targeted spells: paint the range ring as soon as the spell is selected.
	# Walk chrome stays off. Aim chance chrome is client and is not added here.
	if spell_id != "" and spell_id != SpellKits.ADVANCE:
		var def: Dictionary = SpellKits.spell(spell_id)
		if str(def.get("target", "")) == "enemy":
			for cell in CombatSim.range_highlight_cells(int(snap.get("active_seat", 0)), spell_id):
				_tile_at(cell).set_highlight("range")
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


func _as_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
