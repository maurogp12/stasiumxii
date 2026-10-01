extends SceneTree

## Dev screenshot helper (not a test suite): the dungeon finder at ★3 with
## AI-filled seats, then the party fight on the live board.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_dungeon_party.gd -- <out_dir>

var _out := "user://"
var _frames := 0
var _run: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	GearBag.save_path = "user://shot_party_bag.json"
	HeroProgress.save_path = "user://shot_party_hero.json"
	StillVault.save_path = "user://shot_party_still.json"
	KoliseoWallet.save_path = "user://shot_party_wallet.json"
	root.size = Vector2i(960, 720)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		var hub: Script = load("res://scenes/mobile_hub.gd")
		hub.set("pending_biome_id", "crosshaven")
		change_scene_to_file("res://scenes/stasis_run.tscn")
	elif _frames == 20:
		_run = current_scene
		_run.set("_auto_launch", false)
		_run.call("pick_star", 3)
		_run.call("pick_class", "kestrel")
		_run.call("fill_with_ai", 0)
		_run.call("fill_with_ai", 1)
	elif _frames == 40:
		_shot("finder")
		_run.call("enter_dungeon")
		change_scene_to_file(StasisCatalog.FIGHT_SCENE)
	elif _frames == 200:
		_shot("fight")
	elif _frames == 700:
		_shot("fight_later")
		quit(0)
	return false


func _shot(tag: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join("dungeon_party_%s.png" % tag))
