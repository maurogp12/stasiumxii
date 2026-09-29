class_name ArenaLook
extends RefCounted

## Mauro's look pictures (29 Sep) painted onto the Koliseo boards.
## Floor stamps are cut from the pictures by build_tools/art/arena_look.py into
## art/maps/arena_look/<map>/<terrain>_<n>.png. A tile with a stamp draws it
## instead of the older sheet; a tile without one keeps KoliseoArt.
## Each arena also names its grid ink and the face color of raised cells.
## View only: tags, walk, MP, LoS and legality never read this.

const _Maps := preload("res://backend/cell_tag_map.gd")
const ROOT := "res://art/maps/arena_look/"
const MAX_STAMPS := 12

## ink / gleam are the cell lines (gleam is the lit inner stroke); face_left /
## face_right shade the drop under a raised cell.
const STYLES := {
	"slagcrown": {
		"ink": Color(0.03, 0.01, 0.01, 0.6), "ink_px": 1.8,
		"gleam": Color(1.0, 0.42, 0.10, 0.18), "gleam_px": 1.0,
		"face_left": Color(0.17, 0.10, 0.08), "face_right": Color(0.10, 0.06, 0.05),
		"lip": Color(1.0, 0.48, 0.14, 0.85),
		# terrain -> [shader mode, gain] (board/arena_surface.gdshader)
		"surfaces": {"lava": [1, 1.0], "ground": [2, 1.0], "mud": [2, 0.85]},
		"no_grid": ["lava"],
		"edge_glow": Color(1.0, 0.40, 0.08, 0.95), "edge_from": "lava",
		# One volcano on the centre lava cross (Mauro, 29 Sep). Decoration only.
		"centerpiece": {"cell": Vector2i(7, 7), "prop": "volcano"},
	},
	"brinewake": {
		"ink": Color(0.05, 0.05, 0.07, 0.9), "ink_px": 2.2,
		"gleam": Color(0.55, 0.62, 0.72, 0.32), "gleam_px": 1.0,
		"face_left": Color(0.24, 0.19, 0.15), "face_right": Color(0.16, 0.13, 0.11),
		"surfaces": {"water": [5, 1.0]},
	},
	"stormspire": {
		"ink": Color(0.10, 0.07, 0.02, 0.85), "ink_px": 2.4,
		"gleam": Color(1.0, 0.80, 0.30, 0.85), "gleam_px": 1.3,
		"face_left": Color(0.24, 0.22, 0.32), "face_right": Color(0.15, 0.14, 0.22),
		"lip": Color(1.0, 0.80, 0.30, 0.9),
		"surfaces": {"water": [3, 1.0], "ground": [4, 1.15], "mud": [4, 1.0]},
	},
	"windmere": {
		"ink": Color(0.34, 0.40, 0.50, 0.8), "ink_px": 1.9,
		"gleam": Color(0.92, 0.84, 0.58, 0.55), "gleam_px": 1.0,
		"face_left": Color(0.56, 0.62, 0.72), "face_right": Color(0.40, 0.46, 0.56),
		"surfaces": {"water": [5, 1.0]},
	},
	"crosshaven": {
		"ink": Color(0.20, 0.15, 0.10, 0.8), "ink_px": 2.0,
		"gleam": Color(0.96, 0.88, 0.70, 0.45), "gleam_px": 1.0,
		"face_left": Color(0.52, 0.46, 0.36), "face_right": Color(0.38, 0.33, 0.26),
		"surfaces": {"water": [5, 1.0]},
	},
}

static var _stamps: Dictionary = {}
static var _props: Dictionary = {}


static func normalize(map_id: String) -> String:
	return _Maps.normalize_id(map_id)


static func style_for(map_id: String) -> Dictionary:
	return STYLES.get(normalize(map_id), {})


static func has_look(map_id: String) -> bool:
	return not stamps(map_id, "ground").is_empty()


## Every stamp shipped for this arena and terrain. Empty when none.
static func stamps(map_id: String, terrain: String) -> Array:
	var id := normalize(map_id)
	var key := "%s/%s" % [id, terrain]
	if _stamps.has(key):
		return _stamps[key]
	var out: Array = []
	if STYLES.has(id):
		for i in MAX_STAMPS:
			var path := "%s%s/%s_%d.png" % [ROOT, id, terrain, i]
			if not ResourceLoader.exists(path):
				break
			var tex := load(path) as Texture2D
			if tex != null:
				out.append(tex)
	_stamps[key] = out
	return out


## The stamp a cell paints, fixed per cell so the floor does not shimmer
## between redraws. Null keeps the older sheet.
static func stamp_for(map_id: String, terrain: String, cell: Vector2i) -> Texture2D:
	var list := stamps(map_id, terrain)
	if list.is_empty():
		return null
	var pick := posmod(cell.x * 7 + cell.y * 13 + (cell.x * cell.y) % 5, list.size())
	return list[pick]


## Prop cut from the arena's look picture (build_tools/art/arena_props.py).
## Null keeps the older KoliseoArt prop sprite.
static func prop_for(map_id: String, prop_name: String) -> Texture2D:
	var id := normalize(map_id)
	var key := "%s/%s" % [id, prop_name]
	if _props.has(key):
		return _props[key]
	var tex: Texture2D = null
	var path := "%s%s/prop_%s.png" % [ROOT, id, prop_name]
	if STYLES.has(id) and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_props[key] = tex
	return tex


## [mode, gain] for this arena's animated surface on a terrain, or [] for a
## plain stamp. Modes live in board/arena_surface.gdshader.
static func surface_for(map_id: String, terrain: String) -> Array:
	var surfaces: Dictionary = style_for(map_id).get("surfaces", {})
	return surfaces.get(terrain, [])


## Big decoration an arena draws on one cell (Slagcrown's volcano), or {}.
static func centerpiece_for(map_id: String, cell: Vector2i) -> Texture2D:
	var piece: Dictionary = style_for(map_id).get("centerpiece", {})
	if piece.is_empty() or piece.get("cell") != cell:
		return null
	return prop_for(map_id, str(piece.get("prop", "")))
