extends SceneTree

## 12s clip. A Mark Shot outdoors, then the same shot in the dungeon.
## Shafts and the floor pool sit on the target with the damage number.
## "+1 Mark" stays on the caster, two cells away.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l7_clip.gd -- --out=/tmp/l7_clip

const HUD := preload("res://ui/hud.gd")
const LIGHT := preload("res://board/pc/look_light.gd")

var _out := "/tmp/l7_clip"
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
	await process_frame
	var frame := 0
	var outdoor := await _boot("crosshaven", "")
	if outdoor.is_empty():
		quit(1)
		return
	frame = await _hold(frame, 18)
	frame = await _shot(outdoor, frame, 48)
	if frame < 0:
		quit(1)
		return
	outdoor["main"].free()
	await process_frame
	var dungeon := await _boot("stormspire", "thunderwell")
	if dungeon.is_empty():
		quit(1)
		return
	frame = await _hold(frame, 14)
	frame = await _shot(dungeon, frame, 40)
	if frame < 0:
		quit(1)
		return
	dungeon["main"].free()
	print("L7_CLIP frames=%d dir=%s" % [frame, _out])
	quit(0)


func _boot(map_id: String, theme: String) -> Dictionary:
	HUD.set_pc_chrome_override(1)
	LIGHT.set_suppressed(false)
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
	if theme != "":
		board.set_board_theme(theme)
	var cam := board.get_node("BoardCamera") as Camera2D
	cam.zoom = Vector2(0.72, 0.72)
	for _i in 6:
		await process_frame
	return {"main": main, "board": board, "sim": sim}


func _hold(frame: int, count: int) -> int:
	for _i in count:
		await process_frame
		frame = _save(frame)
	return frame


func _shot(scene: Dictionary, frame: int, count: int) -> int:
	var board: Node = scene["board"]
	var sim: Node = scene["sim"]
	var hit: Dictionary = sim.submit({"type": "cast", "spell": "mark_shot", "to": _target})
	if not bool(hit.get("ok", false)):
		push_error("mark_shot failed %s" % str(hit))
		return -1
	var events: Array = hit.get("events", [])
	events.append({
		"type": "cast",
		"spell": "mark_shot",
		"to": _target,
		"seat": 0,
	})
	board._apply_units(sim.snapshot())
	board._arm_view_motions(hit.get("events", []))
	board._arm_vfx(events)
	var saw := false
	for i in count:
		if i == 16:
			board._arm_vfx([{
				"type": "cast",
				"spell": "mark_shot",
				"to": _target,
				"seat": 0,
			}])
		await process_frame
		if _damage_alpha(board) > 0.85:
			saw = true
		frame = _save(frame)
	print("L7_CLIP shot texts=%s" % _texts(board))
	if not saw:
		push_error("damage number did not show")
		return -1
	return frame


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


func _texts(board: Node) -> String:
	var director := board.get_node_or_null("VfxDirector")
	if director == null:
		return ""
	var parts: PackedStringArray = []
	for child in director.get_children():
		if child == null or not str(child.name).begins_with("number"):
			continue
		var shown := str(child.get("_text"))
		if shown != "":
			parts.append(shown)
	return " ".join(parts)


func _save(frame: int) -> int:
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(_out.path_join("frame_%04d.png" % frame))
	return frame + 1
