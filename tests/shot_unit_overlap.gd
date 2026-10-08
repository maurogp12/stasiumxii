extends SceneTree

## Phone frame of two adjacent Koliseo fighters.
## godot --path . --rendering-driver opengl3 -s res://tests/shot_unit_overlap.gd -- <dir> --mobile-frame

var _dir := "/tmp/unit_overlap"
var _frames := 0
var _maps: Array[String] = ["windmere", "slagcrown", "crosshaven"]
var _map_i := 0
var _phase := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	if _map_i >= _maps.size():
		print("UNIT_OVERLAP_DONE %s" % _dir)
		return true
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		var pair := _stand_pair(sim, _maps[_map_i])
		if pair.is_empty():
			push_error("no adjacent stand on %s" % _maps[_map_i])
			return true
		sim.reset_match({
			"seed": 1,
			"map_id": _maps[_map_i],
			"skip_deploy": true,
			"classes": ["kestrel", "gloam"],
			"positions": [pair[0], pair[1]],
		})
		board._rebuild_pawns()
		board._refresh()
		_phase = 1
		_frames = 0
		return false
	if _frames < 8:
		return false
	_aim(board)
	if _frames == 8:
		for seat in board.pawns_by_seat.keys():
			var pawn: Pawn = board.pawns_by_seat[seat]
			var rim := pawn.get_node_or_null("OccludeRim")
			var rim_on := false
			if rim != null:
				rim_on = rim.visible
			print("UNIT %s seat=%d cell=%s z=%d nudge=%s occluded=%s rim=%s" % [pawn.unit_name, seat, pawn.grid_position, pawn.z_index, pawn.name_nudge, pawn.is_occluded(), rim_on])
	if _frames < 12:
		return false
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, _maps[_map_i]]
	image.save_png(path)
	print("UNIT_OVERLAP %s %dx%d" % [path, image.get_width(), image.get_height()])
	_map_i += 1
	_phase = 0
	_frames = 0
	return false


func _aim(board: Node) -> void:
	var cam: Camera2D = board._camera
	if cam == null:
		return
	var a: Node2D = board.pawns_by_seat[0]
	var b: Node2D = board.pawns_by_seat[1]
	cam.zoom = Vector2(2.35, 2.35)
	cam.position = (a.position + b.position) * 0.5 + Vector2(0, -36)


func _stand_pair(sim: Node, map_id: String) -> Array:
	sim.reset_match({"seed": 1, "map_id": map_id, "skip_deploy": true, "classes": ["kestrel", "gloam"]})
	var n := int(sim.snapshot().get("board_size", 15))
	var best: Array = []
	var best_score := 9999
	for y in n:
		for x in range(n - 1):
			var a := Vector2i(x, y)
			var b := Vector2i(x + 1, y)
			if not _open(sim, a) or not _open(sim, b):
				continue
			var score := absi(x - n / 2) + absi(y - n / 2)
			if score < best_score:
				best_score = score
				best = [a, b]
	return best


func _open(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"
