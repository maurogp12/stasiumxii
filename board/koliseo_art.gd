class_name KoliseoArt
extends RefCounted

## Isometric diamonds sliced from the original tileset sheets
## (res://art/tilesets/original/). Flat terrain is a full 64×32 diamond.
## A cliff sheet is 64 wide and taller: the top is the diamond, the rest
## hangs below it. cell_to_local stays ((x-y)*32, (x+y)*16).
## paint_only props are visuals. They are not walk, LoS, or MP data.
## Windmere paints the ice sheet. Stormspire paints the electric sheet.
## See res://art/tilesets/original/THEMES.md.

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
## Scenario sheets are sliced. Nothing in this list is still a hook.
const PENDING_THEMES: Array[String] = []


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


## Full isometric sheet: the texture's top is the north tip of the board diamond.
## Extra rows are cliff face and hang below. A left-half-only sheet (legacy
## dress) still scales that half onto the diamond. Mobile exports often have
## no CPU image, so a 64-wide sheet uses the same top anchor from its size.
static func terrain_placement(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {}
	var key := tex.resource_path
	if key == "":
		key = str(tex.get_instance_id())
	if _placement.has(key):
		return _placement[key]
	var placed := _measure_half_diamond(tex)
	if placed.is_empty() and _image_unreadable(tex):
		placed = dress_placement_for_size(tex.get_size())
	_placement[key] = placed
	return placed


## Top-anchored rect for a 64-wide isometric sheet. Empty for any other width.
## Used when Texture.get_image() is null, and for a measured full-bleed sheet.
static func dress_placement_for_size(size: Vector2) -> Dictionary:
	var width := int(round(size.x))
	var height := int(round(size.y))
	if width != 64 or height < 32:
		return {}
	return {
		"source": Rect2(0, 0, width, height),
		"dest": Rect2(-32.0, -16.0, float(width), float(height)),
	}


static func _image_unreadable(tex: Texture2D) -> bool:
	var image := tex.get_image()
	return image == null or image.is_empty()


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
	if content_bottom < 0:
		return {}
	if right_used:
		return dress_placement_for_size(Vector2(width, height))
	var src_h := content_bottom + 1
	return {
		"source": Rect2(0, 0, half, src_h),
		"dest": Rect2(-32.0, -16.0, float(half) * 2.0, float(src_h) * 2.0),
	}


## Primary terrain sheet, or a `name_vN.png` sibling chosen from the cell.
## The primary file is what `terrain_texture` returns. Neighbors differ when
## the sheet shipped more than one slice of that terrain.
static func terrain_texture_at(terrain: String, elevation: int, dress: String, cell: Vector2i) -> Texture2D:
	var primary := terrain_texture(terrain, elevation, dress)
	if primary == null:
		return null
	var file := primary.resource_path.get_file()
	if file == "":
		return primary
	var siblings := _variant_files(file)
	if siblings.size() <= 1:
		return primary
	var pick := posmod(int(cell.x) * 13 + int(cell.y) * 29 + elevation * 7, siblings.size())
	var chosen := _load(siblings[pick])
	return chosen if chosen != null else primary


static func _variant_files(file_name: String) -> Array[String]:
	var stem := file_name.trim_suffix(".png")
	var base := stem
	var mark := stem.rfind("_v")
	if mark != -1 and stem.substr(mark + 2).is_valid_int():
		base = stem.substr(0, mark)
	var names: Array[String] = []
	var primary := base + ".png"
	if ResourceLoader.exists(ROOT + primary):
		names.append(primary)
	var i := 1
	while i < 8:
		var extra := "%s_v%d.png" % [base, i]
		if not ResourceLoader.exists(ROOT + extra):
			break
		names.append(extra)
		i += 1
	if names.is_empty():
		names.append(file_name)
	return names


## Dress-prefixed props win (`wind_prop_spark.png`), then the shared sheet.
static func prop_texture(prop_name: String, dress: String = "") -> Texture2D:
	if dress != "":
		var themed := _load("%sprop_%s.png" % [dress, prop_name])
		if themed != null:
			return themed
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
