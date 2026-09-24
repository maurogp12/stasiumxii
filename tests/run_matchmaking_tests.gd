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
	_test_five_class_pair()
	_test_bound_seats_keep_class()
	_test_proto_defaults()
	_test_umbral_cap()
	_test_ambush_miss_keeps_shade()
	_test_aegis_break()
	_test_snap_wall_blocks_only_with_bastion()
	_test_open_spells_are_not_free_casts()


func _test_roster_gate() -> void:
	eq(SpellKits.LOCKED_ROSTER.size(), 5, "roster is five classes")
	eq(SpellKits.is_roster_class("kestrel"), true, "kestrel is on the roster")
	eq(SpellKits.is_roster_class(" Ironjaw "), true, "ironjaw normalizes")
	eq(SpellKits.is_roster_class("mender"), true, "mender is on the roster")
	eq(SpellKits.is_roster_class("gloam"), true, "gloam is on the roster")
	eq(SpellKits.is_roster_class("bastion"), true, "bastion is on the roster")
	eq(SpellKits.is_roster_class("pulse"), false, "pulse is not on the roster")
	eq(SpellKits.is_roster_class(""), false, "empty class is rejected")
	eq(SpellKits.class_spells("mender").is_empty(), true, "mender has no invented spell list")
	eq(SpellKits.class_spells("gloam").is_empty(), true, "gloam has no invented spell list")
	eq(SpellKits.class_spells("bastion").is_empty(), true, "bastion has no invented spell list")
	eq(SpellKits.element_of("gloam"), "", "gloam element stays Open")
	eq(SpellKits.UMBRAL_CAP, 4, "Umbral cap is 4")
	var advance: Dictionary = SpellKits.spell(SpellKits.ADVANCE)
	eq(int(advance.get("ap", -1)), 3, "Advance stays 3 AP")
	eq(int(advance.get("mp", -1)), 0, "Advance stays 0 MP")
	eq(str(advance.get("range_mode", "")), "cardinal", "Advance stays cardinal")
	eq(int(advance.get("min_range", -1)), 1, "Advance min range stays 1")
	eq(int(advance.get("max_range", -1)), 1, "Advance max range stays 1")


func _test_invalid_class_does_not_confirm() -> void:
	var queue := MatchQueue.new()
	for bad in ["pulse", "blends", "", "  "]:
		var rejected: Dictionary = queue.handle("p1", {"type": MatchQueue.SELECT_CLASS, "class_id": bad})
		eq(bool(rejected.get("ok", true)), false, "SELECT_CLASS rejects %s" % bad)
		eq(str(rejected.get("reason", "")), "invalid_class", "reject reason is invalid_class for %s" % bad)
		eq(queue.session("p1").is_empty(), true, "rejected SELECT_CLASS does not store %s" % bad)
	var kept: Dictionary = queue.select_class("p2", "kestrel")
	eq(bool(kept.get("ok", false)), true, "kestrel SELECT_CLASS confirms")
	var again: Dictionary = queue.select_class("p2", "pulse")
	eq(bool(again.get("ok", true)), false, "later invalid SELECT_CLASS is rejected")
	eq(str(queue.session("p2").get("class_id", "")), "kestrel", "confirmed class stays kestrel")
	eq(bool(queue.session("p2").get("confirmed", false)), true, "session stays confirmed")


func _test_enqueue_requires_class() -> void:
	var missing: Dictionary = _host.server_enqueue("nobody")
	eq(bool(missing.get("ok", true)), false, "enqueue without a session fails")
	eq(str(missing.get("reason", "")), "class_required", "reason is class_required")
	var bad: Dictionary = _host.server_select_class("late", "pulse")
	eq(bool(bad.get("ok", true)), false, "server SELECT_CLASS rejects pulse")
	eq(_host.server_session("late").is_empty(), true, "server does not store pulse")
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
		"classes": ["pulse", "kestrel"],
	})
	eq(str(snap["units"][0]["class_id"]), "kestrel", "unknown class falls back to Kestrel")
	eq(str(snap["units"][1]["class_id"]), "ironjaw", "unknown class falls back to Ironjaw")
	eq(str(snap["units"][0]["class_id"]) != "pulse", true, "pulse is not spawned")


func _test_hotseat_default_pair() -> void:
	var snap: Dictionary = _sim.reset_match({"seed": 1, "skip_deploy": true, "flat_board": true})
	eq(str(snap["units"][0]["class_id"]), "kestrel", "hot-seat seat 0 stays Kestrel")
	eq(str(snap["units"][1]["class_id"]), "ironjaw", "hot-seat seat 1 stays Ironjaw")
	eq(str(snap["coach"]), "Kestrel's turn. 6 AP / 3 MP.", "default coach still names Kestrel")


func _test_queue_client_needs_a_class() -> void:
	var net_script := load("res://backend/net_session.gd")
	var client: Node = net_script.new()
	var rejected: Dictionary = client.select_class("pulse")
	eq(bool(rejected.get("ok", true)), false, "client rejects pulse before connect")
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
	eq(kits.contains("CLASS_MENDER"), true, "mender id is on the allowlist")
	eq(kits.contains("CLASS_GLOAM"), true, "gloam id is on the allowlist")
	eq(kits.contains("CLASS_BASTION"), true, "bastion id is on the allowlist")
	eq(kits.contains("TODO"), true, "missing card fields stay Open")
	eq(SpellKits.spell(SpellKits.AMBUSH).is_empty(), true, "Ambush has no invented cost table")
	eq(SpellKits.spell(SpellKits.AEGIS_BREAK).is_empty(), true, "Aegis Break has no invented cost table")
	eq(queue_src.contains("SELECT_CLASS"), true, "queue names SELECT_CLASS")
	eq(queue_src.contains("Pulse"), false, "queue does not invent Pulse")
	eq(queue_src.contains("Blends"), false, "queue does not invent Blends")
	eq(queue_src.contains("reconnect"), false, "queue does not invent reconnect")
	eq(sim_src.contains("dedicated"), false, "CombatSim does not become a server")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["ap"]), 3, "kit table Advance AP is still 3")
	eq(int(SpellKits.spell(SpellKits.ADVANCE)["mp"]), 0, "kit table Advance MP is still 0")


func _test_five_class_pair() -> void:
	var host_script := load("res://backend/net_session.gd")
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	var host: Node = host_script.new()
	host.attach_sim(sim)
	host.enter_dedicated_offline()
	host.server_select_class("g", "gloam")
	host.server_enqueue("g")
	host.server_select_class("b", "bastion")
	var paired: Dictionary = host.server_enqueue("b")
	eq(bool(paired.get("matched", false)), true, "gloam and bastion pair")
	eq(str(sim.snapshot()["units"][0]["class_id"]), "gloam", "seat 0 is gloam")
	eq(str(sim.snapshot()["units"][1]["class_id"]), "bastion", "seat 1 is bastion")
	eq(sim.snapshot()["units"][0]["spells"], [], "gloam spell list stays empty")
	eq(sim.snapshot()["units"][1]["spells"], [], "bastion spell list stays empty")
	host.free()
	sim.free()


func _test_bound_seats_keep_class() -> void:
	var host_script := load("res://backend/net_session.gd")
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	var host: Node = host_script.new()
	host.attach_sim(sim)
	host.enter_dedicated_offline()
	host.server_select_class("early", "gloam")
	host.server_bind_seat("early", 1)
	host.server_select_class("late", "bastion")
	host.server_bind_seat("late", 0)
	host.server_enqueue("early")
	var paired: Dictionary = host.server_enqueue("late")
	eq(bool(paired.get("matched", false)), true, "bound seats still pair")
	var class_ids: Array = paired.get("match", {}).get("class_ids", [])
	eq(str(class_ids[0]), "bastion", "bound seat 0 keeps bastion")
	eq(str(class_ids[1]), "gloam", "bound seat 1 keeps gloam")
	eq(str(sim.snapshot()["units"][0]["class_id"]), "bastion", "sim seat 0 is bastion")
	eq(str(sim.snapshot()["units"][1]["class_id"]), "gloam", "sim seat 1 is gloam")
	host.free()
	sim.free()


func _test_proto_defaults() -> void:
	for class_id in ["mender", "gloam", "bastion"]:
		var snap: Dictionary = _sim.reset_match({
			"seed": 1,
			"flat_board": true,
			"skip_deploy": true,
			"classes": [class_id, "kestrel"],
			"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		})
		var unit: Dictionary = snap["units"][0]
		eq(str(unit["class_id"]), class_id, "%s spawns from the class id" % class_id)
		eq(int(unit["hp"]), 80, "%s proto HP is 80" % class_id)
		eq(int(unit["marks"]), 0, "%s proto marks are 0" % class_id)
		eq(int(unit["impact"]), 0, "%s proto impact is 0" % class_id)
		eq(int(unit["ap"]), 6, "%s combat AP stays 6" % class_id)
		eq(int(unit["mp"]), 3, "%s combat MP stays 3" % class_id)


func _test_umbral_cap() -> void:
	var snap: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"gloam_umbral": 9,
		"kestrel_umbral": 3,
	})
	eq(int(snap["units"][0]["umbral"]), 4, "Gloam Umbral clamps to 4")
	eq(int(snap["units"][0]["umbral_cap"]), 4, "Gloam Umbral cap is 4")
	eq(int(snap["units"][1]["umbral"]), 0, "non-Gloam Umbral stays 0")
	eq(int(snap["units"][1]["umbral_cap"]), 0, "non-Gloam has no Umbral cap")


func _test_ambush_miss_keeps_shade() -> void:
	var snap: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(2, 2), Vector2i(6, 6)],
		"gloam_shade": true,
		"gloam_invisible": true,
	})
	var before: Vector2i = snap["units"][0]["pos"]
	var missed: Dictionary = _sim.apply_locked_resolve(SpellKits.AMBUSH, false, 0, 1)
	eq(bool(missed.get("teleported", true)), false, "Ambush miss does not teleport")
	eq(bool(missed.get("shade_retained", false)), true, "Ambush miss keeps Shade")
	eq(bool(missed.get("invisible_retained", false)), true, "Ambush miss keeps Invisible")
	eq(_sim.snapshot()["units"][0]["pos"], before, "Ambush miss leaves the cell")
	eq(bool(_sim.snapshot()["units"][0]["shade"]), true, "Shade flag stays set")
	eq(bool(_sim.snapshot()["units"][0]["invisible"]), true, "Invisible flag stays set")
	var hit: Dictionary = _sim.apply_locked_resolve(SpellKits.AMBUSH, true, 0, 1)
	eq(bool(hit.get("teleported", true)), false, "Ambush hit does not invent a teleport")
	eq(bool(hit.get("open_hit", false)), true, "Ambush hit payload stays Open")
	eq(_sim.snapshot()["units"][0]["pos"], before, "Open Ambush hit does not move")
	eq(bool(_sim.snapshot()["units"][0]["shade"]), true, "Open Ambush hit does not clear Shade")


func _test_aegis_break() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "gloam"],
		"positions": [Vector2i(1, 1), Vector2i(4, 1)],
		"gloam_marks": 3,
		"gloam_impact": 2,
		"gloam_umbral": 3,
		"gloam_aegis": 2,
		"gloam_shade": true,
		"gloam_invisible": true,
	})
	var hit: Dictionary = _sim.apply_locked_resolve(SpellKits.AEGIS_BREAK, true, 0, 1)
	eq(bool(hit.get("stacks_cleared", false)), true, "Aegis Break hit clears stacks")
	var cleared: Dictionary = _sim.snapshot()["units"][1]
	eq(int(cleared["marks"]), 0, "hit clears marks")
	eq(int(cleared["impact"]), 0, "hit clears impact")
	eq(int(cleared["umbral"]), 0, "hit clears umbral")
	eq(int(cleared["aegis"]), 0, "hit clears aegis")
	eq(bool(cleared["shade"]), false, "hit clears shade")
	eq(bool(cleared["invisible"]), false, "hit clears invisible")
	eq(int(cleared["hp"]), 80, "hit does not invent damage")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "gloam"],
		"positions": [Vector2i(1, 1), Vector2i(4, 1)],
		"gloam_marks": 3,
		"gloam_umbral": 2,
		"gloam_aegis": 4,
		"gloam_shade": true,
		"gloam_invisible": true,
	})
	var missed: Dictionary = _sim.apply_locked_resolve(SpellKits.AEGIS_BREAK, false, 0, 1)
	eq(bool(missed.get("stacks_cleared", true)), false, "Aegis Break miss does not clear-all")
	var kept: Dictionary = _sim.snapshot()["units"][1]
	eq(int(kept["aegis"]), 0, "miss sets aegis to 0")
	eq(int(kept["marks"]), 3, "miss keeps marks")
	eq(int(kept["umbral"]), 2, "miss keeps umbral")
	eq(bool(kept["shade"]), true, "miss keeps shade")
	eq(bool(kept["invisible"]), true, "miss keeps invisible")


func _test_snap_wall_blocks_only_with_bastion() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"snap_walls": [Vector2i(2, 1)],
	})
	var blocked := false
	for intent in _sim.legal_intents(0):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) == "move" and intent.get("to") == Vector2i(2, 1):
			blocked = true
	eq(blocked, false, "Snap Wall is not a walk dest while Bastion is in the match")
	eq(bool(_sim.snapshot().get("snap_wall_active", false)), true, "snapshot marks Snap Wall active")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"snap_walls": [Vector2i(2, 1)],
	})
	var offered := false
	for intent in _sim.legal_intents(0):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) == "move" and intent.get("to") == Vector2i(2, 1):
			offered = true
	eq(offered, true, "Snap Wall cells do not block when Bastion is absent")
	eq(bool(_sim.snapshot().get("snap_wall_active", true)), false, "snapshot marks Snap Wall inactive")


func _test_open_spells_are_not_free_casts() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_aegis": 2,
	})
	var before := int(_sim.snapshot()["units"][0]["ap"])
	var rejected: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(3, 1), "seat": 0})
	eq(bool(rejected.get("ok", true)), false, "Ambush submit is rejected")
	eq(str(rejected.get("reason", "")), "unknown_spell", "Ambush is not a free cast")
	eq(int(_sim.snapshot()["units"][0]["ap"]), before, "rejected Ambush refunds AP")
	eq(int(_sim.snapshot()["units"][1]["aegis"]), 2, "rejected cast does not clear aegis")


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1
