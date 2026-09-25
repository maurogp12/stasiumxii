class_name CellTagMap
extends RefCounted

## Loader hook for Crosshaven tags. Applied only when the file size matches
## the board. Ship matches ask for size [15,15]. This does not invent cells.
## `paint_only` / Tiled `props_paint` is visual only: never pathing, LoS, or MP.
## The sibling `.tmx` is isometric art (diamond 64×32) and is cross-checked for
## terrain + elevation only.
##
## Schema: { "size": [w, h], "cells": [ { "x", "y", "terrain", "elevation", "paint_only" } ] }

const DEFAULT_TAGS := "res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json"
const DEFAULT_TMX := "res://art/maps/arena_colosseum_v2/tiled/crosshaven_15x15.tmx"
const MAP_ID := "crosshaven_15"
const _TerrainDef := preload("res://backend/terrain_def.gd")


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
		"map_id": map_id_for(path),
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
	if file.contains("12x12"):
		return "crosshaven_12"
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
	var mismatches := 0
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = item
		var pos: Vector2i = rec.get("pos", Vector2i(-1, -1))
		var terrain_gid := _gid_at(terrain, pos)
		var elev_gid := _gid_at(elevation, pos)
		var expect_terrain := str(_TERRAIN_FROM_GID.get(terrain_gid, ""))
		var expect_elev := int(_ELEV_FROM_GID.get(elev_gid, -1))
		if expect_terrain != str(rec.get("terrain", "")) or expect_elev != int(rec.get("elevation", -2)):
			mismatches += 1
	return {"ok": mismatches == 0, "reason": "" if mismatches == 0 else "mismatch", "mismatches": mismatches}


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
