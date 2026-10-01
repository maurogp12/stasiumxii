extends Node

## Optional screen grade, drifting cloud shadows, and a few ambient critters.
## Each one is registered on a VisualSettings flag.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

var _grade: ColorRect
var _shadows: Sprite2D
var _critters: Node2D
var _settings: VisualSettings


func setup(world: Node2D, settings: VisualSettings) -> void:
	_settings = settings
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
	_shadows = Sprite2D.new()
	var tex := Art.anim_texture("cloud_shadow_a")
	if tex == null:
		tex = Art.anim_texture("cloud_shadow_b")
	_shadows.texture = tex
	_shadows.centered = false
	_shadows.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_shadows.region_enabled = true
	_shadows.region_rect = Rect2(0, 0, 4200, 2800)
	_shadows.position = Vector2(-800, -400)
	_shadows.modulate = Color(0.25, 0.3, 0.4, 0.22)
	_shadows.z_as_relative = false
	_shadows.z_index = 2500
	world.add_child(_shadows)
	_critters = Node2D.new()
	_critters.name = "Critters"
	world.add_child(_critters)
	settings.bind(self, "post_fx", _on_post_fx)
	settings.bind(self, "sway_shadows", _on_sway_shadows)
	settings.bind(self, "animations", _on_animations)


func _on_post_fx(on: bool) -> void:
	if _grade != null:
		_grade.visible = on


func _on_sway_shadows(on: bool) -> void:
	if _shadows != null:
		_shadows.visible = on


func _on_animations(on: bool) -> void:
	if _critters != null:
		_critters.visible = on


func restock(zone: WorldZone) -> void:
	for child in _critters.get_children():
		child.queue_free()
	var spots: Array[Vector2i] = []
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if not zone.passable_at(cell) or not zone.exit_link(cell).is_empty():
				continue
			var away := absi(cell.x - zone.spawn.x) + absi(cell.y - zone.spawn.y)
			if away >= 5 and away <= 14:
				spots.append(cell)
	if spots.is_empty():
		return
	_add_critter(zone, spots[spots.size() / 3], "butterfly_blue", 22.0)
	_add_critter(zone, spots[spots.size() * 2 / 3], "butterfly_yellow", 18.0)
	var town := false
	for poi in zone.points_of_interest:
		if str(poi.get("kind", "")) == "town":
			town = true
	if town:
		_add_critter(zone, spots[spots.size() / 2], "chicken_walk", 11.0)


func _add_critter(zone: WorldZone, cell: Vector2i, anim_id: String, speed: float) -> void:
	var sprite := Art.make_loop(anim_id)
	if sprite == null:
		return
	var body := Node2D.new()
	body.position = BoardVisualSort.cell_to_local(cell, float(zone.height_at(cell)))
	body.z_as_relative = false
	body.z_index = (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS
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
	if _shadows != null and _shadows.visible:
		_shadows.region_rect.position += Vector2(18.0, 6.0) * delta
	if _critters == null or not _critters.visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for body in _critters.get_children():
		var origin: Vector2 = body.get_meta("origin")
		var phase: float = body.get_meta("phase")
		var speed: float = body.get_meta("speed")
		body.position = origin + Vector2(sin(t * 0.7 + phase) * speed, cos(t * 0.45 + phase) * speed * 0.35)
