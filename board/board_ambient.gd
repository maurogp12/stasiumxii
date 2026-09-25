class_name BoardAmbient
extends Node

## View-only board chrome. CombatSim never reads this file.
## Seat, facing, wind, and AP/MP stay the first read. This layer stays quieter.
## cell_to_local and elevation stay in BoardVisualSort.

const SHIMMER_PERIOD := 4.2
const SHIMMER_AMPLITUDE_WATER := 0.03
const SHIMMER_AMPLITUDE_MUD := 0.018
const SHIMMER_UV_WATER := 0.0015
const SHIMMER_UV_MUD := 0.001

## Centered on the 0.5 fill. The full swing is 8 points of opacity, not more.
const OVERLAY_ALPHA_MIN := 0.46
const OVERLAY_ALPHA_MAX := 0.54
const OVERLAY_PERIOD := 1.5

const CRISP_OUTLINE_PX := 2.0
const CRISP_INNER_PX := 1.0

## One pixel of overlap closes linear-filter hairlines between diamonds.
## Tree order breaks same-z ties, so the overlap does not flicker.
const SEAM_BLEED_PX := 1.0

## Two side strips, three specks each. They never cover the diamond.
const MOTE_PER_STRIP := 3
const MOTE_AMOUNT := 6
const MOTE_LIFETIME := 7.0
## Under every tile and pawn, so a stray speck cannot cover a silhouette or a floater.
const MOTE_Z := -4
const APRON_PX := 40.0
const APRON_BAND := 16.0
## Pull the strips in from the north and south tips, clear of the top bar and the bottom toast.
const APRON_V_INSET := 64.0
const MOTE_SPREAD_DEG := 6.0
const MOTE_SPEED_MAX := 3.0
const MOTE_ALPHA := 0.14

const PROP_PERIOD := 1.7
const PROP_SCALE_AMP := 0.02
## Dim only. A crest above the paint reads as a glint.
const PROP_GAIN_AMP := 0.02

const AMBIENT_PROPS: Array[String] = ["waterfall", "steam_vent", "spark", "crystal"]

const _MOTION := preload("res://units/view_motion.gd")

static var _shader: Shader
static var _mote_tex: Texture2D

var _board: Node
var _strips: Array[CPUParticles2D] = []
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


## Crest is 1.0 (the painted texel). The trough is 1.0 - amplitude. Never brighter.
static func shimmer_gain(time_sec: float, phase: float, terrain: String) -> float:
	var amp := shimmer_amplitude(terrain)
	var wave := sin(TAU * time_sec / SHIMMER_PERIOD + phase)
	return 1.0 - amp * (0.5 - 0.5 * wave)


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


## Crest is the painted prop. The pulse only dips, so it cannot flash.
static func prop_gain(time_sec: float, phase: float) -> float:
	var wave := sin(TAU * time_sec / PROP_PERIOD + phase)
	return 1.0 - PROP_GAIN_AMP * (0.5 - 0.5 * wave)


static func diamond_bounds(size: int) -> Rect2:
	var n := maxi(size, 1)
	var half_w := 32.0
	var half_h := 16.0
	var min_x := float(0 - (n - 1)) * 32.0 - half_w
	var max_x := float(n - 1) * 32.0 + half_w
	var min_y := -half_h
	var max_y := float((n - 1) + (n - 1)) * 16.0 + half_h
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


## True when a side strip sits fully outside the diamond and short of its north/south tips.
static func strip_clears_playfield(center: Vector2, extents: Vector2, bounds: Rect2, outward_x: float) -> bool:
	var rect := Rect2(center - extents, extents * 2.0)
	if outward_x < 0.0:
		if rect.end.x > bounds.position.x:
			return false
	elif rect.position.x < bounds.end.x:
		return false
	if rect.position.y <= bounds.position.y:
		return false
	if rect.end.y >= bounds.end.y:
		return false
	return true


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
	_ensure_motes()
	var bounds := diamond_bounds(size)
	var gap := (APRON_PX - APRON_BAND) * 0.5
	var half_band := APRON_BAND * 0.5
	var y_half := maxf(bounds.size.y * 0.5 - APRON_V_INSET, 8.0)
	var mid := bounds.get_center()
	var left := _strips[0]
	left.position = Vector2(bounds.position.x - gap - half_band, mid.y)
	left.emission_rect_extents = Vector2(half_band, y_half)
	left.direction = Vector2(-1, 0)
	var right := _strips[1]
	right.position = Vector2(bounds.end.x + gap + half_band, mid.y)
	right.emission_rect_extents = Vector2(half_band, y_half)
	right.direction = Vector2(1, 0)
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
	if _strips.size() == 2 and is_instance_valid(_strips[0]):
		return
	_strips.clear()
	var root := Node2D.new()
	root.name = "Motes"
	add_child(root)
	_strips.append(_make_strip(root, "Left"))
	_strips.append(_make_strip(root, "Right"))


func _make_strip(parent: Node, strip_name: String) -> CPUParticles2D:
	var motes := CPUParticles2D.new()
	motes.name = strip_name
	motes.z_as_relative = false
	motes.z_index = MOTE_Z
	motes.amount = MOTE_PER_STRIP
	motes.lifetime = MOTE_LIFETIME
	motes.preprocess = MOTE_LIFETIME
	motes.one_shot = false
	motes.explosiveness = 0.0
	motes.randomness = 0.25
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(8, 24)
	motes.direction = Vector2(-1, 0)
	motes.spread = MOTE_SPREAD_DEG
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 1.0
	motes.initial_velocity_max = MOTE_SPEED_MAX
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 1.6
	motes.local_coords = true
	motes.texture = mote_texture()
	motes.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	motes.color = Color(0.86, 0.82, 0.74, 1.0)
	motes.color_ramp = _mote_ramp()
	motes.emitting = false
	parent.add_child(motes)
	return motes


func _mote_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.96, 0.92, 0.84, 0.0))
	ramp.set_color(1, Color(0.96, 0.92, 0.84, 0.0))
	ramp.add_point(0.18, Color(0.97, 0.93, 0.86, MOTE_ALPHA))
	ramp.add_point(0.72, Color(0.93, 0.88, 0.78, MOTE_ALPHA * 0.62))
	return ramp


func _sync_mote_emission(reduced: bool) -> void:
	_ensure_motes()
	for motes in _strips:
		if reduced:
			motes.emitting = false
			continue
		if motes.emitting:
			continue
		motes.emitting = true
		motes.restart()


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
