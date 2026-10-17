extends Node3D

## Shared city lighting: sun, sky, fog, tone and the day/night clock.
## Keyframes come from the city file's "time" block; between keys every
## value is blended. Forward+ gets SSAO and SSIL; the Compatibility
## renderer (captures under xvfb) ignores them and keeps the rest.

signal hour_changed(hour: float)

var keys: Array = []
var hour := 10.0
var time_scale := 0.0          ## game hours per real second (0 = frozen)
var lamps_on := 18.5
var lamps_off := 6.5
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var world_env: WorldEnvironment
var builder = null             ## city_builder, for lamps and windows
var sun_yaw := -35.0


func setup(city: Dictionary) -> void:
	var t: Dictionary = city.get("time", {})
	keys = t.get("keys", [])
	lamps_on = float(t.get("lamps_on", 18.5))
	lamps_off = float(t.get("lamps_off", 6.5))
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.06
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.6
	sun.light_angular_distance = 1.2
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = false
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.rotation_degrees = Vector3(-55, 140, 0)
	add_child(moon)
	apply()


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	apply()


func _process(delta: float) -> void:
	if time_scale > 0.0:
		set_hour(hour + delta * time_scale)


func _sample() -> Dictionary:
	if keys.is_empty():
		return {}
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[keys.size() - 1]
	for i in range(keys.size() - 1):
		if hour >= float(keys[i]["hour"]) and hour <= float(keys[i + 1]["hour"]):
			a = keys[i]
			b = keys[i + 1]
			break
	var span := maxf(0.001, float(b["hour"]) - float(a["hour"]))
	var t := clampf((hour - float(a["hour"])) / span, 0.0, 1.0)
	var out := {}
	for k in a.keys():
		if k == "hour":
			continue
		var va: Variant = a[k]
		var vb: Variant = b.get(k, va)
		if va is Array:
			out[k] = Color(lerpf(va[0], vb[0], t), lerpf(va[1], vb[1], t), lerpf(va[2], vb[2], t))
		else:
			out[k] = lerpf(float(va), float(vb), t)
	return out


func night_amount() -> float:
	# 1 while the lamps are lit, easing over half an hour at each end.
	var h := hour
	if h >= lamps_on or h < lamps_off:
		var to_on := h - lamps_on if h >= lamps_on else 99.0
		var to_off := lamps_off - h if h < lamps_off else 99.0
		return clampf(minf(to_on, to_off) * 2.0, 0.0, 1.0) if minf(to_on, to_off) < 0.5 else 1.0
	return 0.0


func apply() -> void:
	var s := _sample()
	if s.is_empty():
		return
	var elev: float = s["elev"]
	# The sun swings east to west over the day.
	var yaw := sun_yaw + (hour - 12.0) * 15.0
	sun.rotation_degrees = Vector3(-maxf(elev, 2.0), yaw, 0)
	sun.light_color = s["sun"]
	sun.light_energy = s["sun_energy"] if elev > -2.0 else 0.0
	sun.visible = elev > -3.0
	moon.light_energy = clampf(-elev / 20.0, 0.0, 1.0) * 0.35
	moon.visible = moon.light_energy > 0.01
	sky_mat.sky_top_color = s["sky_top"]
	sky_mat.sky_horizon_color = s["sky_horizon"]
	sky_mat.ground_horizon_color = (s["sky_horizon"] as Color).darkened(0.3)
	sky_mat.ground_bottom_color = (s["fog"] as Color).darkened(0.6)
	sky_mat.sun_angle_max = 25.0
	env.ambient_light_color = s["ambient"]
	env.ambient_light_energy = s["ambient_energy"]
	env.fog_light_color = s["fog"]
	env.fog_density = s["fog_density"]
	env.tonemap_exposure = s["exposure"]
	if builder != null:
		builder.set_night(night_amount())
	hour_changed.emit(hour)
