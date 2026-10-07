extends RefCounted
class_name PaintedRoom

## Painted arena plates. Backgrounds, occluders, and surface crops load as
## raw WebP bytes (webpbin) so the phone pack keeps the authored file size.
## Gameplay tiles stay in charge of highlights, grid ink, edge glow, and input.

const ROOT := "res://art/rooms/"
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const ARENA_LOOK := preload("res://board/arena_look.gd")

static var _tex: Dictionary = {}
static var _bound_room: String = ""


static func room_id_for(map_id: String, stasis_letter: String) -> String:
	var biome := ARENA_LOOK.normalize(map_id)
	if biome == "":
		return ""
	var letter := stasis_letter.strip_edges().to_lower()
	if letter == "a" or letter == "b":
		return "stasis_%s_room_%s" % [biome, letter]
	return "koliseo_%s" % biome


static func texture_from_webpbin(path: String) -> Texture2D:
	if _tex.has(path):
		var cached: Variant = _tex[path]
		return cached as Texture2D if cached is Texture2D else null
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			tex = ImageTexture.create_from_image(image)
	_tex[path] = tex
	return tex


## True when this board is showing a painted plate. Tiles then skip their
## own floor stamp and prop art. Missing rooms leave the old stamps in place.
static func bind(parent: Node2D, room_id: String, tiles: Dictionary) -> bool:
	var host := parent.get_node_or_null("PaintedRoom") as Node2D
	if room_id != "" and room_id == _bound_room and host != null and host.get_child_count() > 0:
		return true
	if room_id == "":
		_clear(host, tiles)
		return false
	var place_path := "%s%s/place.json" % [ROOT, room_id]
	if not FileAccess.file_exists(place_path):
		_clear(host, tiles)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(place_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_clear(host, tiles)
		return false
	var place: Dictionary = parsed
	_drop_other_rooms(room_id)
	if host == null:
		host = Node2D.new()
		host.name = "PaintedRoom"
		parent.add_child(host)
	else:
		for child in host.get_children():
			host.remove_child(child)
			child.free()
	parent.move_child(host, 0)
	for cell in tiles.keys():
		var tile: Node = tiles[cell]
		if tile != null and tile.has_method("set_painted_floor"):
			tile.set_painted_floor(false)
	var bg := texture_from_webpbin("%s%s/%s" % [ROOT, room_id, str(place.get("background", ""))])
	if bg != null:
		var sprite := Sprite2D.new()
		sprite.name = "Background"
		sprite.texture = bg
		sprite.centered = false
		sprite.scale = Vector2(0.5, 0.5)
		var pos: Array = place.get("position", [-610.0, -366.0])
		sprite.position = Vector2(float(pos[0]), float(pos[1]))
		sprite.z_index = int(place.get("z", -199))
		sprite.z_as_relative = true
		host.add_child(sprite)
	for raw in place.get("occluders", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var occ: Dictionary = raw
		var cell := _cell(occ.get("cell", [0, 0]))
		var tile: Node = tiles.get(cell)
		var elev := float(tile.elevation) if tile != null and "elevation" in tile else 0.0
		var tex := texture_from_webpbin("%s%s/%s" % [ROOT, room_id, str(occ.get("file", ""))])
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.scale = Vector2(0.5, 0.5)
		var off: Array = occ.get("offset", [0.0, 0.0])
		sprite.position = VISUAL_SORT.cell_to_local(cell, elev) + Vector2(float(off[0]), float(off[1])) * 0.5
		sprite.z_index = VISUAL_SORT.tile_z_index(cell, elev)
		sprite.z_as_relative = true
		host.add_child(sprite)
	var surfaced := {}
	for raw in place.get("surfaces", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var surf: Dictionary = raw
		var cell := _cell(surf.get("cell", [0, 0]))
		var tile: Node = tiles.get(cell)
		if tile == null or not tile.has_method("set_painted_floor"):
			continue
		var tex := texture_from_webpbin("%s%s/%s" % [ROOT, room_id, str(surf.get("file", ""))])
		if tex == null:
			continue
		tile.set_painted_floor(true, tex, int(surf.get("mode", 0)), float(surf.get("gain", 1.0)))
		surfaced[cell] = true
	for cell in tiles.keys():
		if surfaced.has(cell):
			continue
		var tile: Node = tiles[cell]
		if tile != null and tile.has_method("set_painted_floor"):
			tile.set_painted_floor(true)
	_bound_room = room_id
	return true


static func _clear(host: Node2D, tiles: Dictionary) -> void:
	_bound_room = ""
	if host != null and is_instance_valid(host):
		var parent_node := host.get_parent()
		if parent_node != null:
			parent_node.remove_child(host)
		host.free()
	for cell in tiles.keys():
		var tile: Node = tiles[cell]
		if tile != null and tile.has_method("set_painted_floor"):
			tile.set_painted_floor(false)


static func _drop_other_rooms(room_id: String) -> void:
	var keep := "%s%s/" % [ROOT, room_id]
	var drop: Array = []
	for key in _tex.keys():
		if not str(key).begins_with(keep):
			drop.append(key)
	for key in drop:
		_tex.erase(key)


static func _cell(raw: Variant) -> Vector2i:
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ZERO
