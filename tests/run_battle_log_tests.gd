extends SceneTree

## Battle log: every combat event type has a line, hidden tiles stay hidden,
## and spent AP/MP are named with the pools left afterwards.
## Run: godot --headless --path . -s res://tests/run_battle_log_tests.gd

const LOG := preload("res://ui/battle_log.gd")

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_sim = root.get_node("CombatSim")
	_test_every_event_type_has_a_line()
	_test_named_lines()
	_test_live_fight()
	_test_hidden_cells()
	_test_cap_and_reject()
	_test_online_redaction()
	print("Battle log tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _snap() -> Dictionary:
	return {
		"active_seat": 0,
		"local_seat": -1,
		"team_size": 1,
		"party_size": 1,
		"turn_index": 1,
		"units": [
			{"seat": 0, "name": "Kestrel", "class_id": "kestrel", "team": 0, "pos": Vector2i(2, 2), "alive": true},
			{"seat": 1, "name": "Ironjaw", "class_id": "ironjaw", "team": 1, "pos": Vector2i(5, 2), "alive": true},
		],
	}


func _test_every_event_type_has_a_line() -> void:
	var types: Array = LOG.sim_event_types()
	truthy(types.size() >= 20, "the sim scan found combat events")
	var snap := _snap()
	for kind in types:
		var type_name := str(kind)
		eq(LOG.LINES.has(type_name), true, "no log line for event type %s" % type_name)
		var line := LOG.plain({"type": type_name, "seat": 0, "target_seat": 1, "coach": "REJECT — no."}, snap)
		truthy(line != "", "empty log line for event type %s" % type_name)


func _test_named_lines() -> void:
	var snap := _snap()
	var fade := LOG.plain({
		"type": "cast", "spell": "fade", "seat": 0, "invisible": true, "invisible_turns": 2,
		"ap_spent": 2, "mp_spent": 0, "ap_left": 4, "mp_left": 3, "engine_gained": 1,
	}, snap)
	truthy(fade.contains("fades") and fade.contains("Invisible 2"), "fade names the hide: %s" % fade)
	truthy(fade.contains("-2 AP") and fade.contains("AP 4 MP 3"), "fade names AP left: %s" % fade)
	var bell := LOG.plain({"type": "revealed", "seat": 0, "cell": Vector2i(2, 2), "coach": "Tolling Bell reveals Kestrel."}, snap)
	truthy(bell.contains("Tolling Bell reveals"), "tolling bell reveal: %s" % bell)
	var hit_reveal := LOG.plain({"type": "revealed", "seat": 0, "coach": "Kestrel is hit and revealed! Fade cooldown 1."}, snap)
	truthy(hit_reveal.contains("hit and revealed"), "hit reveal: %s" % hit_reveal)
	var worn := LOG.plain({"type": "expire", "status": "invisible", "target_seat": 0, "owner_seat": 0, "pos": Vector2i(2, 2)}, snap)
	truthy(worn.contains("visible"), "fade expiry: %s" % worn)
	var owner := snap.duplicate(true)
	owner["local_seat"] = 0
	var enemy := snap.duplicate(true)
	enemy["local_seat"] = 1
	var trap_event := {"type": "cast", "spell": "snare_trap", "seat": 0, "to": Vector2i(3, 4), "ap_spent": 2, "ap_left": 4, "mp_left": 3}
	truthy(LOG.plain(trap_event, owner).contains("(3,4)"), "owner sees the trap tile")
	eq(LOG.plain(trap_event, enemy).contains("(3,4)"), false, "enemy does not see the trap tile")
	var sprung := LOG.plain({"type": "trap", "seat": 0, "target_seat": 1, "to": Vector2i(3, 4), "damage": 6, "pin": true}, enemy)
	truthy(sprung.contains("Ironjaw") and sprung.contains("-6") and sprung.contains("Pinned"), "sprung trap names victim and damage: %s" % sprung)
	var push := LOG.lines({
		"type": "hit", "seat": 0, "target_seat": 1, "spell": "shoulder", "damage": 8,
		"ap_spent": 3, "ap_left": 3, "mp_left": 3, "pushed": true, "pulled": false,
		"push_from": Vector2i(5, 2), "push_to": Vector2i(7, 2), "slow_applied": true,
	}, snap)
	truthy(str(push[0]).contains("HIT") and str(push[0]).contains("-3 AP"), "hit names AP: %s" % str(push[0]))
	truthy(push.size() > 1 and str(push[1]).contains("(5,2)->(7,2)") and str(push[1]).contains("2 tiles") and str(push[1]).contains("mud"), "push names the slide: %s" % str(push[1]))
	var pull := LOG.plain({
		"type": "hit", "seat": 1, "target_seat": 0, "damage": 4, "pushed": true, "pulled": true,
		"push_from": Vector2i(2, 2), "push_to": Vector2i(3, 2),
	}, snap)
	eq(pull.contains("pulled"), false, "the hit line stays the hit")
	truthy(str(LOG.lines({
		"type": "hit", "seat": 1, "target_seat": 0, "damage": 4, "pushed": true, "pulled": true,
		"push_from": Vector2i(2, 2), "push_to": Vector2i(3, 2),
	}, snap)[1]).contains("pulled"), "pull is its own line")
	var bounce := LOG.plain({"type": "push_bounce", "target_seat": 1, "reason": "wall", "stagger_hp": 4, "stagger_mp": 1}, snap)
	truthy(bounce.contains("wall") and bounce.contains("-4 HP"), "bounce names the wall and damage: %s" % bounce)
	var blocked := LOG.plain({"type": "push_blocked", "target_seat": 1, "reason": "occupied"}, snap)
	truthy(blocked.contains("fighter"), "blocked push names the fighter: %s" % blocked)
	var slow := LOG.plain({"type": "slow", "target_seat": 1, "mp_delta": -2, "mp_left": 1, "ap_left": 6, "remaining": 0}, snap)
	truthy(slow.contains("Slow") and slow.contains("-2 MP") and slow.contains("MP 1"), "slow tick names MP: %s" % slow)
	var burn := LOG.plain({"type": "status", "status": "burn", "target_seat": 1, "stacks": 2, "hp_per_tick": 8, "remaining": 3, "refreshed": true}, snap)
	truthy(burn.contains("extended") and burn.contains("stack 2"), "burn extension: %s" % burn)
	var header := LOG.plain({
		"type": "turn_start", "seat": 0, "turn": 3, "ap_left": 4, "mp_left": 1,
		"water_cut": 1, "gear_cut": 1, "pinned": true, "stunned_skip": false, "steadfast_cut": 3,
	}, snap)
	truthy(header.begins_with("Turn 3 · Kestrel") and header.contains("AP 4 MP 1") and header.contains("Water -1 MP") and header.contains("Pinned") and header.contains("Steadfast -3 AP"), "turn start names the cuts: %s" % header)
	var mirror := LOG.plain({
		"type": "still", "still": "mirror_hour", "seat": 0, "target_seat": 1,
		"from": Vector2i(2, 2), "to": Vector2i(5, 2), "ap_spent": 2, "ap_left": 4, "mp_left": 3,
	}, snap)
	truthy(mirror.contains("Mirror Hour") and mirror.contains("-2 AP") and mirror.contains("AP 4 MP 3"), "mirror names AP left: %s" % mirror)
	var tide := LOG.plain({"type": "still", "still": "tide", "seat": 0, "cleared": ["Slow", "Burn"]}, snap)
	truthy(tide.contains("Tide cleansed Slow, Burn"), "tide names what it cleaned: %s" % tide)
	var vault := LOG.plain({
		"type": "cast", "spell": "vault", "seat": 0, "from": Vector2i(2, 2), "to": Vector2i(2, 4),
		"ap_spent": 3, "ap_left": 3, "mp_left": 3,
	}, snap)
	truthy(vault.contains("vaults") and vault.contains("-3 AP") and vault.contains("(2,2)->(2,4)"), "vault names the jump: %s" % vault)
	var grouped := LOG.text([
		{"type": "turn_start", "seat": 0, "turn": 1, "ap_left": 6, "mp_left": 3},
		{"type": "move", "seat": 0, "from": Vector2i(2, 2), "to": Vector2i(2, 3), "path": [Vector2i(2, 3)], "mp_spent": 1, "ap_left": 6, "mp_left": 2},
	], snap)
	truthy(grouped.contains("Turn 1 · Kestrel") and grouped.contains("walks 1"), "turns group the lines: %s" % grouped)
	var hidden := snap.duplicate(true)
	hidden["local_seat"] = 1
	hidden["units"][0]["invisible"] = true
	var walked := LOG.plain({
		"type": "move", "seat": 0, "from": Vector2i(2, 2), "to": Vector2i(2, 3),
		"path": [Vector2i(2, 3)], "mp_spent": 1, "ap_left": 6, "mp_left": 2,
	}, hidden)
	eq(walked.contains("(2,"), false, "an invisible walk hides the tile: %s" % walked)
	truthy(walked.contains("walks 1"), "the step count stays: %s" % walked)


func _test_live_fight() -> void:
	_sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1, 1, 1, 1],
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(4, 4), Vector2i(7, 4)],
	})
	var opened: Array = _sim.snapshot()["battle_log"]
	var starts := 0
	for event in opened:
		if str(event.get("type", "")) == "turn_start":
			starts += 1
			truthy(event.has("ap_left") and event.has("mp_left"), "turn start stamps pools")
			eq(int(event["ap_left"]), int(_sim._unit_by_seat(0)["ap"]), "opening AP is the pool after cuts")
	eq(starts, 1, "opening turn is logged once")
	var walked: Dictionary = _sim.submit({"type": "move", "seat": 0, "to": Vector2i(4, 5)})
	eq(bool(walked.get("ok", false)), true, "kestrel walks")
	var move := _find(_sim.snapshot()["battle_log"], "move")
	truthy(int(move.get("mp_spent", 0)) > 0, "walk records MP spent")
	eq(int(move.get("mp_left", -1)), int(_sim._unit_by_seat(0)["mp"]), "walk records MP left")
	var walk_line := LOG.plain(move, _view(0))
	truthy(walk_line.contains("walks") and walk_line.contains("MP"), "walk line names MP: %s" % walk_line)
	_sim._unit_by_seat(0)["crit"] = 100
	var shot: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "seat": 0, "to": Vector2i(7, 4)})
	eq(bool(shot.get("ok", false)), true, "mark shot connects")
	var hit := _find(_sim.snapshot()["battle_log"], "hit")
	var hit_line := LOG.plain(hit, _view(0))
	truthy(hit_line.contains("crit") and hit_line.contains("-2 AP"), "crit hit names AP: %s" % hit_line)
	_sim._unit_by_seat(0)["still"] = "bleeding_hour"
	_sim._unit_by_seat(0)["still_mode"] = "intact"
	_sim._unit_by_seat(0)["still_ready"] = true
	var still: Dictionary = _sim.submit({"type": "use_still", "seat": 0})
	eq(bool(still.get("ok", false)), true, "bleeding hour fires")
	var still_row := _find(_sim.snapshot()["battle_log"], "still")
	var still_line := LOG.plain(still_row, _view(0))
	truthy(still_line.contains("Bleeding Hour") and still_line.contains("AP"), "still line names the pool: %s" % still_line)
	_sim.submit({"type": "end_turn", "seat": 0})
	_sim._map_id = ""
	var mud := {"pos": Vector2i(7, 4), "terrain": "mud", "elevation": 0}
	_sim.reset_match({
		"seed": 5,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1],
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(6, 4), Vector2i(5, 4)],
		"tiles": [mud],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	var shove: Dictionary = _sim.submit({"type": "cast", "spell": "shoulder", "seat": 1, "to": Vector2i(6, 4)})
	eq(bool(shove.get("ok", false)), true, "shoulder connects")
	var shoved := false
	for event in _sim.snapshot()["battle_log"]:
		if str(event.get("type", "")) != "hit":
			continue
		var rows: Array = LOG.lines(event, _view(1))
		if rows.size() < 2:
			continue
		if str(rows[1]).contains("mud"):
			shoved = true
	truthy(shoved, "shoulder into mud is a push line")
	_sim.reset_match({
		"seed": 6,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(3, 3), Vector2i(6, 3)],
	})
	var faded: Dictionary = _sim.submit({"type": "cast", "spell": "fade", "seat": 0, "to": Vector2i(3, 3)})
	eq(bool(faded.get("ok", false)), true, "fade casts")
	var fade_row := _find(_sim.snapshot()["battle_log"], "cast")
	truthy(LOG.plain(fade_row, _view(0)).contains("Invisible"), "gloam's log says invisible")
	_sim.submit({"type": "move", "seat": 0, "to": Vector2i(3, 4)})
	var hidden_move := _find(_sim.snapshot()["battle_log"], "move")
	eq(LOG.plain(hidden_move, _view(1)).contains("(3,"), false, "enemy log hides the fade walk")
	truthy(LOG.plain(hidden_move, _view(0)).contains("(3,4)"), "gloam still sees his own walk")


func _test_hidden_cells() -> void:
	_sim.reset_match({
		"seed": 7,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(4, 4), Vector2i(4, 7)],
	})
	var laid: Dictionary = _sim.submit({"type": "cast", "spell": "snare_trap", "seat": 0, "to": Vector2i(4, 6)})
	eq(bool(laid.get("ok", false)), true, "snare places")
	var cast := _find(_sim.snapshot()["battle_log"], "cast")
	truthy(LOG.plain(cast, _view(0)).contains("(4,6)"), "owner log shows the trap")
	eq(LOG.plain(cast, _view(1)).contains("(4,6)"), false, "enemy log hides the trap")
	_sim.submit({"type": "end_turn", "seat": 0})
	var stepped: Dictionary = _sim.submit({"type": "move", "seat": 1, "to": Vector2i(4, 6)})
	eq(bool(stepped.get("ok", false)), true, "ironjaw steps on the trap")
	var trap := _find(_sim.snapshot()["battle_log"], "trap")
	var trap_line := LOG.plain(trap, _view(1))
	truthy(trap_line.contains("Snare") and trap_line.contains("Ironjaw") and trap_line.contains("-"), "trigger names the victim: %s" % trap_line)


func _test_cap_and_reject() -> void:
	_sim.reset_match({
		"seed": 8,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(2, 2), Vector2i(6, 2)],
	})
	var before := int(_sim.snapshot()["battle_log"].size())
	var again := int(_sim.snapshot()["battle_log"].size())
	eq(again, before, "a second snapshot does not duplicate the log")
	var bad: Dictionary = _sim.submit({"type": "move", "seat": 0, "to": Vector2i(14, 14)})
	eq(bool(bad.get("ok", false)), false, "a bad walk is rejected")
	var log: Array = _sim.snapshot()["battle_log"]
	truthy(str(log.back().get("type", "")) == "reject", "the reject is kept")
	truthy(log.size() > 1, "the reject does not wipe earlier lines")
	var dirs := ["N", "E", "S", "W"]
	for i in 200:
		_sim.submit({"type": "face", "seat": _sim._active_seat, "dir": dirs[i % 4]})
		if _sim._match_over:
			break
	eq(_sim.snapshot()["battle_log"].size(), int(_sim.BATTLE_LOG_CAP), "the log stays capped")


func _test_online_redaction() -> void:
	_sim.reset_match({
		"seed": 9,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(3, 3), Vector2i(6, 3)],
	})
	_sim.submit({"type": "cast", "spell": "fade", "seat": 0, "to": Vector2i(3, 3)})
	var snap: Dictionary = _sim.snapshot()
	var net := root.get_node("NetSession")
	var viewed: Dictionary = net._redact_invisible_for_viewer(snap, [], 1)
	var hidden := false
	for event in viewed["snapshot"].get("battle_log", []):
		if str(event.get("spell", "")) != "fade":
			continue
		hidden = event.get("caster_cell", Vector2i.ZERO) == null
	truthy(hidden, "the enemy wire drops the fade tile from the log")
	var owner: Dictionary = net._redact_invisible_for_viewer(snap, [], 0)
	var kept := false
	for event in owner["snapshot"].get("battle_log", []):
		if str(event.get("spell", "")) == "fade" and event.get("caster_cell", null) != null:
			kept = true
	truthy(kept, "gloam's own wire keeps the fade tile")


func _view(seat: int) -> Dictionary:
	var snap: Dictionary = _sim.snapshot()
	snap["local_seat"] = seat
	return snap


func _find(events: Array, kind: String) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if typeof(events[i]) == TYPE_DICTIONARY and str(events[i].get("type", "")) == kind:
			return events[i]
	return {}


func truthy(ok: bool, msg: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL %s" % msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL %s (got %s, want %s)" % [msg, str(actual), str(expected)])
