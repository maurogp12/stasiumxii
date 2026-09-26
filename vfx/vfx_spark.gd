extends "res://vfx/vfx_pooled.gd"

## One-shot impact spark. Amount is capped. A short white flash sits in the core.

var _particles: CPUParticles2D
var _flash: float = 0.0
var _life: float = 0.0
var _tint: Color = Color.WHITE
var _wait: float = 0.0
var _pending: Dictionary = {}


func _ready() -> void:
	super._ready()
	_particles = CPUParticles2D.new()
	_particles.amount = VfxBudget.SPARK_AMOUNT
	_particles.lifetime = VfxBudget.SPARK_LIFE
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 46)
	_particles.initial_velocity_min = 52.0
	_particles.initial_velocity_max = 118.0
	_particles.scale_amount_min = 2.1
	_particles.scale_amount_max = 3.6
	_particles.local_coords = true
	_particles.texture = VfxPalette.dot_texture()
	_particles.emitting = false
	add_child(_particles)


func prewarm() -> void:
	super.prewarm()
	_particles.position = Vector2.ZERO
	_particles.emitting = true
	_particles.restart()
	_particles.emitting = false


func play(spec: Dictionary) -> void:
	_begin()
	position = spec.get("pos", Vector2.ZERO)
	z_as_relative = false
	z_index = int(spec.get("z", 40))
	_wait = maxf(0.0, float(spec.get("delay", 0.0)))
	_pending = spec
	if _wait > 0.0:
		visible = false
		_particles.emitting = false
		_flash = 0.0
		_life = 0.28
		return
	_emit(spec)


func _emit(spec: Dictionary) -> void:
	visible = true
	var tint: Color = spec.get("tint", VfxPalette.KESTREL_AIR)
	var amount := VfxBudget.SPARK_AMOUNT
	if spec.has("amount"):
		amount = clampi(int(spec.get("amount", amount)), 1, VfxBudget.SPARK_CAP)
	_particles.amount = amount
	_tint = tint
	_particles.color = Color.WHITE
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.16, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		tint,
		Color(tint.r, tint.g, tint.b, 0.0),
	])
	_particles.color_ramp = ramp
	_particles.emitting = true
	_particles.restart()
	_flash = 1.0
	_life = 0.28
	queue_redraw()


func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
		_wait = 0.0
		_emit(_pending)
		return
	_life -= delta
	_flash = maxf(0.0, _flash - delta / 0.08)
	queue_redraw()
	if _life <= 0.0:
		_particles.emitting = false
		release()


func _draw() -> void:
	if _flash <= 0.0:
		return
	var hot := 16.0 + (1.0 - _flash) * 10.0
	draw_circle(Vector2.ZERO, hot * 1.55, Color(_tint.r, _tint.g, _tint.b, _flash * 0.38))
	draw_circle(Vector2.ZERO, hot * 0.85, Color(_tint.r, _tint.g, _tint.b, _flash * 0.82))
	draw_circle(Vector2.ZERO, hot * 0.38, Color(1, 0.98, 0.9, _flash))


func release() -> void:
	if _particles != null:
		_particles.emitting = false
		_particles.amount = VfxBudget.SPARK_AMOUNT
	super.release()
