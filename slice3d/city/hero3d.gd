extends Node3D

## The player's hero in the 3D city: click-to-walk along the nav grid's
## smoothed route, gliding round corners (no stop-and-go), turning smoothly
## toward travel, with walk / idle animation from the rigged model, or a
## simple procedural bob on the placeholder body until the model is there.

const ModelLoader := preload("res://slice3d/city/model_loader.gd")
const Retarget := preload("res://slice3d/city/humanoid_retarget.gd")
const CHAR_DIR := "res://art/3d/characters/"
const CLIP_MAP := "res://data/world/city3d/clip_map.json"
const CLASSES := "res://data/world/city3d/classes3d.json"
const LOOPING := ["idle", "walk", "run", "sit"]

signal arrived

var plan
var nav
var speed := 4.2
var run_speed := 6.6
var running := false
var path: Array = []           ## Vector2 world points still to visit
var heading := 0.0
var moving := false
var model: Node3D
var anim: AnimationPlayer
var _bob_t := 0.0
var _body: Node3D
var _anim_names := {}
var class_id := "bastion"
var character: Dictionary = {}
var _weapons := {}        ## weapon id -> BoneAttachment3D
var _holster := {}        ## rig_json weapons.holster
var _skel_path := ""
var _oneshot := false


func setup(p, n) -> void:
	plan = p
	nav = n
	_build_body()


## The 3D character a class uses (data: classes3d.json): the first entry
## whose model file exists. An entry is a name (our Meshy folder layout) or a
## dict {name, glb, rig_json, weapons} for a model with its clips inside.
static func character_for(cls: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(CLASSES)) if FileAccess.file_exists(CLASSES) else {}
	var models: Array = ((doc as Dictionary).get("classes", {}) as Dictionary).get(cls, {}).get("models", ["hero_male"])
	for m in models:
		var e: Dictionary = m if m is Dictionary else {"name": str(m)}
		if not e.has("glb"):
			e["glb"] = CHAR_DIR + "%s/%s_rigged.glb" % [e["name"], e["name"]]
		if FileAccess.file_exists(str(e["glb"])):
			return e
	return {}


## Switch class: swaps the model when that class has its own.
func set_class(cls: String) -> void:
	class_id = cls
	var ch := character_for(cls)
	if str(ch.get("name", "")) == str(character.get("name", "")) and model != null:
		return
	character = ch
	if model != null:
		model.queue_free()
		model = null
		anim = null
	if _body != null:
		_body.queue_free()
		_body = null
	_anim_names.clear()
	_weapons.clear()
	_build_body()


func _build_body() -> void:
	if character.is_empty():
		character = character_for(class_id)
	model = ModelLoader.instance(str(character["glb"])) if not character.is_empty() else null
	if model != null:
		add_child(model)
		anim = ModelLoader.find_player(model)
		var sk := Retarget.find_skeleton(model)
		if sk != null:
			Retarget.retarget_skeleton(sk)
			if anim != null:
				_skel_path = str(anim.get_node(anim.root_node).get_path_to(sk))
		_attach_anims()
		_attach_weapons()
		_play("idle")
		return
	# Placeholder: a cloaked figure from primitives (1.8 m).
	_body = Node3D.new()
	add_child(_body)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.27, 0.33, 0.2)
	cloth.roughness = 0.95
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.36, 0.25, 0.16)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.56, 0.45)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.56, 0.58)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var cap := CapsuleMesh.new()
	cap.radius = 0.27
	cap.height = 1.45
	var b := MeshInstance3D.new()
	b.mesh = cap
	b.material_override = cloth
	b.position.y = 0.78
	_body.add_child(b)
	var vest := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.5, 0.55, 0.32)
	vest.mesh = vb
	vest.material_override = leather
	vest.position = Vector3(0, 1.12, 0.06)
	_body.add_child(vest)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.13
	hs.height = 0.27
	head.mesh = hs
	head.material_override = skin
	head.position.y = 1.62
	_body.add_child(head)
	var helm := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.145
	hm.height = 0.2
	helm.mesh = hm
	helm.material_override = steel
	helm.position.y = 1.7
	_body.add_child(helm)
	var sword := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.05, 0.9, 0.08)
	sword.mesh = sb
	sword.material_override = steel
	sword.position = Vector3(0.3, 0.7, 0.05)
	sword.rotation.z = 0.25
	_body.add_child(sword)


func _attach_anims() -> void:
	if anim == null:
		return
	var lib: AnimationLibrary
	if anim.has_animation_library(""):
		lib = anim.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		anim.add_animation_library("", lib)
	var cmap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIP_MAP)).get("clips", {})
	for key in cmap.keys():
		var cname := str(character.get("name", ""))
		var path := CHAR_DIR + "%s/%s_%s.glb" % [cname, cname, key]
		if not FileAccess.file_exists(path):
			continue
		var clips: Dictionary = ModelLoader.animations(path)
		for clip_name in clips.keys():
			var a: Animation = (clips[clip_name] as Animation).duplicate(true)
			Retarget.retarget_animation(a, true, _skel_path)
			a.loop_mode = Animation.LOOP_LINEAR if key in LOOPING else Animation.LOOP_NONE
			if not lib.has_animation(key):
				lib.add_animation(key, a)
			_anim_names[key] = key
			break
	# Clips already inside the model under the standard names.
	for a in lib.get_animation_list():
		if str(a) in cmap.keys() and not _anim_names.has(str(a)):
			_anim_names[str(a)] = str(a)
			var clip := lib.get_animation(a)
			clip.loop_mode = Animation.LOOP_LINEAR if str(a) in LOOPING else Animation.LOOP_NONE
	for a in lib.get_animation_list():
		var low := str(a).to_lower()
		for key in ["walk", "run", "idle"]:
			if not _anim_names.has(key) and key in low:
				_anim_names[key] = str(a)


## Play a one-shot clip (attack, cast, victory...) then return to idle/walk.
func play_once(key: String) -> bool:
	if anim == null or not _anim_names.has(key):
		return false
	anim.play(str(_anim_names[key]), 0.15)
	_weapons_for_clip(key)
	_oneshot = true
	return true


func clip_names() -> Array:
	return _anim_names.keys()


## Weapons from the rig JSON (weapons.attach: bone, position_m,
## rotation_quat_xyzw), on BoneAttachment3D nodes; weapons.holster moves them
## (e.g. onto UpperChest) for the clips it lists.
func _attach_weapons() -> void:
	var files: Dictionary = character.get("weapons", {})
	var rj := str(character.get("rig_json", ""))
	if files.is_empty() or rj == "" or not FileAccess.file_exists(rj):
		return
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rj))
	var w: Dictionary = doc.get("weapons", {})
	_holster = w.get("holster", {})
	var sk := Retarget.find_skeleton(model)
	if sk == null:
		return
	for wid in (w.get("attach", {}) as Dictionary).keys():
		if not files.has(wid):
			continue
		var mesh := ModelLoader.instance(str(files[wid]))
		if mesh == null:
			continue
		var ba := BoneAttachment3D.new()
		sk.add_child(ba)
		ba.add_child(mesh)
		_weapons[wid] = {"node": ba, "mesh": mesh, "hand": w["attach"][wid]}
		_mount(wid, w["attach"][wid])


func _mount(wid: String, spec: Dictionary) -> void:
	var e: Dictionary = _weapons[wid]
	var ba: BoneAttachment3D = e["node"]
	ba.bone_name = str(spec.get("bone", "RightHand"))
	var q: Array = spec.get("rotation_quat_xyzw", [0, 0, 0, 1])
	var pos: Array = spec.get("position_m", [0, 0, 0])
	# Offsets are in the joint's space with the joint scale removed.
	var sk: Skeleton3D = ba.get_parent()
	var bone_scale := sk.get_bone_global_pose(sk.find_bone(ba.bone_name)).basis.get_scale() * sk.global_basis.get_scale() if sk.find_bone(ba.bone_name) >= 0 else Vector3.ONE
	var inv := Vector3(1.0 / maxf(bone_scale.x, 1e-6), 1.0 / maxf(bone_scale.y, 1e-6), 1.0 / maxf(bone_scale.z, 1e-6))
	(e["mesh"] as Node3D).transform = Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])).scaled(inv), Vector3(pos[0], pos[1], pos[2]) * inv)


## Holster or draw for a clip, as the rig JSON says.
func _weapons_for_clip(key: String) -> void:
	if _weapons.is_empty():
		return
	var holster := key in (_holster.get("use_for_clips", []) as Array)
	for wid in _weapons.keys():
		var spec: Dictionary = (_holster.get("attach", {}) as Dictionary).get(wid, {}) if holster else _weapons[wid]["hand"]
		if not spec.is_empty():
			_mount(wid, spec)


func _play(key: String) -> void:
	if _oneshot and anim != null and anim.is_playing():
		return
	_oneshot = false
	if anim == null:
		return
	var n := str(_anim_names.get(key, _anim_names.get("walk", "")))
	if n != "" and anim.current_animation != n:
		anim.play(n, 0.25)
		_weapons_for_clip(key)


func ground_pos() -> Vector2:
	return Vector2(position.x, position.z)


func place(p: Vector2, face: Vector2 = Vector2(0, -1)) -> void:
	position = Vector3(p.x, plan.ground_y(p), p.y)
	heading = atan2(face.x, face.y)
	rotation.y = heading
	path.clear()
	moving = false


## Walk to a world point. Returns false when there is no route.
func walk_to(target: Vector2) -> bool:
	var route: Array = nav.world_path(ground_pos(), target)
	if route.size() < 2:
		return false
	route.remove_at(0)
	path = route
	moving = true
	return true


func _process(delta: float) -> void:
	if moving and not path.is_empty():
		var sp := run_speed if running else speed
		var left := sp * delta
		while left > 0.0 and not path.is_empty():
			var tgt: Vector2 = path[0]
			var here := ground_pos()
			var d := here.distance_to(tgt)
			# Glide: start the next leg a little before the corner.
			if d <= left or (path.size() > 1 and d < 0.35):
				var step: float = minf(d, left)
				var np := here.move_toward(tgt, step)
				position.x = np.x
				position.z = np.y
				left -= step
				path.remove_at(0)
			else:
				var np := here.move_toward(tgt, left)
				position.x = np.x
				position.z = np.y
				left = 0.0
			if not path.is_empty():
				var dir: Vector2 = (path[0] as Vector2) - ground_pos()
				if dir.length() > 0.01:
					heading = atan2(dir.x, dir.y)
		position.y = lerpf(position.y, plan.ground_y(ground_pos()), minf(1.0, delta * 10.0))
		rotation.y = lerp_angle(rotation.y, heading, minf(1.0, delta * 9.0))
		_play("run" if running and _anim_names.has("run") else "walk")
		if path.is_empty():
			moving = false
			arrived.emit()
	else:
		_play("idle")
	if _body != null:
		_bob_t += delta * (9.0 if moving else 1.6)
		_body.position.y = (absf(sin(_bob_t)) * 0.06) if moving else sin(_bob_t) * 0.01
		_body.rotation.z = sin(_bob_t) * (0.04 if moving else 0.0)
