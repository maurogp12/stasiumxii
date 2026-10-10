extends SceneTree

## 2400×1080: the 14-Still vault, one Still's detail, then combat
## Mirror Hour (ally swap), Bound Hour on the corner card, and Tolling Bell
## revealing a Gloam who just turned Invisible.
## godot --rendering-driver opengl3 -s res://tests/shot_stills.gd -- <dir>

const VAULT_PATH := "user://shot_stills_vault.json"

var _dir := "/opt/cursor/artifacts/stills"
var _frames := 0
var _phase := 0
var _screen: StillsScreen
var _board: Node


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
	_seed_vault()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 360:
		push_error("stills shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_show_vault()
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		_save("vault_14.png")
		_log_vault()
		_screen.pick("mirror_hour")
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		if _frames < 8:
			return false
		_save("detail_mirror_hour.png")
		_log_detail()
		_screen.queue_free()
		_screen = null
		change_scene_to_file("res://main.tscn")
		_phase = 3
		_frames = 0
		return false
	if _phase == 3:
		_board = current_scene.get_node_or_null("BoardView") if current_scene != null else null
		if _board == null or not bool(_board._booted):
			return false
		if not _shot_mirror():
			return true
		_phase = 4
		_frames = 0
		return false
	if _phase == 4:
		if _frames < 10:
			return false
		_save("combat_mirror_hour.png")
		if not _shot_bound():
			return true
		_phase = 5
		_frames = 0
		return false
	if _phase == 5:
		if _frames < 10:
			return false
		_save("combat_bound_hour.png")
		_log_bound_card()
		if not _shot_tolling():
			return true
		_phase = 6
		_frames = 0
		return false
	if _phase == 6:
		if _frames < 10:
			return false
		_save("combat_tolling_bell.png")
		_log_tolling()
		return true
	return true


func _seed_vault() -> void:
	StillVault.save_path = VAULT_PATH
	if FileAccess.file_exists(VAULT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(VAULT_PATH))
	var vault := StillVault.new()
	var fragments := {}
	for id in StillVault.IDS:
		fragments[id] = StillVault.FORGE_COST
	vault.fragments = fragments
	vault.socket = ""
	vault.save()


func _show_vault() -> void:
	_screen = (load("res://scenes/stills_screen.gd") as Script).new()
	_screen.name = "StillsShot"
	root.add_child(_screen)
	_phase = 1
	_frames = 0


func _log_vault() -> void:
	var names: PackedStringArray = PackedStringArray()
	for id in StillVault.IDS:
		var tile := _screen.find_child("Still_" + id, true, false)
		if tile == null:
			push_error("vault is missing %s" % id)
		else:
			names.append(id)
	print("VAULT tiles=%d %s" % [names.size(), " ".join(names)])
	if names.size() != 14:
		push_error("vault listing is not 14 Stills")


func _log_detail() -> void:
	var head := _screen.find_child("StillHead", true, false) as Label
	var head_text := head.text if head != null else ""
	print("DETAIL head=%s" % head_text)
	if not head_text.contains("Mirror Hour"):
		push_error("detail view is not Mirror Hour")
	var saw_intact := false
	var saw_over := false
	for child in _screen._detail.get_children():
		var label := child as Label
		if label == null:
			continue
		print("DETAIL line=%s" % label.text)
		if label.text.begins_with("Intact"):
			saw_intact = true
		if label.text.begins_with("Overwound"):
			saw_over = true
	if not saw_intact or not saw_over:
		push_error("detail view is missing Intact / Overwound sentences")


func _shot_mirror() -> bool:
	var sim: Node = root.get_node("CombatSim")
	var spots := [Vector2i(4, 8), Vector2i(11, 4), Vector2i(8, 8), Vector2i(11, 11)]
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"team_size": 2,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw", "bastion", "gloam"],
		"positions": spots,
		"seat_gear": {0: {"worn": [], "still": {"id": "mirror_hour", "mode": "intact"}}},
	})
	var before_kestrel: Vector2i = sim._unit_by_seat(0)["pos"]
	var before_bastion: Vector2i = sim._unit_by_seat(2)["pos"]
	var swapped: Dictionary = sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	print("MIRROR ok=%s coach=%s kestrel %s -> %s bastion %s -> %s" % [
		swapped.get("ok", false),
		str(sim.snapshot().get("coach", "")),
		before_kestrel,
		sim._unit_by_seat(0)["pos"],
		before_bastion,
		sim._unit_by_seat(2)["pos"],
	])
	if not bool(swapped.get("ok", false)):
		push_error("Mirror Hour swap failed")
		return false
	if sim._unit_by_seat(0)["pos"] != before_bastion or sim._unit_by_seat(2)["pos"] != before_kestrel:
		push_error("Mirror Hour did not swap the ally")
		return false
	_board._rebuild_pawns()
	_board._refresh()
	return true


func _shot_bound() -> bool:
	var sim: Node = root.get_node("CombatSim")
	var spots := [Vector2i(5, 8), Vector2i(11, 4), Vector2i(7, 8), Vector2i(11, 11)]
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"team_size": 2,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw", "bastion", "gloam"],
		"positions": spots,
		"seat_gear": {0: {"worn": [], "still": {"id": "bound_hour", "mode": "intact"}}},
	})
	var bound: Dictionary = sim.submit({"type": "use_still", "seat": 0, "target_seat": 2})
	print("BOUND ok=%s name=%s coach=%s" % [
		bound.get("ok", false),
		str(sim._unit_by_seat(0).get("bound_name", "")),
		str(sim.snapshot().get("coach", "")),
	])
	if not bool(bound.get("ok", false)):
		push_error("Bound Hour failed")
		return false
	_board._rebuild_pawns()
	_board._refresh()
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud.focus_fighter(0)
		hud._layout_chrome()
	return true


func _log_bound_card() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null or hud._kestrel_body == null:
		push_error("corner card is missing")
		return
	var card := hud._kestrel_body.get_parsed_text().replace("\n", " | ")
	var title := hud._banner_titles[0].text if hud._banner_titles.size() > 0 else ""
	print("BOUND card title=%s text=%s" % [title, card])
	if not card.contains("Bound to Bastion"):
		push_error("corner card is missing Bound to Bastion")


func _shot_tolling() -> bool:
	var sim: Node = root.get_node("CombatSim")
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["gloam", "kestrel"],
		"positions": [Vector2i(6, 8), Vector2i(9, 8)],
		"rolls": [1],
		"seat_gear": {1: {"worn": [], "still": {"id": "tolling_bell", "mode": "intact"}}},
	})
	var gloam: Dictionary = sim._unit_by_seat(0)
	var faded: Dictionary = sim.submit({"type": "cast", "spell": "fade", "to": gloam["pos"], "seat": 0})
	var hidden := bool(sim._unit_by_seat(0).get("invisible", true))
	var coach := str(sim.snapshot().get("coach", ""))
	print("TOLLING ok=%s invisible=%s coach=%s" % [faded.get("ok", false), hidden, coach])
	if not bool(faded.get("ok", false)):
		push_error("Gloam Fade failed")
		return false
	if hidden:
		push_error("Tolling Bell left Gloam Invisible")
		return false
	if not coach.contains("Tolling Bell"):
		push_error("coach is missing Tolling Bell")
		return false
	_board._rebuild_pawns()
	_board._refresh()
	var pawn: Node = _board.pawns_by_seat.get(0, null)
	var shown := false
	if pawn is CanvasItem:
		shown = (pawn as CanvasItem).visible
	print("TOLLING pawn_visible=%s" % shown)
	if not shown:
		push_error("revealed Gloam is not drawn")
		return false
	return true


func _log_tolling() -> void:
	var hud: CombatHUD = _board._hud
	var coach := ""
	if hud != null and hud._coach_label != null:
		coach = hud._coach_label.text
	print("TOLLING hud_coach=%s" % coach)
	if not coach.contains("Tolling Bell"):
		push_error("HUD coach is missing Tolling Bell")


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized %s to 2400x1080" % file_name)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
