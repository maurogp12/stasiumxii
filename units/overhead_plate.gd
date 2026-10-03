extends Node2D
class_name OverheadPlate

## Name and life bar over a fighter. View only. The numbers come from the
## CombatSim snapshot the pawn already applied. This node shows them; it
## never decides them. The bar width eases toward the snapshot so a hit
## drains instead of popping.

const TEAM_P1 := Color(74.0 / 255.0, 143.0 / 255.0, 224.0 / 255.0)
const TEAM_P2 := Color(224.0 / 255.0, 90.0 / 255.0, 74.0 / 255.0)
const BAR_W := 34.0
const BAR_H := 5.0
const DRAIN_SEC := 0.85
## A hitch must not skip the drain. One frame counts as at most a 30fps step.
const DRAIN_STEP_CAP := 1.0 / 30.0
## Flattened pointy hex under the feet. Stays inside one 64×32 cell.
const HEX_RX := 18.0
const HEX_RY := 8.0
const HEX_FILL_ALPHA := 0.48

var host: Pawn
var _shown: float = -1.0
var _target: float = 1.0
var _life: int = 0
var _life_max: int = 1


static func team_color(seat: int) -> Color:
	if seat == 1:
		return TEAM_P2
	return TEAM_P1


static func hex_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts


func shown_ratio() -> float:
	return _shown


func target_ratio() -> float:
	return _target


func snapshot_life() -> int:
	return _life


func sync_from_unit(unit: Dictionary) -> void:
	var life := int(unit.get("hp", 0))
	var cap := int(unit.get("max_hp", 1))
	var next_max := maxi(cap, 1)
	var next_target := clampf(float(maxi(life, 0)) / float(next_max), 0.0, 1.0)
	var changed := life != _life or next_max != _life_max or not is_equal_approx(next_target, _target) or _shown < 0.0
	_life = life
	_life_max = next_max
	_target = next_target
	if _shown < 0.0:
		_shown = _target
	_arm_drain()
	if changed:
		queue_redraw()


func tick(delta: float) -> void:
	if _shown < 0.0 or is_equal_approx(_shown, _target):
		_shown = _target
		set_process(false)
		return
	var step := minf(absf(delta), DRAIN_STEP_CAP) / DRAIN_SEC
	if absf(_shown - _target) <= step:
		_shown = _target
		set_process(false)
	else:
		_shown += signf(_target - _shown) * step
	queue_redraw()


func _arm_drain() -> void:
	if _shown < 0.0 or is_equal_approx(_shown, _target):
		_shown = _target
		set_process(false)
	else:
		set_process(true)


func _process(delta: float) -> void:
	tick(delta)


func _draw() -> void:
	if host == null:
		return
	_paint_name()
	_paint_bar()


func _paint_name() -> void:
	var font := ThemeDB.fallback_font
	var label := host.unit_name
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, Pawn.NAME_FONT_SIZE)
	var label_x := -size.x * 0.5
	var name_y := host.name_baseline()
	var ascent := font.get_ascent(Pawn.NAME_FONT_SIZE)
	var descent := font.get_descent(Pawn.NAME_FONT_SIZE)
	var plate := Rect2(Vector2(label_x - 4.0, name_y - ascent - 1.0), Vector2(size.x + 8.0, ascent + descent + 2.0))
	draw_rect(plate, Color(0.07, 0.05, 0.06, 0.84))
	var team := team_color(host.seat)
	var underline := plate.position.y + plate.size.y
	draw_line(Vector2(plate.position.x, underline), Vector2(plate.position.x + plate.size.x, underline), Color(team.r, team.g, team.b, 0.95), 1.5, true)
	draw_string(font, Vector2(label_x, name_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Pawn.NAME_FONT_SIZE, Color(0.97, 0.95, 0.90))


func _paint_bar() -> void:
	var origin := Vector2(-BAR_W * 0.5, Pawn.HEAD_HP_Y)
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), Color(0.10, 0.08, 0.09, 0.92))
	var team := team_color(host.seat)
	var width := BAR_W * clampf(_shown, 0.0, 1.0)
	if width > 0.4:
		draw_rect(Rect2(origin, Vector2(width, BAR_H)), Color(team.r, team.g, team.b, 0.95))
	var font := ThemeDB.fallback_font
	var text := str(_life)
	draw_string(font, Vector2(origin.x + BAR_W + 3.0, origin.y + BAR_H - 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.97, 0.95, 0.90))
