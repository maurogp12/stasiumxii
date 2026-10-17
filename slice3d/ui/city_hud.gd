extends CanvasLayer

## City HUD: the place name card, the clock, and a short controls line.
## Style (Luca's reference): dark semi-transparent panels, thin gold borders,
## serif type.

const GOLD := Color(0.83, 0.68, 0.38)
const PANEL := Color(0.06, 0.05, 0.04, 0.72)

var main
var _clock: Label
var _title: Label
var _help: Label


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
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", panel_style())
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -48
	bottom.offset_left = 24
	add_child(bottom)
	_help = Label.new()
	_help.text = "Click: walk   Shift: run   Right-drag / Q E: orbit   Wheel: zoom   WASD: pan   Space: follow   T: +1 h   N: day / dusk / night"
	_help.add_theme_font_override("font", font)
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	bottom.add_child(_help)


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
