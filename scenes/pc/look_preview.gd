extends Node

## View-only arena for a board theme. Loads an existing Koliseo map.
## godot --path . res://scenes/pc/look_preview.tscn -- --theme=thunderwell --map=stormspire

const FLOOR := preload("res://board/pc/thunderwell_floor.gd")

var theme_id := "thunderwell"
var map_id := "stormspire"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--theme="):
			theme_id = text.trim_prefix("--theme=")
		elif text.begins_with("--map="):
			map_id = text.trim_prefix("--map=")
	ClassSelect.hotseat_map_id = map_id
	FLOOR.request_theme(theme_id)
	FLOOR.preview_bloom = theme_id == "thunderwell"
	if theme_id == "thunderwell":
		_enable_preview_glow()
	add_child(load("res://main.tscn").instantiate())


func _enable_preview_glow() -> void:
	var vp := get_viewport()
	vp.use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	var followed := maxf(FLOOR.glow_strength(), maxf(FLOOR.pad_strength(), FLOOR.pillar_strength()))
	var cap := minf(followed, float(FLOOR.load_params().get("preview_bloom", 0.36)))
	env.glow_enabled = true
	env.glow_intensity = cap
	env.glow_strength = cap
	env.glow_bloom = cap * 0.25
	env.glow_hdr_threshold = 1.05
	env.glow_hdr_scale = 1.0
	var world := WorldEnvironment.new()
	world.name = "PreviewGlow"
	world.environment = env
	add_child(world)
