extends Node2D

## Pooled one-shot. The director never instantiates these during combat.

var in_use: bool = false
var _tween: Tween


func _ready() -> void:
	visible = false
	position = Vector2(-4000, -4000)


func release() -> void:
	_kill_tween()
	in_use = false
	visible = false
	set_process(false)
	position = Vector2(-4000, -4000)
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	z_index = 0


func prewarm() -> void:
	visible = true
	position = Vector2(-4000, -4000)
	in_use = true


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _begin() -> void:
	_kill_tween()
	in_use = true
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	set_process(true)
