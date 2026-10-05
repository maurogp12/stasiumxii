extends Control
class_name InventoryScreen

## Main-menu inventory, Dofus style (Mauro 29 Sep 2026: "an inventory at the
## main menu where you can modify your champion, gear, fuse the equipment").
## Left: champion picker, the champion turning on its pedestal (ChampionStage:
## swipe or ◀ ▶) with the five worn slots and the Still socket around it, and the characteristics the next fight uses.
## Right: tabs (Equipment / Consumables / Stills / Cosmetics), an item grid,
## and a detail box with Wear, Take off and Fuse. Levels, Stills and Sets
## open the full screens for spend points, forging and attune.

signal closed

const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const GREEN := Color(0.66, 0.84, 0.25)
const ROW_HEIGHT := 48
const TILE := 64
const TABS: Array[String] = ["equipment", "consumables", "stills", "cosmetics"]
const TAB_LABEL := {"equipment": "Equipment", "consumables": "Consumables", "stills": "Stills", "cosmetics": "Cosmetics"}
## Doll slots: left side, right side of the champion card.
const LEFT_SLOTS: Array[String] = ["head", "weapon", "chest"]
const RIGHT_SLOTS: Array[String] = ["legs", "boots"]
const CONSUMABLES: Array[String] = ["consumable.room_tonic", "food.hearth", "food.stillwater"]

var font: Font
var champion: String = "kestrel"
var tab: String = "equipment"
## {"kind": "item", "uid": n} | {"kind": "slot", "slot": s} | {"kind": "sku", "sku": s} | {"kind": "still", "id": s}
var picked: Dictionary = {}
var _bag: GearBag
var _hero: HeroProgress
var _wallet: KoliseoWallet
var _vault: StillVault
var _header: Label
var _status: Label
var _champ_row: HBoxContainer
var _doll: Control
var _stage: ChampionStage
var _stats_box: VBoxContainer
var _tab_row: HBoxContainer
var _grid: GridContainer
var _detail: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reload()
	_build()
	_refresh()


func bag() -> GearBag:
	return _bag


func status_text() -> String:
	return _status.text if _status != null else ""


func stats() -> Dictionary:
	return champion_stats(_bag, _hero, champion)


## The characteristics the next Stasis / online Koliseo fight gives this
## champion: Mauro 30 Sep 2026 class base HP, 6 AP / 3 MP, plus worn gear,
## plus the class level.
static func champion_stats(gear: GearBag, hero: HeroProgress, class_id: String) -> Dictionary:
	var st := GearBag.combat_stats(gear.worn_list(), gear.attune)
	var lv := HeroProgress.combat_stats(hero.fight_hero(class_id), class_id)
	var apmp := gear.ap_mp()
	var base_hp := preload("res://backend/combat_sim.gd").class_base_hp(class_id)
	return {
		"level": int(lv["level"]),
		"hp": roundi(float(base_hp + int(lv["hp"]) + int(st["hp_flat"])) * (1.0 + float(st["hp_pct"]) / 100.0)),
		"ap": mini(int(apmp["ap"]) + int(lv["ap"]), GearBag.AP_CAP),
		"mp": int(apmp["mp"]),
		"init": int(st["init"]) + int(lv["init"]),
		"mastery": int(st["mastery"]) + int(lv["mastery"]),
		"resist": int(st["resist"]),
		"ward": int(lv["ward"]),
	}


func pick_champion(class_id: String) -> void:
	if SpellKits.is_roster_class(class_id):
		champion = class_id
		_refresh()


func show_tab(id: String) -> void:
	if TABS.has(id):
		tab = id
		picked = {}
		_refresh()


func select(sel: Dictionary) -> void:
	picked = sel
	_status.text = ""
	_refresh()


func wear(uid: int) -> Dictionary:
	var result := _bag.equip(uid)
	_after_gear(result, "Wearing %s." % GearBag.item_label(_bag.item(uid)))
	return result


func take_off(slot: String) -> Dictionary:
	var result := _bag.unequip(slot)
	_after_gear(result, "Took off the %s." % slot)
	if bool(result.get("ok", false)):
		picked = {}
		_refresh()
	return result


func fuse(uid: int) -> Dictionary:
	var partner := _bag.fuse_partner(uid)
	var result := _bag.fuse(uid, partner) if partner != -1 else {"ok": false, "reason": "no_partner"}
	_after_gear(result, "Fused: %s." % GearBag.item_label(_bag.item(uid)))
	return result


func open_levels() -> CharacterScreen:
	var screen: CharacterScreen = load("res://scenes/character_screen.gd").new()
	screen.name = "CharacterScreen"
	screen.font = font
	screen.selected = champion
	screen.closed.connect(_on_child_closed)
	add_child(screen)
	return screen


## Elements Step 3: pick 2 elements per class, set each spell, Blend guide.
func open_elements() -> ElementsScreen:
	var screen: ElementsScreen = load("res://scenes/elements_screen.gd").new()
	screen.name = "ElementsScreen"
	screen.font = font
	screen.selected = champion
	screen.closed.connect(_on_child_closed)
	add_child(screen)
	return screen


func open_stills() -> StillsScreen:
	var screen: StillsScreen = load("res://scenes/stills_screen.gd").new()
	screen.name = "StillsScreen"
	screen.font = font
	screen.closed.connect(_on_child_closed)
	add_child(screen)
	return screen


func open_sets() -> GearScreen:
	var screen: GearScreen = load("res://scenes/gear_screen.gd").new()
	screen.name = "GearScreen"
	screen.font = font
	screen.closed.connect(_on_child_closed)
	add_child(screen)
	return screen


func close() -> void:
	closed.emit()
	queue_free()


func _on_child_closed() -> void:
	_reload()
	_refresh()


func _reload() -> void:
	_bag = GearBag.load_saved()
	_hero = HeroProgress.load_saved()
	_wallet = KoliseoWallet.load_saved()
	_vault = StillVault.load_saved()


func _after_gear(result: Dictionary, ok_text: String) -> void:
	if bool(result.get("ok", false)):
		_bag.save()
		_status.text = ok_text
	else:
		_status.text = GearScreen._reason_text(str(result.get("reason", "")))
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.78))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 14
	panel.offset_right = -16
	panel.offset_bottom = -14
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.03, 0.025, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	body.add_child(top)
	_header = _label("", 18, GOLD_BRIGHT)
	_header.name = "InventoryHeader"
	_header.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	for spec in [["Levels", "OpenLevels", open_levels], ["Elements", "OpenElements", open_elements], ["Stills", "OpenStills", open_stills], ["Sets", "OpenSets", open_sets], ["Close", "CloseInventory", close]]:
		var b := _button(str(spec[0]))
		b.name = str(spec[1])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(spec[2] as Callable)
		top.add_child(b)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	# Left: champion.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	_champ_row = HBoxContainer.new()
	_champ_row.add_theme_constant_override("separation", 4)
	left.add_child(_champ_row)
	_doll = Control.new()
	_doll.name = "Doll"
	_doll.custom_minimum_size = Vector2(380, 300)
	left.add_child(_doll)
	# The turning champion (ChampionStage) sits between the slot columns.
	_stage = ChampionStage.new()
	_stage.name = "ChampionStage"
	_stage.position = Vector2(TILE + 12, 0)
	_stage.size = Vector2(380 - (TILE + 12) * 2, 300)
	_doll.add_child(_stage)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	left.add_child(_stats_box)
	# Right: bag.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 4)
	right.add_child(_tab_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "ItemGrid"
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	var detail_panel := PanelContainer.new()
	var dstyle := StyleBoxFlat.new()
	dstyle.bg_color = Color(0.07, 0.06, 0.05, 0.95)
	dstyle.border_color = GOLD_DIM
	dstyle.set_border_width_all(1)
	dstyle.set_content_margin_all(8)
	detail_panel.add_theme_stylebox_override("panel", dstyle)
	detail_panel.custom_minimum_size.y = 150
	right.add_child(detail_panel)
	_detail = VBoxContainer.new()
	_detail.name = "ItemDetail"
	_detail.add_theme_constant_override("separation", 4)
	detail_panel.add_child(_detail)
	_status = _label("", 14, GOLD)
	_status.name = "InventoryStatus"
	body.add_child(_status)


func _refresh() -> void:
	if _header == null:
		return
	_header.text = "Inventory     Coins %d  ·  Trophies %d" % [_wallet.coins, _wallet.trophies]
	_refresh_champions()
	_refresh_doll()
	_refresh_stats()
	_refresh_tabs()
	_refresh_grid()
	_refresh_detail()


func _refresh_champions() -> void:
	_clear(_champ_row)
	for class_id in SpellKits.LOCKED_ROSTER:
		var b := _button(SpellKits.display_name(class_id))
		b.name = "Champ_" + class_id
		b.custom_minimum_size = Vector2(72, 40)
		b.clip_text = false
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 11)
		for st_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			var st := b.get_theme_stylebox(st_name) as StyleBoxFlat
			if st != null:
				st.content_margin_left = 2
				st.content_margin_right = 2
		b.tooltip_text = "Level %d" % _hero.level_of(class_id)
		if class_id == champion:
			_light(b)
		b.pressed.connect(pick_champion.bind(class_id))
		_champ_row.add_child(b)


func _refresh_doll() -> void:
	for child in _doll.get_children():
		if child != _stage:
			_doll.remove_child(child)
			child.queue_free()
	_stage.set_class(champion)
	_stage.rune_tint = _worn_tint()
	var y := 8
	for slot in LEFT_SLOTS:
		_doll.add_child(_slot_tile(slot, Vector2(8, y)))
		y += TILE + 30
	y = 8
	for slot in RIGHT_SLOTS:
		_doll.add_child(_slot_tile(slot, Vector2(380 - TILE - 8, y)))
		y += TILE + 30
	# The XII Still socket sits under the right column.
	var sock := InvTile.new()
	sock.name = "Socket"
	sock.font = font
	sock.glyph = "still"
	sock.position = Vector2(380 - TILE - 8, y)
	sock.size = Vector2(TILE, TILE)
	sock.caption = "Still"
	if _vault.socket != "":
		sock.tint = StillVault.COLORS[_vault.socket]
		sock.icon_tex = StillVault.icon(_vault.socket)
		sock.filled = true
		sock.badge = "OW" if _vault.mode == "overwound" else ""
		sock.pressed.connect(select.bind({"kind": "still", "id": _vault.socket}))
	else:
		sock.pressed.connect(open_stills)
	_doll.add_child(sock)


func _slot_tile(slot: String, at: Vector2) -> InvTile:
	var t := InvTile.new()
	t.name = "Slot_" + slot
	t.font = font
	t.glyph = slot
	t.caption = slot.capitalize()
	t.position = at
	t.size = Vector2(TILE, TILE)
	var worn := _bag.equipped_item(slot)
	if not worn.is_empty():
		t.filled = true
		t.tint = _rarity_tint(str(worn["item_id"]))
		t.icon_tex = GearBag.icon(str(worn["item_id"]), champion)
		t.plus = int(worn["plus"])
		t.picked = str(picked.get("kind", "")) == "slot" and str(picked.get("slot", "")) == slot
		t.pressed.connect(select.bind({"kind": "slot", "slot": slot}))
	return t


func _refresh_stats() -> void:
	_clear(_stats_box)
	var st := stats()
	var level := int(st["level"])
	var need := HeroProgress.xp_to_next(level)
	var lv := _label("%s — Level %d%s" % [SpellKits.display_name(champion), level, ("   ·   %d free points" % _hero.points_free(champion)) if _hero.points_free(champion) > 0 else ""], 16, GOLD_BRIGHT)
	lv.name = "ChampionLevel"
	_stats_box.add_child(lv)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.max_value = maxi(need, 1)
	bar.value = _hero.xp_of(champion) if need > 0 else bar.max_value
	var fill := StyleBoxFlat.new()
	fill.bg_color = GREEN
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.09, 0.08)
	bar.add_theme_stylebox_override("background", bg)
	_stats_box.add_child(bar)
	var grid := GridContainer.new()
	grid.name = "Characteristics"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	for pair in [["HP", st["hp"]], ["AP", st["ap"]], ["MP", st["mp"]], ["Init", st["init"]], ["Mastery", st["mastery"]], ["Resist", st["resist"]], ["Ward", st["ward"]]]:
		var cell := _label("%s  %d" % [str(pair[0]), int(pair[1])], 14, GOLD_BRIGHT)
		cell.name = "Stat_" + str(pair[0])
		cell.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(cell)
	_stats_box.add_child(grid)


func _refresh_tabs() -> void:
	_clear(_tab_row)
	for id in TABS:
		var b := _button(str(TAB_LABEL[id]))
		b.name = "Tab_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(120, 40)
		b.clip_text = false
		b.add_theme_font_size_override("font_size", 12)
		if id == tab:
			_light(b)
		b.pressed.connect(show_tab.bind(id))
		_tab_row.add_child(b)


func _refresh_grid() -> void:
	_clear(_grid)
	match tab:
		"equipment":
			var sorted := _bag.items.duplicate(true)
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var fa := GearBag.FAMILY_ORDER.find(GearBag.family_of(str(a["item_id"])))
				var fb := GearBag.FAMILY_ORDER.find(GearBag.family_of(str(b["item_id"])))
				if fa != fb:
					return fa < fb
				if str(a["item_id"]) != str(b["item_id"]):
					return GearBag.SLOTS.find(GearBag.slot_of(str(a["item_id"]))) < GearBag.SLOTS.find(GearBag.slot_of(str(b["item_id"])))
				return int(a["plus"]) > int(b["plus"]))
			for it in sorted:
				var uid := int(it["uid"])
				var t := _grid_tile("Item_%d" % uid)
				t.glyph = GearBag.slot_of(str(it["item_id"]))
				t.tint = _rarity_tint(str(it["item_id"]))
				t.icon_tex = GearBag.icon(str(it["item_id"]), champion)
				t.filled = true
				t.plus = int(it["plus"])
				t.badge = "E" if _bag.is_equipped(uid) else ""
				t.picked = str(picked.get("kind", "")) == "item" and int(picked.get("uid", -1)) == uid
				t.pressed.connect(select.bind({"kind": "item", "uid": uid}))
			if sorted.is_empty():
				_grid_note("Empty. Clear a Stasis door or buy Duskbrand in the Shop.")
		"consumables":
			var any := false
			for sku in CONSUMABLES:
				var n := _consumable_count(sku)
				if n <= 0:
					continue
				any = true
				var t := _grid_tile("Sku_" + sku.replace(".", "_"))
				t.glyph = "tonic" if sku == KoliseoWallet.TONIC_SKU else "food"
				t.icon_tex = load(KoliseoShop.TONIC_ICON) if sku == KoliseoWallet.TONIC_SKU and ResourceLoader.exists(KoliseoShop.TONIC_ICON) else null
				t.tint = GOLD_BRIGHT
				t.filled = true
				t.count = n
				t.picked = str(picked.get("sku", "")) == sku
				t.pressed.connect(select.bind({"kind": "sku", "sku": sku}))
			if not any:
				_grid_note("No consumables. Room Tonics cost 1 coin in the Shop.")
		"stills":
			var any := false
			for id in StillVault.IDS:
				if _vault.count(id) <= 0 and _vault.socket != id:
					continue
				any = true
				var t := _grid_tile("Still_" + id)
				t.glyph = "still"
				# Fragments show the shard; a socketed Still with none left shows the hourglass.
				t.icon_tex = StillVault.icon(id, _vault.count(id) > 0)
				t.tint = StillVault.COLORS[id]
				t.filled = true
				t.count = _vault.count(id)
				t.badge = "S" if _vault.socket == id else ""
				t.picked = str(picked.get("id", "")) == id
				t.pressed.connect(select.bind({"kind": "still", "id": id}))
			if not any:
				_grid_note("No Still fragments yet. Stasis chests drop them.")
		"cosmetics":
			var any := false
			for sku in KoliseoWallet.SHOP_ORDER:
				if not bool(KoliseoWallet.SHOP[sku].get("once", false)) or not _wallet.owns(sku):
					continue
				any = true
				var t := _grid_tile("Sku_" + sku.replace(".", "_"))
				t.glyph = "cosmetic"
				t.tint = Color(0.86, 0.50, 1.0)
				t.filled = true
				t.picked = str(picked.get("sku", "")) == sku
				t.pressed.connect(select.bind({"kind": "sku", "sku": sku}))
			if not any:
				_grid_note("No cosmetics yet. The trophy Shop sells frames, titles, tints and the pet.")


func _grid_tile(node_name: String) -> InvTile:
	var t := InvTile.new()
	t.name = node_name
	t.font = font
	t.custom_minimum_size = Vector2(TILE, TILE)
	_grid.add_child(t)
	return t


func _grid_note(text: String) -> void:
	var note := _label(text, 13, GOLD_DIM)
	note.custom_minimum_size.x = 360
	_grid.add_child(note)


func _consumable_count(sku: String) -> int:
	if sku == KoliseoWallet.TONIC_SKU:
		return _wallet.tonics
	return int(_wallet.owned.get(sku, 0))


func _refresh_detail() -> void:
	_clear(_detail)
	var kind := str(picked.get("kind", ""))
	var item := {}
	if kind == "item":
		item = _bag.item(int(picked.get("uid", -1)))
	elif kind == "slot":
		item = _bag.equipped_item(str(picked.get("slot", "")))
	if not item.is_empty():
		var uid := int(item["uid"])
		var item_id := str(item["item_id"])
		var fam: Dictionary = GearBag.FAMILIES.get(GearBag.family_of(item_id), {})
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var art := TextureRect.new()
		art.name = "DetailIcon"
		art.texture = GearBag.icon(item_id, champion)
		art.custom_minimum_size = Vector2(48, 48)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(art)
		var title := _label(GearBag.item_label(item), 17, _rarity_tint(item_id))
		title.name = "DetailName"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(title)
		_detail.add_child(head)
		_detail.add_child(_label("%s · %s %s · %s" % [GearBag.slot_of(item_id).capitalize(), str(fam.get("name", "")), str(fam.get("rarity", "")), GearBag.part_line(item_id, int(item["plus"]))], 13, GOLD_BRIGHT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		if _bag.is_equipped(uid):
			var off := _button("Take off")
			off.name = "TakeOff"
			off.custom_minimum_size.x = 120
			off.pressed.connect(take_off.bind(GearBag.slot_of(item_id)))
			row.add_child(off)
		else:
			var on := _button("Wear")
			on.name = "Wear"
			on.custom_minimum_size.x = 120
			on.pressed.connect(wear.bind(uid))
			row.add_child(on)
		var fuse_button := _button("Fuse (needs 2 alike)")
		fuse_button.name = "Fuse"
		fuse_button.custom_minimum_size.x = 200
		fuse_button.clip_text = false
		var partner := _bag.fuse_partner(uid)
		fuse_button.disabled = partner == -1 or not bool(_bag.can_fuse(uid, partner).get("ok", false))
		if not fuse_button.disabled:
			fuse_button.text = "Fuse → +%d" % (int(item["plus"]) + 1)
		fuse_button.pressed.connect(fuse.bind(uid))
		row.add_child(fuse_button)
		_detail.add_child(row)
		return
	if kind == "sku":
		var sku := str(picked.get("sku", ""))
		if sku == KoliseoWallet.TONIC_SKU:
			_detail.add_child(_label("Room Tonic × %d / %d" % [_wallet.tonics, KoliseoWallet.TONIC_CARRY], 17, GOLD_BRIGHT))
			_detail.add_child(_label("Heals 30% of max HP (no overheal). Drink it between Stasis Room A and Room B — not mid-fight, not in Koliseo.", 13, GOLD_BRIGHT))
		elif KoliseoWallet.SHOP.has(sku):
			var entry: Dictionary = KoliseoWallet.SHOP[sku]
			_detail.add_child(_label(str(entry["name"]), 17, GOLD_BRIGHT))
			_detail.add_child(_label("%s (use: not built yet)" % str(entry["what"]), 13, GOLD_BRIGHT))
		return
	if kind == "still":
		var id := str(picked.get("id", ""))
		var fx: Dictionary = StillVault.EFFECTS.get(id, {})
		var still_tint: Color = StillVault.COLORS.get(id, GOLD_BRIGHT).lerp(GOLD_BRIGHT, 0.4)
		var head := _label("%s Still" % StillVault.display_name(id), 18, still_tint)
		head.name = "StillHead"
		_detail.add_child(head)
		var have := _vault.count(id)
		var line := "Fragments: %d.  %s" % [have, StillVault.forge_summary(have)]
		if _vault.socket == id:
			line = "In your Still socket (%s).  %s" % ["Intact" if _vault.mode == "intact" else "Overwound", line]
		_detail.add_child(_label(line, 14, GOLD_BRIGHT))
		var soon := "" if bool(fx.get("built", true)) else "  (coming in the next update)"
		_detail.add_child(_label("Intact — safe: %s%s" % [StillVault.plain(id, "intact"), soon], 14, GOLD_BRIGHT))
		_detail.add_child(_label("Overwound — stronger, then it cracks: %s%s" % [StillVault.plain(id, "overwound"), soon], 14, GOLD_BRIGHT))
		_detail.add_child(_label("  ".join(StillVault.HOW_TO), 12, GOLD_DIM))
		var vault_button := _button("Open the Vault to forge")
		vault_button.name = "OpenVault"
		vault_button.pressed.connect(open_stills)
		_detail.add_child(vault_button)
		return
	_detail.add_child(_label("Tap an item to see it. Tap a worn slot to take it off.", 13, GOLD_DIM))


## Pedestal runes glow with the rarest worn piece; dim gold with nothing worn.
func _worn_tint() -> Color:
	var order: Array[String] = ["Normal", "Rare", "Legendary", "Ultra"]
	var best := -1
	var tint := Color(0.78, 0.62, 0.36)
	for slot in GearBag.SLOTS:
		var worn := _bag.equipped_item(slot)
		if worn.is_empty():
			continue
		var rarity := str(GearBag.FAMILIES.get(GearBag.family_of(str(worn["item_id"])), {}).get("rarity", ""))
		var rank := order.find(rarity)
		if rank > best:
			best = rank
			tint = GearScreen.RARITY_TINT.get(rarity, tint)
	return tint


func _rarity_tint(item_id: String) -> Color:
	var rarity := str(GearBag.FAMILIES.get(GearBag.family_of(item_id), {}).get("rarity", ""))
	return GearScreen.RARITY_TINT.get(rarity, GOLD_BRIGHT)


func _light(b: Button) -> void:
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0.30, 0.24, 0.10)
	lit.border_color = GOLD_BRIGHT
	lit.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", lit)
	b.add_theme_color_override("font_color", Color.WHITE)


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


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
	button.custom_minimum_size = Vector2(88, ROW_HEIGHT)
	button.clip_text = true
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", GOLD_DIM)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.065, 0.05, 0.95) if style_name != "disabled" else Color(0.05, 0.045, 0.04, 0.9)
		st.border_color = GOLD_BRIGHT if style_name in ["hover", "focus"] else (GOLD_DIM if style_name == "disabled" else GOLD)
		st.set_border_width_all(1)
		st.set_corner_radius_all(4)
		st.content_margin_left = 8
		st.content_margin_right = 8
		button.add_theme_stylebox_override(style_name, st)
	return button


## One square inventory cell: parchment slot, rarity frame, a drawn glyph
## for the slot (or the item's icon), +N, a count and a small corner badge.
class InvTile extends Button:
	var glyph := "weapon"
	var tint := Color(0.86, 0.84, 0.78)
	var filled := false
	var picked := false
	var plus := 0
	var count := 0
	var badge := ""
	var caption := ""
	var icon_tex: Texture2D
	var font: Font

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		text = ""
		clip_contents = false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.13, 0.11, 0.08, 0.95))
		draw_rect(r.grow(-3), Color(0.20, 0.17, 0.12, 0.9) if filled else Color(0.09, 0.08, 0.06, 0.9))
		var frame := tint if filled else Color(0.45, 0.37, 0.24)
		draw_rect(r, Color(1.0, 0.9, 0.55) if picked else frame, false, 3.0 if picked else 1.5)
		var c := size * 0.5
		var s := size.x * 0.28
		var ink := tint if filled else Color(0.40, 0.34, 0.24)
		if icon_tex != null:
			# Soft rarity glow behind the item art, then the art.
			if filled:
				draw_circle(c, size.x * 0.34, Color(tint.r, tint.g, tint.b, 0.16))
			draw_texture_rect(icon_tex, r.grow(-4), false)
		else:
			_glyph(c, s, ink)
		var f := font if font != null else ThemeDB.fallback_font
		if plus > 0:
			draw_string(f, Vector2(4, size.y - 5), "+%d" % plus, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.95, 0.7))
		if count > 0:
			var ct := "x%d" % count
			var w := f.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			# Dark plate so the count reads over painted icons.
			draw_rect(Rect2(Vector2(size.x - w - 7, size.y - 18), Vector2(w + 5, 15)), Color(0.04, 0.03, 0.02, 0.82))
			draw_string(f, Vector2(size.x - w - 4, size.y - 5), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.7))
		if badge != "":
			draw_circle(Vector2(size.x - 9, 9), 8, Color(0.66, 0.84, 0.25) if badge == "E" else Color(0.62, 0.36, 0.95))
			var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(f, Vector2(size.x - 9 - bw * 0.5, 13), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.05, 0.05, 0.05))
		if caption != "" and not filled:
			var cw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(f, Vector2((size.x - cw) * 0.5, size.y - 5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.52, 0.34))

	func _glyph(c: Vector2, s: float, ink: Color) -> void:
		match glyph:
			"weapon":
				draw_line(c + Vector2(-s, s), c + Vector2(s, -s), ink, 4.0, true)
				draw_line(c + Vector2(-s * 0.9, s * 0.3), c + Vector2(-s * 0.3, s * 0.9), ink, 3.0, true)
			"head":
				draw_arc(c + Vector2(0, s * 0.2), s, PI, TAU, 16, ink, 4.0, true)
				draw_line(c + Vector2(-s, s * 0.2), c + Vector2(s, s * 0.2), ink, 3.0, true)
				draw_line(c + Vector2(0, s * 0.2), c + Vector2(0, s * 0.8), ink, 3.0, true)
			"chest":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.8), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.7, s), c + Vector2(-s * 0.7, s)]), Color(ink.r, ink.g, ink.b, 0.55))
				draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.8), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.7, s), c + Vector2(-s * 0.7, s), c + Vector2(-s, -s * 0.8)]), ink, 2.0, true)
			"legs":
				draw_line(c + Vector2(-s * 0.4, -s), c + Vector2(-s * 0.5, s), ink, 5.0, true)
				draw_line(c + Vector2(s * 0.4, -s), c + Vector2(s * 0.5, s), ink, 5.0, true)
				draw_line(c + Vector2(-s * 0.6, -s), c + Vector2(s * 0.6, -s), ink, 3.0, true)
			"boots":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s), c + Vector2(0, -s), c + Vector2(0, s * 0.4), c + Vector2(s, s * 0.5), c + Vector2(s, s), c + Vector2(-s * 0.5, s)]), ink)
			"still":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s), c + Vector2(s * 0.7, -s), c]), Color(ink.r, ink.g, ink.b, 0.6))
				draw_colored_polygon(PackedVector2Array([c, c + Vector2(s * 0.7, s), c + Vector2(-s * 0.7, s)]), ink)
				draw_line(c + Vector2(-s, -s), c + Vector2(s, -s), Color(0.85, 0.68, 0.32), 2.5, true)
				draw_line(c + Vector2(-s, s), c + Vector2(s, s), Color(0.85, 0.68, 0.32), 2.5, true)
			"food":
				draw_circle(c + Vector2(0, s * 0.2), s * 0.8, Color(0.72, 0.50, 0.26))
				draw_arc(c + Vector2(0, s * 0.2), s * 0.8, 0, TAU, 20, ink, 2.0, true)
			"tonic":
				draw_circle(c + Vector2(0, s * 0.3), s * 0.75, Color(0.95, 0.85, 0.55, 0.8))
				draw_rect(Rect2(c + Vector2(-s * 0.2, -s), Vector2(s * 0.4, s * 0.6)), ink)
			"cosmetic":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.3, -s * 0.3), c + Vector2(s, 0), c + Vector2(s * 0.3, s * 0.3), c + Vector2(0, s), c + Vector2(-s * 0.3, s * 0.3), c + Vector2(-s, 0), c + Vector2(-s * 0.3, -s * 0.3)]), ink)
