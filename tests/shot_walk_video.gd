extends SceneTree

## Dev capture (not a test suite): frames of the live board while fighters
## walk paths with turns, for a short video. Run with --fixed-fps 30.
## xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tests/shot_walk_video.gd -- <out_dir>

var _out := "user://"
var _frames := 0
var _shot := 0
const STEPS := [
	[60, 0, null],
	[120, -1, null],
	[135, 1, null],
	[195, -1, null],
	[210, 0, null],
]
const LAST := 270


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	GearBag.save_path = "user://shot_wv_bag.json"
	HeroProgress.save_path = "user://shot_wv_hero.json"
	StillVault.save_path = "user://shot_wv_still.json"
	KoliseoWallet.save_path = "user://shot_wv_wallet.json"
	root.size = Vector2i(960, 720)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		var cs: GDScript = load("res://scenes/class_select.gd")
		cs.set("hotseat_team_size", 1)
		var picks: Array[String] = ["kestrel", "gloam"]
		cs.set("hotseat_classes", picks)
		cs.set("hotseat_map_id", "crosshaven")
		change_scene_to_file("res://main.tscn")
		return false
	if _frames == 40:
		var sim = root.get_node("/root/CombatSim")
		sim.reset_match({"seed": 4, "map_id": "crosshaven", "skip_deploy": true, "classes": ["kestrel", "gloam"], "positions": [Vector2i(6, 7), Vector2i(7, 12)]})
		var board := current_scene.get_node("BoardView")
		board.call("_rebuild_pawns")
		board.call("_refresh")
		var cam: Camera2D = board.get("_camera")
		if cam != null:
			cam.zoom = Vector2(1.7, 1.7)
			board.set("_pan_limit", Vector2(400, 300))
			var pawn: Node2D = board.pawns_by_seat[0]
			cam.position = pawn.global_position - board.global_position
	for step in STEPS:
		if _frames == int(step[0]):
			var board := current_scene.get_node("BoardView")
			var sim = root.get_node("/root/CombatSim")
			if int(step[1]) < 0:
				sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
				board.call("_refresh")
			else:
				# The farthest legal walk (the full 3 MP), so the path has turns.
				var seat := int(sim.snapshot()["active_seat"])
				var me: Dictionary = {}
				for u in sim.snapshot()["units"]:
					if int(u["seat"]) == seat:
						me = u
				var best = null
				var best_d := -1
				for it in sim.legal_intents(seat):
					if str(it.get("type", "")) != "move":
						continue
					var to: Vector2i = it["to"]
					var d: int = absi(to.x - me["pos"].x) + absi(to.y - me["pos"].y)
					if d > best_d:
						best_d = d
						best = to
				if best != null:
					board.call("_submit", {"type": "move", "to": best})
	if _frames >= 50 and _frames <= LAST:
		root.get_texture().get_image().save_png(_out.path_join("v_%04d.png" % _shot))
		_shot += 1
	if _frames > LAST:
		quit(0)
	return false
