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


## Round 18: the plate is Mauro's ring v4 image (painted river, lamps and
## bridges; no kit ring, no separate buildings).
func _image_plate() -> bool:
	return str((city.doc.get("wall_ring", {}) as Dictionary).get("source", "")) == "image"


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
	if _image_plate():
		_test_image_ring()
	else:
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


var _lift_seen := 0.0


func _gate_lift_max(w: Node2D) -> float:
	var m := 0.0
	if w.city_plate != null:
		for gf in w.city_plate.gates_fx:
			m = maxf(m, float(gf["lift"]))
	return m


func _drive(w: Node2D, max_steps: int = 6000) -> void:
	var n := 0
	while w.walker.is_moving() and n < max_steps:
		w.tick_city_gates(0.05)
		w.walker.advance(0.05)
		_lift_seen = maxf(_lift_seen, _gate_lift_max(w))
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
	check(_image_plate() or (trees >= 6 and trees <= 25), "trees cut to about 20, fewer after the gate plazas (%d)" % trees)
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
	check(_image_plate() or plants >= 150, "bushes and flowers scattered (%d)" % plants)
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
	check(city.bridges().size() == 2, "two bridges in the data (the NE one outside the wall is removed)")
	for b in city.bridges():
		check(str(b["id"]) != "bridge_1", "the NE bridge outside the water gate is gone")
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
		check(top >= 5 or _image_plate(), "%s deck rises to the crown (step %d)" % [b["id"], top])
		# Crossing: a path from one end to the other climbs the deck.
		var cross: Dictionary = WorldWalk.find_path(city.map, "crosshaven_city", a, "crosshaven_city", c)
		check(bool(cross.get("ok", false)), "%s can be crossed" % b["id"])
		var climb := 0
		for step in cross.get("path", []):
			climb = maxi(climb, z.height_at(Vector2i(int(step["x"]), int(step["y"]))))
		check((climb >= 5 or _image_plate()) and (cross.get("path", []) as Array).size() <= 24, "%s crossing goes over the deck (top %d, %d steps)" % [b["id"], climb, (cross.get("path", []) as Array).size()])
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
	check(gates.size() == 4, "4 land gatehouses (%d)" % gates.size())
	var ids := {}
	for g in gates:
		ids[str(g["id"])] = true
	for g in gates:
		check(str(g["id"]) != "SE", "the SE gate is removed")
	for want in ["S", "W", "E", "N"]:
		check(ids.has(want), "gatehouse %s exists" % want)
	# Ring on the 3 plate directions: every edge horizontal or an iso diagonal.
	var poly: Array = city.doc["wall_polygon"]
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var dx := float(b[0]) - float(a[0])
		var slope := 999.0 if is_zero_approx(dx) else (float(b[1]) - float(a[1])) / dx
		check(_image_plate() or is_zero_approx(slope) or is_equal_approx(absf(slope), 0.5), "wall edge %d runs on a plate direction (%.3f)" % [i, slope])
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
		if not (str(rec["tag"]) in ["tower", "tower_g"]) or rec.has("module") or _image_plate():
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
	check(_image_plate() or towers >= 12 or kit_towers >= 4, "towers checked (%d prototype, %d kit)" % [towers, kit_towers])


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
	check(hidden >= 30 or _image_plate(), "buildings are hidden in data (%d)" % hidden)
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
	check(not _image_plate() or water == null, "image plate: the river is painted (no shader layer)")
	if not _image_plate():
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
	if _image_plate():
		# Round 18: the image sets the scale; the plate scale stays until Mauro decides.
		var t_h := 0.0
		for rec in city.layers():
			if str(rec["tag"]) == "tower":
				t_h = maxf(t_h, float(rec["h"]) * city.scale())
		check(t_h > hero_h, "image towers stand over the hero (%.2f hero heights)" % (t_h / hero_h))
		print("SCALE image plate %.2f: tower %.2f hero heights" % [city.scale(), t_h / hero_h])
	if not _image_plate():
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
	var west: Dictionary = city.bridges()[city.bridges().size() - 1]
	var target := Vector2i(int(west["ends"][1][0]), int(west["ends"][1][1]))
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
	if not _image_plate():
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
		var gf: Dictionary = w.city_plate.gate_fx(str(g["id"]))
		if _image_plate():
			check(not gf.is_empty(), "%s has a portcullis" % g["id"])
		for leg in [[out_c, in_c, "in"], [in_c, out_c, "out"]]:
			w.walker.place(z, leg[0])
			if not gf.is_empty():
				# nobody near: the grate comes down and the arch cells hold
				_settle_gates(w, [], 3.0)
				check(float(gf["lift"]) == 0.0, "%s portcullis is down when nobody is near" % g["id"])
				var bc: Array = (gf["block"] as Dictionary).keys()
				check(not bc.is_empty() and w.city_plate.gate_closed_at(bc[0]), "%s arch cells hold while the grate is down" % g["id"])
				_lift_seen = 0.0
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
			if not gf.is_empty():
				check(_lift_seen >= 1.0, "%s portcullis rose all the way for the walk %s (%.2f)" % [g["id"], leg[2], _lift_seen])
				# someone at the arch, then nobody: it stays up 1.5 s, then is down after 0.6 s more
				_settle_gates(w, [gf["at"]], 0.1)
				_settle_gates(w, [], 1.2)
				check(float(gf["lift"]) == 1.0, "%s portcullis waits before it drops" % g["id"])
				_settle_gates(w, [], 1.0)
				check(float(gf["lift"]) == 0.0, "%s portcullis drops once nobody is near" % g["id"])
	w.walker.place(z, city.spawn())


## Tick only the gates, with the given bodies near them (no hero).
func _settle_gates(w: Node2D, bodies: Array, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		w.city_plate.tick_gates(0.05, bodies, w.walker._strips.height())
		t += 0.05


func _free_beyond(z: WorldZone, from: Vector2i, dir: Vector2i) -> Vector2i:
	var step := Vector2i(signi(dir.x), signi(dir.y))
	var best := from
	for k in range(1, 5):
		var c := from + step * k
		if z.passable_at(c):
			best = c
	return best


# ------------------------------------------------- coordinator review (c80e4cab)

## Round 18: Mauro's ring v4 image as the plate, towers cut to 12.
func _test_image_ring() -> void:
	var ring: Dictionary = city.doc["wall_ring"]
	var towers: Array = []
	var kinds := {}
	for rec in city.layers():
		if str(rec["tag"]) == "tower":
			towers.append(rec)
			kinds[str(rec.get("tower_kind", ""))] = int(kinds.get(str(rec.get("tower_kind", "")), 0)) + 1
	check(towers.size() == 12, "12 towers kept (%d)" % towers.size())
	check(int(ring.get("towers_kept", 0)) == towers.size(), "the ring data lists the kept towers")
	check((ring.get("towers_removed", []) as Array).size() == 6, "6 towers painted out (%d)" % (ring.get("towers_removed", []) as Array).size())
	check(int(kinds.get("gate", 0)) == 7 and int(kinds.get("water_gate", 0)) == 3 and int(kinds.get("mid", 0)) == 2, "towers: 7 at the land gates, 3 by the tunnels, 2 mid-wall (%s)" % kinds)
	# every land gate has a tower at its side
	for g in city.gates():
		var arch := Vector2(float(g["arch"][0]), float(g["arch"][1]))
		var near := 0
		for t in towers:
			if _tower_foot(t).distance_to(arch) < 420.0:
				near += 1
		check(near >= (1 if str(g["id"]) == "E" else 2), "gate %s is flanked by its towers (%d)" % [g["id"], near])
	# both water tunnels list two flanking towers, each one a kept tower
	var wgs: Array = city.doc.get("water_gates", [])
	check(wgs.size() == 2, "two water tunnels (%d)" % wgs.size())
	for wg in wgs:
		var fl: Array = wg.get("flank_towers", [])
		check(fl.size() == 2, "water tunnel %s has two flanking towers (%d)" % [wg["id"], fl.size()])
		for f in fl:
			var hit := false
			for t in towers:
				if _tower_foot(t).distance_to(Vector2(float(f[0]), float(f[1]))) < 4.0:
					hit = true
			check(hit, "water tunnel %s flank %s is a kept tower" % [wg["id"], f])
	# walls and towers are y-sorted fading layers with a fade mask
	var walls := 0
	for rec in city.layers():
		if str(rec["tag"]) in ["wall", "tower"]:
			if str(rec["tag"]) == "wall":
				walls += 1
			check(bool(rec["fade"]) and rec.has("mask"), "%s %d fades with a mask" % [rec["tag"], int(rec["id"])]) if not (bool(rec["fade"]) and rec.has("mask")) else null
			var sy := float(rec["sort_y"])
			check(sy >= float(rec["y"]) and sy <= float(rec["y"]) + float(rec["h"]) + 16.0, "%s %d sorts on its own foot line" % [rec["tag"], int(rec["id"])]) if not (sy >= float(rec["y"]) and sy <= float(rec["y"]) + float(rec["h"]) + 16.0) else null
	check(walls > 150, "the wall ring is cut into sorted strips (%d)" % walls)
	# tower bases block, the gates do not
	var z: WorldZone = city.zone
	for t in towers:
		var c := _cell_at(city.plate_to_world(_tower_foot(t) + Vector2(0, -20)))
		check(not z.passable_at(c), "tower %s blocks its base" % t.get("name", t["id"]))
	# the ground is the image x4
	var src: Array = city.doc["plate"].get("source_image_px", [0, 0])
	check(int(src[0]) * 4 == int(city.plate_size().x) and int(src[1]) * 4 == int(city.plate_size().y), "the plate is the image x4 (%s)" % [src])


func _test_review_data() -> void:
	var ring: Dictionary = city.doc.get("wall_ring", {})
	var hero_plate: float = float((ring.get("factors", {}) as Dictionary).get("hero_plate_px", 54.52))
	var passage_px: float = 2.2 * 0.6 * hero_plate
	var wall_h: float = 550.0 * float((ring.get("factors", {}) as Dictionary).get("module_scale", 0.3495))
	# 2: the gatehouse curtain face matches the run's face; the arch stays wide.
	for g in city.gates():
		if str(g["id"]) in ["N", "S"]:
			check(str(g["art"]) == "gatehouse_horizontal_v8_CONCEPTO.png" and is_zero_approx(float(g["shear"])), "%s uses the horizontal gatehouse with no shear (%s %.3f)" % [g["id"], g["art"], float(g["shear"])])
		else:
			check(str(g["art"]).begins_with("gatehouse_diagonal_v8"), "%s uses the diagonal gatehouse v8 (%s)" % [g["id"], g["art"]])
			check(absf(absf(float(g["shear"])) - (0.5 - 0.3633)) < 0.01, "%s shear: the JSON slope -0.3633 to the wall line (%.3f)" % [g["id"], float(g["shear"])])
		# round 15: the curtain's foot and the plinth bottoms on one ground line (2 px)
		check(g.get("feet_level_art_px") == null or float(g["feet_level_art_px"]) * 0.3495 * float(g.get("scale_mul", 1.0)) <= 2.0, "%s curtain foot level with its plinths (%s art px)" % [g["id"], g.get("feet_level_art_px")])
		if true:
			# v5 diagonal: the tower bases sit on the wall line (no drop)
			check(absf(float(g.get("art_drop_px", -1.0))) < 0.5, "%s tower bases on the wall line, no drop (%.1f)" % [g["id"], float(g.get("art_drop_px", -1.0))])
		# hero width as the art team measures it: 48 px at a 156 px hero
		var arch_min: float = 2.2 * (48.0 / 156.0) * hero_plate
		check(float(g.get("arch_open_px", 0.0)) >= arch_min, "%s arch opening %.1f px >= 2.2 hero widths (%.1f)" % [g["id"], float(g.get("arch_open_px", 0.0)), arch_min])
		check(float(g.get("passage_half_width_px", 0.0)) * 2.0 >= passage_px - 0.5, "%s passage is 2.2 hero widths" % g["id"])
	# Round 4: horizontal gatehouse v5 at N and S (1752x1041, towers 433 px wide).
	var k_mod: float = float((ring.get("factors", {}) as Dictionary).get("module_scale", 0.3495))
	for g in city.gates():
		if not (str(g["id"]) in ["N", "S"]):
			continue
		var sm: float = float(g.get("scale_mul", 1.0))
		check(str(g["art"]).contains("_v8"), "%s uses the kit5 horizontal gatehouse" % g["id"])
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
	# 3 (round 10, GOAL rhythm): no wall tower stands inside a gatehouse span or
	# crowds its towers (closer than a tower body diameter).
	var r_t: float = float(city.doc.get("tower_body_radius_px", 60.0))
	for rec in city.layers():
		if str(rec["tag"]) != "tower" or str(rec.get("tower_kind", "wall")) != "wall":
			continue
		var foot := _tower_foot(rec)
		for g in city.gates():
			var jl := Vector2(float(g["wall_join_left"][0]), float(g["wall_join_left"][1]))
			var jr := Vector2(float(g["wall_join_right"][0]), float(g["wall_join_right"][1]))
			var tt: float = (foot - jl).dot(jr - jl) / (jr - jl).length_squared()
			var inside: bool = tt > 0.0 and tt < 1.0 and foot.distance_to(jl.lerp(jr, tt)) < 10.0
			check(not inside, "tower %d is not inside gate %s" % [int(rec["id"]), g["id"]])
			check(minf(foot.distance_to(jl), foot.distance_to(jr)) >= 2.0 * r_t, "tower %d keeps clear of gate %s's towers (%.0f px)" % [int(rec["id"]), g["id"], minf(foot.distance_to(jl), foot.distance_to(jr))])
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
				var ref_k: Variant = rr.get("start_at" if key == "a" else "end_at")
				if ref_k == null or not (str(ref_k["kind"]) in ["tower", "gtower"]):
					continue
				var e := Vector2(float(rr[key][0]), float(rr[key][1]))
				if e.distance_to(cpt) < 3.0 * r_body:
					check(absf(e.x - cpt.x) <= r_body + 0.5, "corner %s: run end %s is within the corner tower's outline (%.1f px)" % [cpt, e, absf(e.x - cpt.x)])
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
			var run_len: float = Vector2(float(rr["a"][0]), float(rr["a"][1])).distance_to(Vector2(float(rr["b"][0]), float(rr["b"][1])))
			(ends_at[key] as Array).append([rr[pair[1]], rr.get(pair[2]), ref["at"], int(rr["edge"]), run_len])
	var pairs := 0
	var corner_tip_pairs := 0
	for key in ends_at.keys():
		var lst: Array = ends_at[key]
		for e in lst:
			var ep := Vector2(float(e[0][0]), float(e[0][1]))
			var tp := Vector2(float(e[2][0]), float(e[2][1]))
			check(absf(ep.x - tp.x) <= r_b + 0.5, "tower %s: run end %s is within the tower's outline (%.1f <= %.1f)" % [key, ep, absf(ep.x - tp.x), r_b])
		if lst.size() == 2 and lst[0][1] != null and lst[1][1] != null:
			pairs += 1
			var fa: float = float(lst[0][1]["foot"])
			var fb: float = float(lst[1][1]["foot"])
			check(absf(fa - fb) <= 2.0, "tower %s: the runs either side share the foot line (%.1f vs %.1f)" % [key, fa, fb])
			var ta0: float = float(lst[0][1]["tip"])
			var tb0: float = float(lst[1][1]["tip"])
			if int(lst[0][3]) != int(lst[1][3]):
				# round 9: at a corner tower (flat N/S run meets a diagonal) too
				corner_tip_pairs += 1
				check(absf(ta0 - tb0) <= 2.0, "corner tower %s: the flat and diagonal merlon lines meet (%.1f vs %.1f)" % [key, ta0, tb0])
			if int(lst[0][3]) == int(lst[1][3]) and float(lst[0][4]) >= 150.0 and float(lst[1][4]) >= 150.0:
				# along a wall (same module both sides) the merlon line runs on too
				# (runs shorter than 150 px are too short for a fitted merlon line)
				var ta: float = float(lst[0][1]["tip"])
				var tb: float = float(lst[1][1]["tip"])
				check(absf(ta - tb) <= 2.0, "tower %s: the runs either side share the merlon line (%.1f vs %.1f)" % [key, ta, tb])
	check(pairs >= 1, "towers with runs on both sides checked (%d)" % pairs)
	var n_corner_towers := 0
	for rec in city.layers():
		if str(rec["tag"]) == "tower" and bool(rec.get("corner", false)):
			n_corner_towers += 1
	check(corner_tip_pairs >= mini(2, n_corner_towers), "corner merlon lines checked (%d, %d corner towers)" % [corner_tip_pairs, n_corner_towers])
	for rec in city.layers():
		if str(rec["tag"]) == "tower":
			check(str(rec.get("module", "")).begins_with("tower_"), "tower %d uses a tower sprite from data (%s)" % [int(rec["id"]), rec.get("module", "")])
	# Round 10: every tower has the same size, stands centred on the wall
	# line, the runs enter it symmetrically, and the rhythm is even.
	var k_mod2: float = float((ring.get("factors", {}) as Dictionary).get("module_scale", 0.3495))
	var sizes: Array = []
	var ring_ws: Array = []
	var ring_hs: Array = []
	for rec in city.layers():
		if str(rec["tag"]) == "tower":
			ring_ws.append(float(rec["w"]))
			ring_hs.append(float(rec["h"]))
	var tw0: float = ring_ws[0] if not ring_ws.is_empty() else 0.0
	var th0: float = ring_hs[0] if not ring_hs.is_empty() else 0.0
	for k in ring_ws.size():
		check(absf(ring_ws[k] - tw0) / tw0 <= 0.02 and absf(ring_hs[k] - th0) / th0 <= 0.02, "ring tower %d has the common size (%.0fx%.0f)" % [k, ring_ws[k], ring_hs[k]])
	# round 15: the gatehouses are the v6 composites (their towers are v6 copies at the ring towers' scale)
	var ring_mul: float = 1.179
	for g in city.gates():
		check(str(g["art"]).contains("_v8"), "%s gatehouse is kit5 v8 art (%s)" % [g["id"], g["art"]])
	var r_c: float = float(city.doc.get("tower_body_radius_px", 60.0))
	var poly_t: Array = city.doc["wall_polygon"]
	for rec in city.layers():
		if str(rec["tag"]) != "tower":
			continue
		var wp := _tower_foot(rec)
		var axis_x: float = float(rec["x"]) + float(rec["w"]) * float(rec.get("anchor_frac", 251.5 / 505.0))
		check(absf(axis_x - wp.x) <= 4.0, "tower %d axis on its wall point (%.1f vs %.1f)" % [int(rec["id"]), axis_x, wp.x])
		var on_line := 1e9
		for i in poly_t.size():
			var a2 := Vector2(float(poly_t[i][0]), float(poly_t[i][1]))
			var b2 := Vector2(float(poly_t[(i + 1) % poly_t.size()][0]), float(poly_t[(i + 1) % poly_t.size()][1]))
			var t2: float = clampf((wp - a2).dot(b2 - a2) / (b2 - a2).length_squared(), 0.0, 1.0)
			on_line = minf(on_line, wp.distance_to(a2.lerp(b2, t2)))
		check(on_line <= 4.0, "tower %d stands on the wall centreline (%.1f px)" % [int(rec["id"]), on_line])
		if bool(rec.get("corner", false)):
			var near_c := 1e9
			for q2 in poly_t:
				near_c = minf(near_c, wp.distance_to(Vector2(float(q2[0]), float(q2[1]))))
			check(near_c <= 4.0, "corner tower %d axis on the corner point (%.1f px)" % [int(rec["id"]), near_c])
	# symmetric entry: the visible run ends either side of a tower (near run ends
	# at the body silhouette; a far run comes out from behind at the silhouette)
	for key2 in ends_at.keys():
		var lst2: Array = ends_at[key2]
		if lst2.size() != 2:
			continue
		var tp2 := Vector2(float(lst2[0][2][0]), float(lst2[0][2][1]))
		var offs: Array = []
		for e2 in lst2:
			var ep2 := Vector2(float(e2[0][0]), float(e2[0][1]))
			var off: float = absf(ep2.x - tp2.x)
			# a run tucked behind the tower shows from the silhouette outward
			offs.append(r_c if off < r_c * 0.95 else off)
		check(absf(float(offs[0]) - float(offs[1])) <= 0.1 * r_c, "tower %s: the runs enter at the same offset from its axis (%.1f vs %.1f)" % [key2, float(offs[0]), float(offs[1])])
	# round 15 (fewer towers): a mid-wall tower only on a stretch between
	# fixed towers longer than 6 wall heights, at its midpoint; 12-14 towers
	var n_t := 0
	for rec in city.layers():
		if str(rec["tag"]) == "tower":
			n_t += 1
	var n_g: int = city.gates().size() * 2
	for rec in city.layers():
		if str(rec.get("tower_kind", "")) == "gatehouse":
			n_g = 0
			break
	check(n_t + n_g == 12, "12 towers in all (%d ring + %d gatehouse)" % [n_t, n_g])
	for sp in city.doc.get("tower_spacing", []):
		var ml: float = float(sp.get("min_len", 0.0))
		for iv in sp.get("intervals", []):
			var ln: float = float(iv[1]) - float(iv[0])
			check((int(iv[2]) == 2) == (ln > ml), "edge %d stretch %.0f px: a mid tower only if longer than %.0f (%d)" % [int(sp["edge"]), ln, ml, int(iv[2])])
		for rec in city.layers():
			if str(rec["tag"]) == "tower" and str(rec.get("tower_kind", "")) == "wall" and int(rec.get("edge", -1)) == int(sp["edge"]):
				var at_mid := false
				for iv in sp.get("intervals", []):
					if absf(float(rec["s"]) - (float(iv[0]) + float(iv[1])) * 0.5) < 1.0:
						at_mid = true
				check(at_mid, "wall tower %d at its stretch midpoint" % int(rec["id"]))
	# water gates are flanked by two towers, on dry ground
	for wg in city.doc.get("water_gates", []):
		var w_at := Vector2(float(wg["at"][0]), float(wg["at"][1]))
		var flank := 0
		for rec in city.layers():
			if str(rec["tag"]) == "tower" and str(rec.get("tower_kind", "")) == "water_gate":
				var tf2 := _tower_foot(rec)
				if tf2.distance_to(w_at) < float(wg.get("art_width_px", 500.0)) * 0.75:
					flank += 1
					var tc := _cell_at(city.plate_to_world(tf2))
					check(city.zone.terrain_at(tc) != "water", "water gate tower %d stands on a bank" % int(rec["id"]))
		# a gatehouse tower or corner tower next to it counts as one flank
		for g in city.gates():
			for key in ["wall_join_left", "wall_join_right"]:
				if Vector2(float(g[key][0]), float(g[key][1])).distance_to(w_at) < float(wg.get("art_width_px", 500.0)) * 0.75:
					var dup := false
					for rec2 in city.layers():
						if str(rec2["tag"]) == "tower" and str(rec2.get("tower_kind", "")) == "water_gate" and _tower_foot(rec2).distance_to(Vector2(float(g[key][0]), float(g[key][1]))) < 4.0:
							dup = true
					if not dup:
						flank += 1
		for rec in city.layers():
			if str(rec["tag"]) == "tower" and bool(rec.get("corner", false)) and _tower_foot(rec).distance_to(w_at) < 400.0:
				flank += 1
		check(flank == 2, "water gate %s has two flanking towers (%d)" % [w_at, flank])
	# Round 12: one tower style: every tower is the v5 tower (ring towers use
	# its crop; the gatehouses are the v5 horizontal and diagonal art).
	for g in city.gates():
		check(str(g["art"]) in ["gatehouse_horizontal_v8_CONCEPTO.png", "gatehouse_diagonal_v8_CONCEPTO.png", "gatehouse_diagonal_v8_mirror_CONCEPTO.png"], "%s gatehouse is kit5 v8 art (%s)" % [g["id"], g["art"]])
	for rec in city.layers():
		var md := str(rec.get("module", ""))
		check(not ("diag_v3" in md) and not ("_v5" in md) and md != "tower_CONCEPTO.png" and md != "gatehouse_horizontal_CONCEPTO.png", "layer %d uses no old-style tower art (%s)" % [int(rec["id"]), md])
	# Round 13: joins. Every tower's base outline stands on ground, not water;
	# no gap between a tower and an adjoining module (sampled on the composite
	# of all ring sprites in the build); no water-gate block below a tower base.
	var r_base: float = float(city.doc.get("tower_body_radius_px", 77.5)) * 300.0 / 214.0
	for rec in city.layers():
		if str(rec["tag"]) != "tower":
			continue
		var wp2 := _tower_foot(rec)
		var wet := 0
		for kq in 16:
			var ang := TAU * float(kq) / 16.0
			var bp := wp2 + Vector2(cos(ang) * r_base * 0.9, sin(ang) * r_base * 0.45)
			if city.zone.terrain_at(_cell_at(city.plate_to_world(bp))) == "water":
				wet += 1
		check(wet == 0, "tower %d base outline stands on ground (%d points on water)" % [int(rec["id"]), wet])
	# round 15: no walkable cell inside any tower plinth ellipse (gate passages excepted)
	var r_pl: float = float(city.doc.get("tower_base_radius_px", 120.0)) - 2.0
	var pass_cells := {}
	for g in city.gates():
		for c in g.get("cells", []):
			pass_cells[Vector2i(int(c[0]), int(c[1]))] = true
	var on_plinth := 0
	for pl in city.doc.get("tower_plinths", []):
		var pc := Vector2(float(pl[0]), float(pl[1]))
		var cc: Vector2i = _cell_at(city.plate_to_world(pc))
		for dy in range(-8, 9):
			for dx in range(-8, 9):
				var cell := cc + Vector2i(dx, dy)
				if pass_cells.has(cell) or not city.zone.passable_at(cell):
					continue
				var pp: Vector2 = city.world_to_plate(BoardVisualSort.cell_to_local(cell))
				if ((pp.x - pc.x) / r_pl) ** 2 + ((pp.y - pc.y) / (r_pl * 0.5)) ** 2 <= 1.0:
					on_plinth += 1
	check(city.doc.get("tower_plinths", []).size() >= 12, "tower plinths in data (%d)" % city.doc.get("tower_plinths", []).size())
	check(on_plinth == 0, "no walkable cell inside a tower plinth (%d)" % on_plinth)
	var audit: Array = city.doc.get("join_audit", [])
	check(audit.size() >= 12, "joins audited (%d)" % audit.size())
	for j in audit:
		check(int(j["gap_px"]) == 0, "join %s (%s) at %s has no gap (%d px)" % [j["id"], j["kind"], j["at"], int(j["gap_px"])])
	# round 14: the block keeps its stonework down to the ground (no grass under the deck)
	for wg in city.doc.get("water_gates", []):
		var found := false
		for rec in city.layers():
			if str(rec["tag"]) == "watergate" and absf(float(rec["x"]) + float(rec["w"]) * 0.5 - float(wg["at"][0])) < 260.0 and absf(float(rec["sort_y"]) - float(wg["at"][1])) < 260.0:
				found = true
				check(float(rec["y"]) + float(rec["h"]) >= float(wg["at"][1]) + 20.0, "water gate %s keeps its stonework down to the ground" % [wg["at"]])
		check(found, "water gate block at %s" % [wg["at"]])
	# Round 15: Grok's regraded v7 segments (no in-game recolour); the water
	# channel runs through each water gate's arch on both sides of the wall
	for rec in city.layers():
		if str(rec["tag"]) == "wall":
			check(str(rec.get("module", "")).contains("_v8"), "wall strip %d uses the kit5 v8 segment (%s)" % [int(rec["id"]), rec.get("module", "")])
			break
	for wg in city.doc.get("water_gates", []):
		check(str(wg["art"]).begins_with("watergate_diagonal_v8"), "water gate %s is kit5 v8 art" % [wg["at"]])
		check(wg.get("channel_offset_px") != null and float(wg["channel_offset_px"]) <= 8.0, "water gate %s: the channel centreline passes the arch centre (%s px)" % [wg["at"], wg.get("channel_offset_px")])
	# Round 5: a clear plaza at every gate and water gate (no trees).
	var clear_cfg: Dictionary = city.doc.get("gate_clear", {})
	check(not clear_cfg.is_empty(), "gate clearance in data")
	var zones: Array = []
	for g in city.gates():
		zones.append([Vector2(float(g["arch"][0]), float(g["arch"][1])), float(g.get("art_width_px", 400.0))])
	for wg in city.doc.get("water_gates", []):
		zones.append([Vector2(float(wg["at"][0]), float(wg["at"][1])), float(wg.get("art_width_px", 400.0))])
	check(zones.size() == 6, "4 gates and 2 water gates get a clear plaza (%d)" % zones.size())
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
	if _image_plate():
		# Round 19: a warm glow at every gate mouth by night, none by day
		cp.set_hour(22.0)
		var glows := 0
		for gf in cp.gates_fx:
			if gf["glow"] != null and (gf["glow"] as CanvasItem).visible:
				glows += 1
		check(glows == 4, "night: a glow at each gate mouth (%d)" % glows)
		cp.set_hour(12.0)
		for gf in cp.gates_fx:
			check(gf["glow"] != null and not (gf["glow"] as CanvasItem).visible, "day: gate %s glow is off" % gf["id"])
	if not _image_plate():
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
