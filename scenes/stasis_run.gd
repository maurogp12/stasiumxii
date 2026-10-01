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
var _star_buttons: Array[Button] = []
var _star_info: Label
## Dungeon finder (Mauro 1 Oct 2026). Roles: Tank = Bastion, Healer = Mender,
## DPS = Kestrel / Ironjaw / Gloam. Any class mix is allowed; a role is what
## an empty seat requests. "Fill with AI" is only the fallback when no player
## is found (online search arrives with online parties).
const ROLES: Array[String] = ["Tank", "Healer", "DPS", "Any"]
const ROLE_OF := {"bastion": "Tank", "mender": "Healer", "kestrel": "DPS", "ironjaw": "DPS", "gloam": "DPS"}
var _party_box: VBoxContainer
var _slot_roles: Array[String] = []
var _slot_classes: Array[String] = []
var _picked_class := ""


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


## Difficulty (Mauro 29 Sep 2026: "every star should be a lvl of difficult").
func pick_star(value: int) -> void:
	StasisCatalog.set_star(value)
	_sync_stars()
	if _party_box != null:
		_party_box.visible = false
	_slot_roles.clear()
	_slot_classes.clear()


func star_info_text() -> String:
	return _star_info.text if _star_info != null else ""


func star_button_count() -> int:
	return _star_buttons.size()


static func star_summary(for_star: int) -> String:
	var fams: Array[String] = []
	for fam in GearBag.FAMILY_ORDER:
		if int(GearBag.FAMILIES[fam]["min_star"]) <= for_star:
			fams.append(str(GearBag.FAMILIES[fam]["name"]))
	var frags := int(StillVault.CHEST_FRAGMENTS.get(for_star, 1))
	var players := StasisCatalog.party_for_star(for_star)
	return "%s — for %s · foes x%.1f HP, x%.2f damage (trash %d HP, boss %d HP)\nChest: %s · %d Still fragment%s · %d XP" % [
		StasisCatalog.star_label(for_star),
		"1 player" if players == 1 else "a party of %d" % players,
		StasisCatalog.hp_mult(for_star),
		StasisCatalog.dmg_mult(for_star),
		StasisCatalog.scaled_hp(StasisCatalog.PROVISIONAL_TRASH_HP, for_star),
		StasisCatalog.scaled_hp(StasisCatalog.PROVISIONAL_BOSS_HP, for_star),
		", ".join(fams),
		frags,
		"" if frags == 1 else "s",
		HeroProgress.stasis_xp(for_star, true),
	]


func _sync_stars() -> void:
	for i in _star_buttons.size():
		var on := i + 1 == StasisCatalog.star
		var b := _star_buttons[i]
		b.add_theme_stylebox_override("normal", _star_style(on, i + 1))
		b.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4) if on else Color(0.8, 0.74, 0.62))
	if _star_info != null:
		_star_info.text = star_summary(StasisCatalog.star)


func _star_style(on: bool, value: int) -> StyleBoxFlat:
	var heat := float(value - 1) / 4.0
	var style := _style(on)
	style.bg_color = Color(0.14, 0.18, 0.22).lerp(Color(0.34, 0.12, 0.1), heat * 0.8)
	if on:
		style.border_color = Color(1.0, 0.82, 0.36)
		style.set_border_width_all(3)
	return style


func pick_class(class_id: String) -> bool:
	var id := SpellKits.normalize_class_id(class_id)
	if not MobileHub.is_biome_id(StasisCatalog.biome_id):
		return false
	if not SpellKits.is_roster_class(id):
		return false
	StasisCatalog.class_id = id
	_picked_class = id
	var size := StasisCatalog.party_for_star(StasisCatalog.star)
	if size <= 1:
		StasisCatalog.clear_run_party()
		_launch()
		return true
	# ★2+: open the party finder for the other seats.
	_slot_roles.clear()
	_slot_classes.clear()
	for i in size - 1:
		_slot_roles.append(_default_role(i))
		_slot_classes.append("")
	_show_party()
	return true


func _launch() -> void:
	if not _auto_launch:
		return
	get_tree().change_scene_to_file(StasisCatalog.FIGHT_SCENE)


## The role an empty seat asks for first: the full party is Healer, Tank,
## DPS, DPS; the player's own role is taken out once.
func _default_role(slot: int) -> String:
	var missing: Array = ["Healer", "Tank", "DPS", "DPS"]
	missing.erase(str(ROLE_OF.get(_picked_class, "DPS")))
	return str(missing[slot]) if slot < missing.size() else "Any"


func party_slot_count() -> int:
	return _slot_roles.size()


func slot_role(slot: int) -> String:
	return _slot_roles[slot] if slot >= 0 and slot < _slot_roles.size() else ""


func slot_class(slot: int) -> String:
	return _slot_classes[slot] if slot >= 0 and slot < _slot_classes.size() else ""


## Request only this role for an empty seat (Tank → Healer → DPS → Any).
func request_role(slot: int, role: String = "") -> void:
	if slot < 0 or slot >= _slot_roles.size():
		return
	if role == "":
		role = ROLES[(ROLES.find(_slot_roles[slot]) + 1) % ROLES.size()]
	if ROLES.has(role):
		_slot_roles[slot] = role
		_slot_classes[slot] = ""
	_show_party()


## Fallback when no player is found: an AI companion plays that role.
func fill_with_ai(slot: int) -> void:
	if slot < 0 or slot >= _slot_roles.size():
		return
	_slot_classes[slot] = _ai_class_for(_slot_roles[slot])
	_show_party()


func _ai_class_for(role: String) -> String:
	var in_party: Array = [_picked_class]
	for c in _slot_classes:
		if c != "":
			in_party.append(c)
	match role:
		"Tank":
			return "bastion"
		"Healer":
			return "mender"
		"DPS":
			for c in ["kestrel", "ironjaw", "gloam"]:
				if not in_party.has(c):
					return c
			return "kestrel"
	# Any: the role the party lacks most.
	if not in_party.has("mender"):
		return "mender"
	if not in_party.has("bastion"):
		return "bastion"
	return _ai_class_for("DPS")


## Enter with the filled seats; empty seats stay empty (short-handed — the
## dungeon is tuned for the full party, so it is brutal).
func enter_dungeon() -> void:
	var classes: Array = [_picked_class]
	var ai: Array = []
	for c in _slot_classes:
		if c != "":
			ai.append(classes.size())
			classes.append(c)
	if classes.size() > 1:
		StasisCatalog.set_party(classes, ai)
	else:
		StasisCatalog.clear_run_party()
	_launch()


func _show_party() -> void:
	if _party_box == null:
		return
	for child in _party_box.get_children():
		child.queue_free()
	var size := _slot_roles.size() + 1
	var filled := 1
	for c in _slot_classes:
		if c != "":
			filled += 1
	_label(_party_box, "Party %d / %d — %s is tuned for %d players" % [filled, size, StasisCatalog.star_label(StasisCatalog.star), size], 18, Color(0.95, 0.9, 0.82))
	_label(_party_box, "You: %s (%s)" % [SpellKits.display_name(_picked_class), str(ROLE_OF.get(_picked_class, "DPS"))], 16, Color(0.72, 0.9, 0.78))
	for i in _slot_roles.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_party_box.add_child(row)
		var status := "AI %s" % SpellKits.display_name(_slot_classes[i]) if _slot_classes[i] != "" else "No player found"
		var info := _label(row, "Seat %d · looking for %s · %s" % [i + 2, _slot_roles[i], status], 15, Color(0.86, 0.82, 0.74))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_small_button("Request: %s" % _slot_roles[i], request_role.bind(i, "")))
		if _slot_classes[i] == "":
			row.add_child(_small_button("Fill with AI", fill_with_ai.bind(i)))
	_label(_party_box, "Online player search for these roles arrives with online parties. Until then, fill with AI or go in short-handed (brutal).", 13, Color(0.7, 0.66, 0.5))
	_party_box.add_child(_small_button("Enter dungeon", enter_dungeon))
	_party_box.visible = true


func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	b.add_theme_stylebox_override("normal", _style(false))
	b.add_theme_stylebox_override("hover", _style(true))
	b.add_theme_stylebox_override("pressed", _style(true))
	b.pressed.connect(action)
	return b


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
	_note = _label(col, "Foe numbers are provisional for playtest (★1: trash %d HP / base %d, boss %d HP / base %d; higher stars scale up). Your class keeps its Locked kit." % [
		StasisCatalog.PROVISIONAL_TRASH_HP,
		StasisCatalog.PROVISIONAL_TRASH_ATTACK,
		StasisCatalog.PROVISIONAL_BOSS_HP,
		StasisCatalog.PROVISIONAL_BOSS_ATTACK,
	], 13, Color(0.7, 0.66, 0.5))
	_label(col, "Difficulty", 18, Color(0.95, 0.9, 0.82))
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 8)
	col.add_child(stars)
	for value in range(1, StasisCatalog.MAX_STAR + 1):
		var sb := Button.new()
		sb.name = "Star_%d" % value
		sb.text = "★".repeat(value)
		sb.custom_minimum_size = Vector2(0, 56)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.focus_mode = Control.FOCUS_ALL
		sb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sb.add_theme_font_size_override("font_size", 18)
		sb.add_theme_stylebox_override("hover", _style(true))
		sb.add_theme_stylebox_override("pressed", _style(true))
		sb.pressed.connect(pick_star.bind(value))
		stars.add_child(sb)
		_star_buttons.append(sb)
	_star_info = _label(col, "", 15, Color(0.9, 0.82, 0.5))
	_star_info.name = "StarInfo"
	_sync_stars()
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 6)
	_party_box.visible = false
	col.add_child(_party_box)
	var prompt := _label(col, "Pick your class (your role)", 18, Color(0.95, 0.9, 0.82))
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
