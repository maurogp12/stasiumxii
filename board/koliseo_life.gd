class_name KoliseoLife
extends Node2D

## View-only life on the five Locked Koliseo arenas.
## Grades the existing diamonds (contrast, north light, sheen, pulse) and
## drifts a few motes plus a soft light. Not walk data and not MP.
## Unknown maps stay ungraded so a proto board is not dressed as a biome.

const _Maps := preload("res://backend/cell_tag_map.gd")
const _Palette := preload("res://vfx/vfx_palette.gd")
const _Sort := preload("res://board/visual_sort.gd")
const GROUND_SHADER := preload("res://board/koliseo_ground.gdshader")
const MOTE_AMOUNT := 18
const ELEV_LIFT := 0.055

const _TERRAIN := {
	"ground": {"contrast": 1.26, "sat": 1.48, "shimmer": 0.16, "pulse": 0.034, "speed": 0.85},
	"mud": {"contrast": 1.18, "sat": 1.22, "shimmer": 0.06, "pulse": 0.022, "speed": 0.55},
	"water": {"contrast": 1.30, "sat": 1.58, "shimmer": 0.52, "pulse": 0.072, "speed": 2.15},
	"lava": {"contrast": 1.34, "sat": 1.52, "shimmer": 0.58, "pulse": 0.095, "speed": 2.7},
}
## Dark ink plus a pale gleam. Drawn on a child so the grade shader does not wash the grid.
const GRID_INK := Color(0.04, 0.03, 0.07, 0.82)
const GRID_GLEAM := Color(1.0, 0.97, 0.9, 0.62)

## grade / shimmer_color tint the existing sheets. shimmer_mul is per terrain.
const _BIOMES := {
	"crosshaven": {
		"grade": Color(0.92, 1.22, 0.62),
		"shimmer_color": Color(0.78, 1.0, 0.42),
		"light": Color(0.72, 1.0, 0.38),
		"mote": Color(0.72, 0.95, 0.38, 0.72),
		"direction": Vector2(0.2, -1.0),
		"gravity": Vector2(6.0, -12.0),
		"spread": 36.0,
		"speed_mul": 1.0,
		"pulse_mul": 1.0,
		"shimmer_mul": {"ground": 1.2, "mud": 0.65, "water": 1.15, "lava": 1.0},
	},
	"brinewake": {
		"grade": Color(0.62, 1.02, 1.32),
		"shimmer_color": Color(0.45, 0.92, 1.0),
		"light": Color(0.28, 0.72, 1.0),
		"mote": Color(0.55, 0.9, 1.0, 0.7),
		"direction": Vector2(1.0, -0.12),
		"gravity": Vector2(10.0, 4.0),
		"spread": 28.0,
		"speed_mul": 1.15,
		"pulse_mul": 1.2,
		"shimmer_mul": {"ground": 0.45, "mud": 0.4, "water": 1.4, "lava": 1.0},
	},
	"slagcrown": {
		"grade": Color(1.28, 0.78, 0.48),
		"shimmer_color": Color(1.0, 0.46, 0.12),
		"light": Color(1.0, 0.34, 0.08),
		"mote": Color(1.0, 0.48, 0.16, 0.78),
		"direction": Vector2(0.08, -1.0),
		"gravity": Vector2(2.0, -22.0),
		"spread": 24.0,
		"speed_mul": 1.25,
		"pulse_mul": 1.35,
		"shimmer_mul": {"ground": 0.32, "mud": 0.5, "water": 0.4, "lava": 1.3},
	},
	"windmere": {
		"grade": Color(0.7, 1.05, 1.34),
		"shimmer_color": Color(0.75, 0.94, 1.0),
		"light": Color(0.55, 0.82, 1.0),
		"mote": Color(0.86, 0.94, 1.0, 0.7),
		"direction": Vector2(0.85, 0.45),
		"gravity": Vector2(14.0, 18.0),
		"spread": 22.0,
		"speed_mul": 1.05,
		"pulse_mul": 0.85,
		"shimmer_mul": {"ground": 1.45, "mud": 0.8, "water": 1.25, "lava": 1.0},
	},
	"stormspire": {
		"grade": Color(0.78, 0.7, 1.32),
		"shimmer_color": Color(0.72, 0.58, 1.0),
		"light": Color(0.52, 0.34, 1.0),
		"mote": Color(0.82, 0.72, 1.0, 0.8),
		"direction": Vector2(0.35, -0.55),
		"gravity": Vector2(-4.0, -6.0),
		"spread": 78.0,
		"speed_mul": 1.85,
		"pulse_mul": 1.45,
		"shimmer_mul": {"ground": 1.55, "mud": 0.7, "water": 1.2, "lava": 1.1},
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
	var biome := ambient_for(map_id)
	if biome.is_empty():
		return Color(0, 0, 0, 0)
	return biome["light"]


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
	_glow.modulate = Color(light.r, light.g, light.b, 0.16)
	_glow.visible = true
	_glow.scale = Vector2(7.2, 5.4)


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
	var amp := 0.10 + 0.07 * (0.5 + 0.5 * sin(_time * 1.25))
	_glow.modulate = Color(light.r, light.g, light.b, amp)
	var breathe := 1.0 + 0.08 * sin(_time * 1.25)
	_glow.scale = Vector2(7.2, 5.4) * breathe
	queue_redraw()


func _draw() -> void:
	if not _BIOMES.has(_map_id) or _board_size < 2:
		return
	var rim := board_rim(_board_size)
	var loop := rim.duplicate()
	loop.append(rim[0])
	var tint: Color = edge_tint(_map_id)
	var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * 1.7))
	draw_polyline(loop, Color(tint.r, tint.g, tint.b, 0.22 * pulse), 16.0, true)
	draw_polyline(loop, Color(tint.r, tint.g, tint.b, 0.45 * pulse), 8.0, true)
	draw_polyline(loop, Color(tint.r, tint.g, tint.b, 0.85), 3.2, true)
	draw_polyline(loop, Color(1.0, 0.98, 0.94, 0.8 * pulse), 1.4, true)
