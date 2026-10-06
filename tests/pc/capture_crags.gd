extends SceneTree

## Northgate crags stills (before/after the snowy terrain pass). Needs GL:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1920x1080 \
##     -s res://tests/pc/capture_crags.gd -- --out=/tmp/crags --tag=before
## Walk clip frames (JPG, 30 fps game time; encode with ffmpeg afterwards):
##   xvfb-run ... godot ... --fixed-fps 30 -s res://tests/pc/capture_crags.gd \
##     -- --mode=walk --out=/tmp/crags_walk
##   ffmpeg -framerate 30 -i /tmp/crags_walk/f%05d.jpg -c:v libx264 -crf 24 \
##     -pix_fmt yuv420p crags_walk.mp4

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const SHOTS := [
	["crosshaven_northgate_crags_east", Vector2i(18, 16), "east"],
	["crosshaven_northgate_crags_far", Vector2i(18, 20), "far"],
	["crosshaven_northgate_crags_west", Vector2i(36, 16), "west"],
	["crosshaven_northgate_pass", Vector2i(4, 16), "pass"],
]

## East crags along the trodden path, past the pond and the tower terrace,
## then over the seam into the far crags.
const WALK := [
	["crosshaven_northgate_crags_east", Vector2i(10, 14)],
	["crosshaven_northgate_crags_east", Vector2i(18, 16)],
	["crosshaven_northgate_crags_east", Vector2i(20, 21)],
	["crosshaven_northgate_crags_east", Vector2i(26, 23)],
	["crosshaven_northgate_crags_east", Vector2i(33, 26)],
	["crosshaven_northgate_crags_far", Vector2i(10, 17)],
]
const MAX_FRAMES := 720

var _out := "/tmp/crags"
var _tag := "shot"
var _mode := "stills"
var _w: Node2D
var _recording := false
var _frame_i := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--tag="):
			_tag = text.trim_prefix("--tag=")
		elif text.begins_with("--mode="):
			_mode = text.trim_prefix("--mode=")
	_go.call_deferred()


func _go() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_out)
	var w: Node2D = WORLD.instantiate()
	_w = w
	w.instant_transitions = true
	root.add_child(w)
	await process_frame
	await process_frame
	w.settings.apply_preset("Full")
	w.weather.auto_rotate = false
	w.weather.time_scale = 0.0
	w.weather.set_weather("clear")
	w.weather.time_of_day = 12.0
	w.weather.settle()
	w._zoom = 1.15
	w.camera.zoom = Vector2.ONE * 1.15
	if _mode == "walk":
		await _walk(w)
		quit(0)
		return
	for shot in SHOTS:
		await w._grab_theme_still(shot[0], shot[1], "%s/%s_%s.png" % [_out, _tag, shot[2]])
		print("CAPTURED ", shot[2])
	quit(0)


func _walk(w: Node2D) -> void:
	await w.enter_zone("crosshaven_northgate_crags_east", Vector2i(2, 13), false)
	w._hide_debug_readout()
	if w.tracker != null:
		w.tracker.visible = false
	w.camera.position = w.walker.position
	w.camera.reset_smoothing()
	for _i in 20:
		await process_frame
	RenderingServer.frame_post_draw.connect(_save_frame)
	_recording = true
	for leg in WALK:
		if _frame_i >= MAX_FRAMES:
			break
		w.walk_to_zone(leg[0], leg[1], "walk")
		var guard := 0
		while (w.walker.is_moving() or not w._route.is_empty() or w._transitioning) and guard < 3000 and _frame_i < MAX_FRAMES:
			if w._banner != null:
				w._banner.modulate.a = 0.0
			await process_frame
			guard += 1
	for _i in 15:
		await process_frame
	_recording = false
	print("WALK frames=", _frame_i)


func _save_frame() -> void:
	if not _recording:
		return
	var image := root.get_texture().get_image()
	image.save_jpg("%s/f%05d.jpg" % [_out, _frame_i], 0.9)
	_frame_i += 1
