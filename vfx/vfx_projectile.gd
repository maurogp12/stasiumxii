extends "res://vfx/vfx_pooled.gd"

## Straight or arced mover with a short trail. Overshoot is the miss whiff.

var _line: Line2D
var _glow: Line2D
var _head: Polygon2D
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _arc: float = 0.0
var _duration: float = 0.2
var _elapsed: float = 0.0
var _delay: float = 0.0
var _show_head: bool = true
var _whiff: bool = false
var _points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	super._ready()
	_line = Line2D.new()
	_line.width = 5.0
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.z_index = 1
	add_child(_line)
	_glow = Line2D.new()
	_glow.width = 14.0
	_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.z_index = 0
	add_child(_glow)
	move_child(_glow, 0)
	_head = Polygon2D.new()
	_head.polygon = PackedVector2Array([
		Vector2(10, 0), Vector2(-6, 4.5), Vector2(-2, 0), Vector2(-6, -4.5),
	])
	add_child(_head)


func play(spec: Dictionary) -> void:
	_begin()
	_from = spec.get("from", Vector2.ZERO)
	_to = spec.get("to", _from)
	var overshoot := float(spec.get("overshoot", 0.0))
	if overshoot > 0.0:
		var delta: Vector2 = _to - _from
		var dir := delta.normalized() if delta.length_squared() > 1.0 else Vector2.RIGHT
		_to = _to + dir * overshoot
	_arc = float(spec.get("arc", 0.0))
	_duration = maxf(0.08, float(spec.get("duration", 0.2)))
	_delay = maxf(0.0, float(spec.get("delay", 0.0)))
	_elapsed = -_delay
	_points = PackedVector2Array()
	var tint: Color = spec.get("tint", VfxPalette.KESTREL_AIR)
	var width := float(spec.get("width", 5.0))
	_line.default_color = tint.lerp(Color(1, 0.98, 0.9), 0.55)
	_line.width = width
	if _glow != null:
		_glow.default_color = Color(tint.r, tint.g, tint.b, 0.62)
		_glow.width = width * 2.6
	_head.color = tint.lerp(Color.WHITE, 0.25)
	_show_head = bool(spec.get("head", true))
	_whiff = bool(spec.get("whiff", false))
	if _whiff:
		_line.default_color = Color(tint.r, tint.g, tint.b, 0.55)
		_line.width = maxf(1.6, width * 0.7)
		if _glow != null:
			_glow.default_color = Color(tint.r, tint.g, tint.b, 0.12)
		_show_head = false
	_head.visible = false
	z_as_relative = false
	z_index = int(spec.get("z", 80))
	position = Vector2.ZERO
	if _delay <= 0.0:
		_head.visible = _show_head
		_sample(0.0)
	else:
		visible = false
		_line.points = PackedVector2Array()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.0:
		visible = false
		return
	visible = true
	_head.visible = _show_head
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	_sample(t)
	if t >= 1.0:
		var fade := create_tween()
		_tween = fade
		fade.tween_property(self, "modulate:a", 0.0, 0.12)
		fade.finished.connect(release, CONNECT_ONE_SHOT)
		set_process(false)


func _sample(t: float) -> void:
	var flat := _from.lerp(_to, t)
	var lift := sin(t * PI) * _arc
	var at := flat + Vector2(0, -lift)
	_head.position = at
	_head.rotation = (_to - _from).angle()
	# A miss breaks before it would connect, then the stub overshoots.
	if _whiff and t > 0.55 and t < 0.78:
		_head.visible = false
		return
	_points.append(at)
	if _points.size() > 8:
		_points.remove_at(0)
	_line.points = _points
	if _glow != null:
		_glow.points = _points


func release() -> void:
	if _line != null:
		_line.points = PackedVector2Array()
	if _glow != null:
		_glow.points = PackedVector2Array()
	_points = PackedVector2Array()
	super.release()
