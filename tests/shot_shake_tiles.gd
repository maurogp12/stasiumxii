extends SceneTree

## 60fps check: a crit punch and a trap punch never drop a tile or change
## tile order. Shaders are paused. Each frame has to be the still board
## slid by the punch's whole-pixel offset.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --fixed-fps 60 --path . -s res://tests/shot_shake_tiles.gd -- /opt/cursor/artifacts/shake_tiles --mobile-frame

const KOLISEO := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const PUNCHES := [
	{"name": "crit", "px": 14.0, "sec": 0.20},
	{"name": "trap", "px": 16.0, "sec": 0.22},
]
const FRAMES := 24

var _out := "/tmp/shake_tiles"
var _only := ""
var _steps: Array = []
var _index := 0
var _phase := "boot"
var _frames := 0
var _opened := -1
var _open_waits := 0
var _punch := 0
var _order := ""
var _base := PackedByteArray()
var _base_w := 0
var _base_h := 0
var _canvas7 := Vector2.ZERO
var _max_shift := 0.0
var _misses := 0
var _worst := 0
var _thin := 0
var _order_breaks := 0
var _samples := 0
var _failed := 0
var _log: FileAccess


func _initialize() -> void:
	var positional: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("--"):
			positional.append(str(arg))
	if positional.size() > 0:
		_out = positional[0]
	if positional.size() > 1:
		_only = positional[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_log = FileAccess.open(_out.path_join("shake_tiles.txt"), FileAccess.WRITE)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	for biome in KOLISEO:
		if _only != "" and _only != "stasis" and biome != _only:
			continue
		if _only != "stasis":
			_steps.append({"kind": "koliseo", "biome": biome, "room": ""})
		if _only == "" or _only == "stasis" or _only == biome:
			_steps.append({"kind": "stasis", "biome": biome, "room": "a"})
			_steps.append({"kind": "stasis", "biome": biome, "room": "b"})
	var cs: GDScript = load("res://scenes/class_select.gd")
	cs.set("hotseat_classes", ["ironjaw", "gloam"])
	cs.set("hotseat_map_id", "crosshaven")
	change_scene_to_file("res://main.tscn")
	_phase = "open"


func _process(_delta: float) -> bool:
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null:
		return false
	if _index >= _steps.size():
		_finish()
		return true
	var step: Dictionary = _steps[_index]
	if _phase == "open":
		if str(step["kind"]) == "stasis":
			if _opened != _index:
				_open_stasis(step)
				_opened = _index
				return false
			if not str(current_scene.scene_file_path).contains("stasis") or not bool(board.get("_booted")):
				return _wait_open(step)
			board._ai_running = true
		else:
			if not bool(board.get("_booted")):
				return _wait_open(step)
			_open_koliseo(board, str(step["biome"]))
		board.set_process(false)
		_open_waits = 0
		_phase = "settle"
		_frames = 0
		return false
	if _phase == "settle":
		_frames += 1
		if _frames < 8:
			return false
		_freeze(board)
		board._arm_shake_cull()
		_phase = "baseline"
		_frames = 0
		_punch = 0
		return false
	if _phase == "baseline":
		_frames += 1
		if _frames < 2:
			return false
		_capture(board)
		var spec: Dictionary = PUNCHES[_punch]
		# The tween clock is paused with the shaders. Step the same punch the
		# tween would call, one 60fps sample at a time, so the picture stays still.
		board.punch_camera(float(spec["px"]), float(spec["sec"]))
		if board._shake_tween != null and is_instance_valid(board._shake_tween):
			board._shake_tween.kill()
		board._set_view_shake(Vector2.ZERO)
		_phase = "punch"
		_frames = 0
		_max_shift = 0.0
		_misses = 0
		_worst = 0
		_thin = 0
		_order_breaks = 0
		_samples = 0
		return false
	if _phase == "punch":
		_frames += 1
		_note(board, step, str(PUNCHES[_punch]["name"]))
		if _frames < FRAMES:
			_step_punch(board)
			return false
		_report_punch(step, str(PUNCHES[_punch]["name"]))
		board._set_view_shake(Vector2.ZERO)
		if board._shake_tween != null and is_instance_valid(board._shake_tween):
			board._shake_tween.kill()
		_punch += 1
		if _punch < PUNCHES.size():
			_phase = "baseline"
			_frames = 0
			return false
		_index += 1
		_opened = -1
		_phase = "open"
		_frames = 0
		if _index < _steps.size() and str(_steps[_index]["kind"]) == "koliseo":
			change_scene_to_file("res://main.tscn")
		return false
	return false


func _open_koliseo(board: Node, map_id: String) -> void:
	Engine.time_scale = 1.0
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": map_id,
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(3, 3), Vector2i(11, 11)],
	})
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera()


func _open_stasis(step: Dictionary) -> void:
	Engine.time_scale = 1.0
	StasisCatalog.clear_run()
	MobileHub.pending_biome_id = str(step["biome"])
	StasisCatalog.begin(str(step["biome"]))
	StasisCatalog.class_id = "ironjaw"
	StasisCatalog.room = str(step["room"])
	change_scene_to_file(StasisCatalog.FIGHT_SCENE)


func _wait_open(step: Dictionary) -> bool:
	_open_waits += 1
	if _open_waits > 600:
		_fail("%s %s did not open" % [str(step["kind"]), str(step["biome"])])
		_index += 1
		_phase = "open"
		_opened = -1
	return false


func _freeze(board: Node) -> void:
	# Shader TIME and weather stop. A changed pixel is the floor moving, not lava.
	Engine.time_scale = 0.0
	if board._focus_tween != null and is_instance_valid(board._focus_tween):
		board._focus_tween.kill()
	var units := board.find_child("Units", true, false)
	if units is CanvasItem:
		(units as CanvasItem).visible = false
	var vfx: Node = board.get("_vfx")
	if vfx is CanvasItem:
		(vfx as CanvasItem).visible = false
	var aim: Node = board.get("_aim_line")
	if aim is CanvasItem:
		(aim as CanvasItem).visible = false
	var sky := board.get_node_or_null("WorldShake/ArenaSky")
	if sky == null:
		sky = board.find_child("ArenaSky", true, false)
	if sky != null:
		for node_name in ["SnowFall", "AmbientMotes", "StormBolts"]:
			var node := sky.get_node_or_null(node_name)
			if node != null:
				node.visible = false
				node.set_process(false)
	_hide_decor(board.find_child("Tiles", true, false))
	var life := board.find_child("KoliseoLife", true, false)
	if life != null:
		life.set_process(false)
		var motes := life.get_node_or_null("Motes")
		if motes != null:
			motes.emitting = false
			motes.visible = false
		var glow := life.get_node_or_null("Light")
		if glow != null:
			glow.visible = false


func _capture(board: Node) -> void:
	_order = _tile_order(board)
	var image := _image()
	if image == null:
		_base = PackedByteArray()
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_base = image.get_data()
	_base_w = image.get_width()
	_base_h = image.get_height()
	var tile: Node2D = board.tiles.get(Vector2i(7, 7))
	_canvas7 = tile.get_global_transform_with_canvas().origin if tile != null else Vector2.ZERO


## Banners, mist, and floor decals keep their own clock. The diamonds underneath
## are the tiles the shake was dropping.
func _hide_decor(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		_hide_decor(child)
		if child is BoardTile or child.get_parent() is BoardTile:
			continue
		if child is Sprite2D or child is AnimatedSprite2D:
			(child as CanvasItem).visible = false


## The picture on screen was drawn with the shake applied last frame. Interior
## tile pixels have to be that still frame slid by one shared offset. The HUD
## stays put, and the diamond's outer edge meets the sky, so neither counts.
func _note(board: Node, step: Dictionary, punch: String) -> void:
	var order := _tile_order(board)
	if order != _order:
		_order_breaks += 1
		_fail("%s %s %s frame %d tile order changed" % [str(step["kind"]), str(step["biome"]), punch, _frames])
		_order = order
	if board._camera != null and board._camera.offset.length() > 0.01:
		_fail("%s %s %s camera offset moved" % [str(step["kind"]), str(step["biome"]), punch])
	var image := _image()
	if image == null or _base.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var raw := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	if width != _base_w or height != _base_h:
		_fail("%s %s %s viewport size changed" % [str(step["kind"]), str(step["biome"]), punch])
		return
	var expect := _image_shift(board)
	var best := expect
	var best_n := 1 << 30
	var best_checked := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var score := _tally(raw, width, height, expect + Vector2i(dx, dy))
			if int(score.x) < best_n:
				best_n = int(score.x)
				best_checked = int(score.y)
				best = expect + Vector2i(dx, dy)
	_samples += best_checked
	_misses += best_n
	_worst = maxi(_worst, best_n)
	# One vanished diamond covers dozens of samples. A handful is the
	# stretch filter on a hard edge, which the trap's larger slide shows.
	if best_n > 8:
		_fail("%s %s %s frame %d %d tile pixels moved on their own" % [str(step["kind"]), str(step["biome"]), punch, _frames, best_n])
	if best_checked < 80:
		_thin += 1
		_fail("%s %s %s frame %d saw %d tile pixels" % [str(step["kind"]), str(step["biome"]), punch, _frames, best_checked])


func _step_punch(board: Node) -> void:
	var spec: Dictionary = PUNCHES[_punch]
	var dur := maxi(1, roundi(float(spec["sec"]) * 60.0))
	var step_i := _frames - 1
	if step_i < dur:
		board._apply_punch(float(step_i) / float(dur), float(spec["px"]))
	else:
		board._set_view_shake(Vector2.ZERO)
	_max_shift = maxf(_max_shift, _shift_of(board))


## Canvas pixels, times the window stretch, in the framebuffer.
func _image_shift(board: Node) -> Vector2i:
	var tile: Node2D = board.tiles.get(Vector2i(7, 7))
	if tile == null:
		return Vector2i.ZERO
	var delta := tile.get_global_transform_with_canvas().origin - _canvas7
	var scale := root.get_final_transform().get_scale()
	return Vector2i(roundi(delta.x * scale.x), roundi(delta.y * scale.y))


const STRIDE := 8
const INSET_L := 360
const INSET_T := 340
const INSET_R := 360
const INSET_B := 380


## Interior floor pixels. A hit matches the still tile slid by `shift`, or the
## HUD pixel that was already there. Sky along the diamond edge is not interior.
func _tally(raw: PackedByteArray, width: int, height: int, shift: Vector2i) -> Vector2i:
	var row := width * 4
	var x0 := INSET_L
	var y0 := INSET_T
	var x1 := width - INSET_R
	var y1 := height - INSET_B
	var bad := 0
	var checked := 0
	var y := y0
	while y < y1:
		var x := x0
		while x < x1:
			var a := y * row + x * 4
			if not _sky_at(_base, a) and not _fringe(width, x, y):
				var qx := x + shift.x
				var qy := y + shift.y
				if qx >= x0 and qy >= y0 and qx < x1 and qy < y1:
					checked += 1
					var b := qy * row + qx * 4
					if not _near_at(raw, b, _base, a) and not _near_at(raw, b, _base, b):
						bad += 1
			x += STRIDE
		y += STRIDE
	return Vector2i(bad, checked)


func _fringe(width: int, x: int, y: int) -> bool:
	var row := width * 4
	for step in [Vector2i(-STRIDE, 0), Vector2i(STRIDE, 0), Vector2i(0, -STRIDE), Vector2i(0, STRIDE)]:
		var nx: int = x + int(step.x)
		var ny: int = y + int(step.y)
		if nx < 0 or ny < 0 or nx >= width or ny >= _base_h:
			return true
		if _sky_at(_base, ny * row + nx * 4):
			return true
	return false


func _sky_at(raw: PackedByteArray, i: int) -> bool:
	var r := int(raw[i])
	var g := int(raw[i + 1])
	var b := int(raw[i + 2])
	return r < 31 and g < 41 and b < 71 and b + 5 >= r


func _near_at(a: PackedByteArray, ia: int, b: PackedByteArray, ib: int) -> bool:
	return absi(int(a[ia]) - int(b[ib])) <= 2 and absi(int(a[ia + 1]) - int(b[ib + 1])) <= 2 and absi(int(a[ia + 2]) - int(b[ib + 2])) <= 2


func _shift_of(board: Node) -> float:
	var world: Node2D = board.get("_world")
	if world == null or board._camera == null:
		return 0.0
	return world.position.length() * board._camera.zoom.x


func _report_punch(step: Dictionary, punch: String) -> void:
	var label := "%s %s%s %s" % [str(step["kind"]), str(step["biome"]), str(step["room"]), punch]
	var bad := _order_breaks > 0 or _worst > 8 or _thin > 0 or _max_shift < 8.0
	if bad:
		_failed += 1
	var line := "%s shift=%.2f samples=%d misses=%d worst=%d order=%d %s" % [label, _max_shift, _samples, _misses, _worst, _order_breaks, "FAIL" if bad else "ok"]
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _tile_order(board: Node) -> String:
	var tiles := board.find_child("Tiles", true, false)
	if tiles == null:
		return ""
	return _order_of(tiles, "")


func _order_of(node: Node, prefix: String) -> String:
	var parts := prefix
	var index := 0
	for child in node.get_children():
		if child is CanvasItem:
			var item := child as CanvasItem
			parts += "%s/%s@%d#%d;" % [prefix, str(child.name), item.z_index, index]
		if child.get_child_count() > 0 and str(child.name) != "Units":
			parts += _order_of(child, prefix + "/" + str(child.name))
		index += 1
	return parts


func _image() -> Image:
	var tex := root.get_texture()
	if tex == null:
		return null
	return tex.get_image()


func _fail(msg: String) -> void:
	push_error(msg)
	if _log != null:
		_log.store_line("FAIL " + msg)
		_log.flush()


func _finish() -> void:
	var line := "shake tiles: %d maps failed" % _failed
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()
	quit(1 if _failed > 0 else 0)
