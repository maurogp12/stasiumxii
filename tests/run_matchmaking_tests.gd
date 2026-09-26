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
	_test_ambush_hit()
	_test_aegis_break()
	_test_snap_wall_blocks_only_with_bastion()
	_test_snap_wall_cast()
	_test_nightfold_is_gated()
	_test_mender_heals_and_ward()
	_test_shades_cap_and_fade()
	_test_hold_line_exit_tax()
	_test_heartstop()
	_test_gloam_backstab()


func _test_roster_gate() -> void:
	eq(SpellKits.LOCKED_ROSTER.size(), 5, "roster is five classes")
	eq(SpellKits.is_roster_class("kestrel"), true, "kestrel is on the roster")
	eq(SpellKits.is_roster_class(" Ironjaw "), true, "ironjaw normalizes")
	eq(SpellKits.is_roster_class("mender"), true, "mender is on the roster")
	eq(SpellKits.is_roster_class("gloam"), true, "gloam is on the roster")
	eq(SpellKits.is_roster_class("bastion"), true, "bastion is on the roster")
	eq(SpellKits.is_roster_class("pulse"), false, "pulse is not on the roster")
	eq(SpellKits.is_roster_class(""), false, "empty class is rejected")
	eq(SpellKits.class_spells("mender").size(), 5, "mender kit has five spells")
	eq(SpellKits.class_spells("gloam").size(), 5, "gloam kit has five spells")
	eq(SpellKits.class_spells("bastion").size(), 5, "bastion kit has five spells")
	eq(SpellKits.element_of("gloam"), "air", "gloam primary element is air")
	eq(SpellKits.element_of("mender"), "water", "mender primary element is water")
	eq(SpellKits.element_of("bastion"), "earth", "bastion primary element is earth")
	eq(SpellKits.UMBRAL_CAP, 4, "Umbral cap is 4")
	eq(SpellKits.SHADE_CAP, 2, "Shade cap is 2")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["ap"]), 4, "Ambush costs 4 AP")
	eq(int(SpellKits.spell(SpellKits.AMBUSH)["base_damage"]), 22, "Ambush damage is 22")
	eq(int(SpellKits.spell(SpellKits.AEGIS_BREAK)["base_damage"]), 26, "Aegis Break damage is 26")
	eq(SpellKits.is_gated(SpellKits.NIGHTFOLD), true, "Nightfold stays gated")
	var advance: Dictionary = SpellKits.spell(SpellKits.ADVANCE)
	eq(int(advance.get("ap", -1)), 3, "Advance stays 3 AP")
	eq(int(advance.get("mp", -1)), 0, "Advance stays 0 MP")
	eq(str(advance.get("range_mode", "")), "cardinal", "Advance stays cardinal")
	eq(int(advance.get("min_range", -1)), 2, "Advance min range is exactly 2")
	eq(int(advance.get("max_range", -1)), 2, "Advance max range is exactly 2")


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
		var dx := absi(cell.x - 3)
		var dy := absi(cell.y - 3)
		eq(dx + dy, 2, "Advance dest %s is Manhattan 2" % cell)
		eq(dx == 0 or dy == 0, true, "Advance dest %s is cardinal" % cell)
	var cast: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 3), "seat": 0})
	eq(bool(cast.get("ok", false)), true, "cardinal Advance resolves")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 3, "Advance spends 3 AP")
	eq(int(_sim.snapshot()["units"][0]["mp"]), 3, "Advance spends 0 MP")
	eq(_sim.snapshot()["units"][0]["pos"], Vector2i(5, 3), "Advance snaps two tiles east")


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
	eq(SpellKits.spell(SpellKits.AMBUSH).is_empty(), false, "Ambush has a Locked cost table")
	eq(SpellKits.spell(SpellKits.AEGIS_BREAK).is_empty(), false, "Aegis Break has a Locked cost table")
	eq(kits.contains("open_can_wait"), true, "open_can_wait stays named")
	eq(sim_src.contains("backend_pending"), false, "card spells are resolved, not backend_pending")
	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	eq(net_src.contains("func rpc_select_class"), true, "rpc_select_class stays")
	eq(net_src.contains("func rpc_class_result"), true, "rpc_class_result is the class reply")
	eq(net_src.contains("func rpc_enqueue"), true, "rpc_enqueue is the queue entry")
	eq(net_src.contains("func rpc_queue_result"), true, "rpc_queue_result is the queue reply")
	eq(net_src.contains("func rpc_match_assigned"), true, "rpc_match_assigned assigns the match")
	eq(net_src.contains("rpc_enter_matchmaking"), false, "queue RPC is rpc_enqueue")
	eq(net_src.contains("rpc_match_found"), false, "match RPC is rpc_match_assigned")
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
	eq(sim.snapshot()["units"][0]["spells"], SpellKits.class_spells("gloam"), "gloam seat uses the gloam kit")
	eq(sim.snapshot()["units"][1]["spells"], SpellKits.class_spells("bastion"), "bastion seat uses the bastion kit")
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
		eq(int(unit["mastery"]), 0, "%s mastery is 0" % class_id)
		eq(int(unit["resist"]), 0, "%s resist is 0" % class_id)
		eq(unit.has("pulse"), true, "%s snapshot has pulse" % class_id)
		eq(unit.has("umbral"), true, "%s snapshot has umbral" % class_id)
		eq(unit.has("shades"), true, "%s snapshot has shades" % class_id)
		eq(unit.has("aegis"), true, "%s snapshot has aegis" % class_id)
		var resources: Dictionary = unit.get("resources", {})
		eq(int(resources.get("pulse", -1)), int(unit["pulse"]), "%s resources.pulse matches the field" % class_id)
		eq(int(resources.get("umbral", -1)), int(unit["umbral"]), "%s resources.umbral matches the field" % class_id)
		eq(int(resources.get("shades", -1)), int(unit["shades"]), "%s resources.shades matches the field" % class_id)
		eq(int(resources.get("aegis", -1)), int(unit["aegis"]), "%s resources.aegis matches the field" % class_id)


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
		"positions": [Vector2i(2, 2), Vector2i(4, 2)],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"gloam_invisible": true,
		"rolls": [100],
	})
	var before: Vector2i = snap["units"][0]["pos"]
	var shades_before := int(snap["units"][0]["shades"])
	eq(shades_before >= 1, true, "Shade setup places a token")
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(4, 2), "seat": 0})
	eq(bool(missed.get("ok", false)), true, "Ambush miss resolves")
	var actor: Dictionary = _sim.snapshot()["units"][0]
	eq(actor["pos"], before, "Ambush miss does not teleport")
	eq(bool(actor["shade"]), true, "Ambush miss keeps Shade")
	eq(int(actor["shades"]), shades_before, "Ambush miss does not spend a Shade token")
	eq(bool(actor["invisible"]), true, "Ambush miss keeps Invisible")
	eq(int(actor["ap"]), 2, "Ambush miss spends 4 AP")
	eq(int(actor["mp"]), 3, "Ambush miss does not spend MP")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 80, "Ambush miss deals no damage")


func _test_ambush_hit() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(2, 2), Vector2i(4, 2)],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"gloam_shade": true,
		"rolls": [1],
	})
	var shades_before := int(_sim.snapshot()["units"][0]["shades"])
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(4, 2), "seat": 0})
	eq(bool(hit.get("ok", false)), true, "Invisible Ambush hit resolves")
	var actor: Dictionary = _sim.snapshot()["units"][0]
	eq(actor["pos"], Vector2i(5, 2), "Ambush lands on the empty back cell")
	eq(int(actor["shades"]), shades_before, "Invisible origin does not spend Shade")
	eq(bool(actor["invisible"]), true, "Ambush hit keeps Invisible")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 50, "true back is 22 × 1.35 = 30")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(2, 4), Vector2i(4, 2)],
		"kestrel_facing": "W",
		"rolls": [1],
		"blockers": [Vector2i(5, 2)],
	})
	eq(_sim.chebyshev(Vector2i(2, 4), Vector2i(2, 2)), 2, "blocked-back plant is Chebyshev 2 from Gloam")
	eq(_sim.is_cardinal_exact(Vector2i(2, 2), Vector2i(4, 2), 2), true, "blocked-back plant is Manhattan 2 cardinal from the prey")
	var planted_block: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 2), "seat": 0})
	eq(bool(planted_block.get("ok", false)), true, "blocked-back fixture plants a Shade Manhattan 2 cardinal from the prey")
	_sim.submit({"type": "end_turn", "seat": 0})
	_sim.submit({"type": "end_turn", "seat": 1})
	var shades_blocked := int(_sim.snapshot()["units"][0]["shades"])
	var ap_blocked := int(_sim.snapshot()["units"][0]["ap"])
	var blocked: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(4, 2), "seat": 0})
	eq(bool(blocked.get("illegal", false)), true, "blocked back is an illegal Ambush")
	eq(str(blocked.get("reason", "")), "illegal_back", "blocked back refunds")
	eq(_sim.snapshot()["units"][0]["pos"], Vector2i(2, 4), "blocked back does not move onto an adjacent cell")
	eq(int(_sim.snapshot()["units"][0]["shades"]), shades_blocked, "blocked back does not spend Shade")
	eq(int(_sim.snapshot()["units"][0]["ap"]), ap_blocked, "blocked back refunds AP")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 80, "blocked back deals no damage")
	var bare: Dictionary = _sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(2, 2), Vector2i(4, 2)],
	})
	var rejected: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(4, 2), "seat": 0})
	eq(str(rejected.get("reason", "")), "no_shade", "Ambush without Shade or Invisible is rejected")
	eq(int(_sim.snapshot()["units"][0]["ap"]), int(bare["units"][0]["ap"]), "no_shade does not spend AP")


func _test_aegis_break() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"kestrel_marks": 3,
		"bastion_aegis": 4,
		"rolls": [1],
	})
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(bool(hit.get("ok", false)), true, "Aegis Break hit resolves")
	var caster: Dictionary = _sim.snapshot()["units"][0]
	var victim: Dictionary = _sim.snapshot()["units"][1]
	eq(int(caster["aegis"]), 0, "HIT clears all Aegis on the caster")
	eq(int(caster["ap"]), 2, "Aegis Break spends 4 AP")
	eq(int(victim["hp"]), 54, "Aegis Break hit is 26")
	eq(victim["pos"], Vector2i(4, 1), "Aegis Break pushes 1")
	eq(int(victim["marks"]), 3, "HIT does not clear Marks")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"bastion_aegis": 4,
		"rolls": [1],
	})
	var second: Dictionary = _sim._make_unit(1, "kestrel", "Second", "air", Vector2i(1, 3), "N", true)
	var outside: Dictionary = _sim._make_unit(1, "kestrel", "Outside", "air", Vector2i(4, 2), "W", true)
	_sim._units.append(second)
	_sim._units.append(outside)
	var burst: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(bool(burst.get("ok", false)), true, "Aegis Break burst hit resolves")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 0, "burst HIT clears all Aegis once")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 54, "aimed body takes 26")
	eq(_sim.snapshot()["units"][1]["pos"], Vector2i(4, 1), "aimed body is pushed 1")
	eq(int(second["hp"]), 54, "second body in range 1–2 takes 26")
	eq(second["pos"], Vector2i(1, 4), "second body is pushed 1")
	eq(int(outside["hp"]), 80, "a body outside range 1–2 takes no damage")
	eq(outside["pos"], Vector2i(4, 2), "a body outside range 1–2 is not pushed")
	var burst_hit: Dictionary = {}
	for event in burst.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "hit":
			burst_hit = event
	eq(int(burst_hit.get("bodies", 0)), 2, "Aegis Break hit counts both bodies")
	var burst_rows: Array = burst_hit.get("targets", [])
	eq(burst_rows.size(), 2, "Aegis Break hit lists each body")
	eq(int(burst_rows[0].get("damage", -1)), 26, "first burst row is 26")
	eq(int(burst_rows[1].get("damage", -1)), 26, "second burst row is 26")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"bastion_aegis": 4,
		"rolls": [100],
	})
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(bool(missed.get("ok", false)), true, "Aegis Break miss resolves")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 4, "MISS spends 0 Aegis")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 2, "MISS still spends 4 AP")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 80, "MISS deals no damage")
	eq(_sim.snapshot()["units"][1]["pos"], Vector2i(3, 1), "MISS does not push")
	var miss_event: Dictionary = {}
	for event in missed.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "miss":
			miss_event = event
	eq(int(miss_event.get("aegis_spent", -1)), 0, "MISS event spends 0 Aegis")
	eq(bool(miss_event.get("stacks_cleared", true)), false, "MISS does not clear Aegis")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"kestrel_invisible": true,
		"bastion_aegis": 4,
		"rolls": [1],
	})
	var hidden: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(str(hidden.get("reason", "")), "open_can_wait", "Aegis Break versus Invisible stays open")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 4, "open AoE does not clear Aegis")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 6, "open AoE does not spend AP")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"bastion_aegis": 2,
	})
	var gated: Dictionary = _sim.submit({"type": "cast", "spell": "aegis_break", "to": Vector2i(3, 1), "seat": 0})
	eq(str(gated.get("reason", "")), "insufficient_aegis", "Aegis Break requires 3 Aegis")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 6, "failed gate does not spend AP")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 2, "failed gate does not spend Aegis")


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


func _test_snap_wall_cast() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"bastion_aegis": 2,
	})
	var casted: Dictionary = _sim.submit({"type": "cast", "spell": "snap_wall", "to": Vector2i(2, 1), "seat": 0})
	eq(bool(casted.get("ok", false)), true, "Snap Wall places without a roll")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 5, "Snap Wall costs 1 AP")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 0, "Snap Wall spends 2 Aegis")
	var tiles: Array = _sim.snapshot()["blocked_tiles"]
	eq(tiles.size(), 1, "blocked_tiles lists the Snap Wall")
	eq(tiles[0]["pos"], Vector2i(2, 1), "blocked_tiles pos is the wall cell")
	eq(int(tiles[0]["x"]), 2, "blocked_tiles x is readable without a pos key")
	eq(int(tiles[0]["y"]), 1, "blocked_tiles y is readable without a pos key")
	eq(int(tiles[0]["turns"]), 2, "Snap Wall lasts 2 turns")
	var painted := false
	for event in casted.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "walls":
			eq(false, true, "Snap Wall event type is snap_wall")
		if str(event.get("type", "")) == "snap_wall" and event.get("to") == Vector2i(2, 1):
			painted = true
	eq(painted, true, "Snap Wall emits type snap_wall")
	eq(_move_offered(0, Vector2i(2, 1)), false, "Snap Wall blocks walk")
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 2, "enemy turn-start does not tick Snap Wall")
	eq(_sim.snapshot()["blocked_tiles"].size(), 1, "Snap Wall survives the enemy turn")
	_sim.submit({"type": "end_turn", "seat": 1})
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 1, "first Bastion turn-start ticks 2 to 1")
	eq(_move_offered(0, Vector2i(2, 1)), false, "wall still blocks after one Bastion turn-start")
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 1, "a later enemy turn still does not tick Snap Wall")
	_sim.submit({"type": "end_turn", "seat": 1})
	eq(_sim.snapshot()["blocked_tiles"].size(), 0, "wall expires on the second Bastion turn-start")
	eq(_move_offered(0, Vector2i(2, 1)), true, "expired wall is walkable again")


func _test_nightfold_is_gated() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"gloam_shade": true,
		"gloam_umbral": 2,
	})
	var offered := false
	for intent in _sim.legal_intents(0):
		if typeof(intent) == TYPE_DICTIONARY and str(intent.get("spell", "")) == "nightfold":
			offered = true
	eq(offered, false, "Nightfold is not a legal intent")
	var rejected: Dictionary = _sim.submit({"type": "cast", "spell": "nightfold", "to": Vector2i(3, 1), "seat": 0})
	eq(str(rejected.get("reason", "")), "open_can_wait", "Nightfold submit is open_can_wait")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 6, "gated Nightfold does not spend AP")
	eq(int(_sim.snapshot()["units"][0]["umbral"]), 2, "gated Nightfold does not clear Umbral")


func _test_mender_heals_and_ward() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 31,
		"rolls": [1],
	})
	var mend: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	eq(bool(mend.get("ok", false)), true, "Mend hits an ally")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 51, "Triage heals 16 × 1.25 below 40% HP")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 1, "Mend gains 1 Pulse")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 3, "Mend costs 3 AP")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_pulse": 2,
		"rolls": [1, 1],
	})
	var ward: Dictionary = _sim.submit({"type": "cast", "spell": "ward", "to": Vector2i(1, 1), "seat": 0})
	eq(bool(ward.get("ok", false)), true, "Ward connects")
	eq(int(_sim.snapshot()["units"][0]["shield"]), 20, "Ward shield is 20, not the open 24 rider")
	eq(int(_sim.snapshot()["units"][0]["shield_turns"]), 2, "Ward lasts 2 turns")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 0, "Ward spends 2 Pulse on connect")
	var stacked: Dictionary = _sim.submit({"type": "cast", "spell": "ward", "to": Vector2i(1, 1), "seat": 0})
	eq(str(stacked.get("reason", "")), "open_can_wait", "a second Ward does not stack or overwrite")
	eq(int(_sim.snapshot()["units"][0]["shield"]), 20, "rejected Ward leaves the 20 shield")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 3, "rejected Ward does not spend AP")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"rolls": [100],
	})
	var cleanse: Dictionary = _sim.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(1, 1), "seat": 0})
	eq(bool(cleanse.get("ok", false)), true, "Cleanse does not roll")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 1, "Cleanse gains 1 Pulse with no CC")
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	eq(bool(missed.get("ok", false)), true, "Mend miss still resolves")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "Mend miss does not heal")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 1, "Mend miss does not gain Pulse")


func _test_shades_cap_and_fade() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	eq(bool(_sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 1), "seat": 0}).get("ok", false)), true, "first Shade places")
	eq(bool(_sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 2), "seat": 0}).get("ok", false)), true, "second Shade places")
	var capped: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(3, 1), "seat": 0})
	eq(str(capped.get("reason", "")), "shade_cap", "third Shade is rejected")
	eq(int(_sim.snapshot()["units"][0]["shades"]), 2, "Shade count stays at 2")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 4, "rejected Shade does not spend AP")
	var fade: Dictionary = _sim.submit({"type": "cast", "spell": "fade", "to": Vector2i(1, 1), "seat": 0})
	eq(bool(fade.get("ok", false)), true, "Fade resolves")
	eq(bool(_sim.snapshot()["units"][0]["invisible"]), true, "Fade sets Invisible")
	eq(int(_sim.snapshot()["units"][0]["umbral"]), 1, "Fade gains 1 Umbral")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 2, "Fade costs 2 AP")
	eq(int(_sim.snapshot()["units"][0]["mp"]), 2, "Fade costs 1 MP")


func _test_hold_line_exit_tax() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(2, 1)],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "hold_line", "to": Vector2i(2, 1), "seat": 0})
	eq(bool(hit.get("ok", false)), true, "Hold Line hits the front cone")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 73, "Hold Line is 7 per body")
	eq(int(_sim.snapshot()["units"][1]["exit_tax"]), 1, "Hold Line applies a 1-turn exit tax")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 1, "Hold Line gains 1 Aegis on connect")
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(_move_offered(1, Vector2i(5, 1)), false, "exit tax shortens the walk budget by 1")
	eq(_move_offered(1, Vector2i(4, 1)), true, "a shorter walk stays legal")
	var walked: Dictionary = _sim.submit({"type": "move", "to": Vector2i(4, 1), "seat": 1})
	eq(bool(walked.get("ok", false)), true, "taxed walk resolves")
	eq(int(_sim.snapshot()["units"][1]["mp"]), 0, "exit tax spends path cost + 1")


func _test_heartstop() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"mender_pulse": 4,
		"rolls": [1],
	})
	var enemy: Dictionary = _sim.submit({"type": "cast", "spell": "heartstop", "to": Vector2i(3, 1), "seat": 0})
	eq(bool(enemy.get("ok", false)), true, "enemy Heartstop hits")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 70, "enemy Heartstop damage is 10")
	eq(bool(_sim.snapshot()["units"][1]["skip_next_mp"]), true, "enemy Heartstop skips the next MP refill")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 0, "Heartstop spends 4 Pulse")
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(int(_sim.snapshot()["units"][1]["mp"]), 0, "skipped refill sets MP to 0")
	eq(int(_sim.snapshot()["units"][1]["ap"]), 6, "skipped refill still refills AP")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_pulse": 4,
		"mender_hit_immunity": 1,
	})
	var again: Dictionary = _sim.submit({"type": "cast", "spell": "heartstop", "to": Vector2i(1, 1), "seat": 0})
	eq(str(again.get("reason", "")), "open_can_wait", "immunity refresh is open_can_wait")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 6, "gated Heartstop does not spend AP")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 4, "gated Heartstop does not spend Pulse")


func _test_gloam_backstab() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(2, 2), Vector2i(3, 2)],
		"rolls": [1],
	})
	var cut: Dictionary = _sim.submit({"type": "cast", "spell": "cut", "to": Vector2i(3, 2), "seat": 0})
	eq(bool(cut.get("ok", false)), true, "Cut hits")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 62, "Gloam backstab is 13 × 1.35 = 18")
	eq(int(_sim.snapshot()["units"][0]["umbral"]), 1, "Cut gains 1 Umbral")


func _move_offered(seat: int, cell: Vector2i) -> bool:
	for intent in _sim.legal_intents(seat):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) == "move" and intent.get("to") == cell:
			return true
	return false


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1
