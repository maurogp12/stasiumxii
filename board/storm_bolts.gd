class_name StormBolts
extends Node2D

## Stormspire weather (Mauro's electric look picture): every few seconds a
## jagged gold-white bolt cracks in from beyond the board and strikes a cell,
## with a branch or two and a spark ring where it lands. Presentation only:
## it picks a cell at random for looks and never touches the sim or its RNG.

const LIFE := 0.42
const MIN_GAP := 2.2
const MAX_GAP := 5.5

var _board_size := 15
var _rng := RandomNumberGenerator.new()
var _wait := 1.5
var _bolts: Array = []  # {points, branches, age, end}


func _ready() -> void:
	z_as_relative = false
	# Above tiles and fighters, under Shade markers and combat numbers.
	z_index = 470
	_rng.randomize()


func set_board_size(size: int) -> void:
	_board_size = maxi(size, 1)


func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait <= 0.0:
		_strike()
		_wait = _rng.randf_range(MIN_GAP, MAX_GAP)
	var alive: Array = []
	for bolt in _bolts:
		bolt["age"] = float(bolt["age"]) + delta
		if float(bolt["age"]) < LIFE:
			alive.append(bolt)
	_bolts = alive
	queue_redraw()


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)


func _strike() -> void:
	var last := _board_size - 1
	var target := Vector2i(_rng.randi_range(1, last - 1), _rng.randi_range(1, last - 1))
	var end := _cell_center(target)
	# Enter from high above the far (north) half, like the picture's sky bolts.
	var start := end + Vector2(_rng.randf_range(-260.0, 260.0), -_rng.randf_range(260.0, 380.0))
	var main := _jagged(start, end, 11, 22.0)
	var branches: Array = []
	for i in _rng.randi_range(1, 2):
		var from: Vector2 = main[_rng.randi_range(3, main.size() - 4)]
		var to := from + Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(30.0, 90.0))
		branches.append(_jagged(from, to, 5, 12.0))
	_bolts.append({"points": main, "branches": branches, "age": 0.0, "end": end})


func _jagged(a: Vector2, b: Vector2, segments: int, sway: float) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var normal := (b - a).orthogonal().normalized()
	for i in range(1, segments):
		var t := float(i) / float(segments)
		var off := _rng.randf_range(-sway, sway) * sin(t * PI)
		pts.append(a.lerp(b, t) + normal * off)
	pts.append(b)
	return pts


func _draw() -> void:
	for bolt in _bolts:
		var k := 1.0 - float(bolt["age"]) / LIFE
		# Two quick flickers, then fade.
		var flick := 1.0 if fmod(float(bolt["age"]), 0.12) < 0.08 else 0.55
		var a := k * flick
		var pts: PackedVector2Array = bolt["points"]
		_stroke(pts, a, 1.0)
		for br in bolt["branches"]:
			_stroke(br, a * 0.8, 0.6)
		var end: Vector2 = bolt["end"]
		var r := 6.0 + (1.0 - k) * 22.0
		draw_arc(end, r, 0.0, TAU, 28, Color(1.0, 0.86, 0.45, 0.8 * a), 2.0, true)
		draw_circle(end, 5.0 * k + 1.0, Color(1.0, 0.97, 0.85, a))


func _stroke(pts: PackedVector2Array, a: float, scale: float) -> void:
	draw_polyline(pts, Color(1.0, 0.78, 0.30, 0.22 * a), 12.0 * scale, true)
	draw_polyline(pts, Color(1.0, 0.88, 0.55, 0.55 * a), 5.0 * scale, true)
	draw_polyline(pts, Color(1.0, 1.0, 0.95, a), 1.8 * scale, true)
