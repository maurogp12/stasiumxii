class_name ApkUpdate
extends RefCounted

## Pure logic for the mobile hub's Actualizar check.
## Remote stamps are the existing GitHub tags `mobile-0.1.N-debug`
## (version name `0.1.N-mobile`) and the Android versionCode already
## printed in those release notes as `(code N)`. The running build is
## compared with PackageManager versionCode / versionName, or with the
## baked export stamp in apk_version_stamp.gd when that read fails.
## No second numbering scheme, and no GitHub token.

const REPO := "maurogp12/stasiumxii"
const ASSET_NAME := "stasiumxii-mobile-debug.apk"
const PACKAGE_ID := "com.maurogp12.stasiumxii.mobile"
const DOWNLOAD_DIR := "user://updates"
const USER_AGENT := "STASIUM-XII-mobile"

static func releases_api_url() -> String:
	return "https://api.github.com/repos/%s/releases?per_page=100" % REPO


static func download_user_path() -> String:
	return DOWNLOAD_DIR.path_join(ASSET_NAME)


static func api_headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: %s" % USER_AGENT,
		"Accept: application/vnd.github+json",
	])


static func download_headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: %s" % USER_AGENT,
		"Accept: application/octet-stream",
	])


static func headers_are_public(headers: PackedStringArray) -> bool:
	for header in headers:
		var lower := header.to_lower()
		if lower.begins_with("authorization:"):
			return false
		if lower.contains("bearer"):
			return false
		if lower.contains("token"):
			return false
	return true


## `mobile-0.1.19-debug` → version name `0.1.19-mobile` and parts [0, 1, 19].
static func version_from_tag(tag: String) -> Dictionary:
	var matched := RegEx.create_from_string("^mobile-(\\d+)\\.(\\d+)\\.(\\d+)-debug$").search(tag.strip_edges())
	if matched == null:
		return {}
	var parts: Array[int] = [
		int(matched.get_string(1)),
		int(matched.get_string(2)),
		int(matched.get_string(3)),
	]
	return {
		"version_name": "%d.%d.%d-mobile" % [parts[0], parts[1], parts[2]],
		"parts": parts,
	}


static func parts_from_version_name(version_name: String) -> Array:
	var matched := RegEx.create_from_string("^(\\d+)\\.(\\d+)\\.(\\d+)").search(version_name.strip_edges())
	if matched == null:
		return []
	return [int(matched.get_string(1)), int(matched.get_string(2)), int(matched.get_string(3))]


## Positive when `left` is a newer stamp than `right`.
static func compare_parts(left: Array, right: Array) -> int:
	if left.size() < 3 or right.size() < 3:
		return 0
	for index in 3:
		var a := int(left[index])
		var b := int(right[index])
		if a > b:
			return 1
		if a < b:
			return -1
	return 0


## Android versionCode wins when both sides have one. Otherwise the
## version name (`0.1.N-mobile`) is the same stamp Godot writes.
## "update" / "current" / "unknown".
static func compare_to_installed(local_code: int, local_name: String, remote_code: int, remote_name: String) -> String:
	if remote_code > 0 and local_code > 0:
		if remote_code > local_code:
			return "update"
		return "current"
	var local_parts := parts_from_version_name(local_name)
	var remote_parts := parts_from_version_name(remote_name)
	if local_parts.is_empty() or remote_parts.is_empty():
		return "unknown"
	if compare_parts(remote_parts, local_parts) > 0:
		return "update"
	return "current"


static func version_code_from_body(body: String, version_name: String) -> int:
	if version_name.is_empty():
		return 0
	var at := body.find(version_name)
	if at < 0:
		return 0
	var window := body.substr(at, mini(96, body.length() - at))
	var matched := RegEx.create_from_string("\\(code\\s+(\\d+)\\)").search(window)
	if matched == null:
		return 0
	return int(matched.get_string(1))


static func public_download_url(tag: String) -> String:
	if version_from_tag(tag).is_empty():
		return ""
	return "https://github.com/%s/releases/download/%s/%s" % [REPO, tag, ASSET_NAME]


static func is_public_apk_url(url: String, tag: String) -> bool:
	var expected := public_download_url(tag)
	return not expected.is_empty() and url == expected


static func parse_release(item: Dictionary) -> Dictionary:
	if bool(item.get("draft", false)):
		return {"ok": false, "reason": "draft"}
	var tag := str(item.get("tag_name", ""))
	var named := version_from_tag(tag)
	if named.is_empty():
		return {"ok": false, "reason": "tag"}
	if not _has_apk_asset(item.get("assets", [])):
		return {"ok": false, "reason": "asset"}
	var version_name := str(named["version_name"])
	var url := public_download_url(tag)
	if not is_public_apk_url(url, tag):
		return {"ok": false, "reason": "url"}
	return {
		"ok": true,
		"tag": tag,
		"version_name": version_name,
		"version_code": version_code_from_body(str(item.get("body", "")), version_name),
		"parts": named["parts"],
		"download_url": url,
	}


static func parse_releases_json(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		return {"ok": false, "reason": "json"}
	var best: Dictionary = {}
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var release := parse_release(item)
		if not release.get("ok", false):
			continue
		if best.is_empty() or _outranks(release, best):
			best = release
	if best.is_empty():
		return {"ok": false, "reason": "not_found"}
	return best


## "ok" / "offline" / "rate_limit" / "not_found" / "error".
## `result` is an HTTPRequest.Result value.
static func classify_http(result: int, response_code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		if result == HTTPRequest.RESULT_CANT_CONNECT \
				or result == HTTPRequest.RESULT_CANT_RESOLVE \
				or result == HTTPRequest.RESULT_CONNECTION_ERROR \
				or result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR \
				or result == HTTPRequest.RESULT_NO_RESPONSE \
				or result == HTTPRequest.RESULT_TIMEOUT:
			return "offline"
		return "error"
	if response_code == 200:
		return "ok"
	if response_code == 404:
		return "not_found"
	if response_code == 403 or response_code == 429:
		return "rate_limit"
	return "error"


static func classify_download(result: int, response_code: int) -> String:
	if result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN \
			or result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		return "download_failed"
	var kind := classify_http(result, response_code)
	if kind == "ok":
		return "ok"
	if kind == "not_found":
		return "not_found"
	if kind == "offline" or kind == "rate_limit":
		return kind
	return "download_failed"


static func looks_like_apk(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var header := file.get_buffer(4)
	file.close()
	return header.size() >= 2 and header[0] == 0x50 and header[1] == 0x4B


## What the hub should do after a parsed release.
## `action` is "message" or "download".
## An unreadable local version on Android still downloads the newest
## public debug APK (same package, same cert). It does not stop on "version".
static func plan_after_release(on_android: bool, local_ok: bool, local_code: int, local_name: String, remote: Dictionary) -> Dictionary:
	var remote_name := str(remote.get("version_name", ""))
	var remote_code := int(remote.get("version_code", 0))
	if on_android and not local_ok:
		return _download_plan(remote, remote_name, "version_fetch")
	var cmp := compare_to_installed(local_code, local_name, remote_code, remote_name)
	if cmp == "current":
		var shown := local_name if not local_name.is_empty() else remote_name
		return {"action": "message", "kind": "current", "detail": shown}
	if not on_android or cmp == "unknown":
		var kind := "not_android" if not on_android else "error"
		return {"action": "message", "kind": kind, "detail": remote_name}
	return _download_plan(remote, remote_name, "downloading")


static func _download_plan(remote: Dictionary, remote_name: String, kind: String) -> Dictionary:
	var url := str(remote.get("download_url", ""))
	var tag := str(remote.get("tag", ""))
	if not is_public_apk_url(url, tag):
		var failed := "version" if kind == "version_fetch" else "error"
		return {"action": "message", "kind": failed, "detail": ""}
	return {
		"action": "download",
		"kind": kind,
		"detail": remote_name,
		"url": url,
		"tag": tag,
	}


static func message_for(kind: String, detail: String = "") -> String:
	match kind:
		"checking":
			return "Buscando actualización..."
		"current":
			if detail.is_empty():
				return "Al día."
			return "Al día · %s" % detail
		"offline":
			return "Sin conexión. Inténtalo de nuevo."
		"rate_limit":
			return "GitHub limitó las consultas. Prueba más tarde."
		"not_found":
			return "No hay un APK publicado."
		"downloading":
			if detail.is_empty():
				return "Descargando..."
			return "Descargando %s..." % detail
		"need_permission":
			return "Permite instalar apps desconocidas y vuelve al juego."
		"installing":
			return "Abriendo el instalador..."
		"not_android":
			if detail.is_empty():
				return "Actualizar instala en el teléfono."
			return "Actualizar instala en el teléfono. Última: %s." % detail
		"download_failed":
			return "La descarga falló. Inténtalo de nuevo."
		"install_failed":
			return "Android no abrió el instalador."
		"version":
			return "No se pudo leer la versión instalada."
		"version_fetch":
			if detail.is_empty():
				return "No se pudo leer la versión instalada. Descargando la última..."
			return "No se pudo leer la versión instalada. Descargando %s..." % detail
		_:
			return "No se pudo comprobar la actualización."


static func _has_apk_asset(assets: Variant) -> bool:
	if typeof(assets) != TYPE_ARRAY:
		return false
	for asset in assets:
		if typeof(asset) != TYPE_DICTIONARY:
			continue
		if str(asset.get("name", "")) == ASSET_NAME:
			return true
	return false


static func _outranks(candidate: Dictionary, incumbent: Dictionary) -> bool:
	var by_name := compare_parts(candidate.get("parts", []), incumbent.get("parts", []))
	if by_name != 0:
		return by_name > 0
	return int(candidate.get("version_code", 0)) > int(incumbent.get("version_code", 0))
