extends SceneTree

## The playable world on the modular city (city.json "modular", tile mode):
## walk grid from the tile map, gates that open, no leaks, plots reached,
## y-sort, fade, labels, night lamps, NPCs, exits.

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const PlateCity := preload("res://backend/plate_city.gd")

var passed := 0
var failed := 0
var city


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	PlateCity.mode_override = "tile"
	PlateCity.clear_cache()
	var loaded: Dictionary = PlateCity.load_default()
	check(bool(loaded.get("ok", false)), "city loads in tile mode (%s)" % [loaded.get("errors", [])])
	if not bool(loaded.get("ok", false)):
		_finish()
		return
	city = loaded["city"]
	check(city.tile_mode(), "tile mode is on")
	_test_grid()
	var w := _spawn()
	await process_frame
	w.warp_city()
	await _enter(w)
	_test_view(w)
	_test_gates(w)
	_test_fade_labels(w)
	_test_lamps(w)
	_test_npcs(w)
	w.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("tile world tests: %d passed, %d failed" % [passed, failed])
	PlateCity.mode_override = ""
	PlateCity.clear_cache()
	quit(1 if failed > 0 else 0)


func _spawn() -> Node2D:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	settings.set_performance(false)
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.weather.time_scale = 0.0
	w.weather.time_of_day = 12.0
	return w


func _enter(w: Node2D) -> void:
	for i in 3:
		await process_frame


func _drive(w: Node2D, max_steps: int = 6000) -> void:
	var n := 0
	while w.walker.is_moving() and n < max_steps:
		w.tick_city_gates(0.05)
		w.walker.advance(0.05)
		n += 1


func _cell_at(world: Vector2) -> Vector2i:
	var u := (world.x / 32.0 + world.y / 16.0) * 0.5
	var v := (world.y / 16.0 - world.x / 32.0) * 0.5
	return Vector2i(roundi(u), roundi(v))


func _in_wall(p: Vector2) -> bool:
	var poly := PackedVector2Array()
	for q in city.doc["wall_polygon"]:
		poly.append(Vector2(float(q[0]), float(q[1])))
	return Geometry2D.is_point_in_polygon(p, poly)


func _reach(from: Vector2i, shut: Dictionary = {}) -> Dictionary:
	var z: WorldZone = city.zone
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if z.passable_at(n) and not seen.has(n) and not shut.has(n):
				seen[n] = true
				q.append(n)
	return seen


func _test_grid() -> void:
	var z: WorldZone = city.zone
	var spawn: Vector2i = city.spawn()
	check(z.passable_at(spawn), "spawn is walkable")
	var reach := _reach(spawn)
	check(reach.has(city.exit_cell()), "the road exit is reached")
	check(reach.size() > 3000, "one walk area (%d cells)" % reach.size())
	var shut := {}
	for g in city.gates():
		var ins := false
		var outs := false
		for c in g["cells"]:
			var cell := Vector2i(int(c[0]), int(c[1]))
			shut[cell] = true
			check(reach.has(cell), "gate %s cell %s is reached" % [g["id"], cell])
			if _in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(cell))):
				ins = true
			else:
				outs = true
		check(ins and outs, "gate %s passage runs outside to inside" % g["id"])
	# no leaks: from inside, with every gate shut, nothing outside the ring
	var start := Vector2i(-1, -1)
	for y in z.height:
		for x in z.width:
			var c := Vector2i(x, y)
			if start.x < 0 and z.passable_at(c) and not shut.has(c) and _in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(c))):
				var r0 := _reach(c, shut)
				if r0.size() > 2000:
					start = c
	check(start.x >= 0, "a big inside area")
	var inside := _reach(start, shut)
	var leaks := 0
	for c in inside.keys():
		if not _in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(c))):
			leaks += 1
	check(leaks <= 6, "the wall lets nobody out but the gates (%d cells past the line)" % leaks)
	check(not inside.has(spawn), "the spawn (outside) is not reached with the gates shut")
	# every plot entrance is reached
	for p in city.tile.doc["plots"]:
		var f := Vector2i(int(p["front"][0]), int(p["front"][1]))
		var c := _cell_at(city.tile.cell_to_world(Vector2(f)))
		var ok := false
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1)]:
			if reach.has(c + d):
				ok = true
		check(ok, "plot %s entrance is reached" % p["id"])
	# exits to the region roads are reached
	for st in city.stubs_from(PlateCity.CITY_ID):
		var c := Vector2i(int(st["from"]["x"]), int(st["from"]["y"]))
		check(reach.has(c), "exit %s is reached" % st["id"])
	for n in city.npcs():
		check(z.passable_at(Vector2i(int(n["cell"]["x"]), int(n["cell"]["y"]))), "NPC %s stands on a walkable cell" % n["id"])


func _test_view(w: Node2D) -> void:
	check(w.in_city() and w.city_plate != null, "the world is in the city")
	var cp = w.city_plate
	check(cp.tile_view != null, "the tile view draws the town")
	check(cp.rows.size() > 1000, "every piece is a sorted row (%d)" % cp.rows.size())
	var tags := {}
	for row in cp.rows:
		tags[str(row["tag"])] = true
	for t in ["wall", "tower", "gate_back", "castle", "cathedral", "house", "lamp", "plot_house"]:
		check(tags.has(t), "rows include %s" % t)
	check(cp.plot_nodes.size() == 10, "10 plot houses (%d)" % cp.plot_nodes.size())
	# the hero sorts in front of a house when south of it, behind when north
	for row in cp.rows:
		if str(row["tag"]) == "house":
			var foot_y: float = city.plate_to_world(Vector2(0, float(row["sort_y"]))).y
			var zf := int(round((foot_y + 4.0) * 10.0 / 16.0)) + BoardVisualSort.UNIT_Z_BIAS
			var zb := int(round((foot_y - 14.0) * 10.0 / 16.0)) + BoardVisualSort.UNIT_Z_BIAS
			check(zf > int(row["z"]) and zb < int(row["z"]), "the hero sorts round a house by its foot")
			break


func _test_gates(w: Node2D) -> void:
	var z: WorldZone = w.zone
	var cp = w.city_plate
	check(cp.gates_fx.size() == 4, "4 gates open and close (%d)" % cp.gates_fx.size())
	for g in city.gates():
		var gf: Dictionary = cp.gate_fx(str(g["id"]))
		if gf.is_empty():
			check(false, "gate %s has its doors" % g["id"])
			continue
		var cells: Array = g["cells"]
		var outs: Array[Vector2i] = []
		var ins: Array[Vector2i] = []
		for c in cells:
			var cc := Vector2i(int(c[0]), int(c[1]))
			if _in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(cc))):
				ins.append(cc)
			else:
				outs.append(cc)
		var a: Vector2i = outs[0]
		var b: Vector2i = ins[ins.size() - 1]
		for leg in [[a, b, "in"], [b, a, "out"]]:
			w.walker.place(z, leg[0])
			for i in 60:
				cp.tick_gates(0.05, [], w.walker._strips.height())
			check(float(gf["lift"]) == 0.0, "gate %s is shut with nobody near" % g["id"])
			var r: Dictionary = w.walk_to(leg[1], "walk")
			check(bool(r.get("ok", false)), "gate %s: walk %s" % [g["id"], leg[2]])
			var top := 0.0
			var n := 0
			while w.walker.is_moving() and n < 6000:
				w.tick_city_gates(0.05)
				w.walker.advance(0.05)
				top = maxf(top, float(gf["lift"]))
				n += 1
			check(w.walker.cell == leg[1], "gate %s: the hero gets %s (%s)" % [g["id"], leg[2], w.walker.cell])
			check(top >= 1.0, "gate %s opened for the walk %s" % [g["id"], leg[2]])


func _test_fade_labels(w: Node2D) -> void:
	var cp = w.city_plate
	var z: WorldZone = w.zone
	var done_fade := false
	var done_label := false
	for row in cp.rows:
		if done_fade and done_label:
			break
		if not (str(row["tag"]) in ["house", "wall", "tower"]) or not bool(row["fade"]):
			continue
		var rect: Rect2 = row["rect"]
		var sort_world_y: float = city.plate_to_world(Vector2(0, float(row["sort_y"]))).y
		for y in z.height:
			if done_fade:
				break
			for x in z.width:
				var c := Vector2i(x, y)
				if not z.passable_at(c):
					continue
				var p := BoardVisualSort.cell_to_local(c)
				if rect.has_point(p - Vector2(0, 30)) and p.y < sort_world_y - 30.0 and cp._mask_hits(row, Rect2(p.x - 13, p.y - 58, 26, 54)):
					w.walker.place(z, c)
					var covered: bool = cp.update_cover(w.walker.position, 0.0, w.walker.z_index, 1.0)
					check(covered and float(row["alpha"]) <= 0.5, "a %s fades over the hero behind it" % row["tag"])
					check(cp.occluded(w.walker.position, w.walker.z_index), "a body behind the %s is occluded (labels hide)" % row["tag"])
					check(not cp.occluded(w.walker.position + Vector2(0, rect.size.y + 80.0), int(row["z"]) + 400), "a body in the open is not")
					done_fade = true
					done_label = true
					break
	check(done_fade, "found a spot behind a building or wall")
	w.walker.place(z, city.spawn())
	cp.update_cover(w.walker.position, 0.0, w.walker.z_index, 1.0)


func _test_lamps(w: Node2D) -> void:
	var cp = w.city_plate
	check(cp.lights.size() >= 20, "street lamps (%d)" % cp.lights.size())
	cp.set_hour(22.0)
	var lit := 0
	for l in cp.lights:
		if (l["halo"] as CanvasItem).visible:
			lit += 1
	check(lit == cp.lights.size(), "every lamp is lit at night (%d)" % lit)
	cp.set_hour(12.0)
	lit = 0
	for l in cp.lights:
		if (l["halo"] as CanvasItem).visible:
			lit += 1
	check(lit == 0, "no lamp lit at noon")


func _test_npcs(w: Node2D) -> void:
	var n := 0
	for node in w.npcs_root.get_children():
		n += 1
		check(w.zone.passable_at(node.cell), "NPC %s on a walkable cell" % node.name)
	check(n == city.npcs().size() and n > 0, "the townsfolk are out (%d)" % n)
