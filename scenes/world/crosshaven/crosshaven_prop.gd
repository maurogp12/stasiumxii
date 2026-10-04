extends Node2D

## VIEW ONLY. One Crosshaven prop (tree, fence, cottage, spire, centerpiece).
## Sits on the south tip of its footprint and z-sorts with `BoardVisualSort`.
##
## Art hook: `PROP_ART_ROOT/<type>.png`, drawn bottom-center on the south tip.

const PROP_ART_ROOT := "res://art/world/crosshaven/props/"
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const _SNOW_SHADER := preload("res://scenes/world/crosshaven/snow_cap.gdshader")

const SPIRE_TINT := {
	"northgate_spire": Color("7d93b8"),
	"stoneford_spire": Color("9a9488"),
	"eastmarch_spire": Color("c98c4e"),
	"westwatch_spire": Color("6f9a6a"),
	"southbridge_spire": Color("b86a6a"),
}

var prop_type := ""
var prop_id := ""
var zone_id := ""
var footprint: Array[Vector2i] = []
var south_cell := Vector2i.ZERO
var base_height := 0
## Screen rect (local) used for "player is behind me" fading.
var cover_rect := Rect2()
var base_z := 0
## 0 everywhere except Northgate and the town half of the north road.
var snow_amount := 0.0:
	set(value):
		snow_amount = value
		_sync_snow_shader()
		queue_redraw()
var _tex: Texture2D
var _fence_axis := 0  # 0: along x (NE-SW screen), 1: along y


func setup(zone: WorldZone, record: Dictionary) -> void:
	prop_type = str(record["type"])
	prop_id = str(record.get("id", prop_type))
	zone_id = zone.zone_id
	footprint.clear()
	for c in record["footprint"]:
		footprint.append(Vector2i(int(c["x"]), int(c["y"])))
	south_cell = footprint[0]
	base_height = 0
	for c in footprint:
		if c.x + c.y > south_cell.x + south_cell.y:
			south_cell = c
		base_height = maxi(base_height, zone.height_at(c))
	position = BoardVisualSort.cell_to_local(south_cell, float(base_height)) + Vector2(0, Pick.HALF_H)
	z_as_relative = false
	base_z = (south_cell.x + south_cell.y) * BoardVisualSort.TILE_Z_SCALE + 2
	z_index = base_z
	if prop_type == "fence":
		var o := footprint[0]
		var along_y := _is_fence(zone, o + Vector2i(0, 1)) or _is_fence(zone, o + Vector2i(0, -1))
		_fence_axis = 1 if along_y else 0
	_tex = _load_art()
	cover_rect = _cover_rect()
	var clutter := _clutter_scale(prop_type)
	if clutter != 1.0:
		scale = Vector2(clutter, clutter)
		cover_rect = Rect2(cover_rect.position * clutter, cover_rect.size * clutter)
	_attach_loops()
	_apply_theme_tint()
	queue_redraw()


var _sway: AnimatedSprite2D
var _shadow_sway: AnimatedSprite2D
var _overlay: AnimatedSprite2D
var _snow_plate: Sprite2D
var _loops_ready := false


func _attach_loops() -> void:
	var sway_id := art_id + "_sway"
	if Art.anim_meta(sway_id).is_empty() and prop_type == "tree":
		sway_id = "tree_sway"
	_sway = Art.make_loop(sway_id)
	if _sway != null:
		_sway.visible = false
		_sway.z_index = 1
		add_child(_sway)
	_shadow_sway = Art.make_loop(art_id + "_shadow_sway")
	if _shadow_sway != null:
		_shadow_sway.visible = false
		_shadow_sway.z_index = 0
		add_child(_shadow_sway)
	var overlay_id := ""
	if prop_type == "windmill_2x2_body":
		overlay_id = "windmill_sails_v5"
	elif prop_type == "watermill_2x2_body":
		overlay_id = "watermill_wheel_v6"
	elif prop_type == "fountain_2x2":
		overlay_id = "fountain_water"
	elif prop_type == "bakery_2x2" or prop_type == "smithy_2x2" or prop_type == "red_roof_cottage" or prop_type == "farmhouse_2x2" or prop_type == "tavern_3x2":
		overlay_id = "smoke_puff"
	_overlay = Art.make_loop(overlay_id) if overlay_id != "" else null
	if _overlay != null:
		_overlay.visible = false
		_overlay.z_as_relative = true
		_overlay.z_index = 2
		if prop_type == "windmill_2x2_body":
			_overlay.position = Vector2(0, -104)
		elif overlay_id == "smoke_puff":
			_overlay.position = Vector2(cover_rect.position.x + cover_rect.size.x * 0.72, cover_rect.position.y + 12.0)
			_overlay.modulate = Color(1, 1, 1, 0.8)
		add_child(_overlay)
	_loops_ready = true


func _process(_delta: float) -> void:
	if not _loops_ready:
		return
	var anim_on := VisualSettings.current != null and VisualSettings.current.enabled("animations")
	var shadow_on := anim_on and VisualSettings.current != null and VisualSettings.current.enabled("sway_shadows")
	var changed := false
	if _sway != null and _sway.visible != anim_on:
		_sway.visible = anim_on
		changed = true
	if _shadow_sway != null and _shadow_sway.visible != shadow_on:
		_shadow_sway.visible = shadow_on
	if _overlay != null and _overlay.visible != anim_on:
		_overlay.visible = anim_on
	if changed:
		_sync_snow_shader()
		queue_redraw()


## Kit art id for this placement: fences along y use `fence_wood_nesw`,
## trees and cottages pick a variant by hash of their origin (kit README).
var art_id := ""
var _art: Dictionary = {}


## Hay sits with the sunflowers. Hedges stay a shoulder-high barrier.
## Buildings, trees, mills and gates are left at full size.
func _clutter_scale(kind: String) -> float:
	match kind:
		"hay_bale", "haystack":
			return 0.58
		"hedgerow_nesw", "hedgerow_nwse":
			return 0.62
		_:
			return 1.0


func _load_art() -> Texture2D:
	art_id = Art.prop_art_id(prop_type, footprint[0], _fence_axis, zone_id)
	_art = Art.texture("props", art_id)
	if _art.is_empty() and art_id != prop_type:
		art_id = prop_type
		_art = Art.texture("props", prop_type)
	return _art.get("tex", null)


func has_art() -> bool:
	return _tex != null


func _is_fence(zone: WorldZone, cell: Vector2i) -> bool:
	for p in zone.props:
		if str(p["type"]) != "fence":
			continue
		for c in p["footprint"]:
			if int(c["x"]) == cell.x and int(c["y"]) == cell.y:
				return true
	return false


func _cover_rect() -> Rect2:
	if _tex != null:
		var s := Art.size_of(_art)
		return Rect2(-s.x * 0.5, -s.y, s.x, s.y)
	match prop_type:
		"tree":
			return Rect2(-22, -64, 44, 64)
		"fence":
			return Rect2(-32, -20, 64, 20)
		"red_roof_cottage":
			return Rect2(-64, -96, 128, 96)
		"crossroads_centerpiece":
			return Rect2(-40, -120, 80, 120)
		_:
			return Rect2(-40, -180, 80, 180)


## Feet north of the base, inside the sprite, are behind the prop.
## Pull the prop in front of the character and fade it so they stay readable.
func update_cover(walker_pos: Vector2, walker_z: int) -> void:
	var local := walker_pos - position
	var overlap := cover_rect.grow(6).has_point(local)
	# The south-cell center sits 16px above the sprite foot. Fading only above
	# that keeps a character on the front of the prop drawn over the base.
	var behind := local.y < -20.0
	var hide := overlap and behind and prop_type != "fence" and cover_rect.size.y > 36.0
	if hide:
		z_index = walker_z + 1
		# Flat alpha of this sprite only. Roof strokes at a partial fade read as a hatch,
		# so the hero also gets a soft rim above this (see the walker).
		modulate.a = 0.45
	else:
		z_index = base_z
		modulate.a = 1.0


func _draw() -> void:
	var swayed := _sway != null and _sway.visible
	if not swayed:
		if _tex != null:
			var s := Art.size_of(_art)
			Art.draw_at(self, _art, Vector2(-s.x * 0.5, -s.y))
			_draw_window_glow(s)
		else:
			match prop_type:
				"tree":
					_draw_tree()
				"fence":
					_draw_fence()
				"red_roof_cottage":
					_draw_cottage()
				"crossroads_centerpiece":
					_draw_centerpiece()
				_:
					_draw_spire(SPIRE_TINT.get(prop_type, Color("8a8a8a")))
	_paint_snow_cap()


func _paint_snow_cap() -> void:
	if snow_amount <= 0.05:
		return
	var kind := _snow_kind()
	var swayed := _sway != null and _sway.visible
	if kind != "" and not swayed and _tex != null and _snow_plate == null:
		_stamp_masked_cap(kind)
	if _snow_gathers_at_base():
		_paint_drifts()


## Roof, foliage, or rail. Barrels, stalls, crates and carts stay bare.
func _snow_kind() -> String:
	var name := prop_type + " " + art_id
	for token in ["barrel", "stall", "crate", "cart", "sign", "lamp", "well", "brazier", "hay", "scarecrow", "rowboat", "net_rack", "waystone"]:
		if name.find(token) >= 0:
			return ""
	for token in ["cottage", "house", "farmhouse", "tavern", "bakery", "smithy", "mill", "spire", "watchtower", "hut", "barn", "centerpiece"]:
		if name.find(token) >= 0:
			return "roof"
	for token in ["tree", "pine", "oak", "birch"]:
		if name.find(token) >= 0:
			return "tree"
	for token in ["fence", "wall", "hedge"]:
		if name.find(token) >= 0:
			return "fence"
	return ""


func _cap_band(kind: String) -> float:
	if kind == "tree":
		return 0.58
	if kind == "fence":
		return 0.30
	return 0.62


func _cap_strength(kind: String) -> float:
	var amount := clampf(snow_amount, 0.0, 1.0)
	if kind == "tree":
		return amount * 0.95
	if kind == "fence":
		return amount * 0.8
	return amount


## Upper slope only, and only where the sprite itself is opaque.
func _stamp_masked_cap(kind: String) -> void:
	var full := _tex.get_size()
	var shown := Art.size_of(_art)
	var band := _cap_band(kind)
	var src := Rect2(0, 0, full.x, full.y * band)
	var dst := Rect2(-shown.x * 0.5, -shown.y, shown.x, shown.y * band)
	draw_texture_rect_region(_tex, dst, src, Color(1, 1, 1, _cap_strength(kind)))


func _sync_snow_shader() -> void:
	var kind := _snow_kind()
	if _sway != null:
		if snow_amount <= 0.05 or kind == "" or not _sway.visible:
			_sway.material = null
		else:
			var mat := ShaderMaterial.new()
			mat.shader = _SNOW_SHADER
			mat.set_shader_parameter("snow_amount", _cap_strength(kind))
			mat.set_shader_parameter("cap", _cap_band(kind))
			_sway.material = mat
	_sync_snow_plate(kind)


## Still prop (sway hidden). The shader paints the roof slope white.
## A modulate multiply cannot, so the cap is a second sprite.
func _sync_snow_plate(kind: String) -> void:
	var show := snow_amount > 0.05 and kind != "" and _tex != null and (_sway == null or not _sway.visible)
	if not show:
		if _snow_plate != null:
			_snow_plate.visible = false
		return
	if _snow_plate == null:
		_snow_plate = Sprite2D.new()
		_snow_plate.centered = false
		_snow_plate.texture = _tex
		var sc := float(_art.get("scale", 1.0))
		_snow_plate.scale = Vector2(sc, sc)
		var s := Art.size_of(_art)
		_snow_plate.position = Vector2(-s.x * 0.5, -s.y)
		_snow_plate.z_as_relative = true
		_snow_plate.z_index = 1
		var mat := ShaderMaterial.new()
		mat.shader = _SNOW_SHADER
		_snow_plate.material = mat
		add_child(_snow_plate)
	var plate_mat := _snow_plate.material as ShaderMaterial
	plate_mat.set_shader_parameter("snow_amount", _cap_strength(kind))
	plate_mat.set_shader_parameter("cap", _cap_band(kind))
	_snow_plate.visible = true


func _paint_drifts() -> void:
	var amount := clampf(snow_amount, 0.0, 1.0)
	var salt := _hash_prop()
	var frost := Color(0.96, 0.98, 1.0, 0.62 * amount)
	var soft := Color(0.93, 0.96, 1.0, 0.4 * amount)
	_snow_blob(Vector2(-14.0 + salt * 8.0, 7.0), 13.0 + salt * 5.0, 4.2, frost, salt)
	_snow_blob(Vector2(11.0, 9.0), 8.0 + salt * 3.0, 3.2, soft, salt + 1.7)
	_snow_blob(Vector2(-2.0, 5.0), 6.0, 2.4, Color(1, 1, 1, 0.35 * amount), salt + 0.4)


func _snow_blob(at: Vector2, rx: float, ry: float, tint: Color, salt: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * float(i) / 9.0
		var wobble := 0.72 + 0.28 * absf(sin(a * 3.0 + salt * 5.0))
		pts.append(at + Vector2(cos(a) * rx * wobble, sin(a) * ry * wobble))
	draw_colored_polygon(pts, tint)


func _hash_prop() -> float:
	var h := (south_cell.x * 73856093) ^ (south_cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 1000) / 1000.0


func _snow_gathers_at_base() -> bool:
	var name := prop_type + " " + art_id
	for token in ["tree", "fence", "wall", "hedge"]:
		if name.find(token) >= 0:
			return true
	return false


## Dead wood in the blight, olive trunks in the swamp, warm crowns on the beach.
func _apply_theme_tint() -> void:
	var kind := _snow_kind()
	if zone_id.find("westwatch") >= 0 and kind == "tree":
		modulate = Color(0.55, 0.48, 0.66)
	elif zone_id.find("southbridge") >= 0 and kind == "tree":
		modulate = Color(0.66, 0.70, 0.55)
	elif zone_id.find("eastmarch") >= 0 and kind == "tree":
		modulate = Color(0.98, 0.92, 0.80)


func _draw_window_glow(s: Vector2) -> void:
	if VisualSettings.current == null or not VisualSettings.current.enabled("post_fx"):
		return
	if not _glows():
		return
	var a := Vector2(-s.x * 0.18, -s.y * 0.38)
	var b := Vector2(s.x * 0.16, -s.y * 0.46)
	draw_circle(a, 2.4, Color(1.0, 0.96, 0.72, 1.0))
	draw_circle(b, 1.8, Color(1.0, 0.9, 0.55, 0.95))


func _glows() -> bool:
	for token in ["cottage", "house", "tavern", "bakery", "smithy", "mill"]:
		if prop_type.contains(token):
			return true
	return false


func _shadow(rx: float, ry: float, cy: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * rx, cy + sin(a) * ry))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))


## Box with its south corner at `south`, half sizes in cells (hx along +x, hy along +y).
func _iso_box(south: Vector2, hx: float, hy: float, tall: float, wall: Color) -> PackedVector2Array:
	var ex := Vector2(Pick.HALF_W, -Pick.HALF_H) * hx  # toward east corner
	var wy := Vector2(-Pick.HALF_W, -Pick.HALF_H) * hy  # toward west corner
	var up := Vector2(0, -tall)
	var s := south
	var e := s + ex
	var w := s + wy
	var n := s + ex + wy
	draw_colored_polygon(PackedVector2Array([w, s, s + up, w + up]), wall)
	draw_colored_polygon(PackedVector2Array([s, e, e + up, s + up]), wall.darkened(0.2))
	var top := PackedVector2Array([s + up, e + up, n + up, w + up])
	draw_colored_polygon(top, wall.lightened(0.15))
	return top


func _draw_tree() -> void:
	_shadow(18, 7, -Pick.HALF_H)
	var base := Vector2(0, -Pick.HALF_H)
	draw_rect(Rect2(base.x - 3, base.y - 18, 6, 18), Color("6b4a2c"))
	draw_circle(base + Vector2(0, -34), 17, Color("4f7d3a"))
	draw_circle(base + Vector2(-9, -28), 12, Color("5d8c40"))
	draw_circle(base + Vector2(8, -40), 11, Color("6c9c48"))
	draw_circle(base + Vector2(4, -30), 9, Color("7aa852"))


func _draw_fence() -> void:
	var c := Vector2(0, -Pick.HALF_H)
	var d := Vector2(Pick.HALF_W, -Pick.HALF_H) * 0.5 if _fence_axis == 0 else Vector2(-Pick.HALF_W, -Pick.HALF_H) * 0.5
	var a := c - d
	var b := c + d
	var wood := Color("8a6440")
	for p in [a, c, b]:
		draw_line(p, p + Vector2(0, -14), wood.darkened(0.15), 3.0)
	draw_line(a + Vector2(0, -11), b + Vector2(0, -11), wood, 2.0)
	draw_line(a + Vector2(0, -5), b + Vector2(0, -5), wood, 2.0)


func _draw_cottage() -> void:
	_shadow(54, 18, -Pick.HALF_H * 2)
	var south := Vector2(0, -6)
	var wall := Color("e6d6b4")
	var top := _iso_box(south, 1.7, 1.7, 30, wall)
	# Door and window on the south-west wall.
	var wy := Vector2(-Pick.HALF_W, -Pick.HALF_H)
	var door := south + wy * 0.55
	draw_colored_polygon(PackedVector2Array([door, door + wy * 0.25, door + wy * 0.25 + Vector2(0, -16), door + Vector2(0, -16)]), Color("6b4a2c"))
	var win := south + wy * 1.2 + Vector2(0, -12)
	draw_colored_polygon(PackedVector2Array([win, win + wy * 0.22, win + wy * 0.22 + Vector2(0, -8), win + Vector2(0, -8)]), Color("8fb6d0"))
	# Hip roof.
	var peak := (top[0] + top[2]) * 0.5 + Vector2(0, -26)
	var roof := Color("b8443a")
	var eave := Vector2(0, 4)
	draw_colored_polygon(PackedVector2Array([top[3] + eave, top[0] + eave, peak]), roof)
	draw_colored_polygon(PackedVector2Array([top[0] + eave, top[1] + eave, peak]), roof.darkened(0.22))
	draw_colored_polygon(PackedVector2Array([top[1] + eave, top[2], peak]), roof.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([top[2], top[3] + eave, peak]), roof.lightened(0.08))
	var chimney := top[1] + (peak - top[1]) * 0.45
	draw_rect(Rect2(chimney.x - 3, chimney.y - 14, 6, 14), Color("7a6a5a"))


func _draw_spire(tint: Color) -> void:
	_shadow(40, 14, -Pick.HALF_H * 2)
	var south := Vector2(0, -12)
	var base_top := _iso_box(south, 1.3, 1.3, 14, Color("a49c8c"))
	var tower_south := (base_top[0] + base_top[2]) * 0.5 + Vector2(0, Pick.HALF_H * 0.7)
	var top := _iso_box(tower_south, 0.7, 0.7, 120, tint.lerp(Color("cfc6b2"), 0.55))
	var peak := (top[0] + top[2]) * 0.5 + Vector2(0, -44)
	draw_colored_polygon(PackedVector2Array([top[3], top[0], peak]), tint)
	draw_colored_polygon(PackedVector2Array([top[0], top[1], peak]), tint.darkened(0.25))
	draw_line(peak, peak + Vector2(0, -12), Color("5a4a3a"), 2.0)
	draw_colored_polygon(PackedVector2Array([peak + Vector2(0, -12), peak + Vector2(12, -9), peak + Vector2(0, -6)]), tint.lightened(0.2))
	var slit := (top[0] + top[3]) * 0.5 + Vector2(0, 40)
	draw_rect(Rect2(slit.x - 2, slit.y - 9, 4, 9), Color(0.15, 0.12, 0.1, 0.8))


func _draw_centerpiece() -> void:
	_shadow(46, 16, -Pick.HALF_H * 2)
	var south := Vector2(0, -6)
	var t1 := _iso_box(south, 1.6, 1.6, 8, Color("b9ad94"))
	var s2 := (t1[0] + t1[2]) * 0.5 + Vector2(0, Pick.HALF_H * 1.1)
	var t2 := _iso_box(s2, 1.1, 1.1, 8, Color("c9bea6"))
	var s3 := (t2[0] + t2[2]) * 0.5 + Vector2(0, Pick.HALF_H * 0.45)
	var t3 := _iso_box(s3, 0.45, 0.45, 64, Color("ddd3bc"))
	var peak := (t3[0] + t3[2]) * 0.5 + Vector2(0, -18)
	draw_colored_polygon(PackedVector2Array([t3[3], t3[0], peak]), Color("e8dfca"))
	draw_colored_polygon(PackedVector2Array([t3[0], t3[1], peak]), Color("c4b99f"))
	draw_circle(peak + Vector2(0, -10), 7, Color(1.0, 0.86, 0.45))
	draw_circle(peak + Vector2(0, -10), 11, Color(1.0, 0.86, 0.45, 0.25))
