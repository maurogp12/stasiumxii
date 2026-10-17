extends Node3D

## City life in 3D: the city's NPCs at their posts with names (and a "!" when
## they give a mission), keeping the same day as the 2D city
## (scenes/world/crosshaven/city_life.gd: home, work, plaza at noon, work,
## evening by the town hall, home), plus townsfolk who stroll the streets by
## day. Everyone walks the same nav grid as the hero.
## Placeholder bodies (capsule figures) until NPC models arrive.

const CityLife2D := preload("res://scenes/world/crosshaven/city_life.gd")
const MISSIONS := "res://data/world/missions.json"

var plan
var nav
var places := {}       ## place name -> Array of Vector2 (world m)
var npcs: Array = []   ## {node, data, path:[], post:Vector2, phase}
var folk: Array = []
var hour := 10.0
var _phase := ""
var _rng := RandomNumberGenerator.new()
var _street_cells: Array = []
var _givers := {}


func setup(p, n, folk_count := 28) -> void:
	plan = p
	nav = n
	_rng.seed = 25
	_find_places()
	_load_givers()
	for d in plan.npcs:
		var post := _post_for(d)
		var node := _figure(_npc_colors(str(d["role"])), str(d["name"]), _givers.has(str(d["id"])))
		add_child(node)
		node.position = Vector3(post.x, 0, post.y)
		npcs.append({"node": node, "data": d, "path": [], "post": post, "speed": 2.4})
	for i in folk_count:
		if _street_cells.is_empty():
			break
		var c: Vector2i = _street_cells[_rng.randi() % _street_cells.size()]
		var tint := Color.from_hsv(_rng.randf(), 0.35, 0.45 + _rng.randf() * 0.2)
		var node := _figure([tint, tint.darkened(0.3), Color(0.7, 0.55, 0.45)], "", false)
		add_child(node)
		var p0: Vector2 = plan.cell_center(c)
		node.position = Vector3(p0.x, 0, p0.y)
		folk.append({"node": node, "path": [], "speed": 1.3 + _rng.randf() * 0.6, "wait": _rng.randf() * 4.0})


func _load_givers() -> void:
	var doc: Dictionary = plan._json(MISSIONS)
	for m in doc.get("missions", []):
		_givers[str(m.get("giver", ""))] = true


func _find_places() -> void:
	var add := func(name: String, p: Vector2):
		if not places.has(name):
			places[name] = []
		places[name].append(p)
	for pc in plan.pieces:
		var k := str(pc["kind"])
		var door: Vector2 = plan.cell_center(pc["door"]) if pc.has("door") else pc["center"] + Vector2(0, pc["size"].y * 0.5 + 1.5)
		if k.begins_with("workshop") or k == "mill":
			add.call("workshop", door)
			add.call(k, door)
		elif k.begins_with("stall"):
			add.call("stall", pc["center"] + Vector2(0, 1.8))
			add.call(k, pc["center"] + Vector2(0, 1.8))
		elif k in ["bank", "townhall", "cathedral", "castle"]:
			add.call(k, door)
		elif k == "fountain" or k == "well" or k == "gazebo":
			add.call("plaza", pc["center"] + Vector2(2.5, 2.5))
		elif k.begins_with("house_npc"):
			add.call("home", door)
		elif k == "quay_section" or k == "rowboat":
			add.call("river", plan.cell_center(plan.nearest_passable(plan.world_to_cell(pc["center"]), 6)))
	for g in plan.gates:
		add.call("gate", g["inside"])
	for y in plan.height:
		for x in plan.width:
			var ch: String = plan.terrain_char(Vector2i(x, y))
			if (ch == "c" or ch == "p") and nav.walkable(Vector2i(x, y)) and (x + y * 3) % 5 == 0:
				_street_cells.append(Vector2i(x, y))


func _post_for(d: Dictionary) -> Vector2:
	var role := str(d["role"])
	var work := str(CityLife2D.WORK_OF_ROLE.get(role, "plaza"))
	var spot: String = {"smith": "workshop_smithy", "forge_master": "workshop_forge", "woodcutter": "workshop_carpenter",
		"trader": "stall_fruit", "farmer": "stall_bakery", "archivist": "townhall", "elder": "townhall"}.get(role, work)
	var list: Array = places.get(spot, places.get(work, []))
	if list.is_empty():
		return plan.cell_center(d["cell"])
	var i := absi(hash(str(d["id"]))) % list.size()
	return plan.cell_center(plan.nearest_passable(plan.world_to_cell(list[i]), 6))


func _npc_colors(role: String) -> Array:
	var c: Color = {"smith": Color(0.3, 0.25, 0.2), "forge_master": Color(0.35, 0.2, 0.15), "trader": Color(0.55, 0.4, 0.2),
		"herald": Color(0.6, 0.15, 0.15), "banker": Color(0.2, 0.25, 0.4), "archivist": Color(0.3, 0.3, 0.45),
		"door_keeper": Color(0.3, 0.32, 0.36), "warden": Color(0.25, 0.3, 0.38), "farmer": Color(0.45, 0.42, 0.25),
		"elder": Color(0.45, 0.4, 0.5), "guide": Color(0.25, 0.45, 0.35), "fisher": Color(0.25, 0.35, 0.45),
		"woodcutter": Color(0.35, 0.3, 0.18)}.get(role, Color(0.4, 0.4, 0.4))
	return [c, c.darkened(0.35), Color(0.72, 0.56, 0.45)]


func _figure(cols: Array, label: String, giver: bool) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.4
	body.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = cols[0]
	m.roughness = 0.95
	body.material_override = m
	body.position.y = 0.72
	root.add_child(body)
	var legs := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.36, 0.5, 0.26)
	legs.mesh = lb
	var lm := StandardMaterial3D.new()
	lm.albedo_color = cols[1]
	legs.material_override = lm
	legs.position.y = 0.25
	root.add_child(legs)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.12
	hs.height = 0.25
	head.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.albedo_color = cols[2]
	head.material_override = hm
	head.position.y = 1.55
	root.add_child(head)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position.y = 2.15
		l.font_size = 48
		l.pixel_size = 0.012
		l.outline_size = 10
		l.modulate = Color(1, 0.95, 0.85)
		l.visibility_range_end = 40.0
		root.add_child(l)
	if giver:
		var g := Label3D.new()
		g.text = "!"
		g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		g.position.y = 2.6
		g.font_size = 96
		g.pixel_size = 0.012
		g.outline_size = 16
		g.modulate = Color(1.0, 0.82, 0.25)
		g.visibility_range_end = 60.0
		root.add_child(g)
	return root


func set_hour(h: float) -> void:
	hour = h
	var phase := "home"
	for row in CityLife2D.DAY:
		if h >= float(row[0]):
			phase = str(row[1])
	if phase == _phase:
		return
	_phase = phase
	for n in npcs:
		var d: Dictionary = n["data"]
		var night_in := phase == "home" and str(d.get("night", "")) == "indoors"
		var goal: Vector2 = n["post"]
		if phase == "plaza":
			goal = _pick("plaza", goal)
		elif phase == "tavern":
			goal = _pick("townhall", goal)
		elif phase == "home":
			goal = _pick("home", goal) if night_in else _pick("gate", goal)
		n["path"] = _route(n["node"], goal)
		n["hide_on_arrival"] = night_in
		(n["node"] as Node3D).visible = true
	for f in folk:
		(f["node"] as Node3D).visible = phase != "home" or _rng.randf() < 0.15


func _pick(place: String, fallback: Vector2) -> Vector2:
	var list: Array = places.get(place, [])
	if list.is_empty():
		return fallback
	return plan.cell_center(plan.nearest_passable(plan.world_to_cell(list[_rng.randi() % list.size()]), 6))


func _route(node: Node3D, goal: Vector2) -> Array:
	var r: Array = nav.world_path(Vector2(node.position.x, node.position.z), goal)
	if r.size() > 0:
		r.remove_at(0)
	return r


func _process(delta: float) -> void:
	for n in npcs:
		if _walk(n, delta) and n.get("hide_on_arrival", false):
			(n["node"] as Node3D).visible = false
			n["hide_on_arrival"] = false
	for f in folk:
		if not (f["node"] as Node3D).visible:
			continue
		if (f["path"] as Array).is_empty():
			f["wait"] -= delta
			if f["wait"] <= 0.0 and not _street_cells.is_empty():
				var c: Vector2i = _street_cells[_rng.randi() % _street_cells.size()]
				var here := Vector2(f["node"].position.x, f["node"].position.z)
				if here.distance_to(plan.cell_center(c)) < 60.0:
					f["path"] = _route(f["node"], plan.cell_center(c))
				f["wait"] = 2.0 + _rng.randf() * 6.0
		else:
			_walk(f, delta)


## Moves along the path; returns true on the frame it arrives.
func _walk(w: Dictionary, delta: float) -> bool:
	var path: Array = w["path"]
	if path.is_empty():
		return false
	var node: Node3D = w["node"]
	var here := Vector2(node.position.x, node.position.z)
	var tgt: Vector2 = path[0]
	var np := here.move_toward(tgt, float(w["speed"]) * delta)
	node.position = Vector3(np.x, plan.ground_y(np), np.y)
	var dir := tgt - here
	if dir.length() > 0.01:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(dir.x, dir.y), minf(1.0, delta * 8.0))
	if np.distance_to(tgt) < 0.05:
		path.remove_at(0)
		return path.is_empty()
	return false
