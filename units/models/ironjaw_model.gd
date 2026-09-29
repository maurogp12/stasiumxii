extends Node3D
class_name IronjawModel

## Ironjaw as a real 3D figure (Mauro 29 Sep 2026: "The only one not looking
## good is ironjaw create a 3d model"). His painted sheet only has one side
## view, so in the 3D board he is built from shaped parts instead: the in-game
## look (crimson plate armour over black, dark spiked great-helm with a barred
## visor, grey knee and shin plates, two double-bit axes held low and out),
## chibi proportions like the other champions, cel shading and an ink outline
## so he sits next to the painted art. Faces +Z, about 1.6 units tall.
## View only.

const RED := Color(0.46, 0.05, 0.05)
const RED_DARK := Color(0.26, 0.03, 0.035)
const IRON := Color(0.2, 0.2, 0.22)
const IRON_MID := Color(0.28, 0.29, 0.31)
const STEEL := Color(0.42, 0.43, 0.46)
const BLACK := Color(0.07, 0.065, 0.065)
const LEATHER := Color(0.3, 0.19, 0.12)
const SKIN := Color(0.6, 0.42, 0.32)
const WOOD := Color(0.22, 0.15, 0.1)
const INK := Color(0.04, 0.02, 0.02)
const BREATH_SEC := 2.8

var _mats: Dictionary = {}
var _body: Node3D
var _time := 0.0


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_build()


func _process(delta: float) -> void:
	_time += delta
	var b := sin(_time * TAU / BREATH_SEC)
	_body.scale = Vector3(1.0 + 0.008 * b, 1.0 + 0.012 * b, 1.0 + 0.008 * b)


func _build() -> void:
	for side: float in [-1.0, 1.0]:
		_leg(side)
		_arm(side)
		_pauldron(side)
	# Hips: black skirt of mail, leather belt with an iron buckle, crimson
	# tabard hanging front and back.
	_blob(Vector3(0, 0.6, 0), Vector3(0.23, 0.1, 0.18), BLACK)
	_ring(Vector3(0, 0.67, 0), 0.235, 0.05, LEATHER)
	_box(Vector3(0, 0.67, 0.225), Vector3(0.07, 0.07, 0.03), STEEL)
	_plate(Vector3(0, 0.5, 0.15), Vector3(0.2, 0.26, 0.03), RED, Vector3(-10, 0, 0))
	_plate(Vector3(0, 0.5, -0.15), Vector3(0.24, 0.28, 0.03), RED_DARK, Vector3(10, 0, 0))
	# Torso: black gambeson under a rounded crimson cuirass with a raised
	# centre ridge, rivets and a dark gorget.
	_blob(Vector3(0, 0.8, 0), Vector3(0.25, 0.19, 0.18), BLACK)
	_blob(Vector3(0, 0.86, 0.0), Vector3(0.27, 0.2, 0.21), RED, true)
	_blob(Vector3(0, 0.88, 0.19), Vector3(0.018, 0.12, 0.02), RED_DARK, true)
	for rx: float in [-0.12, 0.12]:
		for ry: float in [0.78, 0.9]:
			_blob(Vector3(rx, ry, 0.17), Vector3(0.016, 0.016, 0.016), STEEL, true)
	_ring(Vector3(0, 0.72, 0), 0.23, 0.04, RED_DARK)
	_blob(Vector3(0, 1.03, 0), Vector3(0.15, 0.05, 0.13), IRON, true)
	_helm()
	for side: float in [-1.0, 1.0]:
		_axe(side)


func _leg(side: float) -> void:
	var x := 0.12 * side
	# Boot, shin plate, knee cop, crimson thigh.
	_blob(Vector3(x, 0.06, 0.05), Vector3(0.09, 0.065, 0.15), BLACK)
	_cyl(Vector3(x, 0.23, 0.0), 0.085, 0.075, 0.24, IRON_MID, true)
	_plate(Vector3(x, 0.24, 0.07), Vector3(0.12, 0.2, 0.03), STEEL, Vector3(-4, 0, 0))
	_blob(Vector3(x, 0.37, 0.07), Vector3(0.07, 0.06, 0.05), STEEL, true)
	_cyl(Vector3(x, 0.47, 0.0), 0.1, 0.09, 0.2, RED, true)


func _arm(side: float) -> void:
	var sx := 0.3 * side
	# Bare upper arm, crimson vambrace, black gauntlet gripping the axe.
	_cyl(Vector3(sx, 0.82, 0.0), 0.06, 0.055, 0.16, SKIN, false, Vector3(0, 0, -12 * side))
	_cyl(Vector3(sx * 1.02, 0.68, 0.08), 0.07, 0.06, 0.16, RED, true, Vector3(55, 0, -8 * side))
	_ring(Vector3(sx * 1.02, 0.72, 0.03), 0.072, 0.025, STEEL, Vector3(55, 0, -8 * side))
	_blob(Vector3(sx * 1.0, 0.6, 0.17), Vector3(0.065, 0.06, 0.065), BLACK)


func _pauldron(side: float) -> void:
	var px := 0.3 * side
	# Three overlapping lames, the top one biggest, with a spike.
	for i in 3:
		var y := 1.0 - i * 0.06
		var s := 1.0 - i * 0.12
		var lame := _blob(Vector3(px + 0.02 * i * side, y, 0), Vector3(0.14 * s, 0.075, 0.13 * s), RED if i == 0 else RED_DARK, true)
		lame.rotation_degrees = Vector3(0, 0, -18 * side)
	_ring(Vector3(px, 0.985, 0), 0.13, 0.02, IRON_MID, Vector3(0, 0, -18 * side))
	_cone(Vector3(px * 1.18, 1.1, 0), 0.03, 0.12, STEEL, Vector3(0, 0, -35 * side))


func _helm() -> void:
	# Dark great-helm: a tall rounded bucket, a brow ridge, barred visor
	# slits, cheek rivets and a crown of spikes.
	_cyl(Vector3(0, 1.22, 0), 0.19, 0.18, 0.28, IRON, true)
	_blob(Vector3(0, 1.36, 0), Vector3(0.19, 0.13, 0.19), IRON, true)
	_ring(Vector3(0, 1.33, 0), 0.195, 0.03, IRON_MID)
	_box(Vector3(0, 1.24, 0.172), Vector3(0.26, 0.09, 0.03), BLACK)
	for i in 6:
		_box(Vector3(-0.1 + i * 0.04, 1.24, 0.185), Vector3(0.014, 0.1, 0.014), IRON_MID)
	_box(Vector3(0, 1.2, 0.19), Vector3(0.026, 0.24, 0.02), IRON_MID)
	for rx: float in [-0.14, 0.14]:
		_blob(Vector3(rx, 1.14, 0.12), Vector3(0.014, 0.014, 0.014), STEEL, true)
	for i in 7:
		var a := deg_to_rad(-90.0 + i * 30.0)
		var tall := 0.16 if i == 3 else 0.11
		_cone(Vector3(sin(a) * 0.14, 1.44, cos(a) * 0.14), 0.028, tall, STEEL, Vector3(rad_to_deg(cos(a)) * 0.35, 0, -rad_to_deg(sin(a)) * 0.35))


func _axe(side: float) -> void:
	# Haft runs out from the fist, head at the outer end; two crescent bits.
	var axe := Node3D.new()
	axe.position = Vector3(0.3 * side, 0.6, 0.18)
	axe.rotation_degrees = Vector3(0, -20 * side, -18 * side)
	_body.add_child(axe)
	_cyl(Vector3(0.12 * side, 0, 0), 0.02, 0.022, 0.5, WOOD, false, Vector3(0, 0, 90), axe)
	_blob(Vector3(-0.12 * side, 0, 0), Vector3(0.03, 0.03, 0.03), IRON_MID, true, axe)
	var head_x := 0.34 * side
	_box(Vector3(head_x, 0, 0), Vector3(0.07, 0.08, 0.05), IRON, Vector3.ZERO, axe)
	var bit := PackedVector2Array([
		Vector2(-0.03, 0.03), Vector2(0.03, 0.03), Vector2(0.06, 0.07), Vector2(0.1, 0.15),
		Vector2(0.03, 0.17), Vector2(-0.03, 0.17), Vector2(-0.1, 0.15), Vector2(-0.06, 0.07),
	])
	for up: float in [1.0, -1.0]:
		var pts := PackedVector2Array()
		for p in bit:
			pts.append(Vector2(p.x, p.y * up))
		if up < 0.0:
			pts.reverse()
		var blade := _extrude(pts, 0.025, STEEL, axe)
		blade.position = Vector3(head_x, 0, 0)
	_cone(Vector3(head_x + 0.05 * side, 0, 0), 0.018, 0.08, STEEL, Vector3(0, 0, -90 * side), axe)


# --- parts -----------------------------------------------------------------

func _mat(col: Color, shiny: bool) -> StandardMaterial3D:
	var key := "%s_%s" % [col.to_html(), shiny]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.4 if shiny else 0.85
	m.metallic = 0.3 if shiny else 0.0
	m.metallic_specular = 0.35 if shiny else 0.1
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.7
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = INK
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	ink.grow = true
	ink.grow_amount = 0.01
	m.next_pass = ink
	_mats[key] = m
	return m


func _add(mesh: Mesh, pos: Vector3, col: Color, shiny: bool, rot: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = _mat(col, shiny)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent != null else _body).add_child(mi)
	return mi


func _box(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(m, pos, col, col == STEEL or col == IRON or col == IRON_MID, rot, parent)


## A thin curved-looking plate (flattened sphere).
func _plate(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := _blob(pos, size * 0.5, col, true)
	mi.rotation_degrees = rot
	return mi


## Ellipsoid with the given radii.
func _blob(pos: Vector3, radii: Vector3, col: Color, shiny := false, parent: Node3D = null) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 20
	m.rings = 10
	var mi := _add(m, pos, col, shiny, Vector3.ZERO, parent)
	mi.scale = radii
	return mi


func _cyl(pos: Vector3, top: float, bottom: float, height: float, col: Color, shiny: bool, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 18
	m.rings = 1
	return _add(m, pos, col, shiny, rot, parent)


func _ring(pos: Vector3, r: float, h: float, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return _cyl(pos, r, r, h, col, true, rot)


func _cone(pos: Vector3, r: float, h: float, col: Color, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	return _add(m, pos, col, true, rot, parent)


## A flat shape (outline in XY, counter-clockwise) extruded along Z.
func _extrude(poly: PackedVector2Array, depth: float, col: Color, parent: Node3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(poly)
	var hz := depth * 0.5
	for face: float in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, face))
		for i in range(0, tris.size(), 3):
			var order := [tris[i], tris[i + 2], tris[i + 1]] if face > 0.0 else [tris[i], tris[i + 1], tris[i + 2]]
			for k in order:
				st.add_vertex(Vector3(poly[k].x, poly[k].y, hz * face))
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var n := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		st.set_normal(n)
		for v in [Vector3(a.x, a.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, -hz), Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(b.x, b.y, -hz)]:
			st.add_vertex(v)
	return _add(st.commit(), Vector3.ZERO, col, true, Vector3.ZERO, parent)
