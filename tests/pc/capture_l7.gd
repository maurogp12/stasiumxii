extends SceneTree

## L7 stills. Phone frame, then the PC grade with a Strike so the number,
## the shafts and the floor pool are in the shot.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l7.gd -- --out=/tmp/l7_frames --size=1280x720 --ref=/tmp/look_target_refs.jpg

var _out := "/tmp/l7_frames"
var _size := Vector2i(1280, 720)
var _ref := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
		elif text.begins_with("--ref="):
			_ref = text.trim_prefix("--ref=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	await process_frame
	var phone := await _frame(false, "crosshaven", "")
	var outdoor := await _frame(true, "crosshaven", "")
	var dungeon := await _frame(true, "stormspire", "thunderwell")
	if phone == null or outdoor == null or dungeon == null:
		quit(1)
		return
	_pair(phone, outdoor, _out.path_join("before_after.png"))
	if _ref != "":
		var sheet := Image.load_from_file(_ref)
		if sheet == null or sheet.is_empty():
			push_error("reference missing")
			quit(1)
			return
		sheet.convert(Image.FORMAT_RGBA8)
		_beside(sheet, Rect2i(0, 0, 1000, 543), outdoor, _out.path_join("beside_a.png"))
		_beside(sheet, Rect2i(0, 543, 1000, 543), dungeon, _out.path_join("beside_b.png"))
		_beside(sheet, Rect2i(0, 1086, 1000, 544), outdoor, _out.path_join("beside_c.png"))
	print("L7_SHOT %s size=%s" % [_out, str(_size)])
	quit(0)


func _frame(pc: bool, map_id: String, theme: String) -> Image:
	var hud_script := load("res://ui/hud.gd")
	hud_script.set_pc_chrome_override(1 if pc else 0)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match({
		"seed": 1,
		"map_id": map_id,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(8, 7),
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	if theme != "":
		board.set_board_theme(theme)
	else:
		board.set_board_theme("")
	for _i in 8:
		await process_frame
	var ended: Dictionary = sim.submit({"type": "end_turn"})
	if not bool(ended.get("ok", false)):
		push_error("end turn failed %s" % str(ended))
		main.free()
		return null
	var strike: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(7, 7)})
	if not bool(strike.get("ok", false)):
		push_error("strike failed %s" % str(strike))
		main.free()
		return null
	board._apply_units(sim.snapshot())
	board._arm_vfx(strike.get("events", []))
	var shown := false
	for _i in 24:
		await process_frame
		if _number_alpha(board) > 0.85:
			shown = true
			break
	if not shown:
		push_error("damage number did not show")
		main.free()
		return null
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	main.free()
	hud_script.set_pc_chrome_override(-1)
	for _i in 2:
		await process_frame
	return image


func _number_alpha(board: Node) -> float:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return 0.0
	var best := 0.0
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		if str(child.get("_text")) == "":
			continue
		best = maxf(best, float(child.modulate.a))
	return best


func _pair(left: Image, right: Image, path: String) -> void:
	var gap := 8
	var width := left.get_width() + right.get_width() + gap
	var height := maxi(left.get_height(), right.get_height())
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.07, 0.06, 1))
	_blit(out, left, Vector2i(0, 0))
	_blit(out, right, Vector2i(left.get_width() + gap, 0))
	out.save_png(path)


func _beside(sheet: Image, crop: Rect2i, game: Image, path: String) -> void:
	var ref := Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	ref.blit_rect(sheet, crop, Vector2i.ZERO)
	ref.resize(int(float(crop.size.x) * float(game.get_height()) / float(crop.size.y)), game.get_height(), Image.INTERPOLATE_LANCZOS)
	_pair(ref, game, path)


func _blit(dst: Image, src: Image, at: Vector2i) -> void:
	var copy := src.duplicate()
	if copy.get_format() != dst.get_format():
		copy.convert(dst.get_format())
	dst.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), at)
