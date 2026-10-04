extends SceneTree

## L10 stills. The same script runs on pc/combat-look (before) and on this branch.
## World shots and the 0.22 / 0.42 walk need the new files, so a before tree skips them.
## PC combat defaults to the 0.42 trial. The clip still shows 0.22 beside 0.42.
## Ironjaw v3.1 has no cast folder. Its stills are idle, walk, and attack (Strike).
## Kestrel stills are idle, walk, and cast (Detonate). Mark Shot is wired to
## cast_mark, so Kestrel also gets a cast_mark still.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l10.gd -- --out=/tmp/l10_after_1280 --size=1280x720 --role=after

const HUD := preload("res://ui/hud.gd")
const LIGHT := preload("res://board/pc/look_light.gd")

var _out := "/tmp/l10_frames"
var _size := Vector2i(1280, 720)
var _role := "after"
var _failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
		elif text.begins_with("--role="):
			_role = text.trim_prefix("--role=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	await process_frame
	await _board_pass("crosshaven", "crosshaven", "")
	await _board_pass("thunderwell", "stormspire", "thunderwell")
	if _role == "after" and ResourceLoader.exists("res://scenes/pc/pc_world_walker.gd"):
		await _world_pass()
		await _speed_pass()
	print("L10_SHOT role=%s size=%s out=%s failed=%s" % [_role, str(_size), _out, str(_failed)])
	quit(1 if _failed else 0)


func _board_pass(board_name: String, map_id: String, theme: String) -> void:
	var session := await _boot(map_id, theme)
	if session.is_empty():
		_failed = true
		return
	var board: Node = session["board"]
	var sim: Node = session["sim"]
	var main: Node = session["main"]
	var cam: Camera2D = board.get_node("BoardCamera")
	for class_id in ["ironjaw", "kestrel"]:
		_place(sim, board, map_id, class_id, Vector2i(7, 7), Vector2i(11, 7))
		await _frames(6)
		_aim(cam, _pawn(board, _seat_of(class_id)).global_position, 1.12)
		await _frames(3)
		_save(board_name, class_id, "idle")
		# One cell. A three-cell walk from (7, 7) costs more than 3 MP on Stormspire.
		var walk_to := Vector2i(8, 7) if class_id == "kestrel" else Vector2i(10, 7)
		if not await _walk_to(board, sim, _seat_of(class_id), walk_to):
			_failed = true
		else:
			await _until_moved(board, _seat_of(class_id), 18.0)
			_aim(cam, _pawn(board, _seat_of(class_id)).global_position, 1.12)
			_save(board_name, class_id, "walk")
			await _until_idle(board)
		if class_id == "ironjaw":
			# No cast folder. Strike is the attack still.
			_place(sim, board, map_id, class_id, Vector2i(7, 7), Vector2i(8, 7))
			await _frames(4)
			if not await _cast(board, sim, 1, "strike", Vector2i(7, 7)):
				_failed = true
			else:
				await _seconds(0.18)
				_aim(cam, _pawn(board, 1).global_position, 1.12)
				_save(board_name, class_id, "attack")
				_stop_motion(board)
				await _frames(2)
		else:
			# Detonate plays cast_*. Distance 3 is inside 1–4.
			_place(sim, board, map_id, class_id, Vector2i(7, 7), Vector2i(10, 7), 1)
			await _frames(4)
			if not await _cast(board, sim, 0, "detonate", Vector2i(10, 7)):
				_failed = true
			else:
				await _seconds(0.18)
				_aim(cam, _pawn(board, 0).global_position, 1.12)
				_save(board_name, class_id, "cast")
				_stop_motion(board)
				await _frames(2)
			# Mark Shot plays cast_mark_*. Distance 3 is inside 2–7.
			_place(sim, board, map_id, class_id, Vector2i(7, 7), Vector2i(10, 7))
			await _frames(4)
			if not await _cast(board, sim, 0, "mark_shot", Vector2i(10, 7)):
				_failed = true
			else:
				await _seconds(0.18)
				_aim(cam, _pawn(board, 0).global_position, 1.12)
				_save(board_name, class_id, "cast_mark")
				_stop_motion(board)
				await _frames(2)
	_place(sim, board, map_id, "kestrel", Vector2i(7, 7), Vector2i(10, 7))
	await _frames(4)
	var a: Node2D = _pawn(board, 0)
	var b: Node2D = _pawn(board, 1)
	_aim(cam, (a.global_position + b.global_position) * 0.5, 0.92)
	await _frames(3)
	_save(board_name, "both", "idle")
	main.free()
	await _frames(2)


func _world_pass() -> void:
	var session := await _boot("crosshaven", "")
	if session.is_empty():
		_failed = true
		return
	var board: Node = session["board"]
	var main: Node = session["main"]
	var hud := main.get_node("HUD")
	hud.visible = false
	for child in board.get_node("Units").get_children():
		(child as CanvasItem).visible = false
	var script: Script = load("res://scenes/pc/pc_world_walker.gd")
	var cam: Camera2D = board.get_node("BoardCamera")
	for class_id in ["ironjaw", "kestrel"]:
		var walker: Node2D = script.new()
		walker.name = "WorldWalker"
		board.get_node("Units").add_child(walker)
		walker.position = board._cell_to_local(Vector2i(8, 8))
		walker.z_index = 8
		if not walker.setup(class_id):
			push_error("world walker missing %s" % class_id)
			_failed = true
			walker.free()
			continue
		walker.face("E")
		walker.show_state("idle")
		await _frames(4)
		_aim(cam, walker.global_position, 1.12)
		await _frames(2)
		_save("world", class_id, "idle")
		walker.set_travel_px(36.0)
		walker.position += Vector2(28, 14)
		await _frames(2)
		_aim(cam, walker.global_position, 1.12)
		_save("world", class_id, "walk")
		if class_id == "ironjaw":
			walker.show_state("attack")
			await _seconds(0.18)
			_save("world", class_id, "attack")
		else:
			walker.show_state("cast")
			await _seconds(0.18)
			_save("world", class_id, "cast")
			walker.show_state("cast_mark")
			await _seconds(0.18)
			_save("world", class_id, "cast_mark")
		walker.free()
	main.free()
	await _frames(2)


func _speed_pass() -> void:
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	if not pawn_src.contains("func set_pc_walk_tile_sec"):
		return
	# Runtime call. The before tree's Pawn has no walk-trial members, and a
	# direct Pawn.PC_WALK_TILE_SEC reference fails to parse there.
	var pawn_api: Script = load("res://units/pawn.gd")
	for seconds in [0.22, 0.42]:
		var tag := "022" if is_equal_approx(seconds, 0.22) else "042"
		var dir := _out.path_join("speed_%s" % tag)
		DirAccess.make_dir_recursive_absolute(dir)
		pawn_api.call("set_pc_walk_tile_sec", seconds)
		var session := await _boot("crosshaven", "")
		if session.is_empty():
			_failed = true
			return
		var board: Node = session["board"]
		var sim: Node = session["sim"]
		var main: Node = session["main"]
		var cam: Camera2D = board.get_node("BoardCamera")
		_place(sim, board, "crosshaven", "ironjaw", Vector2i(6, 7), Vector2i(12, 7))
		await _frames(4)
		var caption := _caption("%.2f s per cell" % seconds)
		var pawn: Node2D = _pawn(board, 1)
		_aim(cam, pawn.global_position, 1.05)
		if not await _walk_to(board, sim, 1, Vector2i(10, 7)):
			_failed = true
			caption.free()
			main.free()
			continue
		var started := Time.get_ticks_msec()
		var next := 0
		var index := 0
		var guard := 0
		while int(board.get("_hop_seat")) >= 0 and guard < 900:
			await process_frame
			guard += 1
			var elapsed := Time.get_ticks_msec() - started
			if elapsed < next:
				continue
			next += 50
			_aim(cam, _pawn(board, 1).global_position, 1.05)
			var image := _grab()
			image.save_png(dir.path_join("f%04d.png" % index))
			index += 1
		caption.free()
		print("L10_SPEED %s frames=%d" % [tag, index])
		main.free()
		await _frames(2)
	var restore: float = float(pawn_api.get_script_constant_map().get("PC_WALK_TILE_SEC", 0.42))
	pawn_api.call("set_pc_walk_tile_sec", restore)


func _boot(map_id: String, theme: String) -> Dictionary:
	HUD.set_pc_chrome_override(1)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 50:
		await process_frame
		if bool(board.get("_booted")):
			break
	if not bool(board.get("_booted")):
		push_error("board did not boot")
		_failed = true
		main.free()
		return {}
	sim.reset_match({
		"seed": 1,
		"map_id": map_id,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(7, 7), Vector2i(10, 7)],
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme(theme)
	if board.has_method("_sync_look_light"):
		board._sync_look_light()
	await _frames(6)
	return {"main": main, "board": board, "sim": sim}


func _place(sim: Node, board: Node, map_id: String, focus: String, kestrel_at: Vector2i, ironjaw_at: Vector2i, ironjaw_marks: int = 0) -> void:
	var setup := {
		"seed": 1,
		"map_id": map_id,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [kestrel_at, ironjaw_at],
		"kestrel_pos": kestrel_at,
		"ironjaw_pos": ironjaw_at,
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1],
	}
	if ironjaw_marks > 0:
		setup["ironjaw_marks"] = ironjaw_marks
	sim.reset_match(setup)
	board._rebuild_pawns()
	board._refresh()
	if focus == "ironjaw":
		var pawn := _pawn(board, 1)
		if pawn != null:
			pawn.set_facing("E")


func _walk_to(board: Node, sim: Node, seat: int, to: Vector2i) -> bool:
	if seat != 0:
		var ended: Dictionary = sim.submit({"type": "end_turn", "seat": 0})
		if not bool(ended.get("ok", false)):
			push_error("end turn failed %s" % str(ended))
			return false
	var result: Dictionary = sim.submit({"type": "move", "to": to, "seat": seat})
	if not bool(result.get("ok", false)):
		push_error("move failed %s" % str(result))
		return false
	var event: Dictionary = board._path_event(result.get("events", []))
	var path: Array = event.get("path", [])
	if path.is_empty():
		push_error("move had no path")
		return false
	board._play_walk(seat, path, board._as_cell(event.get("from", Vector2i(-1, -1))))
	return true


func _cast(board: Node, sim: Node, seat: int, spell: String, to: Vector2i) -> bool:
	if seat != 0:
		var ended: Dictionary = sim.submit({"type": "end_turn", "seat": 0})
		if not bool(ended.get("ok", false)):
			push_error("end turn failed %s" % str(ended))
			return false
	var result: Dictionary = sim.submit({"type": "cast", "spell": spell, "to": to, "seat": seat})
	if not bool(result.get("ok", false)):
		push_error("%s failed %s" % [spell, str(result)])
		return false
	board._apply_units(sim.snapshot())
	board._arm_view_motions(result.get("events", []))
	return true


func _until_moved(board: Node, seat: int, pixels: float) -> void:
	var pawn := _pawn(board, seat)
	var start := pawn.global_position
	var guard := 0
	while pawn.global_position.distance_to(start) < pixels and int(board.get("_hop_seat")) >= 0 and guard < 180:
		await process_frame
		guard += 1


func _until_idle(board: Node) -> void:
	var guard := 0
	while int(board.get("_hop_seat")) >= 0 and guard < 900:
		await process_frame
		guard += 1


func _stop_motion(board: Node) -> void:
	var pawns: Variant = board.get("pawns_by_seat")
	if pawns is Dictionary:
		for seat in pawns.keys():
			var pawn: Variant = pawns[seat]
			if pawn != null and pawn.has_method("settle_motion"):
				pawn.settle_motion()


func _seat_of(class_id: String) -> int:
	return 0 if class_id == "kestrel" else 1


func _pawn(board: Node, seat: int) -> Node2D:
	var pawns: Variant = board.get("pawns_by_seat")
	if pawns is Dictionary and pawns.has(seat):
		return pawns[seat]
	return null


func _aim(cam: Camera2D, at: Vector2, zoom: float) -> void:
	cam.zoom = Vector2(zoom, zoom)
	cam.global_position = at


func _save(board_name: String, class_id: String, pose: String) -> void:
	var image := _grab()
	var path := _out.path_join("%s_%s_%s.png" % [board_name, class_id, pose])
	image.save_png(path)
	print("L10_FRAME %s" % path)


func _grab() -> Image:
	RenderingServer.force_draw()
	return root.get_viewport().get_texture().get_image()


func _caption(text: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var label := Label.new()
	label.text = text
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.86))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	root.add_child(layer)
	return layer


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _seconds(sec: float) -> void:
	await create_timer(sec).timeout
