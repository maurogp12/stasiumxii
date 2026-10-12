extends Node2D

## 2D cut-out puppet for the character select pedestal and island.
## Parts are Sprite2D nodes in a parent chain. No bone rig and no 3D.
## Idle and select are built from rig.json into an AnimationPlayer at 60 fps.
## S is the front three-quarter. Sm is S mirrored. B is the back view.
## A turn is a 0.18 s cross-fade.

const ART_ROOT := "res://art/pc/character_select/puppets/"
const SHADER := preload("res://scenes/pc/character_select/recolour.gdshader")

var facing := "S"
var class_id := ""
var gender := ""
var list_mode := false
var performance := false
var rig: Dictionary = {}

var _base_scale := 1.0
var _fade_a: Node2D
var _fade_b: Node2D
var _player_a: AnimationPlayer
var _player_b: AnimationPlayer
var _showing_b := false
var _fading := false
var _still := 0.0
var _drag := 0.0
var _worn: Dictionary = {}
var _face := "broad"
var _skin := Color(0.776, 0.525, 0.259)
var _hair := Color(0.231, 0.141, 0.078)
var _eyes := Color(0.239, 0.169, 0.122)
var _materials: Array[ShaderMaterial] = []
var _turn_tween: Tween


static func directory_for(class_key: String, gender_key: String) -> String:
	return ART_ROOT + "%s_%s" % [class_key, gender_key]


static func has_puppet(class_key: String, gender_key: String) -> bool:
	return FileAccess.file_exists(directory_for(class_key, gender_key) + "/rig.json")


func show_puppet(class_key: String, gender_key: String) -> bool:
	if class_key == class_id and gender_key == gender and _fade_a != null:
		return true
	release()
	if not has_puppet(class_key, gender_key):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory_for(class_key, gender_key) + "/rig.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	rig = parsed
	class_id = class_key
	gender = gender_key
	facing = "S"
	_worn = {}
	_face = "broad"
	add_to_group("charselect_puppet")
	_fade_a = _build_tree("A")
	_fade_b = _build_tree("B")
	add_child(_fade_a)
	add_child(_fade_b)
	_showing_b = false
	_fade_b.modulate.a = 0.0
	_fade_b.visible = false
	_apply_facing(_fade_a, "S")
	_apply_facing(_fade_b, "Sm")
	_apply_root_scale()
	play_idle()
	return true


func release() -> void:
	_kill_turn()
	if is_in_group("charselect_puppet"):
		remove_from_group("charselect_puppet")
	for node in [_fade_a, _fade_b]:
		if node != null and is_instance_valid(node):
			node.free()
	_fade_a = null
	_fade_b = null
	_player_a = null
	_player_b = null
	_materials.clear()
	rig = {}
	class_id = ""
	gender = ""
	facing = "S"


func set_body_colors(skin: Color, hair: Color, eyes: Color) -> void:
	_skin = skin
	_hair = hair
	_eyes = eyes
	for mat in _materials:
		if mat == null:
			continue
		mat.set_shader_parameter("skin", _skin)
		mat.set_shader_parameter("hair", _hair)
		mat.set_shader_parameter("eyes", _eyes)


func set_face(face_id: String) -> void:
	_face = face_id
	_refresh_textures()


func set_slot(slot: String, family: String) -> void:
	if family == "":
		_worn.erase(slot)
	else:
		_worn[slot] = family
	_refresh_textures()


func clear_slots() -> void:
	_worn.clear()
	_refresh_textures()


func set_list_mode(on: bool) -> void:
	var was := list_mode
	list_mode = on
	if on and was != on:
		play_idle()
	_apply_root_scale()


func set_performance(on: bool) -> void:
	if performance == on:
		return
	performance = on
	_refresh_textures()
	if _player_a != null and _player_a.current_animation == "idle":
		play_idle()


func play_idle() -> void:
	_play("idle_core" if performance else "idle")
	if performance:
		_rest_secondary()


func _rest_secondary() -> void:
	var names: Array = rig.get("anims", {}).get("idle", {}).get("secondary", [])
	for root in [_fade_a, _fade_b]:
		if root == null:
			continue
		for part_name in names:
			var node := root.get_node_or_null(_node_path(str(part_name))) as Node2D
			if node != null:
				node.rotation = 0.0


func play_select() -> void:
	if list_mode or _player_a == null:
		return
	_play("select")


func snap_facing(which: String) -> void:
	if rig.is_empty():
		return
	_kill_turn()
	_fading = false
	facing = which
	_showing_b = false
	if _fade_a != null:
		_apply_facing(_fade_a, which)
		_fade_a.visible = true
		_fade_a.modulate.a = 1.0
	if _fade_b != null:
		_fade_b.visible = false
		_fade_b.modulate.a = 0.0
	_apply_root_scale()


func turn(dir: int) -> void:
	if list_mode or _fading or rig.is_empty() or dir == 0:
		return
	var order: Array = rig.get("turn", {}).get("order", ["S", "Sm", "B"])
	var index := order.find(facing)
	if index < 0:
		index = 0
	var nxt := str(order[posmod(index + dir, order.size())])
	_begin_fade(nxt)


func turn_by_pixels(dx: float) -> void:
	if list_mode or rig.is_empty():
		return
	_still = 0.0
	_drag += dx
	var need := float(rig.get("turn", {}).get("drag_px", 60))
	if absf(_drag) >= need and not _fading:
		var dir := 1 if _drag > 0.0 else -1
		_drag -= need * float(dir)
		turn(dir)


func fit_height(px: float) -> void:
	var figure := maxf(float(rig.get("figure_px", 1.0)), 1.0)
	_base_scale = px / figure
	if list_mode:
		_base_scale *= 0.8
	_apply_root_scale()


func feet_offset() -> float:
	return float(rig.get("feet_from_hip", 0.0)) * _base_scale


func seek_anim(anim_name: String, time: float) -> void:
	for player in [_player_a, _player_b]:
		if player == null or not player.has_animation(anim_name):
			continue
		player.play(anim_name)
		player.seek(time, true)


func anim_length(anim_name: String) -> float:
	if _player_a == null or not _player_a.has_animation(anim_name):
		return 0.0
	return _player_a.get_animation(anim_name).length


func part_node(part: String) -> Node2D:
	var root := _visible_root()
	if root == null:
		return null
	return root.get_node_or_null(_node_path(part)) as Node2D


func sprite_of(part: String) -> Sprite2D:
	var node := part_node(part)
	if node == null:
		return null
	return node.get_node_or_null("sprite") as Sprite2D


func texture_path(part: String) -> String:
	var sprite := sprite_of(part)
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path


func part_image(part: String) -> Image:
	var sprite := sprite_of(part)
	if sprite == null or sprite.texture == null:
		return null
	return sprite.texture.get_image()


func scale_x_magnitude() -> float:
	var root := _visible_root()
	if root == null:
		return 0.0
	return absf(root.scale.x)


func apply_turn_sample(t: float) -> void:
	var outgoing := _visible_root()
	var incoming := _hidden_root()
	if outgoing == null or incoming == null:
		return
	_squash_roots(t, outgoing, incoming, _sign_for(facing), _sign_for(facing))


func secondary_on() -> bool:
	return not performance


func _process(delta: float) -> void:
	if list_mode or rig.is_empty() or _fading or facing == "S":
		return
	_still += delta
	var limit := float(rig.get("turn", {}).get("return_s_sec", 4.0))
	if _still < limit:
		return
	_still = 0.0
	# Sm steps back to S. B steps forward to S.
	if facing == "Sm":
		turn(-1)
	else:
		turn(1)


func _build_tree(which: String) -> Node2D:
	var root := Node2D.new()
	root.name = "Fade" + which
	var parts: Dictionary = rig.get("parts", {})
	var nodes: Dictionary = {}
	var hip := Node2D.new()
	hip.name = "hip"
	hip.z_as_relative = false
	root.add_child(hip)
	nodes["hip"] = hip
	for part_name in parts.keys():
		if str(part_name) == "hip":
			continue
		var body := Node2D.new()
		body.name = str(part_name)
		body.z_as_relative = false
		nodes[str(part_name)] = body
	for part_name in nodes.keys():
		if str(part_name) == "hip":
			continue
		var spec: Dictionary = parts.get(part_name, {})
		var parent_name := str(spec.get("parent", "hip"))
		var parent: Node2D = nodes.get(parent_name, hip)
		parent.add_child(nodes[part_name])
		var rest: Dictionary = spec.get("rest", {}).get("S", {})
		var pos: Array = rest.get("pos", [0, 0])
		nodes[part_name].position = Vector2(float(pos[0]), float(pos[1]))
		if bool(spec.get("sprite", false)):
			var sprite := Sprite2D.new()
			sprite.name = "sprite"
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			nodes[part_name].add_child(sprite)
	var player := AnimationPlayer.new()
	player.name = "Anim"
	root.add_child(player)
	var library := AnimationLibrary.new()
	for anim_name in ["idle", "idle_core", "select"]:
		library.add_animation(anim_name, _build_animation(str(anim_name)))
	player.add_animation_library("", library)
	player.animation_finished.connect(_on_anim_finished)
	if which == "A":
		_player_a = player
	else:
		_player_b = player
	return root


func _build_animation(anim_name: String) -> Animation:
	var source := "idle" if anim_name == "idle_core" else anim_name
	var spec: Dictionary = rig.get("anims", {}).get(source, {})
	var anim := Animation.new()
	anim.length = float(spec.get("length", 1.0))
	anim.step = 1.0 / 60.0
	anim.loop_mode = Animation.LOOP_LINEAR if bool(spec.get("loop", false)) and anim_name != "select" else Animation.LOOP_NONE
	var secondary: Array = spec.get("secondary", [])
	var tracks: Dictionary = spec.get("tracks", {})
	for part_name in tracks.keys():
		if anim_name == "idle_core" and secondary.has(part_name):
			continue
		var keys: Array = tracks[part_name]
		if keys.is_empty():
			continue
		var path := _node_path(str(part_name))
		_add_float_track(anim, path + ":rotation", keys, "rot")
		_add_scale_track(anim, path + ":scale", keys)
		if _keys_have(keys, "a"):
			_add_float_track(anim, path + ":modulate:a", keys, "a")
	return anim


func _add_float_track(anim: Animation, path: String, keys: Array, field: String) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(path))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for key in keys:
		if typeof(key) != TYPE_DICTIONARY or not (key as Dictionary).has(field):
			continue
		anim.track_insert_key(track, float((key as Dictionary)["t"]), float((key as Dictionary)[field]))


func _add_scale_track(anim: Animation, path: String, keys: Array) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(path))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for key in keys:
		if typeof(key) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = key
		if not row.has("sx") and not row.has("sy"):
			continue
		anim.track_insert_key(track, float(row["t"]), Vector2(float(row.get("sx", 1.0)), float(row.get("sy", 1.0))))


func _keys_have(keys: Array, field: String) -> bool:
	for key in keys:
		if typeof(key) == TYPE_DICTIONARY and (key as Dictionary).has(field):
			return true
	return false


func _node_path(part: String) -> String:
	var parts: Dictionary = rig.get("parts", {})
	var chain: Array[String] = []
	var cursor := part
	var guard := 0
	while cursor != "" and guard < 12:
		chain.push_front(cursor)
		if cursor == "hip":
			break
		cursor = str(parts.get(cursor, {}).get("parent", ""))
		guard += 1
	return "/".join(chain)


func _apply_facing(root: Node2D, which: String) -> void:
	if root == null:
		return
	var art := _art_for(which)
	var parts: Dictionary = rig.get("parts", {})
	for part_name in parts.keys():
		var spec: Dictionary = parts[part_name]
		var node := root.get_node_or_null(_node_path(str(part_name))) as Node2D
		if node == null:
			continue
		var zed: Variant = spec.get("z", {})
		if typeof(zed) == TYPE_DICTIONARY:
			node.z_index = int((zed as Dictionary).get(art, 0))
		var rest: Dictionary = spec.get("rest", {}).get(art, {})
		var pos: Array = rest.get("pos", [0, 0])
		if str(part_name) != "hip":
			node.position = Vector2(float(pos[0]), float(pos[1]))
		if not bool(spec.get("sprite", false)):
			continue
		var sprite := node.get_node_or_null("sprite") as Sprite2D
		if sprite == null:
			continue
		var pivot: Array = spec.get("pivot", {}).get(art, [0, 0])
		_bind_sprite(sprite, str(part_name), art, Vector2(float(pivot[0]), float(pivot[1])))


func _bind_sprite(sprite: Sprite2D, part: String, art: String, pivot: Vector2) -> void:
	var file_name := _file_for(part, art)
	var folder := _folder_for(part)
	var stem := ART_ROOT + "%s_%s/%s%s/%s/%s" % [class_id, gender, "_half/" if performance else "", art, folder, file_name]
	var tex := load(stem + ".png") as Texture2D
	var mask := load(stem + "_mask.png") as Texture2D
	sprite.texture = tex
	var draw := 2.0 if performance else 1.0
	sprite.scale = Vector2(draw, draw)
	sprite.position = -pivot
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	if mask != null:
		mat.set_shader_parameter("mask_tex", mask)
	mat.set_shader_parameter("skin", _skin)
	mat.set_shader_parameter("hair", _hair)
	mat.set_shader_parameter("eyes", _eyes)
	sprite.material = mat
	_materials.append(mat)


func _file_for(part: String, _art: String) -> String:
	if part == "head":
		for row in rig.get("faces", []):
			if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == _face:
				return str((row as Dictionary).get("file", "head_f1"))
		return "head_f1"
	return part


func _folder_for(part: String) -> String:
	var slots: Dictionary = rig.get("slots", {})
	for slot in _worn.keys():
		var names: Variant = slots.get(slot, [])
		if typeof(names) == TYPE_ARRAY and (names as Array).has(part):
			return "%s_%s" % [str(_worn[slot]), str(slot)]
	return "base"


func _refresh_textures() -> void:
	_materials.clear()
	var shown := facing
	var other := _next_facing(shown)
	if _showing_b:
		_apply_facing(_fade_b, shown)
		_apply_facing(_fade_a, other)
	else:
		_apply_facing(_fade_a, shown)
		_apply_facing(_fade_b, other)


func _begin_fade(nxt: String) -> void:
	var incoming := _hidden_root()
	var outgoing := _visible_root()
	if incoming == null or outgoing == null:
		facing = nxt
		return
	_apply_facing(incoming, nxt)
	incoming.visible = true
	incoming.modulate.a = 0.0
	_fading = true
	_still = 0.0
	var from_sign := _sign_for(facing)
	var to_sign := _sign_for(nxt)
	facing = nxt
	_kill_turn()
	_turn_tween = create_tween()
	_turn_tween.tween_method(_on_fade_step.bind(outgoing, incoming, from_sign, to_sign), 0.0, 1.0, float(rig.get("turn", {}).get("sec", 0.18)))
	_turn_tween.tween_callback(_finish_fade.bind(incoming, outgoing))


func _on_fade_step(t: float, outgoing: Node2D, incoming: Node2D, from_sign: float, to_sign: float) -> void:
	if outgoing != null:
		outgoing.modulate.a = 1.0 - t
	if incoming != null:
		incoming.modulate.a = t
	_squash_roots(t, outgoing, incoming, from_sign, to_sign)


func _squash_roots(t: float, outgoing: Node2D, incoming: Node2D, from_sign: float, to_sign: float) -> void:
	var pinch := 1.0 - absf(t - 0.5) * 2.0
	var squash := float(rig.get("turn", {}).get("squash", 0.96))
	var sx := lerpf(1.0, squash, pinch)
	if outgoing != null:
		outgoing.scale = Vector2(from_sign * _base_scale * sx, _base_scale)
	if incoming != null:
		incoming.scale = Vector2(to_sign * _base_scale * sx, _base_scale)


func _finish_fade(incoming: Node2D, outgoing: Node2D) -> void:
	_fading = false
	_showing_b = incoming == _fade_b
	if outgoing != null:
		outgoing.modulate.a = 0.0
		outgoing.visible = false
	if incoming != null:
		incoming.modulate.a = 1.0
		incoming.visible = true
	_apply_root_scale()


func _apply_root_scale() -> void:
	var shown := _visible_root()
	var hidden := _hidden_root()
	if shown != null:
		shown.scale = Vector2(_sign_for(facing) * _base_scale, _base_scale)
	if hidden != null and not _fading:
		hidden.scale = Vector2(_base_scale, _base_scale)


func _art_for(which: String) -> String:
	if which == "B":
		return "B"
	return "S"


func _next_facing(which: String) -> String:
	var order: Array = rig.get("turn", {}).get("order", ["S", "Sm", "B"])
	var index := order.find(which)
	if index < 0:
		index = 0
	return str(order[posmod(index + 1, order.size())])


func _sign_for(which: String) -> float:
	return -1.0 if which == "Sm" else 1.0


func _visible_root() -> Node2D:
	return _fade_b if _showing_b else _fade_a


func _hidden_root() -> Node2D:
	return _fade_a if _showing_b else _fade_b


func _play(anim_name: String) -> void:
	for player in [_player_a, _player_b]:
		if player != null and player.has_animation(anim_name):
			player.play(anim_name)


func _on_anim_finished(anim_name: StringName) -> void:
	if str(anim_name) == "select" and not list_mode:
		play_idle()


func _kill_turn() -> void:
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = null
