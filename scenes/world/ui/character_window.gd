extends CanvasLayer

## Character panel of the window in spec 4.15. Key C toggles it.
## Numbers come from pc_progress.gd. This panel does not invent them.
## Loaded with preload. No global class.

const Painted := preload("res://units/painted_looks.gd")
const Gear := preload("res://backend/pc_gear.gd")

var _portrait: TextureRect
var _who: Label
var _portrait_class := ""

var progress = null
var _root: Control
var _body: RichTextLabel
var _details: Label
var _showing_details := false
## Worn gear: the five gear slots with their +, gear stats, set bonuses, and
## a Fuse button per worn piece that has a partner (mobile gear screen).
var _gear_box: VBoxContainer


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
	_sync_portrait()
	_fill()


## The hero's class: painted idle, front view, first cell. Ironjaw until a
## class is picked (the world's default hero).
func _sync_portrait() -> void:
	var cls := str(progress.hero_class) if progress != null else ""
	if not Painted.has_class(cls):
		cls = "ironjaw"
	if cls == _portrait_class or _portrait == null:
		return
	_portrait_class = cls
	var sheet := Painted.sheet(cls, "idle", "S")
	var cell := Painted.cell_of(cls, "idle")
	if sheet != null:
		var first := AtlasTexture.new()
		first.atlas = sheet
		first.region = Rect2(Vector2.ZERO, Vector2(cell))
		_portrait.texture = first
	_who.text = "Hero\n%s" % cls.capitalize()


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
	panel.offset_bottom = 860
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
	header.add_child(portrait)
	_portrait = portrait
	var who := Label.new()
	who.text = "Hero\nIronjaw"
	who.add_theme_font_size_override("font_size", 22)
	who.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	header.add_child(who)
	_who = who
	_sync_portrait()
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(420, 280)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)
	_gear_box = VBoxContainer.new()
	_gear_box.name = "GearBox"
	_gear_box.add_theme_constant_override("separation", 2)
	box.add_child(_gear_box)
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
	lines.append("HP %s    (base %s, class HP per level: %s)" % [str(view.get("hp_max", view["hp"])), str(view["hp"]), str(view["class_hp_per_level"])])
	var caps: Dictionary = view["caps"]
	lines.append("AP %s / %s    (milestones +%s)" % [
		str(view["ap"]), str(caps.get("ap", "Open")), str(view["ap_from_milestones"]),
	])
	lines.append("MP %s / %s" % [str(view["mp"]), str(caps.get("mp", "Open"))])
	lines.append("Initiative %s    Swift +%s" % [str(view["initiative"]), str(view.get("initiative_from_swift", 0))])
	lines.append("Range bonus %s / %s" % [str(view["range_bonus"]), str(caps.get("range_bonus", "Open"))])
	lines.append("")
	lines.append("[b]Free points %s[/b]" % str(view["points_free"]))
	lines.append("Crypto Coins %s" % str(view.get("coins", 0)))
	for row in view["stats"]:
		lines.append("%s  %s    per point: %s" % [str(row["name"]), str(row["spent"]), _point_label(row["per_point"])])
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
	var effects := "Open"
	if view.has("gear"):
		effects = _gear_line(view["gear"])
	_details.text = "Titles: %s\nResistances: Open\nHealing bonus: Open\nSet and item effects: %s" % [earned, effects]
	_fill_gear(view.get("gear", {}))


func _fill_gear(gear: Dictionary) -> void:
	if _gear_box == null:
		return
	for child in _gear_box.get_children():
		_gear_box.remove_child(child)
		child.queue_free()
	var head := Label.new()
	head.text = "Gear"
	head.add_theme_color_override("font_color", Color(0.93, 0.76, 0.38))
	_gear_box.add_child(head)
	for slot in Gear.SLOTS:
		var row := HBoxContainer.new()
		row.name = "Slot_%s" % slot
		_gear_box.add_child(row)
		var label := Label.new()
		label.custom_minimum_size = Vector2(330, 0)
		label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
		var inst: Dictionary = progress.equipped.get(slot, {}) if progress != null else {}
		var item_id := str(inst.get("item_id", ""))
		if Gear.is_valid_item_id(item_id):
			label.text = "%s: %s" % [slot.capitalize(), Gear.item_label(item_id, int(inst.get("plus", 0)))]
			label.tooltip_text = Gear.part_line(item_id, int(inst.get("plus", 0)))
			label.mouse_filter = Control.MOUSE_FILTER_PASS
		elif item_id != "":
			label.text = "%s: %s" % [slot.capitalize(), str(progress.item_def(item_id).get("name", item_id))]
		else:
			label.text = "%s: empty" % slot.capitalize()
		row.add_child(label)
		if Gear.is_valid_item_id(item_id) and progress.has_method("fuse_partner"):
			var fuse := Button.new()
			fuse.name = "Fuse_%s" % slot
			fuse.text = "Fuse"
			var uid := int(inst.get("uid", -1))
			fuse.disabled = progress.fuse_partner(uid) == -1 or int(inst.get("plus", 0)) >= Gear.PLUS_CAP
			fuse.tooltip_text = "Needs another %s +%d in the bag." % [Gear.part_name(item_id), int(inst.get("plus", 0))]
			fuse.pressed.connect(_fuse.bind(uid))
			row.add_child(fuse)
	var stats: Dictionary = gear.get("stats", {})
	var bits: PackedStringArray = []
	for key in ["HP", "HP %", "Mastery", "Resist", "Init", "Crit %"]:
		if int(stats.get(key, 0)) != 0:
			bits.append("%s +%d" % [key, int(stats[key])])
	var line := Label.new()
	line.name = "GearStats"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78))
	line.text = "Gear: %s" % ("none" if bits.is_empty() else ", ".join(bits))
	_gear_box.add_child(line)
	for set_row in gear.get("sets", []):
		var set_label := Label.new()
		set_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		set_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))
		var tiers: PackedStringArray = []
		for tier_row in set_row.get("bonuses", []):
			tiers.append("%dpc %s" % [int(tier_row["tier"]), str(tier_row["text"])])
		set_label.text = "%s %d/5%s" % [str(set_row.get("name", "")), int(set_row.get("count", 0)), "" if tiers.is_empty() else ": " + "; ".join(tiers)]
		_gear_box.add_child(set_label)


func _fuse(uid: int) -> void:
	if progress != null and progress.has_method("fuse_uid"):
		progress.fuse_uid(uid)
	refresh()


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


func _gear_line(gear: Dictionary) -> String:
	var stats: Dictionary = gear.get("stats", {})
	var bits: PackedStringArray = []
	for stat in ["HP", "HP %", "Mastery", "Resist", "Init", "Crit %"]:
		if int(stats.get(stat, 0)) != 0:
			bits.append("%s +%d" % [stat, int(stats[stat])])
	if int(gear.get("ap", 0)) != 0:
		bits.append("AP +%d" % int(gear["ap"]))
	if int(gear.get("mp", 0)) != 0:
		bits.append("MP +%d" % int(gear["mp"]))
	if bits.is_empty():
		return "none"
	return ", ".join(bits)


func _point_label(value: Variant) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return str(value)
	var doc: Dictionary = value
	var bits: PackedStringArray = []
	if doc.has("damage_done"):
		bits.append("%s damage and healing" % _percent(doc["damage_done"]))
	if doc.has("max_hp"):
		bits.append("%s of base max HP" % _percent(doc["max_hp"]))
	if doc.has("damage_taken"):
		var cap := ""
		if doc.has("cap"):
			cap = ", cap %s" % _percent(doc["cap"]).trim_prefix("+")
		bits.append("%s less damage taken%s" % [_percent(doc["damage_taken"]), cap])
	if doc.has("initiative"):
		bits.append("+%s Initiative" % str(doc["initiative"]))
	if doc.has("bonus_damage"):
		bits.append("%s damage" % _percent(doc["bonus_damage"]))
	if bits.is_empty():
		return str(value)
	return ", ".join(bits)


func _percent(value: Variant) -> String:
	return "+%.3f%%" % (float(value) * 100.0)


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
