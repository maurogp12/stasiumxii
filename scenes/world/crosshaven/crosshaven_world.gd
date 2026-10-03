extends Node2D

## Crosshaven open world (PC, `main`). Click-to-walk around one chunk at a time;
## walking onto an exit tile fades into the linked chunk. A gate uses that
## same fade: walk to the arrow, then enter_zone on the target region.
##
## Data and walk rules come from Backend: `WorldMap`, `WorldZone`, `WorldWalk`
## (data/world/crosshaven/, docs/world/crosshaven_zone_format.md). This scene
## only draws and animates; it never decides what is walkable on its own.

signal zone_entered(zone_id: String, cell: Vector2i)
signal walk_rejected(reason: String)

const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")
const Ground := preload("res://scenes/world/crosshaven/crosshaven_ground.gd")
const Prop := preload("res://scenes/world/crosshaven/crosshaven_prop.gd")
const Walker := preload("res://scenes/world/crosshaven/crosshaven_walker.gd")
const Weather := preload("res://scenes/world/crosshaven/crosshaven_weather.gd")
const Decor := preload("res://scenes/world/crosshaven/crosshaven_decor.gd")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")
const Fx := preload("res://scenes/world/crosshaven/crosshaven_fx.gd")
const SettingsPanel := preload("res://ui/visual_settings_panel.gd")
const Progress := preload("res://backend/pc_progress.gd")
const CharacterWindow := preload("res://scenes/world/ui/character_window.gd")
const InventoryWindow := preload("res://scenes/world/ui/inventory_window.gd")
const RewardPopup := preload("res://scenes/world/ui/reward_popup.gd")
const Rewards := preload("res://backend/pc_rewards.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const NpcBook := preload("res://backend/world_npcs.gd")
const Missions := preload("res://backend/pc_missions.gd")
const WorldNpc := preload("res://scenes/world/npc/world_npc.gd")
const NpcDialogue := preload("res://scenes/world/ui/npc_dialogue.gd")
const MissionTracker := preload("res://scenes/world/ui/mission_tracker.gd")
const MissionLog := preload("res://scenes/world/ui/mission_log.gd")

const SEA := Color("2d4f63")
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.5
const FADE_SECONDS := 0.35

## Tests set this so exits swap chunks without waiting on the fade.
@export var instant_transitions := false

var map: WorldMap
var zone: WorldZone
var atlas = null
var load_errors: Array = []

var ground: Node2D
var props_root: Node2D
var decor_root: Node2D
var walker: Node2D
var camera: Camera2D
var weather: Node
var settings: VisualSettings
var visuals: CanvasLayer
var fx: Node
var progress = null
var character_window: CanvasLayer
var inventory_window: CanvasLayer
var reward_popup: CanvasLayer
var npcs_root: Node2D
var npc_plates: CanvasLayer
var npc_book = null
var dialogue: CanvasLayer
var missions = null
var tracker: CanvasLayer
var mission_log: CanvasLayer
var _pending_talk: Dictionary = {}
var _npc_by_cell: Dictionary = {}
var hover_cell := Vector2i(-1, -1)

var _hover: Node2D
var _max_h := 0
var _pending_exit := false
var _pending_gate: Dictionary = {}
var _transitioning := false
var _hud_label: Label
var _banner: Label
var _fade: ColorRect
var _screen_fx: CanvasLayer
var _zoom := 1.6
var _last_click_ms := 0
var _movie := ""
var _movie_t0 := 0
var _bench: Array[float] = []
var _bench_until := 0.0
var _window_before := Vector2i.ZERO
var _zoom_tween: Tween


func _ready() -> void:
	_read_launch_args()
	# Parent process runs after the walker so cover uses this frame's feet.
	process_priority = 1
	_apply_world_window()
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var sea := ColorRect.new()
	sea.color = SEA
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(sea)

	settings = VisualSettings.new()
	props_root = Node2D.new()
	props_root.name = "Props"
	add_child(props_root)
	npcs_root = Node2D.new()
	npcs_root.name = "Npcs"
	add_child(npcs_root)
	# Above the grade (layer 6), so Gloomfen fog does not wash the names out.
	npc_plates = CanvasLayer.new()
	npc_plates.name = "NpcPlates"
	npc_plates.layer = 7
	add_child(npc_plates)
	decor_root = Node2D.new()
	decor_root.name = "Decor"
	add_child(decor_root)
	settings.bind(self, "decor", _on_decor_flag)
	if not settings.preset_changed.is_connected(_on_preset):
		settings.preset_changed.connect(_on_preset)

	_hover = Node2D.new()
	_hover.name = "Hover"
	_hover.z_as_relative = false
	_hover.draw.connect(_draw_hover)
	add_child(_hover)

	walker = Walker.new()
	walker.name = "Player"
	walker.arrived.connect(_on_arrived)
	walker.stepped.connect(func(_c): _refresh_hud())
	add_child(walker)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.zoom = Vector2.ONE * _zoom
	add_child(camera)

	_screen_fx = CanvasLayer.new()
	_screen_fx.layer = 5
	add_child(_screen_fx)
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(self, _screen_fx)
	weather.weather_changed.connect(func(_w): _refresh_hud())
	settings.bind(weather, "weather", weather.set_visuals_enabled)
	fx = Fx.new()
	fx.name = "Fx"
	add_child(fx)
	fx.setup(self, settings)
	settings.bind(self, "post_fx", _on_look_flag)
	settings.bind(self, "animations", _on_look_flag)
	visuals = SettingsPanel.new()
	visuals.name = "VisualSettings"
	add_child(visuals)
	visuals.setup(settings)

	_build_hud()
	progress = Progress.new()
	if progress.hero_class == "":
		var session := get_node_or_null("/root/NetSession")
		if session != null:
			progress.set_hero_class(str(session.get("selected_class_id")))
	character_window = CharacterWindow.new()
	character_window.name = "CharacterWindow"
	character_window.setup(progress)
	add_child(character_window)
	inventory_window = InventoryWindow.new()
	inventory_window.name = "InventoryWindow"
	inventory_window.setup(progress)
	add_child(inventory_window)
	reward_popup = RewardPopup.new()
	reward_popup.name = "RewardPopup"
	add_child(reward_popup)
	dialogue = NpcDialogue.new()
	dialogue.name = "NpcDialogue"
	add_child(dialogue)
	dialogue.accept_requested.connect(_on_mission_accept)
	dialogue.turn_in_requested.connect(_on_mission_turn_in)
	var mission_loaded: Dictionary = Missions.load_default()
	if bool(mission_loaded.get("ok", false)):
		missions = mission_loaded["missions"]
	else:
		push_error("Missions failed to load: %s" % [mission_loaded.get("errors", [])])
	tracker = MissionTracker.new()
	tracker.name = "MissionTracker"
	tracker.setup(missions, progress)
	add_child(tracker)
	mission_log = MissionLog.new()
	mission_log.name = "MissionLog"
	mission_log.setup(missions, progress)
	add_child(mission_log)
	var npc_loaded: Dictionary = NpcBook.load_default()
	if bool(npc_loaded.get("ok", false)):
		npc_book = npc_loaded["npcs"]
	else:
		push_error("NPC book failed to load: %s" % [npc_loaded.get("errors", [])])

	var loaded: Dictionary = Atlas.load_default()
	if not bool(loaded.get("ok", false)):
		load_errors = loaded.get("errors", [])
		push_error("World atlas failed to load: %s" % [load_errors])
		return
	atlas = loaded["atlas"]
	map = atlas.map_for_chunk(atlas.entry_of(str(atlas.start_region)))
	if map == null:
		load_errors = ["start region is not loaded"]
		push_error("World atlas failed to load: %s" % [load_errors])
		return
	enter_zone(map.start_zone, map.start_cell, false)
	if _movie != "":
		get_tree().process_frame.connect(_start_movie, CONNECT_ONE_SHOT)


func enter_zone(zone_id: String, cell: Vector2i, fade: bool = true) -> void:
	var next: WorldMap = map
	if atlas != null:
		var found: Variant = atlas.map_for_chunk(zone_id)
		if found != null:
			next = found as WorldMap
		elif map == null or map.zone(zone_id) == null:
			_show_banner(_unbuilt_label(zone_id))
			walk_rejected.emit("region_not_built")
			return
	if next == null or next.zone(zone_id) == null:
		_show_banner(_unbuilt_label(zone_id))
		walk_rejected.emit("region_not_built")
		return
	map = next
	if fade and not instant_transitions:
		_transitioning = true
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
		await tw.finished
	_load_zone(zone_id, cell)
	if fade and not instant_transitions:
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
		await tw2.finished
	_transitioning = false


func _load_zone(zone_id: String, cell: Vector2i) -> void:
	zone = map.zone(zone_id)
	_max_h = Pick.max_height(zone)
	if ground != null:
		ground.free()
	ground = Ground.new()
	ground.name = "Ground"
	add_child(ground)
	move_child(ground, 1)
	ground.setup(zone)
	_mark_gates()
	for child in props_root.get_children():
		child.free()
	for record in zone.props:
		var p := Prop.new()
		props_root.add_child(p)
		p.setup(zone, record)
	for child in decor_root.get_children():
		child.free()
	for record in zone.decor:
		var d := Decor.new()
		decor_root.add_child(d)
		d.setup(zone, record)
	_scatter_v7_light()
	if fx != null:
		fx.restock(zone)
	walker.place(zone, cell)
	hover_cell = Vector2i(-1, -1)
	_hover.queue_redraw()
	var rect := Pick.zone_rect(zone).grow(160)
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.position = walker.position
	camera.reset_smoothing()
	_spawn_npcs()
	_apply_region_look()
	_show_banner(Pick.zone_name(zone))
	_refresh_hud()
	_apply_decor_density()
	if progress != null and progress.has_method("note_zone"):
		progress.note_zone(zone.zone_id)
	zone_entered.emit(zone.zone_id, cell)


## Click-to-walk to a cell in the current chunk. Returns the WorldWalk result.
func walk_to(target: Vector2i, pace: String = "auto") -> Dictionary:
	if zone == null or _transitioning:
		return {"ok": false, "reason": "busy"}
	_pending_talk = {}
	var from: Vector2i = walker.anchor_cell()
	if from == target:
		_arm_arrival(target)
		if (_pending_exit or not _pending_gate.is_empty()) and not walker.is_moving():
			_on_arrived(target)
		return {"ok": true, "path": [], "length": 0}
	var result := WorldWalk.find_path(map, zone.zone_id, from, zone.zone_id, target, null, _extra_blocked())
	if not bool(result.get("ok", false)):
		_pending_exit = false
		_pending_gate = {}
		walk_rejected.emit(str(result.get("reason", "no_path")))
		return result
	var steps: Array[Vector2i] = []
	var path: Array = result["path"]
	for i in range(1, path.size()):
		steps.append(Vector2i(int(path[i]["x"]), int(path[i]["y"])))
	if pace == "auto":
		var now := Time.get_ticks_msec()
		if _last_click_ms > 0 and now - _last_click_ms < 280:
			pace = "run"
		_last_click_ms = now
	_arm_arrival(target)
	walker.walk(steps, pace)
	return result


func _spawn_npcs() -> void:
	_npc_by_cell.clear()
	_pending_talk = {}
	if dialogue != null and dialogue.is_open():
		dialogue.close()
	if npcs_root == null:
		return
	for child in npcs_root.get_children():
		child.free()
	if npc_plates != null:
		for plate in npc_plates.get_children():
			plate.free()
	if npc_book == null or zone == null:
		return
	for record in npc_book.for_zone(zone.zone_id):
		var node := WorldNpc.new()
		npcs_root.add_child(node)
		node.setup(zone, record, npc_plates)
		var at: Dictionary = record["cell"]
		_npc_by_cell[Vector2i(int(at["x"]), int(at["y"]))] = record
	_refresh_marks()


func _npc_at(cell: Vector2i) -> Dictionary:
	var found: Variant = _npc_by_cell.get(cell, {})
	if typeof(found) != TYPE_DICTIONARY:
		return {}
	return found


func _extra_blocked() -> Dictionary:
	var blocked := {}
	if zone == null:
		return blocked
	for cell in _npc_by_cell.keys():
		blocked[WorldWalk.cell_key(zone.zone_id, cell)] = true
	return blocked


func _stand_free(cell: Vector2i) -> bool:
	if zone == null or not zone.passable_at(cell):
		return false
	if not zone.exit_link(cell).is_empty():
		return false
	if _npc_by_cell.has(cell):
		return false
	if atlas != null and not atlas.gate_at(zone.zone_id, cell).is_empty():
		return false
	return true


func _talk_stand(npc_cell: Vector2i) -> Vector2i:
	var here: Vector2i = walker.anchor_cell() if walker.is_moving() else walker.cell
	var best := Vector2i(-1, -1)
	var best_len := 1000000
	for dir in WorldWalk.ORTHO:
		var next: Vector2i = npc_cell + dir
		if not _stand_free(next):
			continue
		if next == here:
			return next
		var path := WorldWalk.find_path(map, zone.zone_id, here, zone.zone_id, next, null, _extra_blocked())
		if not bool(path.get("ok", false)):
			continue
		var length := int(path.get("length", best_len))
		if length < best_len:
			best_len = length
			best = next
	return best


func _approach_npc(record: Dictionary) -> void:
	if record.is_empty() or zone == null:
		return
	var at: Dictionary = record["cell"]
	var npc_cell := Vector2i(int(at["x"]), int(at["y"]))
	var stand := _talk_stand(npc_cell)
	if stand.x < 0:
		walk_rejected.emit("no_path")
		return
	var result := walk_to(stand)
	if not bool(result.get("ok", false)):
		return
	_pending_talk = {"id": str(record["id"]), "stand": stand, "npc": npc_cell}
	if walker.cell == stand and not walker.is_moving():
		_open_talk()


func _open_talk() -> void:
	if _pending_talk.is_empty() or npc_book == null:
		return
	var npc_id := str(_pending_talk["id"])
	var stand: Vector2i = _pending_talk["stand"]
	var npc_cell: Vector2i = _pending_talk["npc"]
	_pending_talk = {}
	var toward := npc_cell - stand
	walker.face(_ortho_name(toward))
	for node in npcs_root.get_children():
		if str(node.npc_id) == npc_id:
			node.face(_ortho_name(-toward))
			break
	var record: Dictionary = npc_book.by_id(npc_id)
	if record.is_empty() or dialogue == null:
		return
	var view := _mission_view(npc_id)
	if missions != null and progress != null:
		var changed: Array = missions.on_talk(npc_id, progress)
		if not changed.is_empty():
			progress.save()
			_refresh_marks()
			view = {
				"lines": str(view.get("lines", "")),
				"accept_id": "",
				"turn_in_id": "",
				"soon": false,
				"soon_name": "",
			}
		else:
			view = _mission_view(npc_id)
	dialogue.open_for(record, view)


func _mission_view(npc_id: String) -> Dictionary:
	if missions == null or progress == null:
		return {}
	return missions.panel_for(npc_id, progress)


func _refresh_marks() -> void:
	if npcs_root == null:
		return
	for node in npcs_root.get_children():
		var next := ""
		if missions != null and progress != null:
			next = missions.mark_for(str(node.npc_id), progress)
		node.set_mark(next)
	if tracker != null:
		tracker.refresh()


func _on_mission_accept(mission_id: String) -> void:
	if missions == null or progress == null:
		return
	var result: Dictionary = missions.accept(mission_id, progress)
	if not bool(result.get("ok", false)):
		return
	progress.save()
	_refresh_marks()
	_reopen_talk()


func _on_mission_turn_in(mission_id: String) -> void:
	if missions == null or progress == null:
		return
	var result: Dictionary = missions.turn_in(mission_id, progress)
	if not bool(result.get("ok", false)):
		return
	progress.save()
	_refresh_marks()
	if tracker != null:
		tracker.show_reward(result, _movie != "")
	_reopen_talk()


func _reopen_talk() -> void:
	if dialogue == null or npc_book == null:
		return
	var npc_id := str(dialogue.npc_id)
	if npc_id == "":
		return
	var record: Dictionary = npc_book.by_id(npc_id)
	if record.is_empty():
		return
	dialogue.open_for(record, _mission_view(npc_id))


func _ortho_name(step: Vector2i) -> String:
	if step.x > 0:
		return "e"
	if step.x < 0:
		return "w"
	if step.y > 0:
		return "s"
	if step.y < 0:
		return "n"
	return "s"


func _arm_arrival(target: Vector2i) -> void:
	_pending_gate = {}
	if atlas != null:
		var found: Dictionary = atlas.gate_at(zone.zone_id, target)
		if not found.is_empty():
			_pending_gate = found
	_pending_exit = _pending_gate.is_empty() and not zone.exit_link(target).is_empty()


func _mark_gates() -> void:
	if atlas == null or zone == null or ground == null:
		return
	for gate in atlas.gates_from_zone(zone.zone_id):
		var frm: Dictionary = gate["from"]
		var cell := Vector2i(int(frm["x"]), int(frm["y"]))
		ground.call("add_gate_arrow", cell, _edge_dir(cell))


func _edge_dir(cell: Vector2i) -> Vector2i:
	if zone == null:
		return Vector2i.ZERO
	if cell.y == 0:
		return Vector2i(0, -1)
	if cell.y == zone.height - 1:
		return Vector2i(0, 1)
	if cell.x == 0:
		return Vector2i(-1, 0)
	if cell.x == zone.width - 1:
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _on_arrived(cell: Vector2i) -> void:
	_refresh_hud()
	if missions != null and progress != null and zone != null:
		var advanced: Array = missions.on_reach(zone.zone_id, cell, progress)
		if not advanced.is_empty():
			progress.save()
			_refresh_marks()
	if not _pending_gate.is_empty():
		var gate: Dictionary = _pending_gate
		_pending_gate = {}
		_pending_exit = false
		var dest: Dictionary = gate["to"]
		enter_zone(str(dest["zone_id"]), Vector2i(int(dest["x"]), int(dest["y"])), true)
		return
	if not _pending_talk.is_empty() and cell == (_pending_talk["stand"] as Vector2i):
		_open_talk()
		return
	if not _pending_exit:
		return
	_pending_exit = false
	var link := zone.exit_link(cell)
	if link.is_empty():
		return
	var to_cell := Vector2i(int(link["x"]), int(link["y"]))
	var target := str(link["target_zone"])
	var check := WorldWalk.validate_path(map, [
		{"zone_id": zone.zone_id, "x": cell.x, "y": cell.y},
		{"zone_id": target, "x": to_cell.x, "y": to_cell.y},
	])
	if not bool(check.get("ok", false)):
		walk_rejected.emit(str(check.get("reason", "bad_exit")))
		return
	enter_zone(target, to_cell, true)


func cell_at_screen(screen_pos: Vector2) -> Vector2i:
	if zone == null:
		return Vector2i(-1, -1)
	var local := get_canvas_transform().affine_inverse() * screen_pos
	return Pick.pick(zone, to_local(local), _max_h)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(cell_at_screen(event.position))
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if visuals != null and visuals.visible:
					return
				var c := cell_at_screen(event.position)
				if c.x >= 0:
					var record := _npc_at(c)
					if not record.is_empty():
						_approach_npc(record)
					else:
						walk_to(c)
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_zoom * 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom / 1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				weather.cycle_weather()
			KEY_2:
				weather.time_scale = 1.0 if weather.time_scale > 1.0 else 30.0
				_refresh_hud()
			KEY_ESCAPE:
				if dialogue != null and dialogue.is_open():
					dialogue.close()
				elif mission_log != null and mission_log.is_open():
					mission_log.close()
				elif visuals != null:
					visuals.toggle()
			KEY_J:
				if mission_log != null:
					mission_log.toggle()
			KEY_C:
				if character_window != null:
					character_window.toggle()
			KEY_I:
				if inventory_window != null:
					inventory_window.set_at_bank(_at_bank())
					inventory_window.toggle()


func _at_bank() -> bool:
	if npc_book == null or walker == null or zone == null:
		return false
	var hero: Vector2i = walker.anchor_cell()
	for record in npc_book.for_zone(zone.zone_id):
		if str(record.get("role", "")) != "banker":
			continue
		var at: Dictionary = record.get("cell", {})
		var cell := Vector2i(int(at.get("x", -99)), int(at.get("y", -99)))
		if absi(hero.x - cell.x) + absi(hero.y - cell.y) <= 1:
			return true
	return false


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	if camera == null:
		return
	if _zoom_tween != null and is_instance_valid(_zoom_tween):
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(camera, "zoom", Vector2.ONE * _zoom, 0.32)


func _set_hover(c: Vector2i) -> void:
	if c == hover_cell:
		return
	hover_cell = c
	if c.x >= 0:
		_hover.z_index = (c.x + c.y) * BoardVisualSort.TILE_Z_SCALE + 1
	_hover.queue_redraw()


func _draw_hover() -> void:
	if zone == null or hover_cell.x < 0 or not zone.in_bounds(hover_cell):
		return
	var color := Color(0.45, 0.95, 0.5, 0.9)
	if atlas != null and not atlas.gate_at(zone.zone_id, hover_cell).is_empty():
		color = Color(1.0, 0.84, 0.35, 0.95)
	elif not zone.exit_link(hover_cell).is_empty():
		color = Color(1.0, 0.84, 0.35, 0.95)
	elif not zone.passable_at(hover_cell):
		color = Color(0.95, 0.35, 0.3, 0.9)
	var d := Pick.diamond(hover_cell, float(zone.height_at(hover_cell)))
	var fill := color
	fill.a = 0.22
	_hover.draw_colored_polygon(d, fill)
	_hover.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), color, 2.0)


func _process(delta: float) -> void:
	if _bench_until > 0.0:
		_bench.append(delta)
		if Time.get_ticks_msec() / 1000.0 >= _bench_until:
			_report_bench()
			return
	if walker == null or zone == null:
		return
	camera.position = walker.position + walker.visual_offset()
	var feet: Vector2 = walker.position
	var wz: int = walker.z_index
	var covered := false
	for p in props_root.get_children():
		p.update_cover(feet, wz)
		if p.modulate.a < 0.9:
			covered = true
	if decor_root != null:
		for d in decor_root.get_children():
			d.update_cover(feet, wz)
			if d.modulate.a < 0.9:
				covered = true
	walker.set_covered(covered)
	if weather.time_scale > 1.0 or Engine.get_process_frames() % 30 == 0:
		_refresh_hud()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var sheet := Control.new()
	sheet.name = "HudSheet"
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sheet)
	var gear := Button.new()
	gear.text = "Visuals"
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -148
	gear.offset_top = 16
	gear.offset_right = -36
	gear.offset_bottom = 52
	gear.pressed.connect(func(): visuals.toggle())
	sheet.add_child(gear)
	_hud_label = Label.new()
	# Stretch with the viewport. A fixed left inset stays on screen at 4:3, 16:9,
	# and any other window size; the right inset clears the Visuals button.
	_hud_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_label.offset_left = 48
	_hud_label.offset_top = 20
	_hud_label.offset_right = -188
	_hud_label.offset_bottom = 156
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.clip_text = false
	_hud_label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_hud_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hud_label.add_theme_constant_override("outline_size", 4)
	sheet.add_child(_hud_label)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.offset_left = -320
	_banner.offset_top = 120
	_banner.offset_right = 320
	_banner.offset_bottom = 176
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_banner.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	sheet.add_child(_banner)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(_fade)


func _unbuilt_label(zone_id: String) -> String:
	var levels = null
	if atlas != null:
		levels = atlas.levels
	if levels == null:
		return "Region: not open yet"
	var band: Dictionary = levels.zone_for_chunk(zone_id)
	if band.is_empty():
		return "Region: not open yet"
	return "%s (%d–%d): not open yet" % [str(band["name"]), int(band["level_min"]), int(band["level_max"])]


func _region_stand_in(region: String) -> Dictionary:
	var path := "res://data/world/%s/stand_in.json" % region
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _apply_region_look() -> void:
	var look := _region_stand_in(zone.region)
	var pool: Array = ["clear"]
	if look.has("weather") and typeof(look["weather"]) == TYPE_ARRAY:
		pool = look["weather"]
	elif zone.presentation.has("default_weather"):
		pool = zone.presentation["default_weather"]
	weather.set_zone_pool(pool)
	weather.settle()
	if fx == null:
		return
	var mat: Variant = fx.get("_grade_mat")
	if mat == null:
		return
	var grade: Dictionary = look.get("grade", {})
	var warm: Array = grade.get("warm_mul", [1.02, 1.0, 0.96])
	var haze: Array = grade.get("haze_col", [0.45, 0.52, 0.62])
	mat.set_shader_parameter("grade_mix", 1.0 if not grade.is_empty() else 0.0)
	mat.set_shader_parameter("warm_mul", Color(float(warm[0]), float(warm[1]), float(warm[2])))
	mat.set_shader_parameter("haze_col", Color(float(haze[0]), float(haze[1]), float(haze[2])))
	mat.set_shader_parameter("haze_max", float(grade.get("haze_max", 0.15)))
	mat.set_shader_parameter("saturation", float(grade.get("saturation", 1.06)))
	var tint: Array = grade.get("tint_col", [1.0, 1.0, 1.0])
	mat.set_shader_parameter("tint_col", Color(float(tint[0]), float(tint[1]), float(tint[2])))
	mat.set_shader_parameter("tint_amount", float(grade.get("tint_amount", 0.0)))


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _refresh_hud() -> void:
	if _hud_label == null or zone == null:
		return
	var c: Vector2i = walker.cell
	var speed := "  (time x30)" if weather.time_scale > 1.0 else ""
	_hud_label.text = "%s\nCell %d, %d   height %d\nWeather: %s   %s%s\nClick to walk · double-click to run · Esc visuals" % [
		Pick.zone_name(zone), c.x, c.y, zone.height_at(c),
		str(weather.weather).replace("_", " "), weather.clock_text(), speed,
	]


func _on_decor_flag(_on: bool) -> void:
	_apply_decor_density()


func _on_preset(_preset_name: String) -> void:
	_apply_decor_density()
	_redraw_ground_and_props()


func _on_look_flag(_on: bool) -> void:
	_redraw_ground_and_props()


func _redraw_ground_and_props() -> void:
	if ground != null and ground.has_method("redraw_all"):
		ground.redraw_all()
	if props_root == null:
		return
	for p in props_root.get_children():
		p.queue_redraw()


## Full shows every sprite. Reduced keeps the roadside and building ring and
## hides open-field fill. Minimal turns the decor flag off and hides the root.
func _apply_decor_density() -> void:
	if decor_root == null or settings == null:
		return
	var show_root := settings.enabled("decor")
	decor_root.visible = show_root
	var rich := settings.preset != "Reduced"
	for d in decor_root.get_children():
		d.visible = rich or bool(d.get("core"))


func _apply_world_window() -> void:
	# Hub, touch, and combat keep the project viewport at 960×720. Crosshaven
	# only widens its own window. Stretch aspect is already "expand", so the
	# extra width is more map, not black bars. The movie writer locks its
	# size from the project viewport at startup, so 1280×720 captures use a
	# temporary override.cfg and are not a project setting.
	if DisplayServer.get_name() == "headless":
		return
	if _movie != "":
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		return
	var current := DisplayServer.window_get_size()
	if current.x == 1280 and current.y == 720:
		return
	_window_before = current
	DisplayServer.window_set_size(Vector2i(1280, 720))


func _exit_tree() -> void:
	if _window_before != Vector2i.ZERO and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_window_before)
	if settings != null:
		if settings.preset_changed.is_connected(_on_preset):
			settings.preset_changed.disconnect(_on_preset)
		settings.detach()


func _read_launch_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--movie" and i + 1 < args.size():
			_movie = str(args[i + 1])
		elif args[i] == "--bench" and i + 1 < args.size():
			_movie = "bench:" + str(args[i + 1])


func _start_movie() -> void:
	if _movie.begins_with("bench:"):
		_run_bench(_movie.trim_prefix("bench:"))
		return
	await _play_movie(_movie)


func _run_bench(preset_name: String) -> void:
	settings.apply_preset(preset_name)
	weather.set_weather("light_rain" if preset_name == "Full" else "clear")
	weather.settle()
	_set_zoom(1.6)
	var target := _far_cell(18)
	walk_to(target, "run")
	_bench.clear()
	_bench_until = Time.get_ticks_msec() / 1000.0 + 4.0


func _report_bench() -> void:
	_bench_until = 0.0
	if _bench.is_empty():
		print("BENCH empty")
		get_tree().quit()
		return
	var sorted := _bench.duplicate()
	sorted.sort()
	var sum := 0.0
	for d in _bench:
		sum += d
	var avg := sum / float(_bench.size())
	var p95: float = sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))]
	print("BENCH preset=%s frames=%d avg_ms=%.2f p95_ms=%.2f min_fps=%.1f" % [
		settings.preset, _bench.size(), avg * 1000.0, p95 * 1000.0, 1.0 / maxf(p95, 0.0001),
	])
	get_tree().quit()


func _play_movie(mode: String) -> void:
	weather.auto_rotate = false
	if mode.begins_with("v7still_"):
		await _movie_v7_still(mode.trim_prefix("v7still_"))
		get_tree().quit()
		return
	match mode:
		"tour":
			await _movie_tour()
		"settings":
			await _movie_settings()
		"gait":
			await _movie_gait(false)
		"gait_v2":
			await _movie_gait_v2()
		"slow":
			await _movie_gait(true)
		"gameplay":
			await _movie_gameplay()
		"decor":
			await _movie_decor()
		"northgate", "stoneford", "eastmarch", "westwatch", "southbridge":
			await _movie_town("crosshaven_" + mode)
		"scale":
			await _movie_scale()
		"graphics":
			await _movie_graphics()
		"v7tour":
			await _movie_v7_tour()
		"ironjaw_tall":
			await _movie_ironjaw_tall()
		"wp4gate":
			await _movie_wp4_gate()
		"wp5astills":
			await _movie_wp5a_stills()
		"wp10a":
			await _movie_wp10a_stills()
		"wp6grades":
			await _movie_wp6_grades()
		"wp6fix":
			await _movie_wp6_fix()
		"wp6":
			await _movie_wp6()
		"wp6b":
			await _movie_wp6b()
		"wp3b":
			await _movie_wp3b()
		"wp14":
			await _movie_wp14()
		_:
			push_error("unknown movie %s" % mode)
	get_tree().quit()


## v7 light and shade are not zone data. Unknown decor ids fail the zone
## loader, so these are placed when a chunk loads.
const V7_SHADE_BUILDINGS: Array[String] = [
	"red_roof_cottage",
	"northgate_spire", "stoneford_spire", "eastmarch_spire", "westwatch_spire", "southbridge_spire",
	"crossroads_centerpiece",
	"barn_2x2", "farmhouse_2x2", "windmill_2x2_body", "bakery_2x2", "smithy_2x2",
	"tavern_3x2", "fountain_2x2", "watermill_2x2_body", "watchtower_2x2", "fishing_hut_2x2",
	"wall_tower",
]


func _scatter_v7_light() -> void:
	var shade_at: Array[Vector2i] = []
	var prop_cells: Array[Vector2i] = []
	var n := 0
	var kind := ""
	var cells: Array = []
	var origin: Dictionary = {}
	var ox := 0
	var oy := 0
	var fw := 1
	var fh := 1
	var anchor := Vector2i.ZERO
	for prop in zone.props:
		kind = str(prop.get("type", ""))
		cells = prop.get("footprint", [])
		if cells.is_empty():
			continue
		origin = prop.get("origin", {})
		ox = int(origin.get("x", cells[0]["x"]))
		oy = int(origin.get("y", cells[0]["y"]))
		prop_cells.append(Vector2i(ox, oy))
		if not _v7_wants_shade(kind, ox, oy):
			continue
		fw = 1
		fh = 1
		for cell in cells:
			fw = maxi(fw, int(cell["x"]) - ox + 1)
			fh = maxi(fh, int(cell["y"]) - oy + 1)
		anchor = Vector2i(mini(ox + fw + 1, zone.width - 1), mini(oy + fh, zone.height - 1))
		if (kind == "tree" or kind == "tree_apple" or kind.begins_with("tree_cluster")) and _near_cells(anchor, shade_at, 5):
			continue
		var which := "decal_v7_shade_pool_a" if n % 2 == 0 else "decal_v7_shade_pool_b"
		var shade := _add_v7_decal(which, anchor)
		shade.set("core", true)
		shade_at.append(anchor)
		n += 1
	for prop in zone.props:
		kind = str(prop.get("type", ""))
		if kind != "lamp_post" and kind != "brazier":
			continue
		cells = prop.get("footprint", [])
		if cells.is_empty():
			continue
		origin = prop.get("origin", {})
		ox = int(origin.get("x", cells[0]["x"]))
		oy = int(origin.get("y", cells[0]["y"]))
		anchor = Vector2i(mini(ox + 1, zone.width - 1), mini(oy + 1, zone.height - 1))
		var glow := _add_v7_decal("decal_v7_lamp_glow", anchor)
		glow.set("night_only", true)
		glow.set("core", true)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
	for y in range(2, zone.height - 2, 6):
		for x in range(2, zone.width - 2, 6):
			var spot := Vector2i(x, y)
			if zone.terrain_at(spot) != "golden_plains" or not zone.passable_at(spot):
				continue
			if _near_road(spot, 2) or _near_cells(spot, prop_cells, 5) or _near_cells(spot, shade_at, 4):
				continue
			anchor = Vector2i(mini(spot.x + 1, zone.width - 1), mini(spot.y + 1, zone.height - 1))
			var dapple := _add_v7_decal("decal_v7_sun_dapple_a", anchor)
			dapple.set("core", false)


func _v7_wants_shade(kind: String, ox: int, oy: int) -> bool:
	if V7_SHADE_BUILDINGS.has(kind) or kind == "tree_apple" or kind.begins_with("tree_cluster"):
		return true
	if kind != "tree":
		return false
	var art_id := str(Art.prop_art_id("tree", Vector2i(ox, oy), 0, zone.zone_id))
	return art_id != "tree_pine"


func _add_v7_decal(kind: String, cell: Vector2i) -> Node2D:
	var d := Decor.new()
	decor_root.add_child(d)
	d.setup(zone, {"type": kind, "x": cell.x, "y": cell.y})
	return d


func _open_square_cell(z: WorldZone) -> Vector2i:
	var blocked: Array[Vector2i] = []
	var sx := 0
	var sy := 0
	var n := 0
	for prop in z.props:
		var kind := str(prop.get("type", ""))
		var cells: Array = prop.get("footprint", [])
		if cells.is_empty():
			continue
		var mass := V7_SHADE_BUILDINGS.has(kind) or kind == "market_stall"
		for c in cells:
			var p := Vector2i(int(c["x"]), int(c["y"]))
			if bool(prop.get("blocks", true)):
				blocked.append(p)
			if mass:
				sx += p.x
				sy += p.y
				n += 1
	if n == 0:
		return z.spawn
	var center := Vector2i(sx / n, sy / n)
	var best: Vector2i = z.spawn
	var best_score := 1000000
	for y in range(maxi(0, center.y - 4), mini(z.height, center.y + 6)):
		for x in range(maxi(0, center.x - 6), mini(z.width, center.x + 7)):
			var spot := Vector2i(x, y)
			if not z.passable_at(spot) or not z.exit_link(spot).is_empty():
				continue
			var ground := z.terrain_at(spot)
			if ground != "dirt_road" and ground != "golden_plains":
				continue
			if _gap_to(spot, blocked) < 2:
				continue
			if _under_a_roof(z, spot):
				continue
			# Slightly south of the building centroid, so the square fills the frame
			# and the hero stands in front of the houses.
			var score := absi(spot.x - center.x) * 3 + absi(spot.y - center.y - 1) * 2
			if score < best_score:
				best_score = score
				best = spot
	return best


## True when this cell sits in the screen-footprint of a building sprite.
## Those sprites hang many cells north of their south tip.
func _under_a_roof(z: WorldZone, spot: Vector2i) -> bool:
	for prop in z.props:
		var kind := str(prop.get("type", ""))
		if not V7_SHADE_BUILDINGS.has(kind) and kind != "market_stall":
			continue
		var cells: Array = prop.get("footprint", [])
		if cells.is_empty():
			continue
		var min_x := 999
		var max_x := -1
		var min_y := 999
		var max_y := -1
		for c in cells:
			var px := int(c["x"])
			var py := int(c["y"])
			min_x = mini(min_x, px)
			max_x = maxi(max_x, px)
			min_y = mini(min_y, py)
			max_y = maxi(max_y, py)
		if spot.x < min_x - 1 or spot.x > max_x + 1:
			continue
		# In front of the south wall. The sprite does not cover this cell.
		if spot.y > max_y + 1:
			continue
		# Far north of a cottage. A spire still reaches, so keep a wider margin.
		var reach := 6 if kind.ends_with("spire") or kind == "crossroads_centerpiece" else 3
		if spot.y < min_y - reach:
			continue
		return true
	return false


func _gap_to(cell: Vector2i, blocked: Array[Vector2i]) -> int:
	var best := 99
	for other in blocked:
		var d := maxi(absi(other.x - cell.x), absi(other.y - cell.y))
		if d < best:
			best = d
	return best


func _near_cells(cell: Vector2i, others: Array[Vector2i], dist: int) -> bool:
	for other in others:
		if absi(other.x - cell.x) + absi(other.y - cell.y) < dist:
			return true
	return false


func _near_road(cell: Vector2i, dist: int) -> bool:
	for y in range(cell.y - dist, cell.y + dist + 1):
		for x in range(cell.x - dist, cell.x + dist + 1):
			var n := Vector2i(x, y)
			if zone.in_bounds(n) and zone.terrain_at(n) == "dirt_road":
				return true
	return false


## Full preset, clear noon. The hero stands in the open square, south of the
## building mass, so the houses sit in frame and he is not under a roof sprite.
## Stoneford gate into Rowanvale, on to the dungeon door, and back out the gate.
func _movie_wp4_gate() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.6)
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	walker.playback = 3.0
	await enter_zone("crosshaven_stoneford", Vector2i(3, 3), false)
	await _go(Vector2i(3, 0), "walk")
	await _cross_to("rowanvale_hub")
	await _cross_to("rowanvale_door")
	await _go(Vector2i(20, 12), "run")
	await _cross_to("rowanvale_hub")
	await _cross_to("rowanvale_entry")
	await _go(Vector2i(0, 16), "run")
	await get_tree().create_timer(0.8).timeout


## Rowanvale entry, hub, and door beside the Crosshaven Crossroads.
## Zoom is 1.0 so the border band and the scattered decor stay in frame.
func _movie_wp10a_stills() -> void:
	settings.apply_preset("Full")
	_zoom = 1.0
	if camera != null:
		camera.zoom = Vector2.ONE
	weather.auto_rotate = false
	weather.time_of_day = 12.0
	weather.settle()
	if _hud_label != null:
		_hud_label.visible = false
	var sheet := find_child("HudSheet", true, false)
	if sheet != null and sheet.get_child_count() > 0:
		sheet.get_child(0).visible = false
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp10a")
	DirAccess.make_dir_recursive_absolute(folder)
	await _save_still("rowanvale_entry", Vector2i(16, 12), folder.path_join("rowanvale_entry.png"))
	await _save_still("rowanvale_hub", Vector2i(16, 12), folder.path_join("rowanvale_hub.png"))
	await _save_still("rowanvale_door", Vector2i(16, 12), folder.path_join("rowanvale_door.png"))
	await _save_still("crosshaven_crossroads", Vector2i(22, 18), folder.path_join("crosshaven_crossroads.png"))
	await get_tree().process_frame


## One still of each region's entry, at zoom 1.6, with that region's grade.
func _movie_wp5a_stills() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.6)
	weather.auto_rotate = false
	weather.time_of_day = 12.0
	var regions: Array[String] = [
		"rowanvale", "windmere", "brinewake", "slagcrown", "eastmarch_fen_edge",
		"gloomfen_mire", "stormspire", "ashen_shardfields", "blightwood_hollow",
	]
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp5a/stills")
	DirAccess.make_dir_recursive_absolute(folder)
	for region in regions:
		await enter_zone(region + "_entry", Vector2i(16, 12), false)
		await get_tree().process_frame
		await get_tree().process_frame
		if _banner != null:
			_banner.modulate.a = 0.0
		walker.facing = "s"
		walker._show_idle()
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(folder.path_join(region + ".png"))
	await get_tree().process_frame


## One still of each region entry after the grade push, for the contact sheet.
func _movie_wp6_grades() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.6)
	weather.auto_rotate = false
	weather.time_of_day = 12.0
	var regions: Array[String] = [
		"rowanvale", "windmere", "brinewake", "slagcrown", "eastmarch_fen_edge",
		"gloomfen_mire", "stormspire", "ashen_shardfields", "blightwood_hollow",
	]
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp6/stills")
	DirAccess.make_dir_recursive_absolute(folder)
	for region in regions:
		await enter_zone(region + "_entry", Vector2i(16, 12), false)
		await get_tree().process_frame
		await get_tree().process_frame
		if _banner != null:
			_banner.modulate.a = 0.0
		walker.facing = "s"
		walker._show_idle()
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(folder.path_join(region + ".png"))
	# Wider frames of one hub and one non-town entry, so the path spread is in view.
	_set_zoom(1.0)
	await get_tree().create_timer(0.45).timeout
	var place_folder := ProjectSettings.globalize_path("res://docs/pc/media/wp6")
	for zone_id in ["rowanvale_hub", "gloomfen_mire_entry"]:
		await enter_zone(zone_id, Vector2i(16, 12), false)
		await get_tree().process_frame
		await get_tree().process_frame
		if _banner != null:
			_banner.modulate.a = 0.0
		walker.facing = "s"
		walker._show_idle()
		await get_tree().process_frame
		var placed := get_viewport().get_texture().get_image()
		placed.save_png(place_folder.path_join(zone_id + ".png"))
	await get_tree().process_frame


## Gloomfen plates above the fog, and a Crosshaven square after the spread.
func _movie_wp6_fix() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.45)
	weather.auto_rotate = false
	weather.time_of_day = 12.0
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp6fix")
	DirAccess.make_dir_recursive_absolute(folder)
	await _save_still("gloomfen_mire_entry", Vector2i(8, 8), folder.path_join("gloomfen_plates.png"))
	await _save_still("crosshaven_crossroads", Vector2i(20, 17), folder.path_join("crosshaven_square.png"))


func _save_still(zone_id: String, cell: Vector2i, path: String) -> void:
	await enter_zone(zone_id, cell, false)
	await get_tree().create_timer(0.5).timeout
	if _banner != null:
		_banner.modulate.a = 0.0
	walker.facing = "s"
	walker._show_idle()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)


## Talk to the Guide at the spawn, then to the Stoneford Elder.
func _movie_wp6() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.6)
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	walker.playback = 2.0
	await enter_zone("crosshaven_crossroads", Vector2i(22, 18), false)
	if _banner != null:
		_banner.modulate.a = 0.0
	_approach_npc(npc_book.by_id("crossroads_guide"))
	await _wait_until_stopped()
	await get_tree().create_timer(2.4).timeout
	if dialogue != null:
		dialogue.close()
	await get_tree().create_timer(0.6).timeout
	await enter_zone("crosshaven_stoneford", Vector2i(16, 12), false)
	if _banner != null:
		_banner.modulate.a = 0.0
	_approach_npc(npc_book.by_id("stoneford_elder"))
	await _wait_until_stopped()
	await get_tree().create_timer(2.4).timeout


## Take Welcome to Crosshaven, talk to the Trader and the Door Keeper, turn it in.
func _movie_wp6b() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.45)
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	walker.playback = 2.4
	if progress != null and missions != null:
		progress.level = 1
		progress.xp = 0
		progress.coins = 0
		progress.mission_blob = {}
		var reward := 15
		var welcome: Dictionary = missions.mission("heart_welcome")
		if not welcome.is_empty():
			reward = int(welcome["rewards"]["xp"])
		var need := int(progress.xp_to_next[0])
		if reward < need:
			progress.xp = need - reward
		progress.save()
	await enter_zone("crosshaven_crossroads", Vector2i(22, 18), false)
	if _banner != null:
		_banner.modulate.a = 0.0
	_refresh_marks()
	_approach_npc(npc_book.by_id("crossroads_warden"))
	await _wait_until_stopped()
	await get_tree().create_timer(1.1).timeout
	_save_wp6b("welcome_offer.png")
	if dialogue != null:
		dialogue.press_accept()
	await get_tree().create_timer(1.0).timeout
	if dialogue != null:
		dialogue.close()
	await get_tree().create_timer(0.35).timeout
	_approach_npc(npc_book.by_id("crossroads_trader"))
	await _wait_until_stopped()
	await get_tree().create_timer(0.9).timeout
	if dialogue != null:
		dialogue.close()
	await get_tree().create_timer(0.3).timeout
	_approach_npc(npc_book.by_id("granary_door_keeper"))
	await _wait_until_stopped()
	await get_tree().create_timer(0.9).timeout
	if dialogue != null:
		dialogue.close()
	await get_tree().create_timer(0.3).timeout
	_approach_npc(npc_book.by_id("crossroads_warden"))
	await _wait_until_stopped()
	await get_tree().create_timer(0.7).timeout
	if dialogue != null:
		dialogue.press_turn_in()
	await get_tree().create_timer(2.2).timeout
	_save_wp6b("turn_in.png")


func _save_wp6b(file_name: String) -> void:
	if OS.has_feature("movie"):
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null:
		return
	var image: Image = texture.get_image()
	if image == null:
		return
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp6b")
	DirAccess.make_dir_recursive_absolute(folder)
	image.save_png(folder.path_join(file_name))


func _wait_until_stopped() -> void:
	var guard := 0
	while walker.is_moving() and guard < 4000:
		await get_tree().process_frame
		guard += 1
	await get_tree().process_frame


func _cross_to(target_zone: String) -> void:
	var cell := _exit_toward(target_zone)
	if cell.x < 0:
		return
	await _go(cell, "run")


func _movie_v7_still(town: String) -> void:
	settings.apply_preset("Full")
	var zone_id := "crosshaven_" + town
	var z: WorldZone = map.zone(zone_id)
	var cell := _open_square_cell(z)
	enter_zone(zone_id, cell, false)
	await get_tree().process_frame
	_set_zoom(1.58)
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	walker.facing = "s"
	walker._show_idle()
	if _banner != null:
		_banner.modulate.a = 0.0
	await get_tree().create_timer(0.75).timeout


## A short walk through every town. Roads are a fade, so the clip stays under a minute.
func _movie_v7_tour() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.5)
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.auto_rotate = false
	weather.settle()
	var towns: Array[String] = [
		"crosshaven_crossroads",
		"crosshaven_northgate",
		"crosshaven_stoneford",
		"crosshaven_eastmarch",
		"crosshaven_westwatch",
		"crosshaven_southbridge",
	]
	_mark("tour-start")
	for id in towns:
		var z: WorldZone = map.zone(id)
		await enter_zone(id, _open_square_cell(z), true)
		_mark(id)
		await _town_stroll()
	_mark("tour-end")


## Painted Ironjaw on the v9 roads. East and west use the new strips; north and
## south are the placeholder cycles. Kestrel stands beside him at the end.
func _movie_ironjaw_tall() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.85)
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.auto_rotate = false
	weather.settle()
	_mark("crossroads")
	await _cardinal("e", 3, "walk")
	await _cardinal("w", 3, "walk")
	_mark("town")
	await enter_zone("crosshaven_northgate", Vector2i(20, 12), true)
	await _cardinal("e", 2, "walk")
	await _cardinal("w", 2, "walk")
	_mark("ns")
	await _cardinal("s", 1, "walk")
	await _cardinal("n", 1, "walk")
	_mark("scale")
	await enter_zone("crosshaven_crossroads", Vector2i(22, 18), true)
	walker.facing = "e"
	walker._show_idle()
	_place_scale_kestrel()
	await get_tree().create_timer(3.0).timeout
	_mark("end")


func _place_scale_kestrel() -> void:
	var strips = Strips.new()
	strips.load_class("kestrel")
	var hero: Vector2i = walker.cell
	var spot := hero + Vector2i(0, 1)
	if not zone.passable_at(spot):
		spot = hero + Vector2i(-1, 0)
	var spr := Sprite2D.new()
	spr.name = "ScaleKestrel"
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.offset = strips.pivot
	spr.texture = strips.idle("e")
	spr.scale = Vector2(strips.scale, strips.scale)
	spr.z_as_relative = false
	spr.position = BoardVisualSort.cell_to_local(spot, float(zone.height_at(spot)))
	spr.z_index = (spot.x + spot.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS
	add_child(spr)


func _town_stroll() -> void:
	var start: Vector2i = walker.anchor_cell()
	await _cardinal("e", 1, "walk")
	await _cardinal("s", 1, "walk")
	await _cardinal("w", 1, "walk")
	if walker.anchor_cell() == start:
		await _cardinal("n", 1, "walk")
		await _cardinal("s", 1, "walk")
	await get_tree().create_timer(0.55).timeout


## Mission turn-in. World fights and dungeons call this from WP9 and WP8.
func grant_turn_in(drop: Dictionary) -> void:
	if progress == null:
		return
	progress.grant(drop)
	if reward_popup != null and reward_popup.has_method("show_drop"):
		reward_popup.show_drop(drop, progress)


## Fight reward, then a Mystery Box opened from the inventory.
func _movie_wp14() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.35)
	weather.auto_rotate = false
	weather.time_of_day = 12.0
	if _banner != null:
		_banner.modulate.a = 0.0
	await get_tree().create_timer(0.45).timeout
	var loaded: Dictionary = Rewards.load_default()
	if not bool(loaded.get("ok", false)) or progress == null:
		return
	var catalog = loaded["rewards"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var drop: Dictionary = catalog.roll("world", {
		"level": progress.level,
		"class_id": progress.hero_class,
		"zone_id": zone.zone_id,
	}, rng)
	progress.grant(drop)
	reward_popup.show_drop(drop, progress)
	await get_tree().create_timer(1.8).timeout
	await _save_wp14("reward_popup.png")
	reward_popup.hide_drop()
	progress.grant({
		"coins": 0,
		"items": [{"item_id": "mystery_box", "rarity": "regular", "count": 1}],
	})
	inventory_window.show_category("special")
	inventory_window.open()
	await get_tree().create_timer(1.2).timeout
	await _save_wp14("box_in_bag.png")
	var box_rng := RandomNumberGenerator.new()
	box_rng.seed = 3
	inventory_window.open_first_box(box_rng)
	await get_tree().create_timer(2.0).timeout
	await _save_wp14("box_open.png")


func _save_wp14(file_name: String) -> void:
	if OS.has_feature("movie"):
		return
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp14")
	DirAccess.make_dir_recursive_absolute(folder)
	await get_tree().process_frame
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	image.save_png(folder.path_join(file_name))


## Before: the Crossroads with the character panel closed.
## After: the same camera with the panel open.
func _movie_wp3b() -> void:
	_set_zoom(1.6)
	weather.set_weather("clear")
	weather.settle()
	if character_window != null:
		character_window.close()
	await get_tree().create_timer(1.2).timeout
	if progress != null and character_window != null:
		var grant := 0
		var steps: Array = progress.xp_to_next
		var count: int = mini(11, steps.size())
		for i in count:
			grant += int(steps[i])
		progress.add_xp(grant)
		progress.spend("Mastery", 4)
		progress.spend("Vitality", 4)
		progress.spend("Swift", 2)
		progress.spend("Resist", 2)
		character_window.open()
	await get_tree().create_timer(2.4).timeout


func _movie_tour() -> void:
	_set_zoom(1.85)
	weather.set_weather("clear")
	weather.settle()
	await _wander(6, "walk")
	weather.set_weather("light_rain")
	await _run_link("crosshaven_road_north")
	await _run_link("crosshaven_northgate")
	await _wander(4, "walk")
	weather.set_weather("light_cloud")
	await _run_link("crosshaven_road_north")
	await _run_link("crosshaven_crossroads")
	await _run_link("crosshaven_road_east")
	await _run_link("crosshaven_eastmarch")
	await _wander(4, "walk")
	weather.set_weather("wind")
	await _run_link("crosshaven_road_east")
	await _run_link("crosshaven_crossroads")
	await _run_link("crosshaven_road_south")
	await _run_link("crosshaven_southbridge")
	await _wander(4, "run")


## Hero standing in front of a Northgate cottage, for scale stills.
func _movie_scale() -> void:
	enter_zone("crosshaven_northgate", Vector2i(10, 12), false)
	await get_tree().process_frame
	_set_zoom(2.05)
	weather.set_weather("clear")
	weather.settle()
	walker.facing = "s"
	walker._show_idle()
	await get_tree().create_timer(0.5).timeout


func _movie_town(zone_id: String) -> void:
	var z: WorldZone = map.zone(zone_id)
	enter_zone(zone_id, z.spawn, false)
	await get_tree().process_frame
	_set_zoom(1.9)
	weather.set_weather("light_cloud")
	weather.settle()
	await _wander(10, "walk")
	await _wander(8, "walk")
	await _wander(8, "run")


## Click-walk and run through all four facings, with stops, turns, a diagonal,
## then the same kind of step in slow motion. Aimed at about 20s.
func _movie_gait_v2() -> void:
	settings.apply_preset("Full")
	_set_zoom(2.2)
	weather.set_weather("clear")
	weather.settle()
	await _stand_on_pad(3)
	walker.playback = 1.0
	for dir in ["e", "s", "w", "n"]:
		await _cardinal(dir, 1, "walk")
		await get_tree().create_timer(0.55).timeout
	for dir in ["e", "s", "w", "n"]:
		await _cardinal(dir, 1, "run")
		await get_tree().create_timer(0.40).timeout
	var diag: Vector2i = walker.anchor_cell() + Vector2i(2, 2)
	if zone.passable_at(diag) and zone.exit_link(diag).is_empty():
		await _go(diag, "walk")
		await get_tree().create_timer(0.45).timeout
	walker.playback = 0.4
	await _cardinal("e", 1, "walk")
	walker.playback = 1.0
	await get_tree().create_timer(0.25).timeout


## Close-up of one walk cycle set, then one run set, each facing in turn.
## `slow` plays that same route at 0.4 speed.
func _movie_gait(slow: bool) -> void:
	settings.apply_preset("Full")
	_set_zoom(2.45)
	walker.playback = 0.4 if slow else 1.0
	weather.set_weather("clear")
	weather.settle()
	await _stand_on_pad(2)
	# One tile of walk still covers a full cycle; two tiles of run reads as a run.
	# South and north are slower, so this stays inside a 20s close-up.
	for dir in ["e", "s", "w", "n"]:
		await _cardinal(dir, 1, "walk")
	for dir in ["e", "s", "w", "n"]:
		await _cardinal(dir, 2, "run")


## Crossroads, the north road into Northgate, then Eastmarch and Southbridge.
## Later towns fade in. A full run of every connecting road at this stride exceeds 90s.
func _movie_gameplay() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.6)
	weather.set_weather("clear")
	weather.settle()
	_mark("start")
	await _stand_on_pad(2)
	for dir in ["e", "s", "w", "n"]:
		await _cardinal(dir, 1, "walk")
	for dir in ["e", "s", "w", "n"]:
		await _cardinal(dir, 2, "run")
	_mark("crossroads")
	await _run_link("crosshaven_road_north")
	await _run_link("crosshaven_northgate")
	_mark("northgate")
	await _show_faces(2, "walk")
	await _arrive_town("crosshaven_eastmarch")
	_mark("eastmarch")
	await _show_faces(2, "run")
	await _arrive_town("crosshaven_southbridge")
	_mark("southbridge")
	await _wander(3, "walk")
	await _wander(4, "run")
	_mark("end")


func _mark(tag: String) -> void:
	if _movie_t0 == 0:
		_movie_t0 = Time.get_ticks_msec()
	print("MOVIE %s %.1fs frame %d" % [tag, (Time.get_ticks_msec() - _movie_t0) / 1000.0, Engine.get_process_frames()])


## Clear and flat, then the same walk with the grade, then the same walk in rain.
func _movie_graphics() -> void:
	_set_zoom(1.75)
	weather.set_weather("clear")
	weather.settle()
	await _stand_on_pad(2)
	_polish(false)
	await get_tree().create_timer(0.35).timeout
	_mark("before")
	await _polish_lap()
	_polish(true)
	weather.set_weather("clear")
	weather.settle()
	await get_tree().create_timer(0.35).timeout
	_mark("after")
	await _polish_lap()
	weather.set_weather("light_rain")
	weather.settle()
	await get_tree().create_timer(0.45).timeout
	_mark("rain")
	await _polish_lap()
	_mark("end")


func _polish(on: bool) -> void:
	settings.apply_preset("Full")
	if on:
		return
	settings.set_flag("post_fx", false)
	settings.set_flag("sway_shadows", false)
	settings.set_flag("weather", false)


func _polish_lap() -> void:
	await _cardinal("e", 2, "walk")
	await _cardinal("w", 2, "walk")
	await _cardinal("s", 1, "walk")
	await _cardinal("n", 1, "walk")


func _arrive_town(zone_id: String) -> void:
	var z: WorldZone = map.zone(zone_id)
	await enter_zone(zone_id, z.spawn, true)


func _stand_on_pad(reach: int) -> void:
	var pad := _gait_pad(reach)
	if pad.x < 0 or pad == walker.cell:
		return
	enter_zone(zone.zone_id, pad, false)
	await get_tree().process_frame


func _show_faces(tiles: int, pace: String) -> void:
	var moved := false
	for dir in ["e", "s", "w", "n"]:
		var before: Vector2i = walker.cell
		await _cardinal(dir, tiles, pace)
		if walker.cell != before:
			moved = true
	if not moved:
		await _wander(tiles * 2, pace)


func _cardinal(dir: String, tiles: int, pace: String) -> void:
	var step := Vector2i.ZERO
	match dir:
		"e":
			step = Vector2i(1, 0)
		"w":
			step = Vector2i(-1, 0)
		"s":
			step = Vector2i(0, 1)
		"n":
			step = Vector2i(0, -1)
		_:
			return
	var goal: Vector2i = walker.anchor_cell()
	var cursor: Vector2i = goal
	for _i in tiles:
		var nxt: Vector2i = cursor + step
		if not zone.passable_at(nxt) or not zone.exit_link(nxt).is_empty():
			break
		cursor = nxt
		goal = nxt
	if goal == walker.anchor_cell():
		return
	await _go(goal, pace)


func _gait_pad(reach: int) -> Vector2i:
	var origin: Vector2i = walker.cell
	var best := Vector2i(-1, -1)
	var best_d := 999999
	for y in range(reach, zone.height - reach):
		for x in range(reach, zone.width - reach):
			var c := Vector2i(x, y)
			if not _clear_cross(c, reach):
				continue
			var d := absi(c.x - origin.x) + absi(c.y - origin.y)
			if d < best_d:
				best_d = d
				best = c
	return best


func _clear_cross(c: Vector2i, reach: int) -> bool:
	if not zone.passable_at(c) or not zone.exit_link(c).is_empty():
		return false
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in dirs:
		for i in range(1, reach + 1):
			var n: Vector2i = c + dir * i
			if not zone.passable_at(n) or not zone.exit_link(n).is_empty():
				return false
	return true


func _movie_decor() -> void:
	_set_zoom(1.9)
	weather.set_weather("clear")
	weather.settle()
	await _wander(8, "walk")
	await _run_link("crosshaven_road_north")
	await _wander(4, "run")


func _movie_settings() -> void:
	_set_zoom(1.7)
	settings.apply_preset("Full")
	weather.set_weather("light_rain")
	weather.settle()
	await _wander(4, "walk")
	visuals.show_panel()
	await get_tree().create_timer(1.2).timeout
	for flag in ["animations", "weather", "post_fx", "sway_shadows", "decor"]:
		settings.set_flag(flag, false)
		await get_tree().create_timer(1.9).timeout
	settings.apply_preset("Full")
	await get_tree().create_timer(2.0).timeout
	settings.apply_preset("Reduced")
	await get_tree().create_timer(2.0).timeout
	settings.apply_preset("Minimal")
	await get_tree().create_timer(2.0).timeout
	settings.apply_preset("Full")
	await get_tree().create_timer(1.4).timeout


func _run_link(target_zone: String) -> void:
	var gate := _exit_toward(target_zone)
	if gate.x < 0:
		return
	await _go(gate, "run")


func _wander(tiles: int, pace: String) -> void:
	var goal := _far_cell(tiles)
	if goal.x < 0:
		return
	await _go(goal, pace)


func _go(target: Vector2i, pace: String) -> void:
	walk_to(target, pace)
	var guard := 0
	while (walker.is_moving() or _transitioning) and guard < 4000:
		await get_tree().process_frame
		guard += 1


func _exit_toward(target_zone: String) -> Vector2i:
	for exit_rec in zone.exits:
		if str(exit_rec["target_zone"]) != target_zone:
			continue
		var link: Dictionary = exit_rec["links"][0]
		var frm: Dictionary = link["from"]
		return Vector2i(int(frm["x"]), int(frm["y"]))
	return Vector2i(-1, -1)


func _far_cell(min_tiles: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1
	var fallback := Vector2i(-1, -1)
	var fallback_d := -1
	var origin: Vector2i = walker.anchor_cell()
	for y in zone.height:
		for x in range(0, zone.width, 2):
			var c := Vector2i(x, y)
			if not zone.passable_at(c) or not zone.exit_link(c).is_empty():
				continue
			var d := absi(c.x - origin.x) + absi(c.y - origin.y)
			if d >= min_tiles and d > best_d and d < min_tiles + 10:
				best_d = d
				best = c
			if d > fallback_d:
				fallback_d = d
				fallback = c
	if best.x >= 0:
		return best
	return fallback
