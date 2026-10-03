extends SceneTree

## Locked down-right walks for the five world classes. Run:
##   godot --headless --path . -s res://tests/run_locked_s_walk_tests.gd

const Strips := preload("res://scenes/world/crosshaven/world_strips.gd")

var passed := 0
var failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var expect := {
		"ironjaw": {"size": Vector2i(161, 155), "scale": 0.33, "pivot": Vector2(-5.45, -76.5), "speed": 31.68, "others": 8},
		"gloam": {"size": Vector2i(135, 160), "scale": 0.33219, "pivot": Vector2(-39.33, -76.99), "speed": 16.0, "others": 12},
		"kestrel": {"size": Vector2i(116, 160), "scale": 0.33892, "pivot": Vector2(-38.5, -77.95), "speed": 16.0, "others": 12},
		"bastion": {"size": Vector2i(132, 151), "scale": 0.34385, "pivot": Vector2(-39.33, -74.38), "speed": 16.0, "others": 12},
		"mender": {"size": Vector2i(90, 179), "scale": 0.29857, "pivot": Vector2(-27.1, -87.71), "speed": 16.0, "others": 12},
	}
	for cls in expect:
		var spec: Dictionary = expect[cls]
		var strips = Strips.new()
		strips.load_class(str(cls))
		var cell: Vector2i = spec["size"]
		check(strips.has_locked_walk("e"), "%s east is the locked sheet" % cls)
		check(strips.frame_count("walk", "e") == 12, "%s east walk is 12 frames" % cls)
		check(strips.frame_size_of("walk", "e") == cell, "%s east cell is %s" % [cls, cell])
		check(is_equal_approx(strips.fps_of("walk", "e"), 12.0 / 0.70), "%s plays at 12/0.70 fps" % cls)
		check(is_equal_approx(1.0 / strips.fps_of("walk", "e"), 0.70 / 12.0), "%s frame is 58.33 ms" % cls)
		check(is_equal_approx(strips.speed_of("walk", "e"), float(spec["speed"])), "%s east speed stays %s" % [cls, spec["speed"]])
		check(is_equal_approx(strips.draw_scale("walk", "e"), float(spec["scale"])), "%s scale" % cls)
		check(strips.draw_pivot("walk", "e").is_equal_approx(spec["pivot"]), "%s pivot %s" % [cls, spec["pivot"]])
		for dir in ["n", "s", "w"]:
			check(not strips.has_locked_walk(dir), "%s %s is not the locked sheet" % [cls, dir])
			check(strips.frame_count("walk", dir) == int(spec["others"]), "%s walk_%s frame count" % [cls, dir])
			check(strips.frame_size_of("walk", dir) == Vector2i(144, 160), "%s walk_%s stays 144x160" % [cls, dir])
		var sheet := strips.texture("walk", "e").get_image()
		var src_tex := load("res://art/characters/world/%s/locked_s/%s_walk_S_f00.png" % [cls, cls]) as Texture2D
		var src := src_tex.get_image()
		var frame := sheet.get_region(Rect2i(0, 0, cell.x, cell.y))
		check(_same_image(frame, src), "%s f00 pixels match the delivered frame" % cls)
		var last_src := load("res://art/characters/world/%s/locked_s/%s_walk_S_f11.png" % [cls, cls]) as Texture2D
		var last := sheet.get_region(Rect2i(11 * cell.x, 0, cell.x, cell.y))
		check(_same_image(last, last_src.get_image()), "%s f11 pixels match the delivered frame" % cls)
	var tall = Strips.new()
	tall.load_class("ironjaw_tall")
	check(not tall.has_locked_walk("e"), "ironjaw_tall east stays the painted strip")
	check(tall.frame_count("walk", "e") == 6, "ironjaw_tall east is still 6 frames")
	check(is_equal_approx(tall.speed_of("walk", "e"), 31.68), "ironjaw_tall east speed stays 31.68")
	print("locked S walk tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _same_image(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return false
	if a.get_format() != Image.FORMAT_RGBA8:
		a.convert(Image.FORMAT_RGBA8)
	if b.get_format() != Image.FORMAT_RGBA8:
		b.convert(Image.FORMAT_RGBA8)
	return a.get_data() == b.get_data()
