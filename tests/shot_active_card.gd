extends SceneTree

## Phone frame: left card follows the active fighter, and Gloam's card fits.
## godot --rendering-driver opengl3 -s res://tests/shot_active_card.gd -- <dir>

var _dir := "/opt/cursor/artifacts/fix"
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
		push_error("active-card shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		if not _boot_ironjaw_turn(sim):
			return true
		board._rebuild_pawns()
		board._refresh()
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 12:
			return false
		var hud: CombatHUD = board._hud
		hud._fit_corner_cards()
		var image := root.get_texture().get_image()
		var path := _dir.path_join("active_card.png")
		var err := image.save_png(path)
		var left := hud._kestrel_body.get_parsed_text().replace("\n", " | ")
		print("ACTIVE %s %dx%d err=%s title=%s" % [path, image.get_width(), image.get_height(), err, hud._banner_titles[0].text])
		print("ACTIVE left=%s" % left)
		print("ACTIVE left_fit content=%s box=%s card=%s" % [hud._kestrel_body.get_content_height(), hud._kestrel_body.size, hud._banner_panels[0].size])
		if hud._banner_titles[0].text != "Ironjaw":
			push_error("left card is %s, expected Ironjaw" % hud._banner_titles[0].text)
		if not left.contains("Impact"):
			push_error("Ironjaw card is missing Impact")
		if left.contains("Pulse"):
			push_error("left card still shows Mender")
		_stamp_gloam(sim)
		board._refresh()
		_phase = 2
		_frames = 0
		return false
	if _frames < 12:
		return false
	var hud: CombatHUD = board._hud
	hud._fit_corner_cards()
	var image := root.get_texture().get_image()
	var path := _dir.path_join("gloam_card.png")
	var err := image.save_png(path)
	var right := hud._ironjaw_body
	var parsed := right.get_parsed_text().replace("\n", " | ")
	var live := right.get_content_height()
	print("GLOAM %s %dx%d err=%s title=%s" % [path, image.get_width(), image.get_height(), err, hud._banner_titles[1].text])
	print("GLOAM right=%s" % parsed)
	print("GLOAM right_fit content=%s box=%s lines=%d card=%s" % [live, right.size, right.get_line_count(), hud._banner_panels[1].size])
	if hud._banner_titles[1].text != "Gloam":
		push_error("right card is %s, expected Gloam" % hud._banner_titles[1].text)
	if not parsed.contains("Umbral 2/4") or not parsed.contains("Shades"):
		push_error("Gloam card is missing Umbral 2/4 or Shades")
	if not parsed.contains("Marks") or not parsed.contains("residue"):
		push_error("Gloam card is missing Marks or the element line")
	if live > right.size.y + 1.0:
		push_error("Gloam text overflows the body (%s > %s)" % [live, right.size.y])
	var card_bottom := hud._banner_panels[1].get_global_rect().end.y
	var view_h := root.get_visible_rect().size.y
	if card_bottom > view_h + 1.0:
		push_error("Gloam card runs off the screen (%s > %s)" % [card_bottom, view_h])
	return true


func _boot_ironjaw_turn(sim: Node) -> bool:
	var cells := _cluster(sim)
	if cells.size() < 6:
		push_error("no cluster of six ground cells")
		return false
	sim.reset_match({
		"seed": 4,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"team_size": 3,
		"classes": ["ironjaw", "gloam", "mender", "kestrel", "bastion", "bastion"],
		"positions": cells,
	})
	var iron := _class_seat(sim, "ironjaw", 0)
	var mender := _class_seat(sim, "mender", 0)
	if iron < 0 or mender < 0:
		push_error("missing Ironjaw or Mender")
		return false
	var guard := 0
	while int(sim.snapshot().get("active_seat", -1)) != iron and guard < 8:
		sim.submit({"type": "end_turn"})
		guard += 1
	if int(sim.snapshot().get("active_seat", -1)) != iron:
		push_error("could not reach Ironjaw's turn")
		return false
	var hud: CombatHUD = current_scene.get_node("BoardView")._hud
	hud.render(sim.snapshot(), [])
	hud.focus_fighter(mender)
	if hud._banner_titles[0].text != "Mender":
		push_error("ally tap did not peek Mender")
		return false
	var left_turn := false
	guard = 0
	while guard < 8:
		sim.submit({"type": "end_turn"})
		guard += 1
		var active := int(sim.snapshot().get("active_seat", -1))
		if active != iron:
			left_turn = true
		elif left_turn:
			break
	if int(sim.snapshot().get("active_seat", -1)) != iron:
		push_error("Ironjaw did not get the turn back")
		return false
	print("ACTIVE setup peek=Mender then turn returned to Ironjaw")
	return true


func _stamp_gloam(sim: Node) -> void:
	for unit in sim._units:
		if str(unit.get("class_id", "")) != "gloam" or int(unit.get("team", 0)) != 1:
			continue
		unit["umbral"] = 2
		unit["shades"] = 2
		unit["invisible"] = true
		unit["invisible_turns"] = 2
		unit["marks"] = 5
		unit["stunned"] = true
		unit["stun_remaining"] = 1
		unit["burn_stacks"] = 2
		unit["burn_remaining"] = 3
		unit["slow_stacks"] = 1
		unit["slow_remaining"] = 2
		unit["breathless_stacks"] = 1
		unit["breathless_remaining"] = 2
		unit["frozen_stacks"] = 1
		unit["frozen_remaining"] = 1
		unit["electro_stacks"] = 1
		unit["electro_remaining"] = 1
		unit["residue"] = "air"
		unit["residue_turns"] = 2
		unit["grounded"] = true
		unit["water_slow"] = true
		unit["pinned"] = true
		unit["sparked"] = true
		return


func _class_seat(sim: Node, class_id: String, team: int) -> int:
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if str(unit.get("class_id", "")) == class_id and int(unit.get("team", 0)) == team:
			return int(unit.get("seat", -1))
	return -1


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
