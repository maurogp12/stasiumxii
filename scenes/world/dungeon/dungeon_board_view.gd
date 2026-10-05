extends "res://board_view.gd"

## VIEW ONLY. The combat board for a PC dungeon room. Same board, HUD and
## CombatSim as the Koliseo (board_view.gd is not changed); this view:
## - starts rooms from the run (no hot-seat boot, no New Match),
## - lets the player drive only the hero (seat 0),
## - plays the monster turns with the dungeon AI, one intent at a time, with
##   the usual walk / attack / hit animation,
## - draws the room: floor tiles, props, glowing pads and the backdrop, from
##   the art manifest or drawn placeholders,
## - spawns pawns for summoned monsters and fades out the fallen.

signal room_over(result: String)
signal turn_changed(seat: int)

const AI := preload("res://backend/dungeon_ai.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const DungeonTile := preload("res://scenes/world/dungeon/dungeon_tile.gd")
const MonsterPawn := preload("res://scenes/world/dungeon/monster_pawn.gd")
const Props := preload("res://scenes/world/dungeon/dungeon_props.gd")
const MONSTER_BANNER_SEC := 0.55

var manifest: Dictionary = {}
var room_id := ""
var autoplay := false
var autoplay_pace := 0.35
var _driving := false
var _over_sent := false
var _room_live := false
var _backdrop: Node2D
var _props_root: Node2D


func _boot() -> void:
	# The run scene starts each room with start_room(). Nothing to boot here.
	pass


func start_room(config: Dictionary, art_manifest: Dictionary) -> void:
	manifest = art_manifest
	room_id = str((config.get("dungeon", {}) as Dictionary).get("room_id", ""))
	_over_sent = false
	_room_live = true
	_stop_flash_tweens()
	_stop_walk_tween()
	_busy = false
	_view_locked = false
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_hud.clear_spell()
	sim_node().reset_match(config)
	_rebuild_grid(int(sim_node().snapshot().get("board_size", 12)))
	_dress_room()
	_rebuild_pawns()
	_booted = true
	_refresh()
	_hydrate_turn_clock()


func end_room() -> void:
	_room_live = false


func _on_new_match() -> void:
	pass


func _can_control_seat(seat: int) -> bool:
	return seat == 0 and not autoplay and int(sim_node().snapshot().get("active_seat", -1)) == 0


func _rebuild_grid(size: int) -> void:
	var next := size if size > 0 else 12
	if next == _board_size and tiles.size() == next * next and not tiles.is_empty() and $Tiles.get_child_count() > 0 and $Tiles.get_child(0) is DungeonTile:
		return
	_board_size = next
	for child in $Tiles.get_children():
		$Tiles.remove_child(child)
		child.free()
	tiles.clear()
	selected_tile = null
	for y in range(next):
		for x in range(next):
			var tile := DungeonTile.new()
			tile.grid_position = Vector2i(x, y)
			tile.apply_board_data("ground", 0.0)
			tile.position = VISUAL_SORT.cell_to_local(tile.grid_position, 0.0)
			tile.z_index = VISUAL_SORT.tile_z_index(tile.grid_position, 0.0)
			$Tiles.add_child(tile)
			tiles[tile.grid_position] = tile
	_fit_board_camera()


## Floor art, pads, props, the grate decal and the backdrop for the room.
## Uses the art kit (manifest) when present, else drawn placeholders.
func _dress_room() -> void:
	var snap: Dictionary = sim_node().snapshot()
	var info: Dictionary = snap.get("dungeon", {})
	var pads: Array = info.get("pads", [])
	var kit := Art.room_kit(manifest, room_id, _board_size)
	var floors: Array = kit.get("floors", [])
	var pad_kit: Dictionary = kit.get("pad", {})
	var glow_kit: Dictionary = kit.get("pad_glow", {})
	var decals: Dictionary = kit.get("decals", {})
	var paint: Dictionary = snap.get("paint_only", {})
	var grate_cells: Array = []
	for cell in tiles.keys():
		var tile = tiles[cell]
		var c: Vector2i = cell
		var props: Array = paint.get(c, [])
		tile.pad = pads.has(c)
		tile.pad_kind = "drain_grate" if props.has("drain_grate") else "wheat_pad"
		tile.pad_color = Color(0.55, 0.95, 0.45) if tile.pad_kind == "drain_grate" else Color(1.0, 0.72, 0.28)
		tile.floor_tex = null
		if not floors.is_empty():
			tile.floor_tex = (floors[absi(c.x * 7 + c.y * 13 + c.x * c.y) % floors.size()] as Dictionary)["tex"]
		tile.pad_tex = null
		tile.skip_floor = false
		if tile.pad and tile.pad_kind == "wheat_pad" and not pad_kit.is_empty():
			tile.pad_tex = pad_kit["tex"]
		if tile.pad_kind == "drain_grate":
			grate_cells.append(c)
			tile.skip_floor = decals.has("drain_grate")
		tile.set_pad_glow(glow_kit.get("tex", null) if tile.pad_kind == "wheat_pad" else null, float(glow_kit.get("scale", 1.0)))
		tile.set_process(tile.pad)
		tile.queue_redraw()
	if _props_root != null and is_instance_valid(_props_root):
		_props_root.free()
	_props_root = Node2D.new()
	_props_root.name = "RoomProps"
	$Units.add_child(_props_root)
	for cell in paint.keys():
		var c2: Vector2i = cell if cell is Vector2i else _as_cell(cell)
		if bool(sim_node().tile_at(c2).get("walkable", true)):
			continue
		var names: Array = paint[cell]
		var kind := str(names[0]) if not names.is_empty() else "crate_stack"
		if kind.ends_with(":part"):
			continue
		var prop := Props.new()
		_props_root.add_child(prop)
		prop.setup(kind, c2, (kit.get("props", {}) as Dictionary).get(kind, {}))
		prop.position = _cell_to_local(c2)
		prop.z_as_relative = false
		prop.z_index = VISUAL_SORT.unit_z_index(c2, _elev_at(c2))
	if not grate_cells.is_empty():
		var south: Vector2i = grate_cells[0]
		for gc in grate_cells:
			if gc.x + gc.y > south.x + south.y:
				south = gc
		var decal := Props.make_decal(decals.get("drain_grate", {}), south)
		decal.position = _cell_to_local(south)
		_props_root.add_child(decal)
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.free()
	_backdrop = Props.make_backdrop(kit.get("backdrop", {}), room_id, _board_size)
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_fit_board_camera()


## The Koliseo HUD is shared as is; in a room it hides the second seat card
## (the run's monster list replaces it), the terrain legend and the
## online "HOST" prefix that the dungeon's local seat would show.
func _tidy_hud() -> void:
	if _hud == null:
		return
	if _hud._seat_panels.size() > 1 and _hud._seat_panels[1] != null:
		_hud._seat_panels[1].visible = false
	if _hud._terrain_legend != null:
		_hud._terrain_legend.visible = false
	if str(_hud._turn_label_base).begins_with("HOST · "):
		_hud._turn_label_base = str(_hud._turn_label_base).trim_prefix("HOST · ")
		_hud._apply_turn_label_clock()


## Fit the board and the backdrop's walls into the play band.
func _fit_board_camera() -> void:
	_ensure_camera()
	var n := _board_size
	var rect := Rect2(Vector2(float(-(n - 1)) * 32.0 - 32.0, -36.0), Vector2(float(n - 1) * 64.0 + 64.0, float(2 * (n - 1)) * 16.0 + 52.0))
	if _backdrop != null and is_instance_valid(_backdrop) and _backdrop.has_method("bounds"):
		rect = rect.merge(_backdrop.bounds())
	var play_w := VIEW_W - 32.0
	var play_h := PLAY_BOTTOM - PLAY_TOP
	var zoom := clampf(minf(play_w / rect.size.x, play_h / rect.size.y), 0.35, 1.6)
	_camera.zoom = Vector2(zoom, zoom)
	var center := rect.get_center()
	var play_center := Vector2(VIEW_W * 0.5, (PLAY_TOP + PLAY_BOTTOM) * 0.5)
	var view_center := Vector2(VIEW_W * 0.5, VIEW_H * 0.5)
	var camera_world := global_position + center - (play_center - view_center) / zoom
	_fit_camera_pos = camera_world - global_position
	_camera.position = _fit_camera_pos


func _rebuild_pawns() -> void:
	_stop_flash_tweens()
	for child in $Units.get_children():
		if child == _props_root:
			continue
		if child.get_script() == SHADE_MARKER:
			child.reparent(_shade_layer())
			continue
		$Units.remove_child(child)
		child.free()
	pawns_by_seat.clear()
	for unit in sim_node().snapshot().get("units", []):
		_add_pawn(unit)


func _add_pawn(unit: Dictionary) -> Pawn:
	var pawn: Pawn
	if unit.has("monster"):
		var mp := MonsterPawn.new()
		mp.bind_art(manifest, str(unit["monster"]), bool(unit.get("boss", false)))
		pawn = mp
	else:
		pawn = PAWN_SCENE.instantiate() as Pawn
	$Units.add_child(pawn)
	pawns_by_seat[int(unit["seat"])] = pawn
	return pawn


func _apply_units(snap: Dictionary) -> void:
	for unit in snap.get("units", []):
		var seat := int(unit["seat"])
		if not pawns_by_seat.has(seat):
			var pawn := _add_pawn(unit)
			pawn.position = _cell_to_local(_as_cell(unit["pos"]))
			pawn.modulate.a = 0.0
			create_tween().tween_property(pawn, "modulate:a", 1.0, 0.35)
	super._apply_units(snap)
	for unit in snap.get("units", []):
		var seat := int(unit["seat"])
		if unit.has("monster") and not bool(unit.get("alive", true)):
			var body = pawns_by_seat.get(seat)
			if body != null and body.has_method("fade_out"):
				if bool(unit.get("fled", false)):
					body.fade_out()
				elif not body.motion_playing():
					body.fade_out()


## Monster casts are not SpellKits spells, so ViewMotion has no plan for them.
## Add an attack lunge for a monster hit / miss and a wind-up for a summon.
func _arm_view_motions(events: Array) -> void:
	super._arm_view_motions(events)
	if VIEW_MOTION.reduce_motion():
		return
	var longest := _pending_motion_sec
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var typ := str(event.get("type", ""))
		var seat := int(event.get("seat", -1))
		if not pawns_by_seat.has(seat):
			continue
		var pawn: Pawn = pawns_by_seat[seat]
		if bool(event.get("monster_attack", false)) and (typ == "hit" or typ == "miss"):
			# The target's recoil / slump already comes from the base plans.
			longest = maxf(longest, pawn.play_view_plan({"attack": true, "aim": _aim_vector(seat, event)}))
		elif typ == "summon":
			longest = maxf(longest, pawn.play_view_plan({"cast": true, "strip": "summon"}))
	_pending_motion_sec = minf(longest, VIEW_MOTION.ACTION_LOCK_MAX)


func _refresh() -> void:
	super._refresh()
	_tidy_hud()
	if not _room_live:
		return
	var snap: Dictionary = sim_node().snapshot()
	if bool(snap.get("match_over", false)):
		if not _over_sent:
			_over_sent = true
			var result := str((snap.get("dungeon", {}) as Dictionary).get("result", ""))
			get_tree().create_timer(1.1).timeout.connect(func(): room_over.emit(result))
		return
	if _busy or _view_locked or _driving:
		return
	var active := int(snap.get("active_seat", 0))
	if active != 0:
		call_deferred("_drive_monsters")
	elif autoplay:
		call_deferred("_drive_hero")


func _drive_monsters() -> void:
	if _driving or _busy or _view_locked or not _room_live:
		return
	_driving = true
	_hud.set_locked(true)
	var guard := 0
	while _room_live and guard < 64:
		guard += 1
		var snap: Dictionary = sim_node().snapshot()
		if bool(snap.get("match_over", false)):
			break
		var seat := int(snap.get("active_seat", 0))
		if seat == 0:
			break
		turn_changed.emit(seat)
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return
		var faced := false
		var ended := false
		for step in AI.MAX_STEPS:
			var intent := AI.next_intent(sim_node(), seat, faced)
			if intent.is_empty():
				break
			if str(intent.get("type", "")) == "face":
				faced = true
			if str(intent.get("type", "")) == "end_turn":
				await _end_turn_now(intent)
				ended = true
				break
			await _submit_now(intent)
			if not is_inside_tree():
				return
			if bool(sim_node().snapshot().get("match_over", false)):
				break
			if int(sim_node().snapshot().get("active_seat", -1)) != seat:
				ended = true
				break
		if not ended and not bool(sim_node().snapshot().get("match_over", false)) and int(sim_node().snapshot().get("active_seat", -1)) == seat:
			await _end_turn_now({"type": "end_turn", "seat": seat})
	_driving = false
	_hud.set_locked(false)
	if is_inside_tree():
		_refresh()
		turn_changed.emit(int(sim_node().snapshot().get("active_seat", 0)))


## Autoplay (capture movie): the hero bot plays the hero's turns on screen.
func _drive_hero() -> void:
	if _driving or _busy or _view_locked or not _room_live or not autoplay:
		return
	_driving = true
	var guard := 0
	while _room_live and guard < AI.MAX_STEPS:
		guard += 1
		var snap: Dictionary = sim_node().snapshot()
		if bool(snap.get("match_over", false)) or int(snap.get("active_seat", -1)) != 0:
			break
		await get_tree().create_timer(autoplay_pace).timeout
		if not is_inside_tree():
			return
		var intent := AI.hero_intent(sim_node())
		if intent.is_empty():
			break
		if str(intent.get("type", "")) == "end_turn":
			await _end_turn_now(intent)
			break
		await _submit_now(intent)
	_driving = false
	if is_inside_tree():
		_refresh()


func _submit_now(intent: Dictionary) -> void:
	var guard := 0
	while (_busy or _view_locked) and guard < 600:
		guard += 1
		await get_tree().process_frame
	_hud.set_locked(false)
	await _submit(intent)
	guard = 0
	while (_busy or _view_locked) and guard < 600:
		guard += 1
		await get_tree().process_frame


func _end_turn_now(intent: Dictionary) -> void:
	var guard := 0
	while (_busy or _view_locked) and guard < 600:
		guard += 1
		await get_tree().process_frame
	_hud.clear_spell()
	var result: Dictionary = sim_node().submit(intent)
	if not bool(result.get("ok", false)):
		_refresh()
		return
	_present_resolve(result.get("events", []))
	if _pending_motion_sec > 0.0:
		await _await_view_motions()
	await _present_turn_handoff(result)


## Shorter seat banner for monster turns so a pack does not drag.
func _present_turn_handoff(result: Dictionary) -> void:
	var snap: Dictionary = result.get("snapshot", sim_node().snapshot())
	if snap.is_empty():
		snap = sim_node().snapshot()
	if bool(snap.get("match_over", false)):
		_busy = false
		_refresh()
		return
	_busy = true
	_hud.set_locked(true)
	super._refresh()
	var next_unit := _active_unit(snap)
	var monster := next_unit.has("monster")
	var caption := "" if monster else "Your turn"
	_tidy_hud()
	_hud.show_turn_banner(str(next_unit.get("name", "Next")), str(next_unit.get("class_id", "")), caption)
	await get_tree().create_timer(MONSTER_BANNER_SEC if monster else HANDOFF_SEC * 0.8).timeout
	if not is_inside_tree():
		return
	_hud.hide_turn_banner()
	_hud.set_locked(false)
	_busy = false
	_refresh()
	_hydrate_turn_clock()


func sim_node() -> Node:
	return get_node("/root/CombatSim")
