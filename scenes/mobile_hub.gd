extends Control
class_name MobileHub

## Mobile-branch entry (`project.godot` `run/main_scene`).
## The hub is Luca's menu: a Koliseo banner over a RAID row of five
## Stasis portraits. Koliseo is PvP into the five existing boards (class
## select, then a random hot-seat arena). Each Stasis tile opens that
## biome's mobile dungeon (scenes/stasis_run.tscn). Do not wire these
## scenes into PC main.
## `--dedicated`, `--class`, `--queue`, `--join`, and `--host` skip this
## screen and follow the class-select route (no map picker).

const MOBILE_HUB := "res://scenes/mobile_hub.tscn"
const _TOUCH := preload("res://ui/touch_adapter.gd")
const STASIS_RUN := "res://scenes/stasis_run.tscn"
const KOLISEO_SCENE := "res://scenes/class_select.tscn"
## Exact ship ids. Files live at art/maps/arena_colosseum_v2/tiled/{id}_15x15.*
const BIOME_IDS: Array[String] = ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const TAGS_ROOT := "res://art/maps/arena_colosseum_v2/tiled/"
const HUB_FONT := "res://art/ui/hub/Cinzel-Semibold.ttf"
const BANNER_ART := "res://art/ui/hub/koliseo_banner.png"
## Fat hit targets on the 960×720 canvas. The phone stays landscape, so
## this poster is a wide banner over one horizontal RAID row.
const DOOR_MIN_HEIGHT := 72
const _ApkClient := preload("res://backend/apk_update_client.gd")

const NAVY := Color(0.008, 0.028, 0.07)
const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)

## Biome id for the stub scene. Empty until a Stasis door is pressed.
static var pending_biome_id: String = ""

var _auto_launch: bool = true
var _doors: Array[Button] = []
var _door_ids: Array[String] = []
var _font: Font
var _title_row: Control
var _banner: Button
var _raid_row: Control
var _footer: Control
var _update_button: Button
var _update_status: Label
var _update_client: ApkUpdateClient
var _banner_ratio: float = 1536.0 / 510.0
var _tile_ratio: float = 292.0 / 410.0


static func boot_route(args: PackedStringArray) -> String:
	var net: Script = load("res://backend/net_session.gd")
	var select: Script = load("res://scenes/class_select.gd")
	return select.route_for_plan(net.plan_from_args(args))


static func is_biome_id(map_id: String) -> bool:
	return BIOME_IDS.has(map_id.strip_edges().to_lower())


## Title Case of the id itself (`crosshaven` → `Crosshaven`). Not a second name.
static func title_of(map_id: String) -> String:
	var id := map_id.strip_edges().to_lower()
	if not BIOME_IDS.has(id):
		return ""
	return id.substr(0, 1).to_upper() + id.substr(1)


static func tags_path(map_id: String) -> String:
	var id := map_id.strip_edges().to_lower()
	if not BIOME_IDS.has(id):
		return ""
	return TAGS_ROOT + "%s_15x15_tags.json" % id


static func raid_art_path(map_id: String) -> String:
	var id := map_id.strip_edges().to_lower()
	if not BIOME_IDS.has(id):
		return ""
	return "res://art/ui/hub/raid_%s.png" % id


static func paint_star(canvas: CanvasItem, center: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	var inner := radius * 0.36
	for i in 8:
		var angle := -PI * 0.5 + float(i) * PI * 0.25
		var reach := radius if i % 2 == 0 else inner
		points.append(center + Vector2(cos(angle), sin(angle)) * reach)
	canvas.draw_colored_polygon(points, tint)
	canvas.draw_circle(center, maxf(radius * 0.14, 0.8), tint.lightened(0.45))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_TOUCH.lock_landscape_frame(get_window())
	resized.connect(_on_resized)
	if _auto_launch and boot_route(OS.get_cmdline_user_args()) != "picker":
		call_deferred("open_koliseo")
		return
	_build()


func _on_resized() -> void:
	_layout()
	queue_redraw()


func door_count() -> int:
	return _doors.size()


func door_id(index: int) -> String:
	if index < 0 or index >= _door_ids.size():
		return ""
	return _door_ids[index]


func door_text(index: int) -> String:
	if index < 0 or index >= _doors.size():
		return ""
	return _doors[index].text


func open_koliseo() -> void:
	pending_biome_id = ""
	if not _auto_launch:
		return
	get_tree().change_scene_to_file(KOLISEO_SCENE)


func open_stasis(map_id: String) -> void:
	var id := map_id.strip_edges().to_lower()
	if not BIOME_IDS.has(id):
		return
	pending_biome_id = id
	if not _auto_launch:
		return
	get_tree().change_scene_to_file(STASIS_RUN)


func _draw() -> void:
	var extents := size
	if extents.x < 2.0 or extents.y < 2.0:
		return
	draw_rect(Rect2(Vector2.ZERO, extents), NAVY)
	var inset := 11.0
	var frame := Rect2(inset, inset, extents.x - inset * 2.0, extents.y - inset * 2.0)
	draw_rect(frame, GOLD_DIM, false, 1.15)
	_draw_corners(frame)


func _build() -> void:
	_font = _load_font()
	_title_row = _make_title_row()
	add_child(_title_row)
	var banner_tex := load(BANNER_ART) as Texture2D
	if banner_tex != null and banner_tex.get_height() > 0:
		_banner_ratio = float(banner_tex.get_width()) / float(banner_tex.get_height())
	_banner = _make_art_button("Koliseo", banner_tex, true)
	_banner.pressed.connect(open_koliseo)
	add_child(_banner)
	_remember_door(_banner, "koliseo")
	_raid_row = _make_raid_header()
	add_child(_raid_row)
	var sample := load(raid_art_path(BIOME_IDS[0])) as Texture2D
	if sample != null and sample.get_height() > 0:
		_tile_ratio = float(sample.get_width()) / float(sample.get_height())
	for map_id in BIOME_IDS:
		var tex := load(raid_art_path(map_id)) as Texture2D
		var button := _make_art_button("%s Stasis" % title_of(map_id), tex, false)
		button.pressed.connect(open_stasis.bind(map_id))
		add_child(button)
		_remember_door(button, map_id)
	_footer = FooterRule.new()
	add_child(_footer)
	_update_client = _ApkClient.new()
	_update_client.name = "ApkUpdate"
	_update_client.status_changed.connect(_set_update_status)
	_update_client.busy_changed.connect(_set_update_busy)
	add_child(_update_client)
	_layout()


func _remember_door(button: Button, door_id: String) -> void:
	_doors.append(button)
	_door_ids.append(door_id)


func _layout() -> void:
	if _title_row == null:
		return
	var extents := size
	if extents.x < 64.0 or extents.y < 64.0:
		return
	var margin := 18.0
	var left := margin
	var width := extents.x - margin * 2.0
	var top := margin
	var bottom_limit := extents.y - margin
	var title_h := 52.0
	var raid_h := 28.0
	var footer_h := 18.0
	var gap := 8.0
	var tile_gap := 8.0
	var tile_w := (width - tile_gap * 4.0) / 5.0
	var tile_h := tile_w / _tile_ratio
	var banner_h := width / _banner_ratio
	var cluster := title_h + gap + banner_h + gap + raid_h + gap + tile_h
	var room := bottom_limit - footer_h - gap - top
	if cluster > room and cluster > 0.0:
		var scale := room / cluster
		banner_h *= scale
		tile_h *= scale
		title_h *= clampf(scale + 0.15, 0.7, 1.0)
		var fitted := tile_h * _tile_ratio
		if fitted < tile_w:
			tile_w = fitted
		cluster = title_h + gap + banner_h + gap + raid_h + gap + tile_h
	var extra := maxf(room - cluster, 0.0)
	# Keep the poster under the top frame. Extra space sits around the
	# plates instead of stretching them. The Koliseo plate keeps the
	# art's aspect so the lineup and the KOLISEO label stay in frame.
	var y := top + minf(extra * 0.08, 28.0)
	_title_row.position = Vector2(left, y)
	_title_row.size = Vector2(width, title_h)
	y += title_h + gap
	var banner_w := width
	if _banner_ratio > 0.0:
		var fitted_w := banner_h * _banner_ratio
		if fitted_w < width:
			banner_w = fitted_w
	_banner.position = Vector2(left + (width - banner_w) * 0.5, y)
	_banner.size = Vector2(banner_w, maxf(banner_h, float(DOOR_MIN_HEIGHT)))
	y += _banner.size.y + gap
	_raid_row.position = Vector2(left, y)
	_raid_row.size = Vector2(width, raid_h)
	y += raid_h + gap
	var row_w := tile_w * 5.0 + tile_gap * 4.0
	var row_x := left + (width - row_w) * 0.5
	var tile_index := 0
	for index in _doors.size():
		if _door_ids[index] == "koliseo":
			continue
		var tile := _doors[index]
		tile.position = Vector2(row_x + float(tile_index) * (tile_w + tile_gap), y)
		tile.size = Vector2(tile_w, maxf(tile_h, float(DOOR_MIN_HEIGHT)))
		tile_index += 1
	_footer.position = Vector2(left, bottom_limit - footer_h)
	_footer.size = Vector2(width, footer_h)


func _make_title_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star := StarMark.new()
	star.radius = 9.0
	star.custom_minimum_size = Vector2(22, 22)
	row.add_child(star)
	var title := Label.new()
	title.text = "STASIUM XII"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font != null:
		title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	row.add_child(title)
	var rule := GoldRule.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rule)
	_update_button = _make_update_button()
	row.add_child(_update_button)
	return row


func _make_raid_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swords := SwordMark.new()
	swords.custom_minimum_size = Vector2(22, 22)
	row.add_child(swords)
	var label := Label.new()
	label.text = "RAID"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GOLD)
	row.add_child(label)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var status := Label.new()
	status.name = "UpdateStatus"
	status.text = ""
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _font != null:
		status.add_theme_font_override("font", _font)
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", GOLD)
	row.add_child(status)
	_update_status = status
	return row


func _make_art_button(label: String, tex: Texture2D, framed: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, DOOR_MIN_HEIGHT)
	button.clip_contents = true
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, empty)
	if framed:
		button.add_theme_stylebox_override("normal", _banner_style(false))
		button.add_theme_stylebox_override("hover", _banner_style(true))
		button.add_theme_stylebox_override("pressed", _banner_style(false))
		button.add_theme_stylebox_override("focus", _banner_style(true))
	if tex == null:
		return button
	var hidden := Color(0, 0, 0, 0)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color_name, hidden)
	var plate := TextureRect.new()
	plate.name = "Art"
	plate.texture = tex
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if framed else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if framed:
		plate.offset_left = 1
		plate.offset_top = 1
		plate.offset_right = -1
		plate.offset_bottom = -1
	button.add_child(plate)
	button.mouse_entered.connect(_tint_art.bind(plate, Color(1.07, 1.045, 0.98)))
	button.mouse_exited.connect(_tint_art.bind(plate, Color.WHITE))
	button.button_down.connect(_tint_art.bind(plate, Color(0.8, 0.76, 0.68)))
	button.button_up.connect(_tint_art.bind(plate, Color.WHITE))
	button.focus_entered.connect(_tint_art.bind(plate, Color(1.08, 1.05, 0.96)))
	button.focus_exited.connect(_tint_art.bind(plate, Color.WHITE))
	return button


func _on_update_pressed() -> void:
	if _update_client != null and _update_client.has_method("start"):
		_update_client.start()


func _set_update_status(text: String) -> void:
	if _update_status != null:
		_update_status.text = text


func _set_update_busy(busy: bool) -> void:
	if _update_button != null:
		_update_button.disabled = busy


func _make_update_button() -> Button:
	var button := Button.new()
	button.name = "Actualizar"
	button.text = "Actualizar"
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(168, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", GOLD_DIM)
	button.add_theme_stylebox_override("normal", _update_style(false))
	button.add_theme_stylebox_override("hover", _update_style(true))
	button.add_theme_stylebox_override("pressed", _update_style(false))
	button.add_theme_stylebox_override("focus", _update_style(true))
	button.add_theme_stylebox_override("disabled", _update_style(false))
	button.pressed.connect(_on_update_pressed)
	return button


func _update_style(lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.09, 0.94)
	style.border_color = GOLD_BRIGHT if lit else GOLD
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _banner_style(lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = GOLD_BRIGHT if lit else GOLD
	style.set_border_width_all(1)
	return style


func _tint_art(plate: TextureRect, tint: Color) -> void:
	plate.self_modulate = tint


func _load_font() -> Font:
	var loaded := load(HUB_FONT) as Font
	if loaded == null:
		return null
	var font := loaded.duplicate() as Font
	if font == null:
		font = loaded
	if font.has_method("set_extra_spacing"):
		font.set_extra_spacing(0, TextServer.SPACING_GLYPH, 2)
	return font


func _draw_corners(frame: Rect2) -> void:
	var corners: Array[Vector2] = [
		frame.position,
		Vector2(frame.end.x, frame.position.y),
		frame.end,
		Vector2(frame.position.x, frame.end.y),
	]
	var signs: Array[Vector2] = [
		Vector2(1, 1),
		Vector2(-1, 1),
		Vector2(-1, -1),
		Vector2(1, -1),
	]
	for i in 4:
		_draw_bracket(corners[i], signs[i], 20.0, GOLD, 1.6)
		_draw_bracket(corners[i] + signs[i] * 4.0, signs[i], 11.0, GOLD_DIM, 1.05)


func _draw_bracket(origin: Vector2, direction: Vector2, length: float, tint: Color, width: float) -> void:
	draw_line(origin, origin + Vector2(direction.x, 0.0) * length, tint, width, true)
	draw_line(origin, origin + Vector2(0.0, direction.y) * length, tint, width, true)


class StarMark extends Control:
	var radius: float = 7.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		MobileHub.paint_star(self, size * 0.5, radius, Color(0.93, 0.8, 0.48))


class GoldRule extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(24, 8)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := size.y * 0.55
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.72, 0.58, 0.34, 0.9), 1.05, true)


class SwordMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var tint := Color(0.86, 0.7, 0.4)
		var center := size * 0.5
		_sword(center + Vector2(-7.0, -8.0), center + Vector2(6.5, 7.5), tint)
		_sword(center + Vector2(7.0, -8.0), center + Vector2(-6.5, 7.5), tint)

	func _sword(hilt: Vector2, tip: Vector2, tint: Color) -> void:
		var direction := (tip - hilt).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var guard := hilt.lerp(tip, 0.58)
		draw_line(hilt, tip, tint, 1.7, true)
		draw_line(guard - normal * 3.4, guard + normal * 3.4, tint, 1.45, true)
		draw_circle(hilt, 1.35, tint)


class FooterRule extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := size.y * 0.5
		var mid := size.x * 0.5
		var tint := Color(0.75, 0.6, 0.35, 0.95)
		draw_line(Vector2(0, y), Vector2(mid - 16.0, y), tint, 1.05, true)
		draw_line(Vector2(mid + 16.0, y), Vector2(size.x, y), tint, 1.05, true)
		MobileHub.paint_star(self, Vector2(mid, y), 6.5, Color(0.93, 0.8, 0.48))
