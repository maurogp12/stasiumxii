extends Node2D

## VIEW ONLY. Ironjaw walks Crosshaven from data-driven strips.
## Paths still come from `WorldWalk.find_path`. This node only animates them.
## `advance(delta)` is public so tests can step it deterministically.
##
## Art lives in `res://art/characters/world/ironjaw/` and is described by
## `ironjaw.json` (scale, pivot, fps, stride). See `world_strips.gd`.

signal stepped(cell: Vector2i)
signal arrived(cell: Vector2i)

const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")
const CLASS_ID := "ironjaw"
const CORNER_CUT := 10.0
## Ease distance, in strides, so a shorter hero still eases over about one step.
const EASE_STRIDES := 1.3

var zone: WorldZone
var cell := Vector2i.ZERO
var facing := "s"
var pace := "walk"
var auto_advance := true
## Slow-motion capture. Tests leave this at 1.
var playback := 1.0

var _sprite: Sprite2D
var _strips
var _queue: Array[Vector2i] = []
var _moving := false
var _samples: Array = []
var _cursor := 0
var _traveled := 0.0
var _total := 0.0
var _leg_start := 0.0
var _cruise := 57.0
var _stride := 19.0
var _bob := 0.0
var _air := 0.0
var _idle_t := 0.0
var _phase := 0.0
var _halt_after := false
## East/west strips plant the foot on a flat line. The iso step also moves in Y.
## Hold the sole's screen Y while it is down, and ease that hold off in the air.
var _foot_cycle := -1
var _foot_origin_y := 0.0
var _foot_sole_y := 0.0
var _foot_release := 0.0


func _ready() -> void:
	z_as_relative = false
	_strips = Strips.new()
	_strips.load_class(CLASS_ID)
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.offset = _strips.pivot
	add_child(_sprite)
	_apply_strip_speed()
	_show_idle()


func base_scale() -> float:
	return _strips.scale


func frame_count(gait: String, dir: String) -> int:
	return _strips.frame_count(gait, dir)


func fps_of(gait: String) -> float:
	return _strips.fps_of(gait, "s")


func stride_of(gait: String, dir: String = "s") -> float:
	return _strips.stride_of(gait, dir)


func speed_of(gait: String) -> float:
	return _strips.speed_of(gait, "s")


func place(target_zone: WorldZone, at: Vector2i) -> void:
	zone = target_zone
	cell = at
	facing = "s"
	pace = "walk"
	_queue.clear()
	_samples.clear()
	_moving = false
	_halt_after = false
	_traveled = 0.0
	_total = 0.0
	_phase = 0.0
	_bob = 0.0
	_air = 0.0
	position = _cell_pos(at)
	z_index = _z_for(at)
	_show_idle()
	queue_redraw()


func is_moving() -> bool:
	return _moving


func anchor_cell() -> Vector2i:
	if not _moving:
		return cell
	return _pending_cell()


## `steps` excludes the anchor cell. `pace_name` is "auto", "walk", or "run".
func walk(steps: Array[Vector2i], pace_name: String = "auto") -> void:
	var use := pace_name
	if use == "auto":
		use = "run" if steps.size() >= 14 else "walk"
	pace = use
	_halt_after = false
	if _moving:
		var pending := _pending_cell()
		var rest: Array[Vector2i] = [pending]
		for step in steps:
			if rest.is_empty() or rest[rest.size() - 1] != step:
				rest.append(step)
		_queue = rest
		_rebuild(cell, position)
		return
	if steps.is_empty():
		return
	_queue = steps.duplicate()
	_phase = 0.0
	_rebuild(cell, _cell_pos(cell))


func stop() -> void:
	if _moving:
		_halt_after = true


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


func advance(delta: float) -> void:
	delta *= playback
	if not _moving:
		_idle_t += delta
		_show_idle()
		return
	var speed := _speed_at(_traveled, _total, _cruise)
	_traveled = minf(_total, _traveled + speed * delta)
	_phase += speed * delta
	_consume()
	if _traveled >= _total - 0.15:
		_traveled = _total
		_consume()
		_moving = false
		if not _samples.is_empty():
			position = _samples[_samples.size() - 1]["pos"]
		z_index = _z_for(cell)
		_bob = 0.0
		_show_idle()
		arrived.emit(cell)
		return
	position = _point_at(_traveled)
	_face_toward(_pending_cell())
	_apply_gait()
	_update_z()


func _rebuild(from_cell: Vector2i, from_pos: Vector2) -> void:
	var cells: Array[Vector2i] = [from_cell]
	for step in _queue:
		cells.append(step)
	_samples = _bake(cells, from_pos)
	_cursor = 0
	_traveled = 0.0
	_leg_start = 0.0
	_total = 0.0
	if not _samples.is_empty():
		_total = float(_samples[_samples.size() - 1]["dist"])
	_apply_strip_speed()
	_moving = _total > 0.4
	if _moving:
		_face_toward(_pending_cell())
		_apply_gait()
	else:
		_show_idle()


func _bake(cells: Array[Vector2i], first_pos: Vector2) -> Array:
	var raw: PackedVector2Array = PackedVector2Array()
	raw.append(first_pos)
	for i in range(1, cells.size()):
		raw.append(_cell_pos(cells[i]))
	var marks: Array = [{"pos": raw[0], "has": false, "cell": Vector2i.ZERO}]
	for i in range(1, raw.size()):
		var here: Vector2 = raw[i]
		var prev: Vector2 = raw[i - 1]
		var arrive: Vector2i = cells[i]
		var last := i == raw.size() - 1
		if not last:
			var nxt: Vector2 = raw[i + 1]
			var vin := here - prev
			var vout := nxt - here
			var lin := vin.length()
			var lout := vout.length()
			var aligned := true
			if lin > 0.01 and lout > 0.01:
				aligned = vin.normalized().dot(vout.normalized()) > 0.98
			if not aligned and lin > 8.0 and lout > 8.0:
				var cut_in := minf(CORNER_CUT, lin * 0.35)
				var cut_out := minf(CORNER_CUT, lout * 0.35)
				var a := here - vin.normalized() * cut_in
				var b := here + vout.normalized() * cut_out
				marks.append({"pos": a, "has": false, "cell": Vector2i.ZERO})
				for step in [0.35, 0.5, 0.75, 1.0]:
					var t := float(step)
					marks.append({
						"pos": _quad(a, here, b, t),
						"has": is_equal_approx(t, 0.5),
						"cell": arrive,
					})
				continue
		marks.append({"pos": here, "has": true, "cell": arrive})
	return _measure(marks)


func _quad(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


func _measure(marks: Array) -> Array:
	var out: Array = []
	var dist := 0.0
	var prev: Vector2 = marks[0]["pos"]
	for mark in marks:
		var pos: Vector2 = mark["pos"]
		dist += prev.distance_to(pos)
		out.append({"pos": pos, "dist": dist, "has": mark["has"], "cell": mark["cell"]})
		prev = pos
	return out


func _point_at(dist: float) -> Vector2:
	if _samples.is_empty():
		return position
	var prev_d := 0.0
	var prev_p: Vector2 = _samples[0]["pos"]
	for sample in _samples:
		var d := float(sample["dist"])
		var pos: Vector2 = sample["pos"]
		if d >= dist:
			var span := d - prev_d
			var u := 0.0 if span < 0.001 else (dist - prev_d) / span
			return prev_p.lerp(pos, u)
		prev_d = d
		prev_p = pos
	return prev_p


func _consume() -> void:
	while _cursor < _samples.size():
		var sample: Dictionary = _samples[_cursor]
		if float(sample["dist"]) > _traveled + 0.05:
			break
		_cursor += 1
		if not bool(sample["has"]):
			continue
		var arrived_cell: Vector2i = sample["cell"]
		cell = arrived_cell
		_leg_start = float(sample["dist"])
		if not _queue.is_empty() and _queue[0] == arrived_cell:
			_queue.pop_front()
		stepped.emit(arrived_cell)
		if _halt_after:
			_traveled = _total
			_queue.clear()
			return


func _pending_cell() -> Vector2i:
	for i in range(_cursor, _samples.size()):
		var sample: Dictionary = _samples[i]
		if bool(sample["has"]) and float(sample["dist"]) > _traveled + 0.001:
			return sample["cell"]
	if not _queue.is_empty():
		return _queue[0]
	return cell


func _pending_dist() -> float:
	for i in range(_cursor, _samples.size()):
		var sample: Dictionary = _samples[i]
		if bool(sample["has"]):
			return float(sample["dist"])
	return _total


func _speed_at(traveled: float, total: float, cruise: float) -> float:
	var ease := minf(_stride * EASE_STRIDES, total * 0.22)
	if ease < 1.0:
		return cruise
	var gate := 1.0
	if traveled < ease:
		var u := traveled / ease
		gate = 0.2 + 0.8 * (u * u * (3.0 - 2.0 * u))
	elif traveled > total - ease:
		var u2 := (total - traveled) / ease
		gate = 0.2 + 0.8 * (u2 * u2 * (3.0 - 2.0 * u2))
	return cruise * gate


func _face_toward(target: Vector2i) -> void:
	var d := target - cell
	if d.x > 0:
		facing = "e"
	elif d.x < 0:
		facing = "w"
	elif d.y > 0:
		facing = "s"
	elif d.y < 0:
		facing = "n"
	_apply_strip_speed()


func _gait_name() -> String:
	return "run" if pace == "run" else "walk"


func _apply_strip_speed() -> void:
	if _strips == null:
		return
	var gait := _gait_name()
	var next_stride: float = _strips.stride_of(gait, facing)
	# Keep the same point in the cycle when a corner changes the stride.
	if _stride > 0.001 and not is_equal_approx(next_stride, _stride):
		var frac := fmod(_phase / _stride, 1.0)
		if frac < 0.0:
			frac += 1.0
		_phase = frac * next_stride
	_stride = next_stride
	_cruise = _strips.speed_of(gait, facing)


func _apply_gait() -> void:
	var gait := _gait_name()
	var tex: Texture2D = _strips.texture(gait, facing)
	if tex == null:
		_show_idle()
		return
	var count := maxi(1, _strips.frame_count(gait, facing))
	var span := maxf(_stride, 0.001)
	var phase := fmod(_phase / span, 1.0)
	if phase < 0.0:
		phase += 1.0
	var frame := int(phase * float(count)) % count
	var cell_size: Vector2i = _strips.frame_size(gait)
	_bob = 0.0
	_air = 0.0
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(frame * cell_size.x, 0, cell_size.x, cell_size.y)
	_sprite.scale = Vector2(_strips.scale, _strips.scale)
	_sprite.position = _foot_offset(frame)
	queue_redraw()


func _show_idle() -> void:
	var tex: Texture2D = _strips.idle(facing)
	_sprite.texture = tex
	_sprite.region_enabled = false
	var breath := sin(_idle_t * TAU * 1.35) * 0.012
	_sprite.scale = Vector2(_strips.scale * (1.0 - breath * 0.4), _strips.scale * (1.0 + breath))
	_sprite.position = Vector2.ZERO
	_foot_cycle = -1
	_bob = 0.0
	_air = 0.0
	queue_redraw()


func _update_z() -> void:
	# Sort by ground screen-Y so the order slides across a step. Add the
	# elevation lift back: props sort on the cell diagonal, not the raised pixels.
	var ground_y := position.y
	if zone != null:
		var nxt := _pending_cell()
		var span := maxf(_pending_dist() - _leg_start, 0.001)
		var along := clampf((_traveled - _leg_start) / span, 0.0, 1.0)
		var h := lerpf(float(zone.height_at(cell)), float(zone.height_at(nxt)), along)
		ground_y += h * BoardVisualSort.ELEVATION_PIXELS
	z_index = int(round(ground_y * float(BoardVisualSort.TILE_Z_SCALE) / 16.0)) + BoardVisualSort.UNIT_Z_BIAS


func _z_for(c: Vector2i) -> int:
	return (c.x + c.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS


func _cell_pos(c: Vector2i) -> Vector2:
	if zone == null:
		return BoardVisualSort.cell_to_local(c)
	return BoardVisualSort.cell_to_local(c, float(zone.height_at(c)))


## Sole lift in world pixels, measured from the pivot on the east strip (west matches).
func _sole_lift(gait: String, frame: int) -> float:
	var dy := -1.0
	if gait == "run":
		match frame:
			0:
				dy = -2.0
			1:
				dy = -1.0
			2:
				dy = -2.0
			3:
				dy = -7.0
			4:
				dy = -6.0
			5:
				dy = -3.0
			6:
				dy = -7.0
			_:
				dy = -5.0
	else:
		match frame:
			0:
				dy = -3.0
			1, 2, 3:
				dy = -1.0
			4:
				dy = -2.0
			5:
				dy = -3.0
			_:
				dy = -6.0
	var s: float = _strips.scale if _strips != null else 0.33
	return dy * s


func _foot_in_air(gait: String, frame: int) -> bool:
	if gait == "run":
		return frame >= 3
	return frame >= 6


func _foot_offset(frame: int) -> Vector2:
	if facing != "e" and facing != "w":
		_foot_cycle = -1
		return Vector2.ZERO
	var gait := _gait_name()
	var span := maxf(_stride, 0.001)
	var cycle := int(_phase / span)
	var sole_y := _sole_lift(gait, frame)
	if cycle != _foot_cycle:
		_foot_cycle = cycle
		_foot_origin_y = position.y
		_foot_sole_y = sole_y
		_foot_release = 0.0
	var held := _foot_origin_y - position.y + _foot_sole_y - sole_y
	if not _foot_in_air(gait, frame):
		_foot_release = held
		return Vector2(0.0, held)
	var slots := 5 if gait == "run" else 2
	var index := frame - (3 if gait == "run" else 6)
	var u := float(index + 1) / float(slots)
	return Vector2(0.0, _foot_release * (1.0 - u))


func _draw() -> void:
	var s: float = _strips.scale if _strips != null else 0.33
	var rx := 24.0 * s
	var ry := 9.0 * s
	var at := Vector2.ZERO
	if _sprite != null:
		at = _sprite.position
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))
	if _strips == null or not _strips.has_gait("walk"):
		draw_circle(Vector2(0, -28), 10, Color("6a5344"))
