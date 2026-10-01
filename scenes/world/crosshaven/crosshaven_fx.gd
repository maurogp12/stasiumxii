extends Node

## Screen grade, contact shadows, drifting clouds, birds, leaves, and pollen.
## post_fx: bloom, warmth, vignette, depth haze.
## sway_shadows: contact shadows, ambient occlusion, cloud shadows.
## animations: birds, falling leaves, pollen, critters.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

var _grade: ColorRect
var _shadows: Sprite2D
var _shadows_b: Sprite2D
var _contacts: Node2D
var _critters: Node2D
var _pollen: CPUParticles2D
var _fall: CPUParticles2D
var _env: WorldEnvironment
var _settings: VisualSettings
var _world: Node2D
var _hdr_before := false


class ContactBlob extends Node2D:
	var rx: float = 12.0
	var ry: float = 4.5
	var lift_ao: bool = false

	func _draw() -> void:
		_ellipse(rx, ry, Color(0, 0, 0, 0.26), Vector2.ZERO)
		if lift_ao:
			_ellipse(rx * 0.68, ry * 0.5, Color(0, 0, 0, 0.22), Vector2(0, -ry * 1.7))

	func _ellipse(erx: float, ery: float, col: Color, at: Vector2) -> void:
		var pts := PackedVector2Array()
		pts.resize(14)
		for i in 14:
			var a := TAU * float(i) / 14.0
			pts[i] = at + Vector2(cos(a) * erx, sin(a) * ery)
		draw_colored_polygon(pts, col)


func setup(world: Node2D, settings: VisualSettings) -> void:
	_settings = settings
	_world = world
	var vp := world.get_viewport()
	if vp != null:
		_hdr_before = vp.use_hdr_2d
		vp.use_hdr_2d = true
	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.5
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.62
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 0.8)
	env.set_glow_level(2, 0.4)
	env.set_glow_level(3, 0.0)
	env.set_glow_level(4, 0.0)
	env.set_glow_level(5, 0.0)
	env.set_glow_level(6, 0.0)
	_env.environment = env
	world.add_child(_env)
	var layer := CanvasLayer.new()
	layer.layer = 6
	world.add_child(layer)
	_grade = ColorRect.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader: Shader = load("res://scenes/world/crosshaven/crosshaven_grade.gdshader")
	mat.shader = shader
	_grade.material = mat
	layer.add_child(_grade)
	_shadows = _cloud_layer("cloud_shadow_a", Color(0.25, 0.3, 0.4, 0.20), Vector2(-800, -400))
	_shadows_b = _cloud_layer("cloud_shadow_b", Color(0.22, 0.28, 0.38, 0.14), Vector2(-600, -200))
	if _shadows != null:
		world.add_child(_shadows)
	if _shadows_b != null:
		world.add_child(_shadows_b)
	_contacts = Node2D.new()
	_contacts.name = "ContactShadows"
	world.add_child(_contacts)
	_critters = Node2D.new()
	_critters.name = "Critters"
	world.add_child(_critters)
	var mote := _soft_dot()
	_pollen = _air_particles(22, Color(0.98, 0.90, 0.45, 0.55), mote, false)
	_fall = _air_particles(12, Color(0.72, 0.42, 0.18, 0.75), mote, true)
	world.add_child(_pollen)
	world.add_child(_fall)
	settings.bind(self, "post_fx", _on_post_fx)
	settings.bind(self, "sway_shadows", _on_sway_shadows)
	settings.bind(self, "animations", _on_animations)


func effect_on(flag: String) -> bool:
	if flag == "post_fx":
		return _grade != null and _grade.visible
	if flag == "sway_shadows":
		return _contacts != null and _contacts.visible
	if flag == "animations":
		return _critters != null and _critters.visible
	return false


func _cloud_layer(anim_id: String, tint: Color, at: Vector2) -> Sprite2D:
	var tex := Art.anim_texture(anim_id)
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 4200, 2800)
	sprite.position = at
	sprite.modulate = tint
	sprite.z_as_relative = false
	sprite.z_index = 2500
	return sprite


func _air_particles(amount: int, col: Color, tex: Texture2D, tumbling: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.z_as_relative = false
	p.z_index = 2100
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(520, 300)
	p.direction = Vector2(0.35, 1.0)
	p.spread = 28.0
	p.gravity = Vector2(6, 12)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = col
	p.texture = tex
	if tumbling:
		p.angular_velocity_min = -90.0
		p.angular_velocity_max = 90.0
		p.gravity = Vector2(18, 28)
		p.initial_velocity_min = 14.0
		p.initial_velocity_max = 36.0
	p.emitting = true
	return p


func _soft_dot() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(float(x) - 3.5, float(y) - 3.5).length() / 3.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _on_post_fx(on: bool) -> void:
	if _grade != null:
		_grade.visible = on
	if _env != null and _env.environment != null:
		_env.environment.glow_enabled = on


func _on_sway_shadows(on: bool) -> void:
	if _shadows != null:
		_shadows.visible = on
	if _shadows_b != null:
		_shadows_b.visible = on
	if _contacts != null:
		_contacts.visible = on


func _on_animations(on: bool) -> void:
	if _critters != null:
		_critters.visible = on
	if _pollen != null:
		_pollen.visible = on
		_pollen.emitting = on
	if _fall != null:
		_fall.visible = on
		_fall.emitting = on


func restock(zone: WorldZone) -> void:
	for child in _critters.get_children():
		child.queue_free()
	for child in _contacts.get_children():
		child.queue_free()
	_add_contacts(zone)
	var spots: Array[Vector2i] = []
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if not zone.passable_at(cell) or not zone.exit_link(cell).is_empty():
				continue
			var away := absi(cell.x - zone.spawn.x) + absi(cell.y - zone.spawn.y)
			if away >= 5 and away <= 14:
				spots.append(cell)
	if not spots.is_empty():
		_add_critter(zone, spots[spots.size() / 3], "butterfly_blue", 22.0)
		_add_critter(zone, spots[spots.size() * 2 / 3], "butterfly_yellow", 18.0)
		var town := false
		for poi in zone.points_of_interest:
			if str(poi.get("kind", "")) == "town":
				town = true
		if town:
			_add_critter(zone, spots[spots.size() / 2], "chicken_walk", 11.0)
	_add_bird(zone, 0.35, 70.0)
	_add_bird(zone, 0.62, 58.0)


func _add_contacts(zone: WorldZone) -> void:
	for record in zone.props:
		var footprint: Array = record["footprint"]
		if footprint.is_empty():
			continue
		var south := Vector2i(int(footprint[0]["x"]), int(footprint[0]["y"]))
		for c in footprint:
			var cell := Vector2i(int(c["x"]), int(c["y"]))
			if cell.x + cell.y > south.x + south.y:
				south = cell
		var kind := str(record["type"])
		var blob := ContactBlob.new()
		var size := _shadow_size(kind, footprint.size())
		blob.rx = size.x
		blob.ry = size.y
		blob.lift_ao = size.z > 0.5
		blob.position = BoardVisualSort.cell_to_local(south, float(zone.height_at(south))) + Vector2(0, 16)
		blob.z_as_relative = false
		blob.z_index = (south.x + south.y) * BoardVisualSort.TILE_Z_SCALE + 1
		_contacts.add_child(blob)


func _shadow_size(kind: String, cells: int) -> Vector3:
	if _is_building(kind) or cells >= 4:
		return Vector3(28, 10, 1)
	if kind.contains("tree"):
		return Vector3(20, 7, 0)
	if kind == "fence" or kind.contains("hedge") or kind.contains("wall"):
		return Vector3(18, 5.5, 0)
	return Vector3(12, 4.5, 0)


func _is_building(kind: String) -> bool:
	for token in ["cottage", "house", "mill", "tavern", "barn", "gate", "spire", "tower", "bakery", "smithy", "hut"]:
		if kind.contains(token):
			return true
	return false


func _add_bird(zone: WorldZone, y_frac: float, speed: float) -> void:
	var sprite := Art.make_loop("bird")
	if sprite == null:
		return
	sprite.position = Vector2.ZERO
	var row := clampi(int(float(zone.height) * y_frac), 0, zone.height - 1)
	var start := BoardVisualSort.cell_to_local(Vector2i(0, row), 0.0)
	var end := BoardVisualSort.cell_to_local(Vector2i(maxi(zone.width - 1, 0), row), 0.0)
	var body := Node2D.new()
	body.position = Vector2(minf(start.x, end.x) - 40.0, start.y - 80.0)
	body.z_as_relative = false
	body.z_index = 2400
	body.set_meta("kind", "bird")
	body.set_meta("speed", speed)
	body.set_meta("base_y", body.position.y)
	body.set_meta("phase", y_frac * 5.0)
	body.set_meta("min_x", minf(start.x, end.x) - 80.0)
	body.set_meta("max_x", maxf(start.x, end.x) + 80.0)
	body.add_child(sprite)
	_critters.add_child(body)


func _add_critter(zone: WorldZone, cell: Vector2i, anim_id: String, speed: float) -> void:
	var sprite := Art.make_loop(anim_id)
	if sprite == null:
		return
	var body := Node2D.new()
	body.position = BoardVisualSort.cell_to_local(cell, float(zone.height_at(cell)))
	body.z_as_relative = false
	body.z_index = (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS
	body.set_meta("kind", "critter")
	body.set_meta("origin", body.position)
	body.set_meta("speed", speed)
	body.set_meta("phase", float(cell.x * 13 + cell.y * 7))
	sprite.position = Vector2(0, -6)
	body.add_child(sprite)
	_critters.add_child(body)


func _exit_tree() -> void:
	if _world != null and is_instance_valid(_world):
		var vp := _world.get_viewport()
		if vp != null:
			vp.use_hdr_2d = _hdr_before
	if _settings != null:
		_settings.detach()


func _process(delta: float) -> void:
	if _shadows != null and _shadows.visible:
		_shadows.region_rect.position += Vector2(18.0, 6.0) * delta
	if _shadows_b != null and _shadows_b.visible:
		_shadows_b.region_rect.position += Vector2(9.0, 3.0) * delta
	_follow_air()
	if _critters == null or not _critters.visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for body in _critters.get_children():
		if str(body.get_meta("kind", "critter")) == "bird":
			_step_bird(body as Node2D, delta, t)
		else:
			var origin: Vector2 = body.get_meta("origin")
			var phase: float = float(body.get_meta("phase"))
			var speed: float = float(body.get_meta("speed"))
			body.position = origin + Vector2(sin(t * 0.7 + phase) * speed, cos(t * 0.45 + phase) * speed * 0.35)


func _step_bird(body: Node2D, delta: float, t: float) -> void:
	var speed: float = float(body.get_meta("speed"))
	var base_y: float = float(body.get_meta("base_y"))
	var phase: float = float(body.get_meta("phase"))
	var min_x: float = float(body.get_meta("min_x"))
	var max_x: float = float(body.get_meta("max_x"))
	var x := body.position.x + speed * delta
	if x > max_x:
		x = min_x
	body.position = Vector2(x, base_y + sin(t * 1.4 + phase) * 10.0)


func _follow_air() -> void:
	if _world == null:
		return
	var cam: Object = _world.get("camera")
	if cam == null:
		return
	var at: Vector2 = (cam as Node2D).position
	if _pollen != null:
		_pollen.position = at
	if _fall != null:
		_fall.position = at
