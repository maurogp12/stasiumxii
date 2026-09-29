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
		if typ != "hit" and typ != "miss" and typ != "cast":
			continue
		var spell_id := str(event.get("spell", ""))
		if spell_id == "":
			continue
		var class_id := _class_of(spell_id)
		if not VOICES.has(class_id):
			continue
		var caster_cell := _cell(event.get("caster_cell", _seat_cell(snapshot, int(event.get("seat", -1)))))
		var to_cell := _cell(event.get("to", caster_cell))
		var voice: Array = VOICES[class_id]
		var healing := class_id == "mender"
		# Release glow on the caster for every committed spell.
		_glow(_at(caster_cell) + CHEST, voice[0], 0.9, 0.35, 0.0)
		if typ == "miss":
			_burst(_at(to_cell) + CHEST * 0.4, voice[1], 8, 40.0, 0.35, 0.05, "puff")
			continue
		var delay := 0.16 if not _same(caster_cell, to_cell) else 0.06
		var at := _at(to_cell)
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
