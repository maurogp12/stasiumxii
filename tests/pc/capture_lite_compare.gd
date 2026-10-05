extends SceneTree

## Performance mode media: one half of the side-by-side clip. Not a test.
## Needs a real GL context. One run per (mode, zone), PNG frames at 960x1080:
##   XDG_DATA_HOME=<scratch> xvfb-run -s "-screen 0 1920x1080x24" godot \
##     --rendering-driver opengl3 --audio-driver Dummy --path . \
##     --resolution 960x1080 --fixed-fps 30 \
##     -s res://tests/pc/capture_lite_compare.gd -- --mode=lite --zone=northgate --out=/tmp/lite_ng
## Then ffmpeg puts full | performance side by side (see the branch notes).
## The readout shows static memory, GPU texture memory and the process RSS.

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const ZONES := {
	"crossroads": {"id": "crosshaven_crossroads", "name": "Crossroads", "a": Vector2i(-1, -1), "b": Vector2i(22, 24)},
	"northgate": {"id": "crosshaven_northgate", "name": "Northgate", "a": Vector2i(20, 14), "b": Vector2i(20, 24)},
}
const WARM_FRAMES := 90

var _mode := "full"
var _zone := "crossroads"
var _out := "/tmp/lite_compare"
var _secs := 9.0
var _w: Node2D
var _readout: Label
var _frame_i := 0
var _grabbing := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--zone="):
			_zone = arg.trim_prefix("--zone=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--secs="):
			_secs = float(arg.trim_prefix("--secs="))
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_go")


func _go() -> void:
	var store := VisualSettings.new()
	store.apply_preset("Full")
	store.performance_prompted = true
	store.set_performance(_mode == "lite")
	_w = WORLD.instantiate()
	_w.instant_transitions = true
	root.add_child(_w)
	await process_frame
	_w.weather.auto_rotate = false
	_w.weather.set_weather("clear")
	_w.weather.time_of_day = 11.0
	_w.weather.time_scale = 0.0
	_w.weather.settle()
	var spec: Dictionary = ZONES.get(_zone, ZONES["crossroads"])
	var a: Vector2i = spec["a"]
	if a.x < 0:
		a = _w.map.zone(str(spec["id"])).spawn
	if _w.zone.zone_id != str(spec["id"]) or _w.walker.cell != a:
		await _w.enter_zone(str(spec["id"]), a, false)
	_w._hide_debug_readout()
	_build_overlay(str(spec["name"]))
	_w.camera.position = _w.walker.position
	_w.camera.reset_smoothing()
	for i in WARM_FRAMES:
		await process_frame
	_refresh_readout()
	_grabbing = true
	RenderingServer.frame_post_draw.connect(_grab)
	var total := int(_secs * 30.0)
	var legs := 0
	var b: Vector2i = spec["b"]
	for i in total:
		if i > 20 and not _w.walker.is_moving():
			_w.walk_to(b if legs % 2 == 0 else a, "walk")
			legs += 1
		if i % 15 == 0:
			_refresh_readout()
		await process_frame
	_grabbing = false
	await process_frame
	print("CAPTURED %s %s frames=%d" % [_mode, _zone, _frame_i])
	quit(0)


func _build_overlay(zone_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var bar := ColorRect.new()
	bar.color = Color(0.06, 0.05, 0.04, 0.78)
	bar.position = Vector2.ZERO
	bar.size = Vector2(4000, 112)
	layer.add_child(bar)
	var title := Label.new()
	title.text = ("FULL ANIMATIONS" if _mode == "full" else "PERFORMANCE MODE") + "  ·  " + zone_name
	title.position = Vector2(18, 10)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.7) if _mode == "full" else Color(0.7, 0.92, 1))
	layer.add_child(title)
	_readout = Label.new()
	_readout.position = Vector2(18, 54)
	_readout.add_theme_font_size_override("font_size", 20)
	_readout.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	layer.add_child(_readout)


func _refresh_readout() -> void:
	if _readout == null:
		return
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var tex_mb := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	_readout.text = "RAM (static) %.0f MB   ·   Textures %.0f MB\nProcess RSS %.0f MB   ·   Nodes %d" % [
		static_mb, tex_mb, _rss_kb() / 1024.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]


static func _rss_kb() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	var kb := -1.0
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("VmRSS:"):
			kb = float(line.trim_prefix("VmRSS:").strip_edges().split(" ")[0])
			break
	f.close()
	return kb


func _grab() -> void:
	if not _grabbing:
		return
	var image := root.get_texture().get_image()
	if image == null:
		return
	image.save_png("%s/f%05d.png" % [_out, _frame_i])
	_frame_i += 1
