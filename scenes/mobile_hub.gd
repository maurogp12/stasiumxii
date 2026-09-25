extends Control
class_name MobileHub

## Mobile-branch entry (`project.godot` `run/main_scene`).
## Koliseo is PvP into the five existing boards (class select, then a random
## hot-seat arena). Each Stasis door is one stub for one of those ids.
## `--dedicated`, `--class`, `--queue`, `--join`, and `--host` skip this
## screen and follow the class-select route (no map picker).

const MOBILE_HUB := "res://scenes/mobile_hub.tscn"
const STASIS_STUB := "res://scenes/stasis_stub.tscn"
const KOLISEO_SCENE := "res://scenes/class_select.tscn"
## Exact ship ids. Files live at art/maps/arena_colosseum_v2/tiled/{id}_15x15.*
const BIOME_IDS: Array[String] = ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const TAGS_ROOT := "res://art/maps/arena_colosseum_v2/tiled/"
## Fat hit targets on the 960×720 canvas. The stack fits that window, and
## the buttons grow when stretch aspect expand adds height (portrait).
const DOOR_MIN_HEIGHT := 72

## Biome id for the stub scene. Empty until a Stasis door is pressed.
static var pending_biome_id: String = ""

var _auto_launch: bool = true
var _doors: Array[Button] = []
var _door_ids: Array[String] = []


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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _auto_launch and boot_route(OS.get_cmdline_user_args()) != "picker":
		call_deferred("open_koliseo")
		return
	_build()


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
	get_tree().change_scene_to_file(STASIS_STUB)


func _build() -> void:
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

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var title := Label.new()
	title.text = "STASIUM XII"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(title)

	var blurb := Label.new()
	blurb.text = "Hub"
	blurb.add_theme_font_size_override("font_size", 18)
	blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(blurb)

	_add_door(col, "koliseo", "Koliseo", true)
	for map_id in BIOME_IDS:
		_add_door(col, map_id, "%s Stasis" % title_of(map_id), false)


func _add_door(parent: Node, door_id: String, label: String, koliseo: bool) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, DOOR_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.94))
	button.add_theme_color_override("font_pressed_color", Color(0.98, 0.96, 0.92))
	button.add_theme_stylebox_override("normal", _door_style(koliseo, false))
	button.add_theme_stylebox_override("hover", _door_style(koliseo, true))
	button.add_theme_stylebox_override("pressed", _door_style(koliseo, true))
	button.add_theme_stylebox_override("focus", _door_style(koliseo, true))
	if koliseo:
		button.pressed.connect(open_koliseo)
	else:
		button.pressed.connect(open_stasis.bind(door_id))
	parent.add_child(button)
	_doors.append(button)
	_door_ids.append(door_id)


func _door_style(koliseo: bool, lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if koliseo:
		style.bg_color = Color(0.50, 0.34, 0.14) if lit else Color(0.40, 0.26, 0.10)
		style.border_color = Color(0.93, 0.78, 0.42)
	else:
		style.bg_color = Color(0.20, 0.26, 0.32) if lit else Color(0.14, 0.18, 0.22)
		style.border_color = Color(0.55, 0.66, 0.74)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
