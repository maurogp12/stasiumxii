extends "res://vfx/vfx_pooled.gd"

## Attached status marker. Follows a pawn without parenting, so a pawn rebuild cannot free the pool.

var follow: Callable = Callable()
var kind: String = ""
var _phase: float = 0.0
var _speed: float = 3.0
var _tint: Color = VfxPalette.STUN
var _pulse_left: float = 0.0
var _life: float = -1.0
var _aim: Vector2 = Vector2.RIGHT
var _count: int = 1
var _glow: bool = false


func play(spec: Dictionary) -> void:
	_begin()
	kind = str(spec.get("status", "stun"))
	_tint = spec.get("tint", _tint_for(kind))
	_phase = 0.0
	_speed = 3.0 if kind == "stun" else 5.0
	_pulse_left = 0.0
	_life = float(spec.get("life", -1.0))
	_count = maxi(int(spec.get("count", 1)), 0)
	_glow = bool(spec.get("glow", false))
	if kind == "impact":
		_glow = _glow or _count >= 4
	elif kind == "aegis":
		_glow = _glow or _count >= 3
	var aim: Variant = spec.get("aim", Vector2.RIGHT)
	_aim = aim if aim is Vector2 else Vector2.RIGHT
	z_as_relative = false
	z_index = int(spec.get("z", 120))
	if spec.has("pos"):
		position = spec["pos"]
	queue_redraw()


func retarget(spec: Dictionary) -> void:
	if spec.has("pos"):
		position = spec["pos"]
	if spec.has("status"):
		kind = str(spec["status"])
	_tint = spec.get("tint", _tint)
	if spec.has("count"):
		_count = maxi(int(spec["count"]), 0)
	if spec.has("glow"):
		_glow = bool(spec["glow"])
	if kind == "impact":
		_glow = _glow or _count >= 4
	elif kind == "aegis":
		_glow = _glow or _count >= 3
	queue_redraw()


func pulse(sec: float) -> void:
	_speed = 9.0
	_pulse_left = sec


func dismiss() -> void:
	if not in_use:
		return
	follow = Callable()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.finished.connect(release, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if follow.is_valid():
		var at: Variant = follow.call()
		if at is Vector2:
			position = at
	_phase += delta * _speed
	if _pulse_left > 0.0:
		_pulse_left -= delta
		if _pulse_left <= 0.0:
			_speed = 3.0 if kind == "stun" else 5.0
	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			_life = -1.0
			dismiss()
	queue_redraw()


func _draw() -> void:
	match kind:
		"stun":
			_draw_stun()
		"burn":
			_draw_burn()
		"shield":
			_draw_shield()
		"chevron":
			_draw_chevron()
		"marks":
			_draw_marks()
		"impact":
			_draw_pips(VfxPalette.IRONJAW, VfxPalette.IRONJAW_EARTH, 4)
		"aegis":
			_draw_pips(VfxPalette.BASTION_PALE if _glow else VfxPalette.BASTION, VfxPalette.BASTION_BLACK, 4)
		"umbral":
			_draw_wisps()
		"pulse":
			_draw_lantern()
		"hit_immunity":
			_draw_immunity()
		"skip_next_mp":
			_draw_tag("0 MP", VfxPalette.MENDER_DEEP)
		"exit_tax":
			_draw_chain()
		"invisible":
			_draw_invisible()
		"slash":
			_draw_slash()
		"wash":
			_draw_wash()
		_:
			draw_arc(Vector2(0, -16), 16.0, 0, TAU, 20, _tint, 1.5, true)


func _draw_stun() -> void:
	for i in 3:
		var ang := _phase * 1.4 + TAU * float(i) / 3.0
		var at := Vector2(cos(ang) * 14.0, sin(ang) * 6.0 - 46.0)
		draw_circle(at, 4.2, VfxPalette.OUTLINE)
		draw_circle(at, 3.0, _tint)


func _draw_burn() -> void:
	var flicker := 0.75 + 0.25 * sin(_phase * 9.0)
	var base := Vector2(0, -6)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0, -16.0 * flicker),
		base + Vector2(6, 0),
		base + Vector2(0, -4),
		base + Vector2(-6, 0),
	]), VfxPalette.BURN)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0, -10.0 * flicker),
		base + Vector2(3, -2),
		base + Vector2(-3, -2),
	]), VfxPalette.EMBER)


func _draw_shield() -> void:
	draw_arc(Vector2(0, -24), 18.0, 0, TAU, 24, VfxPalette.OUTLINE, 3.0, true)
	draw_arc(Vector2(0, -24), 18.0, 0, TAU, 24, _tint, 1.5, true)


func _draw_chevron() -> void:
	var tip: Vector2 = _tint_dir()
	var side := Vector2(-tip.y, tip.x)
	var a := tip * 10.0
	var b := -tip * 4.0 + side * 6.0
	var c := -tip * 4.0 - side * 6.0
	draw_colored_polygon(PackedVector2Array([a, b, c]), VfxPalette.OUTLINE)
	draw_colored_polygon(PackedVector2Array([a * 0.72, b * 0.55, c * 0.55]), _tint)


func _tint_dir() -> Vector2:
	if _aim.length_squared() < 0.01:
		return Vector2.RIGHT
	return _aim.normalized()


func _draw_marks() -> void:
	var n := mini(maxi(_count, 1), 5)
	for i in n:
		var ang := _phase * 0.6 + TAU * float(i) / float(n)
		var at := Vector2(cos(ang) * 16.0, sin(ang) * 7.0 - 4.0)
		_chevron_at(at, Vector2(cos(ang), sin(ang) * 0.45), VfxPalette.KESTREL)


func _draw_pips(fill: Color, core: Color, cap: int) -> void:
	var n := mini(maxi(_count, 1), cap)
	for i in n:
		var ang := _phase * 0.8 + TAU * float(i) / float(cap)
		var at := Vector2(cos(ang) * 14.0, sin(ang) * 6.0 - 2.0)
		var radius := 4.2 if _glow else 3.2
		draw_circle(at, radius + 1.2, VfxPalette.OUTLINE)
		draw_circle(at, radius, fill)
		draw_circle(at, 1.3, core if not _glow else VfxPalette.MENDER_CORE)


func _draw_wisps() -> void:
	var n := mini(maxi(_count, 1), 4)
	for i in n:
		var ang := _phase * 1.3 + TAU * float(i) / float(n)
		var at := Vector2(cos(ang) * 12.0, sin(ang) * 8.0 - 18.0)
		draw_circle(at, 4.0, VfxPalette.OUTLINE)
		draw_circle(at, 2.6, VfxPalette.GLOAM_RIM)


func _draw_lantern() -> void:
	var alpha := clampf(0.2 + 0.1 * float(mini(_count, 6)), 0.2, 0.8)
	var pulse := 0.85 + 0.15 * sin(_phase * 3.0)
	draw_circle(Vector2(0, -22), 8.0 * pulse, Color(VfxPalette.MENDER_CORE.r, VfxPalette.MENDER_CORE.g, VfxPalette.MENDER_CORE.b, alpha))
	draw_arc(Vector2(0, -22), 9.0, 0, TAU, 16, VfxPalette.MENDER, 1.4, true)


func _draw_immunity() -> void:
	var pulse := 0.9 + 0.1 * sin(_phase * 2.4)
	draw_arc(Vector2(0, -22), 20.0 * pulse, 0, TAU, 28, VfxPalette.OUTLINE, 3.0, true)
	draw_arc(Vector2(0, -22), 20.0 * pulse, 0, TAU, 28, VfxPalette.MENDER, 1.4, true)
	draw_arc(Vector2(0, -22), 16.0 * pulse, 0, PI, 16, VfxPalette.BASTION_PALE, 1.4, true)


func _draw_chain() -> void:
	draw_arc(Vector2(-6, -6), 5.0, 0, TAU, 12, VfxPalette.OUTLINE, 2.4, true)
	draw_arc(Vector2(6, -6), 5.0, 0, TAU, 12, VfxPalette.OUTLINE, 2.4, true)
	draw_arc(Vector2(-6, -6), 5.0, 0, TAU, 12, VfxPalette.BASTION, 1.3, true)
	draw_arc(Vector2(6, -6), 5.0, 0, TAU, 12, VfxPalette.BASTION, 1.3, true)
	_draw_tag("+1 MP", VfxPalette.BASTION)


func _draw_invisible() -> void:
	var y := -20.0
	for i in 10:
		var a0 := TAU * float(i) / 10.0 + _phase * 0.4
		var a1 := a0 + 0.28
		draw_arc(Vector2(0, y), 16.0, a0, a1, 4, VfxPalette.GLOAM_RIM, 2.0, true)
	draw_arc(Vector2(0, y), 16.0, 0, TAU, 24, Color(VfxPalette.GLOAM_VOID.r, VfxPalette.GLOAM_VOID.g, VfxPalette.GLOAM_VOID.b, 0.0), 1.0, true)


func _draw_slash() -> void:
	draw_line(Vector2(-14, -36), Vector2(14, -8), VfxPalette.OUTLINE, 4.0, true)
	draw_line(Vector2(-14, -8), Vector2(14, -36), VfxPalette.OUTLINE, 4.0, true)
	draw_line(Vector2(-14, -36), Vector2(14, -8), VfxPalette.KESTREL_AIR, 1.4, true)
	draw_line(Vector2(-14, -8), Vector2(14, -36), VfxPalette.GLOAM_RIM, 2.2, true)


func _draw_wash() -> void:
	var fade := clampf(_life / 0.28, 0.0, 1.0) if _life > 0.0 else 1.0
	draw_line(Vector2(0, -40), Vector2(0, 4), Color(VfxPalette.MENDER_CREAM.r, VfxPalette.MENDER_CREAM.g, VfxPalette.MENDER_CREAM.b, 0.85 * fade), 10.0, true)
	draw_line(Vector2(0, -36), Vector2(0, 0), Color(1, 1, 1, 0.55 * fade), 3.0, true)


func _draw_tag(text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var origin := Vector2(-size.x * 0.5, -44.0)
	font.draw_string(get_canvas_item(), origin + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, VfxPalette.OUTLINE)
	font.draw_string(get_canvas_item(), origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _chevron_at(at: Vector2, aim: Vector2, tint: Color) -> void:
	var tip := aim.normalized() if aim.length_squared() > 0.01 else Vector2.UP
	var side := Vector2(-tip.y, tip.x)
	var a := at + tip * 6.0
	var b := at - tip * 3.0 + side * 3.5
	var c := at - tip * 3.0 - side * 3.5
	draw_colored_polygon(PackedVector2Array([a, b, c]), VfxPalette.OUTLINE)
	draw_colored_polygon(PackedVector2Array([at + tip * 4.2, at - tip * 1.4 + side * 2.2, at - tip * 1.4 - side * 2.2]), tint)


func _tint_for(status: String) -> Color:
	match status:
		"burn":
			return VfxPalette.BURN
		"shield":
			return VfxPalette.SHIELD_TOP
		"chevron", "marks":
			return VfxPalette.KESTREL
		"impact":
			return VfxPalette.IRONJAW
		"aegis", "exit_tax":
			return VfxPalette.BASTION
		"umbral", "invisible", "slash":
			return VfxPalette.GLOAM_RIM
		"pulse", "hit_immunity", "skip_next_mp", "wash":
			return VfxPalette.MENDER
		_:
			return VfxPalette.STUN


func release() -> void:
	follow = Callable()
	kind = ""
	_life = -1.0
	_aim = Vector2.RIGHT
	_count = 1
	_glow = false
	super.release()
