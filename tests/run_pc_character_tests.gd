extends SceneTree

## L10 PC character sets. Ironjaw v2 and Kestrel v3 only.
## Run: godot --headless --path . -s res://tests/run_pc_character_tests.gd

const CHARS := preload("res://units/pc/pc_characters.gd")
const WALKER := preload("res://scenes/pc/pc_world_walker.gd")
const LOOK := preload("res://board/pc/look_light.gd")

const SIM_SHA := "51c03ba6ee69b35b27fc21305b6ba87656e91aafeed0d9f45fefff4b5e3dc198"
const KITS_SHA := "cd0ec1b63098fab037a7e78cbdeca112cccf8a698b52aaa2fb996bd5080111ef"
const CLASS_JSON_SHA := "c24d39781a86426465d020535fb6f77ff6d283644943a54bbd034f401094a5bf"

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_pawn_pivots_and_distance_walk()
	await _test_phone_path_unchanged()
	Pawn.set_pc_walk_tile_sec(-1.0)
	CombatHUD.set_pc_chrome_override(-1)
	LOOK.active = false
	print("PC character tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	CombatHUD.set_pc_chrome_override(1)
	_test_remap_and_baked_files()
	_test_pivots_from_json()
	_test_distance_formula()
	_test_unshipped_classes_stay()
	_test_walk_setting_and_sources()
	_test_combat_sim_untouched()
	_test_imports()


func _test_remap_and_baked_files() -> void:
	for class_id in ["ironjaw", "kestrel"]:
		eq(CHARS.art_facing(class_id, "E"), "S", "%s code e is art S" % class_id)
		eq(CHARS.art_facing(class_id, "S"), "W", "%s code s is art W" % class_id)
		eq(CHARS.art_facing(class_id, "N"), "E", "%s code n is art E" % class_id)
		eq(CHARS.art_facing(class_id, "W"), "N", "%s code w is art N" % class_id)
		for code in ["N", "E", "S", "W"]:
			var path := CHARS.frame_path(class_id, code, "walk", 0)
			var art := CHARS.art_facing(class_id, code)
			truthy(path.contains("_%s_" % art), "%s walk %s file is the baked %s facing" % [class_id, code, art])
			eq(_images_match(path), true, "%s walk %s pixels are the file on disk" % [class_id, code])
		var bank := CHARS.frames_for(class_id)
		truthy(bank != null and bank.has_animation("walk_e"), "%s walk_e exists" % class_id)
		var shown: Texture2D = bank.get_frame_texture("walk_e", 0)
		var disk := CHARS.frame_texture(class_id, "E", "walk", 0)
		eq(shown, disk, "%s walk_e is the art S frame, not a runtime mirror" % class_id)
	var iron_w := CHARS.frame_path("ironjaw", "S", "walk", 11)
	truthy(iron_w.ends_with("ironjaw_walk_W_f11.png"), "ironjaw code s uses the pre-flipped W file")
	var kestrel_w := CHARS.frame_path("kestrel", "S", "attack", 0)
	truthy(kestrel_w.ends_with("kestrel_attack_W_f00.png"), "kestrel code s uses the painted W file")
	eq(_is_flip_of(CHARS.frame_path("kestrel", "E", "idle", 0), CHARS.frame_path("kestrel", "S", "idle", 0)), false, "kestrel W is not a flip of S")
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	eq(pawn_src.contains("flip_h = true"), false, "pawn never assigns flip_h true")
	var walker_src := FileAccess.get_file_as_string("res://scenes/pc/pc_world_walker.gd")
	eq(walker_src.contains("flip_h = true"), false, "the world walker never assigns flip_h true")


func _test_pivots_from_json() -> void:
	for class_id in ["ironjaw", "kestrel"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/pc/characters/%s/%s.json" % [class_id, class_id]))
		var states: Dictionary = data["states"]
		for state in states.keys():
			var faces: Dictionary = (states[state] as Dictionary)["facings"]
			for code in ["N", "E", "S", "W"]:
				var art := CHARS.art_facing(class_id, code)
				var raw: Array = (faces[art] as Dictionary)["offset"]
				var got := CHARS.offset_for(class_id, code, str(state))
				eq(got, Vector2(int(raw[0]), int(raw[1])), "%s %s %s offset is the json use value" % [class_id, state, code])
	eq(CHARS.offset_for("kestrel", "E", "walk"), Vector2(-68, -145), "kestrel walk S pivot is the verified walk pivot")
	eq(CHARS.offset_for("kestrel", "E", "idle"), Vector2(-68, -141), "kestrel idle S pivot stays the idle pivot")
	eq(CHARS.offset_for("ironjaw", "E", "death"), Vector2(-102, -133), "ironjaw death pivot is the wider cell")
	eq(CHARS.offset_for("kestrel", "S", "death"), Vector2(-158, -141), "kestrel death pivot is the death cell")
	eq(is_equal_approx(CHARS.combat_scale("kestrel"), 0.465), true, "kestrel draw scale is 0.465")
	eq(is_equal_approx(CHARS.world_scale("kestrel"), 0.4278), true, "kestrel world scale is draw scale times 0.92")
	eq(is_equal_approx(CHARS.board_px_per_frame("kestrel", "E"), 4.99875), true, "kestrel walk step is board px at draw scale")
	eq(CHARS.head_hp_y("ironjaw"), -80.0, "ironjaw v2 plate sits at -80 until v3.1 art lands")
	eq(CHARS.head_hp_y("kestrel"), -74.0, "kestrel plate sits at -74")
	eq(Pawn.HEAD_HP_Y, -76.0, "the shipped plate constant stays -76")


func _test_distance_formula() -> void:
	eq(CHARS.walk_frame_index("ironjaw", "E", 0.0, 0.5), 0, "zero distance is frame 0")
	eq(CHARS.walk_frame_index("ironjaw", "E", 20.0, 0.5), 5, "ironjaw frame follows board distance")
	eq(CHARS.walk_frame_index("ironjaw", "W", 44.6, 0.5), 0, "one ironjaw cycle returns to frame 0")
	eq(is_equal_approx(CHARS.travel_cell_px("kestrel", "E"), 129.0), true, "kestrel art S travel is 129")
	var kest_draw := CHARS.combat_scale("kestrel")
	var kest_per := CHARS.board_px_per_frame("kestrel", "E")
	eq(CHARS.walk_frame_index("kestrel", "E", kest_per * 12.0, kest_draw), 0, "one kestrel cycle returns to frame 0")
	var kest_world := CHARS.world_scale("kestrel")
	var world_per := kest_per * kest_world / kest_draw
	eq(CHARS.walk_frame_index("kestrel", "S", world_per * 3.5, kest_world), 3, "world scale uses the same travel")


func _test_unshipped_classes_stay() -> void:
	for class_id in ["gloam", "bastion", "mender"]:
		eq(CHARS.has_set(class_id), false, "%s has no PC set yet" % class_id)
		eq(CHARS.uses_body(class_id), false, "%s stays on the shipped body" % class_id)
		eq(Pawn.sprite_path(class_id, "S"), "res://art/characters/%s/%s_s.png" % [class_id, class_id], "%s portrait stays the shipped file" % class_id)
	var select := load("res://scenes/class_select.gd")
	eq(select.portrait_path("ironjaw"), CHARS.frame_path("ironjaw", "S", "idle", 0), "the class picker uses the PC idle frame")
	eq(select.portrait_path("gloam"), "res://art/characters/gloam/gloam_s.png", "gloam picker stays shipped")
	var bar := FileAccess.get_file_as_string("res://ui/pc/action_bar.gd")
	truthy(bar.contains("Pawn.sprite_path"), "the action bar portrait goes through sprite_path")


func _test_walk_setting_and_sources() -> void:
	eq(Pawn.WALK_TILE_SEC, 0.22, "the shipped tile time stays 0.22")
	Pawn.set_pc_walk_tile_sec(-1.0)
	eq(is_equal_approx(Pawn.walk_tile_sec(), 0.22), true, "PC walk defaults to 0.22")
	Pawn.set_pc_walk_tile_sec(0.42)
	eq(is_equal_approx(Pawn.walk_tile_sec(), 0.42), true, "the PC setting slows the combat walk")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("Pawn.WALK_TILE_SEC"), "the board still names the shipped tile time")
	truthy(view.contains("walk_tile_sec()"), "the board reads the PC tile time")
	truthy(view.contains("uses_pc_chrome()"), "the slower walk is PC only")
	truthy(view.contains("note_walk_distance"), "the glide reports distance")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	var light := FileAccess.get_file_as_string("res://scenes/pc/pc_world_light.gdshader")
	truthy(light.contains("warm_mul"), "world light is the warm multiply")
	truthy(light.contains("1.06"), "world light saturation is 1.06")


func _test_combat_sim_untouched() -> void:
	eq(_sha256("res://backend/combat_sim.gd"), SIM_SHA, "CombatSim bytes are unchanged")
	eq(_sha256("res://data/kits.gd"), KITS_SHA, "kits.gd bytes are unchanged")
	eq(_sha256("res://data/select_class_lock_kits_v0.6.json"), CLASS_JSON_SHA, "class json bytes are unchanged")
	for path in ["res://backend/combat_sim.gd", "res://data/kits.gd", "res://data/select_class_lock_kits_v0.6.json"]:
		var text := FileAccess.get_file_as_string(path)
		eq(text.contains("art/pc/characters"), false, "%s does not name the PC art" % path)
		eq(text.contains("PcCharacters"), false, "%s does not name the PC loader" % path)


func _test_imports() -> void:
	var samples := [
		CHARS.frame_path("ironjaw", "E", "walk", 0),
		CHARS.frame_path("ironjaw", "S", "attack", 2),
		CHARS.frame_path("kestrel", "E", "cast", 0),
		CHARS.frame_path("kestrel", "W", "death", 5),
	]
	for path in samples:
		var imported := FileAccess.get_file_as_string(path + ".import")
		truthy(imported.contains("mipmaps/generate=false"), "%s mipmaps off" % path)
		truthy(imported.contains("compress/mode=0"), "%s lossless" % path)
		truthy(imported.contains("process/fix_alpha_border=true"), "%s fix alpha border" % path)
		truthy(imported.contains("process/premult_alpha=false"), "%s straight alpha" % path)


func _test_pawn_pivots_and_distance_walk() -> void:
	CombatHUD.set_pc_chrome_override(1)
	LOOK.active = true
	var iron := _pawn("ironjaw", "E", 0)
	await process_frame
	var sprite := iron.get_node("Sprite") as Sprite2D
	eq(sprite.centered, false, "ironjaw is uncentered")
	eq(sprite.flip_h, false, "ironjaw idle does not flip")
	eq(sprite.offset, CHARS.offset_for("ironjaw", "E", "idle"), "ironjaw idle offset is the json pivot")
	eq(sprite.scale, Vector2(0.5, 0.5), "ironjaw combat scale stays 0.5")
	eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "ironjaw filters linear")
	eq(is_equal_approx(iron.head_hp_y(), -80.0), true, "ironjaw head y is -80")
	var plate := iron.get_node("Chrome/OverheadPlate") as OverheadPlate
	eq(is_equal_approx(plate.bar_rect().position.y, -80.0), true, "ironjaw plate reads the class head y")
	var rim := _rim(iron)
	truthy(rim != null, "the L7 rim follows the ironjaw body")
	if rim != null:
		eq(rim.flip_h, false, "the rim does not flip")
		eq(rim.centered, false, "the rim uses the uncentered pivot")
	iron.play_view_plan({"attack": true, "aim": Vector2(20, 10)})
	var attack := _visible_strip(iron)
	truthy(attack != null, "ironjaw attack plays a strip")
	if attack != null:
		eq(String(attack.animation), "attack_e", "ironjaw attack uses code e")
		eq(attack.flip_h, false, "ironjaw attack does not flip")
		eq(attack.offset, CHARS.offset_for("ironjaw", "E", "attack"), "ironjaw attack offset is the json pivot")
		eq(attack.centered, false, "ironjaw attack is uncentered")
	iron._start_kind_strip("death", 0.4)
	var death := _visible_strip(iron)
	truthy(death != null, "ironjaw death plays a strip")
	if death != null:
		eq(death.offset, Vector2(-102, -133), "ironjaw death uses the death pivot")
		eq(death.flip_h, false, "ironjaw death does not flip")
	iron.free()

	var kest := _pawn("kestrel", "E", 1)
	await process_frame
	eq(is_equal_approx(kest.head_hp_y(), -74.0), true, "kestrel head y is -74")
	var kest_plate := kest.get_node("Chrome/OverheadPlate") as OverheadPlate
	eq(is_equal_approx(kest_plate.bar_rect().position.y, -74.0), true, "kestrel plate reads the class head y")
	kest.begin_path_walk()
	var walk := _visible_strip(kest)
	truthy(walk != null, "kestrel walk plays")
	if walk != null:
		eq(walk.frame, 0, "a walk starts on frame 0")
		eq(is_equal_approx(walk.speed_scale, 0.0), true, "PC walk does not advance on the clock")
		eq(walk.flip_h, false, "kestrel walk does not flip")
		eq(walk.offset, Vector2(-68, -145), "kestrel code e uses the walk S pivot")
		kest.note_walk_distance(20.0)
		var expected := CHARS.walk_frame_index("kestrel", "E", 20.0, CHARS.combat_scale("kestrel"))
		eq(walk.frame, expected, "kestrel walk frame follows distance")
		await create_timer(0.35).timeout
		eq(walk.frame, expected, "a third of a second does not change a distance frame")
		eq(is_equal_approx(walk.speed_scale, 0.0), true, "the clock stays stopped")
		kest.set_facing("S")
		kest.retarget_walk_strip()
		eq(String(walk.animation), "walk_s", "a facing change swaps the baked clip")
		eq(walk.frame, CHARS.walk_frame_index("kestrel", "S", 20.0, CHARS.combat_scale("kestrel")), "the distance frame survives the facing change")
		eq(walk.flip_h, false, "the facing change does not flip")
		eq(walk.offset, CHARS.offset_for("kestrel", "S", "walk"), "the new facing uses its own pivot")
	kest.free()

	for class_id in ["gloam", "bastion", "mender"]:
		var pawn := _pawn(class_id, "W", 0)
		var body := pawn.get_node("Sprite") as Sprite2D
		eq(body.centered, true, "%s stays centered" % class_id)
		eq(body.offset, Vector2(0, -72), "%s keeps the shipped foot offset" % class_id)
		eq(body.flip_h, false, "%s does not flip" % class_id)
		eq(is_equal_approx(pawn.head_hp_y(), -76.0), true, "%s plate stays at -76" % class_id)
		pawn.free()

	var walker := WALKER.new() as PcWorldWalker
	get_root().add_child(walker)
	eq(walker.setup("ironjaw"), true, "ironjaw builds a world walker")
	eq(is_equal_approx(walker.base_scale(), 0.46), true, "the walker scale is 0.46")
	var wsprite := walker.get_node("Sprite") as Sprite2D
	eq(wsprite.centered, false, "the walker is uncentered")
	eq(wsprite.flip_h, false, "the walker does not flip")
	eq(wsprite.offset, CHARS.offset_for("ironjaw", "E", "idle"), "the walker idle offset is the json pivot")
	eq(wsprite.scale, Vector2(0.46, 0.46), "the walker draws at world scale")
	eq(wsprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "the walker filters linear")
	truthy(wsprite.material is ShaderMaterial, "the walker takes the world light")
	var wrim := walker.get_node("Sprite/LookRim") as Sprite2D
	truthy(wrim != null, "the walker keeps the L7 rim")
	eq(wrim.flip_h, false, "the walker rim does not flip")
	eq(wrim.centered, false, "the walker rim follows the pivot")
	walker.set_travel_px(30.0)
	eq(walker.frame_index(), CHARS.walk_frame_index("ironjaw", "E", 30.0, 0.46), "walker frames follow distance")
	eq(wsprite.flip_h, false, "a walker step does not flip")
	walker.show_state("attack")
	eq(walker.state, "attack", "ironjaw walker can show attack")
	walker.free()

	var bow := WALKER.new() as PcWorldWalker
	get_root().add_child(bow)
	eq(bow.setup("kestrel"), true, "kestrel builds a world walker")
	bow.show_state("cast")
	eq(bow.state, "cast", "kestrel walker can show cast")
	eq((bow.get_node("Sprite") as Sprite2D).flip_h, false, "kestrel walker cast does not flip")
	eq(bow.setup("gloam"), false, "gloam has no world walker yet")
	bow.free()
	LOOK.active = false


func _test_phone_path_unchanged() -> void:
	CombatHUD.set_pc_chrome_override(0)
	Pawn.set_pc_walk_tile_sec(0.42)
	eq(is_equal_approx(Pawn.walk_tile_sec(), 0.22), true, "the phone ignores the PC walk setting")
	eq(CHARS.uses_body("ironjaw"), false, "the phone does not take the PC body")
	eq(CHARS.has_set("ironjaw"), true, "the files stay on disk for the PC path")
	var pawn := _pawn("ironjaw", "E", 0)
	await process_frame
	var sprite := pawn.get_node("Sprite") as Sprite2D
	eq(sprite.centered, true, "phone ironjaw stays centered")
	eq(sprite.offset, Vector2(0, -72), "phone ironjaw keeps the shipped offset")
	eq(sprite.scale, Vector2(0.5, 0.5), "phone ironjaw stays at 0.5")
	eq(sprite.flip_h, false, "phone ironjaw does not flip")
	eq(sprite.texture.get_width(), 144, "phone ironjaw is the 144-wide master")
	eq(Pawn.sprite_path("ironjaw", "E"), "res://art/characters/ironjaw/ironjaw_e.png", "phone path is the shipped file")
	var select := load("res://scenes/class_select.gd")
	eq(select.portrait_path("kestrel"), "res://art/characters/kestrel/kestrel_s.png", "phone picker stays shipped")
	pawn.begin_path_walk()
	var strip := _visible_strip(pawn)
	truthy(strip != null, "phone walk uses the export strip")
	if strip != null:
		eq(is_equal_approx(strip.speed_scale, 1.0), true, "phone walk advances on the clock")
		eq(strip.flip_h, false, "phone walk does not flip")
		var start := strip.frame
		await create_timer(0.3).timeout
		eq(strip.frame != start, true, "phone walk frame moves in 0.3s")
	eq(is_equal_approx(pawn.head_hp_y(), -76.0), true, "phone plate stays at -76")
	pawn.free()
	CombatHUD.set_pc_chrome_override(-1)
	Pawn.set_pc_walk_tile_sec(-1.0)


func _pawn(class_id: String, facing: String, seat: int) -> Pawn:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot({
		"pos": Vector2i(2, 2),
		"name": SpellKits.display_name(class_id),
		"class_id": class_id,
		"facing": facing,
		"seat": seat,
		"hp": 80,
		"max_hp": 80,
		"alive": true,
		"stun_remaining": 0,
	}, seat)
	return pawn


func _visible_strip(pawn: Node) -> AnimatedSprite2D:
	for child in pawn.get_children():
		if child is AnimatedSprite2D and (child as CanvasItem).visible:
			return child
	return null


func _rim(pawn: Node) -> Sprite2D:
	var stack: Array[Node] = [pawn]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Sprite2D and str(node.name) == "LookRim":
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func _images_match(path: String) -> bool:
	var disk := Image.new()
	if disk.load(path) != OK:
		return false
	var tex := load(path) as Texture2D
	if tex == null:
		return false
	var drawn := tex.get_image()
	if drawn == null:
		return false
	if drawn.get_size() != disk.get_size():
		return false
	# Fix-alpha-border repaints the transparent edge. An opaque body pixel stays.
	var at := Vector2i(disk.get_width() / 2, disk.get_height() / 2)
	for _try in 8:
		if disk.get_pixelv(at).a > 0.9:
			break
		at = Vector2i(at.x + 3, at.y + 2)
	return disk.get_pixelv(at).is_equal_approx(drawn.get_pixelv(at))


func _is_flip_of(a_path: String, b_path: String) -> bool:
	var a := Image.new()
	var b := Image.new()
	if a.load(a_path) != OK or b.load(b_path) != OK:
		return false
	if a.get_size() != b.get_size():
		return false
	b.flip_x()
	return a.get_data() == b.get_data()


func _sha256(path: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


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
