extends RefCounted

## City layout data in, a 3D build plan out. Pure: no nodes, no rendering.
##
## The plan is what the 3D builder (city_builder.gd), the walk grid
## (nav_grid.gd) and city life (city_life3d.gd) all read, so every layer
## agrees on where things are. Grid cell (x, y) maps to world metres
## (x * cell_m, ground, y * cell_m): grid +x is world +X, grid +y is world +Z.
## The painted 2D view looked from grid south-east, so the 3D camera starts
## from world +X+Z looking back the same way.
##
## Sources: "tile_city" (Crosshaven's approved modular layout, tilemap.json,
## which city_plan.py builds from streetplan.json). The builder is generic:
## another source only has to fill the same plan fields.

const SCALE_PATH := "res://data/world/city3d/scale_table.json"

var ok := false
var errors: Array = []
var city: Dictionary = {}        ## the stasium.city3d sidecar
var scale: Dictionary = {}       ## kind -> scale entry
var cell_m := 2.0
var width := 0
var height := 0
var rows: Array = []             ## terrain chars per row
var pieces: Array = []           ## {kind, spec, cells:[Vector2i], anchor, flip, center(Vector2 m), size(Vector2 m), name, tier, door}
var wall_cells: Dictionary = {}  ## Vector2i -> true
var walk_over: Dictionary = {}   ## bridge decks over water
var gates: Array = []            ## {id, cells, center, dir(Vector2 inside), width}
var tunnels: Array = []          ## water tunnels through the ring
var npcs: Array = []             ## {id, name, role, cell, facing, night}
var spawn := Vector2i.ZERO
var spawn_facing := Vector2(0, -1)
var tile_city = null             ## TileCity, for passable()
var ring: Array = []             ## closed polyline (Vector2 m) along the middle of the ring wall
var ring_center := Vector2.ZERO
var bridges: Array = []          ## {cells, center, axis(Vector2), length, width}
var _bridge_of: Dictionary = {}  ## cell -> bridge index
var solid_extra: Dictionary = {} ## cells blocked by 3D pieces (gatehouse pillars)


static func load_city(path: String):
	var p = load("res://slice3d/city/city_plan.gd").new()
	p._load(path)
	return p


func _load(path: String) -> void:
	city = _json(path)
	if city.is_empty():
		errors.append("city file %s" % path)
		return
	var sc := _json(SCALE_PATH)
	scale = sc.get("kinds", {})
	cell_m = float(city.get("cell_m", 2.0))
	var src: Dictionary = city.get("source", {})
	match str(src.get("kind", "")):
		"tile_city":
			_from_tile_city(src)
		_:
			errors.append("unknown source kind %s" % src.get("kind", ""))
	ok = errors.is_empty()


# ---------------------------------------------------------------- tile city

func _from_tile_city(src: Dictionary) -> void:
	tile_city = TileCity.load_path(str(src["tilemap"]))
	if not tile_city.ok():
		errors.append_array(tile_city.errors)
		return
	var doc: Dictionary = tile_city.doc
	width = tile_city.width
	height = tile_city.height
	rows = doc["grid"]["rows"]
	for c in doc.get("wall_cells", []):
		wall_cells[Vector2i(int(c[0]), int(c[1]))] = true
	for c in doc.get("walk_over", []):
		walk_over[Vector2i(int(c[0]), int(c[1]))] = true
	for p in tile_city.pieces():
		var kind := str(p["kind"])
		if not (tile_city.kit["pieces"] as Dictionary).has(kind):
			continue
		var cells: Array = tile_city.footprint(p)
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for c in cells:
			lo.x = minf(lo.x, c.x)
			lo.y = minf(lo.y, c.y)
			hi.x = maxf(hi.x, c.x + 1)
			hi.y = maxf(hi.y, c.y + 1)
		var rec := {
			"kind": kind,
			"group": TileCity.kind_group(kind),
			"spec": scale_for(kind),
			"cells": cells,
			"anchor": Vector2i(int(p["cell"][0]), int(p["cell"][1])),
			"flip": bool(p.get("flip", false)),
			"center": (lo + hi) * 0.5 * cell_m,
			"size": (hi - lo) * cell_m,
			"name": str(p.get("name", "")),
			"tier": str(p.get("tier", "")),
			"plot": str(p.get("plot", "")),
			"solid": tile_city.piece_blocks(p),
		}
		if p.has("door_cell"):
			rec["door"] = Vector2i(int(p["door_cell"][0]), int(p["door_cell"][1]))
		if kind.begins_with("tunnel"):
			tunnels.append(rec)
		pieces.append(rec)
	for g in doc.get("gates", []):
		gates.append(_gate_from(g))
	var gate_id := str(city.get("spawn_gate", ""))
	spawn = tile_city.spawn()
	for g in gates:
		if g["id"] == gate_id:
			# Just inside the gate, facing into town.
			spawn_facing = g["dir"]
			var deep: Vector2 = g["inside"] + g["dir"] * cell_m * 5.0
			spawn = nearest_passable(world_to_cell(deep), 6)
	_load_npcs(str(src.get("city", "")))
	_trace_ring()
	_find_bridges()
	_gate_solids()


func _gate_from(g: Dictionary) -> Dictionary:
	var cells: Array = []
	var sum := Vector2.ZERO
	for c in g["cells"]:
		var v := Vector2i(int(c[0]), int(c[1]))
		cells.append(v)
		sum += Vector2(v) + Vector2(0.5, 0.5)
	var inside := _mean(g.get("inside", []))
	var outside := _mean(g.get("outside", []))
	var dir := (inside - outside).normalized() if inside != outside else Vector2(0, -1)
	var arch := Vector2(float(g["arch_cell"][0]), float(g["arch_cell"][1])) + Vector2(0.5, 0.5)
	var ins: Array = g.get("inside", [])
	var inside_cell := Vector2i(int(ins[ins.size() / 2][0]), int(ins[ins.size() / 2][1])) if not ins.is_empty() else Vector2i(arch)
	# Passage centre and width: the gate cells close to the arch line.
	var perp := Vector2(-dir.y, dir.x)
	var lo := 1e9
	var hi := -1e9
	for c in cells:
		var q: Vector2 = (Vector2(c) + Vector2(0.5, 0.5) - arch) * cell_m
		if absf(q.dot(dir)) < cell_m * 1.6:
			lo = minf(lo, q.dot(perp))
			hi = maxf(hi, q.dot(perp))
	if lo > hi:
		lo = 0.0
		hi = 0.0
	var mid := arch * cell_m + perp * (lo + hi) * 0.5
	return {
		"mid": mid,
		"perp": perp,
		"passage_m": hi - lo + cell_m,
		"id": str(g["id"]),
		"cells": cells,
		"arch": arch * cell_m,
		"center": (sum / maxf(1.0, cells.size())) * cell_m,
		"inside": inside * cell_m,
		"outside": outside * cell_m,
		"inside_cell": inside_cell,
		"dir": dir,
	}


func _mean(list: Array) -> Vector2:
	if list.is_empty():
		return Vector2.ZERO
	var s := Vector2.ZERO
	for c in list:
		s += Vector2(float(c[0]), float(c[1])) + Vector2(0.5, 0.5)
	return s / list.size()


## city.json NPCs sit on the old plate cell grid (32 x 16 px iso cells). Same
## world px frame as the tile map, so: old cell -> world px -> tile cell.
func _load_npcs(path: String) -> void:
	var doc := _json(path)
	for n in doc.get("npcs", []):
		var oc := Vector2(float(n["cell"]["x"]), float(n["cell"]["y"]))
		var wpx := Vector2((oc.x - oc.y) * 32.0, (oc.x + oc.y) * 16.0)
		var c: Vector2i = tile_city.world_to_cell(wpx)
		c = nearest_passable(c, 10)
		npcs.append({"id": str(n["id"]), "name": str(n.get("name", "")), "role": str(n.get("role", "")),
			"cell": c, "facing": str(n.get("facing", "S")), "night": str(n.get("night", ""))})


# ---------------------------------------------------------------- ring and bridges

## The ring's centre line: wall cells binned by angle round the ring's centre
## (one point per bin = the mean of its cells), then simplified to straight
## runs (Douglas-Peucker). Bins with no wall (gates, the river) are bridged
## by the line; the builder puts gatehouses and tunnels there.
func _trace_ring(bins := 360, tolerance := 2.5) -> void:
	if wall_cells.is_empty():
		return
	var sum := Vector2.ZERO
	for c in wall_cells.keys():
		sum += cell_center(c)
	ring_center = sum / wall_cells.size()
	var acc: Array = []
	for i in bins:
		acc.append([Vector2.ZERO, 0])
	for c in wall_cells.keys():
		var p := cell_center(c)
		var a := fposmod((p - ring_center).angle(), TAU)
		var b := int(a / TAU * bins) % bins
		acc[b][0] += p
		acc[b][1] += 1
	var pts: Array = []
	for i in bins:
		if acc[i][1] > 0:
			pts.append(acc[i][0] / float(acc[i][1]))
	if pts.size() < 3:
		return
	# Douglas-Peucker on the closed loop: split at the two farthest points.
	var far_i := 0
	var far_d := 0.0
	for i in pts.size():
		var d: float = (pts[i] as Vector2).distance_to(pts[0])
		if d > far_d:
			far_d = d
			far_i = i
	var a_half := _dp(pts.slice(0, far_i + 1), tolerance)
	var b_half := _dp(pts.slice(far_i) + [pts[0]], tolerance)
	ring = a_half.slice(0, a_half.size() - 1) + b_half.slice(0, b_half.size() - 1)


static func _dp(pts: Array, tol: float) -> Array:
	if pts.size() < 3:
		return pts
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var best := -1
	var best_d := 0.0
	for i in range(1, pts.size() - 1):
		var d := _seg_dist(pts[i], a, b)
		if d > best_d:
			best_d = d
			best = i
	if best_d <= tol:
		return [a, b]
	var left := _dp(pts.slice(0, best + 1), tol)
	var right := _dp(pts.slice(best), tol)
	return left.slice(0, left.size() - 1) + right


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Bridge decks: connected walk_over cells; the long axis (principal
## direction) runs across the river.
func _find_bridges() -> void:
	var seen := {}
	for start in walk_over.keys():
		if seen.has(start):
			continue
		var cells: Array = []
		var q: Array = [start]
		seen[start] = true
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			cells.append(c)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n: Vector2i = c + Vector2i(dx, dy)
					if walk_over.has(n) and not seen.has(n):
						seen[n] = true
						q.append(n)
		var mean := Vector2.ZERO
		for c in cells:
			mean += cell_center(c)
		mean /= cells.size()
		var sxx := 0.0
		var syy := 0.0
		var sxy := 0.0
		for c in cells:
			var d := cell_center(c) - mean
			sxx += d.x * d.x
			syy += d.y * d.y
			sxy += d.x * d.y
		var ang := 0.5 * atan2(2.0 * sxy, sxx - syy)
		var axis := Vector2(cos(ang), sin(ang))
		var lo := 1e9
		var hi := -1e9
		var wl := 1e9
		var wh := -1e9
		for c in cells:
			var d := cell_center(c) - mean
			lo = minf(lo, d.dot(axis))
			hi = maxf(hi, d.dot(axis))
			wl = minf(wl, d.dot(axis.orthogonal()))
			wh = maxf(wh, d.dot(axis.orthogonal()))
		var idx := bridges.size()
		for c in cells:
			_bridge_of[c] = idx
		bridges.append({"cells": cells, "center": mean + axis * (lo + hi) * 0.5 + axis.orthogonal() * (wl + wh) * 0.5,
			"axis": axis, "length": hi - lo + cell_m, "width": wh - wl + cell_m})


## With a gatehouse model, its pillars block the cells they stand on; the
## passage between them stays walkable (Grok's collider: 2 pillars + lintel).
func _gate_solids() -> void:
	var gk: Dictionary = city.get("kit", {}).get("gatehouse", {})
	if gk.is_empty() or not FileAccess.file_exists(str(gk.get("glb", ""))):
		return
	var s := float(gk.get("scale", 1.0))
	var half_w := float(gk.get("width", 7.75)) * s * 0.5
	var half_d := float(gk.get("depth", 5.0)) * s * 0.5
	var half_p := float(gk.get("passage", 2.82)) * s * 0.5
	for g in gates:
		var mid: Vector2 = g["mid"]
		var dir: Vector2 = g["dir"]
		var perp: Vector2 = g["perp"]
		var r := int(ceil(maxf(half_w, half_d) / cell_m)) + 1
		var c0 := world_to_cell(mid)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := c0 + Vector2i(dx, dy)
				var q := cell_center(c) - mid
				var across := absf(q.dot(perp))
				if across <= half_w and absf(q.dot(dir)) <= half_d and across > half_p:
					solid_extra[c] = true


## Deck height on a bridge: an arch, highest mid-span (data: kit.bridge.deck_peak).
func bridge_y(p: Vector2, c: Vector2i) -> float:
	var b: Dictionary = bridges[_bridge_of[c]]
	var peak := float(city.get("kit", {}).get("bridge", {}).get("deck_peak", 0.0))
	if peak <= 0.0:
		return bridge_deck_y()
	var t: float = (p - b["center"]).dot(b["axis"]) / maxf(1.0, float(b["length"]) * 0.5 + cell_m)
	return bridge_deck_y() + peak * maxf(0.0, 1.0 - t * t)


# ---------------------------------------------------------------- queries

func scale_for(kind: String) -> Dictionary:
	if scale.has(kind):
		return scale[kind]
	var best := ""
	for k in scale.keys():
		if kind.begins_with(str(k)) and str(k).length() > best.length():
			best = str(k)
	if best == "":
		var g := TileCity.kind_group(kind)
		if scale.has(g):
			return scale[g]
		return {}
	return scale[best]


func terrain_char(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return "."
	return str(rows[c.y])[c.x]


func is_water(c: Vector2i) -> bool:
	return terrain_char(c) == "w" and not walk_over.has(c)


func passable(c: Vector2i) -> bool:
	return tile_city != null and tile_city.passable(c) and not solid_extra.has(c)


func nearest_passable(c: Vector2i, r_max: int = 8) -> Vector2i:
	if passable(c):
		return c
	for r in range(1, r_max + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and passable(c + Vector2i(dx, dy)):
					return c + Vector2i(dx, dy)
	return c


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * cell_m


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell_m), floori(p.y / cell_m))


## Ground height (metres) at a world point: 0 on land, down on water, the
## deck on bridges. Smooth enough for walking and for the click ray.
func ground_y(p: Vector2) -> float:
	var c := world_to_cell(p)
	if walk_over.has(c):
		return bridge_y(p, c) if _bridge_of.has(c) else bridge_deck_y()
	if is_water(c):
		return float(city.get("water", {}).get("bed", -1.6))
	return 0.0


func bridge_deck_y() -> float:
	return 0.35


func size_m() -> Vector2:
	return Vector2(width, height) * cell_m


func pieces_of(group: String) -> Array:
	var out: Array = []
	for p in pieces:
		if p["group"] == group or str(p["kind"]).begins_with(group):
			out.append(p)
	return out


static func _json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_DICTIONARY else {}
