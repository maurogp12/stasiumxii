extends Node2D

## One kit sprite. `pivot` is where the node origin sits on the art:
## bottom (south tip), top (chain hook), or center.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")

var art: Dictionary = {}
var pivot := "bottom"


func _draw() -> void:
	if art.is_empty():
		return
	var size := Art.size_of(art)
	var top_left := Vector2(-size.x * 0.5, -size.y)
	if pivot == "top":
		top_left = Vector2(-size.x * 0.5, 0.0)
	elif pivot == "center":
		top_left = Vector2(-size.x * 0.5, -size.y * 0.5)
	Art.draw_at(self, art, top_left)
