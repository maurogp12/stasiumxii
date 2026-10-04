extends RefCounted

## View-only loader for outskirts theme kits. No class_name.
## Each kit names its own files in kit.json: `file` is the master drawn at
## half size, `file_1x` is the half-size fallback. Eastmarch masters are
## `<id>@2x.png` next to `<id>.png`. A later kit (Northgate) can point
## `file` at `tiles/_2x/<id>.png` and this loader follows that path.
## Nothing here changes walkability.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

const ROOT := "res://art/pc/look/outskirts/"
const SIDES: Array[String] = ["nw", "ne", "se", "sw"]
const SIDE_DIR := {
	"nw": Vector2i(-1, 0),
	"ne": Vector2i(0, -1),
	"se": Vector2i(1, 0),
	"sw": Vector2i(0, 1),
}
const CORNERS := {
	"n": [Vector2i(-1, -1), "nw", "ne"],
	"e": [Vector2i(1, -1), "ne", "se"],
	"s": [Vector2i(1, 1), "se", "sw"],
	"w": [Vector2i(-1, 1), "sw", "nw"],
}

static var _docs: Dictionary = {}
static var _tex: Dictionary = {}


static func doc(theme: String) -> Dictionary:
	if _docs.has(theme):
		return _docs[theme]
	var path := ROOT + theme + "/kit.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_docs[theme] = {}
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_docs[theme] = {}
		return {}
	var raw: Dictionary = parsed
	var items: Dictionary = {}
	var families: Dictionary = {}
	for item_value in raw.get("items", []):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		items[str(item.get("id", ""))] = item
	var grammar: Dictionary = raw.get("grammar", {})
	var fam_raw: Dictionary = grammar.get("families", {})
	for fam_name in fam_raw.keys():
		var fam: Dictionary = fam_raw[fam_name]
		families[str(fam_name)] = {
			"interiors": fam.get("interiors", []),
			"edge": str(fam.get("edge", "")),
			"corner": str(fam.get("corner", "")),
			"against": _clean_against(fam.get("against", [])),
		}
	var packed := {
		"theme": str(raw.get("theme", theme)),
		"count": int(raw.get("count", 0)),
		"items": items,
		"families": families,
	}
	_docs[theme] = packed
	return packed


static func _clean_against(raw: Variant) -> Array:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item in raw:
		var name := str(item)
		if name == "" or name.find(" ") >= 0 or name.find("(") >= 0:
			continue
		out.append(name)
	return out


static func has_theme(theme: String) -> bool:
	var packed := doc(theme)
	return int(packed.get("count", 0)) > 0 and not (packed.get("items", {}) as Dictionary).is_empty()


## Master path as kit.json wrote it, relative to the theme folder.
static func master_file(theme: String, id: String) -> String:
	var packed := doc(theme)
	var items: Dictionary = packed.get("items", {})
	if not items.has(id):
		return ""
	var item: Dictionary = items[id]
	return str(item.get("file", ""))


static func texture(theme: String, id: String) -> Dictionary:
	var key := theme + "/" + id
	if _tex.has(key):
		return _tex[key]
	var packed := doc(theme)
	var items: Dictionary = packed.get("items", {})
	var out := {}
	if items.has(id):
		var item: Dictionary = items[id]
		var hi := ROOT + theme + "/" + str(item.get("file", ""))
		var lo := ROOT + theme + "/" + str(item.get("file_1x", ""))
		if str(item.get("file", "")) != "" and ResourceLoader.exists(hi):
			out = {"tex": load(hi), "scale": 0.5}
		elif str(item.get("file_1x", "")) != "" and ResourceLoader.exists(lo):
			out = {"tex": load(lo), "scale": 1.0}
	_tex[key] = out
	return out


## Floor, corner decals, and whether the interior may flip.
## Edge and corner pieces stay unflipped: each side is a specific piece.
## `seen` returns the neighbour's visual family (or terrain id).
static func pick(theme: String, family: String, cell: Vector2i, seen: Callable) -> Dictionary:
	var packed := doc(theme)
	var families: Dictionary = packed.get("families", {})
	if not families.has(family):
		return {"floor": "", "corners": [], "flip_h": false, "flip_v": false}
	var spec: Dictionary = families[family]
	var interiors: Array = spec["interiors"]
	if interiors.is_empty():
		return {"floor": "", "corners": [], "flip_h": false, "flip_v": false}
	var floor := str(interiors[Art.h(cell.x, cell.y, interiors.size())])
	var against: Array = spec["against"]
	var g: Array[String] = []
	for side in SIDES:
		var nb := str(seen.call(cell + SIDE_DIR[side]))
		if against.has(nb):
			g.append(side)
	var kind := "tile"
	if not g.is_empty():
		floor = str(spec["edge"]) + "_".join(g)
		kind = "edge"
	var corners: Array[String] = []
	for c in ["n", "e", "s", "w"]:
		var rec: Array = CORNERS[c]
		if g.has(str(rec[1])) or g.has(str(rec[2])):
			continue
		var diag := str(seen.call(cell + rec[0]))
		if against.has(diag):
			corners.append(str(spec["corner"]) + c)
	var flip_h := false
	var flip_v := false
	if kind == "tile":
		var bits := Art.h(cell.x, cell.y, 4)
		flip_h = (bits & 1) == 1
		flip_v = (bits & 2) == 2
	return {"floor": floor, "corners": corners, "flip_h": flip_h, "flip_v": flip_v}


## Bottom-centre of the canvas sits on `south_tip`. The cave's 15 px
## transparent gap stays; the sprite is not shifted down onto the tip.
static func draw(ci: CanvasItem, art: Dictionary, south_tip: Vector2, modulate: Color, flip_h: bool, flip_v: bool) -> void:
	if art.is_empty():
		return
	var tex: Texture2D = art["tex"]
	var scale := float(art["scale"])
	var size := tex.get_size() * scale
	var top_left := south_tip + Vector2(-size.x * 0.5, -size.y)
	if not flip_h and not flip_v:
		ci.draw_texture_rect(tex, Rect2(top_left, size), false, modulate)
		return
	var center := top_left + size * 0.5
	var sx := -1.0 if flip_h else 1.0
	var sy := -1.0 if flip_v else 1.0
	ci.draw_set_transform(center, 0.0, Vector2(sx, sy))
	ci.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
