extends RefCounted

## Player accounts, Step 1 (Mauro 10 Oct 2026: "Yes you build it, email and
## guest, start now"). Email + password accounts and guest accounts on
## Supabase Auth. A guest can add an email + password later and keeps the
## same account.
##
## Pure helpers only: building the HTTP requests, reading the answers, the
## saved session and the plain-words messages. The network calls live in
## account_client.gd; the screen is scenes/account_screen.gd.
##
## Step 1 does not move any progress. Levels, gear, Stills and the wallet
## stay in their own user:// files until Step 2 (cloud save).

const _Config := preload("res://backend/account_config.gd")

const MIN_PASSWORD := 8
const NAME_MIN := 3
const NAME_MAX := 16
## Refresh the login this many seconds before it runs out.
const REFRESH_MARGIN := 120

const SIGN_UP := "sign_up"
const SIGN_IN := "sign_in"
const GUEST := "guest"
const UPGRADE := "upgrade"
const REFRESH := "refresh"
const SIGN_OUT := "sign_out"

const MESSAGES := {
	"not_configured": "Accounts are not connected yet. Your progress stays on this phone.",
	"offline": "No internet. Check your connection and try again.",
	"bad_email": "Type a real email, like name@mail.com.",
	"short_password": "The password needs at least 8 characters.",
	"bad_name": "Pick a name with 3 to 16 letters or numbers.",
	"invalid_credentials": "Wrong email or password.",
	"email_exists": "That email already has an account. Log in instead.",
	"weak_password": "That password is too easy to guess. Try a longer one.",
	"email_not_confirmed": "Confirm your email first (check your inbox), then log in.",
	"guest_disabled": "Guest play is turned off on the server right now.",
	"rate_limited": "Too many tries. Wait a minute and try again.",
	"session_expired": "Please log in again.",
	"not_signed_in": "You are not logged in.",
	"busy": "Wait, still working on the last step.",
	"error": "Something went wrong. Try again.",
}

## Tests point this at their own file.
static var save_path: String = "user://account.json"


static func is_configured(url: String = _Config.SUPABASE_URL, key: String = _Config.SUPABASE_ANON_KEY) -> bool:
	return url.strip_edges().begins_with("https://") and not key.strip_edges().is_empty()


static func message_for(reason: String) -> String:
	return str(MESSAGES.get(reason, MESSAGES["error"]))


# --- input checks ------------------------------------------------------------

static func clean_email(email: String) -> String:
	return email.strip_edges().to_lower()


static func clean_name(display_name: String) -> String:
	return display_name.strip_edges()


## "" when fine, else a MESSAGES key.
static func check_email(email: String) -> String:
	var e := clean_email(email)
	var at := e.find("@")
	if e.length() < 5 or at < 1 or e.count("@") != 1 or e.contains(" "):
		return "bad_email"
	var domain := e.substr(at + 1)
	if not domain.contains(".") or domain.begins_with(".") or domain.ends_with("."):
		return "bad_email"
	return ""


static func check_password(password: String) -> String:
	return "" if password.length() >= MIN_PASSWORD else "short_password"


## Letters, numbers, space, _ and -, 3 to 16 long.
static func check_name(display_name: String) -> String:
	var n := clean_name(display_name)
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return "bad_name"
	var regex := RegEx.new()
	regex.compile("^[\\p{L}\\p{N} _-]+$")
	if regex.search(n) == null:
		return "bad_name"
	return ""


# --- requests ----------------------------------------------------------------

## {url, method, headers, body} for one Supabase Auth call.
## `fields` holds email / password / name / refresh_token as needed.
static func build_request(kind: String, fields: Dictionary, session: Dictionary, url: String = _Config.SUPABASE_URL, key: String = _Config.SUPABASE_ANON_KEY) -> Dictionary:
	var base := url.strip_edges().trim_suffix("/") + "/auth/v1"
	var headers := PackedStringArray(["apikey: " + key.strip_edges(), "Content-Type: application/json"])
	var path := ""
	var method := HTTPClient.METHOD_POST
	var body := {}
	var bearer := false
	match kind:
		SIGN_UP:
			path = "/signup"
			body = {"email": clean_email(str(fields.get("email", ""))), "password": str(fields.get("password", "")),
				"data": {"display_name": clean_name(str(fields.get("name", "")))}}
		SIGN_IN:
			path = "/token?grant_type=password"
			body = {"email": clean_email(str(fields.get("email", ""))), "password": str(fields.get("password", ""))}
		GUEST:
			# A signup with no email and no password is a Supabase anonymous user.
			path = "/signup"
			body = {"data": {"display_name": clean_name(str(fields.get("name", "")))}}
		UPGRADE:
			path = "/user"
			method = HTTPClient.METHOD_PUT
			bearer = true
			body = {"email": clean_email(str(fields.get("email", ""))), "password": str(fields.get("password", ""))}
		REFRESH:
			path = "/token?grant_type=refresh_token"
			body = {"refresh_token": str(session.get("refresh_token", ""))}
		SIGN_OUT:
			path = "/logout"
			bearer = true
		_:
			return {}
	if bearer:
		headers.append("Authorization: Bearer " + str(session.get("access_token", "")))
	return {"url": base + path, "method": method, "headers": headers, "body": JSON.stringify(body)}


# --- answers -----------------------------------------------------------------

## Reads one answer. Always returns {ok, reason}; plus `session` for a login,
## `user` for an account change, `needs_confirm` when Supabase wants the
## email confirmed before the first login.
static func parse_response(kind: String, result: int, code: int, body_text: String, now: int) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "reason": "offline"}
	var parsed: Variant = JSON.parse_string(body_text) if not body_text.strip_edges().is_empty() else {}
	var data: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if code < 200 or code >= 300:
		return {"ok": false, "reason": error_reason(kind, code, data)}
	if kind == SIGN_OUT:
		return {"ok": true, "reason": ""}
	if data.has("access_token"):
		return {"ok": true, "reason": "", "session": session_from(data, now)}
	if kind == SIGN_UP and (data.has("id") or data.has("user")):
		return {"ok": true, "reason": "", "needs_confirm": true}
	if kind == UPGRADE and data.has("id"):
		return {"ok": true, "reason": "", "user": data}
	return {"ok": false, "reason": "error"}


static func error_reason(kind: String, code: int, data: Dictionary) -> String:
	if code == 429:
		return "rate_limited"
	var error_code := str(data.get("error_code", data.get("error", ""))).to_lower()
	var text := ("%s %s %s" % [data.get("msg", ""), data.get("message", ""), data.get("error_description", "")]).to_lower()
	match error_code:
		"invalid_credentials":
			return "invalid_credentials"
		"email_exists", "user_already_exists":
			return "email_exists"
		"weak_password":
			return "weak_password"
		"email_not_confirmed":
			return "email_not_confirmed"
		"anonymous_provider_disabled", "signup_disabled":
			return "guest_disabled" if kind == GUEST else "error"
		"over_request_rate_limit", "over_email_send_rate_limit":
			return "rate_limited"
		"refresh_token_not_found", "refresh_token_already_used", "session_not_found", "bad_jwt", "session_expired":
			return "session_expired"
		"validation_failed", "email_address_invalid":
			if text.contains("password"):
				return "weak_password"
			return "bad_email"
	if text.contains("invalid login"):
		return "invalid_credentials"
	if text.contains("already registered") or text.contains("already been registered"):
		return "email_exists"
	if text.contains("email not confirmed"):
		return "email_not_confirmed"
	if text.contains("anonymous sign-ins are disabled"):
		return "guest_disabled"
	if text.contains("refresh token") or text.contains("jwt"):
		return "session_expired"
	if kind == SIGN_IN and code == 400:
		return "invalid_credentials"
	if kind == REFRESH and (code == 400 or code == 401):
		return "session_expired"
	return "error"


## The parts of a Supabase session the game keeps.
static func session_from(data: Dictionary, now: int) -> Dictionary:
	var expires_at := int(data.get("expires_at", 0))
	if expires_at <= 0:
		expires_at = now + int(data.get("expires_in", 3600))
	var session := {
		"access_token": str(data.get("access_token", "")),
		"refresh_token": str(data.get("refresh_token", "")),
		"expires_at": expires_at,
	}
	var user: Dictionary = data.get("user", {}) if typeof(data.get("user", {})) == TYPE_DICTIONARY else {}
	return merge_user(session, user)


## Copies id / email / guest flag / name from a Supabase user into a session.
static func merge_user(session: Dictionary, user: Dictionary) -> Dictionary:
	var out := session.duplicate(true)
	if user.is_empty():
		return out
	out["user_id"] = str(user.get("id", out.get("user_id", "")))
	var email := str(user.get("email", "")) if user.get("email") != null else ""
	var pending := str(user.get("new_email", "")) if user.get("new_email") != null else ""
	out["email"] = email
	out["pending_email"] = pending
	out["is_guest"] = bool(user.get("is_anonymous", email.is_empty()))
	var meta: Variant = user.get("user_metadata", {})
	if typeof(meta) == TYPE_DICTIONARY and str((meta as Dictionary).get("display_name", "")) != "":
		out["name"] = str((meta as Dictionary)["display_name"])
	return out


static func is_signed_in(session: Dictionary) -> bool:
	return str(session.get("access_token", "")) != "" and str(session.get("refresh_token", "")) != ""


static func needs_refresh(session: Dictionary, now: int) -> bool:
	return is_signed_in(session) and now >= int(session.get("expires_at", 0)) - REFRESH_MARGIN


## What the hub button says.
static func label_for(session: Dictionary) -> String:
	if not is_signed_in(session):
		return "Log in"
	var display_name := str(session.get("name", ""))
	if display_name.is_empty():
		display_name = "Guest" if bool(session.get("is_guest", false)) else str(session.get("email", "Player")).get_slice("@", 0)
	return display_name


# --- saved login -------------------------------------------------------------

static func load_session() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not is_signed_in(parsed):
		return {}
	return parsed


static func save_session(session: Dictionary) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(session, "\t"))
	return true


static func clear_session() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
