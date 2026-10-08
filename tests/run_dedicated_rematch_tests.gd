extends SceneTree

## Two full matches on one dedicated process. The second pair must get a seat
## after the first match ends. The process must still be the same pid.
## Run: godot --headless --path . -s res://tests/run_dedicated_rematch_tests.gd

const PORT := 17781

var _failed := 0
var _passed := 0
var _server_pid := 0
var _log := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_log = "/tmp/stasium-rematch-%d.log" % PORT
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
	var first := await _play_pair("kestrel", "ironjaw", "rematch-a")
	if not first:
		_done()
		return
	if not OS.is_process_running(_server_pid):
		_fail("dedicated process died after the first match")
		_done()
		return
	_ok("the same process is still running after match end")
	var second := await _play_pair("ironjaw", "gloam", "rematch-b")
	if not second:
		_done()
		return
	if not OS.is_process_running(_server_pid):
		_fail("dedicated process died after the second match")
		_done()
		return
	_ok("a second match finished on the same process")
	var log_text := FileAccess.get_file_as_string(_log)
	var starts := log_text.count("STASIUM server: match start")
	var ends := log_text.count("STASIUM server: match end")
	if starts < 2 or ends < 2:
		_fail("server log has %d match starts and %d match ends" % [starts, ends])
	else:
		_ok("server log records both matches")
	if log_text.contains("reason=seats_full"):
		_fail("the second pair was refused because a seat stayed reserved")
	else:
		_ok("nobody was refused for a full seat table")
	_done()


func _play_pair(class_a: String, class_b: String, tag: String) -> bool:
	var project := ProjectSettings.globalize_path("res://")
	var godot := OS.get_executable_path()
	var report_a := "/tmp/%s-0.txt" % tag
	var report_b := "/tmp/%s-1.txt" % tag
	DirAccess.remove_absolute(report_a)
	DirAccess.remove_absolute(report_b)
	var pid_a := _spawn_bot(godot, project, class_a, report_a)
	var pid_b := _spawn_bot(godot, project, class_b, report_b)
	var result_a: Dictionary = await _wait_report(report_a, 200000)
	var result_b: Dictionary = await _wait_report(report_b, 20000)
	_stop(pid_a)
	_stop(pid_b)
	if bool(result_a.get("missing", false)) or bool(result_b.get("missing", false)):
		_fail("%s vs %s did not finish" % [class_a, class_b])
		return false
	if int(result_a.get("dropped", 1)) != 0 or int(result_b.get("dropped", 1)) != 0:
		_fail("%s vs %s saw server disconnected (%s / %s)" % [class_a, class_b, result_a.get("status", ""), result_b.get("status", "")])
		return false
	if int(result_a.get("match_over", 0)) != 1 or int(result_b.get("match_over", 0)) != 1:
		_fail("%s vs %s did not reach match_over" % [class_a, class_b])
		return false
	_ok("%s vs %s finished without a disconnect" % [class_a, class_b])
	return true


func _spawn_bot(godot: String, project: String, class_id: String, report: String) -> int:
	return OS.create_process(godot, [
		"--headless", "--path", project,
		"-s", "res://tests/dedicated_queue_bot.gd",
		"--", "--queue", "127.0.0.1:%d" % PORT, "--class", class_id, "--report", report,
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
			# The bot opens the report before it writes it. An empty file is
			# not a disconnect; wait until the match_over line is there.
			var text := FileAccess.get_file_as_string(path)
			if text.contains("match_over="):
				return _parse_report(text)
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
	print("Dedicated rematch: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
