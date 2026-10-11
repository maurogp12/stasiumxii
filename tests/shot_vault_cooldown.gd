extends SceneTree

## Kestrel's turn, Vault cooling down, button reads "1 turn".
## xvfb-run -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 -s res://tests/shot_vault_cooldown.gd -- /opt/cursor/artifacts/vault --mobile-frame

var _out := "/tmp/vault_cooldown.png"
var _phase := "boot"
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--"):
			continue
		_out = str(arg)
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir() if _out.ends_with(".png") else _out)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	var select: GDScript = load("res://scenes/class_select.gd")
	var roster: Array[String] = ["kestrel", "ironjaw"]
	select.set("hotseat_classes", roster)
	select.set("hotseat_map_id", "crosshaven")
	change_scene_to_file("res://main.tscn")
	_phase = "fight"


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null:
		return false
	var board := current_scene.get_node_or_null("BoardView")
	if board == null or not bool(board.get("_booted")):
		return false
	if _phase == "fight":
		if _frames < 8:
			return false
		_arm_cooldown(board)
		if board.has_method("_fit_board_camera"):
			board._fit_board_camera()
		_phase = "hold"
		_frames = 0
		return false
	if _phase == "hold":
		if _frames < 24:
			return false
		var hud: Node = board._hud
		var button: Button = hud._spell_buttons.get("vault")
		var badge := button.get_node_or_null("CooldownBadge") if button != null else null
		var text := "" if badge == null else str(badge.text)
		print("VAULT_BADGE ", text)
		print("VAULT_DISABLED ", button.disabled if button != null else "missing")
		if button != null:
			var rect := button.get_global_rect()
			print("VAULT_RECT ", rect.position.x, " ", rect.position.y, " ", rect.size.x, " ", rect.size.y)
		var file_name := "vault_one_turn.png"
		var path := _out if _out.ends_with(".png") else _out.path_join(file_name)
		var image := root.get_texture().get_image()
		image.save_png(path)
		print("saved ", path, " ", image.get_width(), "x", image.get_height())
		return true
	return false


func _arm_cooldown(board: Node) -> void:
	var sim: Node = root.get_node("/root/CombatSim")
	sim.reset_match({
		"seed": 1,
		"skip_deploy": true,
		"map_id": "crosshaven",
		"classes": ["kestrel", "ironjaw"],
		"positions": [Vector2i(5, 5), Vector2i(6, 5)],
	})
	# (5,5) to (3,5) is mud on Crosshaven. East lands on open ground, and
	# Ironjaw on (6,5) stays next to her after the jump.
	var vault: Dictionary = sim.submit({"type": "cast", "spell": "vault", "to": Vector2i(7, 5), "seat": 0})
	print("VAULT_CAST ", vault.get("ok", false), " ", vault.get("reason", ""))
	for _i in 4:
		sim.submit({"type": "end_turn", "seat": sim.snapshot().get("active_seat", 0)})
	board._rebuild_grid(15)
	board._rebuild_pawns()
	board._refresh()
