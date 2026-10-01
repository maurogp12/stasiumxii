extends Node2D

## Crosshaven open world (PC, `main`). Click-to-walk around one chunk at a time;
## walking onto an exit tile fades into the linked chunk.
##
## Data and walk rules come from Backend: `WorldMap`, `WorldZone`, `WorldWalk`
## (data/world/crosshaven/, docs/world/crosshaven_zone_format.md). This scene
## only draws and animates; it never decides what is walkable on its own.

signal zone_entered(zone_id: String, cell: Vector2i)
signal walk_rejected(reason: String)

const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")
const Ground := preload("res://scenes/world/crosshaven/crosshaven_ground.gd")
const Prop := preload("res://scenes/world/crosshaven/crosshaven_prop.gd")
const Walker := preload("res://scenes/world/crosshaven/crosshaven_walker.gd")
const Weather := preload("res://scenes/world/crosshaven/crosshaven_weather.gd")
const Decor := preload("res://scenes/world/crosshaven/crosshaven_decor.gd")
const Fx := preload("res://scenes/world/crosshaven/crosshaven_fx.gd")
const SettingsPanel := preload("res://ui/visual_settings_panel.gd")

const SEA := Color("2d4f63")
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.5
const FADE_SECONDS := 0.35

## Tests set this so exits swap chunks without waiting on the fade.
@export var instant_transitions := false

var map: WorldMap
var zone: WorldZone
var load_errors: Array = []

var ground: Node2D
var props_root: Node2D
var decor_root: Node2D
var walker: Node2D
var camera: Camera2D
var weather: Node
var settings: VisualSettings
var visuals: CanvasLayer
var fx: Node
var hover_cell := Vector2i(-1, -1)

var _hover: Node2D
var _max_h := 0
var _pending_exit := false
var _transitioning := false
var _hud_label: Label
var _banner: Label
var _fade: ColorRect
var _screen_fx: CanvasLayer
var _zoom := 1.6
var _last_click_ms := 0
var _movie := ""
var _bench: Array[float] = []
var _bench_until := 0.0


func _ready() -> void:
	_read_launch_args()
	if _movie != "":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var sea := ColorRect.new()
	sea.color = SEA
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(sea)

	settings = VisualSettings.new()
	props_root = Node2D.new()
	props_root.name = "Props"
	add_child(props_root)
	decor_root = Node2D.new()
	decor_root.name = "Decor"
	add_child(decor_root)
	settings.bind(self, "decor", _on_decor_flag)

	_hover = Node2D.new()
	_hover.name = "Hover"
	_hover.z_as_relative = false
	_hover.draw.connect(_draw_hover)
	add_child(_hover)

	walker = Walker.new()
	walker.name = "Player"
	walker.arrived.connect(_on_arrived)
	walker.stepped.connect(func(_c): _refresh_hud())
	add_child(walker)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.zoom = Vector2.ONE * _zoom
	add_child(camera)

	_screen_fx = CanvasLayer.new()
	_screen_fx.layer = 5
	add_child(_screen_fx)
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(self, _screen_fx)
	weather.weather_changed.connect(func(_w): _refresh_hud())
	settings.bind(weather, "weather", weather.set_visuals_enabled)
	fx = Fx.new()
	fx.name = "Fx"
	add_child(fx)
	fx.setup(self, settings)
	visuals = SettingsPanel.new()
	visuals.name = "VisualSettings"
	add_child(visuals)
	visuals.setup(settings)

	_build_hud()

	var loaded := WorldMap.load_default()
	if not bool(loaded.get("ok", false)):
		load_errors = loaded.get("errors", [])
		push_error("Crosshaven data failed to load: %s" % [load_errors])
		return
	map = loaded["map"]
	enter_zone(map.start_zone, map.start_cell, false)
	if _movie != "":
		get_tree().process_frame.connect(_start_movie, CONNECT_ONE_SHOT)


func enter_zone(zone_id: String, cell: Vector2i, fade: bool = true) -> void:
	if fade and not instant_transitions:
		_transitioning = true
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
		await tw.finished
	_load_zone(zone_id, cell)
	if fade and not instant_transitions:
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
		await tw2.finished
	_transitioning = false


func _load_zone(zone_id: String, cell: Vector2i) -> void:
	zone = map.zone(zone_id)
	_max_h = Pick.max_height(zone)
	if ground != null:
		ground.free()
	ground = Ground.new()
	ground.name = "Ground"
	add_child(ground)
	move_child(ground, 1)
	ground.setup(zone)
	for child in props_root.get_children():
		child.free()
	for record in zone.props:
		var p := Prop.new()
		props_root.add_child(p)
		p.setup(zone, record)
	for child in decor_root.get_children():
		child.free()
	for record in zone.decor:
		var d := Decor.new()
		decor_root.add_child(d)
		d.setup(zone, record)
	if fx != null:
		fx.restock(zone)
	walker.place(zone, cell)
	hover_cell = Vector2i(-1, -1)
	_hover.queue_redraw()
	var rect := Pick.zone_rect(zone).grow(160)
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.position = walker.position
	camera.reset_smoothing()
	weather.set_zone_pool(zone.presentation.get("default_weather", ["clear"]))
	weather.settle()
	_show_banner(Pick.zone_name(zone))
	_refresh_hud()
	zone_entered.emit(zone.zone_id, cell)


## Click-to-walk to a cell in the current chunk. Returns the WorldWalk result.
func walk_to(target: Vector2i, pace: String = "auto") -> Dictionary:
	if zone == null or _transitioning:
		return {"ok": false, "reason": "busy"}
	var from: Vector2i = walker.anchor_cell()
	if from == target:
		_pending_exit = not zone.exit_link(target).is_empty()
		if _pending_exit and not walker.is_moving():
			_on_arrived(target)
		return {"ok": true, "path": [], "length": 0}
	var result := WorldWalk.find_path(map, zone.zone_id, from, zone.zone_id, target)
	if not bool(result.get("ok", false)):
		walk_rejected.emit(str(result.get("reason", "no_path")))
		return result
	var steps: Array[Vector2i] = []
	var path: Array = result["path"]
	for i in range(1, path.size()):
		steps.append(Vector2i(int(path[i]["x"]), int(path[i]["y"])))
	if pace == "auto":
		var now := Time.get_ticks_msec()
		if _last_click_ms > 0 and now - _last_click_ms < 280:
			pace = "run"
		_last_click_ms = now
	_pending_exit = not zone.exit_link(target).is_empty()
	walker.walk(steps, pace)
	return result


func _on_arrived(cell: Vector2i) -> void:
	_refresh_hud()
	if not _pending_exit:
		return
	_pending_exit = false
	var link := zone.exit_link(cell)
	if link.is_empty():
		return
	var to_cell := Vector2i(int(link["x"]), int(link["y"]))
	var target := str(link["target_zone"])
	var check := WorldWalk.validate_path(map, [
		{"zone_id": zone.zone_id, "x": cell.x, "y": cell.y},
		{"zone_id": target, "x": to_cell.x, "y": to_cell.y},
	])
	if not bool(check.get("ok", false)):
		walk_rejected.emit(str(check.get("reason", "bad_exit")))
		return
	enter_zone(target, to_cell, true)


func cell_at_screen(screen_pos: Vector2) -> Vector2i:
	if zone == null:
		return Vector2i(-1, -1)
	var local := get_canvas_transform().affine_inverse() * screen_pos
	return Pick.pick(zone, to_local(local), _max_h)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(cell_at_screen(event.position))
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if visuals != null and visuals.visible:
					return
				var c := cell_at_screen(event.position)
				if c.x >= 0:
					walk_to(c)
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_zoom * 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom / 1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				weather.cycle_weather()
			KEY_2:
				weather.time_scale = 1.0 if weather.time_scale > 1.0 else 30.0
				_refresh_hud()
			KEY_ESCAPE:
				if visuals != null:
					visuals.toggle()


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2.ONE * _zoom


func _set_hover(c: Vector2i) -> void:
	if c == hover_cell:
		return
	hover_cell = c
	if c.x >= 0:
		_hover.z_index = (c.x + c.y) * BoardVisualSort.TILE_Z_SCALE + 1
	_hover.queue_redraw()


func _draw_hover() -> void:
	if zone == null or hover_cell.x < 0 or not zone.in_bounds(hover_cell):
		return
	var color := Color(0.45, 0.95, 0.5, 0.9)
	if not zone.exit_link(hover_cell).is_empty():
		color = Color(1.0, 0.84, 0.35, 0.95)
	elif not zone.passable_at(hover_cell):
		color = Color(0.95, 0.35, 0.3, 0.9)
	var d := Pick.diamond(hover_cell, float(zone.height_at(hover_cell)))
	var fill := color
	fill.a = 0.22
	_hover.draw_colored_polygon(d, fill)
	_hover.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), color, 2.0)


func _process(delta: float) -> void:
	if _bench_until > 0.0:
		_bench.append(delta)
		if Time.get_ticks_msec() / 1000.0 >= _bench_until:
			_report_bench()
			return
	if walker == null or zone == null:
		return
	camera.position = walker.position
	for p in props_root.get_children():
		p.update_cover(walker.anchor_cell(), walker.position)
	if weather.time_scale > 1.0 or Engine.get_process_frames() % 30 == 0:
		_refresh_hud()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var gear := Button.new()
	gear.text = "Visuals"
	gear.position = Vector2(820, 12)
	gear.pressed.connect(func(): visuals.toggle())
	hud.add_child(gear)
	_hud_label = Label.new()
	_hud_label.position = Vector2(14, 10)
	_hud_label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_hud_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hud_label.add_theme_constant_override("outline_size", 5)
	hud.add_child(_hud_label)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-300, 120)
	_banner.size = Vector2(600, 50)
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_banner.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	hud.add_child(_banner)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_fade)


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _refresh_hud() -> void:
	if _hud_label == null or zone == null:
		return
	var c: Vector2i = walker.cell
	var speed := "  (time x30)" if weather.time_scale > 1.0 else ""
	_hud_label.text = "%s\nCell %d, %d   height %d\nWeather: %s   %s%s\nClick to walk · double-click to run · Esc visuals" % [
		Pick.zone_name(zone), c.x, c.y, zone.height_at(c),
		str(weather.weather).replace("_", " "), weather.clock_text(), speed,
	]


func _on_decor_flag(on: bool) -> void:
	if decor_root != null:
		decor_root.visible = on


func _exit_tree() -> void:
	if settings != null:
		settings.detach()


func _read_launch_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--movie" and i + 1 < args.size():
			_movie = str(args[i + 1])
		elif args[i] == "--bench" and i + 1 < args.size():
			_movie = "bench:" + str(args[i + 1])


func _start_movie() -> void:
	if _movie.begins_with("bench:"):
		_run_bench(_movie.trim_prefix("bench:"))
		return
	await _play_movie(_movie)


func _run_bench(preset_name: String) -> void:
	settings.apply_preset(preset_name)
	weather.set_weather("light_rain" if preset_name == "Full" else "clear")
	weather.settle()
	_set_zoom(1.6)
	var target := _far_cell(18)
	walk_to(target, "run")
	_bench.clear()
	_bench_until = Time.get_ticks_msec() / 1000.0 + 4.0


func _report_bench() -> void:
	_bench_until = 0.0
	if _bench.is_empty():
		print("BENCH empty")
		get_tree().quit()
		return
	var sorted := _bench.duplicate()
	sorted.sort()
	var sum := 0.0
	for d in _bench:
		sum += d
	var avg := sum / float(_bench.size())
	var p95: float = sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))]
	print("BENCH preset=%s frames=%d avg_ms=%.2f p95_ms=%.2f min_fps=%.1f" % [
		settings.preset, _bench.size(), avg * 1000.0, p95 * 1000.0, 1.0 / maxf(p95, 0.0001),
	])
	get_tree().quit()


func _play_movie(mode: String) -> void:
	weather.auto_rotate = false
	match mode:
		"tour":
			await _movie_tour()
		"settings":
			await _movie_settings()
		"gait":
			await _movie_gait(false)
		"slow":
			await _movie_gait(true)
		"decor":
			await _movie_decor()
		"northgate", "stoneford", "eastmarch", "westwatch", "southbridge":
			await _movie_town("crosshaven_" + mode)
		_:
			push_error("unknown movie %s" % mode)
	get_tree().quit()


func _movie_tour() -> void:
	_set_zoom(1.85)
	weather.set_weather("clear")
	weather.settle()
	await _wander(6, "walk")
	weather.set_weather("light_rain")
	await _run_link("crosshaven_road_north")
	await _run_link("crosshaven_northgate")
	await _wander(4, "walk")
	weather.set_weather("light_cloud")
	await _run_link("crosshaven_road_north")
	await _run_link("crosshaven_crossroads")
	await _run_link("crosshaven_road_east")
	await _run_link("crosshaven_eastmarch")
	await _wander(4, "walk")
	weather.set_weather("wind")
	await _run_link("crosshaven_road_east")
	await _run_link("crosshaven_crossroads")
	await _run_link("crosshaven_road_south")
	await _run_link("crosshaven_southbridge")
	await _wander(4, "run")


func _movie_town(zone_id: String) -> void:
	var z: WorldZone = map.zone(zone_id)
	enter_zone(zone_id, z.spawn, false)
	await get_tree().process_frame
	_set_zoom(1.9)
	weather.set_weather("light_cloud")
	weather.settle()
	await _wander(10, "walk")
	await _wander(8, "walk")
	await _wander(8, "run")


func _movie_gait(slow: bool) -> void:
	_set_zoom(2.2)
	walker.playback = 0.32 if slow else 1.0
	weather.set_weather("clear")
	weather.settle()
	if slow:
		await _wander(4, "walk")
		await _wander(3, "run")
		return
	await _wander(8, "walk")
	_set_zoom(1.55)
	await _wander(10, "run")
	await _wander(6, "walk")


func _movie_decor() -> void:
	_set_zoom(1.9)
	weather.set_weather("clear")
	weather.settle()
	await _wander(8, "walk")
	await _run_link("crosshaven_road_north")
	await _wander(4, "run")


func _movie_settings() -> void:
	_set_zoom(1.7)
	weather.set_weather("light_rain")
	weather.settle()
	await _wander(4, "walk")
	visuals.show_panel()
	await get_tree().create_timer(1.2).timeout
	for flag in ["animations", "weather", "post_fx", "sway_shadows", "decor"]:
		settings.set_flag(flag, false)
		await get_tree().create_timer(1.9).timeout
	settings.apply_preset("Full")
	await get_tree().create_timer(2.0).timeout
	settings.apply_preset("Reduced")
	await get_tree().create_timer(2.0).timeout
	settings.apply_preset("Minimal")
	await get_tree().create_timer(2.0).timeout
	settings.apply_preset("Full")
	await get_tree().create_timer(1.4).timeout


func _run_link(target_zone: String) -> void:
	var gate := _exit_toward(target_zone)
	if gate.x < 0:
		return
	await _go(gate, "run")


func _wander(tiles: int, pace: String) -> void:
	var goal := _far_cell(tiles)
	if goal.x < 0:
		return
	await _go(goal, pace)


func _go(target: Vector2i, pace: String) -> void:
	walk_to(target, pace)
	var guard := 0
	while (walker.is_moving() or _transitioning) and guard < 4000:
		await get_tree().process_frame
		guard += 1


func _exit_toward(target_zone: String) -> Vector2i:
	for exit_rec in zone.exits:
		if str(exit_rec["target_zone"]) != target_zone:
			continue
		var link: Dictionary = exit_rec["links"][0]
		var frm: Dictionary = link["from"]
		return Vector2i(int(frm["x"]), int(frm["y"]))
	return Vector2i(-1, -1)


func _far_cell(min_tiles: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1
	var fallback := Vector2i(-1, -1)
	var fallback_d := -1
	var origin: Vector2i = walker.anchor_cell()
	for y in zone.height:
		for x in range(0, zone.width, 2):
			var c := Vector2i(x, y)
			if not zone.passable_at(c) or not zone.exit_link(c).is_empty():
				continue
			var d := absi(c.x - origin.x) + absi(c.y - origin.y)
			if d >= min_tiles and d > best_d and d < min_tiles + 10:
				best_d = d
				best = c
			if d > fallback_d:
				fallback_d = d
				fallback = c
	if best.x >= 0:
		return best
	return fallback
