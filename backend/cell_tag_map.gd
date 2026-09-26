class_name CellTagMap
extends RefCounted

## Loader hook for Koliseo ship tags. Applied only when the file size matches
## the board. Ship matches ask for size [15,15]. This does not invent cells.
## `paint_only` / Tiled `props_paint` is visual only: never pathing, LoS, or MP.
## The sibling `.tmx` is isometric art (diamond 64×32) and is cross-checked for
## terrain + elevation only.
##
## Catalog ids: crosshaven, brinewake, slagcrown, windmere, stormspire.
## An empty map id loads Crosshaven. `demo_map` stays `{id}_15`.
## Hot-seat calls `random_ship_id()`; this loader does not show a chooser.
##
## Schema: { "size": [w, h], "cells": [ { "x", "y", "terrain", "elevation", "paint_only" } ] }

const ROOT := "res://art/maps/arena_colosseum_v2/tiled/"
const DEFAULT_ID := "crosshaven"
const DEFAULT_TAGS := "res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json"
const DEFAULT_TMX := "res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15.tmx"
const MAP_ID := "crosshaven_15"
const SHIP_MAPS: Array[String] = ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const _INFO := {
	"crosshaven": {"label": "Crosshaven", "blurb": "Warm gold plains"},
	"brinewake": {"label": "Brinewake", "blurb": "Teal stone and ocean"},
	"slagcrown": {"label": "Slagcrown", "blurb": "Ash basalt and lava"},
	"windmere": {"label": "Windmere", "blurb": "Ice-blue meltwater"},
	"stormspire": {"label": "Stormspire", "blurb": "Dark slate and storm pools"},
}
const _TerrainDef := preload("res://backend/terrain_def.gd")


static func is_ship_map(map_id: String) -> bool:
	return SHIP_MAPS.has(normalize_id(map_id))


## Catalog slot. Index wraps so every ship id is reachable.
static func ship_id_at(index: int) -> String:
	if SHIP_MAPS.is_empty():
		return DEFAULT_ID
	return SHIP_MAPS[posmod(index, SHIP_MAPS.size())]


## Uniform among SHIP_MAPS. Pass an RNG to keep a test seed off the global generator.
static func random_ship_id(rng: Variant = null) -> String:
	var count := SHIP_MAPS.size()
	if count == 0:
		return DEFAULT_ID
	var index := 0
	if rng is RandomNumberGenerator:
		index = (rng as RandomNumberGenerator).randi_range(0, count - 1)
	else:
		index = randi_range(0, count - 1)
	return SHIP_MAPS[index]


static func normalize_id(raw: String) -> String:
	var id := raw.strip_edges().to_lower().get_file()
	if id.ends_with("_tags.json"):
		id = id.trim_suffix("_tags.json")
	elif id.ends_with(".json"):
		id = id.trim_suffix(".json")
	elif id.ends_with(".tmx"):
		id = id.trim_suffix(".tmx")
	if id.ends_with("_15x15"):
		id = id.trim_suffix("_15x15")
	elif id.ends_with("_12x12"):
		id = id.trim_suffix("_12x12")
	elif id.ends_with("_15"):
		id = id.trim_suffix("_15")
	elif id.ends_with("_12"):
		id = id.trim_suffix("_12")
	return id


## Empty id is Crosshaven. An unknown id returns "" so the sim does not invent a board.
static func tags_path_for(map_id: String) -> String:
	var id := normalize_id(map_id)
	if id == "":
		id = DEFAULT_ID
	if not SHIP_MAPS.has(id):
		return ""
	return ROOT + "%s_15x15_tags.json" % id


static func preview_path(map_id: String) -> String:
	var id := normalize_id(map_id)
	if not SHIP_MAPS.has(id):
		return ""
	var painted := ROOT + "%s_15x15_painted_preview.png" % id
	if FileAccess.file_exists(painted):
		return painted
	var plain := ROOT + "%s_15x15_preview.png" % id
	if FileAccess.file_exists(plain):
		return plain
	return ""


static func label_of(map_id: String) -> String:
	var id := normalize_id(map_id)
	var info: Dictionary = _INFO.get(id, {})
	return str(info.get("label", id))


static func blurb_of(map_id: String) -> String:
	var id := normalize_id(map_id)
	var info: Dictionary = _INFO.get(id, {})
	return str(info.get("blurb", ""))


static func catalog() -> Array:
	var out: Array = []
	for id in SHIP_MAPS:
		out.append({
			"id": id,
			"label": label_of(id),
			"blurb": blurb_of(id),
			"tags": tags_path_for(id),
			"preview": preview_path(id),
		})
	return out


static func load_default() -> Dictionary:
	return load_file(DEFAULT_TAGS)


static func load_file(path: String) -> Dictionary:
	var missing := _empty("missing")
	if path == "" or not FileAccess.file_exists(path):
		return missing
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _empty("bad_json")
	var doc: Dictionary = parsed
	var labeled := str(doc.get("map_id", "")).strip_edges()
	var size: Variant = doc.get("size", [])
	var width := 0
	var height := 0
	if size is Array and (size as Array).size() >= 2:
		width = int((size as Array)[0])
		height = int((size as Array)[1])
	var combat: Array = []
	var paint := {}
	for item in doc.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var cell := Vector2i(int(rec.get("x", -1)), int(rec.get("y", -1)))
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			continue
		var terrain := _TerrainDef.parse(rec.get("terrain", "ground"))
		combat.append({
			"pos": cell,
			"terrain": _TerrainDef.name_of(terrain),
			"elevation": int(rec.get("elevation", 0)),
		})
		var props: Array = []
		var raw_props: Variant = rec.get("paint_only", [])
		if raw_props is Array:
			for prop_name in raw_props:
				props.append(str(prop_name))
		if not props.is_empty():
			paint[cell] = props
	return {
		"ok": width > 0 and height > 0 and not combat.is_empty(),
		"map_id": labeled if labeled != "" else map_id_for(path),
		"width": width,
		"height": height,
		"cells": combat,
		"paint_only": paint,
		"tmx": sibling_tmx(path),
		"reason": "",
	}


## Sibling isometric `.tmx` next to `*_tags.json`. Not a combat source.
static func sibling_tmx(tags_path: String) -> String:
	if tags_path.ends_with("_tags.json"):
		var tmx_path := tags_path.trim_suffix("_tags.json") + ".tmx"
		if FileAccess.file_exists(tmx_path):
			return tmx_path
	if FileAccess.file_exists(DEFAULT_TMX) and tags_path == DEFAULT_TAGS:
		return DEFAULT_TMX
	return ""


static func map_id_for(path: String) -> String:
	var file := path.get_file()
	var stem := file
	if stem.ends_with("_tags.json"):
		stem = stem.trim_suffix("_tags.json")
	elif stem.ends_with(".tmx"):
		stem = stem.trim_suffix(".tmx")
	if stem.ends_with("_15x15"):
		return stem.trim_suffix("_15x15") + "_15"
	if stem.ends_with("_12x12"):
		return stem.trim_suffix("_12x12") + "_12"
	if file.contains("15x15"):
		return "crosshaven_15"
	return MAP_ID


## Terrain + elevation only. Does not read paint_only or the tmx props layer.
static func apply(board, tags: Dictionary) -> bool:
	if not bool(tags.get("ok", false)):
		return false
	if int(tags.get("width", 0)) != int(board.width) or int(tags.get("height", 0)) != int(board.height):
		return false
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var pos: Vector2i = rec.get("pos", Vector2i(-1, -1))
		board.set_tile(pos, rec.get("terrain", "ground"), int(rec.get("elevation", 0)))
	return true


## Terrain + elevation layers only. props_paint is ignored.
## Legacy Crosshaven GIDs, used when the sibling tileset cannot be read.
const _TERRAIN_FROM_GID := {0: "ground", 2: "mud", 3: "water", 4: "lava"}
const _ELEV_FROM_GID := {0: 0, 6: 1, 7: 2, 8: 1}


static func cross_check_tmx(tags: Dictionary) -> Dictionary:
	var tmx_path := str(tags.get("tmx", ""))
	if tmx_path == "" or not FileAccess.file_exists(tmx_path):
		return {"ok": false, "reason": "missing_tmx", "mismatches": 0}
	var text := FileAccess.get_file_as_string(tmx_path)
	if not text.contains('orientation="isometric"'):
		return {"ok": false, "reason": "orientation", "mismatches": 0}
	if not text.contains('tilewidth="64"') or not text.contains('tileheight="32"'):
		return {"ok": false, "reason": "tile_size", "mismatches": 0}
	var terrain := _layer_grid(text, "terrain")
	var elevation := _layer_grid(text, "elevation")
	if terrain.is_empty() or elevation.is_empty():
		return {"ok": false, "reason": "layers", "mismatches": 0}
	var gid_map := _tileset_gid_map(text, tmx_path)
	var mismatches := 0
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var pos: Vector2i = rec.get("pos", Vector2i(-1, -1))
		var terrain_gid := _gid_at(terrain, pos)
		var elev_gid := _gid_at(elevation, pos)
		if not gid_map.has(terrain_gid) or not gid_map.has(elev_gid):
			mismatches += 1
			continue
		var terrain_info: Dictionary = gid_map[terrain_gid]
		var elev_info: Dictionary = gid_map[elev_gid]
		var expect_terrain := str(terrain_info.get("terrain", ""))
		var expect_elev := int(elev_info.get("elevation", -1))
		if expect_terrain != str(rec.get("terrain", "")) or expect_elev != int(rec.get("elevation", -2)):
			mismatches += 1
	return {"ok": mismatches == 0, "reason": "" if mismatches == 0 else "mismatch", "mismatches": mismatches}


static func _tileset_gid_map(tmx_text: String, tmx_path: String) -> Dictionary:
	var legacy := _legacy_gid_map()
	var tag_at := tmx_text.find("<tileset")
	if tag_at < 0:
		return legacy
	var tag_end := tmx_text.find(">", tag_at)
	if tag_end < 0:
		return legacy
	var tag := tmx_text.substr(tag_at, tag_end - tag_at)
	var source := _attr(tag, "source")
	if source == "":
		return legacy
	var firstgid := int(_attr(tag, "firstgid"))
	if firstgid <= 0:
		firstgid = 1
	var tsx_path := tmx_path.get_base_dir().path_join(source)
	if not FileAccess.file_exists(tsx_path):
		return legacy
	var tsx := FileAccess.get_file_as_string(tsx_path)
	var out := {0: {"terrain": "ground", "elevation": 0}}
	var search := 0
	while true:
		var tile_at := tsx.find('<tile id="', search)
		if tile_at < 0:
			break
		var id_end := tsx.find('"', tile_at + 10)
		if id_end < 0:
			break
		var tid := int(tsx.substr(tile_at + 10, id_end - (tile_at + 10)))
		var next := tsx.find('<tile id="', tile_at + 10)
		var block_end := next if next > 0 else tsx.length()
		var block := tsx.substr(tile_at, block_end - tile_at)
		var paint := _attr(block, "paint_only")
		var terrain := _attr(block, "terrain")
		if paint != "true" and terrain != "" and terrain != "paint_only" and terrain != "void":
			out[tid + firstgid] = {
				"terrain": terrain,
				"elevation": int(_attr(block, "elevation")),
			}
		if next < 0:
			break
		search = next
	if out.size() <= 1:
		return legacy
	return out


static func _legacy_gid_map() -> Dictionary:
	var out := {0: {"terrain": "ground", "elevation": 0}}
	for gid in _TERRAIN_FROM_GID.keys():
		var terrain_name := str(_TERRAIN_FROM_GID[gid])
		var elev := int(_ELEV_FROM_GID.get(gid, 0))
		out[int(gid)] = {"terrain": terrain_name, "elevation": elev}
	for gid in _ELEV_FROM_GID.keys():
		var elev := int(_ELEV_FROM_GID[gid])
		if out.has(int(gid)):
			(out[int(gid)] as Dictionary)["elevation"] = elev
		else:
			out[int(gid)] = {"terrain": "ground", "elevation": elev}
	return out


static func _attr(block: String, attr_name: String) -> String:
	var key := 'name="%s"' % attr_name
	var at := block.find(key)
	if at < 0:
		key = '%s="' % attr_name
		at = block.find(key)
		if at < 0:
			return ""
		var start := at + key.length()
		var end := block.find('"', start)
		if end < 0:
			return ""
		return block.substr(start, end - start)
	var value_key := 'value="'
	var value_at := block.find(value_key, at)
	if value_at < 0:
		return ""
	var start := value_at + value_key.length()
	var end := block.find('"', start)
	if end < 0:
		return ""
	return block.substr(start, end - start)


static func _layer_grid(text: String, layer_name: String) -> Array:
	var at := text.find('name="%s"' % layer_name)
	if at < 0:
		return []
	var data_at := text.find("<data", at)
	var start := text.find(">", data_at)
	var end := text.find("</data>", start)
	if data_at < 0 or start < 0 or end < 0:
		return []
	var body := text.substr(start + 1, end - start - 1)
	var rows: Array = []
	for line in body.split("\n", false):
		var row: Array = []
		for part in line.split(",", false):
			var token := part.strip_edges()
			if token == "":
				continue
			row.append(int(token))
		if not row.is_empty():
			rows.append(row)
	return rows


static func _gid_at(grid: Array, pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= grid.size():
		return -1
	var row: Array = grid[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return -1
	return int(row[pos.x])


static func _empty(reason: String) -> Dictionary:
	return {
		"ok": false,
		"map_id": "",
		"width": 0,
		"height": 0,
		"cells": [],
		"paint_only": {},
		"tmx": "",
		"reason": reason,
	}
