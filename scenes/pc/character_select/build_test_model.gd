extends SceneTree

## Builds the capsule placeholder GLB used by both genders of class "test".
## Run: godot --headless --path . -s res://scenes/pc/character_select/build_test_model.gd
##
## Brief: <= 15k triangles, <= 60 bones, origin at the feet, facing +Z,
## idle 4s loop, select 2s one-shot. Mask: R skin, G hair, B eyes.
## Cloth, leather, metal, and gear stay unmasked. dye_mask.png is white
## only on the gear UV rect and is not applied by the stage.

const OUT_DIR := "res://art/pc/characters_3d/test"
const TEX_SIZE := 512

const UV_SKIN := Rect2(0.02, 0.02, 0.28, 0.44)
const UV_HAIR := Rect2(0.36, 0.02, 0.28, 0.44)
const UV_EYES := Rect2(0.70, 0.02, 0.26, 0.44)
const UV_CLOTH := Rect2(0.02, 0.52, 0.30, 0.44)
const UV_LEATHER := Rect2(0.36, 0.52, 0.26, 0.44)
const UV_METAL := Rect2(0.66, 0.52, 0.12, 0.20)
const UV_MOUTH := Rect2(0.66, 0.76, 0.12, 0.16)
const UV_GEAR := Rect2(0.82, 0.52, 0.14, 0.44)

var _parts: Array = []
var _holders := {}


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	var glb_path := OUT_DIR.path_join("placeholder.glb")
	if "--check" in OS.get_cmdline_user_args():
		_check(glb_path)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_paint_textures()
	var hero := _make_hero()
	# Stay off the tree so Skeleton3D does not spawn a physical-bone simulator.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(hero, state)
	if err != OK:
		push_error("append_from_scene failed: %s" % err)
		quit(1)
		return
	err = doc.write_to_filesystem(state, glb_path)
	hero.queue_free()
	if err != OK:
		push_error("write glb failed: %s" % err)
		quit(1)
		return
	print("WROTE ", glb_path)
	quit(0)


func _check(glb_path: String) -> void:
	var packed := load(glb_path) as PackedScene
	if packed == null:
		push_error("reload failed")
		quit(1)
		return
	var inst := packed.instantiate()
	root.add_child(inst)
	var report := _validate(inst)
	inst.queue_free()
	if report != "":
		push_error(report)
		quit(1)
		return
	print("PLACEHOLDER OK")
	quit(0)


func _make_hero() -> Node3D:
	var hero := Node3D.new()
	hero.name = "Hero"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	hero.add_child(skel)
	var bones := {
		"root": [-1, Vector3(0, 0, 0)],
		"hips": ["root", Vector3(0, 0.92, 0)],
		"spine": ["hips", Vector3(0, 0.16, 0)],
		"chest": ["spine", Vector3(0, 0.22, 0)],
		"head": ["chest", Vector3(0, 0.32, 0)],
		"arm_l": ["chest", Vector3(-0.24, 0.10, 0)],
		"arm_r": ["chest", Vector3(0.24, 0.10, 0)],
		"leg_l": ["hips", Vector3(-0.09, -0.02, 0)],
		"leg_r": ["hips", Vector3(0.09, -0.02, 0)],
		"weapon": ["arm_r", Vector3(0.18, -0.52, 0.18)],
	}
	var order := ["root", "hips", "spine", "chest", "head", "arm_l", "arm_r", "leg_l", "leg_r", "weapon"]
	var index := {}
	for bone_name in order:
		var spec: Array = bones[bone_name]
		var idx := skel.add_bone(bone_name)
		index[bone_name] = idx
		if str(spec[0]) != "-1":
			skel.set_bone_parent(idx, index[spec[0]])
		skel.set_bone_rest(idx, Transform3D(Basis.IDENTITY, spec[1]))
	skel.reset_bone_poses()
	var skin := Skin.new()
	for i in skel.get_bone_count():
		skin.add_named_bind(skel.get_bone_name(i), skel.get_bone_global_rest(i).affine_inverse())

	for n in 4:
		var holder := Node3D.new()
		holder.name = "face_%d" % n
		skel.add_child(holder)
		_holders[holder.name] = holder

	_body(index)
	_faces(index)
	_cloth(index)
	_gear(index)

	for info in _parts:
		var mesh: ArrayMesh = (info["st"] as SurfaceTool).commit()
		var mi := MeshInstance3D.new()
		mi.name = str(info["name"])
		mi.mesh = mesh
		mi.skin = skin
		mi.visible = info["visible"]
		var parent_name := str(info["parent"])
		var parent: Node = skel
		if parent_name != "":
			parent = _holders[parent_name]
		parent.add_child(mi)
		mi.skeleton = mi.get_path_to(skel)

	var front := Marker3D.new()
	front.name = "front"
	front.position = Vector3(0, 1.55, 0.42)
	hero.add_child(front)

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	library.add_animation("idle", _anim_idle())
	library.add_animation("select", _anim_select())
	player.add_animation_library("", library)
	hero.add_child(player)
	return hero


func _strip_simulators(node: Node) -> void:
	for child in node.get_children():
		_strip_simulators(child)
	var doomed: Array = []
	for child in node.get_children():
		if str(child.name).begins_with("_PhysicalBone"):
			doomed.append(child)
	for child in doomed:
		node.remove_child(child)
		child.free()


func _part(part_name: String, visible: bool = true, parent_name: String = "") -> SurfaceTool:
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_parts.append({"name": part_name, "st": st, "visible": visible, "parent": parent_name})
	return st


func _body(index: Dictionary) -> void:
	var skin_m := _part("base_body")
	var head: int = index["head"]
	_vcap(skin_m, 0.0, 0.0, 1.50, 1.84, 0.115, head, UV_SKIN)
	_vcap(skin_m, 0.0, 0.02, 1.40, 1.54, 0.055, head, UV_SKIN)
	_vcap(skin_m, -0.40, 0.10, 0.78, 0.90, 0.045, index["arm_l"], UV_SKIN)
	_vcap(skin_m, 0.40, 0.10, 0.78, 0.90, 0.045, index["arm_r"], UV_SKIN)
	var hair := _part("base_head")
	_vcap(hair, 0.0, -0.03, 1.62, 1.90, 0.125, head, UV_HAIR)


func _faces(index: Dictionary) -> void:
	var head: int = index["head"]
	# Four faces (inside 3–5). Eyes sit on +Z so the body faces the camera.
	var layouts := [
		{"eye_x": 0.045, "eye_y": 1.68, "eye_z": 0.10, "brow": 0.0},
		{"eye_x": 0.028, "eye_y": 1.69, "eye_z": 0.105, "brow": 0.02},
		{"eye_x": 0.062, "eye_y": 1.71, "eye_z": 0.09, "brow": 0.045},
		{"eye_x": 0.050, "eye_y": 1.64, "eye_z": 0.11, "brow": -0.01},
	]
	for n in layouts.size():
		var lay: Dictionary = layouts[n]
		var parent := "face_%d" % n
		var eyes := _part("face_%d_eyes" % n, true, parent)
		var ex := float(lay["eye_x"])
		var ey := float(lay["eye_y"])
		var ez := float(lay["eye_z"])
		_sphere(eyes, Vector3(-ex, ey, ez), 0.028, head, UV_EYES)
		_sphere(eyes, Vector3(ex, ey, ez), 0.028, head, UV_EYES)
		var nose := _part("face_%d_nose" % n, true, parent)
		_vcap(nose, 0.0, ez + 0.02, ey - 0.06, ey - 0.01, 0.02, head, UV_SKIN)
		var mouth := _part("face_%d_mouth" % n, true, parent)
		_vcap(mouth, 0.0, ez, ey - 0.10, ey - 0.075, 0.018, head, UV_MOUTH)
		if absf(float(lay["brow"])) > 0.001:
			var brow := _part("face_%d_brow" % n, true, parent)
			_along(brow, Vector3(-0.07, ey + 0.04 + float(lay["brow"]), ez), Vector3(0.07, ey + 0.04 + float(lay["brow"]), ez), 0.012, head, UV_SKIN)


func _cloth(index: Dictionary) -> void:
	var chest := _part("base_chest")
	var chest_b: int = index["chest"]
	_vcap(chest, 0.0, 0.0, 1.00, 1.46, 0.155, chest_b, UV_CLOTH)
	_vcap(chest, 0.0, 0.02, 0.92, 1.05, 0.175, chest_b, UV_CLOTH)
	_along(chest, Vector3(-0.22, 1.40, 0.0), Vector3(-0.36, 1.05, 0.05), 0.05, index["arm_l"], UV_CLOTH)
	_along(chest, Vector3(0.22, 1.40, 0.0), Vector3(0.36, 1.05, 0.05), 0.05, index["arm_r"], UV_CLOTH)
	_along(chest, Vector3(-0.36, 1.05, 0.05), Vector3(-0.40, 0.86, 0.08), 0.042, index["arm_l"], UV_CLOTH)
	_along(chest, Vector3(0.36, 1.05, 0.05), Vector3(0.40, 0.86, 0.08), 0.042, index["arm_r"], UV_CLOTH)
	_vcap(chest, -0.38, 0.08, 0.84, 0.92, 0.03, index["arm_l"], UV_LEATHER)
	_vcap(chest, 0.38, 0.08, 0.84, 0.92, 0.03, index["arm_r"], UV_LEATHER)
	var legs := _part("base_legs")
	_vcap(legs, -0.09, 0.0, 0.48, 0.98, 0.085, index["leg_l"], UV_CLOTH)
	_vcap(legs, 0.09, 0.0, 0.48, 0.98, 0.085, index["leg_r"], UV_CLOTH)
	var boots := _part("base_boots")
	_vcap(boots, -0.09, 0.02, 0.0, 0.50, 0.07, index["leg_l"], UV_LEATHER)
	_vcap(boots, 0.09, 0.02, 0.0, 0.50, 0.07, index["leg_r"], UV_LEATHER)
	var weapon := _part("base_weapon")
	_along(weapon, Vector3(0.42, 0.82, 0.16), Vector3(0.55, 1.20, 0.42), 0.035, index["weapon"], UV_METAL)


func _gear(index: Dictionary) -> void:
	var helm := _part("gear_head", false)
	_vcap(helm, 0.0, -0.04, 1.60, 1.93, 0.14, index["head"], UV_GEAR)
	var chest := _part("gear_chest", false)
	_vcap(chest, 0.0, 0.03, 0.96, 1.50, 0.185, index["chest"], UV_GEAR)
	_along(chest, Vector3(-0.24, 1.42, 0.02), Vector3(-0.42, 0.84, 0.08), 0.06, index["arm_l"], UV_GEAR)
	_along(chest, Vector3(0.24, 1.42, 0.02), Vector3(0.42, 0.84, 0.08), 0.06, index["arm_r"], UV_GEAR)
	var legs := _part("gear_legs", false)
	_vcap(legs, -0.09, 0.02, 0.46, 1.02, 0.10, index["leg_l"], UV_GEAR)
	_vcap(legs, 0.09, 0.02, 0.46, 1.02, 0.10, index["leg_r"], UV_GEAR)
	var boots := _part("gear_boots", false)
	_vcap(boots, -0.09, 0.04, 0.0, 0.56, 0.085, index["leg_l"], UV_GEAR)
	_vcap(boots, 0.09, 0.04, 0.0, 0.56, 0.085, index["leg_r"], UV_GEAR)
	var weapon := _part("gear_weapon", false)
	_along(weapon, Vector3(0.40, 0.78, 0.18), Vector3(0.62, 1.35, 0.55), 0.045, index["weapon"], UV_GEAR)


func _vcap(st: SurfaceTool, x: float, z: float, bottom: float, top: float, radius: float, bone: int, uv: Rect2) -> void:
	var p0 := Vector3(x, bottom + radius, z)
	var p1 := Vector3(x, top - radius, z)
	if p1.y < p0.y:
		var mid := (bottom + top) * 0.5
		p0.y = mid
		p1.y = mid
	_add_capsule(st, p0, p1, radius, bone, uv)


func _along(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, bone: int, uv: Rect2) -> void:
	var dir := (b - a).normalized()
	_add_capsule(st, a + dir * radius, b - dir * radius, radius, bone, uv)


func _sphere(st: SurfaceTool, center: Vector3, radius: float, bone: int, uv: Rect2) -> void:
	_add_capsule(st, center, center + Vector3(0, 0.0001, 0), radius, bone, uv)


func _add_capsule(st: SurfaceTool, p0: Vector3, p1: Vector3, radius: float, bone: int, uv_rect: Rect2) -> void:
	var axis := p1 - p0
	var length := axis.length()
	if length < 0.00005:
		length = 0.00005
		axis = Vector3(0, length, 0)
	var dir := axis / length
	var hint := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.92 else Vector3.UP
	var side := dir.cross(hint).normalized()
	var up := side.cross(dir).normalized()
	var sides := 8
	var rings := 2
	var row_count := rings * 2 + 2
	var rows: Array = []
	for r in row_count:
		var t := float(r) / float(row_count - 1)
		var along := -radius + t * (length + radius * 2.0)
		var radial := radius
		var normal_from := p0
		if along < 0.0:
			radial = sqrt(maxf(radius * radius - along * along, 0.0))
			normal_from = p0
		elif along > length:
			var dy := along - length
			radial = sqrt(maxf(radius * radius - dy * dy, 0.0))
			normal_from = p1
		else:
			radial = radius
			normal_from = p0 + dir * along
		var ring: Array = []
		for c in sides + 1:
			var ang := TAU * float(c) / float(sides)
			var offset := (side * cos(ang) + up * sin(ang)) * radial
			var point := p0 + dir * along + offset
			var normal := point - normal_from
			if normal.length_squared() < 0.000001:
				normal = dir if t > 0.5 else -dir
			else:
				normal = normal.normalized()
			var uv := Vector2(
				uv_rect.position.x + (float(c) / float(sides)) * uv_rect.size.x,
				uv_rect.position.y + t * uv_rect.size.y
			)
			ring.append([point, normal, uv])
		rows.append(ring)
	var bones := PackedInt32Array([bone, 0, 0, 0])
	var weights := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	for r in row_count - 1:
		for c in sides:
			var a: Array = rows[r][c]
			var b: Array = rows[r][c + 1]
			var d: Array = rows[r + 1][c]
			var e: Array = rows[r + 1][c + 1]
			_tri(st, a, e, d, bones, weights)
			_tri(st, a, b, e, bones, weights)


func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	for v in [a, b, c]:
		st.set_normal(v[1])
		st.set_uv(v[2])
		st.set_bones(bones)
		st.set_weights(weights)
		st.add_vertex(v[0])


func _anim_idle() -> Animation:
	var anim := Animation.new()
	anim.length = 4.0
	anim.loop_mode = Animation.LOOP_LINEAR
	_rot_track(anim, "spine", [
		[0.0, Vector3.ZERO],
		[1.0, Vector3(deg_to_rad(2.0), 0, 0)],
		[2.0, Vector3.ZERO],
		[3.0, Vector3(deg_to_rad(-1.5), 0, 0)],
		[4.0, Vector3.ZERO],
	])
	_rot_track(anim, "head", [
		[0.0, Vector3.ZERO],
		[2.0, Vector3(deg_to_rad(3.0), deg_to_rad(4.0), 0)],
		[4.0, Vector3.ZERO],
	])
	_rot_track(anim, "arm_l", [
		[0.0, Vector3.ZERO],
		[1.0, Vector3(0, 0, deg_to_rad(6.0))],
		[3.0, Vector3(0, 0, deg_to_rad(-4.0))],
		[4.0, Vector3.ZERO],
	])
	_rot_track(anim, "arm_r", [
		[0.0, Vector3.ZERO],
		[1.0, Vector3(0, 0, deg_to_rad(-6.0))],
		[3.0, Vector3(0, 0, deg_to_rad(4.0))],
		[4.0, Vector3.ZERO],
	])
	var pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos, NodePath("Skeleton3D:hips"))
	anim.track_set_interpolation_type(pos, Animation.INTERPOLATION_LINEAR)
	anim.position_track_insert_key(pos, 0.0, Vector3(0, 0.92, 0))
	anim.position_track_insert_key(pos, 1.0, Vector3(0, 0.935, 0))
	anim.position_track_insert_key(pos, 2.0, Vector3(0, 0.92, 0))
	anim.position_track_insert_key(pos, 3.0, Vector3(0, 0.908, 0))
	anim.position_track_insert_key(pos, 4.0, Vector3(0, 0.92, 0))
	return anim


func _anim_select() -> Animation:
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_NONE
	var lift := Vector3(deg_to_rad(-70.0), 0, 0)
	_rot_track(anim, "arm_l", [[0.0, Vector3.ZERO], [0.45, lift], [1.15, lift], [2.0, Vector3.ZERO]])
	_rot_track(anim, "arm_r", [[0.0, Vector3.ZERO], [0.45, lift], [1.15, lift], [2.0, Vector3.ZERO]])
	_rot_track(anim, "weapon", [
		[0.0, Vector3.ZERO],
		[0.45, Vector3(0, deg_to_rad(30.0), 0)],
		[1.15, Vector3(0, deg_to_rad(30.0), 0)],
		[2.0, Vector3.ZERO],
	])
	_rot_track(anim, "spine", [
		[0.0, Vector3.ZERO],
		[0.45, Vector3(deg_to_rad(-8.0), deg_to_rad(10.0), 0)],
		[1.15, Vector3(deg_to_rad(4.0), 0, 0)],
		[2.0, Vector3.ZERO],
	])
	return anim


func _rot_track(anim: Animation, bone_name: String, keys: Array) -> void:
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, NodePath("Skeleton3D:%s" % bone_name))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		var euler: Vector3 = key[1]
		anim.rotation_track_insert_key(track, key[0], Quaternion.from_euler(euler))


func _paint_textures() -> void:
	var albedo := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var mask := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var dye := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	albedo.fill(Color(0.5, 0.5, 0.5))
	mask.fill(Color(0, 0, 0))
	dye.fill(Color(0, 0, 0))
	_shade(albedo, UV_SKIN, Color(0.72, 0.72, 0.72), true)
	_shade(albedo, UV_HAIR, Color(0.55, 0.55, 0.55), true)
	_shade(albedo, UV_EYES, Color(0.85, 0.85, 0.85), true)
	_shade(albedo, UV_CLOTH, Color(0.76, 0.67, 0.52), true)
	_shade(albedo, UV_LEATHER, Color(0.42, 0.28, 0.16), true)
	_shade(albedo, UV_METAL, Color(0.62, 0.64, 0.68), true)
	_shade(albedo, UV_MOUTH, Color(0.35, 0.16, 0.16), false)
	_shade(albedo, UV_GEAR, Color(0.45, 0.48, 0.52), true)
	_flat(mask, UV_SKIN, Color(1, 0, 0))
	_flat(mask, UV_HAIR, Color(0, 1, 0))
	_flat(mask, UV_EYES, Color(0, 0, 1))
	_flat(dye, UV_GEAR, Color(1, 1, 1))
	albedo.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join("albedo.png")))
	mask.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join("mask.png")))
	dye.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join("dye_mask.png")))


func _shade(image: Image, rect: Rect2, base: Color, gradient: bool) -> void:
	var area := _px(rect)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var u := float(x - area.position.x) / maxf(float(area.size.x), 1.0)
			var v := float(y - area.position.y) / maxf(float(area.size.y), 1.0)
			var lum := 1.0
			if gradient:
				lum *= lerpf(1.25, 0.55, v)
				lum *= lerpf(0.72, 1.0, 1.0 - absf(u - 0.5) * 2.0)
			image.set_pixel(x, y, Color(base.r * lum, base.g * lum, base.b * lum))


func _flat(image: Image, rect: Rect2, color: Color) -> void:
	var area := _px(rect)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			image.set_pixel(x, y, color)


func _px(rect: Rect2) -> Rect2i:
	return Rect2i(
		int(rect.position.x * TEX_SIZE),
		int(rect.position.y * TEX_SIZE),
		maxi(int(rect.size.x * TEX_SIZE), 1),
		maxi(int(rect.size.y * TEX_SIZE), 1)
	)


func _validate(inst: Node) -> String:
	var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return "no skeleton"
	if skel.get_bone_count() > 60:
		return "too many bones: %d" % skel.get_bone_count()
	var player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation("idle") or not player.has_animation("select"):
		return "missing idle/select"
	var idle_len := player.get_animation("idle").length
	var select_len := player.get_animation("select").length
	if idle_len < 3.0 or idle_len > 5.0:
		return "idle length %s" % idle_len
	if select_len < 1.5 or select_len > 2.5:
		return "select length %s" % select_len
	var faces := 0
	for n in 8:
		if inst.find_child("face_%d" % n, true, false):
			faces += 1
	if faces < 3 or faces > 5:
		return "face count %d" % faces
	for slot in ["weapon", "head", "chest", "legs", "boots"]:
		if inst.find_child("base_" + slot, true, false) == null:
			return "missing base_" + slot
		if inst.find_child("gear_" + slot, true, false) == null:
			return "missing gear_" + slot
	var acc := {"tris": 0, "min_y": 1000.0, "max_y": -1000.0, "eye_z": -1000.0, "weighted": 0}
	_measure(inst, inst, acc)
	print("bones ", skel.get_bone_count(), " tris ", acc["tris"], " y ", acc["min_y"], "..", acc["max_y"], " eye_z ", acc["eye_z"], " faces ", faces, " weighted ", acc["weighted"])
	if int(acc["tris"]) > 15000:
		return "too many triangles: %d" % int(acc["tris"])
	if int(acc["weighted"]) <= 0:
		return "mesh has no bone weights"
	if float(acc["min_y"]) < -0.02 or float(acc["min_y"]) > 0.05:
		return "feet not at origin: %s" % str(acc["min_y"])
	if float(acc["max_y"]) < 1.75 or float(acc["max_y"]) > 1.95:
		return "height %s" % str(acc["max_y"])
	if float(acc["eye_z"]) < 0.05:
		return "not facing +Z, eye z %s" % str(acc["eye_z"])
	var front := inst.find_child("front", true, false)
	if front == null or front.position.z <= 0.0:
		return "front marker"
	return ""


func _measure(model: Node, node: Node, acc: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				acc["tris"] = int(acc["tris"]) + int(arrays[Mesh.ARRAY_VERTEX].size() / 3)
			else:
				acc["tris"] = int(acc["tris"]) + int(idx.size() / 3)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			if bones.size() > 0:
				acc["weighted"] = int(acc["weighted"]) + 1
		var xform: Transform3D = model.global_transform.affine_inverse() * mi.global_transform
		var box: AABB = xform * mi.get_aabb()
		acc["min_y"] = minf(float(acc["min_y"]), box.position.y)
		acc["max_y"] = maxf(float(acc["max_y"]), box.position.y + box.size.y)
		if str(node.name).begins_with("face_0_eyes"):
			var center := box.position + box.size * 0.5
			acc["eye_z"] = maxf(float(acc["eye_z"]), center.z)
	for child in node.get_children():
		_measure(model, child, acc)
