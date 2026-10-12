extends SceneTree

## Before/after clip for the 2D character-select puppet. Not a test suite.
## Needs a real GL context:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1920x1080 --fixed-fps 30 \
##     -s res://tests/pc/capture_charselect_stage.gd -- --out=/tmp/puppet_frames
## Then ffmpeg (30 fps, H.264) into docs/pc/media/charselect/.
## Before is the locked idle (no puppet). After is Ironjaw male: idle, select, turn.

const Roster = preload("res://backend/pc_roster.gd")
const SCREEN := "res://scenes/pc/character_select/character_select.tscn"

var _out := "/tmp/puppet_frames"
var _frame_i := 0
var _caption: Label


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_wipe()
	call_deferred("_go")


func _go() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	var screen = load(SCREEN).instantiate()
	screen.instant = true
	screen.auto_enter_world = false
	screen.auto_quit = false
	root.add_child(screen)
	_caption = Label.new()
	_caption.position = Vector2(48, 24)
	_caption.size = Vector2(1400, 48)
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	root.add_child(_caption)
	await process_frame
	await process_frame
	screen.select_class("kestrel")
	await process_frame
	_caption.text = "BEFORE  Kestrel keeps the locked idle. No puppet yet."
	await _hold(36)
	screen.select_class("ironjaw")
	screen.set_gender("m")
	await process_frame
	var puppet = screen.puppet
	puppet.snap_facing("S")
	puppet.play_idle()
	_caption.text = "AFTER  Ironjaw male, idle on S."
	await _hold(24)
	_save("puppet_s_idle.png")
	await _hold(36)
	_caption.text = "AFTER  Select. The axe stays in the hand."
	puppet.play_select()
	# 1.05 s is the low point of the slam. Capture runs at 30 fps.
	await _hold(32)
	_save("puppet_select_low.png")
	await _hold(36)
	puppet.snap_facing("S")
	puppet.play_idle()
	_caption.text = "AFTER  Turn. S mirrored."
	puppet.turn(1)
	await _hold(28)
	_caption.text = "AFTER  Back view, B."
	puppet.turn(1)
	await _hold(20)
	_save("puppet_back.png")
	await _hold(16)
	_caption.text = "AFTER  Back to S."
	puppet.turn(1)
	await _hold(24)
	print("CAPTURED frames=%d stills=puppet_s_idle.png,puppet_select_low.png,puppet_back.png" % _frame_i)
	quit(0)


func _hold(count: int) -> void:
	for _i in count:
		await process_frame
		_save("frame_%04d.png" % _frame_i)


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(file_name))
	if file_name.begins_with("frame_"):
		_frame_i += 1


func _wipe() -> void:
	if FileAccess.file_exists(Roster.ROSTER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Roster.ROSTER_PATH))
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var pending: Array[String] = []
	while name != "":
		if name.begins_with("pc_progress_"):
			pending.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	for file_name in pending:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))
