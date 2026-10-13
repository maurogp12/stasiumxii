extends SceneTree

## Windmere on a 1080p phone. A pan used to land on a half device pixel every
## other step, so the ice, snow blocks, and crystals changed brightness.
## Weather and pawns are frozen. A pixel that matches neither the previous
## frame nor that frame shifted by the camera step is flicker.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_windmere_flicker.gd -- --mobile-frame

const FRAMES := 6
## Stride-4 samples whose color moves by 40 or more, after the best whole-pixel
## shift. The broken snap left several thousand of these on the ice edges.
const PAN_LIMIT := 800

var _phase := "boot"
var _frames := 0
var _beats := 0
var _failed := false
var _prev := PackedByteArray()
var _pw := 0
var _ph := 0
var _origin := Vector2.ZERO
var _have_origin := false


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--mobile-frame"):
		push_error("pass --mobile-frame so the 1080p stretch is the phone scale")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var cs: GDScript = load("res://scenes/class_select.gd")
	cs.set("hotseat_classes", ["kestrel", "bastion"])
	cs.set("hotseat_map_id", "windmere")
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_beats += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null:
		if _beats > 900:
			_fail("board never opened")
			return true
		return false
	if _phase == "boot":
		if not bool(board.get("_booted")):
			if _beats > 900:
				_fail("match never booted")
				return true
			return false
		_open(board)
		_phase = "settle"
		_frames = 0
		return false
	if _phase == "settle":
		_frames += 1
		if _frames == 3:
			DisplayServer.window_set_size(Vector2i(2400, 1080))
			root.size = Vector2i(2400, 1080)
		if _frames < 10:
			return false
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera()
		_freeze(board)
		_phase = "still"
		_frames = 0
		_prev = PackedByteArray()
		_have_origin = false
		return false
	if _phase == "still":
		_frames += 1
		_note(board, "still")
		if _failed:
			return true
		if _frames < FRAMES:
			return false
		_phase = "pan"
		_frames = 0
		_prev = PackedByteArray()
		_have_origin = false
		return false
	if _phase == "pan":
		_frames += 1
		board._pan_limit = Vector2(500.0, 400.0)
		board._queue_pan(Vector2(3.0, 2.0))
		board._apply_pending_pan()
		_note(board, "pan")
		if _failed:
			return true
		if _frames < FRAMES:
			return false
		print("WINDMERE FLICKER ok")
		quit(0)
		return true
	return false


func _open(board: Node) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": "windmere",
		"classes": ["kestrel", "bastion"],
		"positions": [Vector2i(2, 6), Vector2i(11, 3)],
	})
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
	board.set_process(false)


func _freeze(board: Node) -> void:
	Engine.time_scale = 0.0
	var sky := board.get_node_or_null("ArenaSky")
	if sky != null:
		for node_name in ["SnowFall", "AmbientMotes", "StormBolts"]:
			var node := sky.get_node_or_null(node_name)
			if node != null:
				node.visible = false
				node.set_process(false)
	var life := board.get_node_or_null("KoliseoLife")
	if life != null:
		life.set_process(false)
		var motes := life.get_node_or_null("Motes")
		if motes != null:
			motes.emitting = false
			motes.visible = false
		var glow := life.get_node_or_null("Light")
		if glow != null:
			glow.visible = false
	_pause_tree(board.find_child("Tiles", true, false))
	_pause_tree(board.find_child("Units", true, false))


func _pause_tree(node: Node) -> void:
	if node == null:
		return
	if node is AnimatedSprite2D:
		(node as AnimatedSprite2D).pause()
	node.set_process(false)
	for child in node.get_children():
		_pause_tree(child)


func _note(board: Node, label: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var raw := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var cam: Camera2D = board.get("_camera")
	var view: Vector2 = board.get_viewport_rect().size
	var origin := Vector2.ZERO
	if cam != null and view.x > 1.0:
		origin = Vector2(view.x * 0.5 - cam.position.x * cam.zoom.x, view.y * 0.5 - cam.position.y * cam.zoom.y)
	if _prev.is_empty() or _pw != width or _ph != height:
		_prev = raw
		_pw = width
		_ph = height
		_origin = origin
		_have_origin = true
		return
	var shift := Vector2i.ZERO
	if _have_origin and view.x > 1.0 and view.y > 1.0:
		shift = Vector2i(
			roundi((origin.x - _origin.x) * float(width) / view.x),
			roundi((origin.y - _origin.y) * float(height) / view.y)
		)
	var window := Vector2(DisplayServer.window_get_size())
	var scale := BoardVisualSort.viewport_pixel_scale(view, window)
	var device := Vector2(origin.x * scale.x, origin.y * scale.y)
	if absf(device.x - roundf(device.x)) > 0.05 or absf(device.y - roundf(device.y)) > 0.05:
		_fail("%s frame %d device origin %s is not a whole pixel" % [label, _frames, device])
		return
	var hot := _hot(raw, width, height, shift)
	print("WINDMERE %s frame %d shift %s device %s hot %d" % [label, _frames, shift, device, hot])
	if label == "still" and hot > 0:
		_fail("still frame %d changed %d samples" % [_frames, hot])
	elif label == "pan" and hot > PAN_LIMIT:
		_fail("pan frame %d left %d shimmering samples (limit %d)" % [_frames, hot, PAN_LIMIT])
	_prev = raw
	_origin = origin


## Samples that match neither the unshifted frame nor the camera shift,
## searching one pixel around the measured step. Only a jump of 40 or more
## counts, so a soft edge is not a z-swap.
func _hot(raw: PackedByteArray, width: int, height: int, shift: Vector2i) -> int:
	var best := 1 << 30
	var search := 1 if shift != Vector2i.ZERO else 0
	for dy in range(-search, search + 1):
		for dx in range(-search, search + 1):
			best = mini(best, _count(raw, width, height, shift + Vector2i(dx, dy)))
	return best


func _count(raw: PackedByteArray, width: int, height: int, shift: Vector2i) -> int:
	var row := width * 4
	var hot := 0
	for y in range(8, height - 8, 4):
		for x in range(8, width - 8, 4):
			var a := y * row + x * 4
			if _close(raw, a, _prev, a):
				continue
			var slid := false
			if shift != Vector2i.ZERO:
				var px := x - shift.x
				var py := y - shift.y
				if px >= 0 and py >= 0 and px < width and py < height:
					slid = _close(raw, a, _prev, py * row + px * 4)
				else:
					slid = true
			if not slid:
				hot += 1
	return hot


func _close(raw: PackedByteArray, a: int, prev: PackedByteArray, b: int) -> bool:
	return absi(int(raw[a]) - int(prev[b])) < 40 and absi(int(raw[a + 1]) - int(prev[b + 1])) < 40 and absi(int(raw[a + 2]) - int(prev[b + 2])) < 40


func _fail(msg: String) -> void:
	_failed = true
	push_error(msg)
	print("WINDMERE FLICKER FAIL %s" % msg)
	quit(1)
