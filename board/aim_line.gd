extends Node2D

## Aim chrome only. A dashed curve from the spell origin to the hovered cell,
## plus the predicted connect float. Ambush's origin is the Shade (Gloam while
## Invisible). This node does not move pawns and does not submit intents.

const AIM_RED := Color(0.92, 0.16, 0.2, 0.96)
const AIM_HEAL := Color(0.45, 0.92, 0.62, 0.96)
const AIM_SHIELD := Color(0.72, 0.84, 0.96, 0.96)
const DASH_POINTS := 2
const GAP_POINTS := 2

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _show := false
var _kind := ""
var _label: Label


func _ready() -> void:
	z_as_relative = false
	z_index = 860
	_label = Label.new()
	_label.name = "AimFloat"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(104, 40)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.04))
	_label.add_theme_constant_override("outline_size", 8)
	_label.visible = false
	add_child(_label)


func show_world(from: Vector2, to: Vector2, text: String, kind: String) -> void:
	_from = from
	_to = to
	_kind = kind
	_show = from.distance_to(to) > 6.0
	_ensure_label()
	_label.text = text
	_label.visible = text != ""
	_label.modulate = _kind_color(kind)
	_label.position = to + Vector2(-52, -112)
	queue_redraw()


func clear_aim() -> void:
	_show = false
	_kind = ""
	if _label != null and is_instance_valid(_label):
		_label.text = ""
		_label.visible = false
	queue_redraw()


func _ensure_label() -> void:
	if _label != null and is_instance_valid(_label):
		return
	_label = Label.new()
	_label.name = "AimFloat"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(104, 40)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.04))
	_label.add_theme_constant_override("outline_size", 8)
	_label.visible = false
	add_child(_label)


static func curve_points(from: Vector2, to: Vector2, steps: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var delta := to - from
	var length := delta.length()
	if length < 2.0:
		pts.append(from)
		pts.append(to)
		return pts
	var normal := Vector2(-delta.y, delta.x).normalized()
	# Screen-up so the curve reads above the tiles, the way the reference arc does.
	if normal.y > 0.0:
		normal = -normal
	var lift := clampf(length * 0.22, 14.0, 56.0)
	var control := (from + to) * 0.5 + normal * lift
	var count := maxi(steps, 4)
	for i in count + 1:
		var t := float(i) / float(count)
		var u := 1.0 - t
		pts.append(u * u * from + 2.0 * u * t * control + t * t * to)
	return pts


## Distance from the curve's midpoint to the straight segment. Tests use this
## to prove the aim line is an arc, not a body-path dash.
static func arc_offset(from: Vector2, to: Vector2) -> float:
	var pts := curve_points(from, to)
	if pts.size() < 3:
		return 0.0
	var mid: Vector2 = pts[pts.size() / 2]
	return mid.distance_to((from + to) * 0.5)


func _kind_color(kind: String) -> Color:
	if kind == "heal":
		return AIM_HEAL
	if kind == "shield":
		return AIM_SHIELD
	return AIM_RED


func _draw() -> void:
	if not _show:
		return
	var pts := curve_points(_from, _to)
	if pts.size() < 2:
		return
	var color := _kind_color(_kind)
	var i := 0
	while i < pts.size() - 1:
		var j := mini(i + DASH_POINTS, pts.size() - 1)
		draw_line(pts[i], pts[j], color, 3.4, true)
		i += DASH_POINTS + GAP_POINTS
