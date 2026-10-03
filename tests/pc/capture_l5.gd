extends SceneTree

## L5 stills and the life-bar drain clip.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l5.gd -- --out=/tmp/l5_frames

var _out := "/tmp/l5_frames"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			_out = str(arg).trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(7, 7), Vector2i(8, 7)],
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	for _i in 16:
		await process_frame
	await _shot(_out.path_join("crosshaven.png"))
	board.set_board_theme("thunderwell")
	board._refresh()
	for _i in 12:
		await process_frame
	await _shot(_out.path_join("thunderwell.png"))
	board.set_board_theme("")
	board._refresh()
	var before_life := _life(board, 0)
	var turned: Dictionary = sim.submit({"type": "end_turn"})
	print("L5_END %s" % bool(turned.get("ok", false)))
	var first: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(7, 7), "seat": 1})
	var second: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(7, 7), "seat": 1})
	print("L5_HIT first=%s second=%s" % [bool(first.get("ok", false)), bool(second.get("ok", false))])
	board._refresh()
	var after_life := _life(board, 0)
	print("L5_LIFE before=%d after=%d shown=%.3f" % [before_life, after_life, _shown(board, 0)])
	var drain_dir := _out.path_join("drain")
	DirAccess.make_dir_recursive_absolute(drain_dir)
	var dropped := false
	for i in 48:
		await process_frame
		var shown := _shown(board, 0)
		await _shot(drain_dir.path_join("f%02d.png" % i))
		if shown <= _target(board, 0) + 0.02:
			dropped = true
			print("L5_DRAIN settled frame=%d shown=%.3f life=%d" % [i, shown, _life(board, 0)])
			break
	if not dropped:
		print("L5_DRAIN still moving shown=%.3f target=%.3f" % [_shown(board, 0), _target(board, 0)])
	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(7, 7), Vector2i(8, 7)],
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"kestrel_hp": 16,
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	_zoom_on(board, Vector2i(7, 7), Vector2i(8, 7), 1.65)
	for _i in 20:
		await process_frame
	await _shot(_out.path_join("fighters.png"))
	print("L5_LOW life=%d target=%.3f" % [_life(board, 0), _target(board, 0)])
	quit(0 if after_life < before_life and dropped and _life(board, 0) <= 24 else 1)


func _zoom_on(board: Node2D, a: Vector2i, b: Vector2i, zoom: float) -> void:
	var cam: Camera2D = board.get("_camera")
	var pa: Vector2 = (board.tiles[a] as Node2D).global_position
	var pb: Vector2 = (board.tiles[b] as Node2D).global_position
	cam.zoom = Vector2(zoom, zoom)
	cam.global_position = (pa + pb) * 0.5 + Vector2(0, -28)


func _life(board: Node2D, seat: int) -> int:
	var plate := _plate(board, seat)
	if plate == null:
		return -1
	return plate.snapshot_life()


func _shown(board: Node2D, seat: int) -> float:
	var plate := _plate(board, seat)
	if plate == null:
		return -1.0
	return plate.shown_ratio()


func _target(board: Node2D, seat: int) -> float:
	var plate := _plate(board, seat)
	if plate == null:
		return -1.0
	return plate.target_ratio()


func _plate(board: Node2D, seat: int) -> OverheadPlate:
	var pawns: Dictionary = board.get("pawns_by_seat")
	if not pawns.has(seat):
		return null
	var pawn: Pawn = pawns[seat]
	return pawn.get_node_or_null("Chrome/OverheadPlate") as OverheadPlate


func _shot(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("empty frame")
		quit(1)
		return
	image.save_png(path)
