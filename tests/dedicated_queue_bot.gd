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
var _team_size := 1
var _match_clock := -1
var _unit_count := 0
var _placed_extra := false
var _acted_extra := false
var _class_note := ""
var _owned_note := ""
var _roster_note := ""


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
		if not _snap_ready(snap, net):
			await process_frame
			continue
		_note_snap(snap, net)
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
		var owned := _owned(net)
		var seat := int(owned[0]) if not owned.is_empty() else int(net.local_seat)
		if str(snap.get("phase", "")) == "DEPLOYMENT":
			await _deploy(net, seat)
			continue
		var active := int(snap.get("active_seat", -1))
		if not owned.has(active):
			await process_frame
			continue
		var replica: Node = net.sim()
		if replica == null:
			await process_frame
			continue
		var intent: Dictionary = _HeroAi.plan(replica, active)
		if intent.is_empty():
			intent = {"type": "end_turn", "seat": active}
		var before := str(snap.get("last_events", []))
		net.submit(intent)
		actions += 1
		if active != seat:
			_acted_extra = true
			print("BOT ACT_EXTRA seat=%d type=%s" % [active, str(intent.get("type", ""))])
		elif actions <= 4 or actions % 8 == 0:
			print("BOT ACT %s" % str(intent.get("type", "")))
		await _wait_action(net, active, before)
		if _proof_requested() and _placed_extra and _acted_extra and _match_clock >= 0:
			print("BOT PROOF team=%d clock=%d classes=%s" % [_team_size, _match_clock, _class_note])
			_finish(0)
			return
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


func _owned(net: Node) -> Array:
	var owned: Array = net.owned_seats()
	if owned.is_empty() and int(net.local_seat) >= 0:
		owned = [int(net.local_seat)]
	return owned


func _snap_ready(snap: Dictionary, net: Node) -> bool:
	var owned := _owned(net)
	if owned.is_empty():
		return false
	for seat in owned:
		if not _snap_has_class(snap, int(seat)):
			return false
	if int(snap.get("team_size", 1)) > 1 and (snap.get("units", []) as Array).size() < int(snap.get("team_size", 1)) * 2:
		return false
	return true


func _note_snap(snap: Dictionary, net: Node) -> void:
	_team_size = int(snap.get("team_size", 1))
	_unit_count = (snap.get("units", []) as Array).size()
	var owned := _owned(net)
	var owned_bits: Array[String] = []
	for seat in owned:
		owned_bits.append(str(int(seat)))
	_owned_note = ",".join(owned_bits)
	var class_bits: Array[String] = []
	var roster_bits: Array[String] = []
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var seat := int(unit.get("seat", -1))
		if not owned.has(seat):
			continue
		class_bits.append(str(unit.get("class_id", "")))
		roster_bits.append("%d:%s:still=%s:ap=%s:mp=%s:gear=%d" % [
			seat,
			str(unit.get("class_id", "")),
			str(unit.get("still", "")),
			str(unit.get("max_ap", "")),
			str(unit.get("max_mp", "")),
			(unit.get("gear", []) as Array).size() if unit.get("gear", []) is Array else 0,
		])
	_class_note = ",".join(class_bits)
	_roster_note = "|".join(roster_bits)
	if _match_clock < 0 and str(snap.get("phase", "")) != "DEPLOYMENT" and str(snap.get("phase", "")) != "":
		var left := float(snap.get("match_time_left", -1.0))
		if left >= 0.0:
			_match_clock = int(floor(left))


func _proof_requested() -> bool:
	return OS.get_cmdline_user_args().has("--proof")


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
	var owned := _owned(net)
	var side := seat
	if int(snap.get("team_size", 1)) > 1 and not owned.is_empty():
		side = int(owned[0]) % 2
	var ready: Dictionary = snap.get("ready", {})
	if bool(ready.get(side, false)):
		await process_frame
		return
	for fighter in owned:
		if _seat_placed(snap, int(fighter)):
			continue
		var cells: Array = net.legal_deploy_cells(int(fighter))
		if cells.is_empty():
			await process_frame
			return
		var placed: Dictionary = await net.place_unit_wait(int(fighter), cells[0])
		print("BOT PLACE seat=%d ok=%s reason=%s" % [int(fighter), str(placed.get("ok", "")), str(placed.get("reason", ""))])
		if int(fighter) != seat and bool(placed.get("ok", false)):
			_placed_extra = true
		if not bool(placed.get("ok", false)):
			await process_frame
		return
	var readied: Dictionary = await net.ready_seat_wait(side)
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
			file.store_string("match_over=%d\ndropped=%d\nwinner=%d\nstatus=%s\ncode=%d\nhub=%d\nsecond_match=%d\nteam_size=%d\nclasses=%s\nowned=%s\nunits=%d\nmatch_clock=%d\nacted_extra=%d\nplaced_extra=%d\nroster=%s\n" % [
				1 if _match_over else 0,
				1 if _dropped else 0,
				_winner,
				_status,
				code,
				1 if _on_hub else 0,
				1 if _second_match else 0,
				_team_size,
				_class_note,
				_owned_note,
				_unit_count,
				_match_clock,
				1 if _acted_extra else 0,
				1 if _placed_extra else 0,
				_roster_note,
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
