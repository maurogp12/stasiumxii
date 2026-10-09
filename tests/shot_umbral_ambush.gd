extends SceneTree

## Phone frame: Gloam at 4 Umbral behind a foe, Ambush aim float, then the hit coach.
## godot --rendering-driver opengl3 -s res://tests/shot_umbral_ambush.gd -- <dir>

var _dir := "/tmp/umbral"
var _frames := 0
var _phase := 0
var _step := 0
var _stand: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_dir = text
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("umbral shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		if not _boot(sim, board, _step):
			return true
		_phase = 1
		_frames = 0
		return false
	if _frames < 12:
		return false
	var image := root.get_texture().get_image()
	var name := "ambush_preview.png" if _step == 0 else "ambush_coach.png"
	var path := _dir.path_join(name)
	var err := image.save_png(path)
	var feel: Dictionary = sim.aim_feel(0, SpellKits.AMBUSH)
	var coach := str(sim.snapshot().get("coach", ""))
	var badge := _badge_text(board)
	var aim := board.get_node_or_null("AimLine/AimFloat")
	var aim_text := ""
	if aim != null:
		aim_text = "%s vis=%s at=%s" % [aim.text, aim.visible, aim.global_position]
	print("UMBRAL %s %dx%d err=%s float=%s aim=%s badge=%s coach=%s umbral=%s" % [path, image.get_width(), image.get_height(), err, feel.get("float_text", ""), aim_text, badge, coach, sim.snapshot()["units"][0].get("umbral", -1)])
	_step += 1
	if _step > 1:
		return true
	_phase = 0
	_frames = 0
	return false


func _boot(sim: Node, board: Node, step: int) -> bool:
	if _stand.is_empty():
		_stand = _backstab_line(sim, board)
	if _stand.size() < 2:
		push_error("no cardinal backstab line")
		return false
	sim.reset_match({
		"seed": 1,
		"map_id": "slagcrown",
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [_stand[0], _stand[1]],
		"kestrel_facing": "W",
		"gloam_umbral": 4,
		"rolls": [1],
	})
	if step == 1:
		var hit: Dictionary = sim.submit({"type": "cast", "spell": "ambush", "to": _stand[1], "seat": 0})
		if not bool(hit.get("ok", false)):
			push_error("ambush preview hit did not resolve")
			return false
	board._rebuild_pawns()
	board._refresh()
	if step == 0 and board._hud != null:
		board._hud._selected_spell = SpellKits.AMBUSH
		board._hud._refresh_spell_buttons()
		board._on_spell_selected(SpellKits.AMBUSH)
		board._refresh()
	if board._camera != null:
		board._camera.zoom = Vector2(2.4, 2.4)
		board._center_on_cell(_stand[1])
	return true


func _backstab_line(sim: Node, board: Node) -> Array:
	var cells: Array = board.tiles.keys()
	var best: Array = []
	var best_score := -1
	for cell in cells:
		var gloam: Vector2i = cell
		var foe: Vector2i = gloam + Vector2i(2, 0)
		var back: Vector2i = gloam + Vector2i(3, 0)
		var gap: Vector2i = gloam + Vector2i(1, 0)
		if not board.tiles.has(foe) or not board.tiles.has(back) or not board.tiles.has(gap):
			continue
		# Keep the pair off the map rim so the damage float is not under the menus.
		if gloam.x < 4 or gloam.y < 4 or foe.x > 14 or foe.y > 12:
			continue
		sim.reset_match({
			"seed": 1,
			"map_id": "slagcrown",
			"skip_deploy": true,
			"classes": ["gloam", "kestrel"],
			"positions": [gloam, foe],
			"kestrel_facing": "W",
			"gloam_umbral": 4,
			"rolls": [1],
		})
		if sim.snapshot()["units"][0]["pos"] != gloam or sim.snapshot()["units"][1]["pos"] != foe:
			continue
		var feel: Dictionary = sim.aim_feel(0, SpellKits.AMBUSH)
		if str(feel.get("float_text", "")) != "-51":
			continue
		var score := 100 - absi(gloam.x - 8) - absi(gloam.y - 6)
		if score > best_score:
			best_score = score
			best = [gloam, foe, back]
	if not best.is_empty():
		print("UMBRAL stand gloam=%s foe=%s" % [best[0], best[1]])
	return best


func _badge_text(board: Node) -> String:
	if board._hud == null:
		return ""
	var bits: PackedStringArray = PackedStringArray()
	for child in board._hud._turn_chips():
		var badge := child.get_node_or_null("StackBadge") as Control
		if badge == null or not badge.visible:
			continue
		var count := badge.get_node_or_null("Count") as Label
		bits.append(str(child.get_meta("seat", "?")) + ":" + (count.text if count != null else "?"))
	return " ".join(bits)
