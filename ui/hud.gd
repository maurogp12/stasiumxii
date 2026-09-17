extends CanvasLayer
class_name CombatHUD

signal spell_selected(spell_id: String)
signal face_requested(dir: String)
signal end_turn_requested
signal new_match_requested

const KESTREL_GREEN := Color("#2E5A3C")
const IRONJAW_RED := Color("#8B2E2E")

var _selected_spell: String = ""
var _spell_buttons: Dictionary = {}
var _face_buttons: Dictionary = {}
var _kestrel_body: RichTextLabel
var _ironjaw_body: RichTextLabel
var _turn_label: Label
var _coach_label: Label
var _selected_label: Label
var _ap_pips: HBoxContainer
var _mp_pips: HBoxContainer


func _ready() -> void:
	layer = 10
	_build()


func selected_spell() -> String:
	return _selected_spell


func clear_spell() -> void:
	_selected_spell = ""
	_refresh_spell_buttons()
	_update_selected_label()


func render(snap: Dictionary, legal: Array) -> void:
	var units: Array = snap.get("units", [])
	var kestrel := _unit(units, 0)
	var ironjaw := _unit(units, 1)
	_kestrel_body.text = _unit_card_text(kestrel, int(snap.get("active_seat", 0)) == 0)
	_ironjaw_body.text = _unit_card_text(ironjaw, int(snap.get("active_seat", 0)) == 1)

	var active := _unit(units, int(snap.get("active_seat", 0)))
	var active_name := str(active.get("name", "—"))
	if snap.get("match_over", false):
		var winner := _unit(units, int(snap.get("winner_seat", -1)))
		_turn_label.text = "Match over — %s wins" % str(winner.get("name", "—"))
	else:
		_turn_label.text = "Turn %d  ·  %s" % [int(snap.get("turn_index", 1)), active_name]

	_render_pips(_ap_pips, int(active.get("ap", 0)), int(active.get("max_ap", 6)), Color(0.95, 0.78, 0.28))
	_render_pips(_mp_pips, int(active.get("mp", 0)), int(active.get("max_mp", 3)), Color(0.45, 0.75, 0.95))
	_coach_label.text = str(snap.get("coach", ""))
	_update_selected_label()

	var legal_spells := {}
	for intent in legal:
		if str(intent.get("type", "")) == "cast":
			legal_spells[str(intent.get("spell", ""))] = true
	for spell_id in _spell_buttons.keys():
		var button: Button = _spell_buttons[spell_id]
		var in_kit := false
		if not active.is_empty():
			in_kit = spell_id in active.get("spells", [])
		button.disabled = snap.get("match_over", false) or not in_kit
		button.modulate = Color(1, 1, 1, 1) if legal_spells.has(spell_id) else Color(1, 1, 1, 0.72)
	for button in _face_buttons.values():
		button.disabled = snap.get("match_over", false)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	root.add_child(_make_banner(true))
	root.add_child(_make_banner(false))

	_turn_label = Label.new()
	_turn_label.position = Vector2(280, 12)
	_turn_label.size = Vector2(400, 28)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 18)
	_turn_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.12))
	root.add_child(_turn_label)

	var resource_panel := Panel.new()
	resource_panel.position = Vector2(300, 44)
	resource_panel.size = Vector2(360, 52)
	resource_panel.add_theme_stylebox_override("panel", _panel(Color(1, 1, 1, 0.78)))
	root.add_child(resource_panel)
	var res_box := VBoxContainer.new()
	res_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	res_box.add_theme_constant_override("separation", 4)
	resource_panel.add_child(res_box)
	_ap_pips = _make_pip_row("AP")
	_mp_pips = _make_pip_row("MP")
	res_box.add_child(_ap_pips)
	res_box.add_child(_mp_pips)

	_selected_label = Label.new()
	_selected_label.position = Vector2(220, 620)
	_selected_label.size = Vector2(520, 24)
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.add_theme_font_size_override("font_size", 16)
	_selected_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.12))
	root.add_child(_selected_label)

	var action_bar := HBoxContainer.new()
	action_bar.position = Vector2(90, 650)
	action_bar.size = Vector2(780, 36)
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", 8)
	root.add_child(action_bar)

	for spell_id in [SpellKits.ADVANCE, SpellKits.STRIKE, SpellKits.MARK_SHOT]:
		var def: Dictionary = SpellKits.spell(spell_id)
		var button := Button.new()
		button.text = "%s  %dAP/%dMP" % [def["name"], def["ap"], def["mp"]]
		button.custom_minimum_size = Vector2(150, 32)
		button.pressed.connect(_on_spell_pressed.bind(spell_id))
		action_bar.add_child(button)
		_spell_buttons[spell_id] = button

	var end_btn := Button.new()
	end_btn.text = "End Turn"
	end_btn.custom_minimum_size = Vector2(110, 32)
	end_btn.pressed.connect(func() -> void: end_turn_requested.emit())
	action_bar.add_child(end_btn)

	var new_btn := Button.new()
	new_btn.text = "New Match"
	new_btn.custom_minimum_size = Vector2(110, 32)
	new_btn.pressed.connect(func() -> void: new_match_requested.emit())
	action_bar.add_child(new_btn)

	var face_bar := HBoxContainer.new()
	face_bar.position = Vector2(360, 578)
	face_bar.size = Vector2(240, 32)
	face_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	face_bar.add_theme_constant_override("separation", 6)
	root.add_child(face_bar)
	var face_caption := Label.new()
	face_caption.text = "Face"
	face_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face_bar.add_child(face_caption)
	for dir in ["N", "E", "S", "W"]:
		var button := Button.new()
		button.text = dir
		button.custom_minimum_size = Vector2(36, 28)
		button.pressed.connect(_on_face_pressed.bind(dir))
		face_bar.add_child(button)
		_face_buttons[dir] = button

	_coach_label = Label.new()
	_coach_label.position = Vector2(40, 690)
	_coach_label.size = Vector2(880, 24)
	_coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach_label.add_theme_font_size_override("font_size", 15)
	_coach_label.add_theme_color_override("font_color", Color(0.14, 0.1, 0.12))
	root.add_child(_coach_label)

	_update_selected_label()


func _make_banner(is_kestrel: bool) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(16, 12) if is_kestrel else Vector2(704, 12)
	panel.size = Vector2(240, 132)
	var color := KESTREL_GREEN if is_kestrel else IRONJAW_RED
	panel.add_theme_stylebox_override("panel", _panel(color))
	var title := Label.new()
	title.text = "Kestrel" if is_kestrel else "Ironjaw"
	title.position = Vector2(12, 6)
	title.size = Vector2(216, 22)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(title)
	var body := RichTextLabel.new()
	body.position = Vector2(10, 30)
	body.size = Vector2(220, 96)
	body.bbcode_enabled = true
	body.scroll_active = false
	body.fit_content = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)
	if is_kestrel:
		_kestrel_body = body
	else:
		_ironjaw_body = body
	return panel


func _make_pip_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(28, 18)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.12))
	row.add_child(label)
	return row


func _render_pips(row: HBoxContainer, current: int, maximum: int, fill: Color) -> void:
	while row.get_child_count() > 1:
		var child := row.get_child(row.get_child_count() - 1)
		row.remove_child(child)
		child.free()
	for i in range(maximum):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 12)
		pip.color = fill if i < current else Color(0.75, 0.75, 0.78)
		row.add_child(pip)


func _unit_card_text(unit: Dictionary, active: bool) -> String:
	if unit.is_empty():
		return "[color=#ffffff]—[/color]"
	var status := "ACTIVE" if active and unit["alive"] else ("DOWN" if not unit["alive"] else "waiting")
	return "[color=#ffffff]%s  HP %d/%d\nAP %d  MP %d  Face %s\nMarks %d/%d  Impact %d/%d\n%s[/color]" % [
		status,
		int(unit["hp"]),
		int(unit["max_hp"]),
		int(unit["ap"]),
		int(unit["mp"]),
		str(unit["facing"]),
		int(unit["marks"]),
		int(unit["marks_cap"]),
		int(unit["impact"]),
		int(unit["impact_cap"]),
		str(unit["element"]).capitalize() + " · " + ", ".join(PackedStringArray(unit["spells"])),
	]


func _unit(units: Array, seat: int) -> Dictionary:
	for unit in units:
		if int(unit.get("seat", -1)) == seat:
			return unit
	return {}


func _panel(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _on_spell_pressed(spell_id: String) -> void:
	if _selected_spell == spell_id:
		_selected_spell = ""
	else:
		_selected_spell = spell_id
	_refresh_spell_buttons()
	_update_selected_label()
	spell_selected.emit(_selected_spell)


func _on_face_pressed(dir: String) -> void:
	face_requested.emit(dir)


func _refresh_spell_buttons() -> void:
	for spell_id in _spell_buttons.keys():
		var button: Button = _spell_buttons[spell_id]
		if _selected_spell == spell_id:
			button.modulate = Color(1.15, 1.1, 0.7)
		else:
			button.modulate = Color.WHITE


func _update_selected_label() -> void:
	if _selected_spell == "":
		_selected_label.text = "Selected: Walk  ·  click an empty tile  ·  right-click to face"
		return
	var def: Dictionary = SpellKits.spell(_selected_spell)
	_selected_label.text = "Selected: %s  ·  %d AP / %d MP  ·  range %d–%d" % [
		def.get("name", _selected_spell),
		int(def.get("ap", 0)),
		int(def.get("mp", 0)),
		int(def.get("min_range", 0)),
		int(def.get("max_range", 0)),
	]
