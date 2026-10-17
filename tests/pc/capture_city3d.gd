extends SceneTree

## 3D city stills and the walk clip (media, not a test).
##   XDG_DATA_HOME=<scratch> xvfb-run -a -s "-screen 0 1920x1080x24" godot \
##     --rendering-driver opengl3 --audio-driver Dummy --path . \
##     --resolution 1920x1080 -s res://tests/pc/capture_city3d.gd -- --out=<dir> [--set=stills|clip|quick]
## Stills: wide views by day and dusk, the south gate and plaza, landmarks,
## the river and bridges, the W crafts quarter, plots, night lamps.
## Clip: JPEG frames at 30 fps of the hero walking in from the south gate.

const SCENE := preload("res://slice3d/city3d.tscn")

var _out := "/tmp/city3d"
var _set := "stills"
var m


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--set="):
			_set = a.trim_prefix("--set=")
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_go")


func _go() -> void:
	m = SCENE.instantiate()
	root.add_child(m)
	await _frames(3)
	m.hud.visible = true
	match _set:
		"quick":
			await _quick()
		"gate":
			await _gatecheck()
		"hero":
			await _herocheck()
		"keyart":
			await _keyart()
			await _keyart(18.6, "00_keyart_wide_dusk.png")
		"classes":
			await _classcheck()
		"ironjaw":
			await _ironjaw()
		"lineup":
			await _lineup()
		"terrain":
			await _terraincheck()
		"clip":
			await _clip()
		_:
			await _stills()
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name))
	print("saved ", name)


func _view(focus: Vector3, yaw: float, pitch: float, dist: float) -> void:
	m.rig.follow = false
	m.rig.focus = focus
	m.rig.yaw = yaw
	m.rig.pitch = pitch
	m.rig.distance = dist
	m.rig._place()


func _piece(kind: String) -> Vector3:
	for pc in m.plan.pieces:
		if str(pc["kind"]) == kind:
			return Vector3(pc["center"].x, 0, pc["center"].y)
	return Vector3.ZERO


func _quick() -> void:
	m.env.set_hour(10.0)
	await _grab("q_spawn.png")
	var c: Vector2 = m.plan.size_m() * 0.5
	_view(Vector3(c.x, 0, c.y), 45, 48, 330)
	await _grab("q_wide.png")


func _stills() -> void:
	var c: Vector2 = m.plan.size_m() * 0.5
	var mid := Vector3(c.x - 10, 0, c.y - 10)
	m.env.set_hour(10.5)
	_view(mid, 45, 42, 300)
	await _grab("01_wide_day.png")
	m.env.set_hour(19.3)
	await _grab("02_wide_dusk.png")
	m.env.set_hour(22.5)
	await _grab("03_wide_night.png")
	m.env.set_hour(10.5)
	# The hero inside the south gate, looking into town.
	m.rig.follow = true
	m.rig.distance = 22.0
	m.rig.pitch = 48.0
	m.rig.snap()
	await _grab("04_south_gate_hero.png")
	var sg: Vector3 = Vector3.ZERO
	for g in m.builder.gate_doors:
		if g["id"] == "S":
			sg = g["center"]
	m.builder.update_gates(sg)
	for i in 90:
		await process_frame
	_view(sg, 225, 30, 34)
	await _grab("05_south_gate_doors_open.png")
	_view(_piece("fountain"), 45, 40, 70)
	await _grab("06_plaza.png")
	_view((_piece("townhall") + _piece("bank")) * 0.5, 20, 35, 80)
	await _grab("07_townhall_bank.png")
	_view(_piece("cathedral"), 70, 32, 90)
	await _grab("08_cathedral.png")
	_view(_piece("castle"), 30, 32, 110)
	await _grab("09_castle.png")
	_view(_piece("mill"), 120, 38, 60)
	await _grab("10_mill_crafts.png")
	_view(_piece("workshop_forge"), 45, 45, 60)
	await _grab("11_crafts_quarter.png")
	_view(_piece("plot_legendary"), 45, 42, 60)
	await _grab("12_plot_legendary.png")
	_view(_piece("gazebo"), 45, 42, 50)
	await _grab("13_gardens_gazebo.png")
	var br: Vector2 = m.plan.cell_center(m.plan.walk_over.keys()[0])
	_view(Vector3(br.x, 0, br.y), 60, 38, 45)
	await _grab("14_river_bridge.png")
	m.env.set_hour(21.5)
	_view(_piece("fountain"), 45, 40, 70)
	await _grab("15_plaza_night.png")
	m.env.set_hour(19.2)
	_view(sg, 20, 32, 38)
	await _grab("16_south_gate_dusk.png")


func _clip() -> void:
	m.env.set_hour(11.0)
	m.rig.distance = 17.0
	m.rig.pitch = 50.0
	m.rig.snap()
	var goal: Vector3 = _piece("fountain")
	m.walk_to(Vector2(goal.x + 4.0, goal.z + 4.0))
	var f := 0
	while m.hero.moving and f < 30 * 40:
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_jpg(_out.path_join("f%05d.jpg" % f), 0.85)
		f += 1
		await process_frame
	print("frames ", f)


func _gatecheck() -> void:
	m.env.set_hour(10.5)
	var sg: Vector3 = Vector3.ZERO
	for g in m.builder.gate_doors:
		if g["id"] == "S":
			sg = g["center"]
	_view(sg, 200, 35, 40)
	await _grab("g_south_gate.png")
	m.builder.update_gates(sg)
	for i in 120:
		await process_frame
	_view(sg, 20, 35, 40)
	await _grab("g_south_gate_open_inside.png")
	var c: Vector2 = m.plan.size_m() * 0.5
	_view(Vector3(c.x, 0, c.y), 45, 42, 300)
	await _grab("g_wide.png")


func _herocheck() -> void:
	m.env.set_hour(10.5)
	m.rig.distance = 9.0
	m.rig.pitch = 30.0
	m.rig.snap()
	await _grab("h_idle.png")
	var goal: Vector3 = _piece("fountain")
	m.walk_to(Vector2(goal.x, goal.z))
	for i in 40:
		await process_frame
	m.rig.snap()
	await _grab("h_walk.png")


## Framed like work/3d_cities/crosshaven/keyart/crosshaven_wide_day_CONCEPTO_.jpg:
## high 3/4 view from beyond the south gate, the castle at the top.
func _keyart(hour := 10.0, name := "00_keyart_wide_day.png") -> void:
	m.env.set_hour(hour)
	var castle := _piece("castle")
	var sg := Vector3.ZERO
	for g in m.builder.gate_doors:
		if g["id"] == "S":
			sg = g["center"]
	var d := Vector2(sg.x - castle.x, sg.z - castle.z).normalized()
	var mid := Vector3(m.plan.ring_center.x, 0, m.plan.ring_center.y) - Vector3(d.x, 0, d.y) * 8.0
	m.hud.visible = false
	m.rig.cam.fov = 38.0
	_view(mid, rad_to_deg(atan2(d.x, d.y)), 40, 290)
	await _grab(name)
	m.hud.visible = true


func _classcheck() -> void:
	m.env.set_hour(10.5)
	m.rig.distance = 8.0
	m.rig.pitch = 25.0
	m.rig.snap()
	await _grab("c_bastion_idle.png")
	m.preview_spell("bash")
	for i in 20:
		await process_frame
	await _grab("c_bastion_bash.png")
	m.set_class("kestrel")
	for i in 10:
		await process_frame
	await _grab("c_kestrel_hero_male.png")


func _ironjaw() -> void:
	m.env.set_hour(10.5)
	m.set_class("ironjaw")
	var f := _piece("fountain")
	m.hero.place(Vector2(f.x + 6.0, f.z + 6.0), Vector2(1, 1).normalized())
	m.rig.distance = 5.5
	m.rig.pitch = 14.0
	m.rig.yaw = rad_to_deg(m.hero.rotation.y) + 25.0
	m.rig.snap()
	for i in 10:
		await process_frame
	await _grab("ij_idle.png")
	m.hero.play_once("attack_melee_2")
	for i in 25:
		await process_frame
	await _grab("ij_attack.png")
	m.hero.play_once("sit")
	for i in 30:
		await process_frame
	await _grab("ij_sit_holster.png")
	m.hero._oneshot = false
	m.walk_to(Vector2(f.x + 16.0, f.z + 16.0))
	for i in 30:
		await process_frame
	m.rig.yaw = rad_to_deg(m.hero.rotation.y) + 25.0
	m.rig.snap()
	await _grab("ij_walk.png")


## The five class heroes side by side on the plaza (idle).
func _lineup() -> void:
	m.env.set_hour(10.5)
	var f := _piece("fountain")
	var base := Vector2(f.x + 7.0, f.z + 7.0)
	var side := Vector2(1, -1).normalized()
	var face := Vector2(1, 1).normalized()
	var HeroScript = load("res://slice3d/city/hero3d.gd")
	m.hero.visible = false
	var i := 0
	for cls in ["kestrel", "ironjaw", "mender", "gloam", "bastion"]:
		var h = HeroScript.new()
		m.add_child(h)
		h.setup(m.plan, m.nav)
		h.set_class(cls)
		h.place(base + side * (i - 2) * 1.6, face)
		i += 1
	m.hud.visible = false
	_view(Vector3(base.x, 1.0, base.y), rad_to_deg(atan2(face.x, face.y)), 12, 9.5)
	for k in 20:
		await process_frame
	await _grab("17_class_lineup.png")


func _terraincheck() -> void:
	m.env.set_hour(10.5)
	_view(_piece("fountain") + Vector3(6, 0, 6), 45, 40, 26)
	await _grab("t_plaza.png")
	var sg := Vector3.ZERO
	for g in m.builder.gate_doors:
		if g["id"] == "S":
			sg = g["center"]
	_view(sg, 200, 40, 30)
	await _grab("t_gate_outside.png")
	var br: Vector2 = m.plan.bridges[0]["center"]
	_view(Vector3(br.x, 0, br.y), 60, 42, 26)
	await _grab("t_river.png")
	_view(_piece("cathedral") + Vector3(0, 0, 14), 20, 50, 30)
	await _grab("t_street.png")
