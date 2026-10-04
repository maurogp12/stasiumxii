extends SceneTree

## Off, light, and medium on the v1.3 Crosshaven board. Same match and camera
## as the before/after pair. The shipped preset stays off.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l9_grade.gd -- --out=/tmp/l9_grade

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")

var _out := "/tmp/l9_grade"


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
	var off := await _grab(board, LIGHT.PRESET_OFF)
	var light := await _grab(board, LIGHT.PRESET_LIGHT)
	var medium := await _grab(board, LIGHT.PRESET_MEDIUM)
	var path := _out.path_join("grade_options_1280.png")
	_row([
		_labeled(off, "OFF"),
		_labeled(light, "LIGHT"),
		_labeled(medium, "MEDIUM"),
	], path)
	print("L9_GRADE %s %s" % [path, str(off.get_size())])
	shot["main"].free()
	LIGHT.set_outdoor_preset(LIGHT.PRESET_OFF)
	LIGHT.set_suppressed(false)
	BOARD.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)
	Engine.time_scale = 1.0
	quit(0)


func _boot() -> Dictionary:
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	LIGHT.set_suppressed(false)
	LIGHT.set_outdoor_preset(LIGHT.PRESET_OFF)
	var size := Vector2i(1280, 720)
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


func _grab(board: Node, preset: String) -> Image:
	LIGHT.set_outdoor_preset(preset)
	board._sync_look_light()
	_freeze(board)
	_plant_bodies(board)
	for _i in 4:
		await process_frame
	_plant_bodies(board)
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	var light = board.get_node_or_null("LookLight")
	var sat := 1.0
	var contrast := 1.0
	if light != null:
		sat = light.grade_saturation()
		contrast = light.grade_contrast()
	print("L9_GRADE_GRAB preset=%s sat=%.2f contrast=%.2f" % [preset, sat, contrast])
	if image.get_width() != 1280 or image.get_height() != 720:
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	return image


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
		"D": [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110],
		"E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
		"F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
		"G": [0b01110, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110],
		"H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
		"I": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111],
		"L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
		"M": [0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001],
		"O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
		"T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
		"U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
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
