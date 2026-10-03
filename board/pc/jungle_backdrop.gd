extends Node2D

## View-only Crosshaven jungle surround. Painted plates sit behind the board,
## soft leaf shadows fall on the diamonds, and giant leaves frame the screen.
## The grid, the tile records and CombatSim are not touched.
## Art is data-driven: res://art/pc/look/crosshaven_jungle/ with @2x tried first.
## Tunables: res://data/pc/look/crosshaven_backdrop.json

const PARAMS_PATH := "res://data/pc/look/crosshaven_backdrop.json"
const DEFAULT_ROOT := "res://art/pc/look/crosshaven_jungle/"
const BACK_SLOTS: Array[String] = ["back_far", "back_mid"]
const LEAF_EDGES := {
	"front_leaves_left": "left",
	"front_leaves_right": "right",
	"front_leaves_top": "top",
	"front_leaves_bottom": "bottom",
}
const SHADOW_SHADER := """shader_type canvas_item;
render_mode blend_mul;
uniform sampler2D shadow_tex : repeat_enable, filter_linear, hint_default_white;
uniform float opacity = 0.55;
uniform vec2 origin = vec2(0.0);
uniform float world_repeat = 512.0;
varying vec2 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	float rep = max(world_repeat, 1.0);
	vec2 drift = vec2(TIME * 0.012, TIME * 0.004);
	vec2 uv = fract((origin + local_pos) / rep + drift);
	float lit = texture(shadow_tex, uv).r;
	vec3 tinted = mix(vec3(0.22, 0.48, 0.28), vec3(0.93, 1.0, 0.90), lit);
	vec3 mul = mix(vec3(1.0), tinted, clamp(opacity, 0.0, 1.0));
	COLOR = vec4(mul, 1.0);
}
"""
const SKIRT_SHADER := """shader_type canvas_item;
// Retired cliff. Strength stays in json and is 0 once the clearing is painted.
uniform vec3 skirt_color = vec3(0.035, 0.062, 0.048);
uniform float strength = 0.0;
uniform float board_n = 15.0;
uniform float reach = 0.0;
varying vec2 board_pos;
void vertex() {
	board_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float fx = board_pos.y / 32.0 + board_pos.x / 64.0;
	float fy = board_pos.y / 32.0 - board_pos.x / 64.0;
	float edge = max(board_n - 0.5, 0.0);
	float ox = max(max(-0.5 - fx, fx - edge), 0.0);
	float oy = max(max(-0.5 - fy, fy - edge), 0.0);
	float outside = length(vec2(ox, oy));
	float fade = 1.0 - smoothstep(0.15, max(reach, 0.2), outside);
	float rim = smoothstep(0.0, 0.85, outside);
	float a = strength * fade * mix(0.55, 1.0, rim);
	COLOR = vec4(skirt_color, a);
}
"""
## Keep the rim curve in step with contact_rim_alpha(). Alpha is 0 on the
## board square, which is the cell diamonds, and it dies by width_cells.
const CONTACT_SHADER := """shader_type canvas_item;
uniform vec3 shadow_color = vec3(0.02, 0.04, 0.03);
uniform float strength = 0.36;
uniform float board_n = 15.0;
uniform float width = 0.9;
varying vec2 board_pos;
void vertex() {
	board_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float fx = board_pos.y / 32.0 + board_pos.x / 64.0;
	float fy = board_pos.y / 32.0 - board_pos.x / 64.0;
	float edge = max(board_n - 0.5, 0.0);
	float ox = max(max(-0.5 - fx, fx - edge), 0.0);
	float oy = max(max(-0.5 - fy, fy - edge), 0.0);
	float outside = length(vec2(ox, oy));
	float w = max(width, 0.05);
	float rise = smoothstep(0.0, w * 0.18, outside);
	float fall = 1.0 - smoothstep(w * 0.45, w, outside);
	COLOR = vec4(shadow_color, strength * rise * fall);
}
"""
const MAX_FIGHTERS := 12
const CELL_HALF_X := 34.0
const CELL_HALF_Y := 18.0
const FIGHTER_RX := 78.0
const FIGHTER_RY := 130.0
const FIGHTER_LIFT := 42.0
const HOVER_HX := 72.0
const HOVER_HY := 44.0
## Keep this fragment in step with leaf_cutout(). 0 cuts the leaf, 1 leaves it.
const SWAY_SHADER := """shader_type canvas_item;
uniform sampler2D sway_tex : filter_linear, repeat_disable;
uniform float swing = 0.0;
uniform vec2 sway_dir = vec2(1.0, 0.0);
uniform float amplitude_px = 16.0;
uniform vec2 to_board_x = vec2(1.0, 0.0);
uniform vec2 to_board_y = vec2(0.0, 1.0);
uniform vec2 to_board_origin = vec2(0.0);
uniform vec2 fighter_pos[12];
uniform int fighter_count = 0;
uniform vec2 hover_pos = vec2(0.0);
uniform float hover_on = 0.0;
uniform float board_n = 0.0;
uniform float cell_half_x = 34.0;
uniform float cell_half_y = 18.0;
uniform float fighter_rx = 78.0;
uniform float fighter_ry = 130.0;
uniform float fighter_lift = 42.0;
uniform float hover_hx = 72.0;
uniform float hover_hy = 44.0;
varying vec2 v_board;
void vertex() {
	float weight = texture(sway_tex, UV).r;
	VERTEX += sway_dir * swing * amplitude_px * weight;
	vec2 canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_board = to_board_origin + to_board_x * canvas_pos.x + to_board_y * canvas_pos.y;
}
void fragment() {
	float keep = 1.0;
	vec2 p = v_board;
	float hx = max(cell_half_x, 1.0);
	float hy = max(cell_half_y, 1.0);
	for (int step = 0; step < 3; step++) {
		vec2 q = p + vec2(0.0, float(step) * 10.0);
		float fx = q.y / 32.0 + q.x / 64.0;
		float fy = q.y / 32.0 - q.x / 64.0;
		float cx = floor(fx + 0.5);
		float cy = floor(fy + 0.5);
		if (cx >= 0.0 && cy >= 0.0 && cx <= board_n - 1.0 && cy <= board_n - 1.0) {
			vec2 center = vec2((cx - cy) * 32.0, (cx + cy) * 16.0 - float(step) * 10.0);
			float metric = abs(p.x - center.x) / hx + abs(p.y - center.y) / hy;
			keep = min(keep, smoothstep(0.92, 1.05, metric));
		}
	}
	for (int i = 0; i < 12; i++) {
		if (i < fighter_count) {
			vec2 center = fighter_pos[i] + vec2(0.0, -fighter_lift);
			vec2 delta = (p - center) / vec2(max(fighter_rx, 1.0), max(fighter_ry, 1.0));
			keep = min(keep, smoothstep(0.70, 1.0, length(delta)));
		}
	}
	if (hover_on > 0.5) {
		float metric = abs(p.x - hover_pos.x) / max(hover_hx, 1.0) + abs(p.y - hover_pos.y) / max(hover_hy, 1.0);
		keep = min(keep, smoothstep(0.78, 1.05, metric));
	}
	COLOR.a *= keep;
}
"""

var _params: Dictionary = {}
var _board: Node2D
var _map_id: String = ""
var _force_off: bool = false
var _built: bool = false
var _time: float = 0.0
var _shader: Shader
var _sway_shader: Shader
var _backs: Dictionary = {}
var _clips: Dictionary = {}
var _pivots: Dictionary = {}
var _sprites: Dictionary = {}
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_locked: bool = false
var _skirt: Sprite2D
var _skirt_shader: Shader
var _contact: Sprite2D
var _contact_shader: Shader


class LeafDapple extends Node2D:
	func _draw() -> void:
		var points := PackedVector2Array([
			Vector2(0, -16),
			Vector2(32, 0),
			Vector2(0, 16),
			Vector2(-32, 0),
		])
		var uvs := PackedVector2Array([
			Vector2(0.5, 0.0),
			Vector2(1.0, 0.5),
			Vector2(0.5, 1.0),
			Vector2(0.0, 0.5),
		])
		var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		draw_polygon(points, colors, uvs)


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


## @2x master first, then the 1x plate. Empty when neither file imports.
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


static func normalize_map_id(map_id: String) -> String:
	var id := map_id.strip_edges().to_lower()
	if id.ends_with("_15"):
		id = id.substr(0, id.length() - 3)
	if id == "":
		return "crosshaven"
	return id


func _ready() -> void:
	_ensure_params()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	if _board != null and visible and _built:
		call_deferred("_layout_after_resize")


func _layout_after_resize() -> void:
	if _board != null and visible and _built:
		layout()


func sync_map(board: Node2D, map_id: String) -> void:
	_board = board
	_map_id = map_id
	_ensure_params()
	if not _wants_map(map_id):
		_teardown_shadows()
		visible = false
		return
	visible = true
	_ensure_nodes()
	if not _shadows_match(board):
		_build_shadows(board)
	layout()


func set_enabled(on: bool) -> void:
	_force_off = not on
	if _board != null:
		sync_map(_board, _map_id)


func preview_time(t: float) -> void:
	_time = t
	_apply_sway()


func layout() -> void:
	if _board == null or not visible:
		return
	_ensure_params()
	_layout_backs()
	_layout_leaves()
	_layout_skirt()
	_layout_contact()
	_apply_sway()
	_apply_top_fade()
	_drop_pointer(self)
	_sync_cutout()


## Tests and the capture pin the cell under the cursor. Pass a negative cell to release it.
func set_hover_cell(cell: Vector2i) -> void:
	_hover_locked = cell.x >= 0 and cell.y >= 0
	_hover_cell = cell
	_sync_cutout()


## 0 where a front leaf must disappear, 1 where the painted leaf stays.
## Mirrors the sway shader so tests can check the hole without reading pixels.
func leaf_cutout(board_pos: Vector2) -> float:
	var keep := 1.0
	var n := _board_n()
	for step in 3:
		var q := board_pos + Vector2(0.0, float(step) * 10.0)
		var fx := q.y / 32.0 + q.x / 64.0
		var fy := q.y / 32.0 - q.x / 64.0
		var cx := int(floor(fx + 0.5))
		var cy := int(floor(fy + 0.5))
		if cx >= 0 and cy >= 0 and cx <= n - 1 and cy <= n - 1:
			var center := Vector2(float(cx - cy) * 32.0, float(cx + cy) * 16.0 - float(step) * 10.0)
			var metric := absf(board_pos.x - center.x) / CELL_HALF_X + absf(board_pos.y - center.y) / CELL_HALF_Y
			keep = minf(keep, _smoothstep(0.92, 1.05, metric))
	var counted := 0
	for point in _fighter_points():
		if counted >= MAX_FIGHTERS:
			break
		counted += 1
		var center := point + Vector2(0.0, -FIGHTER_LIFT)
		var delta := Vector2(
			(board_pos.x - center.x) / FIGHTER_RX,
			(board_pos.y - center.y) / FIGHTER_RY
		)
		keep = minf(keep, _smoothstep(0.70, 1.0, delta.length()))
	if _hover_active():
		var at: Vector2 = (_board.tiles[_hover_cell] as Node2D).position
		var metric := absf(board_pos.x - at.x) / HOVER_HX + absf(board_pos.y - at.y) / HOVER_HY
		keep = minf(keep, _smoothstep(0.78, 1.05, metric))
	return keep


func cutout_fighter_count() -> int:
	return mini(_fighter_points().size(), MAX_FIGHTERS)


func pointer_passes() -> bool:
	return _controls_ignore(self)


func shadow_count() -> int:
	if _board == null:
		return 0
	var count := 0
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		if tile.get_node_or_null("LeafDapple") != null:
			count += 1
	return count


func shadow_opacity() -> float:
	if _board == null:
		return -1.0
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		var dapple := tile.get_node_or_null("LeafDapple")
		if dapple == null:
			continue
		var mat := dapple.material as ShaderMaterial
		if mat == null:
			return -1.0
		return float(mat.get_shader_parameter("opacity"))
	return -1.0


func shadow_uses_multiply() -> bool:
	if _board == null:
		return false
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		var dapple := tile.get_node_or_null("LeafDapple")
		if dapple == null:
			continue
		var mat := dapple.material as ShaderMaterial
		if mat == null or mat.shader == null:
			return false
		return mat.shader.code.find("blend_mul") >= 0
	return false


func back_art_position(slot: String) -> Vector2:
	var root: Node2D = _backs.get(slot) as Node2D
	if root == null:
		return Vector2.ZERO
	var art := root.get_node_or_null("Art") as Node2D
	if art == null:
		return root.position
	return root.position + art.position


func back_z(slot: String) -> int:
	var root: Node2D = _backs.get(slot) as Node2D
	if root == null:
		return 0
	return root.z_index


func front_z() -> int:
	for slot in _clips.keys():
		var clip: CanvasItem = _clips[slot]
		return clip.z_index
	return 0


## True when a front-leaf corner lands on the play guard at a sway extreme.
func leaves_cover_play() -> bool:
	if _board == null or not visible:
		return false
	var guard := _play_guard()
	if guard.size.x < 1.0:
		return false
	var saved := _time
	var speed := float(_params.get("sway_speed", 0.85))
	var phases: Dictionary = _params.get("sway_phase", {})
	var times: Array[float] = [saved, 0.0, 0.6, 1.4, 2.2]
	for slot in _pivots.keys():
		var phase := float(phases.get(slot, 0.0))
		if speed > 0.001:
			times.append((PI * 0.5 - phase) / speed)
			times.append((PI * 1.5 - phase) / speed)
	for t in times:
		_time = t
		_apply_sway()
		for slot in _sprites.keys():
			var sprite: Sprite2D = _sprites[slot]
			var clip: Control = _clips[slot]
			if sprite == null or sprite.texture == null or not clip.visible:
				continue
			for corner in _sprite_board_corners(sprite):
				if _inside(guard, corner):
					_time = saved
					_apply_sway()
					return true
	_time = saved
	_apply_sway()
	return false


func top_leaf_alpha() -> float:
	return _top_fade_alpha()


func leaf_board_coverage() -> float:
	if _board == null or _board.tiles.is_empty():
		return 0.0
	var images := {}
	for slot in _sprites.keys():
		var sprite: Sprite2D = _sprites[slot]
		if sprite == null or sprite.texture == null:
			continue
		var image := sprite.texture.get_image()
		if image != null and not image.is_empty():
			images[slot] = image
	var hit := 0
	var total := 0
	for cell in _board.tiles.keys():
		var center: Vector2 = (_board.tiles[cell] as Node2D).position
		var samples: Array[Vector2] = [
			center,
			center + Vector2(0, -10),
			center + Vector2(18, 0),
			center + Vector2(0, 10),
			center + Vector2(-18, 0),
		]
		for point in samples:
			total += 1
			if _leaf_covers_point(point, images):
				hit += 1
	if total == 0:
		return 0.0
	return float(hit) / float(total)


func _process(delta: float) -> void:
	if not visible or _board == null or not _built:
		return
	_time += delta
	layout()


func _ensure_params() -> void:
	if not _params.is_empty():
		return
	_params = load_params()


func _wants_map(map_id: String) -> bool:
	if _force_off:
		return false
	var id := normalize_map_id(map_id)
	var allowed: Array = _params.get("map_ids", ["crosshaven"])
	for item in allowed:
		if normalize_map_id(str(item)) == id:
			return true
	return false


func _ensure_nodes() -> void:
	if _built:
		return
	for slot in BACK_SLOTS:
		var root := Node2D.new()
		root.name = slot
		root.z_as_relative = false
		root.z_index = _z(slot)
		var art := Sprite2D.new()
		art.name = "Art"
		art.centered = true
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var path := resolve_slot(slot)
		art.texture = _load_tex(path)
		art.set_meta("slot_path", path)
		root.add_child(art)
		add_child(root)
		_backs[slot] = root
	for slot in LEAF_EDGES.keys():
		var clip := Control.new()
		clip.name = slot
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		clip.z_as_relative = false
		clip.z_index = _z("front_leaves")
		var pivot := Node2D.new()
		pivot.name = "Pivot"
		pivot.set_meta("edge", str(LEAF_EDGES[slot]))
		var sprite := Sprite2D.new()
		sprite.name = "Art"
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var path := resolve_slot(slot)
		sprite.texture = _load_tex(path)
		sprite.set_meta("slot_path", path)
		sprite.material = _sway_material(slot, str(LEAF_EDGES[slot]))
		pivot.add_child(sprite)
		clip.add_child(pivot)
		add_child(clip)
		_clips[slot] = clip
		_pivots[slot] = pivot
		_sprites[slot] = sprite
	_drop_pointer(self)
	_built = true


func _layout_backs() -> void:
	var cam := _board.get_node_or_null("BoardCamera") as Camera2D
	if cam == null:
		return
	var fit: Vector2 = _board.get("_fit_camera_pos")
	var pan := cam.position - fit
	var factors: Dictionary = _params.get("parallax", {})
	var view := _view_rect().size
	for slot in BACK_SLOTS:
		var root: Node2D = _backs[slot]
		var art := root.get_node_or_null("Art") as Sprite2D
		if art == null or art.texture == null:
			root.visible = false
			continue
		root.visible = true
		root.position = cam.position
		art.modulate = _layer_modulate(slot)
		var fraction := float(factors.get(slot, 0.0))
		var scale := _back_scale(fraction, art.texture.get_size(), view)
		art.scale = Vector2(scale, scale)
		art.position = -pan * fraction


func _layout_leaves() -> void:
	var guard := _play_guard()
	var view := _view_rect()
	var margins := _margins(view, guard)
	for slot in LEAF_EDGES.keys():
		_place_leaf(slot, margins[str(LEAF_EDGES[slot])], str(LEAF_EDGES[slot]))


func _place_leaf(slot: String, margin: Rect2, edge: String) -> void:
	var clip: Control = _clips[slot]
	var pivot: Node2D = _pivots[slot]
	var sprite: Sprite2D = _sprites[slot]
	if sprite.texture == null or margin.size.x < 24.0 or margin.size.y < 24.0:
		clip.visible = false
		return
	var tex_size := sprite.texture.get_size()
	var swing_px := float(_params.get("sway_amplitude_px", 14.0))
	var gap := float(_params.get("guard_gap_px", 8.0))
	var pad := swing_px + gap
	var fitted := _inner_box(margin.size, edge, pad)
	if fitted.x < 8.0 or fitted.y < 8.0:
		clip.visible = false
		return
	var disp := _contain(tex_size, fitted)
	clip.visible = true
	clip.position = margin.position
	clip.size = margin.size
	var scale := disp.x / tex_size.x
	sprite.scale = Vector2(scale, scale)
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	var base := Vector2.ZERO
	var local := Vector2.ZERO
	if edge == "left":
		base = Vector2(0, margin.size.y * 0.5)
		local = Vector2(disp.x * 0.5, 0)
	elif edge == "right":
		base = Vector2(margin.size.x, margin.size.y * 0.5)
		local = Vector2(-disp.x * 0.5, 0)
	elif edge == "top":
		base = Vector2(margin.size.x * 0.5, 0)
		local = Vector2(0, disp.y * 0.5)
	else:
		base = Vector2(margin.size.x * 0.5, margin.size.y)
		local = Vector2(0, -disp.y * 0.5)
	pivot.set_meta("base_pos", base)
	pivot.position = base
	pivot.rotation = 0.0
	sprite.position = local
	sprite.modulate = _layer_modulate("front_leaves")
	var mat := sprite.material as ShaderMaterial
	if mat != null and sprite.scale.x > 0.001:
		mat.set_shader_parameter("amplitude_px", swing_px / sprite.scale.x)


func _apply_sway() -> void:
	var speed := float(_params.get("sway_speed", 0.85))
	var phases: Dictionary = _params.get("sway_phase", {})
	for slot in _pivots.keys():
		var pivot: Node2D = _pivots[slot]
		if not pivot.has_meta("base_pos"):
			continue
		var phase := float(phases.get(slot, 0.0))
		var wave := sin(_time * speed + phase)
		pivot.rotation = 0.0
		pivot.position = pivot.get_meta("base_pos")
		var sprite: Sprite2D = _sprites.get(slot)
		if sprite == null:
			continue
		var mat := sprite.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("swing", wave)


func _build_shadows(board: Node2D) -> void:
	_teardown_shadows()
	var tex := _texture("leaf_shadow")
	if tex == null:
		return
	var shader := _shadow_shader()
	var opacity := float(_params.get("shadow_opacity", 0.55))
	var world_repeat := float(_params.get("shadow_world_repeat", 512.0))
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		var dapple := LeafDapple.new()
		dapple.name = "LeafDapple"
		dapple.z_as_relative = true
		dapple.z_index = _z("leaf_shadow")
		dapple.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("shadow_tex", tex)
		mat.set_shader_parameter("opacity", opacity)
		mat.set_shader_parameter("world_repeat", world_repeat)
		mat.set_shader_parameter("origin", Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0))
		dapple.material = mat
		tile.add_child(dapple)


func _teardown_shadows() -> void:
	if _board == null:
		return
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		var dapple := tile.get_node_or_null("LeafDapple")
		if dapple == null:
			continue
		tile.remove_child(dapple)
		dapple.free()


func _shadows_match(board: Node2D) -> bool:
	if board.tiles.is_empty():
		return false
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		if tile.get_node_or_null("LeafDapple") == null:
			return false
	return true


func _shadow_shader() -> Shader:
	if _shader != null:
		return _shader
	_shader = Shader.new()
	_shader.code = SHADOW_SHADER
	return _shader


func _play_guard() -> Rect2:
	var clear := float(_params.get("fighter_clear_px", 136.0))
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for cell in _board.tiles.keys():
		var tile: Node2D = _board.tiles[cell]
		var at := tile.position
		min_x = minf(min_x, at.x - 32.0)
		max_x = maxf(max_x, at.x + 32.0)
		min_y = minf(min_y, at.y - clear)
		max_y = maxf(max_y, at.y + 18.0)
	if min_x == INF:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _view_rect() -> Rect2:
	var cam := _board.get_node_or_null("BoardCamera") as Camera2D
	var view := _board.get_viewport_rect().size
	if view.x < 32.0 or view.y < 32.0:
		view = Vector2(960, 720)
	if cam == null:
		return Rect2(Vector2(-480, -360), view)
	var zoom := cam.zoom
	if zoom.x < 0.01 or zoom.y < 0.01:
		zoom = Vector2.ONE
	var size := Vector2(view.x / zoom.x, view.y / zoom.y)
	return Rect2(cam.position - size * 0.5, size)


func _margins(view: Rect2, guard: Rect2) -> Dictionary:
	var left_w := guard.position.x - view.position.x
	var right_x := guard.position.x + guard.size.x
	var right_w := view.position.x + view.size.x - right_x
	var top_h := guard.position.y - view.position.y
	var bot_y := guard.position.y + guard.size.y
	var bot_h := view.position.y + view.size.y - bot_y
	return {
		"left": Rect2(view.position.x, view.position.y, maxf(left_w, 0.0), view.size.y),
		"right": Rect2(right_x, view.position.y, maxf(right_w, 0.0), view.size.y),
		"top": Rect2(guard.position.x, view.position.y, guard.size.x, maxf(top_h, 0.0)),
		"bottom": Rect2(guard.position.x, bot_y, guard.size.x, maxf(bot_h, 0.0)),
	}


func _sprite_board_corners(sprite: Sprite2D) -> PackedVector2Array:
	var size := sprite.texture.get_size()
	var half := size * 0.5
	var locals := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var out := PackedVector2Array()
	for point in locals:
		out.append(_board.to_local(sprite.to_global(point)))
	return out


func _inside(rect: Rect2, point: Vector2) -> bool:
	return (
		point.x > rect.position.x + 0.75
		and point.x < rect.position.x + rect.size.x - 0.75
		and point.y > rect.position.y + 0.75
		and point.y < rect.position.y + rect.size.y - 0.75
	)


func _inner_box(box: Vector2, edge: String, pad: float) -> Vector2:
	var inner := box
	if edge == "left" or edge == "right":
		inner.x = maxf(box.x - pad, 0.0)
	else:
		inner.y = maxf(box.y - pad, 0.0)
	return inner


func _contain(native: Vector2, box: Vector2) -> Vector2:
	if native.x < 1.0 or native.y < 1.0 or box.x < 1.0 or box.y < 1.0:
		return Vector2.ZERO
	var scale := minf(box.x / native.x, box.y / native.y)
	scale = minf(scale, 1.0)
	return native * scale


func _back_scale(fraction: float, tex_size: Vector2, view: Vector2) -> float:
	if tex_size.x < 1.0 or tex_size.y < 1.0:
		return 1.0
	var drift := float(_params.get("pan_limit_px", 220.0)) * fraction
	return maxf((view.x + drift * 2.0) / tex_size.x, (view.y + drift * 2.0) / tex_size.y)


func _sync_cutout() -> void:
	if not _built or _sprites.is_empty():
		return
	if not _hover_locked:
		_hover_cell = _cell_near(_pointer_board())
	var points := _fighter_points()
	var packed := PackedVector2Array()
	packed.resize(MAX_FIGHTERS)
	for i in mini(points.size(), MAX_FIGHTERS):
		packed[i] = points[i]
	var hover_on := 0.0
	var hover_at := Vector2.ZERO
	if _hover_active():
		hover_on = 1.0
		hover_at = (_board.tiles[_hover_cell] as Node2D).position
	var xform := Transform2D.IDENTITY
	if _board != null:
		xform = _board.get_global_transform().affine_inverse()
	var n := float(_board_n())
	for slot in _sprites.keys():
		var sprite: Sprite2D = _sprites[slot]
		var mat := sprite.material as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("to_board_x", xform.x)
		mat.set_shader_parameter("to_board_y", xform.y)
		mat.set_shader_parameter("to_board_origin", xform.origin)
		mat.set_shader_parameter("fighter_pos", packed)
		mat.set_shader_parameter("fighter_count", mini(points.size(), MAX_FIGHTERS))
		mat.set_shader_parameter("hover_pos", hover_at)
		mat.set_shader_parameter("hover_on", hover_on)
		mat.set_shader_parameter("board_n", n)
		mat.set_shader_parameter("cell_half_x", CELL_HALF_X)
		mat.set_shader_parameter("cell_half_y", CELL_HALF_Y)
		mat.set_shader_parameter("fighter_rx", FIGHTER_RX)
		mat.set_shader_parameter("fighter_ry", FIGHTER_RY)
		mat.set_shader_parameter("fighter_lift", FIGHTER_LIFT)
		mat.set_shader_parameter("hover_hx", HOVER_HX)
		mat.set_shader_parameter("hover_hy", HOVER_HY)


func _pointer_board() -> Vector2:
	if _board == null:
		return Vector2.ZERO
	var tiles := _board.get_node_or_null("Tiles") as Node2D
	if tiles != null:
		return tiles.get_local_mouse_position()
	return _board.get_local_mouse_position()


func _cell_near(point: Vector2) -> Vector2i:
	if _board == null:
		return Vector2i(-1, -1)
	var fx := point.y / 32.0 + point.x / 64.0
	var fy := point.y / 32.0 - point.x / 64.0
	var guess := Vector2i(int(round(fx)), int(round(fy)))
	var best := Vector2i(-1, -1)
	var best_m := 2.0
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var cell := guess + Vector2i(ox, oy)
			var tile := _board.tiles.get(cell) as Node2D
			if tile == null:
				continue
			var at := tile.position
			var metric := absf(point.x - at.x) / 32.0 + absf(point.y - at.y) / 16.0
			if metric <= 1.0 and metric < best_m:
				best_m = metric
				best = cell
	return best


func _fighter_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _board == null:
		return out
	var pawns: Variant = _board.get("pawns_by_seat")
	if pawns is not Dictionary:
		return out
	var seats: Array = (pawns as Dictionary).keys()
	seats.sort()
	for seat in seats:
		var pawn := (pawns as Dictionary).get(seat) as Node2D
		if pawn == null or not is_instance_valid(pawn):
			continue
		if pawn.get("alive") == false:
			continue
		out.append(_board.to_local(pawn.global_position))
		if out.size() >= MAX_FIGHTERS:
			break
	return out


func _hover_active() -> bool:
	return _board != null and _board.tiles.has(_hover_cell)


func _board_n() -> int:
	if _board == null:
		return 0
	var n := int(_board.get("_board_size"))
	if n > 0:
		return n
	return int(round(sqrt(float(_board.tiles.size()))))


func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _drop_pointer(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_drop_pointer(child)


func _controls_ignore(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _controls_ignore(child):
			return false
	return true


func _sway_material(slot: String, edge: String) -> ShaderMaterial:
	if _sway_shader == null:
		_sway_shader = Shader.new()
		_sway_shader.code = SWAY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _sway_shader
	mat.set_shader_parameter("sway_tex", _load_tex(art_root() + slot + "_sway.png"))
	mat.set_shader_parameter("sway_dir", _sway_dir(edge))
	return mat


func _sway_dir(edge: String) -> Vector2:
	if edge == "right":
		return Vector2(-1, 0)
	if edge == "top":
		return Vector2(0, 1)
	if edge == "bottom":
		return Vector2(0, -1)
	return Vector2(1, 0)


func _layer_modulate(key: String) -> Color:
	var layers: Dictionary = _params.get("layers", {})
	var spec: Variant = layers.get(key, {})
	if spec is Dictionary:
		var raw: Variant = (spec as Dictionary).get("modulate", [])
		if raw is Array and (raw as Array).size() >= 3:
			return Color(float(raw[0]), float(raw[1]), float(raw[2]), 1.0)
	return Color.WHITE


func _apply_top_fade() -> void:
	var sprite: Sprite2D = _sprites.get("front_leaves_top")
	if sprite == null:
		return
	var tint := _layer_modulate("front_leaves")
	sprite.modulate = Color(tint.r, tint.g, tint.b, _top_fade_alpha())


func _top_fade_alpha() -> float:
	var dist := float(_params.get("top_fade_distance", 220.0))
	if dist <= 1.0 or _board == null:
		return 1.0
	var cam := _board.get_node_or_null("BoardCamera") as Camera2D
	if cam == null:
		return 1.0
	var fit: Vector2 = _board.get("_fit_camera_pos")
	var pan_y := cam.position.y - fit.y
	return clampf(1.0 - maxf(pan_y, 0.0) / dist, 0.0, 1.0)


func _leaf_covers_point(point: Vector2, images: Dictionary) -> bool:
	var here := to_local(_board.to_global(point))
	for slot in images.keys():
		var clip: Control = _clips.get(slot)
		var sprite: Sprite2D = _sprites.get(slot)
		if clip == null or sprite == null or not clip.visible:
			continue
		if sprite.modulate.a <= 0.1:
			continue
		if not Rect2(clip.position, clip.size).has_point(here):
			continue
		var local := sprite.to_local(_board.to_global(point))
		var size := sprite.texture.get_size()
		if absf(local.x) > size.x * 0.5 or absf(local.y) > size.y * 0.5:
			continue
		var image: Image = images[slot]
		var u := clampf(local.x / size.x + 0.5, 0.0, 0.999)
		var v := clampf(local.y / size.y + 0.5, 0.0, 0.999)
		var px := int(u * float(image.get_width()))
		var py := int(v * float(image.get_height()))
		if image.get_pixel(px, py).a * sprite.modulate.a > 0.1:
			return true
	return false


## Rim factor times strength. 0 inside the board and again at width_cells.
## Mirrors CONTACT_SHADER so tests can check the cells stay clear.
func contact_rim_alpha(outside: float) -> float:
	var spec: Dictionary = _params.get("contact_shadow", {})
	var strength := float(spec.get("strength", 0.36))
	var width := maxf(float(spec.get("width_cells", 0.9)), 0.05)
	var rise := _smoothstep(0.0, width * 0.18, outside)
	var fall := 1.0 - _smoothstep(width * 0.45, width, outside)
	return strength * rise * fall


func _layout_skirt() -> void:
	_ensure_skirt()
	if _skirt == null or _board == null:
		return
	var spec: Dictionary = _params.get("ground_skirt", {})
	var reach := float(spec.get("reach_cells", 0.0))
	var n := float(_board_n())
	var span := n + reach * 2.0
	_skirt.position = Vector2(0.0, (n - 1.0) * 16.0)
	_skirt.scale = Vector2(span * 64.0 / 4.0, span * 32.0 / 4.0)
	var mat := _skirt.material as ShaderMaterial
	if mat == null:
		return
	var raw: Variant = spec.get("color", [0.035, 0.062, 0.048])
	var color := Color(0.035, 0.062, 0.048)
	if raw is Array and (raw as Array).size() >= 3:
		color = Color(float(raw[0]), float(raw[1]), float(raw[2]))
	mat.set_shader_parameter("skirt_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("strength", float(spec.get("strength", 0.0)))
	mat.set_shader_parameter("board_n", n)
	mat.set_shader_parameter("reach", reach)


func _layout_contact() -> void:
	_ensure_contact()
	if _contact == null or _board == null:
		return
	var spec: Dictionary = _params.get("contact_shadow", {})
	var width := maxf(float(spec.get("width_cells", 0.9)), 0.05)
	var n := float(_board_n())
	var span := n + width * 2.0
	_contact.position = Vector2(0.0, (n - 1.0) * 16.0)
	_contact.scale = Vector2(span * 64.0 / 4.0, span * 32.0 / 4.0)
	var mat := _contact.material as ShaderMaterial
	if mat == null:
		return
	var raw: Variant = spec.get("color", [0.02, 0.04, 0.03])
	var color := Color(0.02, 0.04, 0.03)
	if raw is Array and (raw as Array).size() >= 3:
		color = Color(float(raw[0]), float(raw[1]), float(raw[2]))
	mat.set_shader_parameter("shadow_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("strength", float(spec.get("strength", 0.36)))
	mat.set_shader_parameter("board_n", n)
	mat.set_shader_parameter("width", width)


func _ensure_contact() -> void:
	if _contact != null and is_instance_valid(_contact):
		return
	_contact = Sprite2D.new()
	_contact.name = "ContactShadow"
	_contact.centered = true
	_contact.z_as_relative = false
	_contact.z_index = _z("contact_shadow")
	_contact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_contact.texture = ImageTexture.create_from_image(image)
	if _contact_shader == null:
		_contact_shader = Shader.new()
		_contact_shader.code = CONTACT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _contact_shader
	_contact.material = mat
	add_child(_contact)


func _ensure_skirt() -> void:
	if _skirt != null and is_instance_valid(_skirt):
		return
	_skirt = Sprite2D.new()
	_skirt.name = "GroundSkirt"
	_skirt.centered = true
	_skirt.z_as_relative = false
	_skirt.z_index = _z("ground_skirt")
	_skirt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_skirt.texture = ImageTexture.create_from_image(image)
	if _skirt_shader == null:
		_skirt_shader = Shader.new()
		_skirt_shader.code = SKIRT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _skirt_shader
	_skirt.material = mat
	add_child(_skirt)


func _z(key: String) -> int:
	var table: Dictionary = _params.get("z_order", {})
	return int(table.get(key, 0))


func _texture(slot: String) -> Texture2D:
	return _load_tex(resolve_slot(slot))


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	return load(path) as Texture2D
