extends "res://vfx/vfx_pooled.gd"

## Calm combat number. Rises and fades. Does not lock input.
const _FONT := preload("res://art/ui/hub/Cinzel-Semibold.ttf")

var _text: String = ""
var _top: Color = VfxPalette.DAMAGE_TOP
var _bottom: Color = VfxPalette.DAMAGE_BOTTOM
var _outline: Color = VfxPalette.NUMBER_OUTLINE
var _font_size: int = VfxBudget.NUMBER_SIZE
var _kind: String = ""
var _rise: Tween
## Extra height (px, local) when this number made room for another one.
var lift: float = 0.0
var _pop: float = 1.0


func play(spec: Dictionary) -> void:
	_kill_rise()
	_begin()
	_text = str(spec.get("text", ""))
	var colors: Dictionary = VfxPalette.number_colors(str(spec.get("kind", "damage")))
	_top = colors["top"]
	_bottom = colors["bottom"]
	if spec.has("tint") and spec["tint"] is Color:
		_top = spec["tint"]
		_bottom = _top.darkened(0.28)
	_outline = VfxPalette.NUMBER_OUTLINE
	if spec.has("outline") and spec["outline"] is Color:
		_outline = spec["outline"]
	_font_size = int(colors["size"])
	_kind = str(spec.get("kind", ""))
	var pop := float(spec.get("scale", 1.0))
	_pop = pop
	lift = 0.0
	rotation = 0.0
	scale = Vector2.ONE * pop
	modulate.a = 0.0
	z_as_relative = false
	z_index = 900
	var delay := float(spec.get("delay", 0.0))
	var drift := Vector2(0, -VfxBudget.NUMBER_RISE_PX)
	if _kind == "miss":
		drift = Vector2(14.0, -12.0)
	var risen: Vector2 = position + drift
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_callback(_show_pop)
	_rise = create_tween()
	if delay > 0.0:
		_rise.tween_interval(delay)
	_rise.tween_property(self, "position", risen, VfxBudget.NUMBER_RISE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_rise.tween_property(self, "modulate:a", 0.0, VfxBudget.NUMBER_FADE_SEC)
	_rise.finished.connect(release, CONNECT_ONE_SHOT)
	queue_redraw()


func _kill_rise() -> void:
	if _rise != null and is_instance_valid(_rise):
		_rise.kill()
	_rise = null


func release() -> void:
	_kill_rise()
	super.release()


func _show_pop() -> void:
	modulate.a = 1.0
	visible = true
	queue_redraw()


func _draw() -> void:
	if _text == "":
		return
	var font := _FONT if _FONT != null else ThemeDB.fallback_font
	if font == null:
		return
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var baseline := Vector2(-width * 0.5, _font_size * 0.35 - lift)
	font.draw_string(get_canvas_item(), baseline + Vector2(1, 2), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, VfxPalette.NUMBER_SHADOW)
	for ox in [-2, 0, 2]:
		for oy in [-2, 0, 2]:
			if ox == 0 and oy == 0:
				continue
			font.draw_string(get_canvas_item(), baseline + Vector2(ox, oy), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _outline)
	font.draw_string(get_canvas_item(), baseline + Vector2(0, -2), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _top)
	font.draw_string(get_canvas_item(), baseline, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _bottom)
	if _kind == "miss":
		var slash_y := baseline.y - float(_font_size) * 0.28
		draw_line(Vector2(baseline.x - 4.0, slash_y + 2.0), Vector2(baseline.x + width + 4.0, slash_y - float(_font_size) * 0.55), Color(0.28, 0.16, 0.1, 0.95), 3.0, true)


## Resource and MP ticks give way to damage and heal numbers.
func is_minor() -> bool:
	return _kind in ["resource", "mp"]


## Where the number sits on screen (parent space). The rise is a single
## ease-out, so a status line sits clear of that path.
func footprint() -> Rect2:
	var font: Font = _FONT if _FONT != null else ThemeDB.fallback_font
	var width := 40.0
	if font != null and _text != "":
		width = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var s := maxf(_pop, 0.5)
	var h := float(_font_size) * 1.05 * s
	var bounce := 0.0
	var top := position.y - (lift + float(_font_size) * 0.8) * s - bounce
	return Rect2(Vector2(position.x - width * 0.5 * s - 4.0, top), Vector2(width * s + 8.0, h + bounce))


## Lift until this number's box sits above `other` (plus a small gap).
func clear_above(other: Rect2) -> void:
	var mine := footprint()
	if not mine.intersects(other):
		return
	var s := maxf(_pop, 0.5)
	lift += (mine.end.y - other.position.y + 5.0) / s
	queue_redraw()
