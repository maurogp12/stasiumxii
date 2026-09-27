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
	truthy(shader.contains("COLOR = vec4(rgb, alpha) * COLOR"), "figure read keeps modulate")
	eq(shader.contains("px.x * 3.0"), false, "figure read does not grow a 3px halo")
	eq(shader.contains("px.x * 2.0"), false, "figure read does not grow a 2px halo")
	eq(shader.contains("0.0, 1.0, 1.0"), false, "figure read does not paint cyan")
	var ironjaw_read := Pawn.figure_read_for("ironjaw")
	var bastion_read := Pawn.figure_read_for("bastion")
	var kestrel_read := Pawn.figure_read_for("kestrel")
	eq(float(ironjaw_read["rim_px"]), 1.0, "ironjaw rim is one texel")
	eq(float(bastion_read["rim_px"]), 1.0, "bastion rim is one texel")
	eq(float(kestrel_read["rim_px"]), 0.0, "kestrel stays a straight sample")
	eq(float(kestrel_read["mid_mix"]), 0.0, "kestrel does not recolor")


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
	var ironjaw_idle := _visible_strip(pawn)
	truthy(ironjaw_idle != null, "ironjaw idle shows the walk sheet")
	eq(sprite.visible, false, "ironjaw idle hides the static turnaround")
	if ironjaw_idle != null:
		eq(String(ironjaw_idle.animation), "walk_w", "ironjaw west idle is walk_w")
		eq(ironjaw_idle.frame, 0, "ironjaw west idle is walk frame 0")
		eq(ironjaw_idle.flip_h, false, "ironjaw E/W mirror is not flip_h")
	eq(sprite.modulate, Color.WHITE, "ironjaw idle is not Invisible")
	_assert_walk_identity(pawn, "ironjaw", "W")
	_assert_ironjaw_feet(ironjaw_scale.y)
	eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "sprite filter is Linear")
	eq(sprite.z_index, 0, "sprite z stays relative to the pawn")
	eq(sprite.z_as_relative, true, "sprite z is relative")
	eq(sprite.position, Vector2.ZERO, "sprite sits on the pawn origin")
	var bastion := Pawn.new()
	get_root().add_child(bastion)
	bastion.apply_snapshot(_unit_dict("bastion", "N", 0), 0)
	var bastion_sprite := bastion.get_node("Sprite") as Sprite2D
	eq(bastion_sprite.scale, Pawn.SPRITE_SCALE, "bastion matches the kestrel cell")
	eq(bastion_sprite.modulate, Color.WHITE, "a visible bastion is not Invisible")
	eq(sprite.modulate, Color.WHITE, "a visible ironjaw is not Invisible")
	eq(bastion_sprite.visible, false, "bastion idle hides the static turnaround")
	var bastion_idle := _visible_strip(bastion)
	truthy(bastion_idle != null, "bastion idle shows the walk sheet")
	if bastion_idle != null:
		eq(String(bastion_idle.animation), "walk_n", "bastion north idle is walk_n")
		eq(bastion_idle.frame, 0, "bastion north idle is walk frame 0")
	_assert_walk_identity(bastion, "bastion", "N")
	for class_id in ["kestrel", "gloam", "mender", "bastion", "ironjaw"]:
		eq(Pawn.sprite_scale_for(class_id), Pawn.SPRITE_SCALE, "%s uses the shared 0.5 cell" % class_id)
		eq(Pawn.presentation_mul(class_id), 1.0, "%s combat scale is 1.0" % class_id)
	for class_id in ["bastion", "ironjaw"]:
		for face in ["E", "S", "N", "W"]:
			var body := Pawn.new()
			get_root().add_child(body)
			body.apply_snapshot(_unit_dict(class_id, face, 0), 0)
			_assert_walk_identity(body, class_id, face)
			body.free()
	for class_id in ["kestrel", "gloam", "mender"]:
		eq(Pawn.idle_plant_texture(class_id, "E"), null, "%s has no separate idle plant" % class_id)
	for class_id in ["ironjaw", "bastion"]:
		_assert_west_is_east_mirror(class_id)
		_assert_facing_is_own_sheet(class_id)
	bastion.apply_snapshot(_unit_dict("bastion", "W", 0, false), 0)
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


## Idle, the face snap, and the walk clip are one sheet. The soft plant is not shown.
func _assert_walk_identity(pawn: Pawn, class_id: String, facing: String) -> void:
	var strip := _visible_strip(pawn)
	truthy(strip != null, "%s %s idle is the walk strip" % [class_id, facing])
	if strip == null:
		return
	var face := facing.strip_edges().to_lower()
	var anim := "walk_%s" % face
	eq(String(strip.animation), anim, "%s %s idle animation is the facing walk" % [class_id, facing])
	eq(strip.frame, 0, "%s %s idle is frame 0" % [class_id, facing])
	eq(strip.flip_h, false, "%s %s is not flip_h" % [class_id, facing])
	eq(strip.scale, Pawn.sprite_scale_for(class_id), "%s %s keeps the shared scale" % [class_id, facing])
	var frames := strip.sprite_frames
	var shown := frames.get_frame_texture(anim, strip.frame)
	var bank := StripLibrary.frames_for(class_id)
	var locked := bank.get_frame_texture(anim, 0)
	truthy(shown != null and locked != null, "%s %s walk frame 0 loads" % [class_id, facing])
	if shown != null and locked != null:
		eq(shown.get_image().get_data(), locked.get_image().get_data(), "%s %s idle cell is the walk sheet" % [class_id, facing])
	var foreign := Pawn.idle_plant_texture(class_id, facing)
	if foreign != null and shown != null:
		eq(shown.get_image().get_data() == foreign.get_image().get_data(), false, "%s %s idle is not the soft plant" % [class_id, facing])
	var other := "E" if facing != "E" else "S"
	pawn.set_facing(other)
	var turned := _visible_strip(pawn)
	truthy(turned != null, "%s face snap keeps a body" % class_id)
	if turned != null:
		eq(turned.sprite_frames, frames, "%s face snap keeps the same frames" % class_id)
		eq(String(turned.animation), "walk_%s" % other.to_lower(), "%s face snap matches the pad" % class_id)
		eq(turned.frame, 0, "%s face snap plants frame 0" % class_id)
	pawn.set_facing(facing)


## North and south are their own three-quarter walks. A face pad must not
## show the east body, and the helm must not bob inside the cell. West is
## the mirror, checked separately. The v5 strips are not this contract.
func _assert_facing_is_own_sheet(class_id: String) -> void:
	var east_bytes := FileAccess.get_file_as_bytes(StripLibrary.walk_bytes_path(class_id, "e"))
	for face in ["n", "s"]:
		var held := FileAccess.get_file_as_bytes(StripLibrary.walk_bytes_path(class_id, face))
		var png := FileAccess.get_file_as_bytes(StripLibrary.export_png_path(class_id, "walk", face))
		eq(held == east_bytes, false, "%s walk_%s is not the east sheet" % [class_id, face])
		eq(png == held, true, "%s walk_%s png matches the packed bytes" % [class_id, face])
		var img := Image.new()
		eq(img.load_png_from_buffer(held), OK, "%s walk_%s loads" % [class_id, face])
		eq(img.get_width(), 864, "%s walk_%s is six cells" % [class_id, face])
		eq(img.get_height(), 160, "%s walk_%s is 160 tall" % [class_id, face])
		var tops: Array[int] = []
		var prev := PackedByteArray()
		for i in 6:
			var cell := img.get_region(Rect2i(i * 144, 0, 144, 160))
			var metrics := _cell_metrics(cell)
			eq(int(metrics.x) >= 148 and int(metrics.x) <= 151, true, "%s %s frame %d foot stays on the plant row" % [class_id, face, i])
			eq(int(metrics.z) >= 4500, true, "%s %s frame %d is a solid body" % [class_id, face, i])
			tops.append(int(metrics.y))
			var raw := cell.get_data()
			if i > 0:
				eq(raw == prev, false, "%s %s frame %d is a new pose" % [class_id, face, i])
			prev = raw
		var lo := tops[0]
		var hi := tops[0]
		for t in tops:
			lo = mini(lo, t)
			hi = maxi(hi, t)
		eq(hi - lo <= 6, true, "%s %s helm stays on one row" % [class_id, face])
	var north := FileAccess.get_file_as_bytes(StripLibrary.walk_bytes_path(class_id, "n"))
	var south := FileAccess.get_file_as_bytes(StripLibrary.walk_bytes_path(class_id, "s"))
	eq(north == south, false, "%s north and south are different walks" % class_id)
	StripLibrary.clear_cache()
	var bank := StripLibrary.frames_for(class_id)
	var east_cell := bank.get_frame_texture("walk_e", 0).get_image().get_data()
	eq(bank.get_frame_texture("walk_n", 0).get_image().get_data() == east_cell, false, "%s north playback is not the east cell" % class_id)
	eq(bank.get_frame_texture("walk_s", 0).get_image().get_data() == east_cell, false, "%s south playback is not the east cell" % class_id)


## foot x, helm y, opaque count. Alpha under 0.08 is empty.
func _cell_metrics(cell: Image) -> Vector3:
	var foot := -1
	var head := cell.get_height()
	var count := 0
	for y in range(cell.get_height() - 1, -1, -1):
		var hit := false
		for x in cell.get_width():
			if cell.get_pixel(x, y).a > 0.08:
				hit = true
				count += 1
				head = mini(head, y)
		if hit and foot < 0:
			foot = y
	return Vector3(foot, head, count)


func _assert_west_is_east_mirror(class_id: String) -> void:
	var east_img := Image.new()
	var west_img := Image.new()
	var east_bytes := FileAccess.get_file_as_bytes(StripLibrary.walk_bytes_path(class_id, "e"))
	var west_bytes := FileAccess.get_file_as_bytes(StripLibrary.walk_bytes_path(class_id, "w"))
	eq(east_img.load_png_from_buffer(east_bytes), OK, "%s east walk bytes load" % class_id)
	eq(west_img.load_png_from_buffer(west_bytes), OK, "%s west walk bytes load" % class_id)
	eq(east_img.get_width(), 864, "%s east walk is six cells" % class_id)
	eq(west_img.get_width(), 864, "%s west walk is six cells" % class_id)
	for i in 6:
		var east := east_img.get_region(Rect2i(i * 144, 0, 144, 160))
		var west := west_img.get_region(Rect2i(i * 144, 0, 144, 160))
		east.flip_x()
		eq(west.get_data() == east.get_data(), true, "%s west cell %d is the baked east mirror" % [class_id, i])


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
	eq(foot_y >= 148 and foot_y <= 151, true, "ironjaw v6g plant foot stays on the shared anchor")
	eq(float(foot_y - head_y + 1) / float(height) >= 0.80, true, "ironjaw v6g plant still fills most of the cell")
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
