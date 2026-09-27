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
	var hud := main.get_node("HUD")
	hud.visible = false
	# Full 15×15 in the phone frame. The 1.55 overview keeps the width and
	# crops the diamond tips. This contain fit keeps every tile on screen.
	var camera := board.get("_camera") as Camera2D
	var n := 15
	var min_x := float(0 - (n - 1)) * 32.0 - 32.0
	var max_x := float(n - 1) * 32.0 + 32.0
	var min_y := -16.0 - 48.0
	var max_y := float((n - 1) + (n - 1)) * 16.0 + 16.0 + 36.0
	var board_w := max_x - min_x
	var board_h := max_y - min_y
	var view_size := root.get_viewport().get_visible_rect().size
	var zoom := minf(view_size.x / board_w, view_size.y / board_h) * 0.94
	camera.zoom = Vector2(zoom, zoom)
	camera.position = Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
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
	zoom = camera.zoom.x if camera != null else zoom
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
