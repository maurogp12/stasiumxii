class_name ArenaSky
extends Node2D

## Scenery around the five Koliseo arenas, following Mauro's look pictures
## (29 Sep): a dark painted backdrop behind everything, and an edge under or
## around the board: a rock slab (Slagcrown, Stormspire, Crosshaven), dark
## water with foam around the dock (Brinewake), or a snowy rock wall ring
## (Windmere). View only. Not walk data, not MP, not legality. Unknown maps
## (proto boards) keep the plain clear color and no edge.

const _Maps := preload("res://backend/cell_tag_map.gd")
const _Sort := preload("res://board/visual_sort.gd")
const _Palette := preload("res://vfx/vfx_palette.gd")
const SKY_SHADER := preload("res://board/arena_sky.gdshader")
const STORM_BOLTS := preload("res://board/storm_bolts.gd")
const SNOW_FALL := preload("res://board/snow_fall.gd")
const AMBIENT_MOTES := preload("res://board/ambient_motes.gd")
## Below every tile (tile z starts at 0) and the arena light.
const SLAB_Z := -200
const SLAB_DEPTH := 30.0

const SKIES := {
	"crosshaven": {
		"top": Color(0.03, 0.05, 0.10), "bottom": Color(0.10, 0.14, 0.22),
		"cloud": Color(0.30, 0.34, 0.44), "sun": Color(0.95, 0.80, 0.55), "clouds": 0.25,
		"edge": "slab", "slab_top": Color(0.50, 0.44, 0.34), "slab_bottom": Color(0.20, 0.17, 0.13),
		"lip": Color(0.10, 0.08, 0.06, 0.6), "motes": "pollen",
	},
	"brinewake": {
		"top": Color(0.01, 0.03, 0.07), "bottom": Color(0.02, 0.08, 0.17),
		"cloud": Color(0.10, 0.22, 0.36), "sun": Color(0.30, 0.55, 0.85), "clouds": 0.35,
		"edge": "ocean", "slab_top": Color(0.27, 0.21, 0.16), "slab_bottom": Color(0.12, 0.09, 0.07),
		"water": Color(0.02, 0.09, 0.18), "foam": Color(0.70, 0.85, 0.95, 0.55), "motes": "spray",
	},
	"slagcrown": {
		"top": Color(0.01, 0.0, 0.0), "bottom": Color(0.10, 0.02, 0.01),
		"cloud": Color(0.30, 0.06, 0.02), "sun": Color(1.0, 0.30, 0.06), "clouds": 0.30,
		"edge": "slab", "slab_top": Color(0.16, 0.09, 0.07), "slab_bottom": Color(0.04, 0.02, 0.02),
		"lip": Color(1.0, 0.42, 0.10, 0.75), "motes": "embers",
	},
	"windmere": {
		"top": Color(0.02, 0.04, 0.10), "bottom": Color(0.07, 0.11, 0.22),
		"cloud": Color(0.40, 0.50, 0.66), "sun": Color(0.70, 0.82, 1.0), "clouds": 0.22,
		"edge": "rim_wall", "slab_top": Color(0.52, 0.58, 0.68), "slab_bottom": Color(0.20, 0.24, 0.32),
		"snow": Color(0.90, 0.94, 0.99), "rock": Color(0.44, 0.48, 0.56), "rock_dark": Color(0.27, 0.30, 0.37),
		"snowfall": true,
	},
	"stormspire": {
		"top": Color(0.02, 0.03, 0.10), "bottom": Color(0.07, 0.07, 0.20),
		"cloud": Color(0.28, 0.22, 0.46), "sun": Color(0.66, 0.50, 1.0), "clouds": 0.40,
		"edge": "slab", "slab_top": Color(0.13, 0.12, 0.18), "slab_bottom": Color(0.04, 0.04, 0.08),
		"lip": Color(1.0, 0.80, 0.30, 0.8), "bolts": true, "motes": "sparks",
	},
}

var _map_id := ""
var _board_size := 0
var _layer: CanvasLayer
var _sky: ColorRect
var _mat: ShaderMaterial
var _bolts: Node2D
var _snow: Node2D
var _motes: Node2D


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
	_bind_bolts(bool(spec.get("bolts", false)), size)
	_bind_snow(bool(spec.get("snowfall", false)), size)
	_bind_motes(str(spec.get("motes", "")), size)
	queue_redraw()


## Drifting air life per arena (embers / pollen / spray / sparks). View only.
func _bind_motes(style: String, size: int) -> void:
	if style == "":
		if _motes != null and is_instance_valid(_motes):
			_motes.visible = false
		return
	if _motes == null or not is_instance_valid(_motes):
		_motes = AMBIENT_MOTES.new()
		_motes.name = "AmbientMotes"
		add_child(_motes)
	_motes.configure(style, size)
	_motes.visible = true


func motes_style() -> String:
	if _motes == null or not is_instance_valid(_motes) or not _motes.visible:
		return ""
	return str(_motes.style)


## Windmere snowfall (view only). Other arenas keep it hidden.
func _bind_snow(enabled: bool, size: int) -> void:
	if not enabled:
		if _snow != null and is_instance_valid(_snow):
			_snow.visible = false
		return
	if _snow == null or not is_instance_valid(_snow):
		_snow = SNOW_FALL.new()
		_snow.name = "SnowFall"
		add_child(_snow)
	_snow.set_board_size(size)
	_snow.visible = true


func snow_visible() -> bool:
	return _snow != null and is_instance_valid(_snow) and _snow.visible


## Stormspire lightning (view only). Other arenas keep it hidden.
func _bind_bolts(enabled: bool, size: int) -> void:
	if not enabled:
		if _bolts != null and is_instance_valid(_bolts):
			_bolts.visible = false
		return
	if _bolts == null or not is_instance_valid(_bolts):
		_bolts = STORM_BOLTS.new()
		_bolts.name = "StormBolts"
		add_child(_bolts)
	_bolts.set_board_size(size)
	_bolts.visible = true


func sky_visible() -> bool:
	return _sky != null and _sky.visible


## Outer diamond of the board (N, E, S, W tips), same as KoliseoLife's edge.
func _rim(grow: float = 0.0) -> PackedVector2Array:
	var last := maxi(_board_size, 1) - 1
	var pts := PackedVector2Array([
		_Sort.cell_to_local(Vector2i(0, 0), 0.0) + Vector2(0, -16),
		_Sort.cell_to_local(Vector2i(last, 0), 0.0) + Vector2(32, 0),
		_Sort.cell_to_local(Vector2i(last, last), 0.0) + Vector2(0, 16),
		_Sort.cell_to_local(Vector2i(0, last), 0.0) + Vector2(-32, 0),
	])
	if grow == 0.0:
		return pts
	var center := (pts[0] + pts[2]) * 0.5
	var out := PackedVector2Array()
	for p in pts:
		var d := p - center
		out.append(p + Vector2(signf(d.x) * grow * 2.0, signf(d.y) * grow))
	return out


func _draw() -> void:
	var spec := sky_for(_map_id)
	if spec.is_empty():
		return
	match str(spec.get("edge", "slab")):
		"ocean":
			_draw_ocean(spec)
		"rim_wall":
			_draw_rim_wall(spec)
		_:
			_draw_slab(spec)


func _draw_cast_shadow(rim: PackedVector2Array, alpha: float) -> void:
	var shadow := _Palette.ellipse_texture()
	if shadow == null:
		return
	var center := (rim[0] + rim[2]) * 0.5 + Vector2(0, SLAB_DEPTH + 40.0)
	var size := Vector2(rim[1].x - rim[3].x, (rim[2].y - rim[0].y) * 0.55) * 1.05
	draw_texture_rect(shadow, Rect2(center - size * 0.5, size), false, Color(0, 0, 0, alpha))


## Floating slab under the board. The lip glows on lava and storm boards.
func _draw_slab(spec: Dictionary) -> void:
	var rim := _rim()
	_draw_cast_shadow(rim, 0.35)
	var east: Vector2 = rim[1]
	var south: Vector2 = rim[2]
	var west: Vector2 = rim[3]
	var drop := Vector2(0, SLAB_DEPTH)
	var top: Color = spec["slab_top"]
	var bottom: Color = spec["slab_bottom"]
	draw_polygon(PackedVector2Array([west, south, south + drop * 1.25, west + drop]), PackedColorArray([top, top.darkened(0.08), bottom, bottom]))
	draw_polygon(PackedVector2Array([south, east, east + drop, south + drop * 1.25]), PackedColorArray([top.darkened(0.22), top.darkened(0.3), bottom.darkened(0.25), bottom.darkened(0.2)]))
	var strata := Color(0, 0, 0, 0.22)
	draw_line(west + drop * 0.45, south + drop * 0.6, strata, 2.0, true)
	draw_line(south + drop * 0.6, east + drop * 0.45, strata, 2.0, true)
	var lip: Color = spec.get("lip", Color(0.06, 0.04, 0.03, 0.55))
	# The board's outer edge: a lit line like the glowing seams in the pictures.
	var ring := PackedVector2Array(rim)
	ring.append(rim[0])
	draw_polyline(ring, Color(lip.r, lip.g, lip.b, lip.a * 0.35), 7.0, true)
	draw_polyline(ring, lip, 2.2, true)


## Dark sea around the dock: a wide water skirt, a foam line hugging the pier
## and a short plank face so the deck sits just above the water.
func _draw_ocean(spec: Dictionary) -> void:
	var rim := _rim()
	var sea := _rim(90.0)
	var water: Color = spec["water"]
	draw_colored_polygon(sea, water)
	var mid := _rim(40.0)
	draw_colored_polygon(mid, water.lightened(0.05))
	var drop := Vector2(0, 8.0)
	var plank: Color = spec["slab_top"]
	draw_colored_polygon(PackedVector2Array([rim[3], rim[2], rim[2] + drop, rim[3] + drop]), plank)
	draw_colored_polygon(PackedVector2Array([rim[2], rim[1], rim[1] + drop, rim[2] + drop]), plank.darkened(0.3))
	var foam: Color = spec["foam"]
	for i in 3:
		var ring := _rim(6.0 + float(i) * 9.0)
		ring.append(ring[0])
		var a := foam.a * (1.0 - float(i) * 0.3)
		draw_polyline(ring, Color(foam.r, foam.g, foam.b, a), 1.6 - float(i) * 0.4, true)


## Snowy rock wall around the ice ring. The far walls rise behind the board;
## the near walls stay low and drop to a cliff so they never hide a cell.
func _draw_rim_wall(spec: Dictionary) -> void:
	var rim := _rim()
	var outer := _rim(34.0)
	_draw_cast_shadow(outer, 0.3)
	var snow: Color = spec["snow"]
	var rock: Color = spec["rock"]
	var dark: Color = spec["rock_dark"]
	var lift := Vector2(0, -26.0)
	# Far walls (N-W and N-E edges): inner rock face, then the snow cap.
	for pair in [[3, 0], [0, 1]]:
		var a: Vector2 = rim[pair[0]]
		var b: Vector2 = rim[pair[1]]
		var oa: Vector2 = outer[pair[0]]
		var ob: Vector2 = outer[pair[1]]
		draw_colored_polygon(PackedVector2Array([a, b, b + lift, a + lift]), rock if pair[0] == 3 else dark)
		draw_colored_polygon(PackedVector2Array([a + lift, b + lift, ob + lift, oa + lift]), snow)
		draw_line(a + lift, b + lift, Color(1, 1, 1, 0.8), 1.5, true)
	# Near walls (S-W and S-E edges): a snow ledge and a cliff face below it.
	var drop := Vector2(0, SLAB_DEPTH + 6.0)
	for pair in [[3, 2], [2, 1]]:
		var a: Vector2 = rim[pair[0]]
		var b: Vector2 = rim[pair[1]]
		var oa: Vector2 = outer[pair[0]]
		var ob: Vector2 = outer[pair[1]]
		draw_colored_polygon(PackedVector2Array([a, b, ob, oa]), snow.darkened(0.05))
		var face := rock if pair[0] == 3 else dark
		draw_colored_polygon(PackedVector2Array([oa, ob, ob + drop, oa + drop]), face)
		draw_line(oa, ob, Color(1, 1, 1, 0.7), 1.4, true)
	# Blocky breaks in the rock so the wall reads as stacked stone.
	for i in range(1, 10):
		var t := float(i) / 10.0
		for pair in [[3, 2], [2, 1]]:
			var p: Vector2 = outer[pair[0]].lerp(outer[pair[1]], t)
			draw_line(p, p + drop, Color(0, 0, 0, 0.18), 1.2, true)
