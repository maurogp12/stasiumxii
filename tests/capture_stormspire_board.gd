extends SceneTree

## One-shot in-game capture of the Stormspire combat board.
## Phone landscape, Koliseo overview. Run with a window, not --headless:
##   godot --path . --rendering-driver opengl3 --resolution 1600x720 \
##     -s res://tests/capture_stormspire_board.gd -- --mobile-frame
## Writes /opt/cursor/artifacts/stormspire_ingame_phone.png, then quits.

const OUT := "/opt/cursor/artifacts/stormspire_ingame_phone.png"


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var window := root
	window.size = Vector2i(1600, 720)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(960, 720)
	var select := load("res://scenes/class_select.gd")
	select.hotseat_map_id = "stormspire"
	var classes: Array[String] = ["kestrel", "ironjaw"]
	select.hotseat_classes = classes
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
	var board: Node = main.get_node("BoardView")
	var sim := root.get_node("CombatSim")
	sim.reset_match({
		"seed": 1,
		"map_id": "stormspire",
		"skip_deploy": true,
		"classes": ["kestrel", "ironjaw"],
	})
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var view := root.get_viewport()
	var image := view.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Stormspire capture got an empty viewport")
		quit(1)
		return
	var snap: Dictionary = sim.snapshot()
	var camera := board.get("_camera") as Camera2D
	var zoom := camera.zoom.x if camera != null else -1.0
	print("capture map=%s size=%s viewport=%s zoom=%.3f" % [
		str(snap.get("demo_map", snap.get("map_id", ""))),
		image.get_size(),
		view.get_visible_rect().size,
		zoom,
	])
	var err := image.save_png(OUT)
	if err != OK:
		push_error("save_png failed %s" % err)
		quit(1)
		return
	quit(0)
