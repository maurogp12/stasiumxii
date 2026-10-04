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
const ATLAS_PATH := ART_ROOT + "atlas_meta.json"
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
var _terrace: Dictionary = {}
var _terrace_list: Array = []
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


## Props never block movement or line of sight. A missing field is the same
## as "none", which is what kit v1.3 writes on every prop.
static func prop_blocks(spec: Dictionary) -> String:
	var raw := str(spec.get("blocks", "none")).strip_edges().to_lower()
	if raw == "":
		return "none"
	return raw


static func load_atlas() -> Dictionary:
	return load_json(ATLAS_PATH)


## One terrace step, in @2x pixels. The kit keeps this global (20).
static func step_px_2x() -> float:
	var atlas := load_atlas()
	if atlas.has("step_px_2x"):
		return float(atlas.get("step_px_2x"))
	var terrace: Variant = atlas.get("terrace", [])
	if terrace is Dictionary and (terrace as Dictionary).has("step_px_2x"):
		return float((terrace as Dictionary).get("step_px_2x"))
	var grid: Dictionary = atlas.get("grid", {})
	return float(grid.get("step_px_2x", 20))


static func terrace_entries() -> Array:
	var terrace: Variant = load_atlas().get("terrace", [])
	if terrace is Dictionary:
		var pieces: Variant = (terrace as Dictionary).get("pieces", [])
		if pieces is Array:
			return pieces
		return []
	if terrace is Array:
		return terrace
	return []


## Canvas top-left relative to the lifted cell centre, in 1x pixels.
## offset_2x is that corner in @2x pixels.
static func terrace_origin(entry: Dictionary) -> Vector2:
	var offset: Variant = entry.get("offset_2x", null)
	if offset is Array and (offset as Array).size() >= 2:
		return Vector2(float(offset[0]), float(offset[1])) * DRAW_SCALE
	return Vector2.ZERO


## "face" draws under the top, "strip" after the overlays, "corner" last.
static func terrace_role(entry: Dictionary) -> String:
	match _field(entry, "kind").to_lower():
		"corner":
			return "corner"
		"overhang":
			return "strip"
		_:
			return "face"


## The cell the face drops onto. In this kit tile_axis x is the SW face,
## whose lower neighbour is (x, y+1). tile_axis y is the SE face, (x+1, y).
static func drop_step(entry: Dictionary) -> Vector2i:
	var axis := _field(entry, "tile_axis").to_lower()
	var edge := _field(entry, "edge").to_upper()
	if axis == "x" or edge == "SW":
		return Vector2i(0, 1)
	if axis == "y" or edge == "SE":
		return Vector2i(1, 0)
	return Vector2i.ZERO


static func edge_side(entry: Dictionary) -> String:
	var edge := _field(entry, "edge").to_upper()
	var axis := _field(entry, "tile_axis").to_lower()
	if edge == "SW" or axis == "x":
		return "left"
	if edge == "SE" or axis == "y":
		return "right"
	return ""


static func vertex_where(entry: Dictionary) -> String:
	match _field(entry, "vertex").to_upper():
		"S":
			return "front"
		"W":
			return "left"
		"E":
			return "right"
		_:
			return ""


static func height_steps(entry: Dictionary) -> int:
	var raw: Variant = entry.get("height_steps", null)
	if raw == null or not (raw is int or raw is float):
		return -1
	return int(raw)


static func _field(entry: Dictionary, key: String) -> String:
	var raw: Variant = entry.get(key, null)
	if raw == null:
		return ""
	return str(raw).strip_edges()


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
	for entry in terrace_entries():
		if entry is Dictionary:
			_note_id(seen, missing, "terrace", str(entry.get("id", "")))
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
	_terrace.clear()
	_terrace_list = terrace_entries()
	for entry in _terrace_list:
		if entry is Dictionary:
			_terrace[str(entry.get("id", ""))] = entry


func _add_cell(dress: Dress, cell: Vector2i, spec: Dictionary, size: int, tint: Color) -> void:
	var look := str(spec.get("look", ""))
	var faces: Array[String] = []
	var strips: Array[String] = []
	var corners: Array[String] = []
	for raw in spec.get("terrace", []):
		_bucket(_resolve_face(str(raw), cell), faces, strips, corners)
	if BOARD_EDGE == "earth_h2":
		for raw in _edge_ids(cell, look, size):
			_bucket(_resolve_face(raw, cell), faces, strips, corners)
	for id in faces:
		_add_terrace(dress, id, tint)
	_add_floor(dress, str(spec.get("tile", "")), tint)
	for raw in spec.get("overlays", []):
		var overlay := str(raw)
		if _shore_lip_hidden(overlay, cell):
			continue
		_add_flat(dress, overlay, "overlay", tint)
	for id in strips:
		_add_terrace(dress, id, tint)
	for id in corners:
		_add_terrace(dress, id, tint)
	for entry in _props_at.get(cell, []):
		_add_prop(dress, _prop_id(entry), "prop", cell)
	for entry in _decor_at.get(cell, []):
		if entry is Dictionary:
			_add_prop(dress, str(entry.get("id", "")), "decor", cell)
	dress.rebuild_bake()


func _bucket(id: String, faces: Array[String], strips: Array[String], corners: Array[String]) -> void:
	if id == "":
		return
	match _role_for(id):
		"corner":
			if not corners.has(id):
				corners.append(id)
		"strip":
			if not strips.has(id):
				strips.append(id)
		_:
			if not faces.has(id):
				faces.append(id)


## The front column and row take the 2-step face from the atlas, plus the
## grass lip on grass cells. The skirt variants from the mock are not ids.
func _edge_ids(cell: Vector2i, look: String, size: int) -> Array[String]:
	var out: Array[String] = []
	var front_y := cell.y == size - 1
	var front_x := cell.x == size - 1
	if front_y:
		out.append(_face_for_edge("left", 2))
		if look == "grass":
			_append_lip(out, "left")
	if front_x:
		out.append(_face_for_edge("right", 2))
		if look == "grass":
			_append_lip(out, "right")
	if front_x and front_y and look == "grass":
		var front := _corner_id("front")
		if front != "":
			out.append(front)
	return out


func _face_for_edge(side: String, steps: int) -> String:
	for entry in _terrace_list:
		if not (entry is Dictionary):
			continue
		var id := str(entry.get("id", ""))
		if id.ends_with("_water") or terrace_role(entry) != "face":
			continue
		if _field(entry, "foot") == "water":
			continue
		if height_steps(entry) == steps and edge_side(entry) == side:
			return id
	return "cliff_%s_h%d" % [side, steps]


func _append_lip(out: Array[String], side: String) -> void:
	for entry in _terrace_list:
		if not (entry is Dictionary):
			continue
		var id := str(entry.get("id", ""))
		var role := terrace_role(entry)
		if role == "strip" and edge_side(entry) == side:
			out.append(id)
		elif role == "corner" and vertex_where(entry) == side:
			out.append(id)


func _corner_id(where: String) -> String:
	for entry in _terrace_list:
		if entry is Dictionary and terrace_role(entry) == "corner" and vertex_where(entry) == where:
			return str(entry.get("id", ""))
	return ""


## A ground foot becomes the water-foot face when the lower neighbour is water.
## looks.json still names the dry id. The atlas foot field picks the variant.
func _resolve_face(id: String, cell: Vector2i) -> String:
	if id == "" or _role_for(id) != "face":
		return id
	var entry := _entry_for(id)
	if entry.is_empty() or _field(entry, "foot") == "water":
		return id
	var step := drop_step(entry)
	if step == Vector2i.ZERO or not _is_water(cell + step):
		return id
	var wet := _water_face(entry)
	if wet == "" or piece_path("terrace", wet) == "":
		return id
	return wet


func _water_face(entry: Dictionary) -> String:
	var direct := str(entry.get("id", "")) + "_water"
	if _terrace.has(direct):
		return direct
	var edge := _field(entry, "edge").to_upper()
	var steps := height_steps(entry)
	for other in _terrace_list:
		if not (other is Dictionary):
			continue
		if terrace_role(other) != "face" or _field(other, "foot") != "water":
			continue
		if _field(other, "edge").to_upper() == edge and height_steps(other) == steps:
			return str(other.get("id", ""))
	return ""


## The water face is the shore. The stone lip on that edge of the water cell
## would sit in front of the foam, so it stays off. SW skips water_edge_ne.
## SE skips water_edge_nw.
func _shore_lip_hidden(overlay: String, cell: Vector2i) -> bool:
	if overlay == "water_edge_ne" and _water_face_above(cell + Vector2i(0, -1), "SW", cell):
		return true
	if overlay == "water_edge_nw" and _water_face_above(cell + Vector2i(-1, 0), "SE", cell):
		return true
	return false


func _water_face_above(upper: Vector2i, edge: String, here: Vector2i) -> bool:
	var spec: Dictionary = _by_cell.get(upper, {})
	if spec.is_empty() or not _is_water(here):
		return false
	for raw in spec.get("terrace", []):
		var entry := _entry_for(str(raw))
		if entry.is_empty() or terrace_role(entry) != "face":
			continue
		if _field(entry, "edge").to_upper() != edge:
			continue
		if upper + drop_step(entry) == here:
			return true
	return false


func _is_water(cell: Vector2i) -> bool:
	var spec: Dictionary = _by_cell.get(cell, {})
	if spec.is_empty():
		return false
	var look := str(spec.get("look", "")).to_lower()
	var terrain := str(spec.get("terrain", "")).to_lower()
	var tile := str(spec.get("tile", "")).to_lower()
	return look == "water" or terrain == "water" or tile.begins_with("water_")


func _role_for(id: String) -> String:
	var entry := _entry_for(id)
	if entry.is_empty():
		return "face"
	return terrace_role(entry)


func _entry_for(id: String) -> Dictionary:
	if _terrace.has(id):
		return _terrace[id]
	if id.ends_with("_water"):
		var dry := id.trim_suffix("_water")
		if _terrace.has(dry):
			return _terrace[dry]
	return {}


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
	var entry := _entry_for(id)
	var origin := terrace_origin(entry) if not entry.is_empty() else Vector2(-32, -16)
	dress.add_piece(id, _role_for(id), tex, Rect2(origin, tex.get_size() * scale), tint, true)


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


class Dress extends Node2D:
	## One composited image per texture, size, and tint. Cells share these.
	static var _stamp_cache: Dictionary = {}

	var _pieces: Array = []
	var _baked: Texture2D
	var _baked_origin := Vector2.ZERO

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
			rebuild_bake()

	## The live frame blits one image. The piece list stays for the tests.
	func rebuild_bake() -> void:
		_baked = null
		if _pieces.is_empty():
			queue_redraw()
			return
		var bounds: Rect2 = _pieces[0].get("dest", Rect2())
		for piece in _pieces:
			bounds = bounds.merge(piece.get("dest", Rect2()))
		var origin := Vector2(floor(bounds.position.x), floor(bounds.position.y))
		var end := Vector2(ceil(bounds.end.x), ceil(bounds.end.y))
		var size := Vector2i(maxi(1, int(end.x - origin.x)), maxi(1, int(end.y - origin.y)))
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var painted := false
		for piece in _pieces:
			var tex: Texture2D = piece.get("tex")
			if tex == null:
				continue
			var dest: Rect2 = piece.get("dest", Rect2())
			var stamp := _stamp(tex, dest.size, piece.get("tint", Color.WHITE))
			if stamp == null:
				continue
			var at := Vector2i(Vector2(round(dest.position.x - origin.x), round(dest.position.y - origin.y)))
			image.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), at)
			painted = true
		if not painted:
			queue_redraw()
			return
		_baked = ImageTexture.create_from_image(image)
		_baked_origin = origin
		queue_redraw()

	static func _stamp(tex: Texture2D, dest_size: Vector2, tint: Color) -> Image:
		var dw := maxi(1, int(round(dest_size.x)))
		var dh := maxi(1, int(round(dest_size.y)))
		var key := "%s|%d|%d|%d|%d|%d|%d" % [
			tex.resource_path,
			dw, dh,
			int(round(tint.r * 255.0)), int(round(tint.g * 255.0)),
			int(round(tint.b * 255.0)), int(round(tint.a * 255.0)),
		]
		if _stamp_cache.has(key):
			return _stamp_cache[key]
		var src := tex.get_image()
		if src == null:
			return null
		src = src.duplicate()
		if src.get_format() != Image.FORMAT_RGBA8:
			src.convert(Image.FORMAT_RGBA8)
		var sw := src.get_width()
		var sh := src.get_height()
		var out: Image
		if sw == dw * 2 and sh == dh * 2:
			out = _box_half(src, dw, dh, tint)
		else:
			if sw != dw or sh != dh:
				src.resize(dw, dh, Image.INTERPOLATE_BILINEAR)
			out = _tint_image(src, tint)
		_stamp_cache[key] = out
		return out

	static func _box_half(src: Image, dw: int, dh: int, tint: Color) -> Image:
		var raw := src.get_data()
		var sw := dw * 2
		var out := PackedByteArray()
		out.resize(dw * dh * 4)
		var tr := tint.r
		var tg := tint.g
		var tb := tint.b
		var ta := tint.a
		var white := tint.is_equal_approx(Color.WHITE)
		var i := 0
		for y in dh:
			var row0 := (y * 2) * sw * 4
			var row1 := row0 + sw * 4
			for x in dw:
				var p := (x * 2) * 4
				var a0 := row0 + p
				var b0 := row1 + p
				var r := (int(raw[a0]) + int(raw[a0 + 4]) + int(raw[b0]) + int(raw[b0 + 4])) >> 2
				var g := (int(raw[a0 + 1]) + int(raw[a0 + 5]) + int(raw[b0 + 1]) + int(raw[b0 + 5])) >> 2
				var b := (int(raw[a0 + 2]) + int(raw[a0 + 6]) + int(raw[b0 + 2]) + int(raw[b0 + 6])) >> 2
				var a := (int(raw[a0 + 3]) + int(raw[a0 + 7]) + int(raw[b0 + 3]) + int(raw[b0 + 7])) >> 2
				if not white:
					r = int(float(r) * tr)
					g = int(float(g) * tg)
					b = int(float(b) * tb)
					a = int(float(a) * ta)
				out[i] = r
				out[i + 1] = g
				out[i + 2] = b
				out[i + 3] = a
				i += 4
		return Image.create_from_data(dw, dh, false, Image.FORMAT_RGBA8, out)

	static func _tint_image(src: Image, tint: Color) -> Image:
		if tint.is_equal_approx(Color.WHITE):
			return src
		var raw := src.get_data()
		var out := PackedByteArray()
		out.resize(raw.size())
		var tr := tint.r
		var tg := tint.g
		var tb := tint.b
		var ta := tint.a
		var i := 0
		while i < raw.size():
			out[i] = int(float(raw[i]) * tr)
			out[i + 1] = int(float(raw[i + 1]) * tg)
			out[i + 2] = int(float(raw[i + 2]) * tb)
			out[i + 3] = int(float(raw[i + 3]) * ta)
			i += 4
		return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8, out)

	func _draw() -> void:
		if _baked != null:
			draw_texture(_baked, _baked_origin)
			return
		for piece in _pieces:
			var tex: Texture2D = piece.get("tex")
			if tex == null:
				continue
			draw_texture_rect(tex, piece.get("dest", Rect2()), false, piece.get("tint", Color.WHITE))
