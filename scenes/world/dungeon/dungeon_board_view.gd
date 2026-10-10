extends "res://board_view.gd"

## VIEW ONLY. The combat board for a PC dungeon room. Same board, HUD and
## CombatSim as the Koliseo (board_view.gd is not changed); this view:
## - starts rooms from the run (no hot-seat boot, no New Match),
## - lets the player drive only the hero (seat 0),
## - plays the monster turns with the dungeon AI, one intent at a time, with
##   the usual walk / attack / hit animation,
## - draws the room: floor tiles, props, glowing pads and the backdrop, from
##   the art manifest or drawn placeholders,
## - spawns pawns for summoned monsters and fades out the fallen,
## - draws the hero on the painted class look (Pawn.painted_look); monsters
##   keep their own sprites.

signal room_over(result: String)
signal turn_changed(seat: int)

const AI := preload("res://backend/dungeon_ai.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const DungeonTile := preload("res://scenes/world/dungeon/dungeon_tile.gd")
const MonsterPawn := preload("res://scenes/world/dungeon/monster_pawn.gd")
const Props := preload("res://scenes/world/dungeon/dungeon_props.gd")
## Monster turns play back quickly: a short seat banner and a short beat
## before each monster acts (6-8 monsters in room A).
const MONSTER_BANNER_SEC := 0.3
const MONSTER_BEAT_SEC := 0.06
const Fx := preload("res://scenes/world/dungeon/dungeon_fx.gd")
const OUT_OF_RANGE_TEXT := "Out of range: walk closer"
const NO_TARGET_TEXT := "Click a ringed monster  ·  Esc to walk"
## How long the out-of-range note stays on the monster's card.
const NOTE_SEC := 2.2

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
	_tidy_hud()
	_clear_targeting()
	sim_node().reset_match(config)
	_rebuild_grid(int(sim_node().snapshot().get("board_size", 12)))
	_dress_room()
	_rebuild_pawns()
	_booted = true
	_refresh()
	_hydrate_turn_clock()
	_refit_soon()


## Fit again once the HUD and the run's roster have laid out for the room.
func _refit_soon() -> void:
	for i in 3:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_fit_board_camera()


func end_room() -> void:
	_room_live = false
	_clear_targeting()


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
		tile.set_decal(null, null, Rect2())
		if tile.pad_kind == "drain_grate":
			grate_cells.append(c)
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
		var grate: Dictionary = decals.get("drain_grate", {})
		if grate.has("tex"):
			# Kit rule: bottom-centre on the south tip of the south cell. Each
			# grate tile draws its own diamond of the decal (and of its glow),
			# so units on the grate stay on top.
			var size: Vector2 = (grate["tex"] as Texture2D).get_size() * float(grate.get("scale", 1.0))
			var at := _cell_to_local(south) + Vector2(-size.x * 0.5, 16.0 - size.y)
			for gc in grate_cells:
				var t = tiles[gc]
				t.set_decal(grate["tex"], grate.get("glow", null), Rect2(at - _cell_to_local(gc), size))
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.free()
	_backdrop = Props.make_backdrop(kit.get("backdrop", {}), room_id, _board_size)
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_fit_board_camera()


## Toxic pools (★5) show on their tiles as danger cells.
func _sync_pools() -> void:
	var snap: Dictionary = sim_node().snapshot()
	var cells := {}
	for pool in (snap.get("dungeon", {}) as Dictionary).get("pools", []):
		cells[_as_cell(pool["cell"])] = int(pool.get("turns", 0))
	for cell in tiles.keys():
		var t = tiles[cell]
		if t.has_method("set_pool"):
			t.set_pool(cells.has(cell), int(cells.get(cell, 0)), manifest)


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
	# Spell cards dock beside the action bar, never over the room; Walk and
	# End Turn sit next to the Face pad so the room's front tip has room.
	if _hud.tooltip_dock != "bar":
		_hud.set_tooltip_dock("bar")
	if _hud._action_bar != null and _hud._action_bar.alignment != FlowContainer.ALIGNMENT_BEGIN:
		_hud._action_bar.alignment = FlowContainer.ALIGNMENT_BEGIN
	# The bottom lines sit over the dark cellar: light text with an outline.
	for label in [_hud._selected_label, _hud._coach_label, _hud._aim_hit_label]:
		if label != null and not label.has_meta("dungeon_lit"):
			label.set_meta("dungeon_lit", true)
			label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5) if label == _hud._aim_hit_label else Color(0.94, 0.9, 0.82))
			label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))
			label.add_theme_constant_override("outline_size", 5)
	if str(_hud._turn_label_base).begins_with("HOST · "):
		_hud._turn_label_base = str(_hud._turn_label_base).trim_prefix("HOST · ")
		_hud._apply_turn_label_clock()


## Dungeon framing (the Koliseo band in board_view.gd is not used here).
## The camera takes the biggest zoom at which:
## - the whole room, backdrop walls included, is on screen (the back wall may
##   run up behind the top HUD strip),
## - the floor diamond plus a unit's head room above it stays clear of every
##   HUD panel and button (seat card, AP strip, the run's roster, the Face
##   pad, Walk / End Turn, the ability cluster and the docked spell card).
## Re-fit on every resize. The room is centred across; it slides up or down
## inside the band that keeps it clear.
const FRAME_TOP := 4.0
const FRAME_BOTTOM := 4.0
const FRAME_SIDE := 8.0
## World px above the floor diamond kept clear for units' heads and names.
const HEAD_ROOM := 64.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 3.0
var _frame_shown := Rect2()


## The screen rect the room was fitted into (the room's own rect on screen).
func frame_rect() -> Rect2:
	if _frame_shown.size.x > 0.0:
		return _frame_shown
	var vis := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(VIEW_W, VIEW_H)
	return Rect2(FRAME_SIDE, FRAME_TOP, vis.x - FRAME_SIDE * 2.0, vis.y - FRAME_TOP - FRAME_BOTTOM)


func room_rect() -> Rect2:
	var n := _board_size
	var rect := Rect2(Vector2(float(-(n - 1)) * 32.0 - 32.0, -36.0), Vector2(float(n - 1) * 64.0 + 64.0, float(2 * (n - 1)) * 16.0 + 52.0))
	if _backdrop != null and is_instance_valid(_backdrop) and _backdrop.has_method("bounds"):
		rect = rect.merge(_backdrop.bounds())
	return rect


## The floor diamond and the head room above it, board-local px (convex).
func floor_keep_clear() -> PackedVector2Array:
	var n := _board_size
	var top := _cell_to_local(Vector2i(0, 0)) + Vector2(0, -16)
	var right := _cell_to_local(Vector2i(n - 1, 0)) + Vector2(32, 0)
	var bottom := _cell_to_local(Vector2i(n - 1, n - 1)) + Vector2(0, 16)
	var left := _cell_to_local(Vector2i(0, n - 1)) + Vector2(-32, 0)
	var up := Vector2(0, -HEAD_ROOM)
	return PackedVector2Array([left + up, top + up, right + up, right, bottom, left])


## HUD rects (canvas px) the floor must stay clear of.
func hud_keep_out(with_overlay: bool = true) -> Array:
	var out: Array = []
	if _hud == null:
		return out
	var controls: Array = []
	if not _hud._banner_panels.is_empty():
		controls.append(_hud._banner_panels[0])
	if _hud._kestrel_body != null:
		controls.append(_hud._kestrel_body)
	if _hud._ap_pips != null and _hud._ap_pips.get_parent() != null:
		controls.append(_hud._ap_pips.get_parent().get_parent())
	for b in _hud._face_buttons.values():
		controls.append(b)
	controls.append(_hud._walk_button)
	controls.append(_hud._end_turn_button)
	for host in _hud._spell_hosts.values():
		controls.append(host)
	# The run's right column is right-aligned text: keep clear of the text
	# itself, not the whole column box.
	var overlay := get_parent().get_node_or_null("DungeonOverlay") if get_parent() != null and with_overlay else null
	if overlay != null and overlay.get_child_count() > 0 and overlay.get_child(0) is Control:
		for line in (overlay.get_child(0) as Control).get_children():
			var r := _text_rect(line)
			if r.size.x > 0.0:
				out.append(r)
	for c in controls:
		if c == null or not is_instance_valid(c) or not (c is Control):
			continue
		var ctl := c as Control
		if not ctl.is_inside_tree() or not ctl.is_visible_in_tree() or ctl.size.x <= 0.0:
			continue
		out.append(ctl.get_global_rect())
	if _hud.tooltip_dock == "bar":
		out.append(_hud.tooltip_dock_rect())
	return out


## The drawn text of a right-aligned Label / RichTextLabel, canvas px.
static func _text_rect(c: Node) -> Rect2:
	if not (c is Control) or not (c as Control).is_visible_in_tree():
		return Rect2()
	var ctl := c as Control
	var full := ctl.get_global_rect()
	var w := full.size.x
	if c is RichTextLabel:
		w = minf(float((c as RichTextLabel).get_content_width()) + 8.0, full.size.x)
		full.size.y = minf(full.size.y, float((c as RichTextLabel).get_content_height()) + 4.0)
	elif c is Label:
		var label := c as Label
		var font := label.get_theme_font("font")
		var size := label.get_theme_font_size("font_size")
		var widest := 0.0
		for line in label.text.split("\n"):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		w = minf(widest + 8.0, full.size.x)
	if c is Label and (c as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		return Rect2(Vector2(full.end.x - w, full.position.y), Vector2(w, full.size.y))
	return Rect2(full.position, Vector2(w, full.size.y))


func _fit_board_camera() -> void:
	_ensure_camera()
	if is_inside_tree() and not get_viewport().size_changed.is_connected(_on_view_resized):
		get_viewport().size_changed.connect(_on_view_resized)
	var vis := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(VIEW_W, VIEW_H)
	var rect := room_rect()
	var fit := fit_for(vis, rect, floor_keep_clear(), hud_keep_out())
	var zoom: float = fit["zoom"]
	var at: Vector2 = fit["at"]
	_camera.zoom = Vector2(zoom, zoom)
	_fit_camera_pos = rect.position - (at - vis * 0.5) / zoom
	_camera.position = _fit_camera_pos
	_camera.reset_smoothing()
	_frame_shown = Rect2(at, rect.size * zoom)


func _on_view_resized() -> void:
	_fit_board_camera()
	# HUD containers lay out on the next frame; fit again once they have.
	if is_inside_tree():
		await get_tree().process_frame
		if is_inside_tree():
			_fit_board_camera()


## {zoom, at}: the biggest zoom (and the room's top-left on screen) that
## keeps the room on screen and the floor clear of `keep_out`.
static func fit_for(vis: Vector2, rect: Rect2, floor_poly: PackedVector2Array, keep_out: Array) -> Dictionary:
	var cap := minf((vis.x - FRAME_SIDE * 2.0) / rect.size.x, (vis.y - FRAME_TOP - FRAME_BOTTOM) / rect.size.y)
	cap = clampf(cap, ZOOM_MIN, ZOOM_MAX)
	var lo := ZOOM_MIN
	var hi := cap
	var best: Variant = _placement(vis, rect, floor_poly, keep_out, cap)
	if best != null:
		return {"zoom": cap, "at": best}
	var found: Variant = _placement(vis, rect, floor_poly, keep_out, lo)
	if found == null:
		# Nothing clears the HUD (tiny window): centre the room at the cap.
		return {"zoom": cap, "at": Vector2((vis.x - rect.size.x * cap) * 0.5, (vis.y - rect.size.y * cap) * 0.5)}
	for i in 14:
		var mid := (lo + hi) * 0.5
		var at: Variant = _placement(vis, rect, floor_poly, keep_out, mid)
		if at != null:
			lo = mid
			found = at
		else:
			hi = mid
	return {"zoom": lo, "at": found}


## The room's top-left on screen at `zoom`: centred across when it can be,
## else slid a little sideways (SLIDE_STEPS), and in the middle of the
## vertical band where the floor clears the HUD. Null when none does.
const SLIDE_STEPS := [0.0, 24.0, -24.0]


static func _placement(vis: Vector2, rect: Rect2, floor_poly: PackedVector2Array, keep_out: Array, zoom: float) -> Variant:
	var y_min := FRAME_TOP
	var y_max := vis.y - FRAME_BOTTOM - rect.size.y * zoom
	if y_max < y_min:
		return null
	var quads: Array = []
	for r in keep_out:
		var box: Rect2 = r
		quads.append(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]))
	for slide in SLIDE_STEPS:
		var x0 := (vis.x - rect.size.x * zoom) * 0.5 + float(slide)
		if x0 < FRAME_SIDE or x0 + rect.size.x * zoom > vis.x - FRAME_SIDE:
			continue
		var ok: Array = []
		var steps := maxi(int((y_max - y_min) / 4.0), 0)
		for i in steps + 1:
			var y := y_min + float(i) * 4.0 if steps > 0 else y_min
			var origin := Vector2(x0, y)
			var poly := PackedVector2Array()
			for p in floor_poly:
				poly.append((p - rect.position) * zoom + origin)
			var clear := true
			for quad in quads:
				if not Geometry2D.intersect_polygons(poly, quad).is_empty():
					clear = false
					break
			if clear:
				ok.append(y)
		if not ok.is_empty():
			return Vector2(x0, float(ok[ok.size() / 2]))
	return null


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
		mp.bind_art(manifest, str(unit["monster"]), bool(unit.get("boss", false)), str(unit.get("variant_of", "")))
		pawn = mp
	else:
		pawn = PAWN_SCENE.instantiate() as Pawn
		# The hero plays the locked painted idle, walk, attack, skill, hit
		# and death of its class (units/painted_looks.gd).
		pawn.painted_look = true
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
			if str(event.get("projectile", "")) != "":
				var to_cell := _as_cell(event.get("to", Vector2i.ZERO))
				var to_at := _cell_to_local(to_cell) + Vector2(0, -26)
				var from_at: Vector2 = pawn.position + (pawn.release_offset() if pawn.has_method("release_offset") else Vector2(0, -22))
				var at_sec: float = pawn.release_sec() if pawn.has_method("release_sec") else 0.22
				longest = maxf(longest, Fx.throw(self, manifest, str(event["projectile"]), from_at, to_at, typ == "hit", VISUAL_SORT.unit_z_index(to_cell) + 6, at_sec))
		elif typ == "summon" or typ == "pools":
			longest = maxf(longest, pawn.play_view_plan({"cast": true, "strip": "summon"}))
	_pending_motion_sec = minf(longest, VIEW_MOTION.ACTION_LOCK_MAX)


func _refresh() -> void:
	super._refresh()
	_tidy_hud()
	_sync_pools()
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
		await get_tree().create_timer(MONSTER_BEAT_SEC).timeout
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


# --- Targeting: unit picking, in-range rings, hover card, out-of-range ------

var _target_cells: Dictionary = {}
var _hover_seat := -1
var _mouse_seen := false
var _cursor := Input.CURSOR_ARROW
var _card_layer: CanvasLayer
var _card: PanelContainer
var _card_label: Label
var _note := {}
var _assist := {}
var _keep_out_sig := ""
var _card_key := ""
var _card_at := 0
## Game-time clock for the note / assist windows (follows the frame delta,
## so a slow frame or a recorded movie keeps the same windows).
var _game_ms := 0.0


func _now_ms() -> int:
	return int(_game_ms)
var _keep_out_check := 0.0


## Enemy / ally / any / burst casts take a unit's cell as their target.
static func spell_target_kind(spell_id: String) -> String:
	if spell_id == "":
		return ""
	var kind := str(SpellKits.spell(spell_id).get("target", ""))
	return kind if kind in ["enemy", "ally", "any", "burst"] else ""


func _armed_target_kind() -> String:
	return spell_target_kind(_hud.selected_spell()) if _hud != null else ""


## With a unit cast armed, a point on a unit's sprite picks that unit's cell;
## otherwise (and in Walk) the floor diamond under the point, as before.
func _pick_local(local: Vector2) -> Vector2i:
	var kind := _armed_target_kind()
	if kind != "":
		var seat := unit_seat_at(local, kind)
		if seat >= 0:
			return (pawns_by_seat[seat] as Pawn).grid_position
	return TOUCH.pick_board_cell(local, _tile_positions(), [], false)


## The seat whose sprite is under a board-local point, or -1. Visible pixels
## beat the generous body box; among equals the front-most (draw order) wins.
## kind: "enemy" / "burst" (monsters), "ally" (the hero), "any" (both).
func unit_seat_at(local: Vector2, kind: String = "enemy") -> int:
	var point := to_global(local)
	var best := -1
	var best_key := []
	for seat in pawns_by_seat.keys():
		var pawn = pawns_by_seat[seat]
		if pawn == null or not is_instance_valid(pawn) or not pawn.visible or not bool(pawn.alive):
			continue
		var hero := int(seat) == 0
		if hero and kind in ["enemy", "burst"]:
			continue
		if not hero and kind == "ally":
			continue
		var level := 0
		if pawn.has_method("pick_test"):
			level = int(pawn.pick_test(point))
		elif TOUCH.hits_pawn_body(local, (pawn as Pawn).position):
			level = 1
		if level <= 0:
			continue
		var key := [level, int(pawn.z_index), (pawn as Pawn).position.y]
		if best < 0 or pick_key_beats(key, best_key):
			best = int(seat)
			best_key = key
	return best


## [level, z_index, y]: a pixel hit beats a box hit, then the front-most.
static func pick_key_beats(a: Array, b: Array) -> bool:
	for i in a.size():
		if float(a[i]) != float(b[i]):
			return float(a[i]) > float(b[i])
	return false


func _clear_targeting() -> void:
	_target_cells.clear()
	_hover_seat = -1
	_note = {}
	_assist = {}
	for pawn in pawns_by_seat.values():
		if pawn != null and is_instance_valid(pawn) and pawn.has_method("set_target_state"):
			pawn.set_target_state("")
	_set_cursor(Input.CURSOR_ARROW)
	if _card != null:
		_card.visible = false


func _hero_can_aim() -> bool:
	if not _room_live or autoplay or _busy or _view_locked or _driving:
		return false
	var snap: Dictionary = sim_node().snapshot()
	return not bool(snap.get("match_over", false)) and int(snap.get("active_seat", -1)) == 0


## Legal target cells for the armed spell: {cell: seat}.
func target_cells() -> Dictionary:
	return _target_cells


func _paint_highlights() -> void:
	super._paint_highlights()
	_sync_target_marks()


func _sync_target_marks() -> void:
	_target_cells.clear()
	var kind := _armed_target_kind()
	if kind != "" and _hero_can_aim():
		var snap: Dictionary = sim_node().snapshot()
		var legal: Array = sim_node().legal_intents(0)
		for dest in SNAPSHOT_TILES.cast_dests(legal, _hud.selected_spell()):
			var cell := _as_cell(dest)
			for unit in snap.get("units", []):
				if bool(unit.get("alive", false)) and _as_cell(unit.get("pos", Vector2i(-1, -1))) == cell:
					_target_cells[cell] = int(unit["seat"])
	for seat in pawns_by_seat.keys():
		var pawn = pawns_by_seat[seat]
		if pawn == null or not is_instance_valid(pawn) or not pawn.has_method("set_target_state"):
			continue
		var state := ""
		if kind in ["enemy", "any", "burst"] and _hero_can_aim() and bool(pawn.alive):
			if _target_cells.has((pawn as Pawn).grid_position):
				state = "hover" if int(seat) == _hover_seat else "legal"
			else:
				state = "dim"
		pawn.set_target_state(state)


## Target-state of a monster seat ("", "legal", "hover", "dim"), for tests.
func target_state(seat: int) -> String:
	var pawn = pawns_by_seat.get(seat)
	if pawn == null or not is_instance_valid(pawn) or not ("target_state" in pawn):
		return ""
	return str(pawn.target_state)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not TOUCH.is_emulated_mouse(event):
		_mouse_seen = true


func _process(delta: float) -> void:
	super._process(delta)
	_game_ms += delta * 1000.0
	_keep_out_check -= delta
	if _keep_out_check <= 0.0 and is_inside_tree():
		_keep_out_check = 0.25
		# HUD panels only: the roster's text changes as monsters fall and must
		# not move the camera mid-fight.
		var sig := str(hud_keep_out(false)) + str(get_viewport().get_visible_rect().size)
		if sig != _keep_out_sig:
			_keep_out_sig = sig
			_fit_board_camera()
	if _room_live and _mouse_seen and is_inside_tree():
		hover_at(($Tiles as Node2D).get_local_mouse_position(), _pointer_over_hud())
	_sync_card()


func _pointer_over_hud() -> bool:
	if _hud == null or not is_inside_tree():
		return false
	var at := get_viewport().get_mouse_position()
	if _hud.claims_screen_point(at):
		return true
	return _hud.tooltip_visible() and _hud.tooltip_rect().has_point(at)


## Hover at a board-local point: rings the hovered target, shows its card,
## sets the target cursor and closes the spell card. Called each frame for
## the mouse; tests call it directly.
func hover_at(local: Vector2, over_hud: bool = false) -> void:
	var seat := -1
	if not over_hud and _hero_can_aim():
		var kind := _armed_target_kind()
		seat = unit_seat_at(local, kind if kind != "" else "enemy")
	if seat != _hover_seat:
		_hover_seat = seat
		_sync_target_marks()
		if seat >= 0 and _armed_target_kind() != "":
			_sync_aim_preview((pawns_by_seat[seat] as Pawn).grid_position)
	var legal_hover := seat >= 0 and _target_cells.has((pawns_by_seat[seat] as Pawn).grid_position)
	if seat >= 0 and _armed_target_kind() != "" and _hud != null and _hud.tooltip_visible() and not _hud.tooltip_pinned():
		_hud.hide_spell_tooltip()
	_set_cursor(Input.CURSOR_CROSS if legal_hover else Input.CURSOR_ARROW)


func hovered_seat() -> int:
	return _hover_seat


func cursor_shape() -> int:
	return _cursor


func _set_cursor(shape: int) -> void:
	if shape == _cursor:
		return
	_cursor = shape
	Input.set_default_cursor_shape(shape as Input.CursorShape)


func _exit_tree() -> void:
	if _cursor != Input.CURSOR_ARROW:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_cursor = Input.CURSOR_ARROW


## The card beside the hovered (or just-clicked) monster: name, HP, and with
## a cast armed the hit % and damage from preview_cast, or why it can't land.
func card_text() -> String:
	if _card == null or not _card.visible:
		return ""
	return _card_label.text


func _card_seat() -> int:
	# A hovered monster wins; the note stays on its monster while nothing else is hovered.
	if _hover_seat >= 0:
		return _hover_seat
	if not _note.is_empty() and _now_ms() < int(_note.get("until", 0)):
		return int(_note.get("seat", -1))
	return -1


func _sync_card() -> void:
	var seat := _card_seat()
	if seat < 0 or not _room_live or not pawns_by_seat.has(seat):
		if _card != null:
			_card.visible = false
		return
	var pawn: Pawn = pawns_by_seat[seat]
	if not is_instance_valid(pawn) or not pawn.visible:
		if _card != null:
			_card.visible = false
		return
	_ensure_card()
	var now := _now_ms()
	var key := "%d|%s|%s" % [seat, _hud.selected_spell() if _hud != null else "", str(_note.get("until", 0))]
	if key != _card_key or now - _card_at > 200 or not _card.visible:
		_card_key = key
		_card_at = now
		_card_label.text = _card_lines(seat)
	_card.reset_size()
	var head := -float(pawn.body_height()) if pawn.has_method("body_height") else -110.0
	var at: Vector2 = pawn.get_global_transform_with_canvas() * Vector2(30.0, head * 0.6)
	var vis := get_viewport().get_visible_rect().size
	var size := _card.size
	at.x = clampf(at.x, 4.0, vis.x - size.x - 4.0)
	at.y = clampf(at.y - size.y * 0.5, 4.0, vis.y - size.y - 4.0)
	_card.position = at
	_card.visible = true


func _card_lines(seat: int) -> String:
	var snap: Dictionary = sim_node().snapshot()
	var unit := _unit_from_seat(snap, seat)
	var lines: PackedStringArray = []
	lines.append("%s   %d/%d HP" % [str(unit.get("name", "")), int(unit.get("hp", 0)), int(unit.get("max_hp", 1))])
	var spell := _hud.selected_spell() if _hud != null else ""
	if spell != "" and spell_target_kind(spell) != "":
		var pv: Dictionary = sim_node().preview_cast({"spell": spell, "seat": 0, "to": _as_cell(unit.get("pos", Vector2i.ZERO)), "target_seat": seat})
		var name := str(SpellKits.spell(spell).get("name", spell))
		if bool(pv.get("legal", false)):
			var parts: PackedStringArray = [name]
			if pv.get("hit_chance") != null:
				parts.append("HIT %d%%" % int(pv["hit_chance"]))
			if pv.get("sample_damage") != null:
				parts.append("%d dmg" % int(pv["sample_damage"]))
			lines.append("  ·  ".join(parts))
		else:
			lines.append("%s: %s" % [name, _reason_text(str(pv.get("reason", "")))])
	if not _note.is_empty() and int(_note.get("seat", -1)) == seat and _now_ms() < int(_note.get("until", 0)):
		lines.append(str(_note.get("text", "")))
	return "\n".join(lines)


static func _reason_text(reason: String) -> String:
	match reason:
		"out_of_range":
			return "out of range"
		"insufficient_ap":
			return "not enough AP"
		"insufficient_mp":
			return "not enough MP"
		"stunned_cannot_act":
			return "stunned"
		"no_target":
			return "no target"
		"open_can_wait":
			return "not yet"
	return "can't target" if reason != "" else ""


func _ensure_card() -> void:
	if _card != null and is_instance_valid(_card):
		return
	_card_layer = CanvasLayer.new()
	_card_layer.name = "TargetCard"
	_card_layer.layer = 12
	add_child(_card_layer)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.06, 0.9)
	style.border_color = Color(0.95, 0.74, 0.32, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_card.add_theme_stylebox_override("panel", style)
	_card_layer.add_child(_card)
	_card_label = Label.new()
	_card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_label.add_theme_font_size_override("font_size", 14)
	_card_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	_card.add_child(_card_label)
	_card.visible = false


## A click while a unit cast is armed. Legal target: cast as before. A unit
## out of range: a short note, never the refund line, and the cast stays
## armed. A melee cast with a free cell in reach offers walk-then-strike: a
## second click on the same monster walks there and casts.
func _handle_left_click(cell: Vector2i) -> void:
	var spell := _hud.selected_spell() if _hud != null else ""
	var kind := spell_target_kind(spell)
	if kind == "" or not _room_live or not _can_control_seat(0) or _active_is_stunned():
		_assist = {}
		super._handle_left_click(cell)
		return
	if _target_cells.has(cell):
		_assist = {}
		_note = {}
		super._handle_left_click(cell)
		return
	var snap: Dictionary = sim_node().snapshot()
	var target := {}
	for unit in snap.get("units", []):
		if bool(unit.get("alive", false)) and _as_cell(unit.get("pos", Vector2i(-1, -1))) == cell:
			target = unit
	var hero_cell := int(target.get("seat", -1)) == 0
	if target.is_empty() or (hero_cell and kind in ["enemy", "burst"]) or (not hero_cell and kind == "ally"):
		_assist = {}
		_hud.show_toast(NO_TARGET_TEXT)
		return
	var seat := int(target["seat"])
	var pv: Dictionary = sim_node().preview_cast({"spell": spell, "seat": 0, "to": cell, "target_seat": seat})
	var reason := str(pv.get("reason", ""))
	if reason == "out_of_range":
		var plan := walk_strike_plan(spell, seat)
		if not plan.is_empty() and int(_assist.get("seat", -1)) == seat and str(_assist.get("spell", "")) == spell and _now_ms() < int(_assist.get("until", 0)):
			_assist = {}
			_note = {}
			_walk_then_cast(plan)
			return
		var name := str(SpellKits.spell(spell).get("name", spell))
		var hint := "Click again: walk + %s" % name if not plan.is_empty() else ""
		_assist = {"seat": seat, "spell": spell, "until": _now_ms() + 4000} if not plan.is_empty() else {}
		_hud.show_toast(OUT_OF_RANGE_TEXT)
		_note = {"seat": seat, "text": OUT_OF_RANGE_TEXT + ("\n" + hint if hint != "" else ""), "until": _now_ms() + int(NOTE_SEC * 1000.0) + (1800 if hint != "" else 0)}
		return
	_assist = {}
	var short := _reason_text(reason)
	_hud.show_toast("%s: %s" % [str(SpellKits.spell(spell).get("name", spell)), short if short != "" else "can't target"])
	_note = {"seat": seat, "text": short.capitalize() if short != "" else "", "until": _now_ms() + int(NOTE_SEC * 1000.0)}


## Melee (range 1) only: the free cell next to the target that a legal walk
## reaches with the MP left and from which the cast is legal. {} when none.
func walk_strike_plan(spell: String, seat: int) -> Dictionary:
	var def: Dictionary = SpellKits.spell(spell)
	if int(def.get("max_range", 0)) != 1:
		return {}
	var snap: Dictionary = sim_node().snapshot()
	var hero := _unit_from_seat(snap, 0)
	var target := _unit_from_seat(snap, seat)
	if hero.is_empty() or target.is_empty() or int(hero.get("ap", 0)) < int(def.get("ap", 0)):
		return {}
	var from := _as_cell(hero.get("pos", Vector2i.ZERO))
	var to := _as_cell(target.get("pos", Vector2i.ZERO))
	var best := Vector2i(-1, -1)
	var best_d := 1 << 20
	for dest in SNAPSHOT_TILES.walk_dests(sim_node().legal_intents(0)):
		var c := _as_cell(dest)
		var pv: Dictionary = sim_node().preview_cast({"spell": spell, "seat": 0, "from": c, "to": to, "target_seat": seat})
		if not bool(pv.get("in_range", false)):
			continue
		var d := absi(c.x - from.x) + absi(c.y - from.y)
		if d < best_d:
			best_d = d
			best = c
	if best.x < 0:
		return {}
	return {"walk_to": best, "spell": spell, "target": to, "seat": seat}


func _walk_then_cast(plan: Dictionary) -> void:
	await _submit_now({"type": "move", "to": plan["walk_to"]})
	if not is_inside_tree() or not _room_live:
		return
	var snap: Dictionary = sim_node().snapshot()
	if int(snap.get("active_seat", -1)) != 0 or _as_cell(_unit_from_seat(snap, 0).get("pos", Vector2i(-1, -1))) != plan["walk_to"]:
		return
	var legal: Array = sim_node().legal_intents(0)
	if not SNAPSHOT_TILES.cast_dests(legal, str(plan["spell"])).has(plan["target"]):
		_paint_highlights()
		return
	await _submit_now({"type": "cast", "spell": plan["spell"], "to": plan["target"]})
	if _hud != null:
		_hud.clear_spell()
	_paint_highlights()
