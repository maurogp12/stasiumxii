extends VBoxContainer
class_name CosmeticTray

## Shared hot-seat tray (PC class select and the mobile Koliseo door).
## Button.pressed is the mouse and touch path. Labels are "Locked default" / "Alt".

signal gender_picked(gender_id: String)
signal palette_picked(palette_id: String)
signal lock_pressed

var _class_id: String = ""
var _gender: String = SeatCosmetics.GENDER_DEFAULT
var _palette: String = SeatCosmetics.PALETTE_LOCKED
var _gender_buttons: Dictionary = {}
var _palette_buttons: Dictionary = {}
var _palette_row: HBoxContainer
var _built_for: String = ""


func _ready() -> void:
	visible = false
	add_theme_constant_override("separation", 6)
	var gender_row := HBoxContainer.new()
	gender_row.add_theme_constant_override("separation", 8)
	add_child(gender_row)
	for gender_id in SeatCosmetics.GENDERS:
		var button := _make_button(SeatCosmetics.gender_label(gender_id), Vector2(176, 44))
		button.pressed.connect(_on_gender.bind(gender_id))
		_gender_buttons[gender_id] = button
		gender_row.add_child(button)
	_palette_row = HBoxContainer.new()
	_palette_row.add_theme_constant_override("separation", 8)
	add_child(_palette_row)
	var lock := _make_button("Lock in", Vector2(176, 48))
	lock.pressed.connect(func() -> void: lock_pressed.emit())
	add_child(lock)


func present(class_id: String, gender_id: String, palette_id: String) -> void:
	if not SeatCosmetics.enabled() or not SeatCosmetics.supports(class_id):
		visible = false
		return
	_class_id = SpellKits.normalize_class_id(class_id)
	_gender = SeatCosmetics.normalize_gender(gender_id)
	var palettes := SeatCosmetics.palettes_for(_class_id)
	_palette = palette_id if palettes.has(palette_id) else SeatCosmetics.PALETTE_LOCKED
	visible = true
	_style_genders()
	if _built_for != _class_id:
		_rebuild_palettes()
	_style_palettes()


func dismiss() -> void:
	visible = false


func gender_button(gender_id: String) -> Button:
	return _gender_buttons.get(gender_id) as Button


func palette_button(palette_id: String) -> Button:
	return _palette_buttons.get(palette_id) as Button


func _on_gender(gender_id: String) -> void:
	gender_picked.emit(gender_id)


func _make_button(text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	return button


func _style_genders() -> void:
	for gender_id in _gender_buttons.keys():
		var button: Button = _gender_buttons[gender_id]
		var selected := str(gender_id) == _gender
		button.add_theme_stylebox_override("normal", _chip_style(Color(0.18, 0.16, 0.14), Color(0.93, 0.78, 0.42) if selected else Color(0.38, 0.34, 0.3), selected))
		button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
		button.add_theme_color_override("font_hover_color", Color(0.98, 0.96, 0.92))


func _rebuild_palettes() -> void:
	if _palette_row == null:
		return
	for child in _palette_row.get_children():
		_palette_row.remove_child(child)
		child.free()
	_palette_buttons.clear()
	for palette_id in SeatCosmetics.palettes_for(_class_id):
		var button := _make_button(SeatCosmetics.palette_label(palette_id), Vector2(120, 44))
		button.pressed.connect(_on_palette.bind(palette_id))
		_palette_buttons[palette_id] = button
		_palette_row.add_child(button)
	_built_for = _class_id


func _on_palette(palette_id: String) -> void:
	palette_picked.emit(palette_id)


func _style_palettes() -> void:
	for palette_id in _palette_buttons.keys():
		var button: Button = _palette_buttons[palette_id]
		var colors := SeatCosmetics.swatch_colors(_class_id, str(palette_id))
		var bg: Color = colors[0] if colors.size() > 0 else Color(0.2, 0.2, 0.2)
		var edge: Color = colors[1] if colors.size() > 1 else bg.lightened(0.35)
		var selected := str(palette_id) == _palette
		button.add_theme_stylebox_override("normal", _chip_style(bg, Color(0.93, 0.78, 0.42) if selected else edge, selected))
		button.add_theme_stylebox_override("hover", _chip_style(bg.lightened(0.08), Color(0.93, 0.78, 0.42) if selected else edge, selected))
		button.add_theme_stylebox_override("pressed", _chip_style(bg, Color(0.93, 0.78, 0.42), true))
		button.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
		button.add_theme_color_override("font_hover_color", Color(0.97, 0.95, 0.9))
		button.add_theme_color_override("font_pressed_color", Color(0.97, 0.95, 0.9))


func _chip_style(bg: Color, edge: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(4 if selected else 2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
