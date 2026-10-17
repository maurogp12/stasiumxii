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
## --only=S,N: the clip walks only these gates.
var _only := ""
## --set=towers: only the tower close-ups.
var _set := ""
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
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
		elif arg.begins_with("--set="):
			_set = arg.trim_prefix("--set=")
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
	if _clip and _set != "r23":
		await _walk_clip()
	elif _set == "towers":
		await _tower_shots()
	elif _set == "audit":
		await _audit_shots()
	elif _set == "round10":
		await _round10_shots()
		await _tower_shots()
	elif _set == "v4":
		await _v4_shots()
	elif _set == "behind":
		await _behind_shots()
	elif _set == "r23" and not _clip:
		await _r23_shots()
	elif _set == "r23" and _clip:
		await _r23_clip()
	else:
		await _stills()
		await _tower_shots()
	quit(0)


## Round 18: Mauro's ring v4 image as the plate. The wide shot frames the
## whole plate (the image's own framing); then the hero at every gate.
func _v4_shots() -> void:
	_w.camera_hold = true
	_w.npc_plates.visible = false
	_w.walker.visible = false
	var rect: Rect2 = city.world_rect()
	var vp: Vector2 = _w.get_viewport().get_visible_rect().size
	await _hold(rect.get_center(), minf(vp.x / rect.size.x, vp.y / rect.size.y), 40, "20_wide_ring_goal")
	# Round 21: the S gate shut (nobody near), then open with the hero in the arch
	for g in city.gates():
		if str(g["id"]) != "S":
			continue
		var aw0: Vector2 = city.plate_to_world(Vector2(float(g["arch"][0]), float(g["arch"][1])))
		_place(_near_free(Vector2i(int(city.doc["spawn"][0]), int(city.doc["spawn"][1]))), "n")
		await _hold(aw0 + Vector2(0, -40), 1.1, 90, "07_gate_S_closed")
		var cs: Array = g.get("cells", [])
		var mid := Vector2i(int(cs[cs.size() / 2][0]), int(cs[cs.size() / 2][1]))
		_w.walker.visible = true
		_place(mid, "n")
		await _hold(aw0 + Vector2(0, -40), 1.1, 40, "07_gate_S_open")
		_w.walker.visible = false
	_w.walker.visible = true
	for g in city.gates():
		if _only != "" and not (str(g["id"]) in _only.split(",")):
			continue
		var cells: Array = g.get("cells", [])
		if cells.is_empty():
			continue
		var out_c := Vector2i(int(cells[0][0]), int(cells[0][1]))
		var arch_w: Vector2 = city.plate_to_world(Vector2(float(g["arch"][0]), float(g["arch"][1])))
		_place(_near_free(out_c), "n")
		await _hold(arch_w + Vector2(0, -40), 1.1, 30, "07_gate_%s" % g["id"])
		var under := out_c
		for c in cells:
			var cc := Vector2i(int(c[0]), int(c[1]))
			if BoardVisualSort.cell_to_local(cc).distance_to(arch_w) < BoardVisualSort.cell_to_local(under).distance_to(arch_w):
				under = cc
		_place(under, "n")
		await _hold(_w.walker.position + Vector2(0, -60), 1.8, 30, "14_arch_close_%s" % g["id"])
		await _hold(arch_w + Vector2(0, -40), 1.1, 10, "31_gate_%s_open" % g["id"])
		var in_c := Vector2i(int(cells[cells.size() - 1][0]), int(cells[cells.size() - 1][1]))
		_place(_near_free(in_c), "s")
		await _hold(_w.walker.position + Vector2(0, -60), 1.8, 30, "14_inside_%s" % g["id"])
	# Round 20: a tower at 100% (one plate px per screen px)
	_w.walker.visible = false
	for rec in city.layers():
		if str(rec["tag"]) == "tower" and str(rec.get("name", "")) == "S_left":
			var tc := Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["y"]) + float(rec["h"]) * 0.5)
			await _hold(city.plate_to_world(tc), 1.0 / city.scale(), 20, "34_tower_100pct")
	_w.walker.visible = true
	# Round 19: the gates by night (warm glow at each mouth)
	_w.weather.time_of_day = 22.5
	for g in city.gates():
		if str(g["id"]) in ["S", "W"]:
			var aw: Vector2 = city.plate_to_world(Vector2(float(g["arch"][0]), float(g["arch"][1])))
			var cells2: Array = g.get("cells", [])
			_place(_near_free(Vector2i(int(cells2[0][0]), int(cells2[0][1]))), "n")
			await _hold(aw + Vector2(0, -40), 1.1, 30, "33_gate_%s_night" % g["id"])
	_w.weather.time_of_day = 12.0
	_w.npc_plates.visible = true
	_w.camera_hold = false


func _building_at(id: String) -> Dictionary:
	for rec in city.layers():
		if str(rec.get("building", "")) == id:
			return rec
	return {}


func _rec_centre(rec: Dictionary) -> Vector2:
	return city.plate_to_world(Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["y"]) + float(rec["h"]) * 0.55))


## Round 23: the town. Wide, then the castle, cathedral, plaza, crafts
## quarter and a player plot, each with the hero beside it for scale.
func _r23_shots() -> void:
	_w.camera_hold = true
	_w.npc_plates.visible = false
	_w.walker.visible = false
	var rect: Rect2 = city.world_rect()
	var vp: Vector2 = _w.get_viewport().get_visible_rect().size
	await _hold(rect.get_center(), minf(vp.x / rect.size.x, vp.y / rect.size.y), 40, "20_wide_ring_goal")
	_w.walker.visible = true
	var shots := [["castle", 0.75, "37_castle"], ["cathedral", 0.85, "38_cathedral"], ["fountain", 1.0, "39_plaza"], ["potter", 0.9, "40_crafts_quarter"]]
	for sh in shots:
		var rec := _building_at(str(sh[0]))
		if rec.is_empty():
			continue
		var foot: Vector2 = city.plate_to_world(Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["sort_y"])))
		_place(_near_free(_cell_at_world(foot + Vector2(40, 40))), "n")
		await _hold(_rec_centre(rec), float(sh[1]), 40, str(sh[2]))
	var p: Dictionary = city.plots()[0]
	var a: Vector2 = city.plate_to_world(Vector2(float(p["anchor_px"][0]), float(p["anchor_px"][1])))
	_place(Vector2i(int(p["front_cells"][0][0]), int(p["front_cells"][0][1])), "n")
	await _hold(a + Vector2(0, -120), 1.0, 40, "41_player_plot_%s_%s" % [p["id"], p["tier"]])
	_w.npc_plates.visible = true
	_w.camera_hold = false


func _cell_at_world(world: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var bd := 1e18
	for y in _w.zone.height:
		for x in _w.zone.width:
			var c := Vector2i(x, y)
			var d: float = BoardVisualSort.cell_to_local(c).distance_squared_to(world)
			if d < bd:
				bd = d
				best = c
	return best


## Round 23: a walk through the town: in by the S gate, over the bridge, round
## the plaza, to the crafts quarter.
func _r23_clip() -> void:
	RenderingServer.frame_post_draw.connect(_grab)
	_w.camera_hold = false
	_w._zoom = 1.3
	_w.camera.zoom = Vector2.ONE * 1.3
	var stops: Array = []
	for id in ["fountain", "cathedral", "townhall", "potter"]:
		var rec := _building_at(id)
		if not rec.is_empty():
			stops.append(_near_free(_cell_at_world(city.plate_to_world(Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["sort_y"]) + 40.0)))))
	_place(city.spawn(), "n")
	_w.camera.position = _w.walker.position
	_w.camera.reset_smoothing()
	for i in 15:
		await process_frame
	_grabbing = true
	for st in stops:
		var r: Dictionary = _w.walk_to(st, "walk")
		print("LEG r23 -> %s: %s" % [st, r.get("ok", false)])
		var n := 0
		while n < 1200:
			await process_frame
			n += 1
			if n > 10 and not _w.walker.is_moving():
				break
		for i in 15:
			await process_frame
	_grabbing = false
	print("CLIP frames=%d" % _frame_i)


## Round 22: the hero just inside the S and W gatehouses (behind the wall),
## a few cells deep, to judge the local fade and the door sort from inside.
func _behind_shots() -> void:
	_w.camera_hold = true
	_w.npc_plates.visible = false
	for g in city.gates():
		if not (str(g["id"]) in ["S", "W"]):
			continue
		var cells: Array = g.get("cells", [])
		var a := Vector2i(int(cells[0][0]), int(cells[0][1]))
		var b := Vector2i(int(cells[cells.size() - 1][0]), int(cells[cells.size() - 1][1]))
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var arch_w: Vector2 = city.plate_to_world(Vector2(float(g["arch"][0]), float(g["arch"][1])))
		var mid := Vector2i(int(cells[cells.size() / 2][0]), int(cells[cells.size() / 2][1]))
		var k := 0
		for c in [mid + step, mid + step * 2, mid + step * 3, b - step * 2 + Vector2i(step.y, -step.x) * 2]:
			_place(_near_free(c), "n")
			await _hold(arch_w + Vector2(0, -60), 1.6, 45, "36_behind_%s_%d" % [g["id"], k])
			k += 1
	_w.npc_plates.visible = true
	_w.camera_hold = false


## Round 8: every tower on the NW and SW diagonals (mid-edge and corners),
## framed from the city side and from the outside.
func _tower_shots() -> void:
	_w.camera_hold = true
	_w.walker.visible = false
	var poly: Array = city.doc["wall_polygon"]
	var n := poly.size()
	var centre := Vector2.ZERO
	for q in poly:
		centre += Vector2(float(q[0]), float(q[1]))
	centre /= float(n)
	for e in [5, 4]:
		var a := Vector2(float(poly[e][0]), float(poly[e][1]))
		var b := Vector2(float(poly[(e + 1) % n][0]), float(poly[(e + 1) % n][1]))
		var k := 0
		for rec in city.layers():
			if str(rec["tag"]) != "tower" or bool(rec.get("hidden", false)):
				continue
			var foot := _tower_foot(rec)
			var t: float = clampf((foot - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if foot.distance_to(a.lerp(b, t)) > 20.0:
				continue
			var mid: Vector2 = (a + b) * 0.5
			var inward: Vector2 = (centre - mid).normalized()
			var name := "15_tower_%s_%d" % ["NW" if e == 5 else "SW", k]
			await _hold(city.plate_to_world(foot + inward * 140.0) + Vector2(0, -110), 1.6, 25, name + "_inside")
			await _hold(city.plate_to_world(foot - inward * 140.0) + Vector2(0, -110), 1.6, 25, name + "_outside")
			k += 1
	# Round 9: the ring corner towers (where a flat run meets a diagonal).
	for rec in city.layers():
		if str(rec["tag"]) != "tower" or not bool(rec.get("corner", false)):
			continue
		var cf := _tower_foot(rec)
		var tag := ("N" if cf.y < centre.y else "S") + ("E" if cf.x > centre.x else "W")
		await _hold(city.plate_to_world(cf) + Vector2(0, -130), 1.4, 25, "17_corner_%s" % tag)
	_w.walker.visible = true
	_w.camera_hold = false


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
	_w.npc_plates.visible = false
	print("VIEWPORT logical %s" % vp)
	await _hold(rect.get_center(), vp.x / rect.size.x, 40, "01_wide_city")
	# Street by the market.
	var market := Vector2.ZERO
	for row in plate.rows:
		if str(row["tag"]) == "stall":
			market = (row["rect"] as Rect2).get_center()
			break
	_w.npc_plates.visible = true
	if market == Vector2.ZERO:
		market = city.plate_to_world(Vector2(2420, 1340))
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
		_cam(centre + Vector2(0, -80), 0.6)
		await process_frame
		_place_labels()
	await _hold(centre + Vector2(0, -80), 0.6, 2, "06_plots_p1_p10")
	_clear_labels()
	# Map base: plots and building footprints reserved, empty (F9 overlay).
	plate.set_footprints_visible(true)
	_w.npc_plates.visible = false
	var rect2: Rect2 = city.world_rect()
	var vp2: Vector2 = _w.get_viewport().get_visible_rect().size
	await _hold(rect2.get_center(), vp2.x / rect2.size.x, 20, "11_footprints_overlay_wide")
	await _hold(centre + Vector2(0, -80), 0.6, 20, "12_plots_overlay")
	plate.set_footprints_visible(false)
	_w.npc_plates.visible = true
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
		if true:
			# Close-up: the hero under the arch (the cell nearest the arch point).
			var arch_w: Vector2 = city.plate_to_world(Vector2(float(g["arch"][0]), float(g["arch"][1])))
			var under := Vector2i(int(cells[0][0]), int(cells[0][1]))
			for c in cells:
				var cc := Vector2i(int(c[0]), int(c[1]))
				if BoardVisualSort.cell_to_local(cc).distance_to(arch_w) < BoardVisualSort.cell_to_local(under).distance_to(arch_w):
					under = cc
			_place(under)
			await _hold(_w.walker.position + Vector2(0, -50), 2.0, 30, "14_arch_close_%s" % g["id"])
	# Towers after the stub cut.
	var t_n := 0
	for row in plate.rows:
		if str(row["tag"]) in ["tower", "tower_g"] and t_n < 3:
			await _hold((row["rect"] as Rect2).get_center() + Vector2(0, 40), 1.1, 25, "08_tower_%d" % int(row["id"]))
			t_n += 1
	# Night.
	_w.weather.time_of_day = 22.5
	_w.weather.settle()
	_w._sync_city_life()
	_place(street)
	await _hold(_w.walker.position, 1.0, 50, "09_night_market")
	_w.weather.time_of_day = 12.0
	_w.weather.settle()
	_w._sync_city_life()
	# Woods close-up: the densest clump outside the walls (round 3).
	var feet: Array[Vector2] = []
	for rec in city.layers():
		if str(rec.get("spot", "")) == "outer_forest":
			feet.append(Vector2(float(rec["x"]) + float(rec["w"]) * float(rec.get("k", 1.0)) * 0.5, float(rec["sort_y"])))
	var best := Vector2.ZERO
	var best_n := -1
	for f in feet:
		var n := 0
		for g in feet:
			if f.distance_to(g) < 320.0:
				n += 1
		if n > best_n:
			best_n = n
			best = f
	if best_n > 0:
		await _hold(city.plate_to_world(best + Vector2(0, -60)), 0.75, 40, "13_woods_close")


func _behind_house() -> Vector2i:
	var z: WorldZone = _w.zone
	var plate = _w.city_plate
	for row in plate.rows:
		if not (str(row["tag"]) in ["house", "wall", "tree"]) or not bool(row["fade"]):
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
		var step := Vector2i(signi(n.x - o.x), signi(n.y - o.y))
		legs.append([_beyond(o, -step, 4), _beyond(n, step, 6), "walk", 7.5, "gate %s" % g["id"]])
	for b in city.bridges():
		var a := _end(b, 0)
		var c := _end(b, 1)
		if _w.zone.passable_at(a) and Geometry2D.is_point_in_polygon(city.world_to_plate(BoardVisualSort.cell_to_local(a)), poly):
			legs.append([a, c, "walk", 8.0, "bridge %s" % b["id"]])
	# Ring road round the centre plaza: street cells at four compass points,
	# walked as two half rings; the second at night (lamps lit).
	var centre := Vector2.ZERO
	for q in poly:
		centre += q
	centre /= float(poly.size())
	var marks: Array[Vector2i] = []
	for dir in [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)]:
		var want: Vector2 = centre + Vector2(dir.x * 560.0, dir.y * 280.0)
		var best := Vector2i(-1, -1)
		var best_d := 1e12
		for y in _w.zone.height:
			for x in _w.zone.width:
				var cc := Vector2i(x, y)
				if _w.zone.terrain_at(cc) != "dirt_road" or not _w.zone.passable_at(cc):
					continue
				var d: float = (city.world_to_plate(BoardVisualSort.cell_to_local(cc)) as Vector2).distance_squared_to(want)
				if d < best_d:
					best_d = d
					best = cc
		marks.append(best)
	# Outer woods: only the roads are walkable outside the ring, so the hero
	# walks out along the west road, then the camera pans along the wall foot
	# woods (NW, then NE edge).
	for g in city.gates():
		if str(g["id"]) == "W" and g.has("exit_cell"):
			var ws: Array = g["cells"]
			var from_c := Vector2i(int(ws[0][0]), int(ws[0][1]))
			var ex := Vector2i(int(g["exit_cell"][0]), int(g["exit_cell"][1]))
			# stop short of the exit stub (it would leave the city)
			var back := Vector2i(signi(from_c.x - ex.x), signi(from_c.y - ex.y))
			var stop := ex
			for k in range(2, 6):
				if _w.zone.passable_at(ex + back * k):
					stop = ex + back * k
					break
			legs.append([from_c, stop, "walk", 7.0, "west road out past the woods"])
	var n_poly := poly.size()
	for pair in [[n_poly - 1, 0], [1, 2]]:
		var pa: Vector2 = poly[pair[0]]
		var pb: Vector2 = poly[pair[1]]
		var out_a: Vector2 = pa + ((pa + pb) * 0.5 - centre).normalized() * 200.0
		var out_b: Vector2 = pb + ((pa + pb) * 0.5 - centre).normalized() * 200.0
		legs.append([city.plate_to_world(out_a.lerp(out_b, 0.12)), city.plate_to_world(out_a.lerp(out_b, 0.88)), "pan", 7.0, "outer woods pan"])
	legs.append([marks[0], marks[2], "walk", 10.0, "ring road west to east (day)"])
	legs.append([marks[2], marks[0], "walk", 10.0, "ring road east to west (night)", 22.0])
	_w.camera_hold = false
	_w._zoom = 1.6
	_w.camera.zoom = Vector2.ONE * 1.6
	if _only != "":
		var keep: Array = []
		for leg in legs:
			for want in _only.split(","):
				if str(leg[4]) == "gate %s" % want:
					keep.append(leg)
		legs = keep
	for leg in legs:
		_w.weather.time_of_day = float(leg[5]) if leg.size() > 5 else 12.0
		if str(leg[2]) == "pan":
			_w.camera_hold = true
			var n_pan := int(float(leg[3]) * 30.0)
			for i in 10:
				_cam(leg[0], 1.1)
				await process_frame
			_grabbing = true
			for i in n_pan:
				_cam((leg[0] as Vector2).lerp(leg[1], float(i) / float(n_pan - 1)), 1.1)
				await process_frame
			_grabbing = false
			_w.camera_hold = false
			_w._zoom = 1.6
			_w.camera.zoom = Vector2.ONE * 1.6
			print("LEG %s pan" % leg[4])
			continue
		_place(leg[0])
		_w._sync_city_life()
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
		if str(leg[4]).begins_with("gate") and _set == "v4":
			# Round 18: hold on the gate while the portcullis drops behind the hero
			_w.camera_hold = true
			for g in city.gates():
				if "gate %s" % g["id"] == str(leg[4]):
					_cam(city.plate_to_world(Vector2(float(g["arch"][0]), float(g["arch"][1]))) + Vector2(0, -40), 1.6)
			for i in 90:
				await process_frame
			_w.camera_hold = false
		_grabbing = false
	print("CLIP frames=%d" % _frame_i)


func _beyond(from: Vector2i, step: Vector2i, n: int) -> Vector2i:
	var best := from
	for k in range(1, n + 1):
		if _w.zone.passable_at(from + step * k):
			best = from + step * k
	return best


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


## A ring tower's point on the wall line (round 8 towers stand in front of it).
func _tower_foot(rec: Dictionary) -> Vector2:
	if rec.has("wall_point"):
		return Vector2(float(rec["wall_point"][0]), float(rec["wall_point"][1]))
	return Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["sort_y"]) - 10.0)


## Round 10: Mauro's framings (water gates, the SE wall, a GOAL-like wide).
func _round10_shots() -> void:
	_w.camera_hold = true
	_w.npc_plates.visible = false
	_w.walker.visible = false
	var poly: Array = city.doc["wall_polygon"]
	var centre := Vector2.ZERO
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for q in poly:
		var v := Vector2(float(q[0]), float(q[1]))
		centre += v
		lo = lo.min(v)
		hi = hi.max(v)
	centre /= float(poly.size())
	for wg in city.doc.get("water_gates", []):
		var at := Vector2(float(wg["at"][0]), float(wg["at"][1]))
		var tag := ("N" if at.y < centre.y else "S") + ("E" if at.x > centre.x else "W")
		if tag == "SW":
			# with the S gate beside it, as in Mauro's screenshot
			var s_arch := at
			for g in city.gates():
				if str(g["id"]) == "S":
					s_arch = Vector2(float(g["arch"][0]), float(g["arch"][1]))
			await _hold(city.plate_to_world((at + s_arch) * 0.5) + Vector2(0, -140), 0.85, 30, "18_watergate_SW_and_gate_S")
		else:
			await _hold(city.plate_to_world(at) + Vector2(0, -140), 0.85, 30, "18_watergate_%s" % tag)
	# the SE wall, the river on the left
	var a := Vector2(float(poly[2][0]), float(poly[2][1]))
	var b := Vector2(float(poly[3][0]), float(poly[3][1]))
	await _hold(city.plate_to_world(a.lerp(b, 0.55)) + Vector2(-260, -120), 0.7, 30, "19_se_wall")
	# GOAL-like: the whole ring with a margin
	var vp: Vector2 = _w.get_viewport().get_visible_rect().size
	var wlo: Vector2 = city.plate_to_world(lo)
	var whi: Vector2 = city.plate_to_world(hi)
	var span: Vector2 = (whi - wlo) * 1.12
	var zoom: float = minf(vp.x / span.x, vp.y / span.y)
	await _hold((wlo + whi) * 0.5 + Vector2(0, -40), zoom, 40, "20_wide_ring_goal")
	_w.walker.visible = true
	_w.camera_hold = false
	_w.npc_plates.visible = true


## Round 13: every tower-to-wall and tower-to-gate join, from inside and
## from outside, with the hero standing beside it for scale.
func _audit_shots() -> void:
	_w.camera_hold = true
	_w.npc_plates.visible = false
	var poly: Array = city.doc["wall_polygon"]
	var centre := Vector2.ZERO
	for q in poly:
		centre += Vector2(float(q[0]), float(q[1]))
	centre /= float(poly.size())
	var spots: Array = []
	for rec in city.layers():
		if str(rec["tag"]) == "tower":
			spots.append([_tower_foot(rec), "%s_%d" % [str(rec.get("tower_kind", "wall")), int(rec["id"])]])
	for g in city.gates():
		spots.append([Vector2(float(g["wall_join_left"][0]), float(g["wall_join_left"][1])), "gate_%s_left" % g["id"]])
		spots.append([Vector2(float(g["wall_join_right"][0]), float(g["wall_join_right"][1])), "gate_%s_right" % g["id"]])
	for sp in spots:
		var p: Vector2 = sp[0]
		var inward: Vector2 = (centre - p).normalized()
		for view in [["in", 1.0], ["out", -1.0]]:
			var side: float = view[1]
			var hero_at: Vector2 = city.plate_to_world(p + inward * side * 95.0 + Vector2(70.0, 0.0))
			_w.walker.position = hero_at
			_w.walker.z_index = int(round(hero_at.y * 10.0 / 16.0)) + 4
			_w.walker.visible = true
			await _hold(city.plate_to_world(p + inward * side * 60.0) + Vector2(0, -120), 1.25, 12, "22_%s_%s" % [sp[1], view[0]])
	_w.camera_hold = false
	_w.npc_plates.visible = true
