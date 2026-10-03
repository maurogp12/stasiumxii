extends SceneTree

## OpenGL frame time for the Crosshaven jungle layer.
## Standing, a 60-frame circular pan, and a fighter walking.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/bench_jungle_frame.gd

const WARMUP := 20
const SAMPLES := 60

var _rows: Array[bool] = []


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
	var cam := board.get_node("BoardCamera") as Camera2D
	var fit: Vector2 = board.get("_fit_camera_pos")
	cam.zoom = Vector2(0.64, 0.64)
	var pawn := _first_pawn(board)
	var home := pawn.global_position if pawn != null else Vector2.ZERO
	await _pair(layer, "still", func(i: int) -> void:
		cam.position = fit + Vector2(220, 0)
	)
	await _pair(layer, "pan", func(i: int) -> void:
		var ang := float(i) / float(SAMPLES) * TAU
		cam.position = fit + Vector2(cos(ang), sin(ang)) * 180.0
	)
	await _pair(layer, "walk", func(i: int) -> void:
		cam.position = fit + Vector2(220, 0)
		if pawn != null:
			pawn.global_position = home + Vector2(float(i) * 8.0, float(i) * 4.0)
	)
	if pawn != null:
		pawn.global_position = home
	cam.position = fit + Vector2(220, 0)
	layer.set_enabled(true)
	layer.layout()
	var units := board.get_node_or_null("Units") as CanvasItem
	if units != null:
		units.visible = false
	var changed := await _sway_margin_diff(layer)
	print("JUNGLE_SWAY margin_pixels_changed=%d" % changed)
	var leaf_frac := await _prove_leaf_sway(layer)
	if units != null:
		units.visible = true
	var budget_ok := true
	for row in _rows:
		if not bool(row):
			budget_ok = false
	var margin_ok := changed > 5000
	var leaf_ok := leaf_frac > 0.02
	print("JUNGLE_PROOF budget=%s margin=%s leaf_frac=%.4f" % [str(budget_ok), str(margin_ok), leaf_frac])
	quit(0 if budget_ok and margin_ok and leaf_ok else 1)


func _pair(layer: Node, mode: String, move: Callable) -> void:
	layer.set_enabled(false)
	var before := await _sample(move)
	layer.set_enabled(true)
	layer.layout()
	var after := await _sample(move)
	var cap := before.x * 1.25
	var ok := after.x <= cap
	_rows.append(ok)
	print("JUNGLE_FRAME mode=%s before_mean_ms=%.3f before_worst_ms=%.3f after_mean_ms=%.3f after_worst_ms=%.3f cap_ms=%.3f ok=%s samples=%d" % [mode, before.x, before.y, after.x, after.y, cap, str(ok), SAMPLES])


func _sample(move: Callable) -> Vector2:
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
		if dt > worst:
			worst = dt
		if dt > 25000:
			print("  spike_ms=%.2f" % (float(dt) / 1000.0))
	samples.sort()
	var median := float(samples[SAMPLES / 2]) / 1000.0
	print("  median_ms=%.3f" % median)
	return Vector2(float(total) / float(SAMPLES) / 1000.0, float(worst) / 1000.0)


func _sway_margin_diff(layer: Node) -> int:
	await process_frame
	layer.preview_time(0.0)
	RenderingServer.force_draw()
	var first := root.get_viewport().get_texture().get_image()
	await process_frame
	layer.preview_time(1.0)
	RenderingServer.force_draw()
	var second := root.get_viewport().get_texture().get_image()
	if first == null or second == null or first.is_empty() or second.is_empty():
		return 0
	var w := mini(first.get_width(), second.get_width())
	var h := mini(first.get_height(), second.get_height())
	var band := maxi(int(float(w) * 0.08), 8)
	var changed := 0
	for y in h:
		for x in band:
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				changed += 1
			var rx := w - 1 - x
			if first.get_pixel(rx, y) != second.get_pixel(rx, y):
				changed += 1
	return changed


## Renders the left leaf alone at swing -1 and +1. Returns the fraction of its opaque pixels that change.
func _prove_leaf_sway(layer: Node) -> float:
	var art := layer.get_node_or_null("front_leaves_left/Pivot/Art") as Sprite2D
	if art == null or art.texture == null or art.material == null:
		print("LEAF_RENDER missing")
		return 0.0
	var mat := art.material as ShaderMaterial
	var tex := art.texture
	var vp := SubViewport.new()
	vp.name = "LeafProof"
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(maxi(tex.get_width(), 2), maxi(tex.get_height(), 2))
	root.add_child(vp)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(vp.size) * 0.5
	sprite.material = mat
	vp.add_child(sprite)
	var neg := await _render_swing(vp, mat, -1.0)
	var pos := await _render_swing(vp, mat, 1.0)
	vp.queue_free()
	if neg == null or pos == null or neg.is_empty() or pos.is_empty():
		print("LEAF_RENDER empty")
		return 0.0
	var w := mini(neg.get_width(), pos.get_width())
	var h := mini(neg.get_height(), pos.get_height())
	var opaque := 0
	var changed := 0
	for y in h:
		for x in w:
			var a := neg.get_pixel(x, y)
			var b := pos.get_pixel(x, y)
			if a.a > 0.2 or b.a > 0.2:
				opaque += 1
				if a != b:
					changed += 1
	var frac := float(changed) / float(maxi(opaque, 1))
	print("LEAF_RENDER changed=%d opaque=%d frac=%.4f" % [changed, opaque, frac])
	return frac


func _render_swing(vp: SubViewport, mat: ShaderMaterial, swing: float) -> Image:
	mat.set_shader_parameter("swing", swing)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := vp.get_texture().get_image()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return image


func _first_pawn(board: Node) -> Node2D:
	var pawns: Variant = board.get("pawns_by_seat")
	if pawns is Dictionary:
		for key in (pawns as Dictionary).keys():
			var node: Node2D = (pawns as Dictionary)[key]
			if node != null:
				return node
	return null
