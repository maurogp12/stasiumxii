extends SceneTree

## L9 before/after. Left is this branch with the look off, the same match
## as pc/combat-look at 265cc43. Right is the v1.2 board. One seed, one
## camera, one freeze, so pixels outside the board art match.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l9.gd -- --out=/tmp/l9_frames --size=1280x720

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")

var _out := "/tmp/l9_frames"
var _size := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var shot := await _boot(_size)
	if shot.is_empty():
		quit(1)
		return
	var board: Node = shot["board"]
	_freeze(board)
	var before := await _grab(board, true)
	var after := await _grab(board, false)
	var outside := _outside_board(board, before, after)
	var name := "before_after_%d.png" % _size.x
	before.save_png(_out.path_join("stock_%d.png" % _size.x))
	after.save_png(_out.path_join("board_%d.png" % _size.x))
	_pair(before, after, _out.path_join(name))
	print("L9_OUTSIDE size=%d outside=%d" % [_size.x, outside])
	print("L9_SHOT %s %s" % [name, str(before.get_size())])
	if outside != 0:
		push_error("pixels outside the board art differ: %d" % outside)
		shot["main"].free()
		quit(1)
		return
	shot["main"].free()
	BOARD.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)
	quit(0)


func _boot(size: Vector2i) -> Dictionary:
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = size
	root.size = size
	DisplayServer.window_set_size(size)
	await process_frame
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match(PAIR.args("crosshaven"))
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	for _i in 6:
		await process_frame
	return {"main": main, "board": board}


func _plant_bodies(board: Node) -> void:
	var pawns: Dictionary = board.get("pawns_by_seat")
	for seat in pawns.keys():
		var pawn: Node = pawns[seat]
		if pawn.has_method("hold_idle"):
			pawn.hold_idle()


func _freeze(board: Node) -> void:
	Engine.time_scale = 0.0
	var jungle = board.get_node_or_null("JungleBackdrop")
	if jungle != null:
		jungle.set_process(false)
		if jungle.has_method("preview_time"):
			jungle.preview_time(0.35)
	var tile_script: GDScript = load("res://board/tile.gd")
	if tile_script != null:
		tile_script.set_move_pulse_frozen(true)
		tile_script.set_move_pulse_time(0.35)


func _grab(board: Node, off: bool) -> Image:
	BOARD.set_suppressed(off)
	board._refresh()
	_freeze(board)
	for _i in 4:
		await process_frame
	# Idle bob samples the wall clock, so two boots land on different frames.
	# Plant both fighters before the grab. The pair then matches 265cc43
	# outside the board art.
	_plant_bodies(board)
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	return image


func _pair(left: Image, right: Image, path: String) -> void:
	var gap := 8
	var out := Image.create(left.get_width() + right.get_width() + gap, maxi(left.get_height(), right.get_height()), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.07, 0.06, 1))
	_blit(out, left, Vector2i(0, 0))
	_blit(out, right, Vector2i(left.get_width() + gap, 0))
	out.save_png(path)


## Jungle, HUD and the fighter bodies sit outside the dressed cells. The
## kit edge and the props hang past the diamond, so the mask is generous.
func _outside_board(board: Node, before: Image, after: Image) -> int:
	if before.get_size() != after.get_size():
		return -1
	var cam := board.get_node("BoardCamera") as Camera2D
	var xform := cam.get_canvas_transform()
	var zoom := cam.zoom.x
	# Props and the 2-step earth face hang past the diamond. The pad is in
	# cell pixels, then the screen margin catches the anti-aliased rim.
	# The kit edge replaces the jungle lip, which reaches about 2.2 cells
	# past the diamond. That lip is part of the board-edge change.
	var pad := Vector2(150.0, 180.0) * zoom
	var margin := 16.0
	var rects: Array[Rect2] = []
	var tiles: Dictionary = board.get("tiles")
	for cell in tiles.keys():
		var tile := tiles[cell] as Node2D
		var center: Vector2 = xform * tile.global_position
		var grown := pad + Vector2(margin, margin)
		rects.append(Rect2(center - grown, grown * 2.0))
	var n := 0
	var width := before.get_width()
	var height := before.get_height()
	var min_at := Vector2i(width, height)
	var max_at := Vector2i(-1, -1)
	for y in height:
		for x in width:
			if before.get_pixel(x, y) == after.get_pixel(x, y):
				continue
			var at := Vector2(x + 0.5, y + 0.5)
			var inside := false
			for rect in rects:
				if rect.has_point(at):
					inside = true
					break
			if not inside:
				n += 1
				min_at.x = mini(min_at.x, x)
				min_at.y = mini(min_at.y, y)
				max_at.x = maxi(max_at.x, x)
				max_at.y = maxi(max_at.y, y)
	if n > 0:
		print("L9_OUTSIDE_BOX %s %s" % [str(min_at), str(max_at)])
	return n


func _blit(dst: Image, src: Image, at: Vector2i) -> void:
	var copy := src.duplicate()
	if copy.get_format() != dst.get_format():
		copy.convert(dst.get_format())
	dst.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), at)
