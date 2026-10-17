extends Node3D

## Generic 3D city builder: a city plan (city_plan.gd) in, a 3D scene out.
##
## Builds the terrain (one mesh, terrain colours blended per cell corner and
## a procedural setts / grass shader), water, the ring wall with its towers,
## gatehouses with doors that open, water tunnels, bridges, every building
## and prop of the layout as placeholder geometry sized in metres from the
## scale table, lamps and window glow for the night, chimney smoke and the
## mill wheel. Repeated pieces are batched into MultiMeshes.
##
## Model swap: when res://art/3d/<kind>.glb exists for a piece kind, that
## model is placed instead of the placeholder (pivot at foot centre, +Z front).

const MeshKit := preload("res://slice3d/city/mesh_kit.gd")
const CityPlan := preload("res://slice3d/city/city_plan.gd")
const ModelLoader := preload("res://slice3d/city/model_loader.gd")
const TERRAIN_SHADER := preload("res://slice3d/city/terrain.gdshader")
const WATER_SHADER := preload("res://slice3d/city/water.gdshader")
const MODEL_DIR := "res://art/3d/"

var plan: CityPlan
var kit: MeshKit
var cm := 2.0
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var window_mat: StandardMaterial3D
var lantern_mat: StandardMaterial3D
var lamps: Array = []          ## OmniLight3D, on at night
var fires: Array = []          ## OmniLight3D on the towers (braziers)
var gate_doors: Array = []     ## {id, center(Vector3), hinges:[Node3D, Node3D], open(float), sign}
var spinners: Array = []       ## Node3D spun around local X (mill wheel)
var smokes: Array = []
var labels: Array = []
var stats := {}
var _rng := RandomNumberGenerator.new()
var _models := {}


func build(p) -> void:
	plan = p
	cm = plan.cell_m
	kit = MeshKit.new(plan.city.get("materials", {}))
	_rng.seed = 12
	_make_materials()
	_build_terrain()
	_build_water()
	_build_ring()
	_build_gates()
	_build_tunnels()
	_build_bridges()
	for piece in plan.pieces:
		_build_piece(piece)
	_build_outskirts()
	stats["batched"] = kit.flush(self)


# ---------------------------------------------------------------- helpers

func v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


func _hash(c: Vector2i) -> float:
	return fposmod(sin(float(c.x) * 12.9898 + float(c.y) * 78.233) * 43758.5453, 1.0)


func _make_materials() -> void:
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN_SHADER
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	var w: Dictionary = plan.city.get("water", {})
	if w.has("shallow"):
		water_mat.set_shader_parameter("shallow", Color(w["shallow"][0], w["shallow"][1], w["shallow"][2]))
		water_mat.set_shader_parameter("deep", Color(w["deep"][0], w["deep"][1], w["deep"][2]))
	window_mat = StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.09, 0.08, 0.07)
	window_mat.roughness = 0.4
	window_mat.emission_enabled = true
	window_mat.emission = Color(1.0, 0.62, 0.3)
	window_mat.emission_energy_multiplier = 0.0
	window_mat.vertex_color_use_as_albedo = true
	lantern_mat = StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(0.35, 0.3, 0.2)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(1.0, 0.7, 0.35)
	lantern_mat.emission_energy_multiplier = 0.2
	lantern_mat.vertex_color_use_as_albedo = true


## Night glow: 0 by day, 1 at night.
func set_night(t: float) -> void:
	window_mat.emission_energy_multiplier = 2.2 * t
	lantern_mat.emission_energy_multiplier = 0.2 + 5.0 * t
	for l in lamps:
		l.visible = t > 0.05
		l.light_energy = 2.4 * t
	for f in fires:
		f.light_energy = 1.0 + 3.0 * t


func _process(delta: float) -> void:
	for s in spinners:
		s.rotate_object_local(Vector3.RIGHT, delta * 0.6)
	for g in gate_doors:
		var target: float = g["target"]
		g["open"] = move_toward(g["open"], target, delta * 0.9)
		var ang: float = g["open"] * deg_to_rad(96.0)
		g["hinges"][0].rotation.y = ang
		g["hinges"][1].rotation.y = -ang
	for f in fires:
		f.light_energy *= 0.96 + 0.08 * randf()


# ---------------------------------------------------------------- terrain

func _cell_terrain(c: Vector2i) -> Dictionary:
	var t: Dictionary = plan.city.get("terrain", {})
	var ch: String = plan.terrain_char(c)
	return t.get(ch, t.get(".", {"color": [0.3, 0.33, 0.18], "alt": [0.35, 0.34, 0.2], "stone": 0.0}))


func _vertex_y(x: int, y: int) -> float:
	var w: Dictionary = plan.city.get("water", {})
	var k := 0
	for c in [Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x - 1, y), Vector2i(x, y)]:
		if plan.terrain_char(c) == "w":
			k += 1
	if k == 0:
		return 0.0
	return lerpf(float(w.get("bank", -0.7)), float(w.get("bed", -1.6)), float(k - 1) / 3.0)


func _build_terrain() -> void:
	var W: int = plan.width
	var H: int = plan.height
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var hs := PackedFloat32Array()
	hs.resize((W + 1) * (H + 1))
	for y in H + 1:
		for x in W + 1:
			hs[y * (W + 1) + x] = _vertex_y(x, y)
	for y in H + 1:
		for x in W + 1:
			var h := hs[y * (W + 1) + x]
			verts.append(Vector3(x * cm, h, y * cm))
			var hl := hs[y * (W + 1) + maxi(x - 1, 0)]
			var hr := hs[y * (W + 1) + mini(x + 1, W)]
			var hu := hs[maxi(y - 1, 0) * (W + 1) + x]
			var hd := hs[mini(y + 1, H) * (W + 1) + x]
			norms.append(Vector3(hl - hr, 2.0 * cm, hu - hd).normalized())
			var acc := Color(0, 0, 0, 0)
			for c in [Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x - 1, y), Vector2i(x, y)]:
				var t := _cell_terrain(c)
				var a: Array = t["color"]
				var b: Array = t.get("alt", a)
				var k := _hash(c)
				acc += Color(lerpf(a[0], b[0], k), lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), float(t.get("stone", 0.0)))
			cols.append(acc / 4.0)
	for y in H:
		for x in W:
			var i := y * (W + 1) + x
			idx.append_array([i, i + 1, i + W + 1, i + 1, i + W + 2, i + W + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = m
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Skirt: fields to the horizon around the layout.
	var size: Vector2 = plan.size_m()
	var far := 2500.0
	var t0: Array = _cell_terrain(Vector2i(-1, -1))["color"]
	var skirt_mat := StandardMaterial3D.new()
	skirt_mat.albedo_color = Color(t0[0], t0[1], t0[2]) * 0.95
	skirt_mat.roughness = 1.0
	for r in [Rect2(-far, -far, size.x + 2 * far, far), Rect2(-far, size.y, size.x + 2 * far, far),
			Rect2(-far, 0, far, size.y), Rect2(size.x, 0, far, size.y)]:
		var pm := PlaneMesh.new()
		pm.size = r.size
		var s := MeshInstance3D.new()
		s.mesh = pm
		s.material_override = skirt_mat
		s.position = Vector3(r.position.x + r.size.x * 0.5, -0.02, r.position.y + r.size.y * 0.5)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
	stats["terrain_verts"] = verts.size()


func _build_water() -> void:
	var size: Vector2 = plan.size_m()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 64
	pm.subdivide_depth = 64
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = pm
	mi.material_override = water_mat
	mi.position = Vector3(size.x * 0.5, float(plan.city.get("water", {}).get("level", -0.45)), size.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- ring wall

func _kitd(name: String) -> Dictionary:
	var d: Dictionary = plan.city.get("kit", {}).get(name, {})
	if d.is_empty() or not ModelLoader.exists(str(d.get("glb", ""))):
		return {}
	return d


## Yaw that turns a model's +Z (its outside face) toward `out`.
static func _yaw_to(out: Vector2) -> float:
	return atan2(out.x, out.y)


func _build_ring() -> void:
	var wk := _kitd("wall")
	if not wk.is_empty() and plan.ring.size() >= 3:
		_build_ring_models(wk)
		return
	var spec: Dictionary = plan.scale_for("wall")
	var h := float(spec.get("h", 8.0))
	var stone := kit.mat("stone", 0.95)
	var dark := kit.mat("stone_dark", 0.95)
	var cells: Dictionary = plan.wall_cells
	var n := 0
	for c in cells.keys():
		var p: Vector2 = plan.cell_center(c)
		var tint := Color(1, 1, 1).darkened(_hash(c) * 0.12)
		kit.add_box("ring", stone, v3(p, h * 0.5), Vector3(cm * 1.02, h, cm * 1.02), 0.0, tint)
		# Merlons on the outer rim: a wall cell with open ground beside it.
		var rim := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(c + d):
				rim = true
		if rim and (c.x + c.y) % 2 == 0:
			kit.add_box("merlon", dark, v3(p, h + 0.6), Vector3(cm * 0.7, 1.2, cm * 0.7))
		# A darker plinth where the wall meets the ground.
		if rim:
			kit.add_box("plinth", dark, v3(p, 0.6), Vector3(cm * 1.08, 1.2, cm * 1.08))
		n += 1
	stats["wall_cells"] = n


func _build_ring_models(wk: Dictionary) -> void:
	var L0 := float(wk.get("length", 8.0))
	var keep_out: Array = []
	var gk: Dictionary = plan.city.get("kit", {}).get("gatehouse", {})
	var gw := float(gk.get("width", 7.75)) * float(gk.get("scale", 1.0))
	for g in plan.gates:
		keep_out.append([g["mid"], gw * 0.5 + 1.0])
	for t in plan.tunnels:
		keep_out.append([t["center"], float(_kitd("tunnel").get("length", 8.0)) * 0.5 + 0.5])
	var ring: Array = plan.ring
	var n := 0
	for i in ring.size():
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		var L := a.distance_to(b)
		if L < 0.5:
			continue
		var nrm := (b - a).orthogonal().normalized()
		if nrm.dot((a + b) * 0.5 - plan.ring_center) < 0.0:
			nrm = -nrm
		var k := maxi(1, roundi(L / L0))
		var sx := L / (k * L0)
		var basis := Basis(Vector3.UP, _yaw_to(nrm)) * Basis.from_scale(Vector3(sx, 1, 1))
		for j in k:
			var c := a.lerp(b, (j + 0.5) / k)
			var blocked := false
			for ko in keep_out:
				if c.distance_to(ko[0]) < float(ko[1]) + L0 * sx * 0.5 - 0.5:
					blocked = true
			if blocked:
				continue
			kit.add_model("wall", str(wk["glb"]), Transform3D(basis, v3(c)))
			n += 1
		# Capped joint at each corner (until the kit has its own end caps).
		var cap: Dictionary = wk.get("cap", {})
		if not cap.is_empty():
			var near_gate := false
			for ko in keep_out:
				if a.distance_to(ko[0]) < float(ko[1]):
					near_gate = true
			if not near_gate:
				kit.add_cyl("wall_cap", kit.mat(str(cap.get("material", "stone")), 0.95), v3(a), float(cap.get("radius", 1.6)), float(cap.get("h", 6.6)), 10)
	stats["wall_sections"] = n


func _build_gates() -> void:
	var gk := _kitd("gatehouse")
	if not gk.is_empty():
		_build_gate_models(gk)
		return

	var spec: Dictionary = plan.scale_for("gate")
	var h := float(spec.get("h", 11.0))
	var arch_h := float(spec.get("arch", 5.6))
	for g in plan.gates:
		var dir: Vector2 = g["dir"]
		var perp := Vector2(-dir.y, dir.x)
		var arch: Vector2 = g["arch"]
		# Passage width: the gate cells close to the arch line, across it.
		var lo := 1e9
		var hi := -1e9
		for c in g["cells"]:
			var q: Vector2 = plan.cell_center(c) - arch
			if absf(q.dot(dir)) < cm * 1.6:
				lo = minf(lo, q.dot(perp))
				hi = maxf(hi, q.dot(perp))
		var width := clampf(hi - lo + cm, 4.0, 9.0)
		var mid := arch + perp * (lo + hi) * 0.5
		var yaw := atan2(-perp.y, perp.x)  # local +X along perp
		var depth := 7.0
		var root := Node3D.new()
		root.name = "Gate_%s" % g["id"]
		root.position = v3(mid)
		root.rotation.y = yaw
		add_child(root)
		var stone := kit.mat("stone_pale", 0.92)
		var dark := kit.mat("stone_dark", 0.95)
		var pillar := 3.2
		for side in [-1.0, 1.0]:
			var px: float = side * (width * 0.5 + pillar * 0.5)
			_part(root, kit.box(), stone, Vector3(px, h * 0.5, 0), Vector3(pillar, h, depth))
			_part(root, kit.box(), dark, Vector3(px, h + 0.7, 0), Vector3(pillar + 0.6, 1.4, depth + 0.6))
		_part(root, kit.box(), stone, Vector3(0, (h + arch_h) * 0.5, 0), Vector3(width, h - arch_h, depth))
		# rounded arch soffit (a half cylinder reads as the vault)
		var vault := MeshInstance3D.new()
		vault.mesh = kit.cyl(16)
		vault.material_override = dark
		vault.scale = Vector3(width, depth + 0.05, width * 0.55)
		vault.rotation = Vector3(PI * 0.5, 0, 0)
		vault.position = Vector3(0, arch_h, 0)
		root.add_child(vault)
		for i in 5:
			var mx := lerpf(-width * 0.5 - pillar, width * 0.5 + pillar, (i + 0.5) / 5.0)
			_part(root, kit.box(), dark, Vector3(mx, h + 1.9, depth * 0.5 - 0.4), Vector3(1.0, 1.0, 0.8))
		# Timber doors, hinged at the arch sides, opening inward.
		var wood := kit.mat("wood", 0.85)
		var iron := kit.mat("iron", 0.6)
		var hinges: Array = []
		for side in [-1.0, 1.0]:
			var hinge := Node3D.new()
			hinge.position = Vector3(side * width * 0.5, 0, -0.6)
			root.add_child(hinge)
			var leaf_w := width * 0.5
			_part(hinge, kit.box(), wood, Vector3(-side * leaf_w * 0.5, arch_h * 0.5, 0), Vector3(leaf_w - 0.05, arch_h - 0.1, 0.22))
			for yb in [0.9, arch_h * 0.5, arch_h - 0.9]:
				_part(hinge, kit.box(), iron, Vector3(-side * leaf_w * 0.5, yb, 0.13), Vector3(leaf_w - 0.2, 0.14, 0.06))
			hinges.append(hinge)
		# Inward is local -Z? Our local Z points along -dir after the yaw;
		# flip the doors so they swing into town.
		var fwd := Vector3(dir.x, 0, dir.y)
		var local_z := root.basis.z
		if local_z.dot(fwd) > 0.0:
			for hg in hinges:
				hg.rotation_degrees.y = 0
			root.scale.z = -1.0
		gate_doors.append({"id": g["id"], "center": v3(mid), "hinges": hinges, "open": 0.0, "target": 0.0})
		# Braziers either side of the gate.
		for side in [-1.0, 1.0]:
			var bp := root.to_global(Vector3(side * (width * 0.5 + pillar * 0.5), h + 1.4, 0))
			_brazier(bp)
		var lab := Label3D.new()
		lab.text = "%s Gate" % {"N": "North", "S": "South", "E": "East", "W": "West"}.get(g["id"], g["id"])
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = v3(mid, h + 4.0)
		lab.font_size = 64
		lab.pixel_size = 0.02
		lab.outline_size = 14
		lab.modulate = Color(1, 0.92, 0.75)
		lab.visibility_range_begin = 45.0
		lab.visibility_range_end = 160.0
		add_child(lab)
		labels.append(lab)


func _build_gate_models(gk: Dictionary) -> void:
	var s := float(gk.get("scale", 1.0))
	var passage := float(gk.get("passage", 2.82)) * s
	var clear := float(gk.get("clear", 5.39)) * s
	var h := float(gk.get("height", 8.0)) * s
	for g in plan.gates:
		var mid: Vector2 = g["mid"]
		var outward: Vector2 = -(g["dir"] as Vector2)
		var root := Node3D.new()
		root.name = "Gate_%s" % g["id"]
		root.position = v3(mid)
		root.rotation.y = _yaw_to(outward)
		add_child(root)
		var model: Node3D = ModelLoader.instance(str(gk["glb"]))
		if model != null:
			model.scale = Vector3.ONE * s
			root.add_child(model)
		# Our timber doors in the passage, hinged at its sides, swinging into
		# town (local -Z is inside).
		var wood := kit.mat("wood", 0.85)
		var iron := kit.mat("iron", 0.6)
		var hinges: Array = []
		var leaf_w := passage * 0.5
		var door_h := clear * 0.92
		for side in [-1.0, 1.0]:
			var hinge := Node3D.new()
			hinge.position = Vector3(side * passage * 0.5, 0, -0.4)
			root.add_child(hinge)
			_part(hinge, kit.box(), wood, Vector3(-side * leaf_w * 0.5, door_h * 0.5, 0), Vector3(leaf_w - 0.04, door_h, 0.18))
			for yb in [0.8, door_h * 0.5, door_h - 0.8]:
				_part(hinge, kit.box(), iron, Vector3(-side * leaf_w * 0.5, yb, -0.11), Vector3(leaf_w - 0.15, 0.12, 0.05))
			hinges.append(hinge)
		gate_doors.append({"id": g["id"], "center": v3(mid), "hinges": hinges, "open": 0.0, "target": 0.0, "sign": -1.0})
		for side in [-1.0, 1.0]:
			_brazier(root.to_global(Vector3(side * float(gk.get("width", 7.75)) * s * 0.36, h + 0.2, 0)))
		var lab := Label3D.new()
		lab.text = "%s Gate" % {"N": "North", "S": "South", "E": "East", "W": "West"}.get(g["id"], g["id"])
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = v3(mid, h + 4.0)
		lab.font_size = 64
		lab.pixel_size = 0.02
		lab.outline_size = 14
		lab.modulate = Color(1, 0.92, 0.75)
		lab.visibility_range_begin = 45.0
		lab.visibility_range_end = 160.0
		add_child(lab)
		labels.append(lab)


func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = size
	parent.add_child(mi)
	return mi


func _brazier(at: Vector3) -> void:
	kit.add_cyl("brazier", kit.mat("iron", 0.5), at - Vector3(0, 0.5, 0), 0.5, 0.6, 8)
	kit.add_sphere("flame", kit.mat_glow(Color(1.0, 0.55, 0.2), 4.0), at + Vector3(0, 0.35, 0), Vector3(0.6, 0.8, 0.6))
	var l := OmniLight3D.new()
	l.position = at + Vector3(0, 0.8, 0)
	l.light_color = Color(1.0, 0.62, 0.3)
	l.omni_range = 14.0
	l.light_energy = 1.0
	l.shadow_enabled = false
	add_child(l)
	fires.append(l)


func _build_tunnels() -> void:
	var tk := _kitd("tunnel")
	if not tk.is_empty():
		for t in plan.tunnels:
			var size: Vector2 = t["size"]
			var c: Vector2 = t["center"]
			var along := Vector2(1, 0) if size.x >= size.y else Vector2(0, 1)
			var nrm := along.orthogonal()
			if nrm.dot(c - plan.ring_center) < 0.0:
				nrm = -nrm
			var sx := maxf(size.x, size.y) / float(tk.get("length", 8.0))
			kit.add_model("tunnel", str(tk["glb"]), Transform3D(Basis(Vector3.UP, _yaw_to(nrm)) * Basis.from_scale(Vector3(sx, 1, 1)), v3(c, -0.6)))
		return
	var stone := kit.mat("stone", 0.95)
	var iron := kit.mat("iron", 0.5)
	for t in plan.tunnels:
		var size: Vector2 = t["size"]
		var c: Vector2 = t["center"]
		var long_x := size.x >= size.y
		var yaw := 0.0 if long_x else PI * 0.5
		var length := maxf(size.x, size.y)
		kit.add_box("tunnel_top", stone, v3(c, 5.6), Vector3(length, 5.0, 3.2) if long_x else Vector3(3.2, 5.0, length))
		var bars := int(length / 0.6)
		for i in bars:
			var off := -length * 0.5 + (i + 0.5) * length / bars
			var bp := c + (Vector2(off, 0) if long_x else Vector2(0, off))
			kit.add_box("grate", iron, v3(bp, 1.4), Vector3(0.12, 4.4, 0.12))
		kit.add_box("grate", iron, v3(c, 1.0), Vector3(length, 0.14, 0.14) if long_x else Vector3(0.14, 0.14, length))
		kit.add_box("grate", iron, v3(c, 2.4), Vector3(length, 0.14, 0.14) if long_x else Vector3(0.14, 0.14, length))
		var _unused := yaw


func _build_bridges() -> void:
	var bk := _kitd("bridge")
	if not bk.is_empty() and not plan.bridges.is_empty():
		for b in plan.bridges:
			var axis: Vector2 = b["axis"]
			var sx := (float(b["length"]) + 2.0) / float(bk.get("length", 8.0))
			var sz := clampf(float(b["width"]) / float(bk.get("width", 3.3)), 0.9, 1.6)
			# model X runs along the span: yaw so +X maps onto the axis
			var yaw := _yaw_to(axis.orthogonal())
			if Basis(Vector3.UP, yaw).x.dot(Vector3(axis.x, 0, axis.y)) < 0.0:
				yaw += PI
			kit.add_model("bridge", str(bk["glb"]), Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, 1, sz)), v3(b["center"], -0.15)))
		return
	var deck := kit.mat("stone_pale", 0.9)
	var rail := kit.mat("stone", 0.95)
	var y: float = plan.bridge_deck_y()
	for c in plan.walk_over.keys():
		var p: Vector2 = plan.cell_center(c)
		kit.add_box("deck", deck, v3(p, y - 0.25), Vector3(cm, 0.5, cm))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if plan.is_water(n):
				var e := p + Vector2(d) * cm * 0.45
				var sz := Vector3(0.35, 0.9, cm) if d.x != 0 else Vector3(cm, 0.9, 0.35)
				kit.add_box("parapet", rail, v3(e, y + 0.45), sz)
		# piers
		if (c.x + c.y) % 3 == 0:
			kit.add_box("pier", rail, v3(p, -0.9), Vector3(cm * 0.6, 1.8, cm * 0.6))


# ---------------------------------------------------------------- outskirts

## Woods and rocks round the walls (data: city "outskirts"), in clumps from a
## seeded noise, off the roads, the river and the ring's apron.
func _build_outskirts() -> void:
	var o: Dictionary = plan.city.get("outskirts", {})
	if o.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", 7))
	var noise := FastNoiseLite.new()
	noise.seed = int(o.get("seed", 7))
	noise.frequency = float(o.get("clump", 0.025))
	var apron := float(o.get("apron_m", 26.0))
	var keep := float(o.get("density", 0.45))
	var ring_r := 0.0
	for p in plan.ring:
		ring_r = maxf(ring_r, (p as Vector2).distance_to(plan.ring_center))
	var size: Vector2 = plan.size_m()
	var extra := float(o.get("beyond_m", 220.0))
	var leaf_cols := [kit.color("leaf_oak"), kit.color("leaf_elm"), kit.color("leaf_cypress")]
	var n := 0
	var step := float(o.get("step_m", 5.0))
	var x := -extra
	while x < size.x + extra:
		var z := -extra
		while z < size.y + extra:
			var p := Vector2(x + rng.randf_range(-2.0, 2.0), z + rng.randf_range(-2.0, 2.0))
			z += step
			if p.distance_to(plan.ring_center) < ring_r + apron:
				continue
			var v := noise.get_noise_2d(p.x, p.y)
			if v < 1.0 - keep * 2.0:
				continue
			var c := plan.world_to_cell(p)
			var clear := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var ch: String = plan.terrain_char(c + Vector2i(dx, dy))
					if ch == "d" or ch == "w" or ch == "c":
						clear = false
			if not clear:
				continue
			var h := rng.randf_range(7.0, 13.0)
			var kind := rng.randi() % 3
			var tint := (leaf_cols[kind] as Color).darkened(rng.randf() * 0.25)
			kit.add_cyl("wood_trunk", kit.mat("bark", 0.95), v3(p), 0.3, h * 0.5, 6)
			if kind == 2:
				kit.add_cone("wood_conifer", kit.mat_vc(0.95), v3(p, h * 0.15), rng.randf_range(1.8, 2.6), h, 8, tint)
			else:
				var r := rng.randf_range(2.6, 4.2)
				kit.add_sphere("wood_crown", kit.mat_vc(0.95), v3(p, h * 0.62), Vector3(r * 2.0, r * 1.7, r * 2.0), tint)
			n += 1
		x += step
	# a few boulders
	for i in int(o.get("rocks", 120)):
		var p := Vector2(rng.randf_range(-extra, size.x + extra), rng.randf_range(-extra, size.y + extra))
		if p.distance_to(plan.ring_center) < ring_r + apron:
			continue
		var s := rng.randf_range(1.0, 3.2)
		kit.add_sphere("boulder", kit.mat("stone", 1.0), v3(p, s * 0.2), Vector3(s * 1.4, s * 0.8, s), Color.WHITE.darkened(rng.randf() * 0.3))
	stats["outskirt_trees"] = n


# ---------------------------------------------------------------- pieces

func _model_for(kind: String) -> Node3D:
	var path := MODEL_DIR + kind + ".glb"
	if not ModelLoader.exists(path):
		return null
	return ModelLoader.instance(path)


func _build_piece(pc: Dictionary) -> void:
	var spec: Dictionary = pc["spec"]
	var shape := str(spec.get("shape", ""))
	var model := _model_for(str(pc["kind"]))
	if model != null:
		model.position = v3(pc["center"])
		add_child(model)
		return
	var lms: Dictionary = plan.city.get("kit", {}).get("landmarks", {})
	var lk: Dictionary = lms.get(str(pc["kind"]), {})
	if not lk.is_empty() and ModelLoader.exists(str(lk.get("glb", ""))):
		_landmark_model(pc, lk)
		return
	var hk: Dictionary = plan.city.get("kit", {}).get("houses", {})
	if not hk.is_empty() and (str(pc["kind"]).begins_with("house_npc") or str(pc["kind"]).begins_with("plot_")):
		if _house_model(pc, hk):
			return
	var props: Dictionary = plan.city.get("kit", {}).get("props", {})
	var pk: Dictionary = props.get(str(pc["group"]), {})
	if not pk.is_empty() and ModelLoader.exists(str(pk.get("glb", ""))):
		var size: Vector2 = pc["size"]
		var yaw := 0.0 if size.x >= size.y else PI * 0.5
		yaw += PI * float(_hash(pc["anchor"]) > 0.5)
		kit.add_model(str(pc["group"]), str(pk["glb"]), Transform3D(Basis(Vector3.UP, yaw), v3(pc["center"])))
		return
	match shape:
		"house":
			_house(pc, spec)
		"manor":
			_house(pc, spec)
			_side_tower(pc, spec)
		"castle":
			_castle(pc, spec)
		"cathedral":
			_cathedral(pc, spec)
		"townhall":
			_townhall(pc, spec)
		"bank":
			_bank(pc, spec)
		"mill":
			_house(pc, spec)
			_mill_wheel(pc, spec)
		"tower":
			_tower(pc, spec)
		"stall":
			_stall(pc, spec)
		"lamp", "lamp_hanging":
			_lamp(pc, spec, shape == "lamp_hanging")
		"tree", "cypress":
			_tree(pc, spec, shape == "cypress")
		"bush":
			_bush(pc)
		"hedge":
			_hedge(pc, spec)
		"flowerbed", "flowers":
			_flowers(pc, shape == "flowerbed")
		"rocks", "rock":
			_rocks(pc, shape == "rock")
		"fence":
			_fence(pc, spec)
		"bench":
			kit.add_box("bench", kit.mat("stone", 0.9), v3(pc["center"], 0.45), Vector3(pc["size"].x * 0.7, 0.18, 0.6) if pc["size"].x > pc["size"].y else Vector3(0.6, 0.18, pc["size"].y * 0.7))
		"crate":
			_crate(pc["center"], 0.9, 0)
		"crate_stack":
			_crate(pc["center"], 0.9, 0)
			_crate(pc["center"] + Vector2(0.3, 0.2), 0.8, 1)
		"barrel":
			_barrel(pc["center"])
		"well":
			_well(pc)
		"fountain":
			_fountain(pc)
		"gazebo":
			_gazebo(pc, spec)
		"signpost", "notice_board":
			_sign(pc, shape == "notice_board")
		"rowboat":
			var yb := float(plan.city.get("water", {}).get("level", -0.45))
			kit.add_sphere("boat", kit.mat("wood", 0.8), v3(pc["center"], yb + 0.1), Vector3(1.4, 0.6, 3.4))
		"quay":
			kit.add_box("quay", kit.mat("wood_dark", 0.9), v3(pc["center"], 0.1), Vector3(pc["size"].x, 0.3, pc["size"].y))
		_:
			pass


## The direction a building's front (+Z) should face: its door, snapped to
## the footprint's axes; else toward the plaza.
func _front_of(pc: Dictionary) -> Vector2:
	var c: Vector2 = pc["center"]
	var front := Vector2.ZERO
	if pc.has("door"):
		front = plan.cell_center(pc["door"]) - c
	if front.length() < 0.1:
		var plaza := plan.ring_center
		for q in plan.pieces:
			if str(q["kind"]) == "fountain":
				plaza = q["center"]
		front = plaza - c
	if absf(front.x) > absf(front.y):
		return Vector2(signf(front.x), 0)
	return Vector2(0, signf(front.y))


func _house_model(pc: Dictionary, hk: Dictionary) -> bool:
	var kind := str(pc["kind"])
	var path := ""
	var tier := ""
	if kind.begins_with("plot_"):
		tier = kind.trim_prefix("plot_")
		path = str((hk.get("player", {}) as Dictionary).get(tier, ""))
	else:
		var vars: Array = hk.get("npc", [])
		if vars.is_empty():
			return false
		path = str(vars[int(_hash(pc["anchor"]) * 9973.0) % vars.size()])
	if not ModelLoader.exists(path):
		return false
	var s := float(hk.get("scale", 1.0))
	var yaw := _yaw_to(_front_of(pc))
	kit.add_model(path.get_file().get_basename(), path, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s), v3(pc["center"])))
	if tier != "":
		_plot_marker(pc, pc["spec"], tier)
	return true


## A landmark model: front (+Z) toward its door, else toward the plaza;
## uniform scale to fill the layout footprint when fit = footprint.
func _landmark_model(pc: Dictionary, lk: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var front := Vector2.ZERO
	if pc.has("door"):
		front = plan.cell_center(pc["door"]) - c
	if front.length() < 0.1:
		var plaza := plan.ring_center
		for q in plan.pieces:
			if str(q["kind"]) == "fountain":
				plaza = q["center"]
		front = plaza - c
	# snap to the footprint's axes so the building sits square on its plot
	if absf(front.x) > absf(front.y):
		front = Vector2(signf(front.x), 0)
	else:
		front = Vector2(0, signf(front.y))
	var ms: Array = lk.get("size", [10, 10])
	var foot: Vector2 = pc["size"]
	# model X runs across the front, Z along the depth
	var across := foot.y if absf(front.x) > 0.5 else foot.x
	var deep := foot.x if absf(front.x) > 0.5 else foot.y
	var s := 1.0
	if str(lk.get("fit", "model")) == "footprint":
		s = clampf(minf(across / float(ms[0]), deep / float(ms[1])), float(lk.get("min", 0.5)), float(lk.get("max", 2.0)))
	kit.add_model(str(pc["kind"]), str(lk["glb"]), Transform3D(Basis(Vector3.UP, _yaw_to(front)) * Basis.from_scale(Vector3.ONE * s), v3(c)))
	var names := {"castle": "Castle", "cathedral": "Cathedral", "townhall": "Town Hall", "bank": "Bank"}
	_label(c, 26.0 * s if str(pc["kind"]) != "castle" else 30.0, str(names.get(str(pc["kind"]), pc["kind"])))


func _footprint_box(pc: Dictionary, spec: Dictionary) -> Dictionary:
	var size: Vector2 = pc["size"]
	var inset := float(spec.get("inset", 0.3))
	var sx := maxf(1.5, size.x - inset * 2.0)
	var sz := maxf(1.5, size.y - inset * 2.0)
	# Ridge along the long side; for square plots, along the side with the door.
	var along_x := sx > sz + 0.01
	if absf(sx - sz) < 0.01 and pc.has("door"):
		var d: Vector2 = plan.cell_center(pc["door"]) - pc["center"]
		along_x = absf(d.y) >= absf(d.x)
	return {"sx": sx, "sz": sz, "along_x": along_x}


func _house(pc: Dictionary, spec: Dictionary) -> void:
	var fb := _footprint_box(pc, spec)
	var c: Vector2 = pc["center"]
	var anchor: Vector2i = pc["anchor"]
	var jit := _hash(anchor)
	var h := float(spec.get("h", 5.0)) * (0.92 + 0.16 * jit)
	var roof_h := float(spec.get("roof", 3.4)) * (0.95 + 0.1 * jit)
	var walls := str(spec.get("walls", "plaster"))
	var roof_col := str(spec.get("roof_color", "tile"))
	var sx: float = fb["sx"]
	var sz: float = fb["sz"]
	var wall_tint := Color.WHITE.darkened(jit * 0.12)
	var plot := str(spec.get("plot", ""))
	kit.add_box("walls_" + walls, kit.mat(walls, 0.95), v3(c, h * 0.5), Vector3(sx, h, sz), 0.0, wall_tint)
	# stone footing
	kit.add_box("footing", kit.mat("stone_dark", 0.95), v3(c, 0.35), Vector3(sx + 0.15, 0.7, sz + 0.15))
	var yaw := 0.0 if fb["along_x"] else PI * 0.5
	var rl: float = sx if fb["along_x"] else sz
	var rw: float = sz if fb["along_x"] else sx
	kit.add_roof("roof_" + roof_col, kit.mat(roof_col, 0.85), v3(c, h), Vector3(rl + 0.8, roof_h, rw + 1.0), yaw, Color.WHITE.darkened(_hash(anchor + Vector2i(3, 7)) * 0.15))
	if walls == "timber" or walls == "plaster_warm":
		var beam := kit.mat("beam", 0.9)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				kit.add_box("beam", beam, v3(c + Vector2(cx * sx * 0.5, cz * sz * 0.5), h * 0.5), Vector3(0.3, h, 0.3))
		for yb in [h * 0.48, h - 0.15]:
			kit.add_box("beam", beam, v3(c, yb), Vector3(sx + 0.06, 0.24, sz + 0.06))
		# diagonal braces read from afar as half-timbering
		var n := int(rl / 2.2)
		for i in n:
			var off := -rl * 0.5 + (i + 0.5) * rl / n
			for side in [-1.0, 1.0]:
				var bp: Vector2 = c + (Vector2(off, side * (rw * 0.5 + 0.02)) if fb["along_x"] else Vector2(side * (rw * 0.5 + 0.02), off))
				kit.add_box("beam", beam, v3(bp, h * 0.74), Vector3(0.2, h * 0.5, 0.2) if true else Vector3.ONE)
	# windows on the long faces, a door on the door side
	var floors := 2 if h > 5.8 else 1
	var nw := maxi(1, int(rl / 2.6))
	for f in floors:
		var wy := 1.6 + f * 2.7 if floors == 2 else h * 0.55
		for i in nw:
			var off := -rl * 0.5 + (i + 0.5) * rl / nw
			for side in [-1.0, 1.0]:
				var wp: Vector2 = c + (Vector2(off, side * (rw * 0.5 + 0.03)) if fb["along_x"] else Vector2(side * (rw * 0.5 + 0.03), off))
				var sz3 := Vector3(0.8, 1.1, 0.1) if fb["along_x"] else Vector3(0.1, 1.1, 0.8)
				kit.add_box("window", window_mat, v3(wp, wy), sz3, 0.0, Color.WHITE.darkened(0.3 * float(_hash(anchor + Vector2i(i, f)) > 0.6)))
	if pc.has("door"):
		var d: Vector2 = (plan.cell_center(pc["door"]) - c)
		var dp := c
		var dsz := Vector3(1.2, 2.2, 0.12)
		if absf(d.x) > absf(d.y):
			dp.x += signf(d.x) * (sx * 0.5 + 0.04)
			dsz = Vector3(0.12, 2.2, 1.2)
		else:
			dp.y += signf(d.y) * (sz * 0.5 + 0.04)
		kit.add_box("door", kit.mat("wood_dark", 0.8), v3(dp, 1.1), dsz)
	if bool(spec.get("chimney", false)) or jit > 0.55:
		var chp := c + (Vector2(rl * 0.3, rw * 0.15) if fb["along_x"] else Vector2(rw * 0.15, rl * 0.3))
		var top := h + roof_h * 0.75
		kit.add_box("chimney", kit.mat("stone_dark", 0.95), v3(chp, top - 0.6), Vector3(0.8, 2.4, 0.8))
		if bool(spec.get("chimney", false)) or jit > 0.8:
			_smoke(v3(chp, top + 0.7), bool(spec.get("forge", false)))
	if plot != "":
		_plot_marker(pc, spec, plot)


func _plot_marker(pc: Dictionary, spec: Dictionary, tier: String) -> void:
	var c: Vector2 = pc["center"]
	var col := kit.color("plot_" + tier, Color(0.8, 0.8, 0.8))
	var size: Vector2 = pc["size"]
	# A low tier-coloured hedge ring marks the player plot.
	var m := kit.mat("plot_" + tier, 0.8)
	for s in [-1.0, 1.0]:
		kit.add_box("plot_edge", m, v3(c + Vector2(0, s * (size.y * 0.5 + 0.4)), 0.25), Vector3(size.x + 1.2, 0.5, 0.35))
		kit.add_box("plot_edge", m, v3(c + Vector2(s * (size.x * 0.5 + 0.4), 0), 0.25), Vector3(0.35, 0.5, size.y + 1.2))
	var lab := Label3D.new()
	var tier_name: String = {"normal": "Normal", "rare": "Rare", "legendary": "Legendary"}.get(tier, tier)
	lab.text = "%s · %s plot" % [str(pc.get("plot", "")) if str(pc.get("plot", "")) != "" else "Plot", tier_name]
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = v3(c, float(spec.get("h", 5.0)) + float(spec.get("roof", 3.0)) + 1.6)
	lab.font_size = 48
	lab.pixel_size = 0.02
	lab.outline_size = 12
	lab.modulate = col.lightened(0.3)
	lab.visibility_range_begin = 18.0
	lab.visibility_range_end = 90.0
	add_child(lab)
	labels.append(lab)


func _side_tower(pc: Dictionary, spec: Dictionary) -> void:
	var size: Vector2 = pc["size"]
	var c: Vector2 = pc["center"] + Vector2(size.x * 0.42, -size.y * 0.42)
	var h := float(spec.get("h", 9.0)) + 5.0
	kit.add_cyl("manor_tower", kit.mat("stone", 0.9), v3(c), 2.0, h, 12)
	kit.add_cone("spire_roof", kit.mat("slate", 0.8), v3(c, h), 2.5, 5.0, 12)


func _smoke(at: Vector3, heavy: bool) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 14 if heavy else 8
	p.lifetime = 4.5
	p.preprocess = 4.0
	p.direction = Vector3(0.25, 1, 0.1)
	p.spread = 12.0
	p.gravity = Vector3(0.25, 0.35, 0.0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.53, 0.52, 0.22) if not heavy else Color(0.3, 0.29, 0.28, 0.3)
	mat.vertex_color_use_as_albedo = true
	sm.material = mat
	p.mesh = sm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	smokes.append(p)


func _castle(pc: Dictionary, spec: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var size: Vector2 = pc["size"]
	var h := float(spec.get("h", 16.0))
	var stone := kit.mat("stone_dark", 0.92)
	var pale := kit.mat("stone", 0.92)
	var slate := kit.mat("slate", 0.8)
	var keep := size * 0.62
	kit.add_box("castle", stone, v3(c, h * 0.5), Vector3(keep.x, h, keep.y))
	kit.add_roof("castle_roof", slate, v3(c, h), Vector3(keep.x * 0.8, 5.0, keep.y * 0.6))
	# curtain wall around the keep
	for s in [-1.0, 1.0]:
		kit.add_box("castle", pale, v3(c + Vector2(0, s * size.y * 0.46), 4.5), Vector3(size.x * 0.92, 9.0, 1.6))
		kit.add_box("castle", pale, v3(c + Vector2(s * size.x * 0.46, 0), 4.5), Vector3(1.6, 9.0, size.y * 0.92))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var tp := c + Vector2(cx * size.x * 0.46, cz * size.y * 0.46)
			kit.add_cyl("castle_tower", pale, v3(tp), 2.6, h + 4.0, 12)
			kit.add_cone("spire_roof", slate, v3(tp, h + 4.0), 3.2, 6.0, 12)
	# great tower on the keep
	kit.add_box("castle", stone, v3(c + Vector2(keep.x * 0.25, -keep.y * 0.2), h + 6.0), Vector3(5.0, 12.0, 5.0))
	kit.add_cone("spire_roof", slate, v3(c + Vector2(keep.x * 0.25, -keep.y * 0.2), h + 12.0), 3.8, 7.0, 4)
	for i in 8:
		var a := TAU * i / 8.0
		kit.add_box("merlon", kit.mat("stone_dark", 0.95), v3(c + Vector2(cos(a) * keep.x * 0.45, sin(a) * keep.y * 0.45), h + 0.6), Vector3(1.0, 1.2, 1.0))
	_label(c, h + 16.0, "Castle")


func _cathedral(pc: Dictionary, spec: Dictionary) -> void:
	var fb := _footprint_box(pc, spec)
	var c: Vector2 = pc["center"]
	var h := float(spec.get("h", 14.0))
	var pale := kit.mat("stone_pale", 0.9)
	var slate := kit.mat("slate", 0.8)
	var sx: float = fb["sx"]
	var sz: float = fb["sz"]
	var along_x := sx >= sz
	kit.add_box("cathedral", pale, v3(c, h * 0.5), Vector3(sx, h, sz))
	kit.add_roof("cathedral_roof", slate, v3(c, h), Vector3(maxf(sx, sz) + 0.6, 7.0, minf(sx, sz) + 0.8), 0.0 if along_x else PI * 0.5)
	# west front tower with spire
	var front := c + (Vector2(-sx * 0.42, 0) if along_x else Vector2(0, sz * 0.42))
	var tw := minf(sx, sz) * 0.42
	kit.add_box("cathedral", pale, v3(front, (h + 10.0) * 0.5), Vector3(tw, h + 10.0, tw))
	kit.add_cone("spire_roof", slate, v3(front, h + 10.0), tw * 0.62, float(spec.get("spire", 30.0)) - h - 10.0 + 8.0, 8)
	# buttresses
	var n := int(maxf(sx, sz) / 4.0)
	for i in n:
		var off := -maxf(sx, sz) * 0.5 + (i + 0.5) * maxf(sx, sz) / n
		for s in [-1.0, 1.0]:
			var bp: Vector2 = c + (Vector2(off, s * (sz * 0.5 + 0.6)) if along_x else Vector2(s * (sx * 0.5 + 0.6), off))
			kit.add_box("buttress", pale, v3(bp, h * 0.4), Vector3(1.0, h * 0.8, 1.2) if along_x else Vector3(1.2, h * 0.8, 1.0))
			var wp: Vector2 = c + (Vector2(off + 2.0, s * (sz * 0.5 + 0.04)) if along_x else Vector2(s * (sx * 0.5 + 0.04), off + 2.0))
			kit.add_box("window", window_mat, v3(wp, h * 0.55), Vector3(1.0, h * 0.5, 0.1) if along_x else Vector3(0.1, h * 0.5, 1.0), 0.0, Color(0.7, 0.6, 0.9))
	_label(c, h + 24.0, "Cathedral")


func _townhall(pc: Dictionary, spec: Dictionary) -> void:
	var spec2 := spec.duplicate()
	spec2["chimney"] = false
	_house(pc, spec2)
	var c: Vector2 = pc["center"]
	var size: Vector2 = pc["size"]
	var th := float(spec.get("tower", 20.0))
	var tp := c + Vector2(-size.x * 0.25, -size.y * 0.25)
	kit.add_box("townhall_tower", kit.mat("stone_pale", 0.9), v3(tp, th * 0.5), Vector3(4.2, th, 4.2))
	kit.add_cone("spire_roof", kit.mat("tile", 0.8), v3(tp, th), 3.4, 6.0, 4)
	for d in [Vector2(0, 2.15), Vector2(2.15, 0)]:
		kit.add_cyl("clock", kit.mat_glow(Color(0.95, 0.85, 0.6), 0.4), v3(tp + d, th - 2.6), 1.0, 0.1, 16)
	_label(c, th + 8.0, "Town Hall")


func _bank(pc: Dictionary, spec: Dictionary) -> void:
	var fb := _footprint_box(pc, spec)
	var c: Vector2 = pc["center"]
	var h := float(spec.get("h", 9.0))
	var pale := kit.mat("stone_pale", 0.9)
	kit.add_box("bank", pale, v3(c, h * 0.5), Vector3(fb["sx"], h, fb["sz"]))
	kit.add_roof("bank_roof", kit.mat("slate", 0.8), v3(c, h), Vector3(fb["sx"] + 0.6, float(spec.get("roof", 3.0)), fb["sz"] + 0.6))
	# columns on the front
	var front_z: float = fb["sz"] * 0.5 + 1.0
	for i in 6:
		var x := lerpf(-fb["sx"] * 0.4, fb["sx"] * 0.4, i / 5.0)
		kit.add_cyl("column", pale, v3(c + Vector2(x, front_z)), 0.45, h - 1.0, 10)
	kit.add_box("bank", pale, v3(c + Vector2(0, front_z), h - 0.5), Vector3(fb["sx"], 1.0, 2.4))
	_label(c, h + 6.0, "Bank")


func _mill_wheel(pc: Dictionary, spec: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var size: Vector2 = pc["size"]
	# The wheel sits on the side with water, if any.
	var best := Vector2(size.x * 0.5 + 0.8, 0)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var probe: Vector2 = c + d * (maxf(size.x, size.y) * 0.5 + 2.0)
		if plan.is_water(plan.world_to_cell(probe)):
			best = d * (Vector2(size.x, size.y) * 0.5 + Vector2(0.8, 0.8))
			break
	var hub := Node3D.new()
	var r := float(spec.get("wheel", 6.0)) * 0.5
	hub.position = v3(c + best, r * 0.7)
	if absf(best.y) > absf(best.x):
		hub.rotation.y = PI * 0.5
	add_child(hub)
	var wood := kit.mat("wood", 0.85)
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = r - 0.35
	tor.outer_radius = r
	tor.rings = 24
	tor.ring_segments = 6
	rim.mesh = tor
	rim.material_override = wood
	rim.rotation.z = PI * 0.5
	var spin := Node3D.new()
	hub.add_child(spin)
	spin.add_child(rim)
	for i in 8:
		var a := TAU * i / 8.0
		var paddle := MeshInstance3D.new()
		paddle.mesh = kit.box()
		paddle.material_override = wood
		paddle.scale = Vector3(1.0, 0.18, r * 2.0)
		paddle.rotation.x = a
		spin.add_child(paddle)
	spinners.append(spin)


func _tower(pc: Dictionary, spec: Dictionary) -> void:
	var tk := _kitd("tower")
	if not tk.is_empty():
		var tc: Vector2 = pc["center"]
		var ts := float(tk.get("scale", 1.0))
		var out: Vector2 = tc - plan.ring_center
		kit.add_model("tower", str(tk["glb"]), Transform3D(Basis(Vector3.UP, _yaw_to(out)) * Basis.from_scale(Vector3.ONE * ts), v3(tc)))
		var cone: Dictionary = tk.get("roof_cone", {})
		var th := float(tk.get("height", 11.0)) * ts
		if not cone.is_empty():
			kit.add_cone("tower_roof", kit.mat(str(cone.get("material", "slate")), 0.75), v3(tc, th - 0.4), float(cone.get("r", 4.4)) * ts, float(cone.get("h", 6.0)) * ts, 16)
		else:
			_brazier(v3(tc, th))
		return
	var c: Vector2 = pc["center"]
	var size: Vector2 = pc["size"]
	var r := minf(size.x, size.y) * 0.5 + 0.6
	var h := float(spec.get("h", 13.0))
	var stone := kit.mat("stone", 0.92)
	var dark := kit.mat("stone_dark", 0.95)
	kit.add_cyl("tower", stone, v3(c), r, h, 16, Color.WHITE.darkened(_hash(pc["anchor"]) * 0.1))
	kit.add_cyl("tower_band", dark, v3(c, h - 0.6), r + 0.35, 0.9, 16)
	for i in 10:
		var a := TAU * i / 10.0
		kit.add_box("merlon", dark, v3(c + Vector2(cos(a), sin(a)) * (r + 0.1), h + 0.9), Vector3(0.9, 1.4, 0.9))
	for i in 3:
		var a := TAU * (i + 0.3) / 3.0
		kit.add_box("arrowslit", window_mat, v3(c + Vector2(cos(a), sin(a)) * (r + 0.02), h * 0.55), Vector3(0.25, 1.4, 0.25))
	_brazier(v3(c, h + 0.9))


func _stall(pc: Dictionary, spec: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var size: Vector2 = pc["size"]
	var along_x := size.x >= size.y
	var w := maxf(size.x, size.y) * 0.85
	var d := 1.6
	var h := float(spec.get("h", 2.6))
	var wood := kit.mat("wood", 0.85)
	var canvas: String = ["canvas_a", "canvas_b", "canvas_c"][int(_hash(pc["anchor"]) * 3.0) % 3]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pp := c + (Vector2(sx * w * 0.46, sz * d * 0.46) if along_x else Vector2(sz * d * 0.46, sx * w * 0.46))
			kit.add_box("stall_post", wood, v3(pp, h * 0.5), Vector3(0.14, h, 0.14))
	kit.add_box("stall_table", wood, v3(c, 0.9), Vector3(w, 0.12, d * 0.8) if along_x else Vector3(d * 0.8, 0.12, w))
	kit.add_roof("stall_canvas", kit.mat(canvas, 0.95), v3(c, h), Vector3(w + 0.4, 0.7, d + 0.6), 0.0 if along_x else PI * 0.5)
	for i in 4:
		var o := -w * 0.35 + i * w * 0.23
		var gp := c + (Vector2(o, 0) if along_x else Vector2(0, o))
		kit.add_sphere("goods", kit.mat_vc(0.8), v3(gp, 1.1), Vector3(0.45, 0.3, 0.45), Color.from_hsv(_hash(pc["anchor"] + Vector2i(i, 0)), 0.55, 0.65))


func _lamp(pc: Dictionary, spec: Dictionary, hanging: bool) -> void:
	var c: Vector2 = pc["center"]
	var h := float(spec.get("h", 3.4))
	var iron := kit.mat("iron", 0.5)
	kit.add_box("lamp_pole", iron, v3(c, h * 0.5), Vector3(0.14, h, 0.14))
	var lp := c
	if hanging:
		kit.add_box("lamp_pole", iron, v3(c + Vector2(0.45, 0), h - 0.1), Vector3(0.9, 0.08, 0.08))
		lp = c + Vector2(0.85, 0)
	kit.add_box("lantern", lantern_mat, v3(lp, h - (0.45 if hanging else 0.0)), Vector3(0.36, 0.5, 0.36))
	var l := OmniLight3D.new()
	l.position = v3(lp, h - 0.4)
	l.light_color = Color(1.0, 0.68, 0.36)
	l.omni_range = 10.0
	l.omni_attenuation = 1.4
	l.light_energy = 0.0
	l.visible = false
	add_child(l)
	lamps.append(l)


func _tree(pc: Dictionary, spec: Dictionary, cypress: bool) -> void:
	var c: Vector2 = pc["center"]
	var j := _hash(pc["anchor"])
	var h := float(spec.get("h", 9.0)) * (0.85 + 0.3 * j)
	var crown := float(spec.get("crown", 4.0)) * (0.85 + 0.3 * j)
	var leaf := "leaf_" + str(spec.get("leaf", "oak"))
	var tint := Color.WHITE.darkened(j * 0.2)
	kit.add_cyl("trunk", kit.mat("bark", 0.95), v3(c), 0.28 if not cypress else 0.2, h * 0.55, 6)
	if cypress:
		kit.add_cone("cypress", kit.mat(leaf, 0.95), v3(c, h * 0.12), crown, h * 0.95, 8, tint)
		return
	kit.add_sphere("crown", kit.mat(leaf, 0.95), v3(c, h * 0.62), Vector3(crown * 2.0, crown * 1.6, crown * 2.0), tint)
	kit.add_sphere("crown", kit.mat(leaf, 0.95), v3(c + Vector2(crown * 0.45, crown * 0.2), h * 0.72), Vector3(crown * 1.3, crown * 1.1, crown * 1.3), tint.lightened(0.08))
	kit.add_sphere("crown", kit.mat(leaf, 0.95), v3(c + Vector2(-crown * 0.35, -crown * 0.3), h * 0.78), Vector3(crown * 1.2, crown, crown * 1.2), tint.darkened(0.08))


func _bush(pc: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var kind := str(pc["kind"])
	var col := kit.color("leaf_elm")
	if kind.ends_with("pink"):
		col = Color(0.62, 0.38, 0.45)
	elif kind.ends_with("yellow"):
		col = Color(0.58, 0.52, 0.2)
	kit.add_sphere("bush", kit.mat_vc(0.95), v3(c, 0.5), Vector3(1.6, 1.1, 1.6), col.darkened(_hash(pc["anchor"]) * 0.2))


func _hedge(pc: Dictionary, spec: Dictionary) -> void:
	# Clipped hedges: one rounded block per footprint cell, so an L-shaped
	# corner piece reads as an L and a section as a row.
	var h := float(spec.get("h", 1.5)) * 0.6
	var m := kit.mat("leaf_oak", 0.95)
	var cells: Array = pc["cells"]
	var keep: Array = cells
	if str(pc["kind"]) == "hedge_corner" and cells.size() == 4:
		keep = cells.slice(0, 3)
	for cell in keep:
		var p: Vector2 = plan.cell_center(cell)
		var t := Color.WHITE.darkened(_hash(cell) * 0.15)
		kit.add_box("hedge", m, v3(p, h * 0.45), Vector3(cm * 0.9, h * 0.9, cm * 0.9), 0.0, t)
		kit.add_sphere("hedge_top", m, v3(p, h * 0.9), Vector3(cm * 0.95, h * 0.45, cm * 0.95), t)


func _flowers(pc: Dictionary, bed: bool) -> void:
	var c: Vector2 = pc["center"]
	var kind := str(pc["kind"])
	var base := Color(0.7, 0.25, 0.25)
	if "blue" in kind:
		base = Color(0.35, 0.35, 0.75)
	elif "tulip" in kind:
		base = Color(0.85, 0.45, 0.2)
	if bed:
		kit.add_cyl("flowerbed", kit.mat("stone", 0.9), v3(c), pc["size"].x * 0.42, 0.35, 12)
	var n := 7 if bed else 4
	for i in n:
		var o: Vector2 = Vector2(_hash(pc["anchor"] + Vector2i(i, 1)) - 0.5, _hash(pc["anchor"] + Vector2i(1, i)) - 0.5) * (pc["size"].x * 0.7)
		kit.add_sphere("flower", kit.mat_vc(0.8), v3(c + o, 0.35 if bed else 0.18), Vector3(0.45, 0.3, 0.45), base.lightened(_hash(pc["anchor"] + Vector2i(i, i)) * 0.4))


func _rocks(pc: Dictionary, large: bool) -> void:
	var c: Vector2 = pc["center"]
	var s := 1.8 if large else 0.6
	kit.add_sphere("rock", kit.mat("stone", 1.0), v3(c, s * 0.25), Vector3(s, s * 0.6, s * 0.8), Color.WHITE.darkened(_hash(pc["anchor"]) * 0.25))


func _fence(pc: Dictionary, spec: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var size: Vector2 = pc["size"]
	var along_x := size.x >= size.y
	var L := maxf(size.x, size.y)
	var wood := kit.mat("wood", 0.9)
	kit.add_box("fence_rail", wood, v3(c, 0.75), Vector3(L, 0.1, 0.08) if along_x else Vector3(0.08, 0.1, L))
	kit.add_box("fence_rail", wood, v3(c, 0.4), Vector3(L, 0.1, 0.08) if along_x else Vector3(0.08, 0.1, L))
	var n := int(L / 0.9) + 1
	for i in n:
		var o := -L * 0.5 + i * L / maxf(1, n - 1)
		kit.add_box("fence_post", wood, v3(c + (Vector2(o, 0) if along_x else Vector2(0, o)), 0.55), Vector3(0.12, 1.1, 0.12))


func _crate(p: Vector2, s: float, level: int) -> void:
	kit.add_box("crate", kit.mat("wood", 0.9), v3(p, s * 0.5 + level * s), Vector3(s, s, s), _hash(Vector2i(p)) * 0.6)


func _barrel(p: Vector2) -> void:
	kit.add_cyl("barrel", kit.mat("wood", 0.85), v3(p), 0.36, 1.0, 10)
	kit.add_cyl("barrel_band", kit.mat("iron", 0.6), v3(p, 0.2), 0.38, 0.08, 10)
	kit.add_cyl("barrel_band", kit.mat("iron", 0.6), v3(p, 0.75), 0.38, 0.08, 10)


func _well(pc: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	kit.add_cyl("well", kit.mat("stone", 0.95), v3(c), 1.3, 0.9, 14)
	kit.add_cyl("well_water", kit.mat("stone_dark", 0.4), v3(c, 0.5), 1.0, 0.42, 14)
	for s in [-1.0, 1.0]:
		kit.add_box("well_post", kit.mat("wood", 0.9), v3(c + Vector2(s * 1.1, 0), 1.5), Vector3(0.2, 2.6, 0.2))
	kit.add_roof("well_roof", kit.mat("tile", 0.85), v3(c, 2.7), Vector3(2.9, 1.0, 2.6))


func _fountain(pc: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var r := minf(pc["size"].x, pc["size"].y) * 0.5
	var pale := kit.mat("stone_pale", 0.85)
	kit.add_cyl("fountain", pale, v3(c), r, 0.7, 20)
	var w := MeshInstance3D.new()
	w.mesh = kit.cyl(20)
	w.material_override = water_mat
	w.scale = Vector3(r * 1.8, 0.1, r * 1.8)
	w.position = v3(c, 0.62)
	add_child(w)
	kit.add_cyl("fountain", pale, v3(c), 0.4, 2.0, 10)
	kit.add_cyl("fountain", pale, v3(c, 2.0), 1.0, 0.25, 14)
	kit.add_sphere("fountain", pale, v3(c, 2.4), Vector3(0.6, 0.6, 0.6))


func _gazebo(pc: Dictionary, spec: Dictionary) -> void:
	var c: Vector2 = pc["center"]
	var r := minf(pc["size"].x, pc["size"].y) * 0.45
	var h := float(spec.get("h", 4.4))
	kit.add_cyl("gazebo_floor", kit.mat("stone_pale", 0.9), v3(c), r, 0.4, 8)
	for i in 8:
		var a := TAU * i / 8.0
		kit.add_box("gazebo_post", kit.mat("plaster", 0.9), v3(c + Vector2(cos(a), sin(a)) * (r - 0.3), h * 0.4), Vector3(0.22, h * 0.8, 0.22))
	kit.add_cone("gazebo_roof", kit.mat("slate", 0.8), v3(c, h * 0.8), r + 0.5, h * 0.45, 8)


func _sign(pc: Dictionary, board: bool) -> void:
	var c: Vector2 = pc["center"]
	var wood := kit.mat("wood", 0.9)
	if board:
		for s in [-1.0, 1.0]:
			kit.add_box("sign_post", wood, v3(c + Vector2(s * 0.8, 0), 1.1), Vector3(0.14, 2.2, 0.14))
		kit.add_box("sign_board", kit.mat("wood_dark", 0.9), v3(c, 1.6), Vector3(1.9, 1.1, 0.1))
		kit.add_box("sign_paper", kit.mat("canvas_b", 0.95), v3(c + Vector2(0, 0.07), 1.6), Vector3(1.5, 0.8, 0.02))
	else:
		kit.add_box("sign_post", wood, v3(c, 1.3), Vector3(0.14, 2.6, 0.14))
		kit.add_box("sign_board", wood, v3(c, 2.2), Vector3(1.4, 0.3, 0.06))
		kit.add_box("sign_board", wood, v3(c, 1.8), Vector3(0.06, 0.3, 1.2))


func _label(c: Vector2, y: float, text: String) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = v3(c, y)
	lab.font_size = 110
	lab.pixel_size = 0.03
	lab.outline_size = 20
	lab.modulate = Color(1, 0.93, 0.78)
	lab.visibility_range_end = 220.0
	add_child(lab)
	labels.append(lab)


## Doors near `pos` (Vector3) open, others close.
func update_gates(pos: Vector3, radius := 14.0) -> void:
	for g in gate_doors:
		var d: float = Vector2(pos.x - g["center"].x, pos.z - g["center"].z).length()
		g["target"] = 1.0 if d < radius else 0.0
