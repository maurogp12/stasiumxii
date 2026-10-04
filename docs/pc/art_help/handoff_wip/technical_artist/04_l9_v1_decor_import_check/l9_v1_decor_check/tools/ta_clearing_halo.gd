extends SceneTree
## Uses the game's own display copy of the clearing (resized exactly as jungle_backdrop does),
## and blends it over black and white with the same Image.blend_rect the plate compositor uses.
const BOARD := preload("res://board/pc/crosshaven_board.gd")
const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")
var _out := "/tmp/ta_l9"
var _size := Vector2i(1280, 720)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var t := str(arg)
		if t.begins_with("--out="): _out = t.trim_prefix("--out=")
		elif t.begins_with("--w="): _size.x = int(t.trim_prefix("--w="))
		elif t.begins_with("--h="): _size.y = int(t.trim_prefix("--h="))
	call_deferred("_go")

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	LIGHT.set_suppressed(false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1280, 720)
	root.size = _size
	DisplayServer.window_set_size(_size)
	await process_frame
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")): break
	root.get_node("CombatSim").reset_match(PAIR.args("crosshaven"))
	board._refresh()
	board._fit_board_camera()
	for _i in 6: await process_frame
	var jungle := board.get_node("JungleBackdrop")
	for cam_name in ["fit", "zoom1"]:
		if cam_name == "zoom1":
			var cam := board.get_node("BoardCamera") as Camera2D
			cam.zoom = Vector2(1, 1)
		for _i in 4: await process_frame
		var mid: Sprite2D = jungle.get("_backs")["back_mid"].get_node("Art")
		var img: Image = mid.texture.get_image().duplicate()
		if img.is_compressed(): img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(_out.path_join("clearing_display_%s_%d.png" % [cam_name, _size.x]))
		for bg in [["k", Color(0, 0, 0, 1)], ["w", Color(1, 1, 1, 1)]]:
			var base := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
			base.fill(bg[1])
			base.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
			base.save_png(_out.path_join("clearing_over_%s_%s_%d.png" % [bg[0], cam_name, _size.x]))
		print("TA_CLEARING %s %d display=%s on_screen_scale=%s" % [cam_name, _size.x, str(img.get_size()), str(mid.scale)])
	main.free()
	quit(0)
