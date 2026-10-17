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
	# The wall line crosses the passage at the arch: find the wall cells
	# around it, so the gatehouse spans the ring there.
	return {
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
	return tile_city != null and tile_city.passable(c)


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
		return bridge_deck_y()
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
