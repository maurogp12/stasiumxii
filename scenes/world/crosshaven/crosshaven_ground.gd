extends Node2D

## VIEW ONLY. Draws one Crosshaven chunk's ground: terrain diamonds, height
## side faces, and exit markers. Walk data stays in `WorldZone` / `WorldWalk`.
##
## Art hook: a PNG at `TILE_ART_ROOT/<terrain id>.png` replaces the painted
## placeholder for that terrain, drawn like `board/tile.gd` (bottom on the
## diamond's south tip).

const TILE_ART_ROOT := "res://art/world/crosshaven/tiles/"
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")
const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

const TOP := {
	"golden_plains": Color("d8c27a"),
	"dirt_road": Color("b48c5c"),
	"water": Color("3f8fc2"),
	"cliff": Color("8c857a"),
}
const SIDE := {
	"golden_plains": Color("9a7a46"),
	"dirt_road": Color("8a6a44"),
	"water": Color("2c6a92"),
	"cliff": Color("625c54"),
}
const EXIT_COLOR := Color(1.0, 0.84, 0.35, 0.85)
## Same olive as the world's field fill, so an outer edge fades into it.
const FIELD_FADE := Color("90a91b")
const _ORTHO: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

var zone: WorldZone
## Plane edges you can walk across hide the yellow exit triangles.
var show_walk_exits := true
## Extra cells drawn past the chunk so the neighbour's tiles cover the seam.
var blend_margin := 0
var _use_kit := false
var _exit_dirs: Dictionary = {}
var _ripple_frame := 0
var _water_rows: Dictionary = {}
var _void_ranks: Dictionary = {}


## Ground is split into one canvas item per diagonal (x+y), z = diagonal * 10,
## so a raised tile in front covers the walker standing behind it.
static func row_z(diagonal: int) -> int:
	return diagonal * BoardVisualSort.TILE_Z_SCALE


func setup(target: WorldZone) -> void:
	zone = target
	for child in get_children():
		child.queue_free()
	# Use the kit once its four base terrain tiles exist.
	_use_kit = true
	for terrain in TOP.keys():
		if not Art.has("tiles", str(terrain)):
			_use_kit = false
	_exit_dirs.clear()
	if show_walk_exits:
		for exit_rec in zone.exits:
			var dir: Vector2i = WorldZone.EDGE_DIR.get(str(exit_rec["edge"]), Vector2i.ZERO)
			for link in exit_rec["links"]:
				var frm: Dictionary = link["from"]
				_exit_dirs[Vector2i(int(frm["x"]), int(frm["y"]))] = dir
	_cache_void_ranks()
	var margin := blend_margin
	for d in range(-margin * 2, zone.width + zone.height - 1 + margin * 2):
		var row := Node2D.new()
		row.name = "Row%d" % d
		row.z_as_relative = false
		row.z_index = row_z(d)
		row.draw.connect(_draw_row.bind(row, d))
		add_child(row)
	_mark_water_rows()


func _mark_water_rows() -> void:
	_water_rows.clear()
	for y in zone.height:
		for x in zone.width:
			if zone.terrain_at(Vector2i(x, y)) == "water":
				_water_rows[x + y] = true


func _process(_delta: float) -> void:
	if zone == null or _water_rows.is_empty():
		return
	var on := VisualSettings.current != null and VisualSettings.current.enabled("animations")
	if not on:
		if _ripple_frame != -1:
			_ripple_frame = -1
			_redraw_water()
		return
	var frame := int(float(Time.get_ticks_msec()) * 4.0 / 1000.0) % 8
	if frame == _ripple_frame:
		return
	_ripple_frame = frame
	_redraw_water()


func _redraw_water() -> void:
	for d in _water_rows.keys():
		var row := get_node_or_null("Row%d" % int(d))
		if row != null:
			row.queue_redraw()


func redraw_all() -> void:
	for child in get_children():
		child.queue_redraw()


func uses_kit() -> bool:
	return _use_kit


## Same gold arrow as a chunk exit. Gates are sidecar data, so the zone file stays untouched.
func add_gate_arrow(cell: Vector2i, dir: Vector2i) -> void:
	_exit_dirs[cell] = dir
	var row := get_node_or_null("Row%d" % (cell.x + cell.y))
	if row != null:
		row.queue_redraw()


func marker_dir(cell: Vector2i) -> Vector2i:
	if not _exit_dirs.has(cell):
		return Vector2i.ZERO
	return _exit_dirs[cell]


## Light snow only. Northgate (and any later `crosshaven_northgate*` chunk)
## stays dusted. The north road fades that dust out toward the Crossroads.
static func snow_at(zone_id: String, cell: Vector2i) -> float:
	if zone_id.begins_with("crosshaven_northgate"):
		return 1.0
	if zone_id == "crosshaven_road_north":
		if cell.y >= 16:
			return 0.0
		return clampf(1.0 - float(cell.y) / 16.0, 0.0, 1.0)
	return 0.0


func snow_at_cell(cell: Vector2i) -> float:
	if zone == null:
		return 0.0
	return snow_at(zone.zone_id, cell)


## 1 = this cell meets empty world, 2 = the next cell in. 0 on a real join.
func void_rank(cell: Vector2i) -> int:
	return int(_void_ranks.get(cell, 0))


func _cache_void_ranks() -> void:
	_void_ranks.clear()
	if zone == null or not zone.sample_terrain.is_valid():
		return
	var margin := blend_margin
	for y in range(-margin, zone.height + margin):
		for x in range(-margin, zone.width + margin):
			var cell := Vector2i(x, y)
			var rank := _compute_void_rank(cell)
			if rank > 0:
				_void_ranks[cell] = rank


func _compute_void_rank(cell: Vector2i) -> int:
	if Art.terrain_seen(zone, cell) == "":
		return 0
	if _faces_void(cell):
		return 1
	for dir in _ORTHO:
		var nb: Vector2i = cell + dir
		if Art.terrain_seen(zone, nb) == "":
			continue
		if _faces_void(nb):
			return 2
	return 0


func _faces_void(cell: Vector2i) -> bool:
	if Art.terrain_seen(zone, cell) == "":
		return false
	for dir in _ORTHO:
		if Art.terrain_seen(zone, cell + dir) == "":
			return true
	return false


func _draw_row(row: Node2D, s: int) -> void:
	var margin := blend_margin
	var x0 := maxi(-margin, s - (zone.height - 1 + margin))
	var x1 := mini(zone.width - 1 + margin, s + margin)
	for x in range(x0, x1 + 1):
		var cell := Vector2i(x, s - x)
		if not zone.in_bounds(cell) and Art.terrain_seen(zone, cell) == "":
			continue
		_draw_cell(row, cell)
		if _exit_dirs.has(cell):
			_draw_exit(row, cell, _exit_dirs[cell])


func _draw_cell(ci: Node2D, cell: Vector2i) -> void:
	var terrain := Art.terrain_seen(zone, cell)
	if terrain == "":
		return
	var steps := Art.height_seen(zone, cell)
	var rank := void_rank(cell)
	# The last water cell of a stream becomes a bank, not a blue rectangle.
	var bank := terrain == "water" and rank == 1
	var paint := "golden_plains" if bank else terrain
	if _use_kit:
		_draw_cell_kit(ci, cell, terrain, steps, bank)
	else:
		var top: Color = TOP.get(paint, Color.MAGENTA)
		var side: Color = SIDE.get(paint, Color.DARK_MAGENTA)
		var lifted := Pick.diamond(cell, float(steps))
		if steps > 0:
			_draw_flat_faces(ci, lifted, steps, side)
		# Painted placeholder: soft per-cell variation so the plains read hand-made.
		var n := _hash(cell)
		var tint := top.lightened(0.06 * n) if paint != "water" else top.lightened(0.04 * n)
		ci.draw_colored_polygon(lifted, tint)
		if paint == "golden_plains" and n > 0.72:
			var c := BoardVisualSort.cell_to_local(cell, float(steps))
			ci.draw_line(c + Vector2(-4, 2), c + Vector2(-2, -4), Color("a89048"), 1.0)
			ci.draw_line(c + Vector2(3, 3), c + Vector2(5, -3), Color("a89048"), 1.0)
		elif paint == "water":
			var c := BoardVisualSort.cell_to_local(cell, float(steps))
			ci.draw_line(c + Vector2(-8, -1 + 3 * n), c + Vector2(6, -1 + 3 * n), Color(1, 1, 1, 0.22), 1.0)
		var edge := Color(0, 0, 0, 0.06)
		ci.draw_polyline(PackedVector2Array([lifted[0], lifted[1], lifted[2], lifted[3], lifted[0]]), edge, 1.0)
	_theme_wash(ci, cell, terrain, steps)
	_fade_void_edge(ci, cell, steps, rank, terrain)
	_dust_snow(ci, cell, paint, steps)


func _draw_flat_faces(ci: Node2D, lifted: PackedVector2Array, steps: int, side: Color) -> void:
	var drop := Vector2(0, float(steps) * BoardVisualSort.ELEVATION_PIXELS)
	ci.draw_colored_polygon(PackedVector2Array([lifted[3], lifted[2], lifted[2] + drop, lifted[3] + drop]), side)
	ci.draw_colored_polygon(PackedVector2Array([lifted[2], lifted[1], lifted[1] + drop, lifted[2] + drop]), side.darkened(0.18))


## Technical Artist kit path: height strips, autotiled floor, corner decals.
func _draw_cell_kit(ci: Node2D, cell: Vector2i, terrain: String, steps: int, bank: bool = false) -> void:
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var south_tip := center + Vector2(0, Pick.HALF_H)
	var shown := "golden_plains" if bank else terrain
	if steps > 0:
		var strips := Art.face_strips(zone, cell)
		var all_found := true
		for strip in strips:
			if not Art.has("tiles", strip["id"]):
				all_found = false
				break
		if all_found:
			for strip in strips:
				Art.draw_at(ci, Art.texture("tiles", strip["id"]), south_tip + strip["offset"])
		else:
			_draw_flat_faces(ci, Pick.diamond(cell, float(steps)), steps, SIDE.get(shown, Color.DARK_MAGENTA))
	if bank:
		_draw_named_floor(ci, south_tip, "golden_plains_a", "golden_plains")
		return
	var pick := Art.pick_tile(zone, cell)
	var floor_id := str(pick["floor"])
	var drew_ripple := false
	if terrain == "water" and VisualSettings.current != null and VisualSettings.current.enabled("animations"):
		drew_ripple = _draw_ripple(ci, floor_id + "_ripple", south_tip)
	if not drew_ripple:
		var floor_art := Art.texture("tiles", floor_id)
		if floor_art.is_empty():
			floor_art = Art.texture("tiles", terrain)
		if not floor_art.is_empty():
			var size := Art.size_of(floor_art)
			Art.draw_at(ci, floor_art, south_tip + Vector2(-size.x * 0.5, -size.y))
	for corner_id in pick["corners"]:
		var corner_art := Art.texture("tiles", corner_id)
		if not corner_art.is_empty():
			var csize := Art.size_of(corner_art)
			Art.draw_at(ci, corner_art, south_tip + Vector2(-csize.x * 0.5, -csize.y))
	if terrain == "water" and VisualSettings.current != null and VisualSettings.current.enabled("animations"):
		_draw_water_polish(ci, cell, steps)
	var lip := str(pick.get("lip", ""))
	if lip != "":
		var lip_art := Art.texture("tiles", lip)
		if not lip_art.is_empty():
			var lsize := Art.size_of(lip_art)
			Art.draw_at(ci, lip_art, south_tip + Vector2(-lsize.x * 0.5, -lsize.y))


func _draw_water_polish(ci: Node2D, cell: Vector2i, steps: int) -> void:
	var d := Pick.diamond(cell, float(steps))
	var n := _hash(cell)
	var phase := 0.0 if _ripple_frame < 0 else float(_ripple_frame) / 8.0
	var c := BoardVisualSort.cell_to_local(cell, float(steps))
	var shimmer_y := -2.0 + 3.0 * sin(phase * TAU + n * 6.0)
	ci.draw_line(c + Vector2(-10, shimmer_y), c + Vector2(8, shimmer_y * 0.35), Color(1, 1, 1, 0.22), 1.2)
	if n > 0.72:
		ci.draw_circle(c + Vector2(-2.0 + n * 4.0, shimmer_y), 1.15, Color(1, 1, 1, 0.95))
	ci.draw_line(c + Vector2(-3, 1), c + Vector2(-3, 6), Color(0.85, 0.95, 1, 0.16), 1.4)
	_foam_if_shore(ci, cell, d, Vector2i(0, -1), 0, 1)
	_foam_if_shore(ci, cell, d, Vector2i(1, 0), 1, 2)
	_foam_if_shore(ci, cell, d, Vector2i(0, 1), 2, 3)
	_foam_if_shore(ci, cell, d, Vector2i(-1, 0), 3, 0)


func _foam_if_shore(ci: Node2D, cell: Vector2i, d: PackedVector2Array, step: Vector2i, ia: int, ib: int) -> void:
	var nb: Vector2i = cell + step
	# A water cell that is itself the bank still gets a foam line on this side.
	if Art.terrain_seen(zone, nb) == "water" and void_rank(nb) != 1:
		return
	ci.draw_line(d[ia], d[ib], Color(0.92, 0.97, 1.0, 0.55), 1.6)


func _draw_named_floor(ci: Node2D, south_tip: Vector2, first_id: String, fallback_id: String) -> void:
	var floor_art := Art.texture("tiles", first_id)
	if floor_art.is_empty():
		floor_art = Art.texture("tiles", fallback_id)
	if floor_art.is_empty():
		return
	var size := Art.size_of(floor_art)
	Art.draw_at(ci, floor_art, south_tip + Vector2(-size.x * 0.5, -size.y))


func _fade_void_edge(ci: Node2D, cell: Vector2i, steps: int, rank: int, terrain: String) -> void:
	if rank <= 0:
		return
	var fade := FIELD_FADE
	# The sea meets the island. A stream that runs off the land fades into that sea.
	if terrain == "water":
		fade = Color("1e6e96")
	elif terrain == "cliff":
		fade = Color("9c935f")
	fade.a = 1.0 if rank == 1 else 0.5
	ci.draw_colored_polygon(Pick.diamond(cell, float(steps)), fade)


## Sand, murk, and blight are paints on the same tiles, so each town reads apart.
func _theme_wash(ci: Node2D, cell: Vector2i, terrain: String, steps: int) -> void:
	if zone == null or terrain == "water" or terrain == "cliff" or terrain == "dirt_road":
		return
	var id := zone.zone_id
	var wash := Color(0, 0, 0, 0)
	if id.find("eastmarch") >= 0:
		wash = Color(0.89, 0.78, 0.48, 0.5)
	elif id.find("southbridge") >= 0:
		wash = Color(0.32, 0.4, 0.26, 0.42)
	elif id.find("westwatch") >= 0:
		wash = Color(0.38, 0.22, 0.46, 0.48)
	if wash.a <= 0.0:
		return
	ci.draw_colored_polygon(Pick.diamond(cell, float(steps)), wash)


func _dust_snow(ci: Node2D, cell: Vector2i, terrain: String, steps: int) -> void:
	var amount := snow_at_cell(cell)
	if amount <= 0.2:
		return
	var n := _hash(cell)
	var diamond := Pick.diamond(cell, float(steps))
	# Pale frost on the grass, readable at a glance. Not a few ridge caps.
	if terrain != "water" and terrain != "dirt_road":
		var frost := Color(0.78, 0.86, 0.94, 0.42 * amount)
		ci.draw_colored_polygon(diamond, frost)
	if terrain == "cliff":
		ci.draw_colored_polygon(diamond, Color(0.96, 0.98, 1.0, 0.55 * amount))
	if n > 0.35:
		var c := BoardVisualSort.cell_to_local(cell, float(steps))
		ci.draw_circle(c + Vector2(-6, 2), 6.5, Color(1, 1, 1, 0.82 * amount))
		ci.draw_circle(c + Vector2(7, -1), 4.5, Color(0.96, 0.98, 1, 0.7 * amount))


func _draw_ripple(ci: Node2D, anim_id: String, south_tip: Vector2) -> bool:
	var meta := Art.anim_meta(anim_id)
	var tex := Art.anim_texture(anim_id)
	if tex == null or meta.is_empty():
		return false
	var size: Array = meta.get("frame_size", [])
	if size.size() < 2:
		return false
	var fw := float(size[0])
	var fh := float(size[1])
	var region := Rect2(_ripple_frame * fw, 0, fw, fh)
	ci.draw_texture_rect_region(tex, Rect2(south_tip + Vector2(-fw * 0.5, -fh), Vector2(fw, fh)), region)
	return true


func _draw_exit(ci: Node2D, cell: Vector2i, dir: Vector2i) -> void:
	var c := Pick.cell_center(zone, cell)
	var screen_dir := Vector2(float(dir.x - dir.y) * Pick.HALF_W, float(dir.x + dir.y) * Pick.HALF_H).normalized()
	var side := Vector2(-screen_dir.y, screen_dir.x)
	var tip := c + screen_dir * 9.0
	ci.draw_colored_polygon(PackedVector2Array([tip, c - screen_dir * 3.0 + side * 6.0, c - screen_dir * 3.0 - side * 6.0]), EXIT_COLOR)


static func _hash(cell: Vector2i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 1000) / 1000.0
