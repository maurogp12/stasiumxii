extends CanvasLayer

## Reward pop-up after a fight, a dungeon or a mission. The window does not
## roll or store anything; it only shows the drop it is given.

var _root: Control
var _body: RichTextLabel


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _root != null:
		return
	layer = 40
	_root = Control.new()
	_root.name = "RewardPopup"
	_root.visible = false
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.06, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_top = -180
	panel.offset_right = 280
	panel.offset_bottom = 180
	panel.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(panel)
	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(480, 280)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_body)


func show_drop(drop: Dictionary, hero = null) -> void:
	ensure_built()
	var lines: PackedStringArray = ["[b]Victory[/b]", ""]
	var xp := int(drop.get("xp", 0))
	if xp > 0:
		lines.append("XP +%s" % str(xp))
	lines.append("Crypto Coins +%s" % str(int(drop.get("coins", 0))))
	var items: Variant = drop.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		for raw in items:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw
			var label := str(item.get("item_id", ""))
			if hero != null and hero.has_method("item_def"):
				var def: Dictionary = hero.item_def(label)
				if not def.is_empty():
					label = str(def.get("name", label))
			var count := int(item.get("count", 1))
			var rarity := str(item.get("rarity", "regular"))
			if count > 1:
				lines.append("%s x%s (%s)" % [label, str(count), rarity])
			else:
				lines.append("%s (%s)" % [label, rarity])
	if lines.size() == 2:
		lines.append("No items")
	_body.text = "\n".join(lines)
	_root.visible = true


func hide_drop() -> void:
	if _root != null:
		_root.visible = false


func is_open() -> bool:
	return _root != null and _root.visible


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.08, 0.96)
	style.border_color = Color(0.93, 0.76, 0.38)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style
