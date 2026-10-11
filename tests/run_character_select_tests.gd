extends SceneTree

## Contained 3D character-select stage: viewport, recolour, gear, faces, containment.
## Run: godot --headless --path . -s res://tests/run_character_select_tests.gd

const STAGE := preload("res://scenes/pc/character_select/character_stage.tscn")
const StageScript := preload("res://scenes/pc/character_select/character_stage.gd")
const WORLD := "res://scenes/world/crosshaven/crosshaven_world.tscn"
const DUNGEON := "res://scenes/world/dungeon/dungeon_run.tscn"
const COMBAT := "res://main.tscn"
const ALLOWED_SCENE := "res://scenes/pc/character_select/"
const ART := "res://art/pc/characters_3d/"

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_shader_source()
	_test_recolour_math()
	_test_mask_pixels()
	_test_paths()
	var stage: Node = STAGE.instantiate()
	root.add_child(stage)
	_test_viewport(stage)
	_test_model(stage)
	_test_colours_and_dye(stage)
	_test_faces_and_gear(stage)
	_test_motion(stage)
	_test_performance_and_list(stage)
	await _test_release(stage)
	_test_containment_files()
	await _test_containment_scenes()
	print("character select tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_shader_source() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/pc/character_select/recolour.gdshader")
	check(src.contains("shader_type spatial"), "recolour shader is spatial")
	check(src.contains("uniform vec3 skin"), "skin uniform")
	check(src.contains("uniform vec3 hair"), "hair uniform")
	check(src.contains("uniform vec3 eyes"), "eyes uniform")
	check(not src.contains("uniform vec3 primary"), "no armour primary uniform")
	check(not src.contains("uniform vec3 secondary"), "no armour secondary uniform")
	check(not src.contains("uniform vec3 accent"), "no armour accent uniform")
	check(src.contains("dot(albedo.rgb, vec3(0.299, 0.587, 0.114))"), "luminance weights")
	check(src.contains("lum * 2.0 * skin"), "skin tint keeps shading")
	check(src.find("mask.r") < src.find("mask.g") and src.find("mask.g") < src.find("mask.b"), "channels apply R then G then B")
	check(src.contains("uniform sampler2D dye_mask"), "dye mask hook is declared")
	check(src.contains("uniform float dye_enabled"), "dye stays behind a switch")
	check(src.contains("uniform float face_index"), "face index hook is declared")
	check(not src.contains("hint_screen_texture"), "no screen texture")
	check(not src.contains("hint_depth_texture"), "no depth texture")


func _test_recolour_math() -> void:
	var cloth := Color(0.76, 0.67, 0.52)
	var skin := Color(0.2, 0.8, 0.3)
	var hair := Color(0.9, 0.1, 0.1)
	var eyes := Color(0.1, 0.2, 0.9)
	var kept := StageScript.shade_recolour(cloth, Color(0, 0, 0), skin, hair, eyes)
	check(_near(kept, cloth), "black mask leaves cloth uncoloured")
	var grey := Color(0.5, 0.5, 0.5)
	var skinned := StageScript.shade_recolour(grey, Color(1, 0, 0), skin, hair, eyes)
	check(_near(skinned, skin), "mid grey skin mask becomes the skin colour")
	var haired := StageScript.shade_recolour(grey, Color(0, 1, 0), skin, hair, eyes)
	check(_near(haired, hair), "mid grey hair mask becomes the hair colour")
	var eyed := StageScript.shade_recolour(grey, Color(0, 0, 1), skin, hair, eyes)
	check(_near(eyed, eyes), "mid grey eye mask becomes the eye colour")
	var dark := StageScript.shade_recolour(Color(0.2, 0.2, 0.2), Color(1, 0, 0), Color(1, 0, 0), hair, eyes)
	var light := StageScript.shade_recolour(Color(0.8, 0.8, 0.8), Color(1, 0, 0), Color(1, 0, 0), hair, eyes)
	check(light.r > dark.r + 0.5, "lighter albedo stays lighter after the tint")
	var ordered := StageScript.shade_recolour(grey, Color(1, 1, 0), skin, hair, eyes)
	check(_near(ordered, hair), "a full green mask replaces the red mix, using the original luminance")
	var half := StageScript.shade_recolour(grey, Color(0.5, 0, 0), Color(1, 0, 0), hair, eyes)
	check(_near(half, Color(0.75, 0.25, 0.25)), "a half skin mask blends halfway")
	var dyed_off := StageScript.shade_recolour(cloth, Color(0, 0, 0), skin, hair, eyes, 1.0, Color(0, 1, 0), 0.0)
	check(_near(dyed_off, cloth), "dye hook at 0 leaves armour painted")
	var dyed_on := StageScript.shade_recolour(grey, Color(0, 0, 0), skin, hair, eyes, 1.0, Color(0, 1, 0), 1.0)
	check(_near(dyed_on, Color(0, 1, 0)), "dye hook at 1 tints a gear texel")


func _test_mask_pixels() -> void:
	var mask := Image.new()
	var bytes := FileAccess.get_file_as_bytes("res://art/pc/characters_3d/test/mask.png")
	var err := mask.load_png_from_buffer(bytes)
	check(err == OK, "mask texture loads")
	if err != OK:
		return
	var saw_r := false
	var saw_g := false
	var saw_b := false
	var saw_black := false
	for y in range(0, mask.get_height(), 8):
		for x in range(0, mask.get_width(), 8):
			var c := mask.get_pixel(x, y)
			if c.r > 0.9 and c.g < 0.1 and c.b < 0.1:
				saw_r = true
			if c.g > 0.9 and c.r < 0.1 and c.b < 0.1:
				saw_g = true
			if c.b > 0.9 and c.r < 0.1 and c.g < 0.1:
				saw_b = true
			if c.r < 0.05 and c.g < 0.05 and c.b < 0.05:
				saw_black = true
	check(saw_r and saw_g and saw_b and saw_black, "mask has skin, hair, eyes, and untouched texels")


func _test_paths() -> void:
	check(StageScript.model_path("ironjaw", "m") == "res://art/pc/characters_3d/ironjaw/ironjaw_m.glb", "male path")
	check(StageScript.model_path("ironjaw", "f") == "res://art/pc/characters_3d/ironjaw/ironjaw_f.glb", "female path")
	check(StageScript.model_path("ironjaw", "x") == "", "gender must be m or f")
	check(StageScript.model_path("../nope", "m") == "", "class id cannot climb out of the art folder")
	var shared := "res://art/pc/characters_3d/test/placeholder.glb"
	check(StageScript.resolve_model_path("test", "m") == shared, "placeholder serves male")
	check(StageScript.resolve_model_path("test", "f") == shared, "placeholder serves female")
	check(StageScript.resolve_model_path("ironjaw", "f") == "", "a missing class GLB does not fall back to the test capsule")


func _test_viewport(stage: Node) -> void:
	var vp: SubViewport = stage.viewport()
	check(vp != null and vp.own_world_3d and vp.transparent_bg, "viewport has its own world and a transparent background")
	check(vp.size == Vector2i(768, 1024), "viewport is 768x1024")
	check(vp.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE, "viewport updates while visible")
	var cam: Camera3D = stage.camera()
	check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "camera is perspective")
	check(absf(cam.fov - 28.0) < 0.01, "camera fov is 28")
	check(cam.position.distance_to(Vector3(0, 1.25, 4.2)) < 0.02, "camera sits at (0, 1.25, 4.2)")
	var forward := -cam.global_transform.basis.z
	var aim := (Vector3(0, 0.95, 0) - cam.position).normalized()
	check(forward.dot(aim) > 0.99, "camera looks at (0, 0.95, 0)")
	var key: DirectionalLight3D = stage.key_light()
	check(absf(key.light_energy - 1.2) < 0.01, "key energy is 1.2")
	check(not key.shadow_enabled, "key shadows are off")
	check(key.rotation_degrees.distance_to(Vector3(-35, 35, 0)) < 0.1, "key rotation is (-35, 35, 0)")
	var rim: OmniLight3D = stage.rim_light()
	check(absf(rim.light_energy - 2.0) < 0.01 and absf(rim.omni_range - 4.0) < 0.01, "rim energy 2 and range 4")
	check(not rim.shadow_enabled and rim.position.z < 0.0 and rim.position.y > 1.5, "rim is behind and above, shadows off")
	var env: Environment = stage.fill_environment()
	check(absf(env.ambient_light_energy - 0.35) < 0.01, "fill ambient is 0.35")
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "fill is a flat ambient colour")
	check(env.background_mode == Environment.BG_COLOR, "no sky")
	check(not env.sdfgi_enabled and not env.glow_enabled and not env.ssr_enabled and not env.ssao_enabled and not env.volumetric_fog_enabled, "no screen-space or gi effects")
	var shadows := false
	_each(vp, func(n: Node) -> void:
		if n is Light3D and (n as Light3D).shadow_enabled:
			shadows = true
	)
	check(not shadows, "every light has shadows off")
	var blob := stage.get_node("ContactShadow")
	check(blob is TextureRect and blob.get_parent() == stage, "contact shadow is a 2D sprite outside the 3D world")
	check(absf(stage.yaw_degrees - StageScript.REST_YAW) < 0.01, "turntable rests at -20 degrees")


func _test_model(stage: Node) -> void:
	check(stage.show_model("ironjaw", "m") == false, "missing ironjaw male does not load")
	check(stage.loaded_path() == "", "a miss leaves nothing loaded")
	check(stage.show_model("test", "m"), "test male loads the placeholder")
	check(stage.gender() == "m" and stage.class_id() == "test", "stage remembers class and gender")
	check(stage.loaded_path().ends_with("placeholder.glb"), "male uses the shared placeholder")
	check(stage.current_animation() == "select", "showing a model plays the select flourish")
	var player := stage.model_root().find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(player != null, "model has an AnimationPlayer")
	var idle: Animation = player.get_animation("idle")
	var select: Animation = player.get_animation("select")
	check(idle.loop_mode == Animation.LOOP_LINEAR and idle.length >= 3.0 and idle.length <= 5.0, "idle loops for 3 to 5 seconds")
	check(select.loop_mode == Animation.LOOP_NONE and select.length >= 1.5 and select.length <= 2.5, "select is a one-shot of 1.5 to 2.5 seconds")
	var skel := stage.model_root().find_child("Skeleton3D", true, false) as Skeleton3D
	check(skel != null and skel.get_bone_count() <= 60 and skel.get_bone_count() > 0, "skeleton stays within 60 bones")
	var acc := {"tris": 0, "min_y": 1000.0, "max_y": -1000.0, "eye_z": -1000.0}
	_bounds(stage.model_root(), stage.model_root(), acc)
	check(int(acc["tris"]) > 0 and int(acc["tris"]) <= 15000, "triangle count stays within 15k")
	check(float(acc["min_y"]) >= -0.02 and float(acc["min_y"]) <= 0.05, "origin is at the feet")
	check(float(acc["max_y"]) >= 1.75 and float(acc["max_y"]) <= 1.95, "height is 1.75 to 1.95 m")
	check(float(acc["eye_z"]) > 0.05, "eyes face +Z")
	check(stage.show_model("test", "f"), "test female loads")
	check(stage.gender() == "f", "gender switches to female")
	check(stage.loaded_path().ends_with("placeholder.glb"), "female uses the same placeholder")
	check(_live_models(stage) == 1, "switching gender keeps a single instance")
	check(stage.show_model("kestrel", "f") == false, "a class without a GLB unloads the previous model")
	check(_live_models(stage) == 0 and stage.loaded_path() == "", "the previous GLB is gone")


func _test_colours_and_dye(stage: Node) -> void:
	check(stage.show_model("test", "m"), "reload the placeholder for colour tests")
	var skin := Color(0.9, 0.3, 0.2)
	var hair := Color(0.1, 0.15, 0.2)
	var eyes := Color(0.2, 0.7, 0.4)
	stage.set_body_colors(skin, hair, eyes)
	var mat: ShaderMaterial = stage.body_material()
	check(_vec(mat, "skin", skin), "skin uniform is live")
	check(_vec(mat, "hair", hair), "hair uniform is live")
	check(_vec(mat, "eyes", eyes), "eyes uniform is live")
	check(float(mat.get_shader_parameter("dye_enabled")) == 0.0, "dye starts off")
	var dye := Image.create(2, 2, false, Image.FORMAT_RGB8)
	dye.fill(Color(1, 1, 1))
	var tex := ImageTexture.create_from_image(dye)
	stage.set_gear_dye_mask(tex)
	check(mat.get_shader_parameter("dye_mask") == tex, "dye mask hook stores the texture")
	check(stage.dye_enabled() == false, "storing a dye mask does not recolour armour")
	check(float(mat.get_shader_parameter("dye_enabled")) == 0.0, "dye_enabled stays 0")


func _test_faces_and_gear(stage: Node) -> void:
	var count := int(stage.face_count())
	check(count >= StageScript.FACE_MIN and count <= StageScript.FACE_MAX, "face types are between 3 and 5")
	check(stage.face_index() == 0, "face starts at 0")
	check(stage.set_face(count - 1), "last face can be selected")
	check(stage.face_index() == count - 1, "face index follows the selection")
	check(_face_visible(stage, count - 1) and not _face_visible(stage, 0), "only the selected face meshes show")
	check(not stage.set_face(count) and not stage.set_face(-1), "face index outside the model is refused")
	check(float(stage.body_material().get_shader_parameter("face_index")) == float(count - 1), "face index uniform follows the mesh")
	for slot in StageScript.GEAR_SLOTS:
		var base: Node = stage.zone_node("base_" + slot)
		var gear: Node = stage.zone_node("gear_" + slot)
		check(base != null and gear != null, "slot %s has a base mesh and a gear mesh" % slot)
		check(base.visible and not gear.visible, "slot %s starts as the base clothes" % slot)
		stage.set_slot(slot, true)
		check(not base.visible and gear.visible, "equipping %s hides that base zone" % slot)
		stage.set_slot(slot, false)
		check(base.visible and not gear.visible, "clearing %s brings the base zone back" % slot)
	stage.set_slot("chest", true)
	check(stage.zone_node("base_legs").visible and stage.zone_node("base_body").visible, "a chest piece does not hide the other zones")
	stage.set_slot("chest", false)


func _test_motion(stage: Node) -> void:
	stage.play_idle()
	check(stage.current_animation() == "idle", "idle can be playing")
	stage.play_select()
	check(stage.current_animation() == "select", "select can be played again")
	var player := stage.model_root().find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.advance(3.0)
	check(stage.current_animation() == "idle", "select returns to idle")
	var before: float = stage.yaw_degrees
	stage.turn_by_pixels(10.0)
	check(absf(stage.yaw_degrees - (before + 4.0)) < 0.001, "drag turns 0.4 degrees per pixel")
	stage.advance(1.9)
	check(absf(stage.yaw_degrees - (before + 4.0)) < 0.001, "yaw holds for 2 seconds")
	stage.advance(0.5)
	check(stage.yaw_degrees < before + 4.0, "yaw eases back after the hold")
	for i in 40:
		stage.advance(0.1)
	check(absf(stage.yaw_degrees - StageScript.REST_YAW) < 0.5, "yaw returns to -20")
	stage.visible = false
	check(stage.viewport().render_target_update_mode == SubViewport.UPDATE_DISABLED, "hiding the stage stops the viewport")
	stage.visible = true
	check(stage.viewport().render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE, "showing the stage updates again")
	stage.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(stage.viewport().render_target_update_mode == SubViewport.UPDATE_DISABLED, "a minimised window stops the viewport")
	stage.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(stage.viewport().render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE, "focus brings the viewport back")


func _test_performance_and_list(stage: Node) -> void:
	stage.set_performance(true)
	check(stage.viewport().size == Vector2i(384, 512), "performance mode halves the viewport")
	check(stage.viewport().msaa_3d == Viewport.MSAA_DISABLED, "performance mode turns MSAA off")
	var player := stage.model_root().find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(absf(player.speed_scale - 0.5) < 0.01, "performance mode plays idle at half speed")
	stage.set_list_mode(true)
	check(absf(stage.turntable().scale.x - 0.8) < 0.01, "the island shows the model at 0.8 scale")
	check(stage.current_animation() == "idle", "list mode stays on idle")
	stage.play_select()
	check(stage.current_animation() == "idle", "list mode does not play the flourish")
	stage.set_list_mode(false)
	stage.set_performance(false)
	check(stage.viewport().size == Vector2i(768, 1024), "full mode restores 768x1024")
	check(absf(stage.turntable().scale.x - 1.0) < 0.01, "pedestal scale is 1")


func _test_release(stage: Node) -> void:
	stage.release()
	await process_frame
	check(stage.viewport() == null, "release frees the viewport")
	check(_count_3d(root) == 0, "no 3D nodes remain after the stage releases")
	check(stage.show_model("test", "m") == false, "a released stage does not load again")
	var again: Node = STAGE.instantiate()
	root.add_child(again)
	check(again.show_model("test", "f"), "a new stage can load the female placeholder")
	again.queue_free()
	await process_frame
	check(_count_3d(root) == 0, "leaving the tree frees the 3D world")


func _test_containment_files() -> void:
	var banned := [
		"type=\"Node3D\"",
		"type=\"Camera3D\"",
		"type=\"MeshInstance3D\"",
		"type=\"DirectionalLight3D\"",
		"type=\"OmniLight3D\"",
		"type=\"SpotLight3D\"",
		"type=\"Light3D\"",
		"type=\"WorldEnvironment\"",
		"type=\"Skeleton3D\"",
		"type=\"BoneAttachment3D\"",
	]
	var scenes: Array[String] = []
	for folder in ["res://scenes", "res://ui", "res://board", "res://units"]:
		_walk(folder, ".tscn", scenes)
	check(scenes.size() > 5, "scene scan sees the project")
	var leaked := ""
	for path in scenes:
		if path.begins_with(ALLOWED_SCENE):
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.contains("own_world_3d"):
			leaked = path + " own_world_3d"
			break
		if text.contains(ART):
			leaked = path + " art"
			break
		for token in banned:
			if text.contains(token):
				leaked = path + " " + token
				break
		if leaked != "":
			break
	check(leaked == "", "no 3D scene outside the character-select folder (%s)" % leaked)
	var scripts: Array[String] = []
	_walk("res://", ".gd", scripts)
	var script_leak := ""
	for path in scripts:
		if path.begins_with(ALLOWED_SCENE):
			continue
		var text := FileAccess.get_file_as_string(path)
		for line in text.split("\n"):
			if _line_loads_art(line):
				script_leak = path
				break
		if script_leak != "":
			break
	check(script_leak == "", "no script outside the stage folder loads the 3D art (%s)" % script_leak)


func _test_containment_scenes() -> void:
	for path in [WORLD, DUNGEON, COMBAT]:
		var packed := load(path) as PackedScene
		check(packed != null, "scene loads: %s" % path)
		if packed == null:
			continue
		var node := packed.instantiate()
		root.add_child(node)
		await process_frame
		check(_count_3d(node) == 0, "no 3D nodes in %s" % path)
		node.queue_free()
		await process_frame


func _line_loads_art(line: String) -> bool:
	if not line.contains("art/pc/characters_3d"):
		return false
	var stripped := line.replace(".load(", "")
	if stripped.contains("preload(") or stripped.contains("ResourceLoader.load("):
		return true
	return stripped.contains("load(") and not line.contains(".load(")


func _face_visible(stage: Node, index: int) -> bool:
	var model: Node = stage.model_root()
	var saw := false
	var ok := true
	var pending: Array[Node] = [model]
	while pending.size() > 0:
		var node: Node = pending.pop_back()
		var text := String(node.name)
		if text.begins_with("face_%d_" % index) and node is MeshInstance3D:
			saw = true
			if not node.visible:
				ok = false
		for child in node.get_children():
			pending.append(child)
	return saw and ok


func _live_models(stage: Node) -> int:
	var n := 0
	for child in stage.turntable().get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n


func _bounds(model: Node, node: Node, acc: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				acc["tris"] = int(acc["tris"]) + int(arrays[Mesh.ARRAY_VERTEX].size() / 3)
			else:
				acc["tris"] = int(acc["tris"]) + int(idx.size() / 3)
		var xform: Transform3D = model.global_transform.affine_inverse() * mi.global_transform
		var box: AABB = xform * mi.get_aabb()
		acc["min_y"] = minf(float(acc["min_y"]), box.position.y)
		acc["max_y"] = maxf(float(acc["max_y"]), box.position.y + box.size.y)
		if str(node.name).begins_with("face_0_eyes"):
			var center := box.position + box.size * 0.5
			acc["eye_z"] = maxf(float(acc["eye_z"]), center.z)
	for child in node.get_children():
		_bounds(model, child, acc)


func _count_3d(node: Node) -> int:
	var n := 0
	if node is Node3D or node is WorldEnvironment:
		n += 1
	if node is SubViewport and (node as SubViewport).own_world_3d:
		n += 1
	for child in node.get_children():
		n += _count_3d(child)
	return n


func _each(node: Node, fn: Callable) -> void:
	fn.call(node)
	for child in node.get_children():
		_each(child, fn)


func _walk(dir_path: String, suffix: String, acc: Array) -> void:
	var folder := DirAccess.open(dir_path)
	if folder == null:
		return
	folder.list_dir_begin()
	var name := folder.get_next()
	while name != "":
		if not name.begins_with("."):
			var path := dir_path.path_join(name)
			if folder.current_is_dir():
				_walk(path, suffix, acc)
			elif name.ends_with(suffix):
				acc.append(path)
		name = folder.get_next()
	folder.list_dir_end()


func _vec(mat: ShaderMaterial, param: String, color: Color) -> bool:
	var value: Variant = mat.get_shader_parameter(param)
	if value is Vector3:
		var v: Vector3 = value
		return absf(v.x - color.r) < 0.001 and absf(v.y - color.g) < 0.001 and absf(v.z - color.b) < 0.001
	return false


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02
