extends SceneTree

## Review captures for the painted rooms and the spell bar.
## Not a test suite.
## xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/shot_art_review.gd -- <out_dir> --mobile-frame

const KOLISEO := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const VISUAL_SORT := preload("res://board/visual_sort.gd")
const CASTS := [
	["kestrel_mark", ["kestrel", "ironjaw"], Vector2i(5, 7), Vector2i(8, 7), "mark_shot"],
	["ironjaw_strike", ["ironjaw", "kestrel"], Vector2i(6, 7), Vector2i(7, 7), "strike"],
	["gloam_cut", ["gloam", "ironjaw"], Vector2i(6, 7), Vector2i(7, 7), "cut"],
	["bastion_bash", ["bastion", "kestrel"], Vector2i(6, 7), Vector2i(7, 7), "bash"],
	["mender_mend", ["mender", "ironjaw"], Vector2i(6, 7), Vector2i(6, 7), "mend"],
]

var _out := "user://"
var _phase := "boot"
var _frames := 0
var _index := 0
var _hold := 0
var _opened := -1
var _clock := 0.0
var _bar_saved := false
var _cast_sent := false
var _sample := false
var _rooms_only := false
var _biomes: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if str(arg) == "--sample":
			_sample = true
		elif str(arg) == "--rooms-only":
			_rooms_only = true
		elif str(arg).begins_with("--biomes="):
			_biomes = str(arg).trim_prefix("--biomes=").split(",", false)
		elif not str(arg).begins_with("--"):
			_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var cs: GDScript = load("res://scenes/class_select.gd")
	cs.set("hotseat_classes", ["kestrel", "ironjaw"])
	cs.set("hotseat_map_id", "crosshaven")
	change_scene_to_file("res://main.tscn")
	_phase = "koliseo"
	_frames = 0


func _process(delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null:
		return false
	if _phase == "koliseo":
		return _rooms(board, false)
	if _phase == "stasis":
		return _rooms(board, true)
	if _phase == "casts":
		return _casts(board, delta)
	return true


func _wanted(biome: String) -> bool:
	return _biomes.is_empty() or _biomes.has(biome)


func _rooms(board: Node, stasis: bool) -> bool:
	var steps: Array = []
	if stasis:
		for step in _stasis_steps():
			if _wanted(str(step[0])):
				steps.append(step)
	else:
		for biome in KOLISEO:
			if _wanted(str(biome)):
				steps.append(biome)
	if _index >= steps.size():
		_index = 0
		_frames = 0
		_hold = 0
		if stasis:
			if _rooms_only:
				return true
			_phase = "casts"
			_opened = -1
			_show_hud(true)
			change_scene_to_file("res://main.tscn")
		else:
			_phase = "stasis"
			_opened = -1
		return false
	if _hold == 0:
		if not bool(board.get("_booted")):
			if stasis and _opened != _index:
				_open_stasis()
				_opened = _index
			return false
		if stasis:
			if _opened != _index:
				_open_stasis()
				_opened = _index
				return false
		else:
			_open_koliseo(board, str(steps[_index]))
		_show_hud(false)
		_hold = _frames
		return false
	if _frames - _hold < 80:
		return false
	if _frames - _hold == 80:
		var room_id := "koliseo_%s" % str(steps[_index]) if not stasis else _stasis_room_id(steps[_index])
		_stand_behind(board, room_id)
		return false
	if _frames - _hold >= 82:
		var name := "koliseo_%s.png" % str(steps[_index]) if not stasis else "stasis_%s_%s.png" % [steps[_index][0], steps[_index][1]]
		var image := root.get_texture().get_image()
		image.save_png(_out.path_join(name))
		print("saved ", name, " ", image.get_size())
		_index += 1
		_hold = 0
		if _sample and not stasis:
			_phase = "casts"
			_index = 0
			_opened = -1
			_show_hud(true)
			change_scene_to_file("res://main.tscn")
	return false


func _casts(board: Node, delta: float) -> bool:
	if _index >= CASTS.size():
		Engine.time_scale = 1.0
		return true
	if not bool(board.get("_booted")):
		return false
	if _hold == 0:
		Engine.time_scale = 0.25
		_stage_cast(board, CASTS[_index])
		_show_hud(true)
		_clock = 0.0
		_bar_saved = false
		_cast_sent = false
		_hold = 1
		return false
	_clock += delta
	if not _bar_saved and _clock >= 0.12:
		var shot := root.get_texture().get_image()
		shot.save_png(_out.path_join("spellbar_%s.png" % str(CASTS[_index][0])))
		_note_hud(shot.get_size())
		_bar_saved = true
	elif _bar_saved and not _cast_sent and _clock >= 0.2:
		var intent := {"type": "cast", "spell": str(CASTS[_index][4]), "to": CASTS[_index][3], "seat": 0}
		board._submit(intent)
		_cast_sent = true
		_clock = 0.0
	elif _cast_sent and _clock >= _cast_hold(str(CASTS[_index][4])):
		root.get_texture().get_image().save_png(_out.path_join("cast_%s.png" % str(CASTS[_index][0])))
		print("saved cast ", CASTS[_index][0])
		_index += 1
		_hold = 0
		if _sample:
			Engine.time_scale = 1.0
			return true
	return false


func _cast_hold(spell_id: String) -> float:
	if spell_id == "mark_shot":
		return 0.32
	if spell_id == "mend":
		return 0.12
	return 0.28


func _note_hud(image_size: Vector2i) -> void:
	var hud := current_scene.get_node_or_null("HUD")
	var cluster: Node = null
	if hud != null:
		cluster = hud.find_child("AbilityCluster", true, false)
	var rect := Rect2()
	var shown := false
	if cluster is Control:
		rect = (cluster as Control).get_global_rect()
		shown = (cluster as Control).visible
	print("spellbar ", image_size, " cluster ", shown, " ", rect)


func _open_koliseo(board: Node, map_id: String) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": map_id,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(2, 2), Vector2i(12, 12)],
	})
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera()


func _open_stasis() -> void:
	var step: Array = _stasis_steps()[_index]
	StasisCatalog.clear_run()
	MobileHub.pending_biome_id = str(step[0])
	StasisCatalog.begin(str(step[0]))
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = str(step[1])
	change_scene_to_file(StasisCatalog.FIGHT_SCENE)


func _stasis_steps() -> Array:
	var out: Array = []
	for biome in KOLISEO:
		out.append([biome, "a"])
		out.append([biome, "b"])
	return out


func _stasis_room_id(step: Array) -> String:
	return "stasis_%s_room_%s" % [step[0], step[1]]


func _stage_cast(board: Node, scene: Array) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	var caster: Vector2i = scene[2]
	var target: Vector2i = scene[3]
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"rolls": [1, 1, 1, 1],
		"classes": scene[1],
		"positions": [caster, target],
	})
	if str(scene[4]) == "mend":
		var me: Dictionary = sim._unit_by_seat(0)
		me["hp"] = int(me["hp"]) - 30
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
	if board.has_method("_fit_board_camera"):
		board._fit_board_camera()


func _show_hud(on: bool) -> void:
	var hud := current_scene.get_node_or_null("HUD")
	if hud != null:
		hud.visible = on


func _stand_behind(board: Node, room_id: String) -> void:
	var place_path := "res://art/rooms/%s/place.json" % room_id
	if not FileAccess.file_exists(place_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(place_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var best: Dictionary = {}
	var best_h := -1
	for raw in parsed.get("occluders", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var size: Array = raw.get("size", [0, 0])
		var h := int(size[1]) if size.size() > 1 else 0
		if h > best_h:
			best_h = h
			best = raw
	if best.is_empty():
		return
	var cell_raw: Array = best.get("cell", [0, 0])
	var front := Vector2i(int(cell_raw[0]), int(cell_raw[1]))
	var back := front + Vector2i(-1, 0)
	if back.x < 0 or back.y < 0:
		back = front + Vector2i(0, -1)
	if back.x < 0 or back.y < 0 or back.x > 14 or back.y > 14:
		return
	var pawns: Variant = board.get("pawns_by_seat")
	if typeof(pawns) != TYPE_DICTIONARY or not pawns.has(0):
		return
	var pawn: Node2D = pawns[0]
	var elev := 0.0
	if board.has_method("_elev_at"):
		elev = float(board.call("_elev_at", back))
	pawn.grid_position = back
	pawn.position = VISUAL_SORT.cell_to_local(back, elev)
	pawn.z_as_relative = true
	pawn.z_index = VISUAL_SORT.unit_z_index(back, elev)
	print("occluder ", room_id, " ", front, " fighter ", back)
