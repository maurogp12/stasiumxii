extends Node2D

## VIEW ONLY. One Crosshaven prop (tree, fence, cottage, spire, centerpiece).
## Sits on the south tip of its footprint and z-sorts with `BoardVisualSort`.
##
## Art hook: `PROP_ART_ROOT/<type>.png`, drawn bottom-center on the south tip.

const PROP_ART_ROOT := "res://art/world/crosshaven/props/"
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

const SPIRE_TINT := {
	"northgate_spire": Color("7d93b8"),
	"stoneford_spire": Color("9a9488"),
	"eastmarch_spire": Color("c98c4e"),
	"westwatch_spire": Color("6f9a6a"),
	"southbridge_spire": Color("b86a6a"),
}

var prop_type := ""
var prop_id := ""
var footprint: Array[Vector2i] = []
var south_cell := Vector2i.ZERO
var base_height := 0
## Screen rect (local) used for "player is behind me" fading.
var cover_rect := Rect2()
var _tex: Texture2D
var _fence_axis := 0  # 0: along x (NE-SW screen), 1: along y


func setup(zone: WorldZone, record: Dictionary) -> void:
	prop_type = str(record["type"])
	prop_id = str(record.get("id", prop_type))
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
	z_index = (south_cell.x + south_cell.y) * BoardVisualSort.TILE_Z_SCALE + 2
	if prop_type == "fence":
		var o := footprint[0]
		var along_y := _is_fence(zone, o + Vector2i(0, 1)) or _is_fence(zone, o + Vector2i(0, -1))
		_fence_axis = 1 if along_y else 0
	_tex = _load_art()
	cover_rect = _cover_rect()
	queue_redraw()


## Kit art id for this placement: fences along y use `fence_wood_nesw`,
## trees and cottages pick a variant by hash of their origin (kit README).
var art_id := ""
var _art: Dictionary = {}


func _load_art() -> Texture2D:
	art_id = Art.prop_art_id(prop_type, footprint[0], _fence_axis)
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


## Fade when the walker stands behind the prop and overlaps it on screen.
func update_cover(walker_cell: Vector2i, walker_pos: Vector2) -> void:
	var behind := walker_cell.x + walker_cell.y < south_cell.x + south_cell.y
	var overlap := cover_rect.grow(-4).has_point(walker_pos - position)
	var target := 0.45 if behind and overlap and prop_type != "fence" else 1.0
	modulate.a = lerpf(modulate.a, target, 0.25)


func _draw() -> void:
	if _tex != null:
		var s := Art.size_of(_art)
		Art.draw_at(self, _art, Vector2(-s.x * 0.5, -s.y))
		return
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
