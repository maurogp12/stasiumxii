extends Node2D

## KO soul release (view only): a soft shaft of light over the fallen
## champion and glowing wisps in the class colour that sway up out of the
## body and fade. One per death, frees itself. Wakfu-style farewell.

const LIFE := 1.9
const WISPS := 18

var tint := Color(0.9, 0.85, 0.7)
var _t := 0.0
var _wisps: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 13.0 + position.y * 7.0)
	for i in WISPS:
		_wisps.append({
			"x": rng.randf_range(-16.0, 16.0),
			"y": rng.randf_range(-40.0, -6.0),
			"rise": rng.randf_range(55.0, 105.0),
			"sway": rng.randf_range(4.0, 11.0),
			"phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(2.2, 4.4),
			"delay": rng.randf_range(0.0, 0.45),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var u := clampf(_t / LIFE, 0.0, 1.0)
	# Light shaft: opens fast, then thins and fades.
	var open := clampf(_t / 0.18, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.35, 1.0, u)
	var half := 15.0 * open * (1.0 - 0.45 * u)
	var top := -150.0
	if fade > 0.0:
		for k in 3:
			var w := half * (1.0 + 0.7 * k)
			var a := 0.3 * fade / float(k + 1)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.35, top), Vector2(w * 0.35, top), Vector2(w, 0), Vector2(-w, 0),
			]), Color(tint.r, tint.g, tint.b, a))
		draw_circle(Vector2(0, -6), 22.0 * open, Color(tint.r, tint.g, tint.b, 0.3 * fade))
	# Wisps sway up and fade.
	for wisp in _wisps:
		var t: float = _t - float(wisp["delay"])
		if t <= 0.0:
			continue
		var k: float = clampf(t / (LIFE - float(wisp["delay"])), 0.0, 1.0)
		var p := Vector2(float(wisp["x"]) + sin(float(wisp["phase"]) + t * 5.0) * float(wisp["sway"]), float(wisp["y"]) - float(wisp["rise"]) * k)
		var a := (1.0 - k) * minf(t / 0.12, 1.0)
		var r: float = float(wisp["size"]) * (1.0 - 0.4 * k)
		draw_circle(p, r * 3.2, Color(tint.r, tint.g, tint.b, 0.22 * a))
		draw_circle(p, r, Color(1.0, 1.0, 1.0, 0.85 * a).lerp(tint, 0.35))
