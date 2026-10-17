extends RefCounted

## Loads .glb models at run time (GLTFDocument), so new models dropped into
## res://art/3d/ work without an editor import pass. Each file is parsed
## once; callers get a fresh copy. Returns null when the file is missing.

static var _cache := {}


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


static func instance(path: String) -> Node3D:
	if _cache.has(path):
		var proto: Node3D = _cache[path]
		return proto.duplicate() if proto != null else null
	var node: Node3D = null
	if ResourceLoader.exists(path) and path.get_extension() != "glb":
		var ps: PackedScene = load(path)
		node = ps.instantiate()
	elif FileAccess.file_exists(path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(path, state)
		if err == OK:
			node = doc.generate_scene(state)
			if not "/characters/" in path:
				add_missing_normals(node)
				double_sided(node)
				if "impostor" in path:
					unshaded(node, 1.0)
	_cache[path] = node
	return node.duplicate() if node != null else null


## Animations from another .glb of the same rig (e.g. a walk clip), keyed by
## their name in that file.
static func animations(path: String) -> Dictionary:
	var out := {}
	var n := instance(path)
	if n == null:
		return out
	var ap := find_player(n)
	if ap != null:
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for a in lib.get_animation_list():
				out[str(a)] = lib.get_animation(a)
	n.free()
	return out


## Kit meshes from image-to-3D tools often have some faces wound the wrong
## way; drawing both sides hides the holes until the art is cleaned.
static func double_sided(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				var d: BaseMaterial3D = m.duplicate()
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				# Generated kits ship metallic = 1 with a metal map; stone and
				# timber read better as dielectric under our lighting.
				d.metallic = 0.0
				d.metallic_specular = 0.35
				# COLOR_0 on kit meshes is data (e.g. tree wind weights), never tint.
				d.vertex_color_use_as_albedo = false
				mesh.surface_set_material(i, d)
	for c in n.get_children():
		double_sided(c)


## Procedural kit pieces may ship without normals; light needs them.
static func add_missing_normals(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
		var mi := n as MeshInstance3D
		var src: ArrayMesh = mi.mesh
		var need := false
		for i in src.get_surface_count():
			if (src.surface_get_format(i) & Mesh.ARRAY_FORMAT_NORMAL) == 0:
				need = true
		if need:
			var out := ArrayMesh.new()
			for i in src.get_surface_count():
				var st := SurfaceTool.new()
				st.create_from(src, i)
				if (src.surface_get_format(i) & Mesh.ARRAY_FORMAT_NORMAL) == 0:
					st.generate_normals()
				st.commit(out)
				out.surface_set_material(i, src.surface_get_material(i))
			mi.mesh = out
	for c in n.get_children():
		add_missing_normals(c)


## Billboards (tree impostors) read best unlit, slightly darkened.
static func unshaded(n: Node, tint: float) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				(m as BaseMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				(m as BaseMaterial3D).albedo_color = Color(tint, tint, tint)
	for c in n.get_children():
		unshaded(c, tint)


static func find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := find_player(c)
		if r != null:
			return r
	return null
