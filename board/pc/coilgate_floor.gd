extends Node2D

## View-only Coilgate / Stormspire floor. Dark circuit plates, glowing pads,
## cyan pillars on key cells, and a quiet room that fades to black around the
## board. CombatSim, the grid and the tile records stay as they are.
## Art: res://art/pc/look/coilgate_floor/ (@2x first). Params: coilgate_floor.json.
## Dungeon runs are not part of this layer. A preview calls request_theme.

const PARAMS_PATH := "res://data/pc/look/coilgate_floor.json"
const DEFAULT_ROOT := "res://art/pc/look/coilgate_floor/"
const THEME_ID := "coilgate"

static var requested_theme: String = ""

var _params: Dictionary = {}
var _board: Node2D
var _built_for: int = -1
var _time: float = 0.0
var _room: Sprite2D
var _pillars: Array[Node2D] = []


static func request_theme(theme_id: String) -> void:
	requested_theme = theme_id.strip_edges().to_lower()


static func load_params() -> Dictionary:
	var text := FileAccess.get_file_as_string(PARAMS_PATH)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func art_root() -> String:
	var params := load_params()
	var root := str(params.get("art_root", DEFAULT_ROOT))
	if not root.ends_with("/"):
		root += "/"
	return root


static func choose_path(root: String, slot: String) -> String:
	var hi := root + slot + "@2x.png"
	if ResourceLoader.exists(hi):
		return hi
	var lo := root + slot + ".png"
	if ResourceLoader.exists(lo):
		return lo
	return ""


static func resolve_slot(slot: String) -> String:
	return choose_path(art_root(), slot)


static func slot_path_1x(slot: String) -> String:
	return art_root() + slot + ".png"


func _ready() -> void:
	_ensure_params()


func sync_board(board: Node2D, snap: Dictionary) -> void:
	_board = board
	_ensure_params()
	if requested_theme != THEME_ID:
		_clear()
		visible = false
		return
	visible = true
	_ensure_room()
	if not _floors_match(board):
		_build(board, snap)
	else:
		_place_pillars()
	_layout_room()
	_apply_pulse()


func preview_time(t: float) -> void:
	_time = t
	_apply_pulse()


func floor_pulse() -> float:
	return _pulse_value()


func room_z() -> int:
	if _room == null:
		return 0
	return _room.z_index


func room_is_behind() -> bool:
	return _room != null and not _room.z_as_relative and _room.z_index < 0


func pillar_count() -> int:
	return _pillars.size()


func pillar_display_width() -> float:
	if _pillars.is_empty():
		return 0.0
	var sprite := _pillars[0] as Sprite2D
	if sprite.texture == null:
		return 0.0
	return sprite.texture.get_width() * absf(sprite.scale.x)


func themed_cell_count() -> int:
	if _board == null:
		return 0
	var count := 0
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		if tile.has_method("look_floor") and tile.look_floor() != null:
			count += 1
	return count


func _process(delta: float) -> void:
	if not visible or _board == null:
		return
	_time += delta
	_layout_room()
	_apply_pulse()


func _ensure_params() -> void:
	if not _params.is_empty():
		return
	_params = load_params()


func _ensure_room() -> void:
	if _room != null and is_instance_valid(_room):
		return
	_room = Sprite2D.new()
	_room.name = "RoomEdge"
	_room.centered = true
	_room.z_as_relative = false
	_room.z_index = _z("room")
	_room.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_room.texture = _texture("room_edge_dark")
	add_child(_room)


func _build(board: Node2D, snap: Dictionary) -> void:
	_clear_cell_dressing()
	var cycle: Array = _params.get("floor_cycle", [])
	var paint: Dictionary = snap.get("paint_only", {})
	var use_paint := bool(_params.get("special_from_paint", true))
	var pillars := _pillar_set()
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		var slot := _floor_slot(cell, cycle)
		var tex := _texture(slot)
		if tile.has_method("set_look_floor"):
			tile.set_look_floor(tex)
		if _is_pad(cell, _params.get("pad_blue", {})) and not pillars.has(cell):
			_add_pad(tile, "pad_blue", Color(0.45, 0.85, 1.0))
		elif _is_pad(cell, _params.get("pad_red", {})) and not pillars.has(cell):
			_add_pad(tile, "pad_red", Color(1.0, 0.45, 0.4))
		if use_paint and not _props_at(paint, cell).is_empty():
			_add_glow(tile)
	_spawn_pillars(board)
	_built_for = board.tiles.size()


func _floors_match(board: Node2D) -> bool:
	if board.tiles.size() != _built_for or board.tiles.is_empty():
		return false
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		if not tile.has_method("look_floor") or tile.look_floor() == null:
			return false
	return true


func _clear() -> void:
	_clear_cell_dressing()
	_free_pillars()
	_built_for = -1
	if _room != null:
		_room.visible = false


func _clear_cell_dressing() -> void:
	if _board == null:
		return
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		if tile.has_method("clear_look_floor"):
			tile.clear_look_floor()
		for child_name in ["CoilPad", "CoilGlow"]:
			var child := tile.get_node_or_null(child_name)
			if child == null:
				continue
			tile.remove_child(child)
			child.free()
	_free_pillars()
	_built_for = -1


func _add_pad(tile: Node, slot: String, tint: Color) -> void:
	var tex := _texture(slot)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "CoilPad"
	sprite.centered = true
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(48.0 / tex.get_width(), 48.0 / tex.get_width())
	sprite.modulate = tint
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	sprite.z_as_relative = true
	sprite.z_index = _z("pad")
	tile.add_child(sprite)


func _add_glow(tile: Node) -> void:
	var tex := _texture("glow_mask")
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "CoilGlow"
	sprite.centered = true
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(56.0 / tex.get_width(), 56.0 / tex.get_width())
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	sprite.z_as_relative = true
	sprite.z_index = _z("glow")
	tile.add_child(sprite)


func _spawn_pillars(board: Node2D) -> void:
	_free_pillars()
	var tex := _texture("light_pillar")
	if tex == null:
		return
	var scale := 1.0
	var path := resolve_slot("light_pillar")
	if path.ends_with("@2x.png"):
		scale = 0.5
	for cell in _pillar_list():
		if not board.tiles.has(cell):
			continue
		var sprite := Sprite2D.new()
		sprite.name = "CoilPillar"
		sprite.centered = true
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2(scale, scale)
		sprite.z_as_relative = false
		sprite.z_index = _z("pillar")
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat
		sprite.set_meta("cell", cell)
		add_child(sprite)
		_pillars.append(sprite)
	_place_pillars()


func _place_pillars() -> void:
	if _board == null:
		return
	for sprite in _pillars:
		if sprite == null or not is_instance_valid(sprite):
			continue
		var cell: Vector2i = sprite.get_meta("cell")
		if not _board.tiles.has(cell):
			continue
		var tile: Node2D = _board.tiles[cell]
		var shown: float = float(sprite.texture.get_height()) * absf(sprite.scale.y)
		sprite.position = tile.position + Vector2(0, -shown * 0.5 + 10.0)


func _layout_room() -> void:
	if _room == null or _room.texture == null or _board == null:
		return
	var cam := _board.get_node_or_null("BoardCamera") as Camera2D
	if cam == null:
		return
	_room.visible = visible
	var view := _board.get_viewport_rect().size
	if view.x < 32.0 or view.y < 32.0:
		view = Vector2(960, 720)
	var zoom := cam.zoom
	if zoom.x < 0.01:
		zoom = Vector2.ONE
	var world := Vector2(view.x / zoom.x, view.y / zoom.y)
	_room.position = cam.position
	var tex_size := _room.texture.get_size()
	var cover := world * 1.2
	var scale := maxf(cover.x / tex_size.x, cover.y / tex_size.y)
	_room.scale = Vector2(scale, scale)


func _apply_pulse() -> void:
	if _board == null:
		return
	var glow := _pulse_value()
	var wave := _pulse_wave()
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		if tile.has_method("set_look_pulse"):
			tile.set_look_pulse(glow)
		var pad := tile.get_node_or_null("CoilPad") as CanvasItem
		if pad != null:
			pad.modulate.a = 0.62 + 0.38 * wave
		var mask := tile.get_node_or_null("CoilGlow") as CanvasItem
		if mask != null:
			mask.modulate.a = 0.55 + 0.45 * wave
	for sprite in _pillars:
		if sprite == null or not is_instance_valid(sprite):
			continue
		sprite.modulate.a = 0.55 + 0.45 * wave


func _pulse_wave() -> float:
	var hz := float(_params.get("pulse_hz", 0.22))
	return 0.5 + 0.5 * sin(_time * TAU * hz)


func _pulse_value() -> float:
	var amount := float(_params.get("pulse_amount", 0.16))
	return 1.0 - amount + amount * _pulse_wave()


func _floor_slot(cell: Vector2i, cycle: Array) -> String:
	if cycle.is_empty():
		return "floor_tile_a"
	var index := posmod(cell.x + cell.y * 2, cycle.size())
	return str(cycle[index])


func _is_pad(cell: Vector2i, spec: Variant) -> bool:
	if typeof(spec) != TYPE_DICTIONARY:
		return false
	var step_x := int(spec.get("step_x", 0))
	var step_y := int(spec.get("step_y", 0))
	if step_x < 1 or step_y < 1:
		return false
	var phase_x := int(spec.get("phase_x", 0))
	var phase_y := int(spec.get("phase_y", 0))
	return posmod(cell.x - phase_x, step_x) == 0 and posmod(cell.y - phase_y, step_y) == 0


func _pillar_list() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var raw: Variant = _params.get("pillar_cells", [])
	if raw is Array:
		for item in raw:
			if item is Array and item.size() >= 2:
				out.append(Vector2i(int(item[0]), int(item[1])))
	return out


func _pillar_set() -> Dictionary:
	var found := {}
	for cell in _pillar_list():
		found[cell] = true
	return found


func _props_at(paint: Dictionary, cell: Vector2i) -> Array:
	if paint.has(cell) and paint[cell] is Array:
		return paint[cell]
	var key := "%d,%d" % [cell.x, cell.y]
	if paint.has(key) and paint[key] is Array:
		return paint[key]
	return []


func _free_pillars() -> void:
	for sprite in _pillars:
		if sprite != null and is_instance_valid(sprite):
			if sprite.get_parent() != null:
				sprite.get_parent().remove_child(sprite)
			sprite.free()
	_pillars.clear()


func _z(key: String) -> int:
	var table: Dictionary = _params.get("z_order", {})
	return int(table.get(key, 0))


func _texture(slot: String) -> Texture2D:
	var path := resolve_slot(slot)
	if path == "":
		return null
	return load(path) as Texture2D
