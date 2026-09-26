extends Control
class_name StasisRun

## Class pick for one mobile Stasis gate. Clickable only.
## The fight itself is scenes/stasis_fight.tscn on that biome's 15×15 board.
## This scene stays off PC main.

var _auto_launch: bool = true
var _title: Label
var _body: Label
var _note: Label
var _class_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not StasisCatalog.begin(MobileHub.pending_biome_id):
		_build_invalid()
		return
	_build()


func title_text() -> String:
	if _title == null:
		return ""
	return _title.text


func body_text() -> String:
	if _body == null:
		return ""
	return _body.text


func note_text() -> String:
	if _note == null:
		return ""
	return _note.text


func class_button_count() -> int:
	return _class_buttons.size()


func class_button_text(index: int) -> String:
	if index < 0 or index >= _class_buttons.size():
		return ""
	return _class_buttons[index].text


func pick_class(class_id: String) -> bool:
	var id := SpellKits.normalize_class_id(class_id)
	if not MobileHub.is_biome_id(StasisCatalog.biome_id):
		return false
	if not SpellKits.is_roster_class(id):
		return false
	StasisCatalog.class_id = id
	if not _auto_launch:
		return true
	get_tree().change_scene_to_file(StasisCatalog.FIGHT_SCENE)
	return true


func back_to_hub() -> void:
	StasisCatalog.clear_run()
	if not _auto_launch:
		return
	get_tree().change_scene_to_file(MobileHub.MOBILE_HUB)


func _build_invalid() -> void:
	var col := _shell()
	_title = _label(col, "Stasis", 28, Color(0.95, 0.9, 0.82))
	_body = _label(col, "Open a Stasis door from the hub.", 18, Color(0.78, 0.74, 0.7))
	_note = _label(col, "", 16, Color(0.9, 0.82, 0.5))
	_add_back(col)


func _build() -> void:
	var col := _shell()
	var id := StasisCatalog.biome_id
	_title = _label(col, StasisCatalog.door_name(id), 28, Color(0.95, 0.9, 0.82))
	var trash := ", ".join(StasisCatalog.trash_names(id))
	var copy := "%s · %s\nTwo rooms. Room A is one fight with the trash pack, then Room B is the boss.\nTrash: %s\nBoss: %s" % [
		MobileHub.title_of(id),
		CellTagMap.blurb_of(id),
		trash,
		StasisCatalog.boss_name(id),
	]
	_body = _label(col, copy, 16, Color(0.78, 0.74, 0.7))
	_note = _label(col, "Foe numbers are provisional Open for playtest (trash %d HP / base %d, boss %d HP / base %d). Your class keeps its Locked kit. Not a Locked dungeon stamp." % [
		StasisCatalog.PROVISIONAL_TRASH_HP,
		StasisCatalog.PROVISIONAL_TRASH_ATTACK,
		StasisCatalog.PROVISIONAL_BOSS_HP,
		StasisCatalog.PROVISIONAL_BOSS_ATTACK,
	], 15, Color(0.9, 0.82, 0.5))
	var prompt := _label(col, "Pick a class", 18, Color(0.95, 0.9, 0.82))
	prompt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for class_id in SpellKits.LOCKED_ROSTER:
		var button := Button.new()
		button.text = "%s — %s" % [SpellKits.display_name(class_id), ClassSelect.role_line(class_id)]
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
		button.add_theme_stylebox_override("normal", _style(false))
		button.add_theme_stylebox_override("hover", _style(true))
		button.add_theme_stylebox_override("pressed", _style(true))
		button.add_theme_stylebox_override("focus", _style(true))
		button.pressed.connect(pick_class.bind(class_id))
		col.add_child(button)
		_class_buttons.append(button)
	_add_back(col)


func _shell() -> VBoxContainer:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.08)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	return col


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _add_back(parent: Node) -> void:
	var back := Button.new()
	back.text = "Back to hub"
	back.custom_minimum_size = Vector2(0, 72)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.focus_mode = Control.FOCUS_ALL
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	back.add_theme_stylebox_override("normal", _style(false))
	back.add_theme_stylebox_override("hover", _style(true))
	back.add_theme_stylebox_override("pressed", _style(true))
	back.add_theme_stylebox_override("focus", _style(true))
	back.pressed.connect(back_to_hub)
	parent.add_child(back)


func _style(lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.28, 0.34) if lit else Color(0.14, 0.18, 0.22)
	style.border_color = Color(0.55, 0.66, 0.74)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
