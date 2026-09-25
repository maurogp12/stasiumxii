class_name KoliseoArt
extends RefCounted

## Isometric diamond art from the Crosshaven tileset (64×32, taller elev/props).
## Drawn on the existing board diamonds so cell_to_local stays ((x-y)*32, (x+y)*16).
## paint_only props are visuals. They are not walk, LoS, or MP data.

const ROOT := "res://art/maps/arena_colosseum_v2/tiled/tiles/"
const _Maps := preload("res://backend/cell_tag_map.gd")
## File prefix for region-tinted grounds. Crosshaven uses the base names.
const DRESS := {
	"crosshaven": "",
	"brinewake": "brine_",
	"slagcrown": "slag_",
	"windmere": "wind_",
	"stormspire": "storm_",
}
const _PROPS := {
	"ruins": "prop_ruins.png",
	"well": "prop_well.png",
	"hay": "prop_hay.png",
	"fence": "prop_fence.png",
	"rubble": "prop_rubble.png",
	"rock_pillar": "prop_rock_pillar.png",
	"floor_seal": "prop_floor_seal.png",
	"driftwood": "prop_driftwood.png",
	"waterfall": "prop_waterfall.png",
	"rock_cluster": "prop_rock_cluster.png",
	"basalt_pillar": "prop_basalt_pillar.png",
	"steam_vent": "prop_steam_vent.png",
	"ash_rock": "prop_ash_rock.png",
	"crystal": "prop_crystal.png",
	"ice_shard": "prop_ice_shard.png",
	"ice_sheet": "prop_ice_sheet.png",
	"spark": "prop_spark.png",
	"conduit": "prop_conduit.png",
	"crystal_bolt": "prop_crystal_bolt.png",
	"arc": "prop_arc.png",
}

static var _cache: Dictionary = {}
static var _placement: Dictionary = {}


## `crosshaven_15` and `brinewake` both resolve. Unknown ids use the base dress.
static func dress_for(map_id: String) -> String:
	var id := _Maps.normalize_id(map_id)
	return str(DRESS.get(id, ""))


## Region dress is tried first (`brine_ground_e1.png`), then the Crosshaven sheet.
## A missing higher cliff falls back to the next lower sheet of that dress.
static func terrain_texture(terrain: String, elevation: int, dress: String = "") -> Texture2D:
	var prefixes: Array[String] = []
	if dress != "":
		prefixes.append(dress)
	prefixes.append("")
	for prefix in prefixes:
		var z := elevation
		while z >= 0:
			var file := "%s%s.png" % [prefix, terrain]
			if z > 0:
				file = "%s%s_e%d.png" % [prefix, terrain, z]
			var tex := _load(file)
			if tex != null:
				return tex
			z -= 1
	return null


## Painted dress v1 stores the terrain diamond in the top-left half of the PNG.
## The returned rects scale that half onto the 64×32 board diamond. Extra source
## rows are the cliff and stay below the diamond. A full-bleed sheet returns empty
## so the caller draws the texture centered.
static func terrain_placement(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {}
	var key := tex.resource_path
	if key == "":
		key = str(tex.get_instance_id())
	if _placement.has(key):
		return _placement[key]
	var placed := _measure_half_diamond(tex)
	_placement[key] = placed
	return placed


static func _measure_half_diamond(tex: Texture2D) -> Dictionary:
	var image := tex.get_image()
	if image == null or image.is_empty():
		return {}
	var width := image.get_width()
	var height := image.get_height()
	if width < 2 or height < 1:
		return {}
	var half := width / 2
	var content_bottom := -1
	var right_used := false
	for y in height:
		for x in half:
			if image.get_pixel(x, y).a > 0.03:
				content_bottom = y
				break
		if right_used:
			continue
		for x in range(half, width):
			if image.get_pixel(x, y).a > 0.03:
				right_used = true
				break
	if right_used or content_bottom < 0:
		return {}
	var src_h := content_bottom + 1
	return {
		"source": Rect2(0, 0, half, src_h),
		"dest": Rect2(-32.0, -16.0, float(half) * 2.0, float(src_h) * 2.0),
	}


static func prop_texture(prop_name: String) -> Texture2D:
	var file := str(_PROPS.get(prop_name, ""))
	if file == "":
		return null
	return _load(file)


static func _load(file_name: String) -> Texture2D:
	if _cache.has(file_name):
		var cached: Variant = _cache[file_name]
		return cached as Texture2D
	var path := ROOT + file_name
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	_cache[file_name] = tex
	return tex
