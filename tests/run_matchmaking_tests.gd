extends SceneTree

## SELECT_CLASS + queue: Locked roster only, then CombatSim seats.
## Run: godot --headless --path . -s res://tests/run_matchmaking_tests.gd

var _failed: int = 0
var _passed: int = 0
var _sim: Node
var _host: Node


func _initialize() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var net_script := load("res://backend/net_session.gd")
	_sim = sim_script.new()
	_host = net_script.new()
	_host.attach_sim(_sim)
	_host.enter_dedicated_offline()
	_run()
	print("Matchmaking tests: %d passed, %d failed" % [_passed, _failed])
	_host.free()
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_roster_gate()
	_test_invalid_class_does_not_confirm()
	_test_enqueue_requires_class()
	_test_pair_keeps_queue_order()
	_test_swapped_pair_spawns_kits()
	_test_advance_stays_locked()
	_test_mirror_ironjaw()
	_test_invalid_config_does_not_invent_a_kit()
	_test_hotseat_default_pair()
	_test_queue_client_needs_a_class()
	_test_third_waits()
	_test_source_stamps()


func _test_roster_gate() -> void:
	eq(SpellKits.LOCKED_ROSTER.size(), 2, "roster is two classes")
	eq(SpellKits.is_roster_class("kestrel"), true, "kestrel is on the roster")
	eq(SpellKits.is_roster_class(" Ironjaw "), true, "ironjaw normalizes")
	eq(SpellKits.is_roster_class("mender"), false, "mender is not on the roster")
	eq(SpellKits.is_roster_class("gloam"), false, "gloam is not on the roster")
	eq(SpellKits.is_roster_class("bastion"), false, "bastion is not on the roster")
	eq(SpellKits.is_roster_class(""), false, "empty class is rejected")
	eq(SpellKits.class_spells("mender"), ["mend", "pulse_tap", "ward", "cleanse", "heartstop"], "mender card ids are chrome only")
	eq(SpellKits.awaits_backend("mend"), true, "mender casts stay backend_pending")
	var advance: Dictionary = SpellKits.spell(SpellKits.ADVANCE)
	eq(int(advance.get("ap", -1)), 3, "Advance stays 3 AP")
	eq(int(advance.get("mp", -1)), 0, "Advance stays 0 MP")
	eq(str(advance.get("range_mode", "")), "cardinal", "Advance stays cardinal")
	eq(int(advance.get("min_range", -1)), 1, "Advance min range stays 1")
	eq(int(advance.get("max_range", -1)), 1, "Advance max range stays 1")


func _test_invalid_class_does_not_confirm() -> void:
	var queue := MatchQueue.new()
	for bad in ["mender", "gloam", "bastion", "pulse", "", "  "]:
		var rejected: Dictionary = queue.handle("p1", {"type": MatchQueue.SELECT_CLASS, "class_id": bad})
		eq(bool(rejected.get("ok", true)), false, "SELECT_CLASS rejects %s" % bad)
		eq(str(rejected.get("reason", "")), "invalid_class", "reject reason is invalid_class for %s" % bad)
		eq(queue.session("p1").is_empty(), true, "rejected SELECT_CLASS does not store %s" % bad)
	var kept: Dictionary = queue.select_class("p2", "kestrel")
	eq(bool(kept.get("ok", false)), true, "kestrel SELECT_CLASS confirms")
	var again: Dictionary = queue.select_class("p2", "bastion")
	eq(bool(again.get("ok", true)), false, "later invalid SELECT_CLASS is rejected")
	eq(str(queue.session("p2").get("class_id", "")), "kestrel", "confirmed class stays kestrel")
	eq(bool(queue.session("p2").get("confirmed", false)), true, "session stays confirmed")


func _test_enqueue_requires_class() -> void:
	var missing: Dictionary = _host.server_enqueue("nobody")
	eq(bool(missing.get("ok", true)), false, "enqueue without a session fails")
	eq(str(missing.get("reason", "")), "class_required", "reason is class_required")
	var bad: Dictionary = _host.server_select_class("late", "mender")
	eq(bool(bad.get("ok", true)), false, "server SELECT_CLASS rejects mender")
	eq(_host.server_session("late").is_empty(), true, "server does not store mender")
	var queued: Dictionary = _host.server_enqueue("late")
	eq(bool(queued.get("ok", true)), false, "unconfirmed session cannot queue")
	eq(str(queued.get("reason", "")), "class_required", "unconfirmed enqueue is class_required")


func _test_pair_keeps_queue_order() -> void:
	var first: Dictionary = _host.server_select_class("a", "KESTREL")
	eq(str(first.get("class_id", "")), "kestrel", "server stores normalized kestrel")
	eq(str(_host.server_session("a").get("class_id", "")), "kestrel", "session keeps kestrel")
	var waiting: Dictionary = _host.server_enqueue("a")
	eq(bool(waiting.get("matched", true)), false, "one player does not start a match")
	eq(bool(waiting.get("queued", false)), true, "first player is queued")
	_host.server_select_class("b", "ironjaw")
	var paired: Dictionary = _host.server_enqueue("b")
	eq(bool(paired.get("matched", false)), true, "second confirmed player pairs")
	var match: Dictionary = paired.get("match", {})
	var class_ids: Array = match.get("class_ids", [])
	eq(str(class_ids[0]), "kestrel", "seat 0 is the first queued class")
	eq(str(class_ids[1]), "ironjaw", "seat 1 is the second queued class")
	eq(str(_sim.snapshot()["units"][0]["class_id"]), "kestrel", "sim seat 0 is kestrel")
	eq(str(_sim.snapshot()["units"][1]["class_id"]), "ironjaw", "sim seat 1 is ironjaw")
	eq(_sim.snapshot()["units"][0]["spells"], ["mark_shot", "detonate"], "seat 0 has the Kestrel kit")
	eq(_sim.snapshot()["units"][1]["spells"], ["advance", "strike", "shoulder", "crush"], "seat 1 has the Ironjaw kit")
	eq(int(_host.server_session("a").get("seat", -2)), 0, "first session is seat 0")
	eq(int(_host.server_session("b").get("seat", -2)), 1, "second session is seat 1")


func _test_swapped_pair_spawns_kits() -> void:
	var host_script := load("res://backend/net_session.gd")
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	var host: Node = host_script.new()
	host.attach_sim(sim)
	host.enter_dedicated_offline()
	host.server_select_class("first", "ironjaw")
	host.server_enqueue("first")
	host.server_select_class("second", "kestrel")
	var paired: Dictionary = host.server_enqueue("second")
	eq(bool(paired.get("matched", false)), true, "swapped pair matches")
	var units: Array = sim.snapshot()["units"]
	eq(str(units[0]["class_id"]), "ironjaw", "seat 0 stays ironjaw (not forced to Kestrel)")
	eq(str(units[1]["class_id"]), "kestrel", "seat 1 stays kestrel")
	eq(str(units[0]["name"]), "Ironjaw", "seat 0 name is Ironjaw")
	eq(str(units[1]["name"]), "Kestrel", "seat 1 name is Kestrel")
	eq("advance" in units[0]["spells"], true, "ironjaw seat has Advance")
	eq("advance" in units[1]["spells"], false, "kestrel seat has no Advance")
	eq(sim.snapshot()["match_config"]["classes"], ["ironjaw", "kestrel"], "match_config records seat classes")
	host.free()
	sim.free()


func _test_advance_stays_locked() -> void:
	var snap: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["ironjaw", "kestrel"],
		"positions": [Vector2i(3, 3), Vector2i(7, 7)],
	})
	eq(str(snap["units"][0]["class_id"]), "ironjaw", "spawn uses the ironjaw class id")
	eq(snap["units"][0]["pos"], Vector2i(3, 3), "ironjaw spawned on seat 0")
	eq(snap["units"][1]["pos"], Vector2i(7, 7), "kestrel spawned on seat 1")
	var advances: Array = []
	for intent in _sim.legal_intents(0):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == "advance":
			advances.append(intent["to"])
	eq(advances.size(), 4, "Advance offers exactly 4 destinations")
	for dest in advances:
		var cell: Vector2i = dest
		var manhattan := absi(cell.x - 3) + absi(cell.y - 3)
		eq(manhattan, 1, "Advance dest %s is an orthogonal neighbor" % cell)
	var cast: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(4, 3), "seat": 0})
	eq(bool(cast.get("ok", false)), true, "ortho Advance resolves")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 3, "Advance spends 3 AP")
	eq(int(_sim.snapshot()["units"][0]["mp"]), 3, "Advance spends 0 MP")
	eq(_sim.snapshot()["units"][0]["pos"], Vector2i(4, 3), "Advance snaps to the ortho tile")


func _test_mirror_ironjaw() -> void:
	var snap: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["ironjaw", "ironjaw"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	eq(str(snap["units"][0]["class_id"]), "ironjaw", "mirror seat 0 is ironjaw")
	eq(str(snap["units"][1]["class_id"]), "ironjaw", "mirror seat 1 is ironjaw")
	eq("advance" in snap["units"][0]["spells"], true, "both seats keep the Ironjaw kit")
	eq("advance" in snap["units"][1]["spells"], true, "second ironjaw keeps Advance")
	eq("mark_shot" in snap["units"][0]["spells"], false, "mirror match does not invent a Kestrel kit")


func _test_invalid_config_does_not_invent_a_kit() -> void:
	var snap: Dictionary = _sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"flat_board": true,
		"classes": ["mender", "kestrel"],
	})
	eq(str(snap["units"][0]["class_id"]), "kestrel", "unknown class falls back to Kestrel")
	eq(str(snap["units"][1]["class_id"]), "ironjaw", "unknown class falls back to Ironjaw")
	eq(str(snap["units"][0]["class_id"]) != "mender", true, "mender is not spawned")


func _test_hotseat_default_pair() -> void:
	var snap: Dictionary = _sim.reset_match({"seed": 1, "skip_deploy": true, "flat_board": true})
	eq(str(snap["units"][0]["class_id"]), "kestrel", "hot-seat seat 0 stays Kestrel")
	eq(str(snap["units"][1]["class_id"]), "ironjaw", "hot-seat seat 1 stays Ironjaw")
	eq(str(snap["coach"]), "Kestrel's turn. 6 AP / 3 MP.", "default coach still names Kestrel")


func _test_queue_client_needs_a_class() -> void:
	var net_script := load("res://backend/net_session.gd")
	var client: Node = net_script.new()
	var rejected: Dictionary = client.select_class("gloam")
	eq(bool(rejected.get("ok", true)), false, "client rejects gloam before connect")
	eq(client.selected_class_id, "", "rejected class is not stored locally")
	var blocked: Dictionary = client.start_queue_client("127.0.0.1", 7777)
	eq(bool(blocked.get("ok", true)), false, "queue connect requires a class")
	eq(str(blocked.get("reason", "")), "class_required", "missing class is class_required")
	eq(client.is_hotseat(), true, "failed queue connect stays on hot-seat")
	var picked: Dictionary = client.select_class("ironjaw")
	eq(bool(picked.get("ok", false)), true, "client can confirm ironjaw")
	eq(client.selected_class_id, "ironjaw", "confirmed class is stored before connect")
	client.free()


func _test_third_waits() -> void:
	var host_script := load("res://backend/net_session.gd")
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	var host: Node = host_script.new()
	host.attach_sim(sim)
	host.enter_dedicated_offline()
	host.server_select_class("p1", "kestrel")
	host.server_select_class("p2", "kestrel")
	host.server_select_class("p3", "ironjaw")
	host.server_enqueue("p1")
	var paired: Dictionary = host.server_enqueue("p2")
	eq(bool(paired.get("matched", false)), true, "first two pair")
	eq(sim.snapshot()["match_config"]["classes"], ["kestrel", "kestrel"], "mirror kestrel classes land on seats")
	var waiting: Dictionary = host.server_enqueue("p3")
	eq(bool(waiting.get("matched", true)), false, "third player is not forced into the match")
	eq(bool(waiting.get("queued", false)), true, "third player stays queued")
	eq(int(host.server_session("p3").get("seat", 0)), -1, "waiting player has no seat yet")
	host.free()
	sim.free()


func _test_source_stamps() -> void:
	var kits := FileAccess.get_file_as_string("res://data/kits.gd")
	var queue_src := FileAccess.get_file_as_string("res://backend/matchmaking.gd")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	truthy(kits.contains("CLASS_MENDER"), "card chrome names mender")
	eq(SpellKits.is_roster_class("mender"), false, "allowlist still excludes mender")
	eq(SpellKits.is_roster_class("gloam"), false, "allowlist still excludes gloam")
	eq(SpellKits.is_roster_class("bastion"), false, "allowlist still excludes bastion")
	eq(queue_src.contains("SELECT_CLASS"), true, "queue names SELECT_CLASS")
	eq(queue_src.contains("Pulse"), false, "queue does not invent Pulse")
	eq(queue_src.contains("Blends"), false, "queue does not invent Blends")
	eq(queue_src.contains("reconnect"), false, "queue does not invent reconnect")
	eq(sim_src.contains("dedicated"), false, "CombatSim does not become a server")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["ap"]), 3, "kit table Advance AP is still 3")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["mp"]), 0, "kit table Advance MP is still 0")


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
