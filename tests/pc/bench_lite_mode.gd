extends SceneTree

## Performance mode A/B: memory and frame time in one zone, one mode.
##
## One process per (zone, mode), so each number starts from a clean heap:
##   LITE_MODE=full|lite LITE_ZONE=crossroads|northgate \
##   godot --headless --path . -s res://tests/pc/bench_lite_mode.gd
## Under xvfb with `--rendering-driver opengl3` (not headless) the texture
## memory monitor reads the GPU textures; headless it reads 0.
##
## Frame time follows bench_northgate_walk.gd: pacing off, every frame timed
## on the wall clock, standing still once the ground is warm, then a scripted
## walk with the mouse sweeping the view. Prints one LITE_BENCH line (JSON).
## Run it with XDG_DATA_HOME set to a scratch folder so the settings store
## of the game is left alone.

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const ZONES := {
	"crossroads": ["crosshaven_crossroads", Vector2i(-1, -1), Vector2i(22, 24)],
	"northgate": ["crosshaven_northgate", Vector2i(20, 14), Vector2i(20, 27)],
}
const WARM_FRAMES := 240
const STEADY_FRAMES := 900
const WALK_SECS := 12.0


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var mode := OS.get_environment("LITE_MODE")
	if mode == "":
		mode = "full"
	var zone_key := OS.get_environment("LITE_ZONE")
	if not ZONES.has(zone_key):
		zone_key = "crossroads"
	root.size = Vector2i(1920, 1080)
	OS.low_processor_usage_mode_sleep_usec = 0
	# The store decides the mode before the world loads its first texture.
	var store := VisualSettings.new()
	store.apply_preset("Full")
	store.performance_prompted = true
	store.set_performance(mode == "lite")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	await process_frame
	w.weather.auto_rotate = false
	w.weather.set_weather("clear")
	w.weather.time_of_day = 12.0
	w.weather.settle()
	var spec: Array = ZONES[zone_key]
	var zid := str(spec[0])
	var stand: Vector2i = spec[1]
	if stand.x < 0:
		stand = w.map.zone(zid).spawn
	if w.zone.zone_id != zid or w.walker.cell != stand:
		await w.enter_zone(zid, stand, false)
	w.camera.position = w.walker.position
	w.camera.reset_smoothing()
	for i in WARM_FRAMES:
		await process_frame
	var mem := _memory()
	var t0 := Time.get_ticks_usec()
	for i in STEADY_FRAMES:
		await process_frame
	var steady := float(Time.get_ticks_usec() - t0) / 1000.0 / float(STEADY_FRAMES)
	var walk := await _walk(w, stand, spec[2])
	var after := _memory()
	var out := {
		"mode": mode,
		"zone": zone_key,
		"renderer": RenderingServer.get_current_rendering_driver_name() if DisplayServer.get_name() != "headless" else "headless",
		"steady_ms": snappedf(steady, 0.01),
		"walk_mean_ms": walk["mean"],
		"walk_p99_ms": walk["p99"],
		"walk_frames": walk["n"],
		"mem": mem,
		"mem_after_walk": after,
		"critters": w.fx.critter_count(),
		"npcs": w.npcs_root.get_child_count(),
	}
	print("LITE_BENCH ", JSON.stringify(out))
	w.queue_free()
	await process_frame
	quit(0)


func _memory() -> Dictionary:
	return {
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"texture_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"rss_mb": snappedf(_rss_kb() / 1024.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


static func _rss_kb() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	# /proc files report length 0, so read line by line.
	var kb := -1.0
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("VmRSS:"):
			kb = float(line.trim_prefix("VmRSS:").strip_edges().split(" ")[0])
			break
	f.close()
	return kb


func _walk(w: Node2D, a: Vector2i, b: Vector2i) -> Dictionary:
	var ms: Array = []
	var legs := 0
	var t := 0.0
	var view := Vector2(root.size)
	var end := Time.get_ticks_msec() + int(WALK_SECS * 1000.0)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() < end:
		if not w.walker.is_moving():
			w.walk_to(b if legs % 2 == 0 else a, "run" if (legs / 2) % 2 == 1 else "walk")
			legs += 1
		t += 0.05
		var move := InputEventMouseMotion.new()
		move.position = view * 0.5 + Vector2(cos(t) * view.x * 0.3, sin(t * 1.3) * view.y * 0.3)
		move.global_position = move.position
		root.push_input(move)
		await process_frame
		var now := Time.get_ticks_usec()
		ms.append(float(now - last) / 1000.0)
		last = now
	ms.sort()
	var n := ms.size()
	var mean := 0.0
	for v in ms:
		mean += float(v)
	mean /= maxf(float(n), 1.0)
	return {"mean": snappedf(mean, 0.01), "p99": snappedf(float(ms[mini(n - 1, int(float(n) * 0.99))]) if n > 0 else 0.0, 0.01), "n": n}
