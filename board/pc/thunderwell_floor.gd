extends Node2D

## View-only Thunderwell Core floor. Theme id thunderwell.
## Dark circuit plates, a glow tint on the traces, pillars tinted pale, pads
## left in their painted hue, and a dark gradient around a hole generated from
## the cell footprint. CombatSim, the grid and the tile records stay as they are.
## Art: res://art/pc/look/thunderwell_floor/. Params: thunderwell_floor.json.
## glow_mask is painted across 0–1. glow_strength, pad_strength and
## pillar_strength are the shader caps. glow_color tints the traces. A preview
## calls request_theme. 2D HDR and the glow environment stay on that preview.

const PARAMS_PATH := "res://data/pc/look/thunderwell_floor.json"
const DEFAULT_ROOT := "res://art/pc/look/thunderwell_floor/"
const THEME_ID := "thunderwell"
const GLOW_SLICES := 4
const GLOW_SHADER := """shader_type canvas_item;
render_mode blend_add;
// glow_mask.png is RGB. R is glow intensity. G is the flow gradient along the traces.
uniform float phase = 0.0;
uniform float pulse_hz = 0.22;
uniform float flow_speed = 0.35;
uniform float glow_strength = 0.08;
uniform vec3 glow_color = vec3(0.220, 0.900, 0.447);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float intensity = tex.r;
	float flow = tex.g;
	float pulse = 0.62 + 0.38 * sin(TIME * TAU * pulse_hz + phase);
	float along = fract(flow - TIME * flow_speed);
	float energy = smoothstep(0.16, 0.0, abs(along - 0.12));
	float glow = min(intensity * (0.55 * pulse + energy), glow_strength);
	float peak = max(max(glow_color.r, glow_color.g), max(glow_color.b, 0.001));
	vec3 hue = glow_color / peak;
	COLOR = vec4(hue * glow, glow);
}
"""
const PAD_SHADER := """shader_type canvas_item;
render_mode blend_add;
// Pad hue stays in the painted art. pad_strength only scales that paint.
uniform float pad_strength = 0.22;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb * pad_strength, tex.a * pad_strength);
}
"""
const PILLAR_SHADER := """shader_type canvas_item;
render_mode blend_add;
uniform float pillar_strength = 0.10;
uniform vec3 pillar_color = vec3(0.780, 0.920, 0.827);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float ink = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722)) * tex.a;
	float glow = min(ink, pillar_strength);
	float peak = max(max(pillar_color.r, pillar_color.g), max(pillar_color.b, 0.001));
	vec3 hue = pillar_color / peak;
	COLOR = vec4(hue * glow, glow);
}
"""
const ROOM_SHADER := """shader_type canvas_item;
uniform sampler2D hole_mask : filter_linear, repeat_disable;
void fragment() {
	vec4 grad = texture(TEXTURE, UV);
	float room = texture(hole_mask, UV).r;
	COLOR = vec4(grad.rgb, grad.a * room);
}
"""

static var requested_theme: String = ""
static var preview_bloom: bool = false

var _params: Dictionary = {}
var _board: Node2D
var _built_for: int = -1
var _time: float = 0.0
var _room: Sprite2D
var _pillars: Array[Node2D] = []
var _glow_shader: Shader
var _pad_shader: Shader
var _pillar_shader: Shader
var _room_shader: Shader
var _hole_tex: ImageTexture
var _mask_key: String = ""


static func request_theme(theme_id: String) -> void:
	requested_theme = theme_id.strip_edges().to_lower()


static func glow_color() -> Color:
	return _json_color("glow_color", Color(0.220, 0.900, 0.447))


static func glow_strength() -> float:
	return _json_float("glow_strength", 0.08)


static func pillar_color() -> Color:
	return _json_color("pillar_color", Color(0.780, 0.920, 0.827))


static func pillar_strength() -> float:
	return _json_float("pillar_strength", 0.10)


static func pad_strength() -> float:
	return _json_float("pad_strength", 0.22)


static func pad_blue_color() -> Color:
	return _json_color("pad_blue_color", Color(0.083, 0.199, 0.550))


static func pad_red_color() -> Color:
	return _json_color("pad_red_color", Color(0.620, 0.112, 0.197))


static func _json_color(key: String, fallback: Color) -> Color:
	var raw: Variant = load_params().get(key, [])
	if raw is Array and (raw as Array).size() >= 3:
		return Color(float(raw[0]), float(raw[1]), float(raw[2]))
	return fallback


static func _json_float(key: String, fallback: float) -> float:
	var params := load_params()
	if not params.has(key):
		return fallback
	return float(params[key])


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


func room_texture_size() -> Vector2:
	if _room == null or _room.texture == null:
		return Vector2.ZERO
	return _room.texture.get_size()


func hole_is_generated() -> bool:
	return _hole_tex != null


func floor_atlas_size() -> Vector2:
	if _board == null:
		return Vector2.ZERO
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		if not tile.has_method("look_floor"):
			continue
		var plate := tile.look_floor() as AtlasTexture
		if plate == null or plate.atlas == null:
			continue
		return plate.atlas.get_size()
	return Vector2.ZERO


func pad_offset_y() -> float:
	if _board == null:
		return 0.0
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		var pad := tile.get_node_or_null("ThunderPad") as Sprite2D
		if pad == null:
			continue
		return pad.offset.y
	return 0.0


func room_scale() -> float:
	if _room == null:
		return 0.0
	return _room.scale.x


func room_position() -> Vector2:
	if _room == null:
		return Vector2.ZERO
	return _room.position


func footprint_center() -> Vector2:
	return _footprint_center()


func glow_atlas_size() -> Vector2:
	if _board == null:
		return Vector2.ZERO
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		var glow := tile.get_node_or_null("ThunderGlow") as Sprite2D
		if glow == null:
			continue
		var atlas := glow.texture as AtlasTexture
		if atlas == null or atlas.atlas == null:
			return Vector2.ZERO
		return atlas.atlas.get_size()
	return Vector2.ZERO


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
	var path := resolve_slot("room_edge_dark")
	_room.set_meta("slot_path", path)
	_room.texture = _load_tex(path)
	_room.material = _room_material()
	add_child(_room)


func _build(board: Node2D, snap: Dictionary) -> void:
	_clear_cell_dressing()
	var cycle: Array = _params.get("floor_cycle", [])
	var paint: Dictionary = snap.get("paint_only", {})
	var use_paint := bool(_params.get("special_from_paint", true))
	var pillars := _pillar_set()
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		var tex := _floor_slice(cell, cycle)
		if tile.has_method("set_look_floor"):
			tile.set_look_floor(tex)
		if _is_pad(cell, _params.get("pad_blue", {})) and not pillars.has(cell):
			_add_pad(tile, "pad_blue")
		elif _is_pad(cell, _params.get("pad_red", {})) and not pillars.has(cell):
			_add_pad(tile, "pad_red")
		if use_paint and not _props_at(paint, cell).is_empty():
			_add_glow(tile, cell)
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
		for child_name in ["ThunderPad", "ThunderGlow"]:
			var child := tile.get_node_or_null(child_name)
			if child == null:
				continue
			tile.remove_child(child)
			child.free()
	_free_pillars()
	_built_for = -1


func _add_pad(tile: Node, slot: String) -> void:
	var path := resolve_slot(slot)
	var tex := _load_tex(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "ThunderPad"
	sprite.centered = true
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scale := _cell_scale()
	sprite.scale = Vector2(scale, scale)
	sprite.offset = _pad_offset(tex, slot)
	sprite.material = _pad_material()
	sprite.z_as_relative = true
	sprite.z_index = _z("pad")
	tile.add_child(sprite)


func _add_glow(tile: Node, cell: Vector2i) -> void:
	var path := resolve_slot("glow_mask")
	var tex := _load_tex(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "ThunderGlow"
	sprite.centered = true
	sprite.texture = _glow_slice(tex, cell)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scale := _cell_scale()
	sprite.scale = Vector2(scale, scale)
	sprite.material = _glow_material(cell)
	sprite.z_as_relative = true
	sprite.z_index = _z("glow")
	tile.add_child(sprite)


func _spawn_pillars(board: Node2D) -> void:
	_free_pillars()
	var tex := _texture("light_pillar")
	if tex == null:
		return
	var scale := _cell_scale()
	for cell in _pillar_list():
		if not board.tiles.has(cell):
			continue
		var sprite := Sprite2D.new()
		sprite.name = "ThunderPillar"
		sprite.centered = true
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2(scale, scale)
		sprite.z_as_relative = false
		sprite.z_index = _z("pillar")
		sprite.material = _pillar_material()
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
	_room.visible = visible
	_room.position = _footprint_center()
	var tex_size := _room.texture.get_size()
	var scale := _room_cover_scale(tex_size)
	_room.scale = Vector2(scale, scale)
	var key := "%.3f|%.1f|%.1f|%d" % [scale, _room.position.x, _room.position.y, _board.tiles.size()]
	if key != _mask_key:
		_rebuild_hole(tex_size)
		_mask_key = key


func _apply_pulse() -> void:
	if _board == null:
		return
	var glow := _pulse_value()
	var wave := _pulse_wave()
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		if tile.has_method("set_look_pulse"):
			tile.set_look_pulse(glow)
		var pad := tile.get_node_or_null("ThunderPad") as CanvasItem
		if pad != null:
			pad.modulate.a = 0.62 + 0.38 * wave
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


func _footprint_center() -> Vector2:
	if _board == null or _board.tiles.is_empty():
		return Vector2.ZERO
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for cell in _board.tiles.keys():
		var origin := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)
		min_x = minf(min_x, origin.x - 32.0)
		max_x = maxf(max_x, origin.x + 32.0)
		min_y = minf(min_y, origin.y - 16.0)
		max_y = maxf(max_y, origin.y + 16.0)
	return Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)


func _cell_scale() -> float:
	return float(_params.get("cell_draw_scale", 0.5))


func _pad_offset(tex: Texture2D, slot: String) -> Vector2:
	var slots: Dictionary = _params.get("slots", {})
	var spec: Dictionary = slots.get(slot, {})
	var raised := float(spec.get("raised_px", 0))
	var height := float(tex.get_height())
	var diamond_center := raised + (height - raised) * 0.5
	return Vector2(0, height * 0.5 - diamond_center)


func _floor_slice(cell: Vector2i, cycle: Array) -> Texture2D:
	var tex := _texture("floor_tiles")
	if tex == null:
		return null
	var count := cycle.size()
	if count < 1:
		count = GLOW_SLICES
	var index := posmod(cell.x + cell.y * 2, count)
	return _slice(tex, index, count)


func _slice(tex: Texture2D, index: int, count: int) -> AtlasTexture:
	var slice_w := float(tex.get_width()) / float(count)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(slice_w * float(index), 0.0, slice_w, float(tex.get_height()))
	return atlas


func _glow_slice(tex: Texture2D, cell: Vector2i) -> AtlasTexture:
	var index := posmod(cell.x + cell.y * 2, GLOW_SLICES)
	return _slice(tex, index, GLOW_SLICES)


func _glow_material(cell: Vector2i) -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _glow_shader
	mat.set_shader_parameter("phase", float(cell.x) * 1.7 + float(cell.y) * 2.3)
	mat.set_shader_parameter("pulse_hz", float(_params.get("pulse_hz", 0.22)))
	mat.set_shader_parameter("flow_speed", float(_params.get("glow_flow_speed", 0.35)))
	_apply_glow_uniforms(mat)
	return mat


func _pad_material() -> ShaderMaterial:
	if _pad_shader == null:
		_pad_shader = Shader.new()
		_pad_shader.code = PAD_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _pad_shader
	mat.set_shader_parameter("pad_strength", pad_strength())
	return mat


func _pillar_material() -> ShaderMaterial:
	if _pillar_shader == null:
		_pillar_shader = Shader.new()
		_pillar_shader.code = PILLAR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _pillar_shader
	var color := pillar_color()
	mat.set_shader_parameter("pillar_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("pillar_strength", pillar_strength())
	return mat


func _apply_glow_uniforms(mat: ShaderMaterial) -> void:
	var color := glow_color()
	mat.set_shader_parameter("glow_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("glow_strength", glow_strength())


func _room_material() -> ShaderMaterial:
	if _room_shader == null:
		_room_shader = Shader.new()
		_room_shader.code = ROOM_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _room_shader
	return mat


func _room_cover_scale(tex_size: Vector2) -> float:
	var view := _view_world()
	var margin := float(_params.get("pan_margin_px", 220.0))
	var need := view + Vector2(margin, margin) * 2.0
	var cover := maxf(need.x / tex_size.x, need.y / tex_size.y)
	return cover * float(_params.get("room_extra_scale", 1.08))


func _view_world() -> Vector2:
	var view := Vector2(960, 720)
	if _board != null:
		var live := _board.get_viewport_rect().size
		if live.x >= 32.0 and live.y >= 32.0:
			view = live
	var zoom := Vector2(0.64, 0.64)
	if _board != null:
		var cam := _board.get_node_or_null("BoardCamera") as Camera2D
		if cam != null and cam.zoom.x > 0.01:
			zoom = cam.zoom
	return Vector2(view.x / zoom.x, view.y / zoom.y)


func _rebuild_hole(tex_size: Vector2) -> void:
	var w := int(tex_size.x)
	var h := int(tex_size.y)
	if w < 2 or h < 2 or _room == null:
		return
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	bytes.fill(255)
	var scale := _room.scale.x
	if scale < 0.001:
		return
	var center := _room.position
	var hx := 32.0 / scale
	var hy := 16.0 / scale
	var feather := float(_params.get("room_feather", 0.14))
	for cell in _board.tiles.keys():
		var origin := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)
		var px := (origin - center) / scale + Vector2(float(w), float(h)) * 0.5
		_stamp_hole(bytes, w, h, px, hx, hy, feather)
	var image := Image.create_from_data(w, h, false, Image.FORMAT_L8, bytes)
	if _hole_tex == null:
		_hole_tex = ImageTexture.create_from_image(image)
	else:
		_hole_tex.set_image(image)
	var mat := _room.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("hole_mask", _hole_tex)


func _stamp_hole(bytes: PackedByteArray, w: int, h: int, center: Vector2, hx: float, hy: float, feather: float) -> void:
	if hx < 0.5 or hy < 0.5:
		return
	var limit := 1.0 + feather
	var y0 := maxi(0, int(floor(center.y - hy * limit)))
	var y1 := mini(h - 1, int(ceil(center.y + hy * limit)))
	var x_pad := hx * limit
	for y in range(y0, y1 + 1):
		var row := y * w
		var x0 := maxi(0, int(floor(center.x - x_pad)))
		var x1 := mini(w - 1, int(ceil(center.x + x_pad)))
		for x in range(x0, x1 + 1):
			var dist := absf(float(x) - center.x) / hx + absf(float(y) - center.y) / hy
			if dist >= limit:
				continue
			var room := clampf((dist - 1.0) / feather, 0.0, 1.0)
			var shade := int(round(room * 255.0))
			if shade < int(bytes[row + x]):
				bytes[row + x] = shade


func _z(key: String) -> int:
	var table: Dictionary = _params.get("z_order", {})
	return int(table.get(key, 0))


func _texture(slot: String) -> Texture2D:
	return _load_tex(resolve_slot(slot))


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	return load(path) as Texture2D
