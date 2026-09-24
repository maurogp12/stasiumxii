extends Control

## Anonymous listen-host lobby. Direct IP join.

const MAIN_SCENE := "res://main.tscn"

var _status: Label
var _host_port: LineEdit
var _join_ip: LineEdit
var _join_port: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not NetSession.connection_changed.is_connected(_on_connection):
		NetSession.connection_changed.connect(_on_connection)
	_status.text = "Join a dedicated host by IP, or host a listen-host window. Clients send Intent."


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.08)
	add_child(bg)

	var col := VBoxContainer.new()
	col.position = Vector2(80, 80)
	col.size = Vector2(800, 560)
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var title := Label.new()
	title.text = "STASIUM XII — listen-host duel"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(title)

	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "ENet (Godot MultiplayerAPI). Host match is optional listen-host: this window is Kestrel and owns the sim. A dedicated process is headless (--dedicated 7777); Join match uses its IP. First joiner is Kestrel, second is Ironjaw. Clients send Intent only. Local hot-seat stays on main.tscn."
	blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(blurb)

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 8)
	col.add_child(host_row)
	_host_port = _field("7777")
	host_row.add_child(_label("Port"))
	host_row.add_child(_host_port)
	var host_btn := Button.new()
	host_btn.text = "Host match"
	host_btn.custom_minimum_size = Vector2(160, 36)
	host_btn.pressed.connect(_on_host)
	host_row.add_child(host_btn)

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
	var join_btn := Button.new()
	join_btn.text = "Join match"
	join_btn.custom_minimum_size = Vector2(160, 36)
	join_btn.pressed.connect(_on_join)
	join_row.add_child(join_btn)

	var local_btn := Button.new()
	local_btn.text = "Local hot-seat"
	local_btn.custom_minimum_size = Vector2(180, 36)
	local_btn.pressed.connect(_on_hotseat)
	col.add_child(local_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	col.add_child(_status)


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


func _on_connection(status: String) -> void:
	_status.text = status


func _go_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
