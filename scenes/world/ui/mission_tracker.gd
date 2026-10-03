extends CanvasLayer

## Active missions and the next step, top-right. A reward line stays up
## after a turn-in so the level-up is visible. Preload. No global class.

var missions = null
var progress = null
var _root: Control
var _card: PanelContainer
var _body: Label
var _reward_card: PanelContainer
var _reward: Label
var _hold := false
var _rows_hidden := false

const ROW_CAP := 5


func setup(book, hero) -> void:
	missions = book
	progress = hero
	refresh()


func refresh() -> void:
	ensure_built()
	if missions == null or progress == null:
		_body.text = ""
		return
	if _rows_hidden:
		return
	var rows: Array = missions.tracker_rows(progress)
	if rows.is_empty():
		_body.text = "No active mission"
		return
	var shown := rows.size()
	if shown > ROW_CAP:
		shown = ROW_CAP
	var text := ""
	for index in shown:
		var record: Dictionary = rows[index]
		if text != "":
			text += "\n"
		text += str(record["name"]) + "\n" + str(record["step"])
	if rows.size() > ROW_CAP:
		text += "\n+%d more · J" % (rows.size() - ROW_CAP)
	_body.text = text


func show_reward(result: Dictionary, hold: bool) -> void:
	ensure_built()
	_hold = hold
	if not bool(result.get("ok", false)):
		return
	var text := "+%d XP" % int(result.get("xp", 0))
	var coins := int(result.get("coins", 0))
	if coins > 0:
		text += "\n+%d Crypto Coins" % coins
	var events: Array = result.get("events", [])
	if not events.is_empty():
		var last: Dictionary = events[events.size() - 1]
		text += "\nLevel %d" % int(last["level"])
	_reward.text = text
	_reward_card.visible = true
	# The corner card is the one the frame always shows. Keep the payout there too.
	_rows_hidden = true
	_body.text = text
	if _hold:
		return
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_callback(restore_rows)


func restore_rows() -> void:
	if _hold:
		return
	_rows_hidden = false
	if _reward_card != null:
		_reward_card.visible = false
	refresh()


func ensure_built() -> void:
	if _root != null:
		return
	layer = 15
	_root = Control.new()
	_root.name = "MissionTracker"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.offset_left = -360
	_card.offset_top = 18
	_card.offset_right = -16
	_card.offset_bottom = 188
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(_card)
	_body = Label.new()
	_body.name = "Steps"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 18)
	_body.add_theme_color_override("font_color", Color(1, 0.95, 0.86))
	_card.add_child(_body)
	_reward_card = PanelContainer.new()
	_reward_card.name = "RewardCard"
	_reward_card.visible = false
	_reward_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reward_card.offset_left = -280
	_reward_card.offset_top = 150
	_reward_card.offset_right = 280
	_reward_card.offset_bottom = 340
	_reward_card.add_theme_stylebox_override("panel", _card_style())
	_root.add_child(_reward_card)
	_reward = Label.new()
	_reward.name = "Reward"
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.add_theme_font_size_override("font_size", 40)
	_reward.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	_reward.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	_reward.add_theme_constant_override("outline_size", 8)
	_reward_card.add_child(_reward)


func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.08, 0.06, 0.82)
	box.border_color = Color(0.72, 0.58, 0.32)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
