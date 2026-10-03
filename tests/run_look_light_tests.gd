extends SceneTree

## L7 light. The phone path stays flat. PC grades, rims, and cast light are warm.
## Run: godot --headless --path . -s res://tests/run_look_light_tests.gd

const LIGHT := preload("res://board/pc/look_light.gd")
const HUD := preload("res://ui/hud.gd")
const BUDGET := preload("res://vfx/vfx_budget.gd")
const NUMBER := preload("res://vfx/vfx_number.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_run()
	HUD.set_pc_chrome_override(-1)
	LIGHT.active = false
	print("Look light tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_phone_stays_flat()
	_test_outdoor_grade_and_rim()
	_test_dungeon_grade()
	_test_cast_light_is_warm_and_pc_only()
	_test_damage_numbers()
	_test_pawn_rim_follows_the_path()


func _host() -> Dictionary:
	var host := Node.new()
	host.name = "Host"
	root.add_child(host)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 1
	host.add_child(hud)
	var board := Node2D.new()
	board.name = "BoardView"
	host.add_child(board)
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	board.add_child(tiles)
	var jungle := Node2D.new()
	jungle.name = "JungleBackdrop"
	board.add_child(jungle)
	var units := Node2D.new()
	units.name = "Units"
	board.add_child(units)
	var light = LIGHT.new()
	light.name = "LookLight"
	board.add_child(light)
	return {"host": host, "hud": hud, "board": board, "tiles": tiles, "jungle": jungle, "units": units, "light": light}


func _test_phone_stays_flat() -> void:
	var tree := _host()
	var light = tree["light"]
	var hud: CanvasLayer = tree["hud"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	eq(hud.layer, 2, "PC grade sits under the HUD")
	HUD.set_pc_chrome_override(0)
	light.sync(tree["board"], true)
	eq(light.grade_color(), LIGHT.PHONE_GRADE, "the phone grade is white")
	eq(tree["board"].modulate, Color.WHITE, "the phone board is not tinted")
	eq(tree["tiles"].modulate, Color.WHITE, "the phone tiles stay untinted")
	eq(tree["jungle"].modulate, Color.WHITE, "the jungle plates stay untinted")
	eq(light.wash_visible(), false, "the phone path has no sun wash")
	eq(light.vignette_visible(), false, "the phone path has no dungeon vignette")
	eq(hud.layer, 1, "the phone HUD stays on its own layer")
	eq(LIGHT.active, false, "the phone path does not dress fighters")
	eq(light.note_events([{"type": "hit", "spell": "strike", "damage": 16, "to": Vector2i(4, 4)}]), 0, "a phone cast does not add shafts")
	eq(light.cast_count(), 0, "the phone path keeps no cast light")
	_free_host(tree)


func _test_outdoor_grade_and_rim() -> void:
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	var grade: Color = light.grade_color()
	eq(grade, LIGHT.OUTDOOR_GRADE, "outdoors use the warm grade")
	eq(tree["board"].modulate, Color.WHITE, "the outdoor tint does not cover the jungle parent")
	eq(tree["tiles"].modulate, LIGHT.OUTDOOR_GRADE, "the outdoor tint sits on the tiles")
	eq(tree["units"].modulate, LIGHT.OUTDOOR_GRADE, "the outdoor tint sits on the fighters")
	eq(tree["jungle"].modulate, Color.WHITE, "the jungle plates stay untinted outdoors")
	truthy(grade.r > grade.b, "the outdoor grade is warm")
	eq(light.wash_visible(), false, "the grade is not a fullscreen pass")
	eq(light.vignette_visible(), false, "outdoors do not vignette the room")
	var rim: Color = light.rim_color()
	truthy(rim.r > rim.b, "the outdoor rim is warm")
	eq(is_equal_approx(light.rim_strength(), LIGHT.OUTDOOR_RIM_STRENGTH), true, "outdoor rim strength")
	truthy(LIGHT.SHAFT_COLOR.r > LIGHT.SHAFT_COLOR.b and LIGHT.SHAFT_COLOR.b < 0.7, "shafts are warm, not cyan")
	truthy(LIGHT.FLOOR_COLOR.r > LIGHT.FLOOR_COLOR.g and LIGHT.FLOOR_COLOR.b < 0.55, "the floor pool is warm")
	_free_host(tree)


func _test_dungeon_grade() -> void:
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], true)
	var grade: Color = light.grade_color()
	eq(grade, LIGHT.DUNGEON_GRADE, "dungeons use the cinematic grade")
	truthy(grade.b > grade.r, "the dungeon grade is cool")
	truthy(_lum(grade) < _lum(LIGHT.OUTDOOR_GRADE), "the dungeon grade is darker than outdoors")
	eq(tree["tiles"].modulate, LIGHT.DUNGEON_GRADE, "the dungeon tint sits on the tiles")
	eq(tree["units"].modulate, LIGHT.DUNGEON_GRADE, "the dungeon tint sits on the fighters")
	eq(tree["jungle"].modulate, Color.WHITE, "the jungle plates stay untinted in a dungeon")
	eq(light.wash_visible(), false, "the dungeon does not add a fullscreen wash")
	eq(light.vignette_visible(), true, "the dungeon vignettes the room")
	truthy(light.rim_strength() > LIGHT.OUTDOOR_RIM_STRENGTH, "the dungeon rim is stronger")
	truthy(light.rim_color().r > light.rim_color().b, "the dungeon rim stays warm")
	_free_host(tree)


func _test_cast_light_is_warm_and_pc_only() -> void:
	var tree := _host()
	var light = tree["light"]
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	eq(light.note_events([{"type": "burn", "damage": 4, "to": Vector2i(1, 1)}]), 0, "a burn tick is not a cast")
	eq(light.note_events([{
		"type": "cast",
		"spell": "drop_shade",
		"to": Vector2i(3, 4),
	}]), 1, "a cast adds shafts and a floor pool")
	eq(light.cast_count(), 1, "one cast is live")
	var tint: Color = light.cast_tint()
	truthy(tint.r > tint.b, "a Gloam cast stays a warm pool, not a violet beam")
	eq(light.note_events([{"type": "hit", "spell": "strike", "damage": 16, "to": Vector2i(8, 7)}]), 1, "a hit adds cast light")
	HUD.set_pc_chrome_override(0)
	light.sync(tree["board"], false)
	eq(light.cast_count(), 0, "leaving PC clears the cast light")
	_free_host(tree)


func _test_damage_numbers() -> void:
	var number = NUMBER.new()
	root.add_child(number)
	HUD.set_pc_chrome_override(0)
	number.play({"text": "16", "kind": "damage"})
	eq(number._text, "16", "the phone number is the event text")
	eq(number._font_size, BUDGET.NUMBER_SIZE, "the phone damage number keeps the small size")
	HUD.set_pc_chrome_override(1)
	number.play({"text": "16", "kind": "damage"})
	eq(number._text, "16", "the PC number is still the event text")
	eq(number._font_size, LIGHT.PC_DAMAGE_FONT, "PC damage numbers are bigger")
	truthy(LIGHT.PC_DAMAGE_FONT > BUDGET.NUMBER_SIZE, "the PC size is above the phone size")
	number.play({"text": "10", "kind": "heal"})
	eq(number._font_size, BUDGET.NUMBER_SIZE, "heals stay the small size")
	number.free()


func _test_pawn_rim_follows_the_path() -> void:
	var tree := _host()
	var light = tree["light"]
	var pawn = (load("res://units/pawn.gd") as GDScript).new()
	pawn.class_id = "kestrel"
	pawn.facing = "E"
	pawn.alive = true
	tree["units"].add_child(pawn)
	HUD.set_pc_chrome_override(0)
	light.sync(tree["board"], false)
	pawn._sync_sprite()
	var sprite := pawn.get_node("Sprite") as Sprite2D
	eq(sprite.get_node_or_null("LookRim"), null, "the phone fighter has no rim")
	HUD.set_pc_chrome_override(1)
	light.sync(tree["board"], false)
	pawn._sync_sprite()
	var rim := sprite.get_node_or_null("LookRim") as Sprite2D
	truthy(rim != null and rim.visible, "the PC fighter takes the rim")
	truthy(rim.modulate.r > rim.modulate.b, "the rim is warm")
	pawn.alive = false
	light.sync(tree["board"], false)
	eq(rim.visible, false, "a downed fighter drops the rim")
	_free_host(tree)


func _lum(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _free_host(tree: Dictionary) -> void:
	var host: Node = tree["host"]
	host.free()


func eq(got: Variant, want: Variant, label: String) -> void:
	if got == want:
		_passed += 1
		return
	_failed += 1
	print("FAIL %s got=%s want=%s" % [label, str(got), str(want)])


func truthy(got: bool, label: String) -> void:
	eq(got, true, label)
