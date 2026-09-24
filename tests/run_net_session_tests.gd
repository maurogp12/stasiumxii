extends SceneTree

## Listen-host proto: validate, serialize intents, host submit, guest hydrate.
## Run: godot --headless --path . -s res://tests/run_net_session_tests.gd

var _failed: int = 0
var _passed: int = 0
var _sim: Node
var _view: Node
var _host: Node
var _guest: Node


func _initialize() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var net_script := load("res://backend/net_session.gd")
	_sim = sim_script.new()
	_view = sim_script.new()
	_host = net_script.new()
	_guest = net_script.new()
	_host.attach_sim(_sim)
	_guest.attach_sim(_view)
	_host.enter_host_offline()
	_guest.enter_client_offline()
	_run()
	print("Net-session tests: %d passed, %d failed" % [_passed, _failed])
	_host.free()
	_guest.free()
	_sim.free()
	_view.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_source_stamps()
	_test_intent_codec_roundtrip()
	_test_intent_json_roundtrip()
	_test_host_submit_identical()
	_test_client_must_not_roll_on_wire()
	_test_seat_ownership()
	_test_guest_hydrate_from_packed_state()
	_test_hotseat_still_direct()
	_test_host_timer_broadcast_and_guest_hydrate()
	_test_local_vs_active_seat_semantics()


func _test_source_stamps() -> void:
	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	eq(net_src.contains("MultiplayerSynchronizer"), false, "net_session does not invent MultiplayerSynchronizer")
	eq(net_src.contains("ENetMultiplayerPeer"), true, "net_session uses ENet")
	truthy(net_src.contains("res://backend/matchmaking.gd"), "queue host loads the matchmaking module")
	eq(net_src.contains("DedicatedServer"), false, "net_session does not invent a DedicatedServer type")
	eq(net_src.contains("Gloam"), false, "net_session does not invent Gloam")
	eq(net_src.contains("Mender"), false, "net_session does not invent Mender")
	eq(net_src.contains("Bastion"), false, "net_session does not invent Bastion")
	eq(net_src.contains("Pulse"), false, "net_session does not invent Pulse")
	eq(net_src.contains("Residue"), false, "net_session does not invent Residue")
	eq(net_src.contains("Blends"), false, "net_session does not invent Blends")
	var lobby := FileAccess.get_file_as_string("res://scenes/online_lobby.gd")
	eq(lobby.contains("auth"), false, "lobby does not invent auth")
	truthy(lobby.contains("Join queue"), "lobby joins the queue after a class pick")
	truthy(lobby.contains("Host dedicated"), "lobby can host the dedicated queue")
	eq(lobby.contains("Mender"), false, "lobby does not invent Mender")
	eq(lobby.contains("Gloam"), false, "lobby does not invent Gloam")
	eq(lobby.contains("Bastion"), false, "lobby does not invent Bastion")
	var md := FileAccess.get_file_as_string("res://MIGRATION_PHASE_E.md")
	truthy(md.contains("submit(intent)"), "Phase E keeps submit identical")
	truthy(md.contains("listen-host"), "Phase E names listen-host")
	truthy(md.contains("ENet"), "Phase E names ENet")
	eq(_host.TRANSPORT, "enet", "transport stamp is enet")
	eq(_host.owns_seat(0), true, "offline host owns seat 0")
	eq(_host.owns_seat(1), false, "offline host does not own seat 1")
	eq(_guest.owns_seat(1), true, "offline guest owns seat 1")
	eq(_guest.can_reset_match(), false, "guest cannot reset")


func _test_intent_codec_roundtrip() -> void:
	var move := {"type": "move", "to": Vector2i(2, 1), "seat": 0}
	var encoded := IntentCodec.encode_intent(move)
	var decoded := IntentCodec.decode_intent(encoded)
	eq(decoded["type"], "move", "codec keeps type")
	eq(decoded["to"], Vector2i(2, 1), "codec restores Vector2i dest")
	eq(int(decoded["seat"]), 0, "codec keeps seat")

	var cast := {"type": "cast", "spell": "shoulder", "to": Vector2i(1, 0)}
	eq(IntentCodec.decode_intent(IntentCodec.encode_intent(cast))["to"], Vector2i(1, 0), "cast dest survives encode")
	eq(HostValidate.validate_intent(IntentCodec.decode_intent(IntentCodec.encode_intent(cast)))["ok"], true, "decoded cast still passes host-validate")


func _test_intent_json_roundtrip() -> void:
	var intent := {"type": "place", "seat": 1, "to": Vector2i(6, 2)}
	var text := IntentCodec.to_json(intent)
	var back: Variant = IntentCodec.from_json(text)
	eq(typeof(back), TYPE_DICTIONARY, "JSON decode is a dict")
	eq(back["to"], Vector2i(6, 2), "JSON restores place dest")
	eq(int(back["seat"]), 1, "JSON restores seat")
	eq(HostValidate.validate_intent(back)["ok"], true, "JSON place still passes host-validate")


func _test_host_submit_identical() -> void:
	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
		"fixture": true,
	})
	var move := {"type": "move", "to": Vector2i(2, 1)}
	eq(HostValidate.validate_intent(move)["ok"], true, "host-validate accepts the move Intent")
	var result: Dictionary = _host.submit(move)
	eq(result["ok"], true, "host NetSession.submit accepts that same move Intent")
	eq(_sim.snapshot()["units"][0]["pos"], Vector2i(2, 1), "CombatSim still moved on the host")

	var face := {"type": "face", "dir": "S"}
	eq(_host.submit(face)["ok"], true, "host accepts the same face Intent")
	eq(_host.submit({"type": "end_turn"})["ok"], true, "host accepts the same end_turn Intent")


func _test_client_must_not_roll_on_wire() -> void:
	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"fixture": true,
	})
	var rolled := {"type": "cast", "spell": "strike", "to": Vector2i(2, 1), "roll": 12}
	var result: Dictionary = _host.submit(rolled)
	eq(result["ok"], false, "host rejects a client roll")
	eq(str(result["reason"]), "client_must_not_roll", "reject reason is client_must_not_roll")


func _test_seat_ownership() -> void:
	_host.reset_match({"seed": 1})
	var guest_cell: Vector2i = _first_zone_cell(1)
	var stolen: Dictionary = _host.submit_for_seat({"type": "place", "seat": 1, "to": guest_cell}, 0)
	eq(stolen["ok"], false, "host cannot place the guest seat")
	eq(str(stolen["reason"]), "not_your_seat", "stolen place is not_your_seat")

	var host_cell: Vector2i = _first_zone_cell(0)
	var placed: Dictionary = _host.submit_for_seat({"type": "place", "seat": 0, "to": host_cell}, 0)
	eq(placed["ok"], true, "host can place seat 0")

	var guest_place: Dictionary = _host.submit_for_seat({"type": "place", "seat": 1, "to": guest_cell}, 1)
	eq(guest_place["ok"], true, "guest seat can place on the host")


func _test_guest_hydrate_from_packed_state() -> void:
	_host.reset_match({
		"seed": 7,
		"elev_seed": 7,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
		"fixture": true,
	})
	_host.submit({"type": "move", "to": Vector2i(2, 1)})
	eq(_host.last_packed.is_empty(), false, "host packed a state")
	_guest.apply_packed_state(_host.last_packed)
	eq(int(_guest.snapshot()["seed"]), 7, "guest snapshot.seed is the host seed")
	eq(int(_guest.snapshot()["elev_seed"]), 7, "guest snapshot.elev_seed is the host elev_seed")
	eq(_guest.snapshot()["units"][0]["pos"], Vector2i(2, 1), "guest hydrate has the host move")
	eq(int(_guest.snapshot()["local_seat"]), 1, "guest decorate stamps local_seat 1")
	eq(int(_guest.snapshot()["active_seat"]), 0, "guest snapshot keeps host active_seat")
	eq(_guest.legal_intents(0).size(), _sim.legal_intents(0).size(), "full host packet still carries seat 0 legal")
	var preview: Dictionary = _guest.preview_cast("mark_shot")
	eq(str(preview.get("spell_id", "")), "mark_shot", "guest replica still serves preview_cast")
	eq(preview.has("hit_chance"), true, "guest preview_cast does not roll a new API")


func _test_hotseat_still_direct() -> void:
	var net_script := load("res://backend/net_session.gd")
	var hot: Node = net_script.new()
	hot.attach_sim(_sim)
	eq(hot.is_hotseat(), true, "fresh NetSession is hot-seat")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
	})
	var result: Dictionary = hot.submit({"type": "move", "to": Vector2i(2, 1)})
	eq(result["ok"], true, "hot-seat NetSession still calls CombatSim.submit")
	eq(_sim.snapshot()["networking"], false, "CombatSim snapshot.networking stays false")
	hot.free()


func _test_host_timer_broadcast_and_guest_hydrate() -> void:
	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
		"fixture": true,
	})
	var snap: Dictionary = _host.snapshot()
	eq(snap.has("turn_time_remaining"), true, "host snapshot has turn_time_remaining")
	eq(snap.has("turn_time_limit"), true, "host snapshot has turn_time_limit")
	eq(int(snap["turn_time_seconds"]), 30, "host clock starts at 30")
	eq(int(snap["local_seat"]), 0, "host decorate stamps local_seat 0")
	eq(int(snap["active_seat"]), 0, "host active_seat is 0")
	eq(int(snap["net"]["local_seat"]), 0, "net.local_seat is 0 on the host")
	eq(int(snap["net"]["active_seat"]), 0, "net.active_seat is 0 on the host")

	var ticked: Dictionary = _host.tick_turn_timer(1.0)
	eq(bool(ticked.get("expired", false)), false, "1s tick does not expire")
	eq(_host.last_packed.is_empty(), false, "host packed after a timer tick")
	var packed_snap: Dictionary = IntentCodec.decode(_host.last_packed)["snapshot"]
	eq(int(ceili(float(packed_snap["turn_time_remaining"]))), 29, "packed snapshot remaining is 29 after 1s")

	var guest_pack: Dictionary = _host.pack_result({
		"ok": true,
		"illegal": false,
		"reason": "",
		"events": [],
		"snapshot": _sim.snapshot(),
	}, 1)
	_guest.apply_packed_state(guest_pack)
	eq(int(_guest.snapshot()["turn_time_seconds"]), 29, "guest hydrate copies remaining seconds")
	eq(int(_guest.snapshot()["local_seat"]), 1, "guest decorate keeps local_seat 1")
	eq(int(_guest.snapshot()["active_seat"]), 0, "guest still sees host active_seat 0")
	eq(_guest.legal_intents(0).is_empty(), true, "guest packet seat-filters legal_intents for seat 0")
	eq(_guest.legal_intents(1).is_empty(), true, "guest legal_intents empty on opponent turn")

	var expired: Dictionary = _host.tick_turn_timer(29.0)
	eq(bool(expired.get("expired", false)), true, "30s host tick expires")
	eq(int(_sim.snapshot()["active_seat"]), 1, "expiry end_turn hands Ironjaw the seat")
	eq(int(_host.snapshot()["turn_time_seconds"]), 30, "host next-turn clock is 30")
	_guest.apply_packed_state(_host.pack_result(expired, 1))
	eq(int(_guest.snapshot()["active_seat"]), 1, "guest hydrate sees the new active_seat")
	eq(int(_guest.snapshot()["turn_time_seconds"]), 30, "guest hydrate sees the reset clock")
	eq(_guest.legal_intents(1).is_empty(), false, "guest packet includes seat 1 legal on their turn")
	eq(_guest.legal_intents(0).is_empty(), true, "guest packet still filters seat 0 legal")
	var guest_tick: Dictionary = _guest.tick_turn_timer(30.0)
	eq(int(_guest.snapshot()["active_seat"]), 1, "guest tick_turn_timer does not change the seat")
	eq(int(_sim.snapshot()["active_seat"]), 1, "guest tick does not mutate the host sim")
	eq(bool(guest_tick.get("ok", false)), true, "guest tick returns the last view")

	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	truthy(net_src.contains("Mode.DEDICATED"), "dedicated queue host is a NetSession mode")
	eq(net_src.contains("DedicatedServer"), false, "net_session does not invent DedicatedServer")
	truthy(net_src.contains("tick_turn_timer"), "net_session ticks the host clock")
	var md := FileAccess.get_file_as_string("res://MIGRATION_PHASE_E.md")
	truthy(md.contains("turn_time_remaining"), "Phase E docs name turn_time_remaining")
	truthy(md.contains("local_seat"), "Phase E docs name local_seat")
	truthy(md.contains("active_seat"), "Phase E docs name active_seat")
	eq(md.contains("dedicated server process"), true, "Phase E still forbids inventing a dedicated server")


func _test_local_vs_active_seat_semantics() -> void:
	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"fixture": true,
	})
	var host_snap: Dictionary = _host.snapshot()
	eq(CombatHUD.kit_seat(host_snap), 0, "host kit chrome uses local_seat")
	eq(CombatHUD.turn_status_text(host_snap), "Your Turn", "host starts on Your Turn")
	eq(host_snap.has("show_active_kit"), false, "snapshot does not encode show_active_kit")
	_guest.apply_packed_state(_host.pack_result({
		"ok": true,
		"events": [],
		"snapshot": _sim.snapshot(),
	}, 1))
	eq(CombatHUD.kit_seat(_guest.snapshot()), 1, "guest kit chrome uses local_seat 1")
	eq(CombatHUD.turn_status_text(_guest.snapshot()), "Opponent's Turn", "guest starts on Opponent's Turn")
	eq(_guest.snapshot().has("show_active_kit"), false, "guest snapshot does not encode show_active_kit")
	eq(int(_host.snapshot()["net"]["local_seat"]), 0, "host net.local_seat is 0")
	eq(int(_guest.snapshot()["net"]["local_seat"]), 1, "guest net.local_seat is 1")
	eq(_host.snapshot().has("turn_time_seconds"), true, "host decorate keeps turn_time_seconds")
	eq(str(_host.snapshot().get("turn_timer", "")), "host", "snapshot.turn_timer stamp is host")
	var net_only: Dictionary = _host.decorate_snapshot({
		"turn_time_remaining": 22.0,
		"turn_time_limit": 30,
		"turn_time_running": true,
		"turn_time_seconds": 22,
		"turn_timer": "host",
	})
	eq(CombatHUD.snap_local_seat({"net": net_only.get("net", {})}), 0, "HUD reads net.local_seat from decorated net")
	eq(CombatHUD.turn_clock_seconds(net_only), 22, "decorated snap paints turn_time_seconds")


func _first_zone_cell(seat: int) -> Vector2i:
	var cells: Array = _sim.legal_deploy_cells(seat)
	if cells.is_empty():
		cells = _sim.deploy_zone_cells(seat)
	if cells.is_empty():
		return Vector2i(0, 0)
	return cells[0]


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
