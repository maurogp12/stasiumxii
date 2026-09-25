extends SceneTree

## View-facing event payloads. Fields describe resolves that already happen.
## Run: godot --headless --path . -s res://tests/run_event_hooks_tests.gd

const _IntentCodec := preload("res://backend/intent_codec.gd")

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
	print("Event-hook tests: %d passed, %d failed" % [_passed, _failed])
	_host.free()
	_guest.free()
	_sim.free()
	_view.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_caster_cell_on_hit_and_miss()
	_test_caster_cell_on_cast_events()
	_test_caster_cell_survives_host_pack()
	_test_ambush_origin_and_destination()
	_test_hold_line_cone_and_targets()


func _test_caster_cell_on_hit_and_miss() -> void:
	var caster := Vector2i(3, 3)
	var target := Vector2i(4, 3)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": caster,
		"ironjaw_pos": target,
		"kestrel_facing": "E",
		"rolls": [1],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	var before_hp := int(_sim.snapshot()["units"][0]["hp"])
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": caster, "seat": 1})
	eq(bool(hit.get("ok", false)), true, "Strike hit resolves")
	var hit_event := _event_of(hit.get("events", []), "hit")
	eq(hit_event.get("caster_cell"), target, "Strike hit caster_cell is Ironjaw's cell")
	eq(int(hit_event.get("damage", -1)), 16, "Strike hit damage stays 16")
	eq(int(_sim.snapshot()["units"][0]["hp"]), before_hp - 16, "Strike still removes 16 HP")
	eq(int(_sim.snapshot()["units"][1]["ap"]), 3, "Strike still spends 3 AP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": caster,
		"ironjaw_pos": target,
		"rolls": [100],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": caster, "seat": 1})
	var miss_event := _event_of(missed.get("events", []), "miss")
	eq(miss_event.get("caster_cell"), target, "Strike miss caster_cell is Ironjaw's cell")
	eq(int(miss_event.get("damage", -1)), 0, "Strike miss damage stays 0")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "Strike miss still deals nothing")
	eq(int(_sim.snapshot()["units"][1]["ap"]), 3, "Strike miss still spends 3 AP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"rolls": [1, 100],
	})
	var mend: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	eq(_event_of(mend.get("events", []), "hit").get("caster_cell"), Vector2i(1, 1), "Mend hit caster_cell is Mender")
	var mend_miss: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	eq(_event_of(mend_miss.get("events", []), "miss").get("caster_cell"), Vector2i(1, 1), "Mend miss caster_cell is Mender")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(2, 1)],
		"kestrel_facing": "W",
		"rolls": [1, 100],
	})
	var hold: Dictionary = _sim.submit({"type": "cast", "spell": "hold_line", "to": Vector2i(2, 1), "seat": 0})
	eq(_event_of(hold.get("events", []), "hit").get("caster_cell"), Vector2i(1, 1), "Hold Line hit caster_cell is Bastion")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 73, "Hold Line damage stays 7")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(2, 1)],
		"rolls": [100],
	})
	var hold_miss: Dictionary = _sim.submit({"type": "cast", "spell": "hold_line", "to": Vector2i(2, 1), "seat": 0})
	eq(_event_of(hold_miss.get("events", []), "miss").get("caster_cell"), Vector2i(1, 1), "Hold Line miss caster_cell is Bastion")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 80, "Hold Line miss still deals 0")

	var gloam := Vector2i(2, 2)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, Vector2i(5, 2)],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"rolls": [1],
	})
	var ambush: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(5, 2), "seat": 0})
	var ambush_hit := _event_of(ambush.get("events", []), "hit")
	eq(ambush_hit.get("caster_cell"), gloam, "Ambush hit caster_cell is the cell before the jump")
	eq(_sim.snapshot()["units"][0]["pos"], Vector2i(6, 2), "Ambush still lands on the empty back cell")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, Vector2i(5, 2)],
		"gloam_shade": true,
		"rolls": [100],
	})
	var ambush_miss: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(5, 2), "seat": 0})
	eq(_event_of(ambush_miss.get("events", []), "miss").get("caster_cell"), gloam, "Ambush miss caster_cell is Gloam")
	eq(_sim.snapshot()["units"][0]["pos"], gloam, "Ambush miss still does not teleport")


func _test_caster_cell_on_cast_events() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	var shade: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 1), "seat": 0})
	var shade_event := _event_of(shade.get("events", []), "cast")
	eq(shade_event.get("caster_cell"), Vector2i(1, 1), "Drop Shade cast carries caster_cell")
	eq(shade_event.get("to"), Vector2i(2, 1), "Drop Shade still names the token cell")
	eq(int(_sim.snapshot()["units"][0]["shades"]), 1, "Drop Shade still places one token")
	var fade: Dictionary = _sim.submit({"type": "cast", "spell": "fade", "to": Vector2i(1, 1), "seat": 0})
	eq(_event_of(fade.get("events", []), "cast").get("caster_cell"), Vector2i(1, 1), "Fade cast carries caster_cell")
	eq(bool(_sim.snapshot()["units"][0]["invisible"]), true, "Fade still sets Invisible")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	var plant: Dictionary = _sim.submit({"type": "cast", "spell": "plant", "to": Vector2i(2, 1), "seat": 0})
	eq(_event_of(plant.get("events", []), "cast").get("caster_cell"), Vector2i(1, 1), "Plant cast carries caster_cell")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 1, "Plant still gains 1 Aegis")


func _test_caster_cell_survives_host_pack() -> void:
	var hot_script := load("res://backend/net_session.gd")
	var hot: Node = hot_script.new()
	hot.attach_sim(_sim)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(3, 1),
		"kestrel_facing": "E",
		"rolls": [1],
	})
	var local: Dictionary = hot.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(3, 1)})
	eq(_event_of(local.get("events", []), "hit").get("caster_cell"), Vector2i(1, 1), "hot-seat submit keeps caster_cell")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 72, "hot-seat Mark Shot damage stays 8")
	hot.free()

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "W",
		"rolls": [1],
		"fixture": true,
	})
	eq(_host.submit({"type": "end_turn"})["ok"], true, "host ends Kestrel's turn")
	var cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "strike", "to": Vector2i(3, 3)}, 1)
	eq(bool(cast.get("ok", false)), true, "host Strike resolves")
	var packed: Dictionary = _host.pack_result(cast, 0)
	var decoded: Variant = _IntentCodec.decode(packed)
	var wire_events: Array = (decoded as Dictionary).get("events", [])
	eq(_event_of(wire_events, "hit").get("caster_cell"), Vector2i(4, 3), "packed Strike hit keeps caster_cell")
	_guest.apply_packed_state(packed)
	var guest_events: Array = _guest.snapshot().get("last_events", [])
	eq(_event_of(guest_events, "hit").get("caster_cell"), Vector2i(4, 3), "guest snapshot last_events keep caster_cell")
	eq(int(_guest.snapshot()["units"][0]["hp"]), int(_sim.snapshot()["units"][0]["hp"]), "guest HP matches the host")


func _test_ambush_origin_and_destination() -> void:
	var gloam := Vector2i(2, 2)
	var prey := Vector2i(5, 2)
	var shade_cell := Vector2i(0, 0)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"gloam_shade": true,
		"rolls": [1],
	})
	var shades_before := int(_sim.snapshot()["units"][0]["shades"])
	var invisible_hit: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	var hit := _event_of(invisible_hit.get("events", []), "hit")
	eq(hit.get("origin"), gloam, "Invisible Ambush origin is Gloam's own cell")
	eq(hit.get("destination"), Vector2i(6, 2), "Invisible Ambush destination is the empty back tile")
	eq(bool(hit.get("teleported", false)), true, "Invisible Ambush hit teleported")
	eq(int(_sim.snapshot()["units"][0]["shades"]), shades_before, "Invisible origin still does not spend Shade")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 50, "true back stays 22 × 1.35 = 30")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"rolls": [100],
	})
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	var miss := _event_of(missed.get("events", []), "miss")
	eq(miss.get("origin"), shade_cell, "Shade Ambush miss origin is the Shade cell")
	eq(miss.has("destination"), false, "Ambush miss emits no destination")
	eq(bool(miss.get("teleported", true)), false, "Ambush miss teleported is false")
	eq(_sim.snapshot()["units"][0]["pos"], gloam, "Ambush miss still stays put")
	eq(int(_sim.snapshot()["units"][0]["shades"]), 1, "Ambush miss still keeps the Shade")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 80, "Ambush miss still deals 0")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"rolls": [1],
		"blockers": [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(5, 1), Vector2i(5, 3), Vector2i(6, 2), Vector2i(6, 3)],
	})
	var blocked: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	var blocked_hit := _event_of(blocked.get("events", []), "hit")
	eq(blocked_hit.get("origin"), shade_cell, "Shade Ambush origin is the Shade cell")
	eq(blocked_hit.get("destination"), Vector2i(6, 1), "blocked back destination is the adjacent empty cell")
	eq(bool(blocked_hit.get("teleported", false)), true, "Shade Ambush hit teleported")
	eq(int(_sim.snapshot()["units"][0]["shades"]), 0, "Shade origin still spends one Shade")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 58, "blocked back stays 22 at facing ×1.00")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"rolls": [1],
		"fixture": true,
	})
	var packed_cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "ambush", "to": prey}, 0)
	var packed: Dictionary = _host.pack_result(packed_cast, 1)
	var decoded: Variant = _IntentCodec.decode(packed)
	var wire := _event_of((decoded as Dictionary).get("events", []), "hit")
	eq(wire.get("origin"), gloam, "packed Ambush origin survives encode")
	eq(wire.get("destination"), Vector2i(6, 2), "packed Ambush destination survives encode")
	_guest.apply_packed_state(packed)
	var guest := _event_of(_guest.snapshot().get("last_events", []), "hit")
	eq(guest.get("origin"), gloam, "guest Ambush origin matches the host")
	eq(guest.get("destination"), Vector2i(6, 2), "guest Ambush destination matches the host")


func _test_hold_line_cone_and_targets() -> void:
	var cone := [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 0)]
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(2, 1)],
		"kestrel_facing": "W",
		"rolls": [1],
	})
	var extra: Dictionary = _sim._make_unit(1, "kestrel", "Second", "air", Vector2i(2, 2), "W", true)
	_sim._units.append(extra)
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "hold_line", "to": Vector2i(2, 1), "seat": 0})
	var event := _event_of(hit.get("events", []), "hit")
	eq(event.get("cone"), cone, "Hold Line hit lists the front cone cells")
	var targets: Array = event.get("targets", [])
	eq(targets.size(), 2, "Hold Line hit lists each body in the cone")
	eq(targets[0].get("cell"), Vector2i(2, 1), "first Hold Line body is the front cell")
	eq(int(targets[0].get("damage", -1)), 7, "first body takes 7")
	eq(int(targets[0].get("exit_tax", 0)), 1, "first body gets the exit tax")
	eq(bool(targets[0].get("hit", false)), true, "first body connected")
	eq(targets[1].get("cell"), Vector2i(2, 2), "second Hold Line body is the side cell")
	eq(int(targets[1].get("damage", -1)), 7, "second body takes 7")
	eq(int(event.get("damage", -1)), 14, "Hold Line total is the sum of the bodies")
	eq(int(event.get("bodies", 0)), 2, "Hold Line bodies count stays the hit count")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 73, "primary target still loses 7 HP")
	eq(int(extra["hp"]), 73, "second body still loses 7 HP")
	eq(int(_sim.snapshot()["units"][0]["aegis"]), 1, "Hold Line still gains 1 Aegis")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(2, 1)],
		"kestrel_facing": "W",
		"rolls": [100],
	})
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "hold_line", "to": Vector2i(2, 1), "seat": 0})
	var miss := _event_of(missed.get("events", []), "miss")
	eq(miss.get("cone"), cone, "Hold Line miss lists the same cone")
	var missed_rows: Array = miss.get("targets", [])
	eq(missed_rows.size(), 1, "Hold Line miss names the body that was in the cone")
	eq(bool(missed_rows[0].get("hit", true)), false, "Hold Line miss target did not connect")
	eq(int(missed_rows[0].get("damage", -1)), 0, "Hold Line miss target damage is 0")
	eq(int(miss.get("bodies", -1)), 0, "Hold Line miss bodies field stays 0")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 80, "Hold Line miss still deals no damage")
	eq(int(_sim.snapshot()["units"][1]["exit_tax"]), 0, "Hold Line miss does not apply exit tax")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(2, 1)],
		"kestrel_facing": "W",
		"rolls": [1],
		"fixture": true,
	})
	var cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "hold_line", "to": Vector2i(2, 1)}, 0)
	var packed: Dictionary = _host.pack_result(cast, 1)
	var decoded: Variant = _IntentCodec.decode(packed)
	var wire := _event_of((decoded as Dictionary).get("events", []), "hit")
	eq(wire.get("cone"), cone, "packed Hold Line cone survives encode")
	_guest.apply_packed_state(packed)
	var guest := _event_of(_guest.snapshot().get("last_events", []), "hit")
	eq(guest.get("cone"), cone, "guest Hold Line cone matches the host")
	var guest_rows: Array = guest.get("targets", [])
	eq(guest_rows.size(), 1, "guest Hold Line has the host target row")
	eq(int(guest_rows[0].get("damage", -1)), 7, "guest Hold Line target damage matches")


func _event_of(events: Variant, kind: String) -> Dictionary:
	if typeof(events) != TYPE_ARRAY:
		return {}
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == kind:
			return event
	return {}


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1
