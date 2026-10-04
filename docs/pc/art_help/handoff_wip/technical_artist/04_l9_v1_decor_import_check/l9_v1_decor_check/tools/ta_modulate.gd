extends SceneTree
## Does Sprite2D.modulate reach the sway shader output? Leaves only, modulate 1.0 vs 0.3 grey vs alpha 0.3.
const BOARD := preload("res://board/pc/crosshaven_board.gd")
const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")
const LEAVES := ["front_leaves_left", "front_leaves_right", "front_leaves_top", "front_leaves_bottom"]
var _hidden := []
func _initialize() -> void:
	call_deferred("_go")
func _go() -> void:
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	LIGHT.set_suppressed(false)
	LIGHT.set_outdoor_preset(LIGHT.PRESET_LIGHT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
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
	for child in board.get_children():
		if child != jungle and (child is CanvasItem or child is CanvasLayer) and child.visible:
			child.visible = false
	for child in jungle.get_children():
		if child is CanvasItem and not LEAVES.has(str(child.name)): child.visible = false
	for layer in root.find_children("*", "CanvasLayer", true, false): layer.visible = false
	jungle.set_process(false)
	jungle.preview_time(1.0)
	RenderingServer.set_default_clear_color(Color(0.5, 0.5, 0.5))
	var sprites: Dictionary = jungle.get("_sprites")
	var shots := {}
	for case in [["m100", Color(1, 1, 1, 1)], ["m030", Color(0.3, 0.3, 0.3, 1)], ["a030", Color(1, 1, 1, 0.3)]]:
		for s in LEAVES: (sprites[s] as Sprite2D).modulate = case[1]
		for _i in 3: await process_frame
		RenderingServer.force_draw()
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("/workspace/scratch/l9_v1_decor_check/cap/modulate_%s.png" % case[0])
		shots[case[0]] = img
	var a: Image = shots["m100"]
	for k in ["m030", "a030"]:
		var b: Image = shots[k]
		var diff := 0
		for y in range(0, a.get_height(), 2):
			for x in range(0, a.get_width(), 2):
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.02: diff += 1
		print("TA_MODULATE %s changed_px(sampled 1/4)=%d" % [k, diff])
	main.free()
	quit(0)
