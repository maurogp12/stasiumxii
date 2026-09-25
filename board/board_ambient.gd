class_name BoardAmbient
extends Node

## View-only board chrome. CombatSim never reads this file.
## Water/mud shimmer, highlight breathe, apron dust, and a few prop pulses.
## cell_to_local and elevation stay in BoardVisualSort.

const SHIMMER_PERIOD := 2.8
const SHIMMER_AMPLITUDE_WATER := 0.045
const SHIMMER_AMPLITUDE_MUD := 0.028
const SHIMMER_UV_WATER := 0.004
const SHIMMER_UV_MUD := 0.0022

const OVERLAY_ALPHA_MIN := 0.42
const OVERLAY_ALPHA_MAX := 0.58
const OVERLAY_PERIOD := 1.5

const CRISP_OUTLINE_PX := 2.0
const CRISP_INNER_PX := 1.0

## One pixel of overlap closes linear-filter hairlines between diamonds.
## Tree order breaks same-z ties, so the overlap does not flicker.
const SEAM_BLEED_PX := 1.0

const MOTE_AMOUNT := 10
const MOTE_LIFETIME := 8.0
## Above ship-map pawns (tile z + unit bias) and under Shade (640) and numbers (900).
const MOTE_Z := 400
const APRON_PX := 48.0
const MOTE_ALPHA := 0.22

const PROP_PERIOD := 1.7
const PROP_SCALE_AMP := 0.02
const PROP_GAIN_AMP := 0.035

const AMBIENT_PROPS: Array[String] = ["waterfall", "steam_vent", "spark", "crystal"]

const _MOTION := preload("res://units/view_motion.gd")

static var _shader: Shader
static var _mote_tex: Texture2D

var _board: Node
var _motes: CPUParticles2D
var _time: float = 0.0
var _reduced: bool = false


static func shimmers(terrain: String) -> bool:
	return terrain == "water" or terrain == "mud"


static func prop_is_ambient(prop_name: String) -> bool:
	return prop_name in AMBIENT_PROPS


static func motion_reduced() -> bool:
	return _MOTION.reduce_motion()


static func phase_for(cell: Vector2i) -> float:
	return float(cell.x) * 0.65 + float(cell.y) * 0.41


static func shimmer_speed() -> float:
	return TAU / SHIMMER_PERIOD


static func shimmer_amplitude(terrain: String) -> float:
	if terrain == "mud":
		return SHIMMER_AMPLITUDE_MUD
	return SHIMMER_AMPLITUDE_WATER


static func shimmer_uv(terrain: String) -> float:
	if terrain == "mud":
		return SHIMMER_UV_MUD
	return SHIMMER_UV_WATER


static func shimmer_gain(time_sec: float, phase: float, terrain: String) -> float:
	var amp := shimmer_amplitude(terrain)
	return 1.0 + sin(TAU * time_sec / SHIMMER_PERIOD + phase) * amp


static func overlay_breathes(kind: String, selected: bool) -> bool:
	if kind == "blocked":
		return false
	if selected or kind == "selected":
		return true
	return kind == "move" or kind == "range" or kind == "target"


static func overlay_fill_alpha(time_sec: float, phase: float) -> float:
	var mid := (OVERLAY_ALPHA_MIN + OVERLAY_ALPHA_MAX) * 0.5
	var amp := (OVERLAY_ALPHA_MAX - OVERLAY_ALPHA_MIN) * 0.5
	return mid + sin(TAU * time_sec / OVERLAY_PERIOD + phase) * amp


static func prop_scale(time_sec: float, phase: float) -> float:
	return 1.0 + sin(TAU * time_sec / PROP_PERIOD + phase) * PROP_SCALE_AMP


static func prop_gain(time_sec: float, phase: float) -> float:
	return 1.0 + sin(TAU * time_sec / PROP_PERIOD + phase) * PROP_GAIN_AMP


static func shimmer_shader() -> Shader:
	if _shader == null:
		_shader = load("res://board/board_shimmer.gdshader") as Shader
	return _shader


static func mote_texture() -> Texture2D:
	if _mote_tex != null:
		return _mote_tex
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(2.5, 2.5)
	for y in 6:
		for x in 6:
			var dist := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			var alpha := clampf(1.0 - dist / 2.6, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	_mote_tex = ImageTexture.create_from_image(image)
	return _mote_tex


func bind(board: Node) -> void:
	_board = board
	var size := 15
	var raw: Variant = board.get("_board_size")
	if raw != null:
		size = int(raw)
	fit_to_size(size)


func fit_to_size(size: int) -> void:
	_reduced = motion_reduced()
	var n := maxi(size, 1)
	var half_w := 32.0
	var half_h := 16.0
	var min_x := float(0 - (n - 1)) * 32.0 - half_w
	var max_x := float(n - 1) * 32.0 + half_w
	var min_y := -half_h
	var max_y := float((n - 1) + (n - 1)) * 16.0 + half_h
	var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	_ensure_motes()
	_motes.position = center
	_motes.emission_rect_extents = Vector2(
		(max_x - min_x) * 0.5 + APRON_PX,
		(max_y - min_y) * 0.5 + APRON_PX
	)
	_sync_mote_emission(_reduced)


func _ready() -> void:
	_reduced = motion_reduced()
	_ensure_motes()


func _process(delta: float) -> void:
	_time += delta
	var reduced := motion_reduced()
	if reduced != _reduced:
		_reduced = reduced
		_sync_mote_emission(reduced)
		_resync_tiles()
	_tick_tiles(_time)


func _ensure_motes() -> void:
	if _motes != null and is_instance_valid(_motes):
		return
	_motes = CPUParticles2D.new()
	_motes.name = "Motes"
	_motes.z_as_relative = false
	_motes.z_index = MOTE_Z
	_motes.amount = MOTE_AMOUNT
	_motes.lifetime = MOTE_LIFETIME
	_motes.preprocess = MOTE_LIFETIME
	_motes.one_shot = false
	_motes.explosiveness = 0.0
	_motes.randomness = 0.4
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(480, 280)
	_motes.direction = Vector2(0.2, -1.0)
	_motes.spread = 40.0
	_motes.gravity = Vector2(1.5, -3.0)
	_motes.initial_velocity_min = 3.0
	_motes.initial_velocity_max = 8.0
	_motes.scale_amount_min = 1.2
	_motes.scale_amount_max = 2.2
	_motes.local_coords = true
	_motes.texture = mote_texture()
	_motes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_motes.color = Color(0.97, 0.93, 0.86, 1.0)
	_motes.color_ramp = _mote_ramp()
	_motes.emitting = false
	add_child(_motes)


func _mote_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.96, 0.92, 0.84, 0.0))
	ramp.set_color(1, Color(0.96, 0.92, 0.84, 0.0))
	ramp.add_point(0.18, Color(0.97, 0.93, 0.86, MOTE_ALPHA))
	ramp.add_point(0.72, Color(0.93, 0.88, 0.78, MOTE_ALPHA * 0.62))
	return ramp


func _sync_mote_emission(reduced: bool) -> void:
	_ensure_motes()
	if reduced:
		_motes.emitting = false
		return
	if _motes.emitting:
		return
	_motes.emitting = true
	_motes.restart()


func _tick_tiles(time_sec: float) -> void:
	if _board == null:
		return
	var tiles: Variant = _board.get("tiles")
	if typeof(tiles) != TYPE_DICTIONARY:
		return
	for tile in (tiles as Dictionary).values():
		if tile != null and is_instance_valid(tile) and tile.has_method("apply_ambient_frame"):
			tile.call("apply_ambient_frame", time_sec)


func _resync_tiles() -> void:
	if _board == null:
		return
	var tiles: Variant = _board.get("tiles")
	if typeof(tiles) != TYPE_DICTIONARY:
		return
	for tile in (tiles as Dictionary).values():
		if tile != null and is_instance_valid(tile) and tile.has_method("resync_shimmer"):
			tile.call("resync_shimmer")
