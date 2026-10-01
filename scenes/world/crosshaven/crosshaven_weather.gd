extends Node

## VIEW ONLY (client-side visual, Proposed in the zone data). Day/night tint
## and the four weather looks: clear, light_cloud, light_rain, wind.
## It never feeds movement or anything the server checks.

signal weather_changed(weather: String)

const WEATHERS: Array[String] = ["clear", "light_cloud", "light_rain", "wind"]
const DAY_SECONDS := 720.0  # one in-game day per 12 real minutes
const BLEND_SECONDS := 3.0

var time_of_day := 10.0  # hours, 0..24
var time_scale := 1.0
var weather := "clear"
var auto_rotate := true
var rotation_pool: Array = ["clear"]

var _modulate: CanvasModulate
var _cloud: Sprite2D
var _rain: CPUParticles2D
var _splash: CPUParticles2D
var _fog: ColorRect
var _leaves: CPUParticles2D
var _amount := {"light_cloud": 0.0, "light_rain": 0.0, "wind": 0.0}
var _next_rotate := 90.0
var _rng := RandomNumberGenerator.new()
## When false, rain, cloud cover, and leaves hide. Day and night tint stays.
var visuals_enabled := true


func set_visuals_enabled(on: bool) -> void:
	visuals_enabled = on
	_apply(0.0)


func setup(world: Node2D, screen_layer: CanvasLayer) -> void:
	_rng.seed = 1209
	_modulate = CanvasModulate.new()
	world.add_child(_modulate)

	var noise := FastNoiseLite.new()
	noise.frequency = 0.006
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0, 0, 0, 0.0))
	ramp.set_color(1, Color(0.05, 0.06, 0.12, 0.4))
	ramp.set_offset(0, 0.45)
	tex.color_ramp = ramp
	_cloud = Sprite2D.new()
	_cloud.texture = tex
	_cloud.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_cloud.region_enabled = true
	_cloud.region_rect = Rect2(0, 0, 6000, 4000)
	_cloud.scale = Vector2(1.0, 0.5)
	_cloud.position = Vector2(-1500, -300)
	_cloud.centered = false
	_cloud.z_as_relative = false
	_cloud.z_index = 3000
	_cloud.modulate.a = 0.0
	world.add_child(_cloud)

	_rain = CPUParticles2D.new()
	_rain.amount = 260
	_rain.lifetime = 0.85
	_rain.preprocess = 1.0
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(900, 12)
	_rain.direction = Vector2(-0.22, 1)
	_rain.spread = 4.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 820.0
	_rain.initial_velocity_max = 1080.0
	_rain.scale_amount_min = 0.85
	_rain.scale_amount_max = 1.35
	_rain.color = Color(0.78, 0.86, 0.98, 0.5)
	_rain.texture = _streak_texture()
	_rain.particle_flag_align_y = true
	_rain.position = Vector2(480, -30)
	_rain.emitting = false
	screen_layer.add_child(_rain)

	_splash = CPUParticles2D.new()
	_splash.amount = 48
	_splash.lifetime = 0.32
	_splash.preprocess = 0.4
	_splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splash.emission_rect_extents = Vector2(480, 180)
	_splash.direction = Vector2(0, -1)
	_splash.spread = 36.0
	_splash.gravity = Vector2(0, 420)
	_splash.initial_velocity_min = 24.0
	_splash.initial_velocity_max = 70.0
	_splash.scale_amount_min = 0.35
	_splash.scale_amount_max = 0.9
	_splash.color = Color(0.82, 0.9, 1.0, 0.4)
	_splash.texture = _dot_texture()
	_splash.position = Vector2(480, 420)
	_splash.emitting = false
	screen_layer.add_child(_splash)

	_fog = ColorRect.new()
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.color = Color(0.62, 0.7, 0.8, 0.0)
	screen_layer.add_child(_fog)

	_leaves = CPUParticles2D.new()
	_leaves.amount = 36
	_leaves.lifetime = 5.0
	_leaves.preprocess = 4.0
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.emission_rect_extents = Vector2(10, 420)
	_leaves.direction = Vector2(1, 0.15)
	_leaves.spread = 12.0
	_leaves.gravity = Vector2(0, 14)
	_leaves.initial_velocity_min = 180.0
	_leaves.initial_velocity_max = 280.0
	_leaves.angular_velocity_min = -180.0
	_leaves.angular_velocity_max = 180.0
	_leaves.scale_amount_min = 3.0
	_leaves.scale_amount_max = 5.0
	_leaves.color = Color("c9a24a")
	_leaves.position = Vector2(-20, 360)
	_leaves.emitting = false
	screen_layer.add_child(_leaves)
	_apply(0.0)


func set_weather(next: String) -> void:
	if not WEATHERS.has(next):
		return
	weather = next
	_next_rotate = _rng.randf_range(75.0, 120.0)
	weather_changed.emit(weather)


func cycle_weather() -> void:
	set_weather(WEATHERS[(WEATHERS.find(weather) + 1) % WEATHERS.size()])


func set_zone_pool(pool: Array) -> void:
	rotation_pool = []
	for w in pool:
		if WEATHERS.has(str(w)):
			rotation_pool.append(str(w))
	if rotation_pool.is_empty():
		rotation_pool = ["clear"]
	if not rotation_pool.has(weather):
		set_weather(str(rotation_pool[0]))


## Snap blends to their targets (tests, zone loads).
func settle() -> void:
	for key in _amount.keys():
		_amount[key] = 1.0 if key == weather else 0.0
	_apply(0.0)


func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta * time_scale * 24.0 / DAY_SECONDS, 24.0)
	if auto_rotate and rotation_pool.size() > 1:
		_next_rotate -= delta
		if _next_rotate <= 0.0:
			var options := rotation_pool.filter(func(w): return w != weather)
			set_weather(str(options[_rng.randi() % options.size()]))
	var step := delta / BLEND_SECONDS
	for key in _amount.keys():
		_amount[key] = move_toward(_amount[key], 1.0 if key == weather else 0.0, step)
	_apply(delta)


func daylight_color() -> Color:
	var night := Color(0.32, 0.38, 0.62)
	var dawn := Color(1.0, 0.78, 0.62)
	var noon := Color(1.0, 0.96, 0.9)
	var dusk := Color(0.98, 0.66, 0.5)
	var h := time_of_day
	if h < 5.0 or h >= 21.0:
		return night
	if h < 7.0:
		return night.lerp(dawn, (h - 5.0) / 2.0)
	if h < 10.0:
		return dawn.lerp(noon, (h - 7.0) / 3.0)
	if h < 16.0:
		return noon
	if h < 19.0:
		return noon.lerp(dusk, (h - 16.0) / 3.0)
	return dusk.lerp(night, (h - 19.0) / 2.0)


func current_tint() -> Color:
	var c := daylight_color()
	c = c.lerp(c * Color(0.86, 0.88, 0.94), _amount["light_cloud"])
	c = c.lerp(c * Color(0.7, 0.74, 0.84), _amount["light_rain"])
	c.a = 1.0
	return c


func clock_text() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]


func _apply(delta: float) -> void:
	if _modulate == null:
		return
	_place_screen()
	_modulate.color = current_tint() if visuals_enabled else daylight_color()
	var rain_amt: float = float(_amount["light_rain"])
	var cloud_amt: float = float(_amount["light_cloud"])
	var wind_amt: float = float(_amount["wind"])
	var cover := maxf(cloud_amt, rain_amt * 0.8)
	_cloud.modulate.a = cover if visuals_enabled else 0.0
	_cloud.region_rect.position += Vector2(14.0, 4.0) * delta * (1.0 + 2.0 * wind_amt)
	var rain_on: bool = visuals_enabled and rain_amt > 0.05
	_rain.emitting = rain_on
	_rain.modulate.a = rain_amt if visuals_enabled else 0.0
	if _splash != null:
		_splash.emitting = rain_on
		_splash.modulate.a = rain_amt if visuals_enabled else 0.0
	if _fog != null:
		var fog_a := 0.0
		if visuals_enabled:
			fog_a = rain_amt * 0.22 + cloud_amt * 0.10
		_fog.color = Color(0.62, 0.7, 0.8, fog_a)
	_leaves.emitting = visuals_enabled and wind_amt > 0.05
	_leaves.modulate.a = wind_amt if visuals_enabled else 0.0


func _place_screen() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var size := vp.get_visible_rect().size
	if size.x < 2.0:
		return
	_rain.position = Vector2(size.x * 0.5, -40.0)
	_rain.emission_rect_extents = Vector2(size.x * 0.72, 12.0)
	if _splash != null:
		_splash.position = Vector2(size.x * 0.5, size.y * 0.62)
		_splash.emission_rect_extents = Vector2(size.x * 0.5, size.y * 0.28)
	_leaves.position = Vector2(-20.0, size.y * 0.5)


static func _streak_texture() -> Texture2D:
	var img := Image.create(2, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		var a := float(y) / 21.0
		img.set_pixel(0, y, Color(1, 1, 1, a))
		img.set_pixel(1, y, Color(1, 1, 1, a * 0.45))
	return ImageTexture.create_from_image(img)


static func _dot_texture() -> Texture2D:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		for x in 6:
			var d := Vector2(float(x) - 2.5, float(y) - 2.5).length() / 2.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
