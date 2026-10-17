extends Node2D

## City life on the modular Crosshaven (round 25).
##
## Townsfolk keep a day: home until morning, out to work (their workshop,
## stall or post), the plaza at noon, back to work, an evening by the town
## hall (the tavern-ish corner), home at night (indoors; the warden walks the
## gates). Each change of phase sends the NPC across town on the walk grid
## (WorldNpc.send); once there it roams round the spot.
##
## Animals: cats and dogs by the house doors, chickens behind the houses,
## ducks on the river; each wanders a little round its spot on the walk grid
## (ducks on the water tiles), y-sorted with everyone else.

const PlateCity := preload("res://backend/plate_city.gd")
const ANIM := "res://art/world/crosshaven/animated/"
const PETS := "res://art/world/crosshaven_city/pets/"

## [from hour, phase]
const DAY := [[0.0, "home"], [6.5, "work"], [12.0, "plaza"], [13.0, "work"], [18.0, "tavern"], [21.0, "home"]]
const WORK_OF_ROLE := {
	"smith": "workshop", "forge_master": "workshop", "trader": "stall", "herald": "plaza",
	"banker": "bank", "archivist": "townhall", "elder": "townhall", "door_keeper": "gate",
	"guide": "plaza", "farmer": "stall", "fisher": "river", "woodcutter": "workshop", "warden": "gate",
}

var world: Node2D
var city
var places := {}
var homes: Array[Vector2i] = []
var plan := {}
var animals: Array = []
var _rng := RandomNumberGenerator.new()
var _hour := -1.0
var _tex := {}


func setup(w: Node2D, c) -> void:
	world = w
	city = c
	name = "CityLife"
	_rng.seed = 25
	_find_places()
	_build_animals()


func _old_cell(world_p: Vector2) -> Vector2i:
	var u := (world_p.x / 32.0 + world_p.y / 16.0) * 0.5
	var v := (world_p.y / 16.0 - world_p.x / 32.0) * 0.5
	return Vector2i(roundi(u), roundi(v))


func _walkable_near(c: Vector2i, r_max: int = 6) -> Vector2i:
	var z: WorldZone = world.zone
	if z.passable_at(c):
		return c
	for r in range(1, r_max + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and z.passable_at(c + Vector2i(dx, dy)):
					return c + Vector2i(dx, dy)
	return Vector2i(-1, -1)


## The walkable cell just in front (south) of a piece: its door.
func _door_of(p: Dictionary) -> Vector2i:
	var foot: Vector2 = city.tile.piece_foot(p) + Vector2(0, city.tile.tile.y * 0.8)
	return _walkable_near(_old_cell(foot))


func _find_places() -> void:
	var z: WorldZone = world.zone
	for key in ["workshop", "stall", "plaza", "bank", "townhall", "gate", "river", "tavern"]:
		places[key] = []
	if city.tile_mode():
		for p in city.tile.pieces():
			var kind := TileCity.kind_group(str(p["kind"]))
			var d := Vector2i(-1, -1)
			if kind == "house" and p.has("door_cell"):
				d = _walkable_near(_old_cell(city.tile.cell_to_world(Vector2(float(p["door_cell"][0]), float(p["door_cell"][1])))))
			elif kind in ["house", "workshop", "stall", "fountain", "bank", "townhall", "mill", "gate"]:
				d = _door_of(p)
			if d.x < 0:
				continue
			match kind:
				"house":
					homes.append(d)
				"workshop", "mill":
					places["workshop"].append(d)
				"stall":
					places["stall"].append(d)
				"fountain":
					places["plaza"].append(d)
				"bank":
					places["bank"].append(d)
				"townhall":
					places["townhall"].append(d)
					places["tavern"].append(d)
				"gate":
					places["gate"].append(d)
	# the river bank: walkable cells beside the water
	for y in range(0, z.height, 3):
		for x in range(0, z.width, 3):
			var c := Vector2i(x, y)
			if z.passable_at(c) and z.terrain_at(c + Vector2i(1, 0)) == "water":
				places["river"].append(c)
	for key in places.keys():
		if (places[key] as Array).is_empty() and not homes.is_empty():
			places[key] = [homes[0]]
	var i := 0
	for node in world.npcs_root.get_children():
		var role := str(node.get("role"))
		var work_kind := str(WORK_OF_ROLE.get(role, "plaza"))
		var pick := func(kind: String) -> Vector2i:
			var arr: Array = places.get(kind, [])
			return arr[(i * 7 + kind.length()) % arr.size()] if not arr.is_empty() else node.cell
		plan[node] = {
			"home": homes[(i * 5) % homes.size()] if not homes.is_empty() else node.cell,
			"work": pick.call(work_kind),
			"plaza": pick.call("plaza"),
			"tavern": pick.call("tavern"),
			"night_out": role == "warden",
			"phase": "",
			"lag": _rng.randf_range(0.0, 0.6),
		}
		i += 1


func phase_at(hour: float, lag: float = 0.0) -> String:
	var h := fposmod(hour - lag, 24.0)
	var out := "home"
	for row in DAY:
		if h >= float(row[0]):
			out = str(row[1])
	return out


func target_for(node: Node2D, phase: String) -> Vector2i:
	var p: Dictionary = plan[node]
	if phase == "home" and bool(p["night_out"]):
		return p["work"]
	return p.get(phase, p["home"])


## True while the NPC should be drawn: at night only once home is reached it
## goes indoors (the warden stays out).
func npc_visible(node: Node2D) -> bool:
	if not plan.has(node):
		return true
	var p: Dictionary = plan[node]
	if str(p["phase"]) != "home" or bool(p["night_out"]):
		return true
	return not bool(node.get("arrived_errand")) or node.cell != p["home"]


func tick(delta: float, hour: float) -> void:
	_hour = hour
	for node in plan.keys():
		if not is_instance_valid(node):
			continue
		var p: Dictionary = plan[node]
		var ph := phase_at(hour, float(p["lag"]))
		if ph != str(p["phase"]):
			p["phase"] = ph
			var t := target_for(node, ph)
			if t != node.cell:
				var route := route_between(node.cell, t)
				if not route.is_empty():
					node.send(route)
	_tick_animals(delta, hour)


## 4-connected route on the walk grid (cells after `from`, ending at `to`).
func route_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var z: WorldZone = world.zone
	var out: Array[Vector2i] = []
	if not z.passable_at(to):
		return out
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == to:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not prev.has(n) and z.passable_at(n):
				prev[n] = c
				q.append(n)
	if not prev.has(to):
		return out
	var c2 := to
	while c2 != from:
		out.push_front(c2)
		c2 = prev[c2]
	return out


# ------------------------------------------------------------ animals

func _strip(file: String, frames: int) -> Dictionary:
	if _tex.has(file):
		return _tex[file]
	var t: Texture2D = load(file) as Texture2D
	if t == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(file))
		if img != null:
			t = ImageTexture.create_from_image(img)
	var d := {"tex": t, "frames": frames}
	_tex[file] = d
	return d


func _duck_texture() -> Texture2D:
	# placeholder until the nature kit: a small white duck, orange bill
	if _tex.has("duck"):
		return _tex["duck"]
	var img := Image.create(22, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 22:
			var body := pow((x - 9.0) / 8.5, 2) + pow((y - 9.0) / 4.5, 2) <= 1.0
			var head := pow((x - 16.0) / 3.5, 2) + pow((y - 4.5) / 3.5, 2) <= 1.0
			var bill := x >= 19 and x <= 21 and y >= 4 and y <= 6
			if bill:
				img.set_pixel(x, y, Color(0.95, 0.6, 0.15))
			elif head:
				img.set_pixel(x, y, Color(0.2, 0.5, 0.25))
			elif body:
				img.set_pixel(x, y, Color(0.96, 0.95, 0.9) if y < 11 else Color(0.8, 0.8, 0.78))
	var t := ImageTexture.create_from_image(img)
	_tex["duck"] = t
	return t


func _add_animal(kind: String, at: Vector2i, cells: Dictionary) -> void:
	var s := Sprite2D.new()
	s.centered = false
	s.z_as_relative = false
	var spec := {}
	match kind:
		"cat":
			spec = {"walk": _strip(ANIM + "cat_walk.png", 6), "idle": _strip(ANIM + "cat_idle.png", 6), "speed": 18.0}
		"chicken":
			spec = {"walk": _strip(ANIM + "chicken_walk.png", 6), "idle": _strip(ANIM + "chicken_peck.png", 6), "speed": 10.0}
		"dog":
			spec = {"still": PETS + "pet_dog.png", "speed": 26.0}
		"duck":
			spec = {"speed": 8.0}
	if spec.has("walk"):
		var t: Texture2D = spec["walk"]["tex"]
		s.texture = t
		s.region_enabled = true
		var fw := t.get_width() / int(spec["walk"]["frames"])
		s.region_rect = Rect2(0, 0, fw, t.get_height())
		s.offset = -Vector2(fw * 0.5, t.get_height())
	elif spec.has("still"):
		s.texture = load(str(spec["still"])) as Texture2D
		s.offset = -Vector2(s.texture.get_width() * 0.5, s.texture.get_height())
	else:
		s.texture = _duck_texture()
		s.offset = -Vector2(11, 12)
	s.name = "%s_%d" % [kind, animals.size()]
	add_child(s)
	var pos := BoardVisualSort.cell_to_local(at)
	s.position = pos
	animals.append({"node": s, "kind": kind, "spec": spec, "cells": cells.keys(), "home": at, "target": pos,
		"wait": _rng.randf_range(0.0, 3.0), "t": 0.0, "night": kind in ["cat", "duck"]})


func _area(center: Vector2i, r: int, water: bool) -> Dictionary:
	var z: WorldZone = world.zone
	var out := {}
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := center + Vector2i(dx, dy)
			if not z.in_bounds(c):
				continue
			if water and z.terrain_at(c) == "water":
				out[c] = true
			elif not water and z.passable_at(c):
				out[c] = true
	return out


func _build_animals() -> void:
	var z: WorldZone = world.zone
	if homes.is_empty():
		return
	var n_cat := 0
	var n_dog := 0
	for i in range(0, homes.size(), 6):
		var a := _area(homes[i], 3, false)
		if a.size() < 4:
			continue
		if n_cat <= n_dog:
			_add_animal("cat", homes[i], a)
			n_cat += 1
		else:
			_add_animal("dog", homes[i], a)
			n_dog += 1
	# chickens behind (north of) a few houses
	var n_ch := 0
	for i in range(2, homes.size(), 9):
		var behind := _walkable_near(homes[i] - Vector2i(3, 3), 3)
		if behind.x < 0:
			continue
		var a2 := _area(behind, 2, false)
		for k in 3:
			_add_animal("chicken", behind, a2)
			n_ch += 1
	# ducks on the river
	var water: Array[Vector2i] = []
	for y in range(0, z.height, 2):
		for x in range(0, z.width, 2):
			if z.terrain_at(Vector2i(x, y)) == "water":
				water.append(Vector2i(x, y))
	for k in mini(6, water.size() / 20):
		var c: Vector2i = water[(k * 37 + 11) % water.size()]
		_add_animal("duck", c, _area(c, 3, true))


func animal_count(kind: String) -> int:
	var n := 0
	for a in animals:
		if str(a["kind"]) == kind:
			n += 1
	return n


func _tick_animals(delta: float, hour: float) -> void:
	var day: bool = city.is_day(hour)
	for a in animals:
		var s: Sprite2D = a["node"]
		var show: bool = day or bool(a["night"])
		if s.visible != show:
			s.visible = show
		if not show:
			continue
		var spec: Dictionary = a["spec"]
		var to: Vector2 = a["target"]
		var moving := s.position.distance_to(to) > 1.0
		if moving:
			s.position = s.position.move_toward(to, float(spec["speed"]) * delta)
			if absf(to.x - s.position.x) > 0.5:
				s.flip_h = to.x < s.position.x
		else:
			a["wait"] = float(a["wait"]) - delta
			if float(a["wait"]) <= 0.0:
				var cells: Array = a["cells"]
				if not cells.is_empty():
					var c: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
					a["target"] = BoardVisualSort.cell_to_local(c) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-4, 4))
				a["wait"] = _rng.randf_range(2.0, 6.0)
		# frames: walk while moving, idle otherwise
		a["t"] = float(a["t"]) + delta
		var strip: Dictionary = spec.get("walk" if moving else "idle", {})
		if not strip.is_empty():
			var t: Texture2D = strip["tex"]
			if s.texture != t:
				s.texture = t
			var fw := t.get_width() / int(strip["frames"])
			var f := int(float(a["t"]) * (12.0 if moving else 6.0)) % int(strip["frames"])
			s.region_rect = Rect2(f * fw, 0, fw, t.get_height())
		elif moving:
			s.offset.y = -s.texture.get_height() - absf(sin(float(a["t"]) * 10.0)) * 2.0
		s.z_index = clampi(PlateCity.z_for_world_y(s.position.y) + BoardVisualSort.UNIT_Z_BIAS - 1, -4096, 4096)
