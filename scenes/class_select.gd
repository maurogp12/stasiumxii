extends Control

## Dedicated pre-match chrome. Pick a Locked class, Confirm, then Find Match.
## Roster ids come from SpellKits.LOCKED_ROSTER. Display names come from class_label.
## This scene does not define spells or passives. The server validates the class.
## Listen-host join skips this screen. Hot-seat never opens it from main.tscn.

const MAIN_SCENE := "res://main.tscn"
const LOBBY_SCENE := "res://scenes/online_lobby.tscn"

var _status: Label
var _seat_label: Label
var _reject: Label
var _queue_panel: Panel
var _queue_label: Label
var _class_buttons: Dictionary = {}
var _confirm_button: Button
var _find_button: Button
var _picked: String = ""
var _pending: bool = false
var _leaving: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not NetSession.connection_changed.is_connected(_on_connection):
		NetSession.connection_changed.connect(_on_connection)
	if not NetSession.class_selected.is_connected(_on_class_selected):
		NetSession.class_selected.connect(_on_class_selected)
	if not NetSession.class_rejected.is_connected(_on_class_rejected):
		NetSession.class_rejected.connect(_on_class_rejected)
	if not NetSession.matchmaking_changed.is_connected(_on_queue):
		NetSession.matchmaking_changed.connect(_on_queue)
	if not NetSession.match_found.is_connected(_on_match_found):
		NetSession.match_found.connect(_on_match_found)
	if not NetSession.state_changed.is_connected(_on_state):
		NetSession.state_changed.connect(_on_state)
	call_deferred("_sync")


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.08)
	add_child(bg)

	var col := VBoxContainer.new()
	col.position = Vector2(80, 64)
	col.size = Vector2(800, 600)
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var title := Label.new()
	title.text = "STASIUM XII — choose your fighter"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(title)

	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "Locked roster: Kestrel, Ironjaw, Mender, Gloam, Bastion. Confirm sends the class to the server. Find Match queues you until the other seat is in. The server rejects anything outside this roster."
	blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(blurb)

	_seat_label = Label.new()
	_seat_label.add_theme_font_size_override("font_size", 16)
	_seat_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
	col.add_child(_seat_label)

	_add_roster_rows(col)

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
	var splits: Array[int] = [3, ids.size()]
	var start := 0
	for split in splits:
		if start >= ids.size():
			break
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)
		var end := mini(split, ids.size())
		for i in range(start, end):
			var class_id := str(ids[i])
			var button := _class_button(SpellKits.class_label(class_id), _roster_color(class_id))
			button.pressed.connect(_on_pick.bind(class_id))
			row.add_child(button)
			_class_buttons[class_id] = button
		start = end


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


func _sync() -> void:
	if _leaving:
		return
	if not NetSession.is_client():
		_go_main()
		return
	if not NetSession.awaiting_class_select():
		_go_main()
		return
	_refresh_buttons()


func _refresh_buttons() -> void:
	var seat := int(NetSession.local_seat)
	if seat < 0:
		_seat_label.text = "Connecting… waiting for a seat."
	else:
		_seat_label.text = "Seat %d" % seat
	var queued := NetSession.queue_status == "waiting" or NetSession.queue_status == "matched"
	for class_id in _class_buttons.keys():
		var button: Button = _class_buttons[class_id]
		button.disabled = queued or _pending
		button.modulate = Color(1.15, 1.12, 1.05) if _picked == str(class_id) else Color(0.72, 0.72, 0.72)
	_confirm_button.disabled = queued or _pending or _picked == "" or seat < 0
	var confirmed := NetSession.confirmed_class_id != ""
	_find_button.disabled = queued or not confirmed
	_queue_panel.visible = NetSession.queue_status == "waiting"
	if NetSession.queue_status == "waiting":
		_status.text = "Queued. Waiting for an opponent."
	elif confirmed and _reject.text == "" and not _pending:
		_status.text = "Server accepted %s. Find Match when you are ready." % SpellKits.class_label(NetSession.confirmed_class_id)


func _on_pick(class_id: String) -> void:
	_picked = class_id
	_reject.text = ""
	_refresh_buttons()


func _on_confirm() -> void:
	if _picked == "":
		return
	_pending = true
	_reject.text = ""
	_status.text = "Sending %s to the server…" % SpellKits.class_label(_picked)
	_refresh_buttons()
	var result: Dictionary = NetSession.select_class(_picked)
	if not bool(result.get("pending", false)) and not bool(result.get("ok", false)):
		_pending = false
		_show_reject(str(result.get("reason", "invalid_class")), str(result.get("class_id", _picked)))


func _on_find_match() -> void:
	_status.text = "Entering queue…"
	var result: Dictionary = NetSession.enter_matchmaking()
	if bool(result.get("pending", false)):
		return
	if not bool(result.get("ok", false)):
		_show_reject(str(result.get("reason", "class_not_confirmed")), str(result.get("class_id", "")))
		return
	if str(result.get("status", "")) == "waiting":
		_on_queue("waiting")


func _on_class_selected(class_id: String) -> void:
	_pending = false
	_reject.text = ""
	_picked = class_id
	_status.text = "Server accepted %s." % SpellKits.class_label(class_id)
	_refresh_buttons()


func _on_class_rejected(reason: String, class_id: String) -> void:
	_pending = false
	_show_reject(reason, class_id)


func _on_queue(status: String) -> void:
	if status == "waiting":
		_status.text = "Queued. Waiting for an opponent."
		_queue_panel.visible = true
	elif status == "matched":
		_status.text = "Match assigned."
		_queue_panel.visible = false
	_refresh_buttons()


func _on_match_found(_snapshot: Dictionary) -> void:
	_status.text = "Match assigned."
	_go_main()


func _on_state(_events: Array, _snapshot: Dictionary) -> void:
	_sync()


func _on_connection(status: String) -> void:
	if status == "join_failed":
		_status.text = "Join failed."
		_reject.text = "Could not reach the server."
	elif status == "host_left":
		_status.text = "Server disconnected."
	elif status == "joined" or status == "connecting":
		_status.text = "Connected. Waiting for a seat."
	_refresh_buttons()


func _show_reject(reason: String, class_id: String) -> void:
	var who := SpellKits.class_label(class_id)
	if who == "":
		who = class_id if class_id != "" else "that class"
	match reason:
		"invalid_class":
			_reject.text = "Server rejected %s." % who
		"no_seat":
			_reject.text = "Server rejected the class: no seat yet."
		"not_connected":
			_reject.text = "Server rejected the class: not connected."
		"already_queued":
			_reject.text = "Server rejected a class change: already queued."
		"class_not_confirmed":
			_reject.text = "Server rejected queue: confirm a class first."
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
