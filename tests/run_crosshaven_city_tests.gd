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
	_test_crossroads_untouched()
	var w := _spawn()
	await _test_world_entry(w)
	_test_sort(w)
	_test_fade(w)
	_test_life(w)
	_test_performance(w)
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
	# Through the gate: spawn (outside, south road) to the far side of bridge 1 (north-east).
	var inner: Array = city.bridges()[1]["ends"][1]
	var path: Dictionary = WorldWalk.find_path(city.map, "crosshaven_city", spawn, "crosshaven_city", Vector2i(int(inner[0]), int(inner[1])))
	check(bool(path.get("ok", false)), "spawn walks to the north-east bridge")
	var through_gate := false
	for step in path.get("path", []):
		if gates.has(Vector2i(int(step["x"]), int(step["y"]))):
			through_gate = true
	check(through_gate, "the walk in goes through the gate arch")
	check(city.bridges().size() == 3, "three bridges")
	for b in city.bridges():
		var a := Vector2i(int(b["ends"][0][0]), int(b["ends"][0][1]))
		var c := Vector2i(int(b["ends"][1][0]), int(b["ends"][1][1]))
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
		if tag in ["tower", "castle", "cathedral", "townhall", "bank"]:
			probes += 1
			var foot: Vector2 = city.plate_to_world(Vector2(float(rec["x"]) + float(rec["w"]) * 0.5, float(rec["sort_y"]) - 14.0))
			var cell := _cell_at(foot)
			if not z.passable_at(cell):
				blocked_under += 1
	check(probes > 10 and blocked_under == probes, "towers and landmarks block their base (%d of %d)" % [blocked_under, probes])


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
	check(gates.size() >= 6, "south gate plus the new gates (%d)" % gates.size())
	var whys := {}
	for g in gates:
		whys[str(g["why"])] = int(whys.get(str(g["why"]), 0)) + 1
	check(whys.has("north_gate"), "a north gate exists")
	check(int(whys.get("crosses", 0)) >= 3, "every road crossing the wall has a gate (%d)" % int(whys.get("crosses", 0)))
	check(int(whys.get("dead_end", 0)) >= 1, "the street ending at the south-east wall has a gate")
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
	var start := Vector2i(int(city.bridges()[1]["ends"][0][0]), int(city.bridges()[1]["ends"][0][1]))
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
		if not (str(rec["tag"]) in ["tower", "tower_g"]):
			continue
		towers += 1
		var m: Dictionary = PlateCity.unpack_mask(rec["mask"])
		var stray := 0
		var step := int(m["step"])
		for by in range(136 / step, int(m["h"])):
			for bx in int(m["w"]):
				var x0 := bx * step
				if (x0 + step <= 44 or x0 >= 132) and (m["bits"] as PackedByteArray)[by * int(m["w"]) + bx] == 1:
					stray += 1
		check(stray == 0, "tower layer %d has no wall stub (%d stray blocks)" % [int(rec["id"]), stray])
	check(towers >= 12, "towers checked (%d)" % towers)


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
	check(plots.size() == 5, "five player plots")
	var want := {"P1": "rare", "P2": "legendary", "P3": "rare", "P4": "normal", "P5": "normal"}
	var ground: Image = null
	var gpath: String = city.art_path("ground.jpg")
	if ResourceLoader.exists(gpath):
		var tex := load(gpath) as Texture2D
		if tex != null:
			ground = tex.get_image()
	if ground == null:
		ground = Image.load_from_file(ProjectSettings.globalize_path(gpath))
	check(ground != null and ground.get_width() == 5120, "ground image readable for the street check")
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
				var col := ground.get_pixel(int(q.x), int(q.y))
				var sat := maxf(col.r, maxf(col.g, col.b)) - minf(col.r, minf(col.g, col.b))
				if sat < 28.0 / 255.0 and maxf(col.r, maxf(col.g, col.b)) > 90.0 / 255.0:
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
	check(w.city_plate.rows.size() >= 390, "layers and plot houses built (%d)" % w.city_plate.rows.size())
	check(w.city_plate.plot_nodes.size() == 5, "five plot houses drawn")
	var water: Sprite2D = w.city_plate.water
	check(water != null and water.visible, "the animated river is drawn")
	check(water != null and water.material is ShaderMaterial and (water.material as ShaderMaterial).get_shader_parameter("ripple") != null, "river shader has its ripple tile")
	check(water != null and water.z_index < w.city_plate.UNDER_Z, "river draws under the bridges")
	for id in w.city_plate.plot_nodes.keys():
		var node: Sprite2D = w.city_plate.plot_nodes[id]
		check(node.texture != null, "plot %s house texture" % id)
	var cam_w: int = w.camera.limit_right - w.camera.limit_left
	check(absi(cam_w - int(city.world_rect().size.x)) <= 1, "camera keeps to the plate (%d)" % cam_w)
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
	check(count > 380, "y-sorted rows (%d)" % count)
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
		if str(row["tag"]) == "house" and bool(row["fade"]):
			var c := _cell_behind(w, row)
			if c.x >= 0:
				target = row
				break
	check(not target.is_empty(), "found a house the hero can stand behind")
	if target.is_empty():
		return
	var cell := _cell_behind(w, target)
	w.walker.place(w.zone, cell)
	var feet: Vector2 = w.walker.position
	var covered: bool = plate.update_cover(feet, 0.0, w.walker.z_index, 1.0)
	check(covered, "hero behind a house is covered")
	check(float(target["alpha"]) < 0.5 and (target["node"] as CanvasItem).modulate.a < 0.5, "the house fades to see-through (%.2f)" % float(target["alpha"]))
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
				wall_ok = float(row["alpha"]) < 0.5
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
	check(w.city_plate._ground.scale.is_equal_approx(Vector2(2, 2)), "lite ground still covers the plate")
	# Instant fades: one tiny tick reaches the min alpha.
	var target: Dictionary = {}
	var cell := Vector2i(-1, -1)
	for row in w.city_plate.rows:
		if str(row["tag"]) == "house" and bool(row["fade"]):
			cell = _cell_behind(w, row)
			if cell.x >= 0:
				target = row
				break
	if not target.is_empty():
		w.walker.place(w.zone, cell)
		w.city_plate.update_cover(w.walker.position, 0.0, w.walker.z_index, 0.001)
		check(is_equal_approx(float(target["alpha"]), float(target["min_alpha"])), "Performance mode fades at once")
	for n in w.npcs_root.get_children():
		check(is_equal_approx(float(n.idle_rate), w.LITE_IDLE_RATE), "NPC %s idles at the lite rate" % n.name)
	w.settings.set_performance(false)
	check(not w.city_plate.ground_is_lite(), "full ground back after Performance mode")
	w.walker.place(w.zone, city.spawn())


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
