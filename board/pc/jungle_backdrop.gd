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
uniform float opacity = 0.32;
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
const SWAY_SHADER := """shader_type canvas_item;
uniform sampler2D sway_tex : filter_linear, repeat_disable;
uniform float swing = 0.0;
uniform vec2 sway_dir = vec2(1.0, 0.0);
uniform float amplitude_px = 16.0;
void vertex() {
	float weight = texture(sway_tex, UV).r;
	VERTEX += sway_dir * swing * amplitude_px * weight;
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
	_apply_sway()


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
		var scale := _back_scale(slot, art.texture.get_size(), view)
		art.scale = Vector2(scale, scale)
		var factor := float(factors.get(slot, 0.2))
		art.position = -pan * (1.0 - factor)


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
	var opacity := float(_params.get("shadow_opacity", 0.32))
	var world_repeat := float(_params.get("shadow_world_repeat", 512.0))
	for cell in board.tiles.keys():
		var tile: Node = board.tiles[cell]
		var dapple := LeafDapple.new()
		dapple.name = "LeafDapple"
		dapple.z_as_relative = true
		dapple.z_index = _z("leaf_shadow")
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


func _back_scale(slot: String, tex_size: Vector2, view: Vector2) -> float:
	var cover := maxf(view.x / tex_size.x, view.y / tex_size.y)
	var slots: Dictionary = _params.get("slots", {})
	var spec: Dictionary = slots.get(slot, {})
	if str(spec.get("fit", "")) == "bleed":
		return cover * float(spec.get("bleed", 1.35))
	return maxf(1.0, cover) * float(spec.get("extra_scale", 1.06))


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


func _z(key: String) -> int:
	var table: Dictionary = _params.get("z_order", {})
	return int(table.get(key, 0))


func _texture(slot: String) -> Texture2D:
	return _load_tex(resolve_slot(slot))


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	return load(path) as Texture2D
