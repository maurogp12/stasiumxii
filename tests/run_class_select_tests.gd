extends SceneTree

## SELECT_CLASS chrome on the dedicated queue contract from Backend PR #51.
## Allowlist is the five Locked classes. Card spells resolve. Nightfold stays gated.
## Run: godot --headless --path . -s res://tests/run_class_select_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("Class-select tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_source_contract()
	_test_client_confirm()
	_test_server_allowlist()
	_test_queue_pairs_and_assigns()
	_test_hud_paints_snapshot()
	_test_card_cast_resolves()
	_test_blocked_tiles_chrome()
	_test_hotseat_roster_unchanged()


func _test_source_contract() -> void:
	var net_src := FileAccess.get_file_as_string("res://backend/net_session.gd")
	truthy(net_src.contains("func select_class(class_id: String)"), "select_class keeps the client signature")
	truthy(net_src.contains("func match_assigned"), "match_assigned reports a live pair")
	truthy(net_src.contains("rpc_select_class"), "client select goes through rpc_select_class")
	truthy(net_src.contains("rpc_class_result"), "class result is rpc_class_result")
	truthy(net_src.contains("\"ok\": ok"), "class result carries ok")
	truthy(net_src.contains("\"class_id\": class_id"), "class result carries class_id")
	truthy(net_src.contains("\"reason\": reason"), "class result carries reason")
	truthy(net_src.contains("rpc_enqueue"), "enqueue goes through rpc_enqueue")
	truthy(net_src.contains("rpc_queue_result"), "queue result is rpc_queue_result")
	truthy(net_src.contains("\"status\": status"), "queue result carries status")
	truthy(net_src.contains("\"type\": \"match_assigned\""), "match payload type is match_assigned")
	truthy(net_src.contains("\"classes\": ids"), "match payload carries both classes")
	truthy(net_src.contains("\"match_id\": match_id"), "match payload carries match_id")
	truthy(net_src.contains("\"class_selected\""), "connection_changed emits class_selected")
	truthy(net_src.contains("\"class_rejected\""), "connection_changed emits class_rejected")
	truthy(net_src.contains("\"waiting\""), "connection_changed emits waiting")
	truthy(net_src.contains("\"queue_rejected\""), "connection_changed emits queue_rejected")
	truthy(net_src.contains("\"matched\""), "connection_changed emits matched")
	eq(net_src.contains("rpc_class_selected"), false, "rpc_class_selected is not a chrome RPC")
	eq(net_src.contains("rpc_class_rejected"), false, "rpc_class_rejected is not a chrome RPC")
	eq(net_src.contains("rpc_matchmaking_status"), false, "rpc_matchmaking_status is not a chrome RPC")
	eq(net_src.contains("rpc_match_found"), false, "rpc_match_found is not a chrome RPC")
	eq(net_src.contains("func enter_matchmaking"), false, "enter_matchmaking is not the queue entry")
	eq(net_src.contains("backend_pending"), false, "net_session does not stub card spells")
	var chrome := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	truthy(chrome.contains("select_class"), "class select calls select_class")
	truthy(chrome.contains("Find Match"), "chrome has a Find Match control")
	truthy(chrome.contains("connection_changed"), "class select listens to connection_changed")
	truthy(chrome.contains("start_queue_client"), "Find Match joins the queue")
	truthy(chrome.contains("match_assigned"), "class select reads match_assigned")
	truthy(chrome.contains("\"waiting\""), "class select listens for waiting")
	eq(chrome.contains("enter_matchmaking"), false, "class select does not call enter_matchmaking")
	eq(chrome.contains("backend_pending"), false, "class select does not stub card spells")
	truthy(chrome.contains("Kestrel, Ironjaw, Mender, Gloam, Bastion"), "class select shows the five display names")
	var lobby := FileAccess.get_file_as_string("res://scenes/online_lobby.gd")
	truthy(lobby.contains("select_class"), "lobby calls select_class")
	truthy(lobby.contains("start_queue_client"), "lobby joins the queue")
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	eq(hud_src.contains("backend_pending"), false, "HUD does not stub card spells")
	eq(hud_src.contains("awaits_backend"), false, "HUD does not gate card spells as pending")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("backend_pending"), false, "CombatSim resolves Locked card spells")
	eq(SpellKits.LOCKED_ROSTER, ["kestrel", "ironjaw", "mender", "gloam", "bastion"], "allowlist is the five Locked classes")
	eq(SpellKits.is_roster_class("mender"), true, "mender is on the allowlist")
	eq(SpellKits.is_roster_class("gloam"), true, "gloam is on the allowlist")
	eq(SpellKits.is_roster_class("bastion"), true, "bastion is on the allowlist")
	eq(SpellKits.is_gated("nightfold"), true, "Nightfold stays gated")
	eq(SpellKits.is_gated("mend"), false, "Mend is not gated")


func _test_client_confirm() -> void:
	var net_script := load("res://backend/net_session.gd")
	var client: Node = net_script.new()
	var picked: Dictionary = client.select_class(" Mender ")
	eq(bool(picked.get("ok", false)), true, "mender confirms locally")
	eq(str(picked.get("class_id", "")), "mender", "class id is normalized")
	eq(str(picked.get("reason", "x")), "", "confirm reason is empty")
	eq(client.selected_class_id, "mender", "confirmed class is stored before connect")
	var rejected: Dictionary = client.select_class("pulse")
	eq(bool(rejected.get("ok", true)), false, "client rejects pulse")
	eq(str(rejected.get("reason", "")), "invalid_class", "reject reason is invalid_class")
	eq(client.selected_class_id, "mender", "a reject does not clear the stored class")
	client.free()


func _test_server_allowlist() -> void:
	var dedicated := _dedicated()
	var result: Dictionary = dedicated.server_select_class("p1", "gloam")
	eq(bool(result.get("ok", false)), true, "server confirms gloam")
	eq(str(result.get("class_id", "")), "gloam", "server stores gloam")
	var bad: Dictionary = dedicated.server_select_class("p2", "pulse")
	eq(bool(bad.get("ok", true)), false, "server rejects pulse")
	eq(str(bad.get("reason", "")), "invalid_class", "server reason is invalid_class")
	eq(dedicated.server_session("p2").is_empty(), true, "rejected class is not stored")
	var early: Dictionary = dedicated.server_enqueue("missing")
	eq(str(early.get("reason", "")), "class_required", "queue before confirm is class_required")
	eq(dedicated.match_assigned(), false, "invalid picks do not start a match")
	_free_dedicated(dedicated)


func _test_queue_pairs_and_assigns() -> void:
	var dedicated := _dedicated()
	eq(bool(dedicated.server_select_class("a", "mender").get("ok", false)), true, "first confirm is mender")
	var waiting: Dictionary = dedicated.server_enqueue("a")
	eq(bool(waiting.get("queued", false)), true, "first player is queued")
	eq(bool(waiting.get("matched", true)), false, "one player does not start a match")
	eq(dedicated.match_assigned(), false, "host is not live with one player")
	dedicated.server_select_class("b", "bastion")
	var paired: Dictionary = dedicated.server_enqueue("b")
	eq(bool(paired.get("matched", false)), true, "second confirmed player pairs")
	eq(dedicated.match_assigned(), true, "host match_assigned is true")
	var units: Array = dedicated.sim().snapshot()["units"]
	eq(str(units[0]["class_id"]), "mender", "seat 0 is the first queued class")
	eq(str(units[1]["class_id"]), "bastion", "seat 1 is the second queued class")
	eq(int((units[0]["resources"] as Dictionary)["pulse"]), int(units[0]["pulse"]), "resources.pulse mirrors the field")
	eq(int((units[1]["resources"] as Dictionary)["aegis"]), int(units[1]["aegis"]), "resources.aegis mirrors the field")
	var client_script := load("res://backend/net_session.gd")
	var client: Node = client_script.new()
	client.enter_client_offline()
	var seen: Array[String] = []
	client.connection_changed.connect(func(status: String) -> void:
		seen.append(status)
	)
	client.rpc_match_assigned({
		"type": "match_assigned",
		"seat": 0,
		"class_id": "mender",
		"classes": ["mender", "bastion"],
		"match_id": "m1",
	})
	eq(client.local_seat, 0, "rpc_match_assigned sets the seat")
	eq(client.selected_class_id, "mender", "rpc_match_assigned sets class_id")
	eq(client.match_assigned(), true, "rpc_match_assigned marks the client live")
	truthy(seen.has("matched"), "connection_changed emits matched")
	client.apply_packed_state(dedicated.pack_result(dedicated.last_result, 0))
	eq(str(client.snapshot()["units"][0]["class_id"]), "mender", "board hydrates from the snapshot push")
	client.free()
	_free_dedicated(dedicated)


func _test_hud_paints_snapshot() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	sim.reset_match({
		"seed": 3,
		"skip_deploy": true,
		"flat_board": true,
		"classes": ["mender", "bastion"],
	})
	var snap: Dictionary = sim.snapshot()
	eq(CombatHUD.offered_cast_ids(snap["units"][0]), ["mend", "pulse_tap", "ward", "cleanse", "heartstop"], "mender bar uses card ids")
	eq(CombatHUD.offered_cast_ids(snap["units"][1]).has("snap_wall"), true, "bastion bar includes Snap Wall")
	eq(CombatHUD.offered_cast_ids(snap["units"][1]).has("nightfold"), false, "bastion bar does not invent Nightfold")
	var hud := CombatHUD.new()
	hud._build()
	hud.render(snap, sim.legal_intents(0))
	eq(hud._banner_titles[0].text, "Mender", "seat 0 banner is Mender")
	eq(hud._banner_titles[1].text, "Bastion", "seat 1 banner is Bastion")
	eq(hud._spell_buttons.has("mend"), true, "Mend button id is the card id")
	eq(hud._spell_buttons.has("nightfold"), false, "gated Nightfold is not a button")
	var card := hud._kestrel_body.text
	truthy(card.contains("HP 80/80"), "card prints snapshot HP")
	truthy(card.contains("Pulse 0/6"), "Pulse meter uses the snapshot cap")
	truthy(card.contains("Mastery 0"), "proto mastery is 0")
	truthy(card.contains("Resist 0"), "proto resist is 0")
	eq(card.contains("Marks"), false, "mender card does not invent Marks")
	truthy(hud._ironjaw_body.text.contains("Aegis 0/4"), "Aegis meter uses the snapshot cap")
	var gloam_sim: Node = sim_script.new()
	gloam_sim.reset_match({
		"seed": 4,
		"skip_deploy": true,
		"flat_board": true,
		"classes": ["gloam", "kestrel"],
	})
	var gloam_card := hud._unit_card_text(gloam_sim.snapshot()["units"][0], true, gloam_sim.snapshot())
	truthy(gloam_card.contains("Umbral 0/4"), "Umbral meter uses the snapshot cap")
	truthy(gloam_card.contains("Shades 0/2"), "Shades meter uses the snapshot cap")
	eq(CombatHUD.offered_cast_ids(gloam_sim.snapshot()["units"][0]).has("nightfold"), false, "Nightfold stays off the gloam bar")
	eq(CombatHUD.offered_cast_ids(gloam_sim.snapshot()["units"][0]).has("cut"), true, "Cut stays on the gloam bar")
	hud.free()
	gloam_sim.free()
	sim.free()


func _test_card_cast_resolves() -> void:
	var sim_script := load("res://backend/combat_sim.gd")
	var sim: Node = sim_script.new()
	sim.reset_match({
		"seed": 3,
		"skip_deploy": true,
		"flat_board": true,
		"classes": ["mender", "kestrel"],
		"mender_hp": 40,
		"rolls": [1],
	})
	var before: Dictionary = sim.snapshot()
	var cast: Dictionary = sim.submit({"type": "cast", "spell": "mend", "to": before["units"][0]["pos"], "seat": 0})
	eq(bool(cast.get("ok", false)), true, "Mend resolves")
	eq(str(cast.get("reason", "")), "", "Mend is not backend_pending")
	eq(int(sim.snapshot()["units"][0]["pulse"]), 1, "Mend writes Pulse on the snapshot")
	eq(int((sim.snapshot()["units"][0]["resources"] as Dictionary)["pulse"]), 1, "resources.pulse follows the field")
	var night: Dictionary = sim.submit({"type": "cast", "spell": "nightfold", "to": before["units"][1]["pos"], "seat": 0})
	eq(bool(night.get("ok", true)), false, "Nightfold is not resolved from the mender seat")
	sim.free()


func _test_blocked_tiles_chrome() -> void:
	var wall := Vector2i(2, 3)
	var cells := SnapshotTiles.blocked_cells({
		"blocked_tiles": [{
			"x": wall.x,
			"y": wall.y,
			"pos": wall,
			"turns": 2,
		}],
		"walls": [Vector2i(7, 0)],
		"last_events": [
			{"type": "snap_wall", "to": Vector2i(6, 6), "cells": [Vector2i(6, 6)]},
			{"type": "hit", "to": Vector2i(3, 3)},
		],
	})
	eq(cells.has(wall), true, "blocked_tiles {x,y,pos,turns} is painted")
	eq(cells.has(Vector2i(6, 6)), true, "snap_wall to and cells are painted")
	eq(cells.has(Vector2i(7, 0)), false, "walls is not a bound snapshot key")
	eq(cells.has(Vector2i(3, 3)), false, "non-snap_wall events are not walls")
	eq(SnapshotTiles.blocked_cells({}).is_empty(), true, "a snapshot without the key paints nothing")


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
