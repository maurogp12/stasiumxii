extends Node2D

## VIEW ONLY. Ironjaw walks Crosshaven on the PC copies of the mobile strips.
## Paths still come from `WorldWalk.find_path`. This node only animates them.
## `advance(delta)` is public so tests can step it deterministically.

signal stepped(cell: Vector2i)
signal arrived(cell: Vector2i)

const STRIP := "res://art/characters/world/ironjaw/ironjaw_%s_%s.png"
const IDLE := "res://art/characters/world/ironjaw/ironjaw_idle_%s.png"
const FRAME_W := 144.0
const FRAME_H := 160.0
const FRAME_COUNT := 12
## Mobile pawn is centered with offset (0, -72). 0.62 keeps cottages taller.
const BASE_SCALE := 0.62
const PIVOT := Vector2(0, -72)
const WALK_SPEED := 108.0
const RUN_SPEED := 176.0
## One authored cycle per tile at a walk. Run takes a longer stride.
const WALK_CYCLE := 35.78
const RUN_CYCLE := 52.0
const CORNER_CUT := 10.0
const EASE_PX := 46.0

var zone: WorldZone
var cell := Vector2i.ZERO
var facing := "s"
var pace := "walk"
var auto_advance := true
## Slow-motion capture. Tests leave this at 1.
var playback := 1.0

var _sprite: Sprite2D
var _strips: Dictionary = {}
var _idles: Dictionary = {}
var _queue: Array[Vector2i] = []
var _moving := false
var _samples: Array = []
var _cursor := 0
var _traveled := 0.0
var _total := 0.0
var _leg_start := 0.0
var _cruise := WALK_SPEED
var _cycle := WALK_CYCLE
var _bob := 0.0
var _air := 0.0
var _idle_t := 0.0
var _phase := 0.0
var _halt_after := false


func _ready() -> void:
	z_as_relative = false
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.offset = PIVOT
	add_child(_sprite)
	for gait in ["walk", "run"]:
		for dir in ["n", "e", "s", "w"]:
			var path := STRIP % [gait, dir]
			if ResourceLoader.exists(path):
				_strips["%s_%s" % [gait, dir]] = load(path)
	for dir in ["n", "e", "s", "w"]:
		var path := IDLE % dir
		if ResourceLoader.exists(path):
			_idles[dir] = load(path)
	_show_idle()


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
	_cruise = RUN_SPEED if pace == "run" else WALK_SPEED
	_cycle = RUN_CYCLE if pace == "run" else WALK_CYCLE
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
	var ease := minf(EASE_PX, total * 0.22)
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


func _apply_gait() -> void:
	var key := "%s_%s" % [pace if pace == "run" else "walk", facing]
	var tex: Texture2D = _strips.get(key, null)
	if tex == null:
		_show_idle()
		return
	var phase := fmod(_phase / _cycle, 1.0)
	if phase < 0.0:
		phase += 1.0
	# Six authored plants. The odd frame is the airborne in-between.
	# Hold the plant at the start and end of each step; show the lift in the middle.
	var step_f := phase * 6.0
	var step_i := int(step_f) % 6
	var local := step_f - float(int(step_f))
	var airborne := local > 0.18 and local < 0.58
	var frame := step_i * 2 + (1 if airborne else 0)
	var amp := 3.4 if pace == "run" else 1.8
	_bob = sin(local * PI) * amp
	_air = sin(local * PI)
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(frame * FRAME_W, 0, FRAME_W, FRAME_H)
	var sy := lerpf(0.93, 1.06, _air)
	var sx := lerpf(1.06, 0.97, _air)
	_sprite.scale = Vector2(BASE_SCALE * sx, BASE_SCALE * sy)
	_sprite.position = Vector2(0, -_bob)
	queue_redraw()


func _show_idle() -> void:
	var tex: Texture2D = _idles.get(facing, null)
	_sprite.texture = tex
	_sprite.region_enabled = false
	var breath := sin(_idle_t * TAU * 1.35) * 0.016
	_sprite.scale = Vector2(BASE_SCALE * (1.0 - breath * 0.4), BASE_SCALE * (1.0 + breath))
	_sprite.position = Vector2.ZERO
	_bob = 0.0
	_air = 0.0
	queue_redraw()


func _update_z() -> void:
	var nxt := _pending_cell()
	var dest := _pending_dist()
	var span := maxf(dest - _leg_start, 0.001)
	var along := (_traveled - _leg_start) / span
	z_index = _z_for(nxt if along >= 0.5 else cell)


func _z_for(c: Vector2i) -> int:
	return (c.x + c.y) * BoardVisualSort.TILE_Z_SCALE + BoardVisualSort.UNIT_Z_BIAS


func _cell_pos(c: Vector2i) -> Vector2:
	if zone == null:
		return BoardVisualSort.cell_to_local(c)
	return BoardVisualSort.cell_to_local(c, float(zone.height_at(c)))


func _draw() -> void:
	var plant := 1.0 - clampf(_bob / 5.1, 0.0, 1.0)
	var rx := 15.0 + plant * 3.0
	var ry := 5.6 + plant * 1.3
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.26 + plant * 0.08))
	if _strips.is_empty():
		draw_circle(Vector2(0, -28), 10, Color("6a5344"))
