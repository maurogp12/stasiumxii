extends Node
class_name ApkUpdateClient

## Hub-side check, download, and install handoff.
## Decisions live in ApkUpdate. The Android Intent lives in ApkInstall.

signal status_changed(text: String)
signal busy_changed(is_busy: bool)

const Update := preload("res://backend/apk_update.gd")
const Install := preload("res://backend/apk_install.gd")

var _http: HTTPRequest
var _phase: String = ""
var _release: Dictionary = {}
var _awaiting_permission: bool = false
var _pending_path: String = ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "ReleaseRequest"
	_http.use_threads = true
	_http.accept_gzip = true
	_http.body_size_limit = -1
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_http)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_on_resume()


func start() -> void:
	if _phase == "check" or _phase == "download":
		return
	_awaiting_permission = false
	_begin_check()


func _begin_check() -> void:
	_phase = "check"
	_release = {}
	busy_changed.emit(true)
	status_changed.emit(Update.message_for("checking"))
	_http.download_file = ""
	_http.timeout = 20.0
	var err := _http.request(Update.releases_api_url(), Update.api_headers())
	if err != OK:
		_finish("offline")


func _on_http(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var phase := _phase
	if phase == "check":
		_handle_check(result, response_code, body)
	elif phase == "download":
		_handle_download(result, response_code)


func _handle_check(result: int, response_code: int, body: PackedByteArray) -> void:
	var kind := Update.classify_http(result, response_code)
	if kind != "ok":
		_finish(kind)
		return
	var parsed := Update.parse_releases_json(body.get_string_from_utf8())
	if not parsed.get("ok", false):
		var reason := str(parsed.get("reason", "error"))
		_finish("not_found" if reason == "not_found" else "error")
		return
	var local := Install.installed_version()
	var on_android := OS.has_feature("android")
	var plan := Update.plan_after_release(
		on_android,
		bool(local.get("ok", false)),
		int(local.get("version_code", 0)),
		str(local.get("version_name", "")),
		parsed
	)
	if str(plan.get("action", "")) != "download":
		_finish(str(plan.get("kind", "error")), str(plan.get("detail", "")))
		return
	_release = parsed
	var gate := Install.can_request_package_installs()
	if not gate.get("allowed", false):
		_ask_permission()
		return
	_begin_download()


func _ask_permission() -> void:
	_phase = "permission"
	_awaiting_permission = true
	var opened := Install.open_unknown_sources_settings()
	busy_changed.emit(false)
	status_changed.emit(Update.message_for("need_permission"))
	if not opened.get("ok", false):
		_awaiting_permission = false
		_phase = ""


func _begin_download() -> void:
	var url := str(_release.get("download_url", ""))
	var tag := str(_release.get("tag", ""))
	if not Update.is_public_apk_url(url, tag):
		_finish("error")
		return
	var directory := ProjectSettings.globalize_path(Update.DOWNLOAD_DIR)
	var made := DirAccess.make_dir_recursive_absolute(directory)
	if made != OK and made != ERR_ALREADY_EXISTS:
		_finish("download_failed")
		return
	var path := ProjectSettings.globalize_path(Update.download_user_path())
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_phase = "download"
	_pending_path = path
	busy_changed.emit(true)
	status_changed.emit(Update.message_for("downloading", str(_release.get("version_name", ""))))
	_http.timeout = 180.0
	_http.download_file = path
	var err := _http.request(url, Update.download_headers())
	if err != OK:
		_discard(path)
		_finish("download_failed")


func _handle_download(result: int, response_code: int) -> void:
	var path := str(_http.download_file)
	_http.download_file = ""
	var kind := Update.classify_download(result, response_code)
	if kind != "ok" or not Update.looks_like_apk(path):
		_discard(path)
		_finish("download_failed" if kind == "ok" else kind)
		return
	_pending_path = path
	_handoff(path)


func _handoff(path: String) -> void:
	var gate := Install.can_request_package_installs()
	if not gate.get("allowed", false):
		_pending_path = path
		_ask_permission()
		return
	var handed := Install.handoff_apk(path)
	if not handed.get("ok", false):
		_finish("install_failed")
		return
	_pending_path = ""
	_finish("installing")


func _on_resume() -> void:
	if not _awaiting_permission:
		return
	_awaiting_permission = false
	var gate := Install.can_request_package_installs()
	if not gate.get("allowed", false):
		_finish("need_permission")
		return
	if _pending_path != "" and Update.looks_like_apk(_pending_path):
		_handoff(_pending_path)
		return
	if not _release.is_empty():
		_begin_download()
		return
	_finish("need_permission")


func _discard(path: String) -> void:
	if path.is_empty():
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if _pending_path == path:
		_pending_path = ""


func _finish(kind: String, detail: String = "") -> void:
	_phase = ""
	busy_changed.emit(false)
	status_changed.emit(Update.message_for(kind, detail))
