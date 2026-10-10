extends Control
class_name KoliseoShop

## Hub overlay for the Koliseo wallet (Blueprint §9 and §15).
## Left: trophy shop (hub food, frames, titles, tints, pets).
## Right: Room Tonics. The Duskbrand stall is retired.
## Trophy purchases are stored in the wallet. Cosmetic visuals are not built yet.

signal closed
signal wallet_changed

const _Wallet := preload("res://backend/koliseo_wallet.gd")
const NAVY := Color(0.008, 0.028, 0.07)
const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const ROW_HEIGHT := 48
const TONIC_ICON := "res://art/items/room_tonic.png"

var font: Font
var _wallet: KoliseoWallet
var _panel: PanelContainer
var _header: Label
var _status: Label
var _sku_buttons: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _tonic_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wallet = _Wallet.load_saved()
	_build()
	_refresh()


func wallet() -> KoliseoWallet:
	return _wallet


func sku_button(sku: String) -> Button:
	return _sku_buttons.get(sku, null)


func slot_button(slot: String) -> Button:
	return _slot_buttons.get(slot, null)


func status_text() -> String:
	return _status.text if _status != null else ""


func buy_sku(sku: String) -> Dictionary:
	var result := _wallet.buy(sku)
	if bool(result.get("ok", false)):
		_wallet.save()
		_status.text = "Bought %s." % str(_Wallet.SHOP[sku]["name"])
		wallet_changed.emit()
	else:
		_status.text = _reason_text(str(result.get("reason", "")))
	_refresh()
	return result


func buy_duskbrand(slot: String) -> Dictionary:
	var bag := GearBag.load_saved()
	var result := _wallet.buy_duskbrand(slot, bag)
	if bool(result.get("ok", false)):
		bag.save()
		_wallet.save()
		_status.text = "Bought Duskbrand %s +0." % slot.capitalize()
		wallet_changed.emit()
	else:
		_status.text = _reason_text(str(result.get("reason", "")))
	_refresh()
	return result


func tonic_button() -> Button:
	return _tonic_button


func buy_tonic() -> Dictionary:
	var result := _wallet.buy_tonic()
	if bool(result.get("ok", false)):
		_wallet.save()
		_status.text = "Bought a Room Tonic (%d/%d). Drink it between Stasis rooms." % [_wallet.tonics, _Wallet.TONIC_CARRY]
		wallet_changed.emit()
	else:
		_status.text = _reason_text(str(result.get("reason", "")))
	_refresh()
	return result


func close() -> void:
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.09, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	_panel.add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	_header = _label("", 18, GOLD_BRIGHT)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	var close_button := _button("Close")
	close_button.name = "CloseShop"
	close_button.pressed.connect(close)
	top.add_child(close_button)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	body.add_child(columns)
	var shop_col := VBoxContainer.new()
	shop_col.add_theme_constant_override("separation", 6)
	shop_col.add_child(_label("Trophy shop", 16, GOLD))
	for sku in _Wallet.SHOP_ORDER:
		var button := _button("")
		button.name = "Sku_" + sku.replace(".", "_")
		button.custom_minimum_size.x = 300
		button.pressed.connect(buy_sku.bind(sku))
		shop_col.add_child(button)
		_sku_buttons[sku] = button
	columns.add_child(shop_col)
	var stall_col := VBoxContainer.new()
	stall_col.add_theme_constant_override("separation", 6)
	stall_col.add_child(_label("Consumables", 16, GOLD))
	_tonic_button = _button("")
	_tonic_button.name = "BuyTonic"
	_tonic_button.custom_minimum_size.x = 260
	_tonic_button.tooltip_text = "Room Tonic: drink between Stasis Room A and Room B to heal 30% of max HP."
	if ResourceLoader.exists(TONIC_ICON):
		_tonic_button.icon = load(TONIC_ICON)
		_tonic_button.add_theme_constant_override("icon_max_width", 34)
	_tonic_button.pressed.connect(buy_tonic)
	stall_col.add_child(_tonic_button)
	columns.add_child(stall_col)
	_status = _label("", 14, GOLD)
	_status.name = "ShopStatus"
	body.add_child(_status)


func _refresh() -> void:
	var now := _Wallet.now_unix()
	_header.text = "Coins %d/%d   Trophies %d/%d   Paid wins left today %d" % [
		_wallet.coins, _Wallet.COIN_WALLET_MAX,
		_wallet.trophies, _Wallet.TROPHY_WALLET_MAX,
		_wallet.paid_wins_left(now),
	]
	for sku in _sku_buttons:
		var entry: Dictionary = _Wallet.SHOP[sku]
		var button: Button = _sku_buttons[sku]
		var gate := _wallet.can_buy(sku)
		if str(gate.get("reason", "")) == "owned":
			button.text = "%s — owned" % str(entry["name"])
		else:
			var count := int(_wallet.owned.get(sku, 0))
			var have := "  (x%d)" % count if count > 0 else ""
			button.text = "%s — %d trophies%s" % [str(entry["name"]), int(entry["cost"]), have]
		button.tooltip_text = str(entry["what"])
		button.disabled = not bool(gate.get("ok", false))
	if _tonic_button != null:
		_tonic_button.text = "Room Tonic — %d coin  (%d/%d)" % [_Wallet.TONIC_COST, _wallet.tonics, _Wallet.TONIC_CARRY]
		_tonic_button.disabled = not bool(_wallet.can_buy_tonic().get("ok", false))


static func _reason_text(reason: String) -> String:
	match reason:
		"not_enough_trophies":
			return "Not enough trophies."
		"not_enough_coins":
			return "Not enough coins."
		"owned":
			return "Already owned."
		"tonic_full":
			return "You already carry 3 Room Tonics."
		"retired":
			return "That stall is closed."
	return "Cannot buy."


func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", GOLD_DIM)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.06, 0.12, 0.95) if style_name != "disabled" else Color(0.02, 0.03, 0.06, 0.9)
		style.border_color = GOLD_BRIGHT if style_name in ["hover", "focus"] else (GOLD_DIM if style_name == "disabled" else GOLD)
		style.set_border_width_all(1)
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(style_name, style)
	return button
