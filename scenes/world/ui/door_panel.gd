extends CanvasLayer

## Dungeon entry panel: opened by clicking a dungeon hatch or talking to its
## Door Keeper. Shows the name, level band, boss, party size and the hero's
## level check, with Enter and Leave. Runs are solo for now (party 1-4 is the
## rule; grouping is not built), and the panel says so.

const Run := preload("res://backend/pc_dungeon_run.gd")

signal enter_requested(dungeon_id: String)
signal closed(dungeon_id: String)

## Star picker (mirrors the mobile Stasis stars): the player picks ★1-★5 per
## run, every star open from the start as on mobile. The best star cleared
## is shown.
const STAR_NOTES := {
	1: "Normal set parts.",
	2: "Tougher monsters. More XP and coins.",
	3: "Bigger pack. Rare parts can drop.",
	4: "Tougher still. Mystery Boxes can drop.",
	5: "The Radioactive Ratking. A Rare part and a Mystery Box for sure.",
}

var dungeon_id := ""
var check: Dictionary = {}
var selected_star := 1
var best_star := 0
var star_buttons: Array[Button] = []
var _star_note: Label
var enter_button: Button
var leave_button: Button
var _root: Control
var _title: Label
var _body: RichTextLabel
var _check_label: Label


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _root != null:
		return
	layer = 42
	_root = Control.new()
	_root.name = "DoorPanel"
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var card := PanelContainer.new()
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -250
	card.offset_right = 250
	card.offset_top = -230
	card.offset_bottom = 230
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.5))
	col.add_child(_title)
	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(440, 110)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_size_override("normal_font_size", 17)
	col.add_child(_body)
	var stars := HBoxContainer.new()
	stars.name = "Stars"
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 8)
	col.add_child(stars)
	for n in range(1, 6):
		var b := Button.new()
		b.name = "Star%d" % n
		b.text = "★%d" % n
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(70, 40)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(select_star.bind(n))
		stars.add_child(b)
		star_buttons.append(b)
	_star_note = Label.new()
	_star_note.name = "StarNote"
	_star_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_star_note.add_theme_font_size_override("font_size", 15)
	_star_note.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	col.add_child(_star_note)
	_check_label = Label.new()
	_check_label.name = "LevelCheck"
	_check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_check_label.add_theme_font_size_override("font_size", 17)
	col.add_child(_check_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	enter_button = _button("Enter", Color(0.36, 0.55, 0.26))
	enter_button.name = "Enter"
	enter_button.pressed.connect(_on_enter)
	row.add_child(enter_button)
	leave_button = _button("Leave", Color(0.42, 0.3, 0.24))
	leave_button.name = "Leave"
	leave_button.pressed.connect(close)
	row.add_child(leave_button)


func select_star(n: int) -> void:
	selected_star = clampi(n, 1, 5)
	for i in star_buttons.size():
		star_buttons[i].button_pressed = i + 1 == selected_star
		star_buttons[i].modulate = Color(1.0, 0.86, 0.4) if i + 1 == selected_star else Color(0.85, 0.85, 0.85)
	var best_text := "  Best cleared: ★%d." % best_star if best_star > 0 else ""
	if _star_note != null:
		_star_note.text = "★%d: %s%s" % [selected_star, STAR_NOTES.get(selected_star, ""), best_text]


func open_for(row: Dictionary, hero_level: int, keeper_line: String = "", best: int = 0) -> void:
	ensure_built()
	best_star = best
	dungeon_id = str(row.get("id", ""))
	check = Run.entry_check(row, hero_level, 1)
	_title.text = str(row.get("name", "Dungeon"))
	var party: Dictionary = row.get("party", {})
	var lines: PackedStringArray = []
	if keeper_line != "":
		lines.append("[i]\"%s\"[/i]" % keeper_line)
	lines.append("Levels [b]%d–%d[/b]" % [int(row.get("level_min", 1)), int(row.get("level_max", 1))])
	lines.append("Boss: [b]%s[/b]   ·   Rooms: %d" % [str(row.get("boss", "?")), int(row.get("rooms", 2))])
	lines.append("Party %d–%d. [color=#d9c79a]Solo for now: grouping is not built yet.[/color]" % [int(party.get("min", 1)), int(party.get("max", 4))])
	_body.text = "\n".join(lines)
	var ok := bool(check.get("ok", false))
	_check_label.text = str(check.get("text", ""))
	_check_label.add_theme_color_override("font_color", Color(0.6, 0.92, 0.5) if ok else Color(1.0, 0.45, 0.38))
	enter_button.disabled = not ok
	select_star(selected_star)
	_root.visible = true


func is_open() -> bool:
	return _root != null and _root.visible


func close() -> void:
	if _root == null or not _root.visible:
		return
	_root.visible = false
	closed.emit(dungeon_id)


func press_enter() -> void:
	_on_enter()


func _on_enter() -> void:
	if not is_open() or enter_button.disabled:
		return
	var id := dungeon_id
	_root.visible = false
	enter_requested.emit(id)


func _button(text: String, tint: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 46)
	b.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = tint
	normal.set_corner_radius_all(10)
	normal.border_color = Color(0.95, 0.8, 0.45)
	normal.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.18)
	b.add_theme_stylebox_override("hover", hover)
	var dis := normal.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.3, 0.28, 0.27)
	b.add_theme_stylebox_override("disabled", dis)
	return b


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.08, 0.96)
	style.border_color = Color(0.93, 0.76, 0.38)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style
