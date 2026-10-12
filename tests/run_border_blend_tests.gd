extends SceneTree

## Chunk borders must not be a straight colour cut. Samples the painted colour
## along every zone edge and fails a run of 8 or more cells when the step is
## both large and uniform. Also: the north-road snow line wanders by column,
## and flat grass does not touch the sea.
## Run: godot --headless --path . -s res://tests/run_border_blend_tests.gd

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Ground := preload("res://scenes/world/crosshaven/crosshaven_ground.gd")
const Survey := preload("res://tests/pc/survey_seams.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
const RUN_MIN := 8

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	await process_frame
	await Survey.survey(w)
	_test_borders(w)
	_test_snow_line(w)
	_test_grass_sea(w)
	print("border blend tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_borders(w: Node2D) -> void:
	var grounds := {}
	for g in w._grounds_root.get_children():
		if g.zone != null:
			grounds[g.zone.zone_id] = g
	var owner := {}
	for zid in w.plane_offsets.keys():
		var z: WorldZone = w.map.zone(str(zid))
		if z == null or not grounds.has(str(zid)):
			continue
		var o: Vector2i = w.plane_offsets[zid]
		for y in z.height:
			for x in z.width:
				owner[o + Vector2i(x, y)] = str(zid)
	var hard := 0
	var example := ""
	var edges := {}
	for cell in owner.keys():
		var a: Vector2i = cell
		for dir in DIRS:
			var b: Vector2i = a + dir
			if not owner.has(b) or owner[b] == owner[a]:
				continue
			var ekey := "%s|%s|%s" % [owner[a], owner[b], dir]
			if not edges.has(ekey):
				edges[ekey] = []
			(edges[ekey] as Array).append(a)
	for ekey in edges.keys():
		var parts := str(ekey).split("|")
		var dir := Vector2i(1, 0) if parts[2] == "(1, 0)" else Vector2i(0, 1)
		for seg in Survey._segments(edges[ekey], parts[2]):
			if seg.size() < RUN_MIN:
				continue
			var dists: Array[float] = []
			for at in seg:
				var world_a: Vector2i = at
				var world_b: Vector2i = at + dir
				var ga: Node2D = grounds[owner[world_a]]
				var gb: Node2D = grounds[owner[world_b]]
				var ca: Color = ga.call("visual_color", world_a - ga.world_origin)
				var cb: Color = gb.call("visual_color", world_b - gb.world_origin)
				dists.append(_dist(ca, cb))
			if _uniform_cut(dists):
				hard += 1
				if example == "":
					example = "%s len=%d mean=%.3f" % [ekey, seg.size(), _mean(dists)]
	check(hard == 0, "no straight colour cut along a chunk border (%d, %s)" % [hard, example])


func _uniform_cut(dists: Array[float]) -> bool:
	if dists.size() < RUN_MIN:
		return false
	var mean := _mean(dists)
	if mean < 0.22:
		return false
	var min_d := dists[0]
	var var_sum := 0.0
	for d in dists:
		min_d = minf(min_d, d)
		var delta := d - mean
		var_sum += delta * delta
	var stdev := sqrt(var_sum / float(dists.size()))
	return stdev < 0.035 and min_d > 0.16


func _mean(dists: Array[float]) -> float:
	var sum := 0.0
	for d in dists:
		sum += d
	return sum / float(dists.size())


func _dist(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


func _test_snow_line(w: Node2D) -> void:
	var g: Node2D = null
	for child in w._grounds_root.get_children():
		if child.zone != null and child.zone.zone_id == "crosshaven_road_north":
			g = child
			break
	check(g != null, "the north road is mounted")
	if g == null:
		return
	var zeros: Array[int] = []
	for x in g.zone.width:
		var y0: int = int(g.zone.height)
		for y in g.zone.height:
			if float(g.call("snow_at_cell", Vector2i(x, y))) <= 0.001:
				y0 = y
				break
		zeros.append(y0)
	var lo := zeros[0]
	var hi := zeros[0]
	for y in zeros:
		lo = mini(lo, y)
		hi = maxi(hi, y)
	check(hi - lo >= 2, "north-road snow ends on different rows (%d..%d)" % [lo, hi])
	check(float(g.call("snow_at_cell", Vector2i(12, 2))) > 0.7, "town side of the north road stays snowy")
	check(float(g.call("snow_at_cell", Vector2i(12, 24))) == 0.0, "Crossroads side of the north road stays clear")


func _test_grass_sea(w: Node2D) -> void:
	var bad := 0
	var example := ""
	for g in w._grounds_root.get_children():
		if g.zone == null:
			continue
		var z: WorldZone = g.zone
		for y in z.height:
			for x in z.width:
				var cell := Vector2i(x, y)
				if z.terrain_at(cell) != "golden_plains" or z.height_at(cell) != 0:
					continue
				if float(g.call("cover_at", cell)) >= 0.999:
					continue
				if str(g.call("_beach_at", cell)) == "sand":
					continue
				for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if int(g.call("_shore_kind", cell + dir)) == Ground.SHORE_SEA:
						bad += 1
						if example == "":
							example = "%s %s" % [z.zone_id, cell]
						break
	check(bad == 0, "no flat grass cell touches the sea (%d, %s)" % [bad, example])
