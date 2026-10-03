extends SceneTree

## Saves a Crosshaven before/after frame run for the jungle backdrop.
## godot --path . -s res://tests/pc/capture_jungle_look.gd -- --out=/tmp/l2_frames

var _out := "/tmp/l2_frames"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			_out = str(arg).trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
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
	layer.set_enabled(false)
	await _settle(4)
	await _shot(_out.path_join("before.png"))
	layer.set_enabled(true)
	# One full sway cycle so the clip loops.
	var frames := 16
	var period := TAU / 0.9
	for i in frames:
		layer.preview_time(period * float(i) / float(frames))
		await _settle(1)
		await _shot(_out.path_join("after_%02d.png" % i))
	await _leaf_sides(board, layer)
	print("JUNGLE_CAPTURE %s" % _out)
	quit(0)


func _leaf_sides(board: Node, layer: Node) -> void:
	var cam := board.get_node("BoardCamera") as Camera2D
	var fit: Vector2 = board.get("_fit_camera_pos")
	cam.zoom = Vector2(0.64, 0.64)
	# Full pan that pushes that edge cell toward the leaf on that side of the screen.
	var shots := {
		"leaf_left": [Vector2(220, 0), Vector2i(0, 14)],
		"leaf_right": [Vector2(-220, 0), Vector2i(14, 0)],
		"leaf_top": [Vector2(0, 220), Vector2i(0, 0)],
		"leaf_bottom": [Vector2(0, -220), Vector2i(14, 14)],
	}
	var pawns: Dictionary = board.get("pawns_by_seat")
	var seats: Array = pawns.keys()
	seats.sort()
	for name in shots.keys():
		var spec: Array = shots[name]
		var pan: Vector2 = spec[0]
		var cell: Vector2i = spec[1]
		var tiles: Dictionary = board.get("tiles")
		var tile: Node2D = tiles.get(cell)
		if tile == null or seats.is_empty():
			push_error("missing edge cell or fighter for %s" % name)
			continue
		var fighter: Node2D = pawns[seats[0]]
		if seats.size() > 1:
			var other: Node2D = pawns[seats[1]]
			var mid: Node2D = tiles.get(Vector2i(7, 7))
			if mid != null:
				other.global_position = mid.global_position
		await _settle(1)
		fighter.global_position = tile.global_position
		cam.position = fit + pan
		layer.call("set_hover_cell", cell)
		layer.call("layout")
		await _settle(2)
		_grab(_out.path_join("%s.png" % name))
	cam.position = fit
	layer.call("layout")


func _settle(frames: int) -> void:
	for _i in frames:
		await process_frame


func _shot(path: String) -> void:
	await process_frame
	_grab(path)


func _grab(path: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	if image == null or image.get_width() < 2:
		push_error("empty frame %s" % path)
		return
	image.save_png(path)
