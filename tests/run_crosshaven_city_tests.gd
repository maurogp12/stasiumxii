extends SceneTree

## Walled city of Crosshaven (plate-backed zone `crosshaven_city`). Run:
##   godot --headless --path . -s res://tests/run_crosshaven_city_tests.gd
## Covers: the zone loads; walk cells, gate and bridges connect; the player
## plot rules (MUST FIX list); y-sort against the hero; occluder fade; day and
## night life; Performance mode; the gate stub and the dev entry.

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const PlateCity := preload("res://backend/plate_city.gd")
const Maps := preload("res://backend/world_map.gd")

const WALL_TAGS := ["wall", "wall_g", "tower", "tower_g", "gate_back", "lintel", "watergate"]
const TOWER_TAGS := ["tower", "tower_g"]
const LEGENDARY_W := 350.0
const OCCLUDERS := ["house", "wall", "tree", "tower"]

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
	var loaded: Dictionary = PlateCity.load_default()
	check(bool(loaded.get("ok", false)), "city.json loads (%s)" % [loaded.get("errors", [])])
	if not bool(loaded.get("ok", false)):
		_finish()
		return
	city = loaded["city"]
	_test_data()
	_test_walk()
	_test_plots()
	_test_gates()
	_test_review_data()
	_test_crossroads_untouched()
	var w := _spawn()
	await _test_world_entry(w)
	_test_sort(w)
	_test_fade(w)
	_test_life(w)
	_test_performance(w)
	_test_gate_walks(w)
	_test_review_world(w)
	await _test_gate_stub(w)
	w.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("crosshaven city tests: %d passed, %d failed" % [passed, failed])
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


func _drive(w: Node2D, max_steps: int = 6000) -> void:
	var n := 0
	while w.walker.is_moving() and n < max_steps:
		w.walker.advance(0.05)
		n += 1


# ---------------------------------------------------------------- data

func _test_data() -> void:
	var z: WorldZone = city.zone
	check(z != null and z.zone_id == "crosshaven_city", "zone id is crosshaven_city")
	check(city.map != null and city.map.zone("crosshaven_city") == z, "one-zone map holds the city")
	var walkable := 0
	for y in z.height:
		for x in z.width:
			if z.passable_at(Vector2i(x, y)):
				walkable += 1
	check(walkable > 0, "walkable cell count above 0 (%d)" % walkable)
	check(walkable > 5000, "the streets and greens are walkable (%d cells)" % walkable)
	var plate: Dictionary = city.doc["plate"]
	check(float(plate["scale"]) > 0.0, "plate scale is in data (%.2f)" % float(plate["scale"]))
	check(is_equal_approx(city.world_rect().size.x, city.plate_size().x * float(plate["scale"])), "world rect follows the plate scale")
	var fit: Dictionary = plate["fit"]
	for r in fit["residuals"]:
		check(absf(float(r["offset_px"])) <= 8.0, "%s sits within 8 px of a cell row (%.2f)" % [r["id"], float(r["offset_px"])])
	check(city.layers().size() > 300, "sprite layers load (%d)" % city.layers().size())
	# Item 7: trees cut to the data keep list (about 20).
	var keep := {}
	for g in (city.doc["trees_keep"] as Dictionary).values():
		for id in g:
			keep[int(id)] = true
	var trees := 0
	var stray_trees := 0
	var planters: Array = []
	var houses: Array = []
	var jitter_ok := true
	for rec in city.layers():
		if str(rec["tag"]) == "tree" and str(rec.get("spot", "")) != "outer_forest":
			trees += 1
			if not keep.has(int(rec["id"])):
				stray_trees += 1
		if str(rec["tag"]) == "house":
			houses.append(Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["sort_y"])))
		if str(rec["file"]).ends_with("cx_planter_a.png"):
			planters.append(Vector2(float(rec["x"]) + float(rec["w"]) * float(rec.get("k", 1.0)) * 0.5, float(rec["sort_y"])))
		var k := float(rec.get("k", 1.0))
		if k < 0.899 or k > 1.101:
			jitter_ok = false
	check(trees >= 10 and trees <= 25, "trees cut to about 20, fewer after the gate plazas (%d)" % trees)
	check(stray_trees == 0, "every tree left is on the keep list (%d strays)" % stray_trees)
	check(jitter_ok, "plant scale jitter stays in 0.9-1.1")
	check(planters.size() <= 8, "planters stay few (%d)" % planters.size())
	for pl in planters:
		var near := false
		for h in houses:
			if (pl as Vector2).distance_to(h) < 170.0:
				near = true
		check(near, "planter at %s stands beside a house" % pl)
	var plants := 0
	for rec in city.layers():
		if rec.has("plant"):
			plants += 1
	check(plants >= 150, "bushes and flowers scattered (%d)" % plants)
	for rec in city.layers():
		var tag := str(rec["tag"])
		check(not ("garden" in tag or "bed" in tag or "fence" in tag), "no garden bed or fence layer (%s)" % tag)
		if rec.get("plot_plant", false):
			check(not ("planter" in str(rec["file"])), "plot plants are loose plants, not planter boxes (%s)" % rec["file"])
	check(ResourceLoader.exists(city.art_path("ground.jpg")) or FileAccess.file_exists(city.art_path("ground.jpg")), "ground art exists")
	for t in ["normal", "rare", "legendary"]:
		check(FileAccess.file_exists(city.house_art(t)) or ResourceLoader.exists(city.house_art(t)), "house art for %s" % t)


# ---------------------------------------------------------------- walk

func _reach(from: Vector2i) -> Dictionary:
	var z: WorldZone = city.zone
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if z.passable_at(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen


func _test_walk() -> void:
	var z: WorldZone = city.zone
	var spawn: Vector2i = city.spawn()
	var reach := _reach(spawn)
	check(z.passable_at(spawn), "spawn is walkable")
	check(reach.has(city.exit_cell()), "the road exit is reached from the spawn")
	var gates: Array[Vector2i] = city.gate_cells()
	check(gates.size() >= 3, "the gate arch has walk cells (%d)" % gates.size())
	for g in gates:
		check(reach.has(g), "gate cell %s is reached" % g)
	# Through the gate: spawn (outside, south road) to the far side of bridge 0.
	var inner: Array = city.bridges()[0]["ends"][1]
	var path: Dictionary = WorldWalk.find_path(city.map, "crosshaven_city", spawn, "crosshaven_city", Vector2i(int(inner[0]), int(inner[1])))
	check(bool(path.get("ok", false)), "spawn walks to the north-east bridge")
	var through_gate := false
	for step in path.get("path", []):
		if gates.has(Vector2i(int(step["x"]), int(step["y"]))):
			through_gate = true
	check(through_gate, "the walk in goes through the gate arch")
	check(city.bridges().size() == 3, "three bridges in the data")
	var inner_bridges := 0
	for b in city.bridges():
		var a := Vector2i(int(b["ends"][0][0]), int(b["ends"][0][1]))
		var c := Vector2i(int(b["ends"][1][0]), int(b["ends"][1][1]))
		# Only bridges inside the ring are walked (the re-laid ring leaves one outside).
		if (b["deck_cells"] as Array).is_empty() or not (_in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(a))) and _in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(c)))):
			continue
		inner_bridges += 1
		check(reach.has(a) and reach.has(c), "%s both ends reached" % b["id"])
		check((b["deck_cells"] as Array).size() >= 3, "%s has deck cells" % b["id"])
		var top := 0
		for dc in b["deck_cells"]:
			top = maxi(top, z.height_at(Vector2i(int(dc[0]), int(dc[1]))))
		check(top >= 5, "%s deck rises to the crown (step %d)" % [b["id"], top])
		# Crossing: a path from one end to the other climbs the deck.
		var cross: Dictionary = WorldWalk.find_path(city.map, "crosshaven_city", a, "crosshaven_city", c)
		check(bool(cross.get("ok", false)), "%s can be crossed" % b["id"])
		var climb := 0
		for step in cross.get("path", []):
			climb = maxi(climb, z.height_at(Vector2i(int(step["x"]), int(step["y"]))))
		check(climb >= 5 and (cross.get("path", []) as Array).size() <= 24, "%s crossing goes over the deck (top %d, %d steps)" % [b["id"], climb, (cross.get("path", []) as Array).size()])
	check(inner_bridges >= 2, "bridges inside the ring (%d)" % inner_bridges)
	# The river blocks: every water cell is impassable, and water exists.
	var water := 0
	for y in z.height:
		for x in z.width:
			if z.terrain_at(Vector2i(x, y)) == "water":
				water += 1
				check(not z.passable_at(Vector2i(x, y)), "water cell %d,%d blocks" % [x, y]) if z.passable_at(Vector2i(x, y)) else null
	check(water > 100, "the river is in the grid (%d cells)" % water)
	# Walls and buildings block: the cells under towers and landmarks.
	var blocked_under := 0
	var probes := 0
	for rec in city.layers():
		var tag := str(rec["tag"])
		if tag in ["tower", "castle", "cathedral", "townhall", "bank"] and not bool(rec.get("displaced_by_plot", false)):
			probes += 1
			var foot: Vector2 = city.plate_to_world(_tower_foot(rec) + Vector2(0.0, -4.0) if rec.has("wall_point") else Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["sort_y"]) - 14.0))
			var cell := _cell_at(foot)
			if not z.passable_at(cell):
				blocked_under += 1
	check(probes >= 6 and blocked_under == probes, "towers and landmarks block their base (%d of %d)" % [blocked_under, probes])


func _cell_at(world: Vector2) -> Vector2i:
	var u := (world.x / 32.0 + world.y / 16.0) * 0.5
	var v := (world.y / 16.0 - world.x / 32.0) * 0.5
	return Vector2i(roundi(u), roundi(v))


# ---------------------------------------------------------------- gates (Mauro's change list 1-4)

func _in_wall(p: Vector2) -> bool:
	var poly := PackedVector2Array()
	for q in city.doc["wall_polygon"]:
		poly.append(Vector2(float(q[0]), float(q[1])))
	return Geometry2D.is_point_in_polygon(p, poly)


func _test_gates() -> void:
	var z: WorldZone = city.zone
	var gates: Array = city.gates()
	check(gates.size() >= 5, "gatehouses (%d)" % gates.size())
	var ids := {}
	for g in gates:
		ids[str(g["id"])] = true
	for want in ["S", "W", "E", "N", "SE"]:
		check(ids.has(want), "gatehouse %s exists" % want)
	# Ring on the 3 plate directions: every edge horizontal or an iso diagonal.
	var poly: Array = city.doc["wall_polygon"]
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var dx := float(b[0]) - float(a[0])
		var slope := 999.0 if is_zero_approx(dx) else (float(b[1]) - float(a[1])) / dx
		check(is_zero_approx(slope) or is_equal_approx(absf(slope), 0.5), "wall edge %d runs on a plate direction (%.3f)" % [i, slope])
	# After the build no street meets the wall without a gate.
	for c in (city.doc["wall_contacts"] as Dictionary)["after"]:
		check(str(c["verdict"]) in ["gate", "runs_along"], "wall contact at %s is gated (%s)" % [c["at"], c["verdict"]])
	var reach := _reach(city.spawn())
	var all_gate := {}
	for g in gates:
		var cells: Array = g.get("cells", [])
		check(cells.size() >= 2, "%s has passage cells (%d)" % [g["id"], cells.size()])
		var inside := false
		var outside := false
		for c in cells:
			var cell := Vector2i(int(c[0]), int(c[1]))
			all_gate[cell] = true
			check(reach.has(cell), "%s cell %s is walkable and joined" % [g["id"], cell])
			var p: Vector2 = city.world_to_plate(BoardVisualSort.cell_to_local(cell))
			if _in_wall(p):
				inside = true
			else:
				outside = true
		check(inside and outside, "%s passage runs from outside to inside" % g["id"])
	# Walls block everywhere else: with the gate cells shut, the inside does
	# not reach any cell outside the wall ring.
	var start := Vector2i(int(city.bridges()[0]["ends"][0][0]), int(city.bridges()[0]["ends"][0][1]))
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var leaks := 0
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or all_gate.has(n) or not z.passable_at(n):
				continue
			seen[n] = true
			if not _in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(n))):
				leaks += 1
				continue
			q.append(n)
	check(seen.size() > 3000, "the walled inside is one walk area (%d cells)" % seen.size())
	check(leaks == 0, "the wall lets the hero out only through the gates (%d leaks)" % leaks)
	# Item 4: no wall stubs at the tower bases (cylinder columns only below the stub row).
	var towers := 0
	for rec in city.layers():
		if not (str(rec["tag"]) in ["tower", "tower_g"]) or rec.has("module"):
			continue
		towers += 1
		var m: Dictionary = PlateCity.unpack_mask(rec["mask"])
		var stray := 0
		var step := int(m["step"])
		# The sprite may be scaled (ring heights): cylinder columns 44-132 and
		# stub row 136 of the 180 px source scale with it.
		var k := float(rec["w"]) / 180.0
		for by in range(int(136.0 * k) / step + 1, int(m["h"])):
			for bx in int(m["w"]):
				var x0 := bx * step
				if (x0 + step <= int(44.0 * k) - step or x0 >= int(132.0 * k) + step) and (m["bits"] as PackedByteArray)[by * int(m["w"]) + bx] == 1:
					stray += 1
		check(stray == 0, "tower layer %d has no wall stub (%d stray blocks)" % [int(rec["id"]), stray])
	var kit_towers := 0
	for rec in city.layers():
		if str(rec["tag"]) == "tower" and rec.has("module"):
			kit_towers += 1
	check(towers >= 12 or kit_towers >= 4, "towers checked (%d prototype, %d kit)" % [towers, kit_towers])


# ---------------------------------------------------------------- plots

func _ellipse_points(anchor: Vector2) -> Array[Vector2]:
	var rx := LEGENDARY_W * 0.5
	var ry := rx * 0.5
	var c := anchor - Vector2(0, ry)
	var out: Array[Vector2] = []
	var y := -ry
	while y <= ry:
		var x := -rx
		while x <= rx:
			if (x / rx) * (x / rx) + (y / ry) * (y / ry) <= 1.0:
				out.append(c + Vector2(x, y))
			x += 6.0
		y += 6.0
	return out


func _layer_opaque(rec: Dictionary, mask: Dictionary, p: Vector2) -> bool:
	var lx := p.x - float(rec["x"])
	var ly := p.y - float(rec["y"])
	if lx < 0 or ly < 0 or lx >= float(rec["w"]) or ly >= float(rec["h"]):
		return false
	var step := float(mask["step"])
	var bx := int(lx / step)
	var by := int(ly / step)
	return (mask["bits"] as PackedByteArray)[by * int(mask["w"]) + bx] == 1


func _test_plots() -> void:
	var plots: Array = city.plots()
	check(plots.size() == 10, "ten player plots (%d)" % plots.size())
	var want := {"P1": "rare", "P2": "legendary", "P3": "rare", "P4": "normal", "P5": "normal"}
	var tiers := {}
	for p in plots:
		if not want.has(str(p["id"])):
			want[str(p["id"])] = str(p["tier"])
		tiers[str(p["tier"])] = true
	check(tiers.size() == 3, "the plots mix all three tiers")
	# Street mask from the painted plate, 1/4 size (the shipped ground is retextured).
	var ground: Image = null
	var gpath: String = city.path.get_base_dir().path_join("streets.png")
	if ResourceLoader.exists(gpath):
		var tex := load(gpath) as Texture2D
		if tex != null:
			ground = tex.get_image()
	if ground == null:
		ground = Image.load_from_file(ProjectSettings.globalize_path(gpath))
	check(ground != null and ground.get_width() * 4 == int(city.plate_size().x), "street mask readable")
	var walls: Array = []
	for rec in city.layers():
		if WALL_TAGS.has(str(rec["tag"])) and rec.has("mask"):
			walls.append([rec, PlateCity.unpack_mask(rec["mask"])])
	var z: WorldZone = city.zone
	var reach := _reach(city.spawn())
	var anchors: Array[Vector2] = []
	for p in plots:
		var id := str(p["id"])
		check(str(p["tier"]) == str(want.get(id, "")), "%s exterior tier is %s" % [id, want.get(id, "")])
		var anchor := Vector2(float(p["anchor_px"][0]), float(p["anchor_px"][1]))
		anchors.append(anchor)
		var pts := _ellipse_points(anchor)
		var on_wall := 0
		var on_tower := 0
		var on_street := 0
		var outside := 0
		for q in pts:
			for pair in walls:
				if _layer_opaque(pair[0], pair[1], q):
					on_wall += 1
					if TOWER_TAGS.has(str(pair[0]["tag"])):
						on_tower += 1
			if ground != null:
				var col := ground.get_pixel(clampi(int(q.x / 4.0), 0, ground.get_width() - 1), clampi(int(q.y / 4.0), 0, ground.get_height() - 1))
				if col.r > 0.5:
					on_street += 1
			var c := _cell_at(city.plate_to_world(q))
			if not z.in_bounds(c) or z.terrain_at(c) == "water":
				outside += 1
		check(on_wall == 0, "%s Legendary footprint clears the wall (%d hits)" % [id, on_wall])
		check(on_tower == 0, "%s Legendary footprint clears every tower" % id)
		check(on_street == 0, "%s Legendary footprint clears the streets (%d hits)" % [id, on_street])
		check(outside == 0, "%s Legendary footprint is on land inside the grid" % id)
		# Entrance: two walkable cells in front of the anchor, joined to the streets.
		var front: Array = p["front_cells"]
		check(front.size() >= 2, "%s lists two front cells" % id)
		var f1 := Vector2i(int(front[0][0]), int(front[0][1]))
		var f2 := Vector2i(int(front[1][0]), int(front[1][1]))
		check(z.passable_at(f1) and z.passable_at(f2), "%s front cells are walkable" % id)
		check(absi(f1.x - f2.x) + absi(f1.y - f2.y) == 1, "%s front cells touch" % id)
		var f1w: Vector2 = city.world_to_plate(BoardVisualSort.cell_to_local(f1))
		check(f1w.y > anchor.y and f1w.y - anchor.y < 48.0 and absf(f1w.x - anchor.x) < 40.0, "%s first front cell is right in front of the anchor" % id)
		check(reach.has(f1) and reach.has(f2), "%s entrance is reached from the street network" % id)
		var street_near := false
		for c in reach.keys():
			if z.terrain_at(c) == "dirt_road":
				street_near = true
				break
		check(street_near, "%s reach includes streets" % id)
		# The house blocks its own footprint.
		var base_cell := _cell_at(city.plate_to_world(anchor - Vector2(0, 30)))
		check(not z.passable_at(base_cell), "%s house footprint blocks" % id)
	# Plots never overlap: equal 2:1 ellipses are circles once y doubles.
	for i in anchors.size():
		for j in range(i + 1, anchors.size()):
			var a := anchors[i] - Vector2(0, LEGENDARY_W * 0.25)
			var b := anchors[j] - Vector2(0, LEGENDARY_W * 0.25)
			var d := Vector2(a.x - b.x, (a.y - b.y) * 2.0).length()
			check(d > LEGENDARY_W, "%s and %s Legendary footprints do not touch (%.0f px)" % [plots[i]["id"], plots[j]["id"], d])
	# P3 left the tower it sat on (tower at ref (530, 540) = plate (2650, 2700)).
	for p in plots:
		if str(p["id"]) == "P3":
			var anchor := Vector2(float(p["anchor_px"][0]), float(p["anchor_px"][1]))
			check(anchor.distance_to(Vector2(2650, 2700)) > 200.0, "P3 is off the tower")
	# Tier swap is data: every tier's art loads at a plot anchor.
	for t in ["normal", "rare", "legendary"]:
		check(city.house_size(t).x > 0.0, "%s house size in data" % t)
		check(city.clearance_px(t) > 0.0, "%s clearance in data" % t)
	check(is_equal_approx(city.clearance_px("legendary"), 350.0), "Legendary clearance is 350 px")


func _test_crossroads_untouched() -> void:
	var loaded: Dictionary = Maps.load_default()
	check(bool(loaded.get("ok", false)), "Crosshaven map still loads")
	if not bool(loaded.get("ok", false)):
		return
	var map: WorldMap = loaded["map"]
	check(map.zones.size() == 33, "Crosshaven keeps its 33 chunks")
	check(map.zone("crosshaven_city") == null, "the city is not a Crosshaven plane chunk")
	var cr: WorldZone = map.zone("crosshaven_crossroads")
	var stub: Dictionary = city.stub_at("crosshaven_crossroads", Vector2i(16, 27))
	check(not stub.is_empty(), "gate stub on the Crossroads at 16,27")
	check(cr.passable_at(Vector2i(16, 27)) and cr.exit_link(Vector2i(16, 27)).is_empty(), "stub cell is a free Crossroads cell")
	var back: Dictionary = city.stub_at("crosshaven_city", city.exit_cell())
	check(not back.is_empty() and cr.passable_at(Vector2i(int(back["to"]["x"]), int(back["to"]["y"]))), "city exit returns to a free Crossroads cell")


# ---------------------------------------------------------------- world

func _test_world_entry(w: Node2D) -> void:
	check(w.zone != null and w.zone.zone_id == "crosshaven_crossroads", "world still starts on the Crossroads")
	w.warp_city()
	await process_frame
	check(w.zone != null and w.zone.zone_id == "crosshaven_city", "dev warp enters the city")
	check(w.in_city() and w.city_plate != null, "city plate is drawn")
	check(w.walker.cell == city.spawn(), "hero stands on the city spawn")
	check(w.city_plate.ground_texture() != null, "ground texture loaded")
	check(w.city_plate.rows.size() >= 300, "map-base layers built (%d)" % w.city_plate.rows.size())
	# Item 17: map base first; buildings stay in data, hidden, footprints reserved.
	var hidden := 0
	for rec in city.layers():
		if bool(rec.get("hidden", false)):
			hidden += 1
			check(w.city_plate.row_of(int(rec["id"])).is_empty(), "hidden layer %d is not drawn" % int(rec["id"]))
	check(hidden >= 30, "buildings are hidden in data (%d)" % hidden)
	for row in w.city_plate.rows:
		check(not (str(row["tag"]) in ["house", "stall", "castle", "cathedral", "fountain", "well", "mill"]), "no building drawn (%s)" % row["tag"])
	var displaced := 0
	for rec in city.layers():
		if bool(rec.get("displaced_by_plot", false)):
			displaced += 1
	check((city.doc["building_footprints"] as Array).size() == hidden - displaced, "every hidden building keeps a reserved footprint, unless a plot displaced it")
	check(w.city_plate.plot_nodes.size() == (0 if city.plot_houses_hidden() else 10), "plot houses follow the map-base flag")
	w.city_plate.set_footprints_visible(true)
	check(w.city_plate.footprints.visible, "the footprint overlay turns on")
	w.city_plate.set_footprints_visible(false)
	for rec in city.layers():
		check(not ("thatch" in str(rec["file"])), "no thatched roof left (%s)" % rec["file"])
	var water: Sprite2D = w.city_plate.water
	check(water != null and water.visible, "the animated river is drawn")
	check(water != null and water.material is ShaderMaterial and (water.material as ShaderMaterial).get_shader_parameter("ripple") != null, "river shader has its ripple tile")
	check(water != null and water.z_index < w.city_plate.UNDER_Z, "river draws under the bridges")
	for id in w.city_plate.plot_nodes.keys():
		var node: Sprite2D = w.city_plate.plot_nodes[id]
		check(node.texture != null, "plot %s house texture" % id)
	var cam_w: int = w.camera.limit_right - w.camera.limit_left
	check(absi(cam_w - int(city.world_rect().size.x)) <= 1, "camera keeps to the plate (%d)" % cam_w)
	# Item 8: character to building scale at the plate scale in data.
	var hero_h: float = w.walker._strips.height()
	var hs := {"house": [], "gate_back": [], "stall": []}
	for rec in city.layers():
		if hs.has(str(rec["tag"])):
			(hs[str(rec["tag"])] as Array).append(float(rec["h"]) * float(rec.get("k", 1.0)) * city.scale())
	for t in hs.keys():
		(hs[t] as Array).sort()
	var house_r: float = float(hs["house"][hs["house"].size() / 2]) / hero_h
	var gate_r: float = float(hs["gate_back"][0]) / hero_h
	var gate_min := 1e9
	for g in city.gates():
		if g.has("art_height_px"):
			# the flat gatehouse (towers 1000 px in the art); the diagonal one adds its depth
			gate_min = minf(gate_min, float(g["art_height_px"]) / float(g.get("face_fit", 1.0)) * city.scale() / hero_h)
	if gate_min < 1e8:
		gate_r = gate_min
	var stall_r: float = float(hs["stall"][hs["stall"].size() / 2]) / hero_h
	check(house_r > 2.6 and house_r < 3.6, "a house is about 3 hero heights (%.2f)" % house_r)
	var ring: Dictionary = city.doc.get("wall_ring", {})
	var gate_want: float = 4.5
	if not ring.is_empty():
		gate_want = float(ring["targets_screen_px"]["gate"]) / float(ring["hero_screen_px"])
	check(absf(gate_r - gate_want) / gate_want < 0.15, "a gatehouse is about %.1f hero heights (%.2f)" % [gate_want, gate_r])
	if not ring.is_empty():
		var wall_h := 0.0
		var tower_h := 0.0
		for rec in city.layers():
			if str(rec["tag"]) in ["tower", "tower_g"]:
				tower_h = maxf(tower_h, float(rec["h"]) * city.scale())
		var tower_want := float(ring["targets_screen_px"]["tower"]) / float(ring["hero_screen_px"])
		check(absf(tower_h / hero_h - tower_want) / tower_want < 0.15, "a tower is about %.1f hero heights (%.2f)" % [tower_want, tower_h / hero_h])
	check(stall_r > 1.5 and stall_r < 2.6, "a stall is about 1.5-2 hero heights (%.2f)" % stall_r)
	print("SCALE plate %.2f: house %.2f gate %.2f stall %.2f (hero %.1f px)" % [city.scale(), house_r, gate_r, stall_r, hero_h])
	# Walk in through the gate.
	var target := Vector2i(int(city.bridges()[2]["ends"][1][0]), int(city.bridges()[2]["ends"][1][1]))
	var r: Dictionary = w.walk_to(target, "walk")
	check(bool(r.get("ok", false)), "click-walk to the west bridge end (%s)" % [r])
	_drive(w)
	check(w.walker.cell == target, "hero arrives over the river (%s)" % w.walker.cell)
	# No farm animals in the city.
	for c in w.fx._critters.get_children():
		check(not ("chicken" in str(c.name).to_lower()), "no chicken in the city")


func _test_sort(w: Node2D) -> void:
	var plate = w.city_plate
	var bad_front := 0
	var bad_back := 0
	var count := 0
	for row in plate.rows:
		if int(row["z"]) <= -3000:
			continue
		count += 1
		var sort_world_y: float = city.plate_to_world(Vector2(0, float(row["sort_y"]))).y
		# Hero feet 2 px in front of the sort line: the hero must draw on top.
		var zf := int(round((sort_world_y + 2.0) * 10.0 / 16.0)) + BoardVisualSort.UNIT_Z_BIAS
		if zf <= int(row["z"]):
			bad_front += 1
		# Feet 12 px behind it: the sprite draws on top.
		var zb := int(round((sort_world_y - 12.0) * 10.0 / 16.0)) + BoardVisualSort.UNIT_Z_BIAS
		if zb >= int(row["z"]):
			bad_back += 1
	check(count > 300, "y-sorted rows (%d)" % count)
	check(bad_front == 0, "no sprite sorts in front of a hero standing in front of it (%d bad)" % bad_front)
	check(bad_back == 0, "every sprite sorts over a hero behind it (%d bad)" % bad_back)
	# The real walker on many cells: rows north of its feet draw under it.
	var z: WorldZone = w.zone
	var sampled := 0
	var wrong := 0
	var cells := []
	for y in range(0, z.height, 3):
		for x in range(0, z.width, 3):
			if z.passable_at(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	for c in cells:
		w.walker.place(z, c)
		var feet: Vector2 = w.walker.position + Vector2(0, float(z.height_at(c)) * BoardVisualSort.ELEVATION_PIXELS)
		for row in plate.rows:
			if int(row["z"]) <= -3000:
				continue
			var sy: float = city.plate_to_world(Vector2(0, float(row["sort_y"]))).y
			if (row["rect"] as Rect2).grow(8).has_point(feet) and sy < feet.y - 1.0:
				sampled += 1
				if int(row["z"]) >= int(w.walker.z_index):
					wrong += 1
	check(sampled > 20, "walker sort sampled against overlapping sprites (%d)" % sampled)
	check(wrong == 0, "the walker draws over every sprite it stands in front of (%d wrong)" % wrong)
	# NPCs share the same sort.
	for npc in w.npcs_root.get_children():
		var feet_y: float = (npc as Node2D).position.y
		check(absi(int((npc as Node2D).z_index) - int(round(feet_y * 10.0 / 16.0))) <= 6, "NPC %s sorts by its feet" % npc.name)
	w.walker.place(z, city.spawn())


## A cell behind the cathedral: feet inside its art, north of its sort line.
func _cell_behind(w: Node2D, row: Dictionary) -> Vector2i:
	var z: WorldZone = w.zone
	var rect: Rect2 = row["rect"]
	var sort_world_y: float = city.plate_to_world(Vector2(0, float(row["sort_y"]))).y
	var best := Vector2i(-1, -1)
	for y in z.height:
		for x in z.width:
			var c := Vector2i(x, y)
			if not z.passable_at(c):
				continue
			var p := BoardVisualSort.cell_to_local(c)
			if rect.has_point(p - Vector2(0, 30)) and p.y < sort_world_y - 30.0 and p.y > rect.position.y + 80.0:
				var probe: Dictionary = row
				if w.city_plate._mask_hits(probe, Rect2(p.x - 13, p.y - 58, 26, 54)):
					return c
	return best


func _test_fade(w: Node2D) -> void:
	var plate = w.city_plate
	var target: Dictionary = {}
	for row in plate.rows:
		if str(row["tag"]) in OCCLUDERS and bool(row["fade"]):
			var c := _cell_behind(w, row)
			if c.x >= 0:
				target = row
				break
	check(not target.is_empty(), "found an occluder the hero can stand behind")
	if target.is_empty():
		return
	var cell := _cell_behind(w, target)
	w.walker.place(w.zone, cell)
	var feet: Vector2 = w.walker.position
	var covered: bool = plate.update_cover(feet, 0.0, w.walker.z_index, 1.0)
	check(covered, "hero behind an occluder is covered")
	check(float(target["alpha"]) <= 0.5 and plate.alpha_seen(target) <= 0.5, "the occluder fades to see-through (%.2f)" % float(target["alpha"]))
	if str(target["tag"]) in plate.LOCAL_FADE_TAGS:
		check((target["node"] as CanvasItem).modulate == Color(1, 1, 1, 1), "a structure fades only round the hero: the sprite keeps a neutral modulate")
	check(target in plate.covering(), "the house is listed as covering")
	# Ramp: from opaque, one 0.1 s tick goes part way.
	w.walker.place(w.zone, city.spawn())
	plate.update_cover(w.walker.position, 0.0, w.walker.z_index, 1.0)
	check(is_equal_approx(float(target["alpha"]), 1.0), "the house is opaque again once the hero leaves")
	w.walker.place(w.zone, cell)
	plate.update_cover(w.walker.position, 0.0, w.walker.z_index, 0.1)
	var mid := float(target["alpha"])
	check(mid < 1.0 and mid > float(target["min_alpha"]), "the fade ramps over time (%.2f after 0.1 s)" % mid)
	# Through the world loop: the walker gets its rim while covered.
	for i in 3:
		w._process(0.2)
	check(w.walker._covered, "the world loop marks the hero covered behind the house")
	# Walls fade too (Luca: every obstacle), via a south wall row.
	var wall_ok := false
	for row in plate.rows:
		if str(row["tag"]) == "wall" and bool(row["fade"]):
			var c2 := _cell_behind(w, row)
			if c2.x >= 0:
				w.walker.place(w.zone, c2)
				plate.update_cover(w.walker.position, 0.0, w.walker.z_index, 1.0)
				wall_ok = float(row["alpha"]) <= 0.5 and (row["node"] as CanvasItem).material is ShaderMaterial and (row["node"] as CanvasItem).modulate.a == 1.0
				break
	check(wall_ok, "a wall fades while the hero is behind it")
	w.walker.place(w.zone, city.spawn())
	plate.update_cover(w.walker.position, 0.0, w.walker.z_index, 1.0)


func _test_life(w: Node2D) -> void:
	var npcs: Array = w.npcs_root.get_children()
	check(npcs.size() == city.npcs().size() and npcs.size() >= 10, "townsfolk spawn (%d)" % npcs.size())
	var movers := 0
	for n in npcs:
		if n.allowed_cells().size() > 1:
			movers += 1
	check(movers >= 3, "walkers and the warden roam (%d)" % movers)
	w.weather.time_of_day = 23.0
	w._sync_city_life()
	var shown := 0
	for n in npcs:
		if (n as Node2D).visible:
			shown += 1
			check(str(n.name) == "Npc_city_warden", "only the warden is out at night (%s)" % n.name)
	check(shown == 1, "night: one NPC out (%d)" % shown)
	w.city_plate.tick_pets(0.1)
	for p in w.city_plate.pet_nodes:
		var node: Sprite2D = p["node"]
		check(node.visible == (str(p["night"]) == "out"), "night pet %s follows its schedule" % node.name)
	w.weather.time_of_day = 12.0
	w._sync_city_life()
	var day_shown := 0
	for n in npcs:
		if (n as Node2D).visible:
			day_shown += 1
	check(day_shown == npcs.size(), "day: everyone is out")
	var before: Array = []
	for p in w.city_plate.pet_nodes:
		before.append((p["node"] as Node2D).position)
	for i in 20:
		w.city_plate.tick_pets(0.1)
	var moved := 0
	for i in w.city_plate.pet_nodes.size():
		if (w.city_plate.pet_nodes[i]["node"] as Node2D).position.distance_to(before[i]) > 1.0:
			moved += 1
	check(moved == w.city_plate.pet_nodes.size() and moved > 0, "pets trot by day (%d)" % moved)


func _test_performance(w: Node2D) -> void:
	check(not w.city_plate.ground_is_lite(), "full ground outside Performance mode")
	w.settings.set_performance(true)
	check(w.in_city(), "still in the city after the Performance switch")
	check(w.city_plate.ground_is_lite(), "Performance mode draws the half-size ground")
	check(w.city_plate.water == null or not w.city_plate.water.visible, "Performance mode keeps the painted still water")
	var tex: Texture2D = w.city_plate.ground_texture()
	check(tex != null and tex.get_width() == 2560, "lite ground is 2560 wide")
	check((tex.get_size() * w.city_plate._ground.scale).is_equal_approx(city.plate_size() * city.scale()), "lite ground still covers the plate")
	# Instant fades: one tiny tick reaches the min alpha.
	var target: Dictionary = {}
	var cell := Vector2i(-1, -1)
	for row in w.city_plate.rows:
		if str(row["tag"]) in OCCLUDERS and bool(row["fade"]):
			cell = _cell_behind(w, row)
			if cell.x >= 0:
				target = row
				break
	if not target.is_empty():
		w.walker.place(w.zone, cell)
		w.city_plate.update_cover(w.walker.position, 0.0, w.walker.z_index, 0.001)
		var low := float(target["min_alpha"])
		if str(target["tag"]) in w.city_plate.LOCAL_FADE_TAGS:
			low = maxf(low, w.city_plate.LOCAL_MIN_ALPHA)
		check(is_equal_approx(float(target["alpha"]), low), "Performance mode fades at once")
	for n in w.npcs_root.get_children():
		check(is_equal_approx(float(n.idle_rate), w.LITE_IDLE_RATE), "NPC %s idles at the lite rate" % n.name)
	w.settings.set_performance(false)
	check(not w.city_plate.ground_is_lite(), "full ground back after Performance mode")
	w.walker.place(w.zone, city.spawn())


## Mauro: "asegúrate que el mono pase por ellas sin problemas". The hero walks
## through every gate from outside to inside and back, on the real walker.
func _test_gate_walks(w: Node2D) -> void:
	var z: WorldZone = w.zone
	for g in city.gates():
		var cells: Array = g.get("cells", [])
		if cells.size() < 2:
			check(false, "%s has passage cells" % g["id"])
			continue
		var outs: Array[Vector2i] = []
		var ins: Array[Vector2i] = []
		for c in cells:
			var cc := Vector2i(int(c[0]), int(c[1]))
			if _in_wall(city.world_to_plate(BoardVisualSort.cell_to_local(cc))):
				ins.append(cc)
			else:
				outs.append(cc)
		if outs.is_empty() or ins.is_empty():
			check(false, "%s passage has cells on both sides" % g["id"])
			continue
		var a: Vector2i = outs[0]
		var b: Vector2i = ins[0]
		for c in outs:
			for d in ins:
				if (c - d).length_squared() > (a - b).length_squared():
					a = c
					b = d
		var out_c := _free_beyond(z, a, a - b)
		var in_c := _free_beyond(z, b, b - a)
		var gate_set := {}
		for c in cells:
			gate_set[Vector2i(int(c[0]), int(c[1]))] = true
		for leg in [[out_c, in_c, "in"], [in_c, out_c, "out"]]:
			w.walker.place(z, leg[0])
			var r: Dictionary = w.walk_to(leg[1], "walk")
			check(bool(r.get("ok", false)), "%s: walk %s (%s -> %s)" % [g["id"], leg[2], leg[0], leg[1]])
			var through := false
			for step in r.get("path", []):
				if gate_set.has(Vector2i(int(step["x"]), int(step["y"]))):
					through = true
			check(through, "%s: the walk %s goes through the arch" % [g["id"], leg[2]])
			# no snagging: the route through the arch is close to straight
			var direct: int = absi((leg[1] as Vector2i).x - (leg[0] as Vector2i).x) + absi((leg[1] as Vector2i).y - (leg[0] as Vector2i).y)
			var steps: int = (r.get("path", []) as Array).size() - 1
			check(steps <= direct + 2, "%s: the walk %s runs straight through (%d steps for %d)" % [g["id"], leg[2], steps, direct])
			_drive(w)
			check(w.walker.cell == leg[1], "%s: the hero gets %s (%s)" % [g["id"], leg[2], w.walker.cell])
	w.walker.place(z, city.spawn())


func _free_beyond(z: WorldZone, from: Vector2i, dir: Vector2i) -> Vector2i:
	var step := Vector2i(signi(dir.x), signi(dir.y))
	var best := from
	for k in range(1, 5):
		var c := from + step * k
		if z.passable_at(c):
			best = c
	return best


# ------------------------------------------------- coordinator review (c80e4cab)

func _test_review_data() -> void:
	var ring: Dictionary = city.doc.get("wall_ring", {})
	var hero_plate: float = float((ring.get("factors", {}) as Dictionary).get("hero_plate_px", 54.52))
	var passage_px: float = 2.2 * 0.6 * hero_plate
	var wall_h: float = 550.0 * float((ring.get("factors", {}) as Dictionary).get("module_scale", 0.3495))
	# 2: the gatehouse curtain face matches the run's face; the arch stays wide.
	for g in city.gates():
		if str(g["id"]) in ["N", "S"]:
			check(str(g["art"]) == "gatehouse_horizontal_CONCEPTO.png" and is_zero_approx(float(g["shear"])), "%s uses the horizontal gatehouse with no shear (%s %.3f)" % [g["id"], g["art"], float(g["shear"])])
		else:
			check(str(g["art"]).begins_with("gatehouse_diag_v3"), "%s uses the diagonal gatehouse (%s)" % [g["id"], g["art"]])
			check(absf(absf(float(g["shear"])) - 0.1367) < 0.01, "%s parapet-matched shear (%.3f)" % [g["id"], float(g["shear"])])
		check(float(g.get("art_drop_px", -1.0)) > 0.0, "%s parapet drop in data (%.1f)" % [g["id"], float(g.get("art_drop_px", -1.0))])
		# hero width as the art team measures it: 48 px at a 156 px hero
		var arch_min: float = 2.2 * (48.0 / 156.0) * hero_plate
		check(float(g.get("arch_open_px", 0.0)) >= arch_min, "%s arch opening %.1f px >= 2.2 hero widths (%.1f)" % [g["id"], float(g.get("arch_open_px", 0.0)), arch_min])
		check(float(g.get("passage_half_width_px", 0.0)) * 2.0 >= passage_px - 0.5, "%s passage is 2.2 hero widths" % g["id"])
	# Round 4: horizontal gatehouse v5 at N and S (1752x1041, towers 433 px wide).
	var k_mod: float = float((ring.get("factors", {}) as Dictionary).get("module_scale", 0.3495))
	for g in city.gates():
		if not (str(g["id"]) in ["N", "S"]):
			continue
		check(absf(float(g["art_height_px"]) - 1041.0 * k_mod) < 2.0, "%s uses the v5 horizontal gatehouse (%.1f px tall)" % [g["id"], float(g["art_height_px"])])
		check(absf(float(g["art_drop_px"]) - 27.0 * k_mod) < 0.5, "%s parapet drop 27 art px (577 vs 550) in data (%.1f)" % [g["id"], float(g["art_drop_px"])])
		# the flanking towers' bases stay off the road through the arch
		var tower_r: float = 433.0 * 0.5 * k_mod * 0.92
		var hits := 0
		for c in g["cells"]:
			var p: Vector2 = city.world_to_plate(BoardVisualSort.cell_to_local(Vector2i(int(c[0]), int(c[1]))))
			for key in ["wall_join_left", "wall_join_right"]:
				var t := Vector2(float(g[key][0]), float(g[key][1]))
				if ((p.x - t.x) / tower_r) ** 2 + ((p.y - t.y) / (tower_r * 0.5)) ** 2 <= 1.0:
					hits += 1
		check(hits == 0, "%s flanking towers stay off the passage (%d cells under a tower)" % [g["id"], hits])
	# 3: no ring tower within about one wall height of a gatehouse.
	for rec in city.layers():
		if str(rec["tag"]) != "tower" or bool(rec.get("corner", false)):
			continue
		var foot := _tower_foot(rec)
		for g in city.gates():
			var arch := Vector2(float(g["arch"][0]), float(g["arch"][1]))
			var gap: float = foot.distance_to(arch) - float(g["half_span"]) - float(rec["w"]) * 0.42
			check(gap >= wall_h * 1.25, "tower %d keeps a wall height from gate %s (%.0f px)" % [int(rec["id"]), g["id"], gap])
	# Round 5: every ring corner has a tower unless a gatehouse covers it.
	var poly_c: Array = city.doc["wall_polygon"]
	for q in poly_c:
		var cpt := Vector2(float(q[0]), float(q[1]))
		var has_tower := false
		for rec in city.layers():
			if str(rec["tag"]) == "tower" and bool(rec.get("corner", false)):
				var f := _tower_foot(rec)
				if f.distance_to(cpt) < 30.0:
					has_tower = true
		var gated := false
		for g in city.gates():
			if Vector2(float(g["arch"][0]), float(g["arch"][1])).distance_to(cpt) < float(g["half_span"]) + 10.0:
				gated = true
		# round 8: or a gatehouse tower standing on the corner (snapped)
		for g in city.gates():
			for key in ["wall_join_left", "wall_join_right"]:
				if Vector2(float(g[key][0]), float(g[key][1])).distance_to(cpt) < 30.0:
					gated = true
		check(has_tower or gated, "corner %s is closed by a tower or a gatehouse tower" % cpt)
		# no gap: every run that reaches this corner ends under the tower there
		var r_body: float = float(city.doc.get("tower_body_radius_px", 60.0))
		for rr in city.doc.get("wall_runs", []):
			for key in ["a", "b"]:
				var e := Vector2(float(rr[key][0]), float(rr[key][1]))
				if e.distance_to(cpt) < 3.0 * r_body:
					check(e.distance_to(cpt) <= r_body + 0.5, "corner %s: run end %s is under the corner tower (%.1f px)" % [cpt, e, e.distance_to(cpt)])
	# Round 8: the runs either side of every tower share one foot line and
	# end under the tower; every ring tower is the v5 tower.
	var r_b: float = float(city.doc.get("tower_body_radius_px", 60.0))
	var ends_at := {}
	for rr in city.doc.get("wall_runs", []):
		for pair in [["start_at", "a", "a_px"], ["end_at", "b", "b_px"]]:
			var ref: Variant = rr.get(pair[0])
			if ref == null or not (str(ref["kind"]) in ["tower", "gtower"]):
				continue
			var key := "%.1f,%.1f" % [float(ref["at"][0]), float(ref["at"][1])]
			if not ends_at.has(key):
				ends_at[key] = []
			(ends_at[key] as Array).append([rr[pair[1]], rr.get(pair[2]), ref["at"], int(rr["edge"])])
	var pairs := 0
	for key in ends_at.keys():
		var lst: Array = ends_at[key]
		for e in lst:
			var ep := Vector2(float(e[0][0]), float(e[0][1]))
			var tp := Vector2(float(e[2][0]), float(e[2][1]))
			check(ep.distance_to(tp) <= r_b + 0.5, "tower %s: run end %s is under the tower (%.1f <= %.1f)" % [key, ep, ep.distance_to(tp), r_b])
		if lst.size() == 2 and lst[0][1] != null and lst[1][1] != null:
			pairs += 1
			var fa: float = float(lst[0][1]["foot"])
			var fb: float = float(lst[1][1]["foot"])
			check(absf(fa - fb) <= 2.0, "tower %s: the runs either side share the foot line (%.1f vs %.1f)" % [key, fa, fb])
			if int(lst[0][3]) == int(lst[1][3]):
				# along a wall (same module both sides) the merlon line runs on too
				var ta: float = float(lst[0][1]["tip"])
				var tb: float = float(lst[1][1]["tip"])
				check(absf(ta - tb) <= 2.0, "tower %s: the runs either side share the merlon line (%.1f vs %.1f)" % [key, ta, tb])
	check(pairs >= 2, "towers with runs on both sides checked (%d)" % pairs)
	for rec in city.layers():
		if str(rec["tag"]) == "tower":
			check(str(rec.get("module", "")) == "tower_v5_CONCEPTO.png", "tower %d is the v5 tower (%s)" % [int(rec["id"]), rec.get("module", "")])
	# Round 5: a clear plaza at every gate and water gate (no trees).
	var clear_cfg: Dictionary = city.doc.get("gate_clear", {})
	check(not clear_cfg.is_empty(), "gate clearance in data")
	var zones: Array = []
	for g in city.gates():
		zones.append([Vector2(float(g["arch"][0]), float(g["arch"][1])), float(g.get("art_width_px", 400.0))])
	for wg in city.doc.get("water_gates", []):
		zones.append([Vector2(float(wg["at"][0]), float(wg["at"][1])), float(wg.get("art_width_px", 400.0))])
	check(zones.size() == 7, "5 gates and 2 water gates get a clear plaza (%d)" % zones.size())
	var mul: float = float(clear_cfg.get("width_mul", 1.0))
	var in_plaza := 0
	for rec in city.layers():
		if str(rec["tag"]) != "tree":
			continue
		var tf := Vector2(float(rec["x"]) + float(rec["w"]) * float(rec.get("k", 1.0)) * 0.5, float(rec["sort_y"]))
		for zn in zones:
			var a: Vector2 = zn[0]
			var wd: float = float(zn[1]) * mul
			if ((tf.x - a.x) / wd) ** 2 + ((tf.y - a.y) / (wd * 0.5)) ** 2 <= 1.0:
				in_plaza += 1
	check(in_plaza == 0, "no tree stands in a gate plaza (%d)" % in_plaza)
	# 6: an outer ring of trees, outside the walls, off the roads and the river.
	var outer := 0
	var streets: Image = Image.load_from_file(ProjectSettings.globalize_path(city.path.get_base_dir().path_join("streets.png")))
	for rec in city.layers():
		if str(rec.get("spot", "")) != "outer_forest":
			continue
		outer += 1
		var k := float(rec.get("k", 1.0))
		var foot := Vector2(float(rec["x"]) + float(rec["w"]) * k * 0.5, float(rec["sort_y"]))
		check(not _in_wall(foot), "outer tree %d stands outside the walls" % int(rec["id"]))
		check(str(rec.get("plant", "")).begins_with("tree_oak") or str(rec.get("plant", "")).begins_with("tree_cypress"), "outer tree %d is approved oak or cypress art" % int(rec["id"]))
		var sx := clampi(int(foot.x / 4.0), 0, streets.get_width() - 1)
		var sy := clampi(int(foot.y / 4.0), 0, streets.get_height() - 1)
		check(streets.get_pixel(sx, sy).r < 0.5, "outer tree %d is off the roads" % int(rec["id"]))
		var cell: Vector2i = _cell_at(city.plate_to_world(foot))
		check(city.zone.terrain_at(cell) != "water", "outer tree %d is off the river" % int(rec["id"]))
	check(outer >= 120 and outer <= 160, "120-160 trees outside the walls (%d)" % outer)
	# 7: every gate road ends in an exit to a region road (data).
	var stubs: Array = city.stubs_from(PlateCity.CITY_ID)
	var plate: Vector2 = city.plate_size()
	var reach := _reach(city.spawn())
	for g in city.gates():
		if str(g["id"]) == "S":
			check(not city.stub_at(PlateCity.CITY_ID, city.exit_cell()).is_empty(), "S road keeps the Crossroads exit")
			continue
		var stub: Dictionary = {}
		for st in stubs:
			if str(st.get("gate", "")) == str(g["id"]):
				stub = st
		check(not stub.is_empty(), "%s road ends in an exit stub" % g["id"])
		if stub.is_empty():
			continue
		var end: Array = g["road_out_end"]
		var at_edge: bool = float(end[0]) <= 60.0 or float(end[1]) <= 60.0 or float(end[0]) >= plate.x - 60.0 or float(end[1]) >= plate.y - 60.0
		check(at_edge, "%s road runs to the zone edge (%s)" % [g["id"], end])
		var from := Vector2i(int(stub["from"]["x"]), int(stub["from"]["y"]))
		check(reach.has(from), "%s exit cell %s is walkable and joined" % [g["id"], from])
		check(str(stub.get("status", "")) in ["proposed", "placeholder"], "%s exit link is marked proposed or placeholder" % g["id"])
	# 1: tile scales in data.
	var tex: Dictionary = (city.doc["plate"] as Dictionary).get("ground_textures", {})
	if tex.is_empty():
		tex = _layout().get("ground_textures", {})
	check(is_equal_approx(float(tex.get("cobble_scale", 1.0)), 0.35), "cobble tile at 0.35x")
	check(is_equal_approx(float(tex.get("grass_scale", 1.0)), 0.7), "grass tile at 0.7x")
	check(tex.has("grass_layer2"), "a second grass layer breaks the repeat")


func _layout() -> Dictionary:
	var f := "res://build_tools/crosshaven_city/layout_rosebud_v9.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
	return parsed if parsed is Dictionary else {}


func _test_review_world(w: Node2D) -> void:
	var cp = w.city_plate
	# 4: name plates hide behind walls (the fade's occlusion test).
	var wall_row: Dictionary = {}
	for row in cp.rows:
		if str(row["tag"]) == "wall" and (row["rect"] as Rect2).size.y > 120.0:
			wall_row = row
			break
	check(not wall_row.is_empty(), "a wall strip to stand behind")
	if not wall_row.is_empty():
		var r: Rect2 = wall_row["rect"]
		var behind := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.55)
		check(cp.occluded(behind, int(wall_row["z"]) - 20), "a body behind a wall is occluded")
		check(not cp.occluded(behind + Vector2(0, r.size.y), int(wall_row["z"]) + 50), "a body in front of the wall is not")
		var npc: Node2D = null
		for node in w.npcs_root.get_children():
			if node is Node2D and node.get("_plate") != null and (node as Node2D).visible:
				npc = node
				break
		check(npc != null, "a city NPC with a name plate")
		if npc != null:
			var keep_pos := npc.position
			var keep_z := npc.z_index
			npc.position = behind
			npc.z_index = int(wall_row["z"]) - 20
			w._sync_city_labels()
			check(not (npc.get("_plate") as CanvasItem).visible, "the name plate hides behind the wall")
			npc.position = keep_pos
			npc.z_index = keep_z
			w._sync_city_labels()
	# 5: lamps light at dusk and night, not by day; Performance mode keeps them still.
	check(cp.lights.size() >= 10, "lamp lights built (%d)" % cp.lights.size())
	cp.set_hour(12.0)
	var lit := 0
	for l in cp.lights:
		if (l["halo"] as CanvasItem).visible:
			lit += 1
	check(lit == 0, "no lamp light at noon (%d)" % lit)
	cp.set_hour(22.0)
	lit = 0
	var pools := 0
	for l in cp.lights:
		if (l["halo"] as CanvasItem).visible:
			lit += 1
		if l["pool"] != null and (l["pool"] as CanvasItem).visible:
			pools += 1
	check(lit == cp.lights.size(), "every lamp head glows at night (%d/%d)" % [lit, cp.lights.size()])
	check(pools >= 10, "a light circle on the ground under each lamp (%d)" % pools)
	for l in cp.lights:
		check((l["halo"] as CanvasItem).material is CanvasItemMaterial and ((l["halo"] as CanvasItem).material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "lamp halo is additive")
		break
	cp.set_hour(18.5)
	check((cp.lights[0]["halo"] as CanvasItem).visible, "lamps are lit at dusk")
	var was_lite: bool = cp.lite
	cp.lite = true
	var a0: float = (cp.lights[0]["halo"] as CanvasItem).modulate.a
	cp.tick_lights(0.37)
	cp.tick_lights(0.41)
	check(is_equal_approx((cp.lights[0]["halo"] as CanvasItem).modulate.a, a0), "Performance mode: the lamp light stays still")
	cp.set_hour(22.0)
	var lit_points := 0
	for l in cp.lights:
		if l["light"] != null and (l["light"] as PointLight2D).enabled:
			lit_points += 1
	check(lit_points == 0, "Performance mode: no point lights (%d)" % lit_points)
	cp.lite = false
	cp.set_hour(22.0)
	lit_points = 0
	for l in cp.lights:
		if l["light"] != null and (l["light"] as PointLight2D).enabled:
			lit_points += 1
	check(lit_points >= 10, "a point light per lamp at night (%d)" % lit_points)
	cp.lite = was_lite
	cp.set_hour(12.0)
	# 7: an exit stub takes the hero to its region road.
	for st in city.stubs_from(PlateCity.CITY_ID):
		if str(st.get("gate", "")) == "":
			continue
		var to: Dictionary = st["to"]
		var f := "res://data/world/crosshaven/zones/%s.json" % str(to["zone_id"])
		check(FileAccess.file_exists(f), "exit %s leads to a known zone (%s)" % [st["id"], to["zone_id"]])
		if not FileAccess.file_exists(f):
			continue
		var zd: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
		var ok := false
		for t in (zd as Dictionary).get("tiles", []):
			if int(t["x"]) == int(to["x"]) and int(t["y"]) == int(to["y"]):
				ok = bool(t.get("walkable", false))
		check(ok, "exit %s lands on a walkable cell" % st["id"])


func _test_gate_stub(w: Node2D) -> void:
	# Out: walk onto the road end.
	var r: Dictionary = w.walk_to(city.exit_cell(), "walk")
	check(bool(r.get("ok", false)), "walk to the city road exit")
	_drive(w)
	await process_frame
	check(w.zone != null and w.zone.zone_id == "crosshaven_crossroads", "the road exit leads to the Crossroads (%s)" % (w.zone.zone_id if w.zone else "none"))
	check(not w.in_city() and w.city_plate == null, "the plate is freed on leaving")
	check(w._stub_marker != null and w._stub_marker.visible, "the gate stub is marked on the Crossroads")
	# In: walk onto the stub cell.
	var r2: Dictionary = w.walk_to(Vector2i(16, 27), "walk")
	check(bool(r2.get("ok", false)), "walk to the Crossroads gate stub (%s)" % [r2])
	_drive(w)
	await process_frame
	check(w.zone != null and w.zone.zone_id == "crosshaven_city", "the gate stub leads into the city")
	check(w.walker.cell == city.spawn(), "the stub lands on the city road")
	w.warp_city()
	await process_frame
	check(w.zone.zone_id == "crosshaven_crossroads", "dev warp leaves the city")


## A ring tower's point on the wall line (round 8 towers stand in front of it).
func _tower_foot(rec: Dictionary) -> Vector2:
	if rec.has("wall_point"):
		return Vector2(float(rec["wall_point"][0]), float(rec["wall_point"][1]))
	return Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["sort_y"]) - 10.0)
