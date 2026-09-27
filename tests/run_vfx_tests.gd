extends SceneTree

## Event-to-effect dispatch for the view-only VFX pass.
## Run: godot --headless --path . -s res://tests/run_vfx_tests.gd

const ROUTER := preload("res://vfx/vfx_router.gd")
const DIRECTOR := preload("res://vfx/vfx_director.gd")
const BUDGET := preload("res://vfx/vfx_budget.gd")
const PALETTE := preload("res://vfx/vfx_palette.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_stamp_playback()
	await _test_mark_cast_hands()
	await _test_live_director()
	await _test_shade_markers_survive_rebuild()
	print("VFX tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_budgets()
	_test_basic_hit_and_miss()
	_test_back_and_backstab()
	_test_push_block_bounce()
	_test_lava_is_a_stub()
	_test_burn_stun_heal_death_resource()
	_test_shake_only_crush_and_aegis()
	_test_hold_line_ambush_intercept_expire()
	_test_support_and_absorb()
	_test_stacks_and_lock_cap()
	_test_every_event_type()
	_test_view_wiring_does_not_touch_rules()
	_test_class_choreography()
	_test_scenario_overlays()


func _test_budgets() -> void:
	eq(BUDGET.LOCK_MAX <= 0.6, true, "input lock cap is 0.6s")
	eq(BUDGET.SHAKE_PX, 4.0, "shake amplitude is 4px")
	eq(BUDGET.SPARK_AMOUNT <= 24, true, "spark burst stays under the particle cap")
	eq(BUDGET.SPARK_CAP, 24, "a scaled burst never passes 24 particles")
	eq(BUDGET.PUFF_AMOUNT <= 24, true, "puff burst stays under the particle cap")
	eq(BUDGET.MOTE_AMOUNT <= 24, true, "mote burst stays under the particle cap")
	eq(BUDGET.POOL_SPARK, 4, "sparks are pooled")
	eq(BUDGET.POOL_NUMBER, 6, "numbers are pooled")
	eq(BUDGET.NUMBER_STACK_PX, 22.0, "hits stack 22px apart")
	eq(BUDGET.NUMBER_RISE_PX, 28.0, "numbers rise 28px")
	eq(is_equal_approx(BUDGET.NUMBER_POP_SEC, 0.12), true, "number pop is 0.12s")
	eq(BUDGET.NUMBER_LIFE <= 0.8, true, "a number finishes as a tail")
	eq(PALETTE.number_colors("damage")["bottom"], PALETTE.DAMAGE_BOTTOM, "damage numbers are orange-red")
	eq(PALETTE.number_colors("heal")["bottom"], PALETTE.HEAL_BOTTOM, "heal numbers are green")
	eq(PALETTE.number_colors("shield")["top"], PALETTE.SHIELD_TOP, "shield numbers are grey-blue")
	eq(PALETTE.number_colors("absorb")["bottom"], PALETTE.SHIELD_BOTTOM, "absorbed numbers are grey-blue")


func _test_basic_hit_and_miss() -> void:
	var hit: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "strike",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(2, 3),
		"to": Vector2i(3, 3),
		"damage": 16,
	}])
	truthy(_has(hit, "spark"), "a damaging hit spawns a spark")
	eq(_first(hit, "number")["kind"], "damage", "a damaging hit spawns a damage number")
	eq(_first(hit, "number")["text"], "16", "the number is the event damage")
	eq(float(_first(hit, "number")["block"]), 0.0, "numbers do not lock input")
	eq(_has(hit, "shake"), false, "a normal hit does not shake")
	var miss: Array = ROUTER.recipes_for([{
		"type": "miss",
		"spell": "mark_shot",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(2, 3),
		"to": Vector2i(5, 3),
		"damage": 0,
	}])
	eq(_first(miss, "number")["text"], "MISS", "a miss shows MISS")
	eq(_first(miss, "number")["kind"], "miss", "miss text is the miss kind")
	truthy(_has(miss, "puff"), "a miss fizzles on the caster")
	eq(float(_first(miss, "projectile")["overshoot"]), 12.0, "the whiff overshoots the target")
	eq(_has(miss, "spark"), false, "a miss does not flash a spark on the target")
	var reject: Array = ROUTER.recipes_for([{"type": "reject", "reason": "no_ap"}])
	eq(reject.is_empty(), true, "a reject is not a miss")


func _test_back_and_backstab() -> void:
	var back: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "bash",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(2, 3),
		"to": Vector2i(3, 3),
		"damage": 13,
		"back": true,
		"facing_mult": 1.2,
	}])
	eq(_first(back, "number")["text"], "BACK 13", "back hits prefix BACK")
	eq(float(_first(back, "number")["scale"]), 1.15, "back numbers scale to 1.15")
	truthy(_has(back, "chevron"), "back hits add a chevron")
	var stab: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "cut",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(2, 3),
		"to": Vector2i(3, 3),
		"damage": 18,
		"back": true,
		"backstab": true,
		"facing_mult": 1.35,
	}])
	eq(_first(stab, "number")["text"], "BACKSTAB 18", "backstab hits prefix BACKSTAB")
	eq(is_equal_approx(float(_first(stab, "number")["scale"]), 1.55), true, "backstab numbers are the large float")


func _test_push_block_bounce() -> void:
	var pushed: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "shoulder",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(2, 3),
		"to": Vector2i(3, 3),
		"damage": 6,
		"pushed": true,
		"push_from": Vector2i(3, 3),
		"push_to": Vector2i(4, 3),
	}])
	eq(_first(pushed, "slide")["to"], Vector2i(4, 3), "a clean push slides to push_to")
	eq(is_equal_approx(ROUTER.blocking_sec(pushed), BUDGET.BLOCK_SLIDE), true, "push slide is the blocking beat")
	eq(ROUTER.blocking_sec(pushed) <= 0.6, true, "push lock stays under 0.6s")
	var blocked: Array = ROUTER.recipes_for([{
		"type": "push_blocked",
		"seat": 0,
		"target_seat": 1,
		"from": Vector2i(3, 3),
		"attempted": Vector2i(4, 3),
		"reason": "occupied",
	}])
	eq(_first(blocked, "jolt")["distance"], 4.0, "a blocked push jolts 4px")
	eq(_has(blocked, "slide"), false, "a blocked push does not slide")
	var planted: Array = ROUTER.recipes_for([{
		"type": "push_blocked",
		"target_seat": 1,
		"from": Vector2i(3, 3),
		"attempted": Vector2i(4, 3),
		"reason": "plant_resist",
	}])
	eq(_count(planted, "ring") >= 2, true, "plant resist flares a sigil ring")
	var bounce: Array = ROUTER.recipes_for([
		{"type": "push_bounce", "target_seat": 1, "from": Vector2i(3, 3), "attempted": Vector2i(4, 3), "stagger_hp": 4, "stagger_mp": 1},
		{"type": "stagger", "target_seat": 1, "stagger_hp": 4, "stagger_mp": 1, "hp_delta": -4, "mp_delta": -1},
	])
	eq(_first(bounce, "bounce")["distance"], 8.0, "a bounce lurches 8px")
	eq(_has(bounce, "shake"), false, "bounce does not shake the board")
	var numbers := _all(bounce, "number")
	eq(numbers[0]["text"], "-4", "stagger shows the event HP loss")
	eq(numbers[1]["text"], "-1 MP", "stagger shows the MP loss when the event has it")
	eq(float(numbers[0]["delay"]) > 0.0, true, "the stagger number is delayed behind the lurch")


func _test_lava_is_a_stub() -> void:
	var lava: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "shoulder",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(2, 3),
		"to": Vector2i(3, 3),
		"damage": 6,
		"pushed": true,
		"push_from": Vector2i(3, 3),
		"push_to": Vector2i(4, 3),
		"burn_applied": true,
	}])
	truthy(_has(lava, "lava_todo"), "lava displace keeps a TODO stub")
	eq(_has(lava, "lava_splash"), false, "lava splash is not built in this pass")
	truthy(_has(lava, "slide"), "the displace itself still uses the push slide")


func _test_burn_stun_heal_death_resource() -> void:
	var burn: Array = ROUTER.recipes_for([{"type": "burn", "target_seat": 1, "damage": 4, "hp_delta": -4, "remaining": 1}])
	eq(_first(burn, "number")["text"], "-4", "a burn tick shows the event damage")
	eq(_first(burn, "number")["kind"], "burn", "burn ticks use the burn colour")
	eq(_has(burn, "shake"), false, "a burn tick does not shake")
	truthy(_has(burn, "status_on"), "a burn tick keeps the burn marker")
	var stun: Array = ROUTER.recipes_for([{"type": "status", "status": "stun", "target_seat": 1, "remaining": 1}])
	eq(_first(stun, "status_on")["status"], "stun", "stun attaches a status marker")
	var skip: Array = ROUTER.recipes_for([{"type": "end_turn", "seat": 1, "reason": "stunned", "auto": true}])
	eq(_first(skip, "status_pulse")["status"], "stun", "a stunned skip pulses the stun marker")
	var heal: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "mend",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(3, 2),
		"healed": 16,
		"damage": 0,
		"engine": "pulse",
		"engine_gained": 1,
	}])
	truthy(_has(heal, "motes"), "a heal releases motes")
	eq(_first_kind(heal, "heal")["text"], "+16", "the heal number is the event healed amount")
	eq(_has(heal, "spark"), false, "a heal does not use the damage spark")
	eq(_has(heal, "shake"), false, "a heal does not shake")
	var dead: Array = ROUTER.recipes_for([
		{"type": "dead", "seat": 1, "name": "Ironjaw"},
		{"type": "match_over", "winner_seat": 0},
	])
	truthy(_has(dead, "death"), "death spawns the death puff")
	truthy(_has(dead, "winner"), "match over marks the winner")
	eq(_has(dead, "shake"), false, "death does not shake in this pass")
	var gained: Array = ROUTER.recipes_for([{
		"type": "advance",
		"seat": 0,
		"from": Vector2i(2, 2),
		"to": Vector2i(2, 3),
		"impact_gained": 1,
	}])
	eq(_first(gained, "number")["text"], "+1 Impact", "resource gain uses the event amount")
	eq(_first(gained, "number")["kind"], "resource", "resource text is the small kind")


func _test_shake_only_crush_and_aegis() -> void:
	ProjectSettings.set_setting("stasium/view/reduce_shake", false)
	DIRECTOR.clear_reduce_shake()
	eq(DIRECTOR.shake_pixels(true), BUDGET.SHAKE_PX, "shake defaults on")
	eq(DIRECTOR.shake_pixels(false), 0.0, "effects that are not Crush or Aegis Break do not shake")
	DIRECTOR.set_reduce_shake(true)
	eq(DIRECTOR.shake_pixels(true), 0.0, "reduce-shake zeroes the amplitude")
	DIRECTOR.clear_reduce_shake()
	ProjectSettings.set_setting("stasium/view/reduce_shake", true)
	eq(DIRECTOR.shake_pixels(true), 0.0, "the project setting can turn shake off")
	ProjectSettings.set_setting("stasium/view/reduce_shake", false)
	var crush: Array = ROUTER.recipes_for([_damage("crush", 24)])
	eq(float(_first(crush, "shake")["amplitude"]), 4.0, "Crush shakes at 4px")
	var break_hit: Array = ROUTER.recipes_for([_damage("aegis_break", 26)])
	truthy(_has(break_hit, "shake"), "Aegis Break shakes")
	eq(_has(ROUTER.recipes_for([_damage("bash", 11)]), "shake"), false, "Bash does not shake")
	eq(_has(ROUTER.recipes_for([_damage("detonate", 18)]), "shake"), false, "Detonate does not shake")
	var crush_miss: Array = ROUTER.recipes_for([{
		"type": "miss",
		"spell": "crush",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(2, 1),
		"damage": 0,
	}])
	eq(_has(crush_miss, "shake"), false, "a Crush miss does not shake")


func _test_hold_line_ambush_intercept_expire() -> void:
	var hold: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "hold_line",
		"seat": 0,
		"caster_cell": Vector2i(2, 3),
		"damage": 14,
		"bodies": 2,
		"cone": [Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 4)],
		"targets": [
			{"target_seat": 1, "cell": Vector2i(3, 3), "hit": true, "damage": 7, "back": false},
			{"target_seat": 2, "cell": Vector2i(3, 4), "hit": true, "damage": 7, "back": true, "facing_mult": 1.2},
		],
		"engine": "aegis",
		"engine_gained": 1,
	}])
	eq(_count(hold, "spark"), 2, "Hold Line sparks each listed body")
	eq(_count(hold, "ring"), 3, "Hold Line outlines the cone cells")
	var damage_texts: Array = []
	for item in _all(hold, "number"):
		if str(item.get("kind", "")) == "damage":
			damage_texts.append(str(item.get("text", "")))
	eq(damage_texts.has("14"), false, "Hold Line does not float the total as one hit")
	truthy(damage_texts.has("7"), "Hold Line floats each body's damage")
	truthy(damage_texts.has("BACK 7"), "Hold Line keeps a per-body back tag")
	var hold_miss: Array = ROUTER.recipes_for([{
		"type": "miss",
		"spell": "hold_line",
		"seat": 0,
		"caster_cell": Vector2i(2, 3),
		"damage": 0,
		"bodies": 0,
		"cone": [Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 4)],
		"targets": [{"target_seat": 1, "cell": Vector2i(3, 3), "hit": false, "damage": 0}],
	}])
	eq(_first(hold_miss, "number")["text"], "MISS", "a Hold Line miss tags the cone")
	eq(_has(hold_miss, "spark"), false, "a Hold Line miss has no body spark")
	var ambush: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "ambush",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"from": Vector2i(4, 4),
		"to": Vector2i(5, 4),
		"origin": Vector2i(2, 4),
		"destination": Vector2i(5, 4),
		"teleported": true,
		"backstab": true,
		"facing_mult": 1.35,
		"damage": 30,
		"shade_retained": false,
	}])
	eq(_has(ambush, "projectile"), false, "Ambush does not streak the body to the back tile")
	eq(_has(ambush, "slide"), false, "Ambush teleports; the body does not path from Gloam")
	eq(_first(ambush, "puff")["cell"], Vector2i(2, 4), "the collapse puff sits on the origin")
	var departure: Array = ROUTER.ambush_collapse_specs({
		"type": "hit",
		"spell": "ambush",
		"seat": 0,
		"origin": Vector2i(2, 4),
		"caster_cell": Vector2i(1, 1),
		"teleported": true,
		"damage": 30,
	})
	eq(departure.size(), 1, "the live collapse plays one departure puff")
	eq(departure[0]["cell"], Vector2i(2, 4), "the live collapse puff is the Shade or cast origin")
	eq(_sheet(departure, "ambush_slash").is_empty(), true, "the slash waits until the back-tile plant")
	eq(_sheet(departure, "damage_float").is_empty(), true, "the damage float waits until the back-tile plant")
	eq(ROUTER.ambush_collapse_specs({"type": "miss", "spell": "ambush", "seat": 0}).is_empty(), true, "an Ambush miss does not puff a departure")
	var contact: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "ambush",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"from": Vector2i(4, 4),
		"to": Vector2i(5, 4),
		"origin": Vector2i(2, 4),
		"destination": Vector2i(5, 4),
		"teleported": true,
		"present_phase": "contact",
		"backstab": true,
		"facing_mult": 1.35,
		"damage": 30,
	}])
	eq(_has(contact, "puff"), false, "the slash batch does not replay the collapse puff")
	eq(_sheet(contact, "ambush_slash").is_empty(), false, "the slash batch still stamps the strike")
	eq(_sheet(contact, "damage_float")["cell"], Vector2i(4, 4), "the contact float sits on the struck body")
	eq(is_equal_approx(float(_sheet(contact, "damage_float")["delay"]), preload("res://units/view_motion.gd").ambush_contact_sec()), true, "the damage float waits for the slash contact")
	eq(_first(ambush, "number")["cell"], Vector2i(4, 4), "facing damage sits on the enemy")
	eq(_first(ambush, "number")["text"], "BACKSTAB 30", "facing damage keeps the existing backstab resolution")
	eq(float(_first(ambush, "number").get("delay", 0.0)) > 0.0, true, "facing damage follows the slash")
	eq(_first(ambush, "status_flash")["cell"], Vector2i(4, 4), "the slash sits on the enemy")
	var ambush_miss: Array = ROUTER.recipes_for([{
		"type": "miss",
		"spell": "ambush",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(4, 3),
		"origin": Vector2i(2, 4),
		"teleported": false,
		"damage": 0,
	}])
	eq(_has(ambush_miss, "slide"), false, "an Ambush miss does not teleport")
	eq(_first(ambush_miss, "number")["text"], "MISS", "an Ambush miss still shows MISS")
	eq(_has(ambush_miss, "projectile"), false, "an Ambush miss does not streak a slash onto the enemy")
	eq(_has(ambush_miss, "stamp"), false, "an Ambush miss does not stamp a slash")
	var invisible_miss: Array = ROUTER.recipes_for([{
		"type": "miss",
		"spell": "ambush",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(12, 5),
		"to": Vector2i(14, 2),
		"origin": Vector2i(12, 5),
		"teleported": false,
		"damage": 0,
	}])
	eq(_has(invisible_miss, "projectile"), false, "Invisible Ambush miss does not slash from the caster toward the enemy")
	eq(_has(invisible_miss, "stamp"), false, "Invisible Ambush miss does not stamp a slash")
	eq(_has(invisible_miss, "slide"), false, "Invisible Ambush miss does not move")
	eq(_first(invisible_miss, "number")["text"], "MISS", "Invisible Ambush miss still reads MISS")
	eq(_first(invisible_miss, "number")["cell"], Vector2i(12, 5), "Invisible Ambush miss stays on the caster tile")
	eq(_first(invisible_miss, "puff")["cell"], Vector2i(12, 5), "Invisible Ambush miss chrome is the caster tile")
	var intercept: Array = ROUTER.recipes_for([{
		"type": "intercept",
		"interceptor_seat": 0,
		"for_seat": 1,
		"interceptor_cell": Vector2i(2, 2),
		"for_cell": Vector2i(3, 2),
		"damage": 4,
		"hp": 76,
	}])
	eq(_first(intercept, "number")["text"], "4", "intercept shows the transferred damage")
	eq(_first(intercept, "projectile")["from"], Vector2i(3, 2), "intercept streak starts on the guarded cell")
	var expired: Array = ROUTER.recipes_for([{"type": "expire", "status": "stun", "target_seat": 1, "pos": Vector2i(3, 3), "owner_seat": 1}])
	eq(_first(expired, "status_off")["status"], "stun", "expire detaches that status")


func _test_support_and_absorb() -> void:
	var ward: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "ward",
		"seat": 0,
		"target_seat": 0,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(1, 1),
		"healed": 0,
		"damage": 0,
		"shield": 20,
		"engine": "pulse",
		"engine_spent": 2,
	}])
	eq(_first_kind(ward, "shield")["text"], "+20", "Ward shows the shield value from the event")
	eq(_has(ward, "spark"), false, "Ward is not a damage spark")
	var cleanse: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "cleanse",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(2, 2),
		"healed": 0,
		"damage": 0,
		"engine_gained": 1,
	}])
	eq(_has(cleanse, "spark"), false, "Cleanse is not a damage spark")
	truthy(_has(cleanse, "puff"), "Cleanse plays a wash puff")
	var soaked: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "strike",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(2, 1),
		"damage": 4,
		"shield_absorbed": 12,
		"shield_remaining": 0,
		"shield_broken": true,
		"immunity_absorbed": false,
	}])
	eq(_first_kind(soaked, "damage")["text"], "4", "remaining damage stays a damage number")
	eq(_first_kind(soaked, "absorb")["text"], "12", "absorbed shield uses the event amount")
	ROUTER.assign_stacks(soaked)
	var stacked := _all(soaked, "number")
	eq(int(stacked[0]["stack"]), 0, "the first number on a cell is unshifted")
	eq(int(stacked[1]["stack"]), 1, "the next number on that cell stacks")
	var immune: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "strike",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(2, 1),
		"damage": 0,
		"immunity_absorbed": true,
		"immunity_amount": 16,
		"shield_absorbed": 0,
	}])
	eq(_first_kind(immune, "absorb")["text"], "16", "immunity shows the amount the event swallowed")
	eq(_has(immune, "spark"), false, "a fully absorbed hit does not spark as damage")


func _test_stacks_and_lock_cap() -> void:
	var recipes: Array = [
		{"id": "number", "seat": 1, "cell": Vector2i(4, 3), "block": 0.0},
		{"id": "slide", "block": 0.9},
		{"id": "number", "seat": 1, "cell": Vector2i(4, 3), "block": 0.0},
	]
	eq(ROUTER.blocking_sec(recipes), 0.6, "blocking time never passes 0.6s")
	for beat in ROUTER.debug_beats():
		var block := ROUTER.blocking_sec(ROUTER.recipes_for(beat["events"]))
		eq(block <= 0.6, true, "%s stays inside the input lock" % str(beat["name"]))
		for item in ROUTER.recipes_for(beat["events"]):
			if str(item.get("id", "")) == "number":
				eq(float(item.get("block", 0.0)), 0.0, "%s numbers do not lock input" % str(beat["name"]))
	eq(ROUTER.cell_of(Vector2i(3, 5)), Vector2i(3, 5), "cells pass through as Vector2i")
	eq(ROUTER.cell_of({"__v2i": true, "x": 1, "y": 2}), Vector2i(1, 2), "wire cells decode from x and y")


func _test_every_event_type() -> void:
	var samples: Array = [
		{"type": "hit", "spell": "strike", "seat": 0, "target_seat": 1, "caster_cell": Vector2i(1, 1), "to": Vector2i(2, 1), "damage": 16},
		{"type": "miss", "spell": "mark_shot", "seat": 0, "target_seat": 1, "caster_cell": Vector2i(1, 1), "to": Vector2i(4, 2), "damage": 0},
		{"type": "advance", "seat": 0, "from": Vector2i(1, 1), "to": Vector2i(1, 2), "impact_gained": 0},
		{"type": "cast", "spell": "drop_shade", "seat": 0, "caster_cell": Vector2i(1, 1), "to": Vector2i(2, 2), "shades": 1},
		{"type": "cast", "spell": "plant", "seat": 0, "caster_cell": Vector2i(1, 1), "to": Vector2i(2, 1), "engine_gained": 1},
		{"type": "cast", "spell": "fade", "seat": 0, "caster_cell": Vector2i(1, 1), "invisible": true, "engine_gained": 1},
		{"type": "snap_wall", "spell": "snap_wall", "seat": 0, "to": Vector2i(3, 3), "aegis_spent": 2, "turns": 2},
		{"type": "push_blocked", "target_seat": 1, "from": Vector2i(2, 1), "attempted": Vector2i(3, 1), "reason": "occupied"},
		{"type": "push_bounce", "target_seat": 1, "from": Vector2i(2, 1), "attempted": Vector2i(3, 1), "to": Vector2i(2, 1)},
		{"type": "stagger", "target_seat": 1, "stagger_hp": 4, "stagger_mp": 0, "hp_delta": -4, "mp_delta": 0},
		{"type": "status", "status": "burn", "target_seat": 1, "remaining": 2},
		{"type": "status", "status": "stun", "target_seat": 1, "remaining": 1},
		{"type": "burn", "target_seat": 1, "damage": 4, "hp_delta": -4, "remaining": 1},
		{"type": "dead", "seat": 1, "name": "Kestrel"},
		{"type": "match_over", "winner_seat": 0},
		{"type": "end_turn", "seat": 0, "next_seat": 1},
		{"type": "end_turn", "seat": 1, "auto": true, "reason": "stunned"},
		{"type": "turn_start", "seat": 0, "turn": 2},
		{"type": "move", "seat": 0, "from": Vector2i(1, 1), "to": Vector2i(2, 1), "path": [Vector2i(2, 1)]},
		{"type": "face", "seat": 0, "dir": "N"},
		{"type": "reject", "reason": "illegal"},
		{"type": "intercept", "interceptor_seat": 0, "for_seat": 1, "interceptor_cell": Vector2i(1, 2), "for_cell": Vector2i(2, 2), "damage": 8, "hp": 72},
		{"type": "expire", "status": "shade", "pos": Vector2i(2, 2), "owner_seat": 0},
		{"type": "expire", "status": "plant", "pos": Vector2i(2, 1), "owner_seat": 0},
		{"type": "expire", "status": "wall", "pos": Vector2i(3, 3), "owner_seat": 0},
		{"type": "expire", "status": "shield", "pos": Vector2i(1, 1), "owner_seat": 0, "target_seat": 0},
		{"type": "place", "seat": 0, "to": Vector2i(1, 1)},
		{"type": "ready", "seat": 0},
		{"type": "combat_start"},
		{"type": "deploy_start"},
		{"type": "reposition", "seat": 0},
		{},
	]
	for sample in samples:
		var recipes: Array = ROUTER.recipes_for([sample])
		eq(recipes is Array, true, "router returns recipes for %s" % str(sample.get("type", "empty")))
	var mixed: Array = ROUTER.recipes_for([null, "nope", 3, {"type": "hit", "spell": "cut", "damage": 13, "seat": 0, "target_seat": 1, "to": Vector2i(2, 2), "caster_cell": Vector2i(1, 2)}])
	truthy(_has(mixed, "spark"), "non-dictionary entries are skipped")
	var shade_cast: Array = ROUTER.recipes_for([samples[3]])
	eq(_has(shade_cast, "ring"), false, "Drop Shade does not leave a shader puddle")
	eq(_first(shade_cast, "number")["text"], "Shade", "Drop Shade floater says Shade")
	eq(_first(shade_cast, "number")["cell"], Vector2i(2, 2), "Shade floater cell is the clicked tile")
	eq(_first(shade_cast, "puff")["cell"], Vector2i(2, 2), "Shade puff cell is the clicked tile")
	eq(_first(shade_cast, "number").get("scale", 1.0) >= 1.5, true, "Drop Shade floater is larger than a resource pip")
	eq(_first(shade_cast, "number").get("outline"), VfxPalette.GLOAM, "the Shade label uses a purple outline")
	eq(_has(shade_cast, "projectile"), false, "Drop Shade pops on the tile and does not travel")
	var fade: Array = ROUTER.recipes_for([samples[5]])
	eq(_first(fade, "number")["text"], "+1 Umbral", "Fade gain uses the spell resource when the event omits engine")
	var wall: Array = ROUTER.recipes_for([samples[6]])
	eq(_first(wall, "number")["text"], "-2 Aegis", "Snap Wall spend reads aegis_spent")


func _test_view_wiring_does_not_touch_rules() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	var sim := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	var pawn := FileAccess.get_file_as_string("res://units/pawn.gd")
	truthy(view.contains("res://vfx/vfx_director.gd"), "board view mounts the VFX director")
	truthy(view.contains("_arm_vfx"), "resolve arms VFX with the motion lock")
	truthy(view.contains("is_blocking"), "the shared lock waits on VFX displacement")
	eq(view.contains("hp"), false, "board view still does not mention hp")
	eq(view.contains("randi"), false, "board view still does not roll")
	eq(sim.contains("res://vfx/"), false, "combat sim does not reference VFX")
	eq(sim.contains("VfxDirector"), false, "combat sim does not call the director")
	eq(pawn.contains("VfxDirector"), false, "pawn scripts are untouched by the VFX director")
	truthy(view.contains("play_footstep"), "a walk plant plays footstep dust")
	var names: Array = []
	for beat in ROUTER.debug_beats():
		names.append(str(beat["name"]))
	for needed in ["G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8", "G9", "G10", "G11", "G12"]:
		var found := false
		for beat_name in names:
			if str(beat_name).begins_with(needed):
				found = true
		truthy(found, "F9 includes %s" % needed)
	for needed in ["K1", "K2", "I1", "I2", "I3", "I4", "M1", "M2", "M3", "M4", "M5", "Gl1", "Gl2", "Gl3", "Gl4", "Gl5", "B1", "B2", "B3", "B4", "B5", "B6"]:
		var found_class := false
		for beat_name in names:
			if str(beat_name).begins_with(needed):
				found_class = true
		truthy(found_class, "F9 includes %s" % needed)


func _test_mark_cast_hands() -> void:
	var board_script := GDScript.new()
	board_script.source_code = "extends Node2D\nvar pawns_by_seat: Dictionary = {}\nfunc _cell_to_local(cell: Vector2i) -> Vector2:\n\treturn BoardVisualSort.cell_to_local(cell, 1.0)\nfunc _elev_at(_cell: Vector2i) -> float:\n\treturn 1.0\n"
	eq(board_script.reload() == OK, true, "mark cast board script compiles")
	var board := Node2D.new()
	board.set_script(board_script)
	root.add_child(board)
	var caster_script := GDScript.new()
	caster_script.source_code = "extends Node2D\nvar grid_position: Vector2i = Vector2i.ZERO\n"
	eq(caster_script.reload() == OK, true, "mark cast caster stub compiles")
	var caster := Node2D.new()
	caster.set_script(caster_script)
	var from_cell := Vector2i(2, 3)
	caster.grid_position = from_cell
	caster.position = board.call("_cell_to_local", from_cell)
	var body := Node2D.new()
	body.name = "BodyStrip"
	body.position = Vector2(10, -6)
	body.visible = true
	caster.add_child(body)
	board.add_child(caster)
	board.pawns_by_seat[0] = caster
	var director: Node = DIRECTOR.new()
	director.allow_headless = true
	board.add_child(director)
	director.bind_board(board)
	var east := Vector2i(4, 3)
	director.play([{
		"type": "hit", "spell": "mark_shot", "seat": 0, "target_seat": 1,
		"caster_cell": from_cell, "to": east, "damage": 8,
	}])
	var stamp := _active_sheet(director, "mark_shot_cast")
	truthy(stamp != null, "Mark Shot windup spawns a stamp")
	if stamp != null:
		var hands: Vector2 = caster.position + body.position + BUDGET.HAND_OFFSET
		eq(stamp.position, hands, "Mark Shot windup starts on the bow, not the feet")
		var floater := _active_sheet(director, "damage_float")
		truthy(floater != null, "contact resolve plays the damage float")
		if floater != null:
			var head: Vector2 = board.call("_cell_to_local", east) + BUDGET.HEAD_OFFSET
			eq(floater.position, head, "the damage float sits on the target head")
			eq(floater.position == hands, false, "the damage float is not the bow windup")
		eq(stamp.position.y < caster.position.y + BUDGET.CHEST_OFFSET.y, true, "the bow sits above the chest anchor")
		eq(stamp.z_index, BoardVisualSort.unit_z_index(from_cell, 1.0) + 2, "the bow windup draws in the air")
		var sprite := stamp.get("_sprite") as Sprite2D
		truthy(sprite != null, "the bow stamp has a sprite")
		if sprite != null:
			eq(sprite.flip_h, false, "a shot to screen-right keeps the release streaks forward")
		body.position = Vector2(-14, 3)
		await process_frame
		eq(stamp.position, caster.position + body.position + BUDGET.HAND_OFFSET, "the bow windup follows the lunge")
	for node in director.get("_pools").get("stamp", []):
		if node != null and node.has_method("release"):
			node.release()
	var west := Vector2i(0, 3)
	director.play([{
		"type": "miss", "spell": "mark_shot", "seat": 0, "target_seat": 1,
		"caster_cell": from_cell, "to": west, "damage": 0,
	}])
	var flipped := _active_sheet(director, "mark_shot_cast")
	truthy(flipped != null, "a Mark Shot miss still plays the bow windup")
	if flipped != null:
		var sprite_w := flipped.get("_sprite") as Sprite2D
		truthy(sprite_w != null and sprite_w.flip_h, "a shot to screen-left flips the release streaks")
	director.free()
	board.free()


func _active_sheet(director: Node, sheet: String) -> Node2D:
	var pools: Variant = director.get("_pools")
	if typeof(pools) != TYPE_DICTIONARY:
		return null
	for node in pools.get("stamp", []):
		if node is Node2D and bool(node.get("in_use")) and str(node.get("_sheet")) == sheet:
			return node
	return null


func _test_live_director() -> void:
	var board_script := GDScript.new()
	board_script.source_code = "extends Node2D\nvar pawns_by_seat: Dictionary = {}\nfunc _cell_to_local(cell: Vector2i) -> Vector2:\n\treturn BoardVisualSort.cell_to_local(cell, 1.0)\nfunc _elev_at(_cell: Vector2i) -> float:\n\treturn 1.0\n"
	eq(board_script.reload() == OK, true, "test board script compiles")
	var board := Node2D.new()
	board.set_script(board_script)
	board.position = Vector2(480, 160)
	root.add_child(board)
	var pawn := Node2D.new()
	pawn.position = board.call("_cell_to_local", Vector2i(4, 3))
	board.add_child(pawn)
	board.pawns_by_seat[1] = pawn
	var director: Node = DIRECTOR.new()
	director.allow_headless = true
	board.add_child(director)
	director.bind_board(board)
	eq(director.pool_size("spark"), BUDGET.POOL_SPARK, "spark pool is created up front")
	eq(director.pool_size("stamp"), BUDGET.POOL_STAMP, "overlay stamps are pooled")
	eq(director.pool_size("number"), BUDGET.POOL_NUMBER, "number pool is created up front")
	eq(director.pool_size("projectile"), BUDGET.POOL_PROJECTILE, "projectile pool is created up front")
	var lifted: Vector2 = director._pos_cell(Vector2i(1, 0))
	eq(lifted, BoardVisualSort.cell_to_local(Vector2i(1, 0), 1.0), "effects use cell_to_local plus elevation")
	var quiet: Node = DIRECTOR.new()
	quiet.allow_headless = false
	board.add_child(quiet)
	eq(quiet.play([_damage("strike", 16)]), 0.0, "headless playback without the test flag does nothing")
	eq(quiet.active_count(), 0, "suppressed playback spawns nothing")
	for sample in _catalogue():
		director.play([sample], {})
	for beat in ROUTER.debug_beats():
		director.play_debug(beat["events"])
	await process_frame
	eq(director.pool_size("spark"), BUDGET.POOL_SPARK, "combat playback does not grow the spark pool")
	eq(director.pool_size("number"), BUDGET.POOL_NUMBER, "combat playback does not grow the number pool")
	eq(director.pool_size("ring"), BUDGET.POOL_RING, "combat playback does not grow the ring pool")
	eq(director.pool_size("stamp"), BUDGET.POOL_STAMP, "combat playback does not grow the stamp pool")
	director.dismiss_all()
	var caster_script := GDScript.new()
	caster_script.source_code = "extends Node2D\nvar grid_position: Vector2i = Vector2i.ZERO\n"
	eq(caster_script.reload() == OK, true, "caster stub compiles")
	var caster := Node2D.new()
	caster.set_script(caster_script)
	caster.grid_position = Vector2i(1, 1)
	caster.position = board.call("_cell_to_local", Vector2i(1, 1))
	board.add_child(caster)
	board.pawns_by_seat[0] = caster
	var shade_snap := {
		"units": [],
		"shade_tokens": [{"pos": Vector2i(2, 2), "turns": 3, "owner_seat": 0}],
	}
	director.dismiss_all()
	for child in director.get_children():
		if str(child.name).begins_with("puff") and child.has_method("release"):
			child.release()
	director.play([{
		"type": "cast",
		"spell": "drop_shade",
		"seat": 0,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(2, 2),
	}], shade_snap)
	var shade_at: Vector2 = director._pos_cell(Vector2i(2, 2))
	var floater := _effect_pos(director, "number", "Shade")
	eq(floater, shade_at + BUDGET.HEAD_OFFSET, "Shade floater draws on the clicked tile")
	eq(floater == caster.position + BUDGET.HEAD_OFFSET, false, "Shade floater does not draw on the caster")
	eq(_effect_pos(director, "puff", ""), shade_at, "Shade puff draws on the clicked tile")
	eq(director.linger_count(), 0, "a shade token is not a shader linger")
	var marker_src := FileAccess.get_file_as_string("res://board/shade_marker.gd")
	var board_src := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(marker_src.contains("Shade"), "the board marker labels the token")
	truthy(marker_src.contains("neutral_shade_token.png"), "the marker draws the TA Shade token")
	truthy(marker_src.contains("neutral_shade_tile_marker.png"), "the marker draws the TA tile decal")
	var marker_script: Script = load("res://board/shade_marker.gd")
	var cloak_top := float(marker_script.world_y(marker_script.CLOAK_TOP_SRC_Y))
	var plate_y := float(marker_script.plate_baseline_y())
	eq(plate_y < cloak_top, true, "Shade label sits above the cloak")
	eq(cloak_top - plate_y < 32.0, true, "Shade label stays on the clicked tile")
	truthy(board_src.contains("_sync_shade_markers"), "refresh places the shade on the tile")
	truthy(board_src.contains("ShadeMarkers"), "the shade token is not parented under Units")
	eq(board_src.contains("$Units.add_child(marker)"), false, "sync does not attach the marker to Units")
	director.play([{
		"type": "expire",
		"status": "shade",
		"pos": Vector2i(2, 2),
		"owner_seat": 0,
	}], {"units": [], "shade_tokens": []})
	eq(director.linger_count(), 0, "expire removes the shade ring")
	director.play([], {
		"units": [{
			"seat": 1,
			"pos": Vector2i(4, 3),
			"alive": true,
			"marks": 3,
			"invisible": true,
			"hit_immunity": 1,
			"skip_next_mp": false,
		}],
	})
	eq(director.linger_count(), 3, "snapshot marks, invisible, and immunity linger")
	director.play([], {"units": [{"seat": 1, "pos": Vector2i(4, 3), "alive": true}]})
	eq(director.linger_count(), 0, "a cleared snapshot drops those tells")
	DIRECTOR.set_reduce_shake(true)
	director.play([_damage("crush", 24)], {})
	await process_frame
	eq(board.position, Vector2(480, 160), "reduce-shake leaves the board still")
	DIRECTOR.set_reduce_shake(false)
	director.play([_damage("crush", 24)], {})
	await process_frame
	var shaken: bool = board.position.distance_to(Vector2(480, 160)) > 0.01
	truthy(shaken, "Crush offsets the board")
	eq(board.position.distance_to(Vector2(480, 160)) <= BUDGET.SHAKE_PX + 0.01, true, "the offset stays within 4px")
	director.dismiss_all()
	await create_timer(0.35).timeout
	eq(director.is_blocking(), false, "the director releases the input lock")
	DIRECTOR.clear_reduce_shake()
	ProjectSettings.set_setting("stasium/view/reduce_shake", false)
	board.queue_free()


func _test_stamp_playback() -> void:
	var stamp_script := preload("res://vfx/vfx_stamp.gd")
	var stamp: Node2D = stamp_script.new()
	root.add_child(stamp)
	await process_frame
	stamp.play({"sheet": "hit_flash", "px": 60.0, "life": 0.30, "pos": Vector2.ZERO})
	var flash: Sprite2D = stamp.get("_sprite")
	truthy(flash != null, "stamp builds its sprite")
	if flash == null:
		stamp.free()
		return
	eq(flash.region_enabled, true, "hit flash plays the strip")
	var hit_span := stamp_script.span_for("hit_flash")
	stamp._sample(0.0)
	eq(is_equal_approx(flash.scale.x * hit_span, 60.0), true, "hit flash scales the largest frame to the body size")
	var hit_first := flash.region_rect
	stamp._sample(0.55)
	eq(flash.region_rect.position.x > hit_first.position.x, true, "hit flash advances left to right")
	stamp.play({"sheet": "footstep_dust", "px": 44.0, "life": 0.30, "pos": Vector2.ZERO})
	eq(flash.region_enabled, true, "footstep dust plays the plant strip")
	var dust_span := stamp_script.span_for("footstep_dust")
	stamp._sample(0.0)
	eq(is_equal_approx(flash.scale.x * dust_span, 44.0), true, "footstep dust scales the largest puff")
	var dust_first := flash.region_rect
	stamp._sample(0.6)
	eq(flash.region_rect.position.x > dust_first.position.x, true, "footstep dust advances left to right")
	stamp.play({"sheet": "damage_float", "px": 52.0, "life": 0.28, "pos": Vector2.ZERO})
	eq(flash.region_enabled, true, "damage float plays the strip")
	var float_span := stamp_script.span_for("damage_float")
	stamp._sample(0.0)
	eq(is_equal_approx(flash.scale.x * float_span, 52.0), true, "damage float scales the largest frame")
	var float_first := flash.region_rect
	stamp._sample(0.6)
	eq(flash.region_rect.position.x > float_first.position.x, true, "damage float advances left to right")
	stamp.play({"sheet": "ambush_slash", "px": 100.0, "life": 0.24, "pos": Vector2.ZERO})
	eq(flash.region_enabled, true, "ambush slash plays the strip")
	eq(flash.texture, stamp_script.texture_for("ambush_slash"), "ambush slash keeps the full plate")
	var slash_first := flash.region_rect
	stamp._sample(0.7)
	eq(flash.region_rect.position.x > slash_first.position.x, true, "ambush slash advances left to right")
	stamp.play({"sheet": "mark_shot_cast", "px": 60.0, "life": 0.60, "pos": Vector2.ZERO})
	eq(is_equal_approx(float(stamp.get("_span")), stamp_script.windup_sec("mark_shot_cast")), true, "a longer cast window does not stretch the bow windup")
	eq(flash.offset, Vector2.ZERO, "the centered bow ink stays on the hand anchor")
	stamp._sample(0.0)
	eq(flash.region_rect.position.x, 0.0, "the draw is the left cell")
	stamp._sample(0.23 / stamp_script.windup_sec("mark_shot_cast"))
	eq(flash.region_rect.position.x, float(flash.texture.get_width()) * 0.75, "the arrow-tip release is the last cell")
	stamp.free()


func _test_shade_markers_survive_rebuild() -> void:
	var live := load("res://tests/shade_marker_live.gd")
	truthy(live.has_method("run"), "shade live script parses")
	if not live.has_method("run"):
		return
	await live.run(self)


func _test_class_choreography() -> void:
	var caster := Vector2i(2, 3)
	var foe := Vector2i(4, 3)
	var marked: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "mark_shot",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 8,
		"engine": "mark",
		"engine_gained": 1,
	}])
	eq(_first(marked, "projectile")["from"], caster, "Mark Shot leaves the caster cell")
	eq(_first(marked, "projectile")["to"], foe, "Mark Shot arrives on the target cell")
	eq(is_equal_approx(float(_first(marked, "projectile")["arc"]), 10.0), true, "Mark Shot arcs")
	eq(_first(marked, "status_on")["status"], "marks", "Mark Shot pins Marks on the target")
	eq(int(_first(marked, "status_on")["seat"]), 1, "Marks sit on the target seat")
	eq(_first(marked, "status_on")["cell"], foe, "Mark cells stay Vector2i")
	eq(_has(marked, "shake"), false, "Mark Shot does not shake")
	eq(bool(_first(marked, "projectile").get("hand", false)), true, "Mark Shot emits from the hand")
	var windup := preload("res://vfx/vfx_stamp.gd").windup_sec("mark_shot_cast")
	eq(is_equal_approx(float(_first(marked, "projectile").get("delay", 0.0)), windup), true, "Mark Shot bolt leaves when the windup ends")
	eq(float(_first(marked, "projectile").get("delay", 0.0)) > 0.07, true, "Mark Shot bolt does not leave on the spark frame")
	eq(_has(marked, "puff"), false, "Mark Shot does not puff from the feet")
	var cast_wind := _sheet(marked, "mark_shot_cast")
	eq(cast_wind["cell"], caster, "Mark Shot windup sits on the caster")
	eq(int(cast_wind.get("seat", -1)), 0, "Mark Shot windup follows the caster seat")
	eq(bool(cast_wind.get("hand", false)), true, "Mark Shot windup is at bow height")
	eq(bool(cast_wind.get("chest", true)), false, "Mark Shot windup is not a chest overlay")
	eq(bool(cast_wind.get("ground", false)), false, "Mark Shot windup is not a floor stamp")
	eq(cast_wind.get("aim", Vector2i.ZERO), foe, "Mark Shot windup aims the release at the target")
	eq(is_equal_approx(float(cast_wind.get("delay", 1.0)), 0.0), true, "Mark Shot windup starts with the cast")
	eq(float(cast_wind.get("block", 1.0)), 0.0, "Mark Shot windup does not lock input")
	eq(is_equal_approx(float(_first(ROUTER.recipes_for([_damage("cut", 13)]), "spark").get("delay", 0.0)), StripLibrary.release_sec("gloam", "attack")), true, "Cut spark waits for the slash frame")
	eq(is_equal_approx(float(_first(ROUTER.recipes_for([_damage("detonate", 12)]), "spark").get("delay", 0.0)), StripLibrary.release_sec("kestrel", "cast")), true, "Detonate spark waits for the cast frame")
	var stacked: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "mark_shot",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 8,
		"engine_gained": 1,
	}], {"units": [{"seat": 1, "pos": foe, "marks": 4, "alive": true}]})
	eq(int(_first(stacked, "status_on")["count"]), 4, "Marks count comes from the snapshot")
	var boom: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "detonate",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 24,
		"marks_consumed": 3,
		"marks_remaining": 0,
		"engine": "mark",
		"engine_spent": 3,
	}])
	eq(int(_first(boom, "spark")["amount"]), 16, "Detonate scales the burst with marks consumed")
	eq(_first(boom, "status_off")["status"], "marks", "Detonate clears Marks when none remain")
	eq(float(_first(boom, "shake")["amplitude"]), 4.0, "Detonate at 24 is a heavy hit and shakes")
	eq(_first(boom, "number")["text"], "24", "Detonate still leads with the damage number")
	var kept: Array = ROUTER.recipes_for([{
		"type": "miss",
		"spell": "detonate",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 0,
		"marks_retained": true,
		"marks_on_target": 2,
	}])
	eq(_has(kept, "status_off"), false, "a Detonate miss keeps the Marks")
	eq(_first(kept, "number")["text"], "MISS", "a Detonate miss still reads MISS")
	var step: Array = ROUTER.recipes_for([{
		"type": "advance",
		"seat": 0,
		"from": Vector2i(2, 2),
		"to": Vector2i(2, 3),
		"impact_gained": 1,
	}])
	eq(_has(step, "slide"), false, "Advance teleports, it does not slide")
	eq(_first(step, "puff")["cell"], Vector2i(2, 2), "Advance leaves dust on the origin cell")
	eq(_first(step, "ring")["style"], "crack", "Advance cracks the landing cell")
	eq(_first(step, "number")["text"], "+1 Impact", "Advance still reports the Impact gain")
	var slam: Array = ROUTER.recipes_for([_damage("strike", 16)])
	eq(_first(slam, "ring")["style"], "crack", "Strike slams a ground crack")
	eq(_has(slam, "shake"), false, "Strike does not shake")
	var crush: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "crush",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 24,
		"impact_before": 4,
		"impact_spent": 2,
		"stun_applied": 1,
	}])
	eq(bool(_first(crush, "status_on")["glow"]), true, "Crush at 4 Impact glows the pips before the spend")
	eq(float(_first(crush, "shake")["amplitude"]), 4.0, "Crush still shakes at 4px")
	var plain: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "mend",
		"seat": 0,
		"target_seat": 0,
		"caster_cell": caster,
		"to": caster,
		"healed": 16,
		"damage": 0,
		"engine": "pulse",
		"engine_gained": 1,
	}])
	eq(_first_kind(plain, "triage").is_empty(), true, "Mend omits the triage tag when the event has no triage flag")
	eq(_has(plain, "projectile"), false, "a self Mend does not travel")
	var triage: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "mend",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"healed": 20,
		"damage": 0,
		"triage": true,
	}])
	eq(_first_kind(triage, "triage")["text"], "x1.25", "triage true flashes the multiplier")
	eq(_first_kind(triage, "heal")["text"], "+20", "the heal number stays the event amount")
	eq(_has(triage, "spark"), false, "a triage heal is not a damage spark")
	var tap: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "pulse_tap",
		"seat": 0,
		"target_seat": 0,
		"caster_cell": caster,
		"to": caster,
		"healed": 10,
		"damage": 0,
		"engine_spent": 1,
	}])
	eq(_has(tap, "projectile"), false, "a self Pulse Tap spends in place")
	var washed: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "cleanse",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 0,
		"healed": 0,
		"cc_removed": ["stun"],
		"engine_gained": 1,
	}])
	eq(_first(washed, "status_flash")["status"], "wash", "Cleanse plays the wash")
	eq(_first_kind(washed, "cleansed")["text"], "CLEANSED", "Cleanse names stun when cc_removed lists it")
	eq(_first(washed, "status_off")["status"], "stun", "Cleanse drops the stun marker")
	var empty_cc: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "cleanse",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 0,
		"cc_removed": [],
	}])
	eq(_first_kind(empty_cc, "cleansed").is_empty(), true, "an empty cc_removed list does not claim a cleanse")
	eq(_has(empty_cc, "status_off"), false, "Cleanse leaves stun alone when nothing was removed")
	var ally: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "heartstop",
		"seat": 0,
		"target_seat": 0,
		"caster_cell": caster,
		"to": caster,
		"healed": 32,
		"damage": 0,
		"hit_immunity": 1,
		"triage": true,
		"engine_spent": 4,
	}])
	eq(_first(ally, "status_on")["status"], "hit_immunity", "ally Heartstop locks the immunity rim")
	eq(_first_kind(ally, "triage")["text"], "x1.25", "ally Heartstop shows triage when the flag is set")
	eq(_has(ally, "spark"), false, "ally Heartstop is a heal")
	var full: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "heartstop",
		"seat": 0,
		"target_seat": 0,
		"caster_cell": caster,
		"to": caster,
		"healed": 0,
		"damage": 0,
		"hit_immunity": 1,
	}])
	eq(_first(full, "status_on")["status"], "hit_immunity", "a full-HP ally Heartstop still grants the rim")
	eq(_has(full, "spark"), false, "a zero heal is not drawn as damage")
	eq(bool(_first(ROUTER.recipes_for([{
		"type": "hit",
		"spell": "detonate",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 12,
		"marks_consumed": 1,
		"marks_remaining": 0,
	}]), "projectile").get("head", true)), false, "Detonate's signal line is not an arrow")
	var enemy: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "heartstop",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 10,
		"skip_next_mp": true,
		"engine_spent": 4,
	}])
	eq(_first(enemy, "status_on")["status"], "skip_next_mp", "enemy Heartstop marks skip-next-MP")
	eq(_first(enemy, "number")["text"], "10", "enemy Heartstop keeps the damage number")
	eq(_first_kind(enemy, "triage").is_empty(), true, "enemy Heartstop never shows triage")
	var both: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "heartstop",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 10,
		"skip_next_mp": true,
		"triage": true,
	}])
	eq(_first_kind(both, "triage").is_empty(), true, "skip-next-MP suppresses a stray triage tag")
	var faded: Array = ROUTER.recipes_for([{
		"type": "cast",
		"spell": "fade",
		"seat": 0,
		"caster_cell": caster,
		"invisible": true,
		"engine_gained": 1,
	}])
	eq(_first(faded, "number")["text"], "+1 Umbral", "Fade still leads with the Umbral gain")
	var veil: Dictionary = _first(faded, "status_on")
	eq(veil["status"], "invisible", "Fade sets the invisible rim")
	eq(veil.has("turns"), false, "Invisible has no turn count")
	var fold: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "nightfold",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": foe,
		"damage": 22,
	}])
	eq(_has(fold, "spark"), false, "Nightfold stays parked and does not deal a body spark")
	eq(_first_kind(fold, "damage").is_empty(), true, "Nightfold does not invent per-body damage")
	truthy(_has(fold, "ring"), "Nightfold shows only the parked swirl")
	var taxed: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "hold_line",
		"seat": 0,
		"caster_cell": caster,
		"damage": 7,
		"bodies": 1,
		"cone": [Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 4)],
		"targets": [{"target_seat": 1, "cell": foe, "hit": true, "damage": 7, "exit_tax": 1}],
	}])
	eq(_count(taxed, "spark"), 1, "Hold Line still sparks only the listed bodies")
	eq(_count(taxed, "ring"), 3, "Hold Line still outlines only the cone")
	eq(_first(taxed, "status_on")["status"], "exit_tax", "Hold Line locks exit tax from the body row")
	var lance: Array = ROUTER.recipes_for([{
		"type": "hit",
		"spell": "aegis_break",
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(3, 1),
		"damage": 26,
		"aegis_spent": 4,
		"stacks_cleared": true,
	}])
	eq(_cheby_shot(lance), true, "Aegis Break at range 2 throws the lance")
	eq(_first(lance, "status_off")["status"], "aegis", "Aegis Break clears the facets")
	truthy(_has(lance, "shake"), "Aegis Break still shakes")
	var adjacent: Array = ROUTER.recipes_for([_damage("aegis_break", 26)])
	eq(_has(adjacent, "projectile"), false, "Aegis Break at range 1 has no lance")
	var burned: Array = ROUTER.recipes_for([{"type": "dead", "seat": 1, "name": "Kestrel", "cause": "burn"}])
	eq(_first(burned, "death")["cause"], "burn", "death keeps the burn cause")
	eq(_has(burned, "shake"), false, "a burn death does not shake")
	var struck: Array = ROUTER.recipes_for([{"type": "dead", "seat": 1, "name": "Ironjaw", "cause": "damage"}])
	eq(_first(struck, "death")["cause"], "damage", "death keeps the damage cause")
	var unnamed: Array = ROUTER.recipes_for([{"type": "dead", "seat": 1, "name": "Ironjaw"}])
	eq(_first(unnamed, "death")["cause"], "damage", "a death without a cause reads as damage")
	eq(ROUTER.blocking_sec(boom) <= 0.6, true, "Detonate stays inside the input lock")
	eq(ROUTER.blocking_sec(lance) <= 0.6, true, "Aegis Break stays inside the input lock")


func _cheby_shot(recipes: Array) -> bool:
	for item in recipes:
		if str(item.get("id", "")) != "projectile":
			continue
		var origin: Vector2i = item.get("from", Vector2i.ZERO)
		var dest: Vector2i = item.get("to", Vector2i.ZERO)
		if origin == Vector2i(1, 1) and dest == Vector2i(3, 1):
			return true
	return false


func _catalogue() -> Array:
	return [
		{"type": "hit", "spell": "strike", "seat": 0, "target_seat": 1, "caster_cell": Vector2i(2, 3), "to": Vector2i(4, 3), "damage": 16, "engine": "impact", "engine_gained": 1},
		{"type": "miss", "spell": "cut", "seat": 0, "target_seat": 1, "caster_cell": Vector2i(2, 3), "to": Vector2i(4, 3), "damage": 0},
		{"type": "push_blocked", "target_seat": 1, "from": Vector2i(4, 3), "attempted": Vector2i(5, 3), "reason": "occupied"},
		{"type": "push_bounce", "target_seat": 1, "from": Vector2i(4, 3), "attempted": Vector2i(5, 3)},
		{"type": "stagger", "target_seat": 1, "stagger_hp": 4, "stagger_mp": 0},
		{"type": "status", "status": "burn", "target_seat": 1},
		{"type": "burn", "target_seat": 1, "damage": 4},
		{"type": "dead", "seat": 1},
		{"type": "match_over", "winner_seat": 0},
		{"type": "expire", "status": "burn", "target_seat": 1, "pos": Vector2i(4, 3)},
		{"type": "move", "seat": 0},
		{"type": "face", "seat": 0, "dir": "E"},
		{"type": "reject", "reason": "no"},
		{"type": "turn_start", "seat": 0},
	]


func _test_scenario_overlays() -> void:
	var stamp_script := preload("res://vfx/vfx_stamp.gd")
	for sheet in ["ambush_slash", "mark_shot_impact", "mark_shot_cast", "detonate_burst", "hit_flash", "damage_float", "footstep_dust", "melee_windup"]:
		truthy(FileAccess.file_exists("res://art/vfx/scenario/%s.png" % sheet), "scenario plate %s is on disk" % sheet)
		var tex: Texture2D = stamp_script.texture_for(sheet)
		truthy(tex != null, "%s imports as a texture" % sheet)
		var img := tex.get_image()
		truthy(img != null and img.get_width() > 0, "%s has pixels" % sheet)
		eq(img.get_pixel(0, 0).a < 0.08, true, "%s corner stays transparent" % sheet)
		var opaque := false
		var step := 8
		for y in range(0, img.get_height(), step):
			for x in range(0, img.get_width(), step):
				if img.get_pixel(x, y).a > 0.8:
					opaque = true
					break
			if opaque:
				break
		truthy(opaque, "%s has a readable core" % sheet)
	eq(stamp_script.frame_count("hit_flash"), 6, "hit flash is a 6-frame punch-v3 strip")
	eq(stamp_script.frame_count("damage_float"), 6, "damage float is a 6-frame punch-v3 strip")
	eq(stamp_script.frame_count("footstep_dust"), 5, "footstep dust is a 5-frame punch-v3 plant strip")
	eq(stamp_script.frame_count("ambush_slash"), 5, "ambush slash is a 5-cell v5 strip")
	eq(stamp_script.frame_count("mark_shot_impact"), 7, "Mark Shot impact is a 7-frame floor strip")
	eq(stamp_script.frame_count("mark_shot_cast"), 4, "Mark Shot cast is a 4-frame bow strip")
	eq(stamp_script.frame_count("detonate_burst"), 6, "Detonate burst is a 6-frame punch-v3 strip")
	eq(stamp_script.frame_count("melee_windup"), 4, "melee windup is a 4-frame anticipation strip")
	for sheet in ["ambush_slash", "hit_flash", "damage_float", "footstep_dust", "detonate_burst", "melee_windup", "mark_shot_impact", "mark_shot_cast"]:
		var laid: Texture2D = stamp_script.texture_for(sheet)
		var prev_x := -1.0
		for i in stamp_script.frame_count(sheet):
			var cel: Rect2 = stamp_script.region_for(sheet, i, laid)
			eq(cel.position.x >= 0.0 and cel.position.y >= 0.0, true, "%s frame %d stays on the sheet" % [sheet, i])
			eq(cel.end.x <= float(laid.get_width()) + 0.01 and cel.end.y <= float(laid.get_height()) + 0.01, true, "%s frame %d stays inside the sheet" % [sheet, i])
			eq(cel.position.x > prev_x, true, "%s frames run left to right" % sheet)
			prev_x = cel.position.x
	eq(is_equal_approx(BUDGET.STAMP_DUST_LIFE, 0.30), true, "footstep dust is a short plant puff")
	eq(BUDGET.STAMP_DUST_LIFE >= 0.20 and BUDGET.STAMP_DUST_LIFE <= 0.35, true, "footstep dust life stays inside 0.2-0.35s")
	eq(BUDGET.STAMP_HIT_LIFE >= 0.24 and BUDGET.STAMP_HIT_LIFE <= 0.36, true, "the hit plate has time to pop")
	var strike: Array = ROUTER.recipes_for([_damage("strike", 16)])
	eq(_sheet(strike, "hit_flash")["cell"], Vector2i(2, 1), "damage apply flashes the target")
	eq(float(_sheet(strike, "hit_flash")["px"]), BUDGET.STAMP_HIT_PX, "the hit flash stays body-sized")
	eq(float(_sheet(strike, "hit_flash")["block"]), 0.0, "a hit flash does not lock input")
	var wind := _sheet(strike, "melee_windup")
	eq(wind["cell"], Vector2i(1, 1), "melee windup sits on the caster")
	eq(is_equal_approx(float(wind["delay"]), 0.0), true, "melee windup starts with the swing")
	eq(is_equal_approx(float(wind["life"]), float(_sheet(strike, "hit_flash")["delay"])), true, "melee windup ends as the hit flash starts")
	eq(float(wind["px"]), BUDGET.STAMP_MELEE_PX, "melee windup stays on the body")
	eq(float(wind["block"]), 0.0, "melee windup does not lock input")
	eq(wind.get("aim", Vector2i.ZERO), Vector2i(2, 1), "melee windup aims at the target")
	eq(stamp_script.windup_sec("melee_windup"), 0.0, "melee windup keeps the swing window, not a new hold")
	var wind_tex: Texture2D = stamp_script.texture_for("melee_windup")
	eq(wind_tex.get_width(), 1280, "the melee windup strip is 1280 wide")
	eq(wind_tex.get_height(), 720, "the melee windup strip is 720 tall")
	var wind_img := wind_tex.get_image()
	var wind_dividers: Array[int] = [318, 319, 639, 640, 960, 961]
	for x in wind_dividers:
		eq(wind_img.get_pixel(x, 0).a < 0.02, true, "melee divider x=%d is clear at the top" % x)
		eq(wind_img.get_pixel(x, 360).a < 0.02, true, "melee divider x=%d is clear at mid" % x)
		eq(wind_img.get_pixel(x, 719).a < 0.02, true, "melee divider x=%d is clear at the bottom" % x)
	eq(wind_img.get_pixel(720, 340).a > 0.8, true, "the windup peak core stays opaque")
	var wind_cells: Array[Rect2] = [
		Rect2(30, 165, 252, 355),
		Rect2(337, 165, 279, 355),
		Rect2(656, 165, 271, 355),
		Rect2(964, 165, 312, 355),
	]
	for i in wind_cells.size():
		var wind_cel: Rect2 = stamp_script.region_for("melee_windup", i, wind_tex)
		eq(wind_cel, wind_cells[i], "melee windup cell %d crops off the divider columns" % i)
		for x in wind_dividers:
			eq(float(x) < wind_cel.position.x or float(x) >= wind_cel.end.x, true, "melee windup cell %d does not include divider x=%d" % [i, x])
	var contact_delay := float(_sheet(strike, "hit_flash")["delay"])
	eq(is_equal_approx(contact_delay, float(_first(strike, "spark").get("delay", -1.0))), true, "the compact burst lands with the flash")
	eq(is_equal_approx(contact_delay, float(_first_kind(strike, "damage").get("delay", -1.0))), true, "the damage number lands with the flash")
	eq(is_equal_approx(contact_delay, float(_sheet(strike, "damage_float")["delay"])), true, "the damage float lands with the flash")
	eq(_sheet(strike, "damage_float")["cell"], Vector2i(2, 1), "the damage float sits on the target tile")
	eq(bool(_sheet(strike, "damage_float").get("head", false)), true, "the damage float uses the head anchor")
	eq(bool(_sheet(strike, "damage_float").get("chest", true)), false, "the damage float is not a second chest flash")
	eq(float(_sheet(strike, "damage_float")["px"]), BUDGET.STAMP_FLOAT_PX, "the damage float stays compact")
	eq(float(_sheet(strike, "damage_float")["block"]), 0.0, "the damage float does not lock input")
	eq(is_equal_approx(contact_delay, preload("res://units/view_motion.gd").damage_resolve_sec(SpellKits.STRIKE)), true, "the flinch starts on that same contact")
	var flinch_sec := preload("res://units/view_motion.gd").hit_sec()
	eq(flinch_sec >= 0.20 and flinch_sec <= 0.40, true, "the flinch finishes inside 0.2-0.4s")
	eq(BUDGET.STAMP_HIT_LIFE >= 0.20 and BUDGET.STAMP_HIT_LIFE <= 0.40, true, "the hit flash finishes inside 0.2-0.4s")
	eq(BUDGET.STAMP_FLOAT_LIFE >= 0.20 and BUDGET.STAMP_FLOAT_LIFE <= 0.40, true, "the damage float finishes inside 0.2-0.4s")
	eq(BUDGET.SPARK_LIFE >= 0.20 and BUDGET.SPARK_LIFE <= 0.40, true, "the compact burst finishes inside 0.2-0.4s")
	eq(BUDGET.STAMP_FLOAT_PX < BUDGET.STAMP_HIT_PX, true, "the float stays smaller than the chest flash")
	var heal: Array = ROUTER.recipes_for([{
		"type": "hit", "spell": "mend", "seat": 0, "target_seat": 1,
		"caster_cell": Vector2i(1, 1), "to": Vector2i(2, 1), "healed": 16, "damage": 0,
	}])
	eq(_sheet(heal, "hit_flash").is_empty(), true, "a heal does not play the damage flash")
	eq(_sheet(heal, "damage_float").is_empty(), true, "a heal does not play the damage float")
	eq(_sheet(heal, "melee_windup").is_empty(), true, "a heal does not play the melee windup")
	var ambush: Array = ROUTER.recipes_for([{
		"type": "hit", "spell": "ambush", "seat": 0, "target_seat": 1,
		"caster_cell": Vector2i(1, 1), "from": Vector2i(4, 4), "to": Vector2i(5, 4),
		"origin": Vector2i(2, 4), "destination": Vector2i(5, 4),
		"teleported": true, "backstab": true, "facing_mult": 1.35, "damage": 30,
	}])
	var slash_sheet := _sheet(ambush, "ambush_slash")
	eq(slash_sheet["cell"], Vector2i(5, 4), "the slash is anchored on the planted back tile")
	eq(slash_sheet["cell"] == Vector2i(4, 4), false, "the slash is not centered on the struck body")
	eq(slash_sheet["cell"] == Vector2i(2, 4), false, "the slash is not the origin")
	eq(slash_sheet.get("aim"), Vector2i(4, 4), "the slash faces the struck body")
	eq(int(slash_sheet.get("seat", -1)), 0, "the slash follows the planted caster")
	eq(bool(slash_sheet.get("hand", false)), true, "the slash stays on the planted Gloam")
	eq(bool(slash_sheet.get("chest", true)), false, "the slash is not dropped onto the feet")
	var contact_sec := preload("res://units/view_motion.gd").ambush_contact_sec()
	var slash_lead := stamp_script.lead_sec("ambush_slash", 2)
	var slash_life := stamp_script.windup_sec("ambush_slash")
	eq(stamp_script.holds_for("ambush_slash"), [0.08, 0.12, 0.09, 0.05, 0.04], "slash frames are anticipate, wind, snap, settle, fade")
	eq(is_equal_approx(slash_lead, contact_sec), true, "anticipate and wind fill the beat before contact")
	eq(is_equal_approx(float(slash_sheet["delay"]), contact_sec - slash_lead), true, "the snap opens on the slash contact")
	eq(is_equal_approx(float(slash_sheet["life"]), slash_life), true, "the strip lasts the locked holds")
	eq(slash_life >= 0.20 and slash_life <= 0.40, true, "the slash finishes inside 0.2-0.4s")
	eq(stamp_script.frame_at("ambush_slash", 0.0), 0, "anticipate is the first cell")
	eq(stamp_script.frame_at("ambush_slash", 0.08), 1, "the wind starts when anticipate ends")
	eq(stamp_script.frame_at("ambush_slash", contact_sec), 2, "the SNAP cell is up when the hit resolves")
	eq(stamp_script.frame_at("ambush_slash", 0.29), 3, "settle trails follow the snap")
	eq(stamp_script.frame_at("ambush_slash", 0.34), 4, "fade is the last cell")
	var slash_tex: Texture2D = stamp_script.texture_for("ambush_slash")
	eq(slash_tex.get_width(), 1280, "the ambush strip is 1280 wide")
	eq(slash_tex.get_height(), 720, "the ambush strip is 720 tall")
	var slash_img := slash_tex.get_image()
	eq(slash_img.get_pixel(12, 360).a < 0.08, true, "the gray cell frame is not drawn")
	eq(slash_img.get_pixel(128, 221).a < 0.08, true, "the outer guide line is not drawn")
	eq(slash_img.get_pixel(128, 499).a < 0.08, true, "the lower guide line is not drawn")
	eq(slash_img.get_pixel(640, 360).a > 0.8, true, "the snap core stays opaque")
	var slash_cells: Array[Rect2] = [
		Rect2(7, 238, 244, 243),
		Rect2(263, 238, 244, 243),
		Rect2(519, 238, 244, 243),
		Rect2(775, 238, 244, 243),
		Rect2(1031, 238, 244, 243),
	]
	for i in slash_cells.size():
		eq(stamp_script.region_for("ambush_slash", i, slash_tex), slash_cells[i], "ambush cell %d crops inside the gray frame" % i)
	eq(_sheet(ambush, "hit_flash")["cell"], Vector2i(4, 4), "Ambush damage still flashes the body")
	var ambush_miss: Array = ROUTER.recipes_for([{
		"type": "miss", "spell": "ambush", "seat": 0, "target_seat": 1,
		"caster_cell": Vector2i(1, 1), "to": Vector2i(4, 3), "origin": Vector2i(2, 4), "damage": 0,
	}])
	eq(_sheet(ambush_miss, "ambush_slash").is_empty(), true, "an Ambush miss does not slash")
	eq(_sheet(ambush, "melee_windup").is_empty(), true, "Ambush does not borrow the standing melee windup")
	eq(_sheet(ambush_miss, "melee_windup").is_empty(), true, "an Ambush miss does not play the melee windup")
	var marked: Array = ROUTER.recipes_for([{
		"type": "hit", "spell": "mark_shot", "seat": 0, "target_seat": 1,
		"caster_cell": Vector2i(2, 3), "to": Vector2i(4, 3), "damage": 8,
	}])
	var windup := stamp_script.windup_sec("mark_shot_cast")
	var impact_delay := windup + ROUTER.MARK_FLIGHT_SEC
	var cast_sheet := _sheet(marked, "mark_shot_cast")
	eq(cast_sheet["cell"], Vector2i(2, 3), "Mark Shot windup stays on the caster cell")
	eq(cast_sheet["cell"] == Vector2i(4, 3), false, "Mark Shot windup is not the target")
	eq(bool(cast_sheet.get("hand", false)), true, "Mark Shot windup uses the bow anchor")
	eq(bool(cast_sheet.get("chest", true)), false, "Mark Shot windup is not planted on the chest")
	eq(bool(cast_sheet.get("ground", false)), false, "Mark Shot windup is not a floor ring")
	eq(is_equal_approx(float(cast_sheet.get("delay", 1.0)), 0.0), true, "Mark Shot windup plays from the first cast frame")
	var holds: Array = stamp_script.holds_for("mark_shot_cast")
	eq(holds, [0.07, 0.08, 0.08, 0.07], "bow frames are draw, snap, reticle, release")
	eq(windup >= 0.28 and windup <= 0.32, true, "the bow windup is a 280-320ms snap")
	eq(windup <= 0.30, true, "the bow windup stays at or under 0.30s including the release")
	eq(is_equal_approx(float(cast_sheet.get("life", 0.0)), windup), true, "the bow strip lasts the locked holds")
	eq(is_equal_approx(float(cast_sheet.get("life", 0.0)), impact_delay), false, "the bow draw is not stretched out to the contact")
	eq(stamp_script.frame_at("mark_shot_cast", windup - 0.001), 3, "frame 4 is still the release when the bolt leaves")
	eq(stamp_script.frame_at("mark_shot_cast", 0.0), 0, "the draw is the first cell")
	eq(stamp_script.frame_at("mark_shot_cast", 0.07), 1, "the snap burst starts when the draw ends")
	eq(stamp_script.frame_at("mark_shot_cast", 0.15), 2, "the reticle peak starts after the snap")
	eq(stamp_script.frame_at("mark_shot_cast", 0.23), 3, "the arrow-tip release is the last cell")
	var bolt_delay := float(_first(marked, "projectile").get("delay", 0.0))
	eq(is_equal_approx(bolt_delay, windup), true, "the bolt leaves on the tick after the arrow-tip release")
	eq(bolt_delay > float(holds[0]), true, "the bolt does not spawn on the draw frame")
	eq(bolt_delay > 0.23 - 0.001, true, "the bolt waits until the arrow-tip release")
	eq(ROUTER.MARK_FLIGHT_SEC >= 0.20 and ROUTER.MARK_FLIGHT_SEC <= 0.40, true, "contact lands 0.2-0.4s after the arrow leaves")
	eq(is_equal_approx(impact_delay - windup, ROUTER.MARK_FLIGHT_SEC), true, "the flight is the gap after release, not a stretched draw")
	var float_delay := float(_first_kind(marked, "damage").get("delay", 0.0))
	eq(is_equal_approx(float_delay, impact_delay), true, "the damage float waits for bolt contact")
	eq(float_delay > 0.23, true, "the damage float is not during the draw")
	eq(cast_sheet.get("life", 1.0) < impact_delay, true, "the bow windup finishes before the floor impact")
	eq(float(cast_sheet.get("px", 0.0)), BUDGET.STAMP_MARK_CAST_PX, "the bow windup stays smaller than the floor impact")
	eq(BUDGET.STAMP_MARK_CAST_PX < BUDGET.STAMP_MARK_PX, true, "the bow windup is smaller than the floor impact")
	var cast_tex: Texture2D = stamp_script.texture_for("mark_shot_cast")
	var cell_w := float(cast_tex.get_width()) / 4.0
	var cell_h := float(cast_tex.get_height())
	eq(is_equal_approx(cell_w, cell_h), true, "Mark Shot cast cells are equal squares")
	for i in 4:
		var cel: Rect2 = stamp_script.region_for("mark_shot_cast", i, cast_tex)
		eq(cel.position, Vector2(cell_w * float(i), 0.0), "Mark Shot cast cell %d is an equal slice" % i)
		eq(cel.size, Vector2(cell_w, cell_h), "Mark Shot cast cell %d fills its slice" % i)
	var ink_y := 0.0
	var ink_n := 0
	var plate := cast_tex.get_image()
	for y in plate.get_height():
		for x in int(cell_w):
			if plate.get_pixel(x, y).a > 16.0 / 255.0:
				ink_y += float(y)
				ink_n += 1
	eq(ink_n > 0 and ink_y / float(ink_n) < cell_h * 0.5, true, "the bow ink sits in the upper half of the cell")
	eq(_sheet(marked, "mark_shot_impact")["cell"], Vector2i(4, 3), "Mark Shot impact sits on the target")
	eq(bool(_sheet(marked, "mark_shot_impact").get("ground", false)), true, "Mark Shot aim rings stay on the floor")
	eq(bool(_sheet(marked, "mark_shot_impact").get("chest", true)), false, "Mark Shot impact is not a chest overlay")
	eq(is_equal_approx(float(_sheet(marked, "mark_shot_impact")["delay"]), impact_delay), true, "Mark Shot impact waits for the bolt")
	eq(is_equal_approx(float(_sheet(marked, "hit_flash")["delay"]), impact_delay), true, "the hit flash lands with the bolt")
	eq(is_equal_approx(float(_sheet(marked, "damage_float")["delay"]), impact_delay), true, "the damage float lands with the bolt")
	var mark_miss: Array = ROUTER.recipes_for([{
		"type": "miss", "spell": "mark_shot", "seat": 0, "target_seat": 1,
		"caster_cell": Vector2i(2, 3), "to": Vector2i(4, 3), "damage": 0,
	}])
	eq(_sheet(mark_miss, "mark_shot_impact").is_empty(), true, "a Mark Shot miss has no impact")
	eq(_sheet(mark_miss, "hit_flash").is_empty(), true, "a Mark Shot miss has no hit flash")
	eq(_sheet(mark_miss, "damage_float").is_empty(), true, "a Mark Shot miss has no damage float")
	eq(_sheet(marked, "melee_windup").is_empty(), true, "Mark Shot keeps the bow windup, not the melee strip")
	eq(_sheet(mark_miss, "melee_windup").is_empty(), true, "a Mark Shot miss does not play the melee strip")
	eq(_sheet(mark_miss, "mark_shot_cast")["cell"], Vector2i(2, 3), "a Mark Shot miss still winds the bow")
	eq(bool(_sheet(mark_miss, "mark_shot_cast").get("hand", false)), true, "a Mark Shot miss still lifts the windup to the bow")
	eq(is_equal_approx(float(_first(mark_miss, "projectile").get("delay", 0.0)), windup), true, "a Mark Shot miss still waits for the arrow-tip release")
	var boom: Array = ROUTER.recipes_for([{
		"type": "hit", "spell": "detonate", "seat": 0, "target_seat": 1,
		"caster_cell": Vector2i(2, 3), "to": Vector2i(4, 3), "damage": 24,
		"marks_consumed": 3, "marks_remaining": 0,
	}])
	eq(_sheet(boom, "detonate_burst")["cell"], Vector2i(4, 3), "Detonate bursts on the target")
	eq(is_equal_approx(float(_sheet(boom, "detonate_burst")["delay"]), preload("res://units/strip_library.gd").release_sec("kestrel", "cast")), true, "Detonate bursts on the cast resolve")
	eq(float(_sheet(boom, "detonate_burst")["px"]) > BUDGET.STAMP_HIT_PX, true, "Detonate reads larger than a generic hit")
	eq(is_equal_approx(float(_sheet(boom, "detonate_burst")["life"]), BUDGET.STAMP_SPELL_LIFE), true, "Detonate keeps the spell overlay life")
	eq(BUDGET.STAMP_SPELL_LIFE >= 0.20 and BUDGET.STAMP_SPELL_LIFE <= 0.40, true, "Detonate burst finishes inside 0.2-0.4s")
	var boom_tex: Texture2D = stamp_script.texture_for("detonate_burst")
	eq(boom_tex.get_width(), 1280, "the detonate strip is 1280 wide")
	eq(boom_tex.get_height(), 720, "the detonate strip is 720 tall")
	var boom_img := boom_tex.get_image()
	var divider_xs: Array[int] = [212, 213, 426, 639, 640, 852, 853, 1066]
	for x in divider_xs:
		eq(boom_img.get_pixel(x, 0).a < 0.02, true, "detonate divider x=%d is clear at the top" % x)
		eq(boom_img.get_pixel(x, 360).a < 0.02, true, "detonate divider x=%d is clear at mid" % x)
		eq(boom_img.get_pixel(x, 719).a < 0.02, true, "detonate divider x=%d is clear at the bottom" % x)
	eq(boom_img.get_pixel(528, 360).a > 0.8, true, "the shock core stays opaque")
	var boom_cells: Array[Rect2] = [
		Rect2(42, 165, 133, 353),
		Rect2(221, 165, 199, 353),
		Rect2(429, 165, 208, 353),
		Rect2(644, 165, 205, 353),
		Rect2(865, 165, 191, 353),
		Rect2(1109, 165, 135, 353),
	]
	for i in boom_cells.size():
		var cel: Rect2 = stamp_script.region_for("detonate_burst", i, boom_tex)
		eq(cel, boom_cells[i], "detonate cell %d crops off the divider columns" % i)
		for x in divider_xs:
			eq(float(x) < cel.position.x or float(x) >= cel.end.x, true, "detonate cell %d does not include divider x=%d" % [i, x])
	var kept: Array = ROUTER.recipes_for([{
		"type": "miss", "spell": "detonate", "seat": 0, "target_seat": 1,
		"caster_cell": Vector2i(2, 3), "to": Vector2i(4, 3), "damage": 0, "marks_retained": true,
	}])
	eq(_sheet(kept, "detonate_burst").is_empty(), true, "a Detonate miss does not burst")
	eq(BUDGET.STAMP_DETONATE_PX < 160.0, true, "Detonate stays on the tile, not the screen")
	eq(BUDGET.STAMP_SPELL_LIFE <= 0.3, true, "spell overlays stay short")
	eq(BUDGET.POOL_STAMP, 6, "stamps are a fixed pool")


func _sheet(recipes: Array, sheet: String) -> Dictionary:
	for item in recipes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("id", "")) == "stamp" and str(item.get("sheet", "")) == sheet:
			return item
	return {}


func _damage(spell_id: String, amount: int) -> Dictionary:
	return {
		"type": "hit",
		"spell": spell_id,
		"seat": 0,
		"target_seat": 1,
		"caster_cell": Vector2i(1, 1),
		"to": Vector2i(2, 1),
		"damage": amount,
	}


func _ids(recipes: Array) -> Array:
	var out: Array = []
	for item in recipes:
		out.append(str(item.get("id", "")))
	return out


func _has(recipes: Array, id: String) -> bool:
	return _ids(recipes).has(id)


func _count(recipes: Array, id: String) -> int:
	var count := 0
	for item in recipes:
		if str(item.get("id", "")) == id:
			count += 1
	return count


func _all(recipes: Array, id: String) -> Array:
	var out: Array = []
	for item in recipes:
		if str(item.get("id", "")) == id:
			out.append(item)
	return out


func _effect_pos(director: Node, kind: String, text: String) -> Vector2:
	for child in director.get_children():
		if child == null or not str(child.name).begins_with(kind):
			continue
		if not bool(child.get("in_use")):
			continue
		if text != "" and str(child.get("_text")) != text:
			continue
		return child.position
	return Vector2(-9999, -9999)


func _first(recipes: Array, id: String) -> Dictionary:
	var found := _all(recipes, id)
	if found.is_empty():
		return {}
	return found[0]


func _first_kind(recipes: Array, kind: String) -> Dictionary:
	for item in recipes:
		if str(item.get("id", "")) == "number" and str(item.get("kind", "")) == kind:
			return item
	return {}


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL %s (got %s expected %s)" % [msg, str(actual), str(expected)])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	eq(bool(value), true, msg)
