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
	_test_every_blend_and_reaction_is_logged()


## A combo or reaction the sim can fire, with no log line, fails here.
## The setup tables must name every scanned blend id and reaction tag.
const _BLEND_CASES := {
	"spark": {
		"hit": "water", "residue": "air", "at": Vector2i(5, 5), "foe": Vector2i(6, 5),
		"damage": 10, "debuffs": ["Healing"],
	},
	"drift_pin": {
		"hit": "air", "residue": "earth", "at": Vector2i(13, 5), "foe": Vector2i(14, 5),
		"damage": 8, "debuffs": ["Pin"],
	},
	"magma": {
		"hit": "fire", "residue": "earth", "at": Vector2i(5, 5), "foe": Vector2i(6, 5),
		"damage": 0, "debuffs": [],
		"line": "Magma: Ironjaw on Kestrel, Burn 3 stacks for 2 turns, no shields for 1 turn.",
		"stacks": 3,
	},
	"mire": {
		"hit": "earth", "residue": "water", "at": Vector2i(5, 5), "foe": Vector2i(6, 5),
		"damage": 0, "debuffs": ["Mire"],
	},
	"steam": {
		"hit": "fire", "residue": "water", "at": Vector2i(5, 5), "foe": Vector2i(6, 5),
		"damage": 0, "debuffs": ["Steam"],
	},
	"flare": {
		"hit": "air", "residue": "fire", "at": Vector2i(5, 5), "foe": Vector2i(6, 5),
		"damage": 0, "debuffs": ["Burn"], "reveal": true,
	},
}
const _REACTION_CASES := {
	"water_slow": {"element": "water", "text": "Water slow -1 MP for 1 turn"},
	"fire_burn": {"element": "fire", "text": "Burn stack 1, 4 HP for 2 turns"},
	"residue": {"element": "earth", "text": "Residue Earth for 2 turns"},
	"grounded": {"element": "earth", "text": "Grounded for 1 turn"},
	"air_mp": {"element": "air", "text": "Air +1 MP"},
	"unbound": {"element": "water", "text": "Unbound", "unbound": true},
}


func _test_every_blend_and_reaction_is_logged() -> void:
	var snap := _snap()
	var blend_ids: Array = LOG.blend_ids()
	truthy(blend_ids.size() >= 6, "the sim scan found element combos")
	eq(blend_ids.size(), _sim.BLENDS.size(), "the scan lists every blend")
	for raw_id in blend_ids:
		var blend_id := str(raw_id)
		truthy(_BLEND_CASES.has(blend_id), "no log coverage for combo %s" % blend_id)
		if not _BLEND_CASES.has(blend_id):
			continue
		var spec: Dictionary = _BLEND_CASES[blend_id]
		_assert_blend_logged(blend_id, spec)
	var tags: Array = LOG.reaction_tags()
	truthy(tags.size() >= 6, "the sim scan found element reactions")
	for raw_tag in tags:
		var tag := str(raw_tag)
		truthy(_REACTION_CASES.has(tag), "no log coverage for reaction %s" % tag)
		if not _REACTION_CASES.has(tag):
			continue
		var reaction: Dictionary = _REACTION_CASES[tag]
		var sample := {
			"type": "hit", "seat": 0, "target_seat": 1, "spell": "strike", "damage": 4,
			"riders": [tag],
			"water_mp": 1, "water_turns": 1,
			"burn_stacks": 1, "burn_remaining": 2, "burn_tick": 4,
			"residue": "earth", "residue_turns": 2,
			"grounded_turns": 1,
		}
		var formatted := LOG.plain(sample, snap)
		truthy(formatted.contains(str(reaction["text"])), "reaction %s is not logged: %s" % [tag, formatted])
		_assert_reaction_logged(tag, reaction)
	_assert_mire_unbound_logged()
	_assert_hidden_spark_logged()
	_assert_magma_shield_blocked()
	_assert_utility_residue_logged()


func _assert_blend_logged(blend_id: String, spec: Dictionary) -> void:
	var at: Vector2i = spec["at"]
	var foe: Vector2i = spec["foe"]
	if bool(spec.get("reveal", false)):
		_sim.reset_match({
			"seed": 3,
			"flat_board": true,
			"skip_deploy": true,
			"team_size": 2,
			"rolls": [1, 1, 1, 1],
			"classes": ["ironjaw", "kestrel", "mender", "gloam"],
			"positions": [at, foe, Vector2i(1, 1), foe + Vector2i(1, 1)],
		})
		_sim._active_seat = 0
		var hidden: Dictionary = _sim._unit_by_seat(3)
		hidden["invisible"] = true
		hidden["invisible_turns"] = 2
	else:
		_open_duel(at, foe)
	var element := str(spec["hit"])
	var actor: Dictionary = _sim._unit_by_seat(0)
	actor["spell_elements"] = {"strike": element, "shoulder": element, "crush": element}
	var body: Dictionary = _sim._unit_by_seat(1)
	body["residue"] = str(spec["residue"])
	body["residue_seat"] = 0
	body["residue_turns"] = 2
	var cast: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "seat": 0, "to": foe})
	eq(bool(cast.get("ok", false)), true, "%s cast connects" % blend_id)
	var row := _find(_sim.snapshot()["battle_log"], "blend")
	eq(str(row.get("blend", "")), blend_id, "%s is in the fight log" % blend_id)
	eq(int(row.get("damage", -1)), int(spec["damage"]), "%s log keeps the extra damage" % blend_id)
	var debuffs: Array = row.get("debuffs", []) if row.get("debuffs", []) is Array else []
	var wanted: Array = spec["debuffs"]
	eq(debuffs.size(), wanted.size(), "%s log lists each debuff" % blend_id)
	for i in wanted.size():
		var debuff: Dictionary = debuffs[i]
		eq(str(debuff.get("name", "")), str(wanted[i]), "%s debuff name" % blend_id)
		truthy(int(debuff.get("turns", 0)) > 0, "%s debuff keeps a duration" % blend_id)
	var owner := LOG.plain(row, _view(0))
	var enemy := LOG.plain(row, _view(1))
	eq(owner, enemy, "%s reads the same on both seats: %s" % [blend_id, owner])
	var title := str(row.get("name", ""))
	truthy(owner.contains(title) and owner.contains("Ironjaw") and owner.contains("Kestrel"), "%s names the combo, the cause, and the target: %s" % [blend_id, owner])
	if int(spec["damage"]) > 0:
		truthy(owner.contains("-%d HP" % int(spec["damage"])), "%s names the extra damage: %s" % [blend_id, owner])
	for debuff_name in wanted:
		truthy(owner.contains(str(debuff_name)) and owner.contains("turn"), "%s names the debuff and its duration: %s" % [blend_id, owner])
	if str(spec.get("line", "")) != "":
		eq(owner, str(spec["line"]), "%s log line: %s" % [blend_id, owner])
	if int(spec.get("stacks", -1)) >= 0:
		eq(int(row.get("burn_stacks", -1)), int(spec["stacks"]), "%s log keeps the Burn stacks" % blend_id)
		eq(int(_sim._unit_by_seat(1).get("burn_stacks", -1)), int(spec["stacks"]), "%s leaves that many stacks" % blend_id)
	eq(owner.contains("("), false, "%s log has no tile: %s" % [blend_id, owner])
	if bool(spec.get("reveal", false)):
		truthy(owner.contains("reveals Gloam"), "%s names who it revealed: %s" % [blend_id, owner])
		var whole := LOG.text(_sim.snapshot()["battle_log"], _view(1))
		eq(whole.contains("(7,"), false, "a revealed Gloam's tile stays out of the log: %s" % whole)


func _assert_reaction_logged(tag: String, spec: Dictionary) -> void:
	_open_duel(Vector2i(5, 5), Vector2i(6, 5))
	var element := str(spec["element"])
	var actor: Dictionary = _sim._unit_by_seat(0)
	actor["spell_elements"] = {"strike": element, "shoulder": element, "crush": element}
	if bool(spec.get("unbound", false)):
		var body: Dictionary = _sim._unit_by_seat(1)
		body["unbound"] = true
		body["unbound_ready"] = true
	var cast: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(6, 5)})
	eq(bool(cast.get("ok", false)), true, "%s cast connects" % tag)
	var row := _find(_sim.snapshot()["battle_log"], "hit")
	var riders: Array = row.get("riders", []) if row.get("riders", []) is Array else []
	truthy(riders.has(tag), "%s is on the logged hit" % tag)
	var line := LOG.plain(row, _view(0))
	var other := LOG.plain(row, _view(1))
	eq(line, other, "%s reads the same on both seats: %s" % [tag, line])
	truthy(line.contains(str(spec["text"])), "%s is logged from the fight: %s" % [tag, line])
	eq(line.contains("("), false, "%s log has no tile: %s" % [tag, line])
	if bool(spec.get("unbound", false)):
		eq(line.contains("Water slow"), false, "Unbound is what the log records: %s" % line)


func _assert_mire_unbound_logged() -> void:
	_open_duel(Vector2i(5, 5), Vector2i(6, 5))
	var actor: Dictionary = _sim._unit_by_seat(0)
	actor["spell_elements"] = {"strike": "earth", "shoulder": "earth", "crush": "earth"}
	var body: Dictionary = _sim._unit_by_seat(1)
	body["residue"] = "water"
	body["residue_seat"] = 0
	body["residue_turns"] = 2
	body["unbound"] = true
	body["unbound_ready"] = true
	var cast: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(6, 5)})
	eq(bool(cast.get("ok", false)), true, "Unbound Mire cast connects")
	var row := _find(_sim.snapshot()["battle_log"], "blend")
	eq(str(row.get("blend", "")), "mire", "Unbound still logs the Mire combo")
	eq(str(row.get("ignored", "")), "Unbound", "the log event records that Unbound ignored it")
	var line := LOG.plain(row, _view(1))
	truthy(line.contains("Mire") and line.contains("Ironjaw") and line.contains("Kestrel") and line.contains("Unbound ignores it"), "Unbound Mire is logged: %s" % line)
	eq(line.contains("("), false, "Unbound Mire has no tile: %s" % line)


func _assert_hidden_spark_logged() -> void:
	_open_duel(Vector2i(5, 5), Vector2i(6, 5), ["ironjaw", "gloam"])
	var actor: Dictionary = _sim._unit_by_seat(0)
	actor["spell_elements"] = {"strike": "water", "shoulder": "air", "crush": "air"}
	var gloam: Dictionary = _sim._unit_by_seat(1)
	gloam["residue"] = "air"
	gloam["residue_seat"] = 0
	gloam["residue_turns"] = 2
	gloam["invisible"] = true
	gloam["invisible_turns"] = 2
	var cast: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(6, 5)})
	eq(bool(cast.get("ok", false)), true, "spark on a hidden Gloam connects")
	var row := _find(_sim.snapshot()["battle_log"], "blend")
	eq(str(row.get("blend", "")), "spark", "the hidden Spark is in the fight log")
	var owner := LOG.plain(row, _view(0))
	var enemy := LOG.plain(row, _view(1))
	var hot := LOG.plain(row, _view(-1))
	eq(owner, enemy, "a hidden Spark reads the same for both seats: %s" % owner)
	eq(owner, hot, "hot-seat keeps the Spark line: %s" % hot)
	truthy(owner.contains("Spark") and owner.contains("Ironjaw") and owner.contains("Gloam"), "hidden Spark names both fighters: %s" % owner)
	truthy(owner.contains("-10 HP") and owner.contains("Healing") and owner.contains("for 1 turn"), "hidden Spark names the chip and the debuff: %s" % owner)
	eq(owner.contains("(") or owner.contains("6, 5") or owner.contains("6,5"), false, "hidden Spark keeps the tile out: %s" % owner)
	# Hurt reveals Gloam. Hide them again so the opponent's wire still drops the cell.
	_sim._unit_by_seat(1)["invisible"] = true
	var snap: Dictionary = _sim.snapshot()
	var net: Node = root.get_node("NetSession")
	var viewed: Dictionary = net._redact_invisible_for_viewer(snap, [], 0)
	var kept: Dictionary = net._redact_invisible_for_viewer(snap, [], 1)
	var enemy_row := _find(viewed["snapshot"].get("battle_log", []), "blend")
	var owner_row := _find(kept["snapshot"].get("battle_log", []), "blend")
	eq(enemy_row.get("to", Vector2i.ZERO), null, "the enemy wire drops the hidden Spark tile")
	eq(enemy_row.get("from", Vector2i.ZERO), null, "the enemy wire drops the hidden Spark origin")
	eq(str(enemy_row.get("name", "")), "Spark", "the enemy wire keeps the combo name")
	eq(int(enemy_row.get("damage", 0)), 10, "the enemy wire keeps the Spark damage")
	var debuffs: Array = enemy_row.get("debuffs", []) if enemy_row.get("debuffs", []) is Array else []
	truthy(not debuffs.is_empty() and str(debuffs[0].get("name", "")) == "Healing" and int(debuffs[0].get("turns", 0)) == 1, "the enemy wire keeps the Spark debuff")
	truthy(owner_row.get("to", null) != null, "Gloam's own wire keeps the tile")
	var enemy_view: Dictionary = viewed["snapshot"]
	enemy_view["local_seat"] = 0
	var owner_view: Dictionary = kept["snapshot"]
	owner_view["local_seat"] = 1
	var enemy_line := LOG.plain(enemy_row, enemy_view)
	var owner_line := LOG.plain(owner_row, owner_view)
	eq(enemy_line, owner_line, "both phones show the same Spark line: %s" % enemy_line)
	truthy(enemy_line.contains("Spark") and enemy_line.contains("-10 HP") and enemy_line.contains("Healing"), "the redacted line still records Spark: %s" % enemy_line)
	eq(enemy_line.contains("("), false, "the redacted Spark line has no tile: %s" % enemy_line)


func _assert_magma_shield_blocked() -> void:
	_open_duel(Vector2i(5, 5), Vector2i(6, 5), ["ironjaw", "bastion"])
	var actor: Dictionary = _sim._unit_by_seat(0)
	actor["spell_elements"] = {"strike": "fire", "shoulder": "earth", "crush": "earth"}
	var bastion: Dictionary = _sim._unit_by_seat(1)
	bastion["residue"] = "earth"
	bastion["residue_seat"] = 0
	bastion["residue_turns"] = 2
	var cast: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "seat": 0, "to": Vector2i(6, 5)})
	eq(bool(cast.get("ok", false)), true, "Magma on Bastion connects")
	var row := _find(_sim.snapshot()["battle_log"], "blend")
	var line := LOG.plain(row, _view(0))
	eq(line, LOG.plain(row, _view(1)), "Magma reads the same on both seats: %s" % line)
	eq(line, "Magma: Ironjaw on Bastion, Burn 3 stacks for 2 turns, no shields for 1 turn.", "Magma names the stacks and the 1-turn lock: %s" % line)
	eq(line.contains("("), false, "Magma log has no tile: %s" % line)
	bastion = _sim._unit_by_seat(1)
	eq(int(bastion.get("no_shield", 0)), 1, "Magma writes the shield lock")
	eq(int(bastion.get("burn_remaining", 0)), 2, "Magma burn lasts 2 turns")
	bastion["shield"] = 18
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(int(_sim._unit_by_seat(1).get("shield", 0)), 18, "the Burn tick leaves the old shield")
	eq(int(_sim._unit_by_seat(1).get("no_shield", 0)), 0, "the lock ends as his turn starts")
	eq(int(_sim._unit_by_seat(1).get("burn_stacks", 0)), 3, "he is still burning")
	bastion = _sim._unit_by_seat(1)
	bastion["ap"] = 6
	bastion["aegis"] = 4
	var offered := false
	for intent in _sim.legal_intents(1):
		if str(intent.get("spell", "")) == "ward":
			offered = true
	eq(offered, true, "on his next turn Ward is offered while he still burns")
	var ward: Dictionary = _sim.submit({"type": "cast", "spell": "ward", "seat": 1, "to": bastion["pos"]})
	eq(bool(ward.get("ok", false)), true, "Ward resolves while he is still burning")
	eq(int(_sim._unit_by_seat(1).get("shield", 0)), 38, "Ward adds 20 on top of the old shield")
	eq(_find(_sim.snapshot()["battle_log"], "shield_blocked").is_empty(), true, "a Ward that lands is not a blocked-shield line")
	# An ally in range is shielded. The burning body is the blocked line, and he pays.
	_sim.reset_match({
		"seed": 3, "flat_board": true, "skip_deploy": true, "team_size": 2,
		"classes": ["bastion", "kestrel", "mender", "gloam"],
		"positions": [Vector2i(4, 4), Vector2i(10, 10), Vector2i(5, 4), Vector2i(12, 12)],
		"bastion_aegis": 4,
	})
	var caster: Dictionary = _sim._unit_by_seat(0)
	caster["burn_stacks"] = 3
	caster["burn_remaining"] = 2
	caster["no_shield"] = 1
	caster["shield"] = 12
	var paid: Dictionary = _sim.submit({"type": "cast", "spell": "ward", "seat": 0, "to": caster["pos"]})
	eq(bool(paid.get("ok", false)), true, "Ward resolves for the clean ally")
	eq(int(_sim._unit_by_seat(2).get("shield", 0)), 20, "the clean ally is shielded")
	eq(int(_sim._unit_by_seat(0).get("shield", 0)), 12, "the shield-locked Bastion is not shielded")
	var blocked := _find(_sim.snapshot()["battle_log"], "shield_blocked")
	eq(str(blocked.get("source", "")), "Ward", "the blocked event names Ward")
	eq(int(blocked.get("target_seat", -1)), 0, "the blocked event names Bastion's seat")
	var blocked_line := LOG.plain(blocked, _view(0))
	eq(blocked_line, LOG.plain(blocked, _view(1)), "the blocked line matches on both seats: %s" % blocked_line)
	eq(blocked_line, "Shield blocked (Ward). Bastion cannot take a shield.", "a refused shield is logged: %s" % blocked_line)
	eq(blocked_line.contains(","), false, "the blocked line has no tile: %s" % blocked_line)


func _assert_utility_residue_logged() -> void:
	_open_duel(Vector2i(5, 5), Vector2i(6, 5), ["bastion", "kestrel"])
	_sim._active_seat = 0
	var bastion: Dictionary = _sim._unit_by_seat(0)
	bastion["spell_elements"] = {"bash": "earth", "plant": "water", "hold_line": "earth", "snap_wall": "water", "ward": "earth"}
	bastion["aegis"] = 4
	var wall: Dictionary = _sim.submit({"type": "cast", "spell": "snap_wall", "seat": 0, "to": Vector2i(5, 6)})
	eq(bool(wall.get("ok", false)), true, "Snap Wall resolves for the log")
	var row := _find(_sim.snapshot()["battle_log"], "snap_wall")
	var owner_lines: Array = LOG.lines(row, _view(0))
	var enemy_lines: Array = LOG.lines(row, _view(1))
	eq(owner_lines, enemy_lines, "Snap Wall Residue reads the same on both seats")
	var joined := " ".join(owner_lines)
	truthy(joined.contains("Snap Wall: Residue Water on Kestrel."), "Snap Wall Residue line: %s" % joined)
	eq(joined.contains("("), false, "Snap Wall Residue has no tile: %s" % joined)
	var bash: Dictionary = _sim.submit({"type": "cast", "spell": "bash", "seat": 0, "to": Vector2i(6, 5)})
	eq(bool(bash.get("ok", false)), true, "Earth Bash connects for Mire")
	var blend := _find(_sim.snapshot()["battle_log"], "blend")
	var blend_line := LOG.plain(blend, _view(0))
	eq(blend_line, LOG.plain(blend, _view(1)), "Mire reads the same on both seats: %s" % blend_line)
	truthy(blend_line.contains("Mire") and blend_line.contains("Bastion") and blend_line.contains("Kestrel"), "Mire names both fighters: %s" % blend_line)
	var whole := LOG.text(_sim.snapshot()["battle_log"], _view(1))
	var residue_at := whole.find("Snap Wall: Residue Water on Kestrel.")
	var mire_at := whole.find("Mire:")
	truthy(residue_at >= 0 and mire_at > residue_at, "Residue is logged before Mire: %s" % whole)
	eq(whole.contains("("), false, "the wall and the Blend keep tiles out: %s" % whole)

	_open_duel(Vector2i(5, 5), Vector2i(6, 5), ["gloam", "kestrel"])
	_sim._active_seat = 0
	var gloam: Dictionary = _sim._unit_by_seat(0)
	gloam["spell_elements"] = {"cut": "air", "drop_shade": "air", "ambush": "air", "fade": "water"}
	var faded: Dictionary = _sim.submit({"type": "cast", "spell": "fade", "seat": 0, "to": Vector2i(5, 5)})
	eq(bool(faded.get("ok", false)), true, "Fade resolves")
	eq(str(_sim._unit_by_seat(1).get("residue", "")), "water", "Fade marks the adjacent enemy")
	var snap: Dictionary = _sim.snapshot()
	var net: Node = root.get_node("NetSession")
	var viewed: Dictionary = net._redact_invisible_for_viewer(snap, [], 1)
	var kept: Dictionary = net._redact_invisible_for_viewer(snap, [], 0)
	var enemy_row := _find(viewed["snapshot"].get("battle_log", []), "cast")
	var owner_row := _find(kept["snapshot"].get("battle_log", []), "cast")
	eq(enemy_row.get("caster_cell", Vector2i.ZERO), null, "the enemy wire drops hidden Gloam's cell")
	truthy(owner_row.get("caster_cell", null) != null, "Gloam's own wire keeps the cell")
	var marked: Array = enemy_row.get("residue_on", []) if enemy_row.get("residue_on", []) is Array else []
	truthy(not marked.is_empty(), "the enemy wire still carries the Residue seats")
	for item in marked:
		var rec: Dictionary = item
		eq(rec.has("to") or rec.has("pos") or rec.has("cell") or rec.has("from"), false, "Residue rows have no tile")
	var enemy_view: Dictionary = viewed["snapshot"]
	enemy_view["local_seat"] = 1
	var owner_view: Dictionary = kept["snapshot"]
	owner_view["local_seat"] = 0
	var fade_lines: Array = LOG.lines(enemy_row, enemy_view)
	eq(fade_lines, LOG.lines(owner_row, owner_view), "both phones show the same Fade Residue")
	var fade_text := " ".join(fade_lines)
	truthy(fade_text.contains("Fade: Residue Water on Kestrel."), "Fade Residue line: %s" % fade_text)
	eq(fade_text.contains("(") or fade_text.contains("5, 5") or fade_text.contains("5,5"), false, "Fade Residue keeps the tile out: %s" % fade_text)

	_open_duel(Vector2i(4, 5), Vector2i(5, 5), ["kestrel", "ironjaw"])
	_sim._active_seat = 0
	var kestrel: Dictionary = _sim._unit_by_seat(0)
	kestrel["spell_elements"] = {"mark_shot": "air", "detonate": "air", "vault": "water", "snare_trap": "water"}
	var vault: Dictionary = _sim.submit({"type": "cast", "spell": "vault", "seat": 0, "to": Vector2i(6, 5)})
	eq(bool(vault.get("ok", false)), true, "Vault resolves")
	var vault_row := _find(_sim.snapshot()["battle_log"], "cast")
	var vault_text := " ".join(LOG.lines(vault_row, _view(0)))
	eq(vault_text, " ".join(LOG.lines(vault_row, _view(1))), "Vault Residue matches on both seats")
	truthy(vault_text.contains("Vault: Residue Water on Ironjaw."), "Vault Residue line: %s" % vault_text)
	eq(vault_text.contains("("), false, "Vault Residue has no tile: %s" % vault_text)


func _open_duel(at: Vector2i, foe: Vector2i, classes: Array = ["ironjaw", "kestrel"]) -> void:
	_sim.reset_match({
		"seed": 3,
		"flat_board": true,
		"skip_deploy": true,
		"rolls": [1, 1, 1, 1],
		"classes": classes,
		"positions": [at, foe],
	})


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
	var trap_line := LOG.plain(trap_event, owner)
	truthy(trap_line.contains("Snare Trap") and not trap_line.contains("(3,4)"), "trap line has no tile: %s" % trap_line)
	eq(LOG.plain(trap_event, enemy).contains("(3,4)"), false, "enemy does not see the trap tile")
	var sprung := LOG.plain({"type": "trap", "seat": 0, "target_seat": 1, "to": Vector2i(3, 4), "damage": 6, "pin": true}, enemy)
	truthy(sprung.contains("Ironjaw") and sprung.contains("-6") and sprung.contains("Pinned"), "sprung trap names victim and damage: %s" % sprung)
	var push := LOG.lines({
		"type": "hit", "seat": 0, "target_seat": 1, "spell": "shoulder", "damage": 8,
		"ap_spent": 3, "ap_left": 3, "mp_left": 3, "pushed": true, "pulled": false,
		"push_from": Vector2i(5, 2), "push_to": Vector2i(7, 2), "slow_applied": true,
	}, snap)
	truthy(str(push[0]).contains("HIT") and str(push[0]).contains("-3 AP"), "hit names AP: %s" % str(push[0]))
	truthy(push.size() > 1 and str(push[1]).contains("pushed 2 tiles") and str(push[1]).contains("into mud") and not str(push[1]).contains("(5,2)"), "push names the slide without a tile: %s" % str(push[1]))
	var pull := LOG.plain({
		"type": "hit", "seat": 1, "target_seat": 0, "damage": 4, "pushed": true, "pulled": true,
		"push_from": Vector2i(2, 2), "push_to": Vector2i(3, 2),
	}, snap)
	eq(pull.contains("pulled"), false, "the hit line stays the hit")
	truthy(str(LOG.lines({
		"type": "hit", "seat": 1, "target_seat": 0, "damage": 4, "pushed": true, "pulled": true,
		"push_from": Vector2i(2, 2), "push_to": Vector2i(3, 2),
	}, snap)[1]).contains("pulled"), "pull is its own line")
	var held := LOG.lines({
		"type": "hit", "seat": 0, "target_seat": 1, "spell": "hold_line", "damage": 7,
		"pull_tiles": 0,
	}, snap)
	truthy(held.size() > 1 and str(held[1]).contains("pulled 0 tiles"), "a pull of 0 is logged: %s" % str(held[1]))
	var yanked := LOG.lines({
		"type": "hit", "seat": 0, "target_seat": 1, "spell": "hold_line", "damage": 7,
		"pushed": true, "pulled": true, "pull_tiles": 3,
		"push_from": Vector2i(5, 1), "push_to": Vector2i(2, 1),
	}, snap)
	truthy(str(yanked[1]).contains("pulled 3 tiles"), "Hold Line logs the pull distance: %s" % str(yanked[1]))
	var bounce := LOG.plain({"type": "push_bounce", "target_seat": 1, "reason": "wall", "stagger_hp": 4, "stagger_mp": 1}, snap)
	truthy(bounce.contains("wall") and bounce.contains("-4 HP"), "bounce names the wall and damage: %s" % bounce)
	var blocked := LOG.plain({"type": "push_blocked", "target_seat": 1, "reason": "occupied"}, snap)
	truthy(blocked.contains("fighter"), "blocked push names the fighter: %s" % blocked)
	var slow := LOG.plain({"type": "slow", "target_seat": 1, "mp_delta": -2, "mp_left": 1, "ap_left": 6, "remaining": 0}, snap)
	truthy(slow.contains("Slow -2 MP (last turn)") and slow.contains("MP 1") and not slow.contains("ends"), "last slow tick is named: %s" % slow)
	var slow_more := LOG.plain({"type": "slow", "target_seat": 1, "mp_delta": -1, "mp_left": 2, "ap_left": 6, "remaining": 1}, snap)
	truthy(slow_more.contains("Slow") and slow_more.contains("-1 MP") and not slow_more.contains("last turn"), "an earlier slow tick stays open: %s" % slow_more)
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
	var sand_event := {
		"type": "still", "still": "gathered_sand", "seat": 0, "target_seat": 1, "damage": 4, "pos": Vector2i(5, 7),
	}
	var sand_owner := snap.duplicate(true)
	sand_owner["local_seat"] = 0
	var sand_enemy := snap.duplicate(true)
	sand_enemy["local_seat"] = 1
	eq(LOG.plain(sand_event, sand_owner), "Gathered Sand: Kestrel reflects 4 to Ironjaw.", "Gathered Sand names both fighters")
	eq(LOG.plain(sand_event, sand_enemy), LOG.plain(sand_event, sand_owner), "both phones show the same reflect line")
	eq(LOG.plain(sand_event, sand_owner).contains("("), false, "the reflect line has no tile")
	var tide := LOG.plain({"type": "still", "still": "tide", "seat": 0, "cleared": ["Slow", "Burn"]}, snap)
	truthy(tide.contains("Tide cleansed Slow, Burn"), "tide names what it cleaned: %s" % tide)
	var vault := LOG.plain({
		"type": "cast", "spell": "vault", "seat": 0, "from": Vector2i(2, 2), "to": Vector2i(2, 4),
		"ap_spent": 3, "ap_left": 3, "mp_left": 3,
	}, snap)
	truthy(vault.contains("vaults") and vault.contains("-3 AP") and not vault.contains("(2,2)"), "vault names the jump without a tile: %s" % vault)
	var grouped := LOG.text([
		{"type": "turn_start", "seat": 0, "turn": 1, "ap_left": 6, "mp_left": 3},
		{"type": "move", "seat": 0, "from": Vector2i(2, 2), "to": Vector2i(2, 3), "path": [Vector2i(2, 3)], "mp_spent": 1, "ap_left": 6, "mp_left": 2},
	], snap)
	truthy(grouped.contains("Turn 1 · Kestrel") and grouped.contains("walks 1"), "turns group the lines: %s" % grouped)
	var hidden := snap.duplicate(true)
	hidden["local_seat"] = 1
	hidden["units"][0]["invisible"] = true
	var hidden_walk := {
		"type": "move", "seat": 0, "from": Vector2i(2, 2), "to": Vector2i(2, 3),
		"path": [Vector2i(2, 3)], "mp_spent": 1, "ap_left": 6, "mp_left": 2,
		"facing": "S", "concealed_seats": [0],
	}
	var walked := LOG.plain(hidden_walk, hidden)
	eq(walked, "Kestrel moves while hidden.", "an invisible walk hides the step: %s" % walked)
	var own_snap := hidden.duplicate(true)
	own_snap["local_seat"] = 0
	var own_walk := LOG.plain(hidden_walk, own_snap)
	truthy(own_walk.contains("walks 1") and own_walk.contains("-1 MP") and not own_walk.contains("(2,"), "the owner keeps the step count: %s" % own_walk)
	var hot := hidden.duplicate(true)
	hot["local_seat"] = -1
	eq(LOG.plain(hidden_walk, hot), "Kestrel moves while hidden.", "hot-seat hides the walk while they are hidden")
	var faced := LOG.plain({"type": "face", "seat": 0, "dir": "E", "concealed_seats": [0]}, hidden)
	eq(faced, "Kestrel (hidden) acts.", "a hidden turn hides facing: %s" % faced)
	var sprung_hidden := LOG.plain({
		"type": "trap", "target_seat": 0, "to": Vector2i(2, 3), "damage": 6, "pin": true, "concealed_seats": [0],
	}, hidden)
	eq(sprung_hidden, "Kestrel moves while hidden.", "a hidden step hides the trap: %s" % sprung_hidden)
	var shoved := LOG.lines({
		"type": "hit", "seat": 1, "target_seat": 0, "spell": "shoulder", "damage": 0,
		"pushed": true, "push_from": Vector2i(2, 2), "push_to": Vector2i(2, 3), "slow_applied": true,
		"concealed_seats": [0],
	}, hidden)
	var shove_text := " ".join(shoved)
	eq(shove_text.contains("mud") or shove_text.contains("tile") or shove_text.contains("(2,"), false, "a hidden shove hides the slide: %s" % shove_text)
	truthy(shove_text.contains("moves while hidden"), "a hidden shove is only movement: %s" % shove_text)
	var revealed_snap := hidden.duplicate(true)
	revealed_snap["units"][0]["invisible"] = false
	var shown := LOG.plain(hidden_walk, revealed_snap)
	truthy(shown.contains("walks 1") and not shown.contains("(2,"), "once visible, the step count shows and the tile does not: %s" % shown)
	var hot_later := revealed_snap.duplicate(true)
	hot_later["local_seat"] = -1
	truthy(LOG.plain(hidden_walk, hot_later).contains("walks 1") and not LOG.plain(hidden_walk, hot_later).contains("(2,"), "hot-seat shows the step once they are visible")


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
	truthy(walk_line.contains("walks") and walk_line.contains("MP") and not walk_line.contains("("), "walk line names MP without a tile: %s" % walk_line)
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
	var enemy_walk := LOG.plain(hidden_move, _view(1))
	eq(enemy_walk, "Gloam moves while hidden.", "enemy log hides the fade walk: %s" % enemy_walk)
	var gloam_walk := LOG.plain(hidden_move, _view(0))
	truthy(gloam_walk.contains("walks") and not gloam_walk.contains("(3,"), "gloam still sees his own step count: %s" % gloam_walk)
	var hot_walk := LOG.plain(hidden_move, _view(-1))
	eq(hot_walk, "Gloam moves while hidden.", "hot-seat hides the fade walk: %s" % hot_walk)


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
	var laid_line := LOG.plain(cast, _view(0))
	truthy(laid_line.contains("Snare Trap") and not laid_line.contains("(4,6)"), "owner log names the trap without a tile: %s" % laid_line)
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
	_sim.submit({"type": "move", "seat": 0, "to": Vector2i(3, 4)})
	_sim.submit({"type": "face", "seat": 0, "dir": "E"})
	var snap: Dictionary = _sim.snapshot()
	var net := root.get_node("NetSession")
	var viewed: Dictionary = net._redact_invisible_for_viewer(snap, [], 1)
	var hidden := false
	var move_hidden := false
	var face_hidden := false
	for event in viewed["snapshot"].get("battle_log", []):
		if str(event.get("spell", "")) == "fade":
			hidden = event.get("caster_cell", Vector2i.ZERO) == null
		if str(event.get("type", "")) == "move":
			move_hidden = event.get("from", Vector2i.ZERO) == null and not event.has("path") and not event.has("mp_spent") and not event.has("facing") and not event.has("coach")
		if str(event.get("type", "")) == "face":
			face_hidden = not event.has("dir")
	truthy(hidden, "the enemy wire drops the fade tile from the log")
	truthy(move_hidden, "the enemy wire drops the hidden walk")
	truthy(face_hidden, "the enemy wire drops the hidden facing")
	var enemy_view: Dictionary = viewed["snapshot"]
	enemy_view["local_seat"] = 1
	var enemy_line := ""
	for event in enemy_view.get("battle_log", []):
		if str(event.get("type", "")) == "move":
			enemy_line = LOG.plain(event, enemy_view)
	eq(enemy_line, "Gloam moves while hidden.", "the enemy client cannot rebuild the walk: %s" % enemy_line)
	var owner: Dictionary = net._redact_invisible_for_viewer(snap, [], 0)
	var kept := false
	var move_kept := false
	for event in owner["snapshot"].get("battle_log", []):
		if str(event.get("spell", "")) == "fade" and event.get("caster_cell", null) != null:
			kept = true
		if str(event.get("type", "")) == "move" and event.has("path") and int(event.get("mp_spent", 0)) > 0:
			move_kept = true
	truthy(kept, "gloam's own wire keeps the fade tile")
	truthy(move_kept, "gloam's own wire keeps the walk")
	_sim._unit_by_seat(0)["invisible"] = false
	var later: Dictionary = _sim.snapshot()
	var after: Dictionary = net._redact_invisible_for_viewer(later, [], 1)
	var walk_back := false
	for event in after["snapshot"].get("battle_log", []):
		if str(event.get("type", "")) != "move":
			continue
		walk_back = event.get("to", null) != null and event.has("path")
	truthy(walk_back, "the walk tile returns once Gloam is visible")


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
