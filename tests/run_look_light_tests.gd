extends SceneTree

## L7 light. The phone path stays flat. PC grades, rims, and cast light are warm.
## Run: godot --headless --path . -s res://tests/run_look_light_tests.gd

const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const BUDGET := preload("res://vfx/vfx_budget.gd")
const NUMBER := preload("res://vfx/vfx_number.gd")
const SORT := preload("res://board/visual_sort.gd")
const JUNGLE := preload("res://board/pc/jungle_backdrop.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	LIGHT.set_outdoor_preset(LIGHT.PRESET_MEDIUM)
	_test_phone_stays_flat()
	_test_outdoor_grade_and_rim()
	_test_outdoor_strengths()
	_test_dungeon_grade()
	_test_cast_light_is_warm_and_pc_only()
	_test_damage_numbers()
	_test_pawn_rim_follows_strips()
	await _test_live_board()
	HUD.set_pc_chrome_override(-1)
	LIGHT.active = false
	LIGHT.set_suppressed(false)
	LIGHT.set_outdoor_preset(LIGHT.PRESET_MEDIUM)
	print("Look light tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _host() -> Dictionary:
	var host := Node.new()
	host.name = "Host"
	root.add_child(host)
	var hud = HUD.new()
	hud.name = "HUD"
	host.add_child(hud)
	var board := Node2D.new()
	board.name = "BoardView"
	host.add_child(board)
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	board.add_child(tiles)
	var tile := Node2D.new()
	tile.name = "Cell"
	tiles.add_child(tile)
	var jungle = JUNGLE.new()
	jungle.name = "JungleBackdrop"
	board.add_child(jungle)
	jungle._ensure_plate()
	var units := Node2D.new()
	units.name = "Units"
	board.add_child(units)
	var light = LIGHT.new()
	light.name = "LookLight"
	board.add_child(light)
	return {"host": host, "hud": hud, "board": board, "tiles": tiles, "tile": tile, "jungle": jungle, "units": units, "light": light}


func _test_phone_stays_flat() -> void:
	var tree := _host()
	var light = tree["light"]
	var hud: CanvasLayer = tree["hud"]
	eq(hud.layer, 10, "the real HUD starts at layer 10")
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	eq(hud.layer, 10, "PC grade does not move the HUD layer")
	HUD.set_pc_chrome_override(0)
	light.sync(tree["board"], true)
	eq(hud.layer, 10, "the phone path leaves the real HUD layer alone")
	eq(light.wash_visible(), false, "the phone path has no grade")
	eq(light.vignette_visible(), false, "the phone path has no dungeon vignette")
	eq(tree["board"].modulate, Color.WHITE, "the phone board is not tinted")
	eq(tree["tile"].material, null, "the phone tiles have no grade shader")
	eq(tree["jungle"].modulate, Color.WHITE, "the jungle node stays white")
	eq(tree["jungle"].look_grade_enabled(), false, "the phone jungle plate is not graded")
	eq(LIGHT.active, false, "the phone path does not dress fighters")
	eq(light.note_events([{"type": "cast", "spell": "drop_shade", "to": Vector2i(4, 4)}]), 0, "a phone cast does not add shafts")
	eq(light.cast_count(), 0, "the phone path keeps no cast light")
	_free_host(tree)


func _test_outdoor_grade_and_rim() -> void:
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	eq(light.wash_visible(), true, "the outdoor grade is on")
	eq(LIGHT.outdoor_preset, LIGHT.PRESET_MEDIUM, "medium is the interim outdoor default")
	eq(is_equal_approx(light.grade_saturation(), LIGHT.OUTDOOR_SAT), true, "outdoor saturation is the medium preset")
	truthy(light.grade_saturation() >= 1.12 and light.grade_saturation() <= 1.15, "outdoor saturation is about +12 to +15 percent")
	truthy(light.grade_contrast() > 1.02 and light.grade_contrast() < 1.12, "outdoor contrast is gentle")
	truthy(light.grade_shade() < 0.05, "outdoor grade does not recolor dark tiles")
	truthy(light.grade_bias().r > light.grade_bias().b, "the outdoor grade is warm")
	truthy(light.grade_bias().r < 0.04, "the warm shift stays slight")
	truthy(light.grade_bias().r - light.grade_bias().b < 0.05, "the warm shift is a few degrees")
	eq(tree["board"].modulate, Color.WHITE, "the grade is not a parent multiply")
	eq(tree["tiles"].modulate, Color.WHITE, "the tiles node is not a flat tint")
	eq(tree["units"].modulate, Color.WHITE, "fighters are not tinted as a group")
	var mat := tree["tile"].material as ShaderMaterial
	truthy(mat != null and mat.shader != null and mat.shader.code.find("l7_grade") >= 0, "the tile uses the grade shader")
	truthy(mat.shader.code.find("texture(TEXTURE") < 0, "a drawn tile is graded from its own color, not sampled twice")
	eq(tree["jungle"].modulate, Color.WHITE, "the jungle node stays white")
	eq(tree["jungle"].look_grade_enabled(), true, "the jungle plate takes the grade")
	var plate_code := ""
	var plate_mat: ShaderMaterial = tree["jungle"]._plate_mat
	if plate_mat != null and plate_mat.shader != null:
		plate_code = plate_mat.shader.code
	truthy(plate_code.find("blend_disabled") >= 0, "the jungle plate stays blend-disabled")
	truthy(plate_code.find("l7_grade") >= 0, "the jungle plate shader grades")
	truthy(plate_code.find("grade_shade") >= 0, "the jungle plate can keep the shadow mix off")
	eq(is_equal_approx(float(plate_mat.get_shader_parameter("grade_sat")), LIGHT.OUTDOOR_SAT), true, "the jungle plate uses the outdoor saturation")
	eq(is_equal_approx(float(plate_mat.get_shader_parameter("grade_shade")), LIGHT.OUTDOOR_SHADE), true, "the jungle plate does not crush shadows")
	eq(light.vignette_visible(), false, "outdoors do not vignette the room")
	eq(light.get_node_or_null("Vignette"), null, "outdoors do not add a fullscreen wash")
	var rim: Color = light.rim_color()
	truthy(rim.r > rim.b, "the outdoor rim is warm")
	eq(is_equal_approx(light.rim_strength(), LIGHT.OUTDOOR_RIM_STRENGTH), true, "outdoor rim strength")
	truthy(LIGHT.SHAFT_COLOR.r > LIGHT.SHAFT_COLOR.b and LIGHT.SHAFT_COLOR.a > 0.6, "shafts are warm and readable")
	truthy(LIGHT.FLOOR_COLOR.r > LIGHT.FLOOR_COLOR.g and LIGHT.FLOOR_COLOR.a > 0.5, "the floor pool is warm and readable")
	truthy(LIGHT.POOL_RX >= 64.0, "the pool is wider than a fighter")
	_free_host(tree)


func _test_outdoor_strengths() -> void:
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	LIGHT.set_outdoor_preset(LIGHT.PRESET_LIGHT)
	light.sync(tree["board"], false)
	eq(is_equal_approx(light.grade_saturation(), LIGHT.LIGHT_SAT), true, "light saturation is +10 percent")
	truthy(light.grade_saturation() < LIGHT.OUTDOOR_SAT, "light is softer than medium")
	truthy(light.grade_contrast() > 1.0 and light.grade_contrast() < 1.10, "light contrast is gentle")
	truthy(light.grade_shade() < 0.05, "light does not recolor shadows")
	truthy(light.grade_bias().r > light.grade_bias().b, "light is still warm")
	LIGHT.set_outdoor_preset(LIGHT.PRESET_STRONG)
	light.sync(tree["board"], false)
	eq(is_equal_approx(light.grade_saturation(), LIGHT.STRONG_SAT), true, "strong keeps the rejected saturation")
	eq(is_equal_approx(light.grade_contrast(), LIGHT.STRONG_CONTRAST), true, "strong keeps the rejected contrast")
	truthy(light.grade_shade() > 0.4, "strong still mixes the old shadow")
	truthy(light.grade_bias().r > 0.05, "strong keeps the heavy warm bias")
	var plate_mat: ShaderMaterial = tree["jungle"]._plate_mat
	eq(is_equal_approx(float(plate_mat.get_shader_parameter("grade_sat")), LIGHT.STRONG_SAT), true, "the jungle plate follows the strong preset")
	light.sync(tree["board"], true)
	eq(is_equal_approx(light.grade_saturation(), LIGHT.DUNGEON_SAT), true, "a dungeon sync ignores the outdoor preset")
	eq(is_equal_approx(light.grade_contrast(), LIGHT.DUNGEON_CONTRAST), true, "dungeon contrast stays the accepted grade")
	eq(is_equal_approx(light.grade_shade(), LIGHT.DUNGEON_SHADE), true, "dungeon shadow mix stays")
	LIGHT.set_outdoor_preset(LIGHT.PRESET_MEDIUM)
	light.sync(tree["board"], false)
	eq(is_equal_approx(light.grade_saturation(), LIGHT.OUTDOOR_SAT), true, "medium restores the interim outdoor grade")
	_free_host(tree)


func _test_dungeon_grade() -> void:
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	var outdoor_gain: float = light.grade_gain()
	light.sync(tree["board"], true)
	truthy(light.grade_contrast() > 1.2, "the dungeon grade raises contrast")
	truthy(light.grade_gain() < outdoor_gain, "the dungeon grade is darker than outdoors")
	truthy(light.grade_bias().b > light.grade_bias().r, "the dungeon grade is cool")
	eq(light.wash_visible(), true, "the dungeon grade is on")
	eq(tree["jungle"].look_grade_enabled(), true, "the dungeon still grades the jungle plate")
	eq(light.vignette_visible(), true, "the dungeon vignettes the room")
	truthy(light.rim_strength() > LIGHT.OUTDOOR_RIM_STRENGTH, "the dungeon rim is stronger")
	truthy(light.rim_color().r > light.rim_color().b, "the dungeon rim stays warm")
	_free_host(tree)


func _test_cast_light_is_warm_and_pc_only() -> void:
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	eq(light.note_events([{"type": "burn", "damage": 4, "to": Vector2i(1, 1)}]), 0, "a burn tick is not a cast")
	eq(light.note_events([{"type": "hit", "spell": "strike", "damage": 16, "to": Vector2i(8, 7)}]), 0, "a plain hit does not add shafts")
	eq(light.note_events([{"type": "miss", "spell": "strike", "to": Vector2i(8, 7)}]), 0, "a miss does not add shafts")
	eq(light.note_events([{
		"type": "cast",
		"spell": "drop_shade",
		"to": Vector2i(3, 4),
	}]), 1, "a cast adds shafts and a floor pool")
	eq(light.cast_count(), 1, "one cast is live")
	var tint: Color = light.cast_tint()
	truthy(tint.r > tint.b, "a Gloam cast stays a warm pool, not a violet beam")
	var at: Vector2 = light.cast_at()
	eq(is_equal_approx(at.y, 4.0 + LIGHT.POOL_OFFSET.y), true, "the pool sits on the target cell, in front of the feet")
	var cell := Vector2i(3, 4)
	truthy(light.z_index < SORT.unit_z_index(cell, 0.0), "the pool draws under the fighter")
	truthy(light.z_index > SORT.tile_z_index(cell, 0.0), "the pool draws on the cell floor")
	HUD.set_pc_chrome_override(0)
	light.sync(tree["board"], false)
	eq(light.cast_count(), 0, "leaving PC clears the cast light")
	_free_host(tree)


func _test_damage_numbers() -> void:
	var number = NUMBER.new()
	root.add_child(number)
	HUD.set_pc_chrome_override(0)
	number.play({"text": "16", "kind": "damage"})
	number._draw()
	eq(number._text, "16", "the phone number is the event text")
	eq(number._font_size, BUDGET.NUMBER_SIZE, "the phone damage number keeps the small size")
	eq(number._drawn_size, BUDGET.NUMBER_SIZE, "the phone draw uses the small size")
	eq(number._drawn_spread, 4, "the phone outline stays the small spread")
	HUD.set_pc_chrome_override(1)
	number.play({"text": "16", "kind": "damage"})
	number._draw()
	eq(number._text, "16", "the PC number is still the event text")
	eq(number._font_size, LIGHT.PC_DAMAGE_FONT, "PC damage numbers are bigger")
	eq(number._drawn_size, LIGHT.PC_DAMAGE_FONT, "the PC draw uses the bigger size")
	eq(number._drawn_spread, 6, "the PC outline uses the bigger spread")
	truthy(LIGHT.PC_DAMAGE_FONT > BUDGET.NUMBER_SIZE, "the PC size is above the phone size")
	number.play({"text": "10", "kind": "heal"})
	number._draw()
	eq(number._drawn_size, BUDGET.NUMBER_SIZE, "heals stay the small size")
	number.free()


func _test_pawn_rim_follows_strips() -> void:
	var tree := _host()
	var light = tree["light"]
	var pawn = (load("res://units/pawn.gd") as GDScript).new()
	pawn.class_id = "kestrel"
	pawn.facing = "E"
	pawn.alive = true
	tree["units"].add_child(pawn)
	HUD.set_pc_chrome_override(0)
	light.sync(tree["board"], false)
	pawn._sync_sprite()
	var sprite := pawn.get_node("Sprite") as Sprite2D
	eq(sprite.get_node_or_null("LookRim"), null, "the phone fighter has no rim")
	eq(pawn.get_node_or_null("LookRim"), null, "the phone pawn has no rim")
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	pawn._sync_sprite()
	var rim := sprite.get_node_or_null("LookRim") as Sprite2D
	truthy(rim != null and rim.visible, "the PC fighter takes the rim")
	truthy(rim.modulate.r > rim.modulate.b, "the rim is warm")
	var plate := pawn.get_node_or_null("Chrome/OverheadPlate") as CanvasItem
	truthy(plate != null, "the name plate exists")
	if plate != null:
		eq(plate.material, null, "the name plate is not graded")
	eq(bool(sprite.get_meta("_look_grade_mat", false)), true, "the body takes the grade shader")
	pawn.bind_motion_frames(_frames(["walk_e", "cast_e"]))
	var walked: bool = pawn._play_walk_flat()
	eq(walked, true, "the walk strip plays")
	eq(sprite.visible, false, "the walk strip hides the static sprite")
	var walk_rim := _find_rim(pawn)
	truthy(walk_rim != null and walk_rim.visible, "the rim stays visible during the walk")
	if walk_rim != null:
		eq(walk_rim.get_parent(), pawn._active_strip, "the walk rim is parented to the walk strip")
	pawn.settle_motion()
	pawn._begin_body_strip("cast", 0.4)
	eq(sprite.visible, false, "the cast strip hides the static sprite")
	var cast_rim := _find_rim(pawn)
	truthy(cast_rim != null and cast_rim.visible, "the rim stays visible during the cast")
	if cast_rim != null:
		eq(cast_rim.get_parent(), pawn._active_strip, "the cast rim is parented to the cast strip")
	pawn.alive = false
	light.sync(tree["board"], false)
	eq(cast_rim.visible, false, "a downed fighter drops the rim")
	_free_host(tree)


func _test_live_board() -> void:
	HUD.set_pc_chrome_override(1)
	LIGHT.set_suppressed(false)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node = main.get_node("BoardView")
	var hud: CanvasLayer = main.get_node("HUD")
	for _i in 50:
		await process_frame
		if bool(board.get("_booted")):
			break
	eq(bool(board.get("_booted")), true, "the live board boots")
	var sim: Node = root.get_node("CombatSim")
	sim.reset_match({
		"seed": 1,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	await process_frame
	eq(hud.layer, 10, "the live HUD stays at layer 10")
	var light = board.get_node_or_null("LookLight")
	truthy(light != null and light.wash_visible(), "the live board wires the grade")
	var jungle = board.get_node_or_null("JungleBackdrop")
	truthy(jungle != null and jungle.look_grade_enabled(), "the live jungle plate is graded")
	var graded_body := false
	var plate_clean := false
	for pawn in board.get_node("Units").get_children():
		var plate := pawn.get_node_or_null("Chrome/OverheadPlate") as CanvasItem
		if plate != null:
			eq(plate.material, null, "a live name plate is not graded")
			plate_clean = true
		var sprite := pawn.get_node_or_null("Sprite") as CanvasItem
		if sprite != null and bool(sprite.get_meta("_look_grade_mat", false)):
			graded_body = true
	eq(plate_clean, true, "a live fighter has a name plate")
	eq(graded_body, true, "a live fighter body is graded")
	HUD.set_pc_chrome_override(0)
	board._sync_look_light()
	eq(hud.layer, 10, "phone sync leaves the live HUD layer")
	eq(light.wash_visible(), false, "phone sync clears the live grade")
	eq(light.vignette_visible(), false, "phone sync clears the vignette")
	main.free()
	HUD.set_pc_chrome_override(-1)


func _frames(anims: Array) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.2, 0.1, 1))
	var tex := ImageTexture.create_from_image(image)
	for anim in anims:
		frames.add_animation(str(anim))
		frames.set_animation_speed(str(anim), 8.0)
		frames.set_animation_loop(str(anim), true)
		frames.add_frame(str(anim), tex)
		frames.add_frame(str(anim), tex)
	return frames


func _find_rim(node: Node) -> Sprite2D:
	if node is Sprite2D and str(node.name) == "LookRim" and (node as CanvasItem).is_visible_in_tree():
		return node
	for child in node.get_children():
		var hit := _find_rim(child)
		if hit != null:
			return hit
	return null


func _free_host(tree: Dictionary) -> void:
	var host: Node = tree["host"]
	host.free()


func eq(got: Variant, want: Variant, label: String) -> void:
	if got == want:
		_passed += 1
		return
	_failed += 1
	print("FAIL %s got=%s want=%s" % [label, str(got), str(want)])


func truthy(got: bool, label: String) -> void:
	eq(got, true, label)
