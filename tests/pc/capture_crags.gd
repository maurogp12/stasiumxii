extends SceneTree

## Northgate crags stills (before/after the snowy terrain pass). Needs GL:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1920x1080 \
##     -s res://tests/pc/capture_crags.gd -- --out=/tmp/crags --tag=before

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const SHOTS := [
	["crosshaven_northgate_crags_east", Vector2i(18, 16), "east"],
	["crosshaven_northgate_crags_far", Vector2i(18, 20), "far"],
	["crosshaven_northgate_crags_west", Vector2i(36, 16), "west"],
	["crosshaven_northgate_pass", Vector2i(4, 16), "pass"],
]

var _out := "/tmp/crags"
var _tag := "shot"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--tag="):
			_tag = text.trim_prefix("--tag=")
	_go.call_deferred()


func _go() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_out)
	var w: Node2D = WORLD.instantiate()
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
	for shot in SHOTS:
		await w._grab_theme_still(shot[0], shot[1], "%s/%s_%s.png" % [_out, _tag, shot[2]])
		print("CAPTURED ", shot[2])
	quit(0)
