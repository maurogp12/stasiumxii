extends SceneTree

## Dev capture (not a test suite): one fighter walking a few tiles on the live
## board, a frame every 1/30 s, to judge the walk.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_walk.gd -- <out_dir> <class>

var _out := "user://"
var _class := "kestrel"
var _frames := 0
var _shots := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_class = args[1]
	GearBag.save_path = "user://shot_walk_bag.json"
	HeroProgress.save_path = "user://shot_walk_hero.json"
	StillVault.save_path = "user://shot_walk_still.json"
	KoliseoWallet.save_path = "user://shot_walk_wallet.json"
	root.size = Vector2i(960, 720)
	Engine.max_fps = 30


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		var cs: GDScript = load("res://scenes/class_select.gd")
		cs.set("hotseat_team_size", 1)
		var picks: Array[String] = [_class, "bastion"]
		cs.set("hotseat_classes", picks)
		cs.set("hotseat_map_id", "crosshaven")
		change_scene_to_file("res://main.tscn")
	elif _frames == 50:
		var sim = root.get_node("/root/CombatSim")
		sim.reset_match({"seed": 4, "flat_board": true, "skip_deploy": true, "classes": [_class, "bastion"], "positions": [Vector2i(4, 7), Vector2i(12, 2)]})
		var board := current_scene.get_node("BoardView")
		if board.has_method("_rebuild_pawns"):
			board.call("_rebuild_pawns")
		board.call("_refresh")
	elif _frames == 70:
		var board := current_scene.get_node("BoardView")
		board.call("_submit", {"type": "move", "to": Vector2i(7, 7)})
		var cam: Camera2D = board.get("_camera")
		if cam != null:
			cam.zoom = Vector2(2.2, 2.2)
		var hud := current_scene.get_node_or_null("HUD")
		if hud != null:
			hud.visible = false
	elif _frames > 70 and _frames <= 70 + 45:
		var img := root.get_texture().get_image()
		var board := current_scene.get_node("BoardView")
		var pawn: Node2D = board.pawns_by_seat[0]
		var p: Vector2 = pawn.get_global_transform_with_canvas().origin
		img = img.get_region(Rect2i(clampi(int(p.x) - 90, 0, 780), clampi(int(p.y) - 200, 0, 490), 180, 230))
		img.save_png(_out.path_join("walk_%03d.png" % _shots))
		_shots += 1
	elif _frames > 120:
		quit(0)
	return false
