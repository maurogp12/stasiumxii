extends CanvasLayer

## Equipment and inventory panels (spec 4.15). Key I toggles this window.
## Numbers come from pc_progress.gd and pc_rewards.gd. This window does not
## invent them. Loaded with preload. No global class.

const TABS: Array[String] = [
	"equipment", "consumable", "material", "recipe", "decoration", "special",
]
const TAB_LABEL: Array[String] = [
	"Equipment", "Consumables", "Materials", "Recipes", "Decorations", "Boxes",
]
const SLOT_LABEL := {
	"head": "Head",
	"amulet": "Amulet",
	"ring": "Ring",
	"ring_b": "Ring",
	"cape": "Cape",
	"belt": "Belt",
	"boots": "Boots",
	"weapon": "Weapon",
}

var progress = null
var _root: Control
var _slots: VBoxContainer
var _set_strip: Label
var _epic: Label
var _relic: Label
var _grid: GridContainer
var _card: Label
var _coins: Label
var _slots_label: Label
var _weight: ProgressBar
var _bank: Button
var _search: LineEdit
var _filter: OptionButton
var _category := "equipment"
var _selected := -1
var _confirm := false
var _at_bank := false


func setup(hero) -> void:
	progress = hero
	if _root != null:
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


func set_at_bank(near: bool) -> void:
	_at_bank = near
	if _bank != null:
		_bank.disabled = not near
		_bank.text = "Bank" if near else "Bank (Crossroads)"


func _ready() -> void:
	ensure_built()


func refresh() -> void:
	ensure_built()
	_fill()


func ensure_built() -> void:
	if _root != null:
		return
	layer = 21
	_root = Control.new()
	_root.name = "InventoryPanel"
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_right = -24
	panel.offset_bottom = -24
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	panel.add_child(columns)
	_slots = VBoxContainer.new()
	_slots.name = "Slots"
	_slots.custom_minimum_size = Vector2(220, 0)
	columns.add_child(_slots)
	var middle := VBoxContainer.new()
	middle.custom_minimum_size = Vector2(280, 0)
	columns.add_child(middle)
	_set_strip = Label.new()
	_set_strip.name = "SetStrip"
	_set_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_strip.custom_minimum_size = Vector2(260, 120)
	middle.add_child(_set_strip)
	_epic = Label.new()
	_epic.name = "EpicBadge"
	middle.add_child(_epic)
	_relic = Label.new()
	_relic.name = "RelicBadge"
	middle.add_child(_relic)
	_card = Label.new()
	_card.name = "ItemCard"
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.custom_minimum_size = Vector2(260, 160)
	middle.add_child(_card)
	var actions := HBoxContainer.new()
	middle.add_child(actions)
	var equip := Button.new()
	equip.name = "EquipButton"
	equip.text = "Equip"
	equip.pressed.connect(_equip_selected)
	actions.add_child(equip)
	var open_box := Button.new()
	open_box.name = "OpenButton"
	open_box.text = "Open"
	open_box.pressed.connect(_open_selected)
	actions.add_child(open_box)
	var unequip := Button.new()
	unequip.name = "UnequipButton"
	unequip.text = "Unequip"
	unequip.pressed.connect(_unequip_selected)
	actions.add_child(unequip)
	for label in ["Upgrade", "Sell", "List"]:
		var later := Button.new()
		later.text = label
		later.disabled = true
		later.tooltip_text = "Not built yet"
		actions.add_child(later)
	var destroy := Button.new()
	destroy.name = "DestroyButton"
	destroy.text = "Destroy"
	destroy.pressed.connect(_destroy_selected)
	actions.add_child(destroy)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.name = "CategoryTabs"
	right.add_child(tabs)
	for i in TABS.size():
		var tab := Button.new()
		tab.text = TAB_LABEL[i]
		tab.pressed.connect(_set_category.bind(TABS[i]))
		tabs.add_child(tab)
	var tools := HBoxContainer.new()
	right.add_child(tools)
	_filter = OptionButton.new()
	_filter.name = "RarityFilter"
	_filter.add_item("Any rarity")
	_filter.add_item("Regular")
	_filter.add_item("Rare")
	_filter.add_item("Epic")
	_filter.add_item("Relic")
	_filter.item_selected.connect(func(_i): refresh())
	tools.add_child(_filter)
	_search = LineEdit.new()
	_search.name = "SearchBox"
	_search.placeholder_text = "Search"
	_search.custom_minimum_size = Vector2(180, 0)
	_search.text_changed.connect(func(_t): refresh())
	tools.add_child(_search)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 4
	right.add_child(_grid)
	_slots_label = Label.new()
	_slots_label.name = "SlotLabel"
	right.add_child(_slots_label)
	_weight = ProgressBar.new()
	_weight.name = "WeightBar"
	_weight.custom_minimum_size = Vector2(280, 18)
	_weight.show_percentage = false
	right.add_child(_weight)
	var footer := HBoxContainer.new()
	right.add_child(footer)
	_coins = Label.new()
	_coins.name = "CoinLabel"
	footer.add_child(_coins)
	_bank = Button.new()
	_bank.name = "BankButton"
	_bank.text = "Bank (Crossroads)"
	_bank.disabled = true
	_bank.pressed.connect(_deposit_selected)
	footer.add_child(_bank)
	var hint := Label.new()
	hint.text = "I closes this panel"
	right.add_child(hint)


func show_category(category: String) -> void:
	_category = category
	refresh()


func open_first_box(rng: RandomNumberGenerator) -> Dictionary:
	if progress == null or not progress.has_method("open_mystery_box"):
		return {"ok": false, "reason": "no hero"}
	var result: Dictionary = progress.open_mystery_box(rng)
	_confirm = false
	_selected = -1
	refresh()
	if bool(result.get("ok", false)):
		_card.text = "Opened a Mystery Box.\n%s" % _reward_line(result.get("reward", {}))
	return result


func _fill() -> void:
	if _slots == null or progress == null:
		return
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.free()
	var view: Dictionary = {}
	if progress.has_method("sheet_view"):
		view = progress.sheet_view()
	var gear: Dictionary = view.get("gear", {})
	for slot in ["head", "amulet", "ring", "ring_b", "cape", "belt", "boots", "weapon"]:
		var button := Button.new()
		button.text = "%s: %s" % [str(SLOT_LABEL[slot]), _slot_text(slot)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_slot.bind(slot))
		_slots.add_child(button)
	var set_lines: PackedStringArray = ["[sets]"]
	var rows: Array = gear.get("sets", [])
	if rows.is_empty():
		set_lines.append("No set bonus yet")
	for row in rows:
		var set_row: Dictionary = row
		set_lines.append("%s %d/5" % [str(set_row.get("name", "")), int(set_row.get("count", 0))])
		if int(set_row.get("count", 0)) >= 5:
			set_lines.append(str(set_row.get("five_text", "")))
			set_lines.append("Five-part effect: not in play")
	_set_strip.text = "\n".join(set_lines)
	var epic_name := str(gear.get("epic", ""))
	var relic_name := str(gear.get("relic", ""))
	_epic.text = "Epic: %s" % ("none" if epic_name == "" else epic_name)
	_epic.add_theme_color_override("font_color", Color(0.72, 0.45, 0.95))
	_relic.text = "Relic: %s" % ("none" if relic_name == "" else relic_name)
	_relic.add_theme_color_override("font_color", Color(0.93, 0.76, 0.38))
	_coins.text = "Crypto Coins %s" % str(view.get("coins", 0))
	var used := int(view.get("bag_slots_used", progress.bag.size()))
	var cap := int(view.get("bag_slots", progress.bag_slots))
	_slots_label.text = "Slots %d / %d" % [used, cap]
	var weight := int(view.get("weight", 0))
	var weight_max := maxi(int(view.get("weight_max", 1)), 1)
	_weight.max_value = weight_max
	_weight.value = weight
	_bank.disabled = not _at_bank
	_rebuild_grid()
	if _card.text == "":
		_card.text = "Select an item"


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.free()
	var want := _filter_rarity()
	var query := ""
	if _search != null:
		query = _search.text.to_lower()
	for entry in progress.bag:
		var row: Dictionary = entry
		var def: Dictionary = progress.item_def(str(row.get("item_id", "")))
		if str(def.get("category", "")) != _category:
			continue
		var rarity := str(row.get("rarity", "regular"))
		if str(def.get("rarity", "")) != "":
			rarity = str(def.get("rarity", ""))
		if want != "" and rarity != want:
			continue
		var name := str(def.get("name", row.get("item_id", "")))
		if query != "" and name.to_lower().find(query) < 0:
			continue
		var button := Button.new()
		var count := int(row.get("count", 1))
		button.text = name if count == 1 else "%s x%d" % [name, count]
		button.add_theme_stylebox_override("normal", _rarity_style(rarity))
		var uid := int(row.get("uid", -1))
		button.pressed.connect(_select_uid.bind(uid))
		button.gui_input.connect(_item_click.bind(uid))
		_grid.add_child(button)


func _filter_rarity() -> String:
	if _filter == null:
		return ""
	match _filter.selected:
		1:
			return "regular"
		2:
			return "rare"
		3:
			return "epic"
		4:
			return "relic"
		_:
			return ""


func _set_category(category: String) -> void:
	_category = category
	_selected = -1
	_confirm = false
	refresh()


func _select_uid(uid: int) -> void:
	_selected = uid
	_confirm = false
	_show_card(uid)


func _select_slot(slot: String) -> void:
	if progress == null or not progress.equipped.has(slot):
		_card.text = "%s is empty" % str(SLOT_LABEL[slot])
		_selected = -1
		return
	var inst: Dictionary = progress.equipped[slot]
	_selected = int(inst.get("uid", -1))
	_show_card_def(str(inst.get("item_id", "")), str(inst.get("rarity", "regular")), 1, true)


func _show_card(uid: int) -> void:
	for entry in progress.bag:
		var row: Dictionary = entry
		if int(row.get("uid", -1)) == uid:
			_show_card_def(str(row.get("item_id", "")), str(row.get("rarity", "regular")), int(row.get("count", 1)), false)
			return


func _show_card_def(item_id: String, rarity: String, count: int, worn: bool) -> void:
	var def: Dictionary = progress.item_def(item_id)
	var name := str(def.get("name", item_id))
	var lines: PackedStringArray = [name, "Rarity %s" % rarity]
	if int(def.get("min_level", 0)) > 0:
		lines.append("Level %s" % str(def.get("min_level", "")))
	lines.append("Upgrade +0")
	var stats: Dictionary = {}
	if typeof(def.get("stats", null)) == TYPE_DICTIONARY:
		var table: Dictionary = def["stats"]
		if typeof(table.get(rarity, null)) == TYPE_DICTIONARY:
			stats = table[rarity]
	if not stats.is_empty():
		var bits: PackedStringArray = []
		for stat in stats.keys():
			bits.append("%s +%s" % [str(stat), str(stats[stat])])
		lines.append(", ".join(bits))
	var effect: Dictionary = def.get("effect", {})
	if str(effect.get("text", "")) != "":
		lines.append(str(effect["text"]))
		lines.append("Effect: not in play")
	if str(def.get("set_id", "")) != "":
		lines.append("Set %s" % str(def["set_id"]))
	lines.append("In the bag x%s" % str(count) if not worn else "Worn")
	_card.text = "\n".join(lines)


func _equip_selected() -> void:
	if progress == null or _selected < 0:
		return
	progress.equip_uid(_selected)
	_confirm = false
	refresh()


func _unequip_selected() -> void:
	if progress == null:
		return
	for slot in progress.equipped.keys():
		var inst: Dictionary = progress.equipped[slot]
		if int(inst.get("uid", -1)) == _selected:
			progress.unequip(str(slot))
			break
	_confirm = false
	refresh()


func _open_selected() -> void:
	if progress == null or _selected < 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary = progress.open_mystery_box(rng)
	refresh()
	if bool(result.get("ok", false)):
		_card.text = "Opened a Mystery Box.\n%s" % _reward_line(result.get("reward", {}))


func open_selected_with(rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = progress.open_mystery_box(rng)
	refresh()
	if bool(result.get("ok", false)):
		_card.text = "Opened a Mystery Box.\n%s" % _reward_line(result.get("reward", {}))
	return result


func _destroy_selected() -> void:
	if progress == null or _selected < 0:
		return
	if not _confirm:
		_confirm = true
		_card.text = "Destroy one of this item? Press Destroy again."
		return
	var result: Dictionary = progress.destroy_uid(_selected, 1)
	if not bool(result.get("ok", false)):
		_card.text = str(result.get("reason", ""))
	_selected = -1
	_confirm = false
	refresh()


func _deposit_selected() -> void:
	if progress == null or _selected < 0:
		return
	var result: Dictionary = progress.deposit_uid(_selected)
	_confirm = false
	if not bool(result.get("ok", false)):
		_card.text = str(result.get("reason", ""))
		return
	_selected = -1
	refresh()


func _item_click(event: InputEvent, uid: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_selected = uid
		var def: Dictionary = {}
		for entry in progress.bag:
			var row: Dictionary = entry
			if int(row.get("uid", -1)) == uid:
				def = progress.item_def(str(row.get("item_id", "")))
				break
		if str(def.get("id", "")) == "mystery_box":
			_open_selected()
		else:
			_equip_selected()


func _slot_text(slot: String) -> String:
	if progress == null or not progress.equipped.has(slot):
		return "empty"
	var inst: Dictionary = progress.equipped[slot]
	var def: Dictionary = progress.item_def(str(inst.get("item_id", "")))
	return str(def.get("name", inst.get("item_id", "")))


func _reward_line(reward: Dictionary) -> String:
	if int(reward.get("coins", 0)) > 0:
		return "Crypto Coins +%s" % str(int(reward["coins"]))
	var items: Array = reward.get("items", [])
	if items.is_empty():
		return "Nothing"
	var item: Dictionary = items[0]
	var def: Dictionary = progress.item_def(str(item.get("item_id", "")))
	return "%s (%s)" % [str(def.get("name", item.get("item_id", ""))), str(item.get("rarity", ""))]


func _rarity_style(rarity: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.13, 0.12, 1)
	var border := Color(0.92, 0.9, 0.86)
	if rarity == "rare":
		border = Color(0.35, 0.55, 0.95)
	elif rarity == "epic":
		border = Color(0.72, 0.45, 0.95)
	elif rarity == "relic":
		border = Color(0.93, 0.76, 0.38)
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.12, 0.94)
	style.border_color = Color(0.93, 0.76, 0.38)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
