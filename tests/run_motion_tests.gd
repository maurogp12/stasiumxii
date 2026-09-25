extends SceneTree

## View-only motion curves, budgets, and board_view wiring.
## Run: godot --headless --path . -s res://tests/run_motion_tests.gd

const MOTION := preload("res://units/view_motion.gd")

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	var script := load("res://backend/combat_sim.gd")
	_sim = script.new()
	_run()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_live_tree()
	await _test_strip_fallback()
	await _test_shade_markers_survive_rebuild()
	print("Motion tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_tunables_and_budget()
	_test_curves_return_to_origin()
	_test_idle_phase()
	_test_caster_and_target_kinds()
	_test_support_events_do_not_knock()
	_test_commit_motion_on_hit_and_miss()
	_test_walk_hops_not_advance()
	_test_pawn_samples_then_plants()
	_test_reduce_motion_skips()
	_test_view_wiring()


func _test_tunables_and_budget() -> void:
	eq(MOTION.ACTION_LOCK_MAX <= 0.6, true, "action input lock is at most 0.6s")
	eq(MOTION.attack_sec() <= 0.6, true, "attack motion is at most 0.6s")
	eq(MOTION.cast_sec() <= 0.6, true, "cast motion is at most 0.6s")
	eq(MOTION.hit_sec() <= 0.6, true, "hit motion is at most 0.6s")
	eq(MOTION.support_sec() <= 0.6, true, "support lift is at most 0.6s")
	eq(MOTION.death_sec() <= 0.6, true, "death slump is at most 0.6s")
	eq(MOTION.IDLE_PERIOD >= 1.6 and MOTION.IDLE_PERIOD <= 2.2, true, "idle period is a slow breathe")
	eq(MOTION.IDLE_BOB_PX >= 1.0 and MOTION.IDLE_BOB_PX <= 2.0, true, "idle bob is 1-2px")
	eq(MOTION.HOP_PX >= 32.0 and MOTION.HOP_PX <= 40.0, true, "step arc clears one iso tile so a phone can read the hop")
	eq(Pawn.WALK_HOP_SEC, 0.25, "per-tile hop is 0.25s")
	eq(is_equal_approx(Pawn.walk_strip_speed_scale(), 1.0), true, "a 6-frame 24fps strip matches the hop at speed_scale 1")
	eq(is_equal_approx(Pawn.strip_speed_scale(8, 24.0, Pawn.WALK_HOP_SEC), (8.0 / 24.0) / Pawn.WALK_HOP_SEC), true, "a longer strip speeds up to the same hop")
	eq(Pawn.strip_speed_scale(0, 24.0, Pawn.WALK_HOP_SEC), 1.0, "an empty strip does not divide by zero")
	eq(is_equal_approx(MOTION.ATTACK_LUNGE_PX, 6.0), true, "lunge is about 6px")
	eq(MOTION.HIT_KNOCK_PX >= 4.0 and MOTION.HIT_KNOCK_PX <= 6.0, true, "knockback is 4-6px")
	var stacked := {
		"hit": true,
		"death": true,
		"delay": true,
		"away": Vector2(32, 16),
		"tilt": 1.0,
	}
	eq(MOTION.plan_sec(stacked) <= MOTION.ACTION_LOCK_MAX, true, "hit then slump still fits the action lock")
	var self_cast := {"cast": true, "lift": true, "delay": true}
	var self_steps: Array = MOTION.steps_for(self_cast)
	eq(self_steps.size(), 1, "a self cast does not also play a second lift")
	eq(str(self_steps[0].get("kind", "")), "cast", "self cast keeps the wind-up")


func _test_curves_return_to_origin() -> void:
	eq(MOTION.hop_offset(0.0), Vector2.ZERO, "hop starts on the tile")
	eq(MOTION.hop_offset(1.0), Vector2.ZERO, "hop ends on the tile")
	var crest: Vector2 = MOTION.hop_offset(0.5)
	eq(crest.x, 0.0, "hop arc has no sideways slide")
	eq(crest.y, -MOTION.HOP_PX, "hop crest is the tuned rise")
	eq(MOTION.hop_scale(0.0), Vector2.ONE, "hop scale starts at rest")
	eq(MOTION.hop_scale(1.0), Vector2.ONE, "hop scale ends at rest")
	var stretched: Vector2 = MOTION.hop_scale(0.5)
	eq(is_equal_approx(stretched.y, MOTION.HOP_STRETCH_Y), true, "hop crest stretches upward")
	eq(stretched.x < 1.0, true, "hop crest narrows")
	var landed: Vector2 = MOTION.hop_scale(0.86)
	eq(landed.y < 1.0, true, "hop landing squashes")
	eq(landed.x > 1.0, true, "hop landing widens")
	var aim := Vector2(32, 16)
	eq(MOTION.attack_offset(0.0, aim), Vector2.ZERO, "lunge starts on the tile")
	eq(MOTION.attack_offset(1.0, aim), Vector2.ZERO, "lunge returns to the tile")
	var peak_t := MOTION.ATTACK_OUT_SEC / MOTION.attack_sec()
	var peak: Vector2 = MOTION.attack_offset(peak_t, aim)
	eq(is_equal_approx(peak.length(), MOTION.ATTACK_LUNGE_PX), true, "lunge reaches the tuned distance")
	eq(MOTION.hit_offset(0.0, aim), Vector2.ZERO, "knockback starts on the tile")
	eq(MOTION.hit_offset(1.0, aim), Vector2.ZERO, "knockback returns to the tile")
	var knock_t := MOTION.HIT_OUT_SEC / MOTION.hit_sec()
	var knock: Vector2 = MOTION.hit_offset(knock_t, aim)
	eq(is_equal_approx(knock.length(), MOTION.HIT_KNOCK_PX), true, "knockback reaches the tuned distance")
	eq(MOTION.support_offset(0.0), Vector2.ZERO, "lift starts on the tile")
	eq(MOTION.support_offset(1.0), Vector2.ZERO, "lift returns to the tile")
	eq(MOTION.support_offset(0.5).x, 0.0, "heal lift is not a knockback")
	eq(MOTION.support_offset(0.5).y, -MOTION.SUPPORT_RISE_PX, "heal lift rises")
	var cast_rest: Dictionary = MOTION.cast_pose(1.0)
	eq(cast_rest["pos"], Vector2.ZERO, "cast releases to the tile")
	eq(cast_rest["scale"], Vector2.ONE, "cast scale releases to rest")
	var cast_hold_t := (MOTION.CAST_RISE_SEC + MOTION.CAST_HOLD_SEC * 0.5) / MOTION.cast_sec()
	var held: Dictionary = MOTION.cast_pose(cast_hold_t)
	eq((held["pos"] as Vector2).y, -MOTION.CAST_RISE_PX, "cast holds the rise")
	eq(is_equal_approx((held["scale"] as Vector2).y, MOTION.CAST_SCALE), true, "cast holds the scale-up")
	var slumped: Dictionary = MOTION.death_pose(1.0, 1.0)
	eq(is_equal_approx((slumped["scale"] as Vector2).y, MOTION.DEATH_SQUASH_Y), true, "death squashes down")
	eq(is_equal_approx(float(slumped["rot"]), MOTION.DEATH_TILT_DEG), true, "death tilts")
	var stood: Dictionary = MOTION.death_pose(0.0, 1.0)
	eq(stood["scale"], Vector2.ONE, "death starts upright")
	eq(float(stood["rot"]), 0.0, "death starts untilted")


func _test_idle_phase() -> void:
	var a := MOTION.idle_phase_sec(0, "kestrel:Kestrel")
	var b := MOTION.idle_phase_sec(1, "kestrel:Kestrel")
	eq(is_equal_approx(a, b), false, "two seats do not share an idle phase")
	eq(a, MOTION.idle_phase_sec(0, "kestrel:Kestrel"), "idle phase is stable")
	eq(a >= 0.0 and a < MOTION.IDLE_PERIOD, true, "phase sits inside one cycle")
	eq(b >= 0.0 and b < MOTION.IDLE_PERIOD, true, "second phase sits inside one cycle")


func _test_caster_and_target_kinds() -> void:
	eq(MOTION.caster_motion(SpellKits.STRIKE), "attack", "Strike lunges")
	eq(MOTION.caster_motion(SpellKits.SHOULDER), "attack", "Shoulder lunges")
	eq(MOTION.caster_motion(SpellKits.BASH), "attack", "Bash lunges")
	eq(MOTION.caster_motion(SpellKits.HOLD_LINE), "attack", "Hold Line lunges")
	eq(MOTION.caster_motion(SpellKits.MARK_SHOT), "cast", "Mark Shot winds up")
	eq(MOTION.caster_motion(SpellKits.MEND), "cast", "Mend winds up")
	eq(MOTION.caster_motion(SpellKits.WARD), "cast", "Ward winds up")
	eq(MOTION.caster_motion(SpellKits.CLEANSE), "cast", "Cleanse winds up")
	eq(MOTION.caster_motion(SpellKits.ADVANCE), "", "Advance stays a teleport snap")
	eq(MOTION.caster_motion(SpellKits.AMBUSH), "attack", "Ambush lunges before the blink")
	eq(MOTION.caster_motion(SpellKits.DROP_SHADE), "cast", "Drop Shade still winds up")
	var ambush_reach: Vector2 = MOTION.attack_offset(MOTION.ATTACK_OUT_SEC / MOTION.attack_sec(), Vector2(32, 0), MOTION.AMBUSH_LUNGE_PX)
	eq(is_equal_approx(ambush_reach.x, MOTION.AMBUSH_LUNGE_PX), true, "Ambush reach is phone-readable")
	eq(is_equal_approx(MOTION.attack_offset(MOTION.ATTACK_OUT_SEC / MOTION.attack_sec(), Vector2(32, 0)).x, MOTION.ATTACK_LUNGE_PX), true, "other lunges stay 6px")
	eq(MOTION.target_motion("damage"), "hit", "damage recoils")
	eq(MOTION.target_motion("support"), "lift", "heals lift")
	eq(MOTION.target_motion("ward"), "lift", "Ward lifts")
	eq(MOTION.target_motion(""), "", "a miss does not react")


func _test_commit_motion_on_hit_and_miss() -> void:
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
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": caster, "seat": 1})
	var hit_plans: Dictionary = MOTION.chrome_plans(hit.get("events", []))
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
	var miss_plans: Dictionary = MOTION.chrome_plans(missed.get("events", []))
	var hit_caster: Dictionary = hit_plans.get(1, {})
	var miss_caster: Dictionary = miss_plans.get(1, {})
	eq(bool(hit.get("ok", false)), true, "Strike hit still resolves")
	eq(bool(missed.get("ok", false)), true, "Strike miss still resolves")
	eq(bool(hit_caster.get("attack", false)), true, "Strike hit lunges")
	eq(bool(miss_caster.get("attack", false)), true, "Strike miss lunges")
	eq(bool(hit_caster.get("attack", false)), bool(miss_caster.get("attack", false)), "Strike miss uses the same caster lunge as a hit")
	eq(bool(hit_caster.get("cast", false)), bool(miss_caster.get("cast", false)), "Strike miss does not swap the caster motion")
	eq(bool((hit_plans.get(0, {}) as Dictionary).get("hit", false)), true, "Strike hit recoils the target")
	eq(miss_plans.has(0), false, "Strike miss does not recoil the target")
	var hold_miss: Dictionary = MOTION.chrome_plans([{
		"type": "miss",
		"spell": SpellKits.HOLD_LINE,
		"seat": 0,
	}])
	eq(bool((hold_miss.get(0, {}) as Dictionary).get("attack", false)), true, "Hold Line miss still lunges")
	eq(hold_miss.size(), 1, "Hold Line miss does not invent a target recoil")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(4, 1),
		"kestrel_facing": "E",
		"rolls": [100],
	})
	var shot_miss: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 1), "seat": 0})
	var shot_miss_plans: Dictionary = MOTION.chrome_plans(shot_miss.get("events", []))
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(4, 1),
		"kestrel_facing": "E",
		"rolls": [1],
	})
	var shot_hit: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 1), "seat": 0})
	var shot_hit_plans: Dictionary = MOTION.chrome_plans(shot_hit.get("events", []))
	eq(bool(shot_miss.get("ok", false)), true, "Mark Shot miss still resolves")
	eq(bool(shot_hit.get("ok", false)), true, "Mark Shot hit still resolves")
	eq(bool((shot_miss_plans.get(0, {}) as Dictionary).get("cast", false)), true, "Mark Shot miss winds up")
	eq(bool((shot_hit_plans.get(0, {}) as Dictionary).get("cast", false)), true, "Mark Shot hit winds up")
	eq(bool((shot_miss_plans.get(0, {}) as Dictionary).get("cast", false)), bool((shot_hit_plans.get(0, {}) as Dictionary).get("cast", false)), "Mark Shot miss uses the same caster wind-up")
	eq(shot_miss_plans.has(1), false, "Mark Shot miss does not recoil")
	eq(bool((shot_hit_plans.get(1, {}) as Dictionary).get("hit", false)), true, "Mark Shot hit recoils the target")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 40,
		"rolls": [100],
	})
	var mend_miss: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	var mend_miss_plan: Dictionary = MOTION.chrome_plans(mend_miss.get("events", [])).get(0, {})
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 40,
		"rolls": [1],
	})
	var mend_hit: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	var mend_hit_plan: Dictionary = MOTION.chrome_plans(mend_hit.get("events", [])).get(0, {})
	eq(bool(mend_miss_plan.get("cast", false)), true, "Mend miss winds up")
	eq(bool(mend_hit_plan.get("cast", false)), true, "Mend hit winds up")
	eq(bool(mend_miss_plan.get("lift", false)), false, "Mend miss does not lift")
	eq(bool(mend_hit_plan.get("lift", false)), true, "Mend hit lifts")


func _test_walk_hops_not_advance() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(7, 7),
	})
	var walk: Dictionary = _sim.submit({"type": "move", "to": Vector2i(3, 1), "seat": 0})
	eq(bool(walk.get("ok", false)), true, "a legal walk resolves")
	eq(CombatHUD.should_play_walk_hops(walk.get("events", [])), true, "a legal walk plays per-tile hops")
	var move := _first_type(walk.get("events", []), "move")
	var path: Array = move.get("path", [])
	eq(path.size(), 2, "two tiles is two hop steps")
	var prev: Vector2i = move.get("from", Vector2i.ZERO)
	for step in path:
		var cell: Vector2i = step
		var delta := cell - prev
		eq(absi(delta.x) + absi(delta.y), 1, "each walk hop is one ortho tile")
		prev = cell
	eq(prev, Vector2i(3, 1), "the hops land on the dest")
	_sim.submit({"type": "end_turn", "seat": 0})
	var adv: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(6, 7), "seat": 1})
	eq(bool(adv.get("ok", false)), true, "Advance still resolves")
	eq(str(_first_type(adv.get("events", []), "advance").get("type", "")), "advance", "Advance emits a teleport event")
	eq(CombatHUD.should_play_walk_hops(adv.get("events", [])), false, "Advance does not hop")
	var adv_plans: Dictionary = MOTION.chrome_plans(adv.get("events", []))
	eq(adv_plans.is_empty(), true, "Advance does not lunge or wind up")
	eq(_sim.snapshot()["units"][1]["pos"], Vector2i(6, 7), "Advance still snaps to the neighbor")


func _test_support_events_do_not_knock() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 40,
		"rolls": [1, 1],
	})
	var mend: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	eq(MOTION.target_motion(Pawn.resolve_flash_kind(_first_hit(mend.get("events", [])))), "lift", "Mend does not knock back")
	var tap: Dictionary = _sim.submit({"type": "cast", "spell": "pulse_tap", "to": Vector2i(1, 1), "seat": 0})
	eq(MOTION.target_motion(Pawn.resolve_flash_kind(_first_hit(tap.get("events", [])))), "lift", "Pulse Tap does not knock back")
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
	eq(MOTION.target_motion(Pawn.resolve_flash_kind(_first_hit(ward.get("events", [])))), "lift", "Ward does not knock back")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"rolls": [100],
	})
	var cleanse: Dictionary = _sim.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(1, 1), "seat": 0})
	eq(MOTION.target_motion(Pawn.resolve_flash_kind(_first_hit(cleanse.get("events", [])))), "lift", "Cleanse does not knock back")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(2, 1),
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1],
	})
	_sim.submit({"type": "end_turn"})
	var shot: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(1, 1), "seat": 1})
	eq(bool(shot.get("ok", false)), true, "adjacent Strike connects in the fixture")
	eq(MOTION.target_motion(Pawn.resolve_flash_kind(_first_hit(shot.get("events", [])))), "hit", "Strike still recoils")


func _test_pawn_samples_then_plants() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot(_unit("kestrel", "E", 0), 0)
	var sprite := pawn.get_node("Sprite") as Sprite2D
	eq(sprite.position, Vector2.ZERO, "snapshot leaves the sprite on the origin")
	eq(sprite.scale, Vector2(0.5, 0.5), "snapshot leaves the shipped scale")
	pawn._sample_hop(0.5)
	eq(sprite.position.y, -MOTION.HOP_PX, "pawn applies the hop on the sprite")
	eq(sprite.scale.y > sprite.scale.x, true, "pawn stretches the sprite at the hop crest")
	var chrome := pawn.get_node("Chrome") as Node2D
	eq(chrome.get_parent(), pawn, "name chrome stays on the pawn during a hop")
	eq(chrome.position.y, -MOTION.HOP_PX, "the name rides the walk hop")
	eq(chrome.position.x, 0.0, "the name does not slide sideways on a hop")
	eq(pawn.name_label_origin().y < Pawn.HEAD_HP_Y, true, "the name stays above the HP bar during a hop")
	pawn._sample_hop(1.0)
	eq(sprite.position, Vector2.ZERO, "hop sample ends on the origin")
	pawn._sample_death(1.0, -1.0)
	eq(sprite.rotation < 0.0, true, "death tilts the sprite")
	eq(sprite.scale.y < 0.5, true, "death squashes the sprite")
	pawn.plant_sprite()
	eq(sprite.position, Vector2.ZERO, "plant puts feet back on the origin")
	eq(sprite.scale, Vector2(0.5, 0.5), "plant restores the shipped scale")
	eq(sprite.rotation, 0.0, "plant clears the tilt")
	eq(sprite.offset, Vector2(0, -72), "foot offset stays shipped")
	pawn._sample_idle(0.0)
	var bob: float = sprite.position.y
	eq(absf(bob) <= MOTION.IDLE_BOB_PX + 0.001, true, "idle bob stays inside the tuned amplitude")
	var other := Pawn.new()
	get_root().add_child(other)
	other.apply_snapshot(_unit("ironjaw", "W", 1), 0)
	other._sample_idle(0.0)
	eq(absf((other.get_node("Sprite") as Sprite2D).position.y) <= MOTION.IDLE_BOB_PX + 0.001, true, "second unit bob stays inside the amplitude")
	pawn.free()
	other.free()


func _test_reduce_motion_skips() -> void:
	MOTION.set_reduce_motion(true)
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot(_unit("bastion", "S", 0), 0)
	eq(pawn.play_view_plan({"attack": true, "aim": Vector2(20, 10), "death": true}), 0.0, "reduce-motion plays no action")
	eq(pawn.motion_playing(), false, "reduce-motion does not hold the sprite")
	pawn.play_step_hop()
	eq((pawn.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "reduce-motion does not arc the step")
	var plan := {"hit": true, "death": true, "delay": true, "away": Vector2.RIGHT, "tilt": 1.0}
	eq(MOTION.plan_sec(plan) <= 0.6, true, "budget helper ignores the reduce flag")
	MOTION.clear_reduce_motion()
	eq(MOTION.reduce_motion(), false, "clearing the override restores motion")
	pawn.free()


func _test_live_tree() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	eq(pawn.is_inside_tree(), true, "live pawn enters the tree")
	pawn.apply_snapshot(_unit("mender", "E", 0), 0)
	MOTION.set_reduce_motion(true)
	eq(pawn.play_view_plan({"attack": true, "aim": Vector2(20, 10)}), 0.0, "reduce-motion skips an in-tree lunge")
	eq((pawn.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "reduce-motion leaves the in-tree sprite planted")
	MOTION.clear_reduce_motion()
	var dur := pawn.play_view_plan({"cast": true})
	eq(dur > 0.0 and dur <= 0.6, true, "cast wind-up reports a short duration")
	eq(pawn.motion_playing(), true, "cast wind-up owns the sprite")
	await process_frame
	await process_frame
	var risen: float = (pawn.get_node("Sprite") as Sprite2D).position.y
	eq(risen < -0.5, true, "cast wind-up lifts the sprite")
	pawn.settle_motion()
	eq(pawn.motion_playing(), false, "settle releases the sprite")
	eq((pawn.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "settle plants the feet")
	eq((pawn.get_node("Sprite") as Sprite2D).scale, Vector2(0.5, 0.5), "settle restores scale")
	eq((pawn.get_node("Sprite") as Sprite2D).rotation, 0.0, "settle clears rotation")
	pawn.play_step_hop()
	await create_timer(Pawn.WALK_HOP_SEC * 0.45).timeout
	eq((pawn.get_node("Sprite") as Sprite2D).position.y < -1.0, true, "a live hop leaves the tile")
	await create_timer(Pawn.WALK_HOP_SEC * 0.7).timeout
	eq((pawn.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "a live hop returns to the tile center")
	eq(pawn.motion_playing(), false, "a finished hop releases the sprite")
	var victim := Pawn.new()
	get_root().add_child(victim)
	victim.position = Vector2(80, 40)
	victim.apply_snapshot(_unit("kestrel", "W", 1), 0)
	await process_frame
	var recoil := pawn.play_view_plan({"attack": true, "aim": Vector2(80, 40)})
	var react := victim.play_view_plan({
		"hit": true,
		"death": true,
		"delay": true,
		"away": Vector2(80, 40),
		"tilt": 1.0,
	})
	eq(recoil <= 0.6 and react <= 0.6, true, "paired lunge and slump each fit the lock")
	await create_timer(0.12).timeout
	eq((pawn.get_node("Sprite") as Sprite2D).position.length() > 2.0, true, "live lunge steps toward the target")
	await create_timer(MOTION.ACTION_LOCK_MAX).timeout
	pawn.settle_motion()
	victim.settle_motion()
	eq((pawn.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "lunge ends on the pawn origin")
	eq((victim.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "slump keeps feet on the victim origin")
	eq((victim.get_node("Sprite") as Sprite2D).scale, Vector2(0.5, 0.5), "settle after slump restores scale")
	eq(victim.position, Vector2(80, 40), "the pawn node never leaves its tile")
	pawn.free()
	victim.free()


func _test_view_wiring() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	eq(view.contains("randi"), false, "board_view still does not roll")
	eq(view.split("_present_resolve(").size() >= 3, true, "hot-seat and online share resolve presentation")
	truthy(view.contains("_arm_view_motions"), "resolve arms view motions")
	truthy(view.contains("play_step_hop"), "walk steps arc on the sprite")
	truthy(view.contains("Pawn.WALK_HOP_SEC"), "the tile slide uses the pawn hop constant")
	eq(view.contains("STEP_SEC"), false, "the board does not keep a second hop duration")
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	truthy(pawn_src.contains("const WALK_HOP_SEC := 0.25"), "the hop constant is 0.25s on the pawn")
	truthy(pawn_src.contains("WALK_HOP_SEC)"), "the hop tween reads WALK_HOP_SEC")
	truthy(pawn_src.contains("walk_strip_speed_scale"), "a future walk strip reads the same hop length")
	truthy(view.contains("finish_step"), "each step plants the sprite")
	truthy(view.contains("_track_step_sort"), "hops retarget z while moving")
	truthy(view.contains("ACTION_LOCK_MAX"), "the action lock uses the shared budget")
	truthy(view.contains("_cell_to_local"), "elevated tiles still place the pawn")
	var process_idx := view.find("func _process")
	var hydrate_idx := view.find("func _hydrate_turn_clock")
	var process_src := view.substr(process_idx, hydrate_idx - process_idx)
	eq(process_src.contains("if _busy"), false, "motions do not freeze the host clock")
	eq(process_src.contains("_view_locked"), false, "the view lock does not freeze the host clock")
	truthy(process_src.contains("tick_turn_timer"), "the host clock still ticks")
	var play_idx := view.find("func _play_walk")
	var anim_idx := view.find("func _animate_path")
	var play_src := view.substr(play_idx, anim_idx - play_idx)
	eq(play_src.contains("_turn_clock.pause"), false, "step playback does not pause the clock")
	eq(play_src.contains("_turn_clock.stop"), false, "step playback does not stop the clock")
	eq(pawn_src.contains("Pulse"), false, "pawn does not invent Pulse")
	truthy(pawn_src.contains("Vector2(0, -72)"), "foot offset stays on the pawn")
	truthy(pawn_src.contains("Vector2(0.5, 0.5)"), "shipped scale stays on the pawn")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(sim_src.contains("view_motion"), false, "combat sim does not read view motion")
	eq(sim_src.contains("play_view_plan"), false, "combat sim does not play view motion")
	var motion_src := FileAccess.get_file_as_string("res://units/view_motion.gd")
	truthy(motion_src.contains("\"miss\""), "miss commits arm a caster plan")
	eq(is_equal_approx(MOTION.ATTACK_LUNGE_PX, 6.0), true, "the lunge constant is 6px")
	truthy(view.contains("chrome_plans"), "the board plays the shared hit and miss plans")
	truthy(view.contains("ShadeMarkers"), "Shade markers are not Units children")
	eq(view.contains("$Units.add_child(marker)"), false, "pawn rebuild cannot free Shade markers")
	eq(MOTION.caster_motion(SpellKits.AMBUSH), "attack", "Ambush stays the lunge-then-blink")
	eq(MOTION.caster_motion(SpellKits.DROP_SHADE), "cast", "Drop Shade stays a cast, not a blink")
	var present_idx := view.find("func _present_resolve")
	var path_idx := view.find("func _path_event")
	var present_src := view.substr(present_idx, path_idx - present_idx)
	var motion_at := present_src.find("_arm_view_motions")
	var vfx_at := present_src.find("_arm_vfx")
	eq(motion_at >= 0 and vfx_at > motion_at, true, "spell VFX still arms with the body motion")
	var hop_idx := view.find("func _animate_path")
	var cell_idx := view.find("func _set_pawn_cell")
	var anim_src := view.substr(hop_idx, cell_idx - hop_idx)
	truthy(anim_src.contains("for step in path"), "each path cell is its own hop")
	truthy(anim_src.contains("play_step_hop"), "each path cell plays the sprite hop")
	truthy(anim_src.contains("origin"), "the hop starts on the departure tile, not the snapped dest")
	truthy(pawn_src.contains("WalkStrip"), "a walk strip node can drive the hop")
	truthy(pawn_src.contains("walk_se"), "SE walk frames are the Batch 1 clip name")
	truthy(pawn_src.contains("attack_ne"), "NE attack frames are the Batch 1 clip name")
	truthy(pawn_src.contains("strip_speed_scale"), "strip timing follows the hop or lunge window")


func _test_shade_markers_survive_rebuild() -> void:
	var live := load("res://tests/shade_marker_live.gd")
	await live.run(self)


func _unit(class_id: String, facing: String, seat: int) -> Dictionary:
	return {
		"pos": Vector2i(2, 2),
		"name": SpellKits.display_name(class_id),
		"class_id": class_id,
		"facing": facing,
		"seat": seat,
		"hp": 80,
		"max_hp": 80,
		"alive": true,
		"stun_remaining": 0,
	}


func _first_hit(events: Array) -> Dictionary:
	return _first_type(events, "hit")


func _first_type(events: Array, typ: String) -> Dictionary:
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == typ:
			return event
	return {}


func _solid_tex() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.75, 0.35, 1))
	return ImageTexture.create_from_image(image)


func _strip_frames(anim: String, count: int, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	var tex := _solid_tex()
	for _i in count:
		frames.add_frame(anim, tex)
	return frames


func _test_strip_fallback() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	var stand_in := AnimatedSprite2D.new()
	stand_in.name = "Sprite"
	stand_in.sprite_frames = null
	pawn.add_child(stand_in)
	pawn.apply_snapshot(_unit("kestrel", "E", 0), 0)
	var sprite := pawn.get_node("Sprite") as Sprite2D
	truthy(sprite != null, "a strip standing in for Sprite does not replace the static body")
	truthy(sprite.texture != null, "missing strip frames keep the facing texture")
	eq(sprite.visible, true, "missing strip frames leave the static sprite visible")
	var rehomed := pawn.get_node_or_null("BodyStrip") as AnimatedSprite2D
	truthy(rehomed != null, "the stand-in strip is kept beside the static sprite")
	eq(rehomed.visible, false, "an empty stand-in strip stays hidden")
	pawn.play_step_hop()
	await process_frame
	eq(sprite.visible, true, "a hop with no frames keeps the static sprite")
	eq(rehomed.visible, false, "a hop does not show an empty strip")
	pawn.settle_motion()
	var empty := AnimatedSprite2D.new()
	empty.name = "WalkStrip"
	var blank := SpriteFrames.new()
	blank.add_animation("walk_se")
	empty.sprite_frames = blank
	pawn.add_child(empty)
	pawn.play_step_hop()
	await process_frame
	eq(empty.visible, false, "a walk clip with zero frames stays hidden")
	eq(sprite.visible, true, "zero frames keep the static sprite on screen")
	eq(sprite.texture != null, true, "zero frames do not clear the facing texture")
	pawn.settle_motion()
	empty.queue_free()
	await process_frame
	var walk := AnimatedSprite2D.new()
	walk.name = "KestrelSE"
	walk.sprite_frames = _strip_frames("walk_se", 6, 24.0)
	pawn.add_child(walk)
	pawn.play_step_hop()
	await process_frame
	eq(walk.visible, true, "SE walk frames play during the hop")
	eq(String(walk.animation), "walk_se", "the hop plays the SE clip for an east facing")
	eq(is_equal_approx(walk.speed_scale, Pawn.walk_strip_speed_scale()), true, "the SE hop strip matches the 0.25s hop")
	eq(sprite.visible, false, "the static sprite steps aside while the strip plays")
	eq(walk.offset, Vector2(0, -72), "the strip uses the shipped foot pivot")
	await create_timer(Pawn.WALK_HOP_SEC + 0.05).timeout
	eq(sprite.visible, true, "the static sprite returns when the hop ends")
	eq(walk.visible, false, "the walk strip hides after the hop")
	eq(sprite.texture != null, true, "the facing texture is still on the sprite")
	eq(sprite.position, Vector2.ZERO, "the hop still plants the feet")
	pawn.facing = "N"
	pawn.play_step_hop()
	await process_frame
	eq(walk.visible, false, "east-only frames do not play for a north facing")
	eq(sprite.visible, true, "a facing with no frames keeps the static sprite")
	pawn.settle_motion()
	walk.queue_free()
	await process_frame
	pawn.facing = "N"
	var attack := AnimatedSprite2D.new()
	attack.name = "AttackStrip"
	attack.sprite_frames = _strip_frames("attack_ne", 6, 24.0)
	pawn.add_child(attack)
	var dur := pawn.play_view_plan({"attack": true, "aim": Vector2(20, -10)})
	await process_frame
	eq(dur > 0.0 and dur <= 0.6, true, "an attack plan still reports a short lunge")
	eq(attack.visible, true, "NE attack frames play during the lunge")
	eq(String(attack.animation), "attack_ne", "the lunge plays the NE attack clip")
	var expect := Pawn.strip_speed_scale(6, 24.0, MOTION.attack_sec())
	eq(is_equal_approx(attack.speed_scale, expect), true, "the attack strip fits the lunge window")
	eq(sprite.visible, false, "the static sprite steps aside during the attack strip")
	await create_timer(0.12).timeout
	eq(sprite.position.length() > 2.0, true, "the lunge still moves the body while the strip plays")
	pawn.settle_motion()
	eq(sprite.visible, true, "settle restores the static sprite after the lunge")
	eq(attack.visible, false, "settle hides the attack strip")
	eq(sprite.position, Vector2.ZERO, "settle plants the feet after a strip lunge")
	var miss_dur := pawn.play_view_plan({"attack": true, "aim": Vector2(20, -10)})
	await process_frame
	eq(is_equal_approx(miss_dur, dur), true, "a miss lunge lasts as long as a hit lunge")
	eq(attack.visible, true, "a miss plays the same attack strip as a hit")
	pawn.settle_motion()
	pawn.free()


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
