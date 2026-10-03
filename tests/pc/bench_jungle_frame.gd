extends SceneTree

## OpenGL frame time for the Crosshaven jungle layer.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/bench_jungle_frame.gd

const WARMUP := 20
const SAMPLES := 60


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var main := packed.instantiate()
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
	var cam := board.get_node("BoardCamera") as Camera2D
	var fit: Vector2 = board.get("_fit_camera_pos")
	cam.zoom = Vector2(0.64, 0.64)
	cam.position = fit + Vector2(220, 0)
	layer.layout()
	for _i in WARMUP:
		await process_frame
	var total := 0
	var worst := 0
	for _i in SAMPLES:
		var t0 := Time.get_ticks_usec()
		await process_frame
		RenderingServer.force_draw()
		var dt := Time.get_ticks_usec() - t0
		total += dt
		if dt > worst:
			worst = dt
	var mean_us := float(total) / float(SAMPLES)
	print("JUNGLE_FRAME mean_ms=%.3f worst_ms=%.3f samples=%d" % [mean_us / 1000.0, float(worst) / 1000.0, SAMPLES])
	quit(0)
