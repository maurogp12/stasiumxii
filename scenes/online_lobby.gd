extends Control

## Anonymous lobby. Listen-host duel stays fixed (host Kestrel, guest Ironjaw).
## Dedicated queue: pick a class, then join. The host pairs two confirmed
## allowlist classes onto seats in queue order. Chrome still shows the
## other Locked cards; the server reject line is the response until the
## allowlist expands.

const MAIN_SCENE := "res://main.tscn"
const CLASS_SELECT_SCENE := "res://scenes/class_select.tscn"

var _status: Label
var _reject: Label
var _class_label: Label
var _host_port: LineEdit
var _join_ip: LineEdit
var _join_port: LineEdit
var _queue_btn: Button
var _class_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not NetSession.connection_changed.is_connected(_on_connection):
		NetSession.connection_changed.connect(_on_connection)
	if NetSession.is_dedicated() and NetSession.lobby_text != "":
		_status.text = NetSession.lobby_text
	elif NetSession.is_queue_client():
		_status.text = "Connecting as %s…" % SpellKits.display_name(NetSession.selected_class_id)
	else:
		_status.text = "Pick a class, then Join queue. Listen-host below stays Kestrel vs Ironjaw."
	_sync_class_buttons()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.08)
	add_child(bg)

	var col := VBoxContainer.new()
	col.position = Vector2(80, 36)
	col.size = Vector2(840, 660)
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var title := Label.new()
	title.text = "STASIUM XII — class select"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(title)

	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "Choose a Locked class, then Join queue. The dedicated host stores an allowlist class on your session and pairs the next two confirmed players. Other cards stay visible; the server reject line is the response until Backend expands the allowlist."
	blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(blurb)

	_add_class_rows(col)
	_class_label = Label.new()
	_class_label.text = "Class: none"
	col.add_child(_class_label)

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 8)
	col.add_child(host_row)
	_host_port = _field("7777")
	host_row.add_child(_label("Port"))
	host_row.add_child(_host_port)
	host_row.add_child(_button("Host dedicated", _on_dedicated))

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	col.add_child(join_row)
	_join_ip = _field("127.0.0.1")
	_join_ip.custom_minimum_size = Vector2(180, 32)
	_join_port = _field("7777")
	join_row.add_child(_label("Join IP"))
	join_row.add_child(_join_ip)
	join_row.add_child(_label("Port"))
	join_row.add_child(_join_port)
	_queue_btn = _button("Join queue", _on_queue)
	_queue_btn.disabled = true
	join_row.add_child(_queue_btn)

	_reject = Label.new()
	_reject.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reject.add_theme_color_override("font_color", Color(0.95, 0.45, 0.38))
	col.add_child(_reject)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	col.add_child(_status)

	var screen := _button("Class screen", _on_class_screen)
	col.add_child(screen)

	var legacy := Label.new()
	legacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legacy.text = "Listen-host duel (fixed seats: host is Kestrel, guest is Ironjaw). Class pick above is not used."
	legacy.add_theme_color_override("font_color", Color(0.62, 0.58, 0.54))
	col.add_child(legacy)

	var legacy_row := HBoxContainer.new()
	legacy_row.add_theme_constant_override("separation", 8)
	col.add_child(legacy_row)
	legacy_row.add_child(_button("Host match", _on_host))
	legacy_row.add_child(_button("Join match", _on_join))
	legacy_row.add_child(_button("Local hot-seat", _on_hotseat))


func _add_class_rows(col: VBoxContainer) -> void:
	var ids: Array = SpellKits.CHROME_ROSTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for class_id in ids:
		var button := _button(SpellKits.class_label(str(class_id)), _on_pick.bind(str(class_id)))
		button.custom_minimum_size = Vector2(140, 36)
		row.add_child(button)
		_class_buttons[str(class_id)] = button


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 36)
	button.pressed.connect(handler)
	return button


func _field(text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.custom_minimum_size = Vector2(90, 32)
	return edit


func _label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lab


func _on_pick(class_id: String) -> void:
	var result: Dictionary = NetSession.select_class(class_id)
	if not bool(result.get("ok", false)):
		_reject.text = _reject_line(str(result.get("reason", "invalid_class")), class_id)
		_status.text = ""
		_sync_class_buttons()
		return
	_reject.text = ""
	_class_label.text = "Class: %s" % SpellKits.display_name(str(result.get("class_id", "")))
	_status.text = "Class confirmed. Join queue, or host a dedicated match in another window."
	_sync_class_buttons()


func _sync_class_buttons() -> void:
	var picked := NetSession.selected_class_id
	_queue_btn.disabled = not SpellKits.is_roster_class(picked)
	for class_id in _class_buttons.keys():
		var button: Button = _class_buttons[class_id]
		button.modulate = Color(1.15, 1.12, 1.05) if picked == str(class_id) else Color.WHITE


func _on_dedicated() -> void:
	var port := int(_host_port.text)
	var result: Dictionary = NetSession.start_dedicated(port)
	if not bool(result.get("ok", false)):
		_status.text = "Dedicated host failed: %s (is the port free?)" % str(result.get("reason", "bind_failed"))
		return
	_status.text = NetSession.lobby_text


func _on_queue() -> void:
	if not SpellKits.is_roster_class(NetSession.selected_class_id):
		_reject.text = _reject_line("class_required", "")
		return
	var result: Dictionary = NetSession.start_queue_client(_join_ip.text.strip_edges(), int(_join_port.text))
	if not bool(result.get("ok", false)):
		_status.text = "Queue failed: %s" % str(result.get("reason", "class_required"))
		return
	_reject.text = ""
	_status.text = "Connecting as %s…" % SpellKits.display_name(NetSession.selected_class_id)


func _on_host() -> void:
	var port := int(_host_port.text)
	var result: Dictionary = NetSession.start_host(port)
	if not bool(result.get("ok", false)):
		_status.text = "Host failed: %s (is the port free?)" % str(result.get("reason", "bind_failed"))
		return
	_status.text = "Hosting on %d — opening board…" % port
	_go_main()


func _on_join() -> void:
	var result: Dictionary = NetSession.start_client(_join_ip.text.strip_edges(), int(_join_port.text))
	if not bool(result.get("ok", false)):
		_status.text = "Join failed: %s" % str(result.get("reason", "connect_failed"))
		return
	_status.text = "Connecting to %s:%s…" % [_join_ip.text, _join_port.text]
	_go_main()


func _on_hotseat() -> void:
	NetSession.return_to_hotseat()
	_go_main()


func _on_class_screen() -> void:
	get_tree().change_scene_to_file(CLASS_SELECT_SCENE)


func _on_connection(status: String) -> void:
	if status == "class_rejected":
		_reject.text = NetSession.lobby_text if NetSession.lobby_text != "" else "Server rejected that class."
		_sync_class_buttons()
		return
	if status == "queue_rejected":
		_reject.text = NetSession.lobby_text if NetSession.lobby_text != "" else "Queue rejected."
		return
	if status == "class_selected" or status == "queued":
		_reject.text = ""
		if NetSession.lobby_text != "":
			_status.text = NetSession.lobby_text
		_sync_class_buttons()
		return
	if status == "matched" and NetSession.is_queue_client():
		_status.text = "Matched as %s (seat %d). Opening the board…" % [SpellKits.display_name(NetSession.selected_class_id), NetSession.local_seat]
		_go_main()
		return
	if NetSession.lobby_text != "":
		_status.text = NetSession.lobby_text
	elif status != "":
		_status.text = status


func _reject_line(reason: String, class_id: String) -> String:
	var who := SpellKits.class_label(class_id)
	if who == "":
		who = "that class"
	match reason:
		"invalid_class":
			return "Server rejected %s." % who
		"class_required":
			return "Server rejected queue: confirm Kestrel or Ironjaw first."
		"already_queued":
			return "Server rejected a class change: already queued."
		"not_connected":
			return "Server rejected the class: not connected."
		_:
			return "Server rejected %s (%s)." % [who, reason]


func _go_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
