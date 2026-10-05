extends SceneTree

## Northgate walk frame budget (perf regression bench).
##
## A scripted 20 s walk in Northgate at 1920x1080: the hero walks, then runs,
## between the square and the south road, the townsfolk roam, the snowfall
## is on, and the mouse sweeps the view (hover pick every frame). Every frame
## is timed on the wall clock with the headless frame pacing turned off
## (low_processor_usage_mode_sleep_usec = 0), so with no GPU a frame's time
## is the CPU it spent: _process, physics, and the _draw callbacks that ran
## that frame (ground runs, props, plates). The Performance TIME_PROCESS
## monitor is not used: headless it does not track a frame's own work.
##
## Fails when
##   - any walk frame takes longer than FRAME_BUDGET_MS, or
##   - the walk's p99 frame is over P99_BUDGET_MS, or
##   - standing still in Northgate (snow, NPCs, sea ripple) costs more than
##     STEADY_RATIO times standing still at the Crossroads, or more than
##     STEADY_BUDGET_MS a frame on average.
##
## Budgets are for a headless run on a slow container CPU (a few times
## slower than a desktop) and leave room for a busy machine. Before the fix
## (a1e94a2) every Northgate frame took about 1.15 s: each ripple frame redrew
## 88 ground rows. 100 ms is the spike line from the report: a frame that
## long is a visible hitch even on a fast machine.
##
## Run:
##   godot --headless --path . -s res://tests/pc/bench_northgate_walk.gd
## Optional: BENCH_SECS (walk length, default 20), BENCH_SIZE (e.g. 2560x1440).

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const TOWN := "crosshaven_northgate"
const SQUARE := Vector2i(20, 14)
const SOUTH_ROAD := Vector2i(20, 27)
const FRAME_BUDGET_MS := 100.0
const P99_BUDGET_MS := 25.0
const STEADY_RATIO := 2.0
const STEADY_BUDGET_MS := 5.0
const WARMUP_FRAMES := 30
const STEADY_FRAMES := 1200

var _ok := true


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var size := Vector2i(1920, 1080)
	var asked := OS.get_environment("BENCH_SIZE")
	if asked.contains("x"):
		size = Vector2i(int(asked.get_slice("x", 0)), int(asked.get_slice("x", 1)))
	root.size = size
	var pacing := OS.low_processor_usage_mode_sleep_usec
	OS.low_processor_usage_mode_sleep_usec = 0
	var secs := 20.0
	if OS.get_environment("BENCH_SECS") != "":
		secs = float(OS.get_environment("BENCH_SECS"))
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	await process_frame
	w.settings.apply_preset("Full")
	w.weather.auto_rotate = false
	w.weather.set_weather("clear")
	w.weather.time_of_day = 12.0
	w.weather.settle()

	var cross := await _steady(w, "crosshaven_crossroads", w.map.zone("crosshaven_crossroads").spawn)
	var town := await _steady(w, TOWN, SQUARE)
	var ratio := town / maxf(cross, 0.001)
	var steady_ok := ratio <= STEADY_RATIO and town <= STEADY_BUDGET_MS
	_ok = _ok and steady_ok
	print("STEADY crossroads_mean_ms=%.2f northgate_mean_ms=%.2f ratio=%.2f cap_ratio=%.2f cap_ms=%.1f ok=%s" % [
		cross, town, ratio, STEADY_RATIO, STEADY_BUDGET_MS, str(steady_ok)])

	var walk := await _walk(w, secs, size)
	var times: Array = walk["ms"]
	times.sort()
	var n := times.size()
	var mean := 0.0
	for t in times:
		mean += float(t)
	mean /= maxf(float(n), 1.0)
	var p99 := float(times[mini(n - 1, int(float(n) * 0.99))]) if n > 0 else 0.0
	var worst := float(times[n - 1]) if n > 0 else 0.0
	var over := 0
	for t in times:
		if float(t) > FRAME_BUDGET_MS:
			over += 1
	var walk_ok := n > 0 and over == 0 and p99 <= P99_BUDGET_MS
	_ok = _ok and walk_ok
	print("WALK size=%dx%d secs=%.0f frames=%d legs=%d snow=%.2f npcs=%d mean_ms=%.2f p99_ms=%.2f worst_ms=%.2f over_budget=%d budget_ms=%.0f p99_budget_ms=%.0f ok=%s" % [
		size.x, size.y, secs, n, int(walk["legs"]), float(walk["snow"]), int(walk["npcs"]), mean, p99, worst, over,
		FRAME_BUDGET_MS, P99_BUDGET_MS, str(walk_ok)])
	for spike in walk["spikes"]:
		print("  SPIKE %s" % str(spike))
	print("NORTHGATE_WALK_BENCH budget=%s" % str(_ok))
	w.queue_free()
	await process_frame
	OS.low_processor_usage_mode_sleep_usec = pacing
	quit(0 if _ok else 1)


## Mean frame time (ms) standing still in `zone_id` once the ground is warm.
func _steady(w: Node2D, zone_id: String, cell: Vector2i) -> float:
	await w.enter_zone(zone_id, cell, false)
	w.camera.position = w.walker.position
	w.camera.reset_smoothing()
	for i in WARMUP_FRAMES * 8:
		await process_frame
	var t0 := Time.get_ticks_usec()
	for i in STEADY_FRAMES:
		await process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(STEADY_FRAMES)


func _walk(w: Node2D, secs: float, size: Vector2i) -> Dictionary:
	await w.enter_zone(TOWN, SQUARE, false)
	w.camera.position = w.walker.position
	w.camera.reset_smoothing()
	for i in WARMUP_FRAMES:
		await process_frame
	var ms: Array = []
	var spikes: Array = []
	var legs := 0
	var t := 0.0
	var view := Vector2(size)
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	var last := Time.get_ticks_usec()
	var snow := 0.0
	while Time.get_ticks_msec() < end:
		if not w.walker.is_moving():
			# Walk down and back, then run down and back.
			var target := SOUTH_ROAD if legs % 2 == 0 else SQUARE
			w.walk_to(target, "run" if (legs / 2) % 2 == 1 else "walk")
			legs += 1
		t += 0.05
		var move := InputEventMouseMotion.new()
		move.position = view * 0.5 + Vector2(cos(t) * view.x * 0.3, sin(t * 1.3) * view.y * 0.3)
		move.global_position = move.position
		root.push_input(move)
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000.0
		last = now
		ms.append(dt)
		snow = maxf(snow, float(w.snow_level))
		if dt > FRAME_BUDGET_MS * 0.5:
			spikes.append({"frame": ms.size() - 1, "ms": snappedf(dt, 0.1), "cell": w.walker.cell, "zone": w.zone.zone_id})
	return {"ms": ms, "spikes": spikes, "legs": legs, "snow": snow, "npcs": w.npcs_root.get_child_count()}
