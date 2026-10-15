extends SceneTree

## Two headless queue clients against one dedicated server.
## Each client picks two different classes, deploys a non-primary fighter,
## and acts on a later seat. The match uses the existing team-size-2 clock.
## Run: godot --headless --path . -s res://tests/run_online_2v2_tests.gd

const PORT := 17784

var _failed := 0
var _passed := 0
var _server_pid := 0
var _log := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_log = "/tmp/stasium-2v2-%d.log" % PORT
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
	var report_a := "/tmp/online-2v2-a.txt"
	var report_b := "/tmp/online-2v2-b.txt"
	DirAccess.remove_absolute(report_a)
	DirAccess.remove_absolute(report_b)
	var pid_a := _spawn_bot(godot, project, "kestrel,ironjaw", report_a)
	var pid_b := _spawn_bot(godot, project, "gloam,bastion", report_b)
	var result_a: Dictionary = await _wait_report(report_a, 120000)
	var result_b: Dictionary = await _wait_report(report_b, 20000)
	_stop(pid_a)
	_stop(pid_b)
	if bool(result_a.get("missing", false)) or bool(result_b.get("missing", false)):
		_fail("the two 2v2 clients did not finish")
		_done()
		return
	if int(result_a.get("dropped", 1)) != 0 or int(result_b.get("dropped", 1)) != 0:
		_fail("a client saw the server disconnect")
		_done()
		return
	_ok("both clients stayed connected")
	if int(result_a.get("code", 1)) != 0 or int(result_b.get("code", 1)) != 0:
		_fail("a client exited %s / %s" % [result_a.get("code", ""), result_b.get("code", "")])
	else:
		_ok("both clients finished the proof")
	if int(result_a.get("team_size", 0)) != 2 or int(result_b.get("team_size", 0)) != 2:
		_fail("team size was %s / %s" % [result_a.get("team_size", ""), result_b.get("team_size", "")])
	else:
		_ok("both clients saw team size 2")
	if int(result_a.get("units", 0)) != 4 or int(result_b.get("units", 0)) != 4:
		_fail("unit count was %s / %s" % [result_a.get("units", ""), result_b.get("units", "")])
	else:
		_ok("both clients saw four fighters")
	var clock_a := int(result_a.get("match_clock", -1))
	var clock_b := int(result_b.get("match_clock", -1))
	if clock_a < 580 or clock_a > 600 or clock_b < 580 or clock_b > 600:
		_fail("match clock was %d / %d" % [clock_a, clock_b])
	else:
		_ok("the match clock is the existing 10 minute team-size-2 clock")
	var classes_a := str(result_a.get("classes", ""))
	var classes_b := str(result_b.get("classes", ""))
	var owned_a := str(result_a.get("owned", ""))
	var owned_b := str(result_b.get("owned", ""))
	var roster_ok := (classes_a == "kestrel,ironjaw" and classes_b == "gloam,bastion") or (classes_b == "kestrel,ironjaw" and classes_a == "gloam,bastion")
	if not roster_ok:
		_fail("classes were %s / %s" % [classes_a, classes_b])
	else:
		_ok("each player kept two different classes")
	var seats_ok := (owned_a == "0,2" and owned_b == "1,3") or (owned_a == "1,3" and owned_b == "0,2")
	if not seats_ok:
		_fail("owned seats were %s / %s" % [owned_a, owned_b])
	else:
		_ok("each player controls both of their seats")
	if (classes_a == "kestrel,ironjaw" and owned_a == "1,3" and owned_b != "0,2") or (classes_a == "gloam,bastion" and owned_a == "0,2" and owned_b != "1,3"):
		_fail("a roster landed on the wrong seats")
	else:
		_ok("each roster sits on that player's seats")
	if int(result_a.get("placed_extra", 0)) != 1 or int(result_b.get("placed_extra", 0)) != 1:
		_fail("a player did not deploy a later fighter")
	else:
		_ok("each player deployed a later fighter")
	if int(result_a.get("acted_extra", 0)) != 1 or int(result_b.get("acted_extra", 0)) != 1:
		_fail("a player did not act on a later seat")
	else:
		_ok("each player acted on a later seat")
	if not str(result_a.get("roster", "")).contains("still=") or not str(result_b.get("roster", "")).contains("still="):
		_fail("the roster note did not carry per-fighter gear")
	else:
		_ok("each fighter reports its own Still and gear")
	var log_text := FileAccess.get_file_as_string(_log)
	if not log_text.contains("STASIUM server: match start") or not log_text.contains("team=2"):
		_fail("the server log did not start a team-size 2 match")
	else:
		_ok("the dedicated server started one 2v2 match")
	_done()


func _spawn_bot(godot: String, project: String, classes: String, report: String) -> int:
	return OS.create_process(godot, [
		"--headless", "--path", project,
		"-s", "res://tests/dedicated_queue_bot.gd",
		"--", "--queue", "127.0.0.1:%d" % PORT, "--classes", classes, "--report", report, "--proof",
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
	print("Online 2v2: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
