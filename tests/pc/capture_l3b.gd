extends SceneTree

## L3b stills: rest, full grid, pulsed move tiles, elevated move tiles, glyph decals.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l3b.gd -- --out=/tmp/l3b_frames

var _out := "/tmp/l3b_frames"


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
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	_clear_highlights(board)
	board.apply_full_grid(false)
	await process_frame
	await _shot(_out.path_join("before.png"))
	board.apply_full_grid(true)
	await process_frame
	await _shot(_out.path_join("grid.png"))
	board.apply_full_grid(false)
	var painted := 0
	for cell in board.tiles.keys():
		if absi(cell.x - 7) + absi(cell.y - 7) <= 3 and cell != Vector2i(7, 7):
			board.tiles[cell].set_highlight("move")
			painted += 1
	for _i in 20:
		await process_frame
	BoardTile.set_move_pulse_time(0.48)
	await _shot(_out.path_join("move.png"))
	print("L3B_MOVE painted=%d pulse=%.3f" % [painted, BoardTile.move_pulse_scale()])

	sim.reset_match({
		"seed": 3,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	_clear_highlights(board)
	var heights := {
		0: [Vector2i(5, 6), Vector2i(9, 6), Vector2i(6, 9)],
		1: [Vector2i(6, 6), Vector2i(8, 6), Vector2i(7, 5)],
		2: [Vector2i(7, 6), Vector2i(6, 7), Vector2i(8, 7), Vector2i(7, 8)],
	}
	var lifted := 0
	for elev in heights.keys():
		for cell in heights[elev]:
			var tile: BoardTile = board.tiles[cell]
			if tile == null:
				continue
			tile.set_highlight("move")
			lifted += 1
			print("L3B_HEIGHT cell=%s elev=%s y=%.1f" % [cell, tile.elevation, tile.position.y])
	for _i in 20:
		await process_frame
	BoardTile.set_move_pulse_time(0.0)
	await _shot(_out.path_join("heights.png"))
	print("L3B_HEIGHTS painted=%d" % lifted)

	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	var legal: Array = sim.legal_deploy_cells(0)
	var placed := Vector2i(-1, -1)
	if not legal.is_empty():
		placed = legal[0]
		print("L3B_PLACE %s" % sim.place_unit(0, placed))
	board._refresh()
	for _i in 20:
		await process_frame
	await _shot(_out.path_join("glyphs.png"))
	print("L3B_GLYPHS placed=%s" % placed)
	board.set_board_theme("thunderwell")
	board._refresh()
	for _i in 20:
		await process_frame
	await _shot(_out.path_join("glyphs_thunderwell.png"))
	print("L3B_GLYPHS_THUNDERWELL placed=%s" % placed)
	var pixels_ok := await _check_deploy_pixels(board, sim)
	quit(0 if painted > 0 and lifted > 0 and pixels_ok else 1)


func _clear_highlights(board: Node2D) -> void:
	for tile in board.tiles.values():
		tile.set_highlight("")


func _shot(path: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("empty frame")
		quit(1)
		return
	image.save_png(path)


## Framebuffer check. The headless suite composites paint inputs instead, because
## a headless viewport has no texture. This capture exits non-zero when a deploy
## cell is brighter than the move fill, or when Crosshaven neighbours alternate.
func _check_deploy_pixels(board: Node2D, sim: Node) -> bool:
	# The glyph still places a fighter. Measure a clean deployment instead,
	# the same board the old pixel script rendered.
	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	_clear_highlights(board)
	var units: CanvasItem = board.get_node_or_null("Units")
	if units != null:
		units.visible = false
	await _settle_frames()
	var crosshaven_ok := await _measure_deploy(board, sim, "crosshaven")
	board.set_board_theme("thunderwell")
	board._refresh()
	if units != null:
		units.visible = false
	await _settle_frames()
	var thunderwell_ok := await _measure_deploy(board, sim, "thunderwell")
	return crosshaven_ok and thunderwell_ok


func _settle_frames() -> void:
	for _i in 24:
		await process_frame


func _measure_deploy(board: Node2D, sim: Node, tag: String) -> bool:
	var cam: Camera2D = board.get("_camera")
	var p1: Array[Vector2i] = sim.deploy_zone_cells(0)
	var p2: Array[Vector2i] = sim.deploy_zone_cells(1)
	var move_at := Vector2i(7, 7)
	if p1.has(move_at) or p2.has(move_at):
		move_at = Vector2i(0, 0)
	var move_tile: BoardTile = board.tiles[move_at]
	BoardTile.set_move_pulse_time(0.0)
	move_tile.set_highlight("move")
	await _settle_frames()
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("DEPLOY_PIXELS_FAIL %s viewport image is empty" % tag)
		return false
	var move_peak := _cell_stats(image, cam, move_tile).y
	move_tile.set_highlight("")
	board._refresh()
	var units: CanvasItem = board.get_node_or_null("Units")
	if units != null:
		units.visible = false
	await _settle_frames()
	var painted := root.get_viewport().get_texture().get_image()
	var fill_cap := _lum(Color(0.55, 0.93, 1.0))
	var cap := maxf(move_peak, fill_cap)
	var ok := true
	if move_peak < 0.45 or move_peak >= 0.98:
		print("DEPLOY_PIXELS_FAIL %s move tile peak %.3f is not the painted fill" % [tag, move_peak])
		ok = false
	var open := _zone_stats(painted, board, cam, p1, p2)
	if not _zones_hold(tag, "open", open, cap):
		ok = false
	for cell in p1:
		(board.tiles[cell] as BoardTile).set_highlight("locked_p1")
	for cell in p2:
		(board.tiles[cell] as BoardTile).set_highlight("locked_p2")
	await _settle_frames()
	var locked_image := root.get_viewport().get_texture().get_image()
	var locked := _zone_stats(locked_image, board, cam, p1, p2)
	if not _zones_hold(tag, "locked", locked, cap):
		ok = false
	print("DEPLOY_PIXELS %s move=%.3f cap=%.3f open_max=%.3f open_neighbour=%.3f locked_max=%.3f locked_neighbour=%.3f" % [
		tag, move_peak, cap, _peak(open), _neighbour(open), _peak(locked), _neighbour(locked),
	])
	return ok


func _zones_hold(tag: String, phase: String, stats: Dictionary, cap: float) -> bool:
	var peak := _peak(stats)
	var neighbour := _neighbour(stats)
	var hot := _hot_pairs(stats)
	if peak > cap:
		print("DEPLOY_PIXELS_FAIL %s %s peak %.3f is above the move fill cap %.3f" % [tag, phase, peak, cap])
		return false
	var limit := 0 if tag == "crosshaven" else 2
	if hot > limit or (tag == "crosshaven" and neighbour >= 0.05):
		print("DEPLOY_PIXELS_FAIL %s %s neighbour delta %.3f across %d pairs" % [tag, phase, neighbour, hot])
		for cell in stats.keys():
			print("  CELL ", cell, " mean ", float(stats[cell].x), " peak ", float(stats[cell].y))
		return false
	if neighbour >= 0.05 and not _one_outlier(stats):
		print("DEPLOY_PIXELS_FAIL %s %s neighbour delta %.3f is not one cell" % [tag, phase, neighbour])
		return false
	return true


func _zone_stats(image: Image, board: Node2D, cam: Camera2D, p1: Array[Vector2i], p2: Array[Vector2i]) -> Dictionary:
	var stats := {}
	var cells: Array[Vector2i] = []
	cells.append_array(p1)
	cells.append_array(p2)
	for cell in cells:
		var tile: BoardTile = board.tiles[cell]
		stats[cell] = _cell_stats(image, cam, tile)
	return stats


func _cell_stats(image: Image, cam: Camera2D, tile: BoardTile) -> Vector2:
	var screen := (tile.global_position - cam.global_position) * cam.zoom
	screen += Vector2(image.get_width(), image.get_height()) * 0.5
	var half_w := 32.0 * cam.zoom.x
	var half_h := 16.0 * cam.zoom.y
	var sum := 0.0
	var peak := 0.0
	var count := 0
	var reach_x := int(ceil(half_w))
	var reach_y := int(ceil(half_h))
	for dy in range(-reach_y, reach_y + 1):
		for dx in range(-reach_x, reach_x + 1):
			if absf(float(dx)) / half_w + absf(float(dy)) / half_h > 0.62:
				continue
			var x := int(screen.x) + dx
			var y := int(screen.y) + dy
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var lum := _lum(image.get_pixel(x, y))
			sum += lum
			peak = maxf(peak, lum)
			count += 1
	if count == 0:
		return Vector2(1.0, 1.0)
	return Vector2(sum / float(count), peak)


func _peak(stats: Dictionary) -> float:
	var peak := 0.0
	for cell in stats.keys():
		peak = maxf(peak, float(stats[cell].y))
	return peak


func _hot_pairs(stats: Dictionary) -> int:
	var count := 0
	for cell in stats.keys():
		var here := cell as Vector2i
		var here_mean := float(stats[here].x)
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = here + step
			if not stats.has(other):
				continue
			if absf(here_mean - float(stats[other].x)) >= 0.05:
				count += 1
	return count


func _one_outlier(stats: Dictionary) -> bool:
	var hits := {}
	var pairs := 0
	for cell in stats.keys():
		var here := cell as Vector2i
		var here_mean := float(stats[here].x)
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = here + step
			if not stats.has(other):
				continue
			if absf(here_mean - float(stats[other].x)) < 0.05:
				continue
			pairs += 1
			hits[here] = int(hits.get(here, 0)) + 1
			hits[other] = int(hits.get(other, 0)) + 1
	if pairs == 0:
		return true
	for cell in hits.keys():
		if int(hits[cell]) == pairs:
			return true
	return false


func _neighbour(stats: Dictionary) -> float:
	var worst := 0.0
	for cell in stats.keys():
		var here := cell as Vector2i
		var here_mean := float(stats[here].x)
		for step in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = here + step
			if not stats.has(other):
				continue
			worst = maxf(worst, absf(here_mean - float(stats[other].x)))
	return worst


func _lum(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
