class_name KoliseoArt
extends RefCounted

## Isometric diamond art from the Crosshaven tileset (64×32, taller elev/props).
## Drawn on the existing board diamonds so cell_to_local stays ((x-y)*32, (x+y)*16).
## paint_only props are visuals. They are not walk, LoS, or MP data.

const ROOT := "res://art/maps/arena_colosseum_v2/tiled/tiles/"
const _TERRAIN := {
	"ground": {0: "ground.png", 1: "ground_e1.png", 2: "ground_e2.png"},
	"mud": {0: "mud.png", 1: "mud_e1.png"},
	"water": {0: "water.png"},
	"lava": {0: "lava.png"},
}
const _PROPS := {
	"ruins": "prop_ruins.png",
	"well": "prop_well.png",
	"hay": "prop_hay.png",
	"fence": "prop_fence.png",
	"rubble": "prop_rubble.png",
	"rock_pillar": "prop_rock_pillar.png",
	"floor_seal": "prop_floor_seal.png",
}

static var _cache: Dictionary = {}


static func terrain_texture(terrain: String, elevation: int) -> Texture2D:
	var table: Dictionary = _TERRAIN.get(terrain, {})
	if table.is_empty():
		return null
	var file := ""
	var best := -1
	for key in table.keys():
		var z := int(key)
		if z <= elevation and z >= best:
			best = z
			file = str(table[key])
	if file == "":
		return null
	return _load(file)


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
