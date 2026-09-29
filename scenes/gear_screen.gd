extends Control
class_name GearScreen

## Hub overlay for mobile gear (Blueprint §10). Left: the five worn slots
## (tap to take off). Middle: the bag (tap to wear, Fuse joins two copies of
## the same item and plus). Right: set bonuses, attune, AP/MP after the 8/5
## clamp. Worn gear goes into Stasis and online Koliseo fights.

signal closed

const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const ROW_HEIGHT := 48
const RARITY_TINT := {
	"Normal": Color(0.86, 0.84, 0.78),
	"Rare": Color(0.55, 0.75, 1.0),
	"Legendary": Color(1.0, 0.72, 0.30),
	"Ultra": Color(0.86, 0.50, 1.0),
}

var font: Font
var _bag: GearBag
var _header: Label
var _status: Label
var _slots_box: VBoxContainer
var _bag_box: VBoxContainer
var _sets_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bag = GearBag.load_saved()
	_build()
	_refresh()


func bag() -> GearBag:
	return _bag


func status_text() -> String:
	return _status.text if _status != null else ""


func header_text() -> String:
	return _header.text if _header != null else ""


func wear(uid: int) -> Dictionary:
	var result := _bag.equip(uid)
	_after(result, "Wearing %s." % GearBag.item_label(_bag.item(uid)))
	return result


func take_off(slot: String) -> Dictionary:
	var result := _bag.unequip(slot)
	_after(result, "Took off the %s." % slot)
	return result


func fuse(uid: int) -> Dictionary:
	var partner := _bag.fuse_partner(uid)
	var result := _bag.fuse(uid, partner) if partner != -1 else {"ok": false, "reason": "no_partner"}
	_after(result, "Fused: %s." % GearBag.item_label(_bag.item(uid)))
	return result


func choose_attune(family: String, element: String) -> Dictionary:
	var result := _bag.set_attune(family, element)
	_after(result, "%s attuned to %s." % [str(GearBag.FAMILIES.get(family, {}).get("name", family)), element])
	return result


func open_levels() -> CharacterScreen:
	var screen: CharacterScreen = load("res://scenes/character_screen.gd").new()
	screen.name = "CharacterScreen"
	screen.font = font
	add_child(screen)
	return screen


func open_stills() -> StillsScreen:
	var screen: StillsScreen = load("res://scenes/stills_screen.gd").new()
	screen.name = "StillsScreen"
	screen.font = font
	add_child(screen)
	return screen


func close() -> void:
	closed.emit()
	queue_free()


func _after(result: Dictionary, ok_text: String) -> void:
	if bool(result.get("ok", false)):
		_bag.save()
		_status.text = ok_text
	else:
		_status.text = _reason_text(str(result.get("reason", "")))
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.74))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 20
	panel.offset_right = -24
	panel.offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.09, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	_header = _label("", 18, GOLD_BRIGHT)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	var levels_button := _button("Levels")
	levels_button.name = "OpenLevels"
	levels_button.pressed.connect(open_levels)
	top.add_child(levels_button)
	var stills_button := _button("Stills")
	stills_button.name = "OpenStills"
	stills_button.pressed.connect(open_stills)
	top.add_child(stills_button)
	var close_button := _button("Close")
	close_button.name = "CloseGear"
	close_button.pressed.connect(close)
	top.add_child(close_button)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	_slots_box = _column(columns, "Worn", 1.0)
	_bag_box = _column(columns, "Bag", 1.1)
	_sets_box = _column(columns, "Set bonuses", 1.0)
	_status = _label("", 14, GOLD)
	_status.name = "GearStatus"
	body.add_child(_status)


func _column(parent: Control, title: String, stretch: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = stretch
	col.add_theme_constant_override("separation", 6)
	col.add_child(_label(title, 16, GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	parent.add_child(col)
	return list


func _refresh() -> void:
	var apmp := _bag.ap_mp()
	var grey := ""
	if int(apmp["ap_greyed"]) > 0 or int(apmp["mp_greyed"]) > 0:
		grey = "   (extra greyed out)"
	var st := GearBag.combat_stats(_bag.worn_list(), _bag.attune)
	var hp := roundi(float(80 + int(st["hp_flat"])) * (1.0 + float(st["hp_pct"]) / 100.0))
	_header.text = "Gear   HP %d   Mastery %d   Init %d   AP %d/%d   MP %d/%d%s   Loot today %d/%d" % [
		hp, int(st["mastery"]), int(st["init"]),
		int(apmp["ap"]), GearBag.AP_CAP, int(apmp["mp"]), GearBag.MP_CAP, grey,
		_bag.loot_clears_left(int(Time.get_unix_time_from_system())), GearBag.LOOT_CLEARS_PER_DAY,
	]
	_clear(_slots_box)
	for slot in GearBag.SLOTS:
		var worn := _bag.equipped_item(slot)
		var text := "%s (%s): —" % [slot.capitalize(), GearBag.SLOT_STAT[slot]]
		var button := _button(text)
		button.name = "Slot_" + slot
		if not worn.is_empty():
			button.text = "%s: %s" % [slot.capitalize(), GearBag.item_label(worn)]
			_tint(button, str(worn["item_id"]))
			button.pressed.connect(take_off.bind(slot))
		else:
			button.disabled = true
		_slots_box.add_child(button)
	_clear(_bag_box)
	var shown := 0
	var sorted := _bag.items.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["item_id"]) != str(b["item_id"]):
			return str(a["item_id"]) < str(b["item_id"])
		return int(a["plus"]) > int(b["plus"]))
	for it in sorted:
		var uid := int(it["uid"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var wear_button := _button("%s  ·  %s%s" % [GearBag.item_label(it), GearBag.part_line(str(it["item_id"]), int(it["plus"])), "  (worn)" if _bag.is_equipped(uid) else ""])
		wear_button.name = "Item_%d" % uid
		wear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tint(wear_button, str(it["item_id"]))
		wear_button.disabled = _bag.is_equipped(uid)
		wear_button.pressed.connect(wear.bind(uid))
		row.add_child(wear_button)
		var fuse_button := _button("Fuse")
		fuse_button.name = "Fuse_%d" % uid
		var partner := _bag.fuse_partner(uid)
		fuse_button.disabled = partner == -1 or not bool(_bag.can_fuse(uid, partner).get("ok", false))
		fuse_button.pressed.connect(fuse.bind(uid))
		row.add_child(fuse_button)
		_bag_box.add_child(row)
		shown += 1
	if shown == 0:
		_bag_box.add_child(_label("Empty. Clear a Stasis door or buy Duskbrand in the Shop.", 14, GOLD_DIM))
	_clear(_sets_box)
	var counts := _bag.set_counts()
	var any := false
	for fam in GearBag.FAMILY_ORDER:
		var pieces := int(counts.get(fam, 0))
		if pieces <= 0:
			continue
		any = true
		var spec: Dictionary = GearBag.FAMILIES[fam]
		var title := _label("%s (%s) — %d/5" % [str(spec["name"]), str(spec["rarity"]), pieces], 15, RARITY_TINT.get(str(spec["rarity"]), GOLD_BRIGHT))
		_sets_box.add_child(title)
		for tier in [2, 4, 5]:
			var on: bool = pieces >= int(tier)
			var line := _label("  %dpc: %s" % [tier, str(spec["bonus"][tier])], 13, GOLD_BRIGHT if on else GOLD_DIM)
			_sets_box.add_child(line)
		if pieces >= GearBag.ATTUNE_PIECES:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			for element in GearBag.ELEMENTS:
				var el := _button(element)
				el.name = "Attune_%s_%s" % [fam, element]
				el.custom_minimum_size = Vector2(84, ROW_HEIGHT)
				el.alignment = HORIZONTAL_ALIGNMENT_CENTER
				if _bag.attune_active(fam) == element:
					# Chosen element: lit gold frame and filled.
					var lit := StyleBoxFlat.new()
					lit.bg_color = Color(0.30, 0.24, 0.10)
					lit.border_color = GOLD_BRIGHT
					lit.set_border_width_all(2)
					el.add_theme_stylebox_override("normal", lit)
					el.add_theme_color_override("font_color", Color.WHITE)
				el.pressed.connect(choose_attune.bind(fam, element))
				row.add_child(el)
			_sets_box.add_child(row)
	if not any:
		_sets_box.add_child(_label("Wear 2 pieces of one family for its first bonus.", 14, GOLD_DIM))
	_sets_box.add_child(_label("Gear counts in Stasis and online Koliseo (Koliseo counts every part as +0). Init turn order and the Undertow / Ironveil / Brightedge 5pc effects are not active yet.", 12, GOLD_DIM))


static func _reason_text(reason: String) -> String:
	match reason:
		"no_partner", "different_item", "different_plus":
			return "Fuse needs two of the same item at the same plus."
		"plus_cap":
			return "Already +5."
		"needs_2_pieces":
			return "Attune needs 2 worn pieces of that family."
		"empty_slot":
			return "Nothing worn there."
	return "Cannot do that."


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _tint(button: Button, item_id: String) -> void:
	var rarity := str(GearBag.FAMILIES.get(GearBag.family_of(item_id), {}).get("rarity", ""))
	button.add_theme_color_override("font_color", RARITY_TINT.get(rarity, GOLD_BRIGHT))


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
	button.custom_minimum_size = Vector2(80, ROW_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", GOLD_DIM)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.06, 0.12, 0.95) if style_name != "disabled" else Color(0.02, 0.03, 0.06, 0.9)
		style.border_color = GOLD_BRIGHT if style_name in ["hover", "focus"] else (GOLD_DIM if style_name == "disabled" else GOLD)
		style.set_border_width_all(1)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(style_name, style)
	return button
