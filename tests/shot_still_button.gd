extends SceneTree

## 2400×1080: Kestrel's turn with the Mirror Hour button beside Pass Turn,
## then the same fight after it is used and the button is gone.
## godot --rendering-driver opengl3 -s res://tests/shot_still_button.gd -- <dir>

var _dir := "/opt/cursor/artifacts/still_button"
var _frames := 0
var _phase := 0
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
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 240:
		push_error("still button shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_board = current_scene.get_node_or_null("BoardView") if current_scene != null else null
		if _board == null or not bool(_board._booted):
			return false
		if not _arm():
			return true
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		_save("before_mirror.png")
		_log("BEFORE")
		if not _spend():
			return true
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		if _frames < 8:
			return false
		_save("after_mirror.png")
		_log("AFTER")
		return true
	return true


func _arm() -> bool:
	var sim: Node = root.get_node("CombatSim")
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(6, 8), Vector2i(9, 8)],
		"seat_gear": {0: {"worn": [], "still": {"id": "mirror_hour", "mode": "intact"}}},
	})
	var guard := 0
	while int(sim.snapshot().get("active_seat", -1)) != 0 and guard < 6:
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
		guard += 1
	if int(sim.snapshot().get("active_seat", -1)) != 0:
		push_error("Kestrel never got the turn")
		return false
	_board._rebuild_pawns()
	_board._refresh()
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud.focus_fighter(0)
		hud._layout_chrome()
	return _button_state(true)


func _spend() -> bool:
	var sim: Node = root.get_node("CombatSim")
	var used: Dictionary = sim.submit({"type": "use_still", "seat": 0, "target_seat": 1})
	print("MIRROR ok=%s coach=%s ready=%s" % [
		used.get("ok", false),
		str(sim.snapshot().get("coach", "")),
		bool(sim._unit_by_seat(0).get("still_ready", true)),
	])
	if not bool(used.get("ok", false)):
		push_error("Mirror Hour did not resolve")
		return false
	_board._rebuild_pawns()
	_board._refresh()
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud.focus_fighter(0)
		hud._layout_chrome()
	return _button_state(false)


func _button_state(want_visible: bool) -> bool:
	var hud: CombatHUD = _board._hud
	if hud == null or hud._use_still_button == null or hud._end_turn_button == null:
		push_error("Pass Turn or the Still button is missing")
		return false
	var button := hud._use_still_button
	var shown := button.visible
	var path := ""
	var mark := button.get_node_or_null("StillButtonIcon") as TextureRect
	if mark != null and mark.texture != null:
		path = mark.texture.resource_path
	print("BUTTON visible=%s path=%s text=%s" % [shown, path, button.text])
	if shown != want_visible:
		push_error("Still button visibility is %s" % shown)
		return false
	if want_visible and path != StillVault.icon_path("mirror_hour"):
		push_error("Still button is not Mirror Hour")
		return false
	if button.text != "":
		push_error("Still button still has a text label")
		return false
	return true


func _log(tag: String) -> void:
	var hud: CombatHUD = _board._hud
	if hud == null:
		return
	var button := hud._use_still_button
	var parent := button.get_parent()
	var end := hud._end_turn_button
	var beside := button.global_position.x >= end.global_position.x + end.size.x - 4.0
	print("%s STILL parent=%s index=%s pos=%s size=%s end=%s visible=%s beside=%s" % [
		tag,
		parent.name if parent != null else "",
		parent.get_children().find(button) if parent != null else -1,
		button.global_position,
		button.size,
		end.global_position,
		button.visible,
		beside,
	])
	if tag == "BEFORE" and (not button.visible or not beside):
		push_error("Mirror Hour is not beside Pass Turn")
	if tag == "AFTER" and button.visible:
		push_error("Mirror Hour button is still showing after it was used")
	for i in mini(hud._seat_panels.size(), 2):
		var icon := hud._seat_panels[i].get_node_or_null("StillIcon") as TextureRect
		var title := hud._banner_titles[i].text if i < hud._banner_titles.size() else ""
		var path := ""
		if icon != null and icon.texture != null:
			path = icon.texture.resource_path
		print("%s CARD %d title=%s icon=%s path=%s" % [tag, i, title, icon.visible if icon != null else false, path])


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized %s to 2400x1080" % file_name)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
