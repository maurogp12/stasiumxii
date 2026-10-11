extends SceneTree

## Character-select stills for the before/after clip.
## xvfb-run -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 \
##   --audio-driver Dummy --path . --resolution 1920x1080 \
##   -s res://tests/pc/capture_charselect.gd -- --out=/tmp/charselect_frames

const Roster = preload("res://backend/pc_roster.gd")
const SCREEN := "res://scenes/pc/character_select/character_select.tscn"


func _initialize() -> void:
	var out := "/tmp/charselect_frames"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	_wipe()
	var look := Roster.default_appearance()
	Roster.create_character("Hera", "ironjaw", look)
	var mara := Roster.default_appearance()
	mara["gender"] = "f"
	mara["face"] = "soft"
	Roster.create_character("Mara", "kestrel", mara)
	process_frame.connect(_shoot.bind(out), CONNECT_ONE_SHOT)


func _shoot(out: String) -> void:
	var screen = load(SCREEN).instantiate()
	screen.instant = true
	screen.auto_enter_world = false
	screen.auto_quit = false
	root.add_child(screen)
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	_save(out, "after_list.png")
	screen.press_create()
	await process_frame
	screen.show_tab("gameplay")
	screen.select_class("kestrel")
	await process_frame
	_save(out, "after_class.png")
	screen.show_tab("appearance")
	screen.set_gender("f")
	await process_frame
	_save(out, "after_appearance.png")
	screen.press_create()
	screen.name_field.text = "Nia"
	await process_frame
	_save(out, "after_name.png")
	_wipe()
	quit()


func _save(out: String, file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(file_name))
	print("saved %s %s" % [file_name, image.get_size()])


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
