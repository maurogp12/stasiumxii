extends SceneTree

## Dev preview only: the 3D Ironjaw model (units/models/ironjaw_model.gd)
## turned to four sides on a lit plinth, next to his current painted sheet.
## xvfb-run godot --path . -s res://tests/shot_ironjaw_3d.gd -- <out_dir>

const ANGLES := [0.0, 90.0, 180.0, -90.0, 35.0]

var _out := "user://"
var _frames := 0
var _model: IronjawModel
var _cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	root.size = Vector2i(960, 720)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.085, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.75
	disc.height = 0.1
	floor_mesh.mesh = disc
	floor_mesh.position = Vector3(0, -0.05, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.25, 0.19)
	floor_mesh.material_override = fm
	world.add_child(floor_mesh)
	_model = IronjawModel.new()
	world.add_child(_model)
	_cam = Camera3D.new()
	_cam.fov = 30
	_cam.position = Vector3(0, 1.05, 4.2)
	world.add_child(_cam)
	_cam.look_at(Vector3(0, 0.45, 0), Vector3.UP)


func _process(_delta: float) -> bool:
	_frames += 1
	var idx := (_frames - 1) / 6
	var sub := (_frames - 1) % 6
	if idx >= ANGLES.size():
		return true
	if sub == 0:
		_model.rotation_degrees.y = float(ANGLES[idx])
	elif sub == 5:
		root.get_texture().get_image().save_png(_out.path_join("ironjaw3d_%d.png" % idx))
	return false
