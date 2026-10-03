extends SceneTree

## L6 still: one action bar on Crosshaven, beside the fight.
## godot --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy --path . -s res://tests/pc/capture_l6.gd -- --out=/tmp/l6_frames

var _out := "/tmp/l6_frames"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--out="):
			_out = str(arg).trim_prefix("--out=")
	call_deferred("_go")


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")):
			break
	sim.reset_match({
		"seed": 3,
		"map_id": "crosshaven",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(7, 7), Vector2i(8, 7)],
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"kestrel_hp": 16,
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	board.set_board_theme("")
	var cam: Camera2D = board.get("_camera")
	cam.zoom = Vector2(1.15, 1.15)
	for _i in 12:
		await process_frame
	await _shot(_out.path_join("bar.png"))
	sim.submit({"type": "end_turn"})
	board._refresh()
	for _i in 8:
		await process_frame
	var hud: Node = main.get_node("HUD")
	if hud.has_method("_on_spell_hover"):
		hud.call("_on_spell_hover", "crush")
	for _i in 4:
		await process_frame
	await _shot(_out.path_join("ironjaw.png"))
	print("L6_SHOT life=%s" % str(sim.snapshot().get("units", [])))
	quit(0)


func _shot(path: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(path)
	print("L6_WROTE %s" % path)
