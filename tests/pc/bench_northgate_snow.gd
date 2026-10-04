extends SceneTree

## Northgate snow kit frame time: standing in the square, snow kit off, then on.
## Off is the town as it was (light frost); on is the snow ground, snowy
## cobble, pines, repainted props, window glow and the snowfall layer.
## Cap: on <= off * 1.25.
## xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/bench_northgate_snow.gd

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Ground := preload("res://scenes/world/crosshaven/crosshaven_ground.gd")
const WARMUP := 20
const SAMPLES := 60
const SQUARE := Vector2i(20, 14)

var _ok := true


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	await process_frame
	w.settings.apply_preset("Full")
	w.weather.auto_rotate = false
	w.weather.set_weather("clear")
	w.weather.time_of_day = 12.0
	w.weather.settle()
	for zoom in [1.0, 1.6]:
		w.camera.zoom = Vector2.ONE * zoom
		var off := await _measure(w, false)
		var on := await _measure(w, true)
		var cap := off.x * 1.25
		var ok := on.x <= cap
		_ok = _ok and ok
		var delta := (on.x - off.x) / maxf(off.x, 0.001) * 100.0
		print("SNOW_FRAME zoom=%.1f off_mean_ms=%.3f off_p95_ms=%.3f on_mean_ms=%.3f on_p95_ms=%.3f cap_ms=%.3f delta_pct=%.1f ok=%s samples=%d" % [
			zoom, off.x, off.y, on.x, on.y, cap, delta, str(ok), SAMPLES])
	Ground.snow_kit = true
	print("SNOW_BENCH budget=%s" % str(_ok))
	quit(0 if _ok else 1)


func _measure(w: Node2D, on: bool) -> Vector2:
	Ground.snow_kit = on
	w.enter_zone("crosshaven_northgate", SQUARE, false)
	w.camera.position = w.walker.position
	w.camera.reset_smoothing()
	for i in WARMUP:
		await process_frame
	var samples: Array[float] = []
	var total := 0.0
	for i in SAMPLES:
		var t0 := Time.get_ticks_usec()
		await process_frame
		RenderingServer.force_draw()
		var dt := float(Time.get_ticks_usec() - t0) / 1000.0
		samples.append(dt)
		total += dt
	samples.sort()
	return Vector2(total / float(SAMPLES), samples[int(float(SAMPLES) * 0.95)])
