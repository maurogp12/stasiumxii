extends CanvasLayer

## City HUD: the place name card, the clock, and a short controls line.
## Style (Luca's reference): dark semi-transparent panels, thin gold borders,
## serif type.

const CombatSimScript := preload("res://backend/combat_sim.gd")
const GOLD := Color(0.83, 0.68, 0.38)
const ELEMENT_COL := {"earth": Color(0.72, 0.55, 0.3), "air": Color(0.6, 0.85, 0.85), "water": Color(0.4, 0.65, 0.95), "fire": Color(0.95, 0.45, 0.25), "neutral": Color(0.8, 0.8, 0.75)}
const PANEL := Color(0.06, 0.05, 0.04, 0.72)

var main
var _clock: Label
var _title: Label
var _help: Label
var _hotbar: HBoxContainer
var _classbar: HBoxContainer
var _portrait_name: Label
var _hp: ProgressBar
var _apmp: Label
var _minimap: TextureRect
var _map_dot: ColorRect
var _tip: Label
var _font: Font


static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func serif() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Cormorant Garamond", "EB Garamond", "Georgia", "DejaVu Serif", "Liberation Serif", "serif"])
	return f


func setup(m) -> void:
	main = m
	var font := serif()
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", panel_style())
	top.position = Vector2(24, 20)
	add_child(top)
	var v := VBoxContainer.new()
	top.add_child(v)
	_title = Label.new()
	_title.text = str(main.plan.city.get("name", "City"))
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.97, 0.9, 0.75))
	v.add_child(_title)
	_clock = Label.new()
	_clock.add_theme_font_override("font", font)
	_clock.add_theme_font_size_override("font_size", 18)
	_clock.add_theme_color_override("font_color", GOLD)
	v.add_child(_clock)
	_font = font
	_build_class_bar()
	_build_hotbar()
	_build_portrait()
	_build_minimap()
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", panel_style())
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -40
	bottom.offset_left = 360
	bottom.visible = false
	add_child(bottom)
	_help = Label.new()
	_help.text = "Click: walk   Shift: run   Right-drag / Q E: orbit   Wheel: zoom   WASD: pan   Space: follow   T: +1 h   N: day / dusk / night"
	_help.add_theme_font_override("font", font)
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	bottom.add_child(_help)


func _label(text: String, size: int, col := Color(0.95, 0.9, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	var n := panel_style()
	n.bg_color = Color(0.1, 0.08, 0.06, 0.85)
	var h := panel_style()
	h.bg_color = Color(0.22, 0.17, 0.1, 0.9)
	h.border_color = Color(1.0, 0.85, 0.5)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", n)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Class picker (top centre): the hero can be any of the 5 classes.
func _build_class_bar() -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", panel_style())
	pc.anchor_left = 0.5
	pc.anchor_right = 0.5
	pc.offset_left = -260
	pc.offset_top = 16
	add_child(pc)
	_classbar = HBoxContainer.new()
	_classbar.add_theme_constant_override("separation", 6)
	pc.add_child(_classbar)
	for cls in SpellKits.LOCKED_ROSTER:
		var b := _button(SpellKits.display_name(cls))
		b.pressed.connect(func(): main.set_class(cls))
		_classbar.add_child(b)


## Hotbar (bottom centre): the class's real spells from the kit, AP/MP, End Turn.
func _build_hotbar() -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", panel_style())
	pc.anchor_left = 0.5
	pc.anchor_right = 0.5
	pc.anchor_top = 1.0
	pc.anchor_bottom = 1.0
	pc.offset_left = -330
	pc.offset_top = -92
	pc.offset_bottom = -16
	add_child(pc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pc.add_child(row)
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 6)
	row.add_child(_hotbar)
	_apmp = _label("", 18, GOLD)
	_apmp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_apmp)
	var end := _button("End Turn")
	end.disabled = true
	end.tooltip_text = "Combat only"
	row.add_child(end)
	_tip = _label("", 15)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", panel_style())
	tp.anchor_left = 0.5
	tp.anchor_right = 0.5
	tp.anchor_top = 1.0
	tp.anchor_bottom = 1.0
	tp.offset_left = -330
	tp.offset_top = -210
	tp.offset_bottom = -100
	tp.visible = false
	tp.add_child(_tip)
	add_child(tp)


func set_class(cls: String) -> void:
	for c in _hotbar.get_children():
		c.queue_free()
	var tip_panel: Control = _tip.get_parent()
	for sid in SpellKits.class_spells(cls):
		var d: Dictionary = SpellKits.spell(sid)
		var b := _button("%s\n%d AP" % [str(d.get("name", sid)), int(d.get("ap", 0))])
		b.custom_minimum_size = Vector2(104, 56)
		var el := str(d.get("element", "neutral"))
		b.add_theme_color_override("font_color", (ELEMENT_COL.get(el, Color.WHITE) as Color).lightened(0.25))
		b.mouse_entered.connect(func():
			_tip.text = spell_tip(sid)
			tip_panel.visible = true)
		b.mouse_exited.connect(func(): tip_panel.visible = false)
		b.pressed.connect(func(): main.preview_spell(sid))
		_hotbar.add_child(b)
	_apmp.text = "%d AP  ·  %d MP" % [CombatSimScript.MAX_AP, CombatSimScript.MAX_MP]
	_portrait_name.text = SpellKits.display_name(cls)
	for b in _classbar.get_children():
		(b as Button).modulate = Color(1, 1, 1) if (b as Button).text == SpellKits.display_name(cls) else Color(0.7, 0.7, 0.7)


## Tooltip: damage, element, AP cost and range, straight from the kit.
static func spell_tip(sid: String) -> String:
	var d: Dictionary = SpellKits.spell(sid)
	var lines: PackedStringArray = []
	lines.append(str(d.get("name", sid)))
	var el := str(d.get("element", "neutral")).capitalize()
	var dmg := int(d.get("base_damage", 0))
	if dmg > 0:
		lines.append("%d %s damage%s" % [dmg, el, "  ·  can miss or crit" if bool(d.get("rolls", false)) else ""])
	else:
		lines.append("%s" % el)
	lines.append("%d AP  ·  %s" % [int(d.get("ap", 0)), SpellKits.range_text(d)])
	var eng := str(d.get("engine_on_connect", ""))
	if eng != "":
		lines.append("On connect: %s" % eng.replace("_", " "))
	return "\n".join(lines)


## Round portrait with HP (bottom left).
func _build_portrait() -> void:
	var pc := PanelContainer.new()
	var sb := panel_style()
	sb.set_corner_radius_all(44)
	pc.add_theme_stylebox_override("panel", sb)
	pc.anchor_top = 1.0
	pc.anchor_bottom = 1.0
	pc.offset_left = 24
	pc.offset_top = -120
	pc.offset_right = 300
	pc.offset_bottom = -16
	add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	_portrait_name = _label("", 24)
	v.add_child(_portrait_name)
	_hp = ProgressBar.new()
	_hp.max_value = CombatSimScript.START_HP
	_hp.value = CombatSimScript.START_HP
	_hp.show_percentage = false
	_hp.custom_minimum_size = Vector2(220, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.12, 0.1)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.04, 0.9)
	bg.border_color = GOLD
	bg.set_border_width_all(1)
	_hp.add_theme_stylebox_override("fill", fill)
	_hp.add_theme_stylebox_override("background", bg)
	v.add_child(_hp)
	v.add_child(_label("%d / %d HP" % [CombatSimScript.START_HP, CombatSimScript.START_HP], 14, GOLD))


## Minimap (top right): the layout drawn once, the hero as a dot.
func _build_minimap() -> void:
	var plan = main.plan
	var img := Image.create(plan.width, plan.height, false, Image.FORMAT_RGBA8)
	var cols := {"g": Color(0.25, 0.38, 0.15), "d": Color(0.45, 0.35, 0.22), "c": Color(0.62, 0.56, 0.46), "p": Color(0.72, 0.66, 0.54), "w": Color(0.2, 0.45, 0.6), ".": Color(0.2, 0.3, 0.13)}
	for y in plan.height:
		for x in plan.width:
			var c := Vector2i(x, y)
			var col: Color = cols.get(plan.terrain_char(c), Color.BLACK)
			if plan.wall_cells.has(c):
				col = Color(0.55, 0.55, 0.55)
			elif not plan.passable(c) and plan.terrain_char(c) != "w" and plan.terrain_char(c) != ".":
				col = Color(0.45, 0.2, 0.15)
			img.set_pixel(x, y, col)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", panel_style())
	pc.anchor_left = 1.0
	pc.anchor_right = 1.0
	pc.offset_left = -272
	pc.offset_top = 16
	pc.offset_right = -16
	add_child(pc)
	_minimap = TextureRect.new()
	_minimap.texture = ImageTexture.create_from_image(img)
	_minimap.custom_minimum_size = Vector2(228, 228)
	_minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pc.add_child(_minimap)
	_map_dot = ColorRect.new()
	_map_dot.color = Color(1.0, 0.85, 0.3)
	_map_dot.size = Vector2(7, 7)
	_minimap.add_child(_map_dot)


func _process(_d: float) -> void:
	if main == null or main.hero == null or _minimap == null:
		return
	var c: Vector2 = main.hero.ground_pos() / (main.plan.cell_m * Vector2(main.plan.width, main.plan.height))
	_map_dot.position = c * _minimap.size - Vector2(3.5, 3.5)


func set_hour(h: float) -> void:
	if _clock == null:
		return
	var hh := int(h)
	var mm := int((h - hh) * 60.0)
	var part := "Night"
	if h >= 5.5 and h < 11.0:
		part = "Morning"
	elif h >= 11.0 and h < 17.0:
		part = "Day"
	elif h >= 17.0 and h < 20.5:
		part = "Dusk"
	_clock.text = "%s  ·  %02d:%02d" % [part, hh, mm]


func set_visible_all(on: bool) -> void:
	visible = on
