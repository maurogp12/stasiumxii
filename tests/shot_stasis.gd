extends SceneTree

## Dev screenshot helper (not a test suite): each Stasis door's Room A (trash
## pack) and Room B (boss) on the live fight scene.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_stasis.gd -- <out_dir> [biome]

const BIOMES := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]

var _out := "user://"
var _only := ""
var _frames := 0
var _step := -1
var _t0 := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_only = args[1]
	GearBag.save_path = "user://shot_stasis_bag.json"
	HeroProgress.save_path = "user://shot_stasis_hero.json"
	StillVault.save_path = "user://shot_stasis_still.json"
	KoliseoWallet.save_path = "user://shot_stasis_wallet.json"
	root.size = Vector2i(960, 720)
	_next()


func _list() -> Array:
	var out: Array = []
	for b in BIOMES:
		if _only == "" or _only == b:
			out.append([b, "a"])
			out.append([b, "b"])
	return out


func _next() -> void:
	_step += 1
	var steps := _list()
	if _step >= steps.size():
		quit(0)
		return
	var biome: String = steps[_step][0]
	StasisCatalog.clear_run()
	MobileHub.pending_biome_id = biome
	StasisCatalog.begin(biome)
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = steps[_step][1]
	change_scene_to_file(StasisCatalog.FIGHT_SCENE)
	_t0 = _frames


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames - _t0 == 40:
		var steps := _list()
		root.get_texture().get_image().save_png(_out.path_join("stasis_%s_%s.png" % [steps[_step][0], steps[_step][1]]))
		_next()
	return false
