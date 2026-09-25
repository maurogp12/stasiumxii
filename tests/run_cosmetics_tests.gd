extends SceneTree

## Gender + palette path resolver, flag-off tray, and missing-art fallback.
## Run: godot --headless --path . -s res://tests/run_cosmetics_tests.gd

var _failed: int = 0
var _passed: int = 0
var _script: GDScript


func _initialize() -> void:
	_script = load("res://scenes/class_select.gd")
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var previous := SeatCosmetics.enabled()
	_test_path_resolver()
	_test_missing_art_falls_back()
	_test_prebaked_strips()
	_test_flag_off_hides_tray()
	_test_hotseat_picks_gender_and_palette()
	_test_pawn_spawn_uses_cosmetics()
	_test_no_combat_wire()
	SeatCosmetics.set_enabled(previous)
	SeatCosmetics.clear_hotseat()
	CosmeticStrips.clear_cache()
	CosmeticStrips._exists_override = Callable()
	print("Cosmetics tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_path_resolver() -> void:
	var custom := CosmeticStrips.custom_png_path("kestrel", "alt", "ember", "walk", "e")
	eq(custom, "res://art/export_2x/characters_custom/kestrel/alt/ember/anims/kestrel_walk_e.png", "kestrel alt ember east walk path")
	eq(CosmeticStrips.custom_png_path("ironjaw", "default", "moss", "attack", "s"), "res://art/export_2x/characters_custom/ironjaw/default/moss/anims/ironjaw_attack_s.png", "ironjaw moss south attack path")
	var stock := "res://art/export_2x/characters/kestrel/anims/kestrel_walk_e.png"
	SeatCosmetics.set_enabled(false)
	eq(CosmeticStrips.resolve_png_path_present("kestrel", "alt", "ember", "walk", "e", true), stock, "flag off keeps the live characters path")
	SeatCosmetics.set_enabled(true)
	eq(CosmeticStrips.resolve_png_path_present("kestrel", "alt", "ember", "walk", "e", true), custom, "flag on uses the custom path when the sheet exists")
	eq(CosmeticStrips.resolve_png_path_present("kestrel", "alt", "ember", "walk", "e", false), stock, "flag on still falls back when the sheet is missing")
	eq(CosmeticStrips.resolve_png_path_present("mender", "alt", "ember", "attack", "n", true), StripLibrary.export_png_path("mender", "attack", "n"), "mender stays on the stock path")
	eq(CosmeticStrips.resolve_png_path(" Kestrel ", "alt", "ember", "attack", "n"), "res://art/export_2x/characters_custom/kestrel/alt/ember/anims/kestrel_attack_n.png", "resolver finds the shipped attack sheet")
	eq(FileAccess.file_exists(custom), true, "shipped ember walk is on disk")
	var made := SeatCosmetics.make("ironjaw", "nope", "ember")
	eq(str(made.get("gender", "")), "default", "unknown gender becomes default")
	eq(str(made.get("palette", "")), "locked", "ember is not an ironjaw palette")
	eq(str(SeatCosmetics.make("ironjaw", "alt", "moss").get("palette", "")), "moss", "moss stays on ironjaw")
	eq(SeatCosmetics.gender_label("default"), "Locked default", "default gender label")
	eq(SeatCosmetics.gender_label("alt"), "Alt", "alt gender label")
	var src := FileAccess.get_file_as_string("res://data/seat_cosmetics.gd")
	eq(src.contains("Male"), false, "gender copy does not say Male")
	eq(src.contains("Female"), false, "gender copy does not say Female")
	var tray := FileAccess.get_file_as_string("res://scenes/cosmetic_tray.gd")
	eq(tray.contains("Male"), false, "tray does not say Male")
	eq(tray.contains("Female"), false, "tray does not say Female")


func _test_missing_art_falls_back() -> void:
	SeatCosmetics.set_enabled(true)
	CosmeticStrips.clear_cache()
	CosmeticStrips._exists_override = func(_path: String) -> bool: return false
	var spec := SeatCosmetics.make("kestrel", "alt", "storm")
	var stock := StripLibrary.frames_for("kestrel")
	eq(CosmeticStrips.frames_for(spec), stock, "missing custom sheets use the stock bank")
	eq(CosmeticStrips.resolve_png_path("kestrel", "alt", "storm", "walk", "w"), StripLibrary.export_png_path("kestrel", "walk", "w"), "missing custom path resolves to characters/")
	CosmeticStrips._exists_override = Callable()
	CosmeticStrips.clear_cache()
	SeatCosmetics.set_enabled(false)
	eq(CosmeticStrips.frames_for(spec), StripLibrary.frames_for("kestrel"), "flag off ignores a custom spec")


func _test_prebaked_strips() -> void:
	SeatCosmetics.set_enabled(true)
	CosmeticStrips.clear_cache()
	var count := 0
	for cls in ["kestrel", "ironjaw"]:
		for gender_id in SeatCosmetics.GENDERS:
			for palette_id in SeatCosmetics.palettes_for(cls):
				for kind in ["walk", "attack"]:
					for face in ["e", "s", "n", "w"]:
						var path := CosmeticStrips.custom_png_path(cls, gender_id, palette_id, kind, face)
						eq(FileAccess.file_exists(path), true, "sheet exists %s" % path)
						count += 1
	eq(count, 96, "v1 ships 96 strips")
	var spec := SeatCosmetics.make("kestrel", "alt", "ember")
	var frames := CosmeticStrips.frames_for(spec)
	truthy(frames != null, "ember bank loads")
	eq(frames == StripLibrary.frames_for("kestrel"), false, "ember bank is not the stock bank")
	eq(frames.get_frame_count("walk_e"), 6, "walk is 6 frames")
	eq(frames.get_animation_loop("walk_e"), true, "walk loops")
	eq(is_equal_approx(frames.get_animation_speed("walk_e"), 12.0), true, "walk is 12 fps")
	eq(frames.get_frame_count("attack_e"), 6, "attack is 6 frames")
	eq(frames.get_animation_loop("attack_e"), false, "attack is one-shot")
	eq(frames.get_frame_count("attack_e") > StripLibrary.ATTACK_IMPACT_FRAME, true, "attack reaches impact frame 3")
	var cell := frames.get_frame_texture("walk_e", 0)
	truthy(cell != null, "walk frame 0 has a texture")
	eq(cell.get_width(), 144, "cell width is 144 (864 / 6)")
	eq(cell.get_height(), 160, "cell height is 160")
	var jaw := CosmeticStrips.frames_for(SeatCosmetics.make("ironjaw", "alt", "locked"))
	truthy(jaw != null and jaw.has_animation("walk_n"), "ironjaw alt locked still has a walk")
	var storm := SeatCosmetics.swatch_colors("kestrel", "storm")
	truthy(storm.size() >= 1, "storm swatch comes from palettes.json")
	eq(storm[0], Color("#333841"), "storm cloth hex")


func _test_flag_off_hides_tray() -> void:
	SeatCosmetics.set_enabled(false)
	var picker := _picker()
	picker.choose_mode("hotseat")
	picker.choose_card("kestrel")
	eq(picker.phase_name(), "hotseat_p2", "flag off locks the class on the first click")
	eq(picker.cosmetics_controls_visible(), false, "flag off hides the gender and palette tray")
	picker.free()


func _test_hotseat_picks_gender_and_palette() -> void:
	SeatCosmetics.set_enabled(true)
	SeatCosmetics.clear_hotseat()
	var picker := _picker()
	picker.choose_mode("hotseat")
	picker.choose_card("kestrel")
	eq(picker.phase_name(), "hotseat_p1", "kestrel opens the tray before lock-in")
	eq(picker.cosmetics_controls_visible(), true, "tray is visible for kestrel")
	eq(picker.gender_button_text("default"), "Locked default", "default button label")
	eq(picker.gender_button_text("alt"), "Alt", "alt button label")
	eq(picker.gender_button("alt").custom_minimum_size.y >= 44.0, true, "gender target is a touch size")
	eq(picker.palette_chip_text("locked"), "locked", "locked chip is named")
	eq(picker.palette_chip_text("storm"), "storm", "storm chip is named")
	eq(picker.palette_chip_text("ember"), "ember", "ember chip is named")
	eq(picker.palette_chip_text("moss"), "", "ironjaw moss is not on the kestrel tray")
	picker.gender_button("alt").pressed.emit()
	eq(picker.draft_gender(), "alt", "alt press updates the draft")
	picker.palette_button("ember").pressed.emit()
	eq(picker.draft_palette(), "ember", "ember press updates the draft")
	var locked: Dictionary = picker.lock_in_pending()
	eq(bool(locked.get("ok", false)), true, "lock in accepts kestrel")
	eq(picker.phase_name(), "hotseat_p2", "P2 picks next")
	eq(picker.cosmetics_controls_visible(), false, "tray hides after lock-in")
	truthy(picker.prompt_text().contains("P2"), "prompt moves to P2")
	picker.choose_card("mender")
	eq(picker.phase_name(), "hotseat_done", "a class without cosmetics locks immediately")
	picker.free()
	var again := _picker()
	again.choose_mode("hotseat")
	again.choose_card("ironjaw")
	eq(again.palette_chip_text("slate"), "slate", "slate chip is named")
	eq(again.palette_chip_text("moss"), "moss", "moss chip is named")
	eq(again.palette_chip_text("storm"), "", "kestrel storm is not on the ironjaw tray")
	again.select_palette("moss")
	again.lock_in_pending()
	again.choose_card("kestrel")
	again.select_gender("default")
	again.select_palette("storm")
	again.lock_in_pending()
	var p0 := SeatCosmetics.for_seat(0, "ironjaw")
	var p1 := SeatCosmetics.for_seat(1, "kestrel")
	eq(str(p0.get("gender", "")), "default", "seat 0 gender")
	eq(str(p0.get("palette", "")), "moss", "seat 0 palette")
	eq(str(p1.get("palette", "")), "storm", "seat 1 palette")
	eq(SeatCosmetics.for_seat(0, "kestrel").is_empty(), true, "seat 0 cosmetics do not apply to the other class")
	again.free()


func _test_pawn_spawn_uses_cosmetics() -> void:
	SeatCosmetics.set_enabled(true)
	CosmeticStrips.clear_cache()
	SeatCosmetics.seal_hotseat([
		SeatCosmetics.make("kestrel", "alt", "ember"),
		SeatCosmetics.make("ironjaw", "alt", "slate"),
	])
	var kestrel := Pawn.new()
	root.add_child(kestrel)
	kestrel.apply_snapshot(_unit("kestrel", "E", 0), 0)
	var strip := kestrel.get_node("BodyStrip") as AnimatedSprite2D
	truthy(strip != null, "kestrel spawn binds a strip")
	eq(strip.sprite_frames, CosmeticStrips.frames_for(SeatCosmetics.make("kestrel", "alt", "ember")), "spawn uses the ember bank")
	eq(strip.sprite_frames == StripLibrary.frames_for("kestrel"), false, "spawn does not keep the stock bank")
	var jaw := Pawn.new()
	root.add_child(jaw)
	jaw.apply_snapshot(_unit("ironjaw", "W", 1), 1)
	var jaw_strip := jaw.get_node("BodyStrip") as AnimatedSprite2D
	eq(jaw_strip.sprite_frames, CosmeticStrips.frames_for(SeatCosmetics.make("ironjaw", "alt", "slate")), "ironjaw spawn uses slate")
	SeatCosmetics.set_enabled(false)
	var plain := Pawn.new()
	root.add_child(plain)
	plain.apply_snapshot(_unit("kestrel", "E", 0), 0)
	var plain_strip := plain.get_node("BodyStrip") as AnimatedSprite2D
	eq(plain_strip.sprite_frames, StripLibrary.frames_for("kestrel"), "flag off spawn uses the live characters bank")
	kestrel.free()
	jaw.free()
	plain.free()


func _test_no_combat_wire() -> void:
	for path in ["res://backend/net_session.gd", "res://backend/hit_bands.gd", "res://data/kits.gd", "res://backend/combat_sim.gd"]:
		var src := FileAccess.get_file_as_string(path)
		eq(src.contains("characters_custom"), false, "%s does not load custom strips" % path)
		eq(src.contains("COSMETICS_GENDER_PALETTE"), false, "%s does not read the cosmetics flag" % path)


func _unit(class_id: String, facing: String, seat: int) -> Dictionary:
	return {
		"pos": Vector2i(1, 1),
		"name": class_id,
		"class_id": class_id,
		"facing": facing,
		"seat": seat,
		"hp": 80,
		"max_hp": 80,
		"alive": true,
		"stun_remaining": 0,
	}


func _picker() -> Node:
	var picker: Node = (load("res://scenes/class_select.tscn") as PackedScene).instantiate()
	picker._auto_launch = false
	root.add_child(picker)
	return picker


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
