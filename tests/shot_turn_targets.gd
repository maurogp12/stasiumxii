extends SceneTree

## Phone frame of a crowded turn-order bar.
## godot --path . --rendering-driver opengl3 -s res://tests/shot_turn_targets.gd -- <out.png> --mobile-frame

var _path := "/tmp/turn_targets.png"
var _frames := 0
var _phase := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_path = text
	var folder := _path.get_base_dir()
	if folder != "":
		DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("turn target shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		var cells := _cluster(sim)
		if cells.size() < 6:
			push_error("no cluster of six ground cells")
			return true
		sim.reset_match({
			"seed": 4,
			"map_id": "slagcrown",
			"skip_deploy": true,
			"team_size": 3,
			"classes": ["ironjaw", "bastion", "kestrel", "gloam", "mender", "kestrel"],
			"positions": cells,
		})
		board._rebuild_pawns()
		board._refresh()
		_phase = 1
		_frames = 0
		return false
	if _frames < 12:
		return false
	_aim(board)
	if _frames < 16:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_path)
	var hud: CombatHUD = board._hud
	var chip: Vector2 = hud._turn_strip.get_child(0).size if hud._turn_strip.get_child_count() > 0 else Vector2.ZERO
	print("TURN_TARGETS %s %dx%d err=%s chips=%d chip=%s strip=%s" % [_path, image.get_width(), image.get_height(), err, hud._turn_strip.get_child_count(), chip, hud._turn_strip.size])
	return true


func _aim(board: Node) -> void:
	var cam: Camera2D = board._camera
	if cam == null:
		return
	var sum := Vector2.ZERO
	var n := 0
	for seat in board.pawns_by_seat.keys():
		var pawn: Node2D = board.pawns_by_seat[seat]
		sum += pawn.position
		n += 1
	if n == 0:
		return
	cam.zoom = Vector2(1.7, 1.7)
	cam.position = sum / float(n) + Vector2(20, -10)


func _cluster(sim: Node) -> Array:
	sim.reset_match({"seed": 1, "map_id": "slagcrown", "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	var n := int(sim.snapshot().get("board_size", 15))
	var best: Array = []
	var best_score := 9999
	for y in range(1, n - 2):
		for x in range(1, n - 3):
			var cells: Array = []
			var ok := true
			for dy in 2:
				for dx in 3:
					var cell := Vector2i(x + dx, y + dy)
					if not _open(sim, cell):
						ok = false
						break
					cells.append(cell)
				if not ok:
					break
			if not ok:
				continue
			var score := absi(x - n + 4) + absi(y - 4)
			if score < best_score:
				best_score = score
				best = cells
	return best


func _open(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"
