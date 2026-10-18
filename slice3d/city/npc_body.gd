extends Node3D

## A 3D townsperson body: the art kit's skinned mesh plus its clip file
## (idle, walk, interact, sit, talk), on humanoid bone names. Plays clips by
## name; falls back to a capsule figure when the model is missing.

const ModelLoader := preload("res://slice3d/city/model_loader.gd")
const Retarget := preload("res://slice3d/city/humanoid_retarget.gd")
const LOOPING := ["idle", "walk", "sit", "talk"]

var model: Node3D
var anim: AnimationPlayer
var clips: Array = []
var info: Dictionary = {}
var _current := ""


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
	play("idle")
	return true


func play(clip: String) -> void:
	if anim == null or not clips.has(clip) or clip == _current:
		return
	_current = clip
	anim.play(clip, 0.3)


func is_playing_once() -> bool:
	return anim != null and anim.is_playing() and _current != "" and not _current in LOOPING


func behaviour() -> Dictionary:
	return info.get("behaviour", {})
