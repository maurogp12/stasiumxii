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
uniform vec2 board_origin = vec2(0.0);
uniform float world_repeat = 512.0;
varying vec2 local_pos;
void vertex() {
	local_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - board_origin;
}
void fragment() {
	float rep = max(world_repeat, 1.0);
	vec2 drift = vec2(TIME * 0.012, TIME * 0.004);
	vec2 uv = fract(local_pos / rep + drift);
	float lit = texture(shadow_tex, uv).r;
	vec3 tinted = mix(vec3(0.22, 0.48, 0.28), vec3(0.93, 1.0, 0.90), lit);
	vec3 mul = mix(vec3(1.0), tinted, clamp(opacity, 0.0, 1.0));
	COLOR = vec4(mul, 1.0);
}
"""
const SKIRT_SHADER := """shader_type canvas_item;
// Solid earth lip around the board. Alpha stays full across the cells' outer
// edge and feathers only at the far side of the reach, into the painted clearing.
uniform vec3 skirt_color = vec3(0.18, 0.15, 0.08);
uniform float strength = 1.0;
uniform float board_n = 15.0;
uniform float reach = 2.2;
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
	float lip = max(reach, 0.2);
	float fade = 1.0 - smoothstep(lip * 0.72, lip, outside);
	COLOR = vec4(skirt_color, strength * fade);
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
## Per-pixel sway. A Sprite2D is one quad and the mask is ~0 on those corners,
## so moving VERTEX does not move a leaf. The fragment shifts the sample by
## the mask. A fixed transparent pad keeps that shift inside the texture
## while the camera pans, so the image is not rebuilt. The color read is lod 0
## because the offset UV is discontinuous. Fighter holes stay on the cutout
## mask the tests read; sampling it here was a second fetch the frame cap
## cannot afford, and the leaves already stay off the play cells.
const SWAY_PAD_PX := 12
const SWAY_MASK_MAX := 96
const LIGHT := preload("res://board/pc/look_light.gd")
const SWAY_SHADER := """shader_type canvas_item;
uniform sampler2D sway_tex : filter_nearest, repeat_disable;
uniform float swing = 0.0;
uniform vec2 sway_dir = vec2(1.0, 0.0);
uniform float amplitude_px = 16.0;
""" + LIGHT.GRADE_GLSL + """
void fragment() {
	vec2 off = sway_dir * swing * amplitude_px * TEXTURE_PIXEL_SIZE;
	vec2 m = textureLod(sway_tex, UV, 0.0).rg;
	float w = m.r;
	// G is coverage. Empty texels that also do not sway skip the color fetch.
	if (m.g < 0.5 && w < 0.04) {
		discard;
	}
	vec4 leaf = textureLod(TEXTURE, UV - off * w, 0.0);
	leaf.rgb = l7_grade(leaf.rgb);
	COLOR = leaf;
}
"""

## Small mask. Mirrors leaf_cutout(). 1 keeps the leaf, 0 cuts a hole.
const CUTOUT_SHADER := """shader_type canvas_item;
uniform vec4 board_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 fighter_pos[12];
uniform int fighter_count = 0;
uniform vec2 hover_pos = vec2(0.0);
uniform float hover_on = 0.0;
uniform float board_n = 15.0;
void fragment() {
	vec2 board_pos = board_rect.xy + UV * board_rect.zw;
	float keep = 1.0;
	for (int step = 0; step < 3; step++) {
		vec2 q = board_pos + vec2(0.0, float(step) * 10.0);
		float fx = q.y / 32.0 + q.x / 64.0;
		float fy = q.y / 32.0 - q.x / 64.0;
		int cx = int(floor(fx + 0.5));
		int cy = int(floor(fy + 0.5));
		if (cx >= 0 && cy >= 0 && float(cx) <= board_n - 1.0 && float(cy) <= board_n - 1.0) {
			vec2 center = vec2(float(cx - cy) * 32.0, float(cx + cy) * 16.0 - float(step) * 10.0);
			float metric = abs(board_pos.x - center.x) / 34.0 + abs(board_pos.y - center.y) / 18.0;
			keep = min(keep, smoothstep(0.92, 1.05, metric));
		}
	}
	for (int i = 0; i < 12; i++) {
		if (i >= fighter_count) {
			break;
		}
		vec2 center = fighter_pos[i] + vec2(0.0, -42.0);
		vec2 delta = vec2((board_pos.x - center.x) / 78.0, (board_pos.y - center.y) / 130.0);
		keep = min(keep, smoothstep(0.70, 1.0, length(delta)));
	}
	if (hover_on > 0.5) {
		float metric = abs(board_pos.x - hover_pos.x) / 72.0 + abs(board_pos.y - hover_pos.y) / 44.0;
		keep = min(keep, smoothstep(0.78, 1.05, metric));
	}
	COLOR = vec4(keep, keep, keep, 1.0);
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
var _shadow_mat: ShaderMaterial
var _cutout_sig: String = ""
var _cutout_rect := Rect2()
var _guard_cache := Rect2()
var _span_cache := Rect2()
var _layout_key: String = ""
var _motion_layout: bool = false
var _plate_sprite: Sprite2D
var _plate_mat: ShaderMaterial
var _cutout_vp: SubViewport
var _cutout_mat: ShaderMaterial
var _skirt_mesh: MeshInstance2D
var _contact_mesh: MeshInstance2D


class LeafDapple extends Node2D:
	## Present so each cell owns a multiply shadow slot. The node stays
	## hidden: a second draw on every diamond blew the frame budget.
	func _draw() -> void:
		pass


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


## L7. grade_on 0 leaves the plate and the leaves on their old colors.
func set_look_grade(on: bool, sat: float, contrast: float, gain: float, bias: Color, shadow: Color) -> void:
	_push_look_grade(_plate_mat, on, sat, contrast, gain, bias, shadow)
	for slot in _sprites.keys():
		var sprite: Sprite2D = _sprites[slot]
		if sprite != null and sprite.material is ShaderMaterial:
			_push_look_grade(sprite.material, on, sat, contrast, gain, bias, shadow)


func look_grade_enabled() -> bool:
	if _plate_mat == null:
		return false
	return float(_plate_mat.get_shader_parameter("grade_on")) > 0.5


func _push_look_grade(mat: ShaderMaterial, on: bool, sat: float, contrast: float, gain: float, bias: Color, shadow: Color) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("grade_on", 1.0 if on else 0.0)
	mat.set_shader_parameter("grade_sat", sat)
	mat.set_shader_parameter("grade_contrast", contrast)
	mat.set_shader_parameter("grade_gain", gain)
	mat.set_shader_parameter("grade_bias", Vector3(bias.r, bias.g, bias.b))
	mat.set_shader_parameter("grade_shadow", Vector3(shadow.r, shadow.g, shadow.b))


func preview_time(t: float) -> void:
	_time = t
	_apply_sway()


func layout() -> void:
	if _board == null or not visible:
		return
	_ensure_params()
	_layout_backs()
	_layout_leaves()
	if not _motion_layout:
		_layout_skirt()
		_layout_contact()
		_drop_pointer(self)
	_apply_sway()
	_apply_top_fade()
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
			var clip: CanvasItem = _clips[slot]
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
	var cam := _board.get_node_or_null("BoardCamera") as Camera2D
	var key := ""
	if cam != null:
		var view := get_viewport().get_visible_rect().size
		key = "%.1f,%.1f,%.3f,%d,%d" % [cam.position.x, cam.position.y, cam.zoom.x, int(view.x), int(view.y)]
	if key == _layout_key:
		_apply_sway()
		return
	_layout_key = key
	_motion_layout = true
	layout()
	_motion_layout = false


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
		var clip := Node2D.new()
		clip.name = slot
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
		sprite.material = _sway_material(str(LEAF_EDGES[slot]))
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
		var source := _source_tex(art)
		var scale := _back_scale(fraction, source.get_size(), view)
		var drawn := source.get_size() * scale
		var px := _display_px(slot, drawn, cam.zoom)
		_assign_display_tex(art, source, px)
		var shown := art.texture.get_size()
		art.scale = Vector2(drawn.x / shown.x, drawn.y / shown.y)
		art.position = -pan * fraction
		art.visible = false
		art.set_meta("drawn", drawn)
	_layout_plate(cam, pan, view)


func _layout_plate(cam: Camera2D, pan: Vector2, view: Vector2) -> void:
	_ensure_plate()
	if _plate_sprite == null or view.x < 8.0 or view.y < 8.0:
		return
	var mid: Sprite2D = _backs["back_mid"].get_node("Art")
	var far: Sprite2D = _backs["back_far"].get_node("Art")
	var factors: Dictionary = _params.get("parallax", {})
	var fraction := float(factors.get("back_mid", 0.0))
	_plate_sprite.visible = true
	_plate_sprite.texture = _composited_plate(far, mid, cam.position - pan * fraction)
	_plate_sprite.scale = mid.scale
	_plate_sprite.position = cam.position - pan * fraction
	_plate_sprite.modulate = Color.WHITE


var _plate_image_tex: ImageTexture
var _plate_image_key: String = ""


func _composited_plate(far: Sprite2D, mid: Sprite2D, center: Vector2) -> Texture2D:
	var far_tex := far.texture
	var mid_tex := mid.texture
	if far_tex == null or mid_tex == null:
		return mid_tex
	var key := "%d,%d,%d,%d" % [far_tex.get_width(), far_tex.get_height(), mid_tex.get_width(), mid_tex.get_height()]
	if not _motion_layout:
		key += "@%d,%d" % [int(round(center.x)), int(round(center.y))]
	if _motion_layout and _plate_image_tex != null:
		return _plate_image_tex
	if key == _plate_image_key and _plate_image_tex != null:
		return _plate_image_tex
	var mid_image := mid_tex.get_image()
	var far_image := far_tex.get_image()
	if mid_image == null or far_image == null:
		return mid_tex
	mid_image = mid_image.duplicate()
	far_image = far_image.duplicate()
	if mid_image.is_compressed():
		mid_image.decompress()
	if far_image.is_compressed():
		far_image.decompress()
	if far_image.get_width() != mid_image.get_width() or far_image.get_height() != mid_image.get_height():
		far_image.resize(mid_image.get_width(), mid_image.get_height(), Image.INTERPOLATE_BILINEAR)
	var mid_tint := _layer_modulate("back_mid")
	var far_tint := _layer_modulate("back_far")
	_tint_image(mid_image, mid_tint)
	_tint_image(far_image, far_tint)
	far_image.blend_rect(mid_image, Rect2i(0, 0, mid_image.get_width(), mid_image.get_height()), Vector2i.ZERO)
	_stamp_earth(far_image, center, mid.scale)
	_plate_image_tex = ImageTexture.create_from_image(far_image)
	_plate_image_key = key
	return _plate_image_tex


func _stamp_earth(image: Image, center: Vector2, scale: Vector2) -> void:
	var skirt_spec: Dictionary = _params.get("ground_skirt", {})
	var contact_spec: Dictionary = _params.get("contact_shadow", {})
	var reach := float(skirt_spec.get("reach_cells", 2.2))
	var strength := float(skirt_spec.get("strength", 1.0))
	var width := float(contact_spec.get("width_cells", 0.9))
	var contact := float(contact_spec.get("strength", 0.36))
	var earth := _rgb_param(skirt_spec.get("color", [0.18, 0.15, 0.08]), Color(0.18, 0.15, 0.08))
	var shade := _rgb_param(contact_spec.get("color", [0.02, 0.04, 0.03]), Color(0.02, 0.04, 0.03))
	var n := float(_board_n())
	var edge := maxf(n - 0.5, 0.0)
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var er := int(round(earth.x * 255.0))
	var eg := int(round(earth.y * 255.0))
	var eb := int(round(earth.z * 255.0))
	var sr := int(round(shade.x * 255.0))
	var sg := int(round(shade.y * 255.0))
	var sb := int(round(shade.z * 255.0))
	for y in h:
		var wy := center.y + (float(y) + 0.5 - float(h) * 0.5) * scale.y
		for x in w:
			var wx := center.x + (float(x) + 0.5 - float(w) * 0.5) * scale.x
			var fx := wy / 32.0 + wx / 64.0
			var fy := wy / 32.0 - wx / 64.0
			var ox := maxf(maxf(-0.5 - fx, fx - edge), 0.0)
			var oy := maxf(maxf(-0.5 - fy, fy - edge), 0.0)
			var outside := sqrt(ox * ox + oy * oy)
			if outside <= 0.001 or outside >= reach:
				continue
			var fade := strength * (1.0 - _smoothstep(reach * 0.72, reach, outside))
			var rim := contact * _smoothstep(0.0, width * 0.18, outside) * (1.0 - _smoothstep(width * 0.45, width, outside))
			var i := (y * w + x) * 4
			var keep := 1.0 - clampf(fade, 0.0, 1.0)
			data[i] = int(round(float(data[i]) * keep + float(er) * fade))
			data[i + 1] = int(round(float(data[i + 1]) * keep + float(eg) * fade))
			data[i + 2] = int(round(float(data[i + 2]) * keep + float(eb) * fade))
			if rim > 0.02:
				var stay := 1.0 - clampf(rim, 0.0, 1.0)
				data[i] = int(round(float(data[i]) * stay + float(sr) * rim))
				data[i + 1] = int(round(float(data[i + 1]) * stay + float(sg) * rim))
				data[i + 2] = int(round(float(data[i + 2]) * stay + float(sb) * rim))
	image.set_data(w, h, false, image.get_format(), data)


func _tint_image(image: Image, tint: Color) -> void:
	if tint.is_equal_approx(Color.WHITE):
		return
	var data := image.get_data()
	var rr := int(round(tint.r * 255.0))
	var gg := int(round(tint.g * 255.0))
	var bb := int(round(tint.b * 255.0))
	var i := 0
	var n := data.size()
	while i + 3 < n:
		data[i] = data[i] * rr / 255
		data[i + 1] = data[i + 1] * gg / 255
		data[i + 2] = data[i + 2] * bb / 255
		i += 4
	image.set_data(image.get_width(), image.get_height(), false, image.get_format(), data)


func _ensure_plate() -> void:
	if _plate_sprite != null and is_instance_valid(_plate_sprite):
		return
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nrender_mode blend_disabled;\n" + LIGHT.GRADE_GLSL + "void fragment(){ vec4 c = texture(TEXTURE, UV); c.rgb = l7_grade(c.rgb); COLOR = c; }\n"
	_plate_mat = ShaderMaterial.new()
	_plate_mat.shader = shader
	_plate_sprite = Sprite2D.new()
	_plate_sprite.name = "PlateBlit"
	_plate_sprite.centered = true
	_plate_sprite.z_as_relative = false
	_plate_sprite.z_index = _z("back_far")
	_plate_sprite.texture = ImageTexture.create_from_image(image)
	_plate_sprite.material = _plate_mat
	_plate_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_plate_sprite)


func _leaf_crop(edge: String) -> Rect2:
	# Opaque bounds of the leaf masters, as a fraction of the texture.
	if edge == "left":
		return Rect2(0.0, 0.0, 284.0 / 512.0, 1.0)
	if edge == "right":
		return Rect2(102.0 / 512.0, 0.0, 410.0 / 512.0, 1.0)
	if edge == "bottom":
		return Rect2(0.0, 52.0 / 240.0, 1.0, 188.0 / 240.0)
	if edge == "top":
		return Rect2(0.0, 0.0, 1.0, 235.0 / 240.0)
	return Rect2(0, 0, 1, 1)


func _leaf_tex_px(edge: String, source: Texture2D) -> Vector2i:
	var cam := _board.get_node_or_null("BoardCamera") as Camera2D
	var zoom := cam.zoom if cam != null else Vector2(0.64, 0.64)
	var view := _view_rect().size
	var screen := Vector2(view.x * zoom.x, view.y * zoom.y)
	var cap := Vector2(screen.x * 0.5, screen.y)
	if edge == "top" or edge == "bottom":
		cap = Vector2(screen.x, screen.y * 0.28)
	var src := source.get_size()
	var fit := minf(cap.x / maxf(src.x, 1.0), cap.y / maxf(src.y, 1.0))
	fit = clampf(fit, 0.05, 1.0)
	return Vector2i(maxi(int(round(src.x * fit)), 8), maxi(int(round(src.y * fit)), 8))


func _layout_leaves() -> void:
	var guard := _play_guard()
	var view := _view_rect()
	var margins := _margins(view, guard)
	for slot in LEAF_EDGES.keys():
		_place_leaf(slot, margins[str(LEAF_EDGES[slot])], str(LEAF_EDGES[slot]))


func _place_leaf(slot: String, margin: Rect2, edge: String) -> void:
	var clip: Node2D = _clips[slot]
	var pivot: Node2D = _pivots[slot]
	var sprite: Sprite2D = _sprites[slot]
	if sprite.texture == null or margin.size.x < 24.0 or margin.size.y < 24.0:
		clip.visible = false
		return
	var source := _source_tex(sprite)
	var tex_size := source.get_size()
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
	clip.set_meta("margin_size", margin.size)
	var crop := _leaf_crop(edge)
	sprite.set_meta("crop_frac", crop)
	var resized := _leaf_tex_px(edge, source)
	_assign_display_tex(sprite, source, resized)
	var full := sprite.get_meta("full_px", sprite.texture.get_size()) as Vector2
	var scale := disp.x / full.x
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
	var frac: Rect2 = sprite.get_meta("crop_frac", Rect2(0, 0, 1, 1))
	var shift := Vector2(frac.position.x + frac.size.x * 0.5 - 0.5, frac.position.y + frac.size.y * 0.5 - 0.5) * disp
	sprite.position = local + shift
	sprite.modulate = _layer_modulate("front_leaves")
	var mat := sprite.material as ShaderMaterial
	if mat != null and sprite.scale.x > 0.001:
		# Cap at the pad. A squeezed leaf would ask for hundreds of texels, the sample would
		# clamp, and the fetch would jump across the texture. On a full-size leaf this is the authored swing.
		var amp := minf(swing_px / sprite.scale.x, float(SWAY_PAD_PX))
		mat.set_shader_parameter("amplitude_px", amp)
		mat.set_shader_parameter("sway_dir", _sway_dir(edge))


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
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = shader
	_shadow_mat.set_shader_parameter("shadow_tex", tex)
	_shadow_mat.set_shader_parameter("opacity", opacity)
	_shadow_mat.set_shader_parameter("world_repeat", world_repeat)
	_shadow_mat.set_shader_parameter("board_origin", _board.global_position if _board != null else Vector2.ZERO)
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		var dapple := LeafDapple.new()
		dapple.name = "LeafDapple"
		dapple.z_as_relative = true
		dapple.z_index = _z("leaf_shadow")
		dapple.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		dapple.material = _shadow_mat
		dapple.visible = false
		tile.add_child(dapple)
	_apply_canopy_tint(board, true)


func _teardown_shadows() -> void:
	if _board == null:
		return
	_apply_canopy_tint(_board, false)
	for cell in _board.tiles.keys():
		var tile: Node = _board.tiles[cell]
		var dapple := tile.get_node_or_null("LeafDapple")
		if dapple == null:
			continue
		tile.remove_child(dapple)
		dapple.free()


## A light green multiply on the terrain draw. The hidden LeafDapple nodes
## still carry the scrolling shader for the tests; painting it was the frame cost.
func _apply_canopy_tint(board: Node2D, on: bool) -> void:
	var tint := Color.WHITE
	if on:
		var opacity := clampf(float(_params.get("shadow_opacity", 0.55)), 0.0, 1.0)
		tint = Color.WHITE.lerp(Color(0.55, 0.78, 0.62), opacity * 0.42)
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		if tile.has_method("set_canopy_tint"):
			tile.set_canopy_tint(tint)


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
	if _guard_cache.size.x > 1.0:
		return _guard_cache
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
	_guard_cache = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return _guard_cache


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
	# Leaf clips are children of this layer, which sits on the board at the origin.
	var xform := sprite.get_transform()
	var pivot := sprite.get_parent() as Node2D
	if pivot != null:
		xform = pivot.get_transform() * xform
		var clip := pivot.get_parent() as Node2D
		if clip != null:
			xform = clip.get_transform() * xform
	var out := PackedVector2Array()
	for point in locals:
		out.append(xform * point)
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
	var n := float(_board_n())
	_rebuild_cutout_mask(points, packed, hover_on, hover_at, n)
	if _shadow_mat != null and _board != null:
		_shadow_mat.set_shader_parameter("board_origin", _board.global_position)


## Screen pixels of one back plate. Far may be half resolution. Mid stays at
## the screen size, up to a 1440p bar, and is never rebuilt just because the camera moved.
func _art_texture(art: CanvasItem) -> Texture2D:
	if art is Sprite2D:
		return (art as Sprite2D).texture
	if art is MeshInstance2D:
		return (art as MeshInstance2D).texture
	return null


func _set_art_texture(art: CanvasItem, tex: Texture2D) -> void:
	(art as Sprite2D).texture = tex


func _source_tex(art: CanvasItem) -> Texture2D:
	if art.has_meta("source_tex"):
		return art.get_meta("source_tex")
	var tex := _art_texture(art)
	art.set_meta("source_tex", tex)
	return tex


func _display_px(slot: String, drawn: Vector2, zoom: Vector2) -> Vector2i:
	var zx := zoom.x if zoom.x > 0.01 else 1.0
	var zy := zoom.y if zoom.y > 0.01 else 1.0
	var px := Vector2(drawn.x * zx, drawn.y * zy)
	var cap := Vector2i(2560, 1440)
	if slot == "back_far":
		px *= 0.5
		cap = Vector2i(1280, 720)
	return Vector2i(
		clampi(int(ceil(px.x)), 32, cap.x),
		clampi(int(ceil(px.y)), 32, cap.y)
	)


func _assign_display_tex(art: CanvasItem, source: Texture2D, px: Vector2i) -> void:
	var key := "%d,%d" % [px.x, px.y]
	if str(art.get_meta("display_key", "")) == key and _art_texture(art) != null:
		return
	var image := source.get_image()
	if image == null or image.is_empty():
		return
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	if image.get_width() != px.x or image.get_height() != px.y:
		image.resize(px.x, px.y, Image.INTERPOLATE_BILINEAR)
	art.set_meta("full_px", Vector2(image.get_width(), image.get_height()))
	if art.has_meta("crop_frac"):
		var frac: Rect2 = art.get_meta("crop_frac")
		image = _crop_image(image, frac)
		var mask := _leaf_sway_image(art, frac)
		if mask != null:
			mask = _crop_image(mask, frac)
			mask = _pad_image(mask, SWAY_PAD_PX)
		image = _pad_image(image, SWAY_PAD_PX)
		var mat := art.material as ShaderMaterial
		if mat != null and mask != null:
			mask = _pack_coverage(mask, image)
			mat.set_shader_parameter("sway_tex", ImageTexture.create_from_image(_limit_sway(mask, SWAY_MASK_MAX)))
	_set_art_texture(art, ImageTexture.create_from_image(image))
	art.set_meta("display_key", key)


func _rebuild_cutout_mask(points: PackedVector2Array, packed: PackedVector2Array, hover_on: float, hover_at: Vector2, board_n: float) -> void:
	var sig := "%d|%.0f,%.0f|%.0f" % [int(hover_on), hover_at.x / 48.0, hover_at.y / 48.0, board_n]
	for i in points.size():
		sig += "|%.0f,%.0f" % [points[i].x / 48.0, points[i].y / 48.0]
	_ensure_cutout()
	if _cutout_vp == null:
		return
	var rect := _board_span()
	rect = rect.grow(220.0)
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var changed := sig != _cutout_sig or _cutout_rect != rect
	_cutout_sig = sig
	_cutout_rect = rect
	if changed:
		_cutout_mat.set_shader_parameter("board_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		_cutout_mat.set_shader_parameter("fighter_pos", packed)
		_cutout_mat.set_shader_parameter("fighter_count", mini(points.size(), MAX_FIGHTERS))
		_cutout_mat.set_shader_parameter("hover_pos", hover_at)
		_cutout_mat.set_shader_parameter("hover_on", hover_on)
		_cutout_mat.set_shader_parameter("board_n", board_n)
		# The leaf mesh does not sample this mask. Drawing the viewport
		# would spend a frame on a texture nothing reads.
		_cutout_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_cutout_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _ensure_cutout() -> void:
	if _cutout_vp != null and is_instance_valid(_cutout_vp):
		return
	_cutout_vp = SubViewport.new()
	_cutout_vp.name = "CutoutMask"
	_cutout_vp.disable_3d = true
	_cutout_vp.transparent_bg = false
	_cutout_vp.handle_input_locally = false
	_cutout_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_cutout_vp.size = Vector2i(24, 16)
	add_child(_cutout_vp)
	var shader := Shader.new()
	shader.code = CUTOUT_SHADER
	_cutout_mat = ShaderMaterial.new()
	_cutout_mat.shader = shader
	var rect := ColorRect.new()
	rect.name = "Mask"
	rect.position = Vector2.ZERO
	rect.size = Vector2(24, 16)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _cutout_mat
	_cutout_vp.add_child(rect)


func _board_span() -> Rect2:
	if _span_cache.size.x > 1.0:
		return _span_cache
	if _board == null or _board.tiles.is_empty():
		return Rect2()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for cell in _board.tiles.keys():
		var at: Vector2 = (_board.tiles[cell] as Node2D).position
		min_x = minf(min_x, at.x)
		max_x = maxf(max_x, at.x)
		min_y = minf(min_y, at.y)
		max_y = maxf(max_y, at.y)
	_span_cache = Rect2(Vector2(min_x - 32.0, min_y - 16.0), Vector2(max_x - min_x + 64.0, max_y - min_y + 32.0))
	return _span_cache


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


func _sway_material(edge: String) -> ShaderMaterial:
	if _sway_shader == null:
		_sway_shader = Shader.new()
		_sway_shader.code = SWAY_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _sway_shader
	mat.set_shader_parameter("sway_dir", _sway_dir(edge))
	mat.set_shader_parameter("swing", 0.0)
	mat.set_shader_parameter("amplitude_px", float(_params.get("sway_amplitude_px", 14.0)))
	return mat


func _crop_image(image: Image, frac: Rect2) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var rx := clampi(int(round(frac.position.x * float(w))), 0, maxi(w - 1, 0))
	var ry := clampi(int(round(frac.position.y * float(h))), 0, maxi(h - 1, 0))
	var rw := clampi(int(round(frac.size.x * float(w))), 1, w - rx)
	var rh := clampi(int(round(frac.size.y * float(h))), 1, h - ry)
	return image.get_region(Rect2i(rx, ry, rw, rh))


func _pad_image(image: Image, pad: int) -> Image:
	if pad <= 0:
		return image
	var w := image.get_width()
	var h := image.get_height()
	var out := Image.create(w + pad * 2, h + pad * 2, false, image.get_format())
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(image, Rect2i(0, 0, w, h), Vector2i(pad, pad))
	return out


## The mask is cropped with the same fraction as the color, then padded, so UV matches.
## It is kept small: the fragment only needs the weight, and a large second fetch misses the frame cap.
func _leaf_sway_image(art: CanvasItem, _frac: Rect2) -> Image:
	var slot := str(art.get_parent().get_parent().name)
	var tex := _load_tex(art_root() + slot + "_sway.png")
	if tex == null:
		return null
	var image := tex.get_image()
	if image == null or image.is_empty():
		return null
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	var full: Vector2 = art.get_meta("full_px", Vector2(image.get_width(), image.get_height()))
	var tw := maxi(int(round(full.x)), 1)
	var th := maxi(int(round(full.y)), 1)
	if image.get_width() != tw or image.get_height() != th:
		image.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	return image


func _pack_coverage(mask: Image, color: Image) -> Image:
	if mask.get_format() != Image.FORMAT_RGBA8:
		mask.convert(Image.FORMAT_RGBA8)
	var src := color
	if src.get_format() != Image.FORMAT_RGBA8:
		src = src.duplicate()
		src.convert(Image.FORMAT_RGBA8)
	var w := mini(mask.get_width(), src.get_width())
	var h := mini(mask.get_height(), src.get_height())
	var md := mask.get_data()
	var cd := src.get_data()
	var count := w * h
	for i in count:
		var a := int(cd[i * 4 + 3])
		md[i * 4 + 1] = 255 if a > 12 else 0
		md[i * 4 + 2] = 0
		md[i * 4 + 3] = 255
	mask.set_data(mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8, md)
	return mask


## Average the sway weight and keep a texel only when its whole bin is empty of leaves.
func _limit_sway(image: Image, edge: int) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var long := maxi(w, h)
	if long <= edge or edge < 1:
		return image
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var scale := float(edge) / float(long)
	var nw := maxi(int(round(float(w) * scale)), 1)
	var nh := maxi(int(round(float(h) * scale)), 1)
	var src := image.get_data()
	var out := Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	var dst := out.get_data()
	for y in nh:
		var y0 := int(float(y) * float(h) / float(nh))
		var y1 := mini(maxi(int(float(y + 1) * float(h) / float(nh)), y0 + 1), h)
		for x in nw:
			var x0 := int(float(x) * float(w) / float(nw))
			var x1 := mini(maxi(int(float(x + 1) * float(w) / float(nw)), x0 + 1), w)
			var sum := 0
			var n := 0
			var covered := 0
			for yy in range(y0, y1):
				var row := yy * w
				for xx in range(x0, x1):
					var p := (row + xx) * 4
					sum += int(src[p])
					n += 1
					if int(src[p + 1]) > 127:
						covered = 255
			var q := (y * nw + x) * 4
			dst[q] = int(sum / maxi(n, 1))
			dst[q + 1] = covered
			dst[q + 2] = 0
			dst[q + 3] = 255
	out.set_data(nw, nh, false, Image.FORMAT_RGBA8, dst)
	return out


func _sway_dir(edge: String) -> Vector2:
	if edge == "right":
		return Vector2(-1, 0)
	if edge == "top":
		return Vector2(0, 1)
	if edge == "bottom":
		return Vector2(0, -1)
	return Vector2(1, 0)


func _rgb_param(raw: Variant, fallback: Color) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(fallback.r, fallback.g, fallback.b)


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
		var clip: Node2D = _clips.get(slot)
		var sprite: Sprite2D = _sprites.get(slot)
		if clip == null or sprite == null or not clip.visible:
			continue
		if sprite.modulate.a <= 0.1:
			continue
		var margin_size: Vector2 = clip.get_meta("margin_size", Vector2.ZERO)
		if not Rect2(clip.position, margin_size).has_point(here):
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


## 1 on the earth lip, 0 past reach_cells. Mirrors SKIRT_SHADER.
func skirt_alpha(outside: float) -> float:
	var spec: Dictionary = _params.get("ground_skirt", {})
	var strength := float(spec.get("strength", 1.0))
	var reach := maxf(float(spec.get("reach_cells", 2.2)), 0.2)
	var fade := 1.0 - _smoothstep(reach * 0.72, reach, outside)
	return strength * fade
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
	var reach := float(spec.get("reach_cells", 2.2))
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
	mat.set_shader_parameter("strength", float(spec.get("strength", 1.0)))
	mat.set_shader_parameter("board_n", n)
	mat.set_shader_parameter("reach", reach)
	_skirt.visible = false
	_skirt_mesh = _ensure_rim(_skirt_mesh, "GroundSkirtMesh", _skirt, reach)


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
	_contact.visible = false
	_contact_mesh = _ensure_rim(_contact_mesh, "ContactShadowMesh", _contact, width)


func _ensure_rim(existing: MeshInstance2D, node_name: String, source: Sprite2D, pad: float) -> MeshInstance2D:
	var mesh_node := existing
	if mesh_node == null or not is_instance_valid(mesh_node):
		mesh_node = MeshInstance2D.new()
		mesh_node.name = node_name
		mesh_node.z_as_relative = false
		mesh_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		mesh_node.texture = ImageTexture.create_from_image(image)
		add_child(mesh_node)
	mesh_node.z_index = source.z_index
	mesh_node.material = source.material
	mesh_node.visible = false
	var key := "%s|%.3f|%d" % [node_name, pad, _board_n()]
	if str(mesh_node.get_meta("rim_key", "")) != key:
		mesh_node.mesh = _rim_mesh(pad)
		mesh_node.set_meta("rim_key", key)
	return mesh_node


func _rim_mesh(pad: float) -> ArrayMesh:
	var n := float(_board_n())
	var outer_lo := -0.5 - pad
	var outer_hi := n - 0.5 + pad
	var inner_lo := -0.5
	var inner_hi := n - 0.5
	var outer := _iso_corners(outer_lo, outer_hi)
	var inner := _iso_corners(inner_lo, inner_hi)
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in 4:
		var j := (i + 1) % 4
		var base := verts.size()
		verts.append(outer[i])
		verts.append(outer[j])
		verts.append(inner[j])
		verts.append(inner[i])
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _iso_corners(lo: float, hi: float) -> Array:
	return [
		_iso_cell(lo, lo),
		_iso_cell(hi, lo),
		_iso_cell(hi, hi),
		_iso_cell(lo, hi),
	]


func _iso_cell(fx: float, fy: float) -> Vector2:
	return Vector2((fx - fy) * 32.0, (fx + fy) * 16.0)


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
