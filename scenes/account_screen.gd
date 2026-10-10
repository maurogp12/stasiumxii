extends Control

## Hub overlay for player accounts, Step 1 (Mauro 10 Oct 2026: "email and
## guest"). Log in, create an account, play as a guest, or (as a guest) add
## an email + password to keep the account. Talks through account_client.gd.
## Step 1 does not move progress: levels, gear and coins stay on the phone.

signal closed

const Logic := preload("res://backend/account_logic.gd")
const NAVY := Color(0.008, 0.028, 0.07)
const GOLD := Color(0.855, 0.69, 0.4)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.52)
const GOLD_DIM := Color(0.62, 0.49, 0.28)
const TEXT := Color(0.9, 0.88, 0.82)
const ROW_HEIGHT := 48
const PANEL_WIDTH := 560.0

const WELCOME := "welcome"
const LOGIN := "login"
const CREATE := "create"
const GUEST := "guest"
const UPGRADE := "upgrade"
const SIGNED_IN := "signed_in"

var font: Font
## The hub's AccountClient node.
var client: Node

var _mode: String = ""
var _panel: PanelContainer
var _box: VBoxContainer
var _title: Label
var _blurb: Label
var _status: Label
var _fields: Dictionary = {}
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	if client != null:
		client.finished.connect(_on_finished)
		client.busy_changed.connect(_on_busy)
	show_mode(SIGNED_IN if _signed_in() else WELCOME)
	if client != null and not client.is_configured():
		_status.text = Logic.message_for("not_configured")
	resized.connect(_place_panel)
	_place_panel()


func mode() -> String:
	return _mode


func status_text() -> String:
	return _status.text if _status != null else ""


func field(field_name: String) -> LineEdit:
	return _fields.get(field_name, null)


func button(button_name: String) -> Button:
	return _buttons.get(button_name, null)


func close() -> void:
	closed.emit()
	queue_free()


func show_mode(next: String) -> void:
	_mode = next
	_status.text = ""
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_fields.clear()
	_buttons.clear()
	match next:
		WELCOME:
			_title.text = "Your account"
			_blurb.text = "An account keeps your name and, soon, your heroes, gear and coins safe on any phone. You can start as a guest and add an email later."
			_add_button("LogIn", "Log in", show_mode.bind(LOGIN))
			_add_button("Create", "Create account", show_mode.bind(CREATE))
			_add_button("Guest", "Play as guest", show_mode.bind(GUEST))
			_add_button("Later", "Later", close, true)
		LOGIN:
			_title.text = "Log in"
			_blurb.text = "Use the email and password of your account."
			_add_field("email", "Email", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
			_add_field("password", "Password", LineEdit.KEYBOARD_TYPE_PASSWORD, true)
			_add_button("Submit", "Log in", submit)
			_add_button("Back", "Back", show_mode.bind(WELCOME), true)
		CREATE:
			_title.text = "Create account"
			_blurb.text = "Your name shows to other players. The password needs at least 8 characters."
			_add_field("name", "Player name", LineEdit.KEYBOARD_TYPE_DEFAULT)
			_add_field("email", "Email", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
			_add_field("password", "Password", LineEdit.KEYBOARD_TYPE_PASSWORD, true)
			_add_button("Submit", "Create account", submit)
			_add_button("Back", "Back", show_mode.bind(WELCOME), true)
		GUEST:
			_title.text = "Play as guest"
			_blurb.text = "Pick a name. A guest account lives only on this phone until you add an email."
			_add_field("name", "Player name", LineEdit.KEYBOARD_TYPE_DEFAULT)
			_add_button("Submit", "Start as guest", submit)
			_add_button("Back", "Back", show_mode.bind(WELCOME), true)
		UPGRADE:
			_title.text = "Keep this account"
			_blurb.text = "Add an email and a password. You keep your name and can log in on any phone."
			_add_field("email", "Email", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
			_add_field("password", "Password", LineEdit.KEYBOARD_TYPE_PASSWORD, true)
			_add_button("Submit", "Save email", submit)
			_add_button("Back", "Back", show_mode.bind(SIGNED_IN), true)
		SIGNED_IN:
			_title.text = "Your account"
			_blurb.text = _signed_in_text()
			if client != null and client.is_guest():
				_add_button("Upgrade", "Add email and password", show_mode.bind(UPGRADE))
			_add_button("LogOut", "Log out", log_out)
			_add_button("Close", "Close", close, true)
	if _fields.size() > 0:
		call_deferred("_focus_first")
	# Shrink the panel to the new page (a short page after a long one).
	call_deferred("_place_panel")


## Sends the form on screen.
func submit() -> void:
	if client == null:
		return
	match _mode:
		LOGIN:
			client.sign_in(_text("email"), _text("password"))
		CREATE:
			client.sign_up(_text("email"), _text("password"), _text("name"))
		GUEST:
			client.play_as_guest(_text("name"))
		UPGRADE:
			client.upgrade_guest(_text("email"), _text("password"))


func log_out() -> void:
	if client == null:
		return
	var was_guest: bool = client.is_guest()
	client.sign_out()
	show_mode(WELCOME)
	_status.text = "Logged out." if not was_guest else "Logged out. That guest account cannot be opened again."


func _on_finished(outcome: Dictionary) -> void:
	if not is_inside_tree():
		return
	var kind := str(outcome.get("kind", ""))
	if kind == Logic.SIGN_OUT or kind == Logic.REFRESH:
		return
	var text := str(outcome.get("message", ""))
	if bool(outcome.get("ok", false)) and _signed_in():
		show_mode(SIGNED_IN)
	elif bool(outcome.get("ok", false)) and bool(outcome.get("needs_confirm", false)) and _mode == CREATE:
		show_mode(LOGIN)
	_status.text = text


func _on_busy(is_busy: bool) -> void:
	for b in _buttons.values():
		(b as Button).disabled = is_busy
	if is_busy:
		_status.text = "Connecting…"


func _signed_in() -> bool:
	return client != null and client.is_signed_in()


func _signed_in_text() -> String:
	if client == null:
		return ""
	var s: Dictionary = client.session
	var who := "Playing as %s." % client.label()
	if client.is_guest():
		who += " Guest account: add an email so you never lose it."
		if str(s.get("pending_email", "")) != "":
			who += " Waiting for you to confirm %s." % str(s["pending_email"])
	elif str(s.get("email", "")) != "":
		who += " Logged in with %s." % str(s["email"])
	return who + " For now your progress still saves on this phone."


func _focus_first() -> void:
	if _fields.is_empty():
		return
	var first: LineEdit = _fields.values()[0]
	if first.is_inside_tree():
		first.grab_focus()


func _text(field_name: String) -> String:
	var edit: LineEdit = _fields.get(field_name, null)
	return edit.text if edit != null else ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))


func _place_panel() -> void:
	if _panel == null:
		return
	var w := minf(PANEL_WIDTH, size.x - 32.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	# Near the top so the phone keyboard does not cover the fields.
	_panel.position = Vector2((size.x - w) * 0.5, 16.0)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "AccountPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.045, 0.09, 0.97)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_title = _label(24, GOLD_BRIGHT)
	_title.name = "Title"
	column.add_child(_title)
	_blurb = _label(14, TEXT)
	_blurb.name = "Blurb"
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_blurb)
	_box = VBoxContainer.new()
	_box.name = "Form"
	_box.add_theme_constant_override("separation", 8)
	column.add_child(_box)
	_status = _label(14, GOLD)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _label(font_size: int, tint: Color) -> Label:
	var label := Label.new()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label


func _add_field(field_name: String, hint: String, keyboard: int, secret: bool = false) -> void:
	var edit := LineEdit.new()
	edit.name = field_name.capitalize().replace(" ", "")
	edit.placeholder_text = hint
	edit.secret = secret
	edit.virtual_keyboard_type = keyboard
	edit.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	edit.max_length = 64 if field_name != "name" else Logic.NAME_MAX
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", Color.WHITE)
	edit.add_theme_color_override("font_placeholder_color", GOLD_DIM)
	var box := StyleBoxFlat.new()
	box.bg_color = NAVY
	box.border_color = GOLD_DIM
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	edit.add_theme_stylebox_override("normal", box)
	var lit := box.duplicate() as StyleBoxFlat
	lit.border_color = GOLD_BRIGHT
	edit.add_theme_stylebox_override("focus", lit)
	edit.text_submitted.connect(func(_t: String) -> void: submit())
	_box.add_child(edit)
	_fields[field_name] = edit


func _add_button(button_name: String, text: String, action: Callable, quiet: bool = false) -> void:
	var b := Button.new()
	b.name = button_name
	b.text = text
	b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font != null:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", GOLD if quiet else GOLD_BRIGHT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", GOLD_DIM)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.02, 0.045, 0.09, 0.94) if quiet else Color(0.09, 0.07, 0.03, 0.95)
		s.border_color = GOLD_BRIGHT if state in ["hover", "focus"] else (GOLD_DIM if quiet else GOLD)
		s.set_border_width_all(1)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	_box.add_child(b)
	_buttons[button_name] = b
