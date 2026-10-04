extends Node2D

## L7 view light. PC only. The phone path stays flat: no grade shader, no rim,
## no cast shafts, no vignette, and the small damage number. The HUD layer
## is never changed.
## The outdoor grade ships as light (saturation 1.10, contrast 1.04).
## Mauro, 4 Oct 2026. Off and medium stay in code, unshipped.
## Thunderwell takes none of the grade: no
## grade, no vignette, no cast shafts, and no floor pool, so the board
## matches the base branch. Fighters still take a warm rim that follows the
## sprite and every animation strip, and PC damage numbers stay at 68 px.
## An outdoor cast drops shafts and a floor pool on the target cell.
## Name plates and HP bars are left alone. Nothing here is 3D.

const SORT := preload("res://board/visual_sort.gd")
const HUD := preload("res://ui/hud.gd")
const PALETTE := preload("res://vfx/vfx_palette.gd")

## Shipped outdoor grade. 0 leaves the base paint.
const OUTDOOR_STRENGTH := 0.0
const PRESET_OFF := "off"
const PRESET_LIGHT := "light"
const PRESET_MEDIUM := "medium"
## One line. Mauro shipped light. Off and medium stay in code.
const SHIPPED_OUTDOOR_PRESET := PRESET_LIGHT
## Light grade for L9. About +10% saturation. Applied only when the preset is light.
const LIGHT_SAT := 1.10
const LIGHT_CONTRAST := 1.04
const LIGHT_GAIN := 1.01
const LIGHT_BIAS := Color(0.010, 0.003, -0.006, 1.0)
const LIGHT_SHADE := 0.0
## Medium grade for L9. About +15% saturation. Stays in code. Not shipped.
const MEDIUM_SAT := 1.15
const MEDIUM_CONTRAST := 1.07
const MEDIUM_GAIN := 1.02
const MEDIUM_BIAS := Color(0.020, 0.006, -0.012, 1.0)
const MEDIUM_SHADE := 0.0
const OUTDOOR_RIM := Color(1.0, 0.80, 0.46, 1)
const DUNGEON_RIM := Color(1.0, 0.90, 0.68, 1)
const OUTDOOR_RIM_STRENGTH := 0.92
const DUNGEON_RIM_STRENGTH := 1.0
const SHAFT_COLOR := Color(1.0, 0.86, 0.46, 0.82)
const FLOOR_COLOR := Color(1.0, 0.62, 0.22, 0.70)
const PC_DAMAGE_FONT := 68
const CAST_LIFE := 1.35
const SHAFT_COUNT := 3
const CAST_CAP := 3
const POOL_OFFSET := Vector2(0, 22)
const POOL_RX := 86.0
const POOL_RY := 34.0

const GRADE_GLSL := """
uniform float grade_on = 0.0;
uniform float grade_sat = 1.0;
uniform float grade_contrast = 1.0;
uniform float grade_gain = 1.0;
uniform vec3 grade_bias = vec3(0.0);
uniform vec3 grade_shadow = vec3(0.0);
uniform float grade_shade = 0.50;
vec3 l7_grade(vec3 rgb) {
	if (grade_on < 0.5) {
		return rgb;
	}
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 sat = mix(vec3(luma), rgb, grade_sat);
	sat = (sat - vec3(0.5)) * grade_contrast + vec3(0.5);
	float shade = smoothstep(0.55, 0.0, luma);
	sat = mix(sat, grade_shadow, shade * grade_shade);
	sat = sat * grade_gain + grade_bias;
	return clamp(sat, vec3(0.0), vec3(1.0));
}
"""

const _GRADE_SHADER := """shader_type canvas_item;
""" + GRADE_GLSL + """
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = l7_grade(c.rgb);
	COLOR = c;
}
"""

## A tile paints its texture in _draw. On that path the fragment COLOR is
## already the textured pixel, so sampling TEXTURE again darkens the sand
## before the grade runs. Sprites still sample TEXTURE.
const _DRAW_GRADE_SHADER := """shader_type canvas_item;
""" + GRADE_GLSL + """
void fragment() {
	vec4 c = COLOR;
	c.rgb = l7_grade(c.rgb);
	COLOR = c;
}
"""

const _VIGNETTE_CODE := """shader_type canvas_item;
uniform float strength = 0.62;
uniform vec3 edge : source_color = vec3(0.03, 0.04, 0.08);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p * vec2(0.78, 1.0));
	float a = smoothstep(0.22, 1.12, d) * strength;
	COLOR = vec4(edge, a);
}
"""

static var active := false
static var _dungeon_rim := false
## True only when a named outdoor preset is on. Thunderwell never sets it.
## The shipped preset is SHIPPED_OUTDOOR_PRESET (light).
static var outdoor_preset := SHIPPED_OUTDOOR_PRESET
static var _paint_grade := false
## Bench switch. The phone path is already off. This turns the light off
## while the PC HUD and the jungle stay up.
static var suppressed := false
static var _shared_grade: ShaderMaterial
static var _shared_draw_grade: ShaderMaterial


var _board: Node2D
var _vignette_layer: CanvasLayer
var _vignette: ColorRect
var _casts: Array[Dictionary] = []
var _dungeon := false
var _graded := false
var _sat := 1.0
var _contrast := 1.0
var _gain := 1.0
var _bias := Color(0, 0, 0, 1)
var _shadow := Color(0, 0, 0, 1)
var _shade := 0.0


static func set_suppressed(on: bool) -> void:
	suppressed = on


static func set_outdoor_preset(name: String) -> void:
	if name == PRESET_OFF or name == PRESET_LIGHT or name == PRESET_MEDIUM:
		outdoor_preset = name
	else:
		outdoor_preset = SHIPPED_OUTDOOR_PRESET


## The same curve as l7_grade, so a test can measure water against a move tile
## after the shipped light grade. Off returns the color unchanged.
static func grade_color(src: Color, preset: String) -> Color:
	var sat := 1.0
	var contrast := 1.0
	var gain := 1.0
	var bias := Color(0, 0, 0, 1)
	var shade := 0.0
	if preset == PRESET_LIGHT:
		sat = LIGHT_SAT
		contrast = LIGHT_CONTRAST
		gain = LIGHT_GAIN
		bias = LIGHT_BIAS
		shade = LIGHT_SHADE
	elif preset == PRESET_MEDIUM:
		sat = MEDIUM_SAT
		contrast = MEDIUM_CONTRAST
		gain = MEDIUM_GAIN
		bias = MEDIUM_BIAS
		shade = MEDIUM_SHADE
	else:
		return src
	var rgb := Vector3(src.r, src.g, src.b)
	var luma := rgb.dot(Vector3(0.2126, 0.7152, 0.0722))
	var graded := Vector3(luma, luma, luma).lerp(rgb, sat)
	graded = (graded - Vector3(0.5, 0.5, 0.5)) * contrast + Vector3(0.5, 0.5, 0.5)
	var shade_t := smoothstep(0.55, 0.0, luma)
	graded = graded.lerp(Vector3.ZERO, shade_t * shade)
	graded = graded * gain + Vector3(bias.r, bias.g, bias.b)
	graded = graded.clamp(Vector3.ZERO, Vector3.ONE)
	return Color(graded.x, graded.y, graded.z, src.a)


static func font_size(kind: String, base: int) -> int:
	if kind != "damage" and kind != "burn":
		return base
	if not HUD.uses_pc_chrome() or suppressed:
		return base
	return PC_DAMAGE_FONT


static func dress_pawn(pawn: Node) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	var living := true
	if "alive" in pawn:
		living = bool(pawn.get("alive"))
	var sprite := pawn.get_node_or_null("Sprite") as Sprite2D
	var strip: AnimatedSprite2D = null
	if pawn.has_method("look_body"):
		var body: Variant = pawn.look_body()
		if body is AnimatedSprite2D:
			strip = body
	var show := active and living and (strip != null or (sprite != null and sprite.texture != null))
	var rim := _find_rim(pawn)
	if not show:
		if rim != null:
			rim.visible = false
		_grade_bodies(pawn, false)
		return
	var body: Node2D = strip if strip != null else sprite
	if rim == null:
		rim = Sprite2D.new()
		rim.name = "LookRim"
		rim.centered = true
		rim.z_index = -1
		rim.z_as_relative = true
	if rim.get_parent() != body:
		if rim.get_parent() != null:
			rim.get_parent().remove_child(rim)
		body.add_child(rim)
	if strip != null:
		var frames := strip.sprite_frames
		var anim := strip.animation
		if frames != null and frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			var frame := clampi(strip.frame, 0, frames.get_frame_count(anim) - 1)
			rim.texture = frames.get_frame_texture(anim, frame)
		if not bool(strip.get_meta("_look_rim_bound", false)):
			strip.frame_changed.connect(func() -> void: dress_pawn(pawn))
			strip.set_meta("_look_rim_bound", true)
	else:
		rim.texture = sprite.texture
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rim.scale = Vector2(1.18, 1.18)
	rim.centered = bool(body.get("centered")) if "centered" in body else true
	rim.offset = body.offset if "offset" in body else Vector2.ZERO
	rim.position = Vector2(-8, -10)
	rim.flip_h = false
	var tint: Color = DUNGEON_RIM if _dungeon_rim else OUTDOOR_RIM
	tint.a = DUNGEON_RIM_STRENGTH if _dungeon_rim else OUTDOOR_RIM_STRENGTH
	rim.modulate = tint
	rim.visible = rim.texture != null
	_grade_bodies(pawn, _paint_grade)


static func _find_rim(node: Node) -> Sprite2D:
	if node is Sprite2D and str(node.name) == "LookRim":
		return node
	for child in node.get_children():
		var hit := _find_rim(child)
		if hit != null:
			return hit
	return null


static func _grade_bodies(pawn: Node, on: bool) -> void:
	var sprite := pawn.get_node_or_null("Sprite") as CanvasItem
	if sprite != null:
		_attach_grade(sprite, on)
	for child in pawn.get_children():
		if child is AnimatedSprite2D and str(child.name) != "LookRim":
			_attach_grade(child, on)


static func _attach_grade(item: CanvasItem, on: bool) -> void:
	if item == null:
		return
	if str(item.name) == "LookRim" or str(item.name) == "Chrome" or str(item.name) == "OverheadPlate":
		return
	var tagged := bool(item.get_meta("_look_grade_mat", false))
	if not on:
		if tagged:
			item.material = null
			item.remove_meta("_look_grade_mat")
		return
	if item.material != null and not tagged:
		return
	var mat := _shared_grade
	if not (item is Sprite2D) and not (item is AnimatedSprite2D):
		mat = _shared_draw_grade
	if mat == null:
		return
	item.material = mat
	item.set_meta("_look_grade_mat", true)


func _ready() -> void:
	z_as_relative = false
	z_index = 0
	set_process(false)


func sync(board: Node2D, dungeon: bool) -> void:
	_board = board
	var pc := HUD.uses_pc_chrome() and not suppressed
	active = pc
	_dungeon = pc and dungeon
	_apply_grade()
	if not pc or _dungeon:
		_casts.clear()
		set_process(false)
		queue_redraw()
		_set_vignette(false)
	_dress_units()
	_graded = _paint_grade


func note_events(events: Array) -> int:
	if not active or _dungeon:
		return 0
	var added := 0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "cast":
			continue
		var cell := _event_cell(event)
		if cell.x < -100:
			continue
		var tint := FLOOR_COLOR
		var spell_id := str(event.get("spell", ""))
		if spell_id != "":
			tint = FLOOR_COLOR.lerp(PALETTE.spell_tint(spell_id), 0.18)
		_casts.append({
			"at": _world(cell) + POOL_OFFSET,
			"cell": cell,
			"life": CAST_LIFE,
			"tint": tint,
		})
		added += 1
		if _casts.size() > CAST_CAP:
			_casts.pop_front()
		if added >= CAST_CAP:
			break
	if added > 0:
		visible = true
		set_process(true)
		_place_z()
		queue_redraw()
	return added


func wash_visible() -> bool:
	return _paint_grade


func grade_saturation() -> float:
	return _sat


func grade_contrast() -> float:
	return _contrast


func grade_gain() -> float:
	return _gain


func grade_bias() -> Color:
	return _bias


func grade_shade() -> float:
	return _shade


func vignette_visible() -> bool:
	return _vignette != null and _vignette.visible and _dungeon and active


func rim_color() -> Color:
	return DUNGEON_RIM if _dungeon_rim else OUTDOOR_RIM


func rim_strength() -> float:
	return DUNGEON_RIM_STRENGTH if _dungeon_rim else OUTDOOR_RIM_STRENGTH


func cast_count() -> int:
	return _casts.size()


func cast_tint() -> Color:
	if _casts.is_empty():
		return Color(0, 0, 0, 0)
	return _casts[0]["tint"]


func cast_at() -> Vector2:
	if _casts.is_empty():
		return Vector2.ZERO
	return _casts[0]["at"]


func _process(delta: float) -> void:
	var step := minf(delta, 1.0 / 30.0)
	var live: Array[Dictionary] = []
	for cast in _casts:
		cast["life"] = float(cast["life"]) - step
		if float(cast["life"]) > 0.0:
			live.append(cast)
	_casts = live
	if _casts.is_empty():
		set_process(false)
		queue_redraw()
		return
	_place_z()
	queue_redraw()


func _draw() -> void:
	if not active or _dungeon:
		return
	for cast in _casts:
		var life := float(cast["life"])
		if life <= 0.0:
			continue
		var t := clampf(life / CAST_LIFE, 0.0, 1.0)
		var fade := minf(t * 2.2, 1.0)
		var at: Vector2 = cast["at"]
		var pool: Color = cast["tint"]
		pool.a = FLOOR_COLOR.a * fade
		_ellipse(at, POOL_RX, POOL_RY, Color(pool.r, pool.g, pool.b, pool.a * 0.55))
		_ellipse(at, POOL_RX * 0.62, POOL_RY * 0.62, pool)
		var shaft := SHAFT_COLOR
		shaft.a *= fade
		_shaft(at + Vector2(-46, 4), -10.0, 8.0, 168.0, shaft)
		_shaft(at + Vector2(6, 0), -8.0, 9.0, 196.0, Color(shaft.r, shaft.g, shaft.b, shaft.a * 0.92))
		_shaft(at + Vector2(50, 6), -7.0, 10.0, 154.0, Color(shaft.r, shaft.g, shaft.b, shaft.a * 0.8))


func _apply_grade() -> void:
	_dungeon_rim = active and _dungeon
	_sat = 1.0
	_contrast = 1.0
	_gain = 1.0
	_bias = Color(0, 0, 0, 1)
	_shadow = Color(0, 0, 0, 1)
	_shade = 0.0
	# Strength 0 unless L9 turns a named preset on. Never on Thunderwell.
	_paint_grade = false
	if active and not _dungeon:
		_apply_outdoor_preset()
	_set_vignette(false)
	_ensure_shared()
	_push_shared()
	_grade_board()


func _apply_outdoor_preset() -> void:
	if outdoor_preset == PRESET_LIGHT:
		_paint_grade = true
		_sat = LIGHT_SAT
		_contrast = LIGHT_CONTRAST
		_gain = LIGHT_GAIN
		_bias = LIGHT_BIAS
		_shadow = Color(0, 0, 0, 1)
		_shade = LIGHT_SHADE
	elif outdoor_preset == PRESET_MEDIUM:
		_paint_grade = true
		_sat = MEDIUM_SAT
		_contrast = MEDIUM_CONTRAST
		_gain = MEDIUM_GAIN
		_bias = MEDIUM_BIAS
		_shadow = Color(0, 0, 0, 1)
		_shade = MEDIUM_SHADE


func _ensure_shared() -> void:
	if _shared_grade == null:
		var shader := Shader.new()
		shader.code = _GRADE_SHADER
		_shared_grade = ShaderMaterial.new()
		_shared_grade.shader = shader
	if _shared_draw_grade == null:
		var drawn := Shader.new()
		drawn.code = _DRAW_GRADE_SHADER
		_shared_draw_grade = ShaderMaterial.new()
		_shared_draw_grade.shader = drawn


func _push_shared() -> void:
	_push_material(_shared_grade)
	_push_material(_shared_draw_grade)


func _push_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("grade_on", 1.0 if _paint_grade else 0.0)
	mat.set_shader_parameter("grade_sat", _sat)
	mat.set_shader_parameter("grade_contrast", _contrast)
	mat.set_shader_parameter("grade_gain", _gain)
	mat.set_shader_parameter("grade_bias", Vector3(_bias.r, _bias.g, _bias.b))
	mat.set_shader_parameter("grade_shadow", Vector3(_shadow.r, _shadow.g, _shadow.b))
	mat.set_shader_parameter("grade_shade", _shade)


func _grade_board() -> void:
	if _board == null:
		return
	if _board.modulate != Color.WHITE:
		_board.modulate = Color.WHITE
	var tiles := _board.get_node_or_null("Tiles")
	if tiles != null:
		if tiles is CanvasItem:
			(tiles as CanvasItem).modulate = Color.WHITE
		for child in tiles.get_children():
			if child is CanvasItem:
				_attach_grade(child, _paint_grade)
				# The Crosshaven dress paints in _draw, like a tile. The grade
				# follows the outdoor preset. Light is the shipped one.
				var dress := child.get_node_or_null("CrosshavenDress") as CanvasItem
				if dress != null:
					_attach_grade(dress, _paint_grade)
	var units := _board.get_node_or_null("Units") as CanvasItem
	if units != null:
		units.modulate = Color.WHITE
	var jungle := _board.get_node_or_null("JungleBackdrop")
	if jungle != null and jungle.has_method("set_look_grade"):
		if jungle is CanvasItem:
			(jungle as CanvasItem).modulate = Color.WHITE
		jungle.set_look_grade(_paint_grade, _sat, _contrast, _gain, _bias, _shadow, _shade)
	# ThunderwellFloor keeps the base room shader. No grade, no vignette.


func _set_vignette(on: bool) -> void:
	if not on:
		if _vignette != null:
			_vignette.visible = false
		return
	if _vignette == null:
		_vignette_layer = CanvasLayer.new()
		_vignette_layer.name = "Vignette"
		_vignette_layer.layer = 1
		add_child(_vignette_layer)
		_vignette = ColorRect.new()
		_vignette.name = "Edge"
		_vignette.color = Color.WHITE
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette.material = _shader_mat(_VIGNETTE_CODE, {"strength": 0.62, "edge": Color(0.03, 0.04, 0.08)})
		_vignette_layer.add_child(_vignette)
		_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.visible = true


func _dress_units() -> void:
	if _board == null:
		return
	var units := _board.get_node_or_null("Units")
	if units == null:
		return
	for child in units.get_children():
		dress_pawn(child)


func _place_z() -> void:
	if _casts.is_empty():
		return
	var cell: Vector2i = _casts[_casts.size() - 1]["cell"]
	var elev := 0.0
	if _board != null and _board.has_method("_elev_at"):
		elev = float(_board._elev_at(cell))
	# On the cell floor, under the fighter, so the pool rings the feet.
	z_index = SORT.tile_z_index(cell, elev) + 1


func _world(cell: Vector2i) -> Vector2:
	if _board != null and _board.has_method("_cell_to_local"):
		return _board._cell_to_local(cell)
	return Vector2(cell)


func _event_cell(event: Dictionary) -> Vector2i:
	for key in ["to", "cell"]:
		if not event.has(key):
			continue
		var raw: Variant = event[key]
		if raw is Vector2i:
			return raw
		if raw is Vector2:
			return Vector2i(int(raw.x), int(raw.y))
	if event.has("caster_cell"):
		var caster: Variant = event["caster_cell"]
		if caster is Vector2i:
			return caster
	return Vector2i(-999, -999)


func _ellipse(at: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var ang := TAU * float(i) / 18.0
		pts.append(at + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, color)


func _shaft(at: Vector2, left: float, right: float, height: float, color: Color) -> void:
	var top := at + Vector2((left + right) * 0.5, -height)
	var pts := PackedVector2Array([
		at + Vector2(left, 4.0),
		at + Vector2(right, 4.0),
		top + Vector2(4.0, 0.0),
		top + Vector2(-4.0, 0.0),
	])
	draw_colored_polygon(pts, color)


func _shader_mat(code: String, params: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key in params:
		mat.set_shader_parameter(key, params[key])
	return mat
