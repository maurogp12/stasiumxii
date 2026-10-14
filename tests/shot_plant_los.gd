extends SceneTree

## Phone frame on brinewake. Kestrel aims Mark Shot through a lone Plant
## banner, then the same lane with that banner beside a Snap Wall.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_plant_los.gd -- /opt/cursor/artifacts/plant_los --mobile-frame

var _dir := "/opt/cursor/artifacts/plant_los"
var _phase := "boot"
var _frames := 0
var _kestrel := Vector2i.ZERO
var _bastion := Vector2i.ZERO
var _banner := Vector2i.ZERO
var _wall := Vector2i.ZERO


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	if not OS.get_cmdline_user_args().has("--mobile-frame"):
		push_error("pass --mobile-frame so the board is the phone layout")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	select.set("hotseat_map_id", "brinewake")
	select.set("hotseat_classes", ["kestrel", "bastion"])
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 400:
		push_error("plant los shot timed out in %s" % _phase)
		return true
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null or not bool(board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 8:
			return false
		if not _place(board, false):
			return true
		_aim(board)
		_phase = "through"
		_frames = 0
		return false
	if _phase == "through":
		if _frames < 20:
			return false
		if not _check(board, "target", "through a lone banner"):
			return true
		if not _save("through_banner.png"):
			return true
		if not _place(board, true):
			return true
		_aim(board)
		_phase = "blocked"
		_frames = 0
		return false
	if _phase == "blocked":
		if _frames < 20:
			return false
		if not _check(board, "target", "open beside a Snap Wall"):
			return true
		_save("beside_snap_open.png")
		return true
	return false


func _place(board: Node, with_wall: bool) -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	if _kestrel == Vector2i.ZERO and not _find_lane(sim):
		return false
	sim.reset_match({
		"seed": 1,
		"map_id": "brinewake",
		"skip_deploy": true,
		"classes": ["kestrel", "bastion"],
		"positions": [_kestrel, _bastion],
		"rolls": [1],
	})
	var bastion_seat := _class_seat(sim, "bastion")
	sim._plant_tiles.append({
		"pos": _banner,
		"turns": 1,
		"owner_seat": bastion_seat,
		"push_resist": true,
		"walled": false,
	})
	if with_wall:
		sim._add_snap_wall(_wall, 2, bastion_seat)
	board._rebuild_grid(int(sim.snapshot().get("board_size", 15)))
	board._rebuild_pawns()
	board._refresh()
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera(false)
	_frame(board)
	var sees: bool = sim.has_line_of_sight(_kestrel, _bastion)
	var blocker: Vector2i = sim.sight_blocker(_kestrel, _bastion)
	print("LANE wall=%s sees=%s blocker=%s banner=%s snap=%s" % [with_wall, sees, blocker, _banner, _wall])
	if with_wall:
		if not sees or blocker != Vector2i(-1, -1):
			push_error("a banner beside a Snap Wall should stay open, sees=%s blocker=%s" % [sees, blocker])
			return false
	elif not sees:
		push_error("a lone banner should not block")
		return false
	return true


func _aim(board: Node) -> void:
	var hud: CombatHUD = board._hud
	hud.focus_fighter(0)
	hud._selected_spell = "mark_shot"
	hud._refresh_spell_buttons()
	board._aim_hover = _bastion
	board._paint_highlights()
	if board.has_method("_sync_aim_preview"):
		board._sync_aim_preview(_bastion)


func _check(board: Node, want: String, label: String) -> bool:
	var tile = board.tiles.get(_bastion)
	var highlight := "" if tile == null else str(tile.highlight)
	print("BASTION HIGHLIGHT %s %s" % [label, highlight])
	if highlight != want:
		push_error("%s: Bastion's tile is %s, wanted %s" % [label, highlight, want])
		return false
	if not _banner_drawn(board):
		return false
	return true


func _banner_drawn(board: Node) -> bool:
	var vfx: Node = board.get("_vfx")
	if vfx == null:
		push_error("board has no vfx director")
		return false
	var linger: Dictionary = vfx.get("_linger")
	var key := "plant_banner:%d,%d" % [_banner.x, _banner.y]
	if not linger.has(key):
		push_error("banner was not drawn at %s" % key)
		return false
	var node: Node = linger[key]
	if node is CanvasItem:
		var item := node as CanvasItem
		print("BANNER scale=%.3f alpha=%.3f" % [item.scale.x, item.modulate.a])
	return true


func _frame(board: Node) -> void:
	var cam: Camera2D = board.get("_camera")
	if cam == null:
		return
	cam.zoom = Vector2(1.35, 1.35)
	board._pan_limit = Vector2(900.0, 900.0)
	if board.has_method("_center_on_cell"):
		board._center_on_cell(_banner)


func _find_lane(sim: Node) -> bool:
	sim.reset_match({
		"seed": 1,
		"map_id": "brinewake",
		"skip_deploy": true,
		"classes": ["kestrel", "bastion"],
	})
	var n := int(sim.snapshot().get("board_size", 15))
	for y in range(1, n - 1):
		for x in range(1, n - 5):
			var kestrel := Vector2i(x, y)
			var banner := Vector2i(x + 2, y)
			var bastion := Vector2i(x + 4, y)
			if not _ground(sim, kestrel) or not _ground(sim, banner) or not _ground(sim, bastion):
				continue
			if not _ground(sim, Vector2i(x + 1, y)) or not _ground(sim, Vector2i(x + 3, y)):
				continue
			var wall := Vector2i(banner.x, banner.y + 1)
			if not _ground(sim, wall):
				wall = Vector2i(banner.x, banner.y - 1)
			if not _ground(sim, wall):
				continue
			_kestrel = kestrel
			_banner = banner
			_bastion = bastion
			_wall = wall
			print("LANE kestrel=%s banner=%s bastion=%s wall=%s" % [_kestrel, _banner, _bastion, _wall])
			return true
	push_error("no brinewake dock lane for the banner")
	return false


func _ground(sim: Node, cell: Vector2i) -> bool:
	var tile: Dictionary = sim.tile_at(cell)
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		return false
	return str(tile.get("terrain_type", "")) == "ground"


func _class_seat(sim: Node, class_id: String) -> int:
	for unit in sim.snapshot().get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if str(unit.get("class_id", "")) == class_id:
			return int(unit.get("seat", -1))
	return 0


func _save(file_name: String) -> bool:
	var path := _dir.path_join(file_name)
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	print("PLANT LOS SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	if err != OK:
		push_error("could not save %s" % path)
		return false
	return true
