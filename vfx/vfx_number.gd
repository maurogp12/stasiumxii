extends "res://vfx/vfx_pooled.gd"

## Chunky outlined combat number. Pops, then floats. Does not lock input.

var _text: String = ""
var _top: Color = VfxPalette.DAMAGE_TOP
var _bottom: Color = VfxPalette.DAMAGE_BOTTOM
var _outline: Color = VfxPalette.NUMBER_OUTLINE
var _font_size: int = VfxBudget.NUMBER_SIZE
var _rise: Tween


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
	var pop := float(spec.get("scale", 1.0))
	rotation = deg_to_rad(randf_range(-VfxBudget.NUMBER_TILT_DEG, VfxBudget.NUMBER_TILT_DEG))
	scale = Vector2(0.6, 0.6) * pop
	modulate.a = 0.0
	z_as_relative = false
	z_index = 900
	var delay := float(spec.get("delay", 0.0))
	var risen: Vector2 = position + Vector2(0, -VfxBudget.NUMBER_RISE_PX)
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_callback(_show_pop)
	_tween.tween_property(self, "scale", Vector2(1.45, 1.45) * pop, VfxBudget.NUMBER_POP_SEC * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if pop >= 1.25:
		_tween.tween_property(self, "scale", Vector2(0.86, 0.86) * pop, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * pop, VfxBudget.NUMBER_POP_SEC * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var baseline := Vector2(-width * 0.5, _font_size * 0.35)
	font.draw_string(get_canvas_item(), baseline + Vector2(2, 3), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, VfxPalette.NUMBER_SHADOW)
	for ox in range(-4, 5, 2):
		for oy in range(-4, 5, 2):
			if ox == 0 and oy == 0:
				continue
			font.draw_string(get_canvas_item(), baseline + Vector2(ox, oy), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _outline)
	font.draw_string(get_canvas_item(), baseline + Vector2(0, -3), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _top)
	font.draw_string(get_canvas_item(), baseline, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _bottom)
