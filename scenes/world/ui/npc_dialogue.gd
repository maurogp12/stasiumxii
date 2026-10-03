extends CanvasLayer

## Talk panel. Slides in after the hero arrives. Esc or a click outside closes
## it. Accept and Turn in are wired by the world. Coming soon stays disabled.

signal accept_requested(mission_id: String)
signal turn_in_requested(mission_id: String)

var _root: Control
var _card: PanelContainer
var _backdrop: ColorRect
var _title: Label
var _role: Label
var _body: RichTextLabel
var _soon: Button
var _accept: Button
var _turn_in: Button
var _open := false
var _slide: Tween
var _accept_id := ""
var _turn_in_id := ""
var npc_id := ""


func is_open() -> bool:
	return _open


func open_for(record: Dictionary, view: Dictionary = {}) -> void:
	ensure_built()
	npc_id = str(record.get("id", ""))
	_title.text = str(record.get("name", ""))
	_role.text = str(record.get("role", "")).capitalize()
	var mission_lines := str(view.get("lines", ""))
	if mission_lines == "":
		var lines: Array = record.get("lines", [])
		var text := ""
		for line in lines:
			if text != "":
				text += "\n"
			text += str(line)
		_body.text = text
	else:
		_body.text = mission_lines
	_accept_id = str(view.get("accept_id", ""))
	_turn_in_id = str(view.get("turn_in_id", ""))
	_accept.visible = _accept_id != ""
	_turn_in.visible = _turn_in_id != ""
	var soon := bool(view.get("soon", false)) or (_accept_id == "" and _turn_in_id == "")
	_soon.visible = soon
	_soon.disabled = true
	_open = true
	_root.visible = true
	_slide_in()


func press_accept() -> void:
	if _accept_id == "":
		return
	accept_requested.emit(_accept_id)


func press_turn_in() -> void:
	if _turn_in_id == "":
		return
	turn_in_requested.emit(_turn_in_id)


func close() -> void:
	_open = false
	if _slide != null and is_instance_valid(_slide):
		_slide.kill()
	if _root != null:
		_root.visible = false


func notify_outside_click() -> void:
	if _open:
		close()


func ensure_built() -> void:
	if _root != null:
		return
	layer = 30
	_root = Control.new()
	_root.name = "DialogueRoot"
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0, 0, 0, 0.0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop)
	_root.add_child(_backdrop)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_card.offset_left = -340
	_card.offset_right = 340
	_card.offset_top = -320
	_card.offset_bottom = -36
	_card.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
	box.add_child(_title)
	_role = Label.new()
	_role.name = "Role"
	_role.add_theme_font_size_override("font_size", 16)
	_role.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	box.add_child(_role)
	_body = RichTextLabel.new()
	_body.name = "Lines"
	_body.bbcode_enabled = false
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(640, 72)
	_body.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
	box.add_child(_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_accept = Button.new()
	_accept.name = "Accept"
	_accept.text = "Accept"
	_accept.visible = false
	_accept.focus_mode = Control.FOCUS_NONE
	_accept.pressed.connect(press_accept)
	row.add_child(_accept)
	_turn_in = Button.new()
	_turn_in.name = "TurnIn"
	_turn_in.text = "Turn in"
	_turn_in.visible = false
	_turn_in.focus_mode = Control.FOCUS_NONE
	_turn_in.pressed.connect(press_turn_in)
	row.add_child(_turn_in)
	_soon = Button.new()
	_soon.name = "ComingSoon"
	_soon.text = "Coming soon"
	_soon.disabled = true
	_soon.focus_mode = Control.FOCUS_NONE
	box.add_child(_soon)


func _slide_in() -> void:
	var rest := -320.0
	var height := 284.0
	_card.offset_top = 40.0
	_card.offset_bottom = 40.0 + height
	if _slide != null and is_instance_valid(_slide):
		_slide.kill()
	_slide = create_tween()
	_slide.set_trans(Tween.TRANS_CUBIC)
	_slide.set_ease(Tween.EASE_OUT)
	_slide.tween_property(_card, "offset_top", rest, 0.28)
	_slide.parallel().tween_property(_card, "offset_bottom", rest + height, 0.28)


func _on_backdrop(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		notify_outside_click()
		get_viewport().set_input_as_handled()


func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.12, 0.09, 0.94)
	box.border_color = Color(0.72, 0.58, 0.32)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box
