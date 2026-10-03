extends Node2D

## View-only Thunderwell Core floor. Theme id thunderwell.
## Dark circuit plates, a glow tint on the traces, pillars tinted pale, pads
## left in their painted hue, and a dark gradient around a hole generated from
## the cell footprint. CombatSim, the grid and the tile records stay as they are.
## Art: res://art/pc/look/thunderwell_floor/. Params: thunderwell_floor.json.
## glow_mask is lossless data, with no source_color. R is emission over the full
## range. G is 1 along traces and is not a direction. B is 0. Glow is
## R * strength * pulse(G), tint #47F280, strength 0.35 to 0.42. The pulse is
## 0.7 + 0.3 * sin, shifted by the cell's index along its route. h/v flips only
## mirror the slot and never move the pulse. Untraced cells use slots a and b.
## The pillar adds the painted beam at 0.45, light pool on the cell. Floor, pads,
## the pillar and the room sample as color. A preview calls request_theme.
## 2D HDR and the glow environment stay there. Highlighted cells dim the trace
## by 0.4 so a move tile stays brighter than the glow.

const PARAMS_PATH := "res://data/pc/look/thunderwell_floor.json"
const DEFAULT_ROOT := "res://art/pc/look/thunderwell_floor/"
const THEME_ID := "thunderwell"
const GLOW_SLICES := 4
const ROUTE_SLOTS := 8
const PORT_N := 1
const PORT_E := 2
const PORT_S := 4
const PORT_W := 8
const SLOT_STRAIGHT := 2
const SLOT_BEND := 3
const SLOT_TEE := 4
const SLOT_END := 5
const SLOT_CROSS := 6
const GLOW_STRENGTH_MAX := 0.42
const GLOW_SHADER := """shader_type canvas_item;
render_mode blend_add;
// mask_tex is glow_mask, sampled as data. Do not mark it as color: under HDR 2D
// a color hint bends R and G. R is emission over the full range. G is 1 along
// traces and 0 elsewhere, and is not a flow direction. B is 0. The pulse is
// G * (0.7 + 0.3 * sin), shifted by the route phase. h/v flips only mirror the slot.
uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform float phase = 0.0;
uniform float pulse_hz = 0.22;
uniform float pulse_clock = 0.0;
uniform float glow_strength = 0.38;
uniform float highlight_dim = 1.0;
uniform vec4 slot_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float flip_h = 0.0;
uniform float flip_v = 0.0;
uniform vec3 glow_color = vec3(0.278, 0.949, 0.502);
vec2 slot_uv(vec2 uv) {
	if (flip_h < 0.5 && flip_v < 0.5)
		return uv;
	vec2 local = (uv - slot_rect.xy) / slot_rect.zw;
	if (flip_h > 0.5)
		local.x = 1.0 - local.x;
	if (flip_v > 0.5)
		local.y = 1.0 - local.y;
	return slot_rect.xy + local * slot_rect.zw;
}
void fragment() {
	vec2 uv = slot_uv(UV);
	vec2 local = (uv - slot_rect.xy) / slot_rect.zw;
	// The slot rect is the diamond's box, and neighbouring boxes overlap.
	// Keep the add inside this cell so a straight run does not stack.
	float diamond = abs(local.x - 0.5) + abs(local.y - 0.5);
	vec4 tex = texture(mask_tex, uv);
	float gate = tex.g;
	float wave = 0.7 + 0.3 * sin(pulse_clock * TAU * pulse_hz - phase * TAU);
	float pulse = gate * wave;
	float inside = 1.0 - step(0.5001, diamond);
	float amount = min(tex.r * min(glow_strength, 0.42) * pulse * highlight_dim, 1.0) * inside;
	COLOR = vec4(glow_color * amount, 1.0);
}
"""
const PAD_SHADER := """shader_type canvas_item;
render_mode blend_add;
// TEXTURE keeps source_color. Pad hue stays in the painted art.
uniform float pad_strength = 1.55;
uniform vec3 chip_color = vec3(0.083, 0.199, 0.550);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 scaled = tex.rgb * pad_strength;
	float ink = max(tex.a, max(scaled.r, max(scaled.g, scaled.b)));
	float rim = smoothstep(0.20, 0.48, ink) * (1.0 - smoothstep(0.62, 0.90, ink));
	vec3 rgb = chip_color * ink * 0.55 + chip_color * rim * 0.40;
	COLOR = vec4(rgb, clamp(ink, 0.0, 1.0));
}
"""
const PILLAR_SHADER := """shader_type canvas_item;
render_mode blend_add;
// TEXTURE keeps source_color. The painted beam is added at pillar_strength.
uniform float pillar_strength = 0.45;
uniform vec3 pillar_color = vec3(0.780, 0.920, 0.827);
uniform float core_width = 0.20;
uniform float halo_width = 0.70;
uniform float core_gain = 0.22;
uniform float halo_gain = 0.55;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float keep = (core_width + halo_width + core_gain + halo_gain + pillar_color.r) * 0.0;
	vec3 rgb = tex.rgb * pillar_strength + vec3(keep);
	COLOR = vec4(rgb, 1.0);
}
"""
const ROOM_SHADER := """shader_type canvas_item;
// TEXTURE keeps source_color on the vignette. hole_mask is generated data:
// 0 on the board, rising to 1 across the wall reach.
uniform sampler2D hole_mask : filter_linear, repeat_disable;
uniform vec3 wall_color = vec3(0.012, 0.030, 0.026);
uniform vec3 rim_color = vec3(0.45, 0.95, 0.62);
uniform float rim_strength = 1.15;
uniform float wall_strength = 1.0;
uniform float wall_rim = 0.10;
void fragment() {
	vec4 grad = texture(TEXTURE, UV);
	float d = texture(hole_mask, UV).r;
	float rim_w = max(wall_rim, 0.02);
	float rim = smoothstep(0.0, rim_w * 0.28, d) * (1.0 - smoothstep(rim_w * 0.28, rim_w, d));
	float wall = smoothstep(0.0, 0.04, d) * (1.0 - smoothstep(0.22, 0.78, d));
	vec3 rgb = mix(grad.rgb, wall_color, clamp(wall * wall_strength, 0.0, 1.0));
	rgb += rim_color * rim * rim_strength;
	float cover = smoothstep(0.0, 0.025, d);
	COLOR = vec4(rgb, cover);
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
var _routes: Array = []
var _routes_on: bool = false


static func request_theme(theme_id: String) -> void:
	requested_theme = theme_id.strip_edges().to_lower()


static func glow_color() -> Color:
	return _json_color("glow_color", Color(0.220, 0.900, 0.447))


static func glow_strength() -> float:
	return minf(_json_float("glow_strength", GLOW_STRENGTH_MAX), GLOW_STRENGTH_MAX)


static func pillar_color() -> Color:
	return _json_color("pillar_color", Color(0.780, 0.920, 0.827))


static func pillar_strength() -> float:
	return _json_float("pillar_strength", 0.45)


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


static func strip_slots(width: int, height: int) -> int:
	var slot_w := height * 2
	if slot_w < 1 or width < slot_w:
		return GLOW_SLICES
	return int(width / slot_w)


static func slot_uv_rect(index: int, count: int) -> Rect2:
	var n := maxi(count, 1)
	var w := 1.0 / float(n)
	return Rect2(w * float(index), 0.0, w, 1.0)


static func board_routes(params: Dictionary = {}) -> Array:
	var src := params
	if src.is_empty():
		src = load_params()
	var out: Array = []
	var raw: Variant = src.get("routes", [])
	if not (raw is Array):
		return out
	for route in raw:
		var cells: Array[Vector2i] = []
		if route is Array:
			for item in route:
				if item is Array and (item as Array).size() >= 2:
					cells.append(Vector2i(int(item[0]), int(item[1])))
		if cells.size() >= 2:
			out.append(cells)
	return out


static func named_cells(params: Dictionary, key: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var raw: Variant = params.get(key, [])
	if raw is Array:
		for item in raw:
			if item is Array and (item as Array).size() >= 2:
				out.append(Vector2i(int(item[0]), int(item[1])))
	return out


static func is_pad_cell(cell: Vector2i, params: Dictionary) -> bool:
	for pillar in named_cells(params, "pillar_cells"):
		if pillar == cell:
			return false
	if _pad_hit(cell, params.get("pad_blue", {})):
		return true
	return _pad_hit(cell, params.get("pad_red", {}))


static func _pad_hit(cell: Vector2i, spec: Variant) -> bool:
	if typeof(spec) != TYPE_DICTIONARY:
		return false
	var step_x := int(spec.get("step_x", 0))
	var step_y := int(spec.get("step_y", 0))
	if step_x < 1 or step_y < 1:
		return false
	var phase_x := int(spec.get("phase_x", 0))
	var phase_y := int(spec.get("phase_y", 0))
	return posmod(cell.x - phase_x, step_x) == 0 and posmod(cell.y - phase_y, step_y) == 0


static func port_between(cell: Vector2i, other: Vector2i) -> int:
	var delta := other - cell
	if delta == Vector2i(0, -1):
		return PORT_N
	if delta == Vector2i(1, 0):
		return PORT_E
	if delta == Vector2i(0, 1):
		return PORT_S
	if delta == Vector2i(-1, 0):
		return PORT_W
	return 0


static func cell_ports(cell: Vector2i, routes: Array) -> int:
	var mask := 0
	for route in routes:
		var cells: Array = route
		for i in cells.size():
			if cells[i] != cell:
				continue
			if i > 0:
				mask |= port_between(cell, cells[i - 1])
			if i + 1 < cells.size():
				mask |= port_between(cell, cells[i + 1])
	return mask


## Phase is index / route length. A shared cell keeps the lower index.
## orient is ignored: a flip never reverses the pulse.
static func pulse_phase(cell: Vector2i, routes: Array, _orient: int = 0) -> float:
	return route_phase(cell, routes)


static func route_phase(cell: Vector2i, routes: Array) -> float:
	var best_i := 1 << 30
	var best_len := 1
	var found := false
	for route in routes:
		var cells: Array = route
		var length := cells.size()
		for i in length:
			if cells[i] != cell:
				continue
			if i < best_i:
				best_i = i
				best_len = maxi(length, 1)
				found = true
	if not found:
		return 0.0
	return float(best_i) / float(best_len)


static func mask_port_names(mask: int) -> Array:
	var names: Array = []
	if (mask & PORT_N) != 0:
		names.append("NE")
	if (mask & PORT_E) != 0:
		names.append("SE")
	if (mask & PORT_S) != 0:
		names.append("SW")
	if (mask & PORT_W) != 0:
		names.append("NW")
	names.sort()
	return names


static func mirror_port_name(name: String, flip_h: bool, flip_v: bool) -> String:
	var port := name
	if flip_h:
		match port:
			"NE":
				port = "NW"
			"NW":
				port = "NE"
			"SE":
				port = "SW"
			"SW":
				port = "SE"
	if flip_v:
		match port:
			"NE":
				port = "SE"
			"SE":
				port = "NE"
			"NW":
				port = "SW"
			"SW":
				port = "NW"
	return port


static func piece_for_mask(mask: int) -> Dictionary:
	var want := mask_port_names(mask)
	var slots: Array = load_params().get("strip", {}).get("slots", [])
	for slot in slots:
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var flips: Dictionary = slot.get("ports_by_flip", {})
		for key in ["none", "h", "v", "hv"]:
			var got: Array = []
			for port in flips.get(key, []):
				got.append(str(port))
			got.sort()
			if got == want and not want.is_empty():
				return {
					"slot": int(slot.get("index", 0)),
					"flip_h": key == "h" or key == "hv",
					"flip_v": key == "v" or key == "hv",
					"diag": false,
					"flip": key,
				}
	return {"slot": 0, "flip_h": false, "flip_v": false, "diag": false, "flip": "none"}


static func port_uv(port: int) -> Vector2:
	match port:
		PORT_N:
			return Vector2(0.75, 0.25)
		PORT_E:
			return Vector2(0.75, 0.75)
		PORT_S:
			return Vector2(0.25, 0.75)
		PORT_W:
			return Vector2(0.25, 0.25)
	return Vector2(0.5, 0.5)


static func plain_slot(cell: Vector2i) -> int:
	return 0 if posmod(cell.x * 13 + cell.y * 7 + cell.x * cell.y, 2) == 0 else 1


static func tile_plan(cell: Vector2i, routes: Array) -> Dictionary:
	var mask := cell_ports(cell, routes)
	var phase := pulse_phase(cell, routes, 0)
	if mask == 0:
		return {
			"slot": plain_slot(cell),
			"orient": 0,
			"flip_h": false,
			"flip_v": false,
			"diag": false,
			"flip": "none",
			"phase": phase,
			"mask": 0,
		}
	var plan := piece_for_mask(mask)
	plan["phase"] = phase
	plan["mask"] = mask
	return plan


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


func _build(board: Node2D, _snap: Dictionary) -> void:
	_clear_cell_dressing()
	_routes = board_routes(_params)
	_routes_on = _route_strip_ready()
	var cycle: Array = _params.get("floor_cycle", [])
	var pillars := _pillar_set()
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		var plan := _plan_for(cell)
		var tex := _floor_slice(cell, cycle, plan)
		if tile.has_method("set_look_floor"):
			tile.set_look_floor(tex)
			if tile.has_method("set_look_grade"):
				tile.set_look_grade(_floor_grade())
			if tile.has_method("set_look_lift"):
				tile.set_look_lift(float(_params.get("floor_lift", 0.36)))
			if tile.has_method("set_look_seam"):
				tile.set_look_seam(true)
			if _routes_on and tile.has_method("set_look_orient"):
				var count := _floor_slot_count()
				tile.set_look_orient(bool(plan.get("flip_h", false)), bool(plan.get("flip_v", false)), bool(plan.get("diag", false)), slot_uv_rect(int(plan.get("slot", 0)), count))
		if _is_pad(cell, _params.get("pad_blue", {})) and not pillars.has(cell):
			_add_pad(tile, "pad_blue")
		elif _is_pad(cell, _params.get("pad_red", {})) and not pillars.has(cell):
			_add_pad(tile, "pad_red")
		_add_glow(tile, cell, plan)
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
	sprite.material = _pad_material(slot)
	sprite.set_meta("slot", slot)
	sprite.z_as_relative = true
	sprite.z_index = _z("pad")
	tile.add_child(sprite)


func _add_glow(tile: Node, cell: Vector2i, plan: Dictionary) -> void:
	var path := resolve_slot("glow_mask")
	var tex := _load_tex(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "ThunderGlow"
	sprite.centered = true
	var count := _glow_slot_count(tex)
	var index := int(plan.get("slot", 0)) if _routes_on else posmod(cell.x + cell.y * 2, count)
	sprite.texture = _slice(tex, index, count)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scale := _cell_scale()
	sprite.scale = Vector2(scale, scale)
	sprite.material = _glow_material(cell, tex, plan, index, count)
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
		sprite.centered = false
		sprite.texture = tex
		sprite.offset = _pillar_offset(tex)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2(scale, scale)
		sprite.z_as_relative = false
		sprite.z_index = _pillar_z(cell)
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
		sprite.centered = false
		if sprite.texture != null:
			sprite.offset = _pillar_offset(sprite.texture)
		sprite.position = tile.position
		sprite.z_as_relative = false
		sprite.z_index = _pillar_z(cell)


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
		var trace := tile.get_node_or_null("ThunderGlow") as CanvasItem
		if trace != null and trace.material is ShaderMaterial:
			var mat := trace.material as ShaderMaterial
			mat.set_shader_parameter("highlight_dim", _highlight_dim(tile))
			mat.set_shader_parameter("pulse_clock", _time)
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


func _floor_slice(cell: Vector2i, cycle: Array, plan: Dictionary) -> Texture2D:
	var tex := _texture("floor_tiles")
	if tex == null:
		return null
	var count := _floor_slot_count()
	if not _routes_on:
		count = cycle.size()
		if count < 1:
			count = GLOW_SLICES
	var index := int(plan.get("slot", 0)) if _routes_on else posmod(cell.x + cell.y * 2, count)
	return _slice(tex, index, count)


func _slice(tex: Texture2D, index: int, count: int) -> AtlasTexture:
	var slice_w := float(tex.get_width()) / float(count)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(slice_w * float(index), 0.0, slice_w, float(tex.get_height()))
	return atlas


func _glow_material(cell: Vector2i, mask: Texture2D, plan: Dictionary, index: int, count: int) -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _glow_shader
	mat.set_shader_parameter("mask_tex", mask)
	var phase := float(plan.get("phase", 0.0)) if _routes_on else float(cell.x) * 1.7 + float(cell.y) * 2.3
	mat.set_shader_parameter("phase", phase)
	mat.set_shader_parameter("pulse_hz", float(_params.get("pulse_hz", 0.22)))
	mat.set_shader_parameter("pulse_clock", _time)
	mat.set_shader_parameter("highlight_dim", 1.0)
	var slot := slot_uv_rect(index, count)
	mat.set_shader_parameter("slot_rect", Vector4(slot.position.x, slot.position.y, slot.size.x, slot.size.y))
	mat.set_shader_parameter("flip_h", 1.0 if bool(plan.get("flip_h", false)) and _routes_on else 0.0)
	mat.set_shader_parameter("flip_v", 1.0 if bool(plan.get("flip_v", false)) and _routes_on else 0.0)
	_apply_glow_uniforms(mat)
	return mat


func full_pulse_time(phase: float) -> float:
	var hz := float(_params.get("pulse_hz", 0.22)) if not _params.is_empty() else float(load_params().get("pulse_hz", 0.22))
	if hz < 0.0001:
		return 0.0
	return (0.25 + phase) / hz


func _pillar_offset(tex: Texture2D) -> Vector2:
	var anchor: Array = load_params().get("pillar_anchor", [64, 441])
	var ax := float(tex.get_width()) * 0.5
	var ay := float(tex.get_height())
	if anchor.size() >= 2 and float(anchor[1]) > 1.0:
		ay = float(tex.get_height()) * (float(anchor[1]) / 512.0)
		ax = float(tex.get_width()) * (float(anchor[0]) / 128.0)
	return Vector2(-ax, -ay)


func _plan_for(cell: Vector2i) -> Dictionary:
	if _routes_on:
		return tile_plan(cell, _routes)
	var cycle: Array = _params.get("floor_cycle", [])
	var count := cycle.size()
	if count < 1:
		count = GLOW_SLICES
	return {
		"slot": posmod(cell.x + cell.y * 2, count),
		"flip_h": false,
		"flip_v": false,
		"diag": false,
		"phase": float(cell.x) * 1.7 + float(cell.y) * 2.3,
		"mask": 0,
	}


func _route_strip_ready() -> bool:
	return _floor_slot_count() >= ROUTE_SLOTS and _glow_slot_count(_texture("glow_mask")) >= ROUTE_SLOTS


func _floor_slot_count() -> int:
	var tex := _texture("floor_tiles")
	if tex == null:
		return GLOW_SLICES
	return strip_slots(tex.get_width(), tex.get_height())


func _glow_slot_count(tex: Texture2D) -> int:
	if tex == null:
		return GLOW_SLICES
	return strip_slots(tex.get_width(), tex.get_height())


func _highlight_dim(tile: Node) -> float:
	var kind := str(tile.get("highlight"))
	if kind != "" or bool(tile.get("is_selected")):
		return float(_params.get("trace_highlight_dim", 0.4))
	return 1.0


func _pad_material(slot: String) -> ShaderMaterial:
	if _pad_shader == null:
		_pad_shader = Shader.new()
		_pad_shader.code = PAD_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _pad_shader
	mat.set_shader_parameter("pad_strength", pad_strength())
	var color := pad_blue_color() if slot == "pad_blue" else pad_red_color()
	mat.set_shader_parameter("chip_color", Vector3(color.r, color.g, color.b))
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
	mat.set_shader_parameter("core_width", float(_params.get("pillar_core", 0.055)))
	mat.set_shader_parameter("halo_width", float(_params.get("pillar_halo", 0.30)))
	mat.set_shader_parameter("core_gain", float(_params.get("pillar_core_gain", 1.65)))
	mat.set_shader_parameter("halo_gain", float(_params.get("pillar_halo_gain", 0.20)))
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
	_apply_room_uniforms(mat)
	return mat


func _floor_grade() -> Color:
	var raw: Variant = _params.get("floor_grade", [1.08, 1.32, 1.05])
	if raw is Array and (raw as Array).size() >= 3:
		return Color(float(raw[0]), float(raw[1]), float(raw[2]))
	return Color(1.08, 1.32, 1.05)


func _apply_room_uniforms(mat: ShaderMaterial) -> void:
	var wall := _vec3_param("wall_color", Color(0.012, 0.030, 0.026))
	var rim := _vec3_param("wall_rim_color", Color(0.45, 0.95, 0.62))
	mat.set_shader_parameter("wall_color", wall)
	mat.set_shader_parameter("rim_color", rim)
	mat.set_shader_parameter("rim_strength", float(_params.get("wall_rim_strength", 1.15)))
	mat.set_shader_parameter("wall_strength", float(_params.get("wall_strength", 1.0)))
	mat.set_shader_parameter("wall_rim", float(_params.get("wall_rim", 0.10)))


func _vec3_param(key: String, fallback: Color) -> Vector3:
	var raw: Variant = _params.get(key, [])
	if raw is Array and (raw as Array).size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(fallback.r, fallback.g, fallback.b)


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
	var reach := float(_params.get("wall_reach", 3.4))
	for cell in _board.tiles.keys():
		var origin := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0)
		var px := (origin - center) / scale + Vector2(float(w), float(h)) * 0.5
		_stamp_hole(bytes, w, h, px, hx, hy, reach)
	var image := Image.create_from_data(w, h, false, Image.FORMAT_L8, bytes)
	if _hole_tex == null:
		_hole_tex = ImageTexture.create_from_image(image)
	else:
		_hole_tex.set_image(image)
	var mat := _room.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("hole_mask", _hole_tex)


func _stamp_hole(bytes: PackedByteArray, w: int, h: int, center: Vector2, hx: float, hy: float, reach: float) -> void:
	if hx < 0.5 or hy < 0.5:
		return
	var span := maxf(reach, 0.2)
	var limit := 1.0 + span
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
			var room := 0.0 if dist <= 1.0 else clampf((dist - 1.0) / span, 0.0, 1.0)
			var shade := int(round(room * 255.0))
			if shade < int(bytes[row + x]):
				bytes[row + x] = shade


func _pillar_z(cell: Vector2i) -> int:
	# Sort with the cell. A fixed layer above the board paints the beam over
	# fighters and move tiles. The highlight sits one step above the cell,
	# and the fighter sits above that.
	return BoardVisualSort.tile_z_index(cell)


func _z(key: String) -> int:
	var table: Dictionary = _params.get("z_order", {})
	return int(table.get(key, 0))


func _texture(slot: String) -> Texture2D:
	return _load_tex(resolve_slot(slot))


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	return load(path) as Texture2D
