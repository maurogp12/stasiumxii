extends SceneTree

## TA check capture (scratch only). Boot as tools/l9_v1_decor/capture_l9_decor.gd does, then:
## 1) full in-game frames zoom1 + fit; 2) backdrop-only at two pan positions (parallax);
## 3) leaves-only over black and over white (halo solve); 4) leaves on/off + cell polygons (overlay).
const BOARD := preload("res://board/pc/crosshaven_board.gd")
const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const PAIR := preload("res://tests/pc/pair_match.gd")
const TILE := preload("res://board/tile.gd")
const LEAVES := ["front_leaves_left", "front_leaves_right", "front_leaves_top", "front_leaves_bottom"]

var _out := "/tmp/ta_l9"
var _size := Vector2i(1280, 720)
var _logical := Vector2i(1280, 720)
var _hidden: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var t := str(arg)
		if t.begins_with("--out="): _out = t.trim_prefix("--out=")
		elif t.begins_with("--w="): _size.x = int(t.trim_prefix("--w="))
		elif t.begins_with("--h="): _size.y = int(t.trim_prefix("--h="))
	call_deferred("_go")

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var shot := await _boot()
	var board: Node2D = shot["board"]
	var jungle := board.get_node_or_null("JungleBackdrop")
	var tag := "%d" % _size.x
	var info := {"v1_ready": jungle.v1_ready() if jungle != null else false}
	_show_read(board)
	_set_zoom(board, 1.0)
	(await _grab(board)).save_png(_out.path_join("full_zoom1_%s.png" % tag))
	board._fit_board_camera()
	(await _grab(board)).save_png(_out.path_join("full_fit_%s.png" % tag))
	# --- parallax: backdrop only, leaves off, two pans
	_set_zoom(board, 1.0)
	var cam := board.get_node("BoardCamera") as Camera2D
	var tiles := board.get_node("Tiles") as Node2D
	tiles.visible = false
	for pawn in (board.get("pawns_by_seat") as Dictionary).values():
		(pawn as Node2D).visible = false
	_set_leaves(jungle, false)
	var layers := root.find_children("*", "CanvasLayer", true, false)
	for l in layers: l.visible = false
	var base := cam.position
	var pans := {"p0": Vector2.ZERO, "px": Vector2(150, 0), "py": Vector2(0, 100)}
	info["pans"] = {}
	for k in pans.keys():
		cam.position = base + pans[k]
		for _i in 4: await process_frame
		var img := await _grab_raw()
		img.save_png(_out.path_join("pan_%s_%s.png" % [k, tag]))
		var plate: Sprite2D = jungle.get("_plate_sprite")
		var far: Sprite2D = jungle.get("_backs")["back_far"].get_node("Art")
		var mid: Sprite2D = jungle.get("_backs")["back_mid"].get_node("Art")
		info["pans"][k] = {"cam": [cam.position.x, cam.position.y], "zoom": cam.zoom.x,
			"plate_pos": [plate.position.x, plate.position.y], "plate_visible": plate.visible,
			"far_art_visible": far.visible, "far_art_pos": [far.position.x, far.position.y],
			"mid_art_visible": mid.visible, "mid_art_pos": [mid.position.x, mid.position.y],
			"far_path": str(far.get_meta("slot_path", "")), "mid_path": str(mid.get_meta("slot_path", "")),
			"far_parallax": jungle._parallax_for("back_far"), "mid_parallax": jungle._parallax_for("back_mid")}
	cam.position = base
	for l in layers: l.visible = true
	tiles.visible = true
	for pawn in (board.get("pawns_by_seat") as Dictionary).values():
		(pawn as Node2D).visible = true
	_set_leaves(jungle, true)
	# --- leaves only over black / white, and on/off with cell polys
	info["cams"] = {}
	for cam_name in ["zoom1", "fit"]:
		if cam_name == "zoom1": _set_zoom(board, 1.0)
		else: board._fit_board_camera()
		for _i in 3: await process_frame
		var leafinfo := {}
		for s in LEAVES:
			var spr: Sprite2D = jungle.get("_sprites")[s]
			leafinfo[s] = {"modulate": [spr.modulate.r, spr.modulate.g, spr.modulate.b, spr.modulate.a],
				"path": str(spr.get_meta("slot_path", "")), "clip_visible": (jungle.get("_clips")[s] as Node2D).visible}
		info["cams"][cam_name] = {"leaves": leafinfo, "cells": _cell_polys(board)}
		for swing in [0, 1]:
			var t := (PI * 0.5 if swing == 0 else PI * 1.5)
			_isolate(board, jungle, true)
			jungle.preview_time(t / 0.9 - 0.2)
			for bg in [["k", Color.BLACK], ["w", Color.WHITE]]:
				RenderingServer.set_default_clear_color(bg[1])
				(await _grab_raw()).save_png(_out.path_join("leaves_%s_s%d_%s_%s.png" % [cam_name, swing, bg[0], tag]))
			_set_leaves(jungle, false)
			(await _grab_raw()).save_png(_out.path_join("leaves_%s_s%d_off_%s.png" % [cam_name, swing, tag]))
			_set_leaves(jungle, true)
			RenderingServer.set_default_clear_color(Color(0.3, 0.3, 0.3))
			_isolate(board, jungle, false)
	var f := FileAccess.open(_out.path_join("info_%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(info, " "))
	f.close()
	LIGHT.set_outdoor_preset(LIGHT.SHIPPED_OUTDOOR_PRESET)
	shot["main"].free()
	quit(0)

func _boot() -> Dictionary:
	HUD.set_pc_chrome_override(1)
	BOARD.set_suppressed(false)
	LIGHT.set_suppressed(false)
	LIGHT.set_outdoor_preset(LIGHT.PRESET_LIGHT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = _logical
	root.size = _size
	DisplayServer.window_set_size(_size)
	await process_frame
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var board: Node2D = main.get_node("BoardView")
	var sim: Node = root.get_node("CombatSim")
	for _i in 40:
		await process_frame
		if bool(board.get("_booted")): break
	sim.reset_match(PAIR.args("crosshaven"))
	board._rebuild_pawns()
	board._refresh()
	board._fit_board_camera()
	for _i in 6: await process_frame
	return {"main": main, "board": board, "sim": sim}

func _show_read(board: Node) -> void:
	board._paint_highlights()
	TILE.set_move_pulse_frozen(true)
	TILE.set_move_pulse_time(0.0)

func _set_zoom(board: Node, zoom: float) -> void:
	board._fit_board_camera()
	var cam := board.get_node("BoardCamera") as Camera2D
	var fit_zoom := cam.zoom.x
	var play_center := Vector2(float(board.VIEW_W) * 0.5, (float(board.PLAY_TOP) + float(board.PLAY_BOTTOM)) * 0.5)
	var view_center := Vector2(float(board.VIEW_W) * 0.5, float(board.VIEW_H) * 0.5)
	var shift := play_center - view_center
	var center := cam.position + shift / fit_zoom
	cam.zoom = Vector2(zoom, zoom)
	cam.position = center - shift / zoom

func _grab(board: Node) -> Image:
	LIGHT.set_outdoor_preset(LIGHT.PRESET_LIGHT)
	board._sync_look_light()
	_plant(board)
	for _i in 4: await process_frame
	_plant(board)
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	return image

func _plant(board: Node) -> void:
	for pawn in (board.get("pawns_by_seat") as Dictionary).values():
		if pawn.has_method("hold_idle"): pawn.hold_idle()

func _set_leaves(jungle: Node, on: bool) -> void:
	for name in LEAVES:
		var clip := jungle.get_node_or_null(name) as Node2D
		if clip != null:
			if not clip.has_meta("was_visible"): clip.set_meta("was_visible", clip.visible)
			clip.visible = on and bool(clip.get_meta("was_visible"))

func _cell_polys(board: Node) -> Array:
	var xf: Transform2D = board.get_viewport().get_canvas_transform()
	var k := float(_size.y) / float(_logical.y)
	var cells := []
	for cell in board.tiles.keys():
		var tile: Node2D = board.tiles[cell]
		var e := float(tile.get("elevation"))
		var parent := tile.get_parent() as Node2D
		var pts := []
		for lift in [e, 0.0]:
			var b := Vector2(float(cell.x - cell.y) * 32.0, float(cell.x + cell.y) * 16.0 - lift * 10.0)
			for off in [Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]:
				var p: Vector2 = xf * parent.to_global(b + off)
				pts.append([p.x * k, p.y * k])
		cells.append({"cell": [cell.x, cell.y], "elev": e, "pts": pts})
	return cells

func _isolate(board: Node, jungle: Node, on: bool) -> void:
	if not on:
		for item in _hidden:
			if is_instance_valid(item): item.visible = true
		_hidden.clear()
		return
	for child in board.get_children():
		if child == jungle or not (child is CanvasItem or child is CanvasLayer): continue
		if child.visible:
			child.visible = false
			_hidden.append(child)
	for child in jungle.get_children():
		if (child is CanvasItem) and not LEAVES.has(str(child.name)) and child.visible:
			child.visible = false
			_hidden.append(child)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layer.visible = false
			_hidden.append(layer)

func _grab_raw() -> Image:
	for _i in 3: await process_frame
	RenderingServer.force_draw()
	var image := root.get_viewport().get_texture().get_image()
	if image.get_width() != _size.x or image.get_height() != _size.y:
		image.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	return image
