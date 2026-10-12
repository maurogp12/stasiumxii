extends SceneTree

## Phone-fit trap spring. Window 2400×1080, logical view 1600×720.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --fixed-fps 60 --path . -s res://tests/shot_trap_spring.gd -- <out_dir> [before|after] --mobile-frame
## `after` dumps 60fps frames under <out_dir>/frames. No log panel during the clip.

var _dir := "/opt/cursor/artifacts/trap_detonation"
var _mode := "after"
var _board: Node
var _dump := false
var _clip_i := 0
var _saw_armed := false
var _saved_spring := false
var _watchdog := 0
const CLIP_MAX := 300
var _max_shake := 0.0
var _max_recoil := 0.0
var _label_text := ""
var _label_size := 0
var _label_y := 0.0
var _victim_y := 0.0


func _initialize() -> void:
	var positional: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		positional.append(text)
	if positional.size() > 0:
		_dir = positional[0]
	if positional.size() > 1:
		_mode = positional[1]
	DirAccess.make_dir_recursive_absolute(_dir)
	if _mode == "after":
		DirAccess.make_dir_recursive_absolute(_dir.path_join("frames"))
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	select.set("hotseat_map_id", "crosshaven")
	select.set("hotseat_classes", ["kestrel", "gloam"])
	change_scene_to_file("res://main.tscn")
	call_deferred("_drive")


func _process(_delta: float) -> bool:
	_watchdog += 1
	if _watchdog > 2400:
		push_error("trap spring shot timed out")
		quit(1)
		return true
	if _dump:
		_probe()
		_dump_frame()
		_saw_armed = _saw_armed or _token_visible()
	return false


func _drive() -> void:
	while true:
		await process_frame
		if current_scene == null:
			continue
		_board = current_scene.get_node_or_null("BoardView")
		if _board != null and bool(_board.get("_booted")):
			break
	await _frames(6)
	_setup()
	await _board._submit({"type": "cast", "spell": "snare_trap", "seat": 0, "to": Vector2i(5, 4)})
	await _frames(8)
	_note("armed")
	await _board._submit({"type": "end_turn", "seat": 0})
	await _frames(8)
	if _mode == "after":
		_dump = true
	await _board._submit({"type": "move", "seat": 1, "to": Vector2i(4, 4)})
	# The walk awaits inside _submit. Keep dumping through the spring.
	await _frames(150)
	if not _saved_spring:
		_save("trap_spring_%s.png" % _mode)
	_dump = false
	_note("spring")
	_open_log()
	await _frames(2)
	_finish_log_check()
	quit(0)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _setup() -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 4,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1, 1, 1, 1, 1],
		"classes": ["kestrel", "gloam"],
		"positions": [Vector2i(3, 4), Vector2i(7, 4)],
	})
	if _board.has_method("_rebuild_pawns"):
		_board._rebuild_pawns()
	if _board.has_method("_refresh"):
		_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud._layout_chrome()


func _open_log() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null:
		return
	if not hud._log_open:
		hud._toggle_log()
	hud._layout_chrome()
	hud._scroll_log_end()


func _finish_log_check() -> void:
	var hud: CombatHUD = _board._hud
	var body := "" if hud == null or hud._log_body == null else hud._log_body.get_parsed_text()
	print("LOG\n%s" % body)
	if _mode == "after":
		if not body.contains("Snare!"):
			push_error("log is missing the trap line")
		if not _saw_armed:
			push_error("the owner never saw an armed trap token")
	print("PROBE shake=%.2f recoil=%.2f label=%s size=%d label_y=%.1f victim_y=%.1f" % [_max_shake, _max_recoil, _label_text, _label_size, _label_y, _victim_y])
	print("SPRING done armed_seen=%s clip=%d" % [_saw_armed, _clip_i])


func _probe() -> void:
	if _board == null or _board._camera == null:
		return
	_max_shake = maxf(_max_shake, _board._camera.offset.length() * _board._camera.zoom.x)
	if not _board.pawns_by_seat.has(1):
		return
	var pawn: Pawn = _board.pawns_by_seat[1]
	_victim_y = pawn.position.y
	var strip: Node = pawn.get("_active_strip")
	if strip != null:
		_max_recoil = maxf(_max_recoil, strip.position.length())
	var draw: Node2D = pawn.get_node_or_null("WalkDraw")
	if draw != null:
		_max_recoil = maxf(_max_recoil, draw.position.length())
	var vfx: Node = _board.get("_vfx")
	if vfx == null:
		return
	var pools: Variant = vfx.get("_pools")
	if typeof(pools) != TYPE_DICTIONARY:
		return
	for node in pools.get("number", []):
		if node == null or not bool(node.get("in_use")):
			continue
		var text := str(node.get("_text"))
		if text == "Trap!":
			_label_text = text
			_label_size = int(node.get("_font_size"))
			_label_y = node.position.y
			if not _saved_spring and _max_recoil > 8.0:
				_save("trap_spring_%s.png" % _mode)
				_saved_spring = true


func _token_visible() -> bool:
	if _board == null:
		return false
	var vfx: Node = _board.get("_vfx")
	if vfx == null:
		return false
	for key in vfx.get("_linger"):
		var text := str(key)
		if text.begins_with("snare_token") or text.begins_with("trap:"):
			return true
	return false


func _note(tag: String) -> void:
	var view := _board.get_viewport().get_visible_rect().size
	var zoom := 0.0
	if _board._camera != null:
		zoom = _board._camera.zoom.x
	var sim: Node = root.get_node("/root/CombatSim")
	var traps: Array = sim.snapshot().get("trap_tiles", [])
	var gloam := Vector2i(-1, -1)
	for unit in sim.snapshot().get("units", []):
		if int(unit.get("seat", -1)) == 1:
			gloam = unit.get("pos", gloam)
	print("FRAME %s zoom=%.3f view=%s traps=%d gloam=%s mode=%s" % [tag, zoom, view, traps.size(), gloam, _mode])


func _dump_frame() -> void:
	if _clip_i >= CLIP_MAX:
		return
	var image := root.get_texture().get_image()
	if image == null:
		return
	image.save_png(_dir.path_join("frames/f_%04d.png" % _clip_i))
	_clip_i += 1


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image")
		return
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [path, image.get_width(), image.get_height(), err])
