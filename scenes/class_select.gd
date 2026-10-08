extends Control
class_name ClassSelect

const _TestLoadout := preload("res://backend/test_loadout.gd")

## Koliseo screen. Hot-seat is P1, then P2, then the local duel on a random Koliseo map.
## The mobile hub is the branch entry; this scene opens from the Koliseo door.
## Online pick calls NetSession.select_class (rpc_select_class once connected).
## Online stays on Crosshaven; the dedicated host does not share a map pick.
## Play Online calls begin_auto_queue. That is the Find Match control.
## NetSession still sends rpc_enqueue. The wire is unchanged.
## Results arrive on connection_changed from rpc_class_result / rpc_queue_result /
## rpc_match_assigned: class_selected, class_rejected, waiting, queue_rejected, matched.
## Locked roster: Kestrel, Ironjaw, Mender, Gloam, Bastion.
## --class, --queue, --join, and --host skip this screen. --dedicated never shows it.

const MAIN_SCENE := "res://main.tscn"
const HUB_SCENE := "res://scenes/mobile_hub.tscn"
const SEAT_P1 := Color("#2E5A3C")
const SEAT_P2 := Color("#8B2E2E")
const SEAT_P1_TEXT := Color("#B7E0C4")
const SEAT_P2_TEXT := Color("#F0B4B4")
const HUB_FONT := "res://art/ui/hub/Cinzel-Semibold.ttf"
const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const NAVY := Color(0.008, 0.028, 0.07, 1)
const STONE := Color(0.11, 0.10, 0.09, 0.96)
const STONE_HI := Color(0.18, 0.15, 0.11, 0.98)
const CREAM := Color(0.96, 0.92, 0.84)

var _ui_font: Font

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
## Koliseo hot-seat team size (Mauro 1 Oct 2026): 1 = 1v1, 2 = 2v2, 3 = 3v3.
static var hotseat_team_size: int = 1

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
var _advanced_row: HBoxContainer
var _join_ip: LineEdit
var _join_port: LineEdit
var _queue_button: Button
var _advanced_button: Button
var _retry_button: Button
var _advanced_open: bool = false
var _queue_panel: PanelContainer
var _queue_label: Label
var _back_button: Button
var _mode_buttons: Dictionary = {}
var _size_row: HBoxContainer
var _size_buttons: Dictionary = {}
## Team picks in seat order: A1, B1, A2, B2, A3, B3.
var _team_picks: Array[String] = []
var _class_buttons: Dictionary = {}
var _name_labels: Dictionary = {}
var _role_labels: Dictionary = {}
var _portraits: Dictionary = {}
var _portrait_layout_queued: bool = false
var _portrait_layout_tries: int = 0


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
	var size := clampi(hotseat_team_size, 1, 3)
	var all_roster := hotseat_classes.size() == 2 * size
	for id in hotseat_classes:
		if not SpellKits.is_roster_class(id):
			all_roster = false
	if all_roster:
		config["classes"] = hotseat_classes.duplicate()
	if size > 1:
		config["team_size"] = size
	if CellTagMap.is_ship_map(hotseat_map_id):
		config["map_id"] = CellTagMap.normalize_id(hotseat_map_id)
	# Hot-seat uses no gear or levels, so both Init are 0: a coin flip picks
	# who starts (Mauro 29 Sep 2026: higher Init first, tie = coin flip).
	config["first_by_init"] = true
	# TEMPORARY balance-test kit (backend/test_loadout.gd): both hot-seat seats
	# wear the phone's equipped loadout and socketed Still. Normal game: none.
	if _TestLoadout.ACTIVE:
		var kit := GearBag.load_saved().fight_gear(true)
		var seat_gear := {}
		for seat in 2 * size:
			seat_gear[seat] = kit.duplicate(true)
		config["seat_gear"] = seat_gear
	return config


static func role_line(class_id: String) -> String:
	var key := SpellKits.normalize_class_id(class_id)
	return str(ROLE_LINES.get(key, ""))


## The standing cell the match draws (south idle, frame 0). The old
## art/ui/select plates are a different costume and are not shown here.
const STRIP_LIBRARY := preload("res://units/strip_library.gd")


static func portrait_path(class_id: String) -> String:
	var key := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(key):
		return ""
	return STRIP_LIBRARY.painted_path(key, "idle", "s")


static func load_portrait(class_id: String) -> Texture2D:
	var key := SpellKits.normalize_class_id(class_id)
	if not SpellKits.is_roster_class(key):
		return null
	var cells := STRIP_LIBRARY.painted_cells(key, "idle", "s")
	if cells.is_empty():
		return STRIP_LIBRARY.idle_portrait(key)
	# Same idle-south cell, cropped so every fighter shares one height and baseline.
	var fitted := STRIP_LIBRARY.card_portrait(key)
	return fitted if fitted != null else cells[0]


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
		_team_picks.clear()
		_status.text = ""
	elif which == "online":
		_phase = "online"
		_status.text = "Pick a class, then Play Online."
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
	if hotseat_team_size > 1 and (_phase == "hotseat_p1" or _phase == "hotseat_p2"):
		return _pick_team_class(id)
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


## 2v2 / 3v3 hot-seat: picks go A1, B1, A2, B2 (A3, B3). Duplicates allowed.
func _pick_team_class(id: String) -> Dictionary:
	var seat := _team_picks.size()
	_team_picks.append(id)
	_reject.text = ""
	_status.text = ""
	if _team_picks.size() >= 2 * hotseat_team_size:
		_phase = "hotseat_done"
		_refresh_all()
		_begin_hotseat_match()
		return {"ok": true, "reason": "", "class_id": id, "seat": seat, "classes": hotseat_classes.duplicate()}
	_phase = "hotseat_p1" if _team_picks.size() % 2 == 0 else "hotseat_p2"
	_refresh_all()
	return {"ok": true, "reason": "", "class_id": id, "seat": seat}


func set_team_size(size: int) -> void:
	hotseat_team_size = clampi(size, 1, 3)
	_team_picks.clear()
	_p1 = ""
	_p2 = ""
	if _phase == "hotseat_p2" or _phase == "hotseat_p1":
		_phase = "hotseat_p1"
	_refresh_all()


func team_picks() -> Array[String]:
	return _team_picks.duplicate()


func request_queue() -> Dictionary:
	if not SpellKits.is_roster_class(NetSession.selected_class_id):
		_show_reject("class_required", _picked)
		return {"ok": false, "illegal": true, "reason": "class_required", "class_id": NetSession.selected_class_id}
	if NetSession.is_auto_dialing():
		_status.text = "Connecting…"
		_set_retry_visible(false)
		return {"ok": true, "reason": "", "status": "connecting"}
	if NetSession.is_queue_client() and NetSession.is_client():
		_show_searching()
		return {"ok": true, "reason": "", "status": "waiting"}
	_status.text = "Connecting…"
	_reject.text = ""
	_set_retry_visible(false)
	var result: Dictionary = NetSession.begin_auto_queue(_override_address(), _override_port())
	if not bool(result.get("ok", false)):
		if str(result.get("reason", "")) == "class_required":
			_show_reject("class_required", NetSession.selected_class_id)
		else:
			_status.text = "Could not reach server"
			_set_retry_visible(true)
		return result
	_refresh_all()
	return result


func address_field_visible() -> bool:
	return _advanced_row != null and _advanced_row.visible and _join_ip != null and _join_ip.visible


func retry_button_visible() -> bool:
	return _retry_button != null and _retry_button.visible


func _override_address() -> String:
	if not _advanced_open or _join_ip == null:
		return ""
	return _join_ip.text.strip_edges()


func _override_port() -> int:
	if not _advanced_open or _join_port == null:
		return -1
	var port := int(_join_port.text.strip_edges())
	return port if port > 0 else -1


func _toggle_advanced() -> void:
	_advanced_open = not _advanced_open
	if _advanced_row != null:
		_advanced_row.visible = _phase == "online" and _advanced_open


func _set_retry_visible(show: bool) -> void:
	if _retry_button != null:
		_retry_button.visible = show


func return_to_hub() -> void:
	if _phase == "dedicated" or _leaving:
		return
	if NetSession.is_online() or (NetSession.is_queue_client() and NetSession.is_client()):
		NetSession.return_to_hotseat()
	_leaving = true
	get_tree().change_scene_to_file(HUB_SCENE)


func go_back() -> void:
	if _phase == "dedicated" or _leaving:
		return
	if hotseat_team_size > 1 and not _team_picks.is_empty() and _phase != "hotseat_done":
		_team_picks.pop_back()
		_phase = "hotseat_p1" if _team_picks.size() % 2 == 0 else "hotseat_p2"
		_refresh_all()
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
	bg.color = NAVY
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
	_apply_ui_font(title, 28, GOLD_BRIGHT)
	col.add_child(title)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	col.add_child(mode_row)
	_mode_buttons["hotseat"] = _mode_button("Hot-seat", "hotseat")
	_mode_buttons["online"] = _mode_button("Online", "online")
	mode_row.add_child(_mode_buttons["hotseat"])
	mode_row.add_child(_mode_buttons["online"])
	var hub_button := Button.new()
	hub_button.text = "Back to hub"
	hub_button.custom_minimum_size = Vector2(160, 48)
	_apply_ui_font(hub_button, 18, CREAM)
	hub_button.add_theme_stylebox_override("normal", _hub_return_style())
	hub_button.add_theme_stylebox_override("hover", _hub_return_style())
	hub_button.add_theme_stylebox_override("pressed", _stone_style(true))
	hub_button.pressed.connect(return_to_hub)
	mode_row.add_child(hub_button)

	_size_row = HBoxContainer.new()
	_size_row.add_theme_constant_override("separation", 12)
	_size_row.visible = false
	col.add_child(_size_row)
	for size in [1, 2, 3]:
		var b := Button.new()
		b.text = "%d vs %d" % [size, size]
		b.custom_minimum_size = Vector2(120, 48)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(set_team_size.bind(size))
		_size_buttons[size] = b
		_size_row.add_child(b)

	_prompt = Label.new()
	_apply_ui_font(_prompt, 22, CREAM)
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
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_row.resized.connect(_layout_cards)
	col.add_child(_cards_row)
	for class_id in SpellKits.LOCKED_ROSTER:
		var card := _make_card(str(class_id))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cards_row.add_child(card)

	_join_row = HBoxContainer.new()
	_join_row.add_theme_constant_override("separation", 8)
	_join_row.visible = false
	col.add_child(_join_row)
	_queue_button = Button.new()
	_queue_button.text = "Play Online"
	_queue_button.custom_minimum_size = Vector2(280, 56)
	_apply_ui_font(_queue_button, 22, Color(0.12, 0.09, 0.04))
	_queue_button.add_theme_stylebox_override("normal", _play_style())
	_queue_button.add_theme_stylebox_override("hover", _play_style())
	_queue_button.add_theme_stylebox_override("pressed", _play_style())
	_queue_button.pressed.connect(request_queue)
	_join_row.add_child(_queue_button)
	_advanced_button = Button.new()
	_advanced_button.text = "Advanced"
	_advanced_button.flat = true
	_advanced_button.custom_minimum_size = Vector2(88, 28)
	_apply_ui_font(_advanced_button, 12, GOLD_DIM)
	_advanced_button.pressed.connect(_toggle_advanced)
	_join_row.add_child(_advanced_button)
	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.visible = false
	_retry_button.custom_minimum_size = Vector2(120, 56)
	_retry_button.add_theme_font_size_override("font_size", 18)
	_retry_button.pressed.connect(request_queue)
	_join_row.add_child(_retry_button)

	_advanced_row = HBoxContainer.new()
	_advanced_row.add_theme_constant_override("separation", 8)
	_advanced_row.visible = false
	col.add_child(_advanced_row)
	_join_ip = LineEdit.new()
	_join_ip.text = ""
	_join_ip.custom_minimum_size = Vector2(220, 36)
	_join_ip.placeholder_text = "Address"
	_advanced_row.add_child(_join_ip)
	_join_port = LineEdit.new()
	_join_port.text = "7777"
	_join_port.custom_minimum_size = Vector2(90, 36)
	_join_port.placeholder_text = "7777"
	_advanced_row.add_child(_join_port)

	_reject = Label.new()
	_reject.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reject.add_theme_color_override("font_color", Color(0.95, 0.45, 0.38))
	col.add_child(_reject)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_ui_font(_status, 16, GOLD)
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
	blurb.text = "This window has no seat. Players pick a class on their own screen, then Play Online."
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
	_apply_ui_font(button, 20, CREAM)
	button.pressed.connect(choose_mode.bind(mode_id))
	return button


func _make_card(class_id: String) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(180, 320)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_card_gui.bind(class_id))
	panel.add_theme_stylebox_override("panel", _card_style(false))

	# Top 80% is the figure. Name and the one-line role share the bottom.
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	slot.anchor_left = 0.0
	slot.anchor_right = 1.0
	slot.anchor_top = 0.0
	slot.anchor_bottom = 0.80
	slot.offset_left = 6.0
	slot.offset_right = -6.0
	slot.offset_top = 6.0
	slot.offset_bottom = -2.0
	panel.add_child(slot)

	var portrait := load_portrait(class_id)
	if portrait != null:
		var tex := TextureRect.new()
		tex.texture = _body_texture(portrait)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)
		_portraits[class_id] = tex

	var name_label := Label.new()
	name_label.text = SpellKits.display_name(class_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_ui_font(name_label, 18, GOLD_BRIGHT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.anchor_left = 0.0
	name_label.anchor_right = 1.0
	name_label.anchor_top = 0.80
	name_label.anchor_bottom = 0.91
	name_label.offset_left = 4.0
	name_label.offset_right = -4.0
	panel.add_child(name_label)
	_name_labels[class_id] = name_label

	var role := Label.new()
	role.text = role_line(class_id)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_ui_font(role, 13, GOLD)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role.anchor_left = 0.0
	role.anchor_right = 1.0
	role.anchor_top = 0.90
	role.anchor_bottom = 1.0
	role.offset_left = 4.0
	role.offset_right = -4.0
	role.offset_bottom = -4.0
	panel.add_child(role)
	_role_labels[class_id] = role

	_class_buttons[class_id] = panel
	return panel


## Opaque body of the fitted plate, so the slot height is the figure height.
func _body_texture(plate: Texture2D) -> Texture2D:
	var image := plate.get_image()
	if image == null or image.is_empty():
		return plate
	var used := STRIP_LIBRARY.opaque_rect(image)
	if used.size.x < 2 or used.size.y < 2:
		return plate
	var atlas := AtlasTexture.new()
	atlas.atlas = plate
	atlas.region = Rect2(used)
	return atlas


## Every figure shares the slot height (80% of the card) and the same foot line.
## A wider pose is clipped at the card edge rather than shrinking the row.
## The row's resized signal fires before the card slots have their anchor size,
## so the scale is applied one frame later.
func _layout_cards() -> void:
	if not is_inside_tree():
		_apply_portrait_layout()
		return
	if _portrait_layout_queued:
		return
	_portrait_layout_queued = true
	call_deferred("_apply_portrait_layout")


func _apply_portrait_layout() -> void:
	_portrait_layout_queued = false
	var waiting := false
	for class_id in _portraits.keys():
		var tex: TextureRect = _portraits[class_id]
		var slot := tex.get_parent() as Control
		if slot == null or tex.texture == null:
			continue
		var slot_w := slot.size.x
		var slot_h := slot.size.y
		if slot_w < 8.0 or slot_h < 8.0:
			waiting = true
			continue
		var src := tex.texture.get_size()
		if src.y < 1.0:
			continue
		var draw_h := slot_h
		var draw_w := draw_h * (src.x / src.y)
		tex.anchor_left = 0.0
		tex.anchor_top = 0.0
		tex.anchor_right = 0.0
		tex.anchor_bottom = 0.0
		tex.position = Vector2((slot_w - draw_w) * 0.5, 0.0)
		tex.size = Vector2(draw_w, draw_h)
	if not waiting:
		_portrait_layout_tries = 0
	elif _portrait_layout_tries < 8:
		_portrait_layout_tries += 1
		_layout_cards()


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
	if hotseat_team_size > 1:
		sealed = _team_picks.duplicate()
	else:
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
	if _advanced_row != null:
		_advanced_row.visible = _phase == "online" and _advanced_open
	if _cards_row != null:
		_cards_row.visible = true
	if _size_row != null:
		_size_row.visible = _phase == "hotseat_p1" or _phase == "hotseat_p2"
		for size in _size_buttons.keys():
			var sb: Button = _size_buttons[size]
			sb.add_theme_stylebox_override("normal", _mode_style("hotseat", int(size) == hotseat_team_size))
	if hotseat_team_size > 1 and (_phase == "hotseat_p1" or _phase == "hotseat_p2" or _phase == "hotseat_done"):
		var n := mini(_team_picks.size(), 2 * hotseat_team_size - 1)
		var team_a := n % 2 == 0
		_prompt.text = "%s — pick fighter %d of %d" % ["Team A" if team_a else "Team B", n / 2 + 1, hotseat_team_size]
		_prompt.add_theme_color_override("font_color", SEAT_P1_TEXT if team_a else SEAT_P2_TEXT)
		_prompt_seat = n
		_p1_chip.visible = not _team_picks.is_empty()
		if not _team_picks.is_empty():
			var a_names: Array = []
			var b_names: Array = []
			for i in _team_picks.size():
				(a_names if i % 2 == 0 else b_names).append(SpellKits.display_name(_team_picks[i]))
			_p1_chip_label.text = "A: %s   ·   B: %s" % [", ".join(a_names), ", ".join(b_names)]
		return
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
	elif status == "connecting":
		_reject.text = ""
		_status.text = "Connecting…"
		_set_retry_visible(false)
		_refresh_all()
	elif status == "joined" or status == "waiting":
		_reject.text = ""
		_show_searching()
		_refresh_all()
	elif status == "queue_rejected":
		_show_reject("class_required", NetSession.selected_class_id)
		_queue_panel.visible = false
	elif status == "matched":
		if not NetSession.is_queue_client():
			return
		_status.text = "Opponent found"
		_queue_panel.visible = false
		_set_retry_visible(false)
		if NetSession.match_assigned():
			_go_main()
	elif status == "join_failed":
		_status.text = "Could not reach server"
		_reject.text = ""
		_queue_panel.visible = false
		_set_retry_visible(true)
	elif status == "host_left":
		_status.text = "Server disconnected."
	elif status == "match_finished":
		return_to_hub()


func _show_searching() -> void:
	if _queue_panel != null:
		_queue_label.text = "Searching for opponent…"
		_queue_panel.visible = true
	_set_retry_visible(false)
	if _status != null:
		_status.text = "Searching for opponent…"


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


func _apply_ui_font(control: Control, size: int, color: Color) -> void:
	if _ui_font == null:
		_ui_font = load(HUB_FONT) as Font
	if _ui_font != null:
		control.add_theme_font_override("font", _ui_font)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)


func _stone_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = STONE_HI if selected else STONE
	style.border_color = GOLD_BRIGHT if selected else GOLD_DIM
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	return style


func _card_style(selected: bool) -> StyleBoxFlat:
	return _stone_style(selected)


func _hub_return_style() -> StyleBoxFlat:
	return _stone_style(false)


func _play_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD
	style.border_color = GOLD_BRIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _mode_style(_mode_id: String, active: bool) -> StyleBoxFlat:
	return _stone_style(active)


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
	var style := _stone_style(true)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
