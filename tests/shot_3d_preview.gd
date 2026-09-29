extends SceneTree

## Dev preview only (not a test suite, not shipped): what STASIUM looks like
## in 3D with the characters kept as their painted art (HD-2D style).
## Real 3D arena built from the Crosshaven tags + the same diamond tiles
## (unwarped onto block tops), raised blocks for elevation, water, props as
## standing cards, a warm sun with real shadows, and the five champions as
## their current painted sprites. Each champion shows the facing that matches
## the camera, like the Inventory turntable.
## xvfb-run godot --path . -s res://tests/shot_3d_preview.gd -- <out_dir>

const MAP := "crosshaven"
const TAGS := "res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json"
const FACINGS: Array[String] = ["s", "e", "n", "w"]
const STEP := 0.32

var _out := "user://"
var _frames := 0
var _cam: Camera3D
var _world: Node3D
var _units: Array = []  # [{sprite, class, yaw}]
var _top_cache: Dictionary = {}
var _shots: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	root.size = Vector2i(960, 720)
	_world = Node3D.new()
	root.add_child(_world)
	_build_environment()
	_build_board()
	_skirt()
	_place_champions()
	_cam = Camera3D.new()
	_cam.fov = 38
	_world.add_child(_cam)
	# [name, yaw deg (0 = the current 2D view), pitch deg, distance, look-at]
	_shots = [
		["3d_dofus_angle", 45.0, 38.0, 17.0, Vector3(7, 0, 7)],
		["3d_low_angle", 20.0, 24.0, 11.0, Vector3(7, 0.4, 8)],
		["3d_turned", 150.0, 34.0, 15.0, Vector3(7, 0, 7)],
		["3d_closeup", 45.0, 16.0, 6.5, Vector3(7.2, 0.9, 8.6)],
	]


func _process(_delta: float) -> bool:
	_frames += 1
	var idx := (_frames - 1) / 8
	var sub := (_frames - 1) % 8
	if idx >= _shots.size():
		return true
	var shot: Array = _shots[idx]
	if sub == 0:
		_aim(float(shot[1]), float(shot[2]), float(shot[3]), shot[4])
	elif sub == 7:
		root.get_texture().get_image().save_png(_out.path_join("%s.png" % shot[0]))
	return false


func _aim(yaw_deg: float, pitch_deg: float, dist: float, target: Vector3) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	# yaw 45 looks down the board diagonal, like the isometric view.
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = target + dir * dist
	_cam.look_at(target, Vector3.UP)
	# Each champion shows the painted facing nearest to the camera view.
	for u in _units:
		var sprite: Sprite3D = u["sprite"]
		var to_cam := _cam.global_position - sprite.global_position
		var cam_yaw := atan2(to_cam.x, to_cam.z)
		var rel := wrapf(float(u["yaw"]) - cam_yaw, -PI, PI)
		var k := posmod(int(round(rel / (PI / 2.0))), 4)
		# rel 0 → facing the camera ("s"); +90° → turned to screen right ("e").
		var facing: String = ["s", "e", "n", "w"][k]
		sprite.texture = load("res://art/characters/%s/%s_%s.png" % [u["class"], u["class"], facing])


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.38, 0.66)
	sky_mat.sky_horizon_color = Color(0.62, 0.7, 0.8)
	sky_mat.sky_energy_multiplier = 0.8
	sky_mat.ground_horizon_color = Color(0.3, 0.36, 0.3)
	sky_mat.ground_bottom_color = Color(0.2, 0.18, 0.14)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.78)
	env.ambient_light_energy = 0.55
	env.tonemap_exposure = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.08
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = false
	env.fog_light_color = Color(0.9, 0.84, 0.72)
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.light_energy = 1.25
	sun.shadow_opacity = 0.85
	sun.shadow_blur = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-38, -60, 0)
	_world.add_child(sun)


func _build_board() -> void:
	var tags: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TAGS))
	var dress := KoliseoArt.dress_for(MAP)
	for c in tags["cells"]:
		var cell := Vector2i(int(c["x"]), int(c["y"]))
		var terrain := str(c["terrain"])
		var elev := int(c["elevation"])
		var h := 0.25 + elev * STEP
		if terrain == "water":
			h = 0.12
		var tex := KoliseoArt.terrain_texture_at(terrain, elev, dress, cell)
		var top := _unwarp(tex)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, h, 1.0)
		mesh.mesh = box
		mesh.position = Vector3(cell.x + 0.5, h * 0.5, cell.y + 0.5)
		var side := StandardMaterial3D.new()
		side.albedo_color = Color(0.38, 0.28, 0.18) if terrain != "water" else Color(0.2, 0.3, 0.38)
		side.roughness = 0.95
		mesh.material_override = side
		_world.add_child(mesh)
		# Painted top face: the same diamond tile, unwarped to a square.
		var face := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(1.0, 1.0)
		face.mesh = quad
		face.position = Vector3(cell.x + 0.5, h + 0.001, cell.y + 0.5)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(top) if top != null else null
		mat.roughness = 0.85 if terrain != "water" else 0.1
		mat.metallic_specular = 0.2 if terrain != "water" else 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face.material_override = mat
		_world.add_child(face)
		for prop in c.get("paint_only", []):
			var ptex := KoliseoArt.prop_texture(str(prop), dress)
			if ptex == null or str(prop) == "floor_seal":
				continue
			var card := Sprite3D.new()
			card.texture = ptex
			card.pixel_size = 0.016
			card.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			card.shaded = false
			card.modulate = Color(0.92, 0.92, 0.9)
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			card.offset = Vector2(0, ptex.get_height() * 0.5 - 6)
			card.position = Vector3(cell.x + 0.5, h, cell.y + 0.5)
			_world.add_child(card)


func _skirt() -> void:
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	g.mesh = plane
	g.position = Vector3(7.5, 0.0, 7.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.25, 0.13)
	m.roughness = 1.0
	g.material_override = m
	_world.add_child(g)


func _place_champions() -> void:
	# Kestrel and Ironjaw face off on the pitch; the rest look on.
	var roster := [
		["kestrel", Vector2i(6, 8), 135.0],
		["ironjaw", Vector2i(8, 6), -45.0],
		["mender", Vector2i(5, 9), 135.0],
		["gloam", Vector2i(9, 5), -45.0],
		["bastion", Vector2i(8, 9), 90.0],
	]
	var tags: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TAGS))
	var heights := {}
	for c in tags["cells"]:
		var terrain := str(c["terrain"])
		heights[Vector2i(int(c["x"]), int(c["y"]))] = 0.12 if terrain == "water" else 0.25 + int(c["elevation"]) * STEP
	for r in roster:
		var cls := str(r[0])
		var cell: Vector2i = r[1]
		var sprite := Sprite3D.new()
		sprite.texture = load("res://art/characters/%s/%s_s.png" % [cls, cls])
		sprite.pixel_size = 0.0105
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.offset = Vector2(0, 80 - 8)
		sprite.position = Vector3(cell.x + 0.5, float(heights.get(cell, 0.25)), cell.y + 0.5)
		_world.add_child(sprite)
		_units.append({"sprite": sprite, "class": cls, "yaw": deg_to_rad(float(r[2]))})


## Diamond tile (top 64×32 of the sheet) → square texture for a block top.
func _unwarp(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var key := tex.resource_path
	if _top_cache.has(key):
		return _top_cache[key]
	var src := tex.get_image()
	if src == null or src.is_empty():
		return null
	if src.is_compressed():
		src.decompress()
	var n := 64
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var w := src.get_width()
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / n
			var v := (float(y) + 0.5) / n
			var sx := clampi(int(w * 0.5 + (u - v) * w * 0.5), 0, w - 1)
			var sy := clampi(int((u + v) * w * 0.25), 0, src.get_height() - 1)
			var col := src.get_pixel(sx, sy)
			col.a = 1.0
			out.set_pixel(x, y, col)
	_top_cache[key] = out
	return out


func _average(img: Image) -> Color:
	if img == null:
		return Color(0.4, 0.35, 0.25)
	var acc := Color(0, 0, 0)
	var n := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			acc += img.get_pixel(x, y)
			n += 1
	return Color(acc.r / n, acc.g / n, acc.b / n)
