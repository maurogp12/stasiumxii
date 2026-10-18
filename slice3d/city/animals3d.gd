extends Node3D

## Crosshaven's animals (art kit, custom skeletons, clips in the model):
## cats and dogs by house doors, chickens in back yards, ducks on the river,
## pigeons on the plaza that take off when the hero comes close, and a cart
## horse pulling the supply cart round the ring road. Counts and spots come
## from data/world/city3d/animals3d.json; speeds from each animal's JSON
## (move_speed_mps), so the feet do not skate.

const ModelLoader := preload("res://slice3d/city/model_loader.gd")
const CFG := "res://data/world/city3d/animals3d.json"

var plan
var nav
var hero: Node3D
var cfg: Dictionary = {}
var animals: Array = []   ## {kind, node, anim, info, home, path, timer, state, speed}
var _rng := RandomNumberGenerator.new()
var _protos := {}


func setup(p, n, h: Node3D) -> void:
	plan = p
	nav = n
	hero = h
	_rng.seed = 77
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(CFG)) if FileAccess.file_exists(CFG) else {}
	cfg = v if v is Dictionary else {}
	var doors: Array = []
	var yards: Array = []
	var plaza: Vector2 = plan.ring_center
	for pc in plan.pieces:
		if str(pc["kind"]).begins_with("house_npc") and pc.has("door"):
			doors.append(plan.cell_center(pc["door"]))
			var back: Vector2 = (pc["center"] as Vector2) * 2.0 - plan.cell_center(pc["door"])
			yards.append(plan.cell_center(plan.nearest_passable(plan.world_to_cell(back), 3)))
		if str(pc["kind"]) == "fountain":
			plaza = pc["center"]
	var water: Array = []
	for y in range(0, plan.height, 2):
		for x in range(0, plan.width, 2):
			var c := Vector2i(x, y)
			if plan.is_water(c) and plan.wall_cells.is_empty() == false and (plan.cell_center(c) as Vector2).distance_to(plan.ring_center) < 150.0:
				water.append(plan.cell_center(c))
	var counts: Dictionary = cfg.get("counts", {})
	for i in int(counts.get("cat", 0)):
		_spawn("cat", _pick(doors), "near_home")
	for i in int(counts.get("dog", 0)):
		_spawn("dog", _pick(doors), "near_home")
	for i in int(counts.get("chicken", 0)):
		var y0: Vector2 = _pick(yards)
		for k in 2:
			_spawn("chicken", y0 + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)), "yard")
	for i in int(counts.get("duck", 0)):
		if not water.is_empty():
			_spawn("duck", water[_rng.randi() % water.size()], "water")
	for i in int(counts.get("pigeon", 0)):
		var a := _rng.randf() * TAU
		_spawn("pigeon", plaza + Vector2(cos(a), sin(a)) * _rng.randf_range(3.0, 8.0), "plaza")
	if int(counts.get("horse_cart", 0)) > 0:
		_spawn_cart()


func _pick(list: Array) -> Vector2:
	if list.is_empty():
		return plan.cell_center(plan.spawn)
	return list[_rng.randi() % list.size()]


func _info(kind: String) -> Dictionary:
	var jp := str(cfg.get("dir", "res://art/3d/animals/")) + "ani_%s.json" % kind
	if not FileAccess.file_exists(jp):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp))
	return v if v is Dictionary else {}


func _spawn(kind: String, at: Vector2, role: String) -> Dictionary:
	var node: Node3D = ModelLoader.instance(str(cfg.get("dir", "res://art/3d/animals/")) + "ani_%s_LOD0.glb" % kind)
	if node == null:
		return {}
	var root := Node3D.new()
	add_child(root)
	root.add_child(node)
	var y: float = plan.ground_y(at)
	if role == "water":
		y = float(plan.city.get("water", {}).get("level", -0.45)) - 0.05
	root.position = Vector3(at.x, y, at.y)
	root.rotation.y = _rng.randf() * TAU
	var ap := ModelLoader.find_player(node)
	var info := _info(kind)
	var a := {"kind": kind, "node": root, "anim": ap, "info": info, "home": at, "path": [], "timer": _rng.randf_range(0.5, 6.0),
		"state": "idle", "role": role, "clip": ""}
	if ap != null:
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for nm in lib.get_animation_list():
				var an := lib.get_animation(nm)
				an.loop_mode = Animation.LOOP_NONE if str(nm) == "takeoff" else Animation.LOOP_LINEAR
		ap.speed_scale = _rng.randf_range(0.9, 1.1)
	_play(a, _idle_of(kind))
	animals.append(a)
	return a


func _speed(a: Dictionary, clip: String) -> float:
	var ms: Dictionary = a["info"].get("move_speed_mps", {})
	return float(ms.get(clip, 0.5))


func _idle_of(kind: String) -> String:
	return {"cat": "sit", "dog": "sit", "chicken": "peck", "duck": "peck", "pigeon": "peck", "horse": "graze"}.get(kind, "idle")


func _play(a: Dictionary, clip: String) -> void:
	var ap: AnimationPlayer = a["anim"]
	if ap == null or a["clip"] == clip:
		return
	if not ap.has_animation(clip):
		clip = "idle"
		if not ap.has_animation(clip):
			return
	a["clip"] = clip
	ap.play(clip, 0.25)


# ---------------------------------------------------------------- cart

var cart: Node3D
var cart_horse: Dictionary = {}
var ring_route: Array = []


## The supply cart: the horse walks (walk_cart) a loop just inside the
## walls, the cart rigid behind it.
func _spawn_cart() -> void:
	var inset := float(cfg.get("cart_inset_m", 16.0))
	for p in plan.ring:
		var q: Vector2 = (p as Vector2).move_toward(plan.ring_center, inset)
		var c: Vector2i = plan.nearest_passable(plan.world_to_cell(q), 8)
		ring_route.append(plan.cell_center(c))
	if ring_route.size() < 3:
		return
	cart_horse = _spawn("horse", ring_route[0], "cart")
	if cart_horse.is_empty():
		return
	var cp := str(cfg.get("cart_glb", ""))
	cart = ModelLoader.instance(cp) if ModelLoader.exists(cp) else null
	if cart != null:
		(cart_horse["node"] as Node3D).add_child(cart)
		cart.position = Vector3(0, 0, -float(cfg.get("cart_offset_m", 3.0)))
	cart_horse["wp"] = 0


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	var hp := Vector2(hero.position.x, hero.position.z) if hero != null else Vector2(1e9, 1e9)
	for a in animals:
		if a.is_empty():
			continue
		match str(a["role"]):
			"cart":
				_tick_cart(a, delta)
			"plaza":
				_tick_pigeon(a, delta, hp)
			"water":
				_tick_wander(a, delta, hp, 6.0, true)
			"yard":
				_tick_wander(a, delta, hp, 3.0, false)
			_:
				_tick_wander(a, delta, hp, 7.0, false)


func _tick_wander(a: Dictionary, delta: float, hp: Vector2, radius: float, on_water: bool) -> void:
	var node: Node3D = a["node"]
	var here := Vector2(node.position.x, node.position.z)
	var flee: bool = str(a["kind"]) in ["cat", "chicken"] and here.distance_to(hp) < 2.0
	if (a["path"] as Array).is_empty():
		a["timer"] -= delta
		if a["timer"] <= 0.0 or flee:
			var goal: Vector2 = a["home"] + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius))
			if flee:
				goal = here + (here - hp).normalized() * 5.0
			if on_water:
				if plan.is_water(plan.world_to_cell(goal)):
					a["path"] = [goal]
			else:
				var r: Array = nav.world_path(here, goal)
				if r.size() > 1:
					r.remove_at(0)
					a["path"] = r
			a["run"] = flee
			a["timer"] = _rng.randf_range(4.0, 14.0)
			if (a["path"] as Array).is_empty():
				_play(a, _idle_of(str(a["kind"])) if _rng.randf() < 0.6 else "idle")
		return
	var clip := "run" if a.get("run", false) else "walk"
	_play(a, clip)
	if _step(a, delta, _speed(a, clip), on_water):
		_play(a, _idle_of(str(a["kind"])) if _rng.randf() < 0.6 else "idle")


func _tick_pigeon(a: Dictionary, delta: float, hp: Vector2) -> void:
	var node: Node3D = a["node"]
	var here := Vector2(node.position.x, node.position.z)
	if a["state"] == "fly":
		node.position += a["vel"] * delta
		a["timer"] -= delta
		if a["clip"] == "takeoff" and not (a["anim"] as AnimationPlayer).is_playing():
			_play(a, "fly")
		if a["timer"] <= 0.0:
			# land back on the plaza, away from the hero
			var ang := _rng.randf() * TAU
			var land: Vector2 = a["home"] + Vector2(cos(ang), sin(ang)) * _rng.randf_range(2.0, 6.0)
			node.position = Vector3(land.x, plan.ground_y(land), land.y)
			a["state"] = "idle"
			_play(a, "peck")
		return
	if here.distance_to(hp) < float(cfg.get("pigeon_scatter_m", 4.0)):
		a["state"] = "fly"
		var away := (here - hp).normalized()
		if away.length() < 0.1:
			away = Vector2(1, 0)
		a["vel"] = Vector3(away.x * 5.0, 3.0, away.y * 5.0)
		node.rotation.y = atan2(away.x, away.y)
		a["timer"] = float(cfg.get("pigeon_return_s", 18.0))
		_play(a, "takeoff")
		return
	_tick_wander(a, delta, hp, 3.0, false)


func _tick_cart(a: Dictionary, delta: float) -> void:
	if ring_route.is_empty():
		return
	if (a["path"] as Array).is_empty():
		a["wp"] = (int(a["wp"]) + 1) % ring_route.size()
		var node: Node3D = a["node"]
		var r: Array = nav.world_path(Vector2(node.position.x, node.position.z), ring_route[a["wp"]])
		if r.size() > 1:
			r.remove_at(0)
		a["path"] = r
		return
	var clip := "walk_cart" if cart != null else "walk"
	_play(a, clip)
	_step(a, delta, _speed(a, clip), false)


## Moves along the path; returns true on arrival.
func _step(a: Dictionary, delta: float, speed: float, on_water: bool) -> bool:
	var path: Array = a["path"]
	var node: Node3D = a["node"]
	var here := Vector2(node.position.x, node.position.z)
	var tgt: Vector2 = path[0]
	var np := here.move_toward(tgt, speed * delta)
	var y: float = node.position.y if on_water else plan.ground_y(np)
	node.position = Vector3(np.x, y, np.y)
	var d := tgt - here
	if d.length() > 0.01:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(d.x, d.y), minf(1.0, delta * 5.0))
	if np.distance_to(tgt) < 0.05:
		path.remove_at(0)
		return path.is_empty()
	return false
