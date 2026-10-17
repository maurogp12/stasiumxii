extends RefCounted

## Retargets a Meshy humanoid rig to Godot's SkeletonProfileHumanoid bone
## names, on the skeleton and on every animation track, so every character
## (ours and the art team's) shares one bone naming and one clip set.
## Clip standard (lowercase snake_case, 30 fps, in place):
## idle, walk, run, turn_l, turn_r, attack_melee_1, attack_melee_2,
## attack_ranged, cast, hit, block, push, dodge, downed, death, interact,
## sit, victory.

const MESHY_TO_HUMANOID := {
	"Hips": "Hips", "Spine": "Spine", "Spine01": "Chest", "Spine02": "UpperChest",
	"neck": "Neck", "Neck": "Neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftUpperArm", "LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightArm": "RightUpperArm", "RightForeArm": "RightLowerArm", "RightHand": "RightHand",
	"LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToes",
	"RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToes",
}

const CLIPS := ["idle", "walk", "run", "turn_l", "turn_r", "attack_melee_1", "attack_melee_2",
	"attack_ranged", "cast", "hit", "block", "push", "dodge", "downed", "death", "interact", "sit", "victory"]


static func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := find_skeleton(c)
		if r != null:
			return r
	return null


## Rename the skeleton's bones in place. Returns how many were renamed.
static func retarget_skeleton(sk: Skeleton3D) -> int:
	var n := 0
	for i in sk.get_bone_count():
		var b := sk.get_bone_name(i)
		if MESHY_TO_HUMANOID.has(b) and MESHY_TO_HUMANOID[b] != b:
			sk.set_bone_name(i, MESHY_TO_HUMANOID[b])
			n += 1
	return n


## Point an animation's bone tracks at the humanoid names; in place (no root
## motion: the hips' horizontal travel is flattened out of position tracks).
static func retarget_animation(a: Animation, in_place := true, skel_path := "") -> void:
	for t in a.get_track_count():
		var p := a.track_get_path(t)
		var sub := p.get_concatenated_subnames()
		if sub == "" and skel_path != "" and p.get_name_count() > 0:
			# Clip from a file without a skin: its bones came in as plain
			# nodes; point the track at the bone on our skeleton instead.
			var bone := str(p.get_name(p.get_name_count() - 1))
			if MESHY_TO_HUMANOID.has(bone) or MESHY_TO_HUMANOID.values().has(bone):
				p = NodePath(skel_path + ":" + bone)
				a.track_set_path(t, p)
				sub = bone
		if sub != "" and MESHY_TO_HUMANOID.has(sub):
			var np := NodePath(str(p.get_concatenated_names()) + ":" + str(MESHY_TO_HUMANOID[sub]))
			a.track_set_path(t, np)
			sub = MESHY_TO_HUMANOID[sub]
		if in_place and sub == "Hips" and a.track_get_type(t) == Animation.TYPE_POSITION_3D and a.track_get_key_count(t) > 0:
			var first: Vector3 = a.track_get_key_value(t, 0)
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))
