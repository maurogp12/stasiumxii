extends SceneTree

## Smoothed shoreline (crosshaven_ground.gd `_cache_shore`, crosshaven_shore.gdshader).
## Mauro: "CREO que esos bordes de la arena en la playa están mal hechos"
## (Saltmaw Sea Caves, cell 24,29: a sawtooth of cell diamonds on the coast).
## The bands are a drawing change only. These checks hold it to that:
##   - no walkable cell changes, water stays unwalkable;
##   - the drawn coast stays within half a cell of the real cell coast, so
##     sand never shows where you cannot walk and sea never covers sand you can;
##   - the per-cell surf and wet-sand pieces are gone from shore cells.
## Run: godot --headless --path . -s res://tests/run_shoreline_tests.gd

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Ground := preload("res://scenes/world/crosshaven/crosshaven_ground.gd")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const Survey := preload("res://tests/pc/survey_seams.gd")
## Every chunk with a sea coast, and one spot on it.
const COASTS := {
	"crosshaven_eastmarch_sea_caves": Vector2i(24, 29),
	"crosshaven_eastmarch": Vector2i(26, 22),
	"crosshaven_eastmarch_coves": Vector2i(22, 6),
	"crosshaven_southbridge": Vector2i(8, 23),
	"crosshaven_northgate": Vector2i(7, 7),
	"crosshaven_northgate_crags_east": Vector2i(8, 4),
}
## The shader moves the line by up to this much (noise wobble and tide), in cells.
const DRAW_WOBBLE := 0.17
## The drawn coast may sit this far (cells) from the cell coast.
const TOLERANCE := 0.5

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
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
	w.weather.auto_rotate = false
	await process_frame
	_test_distances()
	for zone_id in COASTS.keys():
		_test_coast(w, str(zone_id), COASTS[zone_id])
	_test_saltmaw_spot(w)
	_test_old_look(w)
	await _test_performance(w, settings)
	await _test_plane(w)
	print("shoreline tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## The cell field: 0.5 beside the other side, 0.71 across a corner.
func _test_distances() -> void:
	# 5x5, sea on the right two columns, one sea cell poking in at (2, 2).
	var size := Vector2i(5, 5)
	var kind := PackedByteArray()
	kind.resize(25)
	for y in 5:
		for x in 5:
			kind[y * 5 + x] = Ground.SHORE_SEA if x >= 3 or (x == 2 and y == 2) else Ground.SHORE_SOFT
	var d := Ground.shore_distances(kind, size, 4.0)
	check(is_equal_approx(d[0 * 5 + 2], 0.5), "land beside sea is 0.5 (%s)" % d[2])
	check(is_equal_approx(d[2 * 5 + 2], -0.5), "a lone sea cell is -0.5 (%s)" % d[12])
	check(is_equal_approx(d[1 * 5 + 1], sqrt(0.5)), "land across a corner is 0.71 (%s)" % d[6])
	check(is_equal_approx(d[0 * 5 + 1], 1.5), "two cells in is 1.5 (%s)" % d[1])
	check(is_equal_approx(d[0 * 5 + 0], sqrt(4.5)), "the far corner walks the diagonal (%s)" % d[0])
	check(d[2 * 5 + 4] < -1.0, "open sea is deeper than the edge (%s)" % d[14])


func _test_coast(w: Node2D, zone_id: String, spot: Vector2i) -> void:
	var raw := _raw_walkable(zone_id)
	w._load_zone(zone_id, spot)
	var z: WorldZone = w.zone
	var ground: Node2D = w.ground
	var cells: Dictionary = ground.call("shore_cells")
	check(not cells.is_empty(), "%s has a smoothed shore" % zone_id)
	# Gameplay is untouched: every cell walks as its zone file says.
	var changed := 0
	var wet_walk := 0
	for y in z.height:
		for x in z.width:
			var cell := Vector2i(x, y)
			if z.walkable_at(cell) != bool(raw.get(cell, false)):
				changed += 1
			if z.terrain_at(cell) == "water" and z.walkable_at(cell):
				wet_walk += 1
	check(changed == 0, "%s: no walkable cell changed (%d did)" % [zone_id, changed])
	check(wet_walk == 0, "%s: water stays unwalkable (%d walk)" % [zone_id, wet_walk])
	# Shore cells are sand or snow on the land side and sea on the other.
	var bad_kind := 0
	for cell in cells.keys():
		var kind := int(ground.call("_shore_kind", cell))
		if kind == Ground.SHORE_HARD:
			bad_kind += 1
	check(bad_kind == 0, "%s: no cliff, bank or river cell takes the bands (%d)" % [zone_id, bad_kind])
	_check_bound(ground, cells, zone_id)
	# The rows draw the bands, after their cells.
	var rows_with := 0
	for row in ground.get_children():
		var band := row.get_node_or_null("Shore")
		if band == null:
			continue
		rows_with += 1
		var shader_mat := (band as Node2D).material as ShaderMaterial
		if shader_mat == null or shader_mat.shader == null:
			check(false, "%s %s has the shore shader" % [zone_id, row.name])
			break
		if row.get_node_or_null("ShoreDecor") == null or band.get_index() <= row.get_node("Run0").get_index():
			check(false, "%s %s: bands after the cells, decor after the bands" % [zone_id, row.name])
			break
	check(rows_with > 0, "%s: rows carry a Shore node (%d)" % [zone_id, rows_with])


## The drawn line is where the smooth field (plus the shader's wobble) is 0.
## Where the real cell coast is more than TOLERANCE away it may not cross:
## land that deep in stays sand, sea that far out stays water.
func _check_bound(ground: Node2D, cells: Dictionary, zone_id: String) -> void:
	var wrong_land := 0
	var wrong_sea := 0
	var worst := ""
	for cell in cells.keys():
		var at: Vector2i = cell
		var sea := int(ground.call("_shore_kind", at)) == Ground.SHORE_SEA
		for j in 4:
			for i in 4:
				var p := Vector2(at) + Vector2(-0.375 + 0.25 * i, -0.375 + 0.25 * j)
				var t := _true_distance(ground, at, p, sea)
				if absf(t) < TOLERANCE:
					continue
				var s: float = ground.call("shore_smooth_at", p)
				if t > 0.0 and s < DRAW_WOBBLE:
					wrong_land += 1
					worst = "%s p=%s true=%.2f drawn=%.2f" % [at, p, t, s]
				elif t < 0.0 and s > -DRAW_WOBBLE:
					wrong_sea += 1
					worst = "%s p=%s true=%.2f drawn=%.2f" % [at, p, t, s]
	check(wrong_land == 0, "%s: walkable sand is never drawn as sea past half a cell (%d, %s)" % [zone_id, wrong_land, worst])
	check(wrong_sea == 0, "%s: sea is never drawn as sand past half a cell (%d, %s)" % [zone_id, wrong_sea, worst])


## Exact distance from `p` (cell units) to the cells of the other side.
func _true_distance(ground: Node2D, cell: Vector2i, p: Vector2, sea: bool) -> float:
	var best := 9.0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var nb := cell + Vector2i(dx, dy)
			var nb_sea := int(ground.call("_shore_kind", nb)) == Ground.SHORE_SEA
			if nb_sea == sea:
				continue
			var lo := Vector2(nb) - Vector2(0.5, 0.5)
			var hi := Vector2(nb) + Vector2(0.5, 0.5)
			var q := Vector2(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y))
			best = minf(best, p.distance_to(q))
	return -best if sea else best


func _raw_walkable(zone_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/world/crosshaven/zones/%s.json" % zone_id, FileAccess.READ)
	var doc: Dictionary = JSON.parse_string(f.get_as_text())
	var out := {}
	for tile in doc["tiles"]:
		out[Vector2i(int(tile["x"]), int(tile["y"]))] = bool(tile["walkable"])
	return out


## Mauro's spot: the coast below cell 24,29 is shore, with no surf or wet
## sand pieces left on its cells.
func _test_saltmaw_spot(w: Node2D) -> void:
	w._load_zone("crosshaven_eastmarch_sea_caves", Vector2i(24, 29))
	var ground: Node2D = w.ground
	var cells: Dictionary = ground.call("shore_cells")
	check(cells.has(Vector2i(28, 29)), "Saltmaw: the sand at the water (28, 29) takes the bands")
	check(cells.has(Vector2i(29, 29)), "Saltmaw: the first sea cell (29, 29) takes the bands")
	check(not cells.has(Vector2i(20, 29)), "Saltmaw: the grass at 20, 29, well inland, stays as it was")
	var surf := 0
	var wet := 0
	for cell in cells.keys():
		var fam := str(ground.call("_beach_at", cell))
		if not w.zone.in_bounds(cell):
			continue
		if fam == "sea_shallow":
			surf += 1
		elif fam == "wet_sand":
			wet += 1
	check(surf == 0, "Saltmaw: no per-cell surf pieces on the shore (%d)" % surf)
	check(wet == 0, "Saltmaw: no per-cell wet sand diamonds (%d)" % wet)


## Off draws the old pieces, for A/B stills and the bench.
func _test_old_look(w: Node2D) -> void:
	Ground.smooth_shore = false
	Ground.clear_memo()
	w._load_zone("crosshaven_eastmarch_sea_caves", Vector2i(24, 29))
	var ground: Node2D = w.ground
	check((ground.call("shore_cells") as Dictionary).is_empty(), "smooth shore off: no shore cells")
	check(str(ground.call("_beach_at", Vector2i(29, 29))) == "sea_shallow", "smooth shore off: the old surf cell is back")
	Ground.smooth_shore = true
	Ground.clear_memo()


## Performance mode: the bands hold one still frame, on every ground.
func _test_performance(w: Node2D, _settings: VisualSettings) -> void:
	w._load_zone("crosshaven_eastmarch_sea_caves", Vector2i(24, 29))
	w.settings.set_performance(true)
	await process_frame
	await process_frame
	var mats := _shore_mats(w)
	check(not mats.is_empty(), "performance mode keeps the bands")
	var moving := 0
	for mat in mats:
		if float(mat.get_shader_parameter("animate")) != 0.0:
			moving += 1
	check(moving == 0, "performance mode: no foam moves (%d of %d)" % [moving, mats.size()])
	w.settings.set_performance(false)
	await process_frame
	await process_frame
	mats = _shore_mats(w)
	var still := 0
	for mat in mats:
		if float(mat.get_shader_parameter("animate")) != 1.0:
			still += 1
	check(still == 0 and not mats.is_empty(), "full animations: the foam laps (%d still)" % still)


func _shore_mats(w: Node2D) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for g in w._grounds_root.get_children():
		var mat: ShaderMaterial = g.get("_shore_mat")
		if mat != null:
			out.append(mat)
	return out


## Mauro: "de arena pasó a pasto y debería ser arena" and "que sea flow
## continuo". Every chunk of the plane at once:
##   - every flat grass cell within BEACH_CELLS of the sea is beach, every
##     one past it is not, on every chunk, so the beach keeps its width
##     across chunk and zone edges;
##   - no flat coast cell shows grass next to the sea;
##   - every ground that draws a cell draws it as its own chunk does;
##   - no look change runs along a chunk edge (survey_seams.gd), except the
##     zone data seams listed in the change log (roads the zone files end
##     on a chunk edge).
func _test_plane(w: Node2D) -> void:
	var report: Dictionary = await Survey.survey(w)
	var grounds := {}
	for g in w._grounds_root.get_children():
		if g.zone != null:
			grounds[g.zone.zone_id] = g
	check(grounds.size() >= 20, "the survey mounts the whole plane (%d grounds)" % grounds.size())
	var wrong_width := 0
	var grass_at_sea := 0
	var example := ""
	for zone_id in grounds.keys():
		var g: Node2D = grounds[zone_id]
		var z: WorldZone = g.zone
		var field: Dictionary = g.get("_shore_field")
		for y in z.height:
			for x in z.width:
				var cell := Vector2i(x, y)
				if z.terrain_at(cell) != "golden_plains" or z.height_at(cell) != 0:
					continue
				if float(g.call("cover_at", cell)) >= 0.999:
					continue
				var sand := str(g.call("_beach_at", cell)) == "sand"
				var near_sea := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if int(g.call("_shore_kind", cell + Vector2i(dx, dy))) == Ground.SHORE_SEA:
							near_sea = true
				if near_sea and not sand:
					grass_at_sea += 1
					example = "%s %s" % [zone_id, cell]
				if field.is_empty():
					continue
				var d := float(g.call("shore_field_at", cell))
				if (d <= Ground.BEACH_CELLS) != sand:
					wrong_width += 1
					example = "%s %s d=%.2f sand=%s" % [zone_id, cell, d, sand]
	check(grass_at_sea == 0, "no flat coast cell has grass beside the sea (%d, %s)" % [grass_at_sea, example])
	check(wrong_width == 0, "the beach is BEACH_CELLS wide on every chunk (%d off, %s)" % [wrong_width, example])
	check(int(report["order"]) == 0, "every ground draws a seam cell as its owner does (%d differ)" % int(report["order"]))
	check(int(report["draw"]) == 0, "no drawn look changes along a chunk edge (%d runs)" % int(report["draw"]))
	for line in report["lines"]:
		if str(line).begins_with("DRAW") or str(line).begins_with("ORDER"):
			print("  ", line)
	# Zone-data seams (a road the zone files stop at a chunk edge) are listed,
	# not failed: the zone data stays as it is on this branch.
	print("  shoreline: zone data seams %d, road ends at chunk edges %d" % [int(report["data"]), int(report["road"])])
