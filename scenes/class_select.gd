extends Control
class_name ClassSelect

## Main scene. Hot-seat is P1, then P2, then the local duel on a random Koliseo map.
## Online pick calls NetSession.select_class (rpc_select_class once connected).
## Online stays on Crosshaven; the dedicated host does not share a map pick.
## Queue calls start_queue_client, which sends rpc_enqueue. Queue is the Find Match control.
## Results arrive on connection_changed from rpc_class_result / rpc_queue_result /
## rpc_match_assigned: class_selected, class_rejected, waiting, queue_rejected, matched.
## Locked roster: Kestrel, Ironjaw, Mender, Gloam, Bastion.
## --class, --queue, --join, and --host skip this screen. --dedicated never shows it.

const MAIN_SCENE := "res://main.tscn"
const SEAT_P1 := Color("#2E5A3C")
const SEAT_P2 := Color("#8B2E2E")
const SEAT_P1_TEXT := Color("#B7E0C4")
const SEAT_P2_TEXT := Color("#F0B4B4")

## Short roles derived from the Locked cards (kits.gd + workbook v0.6).
## Kestrel: Mark Shot range 2–7. Ironjaw: Strike / Shoulder / Crush at range 1.
## Mender: Mend and Pulse Tap heals. Gloam: Fade Invisible and Backstab.
## Bastion: Intercept and Aegis. No extra stats.
const ROLE_LINES := {
	"kestrel": "Ranged carry",
	"ironjaw": "Melee bruiser",
	"mender": "Healer",
	"gloam": "Stealth assassin",
	"bastion": "Tank",
}

static var hotseat_classes: Array[String] = []
## Short catalog id (`brinewake`). Empty keeps the Crosshaven default.
static var hotseat_map_id: String = ""

var _phase: String = "mode"
var _p1: String = ""
var _p2: String = ""
var _picked: String = ""
var _prompt_seat: int = -1
var _leaving: bool = false
## Tests set this false so a finished P2 pick does not change the scene.
var _auto_launch: bool = true

var _prompt: Label
var _status: Label
var _reject: Label
var _p1_chip: PanelContainer
var _p1_chip_label: Label
var _cards_row: HBoxContainer
var _join_row: HBoxContainer
var _join_ip: LineEdit
var _join_port: LineEdit
var _queue_button: Button
var _queue_panel: PanelContainer
var _queue_label: Label
var _back_button: Button
var _mode_buttons: Dictionary = {}
var _class_buttons: Dictionary = {}
var _name_labels: Dictionary = {}
var _role_labels: Dictionary = {}
var _portraits: Dictionary = {}


static func route_for_plan(plan: Dictionary) -> String:
	var planned := str(plan.get("mode", "hotseat"))
	if planned == "dedicated":
		return "dedicated"
	if planned == "host" or planned == "client" or planned == "queue":
		return "board"
	if str(plan.get("class_id", "")) != "":
		return "board"
	return "picker"


static func roll_hotseat_map() -> String:
	hotseat_map_id = CellTagMap.random_ship_id()
	return hotseat_map_id


static func local_match_config() -> Dictionary:
	var config := {}
	if hotseat_classes.size() == 2 and SpellKits.is_roster_class(hotseat_classes[0]) and SpellKits.is_roster_class(hotseat_classes[1]):
		config["classes"] = [hotseat_classes[0], hotseat_classes[1]]
	if CellTagMap.is_ship_map(hotseat_map_id):
		config["map_id"] = CellTagMap.normalize_id(hotseat_map_id)
	return config


static func role_line(class_id: String) -> String:
	var key := SpellKits.normalize_class_id(class_id)
	return str(ROLE_LINES.get(key, ""))


static func portrait_path(class_id: String) -> String:
	var key := SpellKits.normalize_class_id(class_id)
	return "res://art/characters/%s/%s_s.png" % [key, key]


static func load_portrait(class_id: String) -> Texture2D:
	var path := portrait_path(class_id)
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is Texture2D:
		return res as Texture2D
	return null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var route := route_for_plan(NetSession.plan_from_args(OS.get_cmdline_user_args()))
	if NetSession.is_dedicated() or route == "dedicated":
		_phase = "dedicated"
		_build_dedicated()
		_connect_net()
		return
	if route == "board":
		call_deferred("_go_main")
		return
	_build()
	_connect_net()
	_picked = NetSession.selected_class_id
	_refresh_all()
	if NetSession.match_assigned() and NetSession.is_queue_client():
		_go_main()


func choose_mode(which: String) -> void:
	if _phase == "dedicated":
		return
	if which == "hotseat":
		_phase = "hotseat_p1"
		_p1 = ""
		_p2 = ""
		_status.text = ""
	elif which == "online":
		_phase = "online"
		_status.text = "Pick a class, then Queue. Online plays Crosshaven."
	else:
		return
	_reject.text = ""
	_refresh_all()


func pick_class(class_id: String) -> Dictionary:
	var id := SpellKits.normalize_class_id(class_id)
	if _phase == "dedicated":
		return {"ok": false, "reason": "dedicated", "class_id": id}
	if _phase == "mode":
		_status.text = "Choose Hot-seat or Online first."
		return {"ok": false, "reason": "mode_required", "class_id": id}
	if _phase == "hotseat_done":
		return {"ok": false, "reason": "already_started", "class_id": id, "classes": hotseat_classes.duplicate()}
	if not SpellKits.is_roster_class(id):
		if _phase == "online":
			var rejected: Dictionary = NetSession.select_class(id)
			_show_reject(str(rejected.get("reason", "invalid_class")), id)
			_refresh_all()
			return rejected
		_show_reject("invalid_class", id)
		return {"ok": false, "reason": "invalid_class", "class_id": id}
	if _phase == "hotseat_p1":
		_p1 = id
		_phase = "hotseat_p2"
		_reject.text = ""
		_status.text = ""
		_refresh_all()
		return {"ok": true, "reason": "", "class_id": id, "seat": 0}
	if _phase == "hotseat_p2":
		_p2 = id
		_phase = "hotseat_done"
		_reject.text = ""
		_refresh_all()
		_begin_hotseat_match()
		return {"ok": true, "reason": "", "class_id": id, "seat": 1, "classes": hotseat_classes.duplicate()}
	if _phase == "online":
		return _confirm_online_class(id)
	return {"ok": false, "reason": "mode_required", "class_id": id}


func request_queue() -> Dictionary:
	if not SpellKits.is_roster_class(NetSession.selected_class_id):
		_show_reject("class_required", _picked)
		return {"ok": false, "illegal": true, "reason": "class_required", "class_id": NetSession.selected_class_id}
	_status.text = "Entering queue…"
	if NetSession.is_queue_client() and NetSession.is_client():
		_show_waiting()
		return {"ok": true, "reason": "", "status": "waiting"}
	var address := _join_ip.text.strip_edges() if _join_ip != null else "127.0.0.1"
	var port := int(_join_port.text) if _join_port != null else NetSession.DEFAULT_PORT
	var result: Dictionary = NetSession.start_queue_client(address, port)
	if not bool(result.get("ok", false)):
		_show_reject(str(result.get("reason", "class_required")), NetSession.selected_class_id)
		return result
	_status.text = "Connecting as %s…" % SpellKits.display_name(NetSession.selected_class_id)
	_refresh_all()
	return result


func go_back() -> void:
	if _phase == "dedicated" or _leaving:
		return
	if _phase == "hotseat_p2":
		_phase = "hotseat_p1"
		_p2 = ""
		_refresh_all()
		return
	if NetSession.is_online() or (NetSession.is_queue_client() and NetSession.is_client()):
		NetSession.return_to_hotseat()
	_phase = "mode"
	_p1 = ""
	_p2 = ""
	_queue_panel.visible = false
	_refresh_all()


func phase_name() -> String:
	return _phase


func prompt_text() -> String:
	if _prompt == null:
		return ""
	return _prompt.text


func prompt_seat() -> int:
	return _prompt_seat


func status_text() -> String:
	if _status == null:
		return ""
	return _status.text


func reject_text() -> String:
	if _reject == null:
		return ""
	return _reject.text


func class_cards_visible() -> bool:
	return _cards_row != null and _cards_row.visible and _class_buttons.size() == SpellKits.LOCKED_ROSTER.size()


func card_title(class_id: String) -> String:
	if not _name_labels.has(class_id):
		return ""
	return str((_name_labels[class_id] as Label).text)


func card_role(class_id: String) -> String:
	if not _role_labels.has(class_id):
		return ""
	return str((_role_labels[class_id] as Label).text)


func card_has_portrait(class_id: String) -> bool:
	if not _portraits.has(class_id):
		return false
	var tex: TextureRect = _portraits[class_id]
	return tex.texture != null


func portrait_filter(class_id: String) -> int:
	if not _portraits.has(class_id):
		return -1
	return int((_portraits[class_id] as TextureRect).texture_filter)


func queue_button_text() -> String:
	if _queue_button == null:
		return ""
	return _queue_button.text


func _connect_net() -> void:
	if not NetSession.connection_changed.is_connected(_on_connection):
		NetSession.connection_changed.connect(_on_connection)


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
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	var title := Label.new()
	title.text = "STASIUM XII"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(title)

	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "Locked roster: Kestrel, Ironjaw, Mender, Gloam, Bastion. Hot-seat picks classes; the arena is a random Koliseo map. Online queues on the dedicated host (Crosshaven)."
	blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(blurb)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	col.add_child(mode_row)
	_mode_buttons["hotseat"] = _mode_button("Hot-seat", "hotseat")
	_mode_buttons["online"] = _mode_button("Online", "online")
	mode_row.add_child(_mode_buttons["hotseat"])
	mode_row.add_child(_mode_buttons["online"])

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	col.add_child(_prompt)

	_p1_chip = PanelContainer.new()
	_p1_chip.visible = false
	_p1_chip.add_theme_stylebox_override("panel", _seat_chip_style(SEAT_P1))
	col.add_child(_p1_chip)
	_p1_chip_label = Label.new()
	_p1_chip_label.add_theme_font_size_override("font_size", 16)
	_p1_chip_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	_p1_chip.add_child(_p1_chip_label)

	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 12)
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_cards_row)
	for class_id in SpellKits.LOCKED_ROSTER:
		var card := _make_card(str(class_id))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cards_row.add_child(card)

	_join_row = HBoxContainer.new()
	_join_row.add_theme_constant_override("separation", 8)
	_join_row.visible = false
	col.add_child(_join_row)
	var host_label := Label.new()
	host_label.text = "Host"
	host_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_join_row.add_child(host_label)
	_join_ip = LineEdit.new()
	_join_ip.text = NetSession.join_address if NetSession.join_address != "" else "127.0.0.1"
	_join_ip.custom_minimum_size = Vector2(180, 36)
	_join_ip.placeholder_text = "127.0.0.1"
	_join_row.add_child(_join_ip)
	_join_port = LineEdit.new()
	_join_port.text = str(NetSession.listen_port if NetSession.listen_port > 0 else NetSession.DEFAULT_PORT)
	_join_port.custom_minimum_size = Vector2(90, 36)
	_join_port.placeholder_text = "7777"
	_join_row.add_child(_join_port)
	_queue_button = Button.new()
	_queue_button.text = "Queue"
	_queue_button.custom_minimum_size = Vector2(160, 40)
	_queue_button.add_theme_font_size_override("font_size", 18)
	_queue_button.pressed.connect(request_queue)
	_join_row.add_child(_queue_button)

	_reject = Label.new()
	_reject.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reject.add_theme_color_override("font_color", Color(0.95, 0.45, 0.38))
	col.add_child(_reject)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	col.add_child(_status)

	_queue_panel = PanelContainer.new()
	_queue_panel.custom_minimum_size = Vector2(0, 72)
	_queue_panel.visible = false
	_queue_panel.add_theme_stylebox_override("panel", _waiting_style())
	col.add_child(_queue_panel)
	_queue_label = Label.new()
	_queue_label.text = "Queued. Waiting for an opponent."
	_queue_label.add_theme_font_size_override("font_size", 20)
	_queue_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	_queue_panel.add_child(_queue_label)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(120, 36)
	_back_button.pressed.connect(go_back)
	col.add_child(_back_button)


func _build_dedicated() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.08, 0.08)
	add_child(bg)

	var col := VBoxContainer.new()
	col.position = Vector2(48, 48)
	col.size = Vector2(860, 400)
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var title := Label.new()
	title.text = "STASIUM XII — dedicated host"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	col.add_child(title)

	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "This window has no seat. Players pick a class on their own screen, then Queue."
	blurb.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	col.add_child(blurb)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	_status.text = NetSession.lobby_text if NetSession.lobby_text != "" else "Dedicated queue. No class picker on this process."
	col.add_child(_status)

	_reject = Label.new()
	col.add_child(_reject)


func _mode_button(text: String, mode_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(choose_mode.bind(mode_id))
	return button


func _make_card(class_id: String) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(168, 248)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_card_gui.bind(class_id))
	panel.add_theme_stylebox_override("panel", _card_style(false))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(8, 8)
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var portrait := load_portrait(class_id)
	if portrait != null:
		var tex := TextureRect.new()
		tex.texture = portrait
		tex.custom_minimum_size = Vector2(144, 160)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex)
		_portraits[class_id] = tex

	var name_label := Label.new()
	name_label.text = SpellKits.display_name(class_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	_name_labels[class_id] = name_label

	var role := Label.new()
	role.text = role_line(class_id)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 13)
	role.add_theme_color_override("font_color", Color(0.78, 0.74, 0.7))
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(role)
	_role_labels[class_id] = role

	_class_buttons[class_id] = panel
	return panel


func _on_card_gui(event: InputEvent, class_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			pick_class(class_id)
			accept_event()
	elif event.is_action_pressed("ui_accept"):
		pick_class(class_id)
		accept_event()


func _confirm_online_class(class_id: String) -> Dictionary:
	var result: Dictionary = NetSession.select_class(class_id)
	_picked = str(result.get("class_id", class_id))
	if not bool(result.get("ok", false)):
		_show_reject(str(result.get("reason", "invalid_class")), class_id)
		_refresh_all()
		return result
	_reject.text = ""
	_status.text = "Class confirmed: %s." % SpellKits.display_name(str(result.get("class_id", class_id)))
	_refresh_all()
	return result


func _begin_hotseat_match() -> void:
	var sealed: Array[String] = []
	sealed.append(_p1)
	sealed.append(_p2)
	hotseat_classes = sealed
	roll_hotseat_map()
	if not _auto_launch or _leaving:
		return
	_leaving = true
	NetSession.return_to_hotseat()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _refresh_all() -> void:
	if _phase == "dedicated" or _prompt == null:
		return
	_apply_prompt()
	_apply_mode_styles()
	_apply_cards()
	if _queue_button != null:
		var confirmed := SpellKits.is_roster_class(NetSession.selected_class_id)
		_queue_button.disabled = _phase != "online" or not confirmed or NetSession.match_assigned()
	if _back_button != null:
		_back_button.visible = _phase != "mode"


func _apply_prompt() -> void:
	var show_chip := _phase == "hotseat_p2" or _phase == "hotseat_done"
	_p1_chip.visible = show_chip
	if show_chip:
		_p1_chip_label.text = "P1 locked in: %s" % SpellKits.display_name(_p1)
	_join_row.visible = _phase == "online"
	if _cards_row != null:
		_cards_row.visible = true
	if _phase == "hotseat_p1":
		_prompt.text = "P1 — pick your class"
		_prompt.add_theme_color_override("font_color", SEAT_P1_TEXT)
		_prompt_seat = 0
	elif _phase == "hotseat_p2" or _phase == "hotseat_done":
		_prompt.text = "P2 — pick your class"
		_prompt.add_theme_color_override("font_color", SEAT_P2_TEXT)
		_prompt_seat = 1
	elif _phase == "online":
		_prompt.text = "Pick your class"
		_prompt.add_theme_color_override("font_color", Color(0.86, 0.9, 0.98))
		_prompt_seat = -1
	else:
		_prompt.text = "Choose Hot-seat or Online."
		_prompt.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
		_prompt_seat = -1


func _apply_mode_styles() -> void:
	for mode_id in _mode_buttons.keys():
		var button: Button = _mode_buttons[mode_id]
		var active := false
		if str(mode_id) == "hotseat":
			active = _phase.begins_with("hotseat")
		elif str(mode_id) == "online":
			active = _phase == "online"
		button.add_theme_stylebox_override("normal", _mode_style(str(mode_id), active))
		button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))


func _apply_cards() -> void:
	var selected := ""
	if _phase == "hotseat_p1" or _phase == "hotseat_p2" or _phase == "hotseat_done":
		selected = _p1 if _phase == "hotseat_p1" else _p2
	elif _phase == "online":
		selected = NetSession.selected_class_id
	for class_id in _class_buttons.keys():
		var panel: Panel = _class_buttons[class_id]
		panel.add_theme_stylebox_override("panel", _card_style(str(class_id) == selected and selected != ""))


func _on_connection(status: String) -> void:
	if _leaving:
		return
	if _phase == "dedicated" or NetSession.is_dedicated():
		if NetSession.lobby_text != "":
			_status.text = NetSession.lobby_text
		return
	if status == "class_selected":
		_reject.text = ""
		_status.text = "Server accepted %s." % SpellKits.display_name(NetSession.selected_class_id)
		_refresh_all()
	elif status == "class_rejected":
		_show_reject("invalid_class", _picked)
	elif status == "waiting":
		_reject.text = ""
		_show_waiting()
		if NetSession.lobby_text != "":
			_status.text = NetSession.lobby_text
		_refresh_all()
	elif status == "queue_rejected":
		_show_reject("class_required", NetSession.selected_class_id)
		_queue_panel.visible = false
	elif status == "matched":
		if not NetSession.is_queue_client():
			return
		_status.text = "Match assigned."
		_queue_panel.visible = false
		if NetSession.match_assigned():
			_go_main()
	elif status == "join_failed":
		_status.text = "Join failed."
		_reject.text = "Could not reach the server."
		_queue_panel.visible = false
	elif status == "host_left":
		_status.text = "Server disconnected."


func _show_waiting() -> void:
	if _queue_panel == null:
		return
	_queue_label.text = "Queued. Waiting for an opponent."
	_queue_panel.visible = true
	_status.text = "Queued. Waiting for an opponent."


func _show_reject(reason: String, class_id: String) -> void:
	if _reject == null:
		return
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
	if reason == "class_required" or reason == "invalid_class":
		_status.text = ""
	_refresh_all()


func _go_main() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(MAIN_SCENE)


func _card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.2, 0.16) if selected else Color(0.15, 0.14, 0.13)
	style.set_border_width_all(3 if selected else 1)
	style.border_color = Color(0.93, 0.78, 0.42) if selected else Color(0.38, 0.34, 0.3)
	style.set_corner_radius_all(8)
	return style


func _mode_style(mode_id: String, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if mode_id == "hotseat":
		style.bg_color = SEAT_P1 if active else Color(0.16, 0.2, 0.17)
	else:
		style.bg_color = Color("#2E4A6E") if active else Color(0.14, 0.16, 0.2)
	style.set_border_width_all(2 if active else 1)
	style.border_color = Color(0.93, 0.78, 0.42) if active else Color(0.35, 0.32, 0.28)
	style.set_corner_radius_all(8)
	return style


func _seat_chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _waiting_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.22, 0.12)
	style.border_color = Color(0.93, 0.78, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
