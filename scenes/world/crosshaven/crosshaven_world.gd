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
const Snowfall := preload("res://scenes/world/crosshaven/crosshaven_snowfall.gd")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")
const HeroStamina := preload("res://scenes/world/crosshaven/hero_stamina.gd")
const Fx := preload("res://scenes/world/crosshaven/crosshaven_fx.gd")
const SettingsPanel := preload("res://ui/visual_settings_panel.gd")
const Progress := preload("res://backend/pc_progress.gd")
const CharacterWindow := preload("res://scenes/world/ui/character_window.gd")
const InventoryWindow := preload("res://scenes/world/ui/inventory_window.gd")
const RewardPopup := preload("res://scenes/world/ui/reward_popup.gd")
const Rewards := preload("res://backend/pc_rewards.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const Regions := preload("res://backend/world_regions.gd")
const WorldPlane := preload("res://backend/world_plane.gd")
const NpcBook := preload("res://backend/world_npcs.gd")
const Missions := preload("res://backend/pc_missions.gd")
const WorldNpc := preload("res://scenes/world/npc/world_npc.gd")
const NpcDialogue := preload("res://scenes/world/ui/npc_dialogue.gd")
const NpcRoam := preload("res://scenes/world/npc/npc_roam.gd")
const MissionTracker := preload("res://scenes/world/ui/mission_tracker.gd")
const MissionLog := preload("res://scenes/world/ui/mission_log.gd")
const DungeonBook := preload("res://backend/world_dungeons.gd")
const DungeonDoor := preload("res://scenes/world/dungeon/dungeon_door.gd")
const DungeonArt := preload("res://scenes/world/dungeon/dungeon_art.gd")
const DoorPanel := preload("res://scenes/world/ui/door_panel.gd")
const Launcher := preload("res://scenes/world/dungeon/dungeon_launcher.gd")

## Kit deep sea, so the margin past Eastmarch matches the painted tiles.
const SEA := Color("246e9e")
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.5
const FADE_SECONDS := 0.35
const SEA_MARGIN := 720
const LEAD_PX := 22.0
const PRESENCE_SECONDS := 0.55
## Danger tint starts with this level band. Below it the ground stays safe.
const DANGER_FROM := 30

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
## Dungeon doors (dungeons.json). The panel opens from the hatch or the keeper.
var dungeon_book = null
var door_panel: CanvasLayer
var doors_root: Node2D
var door_nodes: Dictionary = {}
var _pending_door := ""
var _door_outcome: Dictionary = {}
## False keeps every NPC at its post (spec 4.5a movement off).
var npc_roam := true
var hover_cell := Vector2i(-1, -1)
var _hover_zone: WorldZone
var neighbours: Node2D
var plane_offsets: Dictionary = {}
## Ground cells of off-screen neighbour chunks drawn per frame ahead of need.
## About 2–4 ms of script a frame on a desktop CPU.
const WARM_CELLS_PER_FRAME := 160
## Margin (px) around the view inside which ground rows draw at once.
const WARM_VIEW_MARGIN := 128.0
## `_chunk_at` answers for `_chunk_map` laid out as `_chunk_offsets`.
var _chunk_hits: Dictionary = {}
var _plane_map: Object
## Grounds kept across loads (`_ground_for`), keyed by chunk and placement.
var _grounds_root: Node2D
var _ground_pool: Dictionary = {}
var _chunk_map: Object
var _chunk_offsets: Dictionary = {}
var transition_count := 0
var seam_count := 0
var music_id := ""
var danger := false
var level_band := ""
var _route: Array = []
var _route_pace := "walk"
var _booting := true
var _lead := Vector2.ZERO
var _sea: ColorRect
var _backdrop: Node2D
## Screen-space snowfall over Northgate (view only, fades at the town edge).
var _snow: Control
## Shown snowfall amount, 0..1. The grade cools and brightens with it.
var snow_level := 0.0
var _presence_tween: Tween

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
## Run on demand. R toggles `run_mode`; Shift held, a Shift-click, or a
## double-click also run. Paths never auto-run by length.
var run_mode := false
var stamina = HeroStamina.new()
var stamina_bar: Panel
var _stamina_fill: ColorRect
var _shift_down := false
## The current path was asked to run (double-click, Shift-click, or a scripted "run").
var _click_run := false
## Hovered cell in this chunk that the hero cannot reach right now (an NPC
## plugs the only way in, say). Drawn red instead of green.
var _hover_unreachable := false
## Last refused click, drawn as a red X until `_bad_click_until` (msec).
var bad_click_cell := Vector2i(-1, -1)
var _bad_click_zone: WorldZone
var _bad_click_until := 0
const BAD_CLICK_MS := 700
## Last mouse position (viewport px) and the canvas transform its hover used.
var _mouse_pos := Vector2.ZERO
var _mouse_seen := false
var _hover_xf := Transform2D()
var _max_h_cache: Dictionary = {}
var _reach_key := ""
var _reach_cache := {}
var _movie := ""
var _launch_class := ""
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
	_sea = ColorRect.new()
	_sea.color = SEA
	_sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sea.visible = false
	bg.add_child(_sea)
	_backdrop = Node2D.new()
	_backdrop.name = "Backdrop"
	_backdrop.z_as_relative = false
	_backdrop.z_index = -4096
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)
	neighbours = Node2D.new()
	neighbours.name = "Neighbours"
	add_child(neighbours)

	settings = VisualSettings.new()
	props_root = Node2D.new()
	props_root.name = "Props"
	add_child(props_root)
	doors_root = Node2D.new()
	doors_root.name = "DungeonDoors"
	add_child(doors_root)
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
	if _launch_class != "":
		walker.class_id = _launch_class
	walker.arrived.connect(_on_arrived)
	walker.stepped.connect(func(_c): _refresh_hud())
	add_child(walker)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.zoom = Vector2.ONE * _zoom
	add_child(camera)
	var snow_layer := CanvasLayer.new()
	snow_layer.name = "SnowfallLayer"
	snow_layer.layer = 5
	add_child(snow_layer)
	_snow = Snowfall.new()
	_snow.name = "Snowfall"
	snow_layer.add_child(_snow)

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
	dialogue.closed.connect(_on_dialogue_closed)
	var mission_loaded: Dictionary = Missions.load_default()
	if bool(mission_loaded.get("ok", false)):
		missions = mission_loaded["missions"]
		var migrated: Array = missions.reconcile(progress)
		if not migrated.is_empty():
			progress.save()
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
	var dungeon_loaded: Dictionary = DungeonBook.load_default()
	if bool(dungeon_loaded.get("ok", false)):
		dungeon_book = dungeon_loaded["dungeons"]
	else:
		push_error("Dungeon doors failed to load: %s" % [dungeon_loaded.get("errors", [])])
	door_panel = DoorPanel.new()
	door_panel.name = "DoorPanel"
	add_child(door_panel)
	door_panel.enter_requested.connect(_on_door_enter)

	var loaded: Dictionary = Atlas.load_default()
	if not bool(loaded.get("ok", false)):
		load_errors = loaded.get("errors", [])
		push_error("World atlas failed to load: %s" % [load_errors])
		return
	atlas = loaded["atlas"]
	_block_dungeon_buildings()
	map = atlas.map_for_chunk(atlas.entry_of(str(atlas.start_region)))
	if map == null:
		load_errors = ["start region is not loaded"]
		push_error("World atlas failed to load: %s" % [load_errors])
		return
	if _movie == "outskirts":
		enter_zone("crosshaven_stoneford_fields", Vector2i(10, 28), false)
		_hide_debug_readout()
		if _banner != null:
			_banner.modulate.a = 0.0
	else:
		enter_zone(map.start_zone, map.start_cell, false)
	_booting = false
	transition_count = 0
	seam_count = 0
	if _movie == "" and DisplayServer.get_name() != "headless":
		restore_place()
	_take_dungeon_outcome()
	if _movie != "":
		get_tree().process_frame.connect(_start_movie, CONNECT_ONE_SHOT)


func enter_zone(zone_id: String, cell: Vector2i, fade: bool = true) -> void:
	if not Regions.enabled() and Regions.is_outer(zone_id):
		push_error("regions closed: refused %s" % zone_id)
		walk_rejected.emit("regions_closed")
		return
	transition_count += 1
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


func _load_zone(zone_id: String, cell: Vector2i, snap: bool = true) -> void:
	_max_h_cache.clear()
	zone = map.zone(zone_id)
	_refresh_plane()
	var origin := _origin_of(zone_id)
	walker.plane_origin = origin
	_max_h = Pick.max_height(zone)
	var pix := BoardVisualSort.cell_to_local(origin)
	if ground != null and is_instance_valid(ground):
		ground.set_process(false)
	ground = _ground_for(zone, origin)
	ground.set_process(true)
	_show_ground(ground, true)
	_mark_gates()
	for child in props_root.get_children():
		child.free()
	props_root.position = pix
	for record in zone.props:
		var p := Prop.new()
		props_root.add_child(p)
		p.snow_cover = ground.cover_at(_record_cell(record))
		p.setup(zone, record)
		p.snow_amount = maxf(Ground.snow_at(zone.zone_id, p.south_cell), ground.cover_at(p.south_cell))
	_raise_sort(props_root, origin)
	for child in decor_root.get_children():
		child.free()
	decor_root.position = pix
	var door_cells := _door_cells_in(zone.zone_id)
	for record in zone.decor:
		if door_cells.has(Vector2i(int(record["x"]), int(record["y"]))):
			continue
		var d := Decor.new()
		decor_root.add_child(d)
		d.snow_cover = ground.cover_at(Vector2i(int(record["x"]), int(record["y"])))
		d.setup(zone, record)
	_plant_snow_pines(decor_root, zone)
	_scatter_v7_light()
	_raise_sort(decor_root, origin)
	if fx != null:
		fx.restock(zone)
		fx._contacts.position = pix
		fx._critters.position = pix
		_raise_sort(fx._contacts, origin)
		_raise_sort(fx._critters, origin)
	hover_cell = Vector2i(-1, -1)
	_hover_zone = null
	_hover.queue_redraw()
	_spawn_npcs()
	npcs_root.position = pix
	_raise_sort(npcs_root, origin)
	_mount_neighbours(zone_id)
	_sync_doors()
	if snap:
		walker.place(zone, cell)
		_apply_region_look()
	else:
		seam_count += 1
		walker.relocate(zone, cell)
		_blend_region_look()
	_apply_camera_limits(snap)
	# A jump in snaps the snowfall; walking over a seam lets it fade.
	if snap:
		_sync_snowfall(true)
	# The frame that loaded may already be past the world's _process.
	_warm_grounds(true)
	_show_banner(Pick.zone_name(zone))
	_refresh_presence()
	_refresh_hud()
	_apply_decor_density()
	if not _booting and progress != null and progress.has_method("note_place"):
		progress.note_place(zone.zone_id, cell)
	zone_entered.emit(zone.zone_id, cell)


## Click-to-walk to a cell in the current chunk. Returns the WorldWalk result.
func walk_to(target: Vector2i, pace: String = "auto") -> Dictionary:
	if zone == null or _transitioning:
		return {"ok": false, "reason": "busy"}
	_route.clear()
	_pending_talk = {}
	_pending_door = ""
	_release_held()
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
	pace = _pick_pace(pace)
	_arm_arrival(target)
	walker.walk(steps, pace)
	return result


## Resolve a requested pace. "auto" walks unless the player asked to run
## (run mode, Shift, or a double-click). Stamina has the last word.
func _pick_pace(pace: String) -> String:
	if pace == "auto":
		var now := Time.get_ticks_msec()
		_click_run = _shift_down or (_last_click_ms > 0 and now - _last_click_ms < 280)
		_last_click_ms = now
	else:
		_click_run = pace == "run"
	return "run" if want_run() else "walk"


## True when the player wants to run and stamina allows it.
func want_run() -> bool:
	return (run_mode or _shift_down or _click_run) and stamina.can_run()


func set_run_mode(on: bool) -> void:
	run_mode = on
	_refresh_hud()


## One frame of run/stamina bookkeeping. `_process` calls it; tests step it.
func tick_run(delta: float) -> void:
	if walker == null:
		return
	if walker.is_moving():
		var pace := "run" if want_run() else "walk"
		walker.pace = pace
		_route_pace = pace
	elif _route.is_empty():
		_click_run = false
	var running: bool = walker.is_moving() and walker.shown_pace() == "run"
	stamina.tick(delta, running)
	_sync_stamina_bar(running)


func _sync_stamina_bar(running: bool) -> void:
	if stamina_bar == null:
		return
	var hud_on := _hud_label == null or _hud_label.visible
	stamina_bar.visible = hud_on and (running or not stamina.is_full())
	if _stamina_fill == null:
		return
	var inner := stamina_bar.size - Vector2(6, 6)
	_stamina_fill.size = Vector2(maxf(0.0, inner.x * stamina.value), inner.y)
	_stamina_fill.color = Color(0.82, 0.36, 0.26) if stamina.winded else Color(0.93, 0.78, 0.36)


## Walk to a cell that may sit on another streamed chunk. Chunk edges are steps.
func walk_to_zone(zone_id: String, target: Vector2i, pace: String = "auto") -> Dictionary:
	if zone == null or _transitioning:
		return {"ok": false, "reason": "busy"}
	if zone_id == zone.zone_id:
		return walk_to(target, pace)
	_pending_talk = {}
	_release_held()
	_pending_exit = false
	_pending_gate = {}
	var from: Vector2i = walker.anchor_cell()
	var result := WorldWalk.find_path(map, zone.zone_id, from, zone_id, target, null, _extra_blocked())
	if not bool(result.get("ok", false)):
		_route.clear()
		walk_rejected.emit(str(result.get("reason", "no_path")))
		return result
	pace = _pick_pace(pace)
	_route = (result["path"] as Array).duplicate()
	_route_pace = pace
	_kick_route(pace)
	return result


func _spawn_npcs() -> void:
	_pending_talk = {}
	if dialogue != null and dialogue.is_open():
		dialogue.close()
	if npcs_root == null:
		return
	for child in npcs_root.get_children():
		_free_npc(child)
	if npc_book == null or zone == null:
		return
	for record in npc_book.for_zone(zone.zone_id):
		var node := WorldNpc.new()
		npcs_root.add_child(node)
		node.setup(zone, record, npc_plates)
		node.roam_enabled = npc_roam
		node.attach_host(self, _roam_forbidden(zone, record, false), _roam_forbidden(zone, record, true))
	_refresh_marks()


## The NPC record whose body is on `cell` in the current chunk. A walking NPC
## covers both cells of its step.
func _npc_at(cell: Vector2i) -> Dictionary:
	var node := _npc_node_at(cell)
	if node == null or npc_book == null:
		return {}
	return npc_book.by_id(str(node.npc_id))


func _npc_node_at(cell: Vector2i) -> Node2D:
	if npcs_root == null:
		return null
	for node in npcs_root.get_children():
		if node.is_queued_for_deletion():
			continue
		if (node.occupied_cells() as Array).has(cell):
			return node
	return null


func _npc_node(npc_id: String) -> Node2D:
	if npcs_root == null:
		return null
	for node in npcs_root.get_children():
		if str(node.npc_id) == npc_id and not node.is_queued_for_deletion():
			return node
	return null


## Cells a moving NPC of this chunk keeps off (spec 4.5a, 4.5 spacing).
## Walk set (`dwell` false): exits, gates, doors and other points of
## interest, the spawn, and the cells touching a standing NPC's post (so its
## talk cells stay free). Pause set (`dwell` true) adds one ring around exits
## and those marks (2 cells clear, as 4.5), keeps 3 cells from every standing
## post and off the cells touching another walker's home.
func _roam_forbidden(z: WorldZone, record: Dictionary, dwell: bool) -> Dictionary:
	var out := {}
	if z == null:
		return out
	var ring := 1 if dwell else 0
	# Snow-town pines stand on cliff cells nobody walks, but keep walkers off
	# them outright in case a pine cell is ever passable.
	for pine in _snow_pines_for(z):
		out[pine] = true
	var anchors: Array[Vector2i] = [z.spawn]
	for poi in z.points_of_interest:
		anchors.append(Vector2i(int(poi["x"]), int(poi["y"])))
	if dungeon_book != null:
		for row in dungeon_book.doors_in(z.zone_id):
			anchors.append(DungeonBook.door_cell(row))
	if atlas != null:
		for gate in atlas.gates:
			for side in [gate["from"], gate["to"]]:
				if str(side["zone_id"]) == z.zone_id:
					anchors.append(Vector2i(int(side["x"]), int(side["y"])))
	for y in z.height:
		for x in z.width:
			var c := Vector2i(x, y)
			if not z.exit_link(c).is_empty():
				anchors.append(c)
	for anchor in anchors:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if absi(dx) + absi(dy) <= ring:
					out[anchor + Vector2i(dx, dy)] = true
	var me := str(record.get("id", ""))
	if npc_book != null:
		for other in npc_book.for_zone(z.zone_id):
			if str(other.get("id", "")) == me:
				continue
			# A walker's home is often empty, and walkers keep apart as they
			# move (npc_cell_free), so only a post that never moves gets the
			# walk ring.
			var still := NpcRoam.behaviour_for(str(other.get("role", ""))) == NpcRoam.POST
			var post_ring := (2 if dwell else 1) if still else (1 if dwell else -1)
			if post_ring < 0:
				continue
			var at: Dictionary = other.get("cell", {})
			var post := Vector2i(int(at.get("x", -99)), int(at.get("y", -99)))
			for dy in range(-post_ring, post_ring + 1):
				for dx in range(-post_ring, post_ring + 1):
					out[post + Vector2i(dx, dy)] = true
	return out


## Asked by a moving NPC before each step. No step onto the hero, the hero's
## route or talk stand, or next to another NPC's body.
func npc_cell_free(npc: Node2D, cell: Vector2i) -> bool:
	if zone == null or walker == null:
		return false
	if cell == walker.cell or cell == walker.anchor_cell():
		return false
	if walker.is_moving():
		for step in walker._queue:
			if step == cell:
				return false
	for step in _route:
		var rec: Dictionary = step
		if str(rec.get("zone_id", "")) == zone.zone_id and int(rec.get("x", -1)) == cell.x and int(rec.get("y", -1)) == cell.y:
			return false
	if not _pending_talk.is_empty() and _pending_talk.get("stand", Vector2i(-1, -1)) == cell:
		return false
	for node in npcs_root.get_children():
		if node == npc or node.is_queued_for_deletion():
			continue
		for at in node.occupied_cells():
			if NpcRoam.cells_apart(at, cell) < 2:
				return false
	return true


## The hero's cell for an NPC of the current chunk, else (-1, -1).
func npc_hero_cell(npc: Node2D) -> Vector2i:
	if walker == null or npcs_root == null or npc.get_parent() != npcs_root:
		return Vector2i(-1, -1)
	return walker.anchor_cell()


func _release_held() -> void:
	if npcs_root == null:
		return
	var talking := ""
	if dialogue != null and dialogue.is_open():
		talking = str(dialogue.npc_id)
	for node in npcs_root.get_children():
		if node.is_held() and str(node.npc_id) != talking:
			node.release()


func _on_dialogue_closed(_npc_id: String) -> void:
	_release_held()


func _extra_blocked() -> Dictionary:
	var blocked := {}
	if zone == null:
		return blocked
	if npcs_root != null:
		for node in npcs_root.get_children():
			if node.is_queued_for_deletion():
				continue
			for at in node.occupied_cells():
				blocked[WorldWalk.cell_key(zone.zone_id, at)] = true
	if neighbours == null or npc_book == null:
		return blocked
	for host in neighbours.get_children():
		var zid := str(host.name)
		var npcs := host.get_node_or_null("Npcs")
		if npcs == null:
			continue
		for node in npcs.get_children():
			blocked[WorldWalk.cell_key(zid, node.cell)] = true
	return blocked


func _stand_free(cell: Vector2i) -> bool:
	if zone == null or not zone.passable_at(cell):
		return false
	if not zone.exit_link(cell).is_empty():
		return false
	if _npc_node_at(cell) != null:
		return false
	if _open_gate(atlas.gate_at(zone.zone_id, cell) if atlas != null else {}):
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
	var body := _npc_node(str(record["id"]))
	if body != null:
		npc_cell = body.stop_cell()
	var stand := _talk_stand(npc_cell)
	if stand.x < 0:
		walk_rejected.emit("no_path")
		return
	var result := walk_to(stand)
	if not bool(result.get("ok", false)):
		return
	# Clicked: the NPC stops where it is and waits for the hero.
	if body != null:
		body.hold()
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
	var body := _npc_node(npc_id)
	if body != null:
		npc_cell = body.stop_cell()
	var toward := npc_cell - stand
	walker.face(_ortho_name(toward))
	if body != null:
		# Stop, face the hero and play the talk gesture once.
		body.talk_to(_ortho_name(-toward))
	var record: Dictionary = npc_book.by_id(npc_id)
	if record.is_empty() or dialogue == null:
		return
	if _keeper_opens_door(npc_id, record):
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
	var items: Array = []
	var raw_items: Variant = result.get("items", [])
	if typeof(raw_items) == TYPE_ARRAY:
		items = (raw_items as Array).duplicate()
	grant_turn_in({
		"xp": int(result.get("xp", 0)),
		"coins": int(result.get("coins", 0)),
		"items": items,
	})
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
		if _open_gate(found):
			_pending_gate = found
	_pending_exit = _pending_gate.is_empty() and not zone.exit_link(target).is_empty()


func _open_gate(gate: Dictionary) -> bool:
	if gate.is_empty():
		return false
	if Regions.enabled():
		return true
	var dest: Dictionary = gate.get("to", {})
	return not Regions.is_outer(str(dest.get("zone_id", "")))


func _mark_gates() -> void:
	if atlas == null or zone == null or ground == null:
		return
	for gate in atlas.gates_from_zone(zone.zone_id):
		if not _open_gate(gate):
			continue
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
	if _follow_route(cell):
		return
	_finish_arrival(cell)


func _finish_arrival(cell: Vector2i) -> void:
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
	if _pending_door != "":
		var door_id := _pending_door
		_pending_door = ""
		var row: Dictionary = dungeon_book.by_id(door_id) if dungeon_book != null else {}
		if not row.is_empty() and cell == DungeonBook.door_cell(row):
			open_door_panel(door_id)
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
	if _seamless() and map.zone(target) != null and not Regions.is_outer(target):
		_load_zone(target, to_cell, false)
		return
	enter_zone(target, to_cell, true)


func _kick_route(pace: String) -> void:
	_route_pace = pace
	while not _route.is_empty():
		var step: Dictionary = _route[0]
		var step_id := str(step.get("zone_id", ""))
		var step_cell := Vector2i(int(step.get("x", 0)), int(step.get("y", 0)))
		if zone != null and step_id == zone.zone_id and step_cell == walker.cell:
			_route.pop_front()
		else:
			break
	if _route.is_empty() or zone == null:
		return
	var nxt: Dictionary = _route[0]
	if str(nxt.get("zone_id", "")) != zone.zone_id:
		_follow_route(walker.cell)
		return
	var steps: Array[Vector2i] = []
	var last := 0
	for i in _route.size():
		var step: Dictionary = _route[i]
		if str(step.get("zone_id", "")) != zone.zone_id:
			break
		steps.append(Vector2i(int(step.get("x", 0)), int(step.get("y", 0))))
		last = i
	var kept: Array = []
	for i in range(last, _route.size()):
		kept.append(_route[i])
	_route = kept
	if steps.is_empty():
		return
	if _route.size() == 1:
		_arm_arrival(steps[steps.size() - 1])
	else:
		_pending_exit = false
		_pending_gate = {}
	walker.walk(steps, pace)


func _follow_route(cell: Vector2i) -> bool:
	if _route.is_empty() or zone == null:
		return false
	while not _route.is_empty():
		var step: Dictionary = _route[0]
		var step_id := str(step.get("zone_id", ""))
		var step_cell := Vector2i(int(step.get("x", 0)), int(step.get("y", 0)))
		if step_id == zone.zone_id and step_cell == cell:
			_route.pop_front()
		else:
			break
	if _route.is_empty():
		return false
	var nxt: Dictionary = _route[0]
	var nxt_id := str(nxt.get("zone_id", ""))
	var nxt_cell := Vector2i(int(nxt.get("x", 0)), int(nxt.get("y", 0)))
	if nxt_id != zone.zone_id:
		if map.zone(nxt_id) == null or (not Regions.enabled() and Regions.is_outer(nxt_id)):
			_route.clear()
			walk_rejected.emit("regions_closed" if Regions.is_outer(nxt_id) else "region_closed")
			return true
		_load_zone(nxt_id, nxt_cell, false)
		if _follow_route(walker.cell):
			return true
		_finish_arrival(walker.cell)
		return true
	_kick_route(_route_pace)
	return true


func cell_at_screen(screen_pos: Vector2) -> Vector2i:
	var hit := _pick_world(_world_point(screen_pos))
	if hit.is_empty():
		return Vector2i(-1, -1)
	return hit["cell"]


func _world_point(screen_pos: Vector2) -> Vector2:
	var local := get_canvas_transform().affine_inverse() * screen_pos
	return to_local(local)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		_shift_down = event.pressed
	elif event is InputEventWithModifiers:
		_shift_down = event.shift_pressed
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
		_mouse_seen = true
		_refresh_hover()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if visuals != null and visuals.visible:
					return
				var hit := _pick_world(_world_point(event.position))
				if not hit.is_empty():
					var hit_zone: WorldZone = hit["zone"]
					var c: Vector2i = hit["cell"]
					var record := _npc_record(hit_zone.zone_id, c)
					var door_row := door_at(hit_zone.zone_id, c)
					if not record.is_empty():
						_approach_npc_in(hit_zone, record)
					elif not door_row.is_empty():
						approach_door(str(door_row["id"]))
					else:
						click_cell(hit_zone, c)
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_zoom * 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom / 1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				set_run_mode(not run_mode)
			KEY_1:
				weather.cycle_weather()
			KEY_2:
				weather.time_scale = 1.0 if weather.time_scale > 1.0 else 30.0
				_refresh_hud()
			KEY_ESCAPE:
				if door_panel != null and door_panel.is_open():
					door_panel.close()
				elif dialogue != null and dialogue.is_open():
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


## A left click on a ground cell. A cell the hero cannot reach gets a red X,
## and the hero walks to the closest cell of this chunk he can reach instead.
func click_cell(hit_zone: WorldZone, c: Vector2i) -> Dictionary:
	if hit_zone == null or zone == null:
		return {"ok": false, "reason": "busy"}
	var result: Dictionary
	if hit_zone.zone_id == zone.zone_id:
		result = walk_to(c)
	else:
		result = walk_to_zone(hit_zone.zone_id, c)
	if bool(result.get("ok", false)) or str(result.get("reason", "")) == "busy":
		return result
	_flag_bad_click(hit_zone, c)
	if hit_zone.zone_id != zone.zone_id:
		return result
	var near := nearest_reachable(c)
	if near.x < 0:
		return result
	var fallback := walk_to(near)
	fallback["fallback_from"] = c
	return fallback


func _flag_bad_click(z: WorldZone, c: Vector2i) -> void:
	bad_click_cell = c
	_bad_click_zone = z
	_bad_click_until = Time.get_ticks_msec() + BAD_CLICK_MS
	if _hover != null:
		var world := _origin_of(z.zone_id) + c
		_hover.z_index = (world.x + world.y) * BoardVisualSort.TILE_Z_SCALE + 1
		_hover.queue_redraw()
	get_tree().create_timer(float(BAD_CLICK_MS) / 1000.0).timeout.connect(func():
		if Time.get_ticks_msec() >= _bad_click_until and _hover != null:
			bad_click_cell = Vector2i(-1, -1)
			_hover.queue_redraw())


## Cells of this chunk the hero can reach from where he stands, walking round
## NPCs. Same step rules as `WorldWalk`, kept inside the chunk.
func reachable_here() -> Dictionary:
	var reached := {}
	if zone == null or walker == null:
		return reached
	var start: Vector2i = walker.anchor_cell()
	if not zone.in_bounds(start):
		return reached
	# Hover asks on every cell change. One flood per stand cell and set of
	# NPC-blocked cells, so it is reused across frames until either moves.
	var blocked := _extra_blocked()
	var key := "%s#%d#%d#%d" % [zone.zone_id, start.x, start.y, hash(blocked.keys())]
	if key == _reach_key:
		return _reach_cache
	var limit := WorldWalk._limit(map, null)
	var zid := zone.zone_id
	reached[start] = true
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + dir
			if reached.has(nxt) or not zone.in_bounds(nxt):
				continue
			if blocked.has(WorldWalk.cell_key(zid, nxt)):
				continue
			if WorldWalk.classify_step(map, zid, cur, zid, nxt, limit) != "":
				continue
			reached[nxt] = true
			queue.append(nxt)
	_reach_key = key
	_reach_cache = reached
	return reached


## Closest reachable cell of this chunk to `target` (not the one he stands on).
## Returns (-1, -1) when nothing nearer than where he stands is reachable.
func nearest_reachable(target: Vector2i) -> Vector2i:
	var reached := reachable_here()
	var here: Vector2i = walker.anchor_cell()
	var best := Vector2i(-1, -1)
	var best_d := Vector2(target - here).length_squared()
	for key in reached.keys():
		var cell: Vector2i = key
		if cell == here or not zone.exit_link(cell).is_empty():
			continue
		var d := Vector2(target - cell).length_squared()
		if d < best_d:
			best_d = d
			best = cell
	return best


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


## Hover the cell under the last mouse position. Also called when the view
## moves under a still cursor (the camera follows the hero), so the green
## diamond stays under the pointer and marks the cell a click would pick.
func _refresh_hover() -> void:
	_hover_xf = get_canvas_transform()
	var motion := _pick_world(_world_point(_mouse_pos))
	if motion.is_empty():
		_set_hover(null, Vector2i(-1, -1))
	else:
		_set_hover(motion["zone"], motion["cell"])


func _set_hover(z: WorldZone, c: Vector2i) -> void:
	if z == _hover_zone and c == hover_cell:
		return
	_hover_zone = z
	hover_cell = c
	_sync_door_hover(z, c)
	_hover_unreachable = false
	# NPC cells open talk on click, so they never read as unreachable.
	if z != null and zone != null and z == zone and c.x >= 0 and z.passable_at(c) and walker != null and c != walker.anchor_cell() and _npc_node_at(c) == null:
		_hover_unreachable = not reachable_here().has(c)
	if z != null and c.x >= 0:
		var world := _origin_of(z.zone_id) + c
		_hover.z_index = (world.x + world.y) * BoardVisualSort.TILE_Z_SCALE + 1
	_hover.queue_redraw()


func _draw_hover() -> void:
	_draw_bad_click()
	var shown: WorldZone = _hover_zone if _hover_zone != null else zone
	if shown == null or hover_cell.x < 0 or not shown.in_bounds(hover_cell):
		return
	var color := Color(0.45, 0.95, 0.5, 0.9)
	if atlas != null and _open_gate(atlas.gate_at(shown.zone_id, hover_cell)):
		color = Color(1.0, 0.84, 0.35, 0.95)
	elif not shown.exit_link(hover_cell).is_empty():
		color = Color(1.0, 0.84, 0.35, 0.95)
	elif not shown.passable_at(hover_cell) or (shown == zone and _hover_unreachable):
		color = Color(0.95, 0.35, 0.3, 0.9)
	var world := _origin_of(shown.zone_id) + hover_cell
	var d := Pick.diamond(world, float(shown.height_at(hover_cell)))
	var fill := color
	fill.a = 0.22
	_hover.draw_colored_polygon(d, fill)
	_hover.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), color, 2.0)


## Red X on a refused click cell.
func _draw_bad_click() -> void:
	var z: WorldZone = _bad_click_zone
	if z == null or bad_click_cell.x < 0 or not z.in_bounds(bad_click_cell):
		return
	if Time.get_ticks_msec() >= _bad_click_until:
		return
	var world := _origin_of(z.zone_id) + bad_click_cell
	var c := BoardVisualSort.cell_to_local(world, float(z.height_at(bad_click_cell)))
	var red := Color(0.95, 0.25, 0.2, 0.95)
	_hover.draw_line(c + Vector2(-12, -6), c + Vector2(12, 6), red, 3.0)
	_hover.draw_line(c + Vector2(-12, 6), c + Vector2(12, -6), red, 3.0)


func _process(delta: float) -> void:
	if _bench_until > 0.0:
		_bench.append(delta)
		if Time.get_ticks_msec() / 1000.0 >= _bench_until:
			_report_bench()
			return
	if walker == null or zone == null:
		return
	tick_run(delta)
	var aim: Vector2 = walker.position + walker.visual_offset()
	if walker.is_moving():
		var step: Vector2 = _facing_step(walker.facing)
		if step.length() > 1.0:
			_lead = step.normalized() * LEAD_PX
	else:
		_lead = _lead.move_toward(Vector2.ZERO, delta * 60.0)
	camera.position = aim + _lead
	var wz: int = walker.z_index
	var covered := false
	var npc_feet := _npc_cover_feet()
	covered = _cover_children(props_root, walker.position, wz, npc_feet) or covered
	covered = _cover_children(decor_root, walker.position, wz, npc_feet) or covered
	if neighbours != null:
		var feet: Vector2 = walker.position
		for host in neighbours.get_children():
			if not _host_near_hero(host, feet):
				continue
			var props := host.get_node_or_null("Props")
			var decor := host.get_node_or_null("Decor")
			covered = _cover_children(props, feet, wz, npc_feet) or covered
			covered = _cover_children(decor, feet, wz, npc_feet) or covered
	walker.set_covered(covered)
	if _mouse_seen and not _transitioning and get_canvas_transform() != _hover_xf:
		_refresh_hover()
	if weather.time_scale > 1.0 or Engine.get_process_frames() % 30 == 0:
		_refresh_hud()
	_cull_neighbour_hosts()
	_warm_grounds()
	_sync_snowfall()


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
	_build_stamina_bar(sheet)
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


## Small stamina strip under the top-left info block, in the HUD card style.
func _build_stamina_bar(sheet: Control) -> void:
	stamina_bar = Panel.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Below the six-line info block, clear of its last line.
	stamina_bar.position = Vector2(48, 178)
	stamina_bar.size = Vector2(168, 16)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.08, 0.06, 0.82)
	box.border_color = Color(0.72, 0.58, 0.32)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	stamina_bar.add_theme_stylebox_override("panel", box)
	_stamina_fill = ColorRect.new()
	_stamina_fill.name = "Fill"
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_fill.position = Vector2(3, 3)
	_stamina_fill.size = Vector2(162, 10)
	stamina_bar.add_child(_stamina_fill)
	stamina_bar.visible = false
	sheet.add_child(stamina_bar)
	_sync_stamina_bar(false)


func _dress_ground(g: Node, z: WorldZone) -> void:
	_bind_plane_samples(z)
	g.set("cache_tag", "map%d" % map.get_instance_id() if map != null and _seamless() else "")
	g.set("snow_rects", _snow_town_rects())
	g.set("show_walk_exits", not _seamless())
	g.set("blend_margin", 2 if _seamless() else 0)


func _bind_plane_samples(z: WorldZone) -> void:
	if z == null or not _seamless():
		if z != null:
			z.sample_terrain = Callable()
			z.sample_height = Callable()
			z.sample_zone_id = Callable()
		return
	var origin := _origin_of(z.zone_id)
	z.sample_terrain = _sample_terrain.bind(origin)
	z.sample_height = _sample_height.bind(origin)
	z.sample_zone_id = _sample_zone_id.bind(origin)


## World-cell rects of the snow-town chunks, for the frost blend around them.
func _snow_town_rects() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if map == null or not _seamless():
		return out
	for id in plane_offsets.keys():
		if not Ground.snow_town(str(id)):
			continue
		var z: WorldZone = map.zone(str(id))
		if z != null:
			out.append(Rect2i(plane_offsets[id], Vector2i(z.width, z.height)))
	return out


func _sample_terrain(cell: Vector2i, origin: Vector2i) -> String:
	var hit := _chunk_at(origin + cell)
	if hit.is_empty():
		return ""
	return (hit["zone"] as WorldZone).terrain_at(hit["cell"])


func _sample_height(cell: Vector2i, origin: Vector2i) -> int:
	var hit := _chunk_at(origin + cell)
	if hit.is_empty():
		return 0
	return (hit["zone"] as WorldZone).height_at(hit["cell"])


func _sample_zone_id(cell: Vector2i, origin: Vector2i) -> String:
	var hit := _chunk_at(origin + cell)
	if hit.is_empty():
		return ""
	return (hit["zone"] as WorldZone).zone_id


## The chunk under a world cell. Ground and pick ask this for every cell past
## a chunk edge (the sea fringe asks 16 times a cell), so answers are kept per
## map and plane layout instead of scanning every chunk each time.
func _chunk_at(world: Vector2i) -> Dictionary:
	if map == null:
		return {}
	if map != _chunk_map or not is_same(plane_offsets, _chunk_offsets):
		_chunk_map = map
		_chunk_offsets = plane_offsets
		_chunk_hits.clear()
	var known: Variant = _chunk_hits.get(world)
	if known != null:
		return known
	var found := {}
	for id in plane_offsets.keys():
		var z: WorldZone = map.zone(str(id))
		if z == null:
			continue
		var origin: Vector2i = plane_offsets[id]
		var local := world - origin
		if z.in_bounds(local):
			found = {"zone": z, "cell": local}
			break
	found.make_read_only()
	_chunk_hits[world] = found
	return found


func _seamless() -> bool:
	return map != null and map.region == "crosshaven" and not plane_offsets.is_empty()


func _refresh_plane() -> void:
	# The layout depends on the map alone. Keeping the same dictionary for the
	# same map lets chunk lookups and ground setups stay cached across loads.
	if map != null and map == _plane_map and not plane_offsets.is_empty():
		return
	_plane_map = map
	plane_offsets = {}
	if map == null or map.region != "crosshaven":
		return
	var lay: Dictionary = WorldPlane.layout(map)
	var found: Variant = lay.get("offsets", {})
	if typeof(found) == TYPE_DICTIONARY:
		plane_offsets = found


func _origin_of(zone_id: String) -> Vector2i:
	if plane_offsets.has(zone_id):
		return plane_offsets[zone_id]
	return Vector2i.ZERO


func _raise_sort(root: Node, origin: Vector2i) -> void:
	if root == null:
		return
	var add := (origin.x + origin.y) * BoardVisualSort.TILE_Z_SCALE
	if add == 0:
		return
	# The contacts/critter roots live across zone loads. Set their z once
	# per load instead of adding the bias again on every chunk.
	if root is Node2D:
		var top := root as Node2D
		if not top.z_as_relative and not ("base_z" in top):
			top.z_index = _clamp_z(add)
	for child in root.get_children():
		_raise_one(child, add)


func _raise_one(node: Node, add: int) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Node2D:
		var drawn := node as Node2D
		if not drawn.z_as_relative:
			if "base_z" in drawn:
				drawn.base_z = int(drawn.base_z) + add
				drawn.z_index = _clamp_z(int(drawn.base_z))
			else:
				drawn.z_index = _clamp_z(drawn.z_index + add)
	for child in node.get_children():
		if child is Node2D and (child as Node2D).z_as_relative:
			continue
		_raise_one(child, add)


func _clamp_z(z: int) -> int:
	return clampi(z, -4096, 4096)


## Free an NPC body and its name plate now (the body's own exit only queues
## the plate, which would show a frame at its old place).
func _free_npc(node: Node) -> void:
	var plate: Variant = node.get("_plate")
	if plate != null and is_instance_valid(plate):
		(plate as Node).free()
	node.free()


func _free_host(host: Node) -> void:
	var npcs := host.get_node_or_null("Npcs")
	if npcs != null:
		for node in npcs.get_children():
			_free_npc(node)
	host.free()


func _mount_neighbours(zone_id: String, everything: bool = false) -> void:
	if neighbours == null:
		return
	var touch: Array = []
	if _seamless():
		if everything:
			for id in plane_offsets.keys():
				touch.append(id)
		else:
			touch = WorldPlane.touching(map, plane_offsets, zone_id)
	# A chunk that stays a neighbour keeps its host (props, decor, NPCs), as
	# built and drawn. The rest are freed before new hosts take their names.
	var kept := {}
	var keep := {ground: true}
	for child in neighbours.get_children():
		var zid := str(child.name)
		var g: Variant = child.get_meta("ground", null)
		var reuse: bool = touch.has(zid) and zid != zone_id and g != null and is_instance_valid(g) \
			and child.get_meta("origin", Vector2i(-99999, -99999)) == _origin_of(zid) \
			and child.get_meta("snow_kit", not Ground.snow_kit) == Ground.snow_kit \
			and child.get_meta("map", 0) == (map.get_instance_id() if map != null else 0)
		if reuse:
			kept[zid] = child
			keep[g] = true
		else:
			_free_host(child)
	if not _seamless():
		_prune_grounds(keep)
		return
	for id in touch:
		var zid := str(id)
		if zid == zone_id:
			continue
		var other: WorldZone = map.zone(zid)
		if other == null:
			continue
		if kept.has(zid):
			_mark_gates_on(kept[zid].get_meta("ground"), other)
			continue
		var origin: Vector2i = _origin_of(zid)
		var host := Node2D.new()
		host.name = zid
		host.position = BoardVisualSort.cell_to_local(origin)
		neighbours.add_child(host)
		# A neighbour's ground is kept from earlier loads when it was already
		# built (as the main chunk or a neighbour), so a seam crossing does
		# not set up and draw the ground of seven chunks again.
		var g := _ground_for(other, origin)
		g.set_process(false)
		host.set_meta("ground", g)
		keep[g] = true
		_mark_gates_on(g, other)
		var props := Node2D.new()
		props.name = "Props"
		host.add_child(props)
		for record in other.props:
			var p := Prop.new()
			props.add_child(p)
			p.snow_cover = g.cover_at(_record_cell(record))
			p.setup(other, record)
			p.snow_amount = maxf(Ground.snow_at(other.zone_id, p.south_cell), g.cover_at(p.south_cell))
		_raise_sort(props, origin)
		var decor := Node2D.new()
		decor.name = "Decor"
		host.add_child(decor)
		for record in other.decor:
			var d := Decor.new()
			decor.add_child(d)
			d.snow_cover = g.cover_at(Vector2i(int(record["x"]), int(record["y"])))
			d.setup(other, record)
		_plant_snow_pines(decor, other)
		_raise_sort(decor, origin)
		var npcs := Node2D.new()
		npcs.name = "Npcs"
		host.add_child(npcs)
		if npc_book != null:
			for record in npc_book.for_zone(zid):
				var node := WorldNpc.new()
				npcs.add_child(node)
				node.setup(other, record, npc_plates)
			_raise_sort(npcs, origin)
		var rect := Pick.zone_rect(other)
		rect.position += host.position
		host.set_meta("bounds", rect)
		host.set_meta("origin", origin)
		host.set_meta("snow_kit", Ground.snow_kit)
		host.set_meta("map", map.get_instance_id())
		host.set_meta("wide", other.width)
		host.set_meta("tall", other.height)
		# Neighbours stay in the tree. Sway stays frozen, and a host is drawn
		# only while its diamond meets the camera, so off-screen roads do not
		# walk the software renderer.
		_freeze_visuals(props)
		_freeze_visuals(decor)
		# Showing a hidden node redraws everything under it, which cost a
		# whole chunk of ground script (up to half a second) each time the
		# camera edge crossed a chunk. The cull hides hosts and their grounds
		# on the rendering server instead (see `_cull_neighbour_hosts`).
		host.set_meta("shown", false)
		RenderingServer.canvas_item_set_visible(host.get_canvas_item(), false)
		_show_ground(g, false)
	_prune_grounds(keep)
	# Same draw order as a fresh mount: hosts in touch order, the main ground
	# first, then the neighbours' grounds. Moving a child does not redraw it.
	var slot := 0
	for id in touch:
		var host := neighbours.get_node_or_null(NodePath(str(id)))
		if host != null:
			neighbours.move_child(host, slot)
			slot += 1
	var at := 0
	for g in [ground] + neighbours.get_children().map(func(h: Node) -> Variant: return h.get_meta("ground", null)):
		if g != null and is_instance_valid(g) and (g as Node).get_parent() == _grounds_root:
			_grounds_root.move_child(g, at)
			at += 1


## The ground of chunk `z` placed at `origin`, built once and kept under
## `_grounds_root` while it is the main chunk or a neighbour. Grounds never
## change parent: re-entering the canvas would redraw every row.
func _ground_for(z: WorldZone, origin: Vector2i) -> Node2D:
	if _grounds_root == null:
		_grounds_root = Node2D.new()
		_grounds_root.name = "Grounds"
		add_child(_grounds_root)
		move_child(_grounds_root, 1)
	var key := "%s|%s|%s|%d" % [z.zone_id, origin, Ground.snow_kit, map.get_instance_id() if map != null else 0]
	var known: Node2D = _ground_pool.get(key)
	if known != null and is_instance_valid(known):
		return known
	var g := Ground.new()
	g.name = "Ground_%s" % z.zone_id
	_grounds_root.add_child(g, true)
	g.position = BoardVisualSort.cell_to_local(origin)
	g.world_origin = origin
	_dress_ground(g, z)
	g.setup(z)
	g.start_cold()
	_raise_sort(g, origin)
	_ground_pool[key] = g
	return g


## Free kept grounds that are neither the main chunk nor a neighbour now.
func _prune_grounds(keep: Dictionary) -> void:
	for key in _ground_pool.keys():
		var g: Node2D = _ground_pool[key]
		if g == null or not is_instance_valid(g):
			_ground_pool.erase(key)
		elif not keep.has(g):
			_ground_pool.erase(key)
			g.free()


## Show or hide a ground on the rendering server only (no redraw).
func _show_ground(g: Node2D, show: bool) -> void:
	if g == null or not is_instance_valid(g):
		return
	if bool(g.get_meta("shown", true)) == show:
		return
	g.set_meta("shown", show)
	RenderingServer.canvas_item_set_visible(g.get_canvas_item(), show)


func _freeze_visuals(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_internal(false)
	if node is AnimatedSprite2D:
		(node as AnimatedSprite2D).stop()
	for child in node.get_children():
		_freeze_visuals(child)


func _cull_neighbour_hosts() -> void:
	if neighbours == null or camera == null or not _seamless():
		return
	var view := _camera_world_rect().grow(32.0)
	var hosts := neighbours.get_children()
	for host in hosts:
		if not host.has_meta("origin"):
			continue
		var origin: Vector2i = host.get_meta("origin")
		var wide := int(host.get_meta("wide"))
		var tall := int(host.get_meta("tall"))
		var show := _view_hits_chunk(view, origin, wide, tall)
		var body := host as Node2D
		if body == null:
			continue
		if bool(body.get_meta("shown", true)) != show:
			body.set_meta("shown", show)
			RenderingServer.canvas_item_set_visible(body.get_canvas_item(), show)
		_show_ground(body.get_meta("ground", null), show)


## Ground rows draw once, when first shown. Rows that meet the view (where
## the camera is and where it is heading) show now; the rest of this chunk
## and its neighbours warm up WARM_CELLS_PER_FRAME cells a frame, so a load
## or a seam crossing does not draw seven chunks of ground in one frame.
func _warm_grounds(view_only: bool = false) -> void:
	var grounds: Array[Node2D] = []
	for g in _ground_pool.values():
		if g != null and is_instance_valid(g):
			grounds.append(g)
	if camera == null:
		for g in grounds:
			g.call("warm", Rect2(), -1)
		return
	var view := _camera_world_rect()
	if walker != null:
		var aim := to_global(walker.position + _lead)
		view = view.merge(Rect2(aim - view.size * 0.5, view.size))
	view = view.grow(WARM_VIEW_MARGIN)
	var budget := 0 if view_only else WARM_CELLS_PER_FRAME
	for g in grounds:
		budget = int(g.call("warm", Rect2(view.position - g.global_position, view.size), budget))


func _view_hits_chunk(view: Rect2, origin: Vector2i, wide: int, tall: int) -> bool:
	var corners: Array[Vector2i] = [
		origin,
		origin + Vector2i(wide - 1, 0),
		origin + Vector2i(0, tall - 1),
		origin + Vector2i(wide - 1, tall - 1),
	]
	for cell in corners:
		if view.has_point(BoardVisualSort.cell_to_local(cell)):
			return true
	for gy in 3:
		for gx in 4:
			var p := view.position + Vector2(view.size.x * (float(gx) + 0.5) / 4.0, view.size.y * (float(gy) + 0.5) / 3.0)
			if _pixel_in_chunk(p, origin, wide, tall):
				return true
	return false


func _pixel_in_chunk(p: Vector2, origin: Vector2i, wide: int, tall: int) -> bool:
	var u := (p.x / 32.0 + p.y / 16.0) * 0.5
	var v := (p.y / 16.0 - p.x / 32.0) * 0.5
	var cell := Vector2i(int(floor(u)), int(floor(v))) - origin
	return cell.x >= -1 and cell.y >= -1 and cell.x <= wide and cell.y <= tall


func _camera_world_rect() -> Rect2:
	var center := camera.get_screen_center_position()
	var zoom := camera.zoom
	var vp := get_viewport().get_visible_rect().size
	var size := Vector2(vp.x / maxf(zoom.x, 0.01), vp.y / maxf(zoom.y, 0.01))
	return Rect2(center - size * 0.5, size)


func _host_near_hero(host: Node, feet: Vector2) -> bool:
	if not host.has_meta("bounds"):
		return false
	var bounds: Rect2 = host.get_meta("bounds")
	return bounds.grow(96.0).has_point(feet)


func _mark_gates_on(g: Node, z: WorldZone) -> void:
	if atlas == null or z == null or g == null:
		return
	for gate in atlas.gates_from_zone(z.zone_id):
		if not _open_gate(gate):
			continue
		var frm: Dictionary = gate["from"]
		var cell := Vector2i(int(frm["x"]), int(frm["y"]))
		g.call("add_gate_arrow", cell, _edge_dir_of(z, cell))


func _edge_dir_of(z: WorldZone, cell: Vector2i) -> Vector2i:
	if cell.y == 0:
		return Vector2i(0, -1)
	if cell.y == z.height - 1:
		return Vector2i(0, 1)
	if cell.x == 0:
		return Vector2i(-1, 0)
	if cell.x == z.width - 1:
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _apply_camera_limits(snap: bool) -> void:
	if camera == null or zone == null:
		return
	if _seamless():
		var bounds := _world_pixel_bounds()
		var rect := bounds.grow(SEA_MARGIN)
		camera.limit_left = int(floor(rect.position.x))
		camera.limit_top = int(floor(rect.position.y))
		camera.limit_right = int(ceil(rect.end.x))
		camera.limit_bottom = int(ceil(rect.end.y))
		_sync_backdrop(rect, bounds)
	else:
		var local := Pick.zone_rect(zone).grow(160)
		camera.limit_left = int(local.position.x)
		camera.limit_top = int(local.position.y)
		camera.limit_right = int(local.end.x)
		camera.limit_bottom = int(local.end.y)
		if _backdrop != null:
			_backdrop.visible = false
	if snap:
		camera.position = walker.position
		camera.reset_smoothing()
		_lead = Vector2.ZERO


func _world_pixel_bounds() -> Rect2:
	var merged := Rect2()
	var first := true
	for id in plane_offsets.keys():
		var z: WorldZone = map.zone(str(id))
		if z == null:
			continue
		var rect := Pick.zone_rect(z)
		rect.position += BoardVisualSort.cell_to_local(_origin_of(str(id)))
		if first:
			merged = rect
			first = false
		else:
			merged = merged.merge(rect)
	return merged


func _sync_backdrop(sea: Rect2, fields: Rect2) -> void:
	if _backdrop == null:
		return
	_backdrop.visible = true
	_backdrop.set_meta("sea", sea)
	_backdrop.set_meta("fields", fields.grow(96.0))
	_backdrop.queue_redraw()


func _record_cell(record: Dictionary) -> Vector2i:
	var origin: Variant = record.get("origin", null)
	if typeof(origin) == TYPE_DICTIONARY:
		return Vector2i(int(origin["x"]), int(origin["y"]))
	var cells: Array = record.get("footprint", [])
	if cells.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(cells[0]["x"]), int(cells[0]["y"]))


## Snowy pines ringing Northgate. View only, on cliff cells nobody can walk:
## never a path, door, exit or NPC cell, and never next to a building.
const SNOW_PINE_TOWN := "crosshaven_northgate"
const SNOW_PINE_IDS: Array[String] = ["tree_pine_snow_a", "tree_pine_snow_b", "tree_pine_snow_c"]


## `keep_clear` cells never take a pine (NPC posts, their talk ring and the
## cells their walkers may use: see npc_keep_clear).
static func snow_pine_cells(z: WorldZone, keep_clear: Dictionary = {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if z == null or z.zone_id != SNOW_PINE_TOWN or not Ground.snow_kit:
		return out
	var near_prop := keep_clear.duplicate()
	for record in z.props:
		for c in record.get("footprint", []):
			var at := Vector2i(int(c["x"]), int(c["y"]))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					near_prop[at + Vector2i(dx, dy)] = true
	var taken := {}
	for y in z.height:
		for x in z.width:
			var cell := Vector2i(x, y)
			if z.terrain_at(cell) != "cliff" or z.passable_at(cell) or near_prop.has(cell):
				continue
			# Keep the crown off the town: a cliff cell beside a walkable
			# cell takes a pine only half as often.
			var edge := false
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cell + step
				if z.in_bounds(n) and (z.passable_at(n) or z.terrain_at(n) == "water"):
					edge = true
			var roll := CrosshavenArt.h(x * 7 + 3, y * 5 + 1, 100)
			if roll >= (22 if edge else 48):
				continue
			var crowded := false
			for t in taken.keys():
				var o: Vector2i = t
				if maxi(absi(o.x - x), absi(o.y - y)) <= 1:
					crowded = true
					break
			if crowded:
				continue
			taken[cell] = true
			out.append(cell)
	return out


## Cells of `z` a pine must leave free for its NPCs: every post and the ring
## around it, and every cell a walker of that chunk could reach from home.
static func npc_keep_clear(z: WorldZone, records: Array) -> Dictionary:
	var out := {}
	if z == null:
		return out
	for record in records:
		var at: Dictionary = record.get("cell", {})
		var home := Vector2i(int(at.get("x", -99)), int(at.get("y", -99)))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				out[home + Vector2i(dx, dy)] = true
		var radius := NpcRoam.radius_for(NpcRoam.behaviour_for(str(record.get("role", ""))))
		for cell in NpcRoam.area(z, home, radius, {}).keys():
			out[cell] = true
	return out


## Pine cells of `z` with its NPCs kept clear (cached per chunk).
var _pine_cache := {}


func _snow_pines_for(z: WorldZone) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if z == null:
		return out
	var key := "%s|%s" % [z.zone_id, Ground.snow_kit]
	if _pine_cache.has(key):
		out.assign(_pine_cache[key])
		return out
	var records: Array = npc_book.for_zone(z.zone_id) if npc_book != null else []
	out = snow_pine_cells(z, npc_keep_clear(z, records))
	if npc_book != null:
		_pine_cache[key] = out
	return out


func _plant_snow_pines(host: Node2D, z: WorldZone) -> void:
	for cell in _snow_pines_for(z):
		var d := Decor.new()
		host.add_child(d)
		d.snow_cover = 1.0
		d.setup(z, {"type": SNOW_PINE_IDS[CrosshavenArt.h(cell.x, cell.y, SNOW_PINE_IDS.size())], "x": cell.x, "y": cell.y})


func _sync_snowfall(snap: bool = false) -> void:
	if _snow == null:
		return
	var target := 0.0
	if zone != null and walker != null and ground != null:
		target = ground.cover_at(walker.cell)
	_snow.target = target
	if camera != null:
		_snow.camera_pos = camera.position
		_snow.camera_zoom = camera.zoom.x
	if snap:
		_snow.snap()
	else:
		_snow.step(get_process_delta_time())
	snow_level = _snow.level


func _draw_backdrop() -> void:
	if _backdrop == null or not _backdrop.has_meta("sea"):
		return
	var sea: Rect2 = _backdrop.get_meta("sea")
	# Past the coast the fill is sea. The olive field rect and the square
	# cliff rings used to show inside the camera before the land diamonds.
	_backdrop.draw_rect(sea, SEA, true)


func _refresh_presence() -> void:
	var band := {}
	if atlas != null and atlas.levels != null and zone != null:
		band = atlas.levels.zone_for_chunk(zone.zone_id)
	if band.is_empty():
		level_band = ""
		music_id = zone.zone_id if zone != null else ""
		danger = false
		return
	level_band = "%s %d–%d" % [str(band.get("name", "")), int(band.get("level_min", 1)), int(band.get("level_max", 1))]
	music_id = str(band.get("id", ""))
	danger = int(band.get("level_min", 1)) >= DANGER_FROM


func _grade_params(grade: Dictionary) -> Dictionary:
	var warm: Array = grade.get("warm_mul", [1.02, 1.0, 0.96])
	var haze: Array = grade.get("haze_col", [0.45, 0.52, 0.62])
	var tint: Array = grade.get("tint_col", [1.0, 1.0, 1.0])
	return {
		"grade_mix": 1.0 if not grade.is_empty() else 0.0,
		"warm_mul": Color(float(warm[0]), float(warm[1]), float(warm[2])),
		"haze_col": Color(float(haze[0]), float(haze[1]), float(haze[2])),
		"haze_max": float(grade.get("haze_max", 0.15)),
		"saturation": float(grade.get("saturation", 1.06)),
		"tint_col": Color(float(tint[0]), float(tint[1]), float(tint[2])),
		"tint_amount": float(grade.get("tint_amount", 0.0)),
	}


func _read_grade(mat: ShaderMaterial) -> Dictionary:
	return {
		"grade_mix": float(mat.get_shader_parameter("grade_mix")),
		"warm_mul": mat.get_shader_parameter("warm_mul"),
		"haze_col": mat.get_shader_parameter("haze_col"),
		"haze_max": float(mat.get_shader_parameter("haze_max")),
		"saturation": float(mat.get_shader_parameter("saturation")),
		"tint_col": mat.get_shader_parameter("tint_col"),
		"tint_amount": float(mat.get_shader_parameter("tint_amount")),
	}


func _write_grade(mat: ShaderMaterial, params: Dictionary) -> void:
	mat.set_shader_parameter("grade_mix", float(params["grade_mix"]))
	mat.set_shader_parameter("warm_mul", params["warm_mul"])
	mat.set_shader_parameter("haze_col", params["haze_col"])
	mat.set_shader_parameter("haze_max", float(params["haze_max"]))
	mat.set_shader_parameter("saturation", float(params["saturation"]))
	mat.set_shader_parameter("tint_col", params["tint_col"])
	mat.set_shader_parameter("tint_amount", float(params["tint_amount"]))


func _lerp_grade(from: Dictionary, to: Dictionary, u: float) -> Dictionary:
	var warm_from: Color = from["warm_mul"]
	var warm_to: Color = to["warm_mul"]
	var haze_from: Color = from["haze_col"]
	var haze_to: Color = to["haze_col"]
	var tint_from: Color = from["tint_col"]
	var tint_to: Color = to["tint_col"]
	return {
		"grade_mix": lerpf(float(from["grade_mix"]), float(to["grade_mix"]), u),
		"warm_mul": warm_from.lerp(warm_to, u),
		"haze_col": haze_from.lerp(haze_to, u),
		"haze_max": lerpf(float(from["haze_max"]), float(to["haze_max"]), u),
		"saturation": lerpf(float(from["saturation"]), float(to["saturation"]), u),
		"tint_col": tint_from.lerp(tint_to, u),
		"tint_amount": lerpf(float(from["tint_amount"]), float(to["tint_amount"]), u),
	}


func _pick_world(world_point: Vector2) -> Dictionary:
	if zone == null:
		return {}
	# Ranks are world diagonals, so chunks north or west of the plane origin
	# rank below zero. Compare against "no hit yet", not against -1, or every
	# cell with world x + y < 0 is unclickable (North Road rows near Northgate).
	var best := _rank_pick(zone, world_point)
	if neighbours != null:
		for host in neighbours.get_children():
			var other: WorldZone = map.zone(str(host.name)) if map != null else null
			if other == null:
				continue
			var hit := _rank_pick(other, world_point)
			if hit.is_empty():
				continue
			if best.is_empty() or int(hit["rank"]) > int(best["rank"]):
				best = hit
	if best.is_empty():
		return {}
	return {"zone": best["zone"], "cell": best["cell"]}


func _rank_pick(z: WorldZone, world_point: Vector2) -> Dictionary:
	var origin := _origin_of(z.zone_id)
	var local_pt := world_point - BoardVisualSort.cell_to_local(origin)
	var cell := Pick.pick(z, local_pt, _max_height_of(z))
	if cell.x < 0:
		return {}
	var world := origin + cell
	var rank := (world.x + world.y) * 64 + z.height_at(cell)
	return {"zone": z, "cell": cell, "rank": rank}


## Tallest step of a chunk, kept per chunk until the next zone load. The
## pick asks it for every chunk on every mouse move; scanning all cells of
## seven chunks each time cost a few ms a move.
func _max_height_of(z: WorldZone) -> int:
	var known: Variant = _max_h_cache.get(z)
	if known != null:
		return int(known)
	var top := Pick.max_height(z)
	_max_h_cache[z] = top
	return top


func _npc_record(zone_id: String, cell: Vector2i) -> Dictionary:
	if zone != null and zone_id == zone.zone_id:
		return _npc_at(cell)
	if npc_book == null:
		return {}
	for record in npc_book.for_zone(zone_id):
		var at: Dictionary = record.get("cell", {})
		if Vector2i(int(at.get("x", -1)), int(at.get("y", -1))) == cell:
			return record
	return {}


func _approach_npc_in(hit_zone: WorldZone, record: Dictionary) -> void:
	if record.is_empty() or hit_zone == null:
		return
	if hit_zone.zone_id == zone.zone_id:
		_approach_npc(record)
		return
	var at: Dictionary = record["cell"]
	var npc_cell := Vector2i(int(at["x"]), int(at["y"]))
	var stand := _stand_on(hit_zone, npc_cell)
	if stand.x < 0:
		walk_rejected.emit("no_path")
		return
	var result := walk_to_zone(hit_zone.zone_id, stand)
	if not bool(result.get("ok", false)):
		return
	_pending_talk = {"id": str(record["id"]), "stand": stand, "npc": npc_cell}


func _stand_on(z: WorldZone, npc_cell: Vector2i) -> Vector2i:
	for dir in WorldWalk.ORTHO:
		var next: Vector2i = npc_cell + dir
		if not z.passable_at(next) or not z.exit_link(next).is_empty():
			continue
		if npc_book != null:
			var busy := false
			for record in npc_book.for_zone(z.zone_id):
				var at: Dictionary = record.get("cell", {})
				if Vector2i(int(at.get("x", -1)), int(at.get("y", -1))) == next:
					busy = true
			if busy:
				continue
		return next
	return Vector2i(-1, -1)


## Fade every prop or decor under `root` that covers the hero or one of the
## NPCs in `npc_feet` ([feet, z] pairs in this node's space). True when the
## hero is behind one of them.
func _cover_children(root: Node, feet: Vector2, wz: int, npc_feet: Array = []) -> bool:
	if root == null:
		return false
	var parent := root as Node2D
	var local_feet := feet
	var local_npcs: Array = npc_feet
	if parent != null:
		local_feet = parent.to_local(to_global(feet))
		if not npc_feet.is_empty():
			local_npcs = []
			for pair in npc_feet:
				local_npcs.append([parent.to_local(to_global(pair[0])), pair[1]])
	var covered := false
	for node in root.get_children():
		if node.update_cover(local_feet, wz, local_npcs):
			covered = true
	return covered


## Feet and z of each NPC body of the current chunk only (neighbour chunks'
## NPCs are not checked), so the per-frame cost stays at one chunk's NPCs.
func _npc_cover_feet() -> Array:
	var out: Array = []
	if npcs_root == null:
		return out
	for node in npcs_root.get_children():
		var body := node as Node2D
		if body == null or not body.visible or body.is_queued_for_deletion():
			continue
		out.append([to_local(body.global_position), body.z_index])
	return out


func _facing_step(dir: String) -> Vector2:
	match dir:
		"e":
			return Vector2(32, 16)
		"w":
			return Vector2(-32, -16)
		"s":
			return Vector2(-32, 16)
		_:
			return Vector2(32, -16)


func remember_place() -> void:
	if progress == null or zone == null or walker == null:
		return
	progress.note_place(zone.zone_id, walker.cell)


func restore_place() -> bool:
	if progress == null or progress.world_zone == "":
		return false
	var id: String = str(progress.world_zone)
	var cell: Vector2i = progress.world_cell
	if map != null and map.zone(id) == null:
		return false
	enter_zone(id, cell, false)
	return zone != null and zone.zone_id == id and walker.cell == cell


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


func _blend_region_look() -> void:
	_push_region_look(false)


func _apply_region_look() -> void:
	_push_region_look(true)


func _push_region_look(snap: bool) -> void:
	var look := _region_stand_in(zone.region)
	var pool: Array = ["clear"]
	if look.has("weather") and typeof(look["weather"]) == TYPE_ARRAY:
		pool = look["weather"]
	elif zone.presentation.has("default_weather"):
		pool = zone.presentation["default_weather"]
	weather.set_zone_pool(pool)
	if snap:
		weather.settle()
	if fx == null:
		return
	var mat: Variant = fx.get("_grade_mat")
	if mat == null:
		return
	var grade: Dictionary = look.get("grade", {})
	var shader := mat as ShaderMaterial
	if shader == null:
		return
	var target := _grade_params(grade)
	if snap:
		_write_grade(shader, target)
		return
	var from := _read_grade(shader)
	if _presence_tween != null and is_instance_valid(_presence_tween):
		_presence_tween.kill()
	_presence_tween = create_tween()
	_presence_tween.tween_method(func(u: float): _write_grade(shader, _lerp_grade(from, target, u)), 0.0, 1.0, PRESENCE_SECONDS)


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
	var danger_word := "danger" if danger else "safe"
	_hud_label.text = "%s\nCell %d, %d   height %d\n%s   %s\nWeather: %s   %s%s\nMusic: %s\nClick to walk · Shift or double-click to run · R run%s · Esc visuals" % [
		Pick.zone_name(zone), c.x, c.y, zone.height_at(c),
		level_band, danger_word,
		str(weather.weather).replace("_", " "), weather.clock_text(), speed,
		music_id, " (on)" if run_mode else "",
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
	if neighbours == null:
		return
	for host in neighbours.get_children():
		var ground_node: Node = host.get_meta("ground", null)
		if ground_node != null and is_instance_valid(ground_node) and ground_node.has_method("redraw_all"):
			ground_node.redraw_all()
		var props := host.get_node_or_null("Props")
		if props == null:
			continue
		for p in props.get_children():
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
	if neighbours == null:
		return
	for host in neighbours.get_children():
		var decor := host.get_node_or_null("Decor")
		if decor == null:
			continue
		decor.visible = show_root
		for d in decor.get_children():
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
		elif args[i] == "--class" and i + 1 < args.size():
			_launch_class = str(args[i + 1])


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
	if mode == "granary" or mode == "granary_stills":
		# The run swaps scenes; the world comes back and finishes the movie.
		if not _door_outcome.is_empty():
			await _movie_granary_return()
			get_tree().quit()
			return
		if mode == "granary_stills":
			await _movie_granary_stills()
			get_tree().quit()
			return
		await _movie_granary()
		return
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
		"hero_speed":
			await _movie_hero_speed()
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
		"locked_s":
			await _movie_locked_s()
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
		"regions_off":
			await _movie_regions_off()
		"wp12":
			await _movie_wp12()
		"outskirts":
			await _movie_outskirts()
		"eastmarch_still":
			await _movie_eastmarch_still()
		"plane_still":
			await _movie_plane_still()
		"crag_still":
			await _movie_crag_still()
		"water_stills":
			await _movie_water_stills()
		"northgate_snow":
			await _movie_northgate_snow()
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
			# A warm grass dapple reads as a yellow stain on snow.
			if ground != null and ground.cover_at(spot) >= 0.5:
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
	Regions.set_enabled(true)
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
	Regions.set_enabled(true)
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
	Regions.set_enabled(true)
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
	Regions.set_enabled(true)
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
	Regions.set_enabled(true)
	settings.apply_preset("Full")
	_set_zoom(1.45)
	weather.auto_rotate = false
	weather.time_of_day = 12.0
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp6fix")
	DirAccess.make_dir_recursive_absolute(folder)
	await _save_still("gloomfen_mire_entry", Vector2i(8, 8), folder.path_join("gloomfen_plates.png"))
	await _save_still("crosshaven_crossroads", Vector2i(20, 17), folder.path_join("crosshaven_square.png"))


## Flag off: the Stoneford gate has no arrow, then a walk to Stoneford and back.
func _movie_regions_off() -> void:
	settings.apply_preset("Full")
	_set_zoom(1.15)
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	walker.playback = 2.0
	if not OS.has_feature("movie"):
		var folder := ProjectSettings.globalize_path("res://docs/pc/media/regions_off")
		DirAccess.make_dir_recursive_absolute(folder)
		Regions.set_enabled(true)
		await _save_still("crosshaven_stoneford", Vector2i(3, 6), folder.path_join("stoneford_gate_on.png"))
		Regions.set_enabled(false)
		await _save_still("crosshaven_stoneford", Vector2i(3, 6), folder.path_join("stoneford_gate_off.png"))
	await enter_zone("crosshaven_crossroads", Vector2i(22, 18), false)
	if _banner != null:
		_banner.modulate.a = 0.0
	await _run_link("crosshaven_road_west")
	await _run_link("crosshaven_stoneford")
	await get_tree().create_timer(0.6).timeout
	await _run_link("crosshaven_road_west")
	await _run_link("crosshaven_crossroads")
	await get_tree().create_timer(0.4).timeout


## Uncut Crossroads → Northgate → Stoneford. The edge still is the same
## camera with the neighbour hidden, then shown. Black fades stay off.
## The debug readout stays hidden. Coast and interior plate stills are saved
## before the walk when this is not the movie writer.
func _movie_wp12() -> void:
	settings.apply_preset("Full")
	_zoom = 1.15
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	_hide_debug_readout()
	if _banner != null:
		_banner.modulate.a = 0.0
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/wp12")
	DirAccess.make_dir_recursive_absolute(folder)
	if not OS.has_feature("movie"):
		await enter_zone("crosshaven_crossroads", Vector2i(20, 2), false)
		walker.facing = "n"
		walker._show_idle()
		camera.position = walker.position
		camera.reset_smoothing()
		neighbours.visible = false
		_backdrop.visible = false
		if _sea != null:
			_sea.color = Color("101820")
			_sea.visible = true
		await get_tree().create_timer(0.4).timeout
		await _grab(folder.path_join("edge_before.png"))
		neighbours.visible = true
		_backdrop.visible = true
		if _sea != null:
			_sea.color = SEA
			_sea.visible = false
		_sync_backdrop(Rect2(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top), _world_pixel_bounds())
		await get_tree().create_timer(0.4).timeout
		await _grab(folder.path_join("edge_after.png"))
		await _grab_plate_stills(folder)
		return
	walker.playback = 2.0
	await _travel("crosshaven_northgate", Vector2i(20, 12))
	await get_tree().create_timer(0.6).timeout
	await _travel("crosshaven_stoneford", Vector2i(16, 16))
	await get_tree().create_timer(0.8).timeout


## Uncut cross-country walk: Stoneford fields into the Northgate crags.
## The hero is already standing in the fields. The debug readout stays hidden.
func _movie_outskirts() -> void:
	settings.apply_preset("Full")
	_zoom = 1.15
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	_hide_debug_readout()
	if tracker != null:
		tracker.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/outskirts")
	DirAccess.make_dir_recursive_absolute(folder)
	if not OS.has_feature("movie"):
		await _grab_theme_still("crosshaven_stoneford_fields", Vector2i(36, 17), folder.path_join("stoneford_fields.png"))
		await _grab_theme_still("crosshaven_northgate", Vector2i(20, 12), folder.path_join("northgate_snow.png"))
		await _grab_theme_still("crosshaven_eastmarch_coves", Vector2i(22, 6), folder.path_join("eastmarch_beach.png"))
		await _grab_theme_still("crosshaven_southbridge_swamp", Vector2i(22, 16), folder.path_join("southbridge_swamp.png"))
		await _grab_theme_still("crosshaven_westwatch_south_blight", Vector2i(18, 16), folder.path_join("westwatch_blight.png"))
		return
	# About 75 s at this pace: fields, crags, beach, swamp, blight.
	walker.playback = 4.0
	walker.facing = "n"
	walker._show_idle()
	await _travel("crosshaven_northgate_crags_far", Vector2i(18, 20))
	await get_tree().create_timer(0.45).timeout
	await _travel("crosshaven_eastmarch_beach", Vector2i(18, 3))
	await get_tree().create_timer(0.45).timeout
	await _travel("crosshaven_southbridge_swamp", Vector2i(22, 16))
	await get_tree().create_timer(0.45).timeout
	await _travel("crosshaven_westwatch_south_blight", Vector2i(18, 16))
	await get_tree().create_timer(0.6).timeout


## Whole island, zoomed out, so the coast outline can sit beside the plate.
func _movie_plane_still() -> void:
	settings.apply_preset("Full")
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	_hide_debug_readout()
	if tracker != null:
		tracker.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
	if walker != null:
		walker.visible = false
	var here := map.start_zone
	if zone != null:
		here = zone.zone_id
	_mount_neighbours(here, true)
	var center := BoardVisualSort.cell_to_local(Vector2i(20, 20))
	if camera != null:
		camera.zoom = Vector2(0.11, 0.11)
		camera.position = center + Vector2(2200, 0)
		camera.reset_smoothing()
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000
	if _backdrop != null:
		_backdrop.visible = true
		_backdrop.set_meta("sea", Rect2(-30000, -30000, 60000, 60000))
		_backdrop.queue_redraw()
	if neighbours != null:
		for host in neighbours.get_children():
			var body := host as Node2D
			if body != null:
				body.visible = true
	await get_tree().create_timer(0.8).timeout
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/outskirts")
	DirAccess.make_dir_recursive_absolute(folder)
	await _grab(folder.path_join("plane_island_raw.png"))


func _movie_crag_still() -> void:
	settings.apply_preset("Full")
	_zoom = 1.15
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	_hide_debug_readout()
	if tracker != null:
		tracker.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/outskirts")
	DirAccess.make_dir_recursive_absolute(folder)
	await _grab_theme_still("crosshaven_northgate_crags_far", Vector2i(18, 20), folder.path_join("crags_far.png"))
	await _grab_theme_still("crosshaven_northgate_crags_west", Vector2i(8, 16), folder.path_join("crags_west.png"))


## Crosshaven river beside Stoneford, and the open water on the Northgate shore.
func _movie_water_stills() -> void:
	settings.apply_preset("Full")
	_zoom = 1.15
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	_hide_debug_readout()
	if tracker != null:
		tracker.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/water")
	DirAccess.make_dir_recursive_absolute(folder)
	await _grab_theme_still("crosshaven_stoneford", Vector2i(10, 16), folder.path_join("crosshaven_river.png"))
	await _grab_theme_still("crosshaven_northgate", Vector2i(16, 8), folder.path_join("northgate_shore.png"))
	_zoom = 1.0
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	await _grab_theme_still("crosshaven_northgate", Vector2i(16, 8), folder.path_join("northgate_shore_zoom_1.png"))
	_zoom = 1.6
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	await _grab_theme_still("crosshaven_northgate", Vector2i(16, 8), folder.path_join("northgate_shore_zoom_1_6.png"))
	_zoom = 1.15
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	var beach := ProjectSettings.globalize_path("res://docs/pc/media/outskirts")
	DirAccess.make_dir_recursive_absolute(beach)
	await _grab_theme_still("crosshaven_eastmarch_coves", Vector2i(22, 6), beach.path_join("eastmarch_beach.png"))
	await _grab_theme_still("crosshaven_eastmarch_coves", Vector2i(22, 6), folder.path_join("eastmarch_beach.png"))
	_zoom = 1.0
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	await _grab_theme_still("crosshaven_eastmarch_coves", Vector2i(22, 6), folder.path_join("eastmarch_beach_zoom_1.png"))
	_zoom = 1.6
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	await _grab_theme_still("crosshaven_eastmarch_coves", Vector2i(22, 6), folder.path_join("eastmarch_beach_zoom_1_6.png"))
	# The north-east lip of Northgate, where the sea meets the map fill.
	_zoom = 1.0
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	await _grab_theme_still("crosshaven_northgate", Vector2i(34, 2), folder.path_join("map_edge_zoom_1.png"))
	_zoom = 1.6
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	await _grab_theme_still("crosshaven_northgate", Vector2i(34, 2), folder.path_join("map_edge_zoom_1_6.png"))


## Northgate square in the snow: stills at zoom 1.0 and 1.6, or (movie writer)
## a short walk through the square with the snowfall on. SNOW_STILLS_DIR and
## SNOW_STILLS_PREFIX pick where the stills go and how they are named.
func _movie_northgate_snow() -> void:
	settings.apply_preset("Full")
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	_hide_debug_readout()
	if tracker != null:
		tracker.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
	var folder := OS.get_environment("SNOW_STILLS_DIR")
	if folder == "":
		folder = ProjectSettings.globalize_path("res://docs/pc/media/northgate_snow")
	var prefix := OS.get_environment("SNOW_STILLS_PREFIX")
	if prefix == "":
		prefix = "after"
	DirAccess.make_dir_recursive_absolute(folder)
	if not OS.has_feature("movie"):
		for z in [1.0, 1.6]:
			_zoom = z
			if camera != null:
				camera.zoom = Vector2.ONE * _zoom
			var tag := "zoom_1" if z == 1.0 else "zoom_1_6"
			await _grab_theme_still("crosshaven_northgate", Vector2i(20, 14), folder.path_join("%s_square_%s.png" % [prefix, tag]))
		# The town edge on the north road, where the snow thins out.
		_zoom = 1.0
		if camera != null:
			camera.zoom = Vector2.ONE * _zoom
		await _grab_theme_still("crosshaven_road_north", Vector2i(12, 2), folder.path_join("%s_town_edge.png" % prefix))
		return
	_zoom = 1.3
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	await enter_zone("crosshaven_northgate", Vector2i(20, 24), false)
	_hide_debug_readout()
	if _banner != null:
		_banner.modulate.a = 0.0
	camera.position = walker.position
	camera.reset_smoothing()
	_sync_snowfall(true)
	await get_tree().create_timer(1.0).timeout
	walker.playback = 1.0
	await _go(Vector2i(20, 13), "walk")
	await _go(Vector2i(14, 12), "walk")
	await get_tree().create_timer(1.0).timeout


func _movie_eastmarch_still() -> void:
	settings.apply_preset("Full")
	_zoom = 1.15
	if camera != null:
		camera.zoom = Vector2.ONE * _zoom
	weather.auto_rotate = false
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.settle()
	_hide_debug_readout()
	if tracker != null:
		tracker.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
	var folder := ProjectSettings.globalize_path("res://docs/pc/media/outskirts")
	DirAccess.make_dir_recursive_absolute(folder)
	await _grab_theme_still("crosshaven_eastmarch_coves", Vector2i(22, 6), folder.path_join("eastmarch_beach.png"))


func _grab_theme_still(zone_id: String, cell: Vector2i, path: String) -> void:
	await enter_zone(zone_id, cell, false)
	_hide_debug_readout()
	if tracker != null:
		tracker.visible = false
	if _banner != null:
		_banner.modulate.a = 0.0
	walker.facing = "s"
	walker._show_idle()
	camera.position = walker.position
	camera.reset_smoothing()
	_sync_snowfall(true)
	await get_tree().create_timer(0.45).timeout
	await _grab(path)


func _hide_debug_readout() -> void:
	if _hud_label != null:
		_hud_label.visible = false


## North coast (sea, breakers, cliffs) and an interior gap with no chunk yet.
func _grab_plate_stills(folder: String) -> void:
	_hide_debug_readout()
	await _frame_world_cell(_field_gap_cell(), Vector2.ZERO)
	await _grab(folder.path_join("plate_fields.png"))
	await enter_zone("crosshaven_northgate", Vector2i(20, 4), false)
	_hide_debug_readout()
	if _banner != null:
		_banner.modulate.a = 0.0
	await _frame_world_cell(_coast_cell(), Vector2(0, -220))
	await _grab(folder.path_join("coast.png"))
	await enter_zone("crosshaven_northgate", Vector2i(20, 12), false)
	_hide_debug_readout()
	if _banner != null:
		_banner.modulate.a = 0.0
	walker.facing = "s"
	walker._show_idle()
	camera.position = walker.position
	camera.reset_smoothing()
	_sync_snowfall(true)
	await get_tree().create_timer(0.45).timeout
	await _grab(folder.path_join("northgate_snow.png"))


func _frame_world_cell(world_cell: Vector2i, nudge: Vector2) -> void:
	camera.position = BoardVisualSort.cell_to_local(world_cell) + nudge
	camera.reset_smoothing()
	_cull_neighbour_hosts()
	await get_tree().create_timer(0.35).timeout


func _coast_cell() -> Vector2i:
	var origin := _origin_of("crosshaven_northgate")
	return origin + Vector2i(20, -6)


func _field_gap_cell() -> Vector2i:
	var origin := _origin_of("crosshaven_crossroads")
	return origin + Vector2i(-4, -8)


func _travel(zone_id: String, cell: Vector2i) -> void:
	walk_to_zone(zone_id, cell, "run")
	var guard := 0
	while (walker.is_moving() or not _route.is_empty() or _transitioning) and guard < 12000:
		await get_tree().process_frame
		guard += 1


func _grab(path: String) -> void:
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	image.save_png(path)


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
	_approach_npc(npc_book.by_id("crossroads_guide"))
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


## Each class walks down-right (east) on the crossroads with the locked S sheet.
func _movie_locked_s() -> void:
	settings.apply_preset("Full")
	_set_zoom(2.3)
	weather.set_weather("clear")
	weather.time_of_day = 12.0
	weather.auto_rotate = false
	weather.settle()
	var classes: Array[String] = ["ironjaw", "gloam", "kestrel", "bastion", "mender"]
	for id in classes:
		_mark(id)
		walker.use_class(id)
		await enter_zone("crosshaven_crossroads", Vector2i(22, 18), false)
		walker.face("e")
		if _banner != null:
			_banner.text = "%s  ·  down-right" % id.capitalize()
			_banner.modulate.a = 1.0
		await get_tree().create_timer(0.45).timeout
		await _cardinal("e", 4, "walk")
		await get_tree().create_timer(0.4).timeout
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


## Crossroads square: walk, then run mode with the stamina bar draining,
## then stand while it refills and hides. About 14 s at 30 fps.
func _movie_hero_speed() -> void:
	settings.apply_preset("Full")
	weather.set_weather("clear")
	weather.settle()
	_set_zoom(1.6)
	enter_zone("crosshaven_crossroads", Vector2i(16, 18), false)
	await get_tree().process_frame
	await _hold_frames(15)
	walk_to(Vector2i(28, 18), "walk")
	await _hold_frames(90)
	set_run_mode(true)
	walk_to(Vector2i(16, 18), "auto")
	for i in 150:
		if not walker.is_moving():
			walk_to(Vector2i(28, 18) if walker.cell.x < 22 else Vector2i(16, 18), "auto")
		await get_tree().process_frame
	set_run_mode(false)
	walker.stop()
	await _hold_frames(180)
	get_tree().quit()


func _hold_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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


# --- Dungeon doors (dungeons.json, spec 4.6) --------------------------------
# A built dungeon stands its entrance building north of the hatch cell (the
# footprint is blocked for walking), shows a hover glow on the hatch, and
# opens the entry panel from the hatch or its Door Keeper. Enter hands the
# run to DungeonLauncher; the world takes the outcome back on load and
# stands the hero on the door cell.

var _door_art_cache: Dictionary = {}


func _art_for(row: Dictionary) -> Dictionary:
	var id := str(row.get("id", ""))
	if _door_art_cache.has(id):
		return _door_art_cache[id]
	var art_path := ""
	var run_path := str(row.get("run", ""))
	if run_path != "" and FileAccess.file_exists(run_path):
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(run_path))
		if typeof(doc) == TYPE_DICTIONARY:
			art_path = str((doc as Dictionary).get("art", ""))
	var man := DungeonArt.manifest(art_path)
	_door_art_cache[id] = man
	return man


func building_size_for(row: Dictionary) -> Vector2i:
	return DungeonArt.building_size(_art_for(row), DungeonBook.DEFAULT_BUILDING)


func _block_dungeon_buildings() -> void:
	if dungeon_book == null or atlas == null:
		return
	for row in dungeon_book.built():
		var zone_id := str((row["door"] as Dictionary)["zone_id"])
		var found = atlas.map_for_chunk(zone_id)
		if found == null:
			continue
		var z: WorldZone = (found as WorldMap).zone(zone_id)
		if z != null:
			z.add_blocked(DungeonBook.building_cells(row, building_size_for(row)))


func _door_cells_in(zone_id: String) -> Dictionary:
	var out := {}
	if dungeon_book == null:
		return out
	for row in dungeon_book.doors_in(zone_id):
		out[DungeonBook.door_cell(row)] = true
		for c in DungeonBook.building_cells(row, building_size_for(row)):
			out[c] = true
	return out


func _sync_doors() -> void:
	if doors_root == null:
		return
	for child in doors_root.get_children():
		child.free()
	door_nodes.clear()
	if dungeon_book == null or zone == null:
		return
	var ids: Array[String] = [zone.zone_id]
	if neighbours != null:
		for host in neighbours.get_children():
			ids.append(str(host.name))
	for zid in ids:
		for row in dungeon_book.doors_in(zid):
			var node := DungeonDoor.new()
			doors_root.add_child(node)
			node.setup(row, _art_for(row), _origin_of(zid))
			door_nodes[str(row["id"])] = node


## The built dungeon whose hatch or building covers this cell, else {}.
func door_at(zone_id: String, cell: Vector2i) -> Dictionary:
	if dungeon_book == null:
		return {}
	for row in dungeon_book.doors_in(zone_id):
		if DungeonBook.door_cell(row) == cell or DungeonBook.building_cells(row, building_size_for(row)).has(cell):
			return row
	return {}


## Walk onto the hatch, then open the entry panel.
func approach_door(dungeon_id: String) -> Dictionary:
	var row: Dictionary = dungeon_book.by_id(dungeon_id) if dungeon_book != null else {}
	if row.is_empty() or zone == null:
		return {"ok": false, "reason": "no_door"}
	var door := DungeonBook.door_cell(row)
	var door_zone := str((row["door"] as Dictionary)["zone_id"])
	if door_zone == zone.zone_id and walker.cell == door and not walker.is_moving():
		open_door_panel(dungeon_id)
		return {"ok": true, "path": [], "length": 0}
	var result: Dictionary
	if door_zone == zone.zone_id:
		result = walk_to(door)
	else:
		result = walk_to_zone(door_zone, door)
	if bool(result.get("ok", false)):
		_pending_door = dungeon_id
	return result


func open_door_panel(dungeon_id: String, keeper_line: String = "") -> void:
	var row: Dictionary = dungeon_book.by_id(dungeon_id) if dungeon_book != null else {}
	if row.is_empty() or door_panel == null:
		return
	if dialogue != null and dialogue.is_open():
		dialogue.close()
	walker.face("n")
	var level := int(progress.level) if progress != null else 1
	door_panel.open_for(row, level, keeper_line)


## A built dungeon's Door Keeper opens the entry panel instead of plain talk,
## unless a mission waits to be accepted or turned in with them.
func _keeper_opens_door(npc_id: String, record: Dictionary) -> bool:
	if dungeon_book == null:
		return false
	var row: Dictionary = dungeon_book.for_keeper(npc_id)
	if row.is_empty() or str(row.get("status", "")) != "built":
		return false
	var view := _mission_view(npc_id)
	if str(view.get("accept_id", "")) != "" or str(view.get("turn_in_id", "")) != "":
		return false
	var lines: Array = record.get("lines", [])
	open_door_panel(str(row["id"]), str(lines[lines.size() - 1]) if not lines.is_empty() else "")
	return true


func _sync_door_hover(z: WorldZone, c: Vector2i) -> void:
	for node in door_nodes.values():
		var door_zone := str((node.dungeon.get("door", {}) as Dictionary).get("zone_id", ""))
		node.set_hovered(z != null and z.zone_id == door_zone and node.covers(c))


func hero_combat_class() -> String:
	if progress != null and SpellKits.is_roster_class(str(progress.hero_class)):
		return str(progress.hero_class)
	var raw := str(walker.class_id) if walker != null else ""
	for cls in SpellKits.LOCKED_ROSTER:
		if raw.begins_with(cls):
			return cls
	return SpellKits.CLASS_KESTREL


func _on_door_enter(dungeon_id: String) -> void:
	var row: Dictionary = dungeon_book.by_id(dungeon_id) if dungeon_book != null else {}
	if row.is_empty():
		return
	var door := DungeonBook.door_cell(row)
	var door_zone := str((row["door"] as Dictionary)["zone_id"])
	if progress != null:
		progress.note_place(door_zone, door)
		progress.save()
	var ctx := {
		"level": int(progress.level) if progress != null else 1,
		"class_id": hero_combat_class(),
		"return_zone": door_zone,
		"return_cell": door,
		"autoplay": _movie == "granary",
		"movie": _movie,
	}
	var started: Dictionary = Launcher.enter(get_tree(), dungeon_id, ctx)
	if not bool(started.get("ok", false)):
		_show_banner("The way down is not open yet.")


## Back from a run: stand on the door cell and show what it paid.
func _take_dungeon_outcome() -> void:
	var back: Dictionary = Launcher.take_outcome()
	if back.is_empty():
		return
	_door_outcome = back
	var zid := str(back.get("return_zone", ""))
	var cell: Vector2i = back.get("return_cell", Vector2i(-1, -1))
	if zid != "" and cell.x >= 0:
		enter_zone(zid, cell, false)
	if missions != null and progress != null:
		missions.reconcile(progress)
		_refresh_marks()
	_refresh_hud()
	var summary: Dictionary = back.get("summary", {})
	var name_text := str(summary.get("name", "The dungeon"))
	if str(back.get("result", "")) == "win":
		_show_banner("%s cleared" % name_text)
		if reward_popup != null:
			reward_popup.show_drop({
				"xp": int(summary.get("xp", 0)),
				"coins": int(summary.get("coins", 0)),
				"items": summary.get("items", []),
			}, progress)
			if is_inside_tree():
				get_tree().create_timer(5.0).timeout.connect(func():
					if is_instance_valid(reward_popup):
						reward_popup.hide_drop())
	else:
		_show_banner("Driven out of %s. No rewards." % name_text)


func dungeon_outcome() -> Dictionary:
	return _door_outcome.duplicate(true)


## Capture: walk from the square to the granary, open the panel, Enter.
func _movie_granary() -> void:
	settings.apply_preset("Full")
	weather.set_weather("clear")
	weather.time_of_day = 11.0
	weather.settle()
	_set_zoom(1.6)
	if zone == null or zone.zone_id != "crosshaven_stoneford":
		await enter_zone("crosshaven_stoneford", Vector2i(16, 16), false)
	_hide_debug_readout()
	_mark("granary_start")
	await get_tree().create_timer(1.2).timeout
	var row: Dictionary = dungeon_book.by_id("old_granary_cellar")
	var door := DungeonBook.door_cell(row)
	_set_hover(zone, door)
	approach_door("old_granary_cellar")
	await _wait_until_stopped()
	await get_tree().create_timer(0.4).timeout
	_mark("granary_panel")
	await get_tree().create_timer(2.6).timeout
	_mark("granary_enter")
	door_panel.press_enter()
	await get_tree().create_timer(30.0).timeout


func _movie_granary_return() -> void:
	_hide_debug_readout()
	_mark("granary_back")
	await get_tree().create_timer(5.5).timeout
	if reward_popup != null:
		reward_popup.hide_drop()
	var row: Dictionary = dungeon_book.by_id("old_granary_cellar")
	var door := DungeonBook.door_cell(row)
	await _go(door + Vector2i(0, 3), "walk")
	await get_tree().create_timer(1.5).timeout
	_mark("granary_end")


## Stills: the granary door with its keeper, then the entry panel.
func _movie_granary_stills() -> void:
	settings.apply_preset("Full")
	weather.set_weather("clear")
	weather.time_of_day = 11.0
	weather.settle()
	_set_zoom(1.9)
	var folder := OS.get_environment("GRANARY_MEDIA")
	if folder == "":
		folder = "user://"
	var row: Dictionary = dungeon_book.by_id("old_granary_cellar")
	var door := DungeonBook.door_cell(row)
	await enter_zone("crosshaven_stoneford", door + Vector2i(1, 3), false)
	_hide_debug_readout()
	await get_tree().create_timer(1.0).timeout
	if _banner != null:
		_banner.modulate.a = 0.0
	_set_hover(zone, door)
	walker.face("n")
	await get_tree().create_timer(0.6).timeout
	await _grab(folder.path_join("01_door_keeper_stoneford.png"))
	approach_door("old_granary_cellar")
	await _wait_until_stopped()
	await get_tree().create_timer(0.8).timeout
	await _grab(folder.path_join("02_entry_panel.png"))
