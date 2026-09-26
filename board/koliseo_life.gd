class_name KoliseoLife
extends Node2D

## View-only life on the five Locked Koliseo arenas.
## Grades the existing diamonds (contrast, north light, sheen, pulse) and
## drifts a few motes plus a soft light. Not walk data and not MP.
## Unknown maps stay ungraded so a proto board is not dressed as a biome.

const _Maps := preload("res://backend/cell_tag_map.gd")
const _Palette := preload("res://vfx/vfx_palette.gd")
const _Sort := preload("res://board/visual_sort.gd")
const _Art := preload("res://board/koliseo_art.gd")
const GROUND_SHADER := preload("res://board/koliseo_ground.gdshader")
const MOTE_AMOUNT := 18
const ELEV_LIFT := 0.055

## Painted grades. Shimmer stays a slow grain, not a glass highlight.
const _TERRAIN := {
	"ground": {"contrast": 1.18, "sat": 1.22, "shimmer": 0.08, "pulse": 0.016, "speed": 0.5},
	"mud": {"contrast": 1.12, "sat": 1.12, "shimmer": 0.04, "pulse": 0.012, "speed": 0.35},
	"water": {"contrast": 1.16, "sat": 1.18, "shimmer": 0.16, "pulse": 0.024, "speed": 0.75},
	"lava": {"contrast": 1.22, "sat": 1.26, "shimmer": 0.2, "pulse": 0.042, "speed": 0.95},
}
## Warm ink plus a parchment gleam. Drawn on a child so the grade shader does not wash the grid.
const GRID_INK := Color(0.1, 0.07, 0.05, 0.88)
const GRID_GLEAM := Color(0.95, 0.86, 0.68, 0.42)
const GRID_INK_PX := 2.35
const GRID_GLEAM_PX := 1.0
## Outer frame is ink, the same family as the cell lines.
const EDGE_INK := Color(0.08, 0.06, 0.05, 0.92)

## grade / shimmer_color tint the existing sheets. shimmer_mul is per terrain.
const _BIOMES := {
	"crosshaven": {
		"grade": Color(1.04, 1.14, 0.9),
		"shimmer_color": Color(0.98, 1.0, 0.82),
		"light": Color(1.0, 0.92, 0.7),
		"mote": Color(0.72, 0.82, 0.38, 0.42),
		"direction": Vector2(0.2, -1.0),
		"gravity": Vector2(6.0, -8.0),
		"spread": 28.0,
		"speed_mul": 0.85,
		"pulse_mul": 0.8,
		"shimmer_mul": {"ground": 0.7, "mud": 0.5, "water": 1.05, "lava": 1.0},
		"rim": ["ruins", "hay", "fence", "well", "rubble"],
	},
	"brinewake": {
		"grade": Color(0.94, 1.04, 0.96),
		"shimmer_color": Color(0.86, 0.94, 0.86),
		"light": Color(0.78, 0.88, 0.8),
		"mote": Color(0.62, 0.78, 0.7, 0.4),
		"direction": Vector2(1.0, -0.12),
		"gravity": Vector2(8.0, 3.0),
		"spread": 22.0,
		"speed_mul": 0.9,
		"pulse_mul": 0.85,
		"shimmer_mul": {"ground": 0.45, "mud": 0.4, "water": 1.35, "lava": 1.0},
		"rim": ["driftwood", "rock_cluster", "fence", "ruins", "waterfall"],
	},
	"slagcrown": {
		"grade": Color(1.12, 0.94, 0.78),
		"shimmer_color": Color(1.0, 0.74, 0.42),
		"light": Color(1.0, 0.62, 0.32),
		"mote": Color(0.92, 0.48, 0.18, 0.48),
		"direction": Vector2(0.08, -1.0),
		"gravity": Vector2(2.0, -16.0),
		"spread": 18.0,
		"speed_mul": 0.95,
		"pulse_mul": 1.05,
		"shimmer_mul": {"ground": 0.32, "mud": 0.45, "water": 0.4, "lava": 1.15},
		"rim": ["basalt_pillar", "ash_rock", "rock_pillar", "rubble", "steam_vent"],
	},
	"windmere": {
		"grade": Color(0.98, 1.02, 1.05),
		"shimmer_color": Color(0.96, 0.97, 0.94),
		"light": Color(0.94, 0.95, 0.96),
		"mote": Color(0.9, 0.92, 0.9, 0.32),
		"direction": Vector2(0.85, 0.45),
		"gravity": Vector2(10.0, 12.0),
		"spread": 16.0,
		"speed_mul": 0.7,
		"pulse_mul": 0.55,
		"shimmer_mul": {"ground": 0.35, "mud": 0.4, "water": 0.85, "lava": 1.0},
		"rim": ["rock_cluster", "ruins", "fence", "hay", "rock_pillar"],
	},
	"stormspire": {
		"grade": Color(1.06, 0.98, 0.9),
		"shimmer_color": Color(0.92, 0.86, 0.74),
		"light": Color(0.86, 0.78, 0.62),
		"mote": Color(0.72, 0.64, 0.5, 0.38),
		"direction": Vector2(0.25, -0.4),
		"gravity": Vector2(-2.0, -4.0),
		"spread": 20.0,
		"speed_mul": 0.65,
		"pulse_mul": 0.6,
		"shimmer_mul": {"ground": 0.4, "mud": 0.45, "water": 0.7, "lava": 1.0},
		"rim": ["rock_pillar", "ruins", "rubble", "basalt_pillar", "rock_cluster"],
	},
}


var _map_id := ""
var _board_size := 0
var _motes: CPUParticles2D
var _glow: Sprite2D
var _time := 0.0


static func is_ship(map_id: String) -> bool:
	return _Maps.SHIP_MAPS.has(_Maps.normalize_id(map_id))


## Numbers the tile shader reads. Non-ship maps return an identity grade.
static func grade_for(map_id: String, terrain: String, elevation: int, cell: Vector2i) -> Dictionary:
	var id := _Maps.normalize_id(map_id)
	var terrain_key := terrain if _TERRAIN.has(terrain) else "ground"
	var base: Dictionary = _TERRAIN[terrain_key]
	var phase := float(cell.x) * 0.73 + float(cell.y) * 0.41
	if not _BIOMES.has(id):
		return {
			"ship": false,
			"contrast": 1.0,
			"sat": 1.0,
			"lift": 1.0,
			"shimmer": 0.0,
			"pulse": 0.0,
			"speed": 0.0,
			"grade": Color.WHITE,
			"shimmer_color": Color.WHITE,
			"phase": phase,
		}
	var biome: Dictionary = _BIOMES[id]
	var mul: Dictionary = biome["shimmer_mul"]
	return {
		"ship": true,
		"contrast": float(base["contrast"]),
		"sat": float(base["sat"]),
		"lift": 1.0 + float(maxi(elevation, 0)) * ELEV_LIFT,
		"shimmer": float(base["shimmer"]) * float(mul.get(terrain_key, 1.0)),
		"pulse": float(base["pulse"]) * float(biome["pulse_mul"]),
		"speed": float(base["speed"]) * float(biome["speed_mul"]),
		"grade": biome["grade"],
		"shimmer_color": biome["shimmer_color"],
		"phase": phase,
	}


static func ambient_for(map_id: String) -> Dictionary:
	var id := _Maps.normalize_id(map_id)
	if not _BIOMES.has(id):
		return {}
	return _BIOMES[id]


## Outer diamond of a ship board. North, east, south, west tips.
static func board_rim(board_size: int) -> PackedVector2Array:
	var n := maxi(board_size, 1)
	var last := n - 1
	return PackedVector2Array([
		_Sort.cell_to_local(Vector2i(0, 0), 0.0) + Vector2(0, -16),
		_Sort.cell_to_local(Vector2i(last, 0), 0.0) + Vector2(32, 0),
		_Sort.cell_to_local(Vector2i(last, last), 0.0) + Vector2(0, 16),
		_Sort.cell_to_local(Vector2i(0, last), 0.0) + Vector2(-32, 0),
	])


static func edge_tint(map_id: String) -> Color:
	if ambient_for(map_id).is_empty():
		return Color(0, 0, 0, 0)
	return EDGE_INK


func _ready() -> void:
	z_as_relative = false
	# Above the iso stack (~tile z 300) and under Shade markers (640),
	# the aim line, and combat numbers. Motes read as weather.
	z_index = 480
	_motes = CPUParticles2D.new()
	_motes.name = "Motes"
	_motes.amount = MOTE_AMOUNT
	_motes.lifetime = 4.4
	_motes.preprocess = 3.2
	_motes.one_shot = false
	_motes.explosiveness = 0.0
	_motes.randomness = 0.65
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.local_coords = true
	_motes.texture = _Palette.dot_texture()
	_motes.scale_amount_min = 0.45
	_motes.scale_amount_max = 1.15
	_motes.emitting = false
	add_child(_motes)
	_glow = Sprite2D.new()
	_glow.name = "Light"
	_glow.texture = _Palette.ellipse_texture()
	_glow.centered = true
	_glow.scale = Vector2(7.2, 5.4)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.visible = false
	add_child(_glow)


## Swap the weather when the arena id changes. Snapshot refreshes do not rebuild.
func bind(map_id: String, board_size: int) -> void:
	var id := _Maps.normalize_id(map_id)
	var size := maxi(board_size, 1)
	if id == _map_id and size == _board_size and _motes != null:
		return
	_map_id = id
	_board_size = size
	_apply_ambient()


func _apply_ambient() -> void:
	if _motes == null or _glow == null:
		return
	var biome := ambient_for(_map_id)
	var center := Vector2(0.0, float(maxi(_board_size - 1, 0)) * 16.0)
	_motes.position = center
	_glow.position = center
	var reach := Vector2(float(_board_size) * 16.0, float(_board_size) * 8.0)
	_motes.emission_rect_extents = reach
	if biome.is_empty():
		_motes.emitting = false
		_glow.visible = false
		_clear_rim()
		return
	var dir: Vector2 = biome["direction"]
	_motes.direction = dir
	_motes.gravity = biome["gravity"]
	_motes.spread = float(biome["spread"])
	_motes.initial_velocity_min = 6.0
	_motes.initial_velocity_max = 18.0
	_motes.color = biome["mote"]
	_motes.emitting = true
	var light: Color = biome["light"]
	_glow.modulate = Color(light.r, light.g, light.b, 0.03)
	_glow.visible = true
	_glow.scale = Vector2(4.2, 2.8)
	_build_rim(biome)


func _clear_rim() -> void:
	var old := get_node_or_null("Rim")
	if old != null:
		old.free()


## Props standing just outside the playable diamond. Paint only.
## Tags, walk, and LoS do not read this.
func _build_rim(biome: Dictionary) -> void:
	_clear_rim()
	var names: Array = biome.get("rim", [])
	if names.is_empty() or _board_size < 2:
		return
	var rim := Node2D.new()
	rim.name = "Rim"
	add_child(rim)
	var n := _board_size
	var slots: Array[Vector2i] = []
	var step := 3
	var i := 1
	while i < n - 1:
		slots.append(Vector2i(i, -1))
		slots.append(Vector2i(i, n))
		slots.append(Vector2i(-1, i))
		slots.append(Vector2i(n, i))
		i += step
	var center := _Sort.cell_to_local(Vector2i(n / 2, n / 2), 0.0)
	var idx := 0
	for cell in slots:
		var prop_name := str(names[idx % names.size()])
		idx += 1
		var tex := _Art.prop_texture(prop_name)
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var at := _Sort.cell_to_local(cell, 0.0)
		var outward := at - center
		if outward.length_squared() > 1.0:
			at += outward.normalized() * 20.0
		sprite.position = at + Vector2(0.0, 8.0)
		sprite.offset = Vector2(0.0, -float(tex.get_height()) * 0.32)
		sprite.z_as_relative = false
		var sort_cell := Vector2i(clampi(cell.x, 0, n - 1), clampi(cell.y, 0, n - 1))
		sprite.z_index = _Sort.tile_z_index(sort_cell, 0.0)
		if cell.y >= n:
			sprite.z_index += 8
		rim.add_child(sprite)


func _process(delta: float) -> void:
	if _glow == null or not _glow.visible:
		return
	_time += delta
	var biome := ambient_for(_map_id)
	if biome.is_empty():
		return
	var center := Vector2(0.0, float(maxi(_board_size - 1, 0)) * 16.0)
	var drift := Vector2(sin(_time * 0.33) * 42.0, cos(_time * 0.27) * 22.0)
	_glow.position = center + drift
	var light: Color = biome["light"]
	var amp := 0.02 + 0.012 * (0.5 + 0.5 * sin(_time * 0.8))
	_glow.modulate = Color(light.r, light.g, light.b, amp)
	var breathe := 1.0 + 0.03 * sin(_time * 0.8)
	_glow.scale = Vector2(4.2, 2.8) * breathe
	queue_redraw()


func _draw() -> void:
	if not _BIOMES.has(_map_id) or _board_size < 2:
		return
	var rim := board_rim(_board_size)
	var loop := rim.duplicate()
	loop.append(rim[0])
	draw_polyline(loop, EDGE_INK, 2.4, true)
