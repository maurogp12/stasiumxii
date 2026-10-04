extends SceneTree

## Thunderwell before/after at 1280. Before is L7 suppressed, which is the
## base board. After is L7 on. Fighters are hidden so the pair is the board:
## the rim and the 68 px number stay on the fighters, not on the map.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l7_grade.gd -- --out=/tmp/l7_grade

const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")

var _out := "/tmp/l7_grade"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var dungeon := await _boot(Vector2i(1280, 720), "stormspire", "thunderwell")
	if dungeon.is_empty():
		quit(1)
		return
	var board: Node = dungeon["board"]
	_hide_fighters(board)
	var base := await _grab(board, true)
	var base_again := await _grab(board, true)
	var graded := await _grab(board, false)
	var delta := _delta(base, graded)
	var repeat_delta := _delta(base, base_again)
	print("L7_THUNDERWELL delta=%d repeat=%d size=%s" % [delta, repeat_delta, str(base.get_size())])
	var pair_path := _out.path_join("thunderwell_before_after_1280.png")
	_pair(_labeled(base, "THUNDERWELL    BASE"), _labeled(graded, "THUNDERWELL    L7 ON"), pair_path)
	dungeon["main"].free()
	LIGHT.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)
	Engine.time_scale = 1.0
	# The pillar beam flickers by a couple of levels between two base frames.
	# L7 is in if it does not add pixels beyond that.
	if delta > repeat_delta:
		push_error("thunderwell board changed by %d px, base repeat is %d" % [delta, repeat_delta])
		quit(1)
		return
	print("L7_GRADE pair=%s" % pair_path)
	quit(0)


func _boot(size: Vector2i, map_id: String, theme: String) -> Dictionary:
	HUD.set_pc_chrome_override(1)
	LIGHT.set_suppressed(true)
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
	sim.reset_match(PAIR.args(map_id))
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme(theme)
	for _i in 8:
		await process_frame
	_freeze(board)
	return {"main": main, "board": board}


func _hide_fighters(board: Node) -> void:
	for node_name in ["Units", "ShadeMarkers"]:
		var node := board.get_node_or_null(node_name) as CanvasItem
		if node == null:
			continue
		node.visible = false
		for child in node.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false


func _freeze(board: Node) -> void:
	Engine.time_scale = 0.0
	var floor = board.get_node_or_null("ThunderwellFloor")
	if floor != null:
		floor.set_process(false)
		if floor.has_method("preview_time"):
			floor.preview_time(0.35)
	var tile_script: GDScript = load("res://board/tile.gd")
	if tile_script != null:
		tile_script.set_move_pulse_frozen(true)
		tile_script.set_move_pulse_time(0.35)


func _grab(board: Node, off: bool) -> Image:
	LIGHT.set_suppressed(off)
	board._sync_look_light()
	_hide_fighters(board)
	_freeze(board)
	for _i in 3:
		await process_frame
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	var light = board.get_node_or_null("LookLight")
	var floor = board.get_node_or_null("ThunderwellFloor")
	var clock := -1.0
	if floor != null:
		clock = float(floor.get("_time"))
	if light != null:
		print("L7_GRAB off=%s sat=%.3f contrast=%.3f shade=%.2f vignette=%s clock=%.5f size=%s" % [str(off), light.grade_saturation(), light.grade_contrast(), light.grade_shade(), str(light.vignette_visible()), clock, str(image.get_size())])
	return image


func _delta(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _labeled(src: Image, caption: String) -> Image:
	var bar_h := 44
	var out := Image.create(src.get_width(), src.get_height() + bar_h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.10, 0.09, 0.08, 1))
	_blit(out, src, Vector2i(0, bar_h))
	_stamp(out, caption, 16, 12)
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


## 5x7 glyphs. Enough to name the two Thunderwell frames.
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
		"D": [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110],
		"E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
		"H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
		"L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
		"N": [0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001],
		"O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
		"R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
		"S": [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110],
		"T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
		"U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
		"W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010],
		"7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
	}
