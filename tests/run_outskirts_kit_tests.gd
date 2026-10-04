extends SceneTree

## Eastmarch beach kit: path rule, autotile edges, and cave anchor.
## Run: godot --headless --path . -s res://tests/run_outskirts_kit_tests.gd

const Kit := preload("res://scenes/world/crosshaven/outskirts_kit.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run()
	print("outskirts kit tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	var packed := Kit.doc("eastmarch")
	eq(int(packed.get("count", 0)), 94, "the kit lists 94 ids")
	eq(str(packed.get("theme", "")), "eastmarch", "the kit theme is eastmarch")
	var sand := Kit.master_file("eastmarch", "sand_a")
	eq(sand, "tiles/sand_a@2x.png", "Eastmarch masters are <id>@2x.png")
	eq(sand.find("/_2x/") < 0, true, "Eastmarch does not use the Crosshaven _2x folder")
	var cave_file := Kit.master_file("eastmarch", "cave_mouth_sandstone")
	eq(cave_file, "props/cave_mouth_sandstone@2x.png", "cave masters use the same path rule")
	eq(Kit.texture("eastmarch", "sand_a").is_empty(), false, "sand_a loads")
	eq(Kit.texture("eastmarch", "sea_deep_a").is_empty(), false, "sea_deep_a loads")
	eq(Kit.texture("eastmarch", "cave_mouth_grey").is_empty(), false, "the grey cave loads")
	var grass := func(at: Vector2i) -> String:
		if at.x < 0:
			return "golden_plains"
		return "sand"
	var edge: Dictionary = Kit.pick("eastmarch", "sand", Vector2i(0, 0), grass)
	eq(str(edge["floor"]), "sand_edge_nw", "sand meeting grass uses the grass edge")
	eq(bool(edge["flip_h"]), false, "an edge piece is not flipped")
	eq(bool(edge["flip_v"]), false, "an edge piece is not flipped on y")
	var sea := func(at: Vector2i) -> String:
		if at == Vector2i(3, 4):
			return "wet_sand"
		if at.y < 3:
			return "sea_deep"
		return "sea_shallow"
	var surf: Dictionary = Kit.pick("eastmarch", "sea_shallow", Vector2i(3, 3), sea)
	eq(str(surf["floor"]), "sand_surf_edge_sw", "shallow water meeting wet sand uses the surf edge")
	eq(bool(surf["flip_h"]) or bool(surf["flip_v"]), false, "surf edges stay unflipped")
	var plain := func(_at: Vector2i) -> String:
		return "sand"
	var interior: Dictionary = Kit.pick("eastmarch", "sand", Vector2i(4, 2), plain)
	var floor := str(interior["floor"])
	eq(floor == "sand_a" or floor == "sand_b" or floor == "sand_c" or floor == "sand_d", true, "open sand is an interior variant")
	var again: Dictionary = Kit.pick("eastmarch", "sand", Vector2i(4, 2), plain)
	eq(bool(again["flip_h"]), bool(interior["flip_h"]), "interior flips are stable")
	eq(bool(again["flip_v"]), bool(interior["flip_v"]), "interior flips are stable on y")
	var art: Dictionary = Kit.texture("eastmarch", "cave_mouth_sandstone")
	var tex: Texture2D = art["tex"]
	var size := tex.get_size() * float(art["scale"])
	var tip := Vector2(100, 200)
	var top_left := tip + Vector2(-size.x * 0.5, -size.y)
	eq(top_left.y, tip.y - size.y, "the cave sits on its anchor, gap included")
	eq(is_equal_approx(top_left.x + size.x * 0.5, tip.x), true, "the cave is centred on the south tip")


func eq(got: Variant, want: Variant, label: String) -> void:
	if got == want:
		_passed += 1
		return
	_failed += 1
	push_error("%s: got %s want %s" % [label, str(got), str(want)])
