extends SceneTree

## Walled city stills and the walking clip (media, not a test).
##   XDG_DATA_HOME=<scratch> xvfb-run -a -s "-screen 0 1920x1080x24" godot \
##     --rendering-driver opengl3 --audio-driver Dummy --path . \
##     --resolution 1920x1080 -s res://tests/pc/capture_city.gd -- --out=<dir> [--clip] [--lite]
## Stills: wide view, street, south gate, every gate, bridge deck, behind a
## house (fade), plots P1-P5 (labelled), scale line-up, tower close-ups, night.
## `--clip` saves JPEG frames at 30 fps for the walking clip instead.

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const PlateCity := preload("res://backend/plate_city.gd")

var _out := "/tmp/city"
var _clip := false
var _lite := false
var _w: Node2D
var city
var _frame_i := 0
var _grabbing := false
var _labels: CanvasLayer


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--clip":
			_clip = true
		elif arg == "--lite":
			_lite = true
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
	city = _w.city_data()
	await _w.enter_zone("crosshaven_city", city.spawn(), false)
	_hud_off()
	_labels = CanvasLayer.new()
	_labels.layer = 50
	root.add_child(_labels)
	print("HERO class=%s height_world=%.1f walk_px_s=%.1f" % [_w.walker.class_id, _w.walker._strips.height(), _w.walker.speed_of("walk")])
	_report_crossing()
	if _clip:
		await _walk_clip()
	else:
		await _stills()
	quit(0)


func _hud_off() -> void:
	_w._hide_debug_readout()
	if _w.tracker != null:
		_w.tracker.visible = false
	if _w._banner != null:
		_w._banner.modulate.a = 0.0


func _place(cell: Vector2i, face: String = "s") -> void:
	_w.walker.place(_w.zone, cell)
	_w.walker.facing = face
	_w.walker._show_idle()


func _cam(world: Vector2, zoom: float) -> void:
	_w.camera_hold = true
	_w._zoom = zoom
	_w.camera.zoom = Vector2.ONE * zoom
	_w.camera.position = world
	_w.camera.reset_smoothing()


func _cam_hero(zoom: float, nudge: Vector2 = Vector2.ZERO) -> void:
	_cam(_w.walker.position + nudge, zoom)


func _shot(name: String, frames: int = 30) -> void:
	for i in frames:
		await process_frame
		# The world loop recentres the camera on the hero; hold ours.
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("SHOT ", path)


## Hold the camera: the world's _process sets camera.position each frame.
func _hold(world: Vector2, zoom: float, frames: int, name: String) -> void:
	for i in frames:
		_cam(world, zoom)
		await process_frame
	_cam(world, zoom)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("SHOT ", path)


func _cell_of_plate(p: Vector2) -> Vector2i:
	var wpos: Vector2 = city.plate_to_world(p)
	var u := (wpos.x / 32.0 + wpos.y / 16.0) * 0.5
	var v := (wpos.y / 16.0 - wpos.x / 32.0) * 0.5
	return Vector2i(roundi(u), roundi(v))


func _near_free(c: Vector2i) -> Vector2i:
	var z: WorldZone = _w.zone
	var best := c
	var bd := 1 << 30
	for y in range(c.y - 8, c.y + 9):
		for x in range(c.x - 8, c.x + 9):
			var n := Vector2i(x, y)
			if z.passable_at(n) and (n - c).length_squared() < bd:
				bd = (n - c).length_squared()
				best = n
	return best


func _label(text: String, world: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	_labels.add_child(l)
	l.set_meta("world", world)
	return l


func _place_labels() -> void:
	var xf: Transform2D = _w.get_viewport().get_canvas_transform()
	for l in _labels.get_children():
		(l as Label).position = xf * (l.get_meta("world") as Vector2) - Vector2(30, 20)


func _clear_labels() -> void:
	for l in _labels.get_children():
		l.free()


func _report_crossing() -> void:
	var gates: Array = city.gates()
	var west: Array = []
	var east: Array = []
	for g in gates:
		if str(g["id"]) in ["gate_1", "W"]:
			west = g["cells"]
		if str(g["id"]) in ["gate_2", "E"]:
			east = g["cells"]
	if west.is_empty() or east.is_empty():
		return
	var a := Vector2i(int(west[0][0]), int(west[0][1]))
	var b := Vector2i(int(east[0][0]), int(east[0][1]))
	var r: Dictionary = WorldWalk.find_path(city.map, "crosshaven_city", a, "crosshaven_city", b)
	var px := 0.0
	var prev := BoardVisualSort.cell_to_local(a)
	for step in r.get("path", []):
		var p := BoardVisualSort.cell_to_local(Vector2i(int(step["x"]), int(step["y"])))
		px += prev.distance_to(p)
		prev = p
	var walk: float = _w.walker.speed_of("walk")
	var run: float = _w.walker.speed_of("run")
	print("CROSSING west gate -> east gate: %d cells, %.0f px, walk %.1f s, run %.1f s" % [(r.get("path", []) as Array).size(), px, px / walk, px / run])


func _stills() -> void:
	var z: WorldZone = _w.zone
	var plate = _w.city_plate
	# Wide: the whole plate.
	var rect: Rect2 = city.world_rect()
	_place(city.spawn())
	var vp: Vector2 = _w.get_viewport().get_visible_rect().size
	print("VIEWPORT logical %s" % vp)
	await _hold(rect.get_center(), vp.x / rect.size.x, 40, "01_wide_city")
	# Street by the market.
	var market := Vector2.ZERO
	for row in plate.rows:
		if str(row["tag"]) == "stall":
			market = (row["rect"] as Rect2).get_center()
			break
	var street := _near_free(_cell_of_plate(city.world_to_plate(market + Vector2(0, 140))))
	_place(street)
	await _hold(_w.walker.position, 1.6, 40, "02_hero_street")
	# South gate: hero in the arch.
	var gcells: Array = city.gates()[0]["cells"]
	var mid: Array = gcells[gcells.size() / 2]
	_place(Vector2i(int(mid[0]), int(mid[1])), "n")
	await _hold(_w.walker.position + Vector2(0, -40), 1.6, 40, "03_hero_south_gate")
	# Bridge: hero on the deck crown.
	var b0: Dictionary = city.bridges()[0]
	var top := Vector2i(-1, -1)
	var th := -1
	for c in b0["deck_cells"]:
		var cc := Vector2i(int(c[0]), int(c[1]))
		if z.height_at(cc) > th:
			th = z.height_at(cc)
			top = cc
	_place(top, "e")
	await _hold(_w.walker.position, 1.6, 40, "04_hero_bridge")
	# Behind a house: fade.
	var behind := _behind_house()
	if behind.x >= 0:
		_place(behind, "n")
		await _hold(_w.walker.position + Vector2(0, -30), 1.6, 50, "05_hero_behind_house_fade")
	# Plots, labelled.
	var anchors: Array = []
	var centre := Vector2.ZERO
	for p in city.plots():
		var wp: Vector2 = city.plate_to_world(Vector2(float(p["anchor_px"][0]), float(p["anchor_px"][1])))
		anchors.append([p, wp])
		centre += wp
	centre /= float(anchors.size())
	centre += Vector2(110, 0)
	_place(_near_free(_cell_of_plate(city.world_to_plate(centre))))
	for pair in anchors:
		var p: Dictionary = pair[0]
		_label("%s %s" % [p["id"], p["tier"]], pair[1] + Vector2(0, 20))
	for i in 40:
		_cam(centre + Vector2(0, -80), 0.72)
		await process_frame
		_place_labels()
	await _hold(centre + Vector2(0, -80), 0.72, 2, "06_plots_p1_p5")
	_clear_labels()
	# Scale line-up at the default zoom: hero by a house, a gate tower, a stall.
	await _scale_shots()
	# Every gate (contact sheet source).
	for g in city.gates():
		var cells: Array = g.get("cells", [])
		if cells.is_empty():
			continue
		# Hero just outside the arch, so the gatehouse is not faded over him.
		var poly := PackedVector2Array()
		for q in city.doc["wall_polygon"]:
			poly.append(Vector2(float(q[0]), float(q[1])))
		var a := Vector2i(int(cells[0][0]), int(cells[0][1]))
		var b := Vector2i(int(cells[cells.size() - 1][0]), int(cells[cells.size() - 1][1]))
		if Geometry2D.is_point_in_polygon(city.world_to_plate(BoardVisualSort.cell_to_local(a)), poly):
			var t := a
			a = b
			b = t
		_place(_near_free(a - (b - a) / maxi(1, (b - a).length() as int) * 3))
		await _hold(city.plate_to_world(Vector2(float(g["arch"][0]), float(g["arch"][1]))) + Vector2(0, -60), 1.1, 30, "07_gate_%s" % g["id"])
	# Towers after the stub cut.
	for row in plate.rows:
		if str(row["tag"]) in ["tower", "tower_g"] and int(row["id"]) in [382, 383, 392]:
			await _hold((row["rect"] as Rect2).get_center() + Vector2(0, 40), 1.6, 25, "08_tower_%d" % int(row["id"]))
	# Night.
	_w.weather.time_of_day = 22.5
	_w.weather.settle()
	_w._sync_city_life()
	_place(street)
	await _hold(_w.walker.position, 1.0, 50, "09_night_market")
	_w.weather.time_of_day = 12.0
	_w.weather.settle()
	_w._sync_city_life()


func _behind_house() -> Vector2i:
	var z: WorldZone = _w.zone
	var plate = _w.city_plate
	for row in plate.rows:
		if str(row["tag"]) != "house":
			continue
		var r: Rect2 = row["rect"]
		var sy: float = city.plate_to_world(Vector2(0, float(row["sort_y"]))).y
		for y in z.height:
			for x in z.width:
				var c := Vector2i(x, y)
				if not z.passable_at(c):
					continue
				var p := BoardVisualSort.cell_to_local(c)
				if r.has_point(p - Vector2(0, 30)) and p.y < sy - 30.0 and p.y > r.position.y + 70.0 \
						and plate._mask_hits(row, Rect2(p.x - 13, p.y - 58, 26, 54)):
					return c
	return Vector2i(-1, -1)


func _scale_shots() -> void:
	var plate = _w.city_plate
	var tower: Rect2
	var house: Rect2
	var stall: Rect2
	for row in plate.rows:
		var t := str(row["tag"])
		if t == "gate_back" and tower.size == Vector2.ZERO:
			tower = row["rect"]
		elif t == "house" and house.size == Vector2.ZERO:
			house = row["rect"]
		elif t == "stall" and stall.size == Vector2.ZERO:
			stall = row["rect"]
	var h: float = _w.walker._strips.height()
	var i := 0
	for pair in [["house", house], ["gate_tower", tower], ["stall", stall]]:
		var r: Rect2 = pair[1]
		var foot := Vector2(r.end.x + 20, r.end.y - 10)
		_place(_near_free(_cell_of_plate(city.world_to_plate(foot))))
		print("SCALE %s sprite_h=%.0f hero_h=%.1f ratio=%.2f" % [pair[0], r.size.y, h, r.size.y / h])
		await _hold(_w.walker.position + Vector2(-60, -90), 1.6, 30, "10_scale_%d_%s" % [i, pair[0]])
		i += 1


func _walk_clip() -> void:
	# Every gate (out and in), the bridges inside the ring, the ring road.
	RenderingServer.frame_post_draw.connect(_grab)
	var legs: Array = []
	var poly := PackedVector2Array()
	for q in city.doc["wall_polygon"]:
		poly.append(Vector2(float(q[0]), float(q[1])))
	for g in city.gates():
		var cells: Array = g.get("cells", [])
		if cells.size() < 2:
			continue
		var outs: Array[Vector2i] = []
		var ins: Array[Vector2i] = []
		for c in cells:
			var cc := Vector2i(int(c[0]), int(c[1]))
			if Geometry2D.is_point_in_polygon(city.world_to_plate(BoardVisualSort.cell_to_local(cc)), poly):
				ins.append(cc)
			else:
				outs.append(cc)
		if outs.is_empty() or ins.is_empty():
			continue
		var o: Vector2i = outs[0]
		var n: Vector2i = ins[0]
		for c in outs:
			for d in ins:
				if (c - d).length_squared() > (o - n).length_squared():
					o = c
					n = d
		var dir := n - o
		legs.append([_near_free(o - dir * 2), _near_free(n + dir * 3), "walk", 8.0, "gate %s" % g["id"]])
	for b in city.bridges():
		var a := _end(b, 0)
		var c := _end(b, 1)
		if _w.zone.passable_at(a) and Geometry2D.is_point_in_polygon(city.world_to_plate(BoardVisualSort.cell_to_local(a)), poly):
			legs.append([a, c, "walk", 8.0, "bridge %s" % b["id"]])
	# Ring road: from the west gate's inside along the ring to the east side.
	_w.camera_hold = false
	_w._zoom = 1.6
	_w.camera.zoom = Vector2.ONE * 1.6
	for leg in legs:
		_place(leg[0])
		_w.camera.position = _w.walker.position
		_w.camera.reset_smoothing()
		for i in 15:
			await process_frame
		_grabbing = true
		var frames := int(float(leg[3]) * 30.0)
		var still := 0
		for i in frames:
			if i == 3:
				var r: Dictionary = _w.walk_to(leg[1], str(leg[2]))
				print("LEG %s %s -> %s: %s" % [leg[4], leg[0], leg[1], r.get("ok", false)])
			await process_frame
			still = still + 1 if (i > 6 and not _w.walker.is_moving()) else 0
			if still > 18:
				break
		_grabbing = false
	print("CLIP frames=%d" % _frame_i)


func _end(b: Dictionary, i: int) -> Vector2i:
	return Vector2i(int(b["ends"][i][0]), int(b["ends"][i][1]))


func _grab() -> void:
	if not _grabbing:
		return
	var image := root.get_texture().get_image()
	if image == null:
		return
	image.save_jpg("%s/f%05d.jpg" % [_out, _frame_i], 0.88)
	_frame_i += 1
