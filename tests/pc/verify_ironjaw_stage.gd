extends SceneTree

## Headless check that the Ironjaw stage recolour and idle actually move pixels.
## Not part of tests/run_*_tests.gd.
##   xvfb-run -s "-screen 0 1280x1280x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 768x1024 \
##     -s res://tests/pc/verify_ironjaw_stage.gd -- --out=/tmp/ironjaw_verify

const STAGE := preload("res://scenes/pc/character_select/character_stage.tscn")

var _out := "/tmp/ironjaw_verify"
var _stage: Node
var _failed := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_go")


func _go() -> void:
	root.size = Vector2i(768, 1024)
	_stage = STAGE.instantiate()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_stage)
	_stage.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	var loaded: bool = _stage.show_model("ironjaw", "m")
	_expect(loaded, "ironjaw male loads")
	if not loaded:
		_finish()
		return
	var vp: SubViewport = _stage.viewport()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for _i in 8:
		await process_frame
	var player0 := _stage.model_root().find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player0 != null:
		_stage.play_idle()
		player0.seek(0.05, true)
	_stage.set_body_colors(Color(0.76, 0.58, 0.46), Color(0.25, 0.14, 0.08), Color(0.22, 0.40, 0.62))
	await _shot(0.0, "stage_front.png")
	await _shot(-35.0, "stage_three_quarter.png")
	await _shot(180.0, "stage_back.png")
	_stage.yaw_degrees = 0.0
	_stage._apply_yaw()
	_stage.set_body_colors(Color(0.95, 0.25, 0.15), Color(0.08, 0.05, 0.04), Color(0.15, 0.25, 0.9))
	var warm := await _grab("recolour_warm.png")
	_stage.set_body_colors(Color(0.2, 0.82, 0.28), Color(0.9, 0.82, 0.2), Color(0.85, 0.15, 0.15))
	var cool := await _grab("recolour_cool.png")
	var recol := _split(warm, cool)
	print("RECOLOUR changed=%d still=%d" % [int(recol.x), int(recol.y)])
	_expect(recol.x > 400, "recolour changes skin, hair, or eyes")
	_expect(recol.y > 400, "cloth and metal stay put when body colours change")
	var player := _stage.model_root().find_child("AnimationPlayer", true, false) as AnimationPlayer
	_expect(player != null, "animation player exists")
	if player != null:
		_stage.play_idle()
		player.seek(0.05, true)
		var pose_a := await _grab("idle_a.png")
		player.seek(2.0, true)
		var pose_b := await _grab("idle_b.png")
		var motion := _split(pose_a, pose_b)
		print("IDLE changed=%d still=%d" % [int(motion.x), int(motion.y)])
		_expect(motion.x > 80, "idle poses differ across the loop")
	_finish()


func _shot(yaw: float, file_name: String) -> void:
	_stage.yaw_degrees = yaw
	_stage._apply_yaw()
	await _grab(file_name)


func _grab(file_name: String) -> Image:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var vp: SubViewport = _stage.viewport()
	var image := vp.get_texture().get_image()
	image.save_png(_out.path_join(file_name))
	return image


func _split(a: Image, b: Image) -> Vector2i:
	var changed := 0
	var still := 0
	var step := 4
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if ca.a < 0.15 and cb.a < 0.15:
				continue
			var d := absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			if d > 0.12:
				changed += 1
			else:
				still += 1
	return Vector2i(changed, still)


func _expect(cond: bool, label: String) -> void:
	if cond:
		print("OK ", label)
	else:
		_failed += 1
		print("FAIL ", label)


func _finish() -> void:
	print("ironjaw verify failed=%d" % _failed)
	quit(1 if _failed > 0 else 0)
