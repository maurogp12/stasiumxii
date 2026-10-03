extends SceneTree

## Stormspire frames for the Thunderwell Core floor, through the HDR preview.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_thunderwell_look.gd -- --out=/tmp/l4_frames

const FLOOR := preload("res://board/pc/thunderwell_floor.gd")

var _out := "/tmp/l4_frames"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			_out = str(arg).trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var preview := (load("res://scenes/pc/look_preview.tscn") as PackedScene).instantiate()
	root.add_child(preview)
	var board: Node2D = preview.find_child("BoardView", true, false)
	if board == null:
		push_error("BoardView missing")
		quit(1)
		return
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	root.get_node("CombatSim").reset_match({
		"seed": 4,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(7, 8),
		"ironjaw_pos": Vector2i(1, 1),
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	await _settle(4)
	await _shot(_out.path_join("before.png"))
	board.set_board_theme("thunderwell")
	var layer = board.get_node_or_null("ThunderwellFloor")
	if layer == null:
		push_error("ThunderwellFloor missing")
		quit(1)
		return
	board._paint_highlights()
	_mark_hover(board, Vector2i(6, 9))
	var frames := 12
	var period := 1.0 / 0.22
	for i in frames:
		layer.preview_time(period * float(i) / float(frames))
		await _settle(1)
		await _shot(_out.path_join("after_%02d.png" % i))
	await _shot(_out.path_join("move_range.png"))
	_clear_highlights(board)
	var pad_cell := Vector2i(7, 2)
	var pillar_move := Vector2i(3, 4)
	var pad_trace := _nearest_trace(board, pad_cell)
	var pillar_trace := _nearest_trace(board, pillar_move)
	_highlight(board, pad_cell, "move")
	_highlight(board, pillar_move, "move")
	var units := board.get_node_or_null("Units") as CanvasItem
	if units != null:
		units.visible = false
	var pad_image := await _grab_at(layer, _full_pulse(layer, board, pad_trace))
	if pad_image != null:
		pad_image.save_png(_out.path_join("glow_sample_pad.png"))
	_report_pair(board, layer, pad_image, pad_cell, pad_trace, "pad")
	var pillar_image := await _grab_at(layer, _full_pulse(layer, board, pillar_trace))
	if pillar_image != null:
		pillar_image.save_png(_out.path_join("glow_sample.png"))
	_report_pair(board, layer, pillar_image, pillar_move, pillar_trace, "pillar")
	await _report_pillar_peak(board, layer, pillar_move)
	if units != null:
		units.visible = true
	_place_for_range()
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("thunderwell")
	board._paint_highlights()
	_mark_hover(board, Vector2i(6, 9))
	await _shot(_out.path_join("move_range.png"))
	print("THUNDERWELL_CAPTURE %s" % _out)
	quit(0)


func _place_for_range() -> void:
	root.get_node("CombatSim").reset_match({
		"seed": 4,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(7, 8),
		"ironjaw_pos": Vector2i(1, 1),
	})


func _mark_hover(board: Node, cell: Vector2i) -> void:
	var tiles: Dictionary = board.get("tiles")
	if not tiles.has(cell):
		return
	var tile: Node = tiles[cell]
	tile.set("is_selected", true)
	if tile.has_method("_request_paint"):
		tile.call("_request_paint")


func _nearest_trace(board: Node, around: Vector2i) -> Vector2i:
	var tiles: Dictionary = board.get("tiles")
	var best := Vector2i(-1, -1)
	var best_d := 999
	for cell in tiles.keys():
		if cell == around:
			continue
		var glow := (tiles[cell] as Node).get_node_or_null("ThunderGlow") as Sprite2D
		if glow == null or not (glow.texture is AtlasTexture):
			continue
		var atlas := glow.texture as AtlasTexture
		if atlas.atlas == null:
			continue
		var slice := float(atlas.atlas.get_width()) / 8.0
		if slice < 1.0:
			continue
		var index := int(round(atlas.region.position.x / slice))
		if index < 2:
			continue
		var dist := absi(cell.x - around.x) + absi(cell.y - around.y)
		if dist < best_d:
			best_d = dist
			best = cell
	return best


func _full_pulse(layer: Node, board: Node, cell: Vector2i) -> float:
	var tiles: Dictionary = board.get("tiles")
	if not tiles.has(cell):
		return 0.0
	var glow := (tiles[cell] as Node).get_node_or_null("ThunderGlow") as CanvasItem
	if glow == null or not (glow.material is ShaderMaterial):
		return 0.0
	var phase := float((glow.material as ShaderMaterial).get_shader_parameter("phase"))
	return layer.full_pulse_time(phase)


func _grab_at(layer: Node, t: float) -> Image:
	await process_frame
	layer.preview_time(t)
	RenderingServer.force_draw()
	return root.get_texture().get_image()


func _move_near_pillar(board: Node, layer: Node) -> Vector2i:
	var tiles: Dictionary = board.get("tiles")
	var best := Vector2i(-1, -1)
	var best_d := 999
	for child in layer.get_children():
		if not str(child.name).begins_with("ThunderPillar") or not child.has_meta("cell"):
			continue
		var cell: Vector2i = child.get_meta("cell")
		for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = cell + delta
			if not tiles.has(neighbor):
				continue
			var trace := _nearest_trace(board, neighbor)
			var dist := absi(trace.x - neighbor.x) + absi(trace.y - neighbor.y)
			if dist == 1 and dist < best_d:
				best_d = dist
				best = neighbor
				return best
	return best


func _report_pair(board: Node, layer: Node, image: Image, move_cell: Vector2i, trace_cell: Vector2i, label: String) -> void:
	if image == null:
		push_error("no %s frame to sample" % label)
		return
	var tiles: Dictionary = board.get("tiles")
	var move_tile: Node2D = tiles[move_cell]
	var trace_tile: Node2D = tiles[trace_cell]
	var zoom := _zoom(board)
	var move := _sample_point(image, _screen(move_tile))
	var inner := _dimmest_cyan(image, _screen(move_tile), zoom)
	var trace := _brightest_green(image, _screen(trace_tile), _screen(move_tile), zoom, _pillar_sprites(layer))
	_print_sample("move_%s" % label, move)
	_print_sample("move_%s_inner" % label, inner)
	_print_sample("trace_%s" % label, trace)
	var ahead := float(move["lum"]) > float(trace["lum"]) and float(inner["lum"]) > float(trace["lum"])
	print("GLOW_FULL_PULSE %s move_cell=%s trace_cell=%s move=%.4f inner=%.4f trace=%.4f ahead=%s" % [label, move_cell, trace_cell, float(move["lum"]), float(inner["lum"]), float(trace["lum"]), str(ahead)])


func _dimmest_cyan(image: Image, center: Vector2, zoom: float) -> Dictionary:
	var best := _sample_point(image, center)
	var half_x := 32.0 * zoom * 0.55
	var half_y := 16.0 * zoom * 0.55
	var x0 := clampi(int(floor(center.x - half_x)), 0, image.get_width() - 1)
	var x1 := clampi(int(ceil(center.x + half_x)), 0, image.get_width())
	var y0 := clampi(int(floor(center.y - half_y)), 0, image.get_height() - 1)
	var y1 := clampi(int(ceil(center.y + half_y)), 0, image.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			if absf(float(x) - center.x) / maxf(half_x, 1.0) + absf(float(y) - center.y) / maxf(half_y, 1.0) > 1.0:
				continue
			var color := image.get_pixel(x, y)
			if color.b <= color.g or color.b < color.r + 0.18:
				continue
			var sample := {"color": color, "lum": _lum(color), "at": Vector2i(x, y)}
			if float(sample["lum"]) < float(best["lum"]):
				best = sample
	return best


func _brightest_green(image: Image, center: Vector2, avoid: Vector2, zoom: float, pillars: Array) -> Dictionary:
	var best := {"color": Color(0, 0, 0), "lum": -1.0, "at": Vector2i.ZERO}
	var half_x := 32.0 * zoom
	var half_y := 16.0 * zoom
	var x0 := clampi(int(floor(center.x - half_x)), 0, image.get_width() - 1)
	var x1 := clampi(int(ceil(center.x + half_x)), 0, image.get_width())
	var y0 := clampi(int(floor(center.y - half_y)), 0, image.get_height() - 1)
	var y1 := clampi(int(ceil(center.y + half_y)), 0, image.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			if absf(float(x) - center.x) / half_x + absf(float(y) - center.y) / half_y > 1.0:
				continue
			if absf(float(x) - avoid.x) / half_x + absf(float(y) - avoid.y) / half_y <= 1.0:
				continue
			if _pixel_on_pillar(pillars, x, y):
				continue
			var color := image.get_pixel(x, y)
			if color.g < color.r + 0.18 or color.g < color.b + 0.04:
				continue
			var lum := _lum(color)
			if lum > float(best["lum"]):
				best = {"color": color, "lum": lum, "at": Vector2i(x, y)}
	return best


func _report_pillar_peak(board: Node, layer: Node, beside: Vector2i) -> void:
	var pillar := _pillar_at(layer, beside)
	if pillar == null:
		return
	var cell: Vector2i = pillar.get_meta("cell")
	_highlight(board, cell, "move")
	var image := await _grab_at(layer, layer.full_pulse_time(0.0))
	if image == null:
		return
	var peak := _sample_point(image, _screen(pillar))
	_print_sample("pillar_pool_over_move", peak)
	_print_sample("pillar_sprite_over_move", _brightest(image, _screen_rect(pillar)))
	_highlight(board, cell, "")
	var plain := await _grab_at(layer, layer.full_pulse_time(0.0))
	if plain == null:
		return
	_print_sample("pillar_pool_over_floor", _sample_point(plain, _screen(pillar)))
	_print_sample("pillar_sprite_over_floor", _brightest(plain, _screen_rect(pillar)))
	var tiles: Dictionary = board.get("tiles")
	if tiles.has(Vector2i(8, 5)):
		_print_sample("quiet_floor", _sample_point(plain, _screen(tiles[Vector2i(8, 5)])))


func _report_glow(board: Node, layer: Node, image: Image, pad_cell: Vector2i, beside: Vector2i) -> void:
	if image == null:
		push_error("no preview frame to sample")
		return
	print("GLOW_IMAGE format=%s size=%sx%s" % [image.get_format(), image.get_width(), image.get_height()])
	var pad_tile: Node2D = board.get("tiles")[pad_cell]
	var beside_tile: Node2D = board.get("tiles")[beside]
	var move_pad := _sample_point(image, _screen(pad_tile))
	var move_pillar := _sample_point(image, _screen(beside_tile))
	var pad_center := _screen(pad_tile)
	var beside_center := _screen(beside_tile)
	var zoom := _zoom(board)
	var pad_sprite := pad_tile.get_node_or_null("ThunderPad") as Sprite2D
	var pad_px := _brightest(image, _screen_rect(pad_sprite), pad_center, zoom, pad_sprite)
	var pillars := _pillar_sprites(layer)
	var trace_near_pad := _brightest_glow(board, image, pad_cell, pad_center, zoom, pillars)
	var pillar := _pillar_at(layer, beside)
	var pillar_px := _brightest(image, _screen_rect(pillar), beside_center, zoom, pillar)
	var trace_near_pillar := _brightest_glow(board, image, beside, beside_center, zoom, pillars)
	var brightest := pad_px
	for sample in [trace_near_pad, pillar_px, trace_near_pillar]:
		if float(sample["lum"]) > float(brightest["lum"]):
			brightest = sample
	_print_sample("move_over_pad", move_pad)
	_print_sample("move_beside_pillar", move_pillar)
	_print_sample("brightest_glow", brightest)
	_print_sample("pad_near_move", pad_px)
	_print_sample("trace_near_pad", trace_near_pad)
	_print_sample("pillar_near_move", pillar_px)
	_print_sample("trace_near_pillar", trace_near_pillar)
	var tiles: Dictionary = board.get("tiles")
	if tiles.has(Vector2i(8, 5)):
		_print_sample("quiet_floor", _sample_point(image, _screen(tiles[Vector2i(8, 5)])))
	if tiles.has(Vector2i(9, 6)):
		_print_sample("quiet_neighbor", _sample_point(image, _screen(tiles[Vector2i(9, 6)])))
	var glow_l := float(brightest["lum"])
	print("GLOW_ZOOM %s pad=%s beside=%s" % [zoom, pad_cell, beside])
	print("GLOW_STRENGTH trace=%s pad=%s pillar=%s" % [FLOOR.glow_strength(), FLOOR.pad_strength(), FLOOR.pillar_strength()])
	print("GLOW_BELOW_MOVE %s" % str(glow_l < float(move_pad["lum"]) and glow_l < float(move_pillar["lum"])))
	print("GLOW_VS_PAD_TILE glow=%s move=%s" % [glow_l, float(move_pad["lum"])])
	print("GLOW_VS_PILLAR_TILE glow=%s move=%s" % [glow_l, float(move_pillar["lum"])])
	var trace_under := float(trace_near_pad["lum"]) < float(move_pad["lum"]) and float(trace_near_pillar["lum"]) < float(move_pillar["lum"])
	print("GLOW_TRACE_UNDER_MOVE %s" % str(trace_under))
	print("GLOW_TRACE_VS_MOVE pad_trace=%s pad_move=%s pillar_trace=%s pillar_move=%s" % [float(trace_near_pad["lum"]), float(move_pad["lum"]), float(trace_near_pillar["lum"]), float(move_pillar["lum"])])


func _print_sample(label: String, sample: Dictionary) -> void:
	var color: Color = sample["color"]
	print("GLOW_SAMPLE %s hex=%s lum=%.4f raw=(%.3f,%.3f,%.3f) at=%s" % [label, _hex(color), float(sample["lum"]), color.r, color.g, color.b, sample["at"]])


func _pad_cell(board: Node) -> Vector2i:
	var tiles: Dictionary = board.get("tiles")
	var best := Vector2i(-1, -1)
	var best_d := 999
	for cell in tiles.keys():
		var pad := (tiles[cell] as Node).get_node_or_null("ThunderPad")
		if pad == null:
			continue
		var dist := absi(cell.x - 7) + absi(cell.y - 7)
		if dist < best_d:
			best_d = dist
			best = cell
	return best


func _pillar_neighbor(layer: Node, board: Node) -> Vector2i:
	var tiles: Dictionary = board.get("tiles")
	for child in layer.get_children():
		if not str(child.name).begins_with("ThunderPillar") or not child.has_meta("cell"):
			continue
		var cell: Vector2i = child.get_meta("cell")
		for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = cell + delta
			if tiles.has(neighbor):
				return neighbor
	return Vector2i(-1, -1)


func _pillar_at(layer: Node, neighbor: Vector2i) -> Sprite2D:
	for child in layer.get_children():
		if not str(child.name).begins_with("ThunderPillar") or not child.has_meta("cell"):
			continue
		var cell: Vector2i = child.get_meta("cell")
		if absi(cell.x - neighbor.x) + absi(cell.y - neighbor.y) == 1:
			return child as Sprite2D
	return null


func _pillar_sprites(layer: Node) -> Array:
	var out: Array = []
	for child in layer.get_children():
		if str(child.name).begins_with("ThunderPillar"):
			out.append(child)
	return out


func _brightest_glow(board: Node, image: Image, around: Vector2i, avoid: Vector2, zoom: float, pillars: Array) -> Dictionary:
	var tiles: Dictionary = board.get("tiles")
	var best := {"color": Color(0, 0, 0), "lum": 0.0, "at": Vector2i.ZERO}
	for cell in tiles.keys():
		if absi(cell.x - around.x) + absi(cell.y - around.y) > 2:
			continue
		if cell == around:
			continue
		var glow := (tiles[cell] as Node).get_node_or_null("ThunderGlow") as Sprite2D
		if glow == null:
			continue
		var sample := _brightest_trace(image, _screen_rect(glow), avoid, zoom, glow, pillars)
		if float(sample["lum"]) > float(best["lum"]):
			best = sample
	return best


func _brightest_trace(image: Image, rect: Rect2, avoid: Vector2, zoom: float, sprite: Sprite2D, pillars: Array) -> Dictionary:
	var best := {"color": Color(0, 0, 0), "lum": -1.0, "at": Vector2i.ZERO}
	if image == null or rect.size == Vector2.ZERO:
		return best
	var x0 := clampi(int(floor(minf(rect.position.x, rect.end.x))), 0, image.get_width() - 1)
	var x1 := clampi(int(ceil(maxf(rect.position.x, rect.end.x))), 0, image.get_width())
	var y0 := clampi(int(floor(minf(rect.position.y, rect.end.y))), 0, image.get_height() - 1)
	var y1 := clampi(int(ceil(maxf(rect.position.y, rect.end.y))), 0, image.get_height())
	var half_x := 32.0 * zoom
	var half_y := 16.0 * zoom
	var near := 96.0
	var tex := _sprite_image(sprite)
	for y in range(y0, y1):
		for x in range(x0, x1):
			if avoid.x > -1000.0:
				var dx := float(x) - avoid.x
				var dy := float(y) - avoid.y
				if dx * dx + dy * dy > near * near:
					continue
			if half_x > 1.0 and absf(float(x) - avoid.x) / half_x + absf(float(y) - avoid.y) / half_y <= 1.55:
				continue
			if tex != null and not _pixel_is_glow(sprite, tex, x, y):
				continue
			if _pixel_on_pillar(pillars, x, y) or _near_pillar_beam(pillars, x, y):
				continue
			var color := image.get_pixel(x, y)
			# Pillar bloom is pale. A trace stays green, so the sample is the circuit.
			if color.g < color.r + 0.08 or color.g < color.b:
				continue
			var lum := _lum(color)
			if lum > float(best["lum"]):
				best = {"color": color, "lum": lum, "at": Vector2i(x, y)}
	return best


func _near_pillar_beam(pillars: Array, x: int, y: int) -> bool:
	for pillar in pillars:
		var sprite := pillar as Sprite2D
		if sprite == null:
			continue
		var base := _screen(sprite)
		if absf(float(x) - base.x) > 28.0:
			continue
		if float(y) > base.y + 8.0 or float(y) < base.y - 180.0:
			continue
		return true
	return false


func _pixel_on_pillar(pillars: Array, x: int, y: int) -> bool:
	for pillar in pillars:
		var sprite := pillar as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var tex := _sprite_image(sprite)
		if tex == null:
			continue
		var local := sprite.to_local(sprite.get_viewport().get_canvas_transform().affine_inverse() * Vector2(x + 0.5, y + 0.5))
		var size := Vector2(tex.get_width(), tex.get_height())
		var origin := sprite.offset
		if sprite.centered:
			origin -= size * 0.5
		var px := local - origin
		var tx := int(floor(px.x))
		var ty := int(floor(px.y))
		if tx < 0 or ty < 0 or tx >= tex.get_width() or ty >= tex.get_height():
			continue
		var sample := tex.get_pixel(tx, ty)
		var ink := (0.2126 * sample.r + 0.7152 * sample.g + 0.0722 * sample.b) * sample.a
		if ink >= 0.04:
			return true
	return false


func _zoom(board: Node) -> float:
	var cam := board.get_node_or_null("BoardCamera") as Camera2D
	if cam == null or cam.zoom.x < 0.01:
		return 1.0
	return cam.zoom.x


func _highlight(board: Node, cell: Vector2i, kind: String) -> void:
	var tiles: Dictionary = board.get("tiles")
	if tiles.has(cell):
		(tiles[cell] as Node).set_highlight(kind)


func _clear_highlights(board: Node) -> void:
	var tiles: Dictionary = board.get("tiles")
	for cell in tiles.keys():
		(tiles[cell] as Node).set_highlight("")


func _screen(node: Node2D) -> Vector2:
	return node.get_viewport().get_canvas_transform() * node.global_position


func _screen_rect(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2()
	var size := sprite.texture.get_size()
	var origin := sprite.offset
	if sprite.centered:
		origin -= size * 0.5
	var a := _screen_local(sprite, origin)
	var b := _screen_local(sprite, origin + size)
	return Rect2(a, Vector2.ZERO).expand(b)


func _screen_local(sprite: Sprite2D, point: Vector2) -> Vector2:
	return sprite.get_viewport().get_canvas_transform() * sprite.to_global(point)


func _sample_point(image: Image, screen_at: Vector2) -> Dictionary:
	var x := clampi(int(round(screen_at.x)), 0, image.get_width() - 1)
	var y := clampi(int(round(screen_at.y)), 0, image.get_height() - 1)
	var color := image.get_pixel(x, y)
	return {"color": color, "lum": _lum(color), "at": Vector2i(x, y)}


func _brightest(image: Image, rect: Rect2, avoid: Vector2 = Vector2(-9999, -9999), zoom: float = 1.0, sprite: Sprite2D = null) -> Dictionary:
	var best := {"color": Color(0, 0, 0), "lum": -1.0, "at": Vector2i.ZERO}
	if image == null or rect.size == Vector2.ZERO:
		return best
	var x0 := clampi(int(floor(minf(rect.position.x, rect.end.x))), 0, image.get_width() - 1)
	var x1 := clampi(int(ceil(maxf(rect.position.x, rect.end.x))), 0, image.get_width())
	var y0 := clampi(int(floor(minf(rect.position.y, rect.end.y))), 0, image.get_height() - 1)
	var y1 := clampi(int(ceil(maxf(rect.position.y, rect.end.y))), 0, image.get_height())
	var half_x := 32.0 * zoom
	var half_y := 16.0 * zoom
	var near := 96.0
	var tex := _sprite_image(sprite)
	for y in range(y0, y1):
		for x in range(x0, x1):
			if avoid.x > -1000.0:
				var dx := float(x) - avoid.x
				var dy := float(y) - avoid.y
				if dx * dx + dy * dy > near * near:
					continue
			if half_x > 1.0 and absf(float(x) - avoid.x) / half_x + absf(float(y) - avoid.y) / half_y <= 1.55:
				continue
			if tex != null and not _pixel_is_glow(sprite, tex, x, y):
				continue
			var color := image.get_pixel(x, y)
			var lum := _lum(color)
			if lum > float(best["lum"]):
				best = {"color": color, "lum": lum, "at": Vector2i(x, y)}
	return best


func _sprite_image(sprite: Sprite2D) -> Image:
	if sprite == null or sprite.texture == null:
		return null
	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		return null
	return image


func _pixel_is_glow(sprite: Sprite2D, tex: Image, x: int, y: int) -> bool:
	var local := sprite.to_local(sprite.get_viewport().get_canvas_transform().affine_inverse() * Vector2(x + 0.5, y + 0.5))
	var size := Vector2(tex.get_width(), tex.get_height())
	var origin := sprite.offset
	if sprite.centered:
		origin -= size * 0.5
	var px := local - origin
	var tx := int(floor(px.x))
	var ty := int(floor(px.y))
	if tx < 0 or ty < 0 or tx >= tex.get_width() or ty >= tex.get_height():
		return false
	var sample := tex.get_pixel(tx, ty)
	var ink := sample.r * sample.a if sprite.name == "ThunderGlow" else (0.2126 * sample.r + 0.7152 * sample.g + 0.0722 * sample.b) * sample.a
	return ink >= 0.45


func _lum(color: Color) -> float:
	return 0.2126 * _lin(color.r) + 0.7152 * _lin(color.g) + 0.0722 * _lin(color.b)


func _lin(channel: float) -> float:
	var c := clampf(channel, 0.0, 1.0)
	if c <= 0.04045:
		return c / 12.92
	return pow((c + 0.055) / 1.055, 2.4)


func _hex(color: Color) -> String:
	var r := clampi(int(round(clampf(color.r, 0.0, 1.0) * 255.0)), 0, 255)
	var g := clampi(int(round(clampf(color.g, 0.0, 1.0) * 255.0)), 0, 255)
	var b := clampi(int(round(clampf(color.b, 0.0, 1.0) * 255.0)), 0, 255)
	return "#%02x%02x%02x" % [r, g, b]


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame


func _shot(path: String) -> void:
	var image := await _grab()
	if image == null or image.get_width() < 2:
		push_error("empty frame %s" % path)
		return
	image.save_png(path)


func _grab() -> Image:
	await process_frame
	RenderingServer.force_draw()
	return root.get_texture().get_image()
