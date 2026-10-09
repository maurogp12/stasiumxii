extends SceneTree

## Phone frame of Threshgate Room A. The side cards stay the small menu and
## read Marks as a number. godot --rendering-driver opengl3 -s res://tests/shot_player_menu.gd -- <out.png> --mobile-frame

var _path := "/tmp/player_menu_proposed.png"
var _frames := 0
var _phase := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_path = text
	var folder := _path.get_base_dir()
	if folder != "":
		DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	root.size = Vector2i(2400, 1080)
	change_scene_to_file("res://main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 180:
		push_error("player menu shot timed out")
		return true
	var board := current_scene.get_node_or_null("BoardView") if current_scene != null else null
	if board == null or not bool(board._booted):
		return false
	var sim: Node = root.get_node("CombatSim")
	if _phase == 0:
		StasisCatalog.clear_run()
		if not StasisCatalog.begin("crosshaven"):
			push_error("Threshgate did not begin")
			return true
		StasisCatalog.set_star(4)
		StasisCatalog.set_party(["ironjaw", "bastion", "kestrel", "mender"])
		var config: Dictionary = StasisCatalog.fight_config()
		if config.is_empty():
			push_error("Threshgate fight config was empty")
			return true
		sim.reset_match(config)
		_grant_marks(sim)
		board._rebuild_pawns()
		board._refresh()
		_phase = 1
		_frames = 0
		return false
	if _frames < 12:
		return false
	_aim(board)
	if _frames < 16:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_path)
	var hud: CombatHUD = board._hud
	var left: Vector2 = hud._banner_panels[0].size
	print("PLAYER_MENU %s %dx%d err=%s left=%s body=%s" % [_path, image.get_width(), image.get_height(), err, left, hud._kestrel_body.text])
	return true


func _grant_marks(sim: Node) -> void:
	var kestrel_seat := -1
	for unit in sim._units:
		if str(unit.get("class_id", "")) == "kestrel":
			kestrel_seat = int(unit.get("seat", -1))
			break
	var foe_marked := false
	for unit in sim._units:
		var class_id := str(unit.get("class_id", ""))
		if class_id == "ironjaw":
			sim._gain_marks(unit, 2, kestrel_seat)
		elif not foe_marked and int(unit.get("team", 0)) == 1:
			sim._gain_marks(unit, 2, kestrel_seat)
			foe_marked = true


func _aim(board: Node) -> void:
	var cam: Camera2D = board._camera
	if cam == null:
		return
	var sum := Vector2.ZERO
	var n := 0
	for seat in board.pawns_by_seat.keys():
		if int(seat) > 3:
			continue
		var pawn: Node2D = board.pawns_by_seat[seat]
		sum += pawn.position
		n += 1
	if n == 0:
		return
	cam.zoom = Vector2(1.55, 1.55)
	cam.position = sum / float(n) + Vector2(40, -20)
