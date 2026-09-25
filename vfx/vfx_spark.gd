extends "res://vfx/vfx_pooled.gd"

## One-shot impact spark. Amount is capped. A short white flash sits in the core.

var _particles: CPUParticles2D
var _flash: float = 0.0
var _life: float = 0.0


func _ready() -> void:
	super._ready()
	_particles = CPUParticles2D.new()
	_particles.amount = VfxBudget.SPARK_AMOUNT
	_particles.lifetime = VfxBudget.SPARK_LIFE
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 28)
	_particles.initial_velocity_min = 36.0
	_particles.initial_velocity_max = 88.0
	_particles.scale_amount_min = 1.2
	_particles.scale_amount_max = 2.4
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
	var tint: Color = spec.get("tint", VfxPalette.KESTREL_AIR)
	var amount := VfxBudget.SPARK_AMOUNT
	if spec.has("amount"):
		amount = clampi(int(spec.get("amount", amount)), 1, VfxBudget.SPARK_CAP)
	_particles.amount = amount
	_particles.color = tint
	_particles.emitting = true
	_particles.restart()
	_flash = 1.0
	_life = 0.28
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	_flash = maxf(0.0, _flash - delta / 0.08)
	queue_redraw()
	if _life <= 0.0:
		_particles.emitting = false
		release()


func _draw() -> void:
	if _flash <= 0.0:
		return
	draw_circle(Vector2.ZERO, 8.0 + (1.0 - _flash) * 6.0, Color(1, 1, 1, _flash * 0.9))


func release() -> void:
	if _particles != null:
		_particles.emitting = false
		_particles.amount = VfxBudget.SPARK_AMOUNT
	super.release()
