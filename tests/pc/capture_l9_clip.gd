extends SceneTree

## 15s of play on the Crosshaven board. 150 frames at 10 fps.
## A walk, Mark Shot, Detonate, and a hit. The move tiles stay up during the walk.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l9_clip.gd -- --out=/tmp/l9_clip

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")

var _out := "/tmp/l9_clip"
var _size := Vector2i(1280, 720)
var _target := Vector2i(9, 7)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	# 20 fps and a slow scale, so a walk and two casts fill the 150 frames
	# instead of one short cast and a long hold.
	Engine.max_fps = 20
	Engine.time_scale = 0.28
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	DisplayServer.window_set_size(_size)
	await process_frame
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match(PAIR.args("crosshaven", {"rolls": [1, 1, 1]}))
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	var cam := board.get_node("BoardCamera") as Camera2D
	cam.zoom = Vector2(0.72, 0.72)
	for _i in 6:
		await process_frame
	var frame := 0
	frame = await _roll(board, frame, 10, {})
	var pawn: Node = board.get("pawns_by_seat")[0]
	var home: Vector2 = pawn.global_position
	var walked: Dictionary = sim.submit({"type": "move", "to": Vector2i(7, 5)})
	if not bool(walked.get("ok", false)):
		push_error("walk failed %s" % str(walked))
		quit(1)
		return
	var path: Array = []
	var origin := Vector2i(7, 7)
	for event in walked.get("events", []):
		if event is Dictionary and (event as Dictionary).has("path"):
			path = (event as Dictionary).get("path", [])
			origin = board._as_cell((event as Dictionary).get("from", origin))
	board._play_walk(0, path, origin)
	var moved := false
	for _i in 42:
		await process_frame
		if pawn.global_position.distance_to(home) > 12.0:
			moved = true
		frame = _save(frame)
	var shot: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": _target})
	if not bool(shot.get("ok", false)):
		push_error("mark_shot failed %s" % str(shot))
		quit(1)
		return
	_arm_cast(board, sim, shot, "mark_shot")
	var mark := ""
	frame = await _roll(board, frame, 44, {"bucket": "mark"})
	mark = str(_roll_note)
	var boom: Dictionary = sim.submit({"type": "cast", "spell": "detonate", "to": _target})
	if not bool(boom.get("ok", false)):
		push_error("detonate failed %s" % str(boom))
		quit(1)
		return
	_arm_cast(board, sim, boom, "detonate")
	frame = await _roll(board, frame, 44, {"bucket": "detonate"})
	var detonate := str(_roll_note)
	while frame < 150:
		await process_frame
		frame = _save(frame)
	print("L9_CLIP frames=%d walked=%s mark=%s detonate=%s dir=%s" % [frame, str(moved), mark, detonate, _out])
	main.free()
	var ok := moved and mark != "" and detonate != "" and mark != detonate and frame == 150
	quit(0 if ok else 1)


var _roll_note := ""


func _arm_cast(board: Node, sim: Node, result: Dictionary, spell: String) -> void:
	var events: Array = result.get("events", [])
	events.append({"type": "cast", "spell": spell, "to": _target, "seat": 0})
	board._apply_units(sim.snapshot())
	board._arm_view_motions(result.get("events", []))
	board._arm_vfx(events)


func _roll(board: Node, frame: int, count: int, note: Dictionary) -> int:
	var bucket := str(note.get("bucket", ""))
	var best := ""
	for _i in count:
		await process_frame
		if bucket != "" and _damage_alpha(board) > 0.85:
			var shown := _damage_text(board)
			if shown != "":
				best = shown
		frame = _save(frame)
	if bucket != "":
		_roll_note = best
	return frame


func _damage_text(board: Node) -> String:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return ""
	var best := ""
	var alpha := 0.0
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		var shown := str(child.get("_text"))
		if not shown.is_valid_int():
			continue
		if float(child.modulate.a) > alpha:
			alpha = float(child.modulate.a)
			best = shown
	return best


func _damage_alpha(board: Node) -> float:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return 0.0
	var best := 0.0
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		var shown := str(child.get("_text"))
		if not shown.is_valid_int():
			continue
		best = maxf(best, float(child.modulate.a))
	return best


func _save(frame: int) -> int:
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(_out.path_join("frame_%04d.png" % frame))
	return frame + 1
