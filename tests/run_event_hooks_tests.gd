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
	_test_absorbed_damage_and_intercept()
	_test_shade_and_plant_snapshot()


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


func _test_absorbed_damage_and_intercept() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"kestrel_hit_immunity": 1,
		"rolls": [1],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	var immune: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var immune_hit := _event_of(immune.get("events", []), "hit")
	eq(bool(immune_hit.get("immunity_absorbed", false)), true, "immunity consumes the hit")
	eq(int(immune_hit.get("immunity_amount", -1)), 16, "immunity amount is the pre-mitigation hit")
	eq(int(immune_hit.get("damage", -1)), 0, "immunity leaves HP damage at 0")
	eq(int(immune_hit.get("shield_absorbed", -1)), 0, "immunity does not touch shield")
	eq(bool(immune_hit.get("shield_broken", true)), false, "immunity does not break shield")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "immunity still prevents HP loss")
	eq(int(_sim.snapshot()["units"][0]["hit_immunity"]), 0, "immunity charge is still spent")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"rolls": [1, 1],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	_live_unit(0)["shield"] = 20
	_live_unit(0)["shield_turns"] = 2
	var soaked: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var soaked_hit := _event_of(soaked.get("events", []), "hit")
	eq(int(soaked_hit.get("shield_absorbed", -1)), 16, "shield absorbs the 16 Strike")
	eq(bool(soaked_hit.get("shield_broken", true)), false, "a 20 shield is not broken by 16")
	eq(int(soaked_hit.get("shield_remaining", -1)), 4, "shield remaining is 4")
	eq(int(soaked_hit.get("damage", -1)), 0, "full shield leaves HP damage at 0")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "partial shield still blocks all HP")
	eq(int(_sim.snapshot()["units"][0]["shield"]), 4, "shield pool is 4")
	_live_unit(0)["shield"] = 10
	_live_unit(0)["shield_turns"] = 2
	var broken: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var broken_hit := _event_of(broken.get("events", []), "hit")
	eq(int(broken_hit.get("shield_absorbed", -1)), 10, "broken shield absorbs its remaining pool")
	eq(bool(broken_hit.get("shield_broken", false)), true, "shield_broken is set when the pool hits 0")
	eq(int(broken_hit.get("damage", -1)), 6, "overflow past the shield is still 6")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 74, "overflow still reduces HP")
	eq(int(_sim.snapshot()["units"][0]["shield"]), 0, "broken shield pool is 0")
	eq(int(_sim.snapshot()["units"][0]["shield_turns"]), 0, "broken shield clears its turns")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"rolls": [1],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	var plain: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var plain_hit := _event_of(plain.get("events", []), "hit")
	eq(bool(plain_hit.get("immunity_absorbed", true)), false, "an unmitigated hit is not immunity")
	eq(int(plain_hit.get("shield_absorbed", -1)), 0, "an unmitigated hit absorbs no shield")
	eq(int(plain_hit.get("intercepted", -1)), 0, "a 1v1 hit does not intercept")
	eq(_event_of(plain.get("events", []), "intercept").is_empty(), true, "1v1 emits no Intercept event")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 64, "unmitigated Strike stays 16")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"rolls": [1],
	})
	var guard: Dictionary = _sim._make_unit(0, "bastion", "Bastion", "earth", Vector2i(3, 4), "N", true)
	_sim._units.append(guard)
	_sim.submit({"type": "end_turn", "seat": 0})
	var guarded: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var guard_hit := _event_of(guarded.get("events", []), "hit")
	var intercept := _event_of(guarded.get("events", []), "intercept")
	eq(int(intercept.get("interceptor_seat", -1)), 0, "Intercept names the Bastion seat")
	eq(int(intercept.get("for_seat", -1)), 0, "Intercept names the ally seat")
	eq(intercept.get("interceptor_cell"), Vector2i(3, 4), "Intercept names the Bastion cell")
	eq(intercept.get("for_cell"), Vector2i(3, 3), "Intercept names the ally cell")
	eq(int(intercept.get("damage", -1)), 6, "Intercept transfers round 40% of 16")
	eq(int(intercept.get("hp", -1)), 74, "Bastion HP after the transfer is 74")
	eq(int(guard_hit.get("intercepted", -1)), 6, "hit records the intercepted amount")
	eq(int(guard_hit.get("damage", -1)), 10, "the ally still takes the remainder")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 70, "ally HP loss stays 10")
	eq(int(guard["hp"]), 74, "Bastion HP loss stays 6")
	eq(bool(guard.get("intercept_used", false)), true, "Intercept is still spent for the turn")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"kestrel_hit_immunity": 1,
		"rolls": [1],
		"fixture": true,
	})
	eq(_host.submit({"type": "end_turn"})["ok"], true, "host hands Ironjaw the turn")
	var cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "strike", "to": Vector2i(3, 3)}, 1)
	var packed: Dictionary = _host.pack_result(cast, 0)
	var decoded: Variant = _IntentCodec.decode(packed)
	var wire := _event_of((decoded as Dictionary).get("events", []), "hit")
	eq(bool(wire.get("immunity_absorbed", false)), true, "packed hit keeps immunity_absorbed")
	eq(int(wire.get("immunity_amount", -1)), 16, "packed hit keeps immunity_amount")
	_guest.apply_packed_state(packed)
	var guest := _event_of(_guest.snapshot().get("last_events", []), "hit")
	eq(bool(guest.get("immunity_absorbed", false)), true, "guest hit keeps immunity_absorbed")
	eq(int(_guest.snapshot()["units"][0]["hp"]), 80, "guest HP matches the immune host")


func _test_shade_and_plant_snapshot() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	eq((_sim.snapshot().get("shade_tokens", null) as Array).is_empty(), true, "a match with no Shades lists none")
	eq((_sim.snapshot().get("plant_tiles", null) as Array).is_empty(), true, "a match with no Plants lists none")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	eq(bool(_sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 1), "seat": 0}).get("ok", false)), true, "Shade places")
	eq(bool(_sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 2), "seat": 0}).get("ok", false)), true, "second Shade places")
	var shades: Array = _sim.snapshot()["shade_tokens"]
	eq(shades.size(), 2, "snapshot lists both Shade tokens")
	eq(shades[0].get("pos"), Vector2i(2, 1), "first Shade pos")
	eq(int(shades[0].get("x", -1)), 2, "first Shade x")
	eq(int(shades[0].get("y", -1)), 1, "first Shade y")
	eq(int(shades[0].get("turns", -1)), 3, "Shade duration is 3")
	eq(int(shades[0].get("owner_seat", -1)), 0, "Shade owner is Gloam's seat")
	eq(shades[1].get("pos"), Vector2i(2, 2), "second Shade pos")
	eq(int(_sim.snapshot()["units"][0]["shades"]), 2, "unit Shade count stays 2")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	eq(bool(_sim.submit({"type": "cast", "spell": "plant", "to": Vector2i(3, 1), "seat": 0}).get("ok", false)), true, "Plant places")
	var plants: Array = _sim.snapshot()["plant_tiles"]
	eq(plants.size(), 1, "snapshot lists the Plant")
	eq(plants[0].get("pos"), Vector2i(3, 1), "Plant pos")
	eq(int(plants[0].get("turns", -1)), 3, "Plant duration is 3")
	eq(int(plants[0].get("owner_seat", -1)), 0, "Plant owner is Bastion's seat")
	eq(bool(plants[0].get("push_resist", false)), true, "Plant still resists the next push")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "bastion"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"fixture": true,
	})
	var shade_cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 2)}, 0)
	var packed: Dictionary = _host.pack_result(shade_cast, 1)
	var decoded: Variant = _IntentCodec.decode(packed)
	var wire_shades: Array = (decoded as Dictionary).get("snapshot", {}).get("shade_tokens", [])
	eq(wire_shades.size(), 1, "packed snapshot includes the Shade")
	eq(wire_shades[0].get("pos"), Vector2i(2, 2), "packed Shade pos survives encode")
	_guest.apply_packed_state(packed)
	var guest_shades: Array = _guest.snapshot()["shade_tokens"]
	eq(guest_shades.size(), 1, "guest rebuilds the Shade token")
	eq(guest_shades[0].get("pos"), Vector2i(2, 2), "guest Shade pos matches the host")
	eq(int(guest_shades[0].get("turns", -1)), 3, "guest Shade turns match the host")
	eq(int(_guest.snapshot()["units"][0]["shades"]), 1, "guest unit Shade count matches the token")

	_host.submit_for_seat({"type": "end_turn"}, 0)
	var plant_cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "plant", "to": Vector2i(5, 6)}, 1)
	eq(bool(plant_cast.get("ok", false)), true, "host Plant resolves")
	_guest.apply_packed_state(_host.pack_result(plant_cast, 0))
	var guest_plants: Array = _guest.snapshot()["plant_tiles"]
	eq(guest_plants.size(), 1, "guest rebuilds the Plant")
	eq(guest_plants[0].get("pos"), Vector2i(5, 6), "guest Plant pos matches the host")
	eq(bool(guest_plants[0].get("push_resist", false)), true, "guest Plant keeps push resist")
	eq((_guest.snapshot().get("shade_tokens", []) as Array).size(), 1, "guest still has the Shade after Plant")


func _live_unit(seat: int) -> Dictionary:
	for unit in _sim._units:
		if int(unit["seat"]) == seat:
			return unit
	return {}


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
