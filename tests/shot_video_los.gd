extends SceneTree

## Stormspire phone layout from the 0.1.189 recording.
## Kestrel (11,0), Bastion (7,0), banners (8,0) and (8,1), Snap Wall on (8,1).
## Bastion's tile must be the Mark Shot target, not grey.
## xvfb-run -s "-screen 0 2560x1440x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_video_los.gd -- /opt/cursor/artifacts/video_los --mobile-frame

var _dir := "/opt/cursor/artifacts/video_los"
var _phase := "boot"
var _frames := 0
var _kestrel := Vector2i(11, 0)
var _bastion := Vector2i(7, 0)
var _banner := Vector2i(8, 0)
var _wall := Vector2i(8, 1)


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
	select.set("hotseat_map_id", "stormspire")
	select.set("hotseat_classes", ["kestrel", "bastion"])
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 400:
		push_error("video los shot timed out in %s" % _phase)
		return true
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null or not bool(board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 8:
			return false
		if not _place(board):
			return true
		_aim(board)
		_phase = "aim"
		_frames = 0
		return false
	if _phase == "aim":
		if _frames < 24:
			return false
		if not _check(board):
			return true
		_save("stormspire_bastion_target.png")
		return true
	return false


func _place(board: Node) -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["bastion", "kestrel"],
		"positions": [_bastion, _kestrel],
		"bastion_aegis": 6,
		"rolls": [1],
	})
	if not bool(sim.submit({"type": "cast", "spell": "plant", "to": _banner, "seat": 0}).get("ok", false)):
		push_error("banner on the shot did not plant")
		return false
	if not bool(sim.submit({"type": "cast", "spell": "plant", "to": _wall, "seat": 0}).get("ok", false)):
		push_error("banner beside the shot did not plant")
		return false
	if not bool(sim.submit({"type": "cast", "spell": "snap_wall", "to": _wall, "seat": 0}).get("ok", false)):
		push_error("Snap Wall did not stand on the banner")
		return false
	if not bool(sim.submit({"type": "end_turn", "seat": 0}).get("ok", false)):
		push_error("Bastion did not end his turn")
		return false
	board._rebuild_grid(int(sim.snapshot().get("board_size", 15)))
	board._rebuild_pawns()
	board._refresh()
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera(false, true)
	var sees: bool = sim.has_line_of_sight(_kestrel, _bastion)
	var blocker: Vector2i = sim.sight_blocker(_kestrel, _bastion)
	print("VIDEO LOS sees=%s blocker=%s" % [sees, blocker])
	if not sees:
		push_error("Bastion is still hidden, blocker=%s" % blocker)
		return false
	return true


func _aim(board: Node) -> void:
	var hud: CombatHUD = board._hud
	var kestrel_seat := 1
	hud.focus_fighter(kestrel_seat)
	hud._selected_spell = "mark_shot"
	hud._refresh_spell_buttons()
	board._aim_hover = _bastion
	board._paint_highlights()
	if board.has_method("_sync_aim_preview"):
		board._sync_aim_preview(_bastion)


func _check(board: Node) -> bool:
	var tile = board.tiles.get(_bastion)
	var highlight := "" if tile == null else str(tile.highlight)
	var between = board.tiles.get(Vector2i(9, 0))
	var between_hl := "" if between == null else str(between.highlight)
	print("BASTION HIGHLIGHT %s BETWEEN %s" % [highlight, between_hl])
	if highlight != "target":
		push_error("Bastion's tile is %s, wanted target" % highlight)
		quit(1)
		return false
	if between_hl == "grey":
		push_error("the tile between them is grey")
		quit(1)
		return false
	return true


func _save(file_name: String) -> bool:
	var path := _dir.path_join(file_name)
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	print("VIDEO LOS SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
	if err != OK:
		push_error("could not save %s" % path)
		return false
	return true
