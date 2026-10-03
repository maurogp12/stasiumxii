extends RefCounted

## Placeholder deploy glyphs. Scenario Art replaces the PNGs; names stay.
## Zone cells draw the zone mark and the deploy cell. An occupied cell draws the ring.

const ROOT := "res://art/pc/look/glyphs/"
const IDS: Array[String] = ["zone", "deploy", "occupied"]


static func path_for(id: String, master: bool = true) -> String:
	if master:
		return ROOT + "glyph_%s@2x.png" % id
	return ROOT + "glyph_%s.png" % id


static func texture(id: String) -> Texture2D:
	var master := load(path_for(id, true)) as Texture2D
	if master != null:
		return master
	return load(path_for(id, false)) as Texture2D


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
