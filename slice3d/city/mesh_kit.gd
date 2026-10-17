extends RefCounted

## Small placeholder mesh kit for the 3D city: shared primitive meshes,
## materials by palette name, a gable roof prism, and a batcher that turns
## many placements of one mesh into a single MultiMeshInstance3D.
## Everything here is a stand-in until the real models arrive.

var palette: Dictionary = {}
var _mats: Dictionary = {}
var _meshes: Dictionary = {}
var _batches: Dictionary = {}   ## key -> {mesh, mat, xforms:[], colors:[]}
var terrain_shader: Shader
var water_shader: Shader


func _init(pal: Dictionary = {}) -> void:
	palette = pal


func color(name: String, fallback := Color(0.5, 0.5, 0.5)) -> Color:
	if palette.has(name):
		var c: Array = palette[name]
		return Color(c[0], c[1], c[2])
	return fallback


## A matte material by palette name (cached). `tint` multiplies it.
func mat(name: String, rough := 0.9, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [name, rough, tint.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color(name) * tint
	m.roughness = rough
	m.metallic = 0.0
	m.vertex_color_use_as_albedo = true
	_mats[key] = m
	return m


## Vertex-colour material for batched meshes with per-instance colour.
func mat_vc(rough := 0.9) -> StandardMaterial3D:
	var key := "vc|%.2f" % rough
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	_mats[key] = m
	return m


func mat_glow(c: Color, energy: float) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c * 0.4
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


func box() -> BoxMesh:
	if not _meshes.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_meshes["box"] = b
	return _meshes["box"]


func cyl(sides := 12) -> CylinderMesh:
	var key := "cyl%d" % sides
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = sides
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]


func cone(sides := 12) -> CylinderMesh:
	var key := "cone%d" % sides
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = sides
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]


func sphere(seg := 10) -> SphereMesh:
	var key := "sph%d" % seg
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = seg
		s.rings = maxi(4, seg / 2)
		_meshes[key] = s
	return _meshes[key]


## Unit gable roof: 1 x 1 footprint centred on the origin, ridge along X,
## base at y = 0, ridge at y = 1, with a little overhang built in by scale.
func prism() -> ArrayMesh:
	if _meshes.has("prism"):
		return _meshes["prism"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0, -0.5)
	var b := Vector3(0.5, 0, -0.5)
	var c := Vector3(0.5, 0, 0.5)
	var d := Vector3(-0.5, 0, 0.5)
	var r1 := Vector3(-0.5, 1, 0)
	var r2 := Vector3(0.5, 1, 0)
	# two slopes
	for tri in [[a, r1, r2], [a, r2, b], [d, c, r2], [d, r2, r1],
			# gable ends
			[a, d, r1], [b, r2, c],
			# underside
			[a, b, c], [a, c, d]]:
		# Godot's front faces wind clockwise; emit both windings with the
		# outward normal on the clockwise one, so no slope is ever culled.
		var n: Vector3 = ((tri[1] - tri[0]).cross(tri[2] - tri[0])).normalized()
		for v in [tri[0], tri[2], tri[1]]:
			st.set_normal(n)
			st.add_vertex(v)
		for v in tri:
			st.set_normal(-n)
			st.add_vertex(v)
	var m := st.commit()
	_meshes["prism"] = m
	return m


## Queue one placement of `mesh` with `material`; flushed into a MultiMesh.
func add(key: String, mesh: Mesh, material: Material, xf: Transform3D, col := Color.WHITE) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "mat": material, "xforms": [], "colors": []}
	_batches[key]["xforms"].append(xf)
	_batches[key]["colors"].append(col)


## Box placed by centre, size and yaw (radians).
func add_box(key: String, material: Material, center: Vector3, size: Vector3, yaw := 0.0, col := Color.WHITE) -> void:
	add(key, box(), material, _xf(center, size, yaw), col)


func add_cyl(key: String, material: Material, base: Vector3, radius: float, h: float, sides := 12, col := Color.WHITE) -> void:
	add(key, cyl(sides), material, _xf(base + Vector3(0, h * 0.5, 0), Vector3(radius * 2, h, radius * 2), 0.0), col)


func add_cone(key: String, material: Material, base: Vector3, radius: float, h: float, sides := 12, col := Color.WHITE) -> void:
	add(key, cone(sides), material, _xf(base + Vector3(0, h * 0.5, 0), Vector3(radius * 2, h, radius * 2), 0.0), col)


func add_sphere(key: String, material: Material, center: Vector3, size: Vector3, col := Color.WHITE) -> void:
	add(key, sphere(), material, _xf(center, size, 0.0), col)


func add_roof(key: String, material: Material, base: Vector3, size: Vector3, yaw := 0.0, col := Color.WHITE) -> void:
	add(key, prism(), material, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), base), col)


static func _xf(center: Vector3, size: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center)


## Turn every queued batch into MultiMeshInstance3D children of `parent`.
func flush(parent: Node3D, shadows := true) -> int:
	var n := 0
	for key in _batches.keys():
		var b: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b["mesh"]
		var xs: Array = b["xforms"]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			mm.set_instance_color(i, b["colors"][i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "MM_%s" % str(key).validate_node_name()
		mi.multimesh = mm
		mi.material_override = b["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		n += xs.size()
	_batches.clear()
	return n
