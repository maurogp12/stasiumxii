extends SceneTree

## L9 frame time. Jungle stays on. The pair is the new board off, then on.
## Still, a 60-frame circular pan, and a fighter walking.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/bench_l9.gd

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const HUD := preload("res://ui/hud.gd")
const WARMUP := 20
const SAMPLES := 60

var _rows: Array[bool] = []


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	HUD.set_pc_chrome_override(1)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	root.get_node("CombatSim").reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	var layer = board.get_node_or_null("JungleBackdrop")
	if layer == null:
		push_error("JungleBackdrop missing")
		quit(1)
		return
	layer.set_enabled(true)
	layer.layout()
	var cam := board.get_node("BoardCamera") as Camera2D
	var fit: Vector2 = board.get("_fit_camera_pos")
	cam.zoom = Vector2(0.64, 0.64)
	var pawn := _first_pawn(board)
	var home := pawn.global_position if pawn != null else Vector2.ZERO
	await _pair(board, "still", func(i: int) -> void:
		cam.position = fit + Vector2(220, 0)
	)
	await _pair(board, "pan", func(i: int) -> void:
		var ang := float(i) / float(SAMPLES) * TAU
		cam.position = fit + Vector2(cos(ang), sin(ang)) * 180.0
	)
	await _pair(board, "walk", func(i: int) -> void:
		cam.position = fit + Vector2(220, 0)
		if pawn != null:
			pawn.global_position = home + Vector2(float(i) * 8.0, float(i) * 4.0)
	)
	BOARD.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)
	board._refresh()
	var budget_ok := true
	for row in _rows:
		if not bool(row):
			budget_ok = false
	print("L9_PROOF budget=%s" % str(budget_ok))
	quit(0 if budget_ok else 1)


func _pair(board: Node, mode: String, move: Callable) -> void:
	_set_look(board, false)
	var before := await _sample(move)
	_set_look(board, true)
	var after := await _sample(move)
	var cap := before.x * 1.25
	var ok := after.x <= cap
	_rows.append(ok)
	var delta := 0.0
	if before.x > 0.0:
		delta = (after.x - before.x) / before.x * 100.0
	print("L9_FRAME mode=%s off_mean_ms=%.3f off_worst_ms=%.3f on_mean_ms=%.3f on_worst_ms=%.3f cap_ms=%.3f delta_pct=%.1f ok=%s samples=%d" % [mode, before.x, before.y, after.x, after.y, cap, delta, str(ok), SAMPLES])


func _set_look(board: Node, on: bool) -> void:
	BOARD.set_suppressed(not on)
	board._refresh()


func _sample(move: Callable) -> Vector2:
	for i in WARMUP:
		move.call(i)
		await process_frame
	var total := 0
	var worst := 0
	for i in SAMPLES:
		move.call(WARMUP + i)
		var t0 := Time.get_ticks_usec()
		await process_frame
		RenderingServer.force_draw()
		var dt := Time.get_ticks_usec() - t0
		total += dt
		if dt > worst:
			worst = dt
	return Vector2(float(total) / float(SAMPLES) / 1000.0, float(worst) / 1000.0)


func _first_pawn(board: Node) -> Node2D:
	var pawns: Variant = board.get("pawns_by_seat")
	if pawns is Dictionary:
		for seat in pawns.keys():
			var pawn: Variant = pawns[seat]
			if pawn is Node2D:
				return pawn
	return null
