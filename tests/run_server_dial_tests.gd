extends SceneTree

## Play Online dial order: remembered, public, Tailscale, LAN.
## Run: godot --headless --path . -s res://tests/run_server_dial_tests.gd

const Dial := preload("res://backend/server_dial.gd")
const _SAVE := "user://test_server_dial.cfg"

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Server-dial tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_order()
	_test_remember()
	_test_sources()
	_test_begin_without_class()


func _test_order() -> void:
	eq(Dial.fallback_hosts(), [Dial.PUBLIC_ADDRESS, Dial.TAILSCALE_ADDRESS, Dial.LAN_ADDRESS], "fallback is public, tailscale, lan")
	eq(Dial.address_order(""), [Dial.PUBLIC_ADDRESS, Dial.TAILSCALE_ADDRESS, Dial.LAN_ADDRESS], "empty memory starts at the public host")
	eq(Dial.address_order(Dial.LAN_ADDRESS), [Dial.LAN_ADDRESS, Dial.PUBLIC_ADDRESS, Dial.TAILSCALE_ADDRESS], "remembered LAN is tried first")
	eq(Dial.address_order(Dial.PUBLIC_ADDRESS), [Dial.PUBLIC_ADDRESS, Dial.TAILSCALE_ADDRESS, Dial.LAN_ADDRESS], "remembered public is not duplicated")
	eq(Dial.address_order("  " + Dial.TAILSCALE_ADDRESS + "  "), [Dial.TAILSCALE_ADDRESS, Dial.PUBLIC_ADDRESS, Dial.LAN_ADDRESS], "remembered tailscale is stripped and not duplicated")
	eq(Dial.address_order("10.0.0.8"), ["10.0.0.8", Dial.PUBLIC_ADDRESS, Dial.TAILSCALE_ADDRESS, Dial.LAN_ADDRESS], "a custom remembered host leads the chain")
	eq(Dial.chain_seconds("10.0.0.8"), 10.0, "four probes at 2.5s is 10s")
	truthy(Dial.chain_seconds("10.0.0.8") <= 12.0, "the full chain stays under 12s")
	truthy(Dial.chain_seconds("") <= 12.0, "the default chain stays under 12s")
	truthy(Dial.PROBE_SEC >= 2.0 and Dial.PROBE_SEC <= 3.0, "each probe is about 2-3s")
	eq(Dial.PORT, 7777, "dial port is 7777")


func _test_remember() -> void:
	Dial.forget(_SAVE)
	eq(Dial.remembered(_SAVE), "", "a missing save remembers nothing")
	Dial.remember("  10.1.2.3  ", _SAVE)
	eq(Dial.remembered(_SAVE), "10.1.2.3", "remember stores the stripped address")
	Dial.remember(Dial.TAILSCALE_ADDRESS, _SAVE)
	eq(Dial.remembered(_SAVE), Dial.TAILSCALE_ADDRESS, "a later success replaces the saved address")
	Dial.forget(_SAVE)
	eq(Dial.remembered(_SAVE), "", "forget clears the saved address")
	eq(FileAccess.file_exists(_SAVE), false, "the test save file is removed")


func _test_sources() -> void:
	var chrome := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	var lobby := FileAccess.get_file_as_string("res://scenes/online_lobby.gd")
	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	eq(chrome.contains("text = \"Host\""), false, "class select has no Host label")
	truthy(chrome.contains("Connecting…"), "class select status says Connecting…")
	eq(chrome.contains("Connecting to"), false, "class select does not name the address while connecting")
	eq(chrome.contains("192.168.1.58"), false, "class select does not hardcode the LAN address")
	eq(chrome.contains("100.94.184.28"), false, "class select does not hardcode the Tailscale address")
	truthy(chrome.contains("begin_auto_queue"), "class select starts the dial chain")
	truthy(chrome.contains("Play Online"), "class select offers Play Online")
	truthy(chrome.contains("Could not reach server"), "class select can say the server was unreachable")
	truthy(chrome.contains("Searching for opponent…"), "class select says it is searching once connected")
	eq(lobby.contains("text = \"Host\""), false, "lobby has no Host label")
	eq(lobby.contains("Join IP"), false, "lobby does not show a Join IP field")
	eq(lobby.contains("Join queue"), false, "lobby does not ask the player to type a queue join")
	eq(lobby.contains("Connecting to"), false, "lobby does not name the address while connecting")
	eq(lobby.contains("192.168.1.58"), false, "lobby does not hardcode the LAN address")
	eq(lobby.contains("100.94.184.28"), false, "lobby does not hardcode the Tailscale address")
	truthy(lobby.contains("begin_auto_queue"), "lobby starts the dial chain")
	truthy(lobby.contains("Play Online"), "lobby offers Play Online")
	truthy(lobby.contains("Host dedicated"), "lobby can still host the dedicated queue")
	truthy(net_src.contains("func begin_auto_queue"), "net session exposes begin_auto_queue")
	truthy(net_src.contains("start_queue_client"), "the dial still opens with start_queue_client")
	eq(net_src.contains("rpc_auto_join"), false, "auto-join does not add an RPC")
	eq(net_src.contains("rpc_enqueue"), true, "enqueue stays rpc_enqueue")


func _test_begin_without_class() -> void:
	var net: Node = root.get_node("NetSession")
	var prior := str(net.selected_class_id)
	net.selected_class_id = ""
	var blocked: Dictionary = net.begin_auto_queue()
	eq(bool(blocked.get("ok", true)), false, "dial before a class does not connect")
	eq(str(blocked.get("reason", "")), "class_required", "dial before a class is class_required")
	eq(net.is_auto_dialing(), false, "a rejected dial is not in progress")
	eq(net.is_client(), false, "a rejected dial does not open a client")
	net.selected_class_id = prior


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
