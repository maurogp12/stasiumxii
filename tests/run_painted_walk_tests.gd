extends SceneTree

## Painted character walks on the mobile board (new looks, 4 Oct 2026).
## Assets: 4 facings x 12 cells per class, pivot on the 152 sole line,
## binary alpha, W/S mirrors baked. Playback: a board move plays the facing
## strip at the spec rate (frame follows the distance walked), with the
## static file as the fallback when a sheet is missing.
## Run: godot --headless --path . -s res://tests/run_painted_walk_tests.gd

const MOTION := preload("res://units/view_motion.gd")
const SPECS := preload("res://units/character_strip_specs.gd")
const CLASSES: Array[String] = ["bastion", "kestrel", "gloam", "mender", "ironjaw"]
const LETTERS: Array[String] = ["n", "e", "s", "w"]
const TILE_STEP := 35.777088  # hypot(32, 16), one board tile

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	var script := load("res://backend/combat_sim.gd")
	_sim = script.new()
	MOTION.glide = true
	StripLibrary.set_painted_looks(true)
	_test_specs()
	_test_sheets_on_disk()
	_test_statics_are_walk_f00()
	_test_library_clips()
	_test_frame_follows_distance()
	_test_action_placeholder()
	call_deferred("_finish_live")


func _finish_live() -> void:
	await _test_driven_four_facings()
	await _test_fallback_to_static()
	for class_id in CLASSES:
		await _test_board_move_plays_walk(class_id)
	StripLibrary.clear_cache()
	print("Painted walk tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _test_specs() -> void:
	for class_id in CLASSES:
		truthy(StripLibrary.has_painted_look(class_id), "%s has a painted look" % class_id)
		var spec := StripLibrary.painted_spec(class_id, "walk")
		eq(int(spec.get("frames", 0)), 12, "%s walk is 12 frames" % class_id)
		near(float(spec.get("fps", 0.0)), 17.144, "%s walk is authored at 17.144 fps" % class_id)
		eq(bool(spec.get("loop", false)), true, "%s walk loops" % class_id)
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		var pivot: Vector2i = spec.get("pivot", Vector2i.ZERO)
		truthy(cell.x > 0 and cell.x <= 256 and cell.y > Pawn.FOOT_PIVOT_Y and cell.y <= 256, "%s cell %s is phone sized (<= 256)" % [class_id, cell])
		eq(pivot, Vector2i(cell.x / 2, int(Pawn.FOOT_PIVOT_Y)), "%s pivot is centred on the 152 sole line" % class_id)
		var per_tile := float(spec.get("frames_per_tile", 0.0))
		truthy(per_tile >= 4.0 and per_tile <= 30.0, "%s frames per tile %s is in range" % [class_id, per_tile])
		eq(int(spec.get("contact", -1)), 0, "%s contact is frame 0 (the standing look)" % class_id)
	eq(SPECS.SPECS.size(), CLASSES.size(), "the spec table lists the five classes")


func _sheet(class_id: String, face: String) -> Image:
	var path := StripLibrary.painted_path(class_id, "walk", face)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return image


func _cell(sheet: Image, cell: Vector2i, i: int) -> Image:
	return sheet.get_region(Rect2i(i * cell.x, 0, cell.x, cell.y))


func _opaque_rows(image: Image) -> Vector2i:
	var top := -1
	var bottom := -1
	for y in image.get_height():
		for x in range(0, image.get_width(), 1):
			if image.get_pixel(x, y).a > 0.5:
				if top < 0:
					top = y
				bottom = y
				break
	return Vector2i(top, bottom)


func _test_sheets_on_disk() -> void:
	for class_id in CLASSES:
		var spec := StripLibrary.painted_spec(class_id, "walk")
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		var sheets := {}
		for face in LETTERS:
			var sheet := _sheet(class_id, face)
			truthy(sheet != null, "%s walk_%s sheet is on disk" % [class_id, face])
			if sheet == null:
				continue
			sheets[face] = sheet
			eq(sheet.get_size(), Vector2i(cell.x * 12, cell.y), "%s walk_%s is 12 cells of %s" % [class_id, face, cell])
			eq(sheet.detect_alpha(), Image.ALPHA_BIT, "%s walk_%s alpha is binary" % [class_id, face])
			var f00 := _cell(sheet, cell, 0)
			var rows := _opaque_rows(f00)
			truthy(rows.x > 0, "%s walk_%s f00 head is not clipped" % [class_id, face])
			truthy(rows.y < cell.y - 1, "%s walk_%s f00 feet are not clipped" % [class_id, face])
			# The figure stands on the sole line: the lowest foot is on or just past 152.
			truthy(rows.y >= int(Pawn.FOOT_PIVOT_Y) - 12 and rows.y <= int(Pawn.FOOT_PIVOT_Y) + 24, "%s walk_%s f00 feet sit on the sole line (bottom row %d)" % [class_id, face, rows.y])
			var span := rows.y - rows.x
			truthy(span > 110 and span < 175, "%s walk_%s figure is board sized (%d px)" % [class_id, face, span])
		# Locked rule: W mirrors S, N mirrors E. Mobile s is the mirror of e, w of n.
		for pair in [["e", "s"], ["n", "w"]]:
			if not sheets.has(pair[0]) or not sheets.has(pair[1]):
				continue
			var same := true
			for i in [0, 5, 11]:
				var a := _cell(sheets[pair[0]], cell, i)
				a.flip_x()
				var b := _cell(sheets[pair[1]], cell, i)
				if a.get_data() != b.get_data():
					same = false
			truthy(same, "%s walk_%s is the baked mirror of walk_%s" % [class_id, pair[1], pair[0]])


func _test_statics_are_walk_f00() -> void:
	for class_id in CLASSES:
		var spec := StripLibrary.painted_spec(class_id, "walk")
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		for face in LETTERS:
			var tex := Pawn.sprite_texture(class_id, face)
			truthy(tex != null, "%s static %s loads" % [class_id, face])
			var sheet := _sheet(class_id, face)
			if tex == null or sheet == null:
				continue
			var still := tex.get_image()
			eq(still.get_size(), cell, "%s static %s is the walk cell size" % [class_id, face])
			if still.get_size() != cell:
				continue
			still.convert(Image.FORMAT_RGBA8)
			var f00 := _cell(sheet, cell, 0)
			f00.convert(Image.FORMAT_RGBA8)
			var diff := 0
			for y in range(0, cell.y, 3):
				for x in range(0, cell.x, 3):
					if absf(still.get_pixel(x, y).a - f00.get_pixel(x, y).a) > 0.5:
						diff += 1
			eq(diff, 0, "%s static %s is walk_%s f00" % [class_id, face, face])
			eq(Pawn.pivot_offset_for(float(tex.get_height())).y, -(Pawn.FOOT_PIVOT_Y - float(cell.y) * 0.5), "%s static %s stands on the sole line" % [class_id, face])


func _test_library_clips() -> void:
	StripLibrary.clear_cache()
	for class_id in CLASSES:
		var spec := StripLibrary.painted_spec(class_id, "walk")
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		var frames := StripLibrary.frames_for(class_id)
		truthy(frames != null, "%s strip bank loads" % class_id)
		if frames == null:
			continue
		for face in LETTERS:
			var anim := "walk_%s" % face
			truthy(frames.has_animation(anim), "%s has %s" % [class_id, anim])
			if not frames.has_animation(anim):
				continue
			eq(frames.get_frame_count(anim), 12, "%s %s plays 12 painted cells" % [class_id, anim])
			near(frames.get_animation_speed(anim), 17.144, "%s %s keeps the authored fps" % [class_id, anim])
			var tex := frames.get_frame_texture(anim, 7)
			eq(tex is ImageTexture, true, "%s %s cells are standalone ImageTextures" % [class_id, anim])
			if tex != null:
				eq(Vector2i(tex.get_width(), tex.get_height()), cell, "%s %s cell is %s" % [class_id, anim, cell])
			eq(StripLibrary.walk_contact_index(class_id, face), 0, "%s %s contact is frame 0" % [class_id, anim])
		var portrait := StripLibrary.idle_portrait(class_id)
		truthy(portrait != null and portrait.get_height() == cell.y, "%s turn chip uses the painted walk e f00" % class_id)


func _test_frame_follows_distance() -> void:
	eq(MOTION.painted_walk_frame(0.0, 14.0, 12, 0), 0, "zero distance is the contact")
	eq(MOTION.painted_walk_frame(0.5, 14.0, 12, 0), 7, "half a tile at 14 cells/tile is cell 7")
	eq(MOTION.painted_walk_frame(1.0, 14.0, 12, 0), 2, "one tile wraps the cycle")
	eq(MOTION.painted_walk_frame(1.0, 0.0, 12, 0), 0, "no rate holds the contact")
	for class_id in CLASSES:
		var per_tile := float(StripLibrary.painted_spec(class_id, "walk").get("frames_per_tile", 0.0))
		# Foot skate: one cell of the strip must equal its share of the tile.
		var board_px_per_cell := TILE_STEP / per_tile
		truthy(board_px_per_cell > 1.0 and board_px_per_cell < 9.0, "%s one cell moves %.2f board px" % [class_id, board_px_per_cell])
		near(per_tile / Pawn.WALK_TILE_SEC, per_tile / 0.34, "%s rate is tied to WALK_TILE_SEC" % class_id)


func _test_action_placeholder() -> void:
	for kind in ["idle", "attack", "skill", "hit", "death"]:
		truthy(StripLibrary.PAINTED_KINDS.has(kind), "%s has a painted drop spot" % kind)
		truthy(StripLibrary.PAINTED_ANIM.has(kind), "%s maps to a pawn clip" % kind)
	eq(str(StripLibrary.PAINTED_ANIM["skill"]), "cast", "a painted skill plays as cast")
	eq(StripLibrary.painted_path("ironjaw", "attack", "e"), "res://art/characters/ironjaw/attack/ironjaw_attack_e.pngbin", "actions load from the same layout as walk")
	# No painted actions yet: today's strips stay.
	StripLibrary.clear_cache()
	var frames := StripLibrary.frames_for("ironjaw")
	eq(StripLibrary.painted_spec("ironjaw", "attack").is_empty(), true, "no painted attack spec yet")
	truthy(frames != null and frames.has_animation("attack_e") and frames.get_frame_count("attack_e") > 0, "Ironjaw keeps the export_2x attack")
	truthy(frames != null and frames.has_animation("hit_e"), "Ironjaw keeps the export_2x hit")
	eq(StripLibrary.release_sec("ironjaw", "attack"), float(StripLibrary.ATTACK_IMPACT_FRAME) / 12.0, "attack release timing is unchanged")


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


func _test_driven_four_facings() -> void:
	for class_id in CLASSES:
		var per_tile := float(StripLibrary.painted_spec(class_id, "walk").get("frames_per_tile", 0.0))
		var pawn := Pawn.new()
		get_root().add_child(pawn)
		await process_frame
		pawn.apply_snapshot(_unit(class_id, "E", 0), 0)
		await process_frame
		pawn.arm_driven_walk()
		var tile := 0
		for face in ["E", "S", "W", "N"]:
			truthy(pawn.begin_segment_walk(face), "%s %s segment starts the painted walk" % [class_id, face])
			if tile == 0:
				pawn.sync_walk_plant()
			else:
				pawn.bridge_straight_tile()
			var cells := StripLibrary.painted_cells(class_id, "walk", face.to_lower())
			var ok := true
			var seen := {}
			for i in 9:
				var u := float(i) / 8.0
				pawn.sample_driven_gait(u)
				var want := MOTION.painted_walk_frame(float(tile) + u, per_tile, 12, 0)
				var sampler := pawn.walk_sampler()
				if sampler == null or sampler.frame != want or String(sampler.animation) != "walk_%s" % face.to_lower():
					ok = false
				if pawn.drawn_walk_texture() != cells[want]:
					ok = false
				seen[want] = true
			truthy(ok, "%s %s draws the painted cell for the distance walked" % [class_id, face])
			truthy(seen.size() >= 4, "%s %s cycles the legs across the tile" % [class_id, face])
			var sprite := pawn.get_node("Sprite") as Sprite2D
			eq(sprite.visible, false, "%s %s hides the static while walking" % [class_id, face])
			eq(pawn.get_node("WalkDraw").position, Vector2.ZERO, "%s %s keeps the feet on the tile (no hop)" % [class_id, face])
			near((pawn.get_node("WalkDraw") as Sprite2D).offset.y, -(Pawn.FOOT_PIVOT_Y - float(cells[0].get_height()) * 0.5), "%s %s pivot stands on the sole line" % [class_id, face])
			tile += 1
		pawn.end_path_walk()
		var plant := pawn.walk_sampler()
		truthy(plant != null and plant.frame == 0, "%s arrival plants walk frame 0" % class_id)
		pawn.free()
		await process_frame


func _test_fallback_to_static() -> void:
	StripLibrary.clear_cache()
	# Pretend the east sheet is missing for Kestrel. The other facings stay.
	StripLibrary._painted_cells[StripLibrary.painted_path("kestrel", "walk", "e")] = []
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	await process_frame
	pawn.apply_snapshot(_unit("kestrel", "E", 0), 0)
	await process_frame
	var sprite := pawn.get_node("Sprite") as Sprite2D
	eq(pawn.has_walk_strip(), false, "a missing east sheet means no east walk")
	eq(pawn.painted_walk_frames_per_tile(), 0.0, "a missing sheet has no painted rate")
	eq(sprite.visible, true, "the static east look shows")
	eq(sprite.texture, Pawn.sprite_texture("kestrel", "E"), "the fallback is the static kestrel_e.png")
	pawn._sample_hop(0.5)
	truthy(sprite.position.y < 0.0, "the fallback keeps the old hop")
	var frames := StripLibrary.frames_for("kestrel")
	eq(frames.has_animation("walk_e"), false, "no old export_2x costume fills the missing walk")
	truthy(frames.has_animation("walk_s") and frames.get_frame_count("walk_s") == 12, "the other facings stay painted")
	pawn.set_facing("S")
	eq(pawn.painted_walk_frames_per_tile() > 0.0, true, "south still walks painted")
	pawn.free()
	await process_frame
	StripLibrary.clear_cache()


func _test_board_move_plays_walk(class_id: String) -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var board: Node = main.get_node("BoardView")
	var sim: Node = get_root().get_node("CombatSim")
	var foe := "kestrel" if class_id != "kestrel" else "gloam"
	sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": [class_id, foe],
		"positions": [Vector2i(2, 2), Vector2i(8, 8)],
		"kestrel_facing": "N",
		"ironjaw_facing": "N",
	})
	board._rebuild_pawns()
	board._refresh()
	var pawn := board.pawns_by_seat[0] as Pawn
	var sprite := pawn.get_node("Sprite") as Sprite2D
	var per_tile := pawn.painted_walk_frames_per_tile()
	truthy(per_tile > 0.0, "%s stands on the painted walk before the move" % class_id)
	board._submit({"type": "move", "to": Vector2i(4, 3), "seat": 0})
	var walked := 0.0
	var prev := pawn.position
	var faces := {}
	var cells := {}
	var static_during := false
	var skate := 0
	var samples := 0
	var frames := 0
	while frames < 400:
		await process_frame
		frames += 1
		walked += pawn.position.distance_to(prev) / TILE_STEP
		prev = pawn.position
		if not bool(board.get("_busy")) and frames > 8:
			break
		if walked <= 0.0 or walked >= 2.99:
			continue
		if sprite.visible:
			static_during = true
		var sampler := pawn.walk_sampler()
		if sampler == null or not pawn.walk_cell_is_drawn():
			static_during = true
			continue
		faces[pawn.facing] = true
		cells[sampler.frame] = true
		samples += 1
		# The cell must match the distance on the board (+-1 for the sample edge).
		var want := MOTION.painted_walk_frame(walked, per_tile, 12, 0)
		var off := posmod(sampler.frame - want + 6, 12) - 6
		if absi(off) > 1:
			skate += 1
	truthy(samples > 4, "%s move was sampled (%d)" % [class_id, samples])
	eq(static_during, false, "%s the static stays hidden while the move plays" % class_id)
	truthy(faces.has("E") and faces.has("S"), "%s the move faces east then south (%s)" % [class_id, faces.keys()])
	truthy(cells.size() >= 6, "%s the walk cycles its cells (%d seen)" % [class_id, cells.size()])
	eq(skate, 0, "%s the painted cell keeps pace with the board (no skate)" % class_id)
	eq(pawn.grid_position, Vector2i(4, 3), "%s lands on the clicked tile" % class_id)
	var planted := pawn.walk_sampler()
	truthy(planted != null and planted.frame == 0 and String(planted.animation) == "walk_s", "%s arrival stands on walk_s f00" % class_id)
	main.free()
	await process_frame


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
