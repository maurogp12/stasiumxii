extends SceneTree

## 3D slice tests: Crosshaven's 3D city build (plan, walk grid, gates,
## bridges, kit placement, day/night, hero walking, rig retarget).
## The combat engine is untouched; its own suites cover it.
## Run: godot --headless --path . -s res://tests/run_slice3d_tests.gd

const CityPlan := preload("res://slice3d/city/city_plan.gd")
const Nav := preload("res://slice3d/city/nav_grid.gd")
const Builder := preload("res://slice3d/city/city_builder.gd")
const Env := preload("res://slice3d/city/city_env.gd")
const Hero := preload("res://slice3d/city/hero3d.gd")
const Retarget := preload("res://slice3d/city/humanoid_retarget.gd")
const CITY := "res://data/world/city3d/crosshaven.json"

var _passed := 0
var _failed := 0
var plan
var nav


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _run() -> void:
	plan = CityPlan.load_city(CITY)
	_check(plan.ok, "Crosshaven plan loads (%s)" % [plan.errors])
	if not plan.ok:
		_done()
		return
	nav = Nav.new()
	nav.setup(plan)
	_test_layout()
	_test_scale_table()
	_test_ring()
	_test_gates()
	_test_reach()
	_test_bridges()
	_test_smoothing()
	await _test_build()
	_test_day_night()
	await _test_hero_walk()
	_test_retarget()
	await _test_life()
	_done()


func _done() -> void:
	print("Slice 3D tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_layout() -> void:
	_check(plan.width == 245 and plan.height == 245, "the approved 245 x 245 layout")
	_check(plan.cell_m == 1.5, "cell is 1.5 m")
	var kinds := {}
	for p in plan.pieces:
		kinds[str(p["kind"])] = kinds.get(str(p["kind"]), 0) + 1
	var houses := 0
	for k in kinds.keys():
		if str(k).begins_with("house_npc"):
			houses += kinds[k]
	_check(houses >= 55, "about 60 houses (%d)" % houses)
	_check(kinds.get("tower", 0) == 12, "12 ring towers (%d)" % kinds.get("tower", 0))
	var plots: int = kinds.get("plot_normal", 0) + kinds.get("plot_rare", 0) + kinds.get("plot_legendary", 0)
	_check(plots == 10, "10 player plots (%d)" % plots)
	for k in ["castle", "cathedral", "townhall", "bank", "mill", "gazebo", "fountain"]:
		_check(kinds.has(k), "layout has the %s" % k)
	_check(plan.tunnels.size() == 2, "2 water tunnels")
	_check(plan.gates.size() == 4, "4 land gates")
	_check(plan.npcs.size() >= 10, "city NPCs loaded (%d)" % plan.npcs.size())


func _test_scale_table() -> void:
	var missing: Array = []
	for p in plan.pieces:
		if (p["spec"] as Dictionary).is_empty():
			missing.append(p["kind"])
	_check(missing.is_empty(), "every piece kind has a 3D size (%s)" % [missing])
	var house: Dictionary = plan.scale_for("house_npc_halftimber_blue_2storey")
	_check(float(house.get("h", 0)) > 5.0 and float(house.get("h", 0)) < 9.0, "a two-storey house is 5-9 m to the eaves")
	_check(not plan.scale_for("tree_oak").is_empty(), "prefix match finds tree sizes")


func _test_ring() -> void:
	_check(plan.ring.size() >= 6, "the ring traces to a polygon (%d corners)" % plan.ring.size())
	# Every tower sits on the ring line (within 6 m).
	for t in plan.pieces_of("tower"):
		var best := 1e9
		for i in plan.ring.size():
			best = minf(best, CityPlan._seg_dist(t["center"], plan.ring[i], plan.ring[(i + 1) % plan.ring.size()]))
		_check(best < 6.0, "tower at %s sits on the ring (%.1f m)" % [t["anchor"], best])


func _test_gates() -> void:
	for g in plan.gates:
		_check(g["passage_m"] >= 4.0, "gate %s passage is wide enough in the layout" % g["id"])
		# The gatehouse pillars block, the passage stays open: walk outside -> inside.
		var a: Vector2i = plan.world_to_cell(g["outside"])
		var b: Vector2i = plan.world_to_cell(g["inside"])
		var path: Array = nav.cell_path(plan.nearest_passable(a, 4), plan.nearest_passable(b, 4))
		_check(not path.is_empty(), "gate %s: walk from outside to inside" % g["id"])
		if not path.is_empty():
			var d := 1e9
			for c in path:
				d = minf(d, plan.cell_center(c).distance_to(g["mid"]))
			_check(d < 4.0, "gate %s: the walk goes through the arch (%.1f m)" % [g["id"], d])
	_check(not plan.solid_extra.is_empty(), "gatehouse pillars block cells")


func _test_reach() -> void:
	var r: Dictionary = nav.reach(plan.spawn)
	_check(r.size() > 15000, "spawn reaches most of the city (%d cells)" % r.size())
	for g in plan.gates:
		_check(r.has(plan.nearest_passable(plan.world_to_cell(g["inside"]), 4)), "spawn reaches gate %s" % g["id"])
	for n in plan.npcs:
		_check(r.has(n["cell"]), "spawn reaches NPC %s" % n["id"])
	var plots_ok := 0
	var plots := 0
	for p in plan.pieces:
		if str(p["kind"]).begins_with("plot_") and p.has("door"):
			plots += 1
			if r.has(plan.nearest_passable(p["door"], 3)):
				plots_ok += 1
	_check(plots_ok == plots, "every plot door is reachable (%d/%d)" % [plots_ok, plots])


func _test_bridges() -> void:
	_check(plan.bridges.size() == 4, "4 bridges on the river (%d)" % plan.bridges.size())
	for b in plan.bridges:
		var mid: Vector2 = b["center"]
		var end: Vector2 = mid + (b["axis"] as Vector2) * float(b["length"]) * 0.5
		var c_mid: Vector2i = plan.world_to_cell(mid)
		if plan.walk_over.has(c_mid):
			_check(plan.ground_y(mid) >= plan.ground_y(end) - 0.01, "bridge deck is highest mid-span")
		for c in b["cells"]:
			_check(nav.walkable(c), "bridge cell %s is walkable" % [c])
			break


func _test_smoothing() -> void:
	var to: Vector2 = plan.cell_center(plan.npcs[0]["cell"])
	var path: Array = nav.world_path(plan.cell_center(plan.spawn), to)
	_check(path.size() >= 2, "a route from the gate to %s" % plan.npcs[0]["id"])
	var cells: Array = nav.cell_path(plan.spawn, plan.npcs[0]["cell"])
	_check(path.size() < cells.size(), "smoothing drops grid steps (%d legs vs %d cells)" % [path.size(), cells.size()])
	for i in range(1, path.size()):
		_check(nav.line_clear(path[i - 1], path[i], 0.2), "leg %d stays on walkable cells" % i)


func _test_build() -> void:
	var b = Builder.new()
	root.add_child(b)
	b.build(plan)
	_check(b.gate_doors.size() == 4, "4 gates with doors")
	_check(b.lamps.size() >= 40, "lamps light the streets (%d)" % b.lamps.size())
	_check(int(b.stats.get("wall_sections", 0)) >= 40 or int(b.stats.get("wall_cells", 0)) > 1000, "the ring is built (%s)" % [b.stats])
	_check(b.spinners.size() == 1, "the mill wheel turns")
	var tc: Dictionary = b.stats.get("terrain_cells", {})
	for mname in ["grass_short", "grass_lush", "dirt_path", "mud", "cobblestone", "plaza_flagstones", "riverbank_pebbles", "wall_base_gravel"]:
		_check(int(tc.get(mname, 0)) > 0, "terrain uses %s (%d cells)" % [mname, int(tc.get(mname, 0))])
	_check(int(tc.get("cobblestone", 0)) > int(tc.get("plaza_flagstones", 0)), "streets are mostly cobbles")
	_check(int(b.stats.get("wind_surfaces", 0)) > 0, "kit trees with wind colours get the foliage wind shader")
	_check(not b.lantern_mats.is_empty(), "the lamppost glass is registered for the night glow")
	b.set_night(1.0)
	_check((b.lantern_mats[0] as BaseMaterial3D).emission_energy_multiplier > 3.0, "lanterns glow at night")
	b.set_night(0.0)
	var stats1: Dictionary = b.stats.duplicate()
	b.update_gates(b.gate_doors[0]["center"])
	_check(b.gate_doors[0]["target"] == 1.0 and b.gate_doors[1]["target"] == 0.0, "only the near gate opens")
	for i in 3:
		await process_frame
	b.queue_free()
	var b2 = Builder.new()
	root.add_child(b2)
	b2.build(plan)
	_check(b2.stats == stats1, "the build is repeatable")
	b2.queue_free()
	await process_frame


func _test_day_night() -> void:
	var e = Env.new()
	root.add_child(e)
	e.setup(plan.city)
	e.set_hour(12.0)
	_check(e.night_amount() == 0.0, "noon is day")
	var noon_sun: float = e.sun.light_energy
	e.set_hour(23.0)
	_check(e.night_amount() == 1.0, "23:00 is night")
	_check(e.sun.light_energy < noon_sun * 0.2, "the sun is down at night")
	e.set_hour(19.0)
	_check(e.night_amount() > 0.0, "lamps come on at dusk")
	e.queue_free()


func _test_hero_walk() -> void:
	var h = Hero.new()
	root.add_child(h)
	h.setup(plan, nav)
	h.place(plan.cell_center(plan.spawn))
	var goal: Vector2 = plan.cell_center(plan.npcs[0]["cell"])
	_check(h.walk_to(goal), "the hero finds a way to %s" % plan.npcs[0]["id"])
	var off_grid := 0
	for i in 4000:
		h._process(1.0 / 30.0)
		if not nav.walkable(plan.world_to_cell(h.ground_pos())):
			off_grid += 1
		if not h.moving:
			break
	_check(not h.moving, "the hero arrives")
	_check(h.ground_pos().distance_to(goal) < plan.cell_m * 1.5, "the hero stops at the target")
	_check(off_grid == 0, "the hero never stands on a blocked cell (%d)" % off_grid)
	h.queue_free()
	await process_frame


func _test_life() -> void:
	var Life = load("res://slice3d/city/city_life3d.gd")
	var life = Life.new()
	root.add_child(life)
	life.setup(plan, nav, 6)
	_check(life.npcs.size() == plan.npcs.size() + 5, "story and role NPCs plus the priest and 4 gate guards (%d)" % life.npcs.size())
	_check(life.bodies_loaded >= life.npcs.size(), "every NPC wears an art kit body (%d)" % life.bodies_loaded)
	var guards := 0
	for a in life.npcs:
		if str(a["data"].get("id", "")).begins_with("gate_guard"):
			guards += 1
			_check((a["wp"] as Array).size() >= 2, "guard %s has a route" % a["data"]["id"])
		if a["body"] != null:
			_check(a["body"].clips.has("walk") and a["body"].clips.has("idle"), "%s has walk and idle" % a["data"]["id"])
	_check(guards == 4, "a guard at each gate")
	life.set_hour(12.5)
	for i in 120:
		life._process(1.0 / 30.0)
	var moving := 0
	for a in life.npcs:
		if not (a["path"] as Array).is_empty():
			moving += 1
	_check(moving > 0, "at noon NPCs walk to the plaza (%d)" % moving)
	var guard_body = null
	for a in life.npcs:
		if str(a["data"].get("id", "")).begins_with("gate_guard") and a["body"] != null:
			guard_body = a["body"]
	if guard_body != null:
		_check(guard_body.spear != null, "the gate guard carries his spear")
		_check(guard_body.walk_clip() == "walk_spear" and guard_body.idle_clip() == "idle_spear", "guards use the spear clips")
		_check(absf(guard_body.walk_speed() - 0.934) < 0.01, "walk speed comes from the model (walk_spear 0.934 m/s)")
	life.queue_free()
	var Animals = load("res://slice3d/city/animals3d.gd")
	var h := Node3D.new()
	root.add_child(h)
	var an = Animals.new()
	root.add_child(an)
	an.setup(plan, nav, h)
	var kinds := {}
	for a in an.animals:
		if not a.is_empty():
			kinds[a["kind"]] = kinds.get(a["kind"], 0) + 1
	for k in ["cat", "dog", "chicken", "duck", "pigeon", "horse"]:
		_check(kinds.has(k), "the city has %s (%d)" % [k, kinds.get(k, 0)])
	_check(an.cart != null and an.ring_route.size() >= 3, "the horse pulls the supply cart round the ring road")
	var pig: Dictionary = {}
	for a in an.animals:
		if not a.is_empty() and a["kind"] == "pigeon":
			pig = a
			break
	h.position = pig["node"].position
	an._process(0.1)
	_check(pig["state"] == "fly", "pigeons take off when the hero comes close")
	an.queue_free()
	h.queue_free()
	await process_frame


func _test_retarget() -> void:
	var needed := ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm",
		"LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]
	var profile := SkeletonProfileHumanoid.new()
	var names := {}
	for i in profile.bone_size:
		names[str(profile.get_bone_name(i))] = true
	for n in needed:
		_check(Retarget.MESHY_TO_HUMANOID.values().has(n), "rig map gives %s" % n)
		_check(names.has(n), "%s is a SkeletonProfileHumanoid bone" % n)
	_check(Retarget.CLIPS.size() == 18 and Retarget.CLIPS[0] == "idle", "the 18-clip standard")
	var a := Animation.new()
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, NodePath("Armature/Skeleton3D:Hips"))
	a.position_track_insert_key(t, 0.0, Vector3(0, 1, 0))
	a.position_track_insert_key(t, 1.0, Vector3(0.2, 1.05, 1.5))
	var t2 := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t2, NodePath("Armature/Skeleton3D:LeftArm"))
	Retarget.retarget_animation(a)
	_check(str(a.track_get_path(t2)) == "Armature/Skeleton3D:LeftUpperArm", "tracks follow the humanoid names")
	var last: Vector3 = a.track_get_key_value(t, 1)
	_check(is_zero_approx(last.x) and is_zero_approx(last.z) and absf(last.y - 1.05) < 0.001, "clips play in place (no root motion)")
