extends SceneTree

## Phone-fit walk. Window 2400×1080, logical view 1600×720.
## Ironjaw walks east, turns the corner by climbing one elevation, and plants.
## Record with --fixed-fps 60 so each dumped frame is one 60fps process frame.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --fixed-fps 60 --path . -s res://tests/shot_walk_polish.gd -- <out_dir>

var _dir := "/opt/cursor/artifacts/walk_motion"
var _mode := "after"
var _board: Node
var _dump := false
var _clip_i := 0
var _saved := false
var _watchdog := 0
var _samples: Array[Dictionary] = []
const CLIP_MAX := 480


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
	select.set("hotseat_classes", ["ironjaw", "gloam"])
	change_scene_to_file("res://main.tscn")
	call_deferred("_drive")


func _process(_delta: float) -> bool:
	_watchdog += 1
	if _watchdog > 1800:
		push_error("walk shot timed out")
		quit(1)
		return true
	if _dump:
		_note_sample()
		_dump_frame()
		if not _saved and _on_rise():
			_save("walk_%s.png" % _mode)
			_saved = true
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
	if _mode == "after":
		_dump = true
	await _frames(30)
	await _board._submit({"type": "move", "to": Vector2i(7, 5), "seat": 0})
	await _frames(80)
	_report()
	if not _saved:
		_save("walk_%s.png" % _mode)
		_saved = true
	print("WALK done saved=%s clip=%d" % [_saved, _clip_i])
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
		"classes": ["ironjaw", "gloam"],
		"positions": [Vector2i(4, 4), Vector2i(10, 10)],
	})
	sim.set_tile(Vector2i(6, 4), "ground", 1)
	sim.set_tile(Vector2i(7, 4), "ground", 1)
	sim.set_tile(Vector2i(7, 5), "ground", 1)
	var unit: Dictionary = sim._unit_by_seat(0)
	unit["mp"] = 8
	unit["max_mp"] = 8
	if _board.has_method("_rebuild_pawns"):
		_board._rebuild_pawns()
	if _board.has_method("_refresh"):
		_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud._layout_chrome()


func _pawn() -> Pawn:
	if _board == null or not _board.pawns_by_seat.has(0):
		return null
	return _board.pawns_by_seat[0]


func _note_sample() -> void:
	var pawn := _pawn()
	if pawn == null:
		return
	var frame := -1
	var sampler := pawn.walk_sampler()
	if sampler != null:
		frame = sampler.frame
	var draw := pawn.get_node_or_null("WalkDraw") as Sprite2D
	var vis := pawn.position
	var bob := 0.0
	if draw != null:
		vis = draw.global_position
		bob = draw.position.length()
	_samples.append({
		"i": _clip_i,
		"pos": pawn.position,
		"vis": vis,
		"bob": bob,
		"cell": pawn.grid_position,
		"frame": frame,
	})


## The climb from (5, 4) onto (6, 4): the foot has finished the step and the
## body is rising, so x is on the high cell while y is still between heights.
func _on_rise() -> bool:
	var pawn := _pawn()
	if pawn == null or pawn.grid_position != Vector2i(5, 4):
		return false
	var src: Vector2 = _board._cell_to_local(Vector2i(5, 4))
	var dst: Vector2 = _board._cell_to_local(Vector2i(6, 4))
	if absf(pawn.position.x - dst.x) > 1.5:
		return false
	var low_y := dst.y + BoardVisualSort.ELEVATION_PIXELS
	return pawn.position.y < low_y - 2.0 and pawn.position.y > dst.y + 1.0


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


func _report() -> void:
	var flat := _moving_run(Vector2i(4, 4), Vector2i(5, 4))
	var climb := _moving_run(Vector2i(5, 4), Vector2i(6, 4))
	var flat_ease := _ease_marks(flat, Vector2i(4, 4), Vector2i(5, 4))
	var climb_rise := _rise_gap(climb, Vector2i(5, 4), Vector2i(6, 4))
	var feet := _foot_misses(flat, 0) + _foot_misses(climb, 1)
	var flat_contacts := _edge_contacts(flat, 0)
	var climb_contacts := _edge_contacts(climb, 1)
	print("PROBE flat_n=%d early=%.3f late=%.3f climb_n=%d y_above=%.2f x_hold=%.2f foot_miss=%d flat_contacts=%s climb_contacts=%s clip=%d" % [
		flat.size(), flat_ease["early"], flat_ease["late"], climb.size(), climb_rise["y_above"], climb_rise["x_hold"], feet, flat_contacts, climb_contacts, _clip_i,
	])
	var lines := PackedStringArray()
	lines.append("flat_n=%d early=%.3f late=%.3f" % [flat.size(), flat_ease["early"], flat_ease["late"]])
	lines.append("climb_n=%d y_above=%.3f x_hold=%.3f" % [climb.size(), climb_rise["y_above"], climb_rise["x_hold"]])
	lines.append("foot_miss=%d flat_contacts=%s climb_contacts=%s" % [feet, flat_contacts, climb_contacts])
	for sample in flat:
		lines.append("F %d pawn=%s vis=%s bob=%.2f frame=%d" % [int(sample["i"]), sample["pos"], sample["vis"], float(sample["bob"]), int(sample["frame"])])
	for sample in climb:
		lines.append("C %d pawn=%s vis=%s bob=%.2f frame=%d" % [int(sample["i"]), sample["pos"], sample["vis"], float(sample["bob"]), int(sample["frame"])])
	var file := FileAccess.open(_dir.path_join("probe.txt"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _moving_run(src_cell: Vector2i, dst_cell: Vector2i) -> Array[Dictionary]:
	var src: Vector2 = _board._cell_to_local(src_cell)
	var dst: Vector2 = _board._cell_to_local(dst_cell)
	var span := dst - src
	var out: Array[Dictionary] = []
	for sample in _samples:
		if sample["cell"] != src_cell:
			continue
		var pos: Vector2 = sample["pos"]
		var h := 0.0
		if span.length_squared() > 0.01:
			h = clampf((pos - src).dot(span) / span.length_squared(), 0.0, 1.5)
		if h < 0.02 and out.is_empty():
			continue
		if h < 0.02 and not out.is_empty():
			break
		out.append(sample)
	return out


func _ease_marks(run: Array[Dictionary], src_cell: Vector2i, dst_cell: Vector2i) -> Dictionary:
	if run.size() < 8:
		return {"early": -1.0, "late": -1.0}
	var src: Vector2 = _board._cell_to_local(src_cell)
	var dst: Vector2 = _board._cell_to_local(dst_cell)
	var span := dst - src
	var n := run.size()
	var early := _progress(run[int(float(n) * 0.25)], src, span)
	var late := _progress(run[mini(int(float(n) * 0.75), n - 1)], src, span)
	return {"early": early, "late": late}


func _progress(sample: Dictionary, src: Vector2, span: Vector2) -> float:
	var pos: Vector2 = sample["pos"]
	if span.length_squared() <= 0.01:
		return 0.0
	return clampf((pos - src).dot(span) / span.length_squared(), 0.0, 1.5)


func _rise_gap(run: Array[Dictionary], src_cell: Vector2i, dst_cell: Vector2i) -> Dictionary:
	var dst: Vector2 = _board._cell_to_local(dst_cell)
	var low_y: float = dst.y + (float(_board._elev_at(dst_cell)) - float(_board._elev_at(src_cell))) * BoardVisualSort.ELEVATION_PIXELS
	var y_above := -1.0
	var x_hold := -1.0
	var planted_x := 9999.0
	var planted_y := 0.0
	var saw_plant := false
	for sample in run:
		var pos: Vector2 = sample["pos"]
		if not saw_plant and absf(pos.x - dst.x) <= 1.5 and absf(pos.y - low_y) <= 3.0:
			saw_plant = true
			planted_x = pos.x
			planted_y = pos.y
			y_above = pos.y - dst.y
			x_hold = 0.0
		elif saw_plant:
			x_hold = maxf(x_hold, absf(pos.x - planted_x))
			if pos.y < planted_y - 3.0:
				break
	return {"y_above": y_above, "x_hold": x_hold}


func _foot_misses(run: Array[Dictionary], tile_i: int) -> int:
	var src_cell := Vector2i(4, 4) if tile_i == 0 else Vector2i(5, 4)
	var dst_cell := Vector2i(5, 4) if tile_i == 0 else Vector2i(6, 4)
	var src: Vector2 = _board._cell_to_local(src_cell)
	var dst: Vector2 = _board._cell_to_local(dst_cell)
	var span := dst - src
	var misses := 0
	for sample in run:
		var h := _progress(sample, src, span)
		var want := ViewMotion.walk_cycle_frame(h, 12, tile_i, 0)
		var got := int(sample["frame"])
		if got < 0:
			misses += 1
			continue
		var off := posmod(got - want + 6, 12) - 6
		if absi(off) > 1:
			misses += 1
	return misses


func _edge_contacts(run: Array[Dictionary], tile_i: int) -> String:
	if run.is_empty():
		return "none"
	var first := int(run[0]["frame"])
	var last := int(run[run.size() - 1]["frame"])
	var arrival := ViewMotion.walk_cycle_frame(1.0, 12, tile_i, 0)
	var depart := ViewMotion.walk_cycle_frame(0.0, 12, tile_i, 0)
	return "depart=%d(%d) arrive=%d(%d)" % [first, depart, last, arrival]
