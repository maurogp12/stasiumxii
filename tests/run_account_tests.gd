extends SceneTree

## Player accounts, Step 1: email + password and guest accounts on Supabase
## Auth (Mauro 10 Oct 2026). No network: a fake transport answers like
## Supabase does.
## Run: godot --headless --path . -s res://tests/run_account_tests.gd

const Logic := preload("res://backend/account_logic.gd")
const Client := preload("res://backend/account_client.gd")
const Screen := preload("res://scenes/account_screen.gd")
const TEST_SAVE := "user://test_account.json"
const URL := "https://demo-project.supabase.co"
const KEY := "public-anon-key"
const NOW := 1_800_000_000

var _failed: int = 0
var _passed: int = 0
## What the fake server got, newest last.
var _sent: Array = []
## Next answers, oldest first: {result, code, body}.
var _answers: Array = []


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	Logic.save_path = TEST_SAVE
	Logic.clear_session()
	_test_input_checks()
	_test_requests()
	_test_answers()
	_test_saved_login()
	_test_not_configured()
	_test_create_and_log_in()
	_test_guest_then_upgrade()
	_test_refresh()
	_test_log_out_offline()
	_test_screen()
	_test_hub_button()
	_test_no_secret_key()
	Logic.clear_session()
	print("Account tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_input_checks() -> void:
	eq(Logic.check_email("mauro@mail.com"), "", "a normal email passes")
	eq(Logic.check_email("  Mauro@Mail.com "), "", "spaces and capitals are cleaned")
	eq(Logic.clean_email("  Mauro@Mail.com "), "mauro@mail.com", "emails are saved lower case")
	for bad in ["", "mauro", "mauro@", "@mail.com", "a@b", "a b@mail.com", "a@@mail.com", "a@mail."]:
		eq(Logic.check_email(bad), "bad_email", "bad email refused: '%s'" % bad)
	eq(Logic.check_password("1234567"), "short_password", "7 characters is too short")
	eq(Logic.check_password("12345678"), "", "8 characters is enough")
	eq(Logic.check_name("Mauro"), "", "a plain name passes")
	eq(Logic.check_name("Íñigo_12"), "", "accents, numbers and _ pass")
	eq(Logic.check_name("ab"), "bad_name", "2 letters is too short")
	eq(Logic.check_name("a".repeat(17)), "bad_name", "17 letters is too long")
	eq(Logic.check_name("<b>x</b>"), "bad_name", "symbols are refused")
	eq(Logic.is_configured("", ""), false, "empty config is not connected")
	eq(Logic.is_configured("http://x.supabase.co", KEY), false, "plain http is refused")
	eq(Logic.is_configured(URL, KEY), true, "https url + key is connected")


func _test_requests() -> void:
	var up := Logic.build_request(Logic.SIGN_UP, {"email": "A@b.co", "password": "secret123", "name": " Mauro "}, {}, URL, KEY)
	eq(up["url"], URL + "/auth/v1/signup", "sign up url")
	eq(up["method"], HTTPClient.METHOD_POST, "sign up is POST")
	truthy((up["headers"] as PackedStringArray).has("apikey: " + KEY), "anon key goes in apikey")
	var body: Dictionary = JSON.parse_string(up["body"])
	eq(body["email"], "a@b.co", "sign up sends the clean email")
	eq(body["data"]["display_name"], "Mauro", "sign up sends the player name")
	var guest := Logic.build_request(Logic.GUEST, {"name": "Kid"}, {}, URL + "/", KEY)
	eq(guest["url"], URL + "/auth/v1/signup", "guest uses signup (trailing / trimmed)")
	var guest_body: Dictionary = JSON.parse_string(guest["body"])
	eq(guest_body.has("email") or guest_body.has("password"), false, "a guest sends no email or password")
	var login := Logic.build_request(Logic.SIGN_IN, {"email": "a@b.co", "password": "p"}, {}, URL, KEY)
	eq(login["url"], URL + "/auth/v1/token?grant_type=password", "log in url")
	var session := {"access_token": "AT", "refresh_token": "RT"}
	var upgrade := Logic.build_request(Logic.UPGRADE, {"email": "a@b.co", "password": "secret123"}, session, URL, KEY)
	eq(upgrade["method"], HTTPClient.METHOD_PUT, "upgrade is PUT /user")
	truthy((upgrade["headers"] as PackedStringArray).has("Authorization: Bearer AT"), "upgrade sends the login token")
	var refresh := Logic.build_request(Logic.REFRESH, {}, session, URL, KEY)
	eq(JSON.parse_string(refresh["body"])["refresh_token"], "RT", "refresh sends the refresh token")
	eq((login["headers"] as PackedStringArray).has("Authorization: Bearer AT"), false, "log in sends no old token")


func _test_answers() -> void:
	var ok := Logic.parse_response(Logic.SIGN_IN, HTTPRequest.RESULT_SUCCESS, 200, _session_json("u1", "a@b.co", false, "Mauro"), NOW)
	eq(ok["ok"], true, "a 200 with a token logs in")
	eq(ok["session"]["user_id"], "u1", "keeps the user id")
	eq(ok["session"]["name"], "Mauro", "keeps the player name")
	eq(ok["session"]["expires_at"], NOW + 3600, "expires_in becomes expires_at")
	eq(ok["session"]["is_guest"], false, "an email account is not a guest")
	var confirm := Logic.parse_response(Logic.SIGN_UP, HTTPRequest.RESULT_SUCCESS, 200, JSON.stringify({"id": "u2", "email": "a@b.co"}), NOW)
	eq(confirm.get("needs_confirm", false), true, "sign up without a token means confirm the email")
	var cases := {
		"new wrong password": [Logic.SIGN_IN, 400, {"code": 400, "error_code": "invalid_credentials", "msg": "Invalid login credentials"}, "invalid_credentials"],
		"old wrong password": [Logic.SIGN_IN, 400, {"error": "invalid_grant", "error_description": "Invalid login credentials"}, "invalid_credentials"],
		"email taken": [Logic.SIGN_UP, 422, {"code": 422, "error_code": "user_already_exists", "msg": "User already registered"}, "email_exists"],
		"weak password": [Logic.SIGN_UP, 422, {"error_code": "weak_password", "msg": "Password should be at least 6 characters."}, "weak_password"],
		"not confirmed": [Logic.SIGN_IN, 400, {"error_code": "email_not_confirmed", "msg": "Email not confirmed"}, "email_not_confirmed"],
		"guest off": [Logic.GUEST, 422, {"error_code": "anonymous_provider_disabled", "msg": "Anonymous sign-ins are disabled"}, "guest_disabled"],
		"too many": [Logic.SIGN_IN, 429, {"msg": "rate limit"}, "rate_limited"],
		"refresh dead": [Logic.REFRESH, 400, {"error_code": "refresh_token_not_found", "msg": "Invalid Refresh Token"}, "session_expired"],
		"server broke": [Logic.SIGN_IN, 500, {}, "error"],
	}
	for label in cases:
		var c: Array = cases[label]
		var parsed := Logic.parse_response(c[0], HTTPRequest.RESULT_SUCCESS, c[1], JSON.stringify(c[2]), NOW)
		eq(parsed["reason"], c[3], "answer: " + label)
	eq(Logic.parse_response(Logic.SIGN_IN, HTTPRequest.RESULT_CANT_CONNECT, 0, "", NOW)["reason"], "offline", "no connection = offline")
	for reason in Logic.MESSAGES:
		truthy(Logic.message_for(reason).length() > 8, "plain message for " + reason)
	eq(Logic.message_for("whatever"), Logic.MESSAGES["error"], "unknown reasons read as a plain error")


func _test_saved_login() -> void:
	Logic.clear_session()
	eq(Logic.load_session(), {}, "no file = not logged in")
	var s := {"access_token": "AT", "refresh_token": "RT", "expires_at": NOW + 3600, "name": "Mauro", "is_guest": false}
	truthy(Logic.save_session(s), "login saves")
	eq(Logic.load_session()["name"], "Mauro", "login loads back")
	eq(Logic.needs_refresh(s, NOW), false, "a fresh login needs no refresh")
	eq(Logic.needs_refresh(s, NOW + 3600 - 60), true, "refresh 2 minutes before it runs out")
	eq(Logic.label_for(s), "Mauro", "hub shows the name")
	eq(Logic.label_for({}), "Log in", "hub says Log in when nobody is logged in")
	eq(Logic.label_for({"access_token": "a", "refresh_token": "b", "is_guest": true}), "Guest", "a nameless guest reads Guest")
	Logic.clear_session()
	eq(FileAccess.file_exists(TEST_SAVE), false, "log out deletes the saved login")


func _test_not_configured() -> void:
	var c := _client("", "")
	var outcomes := _watch(c)
	eq(c.play_as_guest("Mauro"), false, "no project = no call")
	eq(_sent.size(), 0, "nothing is sent without a project")
	eq(outcomes[-1]["reason"], "not_configured", "says accounts are not connected")
	c.free()


func _test_create_and_log_in() -> void:
	Logic.clear_session()
	var c := _client()
	var outcomes := _watch(c)
	eq(c.sign_up("bad", "secret123", "Mauro"), false, "bad email stops before sending")
	eq(outcomes[-1]["reason"], "bad_email", "says the email is bad")
	eq(_sent.size(), 0, "nothing sent for a bad form")
	_answers.append({"code": 200, "body": _session_json("u1", "mauro@mail.com", false, "Mauro")})
	truthy(c.sign_up("Mauro@mail.com", "secret123", "Mauro"), "sign up goes out")
	eq(c.is_signed_in(), true, "logged in after sign up")
	eq(c.is_guest(), false, "an email account is not a guest")
	eq(c.label(), "Mauro", "label is the player name")
	eq(Logic.load_session()["user_id"], "u1", "login saved to the phone")
	truthy(str(outcomes[-1]["message"]).contains("Welcome"), "says welcome")
	var c2 := _client()
	eq(c2.is_signed_in(), true, "next app start is still logged in")
	c2.free()
	c.sign_out()
	_answers.append({"code": 400, "body": JSON.stringify({"error_code": "invalid_credentials", "msg": "Invalid login credentials"})})
	c.sign_in("mauro@mail.com", "wrongpass")
	eq(c.is_signed_in(), false, "wrong password stays logged out")
	eq(outcomes[-1]["message"], Logic.message_for("invalid_credentials"), "says wrong email or password")
	c.free()


func _test_guest_then_upgrade() -> void:
	Logic.clear_session()
	var c := _client()
	var outcomes := _watch(c)
	_answers.append({"code": 200, "body": _session_json("g1", "", true, "Kid")})
	c.play_as_guest("Kid")
	eq(c.is_guest(), true, "guest account made")
	eq(c.label(), "Kid", "guest keeps the name")
	_answers.append({"code": 200, "body": JSON.stringify({"id": "g1", "email": "kid@mail.com", "is_anonymous": false, "user_metadata": {"display_name": "Kid"}})})
	c.upgrade_guest("kid@mail.com", "secret123")
	eq(_sent[-1]["method"], HTTPClient.METHOD_PUT, "upgrade updates the same user")
	eq(c.is_guest(), false, "guest became a real account")
	eq(c.session["user_id"], "g1", "same account id after the upgrade")
	eq(c.session["email"], "kid@mail.com", "email saved")
	_answers.append({"code": 200, "body": JSON.stringify({"id": "g2", "email": "", "new_email": "k2@mail.com", "is_anonymous": true})})
	c.session["is_guest"] = true
	c.upgrade_guest("k2@mail.com", "secret123")
	eq(outcomes[-1].get("needs_confirm", false), true, "an unconfirmed email asks to check the inbox")
	c.free()


func _test_refresh() -> void:
	Logic.clear_session()
	Logic.save_session({"access_token": "OLD", "refresh_token": "RT1", "expires_at": NOW - 10, "name": "Mauro", "is_guest": false, "email": "m@mail.com", "user_id": "u1"})
	var c := _client()
	_answers.append({"code": 200, "body": JSON.stringify({"access_token": "NEW", "refresh_token": "RT2", "expires_in": 3600})})
	truthy(c.refresh_if_needed(), "an old login refreshes")
	eq(c.session["access_token"], "NEW", "new token saved")
	eq(c.session["name"], "Mauro", "the name survives a refresh")
	eq(c.refresh_if_needed(), false, "a fresh login does not refresh again")
	c.session["expires_at"] = NOW - 10
	_answers.append({"code": 400, "body": JSON.stringify({"error_code": "refresh_token_not_found"})})
	c.refresh_if_needed()
	eq(c.is_signed_in(), false, "a dead login logs out")
	c.free()
	Logic.save_session({"access_token": "OLD", "refresh_token": "RT1", "expires_at": NOW - 10, "is_guest": false})
	var c3 := _client()
	_answers.append({"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": ""})
	c3.refresh_if_needed()
	eq(c3.is_signed_in(), true, "no internet keeps the login")
	c3.free()


func _test_log_out_offline() -> void:
	Logic.save_session({"access_token": "AT", "refresh_token": "RT", "expires_at": NOW + 3600})
	var c := _client()
	_answers.append({"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": ""})
	truthy(c.sign_out(), "log out works")
	eq(c.is_signed_in(), false, "logged out even with no internet")
	eq(FileAccess.file_exists(TEST_SAVE), false, "saved login removed")
	eq(_sent[-1]["url"], URL + "/auth/v1/logout", "the server is told when possible")
	c.free()


func _test_screen() -> void:
	Logic.clear_session()
	var c := _client()
	var screen: Control = Screen.new()
	screen.client = c
	root.add_child(screen)
	eq(screen.mode(), "welcome", "logged out opens on the welcome page")
	for b in ["LogIn", "Create", "Guest", "Later"]:
		var button: Button = screen.button(b)
		truthy(button != null, "welcome has " + b)
		truthy(button.custom_minimum_size.y >= 48, b + " is a 48px finger target")
	screen.button("Create").pressed.emit()
	eq(screen.mode(), "create", "Create account opens the form")
	truthy(screen.field("password").secret, "password is hidden")
	screen.field("name").text = "Mauro"
	screen.field("email").text = "nope"
	screen.field("password").text = "secret123"
	screen.button("Submit").pressed.emit()
	eq(screen.status_text(), Logic.message_for("bad_email"), "a bad email is explained")
	eq(screen.mode(), "create", "stays on the form")
	screen.field("email").text = "mauro@mail.com"
	_answers.append({"code": 200, "body": _session_json("u1", "mauro@mail.com", false, "Mauro")})
	screen.button("Submit").pressed.emit()
	eq(screen.mode(), "signed_in", "a new account shows the account page")
	eq(screen.button("Upgrade"), null, "an email account has no upgrade button")
	truthy(screen.status_text().contains("Welcome"), "welcome message")
	screen.button("LogOut").pressed.emit()
	eq(screen.mode(), "welcome", "log out goes back to welcome")
	screen.button("Guest").pressed.emit()
	screen.field("name").text = "Kid"
	_answers.append({"code": 200, "body": _session_json("g1", "", true, "Kid")})
	screen.button("Submit").pressed.emit()
	eq(screen.mode(), "signed_in", "guest lands on the account page")
	truthy(screen.button("Upgrade") != null, "a guest can add an email")
	screen.button("Upgrade").pressed.emit()
	eq(screen.mode(), "upgrade", "upgrade form")
	var closed := [false]
	screen.closed.connect(func() -> void: closed[0] = true)
	screen.close()
	truthy(closed[0], "close tells the hub")
	c.free()
	var offline_client := _client("", "")
	var offline: Control = Screen.new()
	offline.client = offline_client
	root.add_child(offline)
	eq(offline.status_text(), Logic.message_for("not_configured"), "no project shows 'not connected yet'")
	offline.queue_free()
	offline_client.free()
	Logic.clear_session()


func _test_hub_button() -> void:
	Logic.clear_session()
	var hub: MobileHub = load("res://scenes/mobile_hub.tscn").instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	var button := hub.find_child("Account", true, false) as Button
	truthy(button != null, "hub has an Account button")
	eq(button.text, "Log in", "logged out reads Log in")
	truthy(button.custom_minimum_size.y >= 48, "Account is a 48px finger target")
	eq(hub.door_count(), 6, "Account is not a Koliseo or Stasis door")
	eq(hub.find_child("AccountScreen", true, false), null, "tests never auto-open the account screen")
	button.pressed.emit()
	truthy(hub.find_child("AccountScreen", true, false) != null, "Account opens the account screen")
	hub.queue_free()


func _test_no_secret_key() -> void:
	# Supabase keys are JWTs ("eyJ..."). Only the public anon key may ever be
	# pasted into account_config.gd; no key at all lives in the code files.
	for path in ["res://backend/account_logic.gd", "res://backend/account_client.gd", "res://scenes/account_screen.gd"]:
		eq(FileAccess.get_file_as_string(path).contains("eyJ"), false, "no key in " + path)
	var config := FileAccess.get_file_as_string("res://backend/account_config.gd")
	truthy(config.contains("NEVER put the service_role key"), "config warns about the service_role key")


# --- helpers -----------------------------------------------------------------

func _client(url: String = URL, key: String = KEY) -> Node:
	var c: Node = Client.new()
	c.url = url
	c.anon_key = key
	c.clock = func() -> int: return NOW
	c.transport = _fake
	root.add_child(c)
	_sent.clear()
	return c


func _watch(c: Node) -> Array:
	var outcomes: Array = []
	c.finished.connect(func(o: Dictionary) -> void: outcomes.append(o))
	return outcomes


func _fake(request: Dictionary) -> Dictionary:
	_sent.append(request)
	if _answers.is_empty():
		return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": "{}"}
	var a: Dictionary = _answers.pop_front()
	return {"result": int(a.get("result", HTTPRequest.RESULT_SUCCESS)), "code": int(a.get("code", 200)), "body": str(a.get("body", ""))}


func _session_json(id: String, email: String, guest: bool, display_name: String) -> String:
	return JSON.stringify({
		"access_token": "AT-" + id, "token_type": "bearer", "expires_in": 3600, "refresh_token": "RT-" + id,
		"user": {"id": id, "email": email, "is_anonymous": guest, "user_metadata": {"display_name": display_name}},
	})


func eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s — got %s, expected %s" % [label, str(actual), str(expected)])


func truthy(value: Variant, label: String) -> void:
	eq(bool(value), true, label)
