extends "res://vfx/vfx_pooled.gd"

## Rising heal motes. Six particles, cream into teal.

var _particles: CPUParticles2D
var _life: float = 0.0


func _ready() -> void:
	super._ready()
	_particles = CPUParticles2D.new()
	_particles.amount = VfxBudget.MOTE_AMOUNT
	_particles.lifetime = VfxBudget.MOTE_LIFE
	_particles.one_shot = true
	_particles.explosiveness = 0.35
	_particles.spread = 28.0
	_particles.direction = Vector2(0, -1)
	_particles.gravity = Vector2(0, -20)
	_particles.initial_velocity_min = 28.0
	_particles.initial_velocity_max = 54.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 3.6
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
	z_index = int(spec.get("z", 50))
	var tint: Color = spec.get("tint", VfxPalette.MENDER_CREAM)
	_particles.color = tint
	_particles.emitting = true
	_particles.restart()
	_life = VfxBudget.MOTE_LIFE + 0.05


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_particles.emitting = false
		release()


func release() -> void:
	if _particles != null:
		_particles.emitting = false
	super.release()
