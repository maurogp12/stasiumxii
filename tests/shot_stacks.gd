extends SceneTree

## Phone frame: stack text on the corner cards, no portrait discs.
## godot --rendering-driver opengl3 -s res://tests/shot_stacks.gd -- <dir>

var _dir := "/opt/cursor/artifacts/stacks"
var _frames := 0
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
	if _frames > 240:
		push_error("stack shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		if not _boot(sim):
			return true
		board._rebuild_pawns()
		board._refresh()
		var hud: CombatHUD = board._hud
		if hud != null:
			hud.focus_fighter(_class_seat(sim, "ironjaw", 0))
			hud.focus_fighter(_class_seat(sim, "gloam", 1))
			hud._layout_chrome()
		_aim(board)
		_phase = 1
		_frames = 0
		return false
	if _frames < 16:
		return false
	var image := root.get_texture().get_image()
	var full_path := _dir.path_join("full.png")
	var full_err := image.save_png(full_path)
	var hud: CombatHUD = board._hud
	var close_path := _dir.path_join("card_closeup.png")
	var close_err := _save_closeup(image, hud, close_path)
	var discs := _visible_discs(hud)
	var left := hud._kestrel_body
	var right := hud._ironjaw_body
	print("STACKS full=%s %dx%d err=%s close=%s err=%s discs=%d" % [full_path, image.get_width(), image.get_height(), full_err, close_path, close_err, discs])
	print("STACKS left=%s" % left.text.replace("\n", " | "))
	print("STACKS right=%s" % right.text.replace("\n", " | "))
	print("STACKS left_fit content=%s box=%s lines=%d" % [left.get_content_height(), left.size, left.get_line_count()])
	print("STACKS right_fit content=%s box=%s lines=%d" % [right.get_content_height(), right.size, right.get_line_count()])
	print("STACKS parsed_left=%s" % left.get_parsed_text().replace("\n", " | "))
	if discs > 0:
		push_error("portrait discs are still visible")
	if left.get_content_height() > left.size.y + 1.0 or right.get_content_height() > right.size.y + 1.0:
		push_error("corner card text overflows the body")
	if not left.get_parsed_text().contains("Impact 2/5") or not left.get_parsed_text().contains("Marks 3/5"):
		push_error("Ironjaw card is missing Impact 2/5 or Marks 3/5")
	if not left.get_parsed_text().contains("AIR residue 1"):
		push_error("Ironjaw card dropped the residue line")
	return true


func _boot(sim: Node) -> bool:
	var cells := _cluster(sim)
	if cells.size() < 6:
		push_error("no cluster of six ground cells")
		return false
	sim.reset_match({
		"seed": 4,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"team_size": 3,
		"classes": ["ironjaw", "bastion", "mender", "gloam", "kestrel", "bastion"],
		"positions": cells,
	})
	var kestrel := _class_seat(sim, "kestrel", 1)
	_set_field(sim, "ironjaw", 0, "impact", 2)
	_set_field(sim, "ironjaw", 0, "marks", 3)
	_set_field(sim, "ironjaw", 0, "marks_seat", kestrel)
	_set_field(sim, "ironjaw", 0, "residue", "air")
	_set_field(sim, "ironjaw", 0, "residue_turns", 1)
	_set_field(sim, "bastion", 0, "aegis", 1)
	_set_field(sim, "mender", 0, "pulse", 3)
	_set_field(sim, "gloam", 1, "umbral", 1)
	return true


func _set_field(sim: Node, class_id: String, team: int, field: String, value: Variant) -> void:
	for unit in sim._units:
		if str(unit.get("class_id", "")) != class_id or int(unit.get("team", 0)) != team:
			continue
		unit[field] = value
		var bag: Variant = unit.get("resources", null)
		if typeof(bag) == TYPE_DICTIONARY and (bag as Dictionary).has(field):
			(bag as Dictionary)[field] = value
		return


func _class_seat(sim: Node, class_id: String, team: int) -> int:
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if str(unit.get("class_id", "")) == class_id and int(unit.get("team", 0)) == team:
			return int(unit.get("seat", -1))
	return -1


func _visible_discs(hud: CombatHUD) -> int:
	var n := 0
	if hud == null:
		return n
	for child in hud._turn_chips():
		for node_name in ["StackBadge", "MarksBadge"]:
			var badge := child.get_node_or_null(node_name) as CanvasItem
			if badge != null and badge.visible:
				n += 1
	return n


func _save_closeup(image: Image, hud: CombatHUD, path: String) -> int:
	if hud == null or hud._banner_panels.is_empty():
		push_error("no corner card to crop")
		return ERR_DOES_NOT_EXIST
	var panel := hud._banner_panels[0]
	var vp := root.get_visible_rect().size
	var scale := Vector2(float(image.get_width()) / vp.x, float(image.get_height()) / vp.y)
	var rect := panel.get_global_rect().grow(10.0)
	var origin := Vector2i(rect.position * scale)
	var size := Vector2i(rect.size * scale)
	var crop_rect := Rect2i(origin, size).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if crop_rect.size.x < 8 or crop_rect.size.y < 8:
		push_error("corner card crop was empty")
		return ERR_INVALID_DATA
	var crop := image.get_region(crop_rect)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	return crop.save_png(path)


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
