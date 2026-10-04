extends SceneTree

## L10 frame time, one tree per run. Run it on pc/combat-look (the old bodies)
## and on this branch (the new bodies). Same board, camera, seed, and path.
## Jungle on, the shipped light grade on, PC chrome on.
## Still, a 60-frame circular pan, and a fighter walking a real board walk.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/bench_l10.gd -- --tag=after
## Compare the two runs' means against a +25% budget (cap = base mean x 1.25).

const HUD := preload("res://ui/hud.gd")
const WARMUP := 20
const SAMPLES := 60
const WALK_FROM := Vector2i(7, 7)
const WALK_TO := Vector2i(11, 7)

var _tag := "run"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--tag="):
			_tag = text.trim_prefix("--tag=")
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
	var sim: Node = root.get_node("CombatSim")
	_reset(sim, board, WALK_FROM)
	board._fit_board_camera()
	if board.has_method("_sync_look_light"):
		board._sync_look_light()
	var layer = board.get_node_or_null("JungleBackdrop")
	if layer != null:
		layer.set_enabled(true)
		layer.layout()
	var cam := board.get_node("BoardCamera") as Camera2D
	var fit: Vector2 = board.get("_fit_camera_pos")
	cam.zoom = Vector2(0.64, 0.64)
	await _run(board, "still", func(_i: int) -> void:
		cam.position = fit + Vector2(220, 0)
	)
	await _run(board, "pan", func(i: int) -> void:
		var ang := float(i) / float(SAMPLES) * TAU
		cam.position = fit + Vector2(cos(ang), sin(ang)) * 180.0
	)
	var state := {"to": WALK_TO}
	await _run(board, "walk", func(_i: int) -> void:
		cam.position = fit + Vector2(220, 0)
		if int(board.get("_hop_seat")) < 0:
			var to: Vector2i = state["to"]
			var from: Vector2i = WALK_FROM if to == WALK_TO else WALK_TO
			_reset(sim, board, to)
			board._play_walk(1, _line(from, to), from)
			state["to"] = WALK_FROM if to == WALK_TO else WALK_TO
	)
	HUD.set_pc_chrome_override(-1)
	quit(0)


## The sim holds Ironjaw on the destination, so the board walk plays the whole
## line with no MP limit and lands where the sim already is.
func _reset(sim: Node, board: Node, ironjaw_at: Vector2i) -> void:
	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(9, 3), ironjaw_at],
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
	})
	board._rebuild_pawns()
	board._refresh()


func _line(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var at := from
	while at != to:
		at += step
		out.append(at)
	return out


func _run(_board: Node, mode: String, move: Callable) -> void:
	for i in WARMUP:
		move.call(i)
		await process_frame
	var total := 0
	var worst := 0
	var samples: Array[int] = []
	for i in SAMPLES:
		move.call(WARMUP + i)
		var t0 := Time.get_ticks_usec()
		await process_frame
		RenderingServer.force_draw()
		var dt := Time.get_ticks_usec() - t0
		total += dt
		samples.append(dt)
		worst = maxi(worst, dt)
	samples.sort()
	print("L10_FRAME tag=%s mode=%s mean_ms=%.3f worst_ms=%.3f median_ms=%.3f samples=%d" % [_tag, mode, float(total) / float(SAMPLES) / 1000.0, float(worst) / 1000.0, float(samples[SAMPLES / 2]) / 1000.0, SAMPLES])
