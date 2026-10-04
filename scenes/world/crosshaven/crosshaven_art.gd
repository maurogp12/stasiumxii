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
const FARM_TERRAINS: Array[String] = [
	"farm_cabbage", "farm_carrot", "farm_fallow", "farm_lavender",
	"farm_plowed", "farm_pumpkin", "farm_soil", "farm_sunflower",
]
const COTTAGE_SKIN := {
	"crosshaven_northgate": "cottage_slate",
	"crosshaven_stoneford": "cottage_stone",
	"crosshaven_eastmarch": "cottage_thatch",
	"crosshaven_southbridge": "cottage_terracotta",
}

static var _cache: Dictionary = {}
static var _anim_meta: Dictionary = {}


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


static func terrain_seen(zone: WorldZone, cell: Vector2i) -> String:
	if zone.in_bounds(cell):
		return zone.terrain_at(cell)
	if zone.sample_terrain.is_valid():
		return str(zone.sample_terrain.call(cell))
	return ""


static func height_seen(zone: WorldZone, cell: Vector2i) -> int:
	if zone.in_bounds(cell):
		return zone.height_at(cell)
	if zone.sample_height.is_valid():
		return int(zone.sample_height.call(cell))
	return 0


static func _joins(zone: WorldZone, terrain: String, cell: Vector2i) -> bool:
	return terrain_seen(zone, cell) == terrain


## Floor id plus corner decals for one cell, per the kit's README picker.
static func pick_tile(zone: WorldZone, cell: Vector2i) -> Dictionary:
	var terrain := zone.terrain_at(cell)
	if FARM_TERRAINS.has(terrain):
		var farm := _autotile(zone, cell, terrain, terrain + "_edge_", terrain + "_corner_", [terrain + "_a", terrain + "_b"])
		farm["lip"] = ""
		return farm
	var pieces: Array = INTERIOR.get(terrain, [terrain])
	var floor_id: String = pieces[h(cell.x, cell.y, pieces.size())]
	var corners: Array[String] = []
	var lip := ""
	if not EDGE_PREFIX.has(terrain):
		if terrain == "golden_plains":
			lip = grass_lip(zone, cell)
		return {"floor": floor_id, "corners": corners, "lip": lip}
	var g: Array[String] = []
	for side in SIDES:
		if not _joins(zone, terrain, cell + SIDE_DIR[side]):
			g.append(side)
	if not g.is_empty():
		floor_id = str(EDGE_PREFIX[terrain]) + "_".join(g)
	elif terrain == "dirt_road" and _near_poi(zone, cell, 7):
		var macro := "dirt_road_flagstone_m%d%d" % [posmod(cell.x, 3), posmod(cell.y, 3)]
		if h(cell.x, cell.y, 6) == 0 and has("tiles", macro + "_moss"):
			macro = macro + "_moss"
		if has("tiles", macro):
			floor_id = macro
	for c in ["n", "e", "s", "w"]:
		var rec: Array = CORNERS[c]
		if g.has(rec[1]) or g.has(rec[2]):
			continue
		if not _joins(zone, terrain, cell + rec[0]):
			corners.append(str(CORNER_PREFIX[terrain]) + c)
	return {"floor": floor_id, "corners": corners, "lip": lip}


static func _autotile(zone: WorldZone, cell: Vector2i, terrain: String, edge_prefix: String, corner_prefix: String, interiors: Array) -> Dictionary:
	var floor_id: String = interiors[posmod(cell.x + cell.y, interiors.size())]
	var corners: Array[String] = []
	var g: Array[String] = []
	for side in SIDES:
		if not _joins(zone, terrain, cell + SIDE_DIR[side]):
			g.append(side)
	if not g.is_empty():
		var edge_id := edge_prefix + "_".join(g)
		if has("tiles", edge_id):
			floor_id = edge_id
	for c in ["n", "e", "s", "w"]:
		var rec: Array = CORNERS[c]
		if g.has(rec[1]) or g.has(rec[2]):
			continue
		if not _joins(zone, terrain, cell + rec[0]):
			var corner_id := corner_prefix + str(c)
			if has("tiles", corner_id):
				corners.append(corner_id)
	return {"floor": floor_id, "corners": corners}


static func grass_lip(zone: WorldZone, cell: Vector2i) -> String:
	if zone.terrain_at(cell) != "golden_plains":
		return ""
	var g: Array[String] = []
	for side in SIDES:
		var n: Vector2i = cell + SIDE_DIR[side]
		if terrain_seen(zone, n) == "dirt_road":
			g.append(side)
	if g.is_empty():
		return ""
	var id := "grass_lip_" + "_".join(g)
	return id if has("tiles", id) else ""


static func _near_poi(zone: WorldZone, cell: Vector2i, radius: int) -> bool:
	for poi in zone.points_of_interest:
		var at := Vector2i(int(poi["x"]), int(poi["y"]))
		if maxi(absi(at.x - cell.x), absi(at.y - cell.y)) <= radius:
			return true
	return false


## Height-face strips for one cell: [{id, offset}] relative to the lifted south tip.
static func face_strips(zone: WorldZone, cell: Vector2i) -> Array:
	var out: Array = []
	var terrain := zone.terrain_at(cell)
	var elev := zone.height_at(cell)
	for face in ["left", "right"]:
		var n_cell: Vector2i = cell + (Vector2i(0, 1) if face == "left" else Vector2i(1, 0))
		var n_elev := height_seen(zone, n_cell)
		var steps := elev - n_elev
		var base_x := -32.0 if face == "left" else 0.0
		for k in range(maxi(steps, 0)):
			var variant := "a"
			if k == 0:
				variant = "top"
			elif k % 2 == 0 and has("tiles", "%s_side_%s_b" % [terrain, face]):
				variant = "b"
			if terrain == "cliff" and k == steps - 1 and k > 0:
				var below_water := terrain_seen(zone, n_cell) == "water"
				variant = "base_water" if below_water else "base_ground"
			out.append({
				"id": "%s_side_%s_%s" % [terrain, face, variant],
				"offset": Vector2(base_x, -16.0 + 10.0 * float(k)),
			})
	return out


## Draw a kit texture with its top-left at `top_left` (1x pixel space).
## `modulate` is the per-theme multiply. White leaves the painted tile alone.
static func draw_at(ci: CanvasItem, art: Dictionary, top_left: Vector2, modulate: Color = Color.WHITE) -> void:
	var tex: Texture2D = art["tex"]
	var s: float = art["scale"]
	ci.draw_texture_rect(tex, Rect2(top_left, tex.get_size() * s), false, modulate)


static func size_of(art: Dictionary) -> Vector2:
	return (art["tex"] as Texture2D).get_size() * float(art["scale"])


## Zone prop -> kit file id, with per-placement variants by hash of the origin.
## `zone_id` picks a town cottage skin. Callers that omit it keep the v1 file.
static func prop_art_id(prop_type: String, origin: Vector2i, fence_axis: int, zone_id: String = "") -> String:
	match prop_type:
		"fence":
			return "fence_wood_nesw" if fence_axis == 1 else "fence"
		"tree":
			var variants := _tree_variants(zone_id)
			var id: String = variants[h(origin.x, origin.y, variants.size())]
			return id if has("props", id) else "tree"
		"red_roof_cottage":
			var skin := ""
			if COTTAGE_SKIN.has(zone_id):
				skin = str(COTTAGE_SKIN[zone_id])
			else:
				for key in COTTAGE_SKIN.keys():
					if zone_id.begins_with(str(key)):
						skin = str(COTTAGE_SKIN[key])
						break
			if skin != "" and has("props", skin):
				return skin
			if h(origin.x, origin.y, 2) == 1 and has("props", "red_roof_cottage_b"):
				return "red_roof_cottage_b"
			return "red_roof_cottage"
	return prop_type


## Northgate snow kit id for a placement, or "" when the kit has none.
## Trees turn into snow-loaded pines, hedges into small firs, and any other
## prop takes its `<art id>_snow` repaint when that file exists.
static func snow_art_id(prop_type: String, art_id: String, origin: Vector2i) -> String:
	var id := art_id + "_snow"
	if prop_type == "tree" or art_id.begins_with("tree_pine") or art_id.begins_with("tree_oak"):
		var pines := ["tree_pine_snow_a", "tree_pine_snow_b", "tree_pine_snow_c"]
		id = pines[h(origin.x, origin.y, pines.size())]
	elif prop_type.begins_with("hedgerow"):
		id = "fir_snow_small" if h(origin.x, origin.y, 2) == 0 else "fir_snow_small_b"
	elif art_id == "cottage_slate" and h(origin.x, origin.y, 2) == 1:
		id = "cottage_slate_b_snow"
	return id if has("props", id) else ""


## Walk-through decor in the snow: shrubs become small firs, flowers and
## grass become a few snow mounds (or nothing), rocks take a snow cap.
static func snow_decor_id(decor_type: String, cell: Vector2i) -> String:
	if decor_type.begins_with("bush") or decor_type.begins_with("sunflowers") or decor_type == "grass_tuft_tall_a":
		return "fir_snow_small" if h(cell.x, cell.y, 2) == 0 else "fir_snow_small_b"
	if decor_type.begins_with("rock_small"):
		return decor_type + "_snow" if has("props", decor_type + "_snow") else decor_type
	for token in ["flower", "tuft", "mushroom", "leaves", "road_grass", "moss", "reeds"]:
		if decor_type.find(token) >= 0:
			var k := h(cell.x, cell.y, 6)
			if k == 0:
				return "snow_mound_a"
			if k == 1:
				return "snow_mound_b"
			return ""
	return decor_type


static func _tree_variants(zone_id: String) -> Array:
	if zone_id.find("northgate") >= 0:
		return ["tree_pine", "tree_pine", "tree_oak_a"]
	if zone_id.find("westwatch") >= 0:
		return ["tree_birch", "tree_autumn_b", "tree_oak_b"]
	if zone_id.find("southbridge") >= 0:
		return ["tree_birch", "tree_oak_b", "tree_autumn_a"]
	if zone_id.find("eastmarch") >= 0:
		return ["tree_autumn_a", "tree_autumn_b", "tree_oak_a"]
	return TREE_VARIANTS


static func anim_meta(anim_id: String) -> Dictionary:
	if _anim_meta.is_empty():
		var file := FileAccess.open("res://art/world/crosshaven/animated/anim_meta.json", FileAccess.READ)
		if file == null:
			_anim_meta = {"_missing": true}
		else:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				_anim_meta = (parsed as Dictionary).get("animations", {"_missing": true})
			else:
				_anim_meta = {"_missing": true}
	var rec: Variant = _anim_meta.get(anim_id, {})
	return rec if typeof(rec) == TYPE_DICTIONARY else {}


## Bottom-center loop player for a strip in anim_meta, or null when it is missing.
static func anim_texture(anim_id: String) -> Texture2D:
	var key := "anim/" + anim_id
	if _cache.has(key):
		var cached: Variant = _cache[key]
		return cached if cached is Texture2D else null
	var meta := anim_meta(anim_id)
	var tex: Texture2D = null
	if meta.has("file"):
		var path := ROOT + str(meta["file"])
		if ResourceLoader.exists(path):
			tex = load(path)
	_cache[key] = tex
	return tex


static func make_loop(anim_id: String) -> AnimatedSprite2D:
	var meta := anim_meta(anim_id)
	if meta.is_empty() or not meta.has("file"):
		return null
	var frames := int(meta.get("frames", 1))
	var fps := float(meta.get("fps", 8.0))
	var size: Array = meta.get("frame_size", [64, 32])
	if size.size() < 2 or frames < 1:
		return null
	var path := ROOT + str(meta["file"])
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var fw := int(size[0])
	var fh := int(size[1])
	var sheet := SpriteFrames.new()
	sheet.add_animation("loop")
	sheet.set_animation_loop("loop", true)
	sheet.set_animation_speed("loop", maxf(fps, 0.1))
	for i in frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * fw, 0, fw, fh)
		sheet.add_frame("loop", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sheet
	sprite.centered = true
	sprite.position = Vector2(0, -float(fh) * 0.5)
	sprite.frame = h(fw, fh, frames)
	sprite.speed_scale = 0.88 + float(h(fh, fw, 20)) / 100.0
	sprite.play("loop")
	return sprite
