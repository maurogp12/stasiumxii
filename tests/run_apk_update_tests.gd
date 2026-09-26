extends SceneTree

## Actualizar: version compare, public GitHub URL parse, and the
## non-Android side of the install helper. The package-installer Intent
## is not launched here.
## Run: godot --headless --path . -s res://tests/run_apk_update_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_tag_and_version_compare()
	_test_release_parse_and_urls()
	_test_http_and_plan()
	_test_apk_header()
	_test_install_helper_stays_off_android()
	_test_preset_and_sources()
	print("APK update tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_tag_and_version_compare() -> void:
	var named := ApkUpdate.version_from_tag("mobile-0.1.19-debug")
	eq(named["version_name"], "0.1.19-mobile", "debug tag maps to the Android version name")
	eq(named["parts"], [0, 1, 19], "tag parts are the three numbers")
	eq(ApkUpdate.version_from_tag("mobile-0.1.19"), {}, "a tag without -debug is not a sideload cut")
	eq(ApkUpdate.version_from_tag("v0.1.19"), {}, "a non-mobile tag is ignored")
	eq(ApkUpdate.compare_parts([0, 1, 19], [0, 1, 9]), 1, "0.1.19 is newer than 0.1.9")
	eq(ApkUpdate.compare_to_installed(20, "0.1.19-mobile", 21, "0.1.20-mobile"), "update", "a higher versionCode is an update")
	eq(ApkUpdate.compare_to_installed(20, "0.1.19-mobile", 20, "0.1.19-mobile"), "current", "the same versionCode is current")
	eq(ApkUpdate.compare_to_installed(21, "0.1.20-mobile", 20, "0.1.19-mobile"), "current", "a newer install is already ahead")
	eq(ApkUpdate.compare_to_installed(20, "0.1.19-mobile", 20, "0.1.99-mobile"), "current", "versionCode wins when the name disagrees")
	eq(ApkUpdate.compare_to_installed(0, "0.1.19-mobile", 0, "0.1.20-mobile"), "update", "names compare when codes are missing")
	eq(ApkUpdate.compare_to_installed(0, "0.1.19-mobile", 0, "0.1.19-mobile"), "current", "the same version name is current")
	eq(ApkUpdate.compare_to_installed(0, "", 0, ""), "unknown", "empty stamps do not pretend to compare")
	eq(ApkUpdate.version_code_from_body("- Version: `0.1.19-mobile` (code 20)\n", "0.1.19-mobile"), 20, "release notes carry the Android versionCode")
	eq(ApkUpdate.version_code_from_body("Version: `0.1.9-mobile` (code 10)", "0.1.19-mobile"), 0, "a different stamp's code is not reused")


func _test_release_parse_and_urls() -> void:
	var tag := "mobile-0.1.19-debug"
	var url := ApkUpdate.public_download_url(tag)
	eq(url, "https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.19-debug/stasiumxii-mobile-debug.apk", "public download URL")
	eq(ApkUpdate.is_public_apk_url(url, tag), true, "the canonical URL is accepted")
	eq(ApkUpdate.is_public_apk_url(url + "?token=secret", tag), false, "a token query is rejected")
	eq(ApkUpdate.is_public_apk_url("http://github.com/maurogp12/stasiumxii/releases/download/mobile-0.1.19-debug/stasiumxii-mobile-debug.apk", tag), false, "plain http is rejected")
	eq(ApkUpdate.is_public_apk_url("https://api.github.com/repos/maurogp12/stasiumxii/releases/assets/1", tag), false, "the API asset URL is not the public download")
	eq(ApkUpdate.is_public_apk_url("https://github.com/other/stasiumxii/releases/download/mobile-0.1.19-debug/stasiumxii-mobile-debug.apk", tag), false, "another repo is rejected")
	eq(ApkUpdate.public_download_url("../secret"), "", "a bad tag builds no URL")
	eq(ApkUpdate.headers_are_public(ApkUpdate.api_headers()), true, "release check headers stay public")
	eq(ApkUpdate.headers_are_public(ApkUpdate.download_headers()), true, "download headers stay public")
	eq(ApkUpdate.headers_are_public(PackedStringArray(["Authorization: Bearer secret"])), false, "an auth header is not public")
	truthy(ApkUpdate.releases_api_url().begins_with("https://api.github.com/repos/maurogp12/stasiumxii/releases"), "check uses the public releases API")
	var parsed := ApkUpdate.parse_releases_json(_fixture_json())
	eq(parsed.get("ok", false), true, "fixture yields a release")
	eq(parsed.get("tag", ""), "mobile-0.1.19-debug", "newest playable debug tag wins")
	eq(parsed.get("version_name", ""), "0.1.19-mobile", "parsed version name")
	eq(int(parsed.get("version_code", 0)), 20, "parsed versionCode")
	eq(parsed.get("download_url", ""), url, "parsed URL ignores a hostile browser_download_url")
	eq(ApkUpdate.parse_releases_json("[]").get("reason", ""), "not_found", "no matching release is not_found")
	eq(ApkUpdate.parse_releases_json("{\"message\":\"nope\"}").get("reason", ""), "json", "an error object is not a release list")
	eq(ApkUpdate.message_for("current", "0.1.19-mobile"), "Al día · 0.1.19-mobile", "up to date message names the stamp")
	eq(ApkUpdate.message_for("offline").is_empty(), false, "offline message is readable")
	eq(ApkUpdate.message_for("rate_limit").is_empty(), false, "rate-limit message is readable")
	eq(ApkUpdate.message_for("not_found").is_empty(), false, "missing release message is readable")


func _test_http_and_plan() -> void:
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_SUCCESS, 200), "ok", "200 is ok")
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_CANT_CONNECT, 0), "offline", "cant connect is offline")
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_CANT_RESOLVE, 0), "offline", "dns failure is offline")
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_TIMEOUT, 0), "offline", "timeout is offline")
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_SUCCESS, 404), "not_found", "404 is not found")
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_SUCCESS, 429), "rate_limit", "429 is rate limit")
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_SUCCESS, 403), "rate_limit", "403 is rate limit")
	eq(ApkUpdate.classify_http(HTTPRequest.RESULT_SUCCESS, 500), "error", "500 is a readable error")
	eq(ApkUpdate.classify_download(HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR, 0), "download_failed", "a short write fails the download")
	var remote := {
		"tag": "mobile-0.1.20-debug",
		"version_name": "0.1.20-mobile",
		"version_code": 21,
		"download_url": ApkUpdate.public_download_url("mobile-0.1.20-debug"),
	}
	var desktop := ApkUpdate.plan_after_release(false, false, 0, "", remote)
	eq(desktop["action"], "message", "desktop does not download an APK")
	eq(desktop["kind"], "not_android", "desktop says the install is on the phone")
	var unread := ApkUpdate.plan_after_release(true, false, 0, "", remote)
	eq(unread["action"], "download", "Android with an unreadable local version still fetches the newest APK")
	eq(unread["kind"], "version_fetch", "the status says the local read failed while the latest is fetched")
	eq(unread["url"], remote["download_url"], "the unread path uses the public release file")
	var fetch_line := ApkUpdate.message_for("version_fetch", "0.1.20-mobile")
	truthy(fetch_line.contains("No se pudo leer la versión instalada"), "unread fetch says the local read failed")
	truthy(fetch_line.contains("0.1.20-mobile"), "unread fetch names the APK being downloaded")
	var hostile := remote.duplicate()
	hostile["download_url"] = "https://evil.example/apk"
	var blocked := ApkUpdate.plan_after_release(true, false, 0, "", hostile)
	eq(blocked["action"], "message", "an unreadable version does not fetch a non-public URL")
	eq(blocked["kind"], "version", "without a public APK the version read still reports failure")
	var same := ApkUpdate.plan_after_release(true, true, 21, "0.1.20-mobile", remote)
	eq(same["action"], "message", "the same stamp does not download")
	eq(same["kind"], "current", "the same stamp is current")
	var newer := ApkUpdate.plan_after_release(true, true, 20, "0.1.19-mobile", remote)
	eq(newer["action"], "download", "a newer versionCode downloads")
	eq(newer["url"], remote["download_url"], "the download URL is the public release file")


func _test_apk_header() -> void:
	var bad := "user://apk_update_test_bad.bin"
	var good := "user://apk_update_test_good.bin"
	var file := FileAccess.open(bad, FileAccess.WRITE)
	file.store_string("<html>not an apk</html>")
	file.close()
	eq(ApkUpdate.looks_like_apk(bad), false, "an html body is not an apk")
	file = FileAccess.open(good, FileAccess.WRITE)
	file.store_8(0x50)
	file.store_8(0x4B)
	file.store_8(0x03)
	file.store_8(0x04)
	file.close()
	eq(ApkUpdate.looks_like_apk(good), true, "a zip local header counts as an apk")
	eq(ApkUpdate.looks_like_apk("user://apk_update_missing.apk"), false, "a missing file is not an apk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(good))


func _test_install_helper_stays_off_android() -> void:
	var installed := ApkInstall.installed_version()
	eq(installed["ok"], false, "headless has no Android package")
	eq(installed["reason"], "not_android", "missing package says not_android")
	eq(int(installed["version_code"]), 0, "headless does not invent a versionCode")
	var stamp := ApkInstall.export_stamp()
	eq(stamp["version_name"], ApkInstall.version_from_stamp()["version_name"], "export_stamp matches the baked fallback")
	eq(int(stamp["version_code"]), int(ApkInstall.version_from_stamp()["version_code"]), "export_stamp code matches the baked fallback")
	var baked := ApkInstall.version_from_stamp(ApkUpdate.PACKAGE_ID)
	eq(baked["ok"], true, "the baked stamp is a usable local version")
	eq(baked["reason"], "stamp", "the fallback says it came from the export stamp")
	eq(baked["package"], ApkUpdate.PACKAGE_ID, "the stamp keeps the package id it was given")
	eq(int(baked["version_code"]) > 0, true, "the baked stamp has a versionCode")
	var gate := ApkInstall.can_request_package_installs()
	eq(gate["allowed"], false, "headless cannot request package installs")
	eq(gate["reason"], "not_android", "permission probe says not_android")
	var settings := ApkInstall.open_unknown_sources_settings()
	eq(settings["ok"], false, "headless does not open Android settings")
	eq(settings["reason"], "not_android", "settings handoff stays off Android")
	var handoff := ApkInstall.handoff_apk("/tmp/stasiumxii-mobile-debug.apk")
	eq(handoff["ok"], false, "headless does not launch the package installer")
	eq(handoff["reason"], "not_android", "installer handoff says not_android")
	var spec := ApkInstall.install_intent_spec(
		ApkUpdate.PACKAGE_ID,
		"/data/data/com.maurogp12.stasiumxii.mobile/files/updates/stasiumxii-mobile-debug.apk"
	)
	eq(spec["action"], "android.intent.action.VIEW", "installer action is VIEW")
	eq(spec["mime"], "application/vnd.android.package-archive", "installer mime is the apk type")
	eq(spec["authority"], "com.maurogp12.stasiumxii.mobile.fileprovider", "FileProvider authority is this package")
	eq(spec["grant_read"], true, "the installer can read the APK")
	eq(spec["new_task"], true, "the installer is a new task")
	var sources := ApkInstall.unknown_sources_intent_spec(ApkUpdate.PACKAGE_ID)
	eq(sources["action"], "android.settings.MANAGE_UNKNOWN_APP_SOURCES", "Android 8+ unknown-sources settings action")
	eq(sources["data"], "package:com.maurogp12.stasiumxii.mobile", "the settings screen targets this package")


func _test_preset_and_sources() -> void:
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	truthy(preset.contains("android.permission.REQUEST_INSTALL_PACKAGES"), "custom permission is REQUEST_INSTALL_PACKAGES")
	truthy(preset.contains("permissions/internet=true"), "INTERNET stays on")
	truthy(preset.contains("permissions/install_packages=false"), "the signature INSTALL_PACKAGES checkbox stays off")
	truthy(preset.contains('package/unique_name="com.maurogp12.stasiumxii.mobile"'), "package id is unchanged")
	truthy(preset.contains('keystore/debug="res://build_tools/mobile/stasiumxii-mobile-debug.keystore"'), "pinned debug keystore path is unchanged")
	var name_match := RegEx.create_from_string("(?m)^version/name=\"([^\"]+)\"").search(preset)
	var code_match := RegEx.create_from_string("(?m)^version/code=(\\d+)").search(preset)
	truthy(name_match != null and code_match != null, "the Android preset publishes a version name and code")
	if name_match != null and code_match != null:
		eq(ApkInstall.export_stamp()["version_name"], name_match.get_string(1), "baked stamp name matches export_presets.cfg")
		eq(int(ApkInstall.export_stamp()["version_code"]), int(code_match.get_string(1)), "baked stamp code matches export_presets.cfg")
	for path in ["res://backend/apk_update.gd", "res://backend/apk_install.gd", "res://backend/apk_update_client.gd", "res://backend/apk_version_stamp.gd", "res://scenes/mobile_hub.gd"]:
		var src := FileAccess.get_file_as_string(path)
		eq(src.contains("github_pat_"), false, "%s has no github_pat token" % path)
		eq(src.contains("ghp_"), false, "%s has no ghp token" % path)


func _fixture_json() -> String:
	var releases: Array = [
		{
			"tag_name": "mobile-0.1.9-debug",
			"draft": false,
			"prerelease": true,
			"body": "Version: `0.1.9-mobile` (code 10)",
			"assets": [{"name": "stasiumxii-mobile-debug.apk", "browser_download_url": "https://evil.example/apk"}],
		},
		{
			"tag_name": "mobile-0.1.19-debug",
			"draft": false,
			"prerelease": true,
			"body": "- Version: `0.1.19-mobile` (code 20)\n",
			"assets": [{"name": "stasiumxii-mobile-debug.apk", "browser_download_url": "https://evil.example/stolen.apk"}],
		},
		{
			"tag_name": "mobile-0.2.0-debug",
			"draft": true,
			"body": "Version: `0.2.0-mobile` (code 99)",
			"assets": [{"name": "stasiumxii-mobile-debug.apk", "browser_download_url": "https://github.com/maurogp12/stasiumxii/releases/download/mobile-0.2.0-debug/stasiumxii-mobile-debug.apk"}],
		},
		{
			"tag_name": "mobile-0.3.0-debug",
			"draft": false,
			"body": "Version: `0.3.0-mobile` (code 100)",
			"assets": [{"name": "notes.txt"}],
		},
		{
			"tag_name": "v1.0.0",
			"draft": false,
			"body": "",
			"assets": [],
		},
	]
	return JSON.stringify(releases)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s  (got %s)" % [msg, value])
	else:
		_passed += 1
