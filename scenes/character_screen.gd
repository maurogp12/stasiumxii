extends Control
class_name CharacterScreen

## Levels and spend points per class (Mauro 29 Sep 2026, Soft Lock).
## Pick a class on the left; the right shows its level, XP to next, free
## points and the four buckets (Mastery / Vitality / Swift / Ward), plus
## what the level gives in a fight (inherent growth + points).

signal closed

const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const GREEN := Color(0.66, 0.84, 0.25)
const ROW_HEIGHT := 48

var font: Font
var selected: String = "kestrel"
var _hero: HeroProgress
var _class_box: VBoxContainer
var _detail: VBoxContainer
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hero = HeroProgress.load_saved()
	_build()
	_refresh()


func hero() -> HeroProgress:
	return _hero


func pick(class_id: String) -> void:
	if HeroProgress.GROWTH.has(class_id):
		selected = class_id
		if _status != null:
			_status.text = ""
			_refresh()


func spend(bucket: String) -> Dictionary:
	var result := _hero.spend(selected, bucket)
	if bool(result.get("ok", false)):
		_hero.save()
		_status.text = "%s: %s." % [SpellKits.display_name(selected), HeroProgress.BUCKET_LABEL[bucket]]
	else:
		_status.text = "No free points." if str(result.get("reason", "")) == "no_points" else "Cannot spend."
	_refresh()
	return result


func reset_points() -> Dictionary:
	var result := _hero.reset_points(selected)
	if bool(result.get("ok", false)):
		_hero.save()
		_status.text = "%s: %d points back to spend." % [SpellKits.display_name(selected), int(result["refunded"])]
	else:
		_status.text = "No points spent yet."
	_refresh()
	return result


func close() -> void:
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.74))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 30
	panel.offset_right = -40
	panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.09, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var top := HBoxContainer.new()
	var title := _label("Levels", 20, GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_button := _button("Close")
	close_button.name = "CloseLevels"
	close_button.pressed.connect(close)
	top.add_child(close_button)
	body.add_child(top)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	_class_box = VBoxContainer.new()
	_class_box.add_theme_constant_override("separation", 6)
	_class_box.custom_minimum_size = Vector2(230, 0)
	cols.add_child(_class_box)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(_detail)
	_status = _label("", 14, GOLD)
	_status.name = "LevelsStatus"
	body.add_child(_status)


func _refresh() -> void:
	for box in [_class_box, _detail]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for class_id in SpellKits.LOCKED_ROSTER:
		var b := _button("%s  Lv %d" % [SpellKits.display_name(class_id), _hero.level_of(class_id)])
		b.name = "Class_" + class_id
		if class_id == selected:
			b.add_theme_color_override("font_color", Color.WHITE)
			var lit := StyleBoxFlat.new()
			lit.bg_color = Color(0.30, 0.24, 0.10)
			lit.border_color = GOLD_BRIGHT
			lit.set_border_width_all(2)
			b.add_theme_stylebox_override("normal", lit)
		b.pressed.connect(pick.bind(class_id))
		_class_box.add_child(b)
	var level := _hero.level_of(selected)
	var need := HeroProgress.xp_to_next(level)
	var head := _label("%s — Level %d / %d" % [SpellKits.display_name(selected), level, HeroProgress.MAX_LEVEL], 18, GOLD_BRIGHT)
	head.name = "LevelLine"
	_detail.add_child(head)
	var bar := ProgressBar.new()
	bar.name = "XpBar"
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.max_value = maxi(need, 1)
	bar.value = _hero.xp_of(selected) if need > 0 else bar.max_value
	var fill := StyleBoxFlat.new()
	fill.bg_color = GREEN
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.10, 0.14)
	bar.add_theme_stylebox_override("background", bg)
	_detail.add_child(bar)
	var xp_text := "XP %d / %d to level %d" % [_hero.xp_of(selected), need, level + 1] if need > 0 else "Max level"
	_detail.add_child(_label(xp_text, 14, GOLD))
	var free := _hero.points_free(selected)
	var points := _label("Free points: %d" % free, 16, GREEN if free > 0 else GOLD_DIM)
	points.name = "FreePoints"
	_detail.add_child(points)
	var spent: Dictionary = _hero.record(selected)["spent"]
	for bucket in HeroProgress.BUCKETS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var b := _button("+ %s" % HeroProgress.BUCKET_LABEL[bucket])
		b.name = "Spend_" + bucket
		b.custom_minimum_size = Vector2(250, ROW_HEIGHT)
		b.disabled = free <= 0
		b.pressed.connect(spend.bind(bucket))
		row.add_child(b)
		var count := _label("× %d" % int(spent.get(bucket, 0)), 15, GOLD_BRIGHT)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(count)
		_detail.add_child(row)
	var used := 0
	for bucket in spent:
		used += int(spent[bucket])
	var reset := _button("Reset points")
	reset.name = "ResetPoints"
	reset.custom_minimum_size = Vector2(250, ROW_HEIGHT)
	reset.disabled = used <= 0
	reset.pressed.connect(reset_points)
	_detail.add_child(reset)
	var st := HeroProgress.combat_stats(_hero.fight_hero(selected), selected)
	var line := "In a fight this level adds: Mastery +%d · HP +%d · Init +%d · Ward +%d" % [int(st["mastery"]), int(st["hp"]), int(st["init"]), int(st["ward"])]
	if int(st["ap"]) > 0:
		line += " · +1 AP"
	var sum := _label(line, 14, GOLD_BRIGHT)
	sum.name = "LevelStats"
	sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(sum)
	_detail.add_child(_label("Ward only guards the element of an active 2-piece attune. +1 AP at level 20. XP: Stasis clear 60 per star (20 with no chest), online Koliseo win 50 / loss 15.", 12, GOLD_DIM))


func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(96, ROW_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", GOLD_DIM)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.06, 0.12, 0.95)
		style.border_color = GOLD_BRIGHT if style_name in ["hover", "focus"] else (GOLD_DIM if style_name == "disabled" else GOLD)
		style.set_border_width_all(1)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(style_name, style)
	return button
