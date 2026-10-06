extends SceneTree

## Locked painted looks on PC (4 Oct 2026): the world hero's walk, run and
## idle, and the dungeon hero's painted idle, walk, attack, skill, hit and
## death, for all five classes. Run:
##   godot --headless --path . -s res://tests/run_locked_s_walk_tests.gd
## (The old locked-S east walks this suite pinned are retired.)

const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")
const Walker := preload("res://scenes/world/crosshaven/crosshaven_walker.gd")
const Specs := preload("res://units/pc_character_specs.gd")
const Painted := preload("res://units/painted_looks.gd")
const PAWN_SCENE := preload("res://units/pawn.tscn")
const MOTION := preload("res://units/view_motion.gd")

const CLASSES: Array[String] = ["bastion", "gloam", "ironjaw", "kestrel", "mender"]
const KINDS: Array[String] = ["walk", "idle", "attack", "skill", "hit", "death"]
## Lock commits (short) of each class's walk and actions.
const LOCKS := {
	"bastion": ["7f65035", "b50c598"],
	"kestrel": ["d08e0b7", "0227894"],
	"gloam": ["bdf0ff3", "94891db"],
	"mender": ["08ea869", "0afabd7"],
	"ironjaw": ["0f3eeb8", "9d784a1"],
}
## #271 hero speeds (crosshaven_walker speed_of), px/s.
const WALK_SPEED := 55.1034
const RUN_SPEED := 109.593

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	MOTION.set_reduce_motion(false)
	_test_specs()
	_test_world_strips()
	_test_no_skate()
	_test_ironjaw_v7()
	for cls in CLASSES:
		await _test_dungeon_pawn(cls)
	await _test_mirror_and_plain_pawn()
	MOTION.clear_reduce_motion()
	print("locked looks tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## Every class has every kind; sheets match the spec; cells stay under 256.
func _test_specs() -> void:
	for cls in CLASSES:
		check(Specs.SPECS.has(cls) and Specs.WORLD.has(cls), "%s has a painted spec" % cls)
		var locks: Array = LOCKS[cls]
		for kind in KINDS:
			var spec := Painted.spec(cls, kind)
			check(not spec.is_empty(), "%s %s is in the spec" % [cls, kind])
			var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
			check(cell.x > 0 and cell.y > 0 and cell.x <= Specs.MAX_CELL and cell.y <= Specs.MAX_CELL, "%s %s cell %s is within %d px" % [cls, kind, cell, Specs.MAX_CELL])
			var lock: String = locks[0] if kind == "walk" else locks[1]
			check(str(spec.get("source", "")).contains(lock), "%s %s reads the lock commit %s" % [cls, kind, lock])
			for art in ["S", "E"]:
				var tex := Painted.sheet(cls, kind, art)
				check(tex != null, "%s %s %s sheet loads" % [cls, kind, art])
				if tex != null:
					check(tex.get_width() == cell.x * int(spec["frames"]) and tex.get_height() == cell.y, "%s %s %s sheet is frames x cell" % [cls, kind, art])
		check(Painted.impact_frame(cls, "attack") > 0 and Painted.impact_frame(cls, "skill") > 0, "%s attack and skill have an impact cell" % cls)
		check(Painted.frame_count(cls, "walk") == 12 and Painted.frame_count(cls, "idle") == 12, "%s walk and idle are 12 cells" % cls)
		check(Painted.frame_count(cls, "hit") == 8 and Painted.frame_count(cls, "death") == 13, "%s hit is 8 cells, death 13" % cls)


## World: walk, run and idle in all four facings for every class.
func _test_world_strips() -> void:
	for cls in CLASSES:
		var strips = Strips.new()
		strips.load_class(cls)
		for gait in ["walk", "run", "idle"]:
			check(strips.has_gait(gait), "%s world %s loads" % [cls, gait])
			for dir in ["n", "e", "s", "w"]:
				check(strips.texture(gait, dir) != null, "%s world %s %s has a sheet" % [cls, gait, dir])
				check(strips.frame_count(gait, dir) == 12, "%s world %s %s is 12 cells" % [cls, gait, dir])
		check(not strips.flipped("e") and not strips.flipped("n"), "%s e and n draw the sheets as painted" % cls)
		check(strips.flipped("s") and strips.flipped("w"), "%s s and w draw the mirrors" % cls)
		check(strips.texture("walk", "e") == Painted.sheet(cls, "walk", "S"), "%s world e is the art S (front, down-right)" % cls)
		check(strips.texture("walk", "n") == Painted.sheet(cls, "walk", "E"), "%s world n is the art E (back, up-right)" % cls)
		check(strips.texture("run", "s") == strips.texture("walk", "s"), "%s run is the walk sheet" % cls)
		check(strips.texture("idle", "e") == Painted.sheet(cls, "idle", "S"), "%s idle is the painted idle" % cls)
		check(is_equal_approx(strips.fps_of("idle"), Specs.AUTHORED_FPS), "%s idle loops at 17.144 fps" % cls)
		var h: float = strips.height()
		check(h > 50.0 and h <= 62.71, "%s stands %.1f px at zoom 1 (Ironjaw is the old hero's 62.7)" % [cls, h])
		var foot := Vector2(strips.frame_size_of("walk", "e")) * 0.5 - strips.draw_pivot("walk", "e")
		check(foot.is_equal_approx(Vector2(Painted.pivot_of(cls, "walk", "e"))), "%s draw pivot puts the painted ground point on the node" % cls)
	var iron = Strips.new()
	iron.load_class("ironjaw")
	check(is_equal_approx(iron.height(), 62.7), "Ironjaw keeps the old hero height")


## World: at the #271 hero paces the shown stride is the painted foot's own
## travel (no skate), unless the leg rate hits the cap; then the stride grows
## (natural leg speed, a small slide) and never falls short of the foot.
func _test_no_skate() -> void:
	for cls in CLASSES:
		var strips = Strips.new()
		strips.load_class(cls)
		var foot: float = strips.foot_stride()
		check(foot > 1.0, "%s has a measured foot stride (%.2f px)" % [cls, foot])
		for gait in ["walk", "run"]:
			var count := float(strips.frame_count(gait))
			var speed: float = strips.speed_of(gait) * Walker.pace_scale(gait)
			var shown_fps: float = strips.fps_of(gait) * Walker.anim_scale(gait)
			var shown_stride: float = strips.stride_of(gait) * Walker.stride_scale(gait)
			var want := RUN_SPEED if gait == "run" else WALK_SPEED
			var cap := (Specs.RUN_LEG_RATE if gait == "run" else Specs.MAX_LEG_RATE) * Specs.AUTHORED_FPS
			check(absf(speed - want) < 0.01, "%s %s keeps the hero pace %.2f px/s (%.3f)" % [cls, gait, want, speed])
			check(absf(speed * count / shown_fps - shown_stride) < 0.001, "%s %s: one cycle covers one shown stride" % [cls, gait])
			check(shown_fps <= cap + 0.001, "%s %s legs stay at or under %.2f fps (%.2f)" % [cls, gait, cap, shown_fps])
			check(shown_stride >= foot - 0.01, "%s %s stride never falls short of the foot (no moonwalk)" % [cls, gait])
			if shown_fps < cap - 0.01:
				check(absf(shown_stride - foot) < 0.01 * foot, "%s %s: stride is the foot's travel, no skate (%.2f vs %.2f)" % [cls, gait, shown_stride, foot])
			else:
				check(absf(shown_fps - cap) < 0.01, "%s %s: leg rate capped at natural leg speed" % [cls, gait])
		check(strips.fps_of("run") * Walker.anim_scale("run") > strips.fps_of("walk") * Walker.anim_scale("walk"), "%s run legs are faster than the walk" % cls)
	# Ironjaw's long v7 stride fits both gaits under the caps: no skate at all.
	var iron = Strips.new()
	iron.load_class("ironjaw")
	for gait in ["walk", "run"]:
		var shown_stride: float = iron.stride_of(gait) * Walker.stride_scale(gait)
		check(absf(shown_stride - iron.foot_stride()) < 0.01, "Ironjaw %s has no foot slide" % gait)


## Ironjaw is the dark-steel HD walk v7, cleaned.
func _test_ironjaw_v7() -> void:
	var src := str(Painted.spec("ironjaw", "walk").get("source", ""))
	check(src.contains("ironjaw_walk/v7") and src.contains("0f3eeb8"), "Ironjaw walks on the dark-steel v7 (%s)" % src)
	check(src.contains("art/ironjaw-walk-help"), "Ironjaw v7 is read from art/ironjaw-walk-help")
	check(str(Painted.spec("ironjaw", "attack").get("source", "")).contains("claude/ironjaw-actions"), "Ironjaw actions are the locked dark-steel set")
	var build := FileAccess.get_file_as_string("res://build_tools/pc_characters/build_pc_characters.py")
	check(build.contains("\"clean\": True") and build.contains("def clean_frame"), "the build cleans the v7 pin holes and dark edge")
	var gone := not ResourceLoader.exists("res://art/characters/world/ironjaw_tall/ironjaw_tall_walk_e.png") and not FileAccess.file_exists("res://art/characters/world/ironjaw_tall/ironjaw_tall.json")
	check(gone, "ironjaw_tall is retired")
	check(not FileAccess.file_exists("res://art/characters/world/ironjaw/ironjaw.json"), "the old Ironjaw world strips are retired")


func _hero(cls: String, painted: bool = true) -> Pawn:
	var pawn: Pawn = PAWN_SCENE.instantiate()
	pawn.painted_look = painted
	root.add_child(pawn)
	pawn.apply_snapshot({"pos": Vector2i(3, 3), "name": "Hero", "class_id": cls, "facing": "E", "seat": 0, "hp": 60, "max_hp": 60, "alive": true}, 0)
	return pawn


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shows(pawn: Pawn, anim: String) -> bool:
	var strip := pawn._active_strip
	if strip == null or not is_instance_valid(strip) or not strip.visible:
		return false
	if str(strip.animation) != anim:
		return false
	var tex := strip.sprite_frames.get_frame_texture(strip.animation, 0)
	return Painted.is_painted_cell(tex) and strip.offset.is_equal_approx(Pawn.texture_pivot_offset(tex))


## Dungeon hero: each painted action plays on its trigger.
func _test_dungeon_pawn(cls: String) -> void:
	var pawn := _hero(cls)
	await _frames(2)
	check(pawn.uses_painted_look(), "%s pawn uses the painted look" % cls)
	var idle := Painted.cells(cls, "idle", "e")
	check(idle.has(pawn._sprite.texture), "%s stands on the painted idle" % cls)
	check(pawn._sprite.offset.is_equal_approx(Pawn.texture_pivot_offset(pawn._sprite.texture)), "%s idle stands on its ground point" % cls)
	# The idle loops while standing.
	var seen := {}
	for i in 30:
		seen[pawn._sprite.texture] = true
		await create_timer(0.03).timeout
	check(seen.size() > 2, "%s idle loops through its cells (%d seen)" % [cls, seen.size()])
	# Walk: the board's path walk.
	pawn.begin_path_walk()
	await _frames(2)
	check(_shows(pawn, "walk_e"), "%s walks on the painted walk" % cls)
	check(is_equal_approx(pawn._active_strip.speed_scale, Painted.pawn_walk_speed_scale(cls, Pawn.WALK_TILE_SEC)), "%s walk plays frames_per_tile cells per tile" % cls)
	var leg := pawn._active_strip.speed_scale * Specs.AUTHORED_FPS
	check(leg <= Specs.MAX_LEG_RATE * Specs.AUTHORED_FPS + 0.01, "%s pawn legs stay under natural leg speed (%.1f fps)" % [cls, leg])
	await create_timer(0.15).timeout
	check(pawn._active_strip.position == Vector2.ZERO, "%s painted walk has no hop on top" % cls)
	pawn.end_path_walk()
	pawn.release_idle()
	# Attack (melee spell).
	var sec := pawn.play_view_plan({"attack": true, "aim": Vector2(20, 10)})
	await _frames(2)
	check(sec > 0.0 and _shows(pawn, "attack_e"), "%s attack plays the painted attack" % cls)
	await create_timer(0.2).timeout
	check(pawn._active_strip.position == Vector2.ZERO, "%s painted attack has no lunge on top" % cls)
	check(pawn._active_strip.speed_scale > 0.0, "%s painted attack is not frozen on the impact" % cls)
	await create_timer(0.6).timeout
	pawn.settle_motion()
	check(idle.has(pawn._sprite.texture) and pawn._sprite.visible, "%s returns to the painted idle after the attack" % cls)
	# Skill (a cast).
	pawn.play_view_plan({"cast": true, "strip": "cast", "aim": Vector2(20, 10)})
	await _frames(2)
	check(_shows(pawn, "cast_e"), "%s cast plays the painted skill" % cls)
	await create_timer(0.7).timeout
	pawn.settle_motion()
	# Mark Shot (Kestrel) falls back to the painted bow attack.
	pawn.play_view_plan({"cast": true, "strip": "cast_mark"})
	await _frames(2)
	check(_shows(pawn, "attack_e"), "%s Mark Shot plays the painted attack" % cls)
	await create_timer(0.7).timeout
	pawn.settle_motion()
	# A damaging cast: Mender swings her lantern; the others keep the skill.
	pawn.play_view_plan({"cast": true, "strip": "cast", "strikes": true})
	await _frames(2)
	if cls == "mender":
		check(_shows(pawn, "attack_e"), "mender damaging cast swings the painted attack")
	else:
		check(_shows(pawn, "cast_e"), "%s damaging cast keeps the painted skill" % cls)
	await create_timer(0.7).timeout
	pawn.settle_motion()
	# Hit.
	pawn.play_view_plan({"hit": true, "away": Vector2(-20, -10)})
	await _frames(2)
	check(_shows(pawn, "hit_e"), "%s hit plays the painted hit" % cls)
	await create_timer(0.7).timeout
	pawn.settle_motion()
	# Death: plays the painted fall and holds its last cell.
	pawn.alive = false
	pawn.play_view_plan({"death": true})
	await _frames(2)
	check(_shows(pawn, "death_e"), "%s death plays the painted fall" % cls)
	await create_timer(1.2).timeout
	pawn.settle_motion()
	await _frames(2)
	var strip := pawn._active_strip
	check(strip != null and str(strip.animation) == "death_e" and strip.visible and strip.frame == strip.sprite_frames.get_frame_count("death_e") - 1, "%s stays down on the last death cell" % cls)
	pawn.queue_free()
	await _frames(1)


## Mirrored facings use the mirrored cells; a Koliseo pawn keeps its look.
func _test_mirror_and_plain_pawn() -> void:
	for cls in CLASSES:
		var e := Painted.cells(cls, "walk", "e")
		var s := Painted.cells(cls, "walk", "s")
		var a := e[3].get_image()
		var b := s[3].get_image()
		a.convert(Image.FORMAT_RGBA8)
		b.convert(Image.FORMAT_RGBA8)
		a.flip_x()
		check(a.get_data() == b.get_data(), "%s s cell 3 is the mirror of e cell 3" % cls)
		var pe: Vector2i = Painted.pivot_of(cls, "attack", "e")
		var ps: Vector2i = Painted.pivot_of(cls, "attack", "s")
		check(ps.x == Painted.cell_of(cls, "attack").x - pe.x and ps.y == pe.y, "%s mirrored pivot flips x" % cls)
	var hero := _hero("gloam")
	hero.set_facing("S")
	await _frames(1)
	check(Painted.cells("gloam", "idle", "s").has(hero._sprite.texture), "facing S (down-left) stands on the mirrored idle")
	hero.queue_free()
	var plain := _hero("kestrel", false)
	await _frames(1)
	check(not plain.uses_painted_look(), "a Koliseo pawn is not painted")
	check(plain._sprite.texture == Pawn.sprite_texture("kestrel", "E"), "a Koliseo pawn keeps its static look")
	check(plain._sprite.offset == Pawn.SPRITE_OFFSET, "a Koliseo pawn keeps the static pivot")
	plain.queue_free()
	await _frames(1)
