extends Node2D
class_name Pawn

var grid_position: Vector2i = Vector2i.ZERO
var unit_name: String = ""
var class_id: String = ""
var facing: String = "E"
var hp: int = 80
var max_hp: int = 80
var alive: bool = true
var is_active: bool = false

const FACING_ISO := {
	"N": Vector2(20, -10),
	"E": Vector2(20, 10),
	"S": Vector2(-20, 10),
	"W": Vector2(-20, -10),
}


func apply_snapshot(unit: Dictionary, active_seat: int) -> void:
	grid_position = unit["pos"]
	unit_name = str(unit["name"])
	class_id = str(unit["class_id"])
	facing = str(unit["facing"])
	hp = int(unit["hp"])
	max_hp = int(unit["max_hp"])
	alive = bool(unit["alive"])
	is_active = int(unit["seat"]) == active_seat and alive
	queue_redraw()


func _draw() -> void:
	var fill := Color("#4a8a62")
	if class_id == SpellKits.CLASS_IRONJAW:
		fill = Color("#b04a4a")
	if not alive:
		fill = Color(0.35, 0.35, 0.38, 0.85)
	if is_active:
		draw_circle(Vector2(0, -12), 14.0, Color(1, 0.92, 0.45, 0.55))
	draw_circle(Vector2(0, -12), 10.0, fill)
	draw_arc(Vector2(0, -12), 10.0, 0.0, TAU, 24, Color(0.12, 0.08, 0.1), 1.6, true)

	var pointer: Vector2 = FACING_ISO.get(facing, Vector2(20, 10))
	var tip := Vector2(0, -12) + pointer.normalized() * 18.0
	draw_line(Vector2(0, -12), tip, Color(0.12, 0.08, 0.1), 2.0, true)
	draw_circle(tip, 2.4, Color(0.12, 0.08, 0.1))

	var bar_origin := Vector2(-14, -28)
	draw_rect(Rect2(bar_origin, Vector2(28, 4)), Color(0.12, 0.1, 0.12))
	var ratio := 0.0 if max_hp <= 0 else clampf(float(maxi(hp, 0)) / float(max_hp), 0.0, 1.0)
	var hp_color := Color("#6fcf97") if class_id != SpellKits.CLASS_IRONJAW else Color("#f08a8a")
	draw_rect(Rect2(bar_origin, Vector2(28.0 * ratio, 4)), hp_color)

	var font := ThemeDB.fallback_font
	var label := unit_name
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	var label_x := -size.x * 0.5
	if class_id == SpellKits.CLASS_IRONJAW:
		label_x += 10.0
	else:
		label_x -= 10.0
	draw_string(font, Vector2(label_x, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.08, 0.1))
