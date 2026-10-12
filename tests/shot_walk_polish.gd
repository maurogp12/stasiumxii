extends SceneTree

const WALK_MOTION := preload("res://units/view_motion.gd")

## Phone-fit walk. Window 2400×1080, logical view 1600×720.
## Ironjaw walks east, turns the corner by climbing one elevation, and plants.
## Record with --fixed-fps 60 so each dumped frame is one 60fps process frame.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --fixed-fps 60 --path . -s res://tests/shot_walk_polish.gd -- <out_dir>

var _dir := "/opt/cursor/artifacts/walk_motion"
var _mode := "after"
var _board: Node
var _dump := false
var _log_motion := false
var _clip_i := 0
var _saved := false
var _watchdog := 0
var _samples: Array[Dictionary] = []
var _zoom_follow := false
var _fit_zoom := 0.0
var _follow_seat := -1
var _latched: Pawn = null
var _prev_pos := {}
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
	select.set("hotseat_classes", ["ironjaw", "mender"])
	change_scene_to_file("res://main.tscn")
	call_deferred("_drive")


func _process(_delta: float) -> bool:
	_watchdog += 1
	if _watchdog > 1800:
		push_error("walk shot timed out")
		quit(1)
		return true
	if _zoom_follow and _board != null:
		_hold_walker(false)
	if _dump or _log_motion:
		_note_sample()
	if _dump:
		_dump_frame()
		if not _saved and _on_rise():
			_save("walk_%s.png" % _mode)
			_saved = true
	elif _log_motion:
		_clip_i += 1
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
		_zoom_follow = true
		_hold_walker(true)
		await _frames(3)
		_dump = true
	elif _mode == "log":
		_log_motion = true
	await _frames(20)
	await _board._submit({"type": "move", "to": Vector2i(7, 5), "seat": 0})
	await _frames(12)
	await _board._submit({"type": "end_turn", "seat": 0})
	await _frames(8)
	await _board._submit({"type": "move", "to": Vector2i(7, 8), "seat": 1})
	await _frames(30)
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
		"classes": ["ironjaw", "mender"],
		"positions": [Vector2i(4, 4), Vector2i(4, 8)],
	})
	sim.set_tile(Vector2i(6, 4), "ground", 1)
	sim.set_tile(Vector2i(7, 4), "ground", 1)
	sim.set_tile(Vector2i(7, 5), "ground", 1)
	var unit: Dictionary = sim._unit_by_seat(0)
	unit["mp"] = 8
	unit["max_mp"] = 8
	var mender: Dictionary = sim._unit_by_seat(1)
	mender["mp"] = 6
	mender["max_mp"] = 6
	if _board.has_method("_rebuild_pawns"):
		_board._rebuild_pawns()
	if _board.has_method("_refresh"):
		_board._refresh()
	if _board.has_method("_fit_board_camera"):
		_board._fit_board_camera(false)
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud._layout_chrome()


## Twice the fit zoom, locked on whoever is walking, so the stride fills the frame.
func _hold_walker(snap: bool) -> void:
	if _board == null:
		return
	var cam: Camera2D = _board._camera
	if cam == null:
		return
	if _fit_zoom <= 0.0:
		_fit_zoom = maxf(cam.zoom.x, 0.05)
	var z := _fit_zoom * 2.0
	cam.zoom = Vector2(z, z)
	_board._pan_limit = Vector2(8000.0, 8000.0)
	var glide: Tween = _board._focus_tween
	if glide != null and glide.is_valid():
		glide.kill()
	var pawn := _moving_pawn()
	if pawn == null:
		_board._flush_camera()
		return
	var goal := pawn.position + Vector2(0.0, -36.0)
	if snap or pawn.seat != _follow_seat:
		cam.position = goal
		_follow_seat = pawn.seat
	else:
		cam.position = cam.position.lerp(goal, 0.45)
	cam.offset = Vector2.ZERO
	_board._flush_camera()


func _moving_pawn() -> Pawn:
	var best: Pawn = null
	var best_d := 0.0
	for seat in [0, 1]:
		if not _board.pawns_by_seat.has(seat):
			continue
		var pawn: Pawn = _board.pawns_by_seat[seat]
		var prev: Vector2 = _prev_pos.get(seat, pawn.position)
		var traveled := pawn.position.distance_to(prev)
		_prev_pos[seat] = pawn.position
		if traveled > best_d:
			best_d = traveled
			best = pawn
	if best != null and best_d > 0.15:
		_latched = best
	if _latched != null:
		return _latched
	return _pawn()


func _pawn() -> Pawn:
	if _board == null or not _board.pawns_by_seat.has(0):
		return null
	return _board.pawns_by_seat[0]


func _pose(pawn: Pawn) -> Dictionary:
	var frame := -1
	var anim := ""
	var sampler := pawn.walk_sampler()
	if sampler != null:
		frame = sampler.frame
		anim = str(sampler.animation)
	var draw := pawn.get_node_or_null("WalkDraw") as Sprite2D
	var sprite := pawn.get_node_or_null("Sprite") as Sprite2D
	var vis := pawn.position
	var bob := 0.0
	var draw_on := false
	var sprite_on := sprite != null and sprite.visible
	var tex: Texture2D = null
	if draw != null:
		vis = draw.global_position
		bob = draw.position.length()
		draw_on = draw.visible
		tex = draw.texture
	var walk_i := _cell_index(pawn, "walk", tex)
	var idle_i := _cell_index(pawn, "idle", tex)
	return {
		"frame": frame,
		"anim": anim,
		"vis": vis,
		"bob": bob,
		"draw_on": draw_on,
		"sprite_on": sprite_on,
		"walk_i": walk_i,
		"idle_i": idle_i,
		"sig": _tex_sig(tex),
	}


func _cell_index(pawn: Pawn, kind: String, tex: Texture2D) -> int:
	if tex == null:
		return -1
	var face := pawn.facing.strip_edges().to_lower()
	var cells := StripLibrary.painted_cells(pawn.class_id, kind, face)
	return cells.find(tex)


func _tex_sig(tex: Texture2D) -> String:
	if tex == null:
		return "nil"
	var image := tex.get_image()
	if image == null or image.is_empty():
		return "empty"
	var w := image.get_width()
	var h := image.get_height()
	var s := 0
	for i in 24:
		var c := image.get_pixel((i * 17) % w, (i * 13) % h)
		s = (s * 33 + int(c.r * 255.0) + int(c.g * 255.0) * 3 + int(c.b * 255.0) * 7 + int(c.a * 255.0) * 11) & 0x7fffffff
	return "%dx%d:%d" % [w, h, s]


func _note_sample() -> void:
	var pawn := _pawn()
	if pawn == null:
		return
	var pose := _pose(pawn)
	_samples.append({
		"i": _clip_i,
		"seat": 0,
		"pos": pawn.position,
		"vis": pose["vis"],
		"bob": pose["bob"],
		"cell": pawn.grid_position,
		"frame": pose["frame"],
		"anim": pose["anim"],
		"draw_on": pose["draw_on"],
		"sprite_on": pose["sprite_on"],
		"walk_i": pose["walk_i"],
		"idle_i": pose["idle_i"],
		"sig": pose["sig"],
	})
	if _log_motion:
		print("LIVE seat=0 i=%d cell=%s anim=%s frame=%d walk_i=%d idle_i=%d draw=%s sprite=%s sig=%s" % [
			_clip_i, pawn.grid_position, pose["anim"], int(pose["frame"]), int(pose["walk_i"]), int(pose["idle_i"]), pose["draw_on"], pose["sprite_on"], pose["sig"],
		])
		_maybe_save_step(pawn, pose)
	_note_mender()


var _step_saved: Dictionary = {}


## Six stills of the first Ironjaw stride, cropped from the rendered frame.
func _maybe_save_step(pawn: Pawn, pose: Dictionary) -> void:
	if str(pose["anim"]) != "walk_e" or int(pose["walk_i"]) < 0:
		return
	if pawn.grid_position != Vector2i(4, 4):
		return
	var index := int(pose["frame"])
	if index > 5 or _step_saved.has(index):
		return
	_step_saved[index] = true
	var draw := pawn.get_node_or_null("WalkDraw") as Sprite2D
	if draw == null or draw.texture == null:
		return
	var tex_image := draw.texture.get_image()
	if tex_image != null:
		tex_image.save_png(_dir.path_join("cell_%d.png" % index))
	var image := root.get_texture().get_image()
	if image == null:
		return
	var rect := draw.get_rect()
	var xf := draw.get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		xf * rect.position,
		xf * Vector2(rect.end.x, rect.position.y),
		xf * rect.end,
		xf * Vector2(rect.position.x, rect.end.y),
	]
	var min_p := corners[0]
	var max_p := corners[0]
	for corner in corners:
		min_p = min_p.min(corner)
		max_p = max_p.max(corner)
	var pad := 24.0
	var box := Rect2i(
		Vector2i(int(floor(min_p.x - pad)), int(floor(min_p.y - pad))),
		Vector2i(int(ceil(max_p.x - min_p.x + pad * 2.0)), int(ceil(max_p.y - min_p.y + pad * 2.0)))
	)
	box = box.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if box.size.x < 4 or box.size.y < 4:
		print("CROP miss frame=%d box=%s canvas=%s img=%s" % [index, box, min_p, image.get_size()])
		return
	var crop := image.get_region(box)
	crop.save_png(_dir.path_join("screen_%d.png" % index))
	print("CROP frame=%d box=%s img=%s" % [index, box, image.get_size()])


func _note_mender() -> void:
	if _board == null or not _board.pawns_by_seat.has(1):
		return
	var pawn: Pawn = _board.pawns_by_seat[1]
	var pose := _pose(pawn)
	_samples.append({
		"i": _clip_i,
		"seat": 1,
		"pos": pawn.position,
		"vis": pose["vis"],
		"bob": pose["bob"],
		"cell": pawn.grid_position,
		"frame": pose["frame"],
		"anim": pose["anim"],
		"draw_on": pose["draw_on"],
		"sprite_on": pose["sprite_on"],
		"walk_i": pose["walk_i"],
		"idle_i": pose["idle_i"],
		"sig": pose["sig"],
	})
	if _log_motion and str(pose["anim"]) != "":
		print("LIVE seat=1 i=%d cell=%s anim=%s frame=%d walk_i=%d idle_i=%d draw=%s sprite=%s sig=%s" % [
			_clip_i, pawn.grid_position, pose["anim"], int(pose["frame"]), int(pose["walk_i"]), int(pose["idle_i"]), pose["draw_on"], pose["sprite_on"], pose["sig"],
		])


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
	var flat_halt := _longest_halt(flat, Vector2i(4, 4), Vector2i(5, 4))
	var mender := _moving_run(Vector2i(5, 8), Vector2i(6, 8))
	var mender_halt := _longest_halt(mender, Vector2i(5, 8), Vector2i(6, 8))
	var mender_ease := _ease_marks(mender, Vector2i(5, 8), Vector2i(6, 8))
	print("PROBE flat_n=%d early=%.3f late=%.3f halt=%d climb_n=%d y_above=%.2f x_hold=%.2f foot_miss=%d mender_n=%d mender_early=%.3f mender_late=%.3f mender_halt=%d flat_contacts=%s climb_contacts=%s clip=%d" % [
		flat.size(), flat_ease["early"], flat_ease["late"], flat_halt, climb.size(), climb_rise["y_above"], climb_rise["x_hold"], feet, mender.size(), mender_ease["early"], mender_ease["late"], mender_halt, flat_contacts, climb_contacts, _clip_i,
	])
	var lines := PackedStringArray()
	lines.append("flat_n=%d early=%.3f late=%.3f" % [flat.size(), flat_ease["early"], flat_ease["late"]])
	lines.append("climb_n=%d y_above=%.3f x_hold=%.3f" % [climb.size(), climb_rise["y_above"], climb_rise["x_hold"]])
	lines.append("foot_miss=%d flat_contacts=%s climb_contacts=%s" % [feet, flat_contacts, climb_contacts])
	for sample in flat:
		lines.append("F %d pawn=%s vis=%s bob=%.2f anim=%s frame=%d walk_i=%d idle_i=%d" % [int(sample["i"]), sample["pos"], sample["vis"], float(sample["bob"]), str(sample.get("anim", "")), int(sample["frame"]), int(sample.get("walk_i", -1)), int(sample.get("idle_i", -1))])
	for sample in climb:
		lines.append("C %d pawn=%s vis=%s bob=%.2f anim=%s frame=%d walk_i=%d idle_i=%d" % [int(sample["i"]), sample["pos"], sample["vis"], float(sample["bob"]), str(sample.get("anim", "")), int(sample["frame"]), int(sample.get("walk_i", -1)), int(sample.get("idle_i", -1))])
	for sample in _samples:
		if int(sample.get("walk_i", -1)) < 0 and str(sample.get("anim", "")) == "":
			continue
		lines.append("LIVE i=%d seat=%d cell=%s anim=%s frame=%d walk_i=%d idle_i=%d" % [int(sample["i"]), int(sample.get("seat", 0)), sample["cell"], str(sample.get("anim", "")), int(sample["frame"]), int(sample.get("walk_i", -1)), int(sample.get("idle_i", -1))])
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
		if int(sample.get("seat", 0)) != 0 and src_cell.y < 7:
			continue
		if int(sample.get("seat", 0)) != 1 and src_cell.y >= 7:
			continue
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


## Longest run of frames where the foot barely moves. A contact hold is
## several of these in a row. A gentle ease-in is one or two.
func _longest_halt(run: Array[Dictionary], src_cell: Vector2i, dst_cell: Vector2i) -> int:
	var src: Vector2 = _board._cell_to_local(src_cell)
	var dst: Vector2 = _board._cell_to_local(dst_cell)
	var span := dst - src
	var best := 0
	var streak := 0
	var prev := -1.0
	for sample in run:
		var h := _progress(sample, src, span)
		if prev >= 0.0 and absf(h - prev) < 0.008 and h < 0.98:
			streak += 1
			best = maxi(best, streak)
		else:
			streak = 0
		prev = h
	return best


func _foot_misses(run: Array[Dictionary], tile_i: int) -> int:
	var src_cell := Vector2i(4, 4) if tile_i == 0 else Vector2i(5, 4)
	var dst_cell := Vector2i(5, 4) if tile_i == 0 else Vector2i(6, 4)
	var src: Vector2 = _board._cell_to_local(src_cell)
	var dst: Vector2 = _board._cell_to_local(dst_cell)
	var span := dst - src
	var misses := 0
	for sample in run:
		var h := _progress(sample, src, span)
		var want := WALK_MOTION.walk_cycle_frame(h, 12, tile_i, 0)
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
	var arrival := int(WALK_MOTION.walk_cycle_frame(1.0, 12, tile_i, 0))
	var depart := int(WALK_MOTION.walk_cycle_frame(0.0, 12, tile_i, 0))
	return "depart=%d(%d) arrive=%d(%d)" % [first, depart, last, arrival]
