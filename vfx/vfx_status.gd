extends "res://vfx/vfx_pooled.gd"

## Attached status marker. Follows a pawn without parenting, so a pawn rebuild cannot free the pool.

var follow: Callable = Callable()
var kind: String = ""
var _phase: float = 0.0
var _speed: float = 3.0
var _tint: Color = VfxPalette.STUN
var _pulse_left: float = 0.0
var _life: float = -1.0
var _aim: Vector2 = Vector2.RIGHT


func play(spec: Dictionary) -> void:
	_begin()
	kind = str(spec.get("status", "stun"))
	_tint = spec.get("tint", _tint_for(kind))
	_phase = 0.0
	_speed = 3.0 if kind == "stun" else 5.0
	_pulse_left = 0.0
	_life = float(spec.get("life", -1.0))
	var aim: Variant = spec.get("aim", Vector2.RIGHT)
	_aim = aim if aim is Vector2 else Vector2.RIGHT
	z_as_relative = false
	z_index = int(spec.get("z", 120))
	if spec.has("pos"):
		position = spec["pos"]
	queue_redraw()


func retarget(spec: Dictionary) -> void:
	if spec.has("pos"):
		position = spec["pos"]
	_tint = spec.get("tint", _tint)
	queue_redraw()


func pulse(sec: float) -> void:
	_speed = 9.0
	_pulse_left = sec


func dismiss() -> void:
	if not in_use:
		return
	follow = Callable()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.finished.connect(release, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if follow.is_valid():
		var at: Variant = follow.call()
		if at is Vector2:
			position = at
	_phase += delta * _speed
	if _pulse_left > 0.0:
		_pulse_left -= delta
		if _pulse_left <= 0.0:
			_speed = 3.0 if kind == "stun" else 5.0
	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			_life = -1.0
			dismiss()
	queue_redraw()


func _draw() -> void:
	match kind:
		"stun":
			_draw_stun()
		"burn":
			_draw_burn()
		"shield":
			_draw_shield()
		"chevron":
			_draw_chevron()
		_:
			draw_arc(Vector2(0, -16), 16.0, 0, TAU, 20, _tint, 1.5, true)


func _draw_stun() -> void:
	for i in 3:
		var ang := _phase * 1.4 + TAU * float(i) / 3.0
		var at := Vector2(cos(ang) * 14.0, sin(ang) * 6.0 - 46.0)
		draw_circle(at, 4.2, VfxPalette.OUTLINE)
		draw_circle(at, 3.0, _tint)


func _draw_burn() -> void:
	var flicker := 0.75 + 0.25 * sin(_phase * 9.0)
	var base := Vector2(0, -6)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0, -16.0 * flicker),
		base + Vector2(6, 0),
		base + Vector2(0, -4),
		base + Vector2(-6, 0),
	]), VfxPalette.BURN)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0, -10.0 * flicker),
		base + Vector2(3, -2),
		base + Vector2(-3, -2),
	]), VfxPalette.EMBER)


func _draw_shield() -> void:
	draw_arc(Vector2(0, -24), 18.0, 0, TAU, 24, VfxPalette.OUTLINE, 3.0, true)
	draw_arc(Vector2(0, -24), 18.0, 0, TAU, 24, _tint, 1.5, true)


func _draw_chevron() -> void:
	var tip: Vector2 = _tint_dir()
	var side := Vector2(-tip.y, tip.x)
	var a := tip * 10.0
	var b := -tip * 4.0 + side * 6.0
	var c := -tip * 4.0 - side * 6.0
	draw_colored_polygon(PackedVector2Array([a, b, c]), VfxPalette.OUTLINE)
	draw_colored_polygon(PackedVector2Array([a * 0.72, b * 0.55, c * 0.55]), _tint)


func _tint_dir() -> Vector2:
	if _aim.length_squared() < 0.01:
		return Vector2.RIGHT
	return _aim.normalized()


func _tint_for(status: String) -> Color:
	match status:
		"burn":
			return VfxPalette.BURN
		"shield":
			return VfxPalette.SHIELD_TOP
		"chevron":
			return VfxPalette.KESTREL_AIR
		_:
			return VfxPalette.STUN


func release() -> void:
	follow = Callable()
	kind = ""
	_life = -1.0
	_aim = Vector2.RIGHT
	super.release()
