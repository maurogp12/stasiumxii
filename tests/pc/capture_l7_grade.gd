extends SceneTree

## Crosshaven grade sheet and the before/after pair.
## Base is this build with the grade forced off, which matches pc/combat-look.
## Light, medium, and strong are the three outdoor strengths. Medium is the
## interim default. Dungeon is the accepted Thunderwell grade, unchanged.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l7_grade.gd -- --out=/tmp/l7_grade

const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")

var _out := "/tmp/l7_grade"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var outdoor := await _boot(Vector2i(1280, 720), "crosshaven", "")
	if outdoor.is_empty():
		quit(1)
		return
	var board: Node = outdoor["board"]
	var base := await _grab(board, "", true)
	var light := await _grab(board, LIGHT.PRESET_LIGHT, false)
	var medium := await _grab(board, LIGHT.PRESET_MEDIUM, false)
	var strong := await _grab(board, LIGHT.PRESET_STRONG, false)
	_report_delta("base_light", base, light)
	_report_delta("base_medium", base, medium)
	_report_delta("light_medium", light, medium)
	_report_delta("medium_strong", medium, strong)
	var sheet := _row([
		_labeled(base, "BASE    PC/COMBAT-LOOK"),
		_labeled(light, "LIGHT    SAT 1.10"),
		_labeled(medium, "MEDIUM    SAT 1.15    INTERIM"),
		_labeled(strong, "CURRENT    SAT 1.55    TOO STRONG"),
	])
	var sheet_path := _out.path_join("grade_strengths_1280.png")
	sheet.save_png(sheet_path)
	_pair(base, medium, _out.path_join("before_after_1280.png"))
	outdoor["main"].free()
	await process_frame

	var wide := await _boot(Vector2i(1920, 1080), "crosshaven", "")
	if wide.is_empty():
		quit(1)
		return
	var wide_board: Node = wide["board"]
	var wide_base := await _grab(wide_board, "", true)
	var wide_medium := await _grab(wide_board, LIGHT.PRESET_MEDIUM, false)
	_pair(wide_base, wide_medium, _out.path_join("before_after_1920.png"))
	wide["main"].free()
	await process_frame

	var dungeon := await _boot(Vector2i(1280, 720), "stormspire", "thunderwell")
	if dungeon.is_empty():
		quit(1)
		return
	var dungeon_frame := await _grab(dungeon["board"], LIGHT.PRESET_MEDIUM, false)
	var dungeon_path := _out.path_join("dungeon_1280.png")
	_labeled(dungeon_frame, "THUNDERWELL    DUNGEON GRADE UNCHANGED").save_png(dungeon_path)
	dungeon["main"].free()
	LIGHT.set_outdoor_preset(LIGHT.PRESET_MEDIUM)
	LIGHT.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)
	Engine.time_scale = 1.0
	print("L7_GRADE sheet=%s dungeon=%s" % [sheet_path, dungeon_path])
	quit(0)


func _boot(size: Vector2i, map_id: String, theme: String) -> Dictionary:
	HUD.set_pc_chrome_override(1)
	LIGHT.set_outdoor_preset(LIGHT.PRESET_MEDIUM)
	LIGHT.set_suppressed(false)
	Engine.time_scale = 1.0
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
	sim.reset_match({
		"seed": 1,
		"map_id": map_id,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": Vector2i(9, 7),
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme(theme)
	for _i in 8:
		await process_frame
	var jungle := board.get_node_or_null("JungleBackdrop")
	if jungle != null and jungle.has_method("preview_time"):
		jungle.preview_time(0.35)
	Engine.time_scale = 0.0
	await process_frame
	RenderingServer.force_draw()
	return {"main": main, "board": board}


func _grab(board: Node, preset: String, off: bool) -> Image:
	if off:
		LIGHT.set_suppressed(true)
	else:
		LIGHT.set_suppressed(false)
		LIGHT.set_outdoor_preset(preset)
	board._sync_look_light()
	var jungle := board.get_node_or_null("JungleBackdrop")
	if jungle != null and jungle.has_method("preview_time"):
		jungle.preview_time(0.35)
	for _i in 3:
		await process_frame
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	var light = board.get_node_or_null("LookLight")
	if light != null:
		print("L7_GRAB preset=%s off=%s sat=%.3f contrast=%.3f shade=%.2f bias=%s size=%s" % [preset if not off else "base", str(off), light.grade_saturation(), light.grade_contrast(), light.grade_shade(), str(light.grade_bias()), str(image.get_size())])
	return image


func _labeled(src: Image, caption: String) -> Image:
	var bar_h := 44
	var out := Image.create(src.get_width(), src.get_height() + bar_h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.10, 0.09, 0.08, 1))
	_blit(out, src, Vector2i(0, bar_h))
	_stamp(out, caption, 16, 12)
	return out


func _row(panels: Array) -> Image:
	var gap := 8
	var width := gap * (panels.size() - 1)
	var height := 0
	for panel in panels:
		var image: Image = panel
		width += image.get_width()
		height = maxi(height, image.get_height())
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.07, 0.06, 1))
	var x := 0
	for panel in panels:
		var image: Image = panel
		_blit(out, image, Vector2i(x, 0))
		x += image.get_width() + gap
	return out


func _pair(left: Image, right: Image, path: String) -> void:
	var gap := 8
	var out := Image.create(left.get_width() + right.get_width() + gap, maxi(left.get_height(), right.get_height()), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.07, 0.06, 1))
	_blit(out, left, Vector2i(0, 0))
	_blit(out, right, Vector2i(left.get_width() + gap, 0))
	out.save_png(path)
	print("L7_PAIR %s" % path)


func _blit(dst: Image, src: Image, at: Vector2i) -> void:
	var copy := src.duplicate()
	if copy.get_format() != dst.get_format():
		copy.convert(dst.get_format())
	dst.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), at)


## 5x7 glyphs. Enough to name the four strengths without a second viewport.
func _stamp(dst: Image, text: String, x: int, y: int) -> void:
	var glyphs := _glyphs()
	var scale := 3
	var cursor := x
	var ink := Color(0.96, 0.93, 0.86, 1)
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch == " ":
			cursor += 4 * scale
			continue
		var rows: Array = glyphs.get(ch, [])
		for row in rows.size():
			var bits: int = int(rows[row])
			for col in 5:
				if (bits & (1 << (4 - col))) == 0:
					continue
				for sy in scale:
					for sx in scale:
						var px := cursor + col * scale + sx
						var py := y + int(row) * scale + sy
						if px >= 0 and py >= 0 and px < dst.get_width() and py < dst.get_height():
							dst.set_pixel(px, py, ink)
		cursor += 6 * scale


func _glyphs() -> Dictionary:
	return {
		"A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
		"B": [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110],
		"C": [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110],
		"D": [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110],
		"E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
		"G": [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110],
		"H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
		"F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
		"I": [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
		"K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
		"L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
		"M": [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001],
		"N": [0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001],
		"O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
		"P": [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000],
		"R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
		"S": [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110],
		"T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
		"U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
		"W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010],
		"Y": [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100],
		"0": [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110],
		"1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
		"3": [0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110],
		"5": [0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110],
		".": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b01100],
		"/": [0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b00000, 0b00000],
		"-": [0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000],
	}


func _report_delta(name: String, left: Image, right: Image) -> void:
	var w := mini(left.get_width(), right.get_width())
	var h := mini(left.get_height(), right.get_height())
	var step := 8
	var n := 0
	var acc := 0.0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var a := left.get_pixel(x, y)
			var b := right.get_pixel(x, y)
			acc += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			n += 1
			x += step
		y += step
	var mean := 0.0 if n == 0 else acc / float(n)
	print("L7_DELTA %s mean_abs=%.4f" % [name, mean])
