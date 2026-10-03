extends Node2D

## View-only room-edge props for the Thunderwell floor. CombatSim never reads this.
## Masters are the @2x PNGs at half scale. The 1x file is the fallback.
## The anchor is the footprint's south tip, and that cell's unit z sorts the prop
## with fighters. Tall props stay above the board's left-right corner line.
## Front and south edges only take rubble, conduit and cable.
## Emission is albedo + albedo * emit * strength * glow_gain, in the same HDR
## mix as the floor, so metal stays under 1 and only the mask blooms.
## A soft ellipse under the footprint is the contact shadow. Nothing is baked.

const FLOOR_PARAMS := "res://data/pc/look/thunderwell_floor.json"
const ART_ROOT := "res://art/pc/look/thunderwell_props/"
const CATALOG_PATH := ART_ROOT + "props.json"
const DRAW_SCALE := 0.5
const TALL_HEIGHT_PX := 110.0
const SHADOW_STRENGTH := 0.35
const ALPHA_INK := 0.05
## kestrel/ironjaw static frame is 144x160, centered, offset (0, -72), scale 0.5.
const FIGHTER_HALF_W := 36.0
const FIGHTER_ABOVE := 76.0
const FIGHTER_BELOW := 4.0
const CELL_HALF_W := 32.0
const CELL_HALF_H := 16.0

const EMIT_SHADER := """shader_type canvas_item;
// TEXTURE keeps the color sampler. emit_tex is the greyscale mask, sampled as
// data at the sprite UV. Linear, no mipmaps, no color hint.
uniform sampler2D emit_tex : filter_linear, repeat_disable;
uniform float strength = 0.45;
uniform float glow_gain = 1.0;
void fragment() {
	vec4 albedo = texture(TEXTURE, UV);
	float emit = texture(emit_tex, UV).r;
	COLOR = albedo;
	COLOR.rgb += COLOR.rgb * emit * strength * glow_gain;
}
"""

const SHADOW_SHADER := """shader_type canvas_item;
render_mode blend_mul;
uniform float strength = 0.35;
void fragment() {
	float falloff = texture(TEXTURE, UV).a;
	float shade = mix(1.0, 1.0 - strength, falloff);
	COLOR = vec4(vec3(shade), 1.0);
}
"""

const LOW_IDS := ["slate_rubble", "conduit_pipe", "cable_bundle"]

var _key := ""
var _shader: Shader
var _shadow_shader: Shader
var _shadow_tex: Dictionary = {}


static func load_floor_params() -> Dictionary:
	var text := FileAccess.get_file_as_string(FLOOR_PARAMS)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func room_params() -> Dictionary:
	var raw: Variant = load_floor_params().get("room_props", {})
	if raw is Dictionary:
		return raw
	return {}


static func load_catalog() -> Array:
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	if text == "":
		return []
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var props: Variant = parsed.get("props", [])
		if props is Array:
			return props
	return []


static func catalog_by_id() -> Dictionary:
	var out := {}
	for item in load_catalog():
		if item is Dictionary:
			out[str(item.get("id", ""))] = item
	return out


static func glow_gain() -> float:
	return float(room_params().get("glow_gain", 1.0))


static func shadow_strength() -> float:
	return float(room_params().get("contact_shadow", SHADOW_STRENGTH))


static func emission_strength(prop_id: String) -> float:
	var table: Variant = room_params().get("emission", {})
	if table is Dictionary and (table as Dictionary).has(prop_id):
		return float((table as Dictionary)[prop_id])
	var spec: Dictionary = catalog_by_id().get(prop_id, {})
	return float(spec.get("emission_strength_default", 0.0))


static func placements() -> Array:
	var raw: Variant = room_params().get("placements", [])
	if raw is Array:
		return raw
	return []


static func anchor_cell(origin: Vector2i, footprint: Vector2i) -> Vector2i:
	return origin + Vector2i(maxi(footprint.x, 1) - 1, maxi(footprint.y, 1) - 1)


static func south_tip(cell: Vector2i) -> Vector2:
	return BoardVisualSort.cell_to_local(cell) + Vector2(0.0, CELL_HALF_H)


static func corner_line_y(board_cells: Array) -> float:
	var left_x := INF
	var right_x := -INF
	var left_y := 0.0
	var right_y := 0.0
	for cell in board_cells:
		var at := BoardVisualSort.cell_to_local(cell)
		if at.x < left_x:
			left_x = at.x
			left_y = at.y
		if at.x > right_x:
			right_x = at.x
			right_y = at.y
	if left_x == INF:
		return 0.0
	return (left_y + right_y) * 0.5


static func footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in maxi(footprint.y, 1):
		for x in maxi(footprint.x, 1):
			out.append(origin + Vector2i(x, y))
	return out


static func is_tall(spec: Dictionary) -> bool:
	return float(spec.get("height_px_2x", 0.0)) > float(room_params().get("tall_height_px", TALL_HEIGHT_PX))


static func master_path(spec: Dictionary) -> String:
	var path := ART_ROOT + str(spec.get("file_2x", ""))
	if FileAccess.file_exists(path):
		return path
	return ART_ROOT + str(spec.get("file_1x", ""))


static func uses_master(spec: Dictionary) -> bool:
	return FileAccess.file_exists(ART_ROOT + str(spec.get("file_2x", "")))


## Opaque prop pixels, and the contact ellipse, must not draw over a board
## diamond or a fighter body. An orthographic pan does not create new overlaps;
## the same predicate is what the +y 220 and x ±220 views rely on.
static func coverage_hits(board_cells: Array) -> Array:
	var hits: Array = []
	var catalog := catalog_by_id()
	var line_y := corner_line_y(board_cells)
	var occupied := {}
	for cell in board_cells:
		occupied[cell] = true
	for item in placements():
		if not (item is Dictionary):
			continue
		var prop_id := str(item.get("id", ""))
		var spec: Dictionary = catalog.get(prop_id, {})
		if spec.is_empty():
			hits.append("%s missing from the catalog" % prop_id)
			continue
		var origin := _origin_of(item)
		var footprint := _footprint_of(spec)
		var cells := footprint_cells(origin, footprint)
		for cell in cells:
			if occupied.has(cell):
				hits.append("%s footprint %s is a board cell" % [prop_id, str(cell)])
		var anchor := anchor_cell(origin, footprint)
		var tip := south_tip(anchor)
		var above := tip.y < line_y
		if is_tall(spec) and not above:
			hits.append("%s is tall and sits on the front of the corner line" % prop_id)
		if not above and not LOW_IDS.has(prop_id):
			hits.append("%s is on the front edge and is not rubble, conduit or cable" % prop_id)
		var prop_z := BoardVisualSort.unit_z_index(anchor)
		var tex := load(master_path(spec)) as Texture2D
		if tex == null:
			hits.append("%s art did not load" % prop_id)
			continue
		var image := tex.get_image()
		if image == null:
			hits.append("%s has no image" % prop_id)
			continue
		var anchor_px := _anchor_px(spec)
		var scale := DRAW_SCALE if uses_master(spec) else 1.0
		hits.append_array(_ink_hits(prop_id, image, tip, anchor_px, scale, prop_z, board_cells))
		hits.append_array(_shadow_hits(prop_id, tip, footprint, prop_z - 1, board_cells))
	return hits


static func _ink_hits(prop_id: String, image: Image, tip: Vector2, anchor_px: Vector2, scale: float, prop_z: int, board_cells: Array) -> Array:
	var hits: Array = []
	var samples: Array[Vector2] = []
	var width := image.get_width()
	var height := image.get_height()
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a <= ALPHA_INK:
				continue
			samples.append(tip + Vector2(float(x) - anchor_px.x, float(y) - anchor_px.y) * scale)
	if samples.is_empty():
		return hits
	var bounds := _bounds(samples)
	for cell in board_cells:
		var center := BoardVisualSort.cell_to_local(cell)
		var tile_z := BoardVisualSort.tile_z_index(cell)
		var unit_z := BoardVisualSort.unit_z_index(cell)
		var tile_near := _near_diamond(bounds, center)
		var body_near := _near_body(bounds, center)
		if prop_z < tile_z and prop_z < unit_z:
			continue
		if not tile_near and not body_near:
			continue
		for point in samples:
			if prop_z >= tile_z and tile_near and _in_diamond(point, center):
				hits.append("%s covers board cell %s" % [prop_id, str(cell)])
				tile_near = false
			if prop_z >= unit_z and body_near and _in_body(point, center):
				hits.append("%s covers a fighter on %s" % [prop_id, str(cell)])
				body_near = false
			if not tile_near and not body_near:
				break
	return hits


static func _shadow_hits(prop_id: String, tip: Vector2, footprint: Vector2i, shadow_z: int, board_cells: Array) -> Array:
	var hits: Array = []
	var center := tip + Vector2(0.0, -CELL_HALF_H * float(footprint.y))
	var rx := CELL_HALF_W * float(footprint.x) * 0.62
	var ry := CELL_HALF_H * float(footprint.y) * 0.55
	var samples: Array[Vector2] = [center]
	for step in 16:
		var ang := float(step) / 16.0 * TAU
		samples.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	var bounds := _bounds(samples)
	for cell in board_cells:
		var tile_at := BoardVisualSort.cell_to_local(cell)
		if shadow_z < BoardVisualSort.tile_z_index(cell):
			continue
		if not _near_diamond(bounds, tile_at):
			continue
		for point in samples:
			if _in_diamond(point, tile_at):
				hits.append("%s contact shadow covers board cell %s" % [prop_id, str(cell)])
				break
	return hits


static func _bounds(samples: Array[Vector2]) -> Rect2:
	var min_x := samples[0].x
	var max_x := samples[0].x
	var min_y := samples[0].y
	var max_y := samples[0].y
	for point in samples:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


static func _near_diamond(bounds: Rect2, center: Vector2) -> bool:
	return not (bounds.end.x < center.x - CELL_HALF_W or bounds.position.x > center.x + CELL_HALF_W or bounds.end.y < center.y - CELL_HALF_H or bounds.position.y > center.y + CELL_HALF_H)


static func _near_body(bounds: Rect2, center: Vector2) -> bool:
	return not (bounds.end.x < center.x - FIGHTER_HALF_W or bounds.position.x > center.x + FIGHTER_HALF_W or bounds.end.y < center.y - FIGHTER_ABOVE or bounds.position.y > center.y + FIGHTER_BELOW)


static func _in_diamond(point: Vector2, center: Vector2) -> bool:
	return absf(point.x - center.x) / CELL_HALF_W + absf(point.y - center.y) / CELL_HALF_H <= 1.0


static func _in_body(point: Vector2, feet: Vector2) -> bool:
	return absf(point.x - feet.x) <= FIGHTER_HALF_W and point.y <= feet.y + FIGHTER_BELOW and point.y >= feet.y - FIGHTER_ABOVE


static func _origin_of(item: Dictionary) -> Vector2i:
	var raw: Variant = item.get("origin", [0, 0])
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ZERO


static func _footprint_of(spec: Dictionary) -> Vector2i:
	var raw: Variant = spec.get("footprint_cells", [1, 1])
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i.ONE


static func _anchor_px(spec: Dictionary) -> Vector2:
	var key := "anchor_px_2x" if uses_master(spec) else "anchor_px_1x"
	var raw: Variant = spec.get(key, [0, 0])
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


func prop_count() -> int:
	return get_child_count()


func records() -> Array:
	var out: Array = []
	for child in get_children():
		out.append({
			"id": str(child.get_meta("prop_id")),
			"origin": child.get_meta("origin"),
			"anchor": child.get_meta("anchor"),
			"cells": child.get_meta("cells"),
		})
	return out


func clear_props() -> void:
	var kids := get_children()
	for child in kids:
		remove_child(child)
		child.free()
	_key = ""


func sync_board(board: Node2D) -> void:
	if board == null:
		clear_props()
		return
	var key := _signature(board)
	if key != _key:
		_rebuild(board)
		_key = key
	_place(board)


func apply_time(t: float) -> void:
	var params := load_floor_params()
	var hz := float(params.get("pulse_hz", 0.22))
	var wave := 0.5 + 0.5 * sin(t * TAU * hz)
	for child in get_children():
		var art := child.get_node_or_null("Art") as CanvasItem
		if art == null or not (art.material is ShaderMaterial):
			continue
		var mat := art.material as ShaderMaterial
		var base := float(child.get_meta("strength"))
		# The coil shares the floor pulse clock. The peak stays the authored strength.
		var live := base * (0.85 + 0.15 * wave) if str(child.get_meta("prop_id")) == "coil_pylon" else base
		mat.set_shader_parameter("strength", live)


func _signature(board: Node2D) -> String:
	var tiles: Dictionary = board.get("tiles")
	return "%d|%s" % [tiles.size(), JSON.stringify(placements())]


func _rebuild(board: Node2D) -> void:
	clear_props()
	_key = ""
	var catalog := catalog_by_id()
	var occupied := {}
	var tiles: Dictionary = board.get("tiles")
	for cell in tiles.keys():
		occupied[cell] = true
	for item in placements():
		if not (item is Dictionary):
			continue
		var prop_id := str(item.get("id", ""))
		var spec: Dictionary = catalog.get(prop_id, {})
		if spec.is_empty():
			continue
		var origin := _origin_of(item)
		var footprint := _footprint_of(spec)
		var cells := footprint_cells(origin, footprint)
		var on_board := false
		for cell in cells:
			if occupied.has(cell):
				on_board = true
		if on_board:
			continue
		var anchor := anchor_cell(origin, footprint)
		var root := Node2D.new()
		root.name = "Prop_%s" % prop_id
		root.z_as_relative = false
		root.set_meta("prop_id", prop_id)
		root.set_meta("origin", origin)
		root.set_meta("anchor", anchor)
		root.set_meta("cells", cells)
		root.set_meta("strength", emission_strength(prop_id))
		var shadow := _make_shadow(footprint)
		root.add_child(shadow)
		var art := _make_art(spec)
		if art != null:
			root.add_child(art)
		add_child(root)


func _place(_board: Node2D) -> void:
	for child in get_children():
		var anchor: Vector2i = child.get_meta("anchor")
		child.position = south_tip(anchor)
		child.z_as_relative = false
		child.z_index = BoardVisualSort.unit_z_index(anchor)


func _make_art(spec: Dictionary) -> Sprite2D:
	var path := master_path(spec)
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.centered = false
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scale := DRAW_SCALE if uses_master(spec) else 1.0
	sprite.scale = Vector2(scale, scale)
	sprite.offset = -_anchor_px(spec)
	sprite.z_as_relative = true
	sprite.z_index = 0
	var emit_name := str(spec.get("file_emit", ""))
	if emit_name != "":
		var emit := load(ART_ROOT + emit_name) as Texture2D
		if emit != null:
			sprite.material = _emit_material(emit, emission_strength(str(spec.get("id", ""))))
	return sprite


func _make_shadow(footprint: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Shadow"
	sprite.centered = true
	sprite.texture = _ellipse(footprint)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(0.0, -CELL_HALF_H * float(footprint.y))
	sprite.z_as_relative = true
	sprite.z_index = -1
	sprite.material = _shadow_material()
	return sprite


func _emit_material(emit: Texture2D, strength: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = EMIT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("emit_tex", emit)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("glow_gain", glow_gain())
	return mat


func _shadow_material() -> ShaderMaterial:
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shadow_shader
	mat.set_shader_parameter("strength", shadow_strength())
	return mat


func _ellipse(footprint: Vector2i) -> Texture2D:
	var key := "%d,%d" % [footprint.x, footprint.y]
	if _shadow_tex.has(key):
		return _shadow_tex[key]
	var rx := CELL_HALF_W * float(footprint.x) * 0.62
	var ry := CELL_HALF_H * float(footprint.y) * 0.55
	var width := int(ceil(rx * 2.0)) + 4
	var height := int(ceil(ry * 2.0)) + 4
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var cx := float(width) * 0.5
	var cy := float(height) * 0.5
	for y in height:
		for x in width:
			var nx := (float(x) + 0.5 - cx) / maxf(rx, 1.0)
			var ny := (float(y) + 0.5 - cy) / maxf(ry, 1.0)
			var dist := nx * nx + ny * ny
			var falloff := clampf(1.0 - dist, 0.0, 1.0)
			falloff = falloff * falloff
			image.set_pixel(x, y, Color(1, 1, 1, falloff))
	var tex := ImageTexture.create_from_image(image)
	_shadow_tex[key] = tex
	return tex
