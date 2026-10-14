extends SceneTree

## Phone frame: the Plaza Guard scarecrow walking on its painted stride.
## xvfb-run -s "-screen 0 1600x720x24" godot --rendering-driver opengl3 --path . -s res://tests/shot_scarecrow_walk.gd -- /opt/cursor/artifacts/scarecrow_walk/walking.png

var _out := "/opt/cursor/artifacts/scarecrow_walk/walking.png"
var _frames := 0
var _phase := "boot"
var _board: Node
var _pawn: Pawn
var _origin := Vector2.ZERO


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("-"):
			continue
		_out = text
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	DisplayServer.window_set_size(Vector2i(1600, 720))
	root.size = Vector2i(1600, 720)
	StasisCatalog.clear_run()
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = "a"
	change_scene_to_file(StasisCatalog.FIGHT_SCENE)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 400:
		push_error("scarecrow walk shot timed out in %s" % _phase)
		quit(1)
		return true
	if current_scene == null:
		return false
	_board = current_scene.get_node_or_null("BoardView")
	if _board == null or not bool(_board.get("_booted")):
		return false
	if _phase == "boot":
		if _frames < 12:
			return false
		if not _start_walk():
			quit(1)
			return true
		_phase = "walk"
		_frames = 0
		return false
	if _phase == "walk":
		if _pawn == null or not is_instance_valid(_pawn):
			push_error("scarecrow pawn vanished")
			quit(1)
			return true
		var moved := _pawn.position.distance_to(_origin)
		var frame_x := -1.0
		if _pawn._sprite != null and _pawn._sprite.texture is AtlasTexture:
			frame_x = (_pawn._sprite.texture as AtlasTexture).region.position.x
		if moved > 8.0 and frame_x > 0.0:
			_frame_camera()
			_phase = "hold"
			_frames = 0
		return false
	if _frames < 2:
		return false
	_save()
	return true


func _start_walk() -> bool:
	var sim: Node = root.get_node("/root/CombatSim")
	var guard: Dictionary = {}
	for unit in sim.snapshot().get("units", []):
		if str(unit.get("name", "")) == "Plaza Guard":
			guard = unit
	if guard.is_empty():
		push_error("no Plaza Guard")
		return false
	var seat := int(guard["seat"])
	_pawn = _board.pawns_by_seat[seat]
	var origin: Vector2i = _pawn.grid_position
	_origin = _pawn.position
	var dest := Vector2i(-1, -1)
	for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var cell: Vector2i = origin + step
		if _board._in_bounds(cell) and sim.tile_at(cell).get("walkable", false) and sim._occupant_seat(cell) < 0:
			dest = cell
			break
	if dest.x < 0:
		push_error("no empty step from %s" % origin)
		return false
	print("WALK from %s to %s scale=%.3f tile_sec=%.3f" % [origin, dest, _pawn.foe_draw_scale(), _pawn.measured_tile_sec(_origin.distance_to(_board._cell_to_local(dest)))])
	_board._animate_path(seat, [dest], origin)
	return true


func _frame_camera() -> void:
	if _board._camera == null:
		return
	_board._camera.zoom = Vector2(2.6, 2.6)
	_board._camera.position = _pawn.position


func _save() -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 1600 or image.get_height() != 720:
		image.resize(1600, 720, Image.INTERPOLATE_BILINEAR)
	var err := image.save_png(_out)
	var frame_x := -1.0
	if _pawn._sprite != null and _pawn._sprite.texture is AtlasTexture:
		frame_x = (_pawn._sprite.texture as AtlasTexture).region.position.x
	print("SHOT %s %dx%d frame_x=%.0f pos=%s err=%s" % [_out, image.get_width(), image.get_height(), frame_x, _pawn.position, err])
	if err != OK or frame_x <= 0.0:
		push_error("walk frame was not showing")
		quit(1)
