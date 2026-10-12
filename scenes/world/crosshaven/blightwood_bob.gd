extends Node

## Lifts wisp nodes on the dress host. Still when animations are off.

func _process(_delta: float) -> void:
	var host := get_parent()
	if host == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for child in host.get_children():
		if not (child is Node2D) or not child.has_meta("bob"):
			continue
		var body := child as Node2D
		var base := float(body.get_meta("base_y"))
		var phase := float(body.get_meta("phase"))
		body.position.y = base + sin(t * 1.3 + phase) * 7.0
