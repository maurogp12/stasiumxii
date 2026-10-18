extends Node3D

## City life in 3D.
## - Story and role NPCs (city.json, plus the role NPCs of npcs3d.json:
##   the priest, a guard at each gate) wear the art kit's bodies, keep the
##   2D city's day (scenes/world/crosshaven/city_life.gd: home, work, plaza
##   at noon, work, evening by the town hall, home) and, at their post, work
##   a loop: each model's route text becomes waypoints round the post on the
##   walk grid, with its work idles (interact, talk, idle, sit) in between.
##   Never idle more than ~10 s. "!" over mission givers.
## - Townsfolk stroll the streets by day.
## Everyone walks the same nav grid as the hero.

const CityLife2D := preload("res://scenes/world/crosshaven/city_life.gd")
const Body := preload("res://slice3d/city/npc_body.gd")
const MISSIONS := "res://data/world/missions.json"
const NPCS3D := "res://data/world/city3d/npcs3d.json"
const CLIP_WORDS := ["interact", "talk", "idle", "sit"]

var plan
var nav
var cfg: Dictionary = {}
var places := {}       ## place name -> Array of Vector2 (world m)
var npcs: Array = []   ## agents (see _agent)
var folk: Array = []
var hour := 10.0
var _phase := ""
var _rng := RandomNumberGenerator.new()
var _street_cells: Array = []
var _givers := {}
var bodies_loaded := 0


func setup(p, n, folk_count := -1) -> void:
	plan = p
	nav = n
	_rng.seed = 25
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPCS3D)) if FileAccess.file_exists(NPCS3D) else {}
	cfg = v if v is Dictionary else {}
	_find_places()
	_load_givers()
	var models: Dictionary = cfg.get("city", {})
	for d in plan.npcs:
		var post := _post_for(d)
		npcs.append(_agent(d, str(models.get(str(d["id"]), "")), post, true))
	for e in cfg.get("extra", []):
		var ed: Dictionary = (e as Dictionary).duplicate()
		ed["role"] = str(ed.get("post", ""))
		var post := _place_point(str(e.get("post", "plaza")))
		npcs.append(_agent(ed, str(e.get("model", "")), post, true))
	var n_folk := folk_count if folk_count >= 0 else int(cfg.get("folk_count", 24))
	var fm: Array = cfg.get("folk", ["peasant_man"])
	for i in n_folk:
		if _street_cells.is_empty():
			break
		var c: Vector2i = _street_cells[_rng.randi() % _street_cells.size()]
		var a := _agent({"id": "folk_%d" % i, "name": ""}, str(fm[i % fm.size()]), plan.cell_center(c), false)
		if a["body"] == null:
			a["speed"] = 1.2 + _rng.randf() * 0.5
		a["wait"] = _rng.randf() * 4.0
		folk.append(a)


# ---------------------------------------------------------------- agents

func _agent(d: Dictionary, model: String, post: Vector2, labelled: bool) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(post.x, 0, post.y)
	var body = null
	if model != "":
		body = Body.new()
		root.add_child(body)
		if body.setup(str(cfg.get("dir", "res://art/3d/npcs/")), model):
			bodies_loaded += 1
		else:
			body.queue_free()
			body = null
	if body == null:
		root.add_child(_figure(_npc_colors(str(d.get("role", "")))))
	if labelled and str(d.get("name", "")) != "":
		var l := Label3D.new()
		l.text = str(d["name"])
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position.y = 2.2
		l.font_size = 48
		l.pixel_size = 0.012
		l.outline_size = 10
		l.modulate = Color(1, 0.95, 0.85)
		l.visibility_range_end = 40.0
		root.add_child(l)
		if _givers.has(str(d.get("id", ""))):
			var g := Label3D.new()
			g.text = "!"
			g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			g.position.y = 2.65
			g.font_size = 96
			g.pixel_size = 0.012
			g.outline_size = 16
			g.modulate = Color(1.0, 0.82, 0.25)
			g.visibility_range_end = 60.0
			root.add_child(g)
	var a := {"node": root, "body": body, "data": d, "post": post, "anchor": post, "path": [],
		"speed": 1.6, "timer": _rng.randf_range(1.0, 4.0), "wp": [], "wp_i": 0, "work": ["interact", "idle", "talk"]}
	if body != null:
		a["speed"] = body.walk_speed(1.4)
		a["work"] = _work_clips(body)
		a["wp"] = _waypoints(post, body.behaviour(), str(d.get("id", "")))
	else:
		a["wp"] = _waypoints(post, {}, str(d.get("id", "")))
	return a


## Work idles from the model's behaviour text, as clip names it has.
func _work_clips(body) -> Array:
	var out: Array = []
	for line in (body.behaviour().get("work_idles", []) as Array):
		var low := str(line).to_lower()
		for w in CLIP_WORDS:
			if low.begins_with(w) or low.contains(w + " ") or low.contains(" " + w):
				if body.clips.has(w):
					out.append(w)
				break
	if out.is_empty():
		for w in ["interact", "idle", "talk"]:
			if body.clips.has(w):
				out.append(w)
	return out


## The route text ("anvil <-> water trough <-> wood pile") becomes one
## waypoint per stop, spread round the post on walkable, reachable cells.
func _waypoints(post: Vector2, beh: Dictionary, seed_id: String) -> Array:
	var text := str(beh.get("suggested_route", ""))
	var stops := 3
	if text != "":
		var t := text.replace("<->", "|").replace("->", "|").replace(",", "|").replace(";", "|")
		stops = clampi(t.split("|", false).size(), 2, 5)
	var out: Array = []
	var base := float(absi(hash(seed_id)) % 360) / 360.0 * TAU
	for i in stops:
		var a := base + TAU * i / stops
		var r := 2.5 + float((absi(hash(seed_id + str(i))) % 100)) / 100.0 * 3.0
		var c: Vector2i = plan.nearest_passable(plan.world_to_cell(post + Vector2(cos(a), sin(a)) * r), 4)
		var p: Vector2 = plan.cell_center(c)
		if not nav.world_path(post, p).is_empty() or p.distance_to(post) < 0.5:
			out.append(p)
	if out.is_empty():
		out.append(post)
	return out


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
		add.call("gate:" + str(g["id"]), g["inside"] + (g["dir"] as Vector2).orthogonal() * 2.5)
	for y in plan.height:
		for x in plan.width:
			var ch: String = plan.terrain_char(Vector2i(x, y))
			if (ch == "c" or ch == "p") and nav.walkable(Vector2i(x, y)) and (x + y * 3) % 5 == 0:
				_street_cells.append(Vector2i(x, y))


func _place_point(place: String) -> Vector2:
	var list: Array = places.get(place, [])
	if list.is_empty():
		list = places.get("plaza", [plan.cell_center(plan.spawn)])
	return plan.cell_center(plan.nearest_passable(plan.world_to_cell(list[0]), 6))


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
	var c: Color = {"smith": Color(0.3, 0.25, 0.2), "trader": Color(0.55, 0.4, 0.2), "herald": Color(0.6, 0.15, 0.15),
		"banker": Color(0.2, 0.25, 0.4), "warden": Color(0.25, 0.3, 0.38), "guide": Color(0.25, 0.45, 0.35)}.get(role, Color(0.4, 0.4, 0.4))
	return [c, c.darkened(0.35), Color(0.72, 0.56, 0.45)]


func _figure(cols: Array) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.4
	body.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = cols[0]
	body.material_override = m
	body.position.y = 0.72
	root.add_child(body)
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
	return root


# ---------------------------------------------------------------- the day

func set_hour(h: float) -> void:
	hour = h
	var phase := "home"
	for row in CityLife2D.DAY:
		if h >= float(row[0]):
			phase = str(row[1])
	if phase == _phase:
		return
	_phase = phase
	for a in npcs:
		var d: Dictionary = a["data"]
		var night_in := phase == "home" and str(d.get("night", "")) == "indoors"
		var anchor: Vector2 = a["post"]
		var guard := str(d.get("role", "")).begins_with("gate") or str(d.get("role", "")) in ["warden", "door_keeper"]
		if not guard:
			if phase == "plaza":
				anchor = _pick("plaza", anchor)
			elif phase == "tavern":
				anchor = _pick("townhall", anchor)
			elif night_in:
				anchor = _pick("home", anchor)
		a["anchor"] = anchor
		a["wp"] = _waypoints(anchor, a["body"].behaviour() if a["body"] != null else {}, str(d.get("id", "")) + phase)
		a["wp_i"] = 0
		a["path"] = _route(a["node"], anchor)
		a["hide_on_arrival"] = night_in
		(a["node"] as Node3D).visible = true
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


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	for a in npcs:
		_tick_worker(a, delta)
	for f in folk:
		if (f["node"] as Node3D).visible:
			_tick_folk(f, delta)


func _tick_worker(a: Dictionary, delta: float) -> void:
	if not (a["node"] as Node3D).visible:
		return
	if not (a["path"] as Array).is_empty():
		if _walk(a, delta):
			if a.get("hide_on_arrival", false):
				(a["node"] as Node3D).visible = false
				a["hide_on_arrival"] = false
				return
			_start_work(a)
		return
	a["timer"] -= delta
	if a["timer"] <= 0.0:
		var wps: Array = a["wp"]
		a["wp_i"] = (int(a["wp_i"]) + 1) % wps.size()
		a["path"] = _route(a["node"], wps[a["wp_i"]])
		if (a["path"] as Array).is_empty():
			_start_work(a)


## At a waypoint: a work idle for a few seconds (never longer than ~10 s).
func _start_work(a: Dictionary) -> void:
	var work: Array = a["work"]
	var clip := str(work[_rng.randi() % work.size()]) if not work.is_empty() else "idle"
	if clip == "idle" and a["body"] != null:
		clip = a["body"].idle_clip()
	if a["body"] != null:
		a["body"].play(clip)
	a["timer"] = _rng.randf_range(3.0, 8.0)


func _tick_folk(f: Dictionary, delta: float) -> void:
	if (f["path"] as Array).is_empty():
		f["wait"] -= delta
		if f["body"] != null:
			f["body"].play("talk" if int(f.get("mood", 0)) == 1 else f["body"].idle_clip())
		if f["wait"] <= 0.0 and not _street_cells.is_empty():
			var c: Vector2i = _street_cells[_rng.randi() % _street_cells.size()]
			var here := Vector2(f["node"].position.x, f["node"].position.z)
			if here.distance_to(plan.cell_center(c)) < 60.0:
				f["path"] = _route(f["node"], plan.cell_center(c))
			f["wait"] = 2.0 + _rng.randf() * 6.0
			f["mood"] = _rng.randi() % 2
	else:
		_walk(f, delta)


## Moves along the path; returns true on the frame it arrives.
func _walk(w: Dictionary, delta: float) -> bool:
	var path: Array = w["path"]
	if path.is_empty():
		return false
	if w["body"] != null:
		w["body"].play(w["body"].walk_clip())
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
