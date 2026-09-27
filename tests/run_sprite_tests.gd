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
	var shader := FileAccess.get_file_as_string("res://units/figure_read.gdshader")
	truthy(shader.contains("texture(TEXTURE, UV) * COLOR"), "figure read samples the texel and keeps modulate")
	eq(shader.contains("texture(TEXTURE, UV +"), false, "figure read does not sample a neighbor rim")
	eq(shader.contains("px.x * 3.0"), false, "figure read does not grow a 3px halo")


func _test_sprite_node_setup() -> void:
	var pawn := Pawn.new()
	get_root().add_child(pawn)
	pawn.apply_snapshot(_unit_dict("ironjaw", "W", 1), 1)
	var sprite := pawn.get_node("Sprite") as Sprite2D
	truthy(sprite != null, "pawn has one Sprite2D")
	eq(sprite.centered, true, "sprite is centered")
	eq(sprite.offset, Vector2(0, -72), "offset puts feet on the origin")
	eq(pawn.scale, Vector2.ONE, "presentation scale stays on the body, not the pawn")
	var ironjaw_scale := Pawn.sprite_scale_for("ironjaw")
	eq(sprite.scale, ironjaw_scale, "ironjaw combat scale is the shared cell")
	eq(ironjaw_scale, Pawn.SPRITE_SCALE, "ironjaw stays on the 0.5 cell")
	eq(Pawn.IRONJAW_COMBAT_SCALE, 1.0, "ironjaw locked combat scale is 1.0")
	eq(Pawn.presentation_mul("ironjaw"), 1.0, "ironjaw ships at scale 1.0")
	eq(Pawn.capped_presentation_mul(1.0), 1.0, "1.0 is the shared scale")
	eq(Pawn.capped_presentation_mul(1.08), 1.08, "1.08 is inside the optional nudge")
	eq(Pawn.capped_presentation_mul(1.10), 1.10, "1.10 is the top of the optional nudge")
	eq(Pawn.capped_presentation_mul(1.20), 1.0, "a one-class 1.20 bump is rejected")
	eq(Pawn.capped_presentation_mul(1.25), 1.0, "an open 1.25 scale is rejected")
	eq(Pawn.capped_presentation_mul(1.50), 1.0, "a larger bump is rejected")
	pawn._sample_hop(0.0)
	eq(sprite.position.y, 0.0, "ironjaw hop plants on Y=0 at the tile start")
	pawn._sample_hop(1.0)
	eq(sprite.position.y, 0.0, "ironjaw hop plants on Y=0 at the tile edge")
	eq(_visible_strip(pawn), null, "ironjaw idle does not leave the walk strip up")
	eq(sprite.visible, true, "ironjaw idle shows the soft plant")
	eq(sprite.texture, Pawn.idle_plant_texture("ironjaw", "W"), "ironjaw west idle is the soft plant")
	eq(sprite.modulate, Color.WHITE, "ironjaw idle is not Invisible")
	_assert_soft_plant("ironjaw", "W")
	_assert_ironjaw_feet(ironjaw_scale.y)
	eq(sprite.flip_h, false, "ironjaw E/W mirror is not flip_h")
	eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "sprite filter is Linear")
	eq(sprite.z_index, 0, "sprite z stays relative to the pawn")
	eq(sprite.z_as_relative, true, "sprite z is relative")
	eq(sprite.position, Vector2.ZERO, "sprite sits on the pawn origin")
	eq(sprite.texture, Pawn.idle_plant_texture("ironjaw", "W"), "texture follows the ironjaw plant facing")
	var bastion := Pawn.new()
	get_root().add_child(bastion)
	bastion.apply_snapshot(_unit_dict("bastion", "N", 0), 0)
	var bastion_sprite := bastion.get_node("Sprite") as Sprite2D
	eq(bastion_sprite.scale, Pawn.SPRITE_SCALE, "bastion matches the kestrel cell")
	eq(bastion_sprite.modulate, Color.WHITE, "a visible bastion is not Invisible")
	eq(sprite.modulate, Color.WHITE, "a visible ironjaw is not Invisible")
	eq(bastion_sprite.visible, true, "bastion idle shows the soft plant")
	eq(_visible_strip(bastion), null, "bastion idle does not leave the walk strip up")
	for class_id in ["kestrel", "gloam", "mender", "bastion", "ironjaw"]:
		eq(Pawn.sprite_scale_for(class_id), Pawn.SPRITE_SCALE, "%s uses the shared 0.5 cell" % class_id)
		eq(Pawn.presentation_mul(class_id), 1.0, "%s combat scale is 1.0" % class_id)
	eq(bastion_sprite.texture, Pawn.idle_plant_texture("bastion", "N"), "bastion north idle is the soft plant")
	_assert_soft_plant("bastion", "N")
	for class_id in ["bastion", "ironjaw"]:
		for face in ["E", "S", "N", "W"]:
			_assert_soft_plant(class_id, face)
	for class_id in ["kestrel", "gloam", "mender"]:
		eq(Pawn.idle_plant_texture(class_id, "E"), null, "%s stays on walk frame 0" % class_id)
	bastion.apply_snapshot(_unit_dict("bastion", "W", 0, false), 0)
	eq((bastion.get_node("Sprite") as Sprite2D).texture, Pawn.idle_plant_texture("bastion", "W"), "bastion west idle follows facing")
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
		eq(name_bottom <= pawn.head_hp_y() - 1.0, true, "%s name sits above the HP bar" % class_id)
		eq(name_bottom < ring_top, true, "%s name clears the seat ring" % class_id)
		var sprite := pawn.get_node("Sprite") as Sprite2D
		var visual_top := (sprite.offset.y - float(sprite.texture.get_height()) * 0.5) * sprite.scale.y
		eq(name_bottom <= visual_top + 0.01, true, "%s name clears the sprite" % class_id)
		var chrome := pawn.get_node("Chrome") as Node2D
		eq(chrome.get_parent(), pawn, "%s name chrome is not parented to the sprite" % class_id)
		eq(chrome.position, Vector2.ZERO, "%s name rests on the pawn" % class_id)
		var rested := origin.y
		pawn._sample_hop(0.5)
		eq(chrome.position, Vector2.ZERO, "%s hop leaves name chrome on the pawn" % class_id)
		eq(sprite.position.y, -ViewMotion.hop_crest_px(class_id), "%s hop moves the sprite by its mass" % class_id)
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


## Soft matte: alpha under 20 is gone, and the 20–254 band is still there.
func _assert_soft_plant(class_id: String, facing: String) -> void:
	var tex := Pawn.idle_plant_texture(class_id, facing)
	truthy(tex != null, "%s %s soft plant loads" % [class_id, facing])
	if tex == null:
		return
	eq(tex.get_width(), 144, "%s %s plant is 144 wide" % [class_id, facing])
	eq(tex.get_height(), 160, "%s %s plant is 160 tall" % [class_id, facing])
	var image := tex.get_image()
	truthy(image != null, "%s %s plant has pixels" % [class_id, facing])
	if image == null:
		return
	var dust := 0
	var soft := 0
	var solid := 0
	var cyan := 0
	var floor_a := 20.0 / 255.0
	for y in image.get_height():
		for x in image.get_width():
			var px := image.get_pixel(x, y)
			if px.a > 0.001 and px.a < floor_a:
				dust += 1
			elif px.a >= floor_a and px.a < 1.0:
				soft += 1
			elif px.a >= 1.0:
				solid += 1
			if px.a > 0.2 and px.g > px.r + 0.12 and px.b > px.r + 0.12 and px.b > 0.35:
				cyan += 1
	eq(dust, 0, "%s %s plant has no alpha under 20" % [class_id, facing])
	eq(soft > 0, true, "%s %s plant keeps the 20-254 alpha band" % [class_id, facing])
	eq(cyan, 0, "%s %s plant has no cyan pixels" % [class_id, facing])
	eq(solid > 1000, true, "%s %s plant has a readable body" % [class_id, facing])


func _visible_strip(pawn: Pawn) -> AnimatedSprite2D:
	for child in pawn.get_children():
		if child is AnimatedSprite2D and (child as AnimatedSprite2D).visible:
			return child as AnimatedSprite2D
	return null


## Walk frame 0 contact, same foot row StripLibrary pins. Scale grows from the
## pawn origin, so a foot near local y=0 stays on the diamond.
func _assert_ironjaw_feet(scale_y: float) -> void:
	var portrait := StripLibrary.idle_portrait("ironjaw")
	truthy(portrait != null, "ironjaw east walk frame 0 loads")
	if portrait == null:
		return
	var image := portrait.get_image()
	truthy(image != null and not image.is_empty(), "ironjaw walk cell has pixels")
	if image == null or image.is_empty():
		return
	var height := image.get_height()
	var foot_y := -1
	var head_y := height
	for y in range(height - 1, -1, -1):
		var hit := false
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.08:
				hit = true
				head_y = y
				break
		if hit and foot_y < 0:
			foot_y = y
	eq(foot_y >= 148 and foot_y <= 151, true, "ironjaw foot row stays on the shared anchor")
	eq(float(foot_y - head_y + 1) / float(height) >= 0.90, true, "ironjaw art-fill covers at least 90% of the cell")
	if foot_y < 0:
		return
	var local_foot := float(foot_y) - float(height) * 0.5 + Pawn.SPRITE_OFFSET.y
	var world_foot := local_foot * scale_y
	var shared_foot := local_foot * Pawn.SPRITE_SCALE.y
	eq(absf(world_foot) <= 3.0, true, "ironjaw feet stay on the diamond")
	eq(absf(world_foot - shared_foot) <= 1.5, true, "the roster read does not lift the plant off the diamond")


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
