extends SceneTree

## Crosshaven world scene (PC, `main`). Run:
##   godot --headless --path . -s res://tests/run_crosshaven_world_tests.gd

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")

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


func _spawn() -> Node2D:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	return w


func _drive(w: Node2D, max_steps: int = 4000) -> void:
	var n := 0
	while w.walker.is_moving() and n < max_steps:
		w.walker.advance(0.05)
		n += 1


func _run() -> void:
	var w := _spawn()
	check(w.map != null, "map loads")
	check(w.zone != null and w.zone.zone_id == w.map.start_zone, "starts in start zone")
	check(w.walker.cell == w.map.start_cell, "player on start cell")
	check(w.map.start_zone == "crosshaven_crossroads" and w.map.start_cell == Vector2i(22, 18), "start is crossroads (22,18)")

	_test_strips(w)
	_test_pick(w)
	_test_walk(w)
	_test_reject(w)
	_test_zorder(w)
	_test_weather(w)
	_test_all_zones(w)
	_test_exit(w)
	_test_kit(w)

	w.queue_free()
	print("crosshaven world tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## Hero pace on PC: about 55 px/s walking and 110 px/s running, south strip.
## Walk playback is capped at 1.8x; the rest is a longer stride.
func _test_hero_pace(w: Node2D) -> void:
	var walker: Node2D = w.walker
	var art_walk: float = walker._strips.speed_of("walk", "s")
	var art_run: float = walker._strips.speed_of("run", "s")
	check(absf(art_walk - 25.047) < 0.01, "art walk cadence is still 25.05 px/s (%.3f)" % art_walk)
	check(absf(art_run - 54.7965) < 0.01, "art run cadence is still 54.80 px/s (%.3f)" % art_run)
	check(is_equal_approx(walker.HERO_WALK_PACE, 2.2), "hero walk pace is 2.2x")
	check(is_equal_approx(walker.HERO_RUN_PACE, 2.0), "hero run pace is 2.0x")
	check(absf(walker.speed_of("walk") - 55.1034) < 0.01, "hero walks at 55.10 px/s (%.3f)" % walker.speed_of("walk"))
	check(absf(walker.speed_of("run") - 109.593) < 0.01, "hero runs at 109.59 px/s (%.3f)" % walker.speed_of("run"))
	check(is_equal_approx(walker.anim_scale("walk"), 1.8), "walk playback is capped at 1.8x")
	check(is_equal_approx(walker.anim_scale("run"), 2.0), "run playback is 2.0x")
	check(is_equal_approx(walker.stride_scale("walk"), 2.2 / 1.8), "walk stride grows by 2.2/1.8")
	check(is_equal_approx(walker.stride_scale("run"), 1.0), "run keeps the painted stride")
	check(is_equal_approx(walker.shown_fps_of("walk"), 21.6), "walk shows 21.6 fps")
	check(is_equal_approx(walker.shown_fps_of("run"), 30.0), "run shows 30 fps")
	for gait in ["walk", "run"]:
		var count := float(walker.frame_count(gait, "s"))
		var travel: float = walker.speed_of(gait) * count / walker.shown_fps_of(gait)
		check(is_equal_approx(travel, walker.shown_stride_of(gait)), "%s cycle covers one shown stride, no skate" % gait)
	# The live walker uses the scaled stride and cruise.
	var zone: WorldZone = w.zone
	walker.place(zone, zone.spawn)
	walker.facing = "s"
	walker._shown_pace = "walk"
	walker._apply_strip_speed()
	check(absf(walker._cruise - walker.speed_of("walk")) < 0.001, "live walk cruise is the hero pace")
	check(absf(walker._stride - walker.shown_stride_of("walk")) < 0.001, "live walk stride is the scaled stride")
	walker._shown_pace = "run"
	walker._apply_strip_speed()
	check(absf(walker._cruise - walker.speed_of("run")) < 0.001, "live run cruise is the hero pace")
	walker._shown_pace = "walk"
	walker._apply_strip_speed()
	walker.place(zone, zone.spawn)


func _test_strips(w: Node2D) -> void:
	for dir in ["n", "s"]:
		check(w.walker.frame_count("walk", dir) == 8, "walk %s is the 8-frame strip" % dir)
	for dir in ["e", "w"]:
		check(w.walker.frame_count("walk", dir) == 6, "walk %s is the 6-frame painted strip" % dir)
	for dir in ["n", "e", "s", "w"]:
		check(w.walker.frame_count("run", dir) == 8, "run %s is the 8-frame strip" % dir)
	check(is_equal_approx(w.walker.fps_of("walk"), 12.0), "walk plays at 12 fps")
	check(is_equal_approx(w.walker.fps_of("run"), 15.0), "run plays at 15 fps")
	check(is_equal_approx(w.walker.stride_of("walk", "e"), 59.6706), "east walk stride is the painted step at scale 0.33")
	check(is_equal_approx(w.walker.stride_of("walk", "s"), 16.698), "south walk stride matches the on-screen step")
	check(is_equal_approx(w.walker.stride_of("run", "e"), 36.96), "east run stride is ground 112 at scale 0.33")
	check(is_equal_approx(w.walker.stride_of("run", "s"), 29.2248), "south run stride matches the on-screen step")
	var east_fps: float = w.walker._strips.fps_of("walk", "e")
	var east_speed: float = w.walker._strips.speed_of("walk", "e")
	check(is_equal_approx(east_fps, 3.185488331), "east walk fps keeps 31.68 px/s on the painted stride")
	check(is_equal_approx(east_speed, 31.68), "east walk speed stays 31.68 px/s")
	check(is_equal_approx(w.walker._strips.fps_of("walk", "w"), east_fps), "west walk matches east fps")
	check(w.walker._strips.pivot == Vector2(0, -104), "sole pivot sits on the ground point")
	check(w.walker._sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "hero filters linear")
	var count := float(w.walker.frame_count("walk", "s"))
	var expected: float = w.walker.shown_stride_of("walk") * w.walker.shown_fps_of("walk") / count
	check(is_equal_approx(w.walker.speed_of("walk"), expected), "walk speed is shown stride times shown fps over frame count")
	_test_hero_pace(w)
	# The hero pace scales walk 2.2x and run 2.0x, so run lands at about 2x walk.
	var run_ratio: float = w.walker.speed_of("run") / w.walker.speed_of("walk")
	check(run_ratio > 1.9 and run_ratio < 2.1, "run is about twice the walk (%.2fx)" % run_ratio)
	check(w.walker.base_scale() <= 0.4 and w.walker.base_scale() > 0.2, "hero scale lets a cottage tower over them")
	var saw_sun := false
	var saw_flower := false
	var saw_cottage := false
	var saw_tree := false
	for d in w.decor_root.get_children():
		if d.decor_type == "sunflowers_tall":
			saw_sun = true
			check(is_equal_approx(d.scale.y, 0.58), "sunflowers draw at shoulder height")
		elif d.decor_type == "flowers_a" or d.decor_type == "grass_tuft_a" or d.decor_type == "mushrooms_a":
			saw_flower = true
			check(is_equal_approx(d.scale.y, 0.50), "%s stays ankle to knee" % d.decor_type)
	for p in w.props_root.get_children():
		if p.prop_type == "red_roof_cottage" or p.prop_type == "crossroads_centerpiece":
			saw_cottage = true
			check(is_equal_approx(p.scale.y, 1.0), "%s stays full size" % p.prop_type)
		elif p.prop_type == "tree":
			saw_tree = true
			check(is_equal_approx(p.scale.y, 1.0), "trees stay full size")
		elif p.prop_type == "hedgerow_nesw":
			check(is_equal_approx(p.scale.y, 0.62), "hedges sit at shoulder height")
	check(saw_sun, "crossroads has a sunflower to scale")
	check(saw_flower, "crossroads has low plants to scale")
	check(saw_cottage and saw_tree, "crossroads has a full-size building and tree")


func _test_pick(w: Node2D) -> void:
	var z: WorldZone = w.zone
	var mh := Pick.max_height(z)
	var bad := 0
	for y in z.height:
		for x in z.width:
			var c := Vector2i(x, y)
			var got := Pick.pick(z, Pick.cell_center(z, c), mh)
			if got != c:
				# Only acceptable when a taller tile in front covers this centre.
				if got.x < 0 or got.x + got.y <= c.x + c.y or z.height_at(got) <= z.height_at(c):
					bad += 1
	check(bad == 0, "pick round-trips every cell centre (bad=%d)" % bad)
	check(Pick.pick(z, Vector2(-99999, -99999), mh) == Vector2i(-1, -1), "pick off-map is none")


func _first_cell(z: WorldZone, pred: Callable) -> Vector2i:
	for y in z.height:
		for x in z.width:
			var c := Vector2i(x, y)
			if pred.call(c):
				return c
	return Vector2i(-1, -1)


func _test_walk(w: Node2D) -> void:
	var z: WorldZone = w.zone
	var start: Vector2i = w.walker.cell
	var target := start + Vector2i(0, 6)
	if not z.passable_at(target) or not z.exit_link(target).is_empty():
		target = _first_cell(z, func(c): return z.passable_at(c) and z.exit_link(c).is_empty() and (c - start).length() > 4)
	var visited: Array = [{"zone_id": z.zone_id, "x": start.x, "y": start.y}]
	var on_step := func(c): visited.append({"zone_id": z.zone_id, "x": c.x, "y": c.y})
	w.walker.stepped.connect(on_step)
	var res: Dictionary = w.walk_to(target)
	check(bool(res.get("ok", false)), "walk_to finds a path")
	_drive(w)
	w.walker.stepped.disconnect(on_step)
	check(w.walker.cell == target, "player arrives at clicked cell")
	check(bool(WorldWalk.validate_path(w.map, visited).get("ok", false)), "walked steps pass WorldWalk.validate_path")
	check(visited.size() - 1 == int(res.get("length", -1)), "step count matches path length")
	# Retarget mid-walk: anchor is the cell being entered.
	w.walk_to(start)
	w.walker.advance(0.1)
	var anchor: Vector2i = w.walker.anchor_cell()
	check(z.passable_at(anchor), "mid-step anchor is passable")
	_drive(w)
	check(w.walker.cell == start, "walks back to start")


func _test_reject(w: Node2D) -> void:
	var z: WorldZone = w.zone
	var water := _first_cell(z, func(c): return z.terrain_at(c) == "water")
	var blocked := _first_cell(z, func(c): return z.blocked_at(c))
	var before: Vector2i = w.walker.cell
	if water.x >= 0:
		check(not bool(w.walk_to(water).get("ok", true)), "click on water is rejected")
		check(not w.walker.is_moving() and w.walker.cell == before, "player stays put after water click")
	check(blocked.x >= 0 and not bool(w.walk_to(blocked).get("ok", true)), "click on a prop tile is rejected")


func _test_zorder(w: Node2D) -> void:
	var z: WorldZone = w.zone
	var cottage: Node2D = null
	for p in w.props_root.get_children():
		if p.prop_type == "crossroads_centerpiece" or p.prop_type == "red_roof_cottage":
			cottage = p
			break
	check(cottage != null, "crossroads has a 2x2 prop")
	if cottage == null:
		return
	var north: Vector2i = cottage.footprint[0]
	for c in cottage.footprint:
		if c.x + c.y < north.x + north.y:
			north = c
	var behind := north + Vector2i(0, -1)
	var front: Vector2i = cottage.south_cell + Vector2i(0, 1)
	w.walker.place(z, behind)
	check(w.walker.z_index < cottage.z_index, "player north of 2x2 prop draws behind it")
	w.walker.place(z, front)
	check(w.walker.z_index > cottage.z_index, "player south of 2x2 prop draws in front")
	# Raised tile directly in front covers the player.
	var row_front: int = w.ground.row_z(front.x + front.y + 1)
	check(row_front > w.walker.z_index, "ground row in front sorts above player")
	var tall: Node2D = null
	for p in w.props_root.get_children():
		if p.cover_rect.size.y > 70.0:
			tall = p
			break
	if tall != null:
		w.walker.place(z, tall.south_cell)
		w.walker.position = tall.position + Vector2(0, -40)
		# A character up there stands on a row behind the base, so sort it from
		# that row. The prop now keeps its own depth while it fades (it used
		# to drop to the character's z + 1 and sank under the ground).
		w.walker.z_index = w.walker._z_for(tall.south_cell - Vector2i(1, 1))
		tall.update_cover(w.walker.position, w.walker.z_index)
		check(tall.z_index > w.walker.z_index, "tall prop covers a character standing in its upper half")
		check(tall.z_index == tall.base_z, "tall prop keeps its own depth while it fades")
		check(tall.modulate.a < 0.6, "tall prop fades while the character is hidden behind it")
		w.walker.position = tall.position + Vector2(0, 14)
		tall.update_cover(w.walker.position, w.walker.z_index)
		check(tall.z_index == tall.base_z, "character in front of the prop base sorts over it")
	w.walker.place(z, w.map.start_cell)


func _test_weather(w: Node2D) -> void:
	var wt: Node = w.weather
	for name in ["clear", "light_cloud", "light_rain", "wind"]:
		wt.set_weather(name)
		wt.settle()
		check(wt.weather == name, "weather %s applies" % name)
	wt.set_weather("snow")
	check(wt.weather == "wind", "unknown weather ignored")
	wt.set_weather("clear")
	wt.settle()
	wt.time_of_day = 12.0
	var noon: Color = wt.current_tint()
	wt.time_of_day = 23.0
	var night: Color = wt.current_tint()
	check(night.get_luminance() < noon.get_luminance() - 0.2, "night darker than noon")
	wt.set_weather("light_rain")
	wt.settle()
	wt.time_of_day = 12.0
	check(wt.current_tint().get_luminance() < noon.get_luminance(), "rain darker than clear noon")
	wt.set_weather("clear")
	wt.settle()
	wt.time_of_day = 10.0


func _test_all_zones(w: Node2D) -> void:
	for id in w.map.zones.keys():
		var z: WorldZone = w.map.zone(id)
		w._load_zone(id, z.spawn)
		check(w.zone.zone_id == id, "zone %s loads" % id)
		check(w.props_root.get_child_count() == z.props.size(), "zone %s prop count" % id)
		# Eastmarch draws a sea skirt past the chunk, so the row span follows
		# that view margin rather than the seam blend alone.
		var margin := int(w.ground.call("_view_margin"))
		check(w.ground.get_child_count() == z.width + z.height - 1 + margin * 4, "zone %s ground rows" % id)
		check(w.walker.cell == z.spawn, "zone %s player at spawn" % id)
	w._load_zone(w.map.start_zone, w.map.start_cell)


func _test_exit(w: Node2D) -> void:
	# Every exit link: walk onto it from inside and land on link.to.
	var tried := 0
	for id in w.map.zones.keys():
		var z: WorldZone = w.map.zone(id)
		for exit_rec in z.exits:
			var dir: Vector2i = WorldZone.EDGE_DIR[str(exit_rec["edge"])]
			var link_rec: Dictionary = {}
			var from := Vector2i.ZERO
			var inside := Vector2i.ZERO
			for candidate in exit_rec["links"]:
				var cand: Dictionary = candidate
				var at := Vector2i(int(cand["from"]["x"]), int(cand["from"]["y"]))
				var step := at - dir
				if z.in_bounds(step) and z.passable_at(step) and z.exit_link(step).is_empty():
					link_rec = cand
					from = at
					inside = step
					break
			# Coast corners and a 2-cell lane have no free cell behind the exit.
			if link_rec.is_empty():
				continue
			var to := Vector2i(int(link_rec["to"]["x"]), int(link_rec["to"]["y"]))
			w._load_zone(id, inside)
			var landed := {"zone": "", "cell": Vector2i(-1, -1)}
			var cb := func(zid, c):
				landed["zone"] = zid
				landed["cell"] = c
			w.zone_entered.connect(cb)
			w.walk_to(from)
			_drive(w)
			w.zone_entered.disconnect(cb)
			tried += 1
			check(landed["zone"] == str(exit_rec["target_zone"]) and landed["cell"] == to,
				"exit %s/%s lands on link.to (got %s %s)" % [id, exit_rec["id"], landed["zone"], landed["cell"]])
	check(tried >= 20, "covered every exit (%d)" % tried)


func _test_kit(w: Node2D) -> void:
	# Picker logic runs on data alone, with or without the art files present.
	var z: WorldZone = w.map.zone(w.map.start_zone)
	var edge_found := false
	var interior_found := false
	for y in z.height:
		for x in z.width:
			var c := Vector2i(x, y)
			if z.terrain_at(c) != "dirt_road":
				continue
			var p: Dictionary = CrosshavenArt.pick_tile(z, c)
			var open_sides: Array = []
			for side in CrosshavenArt.SIDES:
				var n: Vector2i = c + CrosshavenArt.SIDE_DIR[side]
				if not z.in_bounds(n) or z.terrain_at(n) != "dirt_road":
					open_sides.append(side)
			if open_sides.is_empty():
				interior_found = interior_found or str(p["floor"]).begins_with("dirt_road_") and not str(p["floor"]).contains("edge")
			else:
				edge_found = edge_found or str(p["floor"]) == "dirt_road_edge_" + "_".join(open_sides)
	check(edge_found, "road next to plains picks dirt_road_edge_<sides>")
	check(interior_found, "road interior picks an interior variant")
	check(CrosshavenArt.h(3, 5, 7) == (((3 * 73856093) ^ (5 * 19349663) ^ (15 * 83492791)) & 0x7fffffff) % 7, "kit hash matches README")
	check(CrosshavenArt.prop_art_id("fence", Vector2i(0, 0), 1) == "fence_wood_nesw", "fence along y uses fence_wood_nesw")
	check(CrosshavenArt.prop_art_id("fence", Vector2i(0, 0), 0) == "fence", "fence along x uses fence")
	# With the kit on disk, every picked floor id resolves to a real file.
	if not CrosshavenArt.has("tiles", "golden_plains"):
		print("note: art kit not present, skipping file checks")
		return
	var missing := {}
	for id in w.map.zones.keys():
		var zz: WorldZone = w.map.zone(id)
		for y in zz.height:
			for x in zz.width:
				var c := Vector2i(x, y)
				var p: Dictionary = CrosshavenArt.pick_tile(zz, c)
				for piece in [p["floor"]] + p["corners"]:
					if not CrosshavenArt.has("tiles", piece):
						missing[piece] = true
				for strip in CrosshavenArt.face_strips(zz, c):
					if not CrosshavenArt.has("tiles", strip["id"]):
						missing[strip["id"]] = true
	check(missing.is_empty(), "every picked tile piece exists in the kit (missing %s)" % [missing.keys()])
	w._load_zone(w.map.start_zone, w.map.start_cell)
	check(w.ground.uses_kit(), "ground switches to the kit when art is present")
	var fences_y := 0
	for p in w.props_root.get_children():
		check(p.has_art(), "prop %s has kit art" % p.prop_id)
		if p.prop_type == "fence" and p._fence_axis == 1:
			fences_y += 1
			check(p.art_id == "fence_wood_nesw", "fence %s along y draws nesw" % p.prop_id)
