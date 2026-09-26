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
const Stamp := preload("res://backend/apk_version_stamp.gd")


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


static func export_stamp() -> Dictionary:
	return {
		"version_code": int(Stamp.VERSION_CODE),
		"version_name": str(Stamp.VERSION_NAME),
	}


## Stamp baked into this export. Used only after PackageManager fails.
## `reason` is "stamp" when the numbers come from apk_version_stamp.gd.
static func version_from_stamp(package_id: String = "") -> Dictionary:
	var version_name := str(Stamp.VERSION_NAME).strip_edges()
	var version_code := int(Stamp.VERSION_CODE)
	if version_code <= 0 or version_name.is_empty():
		return {
			"ok": false,
			"version_code": 0,
			"version_name": "",
			"package": package_id,
			"reason": "java",
		}
	return {
		"ok": true,
		"version_code": version_code,
		"version_name": version_name,
		"package": package_id,
		"reason": "stamp",
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
		return _stamp_or(empty)
	var activity = runtime.getActivity()
	if activity == null:
		empty["reason"] = "no_activity"
		return _stamp_or(empty)
	var read := _read_from_package_manager(wrapper, activity)
	if read.get("ok", false):
		return read
	return _stamp_or(read)


## Godot 4.7 JavaObject does not expose Java instance fields, so
## PackageInfo.versionName and versionCode are invisible as properties.
## getPackageInfo(String, int) also fails to bind beside the API 33
## PackageInfoFlags overload, which is why a raw flags int comes back null.
static func _read_from_package_manager(wrapper, activity) -> Dictionary:
	var failed := {
		"ok": false,
		"version_code": 0,
		"version_name": "",
		"package": "",
		"reason": "java",
	}
	var package_id := str(activity.getPackageName())
	if package_id.is_empty() or wrapper.get_exception() != null:
		failed["package"] = package_id
		return failed
	var pm = activity.getPackageManager()
	if pm == null or wrapper.get_exception() != null:
		failed["package"] = package_id
		return failed
	var info = _package_info(wrapper, pm, package_id)
	if info == null:
		failed["package"] = package_id
		return failed
	var version_name := _version_name_of(wrapper, info)
	var version_code := _version_code_of(wrapper, info)
	if version_code <= 0 and version_name.is_empty():
		failed["package"] = package_id
		return failed
	return {
		"ok": true,
		"version_code": version_code,
		"version_name": version_name,
		"package": package_id,
		"reason": "",
	}


static func _stamp_or(failed: Dictionary) -> Dictionary:
	var stamped := version_from_stamp(str(failed.get("package", "")))
	if stamped.get("ok", false):
		return stamped
	return failed


static func _package_info(wrapper, pm, package_id: String):
	var sdk := _sdk_int(wrapper)
	# API 33+ keeps getPackageInfo(String, PackageInfoFlags). The deprecated
	# int overload is a different Godot type, and calling it with `0` does
	# not select that method once the flags overload is the one that bound.
	if sdk == 0 or sdk >= 33:
		var flags_class = wrapper.wrap("android.content.pm.PackageManager$PackageInfoFlags")
		if flags_class != null and flags_class.has_java_method("of"):
			var flags = flags_class.of(0)
			if flags != null and wrapper.get_exception() == null:
				var info = pm.getPackageInfo(package_id, flags)
				if info != null and wrapper.get_exception() == null:
					return info
	var legacy = pm.getPackageInfo(package_id, 0)
	if legacy != null and wrapper.get_exception() == null:
		return legacy
	return null


static func _version_name_of(wrapper, info) -> String:
	var direct = info.get("versionName")
	if typeof(direct) == TYPE_STRING and not str(direct).is_empty():
		return str(direct)
	return _reflect_string(wrapper, info, "versionName")


static func _version_code_of(wrapper, info) -> int:
	# Do not gate this on SDK_INT. A failed Build.VERSION read used to skip
	# the only PackageInfo method Godot can call, then fall through to the
	# versionCode field, which JavaObject cannot see.
	if info.has_java_method("getLongVersionCode"):
		var long_code := int(info.getLongVersionCode())
		if long_code > 0 and wrapper.get_exception() == null:
			return long_code
	var reflected := _reflect_int(wrapper, info, "versionCode")
	if reflected > 0:
		return reflected
	return 0


static func _reflect_string(wrapper, obj, field_name: String) -> String:
	var value = _reflect_field(wrapper, obj, field_name)
	if value == null or wrapper.get_exception() != null:
		return ""
	if typeof(value) == TYPE_STRING:
		return str(value)
	var text = value.toString()
	if text == null or wrapper.get_exception() != null:
		return ""
	return str(text)


static func _reflect_int(wrapper, obj, field_name: String) -> int:
	var value = _reflect_field(wrapper, obj, field_name)
	if value == null or wrapper.get_exception() != null:
		return 0
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	if value.has_java_method("intValue"):
		var as_int := int(value.intValue())
		if wrapper.get_exception() == null and as_int > 0:
			return as_int
	if value.has_java_method("longValue"):
		var as_long := int(value.longValue())
		if wrapper.get_exception() == null and as_long > 0:
			return as_long
	return 0


static func _reflect_field(wrapper, obj, field_name: String):
	if obj == null:
		return null
	var klass = obj.getClass()
	if klass == null or wrapper.get_exception() != null:
		return null
	var field = klass.getField(field_name)
	if field == null or wrapper.get_exception() != null:
		return null
	return field.get(obj)


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


static func _sdk_int(wrapper) -> int:
	var version = wrapper.wrap("android.os.Build$VERSION")
	if version == null:
		return 0
	# SDK_INT is a public static final on Build.VERSION, not a method call.
	# A leftover JavaClassWrapper exception must not discard it.
	return int(version.get("SDK_INT"))


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
