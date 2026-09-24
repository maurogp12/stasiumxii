extends Control

## Dedicated pre-match chrome. Pick a Locked class, Confirm, then Find Match.
## Confirm calls NetSession.select_class. Find Match joins the dedicated queue
## (rpc_select_class + rpc_enqueue on connect). Results arrive as
## connection_changed: class_selected, class_rejected, waiting, queue_rejected, matched.
## Allowlist is kestrel|ironjaw|mender|gloam|bastion. Nightfold stays gated.

const MAIN_SCENE := "res://main.tscn"
const LOBBY_SCENE := "res://scenes/online_lobby.tscn"

var _status: Label
var _reject: Label
var _queue_panel: Panel
var _queue_label: Label
var _join_ip: LineEdit
var _join_port: LineEdit
var _class_buttons: Dictionary = {}
var _confirm_button: Button
var _find_button: Button
var _picked: String = ""
var _leaving: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not NetSession.connection_changed.is_connected(_on_connection):
		NetSession.connection_changed.connect(_on_connection)
	_picked = NetSession.selected_class_id
	_refresh_buttons()
	if NetSession.match_assigned() and NetSession.is_queue_client():
		_go_main()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.08)
	add_child(bg)

	var col := VBoxContainer.new()
	col.position = Vector2(80, 48)
	col.size = Vector2(860, 640)
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var title := Label.new()
	title.text = "STASIUM XII — choose your fighter"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(title)

	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "Locked roster: Kestrel, Ironjaw, Mender, Gloam, Bastion. Confirm sends the class to the server. Find Match queues you until another confirmed player pairs."
	blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(blurb)

	_add_roster_rows(col)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	col.add_child(join_row)
	_join_ip = LineEdit.new()
	_join_ip.text = "127.0.0.1"
	_join_ip.custom_minimum_size = Vector2(180, 32)
	_join_port = LineEdit.new()
	_join_port.text = "7777"
	_join_port.custom_minimum_size = Vector2(90, 32)
	join_row.add_child(_join_ip)
	join_row.add_child(_join_port)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.custom_minimum_size = Vector2(180, 40)
	_confirm_button.pressed.connect(_on_confirm)
	actions.add_child(_confirm_button)
	_find_button = Button.new()
	_find_button.text = "Find Match"
	_find_button.custom_minimum_size = Vector2(180, 40)
	_find_button.pressed.connect(_on_find_match)
	actions.add_child(_find_button)

	_reject = Label.new()
	_reject.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reject.add_theme_color_override("font_color", Color(0.95, 0.45, 0.38))
	col.add_child(_reject)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	col.add_child(_status)

	_queue_panel = Panel.new()
	_queue_panel.custom_minimum_size = Vector2(520, 72)
	_queue_panel.visible = false
	col.add_child(_queue_panel)
	_queue_label = Label.new()
	_queue_label.position = Vector2(16, 16)
	_queue_label.size = Vector2(488, 40)
	_queue_label.text = "Queued. Waiting for an opponent."
	_queue_label.add_theme_font_size_override("font_size", 18)
	_queue_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	_queue_panel.add_child(_queue_label)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 36)
	back.pressed.connect(_on_back)
	col.add_child(back)
	_refresh_buttons()


func _add_roster_rows(col: VBoxContainer) -> void:
	var ids: Array = SpellKits.LOCKED_ROSTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var count := 0
	for class_id in ids:
		if count == 3:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			col.add_child(row)
		var button := _class_button(SpellKits.display_name(str(class_id)), _roster_color(str(class_id)))
		button.pressed.connect(_on_pick.bind(str(class_id)))
		row.add_child(button)
		_class_buttons[str(class_id)] = button
		count += 1


func _roster_color(class_id: String) -> Color:
	match class_id:
		SpellKits.CLASS_IRONJAW:
			return Color("#8B2E2E")
		SpellKits.CLASS_MENDER:
			return Color("#2E4A6E")
		SpellKits.CLASS_GLOAM:
			return Color("#4A3A62")
		SpellKits.CLASS_BASTION:
			return Color("#5C5648")
		_:
			return Color("#2E5A3C")


func _class_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(168, 56)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	return button


func _refresh_buttons() -> void:
	var live := NetSession.match_assigned()
	for class_id in _class_buttons.keys():
		var button: Button = _class_buttons[class_id]
		button.disabled = live
		button.modulate = Color(1.15, 1.12, 1.05) if _picked == str(class_id) else Color(0.72, 0.72, 0.72)
	_confirm_button.disabled = live or _picked == ""
	_find_button.disabled = live or not SpellKits.is_roster_class(NetSession.selected_class_id)
	_queue_panel.visible = NetSession.is_queue_client() and not live


func _on_pick(class_id: String) -> void:
	_picked = class_id
	_reject.text = ""
	_refresh_buttons()


func _on_confirm() -> void:
	if _picked == "":
		return
	_reject.text = ""
	_status.text = "Sending %s…" % SpellKits.display_name(_picked)
	var result: Dictionary = NetSession.select_class(_picked)
	if not bool(result.get("ok", false)):
		_show_reject(str(result.get("reason", "invalid_class")), _picked)
		return
	_status.text = "Class stored: %s. Find Match to join the queue." % SpellKits.display_name(str(result.get("class_id", _picked)))
	_refresh_buttons()


func _on_find_match() -> void:
	if not SpellKits.is_roster_class(NetSession.selected_class_id):
		_show_reject("invalid_class", _picked)
		return
	_status.text = "Entering queue…"
	if NetSession.is_queue_client():
		_queue_panel.visible = true
		return
	var result: Dictionary = NetSession.start_queue_client(_join_ip.text.strip_edges(), int(_join_port.text))
	if not bool(result.get("ok", false)):
		_show_reject(str(result.get("reason", "class_required")), NetSession.selected_class_id)
		return
	_status.text = "Connecting as %s…" % SpellKits.display_name(NetSession.selected_class_id)


func _on_connection(status: String) -> void:
	if _leaving:
		return
	if status == "class_selected":
		_reject.text = ""
		_status.text = NetSession.lobby_text
		_refresh_buttons()
	elif status == "class_rejected":
		_show_reject("invalid_class", _picked)
	elif status == "waiting":
		_reject.text = ""
		_status.text = "Queued. Waiting for an opponent."
		_queue_panel.visible = true
		_refresh_buttons()
	elif status == "queue_rejected":
		_show_reject("class_required", NetSession.selected_class_id)
	elif status == "matched":
		_status.text = "Match assigned."
		_queue_panel.visible = false
		_go_main()
	elif status == "join_failed":
		_status.text = "Join failed."
		_reject.text = "Could not reach the server."
	elif status == "host_left":
		_status.text = "Server disconnected."


func _show_reject(reason: String, class_id: String) -> void:
	var who := SpellKits.display_name(class_id)
	if who == "":
		who = class_id if class_id != "" else "that class"
	match reason:
		"invalid_class":
			_reject.text = "Server rejected %s." % who
		"class_required":
			_reject.text = "Server rejected queue: confirm a class first."
		"already_queued":
			_reject.text = "Server rejected a class change: already queued."
		"not_connected":
			_reject.text = "Server rejected the class: not connected."
		_:
			_reject.text = "Server rejected %s (%s)." % [who, reason]
	_status.text = ""
	_refresh_buttons()


func _on_back() -> void:
	if _leaving:
		return
	_leaving = true
	NetSession.return_to_hotseat()
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _go_main() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(MAIN_SCENE)
