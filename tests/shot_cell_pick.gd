extends SceneTree

const TOUCH := preload("res://ui/touch_adapter.gd")

## Clustered Slagcrown fight. The empty cell between the fighters is the
## selected walk, then the same kind of cell is the selected wall.
## godot --rendering-driver opengl3 -s res://tests/shot_cell_pick.gd -- <dir>

var _dir := "/tmp/cell_pick"
var _frames := 0
var _phase := 0
var _step := 0


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
	if _frames > 240:
		push_error("cell pick shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		if not _boot(sim, board, _step):
			return true
		_phase = 1
		_frames = 0
		return false
	if _frames < 10:
		return false
	_aim(board)
	if _frames < 14:
		return false
	var image := root.get_texture().get_image()
	var name := "part3_walk.png" if _step == 0 else "part3_target.png"
	var path := _dir.path_join(name)
	var err := image.save_png(path)
	var picked: Vector2i = board.selected_tile.grid_position if board.selected_tile != null else Vector2i(-1, -1)
	var ring: Node = board.get_node_or_null("PickRing")
	print("CELL_PICK %s %dx%d err=%s cell=%s spell=%s ring=%s" % [path, image.get_width(), image.get_height(), err, picked, board._hud.selected_spell(), ring != null and ring.visible])
	_step += 1
	if _step > 1:
		return true
	_phase = 0
	_frames = 0
	return false


func _boot(sim: Node, board: Node, step: int) -> bool:
	var probe := {
		"seed": 1,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"team_size": 2,
		"classes": ["ironjaw", "bastion", "kestrel", "gloam"],
	}
	sim.reset_match(probe)
	var spot: Dictionary = _cluster(sim)
	if spot.is_empty():
		push_error("no clustered stand on slagcrown")
		return false
	var config := probe.duplicate()
	config["positions"] = spot["stands"]
	if step == 1:
		config["classes"] = ["bastion", "ironjaw", "kestrel", "gloam"]
		config["bastion_aegis"] = 4
	sim.reset_match(config)
	if sim.snapshot().get("units", []).size() < 4:
		push_error("cluster shot spawned fewer than 4 fighters")
		return false
	board._rebuild_pawns()
	board._refresh()
	var dest: Vector2i = spot["gap"]
	if step == 1:
		dest = _place_cell(sim, spot["gap"])
		board._hud._selected_spell = SpellKits.SNAP_WALL
		board._hud._refresh_spell_buttons()
		board._refresh()
	if not board.tiles.has(dest):
		push_error("picked cell is not on the board")
		return false
	var local: Vector2 = (board.tiles[dest] as Node2D).position
	var spell := "" if step == 0 else SpellKits.SNAP_WALL
	var prefer := TOUCH.spell_targets_unit(spell)
	var got := TOUCH.pick_board_cell(local, board._tile_positions(), board._living_pawns_for_pick(spell), prefer, true)
	if got != dest:
		push_error("finger pick %s did not stay on %s" % [got, dest])
		return false
	board.select_tile(dest)
	return true


func _place_cell(sim: Node, fallback: Vector2i) -> Vector2i:
	var legal: Array = sim.legal_intents(0)
	for intent in legal:
		if str(intent.get("type", "")) != "cast":
			continue
		if str(intent.get("spell", "")) != SpellKits.SNAP_WALL:
			continue
		var cell: Vector2i = intent.get("to", Vector2i(-1, -1))
		if cell == fallback:
			return cell
	for intent in legal:
		if str(intent.get("type", "")) != "cast":
			continue
		if str(intent.get("spell", "")) != SpellKits.SNAP_WALL:
			continue
		var cell: Vector2i = intent.get("to", Vector2i(-1, -1))
		if cell.x >= 0:
			return cell
	return fallback


func _cluster(sim: Node) -> Dictionary:
	var n := int(sim.snapshot().get("board_size", 15))
	var best: Dictionary = {}
	var best_score := 9999
	for y in range(1, n - 2):
		for x in range(1, n - 2):
			var stands := [Vector2i(x, y), Vector2i(x + 2, y), Vector2i(x, y + 2), Vector2i(x + 2, y + 2)]
			var gap := Vector2i(x + 1, y + 1)
			var open := _open(sim, gap)
			if not open:
				continue
			for cell in stands + [Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if not _open(sim, cell):
					open = false
					break
			if not open:
				continue
			var score := absi(x - n / 2) + absi(y - n / 2)
			if score < best_score:
				best_score = score
				best = {"stands": stands, "gap": gap}
	return best


func _open(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"


func _aim(board: Node) -> void:
	var cam: Camera2D = board._camera
	if cam == null:
		return
	var sum := Vector2.ZERO
	var n := 0
	for pawn in board.pawns_by_seat.values():
		sum += (pawn as Node2D).position
		n += 1
	if n == 0:
		return
	cam.zoom = Vector2(2.4, 2.4)
	cam.position = sum / float(n) + Vector2(0, -24)
