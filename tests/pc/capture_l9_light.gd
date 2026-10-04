extends SceneTree

## Mauro's light-grade stills and a short walk. Zoom 1.0 and 1.6 are camera
## zoom, with move, range, and hover up. Off sits beside light at zoom 1.0.
## The clip is a walk with the move range up, under the shipped light grade.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l9_light.gd -- --out=/tmp/l9_light

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")
const TILE := preload("res://board/tile.gd")

var _out := "/tmp/l9_light"
var _size := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var shot := await _boot()
	if shot.is_empty():
		quit(1)
		return
	var board: Node = shot["board"]
	_show_read(board)
	_set_zoom(board, 1.0)
	var light_1 := await _grab(board, LIGHT.PRESET_LIGHT)
	light_1.save_png(_out.path_join("light_zoom_1.png"))
	_set_zoom(board, 1.6)
	var light_16 := await _grab(board, LIGHT.PRESET_LIGHT)
	light_16.save_png(_out.path_join("light_zoom_1_6.png"))
	_set_zoom(board, 1.0)
	var off := await _grab(board, LIGHT.PRESET_OFF)
	var light := await _grab(board, LIGHT.PRESET_LIGHT)
	var pair := _out.path_join("off_beside_light.png")
	_row([_labeled(off, "OFF"), _labeled(light, "LIGHT")], pair)
	print("L9_LIGHT stills zoom1=%s zoom16=%s pair=%s" % [str(light_1.get_size()), str(light_16.get_size()), pair])
	var walked := await _clip(board, shot["sim"])
	LIGHT.set_outdoor_preset(LIGHT.SHIPPED_OUTDOOR_PRESET)
	LIGHT.set_suppressed(false)
	BOARD.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	shot["main"].free()
	quit(0 if walked else 1)


func _boot() -> Dictionary:
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	LIGHT.set_suppressed(false)
	LIGHT.set_outdoor_preset(LIGHT.PRESET_LIGHT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	DisplayServer.window_set_size(_size)
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
	return {"main": main, "board": board, "sim": sim}


func _show_read(board: Node) -> void:
	board._paint_highlights()
	var range_at := Vector2i(7, 2)
	var hover_at := Vector2i(10, 9)
	if board.tiles.has(range_at):
		board._tile_at(range_at).set_highlight("range")
	if board.tiles.has(hover_at):
		var hover: BoardTile = board._tile_at(hover_at)
		hover.set_highlight("")
		hover._reveal = 0.0
		hover._reveal_target = 0.0
		hover.set_soft_hover(true)
	TILE.set_move_pulse_frozen(true)
	TILE.set_move_pulse_time(0.0)
	var moves := 0
	var ranges := 0
	var hovers := 0
	for cell in board.tiles.keys():
		var tile: BoardTile = board.tiles[cell]
		if tile.highlight == "move" or tile.highlight == "range":
			tile._reveal = 1.0
			tile._reveal_target = 1.0
			tile._shown_highlight = tile.highlight
		if tile.highlight == "move":
			moves += 1
		elif tile.highlight == "range":
			ranges += 1
		if tile.soft_hover:
			hovers += 1
	print("L9_READ moves=%d range=%d hover=%d" % [moves, ranges, hovers])


func _set_zoom(board: Node, zoom: float) -> void:
	board._fit_board_camera()
	var cam := board.get_node("BoardCamera") as Camera2D
	var fit_zoom := cam.zoom.x
	var view_w := float(board.VIEW_W)
	var view_h := float(board.VIEW_H)
	var play_center := Vector2(view_w * 0.5, (float(board.PLAY_TOP) + float(board.PLAY_BOTTOM)) * 0.5)
	var view_center := Vector2(view_w * 0.5, view_h * 0.5)
	var shift := play_center - view_center
	var center := cam.position + shift / fit_zoom
	cam.zoom = Vector2(zoom, zoom)
	cam.position = center - shift / zoom


func _grab(board: Node, preset: String) -> Image:
	LIGHT.set_outdoor_preset(preset)
	board._sync_look_light()
	_plant(board)
	for _i in 3:
		await process_frame
	_plant(board)
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	var light = board.get_node_or_null("LookLight")
	var sat := 1.0
	var contrast := 1.0
	if light != null:
		sat = light.grade_saturation()
		contrast = light.grade_contrast()
	print("L9_LIGHT_GRAB preset=%s sat=%.2f contrast=%.2f" % [preset, sat, contrast])
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	return image


func _clip(board: Node, sim: Node) -> bool:
	Engine.max_fps = 20
	Engine.time_scale = 0.35
	LIGHT.set_outdoor_preset(LIGHT.PRESET_LIGHT)
	board._sync_look_light()
	_set_zoom(board, 1.0)
	var dir := _out.path_join("walk")
	DirAccess.make_dir_recursive_absolute(dir)
	var frame := 0
	for _i in 12:
		await process_frame
		frame = _save(dir, frame)
	var pawn: Node = board.get("pawns_by_seat")[0]
	var home: Vector2 = pawn.global_position
	var walked: Dictionary = sim.submit({"type": "move", "to": Vector2i(7, 5)})
	if not bool(walked.get("ok", false)):
		push_error("walk failed %s" % str(walked))
		return false
	var path: Array = []
	var origin := Vector2i(7, 7)
	for event in walked.get("events", []):
		if event is Dictionary and (event as Dictionary).has("path"):
			path = (event as Dictionary).get("path", [])
			origin = board._as_cell((event as Dictionary).get("from", origin))
	board._play_walk(0, path, origin)
	var moved := false
	for _i in 36:
		await process_frame
		if pawn.global_position.distance_to(home) > 12.0:
			moved = true
		frame = _save(dir, frame)
	while frame < 60:
		await process_frame
		frame = _save(dir, frame)
	print("L9_WALK frames=%d walked=%s dir=%s" % [frame, str(moved), dir])
	return moved and frame == 60


func _save(dir: String, frame: int) -> int:
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(dir.path_join("frame_%04d.png" % frame))
	return frame + 1


func _plant(board: Node) -> void:
	var pawns: Dictionary = board.get("pawns_by_seat")
	for seat in pawns.keys():
		var pawn: Node = pawns[seat]
		if pawn.has_method("hold_idle"):
			pawn.hold_idle()


func _labeled(src: Image, caption: String) -> Image:
	var bar_h := 36
	var out := Image.create(src.get_width(), src.get_height() + bar_h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.10, 0.09, 0.08, 1))
	_blit(out, src, Vector2i(0, bar_h))
	_stamp(out, caption, 16, 8)
	return out


func _row(frames: Array, path: String) -> void:
	var gap := 8
	var width := 0
	var height := 0
	for frame in frames:
		var image := frame as Image
		width += image.get_width()
		height = maxi(height, image.get_height())
	width += gap * (frames.size() - 1)
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.07, 0.06, 1))
	var x := 0
	for frame in frames:
		var image := frame as Image
		_blit(out, image, Vector2i(x, 0))
		x += image.get_width() + gap
	out.save_png(path)


func _blit(dst: Image, src: Image, at: Vector2i) -> void:
	var copy := src.duplicate()
	if copy.get_format() != dst.get_format():
		copy.convert(dst.get_format())
	dst.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), at)


func _stamp(dst: Image, text: String, x: int, y: int) -> void:
	var glyphs := {
		"F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
		"G": [0b01110, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110],
		"H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
		"I": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111],
		"L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
		"O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
		"T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
	}
	var scale := 2
	var cursor := x
	var ink := Color(0.96, 0.93, 0.86, 1)
	for i in text.length():
		var rows: Array = glyphs.get(text.substr(i, 1), [])
		for row in rows.size():
			var bits: int = int(rows[row])
			for col in 5:
				if (bits & (1 << (4 - col))) == 0:
					continue
				for sy in scale:
					for sx in scale:
						dst.set_pixel(cursor + col * scale + sx, y + int(row) * scale + sy, ink)
		cursor += 6 * scale
