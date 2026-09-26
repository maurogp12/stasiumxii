extends "res://vfx/vfx_pooled.gd"

## Miss whiff and soft fizzle. Fewer particles than an impact spark.

var _particles: CPUParticles2D
var _life: float = 0.0


func _ready() -> void:
	super._ready()
	_particles = CPUParticles2D.new()
	_particles.amount = VfxBudget.PUFF_AMOUNT
	_particles.lifetime = VfxBudget.PUFF_LIFE
	_particles.one_shot = true
	_particles.explosiveness = 0.85
	_particles.spread = 70.0
	_particles.direction = Vector2(0, -1)
	_particles.gravity = Vector2(0, -8)
	_particles.initial_velocity_min = 18.0
	_particles.initial_velocity_max = 42.0
	_particles.scale_amount_min = 1.8
	_particles.scale_amount_max = 3.2
	_particles.local_coords = true
	_particles.texture = VfxPalette.dot_texture()
	_particles.emitting = false
	add_child(_particles)


func prewarm() -> void:
	super.prewarm()
	_particles.emitting = true
	_particles.restart()
	_particles.emitting = false


func play(spec: Dictionary) -> void:
	_begin()
	position = spec.get("pos", Vector2.ZERO)
	z_as_relative = false
	z_index = int(spec.get("z", 40))
	var tint: Color = spec.get("tint", VfxPalette.MISS)
	tint.a = float(spec.get("alpha", 0.5))
	_particles.color = tint
	_particles.emitting = true
	_particles.restart()
	_life = VfxBudget.PUFF_LIFE + 0.05


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_particles.emitting = false
		release()


func release() -> void:
	if _particles != null:
		_particles.emitting = false
	super.release()
