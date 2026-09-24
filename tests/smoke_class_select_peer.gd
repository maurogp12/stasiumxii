extends SceneTree

## Two-process SELECT_CLASS smoke against the dedicated queue contract.
##
##   godot --headless --path . -s res://tests/smoke_class_select_peer.gd -- --serve 17777
##   godot --headless --path . -s res://tests/smoke_class_select_peer.gd -- --play 127.0.0.1:17777 --class ironjaw
##   godot --headless --path . -s res://tests/smoke_class_select_peer.gd -- --play 127.0.0.1:17777 --class kestrel
##
## --class mender prints REJECT invalid_class and does not connect.
## A paired client prints "SEAT <n> CLASS <class_id>" and exits 0 when the kit matches.

var _status: String = ""


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
	if not net.connection_changed.is_connected(_on_connection):
		net.connection_changed.connect(_on_connection)
	var picked: Dictionary = net.select_class(class_id)
	if not bool(picked.get("ok", false)):
		print("REJECT %s" % str(picked.get("reason", "invalid_class")))
		quit(1)
		return
	var host := "127.0.0.1"
	var port := 17777
	if play.contains(":"):
		var bits := play.split(":")
		host = bits[0]
		port = int(bits[1])
	var joined: Dictionary = net.start_queue_client(host, port)
	if not bool(joined.get("ok", false)):
		print("JOIN FAIL %s" % str(joined.get("reason", "")))
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 8000
	while not net.matched and _status != "class_rejected" and _status != "queue_rejected" and Time.get_ticks_msec() < deadline:
		await process_frame
	if _status == "class_rejected" or _status == "queue_rejected":
		print("REJECT %s" % _status)
		quit(1)
		return
	if not net.matched:
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


func _on_connection(status: String) -> void:
	_status = status


func _flag_value(args: PackedStringArray, flag: String) -> String:
	var i := 0
	while i < args.size():
		if str(args[i]) == flag and i + 1 < args.size():
			return str(args[i + 1])
		i += 1
	return ""
