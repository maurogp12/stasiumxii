extends SceneTree

## One dedicated process, two clients, one app session each.
## They fight to match_over, land on the hub, queue again, and a second match starts.
## Run: godot --headless --path . -s res://tests/run_online_rematch_tests.gd

const PORT := 17791

var _failed := 0
var _passed := 0
var _server_pid := 0
var _log := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_log = "/tmp/stasium-online-rematch-%d.log" % PORT
	var project := ProjectSettings.globalize_path("res://")
	var godot := OS.get_executable_path()
	DirAccess.remove_absolute(_log)
	var launch := "exec \"%s\" --headless --path \"%s\" -- --dedicated %d > \"%s\" 2>&1" % [godot, project, PORT, _log]
	_server_pid = OS.create_process("/bin/bash", ["-lc", launch])
	if _server_pid <= 0:
		_fail("dedicated process did not start")
		_done()
		return
	if not await _wait_log("STASIUM server: listening port=%d" % PORT, 20000):
		_fail("dedicated server did not log that it is listening")
		_done()
		return
	_ok("dedicated server is listening")
	var project_path := project
	var report_a := "/tmp/online-rematch-0.txt"
	var report_b := "/tmp/online-rematch-1.txt"
	DirAccess.remove_absolute(report_a)
	DirAccess.remove_absolute(report_b)
	var pid_a := _spawn(godot, project_path, "kestrel", report_a)
	var pid_b := _spawn(godot, project_path, "gloam", report_b)
	var result_a: Dictionary = await _wait_report(report_a, 220000)
	var result_b: Dictionary = await _wait_report(report_b, 30000)
	_stop(pid_a)
	_stop(pid_b)
	if bool(result_a.get("missing", false)) or bool(result_b.get("missing", false)):
		_fail("the pair did not finish (see %s)" % _log)
		_done()
		return
	if int(result_a.get("dropped", 1)) != 0 or int(result_b.get("dropped", 1)) != 0:
		_fail("server disconnected (%s / %s)" % [result_a.get("status", ""), result_b.get("status", "")])
	else:
		_ok("neither client saw server disconnected")
	if int(result_a.get("match_over", 0)) != 1 or int(result_b.get("match_over", 0)) != 1:
		_fail("the first fight did not reach match_over")
	else:
		_ok("the first fight reached match_over")
	if int(result_a.get("hub", 0)) != 1 or int(result_b.get("hub", 0)) != 1:
		_fail("a client did not land on the hub")
	else:
		_ok("both clients landed on the hub")
	if int(result_a.get("second_match", 0)) != 1 or int(result_b.get("second_match", 0)) != 1:
		_fail("the same process did not start a second match")
	else:
		_ok("both clients queued again and a second match started")
	var log_text := FileAccess.get_file_as_string(_log)
	var starts := log_text.count("STASIUM server: match start")
	var ends := log_text.count("STASIUM server: match end")
	if starts < 2 or ends < 1:
		_fail("server log has %d match starts and %d match ends" % [starts, ends])
	else:
		_ok("server log records the second match")
	if log_text.contains("reason=seats_full"):
		_fail("a seat stayed reserved")
	else:
		_ok("nobody was refused for a full seat table")
	_done()


func _spawn(godot: String, project: String, class_id: String, report: String) -> int:
	return OS.create_process(godot, [
		"--headless", "--path", project,
		"-s", "res://tests/dedicated_queue_bot.gd",
		"--", "--queue", "127.0.0.1:%d" % PORT, "--class", class_id, "--report", report, "--rematch",
	])


func _wait_log(needle: String, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(_log) and FileAccess.get_file_as_string(_log).contains(needle):
			return true
		await process_frame
	return false


func _wait_report(path: String, timeout_ms: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(path):
			return _parse_report(FileAccess.get_file_as_string(path))
		await process_frame
	return {"missing": true}


func _parse_report(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		if not line.contains("="):
			continue
		var parts := line.split("=", true, 1)
		out[parts[0]] = parts[1]
	return out


func _stop(pid: int) -> void:
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)


func _ok(message: String) -> void:
	_passed += 1
	print("PASS %s" % message)


func _fail(message: String) -> void:
	_failed += 1
	print("FAIL %s" % message)


func _done() -> void:
	_stop(_server_pid)
	var dial := load("res://backend/server_dial.gd")
	if dial != null and dial.has_method("forget"):
		dial.forget()
	print("Online rematch: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
