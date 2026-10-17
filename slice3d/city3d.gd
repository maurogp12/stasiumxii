extends Node3D

## Stasium XII 3D: walk a city in 3D (Crosshaven first).
##   godot --path . res://slice3d/city3d.tscn [-- --city=res://data/world/city3d/crosshaven.json --hour=10]
## Left click: walk. Right-drag or Q/E: orbit. Wheel: zoom. Middle-drag or
## WASD: pan. Space: follow the hero again. Shift: run. T: +1 hour. N: day/dusk/night.

const CityPlan := preload("res://slice3d/city/city_plan.gd")
const Builder := preload("res://slice3d/city/city_builder.gd")
const Env := preload("res://slice3d/city/city_env.gd")
const Nav := preload("res://slice3d/city/nav_grid.gd")
const Hero := preload("res://slice3d/city/hero3d.gd")
const Rig := preload("res://slice3d/city/camera_rig.gd")
const Life := preload("res://slice3d/city/city_life3d.gd")
const Hud := preload("res://slice3d/ui/city_hud.gd")

var city_path := "res://data/world/city3d/crosshaven.json"
var plan
var nav
var builder
var env
var hero
var rig
var life
var hud
var start_hour := 10.0
var start_class := "bastion"
var build_ms := 0
var _marker: MeshInstance3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--city="):
			city_path = a.trim_prefix("--city=")
		elif a.begins_with("--class="):
			start_class = a.trim_prefix("--class=")
		elif a.begins_with("--hour="):
			start_hour = float(a.trim_prefix("--hour="))
	var t0 := Time.get_ticks_msec()
	plan = CityPlan.load_city(city_path)
	if not plan.ok:
		push_error("city plan: %s" % [plan.errors])
		return
	nav = Nav.new()
	nav.setup(plan)
	builder = Builder.new()
	builder.name = "City"
	add_child(builder)
	builder.build(plan)
	env = Env.new()
	env.name = "Env"
	add_child(env)
	env.builder = builder
	env.setup(plan.city)
	life = Life.new()
	life.name = "Life"
	add_child(life)
	life.setup(plan, nav)
	hero = Hero.new()
	hero.name = "Hero"
	add_child(hero)
	hero.setup(plan, nav)
	hero.place(plan.cell_center(plan.spawn), plan.spawn_facing)
	rig = Rig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = hero
	var sz: Vector2 = plan.size_m()
	rig.bounds = Rect2(Vector2.ZERO, sz)
	# Start looking into town from just inside the gate.
	rig.yaw = rad_to_deg(atan2(-plan.spawn_facing.x, -plan.spawn_facing.y))
	rig.snap()
	_make_marker()
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(self)
	set_class(start_class)
	env.hour_changed.connect(_on_hour)
	env.set_hour(start_hour)
	build_ms = Time.get_ticks_msec() - t0
	print("city3d: %s built in %d ms (%s)" % [plan.city.get("name", ""), build_ms, builder.stats])


## Switch the hero's class: model (when the class has one) and spell bar.
func set_class(cls: String) -> void:
	hero.set_class(cls)
	hud.set_class(cls)


## Hotbar click outside combat: show the spell's motion (no rules run).
func preview_spell(sid: String) -> void:
	var d: Dictionary = SpellKits.spell(sid)
	var clip := "cast"
	if str(d.get("target", "")) == "enemy":
		clip = "attack_melee_1" if int(d.get("max_range", 1)) <= 1 else "attack_ranged"
	if str(d.get("engine_on_connect", "")).contains("push") or sid in ["shoulder", "bash"]:
		clip = "push"
	if str(d.get("move_mode", "")) == "teleport":
		clip = "dodge"
	hero.play_once(clip)


func _on_hour(h: float) -> void:
	life.set_hour(h)
	if hud != null:
		hud.set_hour(h)


func _make_marker() -> void:
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.5
	_marker.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.35)
	m.emission_energy_multiplier = 1.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = m
	_marker.visible = false
	add_child(_marker)


func walk_to(p: Vector2) -> bool:
	var ok: bool = hero.walk_to(p)
	if ok:
		var end: Vector2 = hero.path[hero.path.size() - 1]
		_marker.position = Vector3(end.x, plan.ground_y(end) + 0.05, end.y)
		_marker.visible = true
		rig.follow = true
	return ok


func _process(_delta: float) -> void:
	if hero == null:
		return
	hero.running = Input.is_key_pressed(KEY_SHIFT)
	builder.update_gates(hero.position)
	if not hero.moving:
		_marker.visible = false
	else:
		_marker.rotate_y(_delta * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Variant = rig.ground_point(event.position)
		if p != null:
			walk_to(p)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			env.set_hour(env.hour + 1.0)
		elif event.keycode == KEY_N:
			var h: float = env.hour
			env.set_hour(19.2 if h < 17.0 else (22.5 if h < 21.0 else 10.0))
