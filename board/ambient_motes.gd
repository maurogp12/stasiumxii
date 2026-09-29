class_name AmbientMotes
extends Node2D

## Arena air life, Wakfu style (Mauro 29 Sep 2026: "keep working in the
## graphics … the goal is Dofus / Wakfu"). Windmere has its own SnowFall;
## the other four arenas get drifting motes:
##   embers — Slagcrown: glowing sparks rising off the lava, flickering.
##   pollen — Crosshaven: soft pollen and small leaves drifting sideways.
##   spray  — Brinewake: pale sea-spray motes rising and fading.
##   sparks — Stormspire: electric sparks that float, jitter and blink.
## Presentation only: own RNG, never the sim.

const STYLES := {
	"embers": {"count": 90, "rise": Vector2(18, 46), "sway": 10.0, "life": Vector2(2.4, 4.6), "size": Vector2(1.6, 3.2),
		"core": Color(1.0, 0.86, 0.45), "glow": Color(1.0, 0.42, 0.08), "flicker": 9.0, "leaf": false},
	"pollen": {"count": 60, "rise": Vector2(-4, 8), "sway": 22.0, "life": Vector2(5.0, 9.0), "size": Vector2(1.6, 3.0),
		"core": Color(1.0, 0.96, 0.78), "glow": Color(0.95, 0.90, 0.55), "flicker": 0.0, "leaf": true},
	"spray": {"count": 50, "rise": Vector2(6, 18), "sway": 14.0, "life": Vector2(3.0, 5.5), "size": Vector2(1.8, 3.4),
		"core": Color(0.92, 0.98, 1.0), "glow": Color(0.55, 0.80, 1.0), "flicker": 0.0, "leaf": false},
	"sparks": {"count": 55, "rise": Vector2(4, 14), "sway": 6.0, "life": Vector2(1.6, 3.2), "size": Vector2(1.5, 2.6),
		"core": Color(1.0, 0.98, 0.85), "glow": Color(1.0, 0.80, 0.30), "flicker": 18.0, "leaf": false},
}

var style: String = "embers"
var _board_size := 15
var _rng := RandomNumberGenerator.new()
var _motes: Array = []  # {pos, vel, age, life, size, phase, spin}
var _t := 0.0


func _ready() -> void:
	z_as_relative = false
	# Same band as snow / storm bolts: over tiles and fighters, under numbers.
	z_index = 470
	_rng.randomize()
	_reseed()


func configure(next_style: String, board_size: int) -> void:
	var changed := next_style != style or board_size != _board_size or _motes.is_empty()
	style = next_style if STYLES.has(next_style) else "embers"
	_board_size = maxi(board_size, 1)
	if changed:
		_reseed()


func mote_count() -> int:
	return _motes.size()


func _spec() -> Dictionary:
	return STYLES.get(style, STYLES["embers"])


func _reseed() -> void:
	_motes.clear()
	var spec := _spec()
	for i in int(spec["count"]):
		var mote := _new_mote()
		mote["age"] = _rng.randf_range(0.0, float(mote["life"]))
		_motes.append(mote)


func _new_mote() -> Dictionary:
	var spec := _spec()
	var span := float(_board_size - 1)
	var cx := _rng.randf_range(-1.0, span + 1.0)
	var cy := _rng.randf_range(-1.0, span + 1.0)
	var rise: Vector2 = spec["rise"]
	var life: Vector2 = spec["life"]
	var size: Vector2 = spec["size"]
	return {
		"pos": Vector2((cx - cy) * 32.0, (cx + cy) * 16.0 - _rng.randf_range(0.0, 30.0)),
		"vel": Vector2(_rng.randf_range(-6.0, 6.0), -_rng.randf_range(rise.x, rise.y)),
		"age": 0.0,
		"life": _rng.randf_range(life.x, life.y),
		"size": _rng.randf_range(size.x, size.y),
		"phase": _rng.randf_range(0.0, TAU),
		"spin": _rng.randf_range(-3.0, 3.0),
	}


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var sway := float(_spec()["sway"])
	for i in _motes.size():
		var m: Dictionary = _motes[i]
		m["age"] = float(m["age"]) + delta
		if float(m["age"]) >= float(m["life"]):
			_motes[i] = _new_mote()
			continue
		var drift := Vector2(cos(_t * 0.7 + float(m["phase"])) * sway, 0.0)
		m["pos"] = (m["pos"] as Vector2) + ((m["vel"] as Vector2) + drift) * delta
	queue_redraw()


func _draw() -> void:
	var spec := _spec()
	var core: Color = spec["core"]
	var glow: Color = spec["glow"]
	var flicker := float(spec["flicker"])
	var leaf := bool(spec["leaf"])
	for m in _motes:
		var u := float(m["age"]) / float(m["life"])
		# Fade in, hold, fade out.
		var a := clampf(u / 0.15, 0.0, 1.0) * clampf((1.0 - u) / 0.3, 0.0, 1.0)
		if flicker > 0.0:
			a *= 0.55 + 0.45 * sin(_t * flicker + float(m["phase"]) * 5.0)
		if a <= 0.02:
			continue
		var pos: Vector2 = m["pos"]
		var r := float(m["size"])
		if leaf and int(float(m["phase"]) * 10.0) % 4 == 0:
			# A small tumbling leaf among the pollen.
			var ang := _t * float(m["spin"]) + float(m["phase"])
			var d := Vector2(cos(ang), sin(ang) * 0.5) * r * 2.2
			var n := Vector2(-d.y, d.x) * 0.45
			draw_colored_polygon(PackedVector2Array([pos - d, pos + n, pos + d, pos - n]), Color(0.55, 0.62, 0.25, a * 0.85))
			continue
		draw_circle(pos, r * 3.2, Color(glow.r, glow.g, glow.b, a * 0.16))
		draw_circle(pos, r * 1.6, Color(glow.r, glow.g, glow.b, a * 0.35))
		draw_circle(pos, r, Color(core.r, core.g, core.b, a))
