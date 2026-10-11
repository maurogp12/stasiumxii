extends SceneTree

## Before/after clip for the character-select 3D stage. Not a test suite.
## Needs a real GL context:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##     --audio-driver Dummy --path . --resolution 1920x1080 --fixed-fps 30 \
##     -s res://tests/pc/capture_charselect_stage.gd -- \
##     --out=/tmp/charselect_frames --ref=/tmp/ironjaw_base_and_sets.png
## Then ffmpeg (30 fps, H.264) into docs/pc/media/charselect/.

const STAGE := preload("res://scenes/pc/character_select/character_stage.tscn")
const FRAMES := 270

var _out := "/tmp/charselect_frames"
var _ref := ""
var _stage: Node
var _caption: Label
var _frame_i := 0
var _grabbing := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--out="):
			_out = text.trim_prefix("--out=")
		elif text.begins_with("--ref="):
			_ref = text.trim_prefix("--ref=")
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_go")


func _go() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	await process_frame
	_build()
	for _i in 30:
		await process_frame
	_grabbing = true
	RenderingServer.frame_post_draw.connect(_grab)
	for i in FRAMES:
		_step(i)
		await process_frame
	_grabbing = false
	await process_frame
	print("CAPTURED frames=%d" % _frame_i)
	quit(0)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.07, 0.05)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	var col_w := 616.0
	var gap := 16.0
	var left := 20.0
	var top := 58.0
	var panel_h := 820.0
	_column(left, top, col_w, panel_h, "REFERENCE", "Approved base look")
	_column(left + col_w + gap, top, col_w, panel_h, "BEFORE", "2D class picker")
	_column(left + (col_w + gap) * 2.0, top, col_w, panel_h, "AFTER", "3D pedestal")

	var ref_rect := TextureRect.new()
	ref_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ref_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ref_rect.position = Vector2(left + 8.0, top + 8.0)
	ref_rect.size = Vector2(col_w - 16.0, panel_h - 16.0)
	ref_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ref_rect.texture = _load_ref()
	root.add_child(ref_rect)

	var before := SubViewport.new()
	before.name = "BeforePicker"
	before.size = Vector2i(1280, 900)
	before.transparent_bg = false
	before.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	before.disable_3d = true
	root.add_child(before)
	# Load after autoloads exist. A parse-time preload compiles the picker
	# before NetSession is registered and the script fails.
	var packed := load("res://scenes/class_select.tscn") as PackedScene
	var picker := packed.instantiate()
	before.add_child(picker)
	if picker.has_method("choose_mode"):
		picker.choose_mode("hotseat")
	var before_rect := TextureRect.new()
	before_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	before_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	before_rect.position = Vector2(left + col_w + gap + 8.0, top + 8.0)
	before_rect.size = Vector2(col_w - 16.0, panel_h - 16.0)
	before_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	before_rect.texture = before.get_texture()
	root.add_child(before_rect)

	var holder := Control.new()
	holder.position = Vector2(left + (col_w + gap) * 2.0 + 8.0, top + 8.0)
	holder.size = Vector2(col_w - 16.0, panel_h - 16.0)
	holder.clip_contents = true
	root.add_child(holder)
	_stage = STAGE.instantiate()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_stage)
	_stage.show_model("test", "f")
	_stage.play_idle()

	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.04, 0.03, 0.92)
	bar.position = Vector2(0, 900)
	bar.size = Vector2(1920, 180)
	root.add_child(bar)
	_caption = Label.new()
	_caption.position = Vector2(28, 948)
	_caption.size = Vector2(1860, 60)
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_color", Color(0.96, 0.9, 0.74))
	_caption.text = "Idle on the pedestal. The 2D picker has no 3D figure."
	root.add_child(_caption)


func _column(x: float, y: float, w: float, h: float, title: String, subtitle: String) -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.16, 0.13, 0.1)
	panel.position = Vector2(x, y)
	panel.size = Vector2(w, h)
	root.add_child(panel)
	var label := Label.new()
	label.text = title
	label.position = Vector2(x, 16)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.45))
	root.add_child(label)
	var sub := Label.new()
	sub.text = subtitle
	sub.position = Vector2(x, 46)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	root.add_child(sub)


func _load_ref() -> Texture2D:
	if _ref == "":
		return null
	var image := Image.load_from_file(_ref)
	if image == null:
		push_error("reference image missing: " + _ref)
		return null
	return ImageTexture.create_from_image(image)


func _step(i: int) -> void:
	if i == 40:
		_stage.play_select()
		_caption.text = "Select flourish, then back to idle."
	elif i == 110:
		_stage.set_body_colors(Color(0.93, 0.78, 0.66), Color(0.55, 0.12, 0.1), Color(0.2, 0.75, 0.35))
		_caption.text = "Skin, hair, and eyes. Cloth stays the painted colour."
	elif i == 155:
		_stage.set_face(2)
		_caption.text = "Face type 3 of 4. The other faces are hidden."
	elif i == 190:
		_stage.set_slot("chest", true)
		_stage.set_slot("head", true)
		_caption.text = "Chest and head gear replace the tunic and the hair."
	elif i == 215:
		_stage.set_slot("legs", true)
		_stage.set_slot("boots", true)
		_stage.set_slot("weapon", true)
		_caption.text = "Legs, boots, and weapon. Skin stays. Dye stays off."
	elif i >= 230:
		_stage.turn_by_pixels(2.0)
		_caption.text = "Drag to turn. It eases back to a three-quarter view."


func _grab() -> void:
	if not _grabbing:
		return
	var image := root.get_texture().get_image()
	if image == null:
		return
	if image.get_width() != 1920 or image.get_height() != 1080:
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/f%05d.png" % [_out, _frame_i])
	_frame_i += 1
