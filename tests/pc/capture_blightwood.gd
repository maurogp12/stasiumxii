extends SceneTree

## Blightwood stills and the walk through the west join.
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1280x720 \
##     -s res://tests/pc/capture_blightwood.gd -- --out=/opt/cursor/artifacts/blightwood
## `--walk` records frames for the 960x540 clip (the window is set to that size).

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Regions := preload("res://backend/world_regions.gd")

const SPOTS := {
	"zone": {"zone": "blightwood_hollow_entry", "hero": Vector2i(16, 12), "cam": Vector2i(16, 12), "zoom": 1.0},
	"heart": {"zone": "blightwood_hollow_door", "hero": Vector2i(6, 6), "cam": Vector2i(4, 4), "zoom": 1.35},
	"join_rowanvale": {"zone": "blightwood_hollow_entry", "hero": Vector2i(2, 16), "cam": Vector2i(3, 16), "zoom": 1.25},
	"join_windmere": {"zone": "blightwood_hollow_entry", "hero": Vector2i(16, 2), "cam": Vector2i(16, 3), "zoom": 1.25},
}

var _out := "/opt/cursor/artifacts/blightwood"
var _walk := false
var _w: Node2D
var _frame_i := 0
var _grabbing := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--walk":
			_walk = true
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_go")


func _go() -> void:
	var store := VisualSettings.new()
	store.apply_preset("Full")
	store.mark_performance_prompted()
	Regions.set_enabled(true)
	_w = WORLD.instantiate()
	_w.instant_transitions = true
	root.add_child(_w)
	await process_frame
	await process_frame
	_w.weather.auto_rotate = false
	_w.weather.set_weather("light_cloud")
	_w.weather.time_of_day = 12.0
	_w.weather.time_scale = 0.0
	_w.weather.settle()
	_w.walker.playback = 1.0
	if _walk:
		DisplayServer.window_set_size(Vector2i(960, 540))
		await process_frame
		await _walk_clip()
	else:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await process_frame
		for name in ["zone", "heart", "join_rowanvale", "join_windmere"]:
			await _still(name)
	quit(0)


func _place(zone_id: String, hero: Vector2i) -> void:
	if _w.zone == null or _w.zone.zone_id != zone_id or _w.walker.cell != hero:
		await _w.enter_zone(zone_id, hero, false)
	_w._hide_debug_readout()
	if _w.tracker != null:
		_w.tracker.visible = false
	if _w._banner != null:
		_w._banner.modulate.a = 0.0
	_w.walker.facing = "s"
	_w.walker._show_idle()


func _cam_at(cell: Vector2i, zoom: float) -> void:
	_w._zoom = zoom
	_w.camera.zoom = Vector2.ONE * zoom
	var hero: Vector2i = _w.walker.cell
	_w.camera.position = _w.walker.position + BoardVisualSort.cell_to_local(cell) - BoardVisualSort.cell_to_local(hero)
	_w.camera.reset_smoothing()


func _still(name: String) -> void:
	var spec: Dictionary = SPOTS[name]
	await _place(str(spec["zone"]), spec["hero"])
	_cam_at(spec["cam"], float(spec["zoom"]))
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])


func _walk_clip() -> void:
	await _place("blightwood_hollow_entry", Vector2i(0, 16))
	_w._zoom = 0.92
	_w.camera.zoom = Vector2.ONE * 0.92
	_w.camera.position = _w.walker.position
	_w.camera.reset_smoothing()
	for _i in 8:
		await process_frame
	_grabbing = true
	RenderingServer.frame_post_draw.connect(_grab)
	# Hold on the west join so the meadow blend, road gap, and towers read,
	# then walk in and around to the Heart. Playback stays 1.
	for _i in 75:
		await process_frame
	var legs := [
		{"zone": "blightwood_hollow_entry", "cell": Vector2i(12, 16), "frames": 150},
		{"zone": "blightwood_hollow_entry", "cell": Vector2i(20, 8), "frames": 140},
		{"zone": "blightwood_hollow_entry", "cell": Vector2i(14, 22), "frames": 140},
		{"zone": "blightwood_hollow_door", "cell": Vector2i(6, 5), "frames": 160},
	]
	for leg in legs:
		var started := false
		for i in int(leg["frames"]):
			if not started and (i == 2 or (not _w.walker.is_moving() and i > 4)):
				var result: Dictionary = _w.walk_to_zone(str(leg["zone"]), leg["cell"], "walk")
				print("LEG %s %s ok=%s" % [leg["zone"], leg["cell"], result.get("ok", false)])
				started = true
			await process_frame
	_grabbing = false
	await process_frame
	print("WALK frames=%d" % _frame_i)


func _grab() -> void:
	if not _grabbing:
		return
	var image := root.get_texture().get_image()
	if image == null:
		return
	if image.get_width() != 960 or image.get_height() != 540:
		image = image.duplicate()
		image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var frames := _out.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames)
	image.save_jpg("%s/f%05d.jpg" % [frames, _frame_i], 0.92)
	_frame_i += 1
