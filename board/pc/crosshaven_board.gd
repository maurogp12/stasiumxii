extends Node2D

## View-only Crosshaven combat board (map crosshaven_15). PC only.
## Reads art/pc/look/crosshaven_board/looks.json and draws the @2x masters
## at half scale. Stock terrain and paint_only props stay hidden the same
## way a Thunderwell floor hides them. CombatSim, the grid, and the shared
## tiles stay as they are.
## Luca, 3 Oct 2026, locked the four open calls:
## the kit's 2-step earth edge, tall stones under the fighter with no fade,
## no decor on raised cells, and the 2-cell wall and log only where looks.json
## already placed them.

const ART_ROOT := "res://art/pc/look/crosshaven_board/"
const LOOKS_PATH := ART_ROOT + "looks.json"
const CATALOG_PATH := ART_ROOT + "props/props.json"
const DRAW_SCALE := 0.5
const MAP_ID := "crosshaven_15"
const HUD := preload("res://ui/hud.gd")
const THUNDERWELL := preload("res://board/pc/thunderwell_floor.gd")
const SORT := preload("res://board/visual_sort.gd")

## Kit earth edge on the front column and row. "off" leaves the jungle lip.
const BOARD_EDGE := "earth_h2"
## Tall stones paint with the cell, under a fighter, and do not fade.
const TALL_UNDER_FIGHTER := true
const TALL_FADE := false
## Raised cells stay clean. looks.json v1.1 already omits them.
const DECOR_ON_RAISED := false
## "fences" keeps the 2-cell ids looks.json wrote. "off" uses the 1-cell shorts.
const TWO_CELL_COVER := "fences"

static var suppressed := false

var _board: Node2D
var _ready_data := false
var _by_cell: Dictionary = {}
var _props_at: Dictionary = {}
var _decor_at: Dictionary = {}
var _catalog: Dictionary = {}
var _tex: Dictionary = {}
var _built_for := -1


static func set_suppressed(on: bool) -> void:
	suppressed = on


static func board_edge() -> String:
	return BOARD_EDGE


static func tall_under_fighter() -> bool:
	return TALL_UNDER_FIGHTER


static func tall_fade() -> bool:
	return TALL_FADE


static func decor_on_raised() -> bool:
	return DECOR_ON_RAISED


static func two_cell_cover() -> String:
	return TWO_CELL_COVER


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func load_looks() -> Dictionary:
	return load_json(LOOKS_PATH)


static func load_catalog() -> Array:
	var parsed := load_json(CATALOG_PATH)
	var props: Variant = parsed.get("props", [])
	if props is Array:
		return props
	return []


static func piece_path(folder: String, id: String) -> String:
	var root := ART_ROOT + folder + "/"
	var hi := root + id + "@2x.png"
	if FileAccess.file_exists(hi):
		return hi
	var lo := root + id + ".png"
	if FileAccess.file_exists(lo):
		return lo
	return ""


static func draw_scale_for(path: String) -> float:
	if path.ends_with("@2x.png"):
		return DRAW_SCALE
	return 1.0


static func applies_to(snap: Dictionary) -> bool:
	if suppressed or not HUD.uses_pc_chrome():
		return false
	if str(THUNDERWELL.requested_theme) == THUNDERWELL.THEME_ID:
		return false
	var id := str(snap.get("map_id", ""))
	if id == "":
		id = str(snap.get("demo_map", ""))
	id = id.strip_edges().to_lower()
	return id == MAP_ID or id == "crosshaven"


static func unresolved_ids() -> PackedStringArray:
	var missing := PackedStringArray()
	var looks := load_looks()
	var seen := {}
	for cell in looks.get("cells", []):
		if not (cell is Dictionary):
			continue
		_note_id(seen, missing, "tiles", str(cell.get("tile", "")))
		for raw in cell.get("overlays", []):
			_note_id(seen, missing, "tiles", str(raw))
		for raw in cell.get("terrace", []):
			_note_id(seen, missing, "terrace", str(raw))
	for entry in looks.get("props", []):
		if entry is Dictionary:
			_note_id(seen, missing, _folder_for_prop(str(entry.get("new_id", ""))), str(entry.get("new_id", "")))
	for entry in looks.get("decor", []):
		if entry is Dictionary:
			_note_id(seen, missing, "props", str(entry.get("id", "")))
	for edge_id in ["cliff_left_h2", "cliff_right_h2", "grass_overhang_left", "grass_overhang_right", "grass_overhang_corner_left", "grass_overhang_corner_right", "grass_overhang_corner_front"]:
		_note_id(seen, missing, "terrace", edge_id)
	return missing


static func _folder_for_prop(id: String) -> String:
	if id == "seal_slab":
		return "tiles"
	return "props"


static func _note_id(seen: Dictionary, missing: PackedStringArray, folder: String, id: String) -> void:
	if id == "" or seen.has(id):
		return
	seen[id] = true
	if piece_path(folder, id) == "":
		missing.append(id)


func sync_board(board: Node2D, snap: Dictionary) -> void:
	_board = board
	var want := applies_to(snap)
	_set_jungle_edge(want and BOARD_EDGE == "earth_h2")
	if not want:
		_clear()
		return
	if _matches(board):
		return
	_build(board)


func dressed_count() -> int:
	if _board == null:
		return 0
	var count := 0
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		if tile.get_node_or_null("CrosshavenDress") != null and tile.has_method("hide_stock") and tile.hide_stock():
			count += 1
	return count


func _set_jungle_edge(on: bool) -> void:
	if _board == null:
		return
	var jungle := _board.get_node_or_null("JungleBackdrop")
	if jungle != null and jungle.has_method("set_kit_edge"):
		jungle.set_kit_edge(on)


func _matches(board: Node2D) -> bool:
	if board.tiles.size() != _built_for or board.tiles.is_empty():
		return false
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		if tile.get_node_or_null("CrosshavenDress") == null:
			return false
		if not tile.has_method("hide_stock") or not tile.hide_stock():
			return false
	return true


func _clear() -> void:
	_built_for = -1
	if _board == null:
		return
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		var dress := tile.get_node_or_null("CrosshavenDress")
		if dress != null:
			tile.remove_child(dress)
			dress.free()
		if tile.has_method("set_hide_stock"):
			tile.set_hide_stock(false)


func _build(board: Node2D) -> void:
	_clear()
	_ensure_data()
	var size := 15
	if "_board_size" in board:
		size = int(board.get("_board_size"))
	for key in board.tiles.keys():
		var cell := key as Vector2i
		var tile: Node = board.tiles[cell]
		var spec: Dictionary = _by_cell.get(cell, {})
		if spec.is_empty():
			continue
		var dress := Dress.new()
		dress.name = "CrosshavenDress"
		dress.z_as_relative = true
		dress.z_index = 0
		dress.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var tint: Color = tile.canopy_tint if "canopy_tint" in tile else Color.WHITE
		_add_cell(dress, cell, spec, size, tint)
		tile.add_child(dress)
		if tile.has_method("set_hide_stock"):
			tile.set_hide_stock(true)
	_built_for = board.tiles.size()


func _ensure_data() -> void:
	if _ready_data:
		return
	_ready_data = true
	var looks := load_looks()
	for cell in looks.get("cells", []):
		if cell is Dictionary:
			_by_cell[Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))] = cell
	for entry in looks.get("props", []):
		if not (entry is Dictionary):
			continue
		if str(entry.get("layer", "")) != "prop":
			continue
		var at := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if not _props_at.has(at):
			_props_at[at] = []
		(_props_at[at] as Array).append(entry)
	for entry in looks.get("decor", []):
		if not (entry is Dictionary):
			continue
		if not DECOR_ON_RAISED and int(entry.get("height", 0)) > 0:
			continue
		var at := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if not _decor_at.has(at):
			_decor_at[at] = []
		(_decor_at[at] as Array).append(entry)
	for item in load_catalog():
		if item is Dictionary:
			_catalog[str(item.get("id", ""))] = item


func _add_cell(dress: Dress, cell: Vector2i, spec: Dictionary, size: int, tint: Color) -> void:
	var look := str(spec.get("look", ""))
	var faces: Array[String] = []
	var strips: Array[String] = []
	var corners: Array[String] = []
	for raw in spec.get("terrace", []):
		_bucket(str(raw), faces, strips, corners)
	if BOARD_EDGE == "earth_h2":
		for raw in _edge_ids(cell, look, size):
			_bucket(raw, faces, strips, corners)
	for id in faces:
		_add_terrace(dress, id, tint)
	_add_floor(dress, str(spec.get("tile", "")), tint)
	for raw in spec.get("overlays", []):
		_add_flat(dress, str(raw), "overlay", tint)
	for id in strips:
		_add_terrace(dress, id, tint)
	for id in corners:
		_add_terrace(dress, id, tint)
	for entry in _props_at.get(cell, []):
		_add_prop(dress, _prop_id(entry), "prop", cell)
	for entry in _decor_at.get(cell, []):
		if entry is Dictionary:
			_add_prop(dress, str(entry.get("id", "")), "decor", cell)


func _bucket(id: String, faces: Array[String], strips: Array[String], corners: Array[String]) -> void:
	if id == "":
		return
	if id.begins_with("grass_overhang_corner"):
		if not corners.has(id):
			corners.append(id)
	elif id.begins_with("grass_overhang"):
		if not strips.has(id):
			strips.append(id)
	elif id.begins_with("cliff_"):
		if not faces.has(id):
			faces.append(id)


func _edge_ids(cell: Vector2i, look: String, size: int) -> Array[String]:
	var out: Array[String] = []
	var front_y := cell.y == size - 1
	var front_x := cell.x == size - 1
	if front_y:
		out.append("cliff_left_h2")
		if look == "grass":
			out.append("grass_overhang_left")
			out.append("grass_overhang_corner_left")
	if front_x:
		out.append("cliff_right_h2")
		if look == "grass":
			out.append("grass_overhang_right")
			out.append("grass_overhang_corner_right")
	if front_x and front_y and look == "grass":
		out.append("grass_overhang_corner_front")
	return out


func _prop_id(entry: Dictionary) -> String:
	var id := str(entry.get("new_id", ""))
	if TWO_CELL_COVER == "off":
		if id == "ruined_wall_2c":
			return "ruined_wall_short"
		if id == "fallen_log_2c":
			return "fallen_log_short"
	return id


func _add_floor(dress: Dress, id: String, tint: Color) -> void:
	var path := piece_path("tiles", id)
	var tex := _texture(path)
	if tex == null:
		return
	var scale := draw_scale_for(path)
	var size := tex.get_size() * scale
	dress.add_piece(id, "floor", tex, Rect2(-size * 0.5, size), tint, true)


func _add_flat(dress: Dress, id: String, role: String, tint: Color) -> void:
	var path := piece_path("tiles", id)
	var tex := _texture(path)
	if tex == null:
		return
	var scale := draw_scale_for(path)
	var size := tex.get_size() * scale
	dress.add_piece(id, role, tex, Rect2(-size * 0.5, size), tint, true)


func _add_terrace(dress: Dress, id: String, tint: Color) -> void:
	var path := piece_path("terrace", id)
	var tex := _texture(path)
	if tex == null:
		return
	var scale := draw_scale_for(path)
	var origin := _top_left(id)
	dress.add_piece(id, _terrace_role(id), tex, Rect2(origin, tex.get_size() * scale), tint, true)


func _add_prop(dress: Dress, id: String, role: String, cell: Vector2i) -> void:
	var spec: Dictionary = _catalog.get(id, {})
	var path := piece_path("props", id)
	var tex := _texture(path)
	if tex == null:
		return
	var master := path.ends_with("@2x.png")
	var scale := draw_scale_for(path)
	var anchor := _anchor_px(spec, master, tex)
	var origin := Vector2(0.0, float(BoardTile.TILE_HEIGHT) * 0.5) - anchor * scale
	var tint := Color(1, 1, 1, _prop_alpha(spec, cell))
	dress.add_piece(id, role, tex, Rect2(origin, tex.get_size() * scale), tint, false)


func _prop_alpha(spec: Dictionary, cell: Vector2i) -> float:
	if not TALL_FADE or str(spec.get("kind", "")) != "tall":
		return 1.0
	if _fighter_on(cell):
		return 0.28
	return 1.0


func _fighter_on(cell: Vector2i) -> bool:
	if _board == null or not ("pawns_by_seat" in _board):
		return false
	var pawns: Variant = _board.get("pawns_by_seat")
	if not (pawns is Dictionary):
		return false
	for pawn in (pawns as Dictionary).values():
		if pawn is Node and "grid_position" in pawn and (pawn as Node).get("grid_position") == cell:
			return true
	return false


func _anchor_px(spec: Dictionary, master: bool, tex: Texture2D) -> Vector2:
	var key := "anchor_px_2x" if master else "anchor_px_1x"
	var raw: Variant = spec.get(key, [])
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2(tex.get_size()) * 0.5


func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex.has(path):
		return _tex[path]
	var tex := load(path) as Texture2D
	_tex[path] = tex
	return tex


static func _terrace_role(id: String) -> String:
	if id.begins_with("grass_overhang_corner"):
		return "corner"
	if id.begins_with("grass_overhang"):
		return "strip"
	return "face"


static func _top_left(id: String) -> Vector2:
	if id.begins_with("cliff_left"):
		return Vector2(-32, 0)
	if id.begins_with("cliff_right"):
		return Vector2(0, 0)
	if id == "grass_overhang_left":
		return Vector2(-32, -4)
	if id == "grass_overhang_right":
		return Vector2(0, -4)
	if id == "grass_overhang_corner_left":
		return Vector2(-42, -6)
	if id == "grass_overhang_corner_right":
		return Vector2(22, -6)
	if id == "grass_overhang_corner_front":
		return Vector2(-10, 10)
	return Vector2(-32, -16)


class Dress extends Node2D:
	var _pieces: Array = []

	func add_piece(id: String, role: String, tex: Texture2D, dest: Rect2, tint: Color, canopy: bool) -> void:
		_pieces.append({
			"id": id,
			"role": role,
			"tex": tex,
			"dest": dest,
			"tint": tint,
			"canopy": canopy,
		})
		queue_redraw()

	func piece_ids() -> PackedStringArray:
		var out := PackedStringArray()
		for piece in _pieces:
			out.append(str(piece.get("id", "")))
		return out

	func piece(id: String) -> Dictionary:
		for item in _pieces:
			if str(item.get("id", "")) == id:
				return item
		return {}

	func set_canopy_tint(tint: Color) -> void:
		var changed := false
		for piece in _pieces:
			if not bool(piece.get("canopy", false)):
				continue
			var next := tint
			next.a = (piece.get("tint", Color.WHITE) as Color).a
			if not (piece.get("tint", Color.WHITE) as Color).is_equal_approx(next):
				piece["tint"] = next
				changed = true
		if changed:
			queue_redraw()

	func _draw() -> void:
		for piece in _pieces:
			var tex: Texture2D = piece.get("tex")
			if tex == null:
				continue
			draw_texture_rect(tex, piece.get("dest", Rect2()), false, piece.get("tint", Color.WHITE))
