extends SceneTree

## Shoreline stills and the beach walk clip (media, not a test).
## Needs a real GL context:
##   XDG_DATA_HOME=<scratch> xvfb-run -s "-screen 0 1920x1080x24" godot \
##     --rendering-driver opengl3 --audio-driver Dummy --path . \
##     --resolution 1920x1080 -s res://tests/pc/capture_shore.gd -- \
##     --spots=saltmaw,docks,southbridge,northgate --out=/tmp/shore --tag=after
## Each spot puts the hero on a fixed cell and the camera on a fixed cell, so
## a before and an after run frame the same ground.
## `--walk` instead walks the Saltmaw beach for `--secs` (default 20) and saves
## JPEG frames at 30 fps into `--out` (ffmpeg makes the clip).
## `--lite` turns Performance mode on.

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
## name: zone, hero cell, camera cell, zoom.
const SPOTS := {
	"saltmaw": {"zone": "crosshaven_eastmarch_sea_caves", "hero": Vector2i(24, 29), "cam": Vector2i(26, 31), "zoom": 1.6},
	"saltmaw_wide": {"zone": "crosshaven_eastmarch_sea_caves", "hero": Vector2i(24, 29), "cam": Vector2i(26, 31), "zoom": 1.0},
	"docks": {"zone": "crosshaven_eastmarch", "hero": Vector2i(26, 22), "cam": Vector2i(27, 22), "zoom": 1.6},
	"coves": {"zone": "crosshaven_eastmarch_coves", "hero": Vector2i(22, 6), "cam": Vector2i(24, 6), "zoom": 1.6},
	"southbridge": {"zone": "crosshaven_southbridge", "hero": Vector2i(8, 23), "cam": Vector2i(10, 25), "zoom": 1.6},
	"northgate": {"zone": "crosshaven_northgate", "hero": Vector2i(7, 7), "cam": Vector2i(7, 6), "zoom": 1.6},
	"crags_east": {"zone": "crosshaven_northgate_crags_east", "hero": Vector2i(8, 4), "cam": Vector2i(10, 3), "zoom": 1.6},
}
const WALK_FROM := Vector2i(27, 3)
const WALK_TO := Vector2i(27, 31)

var _spots: Array[String] = ["saltmaw", "docks", "southbridge", "northgate"]
var _out := "/tmp/shore"
var _tag := "shot"
var _walk := false
var _lite := false
var _secs := 20.0
var _w: Node2D
var _frame_i := 0
var _grabbing := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spots="):
			_spots.clear()
			for s in arg.trim_prefix("--spots=").split(","):
				_spots.append(s)
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
		elif arg == "--walk":
			_walk = true
		elif arg == "--lite":
			_lite = true
		elif arg.begins_with("--secs="):
			_secs = float(arg.trim_prefix("--secs="))
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_go")


func _go() -> void:
	var store := VisualSettings.new()
	store.apply_preset("Full")
	store.mark_performance_prompted()
	store.set_performance(_lite)
	_w = WORLD.instantiate()
	_w.instant_transitions = true
	root.add_child(_w)
	await process_frame
	_w.weather.auto_rotate = false
	_w.weather.set_weather("clear")
	_w.weather.time_of_day = 12.0
	_w.weather.time_scale = 0.0
	_w.weather.settle()
	if _walk:
		await _walk_clip()
	else:
		for name in _spots:
			await _still(name)
	quit(0)


func _place(zone_id: String, hero: Vector2i) -> void:
	if _w.zone.zone_id != zone_id or _w.walker.cell != hero:
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
	_w.camera.position = _w.walker.position + BoardVisualSort.cell_to_local(cell) - BoardVisualSort.cell_to_local(_w.walker.cell)
	_w.camera.reset_smoothing()


func _still(name: String) -> void:
	var spec: Dictionary = SPOTS[name]
	await _place(str(spec["zone"]), spec["hero"])
	_cam_at(spec["cam"], float(spec["zoom"]))
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s_%s.png" % [_out, name, _tag]
	image.save_png(path)
	print("SHOT ", path)


func _walk_clip() -> void:
	await _place("crosshaven_eastmarch_sea_caves", WALK_FROM)
	_w.camera.position = _w.walker.position
	_w.camera.reset_smoothing()
	for i in 40:
		await process_frame
	_grabbing = true
	RenderingServer.frame_post_draw.connect(_grab)
	var total := int(_secs * 30.0)
	for i in total:
		if i == 5:
			_w.walk_to(WALK_TO, "walk")
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
	image.save_jpg("%s/f%05d.jpg" % [_out, _frame_i], 0.92)
	_frame_i += 1
