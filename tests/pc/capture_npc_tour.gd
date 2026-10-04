extends SceneTree

## NPC media for Mauro (spec 4.5a). Not a test suite; needs a real GL context.
##
## Tour (PNG frames at 1920x1080, then ffmpeg). The window keeps the project
## stretch (960x720 base, expand), so it looks like the game on a 1080p screen:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1920x1080 --fixed-fps 30 \
##     -s res://tests/pc/capture_npc_tour.gd -- --mode=tour --out=/tmp/npc_tour
## Stills (one per role at zoom 1.0 and 1.6, one world pixel per screen pixel):
##   xvfb-run ... godot --rendering-driver opengl3 --audio-driver Dummy --path . \
##     --resolution 1920x1080 -s res://tests/pc/capture_npc_tour.gd -- --mode=stills --out=/tmp/npc_stills
## Scene stills (full 1920x1080 frames): the Eastmarch Ferry Captain seen
## through the faded house in front of him, and the Northgate square in snow:
##   xvfb-run ... -s res://tests/pc/capture_npc_tour.gd -- --mode=scenes --out=docs/pc/media/npcs

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Roam := preload("res://scenes/world/npc/npc_roam.gd")

const TOWNS := [
	{"id": "crosshaven_crossroads", "name": "Crossroads", "band": "Hub"},
	{"id": "crosshaven_stoneford", "name": "Stoneford", "band": "Levels 1–10"},
	{"id": "crosshaven_northgate", "name": "Northgate", "band": "Levels 10–20"},
	{"id": "crosshaven_eastmarch", "name": "Eastmarch", "band": "Levels 20–30"},
	{"id": "crosshaven_southbridge", "name": "Southbridge", "band": "Levels 30–40 · swamp"},
	{"id": "crosshaven_westwatch", "name": "Westwatch", "band": "Levels 40–50 · dark side"},
]
const ROLE_NAMES := {"seer": "Shard Seer"}
const BEHAVIOUR_NAMES := {"post": "stays at post", "patrol": "patrols", "wander": "wanders and works"}
const FPS := 30.0

var _mode := "tour"
var _out := "/tmp/npc_stills"
var _w: Node2D
var _cam_pos := Vector2.ZERO
var _cam_zoom := 1.6
var _follow: Node2D = null
var _follow_lift := -30.0
var _title_bg: ColorRect
var _title: Label
var _band: Label
var _caption: Label
var _caption_bg: PanelContainer
var _driver: Node
var _frame_i := 0
## Optional frame range to write (re-render a damaged stretch of a tour).
var _save_from := 0
var _save_to := 1 << 30
## Overlay space: the visible canvas rect, scaled from a 1920x1080 layout.
var _vs := Vector2(1920, 1080)
var _k := 1.0
var _recording := false


class CamDriver extends Node:
	var tour: Object

	func _process(_delta: float) -> void:
		tour.drive_camera()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--mode="):
			_mode = text.trim_prefix("--mode=")
		elif text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--save-from="):
			_save_from = int(text.trim_prefix("--save-from="))
		elif text.begins_with("--save-to="):
			_save_to = int(text.trim_prefix("--save-to="))
	_go.call_deferred()


func _go() -> void:
	root.size = Vector2i(1920, 1080)
	if _mode == "stills" or _mode == "scenes":
		# 1:1 so "zoom 1.0" means one world pixel per image pixel.
		root.content_scale_size = Vector2i(1920, 1080)
	else:
		DirAccess.make_dir_recursive_absolute(_out)
		RenderingServer.frame_post_draw.connect(_grab)
	_w = WORLD.instantiate()
	_w.instant_transitions = true
	root.add_child(_w)
	_w.weather.auto_rotate = false
	_w.weather.time_scale = 0.0
	_w.weather.set_weather("clear")
	_w.weather.time_of_day = 11.5
	_w.weather.settle()
	_driver = CamDriver.new()
	_driver.tour = self
	_driver.process_priority = 1000
	_w.add_child(_driver)
	_build_overlay()
	await _frames(2)
	if _mode == "stills":
		await _stills()
	elif _mode == "scenes":
		await _scenes()
	else:
		await _tour()
	quit(0)


func _grab() -> void:
	if not _recording:
		return
	if _frame_i < _save_from or _frame_i > _save_to:
		_frame_i += 1
		return
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	image.save_png("%s/f%05d.png" % [_out, _frame_i])
	_frame_i += 1


func drive_camera() -> void:
	if _w == null or _w.camera == null:
		return
	if _follow != null and is_instance_valid(_follow):
		_cam_pos = _follow.global_position + Vector2(0, _follow_lift)
	_w.camera.position = _w.camera.get_parent().to_local(_cam_pos) if _w.camera.get_parent() is Node2D else _cam_pos
	_w.camera.zoom = Vector2.ONE * _cam_zoom
	_hide_hud()


func _hide_hud() -> void:
	if _w._hud_label != null:
		_w._hud_label.visible = false
	if _w._banner != null:
		_w._banner.modulate.a = 0.0
	if _w.tracker != null:
		_w.tracker.visible = false


func _build_overlay() -> void:
	_vs = root.get_visible_rect().size
	_k = _vs.y / 1080.0
	var layer := CanvasLayer.new()
	layer.layer = 60
	root.add_child(layer)
	_title_bg = ColorRect.new()
	_title_bg.color = Color(0.06, 0.05, 0.04, 0.82)
	_title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_title_bg)
	_title = _label(layer, 84, Color(1, 0.94, 0.8))
	_title.position = Vector2(0, 400 * _k)
	_band = _label(layer, 40, Color(0.95, 0.8, 0.45))
	_band.position = Vector2(0, 520 * _k)
	_caption_bg = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.05, 0.85)
	box.border_color = Color(1, 0.92, 0.75, 0.9)
	box.set_border_width_all(maxi(1, int(2 * _k)))
	box.set_content_margin_all(14 * _k)
	_caption_bg.add_theme_stylebox_override("panel", box)
	layer.add_child(_caption_bg)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", int(34 * _k))
	_caption.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	_caption_bg.add_child(_caption)
	_caption_bg.visible = false
	_title_bg.visible = false
	_title.visible = false
	_band.visible = false


func _label(layer: CanvasLayer, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(size * _k))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(_vs.x, 110 * _k)
	layer.add_child(l)
	return l


func _set_caption(text: String) -> void:
	_caption.text = text
	_caption_bg.visible = text != ""
	_caption_bg.reset_size()
	var sz := _caption_bg.get_combined_minimum_size()
	_caption_bg.position = Vector2((_vs.x - sz.x) * 0.5, _vs.y - sz.y - 56.0 * _k)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _seconds(sec: float) -> void:
	await _frames(maxi(1, int(round(sec * FPS))))


func _role_name(role: String) -> String:
	return str(ROLE_NAMES.get(role, role.capitalize()))


func _enter(zid: String) -> WorldZone:
	var crosshaven: WorldMap = _w.atlas.maps["crosshaven"]
	var z: WorldZone = crosshaven.zone(zid)
	_w.enter_zone(zid, z.spawn, false)
	_w.weather.set_weather("clear")
	_w.weather.time_of_day = 11.5
	_w.weather.settle()
	return z


func _tour() -> void:
	_recording = true
	for town in TOWNS:
		var z := _enter(str(town["id"]))
		# Let the routines start so walkers are already out on their rounds.
		for node in _w.npcs_root.get_children():
			for _i in 160:
				node.tick(0.05)
		_follow = null
		_cam_pos = _w.walker.global_position + Vector2(0, -30)
		_cam_zoom = 1.25
		_title.text = str(town["name"])
		_band.text = str(town["band"])
		_title_bg.visible = true
		_title.visible = true
		_band.visible = true
		_set_caption("")
		var steps := int(2.2 * FPS)
		for i in steps:
			var a := 1.0
			if i > steps - 15:
				a = float(steps - i) / 15.0
			_title_bg.modulate.a = a
			_title.modulate.a = a
			_band.modulate.a = a
			await process_frame
		_title_bg.visible = false
		_title.visible = false
		_band.visible = false
		_cam_zoom = 1.6
		var nodes: Array = _w.npcs_root.get_children()
		nodes.sort_custom(func(a, b) -> bool: return (a.home.x + a.home.y) < (b.home.x + b.home.y))
		for node in nodes:
			await _visit(node, 1.8)
		if str(town["id"]) == "crosshaven_crossroads":
			await _talk_scene("crossroads_guide")
		elif str(town["id"]) == "crosshaven_stoneford":
			var farmer: Node2D = _w._npc_node("stoneford_farmer")
			if farmer != null:
				_set_caption("Farmer · walking her round")
				_follow = farmer
				await _seconds(3.0)
			await _talk_scene("stoneford_farmer")
	_set_caption("")
	_recording = false
	print("tour frames: %d" % _frame_i)


func _visit(node: Node2D, hold: float) -> void:
	_follow = null
	var start := _cam_pos
	var who := str(node.display_name)
	var role_name := _role_name(str(node.role))
	if who.findn(role_name) < 0:
		who = "%s · %s" % [who, role_name]
	_set_caption("%s · %s" % [who, str(BEHAVIOUR_NAMES.get(str(node.behaviour), ""))])
	var pan := int(0.45 * FPS)
	for i in pan:
		var t := float(i + 1) / float(pan)
		t = t * t * (3.0 - 2.0 * t)
		_cam_pos = start.lerp(node.global_position + Vector2(0, _follow_lift), t)
		await process_frame
	_follow = node
	await _seconds(hold - 0.45)


func _talk_scene(npc_id: String) -> void:
	var node: Node2D = _w._npc_node(npc_id)
	if node == null:
		return
	_set_caption("Click: %s stops, faces the hero and talks" % str(node.display_name))
	_follow = node
	_w._approach_npc(_w.npc_book.by_id(npc_id))
	var n := 0
	while not _w.dialogue.is_open() and n < int(8.0 * FPS):
		await process_frame
		n += 1
	await _seconds(2.6)
	_w.dialogue.close()
	_set_caption("Dialogue closed: back to the routine")
	await _seconds(1.6)


func _stills() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var done := {}
	var rows: Array = _w.npc_book.all()
	# Crosshaven towns first, then the outer regions for roles not in a town.
	rows.sort_custom(func(a, b) -> bool: return str(a["zone_id"]).begins_with("crosshaven_") and not str(b["zone_id"]).begins_with("crosshaven_"))
	for row in rows:
		var record: Dictionary = row
		var role := str(record["role"])
		if done.has(role):
			continue
		var zid := str(record["zone_id"])
		var map: WorldMap = _w.atlas.map_for_chunk(zid)
		if map == null:
			continue
		_w.enter_zone(zid, map.zone(zid).spawn, false)
		_w.weather.set_weather("clear")
		_w.weather.time_of_day = 11.5
		_w.weather.settle()
		var node: Node2D = _w._npc_node(str(record["id"]))
		if node == null:
			continue
		node.roam_enabled = false
		# Front view as painted (S): no turning toward the hero for the still.
		node._host = null
		node.face("e")
		# The hero stands at the spawn; hide it so it never covers the NPC.
		_w.walker.visible = false
		_follow = node
		for zoom in [1.0, 1.6]:
			_cam_zoom = zoom
			await _frames(6)
			var image := root.get_texture().get_image()
			var half := 170
			var rect := Rect2i(960 - half, 540 - half - 10, half * 2, half * 2)
			var crop := image.get_region(rect)
			crop.save_png("%s/%s_zoom%s.png" % [_out, role, "10" if zoom == 1.0 else "16"])
		done[role] = true
		print("still %s from %s" % [role, str(record["id"])])
	print("stills done: %d roles" % done.size())


func _scenes() -> void:
	var folder := _out
	if folder.begins_with("res://") or not folder.begins_with("/"):
		folder = ProjectSettings.globalize_path("res://" + folder.trim_prefix("res://"))
	DirAccess.make_dir_recursive_absolute(folder)
	# Eastmarch: the hero waits on the square; the house in front of the
	# Ferry Captain fades so he reads through it.
	_enter("crosshaven_eastmarch")
	var captain: Node2D = _w._npc_node("eastmarch_ferry_captain")
	if captain != null:
		captain.roam_enabled = false
		_follow = captain
		_follow_lift = -60.0
		_cam_zoom = 1.3
		await _frames(12)
		_save_full(folder.path_join("eastmarch_ferry_captain_behind_faded_house.png"))
	# Northgate square in the snow with its NPCs.
	_follow = null
	_w.enter_zone("crosshaven_northgate", Vector2i(20, 15), false)
	_w.weather.set_weather("clear")
	_w.weather.time_of_day = 12.0
	_w.weather.settle()
	_w._sync_snowfall(true)
	var elder: Node2D = _w._npc_node("northgate_archivist")
	_cam_pos = elder.global_position + Vector2(0, -20) if elder != null else _w.walker.global_position
	_cam_zoom = 1.15
	await _frames(40)
	_save_full(folder.path_join("northgate_square_snow_npcs.png"))


func _save_full(path: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	image.save_png(path)
	print("scene still %s" % path)
