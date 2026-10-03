extends SceneTree

## Renders the deployment phase and checks the zone paint.
## No deploy-zone pixel may be brighter than the move-tile fill, and
## neighbouring cells of the same kind stay within 0.05 mean luminance.
## Crosshaven neighbours stay under 0.05. On Thunderwell the pillar at
## (11, 3) crosses one deploy cell, so that one cell may differ; a checker
## would light more than that single pair.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/deploy_zone_pixels.gd

const _INSET := 0.62

var _failed := false


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	var units: CanvasItem = board.get_node_or_null("Units")
	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	if units != null:
		units.visible = false
	await _settle()
	await _measure(board, sim, "crosshaven")
	board.set_board_theme("thunderwell")
	board._refresh()
	if units != null:
		units.visible = false
	await _settle()
	await _measure(board, sim, "thunderwell")
	quit(1 if _failed else 0)


func _settle() -> void:
	for _i in 24:
		await process_frame


func _measure(board: Node2D, sim: Node, tag: String) -> void:
	var cam: Camera2D = board.get("_camera")
	var p1: Array[Vector2i] = sim.deploy_zone_cells(0)
	var p2: Array[Vector2i] = sim.deploy_zone_cells(1)
	var move_at := Vector2i(7, 7)
	if p1.has(move_at) or p2.has(move_at):
		move_at = Vector2i(0, 0)
	var move_tile: BoardTile = board.tiles[move_at]
	BoardTile.set_move_pulse_time(0.0)
	move_tile.set_highlight("move")
	await _settle()
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail(tag + " viewport image is empty")
		return
	var move_peak := _cell_stats(image, cam, move_tile).y
	move_tile.set_highlight("")
	board._refresh()
	units_hidden(board)
	await _settle()
	var painted := root.get_viewport().get_texture().get_image()
	var fill_cap := _lum(Color(0.55, 0.93, 1.0))
	var cap := maxf(move_peak, fill_cap)
	if move_peak < 0.45 or move_peak >= 0.98:
		_fail("%s move tile peak %.3f is not the painted fill" % [tag, move_peak])
	var open := _zone_stats(painted, board, cam, p1, p2)
	_check_zones(tag, "open", open, cap)
	for cell in p1:
		(board.tiles[cell] as BoardTile).set_highlight("locked_p1")
	for cell in p2:
		(board.tiles[cell] as BoardTile).set_highlight("locked_p2")
	await _settle()
	var locked_image := root.get_viewport().get_texture().get_image()
	var locked := _zone_stats(locked_image, board, cam, p1, p2)
	_check_zones(tag, "locked", locked, cap)
	print("DEPLOY_PIXELS %s move=%.3f cap=%.3f open_max=%.3f open_neighbour=%.3f locked_max=%.3f locked_neighbour=%.3f" % [
		tag, move_peak, cap, _peak(open), _neighbour(open), _peak(locked), _neighbour(locked),
	])


func units_hidden(board: Node2D) -> bool:
	var units: CanvasItem = board.get_node_or_null("Units")
	if units != null:
		units.visible = false
	return true


func _check_zones(tag: String, phase: String, stats: Dictionary, cap: float) -> void:
	var peak := _peak(stats)
	var neighbour := _neighbour(stats)
	var hot := _hot_pairs(stats)
	if peak > cap:
		_fail("%s %s peak %.3f is above the move fill cap %.3f" % [tag, phase, peak, cap])
	# A checker lights every other cell, so many neighbour pairs jump.
	# One Thunderwell pillar beam can cross a single deploy cell.
	var limit := 0 if tag == "crosshaven" else 2
	if hot > limit or (tag == "crosshaven" and neighbour >= 0.05):
		_fail("%s %s neighbour delta %.3f across %d pairs" % [tag, phase, neighbour, hot])
		for cell in stats.keys():
			print("  CELL ", cell, " mean ", float(stats[cell].x), " peak ", float(stats[cell].y))
	elif neighbour >= 0.05 and not _one_outlier(stats):
		_fail("%s %s neighbour delta %.3f is not one cell" % [tag, phase, neighbour])


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
			if absf(float(dx)) / half_w + absf(float(dy)) / half_h > _INSET:
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


## Every hot pair shares one cell. A checker does not.
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


func _fail(msg: String) -> void:
	_failed = true
	print("DEPLOY_PIXELS_FAIL ", msg)
