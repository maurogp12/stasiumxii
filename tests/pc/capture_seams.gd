extends SceneTree

## Seam stills (media, not a test). Reads the JSON `survey_seams.gd` writes
## and grabs one 1920x1080 frame per spot with the same camera (zoom 1.0,
## centred on the boundary cell), into `--out`, named by index. Needs GL:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1920x1080 \
##     -s res://tests/pc/capture_seams.gd -- --spots=/tmp/seams.json --list=bounds --out=/tmp/seams

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

var _spots := ""
var _list := "bounds"
var _out := "/tmp/seams"
var _zoom := 1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spots="):
			_spots = arg.trim_prefix("--spots=")
		elif arg.begins_with("--list="):
			_list = arg.trim_prefix("--list=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--zoom="):
			_zoom = float(arg.trim_prefix("--zoom="))
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_go")


func _go() -> void:
	var store := VisualSettings.new()
	store.apply_preset("Full")
	store.mark_performance_prompted()
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	await process_frame
	w.weather.auto_rotate = false
	w.weather.set_weather("clear")
	w.weather.time_of_day = 12.0
	w.weather.time_scale = 0.0
	w.weather.settle()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_spots))
	var spots: Array = doc.get(_list, [])
	for i in spots.size():
		var spot: Dictionary = spots[i]
		var zone_id := str(spot["zone"])
		var z: WorldZone = w.map.zone(zone_id)
		var at := Vector2i(int(spot["cell"][0]), int(spot["cell"][1]))
		var stand := _stand(z, at)
		if w.zone == null or w.zone.zone_id != zone_id or w.walker.cell != stand:
			await w.enter_zone(zone_id, stand, false)
		w._hide_debug_readout()
		if w.tracker != null:
			w.tracker.visible = false
		if w._banner != null:
			w._banner.modulate.a = 0.0
		w.walker.visible = false
		w._zoom = _zoom
		w.camera.zoom = Vector2.ONE * _zoom
		w.camera.position = w.walker.position + BoardVisualSort.cell_to_local(at) - BoardVisualSort.cell_to_local(w.walker.cell)
		w.camera.reset_smoothing()
		for f in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%03d.png" % [_out, i]
		root.get_texture().get_image().save_png(path)
		print("SHOT %s %s %s %s" % [path, zone_id, at, str(spot.get("pair", ""))])
	quit(0)


## Nearest cell the hero may stand on.
func _stand(z: WorldZone, at: Vector2i) -> Vector2i:
	var best := z.spawn
	var best_d := 1 << 30
	for y in z.height:
		for x in z.width:
			var c := Vector2i(x, y)
			if not z.walkable_at(c) or z.blocked_at(c):
				continue
			var d := (c - at).length_squared()
			if d < best_d:
				best_d = d
				best = c
	return best
