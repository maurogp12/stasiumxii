extends SceneTree

## 15s cast on the v1.1 Crosshaven board. 150 frames at 10 fps.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l9_clip.gd -- --out=/tmp/l9_clip

const BOARD := preload("res://board/pc/crosshaven_board.gd")
const HUD := preload("res://ui/hud.gd")

var _out := "/tmp/l9_clip"
var _size := Vector2i(1280, 720)
var _target := Vector2i(9, 7)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	Engine.time_scale = 0.22
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _size
	root.size = _size
	DisplayServer.window_set_size(_size)
	await process_frame
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match({
		"seed": 1,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"kestrel_pos": Vector2i(7, 7),
		"ironjaw_pos": _target,
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	var cam := board.get_node("BoardCamera") as Camera2D
	cam.zoom = Vector2(0.72, 0.72)
	for _i in 6:
		await process_frame
	var frame := 0
	for _i in 30:
		frame = _save(frame)
		await process_frame
	var hit: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": _target})
	if not bool(hit.get("ok", false)):
		push_error("mark_shot failed %s" % str(hit))
		quit(1)
		return
	var events: Array = hit.get("events", [])
	events.append({"type": "cast", "spell": "mark_shot", "to": _target, "seat": 0})
	board._apply_units(sim.snapshot())
	board._arm_view_motions(hit.get("events", []))
	board._arm_vfx(events)
	var saw := false
	for _i in 120:
		await process_frame
		if _damage_alpha(board) > 0.85:
			saw = true
		frame = _save(frame)
	print("L9_CLIP frames=%d saw=%s dir=%s" % [frame, str(saw), _out])
	main.free()
	quit(0 if saw and frame == 150 else 1)


func _damage_alpha(board: Node) -> float:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return 0.0
	var best := 0.0
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		var shown := str(child.get("_text"))
		if not shown.is_valid_int():
			continue
		best = maxf(best, float(child.modulate.a))
	return best


func _save(frame: int) -> int:
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(_out.path_join("frame_%04d.png" % frame))
	return frame + 1
