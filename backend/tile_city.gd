class_name TileCity
extends RefCounted

## Modular (Wakfu-like) city data: an iso 2:1 tile map, corner-Wang ground
## autotiling and a piece list (walls, towers, gates, buildings, props), read
## from data/world/<zone>/tilemap.json plus the tile kit's kit.json.
## Pure data: the view (scenes/world/crosshaven/tile_city_view.gd) draws it.
##
## Tile (x, y) centre in world px = origin + ((x - y) * tw / 2, (x + y) * th / 2).
## Ground tiles sit on cell corners (dual grid): the corner tile at vertex
## (x, y) covers the cells N (x-1, y-1), E (x, y-1), S (x, y), W (x-1, y).

const FORMAT := "stasium.tile_city"
const DEFAULT_PATH := "res://data/world/crosshaven_city/tilemap.json"

var doc: Dictionary = {}
var kit: Dictionary = {}
var kit_dir := ""
var width := 0
var height := 0
var tile := Vector2(51.4, 25.7)
var origin := Vector2.ZERO
var errors: Array = []
## terrain char -> priority (kit order)
var _prio := {}
var _terrain_of_char := {}
var _blocked := {}
var _walk_over := {}
var _piece_at := {}


static func load_path(path: String = DEFAULT_PATH) -> TileCity:
	var tc := TileCity.new()
	tc._load(path)
	return tc


func ok() -> bool:
	return errors.is_empty()


func _load(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("tilemap does not parse: %s" % path)
		return
	doc = parsed
	if str(doc.get("format", "")) != FORMAT:
		errors.append("format must be %s" % FORMAT)
		return
	var kpath := "res://" + str(doc["kit"])
	var kp: Variant = JSON.parse_string(FileAccess.get_file_as_string(kpath))
	if typeof(kp) != TYPE_DICTIONARY:
		errors.append("kit does not parse: %s" % kpath)
		return
	kit = kp
	kit_dir = kpath.get_base_dir()
	var g: Dictionary = doc["grid"]
	width = int(g["width"])
	height = int(g["height"])
	var rows: Array = g["rows"]
	if rows.size() != height:
		errors.append("grid rows must match the height")
		return
	for r in rows:
		if str(r).length() != width:
			errors.append("grid row length must match the width")
			return
	tile = Vector2(float(doc["tile_world_px"][0]), float(doc["tile_world_px"][1]))
	origin = Vector2(float(doc["origin_world"][0]), float(doc["origin_world"][1]))
	var ids: Dictionary = doc["terrain_ids"]
	for t in kit["terrains"]:
		for ch in ids.keys():
			if str(ids[ch]) == str(t["id"]):
				_prio[str(ch)] = int(t["priority"])
				_terrain_of_char[str(ch)] = t
	for ch in ids.keys():
		if not _prio.has(str(ch)):
			errors.append("kit has no terrain %s" % ids[ch])
	for c in doc.get("walk_over", []):
		_walk_over[Vector2i(int(c[0]), int(c[1]))] = true
	# round 26: the ring blocks by its wall band (the ring pieces are art only)
	for c in doc.get("wall_cells", []):
		_blocked[Vector2i(int(c[0]), int(c[1]))] = -1
	var i := 0
	for p in doc["pieces"]:
		var kind := str(p["kind"])
		if not (kit["pieces"] as Dictionary).has(kind):
			errors.append("kit has no piece %s" % kind)
			i += 1
			continue
		for c in footprint(p):
			if piece_blocks(p):
				_blocked[c] = i
			_piece_at[c] = i
		i += 1


## ---- grid

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func terrain_char(c: Vector2i) -> String:
	if not in_bounds(c):
		return "."
	return str(doc["grid"]["rows"][c.y])[c.x]


func terrain_id(c: Vector2i) -> String:
	var ch := terrain_char(c)
	return str(doc["terrain_ids"].get(ch, "void"))


func cell_to_world(c: Vector2) -> Vector2:
	return origin + Vector2((c.x - c.y) * tile.x * 0.5, (c.x + c.y) * tile.y * 0.5)


func world_to_cell_f(w: Vector2) -> Vector2:
	var a := (w.x - origin.x) / (tile.x * 0.5)
	var b := (w.y - origin.y) / (tile.y * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


func world_to_cell(w: Vector2) -> Vector2i:
	var f := world_to_cell_f(w)
	return Vector2i(int(round(f.x)), int(round(f.y)))


## World px per kit px (the kit is painted at its hero_px).
func kit_scale() -> float:
	return tile.x / float(kit["tile_px"][0])


## ---- autotiling

## Ground layers at vertex (x, y): [[terrain dict, mask 0..15], ...] in draw
## order. The lowest terrain present fills the whole tile (mask 15); every
## higher one sets the bits of the quarters whose cell is that terrain or above.
func corner_layers(v: Vector2i) -> Array:
	var quarters := [Vector2i(v.x - 1, v.y - 1), Vector2i(v.x, v.y - 1), v, Vector2i(v.x - 1, v.y)]
	var bits := [1, 2, 4, 8]
	var pr: Array = []
	var lowest := 1 << 20
	for q in quarters:
		var ch := terrain_char(q)
		var p := int(_prio.get(ch, -1))
		pr.append(p)
		if p >= 0:
			lowest = mini(lowest, p)
	var out: Array = []
	if lowest == 1 << 20:
		return out
	var seen := {}
	for p in pr:
		if p >= 0:
			seen[p] = true
	var levels: Array = seen.keys()
	levels.sort()
	for lv in levels:
		var mask := 0
		for i in 4:
			if int(pr[i]) >= int(lv):
				mask |= bits[i]
		if int(lv) == lowest:
			mask = 15
		out.append([_terrain_by_prio(int(lv)), mask])
	return out


func _terrain_by_prio(p: int) -> Dictionary:
	for t in kit["terrains"]:
		if int(t["priority"]) == p:
			return t
	return {}


## ---- pieces

func pieces() -> Array:
	return doc["pieces"]


## "gate_h" -> "gate", "wall_diag_se" -> "wall", "tunnel_h" -> "tunnel".
static func kind_group(kind: String) -> String:
	if kind.begins_with("house_npc"):
		return "house"
	for g in ["gate", "wall", "tunnel", "workshop", "stall", "lamp", "bench", "fence", "crate", "barrel"]:
		if kind == g or kind.begins_with(g + "_"):
			return g
	return kind


func piece_spec(p: Dictionary) -> Dictionary:
	return kit["pieces"][str(p["kind"])]


func piece_blocks(p: Dictionary) -> bool:
	if p.has("solid"):
		return bool(p["solid"])
	if bool(p.get("tunnel", false)):
		return true
	return bool(piece_spec(p)["blocks"])


func footprint(p: Dictionary) -> Array[Vector2i]:
	var fp: Array = piece_spec(p)["footprint"]
	var fw := int(fp[0])
	var fh := int(fp[1])
	if bool(p.get("flip", false)):
		# mirrored art: the footprint mirrors too
		var t := fw
		fw = fh
		fh = t
	var a := Vector2i(int(p["cell"][0]), int(p["cell"][1]))
	var out: Array[Vector2i] = []
	for i in fw:
		for j in fh:
			out.append(a - Vector2i(i, j))
	return out


## World px of the piece's foot: the south corner of its anchor cell.
func piece_foot(p: Dictionary) -> Vector2:
	if p.has("world_foot"):
		return Vector2(float(p["world_foot"][0]), float(p["world_foot"][1]))
	var a := Vector2(float(p["cell"][0]), float(p["cell"][1]))
	return cell_to_world(a) + Vector2(0, tile.y * 0.5)


func piece_index_at(c: Vector2i) -> int:
	return int(_piece_at.get(c, -1))


## ---- walking

func is_wall(c: Vector2i) -> bool:
	return int(_blocked.get(c, 0)) == -1 and _blocked.has(c)


func passable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var ch := terrain_char(c)
	if ch == ".":
		return false
	if _blocked.has(c):
		return false
	if _walk_over.has(c):
		return true
	if ch == "w" and not _walk_over.has(c):
		return false
	return true


## Breadth-first reach over 4-connected passable tiles; `shut` tiles count as
## blocked (e.g. a gate's passage while its doors are shut).
func reach(from: Vector2i, shut: Dictionary = {}) -> Dictionary:
	var seen := {from: true}
	if not passable(from):
		return seen
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and passable(n) and not shut.has(n):
				seen[n] = true
				q.append(n)
	return seen


func gate_cells(id: String = "") -> Dictionary:
	var out := {}
	for g in doc.get("gates", []):
		if id != "" and str(g["id"]) != id:
			continue
		for c in g["cells"]:
			out[Vector2i(int(c[0]), int(c[1]))] = true
	return out


func spawn() -> Vector2i:
	return Vector2i(int(doc["spawn"][0]), int(doc["spawn"][1]))
