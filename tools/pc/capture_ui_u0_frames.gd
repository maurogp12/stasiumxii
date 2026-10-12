extends SceneTree

## Real 1920x1080 plates for the U0 HUD mockups. Not a test suite.
## Needs a GL context (the headless dummy renderer cannot read these pixels).
##
##   XDG_DATA_HOME=/tmp/ui-u0-data xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --rendering-driver opengl3 --audio-driver Dummy --path . \
##     --resolution 1920x1080 \
##     -s res://tools/pc/capture_ui_u0_frames.gd -- \
##     --out=docs/pc/look_target/ui_u0/real_frames --class ironjaw
##
## The window keeps the project stretch (960x720 base, canvas_items, expand),
## so a 1920x1080 window is the game on a 1080p screen. Zoom stays the world's
## default (1.6). Visuals are the Full preset. --class ironjaw is the hero
## (the world defaults to Ironjaw; the dungeon scene defaults to Kestrel).
## Add --preview to also write coast and farm candidates under the out folder.

const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const DUNGEON_PATH := "res://scenes/world/dungeon/dungeon_run.tscn"

var _out := "docs/pc/look_target/ui_u0/real_frames"
var _preview := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text == "--preview":
			_preview = true
	_go.call_deferred()


func _go() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var folder := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	if not folder.is_absolute_path():
		folder = ProjectSettings.globalize_path("res://" + folder.trim_prefix("./"))
	DirAccess.make_dir_recursive_absolute(folder)
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	# A non-empty movie skips the slow-machine performance offer and opens
	# the 1920x1080 world window. The one-shot movie player is dropped so
	# this script owns the camera.
	w._movie = "ui_u0_hold"
	root.add_child(w)
	if w.get_tree().process_frame.is_connected(w._start_movie):
		w.get_tree().process_frame.disconnect(w._start_movie)
	w.settings.apply_preset("Full")
	w.weather.auto_rotate = false
	w.weather.time_scale = 0.0
	w.weather.set_weather("clear")
	w.weather.time_of_day = 12.0
	w.weather.settle()
	w._zoom = 1.6
	w.camera.zoom = Vector2.ONE * 1.6
	_plate(w)
	await _frames(8)
	var plaza := await _stand_near_guide(w)
	await _still(w, "crosshaven_crossroads", plaza, "e", folder.path_join("frame1_crossroads_plaza.png"))
	if _preview:
		await _still(w, "crosshaven_eastmarch_coves", Vector2i(22, 6), "s", folder.path_join("cand_eastmarch_coves.png"))
		await _still(w, "crosshaven_eastmarch_beach", Vector2i(18, 8), "s", folder.path_join("cand_eastmarch_beach.png"))
		await _still(w, "crosshaven_eastmarch_north_shore", Vector2i(18, 16), "e", folder.path_join("cand_eastmarch_north_shore.png"))
		await _still(w, "crosshaven_stoneford_fields", Vector2i(36, 17), "s", folder.path_join("cand_stoneford_fields.png"))
		await _still(w, "crosshaven_stoneford_mill", Vector2i(16, 16), "s", folder.path_join("cand_stoneford_mill.png"))
	else:
		await _still(w, "crosshaven_eastmarch_coves", Vector2i(22, 6), "s", folder.path_join("frame3_crosshaven.png"))
	w.queue_free()
	await _frames(2)
	await _granary(folder.path_join("frame2_granary_fight.png"))
	quit(0)


func _plate(w: Node2D) -> void:
	w._hide_debug_readout()
	if w.tracker != null:
		w.tracker.visible = false
	if w._banner != null:
		w._banner.modulate.a = 0.0


func _still(w: Node2D, zone_id: String, cell: Vector2i, face: String, path: String) -> void:
	var stood := _passable_near(w, zone_id, cell)
	await w.enter_zone(zone_id, stood, false)
	_plate(w)
	w.walker.facing = face
	w.walker._show_idle()
	w.camera.position = w.walker.position
	w.camera.reset_smoothing()
	w.camera.zoom = Vector2.ONE * 1.6
	await _seconds(0.85)
	_plate(w)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		push_error("no viewport image for " + path)
		return
	if image.get_size() != Vector2i(1920, 1080):
		push_error("viewport %s is not 1920x1080; not resizing" % image.get_size())
		quit(1)
		return
	image.save_png(path)
	var world_h := _opaque_height(w.walker)
	var vis := root.get_visible_rect().size
	var screen_h: float = world_h * w.camera.zoom.y * (float(root.size.y) / vis.y)
	print("CAPTURED %s zone=%s cell=%s face=%s zoom=%.2f preset=%s performance=%s window=%s visible=%s weather=%s tod=%.1f hero_world_px=%.1f hero_screen_px=%.1f class=%s" % [
		path.get_file(), w.zone.zone_id, str(w.walker.cell), w.walker.facing, w.camera.zoom.x,
		w.settings.preset, str(w.settings.performance), DisplayServer.window_get_size(), vis,
		w.weather.weather,
		w.weather.time_of_day, world_h, screen_h, w.walker.class_id,
	])


func _stand_near_guide(w: Node2D) -> Vector2i:
	var guide := Vector2i(24, 18)
	var order: Array[Vector2i] = [
		Vector2i(23, 19), Vector2i(25, 19), Vector2i(23, 18), Vector2i(25, 18),
		Vector2i(24, 19), Vector2i(22, 18), Vector2i(22, 19), Vector2i(26, 19),
	]
	for cell in order:
		if _open(w, "crosshaven_crossroads", cell):
			print("PLAZA stand ", cell, " guide ", guide)
			return cell
	print("PLAZA no adjacent cell, using spawn")
	return Vector2i(22, 18)


func _passable_near(w: Node2D, zone_id: String, cell: Vector2i) -> Vector2i:
	if _open(w, zone_id, cell):
		return cell
	for r in range(1, 6):
		for y in range(cell.y - r, cell.y + r + 1):
			for x in range(cell.x - r, cell.x + r + 1):
				var n := Vector2i(x, y)
				if _open(w, zone_id, n):
					print("MOVED ", zone_id, " ", cell, " -> ", n)
					return n
	return cell


func _open(w: Node2D, zone_id: String, cell: Vector2i) -> bool:
	var map: WorldMap = w.atlas.map_for_chunk(zone_id)
	if map == null:
		return false
	var z: WorldZone = map.zone(zone_id)
	if z == null or not z.in_bounds(cell):
		return false
	if not z.passable_at(cell):
		return false
	if not z.exit_link(cell).is_empty():
		return false
	return true


func _opaque_height(walker: Node2D) -> float:
	var sprite: Sprite2D = null
	for child in walker.get_children():
		if child is Sprite2D and (child as Sprite2D).visible and (child as Sprite2D).texture != null:
			sprite = child
			break
	if sprite == null:
		return 0.0
	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var top := -1
	var bottom := -1
	var x0 := 0
	var y0 := 0
	var wide := image.get_width()
	var tall := image.get_height()
	if sprite.region_enabled:
		x0 = int(sprite.region_rect.position.x)
		y0 = int(sprite.region_rect.position.y)
		wide = int(sprite.region_rect.size.x)
		tall = int(sprite.region_rect.size.y)
	for y in tall:
		for x in wide:
			if image.get_pixel(x0 + x, y0 + y).a > 0.2:
				if top < 0:
					top = y
				bottom = y
				break
	if top < 0:
		return 0.0
	return float(bottom - top) * absf(sprite.scale.y)


func _granary(path: String) -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var run: Node2D = (load(DUNGEON_PATH) as PackedScene).instantiate()
	root.add_child(run)
	var ready := false
	var board: Node2D = run.get_node_or_null("BoardView")
	for _i in 180:
		await process_frame
		var fade: ColorRect = run.get("_fade")
		board = run.get_node_or_null("BoardView")
		var units: Node = board.get_node_or_null("Units") if board != null else null
		if fade != null and fade.color.a < 0.05 and units != null and units.get_child_count() > 0:
			ready = true
			break
	if not ready:
		push_error("granary room did not finish fading in")
	await _seconds(0.4)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_size() != Vector2i(1920, 1080):
		push_error("granary viewport %s" % (image.get_size() if image != null else "null"))
		quit(1)
		return
	image.save_png(path)
	var zoom := 0.0
	if board != null and board.get("_camera") != null:
		zoom = float(board._camera.zoom.x)
	print("CAPTURED %s dungeon=old_granary_cellar room=A star=%s level=%s class=%s board_zoom=%.3f window=%s visible=%s preset=Full" % [
		path.get_file(), str(run.run.star) if run.run != null else "?", str(run.run.level) if run.run != null else "?",
		str(run.ctx.get("class_id", "")), zoom, DisplayServer.window_get_size(), root.get_visible_rect().size,
	])


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _seconds(sec: float) -> void:
	await create_timer(sec).timeout
