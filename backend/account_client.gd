extends Node

## Talks to Supabase Auth for the account screen and the hub (Step 1:
## email + password and guest accounts). Rules and messages live in
## account_logic.gd. One call at a time.
##
## Tests set `transport` to a Callable(request: Dictionary) -> Dictionary
## {result, code, body} so no network is used.

signal changed
signal busy_changed(is_busy: bool)
signal finished(outcome: Dictionary)

const Logic := preload("res://backend/account_logic.gd")
const _Config := preload("res://backend/account_config.gd")

var url: String = _Config.SUPABASE_URL
var anon_key: String = _Config.SUPABASE_ANON_KEY
var session: Dictionary = {}
var transport: Callable
## Unix seconds. Tests can pin the clock.
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

var _http: HTTPRequest
var _kind: String = ""
## A call waiting for a refresh to finish first.
var _after_refresh: Dictionary = {}


func _ready() -> void:
	session = Logic.load_session()
	_http = HTTPRequest.new()
	_http.name = "AuthRequest"
	_http.use_threads = true
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_http)


func is_configured() -> bool:
	return Logic.is_configured(url, anon_key)


func is_busy() -> bool:
	return _kind != ""


func is_signed_in() -> bool:
	return Logic.is_signed_in(session)


func is_guest() -> bool:
	return is_signed_in() and bool(session.get("is_guest", false))


func label() -> String:
	return Logic.label_for(session)


func sign_up(email: String, password: String, display_name: String) -> bool:
	var bad := _first_problem([Logic.check_name(display_name), Logic.check_email(email), Logic.check_password(password)])
	if bad != "":
		return _refuse(Logic.SIGN_UP, bad)
	return _send(Logic.SIGN_UP, {"email": email, "password": password, "name": display_name})


func sign_in(email: String, password: String) -> bool:
	var bad := _first_problem([Logic.check_email(email), "" if password != "" else "short_password"])
	if bad != "":
		return _refuse(Logic.SIGN_IN, bad)
	return _send(Logic.SIGN_IN, {"email": email, "password": password})


func play_as_guest(display_name: String) -> bool:
	var bad := Logic.check_name(display_name)
	if bad != "":
		return _refuse(Logic.GUEST, bad)
	return _send(Logic.GUEST, {"name": display_name})


## A guest adds an email + password and keeps the same account.
func upgrade_guest(email: String, password: String) -> bool:
	if not is_signed_in():
		return _refuse(Logic.UPGRADE, "not_signed_in")
	var bad := _first_problem([Logic.check_email(email), Logic.check_password(password)])
	if bad != "":
		return _refuse(Logic.UPGRADE, bad)
	if _refresh_first(Logic.UPGRADE, {"email": email, "password": password}):
		return true
	return _send(Logic.UPGRADE, {"email": email, "password": password})


## Logs out here even when the server cannot be reached.
func sign_out() -> bool:
	if not is_signed_in():
		return _refuse(Logic.SIGN_OUT, "not_signed_in")
	var old := session
	session = {}
	Logic.clear_session()
	changed.emit()
	if not is_configured() or is_busy():
		finished.emit({"ok": true, "kind": Logic.SIGN_OUT, "reason": ""})
		return true
	return _send(Logic.SIGN_OUT, {}, old)


## Called by the hub on start. Quietly renews an old login.
func refresh_if_needed() -> bool:
	if not is_configured() or is_busy() or not Logic.needs_refresh(session, clock.call()):
		return false
	return _send(Logic.REFRESH, {})



func _refresh_first(kind: String, fields: Dictionary) -> bool:
	if not Logic.needs_refresh(session, clock.call()) or not is_configured():
		return false
	_after_refresh = {"kind": kind, "fields": fields}
	return _send(Logic.REFRESH, {})


func _first_problem(problems: Array) -> String:
	for p in problems:
		if str(p) != "":
			return str(p)
	return ""


func _refuse(kind: String, reason: String) -> bool:
	finished.emit({"ok": false, "kind": kind, "reason": reason, "message": Logic.message_for(reason)})
	return false


func _send(kind: String, fields: Dictionary, with_session: Dictionary = session) -> bool:
	if not is_configured():
		return _refuse(kind, "not_configured")
	if is_busy():
		return _refuse(kind, "busy")
	var request := Logic.build_request(kind, fields, with_session, url, anon_key)
	_kind = kind
	busy_changed.emit(true)
	if transport.is_valid():
		var answer: Dictionary = transport.call(request)
		_complete(int(answer.get("result", HTTPRequest.RESULT_SUCCESS)), int(answer.get("code", 0)), str(answer.get("body", "")))
		return true
	var err := _http.request(str(request["url"]), request["headers"], int(request["method"]), str(request["body"]))
	if err != OK:
		_complete(HTTPRequest.RESULT_CANT_CONNECT, 0, "")
	return true


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_complete(result, code, body.get_string_from_utf8())


func _complete(result: int, code: int, body_text: String) -> void:
	var kind := _kind
	_kind = ""
	busy_changed.emit(false)
	var parsed := Logic.parse_response(kind, result, code, body_text, clock.call())
	var outcome := {"ok": bool(parsed.get("ok", false)), "kind": kind, "reason": str(parsed.get("reason", ""))}
	if kind == Logic.SIGN_OUT:
		# Already logged out on this phone.
		outcome["ok"] = true
		outcome["reason"] = ""
		finished.emit(outcome)
		return
	if outcome["ok"]:
		if parsed.has("session"):
			var fresh: Dictionary = parsed["session"]
			if kind == Logic.REFRESH:
				# A refresh answer may leave out the name; keep what we had.
				for k in ["name", "email", "is_guest", "user_id", "pending_email"]:
					if not fresh.has(k) and session.has(k):
						fresh[k] = session[k]
			session = fresh
			Logic.save_session(session)
			changed.emit()
		elif parsed.has("user"):
			session = Logic.merge_user(session, parsed["user"])
			Logic.save_session(session)
			changed.emit()
		if bool(parsed.get("needs_confirm", false)):
			outcome["needs_confirm"] = true
		if str(session.get("pending_email", "")) != "" and kind == Logic.UPGRADE:
			outcome["needs_confirm"] = true
	elif kind == Logic.REFRESH and outcome["reason"] == "session_expired":
		session = {}
		Logic.clear_session()
		changed.emit()
	outcome["message"] = _success_text(kind, outcome) if outcome["ok"] else Logic.message_for(str(outcome["reason"]))
	if kind == Logic.REFRESH and not _after_refresh.is_empty():
		var next := _after_refresh
		_after_refresh = {}
		if outcome["ok"]:
			_send(str(next["kind"]), next["fields"])
			return
	finished.emit(outcome)


func _success_text(kind: String, outcome: Dictionary) -> String:
	if bool(outcome.get("needs_confirm", false)):
		return "Check your email and tap the link to confirm it. Then log in here."
	match kind:
		Logic.SIGN_UP:
			return "Account made. Welcome, %s!" % label()
		Logic.SIGN_IN:
			return "Welcome back, %s!" % label()
		Logic.GUEST:
			return "You are playing as guest %s. Add an email later to keep this account safe." % label()
		Logic.UPGRADE:
			return "Email saved. You can now log in with it on any phone."
	return ""
