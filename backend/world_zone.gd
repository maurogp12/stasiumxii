class_name WorldZone
extends RefCounted

## One open-world chunk (format stasium.zone v1).
## Tile ids and prop ids are sprite names. See docs/world/crosshaven_zone_format.md.
## This loader does not know combat, MP, or Koliseo arenas.

const FORMAT := "stasium.zone"
const FORMAT_VERSION := 1
const MAX_CHUNK := 128

const TILE_ORDER: Array[String] = [
	"golden_plains", "dirt_road", "water", "cliff",
	"farm_cabbage", "farm_carrot", "farm_fallow", "farm_lavender",
	"farm_plowed", "farm_pumpkin", "farm_soil", "farm_sunflower",
]
const TILE_WALKABLE := {
	"golden_plains": true,
	"dirt_road": true,
	"water": false,
	"cliff": false,
	"farm_cabbage": true,
	"farm_carrot": true,
	"farm_fallow": true,
	"farm_lavender": true,
	"farm_plowed": true,
	"farm_pumpkin": true,
	"farm_soil": true,
	"farm_sunflower": true,
}
const PROP_ORDER: Array[String] = [
	"tree",
	"fence",
	"red_roof_cottage",
	"northgate_spire",
	"stoneford_spire",
	"eastmarch_spire",
	"westwatch_spire",
	"southbridge_spire",
	"crossroads_centerpiece",
	"barn_2x2",
	"farmhouse_2x2",
	"windmill_2x2_body",
	"bakery_2x2",
	"smithy_2x2",
	"tavern_3x2",
	"fountain_2x2",
	"watermill_2x2_body",
	"watchtower_2x2",
	"fishing_hut_2x2",
	"market_stall",
	"cart",
	"scarecrow",
	"farm_fence_nesw",
	"farm_fence_nwse",
	"hedgerow_nesw",
	"hedgerow_nwse",
	"lamp_post",
	"well",
	"hay_bale",
	"waystone",
	"wall_tower",
	"stone_wall_high_nwse",
	"stone_wall_high_nesw",
	"quarry_rocks_a",
	"net_rack",
	"rowboat",
	"crate_apples",
	"signpost_crossroads",
	"brazier",
	"tree_apple",
	"haystack",
	"barrel",
	"tree_cluster_2x2_a",
]
## Walk-through art. Never added to the blocked grid.
const DECOR_TYPES: Array[String] = [
	"bush_small_a", "bush_small_b",
	"decal_dirt_blend", "decal_flowers_pink", "decal_flowers_yellow", "decal_leaves",
	"decal_moss", "decal_path_stones_a", "decal_path_stones_b", "decal_pebbles",
	"decal_puddle_a", "decal_puddle_b", "decal_road_grass", "decal_road_stones",
	"flowers_a", "flowers_b", "flowers_c", "flowers_d",
	"ford_stones", "grass_tuft_a", "grass_tuft_b", "grass_tuft_tall_a",
	"lilypads_a", "mushrooms_a", "mushrooms_b",
	"reeds_a", "reeds_b", "rock_small_c", "rock_small_d",
	"sunflowers_tall", "sunflowers_tall_b", "tuft_a", "tuft_b",
]
## Offsets from the northwest origin. +x east, +y south.
const PROP_FOOTPRINTS := {
	"tree": [[0, 0]],
	"fence": [[0, 0]],
	"red_roof_cottage": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"northgate_spire": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"stoneford_spire": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"eastmarch_spire": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"westwatch_spire": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"southbridge_spire": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"crossroads_centerpiece": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"barn_2x2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"farmhouse_2x2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"windmill_2x2_body": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"bakery_2x2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"smithy_2x2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"tavern_3x2": [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]],
	"fountain_2x2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"watermill_2x2_body": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"watchtower_2x2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"fishing_hut_2x2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"market_stall": [[0, 0], [1, 0]],
	"cart": [[0, 0]],
	"scarecrow": [[0, 0]],
	"farm_fence_nesw": [[0, 0]],
	"farm_fence_nwse": [[0, 0]],
	"hedgerow_nesw": [[0, 0]],
	"hedgerow_nwse": [[0, 0]],
	"lamp_post": [[0, 0]],
	"well": [[0, 0]],
	"hay_bale": [[0, 0]],
	"waystone": [[0, 0]],
	"wall_tower": [[0, 0]],
	"stone_wall_high_nwse": [[0, 0]],
	"stone_wall_high_nesw": [[0, 0]],
	"quarry_rocks_a": [[0, 0]],
	"net_rack": [[0, 0]],
	"rowboat": [[0, 0]],
	"crate_apples": [[0, 0]],
	"signpost_crossroads": [[0, 0]],
	"brazier": [[0, 0]],
	"tree_apple": [[0, 0]],
	"haystack": [[0, 0]],
	"barrel": [[0, 0]],
	"tree_cluster_2x2_a": [[0, 0], [1, 0], [0, 1], [1, 1]],
}
const EDGES: Array[String] = ["north", "south", "east", "west"]
const EDGE_DIR := {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"west": Vector2i(-1, 0),
	"east": Vector2i(1, 0),
}
const OPPOSITE_EDGE := {
	"north": "south",
	"south": "north",
	"east": "west",
	"west": "east",
}
const POI_KINDS: Array[String] = ["town", "crossroads", "landmark"]

var zone_id: String = ""
var region: String = ""
var width: int = 0
var height: int = 0
var spawn: Vector2i = Vector2i.ZERO
var props: Array = []
var decor: Array = []
var exits: Array = []
var points_of_interest: Array = []
var presentation: Dictionary = {}
## View only. The world plane sets these so a chunk edge can see the next
## chunk's tiles. Walk rules stay on terrain_at and height_at.
var sample_terrain: Callable = Callable()
var sample_height: Callable = Callable()

var _terrain: PackedStringArray = PackedStringArray()
var _walkable: PackedByteArray = PackedByteArray()
var _heights: PackedInt32Array = PackedInt32Array()
var _blocked: PackedByteArray = PackedByteArray()
var _links: Dictionary = {}

static var _id_re: RegEx
static var _weather_re: RegEx


static func parse(doc: Variant) -> Dictionary:
	if typeof(doc) != TYPE_DICTIONARY:
		return _invalid(["zone root must be an object"])
	var checked := validate_document(doc)
	if not bool(checked["ok"]):
		checked["zone"] = null
		return checked
	var zone := WorldZone.new()
	zone._apply(doc)
	return {"ok": true, "reason": "", "errors": [], "zone": zone}


static func validate_document(doc: Dictionary) -> Dictionary:
	var errors: Array = []
	_unknown(doc, [
		"format", "format_version", "zone_id", "region", "width", "height",
		"spawn", "points_of_interest", "exits", "props", "decor", "tiles", "presentation",
	], errors, "zone")
	if str(doc.get("format", "")) != FORMAT:
		_err(errors, "format must be %s" % FORMAT)
	if not _whole(doc.get("format_version", null)) or int(doc.get("format_version", -1)) != FORMAT_VERSION:
		_err(errors, "format_version must be %d" % FORMAT_VERSION)
	var zone_id := str(doc.get("zone_id", ""))
	if not _is_id(zone_id):
		_err(errors, "zone_id must be a snake_case id")
	if not _is_id(str(doc.get("region", ""))):
		_err(errors, "region must be a snake_case id")
	if not _in_range(doc.get("width", null), 1, MAX_CHUNK) or not _in_range(doc.get("height", null), 1, MAX_CHUNK):
		_err(errors, "width and height must be integers from 1 to %d" % MAX_CHUNK)
		return _done(errors)
	var width := int(doc["width"])
	var height := int(doc["height"])
	var spawn := _read_cell(doc.get("spawn", null), "spawn", errors)
	var walkable := _read_tiles(doc.get("tiles", null), width, height, errors)
	var blocked := _read_props(doc.get("props", null), width, height, errors)
	if doc.has("decor"):
		_read_decor(doc.get("decor", null), width, height, errors)
	_read_exits(doc.get("exits", null), width, height, walkable, blocked, errors)
	_read_pois(doc.get("points_of_interest", null), width, height, walkable, blocked, errors)
	if bool(spawn.get("ok", false)):
		var spawn_cell := Vector2i(int(spawn["x"]), int(spawn["y"]))
		if not _inside(spawn_cell, width, height):
			_err(errors, "spawn is out of bounds")
		elif not bool(walkable.get(spawn_cell, false)):
			_err(errors, "spawn is not walkable")
		elif bool(blocked.get(spawn_cell, false)):
			_err(errors, "spawn is blocked")
	if doc.has("presentation"):
		_read_presentation(doc["presentation"], errors)
	return _done(errors)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return ""
	return _terrain[_index(cell)]


func walkable_at(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return _walkable[_index(cell)] == 1


func height_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return 0
	return int(_heights[_index(cell)])


func blocked_at(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return _blocked[_index(cell)] == 1


func passable_at(cell: Vector2i) -> bool:
	return walkable_at(cell) and not blocked_at(cell)


func exit_link(cell: Vector2i) -> Dictionary:
	if _links.has(cell):
		return _links[cell]
	return {}


func _apply(doc: Dictionary) -> void:
	zone_id = str(doc["zone_id"])
	region = str(doc["region"])
	width = int(doc["width"])
	height = int(doc["height"])
	var spawn_doc: Dictionary = doc["spawn"]
	spawn = Vector2i(int(spawn_doc["x"]), int(spawn_doc["y"]))
	var count := width * height
	_terrain.resize(count)
	_walkable.resize(count)
	_heights.resize(count)
	_blocked.resize(count)
	_blocked.fill(0)
	for tile in doc["tiles"]:
		var cell := Vector2i(int(tile["x"]), int(tile["y"]))
		var index := _index(cell)
		_terrain[index] = str(tile["terrain"])
		_walkable[index] = 1 if bool(tile["walkable"]) else 0
		_heights[index] = int(tile["height"])
	props = (doc["props"] as Array).duplicate(true)
	for prop in props:
		if not bool(prop.get("blocks", true)):
			continue
		for footprint in prop["footprint"]:
			var cell := Vector2i(int(footprint["x"]), int(footprint["y"]))
			_blocked[_index(cell)] = 1
	decor = []
	if doc.has("decor") and typeof(doc["decor"]) == TYPE_ARRAY:
		decor = (doc["decor"] as Array).duplicate(true)
	exits = (doc["exits"] as Array).duplicate(true)
	for exit_rec in exits:
		for link in exit_rec["links"]:
			var frm: Dictionary = link["from"]
			var dest: Dictionary = link["to"]
			_links[Vector2i(int(frm["x"]), int(frm["y"]))] = {
				"target_zone": str(exit_rec["target_zone"]),
				"x": int(dest["x"]),
				"y": int(dest["y"]),
				"edge": str(exit_rec["edge"]),
				"exit_id": str(exit_rec["id"]),
			}
	points_of_interest = (doc["points_of_interest"] as Array).duplicate(true)
	if doc.has("presentation") and typeof(doc["presentation"]) == TYPE_DICTIONARY:
		presentation = (doc["presentation"] as Dictionary).duplicate(true)


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


static func _read_tiles(value: Variant, width: int, height: int, errors: Array) -> Dictionary:
	var walkable := {}
	if typeof(value) != TYPE_ARRAY:
		_err(errors, "tiles must be an array")
		return walkable
	var tiles: Array = value
	var expected := width * height
	if tiles.size() != expected:
		_err(errors, "tiles length must be width * height")
		return walkable
	for i in tiles.size():
		if typeof(tiles[i]) != TYPE_DICTIONARY:
			_err(errors, "tiles[%d] must be an object" % i)
			continue
		var tile: Dictionary = tiles[i]
		_unknown(tile, ["x", "y", "terrain", "walkable", "height"], errors, "tiles[%d]" % i)
		var x := i % width
		var y := int(i / float(width))
		if not _whole(tile.get("x", null)) or not _whole(tile.get("y", null)) or int(tile.get("x", -1)) != x or int(tile.get("y", -1)) != y:
			_err(errors, "tiles[%d] must be row-major cell %d,%d" % [i, x, y])
			continue
		var terrain := str(tile.get("terrain", ""))
		if not TILE_WALKABLE.has(terrain):
			_err(errors, "tiles[%d] terrain is not a tile id" % i)
			continue
		if typeof(tile.get("walkable", null)) != TYPE_BOOL:
			_err(errors, "tiles[%d] walkable must be a boolean" % i)
			continue
		if bool(tile["walkable"]) != bool(TILE_WALKABLE[terrain]):
			_err(errors, "tiles[%d] walkable does not match %s" % [i, terrain])
		if not _whole(tile.get("height", null)) or int(tile.get("height", -1)) < 0:
			_err(errors, "tiles[%d] height must be a non-negative integer" % i)
		walkable[Vector2i(x, y)] = bool(tile["walkable"])
	return walkable


static func _read_props(value: Variant, width: int, height: int, errors: Array) -> Dictionary:
	var blocked := {}
	if typeof(value) != TYPE_ARRAY:
		_err(errors, "props must be an array")
		return blocked
	var seen := {}
	for index in (value as Array).size():
		var item = (value as Array)[index]
		var label := "props[%d]" % index
		if typeof(item) != TYPE_DICTIONARY:
			_err(errors, "%s must be an object" % label)
			continue
		var prop: Dictionary = item
		_unknown(prop, ["id", "type", "blocks", "origin", "footprint"], errors, label)
		var prop_id := str(prop.get("id", ""))
		if not _is_id(prop_id):
			_err(errors, "%s id must be snake_case" % label)
		elif seen.has(prop_id):
			_err(errors, "%s duplicates id %s" % [label, prop_id])
		seen[prop_id] = true
		var prop_type := str(prop.get("type", ""))
		if not PROP_FOOTPRINTS.has(prop_type):
			_err(errors, "%s type is not a prop id" % label)
			continue
		if typeof(prop.get("blocks", null)) != TYPE_BOOL:
			_err(errors, "%s blocks must be a boolean" % label)
			continue
		var does_block := bool(prop["blocks"])
		var origin := _read_cell(prop.get("origin", null), "%s origin" % label, errors)
		if typeof(prop.get("footprint", null)) != TYPE_ARRAY:
			_err(errors, "%s footprint must be an array" % label)
			continue
		var footprint: Array = prop["footprint"]
		var shape: Array = PROP_FOOTPRINTS[prop_type]
		if not bool(origin.get("ok", false)):
			continue
		if footprint.size() != shape.size():
			_err(errors, "%s footprint does not match %s" % [label, prop_type])
			continue
		var got := {}
		for cell_value in footprint:
			var cell := _read_cell(cell_value, "%s footprint" % label, errors)
			if not bool(cell.get("ok", false)):
				continue
			var at := Vector2i(int(cell["x"]), int(cell["y"]))
			if not _inside(at, width, height):
				_err(errors, "%s footprint %s is out of bounds" % [label, at])
				continue
			if does_block and blocked.has(at):
				_err(errors, "%s overlaps %s" % [label, at])
			got[at] = true
		for offset in shape:
			var at := Vector2i(int(origin["x"]) + int(offset[0]), int(origin["y"]) + int(offset[1]))
			if not got.has(at):
				_err(errors, "%s footprint does not match %s offsets" % [label, prop_type])
				break
		if does_block and got.size() == shape.size():
			for at in got.keys():
				blocked[at] = true
	return blocked


static func _read_decor(value: Variant, width: int, height: int, errors: Array) -> void:
	if typeof(value) != TYPE_ARRAY:
		_err(errors, "decor must be an array")
		return
	var seen := {}
	for index in (value as Array).size():
		var item = (value as Array)[index]
		var label := "decor[%d]" % index
		if typeof(item) != TYPE_DICTIONARY:
			_err(errors, "%s must be an object" % label)
			continue
		var decor_rec: Dictionary = item
		_unknown(decor_rec, ["id", "type", "x", "y"], errors, label)
		var decor_id := str(decor_rec.get("id", ""))
		if not _is_id(decor_id):
			_err(errors, "%s id must be snake_case" % label)
		elif seen.has(decor_id):
			_err(errors, "%s duplicates id %s" % [label, decor_id])
		seen[decor_id] = true
		var decor_type := str(decor_rec.get("type", ""))
		if not DECOR_TYPES.has(decor_type):
			_err(errors, "%s type is not a decor id" % label)
		if not _whole(decor_rec.get("x", null)) or not _whole(decor_rec.get("y", null)):
			_err(errors, "%s needs integer x and y" % label)
			continue
		var cell := Vector2i(int(decor_rec["x"]), int(decor_rec["y"]))
		if not _inside(cell, width, height):
			_err(errors, "%s is out of bounds" % label)


static func _read_exits(value: Variant, width: int, height: int, walkable: Dictionary, blocked: Dictionary, errors: Array) -> void:
	if typeof(value) != TYPE_ARRAY:
		_err(errors, "exits must be an array")
		return
	var seen_ids := {}
	var seen_cells := {}
	for index in (value as Array).size():
		var item = (value as Array)[index]
		var label := "exits[%d]" % index
		if typeof(item) != TYPE_DICTIONARY:
			_err(errors, "%s must be an object" % label)
			continue
		var exit_rec: Dictionary = item
		_unknown(exit_rec, ["id", "edge", "target_zone", "links"], errors, label)
		var exit_id := str(exit_rec.get("id", ""))
		if not _is_id(exit_id):
			_err(errors, "%s id must be snake_case" % label)
		elif seen_ids.has(exit_id):
			_err(errors, "%s duplicates id %s" % [label, exit_id])
		seen_ids[exit_id] = true
		var edge := str(exit_rec.get("edge", ""))
		if not EDGES.has(edge):
			_err(errors, "%s edge must be north, south, east, or west" % label)
		if not _is_id(str(exit_rec.get("target_zone", ""))):
			_err(errors, "%s target_zone must be a snake_case id" % label)
		if typeof(exit_rec.get("links", null)) != TYPE_ARRAY or (exit_rec.get("links", []) as Array).is_empty():
			_err(errors, "%s links must be a non-empty array" % label)
			continue
		for link_index in (exit_rec["links"] as Array).size():
			var link = (exit_rec["links"] as Array)[link_index]
			var link_label := "%s.links[%d]" % [label, link_index]
			if typeof(link) != TYPE_DICTIONARY:
				_err(errors, "%s must be an object" % link_label)
				continue
			_unknown(link, ["from", "to"], errors, link_label)
			var frm := _read_cell(link.get("from", null), "%s from" % link_label, errors)
			_read_cell(link.get("to", null), "%s to" % link_label, errors)
			if not bool(frm.get("ok", false)) or not EDGES.has(edge):
				continue
			var cell := Vector2i(int(frm["x"]), int(frm["y"]))
			if seen_cells.has(cell):
				_err(errors, "%s reuses exit tile %s" % [link_label, cell])
			seen_cells[cell] = true
			if not _on_edge(cell, edge, width, height):
				_err(errors, "%s from %s is not on the %s edge" % [link_label, cell, edge])
			elif not bool(walkable.get(cell, false)):
				_err(errors, "%s from %s is not walkable" % [link_label, cell])
			elif bool(blocked.get(cell, false)):
				_err(errors, "%s from %s is blocked" % [link_label, cell])


static func _read_pois(value: Variant, width: int, height: int, walkable: Dictionary, blocked: Dictionary, errors: Array) -> void:
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		_err(errors, "points_of_interest must be a non-empty array")
		return
	var seen := {}
	for index in (value as Array).size():
		var item = (value as Array)[index]
		var label := "points_of_interest[%d]" % index
		if typeof(item) != TYPE_DICTIONARY:
			_err(errors, "%s must be an object" % label)
			continue
		var poi: Dictionary = item
		_unknown(poi, ["id", "name", "kind", "x", "y"], errors, label)
		var poi_id := str(poi.get("id", ""))
		if not _is_id(poi_id):
			_err(errors, "%s id must be snake_case" % label)
		elif seen.has(poi_id):
			_err(errors, "%s duplicates id %s" % [label, poi_id])
		seen[poi_id] = true
		if str(poi.get("name", "")).strip_edges() == "":
			_err(errors, "%s name is empty" % label)
		if not POI_KINDS.has(str(poi.get("kind", ""))):
			_err(errors, "%s kind must be town, crossroads, or landmark" % label)
		if not _whole(poi.get("x", null)) or not _whole(poi.get("y", null)):
			_err(errors, "%s needs integer x and y" % label)
			continue
		var cell := Vector2i(int(poi["x"]), int(poi["y"]))
		if not _inside(cell, width, height):
			_err(errors, "%s is out of bounds" % label)
		elif not bool(walkable.get(cell, false)) or bool(blocked.get(cell, false)):
			_err(errors, "%s is not passable" % label)


static func _read_presentation(value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		_err(errors, "presentation must be an object")
		return
	var presentation: Dictionary = value
	_unknown(presentation, ["status", "authority", "default_weather", "day_night"], errors, "presentation")
	if str(presentation.get("status", "")) != "proposed":
		_err(errors, "presentation.status must be proposed")
	if str(presentation.get("authority", "")) != "client_visual":
		_err(errors, "presentation.authority must be client_visual")
	if typeof(presentation.get("day_night", null)) != TYPE_BOOL:
		_err(errors, "presentation.day_night must be a boolean")
	if typeof(presentation.get("default_weather", null)) != TYPE_ARRAY or (presentation.get("default_weather", []) as Array).is_empty():
		_err(errors, "presentation.default_weather must be a non-empty array")
		return
	var seen := {}
	for item in presentation["default_weather"]:
		var name := str(item)
		if typeof(item) != TYPE_STRING or _weather_pattern().search(name) == null:
			_err(errors, "presentation weather id is invalid")
		elif seen.has(name):
			_err(errors, "presentation weather repeats %s" % name)
		seen[name] = true


static func _on_edge(cell: Vector2i, edge: String, width: int, height: int) -> bool:
	if not _inside(cell, width, height) or not EDGE_DIR.has(edge):
		return false
	var outward: Vector2i = cell + EDGE_DIR[edge]
	return not _inside(outward, width, height)


static func _inside(cell: Vector2i, width: int, height: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


static func _read_cell(value: Variant, label: String, errors: Array) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		_err(errors, "%s must be an object" % label)
		return {"ok": false}
	_unknown(value, ["x", "y"], errors, label)
	if not _whole(value.get("x", null)) or not _whole(value.get("y", null)):
		_err(errors, "%s needs integer x and y" % label)
		return {"ok": false}
	if int(value["x"]) < 0 or int(value["y"]) < 0:
		_err(errors, "%s is negative" % label)
		return {"ok": false}
	return {"ok": true, "x": int(value["x"]), "y": int(value["y"])}


static func _unknown(doc: Dictionary, allowed: Array, errors: Array, label: String) -> void:
	for key in doc.keys():
		if not allowed.has(str(key)):
			_err(errors, "%s has unknown key %s" % [label, key])


static func _whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) == float(int(value))


static func _in_range(value: Variant, low: int, high: int) -> bool:
	return _whole(value) and int(value) >= low and int(value) <= high


static func _is_id(text: String) -> bool:
	return text != "" and _id_pattern().search(text) != null


static func _id_pattern() -> RegEx:
	if _id_re == null:
		_id_re = RegEx.new()
		_id_re.compile("^[a-z][a-z0-9_]*$")
	return _id_re


static func _weather_pattern() -> RegEx:
	if _weather_re == null:
		_weather_re = RegEx.new()
		_weather_re.compile("^[a-z][a-z_]*$")
	return _weather_re


static func _err(errors: Array, message: String) -> void:
	if errors.size() < 32:
		errors.append(message)


static func _done(errors: Array) -> Dictionary:
	if errors.is_empty():
		return {"ok": true, "reason": "", "errors": []}
	return _invalid(errors)


static func _invalid(errors: Array) -> Dictionary:
	return {"ok": false, "reason": "invalid_zone", "errors": errors, "zone": null}
