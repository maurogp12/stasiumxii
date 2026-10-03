extends Node2D

## L7 view light. PC only. The phone path stays flat: white grade, no rim,
## no cast shafts, and the small damage number.
## Outdoor maps tint the board warm. Thunderwell tints it cooler and darker,
## with an edge vignette. The grade is the board tint, not a fullscreen pass,
## so the jungle plates keep their blend. Fighters take a warm rim. A cast
## drops warm shafts and a floor pool. Nothing here is 3D, and nothing is a new paint.

const SORT := preload("res://board/visual_sort.gd")
const HUD := preload("res://ui/hud.gd")
const PALETTE := preload("res://vfx/vfx_palette.gd")

const PHONE_GRADE := Color(1, 1, 1, 1)
const OUTDOOR_GRADE := Color(1.0, 0.90, 0.74, 1)
const DUNGEON_GRADE := Color(0.70, 0.78, 0.92, 1)
const OUTDOOR_RIM := Color(1.0, 0.80, 0.46, 1)
const DUNGEON_RIM := Color(1.0, 0.90, 0.68, 1)
const OUTDOOR_RIM_STRENGTH := 0.62
const DUNGEON_RIM_STRENGTH := 0.92
const SHAFT_COLOR := Color(1.0, 0.84, 0.50, 0.36)
const FLOOR_COLOR := Color(1.0, 0.70, 0.30, 0.40)
const PC_DAMAGE_FONT := 68
const CAST_LIFE := 0.70
const SHAFT_COUNT := 3
const CAST_CAP := 3

const _VIGNETTE_CODE := """shader_type canvas_item;
uniform float strength = 0.58;
uniform vec3 edge : source_color = vec3(0.04, 0.05, 0.09);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p * vec2(0.82, 1.0));
	float a = smoothstep(0.28, 1.18, d) * strength;
	COLOR = vec4(edge, a);
}
"""

const _CAST_TYPES: Array[String] = ["hit", "cast", "miss"]

static var active := false
static var _dungeon_rim := false


var _board: Node2D
var _shown_grade := Color(1, 1, 1, 1)
var _vignette_layer: CanvasLayer
var _vignette: ColorRect
var _casts: Array[Dictionary] = []
var _dungeon := false


static func font_size(kind: String, base: int) -> int:
	if kind != "damage" and kind != "burn":
		return base
	if not HUD.uses_pc_chrome():
		return base
	return PC_DAMAGE_FONT


static func dress_pawn(pawn: Node) -> void:
	if pawn == null:
		return
	var living := true
	if "alive" in pawn:
		living = bool(pawn.get("alive"))
	var sprite := pawn.get_node_or_null("Sprite") as Sprite2D
	var rim: Sprite2D = null
	if sprite != null:
		rim = sprite.get_node_or_null("LookRim") as Sprite2D
	var show := active and living and sprite != null and sprite.texture != null
	if not show:
		if rim != null:
			rim.visible = false
		return
	if rim == null:
		rim = Sprite2D.new()
		rim.name = "LookRim"
		rim.centered = true
		rim.z_index = -1
		rim.z_as_relative = true
		sprite.add_child(rim)
	rim.texture = sprite.texture
	rim.texture_filter = sprite.texture_filter
	rim.scale = Vector2(1.08, 1.08)
	rim.offset = sprite.offset
	rim.position = Vector2(-4, -5)
	rim.flip_h = false
	var tint: Color = DUNGEON_RIM if _dungeon_rim else OUTDOOR_RIM
	tint.a = DUNGEON_RIM_STRENGTH if _dungeon_rim else OUTDOOR_RIM_STRENGTH
	rim.modulate = tint
	rim.visible = sprite.visible


func _ready() -> void:
	z_as_relative = false
	z_index = 0
	set_process(false)
	_ensure_nodes()


func _ensure_nodes() -> void:
	if _vignette != null or not _dungeon:
		return
	_vignette_layer = CanvasLayer.new()
	_vignette_layer.name = "Vignette"
	_vignette_layer.layer = 1
	add_child(_vignette_layer)
	_vignette = _full_rect()
	_vignette.name = "Edge"
	_vignette.visible = true
	_vignette.material = _shader_mat(_VIGNETTE_CODE, {"strength": 0.58, "edge": Color(0.04, 0.05, 0.09)})
	_vignette_layer.add_child(_vignette)
	_fit_rect(_vignette)


func sync(board: Node2D, dungeon: bool) -> void:
	_ensure_nodes()
	_board = board
	var pc := HUD.uses_pc_chrome()
	active = pc
	_dungeon = pc and dungeon
	_apply_grade()
	_lift_hud(pc)
	if not pc:
		_casts.clear()
		set_process(false)
		visible = true
		queue_redraw()
	_dress_units()


func note_events(events: Array) -> int:
	if not active:
		return 0
	var added := 0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if _CAST_TYPES.find(str(event.get("type", ""))) < 0:
			continue
		var cell := _event_cell(event)
		if cell.x < -100:
			continue
		var tint := FLOOR_COLOR
		var spell_id := str(event.get("spell", ""))
		if spell_id != "":
			tint = FLOOR_COLOR.lerp(PALETTE.spell_tint(spell_id), 0.22)
		_casts.append({
			"at": _world(cell),
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


func grade_color() -> Color:
	return _shown_grade


func wash_visible() -> bool:
	return false


func vignette_visible() -> bool:
	return _vignette != null and _vignette.visible


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
	if not active:
		return
	for cast in _casts:
		var life := float(cast["life"])
		if life <= 0.0:
			continue
		var t := clampf(life / CAST_LIFE, 0.0, 1.0)
		var fade := minf(t * 3.0, 1.0) * t
		var at: Vector2 = cast["at"]
		var pool: Color = cast["tint"]
		pool.a = FLOOR_COLOR.a * fade
		_ellipse(at, 34.0, 14.0, Color(pool.r, pool.g, pool.b, pool.a * 0.45))
		_ellipse(at, 22.0, 9.0, pool)
		var shaft := SHAFT_COLOR
		shaft.a *= fade
		_shaft(at + Vector2(-16, 0), -7.0, 5.0, 108.0, shaft)
		_shaft(at + Vector2(2, 0), -5.0, 6.0, 132.0, Color(shaft.r, shaft.g, shaft.b, shaft.a * 0.85))
		_shaft(at + Vector2(18, 0), -4.0, 7.0, 96.0, Color(shaft.r, shaft.g, shaft.b, shaft.a * 0.7))


func _apply_grade() -> void:
	_dungeon_rim = active and _dungeon
	if not active:
		_shown_grade = PHONE_GRADE
		if _vignette != null:
			_vignette.visible = false
	elif _dungeon:
		_shown_grade = DUNGEON_GRADE
		_ensure_nodes()
		if _vignette != null:
			_vignette.visible = true
	else:
		_shown_grade = OUTDOOR_GRADE
		if _vignette != null:
			_vignette.visible = false
	_tint_board()


## The jungle plates stay at their own modulate. A tint on the board parent
## makes those blend-disabled plates blend, and the pan budget goes with them.
func _tint_board() -> void:
	if _board == null:
		return
	if _board.modulate != Color.WHITE:
		_board.modulate = Color.WHITE
	for node_name in ["Tiles", "Units", "ThunderwellFloor"]:
		var node := _board.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.modulate = _shown_grade


func _lift_hud(pc: bool) -> void:
	if _board == null:
		return
	var hud := _board.get_node_or_null("../HUD") as CanvasLayer
	if hud == null:
		return
	hud.layer = 2 if pc else 1


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
	z_index = SORT.tile_z_index(cell, elev) + 2


func _world(cell: Vector2i) -> Vector2:
	if _board != null and _board.has_method("_cell_to_local"):
		return _board._cell_to_local(cell)
	return Vector2(cell)


func _event_cell(event: Dictionary) -> Vector2i:
	for key in ["to", "cell", "caster_cell"]:
		if not event.has(key):
			continue
		var raw: Variant = event[key]
		if raw is Vector2i:
			return raw
		if raw is Vector2:
			return Vector2i(int(raw.x), int(raw.y))
	return Vector2i(-999, -999)


func _ellipse(at: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var ang := TAU * float(i) / 14.0
		pts.append(at + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, color)


func _shaft(at: Vector2, left: float, right: float, height: float, color: Color) -> void:
	var top := at + Vector2((left + right) * 0.5, -height)
	var pts := PackedVector2Array([
		at + Vector2(left, 2.0),
		at + Vector2(right, 2.0),
		top + Vector2(3.0, 0.0),
		top + Vector2(-3.0, 0.0),
	])
	draw_colored_polygon(pts, color)


func _full_rect() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _fit_rect(rect: ColorRect) -> void:
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0


func _shader_mat(code: String, params: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key in params:
		mat.set_shader_parameter(key, params[key])
	return mat

