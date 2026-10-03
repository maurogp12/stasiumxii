extends Node2D
class_name OverheadPlate

## Name and life bar over a fighter. View only. The numbers come from the
## CombatSim snapshot the pawn already applied. This node shows them; it
## never decides them. The team fill is the snapshot. A lighter ghost eases
## down from the previous amount after damage.

const TEAM_P1 := Color(74.0 / 255.0, 143.0 / 255.0, 224.0 / 255.0)
const TEAM_P2 := Color(224.0 / 255.0, 90.0 / 255.0, 74.0 / 255.0)
## Track height at 1x. The 1 px rim sits outside this.
const BAR_H := 6.0
const BAR_RIM := 1.0
const NUM_SIZE := 7
const NAME_PAD := 3.0
const BAR_GAP := 2.0
const WIDTH_SCALE := 1.2
const LOW_LIFE := 0.30
## Full warning colour at this ratio and below. The tint eases in from LOW_LIFE.
const AMBER_LIFE := 0.20
## A slow brightness pulse while life is under this ratio.
const PULSE_LIFE := 0.15
const WARN_AMBER := Color(0.96, 0.62, 0.22)
const DRAIN_SEC := 0.85
## A hitch must not skip the drain or the nudge. One frame is at most a 30fps step.
const DRAIN_STEP_CAP := 1.0 / 30.0
const LIFT_PX_PER_SEC := 90.0
const LIFT_STEP_CAP := 4.0
## Flattened pointy hex under the feet. Stays inside one 64×32 cell.
const HEX_RX := 18.0
const HEX_RY := 8.0
const HEX_FILL_ALPHA := 0.70
const PLATE_Z := 2000

static var _live: Array[OverheadPlate] = []
static var _laid_out: int = -1

var host: Pawn
var _shown: float = -1.0
var _target: float = 1.0
var _life: int = 0
var _life_max: int = 1
var _lift: float = 0.0
var _lift_goal: float = 0.0
var _pulse: float = 0.0


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


## Positive lift moves the back plate up. `order_y` is screen Y; the larger Y is in front.
static func lifts_for(rests: Array[Rect2], order_y: Array[float]) -> PackedFloat32Array:
	var count := rests.size()
	var lifts := PackedFloat32Array()
	lifts.resize(count)
	for _pass in count:
		for i in count:
			for j in count:
				if i == j or order_y[i] >= order_y[j]:
					continue
				var behind := rests[i]
				behind.position.y -= lifts[i]
				var front := rests[j]
				front.position.y -= lifts[j]
				if not behind.intersects(front):
					continue
				var overlap := behind.position.y + behind.size.y - front.position.y
				if overlap > 0.0:
					lifts[i] += overlap + 1.0
	return lifts


static func layout_now(only: Array[OverheadPlate]) -> void:
	_layout(0.0, true, only)


func shown_ratio() -> float:
	return _shown


func target_ratio() -> float:
	return _target


func snapshot_life() -> int:
	return _life


func lift() -> float:
	return _lift


func sprite_width() -> float:
	if host == null:
		return 72.0
	var sprite := host.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null:
		return 72.0
	return float(sprite.texture.get_width()) * absf(sprite.scale.x)


func plate_width() -> float:
	if host == null:
		return 48.0
	var font := ThemeDB.fallback_font
	var name_w := font.get_string_size(host.unit_name, HORIZONTAL_ALIGNMENT_CENTER, -1, Pawn.NAME_FONT_SIZE).x
	var num_w := _number_width()
	var cap := sprite_width() * WIDTH_SCALE
	var wanted := maxf(name_w + NAME_PAD * 2.0, NAME_PAD + 28.0 + BAR_GAP + num_w + NAME_PAD)
	return minf(wanted, cap)


func local_rect() -> Rect2:
	var font := ThemeDB.fallback_font
	var ascent := font.get_ascent(Pawn.NAME_FONT_SIZE)
	var baseline := host.name_baseline() if host != null else Pawn.HEAD_HP_Y - 2.0
	var top := baseline - ascent - NAME_PAD
	var bar_h := BAR_H + BAR_RIM * 2.0
	var bottom := Pawn.HEAD_HP_Y + bar_h + NAME_PAD
	var w := plate_width()
	return Rect2(-w * 0.5, top, w, bottom - top)


func bar_rect() -> Rect2:
	var plate := local_rect()
	var num := number_rect()
	var x := plate.position.x + NAME_PAD
	var w := num.position.x - BAR_GAP - x
	return Rect2(x, Pawn.HEAD_HP_Y, maxf(w, 4.0), BAR_H + BAR_RIM * 2.0)


func number_rect() -> Rect2:
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(str(_life), HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_SIZE)
	var plate := local_rect()
	var glyph_w := size.x
	var glyph_h := font.get_ascent(NUM_SIZE) + font.get_descent(NUM_SIZE)
	var x := plate.position.x + plate.size.x - NAME_PAD - glyph_w - 1.0
	var bar_mid := Pawn.HEAD_HP_Y + BAR_RIM + BAR_H * 0.5
	var y := bar_mid - glyph_h * 0.5
	return Rect2(x - 1.0, y - 1.0, glyph_w + 2.0, glyph_h + 2.0)


func fill_color() -> Color:
	var ink := _life_ink()
	if _target >= PULSE_LIFE:
		return ink
	var wave := 0.5 + 0.5 * sin(_pulse * TAU)
	return ink.darkened(0.12).lerp(ink.lightened(0.28), wave)


func _life_ink() -> Color:
	var team := team_color(host.seat if host != null else 0)
	if _target >= LOW_LIFE:
		return team
	if _target <= AMBER_LIFE:
		return WARN_AMBER
	var span := LOW_LIFE - AMBER_LIFE
	var mix := clampf((LOW_LIFE - _target) / span, 0.0, 1.0)
	return team.lerp(WARN_AMBER, mix)


func rest_world_rect() -> Rect2:
	var local := local_rect()
	var rest := global_position - position
	return Rect2(rest + local.position, local.size)


func world_rect() -> Rect2:
	var local := local_rect()
	return Rect2(global_position + local.position, local.size)


func sync_from_unit(unit: Dictionary) -> void:
	var life := int(unit.get("hp", 0))
	var cap := int(unit.get("max_hp", 1))
	var next_max := maxi(cap, 1)
	var next_target := clampf(float(maxi(life, 0)) / float(next_max), 0.0, 1.0)
	var changed := life != _life or next_max != _life_max or not is_equal_approx(next_target, _target) or _shown < 0.0
	_life = life
	_life_max = next_max
	if _shown < 0.0 or next_target > _shown:
		_shown = next_target
	_target = next_target
	if changed:
		queue_redraw()


func tick(delta: float) -> void:
	var step_delta := minf(absf(delta), DRAIN_STEP_CAP)
	var redraw := false
	if _shown < 0.0 or is_equal_approx(_shown, _target):
		_shown = _target
	else:
		var step := step_delta / DRAIN_SEC
		if absf(_shown - _target) <= step:
			_shown = _target
		else:
			_shown += signf(_target - _shown) * step
		redraw = true
	if _target < PULSE_LIFE:
		_pulse = fmod(_pulse + step_delta, 1.0)
		redraw = true
	elif _pulse != 0.0:
		_pulse = 0.0
		redraw = true
	if redraw:
		queue_redraw()


func ease_lift(delta: float) -> void:
	var step := minf(LIFT_STEP_CAP, maxf(delta, 0.0) * LIFT_PX_PER_SEC)
	if absf(_lift - _lift_goal) <= step:
		_lift = _lift_goal
	else:
		_lift += signf(_lift_goal - _lift) * step
	position = Vector2(0.0, -_lift)


func _enter_tree() -> void:
	if not _live.has(self):
		_live.append(self)


func _exit_tree() -> void:
	_live.erase(self)


func _process(delta: float) -> void:
	tick(delta)
	var everyone: Array[OverheadPlate] = []
	_layout(delta, false, everyone)


static func _layout(delta: float, immediate: bool, only: Array[OverheadPlate]) -> void:
	var frame := Engine.get_process_frames()
	if not immediate and frame == _laid_out:
		return
	if not immediate:
		_laid_out = frame
	var plates: Array[OverheadPlate] = []
	if only.is_empty():
		for plate in _live:
			if plate != null and is_instance_valid(plate) and plate.visible and plate.host != null:
				plates.append(plate)
	else:
		for plate in only:
			if plate != null and is_instance_valid(plate) and plate.host != null:
				plates.append(plate)
	var rests: Array[Rect2] = []
	var order_y: Array[float] = []
	for plate in plates:
		rests.append(plate.rest_world_rect())
		order_y.append(plate.host.global_position.y)
	var goals := lifts_for(rests, order_y)
	for i in plates.size():
		var plate := plates[i]
		plate._lift_goal = goals[i]
		if immediate:
			plate._lift = plate._lift_goal
			plate.position = Vector2(0.0, -plate._lift)
		else:
			plate.ease_lift(delta)
		plate.z_as_relative = false
		plate.z_index = PLATE_Z + int(round(plate.host.global_position.y))


func _draw() -> void:
	if host == null:
		return
	var plate := local_rect()
	draw_rect(plate, Color(0.07, 0.05, 0.06, 0.90))
	var team := team_color(host.seat)
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1.0)), Color(team.r, team.g, team.b, 0.95))
	_paint_name(plate)
	_paint_bar()
	_paint_number()


func _paint_name(plate: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var label := host.unit_name
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, Pawn.NAME_FONT_SIZE)
	var baseline := host.name_baseline()
	draw_string(font, Vector2(-size.x * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Pawn.NAME_FONT_SIZE, Color(0.97, 0.95, 0.90))


func _paint_bar() -> void:
	var bar := bar_rect()
	draw_rect(bar, Color(0.04, 0.03, 0.04, 0.98))
	var inner := Rect2(bar.position + Vector2(BAR_RIM, BAR_RIM), Vector2(bar.size.x - BAR_RIM * 2.0, BAR_H))
	draw_rect(inner, Color(0.10, 0.08, 0.09, 0.95))
	var ghost_w := inner.size.x * clampf(_shown, 0.0, 1.0)
	var fill_w := inner.size.x * clampf(_target, 0.0, 1.0)
	if ghost_w > fill_w + 0.4:
		var ghost := team_color(host.seat)
		draw_rect(Rect2(inner.position, Vector2(ghost_w, inner.size.y)), Color(minf(ghost.r + 0.38, 1.0), minf(ghost.g + 0.38, 1.0), minf(ghost.b + 0.38, 1.0), 0.55))
	if fill_w > 0.4:
		var ink := fill_color()
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), Color(ink.r, ink.g, ink.b, 0.98))


func _paint_number() -> void:
	var font := ThemeDB.fallback_font
	var text := str(_life)
	var box := number_rect()
	var baseline := box.position.y + 1.0 + font.get_ascent(NUM_SIZE)
	var origin := Vector2(box.position.x + 1.0, baseline)
	var shade := Color(0.05, 0.04, 0.05, 0.95)
	for step in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, origin + step, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_SIZE, shade)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_SIZE, Color(0.98, 0.96, 0.92))


func _number_width() -> float:
	var font := ThemeDB.fallback_font
	return font.get_string_size(str(_life), HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_SIZE).x + 2.0
