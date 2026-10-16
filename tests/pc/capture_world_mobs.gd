extends SceneTree

## World monster media for Mauro (package Z1). Not a test suite; needs a GL
## context. Drives the real world scene: walk Stoneford with packs on the map,
## hover plates, a 3-pack fight on the world cells, a 10-pack fight, and a
## forced world boss (banner, marker, fight). Record with the movie writer:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1920x1080 --fixed-fps 30 \
##     --write-movie /tmp/mobs/clip.avi -s res://tests/pc/capture_world_mobs.gd -- --movie mobs --mode=clip --pace 0.18
## Stills (PNG into --out):
##   xvfb-run ... -s res://tests/pc/capture_world_mobs.gd -- --movie mobs --mode=stills --out=/tmp/mobs

const WORLD := "res://scenes/world/crosshaven/crosshaven_world.tscn"
const Layer := preload("res://scenes/world/monster/world_mob_layer.gd")

var _mode := "clip"
var _out := "/tmp/mobs"
var _caption: Label
var _layer: CanvasLayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var look := VisualSettings.new()
	look.apply_preset("Full")
	Layer.reset_state()
	_run.call_deferred()


func _world() -> Node:
	return current_scene


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _until(cond: Callable, limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await process_frame


func _caption_text(text: String) -> void:
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 50
		root.add_child(_layer)
		_caption = Label.new()
		_caption.add_theme_font_size_override("font_size", 26)
		_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_caption.add_theme_constant_override("outline_size", 7)
		_caption.position = Vector2(40, 990)
		_layer.add_child(_caption)
	_caption.text = text


func _load_world() -> Node:
	change_scene_to_file(WORLD)
	await _until(func(): return current_scene != null and current_scene.has_method("walk_to") and current_scene.get("zone") != null, 30.0)
	await _wait(0.8)
	var w := _world()
	w.weather.auto_rotate = false
	return w


func _to_fields(w: Node, cell: Vector2i) -> void:
	await w.enter_zone("crosshaven_stoneford_fields", cell, false)
	w._set_zoom(1.6)
	await _wait(1.0)


func _pack_of(w: Node, want: int) -> Dictionary:
	var best := {}
	for e in w.mobs.live_entries():
		if (e["pack"] as Dictionary).has("boss"):
			continue
		if best.is_empty() or absi(int(e["pack"]["size"]) - want) < absi(int(best["pack"]["size"]) - want):
			best = e
	if not best.is_empty() and int(best["pack"]["size"]) != want:
		# Re-roll this pack to the size the clip shows (same chunk, same levels).
		var p: Dictionary = w.mobs.book.make_pack(w.mobs.levels, w.zone.zone_id, RandomNumberGenerator.new(), want)
		best["pack"] = p
		best["cells"] = w.mobs.book.body_cells(w.zone, best["home"], mini(want, 6), w.mobs.forbidden, {})
		w.mobs.restock(w.zone, w._origin_of(w.zone.zone_id))
		for e in w.mobs.live_entries():
			if str(e["id"]) == str(best["id"]):
				best = e
	return best


func _hover_pack(w: Node, e: Dictionary) -> void:
	var c: Vector2i = e["cells"][0]
	var world_px: Vector2 = BoardVisualSort.cell_to_local(w._origin_of(w.zone.zone_id) + c, float(w.zone.height_at(c)))
	var screen: Vector2 = w.get_canvas_transform() * (world_px + Vector2(0, -20))
	w.mobs.hover(c, screen, int(w.progress.level))


func _fight(w: Node, e: Dictionary, caption: String) -> void:
	_caption_text(caption)
	w.approach_pack(str(e["id"]))
	await _until(func(): return current_scene != null and current_scene.has_method("result_text"), 40.0)
	await _until(func(): return current_scene == null or not current_scene.has_method("result_text"), 240.0)
	await _until(func(): return current_scene != null and current_scene.has_method("walk_to") and current_scene.get("zone") != null, 30.0)
	await _wait(1.2)


func _run() -> void:
	var w := await _load_world()
	if _mode == "stills":
		await _stills(w)
		quit()
		return
	await _to_fields(w, Vector2i(30, 24))
	_caption_text("Stoneford fields · packs of 2 to 10 on the map (levels 8–10 here)")
	var route := [Vector2i(36, 22), Vector2i(44, 20), Vector2i(50, 18)]
	for c in route:
		w.walk_to(w.nearest_reachable(c))
		await _until(func(): return not w.walker.is_moving(), 12.0)
		await _wait(0.6)
	var three := _pack_of(w, 3)
	_caption_text("Hover: pack size, level range, total level")
	_hover_pack(w, three)
	await _wait(2.5)
	await _fight(w, three, "Click: the fight starts on the world cells round the pack")
	w = _world()
	_caption_text("Won: XP and coins, and the pack is gone (it respawns in 90 s)")
	await _wait(2.5)
	var ten := _pack_of(w, 10)
	_hover_pack(w, ten)
	_caption_text("A pack of 10: a real choice")
	await _wait(2.5)
	await _fight(w, ten, "A 10-pack fight on the field")
	w = _world()
	await _wait(1.0)
	w.force_next_boss()
	_caption_text("Dev command: force the zone's world boss (night: Grimhoot)")
	await _wait(3.0)
	var boss := {}
	for e in w.mobs.live_entries():
		if bool(e["pack"].get("boss", false)):
			boss = e
	if not boss.is_empty():
		_hover_pack(w, boss)
		await _wait(2.0)
		await _fight(w, boss, "World boss fight")
	await _wait(2.0)
	quit()


func _stills(w: Node) -> void:
	await _to_fields(w, Vector2i(30, 24))
	await _wait(1.5)
	await _grab("map_packs.png")
	var e := _pack_of(w, 7)
	_hover_pack(w, e)
	await _wait(0.4)
	await _grab("hover_plate.png")
	w.force_next_boss()
	await _wait(2.0)
	for b in w.mobs.live_entries():
		if bool(b["pack"].get("boss", false)):
			var c: Vector2i = b["home"]
			w.walker.place(w.zone, w.nearest_reachable(c + Vector2i(0, 3)))
	await _wait(1.5)
	await _grab("boss_on_map.png")


func _grab(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(_out.path_join(name))
