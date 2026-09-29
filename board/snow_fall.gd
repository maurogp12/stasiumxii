class_name SnowFall
extends Node2D

## Windmere weather (Mauro, 29 Sep: "the map of winter I would like to have
## snow falling"). Flakes drift down over the board with a slow side sway,
## each settling on a spot of the board and fading there. A few big soft
## flakes pass close to the camera for depth. Presentation only: its own RNG,
## never the sim.

const FLAKES := 280
const NEAR_FLAKES := 22
const FALL_MIN := 26.0
const FALL_MAX := 58.0
const DROP_MIN := 260.0
const DROP_MAX := 520.0
const MELT := 0.9

var _board_size := 15
var _rng := RandomNumberGenerator.new()
var _flakes: Array = []  # {land: Vector2, drop: float, speed, r, a, phase, sway, melt}
var _gust_t := 0.0


func _ready() -> void:
	z_as_relative = false
	# Same band as the storm bolts: above tiles and fighters, under numbers.
	z_index = 470
	_rng.randomize()
	_reseed()


func set_board_size(size: int) -> void:
	var next := maxi(size, 1)
	if next != _board_size or _flakes.is_empty():
		_board_size = next
		_reseed()


func flake_count() -> int:
	return _flakes.size()


func _reseed() -> void:
	_flakes.clear()
	for i in FLAKES + NEAR_FLAKES:
		var flake := _new_flake(i >= FLAKES)
		# Spread the first wave over the whole fall so it does not arrive as one sheet.
		flake["drop"] = maxf(_rng.randf_range(-40.0, float(flake["drop"])), 0.0)
		flake["drop0"] = maxf(float(flake["drop"]), 0.0) + 60.0
		_flakes.append(flake)


func _new_flake(near: bool) -> Dictionary:
	var span := float(_board_size - 1) + 3.0
	# Anywhere over the board and a margin of 1.5 cells around it.
	var cx := _rng.randf_range(-1.5, span - 1.5)
	var cy := _rng.randf_range(-1.5, span - 1.5)
	var land := Vector2((cx - cy) * 32.0, (cx + cy) * 16.0)
	var drop := _rng.randf_range(DROP_MIN, DROP_MAX) * (1.4 if near else 1.0)
	return {
		"land": land,
		"drop": drop,
		"drop0": drop,
		"speed": _rng.randf_range(FALL_MIN, FALL_MAX) * (1.9 if near else 1.0),
		"r": _rng.randf_range(4.5, 7.0) if near else _rng.randf_range(1.6, 3.0),
		"a": _rng.randf_range(0.45, 0.65) if near else _rng.randf_range(0.75, 1.0),
		"phase": _rng.randf_range(0.0, TAU),
		"sway": _rng.randf_range(6.0, 16.0) * (2.0 if near else 1.0),
		"melt": 0.0,
		"near": near,
	}


func _process(delta: float) -> void:
	if not visible:
		return
	_gust_t += delta
	for i in _flakes.size():
		var flake: Dictionary = _flakes[i]
		if float(flake["drop"]) > 0.0:
			flake["drop"] = maxf(float(flake["drop"]) - float(flake["speed"]) * delta, 0.0)
			flake["phase"] = float(flake["phase"]) + delta * 1.3
		else:
			flake["melt"] = float(flake["melt"]) + delta
			if float(flake["melt"]) >= MELT:
				_flakes[i] = _new_flake(bool(flake["near"]))
	queue_redraw()


func _draw() -> void:
	# Slow gusts push the whole fall sideways a little.
	var gust := sin(_gust_t * 0.35) * 10.0 + sin(_gust_t * 0.13 + 1.7) * 6.0
	for flake in _flakes:
		var drop := float(flake["drop"])
		var sway := sin(float(flake["phase"])) * float(flake["sway"])
		var drift := gust * clampf(drop / DROP_MAX, 0.0, 1.0)
		var pos: Vector2 = flake["land"] + Vector2(sway * clampf(drop / 60.0, 0.0, 1.0) + drift, -drop)
		var a := float(flake["a"])
		# Fade in at the top of the fall and melt out once it lands.
		a *= clampf((float(flake["drop0"]) - drop) / 60.0 + 0.15, 0.0, 1.0)
		if drop <= 0.0:
			a *= 1.0 - float(flake["melt"]) / MELT
		if a <= 0.01:
			continue
		var r := float(flake["r"])
		if bool(flake["near"]):
			draw_circle(pos, r * 1.8, Color(0.85, 0.92, 1.0, a * 0.25))
		# Soft blue-grey edge so white flakes still read over white ice.
		draw_circle(pos + Vector2(0.6, 0.9), r * 1.35, Color(0.22, 0.32, 0.48, a * 0.35))
		draw_circle(pos, r * 1.7, Color(0.80, 0.90, 1.0, a * 0.18))
		draw_circle(pos, r, Color(0.98, 0.99, 1.0, a))
		if drop <= 0.0:
			# Settled flake: a tiny flat glint on the ice.
			draw_line(pos + Vector2(-r * 1.6, 0.0), pos + Vector2(r * 1.6, 0.0), Color(1, 1, 1, a * 0.5), 0.8, true)
