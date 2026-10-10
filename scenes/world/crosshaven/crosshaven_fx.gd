extends Node

## Screen grade, contact shadows, drifting clouds, birds, leaves, and pollen.
## post_fx: bloom, warmth, vignette, depth haze.
## sway_shadows: contact shadows, ambient occlusion, cloud shadows.
## animations: birds, falling leaves, pollen, critters.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

var _grade: ColorRect
var _shadows: Sprite2D
var _cloud_drift := Vector2.ZERO
var _contacts: Node2D
var _critters: Node2D
var _pollen: CPUParticles2D
var _fall: CPUParticles2D
var _grade_mat: ShaderMaterial
var _settings: VisualSettings
var _world: Node2D


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
		pts.resize(8)
		for i in 8:
			var a := TAU * float(i) / 8.0
			pts[i] = at + Vector2(cos(a) * erx, sin(a) * ery)
		draw_colored_polygon(pts, col)


func setup(world: Node2D, settings: VisualSettings) -> void:
	_settings = settings
	_world = world
	var layer := CanvasLayer.new()
	layer.layer = 6
	world.add_child(layer)
	_grade = ColorRect.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_mat = ShaderMaterial.new()
	var shader: Shader = load("res://scenes/world/crosshaven/crosshaven_grade.gdshader")
	_grade_mat.shader = shader
	_grade.material = _grade_mat
	layer.add_child(_grade)
	# One drifting cloud sheet. A second fullscreen layer cost more than it added.
	_shadows = _cloud_layer("cloud_shadow_a", Color(0.22, 0.28, 0.38, 0.16), Vector2(-800, -400))
	if _shadows != null:
		world.add_child(_shadows)
	_contacts = Node2D.new()
	_contacts.name = "ContactShadows"
	world.add_child(_contacts)
	_critters = Node2D.new()
	_critters.name = "Critters"
	world.add_child(_critters)
	var mote := _soft_dot()
	_pollen = _air_particles(12, Color(0.98, 0.90, 0.45, 0.55), mote, false)
	_fall = _air_particles(8, Color(0.72, 0.42, 0.18, 0.75), mote, true)
	world.add_child(_pollen)
	world.add_child(_fall)
	settings.bind(self, "post_fx", _on_post_fx)
	settings.bind(self, "sway_shadows", _on_sway_shadows)
	settings.bind(self, VisualSettings.MOTION, _on_animations)
	settings.bind(self, VisualSettings.PERFORMANCE, _on_performance)


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


func _on_sway_shadows(on: bool) -> void:
	if _shadows != null:
		_shadows.visible = on and not _still()
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


## Performance mode: no cloud sheet, and no birds or critters at all (freed,
## not hidden). Contact shadows stay: they are still drawings.
func _on_performance(on: bool) -> void:
	if _shadows != null:
		_shadows.visible = not on and _settings != null and _settings.enabled("sway_shadows")
	if on and _critters != null:
		for child in _critters.get_children():
			child.free()


func _still() -> bool:
	return _settings != null and _settings.performance


## Birds and critters alive now (0 in performance mode).
func critter_count() -> int:
	return _critters.get_child_count() if _critters != null else 0


func clouds_on() -> bool:
	return _shadows != null and _shadows.visible


func air_on() -> bool:
	return (_pollen != null and _pollen.emitting) or (_fall != null and _fall.emitting)


func restock(zone: WorldZone) -> void:
	for child in _critters.get_children():
		child.queue_free()
	for child in _contacts.get_children():
		child.queue_free()
	_add_contacts(zone)
	if _still():
		return
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
		if not _casts_shadow(kind, footprint.size()):
			continue
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


func _casts_shadow(kind: String, cells: int) -> bool:
	if _is_building(kind) or kind.contains("tree") or kind == "fence" or kind.contains("hedge") or kind.contains("wall"):
		return true
	return cells >= 2


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
	if _settings != null:
		_settings.detach()


func _process(delta: float) -> void:
	_sync_grade()
	if _shadows != null and _shadows.visible:
		_cloud_drift += Vector2(14.0, 5.0) * delta
		_follow_clouds()
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


func _sync_grade() -> void:
	if _grade_mat == null or _world == null:
		return
	var rain_amt := 0.0
	var weather_node: Object = _world.get("weather")
	if weather_node != null:
		var amounts: Variant = weather_node.get("_amount")
		if typeof(amounts) == TYPE_DICTIONARY:
			rain_amt = float((amounts as Dictionary).get("light_rain", 0.0))
	# Clear stays warm. Rain drops the golden multiply so the tint can cool it.
	_grade_mat.set_shader_parameter("warmth", clampf(1.0 - rain_amt, 0.0, 1.0))
	var snow_level: Variant = _world.get("snow_level")
	_grade_mat.set_shader_parameter("snow_grade", clampf(float(snow_level), 0.0, 1.0) if snow_level != null else 0.0)


## Keep the cloud sheet around the camera. Its edge used to show past the
## map corner as a hard darker rectangle on the sea. The sheet moves in whole
## texture tiles and the region offset follows, so the clouds stay put in the world.
func _follow_clouds() -> void:
	var at := Vector2(-800, -400)
	var cam: Object = _world.get("camera") if _world != null else null
	if cam != null:
		var size := _shadows.region_rect.size
		var tile := Vector2(256, 256)
		if _shadows.texture != null:
			tile = _shadows.texture.get_size()
		var corner := (cam as Node2D).position - size * 0.5
		at = Vector2(floorf(corner.x / tile.x) * tile.x, floorf(corner.y / tile.y) * tile.y)
	_shadows.position = at
	_shadows.region_rect.position = at + _cloud_drift


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
