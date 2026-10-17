extends RefCounted

## Plate-backed city zones (format stasium.plate_city v1). Preload. No global class.
## A plate city is one painted image with y-sorted sprite layers (the Rosebud
## export). Its walk data is a cell grid stored as text rows; this loader turns
## it into an ordinary WorldZone inside its own one-zone WorldMap, so the
## walker, WorldWalk and picking work as on any chunk. It is not in the world
## atlas or the Crosshaven plane: the gate stubs in the file reach it.
## See docs/pc/CROSSHAVEN_CITY_BUILD.md.

const FORMAT := "stasium.plate_city"
const FORMAT_VERSION := 1
const DEFAULT_PATH := "res://data/world/crosshaven_city/city.json"
const CITY_ID := "crosshaven_city"
const KEYS: Array[String] = [
	"format", "format_version", "zone_id", "region", "name", "status", "source", "plate",
	"grid", "spawn", "exit_cell", "gate_cells", "bridges", "plots", "plot_rules", "pets",
	"npcs", "day_hours", "gate_stubs", "layers", "gates", "wall_contacts", "towers_cleaned", "wall_polygon", "water", "trees_keep", "plants", "map_base_only", "building_footprints", "thatch_swapped", "wall_ring", "lights", "water_gates", "gate_clear", "wall_runs", "tower_body_radius_px", "gates_snapped", "tower_spacing", "stone_chroma", "join_audit", "tower_plinths", "tower_base_radius_px", "block_below_tower_px",
]
const TIERS: Array[String] = ["normal", "rare", "legendary"]
## Grid row symbol -> [terrain, walkable].
const SYMBOLS := {
	".": ["cliff", false],
	"#": ["cliff", false],
	"~": ["water", false],
	"g": ["golden_plains", true],
	"r": ["dirt_road", true],
}

var doc: Dictionary = {}
var zone: WorldZone
var map: WorldMap
var path := ""
var _layers: Array = []


static var _cache: Dictionary = {}


## Cached per path: the world, its tests and the gate check share one parse.
static func load_default() -> Dictionary:
	return load_path(DEFAULT_PATH)


static func load_path(file_path: String) -> Dictionary:
	if _cache.has(file_path):
		return _cache[file_path]
	var out := _load(file_path)
	if bool(out.get("ok", false)):
		_cache[file_path] = out
	return out


static func clear_cache() -> void:
	_cache.clear()


static func _load(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return _fail("missing", ["missing %s" % file_path])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("invalid", ["%s is not a JSON object" % file_path])
	var city = new()
	city.path = file_path
	var errors: Array = city._read(parsed)
	if not errors.is_empty():
		return _fail("invalid", errors)
	return {"ok": true, "reason": "", "errors": [], "city": city}


func zone_id() -> String:
	return str(doc.get("zone_id", ""))


func art_path(file: String) -> String:
	var plate: Dictionary = doc.get("plate", {})
	return str(plate.get("art_root", "")) + file


## Plate pixel of the cell (0, 0) centre. The plate node sits at minus this.
func cell00() -> Vector2:
	var c: Array = (doc["plate"] as Dictionary)["cell00_px"]
	return Vector2(float(c[0]), float(c[1]))


func plate_size() -> Vector2:
	var s: Array = (doc["plate"] as Dictionary)["size"]
	return Vector2(float(s[0]), float(s[1]))


## World px per plate px (data: plate.scale). The cell grid was derived at it.
func scale() -> float:
	return float((doc["plate"] as Dictionary).get("scale", 1.0))


## World-pixel rect of the whole plate (zone-local, plane origin 0).
func world_rect() -> Rect2:
	return Rect2(-cell00() * scale(), plate_size() * scale())


func plate_to_world(p: Vector2) -> Vector2:
	return (p - cell00()) * scale()


func world_to_plate(p: Vector2) -> Vector2:
	return p / scale() + cell00()


func spawn() -> Vector2i:
	return _cell(doc["spawn"])


func exit_cell() -> Vector2i:
	return _cell(doc["exit_cell"])


func plots() -> Array:
	return doc.get("plots", [])


func npcs() -> Array:
	return doc.get("npcs", [])


func pets() -> Array:
	return doc.get("pets", [])


func bridges() -> Array:
	return doc.get("bridges", [])


## Every gatehouse (south gate first) with its passage polygon and walk cells.
func gates() -> Array:
	return doc.get("gates", [])


func gate_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in doc.get("gate_cells", []):
		out.append(_cell(c))
	return out


## Day runs from day_hours[0] to day_hours[1] (weather time_of_day hours).
func is_day(hour: float) -> bool:
	var span: Array = doc.get("day_hours", [6.0, 20.0])
	return hour >= float(span[0]) and hour < float(span[1])


func house_art(tier: String) -> String:
	var rules: Dictionary = doc.get("plot_rules", {})
	var art: Dictionary = rules.get("tier_art", {})
	return art_path(str(art.get(tier, "")))


func house_size(tier: String) -> Vector2:
	var rules: Dictionary = doc.get("plot_rules", {})
	var info: Dictionary = (rules.get("house_art", {}) as Dictionary).get(tier, {})
	return Vector2(float(info.get("w", 0)), float(info.get("h", 0)))


func house_mask(tier: String) -> Dictionary:
	var rules: Dictionary = doc.get("plot_rules", {})
	var info: Dictionary = (rules.get("house_art", {}) as Dictionary).get(tier, {})
	return info.get("mask", {})


func clearance_px(tier: String) -> float:
	var rules: Dictionary = doc.get("plot_rules", {})
	return float((rules.get("clearance_px", {}) as Dictionary).get(tier, 0))


## Item 17: the map base is shown without buildings (data: map_base_only).
func plot_houses_hidden() -> bool:
	return bool((doc.get("map_base_only", {}) as Dictionary).get("hide_plot_houses", false))


## Enabled gate stubs leaving `from_zone`.
func stubs_from(from_zone: String) -> Array:
	var out: Array = []
	for stub in doc.get("gate_stubs", []):
		if not bool(stub.get("enabled", false)):
			continue
		if str((stub["from"] as Dictionary).get("zone_id", "")) == from_zone:
			out.append(stub)
	return out


## The enabled stub whose from cell is `cell` in `from_zone`, or {}.
func stub_at(from_zone: String, cell: Vector2i) -> Dictionary:
	for stub in stubs_from(from_zone):
		if _cell(stub["from"]) == cell:
			return stub
	return {}


## Sprite layers, loaded on first use (393 rows with masks).
func layers() -> Array:
	if not _layers.is_empty():
		return _layers
	var file := path.get_base_dir().path_join(str(doc.get("layers", "layers.json")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if typeof(parsed) == TYPE_DICTIONARY:
		_layers = (parsed as Dictionary).get("layers", [])
	return _layers


## Unpacked fade mask: {step, w, h, bits: PackedByteArray of w*h 0/1}.
static func unpack_mask(mask: Dictionary) -> Dictionary:
	if mask.is_empty():
		return {}
	var w := int(mask["w"])
	var h := int(mask["h"])
	var raw := Marshalls.base64_to_raw(str(mask["bits"]))
	var bits := PackedByteArray()
	bits.resize(w * h)
	for i in w * h:
		var byte := raw[i >> 3] if (i >> 3) < raw.size() else 0
		bits[i] = (byte >> (7 - (i & 7))) & 1
	return {"step": int(mask["step"]), "w": w, "h": h, "bits": bits}


## Fade z of a plate y (sort line): the walker's own formula without its bias.
static func z_for_world_y(world_y: float) -> int:
	return int(round(world_y * float(BoardVisualSort.TILE_Z_SCALE) / 16.0))


func _read(d: Dictionary) -> Array:
	var errors: Array = []
	for key in d.keys():
		if not KEYS.has(str(key)):
			errors.append("unknown key %s" % str(key))
	if str(d.get("format", "")) != FORMAT:
		errors.append("format must be %s" % FORMAT)
	if int(d.get("format_version", -1)) != FORMAT_VERSION:
		errors.append("format_version must be %d" % FORMAT_VERSION)
	var grid: Variant = d.get("grid", null)
	if typeof(grid) != TYPE_DICTIONARY:
		errors.append("grid must be an object")
		return errors
	var w := int((grid as Dictionary).get("width", 0))
	var h := int((grid as Dictionary).get("height", 0))
	var rows: Array = (grid as Dictionary).get("rows", [])
	if w <= 0 or h <= 0 or rows.size() != h:
		errors.append("grid rows must match width and height")
		return errors
	for y in h:
		var row := str(rows[y])
		if row.length() != w:
			errors.append("grid row %d has %d cells, expected %d" % [y, row.length(), w])
			return errors
	for p in d.get("plots", []):
		if not TIERS.has(str(p.get("tier", ""))):
			errors.append("plot %s tier must be normal, rare or legendary" % str(p.get("id", "")))
	if typeof(d.get("plate", null)) != TYPE_DICTIONARY:
		errors.append("plate must be an object")
	if not errors.is_empty():
		return errors
	doc = d
	zone = _build_zone(d, w, h, rows)
	if not zone.passable_at(spawn()):
		errors.append("spawn is not walkable")
	if not zone.passable_at(exit_cell()):
		errors.append("exit cell is not walkable")
	map = WorldMap.new()
	map.region = str(d.get("region", CITY_ID))
	map.start_zone = zone.zone_id
	map.start_cell = zone.spawn
	map.max_climb_steps = -1
	map.adjacency = "ortho"
	map.zones[zone.zone_id] = zone
	return errors


func _build_zone(d: Dictionary, w: int, h: int, rows: Array) -> WorldZone:
	var tiles: Array = []
	tiles.resize(w * h)
	var heights := {}
	for rec in (d["grid"] as Dictionary).get("heights", []):
		heights[Vector2i(int(rec[0]), int(rec[1]))] = int(rec[2])
	for y in h:
		var row := str(rows[y])
		for x in w:
			var sym: Array = SYMBOLS.get(row[x], SYMBOLS["#"])
			tiles[y * w + x] = {
				"x": x, "y": y, "terrain": str(sym[0]), "walkable": bool(sym[1]),
				"height": int(heights.get(Vector2i(x, y), 0)),
			}
	var spawn_cell := _cell(d["spawn"])
	var z := WorldZone.new()
	# The grid rows are checked above, so they are applied directly instead of
	# through WorldZone.parse (one JSON record per tile). Kind "landmark": the
	# critter pass adds a chicken to "town" chunks, and the city has no farm animals.
	z._apply({
		"zone_id": str(d.get("zone_id", CITY_ID)),
		"region": str(d.get("region", CITY_ID)),
		"width": w,
		"height": h,
		"spawn": {"x": spawn_cell.x, "y": spawn_cell.y},
		"tiles": tiles,
		"props": [],
		"decor": [],
		"exits": [],
		"points_of_interest": [{"id": "crosshaven_city", "name": str(d.get("name", "Crosshaven")), "kind": "landmark", "x": spawn_cell.x, "y": spawn_cell.y}],
		"presentation": {"status": "proposed", "authority": "client_visual", "default_weather": ["clear"], "day_night": true},
	})
	return z


static func _cell(v: Variant) -> Vector2i:
	if typeof(v) == TYPE_ARRAY:
		return Vector2i(int(v[0]), int(v[1]))
	if typeof(v) == TYPE_DICTIONARY:
		return Vector2i(int(v.get("x", 0)), int(v.get("y", 0)))
	return Vector2i(-1, -1)


static func _fail(reason: String, errors: Array) -> Dictionary:
	return {"ok": false, "reason": reason, "errors": errors, "city": null}
