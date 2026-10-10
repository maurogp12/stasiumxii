class_name VisualSettingsPanel
extends CanvasLayer

## Shared visual-settings sheet. The hub and the world scene both instance it.
## It is not a door: nothing here starts a fight.

var settings: VisualSettings
var _rows: Dictionary = {}
var _preset_label: Label
var _dim: ColorRect
var _card: PanelContainer
## The "Performance mode" switch (PC world only).
var performance_check: CheckButton
## One-time offer on a slow machine: "Turn on" / "No thanks".
var offer_card: PanelContainer
var offer_label: Label
var offer_yes: Button
var offer_no: Button

const PERFORMANCE_TEXT := "Performance mode"
const PERFORMANCE_NOTE := "For slower PCs: trees, animals and weather hold still and the world uses less memory."


func setup(target: VisualSettings, show_performance: bool = false) -> void:
	settings = target
	layer = 30
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim)
	add_child(_dim)
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	var tall := 560 if show_performance else 460
	_card.custom_minimum_size = Vector2(440, tall)
	_card.position = Vector2(-220, -tall / 2)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.13, 0.1, 0.96)
	style.border_color = Color(0.93, 0.78, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_card.add_child(col)
	var title := Label.new()
	title.text = "Visual Settings"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.94, 0.82))
	col.add_child(title)
	if show_performance:
		_add_performance(col)
	_preset_label = Label.new()
	_preset_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.62))
	col.add_child(_preset_label)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	col.add_child(presets)
	for name in ["Full", "Reduced", "Minimal"]:
		var button := Button.new()
		button.text = name
		button.pressed.connect(func(): settings.apply_preset(name))
		presets.add_child(button)
	_add_row(col, "animations", "Ambient motion, birds, leaves, smoke")
	_add_row(col, "weather", "Weather, rain, and fog")
	_add_row(col, "post_fx", "Bloom, warmth, and vignette")
	_add_row(col, "sway_shadows", "Contact shadows and clouds")
	_add_row(col, "decor", "Decor and clutter")
	var note := Label.new()
	note.text = "Characters, ground, blockers, and exits stay on.\nEsc closes this sheet."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	col.add_child(note)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide_panel)
	col.add_child(close)
	if not settings.flag_changed.is_connected(_on_flag):
		settings.flag_changed.connect(_on_flag)
	if not settings.preset_changed.is_connected(_on_preset):
		settings.preset_changed.connect(_on_preset)
	if show_performance:
		_build_offer(style)
	_refresh()
	hide()


## The one switch most players need: on = world animations off and low memory.
func _add_performance(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	performance_check = CheckButton.new()
	performance_check.text = PERFORMANCE_TEXT
	performance_check.add_theme_font_size_override("font_size", 20)
	performance_check.toggled.connect(func(on): settings.set_performance(on))
	box.add_child(performance_check)
	var note := Label.new()
	note.text = PERFORMANCE_NOTE
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(400, 0)
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
	box.add_child(note)
	parent.add_child(box)
	parent.add_child(HSeparator.new())


func _build_offer(card_style: StyleBoxFlat) -> void:
	offer_card = PanelContainer.new()
	offer_card.name = "PerformanceOffer"
	offer_card.set_anchors_preset(Control.PRESET_CENTER)
	offer_card.custom_minimum_size = Vector2(420, 0)
	offer_card.position = Vector2(-210, -90)
	offer_card.add_theme_stylebox_override("panel", card_style)
	add_child(offer_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	offer_card.add_child(col)
	var title := Label.new()
	title.text = "Turn on Performance mode?"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.94, 0.82))
	col.add_child(title)
	offer_label = Label.new()
	offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offer_label.custom_minimum_size = Vector2(380, 0)
	offer_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
	col.add_child(offer_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	offer_yes = Button.new()
	offer_yes.text = "Turn on"
	offer_yes.pressed.connect(func():
		settings.set_performance(true)
		hide_panel())
	row.add_child(offer_yes)
	offer_no = Button.new()
	offer_no.text = "No thanks"
	offer_no.pressed.connect(hide_panel)
	row.add_child(offer_no)
	offer_card.hide()


## Show the one-time offer alone (the settings card stays shut).
func show_offer(reasons: Array = []) -> void:
	if offer_card == null:
		return
	var why := "This PC"
	if not reasons.is_empty():
		why = "This PC has %s" % ", ".join(PackedStringArray(reasons.map(func(r): return str(r))))
	offer_label.text = "%s, so the world may run slowly. %s\nYou can change this any time under Esc > Visual Settings." % [why, PERFORMANCE_NOTE]
	_card.hide()
	offer_card.show()
	show()


func offer_visible() -> bool:
	return visible and offer_card != null and offer_card.visible


func _on_flag(_flag: String, _on: bool) -> void:
	_refresh()


func _on_preset(_preset_name: String) -> void:
	_refresh()


func show_panel() -> void:
	_refresh()
	_card.show()
	if offer_card != null:
		offer_card.hide()
	show()


func hide_panel() -> void:
	hide()
	_card.show()
	if offer_card != null:
		offer_card.hide()


func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func _add_row(parent: Node, flag: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	var check := CheckButton.new()
	check.text = label_text
	check.toggled.connect(func(on): settings.set_flag(flag, on))
	row.add_child(check)
	parent.add_child(row)
	_rows[flag] = check


func _refresh() -> void:
	if settings == null:
		return
	_preset_label.text = "Preset: %s" % settings.preset
	if performance_check != null:
		performance_check.set_pressed_no_signal(settings.performance)
	for flag in _rows.keys():
		var check: CheckButton = _rows[flag]
		check.set_pressed_no_signal(settings.enabled(flag))


func _on_dim(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
