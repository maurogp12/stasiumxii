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
var stunned: bool = false
var burning: bool = false
var burn_remaining: int = 0
var _hit_flash: bool = false

const FACING_ISO := {
	"N": Vector2(20, -10),
	"E": Vector2(20, 10),
	"S": Vector2(-20, 10),
	"W": Vector2(-20, -10),
}


## `events` supply Burn only when the unit dict has no `burn_remaining`.
## This pawn does not tick Burn; the next host snapshot replaces the number.
func apply_snapshot(unit: Dictionary, active_seat: int, events: Array = []) -> void:
	grid_position = unit["pos"]
	unit_name = str(unit["name"])
	class_id = str(unit["class_id"])
	facing = str(unit["facing"])
	hp = int(unit["hp"])
	max_hp = int(unit["max_hp"])
	alive = bool(unit["alive"])
	is_active = int(unit["seat"]) == active_seat and alive
	_hit_flash = false
	stunned = int(unit.get("stun_remaining", 0)) > 0 or bool(unit.get("stunned", false))
	burn_remaining = CombatHUD.unit_burn_remaining(unit, events)
	burning = burn_remaining > 0
	queue_redraw()


func burn_badge_label() -> String:
	return CombatHUD.burn_badge_text(burn_remaining)


func set_facing(dir: String) -> void:
	if dir == "" or dir == facing:
		return
	facing = dir
	queue_redraw()


func flash_hit() -> void:
	_hit_flash = true
	modulate = Color(1.85, 1.55, 1.15)
	queue_redraw()


func flash_impact() -> void:
	modulate = Color(1.35, 1.2, 0.75)
	queue_redraw()


func _draw() -> void:
	var fill := _body_color()
	if not alive:
		fill = Color(0.35, 0.35, 0.38, 0.85)
	if is_active:
		draw_circle(Vector2(0, -12), 14.0, Color(1, 0.92, 0.45, 0.55))
	if stunned:
		draw_circle(Vector2(0, -12), 16.0, Color(0.95, 0.78, 0.2, 0.35))
	if burning:
		draw_circle(Vector2(0, -12), 18.0, Color(0.95, 0.32, 0.1, 0.28))
	var body := fill
	if _hit_flash:
		body = body.lightened(0.35)
	draw_circle(Vector2(0, -12), 10.0, body)
	draw_arc(Vector2(0, -12), 10.0, 0.0, TAU, 24, Color(0.12, 0.08, 0.1), 1.6, true)

	var pointer: Vector2 = FACING_ISO.get(facing, Vector2(20, 10))
	var tip := Vector2(0, -12) + pointer.normalized() * 18.0
	draw_line(Vector2(0, -12), tip, Color(0.12, 0.08, 0.1), 2.0, true)
	draw_circle(tip, 2.4, Color(0.12, 0.08, 0.1))

	var bar_origin := Vector2(-14, -28)
	draw_rect(Rect2(bar_origin, Vector2(28, 4)), Color(0.12, 0.1, 0.12))
	var ratio := 0.0 if max_hp <= 0 else clampf(float(maxi(hp, 0)) / float(max_hp), 0.0, 1.0)
	var hp_color := _body_color().lightened(0.25)
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
	if stunned:
		var stun_size := font.get_string_size("STUN", HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var badge := Rect2(Vector2(-stun_size.x * 0.5 - 3, -44), Vector2(stun_size.x + 6, 12))
		draw_rect(badge, Color(0.95, 0.78, 0.18, 0.95))
		draw_string(font, Vector2(-stun_size.x * 0.5, -34), "STUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.12, 0.08, 0.1))
	if burning:
		var burn_label := burn_badge_label()
		if burn_label == "":
			burn_label = "BURN"
		var burn_size := font.get_string_size(burn_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var burn_y := -58.0 if stunned else -44.0
		var burn_badge := Rect2(Vector2(-burn_size.x * 0.5 - 3, burn_y), Vector2(burn_size.x + 6, 12))
		draw_rect(burn_badge, Color(0.92, 0.28, 0.1, 0.95))
		_draw_flame(Vector2(burn_badge.position.x - 8.0, burn_y + 6.0))
		draw_string(font, Vector2(-burn_size.x * 0.5, burn_y + 10), burn_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.99, 0.94, 0.88))


func _body_color() -> Color:
	match class_id:
		SpellKits.CLASS_IRONJAW:
			return Color("#b04a4a")
		SpellKits.CLASS_MENDER:
			return Color("#3d6ea8")
		SpellKits.CLASS_GLOAM:
			return Color("#6a5088")
		SpellKits.CLASS_BASTION:
			return Color("#7a7364")
		_:
			return Color("#4a8a62")


func _draw_flame(origin: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0, -7),
		origin + Vector2(3.5, -1),
		origin + Vector2(1.5, 0),
		origin + Vector2(3, 5),
		origin + Vector2(0, 2.5),
		origin + Vector2(-3, 5),
		origin + Vector2(-1.5, 0),
		origin + Vector2(-3.5, -1),
	]), Color(1.0, 0.42, 0.08, 0.98))
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0, -1),
		origin + Vector2(1.6, 2.2),
		origin + Vector2(0, 4),
		origin + Vector2(-1.6, 2.2),
	]), Color(1.0, 0.88, 0.4, 0.98))
