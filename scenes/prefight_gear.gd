extends Control
class_name PrefightGear

## Pre-fight loadout. Same deployment step as Elements. Big buttons, few
## words: the set, Gatewarden's Neutral / Ranged Guard when that set is on,
## and Intact / Overwound when this class has a Still. Locked once the
## fight starts (the board only opens this during deployment).

signal changed(class_id: String)
signal closed

const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const CREAM := Color(0.96, 0.93, 0.86)
const BUTTON_H := 64

var font: Font
var class_ids: Array = []
var selected: String = ""
var _bag: GearBag
var _vault: StillVault
var _header: Label
var _class_row: HBoxContainer
var _set_flow: HFlowContainer
var _empty: Label
var _stance_box: VBoxContainer
var _stance_row: HBoxContainer
var _stance_line: Label
var _still_box: VBoxContainer
var _still_title: Label
var _still_row: HBoxContainer
var _still_line: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bag = GearBag.load_saved()
	_vault = StillVault.load_saved()
	if selected == "" and not class_ids.is_empty():
		selected = str(class_ids[0])
	_build()
	_refresh()


func set_classes(ids: Array) -> void:
	class_ids = []
	for id in ids:
		var cid := str(id)
		if GearBag.CLASS_IDS.has(cid) and not class_ids.has(cid):
			class_ids.append(cid)
	if not class_ids.has(selected):
		selected = str(class_ids[0]) if not class_ids.is_empty() else ""
	if is_inside_tree() and _set_flow != null:
		_refresh()


func bag() -> GearBag:
	return _bag


func vault() -> StillVault:
	return _vault


func wear_set(family: String) -> Dictionary:
	var result := _bag.wear_family(selected, family)
	if bool(result.get("ok", false)):
		_bag.save()
		changed.emit(selected)
		_refresh()
	return result


func choose_stance(mode: String) -> Dictionary:
	var result := _bag.set_stance(mode)
	if bool(result.get("ok", false)):
		_bag.save()
		changed.emit(selected)
		_refresh()
	return result


func choose_still(mode: String) -> Dictionary:
	_vault.set_focus(selected)
	var result := _vault.set_mode(mode)
	if bool(result.get("ok", false)):
		_vault.save()
		changed.emit(selected)
		_refresh()
	return result


func pick_class(class_id: String) -> void:
	if not class_ids.has(class_id):
		return
	selected = class_id
	_bag.set_focus(class_id)
	_bag.save()
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.62))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36
	panel.offset_top = 28
	panel.offset_right = -36
	panel.offset_bottom = -28
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.09, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_header = _label("Gear", 26, GOLD_BRIGHT)
	_header.name = "GearHeader"
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_header)
	var done := _button("Done")
	done.name = "DoneGear"
	done.custom_minimum_size = Vector2(160, BUTTON_H)
	done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.pressed.connect(close)
	top.add_child(done)
	body.add_child(top)

	_class_row = HBoxContainer.new()
	_class_row.name = "ClassRow"
	_class_row.add_theme_constant_override("separation", 10)
	_class_row.visible = false
	body.add_child(_class_row)

	body.add_child(_label("Set", 16, GOLD_DIM))
	_set_flow = HFlowContainer.new()
	_set_flow.name = "SetFlow"
	_set_flow.add_theme_constant_override("h_separation", 10)
	_set_flow.add_theme_constant_override("v_separation", 10)
	_set_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_set_flow)
	_empty = _label("No sets in the bag.", 18, GOLD_DIM)
	_empty.name = "NoSets"
	_empty.visible = false
	body.add_child(_empty)

	_stance_box = VBoxContainer.new()
	_stance_box.name = "StanceBox"
	_stance_box.add_theme_constant_override("separation", 8)
	_stance_box.visible = false
	_stance_box.add_child(_label("Stance", 16, GOLD_DIM))
	_stance_row = HBoxContainer.new()
	_stance_row.add_theme_constant_override("separation", 10)
	_stance_box.add_child(_stance_row)
	_stance_line = _label("", 18, CREAM)
	_stance_line.name = "StanceLine"
	_stance_box.add_child(_stance_line)
	body.add_child(_stance_box)

	_still_box = VBoxContainer.new()
	_still_box.name = "StillBox"
	_still_box.add_theme_constant_override("separation", 8)
	_still_box.visible = false
	_still_title = _label("Still", 16, GOLD_DIM)
	_still_title.name = "StillTitle"
	_still_box.add_child(_still_title)
	_still_row = HBoxContainer.new()
	_still_row.add_theme_constant_override("separation", 10)
	_still_box.add_child(_still_row)
	_still_line = _label("", 18, CREAM)
	_still_line.name = "StillLine"
	_still_box.add_child(_still_line)
	body.add_child(_still_box)


func _refresh() -> void:
	if _header == null:
		return
	var shown := SpellKits.display_name(selected) if selected != "" else ""
	_header.text = "Gear · %s" % shown if shown != "" else "Gear"
	_fill_classes()
	_fill_sets()
	_fill_stance()
	_fill_still()


func _fill_classes() -> void:
	_clear(_class_row)
	_class_row.visible = class_ids.size() > 1
	if not _class_row.visible:
		return
	for cid in class_ids:
		var button := _button(SpellKits.display_name(str(cid)))
		button.name = "Class_%s" % str(cid)
		button.custom_minimum_size = Vector2(168, BUTTON_H)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if str(cid) == selected:
			_light(button)
		button.pressed.connect(pick_class.bind(str(cid)))
		_class_row.add_child(button)


func _fill_sets() -> void:
	_clear(_set_flow)
	var families: Array = _bag.families_in_bag(selected) if selected != "" else []
	var worn := _bag.worn_family(selected) if selected != "" else ""
	_empty.visible = families.is_empty()
	for fam in families:
		var spec: Dictionary = GearBag.FAMILIES[fam]
		var button := _button(str(spec.get("name", fam)))
		button.name = "Set_%s" % str(fam)
		button.custom_minimum_size = Vector2(210, BUTTON_H)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if str(fam) == worn:
			_light(button)
		button.pressed.connect(wear_set.bind(str(fam)))
		_set_flow.add_child(button)


func _fill_stance() -> void:
	_clear(_stance_row)
	var show := selected != "" and _bag.worn_family(selected) == GearBag.STANCE_FAMILY
	_stance_box.visible = show
	if not show:
		return
	var pieces := int(_bag.set_counts(selected).get(GearBag.STANCE_FAMILY, 0))
	var mode := _bag.stance_of()
	for stance_mode in GearBag.STANCES:
		var label := "Neutral" if str(stance_mode) == GearBag.STANCE_NEUTRAL else "Ranged Guard"
		var button := _button(label)
		button.name = "Stance_%s" % str(stance_mode)
		button.custom_minimum_size = Vector2(220, BUTTON_H)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = GearBag.stance_sentence(str(stance_mode))
		if mode == str(stance_mode):
			_light(button)
		button.pressed.connect(choose_stance.bind(str(stance_mode)))
		_stance_row.add_child(button)
	if pieces < GearBag.STANCE_PIECES:
		_stance_line.text = "Needs 5 pieces."
	elif mode == GearBag.STANCE_RANGED:
		_stance_line.text = "%d%% less from 3+ tiles. %d%% more from 1–2." % [GearBag.STANCE_FAR_CUT, GearBag.STANCE_NEAR_AMP]
	else:
		_stance_line.text = "+%d Resist." % GearBag.STANCE_NEUTRAL_RESIST
	_stance_line.tooltip_text = GearBag.stance_sentence(mode)


func _fill_still() -> void:
	_clear(_still_row)
	var still_id := _vault.socket_of(selected) if selected != "" else ""
	_still_box.visible = still_id != ""
	if still_id == "":
		return
	var mode := _vault.mode_of(selected)
	_still_title.text = "Still · %s" % StillVault.display_name(still_id)
	for still_mode in StillVault.MODES:
		var label := "Intact" if str(still_mode) == "intact" else "Overwound"
		var button := _button(label)
		button.name = "Still_%s" % str(still_mode)
		button.custom_minimum_size = Vector2(220, BUTTON_H)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if mode == str(still_mode):
			_light(button)
		button.pressed.connect(choose_still.bind(str(still_mode)))
		_still_row.add_child(button)
	var effects: Dictionary = StillVault.EFFECTS.get(still_id, {})
	_still_line.text = str(effects.get(mode, ""))


func _clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _light(button: Button) -> void:
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0.30, 0.24, 0.10)
	lit.border_color = GOLD_BRIGHT
	lit.set_border_width_all(3)
	lit.set_content_margin_all(8)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style_name, lit)
	button.add_theme_color_override("font_color", Color.WHITE)


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
	button.clip_text = false
	button.custom_minimum_size = Vector2(160, BUTTON_H)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", CREAM)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.04, 0.07, 0.13, 0.98)
		box.border_color = GOLD_BRIGHT if style_name in ["hover", "focus"] else GOLD
		box.set_border_width_all(2)
		box.set_content_margin_all(8)
		button.add_theme_stylebox_override(style_name, box)
	return button
