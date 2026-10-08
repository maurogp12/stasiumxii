extends SceneTree

## Headless queue client that deploys, fights, and writes a one-line report.
## godot --headless --path . -s res://tests/dedicated_queue_bot.gd -- --queue 127.0.0.1:17781 --class kestrel --report /tmp/bot.txt

const _HeroAi := preload("res://backend/hero_ai.gd")

var _status := ""
var _dropped := false
var _winner := -1
var _match_over := false
var _on_hub := false
var _second_match := false


func _initialize() -> void:
	_play()


func _play() -> void:
	await process_frame
	var net: Node = root.get_node("NetSession")
	if not net.connection_changed.is_connected(_on_connection):
		net.connection_changed.connect(_on_connection)
	var seat_deadline := Time.get_ticks_msec() + 20000
	while int(net.local_seat) < 0 and not _dropped and Time.get_ticks_msec() < seat_deadline:
		await process_frame
	if int(net.local_seat) < 0:
		print("BOT FAIL no_seat status=%s" % _status)
		_finish(1)
		return
	print("BOT SEATED %d class=%s" % [int(net.local_seat), str(net.selected_class_id)])
	var live_deadline := Time.get_ticks_msec() + 20000
	while not bool(net.match_assigned()) and not _dropped and Time.get_ticks_msec() < live_deadline:
		await process_frame
	if not bool(net.match_assigned()):
		print("BOT FAIL no_match status=%s" % _status)
		_finish(1)
		return
	print("BOT MATCH_LIVE")
	var end_at := Time.get_ticks_msec() + 180000
	var actions := 0
	while not _dropped and Time.get_ticks_msec() < end_at:
		var snap: Dictionary = net.snapshot()
		if not _snap_has_class(snap, int(net.local_seat)):
			await process_frame
			continue
		if bool(snap.get("match_over", false)):
			_match_over = true
			_winner = int(snap.get("winner_seat", -1))
			print("BOT MATCH_OVER winner=%d status=%s" % [_winner, _status])
			if _rematch_requested():
				await _requeue(net)
				return
			var watch := Time.get_ticks_msec() + 2000
			while not _dropped and Time.get_ticks_msec() < watch:
				await process_frame
			print("BOT AFTER_END dropped=%s status=%s" % [str(_dropped), _status])
			_finish(3 if _dropped else 0)
			return
		if snap.is_empty():
			await process_frame
			continue
		var seat := int(net.local_seat)
		if str(snap.get("phase", "")) == "DEPLOYMENT":
			await _deploy(net, seat)
			continue
		if int(snap.get("active_seat", -1)) != seat:
			await process_frame
			continue
		var replica: Node = net.sim()
		if replica == null:
			await process_frame
			continue
		var intent: Dictionary = _HeroAi.plan(replica, seat)
		if intent.is_empty():
			intent = {"type": "end_turn", "seat": seat}
		var before := str(snap.get("last_events", []))
		net.submit(intent)
		actions += 1
		if actions <= 4 or actions % 8 == 0:
			print("BOT ACT %s" % str(intent.get("type", "")))
		await _wait_action(net, seat, before)
	print("BOT FAIL dropped=%s status=%s actions=%d" % [str(_dropped), _status, actions])
	_finish(3 if _dropped else 2)


func _wait_action(net: Node, seat: int, before: String) -> void:
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not _dropped:
		await process_frame
		var now: Dictionary = net.snapshot()
		if bool(now.get("match_over", false)):
			return
		if int(now.get("active_seat", -1)) != seat:
			return
		var events: Array = now.get("last_events", [])
		if str(events) != before and not events.is_empty():
			return


func _snap_has_class(snap: Dictionary, seat: int) -> bool:
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -1)) == seat and str(unit.get("class_id", "")) != "":
			return true
	return false


func _seat_placed(snap: Dictionary, seat: int) -> bool:
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("seat", -1)) == seat:
			return bool(unit.get("placed", false))
	return false


func _deploy(net: Node, seat: int) -> void:
	var snap: Dictionary = net.snapshot()
	var ready: Dictionary = snap.get("ready", {})
	if bool(ready.get(seat, false)):
		await process_frame
		return
	if not _seat_placed(snap, seat):
		var cells: Array = net.legal_deploy_cells(seat)
		if cells.is_empty():
			await process_frame
			return
		var placed: Dictionary = await net.place_unit_wait(seat, cells[0])
		print("BOT PLACE ok=%s reason=%s" % [str(placed.get("ok", "")), str(placed.get("reason", ""))])
		if not bool(placed.get("ok", false)):
			await process_frame
		return
	var readied: Dictionary = await net.ready_seat_wait(seat)
	print("BOT READY ok=%s reason=%s" % [str(readied.get("ok", "")), str(readied.get("reason", ""))])
	if not bool(readied.get("ok", false)):
		await process_frame


## Same process: wait until the autoload has opened the hub, then queue again.
func _requeue(net: Node) -> void:
	var hub_deadline := Time.get_ticks_msec() + 12000
	while not _dropped and Time.get_ticks_msec() < hub_deadline:
		await process_frame
		var scene := current_scene
		if scene != null and str(scene.scene_file_path).ends_with("mobile_hub.tscn"):
			_on_hub = true
			break
	print("BOT HUB %s dropped=%s" % [str(_on_hub), str(_dropped)])
	if not _on_hub or _dropped:
		_finish(4 if _dropped else 5)
		return
	var opened: Dictionary = net.begin_auto_queue("127.0.0.1", _queue_port())
	print("BOT REQUEUE ok=%s reason=%s" % [str(opened.get("ok", "")), str(opened.get("reason", ""))])
	if not bool(opened.get("ok", false)):
		_finish(6)
		return
	var until := Time.get_ticks_msec() + 25000
	while not _dropped and Time.get_ticks_msec() < until:
		await process_frame
		if bool(net.match_assigned()):
			_second_match = true
			break
	print("BOT SECOND %s dropped=%s status=%s" % [str(_second_match), str(_dropped), _status])
	_finish(0 if _second_match and not _dropped else 7)


func _rematch_requested() -> bool:
	return OS.get_cmdline_user_args().has("--rematch")


func _queue_port() -> int:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--queue")
	if i >= 0 and i + 1 < args.size() and str(args[i + 1]).contains(":"):
		return int(str(args[i + 1]).split(":")[1])
	return 7777


func _on_connection(status: String) -> void:
	_status = status
	print("BOT STATUS %s" % status)
	if status == "host_left":
		_dropped = true
		print("BOT SERVER_DISCONNECTED")


func _finish(code: int) -> void:
	var path := _report_path()
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string("match_over=%d\ndropped=%d\nwinner=%d\nstatus=%s\ncode=%d\nhub=%d\nsecond_match=%d\n" % [
				1 if _match_over else 0,
				1 if _dropped else 0,
				_winner,
				_status,
				code,
				1 if _on_hub else 0,
				1 if _second_match else 0,
			])
	var dial := load("res://backend/server_dial.gd")
	if dial != null and dial.has_method("forget"):
		dial.forget()
	quit(code)


func _report_path() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--report")
	if i >= 0 and i + 1 < args.size():
		return str(args[i + 1])
	return ""
