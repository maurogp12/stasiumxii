extends CanvasLayer

## Every mission by zone. Key J toggles it. Preload. No global class.

var missions = null
var progress = null
var _root: Control
var _body: RichTextLabel
var _open := false


func setup(book, hero) -> void:
	missions = book
	progress = hero


func is_open() -> bool:
	return _open


func open() -> void:
	ensure_built()
	_fill()
	_open = true
	_root.visible = true


func close() -> void:
	_open = false
	if _root != null:
		_root.visible = false


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func ensure_built() -> void:
	if _root != null:
		return
	layer = 22
	_root = Control.new()
	_root.name = "MissionLog"
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var card := PanelContainer.new()
	card.name = "Card"
	card.offset_left = 180
	card.offset_top = 48
	card.offset_right = 780
	card.offset_bottom = 680
	card.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var title := Label.new()
	title.text = "Missions"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
	box.add_child(title)
	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = false
	_body.scroll_active = true
	_body.custom_minimum_size = Vector2(560, 540)
	_body.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
	box.add_child(_body)


func _fill() -> void:
	if missions == null or progress == null or _body == null:
		return
	var text := ""
	var sections: Array = missions.log_sections(progress)
	for section_value in sections:
		var section: Dictionary = section_value
		if text != "":
			text += "\n"
		text += str(section["zone"])
		for row_value in section["rows"]:
			var row: Dictionary = row_value
			text += "\n  %s — %s" % [str(row["name"]), str(row["status"])]
	_body.text = text


func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.09, 0.07, 0.94)
	box.border_color = Color(0.72, 0.58, 0.32)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box
