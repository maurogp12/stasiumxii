extends SceneTree

## L7 stills and the cast clip.
## Phone path is not the before frame. Before is PC on this build with the
## grade forced off, which matches the base branch's flat picture when the
## pair script composites a real base-branch grab.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l7.gd -- --out=/tmp/l7_frames --size=1280x720

const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")

var _out := "/tmp/l7_frames"
var _size := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--size="):
			var parts := text.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	await process_frame
	# Mark Shot is range 2–7. Ironjaw two cells east so the shot connects,
	# and the "+1 Mark" floater stays on Kestrel instead of covering the number.
	var number := await _still(true, "crosshaven", "", "kestrel", "ironjaw", true, Vector2i(9, 7))
	if number == null:
		quit(1)
		return
	number.save_png(_out.path_join("number.png"))
	print("L7_SHOT %s size=%s" % [_out, str(_size)])
	quit(0)


func _still(grade: bool, map_id: String, theme: String, a: String, b: String, strike: bool, foe: Vector2i = Vector2i(8, 7)) -> Image:
	HUD.set_pc_chrome_override(1)
	LIGHT.set_suppressed(not grade)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match({
		"seed": 1,
		"map_id": map_id,
		"skip_deploy": true,
		"classes": [a, b],
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": foe,
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme(theme)
	var cam := board.get_node("BoardCamera") as Camera2D
	cam.zoom = Vector2(0.72, 0.72)
	for _i in 8:
		await process_frame
	if strike:
		var hit: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": foe})
		if not bool(hit.get("ok", false)):
			push_error("strike failed %s" % str(hit))
			main.free()
			return null
		board._apply_units(sim.snapshot())
		board._arm_view_motions(hit.get("events", []))
		board._arm_vfx(hit.get("events", []))
		var shown := false
		for _i in 40:
			await process_frame
			if _number_alpha(board) > 0.85 and _number_scale(board) > 0.9 and not _impact_visible(board):
				shown = true
				break
		if not shown:
			push_error("damage number did not show")
			main.free()
			return null
		print("L7_NUMBER %s" % _number_text(board))
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	main.free()
	LIGHT.set_suppressed(false)
	HUD.set_pc_chrome_override(-1)
	for _i in 2:
		await process_frame
	return image


func _number_alpha(board: Node) -> float:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return 0.0
	var best := 0.0
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		var shown := str(child.get("_text"))
		if shown == "" or shown.contains("Impact") or not shown.is_valid_int():
			continue
		best = maxf(best, float(child.modulate.a))
	return best


func _number_scale(board: Node) -> float:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return 0.0
	var best := 0.0
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		var shown := str(child.get("_text"))
		if shown == "" or shown.contains("Impact") or not shown.is_valid_int():
			continue
		best = maxf(best, float(child.scale.x))
	return best


func _number_text(board: Node) -> String:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return ""
	var parts: PackedStringArray = []
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		var shown := str(child.get("_text"))
		if shown == "":
			continue
		parts.append(shown)
	return " ".join(parts)


func _impact_visible(board: Node) -> bool:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return false
	for child in director.get_children():
		if child == null:
			continue
		if str(child.get("kind")) == "impact" and float(child.modulate.a) > 0.2:
			return true
	return false


func _pair(left: Image, right: Image, path: String) -> void:
	var gap := 8
	var width := left.get_width() + right.get_width() + gap
	var height := maxi(left.get_height(), right.get_height())
	var out := Image.create(width, height, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.07, 0.06, 1))
	_blit(out, left, Vector2i(0, 0))
	_blit(out, right, Vector2i(left.get_width() + gap, 0))
	out.save_png(path)


func _blit(dst: Image, src: Image, at: Vector2i) -> void:
	var copy := src.duplicate()
	if copy.get_format() != dst.get_format():
		copy.convert(dst.get_format())
	dst.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), at)
