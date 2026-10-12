extends SceneTree

## Read-only stills of the proposed lake rects. Does not write zone data.
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1280x720 \
##     -s res://tests/pc/capture_lake_spots.gd -- --out=/opt/cursor/artifacts/blightwood_v2

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Regions := preload("res://backend/world_regions.gd")

const SPOTS := [
	{
		"file": "lake_spots_rowanvale.png",
		"zone": "rowanvale_farmland_3",
		"hero": Vector2i(24, 6),
		"cam": Vector2i(24, 5),
		"zoom": 0.72,
		"rect": Rect2i(20, 2, 10, 7),
		"holes": [],
		"tint": Color(0.25, 0.55, 0.85, 0.35),
		"line": Color(0.85, 0.95, 1.0, 0.95),
	},
	{
		"file": "lake_spots_windmere.png",
		"zone": "windmere_outer_3",
		"hero": Vector2i(24, 5),
		"cam": Vector2i(24, 5),
		"zoom": 0.72,
		"rect": Rect2i(20, 2, 10, 6),
		"holes": [Vector2i(22, 3), Vector2i(25, 4), Vector2i(27, 6)],
		"tint": Color(0.55, 0.82, 0.95, 0.38),
		"line": Color(0.9, 0.97, 1.0, 0.95),
	},
]

var _out := "/opt/cursor/artifacts/blightwood_v2"
var _w: Node2D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
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
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	for spec in SPOTS:
		await _still(spec)
	quit(0)


func _still(spec: Dictionary) -> void:
	var zone_id := str(spec["zone"])
	var hero: Vector2i = spec["hero"]
	if _w.zone == null or _w.zone.zone_id != zone_id or _w.walker.cell != hero:
		await _w.enter_zone(zone_id, hero, false)
	_w._hide_debug_readout()
	if _w.tracker != null:
		_w.tracker.visible = false
	if _w._banner != null:
		_w._banner.modulate.a = 0.0
	_w.walker.facing = "s"
	_w.walker._show_idle()
	var cam: Vector2i = spec["cam"]
	var zoom := float(spec["zoom"])
	_w._zoom = zoom
	_w.camera.zoom = Vector2.ONE * zoom
	_w.camera.position = _w.walker.position + BoardVisualSort.cell_to_local(cam) - BoardVisualSort.cell_to_local(hero)
	_w.camera.reset_smoothing()
	var mark := Node2D.new()
	mark.name = "LakeMark"
	mark.z_as_relative = false
	mark.z_index = 4000
	mark.position = _w.ground.position
	var rect: Rect2i = spec["rect"]
	var holes: Array = spec["holes"]
	var tint: Color = spec["tint"]
	var line: Color = spec["line"]
	mark.draw.connect(func():
		for y in rect.size.y:
			for x in rect.size.x:
				var cell := Vector2i(rect.position.x + x, rect.position.y + y)
				_diamond(mark, cell, tint, line)
		for hole in holes:
			_diamond(mark, hole, Color(0.15, 0.35, 0.55, 0.55), Color(1, 1, 1, 1))
	)
	_w.add_child(mark)
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [_out, spec["file"]]
	image.save_png(path)
	print("SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])
	mark.queue_free()


func _diamond(ci: CanvasItem, cell: Vector2i, fill: Color, line: Color) -> void:
	var center := BoardVisualSort.cell_to_local(cell)
	var poly := PackedVector2Array([
		center + Vector2(0, -16),
		center + Vector2(32, 0),
		center + Vector2(0, 16),
		center + Vector2(-32, 0),
	])
	ci.draw_colored_polygon(poly, fill)
	ci.draw_polyline(poly + PackedVector2Array([poly[0]]), line, 1.5)
