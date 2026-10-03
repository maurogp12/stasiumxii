extends CanvasLayer

## Character panel of the window in spec 4.15. Key C toggles it.
## Numbers come from pc_progress.gd. This panel does not invent them.
## Loaded with preload. No global class.

const PORTRAIT := "res://art/characters/world/ironjaw/ironjaw_idle_s.png"

var progress = null
var _root: Control
var _body: RichTextLabel
var _details: Label
var _showing_details := false


func setup(hero) -> void:
	progress = hero
	if _body != null:
		refresh()


func open() -> void:
	if _root != null:
		_root.visible = true
	refresh()


func close() -> void:
	if _root != null:
		_root.visible = false


func toggle() -> void:
	if _root != null and _root.visible:
		close()
	else:
		open()


func _ready() -> void:
	ensure_built()


func refresh() -> void:
	ensure_built()
	_fill()


func ensure_built() -> void:
	if _root != null:
		return
	layer = 20
	_root = Control.new()
	_root.name = "CharacterPanel"
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.offset_left = 28
	panel.offset_top = 36
	panel.offset_right = 500
	panel.offset_bottom = 680
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(PORTRAIT):
		portrait.texture = load(PORTRAIT)
	header.add_child(portrait)
	var who := Label.new()
	who.text = "Hero\nIronjaw"
	who.add_theme_font_size_override("font_size", 22)
	who.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	header.add_child(who)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(420, 280)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	for stat in ["Mastery", "Vitality", "Swift", "Resist"]:
		var button := Button.new()
		button.text = "+ %s" % stat
		button.pressed.connect(_spend.bind(stat))
		actions.add_child(button)
	var respec := Button.new()
	respec.name = "Respec"
	respec.text = "Respec"
	respec.pressed.connect(_respec)
	box.add_child(respec)
	var details := Button.new()
	details.text = "Details"
	details.pressed.connect(_toggle_details)
	box.add_child(details)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.visible = false
	_details.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	box.add_child(_details)
	var hint := Label.new()
	hint.text = "C closes this panel"
	hint.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
	box.add_child(hint)
	_fill()


func _fill() -> void:
	if _body == null:
		return
	if progress == null or not progress.has_method("sheet_view"):
		_body.text = "No hero progress."
		return
	var view: Dictionary = progress.sheet_view()
	var lines: PackedStringArray = []
	lines.append("[b]Level %s[/b]" % str(view["level"]))
	if bool(view["at_cap"]):
		lines.append("XP %s  (cap)" % str(view["xp"]))
	else:
		lines.append("XP %s / %s" % [str(view["xp"]), str(view["xp_need"])])
	lines.append("HP %s    class HP per level: %s" % [str(view["hp"]), str(view["class_hp_per_level"])])
	var caps: Dictionary = view["caps"]
	lines.append("AP %s / %s    (milestones +%s)" % [
		str(view["ap"]), str(caps.get("ap", "Open")), str(view["ap_from_milestones"]),
	])
	lines.append("MP %s / %s" % [str(view["mp"]), str(caps.get("mp", "Open"))])
	lines.append("Initiative %s" % str(view["initiative"]))
	lines.append("Range bonus %s / %s" % [str(view["range_bonus"]), str(caps.get("range_bonus", "Open"))])
	lines.append("")
	lines.append("[b]Free points %s[/b]" % str(view["points_free"]))
	for row in view["stats"]:
		lines.append("%s  %s    per point: %s" % [str(row["name"]), str(row["spent"]), str(row["per_point"])])
	var cost: Variant = view["respec_cost"]
	if int(view["respecs_used"]) < int(view["free_respecs"]):
		lines.append("Respec: free (%s left)" % str(int(view["free_respecs"]) - int(view["respecs_used"])))
	else:
		lines.append("Respec cost: %s" % str(cost))
	_body.text = "\n".join(lines)
	var title_bits: PackedStringArray = []
	for row in view["titles"]:
		title_bits.append("%s %s" % [str(row["level"]), str(row["name"])])
	var earned := "none yet" if title_bits.is_empty() else ", ".join(title_bits)
	_details.text = "Titles: %s\nResistances: Open\nHealing bonus: Open\nSet and item effects: Open" % earned


func _spend(stat: String) -> void:
	if progress != null and progress.has_method("spend"):
		progress.spend(stat, 1)
	refresh()


func _respec() -> void:
	if progress != null and progress.has_method("respec"):
		progress.respec()
	refresh()


func _toggle_details() -> void:
	_showing_details = not _showing_details
	if _details != null:
		_details.visible = _showing_details


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.09, 0.13, 0.94)
	style.border_color = Color(0.93, 0.76, 0.38)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
