extends Node2D

## One walk-through decor sprite. It never blocks. Ground decals sit just above
## the floor; everything else y-sorts with props.

const Art := preload("res://scenes/world/crosshaven/crosshaven_art.gd")
const Pick := preload("res://scenes/world/crosshaven/crosshaven_pick.gd")

var decor_type := ""
var _art: Dictionary = {}
var _sway: AnimatedSprite2D


func setup(zone: WorldZone, record: Dictionary) -> void:
	decor_type = str(record["type"])
	var cell := Vector2i(int(record["x"]), int(record["y"]))
	position = BoardVisualSort.cell_to_local(cell, float(zone.height_at(cell))) + Vector2(0, Pick.HALF_H)
	z_as_relative = false
	var groundish := decor_type.begins_with("decal_") or decor_type == "lilypads_a" or decor_type == "ford_stones"
	z_index = (cell.x + cell.y) * BoardVisualSort.TILE_Z_SCALE + (1 if groundish else 2)
	_art = Art.texture("props", decor_type)
	if not groundish:
		_sway = Art.make_loop(decor_type + "_sway")
		if _sway != null:
			_sway.visible = false
			add_child(_sway)
	queue_redraw()


func _process(_delta: float) -> void:
	if _sway == null:
		return
	var on := VisualSettings.current != null and VisualSettings.current.enabled("animations")
	if _sway.visible != on:
		_sway.visible = on
		queue_redraw()


func _draw() -> void:
	if _sway != null and _sway.visible:
		return
	if _art.is_empty():
		return
	var size := Art.size_of(_art)
	Art.draw_at(self, _art, Vector2(-size.x * 0.5, -size.y))
