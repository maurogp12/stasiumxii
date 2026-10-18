extends Node3D

## A 3D townsperson body: the art kit's skinned mesh plus its clip file
## (idle, walk, interact, sit, talk), on humanoid bone names. Plays clips by
## name; falls back to a capsule figure when the model is missing.

const ModelLoader := preload("res://slice3d/city/model_loader.gd")
const Retarget := preload("res://slice3d/city/humanoid_retarget.gd")
const LOOPING := ["idle", "walk", "sit", "talk", "idle_spear", "walk_spear"]

var model: Node3D
var anim: AnimationPlayer
var clips: Array = []
var info: Dictionary = {}
var _current := ""
var spear: Node3D
var _spear_ba: BoneAttachment3D
var _spear_spec := {}


func setup(dir: String, model_name: String) -> bool:
	var mesh_path := dir + "chr_%s_LOD1.glb" % model_name
	var clip_path := dir + "chr_%s_clips.glb" % model_name
	var jp := dir + "chr_%s.json" % model_name
	if FileAccess.file_exists(jp):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp))
		info = v if v is Dictionary else {}
	model = ModelLoader.instance(mesh_path)
	if model == null:
		return false
	add_child(model)
	var sk := Retarget.find_skeleton(model)
	anim = ModelLoader.find_player(model)
	if anim == null:
		anim = AnimationPlayer.new()
		model.add_child(anim)
	var root := anim.get_node(anim.root_node)
	var skel_path := str(root.get_path_to(sk)) if sk != null else ""
	var lib := AnimationLibrary.new()
	var src: Dictionary = ModelLoader.animations(clip_path)
	for name in src.keys():
		var a: Animation = (src[name] as Animation).duplicate(true)
		Retarget.retarget_animation(a, true, skel_path)
		a.loop_mode = Animation.LOOP_LINEAR if str(name) in LOOPING else Animation.LOOP_NONE
		lib.add_animation(str(name), a)
		clips.append(str(name))
	if anim.has_animation_library(""):
		anim.remove_animation_library("")
	anim.add_animation_library("", lib)
	_attach_props(dir, sk)
	play(idle_clip())
	return true


## The guard's spear (props.spear in the model JSON): BoneAttachment3D with
## the per-clip mode (in_hand, in_hand_reversed, back_sling, detached).
func _attach_props(dir: String, sk: Skeleton3D) -> void:
	_spear_spec = (info.get("props", {}) as Dictionary).get("spear", {})
	if _spear_spec.is_empty() or sk == null:
		return
	var f := dir + "itm_guard_spear.glb"
	spear = ModelLoader.instance(f)
	if spear == null:
		return
	_spear_ba = BoneAttachment3D.new()
	sk.add_child(_spear_ba)
	_spear_ba.add_child(spear)


func _spear_for(clip: String) -> void:
	if spear == null:
		return
	var mode := str((_spear_spec.get("per_clip", {}) as Dictionary).get(clip, "back_sling"))
	var at: Dictionary = (_spear_spec.get("attach", {}) as Dictionary).get(mode, {})
	spear.visible = not at.is_empty()
	if at.is_empty():
		return
	_spear_ba.bone_name = str(at.get("bone", "RightHand"))
	var q: Array = at.get("rotation_quat_xyzw", [0, 0, 0, 1])
	var p: Array = at.get("position_m", [0, 0, 0])
	var sk := _spear_ba.get_parent() as Skeleton3D
	var bi := sk.find_bone(_spear_ba.bone_name)
	var sc := sk.get_bone_global_pose(bi).basis.get_scale() * sk.global_basis.get_scale() if bi >= 0 and sk.is_inside_tree() else Vector3.ONE
	var inv := Vector3(1.0 / maxf(sc.x, 1e-6), 1.0 / maxf(sc.y, 1e-6), 1.0 / maxf(sc.z, 1e-6))
	spear.transform = Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])).scaled(inv), Vector3(p[0], p[1], p[2]) * inv)


## The model's own idle and walk (the guard carries his spear in them).
func idle_clip() -> String:
	var d := str(info.get("default_idle", "idle"))
	return d if clips.has(d) else "idle"


func walk_clip() -> String:
	if idle_clip() == "idle_spear" and clips.has("walk_spear"):
		return "walk_spear"
	return "walk"


## Walking speed that matches the clip's planted feet (walk_speed_mps).
func walk_speed(fallback := 1.4) -> float:
	var ws: Variant = info.get("walk_speed_mps", {})
	if ws is Dictionary:
		return float((ws as Dictionary).get(walk_clip(), fallback))
	if ws is float or ws is int:
		return float(ws)
	return fallback


func play(clip: String) -> void:
	if anim == null or not clips.has(clip) or clip == _current:
		return
	_current = clip
	anim.play(clip, 0.3)
	_spear_for(clip)


func is_playing_once() -> bool:
	return anim != null and anim.is_playing() and _current != "" and not _current in LOOPING


func behaviour() -> Dictionary:
	return info.get("behaviour", {})
