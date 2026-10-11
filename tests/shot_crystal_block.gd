extends SceneTree

## Windmere crystals at chest height, then Kestrel's Mark Shot across one.
## xvfb-run -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 -s res://tests/shot_crystal_block.gd -- /opt/cursor/artifacts/crystals

var _out := "/tmp/crystals"
var _phase := "boot"
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("--"):
			_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	var roster: Array[String] = ["kestrel", "ironjaw"]
	select.set("hotseat_classes", roster)
	select.set("hotseat_map_id", "windmere")
	change_scene_to_file("res://main.tscn")
	_phase = "arena"


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null or not bool(board.get("_booted")):
		return false
	if _phase == "arena":
		if _frames < 8:
			return false
		_place(board, Vector2i(2, 7), Vector2i(12, 7))
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera()
		_phase = "arena_hold"
		_frames = 0
		return false
	if _phase == "arena_hold":
		if _frames < 30:
			return false
		_save("windmere_crystals.png")
		_place(board, Vector2i(0, 6), Vector2i(5, 1))
		board._hud._selected_spell = "mark_shot"
		board._hud._refresh_spell_buttons()
		board._aim_hover = Vector2i(5, 1)
		board._paint_highlights()
		board._sync_aim_preview(Vector2i(5, 1))
		_frame_crystal(board)
		_phase = "aim_hold"
		_frames = 0
		return false
	if _phase == "aim_hold":
		if _frames < 20:
			return false
		var tile = board.tiles.get(Vector2i(5, 1))
		print("TARGET_HIGHLIGHT ", tile.highlight if tile != null else "missing")
		print("AIM_LABEL ", board._hud._aim_hit_label.text if board._hud._aim_hit_label != null else "")
		var line := board.get_node_or_null("AimLine")
		print("AIM_FLOAT ", line._label.text if line != null and line._label != null else "")
		_save("windmere_crystal_blocked.png")
		return true
	return false


func _place(board: Node, kestrel: Vector2i, ironjaw: Vector2i) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": "windmere",
		"classes": ["kestrel", "ironjaw"],
		"positions": [kestrel, ironjaw],
	})
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()


func _frame_crystal(board: Node) -> void:
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera()
	var cam: Camera2D = board.get("_camera")
	if cam == null:
		return
	# Close enough that the crystal and both fighters fill the frame.
	# The fit pan room is zero, so widen it before centering on the crystal.
	cam.zoom = Vector2(1.45, 1.45)
	board._pan_limit = Vector2(900.0, 900.0)
	if board.has_method("_center_on_cell"):
		board._center_on_cell(Vector2i(3, 3))
	print("CAM zoom ", cam.zoom, " pos ", cam.position)
	var host := board.get_node_or_null("PaintedRoom")
	if host != null:
		for child in host.get_children():
			if str(child.get_meta("what", "")) != "crystal":
				continue
			print("CRYSTAL ", child.get_meta("cell"), " pos ", child.position, " scale ", child.scale, " z ", child.z_index)
	for seat in board.pawns_by_seat.keys():
		var pawn: Node2D = board.pawns_by_seat[seat]
		print("PAWN ", seat, " pos ", pawn.position, " z ", pawn.z_index)


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(file_name))
	print("saved ", file_name, " ", image.get_width(), "x", image.get_height())
