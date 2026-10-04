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
var _only := ""


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
		elif text.begins_with("--only="):
			_only = text.trim_prefix("--only=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	await process_frame
	if _only == "speed":
		await _speed_pass()
		print("L10_SHOT role=%s size=%s out=%s failed=%s" % [_role, str(_size), _out, str(_failed)])
		quit(1 if _failed else 0)
		return
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


## The 0.22 / 0.42 clip. Ironjaw walks the same 5-cell line on Crosshaven, out
## and back, under a fixed camera. Every process frame is one 1/30 s step, so run
## with --fixed-fps 30 and the clip plays at true speed whatever the renderer does.
## The 0.42 side runs first; the 0.22 side keeps idling until it has as many
## frames, so the two halves stay in step when ffmpeg puts them side by side.
## Frames are full size; the clip crops the centre 960 columns of each side.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 --path . -s res://tests/pc/capture_l10.gd -- --out=/tmp/l10_speed --size=1920x1080 --only=speed
const SPEED_FROM := Vector2i(7, 7)
const SPEED_TO := Vector2i(12, 7)
const SPEED_HOLD := 18


func _speed_pass() -> void:
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	if not pawn_src.contains("func set_pc_walk_tile_sec"):
		return
	await process_frame
	if absf(root.get_process_delta_time() - 1.0 / 30.0) > 0.0005:
		push_error("the speed clip needs --fixed-fps 30 (delta %.4f)" % root.get_process_delta_time())
		_failed = true
		return
	# Runtime call. The before tree's Pawn has no walk-trial members, and a
	# direct Pawn.PC_WALK_TILE_SEC reference fails to parse there.
	var pawn_api: Script = load("res://units/pawn.gd")
	var target := 0
	for seconds in [0.42, 0.22]:
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
		_speed_reset(sim, board, SPEED_FROM)
		await _frames(4)
		var a: Vector2 = board.to_global(board._cell_to_local(SPEED_FROM))
		var b: Vector2 = board.to_global(board._cell_to_local(SPEED_TO))
		_aim(cam, (a + b) * 0.5 + Vector2(0, -30), 2.6)
		var label := "0.22 s per cell (phone)" if tag == "022" else "0.42 s per cell (PC)"
		var caption := _caption(label)
		(caption.get_child(0) as Label).position = Vector2(float(_size.x) * 0.25 + 28.0, 24.0)
		await _frames(2)
		var shots := {"dir": dir, "index": 0}
		await _speed_hold(shots, SPEED_HOLD)
		for leg in [[SPEED_FROM, SPEED_TO], [SPEED_TO, SPEED_FROM]]:
			var from: Vector2i = leg[0]
			var to: Vector2i = leg[1]
			_speed_reset(sim, board, to)
			board._play_walk(1, _speed_line(from, to), from)
			await process_frame
			var guard := 0
			while int(board.get("_hop_seat")) >= 0 and guard < 600:
				_speed_shot(shots)
				await process_frame
				guard += 1
			await _speed_hold(shots, SPEED_HOLD)
		if tag == "042":
			target = int(shots["index"])
		else:
			if int(shots["index"]) > target:
				push_error("the 0.22 side ran longer than the 0.42 side")
				_failed = true
			await _speed_hold(shots, target - int(shots["index"]))
		caption.free()
		print("L10_SPEED %s frames=%d" % [tag, int(shots["index"])])
		main.free()
		await _frames(2)
	var restore: float = float(pawn_api.get_script_constant_map().get("PC_WALK_TILE_SEC", 0.42))
	pawn_api.call("set_pc_walk_tile_sec", restore)


## The sim holds Ironjaw on the far cell, so the board plays the whole line with
## no MP limit and lands where the sim already is. Kestrel waits off the line.
func _speed_reset(sim: Node, board: Node, ironjaw_at: Vector2i) -> void:
	sim.reset_match({
		"seed": 1,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(9, 3), ironjaw_at],
		"kestrel_facing": "E",
		"ironjaw_facing": "E" if ironjaw_at == SPEED_FROM else "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()


func _speed_line(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var at := from
	while at != to:
		at += step
		out.append(at)
	return out


func _speed_shot(shots: Dictionary) -> void:
	var image := _grab()
	image.save_png(str(shots["dir"]).path_join("f%04d.png" % int(shots["index"])))
	shots["index"] = int(shots["index"]) + 1


func _speed_hold(shots: Dictionary, count: int) -> void:
	for _i in maxi(count, 0):
		_speed_shot(shots)
		await process_frame


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
