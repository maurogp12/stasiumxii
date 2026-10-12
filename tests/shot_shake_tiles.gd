extends SceneTree

## 60fps check: a crit punch and a trap punch never drop a tile or change
## tile order. Weather is frozen and fighters are hidden so a changed pixel
## at a tile center is the floor, not a body.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --fixed-fps 60 --path . -s res://tests/shot_shake_tiles.gd -- /opt/cursor/artifacts/shake_tiles --mobile-frame

const KOLISEO := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const PUNCHES := [
	{"name": "crit", "px": 14.0, "sec": 0.20},
	{"name": "trap", "px": 16.0, "sec": 0.22},
]
const FRAMES := 24

var _out := "/tmp/shake_tiles"
var _steps: Array = []
var _index := 0
var _phase := "boot"
var _frames := 0
var _opened := -1
var _open_waits := 0
var _punch := 0
var _order := ""
var _colors := {}
var _lag_at := {}
var _max_shift := 0.0
var _holes := 0
var _swaps := 0
var _order_breaks := 0
var _samples := 0
var _failed := 0
var _log: FileAccess


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("--"):
			_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out)
	_log = FileAccess.open(_out.path_join("shake_tiles.txt"), FileAccess.WRITE)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	for biome in KOLISEO:
		_steps.append({"kind": "koliseo", "biome": biome, "room": ""})
	for biome in KOLISEO:
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
		board.punch_camera(float(spec["px"]), float(spec["sec"]))
		_phase = "punch"
		_frames = 0
		_max_shift = 0.0
		_holes = 0
		_swaps = 0
		_order_breaks = 0
		_samples = 0
		return false
	if _phase == "punch":
		_frames += 1
		_note(board, step, str(PUNCHES[_punch]["name"]))
		if _frames < FRAMES:
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
	Engine.time_scale = 1.0
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
	_colors = {}
	var image := _image()
	if image == null:
		return
	var tiles: Dictionary = board.tiles
	for cell in tiles.keys():
		var tile: Node2D = tiles[cell]
		if tile == null:
			continue
		var at := _screen_of(tile)
		if not _on_screen(at, image.get_width(), image.get_height()):
			continue
		_colors[cell] = image.get_pixel(int(at.x), int(at.y))
		_lag_at[cell] = at


func _note(board: Node, step: Dictionary, punch: String) -> void:
	var order := _tile_order(board)
	if order != _order:
		_order_breaks += 1
		_fail("%s %s %s frame %d tile order changed" % [str(step["kind"]), str(step["biome"]), punch, _frames])
		_order = order
	if board._camera != null and board._camera.offset.length() > 0.01:
		_fail("%s %s %s camera offset moved" % [str(step["kind"]), str(step["biome"]), punch])
	_max_shift = maxf(_max_shift, _shift_of(board))
	# The viewport image is the previous frame. Sample the positions recorded
	# then, then store this frame's positions for the next image.
	var image := _image()
	if image == null:
		return
	var width := image.get_width()
	var height := image.get_height()
	for cell in _lag_at.keys():
		var at: Vector2 = _lag_at[cell]
		if not _on_screen(at, width, height):
			continue
		if not _colors.has(cell):
			continue
		_samples += 1
		var got := image.get_pixel(int(at.x), int(at.y))
		var want: Color = _colors[cell]
		if _is_sky(got) and not _is_sky(want):
			_holes += 1
		elif not _near(got, want):
			_swaps += 1
	_lag_at = {}
	var tiles: Dictionary = board.tiles
	for cell in _colors.keys():
		var tile: Node2D = tiles.get(cell)
		if tile == null:
			continue
		var at := _screen_of(tile)
		if _on_screen(at, width, height):
			_lag_at[cell] = at


func _shift_of(board: Node) -> float:
	var world: Node2D = board.get("_world")
	if world == null or board._camera == null:
		return 0.0
	return world.position.length() * board._camera.zoom.x


func _report_punch(step: Dictionary, punch: String) -> void:
	var label := "%s %s%s %s" % [str(step["kind"]), str(step["biome"]), str(step["room"]), punch]
	var bad := _order_breaks > 0 or _holes > 0 or _swaps > 0 or _max_shift < 8.0
	if bad:
		_failed += 1
	var line := "%s shift=%.2f samples=%d holes=%d swaps=%d order=%d %s" % [label, _max_shift, _samples, _holes, _swaps, _order_breaks, "FAIL" if bad else "ok"]
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


func _screen_of(tile: Node2D) -> Vector2:
	return tile.get_global_transform_with_canvas().origin


func _on_screen(at: Vector2, width: int, height: int) -> bool:
	return at.x >= 8.0 and at.y >= 8.0 and at.x < float(width - 8) and at.y < float(height - 8)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 12.0 / 255.0 and absf(a.g - b.g) <= 12.0 / 255.0 and absf(a.b - b.b) <= 12.0 / 255.0


## The star field is the dark blue behind the diamond. A tile that vanishes
## lands on that color. Painted floors are lighter than this.
func _is_sky(color: Color) -> bool:
	return color.r < 0.12 and color.g < 0.16 and color.b < 0.28 and color.b + 0.02 >= color.r


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
