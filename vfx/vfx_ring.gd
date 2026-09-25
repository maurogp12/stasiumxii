extends "res://vfx/vfx_pooled.gd"

## Iso ground ring. Outline only, with a dark stroke, so it does not read as a tile fill.

var _tint: Color = VfxPalette.BASTION
var _life: float = 0.0
var _linger: bool = false
var _pulse: float = 0.0
var _style: String = ""
var _turns: int = 0
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
	_style = str(spec.get("style", ""))
	_turns = int(spec.get("turns", 0))
	_pulse = 0.0
	var mul := float(spec.get("scale", 1.0))
	scale = Vector2(0.86, 0.86) * mul
	z_as_relative = false
	z_index = int(spec.get("z", 1))
	_apply_shader(float(spec.get("swirl", 0.0)))
	_sprite.modulate = Color(_tint.r, _tint.g, _tint.b, 0.85)
	if _linger:
		_tween = create_tween()
		_tween.tween_property(self, "scale", Vector2.ONE * mul, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_tween = create_tween()
		_tween.tween_property(self, "scale", Vector2(1.12, 1.12) * mul, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE * mul, 0.1)
	queue_redraw()


func retarget(spec: Dictionary) -> void:
	if spec.has("pos"):
		position = spec["pos"]
	if spec.has("tint"):
		_tint = spec["tint"]
	if spec.has("style"):
		_style = str(spec["style"])
	if spec.has("turns"):
		_turns = int(spec["turns"])
	if spec.has("z"):
		z_index = int(spec["z"])
	modulate.a = 0.4 if bool(spec.get("dim", false)) else 1.0
	_apply_shader(float(spec.get("swirl", 0.0)))
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
	if _material != null and _linger and _style == "pool":
		_material.set_shader_parameter("uv_swirl", sin(_pulse * 1.6) * 0.35)
	queue_redraw()
	if _linger:
		return
	_life -= delta
	if _life <= 0.0:
		release()


func _draw() -> void:
	match _style:
		"slab":
			_draw_slab()
		"sigil":
			_draw_sigil()
		"crack":
			_draw_crack()
		_:
			_draw_ellipse_ring()
	_draw_turns()


func _draw_ellipse_ring() -> void:
	var pts := _ellipse(28.0, 14.0)
	draw_polyline(pts, VfxPalette.OUTLINE, 3.0, true)
	draw_polyline(pts, _tint, 1.5, true)


func _draw_sigil() -> void:
	var gem := PackedVector2Array([
		Vector2(0, -16), Vector2(18, 0), Vector2(0, 16), Vector2(-18, 0),
	])
	gem.append(gem[0])
	draw_polyline(gem, VfxPalette.OUTLINE, 3.0, true)
	draw_polyline(gem, _tint, 1.5, true)
	draw_line(Vector2(-10, -6), Vector2(10, 6), VfxPalette.BASTION_BLACK, 1.5, true)
	draw_line(Vector2(-10, 6), Vector2(10, -6), VfxPalette.BASTION_BLACK, 1.5, true)


func _draw_crack() -> void:
	_draw_ellipse_ring()
	draw_line(Vector2(-16, 2), Vector2(-4, -2), _tint, 1.5, true)
	draw_line(Vector2(-4, -2), Vector2(6, 3), _tint, 1.5, true)
	draw_line(Vector2(6, 3), Vector2(16, -1), _tint, 1.5, true)


func _draw_slab() -> void:
	var foot := PackedVector2Array([
		Vector2(0, -8), Vector2(16, 0), Vector2(0, 8), Vector2(-16, 0),
	])
	foot.append(foot[0])
	draw_polyline(foot, VfxPalette.OUTLINE, 2.0, true)
	var slab := PackedVector2Array([
		Vector2(-11, -2), Vector2(11, -2), Vector2(8, -36), Vector2(-8, -36),
	])
	draw_colored_polygon(slab, VfxPalette.BASTION_BLACK)
	slab.append(slab[0])
	draw_polyline(slab, VfxPalette.OUTLINE, 2.0, true)
	draw_polyline(slab, VfxPalette.BASTION, 1.4, true)
	draw_line(Vector2(-6, -8), Vector2(-4, -30), VfxPalette.BASTION_PALE, 1.2, true)
	draw_line(Vector2(6, -8), Vector2(4, -30), VfxPalette.BASTION_PALE, 1.2, true)


func _draw_turns() -> void:
	if _turns <= 0:
		return
	var n := mini(_turns, 3)
	for i in n:
		var at := Vector2(-8.0 + float(i) * 8.0, -18.0 if _style == "slab" else -20.0)
		draw_circle(at, 2.4, VfxPalette.OUTLINE)
		draw_circle(at, 1.5, _tint)


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count := 28
	for i in count:
		var ang := TAU * float(i) / float(count)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	pts.append(pts[0])
	return pts
