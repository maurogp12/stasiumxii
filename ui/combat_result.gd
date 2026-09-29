extends Control
class_name CombatResult

## Dofus-style end-of-fight window (Mauro's two examples, 29 Sep 2026:
## "Resultado del combate" for dungeons, "Combate terminado" for Koliseo).
## Header: outcome and duration (mm:ss, turns). Winners block, then losers
## block: portrait, name, HP left, loot icons. No level / XP / kamas columns:
## the game has none of those (not in the Blueprint).
##
## setup() data:
## {
##   "title": String, "outcome": String, "victory": bool,
##   "duration_sec": int, "turns": int, "note": String,
##   "winners": [{"name", "hp", "max_hp", "portrait": Texture2D, "you": bool,
##                "loot": [{"kind": "coin"|"trophy"|"gear", "count": int, "item_id": String, "plus": int}]}],
##   "losers": [same rows],
## }

signal closed

const BG := Color(0.13, 0.135, 0.14, 0.98)
const HEADER := Color(0.20, 0.21, 0.22)
const ROW_A := Color(0.17, 0.175, 0.18)
const ROW_B := Color(0.145, 0.15, 0.155)
const WIN_BAR := Color(0.36, 0.42, 0.33)
const LOSE_BAR := Color(0.24, 0.24, 0.25)
const TEXT := Color(0.93, 0.93, 0.90)
const DIM := Color(0.62, 0.63, 0.60)
const GREEN := Color(0.66, 0.84, 0.25)
const RED := Color(0.86, 0.36, 0.30)
const ROW_H := 56
const FAMILY_TINT := {
	"sheaf": Color(0.86, 0.74, 0.42),
	"undertow": Color(0.30, 0.58, 0.78),
	"ironveil": Color(0.55, 0.60, 0.66),
	"stillcut": Color(0.60, 0.80, 0.86),
	"brightedge": Color(1.0, 0.72, 0.30),
	"duskbrand": Color(0.62, 0.36, 0.86),
}

var data: Dictionary = {}
var font: Font
var _rows := 0


static func format_duration(seconds: int) -> String:
	var s := maxi(seconds, 0)
	return "%02d:%02d" % [s / 60, s % 60]


static func koliseo_result(snap: Dictionary, local_seat: int, payout: Dictionary, secs: int, portrait: Callable = Callable()) -> Dictionary:
	var winner_seat := int(snap.get("winner_seat", -1))
	var winners: Array = []
	var losers: Array = []
	var winner_name := ""
	for unit in snap.get("units", []):
		var seat := int(unit.get("seat", -1))
		var row := {
			"name": str(unit.get("name", "Seat %d" % seat)),
			"hp": int(unit.get("hp", 0)),
			"max_hp": int(unit.get("max_hp", 80)),
			"portrait": portrait.call(unit) if portrait.is_valid() else null,
			"you": seat == local_seat,
			"loot": [],
		}
		if seat == winner_seat:
			winner_name = str(row["name"])
			if seat == local_seat:
				if int(payout.get("coins", 0)) > 0:
					row["loot"].append({"kind": "coin", "count": int(payout["coins"])})
				if int(payout.get("trophies", 0)) > 0:
					row["loot"].append({"kind": "trophy", "count": int(payout["trophies"])})
			winners.append(row)
		else:
			losers.append(row)
	var outcome := "%s wins" % winner_name
	var victory := true
	var note := "Hot-seat match — only online wins pay coins and trophies."
	if local_seat >= 0:
		victory = winner_seat == local_seat
		outcome = "Victory" if victory else "Defeat"
		note = ""
		if victory and payout.is_empty():
			note = "No coins or trophies this time."
		elif victory and int(payout.get("coins", 0)) == 0:
			if int(payout.get("wins_today", 0)) > KoliseoWallet.PAID_WINS_PER_DAY:
				note = "Daily coin limit reached (2 paid wins per day)."
			else:
				note = "Coin wallet full (120)."
	return {
		"title": "Fight over",
		"outcome": outcome,
		"victory": victory,
		"duration_sec": secs,
		"turns": int(snap.get("turn_index", 0)),
		"winners": winners,
		"losers": losers,
		"note": note,
	}


func setup(result: Dictionary) -> void:
	data = result.duplicate()


func row_count() -> int:
	return _rows


func duration_text() -> String:
	return "Duration %s (%d turns)" % [format_duration(int(data.get("duration_sec", 0))), int(data.get("turns", 0))]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.name = "ResultPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(640, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = Color(0.36, 0.37, 0.38)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	panel.add_child(body)
	body.add_child(_title_bar(str(data.get("title", "Fight over"))))
	body.add_child(_summary_bar())
	body.add_child(_column_header())
	var winners: Array = data.get("winners", [])
	var losers: Array = data.get("losers", [])
	body.add_child(_section("Winners", WIN_BAR, true))
	for i in winners.size():
		body.add_child(_row(winners[i], i))
	body.add_child(_section("Losers", LOSE_BAR, false))
	for i in losers.size():
		body.add_child(_row(losers[i], i))
	var note := str(data.get("note", ""))
	if note != "":
		var note_label := _label(note, 13, DIM)
		note_label.name = "ResultNote"
		note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_label.custom_minimum_size = Vector2(0, 30)
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(note_label)
	var foot := CenterContainer.new()
	foot.custom_minimum_size = Vector2(0, 64)
	var close_button := Button.new()
	close_button.name = "CloseResult"
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(150, 48)
	close_button.focus_mode = Control.FOCUS_ALL
	if font != null:
		close_button.add_theme_font_override("font", font)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Color(0.12, 0.16, 0.05))
	close_button.add_theme_color_override("font_hover_color", Color(0.05, 0.08, 0.0))
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = GREEN if style_name != "hover" else GREEN.lightened(0.15)
		box.set_corner_radius_all(4)
		box.border_color = Color(0.84, 0.95, 0.5)
		box.set_border_width_all(1)
		close_button.add_theme_stylebox_override(style_name, box)
	close_button.pressed.connect(close)
	foot.add_child(close_button)
	body.add_child(foot)


func _title_bar(title: String) -> Control:
	var bar := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.095, 0.10)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.border_color = Color(0.40, 0.45, 0.30)
	box.border_width_bottom = 2
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", box)
	var label := _label(title, 20, TEXT)
	label.name = "ResultTitle"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(label)
	return bar


func _summary_bar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 58)
	row.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_child(row)
	var victory := bool(data.get("victory", true))
	var outcome := _chip(str(data.get("outcome", "Victory")), GREEN if victory else RED, "Cup" if victory else "Skull")
	outcome.name = "Outcome"
	row.add_child(outcome)
	var dur := _chip(duration_text(), TEXT, "Glass")
	dur.name = "Duration"
	dur.size_flags_stretch_ratio = 1.6
	row.add_child(dur)
	return margin


func _chip(text: String, tint: Color, icon: String) -> Control:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = HEADER
	box.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("panel", box)
	var inner := HBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 8)
	var glyph := Glyph.new()
	glyph.kind = icon
	glyph.tint = tint
	glyph.custom_minimum_size = Vector2(26, 26)
	inner.add_child(glyph)
	var label := _label(text, 16, tint)
	label.name = "Text"
	inner.add_child(label)
	chip.add_child(inner)
	return chip


func _column_header() -> Control:
	var row := _grid_row(HEADER)
	row.add_child(_cell(_label("Name", 14, DIM), 3.0))
	row.add_child(_cell(_label("HP", 14, DIM), 1.2))
	row.add_child(_cell(_label("Loot", 14, DIM), 3.4))
	return row.get_parent()


func _section(title: String, tint: Color, win: bool) -> Control:
	var bar := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.content_margin_left = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", box)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	var glyph := Glyph.new()
	glyph.kind = "Cup" if win else "Skull"
	glyph.tint = Color(0.45, 0.20, 0.12) if win else Color(0.85, 0.85, 0.82)
	glyph.custom_minimum_size = Vector2(26, 26)
	inner.add_child(glyph)
	inner.add_child(_label(title, 17, GREEN if win else TEXT))
	bar.add_child(inner)
	return bar


func _row(entry: Dictionary, index: int) -> Control:
	_rows += 1
	var row := _grid_row(ROW_A if index % 2 == 0 else ROW_B)
	row.get_parent().name = "Row_%s" % str(entry.get("name", index))
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(40, 40)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Variant = entry.get("portrait", null)
	if tex is Texture2D:
		face.texture = tex
	who.add_child(face)
	var name_label := _label(str(entry.get("name", "")), 16, TEXT)
	who.add_child(name_label)
	if bool(entry.get("you", false)):
		var arrow := Glyph.new()
		arrow.kind = "Arrow"
		arrow.tint = GREEN
		arrow.custom_minimum_size = Vector2(22, 22)
		who.add_child(arrow)
	row.add_child(_cell(who, 3.0))
	var hp := int(entry.get("hp", 0))
	var hp_label := _label("%d / %d" % [hp, int(entry.get("max_hp", 0))] if hp > 0 else "KO", 15, TEXT if hp > 0 else RED)
	row.add_child(_cell(hp_label, 1.2))
	var loot_row := HBoxContainer.new()
	loot_row.name = "Loot"
	loot_row.add_theme_constant_override("separation", 6)
	for loot in entry.get("loot", []):
		var icon := LootIcon.new()
		icon.loot = loot
		icon.custom_minimum_size = Vector2(44, 44)
		icon.tooltip_text = LootIcon.describe(loot)
		loot_row.add_child(icon)
	row.add_child(_cell(loot_row, 3.4))
	return row.get_parent()


func _grid_row(tint: Color) -> HBoxContainer:
	var shell := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.content_margin_left = 12
	box.content_margin_right = 12
	shell.add_theme_stylebox_override("panel", box)
	shell.custom_minimum_size = Vector2(0, ROW_H if tint != HEADER else 34)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	shell.add_child(row)
	return row


func _cell(child: Control, ratio: float) -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = ratio
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(child)
	return box


func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label


## Small painted icons: Cup, Skull, Glass (hourglass), Arrow.
class Glyph extends Control:
	var kind := "Cup"
	var tint := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		match kind:
			"Cup":
				var cup := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.45, r * 0.05), c + Vector2(-r * 0.45, r * 0.05)])
				draw_colored_polygon(cup, tint)
				draw_arc(c + Vector2(-r * 0.7, -r * 0.45), r * 0.3, PI * 0.5, PI * 1.5, 10, tint, 2.0, true)
				draw_arc(c + Vector2(r * 0.7, -r * 0.45), r * 0.3, -PI * 0.5, PI * 0.5, 10, tint, 2.0, true)
				draw_rect(Rect2(c + Vector2(-r * 0.12, 0.0), Vector2(r * 0.24, r * 0.5)), tint)
				draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.5), Vector2(r, r * 0.25)), tint)
			"Skull":
				draw_circle(c + Vector2(0, -r * 0.15), r * 0.62, tint)
				draw_rect(Rect2(c + Vector2(-r * 0.35, r * 0.2), Vector2(r * 0.7, r * 0.45)), tint)
				var eye := Color(0.1, 0.1, 0.1)
				draw_circle(c + Vector2(-r * 0.25, -r * 0.15), r * 0.17, eye)
				draw_circle(c + Vector2(r * 0.25, -r * 0.15), r * 0.17, eye)
				draw_line(c + Vector2(-r * 0.9, r * 0.9), c + Vector2(r * 0.9, r * 0.5), tint, 2.0, true)
				draw_line(c + Vector2(r * 0.9, r * 0.9), c + Vector2(-r * 0.9, r * 0.5), tint, 2.0, true)
			"Glass":
				var top := PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.85), c + Vector2(r * 0.55, -r * 0.85), c])
				var bot := PackedVector2Array([c, c + Vector2(r * 0.55, r * 0.85), c + Vector2(-r * 0.55, r * 0.85)])
				draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[0]]), tint, 2.0, true)
				draw_colored_polygon(bot, Color(tint.r, tint.g, tint.b, 0.8))
				draw_polyline(PackedVector2Array([bot[0], bot[1], bot[2], bot[0]]), tint, 2.0, true)
			"Arrow":
				var pts := PackedVector2Array([c + Vector2(-r * 0.9, 0), c + Vector2(-r * 0.1, -r * 0.7), c + Vector2(-r * 0.1, -r * 0.3), c + Vector2(r * 0.9, -r * 0.3), c + Vector2(r * 0.9, r * 0.3), c + Vector2(-r * 0.1, r * 0.3), c + Vector2(-r * 0.1, r * 0.7)])
				draw_colored_polygon(pts, tint)


## Loot square: coin, trophy, or a gear piece (family colour, slot shape, +N).
class LootIcon extends Control:
	var loot: Dictionary = {}

	static func describe(entry: Dictionary) -> String:
		match str(entry.get("kind", "")):
			"coin":
				return "%d Koliseo coin" % int(entry.get("count", 1))
			"trophy":
				return "%d trophy" % int(entry.get("count", 1))
			"gear":
				return GearBag.item_label({"item_id": str(entry.get("item_id", "")), "plus": int(entry.get("plus", 0))})
		return ""

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.09, 0.09, 0.10))
		draw_rect(rect, Color(0.32, 0.33, 0.34), false, 1.5)
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.34
		var kind := str(loot.get("kind", ""))
		match kind:
			"coin":
				draw_circle(c, r, Color(0.86, 0.66, 0.20))
				draw_circle(c, r * 0.78, Color(1.0, 0.82, 0.34))
				MobileHub.paint_star(self, c, r * 0.55, Color(0.80, 0.56, 0.12))
			"trophy":
				var gold := Color(0.98, 0.80, 0.30)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.5, r * 0.1), c + Vector2(-r * 0.5, r * 0.1)]), gold)
				draw_rect(Rect2(c + Vector2(-r * 0.14, r * 0.1), Vector2(r * 0.28, r * 0.45)), gold)
				draw_rect(Rect2(c + Vector2(-r * 0.55, r * 0.55), Vector2(r * 1.1, r * 0.28)), gold.darkened(0.2))
			"gear":
				var item_id := str(loot.get("item_id", ""))
				var fam := GearBag.family_of(item_id)
				var tint: Color = CombatResult.FAMILY_TINT.get(fam, Color(0.7, 0.7, 0.7))
				_draw_slot(GearBag.slot_of(item_id), c, r, tint)
				var plus := int(loot.get("plus", 0))
				if plus > 0:
					draw_string(ThemeDB.fallback_font, Vector2(size.x - 16, size.y - 4), "+%d" % plus, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		var count := int(loot.get("count", 1))
		if count > 1:
			draw_string(ThemeDB.fallback_font, Vector2(3, 13), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	func _draw_slot(slot: String, c: Vector2, r: float, tint: Color) -> void:
		var dark := tint.darkened(0.45)
		match slot:
			"weapon":
				draw_line(c + Vector2(-r, r), c + Vector2(r * 0.8, -r * 0.8), dark, 6.0, true)
				draw_line(c + Vector2(-r, r), c + Vector2(r * 0.8, -r * 0.8), tint, 3.5, true)
				draw_line(c + Vector2(-r * 0.6, r * 0.1), c + Vector2(-r * 0.1, r * 0.6), tint, 3.0, true)
			"head":
				draw_arc(c + Vector2(0, r * 0.2), r * 0.85, PI, TAU, 16, tint, r * 0.5, true)
				draw_rect(Rect2(c + Vector2(-r, r * 0.2), Vector2(r * 2.0, r * 0.3)), dark)
			"chest":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.7), c + Vector2(r, -r * 0.7), c + Vector2(r * 0.7, r), c + Vector2(-r * 0.7, r)]), tint)
				draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r), dark, 2.0, true)
			"legs":
				draw_rect(Rect2(c + Vector2(-r * 0.8, -r), Vector2(r * 1.6, r * 0.5)), tint)
				draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.5), Vector2(r * 0.65, r * 1.5)), tint)
				draw_rect(Rect2(c + Vector2(r * 0.15, -r * 0.5), Vector2(r * 0.65, r * 1.5)), tint)
			"boots":
				draw_rect(Rect2(c + Vector2(-r * 0.5, -r), Vector2(r * 0.7, r * 1.4)), tint)
				draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.3), Vector2(r * 1.4, r * 0.6)), tint)
				draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.75), Vector2(r * 1.4, r * 0.15)), dark)
