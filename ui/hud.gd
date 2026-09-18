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
var _action_bar: HBoxContainer
var _kestrel_body: RichTextLabel
var _ironjaw_body: RichTextLabel
var _turn_label: Label
var _coach_label: Label
var _selected_label: Label
var _ap_pips: HBoxContainer
var _mp_pips: HBoxContainer
var _end_turn_button: Button
var _new_match_button: Button
var _handoff_overlay: ColorRect
var _handoff_panel: Panel
var _handoff_label: Label
var _clock_label: Label
var _clock_bar: ColorRect
var _clock_bar_max_width: float = 220.0
var _clock_seconds: int = int(TurnClock.DURATION_SEC)
var _locked: bool = false


## Kit chrome for the active seat. Advance is never offered unless class_id is ironjaw.
## legal_intents cannot add a spell the kit does not own; enablement uses legal_cast_ids().
static func offered_cast_ids(active: Dictionary, _legal: Array = []) -> Array:
	var offered: Array = []
	if active.is_empty():
		return offered
	var class_id := str(active.get("class_id", ""))
	for spell_id in active.get("spells", []):
		var id := str(spell_id)
		if id == "":
			continue
		if id == SpellKits.ADVANCE and class_id != SpellKits.CLASS_IRONJAW:
			continue
		if not SpellKits.has_spell(class_id, id):
			continue
		if not offered.has(id):
			offered.append(id)
	return offered


static func legal_cast_ids(legal: Array) -> Dictionary:
	var out := {}
	for intent in legal:
		if str(intent.get("type", "")) != "cast":
			continue
		var id := str(intent.get("spell", ""))
		if id != "":
			out[id] = true
	return out


func _ready() -> void:
	layer = 10
	_build()


func selected_spell() -> String:
	return _selected_spell


func clear_spell() -> void:
	_selected_spell = ""
	_refresh_spell_buttons()
	_update_selected_label()


func set_locked(locked: bool) -> void:
	_locked = locked
	_apply_controls(false)


func show_turn_banner(unit_name: String, class_id: String) -> void:
	_handoff_label.text = "%s's turn" % unit_name
	var fill := KESTREL_GREEN if class_id == SpellKits.CLASS_KESTREL else IRONJAW_RED
	_handoff_panel.add_theme_stylebox_override("panel", _panel(fill))
	_handoff_overlay.visible = true
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func hide_turn_banner() -> void:
	_handoff_overlay.visible = false
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_turn_clock(seconds_left: int, running: bool, fraction: float) -> void:
	if _clock_label == null:
		return
	_clock_label.text = "%ds" % maxi(seconds_left, 0)
	_clock_seconds = maxi(seconds_left, 0)
	var color := Color(0.15, 0.12, 0.12)
	if not running:
		color = Color(0.42, 0.4, 0.42)
	elif seconds_left <= 5:
		color = Color(0.78, 0.12, 0.12)
	elif seconds_left <= 10:
		color = Color(0.72, 0.4, 0.08)
	_clock_label.add_theme_color_override("font_color", color)
	if _clock_bar == null:
		return
	var width := _clock_bar_max_width * clampf(fraction, 0.0, 1.0)
	_clock_bar.custom_minimum_size = Vector2(width, 8)
	_clock_bar.size = Vector2(width, 8)
	if not running:
		_clock_bar.color = Color(0.7, 0.7, 0.74)
	elif seconds_left <= 5:
		_clock_bar.color = Color(0.82, 0.28, 0.28)
	elif seconds_left <= 10:
		_clock_bar.color = Color(0.92, 0.68, 0.28)
	else:
		_clock_bar.color = Color(0.35, 0.7, 0.55)
	if _turn_label != null and not _turn_label.text.begins_with("Match over"):
		var base := _turn_label.text
		var sep := "  ·  "
		var parts := base.split(sep)
		if parts.size() >= 2:
			_turn_label.text = "%s%s%s%s%ds" % [parts[0], sep, parts[1], sep, _clock_seconds]


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
		_turn_label.text = "Turn %d  ·  %s  ·  %ds" % [int(snap.get("turn_index", 1)), active_name, _clock_seconds]

	_render_pips(_ap_pips, int(active.get("ap", 0)), int(active.get("max_ap", 6)), Color(0.95, 0.78, 0.28))
	_render_pips(_mp_pips, int(active.get("mp", 0)), int(active.get("max_mp", 3)), Color(0.45, 0.75, 0.95))
	_coach_label.text = str(snap.get("coach", ""))

	var offered: Array = offered_cast_ids(active, legal)
	_sync_spell_buttons(offered)
	if _selected_spell != "" and not offered.has(_selected_spell):
		_selected_spell = ""
	_update_selected_label()

	var legal_spells := legal_cast_ids(legal)
	var match_over := bool(snap.get("match_over", false))
	# OPEN A05: face/cast chrome follows CombatSim stun reject. Exact suppress list not locked.
	var stunned := int(active.get("stun_remaining", 0)) > 0 or bool(active.get("stunned", false))
	for spell_id in _spell_buttons.keys():
		var button: Button = _spell_buttons[spell_id]
		var can_submit: bool = legal_spells.has(spell_id) and not match_over and not stunned
		button.disabled = not can_submit
		if _selected_spell == spell_id:
			button.modulate = Color(1.15, 1.1, 0.7)
		elif can_submit:
			button.modulate = Color(1, 1, 1, 1)
		else:
			button.modulate = Color(1, 1, 1, 0.72)
	_apply_controls(match_over)
	if stunned and not match_over:
		for button in _face_buttons.values():
			(button as Button).disabled = true


func _apply_controls(match_over: bool) -> void:
	var block := match_over or _locked
	for spell_id in _spell_buttons.keys():
		if block:
			(_spell_buttons[spell_id] as Button).disabled = true
	for button in _face_buttons.values():
		(button as Button).disabled = block
	if _end_turn_button != null:
		_end_turn_button.disabled = block
	if _new_match_button != null:
		_new_match_button.disabled = _locked


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
	resource_panel.size = Vector2(360, 74)
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
	res_box.add_child(_make_clock_row())

	_selected_label = Label.new()
	_selected_label.position = Vector2(220, 620)
	_selected_label.size = Vector2(520, 24)
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.add_theme_font_size_override("font_size", 16)
	_selected_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.12))
	root.add_child(_selected_label)

	_action_bar = HBoxContainer.new()
	_action_bar.position = Vector2(90, 650)
	_action_bar.size = Vector2(780, 36)
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.add_theme_constant_override("separation", 8)
	root.add_child(_action_bar)

	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(110, 32)
	_end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	_action_bar.add_child(_end_turn_button)

	_new_match_button = Button.new()
	_new_match_button.text = "New Match"
	_new_match_button.custom_minimum_size = Vector2(110, 32)
	_new_match_button.pressed.connect(func() -> void: new_match_requested.emit())
	_action_bar.add_child(_new_match_button)

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
	_coach_label.position = Vector2(40, 682)
	_coach_label.size = Vector2(880, 34)
	_coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_label.add_theme_font_size_override("font_size", 15)
	_coach_label.add_theme_color_override("font_color", Color(0.14, 0.1, 0.12))
	root.add_child(_coach_label)

	_handoff_overlay = ColorRect.new()
	_handoff_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handoff_overlay.color = Color(0.06, 0.05, 0.07, 0.42)
	_handoff_overlay.visible = false
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_handoff_overlay)

	_handoff_panel = Panel.new()
	_handoff_panel.position = Vector2(230, 268)
	_handoff_panel.size = Vector2(500, 140)
	_handoff_panel.add_theme_stylebox_override("panel", _panel(KESTREL_GREEN))
	_handoff_overlay.add_child(_handoff_panel)

	_handoff_label = Label.new()
	_handoff_label.position = Vector2(16, 28)
	_handoff_label.size = Vector2(468, 84)
	_handoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_handoff_label.add_theme_font_size_override("font_size", 36)
	_handoff_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_handoff_label.text = "Kestrel's turn"
	_handoff_panel.add_child(_handoff_label)

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


func _make_clock_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var caption := Label.new()
	caption.text = "TIME"
	caption.custom_minimum_size = Vector2(36, 18)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color(0.15, 0.12, 0.12))
	row.add_child(caption)
	_clock_label = Label.new()
	_clock_label.text = "%ds" % int(TurnClock.DURATION_SEC)
	_clock_label.custom_minimum_size = Vector2(36, 18)
	_clock_label.add_theme_font_size_override("font_size", 14)
	_clock_label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.12))
	row.add_child(_clock_label)
	_clock_bar = ColorRect.new()
	_clock_bar.custom_minimum_size = Vector2(_clock_bar_max_width, 8)
	_clock_bar.size = Vector2(_clock_bar_max_width, 8)
	_clock_bar.color = Color(0.35, 0.7, 0.55)
	row.add_child(_clock_bar)
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
	# OPEN A05: stun_remaining / stunned-this-turn display only. Suppress list not locked.
	var stun_note := ""
	if int(unit.get("stun_remaining", 0)) > 0 or bool(unit.get("stunned", false)):
		stun_note = "  STUN"
	return "[color=#ffffff]%s  HP %d/%d\nAP %d  MP %d  Face %s\nMarks %d/%d  Impact %d/%d%s\n%s[/color]" % [
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
		stun_note,
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


func _sync_spell_buttons(offered: Array) -> void:
	var offered_ids: Array = []
	for spell_id in offered:
		var id := str(spell_id)
		if id != "" and not offered_ids.has(id):
			offered_ids.append(id)
	var stale: Array = []
	for spell_id in _spell_buttons.keys():
		if not offered_ids.has(spell_id):
			stale.append(spell_id)
	for spell_id in stale:
		var button: Button = _spell_buttons[spell_id]
		_spell_buttons.erase(spell_id)
		if is_instance_valid(button):
			_action_bar.remove_child(button)
			button.free()
	var insert_idx := 0
	for spell_id in offered_ids:
		var def: Dictionary = SpellKits.spell(spell_id)
		if def.is_empty():
			continue
		if not _spell_buttons.has(spell_id):
			var button := Button.new()
			button.text = _spell_button_text(def)
			button.custom_minimum_size = Vector2(118, 32)
			button.pressed.connect(_on_spell_pressed.bind(spell_id))
			_action_bar.add_child(button)
			_spell_buttons[spell_id] = button
		_action_bar.move_child(_spell_buttons[spell_id], insert_idx)
		insert_idx += 1


func _spell_button_text(def: Dictionary) -> String:
	return "%s  %dAP/%dMP" % [def["name"], int(def.get("ap", 0)), int(def.get("mp", 0))]


func _on_spell_pressed(spell_id: String) -> void:
	if not _spell_buttons.has(spell_id):
		return
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
		_selected_label.text = "Selected: Walk  ·  click a destination  ·  right-click to face"
		return
	var def: Dictionary = SpellKits.spell(_selected_spell)
	var range_metric := "Manhattan" if str(def.get("range_mode", "chebyshev")) == "manhattan" else "Chebyshev"
	_selected_label.text = "Selected: %s  ·  %d AP / %d MP  ·  range %d–%d %s" % [
		def.get("name", _selected_spell),
		int(def.get("ap", 0)),
		int(def.get("mp", 0)),
		int(def.get("min_range", 0)),
		int(def.get("max_range", 0)),
		range_metric,
	]
