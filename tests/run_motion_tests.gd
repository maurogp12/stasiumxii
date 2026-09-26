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
	await _test_failed_strip_falls_back_to_hop()
	await _test_driven_walk_cycle()
	await _test_class_plant_anchor()
	await _test_walk_idle_matches_strip()
	await _test_live_walk_keeps_sheet()
	await _test_batch1_disk_strips()
	await _test_batch1c_hot_swap()
	await _test_shade_markers_survive_rebuild()
	await _test_ambush_present_race()
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
	_test_strip_library_missing_and_slice()


func _test_tunables_and_budget() -> void:
	eq(MOTION.ACTION_LOCK_MAX <= 0.6, true, "action input lock is at most 0.6s")
	eq(MOTION.attack_sec() <= 0.6, true, "attack motion is at most 0.6s")
	eq(MOTION.cast_sec() <= 0.6, true, "cast motion is at most 0.6s")
	eq(MOTION.hit_sec() <= 0.6, true, "hit motion is at most 0.6s")
	eq(MOTION.support_sec() <= 0.6, true, "support lift is at most 0.6s")
	eq(MOTION.death_sec() <= 0.6, true, "death slump is at most 0.6s")
	eq(MOTION.IDLE_PERIOD >= 1.6 and MOTION.IDLE_PERIOD <= 2.2, true, "idle period is a slow breathe")
	eq(MOTION.IDLE_BOB_PX >= 1.0 and MOTION.IDLE_BOB_PX <= 2.0, true, "idle bob is 1-2px")
	eq(MOTION.HOP_PX >= 2.0 and MOTION.HOP_PX <= 4.0, true, "hop peak is 2-4px")
	eq(MOTION.WALK_BOUNCE_PX, MOTION.HOP_PX, "walk bounce uses the hop offset amplitude")
	eq(MOTION.HOP_PX < 8.0, true, "the old 36px hop is gone")
	eq(is_equal_approx(Pawn.WALK_TILE_SEC, 0.30), true, "per-tile travel is about 300ms")
	eq(Pawn.WALK_TILE_SEC >= 0.25 and Pawn.WALK_TILE_SEC <= 0.35, true, "per-tile travel stays in the phase A window")
	eq(Pawn.WALK_HOP_SEC, Pawn.WALK_TILE_SEC, "the old hop duration alias matches the tile")
	eq(is_equal_approx(MOTION.WALK_STEP_SEC, Pawn.WALK_TILE_SEC), true, "one hop period is one tile")
	var authored_cycle := float(Pawn.WALK_STRIP_FRAMES) / Pawn.WALK_STRIP_FPS
	eq(is_equal_approx(Pawn.walk_strip_speed_scale(), authored_cycle / Pawn.WALK_TILE_SEC), true, "walk strips play one full cycle per tile")
	eq(is_equal_approx(Pawn.WALK_STRIP_FPS, 12.0), true, "walk strips are authored at 12 fps")
	eq(Pawn.WALK_STRIP_FRAMES, 6, "walk strips are 6 frames")
	eq(is_equal_approx(Pawn.walk_playback_fps(6), 20.0), true, "six frames play at about 20 fps")
	eq(absf(Pawn.walk_playback_fps(8) - 27.0) < 0.5, true, "eight frames play at about 27 fps")
	eq(MOTION.stride_cycles_per_tile(), 1, "exactly one stride cycle per tile")
	var plant_share := 1.0 - MOTION.HOP_PLANT_AT
	eq(plant_share >= 0.15 and plant_share <= 0.20, true, "the plant is the last 15-20% of the tween")
	eq(MOTION.STEP_SETTLE_SEC >= 0.04 and MOTION.STEP_SETTLE_SEC <= 0.06, true, "step anticipation is a 40-60ms weight shift")
	eq(is_equal_approx(Pawn.strip_speed_scale(8, 24.0, Pawn.WALK_HOP_SEC), (8.0 / 24.0) / Pawn.WALK_HOP_SEC), true, "a longer one-shot still fits the hop window")
	eq(Pawn.strip_speed_scale(0, 24.0, Pawn.WALK_HOP_SEC), 1.0, "an empty strip does not divide by zero")
	eq(MOTION.ATTACK_LUNGE_PX >= 16.0 and MOTION.ATTACK_LUNGE_PX <= 20.0, true, "melee lunge reaches the tile edge")
	eq(MOTION.AMBUSH_LUNGE_PX > MOTION.ATTACK_LUNGE_PX, true, "Ambush keeps a longer reach")
	eq(MOTION.ANTICIPATION_SEC >= 0.06 and MOTION.ANTICIPATION_SEC <= 0.10, true, "anticipation is a short wind-up")
	eq(MOTION.attack_sec() <= MOTION.ACTION_LOCK_MAX, true, "attack wind-up and hold fit the action lock")
	eq(MOTION.cast_sec() <= MOTION.ACTION_LOCK_MAX, true, "cast wind-up and hold fit the action lock")
	eq(MOTION.impact_hold_sec() > 0.05, true, "impact hold is long enough to read")
	eq(MOTION.impact_hold_sec() <= MOTION.ACTION_LOCK_MAX, true, "impact hold does not exceed the action lock")
	var prelude := MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC + MOTION.ATTACK_BACK_SEC
	eq(MOTION.impact_hold_sec() <= MOTION.ACTION_LOCK_MAX - prelude + 0.0001, true, "impact hold fits the remaining lock")
	eq(MOTION.impact_hold_sec(MOTION.ACTION_LOCK_MAX), 0.0, "a spent lock leaves no impact hold")
	eq(MOTION.plan_sec({"attack": true, "aim": Vector2(20, 10)}) <= MOTION.ACTION_LOCK_MAX, true, "an attack plan stays inside the lock")
	eq(MOTION.plan_sec({"cast": true}) <= MOTION.ACTION_LOCK_MAX, true, "a cast plan stays inside the lock")
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
	eq(MOTION.hop_offset(MOTION.HOP_PLANT_AT), Vector2.ZERO, "the plant window is back on the tile")
	eq(MOTION.hop_offset(0.9), Vector2.ZERO, "the last slice stays planted")
	var crest: Vector2 = MOTION.hop_offset(0.5)
	eq(crest.x, 0.0, "hop arc has no sideways slide")
	eq(crest.y, -MOTION.HOP_PX, "bounce crest is the tuned rise")
	eq(MOTION.hop_offset(0.08).y < -0.2, true, "the hop rises off the tile instead of pressing in")
	eq(MOTION.hop_offset(0.08).y > -MOTION.HOP_PX, true, "the early rise is below the crest")
	var sunk := false
	for hop_i in 21:
		if MOTION.hop_offset(float(hop_i) / 20.0).y > 0.001:
			sunk = true
	eq(sunk, false, "the hop never presses into the floor")
	eq(is_equal_approx(MOTION.contact_shadow(0.5), 0.62), true, "the contact shadow shrinks at the crest")
	eq(is_equal_approx(MOTION.contact_shadow(0.0), 1.0), true, "the contact shadow is full on the plant")
	eq(is_equal_approx(MOTION.contact_shadow(0.9), 1.0), true, "the plant shadow is full while the sprite is down")
	eq(MOTION.hop_scale(0.0), Vector2.ONE, "walk bounce does not scale")
	eq(MOTION.hop_scale(0.5), Vector2.ONE, "walk bounce does not stretch at the crest")
	eq(MOTION.hop_scale(1.0), Vector2.ONE, "walk bounce does not scale at the plant")
	eq(MOTION.hop_scale(0.86), Vector2.ONE, "walk bounce does not squash on the landing")
	eq(MOTION.walk_bounce_offset(0.0), Vector2.ZERO, "bounce plants at the start of a step")
	var mid_step := MOTION.walk_bounce_offset(MOTION.WALK_STEP_SEC * 0.5)
	eq(mid_step.y, -MOTION.WALK_BOUNCE_PX, "cycle crest is the 2-4px hop")
	eq(mid_step.x, 0.0, "bounce has no sideways slide")
	var across_tile := MOTION.walk_bounce_offset(Pawn.WALK_TILE_SEC)
	eq(across_tile, Vector2.ZERO, "a tile boundary plants the hop")
	eq(absf(across_tile.y) <= MOTION.WALK_BOUNCE_PX + 0.001, true, "bounce stays inside 2-4px across a tile")
	eq(MOTION.walk_bounce_offset(MOTION.WALK_STEP_SEC), Vector2.ZERO, "the next plant lands on the walk cycle")
	eq(MOTION.step_travel(0.0), 0.0, "a step starts on the departure tile")
	eq(MOTION.step_travel(0.08) > 0.0, true, "the tween eases immediately")
	eq(MOTION.step_travel(0.08) < 0.08, true, "ease-in is slower than a linear skate at the start")
	eq(MOTION.step_travel(1.0), 1.0, "a step ends on the arrival tile")
	eq(MOTION.step_travel(0.9), 1.0, "the plant holds the arrival tile")
	eq(MOTION.step_travel(MOTION.HOP_PLANT_AT), 1.0, "travel has arrived when the plant starts")
	var stride := MOTION.step_travel(0.5)
	eq(stride > 0.35 and stride < 0.85, true, "the stride is underway at mid tile")
	eq(MOTION.step_travel(0.3) < MOTION.step_travel(0.55), true, "travel only moves forward")
	eq(is_equal_approx(MOTION.step_travel(0.5), 0.5), false, "mid-tile travel is eased, not a raw lerp")
	eq(is_equal_approx(MOTION.step_travel(0.2), 0.2), false, "early travel is not a linear skate")
	eq(MOTION.HOP_PX <= 4.0, true, "the body rise stays a short hop, not a long arc")
	eq(MOTION.hop_crest_px("bastion") >= 2.0 and MOTION.hop_crest_px("bastion") <= 3.0, true, "bastion crest stays in the heavy band")
	eq(MOTION.hop_crest_px("ironjaw") >= 2.0 and MOTION.hop_crest_px("ironjaw") <= 3.0, true, "ironjaw crest stays in the heavy band")
	eq(MOTION.hop_crest_px("kestrel") >= 3.0 and MOTION.hop_crest_px("kestrel") <= 4.0, true, "kestrel crest stays in the light band")
	eq(MOTION.hop_crest_px("gloam") >= 3.0 and MOTION.hop_crest_px("gloam") <= 4.0, true, "gloam crest stays in the light band")
	eq(is_equal_approx(MOTION.hop_crest_px("mender"), MOTION.HOP_PX), true, "mender keeps the shared crest")
	eq(is_equal_approx(MOTION.hop_offset(0.5, MOTION.hop_crest_px("ironjaw")).y, -MOTION.hop_crest_px("ironjaw")), true, "ironjaw crest is the heavy hop")
	eq(MOTION.hop_offset(0.5, 9.0).y >= -4.0, true, "a crest above 4px clamps")
	eq(MOTION.hop_offset(0.5, 9.0).y <= -4.0 + 0.001, true, "the clamp still reaches the cap")
	eq(MOTION.plant_scale(0.5), Vector2.ONE, "mid-hop does not squash")
	eq(MOTION.plant_scale(0.0), Vector2.ONE, "departure is already released")
	eq(MOTION.plant_scale(1.0), Vector2.ONE, "the plant releases to rest scale")
	var landed_scale: Vector2 = MOTION.plant_scale(MOTION.HOP_PLANT_AT)
	eq(is_equal_approx(landed_scale.y, MOTION.PLANT_SQUASH_Y), true, "the plant squashes Y to about 0.96")
	eq(is_equal_approx(landed_scale.x, 1.0), true, "the plant does not widen")
	var mid_plant: Vector2 = MOTION.plant_scale((MOTION.HOP_PLANT_AT + 1.0) * 0.5)
	eq(mid_plant.y > MOTION.PLANT_SQUASH_Y and mid_plant.y < 1.0, true, "the squash releases across the plant")
	var plant_sec := Pawn.WALK_TILE_SEC * (1.0 - MOTION.HOP_PLANT_AT)
	eq(plant_sec >= 0.04 and plant_sec <= 0.06, true, "plant squash releases in 40-60ms without stretching the tile")
	eq(MOTION.STOP_IDLE_SEC >= 0.05, true, "path end holds at least one readable idle frame")
	eq(MOTION.STOP_IDLE_SEC <= 0.16, true, "the stop idle stays a short read")
	eq(MOTION.walk_cycle_frame(0.0, 6, 0), 0, "a step starts on the contact frame")
	eq(MOTION.walk_cycle_frame(0.5, 6, 0) != 0, true, "the stride leaves the idle frame")
	eq(MOTION.walk_cycle_frame(0.5, 6, 0) != MOTION.walk_cycle_frame(1.0, 6, 0), true, "arrival is not the passing frame")
	eq(MOTION.walk_cycle_frame(1.0, 6, 0), 0, "arrival plants frame 0")
	eq(MOTION.walk_cycle_frame(1.0, 6, 0), MOTION.walk_cycle_frame(0.0, 6, 1), "the next segment starts on the landed contact")
	eq(MOTION.walk_cycle_frame(0.99, 6, 0), 0, "the plant does not freeze a passing frame")
	eq(MOTION.walk_cycle_frame(0.35, 6, 0) != MOTION.walk_cycle_frame(0.55, 6, 0), true, "the cycle advances through the stride")
	eq(MOTION.walk_cycle_frame(1.0, 1, 0), 0, "a one-frame strip has nothing to advance")
	eq(_stride_wraps(6), 1, "a six-frame strip wraps once per tile")
	eq(_stride_wraps(8), 1, "an eight-frame strip wraps once per tile")
	for step_t in [0.25, 0.4, 0.55]:
		var open_frame := MOTION.walk_cycle_frame(step_t, 6, 0)
		eq(MOTION.step_travel(step_t) > 0.0 and MOTION.step_travel(step_t) < 1.0, true, "the stride is between the plants")
		eq(open_frame != 0 and open_frame != MOTION.walk_cycle_frame(1.0, 6, 0), true, "a moving foot does not show a contact frame")
	for hop_i in 21:
		var hop_t := float(hop_i) / 20.0
		var moving := MOTION.hop_offset(hop_t).y < -0.001
		var shown := MOTION.walk_cycle_frame(hop_t, 6, 0)
		if moving:
			eq(shown != 0, true, "a moving hop does not idle on the contact frame")
		else:
			eq(shown, 0, "hop Y=0 shows the contact frame")
	eq(StripLibrary.contact_index_from_metrics([140, 150, 148], [120, 100, 110]), 1, "a lifted frame 0 retargets to the planted row")
	eq(StripLibrary.contact_index_from_metrics([150, 145, 150], [90, 110, 90]), 0, "frame 0 stays when it shares the planted row")
	eq(MOTION.walk_cycle_frame(0.0, 6, 0, 2), 2, "a retargeted contact shows at the departure")
	eq(MOTION.walk_cycle_frame(1.0, 6, 0, 2), 2, "arrival holds the retargeted contact")
	eq(MOTION.walk_cycle_frame(0.5, 6, 0, 2) != 2, true, "the stride leaves the retargeted contact")
	eq(_cycle_visits_contact(6, 0), true, "a six-frame cycle shows contact only on the plant")
	eq(_cycle_visits_contact(6, 2), true, "a retargeted cycle still visits every cell once")
	eq(MOTION.stride_lead(0.0, Vector2(20, 10)), Vector2.ZERO, "the hop does not lean off the cell")
	eq(MOTION.stride_lead(0.5, Vector2(20, 10)), Vector2.ZERO, "horizontal travel stays on the foot")
	eq(MOTION.stride_lead(1.0, Vector2(20, 10)), Vector2.ZERO, "arrival does not leave a lead")
	eq(MOTION.stride_rise(0.0), Vector2.ZERO, "the start keeps the body on the foot")
	eq(MOTION.stride_rise(1.0), Vector2.ZERO, "arrival puts the body back on the foot")
	var rise := MOTION.stride_rise(0.5)
	eq(rise.x == 0.0 and rise.y <= -2.0 and rise.y >= -4.0, true, "the body rises a few pixels at mid tile")
	eq(MOTION.anticipate_segment(0, false), true, "the first tile settles even when facing already matches")
	eq(MOTION.anticipate_segment(1, false), false, "a straight middle tile does not settle")
	eq(MOTION.anticipate_segment(2, true), true, "a direction change settles")
	eq(MOTION.dust_on_plant(false, false), false, "a straight middle tile does not puff")
	eq(MOTION.dust_on_plant(true, false), true, "a facing change puffs on the plant")
	eq(MOTION.dust_on_plant(false, true), true, "the final plant puffs")
	var anti := MOTION.step_anticipation_offset(0.5, Vector2(20, 10))
	eq(anti.length() > 0.5 and anti.length() < 4.0, true, "the weight shift is a small lean")
	eq(MOTION.step_anticipation_offset(0.0, Vector2(20, 10)), Vector2.ZERO, "anticipation starts on the foot")
	eq(MOTION.step_anticipation_offset(1.0, Vector2(20, 10)), Vector2.ZERO, "anticipation ends on the foot")
	var dust_life := preload("res://vfx/vfx_budget.gd").STAMP_DUST_LIFE
	eq(dust_life >= 0.20 and dust_life <= 0.35, true, "footstep dust is a short puff")
	eq(MOTION.walk_segment_facing(Vector2i(2, 2), Vector2i(3, 2), Vector2(32, 16)), "E", "an east step faces east")
	eq(MOTION.walk_segment_facing(Vector2i(2, 2), Vector2i(2, 1), Vector2(32, -16)), "N", "a north step faces north")
	eq(MOTION.walk_segment_facing(Vector2i(4, 4), Vector2i(3, 4), Vector2(-32, -16)), "W", "a west step faces west")
	eq(MOTION.walk_segment_facing(Vector2i(4, 4), Vector2i(4, 5), Vector2(-32, 16)), "S", "a south step faces south")
	var up_right := Vector2(32, -16)
	eq(MOTION.walk_segment_facing(Vector2i(5, 5), Vector2i(6, 4), up_right), "N", "an up-right diagonal faces into the segment")
	eq(MOTION.walk_segment_facing(Vector2i(5, 5), Vector2i(6, 4), up_right) == "S", false, "an up-right diagonal does not face backwards")
	eq(MOTION.FACING_SCREEN["N"], Pawn.FACING_ISO["N"], "north screen axis matches the pawn")
	eq(MOTION.FACING_SCREEN["E"], Pawn.FACING_ISO["E"], "east screen axis matches the pawn")
	eq(MOTION.FACING_SCREEN["S"], Pawn.FACING_ISO["S"], "south screen axis matches the pawn")
	eq(MOTION.FACING_SCREEN["W"], Pawn.FACING_ISO["W"], "west screen axis matches the pawn")
	var aim := Vector2(32, 16)
	eq(MOTION.attack_offset(0.0, aim), Vector2.ZERO, "lunge starts on the tile")
	eq(MOTION.attack_offset(1.0, aim), Vector2.ZERO, "lunge returns to the tile")
	var peak_t := (MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC) / MOTION.attack_sec()
	var peak: Vector2 = MOTION.attack_offset(peak_t, aim)
	eq(is_equal_approx(peak.length(), MOTION.ATTACK_LUNGE_PX), true, "lunge reaches the tuned distance")
	var anti_t := (MOTION.ANTICIPATION_SEC * 0.92) / MOTION.attack_sec()
	var pulled: Vector2 = MOTION.attack_offset(anti_t, Vector2(32, 0))
	eq(pulled.x < -1.0, true, "anticipation pulls back before the lunge")
	var coiled: Dictionary = MOTION.attack_pose(anti_t, Vector2(32, 0))
	eq((coiled["scale"] as Vector2).y < 1.0, true, "anticipation squashes")
	eq((coiled["scale"] as Vector2).x > 1.0, true, "anticipation widens")
	var hold_t := (MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC + MOTION.impact_hold_sec() * 0.5) / MOTION.attack_sec()
	eq(MOTION.attack_phase(hold_t), "hold", "the lunge holds on the impact pose")
	eq(is_equal_approx(MOTION.attack_offset(hold_t, Vector2(32, 0)).x, MOTION.ATTACK_LUNGE_PX), true, "impact hold stays at the lunge")
	eq(MOTION.attack_phase(anti_t), "anticipation", "the wind-up is its own phase")
	eq(MOTION.hit_offset(0.0, aim), Vector2.ZERO, "knockback starts on the tile")
	eq(MOTION.hit_offset(1.0, aim), Vector2.ZERO, "knockback returns to the tile")
	var knock_t := MOTION.HIT_OUT_SEC / MOTION.hit_sec()
	var knock: Vector2 = MOTION.hit_offset(knock_t, aim)
	eq(is_equal_approx(knock.length(), MOTION.HIT_KNOCK_PX), true, "knockback reaches the tuned distance")
	var stop_t := (MOTION.HIT_OUT_SEC + MOTION.HIT_STOP_SEC * 0.5) / MOTION.hit_sec()
	eq(is_equal_approx(MOTION.hit_offset(stop_t, aim).length(), MOTION.HIT_KNOCK_PX), true, "hit-stop holds the knock")
	var flinch: Vector2 = MOTION.hit_squash(knock_t)
	eq(flinch.x > 1.05, true, "flinch widens on the knock")
	eq(flinch.y < 0.9, true, "flinch compresses on the knock")
	eq(MOTION.hit_squash(0.0), Vector2.ONE, "flinch starts at rest scale")
	eq(MOTION.hit_squash(1.0), Vector2.ONE, "flinch releases to rest scale")
	eq(MOTION.support_offset(0.0), Vector2.ZERO, "lift starts on the tile")
	eq(MOTION.support_offset(1.0), Vector2.ZERO, "lift returns to the tile")
	eq(MOTION.support_offset(0.5).x, 0.0, "heal lift is not a knockback")
	eq(MOTION.support_offset(0.5).y, -MOTION.SUPPORT_RISE_PX, "heal lift rises")
	var cast_rest: Dictionary = MOTION.cast_pose(1.0)
	eq(cast_rest["pos"], Vector2.ZERO, "cast releases to the tile")
	eq(cast_rest["scale"], Vector2.ONE, "cast scale releases to rest")
	var cast_hold_t := (MOTION.ANTICIPATION_SEC + MOTION.CAST_RISE_SEC + MOTION.impact_hold_sec() * 0.5) / MOTION.cast_sec()
	var held: Dictionary = MOTION.cast_pose(cast_hold_t)
	eq((held["pos"] as Vector2).y, -MOTION.CAST_RISE_PX, "cast holds the rise")
	eq(is_equal_approx((held["scale"] as Vector2).y, MOTION.CAST_SCALE), true, "cast holds the scale-up")
	eq(MOTION.cast_phase(cast_hold_t), "hold", "cast holds the impact pose")
	var pointed: Dictionary = MOTION.cast_pose(cast_hold_t, Vector2(40, 0))
	eq((pointed["pos"] as Vector2).x > 8.0, true, "cast points toward the effect")
	eq(is_equal_approx((pointed["pos"] as Vector2).y, -MOTION.CAST_RISE_PX), true, "the point keeps the rise")
	var turned: Array = MOTION.facing_turn("E", "S")
	eq(turned.size(), 2, "a 90 degree turn is two frames")
	eq(str(turned[0]), "S", "a quarter turn snaps to the new facing")
	eq(str(turned[1]), "S", "the turn ends on the new facing")
	eq(MOTION.facing_turn("E", "E").is_empty(), true, "a matching facing does not turn")
	var about: Array = MOTION.facing_turn("E", "W")
	eq(about.size(), 2, "a 180 holds the new facing")
	eq(str(about[0]), "W", "a 180 does not show a side facing")
	eq(str(about[1]), "W", "the 180 turn lands on the destination facing")
	eq(MOTION.is_about_face("E", "W"), true, "east to west is an about-face")
	eq(MOTION.is_about_face("N", "S"), true, "north to south is an about-face")
	eq(MOTION.is_about_face("E", "S"), false, "a quarter turn is not an about-face")
	eq(MOTION.is_about_face("E", "E"), false, "a matching facing is not an about-face")
	var crest_scale: Vector2 = MOTION.fallback_hop_scale(0.45)
	eq(crest_scale.y > 1.0, true, "a missing walk strip stretches at the crest")
	eq(crest_scale.x < 1.0, true, "a missing walk strip narrows at the crest")
	var launch_scale: Vector2 = MOTION.fallback_hop_scale(0.08)
	eq(launch_scale.y < 1.0, true, "a missing walk strip squashes on launch")
	eq(MOTION.fallback_hop_scale(0.0), Vector2.ONE, "fallback hop starts at rest scale")
	eq(MOTION.fallback_hop_scale(1.0), Vector2.ONE, "fallback hop plants at rest scale")
	var cast_anti_t := (MOTION.ANTICIPATION_SEC * 0.92) / MOTION.cast_sec()
	var cast_coil: Dictionary = MOTION.cast_pose(cast_anti_t)
	eq((cast_coil["scale"] as Vector2).y < 1.0, true, "cast anticipation squashes")
	eq((cast_coil["pos"] as Vector2).y > 0.0, true, "cast anticipation dips before the rise")
	eq(MOTION.CAST_DIP_PX >= 5.0, true, "the cast coil is deep enough to read")
	eq(MOTION.CAST_RISE_PX >= 8.0, true, "the cast rise clears the coil")
	eq(MOTION.death_sec() >= 0.45, true, "death holds long enough to read")
	var mid_death: Dictionary = MOTION.death_pose(0.5, 1.0)
	eq(is_equal_approx((mid_death["scale"] as Vector2).y, MOTION.DEATH_SQUASH_Y), true, "death has collapsed by the middle of the beat")
	eq(float(mid_death["fade"]) > 0.5, true, "the downed pose stays visible through the hold")
	eq(MOTION.landing_scale(0.0), Vector2.ONE, "a landing starts at rest scale")
	eq(MOTION.landing_scale(1.0), Vector2.ONE, "a landing ends at rest scale")
	var planted: Vector2 = MOTION.landing_scale(0.2)
	eq(planted.x > 1.05 and planted.y < 0.95, true, "a landing squashes into the tile")
	eq(MOTION.gesture_reach("rest"), 0.0, "a resting body hides the hand")
	eq(MOTION.gesture_reach("strike") > MOTION.gesture_reach("anticipation"), true, "the hand reaches farther on the strike")
	eq(MOTION.gesture_reach("hold") > 10.0, true, "the impact pose keeps the hand out")
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
	eq(MOTION.caster_motion(SpellKits.CRUSH), "attack", "Crush lunges")
	eq(MOTION.caster_motion(SpellKits.MARK_SHOT), "cast", "Mark Shot winds up")
	eq(MOTION.caster_motion(SpellKits.DETONATE), "cast", "Detonate winds up")
	eq(MOTION.caster_motion(SpellKits.MEND), "cast", "Mend winds up")
	eq(MOTION.caster_motion(SpellKits.WARD), "cast", "Ward winds up")
	eq(MOTION.caster_motion(SpellKits.CLEANSE), "cast", "Cleanse winds up")
	eq(MOTION.caster_motion(SpellKits.ADVANCE), "", "Advance stays a teleport snap")
	eq(MOTION.caster_motion(SpellKits.AMBUSH), "attack", "Ambush contact is still a slash")
	eq(MOTION.caster_motion(SpellKits.DROP_SHADE), "cast", "Drop Shade still winds up")
	var lunge_peak := (MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC) / MOTION.attack_sec()
	var ambush_reach: Vector2 = MOTION.attack_offset(lunge_peak, Vector2(32, 0), MOTION.AMBUSH_LUNGE_PX)
	eq(is_equal_approx(ambush_reach.x, MOTION.AMBUSH_LUNGE_PX), true, "Ambush reach is phone-readable")
	eq(is_equal_approx(MOTION.attack_offset(lunge_peak, Vector2(32, 0)).x, MOTION.ATTACK_LUNGE_PX), true, "other lunges stay in the phone band")
	var ambush_plan: Dictionary = MOTION.chrome_plans([{
		"type": "miss",
		"spell": SpellKits.AMBUSH,
		"seat": 0,
		"teleported": false,
	}]).get(0, {})
	eq(bool(ambush_plan.get("attack", false)), false, "Ambush miss does not slash")
	eq(bool(ambush_plan.get("whiff", false)), true, "Ambush miss is a whiff on the cast cell")
	var ambush_hit_plan: Dictionary = MOTION.chrome_plans([{
		"type": "hit",
		"spell": SpellKits.AMBUSH,
		"seat": 0,
		"teleported": true,
	}]).get(0, {})
	eq(bool(ambush_hit_plan.get("attack", false)), true, "Ambush hit still slashes after the snap")
	eq(is_equal_approx(float(ambush_hit_plan.get("reach", 0.0)), MOTION.AMBUSH_LUNGE_PX), true, "Ambush contact keeps the local reach")
	var beats: Array = MOTION.ambush_beats({
		"type": "hit",
		"spell": "ambush",
		"teleported": true,
	})
	eq(_beat_names(beats), ["snap", "face", "slash", "damage"], "Ambush hit snaps, faces, slashes, then resolves damage")
	eq(float(beats[1].get("sec", 0.0)), MOTION.AMBUSH_ARRIVE_HOLD_SEC, "the face beat stands on the back tile before the slash")
	var miss_beats: Array = MOTION.ambush_beats({
		"type": "miss",
		"spell": "ambush",
		"teleported": false,
	})
	eq(_beat_names(miss_beats), ["whiff"], "Ambush miss is only a whiff")
	eq(is_equal_approx(MOTION.ambush_contact_sec(), MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC), true, "facing damage waits until the slash connects")
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
	var adv: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(5, 7), "seat": 1})
	eq(bool(adv.get("ok", false)), true, "Advance still resolves")
	eq(str(_first_type(adv.get("events", []), "advance").get("type", "")), "advance", "Advance emits a teleport event")
	eq(CombatHUD.should_play_walk_hops(adv.get("events", [])), false, "Advance does not hop")
	var adv_plans: Dictionary = MOTION.chrome_plans(adv.get("events", []))
	eq(adv_plans.is_empty(), true, "Advance does not lunge or wind up")
	eq(_sim.snapshot()["units"][1]["pos"], Vector2i(5, 7), "Advance still snaps two cardinal tiles")


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
	eq(sprite.position.y, -MOTION.hop_crest_px("kestrel"), "pawn applies the class hop on the sprite")
	eq(sprite.scale, Vector2(0.5, 0.5), "step bounce does not squash or stretch")
	var chrome := pawn.get_node("Chrome") as Node2D
	eq(chrome.get_parent(), pawn, "name chrome stays on the pawn during a bounce")
	eq(chrome.position, Vector2.ZERO, "the hop does not lift name or aim chrome")
	var foot := pawn.get_node_or_null("Foot") as Node2D
	if foot != null:
		eq(foot.position, Vector2.ZERO, "the hop does not lift the ground mark")
	eq(pawn.name_label_origin().y < Pawn.HEAD_HP_Y, true, "the name stays above the HP bar during a hop")
	pawn._sample_hop(1.0)
	eq(sprite.position, Vector2.ZERO, "hop sample ends on the origin")
	var hold_t := (MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC + MOTION.impact_hold_sec() * 0.5) / MOTION.attack_sec()
	pawn._sample_attack(hold_t, Vector2(32, 0))
	var hand := pawn.get_node_or_null("Gesture") as Node2D
	truthy(hand != null and hand.visible, "a lunge shows a hand reach")
	if hand != null:
		eq(hand.position.length() > 12.0, true, "the hand reaches off the chest")
	pawn._sample_attack(0.0, Vector2(32, 0))
	if hand != null:
		eq(hand.visible, false, "the hand hides when the lunge is at rest")
	pawn.plant_sprite()
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
	eq(dur > 0.0 and dur <= MOTION.ACTION_LOCK_MAX, true, "cast wind-up reports a short duration")
	eq(pawn.motion_playing(), true, "cast wind-up owns the sprite")
	var anti_t := (MOTION.ANTICIPATION_SEC * 0.9) / MOTION.cast_sec()
	pawn._sample_cast(anti_t)
	eq((pawn.get_node("Sprite") as Sprite2D).scale.y < 0.5, true, "cast anticipation squashes before the rise")
	var rise_t := (MOTION.ANTICIPATION_SEC + MOTION.CAST_RISE_SEC * 0.85) / MOTION.cast_sec()
	pawn._sample_cast(rise_t)
	var risen: float = (pawn.get_node("Sprite") as Sprite2D).position.y
	eq(risen < -0.5, true, "cast wind-up lifts the sprite")
	pawn.settle_motion()
	eq(pawn.motion_playing(), false, "settle releases the sprite")
	eq((pawn.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "settle plants the feet")
	eq((pawn.get_node("Sprite") as Sprite2D).scale, Vector2(0.5, 0.5), "settle restores scale")
	eq((pawn.get_node("Sprite") as Sprite2D).rotation, 0.0, "settle clears rotation")
	await process_frame
	# Mender now has a walk sheet. This hop is the no-strip fallback.
	pawn.bind_motion_frames(SpriteFrames.new())
	pawn.play_step_hop()
	await create_timer(Pawn.WALK_HOP_SEC * 0.45).timeout
	var hopped: float = (pawn.get_node("Sprite") as Sprite2D).position.y
	eq(hopped < -1.0 and hopped > -MOTION.WALK_BOUNCE_PX - 0.5, true, "a live step bounce stays inside 2-4px")
	eq((pawn.get_node("Sprite") as Sprite2D).scale != Vector2(0.5, 0.5), true, "a class without a walk strip squashes or stretches")
	await create_timer(Pawn.WALK_HOP_SEC * 0.7).timeout
	eq((pawn.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "a live step bounce returns to the tile center")
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
	var down := _visible_strip(victim)
	truthy(down != null, "kestrel death holds the down strip")
	if down != null:
		eq(String(down.animation), "death_w", "kestrel death plays death_w")
		var last := down.sprite_frames.get_frame_count(down.animation) - 1
		eq(down.frame, last, "death holds the last frame")
		eq(is_equal_approx(down.speed_scale, 0.0), true, "the down pose does not keep playing")
		eq((victim.get_node("Sprite") as Sprite2D).visible, false, "the static sprite steps aside for the down pose")
	eq(victim.position, Vector2(80, 40), "the pawn node never leaves its tile")
	pawn.free()
	victim.free()


func _test_view_wiring() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	eq(view.contains("randi"), false, "board_view still does not roll")
	eq(view.split("_present_resolve(").size() >= 3, true, "hot-seat and online share resolve presentation")
	truthy(view.contains("_arm_view_motions"), "resolve arms view motions")
	eq(view.contains("play_step_hop"), false, "the board does not hop each cell")
	truthy(view.contains("Pawn.WALK_TILE_SEC"), "the tile slide uses the pawn tile constant")
	truthy(view.contains("TRANS_LINEAR"), "the step clock stays linear")
	eq(view.contains("TRANS_QUAD"), false, "the path slide is not a hop ease")
	eq(view.contains("STEP_PAUSE"), false, "the path has no pause between cells")
	eq(view.contains("STEP_SEC"), false, "the board does not keep a second hop duration")
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	truthy(pawn_src.contains("const WALK_TILE_SEC := 0.30"), "tile travel is 0.30s on the pawn")
	truthy(pawn_src.contains("tactical_cell"), "the tactical cell stays separate from the visual foot")
	truthy(pawn_src.contains("class FootMark"), "the contact shadow is its own foot node")
	truthy(pawn_src.contains("WALK_TILE_SEC)"), "the step bounce reads WALK_TILE_SEC")
	truthy(pawn_src.contains("walk_strip_speed_scale"), "walk playback exposes authored speed_scale")
	truthy(pawn_src.contains("has_walk_strip"), "pawn knows when the facing has a walk strip")
	truthy(pawn_src.contains("has_attack_strip"), "pawn knows when the facing has an attack strip")
	truthy(pawn_src.contains("begin_path_walk"), "a path can hold the walk loop")
	truthy(view.contains("arm_driven_walk"), "the board starts the driven walk once")
	truthy(pawn_src.contains("func arm_driven_walk"), "a path walk can be driven per tile")
	truthy(pawn_src.contains("sync_walk_plant"), "each tile can seek the walk plant")
	truthy(view.contains("end_path_walk"), "the board stops the walk loop at the end")
	eq(view.contains("flat_walk := pawn.play_step_hop()"), false, "the board does not choose a hop per cell")
	eq(view.contains("finish_step"), false, "the path does not plant the bounce on every cell")
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
	eq(MOTION.ATTACK_LUNGE_PX >= 16.0 and MOTION.ATTACK_LUNGE_PX <= 20.0, true, "the lunge constant reaches the tile edge")
	truthy(view.contains("chrome_plans"), "the board plays the shared hit and miss plans")
	truthy(view.contains("ShadeMarkers"), "Shade markers are not Units children")
	eq(view.contains("$Units.add_child(marker)"), false, "pawn rebuild cannot free Shade markers")
	eq(MOTION.caster_motion(SpellKits.AMBUSH), "attack", "Ambush contact stays a slash after the snap")
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
	truthy(anim_src.contains("for step in path"), "the path still visits each cell")
	truthy(anim_src.contains("step_travel"), "the path strides from plant to plant")
	eq(anim_src.contains("tween_property"), false, "the path is not a linear position slide")
	eq(anim_src.contains("play_step_hop"), false, "a cell does not play its own hop")
	truthy(anim_src.contains("arm_driven_walk"), "the walk loop starts once for the path")
	truthy(anim_src.contains("sync_walk_plant"), "the stride seeks the plant frame")
	truthy(anim_src.contains("walk_segment_facing"), "each segment faces the way the foot will travel")
	truthy(anim_src.contains("begin_segment_walk"), "a step does not translate until walk_+facing is showing")
	truthy(pawn_src.contains("func begin_segment_walk"), "the pawn can refuse a step that would slide the idle sprite")
	truthy(pawn_src.contains("func body_is_segment_walk"), "the drawn body is walk_+facing or the step is refused")
	var snap_at := anim_src.find("_snap_walk_facing")
	var sample_at := anim_src.find("_sample_walk_step")
	eq(snap_at >= 0 and sample_at > snap_at, true, "each segment faces before the foot moves")
	truthy(pawn_src.contains("walk_cycle_frame"), "a driven step samples the walk cycle")
	truthy(motion_src.contains("func walk_cycle_frame"), "the walk cycle frame is a pure function")
	var arm_at := anim_src.find("_arm_path_walk")
	var settle_at := anim_src.find("STEP_SETTLE_SEC")
	var anti_call := anim_src.find("_sample_step_anticipation")
	eq(arm_at >= 0 and anti_call > arm_at, true, "the walk strip is up before the weight shift")
	eq(anti_call >= 0 and settle_at > anti_call, true, "the weight shift uses the settle duration")
	eq(anti_call >= 0 and sample_at > anti_call, true, "the weight shift runs before the tile tween")
	truthy(anim_src.contains("dust_on_plant"), "dust is chosen per plant, not on every tile")
	truthy(anim_src.contains("anticipate_segment"), "only the first tile and direction changes settle")
	truthy(anim_src.contains("is_about_face"), "a 180 is planted before the next tile")
	truthy(anim_src.contains("_bridge_straight_tile"), "straight tiles bridge without an extra settle")
	truthy(anim_src.contains("STOP_IDLE_SEC"), "path end holds a readable idle before the face pad")
	eq(anim_src.contains("facing_turn("), false, "the walk does not spin through a side facing")
	truthy(anim_src.contains("origin"), "the hop starts on the departure tile, not the snapped dest")
	truthy(pawn_src.contains("WalkStrip"), "a walk strip node can drive the hop")
	truthy(pawn_src.contains("walk_e"), "lettered walk_e is the export_2x clip name")
	truthy(pawn_src.contains("walk_se"), "a drawn-master walk_se still resolves")
	truthy(pawn_src.contains("attack_ne"), "a drawn-master attack_ne still resolves")
	truthy(pawn_src.contains("strip_speed_scale"), "attack and cast strips still fit their motion window")


func _test_shade_markers_survive_rebuild() -> void:
	var live := load("res://tests/shade_marker_live.gd")
	truthy(live.has_method("run"), "shade live script parses")
	if not live.has_method("run"):
		return
	await live.run(self)


func _test_ambush_present_race() -> void:
	var live := load("res://tests/ambush_present_race.gd")
	truthy(live.has_method("run"), "ambush present race script parses")
	if not live.has_method("run"):
		return
	await live.run(self)


func _beat_names(beats: Array) -> Array:
	var names: Array = []
	for row in beats:
		names.append(str((row as Dictionary).get("beat", "")))
	return names


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
	_add_anim(frames, anim, count, fps)
	return frames


func _add_anim(frames: SpriteFrames, anim: String, count: int, fps: float) -> void:
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	var tex := _solid_tex()
	for _i in count:
		frames.add_frame(anim, tex)


func _test_batch1c_hot_swap() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	pawn.apply_snapshot(_unit("kestrel", "E", 0), 0)
	var frames := SpriteFrames.new()
	_add_anim(frames, "attack_e", 6, 12.0)
	_add_anim(frames, "cast_mark_e", 6, 12.0)
	_add_anim(frames, "cast_e", 6, 10.0)
	pawn.bind_motion_frames(frames)
	pawn.play_view_plan({"cast": true, "strip": "cast_mark", "aim": Vector2(32, 0)})
	await process_frame
	var strip := _visible_strip(pawn)
	truthy(strip != null, "cast_mark hot-swap shows a strip")
	if strip != null:
		eq(String(strip.animation), "cast_mark_e", "Mark Shot prefers cast_mark over attack")
	pawn.settle_motion()
	pawn.play_view_plan({"cast": true, "strip": "cast", "aim": Vector2(32, 0)})
	await process_frame
	strip = _visible_strip(pawn)
	truthy(strip != null, "cast hot-swap shows a strip")
	if strip != null:
		eq(String(strip.animation), "cast_e", "Detonate prefers cast over attack")
	pawn.free()


func _test_strip_fallback() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	var stand_in := AnimatedSprite2D.new()
	stand_in.name = "Sprite"
	stand_in.sprite_frames = null
	pawn.add_child(stand_in)
	# Unbind the shipped Mender walk so this still proves the empty-frame hop.
	pawn.apply_snapshot(_unit("mender", "E", 0), 0)
	pawn.bind_motion_frames(SpriteFrames.new())
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
	walk.sprite_frames = _strip_frames("walk_se", 6, 12.0)
	_add_anim(walk.sprite_frames, "walk_ne", 6, 12.0)
	pawn.add_child(walk)
	eq(pawn.has_walk_strip(), true, "synthetic SE frames count as a walk strip")
	eq(pawn.has_attack_strip(), false, "a walk clip is not an attack strip")
	pawn.begin_path_walk()
	pawn.play_step_hop()
	await process_frame
	eq(walk.visible, true, "SE walk frames play for the path")
	eq(String(walk.animation), "walk_se", "east facing plays the SE walk clip")
	eq(is_equal_approx(walk.speed_scale, Pawn.walk_strip_speed_scale()), true, "the walk loop matches one cycle per tile")
	var squeezed := Pawn.strip_speed_scale(6, 12.0, Pawn.WALK_HOP_SEC)
	eq(is_equal_approx(walk.speed_scale, squeezed), true, "one authored cycle is fit to the tile")
	eq(walk.sprite_frames.get_animation_loop("walk_se"), true, "the walk clip loops")
	eq(sprite.visible, false, "the static sprite steps aside while the strip plays")
	eq(_walk_bounce_ok(sprite.position.y), true, "a walk strip hops inside 2-4px")
	eq(sprite.scale, Vector2(0.5, 0.5), "a walk strip does not squash or stretch")
	eq((pawn.get_node("Chrome") as Node2D).position, Vector2.ZERO, "the hop does not lift name chrome")
	await create_timer(MOTION.WALK_STEP_SEC * 0.5).timeout
	eq(sprite.position.y < -1.5, true, "the path bounce crests a few pixels")
	eq(_walk_bounce_ok(sprite.position.y), true, "the path crest stays inside 2-4px")
	eq(is_equal_approx(walk.position.y, sprite.position.y), true, "the strip root takes the same bounce")
	eq(walk.offset, Vector2(0, -72), "the strip uses the shipped foot pivot")
	eq(walk.flip_h, false, "walk playback does not mirror")
	walk.frame = 4
	pawn.sync_walk_plant()
	eq(walk.frame, 0, "a tile seeks the authored walk plant")
	eq(is_equal_approx(walk.frame_progress, 0.0), true, "the plant starts at the first frame")
	walk.frame = 3
	pawn.finish_step()
	eq(walk.visible, true, "finish_step keeps the walk loop during a path")
	eq(walk.frame, 3, "finish_step does not restart the walk cycle")
	pawn.play_step_hop()
	eq(walk.frame, 3, "the next tile continues the walk loop")
	eq(_walk_bounce_ok(sprite.position.y), true, "the continued walk stays a short hop")
	pawn.set_facing("N")
	pawn.play_step_hop()
	eq(String(walk.animation), "walk_ne", "a new direction snaps the walk clip")
	eq(_walk_bounce_ok(sprite.position.y), true, "the snapped walk stays a short hop")
	pawn.end_path_walk()
	eq(sprite.visible, false, "path end keeps the walk identity")
	eq(walk.visible, true, "path end plants walk frame 0")
	eq(walk.frame, 0, "path end is the plant frame, not a passing frame")
	eq(sprite.texture != null, true, "the facing texture is still on the sprite")
	eq(sprite.position, Vector2.ZERO, "path end plants the feet")
	pawn.set_facing("E")
	pawn.play_step_hop()
	await process_frame
	eq(walk.visible, true, "a lone step still plays the walk strip")
	eq(_walk_bounce_ok(sprite.position.y), true, "a lone walk step hops inside 2-4px")
	eq(sprite.scale, Vector2(0.5, 0.5), "a lone walk step does not stretch")
	await create_timer(Pawn.WALK_HOP_SEC + 0.05).timeout
	eq(sprite.visible, false, "a lone walk step returns to the walk plant")
	eq(walk.visible, true, "a lone walk step keeps the walk sheet")
	eq(walk.frame, 0, "a lone walk step plants frame 0")
	eq(sprite.position, Vector2.ZERO, "a lone walk step plants the feet")
	pawn.set_facing("W")
	pawn.play_step_hop()
	await process_frame
	eq(walk.visible, false, "a facing with no frames does not play the strip")
	eq(sprite.visible, true, "a facing with no frames keeps the static sprite")
	await create_timer(Pawn.WALK_HOP_SEC * 0.45).timeout
	eq(_step_bob_ok(sprite.position.y), true, "missing walk strip still bobs, not a 36px hop")
	eq(sprite.scale != Vector2(0.5, 0.5), true, "missing walk strip squashes or stretches for weight")
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
	eq(attack.sprite_frames.get_animation_loop("attack_ne"), false, "the attack strip plays one-shot")
	eq(sprite.visible, false, "the static sprite steps aside during the attack strip")
	await create_timer(0.12).timeout
	eq(sprite.position.length() > 2.0, true, "the lunge still moves the body while the strip plays")
	pawn.settle_motion()
	eq(attack.visible, false, "settle hides the attack strip")
	if pawn.has_walk_strip():
		var rested := _visible_strip(pawn)
		truthy(rested != null and String(rested.animation).begins_with("walk"), "settle plants the walk identity after the lunge")
		eq(sprite.visible, false, "settle does not flash the static turnaround after the lunge")
		eq(rested.frame, 0, "settle plants walk frame 0 after the lunge")
	else:
		eq(sprite.visible, true, "settle restores the static sprite after the lunge")
	eq(sprite.position, Vector2.ZERO, "settle plants the feet after a strip lunge")
	var miss_dur := pawn.play_view_plan({"attack": true, "aim": Vector2(20, -10)})
	await process_frame
	eq(is_equal_approx(miss_dur, dur), true, "a miss lunge lasts as long as a hit lunge")
	eq(attack.visible, true, "a miss plays the same attack strip as a hit")
	pawn.settle_motion()
	pawn.facing = "N"
	var cast_strip := AnimatedSprite2D.new()
	cast_strip.name = "CastStrip"
	cast_strip.sprite_frames = _strip_frames("cast_ne", 4, 12.0)
	pawn.add_child(cast_strip)
	eq(pawn.has_cast_strip(), true, "synthetic NE cast frames resolve")
	var cast_dur := pawn.play_view_plan({"cast": true})
	var rise_t := (MOTION.ANTICIPATION_SEC + MOTION.CAST_RISE_SEC * 0.85) / MOTION.cast_sec()
	pawn._sample_cast(rise_t)
	eq(cast_dur > 0.0 and cast_dur <= MOTION.ACTION_LOCK_MAX, true, "cast with a strip still reports the wind-up")
	eq(cast_strip.visible, true, "cast strip plays during the rise")
	eq(String(cast_strip.animation), "cast_ne", "north cast plays the NE clip")
	var lifted: float = minf(sprite.position.y, cast_strip.position.y)
	eq(lifted < -0.5, true, "cast rise still lifts the body")
	var cast_hold_t := (MOTION.ANTICIPATION_SEC + MOTION.CAST_RISE_SEC + MOTION.impact_hold_sec() * 0.5) / MOTION.cast_sec()
	pawn._sample_cast(cast_hold_t)
	eq(cast_strip.frame, cast_strip.sprite_frames.get_frame_count(cast_strip.animation) - 1, "cast holds the last pose")
	eq(is_equal_approx(cast_strip.speed_scale, 0.0), true, "cast stretches the impact pose")
	eq(cast_dur <= MOTION.ACTION_LOCK_MAX, true, "cast impact hold stays inside the lock")
	pawn.settle_motion()
	eq(cast_strip.visible, false, "settle hides the cast strip")
	if pawn.has_walk_strip():
		var cast_rest := _visible_strip(pawn)
		truthy(cast_rest != null and String(cast_rest.animation).begins_with("walk"), "settle plants the walk identity after cast")
		eq(sprite.visible, false, "settle does not flash the static turnaround after cast")
	else:
		eq(sprite.visible, true, "settle restores the static sprite after cast")
	pawn.free()


func _test_strip_library_missing_and_slice() -> void:
	var paths: Array[String] = StripLibrary.batch1_png_paths()
	eq(paths.size(), 16, "batch 1 is two classes, walk and attack, four letters")
	eq(StripLibrary.export_png_path("kestrel", "walk", "e"), "res://art/export_2x/characters/kestrel/anims/kestrel_walk_e.png", "kestrel east walk is the export_2x path")
	eq(StripLibrary.export_png_path("ironjaw", "attack", "w"), "res://art/export_2x/characters/ironjaw/anims/ironjaw_attack_w.png", "ironjaw west attack is the export_2x path")
	eq(StripLibrary.export_frames_path("kestrel"), "res://art/export_2x/characters/kestrel/kestrel_frames.tres", "frames tres sits beside the class folder")
	eq(paths.has(StripLibrary.grok_png_path("kestrel", "walk", "se")), false, "batch-1 list is export_2x, not grok masters")
	for path in paths:
		eq(FileAccess.file_exists(path), true, "batch-1 png is in the repo: %s" % path)
		eq(ResourceLoader.exists(path), true, "APK ResourceLoader path exists: %s" % path)
		var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		truthy(loaded is Texture2D, "batch-1 png loads: %s" % path)
		eq((loaded as Texture2D).get_width(), 864, "strip width is 6 cells: %s" % path)
		eq((loaded as Texture2D).get_height(), 160, "strip height is one cell: %s" % path)
		var import_text := FileAccess.get_file_as_string(path + ".import")
		truthy(import_text.contains("source_file=\"%s\"" % path), "import source_file matches export_2x: %s" % path)
	for cls in ["kestrel", "ironjaw"]:
		var bank := StripLibrary.try_load(StripLibrary.export_frames_path(cls)) as SpriteFrames
		truthy(bank != null, "%s frames tres loads" % cls)
		for face in ["e", "s", "n", "w"]:
			var walk_name := "walk_%s" % face
			var attack_name := "attack_%s" % face
			eq(bank.get_frame_count(walk_name), 6, "%s %s has 6 frames" % [cls, walk_name])
			eq(bank.get_animation_loop(walk_name), true, "%s %s loops" % [cls, walk_name])
			eq(is_equal_approx(bank.get_animation_speed(walk_name), 12.0), true, "%s %s is 12 fps" % [cls, walk_name])
			eq(bank.get_frame_count(attack_name), 6, "%s %s has 6 frames" % [cls, attack_name])
			eq(bank.get_animation_loop(attack_name), false, "%s %s is one-shot" % [cls, attack_name])
			eq(is_equal_approx(bank.get_animation_speed(attack_name), 12.0), true, "%s %s is 12 fps" % [cls, attack_name])
			var impact := bank.get_frame_texture(attack_name, StripLibrary.ATTACK_IMPACT_FRAME) as AtlasTexture
			eq(is_equal_approx(impact.region.position.x, 432.0), true, "%s %s impact is cell 3" % [cls, attack_name])
	var kestrel_bank := StripLibrary.frames_for("kestrel")
	var ironjaw_bank := StripLibrary.frames_for("ironjaw")
	truthy(kestrel_bank != null, "kestrel strip bank loads from export_2x")
	truthy(ironjaw_bank != null, "ironjaw strip bank loads from export_2x")
	eq(kestrel_bank, StripLibrary.frames_for("kestrel"), "kestrel bank is cached")
	eq(kestrel_bank.get_animation_loop("walk_e"), true, "loaded kestrel walk loops")
	var packed := StripLibrary.image_from_walk_bytes("kestrel", "e")
	truthy(packed != null, "kestrel east walk bytes are packed for the device")
	var packed_cells := StripLibrary.textures_from_image(packed, 6)
	eq(packed_cells.size(), 6, "device walk bytes slice to 6 cells")
	eq(packed_cells[0] is ImageTexture, true, "a device walk cell is its own image")
	eq(packed_cells[0] is AtlasTexture, false, "a device walk cell is not a shared atlas region")
	eq(packed_cells[0].get_image().get_data() == packed_cells[2].get_image().get_data(), false, "device walk cells are not one repeated idle")
	eq(kestrel_bank.get_frame_texture("walk_e", 0).get_image().get_data(), packed_cells[0].get_image().get_data(), "playback frame 0 is the packed cell")
	for cls in ["kestrel", "ironjaw", "gloam", "mender", "bastion"]:
		for face in ["e", "s", "n", "w"]:
			eq(FileAccess.file_exists(StripLibrary.walk_bytes_path(cls, face)), true, "%s %s walk bytes are in the export pack" % [cls, face])
	eq(ironjaw_bank.get_animation_loop("attack_w"), false, "loaded ironjaw attack is one-shot")
	for cls in ["kestrel", "ironjaw"]:
		var tres_path := StripLibrary.export_frames_path(cls)
		eq(ResourceLoader.exists(tres_path), true, "APK frames tres exists: %s" % tres_path)
		var authored := ResourceLoader.load(tres_path, "", ResourceLoader.CACHE_MODE_REUSE) as SpriteFrames
		var played := StripLibrary.frames_for(cls)
		truthy(authored != null and played != null, "%s playback bank and tres both load" % cls)
		var kinds: Array[String] = ["walk", "attack", "hit", "death"]
		if cls == "kestrel":
			kinds.append("cast")
			kinds.append("cast_mark")
		for kind in kinds:
			for face in ["e", "s", "n", "w"]:
				var anim_name := "%s_%s" % [kind, face]
				eq(played.get_frame_count(anim_name) >= 2, true, "%s %s playback has at least two frames" % [cls, anim_name])
				var authored_tex := authored.get_frame_texture(anim_name, 0)
				var played_tex := played.get_frame_texture(anim_name, 0)
				truthy(played_tex != null, "%s %s frame 0 texture is non-null" % [cls, anim_name])
				truthy(played_tex is ImageTexture, "%s %s is baked off the compressed atlas" % [cls, anim_name])
				eq(played_tex.get_width(), 144, "%s %s cell is 144 wide, not the whole strip" % [cls, anim_name])
				eq(played_tex.get_height(), 160, "%s %s cell is 160 tall" % [cls, anim_name])
				var authored_image := authored_tex.get_image()
				var played_image := played_tex.get_image()
				truthy(authored_image != null and played_image != null, "%s %s cell images load" % [cls, anim_name])
				eq(authored_image.get_data(), played_image.get_data(), "%s %s frame 0 matches the tres cell" % [cls, anim_name])
				var later := played.get_frame_texture(anim_name, 3).get_image()
				eq(played_image.get_data() == later.get_data(), false, "%s %s frames are not one repeated cell" % [cls, anim_name])
				var regions: Array = []
				for i in played.get_frame_count(anim_name):
					var cell := played.get_frame_texture(anim_name, i)
					truthy(cell != null, "%s %s frame %d texture is non-null" % [cls, anim_name, i])
					eq(regions.has(cell), false, "%s %s frame %d is its own texture" % [cls, anim_name, i])
					regions.append(cell)
	var gloam_bank := StripLibrary.frames_for("gloam")
	truthy(gloam_bank != null, "gloam strip bank loads from export_2x")
	for cls in ["kestrel", "ironjaw", "gloam"]:
		var walk_bank := StripLibrary.try_load(StripLibrary.export_frames_path(cls)) as SpriteFrames
		for face in ["e", "s", "n", "w"]:
			var walk_name := "walk_%s" % face
			var drop := StripLibrary.export_png_path(cls, "walk", face)
			var atlas := walk_bank.get_frame_texture(walk_name, 0) as AtlasTexture
			truthy(atlas != null and atlas.atlas != null, "%s %s frame 0 is an atlas slice" % [cls, walk_name])
			eq(atlas.atlas.resource_path, drop, "%s %s plays the drop PNG" % [cls, walk_name])
			eq(atlas.region.size, Vector2(144, 160), "%s %s cell is 144×160" % [cls, walk_name])
			eq(walk_bank.get_frame_count(walk_name), 6, "%s %s is six frames" % [cls, walk_name])
	_assert_locked_walk_png(gloam_bank, "gloam")
	var ironjaw_walk := StripLibrary.frames_for("ironjaw")
	eq(gloam_bank.get_frame_texture("walk_e", 0).get_image().get_data() == ironjaw_walk.get_frame_texture("walk_e", 0).get_image().get_data(), false, "gloam walk_e is not the ironjaw sheet")
	eq(gloam_bank.get_frame_texture("walk_n", 0).get_image().get_data() == gloam_bank.get_frame_texture("walk_e", 0).get_image().get_data(), false, "gloam north walk is not the east sheet")
	eq(gloam_bank.get_frame_count("walk_e"), 6, "gloam walk_e has 6 frames")
	eq(gloam_bank.get_animation_loop("walk_e"), true, "gloam walk loops")
	eq(is_equal_approx(gloam_bank.get_animation_speed("walk_e"), 12.0), true, "gloam walk is 12 fps")
	eq(gloam_bank.get_frame_count("attack_e"), 5, "gloam attack_e has 5 frames")
	eq(gloam_bank.get_animation_loop("attack_e"), false, "gloam attack is one-shot")
	eq(gloam_bank.get_frame_count("cast_n"), 4, "gloam cast_n has 4 frames")
	eq(is_equal_approx(gloam_bank.get_animation_speed("cast_n"), 10.0), true, "gloam cast is 10 fps")
	eq(gloam_bank.get_frame_count("hit_s"), 4, "gloam hit_s has 4 frames")
	eq(gloam_bank.get_frame_count("death_w"), 6, "gloam death_w has 6 frames")
	eq(gloam_bank.get_animation_loop("death_w"), false, "gloam death does not loop")
	for cls in ["mender", "bastion"]:
		var walk_only := StripLibrary.frames_for(cls)
		truthy(walk_only != null, "%s walk bank loads from the drop PNGs" % cls)
		for face in ["e", "s", "n", "w"]:
			var walk_name := "walk_%s" % face
			eq(walk_only.has_animation(walk_name), true, "%s %s is on the walk bank" % [cls, walk_name])
			eq(walk_only.get_frame_count(walk_name), 6, "%s %s is six frames" % [cls, walk_name])
			eq(walk_only.get_animation_loop(walk_name), true, "%s %s loops" % [cls, walk_name])
			eq(is_equal_approx(walk_only.get_animation_speed(walk_name), 12.0), true, "%s %s is 12 fps" % [cls, walk_name])
			var cell_tex := walk_only.get_frame_texture(walk_name, 0)
			truthy(cell_tex != null, "%s %s frame 0 texture is non-null" % [cls, walk_name])
			eq(cell_tex.get_width(), 144, "%s %s cell is 144 wide" % [cls, walk_name])
			eq(cell_tex.get_height(), 160, "%s %s cell is 160 tall" % [cls, walk_name])
		eq(walk_only.has_animation("attack_e"), false, "%s has no attack strip" % cls)
		eq(walk_only.has_animation("cast_e"), false, "%s has no cast strip" % cls)
		eq(walk_only.has_animation("hit_e"), false, "%s has no hit strip" % cls)
		eq(walk_only.has_animation("death_e"), false, "%s has no death strip" % cls)
	var batch1c: Array[String] = StripLibrary.batch1c_png_paths()
	eq(batch1c.size(), 44, "batch-1c adds cast/hit/death and the gloam set")
	for path in batch1c:
		eq(FileAccess.file_exists(path), true, "batch-1c png is in the repo: %s" % path)
		eq(ResourceLoader.exists(path), true, "APK ResourceLoader path exists: %s" % path)
		var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		truthy(loaded is Texture2D, "batch-1c png loads: %s" % path)
		eq((loaded as Texture2D).get_height(), 160, "batch-1c strip height is one cell: %s" % path)
		var import_text := FileAccess.get_file_as_string(path + ".import")
		truthy(import_text.contains("source_file=\"%s\"" % path), "import source_file matches export_2x: %s" % path)
		truthy(import_text.contains("compress/mode=0"), "batch-1c import is lossless: %s" % path)
	eq(StripLibrary.try_load(StripLibrary.grok_png_path("kestrel", "walk", "se")) == null, true, "missing grok master returns null")
	eq(StripLibrary.letter_for_sheet("se"), "e", "SE maps to e")
	eq(StripLibrary.letter_for_sheet("sw"), "s", "SW maps to s")
	eq(StripLibrary.letter_for_sheet("ne"), "n", "NE maps to n")
	eq(StripLibrary.letter_for_sheet("nw"), "w", "NW maps to w")
	eq(StripLibrary.ATTACK_IMPACT_FRAME, 3, "attack impact is frame 3")
	eq(StripLibrary.impact_frame("kestrel", "cast_mark"), 3, "cast_mark impact is frame 3")
	eq(StripLibrary.impact_frame("kestrel", "cast"), 3, "kestrel cast impact is frame 3")
	eq(StripLibrary.impact_frame("kestrel", "hit"), 0, "hit impact is frame 0")
	eq(StripLibrary.impact_frame("ironjaw", "death"), 4, "death collapse is frame 4")
	eq(StripLibrary.impact_frame("gloam", "attack"), 2, "gloam attack impact is frame 2")
	eq(StripLibrary.impact_frame("gloam", "cast"), 2, "gloam cast impact is frame 2")
	eq(is_equal_approx(StripLibrary.release_sec("kestrel", "cast_mark"), 0.25), true, "cast_mark releases at frame 3 / 12 fps")
	eq(is_equal_approx(StripLibrary.release_sec("kestrel", "cast"), 0.3), true, "kestrel cast releases at frame 3 / 10 fps")
	eq(is_equal_approx(StripLibrary.release_sec("gloam", "attack"), 2.0 / 12.0), true, "gloam attack releases at frame 2 / 12 fps")
	eq(is_equal_approx(StripLibrary.release_sec("ironjaw", "attack"), VfxBudget.MELEE_IMPACT_DELAY), true, "ironjaw impact delay matches the slam frame")
	eq(is_equal_approx(StripLibrary.kind_fps("cast"), 10.0), true, "cast strips are 10 fps")
	eq(is_equal_approx(StripLibrary.kind_fps("walk"), 12.0), true, "walk strips stay 12 fps")
	eq(StripLibrary.kind_frame_hint("gloam", "attack"), 5, "gloam attack is 5 frames")
	eq(StripLibrary.kind_frame_hint("kestrel", "hit"), 4, "hit strips are 4 frames")
	eq(StripLibrary.try_load("res://art/export_2x/characters/kestrel/anims/kestrel_walk_e_gen.png"), null, "gen_raw sheets are not loaded")
	var image := Image.create(48, 8, false, Image.FORMAT_RGBA8)
	for i in 6:
		image.fill_rect(Rect2i(i * 8, 0, 8, 8), Color(float(i) / 5.0, 0.4, 0.2, 1.0))
	var tex := ImageTexture.create_from_image(image)
	var frames := StripLibrary.frames_from_texture(tex, "walk", "se", 6, 12.0, true)
	eq(frames.get_frame_count("walk_e"), 6, "SE walk stores as walk_e")
	eq(frames.has_animation("walk_se"), false, "SE walk is not stored as walk_se")
	eq(frames.has_animation("walk_s"), false, "SE walk does not fill south")
	eq(is_equal_approx(frames.get_animation_speed("walk_e"), 12.0), true, "SE walk is authored at 12 fps")
	eq(frames.get_animation_loop("walk_e"), true, "SE walk loops")
	var cell := frames.get_frame_texture("walk_e", 2) as AtlasTexture
	eq(is_equal_approx(cell.region.position.x, 16.0), true, "frame 2 is the third cell of the strip")
	var south := StripLibrary.frames_from_texture(tex, "walk", "sw", 6, 12.0, true)
	eq(south.has_animation("walk_s"), true, "SW walk stores as walk_s")
	var attack := StripLibrary.frames_from_texture(tex, "attack", "ne", 6, 12.0, false)
	eq(attack.has_animation("attack_n"), true, "NE attack stores as attack_n")
	eq(attack.has_animation("attack_ne"), false, "NE attack is not stored as attack_ne")
	eq(attack.get_animation_loop("attack_n"), false, "attack sheets are one-shot")
	eq(attack.has_animation("attack_w"), false, "NE attack does not fill west")
	var shipped := Pawn.new()
	get_root().add_child(shipped)
	shipped.apply_snapshot(_unit("kestrel", "E", 0), 0)
	for face in ["E", "S", "N", "W"]:
		shipped.set_facing(face)
		eq(shipped.has_walk_strip(), true, "shipped kestrel %s has a walk strip" % face)
		eq(shipped.has_attack_strip(), true, "shipped kestrel %s has an attack strip" % face)
	shipped.set_facing("E")
	eq(shipped.has_cast_strip(), true, "kestrel cast strip is on disk")
	eq(str(shipped._strip_choice("cast_mark").get("anim", "")), "cast_mark_e", "kestrel east has cast_mark")
	eq(str(shipped._strip_choice("hit").get("anim", "")), "hit_e", "kestrel east has hit")
	eq(str(shipped._strip_choice("death").get("anim", "")), "death_e", "kestrel east has death")
	shipped.free()
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot(_unit("mender", "E", 0), 0)
	eq(pawn.has_walk_strip(), true, "mender east plays the dropped walk strip")
	eq(pawn.has_attack_strip(), false, "mender walk drop has no attack strip")
	eq(pawn.has_cast_strip(), false, "mender walk drop has no cast strip")
	pawn.bind_motion_frames(frames)
	eq(pawn.has_walk_strip(), true, "bound SE frames resolve for an east facing")
	eq(str(pawn._strip_choice("walk").get("anim", "")), "walk_e", "east plays walk_e")
	pawn.set_facing("S")
	eq(pawn.has_walk_strip(), false, "south does not use the SE sheet")
	pawn.set_facing("N")
	eq(pawn.has_walk_strip(), false, "north does not use the SE sheet")
	var both := SpriteFrames.new()
	_add_anim(both, "walk_e", 4, 12.0)
	_add_anim(both, "walk_se", 4, 12.0)
	pawn.bind_motion_frames(both)
	pawn.set_facing("E")
	eq(str(pawn._strip_choice("walk").get("anim", "")), "walk_e", "east prefers walk_e over walk_se")
	pawn.bind_motion_frames(south)
	pawn.set_facing("S")
	eq(pawn.has_walk_strip(), true, "SW frames resolve for a south facing")
	var readme := FileAccess.get_file_as_string("res://art/export_2x/characters/README.md")
	truthy(readme.contains("kestrel_walk_{e,s,n,w}.png"), "README lists the kestrel lettered walks")
	truthy(readme.contains("ironjaw_attack_{e,s,n,w}.png"), "README lists the ironjaw lettered attacks")
	truthy(readme.contains("kestrel_frames.tres"), "README lists the frames tres")
	truthy(readme.contains("kestrel_cast_mark_{e,s,n,w}.png"), "README lists Mark Shot strips")
	truthy(readme.contains("gloam_walk_{e,s,n,w}.png"), "README lists the gloam walks")
	truthy(readme.contains("proposal B"), "Gloam walk drop is proposal B")
	eq(StripLibrary.export_png_path("mender", "walk", "e"), "res://art/export_2x/characters/mender/anims/mender_walk_e.png", "mender east walk drops in the mender anims folder")
	truthy(readme.contains("proposal D2"), "Mender walk drop is proposal D2")
	truthy(readme.contains("more open hood"), "Mender D2 keeps the face visible")
	eq(StripLibrary.export_png_path("ironjaw", "walk", "e"), "res://art/export_2x/characters/ironjaw/anims/ironjaw_walk_e.png", "ironjaw east walk stays on the ironjaw anims path")
	truthy(readme.contains("Ironjaw A2"), "Ironjaw walk drop is A2")
	truthy(readme.contains("double-bit axes"), "Ironjaw A2 keeps the dual axes")
	eq(StripLibrary.export_png_path("bastion", "walk", "e"), "res://art/export_2x/characters/bastion/anims/bastion_walk_e.png", "bastion east walk drops in the bastion anims folder")
	truthy(readme.contains("proposal 2C"), "Bastion walk drop is proposal 2C")
	truthy(readme.contains("oversized tower shield"), "Bastion 2C keeps the tower shield")
	truthy(readme.contains("white-eyes"), "the white-eyes Gloam sheet is not the drop")
	truthy(readme.contains("gloam_frames.tres"), "README lists the gloam frames tres")
	truthy(readme.contains("art/grok_project/anims/"), "README keeps grok masters as fallback only")
	pawn.free()


func _test_driven_walk_cycle() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	pawn.apply_snapshot(_unit("kestrel", "E", 0), 0)
	var sprite := pawn.get_node("Sprite") as Sprite2D
	var foot := pawn.get_node("Foot") as Node2D
	pawn.position = Vector2(48, 16)
	MOTION.set_reduce_motion(true)
	eq(pawn.begin_segment_walk("N"), false, "reduced motion does not claim a walking body")
	MOTION.clear_reduce_motion()
	eq(pawn.begin_segment_walk("N"), true, "a north segment shows walk_n before the foot may move")
	eq(sprite.visible, false, "the idle sprite stays hidden for that segment")
	eq(pawn.body_is_segment_walk("N"), true, "the drawn body is walk_n")
	eq(pawn.body_is_segment_walk("E"), false, "an east check does not accept the north strip")
	sprite.visible = true
	eq(pawn.body_is_segment_walk("N"), false, "a visible idle sprite is not a walk segment")
	sprite.visible = false
	pawn.set_facing("E")
	pawn.arm_driven_walk()
	pawn.sync_walk_plant()
	var strip := _visible_strip(pawn)
	truthy(strip != null, "driven walk shows the facing strip")
	if strip == null:
		pawn.free()
		return
	eq(String(strip.animation), "walk_e", "driven walk plays walk_e for an east step")
	var count := strip.sprite_frames.get_frame_count("walk_e")
	eq(count >= 4, true, "the east walk strip has a real cycle")
	pawn.sample_driven_gait(0.0)
	var plant := strip.frame
	eq(plant, MOTION.walk_cycle_frame(0.0, count, 0), "the press shows the contact frame")
	eq(foot.position, Vector2.ZERO, "the ground mark starts on the diamond")
	# No process tick. A clock that never moves must still fail this.
	pawn.sample_driven_gait(0.5)
	eq(strip.frame == plant, false, "a driven stride leaves the idle frame")
	eq(strip.frame, MOTION.walk_cycle_frame(0.5, count, 0, pawn.walk_contact_frame()), "the stride shows that walk-cycle frame")
	var passing := strip.frame
	var stride_body := MOTION.hop_offset(0.5, MOTION.hop_crest_px("kestrel"))
	eq(strip.position, stride_body, "the hop is a sprite offset, not a foot lead")
	eq(stride_body.y <= -3.0 and stride_body.y >= -4.0 and stride_body.x == 0.0, true, "kestrel rises in the light crest band")
	eq(is_equal_approx(strip.scale.y, Pawn.sprite_scale_for("kestrel").y), true, "mid-hop does not squash the sprite")
	pawn.sample_driven_gait(0.9)
	eq(strip.position, Vector2.ZERO, "the plant hold puts the sprite back on the foot")
	eq(strip.scale.y < Pawn.sprite_scale_for("kestrel").y, true, "the plant squashes the sprite child")
	eq(is_equal_approx(strip.scale.x, Pawn.sprite_scale_for("kestrel").x), true, "the plant squash does not widen")
	eq(pawn.scale, Vector2.ONE, "the plant squash does not scale the pawn")
	eq(foot.position, Vector2.ZERO, "the plant squash leaves the foot on the diamond")
	eq(foot.position, Vector2.ZERO, "the ground mark stays on the floor while the body walks")
	eq((pawn.get_node("Chrome") as Node2D).position, Vector2.ZERO, "the hop does not lift name or aim chrome")
	eq(pawn.position, Vector2(48, 16), "the gait does not lift the foot off the cell")
	eq(strip.offset, Vector2(0, -72), "the strip pivot stays on the diamond")
	eq(is_equal_approx(strip.speed_scale, 0.0), true, "the step owns the cycle")
	var held := strip.frame
	await process_frame
	eq(strip.frame, held, "a paused clock cannot advance off the sampled frame")
	pawn.sample_driven_gait(1.0)
	eq(strip.frame == passing, false, "arrival does not freeze the passing frame")
	eq(strip.frame, MOTION.walk_cycle_frame(1.0, count, 0), "arrival holds the next contact")
	eq(strip.position, Vector2.ZERO, "arrival plants the body on the foot")
	var arrived := strip.frame
	pawn.sync_walk_plant()
	pawn.sample_driven_gait(0.0)
	eq(strip.frame, arrived, "the next segment starts on the contact the last one landed")
	eq(String(strip.animation), "walk_e", "the same facing keeps walk_e")
	pawn.set_facing("S")
	pawn.retarget_walk_strip()
	pawn.sync_walk_plant()
	strip = _visible_strip(pawn)
	truthy(strip != null, "a new segment still shows a walk strip")
	if strip != null:
		eq(String(strip.animation), "walk_s", "the south segment plays walk_s")
		var south_count := strip.sprite_frames.get_frame_count("walk_s")
		pawn.sample_driven_gait(0.5)
		eq(strip.frame == MOTION.walk_cycle_frame(0.0, south_count, 2), false, "the new facing still leaves the idle frame")
	pawn.set_facing("N")
	pawn.retarget_walk_strip()
	strip = _visible_strip(pawn)
	if strip != null:
		eq(String(strip.animation), "walk_n", "north plays walk_n")
	pawn.set_facing("W")
	pawn.retarget_walk_strip()
	strip = _visible_strip(pawn)
	if strip != null:
		eq(String(strip.animation), "walk_w", "west plays walk_w")
	pawn.end_path_walk()
	var planted := _visible_strip(pawn)
	truthy(planted != null, "path end shows the walk plant")
	eq(sprite.visible, false, "path end does not flash the static turnaround")
	eq(String(planted.animation), "walk_w", "path end stays on the west walk sheet")
	eq(planted.frame, 0, "path end plants walk frame 0, not a passing frame")
	eq(foot.position, Vector2.ZERO, "the ground mark is still on the diamond after the walk")
	pawn.free()


## The phone clip popped both fighters onto a foreign portrait for the
## stride, then popped back on arrival. The live submit path has to keep
## the facing walk sheet up the whole way and plant frame 0 at the end.
func _test_live_walk_keeps_sheet() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var board: Node = main.get_node("BoardView")
	truthy(bool(board.get("_booted")), "board booted before the walk identity check")
	var sim: Node = get_root().get_node("CombatSim")
	sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "gloam"],
		"positions": [Vector2i(2, 2), Vector2i(8, 8)],
		"kestrel_facing": "N",
	})
	board._rebuild_pawns()
	board._refresh()
	var gloam := board.pawns_by_seat[1] as Pawn
	var gloam_sprite := gloam.get_node("Sprite") as Sprite2D
	var gloam_idle := _visible_strip(gloam)
	truthy(gloam_idle != null, "Gloam combat idle is the walk sheet")
	if gloam_idle != null:
		eq(gloam_sprite.visible, false, "Gloam idle hides the static portrait")
		eq(String(gloam_idle.animation), "walk_%s" % gloam.facing.to_lower(), "Gloam idle uses the facing walk strip")
		eq(gloam_idle.frame, 0, "Gloam idle is walk frame 0")
		eq(gloam_idle.sprite_frames.get_frame_texture(gloam_idle.animation, 0) != Pawn.sprite_texture("gloam", gloam.facing), true, "Gloam plant is not the static portrait")
	var pawn := board.pawns_by_seat[0] as Pawn
	var sprite := pawn.get_node("Sprite") as Sprite2D
	var idle := _visible_strip(pawn)
	truthy(idle != null, "combat idle is the walk sheet before the first step")
	if idle == null:
		main.free()
		return
	eq(sprite.visible, false, "combat idle hides the static turnaround")
	eq(String(idle.animation), "walk_n", "north idle plays walk_n")
	eq(idle.frame, 0, "north idle is the walk plant")
	var foreign := Pawn.sprite_texture("kestrel", "N")
	eq(idle.sprite_frames.get_frame_texture("walk_n", 0) != foreign, true, "north plant is not the static portrait")
	var origin := pawn.position
	board._submit({"type": "move", "to": Vector2i(4, 3), "seat": 0})
	var left_origin_face := ""
	var left_origin_anim := ""
	var saw_east_stride := false
	var corner := Vector2(-1.0, -1.0)
	var faced_south_on_corner := false
	var saw_south_stride := false
	var static_during := false
	var foreign_during := false
	var max_jump := 0.0
	var prev := pawn.position
	var frames := 0
	while frames < 220:
		await process_frame
		frames += 1
		var shown := _visible_strip(pawn)
		if sprite.visible:
			static_during = true
		if shown == null:
			foreign_during = true
		else:
			var tex := shown.sprite_frames.get_frame_texture(shown.animation, shown.frame)
			var portrait := Pawn.sprite_texture("kestrel", pawn.facing)
			if tex == portrait:
				foreign_during = true
			if pawn.facing == "E" and shown.frame != 0 and pawn.position.distance_to(origin) > 4.0:
				saw_east_stride = true
			if pawn.facing == "S" and String(shown.animation) == "walk_s":
				if corner.x < 0.0:
					corner = pawn.position
				elif pawn.position.distance_to(corner) < 2.0:
					faced_south_on_corner = true
				elif shown.frame != 0:
					saw_south_stride = true
		if left_origin_face == "" and pawn.position.distance_to(origin) > 2.0:
			left_origin_face = pawn.facing
			var moving := _visible_strip(pawn)
			left_origin_anim = String(moving.animation) if moving != null else ""
		max_jump = maxf(max_jump, pawn.position.distance_to(prev))
		prev = pawn.position
		if not bool(board.get("_busy")) and frames > 8:
			break
	eq(static_during, false, "the static portrait stays hidden for the whole walk")
	eq(foreign_during, false, "the stride never shows the static portrait")
	eq(left_origin_face, "E", "the pawn faces east before the foot leaves the tile")
	eq(left_origin_anim, "walk_e", "the east step plays walk_e, not a sliding idle")
	eq(saw_east_stride, true, "the east step plays the walk cycle")
	eq(faced_south_on_corner, true, "the corner faces south before the foot slides")
	eq(saw_south_stride, true, "the south step plays the walk cycle")
	eq(max_jump < 24.0, true, "a frame does not teleport across a tile")
	eq(pawn.grid_position, Vector2i(4, 3), "the walk lands on the clicked tile")
	eq(pawn.facing, "S", "arrival keeps the last hop facing")
	var planted := _visible_strip(pawn)
	truthy(planted != null, "arrival shows the walk sheet")
	if planted != null:
		eq(String(planted.animation), "walk_s", "arrival stays on walk_s")
		eq(planted.frame, 0, "arrival plants walk frame 0")
		eq(sprite.visible, false, "arrival does not pop back to the static portrait")
	main.free()
	await process_frame


func _test_walk_idle_matches_strip() -> void:
	for class_id in ["kestrel", "ironjaw", "gloam", "mender", "bastion"]:
		var pawn := Pawn.new()
		get_root().add_child(pawn)
		await process_frame
		pawn.apply_snapshot(_unit(class_id, "E", 0), 0)
		await process_frame
		var sprite := pawn.get_node("Sprite") as Sprite2D
		var foreign := Pawn.sprite_texture(class_id, "E")
		var idle := _visible_strip(pawn)
		truthy(idle != null, "%s idle shows the walk sheet" % class_id)
		if idle == null:
			pawn.free()
			continue
		eq(sprite.visible, false, "%s idle hides the static turnaround" % class_id)
		eq(String(idle.animation), "walk_e", "%s idle is walk_e" % class_id)
		eq(idle.frame, 0, "%s idle is walk frame 0" % class_id)
		var plant := idle.sprite_frames.get_frame_texture("walk_e", 0)
		eq(plant != foreign, true, "%s plant is not the static turnaround texture" % class_id)
		eq(idle.sprite_frames.get_frame_texture(idle.animation, idle.frame), plant, "%s shows walk frame 0" % class_id)
		pawn.arm_driven_walk()
		eq(sprite.visible, false, "%s walk start does not flash the static turnaround" % class_id)
		var started := _visible_strip(pawn)
		truthy(started != null, "%s walk start keeps the sheet up" % class_id)
		if started != null:
			eq(String(started.animation), "walk_e", "%s walk start stays on walk_e" % class_id)
			eq(started.sprite_frames.get_frame_texture("walk_e", 0) != foreign, true, "%s walk start is not the static portrait" % class_id)
		await process_frame
		eq(sprite.visible, false, "%s walk does not flash the static turnaround" % class_id)
		var walking := _visible_strip(pawn)
		truthy(walking != null, "%s walk keeps a strip on screen" % class_id)
		if walking != null:
			eq(walking.sprite_frames.get_frame_texture("walk_e", 0), plant, "%s walk keeps the idle plant cell" % class_id)
			var shown := walking.sprite_frames.get_frame_texture(walking.animation, walking.frame)
			eq(shown != foreign, true, "%s stride is not the foreign idle texture" % class_id)
			eq(String(walking.animation), "walk_e", "%s stride stays on walk_e" % class_id)
		pawn.end_path_walk()
		eq(sprite.visible, false, "%s stop does not restore the static turnaround" % class_id)
		var rested := _visible_strip(pawn)
		truthy(rested != null, "%s stop stays on the walk sheet" % class_id)
		if rested != null:
			eq(String(rested.animation), "walk_e", "%s stop plants walk_e" % class_id)
			eq(rested.frame, 0, "%s stop plants frame 0" % class_id)
			eq(rested.sprite_frames.get_frame_texture(rested.animation, rested.frame) != foreign, true, "%s stop plant is not the static portrait" % class_id)
		pawn.free()
	var hidden := Pawn.new()
	get_root().add_child(hidden)
	await process_frame
	var concealed := _unit("gloam", "E", 0)
	concealed["invisible"] = true
	hidden.apply_snapshot(concealed, 0)
	await process_frame
	hidden.arm_driven_walk()
	await process_frame
	var hidden_sprite := hidden.get_node("Sprite") as CanvasItem
	var hidden_strip := _visible_strip(hidden)
	eq(hidden_sprite.modulate.a, 0.0, "Invisible walk does not show a solid body")
	truthy(hidden_strip != null, "Invisible walk still binds the Gloam sheet")
	if hidden_strip != null:
		eq(hidden_strip.modulate.a, 0.0, "Invisible walk strip stays hidden")
		eq(String(hidden_strip.animation), "walk_e", "Invisible walk stays on gloam walk_e")
	hidden.free()


func _test_batch1_disk_strips() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	pawn.apply_snapshot(_unit("kestrel", "E", 0), 0)
	var sprite := pawn.get_node("Sprite") as Sprite2D
	pawn.begin_path_walk()
	var playing := pawn.play_step_hop()
	await process_frame
	var strip := _visible_strip(pawn)
	truthy(strip != null, "kestrel walk shows the export strip")
	eq(playing, true, "kestrel east walk reports the strip playing")
	eq(strip.is_playing(), true, "kestrel BodyStrip is_playing after play_step_hop")
	eq(String(strip.animation), "walk_e", "kestrel east plays walk_e")
	eq(strip.sprite_frames.get_frame_count("walk_e") >= 2, true, "kestrel walk has at least two frames")
	_assert_strip_cells(strip, "walk_e")
	var walked_from := strip.frame
	await create_timer(0.12).timeout
	eq(strip.is_playing(), true, "kestrel walk keeps playing across the tile")
	eq(strip.frame != walked_from, true, "kestrel walk frame advances")
	eq(strip.sprite_frames.get_animation_loop("walk_e"), true, "disk walk loops")
	eq(is_equal_approx(strip.speed_scale, Pawn.walk_strip_speed_scale()), true, "disk walk plays one cycle per tile")
	eq(sprite.visible, false, "static sprite steps aside for the disk walk")
	eq(_walk_bounce_ok(sprite.position.y), true, "disk walk hops inside 2-4px")
	eq(_walk_bounce_ok(strip.position.y), true, "the disk strip root takes the step hop")
	eq(strip.offset, Vector2(0, -72), "disk strip uses the foot pivot")
	eq(strip.scale, Vector2(0.5, 0.5), "disk strip uses the shipped scale")
	eq(strip.flip_h, false, "disk strip is not mirrored at runtime")
	strip.frame = 4
	pawn.finish_step()
	pawn.play_step_hop()
	eq(strip.frame, 4, "the path does not restart the disk walk")
	pawn.set_facing("W")
	pawn.play_step_hop()
	eq(String(strip.animation), "walk_w", "west plays the baked mirror as walk_w")
	eq(_walk_bounce_ok(sprite.position.y), true, "the facing snap stays a short hop")
	pawn.end_path_walk()
	var kestrel_rest := _visible_strip(pawn)
	truthy(kestrel_rest != null and String(kestrel_rest.animation) == "walk_w", "path end stays on the west walk sheet")
	eq(kestrel_rest.frame, 0, "path end plants the west walk frame 0")
	eq(sprite.visible, false, "path end does not restore the foreign kestrel idle")
	pawn.set_facing("E")
	var dur := pawn.play_view_plan({"attack": true, "aim": Vector2(32, 16)})
	_assert_attack_hold(pawn, Vector2(32, 16), "kestrel attack")
	eq(dur <= MOTION.ACTION_LOCK_MAX, true, "kestrel attack hold stays inside the lock")
	await process_frame
	strip = _visible_strip(pawn)
	truthy(strip != null, "kestrel attack shows the export strip")
	eq(strip.is_playing(), true, "kestrel attack strip is_playing")
	eq(String(strip.animation), "attack_e", "kestrel east plays attack_e")
	eq(strip.sprite_frames.get_frame_count("attack_e") >= 2, true, "kestrel attack has at least two frames")
	_assert_strip_cells(strip, "attack_e")
	eq(strip.sprite_frames.get_animation_loop("attack_e"), false, "disk attack is one-shot")
	eq(dur > 0.45 and dur <= 0.6, true, "disk attack plays the 12 fps cycle inside the lock")
	eq(is_equal_approx(strip.speed_scale, 1.0), true, "disk attack stays at authored 12 fps")
	_assert_attack_impact(strip, "kestrel attack")
	await create_timer(0.12).timeout
	eq(sprite.position.length() > 2.0, true, "disk attack keeps the lunge")
	pawn.settle_motion()
	var mark_plans: Dictionary = MOTION.chrome_plans([{
		"type": "hit",
		"spell": SpellKits.MARK_SHOT,
		"seat": 0,
		"target_seat": 1,
		"to": Vector2i(4, 1),
	}])
	var mark_plan: Dictionary = mark_plans.get(0, {})
	eq(bool(mark_plan.get("cast", false)), true, "Mark Shot stays a cast in the kit")
	eq(bool(mark_plan.get("attack", false)), false, "Mark Shot is not reclassified as melee")
	eq(str(mark_plan.get("strip", "")), "cast_mark", "Mark Shot names cast_mark for the hot-swap")
	mark_plan["aim"] = Vector2(40, 8)
	var bow := pawn.play_view_plan(mark_plan)
	_assert_attack_hold(pawn, Vector2(40, 8), "Mark Shot")
	eq(bow <= MOTION.ACTION_LOCK_MAX, true, "Mark Shot impact hold stays inside the lock")
	await process_frame
	strip = _visible_strip(pawn)
	truthy(strip != null, "kestrel bow shows the cast_mark strip")
	eq(strip.is_playing(), true, "Mark Shot cast_mark strip is_playing")
	eq(String(strip.animation), "cast_mark_e", "Mark Shot plays cast_mark_e")
	eq(bow > 0.45 and bow <= 0.6, true, "the bow cycle fits the action lock")
	eq(is_equal_approx(strip.speed_scale, 1.0), true, "the bow cycle stays at 12 fps")
	_assert_attack_impact(strip, "Mark Shot")
	pawn.settle_motion()
	pawn.set_facing("E")
	mark_plan["aim"] = Vector2(-48, -16)
	pawn.play_view_plan(mark_plan)
	await process_frame
	strip = _visible_strip(pawn)
	eq(pawn.facing, "W", "Mark Shot faces the prey")
	eq(String(strip.animation), "cast_mark_w", "Mark Shot plays the strip toward the prey")
	pawn.settle_motion()
	var det_hit: Dictionary = MOTION.chrome_plans([{
		"type": "hit",
		"spell": SpellKits.DETONATE,
		"seat": 0,
		"target_seat": 1,
		"damage": 6,
	}]).get(0, {})
	var det_miss: Dictionary = MOTION.chrome_plans([{
		"type": "miss",
		"spell": SpellKits.DETONATE,
		"seat": 0,
		"target_seat": 1,
	}]).get(0, {})
	eq(bool(det_hit.get("cast", false)), true, "Detonate hit winds up")
	eq(bool(det_miss.get("cast", false)), true, "Detonate miss winds up")
	eq(bool(det_hit.get("cast", false)), bool(det_miss.get("cast", false)), "Detonate miss uses the same wind-up")
	eq(bool(det_hit.get("attack", false)), false, "Detonate stays a cast in the kit")
	eq(str(det_hit.get("strip", "")), "cast", "Detonate names cast, not attack")
	det_miss["aim"] = Vector2(40, 8)
	var boom := pawn.play_view_plan(det_miss)
	eq(boom > 0.2 and boom <= MOTION.ACTION_LOCK_MAX, true, "Detonate plays inside the action lock")
	await process_frame
	strip = _visible_strip(pawn)
	truthy(strip != null, "Detonate shows the cast strip")
	if strip != null:
		eq(String(strip.animation), "cast_e", "Detonate plays cast_e")
		eq(strip.sprite_frames.get_animation_loop("cast_e"), false, "Detonate cast is one-shot")
		eq(String(strip.animation) != "attack_e", true, "Detonate does not borrow the attack strip")
	eq(sprite.visible, false, "Detonate steps aside for the cast strip")
	var point_t := (MOTION.ANTICIPATION_SEC + MOTION.CAST_RISE_SEC + MOTION.impact_hold_sec() * 0.5) / MOTION.cast_sec()
	pawn._sample_cast(point_t, Vector2(40, 8))
	eq(sprite.position.x > 4.0, true, "Detonate points toward the effect")
	pawn.settle_motion()
	var attack_rest := _visible_strip(pawn)
	truthy(attack_rest != null and String(attack_rest.animation).begins_with("walk"), "settle returns to the walk plant after a disk attack")
	eq(attack_rest.frame, 0, "settle plants walk frame 0 after a disk attack")
	eq(sprite.visible, false, "settle does not flash the static turnaround after a disk attack")
	pawn.free()
	var jaw := Pawn.new()
	get_root().add_child(jaw)
	await process_frame
	jaw.apply_snapshot(_unit("ironjaw", "N", 1), 1)
	jaw.begin_path_walk()
	var jaw_playing := jaw.play_step_hop()
	await process_frame
	var jaw_strip := _visible_strip(jaw)
	truthy(jaw_strip != null, "ironjaw walk shows the export strip")
	eq(jaw_playing, true, "ironjaw north walk reports the strip playing")
	eq(jaw_strip.is_playing(), true, "ironjaw BodyStrip is_playing after play_step_hop")
	eq(String(jaw_strip.animation), "walk_n", "ironjaw north plays walk_n")
	eq(jaw_strip.sprite_frames.get_frame_count("walk_n") >= 2, true, "ironjaw walk has at least two frames")
	_assert_strip_cells(jaw_strip, "walk_n")
	eq(_walk_bounce_ok((jaw.get_node("Sprite") as Sprite2D).position.y), true, "ironjaw walk bounces inside 4-6px")
	eq((jaw.get_node("Sprite") as Sprite2D).scale, Pawn.sprite_scale_for("ironjaw"), "ironjaw walk keeps the presentation scale")
	eq(jaw_strip.scale, Pawn.sprite_scale_for("ironjaw"), "ironjaw walk strip keeps the presentation scale")
	eq(jaw_strip.offset, Vector2(0, -72), "ironjaw walk keeps the foot pivot")
	jaw.end_path_walk()
	var strike_plans: Dictionary = MOTION.chrome_plans([{
		"type": "hit",
		"spell": SpellKits.STRIKE,
		"seat": 1,
		"target_seat": 0,
	}])
	var strike_plan: Dictionary = strike_plans.get(1, {})
	eq(bool(strike_plan.get("attack", false)), true, "Ironjaw Strike is an attack plan")
	strike_plan["aim"] = Vector2(0, 24)
	var slam := jaw.play_view_plan(strike_plan)
	_assert_attack_hold(jaw, Vector2(0, 24), "Ironjaw Strike")
	eq(slam <= MOTION.ACTION_LOCK_MAX, true, "Strike impact hold stays inside the lock")
	await process_frame
	jaw_strip = _visible_strip(jaw)
	truthy(jaw_strip != null, "ironjaw strike shows the attack strip")
	eq(jaw_strip.is_playing(), true, "ironjaw strike strip is_playing")
	eq(String(jaw_strip.animation), "attack_n", "ironjaw north plays attack_n")
	eq(jaw_strip.sprite_frames.get_frame_count("attack_n") >= 2, true, "ironjaw attack has at least two frames")
	_assert_strip_cells(jaw_strip, "attack_n")
	eq(slam > 0.45 and slam <= 0.6, true, "ironjaw strike plays the authored cycle")
	eq(is_equal_approx(jaw_strip.speed_scale, 1.0), true, "ironjaw attack stays at 12 fps")
	_assert_attack_impact(jaw_strip, "Ironjaw Strike")
	jaw.settle_motion()
	var adv_plans: Dictionary = MOTION.chrome_plans([{
		"type": "advance",
		"spell": SpellKits.ADVANCE,
		"seat": 1,
		"from": Vector2i(7, 7),
		"to": Vector2i(5, 7),
		"teleport": true,
	}])
	eq(adv_plans.is_empty(), true, "Advance snap has no caster chrome")
	var snap_dur := jaw.play_view_plan({})
	eq(snap_dur, 0.0, "Advance plays no body motion")
	eq(jaw.motion_playing(), false, "Advance does not lock the sprite")
	var advance_body := _visible_strip(jaw)
	eq(advance_body == null or not String(advance_body.animation).begins_with("attack"), true, "Advance does not play an attack strip")
	eq((jaw.get_node("Sprite") as Sprite2D).position, Vector2.ZERO, "Advance stays planted, no hop")
	jaw.free()
	var other := Pawn.new()
	get_root().add_child(other)
	await process_frame
	other.apply_snapshot(_unit("gloam", "E", 0), 0)
	eq(other.has_walk_strip(), true, "gloam walk strip is on disk")
	eq(other.has_attack_strip(), true, "gloam attack strip is on disk")
	eq(other.has_cast_strip(), true, "gloam cast strip is on disk")
	other.begin_path_walk()
	var gloam_playing := other.play_step_hop()
	await process_frame
	var gloam_strip := _visible_strip(other)
	truthy(gloam_strip != null, "gloam walk shows the export strip")
	eq(gloam_playing, true, "gloam east walk reports the strip playing")
	if gloam_strip != null:
		eq(String(gloam_strip.animation), "walk_e", "gloam east plays walk_e")
		eq(gloam_strip.sprite_frames.get_frame_count("walk_e"), 6, "gloam walk is 6 frames")
		eq(gloam_strip.flip_h, false, "gloam walk is not mirrored at runtime")
	eq((other.get_node("Sprite") as Sprite2D).scale, Vector2(0.5, 0.5), "gloam walk does not stretch")
	other.end_path_walk()
	var cut := other.play_view_plan({"attack": true, "aim": Vector2(32, 16)})
	await process_frame
	gloam_strip = _visible_strip(other)
	truthy(gloam_strip != null, "gloam attack shows the export strip")
	if gloam_strip != null:
		eq(String(gloam_strip.animation), "attack_e", "gloam east plays attack_e")
		eq(gloam_strip.sprite_frames.get_frame_count("attack_e"), 5, "gloam attack is 5 frames")
		var hold_t := (MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC + MOTION.impact_hold_sec() * 0.5) / MOTION.attack_sec()
		other._sample_attack(hold_t, Vector2(32, 16))
		eq(gloam_strip.frame, StripLibrary.impact_frame("gloam", "attack"), "gloam attack holds frame 2")
	eq(cut <= MOTION.ACTION_LOCK_MAX, true, "gloam attack hold stays inside the lock")
	other.settle_motion()
	var gloam_hit := other.play_view_plan({"hit": true, "away": Vector2(20, 8)})
	await process_frame
	gloam_strip = _visible_strip(other)
	truthy(gloam_strip != null, "gloam hit shows the flinch strip")
	if gloam_strip != null:
		eq(String(gloam_strip.animation), "hit_e", "gloam hit plays hit_e")
	eq(gloam_hit <= MOTION.ACTION_LOCK_MAX, true, "gloam hit stays inside the lock")
	other.settle_motion()
	other.free()


func _assert_attack_hold(pawn: Pawn, aim: Vector2, msg: String) -> void:
	var hold_t := (MOTION.ANTICIPATION_SEC + MOTION.ATTACK_OUT_SEC + MOTION.impact_hold_sec() * 0.5) / MOTION.attack_sec()
	pawn._sample_attack(hold_t, aim)
	var strip := _visible_strip(pawn)
	truthy(strip != null, "%s keeps a body strip on the impact hold" % msg)
	if strip == null:
		return
	var count := strip.sprite_frames.get_frame_count(String(strip.animation))
	var expect_frame := mini(StripLibrary.ATTACK_IMPACT_FRAME, count - 1)
	eq(strip.frame, expect_frame, "%s holds the impact frame" % msg)
	eq(is_equal_approx(strip.speed_scale, 0.0), true, "%s stretches the impact pose" % msg)
	eq((pawn.get_node("Sprite") as Sprite2D).position.length() > 8.0, true, "%s holds the lunge" % msg)
	eq(MOTION.attack_sec() <= MOTION.ACTION_LOCK_MAX, true, "%s hold fits the action lock" % msg)


func _assert_attack_impact(strip: AnimatedSprite2D, msg: String) -> void:
	var anim := String(strip.animation)
	eq(strip.sprite_frames.get_frame_count(anim) > StripLibrary.ATTACK_IMPACT_FRAME, true, "%s reaches the impact frame" % msg)
	var cell := strip.sprite_frames.get_frame_texture(anim, StripLibrary.ATTACK_IMPACT_FRAME)
	truthy(cell != null, "%s impact frame has a texture" % msg)
	eq(cell.get_width(), 144, "%s impact cell is 144 wide" % msg)
	eq(cell.get_height(), 160, "%s impact cell is 160 tall" % msg)
	var matched := false
	for cls in ["kestrel", "ironjaw"]:
		var authored_bank := ResourceLoader.load(StripLibrary.export_frames_path(cls), "", ResourceLoader.CACHE_MODE_REUSE) as SpriteFrames
		if authored_bank == null or not authored_bank.has_animation(anim):
			continue
		var authored := authored_bank.get_frame_texture(anim, StripLibrary.ATTACK_IMPACT_FRAME) as AtlasTexture
		if authored == null:
			continue
		eq(is_equal_approx(authored.region.position.x, 144.0 * float(StripLibrary.ATTACK_IMPACT_FRAME)), true, "%s tres impact is frame index 3" % msg)
		eq(authored.region.size, Vector2(144, 160), "%s tres impact cell is 144x160" % msg)
		var authored_image := authored.get_image()
		var played_image := cell.get_image()
		if authored_image != null and played_image != null and authored_image.get_data() == played_image.get_data():
			matched = true
	eq(matched, true, "%s impact matches the authored frame-3 cell" % msg)


func _test_failed_strip_falls_back_to_hop() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	pawn.apply_snapshot(_unit("mender", "E", 0), 0)
	var frames := SpriteFrames.new()
	_add_anim(frames, "walk_e", 4, 12.0)
	_add_anim(frames, "walk_s", 4, 12.0)
	pawn.bind_motion_frames(frames)
	pawn.set_facing("E")
	var strip := pawn.get_node("BodyStrip") as AnimatedSprite2D
	strip.animation = "walk_s"
	strip.animation_changed.connect(func() -> void:
		strip.stop()
	)
	var started := pawn.play_step_hop()
	eq(started, false, "a strip that stops during play does not count as playing")
	await process_frame
	var sprite := pawn.get_node("Sprite") as Sprite2D
	eq(strip.is_playing(), false, "the failed strip is not playing")
	eq(strip.visible, true, "failed playback plants the walk sheet")
	eq(String(strip.animation), "walk_e", "failed playback stays on the facing walk strip")
	eq(strip.frame, 0, "failed playback plants frame 0")
	eq(sprite.visible, false, "failed playback does not reveal the static still")
	await create_timer(Pawn.WALK_HOP_SEC * 0.45).timeout
	eq(_step_bob_ok(strip.position.y), true, "failed strip playback bobs, not a 36px hop")
	eq(strip.scale, Vector2(0.5, 0.5), "failed strip playback does not stretch")
	pawn.settle_motion()
	pawn.free()


func _assert_locked_walk_png(bank: SpriteFrames, class_id: String) -> void:
	for face in ["n", "e", "s", "w"]:
		var anim := "walk_%s" % face
		var played := bank.get_frame_texture(anim, 0).get_image()
		var sheet := (ResourceLoader.load(StripLibrary.export_png_path(class_id, "walk", face)) as Texture2D).get_image()
		var cell := sheet.get_region(Rect2i(0, 0, StripLibrary.CELL_W, sheet.get_height()))
		eq(played.get_width(), StripLibrary.CELL_W, "%s %s playback is one cell" % [class_id, anim])
		eq(played.get_data(), cell.get_data(), "%s %s frame 0 is the export_2x walk cell" % [class_id, anim])


func _assert_strip_cells(strip: AnimatedSprite2D, anim: String) -> void:
	var frames := strip.sprite_frames
	var count := frames.get_frame_count(anim)
	eq(count >= 2, true, "%s frame_count is at least 2" % anim)
	for i in count:
		var tex := frames.get_frame_texture(anim, i)
		truthy(tex != null, "%s frame %d texture is non-null" % [anim, i])
		eq(tex.get_width() > 0 and tex.get_width() < 800, true, "%s frame %d is one cell, not the whole strip" % [anim, i])


func _visible_strip(pawn: Pawn) -> AnimatedSprite2D:
	for child in pawn.get_children():
		if child is AnimatedSprite2D and (child as AnimatedSprite2D).visible:
			return child as AnimatedSprite2D
	return null


func _walk_bounce_ok(y: float) -> bool:
	# Rise stays inside 4px. Class crests sit under that cap. No floor press.
	return y <= 0.05 and y >= -4.05


func _cycle_visits_contact(frame_count: int, contact: int) -> bool:
	var seen := {}
	var planted := MOTION.walk_cycle_frame(0.0, frame_count, 0, contact)
	if planted != contact:
		return false
	seen[planted] = true
	for i in 24:
		var step_t := float(i) / 24.0
		if step_t <= 0.0 or step_t >= MOTION.HOP_PLANT_AT:
			continue
		var frame := MOTION.walk_cycle_frame(step_t, frame_count, 0, contact)
		if frame == contact:
			return false
		seen[frame] = true
	if MOTION.walk_cycle_frame(1.0, frame_count, 0, contact) != contact:
		return false
	return seen.size() == frame_count


func _test_class_plant_anchor() -> void:
	for class_id in ["kestrel", "ironjaw", "gloam", "mender", "bastion"]:
		StripLibrary.frames_for(class_id)
		for face in ["n", "e", "s", "w"]:
			eq(StripLibrary.walk_contact_index(class_id, face), 0, "%s %s v4 contact stays frame 0" % [class_id, face])
		var pawn := Pawn.new()
		get_root().add_child(pawn)
		await process_frame
		pawn.apply_snapshot(_unit(class_id, "E", 0), 0)
		await process_frame
		var origin := pawn.position
		pawn.arm_driven_walk()
		pawn.sync_walk_plant()
		pawn.sample_driven_gait(0.5)
		var strip := _visible_strip(pawn)
		var crest := MOTION.hop_crest_px(class_id)
		truthy(strip != null, "%s walk strip stays up through the hop" % class_id)
		if strip != null:
			eq(is_equal_approx(strip.position.y, -crest), true, "%s hop crest matches its mass" % class_id)
			eq(strip.position.x, 0.0, "%s hop has no sideways slide" % class_id)
			eq(is_equal_approx(strip.scale.x, Pawn.sprite_scale_for(class_id).x), true, "%s mid-hop does not squash X" % class_id)
			eq(is_equal_approx(strip.scale.y, Pawn.sprite_scale_for(class_id).y), true, "%s mid-hop does not squash Y" % class_id)
			eq(strip.frame != 0, true, "%s mid-hop is not the contact frame" % class_id)
		eq((pawn.get_node("Chrome") as Node2D).position, Vector2.ZERO, "%s hop does not lift the name" % class_id)
		eq((pawn.get_node("Foot") as Node2D).position, Vector2.ZERO, "%s hop does not lift the foot or aim mark" % class_id)
		eq(pawn.scale, Vector2.ONE, "%s hop does not scale the pawn" % class_id)
		eq(pawn.position, origin, "%s hop does not move the foot off the cell" % class_id)
		pawn.sample_driven_gait(0.91)
		if strip != null:
			eq(strip.position, Vector2.ZERO, "%s plant hold is back on the foot" % class_id)
			eq(strip.frame, 0, "%s plant hold shows the contact frame" % class_id)
			eq(strip.scale.y < Pawn.sprite_scale_for(class_id).y, true, "%s plant squashes the sprite only" % class_id)
			eq(is_equal_approx(strip.scale.x, Pawn.sprite_scale_for(class_id).x), true, "%s plant squash does not widen" % class_id)
		eq((pawn.get_node("Chrome") as Node2D).position, Vector2.ZERO, "%s plant squash does not move the name" % class_id)
		eq((pawn.get_node("Foot") as Node2D).position, Vector2.ZERO, "%s plant squash does not move the shade anchor" % class_id)
		eq(pawn.scale, Vector2.ONE, "%s plant squash leaves the collider scale alone" % class_id)
		if class_id == "ironjaw":
			eq(Pawn.presentation_mul("ironjaw"), 1.0, "ironjaw art-fill stays at scale 1.0")
			eq(is_equal_approx(Pawn.sprite_scale_for("ironjaw").y, 0.5), true, "ironjaw body scale stays the shared 0.5")
		pawn.hold_stop_plant()
		var stopped := _visible_strip(pawn)
		truthy(stopped != null, "%s stop keeps the walk sheet" % class_id)
		if stopped != null:
			eq(stopped.frame, 0, "%s stop holds the contact, not a passing frame" % class_id)
			eq(is_equal_approx(stopped.scale.y, Pawn.sprite_scale_for(class_id).y), true, "%s stop releases the squash" % class_id)
		var sprite := pawn.get_node("Sprite") as Sprite2D
		eq(sprite.visible, false, "%s stop does not flash the static idle" % class_id)
		pawn.free()


func _stride_wraps(frame_count: int) -> int:
	var prev := -1
	var wraps := 0
	for i in 25:
		var frame := MOTION.walk_cycle_frame(float(i) / 24.0, frame_count, 0)
		if prev >= 0 and frame < prev:
			wraps += 1
		prev = frame
	return wraps


func _step_bob_ok(y: float) -> bool:
	return y < -1.0 and y >= -MOTION.WALK_BOUNCE_PX - 0.05


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
