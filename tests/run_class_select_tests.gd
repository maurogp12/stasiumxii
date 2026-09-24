extends SceneTree

## SELECT_CLASS stub: server validates the five-id Locked roster, queue starts
## the duel, kit chrome follows units[].class_id. Hot-seat roster stays the default.
## mender / gloam / bastion have no kit rows, so the bar stays empty.
## Run: godot --headless --path . -s res://tests/run_class_select_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Class-select tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_source_contract()
	_test_server_rejects_invalid_class()
	_test_five_class_roster_empty_kits()
	_test_blocked_tiles_chrome()
	_test_opposite_classes_queue_into_kits()
	_test_same_class_is_allowed()
	_test_hotseat_roster_unchanged()
	_test_client_does_not_apply_class()
	_test_listen_host_skips_class_select()
	_test_hud_kit_follows_class_id()


func _test_source_contract() -> void:
	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	truthy(net_src.contains("func select_class(class_id: String)"), "select_class keeps the studio signature")
	truthy(net_src.contains("signal class_selected(class_id: String)"), "class_selected signal is named")
	truthy(net_src.contains("signal class_rejected(reason: String, class_id: String)"), "reject signal carries reason and class_id")
	truthy(net_src.contains("func enter_matchmaking()"), "enter_matchmaking is the queue entry")
	truthy(net_src.contains("rpc_select_class"), "client select goes through rpc_select_class")
	truthy(net_src.contains("rpc_enter_matchmaking"), "queue goes through rpc_enter_matchmaking")
	truthy(net_src.contains("seat_classes"), "match start passes seat_classes")
	eq(net_src.contains("Gloam"), false, "net_session does not hardcode a display name")
	eq(net_src.contains("Mender"), false, "net_session does not hardcode Mender")
	eq(net_src.contains("Bastion"), false, "net_session does not hardcode Bastion")
	truthy(net_src.contains("mender, gloam, bastion"), "net_session allowlist comment lists the new ids")
	var chrome := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	truthy(chrome.contains("select_class"), "class select calls select_class")
	truthy(chrome.contains("enter_matchmaking"), "Find Match calls enter_matchmaking")
	truthy(chrome.contains("Find Match"), "chrome has a Find Match control")
	truthy(chrome.contains("class_rejected"), "chrome shows a server reject")
	truthy(chrome.contains("LOCKED_ROSTER"), "class select paints the Locked roster")
	truthy(chrome.contains("Kestrel, Ironjaw, Mender, Gloam, Bastion"), "class select shows the five display names")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(SpellKits.LOCKED_ROSTER, ["kestrel", "ironjaw", "mender", "gloam", "bastion"], "roster ids are the five lowercase classes")
	eq(SpellKits.class_label("mender"), "Mender", "mender display name")
	eq(SpellKits.class_label("gloam"), "Gloam", "gloam display name")
	eq(SpellKits.class_label("bastion"), "Bastion", "bastion display name")
	eq(SpellKits.class_element_text("mender"), "Water/Water", "mender element pair is the card")
	eq(SpellKits.class_element_text("gloam"), "Air/Neutral", "gloam element pair is the card")
	eq(SpellKits.class_element_text("bastion"), "Earth/Earth", "bastion element pair is the card")
	eq(SpellKits.class_spells("mender"), ["mend", "pulse_tap", "ward", "cleanse", "heartstop"], "mender spell ids match the card")
	eq(SpellKits.class_spells("gloam"), ["cut", "drop_shade", "ambush", "fade", "nightfold"], "gloam spell ids match the card")
	eq(SpellKits.class_spells("bastion"), ["bash", "plant", "hold_line", "snap_wall", "aegis_break"], "bastion spell ids match the card")
	eq(int(SpellKits.spell("heartstop").get("enemy_base_damage", -1)), 10, "Heartstop enemy base is 10")
	eq(int(SpellKits.spell("ambush").get("card_damage", -1)), 22, "Ambush card damage is 22")
	eq(int(SpellKits.spell("ambush").get("min_range", -1)), 1, "Ambush min range is 1")
	eq(int(SpellKits.spell("ambush").get("max_range", -1)), 4, "Ambush max range is 4")
	eq(int(SpellKits.spell("aegis_break").get("card_damage", -1)), 26, "Aegis Break card damage is 26")
	eq(int(SpellKits.spell("aegis_break").get("miss_spend", -1)), 0, "Aegis Break miss spend is 0")
	eq(int(SpellKits.spell("snap_wall").get("blocked_tiles", -1)), 1, "Snap Wall is one tile")
	eq(int(SpellKits.spell("snap_wall").get("blocked_turns", -1)), 2, "Snap Wall lasts 2 turns")
	eq(int(SpellKits.class_resources("mender")[0]["max"]), 6, "Pulse cap is 6")
	eq(int(SpellKits.class_resources("gloam")[0]["max"]), 4, "Umbral cap is 4")
	eq(int(SpellKits.class_resources("gloam")[1]["max"]), 2, "Shades cap is 2")
	eq(int(SpellKits.class_resources("bastion")[0]["max"]), 4, "Aegis cap is 4")
	eq(int(SpellKits.class_proto("mender")["hp"]), 80, "proto HP is 80")
	eq(int(SpellKits.class_proto("gloam")["mastery"]), 0, "proto mastery is 0")
	eq(int(SpellKits.class_proto("bastion")["resist"]), 0, "proto resist is 0")
	eq(float(SpellKits.class_passive("gloam")["mult"]), 1.35, "Backstab multiplier is stored")
	eq(sim_src.contains("nightfold"), false, "CombatSim does not resolve Nightfold")
	eq(sim_src.contains("triage"), false, "CombatSim does not resolve Triage")
	eq(sim_src.contains("intercept"), false, "CombatSim does not resolve Intercept")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud_src.contains("Pulse"), false, "HUD reads resource labels from the card table")
	var lobby := FileAccess.get_file_as_string("res://scenes/online_lobby.gd")
	eq(lobby.contains("matchmaking"), false, "lobby scene does not own the queue")
	eq(lobby.contains("auth"), false, "lobby does not invent auth")
	eq(sim_src.contains("dedicated"), false, "CombatSim does not invent a dedicated server")


func _test_server_rejects_invalid_class() -> void:
	var dedicated := _dedicated()
	var reasons: Array[String] = []
	dedicated.class_rejected.connect(func(reason: String, _class_id: String) -> void:
		reasons.append(reason)
	)
	for bad in ["pulse", "", "  Pulse  ", "warden"]:
		var result: Dictionary = dedicated.select_class_for_seat(0, bad)
		eq(bool(result.get("ok", true)), false, "server rejects %s" % bad)
		eq(str(result.get("reason", "")), "invalid_class", "reject reason is invalid_class for %s" % bad)
	truthy(reasons.has("invalid_class"), "class_rejected fires for an invalid class")
	var early: Dictionary = dedicated.enter_matchmaking_for_seat(0)
	eq(str(early.get("reason", "")), "class_not_confirmed", "queue before confirm is class_not_confirmed")
	eq(dedicated.match_assigned(), false, "invalid picks do not start a match")
	_free_dedicated(dedicated)


func _test_five_class_roster_empty_kits() -> void:
	var dedicated := _dedicated()
	eq(bool(dedicated.select_class_for_seat(0, "Mender").get("ok", false)), true, "seat 0 mender is accepted")
	eq(bool(dedicated.select_class_for_seat(1, "bastion").get("ok", false)), true, "seat 1 bastion is accepted")
	eq(str(dedicated.select_class_for_seat(0, "gloam").get("class_id", "")), "gloam", "gloam normalizes and replaces before queue")
	dedicated.select_class_for_seat(0, "mender")
	dedicated.enter_matchmaking_for_seat(0)
	dedicated.enter_matchmaking_for_seat(1)
	dedicated.reset_match({"fixture": true, "skip_deploy": true, "flat_board": true, "seed": 9})
	var snap: Dictionary = dedicated.snapshot()
	var units: Array = snap["units"]
	eq(str(units[0]["class_id"]), "mender", "seat 0 class_id is mender")
	eq(str(units[1]["class_id"]), "bastion", "seat 1 class_id is bastion")
	eq(str(units[0]["name"]), "Mender", "seat 0 name is the display label")
	eq(int(units[0]["hp"]), 80, "mender HP comes from the snapshot")
	eq(int(units[0]["max_hp"]), 80, "mender max HP is the sim start value")
	eq(units[0]["spells"], ["mend", "pulse_tap", "ward", "cleanse", "heartstop"], "mender spells are the card ids")
	eq(units[1]["spells"], ["bash", "plant", "hold_line", "snap_wall", "aegis_break"], "bastion spells are the card ids")
	eq(str(units[0]["element"]), "Water/Water", "mender element is the card pair")
	var stuffed: Dictionary = units[0].duplicate(true)
	stuffed["spells"] = ["mark_shot", "advance"]
	eq(CombatHUD.offered_cast_ids(stuffed), [], "card kit drops spell ids that are not on the card")
	eq(CombatHUD.offered_cast_ids(units[0]), ["mend", "pulse_tap", "ward", "cleanse", "heartstop"], "mender bar uses card ids")
	eq(CombatHUD.offered_cast_ids(units[1]), ["bash", "plant", "hold_line", "snap_wall", "aegis_break"], "bastion bar uses card ids")
	snap["local_seat"] = 0
	var hud := CombatHUD.new()
	hud._build()
	hud.render(snap, [])
	eq(hud._banner_titles[0].text, "Mender", "seat 0 banner is Mender")
	eq(hud._banner_titles[1].text, "Bastion", "seat 1 banner is Bastion")
	eq(hud._spell_buttons.has("mend"), true, "Mend button id is the card id")
	eq(hud._spell_buttons.has("heartstop"), true, "Heartstop button id is the card id")
	eq(hud._spell_buttons.has("mark_shot"), false, "mender bar does not show the kestrel kit")
	eq(hud._empty_kit_button.visible, false, "a card kit hides the empty slot")
	eq(str(hud._spell_buttons["mend"].text).begins_with("Mend"), true, "Mend button uses the card name")
	eq(hud._spell_buttons["mend"].disabled, false, "card spell can be selected so the Intent carries the id")
	var card := hud._kestrel_body.text
	truthy(card.contains("HP 80/80"), "card prints snapshot HP")
	truthy(card.contains("Pulse 0/6"), "Pulse meter uses the card cap")
	truthy(card.contains("Mastery 0"), "proto mastery is 0")
	truthy(card.contains("Resist 0"), "proto resist is 0")
	eq(card.contains("Marks"), false, "mender card does not invent Marks")
	eq(card.contains("Impact"), false, "mender card does not invent Impact")
	var with_pulse: Dictionary = units[0].duplicate(true)
	with_pulse["pulse"] = 2
	var pulse_card := hud._unit_card_text(with_pulse, true, snap)
	truthy(pulse_card.contains("Pulse 2/6"), "Pulse current comes from the snapshot")
	snap["local_seat"] = 1
	hud.render(snap, [])
	var bastion_card := hud._ironjaw_body.text
	truthy(bastion_card.contains("Aegis 0/4"), "Aegis meter uses the card cap")
	eq(hud._spell_buttons.has("snap_wall"), true, "Snap Wall button id is the card id")
	var gloam_unit: Dictionary = units[0].duplicate(true)
	gloam_unit["class_id"] = "gloam"
	gloam_unit["spells"] = SpellKits.class_spells("gloam")
	var gloam_card := hud._unit_card_text(gloam_unit, true, snap)
	truthy(gloam_card.contains("Umbral 0/4"), "Umbral meter uses the card cap")
	truthy(gloam_card.contains("Shades 0/2"), "Shades meter uses the card cap")
	var hp_before := int(units[1]["hp"])
	var ap_before := int(units[0]["ap"])
	var cast: Dictionary = dedicated.sim().submit({"type": "cast", "spell": "mend", "to": units[1]["pos"]})
	eq(bool(cast.get("ok", true)), false, "mender cast is not resolved here")
	eq(str(cast.get("reason", "")), "backend_pending", "Backend must validate the card spell")
	eq(int(dedicated.sim().snapshot()["units"][1]["hp"]), hp_before, "rejected Mend does not change HP")
	eq(int(dedicated.sim().snapshot()["units"][0]["ap"]), ap_before, "rejected Mend does not spend AP")
	var preview: Dictionary = dedicated.sim().preview_cast("heartstop")
	eq(str(preview.get("reason", "")), "backend_pending", "preview does not sample a card spell")
	eq(preview.get("sample_damage", 1), null, "preview has no invented sample")
	hud.free()
	_free_dedicated(dedicated)


func _test_blocked_tiles_chrome() -> void:
	var cells := SnapshotTiles.blocked_cells({
		"blocked_tiles": [Vector2i(2, 3), {"x": 1, "y": 1}, [4, 5], "3,4"],
		"walls": [Vector2i(7, 0)],
		"last_events": [
			{"type": "snap_wall", "to": Vector2i(6, 6)},
			{"type": "snap_wall", "cells": [[0, 7]]},
			{"type": "hit", "to": Vector2i(3, 3)},
		],
	})
	eq(cells.has(Vector2i(2, 3)), true, "blocked_tiles Vector2i is painted")
	eq(cells.has(Vector2i(1, 1)), true, "blocked_tiles dict cell is painted")
	eq(cells.has(Vector2i(4, 5)), true, "blocked_tiles array cell is painted")
	eq(cells.has(Vector2i(3, 4)), true, "blocked_tiles string cell is painted")
	eq(cells.has(Vector2i(6, 6)), true, "snap_wall to is painted")
	eq(cells.has(Vector2i(0, 7)), true, "snap_wall cells are painted")
	eq(cells.has(Vector2i(7, 0)), false, "walls is not a bound snapshot key")
	eq(cells.has(Vector2i(3, 3)), false, "non-snap_wall events are not walls")
	eq(SnapshotTiles.blocked_cells({}).is_empty(), true, "a snapshot without the key paints nothing")
	var tile := BoardTile.new()
	tile.highlight = "blocked"
	eq(tile.highlight, "blocked", "tile highlight kind blocked is the wall chrome")
	tile.free()


func _test_opposite_classes_queue_into_kits() -> void:
	var dedicated := _dedicated()
	var brain: Node = dedicated.sim()
	var picked0: Dictionary = dedicated.select_class_for_seat(0, "Ironjaw")
	var picked1: Dictionary = dedicated.select_class_for_seat(1, "kestrel")
	eq(bool(picked0.get("ok", false)), true, "seat 0 Ironjaw is accepted")
	eq(str(picked0.get("class_id", "")), "ironjaw", "class id is normalized")
	eq(bool(picked1.get("ok", false)), true, "seat 1 kestrel is accepted")
	var waiting: Dictionary = dedicated.enter_matchmaking_for_seat(0)
	eq(str(waiting.get("status", "")), "waiting", "first queue waits")
	eq(dedicated.match_assigned(), false, "one queued seat is not a match")
	var packed: Dictionary = IntentCodec.decode(dedicated.pack_result({
		"ok": true,
		"snapshot": brain.snapshot(),
	}, 0))
	var pre: Dictionary = packed["snapshot"]["prematch"]
	eq(str(pre.get("phase", "")), "MATCHMAKING", "queued viewer prematch phase is MATCHMAKING")
	eq(str(pre.get("local_class_id", "")), "ironjaw", "prematch local_class_id is the confirmed class")
	eq(bool(pre.get("local_queued", false)), true, "prematch local_queued is true")
	eq(bool(pre.get("match_live", true)), false, "prematch match_live stays false while waiting")
	eq(str(packed["snapshot"].get("server_mode", "")), "dedicated", "packet stamps server_mode")
	var started: Dictionary = dedicated.enter_matchmaking_for_seat(1)
	eq(str(started.get("status", "")), "matched", "second queue assigns the match")
	eq(dedicated.match_assigned(), true, "dedicated match_assigned after both queue")
	var units: Array = brain.snapshot()["units"]
	eq(str(units[0]["class_id"]), "ironjaw", "seat 0 unit class_id is ironjaw")
	eq(str(units[1]["class_id"]), "kestrel", "seat 1 unit class_id is kestrel")
	eq(str(units[0]["name"]), "Ironjaw", "seat 0 name follows class_id")
	eq(str(units[1]["name"]), "Kestrel", "seat 1 name follows class_id")
	eq(CombatHUD.offered_cast_ids(units[0]), ["advance", "strike", "shoulder", "crush"], "seat 0 kit is Ironjaw")
	eq(CombatHUD.offered_cast_ids(units[1]), ["mark_shot", "detonate"], "seat 1 kit is Kestrel")
	var locked: Dictionary = dedicated.select_class_for_seat(0, "kestrel")
	eq(str(locked.get("reason", "")), "already_queued", "class locks once the match is queued")
	dedicated.reset_match({})
	var again: Array = brain.snapshot()["units"]
	eq(str(again[0]["class_id"]), "ironjaw", "new match keeps seat 0 class_id")
	eq(str(again[1]["class_id"]), "kestrel", "new match keeps seat 1 class_id")
	var cell: Vector2i = _first_zone_cell(brain, 0)
	var placed: Dictionary = dedicated.submit_for_seat({"type": "place", "seat": 0, "to": cell}, 0)
	eq(bool(placed.get("ok", false)), true, "queued match still accepts a place Intent")
	_free_dedicated(dedicated)


func _test_same_class_is_allowed() -> void:
	var dedicated := _dedicated()
	eq(bool(dedicated.select_class_for_seat(0, "kestrel").get("ok", false)), true, "seat 0 kestrel accepted")
	eq(bool(dedicated.select_class_for_seat(1, "kestrel").get("ok", false)), true, "seat 1 may also pick kestrel")
	dedicated.enter_matchmaking_for_seat(0)
	dedicated.enter_matchmaking_for_seat(1)
	var units: Array = dedicated.sim().snapshot()["units"]
	eq(str(units[0]["class_id"]), "kestrel", "same-class seat 0 is kestrel")
	eq(str(units[1]["class_id"]), "kestrel", "same-class seat 1 is kestrel")
	eq(CombatHUD.offered_cast_ids(units[1]), ["mark_shot", "detonate"], "second kestrel still has the kestrel kit")
	_free_dedicated(dedicated)


func _test_hotseat_roster_unchanged() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var net_script := load("res://backend/net_session.gd")
	var sim: Node = sim_script.new()
	var hot: Node = net_script.new()
	hot.attach_sim(sim)
	eq(hot.is_hotseat(), true, "fresh session is hot-seat")
	eq(hot.awaiting_class_select(), false, "hot-seat does not wait on class select")
	sim.reset_match({})
	var units: Array = sim.snapshot()["units"]
	eq(str(units[0]["class_id"]), "kestrel", "hot-seat seat 0 stays kestrel")
	eq(str(units[1]["class_id"]), "ironjaw", "hot-seat seat 1 stays ironjaw")
	var moved: Dictionary = hot.submit({"type": "place", "seat": 0, "to": _first_zone_cell(sim, 0)})
	eq(bool(moved.get("ok", false)), true, "hot-seat still submits through CombatSim")
	hot.free()
	sim.free()


func _test_client_does_not_apply_class() -> void:
	var net_script := load("res://backend/net_session.gd")
	var client: Node = net_script.new()
	client.enter_client_unassigned()
	eq(client.awaiting_class_select(), true, "a client with no match waits on class select")
	var result: Dictionary = client.select_class("kestrel")
	eq(bool(result.get("ok", true)), false, "client without a seat does not accept locally")
	eq(str(result.get("reason", "")), "no_seat", "missing seat is no_seat")
	eq(str(client.confirmed_class_id), "", "client confirmed_class_id stays empty")
	client.enter_client_offline()
	var offline: Dictionary = client.select_class("ironjaw")
	eq(str(offline.get("reason", "")), "not_connected", "offline client does not apply ironjaw")
	eq(str(client.confirmed_class_id), "", "offline reject leaves confirmed_class_id empty")
	client.free()


func _test_listen_host_skips_class_select() -> void:
	var net_script := load("res://backend/net_session.gd")
	var sim_script := load("res://backend/combat_sim.gd")
	var brain: Node = sim_script.new()
	var host: Node = net_script.new()
	var guest: Node = net_script.new()
	host.attach_sim(brain)
	host.enter_host_offline()
	guest.enter_client_offline()
	host.reset_match({"seed": 1, "flat_board": true, "skip_deploy": true, "fixture": true})
	var units: Array = brain.snapshot()["units"]
	eq(str(units[0]["class_id"]), "kestrel", "listen-host default seat 0 is still kestrel")
	eq(str(units[1]["class_id"]), "ironjaw", "listen-host default seat 1 is still ironjaw")
	guest.apply_packed_state(host.pack_result({
		"ok": true,
		"events": [],
		"snapshot": brain.snapshot(),
	}, 1))
	eq(guest.awaiting_class_select(), false, "listen-host guest skips class select")
	eq(str(guest.server_mode()), "host", "guest keeps the authority server_mode")
	host.free()
	guest.free()
	brain.free()


func _test_hud_kit_follows_class_id() -> void:
	var dedicated := _dedicated()
	dedicated.select_class_for_seat(0, "ironjaw")
	dedicated.select_class_for_seat(1, "kestrel")
	dedicated.enter_matchmaking_for_seat(0)
	dedicated.enter_matchmaking_for_seat(1)
	dedicated.reset_match({
		"fixture": true,
		"skip_deploy": true,
		"flat_board": true,
		"seed": 4,
	})
	var snap: Dictionary = dedicated.snapshot()
	snap["local_seat"] = 0
	eq(CombatHUD.kit_seat(snap), 0, "kit seat is still local_seat")
	eq(CombatHUD.kit_class_id(snap), "ironjaw", "local seat 0 kit class is ironjaw")
	eq(CombatHUD.offered_cast_ids(CombatHUD.unit_for_seat(snap["units"], 0)), ["advance", "strike", "shoulder", "crush"], "HUD offers the ironjaw kit on seat 0")
	snap["local_seat"] = 1
	eq(CombatHUD.kit_class_id(snap), "kestrel", "local seat 1 kit class is kestrel")
	eq(CombatHUD.offered_cast_ids(CombatHUD.unit_for_seat(snap["units"], 1)), ["mark_shot", "detonate"], "HUD offers the kestrel kit on seat 1")
	var hud := CombatHUD.new()
	hud._build()
	var seat0_view: Dictionary = dedicated.snapshot()
	seat0_view["local_seat"] = 0
	hud.render(seat0_view, [])
	eq(hud._banner_titles[0].text, "Ironjaw", "seat 0 banner uses class_id")
	eq(hud._banner_titles[1].text, "Kestrel", "seat 1 banner uses class_id")
	eq(hud._spell_buttons.has("advance"), true, "action bar shows Advance for the local ironjaw")
	eq(hud._spell_buttons.has("mark_shot"), false, "action bar does not hard-code Kestrel spells onto seat 0")
	hud.free()
	_free_dedicated(dedicated)


func _dedicated() -> Node:
	var sim_script := load("res://backend/combat_sim.gd")
	var net_script := load("res://backend/net_session.gd")
	var brain: Node = sim_script.new()
	var dedicated: Node = net_script.new()
	dedicated.attach_sim(brain)
	dedicated.enter_dedicated_offline()
	dedicated.set_meta("class_select_brain", brain)
	return dedicated


func _free_dedicated(dedicated: Node) -> void:
	var brain: Node = dedicated.get_meta("class_select_brain")
	dedicated.free()
	brain.free()


func _first_zone_cell(sim: Node, seat: int) -> Vector2i:
	var cells: Array = sim.legal_deploy_cells(seat)
	if cells.is_empty():
		cells = sim.deploy_zone_cells(seat)
	if cells.is_empty():
		return Vector2i.ZERO
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
