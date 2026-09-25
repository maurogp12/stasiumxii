extends "res://vfx/vfx_pooled.gd"

## Iso ground ring. Outline only, with a dark stroke, so it does not read as a tile fill.

var _tint: Color = VfxPalette.BASTION
var _life: float = 0.0
var _linger: bool = false
var _pulse: float = 0.0
var _sprite: Sprite2D
var _material: ShaderMaterial


func _ready() -> void:
	super._ready()
	_sprite = Sprite2D.new()
	_sprite.texture = VfxPalette.ellipse_texture()
	_sprite.centered = true
	var shader: Shader = load("res://vfx/vfx_common.gdshader")
	if shader != null:
		_material = ShaderMaterial.new()
		_material.shader = shader
		_sprite.material = _material
	add_child(_sprite)


func play(spec: Dictionary) -> void:
	_begin()
	position = spec.get("pos", Vector2.ZERO)
	_tint = spec.get("tint", VfxPalette.BASTION)
	_linger = bool(spec.get("linger", false))
	_life = float(spec.get("life", 0.28))
	_pulse = 0.0
	scale = Vector2(0.86, 0.86)
	z_as_relative = false
	z_index = int(spec.get("z", 1))
	_apply_shader(float(spec.get("swirl", 0.0)))
	_sprite.modulate = Color(_tint.r, _tint.g, _tint.b, 0.85)
	if _linger:
		_tween = create_tween()
		_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_tween = create_tween()
		_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	queue_redraw()


func dismiss() -> void:
	if not in_use:
		return
	_linger = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.finished.connect(release, CONNECT_ONE_SHOT)


func _apply_shader(swirl: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("tint", _tint)
	_material.set_shader_parameter("outline", 0.85)
	_material.set_shader_parameter("outline_color", VfxPalette.OUTLINE)
	_material.set_shader_parameter("dissolve", 0.0)
	_material.set_shader_parameter("uv_swirl", swirl)


func _process(delta: float) -> void:
	_pulse += delta
	if _material != null and _linger:
		_material.set_shader_parameter("uv_swirl", sin(_pulse * 1.6) * 0.35)
	queue_redraw()
	if _linger:
		return
	_life -= delta
	if _life <= 0.0:
		release()


func _draw() -> void:
	var pts := PackedVector2Array()
	var count := 28
	for i in count:
		var ang := TAU * float(i) / float(count)
		pts.append(Vector2(cos(ang) * 28.0, sin(ang) * 14.0))
	pts.append(pts[0])
	draw_polyline(pts, VfxPalette.OUTLINE, 3.0, true)
	draw_polyline(pts, _tint, 1.5, true)
