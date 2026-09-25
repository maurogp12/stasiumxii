extends Node2D

## Standalone review scene. F9 steps every generic effect. No match and no combat rules.
## Run: godot --path . res://vfx/vfx_preview.tscn

const _Director := preload("res://vfx/vfx_director.gd")

var pawns_by_seat: Dictionary = {}
var _director: Node
var _caption: Label


func _ready() -> void:
	position = Vector2(480, 168)
	_build_backdrop()
	_build_pawns()
	_director = _Director.new()
	_director.name = "VfxDirector"
	add_child(_director)
	_director.bind_board(self)
	if _director.has_signal("debug_beat"):
		_director.debug_beat.connect(_on_beat)
	_build_caption()
	_director._play_next_debug()


func _cell_to_local(cell: Vector2i) -> Vector2:
	return BoardVisualSort.cell_to_local(cell, 0.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-520, -80), Vector2(1040, 640)), Color(0.09, 0.07, 0.06, 1.0), true)
	for y in 8:
		for x in 8:
			var center := _cell_to_local(Vector2i(x, y))
			var pts := PackedVector2Array([
				center + Vector2(0, -16),
				center + Vector2(32, 0),
				center + Vector2(0, 16),
				center + Vector2(-32, 0),
			])
			draw_colored_polygon(pts, Color(0.22, 0.18, 0.12, 1.0))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.10, 0.06, 0.05, 1.0), 1.0, true)
	for seat in pawns_by_seat.keys():
		var pawn: Node2D = pawns_by_seat[seat]
		var color := Color("3FA35B") if int(seat) == 0 else Color("C23B2E")
		draw_circle(pawn.position + Vector2(0, -28), 16.0, color)
		draw_arc(pawn.position + Vector2(0, -28), 18.0, 0, TAU, 20, Color("1A1016"), 2.0, true)


func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.09, 0.07, 0.06)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	layer.add_child(rect)


func _build_pawns() -> void:
	for seat in [0, 1]:
		var pawn := Node2D.new()
		pawn.name = "PreviewPawn%d" % seat
		var cell := Vector2i(2, 3) if seat == 0 else Vector2i(4, 3)
		pawn.position = _cell_to_local(cell)
		add_child(pawn)
		pawns_by_seat[seat] = pawn


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(16, 44)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color("F3E9D2"))
	_caption.text = "F9 steps generic VFX on the test cells. Numbers do not lock input."
	layer.add_child(_caption)


func _on_beat(beat_name: String) -> void:
	if _caption != null:
		_caption.text = "Preview  %s    —  F9 next generic effect" % beat_name
