extends SceneTree

## Dev screenshot helper (not a test suite): a hot-seat 2v2 / 3v3 Koliseo
## match on the live board, at deployment and after both teams are placed.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_teams.gd -- <out_dir> [team_size]

var _out := "user://"
var _size := 2
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_size = int(args[1])
	GearBag.save_path = "user://shot_teams_bag.json"
	HeroProgress.save_path = "user://shot_teams_hero.json"
	StillVault.save_path = "user://shot_teams_still.json"
	KoliseoWallet.save_path = "user://shot_teams_wallet.json"
	root.size = Vector2i(1280, 720)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		# Autoloads exist only once the tree runs; load the picker then.
		var cs: GDScript = load("res://scenes/class_select.gd")
		cs.set("hotseat_team_size", _size)
		var picks: Array[String] = []
		var roster := ["kestrel", "ironjaw", "mender", "gloam", "bastion", "ironjaw"]
		for i in 2 * _size:
			picks.append(roster[i])
		cs.set("hotseat_classes", picks)
		cs.set("hotseat_map_id", "crosshaven")
		change_scene_to_file("res://main.tscn")
		return false
	if _frames == 60:
		_shot("deploy")
		var sim = root.get_node("/root/CombatSim")
		for seat in 2 * _size:
			var cells: Array = sim.legal_deploy_cells(seat)
			if not cells.is_empty():
				sim.place_unit(seat, cells[0])
		sim.ready_seat(0)
		sim.ready_seat(1)
		var board := current_scene.find_child("BoardView", true, false)
		if board == null:
			board = current_scene
		if board.has_method("_refresh"):
			board.call("_refresh")
		if board.has_method("_maybe_enter_combat"):
			board.call("_maybe_enter_combat")
	if _frames == 140:
		_shot("fight")
		quit(0)
	return false


func _shot(tag: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join("teams_%dv%d_%s.png" % [_size, _size, tag]))
