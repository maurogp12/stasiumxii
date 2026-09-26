class_name ApkInstall
extends RefCounted

## Thin Android handoff for an in-place APK update.
## Headless and desktop builds never touch Java. The install Intent
## (FileProvider + ACTION_VIEW) lives only in the platform methods.

const FILEPROVIDER_SUFFIX := ".fileprovider"
const APK_MIME := "application/vnd.android.package-archive"
const VIEW_ACTION := "android.intent.action.VIEW"
const UNKNOWN_SOURCES_ACTION := "android.settings.MANAGE_UNKNOWN_APP_SOURCES"
## Android SDK values, used only if the Java constants cannot be read.
const FLAG_GRANT_READ_URI_PERMISSION := 1
const FLAG_ACTIVITY_NEW_TASK := 0x10000000


static func install_intent_spec(package_id: String, absolute_path: String) -> Dictionary:
	return {
		"action": VIEW_ACTION,
		"mime": APK_MIME,
		"authority": "%s%s" % [package_id, FILEPROVIDER_SUFFIX],
		"path": absolute_path,
		"grant_read": true,
		"new_task": true,
	}


static func unknown_sources_intent_spec(package_id: String) -> Dictionary:
	return {
		"action": UNKNOWN_SOURCES_ACTION,
		"data": "package:%s" % package_id,
		"new_task": true,
	}


static func installed_version() -> Dictionary:
	var empty := {
		"ok": false,
		"version_code": 0,
		"version_name": "",
		"package": "",
		"reason": "not_android",
	}
	if not OS.has_feature("android"):
		return empty
	var runtime = Engine.get_singleton("AndroidRuntime")
	var wrapper = Engine.get_singleton("JavaClassWrapper")
	if runtime == null or wrapper == null:
		empty["reason"] = "no_runtime"
		return empty
	var activity = runtime.getActivity()
	if activity == null:
		empty["reason"] = "no_activity"
		return empty
	var package_id := str(activity.getPackageName())
	var info = activity.getPackageManager().getPackageInfo(package_id, 0)
	if wrapper.get_exception() != null or info == null:
		empty["reason"] = "java"
		empty["package"] = package_id
		return empty
	var version_name := str(info.versionName)
	var version_code := _version_code(wrapper, info)
	if version_code <= 0 and version_name.is_empty():
		empty["reason"] = "java"
		empty["package"] = package_id
		return empty
	return {
		"ok": true,
		"version_code": version_code,
		"version_name": version_name,
		"package": package_id,
		"reason": "",
	}


## Android 8+ gates sideload installs with canRequestPackageInstalls.
## Older than Oreo has no per-app switch; the installer prompts itself.
static func can_request_package_installs() -> Dictionary:
	if not OS.has_feature("android"):
		return {"ok": false, "allowed": false, "reason": "not_android"}
	var runtime = Engine.get_singleton("AndroidRuntime")
	var wrapper = Engine.get_singleton("JavaClassWrapper")
	if runtime == null or wrapper == null:
		return {"ok": false, "allowed": false, "reason": "no_runtime"}
	var activity = runtime.getActivity()
	if activity == null:
		return {"ok": false, "allowed": false, "reason": "no_activity"}
	var sdk := _sdk_int(wrapper)
	if sdk > 0 and sdk < 26:
		return {"ok": true, "allowed": true, "reason": "pre_oreo"}
	var allowed := bool(activity.getPackageManager().canRequestPackageInstalls())
	if wrapper.get_exception() != null:
		return {"ok": false, "allowed": false, "reason": "need_permission"}
	if allowed:
		return {"ok": true, "allowed": true, "reason": ""}
	return {"ok": true, "allowed": false, "reason": "need_permission"}


static func open_unknown_sources_settings() -> Dictionary:
	if not OS.has_feature("android"):
		return {"ok": false, "reason": "not_android"}
	var runtime = Engine.get_singleton("AndroidRuntime")
	var wrapper = Engine.get_singleton("JavaClassWrapper")
	if runtime == null or wrapper == null:
		return {"ok": false, "reason": "no_runtime"}
	var activity = runtime.getActivity()
	if activity == null:
		return {"ok": false, "reason": "no_activity"}
	var package_id := str(activity.getPackageName())
	var spec := unknown_sources_intent_spec(package_id)
	var intent_class = wrapper.wrap("android.content.Intent")
	var uri_class = wrapper.wrap("android.net.Uri")
	if intent_class == null or uri_class == null or wrapper.get_exception() != null:
		return {"ok": false, "reason": "java"}
	var intent = intent_class.Intent(spec["action"])
	intent.setData(uri_class.parse(spec["data"]))
	intent.addFlags(_new_task_flag(intent_class, wrapper))
	if wrapper.get_exception() != null:
		return {"ok": false, "reason": "java"}
	return _start_on_ui(runtime, wrapper, activity, intent)


static func handoff_apk(absolute_path: String) -> Dictionary:
	if not OS.has_feature("android"):
		return {"ok": false, "reason": "not_android"}
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		return {"ok": false, "reason": "missing_file"}
	var runtime = Engine.get_singleton("AndroidRuntime")
	var wrapper = Engine.get_singleton("JavaClassWrapper")
	if runtime == null or wrapper == null:
		return {"ok": false, "reason": "no_runtime"}
	var activity = runtime.getActivity()
	if activity == null:
		return {"ok": false, "reason": "no_activity"}
	var package_id := str(activity.getPackageName())
	var spec := install_intent_spec(package_id, absolute_path)
	var file_class = wrapper.wrap("java.io.File")
	var provider = wrapper.wrap("androidx.core.content.FileProvider")
	var intent_class = wrapper.wrap("android.content.Intent")
	if file_class == null or provider == null or intent_class == null or wrapper.get_exception() != null:
		return {"ok": false, "reason": "java"}
	var file = file_class.File(absolute_path)
	if file == null or not bool(file.exists()):
		return {"ok": false, "reason": "missing_file"}
	var uri = provider.getUriForFile(activity, str(spec["authority"]), file)
	if uri == null or wrapper.get_exception() != null:
		return {"ok": false, "reason": "uri"}
	var intent = intent_class.Intent(spec["action"])
	intent.setDataAndType(uri, spec["mime"])
	intent.addFlags(_grant_read_flag(intent_class, wrapper) | _new_task_flag(intent_class, wrapper))
	if wrapper.get_exception() != null:
		return {"ok": false, "reason": "java"}
	return _start_on_ui(runtime, wrapper, activity, intent)


static func _version_code(wrapper, info) -> int:
	var sdk := _sdk_int(wrapper)
	if sdk >= 28:
		var long_code := int(info.getLongVersionCode())
		if long_code > 0 and wrapper.get_exception() == null:
			return long_code
	# versionCode still carries this project's small stamps if the long read fails.
	var legacy := int(info.versionCode)
	if legacy > 0:
		return legacy
	return 0


static func _sdk_int(wrapper) -> int:
	var version = wrapper.wrap("android.os.Build$VERSION")
	if version == null:
		return 0
	var sdk := int(version.SDK_INT)
	if wrapper.get_exception() != null:
		return 0
	return sdk


static func _grant_read_flag(intent_class, wrapper) -> int:
	var flag := int(intent_class.FLAG_GRANT_READ_URI_PERMISSION)
	if wrapper.get_exception() != null or flag == 0:
		return FLAG_GRANT_READ_URI_PERMISSION
	return flag


static func _new_task_flag(intent_class, wrapper) -> int:
	var flag := int(intent_class.FLAG_ACTIVITY_NEW_TASK)
	if wrapper.get_exception() != null or flag == 0:
		return FLAG_ACTIVITY_NEW_TASK
	return flag


static func _start_on_ui(runtime, wrapper, activity, intent) -> Dictionary:
	var launch := func() -> void:
		activity.startActivity(intent)
	var runnable = runtime.createRunnableFromGodotCallable(launch)
	if runnable == null or wrapper.get_exception() != null:
		return {"ok": false, "reason": "intent"}
	activity.runOnUiThread(runnable)
	if wrapper.get_exception() != null:
		return {"ok": false, "reason": "intent"}
	return {"ok": true, "reason": "scheduled"}
