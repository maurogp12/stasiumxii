class_name VisualSettingsPanel
extends CanvasLayer

## Shared visual-settings sheet. The hub and the world scene both instance it.
## It is not a door: nothing here starts a fight.

var settings: VisualSettings
var _rows: Dictionary = {}
var _preset_label: Label
var _dim: ColorRect
var _card: PanelContainer


func setup(target: VisualSettings) -> void:
	settings = target
	layer = 30
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim)
	add_child(_dim)
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.custom_minimum_size = Vector2(420, 460)
	_card.position = Vector2(-210, -230)
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
	_add_row(col, "animations", "Ambient and decor animation")
	_add_row(col, "weather", "Weather")
	_add_row(col, "post_fx", "Post-processing")
	_add_row(col, "sway_shadows", "Swaying shadows")
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
	_refresh()
	hide()


func _on_flag(_flag: String, _on: bool) -> void:
	_refresh()


func _on_preset(_preset_name: String) -> void:
	_refresh()


func show_panel() -> void:
	_refresh()
	show()


func hide_panel() -> void:
	hide()


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
	for flag in _rows.keys():
		var check: CheckButton = _rows[flag]
		check.set_pressed_no_signal(settings.enabled(flag))


func _on_dim(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
