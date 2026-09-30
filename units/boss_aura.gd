extends Node2D
class_name BossAura

## Stasis boss presence (view only, Mauro 29 Sep 2026: "Monster and boss
## looking lame"). Under the boss: a slow-turning rune sigil on the ground in
## the door's colour, a pulsing glow, and motes rising around the body. The
## pawn adds it for a Room B foe and removes it when the boss falls.

## Door colour by boss art id.
const TINTS := {
	"warden_of_the_sheaves": Color(1.0, 0.72, 0.28),
	"captain_brineclaw": Color(0.25, 0.85, 0.80),
	"slagheart_the_emberbrute": Color(1.0, 0.42, 0.12),
	"serra_the_gale_sentinel": Color(0.70, 0.88, 1.0),
	"tyrant_coilspire": Color(0.66, 0.42, 1.0),
}
const RUNES := 12
const MOTES := 10

var tint := Color(1.0, 0.6, 0.3)
## The boss's own turn: the sigil flares and spins up (view only).
var active := false
var _surge := 0.0
## One-shot burst when the boss unleashes an area spell (0..1, decays).
var _flare := 0.0
## Ground radii in pawn space (the diamond is 64×32).
var radius := Vector2(40, 18)
var _t := 0.0
var _motes: Array = []


static func tint_for(art_path: String) -> Color:
	var id := art_path.get_file().get_basename()
	return TINTS.get(id, Color(1.0, 0.55, 0.3))


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in MOTES:
		_motes.append({
			"a": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(0.55, 1.0),
			"speed": rng.randf_range(18.0, 34.0),
			"phase": rng.randf_range(0.0, 1.0),
			"size": rng.randf_range(1.2, 2.4),
		})


func flare() -> void:
	_flare = 1.0


func _process(delta: float) -> void:
	_flare = move_toward(_flare, 0.0, delta * 1.6)
	_surge = move_toward(_surge, 1.0 if active else 0.0, delta * 2.5)
	_t += delta * (1.0 + 1.4 * _surge)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	var gain := 1.0 + 1.3 * _surge + 2.0 * _flare
	# Glow pool.
	for k in 4:
		var f := 1.0 - float(k) * 0.2
		_ellipse(radius * (1.15 * f + 0.1 * pulse + 0.12 * _surge), Color(tint.r, tint.g, tint.b, (0.06 + 0.03 * pulse) * gain))
	# Sigil: two rings and turning rune ticks.
	_ring(radius, Color(tint.r, tint.g, tint.b, minf(0.75 * gain, 1.0)), 1.6 + 1.2 * _surge)
	if _flare > 0.01:
		# Area spell: a wide shockwave rolls out and a white core flashes.
		var k := 1.0 - _flare
		_ring(radius * (1.0 + k * 2.2), Color(1, 1, 1, 0.9 * _flare).lerp(tint, 0.35), 3.5 * _flare + 1.0)
		_ring(radius * (0.8 + k * 1.4), Color(tint.r, tint.g, tint.b, 0.8 * _flare), 2.5)
		_ellipse(radius * (0.6 + 0.5 * _flare), Color(1, 1, 1, 0.25 * _flare))
	if _surge > 0.01:
		# Shock ring rolling out from the feet while the boss acts.
		var u := fposmod(_t * 0.6, 1.0)
		_ring(radius * (1.0 + u * 0.7), Color(tint.r, tint.g, tint.b, 0.6 * (1.0 - u) * _surge), 2.0)
	_ring(radius * 0.78, Color(tint.r, tint.g, tint.b, 0.45), 1.0)
	for i in RUNES:
		var a := _t * 0.45 + float(i) * TAU / float(RUNES)
		var p := Vector2(cos(a) * radius.x * 0.89, sin(a) * radius.y * 0.89)
		var d := Vector2(-sin(a) * radius.x, cos(a) * radius.y).normalized() * 3.2
		var bright := 0.55 + 0.45 * sin(_t * 3.0 + float(i))
		draw_line(p - d, p + d, Color(1.0, 1.0, 1.0, 0.8 * bright).lerp(tint, 0.4), 1.6, true)
	# Motes rising around the body (behind and in front share this layer).
	for m in _motes:
		var u: float = fposmod(_t * 0.35 + float(m["phase"]), 1.0)
		var a: float = float(m["a"]) + _t * 0.3
		var p := Vector2(cos(a) * radius.x * float(m["r"]), sin(a) * radius.y * float(m["r"]) - u * float(m["speed"]) * 3.0)
		var alpha := sin(u * PI)
		draw_circle(p, float(m["size"]) * 2.4, Color(tint.r, tint.g, tint.b, 0.18 * alpha))
		draw_circle(p, float(m["size"]), Color(1, 1, 1, 0.9 * alpha).lerp(tint, 0.3))


func _ellipse(r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _ring(r: Vector2, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i) / 48.0
		pts.append(Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, width, true)
