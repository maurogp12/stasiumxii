extends Node

## View-only arena for a board theme. Loads an existing Koliseo map.
## godot --path . res://scenes/pc/look_preview.tscn -- --theme=coilgate --map=stormspire

const FLOOR := preload("res://board/pc/coilgate_floor.gd")

var theme_id := "coilgate"
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
	add_child(load("res://main.tscn").instantiate())
