extends Node2D

## Three fog bands glued to the camera. Far drifts slowest (parallax), near
## a little faster. They fade out across the entry's west and north edges
## so the meadow joins are not a fog wall.

const Kit := preload("res://scenes/world/crosshaven/blightwood_art.gd")
const SHADER := preload("res://scenes/world/crosshaven/blightwood_fog.gdshader")

const SPECS := [
	# Upper bands only. The foreground path stays clear of the teal wash.
	{"file": "fog_layer_far", "parallax": 0.16, "speed": 10.0, "alpha": 0.55, "y": 0.0, "z": -130.0, "h": 240.0},
	{"file": "fog_layer_mid", "parallax": 0.34, "speed": 16.0, "alpha": 0.34, "y": 0.16, "z": -36.0, "h": 180.0},
	{"file": "fog_layer_near", "parallax": 0.55, "speed": 24.0, "alpha": 0.18, "y": 0.34, "z": -6.0, "h": 120.0},
]

var _bands: Array[Node2D] = []
var _mats: Array[ShaderMaterial] = []


func _ready() -> void:
	z_as_relative = false
	for spec in SPECS:
		var art: Dictionary = Kit.v2_texture("fx", str(spec["file"]))
		var band := Node2D.new()
		band.name = str(spec["file"])
		band.z_as_relative = false
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		if not art.is_empty():
			mat.set_shader_parameter("fog_tex", art["tex"])
		band.material = mat
		band.draw.connect(_draw_band.bind(band, spec))
		add_child(band)
		_bands.append(band)
		_mats.append(mat)
	set_process(true)


func _process(_delta: float) -> void:
	var world := get_parent()
	if world == null:
		return
	var zone: WorldZone = world.get("zone")
	var show := zone != null and zone.region == "blightwood_hollow"
	visible = show
	if not show:
		return
	var cam: Camera2D = world.get("camera")
	if cam == null:
		return
	position = cam.position
	var zoom := maxf(cam.zoom.x, 0.01)
	var view := get_viewport().get_visible_rect().size / zoom
	var cell := _world_cell(cam.position)
	var fade := _join_fade(world, zone, cell)
	var drift := 1.0 if Kit.animated() else 0.0
	var base_z := (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE
	for i in _bands.size():
		var spec: Dictionary = SPECS[i]
		var band := _bands[i]
		band.z_index = clampi(base_z + int(spec["z"]), -4096, 4096)
		band.modulate = Color(1, 1, 1, float(spec["alpha"]) * fade)
		var width := view.x + 120.0
		var height := float(spec["h"])
		var top := -view.y * 0.5 + view.y * float(spec["y"])
		band.set_meta("rect", Rect2(-width * 0.5, top, width, height))
		var scroll := cam.position.x * float(spec["parallax"]) / 1024.0
		if drift > 0.5:
			scroll += Time.get_ticks_msec() / 1000.0 * float(spec["speed"]) / 1024.0
		_mats[i].set_shader_parameter("uv_scale_x", width / 1024.0)
		_mats[i].set_shader_parameter("scroll", scroll)
		band.queue_redraw()


func _draw_band(band: Node2D, _spec: Dictionary) -> void:
	var rect: Rect2 = band.get_meta("rect", Rect2())
	if rect.size.x < 2.0:
		return
	var poly := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	band.draw_polygon(poly, cols, uvs)


## Local cell on the current chunk, from a world-pixel camera position.
func _world_cell(pixel: Vector2) -> Vector2i:
	var x := (pixel.x / 32.0 + pixel.y / 16.0) * 0.5
	var y := (pixel.y / 16.0 - pixel.x / 32.0) * 0.5
	return Vector2i(int(round(x)), int(round(y)))


func _join_fade(world: Node, zone: WorldZone, world_cell: Vector2i) -> float:
	if zone == null or not zone.zone_id.ends_with("_entry"):
		return 1.0
	var origin: Vector2i = world.call("_origin_of", zone.zone_id)
	var local := world_cell - origin
	var fade := 1.0
	if local.x < 10:
		fade = minf(fade, clampf(float(local.x) / 10.0, 0.0, 1.0))
	if local.y < 10:
		fade = minf(fade, clampf(float(local.y) / 10.0, 0.0, 1.0))
	return fade
