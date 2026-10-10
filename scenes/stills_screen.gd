extends Control
class_name StillsScreen

## XII Stills (Mauro 9 Oct 2026). Left: the 14 hourglasses with fragment
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
var selected: String = "steadfast"
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
		_status.text = "Keep Intact." if mode == "intact" else "Overwind: stronger, with a drawback."
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
	_grid.columns = 5
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
		tile.custom_minimum_size = Vector2(108, 104)
		tile.pressed.connect(pick.bind(id))
		_grid.add_child(tile)
	var fx: Dictionary = StillVault.EFFECTS[selected]
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 12)
	var big := TextureRect.new()
	big.texture = StillVault.icon(selected)
	big.custom_minimum_size = Vector2(84, 84)
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head_row.add_child(big)
	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := _label("%s Still" % StillVault.display_name(selected), 20, StillVault.COLORS[selected].lerp(GOLD_BRIGHT, 0.4))
	head.name = "StillHead"
	head_text.add_child(head)
	var have := _vault.count(selected)
	head_text.add_child(_label("Fragments: %d / %d.  %s" % [have, StillVault.FORGE_COST, StillVault.forge_summary(have)], 15, GREEN if have >= StillVault.FORGE_COST else GOLD))
	head_row.add_child(head_text)
	_detail.add_child(head_row)
	_detail.add_child(_label("Intact — safe: %s" % StillVault.plain(selected, "intact"), 15, GOLD_BRIGHT))
	_detail.add_child(_label("Overwound — stronger, with a drawback: %s" % StillVault.plain(selected, "overwound"), 15, GOLD_BRIGHT))
	if not bool(fx["built"]):
		_detail.add_child(_label("This effect arrives in the next update. Forging it now keeps it for later fights.", 13, GOLD_DIM))
	var forge_button := _button("Forge %s" % StillVault.display_name(selected))
	forge_button.name = "Forge"
	forge_button.disabled = not bool(_vault.can_forge(selected).get("ok", false))
	forge_button.pressed.connect(forge)
	_detail.add_child(forge_button)
	var gate: Dictionary = _vault.can_forge(selected)
	if not bool(gate.get("ok", false)):
		var why := "Collect %d more %s fragments to forge it." % [StillVault.FORGE_COST - _vault.count(selected), StillVault.display_name(selected)]
		if str(gate.get("reason", "")) == "socket_full":
			why = "Your Still socket already holds %s. Use it in a fight first; then you can forge another." % StillVault.display_name(_vault.socket)
		var why_label := _label(why, 13, GOLD_DIM)
		why_label.name = "ForgeWhy"
		_detail.add_child(why_label)
	_detail.add_child(_label("How Stills work", 14, GOLD))
	for step in StillVault.HOW_TO:
		_detail.add_child(_label(step, 13, GOLD_DIM))
	var socket_icon := TextureRect.new()
	socket_icon.custom_minimum_size = Vector2(48, 48)
	socket_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	socket_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	socket_icon.texture = StillVault.icon(_vault.socket) if _vault.socket != "" else null
	_socket_box.add_child(socket_icon)
	var socket_label := _label("Still socket: empty. Forge a Still to fill it.", 16, GOLD)
	socket_label.name = "SocketLabel"
	# One line beside the buttons (word wrap in a row squeezed it to one letter).
	socket_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	socket_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_socket_box.add_child(socket_label)
	if _vault.socket != "":
		socket_label.text = "Still socket: %s — for your next fight:" % StillVault.display_name(_vault.socket)
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
	var still_id := "steadfast"
	var count := 0
	var picked := false
	var font: Font
	var _art: Texture2D

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		text = ""
		# Load before drawing: a texture first loaded inside _draw came out
		# as a blank white cell on the OpenGL (phone) renderer.
		_art = StillVault.icon(still_id, count < StillVault.FORGE_COST)

	func _draw() -> void:
		var tint: Color = StillVault.COLORS.get(still_id, Color.WHITE)
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.07, 0.05, 0.14, 0.95))
		draw_rect(rect, Color(1.0, 0.86, 0.5) if picked else Color(0.4, 0.3, 0.55), false, 2.0 if picked else 1.0)
		var art := _art
		if art != null:
			# Painted icon: the hourglass once 12 are in hand, else the shard
			# (dimmed with none). A bar under it fills toward 12.
			var side := minf(size.x - 12.0, size.y - 40.0)
			var box := Rect2(Vector2((size.x - side) * 0.5, 4.0), Vector2(side, side))
			draw_texture_rect(art, box, false, Color(1, 1, 1, 1.0 if count > 0 else 0.35))
			var bar := Rect2(Vector2(8, size.y - 34), Vector2(size.x - 16, 5))
			draw_rect(bar, Color(0.18, 0.14, 0.24))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(count) / float(StillVault.FORGE_COST), 0.0, 1.0), bar.size.y)), tint if count < StillVault.FORGE_COST else Color(0.66, 0.84, 0.25))
			_draw_caption()
			return
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
		_draw_caption()

	func _draw_caption() -> void:
		var f := font if font != null else ThemeDB.fallback_font
		var name := StillVault.display_name(still_id)
		var fs := 12
		var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - tw) * 0.5, size.y - 18), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.85, 0.6))
		# "7/12" while collecting; "Ready ×8" once a forge is possible (100/12 read badly).
		var ct := "%d/12" % count if count < StillVault.FORGE_COST else "Ready ×%d" % (count / StillVault.FORGE_COST)
		var cw := f.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, Vector2((size.x - cw) * 0.5, size.y - 5), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.66, 0.84, 0.25) if count >= 12 else Color(0.7, 0.62, 0.5))
