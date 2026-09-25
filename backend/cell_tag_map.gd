class_name CellTagMap
extends RefCounted

## Optional cell-tag loader. Applied only when the file size matches the board.
## The ship map is the Mauro 12×12 token grid, not this file.
## `paint_only` (and the Tiled `props_paint` layer) is visual only: never pathing,
## LoS, or MP. The sibling `.tmx` is recorded for the Technical Artist pipeline
## and is not parsed into blockers.
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
		"map_id": MAP_ID,
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
