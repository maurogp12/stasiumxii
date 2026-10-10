extends SceneTree

## 2400×1080: the Stills vault with the forged icons, then a fight where only
## the fighter who socketed a Still shows that icon.
## godot --rendering-driver opengl3 -s res://tests/shot_still_icons.gd -- <dir>

const VAULT_PATH := "user://shot_still_icons_vault.json"

var _dir := "/opt/cursor/artifacts/still_icons"
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
	if _frames > 240:
		push_error("still icon shot timed out in phase %d" % _phase)
		return true
	if _phase == 0:
		_screen = (load("res://scenes/stills_screen.gd") as Script).new()
		_screen.name = "StillIconShot"
		root.add_child(_screen)
		_phase = 1
		_frames = 0
		return false
	if _phase == 1:
		if _frames < 8:
			return false
		_save("vault_icons.png")
		_log_vault()
		_screen.queue_free()
		_screen = null
		change_scene_to_file("res://main.tscn")
		_phase = 2
		_frames = 0
		return false
	if _phase == 2:
		_board = current_scene.get_node_or_null("BoardView") if current_scene != null else null
		if _board == null or not bool(_board._booted):
			return false
		if not _shot_combat():
			return true
		_phase = 3
		_frames = 0
		return false
	if _phase == 3:
		if _frames < 10:
			return false
		_save("combat_one_still.png")
		_log_combat()
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


func _log_vault() -> void:
	var forged := 0
	for id in StillVault.IDS:
		var tile := _screen.find_child("Still_" + id, true, false)
		if tile == null:
			push_error("vault is missing %s" % id)
			continue
		var art: Texture2D = tile.get("_art")
		var path := ""
		if art != null:
			path = art.resource_path
		var want := StillVault.icon_path(id, false)
		print("VAULT %s art=%s" % [id, path])
		if path == want:
			forged += 1
		else:
			push_error("%s tile is not the forged icon (%s)" % [id, path])
	print("VAULT forged=%d" % forged)
	if forged != 14:
		push_error("vault is not showing all 14 forged icons")


func _shot_combat() -> bool:
	var sim: Node = root.get_node("CombatSim")
	sim.reset_match({
		"seed": 4,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(5, 8), Vector2i(10, 8)],
		"seat_gear": {0: {"worn": [], "still": {"id": "mirror_hour", "mode": "intact"}}},
	})
	_board._rebuild_pawns()
	_board._refresh()
	var hud: CombatHUD = _board._hud
	if hud != null:
		hud.focus_fighter(0)
		hud._layout_chrome()
	return true


func _log_combat() -> void:
	var hud: CombatHUD = _board._hud
	if hud == null or hud._seat_panels.size() < 2:
		push_error("combat cards are missing")
		return
	for i in 2:
		var mark := hud._seat_panels[i].get_node_or_null("StillIcon") as TextureRect
		var title := hud._banner_titles[i].text if i < hud._banner_titles.size() else ""
		var path := ""
		var shown := false
		if mark != null:
			shown = mark.visible
			if mark.texture != null:
				path = mark.texture.resource_path
		print("CARD %d title=%s icon_visible=%s path=%s" % [i, title, shown, path])
	var owner := hud._seat_panels[0].get_node_or_null("StillIcon") as TextureRect
	var other := hud._seat_panels[1].get_node_or_null("StillIcon") as TextureRect
	if owner == null or not owner.visible or owner.texture == null:
		push_error("the fighter with Mirror Hour is not showing its icon")
	elif owner.texture.resource_path != StillVault.icon_path("mirror_hour"):
		push_error("the owner's icon is not Mirror Hour")
	if other != null and other.visible:
		push_error("the fighter without a Still is showing an icon")
	var button_path := ""
	if hud._use_still_button != null and hud._use_still_button.icon != null:
		button_path = hud._use_still_button.icon.resource_path
	print("USE_STILL visible=%s icon=%s" % [
		hud._use_still_button.visible if hud._use_still_button != null else false,
		button_path,
	])


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 2400 or image.get_height() != 1080:
		image.resize(2400, 1080, Image.INTERPOLATE_BILINEAR)
		print("resized %s to 2400x1080" % file_name)
	var path := _dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s %dx%d err=%s" % [path, image.get_width(), image.get_height(), err])
