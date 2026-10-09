extends SceneTree

## Phone frame of the class picker.
## godot --rendering-driver opengl3 -s res://tests/shot_class_select.gd -- <out.png>

var _path := "/tmp/class_select.png"
var _frames := 0


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
	change_scene_to_file("res://scenes/class_select.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 90:
		push_error("class select shot timed out")
		return true
	var picker := current_scene
	if picker == null or not picker.has_method("class_cards_visible"):
		return false
	if not picker.class_cards_visible():
		return false
	if _frames < 8:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_path)
	var cards: Array = []
	var row: Node = picker.get("_cards_row")
	if row != null:
		for child in row.get_children():
			if child is Control:
				cards.append((child as Control).size)
	var title_size := 0
	var button_size := Vector2.ZERO
	for child in _walk(picker):
		if child is Label and str(child.text) == "STASIUM XII":
			title_size = int(child.get_theme_font_size("font_size"))
		if child is Button and str(child.text) == "Hot-seat":
			button_size = (child as Control).size
	print("CLASS_SELECT %s %dx%d err=%s cards=%s title_px=%s hotseat=%s prompt=%s" % [_path, image.get_width(), image.get_height(), err, cards, title_size, button_size, picker.prompt_text()])
	return true


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
