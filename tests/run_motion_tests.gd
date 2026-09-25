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
	print("Motion tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_tunables_and_budget()
	_test_curves_return_to_origin()
	_test_idle_phase()
	_test_caster_and_target_kinds()
	_test_support_events_do_not_knock()
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
	eq(MOTION.HOP_PX >= 4.0 and MOTION.HOP_PX <= 6.0, true, "step arc is 4-6px")
	eq(Pawn.WALK_HOP_SEC, 0.25, "per-tile hop is 0.25s")
	eq(is_equal_approx(Pawn.walk_strip_speed_scale(), 1.0), true, "a 6-frame 24fps strip matches the hop at speed_scale 1")
	eq(MOTION.ATTACK_LUNGE_PX >= 8.0 and MOTION.ATTACK_LUNGE_PX <= 12.0, true, "lunge is 8-12px")
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
	eq(MOTION.target_motion("damage"), "hit", "damage recoils")
	eq(MOTION.target_motion("support"), "lift", "heals lift")
	eq(MOTION.target_motion("ward"), "lift", "Ward lifts")
	eq(MOTION.target_motion(""), "", "a miss does not react")


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
	var chrome := pawn.get_node("Chrome") as Node2D
	eq(chrome.get_parent(), pawn, "name chrome stays on the pawn during a hop")
	eq(chrome.position, Vector2.ZERO, "a hop does not move the name")
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
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "hit":
			return event
	return {}


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
