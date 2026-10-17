extends SceneTree

## Stills of the modular Crosshaven (tile map + kit): the whole town, and
## close-ups with a hero stand-in at the hero's world height for scale.
## godot --path . -s res://tests/pc/capture_tile_city.gd -- --out=<dir>

const View := preload("res://scenes/world/crosshaven/tile_city_view.gd")

var _out := "user://tile_city"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var tc := TileCity.load_path()
	var bg := ColorRect.new()
	var v: Node2D = View.new()
	root.add_child(v)
	v.setup(tc)
	var cam := Camera2D.new()
	root.add_child(cam)
	cam.make_current()
	# hero stand-in (idle frame scaled to the hero's world height)
	var hero := Sprite2D.new()
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/characters/painted/ironjaw/ironjaw_idle_S.png"))
	hero.texture = ImageTexture.create_from_image(img)
	# the idle file is a strip: the first frame
	var fw := int(round(float(img.get_width()) / round(float(img.get_width()) / float(img.get_height()))))
	img = img.get_region(Rect2i(0, 0, fw, img.get_height()))
	hero.texture = ImageTexture.create_from_image(img)
	var used := img.get_used_rect()
	var k := float(tc.doc["hero_world_px"]) / float(used.size.y)
	hero.scale = Vector2.ONE * k
	hero.centered = false
	hero.offset = -Vector2(used.position.x + used.size.x * 0.5, used.end.y)
	hero.z_as_relative = false
	root.add_child(hero)
	var vp: Vector2 = root.get_visible_rect().size
	# whole town
	var lo := tc.cell_to_world(Vector2(0, tc.height))
	var hi := tc.cell_to_world(Vector2(tc.width, 0))
	var top := tc.cell_to_world(Vector2(0, 0))
	var bot := tc.cell_to_world(Vector2(tc.width, tc.height))
	var rect := Rect2(Vector2(lo.x, top.y), Vector2(hi.x - lo.x, bot.y - top.y))
	hero.visible = false
	await _shot(cam, rect.get_center(), minf(vp.x / rect.size.x, vp.y / rect.size.y) * 1.9, "50_tile_wide")
	hero.visible = true
	for g in tc.doc["gates"]:
		if str(g["id"]) != "S":
			continue
		var c: Array = g["outside"][g["outside"].size() - 1]
		var at := tc.cell_to_world(Vector2(float(c[0]), float(c[1])) + Vector2(2, 2))
		hero.position = at
		hero.z_index = View.z_at(at)
		await _shot(cam, at + Vector2(0, -120), 1.0, "51_tile_gate_S")
	for p in tc.pieces():
		if str(p["kind"]) == "fountain":
			var at2 := tc.piece_foot(p) + Vector2(60, 40)
			hero.position = at2
			hero.z_index = View.z_at(at2)
			await _shot(cam, at2 + Vector2(0, -150), 0.8, "52_tile_plaza")
	quit(0)


func _shot(cam: Camera2D, at: Vector2, zoom: float, name: String) -> void:
	cam.position = at
	cam.zoom = Vector2.ONE * zoom
	for i in 6:
		await process_frame
	var im := root.get_texture().get_image()
	im.save_png("%s/%s.png" % [_out, name])
	print("SHOT %s/%s.png" % [_out, name])
