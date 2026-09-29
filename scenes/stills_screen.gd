extends Control
class_name StillsScreen

## XII Stills (Mauro 29 Sep 2026). Left: the 12 hourglasses with fragment
## counts (x/12). Right: the picked Still's Intact / Overwound effect and
## Forge (12 of the same, empty socket). Bottom: the socket and the
## Keep Intact / Overwind choice for the next Stasis or online Koliseo fight.

signal closed

const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const GREEN := Color(0.66, 0.84, 0.25)
const ROW_HEIGHT := 48

var font: Font
var selected: String = "stride"
var _vault: StillVault
var _grid: GridContainer
var _detail: VBoxContainer
var _socket_box: HBoxContainer
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vault = StillVault.load_saved()
	if _vault.socket != "":
		selected = _vault.socket
	_build()
	_refresh()


func vault() -> StillVault:
	return _vault


func status_text() -> String:
	return _status.text if _status != null else ""


func pick(id: String) -> void:
	if StillVault.is_id(id):
		selected = id
		if _status != null:
			_status.text = ""
			_refresh()


func forge() -> Dictionary:
	var result := _vault.forge(selected)
	if bool(result.get("ok", false)):
		_vault.save()
		_status.text = "%s forged. It powers your next Stasis or online Koliseo fight, then breaks." % StillVault.display_name(selected)
	else:
		_status.text = {"needs_12": "Needs 12 fragments of the same Still.", "socket_full": "The socket is full — use that Still in a fight first."}.get(str(result.get("reason", "")), "Cannot forge.")
	_refresh()
	return result


func choose_mode(mode: String) -> Dictionary:
	var result := _vault.set_mode(mode)
	if bool(result.get("ok", false)):
		_vault.save()
		_status.text = "Keep Intact." if mode == "intact" else "Overwind: stronger, then it cracks."
	_refresh()
	return result


func close() -> void:
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.76))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_top = 20
	panel.offset_right = -30
	panel.offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.08, 0.97)
	style.border_color = Color(0.62, 0.42, 0.95)
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var top := HBoxContainer.new()
	var title := _label("XII Stills — Vault of Aeons", 20, GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_button := _button("Close")
	close_button.name = "CloseStills"
	close_button.pressed.connect(close)
	top.add_child(close_button)
	body.add_child(top)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	cols.add_child(_grid)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	cols.add_child(_detail)
	_socket_box = HBoxContainer.new()
	_socket_box.add_theme_constant_override("separation", 10)
	body.add_child(_socket_box)
	_status = _label("", 14, GOLD)
	_status.name = "StillsStatus"
	body.add_child(_status)


func _refresh() -> void:
	for box in [_grid, _detail, _socket_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for id in StillVault.IDS:
		var tile := StillTile.new()
		tile.name = "Still_" + id
		tile.still_id = id
		tile.count = _vault.count(id)
		tile.picked = id == selected
		tile.font = font
		tile.custom_minimum_size = Vector2(86, 96)
		tile.pressed.connect(pick.bind(id))
		_grid.add_child(tile)
	var fx: Dictionary = StillVault.EFFECTS[selected]
	var head := _label("%s — %d / %d fragments" % [StillVault.display_name(selected), _vault.count(selected), StillVault.FORGE_COST], 18, StillVault.COLORS[selected].lerp(GOLD_BRIGHT, 0.4))
	head.name = "StillHead"
	_detail.add_child(head)
	_detail.add_child(_label("Intact: %s" % fx["intact"], 15, GOLD_BRIGHT))
	_detail.add_child(_label("Overwound: %s" % fx["overwound"], 15, GOLD_BRIGHT))
	if not bool(fx["built"]):
		_detail.add_child(_label("Effect arrives in the next update — forging it now keeps it for later fights.", 13, GOLD_DIM))
	var forge_button := _button("Forge %s" % StillVault.display_name(selected))
	forge_button.name = "Forge"
	forge_button.disabled = not bool(_vault.can_forge(selected).get("ok", false))
	forge_button.pressed.connect(forge)
	_detail.add_child(forge_button)
	_detail.add_child(_label("Fragments drop from Stasis chests (5 loot clears a day). 12 of the same Still forge it. It powers one fight, then breaks.", 12, GOLD_DIM))
	var socket_label := _label("Socket: empty", 16, GOLD)
	socket_label.name = "SocketLabel"
	_socket_box.add_child(socket_label)
	if _vault.socket != "":
		socket_label.text = "Socket: %s" % StillVault.display_name(_vault.socket)
		socket_label.add_theme_color_override("font_color", StillVault.COLORS[_vault.socket].lerp(Color.WHITE, 0.3))
		for mode in StillVault.MODES:
			var b := _button("Keep Intact" if mode == "intact" else "Overwind")
			b.name = "Mode_" + mode
			if _vault.mode == mode:
				var lit := StyleBoxFlat.new()
				lit.bg_color = Color(0.25, 0.14, 0.42)
				lit.border_color = GOLD_BRIGHT
				lit.set_border_width_all(2)
				b.add_theme_stylebox_override("normal", lit)
			b.pressed.connect(choose_mode.bind(mode))
			_socket_box.add_child(b)


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
	button.custom_minimum_size = Vector2(120, ROW_HEIGHT)
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", GOLD_DIM)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.06, 0.05, 0.12, 0.95)
		st.border_color = GOLD_BRIGHT if style_name in ["hover", "focus"] else (GOLD_DIM if style_name == "disabled" else GOLD)
		st.set_border_width_all(1)
		st.content_margin_left = 10
		st.content_margin_right = 10
		button.add_theme_stylebox_override(style_name, st)
	return button


## One hourglass tile: glass tinted by the Still, sand filled by fragments.
class StillTile extends Button:
	var still_id := "stride"
	var count := 0
	var picked := false
	var font: Font

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		text = ""

	func _draw() -> void:
		var tint: Color = StillVault.COLORS.get(still_id, Color.WHITE)
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.07, 0.05, 0.14, 0.95))
		draw_rect(rect, Color(1.0, 0.86, 0.5) if picked else Color(0.4, 0.3, 0.55), false, 2.0 if picked else 1.0)
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var w := size.x * 0.22
		var h := size.y * 0.28
		var frame := Color(0.85, 0.68, 0.32)
		var fill := clampf(float(count) / float(StillVault.FORGE_COST), 0.0, 1.0)
		# Glass halves.
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -h), c + Vector2(w, -h), c]), Color(tint.r, tint.g, tint.b, 0.18))
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(w, h), c + Vector2(-w, h)]), Color(tint.r, tint.g, tint.b, 0.18))
		# Sand in the bottom half grows with fragments.
		if fill > 0.0:
			var top_y := h * (1.0 - fill)
			var half := w * (1.0 - top_y / h) if h > 0.0 else w
			draw_colored_polygon(PackedVector2Array([c + Vector2(-half, top_y), c + Vector2(half, top_y), c + Vector2(w, h), c + Vector2(-w, h)]), tint)
			draw_circle(c + Vector2(0, h * 0.5), w * 0.9, Color(tint.r, tint.g, tint.b, 0.18 * fill))
		draw_polyline(PackedVector2Array([c + Vector2(-w, -h), c, c + Vector2(-w, h)]), frame, 1.4, true)
		draw_polyline(PackedVector2Array([c + Vector2(w, -h), c, c + Vector2(w, h)]), frame, 1.4, true)
		draw_line(c + Vector2(-w * 1.3, -h), c + Vector2(w * 1.3, -h), frame, 2.5, true)
		draw_line(c + Vector2(-w * 1.3, h), c + Vector2(w * 1.3, h), frame, 2.5, true)
		var f := font if font != null else ThemeDB.fallback_font
		var name := StillVault.display_name(still_id)
		var fs := 12
		var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - tw) * 0.5, size.y - 18), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.85, 0.6))
		var ct := "%d/12" % count
		var cw := f.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, Vector2((size.x - cw) * 0.5, size.y - 5), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.66, 0.84, 0.25) if count >= 12 else Color(0.7, 0.62, 0.5))
