extends Control

## VIEW ONLY. Light screen-space snowfall over Northgate. It never takes
## input (mouse_filter ignore), sits under the NPC name plates and the HUD,
## and keeps a fixed, capped flake count. `level` fades in and out at the
## town edge; the world sets `target` from the snow cover under the hero.

const MAX_FLAKES := 140
## Level units per second, so the snow eases in over about a second and a half.
const FADE_RATE := 0.7

var level := 0.0
var target := 0.0
## World camera position and zoom, for a little parallax as the hero walks.
var camera_pos := Vector2.ZERO
var camera_zoom := 1.0
## Performance mode: `level` still follows the town (the grade reads it) but
## no flake is drawn.
var still := false

# Per flake: x, y (0..1 of the screen), depth (0..1), phase.
var _flakes: PackedFloat32Array = PackedFloat32Array()
var _dot: Texture2D
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dot = _flake_texture()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4411
	_flakes.resize(MAX_FLAKES * 4)
	for i in MAX_FLAKES:
		_flakes[i * 4] = rng.randf()
		_flakes[i * 4 + 1] = rng.randf()
		_flakes[i * 4 + 2] = rng.randf()
		_flakes[i * 4 + 3] = rng.randf() * TAU
	visible = false


func flake_count() -> int:
	return _flakes.size() / 4


## Jump straight to the target, for stills and zone loads.
func snap() -> void:
	level = target
	visible = level > 0.01 and not still
	queue_redraw()


func step(delta: float) -> void:
	level = move_toward(level, target, delta * FADE_RATE)
	visible = level > 0.01 and not still
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if level <= 0.01 or _dot == null:
		return
	var view := size
	if view.x < 1.0 or view.y < 1.0:
		view = get_viewport_rect().size
	var shift := camera_pos * camera_zoom
	for i in MAX_FLAKES:
		var fx := _flakes[i * 4]
		var fy := _flakes[i * 4 + 1]
		var depth := _flakes[i * 4 + 2]
		var phase := _flakes[i * 4 + 3]
		# Near flakes are bigger, faster, and slide more with the camera.
		var fall := 26.0 + 46.0 * depth
		var drift := 8.0 + 10.0 * depth
		var parallax := 0.25 + 0.55 * depth
		var x := fx * view.x + _time * drift + sin(_time * (0.6 + depth) + phase) * (6.0 + 6.0 * depth) - shift.x * parallax
		var y := fy * view.y + _time * fall - shift.y * parallax
		x = fposmod(x, view.x + 16.0) - 8.0
		y = fposmod(y, view.y + 16.0) - 8.0
		var s := 4.0 + 6.0 * depth
		var a := (0.7 + 0.3 * depth) * level
		draw_texture_rect(_dot, Rect2(Vector2(x, y) - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))


## A white core with a faint cool rim, so a flake still reads over snow.
static func _flake_texture() -> Texture2D:
	var n := 12
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (float(n) - 1.0) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var core := clampf(1.0 - d * 1.15, 0.0, 1.0)
			var rim := clampf(1.0 - absf(d - 0.7) * 3.5, 0.0, 1.0) * 0.55
			var col := Color(0.52, 0.56, 0.70, rim).blend(Color(1, 1, 1, core))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
