extends Control
class_name ElementsScreen

## Elements Step 3 (Mauro 5 Oct 2026): "everyone will choose their own
## elements there is no primary"; "make sure to put the elements and their
## combo well explained for player choose carefully".
## Left: the five classes. Right (scrolls): how elements work, the 2-element
## pick, which element each attack spell uses, the Blend this pick makes, then
## the guide to all four elements and all six Blends.
## First pick free; a new pair costs 2 trophies; moving a spell between the
## two picked elements is free (HeroProgress.set_elements).

signal closed

const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const GREEN := Color(0.66, 0.84, 0.25)
const RED := Color(0.95, 0.45, 0.4)
const ROW_HEIGHT := 48
const TINT := {
	"air": Color(0.55, 0.92, 0.86),
	"earth": Color(0.78, 0.56, 0.3),
	"water": Color(0.32, 0.62, 1.0),
	"fire": Color(1.0, 0.45, 0.15),
}

## What every hit of the element adds (CombatSim._flex_target / _flex_caster,
## SpellKits.spell_as).
const ELEMENT_TEXT := {
	"air": "Reach and speed. Spells that reach 3+ tiles reach 1 farther (not Mark Shot). A melee hit gives you +1 MP to step away.",
	"earth": "Weight. After the hit you are Grounded until your next turn (Bastion: no push can move you). Your pushes into a wall or the edge hit for 8 instead of 4.",
	"fire": "Burn. The enemy burns for 4 at the start of its next turn (does not stack).",
	"water": "Flow. Damage takes 1 MP from the enemy at its next turn start. Your heals heal 4 more.",
}

## The six Blends: [first, second, name, what it does, good for].
const BLEND_ROWS := [
	["air", "earth", "Drift-Pin", "Slides the enemy 1 tile away from you. If a wall, the edge or a body is in the way it hits for 8 instead. Pinned: it cannot walk on its next turn (Advance and Ambush still work). Never twice in a row on the same enemy.", "Ranged fighters keeping melee away; slamming enemies into walls."],
	["air", "fire", "Spark", "4 damage that ignores resist and breaks shields first, then pushes the enemy 1 tile away. Your Fire Burn still lands.", "Finishing low enemies, cracking Mender's Ward."],
	["air", "water", "Sleet", "An icy blast pushes the enemy 1 tile away from you. A body in the way stops it; a wall or the edge stops it with the usual 4-damage bump.", "Ranged fighters knocking melee chasers back out of reach."],
	["earth", "fire", "Magma", "The tile the enemy ends its next turn on burns: 4 damage to anyone who ends a turn there until your next turn.", "Enemies that are Stunned, Pinned or stuck in a corridor."],
	["earth", "water", "Mire", "On its next turn, the enemy's first step off its tile costs +1 MP. Being pushed is free. Stacks with Bastion's Hold Line (+2 MP to leave).", "Melee fighters holding an enemy next to them."],
	["fire", "water", "Steam", "The enemy's tile blocks line of sight until your next turn. The enemy standing there can still be hit; once it moves, nobody can shoot through that tile.", "Blocking enemy archers and casters, covering a retreat."],
]

var font: Font
var selected: String = "kestrel"
var _hero: HeroProgress
var _wallet: KoliseoWallet
## The pick being edited (saved with Save): pair [a, b] and spell → element.
var _pair: Array = []
var _spells: Dictionary = {}
var _class_box: VBoxContainer
var _detail: VBoxContainer
var _header: Label
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hero = HeroProgress.load_saved()
	_wallet = KoliseoWallet.load_saved()
	_build()
	_load_pick()
	_refresh()


func hero() -> HeroProgress:
	return _hero


func wallet() -> KoliseoWallet:
	return _wallet


func status_text() -> String:
	return _status.text if _status != null else ""


func pick_class(class_id: String) -> void:
	if HeroProgress.GROWTH.has(class_id):
		selected = class_id
		if _status != null:
			_status.text = ""
		_load_pick()
		_refresh()


## Tap an element: on if fewer than two are on, off if it is on.
func toggle_element(el: String) -> void:
	if not SpellKits.ELEMENTS.has(el):
		return
	if _pair.has(el):
		_pair.erase(el)
	elif _pair.size() < 2:
		_pair.append(el)
	else:
		_status.text = "You already have 2. Tap one of them to take it off first."
		_refresh()
		return
	for id in _spells.keys():
		if not _pair.has(str(_spells[id])):
			_spells.erase(id)
	_status.text = ""
	_refresh()


func set_spell_element(spell_id: String, el: String) -> void:
	if _pair.has(el) and SpellKits.flex_spells(selected).has(spell_id):
		_spells[spell_id] = el
		_status.text = ""
		_refresh()


func save_pick() -> Dictionary:
	if _pair.size() != 2:
		_status.text = "Pick 2 elements first."
		_refresh()
		return {"ok": false, "reason": "pick_two", "cost": 0}
	var result := _hero.set_elements(selected, _pair, _spells, _wallet)
	if bool(result.get("ok", false)):
		_hero.save()
		if int(result.get("cost", 0)) > 0:
			_wallet.save()
		_status.text = "Saved. %s fights with %s." % [SpellKits.display_name(selected), _pair_text(_pair)]
		if int(result.get("cost", 0)) > 0:
			_status.text += " −%d trophies." % int(result["cost"])
		_load_pick()
	elif str(result.get("reason", "")) == "no_trophies":
		_status.text = "Changing your 2 elements costs %d trophies. You have %d. Win online Koliseo fights to earn trophies." % [int(result.get("cost", 0)), _wallet.trophies]
	else:
		_status.text = "Pick 2 different elements."
	_refresh()
	return result


func close() -> void:
	closed.emit()
	queue_free()


func _load_pick() -> void:
	var saved := _hero.elements_of(selected)
	_pair = (saved.get("pair", []) as Array).duplicate()
	_spells = (saved.get("spells", {}) as Dictionary).duplicate()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.74))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_top = 20
	panel.offset_right = -30
	panel.offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.09, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var top := HBoxContainer.new()
	_header = _label("", 20, GOLD_BRIGHT)
	_header.name = "ElementsHeader"
	_header.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	var close_button := _button("Close")
	close_button.name = "CloseElements"
	close_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.pressed.connect(close)
	top.add_child(close_button)
	body.add_child(top)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	_class_box = VBoxContainer.new()
	_class_box.add_theme_constant_override("separation", 6)
	_class_box.custom_minimum_size = Vector2(190, 0)
	cols.add_child(_class_box)
	var scroll := ScrollContainer.new()
	scroll.name = "ElementsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.name = "ElementsDetail"
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	_status = _label("", 14, GREEN)
	_status.name = "ElementsStatus"
	body.add_child(_status)


func _refresh() -> void:
	_header.text = "Elements     Trophies %d" % _wallet.trophies
	for box in [_class_box, _detail]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for class_id in SpellKits.LOCKED_ROSTER:
		var saved: Array = _hero.elements_of(class_id).get("pair", [])
		var b := _button("%s\n%s" % [SpellKits.display_name(class_id), _pair_text(saved) if saved.size() == 2 else "no elements yet"])
		b.name = "Class_" + class_id
		b.custom_minimum_size = Vector2(180, 56)
		if class_id == selected:
			var lit := StyleBoxFlat.new()
			lit.bg_color = Color(0.30, 0.24, 0.10)
			lit.border_color = GOLD_BRIGHT
			lit.set_border_width_all(2)
			lit.content_margin_left = 10
			b.add_theme_stylebox_override("normal", lit)
		b.pressed.connect(pick_class.bind(class_id))
		_class_box.add_child(b)

	_section("How elements work")
	_text("Pick 2 elements for %s. Each attack spell uses one of them, and every hit adds that element's effect. A hit also marks the enemy with your element (a gem on its ring). The mark fades if you go a whole turn without attacking that enemy. Hit that marked enemy with your OTHER element and the two mix into a Blend — a free extra effect. Example: Earth hit, then Water hit = Mire." % SpellKits.display_name(selected))
	_text("Only your own two hits make a Blend (Mender's heals are the exception, see below). One Blend per enemy until its next turn ends. Advance, Drop Shade, Fade, Cleanse, Plant and Snap Wall never take an element. Without a pick, your spells fight Neutral: no element effects, no Blends.", GOLD_DIM)
	_text("First pick is free. Changing your 2 elements costs %d trophies. Moving a spell between your 2 elements is free." % SpellKits.ELEMENT_CHANGE_TROPHIES, GOLD_DIM)

	_section("1. Pick 2 elements")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for el in SpellKits.ELEMENTS:
		var b := _button(el.capitalize())
		b.name = "Element_" + el
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(110, ROW_HEIGHT)
		_tint_button(b, el, _pair.has(el))
		b.pressed.connect(toggle_element.bind(el))
		row.add_child(b)
	_detail.add_child(row)
	for el in SpellKits.ELEMENTS:
		if _pair.has(el):
			_text("%s — %s" % [el.capitalize(), ELEMENT_TEXT[el]], TINT[el])

	_section("2. Set each attack spell")
	if _pair.size() != 2:
		_text("Pick 2 elements above, then choose which one each spell uses.", GOLD_DIM)
	else:
		for id in SpellKits.flex_spells(selected):
			var def := SpellKits.spell(str(id))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			var name_label := _label("%s (%d AP)" % [str(def.get("name", id)), int(def.get("ap", 0))], 15, GOLD_BRIGHT)
			name_label.custom_minimum_size = Vector2(170, 0)
			name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			line.add_child(name_label)
			var current := str(_spells.get(id, _pair[0]))
			for el in _pair:
				var b := _button(str(el).capitalize())
				b.name = "Spell_%s_%s" % [id, el]
				b.alignment = HORIZONTAL_ALIGNMENT_CENTER
				b.custom_minimum_size = Vector2(100, 44)
				_tint_button(b, str(el), current == el)
				b.pressed.connect(set_spell_element.bind(str(id), str(el)))
				line.add_child(b)
			_detail.add_child(line)
		var mine := _blend_row(_pair[0], _pair[1])
		_section("3. Your Blend: %s" % str(mine[2]))
		_text("%s hit, then %s hit (or the other way): %s" % [str(_pair[0]).capitalize(), str(_pair[1]).capitalize(), str(mine[3])], GREEN)
		_text("Good for: %s" % str(mine[4]), GOLD_DIM)
		var one_element := true
		for id in SpellKits.flex_spells(selected):
			if str(_spells.get(id, _pair[0])) != str(_spells.get(SpellKits.flex_spells(selected)[0], _pair[0])):
				one_element = false
		if one_element and selected != SpellKits.CLASS_MENDER:
			_text("All your spells use the same element, so you can never Blend. Set at least one spell to %s." % str(_pair[1] if str(_spells.get(SpellKits.flex_spells(selected)[0], _pair[0])) == str(_pair[0]) else _pair[0]).capitalize(), RED)
	if selected == SpellKits.CLASS_MENDER:
		_text("Mender: a heal on a teammate gives them the heal's element until the end of their next turn. Their next hit of another element fires that Blend at once (heal with Water, Ironjaw hits with Earth = Mire).", GREEN)
	var cost := _hero.element_change_cost(selected, _pair) if _pair.size() == 2 else 0
	var save := _button("Save (free)" if cost == 0 else "Save (%d trophies)" % cost)
	save.name = "SaveElements"
	save.alignment = HORIZONTAL_ALIGNMENT_CENTER
	save.custom_minimum_size = Vector2(220, ROW_HEIGHT)
	save.disabled = _pair.size() != 2
	save.pressed.connect(save_pick)
	_detail.add_child(save)

	_section("Guide: the 4 elements")
	for el in SpellKits.ELEMENTS:
		_text("%s — %s" % [el.capitalize(), ELEMENT_TEXT[el]], TINT[el])
	_section("Guide: the 6 Blends")
	for blend in BLEND_ROWS:
		var head := _label("%s + %s = %s" % [str(blend[0]).capitalize(), str(blend[1]).capitalize(), str(blend[2])], 16, TINT[str(blend[0])].lerp(TINT[str(blend[1])], 0.5))
		_detail.add_child(head)
		_text(str(blend[3]))
		_text("Good for: %s" % str(blend[4]), GOLD_DIM)


func _blend_row(a: String, b: String) -> Array:
	for row in BLEND_ROWS:
		if (row[0] == a and row[1] == b) or (row[0] == b and row[1] == a):
			return row
	return ["", "", "", "", ""]


static func _pair_text(pair: Array) -> String:
	if pair.size() != 2:
		return ""
	return "%s + %s" % [str(pair[0]).capitalize(), str(pair[1]).capitalize()]


func _section(text: String) -> void:
	var label := _label(text, 17, GOLD_BRIGHT)
	_detail.add_child(label)


func _text(text: String, tint: Color = GOLD) -> void:
	var label := _label(text, 14, tint)
	label.custom_minimum_size = Vector2(300, 0)
	_detail.add_child(label)


func _tint_button(b: Button, el: String, on: bool) -> void:
	var tint: Color = TINT[el]
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tint.darkened(0.35) if on else Color(0.03, 0.06, 0.12, 0.95)
		style.border_color = tint
		style.set_border_width_all(3 if on else 1)
		b.add_theme_stylebox_override(style_name, style)
	b.add_theme_color_override("font_color", Color.WHITE if on else tint)


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
	button.custom_minimum_size = Vector2(96, ROW_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", GOLD_DIM)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.06, 0.12, 0.95)
		style.border_color = GOLD_BRIGHT if style_name in ["hover", "focus"] else (GOLD_DIM if style_name == "disabled" else GOLD)
		style.set_border_width_all(1)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(style_name, style)
	return button
