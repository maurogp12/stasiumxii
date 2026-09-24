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
	_test_guest_paints_lava_burn_from_host()
	_test_hotseat_still_direct()
	_test_host_timer_broadcast_and_guest_hydrate()
	_test_local_vs_active_seat_semantics()
	_test_dedicated_host_core()


func _test_source_stamps() -> void:
	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	eq(net_src.contains("MultiplayerSynchronizer"), false, "net_session does not invent MultiplayerSynchronizer")
	eq(net_src.contains("ENetMultiplayerPeer"), true, "net_session uses ENet")
	truthy(net_src.contains("func select_class"), "net_session exposes select_class")
	truthy(net_src.contains("func enter_matchmaking"), "net_session exposes enter_matchmaking")
	truthy(net_src.contains("signal class_selected"), "net_session signals class_selected")
	eq(net_src.contains("Gloam"), false, "net_session does not invent Gloam")
	eq(net_src.contains("Residue"), false, "net_session does not invent Residue")
	eq(net_src.contains("Blends"), false, "net_session does not invent Blends")
	var lobby := FileAccess.get_file_as_string("res://scenes/online_lobby.gd")
	eq(lobby.contains("auth"), false, "lobby does not invent auth")
	eq(lobby.contains("matchmaking"), false, "lobby scene does not own the queue")
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


func _test_guest_paints_lava_burn_from_host() -> void:
	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0}],
		"fixture": true,
	})
	eq(_host.submit({"type": "end_turn"})["ok"], true, "host ends Kestrel's turn")
	var cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)}, 1)
	eq(cast["ok"], true, "host resolves the Shoulder onto lava")
	eq(int(_sim.snapshot()["units"][0]["burn_remaining"]), 2, "host unit carries burn_remaining")
	_guest.apply_packed_state(_host.pack_result(cast, 1))
	eq(int(_guest.snapshot()["units"][0]["burn_remaining"]), 2, "guest hydrate copies burn_remaining")
	eq(_guest.snapshot()["units"][0]["pos"], Vector2i(5, 3), "guest hydrate copies the lava cell")
	var host_toast := CombatHUD.toast_for_events(cast["events"])
	var guest_events: Array = _guest.snapshot().get("last_events", [])
	eq(host_toast, "+1 Impact  Lava - Burn", "host events toast +1 Impact and Burn")
	eq(CombatHUD.toast_for_events(guest_events), host_toast, "guest events toast the same line")
	eq(host_toast.contains(CombatHUD.BOUNCE_TOAST), false, "lava push does not toast Bounce")
	var host_pawn := Pawn.new()
	host_pawn.apply_snapshot(_sim.snapshot()["units"][0], 1, _sim.snapshot().get("last_events", []))
	var guest_pawn := Pawn.new()
	guest_pawn.apply_snapshot(_guest.snapshot()["units"][0], 1, guest_events)
	eq(host_pawn.burn_badge_label(), "BURN 2", "host pawn paints remaining turns")
	eq(guest_pawn.burn_badge_label(), host_pawn.burn_badge_label(), "guest pawn paints the same Burn badge")
	var before := int(_guest.snapshot()["units"][0]["burn_remaining"])
	_guest.tick_turn_timer(30.0)
	eq(int(_guest.snapshot()["units"][0]["burn_remaining"]), before, "guest does not tick Burn")
	host_pawn.free()
	guest_pawn.free()


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
	var guest_advance: Array[Vector2i] = SnapshotTiles.cast_dests(_guest.legal_intents(1), "advance")
	var host_advance: Array[Vector2i] = SnapshotTiles.cast_dests(_sim.legal_intents(1), "advance")
	eq(guest_advance, host_advance, "guest Advance dests match host legal_intents")
	eq(guest_advance.has(Vector2i(7, 7)), false, "guest packet does not offer a diagonal Advance")
	eq(guest_advance.has(Vector2i(4, 6)), false, "guest packet does not offer Manhattan 2 Advance")
	truthy(guest_advance.size() > 0 and guest_advance.size() <= 4, "guest Advance chrome is 1 to 4 ortho cells")
	for cell in guest_advance:
		truthy(_sim.is_cardinal_step(Vector2i(6, 6), cell), "guest Advance dest %s is an ortho neighbor" % str(cell))
	var guest_tick: Dictionary = _guest.tick_turn_timer(30.0)
	eq(int(_guest.snapshot()["active_seat"]), 1, "guest tick_turn_timer does not change the seat")
	eq(int(_sim.snapshot()["active_seat"]), 1, "guest tick does not mutate the host sim")
	eq(bool(guest_tick.get("ok", false)), true, "guest tick returns the last view")

	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	truthy(net_src.contains("--dedicated"), "net_session accepts a dedicated process")
	truthy(net_src.contains("func is_authority"), "listen-host and dedicated share is_authority")
	eq(net_src.contains("DedicatedServer"), false, "host core stays inside NetSession")
	truthy(net_src.contains("tick_turn_timer"), "net_session ticks the host clock")
	var md := FileAccess.get_file_as_string("res://MIGRATION_PHASE_E.md")
	truthy(md.contains("turn_time_remaining"), "Phase E docs name turn_time_remaining")
	truthy(md.contains("local_seat"), "Phase E docs name local_seat")
	truthy(md.contains("active_seat"), "Phase E docs name active_seat")
	truthy(md.contains("dedicated server process"), "Phase E docs name the dedicated server process")


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


func _test_dedicated_host_core() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var net_script := load("res://backend/net_session.gd")
	var brain: Node = sim_script.new()
	var view0: Node = sim_script.new()
	var view1: Node = sim_script.new()
	var dedicated: Node = net_script.new()
	var seat0: Node = net_script.new()
	var seat1: Node = net_script.new()
	dedicated.attach_sim(brain)
	dedicated.enter_dedicated_offline()
	seat0.attach_sim(view0)
	seat1.attach_sim(view1)
	seat0.enter_client_unassigned()
	seat1.enter_client_unassigned()

	eq(dedicated.is_authority(), true, "dedicated is the shared authority")
	eq(dedicated.is_dedicated(), true, "dedicated mode is set")
	eq(dedicated.is_host(), false, "dedicated is not the listen-host window")
	eq(dedicated.owns_seat(0), false, "dedicated process owns no seat 0")
	eq(dedicated.owns_seat(1), false, "dedicated process owns no seat 1")
	eq(int(dedicated.local_seat), -1, "dedicated local_seat stays unassigned")
	eq(dedicated.can_reset_match(), true, "dedicated authority can reset")
	eq(bool(dedicated.snapshot()["net"]["dedicated"]), true, "decorate stamps dedicated")
	eq(bool(dedicated.snapshot()["net"]["authority"]), true, "decorate stamps authority")
	eq(bool(dedicated.snapshot()["net"]["listen_host"]), false, "dedicated is not listen-host")

	var plan: Dictionary = net_script.plan_from_args(PackedStringArray(["--dedicated", "7777"]))
	eq(str(plan["mode"]), "dedicated", "--dedicated plans a dedicated process")
	eq(int(plan["port"]), 7777, "--dedicated keeps port 7777")
	var remote: Dictionary = net_script.plan_from_args(PackedStringArray(["--join", "10.0.0.8:7777"]))
	eq(str(remote["mode"]), "client", "--join plans a client")
	eq(str(remote["address"]), "10.0.0.8", "--join keeps the remote IP")
	eq(int(remote["port"]), 7777, "--join keeps the remote port")
	var listen: Dictionary = net_script.plan_from_args(PackedStringArray(["--host", "7777"]))
	eq(str(listen["mode"]), "host", "--host still plans listen-host")

	eq(dedicated.assign_peer_seat(2), 0, "first dedicated peer is seat 0")
	eq(dedicated.assign_peer_seat(3), 1, "second dedicated peer is seat 1")
	eq(dedicated.assign_peer_seat(4), -1, "third dedicated peer is refused")
	eq(dedicated.release_peer(2), 0, "dedicated stub records seat 0 leaving")
	eq(dedicated.peer_for_seat(0), 0, "left dedicated peer is cleared")
	eq(dedicated.seat_reserved(0), true, "dedicated seat stays reserved")
	eq(dedicated.assign_peer_seat(5), -1, "reserved dedicated seat is not reassigned")

	_host.enter_host_offline()
	eq(_host.assign_peer_seat(2), 1, "listen-host guest is seat 1")
	eq(_host.release_peer(2), 1, "listen-host guest can leave")
	eq(_host.assign_peer_seat(3), 1, "listen-host guest slot can be taken again")
	_host.enter_host_offline()

	dedicated.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"fixture": true,
		"kestrel_pos": Vector2i(4, 3),
		"ironjaw_pos": Vector2i(3, 3),
		"kestrel_facing": "W",
		"tiles": [
			{"pos": Vector2i(5, 3), "terrain": "lava", "elevation": 0},
		],
	})
	eq(dedicated.submit_for_seat({"type": "end_turn"}, 0)["ok"], true, "dedicated accepts seat 0 end_turn")
	var shoulder: Dictionary = dedicated.submit_for_seat({"type": "cast", "spell": "shoulder", "to": Vector2i(4, 3)}, 1)
	eq(shoulder["ok"], true, "dedicated authority resolves Shoulder")
	eq(brain.snapshot()["units"][0]["pos"], Vector2i(5, 3), "server owns the lava push")
	eq(int(brain.snapshot()["units"][0]["hp"]), 74, "server owns HP")
	eq(int(brain.snapshot()["units"][0]["burn_remaining"]), 2, "server owns Burn")
	eq(int(brain.snapshot()["units"][1]["impact"]), 1, "server owns Impact")
	eq(int(brain.snapshot()["units"][0]["mp"]), 3, "server owns MP")
	eq(int(brain.snapshot()["units"][0]["marks"]), 0, "server owns Marks")

	seat0.apply_packed_state(dedicated.pack_result(shoulder, 0))
	seat1.apply_packed_state(dedicated.pack_result(shoulder, 1))
	eq(int(seat0.local_seat), 0, "viewer_seat assigns the first client to seat 0")
	eq(int(seat1.local_seat), 1, "viewer_seat assigns the second client to seat 1")
	eq(seat0.snapshot()["units"][0]["pos"], Vector2i(5, 3), "client hydrates the push")
	eq(int(seat0.snapshot()["units"][0]["hp"]), 74, "client hydrates HP")
	eq(int(seat0.snapshot()["units"][0]["burn_remaining"]), 2, "client hydrates Burn")
	eq(int(seat1.snapshot()["units"][1]["impact"]), 1, "client hydrates Impact")
	var lava_toast := CombatHUD.toast_for_events(shoulder["events"])
	eq(lava_toast, "+1 Impact  Lava - Burn", "dedicated Shoulder toasts +1 Impact and Burn")
	eq(lava_toast.contains(CombatHUD.BOUNCE_TOAST), false, "dedicated lava push is not Bounce")
	eq(CombatHUD.toast_for_events(seat0.snapshot().get("last_events", [])), lava_toast, "seat 0 paints the same toast")
	eq(CombatHUD.toast_for_events(seat1.snapshot().get("last_events", [])), lava_toast, "seat 1 paints the same toast")
	var seat0_pawn := Pawn.new()
	seat0_pawn.apply_snapshot(seat0.snapshot()["units"][0], 1, seat0.snapshot().get("last_events", []))
	var seat1_pawn := Pawn.new()
	seat1_pawn.apply_snapshot(seat1.snapshot()["units"][0], 1, seat1.snapshot().get("last_events", []))
	eq(seat0_pawn.burn_badge_label(), "BURN 2", "seat 0 paints Burn duration")
	eq(seat1_pawn.burn_badge_label(), seat0_pawn.burn_badge_label(), "seat 1 paints the same Burn badge")
	seat0_pawn.free()
	seat1_pawn.free()
	eq(str(seat0.snapshot()["tiles"][Vector2i(5, 3)]["terrain_type"]), "lava", "client hydrates terrain")
	eq(seat0.can_reset_match(), true, "seat 0 client may request New Match")
	eq(seat1.can_reset_match(), false, "seat 1 client cannot reset")

	var hp_before := int(brain.snapshot()["units"][0]["hp"])
	var client_submit: Dictionary = seat0.submit({"type": "end_turn"})
	eq(str(client_submit.get("reason", "")), "not_connected", "offline client does not submit locally")
	eq(int(brain.snapshot()["units"][0]["hp"]), hp_before, "client submit does not change server HP")
	eq(int(brain.snapshot()["active_seat"]), 1, "client submit does not change the turn")

	var expired: Dictionary = dedicated.tick_turn_timer(30.0)
	eq(bool(expired.get("expired", false)), true, "dedicated clock expiry ends the turn")
	eq(int(brain.snapshot()["active_seat"]), 0, "dedicated timer hands the seat back")
	eq(int(brain.snapshot()["units"][0]["hp"]), 70, "dedicated timer owns the Burn tick")
	eq(int(brain.snapshot()["units"][0]["burn_remaining"]), 1, "dedicated timer decrements Burn")
	seat0.apply_packed_state(dedicated.pack_result(expired, 0))
	eq(int(seat0.snapshot()["units"][0]["hp"]), 70, "client hydrates the Burn tick")
	eq(int(seat0.snapshot()["turn_time_seconds"]), 30, "client hydrates the reset clock")
	var ticked_pawn := Pawn.new()
	ticked_pawn.apply_snapshot(seat0.snapshot()["units"][0], 0)
	eq(ticked_pawn.burn_badge_label(), "BURN 1", "client paints the host's ticked duration")
	eq(ticked_pawn.burn_remaining, 1, "client badge follows the host snapshot")
	ticked_pawn.free()
	var client_tick: Dictionary = seat0.tick_turn_timer(30.0)
	eq(int(brain.snapshot()["active_seat"]), 0, "client tick does not change the server seat")
	eq(int(brain.snapshot()["units"][0]["hp"]), 70, "client tick does not apply Burn")
	eq(bool(client_tick.get("ok", false)), true, "client tick returns the last view")

	var seed_before := int(brain.snapshot()["seed"])
	var denied: Dictionary = dedicated.accept_reset_request({
		"seed": 1,
		"rolls": [1],
		"skip_deploy": true,
		"fixture": true,
	}, 1)
	eq(denied["ok"], false, "seat 1 cannot reset the dedicated match")
	eq(int(brain.snapshot()["seed"]), seed_before, "rejected reset keeps the server seed")
	var accepted: Dictionary = dedicated.accept_reset_request({
		"seed": 1,
		"rolls": [99],
		"skip_deploy": true,
		"fixture": true,
		"kestrel_pos": Vector2i(1, 1),
	}, 0)
	eq(accepted["ok"], true, "seat 0 reset request starts a server match")
	eq(str(brain.snapshot()["phase"]), "DEPLOYMENT", "server ignores client skip_deploy")
	eq(int(brain.snapshot()["seed"]) == 1, false, "server ignores the client seed")

	var rolled: Dictionary = dedicated.submit_for_seat({"type": "move", "to": Vector2i(2, 1), "roll": 4}, 0)
	eq(str(rolled.get("reason", "")), "client_must_not_roll", "dedicated host-validate still rejects client rolls")

	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	truthy(net_src.contains("func start_dedicated"), "net_session has a dedicated entry")
	eq(net_src.contains("WebSocketMultiplayerPeer"), false, "remote playtest stays on ENet")
	truthy(net_src.contains("func select_class"), "net_session exposes select_class")
	truthy(net_src.contains("func enter_matchmaking"), "net_session exposes enter_matchmaking")
	truthy(net_src.contains("signal class_selected"), "net_session signals class_selected")
	eq(net_src.contains("Gloam"), false, "net_session does not invent Gloam")
	var lobby := FileAccess.get_file_as_string("res://scenes/online_lobby.gd")
	eq(lobby.contains("auth"), false, "lobby still does not invent auth")
	var readme := FileAccess.get_file_as_string("res://README.md")
	truthy(readme.contains("--dedicated 7777"), "README documents the dedicated command")
	truthy(readme.contains("Machine A"), "README documents the three-process playtest")
	truthy(readme.contains("Machine C"), "README documents the second client")

	dedicated.free()
	seat0.free()
	seat1.free()
	brain.free()
	view0.free()
	view1.free()


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
