extends SceneTree

## Dev screenshot helper (not a test suite): stages real casts and a walk on
## the live board and saves a strip of frames per scene, to judge character
## motion and spell visuals together.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_cast.gd -- <out_dir> [scene_name]

## [name, classes, positions, intent (seat 0), extra config]
const SCENES := [
	["kestrel_mark", ["kestrel", "ironjaw"], [Vector2i(5, 7), Vector2i(8, 7)], {"type": "cast", "spell": "mark_shot", "to": Vector2i(8, 7)}, {}],
	["ironjaw_strike", ["ironjaw", "kestrel"], [Vector2i(6, 7), Vector2i(7, 7)], {"type": "cast", "spell": "strike", "to": Vector2i(7, 7)}, {}],
	["gloam_cut", ["gloam", "ironjaw"], [Vector2i(6, 7), Vector2i(7, 7)], {"type": "cast", "spell": "cut", "to": Vector2i(7, 7)}, {}],
	["bastion_bash", ["bastion", "kestrel"], [Vector2i(6, 7), Vector2i(7, 7)], {"type": "cast", "spell": "bash", "to": Vector2i(7, 7)}, {}],
	["mender_mend", ["mender", "ironjaw"], [Vector2i(6, 7), Vector2i(9, 7)], {"type": "cast", "spell": "mend", "to": Vector2i(6, 7)}, {"hurt_self": 30}],
	["ironjaw_ko", ["ironjaw", "mender"], [Vector2i(6, 7), Vector2i(7, 7)], {"type": "cast", "spell": "strike", "to": Vector2i(7, 7)}, {"foe_hp": 5}],
	["kestrel_walk", ["kestrel", "ironjaw"], [Vector2i(4, 7), Vector2i(10, 7)], {"type": "move", "to": Vector2i(7, 7)}, {}],
]
## Frames after the intent at which a picture is saved.
const TAPS := [2, 6, 10, 14, 20, 28, 40]

var _out := "user://"
var _only := ""
var _frames := 0
var _scene := -1
var _t0 := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_only = args[1]
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["kestrel", "ironjaw"]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", "crosshaven")
	root.size = Vector2i(960, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or _frames < 20:
		return false
	if _scene < 0 or _frames - _t0 > int(TAPS[-1]) + 30:
		_scene += 1
		while _scene < SCENES.size() and _only != "" and str(SCENES[_scene][0]) != _only:
			_scene += 1
		if _scene >= SCENES.size():
			return true
		_stage(board, SCENES[_scene])
		_t0 = _frames + 12
		return false
	var k := _frames - _t0
	if k == 0:
		var intent: Dictionary = (SCENES[_scene][3] as Dictionary).duplicate()
		intent["seat"] = 0
		board._submit(intent)
	elif TAPS.has(k):
		root.get_texture().get_image().save_png(_out.path_join("%s_%02d.png" % [SCENES[_scene][0], k]))
	return false


func _stage(board: Node, scene: Array) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	var positions: Array = scene[2]
	sim.reset_match({"seed": 1, "skip_deploy": true, "flat_board": true, "rolls": [1, 1, 1, 1], "classes": scene[1], "positions": positions})
	var extra: Dictionary = scene[4]
	if extra.has("hurt_self"):
		var me: Dictionary = sim._unit_by_seat(0)
		me["hp"] = int(me["hp"]) - int(extra["hurt_self"])
	if extra.has("foe_hp"):
		var foe: Dictionary = sim._unit_by_seat(1)
		foe["hp"] = int(extra["foe_hp"])
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
