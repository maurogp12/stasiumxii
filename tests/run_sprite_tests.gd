extends SceneTree

## Sprite path, import, node setup, and non-damage flash kind.
## Run: godot --headless --path . -s res://tests/run_sprite_tests.gd

var _failed: int = 0
var _passed: int = 0
var _sim: Node


func _initialize() -> void:
	var script := load("res://backend/combat_sim.gd")
	_sim = script.new()
	_run()
	print("Sprite tests: %d passed, %d failed" % [_passed, _failed])
	_sim.free()
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_texture_paths_and_imports()
	_test_sprite_node_setup()
	_test_facing_follows_unit()
	_test_flash_kinds()
	_test_view_wires_flash_without_rules()
	_test_name_sits_above_the_sprite()
	_test_l5_hex_plate_and_scale()


func _test_texture_paths_and_imports() -> void:
	for class_id in SpellKits.LOCKED_ROSTER:
		for facing in ["N", "E", "S", "W"]:
			var path := Pawn.sprite_path(class_id, facing)
			var expected := "res://art/characters/%s/%s_%s.png" % [class_id, class_id, facing.to_lower()]
			eq(path, expected, "%s %s path" % [class_id, facing])
			eq(FileAccess.file_exists(path), true, "%s exists" % path)
			var imported := FileAccess.get_file_as_string(path + ".import")
			truthy(imported.contains("mipmaps/generate=false"), "%s mipmaps off" % path)
			truthy(imported.contains("compress/mode=0"), "%s lossless import" % path)
			truthy(imported.contains("process/fix_alpha_border=true"), "%s fix alpha border" % path)
			var tex := Pawn.sprite_texture(class_id, facing)
			truthy(tex != null, "%s loads" % path)
	eq(Pawn.sprite_path("nope", "Q"), "res://art/characters/kestrel/kestrel_e.png", "unknown class/facing falls back")
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	eq(pawn_src.contains("flip_h = true"), false, "sprites are not mirrored at runtime")
	truthy(pawn_src.contains("flip_h = false"), "flip_h stays off")
	truthy(pawn_src.contains("Vector2(0, -72)"), "offset is the shipped foot pivot")
	truthy(pawn_src.contains("Vector2(0.5, 0.5)"), "shipped scale is 0.5")


func _test_sprite_node_setup() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot(_unit_dict("ironjaw", "W", 1), 1)
	var sprite := pawn.get_node("Sprite") as Sprite2D
	truthy(sprite != null, "pawn has one Sprite2D")
	eq(sprite.centered, true, "sprite is centered")
	eq(sprite.offset, Vector2(0, -72), "offset puts feet on the origin")
	eq(sprite.scale, Vector2(0.5, 0.5), "ironjaw uses the shared scale (brute size stays in the art)")
	eq(sprite.flip_h, false, "ironjaw E/W mirror is not flip_h")
	eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "sprite filter is Linear")
	eq(sprite.z_index, 0, "sprite z stays relative to the pawn")
	eq(sprite.z_as_relative, true, "sprite z is relative")
	eq(sprite.position, Vector2.ZERO, "sprite sits on the pawn origin")
	eq(sprite.texture, Pawn.sprite_texture("ironjaw", "W"), "texture follows class and facing")
	var bastion := Pawn.new()
	get_root().add_child(bastion)
	bastion.apply_snapshot(_unit_dict("bastion", "N", 0), 0)
	var bastion_sprite := bastion.get_node("Sprite") as Sprite2D
	eq(bastion_sprite.scale, Vector2(0.5, 0.5), "bastion is not normalized")
	eq(bastion_sprite.texture, Pawn.sprite_texture("bastion", "N"), "bastion N placeholder still loads")
	bastion.apply_snapshot(_unit_dict("bastion", "W", 0, false), 0)
	eq((bastion.get_node("Sprite") as Sprite2D).texture, Pawn.sprite_texture("bastion", "W"), "bastion W placeholder still loads")
	var dead := bastion.get_node("Sprite") as Sprite2D
	eq(Color(dead.modulate.r, dead.modulate.g, dead.modulate.b, 1.0), Color(0.45, 0.45, 0.45, 1.0), "dead sprite stays grey")
	eq(dead.modulate.a < 0.05, true, "a dead snapshot dissolves instead of standing")
	eq(dead.position.y > 4.0, true, "a dead snapshot stays collapsed")
	eq(dead.scale.y < 0.35, true, "a dead snapshot stays squashed")
	pawn.free()
	bastion.free()


func _test_facing_follows_unit() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot(_unit_dict("kestrel", "E", 0), 0)
	for facing in ["N", "E", "S", "W"]:
		pawn.set_facing(facing)
		var sprite := pawn.get_node("Sprite") as Sprite2D
		eq(sprite.flip_h, false, "set_facing %s does not flip" % facing)
		eq(sprite.texture, Pawn.sprite_texture("kestrel", facing), "set_facing %s swaps the texture" % facing)
	pawn.free()


func _test_flash_kinds() -> void:
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"kestrel_pos": Vector2i(1, 1),
		"ironjaw_pos": Vector2i(4, 1),
		"kestrel_facing": "E",
		"ironjaw_facing": "W",
		"rolls": [1],
	})
	var shot: Dictionary = _sim.submit({"type": "cast", "spell": "mark_shot", "to": Vector2i(4, 1)})
	eq(Pawn.resolve_flash_kind(_first_hit(shot.get("events", []))), "damage", "Mark Shot stays the orange damage flash")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_hp": 40,
		"rolls": [1, 1],
	})
	var mend: Dictionary = _sim.submit({"type": "cast", "spell": "mend", "to": Vector2i(1, 1), "seat": 0})
	eq(Pawn.resolve_flash_kind(_first_hit(mend.get("events", []))), "support", "Mend is a heal flash")
	var tap: Dictionary = _sim.submit({"type": "cast", "spell": "pulse_tap", "to": Vector2i(1, 1), "seat": 0})
	eq(Pawn.resolve_flash_kind(_first_hit(tap.get("events", []))), "support", "Pulse Tap heal is a heal flash")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"mender_pulse": 2,
		"rolls": [1],
	})
	var ward: Dictionary = _sim.submit({"type": "cast", "spell": "ward", "to": Vector2i(1, 1), "seat": 0})
	eq(Pawn.resolve_flash_kind(_first_hit(ward.get("events", []))), "ward", "Ward is the shield flash")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(6, 6)],
		"rolls": [100],
	})
	var cleanse: Dictionary = _sim.submit({"type": "cast", "spell": "cleanse", "to": Vector2i(1, 1), "seat": 0})
	eq(Pawn.resolve_flash_kind(_first_hit(cleanse.get("events", []))), "support", "Cleanse is a non-damage flash")

	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"mender_pulse": 4,
		"mender_hp": 40,
		"rolls": [1, 1],
	})
	var ally: Dictionary = _sim.submit({"type": "cast", "spell": "heartstop", "to": Vector2i(1, 1), "seat": 0})
	eq(Pawn.resolve_flash_kind(_first_hit(ally.get("events", []))), "support", "ally Heartstop heals")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"skip_deploy": true,
		"classes": ["mender", "kestrel"],
		"positions": [Vector2i(1, 1), Vector2i(3, 1)],
		"kestrel_facing": "W",
		"mender_pulse": 4,
		"rolls": [1],
	})
	var foe: Dictionary = _sim.submit({"type": "cast", "spell": "heartstop", "to": Vector2i(3, 1), "seat": 0})
	eq(Pawn.resolve_flash_kind(_first_hit(foe.get("events", []))), "damage", "enemy Heartstop stays damage")

	eq(Pawn.resolve_flash_kind({"type": "hit", "spell": "mark_shot", "damage": -4}), "support", "negative damage is a heal flash")
	eq(Pawn.resolve_flash_kind({"type": "hit", "spell": "strike", "damage": 16, "shield": 20}), "damage", "a shield field on real damage stays orange")
	eq(Pawn.resolve_flash_kind({"type": "miss", "spell": "mend", "healed": 0, "damage": 0}), "", "a miss does not flash")


func _test_view_wires_flash_without_rules() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(view.contains("resolve_flash_kind"), "board_view picks the flash from the event")
	truthy(view.contains("flash_support"), "board_view plays the heal flash")
	truthy(view.contains("flash_ward"), "board_view plays the Ward flash")
	truthy(view.contains("flash_hit"), "real damage still flashes")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	eq(view.contains("randi"), false, "board_view still does not roll")
	var pawn_src := FileAccess.get_file_as_string("res://units/pawn.gd")
	eq(pawn_src.contains("Pulse"), false, "pawn does not invent Pulse")
	truthy(pawn_src.contains("STUN"), "pawn still draws STUN")
	truthy(pawn_src.contains("func set_facing"), "facing still updates on the pawn")


func _test_name_sits_above_the_sprite() -> void:
	var font := ThemeDB.fallback_font
	var ring_top := Pawn.SEAT_RING_CENTER.y - 10.5
	for class_id in SpellKits.LOCKED_ROSTER:
		var pawn := Pawn.new()
		get_root().add_child(pawn)
		pawn.apply_snapshot(_unit_dict(class_id, "E", 0), 0)
		var origin: Vector2 = pawn.name_label_origin()
		var width := font.get_string_size(pawn.unit_name, HORIZONTAL_ALIGNMENT_CENTER, -1, Pawn.NAME_FONT_SIZE).x
		eq(origin.x, -width * 0.5, "%s name is centered over the unit" % class_id)
		var name_bottom := origin.y + font.get_descent(Pawn.NAME_FONT_SIZE)
		var name_top := origin.y - font.get_ascent(Pawn.NAME_FONT_SIZE)
		eq(name_bottom <= Pawn.HEAD_HP_Y - 1.0, true, "%s name sits above the HP bar" % class_id)
		eq(name_bottom < ring_top, true, "%s name clears the seat ring" % class_id)
		var sprite := pawn.get_node("Sprite") as Sprite2D
		var visual_top := (sprite.offset.y - float(sprite.texture.get_height()) * 0.5) * sprite.scale.y
		eq(name_bottom <= visual_top + 0.01, true, "%s name clears the sprite" % class_id)
		var chrome := pawn.get_node("Chrome") as Node2D
		eq(chrome.get_parent(), pawn, "%s name chrome is not parented to the sprite" % class_id)
		eq(chrome.position, Vector2.ZERO, "%s name rests on the pawn" % class_id)
		var rested := origin.y
		pawn._sample_hop(0.5)
		eq(chrome.position.y, -ViewMotion.HOP_PX, "%s name rides the walk hop" % class_id)
		eq(sprite.position.y < -1.0, true, "%s hop moves the sprite" % class_id)
		eq(pawn.name_label_origin().y, rested, "%s name anchor stays put during a hop" % class_id)
		pawn._sample_attack(0.4, Vector2(20, 10))
		eq(chrome.position, Vector2.ZERO, "%s lunge does not move the name" % class_id)
		eq(sprite.position.length() > 1.0, true, "%s lunge moves the sprite" % class_id)
		pawn._sample_idle(0.0)
		eq(chrome.position, Vector2.ZERO, "%s idle bob does not move the name" % class_id)
		pawn.stunned = true
		pawn.burning = true
		var stun_bottom: float = pawn._badge_stack_bottom(font, Pawn.HEAD_HP_Y, pawn.name_baseline())
		eq(stun_bottom <= name_top, true, "%s stun badge stays above the name" % class_id)
		pawn.free()


func _test_l5_hex_plate_and_scale() -> void:
	eq(OverheadPlate.team_color(0), BoardTile.DEPLOY_P1, "P1 hex matches the deploy tint")
	eq(OverheadPlate.team_color(1), BoardTile.DEPLOY_P2, "P2 hex matches the deploy tint")
	var pts := OverheadPlate.hex_points(Pawn.SEAT_RING_CENTER, OverheadPlate.HEX_RX, OverheadPlate.HEX_RY)
	eq(pts.size(), 6, "the ground mark is a hex")
	for i in pts.size():
		var point: Vector2 = pts[i]
		var inside := absf(point.x) / float(BoardTile.TILE_WIDTH) * 2.0 + absf(point.y) / float(BoardTile.TILE_HEIGHT) * 2.0
		truthy(inside < 1.0, "hex vertex %d stays inside the cell (%.3f)" % [i, inside])
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot(_unit_dict("kestrel", "E", 0), 0)
	var plate := pawn.get_node("Chrome/OverheadPlate") as OverheadPlate
	truthy(plate != null, "the plate is its own node")
	eq(is_equal_approx(plate.shown_ratio(), 1.0), true, "a full snapshot fills the bar")
	eq(plate.snapshot_life(), 80, "the plate shows the snapshot number")
	var hurt := _unit_dict("kestrel", "E", 0)
	hurt["hp"] = 32
	plate.sync_from_unit(hurt)
	eq(plate.snapshot_life(), 32, "the number follows the snapshot at once")
	eq(is_equal_approx(plate.target_ratio(), 32.0 / 80.0), true, "the bar aims at the snapshot")
	eq(is_equal_approx(plate.shown_ratio(), 1.0), true, "damage does not pop the bar")
	plate.tick(0.08)
	truthy(plate.shown_ratio() < 1.0 and plate.shown_ratio() > plate.target_ratio(), "the bar drains toward the snapshot")
	for _step in 40:
		plate.tick(0.05)
	eq(is_equal_approx(plate.shown_ratio(), plate.target_ratio()), true, "the bar settles on the snapshot")
	var foe := Pawn.new()
	get_root().add_child(foe)
	foe.apply_snapshot(_unit_dict("ironjaw", "W", 1), 1)
	eq(OverheadPlate.team_color(foe.seat), OverheadPlate.TEAM_P2, "seat 1 uses the red ring")
	var sprite := pawn.get_node("Sprite") as Sprite2D
	var body := Vector2(float(sprite.texture.get_width()), float(sprite.texture.get_height())) * sprite.scale
	var tall := body.y / float(BoardTile.TILE_HEIGHT)
	var wide := body.x / float(BoardTile.TILE_WIDTH)
	truthy(tall >= 2.0 and tall <= 3.0, "chibi height is two to three cells (%.2f)" % tall)
	truthy(wide >= 0.9 and wide <= 1.4, "chibi width is about one cell (%.2f)" % wide)
	eq(Pawn.NAME_FONT_SIZE, 7, "the name is about 60% of the old 12")
	truthy(OverheadPlate.BAR_H >= 5.0 and OverheadPlate.BAR_H <= 6.0, "the bar is 5 to 6 px at 1x")
	eq(OverheadPlate.BAR_RIM, 1.0, "the bar has a 1 px rim")
	truthy(plate.plate_width() <= sprite.texture.get_width() * sprite.scale.x * 1.2 + 0.01, "the plate stays within 1.2 times the sprite")
	var foe_sprite := foe.get_node("Sprite") as Sprite2D
	var foe_plate := foe.get_node("Chrome/OverheadPlate") as OverheadPlate
	truthy(foe_plate.plate_width() <= foe_sprite.texture.get_width() * foe_sprite.scale.x * 1.2 + 0.01, "Ironjaw's plate stays within 1.2 times the sprite")
	truthy(plate.local_rect().encloses(plate.number_rect()), "the number sits inside the plate")
	truthy(foe_plate.local_rect().encloses(foe_plate.number_rect()), "Ironjaw's number sits inside the plate")
	var full_ink := plate.fill_color()
	eq(full_ink, OverheadPlate.TEAM_P1, "a healthy bar uses the team colour")
	var low := _unit_dict("kestrel", "E", 0)
	low["hp"] = 16
	plate.sync_from_unit(low)
	truthy(plate.target_ratio() < OverheadPlate.LOW_LIFE, "16 of 80 is under 30%")
	var low_ink := plate.fill_color()
	eq(low_ink, OverheadPlate.WARN_AMBER, "20% life is full amber")
	var mid := _unit_dict("kestrel", "E", 0)
	mid["hp"] = 20
	plate.sync_from_unit(mid)
	var mid_ink := plate.fill_color()
	truthy(mid_ink != OverheadPlate.TEAM_P1 and mid_ink != OverheadPlate.WARN_AMBER, "25% life is between the team colour and amber")
	var critical := _unit_dict("kestrel", "E", 0)
	critical["hp"] = 8
	plate.sync_from_unit(critical)
	plate._pulse = 0.0
	var pulse_low := plate.fill_color()
	plate._pulse = 0.25
	var pulse_high := plate.fill_color()
	truthy(not is_equal_approx(pulse_low.r, pulse_high.r), "life under 15% pulses the warning")
	plate.sync_from_unit(low)
	pawn.position = BoardVisualSort.cell_to_local(Vector2i(7, 7))
	foe.position = BoardVisualSort.cell_to_local(Vector2i(8, 7))
	var pair: Array[OverheadPlate] = [plate, foe_plate]
	OverheadPlate.layout_now(pair)
	eq(plate.world_rect().intersects(foe_plate.world_rect()), false, "adjacent plates do not overlap after layout")
	truthy(foe_plate.z_index > plate.z_index, "the front plate draws on top")
	plate.ease_lift(1.0)
	truthy(plate.lift() < plate._lift_goal + 12.0, "a hitch does not throw the plate")
	var parked := OverheadPlate.new()
	parked._lift = 0.0
	parked._lift_goal = 30.0
	parked.ease_lift(1.0)
	truthy(parked.lift() > 0.0 and parked.lift() <= OverheadPlate.LIFT_STEP_CAP, "one frame only nudges the plate")
	parked.free()
	truthy(Pawn.ACTIVE_RING_RY > OverheadPlate.HEX_RY + 3.0, "the yellow ring clears the hex vertically")
	truthy(Pawn.ACTIVE_RING_RX > OverheadPlate.HEX_RX + 6.0, "the yellow ring clears the hex sideways")
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.contains("hp"), false, "board_view still does not mention hp")
	truthy(FileAccess.file_exists("res://units/overhead_plate.gd"), "the plate script is units/overhead_plate.gd")
	pawn.free()
	foe.free()


func _unit_dict(class_id: String, facing: String, seat: int, living: bool = true) -> Dictionary:
	return {
		"pos": Vector2i(2, 2),
		"name": SpellKits.display_name(class_id),
		"class_id": class_id,
		"facing": facing,
		"seat": seat,
		"hp": 80 if living else 0,
		"max_hp": 80,
		"alive": living,
		"stun_remaining": 0,
	}


func _first_hit(events: Array) -> Dictionary:
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "hit":
			return event
	return {}


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s  (got %s)" % [msg, value])
	else:
		_passed += 1
