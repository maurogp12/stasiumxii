extends SceneTree

## Two-process SELECT_CLASS smoke. Not part of the single-process suite.
##
##   godot --headless --path . -s res://tests/smoke_class_select_peer.gd -- --serve 17777
##   godot --headless --path . -s res://tests/smoke_class_select_peer.gd -- --play 127.0.0.1:17777 --class ironjaw
##   godot --headless --path . -s res://tests/smoke_class_select_peer.gd -- --play 127.0.0.1:17777 --class kestrel
##
## Each client prints "SEAT <n> CLASS <class_id>" and exits 0 when the kit matches.

var _reject_reason: String = ""


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var serve := _flag_value(args, "--serve")
	var play := _flag_value(args, "--play")
	var net := root.get_node("NetSession")
	if serve != "":
		var opened: Dictionary = net.start_dedicated(int(serve))
		if not bool(opened.get("ok", false)):
			print("SERVE FAIL %s" % str(opened.get("reason", "")))
			quit(1)
			return
		print("SERVING %s" % serve)
		return
	if play == "":
		print("usage: --serve <port> | --play <ip:port> --class <class_id>")
		quit(1)
		return
	var class_id := _flag_value(args, "--class")
	var host := "127.0.0.1"
	var port := 17777
	if play.contains(":"):
		var bits := play.split(":")
		host = bits[0]
		port = int(bits[1])
	var joined: Dictionary = net.start_client(host, port)
	if not bool(joined.get("ok", false)):
		print("JOIN FAIL")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 8000
	while int(net.local_seat) < 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if int(net.local_seat) < 0:
		print("NO SEAT")
		quit(1)
		return
	_reject_reason = ""
	if not net.class_rejected.is_connected(_on_class_rejected):
		net.class_rejected.connect(_on_class_rejected)
	net.select_class(class_id)
	deadline = Time.get_ticks_msec() + 4000
	while str(net.confirmed_class_id) == "" and _reject_reason == "" and Time.get_ticks_msec() < deadline:
		await process_frame
	if _reject_reason != "":
		print("REJECT %s" % _reject_reason)
		quit(1)
		return
	if str(net.confirmed_class_id) != class_id.strip_edges().to_lower():
		print("REJECT %s" % str(net.confirmed_class_id))
		quit(1)
		return
	net.enter_matchmaking()
	deadline = Time.get_ticks_msec() + 8000
	while not bool(net.match_assigned()) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not bool(net.match_assigned()):
		print("NO MATCH")
		quit(1)
		return
	var want := class_id.strip_edges().to_lower()
	var got := ""
	for unit in net.snapshot().get("units", []):
		if int(unit.get("seat", -1)) == int(net.local_seat):
			got = str(unit.get("class_id", ""))
	print("SEAT %d CLASS %s" % [int(net.local_seat), got])
	quit(0 if got == want else 1)


func _on_class_rejected(reason: String, _class_id: String) -> void:
	_reject_reason = reason


func _flag_value(args: PackedStringArray, flag: String) -> String:
	var i := 0
	while i < args.size():
		if str(args[i]) == flag and i + 1 < args.size():
			return str(args[i + 1])
		i += 1
	return ""
