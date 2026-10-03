extends SceneTree

## L7 light. The phone path stays flat. The outdoor grade ships off.
## Thunderwell matches the base board. Rims and the 68 px number stay.
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
	_test_phone_stays_flat()
	_test_outdoor_grade_and_rim()
	_test_thunderwell_board_stays_flat()
	_test_cast_light_is_warm_and_pc_only()
	_test_damage_numbers()
	_test_pawn_rim_follows_strips()
	await _test_live_board()
	await _test_thunderwell_board_matches_base()
	HUD.set_pc_chrome_override(-1)
	LIGHT.active = false
	LIGHT.set_suppressed(false)
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
	eq(LIGHT.OUTDOOR_STRENGTH, 0.0, "the outdoor grade ships at strength 0")
	eq(light.wash_visible(), false, "the outdoor grade is off")
	eq(is_equal_approx(light.grade_saturation(), 1.0), true, "outdoor saturation matches base")
	eq(is_equal_approx(light.grade_contrast(), 1.0), true, "outdoor contrast matches base")
	eq(is_equal_approx(light.grade_gain(), 1.0), true, "outdoor gain matches base")
	eq(is_equal_approx(light.grade_shade(), 0.0), true, "outdoor grade does not mix a shadow")
	eq(light.grade_bias(), Color(0, 0, 0, 1), "outdoor grade has no color bias")
	eq(tree["board"].modulate, Color.WHITE, "the board is not a parent multiply")
	eq(tree["tiles"].modulate, Color.WHITE, "the tiles node is not a flat tint")
	eq(tree["units"].modulate, Color.WHITE, "fighters are not tinted as a group")
	eq(tree["tile"].material, null, "outdoor tiles have no grade shader")
	var light_src := FileAccess.get_file_as_string("res://board/pc/look_light.gd")
	truthy(light_src.find("vec4 c = COLOR;") >= 0, "a drawn tile grade reads the painted pixel")
	eq(tree["jungle"].modulate, Color.WHITE, "the jungle node stays white")
	eq(tree["jungle"].look_grade_enabled(), false, "the jungle plate is not graded")
	var plate_code := ""
	var plate_mat: ShaderMaterial = tree["jungle"]._plate_mat
	if plate_mat != null and plate_mat.shader != null:
		plate_code = plate_mat.shader.code
	truthy(plate_code.find("blend_disabled") >= 0, "the jungle plate stays blend-disabled")
	eq(is_equal_approx(float(plate_mat.get_shader_parameter("grade_on")), 0.0), true, "the jungle plate grade is off")
	eq(light.vignette_visible(), false, "outdoors do not vignette the room")
	eq(light.get_node_or_null("Vignette"), null, "outdoors do not add a fullscreen wash")
	var rim: Color = light.rim_color()
	truthy(rim.r > rim.b, "the outdoor rim is warm")
	eq(is_equal_approx(light.rim_strength(), LIGHT.OUTDOOR_RIM_STRENGTH), true, "outdoor rim strength")
	truthy(LIGHT.SHAFT_COLOR.r > LIGHT.SHAFT_COLOR.b and LIGHT.SHAFT_COLOR.a > 0.6, "shafts are warm and readable")
	truthy(LIGHT.FLOOR_COLOR.r > LIGHT.FLOOR_COLOR.g and LIGHT.FLOOR_COLOR.a > 0.5, "the floor pool is warm and readable")
	truthy(LIGHT.POOL_RX >= 64.0, "the pool is wider than a fighter")
	_free_host(tree)


func _test_thunderwell_board_stays_flat() -> void:
	var floor_src := FileAccess.get_file_as_string("res://board/pc/thunderwell_floor.gd")
	eq(floor_src.find("l7_grade") < 0, true, "the thunderwell room shader is the base shader")
	eq(floor_src.find("func set_look_grade") < 0, true, "the thunderwell floor does not take an L7 grade")
	var tile_src := FileAccess.get_file_as_string("res://board/tile.gd")
	eq(tile_src.find("l7_grade") < 0, true, "a thunderwell floor plate is the base shader")
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], true)
	eq(light.wash_visible(), false, "thunderwell does not take the grade")
	eq(is_equal_approx(light.grade_saturation(), 1.0), true, "thunderwell saturation matches base")
	eq(is_equal_approx(light.grade_contrast(), 1.0), true, "thunderwell contrast matches base")
	eq(is_equal_approx(light.grade_gain(), 1.0), true, "thunderwell gain matches base")
	eq(light.grade_bias(), Color(0, 0, 0, 1), "thunderwell grade has no color bias")
	eq(light.vignette_visible(), false, "thunderwell has no vignette")
	eq(light.get_node_or_null("Vignette"), null, "thunderwell does not add a vignette layer")
	eq(tree["tile"].material, null, "thunderwell tiles have no grade shader")
	eq(tree["jungle"].look_grade_enabled(), false, "thunderwell does not grade the jungle plate")
	eq(light.note_events([{"type": "cast", "spell": "drop_shade", "to": Vector2i(4, 4)}]), 0, "a thunderwell cast does not add shafts or a floor pool")
	eq(light.cast_count(), 0, "thunderwell keeps no cast light")
	truthy(light.rim_strength() > LIGHT.OUTDOOR_RIM_STRENGTH, "the dungeon rim is stronger")
	truthy(light.rim_color().r > light.rim_color().b, "the dungeon rim stays warm")
	eq(LIGHT.font_size("damage", BUDGET.NUMBER_SIZE), LIGHT.PC_DAMAGE_FONT, "PC damage numbers stay 68 px on thunderwell")
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
	eq(bool(sprite.get_meta("_look_grade_mat", false)), false, "the body is not graded while the outdoor grade is off")
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
	truthy(light != null and not light.wash_visible(), "the live outdoor grade is off")
	var jungle = board.get_node_or_null("JungleBackdrop")
	truthy(jungle != null and not jungle.look_grade_enabled(), "the live jungle plate is not graded")
	var graded_body := false
	var plate_clean := false
	var rim_on := false
	for pawn in board.get_node("Units").get_children():
		if _find_rim(pawn) != null:
			rim_on = true
		var plate := pawn.get_node_or_null("Chrome/OverheadPlate") as CanvasItem
		if plate != null:
			eq(plate.material, null, "a live name plate is not graded")
			plate_clean = true
		var sprite := pawn.get_node_or_null("Sprite") as CanvasItem
		if sprite != null and bool(sprite.get_meta("_look_grade_mat", false)):
			graded_body = true
	eq(plate_clean, true, "a live fighter has a name plate")
	eq(graded_body, false, "a live fighter body is not graded")
	eq(rim_on, true, "a live fighter keeps the rim")
	HUD.set_pc_chrome_override(0)
	board._sync_look_light()
	eq(hud.layer, 10, "phone sync leaves the live HUD layer")
	eq(light.wash_visible(), false, "phone sync clears the live grade")
	eq(light.vignette_visible(), false, "phone sync clears the vignette")
	main.free()
	HUD.set_pc_chrome_override(-1)


func _test_thunderwell_board_matches_base() -> void:
	HUD.set_pc_chrome_override(1)
	LIGHT.set_suppressed(true)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node = main.get_node("BoardView")
	for _i in 50:
		await process_frame
		if bool(board.get("_booted")):
			break
	eq(bool(board.get("_booted")), true, "the thunderwell board boots")
	var sim: Node = root.get_node("CombatSim")
	sim.reset_match({
		"seed": 1,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board.set_board_theme("thunderwell")
	for _i in 8:
		await process_frame
	var floor = board.get_node_or_null("ThunderwellFloor")
	truthy(floor != null and floor.visible, "the thunderwell floor is up")
	if floor != null and floor.has_method("preview_time"):
		floor.preview_time(0.35)
	LIGHT.set_suppressed(true)
	board._sync_look_light()
	var base_sig := _board_paint_signature(board)
	LIGHT.set_suppressed(false)
	board._sync_look_light()
	if floor != null and floor.has_method("preview_time"):
		floor.preview_time(0.35)
	var on_sig := _board_paint_signature(board)
	_same_board(base_sig, on_sig, "the thunderwell board matches base with L7 on")
	var graded := false
	for row in on_sig:
		var text := str(row)
		if text.find("l7_grade") >= 0 or text.find("grade=true") >= 0:
			graded = true
	eq(graded, false, "the thunderwell board has no L7 grade")
	var light = board.get_node_or_null("LookLight")
	eq(light.vignette_visible(), false, "the live thunderwell has no vignette")
	eq(light.get_node_or_null("Vignette"), null, "the live thunderwell adds no vignette")
	eq(light.note_events([{"type": "cast", "spell": "drop_shade", "to": Vector2i(8, 7)}]), 0, "a live thunderwell cast adds no shafts or floor pool")
	eq(light.cast_count(), 0, "the live thunderwell keeps no cast light")
	var jungle = board.get_node_or_null("JungleBackdrop")
	if jungle != null and jungle.has_method("look_grade_enabled"):
		eq(jungle.look_grade_enabled(), false, "thunderwell leaves the jungle plate ungraded")
	var rim_on := false
	var body_clean := false
	for pawn in board.get_node("Units").get_children():
		if _find_rim(pawn) != null:
			rim_on = true
		var sprite := pawn.get_node_or_null("Sprite") as CanvasItem
		if sprite != null:
			eq(bool(sprite.get_meta("_look_grade_mat", false)), false, "a thunderwell fighter body is not graded")
			body_clean = true
	eq(rim_on, true, "a thunderwell fighter keeps the rim")
	eq(body_clean, true, "a thunderwell fighter was checked")
	eq(LIGHT.font_size("damage", BUDGET.NUMBER_SIZE), LIGHT.PC_DAMAGE_FONT, "thunderwell still uses the 68 px number")
	main.free()
	LIGHT.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)


func _board_paint_signature(board: Node) -> PackedStringArray:
	var rows := PackedStringArray()
	for node_name in ["Tiles", "ThunderwellFloor"]:
		_walk_paint(board.get_node_or_null(node_name), "", rows)
	rows.sort()
	return rows


func _walk_paint(node: Node, path: String, rows: PackedStringArray) -> void:
	if node == null:
		return
	var here := path + "/" + str(node.name)
	if node is CanvasItem:
		var item := node as CanvasItem
		var code := ""
		if item.material is ShaderMaterial:
			var mat := item.material as ShaderMaterial
			if mat.shader != null:
				code = mat.shader.code
		rows.append("%s modulate=%s visible=%s grade=%s code=%s" % [here, str(item.modulate), str(item.visible), str(bool(item.get_meta("_look_grade_mat", false))), code])
	for child in node.get_children():
		_walk_paint(child, here, rows)


func _same_board(base_sig: PackedStringArray, on_sig: PackedStringArray, label: String) -> void:
	if base_sig == on_sig:
		_passed += 1
		return
	_failed += 1
	print("FAIL %s" % label)
	var n := mini(base_sig.size(), on_sig.size())
	for i in n:
		if base_sig[i] != on_sig[i]:
			print("  base %s" % base_sig[i])
			print("  on   %s" % on_sig[i])
			break
	if base_sig.size() != on_sig.size():
		print("  size base=%d on=%d" % [base_sig.size(), on_sig.size()])


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
