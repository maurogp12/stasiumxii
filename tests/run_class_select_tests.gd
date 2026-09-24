extends SceneTree

## SELECT_CLASS chrome bound to the dedicated queue RPC contract.
## Allowlist is kestrel|ironjaw. Card chrome for the other three stays on the HUD.
## Run: godot --headless --path . -s res://tests/run_class_select_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Class-select tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_source_contract()
	_test_client_reject_chrome()
	_test_server_rejects_off_roster()
	_test_queue_pairs_roster_classes()
	_test_hud_card_chrome()
	_test_card_cast_stays_pending()
	_test_blocked_tiles_chrome()
	_test_hotseat_roster_unchanged()


func _test_source_contract() -> void:
	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	truthy(net_src.contains("func select_class(class_id: String)"), "select_class keeps the client signature")
	truthy(net_src.contains("rpc_select_class"), "client select goes through rpc_select_class")
	truthy(net_src.contains("rpc_class_result"), "class result is rpc_class_result")
	truthy(net_src.contains("rpc_enqueue"), "enqueue goes through rpc_enqueue")
	truthy(net_src.contains("rpc_queue_result"), "queue result is rpc_queue_result")
	truthy(net_src.contains("rpc_match_assigned"), "match assignment is rpc_match_assigned")
	truthy(net_src.contains("\"class_selected\""), "connection_changed emits class_selected")
	truthy(net_src.contains("\"class_rejected\""), "connection_changed emits class_rejected")
	truthy(net_src.contains("\"queued\""), "connection_changed emits queued")
	truthy(net_src.contains("\"queue_rejected\""), "connection_changed emits queue_rejected")
	truthy(net_src.contains("\"matched\""), "connection_changed emits matched")
	eq(net_src.contains("rpc_class_selected"), false, "rpc_class_selected is not a chrome RPC")
	eq(net_src.contains("rpc_class_rejected"), false, "rpc_class_rejected is not a chrome RPC")
	eq(net_src.contains("rpc_matchmaking_status"), false, "rpc_matchmaking_status is not a chrome RPC")
	eq(net_src.contains("rpc_match_found"), false, "rpc_match_found is not a chrome RPC")
	eq(net_src.contains("func enter_matchmaking"), false, "enter_matchmaking is not the queue entry")
	eq(net_src.contains("Gloam"), false, "net_session does not hardcode a display name")
	var chrome := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	truthy(chrome.contains("select_class"), "class select calls select_class")
	truthy(chrome.contains("Find Match"), "chrome has a Find Match control")
	truthy(chrome.contains("connection_changed"), "class select listens to connection_changed")
	truthy(chrome.contains("start_queue_client"), "Find Match joins the queue")
	eq(chrome.contains("enter_matchmaking"), false, "class select does not call enter_matchmaking")
	truthy(chrome.contains("Kestrel, Ironjaw, Mender, Gloam, Bastion"), "class select shows the five display names")
	var lobby := FileAccess.get_file_as_string("res://scenes/online_lobby.gd")
	truthy(lobby.contains("select_class"), "lobby calls select_class")
	truthy(lobby.contains("start_queue_client"), "lobby joins the queue")
	truthy(lobby.contains("class_rejected"), "lobby shows a server reject")
	eq(SpellKits.LOCKED_ROSTER, ["kestrel", "ironjaw"], "allowlist is the two roster classes")
	eq(SpellKits.CHROME_ROSTER, ["kestrel", "ironjaw", "mender", "gloam", "bastion"], "chrome still shows five classes")
	eq(SpellKits.is_roster_class("mender"), false, "mender waits on the allowlist")
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
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("nightfold"), false, "CombatSim does not resolve Nightfold")
	eq(sim_src.contains("triage"), false, "CombatSim does not resolve Triage")
	eq(sim_src.contains("intercept"), false, "CombatSim does not resolve Intercept")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud_src.contains("Pulse"), false, "HUD reads resource labels from the card table")


func _test_client_reject_chrome() -> void:
	var net_script := load("res://backend/net_session.gd")
	var client: Node = net_script.new()
	var statuses: Array[String] = []
	client.connection_changed.connect(func(status: String) -> void:
		statuses.append(status)
	)
	var rejected: Dictionary = client.select_class("mender")
	eq(bool(rejected.get("ok", true)), false, "client rejects mender before connect")
	eq(bool(rejected.get("illegal", false)), true, "reject is illegal")
	eq(str(rejected.get("reason", "")), "invalid_class", "reject reason is invalid_class")
	eq(client.selected_class_id, "", "rejected class is not stored")
	truthy(statuses.has("class_rejected"), "connection_changed emits class_rejected")
	var picked: Dictionary = client.select_class(" Ironjaw ")
	eq(bool(picked.get("ok", false)), true, "ironjaw confirms locally")
	eq(str(picked.get("class_id", "")), "ironjaw", "class id is normalized")
	eq(client.selected_class_id, "ironjaw", "confirmed class is stored before connect")
	client.free()


func _test_server_rejects_off_roster() -> void:
	var dedicated := _dedicated()
	for bad in ["mender", "gloam", "bastion", "pulse", ""]:
		var result: Dictionary = dedicated.server_select_class("p1", bad)
		eq(bool(result.get("ok", true)), false, "server rejects %s" % bad)
		eq(str(result.get("reason", "")), "invalid_class", "server reason is invalid_class for %s" % bad)
		eq(dedicated.server_session("p1").is_empty(), true, "rejected class is not stored for %s" % bad)
	var early: Dictionary = dedicated.server_enqueue("p1")
	eq(str(early.get("reason", "")), "class_required", "queue before confirm is class_required")
	eq(dedicated.matched, false, "invalid picks do not start a match")
	_free_dedicated(dedicated)


func _test_queue_pairs_roster_classes() -> void:
	var dedicated := _dedicated()
	eq(bool(dedicated.server_select_class("a", "ironjaw").get("ok", false)), true, "seat order starts with ironjaw")
	var waiting: Dictionary = dedicated.server_enqueue("a")
	eq(bool(waiting.get("queued", false)), true, "first player is queued")
	eq(bool(waiting.get("matched", true)), false, "one player does not start a match")
	dedicated.server_select_class("b", "kestrel")
	var paired: Dictionary = dedicated.server_enqueue("b")
	eq(bool(paired.get("matched", false)), true, "second confirmed player pairs")
	eq(dedicated.matched, true, "host records the match")
	var units: Array = dedicated.sim().snapshot()["units"]
	eq(str(units[0]["class_id"]), "ironjaw", "seat 0 is the first queued class")
	eq(str(units[1]["class_id"]), "kestrel", "seat 1 is the second queued class")
	eq(CombatHUD.offered_cast_ids(units[0]), ["advance", "strike", "shoulder", "crush"], "seat 0 kit is Ironjaw")
	eq(CombatHUD.offered_cast_ids(units[1]), ["mark_shot", "detonate"], "seat 1 kit is Kestrel")
	var payload := {
		"seat": 0,
		"class_id": "ironjaw",
		"match_id": "m1",
		"packed": dedicated.pack_result(dedicated.last_result, 0),
	}
	var client_script := load("res://backend/net_session.gd")
	var client: Node = client_script.new()
	client.enter_client_offline()
	var seen: Array[String] = []
	client.connection_changed.connect(func(status: String) -> void:
		seen.append(status)
	)
	client.rpc_match_assigned(payload)
	eq(client.local_seat, 0, "rpc_match_assigned sets the seat")
	eq(client.selected_class_id, "ironjaw", "rpc_match_assigned sets class_id")
	eq(client.match_id, "m1", "rpc_match_assigned sets match_id")
	eq(client.matched, true, "rpc_match_assigned marks the client matched")
	truthy(seen.has("matched"), "connection_changed emits matched")
	eq(str(client.snapshot()["units"][0]["class_id"]), "ironjaw", "board hydrates from the packed snapshot")
	client.free()
	_free_dedicated(dedicated)


func _test_hud_card_chrome() -> void:
	var mender := _card_unit(0, "mender", "Mender")
	var bastion := _card_unit(1, "bastion", "Bastion")
	eq(CombatHUD.offered_cast_ids(mender), ["mend", "pulse_tap", "ward", "cleanse", "heartstop"], "mender bar uses card ids")
	var stuffed: Dictionary = mender.duplicate(true)
	stuffed["spells"] = ["mark_shot", "advance"]
	eq(CombatHUD.offered_cast_ids(stuffed), [], "card kit drops spell ids that are not on the card")
	var snap := {
		"units": [mender, bastion],
		"local_seat": 0,
		"active_seat": 0,
		"phase": "COMBAT",
		"turn_index": 1,
		"coach": "",
		"match_over": false,
	}
	eq(CombatHUD.kit_class_id(snap), "mender", "kit class follows local_seat")
	var hud := CombatHUD.new()
	hud._build()
	hud.render(snap, [])
	eq(hud._banner_titles[0].text, "Mender", "seat 0 banner is Mender")
	eq(hud._banner_titles[1].text, "Bastion", "seat 1 banner is Bastion")
	eq(hud._spell_buttons.has("mend"), true, "Mend button id is the card id")
	eq(hud._spell_buttons.has("heartstop"), true, "Heartstop button id is the card id")
	eq(hud._spell_buttons.has("mark_shot"), false, "mender bar does not show the kestrel kit")
	eq(str(hud._spell_buttons["mend"].text).begins_with("Mend"), true, "Mend button uses the card name")
	var card := hud._kestrel_body.text
	truthy(card.contains("HP 80/80"), "card prints snapshot HP")
	truthy(card.contains("Pulse 0/6"), "Pulse meter uses the card cap")
	truthy(card.contains("Mastery 0"), "proto mastery is 0")
	truthy(card.contains("Resist 0"), "proto resist is 0")
	eq(card.contains("Marks"), false, "mender card does not invent Marks")
	var with_pulse: Dictionary = mender.duplicate(true)
	with_pulse["pulse"] = 2
	truthy(hud._unit_card_text(with_pulse, true, snap).contains("Pulse 2/6"), "Pulse current comes from the snapshot")
	snap["local_seat"] = 1
	hud.render(snap, [])
	truthy(hud._ironjaw_body.text.contains("Aegis 0/4"), "Aegis meter uses the card cap")
	eq(hud._spell_buttons.has("snap_wall"), true, "Snap Wall button id is the card id")
	var gloam := _card_unit(0, "gloam", "Gloam")
	var gloam_card := hud._unit_card_text(gloam, true, snap)
	truthy(gloam_card.contains("Umbral 0/4"), "Umbral meter uses the card cap")
	truthy(gloam_card.contains("Shades 0/2"), "Shades meter uses the card cap")
	hud.free()


func _test_card_cast_stays_pending() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	sim.reset_match({"seed": 3, "skip_deploy": true, "flat_board": true})
	var before: Dictionary = sim.snapshot()
	var hp_before := int(before["units"][1]["hp"])
	var ap_before := int(before["units"][0]["ap"])
	var cast: Dictionary = sim.submit({"type": "cast", "spell": "mend", "to": before["units"][1]["pos"], "seat": 0})
	eq(bool(cast.get("ok", true)), false, "mender cast is not resolved here")
	eq(str(cast.get("reason", "")), "backend_pending", "Backend must validate the card spell")
	eq(int(sim.snapshot()["units"][1]["hp"]), hp_before, "rejected Mend does not change HP")
	eq(int(sim.snapshot()["units"][0]["ap"]), ap_before, "rejected Mend does not spend AP")
	var preview: Dictionary = sim.preview_cast("heartstop")
	eq(str(preview.get("reason", "")), "backend_pending", "preview does not sample a card spell")
	eq(preview.get("sample_damage", 1), null, "preview has no invented sample")
	sim.free()


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


func _test_hotseat_roster_unchanged() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var net_script := load("res://backend/net_session.gd")
	var sim: Node = sim_script.new()
	var hot: Node = net_script.new()
	hot.attach_sim(sim)
	eq(hot.is_hotseat(), true, "fresh session is hot-seat")
	sim.reset_match({})
	var units: Array = sim.snapshot()["units"]
	eq(str(units[0]["class_id"]), "kestrel", "hot-seat seat 0 stays kestrel")
	eq(str(units[1]["class_id"]), "ironjaw", "hot-seat seat 1 stays ironjaw")
	hot.free()
	sim.free()


func _card_unit(seat: int, class_id: String, unit_name: String) -> Dictionary:
	return {
		"seat": seat,
		"name": unit_name,
		"class_id": class_id,
		"element": SpellKits.class_element_text(class_id),
		"hp": 80,
		"max_hp": 80,
		"ap": 6,
		"mp": 3,
		"facing": "E",
		"alive": true,
		"spells": SpellKits.class_spells(class_id).duplicate(),
		"marks": 0,
		"marks_cap": 5,
		"impact": 0,
		"impact_cap": 4,
	}


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
