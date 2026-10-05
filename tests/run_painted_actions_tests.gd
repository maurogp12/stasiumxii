extends SceneTree

## LOCKED painted combat actions on the mobile board (4 Oct 2026).
## Assets: idle, attack, skill, hit and death for all five classes, 4 facings,
## binary alpha, W/S mirrors baked, at the class walk's scale. walk and idle
## share one cell and pivot; each action kind has its own cell (<= 256) with
## its ground point per facing (StripLibrary.CELL_PIVOT_META).
## Playback: idle loops while standing (walk f00 is the fallback), attack and
## skill (as cast) and hit play once and return to idle, death plays once and
## holds its last cell. A missing sheet keeps today's strip or motion.
## Run: godot --headless --path . -s res://tests/run_painted_actions_tests.gd

const MOTION := preload("res://units/view_motion.gd")
const SPECS := preload("res://units/character_strip_specs.gd")
const CLASSES: Array[String] = ["bastion", "kestrel", "gloam", "mender", "ironjaw"]
const LETTERS: Array[String] = ["n", "e", "s", "w"]
const KINDS := {"idle": 12, "attack": 12, "skill": 12, "hit": 8, "death": 13}
const ANIM := {"idle": "idle", "attack": "attack", "skill": "cast", "hit": "hit", "death": "death"}

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	StripLibrary.set_painted_looks(true)
	MOTION.clear_reduce_motion()
	_test_specs()
	_test_sheets()
	_test_idle_lines_up_with_walk()
	_test_library_clips()
	_test_release_timing()
	call_deferred("_finish_live")


func _finish_live() -> void:
	for class_id in CLASSES:
		await _test_triggers(class_id)
	await _test_idle_loops()
	await _test_mark_shot_and_contract()
	await _test_death_holds()
	await _test_fallback()
	StripLibrary.clear_cache()
	print("Painted actions tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_specs() -> void:
	for class_id in CLASSES:
		var walk := StripLibrary.painted_spec(class_id, "walk")
		for kind in KINDS:
			var spec := StripLibrary.painted_spec(class_id, kind)
			truthy(not spec.is_empty(), "%s has a painted %s spec" % [class_id, kind])
			eq(int(spec.get("frames", 0)), int(KINDS[kind]), "%s %s is %d frames" % [class_id, kind, KINDS[kind]])
			near(float(spec.get("fps", 0.0)), 17.144, "%s %s is authored at 17.144 fps" % [class_id, kind])
			eq(bool(spec.get("loop", true)), kind == "idle", "%s %s loops only when idle" % [class_id, kind])
			near(float(spec.get("scale", 0.0)), float(walk.get("scale", -1.0)), "%s %s is at the walk scale (no size jump)" % [class_id, kind])
			var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
			truthy(cell.x > 0 and cell.x <= 256 and cell.y > 0 and cell.y <= 256, "%s %s cell %s is within the 256 cap" % [class_id, kind, cell])
			var pivots: Dictionary = spec.get("pivots", {})
			eq(pivots.size(), 4, "%s %s has a pivot per facing" % [class_id, kind])
			for face in LETTERS:
				var p: Vector2i = pivots.get(face, Vector2i(-1, -1))
				truthy(p.x > 0 and p.x < cell.x and p.y >= int(Pawn.FOOT_PIVOT_Y) and p.y < cell.y, "%s %s %s pivot %s sits inside the cell, on or under the 152 sole line" % [class_id, kind, face, p])
			# Mirrors: s is the mirror of e, w of n.
			eq((pivots["s"] as Vector2i).x, cell.x - (pivots["e"] as Vector2i).x, "%s %s s pivot mirrors e" % [class_id, kind])
			eq((pivots["w"] as Vector2i).x, cell.x - (pivots["n"] as Vector2i).x, "%s %s w pivot mirrors n" % [class_id, kind])
			if kind == "attack" or kind == "skill":
				var impact := int(spec.get("impact", -1))
				truthy(impact > 0 and impact < int(KINDS[kind]) - 1, "%s %s has an impact cell (%d)" % [class_id, kind, impact])
		var idle := StripLibrary.painted_spec(class_id, "idle")
		eq(idle.get("cell"), walk.get("cell"), "%s idle shares the walk cell" % class_id)
		eq(idle.get("pivots"), walk.get("pivots"), "%s idle shares the walk pivot" % class_id)
		eq(idle.get("pivot"), Vector2i((walk.get("cell") as Vector2i).x / 2, int(Pawn.FOOT_PIVOT_Y)), "%s idle stands centred on the 152 sole line" % class_id)
	truthy(str(StripLibrary.painted_spec("ironjaw", "walk").get("source", "")).contains("ironjaw_walk/v7"), "Ironjaw walks on the dark-steel v7")


func _sheet(class_id: String, kind: String, face: String) -> Image:
	var path := StripLibrary.painted_path(class_id, kind, face)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return image


func _cell(sheet: Image, cell: Vector2i, i: int) -> Image:
	return sheet.get_region(Rect2i(i * cell.x, 0, cell.x, cell.y))


## Opaque bounds: x0, y0, x1, y1 (or -1s when empty).
func _bounds(image: Image) -> Rect2i:
	var used := image.get_used_rect()
	return used


func _test_sheets() -> void:
	for class_id in CLASSES:
		for kind in KINDS:
			var spec := StripLibrary.painted_spec(class_id, kind)
			var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
			var count := int(KINDS[kind])
			var sheets := {}
			for face in LETTERS:
				var sheet := _sheet(class_id, kind, face)
				truthy(sheet != null, "%s %s_%s sheet is on disk" % [class_id, kind, face])
				if sheet == null:
					continue
				sheets[face] = sheet
				eq(sheet.get_size(), Vector2i(cell.x * count, cell.y), "%s %s_%s is %d cells of %s" % [class_id, kind, face, count, cell])
				eq(sheet.detect_alpha(), Image.ALPHA_BIT, "%s %s_%s alpha is binary" % [class_id, kind, face])
				var inside := true
				var empty := false
				for i in count:
					var r := _bounds(_cell(sheet, cell, i))
					if r.size.x <= 0:
						empty = true
					elif r.position.x <= 0 or r.position.y <= 0 or r.end.x >= cell.x or r.end.y >= cell.y:
						inside = false
				eq(empty, false, "%s %s_%s has a figure in every cell" % [class_id, kind, face])
				eq(inside, true, "%s %s_%s never touches the cell edge (nothing clipped)" % [class_id, kind, face])
			for pair in [["e", "s"], ["n", "w"]]:
				if not sheets.has(pair[0]) or not sheets.has(pair[1]):
					continue
				var same := true
				for i in [0, count / 2, count - 1]:
					var a := _cell(sheets[pair[0]], cell, i)
					a.flip_x()
					if a.get_data() != _cell(sheets[pair[1]], cell, i).get_data():
						same = false
				truthy(same, "%s %s_%s is the baked mirror of %s_%s" % [class_id, kind, pair[1], kind, pair[0]])


## Lowest opaque row of a cell, relative to its sole line.
func _sole_rows(class_id: String, kind: String, face: String, frames: Array) -> Array:
	var spec := StripLibrary.painted_spec(class_id, kind)
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var pivot: Vector2i = (spec.get("pivots", {}) as Dictionary).get(face, Vector2i.ZERO)
	var sheet := _sheet(class_id, kind, face)
	var out := []
	for i in frames:
		var r := _bounds(_cell(sheet, cell, i))
		out.append(Vector2i(r.position.y - pivot.y, r.end.y - 1 - pivot.y))
	return out


func _test_idle_lines_up_with_walk() -> void:
	for class_id in CLASSES:
		for face in ["e", "n"]:
			var walk := _sole_rows(class_id, "walk", face, range(12))
			var idle := _sole_rows(class_id, "idle", face, [0])
			var lo := 9999
			var hi := -9999
			var top_lo := 9999
			var top_hi := -9999
			for r in walk:
				lo = mini(lo, r.y)
				hi = maxi(hi, r.y)
				top_lo = mini(top_lo, r.x)
				top_hi = maxi(top_hi, r.x)
			var feet: int = (idle[0] as Vector2i).y
			var head: int = (idle[0] as Vector2i).x
			# Same ground: idle f00's feet are inside the band the walk's feet
			# cover on that sole line, and its head inside the walk's bob.
			truthy(feet >= lo - 3 and feet <= hi + 3, "%s idle_%s f00 feet (%d) stand on the walk's sole line (%d..%d)" % [class_id, face, feet, lo, hi])
			truthy(head >= top_lo - 4 and head <= top_hi + 4, "%s idle_%s f00 head (%d) is the walk's height (%d..%d)" % [class_id, face, head, top_lo, top_hi])
		var w := StripLibrary.painted_cells(class_id, "walk", "e")
		var i := StripLibrary.painted_cells(class_id, "idle", "e")
		if w.size() > 0 and i.size() > 0:
			eq(Pawn.texture_pivot_offset(i[0]), Pawn.texture_pivot_offset(w[0]), "%s idle f00 and walk f00 share the pawn offset" % class_id)
			eq(i[0].get_size(), w[0].get_size(), "%s idle f00 and walk f00 share the cell" % class_id)


func _test_library_clips() -> void:
	StripLibrary.clear_cache()
	for class_id in CLASSES:
		var frames := StripLibrary.frames_for(class_id)
		truthy(frames != null, "%s strip bank loads" % class_id)
		if frames == null:
			continue
		for kind in KINDS:
			var spec := StripLibrary.painted_spec(class_id, kind)
			for face in LETTERS:
				var anim := "%s_%s" % [ANIM[kind], face]
				truthy(frames.has_animation(anim), "%s has %s" % [class_id, anim])
				if not frames.has_animation(anim):
					continue
				eq(frames.get_frame_count(anim), int(KINDS[kind]), "%s %s has %d painted cells" % [class_id, anim, KINDS[kind]])
				near(frames.get_animation_speed(anim), 17.144, "%s %s keeps the authored fps" % [class_id, anim])
				eq(frames.get_animation_loop(anim), kind == "idle", "%s %s loop flag" % [class_id, anim])
				var tex := frames.get_frame_texture(anim, 1)
				truthy(StripLibrary.is_painted_cell(tex), "%s %s is a painted cell" % [class_id, anim])
				if tex != null:
					eq(tex.get_meta(StripLibrary.CELL_PIVOT_META), (spec["pivots"] as Dictionary)[face], "%s %s carries its pivot" % [class_id, anim])
		eq(frames.has_animation("cast_mark_e"), false, "%s has no old export_2x Mark Shot bow left" % class_id)
	# Ironjaw's Look 1 attack, hit and death are replaced.
	var ij := StripLibrary.frames_for("ironjaw")
	for kind in ["attack", "hit", "death"]:
		var tex := ij.get_frame_texture("%s_e" % kind, 0)
		eq(tex, StripLibrary.painted_cells("ironjaw", kind, "e")[0], "Ironjaw %s_e is the new painted strip, not Look 1" % kind)


func _test_release_timing() -> void:
	near(StripLibrary.PAINTED_ACTION_MAX_SEC, MOTION.ACTION_LOCK_MAX, "painted one-shots fit the 0.6 s action lock")
	near(StripLibrary.painted_play_fps(StripLibrary.painted_spec("ironjaw", "attack")), 20.0, "a 12-cell attack plays at 20 fps in the lock")
	near(StripLibrary.painted_play_fps(StripLibrary.painted_spec("ironjaw", "hit")), 17.144, "an 8-cell hit keeps 17.144 fps")
	near(StripLibrary.release_sec("ironjaw", "attack"), 0.3, "Strike lands on f06 at 0.30 s")
	near(StripLibrary.release_sec("gloam", "attack"), 0.3, "Cut lands on f06 at 0.30 s")
	near(StripLibrary.release_sec("kestrel", "cast"), 0.45, "Detonate releases on f09 at 0.45 s")
	near(MOTION.damage_resolve_sec(SpellKits.STRIKE), StripLibrary.release_sec("ironjaw", "attack"), "the Strike flinch waits for the painted chop")
	near(MOTION.damage_resolve_sec(SpellKits.BASH), StripLibrary.release_sec("bastion", "attack"), "a Bastion melee flinch waits for the painted smash")
	near(MOTION.damage_resolve_sec(SpellKits.DETONATE), StripLibrary.release_sec("kestrel", "cast"), "the Detonate flinch waits for the painted release")
	near(MOTION.damage_resolve_sec(SpellKits.MARK_SHOT), MOTION.MARK_WINDUP_SEC + MOTION.MARK_BOLT_SEC, "Mark Shot keeps its bolt timing")
	near(MOTION.damage_resolve_sec(SpellKits.CUT), StripLibrary.release_sec("gloam", "attack"), "Cut (2 AP since #272) still waits for the painted slash")
	eq(MOTION.caster_motion(SpellKits.CUT), "attack", "Cut is still a melee attack trigger")
	# Mender option B (#272): Pulse Tap can hit an enemy, Heartstop 4 AP. He has
	# no melee spell, so a cast that hurts a foe swings the painted lantern attack.
	near(MOTION.damage_resolve_sec(SpellKits.HEARTSTOP), StripLibrary.release_sec("mender", "attack"), "the Heartstop flinch waits for the lantern swing")
	near(MOTION.damage_resolve_sec(SpellKits.PULSE_TAP), StripLibrary.release_sec("mender", "attack"), "the Pulse Tap flinch waits for the lantern swing")
	var strike_tap := MOTION.chrome_plans([{"type": "hit", "seat": 0, "target_seat": 1, "spell": SpellKits.PULSE_TAP, "damage": 10}])
	eq(str((strike_tap.get(0, {}) as Dictionary).get("strip", "")), "attack", "Pulse Tap on a foe plays the painted attack")
	var heal_tap := MOTION.chrome_plans([{"type": "hit", "seat": 0, "target_seat": 2, "spell": SpellKits.PULSE_TAP, "damage": 0, "healed": 10}])
	eq(str((heal_tap.get(0, {}) as Dictionary).get("strip", "cast")), "cast", "Pulse Tap on an ally keeps the skill")
	var mend := MOTION.chrome_plans([{"type": "hit", "seat": 0, "target_seat": 2, "spell": SpellKits.MEND, "damage": 0, "healed": 12}])
	eq(bool((mend.get(0, {}) as Dictionary).get("cast", false)) and str((mend.get(0, {}) as Dictionary).get("strip", "cast")) == "cast", true, "Mend plays the skill")
	var heart_miss := MOTION.chrome_plans([{"type": "miss", "seat": 0, "target_seat": 1, "spell": SpellKits.HEARTSTOP, "damage": 0}])
	eq(str((heart_miss.get(0, {}) as Dictionary).get("strip", "")), "attack", "a Heartstop miss still swings the attack")


func _unit(class_id: String, facing: String, alive: bool = true) -> Dictionary:
	return {
		"pos": Vector2i(2, 2),
		"name": SpellKits.display_name(class_id),
		"class_id": class_id,
		"facing": facing,
		"seat": 0,
		"hp": 80 if alive else 0,
		"max_hp": 80,
		"alive": alive,
		"stun_remaining": 0,
	}


func _pawn(class_id: String, facing: String) -> Pawn:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	pawn.apply_snapshot(_unit(class_id, facing), 0)
	await process_frame
	await process_frame
	return pawn


func _idle_cell_drawn(pawn: Pawn, class_id: String, face: String) -> bool:
	var cells := StripLibrary.painted_cells(class_id, "idle", face)
	return pawn.painted_idle_showing() and cells.has(pawn.drawn_walk_texture())


func _test_triggers(class_id: String) -> void:
	var cases := [
		["attack", {"attack": true}, "attack"],
		["skill", {"cast": true, "strip": "cast"}, "cast"],
		["hit", {"hit": true, "delay": true, "contact": 0.0}, "hit"],
	]
	for face in ["E", "S", "N", "W"]:
		var letter: String = face.to_lower()
		for c in cases:
			var pawn: Pawn = await _pawn(class_id, face)
			truthy(_idle_cell_drawn(pawn, class_id, letter), "%s %s stands on the painted idle" % [class_id, face])
			var dur := pawn.play_view_plan(c[1])
			truthy(dur > 0.0 and dur <= MOTION.ACTION_LOCK_MAX + 0.001, "%s %s %s holds the board %.2f s" % [class_id, face, c[0], dur])
			var anim: String = "%s_%s" % [c[2], letter]
			var seen := false
			var cells := {}
			var start := Time.get_ticks_msec()
			while Time.get_ticks_msec() - start < int(dur * 1000.0):
				await process_frame
				var strip := pawn.walk_sampler()
				if strip != null and strip.visible and String(strip.animation) == anim:
					if not seen:
						eq(strip.offset, Pawn.texture_pivot_offset(strip.sprite_frames.get_frame_texture(strip.animation, 0)), "%s %s offset stands the painted cell on its pivot" % [class_id, anim])
					seen = true
					cells[strip.frame] = true
			truthy(seen, "%s %s plays %s" % [class_id, c[0], anim])
			truthy(cells.size() >= int(KINDS[c[0]]) / 2, "%s %s cycles its cells (%d seen)" % [class_id, anim, cells.size()])
			await create_timer(0.15).timeout
			eq(pawn.motion_playing(), false, "%s %s %s finishes" % [class_id, face, c[0]])
			pawn.settle_motion()
			await process_frame
			truthy(_idle_cell_drawn(pawn, class_id, letter), "%s %s returns to the painted idle after %s" % [class_id, face, c[0]])
			pawn.free()
			await process_frame


func _test_idle_loops() -> void:
	var pawn: Pawn = await _pawn("bastion", "E")
	var cells := StripLibrary.painted_cells("bastion", "idle", "e")
	pawn.settle_motion()
	await process_frame
	pawn.end_path_walk()
	pawn.settle_motion()
	await process_frame
	eq(pawn.drawn_walk_texture(), cells[0], "the idle starts on f00 when the stand begins")
	var seen := {}
	var sprite := pawn.get_node("Sprite") as Sprite2D
	var still := true
	for i in 60:
		await process_frame
		seen[cells.find(pawn.drawn_walk_texture())] = true
		if pawn.get_node("WalkDraw").position != Vector2.ZERO:
			still = false
	truthy(seen.size() >= 8 and not seen.has(-1), "the idle loops through its cells (%d seen)" % seen.size())
	eq(still, true, "the painted idle has no sprite bob on top")
	eq(sprite.visible, false, "the static stays hidden while idling")
	var mat := (pawn.get_node("WalkDraw") as Sprite2D).material as ShaderMaterial
	near(float(mat.get_shader_parameter("breath")), 0.0, "the shader breath is off (the cells breathe)")
	# A walk step takes the body back to the walk strip; the stop is idle again.
	pawn.arm_driven_walk()
	pawn.begin_segment_walk("E")
	pawn.sync_walk_plant()
	pawn.sample_driven_gait(0.5)
	eq(pawn.painted_idle_showing(), false, "walking is not the idle")
	truthy(StripLibrary.painted_cells("bastion", "walk", "e").has(pawn.drawn_walk_texture()), "walking draws walk cells")
	pawn.end_path_walk()
	pawn.settle_motion()
	await process_frame
	eq(pawn.drawn_walk_texture(), cells[0], "arrival stands on idle f00")
	pawn.free()
	await process_frame


func _test_mark_shot_and_contract() -> void:
	# Mark Shot takes its existing fallback (the attack, Kestrel's painted bow
	# shot), timed so the loose (f09) is on the bolt release.
	var pawn: Pawn = await _pawn("kestrel", "E")
	pawn.play_view_plan({"cast": true, "strip": "cast_mark"})
	var strip := pawn.walk_sampler()
	truthy(strip != null and String(strip.animation) == "attack_e", "Mark Shot plays the painted attack_e")
	if strip != null:
		near(strip.speed_scale * 17.144 * MOTION.MARK_WINDUP_SEC, 9.0, "the loose lands on the 0.30 s bolt release")
	pawn.free()
	await process_frame
	pawn = await _pawn("gloam", "E")
	pawn.play_view_plan({"attack": true, "reach": MOTION.AMBUSH_LUNGE_PX})
	strip = pawn.walk_sampler()
	if strip != null:
		near(strip.speed_scale * 17.144 * MOTION.ambush_contact_sec(), 6.0, "the Ambush slash lands on its contact time")
	pawn.free()
	await process_frame
	pawn = await _pawn("mender", "E")
	pawn.play_view_plan({"cast": true, "strip": "attack"})
	strip = pawn.walk_sampler()
	truthy(strip != null and String(strip.animation) == "attack_e" and StripLibrary.is_painted_cell(strip.sprite_frames.get_frame_texture("attack_e", 0)), "a Mender strike cast plays the painted attack_e")
	pawn.free()
	await process_frame
	pawn = await _pawn("ironjaw", "E")
	pawn.play_view_plan({"attack": true, "aim": Vector2(20, 10)})
	strip = pawn.walk_sampler()
	if strip != null:
		near(strip.speed_scale * 17.144, 20.0, "Strike plays evenly at 20 fps (fits the lock)")
	await process_frame
	eq(pawn.get_node_or_null("Gesture") == null or not (pawn.get_node("Gesture") as Node2D).visible, true, "no hand mark over a painted strike")
	eq(strip.position, Vector2.ZERO, "no lunge over a painted strike")
	pawn.free()
	await process_frame


func _test_death_holds() -> void:
	for class_id in CLASSES:
		var pawn: Pawn = await _pawn(class_id, "S")
		pawn.play_view_plan({"death": true})
		await process_frame
		await process_frame
		var strip := pawn.walk_sampler()
		truthy(strip != null and String(strip.animation) == "death_s", "%s death plays death_s" % class_id)
		if strip != null:
			near(strip.speed_scale, 1.0, "%s death plays at the authored 17.144 fps" % class_id)
		await create_timer(MOTION.ACTION_LOCK_MAX + 0.1).timeout
		pawn.apply_snapshot(_unit(class_id, "S", false), 0)
		await create_timer(0.5).timeout
		strip = pawn.walk_sampler()
		truthy(strip != null and strip.visible and String(strip.animation) == "death_s" and strip.frame == 12, "%s death holds its last cell" % class_id)
		pawn.apply_snapshot(_unit(class_id, "S", false), 0)
		await create_timer(0.3).timeout
		strip = pawn.walk_sampler()
		truthy(strip != null and strip.visible and strip.frame == 12, "%s a later snapshot keeps the body down" % class_id)
		eq(pawn.painted_idle_showing(), false, "%s the dead do not idle" % class_id)
		pawn.free()
		await process_frame


func _test_fallback() -> void:
	StripLibrary.clear_cache()
	# Pretend Kestrel's east idle and Ironjaw's east attack sheets are missing.
	StripLibrary._painted_cells[StripLibrary.painted_path("kestrel", "idle", "e")] = []
	StripLibrary._painted_cells[StripLibrary.painted_path("ironjaw", "attack", "e")] = []
	var ij := StripLibrary.frames_for("ironjaw")
	truthy(ij.has_animation("attack_e") and not StripLibrary.is_painted_cell(ij.get_frame_texture("attack_e", 0)), "a missing painted attack keeps today's attack_e")
	truthy(StripLibrary.is_painted_cell(ij.get_frame_texture("attack_s", 0)), "the other facings stay painted")
	var pawn: Pawn = await _pawn("kestrel", "E")
	eq(pawn.painted_idle_showing(), false, "no idle sheet: no idle loop")
	eq(pawn.drawn_walk_texture(), StripLibrary.painted_cells("kestrel", "walk", "e")[0], "no idle sheet: walk f00 stands")
	pawn.free()
	await process_frame
	StripLibrary.clear_cache()


func near(actual: float, expected: float, msg: String) -> void:
	eq(absf(actual - expected) < 0.001, true, "%s (got %s expected %s)" % [msg, actual, expected])


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
