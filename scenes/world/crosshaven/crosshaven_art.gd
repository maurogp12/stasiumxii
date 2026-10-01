class_name CrosshavenArt
extends RefCounted

## VIEW ONLY. Loads the Technical Artist's Crosshaven kit (art/world/crosshaven/,
## see its README) and ports its autotile picker. Prefers the 2x masters drawn
## at half size so the art stays sharp when the camera zooms in.
## Nothing here changes walkability; zone data stays authoritative.

const ROOT := "res://art/world/crosshaven/"

const SIDES := ["nw", "ne", "se", "sw"]
const SIDE_DIR := {
	"nw": Vector2i(-1, 0),
	"ne": Vector2i(0, -1),
	"se": Vector2i(1, 0),
	"sw": Vector2i(0, 1),
}
## Diagonal corner -> [its offset, its two adjacent sides].
const CORNERS := {
	"n": [Vector2i(-1, -1), "nw", "ne"],
	"e": [Vector2i(1, -1), "ne", "se"],
	"s": [Vector2i(1, 1), "se", "sw"],
	"w": [Vector2i(-1, 1), "sw", "nw"],
}
const INTERIOR := {
	"golden_plains": ["golden_plains_a", "golden_plains_b", "golden_plains_c", "golden_plains_d",
		"golden_plains_a", "golden_plains_b", "golden_plains_c", "golden_plains_d",
		"golden_plains_golden_a", "golden_plains_golden_b", "golden_plains_flowers_a",
		"golden_plains_flowers_b", "golden_plains_flowers_c"],
	"dirt_road": ["dirt_road_a", "dirt_road_b", "dirt_road_c", "dirt_road_d"],
	"water": ["water_a", "water_b", "water_c", "water_d"],
	"cliff": ["cliff_a", "cliff_b", "cliff_c"],
}
## Families that autotile against grass. Plains are the "grass" everything meets.
const EDGE_PREFIX := {
	"dirt_road": "dirt_road_edge_",
	"water": "water_bank_",
	"cliff": "cliff_edge_",
}
const CORNER_PREFIX := {
	"dirt_road": "dirt_road_corner_",
	"water": "water_bank_corner_",
	"cliff": "cliff_corner_",
}
const TREE_VARIANTS := ["tree_oak_a", "tree_oak_b", "tree_autumn_a", "tree_autumn_b", "tree_pine"]

static var _cache: Dictionary = {}


## {tex: Texture2D, scale: float} or {} when the file is missing.
static func texture(kind: String, id: String) -> Dictionary:
	var key := kind + "/" + id
	if _cache.has(key):
		return _cache[key]
	var out := {}
	var hi := ROOT + kind + "/_2x/" + id + ".png"
	var lo := ROOT + kind + "/" + id + ".png"
	if ResourceLoader.exists(hi):
		out = {"tex": load(hi), "scale": 0.5}
	elif ResourceLoader.exists(lo):
		out = {"tex": load(lo), "scale": 1.0}
	_cache[key] = out
	return out


static func has(kind: String, id: String) -> bool:
	return not texture(kind, id).is_empty()


static func clear_cache() -> void:
	_cache.clear()


## The kit's hash, bit-for-bit with its mock renderer.
static func h(x: int, y: int, k: int) -> int:
	return (((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 0x7fffffff) % k


static func _joins(zone: WorldZone, terrain: String, cell: Vector2i) -> bool:
	if not zone.in_bounds(cell):
		return false
	return zone.terrain_at(cell) == terrain


## Floor id plus corner decals for one cell, per the kit's README picker.
static func pick_tile(zone: WorldZone, cell: Vector2i) -> Dictionary:
	var terrain := zone.terrain_at(cell)
	var pieces: Array = INTERIOR.get(terrain, [terrain])
	var floor_id: String = pieces[h(cell.x, cell.y, pieces.size())]
	var corners: Array[String] = []
	if not EDGE_PREFIX.has(terrain):
		return {"floor": floor_id, "corners": corners}
	var g: Array[String] = []
	for side in SIDES:
		if not _joins(zone, terrain, cell + SIDE_DIR[side]):
			g.append(side)
	if not g.is_empty():
		floor_id = str(EDGE_PREFIX[terrain]) + "_".join(g)
	for c in ["n", "e", "s", "w"]:
		var rec: Array = CORNERS[c]
		if g.has(rec[1]) or g.has(rec[2]):
			continue
		if not _joins(zone, terrain, cell + rec[0]):
			corners.append(str(CORNER_PREFIX[terrain]) + c)
	return {"floor": floor_id, "corners": corners}


## Height-face strips for one cell: [{id, offset}] relative to the lifted south tip.
static func face_strips(zone: WorldZone, cell: Vector2i) -> Array:
	var out: Array = []
	var terrain := zone.terrain_at(cell)
	var elev := zone.height_at(cell)
	for face in ["left", "right"]:
		var n_cell: Vector2i = cell + (Vector2i(0, 1) if face == "left" else Vector2i(1, 0))
		var n_elev := zone.height_at(n_cell) if zone.in_bounds(n_cell) else 0
		var steps := elev - n_elev
		var base_x := -32.0 if face == "left" else 0.0
		for k in range(maxi(steps, 0)):
			var variant := "a"
			if k == 0:
				variant = "top"
			elif k % 2 == 0 and has("tiles", "%s_side_%s_b" % [terrain, face]):
				variant = "b"
			if terrain == "cliff" and k == steps - 1 and k > 0:
				var below_water := zone.in_bounds(n_cell) and zone.terrain_at(n_cell) == "water"
				variant = "base_water" if below_water else "base_ground"
			out.append({
				"id": "%s_side_%s_%s" % [terrain, face, variant],
				"offset": Vector2(base_x, -16.0 + 10.0 * float(k)),
			})
	return out


## Draw a kit texture with its top-left at `top_left` (1x pixel space).
static func draw_at(ci: CanvasItem, art: Dictionary, top_left: Vector2) -> void:
	var tex: Texture2D = art["tex"]
	var s: float = art["scale"]
	ci.draw_texture_rect(tex, Rect2(top_left, tex.get_size() * s), false)


static func size_of(art: Dictionary) -> Vector2:
	return (art["tex"] as Texture2D).get_size() * float(art["scale"])


## Zone prop -> kit file id, with per-placement variants by hash of the origin.
static func prop_art_id(prop_type: String, origin: Vector2i, fence_axis: int) -> String:
	match prop_type:
		"fence":
			return "fence_wood_nesw" if fence_axis == 1 else "fence"
		"tree":
			var id: String = TREE_VARIANTS[h(origin.x, origin.y, TREE_VARIANTS.size())]
			return id if has("props", id) else "tree"
		"red_roof_cottage":
			if h(origin.x, origin.y, 2) == 1 and has("props", "red_roof_cottage_b"):
				return "red_roof_cottage_b"
			return "red_roof_cottage"
	return prop_type
