extends Control
class_name StasisStub

## Retired coming-soon scene. The hub opens scenes/stasis_run.tscn.
## An old path that still loads this file forwards into that run.
## Mobile only. Not a PC main scene.

var _auto_launch: bool = true


func _ready() -> void:
	if not _auto_launch:
		return
	call_deferred("_forward")


func _forward() -> void:
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(StasisCatalog.RUN_SCENE)
