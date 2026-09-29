extends SceneTree

## Dev screenshot helper (not a test suite). Plays each class's flourish on
## a live board and saves a frame mid-burst per class.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_flourish.gd -- <out_dir>

var _out := "user://"
var _frames := 0
var _i := 0
const SPELLS := [["kestrel", "mark_shot"], ["ironjaw", "strike"], ["mender", "mend"], ["gloam", "cut"], ["bastion", "bash"]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var cs: GDScript = load("res://scenes/class_select.gd")
	var pair: Array[String] = ["kestrel", "ironjaw"]
	cs.set("hotseat_classes", pair)
	cs.set("hotseat_map_id", "crosshaven")
	root.size = Vector2i(960, 720)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null:
		return false
	var k := (_frames - 30) % 40
	if k == 0:
		if _i >= SPELLS.size():
			return true
		var at := Vector2i(7, 7)
		var ev := {"type": "hit", "spell": SPELLS[_i][1], "seat": 0, "target_seat": 1, "caster_cell": Vector2i(5, 7), "to": at}
		board._ensure_flourish()
		board._flourish.play([ev], {})
	elif k == 8 or k == 16 or k == 24:
		var img := root.get_texture().get_image()
		img.save_png(_out.path_join("flourish_%s_%d.png" % [SPELLS[_i][0], k]))
		if k == 24:
			_i += 1
	return false
