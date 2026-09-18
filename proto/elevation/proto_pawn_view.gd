class_name ProtoPawnView
extends Node2D

## Prototype pawn token. Not a Phase A CombatSim unit.

var label: String = "Scout"
var fill: Color = Color(0.35, 0.62, 0.92)
var is_blocker: bool = false


func _draw() -> void:
	var body := fill
	if is_blocker:
		body = Color(0.42, 0.40, 0.38)
	draw_circle(Vector2(0, -12), 11.0, body)
	draw_arc(Vector2(0, -12), 11.0, 0.0, TAU, 24, Color(0.10, 0.08, 0.08), 1.6, true)
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2(-size.x * 0.5, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.08, 0.06, 0.06))
