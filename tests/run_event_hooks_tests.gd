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
	_test_expiry_events()
	_test_death_cause()
	_test_triage_on_heals()
	_test_cleanse_cc_removed()
	_test_fade_and_heartstop_linger()


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
		"positions": [gloam, Vector2i(4, 2)],
		"kestrel_facing": "W",
		"gloam_invisible": true,
		"rolls": [1],
	})
	var ambush: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": Vector2i(4, 2), "seat": 0})
	var ambush_hit := _event_of(ambush.get("events", []), "hit")
	eq(ambush_hit.get("caster_cell"), gloam, "Ambush hit caster_cell is the cell before the jump")
	eq(_sim.snapshot()["units"][0]["pos"], Vector2i(5, 2), "Ambush still lands on the empty back cell")
	var plant_from := Vector2i(2, 4)
	var shade_at := Vector2i(2, 2)
	var prey := Vector2i(4, 2)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [plant_from, prey],
		"rolls": [100],
	})
	eq(_sim.chebyshev(plant_from, shade_at), 2, "Ambush miss plant is Chebyshev 2 from Gloam")
	eq(_sim.is_cardinal_exact(shade_at, prey, 2), true, "Ambush miss plant is Manhattan 2 cardinal from the prey")
	var ambush_shade: Dictionary = _sim.submit({"type": "cast", "spell": "drop_shade", "to": shade_at, "seat": 0})
	eq(bool(ambush_shade.get("ok", false)), true, "Ambush miss fixture plants a Shade Manhattan 2 cardinal from the prey")
	_sim.submit({"type": "end_turn", "seat": 0})
	_sim.submit({"type": "end_turn", "seat": 1})
	var ambush_miss: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(_event_of(ambush_miss.get("events", []), "miss").get("caster_cell"), plant_from, "Ambush miss caster_cell is Gloam")
	eq(_sim.snapshot()["units"][0]["pos"], plant_from, "Ambush miss still does not teleport")


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
	var prey := Vector2i(4, 2)
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
	eq(hit.get("destination"), Vector2i(5, 2), "Invisible Ambush destination is the empty back tile")
	eq(bool(hit.get("teleported", false)), true, "Invisible Ambush hit teleported")
	eq(int(_sim.snapshot()["units"][0]["shades"]), shades_before, "Invisible origin still does not spend Shade")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 50, "true back stays 22 × 1.35 = 30")

	# Auto Shade lands at (0, 0). The prey sits Manhattan 2 cardinal from that cell.
	# The Shade arms only after the opponent completes a turn.
	var near := Vector2i(2, 0)
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, near],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"rolls": [100],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	_sim.submit({"type": "end_turn", "seat": 1})
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": near, "seat": 0})
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
		"positions": [gloam, near],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"rolls": [1],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	_sim.submit({"type": "end_turn", "seat": 1})
	var shade_cast: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": near, "seat": 0})
	var shade_hit := _event_of(shade_cast.get("events", []), "hit")
	eq(shade_hit.get("origin"), shade_cell, "Shade Ambush origin is the Shade cell")
	eq(shade_hit.get("destination"), Vector2i(3, 0), "Shade Ambush destination is the empty back tile")
	eq(bool(shade_hit.get("teleported", false)), true, "Shade Ambush hit teleported")
	eq(int(_sim.snapshot()["units"][0]["shades"]), 0, "Shade origin still spends one Shade")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 50, "empty back stays 22 × 1.35 = 30")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, prey],
		"kestrel_facing": "W",
		"gloam_shade": true,
		"gloam_invisible": true,
		"rolls": [1],
		"blockers": [Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 2), Vector2i(6, 3)],
	})
	var shades_blocked := int(_sim.snapshot()["units"][0]["shades"])
	var blocked: Dictionary = _sim.submit({"type": "cast", "spell": "ambush", "to": prey, "seat": 0})
	eq(bool(blocked.get("illegal", false)), true, "blocked back is an illegal Ambush")
	eq(_event_of(blocked.get("events", []), "hit").is_empty(), true, "blocked back emits no hit")
	eq(_event_of(blocked.get("events", []), "reject").get("reason"), "illegal_back", "blocked back reject reason is illegal_back")
	eq(_sim.snapshot()["units"][0]["pos"], gloam, "blocked back does not teleport")
	eq(int(_sim.snapshot()["units"][0]["shades"]), shades_blocked, "blocked back does not spend Shade")
	eq(bool(_sim.snapshot()["units"][0]["invisible"]), true, "blocked back keeps Invisible")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 80, "blocked back deals no damage")

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
	var owner_packed: Dictionary = _host.pack_result(packed_cast, 0)
	var owner_decoded: Variant = _IntentCodec.decode(owner_packed)
	var owner_wire := _event_of((owner_decoded as Dictionary).get("events", []), "hit")
	eq(owner_wire.get("origin"), gloam, "owner Ambush origin survives encode")
	eq(owner_wire.get("destination"), Vector2i(5, 2), "owner Ambush destination survives encode")
	var packed: Dictionary = _host.pack_result(packed_cast, 1)
	var decoded: Variant = _IntentCodec.decode(packed)
	var wire := _event_of((decoded as Dictionary).get("events", []), "hit")
	eq(wire.get("origin"), null, "opponent Ambush origin is redacted")
	eq(wire.get("destination"), null, "opponent Ambush destination is redacted")
	eq(bool(wire.get("invisible_retained", false)), true, "opponent Ambush hit still keeps Invisible")
	eq(_sim.snapshot()["units"][0]["pos"], Vector2i(5, 2), "authority Ambush landing stays on the sim")
	_guest.apply_packed_state(packed)
	var guest := _event_of(_guest.snapshot().get("last_events", []), "hit")
	eq(guest.get("origin"), null, "guest Ambush origin stays redacted")
	eq(guest.get("destination"), null, "guest Ambush destination stays redacted")
	eq(_unit_in(_guest.snapshot(), 0).get("pos"), null, "guest snapshot redacts the Invisible landing")


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
	eq(int(shades[0].get("opponent_turns_completed", -1)), 0, "a fresh Shade has not seen an opponent turn")
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
	eq(int(wire_shades[0].get("opponent_turns_completed", -1)), 0, "packed Shade keeps the arming clock")
	eq(int(guest_shades[0].get("opponent_turns_completed", -1)), 0, "guest Shade keeps the arming clock")
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


func _test_expiry_events() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	_sim.submit({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 1), "seat": 0})
	var early: Dictionary = _sim.submit({"type": "end_turn", "seat": 0})
	eq(_expire(early.get("events", []), "shade").is_empty(), true, "Shade does not expire on the enemy turn-start")
	eq(int(_sim.snapshot()["shade_tokens"][0]["turns"]), 3, "enemy turn-start does not tick Shade (stays 3)")
	eq(int(_sim.snapshot()["shade_tokens"][0]["opponent_turns_completed"]), 0, "the caster ending a turn does not arm their own Shade")
	var armed: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(int(_sim.snapshot()["shade_tokens"][0]["opponent_turns_completed"]), 1, "the opponent completing a turn arms the Shade")
	eq(int(_sim.snapshot()["shade_tokens"][0]["turns"]), 2, "first Gloam turn-start ticks Shade 3 to 2")
	eq(_expire(armed.get("events", []), "shade").is_empty(), true, "Shade does not expire on the first owner tick")
	_sim.submit({"type": "end_turn", "seat": 0})
	var mid: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(int(_sim.snapshot()["shade_tokens"][0]["turns"]), 1, "second Gloam turn-start ticks Shade 2 to 1")
	eq(_expire(mid.get("events", []), "shade").is_empty(), true, "Shade does not expire on the second owner tick")
	_sim.submit({"type": "end_turn", "seat": 0})
	var shade_end: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	var shade_expire := _expire(shade_end.get("events", []), "shade")
	eq(shade_expire.get("pos"), Vector2i(2, 1), "Shade expiry names the token cell")
	eq(int(shade_expire.get("owner_seat", -2)), 0, "Shade expiry names the owner")
	eq((_sim.snapshot().get("shade_tokens", []) as Array).is_empty(), true, "expired Shade leaves the snapshot after 3 owner turn-starts")
	eq(int(_sim.snapshot()["units"][0]["shades"]), 0, "expired Shade clears the unit count")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "Shade expiry does not change HP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	_sim.submit({"type": "cast", "spell": "plant", "to": Vector2i(2, 1), "seat": 0})
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(int(_sim.snapshot()["plant_tiles"][0]["turns"]), 3, "enemy turn-start does not tick Plant")
	_sim.submit({"type": "end_turn", "seat": 1})
	eq(int(_sim.snapshot()["plant_tiles"][0]["turns"]), 2, "first Bastion turn-start ticks Plant 3 to 2")
	_sim.submit({"type": "end_turn", "seat": 0})
	_sim.submit({"type": "end_turn", "seat": 1})
	eq(int(_sim.snapshot()["plant_tiles"][0]["turns"]), 1, "second Bastion turn-start ticks Plant 2 to 1")
	_sim.submit({"type": "end_turn", "seat": 0})
	var plant_end: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	var plant_expire := _expire(plant_end.get("events", []), "plant")
	eq(plant_expire.get("pos"), Vector2i(2, 1), "Plant expiry names the tile")
	eq(int(plant_expire.get("owner_seat", -2)), 0, "Plant expiry names Bastion")
	eq((_sim.snapshot().get("plant_tiles", []) as Array).is_empty(), true, "expired Plant leaves the snapshot after 3 owner turn-starts")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"bastion_aegis": 2,
	})
	_sim.submit({"type": "cast", "spell": "snap_wall", "to": Vector2i(2, 1), "seat": 0})
	var wall_enemy: Dictionary = _sim.submit({"type": "end_turn", "seat": 0})
	eq(_expire(wall_enemy.get("events", []), "wall").is_empty(), true, "wall does not expire on the enemy turn-start")
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 2, "enemy turn-start leaves Snap Wall at 2")
	var wall_tick: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(_expire(wall_tick.get("events", []), "wall").is_empty(), true, "wall does not expire on the first Bastion turn-start")
	eq(int(_sim.snapshot()["blocked_tiles"][0]["turns"]), 1, "first Bastion turn-start ticks 2 to 1")
	_sim.submit({"type": "end_turn", "seat": 0})
	var wall_end: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	var wall_expire := _expire(wall_end.get("events", []), "wall")
	eq(wall_expire.get("pos"), Vector2i(2, 1), "wall expiry names the blocked cell")
	eq(int(wall_expire.get("owner_seat", -2)), 0, "wall expiry names Bastion")
	eq((_sim.snapshot().get("blocked_tiles", []) as Array).is_empty(), true, "expired wall leaves blocked_tiles")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_pulse": 2,
		"rolls": [1],
	})
	var ward: Dictionary = _sim.submit({"type": "cast", "spell": "ward", "to": Vector2i(1, 1), "seat": 0})
	eq(bool(ward.get("ok", false)), true, "Ward connects before the shield clock")
	_sim.submit({"type": "end_turn", "seat": 0})
	var shield_mid: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(_expire(shield_mid.get("events", []), "shield").is_empty(), true, "shield does not expire on its first tick")
	eq(int(_sim.snapshot()["units"][0]["shield"]), 20, "shield amount stays 20 after one tick")
	eq(int(_sim.snapshot()["units"][0]["shield_turns"]), 1, "shield turns tick 2 to 1")
	_sim.submit({"type": "end_turn", "seat": 0})
	var shield_end: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	var shield_expire := _expire(shield_end.get("events", []), "shield")
	eq(shield_expire.get("pos"), Vector2i(1, 1), "shield expiry names the unit cell")
	eq(int(shield_expire.get("target_seat", -2)), 0, "shield expiry names the warded seat")
	eq(int(_sim.snapshot()["units"][0]["shield"]), 0, "expired shield amount is 0")
	eq(int(_sim.snapshot()["units"][0]["shield_turns"]), 0, "expired shield turns are 0")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "shield expiry does not change HP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "W",
		"ironjaw_impact": 4,
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	_sim.submit({"type": "cast", "spell": "crush", "to": Vector2i(3, 3), "seat": 1})
	var skipped: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(_expire(skipped.get("events", []), "stun").is_empty(), true, "the skipped stun turn is not the expiry")
	eq(bool(_sim.snapshot()["units"][0]["stunned"]), true, "Kestrel is still stunned for the skip")
	var stun_end: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	var stun_expire := _expire(stun_end.get("events", []), "stun")
	eq(stun_expire.get("pos"), Vector2i(3, 3), "Stun expiry names the unit cell")
	eq(int(stun_expire.get("target_seat", -2)), 0, "Stun expiry names Kestrel")
	eq(bool(_sim.snapshot()["units"][0]["stunned"]), false, "Stun is clear on the following turn")
	eq(int(_sim.snapshot()["units"][0]["stun_remaining"]), 0, "Stun remaining stays 0")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"fixture": true,
	})
	_host.submit_for_seat({"type": "cast", "spell": "drop_shade", "to": Vector2i(2, 1)}, 0)
	_host.submit_for_seat({"type": "end_turn"}, 0)
	_host.submit_for_seat({"type": "end_turn"}, 1)
	_host.submit_for_seat({"type": "end_turn"}, 0)
	_host.submit_for_seat({"type": "end_turn"}, 1)
	_host.submit_for_seat({"type": "end_turn"}, 0)
	# Third owner turn-start (seat 1 ends, Gloam's turn begins) is the expiry.
	var host_end: Dictionary = _host.submit_for_seat({"type": "end_turn"}, 1)
	var packed: Dictionary = _host.pack_result(host_end, 1)
	var decoded: Variant = _IntentCodec.decode(packed)
	var wire := _expire((decoded as Dictionary).get("events", []), "shade")
	eq(wire.get("pos"), Vector2i(2, 1), "packed Shade expiry survives encode")
	_guest.apply_packed_state(packed)
	var guest := _expire(_guest.snapshot().get("last_events", []), "shade")
	eq(guest.get("pos"), Vector2i(2, 1), "guest Shade expiry matches the host")
	eq((_guest.snapshot().get("shade_tokens", [1]) as Array).is_empty(), true, "guest snapshot drops the expired Shade")


func _test_death_cause() -> void:
	var hot: Dictionary = _hot_submit_after({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"kestrel_hp": 16,
		"rolls": [1],
	}, {"type": "end_turn", "seat": 0})
	var strike: Dictionary = hot["session"].submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	hot["session"].free()
	var dead := _event_of(strike.get("events", []), "dead")
	eq(str(dead.get("cause", "")), "damage", "hot-seat lethal Strike cause is damage")
	eq(int(dead.get("seat", -1)), 0, "lethal Strike dead event names Kestrel")
	eq(int(_event_of(strike.get("events", []), "hit").get("damage", -1)), 16, "lethal Strike damage stays 16")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 0, "lethal Strike still removes the last 16 HP")
	eq(int(_sim.snapshot()["units"][1]["ap"]), 3, "lethal Strike still spends 3 AP")
	eq(bool(_sim.snapshot()["units"][0]["alive"]), false, "lethal Strike still marks the unit dead")
	eq(bool(_sim.snapshot()["match_over"]), true, "lethal Strike still ends the match")
	eq(int(_sim.snapshot()["winner_seat"]), 1, "Ironjaw still wins the lethal Strike")

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
	var lived: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	eq(_event_of(lived.get("events", []), "dead").is_empty(), true, "a non-lethal Strike emits no dead event")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 64, "non-lethal Strike still deals 16")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
	})
	_live_unit(0)["hp"] = 4
	_live_unit(0)["burn_remaining"] = 1
	_sim.submit({"type": "end_turn", "seat": 0})
	var burned: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	var burn_dead := _event_of(burned.get("events", []), "dead")
	eq(str(burn_dead.get("cause", "")), "burn", "lethal Burn tick cause is burn")
	eq(int(_event_of(burned.get("events", []), "burn").get("hp_delta", 0)), -4, "lethal Burn tick is still 4 HP")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 0, "Burn tick still reduces HP to 0")
	eq(bool(_sim.snapshot()["units"][0]["alive"]), false, "Burn tick still marks the victim dead")
	eq(int(_sim.snapshot()["winner_seat"]), 1, "Ironjaw still wins a lethal Burn")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"kestrel_hp": 16,
		"rolls": [1],
		"fixture": true,
	})
	eq(_host.submit_for_seat({"type": "end_turn"}, 0)["ok"], true, "host hands Ironjaw the lethal Strike turn")
	var host_strike: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "strike", "to": Vector2i(3, 3)}, 1)
	var packed: Dictionary = _host.pack_result(host_strike, 0)
	var decoded: Variant = _IntentCodec.decode(packed)
	eq(str(_event_of((decoded as Dictionary).get("events", []), "dead").get("cause", "")), "damage", "packed dead cause survives encode")
	_guest.apply_packed_state(packed)
	eq(str(_event_of(_guest.snapshot().get("last_events", []), "dead").get("cause", "")), "damage", "guest dead cause is damage")
	eq(int(_guest.snapshot()["units"][0]["hp"]), 0, "guest HP matches the lethal host")
	eq(int(_guest.snapshot()["winner_seat"]), 1, "guest winner matches the host")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(6, 6),
		"fixture": true,
	})
	_live_unit(0)["hp"] = 4
	_live_unit(0)["burn_remaining"] = 1
	_host.submit_for_seat({"type": "end_turn"}, 0)
	var host_burn: Dictionary = _host.submit_for_seat({"type": "end_turn"}, 1)
	_guest.apply_packed_state(_host.pack_result(host_burn, 0))
	eq(str(_event_of(_guest.snapshot().get("last_events", []), "dead").get("cause", "")), "burn", "guest Burn death cause is burn")
	eq(int(_guest.snapshot()["units"][0]["hp"]), 0, "guest Burn death HP matches the host")


func _test_triage_on_heals() -> void:
	var hot: Dictionary = _hot_submit_after({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 31,
		"rolls": [1],
	}, {"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	hot["session"].free()
	var mend := _event_of(hot["result"].get("events", []), "hit")
	eq(bool(mend.get("triage", false)), true, "hot-seat Mend sets triage below 40% HP")
	eq(int(mend.get("healed", -1)), 20, "Triage Mend still heals 16 × 1.25")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 51, "Triage Mend HP stays 51")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 1, "Triage Mend still gains 1 Pulse")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 3, "Triage Mend still spends 3 AP")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 32,
		"rolls": [1],
	})
	var at_line: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	var line_hit := _event_of(at_line.get("events", []), "hit")
	eq(line_hit.has("triage"), false, "Mend at 40% HP omits triage")
	eq(int(line_hit.get("healed", -1)), 16, "Mend at 40% HP still heals 16")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 48, "Mend at 40% HP stays 48")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 31,
		"rolls": [100],
	})
	var missed: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	eq(_event_of(missed.get("events", []), "miss").has("triage"), false, "Mend miss does not stamp triage")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 31, "Mend miss still does not heal")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 31,
		"mender_pulse": 1,
		"rolls": [1],
	})
	var tap: Dictionary = _sim.submit({"type": "cast", "spell": "pulse_tap", "to": Vector2i(1, 1), "seat": 0})
	var tap_hit := _event_of(tap.get("events", []), "hit")
	eq(bool(tap_hit.get("triage", false)), true, "Pulse Tap sets triage below 40% HP")
	eq(int(tap_hit.get("healed", -1)), 13, "Triage Pulse Tap still heals round(10 × 1.25)")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 44, "Triage Pulse Tap HP stays 44")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 0, "Pulse Tap still spends 1 Pulse")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 31,
		"mender_pulse": 4,
		"rolls": [1],
	})
	var ally: Dictionary = _sim.submit({"type": "cast", "spell": "heartstop", "to": Vector2i(1, 1), "seat": 0})
	var ally_hit := _event_of(ally.get("events", []), "hit")
	eq(bool(ally_hit.get("triage", false)), true, "ally Heartstop sets triage below 40% HP")
	eq(int(ally_hit.get("healed", -1)), 40, "Triage Heartstop still heals 32 × 1.25")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 71, "Triage Heartstop HP stays 71")
	eq(int(ally_hit.get("hit_immunity", -1)), 1, "ally Heartstop still grants 1 immunity hit")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"kestrel_hp": 20,
		"mender_pulse": 4,
		"rolls": [1],
	})
	var enemy: Dictionary = _sim.submit({"type": "cast", "spell": "heartstop", "to": Vector2i(3, 1), "seat": 0})
	var enemy_hit := _event_of(enemy.get("events", []), "hit")
	eq(enemy_hit.has("triage"), false, "enemy Heartstop does not stamp triage")
	eq(int(enemy_hit.get("damage", -1)), 10, "enemy Heartstop damage stays 10")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 10, "enemy Heartstop still leaves 10 HP")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 31,
		"rolls": [1],
		"fixture": true,
	})
	var host_mend: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "mend", "to": Vector2i(1, 1)}, 0)
	var packed: Dictionary = _host.pack_result(host_mend, 1)
	var decoded: Variant = _IntentCodec.decode(packed)
	eq(bool(_event_of((decoded as Dictionary).get("events", []), "hit").get("triage", false)), true, "packed Mend keeps triage")
	_guest.apply_packed_state(packed)
	eq(bool(_event_of(_guest.snapshot().get("last_events", []), "hit").get("triage", false)), true, "guest Mend keeps triage")
	eq(int(_guest.snapshot()["units"][0]["hp"]), 51, "guest Triage HP matches the host")


func _test_cleanse_cc_removed() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})
	var empty: Dictionary = _sim.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(1, 1), "seat": 0})
	var empty_hit := _event_of(empty.get("events", []), "hit")
	eq(empty_hit.has("cc_removed"), true, "Cleanse always carries cc_removed")
	eq(_string_list(empty_hit.get("cc_removed")), [], "Cleanse with no CC lists nothing")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 1, "Cleanse with no CC still gains 1 Pulse")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 4, "Cleanse still spends 2 AP")

	# A stunned unit cannot cast. Cleanse is observed on a same-seat ally.
	_reset_mender()
	_add_same_seat_ally(1, false, 0)
	var hot_script := load("res://backend/net_session.gd")
	var hot: Node = hot_script.new()
	hot.attach_sim(_sim)
	var hot_cast: Dictionary = hot.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(2, 1), "seat": 0})
	hot.free()
	var stunned := _event_of(hot_cast.get("events", []), "hit")
	eq(_string_list(stunned.get("cc_removed")), ["stun"], "hot-seat Cleanse lists stun")
	var cleared := _unit_at(_sim.snapshot(), Vector2i(2, 1))
	eq(int(cleared.get("stun_remaining", -1)), 0, "Cleanse still clears stun_remaining")
	eq(bool(cleared.get("stunned", true)), false, "Cleanse still clears stunned")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 1, "Cleanse of Stun still gains 1 Pulse")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 4, "Cleanse of Stun still spends 2 AP")

	_reset_mender()
	_add_same_seat_ally(1, true, 2)
	var both: Dictionary = _sim.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(2, 1), "seat": 0})
	eq(_string_list(_event_of(both.get("events", []), "hit").get("cc_removed")), ["stun"], "Stun flags collapse to one id")
	var burned := _unit_at(_sim.snapshot(), Vector2i(2, 1))
	eq(int(burned.get("burn_remaining", -1)), 2, "Cleanse does not clear Burn")
	eq(int(burned.get("stun_remaining", -1)), 0, "Cleanse still clears Stun beside Burn")
	eq(_string_list(_event_of(both.get("events", []), "hit").get("cc_removed")).has("burn"), false, "Burn is not reported as removed")

	_reset_mender()
	_live_unit(0)["burn_remaining"] = 2
	var burn_only: Dictionary = _sim.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(1, 1), "seat": 0})
	eq(_string_list(_event_of(burn_only.get("events", []), "hit").get("cc_removed")), [], "Burn alone leaves cc_removed empty")
	eq(int(_sim.snapshot()["units"][0]["burn_remaining"]), 2, "Burn-only Cleanse still leaves Burn")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"fixture": true,
	})
	_add_same_seat_ally(1, true, 0)
	var host_cast: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "cleanse", "to": Vector2i(2, 1)}, 0)
	var packed: Dictionary = _host.pack_result(host_cast, 1)
	var decoded: Variant = _IntentCodec.decode(packed)
	eq(_string_list(_event_of((decoded as Dictionary).get("events", []), "hit").get("cc_removed")), ["stun"], "packed cc_removed survives encode")
	_guest.apply_packed_state(packed)
	eq(_string_list(_event_of(_guest.snapshot().get("last_events", []), "hit").get("cc_removed")), ["stun"], "guest cc_removed is stun")
	eq(int(_unit_at(_guest.snapshot(), Vector2i(2, 1)).get("stun_remaining", -1)), 0, "guest Stun matches the host")


func _test_fade_and_heartstop_linger() -> void:
	var gloam := Vector2i(1, 1)
	var hot: Dictionary = _hot_submit_after({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, Vector2i(6, 6)],
	}, {"type": "cast", "spell": "fade", "to": gloam, "seat": 0})
	hot["session"].free()
	var fade := _event_of(hot["result"].get("events", []), "cast")
	eq(bool(fade.get("invisible", false)), true, "hot-seat Fade cast says Invisible is active")
	eq(int(fade.get("seat", -1)), 0, "Fade cast names the seat")
	eq(fade.get("caster_cell"), gloam, "Fade cast cell is the caster cell")
	eq(fade.has("turns"), false, "Invisible does not track remaining turns")
	var faded := _unit_in(_sim.snapshot(), 0)
	eq(bool(faded.get("invisible", false)), true, "snapshot unit is invisible")
	eq(int(faded.get("seat", -1)), 0, "snapshot Invisible names the seat")
	eq(faded.get("pos"), gloam, "snapshot Invisible names the cell")
	eq(int(_sim.snapshot()["units"][0]["umbral"]), 1, "Fade still gains 1 Umbral")
	eq(int(_sim.snapshot()["units"][0]["ap"]), 4, "Fade still spends 2 AP")
	eq(int(_sim.snapshot()["units"][0]["mp"]), 2, "Fade still spends 1 MP")
	_sim.submit({"type": "end_turn", "seat": 0})
	var later: Dictionary = _sim.submit({"type": "end_turn", "seat": 1})
	eq(bool(_unit_in(_sim.snapshot(), 0).get("invisible", false)), true, "Invisible stays after a full round")
	eq(_expire(later.get("events", []), "invisible").is_empty(), true, "Invisible does not expire")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [gloam, Vector2i(6, 6)],
		"fixture": true,
	})
	var host_fade: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "fade", "to": gloam}, 0)
	var owner_fade: Dictionary = _host.pack_result(host_fade, 0)
	var owner_fade_wire: Variant = _IntentCodec.decode(owner_fade)
	var owner_cast := _event_of((owner_fade_wire as Dictionary).get("events", []), "cast")
	eq(owner_cast.get("caster_cell"), gloam, "owner Fade pack keeps the cell")
	eq(_unit_in((owner_fade_wire as Dictionary).get("snapshot", {}), 0).get("pos"), gloam, "owner snapshot keeps the Invisible cell")
	var fade_packed: Dictionary = _host.pack_result(host_fade, 1)
	var fade_wire: Variant = _IntentCodec.decode(fade_packed)
	var wire_fade := _event_of((fade_wire as Dictionary).get("events", []), "cast")
	eq(bool(wire_fade.get("invisible", false)), true, "packed Fade keeps invisible")
	eq(wire_fade.get("caster_cell"), null, "opponent Fade pack redacts the cell")
	_guest.apply_packed_state(fade_packed)
	var guest_fade := _unit_in(_guest.snapshot(), 0)
	eq(bool(guest_fade.get("invisible", false)), true, "guest snapshot keeps Invisible")
	eq(guest_fade.get("pos"), null, "guest Invisible cell is redacted")
	eq(bool(guest_fade.get("pos_hidden", false)), true, "guest Invisible pos is marked hidden")
	eq(int(guest_fade.get("seat", -1)), 0, "guest Invisible seat matches the host")
	eq(_sim.snapshot()["units"][0]["pos"], gloam, "authority Fade cell stays on the sim")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_pulse": 4,
		"rolls": [1],
	})
	var ally: Dictionary = _sim.submit({"type": "cast", "spell": "heartstop", "to": Vector2i(1, 1), "seat": 0})
	var ally_hit := _event_of(ally.get("events", []), "hit")
	eq(int(ally_hit.get("hit_immunity", -1)), 1, "ally Heartstop hit exposes the immunity charge")
	eq(ally_hit.get("to"), Vector2i(1, 1), "ally Heartstop hit names the cell")
	eq(int(ally_hit.get("target_seat", -1)), 0, "ally Heartstop hit names the seat")
	var immune := _unit_in(_sim.snapshot(), 0)
	eq(int(immune.get("hit_immunity", -1)), 1, "snapshot keeps the immunity charge")
	eq(immune.get("pos"), Vector2i(1, 1), "immunity snapshot keeps the cell")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "full-HP Heartstop still heals 0")
	eq(int(_sim.snapshot()["units"][0]["pulse"]), 0, "Heartstop still spends 4 Pulse")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_pulse": 4,
		"rolls": [1],
		"fixture": true,
	})
	var host_ally: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "heartstop", "to": Vector2i(1, 1)}, 0)
	_guest.apply_packed_state(_host.pack_result(host_ally, 1))
	eq(int(_event_of(_guest.snapshot().get("last_events", []), "hit").get("hit_immunity", -1)), 1, "guest Heartstop hit keeps hit_immunity")
	eq(int(_unit_in(_guest.snapshot(), 0).get("hit_immunity", -1)), 1, "guest snapshot keeps hit_immunity")

	var enemy_hot: Dictionary = _hot_submit_after({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"mender_pulse": 4,
		"rolls": [1],
	}, {"type": "cast", "spell": "heartstop", "to": Vector2i(3, 1), "seat": 0})
	enemy_hot["session"].free()
	var enemy_hit := _event_of(enemy_hot["result"].get("events", []), "hit")
	eq(bool(enemy_hit.get("skip_next_mp", false)), true, "hot-seat enemy Heartstop sets skip_next_mp")
	eq(int(_sim.snapshot()["units"][1]["hp"]), 70, "enemy Heartstop damage stays 10")
	eq(bool(_unit_in(_sim.snapshot(), 1).get("skip_next_mp", false)), true, "snapshot keeps skip_next_mp")
	eq(_unit_in(_sim.snapshot(), 1).get("pos"), Vector2i(3, 1), "skip_next_mp snapshot keeps the cell")
	var skipped: Dictionary = _sim.submit({"type": "end_turn", "seat": 0})
	var skip_end := _expire(skipped.get("events", []), "skip_next_mp")
	eq(skip_end.get("pos"), Vector2i(3, 1), "skip_next_mp expire names the cell")
	eq(int(skip_end.get("target_seat", -1)), 1, "skip_next_mp expire names the seat")
	eq(bool(_unit_in(_sim.snapshot(), 1).get("skip_next_mp", true)), false, "skip_next_mp clears when the turn starts")
	eq(int(_sim.snapshot()["units"][1]["mp"]), 0, "skipped refill still sets MP to 0")
	eq(int(_sim.snapshot()["units"][1]["ap"]), 6, "skipped refill still refills AP")

	_host.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"mender_pulse": 4,
		"rolls": [1],
		"fixture": true,
	})
	var host_enemy: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "heartstop", "to": Vector2i(3, 1)}, 0)
	_guest.apply_packed_state(_host.pack_result(host_enemy, 1))
	eq(bool(_event_of(_guest.snapshot().get("last_events", []), "hit").get("skip_next_mp", false)), true, "guest hit keeps skip_next_mp")
	eq(bool(_unit_in(_guest.snapshot(), 1).get("skip_next_mp", false)), true, "guest snapshot keeps skip_next_mp")
	var host_skip: Dictionary = _host.submit_for_seat({"type": "end_turn"}, 0)
	var skip_packed: Dictionary = _host.pack_result(host_skip, 1)
	var skip_wire: Variant = _IntentCodec.decode(skip_packed)
	eq(_expire((skip_wire as Dictionary).get("events", []), "skip_next_mp").get("pos"), Vector2i(3, 1), "packed skip_next_mp expire survives encode")
	_guest.apply_packed_state(skip_packed)
	eq(_expire(_guest.snapshot().get("last_events", []), "skip_next_mp").get("pos"), Vector2i(3, 1), "guest skip_next_mp expire matches the host")
	eq(bool(_unit_in(_guest.snapshot(), 1).get("skip_next_mp", true)), false, "guest snapshot clears skip_next_mp")
	eq(int(_guest.snapshot()["units"][1]["mp"]), 0, "guest skipped MP matches the host")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "E",
		"kestrel_hit_immunity": 2,
		"rolls": [1, 1],
	})
	_sim.submit({"type": "end_turn", "seat": 0})
	var first: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	eq(_expire(first.get("events", []), "hit_immunity").is_empty(), true, "a leftover immunity charge does not expire")
	eq(int(_sim.snapshot()["units"][0]["hit_immunity"]), 1, "one immunity charge remains")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "the first charge still prevents HP loss")
	eq(int(_sim.snapshot()["units"][1]["ap"]), 3, "the first Strike still spends 3 AP")
	var second: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var spent := _expire(second.get("events", []), "hit_immunity")
	eq(spent.get("pos"), Vector2i(3, 3), "hit_immunity expire names the cell")
	eq(int(spent.get("target_seat", -1)), 0, "hit_immunity expire names the seat")
	eq(int(_sim.snapshot()["units"][0]["hit_immunity"]), 0, "the last charge is spent")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 80, "the last charge still prevents HP loss")

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
	_host.submit_for_seat({"type": "end_turn"}, 0)
	var host_break: Dictionary = _host.submit_for_seat({"type": "cast", "spell": "strike", "to": Vector2i(3, 3)}, 1)
	var break_packed: Dictionary = _host.pack_result(host_break, 0)
	var break_wire: Variant = _IntentCodec.decode(break_packed)
	eq(_expire((break_wire as Dictionary).get("events", []), "hit_immunity").get("pos"), Vector2i(3, 3), "packed hit_immunity expire survives encode")
	_guest.apply_packed_state(break_packed)
	eq(_expire(_guest.snapshot().get("last_events", []), "hit_immunity").get("pos"), Vector2i(3, 3), "guest hit_immunity expire matches the host")
	eq(int(_unit_in(_guest.snapshot(), 0).get("hit_immunity", -1)), 0, "guest snapshot spends the immunity charge")
	eq(int(_guest.snapshot()["units"][0]["hp"]), 80, "guest immune HP matches the host")


func _reset_mender() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
	})


func _add_same_seat_ally(stun_remaining: int, stunned: bool, burn_remaining: int) -> void:
	var ally: Dictionary = _sim._make_unit(0, "kestrel", "Ally", "air", Vector2i(2, 1), "W", true)
	ally["stun_remaining"] = stun_remaining
	ally["stunned"] = stunned
	ally["burn_remaining"] = burn_remaining
	_sim._units.append(ally)


func _unit_at(snap: Dictionary, cell: Vector2i) -> Dictionary:
	for unit in snap.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if unit.get("pos") == cell:
			return unit
	return {}


func _hot_submit_after(config: Dictionary, intent: Dictionary) -> Dictionary:
	_sim.reset_match(config)
	var hot_script := load("res://backend/net_session.gd")
	var hot: Node = hot_script.new()
	hot.attach_sim(_sim)
	return {"session": hot, "result": hot.submit(intent)}


func _string_list(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return out
	for item in value:
		out.append(str(item))
	return out


func _unit_in(snap: Dictionary, seat: int) -> Dictionary:
	for unit in snap.get("units", []):
		if typeof(unit) == TYPE_DICTIONARY and int(unit.get("seat", -1)) == seat:
			return unit
	return {}


func _expire(events: Variant, status: String) -> Dictionary:
	if typeof(events) != TYPE_ARRAY:
		return {}
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "expire" and str(event.get("status", "")) == status:
			return event
	return {}


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
