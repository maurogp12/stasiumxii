extends RefCounted

## Painted deploy glyphs. Zone cells draw the zone mark and the deploy cell.
## An occupied cell draws the ring. Both marks sit at one alpha so the purple
## reads on the team tint without a second, brighter plate.

const ROOT := "res://art/pc/look/glyphs/"
const IDS: Array[String] = ["zone", "deploy", "occupied"]
## 60–70%. The same alpha on the zone mark and the deploy mark.
const GLYPH_ALPHA := 0.65


static func path_for(id: String, master: bool = true) -> String:
	if master:
		return ROOT + "glyph_%s@2x.png" % id
	return ROOT + "glyph_%s.png" % id


## The canvas item keeps the texture RID after _draw returns. A texture that
## lived only for that call was released first, and the quad painted solid white.
static var _cache: Dictionary = {}


static func texture(id: String) -> Texture2D:
	if _cache.has(id) and _cache[id] != null:
		return _cache[id]
	var master := load(path_for(id, true)) as Texture2D
	var tex := master if master != null else load(path_for(id, false)) as Texture2D
	if tex != null:
		_cache[id] = tex
	return tex


static func uses_master(id: String) -> bool:
	return FileAccess.file_exists(path_for(id, true))


## @2x masters draw at half size so the mark sits inside the 64×32 diamond.
static func draw_size(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	var scale := 0.5 if str(tex.resource_path).ends_with("@2x.png") else 1.0
	return tex.get_size() * scale


static func ids_for_highlight(kind: String) -> Array[String]:
	if kind == "occupied":
		return ["occupied"]
	if kind == "zone_p1" or kind == "zone_p2":
		return ["zone", "deploy"]
	return []


## Both marks, and the occupied ring, draw at the same alpha.
static func modulate_for(_id: String, _kind: String) -> Color:
	return Color(1, 1, 1, GLYPH_ALPHA)
