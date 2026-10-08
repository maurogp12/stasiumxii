extends RefCounted

## Windmere decoration (Mauro, option C + frozen-colosseum crowd).
## Nothing here changes a cell, a rule, or the camera. The plate already
## carries the shaded snow and the ice; these sprites sharpen the flat cells
## and hang the crowd, props, and weather around the board.

const ROOT := "res://art/windmere/alive/"
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const BOARD_SCALE := 960.0 / 2625.0
## 2400x1080 crowd, centered, mapped so image (1199, 619.5) is world (0, 224).
const CROWD_POS := Vector2(BOARD_SCALE, 224.0 + (540.0 - 619.5) * BOARD_SCALE)
const ICICLE_FPS := 5.0

const BOB_CODE := "shader_type canvas_item;
uniform float amp = 5.5;
uniform float period = 3.6;
void vertex() {
	float band = floor(UV.x * 8.0);
	float phase = band * 0.3;
	VERTEX.y += sin((TIME + phase) * 6.28318530718 / period) * amp;
}
"

const SWAY_CODE := "shader_type canvas_item;
uniform float width = 192.0;
void vertex() {
	float along = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 3.14159265) * width * 0.035 * along;
}
"

const FLICKER_CODE := "shader_type canvas_item;
void fragment() {
	float flick = sin(TIME * 9.0) * sin(TIME * 3.7);
	COLOR.rgb *= 1.0 + 0.12 * flick;
}
"

const MIST_CODE := "shader_type canvas_item;
uniform float scroll = 0.03;
uniform float alpha_scale = 0.32;
void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x * 2.0 + TIME * scroll);
	vec4 tex = texture(TEXTURE, uv);
	COLOR = vec4(tex.rgb, tex.a * alpha_scale);
}
"

static var _tex: Dictionary = {}
static var _ice: Array = []
static var _snow: Array = []
static var _flakes: Array = []
static var _icicles: SpriteFrames
static var _glints: SpriteFrames


static func attach(host: Node2D, room_id: String) -> void:
	if not room_id.contains("windmere"):
		return
	_ensure()
	var cells := _cells(room_id)
	var shade := _shade_for(room_id)
	_add_crowd(host)
	_add_props(host)
	_add_floors(host, cells, shade)
	_add_mist(host)
	_add_glints(host, cells)
	_add_flakes(host)


static func _ensure() -> void:
	if _ice.size() == 4:
		return
	_ice.clear()
	_snow.clear()
	_flakes.clear()
	for index in 4:
		_ice.append(_load("%sice_v%d.webpbin" % [ROOT, index + 1]))
		_snow.append(_load("%ssnow_v%d.webpbin" % [ROOT, index + 1]))
	for index in 9:
		_flakes.append(_load("%sflake_%02d.webpbin" % [ROOT, index + 1]))
	var drip := SpriteFrames.new()
	drip.add_animation("drip")
	drip.set_animation_loop("drip", true)
	drip.set_animation_speed("drip", ICICLE_FPS)
	var frames: Array = [
		_load(ROOT + "icicle_f1.webpbin"),
		_load(ROOT + "icicle_f2.webpbin"),
		_load(ROOT + "icicle_f3.webpbin"),
	]
	for index in [0, 1, 2, 1]:
		if frames[index] != null:
			drip.add_frame("drip", frames[index])
	_icicles = drip
	var twinkle := SpriteFrames.new()
	twinkle.add_animation("twinkle")
	twinkle.set_animation_loop("twinkle", false)
	twinkle.set_animation_speed("twinkle", 10.0)
	var glint: Array = [
		_load(ROOT + "glint_f1.webpbin"),
		_load(ROOT + "glint_f2.webpbin"),
		_load(ROOT + "glint_f3.webpbin"),
	]
	for index in [0, 1, 2, 1, 0]:
		if glint[index] != null:
			twinkle.add_frame("twinkle", glint[index])
	_glints = twinkle


static func _load(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			if image.detect_alpha() != Image.ALPHA_NONE:
				image.fix_alpha_edges()
			tex = ImageTexture.create_from_image(image)
	_tex[path] = tex
	return tex


static func _cells(room_id: String) -> Array:
	var path := _tags_path(room_id)
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return (parsed as Dictionary).get("cells", [])


static func _tags_path(room_id: String) -> String:
	if room_id.begins_with("stasis_"):
		return "res://art/maps/stasis_v1/%s_15x15_tags.json" % room_id.trim_prefix("stasis_")
	return "res://art/maps/arena_colosseum_v2/tiled/%s_15x15_tags.json" % room_id.trim_prefix("koliseo_")


static func _shade_for(room_id: String) -> Dictionary:
	var path := ROOT + "shade.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var room: Variant = (parsed as Dictionary).get(room_id, {})
	return room if typeof(room) == TYPE_DICTIONARY else {}


static func _add_crowd(host: Node2D) -> void:
	var back := _load(ROOT + "crowd_l1.webpbin")
	var front := _load(ROOT + "crowd_l2.webpbin")
	if back != null:
		var sprite := Sprite2D.new()
		sprite.name = "CrowdBack"
		sprite.texture = back
		sprite.centered = true
		sprite.position = CROWD_POS
		sprite.scale = Vector2(BOARD_SCALE, BOARD_SCALE)
		# Above the opaque plate (-199), under the floor diamonds (-190).
		sprite.z_index = -197
		sprite.z_as_relative = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var shader := Shader.new()
		shader.code = BOB_CODE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("amp", 2.0 / BOARD_SCALE)
		mat.set_shader_parameter("period", 3.6)
		sprite.material = mat
		host.add_child(sprite)
	if front != null:
		var sprite := Sprite2D.new()
		sprite.name = "CrowdFront"
		sprite.texture = front
		sprite.centered = true
		sprite.position = CROWD_POS
		sprite.scale = Vector2(BOARD_SCALE, BOARD_SCALE)
		sprite.z_index = -196
		sprite.z_as_relative = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		host.add_child(sprite)


static func _add_props(host: Node2D) -> void:
	# Anchors are off the board diamond (checked in install). Icicles hang
	# from a top-centre point; the others stand on a bottom-centre point.
	var icicle_scale := 0.16
	var icicle_h := 280.0 * icicle_scale
	var hang := [
		Vector2(-400, 100), Vector2(-240, 20), Vector2(-80, -56),
		Vector2(80, -56), Vector2(240, 20), Vector2(400, 100),
		Vector2(-300, 360), Vector2(0, 492), Vector2(300, 360),
	]
	var index := 0
	for anchor in hang:
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Icicle%d" % index
		sprite.sprite_frames = _icicles
		sprite.centered = true
		sprite.scale = Vector2(icicle_scale, icicle_scale)
		sprite.position = anchor + Vector2(0, icicle_h * 0.5)
		sprite.z_index = -194
		sprite.z_as_relative = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		host.add_child(sprite)
		sprite.play("drip")
		var into := float(index) * 0.2
		sprite.set_frame_and_progress(int(into * ICICLE_FPS) % 4, fmod(into * ICICLE_FPS, 1.0))
		index += 1
	_stand(host, "BannerW", "prop_banner.webpbin", Vector2(-260, 70), 0.15, true)
	_stand(host, "BannerE", "prop_banner.webpbin", Vector2(260, 70), 0.15, true)
	_stand(host, "BannerSW", "prop_banner.webpbin", Vector2(-200, 470), 0.15, true)
	_stand(host, "BannerSE", "prop_banner.webpbin", Vector2(200, 470), 0.15, true)
	_stand(host, "BrazierW", "prop_brazier.webpbin", Vector2(-530, 230), 0.14, false)
	_stand(host, "BrazierE", "prop_brazier.webpbin", Vector2(530, 230), 0.14, false)
	_stand(host, "BrazierS", "prop_brazier.webpbin", Vector2(0, 540), 0.14, false)
	_stand(host, "PineW", "prop_pine.webpbin", Vector2(-520, 300), 0.17, false)
	_stand(host, "PineE", "prop_pine.webpbin", Vector2(520, 160), 0.17, false)
	_stand(host, "StatueW", "prop_statue.webpbin", Vector2(-470, 300), 0.12, false)
	_stand(host, "StatueE", "prop_statue.webpbin", Vector2(470, 140), 0.12, false)


static func _stand(host: Node2D, node_name: String, file_name: String, anchor: Vector2, sprite_scale: float, sway: bool) -> void:
	var tex := _load(ROOT + file_name)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = tex
	sprite.centered = true
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.position = anchor - Vector2(0, tex.get_height() * sprite_scale * 0.5)
	sprite.z_index = -194
	sprite.z_as_relative = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if sway:
		var shader := Shader.new()
		shader.code = SWAY_CODE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("width", tex.get_width())
		sprite.material = mat
	elif file_name.begins_with("prop_brazier"):
		var shader := Shader.new()
		shader.code = FLICKER_CODE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		sprite.material = mat
	host.add_child(sprite)


static func _add_floors(host: Node2D, cells: Array, shade: Dictionary) -> void:
	for raw in cells:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = raw
		var terrain := str(rec.get("terrain", ""))
		if terrain != "ground" and terrain != "water":
			continue
		if int(rec.get("elevation", 0)) > 0:
			continue
		var cell := Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0)))
		var which: Array = _snow if terrain == "ground" else _ice
		var tex: Texture2D = which[posmod(cell.x + cell.y * 2, 4)]
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Floor_%d_%d" % [cell.x, cell.y]
		sprite.texture = tex
		sprite.centered = true
		sprite.scale = Vector2(0.125, 0.125)
		sprite.position = VISUAL_SORT.cell_to_local(cell, 0.0)
		sprite.z_index = -190
		sprite.z_as_relative = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if terrain == "ground":
			var factor := float(shade.get("%d,%d" % [cell.x, cell.y], 1.0))
			sprite.modulate = Color(factor, factor, factor, 1.0)
		host.add_child(sprite)


static func _add_mist(host: Node2D) -> void:
	var tex := _load(ROOT + "mist.webpbin")
	if tex == null:
		return
	_mist_band(host, tex, "MistA", Vector2(0, 300), Vector2(2.15, 0.56), 0.035, 0.32)
	_mist_band(host, tex, "MistB", Vector2(36, 390), Vector2(2.05, 0.50), -0.028, 0.28)


static func _mist_band(host: Node2D, tex: Texture2D, node_name: String, pos: Vector2, sprite_scale: Vector2, scroll: float, alpha_scale: float) -> void:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = tex
	sprite.centered = true
	sprite.position = pos
	sprite.scale = sprite_scale
	sprite.z_index = -170
	sprite.z_as_relative = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = MIST_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("scroll", scroll)
	mat.set_shader_parameter("alpha_scale", alpha_scale)
	sprite.material = mat
	host.add_child(sprite)


static func _add_glints(host: Node2D, cells: Array) -> void:
	var ice: Array[Vector2i] = []
	for raw in cells:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = raw
		if str(rec.get("terrain", "")) != "water":
			continue
		ice.append(Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0))))
	if ice.is_empty() or _glints == null or _glints.get_frame_count("twinkle") < 5:
		return
	var sprite := Glint.new()
	sprite.name = "IceGlint"
	sprite.sprite_frames = _glints
	sprite.centered = true
	sprite.scale = Vector2(0.32, 0.32)
	sprite.z_index = -165
	sprite.z_as_relative = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.cells = ice
	host.add_child(sprite)


static func _add_flakes(host: Node2D) -> void:
	if _flakes.is_empty() or _flakes[0] == null:
		return
	var fall := Flakes.new()
	fall.name = "AliveFlakes"
	fall.textures = _flakes
	fall.z_index = -160
	fall.z_as_relative = true
	host.add_child(fall)


class Glint extends AnimatedSprite2D:
	const VISUAL_SORT := preload("res://board/visual_sort.gd")
	var cells: Array[Vector2i] = []
	var _wait := 0.0
	var _rng := RandomNumberGenerator.new()
	var _playing := false

	func _ready() -> void:
		_rng.seed = 4901
		animation_finished.connect(_on_finished)
		if not cells.is_empty():
			_show_on(_rng.randi() % cells.size())

	func _process(delta: float) -> void:
		if _playing:
			return
		_wait -= delta
		if _wait <= 0.0 and not cells.is_empty():
			_show_on(_rng.randi() % cells.size())

	func _on_finished() -> void:
		_playing = false
		visible = false
		_wait = _rng.randf_range(1.0, 2.0)

	func _show_on(index: int) -> void:
		var cell := cells[index]
		position = VISUAL_SORT.cell_to_local(cell, 0.0)
		visible = true
		play("twinkle")
		_playing = true


class Flakes extends Node2D:
	var textures: Array = []
	var _parts: Array = []
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = 4901
		for index in 60:
			var tex: Texture2D = textures[index % textures.size()]
			var wide := tex != null and tex.get_width() >= 24
			_parts.append({
				"tex": index % textures.size(),
				"x": _rng.randf_range(-520.0, 520.0),
				"y": _rng.randf_range(-40.0, 500.0),
				"speed": _rng.randf_range(120.0, 170.0),
				"sway": _rng.randf_range(8.0, 18.0),
				"phase": _rng.randf_range(0.0, TAU),
				"scale": 0.22 if wide else 0.42,
			})

	func _process(delta: float) -> void:
		for part in _parts:
			part["y"] = float(part["y"]) + float(part["speed"]) * delta
			if float(part["y"]) > 530.0:
				part["y"] = -50.0
				part["x"] = _rng.randf_range(-520.0, 520.0)
		queue_redraw()

	func _draw() -> void:
		var now := Time.get_ticks_msec() / 1000.0
		for part in _parts:
			var tex: Texture2D = textures[int(part["tex"])]
			if tex == null:
				continue
			var drift := sin(now * 1.4 + float(part["phase"])) * float(part["sway"])
			var sprite_scale := float(part["scale"])
			draw_set_transform(Vector2(float(part["x"]) + drift, float(part["y"])), 0.0, Vector2(sprite_scale, sprite_scale))
			draw_texture(tex, -tex.get_size() * 0.5, Color(1, 1, 1, 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
