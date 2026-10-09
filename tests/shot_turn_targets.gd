extends SceneTree

const FoeKits := preload("res://backend/foe_kits.gd")

## Phone frame of the turn-order cards.
## godot --rendering-driver opengl3 -s res://tests/shot_turn_targets.gd -- <out.png> [koliseo|dungeon] --mobile-frame

var _path := "/tmp/turn_targets.png"
var _mode := "koliseo"
var _frames := 0
var _phase := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		if text == "dungeon" or text == "koliseo" or text == "full_dungeon" or text == "full_koliseo" or text == "shrink_koliseo" or text == "shrink_dungeon" or text == "rows_koliseo" or text == "rows_dungeon" or text == "slim_koliseo" or text == "slim_dungeon" or text == "slim_tapped" or text == "marks_koliseo" or text == "marks_dungeon":
			_mode = text
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
		_apply_bar_layout(board)
		if _mode == "marks_dungeon" or _mode == "full_dungeon" or _mode == "shrink_dungeon" or _mode == "rows_dungeon" or _mode == "slim_dungeon":
			if not _boot_full_dungeon(sim):
				return true
			if _mode == "marks_dungeon":
				_stamp_dungeon_marks(sim)
		elif _mode == "marks_koliseo":
			if not _boot_marks_koliseo(sim):
				return true
		elif _mode == "full_koliseo" or _mode == "shrink_koliseo" or _mode == "rows_koliseo" or _mode == "slim_koliseo" or _mode == "slim_tapped":
			if not _boot_full_koliseo(sim):
				return true
		elif _mode == "dungeon":
			if not _boot_dungeon(sim):
				return true
		else:
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
		if board._hud != null:
			board._hud._layout_chrome()
		# A foe card tap selects that enemy: reach tiles on the board, no confirm.
		if _mode == "slim_tapped" or _mode == "marks_dungeon":
			var tapped := _marked_foe_seat(sim) if _mode == "marks_dungeon" else _nth_foe_seat(sim, 1)
			if board._hud != null:
				board._hud.focus_fighter(tapped)
			if tapped >= 0 and board.pawns_by_seat.has(tapped):
				board._arm_enemy_reach(tapped)
		elif not _mode.begins_with("slim") and not _mode.begins_with("marks"):
			var foe_seat := 3 if _mode == "koliseo" else _first_foe_seat(sim)
			if foe_seat >= 0 and board.pawns_by_seat.has(foe_seat):
				board._arm_enemy_reach(foe_seat)
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
	var allies := 0
	var foes := 0
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("team", 0)) == 1:
			foes += 1
		else:
			allies += 1
	var foe_chips := hud._turn_foe_strip.get_child_count() if hud._turn_foe_strip != null else 0
	var panel: Vector2 = hud._resource_panel.size if hud._resource_panel != null else Vector2.ZERO
	print("TURN_TARGETS %s %dx%d err=%s chips=%d foe_chips=%d allies=%d foes=%d chip=%s scroll=%s content=%s panel=%s layout=%s" % [_path, image.get_width(), image.get_height(), err, hud._turn_strip.get_child_count(), foe_chips, allies, foes, chip, hud._turn_scroll.size, hud._turn_strip.custom_minimum_size, panel, hud.turn_bar_layout])
	if _mode.begins_with("marks"):
		var badges: PackedStringArray = PackedStringArray()
		for child in hud._turn_chips():
			var badge := child.get_node_or_null("MarksBadge") as Label
			if badge != null and badge.visible:
				badges.append("%s:%s" % [str(child.get_meta("chip_seat", -1)), badge.text])
		print("MARKS left=%s right=%s badges=%s" % [hud._kestrel_body.text.replace("\n", " | "), hud._ironjaw_body.text.replace("\n", " | "), " ".join(badges)])
	return true


func _boot_marks_koliseo(sim: Node) -> bool:
	var cells := _cluster_n(sim, 2)
	if cells.size() < 2:
		push_error("no pair of ground cells")
		return false
	sim.reset_match({
		"seed": 4,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [cells[0], cells[1]],
		"ironjaw_marks": 3,
	})
	_give_marks(sim, 1, 3, 0)
	return true


func _stamp_dungeon_marks(sim: Node) -> void:
	var foes: Array[int] = []
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("team", 0)) == 1:
			foes.append(int(unit.get("seat", -1)))
	if foes.size() < 2:
		push_error("dungeon pack has no pair of foes to mark")
		return
	var owner := _class_seat(sim, "kestrel")
	_give_marks(sim, foes[0], 2, owner)
	_give_marks(sim, foes[1], 4, owner)


func _give_marks(sim: Node, seat: int, count: int, owner: int) -> void:
	for unit in sim._units:
		if int(unit.get("seat", -1)) != seat:
			continue
		unit["marks"] = count
		unit["marks_seat"] = owner
		return


func _class_seat(sim: Node, class_id: String) -> int:
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if str(unit.get("class_id", "")) == class_id:
			return int(unit.get("seat", -1))
	return 0


func _marked_foe_seat(sim: Node) -> int:
	var best := -1
	var best_n := -1
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("team", 0)) != 1:
			continue
		var n := int(unit.get("marks", 0))
		if n > best_n:
			best_n = n
			best = int(unit.get("seat", -1))
	return best


func _boot_full_dungeon(sim: Node) -> bool:
	StasisCatalog.clear_run()
	if not StasisCatalog.begin("crosshaven"):
		push_error("Threshgate dungeon did not begin")
		return false
	StasisCatalog.set_star(3)
	StasisCatalog.set_party(["ironjaw", "bastion", "kestrel", "mender"])
	var config: Dictionary = StasisCatalog.fight_config()
	if config.is_empty():
		push_error("Threshgate Room A fight config was empty")
		return false
	config = _with_fifth_hero(config, "gloam")
	sim.reset_match(config)
	return _expect_full(sim, "Threshgate")


func _boot_full_koliseo(sim: Node) -> bool:
	var cells := _cluster_n(sim, 10)
	if cells.size() < 10:
		push_error("no cluster of ten ground cells")
		return false
	var heroes: Array = ["ironjaw", "bastion", "kestrel", "mender", "gloam"]
	var classes: Array = heroes.duplicate()
	classes.append("ironjaw")
	var roster: Array = []
	for i in heroes.size():
		roster.append({"seat": i, "facing": "N"})
	var pack: Array = StasisCatalog.pack("crosshaven", 3)
	for i in pack.size():
		var entry: Dictionary = pack[i]
		roster.append({
			"seat": heroes.size() + i,
			"name": str(entry.get("name", "")),
			"max_hp": 40,
			"hp": 40,
			"facing": "S",
			"sprite": StasisCatalog.art_path(str(entry.get("art", ""))),
			"role": str(entry.get("role", "")),
			"foe_kit": FoeKits.ROLE_KITS.get(str(entry.get("role", "")), ["foe.brute_hit"]),
			"attack_base": 8,
			"attack_name": str(entry.get("attack", "")),
			"max_ap": 6,
			"max_mp": 3,
		})
	sim.reset_match({
		"seed": 4,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"party_size": heroes.size(),
		"classes": classes,
		"positions": cells,
		"stasis_roster": roster,
	})
	return _expect_full(sim, "Koliseo")


func _with_fifth_hero(config: Dictionary, class_id: String) -> Dictionary:
	var classes: Array = (config.get("classes", []) as Array).duplicate()
	if classes.size() >= 2:
		classes.insert(classes.size() - 1, class_id)
	config["classes"] = classes
	config["party_size"] = 5
	var roster: Array = []
	for entry in config.get("stasis_roster", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = (entry as Dictionary).duplicate(true)
		if int(rec.get("seat", 0)) >= 4:
			rec["seat"] = int(rec.get("seat", 0)) + 1
		roster.append(rec)
	roster.insert(4, {"seat": 4, "facing": "N"})
	config["stasis_roster"] = roster
	var positions: Array = (config.get("positions", []) as Array).duplicate()
	var foes: Array = positions.slice(4)
	var heroes: Array = StasisCatalog.party_cells("crosshaven", "a", positions[0], 5, foes)
	if heroes.size() >= 5:
		config["positions"] = heroes + foes
	return config


func _expect_full(sim: Node, label: String) -> bool:
	var allies := 0
	var foes := 0
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("team", 0)) == 1:
			foes += 1
		else:
			allies += 1
	if allies < 5 or foes < 5:
		push_error("%s full party was %d allies and %d foes" % [label, allies, foes])
		return false
	return true


func _boot_dungeon(sim: Node) -> bool:
	StasisCatalog.clear_run()
	if not StasisCatalog.begin("slagcrown"):
		push_error("Slagcrown dungeon did not begin")
		return false
	StasisCatalog.set_star(1)
	# Two heroes plus Room A's pack keeps each card at the Koliseo size.
	StasisCatalog.set_party(["ironjaw", "kestrel"])
	var config: Dictionary = StasisCatalog.fight_config()
	if config.is_empty():
		push_error("Slagcrown Room A fight config was empty")
		return false
	sim.reset_match(config)
	return true


func _first_foe_seat(sim: Node) -> int:
	return _nth_foe_seat(sim, 0)


func _nth_foe_seat(sim: Node, index: int) -> int:
	var seen := 0
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("team", 0)) != 1:
			continue
		if seen == index:
			return int(unit.get("seat", -1))
		seen += 1
	return -1


func _apply_bar_layout(board: Node) -> void:
	var hud: CombatHUD = board._hud
	if hud == null:
		return
	if _mode.begins_with("shrink"):
		hud.turn_bar_layout = CombatHUD.TURN_BAR_SHRINK
	elif _mode.begins_with("rows"):
		hud.turn_bar_layout = CombatHUD.TURN_BAR_ROWS
	elif _mode.begins_with("slim"):
		hud.turn_bar_layout = CombatHUD.TURN_BAR_SLIM


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
	var drop := 0.0
	var hud: CombatHUD = board._hud
	if hud != null and hud._resource_panel != null:
		drop = maxf(hud._resource_panel.size.y - 168.0, 0.0) * 0.5 / cam.zoom.x
	cam.position = sum / float(n) + Vector2(20, -10.0 - drop)


func _cluster_n(sim: Node, want: int) -> Array:
	sim.reset_match({"seed": 1, "map_id": "slagcrown", "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	var n := int(sim.snapshot().get("board_size", 15))
	var best: Array = []
	var best_score := 9999
	var wide := maxi(want / 2, 1)
	var tall := 2 if want > wide else 1
	while wide * tall < want:
		wide += 1
	for y in range(1, n - tall):
		for x in range(1, n - wide):
			var cells: Array = []
			var ok := true
			for dy in tall:
				for dx in wide:
					if cells.size() >= want:
						break
					var cell := Vector2i(x + dx, y + dy)
					if not _open(sim, cell):
						ok = false
						break
					cells.append(cell)
				if not ok or cells.size() >= want:
					break
			if not ok or cells.size() < want:
				continue
			var score := absi(x - n + wide) + absi(y - 4)
			if score < best_score:
				best_score = score
				best = cells
	return best


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
