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
const Kit := preload("res://scenes/world/crosshaven/outskirts_kit.gd")

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
## Plane bbox. Past the coast the backdrop is sea, never an olive field.
const PLANE_X0 := -72
const PLANE_Y0 := -64
const PLANE_X1 := 112
const PLANE_Y1 := 104
const _ORTHO: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

var zone: WorldZone
## World-cell origin of this chunk. Theme weights blend from here, not from the zone id.
var world_origin := Vector2i.ZERO
## Plane edges you can walk across hide the yellow exit triangles.
var show_walk_exits := true
## Extra cells drawn past the chunk so the neighbour's tiles cover the seam.
var blend_margin := 0
var _use_kit := false
var _exit_dirs: Dictionary = {}
var _ripple_frame := 0
var _water_rows: Dictionary = {}
var _void_ranks: Dictionary = {}
## Visual family for the Eastmarch beach kit, keyed by local cell.
var _beach: Dictionary = {}
## How far a void cell sits past the real shore. Breakers use this.
var _skirt_dist: Dictionary = {}
## Sea or river cells within 4 of the empty map edge. 1 is the outer cell.
var _edge_fade: Dictionary = {}
## River cells within 3 of sea water or the map edge, 0..1 toward the sea tint.
var _mouth_mix: Dictionary = {}
## Water connected to the map edge. Inland pools stay out of this set.
var _sea_body: Dictionary = {}
## Empty cells past the sea, painted as the same fill so the backdrop does not show.
var _void_sea: Dictionary = {}
## Steps from the last sea cell for each painted void cell. Same answer in every chunk.
var _void_dist: Dictionary = {}
var _void_margin := 0
## Northgate's shore lip: 1 on a Northgate cell, less where the coast leaves the town.
var _snow_shore: Dictionary = {}
## Snow-town cover per cell, 0..1, margin included. 1 on every Northgate cell,
## thinning over SNOW_BLEND cells into the chunks around it.
var _cover: Dictionary = {}
## World-cell rects of the snow-town chunks (set by the world before setup).
var snow_rects: Array[Rect2i] = []
## Diagonal -> the foam canvas item hung under that row.
var _foam_rows: Dictionary = {}
## Cells per ground run at most (see `_split_row`).
const RUN_CELLS := 12
## Runs and foam rows not drawn yet: [node, local rect, cell count].
var _cold: Array = []
## How far a row's art reaches above and below its diamonds (raised tiles,
## crag faces, kit tiles taller than a diamond; foam onto the next row).
const ROW_ART_ABOVE := 128.0
const ROW_ART_BELOW := 48.0
## Same plane layout, same tag (set by the world). Empty turns the memo off.
var cache_tag := ""
## Diagonal -> [[anim, cells], ...] (`_split_row`).
var _row_parts: Dictionary = {}
## Setup results per chunk placement, shared read-only between loads. They
## only depend on the chunk, where it sits on the plane, the margin and the
## snow kit, and cost up to a third of a second a chunk to work out, which
## every seam crossing paid for all seven grounds it mounts.
static var _memo: Dictionary = {}
const MEMO_FIELDS: Array[String] = [
	"_void_ranks", "_beach", "_skirt_dist", "_sea_body", "_void_sea", "_void_dist",
	"_edge_fade", "_mouth_mix", "_snow_shore", "_cover", "_water_rows",
	"_corner_cache", "_foam_cells", "_row_parts",
]
## Foam row diagonal -> its foam cells.
var _foam_cells: Dictionary = {}
## Canvas items that follow the ripple: [{node, rect, frame}], rect in local px.
var _anim_items: Array = []
var _anim_stale := false
## View margin (px) for redrawing animated runs just before they scroll in.
const ANIM_VIEW_MARGIN := 64.0
## Cell -> its sea corner alphas (`_corner_alphas`).
var _corner_cache: Dictionary = {}
## Diagonal -> runs of that row: [{anim, cells, node}], west to east.
var _runs: Dictionary = {}
## Sample inside the tile and overlap the neighbours so the fringe is not a seam.
const WATER_OVERLAP := 4.0
const BEACH_REACH := 4
## Open sea is one surface in world space, so no cell outline can read.
const SEA_FILL := Color("246e9e")
const SEA_SURFACE_PATH := "res://art/world/crosshaven/animated/water/sea_surface.png"
const SEA_GLINT_PATH := "res://art/world/crosshaven/animated/water/sea_glint.png"
## World pixels per texture repeat. The PNGs are 2x masters.
const SEA_PERIOD := Vector2(256.0, 128.0)
const GLINT_PERIOD := Vector2(192.0, 96.0)
## Void cells over which the textured sea thins into the flat fill.
const SEA_FADE_CELLS := 4
## Cells along the coast where the Northgate snow lip thins into sand.
const SNOW_SHORE_BLEND := 3
## Cells over which the town snow thins into a neighbouring chunk.
const SNOW_BLEND := 3
const SNOW_FIELD_PATH := "res://art/world/crosshaven/tiles/_2x/snow_field.png"
const SNOW_COBBLE_PATH := "res://art/world/crosshaven/tiles/_2x/snow_cobble_field.png"
## World pixels per repeat of the snow textures (2x masters, four cells a side).
const SNOW_PERIOD := Vector2(256.0, 128.0)
## Off draws Northgate as it was before the snow kit (bench and A/B stills).
static var snow_kit := true
static var _snow_field_tex: CanvasTexture
static var _snow_cobble_tex: CanvasTexture
static var _snow_tex_loaded := false
static var _sea_surface_tex: CanvasTexture
static var _sea_glint_tex: CanvasTexture
static var _sea_tex_loaded := false
## Painted sea past the last water cell, so the view edge is not a flat fill.
const SEA_SKIRT := 22


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
	# Fresh dictionaries first: a memo hit hands out shared read-only ones,
	# and the cache passes below clear() what they fill.
	for field in MEMO_FIELDS:
		set(field, {})
	_void_margin = 0
	_foam_rows = {}
	_runs = {}
	_anim_items = []
	var key := _memo_key()
	var memo: Dictionary = _memo.get(key, {}) if key != "" else {}
	if memo.is_empty():
		_cache_void_ranks()
		_cache_beach()
		_cache_sea_skirt()
		_cache_sea_body()
		_cache_void_sea()
		_cache_water_edge()
		_cache_snow_shore()
		_cache_cover()
		_mark_water_rows()
	else:
		for field in MEMO_FIELDS:
			set(field, memo[field])
		_void_margin = int(memo["_void_margin"])
	var margin := _view_margin()
	for d in range(-margin * 2, zone.width + zone.height - 1 + margin * 2):
		var row := Node2D.new()
		row.name = "Row%d" % d
		row.z_as_relative = false
		row.z_index = row_z(d)
		add_child(row)
		# The row draws through its runs. They hang under it at the same z,
		# so tree order keeps the cells in their usual west-to-east order.
		var runs := _split_row(d)
		for i in runs.size():
			var seg := Node2D.new()
			seg.name = "Run%d" % i
			seg.z_as_relative = false
			seg.z_index = row_z(d)
			seg.draw.connect(_draw_run.bind(seg, d, i))
			row.add_child(seg)
			(runs[i] as Dictionary)["node"] = seg
		_runs[d] = runs
		if _row_has_foam(d):
			# Foam reaches past its own diamond onto the next water cell and up
			# the face of a raised bank, so it sorts just after the next row.
			# It hangs under its row so the ground keeps one child per row.
			var foam := Node2D.new()
			foam.name = "Foam"
			foam.z_as_relative = false
			foam.z_index = row_z(d + 1) + 1
			foam.draw.connect(_draw_foam_row.bind(foam, d))
			row.add_child(foam)
			_foam_rows[d] = foam
			_track_anim(foam, _row_foam_cells(d))
		if _water_rows.has(d):
			for run in runs:
				if bool(run["anim"]):
					_track_anim(run["node"], run["cells"])
	if key != "" and memo.is_empty():
		var keep := {"_void_margin": _void_margin}
		for field in MEMO_FIELDS:
			var value: Dictionary = get(field)
			# Corner alphas keep filling as cells draw; the values never change.
			if field != "_corner_cache":
				value.make_read_only()
			keep[field] = value
		_memo[key] = keep


func _mark_water_rows() -> void:
	_water_rows.clear()
	for y in zone.height:
		for x in zone.width:
			if zone.terrain_at(Vector2i(x, y)) == "water":
				_water_rows[x + y] = true
	# The fading sea past the coast moves with the water, so it redraws too.
	for cell in _void_dist.keys():
		if int(_void_dist[cell]) <= SEA_FADE_CELLS:
			var at: Vector2i = cell
			_water_rows[at.x + at.y] = true


func _process(_delta: float) -> void:
	if zone == null or _water_rows.is_empty():
		return
	var on := VisualSettings.current != null and VisualSettings.current.enabled("animations")
	var frame := -1
	if on:
		frame = int(float(Time.get_ticks_msec()) * 4.0 / 1000.0) % 8
	if frame != _ripple_frame:
		_ripple_frame = frame
		_anim_stale = true
	if _anim_stale:
		_redraw_water()


## Animated runs and foam rows whose drawn ripple frame is behind, and that
## meet the view, redraw. Off-screen ones wait until they scroll into view, so
## a ripple frame costs only the sea the camera shows.
func _redraw_water() -> void:
	var view := Rect2()
	var have_view := is_inside_tree()
	if have_view:
		view = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
		view = view.grow(ANIM_VIEW_MARGIN)
	var behind := false
	for item in _anim_items:
		if int(item["frame"]) == _ripple_frame:
			continue
		var node: Node2D = item["node"]
		if not is_instance_valid(node):
			continue
		if have_view and not view.intersects(item["rect"]):
			behind = true
			continue
		item["frame"] = _ripple_frame
		node.queue_redraw()
	_anim_stale = behind


## Only the runs whose drawing follows the ripple phase (water, and the sea
## fringe that still shows the moving surface) redraw with the ripple. The
## rest of a water row (snow, cobble, sand, flat far sea) is drawn once.
## Redrawing whole rows cost Northgate about a second of script per frame.
func _track_anim(node: Node2D, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var rect := Rect2(BoardVisualSort.cell_to_local(cells[0]), Vector2.ZERO)
	for cell in cells:
		rect = rect.expand(BoardVisualSort.cell_to_local(cell))
	# A diamond, its overlap, foam up a bank face and raised tiles.
	rect = rect.grow_individual(Pick.HALF_W + 8.0, 96.0, Pick.HALF_W + 8.0, Pick.HALF_H + 8.0)
	_anim_items.append({"node": node, "rect": rect, "frame": _ripple_frame})


func redraw_all() -> void:
	for runs in _runs.values():
		for run in runs:
			var node: Node2D = run.get("node")
			if is_instance_valid(node):
				node.queue_redraw()
	for foam in _foam_rows.values():
		if is_instance_valid(foam):
			(foam as Node2D).queue_redraw()


## Rows draw once, when first shown. `start_cold` hides them all; `warm`
## shows the ones that meet the view right away and a few more a frame, so a
## zone load or seam crossing draws only what the camera sees.
func start_cold() -> void:
	_cold = []
	for d in _runs.keys():
		for run in _runs[d]:
			_chill(run["node"], run["cells"])
	for d in _foam_rows.keys():
		_chill(_foam_rows[d], _row_foam_cells(d))


func _chill(node: Node2D, cells: Array[Vector2i]) -> void:
	if not is_instance_valid(node) or cells.is_empty():
		return
	var rect := Rect2(BoardVisualSort.cell_to_local(cells[0]), Vector2.ZERO)
	rect = rect.expand(BoardVisualSort.cell_to_local(cells[cells.size() - 1]))
	rect = rect.grow_individual(Pick.HALF_W + 16.0, ROW_ART_ABOVE, Pick.HALF_W + 16.0, ROW_ART_BELOW)
	node.visible = false
	_cold.append([node, rect, cells.size()])


func is_warm() -> bool:
	return _cold.is_empty()


## Show cold rows that meet `view` (local px), then others until `budget`
## cells are spent. A negative budget shows every row. Returns what is left.
func warm(view: Rect2, budget: int) -> int:
	if _cold.is_empty():
		return budget
	var keep: Array = []
	for item in _cold:
		var row: Node2D = item[0]
		if not is_instance_valid(row):
			continue
		if budget < 0 or view.intersects(item[1]):
			row.visible = true
		elif budget > 0:
			row.visible = true
			budget = maxi(0, budget - int(item[2]))
		else:
			keep.append(item)
	_cold = keep
	return budget


func _memo_key() -> String:
	if cache_tag == "" or zone == null:
		return ""
	return "%s|%s|%s|%d|%s|%s|%s" % [cache_tag, zone.zone_id, world_origin, blend_margin, snow_kit, Kit.has_theme("eastmarch"), str(snow_rects)]


static func clear_memo() -> void:
	_memo.clear()


func _redraw_row(d: int) -> void:
	for run in _runs.get(d, []):
		var node: Node2D = run.get("node")
		if is_instance_valid(node):
			node.queue_redraw()


## Splits diagonal `s` into runs of up to RUN_CELLS neighbouring cells that
## are all static or all animated. Only water rows get animated runs, as
## before. Short runs let a load draw only the part of a row on screen.
func _split_row(s: int) -> Array:
	var parts: Array = _row_parts.get(s, [])
	if parts.is_empty():
		var water_row := _water_rows.has(s)
		for cell in _row_cells(s):
			var anim := water_row and _follows_phase(cell)
			if parts.is_empty() or bool(parts[parts.size() - 1][0]) != anim or (parts[parts.size() - 1][1] as Array).size() >= RUN_CELLS:
				parts.append([anim, [] as Array[Vector2i]])
			(parts[parts.size() - 1][1] as Array[Vector2i]).append(cell)
		if parts.is_empty():
			parts.append([false, [] as Array[Vector2i]])
		_row_parts[s] = parts
	var runs: Array = []
	for part in parts:
		runs.append({"anim": bool(part[0]), "cells": part[1]})
	return runs


## True when this cell's drawing reads `_ripple_frame`: water (ripple strip,
## polish, sea surface, sparkle, foam) and void sea whose textured surface
## still shows at one of its corners (a corner mixes the 3x3 around the cell).
func _follows_phase(cell: Vector2i) -> bool:
	var terrain := Art.terrain_seen(zone, cell)
	if terrain == "water":
		return true
	if terrain != "" or not _void_sea.has(cell):
		return false
	var skirt := _beach_at(cell)
	if skirt == "sea_deep" or skirt == "sea_shallow":
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if _sea_alpha(cell + Vector2i(dx, dy)) > 0.0:
				return true
	return false


func uses_kit() -> bool:
	return _use_kit


## Same gold arrow as a chunk exit. Gates are sidecar data, so the zone file stays untouched.
func add_gate_arrow(cell: Vector2i, dir: Vector2i) -> void:
	if _exit_dirs.get(cell) == dir:
		return
	_exit_dirs[cell] = dir
	_redraw_row(cell.x + cell.y)


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


## Cells from the plane edge. Interior of the island is deeper than the coast band.
func _rim_depth(cell: Vector2i) -> int:
	var world := world_origin + cell
	var dx := mini(world.x - PLANE_X0, PLANE_X1 - 1 - world.x)
	var dy := mini(world.y - PLANE_Y0, PLANE_Y1 - 1 - world.y)
	return mini(dx, dy)


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


## Eastmarch beach is a visual family on top of golden_plains and water.
## Zone terrain ids stay as they are.
func _cache_beach() -> void:
	_beach.clear()
	if zone == null or not Kit.has_theme("eastmarch"):
		return
	var margin := blend_margin
	for y in range(-margin, zone.height + margin):
		for x in range(-margin, zone.width + margin):
			var cell := Vector2i(x, y)
			var family := _classify_beach(cell)
			if family != "":
				_beach[cell] = family


func _beach_at(cell: Vector2i) -> String:
	if _beach.has(cell):
		return str(_beach[cell])
	return ""


func _view_margin() -> int:
	if zone != null and zone.zone_id.begins_with("crosshaven_eastmarch"):
		return maxi(blend_margin, SEA_SKIRT)
	return maxi(blend_margin, _void_margin)


## Void cells beyond the Eastmarch shore keep the kit sea and a breaker band.
## Other chunks stay empty there, so this does not paint over land.
func _cache_sea_skirt() -> void:
	_skirt_dist.clear()
	if zone == null or not zone.zone_id.begins_with("crosshaven_eastmarch"):
		return
	if not zone.sample_terrain.is_valid():
		return
	var queue: Array[Vector2i] = []
	var queued := {}
	for y in zone.height:
		for x in zone.width:
			var cell := Vector2i(x, y)
			if Art.terrain_seen(zone, cell) != "water":
				continue
			for dir in _ORTHO:
				var nb: Vector2i = cell + dir
				if queued.has(nb):
					continue
				if Art.terrain_seen(zone, nb) != "":
					continue
				queued[nb] = 1
				queue.append(nb)
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		var dist := int(queued[at])
		# A shallow band every few cells keeps a breaker in the open sea.
		# The rest stays deep kit water, so the corner is not a flat fill.
		var surf := (dist % 7) >= 5
		_beach[at] = "sea_shallow" if surf else "sea_deep"
		_skirt_dist[at] = dist
		if dist >= SEA_SKIRT:
			continue
		for dir in _ORTHO:
			var next: Vector2i = at + dir
			if queued.has(next):
				continue
			if Art.terrain_seen(zone, next) != "":
				continue
			queued[next] = dist + 1
			queue.append(next)


func _family_seen(cell: Vector2i) -> String:
	var beach := _beach_at(cell)
	if beach != "":
		return beach
	if zone == null:
		return ""
	return Art.terrain_seen(zone, cell)


func _east_coast(cell: Vector2i) -> bool:
	var weights := theme_weights(cell)
	var east := _weight(weights, "eastmarch")
	if east < 0.38:
		return false
	if east + 0.02 < _weight(weights, "northgate"):
		return false
	if east + 0.02 < _weight(weights, "southbridge"):
		return false
	return true


func _sea_dist(cell: Vector2i) -> int:
	if zone == null:
		return 99
	if Art.terrain_seen(zone, cell) == "water":
		return 0
	for radius in range(1, BEACH_REACH + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				if Art.terrain_seen(zone, cell + Vector2i(dx, dy)) == "water":
					return radius
	return 99


func _classify_beach(cell: Vector2i) -> String:
	if zone == null or not _east_coast(cell):
		return ""
	var terrain := Art.terrain_seen(zone, cell)
	if terrain == "water":
		for dir in _ORTHO:
			var nb := Art.terrain_seen(zone, cell + dir)
			if nb != "" and nb != "water":
				return "sea_shallow"
		return "sea_deep"
	if terrain != "golden_plains":
		return ""
	var dist := _sea_dist(cell)
	if dist == 1:
		return "wet_sand"
	if dist <= BEACH_REACH:
		return "sand"
	return ""


func _kit_sea(cell: Vector2i) -> bool:
	var family := _beach_at(cell)
	return family == "sea_shallow" or family == "sea_deep"


## Open water_a..d are the lighter river blue. These multiplies make sea and swamp.
const SEA_TINT := Color(36.0 / 94.0, 110.0 / 173.0, 158.0 / 224.0)
const SWAMP_TINT := Color(92.0 / 94.0, 96.0 / 173.0, 52.0 / 224.0)


func _zone_id_at(cell: Vector2i) -> String:
	if zone == null:
		return ""
	if zone.in_bounds(cell):
		return zone.zone_id
	if zone.sample_zone_id.is_valid():
		return str(zone.sample_zone_id.call(cell))
	return ""


func _water_grade(cell: Vector2i) -> String:
	var zone_id := _zone_id_at(cell)
	if zone_id.contains("swamp"):
		return "swamp"
	# Stoneford's channel is the river. Inland pools are the same lighter blue.
	if zone_id.begins_with("crosshaven_stoneford"):
		return "river"
	# The whole body that meets the map edge is sea, not only the outer 8 cells.
	if _sea_body.has(cell):
		return "sea"
	if _rim_depth(cell) > 8 and not _faces_void(cell):
		return "river"
	return "sea"


## Flood sea from the rim through connected water. Swamp and the Stoneford
## river stay out, so a bay more than 8 cells in still counts as sea.
func _cache_sea_body() -> void:
	_sea_body.clear()
	if zone == null:
		return
	var can_sample := zone.sample_terrain.is_valid()
	var margin := 4
	if can_sample:
		margin = maxi(_view_margin(), 4)
	var queue: Array[Vector2i] = []
	var seen := {}
	for y in range(-margin, zone.height + margin):
		for x in range(-margin, zone.width + margin):
			var cell := Vector2i(x, y)
			if not _sea_candidate(cell):
				continue
			var seed := _rim_depth(cell) <= 8
			if not seed and can_sample:
				seed = _faces_void(cell)
			if not seed:
				continue
			seen[cell] = true
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		_sea_body[at] = true
		for dir in _ORTHO:
			var nb: Vector2i = at + dir
			if seen.has(nb):
				continue
			if not _sea_candidate(nb):
				continue
			seen[nb] = true
			queue.append(nb)


func _sea_candidate(cell: Vector2i) -> bool:
	if Art.terrain_seen(zone, cell) != "water":
		return false
	var zone_id := _zone_id_at(cell)
	if zone_id.contains("swamp"):
		return false
	if zone_id.begins_with("crosshaven_stoneford"):
		return false
	return true


## Paint empty cells beyond the coast with the same sea fill as the tiles.
## Eastmarch already extends kit sea into that void.
func _cache_void_sea() -> void:
	_void_sea.clear()
	_void_dist.clear()
	_void_margin = 0
	if zone == null or not zone.sample_terrain.is_valid():
		return
	if zone.zone_id.begins_with("crosshaven_eastmarch"):
		return
	var reach := 16
	var queue: Array[Vector2i] = []
	var dist := {}
	# Seed from the neighbours' coast as well, so a void cell gets the same
	# distance from every chunk that paints it and the fade has no step.
	var seed_pad := reach + SEA_FADE_CELLS + 1
	for y in range(-seed_pad, zone.height + seed_pad):
		for x in range(-seed_pad, zone.width + seed_pad):
			var cell := Vector2i(x, y)
			if not _sea_candidate(cell):
				continue
			if _water_grade(cell) != "sea":
				continue
			if not _faces_void(cell):
				continue
			for dir in _ORTHO:
				var nb: Vector2i = cell + dir
				if dist.has(nb):
					continue
				if Art.terrain_seen(zone, nb) != "":
					continue
				dist[nb] = 1
				queue.append(nb)
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		_void_sea[at] = true
		_void_dist[at] = int(dist[at])
		var here := int(dist[at])
		if here >= reach:
			continue
		for dir in _ORTHO:
			var next: Vector2i = at + dir
			if dist.has(next):
				continue
			if Art.terrain_seen(zone, next) != "":
				continue
			dist[next] = here + 1
			queue.append(next)
	if not _void_sea.is_empty():
		_void_margin = reach


## Outer water dissolves into the sea fill. River cells next to that sea
## pick up the same hue over a few cells.
func _cache_water_edge() -> void:
	_edge_fade.clear()
	_mouth_mix.clear()
	if zone == null:
		return
	var queue: Array[Vector2i] = []
	var dist := {}
	var margin := 4
	for y in range(-margin, zone.height + margin):
		for x in range(-margin, zone.width + margin):
			var cell := Vector2i(x, y)
			if Art.terrain_seen(zone, cell) != "water":
				continue
			if not _faces_void(cell):
				continue
			dist[cell] = 1
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		var here := int(dist[at])
		if here >= 4:
			continue
		for dir in _ORTHO:
			var nb: Vector2i = at + dir
			if dist.has(nb):
				continue
			if Art.terrain_seen(zone, nb) != "water":
				continue
			dist[nb] = here + 1
			queue.append(nb)
	_edge_fade = dist
	for y in range(-margin, zone.height + margin):
		for x in range(-margin, zone.width + margin):
			var cell := Vector2i(x, y)
			if Art.terrain_seen(zone, cell) != "water" or _water_grade(cell) != "river":
				continue
			var near := _near_sea_or_void(cell)
			if near == 1:
				_mouth_mix[cell] = 0.72
			elif near == 2:
				_mouth_mix[cell] = 0.44
			elif near == 3:
				_mouth_mix[cell] = 0.2


func _near_sea_or_void(cell: Vector2i) -> int:
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var nb := cell + Vector2i(dx, dy)
				var seen := Art.terrain_seen(zone, nb)
				if seen == "":
					return radius
				if seen == "water" and _water_grade(nb) == "sea":
					return radius
	return 99


func _water_grade_tint(cell: Vector2i) -> Color:
	var grade := _water_grade(cell)
	if grade == "swamp":
		return SWAMP_TINT
	if grade == "sea":
		return SEA_TINT
	return Color.WHITE


func _open_water_tile(id: String) -> bool:
	return id == "water" or id == "water_a" or id == "water_b" or id == "water_c" or id == "water_d" or id.begins_with("water_deep")


func _touches_sea_water(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nb: Vector2i = cell + Vector2i(dx, dy)
			if Art.terrain_seen(zone, nb) == "water" and _water_grade(nb) == "sea":
				return true
	return false


## One cell of sand where grass or a town path meets the sea.
## Cliffs keep their face and take the foam line instead. Northgate's own
## shore is snow, drawn by _draw_snow_lip.
func _shore_land(cell: Vector2i) -> bool:
	if _beach_at(cell) != "":
		return false
	if snow_shore_at(cell) >= 0.99:
		return false
	var seen := Art.terrain_seen(zone, cell)
	if seen == "" or seen == "water" or seen == "cliff":
		return false
	return _touches_sea_water(cell)


func _sand_pick(cell: Vector2i) -> Dictionary:
	var interiors: Array[String] = ["golden_plains_sand_a", "golden_plains_sand_b", "golden_plains_sand_c"]
	var floor_id := interiors[Art.h(cell.x, cell.y, interiors.size())]
	var g: Array[String] = []
	for side in Art.SIDES:
		var nb: Vector2i = cell + Art.SIDE_DIR[side]
		var seen := Art.terrain_seen(zone, nb)
		var joins := seen == "water" or _shore_land(nb)
		if not joins:
			g.append(side)
	if not g.is_empty():
		var edge := "golden_plains_sand_edge_" + "_".join(g)
		if Art.has("tiles", edge):
			floor_id = edge
	var corners: Array[String] = []
	for c_name in ["n", "e", "s", "w"]:
		var c := str(c_name)
		var rec: Array = Art.CORNERS[c]
		if g.has(str(rec[1])) or g.has(str(rec[2])):
			continue
		var diag: Vector2i = cell + (rec[0] as Vector2i)
		var seen := Art.terrain_seen(zone, diag)
		var joins := seen == "water" or _shore_land(diag)
		if joins:
			continue
		var corner_id := "golden_plains_sand_corner_" + c
		if Art.has("tiles", corner_id):
			corners.append(corner_id)
	return {"floor": floor_id, "corners": corners}


func _cave_id(cell: Vector2i) -> String:
	if zone == null:
		return ""
	if zone.zone_id == "crosshaven_eastmarch_coves" and cell == Vector2i(27, 4):
		return "cave_mouth_sandstone"
	if zone.zone_id == "crosshaven_eastmarch_sea_caves" and cell == Vector2i(32, 33):
		return "cave_mouth_grey"
	return ""


func _shore_prop(cell: Vector2i, family: String) -> String:
	if zone != null and zone.in_bounds(cell) and zone.blocked_at(cell):
		return ""
	if _cave_id(cell) != "" or _cave_id(cell + Vector2i(1, 0)) != "":
		return ""
	if family == "wet_sand" and Art.h(cell.x, cell.y, 9) == 0:
		var wet := ["mooring_post", "shell_heap", "driftwood_fork"]
		return str(wet[Art.h(cell.x + 1, cell.y, wet.size())])
	if family == "sand" and _sea_dist(cell) == 2 and Art.h(cell.x, cell.y, 7) == 0:
		var dry := ["tidepool_rocks_a", "tidepool_rocks_b", "driftwood_long", "shell_heap"]
		return str(dry[Art.h(cell.x, cell.y + 1, dry.size())])
	return ""


func _draw_beach(ci: Node2D, cell: Vector2i, family: String, steps: int) -> void:
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var south_tip := center + Vector2(0, Pick.HALF_H)
	var modulate := Color.WHITE
	var sea := family == "sea_shallow" or family == "sea_deep"
	# One sea surface. The kit tiles are regraded to the same blue as the fill.
	if sea:
		ci.draw_colored_polygon(_sea_diamond(cell, steps), Color("246e9e"))
		modulate = Color.WHITE
	var pick: Dictionary = Kit.pick("eastmarch", family, cell, Callable(self, "_family_seen"))
	var floor := str(pick.get("floor", ""))
	if floor != "":
		var floor_art := Kit.texture("eastmarch", floor)
		if sea:
			_paint_clamped(ci, floor_art, south_tip, modulate, WATER_OVERLAP, bool(pick.get("flip_h", false)), bool(pick.get("flip_v", false)))
		else:
			Kit.draw(ci, floor_art, south_tip, modulate, bool(pick.get("flip_h", false)), bool(pick.get("flip_v", false)))
	for corner_id in pick.get("corners", []):
		var corner_art := Kit.texture("eastmarch", str(corner_id))
		if sea:
			_paint_clamped(ci, corner_art, south_tip, modulate, WATER_OVERLAP, false, false)
		else:
			Kit.draw(ci, corner_art, south_tip, modulate, false, false)
	var prop := _shore_prop(cell, family)
	if prop != "":
		Kit.draw(ci, Kit.texture("eastmarch", prop), south_tip, Color.WHITE, false, false)


func _draw_cave(ci: Node2D, cell: Vector2i, steps: int) -> void:
	var id := _cave_id(cell)
	if id == "":
		return
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var south_tip := center + Vector2(0, Pick.HALF_H)
	Kit.draw(ci, Kit.texture("eastmarch", id), south_tip, Color.WHITE, false, false)


func _joins_kit_sand(cell: Vector2i) -> bool:
	for dir in _ORTHO:
		var fam := _beach_at(cell + dir)
		if fam == "sand" or fam == "wet_sand":
			return true
	for diag in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var corner := _beach_at(cell + diag)
		if corner == "sand" or corner == "wet_sand":
			return true
	return false


func _draw_run(ci: Node2D, s: int, i: int) -> void:
	var runs: Array = _runs.get(s, [])
	if i >= runs.size():
		return
	_draw_cells(ci, (runs[i] as Dictionary)["cells"])


func _draw_cells(row: Node2D, cells: Array[Vector2i]) -> void:
	for cell in cells:
		if not zone.in_bounds(cell) and Art.terrain_seen(zone, cell) == "" and _beach_at(cell) == "" and not _void_sea.has(cell):
			continue
		_draw_cell(row, cell)
		if _exit_dirs.has(cell):
			_draw_exit(row, cell, _exit_dirs[cell])


func _row_cells(s: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var margin := _view_margin()
	var x0 := maxi(-margin, s - (zone.height - 1 + margin))
	var x1 := mini(zone.width - 1 + margin, s + margin)
	for x in range(x0, x1 + 1):
		out.append(Vector2i(x, s - x))
	return out


func _foam_cell(cell: Vector2i) -> bool:
	if Art.terrain_seen(zone, cell) != "water" or _beach_at(cell) != "":
		return false
	if _water_grade(cell) != "sea":
		return false
	for dir in _ORTHO:
		var seen := Art.terrain_seen(zone, cell + dir)
		if seen != "" and seen != "water":
			return true
	return false


func _row_has_foam(s: int) -> bool:
	return not _row_foam_cells(s).is_empty()


## Foam cells of a row, found once per setup. Each ripple frame used to test
## every cell of every foam row again.
func _row_foam_cells(s: int) -> Array[Vector2i]:
	if _foam_cells.has(s):
		return _foam_cells[s]
	var out: Array[Vector2i] = []
	for cell in _row_cells(s):
		if _foam_cell(cell):
			out.append(cell)
	_foam_cells[s] = out
	return out


func _draw_foam_row(ci: Node2D, s: int) -> void:
	for cell in _row_foam_cells(s):
		_draw_sea_foam(ci, cell, Art.height_seen(zone, cell), true)


func _draw_cell(ci: Node2D, cell: Vector2i) -> void:
	var terrain := Art.terrain_seen(zone, cell)
	if terrain == "":
		var skirt := _beach_at(cell)
		if skirt == "sea_deep" or skirt == "sea_shallow":
			_draw_beach(ci, cell, skirt, 0)
		elif _void_sea.has(cell):
			_draw_void_sea(ci, cell, 0)
		return
	var steps := Art.height_seen(zone, cell)
	if _north_crag(cell):
		steps = _terrace(cell)
	var rank := void_rank(cell)
	var beach := _beach_at(cell)
	# A stream that ends inland can still close on a grass bank. Sea, and the
	# river where it meets the map fill, stay water so the edge can fade.
	var sea_edge := terrain == "water" and (_water_grade(cell) == "sea" or _rim_depth(cell) <= 4)
	var bank := terrain == "water" and rank == 1 and beach == "" and not sea_edge
	var paint := "golden_plains" if bank else terrain
	if beach != "":
		_draw_beach(ci, cell, beach, steps)
	elif _use_kit:
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
	_draw_cave(ci, cell, steps)
	_theme_marks(ci, cell, terrain, steps)
	if not _kit_sea(cell):
		_fade_void_edge(ci, cell, steps, rank, terrain)
	_dust_snow(ci, cell, paint, steps)


func _draw_flat_faces(ci: Node2D, lifted: PackedVector2Array, steps: int, side: Color) -> void:
	var drop := Vector2(0, float(steps) * BoardVisualSort.ELEVATION_PIXELS)
	ci.draw_colored_polygon(PackedVector2Array([lifted[3], lifted[2], lifted[2] + drop, lifted[3] + drop]), side)
	ci.draw_colored_polygon(PackedVector2Array([lifted[2], lifted[1], lifted[1] + drop, lifted[2] + drop]), side.darkened(0.18))


## Northgate crag chunks stay height 1 in the zone data. The terrace is draw-only,
## so zone tests that forbid a step of more than one stay green.
func _north_crag(cell: Vector2i) -> bool:
	if zone == null:
		return false
	var id := zone.zone_id
	if not id.begins_with("crosshaven_northgate_crag") and id != "crosshaven_northgate_pass":
		return false
	return Art.terrain_seen(zone, cell) == "cliff"


func _terrace(cell: Vector2i) -> int:
	if zone == null:
		return 0
	var base := Art.height_seen(zone, cell)
	if Art.terrain_seen(zone, cell) != "cliff":
		return base
	var id := zone.zone_id
	if not id.begins_with("crosshaven_northgate_crag") and id != "crosshaven_northgate_pass":
		return base
	# A step on most edges, so the dotted cliff tops do not sit as one flat grid.
	var band := posmod(cell.x + cell.y * 2, 3)
	if Art.h(cell.x, cell.y, 5) == 0:
		band = mini(band + 1, 2)
	return base + band


func _draw_crag_faces(ci: Node2D, cell: Vector2i, south_tip: Vector2) -> void:
	var elev := _terrace(cell)
	var tint := _floor_modulate(cell, "cliff")
	for face in ["left", "right"]:
		var step := Vector2i(0, 1) if face == "left" else Vector2i(1, 0)
		var ncell := cell + step
		var diff := elev - _terrace(ncell)
		var base_x := -32.0 if face == "left" else 0.0
		for k in range(maxi(diff, 0)):
			var variant := "a"
			if k == 0:
				variant = "top"
			elif k % 2 == 0:
				variant = "b"
			if k == diff - 1 and k > 0:
				var below_water := Art.terrain_seen(zone, ncell) == "water"
				variant = "base_water" if below_water else "base_ground"
			var tid := _face_id("cliff_side_%s_%s" % [face, variant], cover_at(cell) >= 0.5)
			if Art.has("tiles", tid):
				Art.draw_at(ci, Art.texture("tiles", tid), south_tip + Vector2(base_x, -16.0 + 10.0 * float(k)), Color.WHITE if tid.begins_with("snow_") else tint)


## Technical Artist kit path: height strips, autotiled floor, corner decals.
func _draw_cell_kit(ci: Node2D, cell: Vector2i, terrain: String, steps: int, bank: bool = false) -> void:
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var south_tip := center + Vector2(0, Pick.HALF_H)
	var shown := "golden_plains" if bank else terrain
	if _north_crag(cell):
		_draw_crag_faces(ci, cell, south_tip)
	elif steps > 0:
		var strips := Art.face_strips(zone, cell)
		var all_found := true
		for strip in strips:
			if not Art.has("tiles", strip["id"]):
				all_found = false
				break
		var face_tint := _floor_modulate(cell, shown)
		var snowy_face := cover_at(cell) >= 0.5
		if snowy_face:
			face_tint = Color.WHITE
		if all_found:
			for strip in strips:
				Art.draw_at(ci, Art.texture("tiles", _face_id(str(strip["id"]), snowy_face)), south_tip + strip["offset"], face_tint)
		else:
			_draw_flat_faces(ci, Pick.diamond(cell, float(steps)), steps, SIDE.get(shown, Color.DARK_MAGENTA))
	if bank:
		_draw_named_floor(ci, south_tip, "golden_plains_a", "golden_plains", _floor_modulate(cell, "golden_plains"))
		return
	var cover := cover_at(cell)
	if cover >= 0.999 and terrain != "water":
		# Snow town: the painted snow replaces the floor art outright.
		_draw_snow_floor(ci, cell, steps, terrain, true)
		var lip_amount := snow_shore_at(cell)
		if lip_amount > 0.0:
			_draw_snow_lip(ci, cell, steps, lip_amount)
		return
	var floor_tint := _floor_modulate(cell, terrain)
	var pick := Art.pick_tile(zone, cell)
	var floor_id := str(pick["floor"])
	var corner_ids: Array = pick["corners"]
	# Open sea is one world-space surface. Per-cell water tiles carried a
	# darker rim in their art, which read as a diamond lattice.
	if terrain == "water" and _water_grade(cell) == "sea":
		_draw_sea_surface(ci, cell, steps)
		if VisualSettings.current != null and VisualSettings.current.enabled("animations"):
			_draw_sea_sparkle(ci, cell, steps)
		_draw_sea_foam(ci, cell, steps, false)
		return
	var water_overlap := 0.0
	if terrain == "water":
		water_overlap = WATER_OVERLAP
		if _open_water_tile(floor_id):
			floor_tint = _water_grade_tint(cell)
			var mix := float(_mouth_mix.get(cell, 0.0))
			if mix > 0.0:
				floor_tint = floor_tint.lerp(SEA_TINT, mix)
		elif _water_grade(cell) == "swamp":
			floor_tint = SWAMP_TINT
		else:
			# Bank and shore art already carry their grade. A multiply would tint the sand.
			floor_tint = Color.WHITE
	elif _shore_land(cell):
		var sand_pick := _sand_pick(cell)
		floor_id = str(sand_pick["floor"])
		corner_ids = sand_pick["corners"]
		floor_tint = Color.WHITE
	var drew_ripple := false
	if terrain == "water" and VisualSettings.current != null and VisualSettings.current.enabled("animations"):
		drew_ripple = _draw_ripple(ci, floor_id + "_ripple", south_tip, floor_tint, water_overlap)
	if not drew_ripple:
		var floor_art := Art.texture("tiles", floor_id)
		if floor_art.is_empty():
			floor_art = Art.texture("tiles", terrain)
		if cover > 0.0 and terrain != "water":
			_paint_exact(ci, floor_art, cell, steps, floor_tint)
		else:
			_paint_art(ci, floor_art, south_tip, floor_tint, water_overlap)
	if cover > 0.0 and terrain != "water":
		# Under thinning snow the floor stays inside its own diamond: the
		# kit's edge bleed drew dark seams over the neighbour's snow.
		corner_ids = []
		pick["lip"] = ""
	for raw_corner in corner_ids:
		var corner_id := str(raw_corner)
		var corner_art := Art.texture("tiles", corner_id)
		_paint_art(ci, corner_art, south_tip, floor_tint, water_overlap)
	if terrain == "water" and VisualSettings.current != null and VisualSettings.current.enabled("animations"):
		_draw_water_polish(ci, cell, steps)
	var lip := str(pick.get("lip", ""))
	if lip != "":
		var lip_art := Art.texture("tiles", lip)
		if not lip_art.is_empty():
			var lsize := Art.size_of(lip_art)
			Art.draw_at(ci, lip_art, south_tip + Vector2(-lsize.x * 0.5, -lsize.y), floor_tint)
	if cover > 0.0 and terrain != "water":
		_draw_snow_floor(ci, cell, steps, terrain, false)
	var snow_lip := snow_shore_at(cell)
	if terrain != "water" and snow_lip > 0.0:
		_draw_snow_lip(ci, cell, steps, snow_lip)


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
	# Sea foam is drawn on its own, inset onto the water. River banks stay.
	if _water_grade(cell) == "sea":
		return
	var nb: Vector2i = cell + step
	var seen := Art.terrain_seen(zone, nb)
	# Empty map and open water do not get a line. That line was the white edge.
	if seen == "" or seen == "water":
		return
	var snow := snow_at_cell(cell)
	if snow > 0.2:
		ci.draw_line(d[ia], d[ib], Color(0.86, 0.95, 1.0, 0.92), 2.6)
		return
	var sand := Art.terrain_seen(zone, nb) != "cliff" and _weight(theme_weights(cell), "eastmarch") > 0.18
	var foam_a := 0.78 if sand else 0.55
	var foam_w := 2.4 if sand else 1.6
	ci.draw_line(d[ia], d[ib], Color(0.93, 0.97, 1.0, foam_a), foam_w)


func _draw_named_floor(ci: Node2D, south_tip: Vector2, first_id: String, fallback_id: String, modulate: Color = Color.WHITE) -> void:
	var floor_art := Art.texture("tiles", first_id)
	if floor_art.is_empty():
		floor_art = Art.texture("tiles", fallback_id)
	if floor_art.is_empty():
		return
	var size := Art.size_of(floor_art)
	Art.draw_at(ci, floor_art, south_tip + Vector2(-size.x * 0.5, -size.y), modulate)


func _fade_void_edge(ci: Node2D, cell: Vector2i, steps: int, _rank: int, terrain: String) -> void:
	if terrain != "water":
		return
	# Sea already matches the fill. A translucent diamond on top drew the grid.
	if _water_grade(cell) == "sea":
		return
	var dist := int(_edge_fade.get(cell, 0))
	if dist <= 0:
		return
	# Textured water thins into the sea fill over four cells. The outer cell
	# is not a solid cap, so there is no white cut and no grass grid.
	var fade := Color("246e9e")
	if dist == 1:
		fade.a = 0.78
	elif dist == 2:
		fade.a = 0.55
	elif dist == 3:
		fade.a = 0.32
	else:
		fade.a = 0.14
	ci.draw_colored_polygon(Pick.diamond(cell, float(steps)), fade)


func _paint_art(ci: Node2D, art: Dictionary, south_tip: Vector2, tint: Color, overlap: float) -> void:
	if art.is_empty():
		return
	if overlap > 0.0:
		_paint_clamped(ci, art, south_tip, tint, overlap, false, false)
		return
	var tex: Texture2D = art["tex"]
	var size := Art.size_of(art)
	var top_left := south_tip + Vector2(-size.x * 0.5, -size.y)
	ci.draw_texture_rect(tex, Rect2(top_left, size), false, tint)


## Sample inside the tile so the transparent fringe is not the seam.
## Mipmaps stay off. The dest grows by `overlap` so neighbours share pixels.
func _paint_clamped(ci: Node2D, art: Dictionary, south_tip: Vector2, tint: Color, overlap: float, flip_h: bool, flip_v: bool) -> void:
	if art.is_empty():
		return
	var tex: Texture2D = art["tex"]
	var scale := float(art["scale"])
	var tex_size := tex.get_size()
	var size := tex_size * scale
	var inset := 4.0 if scale < 0.99 else 3.0
	if tex_size.x <= inset * 2.0 + 2.0 or tex_size.y <= inset * 2.0 + 2.0:
		var plain := south_tip + Vector2(-size.x * 0.5, -size.y)
		ci.draw_texture_rect(tex, Rect2(plain, size), false, tint)
		return
	var src := Rect2(inset, inset, tex_size.x - inset * 2.0, tex_size.y - inset * 2.0)
	var top_left := south_tip + Vector2(-size.x * 0.5, -size.y)
	var dest := Rect2(top_left - Vector2(overlap, overlap), size + Vector2(overlap * 2.0, overlap * 2.0))
	if flip_h or flip_v:
		var center := dest.get_center()
		var sx := -1.0 if flip_h else 1.0
		var sy := -1.0 if flip_v else 1.0
		ci.draw_set_transform(center, 0.0, Vector2(sx, sy))
		ci.draw_texture_rect_region(tex, Rect2(-dest.size * 0.5, dest.size), src, tint)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	ci.draw_texture_rect_region(tex, dest, src, tint)


## Grow the diamond so neighbouring fills share an edge and the cell grid stays hidden.
func _sea_diamond(cell: Vector2i, steps: int) -> PackedVector2Array:
	var d := Pick.diamond(cell, float(steps))
	var center := Vector2.ZERO
	for i in 4:
		center += d[i]
	center *= 0.25
	var grown := PackedVector2Array()
	var pad := 3.0
	for i in 4:
		var point: Vector2 = d[i]
		var away := point - center
		var length := away.length()
		if length < 0.01:
			grown.append(point)
		else:
			grown.append(point + away * (pad / length))
	return grown


## Flat sea past the last tile, with the textured surface thinning into it
## over the first few cells. No snow wash: the sea is one blue everywhere.
func _draw_void_sea(ci: Node2D, cell: Vector2i, steps: int) -> void:
	_draw_sea_surface(ci, cell, steps)


static func _load_sea_textures() -> void:
	if _sea_tex_loaded:
		return
	_sea_tex_loaded = true
	_sea_surface_tex = _repeat_texture(SEA_SURFACE_PATH)
	_sea_glint_tex = _repeat_texture(SEA_GLINT_PATH)


static func _repeat_texture(path: String) -> CanvasTexture:
	if not ResourceLoader.exists(path):
		return null
	var wrapped := CanvasTexture.new()
	wrapped.diffuse_texture = load(path)
	wrapped.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wrapped.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return wrapped


## How much of the textured surface shows on this cell: all of it on water
## and land, thinning over SEA_FADE_CELLS of void into the flat fill.
func _sea_alpha(cell: Vector2i) -> float:
	if Art.terrain_seen(zone, cell) != "":
		return 1.0
	if not _void_dist.has(cell):
		return 0.0
	var d := int(_void_dist[cell])
	return clampf(1.0 - float(d) / float(SEA_FADE_CELLS + 1), 0.0, 1.0)


## Diamond corner i (N, E, S, W) is shared by four cells. Its alpha is their
## mean plus a little world-space jitter, so the fade is soft and not a ruler line.
func _corner_alpha(cell: Vector2i, i: int) -> float:
	var base := cell
	match i:
		0:
			base = cell + Vector2i(-1, -1)
		1:
			base = cell + Vector2i(0, -1)
		2:
			base = cell
		3:
			base = cell + Vector2i(-1, 0)
	var sum := 0.0
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		sum += _sea_alpha(base + (o as Vector2i))
	var a := sum * 0.25
	if a > 0.0 and a < 1.0:
		a += (_hash(world_origin + base) - 0.5) * 0.3
	return clampf(a, 0.0, 1.0)


## The four corner alphas of a cell, empty when none shows. They depend on
## the terrain only, so each cell works them out once per setup, not on every
## ripple frame.
func _corner_alphas(cell: Vector2i) -> PackedFloat32Array:
	var known: Variant = _corner_cache.get(cell)
	if known != null:
		return known
	var alphas := PackedFloat32Array()
	var any := false
	for i in 4:
		var a := _corner_alpha(cell, i)
		alphas.append(a)
		if a > 0.0:
			any = true
	if not any:
		alphas = PackedFloat32Array()
	_corner_cache[cell] = alphas
	return alphas


func _sea_phase() -> float:
	if _ripple_frame < 0:
		return 0.0
	return float(_ripple_frame) / 8.0 * TAU


## One open-sea cell: flat fill, then the seamless surface and glints mapped
## in world pixels. Neighbouring cells sample the same texels, so no edge shows.
func _draw_sea_surface(ci: Node2D, cell: Vector2i, steps: int) -> void:
	var d := Pick.diamond(cell, float(steps))
	ci.draw_colored_polygon(d, SEA_FILL)
	_load_sea_textures()
	if _sea_surface_tex == null:
		return
	var alphas := _corner_alphas(cell)
	if alphas.is_empty():
		return
	var shift := BoardVisualSort.cell_to_local(world_origin) + Vector2(0, float(steps) * BoardVisualSort.ELEVATION_PIXELS)
	var phase := _sea_phase()
	var sway := Vector2(cos(phase), sin(phase)) * 2.0
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for i in 4:
		colors.append(Color(1, 1, 1, alphas[i]))
		uvs.append((d[i] + shift + sway) / SEA_PERIOD)
	ci.draw_polygon(d, colors, uvs, _sea_surface_tex)
	if _sea_glint_tex == null or VisualSettings.current == null or not VisualSettings.current.enabled("animations"):
		return
	var glint_sway := Vector2(-sin(phase), cos(phase)) * 3.0
	var glint_colors := PackedColorArray()
	var glint_uvs := PackedVector2Array()
	for i in 4:
		glint_colors.append(Color(1, 1, 1, alphas[i] * (0.75 + 0.25 * sin(phase * 2.0))))
		glint_uvs.append((d[i] + shift + glint_sway) / GLINT_PERIOD)
	ci.draw_polygon(d, glint_colors, glint_uvs, _sea_glint_tex)


## Sparse sparkles on open sea. The old per-cell shimmer line repeated on
## every diamond and read as a grid.
func _draw_sea_sparkle(ci: Node2D, cell: Vector2i, steps: int) -> void:
	var n := _hash(world_origin + cell)
	if n < 0.86:
		return
	var c := BoardVisualSort.cell_to_local(cell, float(steps))
	var jitter := Vector2((_hash(world_origin + cell + Vector2i(7, 3)) - 0.5) * 36.0, (_hash(world_origin + cell + Vector2i(2, 9)) - 0.5) * 14.0)
	var phase := _sea_phase()
	var a := 0.35 + 0.55 * absf(sin(phase + n * 9.0))
	ci.draw_circle(c + jitter, 1.1, Color(1, 1, 1, a))


## Soft foam where open sea meets land, in the beach kit's style: a bright
## edge that thins onto the water over a few pixels, with a slow wobble in
## world space so it runs on across cells instead of making a chevron per tile.
## In front of the Northgate snow lip it also takes a thin ice rim.
func _draw_sea_foam(ci: Node2D, cell: Vector2i, steps: int, front: bool) -> void:
	if _water_grade(cell) != "sea":
		return
	# Eastmarch kit surf already paints that shore.
	if _beach_at(cell) != "":
		return
	var d := Pick.diamond(cell, float(steps))
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var sides: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for k in 4:
		# Land behind the water (north-west, north-east sides) gets its foam in
		# the water's own row, so a raised cell in front still covers it. Land
		# in front gets it from the foam row, which sorts after that land.
		if (k == 1 or k == 2) != front:
			continue
		var nb: Vector2i = cell + sides[k]
		var seen := Art.terrain_seen(zone, nb)
		if seen == "" or seen == "water":
			continue
		# Eastmarch kit sand carries its own surf on the edge piece.
		var kit := _beach_at(nb)
		if kit == "sand" or kit == "wet_sand":
			continue
		# A raised bank in front hides the plain edge. The line follows the
		# visible top of that bank instead.
		var lift := Vector2.ZERO
		if k == 1 or k == 2:
			var rise := maxi(_drawn_steps(nb) - steps, 0)
			lift = Vector2(0, -float(rise) * BoardVisualSort.ELEVATION_PIXELS)
		_soft_foam_edge(ci, d[k] + lift, d[(k + 1) % 4] + lift, center + lift, snow_shore_at(nb), front)


## Height a cell is drawn at. The Northgate crag terraces sit above their data height.
func _drawn_steps(cell: Vector2i) -> int:
	if _north_crag(cell):
		return _terrace(cell)
	return Art.height_seen(zone, cell)


func _soft_foam_edge(ci: Node2D, a: Vector2, b: Vector2, center: Vector2, ice: float, front: bool) -> void:
	var shift := BoardVisualSort.cell_to_local(world_origin)
	var phase := _sea_phase()
	# Every point moves the same way onto the water, so the band of one cell
	# meets the next one's on a straight coast with no notch. In front of a
	# bank it runs straight up the screen. Behind the water it runs square to
	# the edge, which keeps it inside the cell so the next cell does not cut it.
	var mid_edge := (a + b) * 0.5
	var dir := Vector2(0, -1.0 if center.y < mid_edge.y else 1.0)
	if not front:
		var along := (b - a).normalized()
		dir = Vector2(-along.y, along.x)
		if dir.dot(center - mid_edge) < 0.0:
			dir = -dir
	var segs := 6
	var rim := PackedVector2Array()
	var mid := PackedVector2Array()
	var inner := PackedVector2Array()
	var base := PackedVector2Array()
	for j in segs + 1:
		var t := float(j) / float(segs)
		var p := a.lerp(b, t)
		var w := p + shift
		var wob := 0.5 + 0.5 * sin(w.x * 0.09 + w.y * 0.13 + phase)
		var wob2 := 0.5 + 0.5 * sin(w.x * 0.05 - w.y * 0.11 - phase * 0.5 + 1.7)
		# In pixels. The first one or two sit under the neighbour's lip.
		var start := 1.5 + 1.5 * ice
		base.append(p + dir * 0.5)
		rim.append(p + dir * start)
		mid.append(p + dir * (start + 2.6 + 1.6 * wob))
		inner.append(p + dir * (start + 6.5 + 2.5 * wob2))
	var crest := Color(0.95, 0.98, 1.0, 0.80)
	var veil := Color(0.92, 0.97, 1.0, 0.40)
	var clear := Color(0.92, 0.97, 1.0, 0.0)
	for j in segs:
		# From the rim, so no sliver of open water shows inside the crest.
		ci.draw_polygon(PackedVector2Array([rim[j], rim[j + 1], mid[j + 1], mid[j]]), PackedColorArray([crest, crest, veil, veil]))
		ci.draw_polygon(PackedVector2Array([mid[j], mid[j + 1], inner[j + 1], inner[j]]), PackedColorArray([veil, veil, clear, clear]))
	if ice > 0.0:
		# Thin ice rim hugging the snow lip: pale band, then a bright hairline.
		var band := Color(0.80, 0.92, 1.0, 0.6 * ice)
		for j in segs:
			ci.draw_polygon(PackedVector2Array([base[j], base[j + 1], rim[j + 1], rim[j]]), PackedColorArray([band, band, band, band]))
		ci.draw_polyline(rim, Color(0.90, 0.97, 1.0, 0.9 * ice), 1.2)


## Land cells of the Northgate chunk that touch the sea take a snow lip, not
## sand. Shore cells just past the town keep a thinning share of it, so the
## coast turns from snow to sand over SNOW_SHORE_BLEND cells.
func _cache_snow_shore() -> void:
	_snow_shore.clear()
	# Only Northgate and the crag chunks either side of it reach that coast.
	if zone == null or not zone.zone_id.begins_with("crosshaven_northgate"):
		return
	var margin := maxi(_view_margin(), 2) + 1
	var town := {}
	var shores: Array[Vector2i] = []
	var pad := margin + SNOW_SHORE_BLEND
	for y in range(-pad, zone.height + pad):
		for x in range(-pad, zone.width + pad):
			var cell := Vector2i(x, y)
			var seen := Art.terrain_seen(zone, cell)
			if seen == "" or seen == "water":
				continue
			if not _touches_sea_water(cell):
				continue
			if _zone_id_at(cell) == "crosshaven_northgate":
				town[cell] = true
			else:
				shores.append(cell)
	if town.is_empty():
		return
	for cell in town.keys():
		_snow_shore[cell] = 1.0
	for cell in shores:
		var best := 99
		for dy in range(-SNOW_SHORE_BLEND, SNOW_SHORE_BLEND + 1):
			for dx in range(-SNOW_SHORE_BLEND, SNOW_SHORE_BLEND + 1):
				if town.has(cell + Vector2i(dx, dy)):
					best = mini(best, maxi(absi(dx), absi(dy)))
		if best <= SNOW_SHORE_BLEND:
			_snow_shore[cell] = 1.0 - float(best) / float(SNOW_SHORE_BLEND + 1)


func snow_shore_at(cell: Vector2i) -> float:
	return float(_snow_shore.get(cell, 0.0))


## Packed snow over the shore cell, with a few grey stones at the waterline.
func _draw_snow_lip(ci: Node2D, cell: Vector2i, steps: int, amount: float) -> void:
	var center := BoardVisualSort.cell_to_local(cell, float(steps))
	var south_tip := center + Vector2(0, Pick.HALF_H)
	var crusts: Array[String] = ["snow_crust_a", "snow_crust_b", "snow_crust_c"]
	var art := Art.texture("tiles", crusts[Art.h(cell.x, cell.y, crusts.size())])
	if not art.is_empty():
		var tex: Texture2D = art["tex"]
		# A touch larger than the cell so neighbouring lips share their ragged edge.
		var size := Art.size_of(art) * 1.12
		var top_left := center + Vector2(-size.x * 0.5, -size.y * 0.5)
		ci.draw_texture_rect(tex, Rect2(top_left, size), false, Color(1, 1, 1, amount))
	var d := Pick.diamond(cell, float(steps))
	var sides: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for k in 4:
		var nb: Vector2i = cell + sides[k]
		if Art.terrain_seen(zone, nb) != "water" or _water_grade(nb) != "sea":
			continue
		var a: Vector2 = d[k]
		var b: Vector2 = d[(k + 1) % 4]
		for j in 3:
			var salt := world_origin + cell * 4 + Vector2i(k, j)
			# Not every slot takes a stone, so the waterline is not a chain.
			if _hash(salt + Vector2i(11, 4)) < 0.4:
				continue
			var t := (float(j) + 0.1 + 0.8 * _hash(salt)) / 3.0
			var p := a.lerp(b, t).lerp(center, 0.06 + 0.12 * _hash(salt + Vector2i(3, 1)))
			var rx := 2.0 + 3.2 * _hash(salt + Vector2i(5, 2))
			var ry := rx * 0.55
			_soft_blob(ci, p + Vector2(0, 0.8), rx, ry, Color(0.30, 0.33, 0.38, 0.55 * amount), _hash(salt))
			_soft_blob(ci, p, rx * 0.9, ry * 0.85, Color(0.58, 0.61, 0.66, 0.95 * amount), _hash(salt) + 0.4)
			_soft_blob(ci, p + Vector2(-rx * 0.2, -ry * 0.3), rx * 0.45, ry * 0.35, Color(0.86, 0.89, 0.93, 0.8 * amount), _hash(salt) + 0.9)


## Under snow, every height face is the snowy stone strip: snow over the lip,
## grey rock below, no grass rim.
func _face_id(id: String, snowy: bool) -> String:
	if not snowy:
		return id
	var at := id.find("_side_")
	if at < 0:
		return id
	var snow_id := "snow" + id.substr(at)
	return snow_id if Art.has("tiles", snow_id) else id


static func snow_town(zone_id: String) -> bool:
	return zone_id.begins_with("crosshaven_northgate")


## Every cell of a Northgate chunk is under snow. Cells of other chunks within
## SNOW_BLEND of one thin out, with a little jitter so the edge is not a line.
func _cache_cover() -> void:
	_cover.clear()
	if zone == null or not snow_kit:
		return
	var full := snow_town(zone.zone_id)
	if not full and snow_rects.is_empty():
		return
	var margin := _view_margin()
	var reach := Rect2i(world_origin - Vector2i(margin + SNOW_BLEND, margin + SNOW_BLEND), Vector2i(zone.width, zone.height) + Vector2i(2, 2) * (margin + SNOW_BLEND))
	var near: Array[Rect2i] = []
	for r in snow_rects:
		if r.intersects(reach):
			near.append(r)
	if not full and near.is_empty():
		return
	for y in range(-margin, zone.height + margin):
		for x in range(-margin, zone.width + margin):
			var cell := Vector2i(x, y)
			if full and zone.in_bounds(cell):
				_cover[cell] = 1.0
				continue
			var world := world_origin + cell
			var best := 99
			for r in near:
				var dx := maxi(maxi(r.position.x - world.x, world.x - (r.end.x - 1)), 0)
				var dy := maxi(maxi(r.position.y - world.y, world.y - (r.end.y - 1)), 0)
				best = mini(best, maxi(dx, dy))
			if full and best > 0:
				# Outside the chunk without a plane: measure to the chunk itself.
				var dx2 := maxi(maxi(-x, x - (zone.width - 1)), 0)
				var dy2 := maxi(maxi(-y, y - (zone.height - 1)), 0)
				best = mini(best, maxi(dx2, dy2))
			if best == 0:
				_cover[cell] = 1.0
				continue
			if best > SNOW_BLEND:
				continue
			var c := 1.0 - float(best) / float(SNOW_BLEND + 1)
			c += (_hash(world) - 0.5) * 0.24
			_cover[cell] = clampf(c, 0.05, 0.95)


## How much town snow lies on this cell: 1 in Northgate, 0 far from it.
func cover_at(cell: Vector2i) -> float:
	return float(_cover.get(cell, 0.0))


static func _load_snow_textures() -> void:
	if _snow_tex_loaded:
		return
	_snow_tex_loaded = true
	_snow_field_tex = _repeat_texture(SNOW_FIELD_PATH)
	_snow_cobble_tex = _repeat_texture(SNOW_COBBLE_PATH)


## Cover at the diamond corner `i` (N, E, S, W): the mean of the four cells sharing it.
func _cover_corner(cell: Vector2i, i: int) -> float:
	var base := cell
	match i:
		0:
			base = cell + Vector2i(-1, -1)
		1:
			base = cell + Vector2i(0, -1)
		3:
			base = cell + Vector2i(-1, 0)
	var sum := 0.0
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		sum += cover_at(base + (o as Vector2i))
	return sum * 0.25


## Thin cover breaks into patches, not an even fade: each corner holds its
## snow until a world-space noise threshold, so the town edge is ragged.
func _patchy(cover: float, cell: Vector2i, i: int) -> float:
	if cover >= 0.999 or cover <= 0.0:
		return cover
	var corner := cell
	match i:
		1:
			corner = cell + Vector2i(1, 0)
		2:
			corner = cell + Vector2i(1, 1)
		3:
			corner = cell + Vector2i(0, 1)
	var n := _hash(world_origin + corner + Vector2i(911, 37))
	return clampf(cover * 1.6 - 0.6 * n, 0.0, 1.0)


## Share of the four cells around corner `i` that are not road.
func _off_road_corner(cell: Vector2i, i: int) -> float:
	var base := cell
	match i:
		0:
			base = cell + Vector2i(-1, -1)
		1:
			base = cell + Vector2i(0, -1)
		3:
			base = cell + Vector2i(-1, 0)
	var off := 0
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var seen := Art.terrain_seen(zone, base + (o as Vector2i))
		if seen != "dirt_road":
			off += 1
	return float(off) * 0.25


## World-space snow over a cell. Roads are snowy cobble: the stones show,
## snow lies in the joints and banks up along the edges, the middle is swept.
func _draw_snow_floor(ci: Node2D, cell: Vector2i, steps: int, terrain: String, full: bool) -> void:
	_load_snow_textures()
	if _snow_field_tex == null:
		return
	var d := Pick.diamond(cell, float(steps))
	var shift := BoardVisualSort.cell_to_local(world_origin) + Vector2(0, float(steps) * BoardVisualSort.ELEVATION_PIXELS)
	var uvs := PackedVector2Array()
	var amount := PackedFloat32Array()
	for i in 4:
		uvs.append((d[i] + shift) / SNOW_PERIOD)
		amount.append(1.0 if full else _patchy(_cover_corner(cell, i), cell, i))
	if terrain != "dirt_road" or _snow_cobble_tex == null:
		ci.draw_polygon(d, _alpha_colors(amount, 1.0), uvs, _snow_field_tex)
		return
	ci.draw_polygon(d, _alpha_colors(amount, 1.0), uvs, _snow_cobble_tex)
	var banked := PackedFloat32Array()
	for i in 4:
		var off := _off_road_corner(cell, i)
		var bank := 0.10
		if off >= 0.74:
			bank = 0.95
		elif off >= 0.49:
			bank = 0.70
		elif off > 0.0:
			bank = 0.38
		banked.append(amount[i] * bank)
	ci.draw_polygon(d, _alpha_colors(banked, 1.0), uvs, _snow_field_tex)
	_draw_road_drifts(ci, cell, d, amount)


## A floor tile mapped onto exactly its diamond, with no edge bleed.
func _paint_exact(ci: Node2D, art: Dictionary, cell: Vector2i, steps: int, tint: Color) -> void:
	if art.is_empty():
		return
	var d := Pick.diamond(cell, float(steps))
	var uvs := PackedVector2Array([Vector2(0.5, 0.03), Vector2(0.97, 0.5), Vector2(0.5, 0.97), Vector2(0.03, 0.5)])
	var cols := PackedColorArray([tint, tint, tint, tint])
	ci.draw_polygon(d, cols, uvs, art["tex"])


func _alpha_colors(alphas: PackedFloat32Array, scale: float) -> PackedColorArray:
	var out := PackedColorArray()
	for a in alphas:
		out.append(Color(1, 1, 1, clampf(a * scale, 0.0, 1.0)))
	return out


## Soft lumps of snow along each road side that meets snowy ground.
func _draw_road_drifts(ci: Node2D, cell: Vector2i, d: PackedVector2Array, amount: PackedFloat32Array) -> void:
	var sides: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var center := (d[0] + d[2]) * 0.5
	for k in 4:
		var seen := Art.terrain_seen(zone, cell + sides[k])
		if seen == "dirt_road" or seen == "" or seen == "water":
			continue
		var a: Vector2 = d[k]
		var b: Vector2 = d[(k + 1) % 4]
		var strength := (amount[k] + amount[(k + 1) % 4]) * 0.5
		if strength <= 0.05:
			continue
		for j in 4:
			var salt := world_origin + cell * 4 + Vector2i(k, j)
			var t := (float(j) + 0.1 + 0.8 * _hash(salt)) / 4.0
			var p := a.lerp(b, t).lerp(center, 0.06 + 0.16 * _hash(salt + Vector2i(3, 1)))
			var rx := 8.0 + 6.0 * _hash(salt + Vector2i(5, 2))
			var ry := rx * 0.42
			_soft_blob(ci, p + Vector2(0, 1.4), rx, ry, Color(0.70, 0.74, 0.90, 0.55 * strength), _hash(salt))
			_soft_blob(ci, p, rx * 0.92, ry * 0.9, Color(0.96, 0.97, 1.0, 0.95 * strength), _hash(salt) + 0.4)


## Hook for the painted theme kits. Weights fall off over tens of cells,
## so a border is a mix, not a straight seam between chunk ids.
func theme_weights(cell: Vector2i) -> Dictionary:
	var world := Vector2(world_origin + cell)
	var names: Array[String] = ["stoneford", "northgate", "eastmarch", "southbridge", "westwatch"]
	var raw := {}
	var sum := 0.0
	for id in names:
		var dist := world.distance_to(_theme_anchor(id))
		var t := clampf(1.0 - dist / 52.0, 0.0, 1.0)
		var w := t * t
		raw[id] = w
		sum += w
	if sum <= 0.001:
		for id in names:
			raw[id] = 0.0
		return raw
	for id in names:
		raw[id] = float(raw[id]) / sum
	return raw


func _theme_anchor(theme: String) -> Vector2:
	match theme:
		"stoneford":
			return Vector2(-56, 18)
		"northgate":
			return Vector2(20, -52)
		"eastmarch":
			return Vector2(92, 18)
		"southbridge":
			return Vector2(20, 82)
		"westwatch":
			return Vector2(-44, 46)
	return Vector2(18, 16)


func _tint_of(theme: String) -> Color:
	match theme:
		"stoneford":
			return Color(1.0, 0.98, 0.90)
		"northgate":
			return Color(0.84, 0.90, 0.98)
		"eastmarch":
			return Color(1.0, 0.88, 0.64)
		"southbridge":
			return Color(0.55, 0.68, 0.42)
		"westwatch":
			return Color(0.58, 0.48, 0.78)
	return Color.WHITE


func _weight(weights: Dictionary, id: String) -> float:
	return float(weights.get(id, 0.0))


func _floor_modulate(cell: Vector2i, terrain: String) -> Color:
	if terrain == "dirt_road":
		return _with_frost(Color(1.0, 0.97, 0.90), cell, terrain)
	var weights := theme_weights(cell)
	var names: Array[String] = ["stoneford", "northgate", "eastmarch", "southbridge", "westwatch"]
	var tint := Color(0, 0, 0, 0)
	var any := false
	for id in names:
		var w := _weight(weights, id)
		if w <= 0.0:
			continue
		any = true
		tint += _tint_of(id) * w
	if not any:
		tint = Color.WHITE
	if terrain == "golden_plains" and _joins_kit_sand(cell):
		return _with_frost(Color.WHITE, cell, terrain)
	if terrain == "cliff":
		return _with_frost(tint.lerp(Color(0.90, 0.88, 0.84), 0.45), cell, terrain)
	if terrain == "water":
		return _water_grade_tint(cell)
	if _faces_water(cell) and _weight(weights, "eastmarch") > 0.18:
		tint = tint.lerp(Color(1.0, 0.86, 0.58), 0.72)
	elif _faces_water(cell) and _weight(weights, "southbridge") > 0.22:
		tint = tint.lerp(Color(0.62, 0.58, 0.40), 0.55)
	return _with_frost(tint, cell, terrain)


## Soft white-blue on every snowy land tile, roads included, so frost is not a grid.
func _with_frost(tint: Color, cell: Vector2i, terrain: String) -> Color:
	var amount := snow_at_cell(cell)
	if amount <= 0.2 or terrain == "water":
		return tint
	# Town snow is painted on top here; a frost tint under it drew a grid.
	if cover_at(cell) > 0.0:
		return tint
	var mix := 0.62 * amount
	if terrain == "dirt_road":
		mix = 0.5 * amount
	elif terrain == "cliff":
		mix = 0.4 * amount
	return tint.lerp(Color(0.82, 0.90, 0.97), mix)


func _faces_water(cell: Vector2i) -> bool:
	for dir in _ORTHO:
		if Art.terrain_seen(zone, cell + dir) == "water":
			return true
	return false


## Sparse fog, blight haze, cracked earth, and cliff cave mouths.
## These sit on the painted tiles. They are not a full-cell wash.
func _theme_marks(ci: Node2D, cell: Vector2i, terrain: String, steps: int) -> void:
	if zone == null or terrain == "dirt_road":
		return
	var weights := theme_weights(cell)
	var n := _hash(cell)
	var c := BoardVisualSort.cell_to_local(cell, float(steps))
	var south := _weight(weights, "southbridge")
	var west := _weight(weights, "westwatch")
	var east := _weight(weights, "eastmarch")
	var north := _weight(weights, "northgate")
	if terrain != "water" and terrain != "cliff" and south > 0.42 and n > 0.93:
		_soft_blob(ci, c + Vector2(-4, 2), 18.0, 7.0, Color(0.78, 0.84, 0.72, 0.10), n)
	if terrain != "water" and west > 0.4 and n > 0.94:
		_soft_blob(ci, c, 20.0, 8.0, Color(0.52, 0.46, 0.64, 0.09), n + 1.3)
	if terrain != "water" and terrain != "cliff" and west > 0.28 and n > 0.55:
		var crack := Color(0.28, 0.22, 0.32, 0.5)
		ci.draw_line(c + Vector2(-8, 2), c + Vector2(-1, -2), crack, 1.0)
		ci.draw_line(c + Vector2(-1, -2), c + Vector2(6, 3), crack, 1.0)
	if terrain == "cliff" and _cave_id(cell) == "" and _faces_water(cell) and n > 0.8 and snow_shore_at(cell) < 0.5 and (east > 0.12 or north > 0.2 or south > 0.15):
		var d := Pick.diamond(cell, float(steps))
		var mid := (d[0] + d[2]) * 0.5
		_soft_blob(ci, mid + Vector2(0, 3), 7.5, 4.5, Color(0.10, 0.09, 0.08, 0.88), n)


func _soft_blob(ci: Node2D, at: Vector2, rx: float, ry: float, tint: Color, salt: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		var wobble := 0.75 + 0.25 * absf(sin(a * 2.0 + salt * 4.0))
		pts.append(at + Vector2(cos(a) * rx * wobble, sin(a) * ry * wobble))
	ci.draw_colored_polygon(pts, tint)


func _dust_snow(ci: Node2D, cell: Vector2i, terrain: String, steps: int) -> void:
	var amount := snow_at_cell(cell)
	if amount <= 0.2:
		return
	var diamond := Pick.diamond(cell, float(steps))
	if terrain == "water":
		# Sea stays the one map blue. A wash per diamond also drew the grid.
		if _water_grade(cell) == "sea":
			return
		ci.draw_colored_polygon(diamond, Color(0.62, 0.78, 0.90, 0.22 * amount))
		return
	if terrain != "cliff" or not _north_crag(cell):
		return
	# A lip where the terrace drops. Grass frost is the tint, not a disc per cell.
	var lip := Color(0.97, 0.98, 1.0, 0.7 * amount)
	var south := cell + Vector2i(0, 1)
	var east := cell + Vector2i(1, 0)
	if _terrace(cell) > _terrace(south):
		ci.draw_line(diamond[2], diamond[3], lip, 2.2)
	if _terrace(cell) > _terrace(east):
		ci.draw_line(diamond[1], diamond[2], lip, 2.2)


func _draw_ripple(ci: Node2D, anim_id: String, south_tip: Vector2, modulate: Color = Color.WHITE, overlap: float = 0.0) -> bool:
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
	var dest := Rect2(south_tip + Vector2(-fw * 0.5, -fh), Vector2(fw, fh))
	if overlap > 0.0 and fw > 8.0 and fh > 8.0:
		region = Rect2(region.position + Vector2(3, 3), region.size - Vector2(6, 6))
		dest = Rect2(dest.position - Vector2(overlap, overlap), dest.size + Vector2(overlap * 2.0, overlap * 2.0))
	ci.draw_texture_rect_region(tex, dest, region, modulate)
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
