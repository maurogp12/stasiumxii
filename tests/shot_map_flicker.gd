extends SceneTree

## Frame diffs for every Koliseo arena and Stasis room (the dungeon boards).
## Weather is frozen so a toggling pixel is a real flicker, not snow or lava.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_map_flicker.gd -- /opt/cursor/artifacts/map_flicker

const KOLISEO := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const FRAMES := 60
const STRIDE := 8

var _out := "/tmp/map_flicker"
var _steps: Array = []
var _index := 0
var _phase := "boot"
var _frames := 0
var _hold := 0
var _opened := -1
var _mode := ""
var _prev_raw := PackedByteArray()
var _prev_w := 0
var _prev_h := 0
var _changes := PackedInt32Array()
var _misses := 0
var _edge_misses := 0
var _samples := 0
var _origin := Vector2.ZERO
var _have_origin := false
var _shifts := {}
var _best_shifts := {}
var _open_waits := 0
var _report: Array = []
var _log: FileAccess
var _beats := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("--"):
			_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out)
	_log = FileAccess.open(_out.path_join("flicker_log.txt"), FileAccess.WRITE)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	for biome in KOLISEO:
		_steps.append({"kind": "koliseo", "biome": biome, "room": ""})
	for biome in KOLISEO:
		_steps.append({"kind": "stasis", "biome": biome, "room": "a"})
		_steps.append({"kind": "stasis", "biome": biome, "room": "b"})
	var cs: GDScript = load("res://scenes/class_select.gd")
	cs.set("hotseat_classes", ["kestrel", "ironjaw"])
	cs.set("hotseat_map_id", "crosshaven")
	change_scene_to_file("res://main.tscn")
	_phase = "open"


func _process(_delta: float) -> bool:
	_beats += 1
	if current_scene == null:
		_heartbeat("none", null)
		return false
	var board := current_scene.get_node_or_null("BoardView")
	_heartbeat(str(current_scene.scene_file_path), board)
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
			board.set_process(false)
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
		_begin_count()
		_phase = "still"
		_frames = 0
		return false
	if _phase == "still":
		_frames += 1
		_note_frame(Vector2i.ZERO)
		if _frames < FRAMES:
			return false
		_store("still")
		if str(step["biome"]) in ["windmere", "slagcrown", "stormspire"] and str(step["kind"]) == "koliseo":
			var image := root.get_texture().get_image()
			image.save_png(_out.path_join("koliseo_%s.png" % str(step["biome"])))
			print("saved koliseo_%s %dx%d" % [step["biome"], image.get_width(), image.get_height()])
		_begin_count()
		_phase = "pan"
		_frames = 0
		return false
	if _phase == "pan":
		_frames += 1
		board._pan_limit = Vector2(500.0, 400.0)
		board._queue_pan(Vector2(4.0, 2.0))
		board._apply_pending_pan()
		_note_frame(_image_shift(board))
		if _frames < FRAMES:
			return false
		_store("pan")
		_begin_count()
		_phase = "walk"
		_frames = 0
		return false
	if _phase == "walk":
		_frames += 1
		_step_walker(board, float(_frames) / float(FRAMES))
		_note_frame(Vector2i.ZERO)
		if _frames < FRAMES:
			return false
		_store("walk")
		_emit_row(step)
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
		"classes": ["kestrel", "ironjaw"],
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
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = str(step["room"])
	change_scene_to_file(StasisCatalog.FIGHT_SCENE)


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
	_pause_tree(board.get_node_or_null("Tiles"))


func _pause_tree(node: Node) -> void:
	if node == null:
		return
	if node is AnimatedSprite2D:
		(node as AnimatedSprite2D).pause()
	node.set_process(false)
	for child in node.get_children():
		_pause_tree(child)


func _step_walker(board: Node, u: float) -> void:
	var pawn: Node2D = board.pawns_by_seat.get(0)
	if pawn == null:
		return
	var src: Vector2 = board._cell_to_local(Vector2i(3, 3))
	var dst: Vector2 = board._cell_to_local(Vector2i(6, 4))
	pawn.position = src.lerp(dst, u)
	board._step_src = Vector2i(3, 3)
	board._step_dst = Vector2i(6, 4)
	board._hop_seat = 0
	board._busy = true
	board._publish_pawn_depth(pawn)
	board._busy = false
	board._sync_unit_readability()


func _begin_count() -> void:
	_prev_raw = PackedByteArray()
	_prev_w = 0
	_prev_h = 0
	_changes = PackedInt32Array()
	_misses = 0
	_edge_misses = 0
	_samples = 0
	_have_origin = false
	_shifts = {}
	_best_shifts = {}


## A pixel is flicker only when it matches neither the previous frame (HUD,
## still board) nor that frame shifted by the camera step (the board sliding).
## Pan tries one pixel around the measured step so a rounding off-by-one is
## not scored as a shimmer.
func _note_frame(shift: Vector2i) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var raw := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var key := "%d,%d" % [shift.x, shift.y]
	_shifts[key] = int(_shifts.get(key, 0)) + 1
	if _prev_raw.is_empty() or _prev_w != width or _prev_h != height:
		_prev_raw = raw
		_prev_w = width
		_prev_h = height
		_samples = int(width / STRIDE) * int(height / STRIDE)
		_changes.resize(_samples)
		return
	var chosen := shift
	if shift != Vector2i.ZERO:
		var best_n := _tally(raw, width, height, shift, false)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var trial := shift + Vector2i(dx, dy)
				var n := _tally(raw, width, height, trial, false)
				if n < best_n:
					best_n = n
					chosen = trial
	var chosen_key := "%d,%d" % [chosen.x, chosen.y]
	_best_shifts[chosen_key] = int(_best_shifts.get(chosen_key, 0)) + 1
	_tally(raw, width, height, chosen, true)
	_prev_raw = raw


func _tally(raw: PackedByteArray, width: int, height: int, shift: Vector2i, apply: bool) -> int:
	var row := width * 4
	var across := int(width / STRIDE)
	var down := int(height / STRIDE)
	var misses := 0
	var i := 0
	for y in range(0, height, STRIDE):
		var sy := int(y / STRIDE)
		for x in range(0, width, STRIDE):
			var a := y * row + x * 4
			var stable := raw[a] == _prev_raw[a] and raw[a + 1] == _prev_raw[a + 1] and raw[a + 2] == _prev_raw[a + 2]
			var slid := false
			if not stable and shift != Vector2i.ZERO:
				var px := x - shift.x
				var py := y - shift.y
				if px >= 0 and py >= 0 and px < width and py < height:
					var b := py * row + px * 4
					slid = raw[a] == _prev_raw[b] and raw[a + 1] == _prev_raw[b + 1] and raw[a + 2] == _prev_raw[b + 2]
				else:
					slid = true
			if not stable and not slid:
				misses += 1
				if apply:
					_changes[i] += 1
					_misses += 1
					var sx := i % across
					if sx < 6 or sy < 4 or sx > across - 7 or sy > down - 5:
						_edge_misses += 1
			i += 1
	return misses


func _image_shift(board: Node) -> Vector2i:
	var cam: Camera2D = board.get("_camera")
	var image := root.get_texture().get_image()
	if cam == null or image == null:
		return Vector2i.ZERO
	var view: Vector2 = board.get_viewport_rect().size
	if view.x < 1.0 or view.y < 1.0:
		return Vector2i.ZERO
	var origin := Vector2(
		view.x * 0.5 - cam.position.x * cam.zoom.x,
		view.y * 0.5 - cam.position.y * cam.zoom.y
	)
	var shift := Vector2i.ZERO
	if _have_origin:
		shift = Vector2i(
			roundi((origin.x - _origin.x) * float(image.get_width()) / view.x),
			roundi((origin.y - _origin.y) * float(image.get_height()) / view.y)
		)
	_origin = origin
	_have_origin = true
	return shift


func _store(label: String) -> void:
	var hot := 0
	for n in _changes:
		if n >= 8:
			hot += 1
	var shift_bits: Array = []
	for key in _shifts.keys():
		shift_bits.append("cam %s x%d" % [key, int(_shifts[key])])
	for key in _best_shifts.keys():
		shift_bits.append("fit %s x%d" % [key, int(_best_shifts[key])])
	_report.append({
		"mode": label,
		"miss": _misses,
		"edge": _edge_misses,
		"hot": hot,
		"samples": _samples,
		"shift": ", ".join(shift_bits),
	})


func _emit_row(step: Dictionary) -> void:
	var name := "koliseo_%s" % str(step["biome"])
	if str(step["kind"]) == "stasis":
		name = "stasis_%s_%s" % [step["biome"], step["room"]]
	var bits := []
	for row in _report:
		bits.append("%s miss %d edge %d hot %d shift %s" % [row["mode"], row["miss"], row["edge"], row["hot"], row["shift"]])
	var line := "FLICKER %s | %s" % [name, " | ".join(bits)]
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()
	_report.clear()


func _wait_open(step: Dictionary) -> bool:
	_open_waits += 1
	if _open_waits < 600:
		return false
	var line := "FLICKER STUCK %s %s room %s ready %s class %s scene %s" % [
		step["kind"], step["biome"], step["room"],
		StasisCatalog.ready_to_fight(), StasisCatalog.class_id,
		str(current_scene.scene_file_path) if current_scene != null else "none",
	]
	print(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()
	_index += 1
	_opened = -1
	_open_waits = 0
	_phase = "open"
	return false


func _heartbeat(scene_name: String, board: Node) -> void:
	if _beats % 45 != 0 or _log == null:
		return
	var booted := "noboard" if board == null else str(board.get("_booted"))
	_log.store_line("beat %d phase %s scene %s booted %s waits %d" % [_beats, _phase, scene_name, booted, _open_waits])
	_log.flush()


func _finish() -> void:
	var tail := "FLICKER hub | no board\nFLICKER done"
	print(tail)
	if _log != null:
		_log.store_string(tail + "\n")
		_log.flush()
