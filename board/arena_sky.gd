class_name ArenaSky
extends Node2D

## Dofus-style scenery for the five Koliseo arenas: a painted day sky behind
## everything and a rock slab under the board, so the arena reads as a
## floating island instead of a diamond in a black void.
## View only. Not walk data, not MP, not legality. Unknown maps (proto boards)
## keep the plain clear color and no slab.

const _Maps := preload("res://backend/cell_tag_map.gd")
const _Sort := preload("res://board/visual_sort.gd")
const _Palette := preload("res://vfx/vfx_palette.gd")
const SKY_SHADER := preload("res://board/arena_sky.gdshader")
## Below every tile (tile z starts at 0) and the arena light.
const SLAB_Z := -200
const SLAB_DEPTH := 30.0

## sky_top / sky_bottom / cloud / sun, slab top / slab bottom, cloud amount.
const SKIES := {
	"crosshaven": {
		"top": Color(0.47, 0.74, 0.93), "bottom": Color(0.94, 0.95, 0.86),
		"cloud": Color(1.0, 1.0, 1.0), "sun": Color(1.0, 0.94, 0.78), "clouds": 0.6,
		"slab_top": Color(0.52, 0.38, 0.24), "slab_bottom": Color(0.24, 0.17, 0.11),
	},
	"brinewake": {
		"top": Color(0.30, 0.62, 0.88), "bottom": Color(0.80, 0.93, 0.96),
		"cloud": Color(1.0, 1.0, 1.0), "sun": Color(0.96, 0.98, 0.92), "clouds": 0.55,
		"slab_top": Color(0.40, 0.33, 0.25), "slab_bottom": Color(0.16, 0.20, 0.24),
	},
	"slagcrown": {
		"top": Color(0.26, 0.10, 0.10), "bottom": Color(0.96, 0.56, 0.28),
		"cloud": Color(0.55, 0.36, 0.30), "sun": Color(1.0, 0.62, 0.30), "clouds": 0.5,
		"slab_top": Color(0.30, 0.17, 0.12), "slab_bottom": Color(0.10, 0.05, 0.05),
	},
	"windmere": {
		"top": Color(0.58, 0.77, 0.95), "bottom": Color(0.95, 0.97, 1.0),
		"cloud": Color(1.0, 1.0, 1.0), "sun": Color(0.96, 0.98, 1.0), "clouds": 0.65,
		"slab_top": Color(0.62, 0.72, 0.84), "slab_bottom": Color(0.30, 0.38, 0.50),
	},
	"stormspire": {
		"top": Color(0.18, 0.17, 0.36), "bottom": Color(0.62, 0.56, 0.84),
		"cloud": Color(0.70, 0.66, 0.86), "sun": Color(0.86, 0.80, 1.0), "clouds": 0.75,
		"slab_top": Color(0.28, 0.25, 0.38), "slab_bottom": Color(0.10, 0.09, 0.16),
	},
}

var _map_id := ""
var _board_size := 0
var _layer: CanvasLayer
var _sky: ColorRect
var _mat: ShaderMaterial


static func sky_for(map_id: String) -> Dictionary:
	return SKIES.get(_Maps.normalize_id(map_id), {})


func _ready() -> void:
	z_as_relative = false
	z_index = SLAB_Z
	_layer = CanvasLayer.new()
	_layer.name = "SkyLayer"
	_layer.layer = -20
	add_child(_layer)
	_sky = ColorRect.new()
	_sky.name = "Sky"
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SKY_SHADER
	_sky.material = _mat
	_sky.visible = false
	_layer.add_child(_sky)


## Swap the scenery when the arena id changes. Snapshot refreshes do not rebuild.
func bind(map_id: String, board_size: int) -> void:
	var id := _Maps.normalize_id(map_id)
	var size := maxi(board_size, 1)
	if id == _map_id and size == _board_size:
		return
	_map_id = id
	_board_size = size
	var spec := sky_for(id)
	if _sky != null:
		_sky.visible = not spec.is_empty()
		if not spec.is_empty():
			_mat.set_shader_parameter("sky_top", spec["top"])
			_mat.set_shader_parameter("sky_bottom", spec["bottom"])
			_mat.set_shader_parameter("cloud_color", spec["cloud"])
			_mat.set_shader_parameter("sun_color", spec["sun"])
			_mat.set_shader_parameter("cloud_amount", float(spec["clouds"]))
	queue_redraw()


func sky_visible() -> bool:
	return _sky != null and _sky.visible


## Outer diamond of the board, same tips KoliseoLife uses for the edge ink.
func _rim() -> PackedVector2Array:
	var last := maxi(_board_size, 1) - 1
	return PackedVector2Array([
		_Sort.cell_to_local(Vector2i(0, 0), 0.0) + Vector2(0, -16),
		_Sort.cell_to_local(Vector2i(last, 0), 0.0) + Vector2(32, 0),
		_Sort.cell_to_local(Vector2i(last, last), 0.0) + Vector2(0, 16),
		_Sort.cell_to_local(Vector2i(0, last), 0.0) + Vector2(-32, 0),
	])


func _draw() -> void:
	var spec := sky_for(_map_id)
	if spec.is_empty():
		return
	var rim := _rim()
	var east: Vector2 = rim[1]
	var south: Vector2 = rim[2]
	var west: Vector2 = rim[3]
	var drop := Vector2(0, SLAB_DEPTH)
	var top: Color = spec["slab_top"]
	var bottom: Color = spec["slab_bottom"]
	# Soft cast shadow on the clouds below the island.
	var center := (rim[0] + south) * 0.5 + Vector2(0, SLAB_DEPTH + 40.0)
	var shadow := _Palette.ellipse_texture()
	if shadow != null:
		var size := Vector2(east.x - west.x, (south.y - rim[0].y) * 0.55) * 1.05
		draw_texture_rect(shadow, Rect2(center - size * 0.5, size), false, Color(0.05, 0.06, 0.12, 0.22))
	# Two faces of the slab under the south-west and south-east rims.
	var left := PackedVector2Array([west, south, south + drop * 1.25, west + drop])
	var right := PackedVector2Array([south, east, east + drop, south + drop * 1.25])
	draw_polygon(left, PackedColorArray([top, top.darkened(0.08), bottom, bottom]))
	draw_polygon(right, PackedColorArray([top.darkened(0.22), top.darkened(0.3), bottom.darkened(0.25), bottom.darkened(0.2)]))
	# A strata line and a dark lip so the slab reads as rock, not a ribbon.
	var strata := Color(0, 0, 0, 0.18)
	draw_line(west + drop * 0.45, south + drop * 0.6, strata, 2.0, true)
	draw_line(south + drop * 0.6, east + drop * 0.45, strata, 2.0, true)
	var lip := Color(0.06, 0.04, 0.03, 0.55)
	draw_line(west + drop, south + drop * 1.25, lip, 2.0, true)
	draw_line(south + drop * 1.25, east + drop, lip, 2.0, true)
