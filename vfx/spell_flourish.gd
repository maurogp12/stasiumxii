class_name SpellFlourish
extends Node2D

## Wakfu-style spell flourish (view only), layered on top of the recipe VFX:
## each class has its own particle "voice" — Kestrel wind feathers, Ironjaw
## rock chunks and a shockwave, Mender rising motes and a halo, Gloam violet
## smoke and shards, Bastion gold sparks and a shield flare. Triggered from
## the same resolved events the recipes read; never touches the sim or its RNG.
## Every burst frees itself.

const _Palette := preload("res://vfx/vfx_palette.gd")
const _Sort := preload("res://board/visual_sort.gd")
const CHEST := Vector2(0, -34)

## class -> [main color, accent color, voice]
const VOICES := {
	"kestrel": [Color("B8F0C8"), Color("EAF6F0"), "wind"],
	"ironjaw": [Color("C23B2E"), Color("B89468"), "earth"],
	"mender": [Color("4FD1B5"), Color("FFF4C2"), "life"],
	"gloam": [Color("9F8CFF"), Color("6B4FA0"), "shadow"],
	"bastion": [Color("F2D67A"), Color("D4A437"), "guard"],
}

## Heavy spells get a bigger finisher (extra shockwave, flash, more debris).
const FINISHERS := ["detonate", "crush", "heartstop", "nightfold", "aegis_break", "ambush"]
## Projectile look per class for ranged casts. Ironjaw and Bastion hit in melee.
const MISSILES := {
	"kestrel": "arrow",
	"mender": "orb",
	"gloam": "bolt",
}

var _elev: Callable
static var _soft: Texture2D


## 64px radial soft dot: bright core, long falloff. Built once.
static func soft_texture() -> Texture2D:
	if _soft != null:
		return _soft
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_soft = ImageTexture.create_from_image(img)
	return _soft


func _ready() -> void:
	z_as_relative = false
	# Over fighters, under Shade markers and combat numbers.
	z_index = 600


## elev(cell) -> float board elevation, so bursts sit on raised cells.
func bind_elevation(elev: Callable) -> void:
	_elev = elev


func play(events: Array, snapshot: Dictionary) -> void:
	for raw in events:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = raw
		var typ := str(event.get("type", ""))
		if typ == "snap_wall" and event.has("to"):
			_wall_slam(_at(_cell(event.get("to"))))
			continue
		if typ == "expire" and str(event.get("status", "")) == "invisible":
			# Gloam steps out of the shadows when Invisible wears off.
			var at_cell := _at(_cell(event.get("pos", Vector2i.ZERO)))
			_burst(at_cell + CHEST * 0.6, Color("6B4FA0"), 18, 70.0, 0.7, 0.0, "smoke")
			_glow(at_cell + CHEST, Color("9F8CFF"), 1.3, 0.45, 0.0)
			continue
		if typ != "hit" and typ != "miss" and typ != "cast":
			continue
		var spell_id := str(event.get("spell", ""))
		if spell_id == "":
			continue
		var class_id := _class_of(spell_id)
		if not VOICES.has(class_id):
			continue
		# The host hid this cell (Invisible caster / secret Shade): draw nothing.
		if event.has("caster_cell") and event["caster_cell"] == null:
			continue
		if spell_id == SpellKits.DROP_SHADE and not event.has("to"):
			continue
		var caster_cell := _cell(event.get("caster_cell", _seat_cell(snapshot, int(event.get("seat", -1)))))
		var to_cell := _cell(event.get("to", caster_cell))
		var voice: Array = VOICES[class_id]
		var healing := class_id == "mender"
		# Release glow and a turning rune circle under the caster.
		_glow(_at(caster_cell) + CHEST, voice[0], 0.9, 0.35, 0.0)
		_rune(_at(caster_cell), voice[0], voice[1], 0.0)
		var ranged := _reach(caster_cell, to_cell) > 1
		var delay := 0.06
		if not _same(caster_cell, to_cell):
			delay = 0.16
		if ranged and MISSILES.has(class_id):
			# The strike lands when the projectile arrives.
			delay = clampf(0.1 + 0.035 * float(_reach(caster_cell, to_cell)), 0.16, 0.34)
			_missile(_at(caster_cell) + CHEST, _at(to_cell) + CHEST, voice[0], voice[1], str(MISSILES[class_id]), delay)
		if typ == "miss":
			_burst(_at(to_cell) + CHEST * 0.4, voice[1], 8, 40.0, 0.35, delay, "puff")
			continue
		var at := _at(to_cell)
		if FINISHERS.has(spell_id) and typ == "hit":
			_finisher(at, voice[0], voice[1], delay)
		match str(voice[2]):
			"wind":
				_glow(at + CHEST, voice[1], 1.2, 0.3, delay)
				_burst(at + CHEST, voice[1], 24, 150.0, 0.5, delay, "streak")
				_burst(at + CHEST, voice[0], 14, 80.0, 0.7, delay, "feather")
				_ring(at, voice[0], 36.0, 0.36, delay)
			"earth":
				_glow(at + Vector2(0, -8), Color(1.0, 0.6, 0.3), 1.3, 0.25, delay)
				_ring(at, voice[1], 46.0, 0.34, delay)
				_ring(at, voice[0], 30.0, 0.26, delay + 0.05)
				_burst(at + Vector2(0, -6), voice[1], 16, 150.0, 0.55, delay, "rock")
			"life":
				_glow(at + CHEST, voice[1], 1.5, 0.55, delay)
				_burst(at, voice[0], 20, 45.0, 1.0, delay, "rise")
				_ring(at, voice[0], 28.0, 0.5, delay)
			"shadow":
				_burst(at + CHEST * 0.6, voice[1], 16, 60.0, 0.7, delay, "smoke")
				_burst(at + CHEST, voice[0], 12, 130.0, 0.4, delay, "shard")
			"guard":
				_glow(at + CHEST * 0.5, voice[0], 1.3, 0.35, delay)
				_burst(at + CHEST * 0.5, voice[1], 18, 140.0, 0.45, delay, "spark")
				_ring(at, voice[0], 38.0, 0.3, delay)
		if not healing and typ == "hit":
			_glow(at + CHEST, Color(1, 1, 1), 0.8, 0.12, delay)


## Kestrel and Ironjaw spells carry no class_id in the kit data; ask the kits.
static func _class_of(spell_id: String) -> String:
	var tagged := str(SpellKits.spell(spell_id).get("class_id", ""))
	if tagged != "":
		return tagged
	for class_id in VOICES.keys():
		for raw in SpellKits.class_spells(class_id):
			var sid := str(raw.get("id", raw)) if raw is Dictionary else str(raw)
			if sid == spell_id:
				return class_id
	return ""


## Bastion Snap Wall: the rampart slams up with a gold shockwave, stone chunks
## and a spark shower. The block itself is drawn by the tile.
func _wall_slam(at: Vector2) -> void:
	_ring(at, Color("F2D67A"), 44.0, 0.35, 0.05)
	_ring(at, Color("D4A437"), 28.0, 0.28, 0.1)
	_burst(at + Vector2(0, -8), Color(0.42, 0.40, 0.44), 14, 150.0, 0.55, 0.05, "rock")
	_burst(at + Vector2(0, -24), Color("F2D67A"), 20, 130.0, 0.5, 0.12, "spark")
	_glow(at + Vector2(0, -20), Color("F2D67A"), 1.6, 0.4, 0.1)


## Heavy spell: white flash, double shockwave, a tall column of light and
## extra debris in the class colours.
func _finisher(at: Vector2, main: Color, accent: Color, delay: float) -> void:
	_glow(at + CHEST, Color(1, 1, 1), 2.2, 0.22, delay)
	_glow(at + CHEST * 0.5, main, 2.6, 0.5, delay + 0.03)
	_ring(at, Color(1, 1, 1), 62.0, 0.38, delay)
	_ring(at, main, 80.0, 0.5, delay + 0.08)
	_burst(at + CHEST * 0.5, accent, 26, 220.0, 0.6, delay, "spark")
	var column := LightColumn.new()
	column.position = at
	column.color = main
	column.delay = delay
	add_child(column)


func _rune(at: Vector2, main: Color, accent: Color, delay: float) -> void:
	var rune := RuneCircle.new()
	rune.position = at
	rune.color = main
	rune.accent = accent
	rune.delay = delay
	add_child(rune)


func _missile(from: Vector2, to: Vector2, main: Color, accent: Color, style: String, travel: float) -> void:
	var m := Missile.new()
	m.from = from
	m.to = to
	m.color = main
	m.accent = accent
	m.style = style
	m.travel = travel
	add_child(m)


static func _reach(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _seat_cell(snapshot: Dictionary, seat: int) -> Vector2i:
	for unit in snapshot.get("units", []):
		if int(unit.get("seat", -2)) == seat:
			return _cell(unit.get("pos", Vector2i.ZERO))
	return Vector2i.ZERO


func _cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	return Vector2i.ZERO


func _same(a: Vector2i, b: Vector2i) -> bool:
	return a == b


func _at(cell: Vector2i) -> Vector2:
	var elev := 0.0
	if _elev.is_valid():
		elev = float(_elev.call(cell))
	return _Sort.cell_to_local(cell, elev)


func _burst(pos: Vector2, color: Color, amount: int, speed: float, life: float, delay: float, style: String) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	# Wakfu effects linger: a floor so no burst blinks out before it reads.
	p.lifetime = maxf(life * 1.4, 0.6)
	p.local_coords = false
	p.texture = soft_texture()
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.3
	p.damping_min = 20.0
	p.damping_max = 60.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	match style:
		"streak":
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.18
			p.damping_min = 80.0
			p.damping_max = 140.0
		"feather":
			p.gravity = Vector2(0, 30)
			p.angular_velocity_min = -220.0
			p.angular_velocity_max = 220.0
		"rock":
			p.direction = Vector2(0, -1)
			p.spread = 70.0
			p.gravity = Vector2(0, 520)
			p.scale_amount_min = 0.14
			p.scale_amount_max = 0.3
		"rise":
			p.explosiveness = 0.35
			p.direction = Vector2(0, -1)
			p.spread = 25.0
			p.gravity = Vector2(0, -40)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(16, 5)
		"smoke":
			p.gravity = Vector2(0, -30)
			p.scale_amount_min = 0.45
			p.scale_amount_max = 0.9
			p.damping_min = 60.0
			p.damping_max = 90.0
		"shard":
			p.gravity = Vector2(0, 60)
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.2
		"spark":
			p.gravity = Vector2(0, 260)
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.16
		"puff":
			p.gravity = Vector2(0, -20)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.55
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if style != "smoke" and style != "rock" else CanvasItemMaterial.BLEND_MODE_MIX
	p.material = add
	p.emitting = false
	add_child(p)
	_start(p, delay, life + 0.3)


func _glow(pos: Vector2, color: Color, size: float, life: float, delay: float) -> void:
	var s := Sprite2D.new()
	s.texture = soft_texture()
	s.position = pos
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	s.modulate = Color(color.r, color.g, color.b, 0.0)
	var base := Vector2.ONE * size * 1.3
	s.scale = base * 0.4
	add_child(s)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(s, "modulate:a", 0.9, life * 0.25)
	tw.parallel().tween_property(s, "scale", base, life * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, maxf(life * 1.2, 0.35))
	tw.tween_callback(s.queue_free)


func _ring(pos: Vector2, color: Color, radius: float, life: float, delay: float) -> void:
	var r := FlourishRing.new()
	r.position = pos
	r.color = color
	r.radius = radius
	r.life = maxf(life * 1.5, 0.45)
	r.delay = delay
	add_child(r)


func _start(p: CPUParticles2D, delay: float, life: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: p.emitting = true)
	tw.tween_interval(life)
	tw.tween_callback(p.queue_free)


## Expanding iso ellipse on the ground under a strike.
class FlourishRing extends Node2D:
	var color := Color.WHITE
	var radius := 30.0
	var life := 0.3
	var delay := 0.0
	var _t := -1.0

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			return
		_t = maxf(_t, 0.0) + delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		var u := _t / life
		var rx := radius * (0.3 + 0.7 * (1.0 - pow(1.0 - u, 3.0)))
		var a := (1.0 - u) * 0.9
		var pts := PackedVector2Array()
		for i in 33:
			var ang := TAU * float(i) / 32.0
			pts.append(Vector2(cos(ang) * rx, sin(ang) * rx * 0.5))
		draw_polyline(pts, Color(color.r, color.g, color.b, a), 3.0 * (1.0 - u) + 1.0, true)


## Wakfu cast circle: a flat iso ring with runes that turns and fades.
class RuneCircle extends Node2D:
	var color := Color.WHITE
	var accent := Color.WHITE
	var delay := 0.0
	var life := 0.75
	var _t := -1.0

	func _ready() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			return
		_t = maxf(_t, 0.0) + delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		var u := _t / life
		var grow := 1.0 - pow(1.0 - minf(u * 3.0, 1.0), 3.0)
		var a := (1.0 - u) * 0.85
		var r := 26.0 * grow
		var spin := _t * 2.4
		_ellipse(r, Color(color.r, color.g, color.b, a), 2.0)
		_ellipse(r * 0.72, Color(accent.r, accent.g, accent.b, a * 0.7), 1.2)
		# Six rune ticks between the rings, turning.
		for i in 6:
			var ang := spin + TAU * float(i) / 6.0
			var p0 := Vector2(cos(ang) * r * 0.74, sin(ang) * r * 0.37)
			var p1 := Vector2(cos(ang) * r * 0.98, sin(ang) * r * 0.49)
			draw_line(p0, p1, Color(color.r, color.g, color.b, a), 2.0, true)
			draw_circle(p1, 1.6, Color(1, 1, 1, a))
		# Inner star, counter-turning.
		var star := PackedVector2Array()
		for i in 7:
			var ang := -spin * 1.5 + TAU * float(i * 2 % 6) / 6.0
			star.append(Vector2(cos(ang) * r * 0.62, sin(ang) * r * 0.31))
		draw_polyline(star, Color(accent.r, accent.g, accent.b, a * 0.6), 1.2, true)

	func _ellipse(r: float, c: Color, w: float) -> void:
		var pts := PackedVector2Array()
		for i in 41:
			var ang := TAU * float(i) / 40.0
			pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.5))
		draw_polyline(pts, c, w, true)


## Projectile from caster to target with a fading trail.
## arrow: fast straight streak; orb: soft arcing ball; bolt: wobbling shadow bolt.
class Missile extends Node2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var color := Color.WHITE
	var accent := Color.WHITE
	var style := "arrow"
	var travel := 0.2
	var _t := 0.0
	var _trail: Array[Vector2] = []

	func _ready() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _head(u: float) -> Vector2:
		var p := from.lerp(to, u)
		match style:
			"orb":
				p.y -= sin(u * PI) * minf(from.distance_to(to) * 0.35, 70.0)
			"bolt":
				var n := (to - from).orthogonal().normalized()
				p += n * sin(u * TAU * 2.0) * 6.0 * (1.0 - u)
		return p

	func _process(delta: float) -> void:
		_t += delta
		var u := minf(_t / maxf(travel, 0.01), 1.0)
		if u < 1.0:
			_trail.append(_head(u))
			if _trail.size() > 10:
				_trail.remove_at(0)
		elif not _trail.is_empty():
			_trail.remove_at(0)
		if u >= 1.0 and _trail.is_empty():
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var n := _trail.size()
		for i in range(1, n):
			var k := float(i) / float(n)
			var w := (3.0 if style == "arrow" else 6.0) * k
			draw_line(_trail[i - 1], _trail[i], Color(color.r, color.g, color.b, 0.8 * k), w + 4.0, true)
			draw_line(_trail[i - 1], _trail[i], Color(1, 1, 1, 0.9 * k), maxf(w * 0.4, 1.0), true)
		var u := _t / maxf(travel, 0.01)
		if u >= 1.0:
			return
		var head := _head(u)
		var size := 3.5 if style == "arrow" else 6.0
		draw_circle(head, size * 2.2, Color(color.r, color.g, color.b, 0.35))
		draw_circle(head, size, Color(accent.r, accent.g, accent.b, 0.95))
		draw_circle(head, size * 0.45, Color(1, 1, 1, 1))


## Tall beam of light that flares up on a heavy hit and thins out.
class LightColumn extends Node2D:
	var color := Color.WHITE
	var delay := 0.0
	var life := 0.45
	var _t := -1.0

	func _ready() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _process(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			return
		_t = maxf(_t, 0.0) + delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		var u := _t / life
		var w := 22.0 * (1.0 - u)
		var h := 150.0 * (0.4 + 0.6 * minf(u * 4.0, 1.0))
		var a := (1.0 - u)
		draw_rect(Rect2(-w, -h, w * 2.0, h), Color(color.r, color.g, color.b, 0.28 * a))
		draw_rect(Rect2(-w * 0.35, -h, w * 0.7, h), Color(1, 1, 1, 0.55 * a))
