extends SceneTree
# Behind-the-scenes iso render of a GLB (not part of the game).
var out := "out"
var glb := "cathedral.glb"
var size := 1024
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--glb="): glb = a.trim_prefix("--glb=")
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path("res://" + glb), st)
	if err != OK: print("load fail ", err); quit(1); return
	var model: Node3D = doc.generate_scene(st)
	var vp := SubViewport.new(); vp.size = Vector2i(size, size); vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.own_world_3d = true
	root.add_child(vp)
	var pivot := Node3D.new(); vp.add_child(pivot); pivot.add_child(model)
	# fit: centre on AABB, scale to unit height
	var aabb := _aabb(model)
	var s: float = 2.0 / max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	model.scale = Vector3.ONE * s
	model.position = -(aabb.get_center()) * s + Vector3(0, aabb.size.y * s * 0.5, 0)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 3.2
	# 2:1 dimetric: pitch atan(0.5) ~ 26.565 deg below horizon, yaw 45
	cam.rotation_degrees = Vector3(-26.565, 45, 0)
	cam.position = Vector3(10, 10 * tan(deg_to_rad(26.565)) * sqrt(2.0) + 1.0, 10)
	vp.add_child(cam); cam.look_at(Vector3(0, 1.0, 0))
	var sun := DirectionalLight3D.new(); sun.light_color = Color("fff0c8"); sun.light_energy = 2.4
	sun.rotation_degrees = Vector3(-50, 135, 0); vp.add_child(sun)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("5a6fa0"); e.ambient_light_energy = 1.3
	e.background_mode = Environment.BG_CLEAR_COLOR
	env.environment = e; vp.add_child(env)
	for i in 4:
		pivot.rotation_degrees.y = i * 90
		for f in 4: await process_frame
		var img := vp.get_texture().get_image()
		img.save_png("%s/view_%d.png" % [out, i * 90])
		print("SAVED ", i * 90)
	quit()
func _aabb(n: Node) -> AABB:
	var box := AABB(); var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
		if first: box = b; first = false
		else: box = box.merge(b)
	return box
