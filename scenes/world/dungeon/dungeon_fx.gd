extends RefCounted

## VIEW ONLY. Dungeon effects: a ranged monster's projectile and impact puff
## (the Sling Rat's stone, the Book Wraith's frost bolt). The shot leaves at
## the attack's release frame, flies to the target and bursts. Art from the
## manifest (projectiles[] / star5.projectiles[], the attack's `impact` puff)
## when present, else drawn stand-ins coloured by the run file's
## view.projectiles styles (a grey stone, a green pellet, a blue bolt).

const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const RELEASE_SEC := 0.22
const FLIGHT_SEC := 0.26
const PUFF_SEC := 0.32


## Returns how long the throw keeps the view busy.
static func throw(parent: Node2D, man: Dictionary, kind: String, from: Vector2, to: Vector2, hit: bool, z: int, release: float = RELEASE_SEC, impact: String = "", styles: Dictionary = {}) -> float:
	var shot := Shot.new()
	shot.kind = kind
	var pk := Art.projectile_kit(man, kind)
	shot.tex = pk.get("tex", null)
	shot.tex_scale = float(pk.get("scale", 1.0))
	shot.glow = pk.get("glow", null)
	var green := kind.begins_with("rad")
	var st: Dictionary = styles.get(kind, {})
	var imp: Dictionary = styles.get(impact, {})
	shot.core = _col(st.get("color", null), Color(0.55, 1.0, 0.35) if green else Color(0.62, 0.58, 0.52))
	shot.halo = _col(st.get("glow", null), Color(0.5, 1.0, 0.3, 0.3) if green else Color(0, 0, 0, 0))
	shot.puff_col = _col(st.get("puff", imp.get("color", null)), Color(0.6, 1.0, 0.35) if green else Color(0.85, 0.8, 0.7))
	shot.spin = bool(st.get("spin", true))
	shot.draw_glow = bool(st.get("draw_glow", false))
	shot.glow_scale = float(pk.get("glow_scale", 1.0))
	var puff := Art.projectile_kit(man, impact) if impact != "" else {}
	shot.puff = puff.get("tex", null)
	shot.puff_scale = float(puff.get("scale", 1.0))
	shot.hit = hit
	shot.position = from
	shot.z_as_relative = false
	shot.z_index = z
	shot.visible = false
	parent.add_child(shot)
	var tw := shot.create_tween()
	tw.tween_interval(release)
	tw.tween_callback(func(): shot.visible = true)
	var mid := (from + to) * 0.5 + Vector2(0, -minf(from.distance_to(to) * 0.15 + 12.0, 36.0))
	# A bolt that is not spun (frost_bolt points along +x) turns to its flight.
	tw.tween_method(func(t: float):
		var at := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		var tangent := (mid - from).lerp(to - mid, t)
		if tangent.length_squared() > 0.01:
			shot.heading = tangent.angle()
		shot.position = at, 0.0, 1.0, FLIGHT_SEC)
	tw.tween_callback(shot.burst)
	tw.tween_interval(PUFF_SEC)
	tw.tween_callback(shot.queue_free)
	return release + FLIGHT_SEC + PUFF_SEC


static func _col(v: Variant, fallback: Color) -> Color:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() < 3:
		return fallback
	return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if (v as Array).size() > 3 else 1.0)


class Shot extends Node2D:
	var kind := ""
	var core := Color(0.62, 0.58, 0.52)
	var halo := Color(0, 0, 0, 0)
	var puff_col := Color(0.85, 0.8, 0.7)
	var spin := true
	var heading := 0.0
	## Draw the manifest's additive glow map with the shot (style draw_glow).
	var draw_glow := false
	var glow_scale := 1.0
	var tex: Texture2D
	var tex_scale := 1.0
	var glow: Texture2D
	var puff: Texture2D
	var puff_scale := 1.0
	var hit := true
	var _puff := -1.0
	var _t := 0.0

	func burst() -> void:
		_puff = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _puff >= 0.0:
			_puff += delta
		queue_redraw()

	func _draw() -> void:
		if _puff < 0.0:
			if tex != null:
				# Spin ~720 deg/s (a thrown stone), centred on the flight point.
				draw_set_transform(Vector2.ZERO, _t * TAU * 2.0 if spin else heading, Vector2.ONE)
				var s := tex.get_size() * tex_scale
				draw_texture_rect(tex, Rect2(-s * 0.5, s), false)
				if draw_glow and glow != null:
					var gs := glow.get_size() * glow_scale
					draw_texture_rect(glow, Rect2(-gs * 0.5, gs), false, Color(1, 1, 1, 0.8))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				if halo.a > 0.0:
					draw_circle(Vector2.ZERO, 7.0, halo)
				draw_circle(Vector2.ZERO, 3.5, core)
			return
		var u := clampf(_puff / 0.25, 0.0, 1.0)
		if puff != null:
			# Quick scale-up and fade at the hit point.
			var s2 := puff.get_size() * puff_scale * (0.6 + 0.7 * u)
			draw_texture_rect(puff, Rect2(-s2 * 0.5, s2), false, Color(1, 1, 1, 1.0 - u) if hit else Color(1, 1, 1, 0.6 * (1.0 - u)))
			return
		var col := Color(puff_col.r, puff_col.g, puff_col.b, 1.0 - u)
		if not hit:
			col.a *= 0.6
		for k in 6:
			var a := TAU * float(k) / 6.0
			draw_circle(Vector2(cos(a), sin(a) * 0.6) * (4.0 + 16.0 * u), 3.0 * (1.0 - u) + 1.0, col)
