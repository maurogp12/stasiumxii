extends SceneTree

## PC character roster, migration, and the character-select flow (P1, section 11).
## Run: godot --headless --path . -s res://tests/run_character_select_tests.gd

const Roster = preload("res://backend/pc_roster.gd")
const Progress = preload("res://backend/pc_progress.gd")
const VisualSettings = preload("res://backend/visual_settings.gd")
const SCREEN_SCENE := "res://scenes/pc/character_select/character_select.tscn"
const WORLD_SCENE := "res://scenes/world/crosshaven/crosshaven_world.tscn"
const DUNGEON_SCENE := "res://scenes/world/dungeon/dungeon_run.tscn"

const SCREEN_SRC := "res://scenes/pc/character_select/character_select.gd"
const WORLD_SRC := "res://scenes/world/crosshaven/crosshaven_world.gd"
const PROJECT := "res://project.godot"
const FORBIDDEN_ART := "res://art/pc/characters_3d"
const SCAN_ROOTS := ["res://scenes", "res://ui", "res://board", "res://units"]
const ALLOW_3D := "res://scenes/pc/character_select/"

var _failed := 0
var _passed := 0
var _had_save := false
var _save_backup := ""
var _had_visual := false
var _visual_backup := ""


func _initialize() -> void:
	_backup()
	_wipe_roster_files()
	Roster.take_world_entry()
	# Nodes added before the first frame do not run _ready yet.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_legacy_path_without_roster()
	_test_names()
	_test_appearance_rules()
	_test_radar_approved()
	_test_migration()
	_test_create_rename_delete_and_cap()
	_test_progress_bind_and_mirror()
	_test_launch_gate()
	_test_screen_flow()
	_test_world_bind_and_no_redirect()
	_test_containment()
	_test_sources()
	_test_no_3d()
	_test_puppet()
	_wipe_roster_files()
	Roster.take_world_entry()
	_restore()
	print("character select tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_legacy_path_without_roster() -> void:
	_wipe_roster_files()
	_write_legacy(4, 10, "Ironjaw", "crosshaven_stoneford", 2, 3)
	var hero = Progress.new()
	eq(hero.character_id, "", "no roster keeps the single save")
	eq(hero.level, 4, "legacy level still loads")
	eq(hero.hero_class, "Ironjaw", "legacy class still loads")
	eq(Roster.progress_path(""), "", "empty id has no progress file")
	eq(Roster.progress_path("."), "", "dot id is rejected")
	eq(Roster.progress_path(".."), "", "parent id is rejected")
	eq(Roster.progress_path("a/b"), "", "slash id is rejected")
	eq(Roster.progress_path("a\\b"), "", "backslash id is rejected")
	eq(Roster.progress_path("1"), "user://pc_progress_1.json", "numeric id is a progress file")
	eq(Roster.has_roster(), false, "legacy file is not a roster")
	eq(Roster.launch_screen(0), "class", "empty roster opens the class screen")
	eq(Roster.launch_screen(1), "list", "a character opens the list")
	eq(Roster.SLOT_LIMIT, 5, "five slots, one constant")


func _test_names() -> void:
	eq(Roster.validate_name("Al", [], "")["ok"], false, "two letters is too short")
	eq(Roster.validate_name("   Bo   ", [], "")["ok"], false, "trimmed length still counts")
	eq(Roster.validate_name("AbcdefghijklmnopQ", [], "")["ok"], false, "seventeen is too long")
	eq(Roster.validate_name("Ann1", [], "")["ok"], false, "digits are rejected")
	eq(Roster.validate_name("Ann_Bo", [], "")["ok"], false, "underscore is rejected")
	var spaced: Dictionary = Roster.validate_name("  Ann Bo  ", [], "")
	eq(spaced["ok"], true, "spaces inside a name are kept")
	eq(spaced["name"], "Ann Bo", "the name is trimmed")
	eq(Roster.validate_name("O'Neil", [], "")["ok"], true, "an apostrophe is allowed")
	eq(Roster.validate_name("Ana-Lu", [], "")["ok"], true, "a hyphen is allowed")
	var taken: Dictionary = Roster.validate_name("hero", [{"id": "1", "name": "Hero"}], "")
	eq(taken["ok"], false, "names are unique ignoring case")
	var same: Dictionary = Roster.validate_name("Hero", [{"id": "1", "name": "Hero"}], "1")
	eq(same["ok"], true, "renaming to the same name is allowed")


func _test_appearance_rules() -> void:
	var faces: Array = Roster.face_options()
	eq(faces.size() >= 3 and faces.size() <= 5, true, "face type is 3 to 5 options")
	eq(Roster.skin_options().size(), 8, "eight skin tones")
	eq(Roster.hair_options().size(), 8, "eight hair colours")
	eq(Roster.eye_options().size(), 8, "eight eye colours")
	var body := Roster.default_appearance()
	eq(body["gender"], "m", "default gender is male")
	eq(body["face"], "broad", "default face")
	eq(body["skin"], "#c68642", "default skin")
	eq(body["hair"], "#3b2414", "default hair")
	eq(body["eyes"], "#3d2b1f", "default eyes")
	eq(Roster.validate_appearance(body)["ok"], true, "defaults are a valid body")
	var bad := body.duplicate()
	bad["gender"] = "x"
	eq(Roster.validate_appearance(bad)["ok"], false, "gender is male or female")
	var custom := body.duplicate()
	custom["gender"] = "f"
	custom["hair"] = "#112233"
	custom["hair_custom"] = true
	custom["eyes"] = "#abcdef"
	custom["eyes_custom"] = true
	var checked: Dictionary = Roster.validate_appearance(custom)
	eq(checked["ok"], true, "custom hair and eyes are allowed")
	eq(checked["appearance"]["gender"], "f", "female is stored")
	eq(checked["appearance"]["hair"], "#112233", "custom hair hex is stored")
	eq(checked["appearance"]["eyes_custom"], true, "custom eyes flag is stored")
	var off_list := body.duplicate()
	off_list["hair"] = "#112233"
	eq(Roster.validate_appearance(off_list)["ok"], false, "a hair hex off the list needs the custom flag")
	var skin_custom := body.duplicate()
	skin_custom["skin"] = "#112233"
	eq(Roster.validate_appearance(skin_custom)["ok"], false, "skin has no custom colour")


func _test_radar_approved() -> void:
	var book: Dictionary = Roster.class_book()
	eq(book["radar_status"], "approved", "radar values are approved, not placeholders")
	eq(Roster.radar_values("kestrel"), [4, 5, 2, 1, 3], "kestrel radar")
	eq(Roster.radar_values("ironjaw"), [5, 1, 4, 1, 3], "ironjaw radar")
	eq(Roster.radar_values("mender"), [2, 3, 3, 5, 2], "mender radar")
	eq(Roster.radar_values("gloam"), [5, 2, 2, 1, 5], "gloam radar")
	eq(Roster.radar_values("bastion"), [2, 1, 5, 4, 2], "bastion radar")
	eq(book["axes"], ["Damage", "Range", "Survival", "Support", "Mobility"], "radar axis order")


func _test_migration() -> void:
	_wipe_roster_files()
	_write_legacy(9, 40, "Kestrel", "crosshaven_eastmarch", 8, 9)
	var result: Dictionary = Roster.migrate_legacy()
	eq(result["ok"], true, "migration succeeds")
	eq(result["migrated"], true, "the legacy save was migrated")
	eq(FileAccess.file_exists(Roster.LEGACY_SAVE), false, "the old single save is removed")
	eq(FileAccess.file_exists(Roster.progress_path("1")), true, "character 1 has a progress file")
	var roster: Dictionary = Roster.load_roster()
	eq(roster["last"], "1", "the migrated hero is last played")
	var chars: Array = roster["characters"]
	eq(chars.size(), 1, "one migrated character")
	var ch: Dictionary = chars[0]
	eq(ch["id"], "1", "migrated id is 1")
	eq(ch["name"], "Hero", "migrated name is Hero")
	eq(ch["class_id"], "kestrel", "class comes from the old save")
	eq(ch["level"], 9, "level comes from the old save")
	eq(ch["gender"], "m", "migrated body starts male")
	eq(ch["face"], "broad", "migrated face is the default")
	eq(ch.has("colors"), false, "armour colours are not on the character")
	var again: Dictionary = Roster.migrate_legacy()
	eq(again["migrated"], false, "a second migration does nothing")
	var progress_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Roster.progress_path("1")))
	eq(int(progress_doc["level"]), 9, "the progress copy keeps the level")
	eq(progress_doc["hero_class"], "Kestrel", "the progress copy keeps the class")
	eq(str(progress_doc["world"]["zone_id"]), "crosshaven_eastmarch", "the progress copy keeps the place")


func _test_create_rename_delete_and_cap() -> void:
	_wipe_roster_files()
	var look := Roster.default_appearance()
	look["gender"] = "f"
	look["face"] = "sharp"
	look["hair"] = "#010203"
	look["hair_custom"] = true
	var made: Dictionary = Roster.create_character("Mara", "mender", look)
	eq(made["ok"], true, "create accepts a female body")
	var ch: Dictionary = Roster.find_character(str(made["id"]))
	eq(ch["gender"], "f", "gender is saved on the roster")
	eq(ch["face"], "sharp", "face is saved on the roster")
	eq(ch["hair"], "#010203", "custom hair is saved on the roster")
	eq(ch["hair_custom"], true, "custom hair flag is saved")
	eq(ch["skin"], "#c68642", "skin is saved")
	eq(ch["eyes"], "#3d2b1f", "eyes are saved")
	eq(ch.has("colors"), false, "create does not store armour colours")
	var progress_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Roster.progress_path(str(made["id"]))))
	eq(str(progress_doc["world"]["zone_id"]), "crosshaven_crossroads", "a new character starts at the crossroads")
	eq(int(progress_doc["world"]["x"]), 22, "crossroads cell x")
	eq(int(progress_doc["world"]["y"]), 18, "crossroads cell y")
	eq(progress_doc["hero_class"], "Mender", "progress stores the display class")
	var renamed: Dictionary = Roster.rename_character(str(made["id"]), "Mara Voss")
	eq(renamed["ok"], true, "rename saves")
	eq(Roster.find_character(str(made["id"]))["name"], "Mara Voss", "the new name is on the roster")
	var clash: Dictionary = Roster.create_character("mara voss", "ironjaw", Roster.default_appearance())
	eq(clash["ok"], false, "a second character cannot reuse the name")
	var extras := ["Bram", "Cora", "Dunn", "Edda"]
	for char_name in extras:
		var extra: Dictionary = Roster.create_character(char_name, "ironjaw", Roster.default_appearance())
		eq(extra["ok"], true, "slot for %s opens (%s)" % [char_name, extra.get("reason", "")])
	eq((Roster.load_roster()["characters"] as Array).size(), Roster.SLOT_LIMIT, "the roster holds five")
	var full: Dictionary = Roster.create_character("Sixth", "bastion", Roster.default_appearance())
	eq(full["ok"], false, "the sixth character is refused")
	var removed: Dictionary = Roster.delete_character(str(made["id"]))
	eq(removed["ok"], true, "delete removes the character")
	eq(FileAccess.file_exists(Roster.progress_path(str(made["id"]))), false, "delete removes the progress file")
	eq(Roster.find_character(str(made["id"])).is_empty(), true, "the deleted id is gone")


func _test_progress_bind_and_mirror() -> void:
	_wipe_roster_files()
	var made: Dictionary = Roster.create_character("Pia", "gloam", Roster.default_appearance())
	var id := str(made["id"])
	var hero = Progress.new()
	eq(hero.character_id, "", "a new progress object still reads the legacy path")
	truthy(hero.bind_character(id), "bind loads the character file")
	eq(hero.character_id, id, "bind records the id")
	eq(hero.hero_class, "Gloam", "bind loads the class")
	hero.level = 6
	truthy(hero.save(), "a bound save writes the character file")
	eq(int(Roster.find_character(id)["level"]), 6, "saving mirrors the level onto the roster")
	eq(FileAccess.file_exists(Progress.SAVE_PATH), false, "a bound save does not write the legacy file")


func _test_launch_gate() -> void:
	eq(Roster.should_open_front_door(true, false, "", "", false), true, "a windowed world launch opens the screen")
	eq(Roster.should_open_front_door(false, false, "", "", false), false, "a child world stays in the world")
	eq(Roster.should_open_front_door(true, true, "", "", false), false, "headless stays in the world")
	eq(Roster.should_open_front_door(true, false, "tour", "", false), false, "a movie stays in the world")
	eq(Roster.should_open_front_door(true, false, "", "1", false), false, "an armed entry stays in the world")
	eq(Roster.should_open_front_door(true, false, "", "", true), false, "a dungeon return stays in the world")


func _test_screen_flow() -> void:
	_wipe_roster_files()
	_write_legacy(3, 0, "", "", 0, 0)
	var screen = _open_screen()
	eq(screen.screen_id, "list", "a migrated save opens the list")
	var hero: Dictionary = Roster.find_character("1")
	eq(hero["name"], "Hero", "the screen migrates the name Hero")
	eq(hero["class_id"], "ironjaw", "an empty class becomes Ironjaw")
	eq(FileAccess.file_exists(Roster.LEGACY_SAVE), false, "the screen removes the legacy file")
	screen.begin_rename()
	truthy(screen.confirm_rename("Hera"), "the player can rename Hero")
	eq(Roster.find_character("1")["name"], "Hera", "the rename is saved")
	var male_tex: Texture2D = screen.island_sprite.texture
	screen.press_create()
	eq(screen.screen_id, "class", "create on the list opens the class screen")
	eq(screen.back_button.visible, true, "back is visible once a character exists")
	eq(screen.uses_painted_fallback(), false, "Ironjaw male uses the test puppet")
	eq(screen.painted_art_letter(), "S", "the puppet idles on S")
	eq(screen.class_art.texture, null, "class art is not painted in this package")
	screen.select_class("kestrel")
	eq(screen.selected_class_id, "kestrel", "the class grid selects kestrel")
	eq(screen.radar.shown, [4, 5, 2, 1, 3], "the radar uses the approved kestrel values")
	eq(screen._role_label.text, "Ranged carry", "the role line comes from Koliseo")
	truthy(screen._lore_label.text.length() > 10, "lore is shown")
	var kestrel_tex: Texture2D = screen.pedestal_sprite.texture
	screen.set_gender("f")
	eq(screen.draft["gender"], "f", "the female toggle sets the draft")
	eq(screen.pedestal_sprite.texture, kestrel_tex, "female uses the same locked sprite")
	screen.set_gender("m")
	eq(screen.pedestal_sprite.texture, kestrel_tex, "male uses that same locked sprite")
	screen.select_class("bastion")
	eq(screen.radar.shown, [2, 1, 5, 4, 2], "switching class updates the radar")
	truthy(screen.pedestal_sprite.texture != kestrel_tex, "the pedestal sprite follows the class")
	screen.show_tab("appearance")
	eq(screen.tab, "appearance", "the appearance tab opens")
	eq(screen.appearance_page.visible, true, "the appearance page is shown")
	eq(screen.gameplay_page.visible, false, "the gameplay page hides")
	eq(screen.has_armour_swatches(), false, "there are no armour swatches")
	eq(screen.color_picker.presets_visible, false, "the custom picker hides presets")
	eq(screen.color_picker.edit_alpha, false, "the custom picker has no alpha")
	screen.set_face("narrow")
	screen.set_skin(str(Roster.skin_options()[2]))
	screen.set_hair("#445566", true)
	screen.set_eyes(str(Roster.eye_options()[3]), false)
	screen.set_gender("f")
	screen.press_create()
	eq(screen.naming, true, "create morphs into the name field")
	eq(screen.create_button.visible, false, "the create button hides while naming")
	eq(screen._name_row.visible, true, "the name row is shown")
	screen.name_field.text = "Nia"
	screen.press_cancel_name()
	eq(screen.naming, false, "the red X leaves naming")
	eq(screen.selected_class_id, "bastion", "cancel keeps the class")
	eq(screen.draft["gender"], "f", "cancel keeps the body")
	eq((Roster.load_roster()["characters"] as Array).size(), 1, "cancel creates nobody")
	screen.press_create()
	screen.name_field.text = "Nia"
	truthy(screen.press_confirm_name(), "the check creates the character")
	eq(screen.entered["reason"], "create", "create enters the world")
	eq(screen.entered["class_id"], "bastion", "create keeps the chosen class")
	eq(screen.entered["gender"], "f", "create keeps the gender")
	eq(screen.entered["face"], "narrow", "create keeps the face")
	eq(screen.entered["hair"], "#445566", "create keeps the custom hair")
	eq(screen.entered["hair_custom"], true, "create keeps the custom flag")
	eq(str(screen.entered["zone_id"]), "crosshaven_crossroads", "create spawns at the crossroads")
	eq(screen.auto_enter_world, false, "the test does not change scene")
	var created_id := str(screen.entered["id"])
	var saved: Dictionary = Roster.find_character(created_id)
	eq(saved["gender"], "f", "the screen saved female")
	eq(saved["eyes"], str(Roster.eye_options()[3]), "the screen saved the eye colour")
	screen.free()
	var list = _open_screen()
	eq(list.screen_id, "list", "a roster opens the list")
	eq(str(list._selected()["id"]), created_id, "last played is selected")
	eq(list.island_sprite.texture != null, true, "the list shows the locked sprite on the island")
	list.move_selection(-1)
	eq(str(list._selected()["name"]), "Hera", "up wraps onto the other row")
	eq(list.get_tree().get_nodes_in_group("charselect_puppet").size(), 1, "the list holds the Ironjaw puppet")
	list.press_play()
	eq(list.get_tree().get_nodes_in_group("charselect_puppet").size(), 0, "leaving the screen frees the puppet")
	eq(list.entered["reason"], "play", "play enters with the selected character")
	eq(list.entered["id"], "1", "play uses the highlighted id")
	eq(Roster.last_id(), "1", "play records last played")
	list.begin_delete()
	eq(list._delete_dialog.visible, true, "delete asks for the name")
	eq(list.confirm_delete("nope"), false, "a wrong name does not delete")
	truthy(list.confirm_delete("Hera"), "typing the name deletes")
	eq(Roster.find_character("1").is_empty(), true, "Hera is gone")
	list.free()
	_fill_roster()
	var full = _open_screen()
	eq(full.list_create.visible, false, "a full roster hides create")
	full.press_create()
	eq(full.screen_id, "class", "the class screen can still be opened")
	full.press_create()
	eq(full.naming, false, "a full roster does not open the name field")
	full._settings.set_performance(true)
	eq(full.performance_stage_scale(), 0.5, "performance stage scale is 0.5")
	eq(full._rain.emitting, false, "performance turns the rain off")
	eq(full._rain.visible, false, "performance hides the rain")
	eq(full.lightning_gap_range().x, 14.0, "performance lightning waits at least 14 seconds")
	eq(full._bolt.visible, false, "performance hides the bolt")
	full._settings.set_performance(false)
	full.free()
	if male_tex == null:
		eq(false, true, "the island sprite loaded")


func _test_world_bind_and_no_redirect() -> void:
	_wipe_roster_files()
	var made: Dictionary = Roster.create_character("Wyn", "kestrel", Roster.default_appearance())
	var id := str(made["id"])
	Roster.arm_world_entry(id)
	var world = load(WORLD_SCENE).instantiate()
	root.add_child(world)
	eq(world.get_node_or_null("Player") != null, true, "a child world does not redirect to the screen")
	eq(world.progress.character_id, id, "an armed entry binds that character")
	eq(world.progress.hero_class, "Kestrel", "the bound hero keeps the class")
	eq(Roster.peek_world_entry(), "", "the world consumes the armed entry")
	_assert_no_3d(world, "world scene")
	world.free()
	var dungeon = load(DUNGEON_SCENE).instantiate()
	root.add_child(dungeon)
	_assert_no_3d(dungeon, "dungeon scene")
	dungeon.free()


func _test_containment() -> void:
	var glbs: Array = []
	_collect_files("res://", ".glb", glbs)
	_collect_files("res://", ".gltf", glbs)
	eq(glbs.size(), 0, "this package has no glb or gltf")
	var scenes: Array = []
	for root_path in SCAN_ROOTS:
		_collect_files(root_path, ".tscn", scenes)
	var bad_scenes := 0
	for path in scenes:
		if str(path).begins_with(ALLOW_3D):
			continue
		var text := FileAccess.get_file_as_string(str(path))
		if _scene_text_has_3d(text):
			bad_scenes += 1
			print("3D scene: %s" % path)
	eq(bad_scenes, 0, "world, combat and dungeon scenes have no 3D nodes")
	var scripts: Array = []
	_collect_files("res://", ".gd", scripts)
	var bad_scripts := 0
	for path in scripts:
		var script_path := str(path)
		if script_path.begins_with(ALLOW_3D) or script_path == "res://tests/run_character_select_tests.gd":
			continue
		var text := FileAccess.get_file_as_string(script_path)
		if text.contains(FORBIDDEN_ART) or text.contains("art/pc/characters_3d"):
			bad_scripts += 1
			print("3D preload: %s" % script_path)
	eq(bad_scripts, 0, "scripts outside character select do not load 3D character art")


func _test_sources() -> void:
	var project := FileAccess.get_file_as_string(PROJECT)
	truthy(project.contains('run/main_scene="res://scenes/mobile_hub.tscn"'), "main scene stays the mobile hub")
	var src := FileAccess.get_file_as_string(SCREEN_SRC)
	truthy(src.contains("Roster.SLOT_LIMIT"), "the screen reads the roster slot constant")
	eq(src.find("const SLOT_LIMIT") < 0, true, "the screen does not declare another slot cap")
	eq(src.find("Primary") < 0, true, "no primary armour row")
	eq(src.find("Secondary") < 0, true, "no secondary armour row")
	eq(src.find("Accent") < 0, true, "no accent armour row")
	var world := FileAccess.get_file_as_string(WORLD_SRC)
	truthy(world.contains("should_open_front_door"), "the world opens the character screen on launch")
	truthy(world.contains("_bind_roster_hero"), "the world binds the roster character")


func _test_no_3d() -> void:
	var scenes: Array = []
	_collect_files("res://", ".tscn", scenes)
	var bad := 0
	for path in scenes:
		var text := FileAccess.get_file_as_string(str(path))
		if text.contains('type="Node3D"') or text.contains('type="Camera3D"') or text.contains('type="MeshInstance3D"') or text.contains('Light3D"') or text.contains('type="WorldEnvironment"'):
			bad += 1
			print("3D scene: %s" % path)
		if text.contains("own_world_3d = true"):
			bad += 1
			print("3D viewport: %s" % path)
	eq(bad, 0, "no 3D nodes and no 3D viewport anywhere")
	for suffix in [".glb", ".gltf", ".blend"]:
		var found: Array = []
		_collect_files("res://art", suffix, found)
		_collect_files("res://scenes", suffix, found)
		eq(found.size(), 0, "no %s under art or scenes" % suffix)
	var puppet_src := FileAccess.get_file_as_string("res://scenes/pc/character_select/puppet.gd")
	eq(puppet_src.find("Skeleton2D") < 0, true, "the puppet has no Skeleton2D")
	var shader := FileAccess.get_file_as_string("res://scenes/pc/character_select/recolour.gdshader")
	truthy(shader.contains("shader_type canvas_item"), "recolour is a canvas_item shader")
	truthy(shader.contains("dot(c.rgb, vec3(0.299, 0.587, 0.114))"), "the luminance weights are kept")
	truthy(shader.contains("lum * 2.0"), "the luminance tint is kept")
	eq(shader.find("shader_type spatial") < 0, true, "the spatial shader was not carried over")
	eq(shader.find("dye_") < 0, true, "gear dye is not in this shader")
	eq(FileAccess.file_exists("res://build_tools/pc_charselect/cut_puppet.py"), true, "cut_puppet.py is in the package")


func _test_puppet() -> void:
	var packed: PackedScene = load("res://scenes/pc/character_select/puppet.tscn")
	var puppet = packed.instantiate()
	root.add_child(puppet)
	eq(puppet.show_puppet("kestrel", "m"), false, "kestrel has no puppet")
	eq(puppet.show_puppet("ironjaw", "f"), false, "the female puppet is not in this package")
	truthy(puppet.show_puppet("ironjaw", "m"), "Ironjaw male loads")
	eq(puppet.facing, "S", "idle starts on S")
	eq(puppet.rig.get("fps", 0), 60, "the rig is 60 fps")
	eq(is_equal_approx(float(puppet.rig.get("turn", {}).get("sec", 0)), 0.18), true, "the turn is 0.18 s")
	eq(is_equal_approx(float(puppet.rig.get("overlap_px", 0)), 6.0), true, "joints overlap by about 6 px")
	var base_scale: float = puppet.scale_x_magnitude()
	puppet.apply_turn_sample(0.5)
	eq(is_equal_approx(puppet.scale_x_magnitude(), base_scale * 0.96), true, "the turn squashes to 0.96 at the midpoint")
	puppet.apply_turn_sample(1.0)
	eq(is_equal_approx(puppet.scale_x_magnitude(), base_scale), true, "the squash is gone at the end of the turn")
	puppet.turn(1)
	eq(puppet.facing, "Sm", "the first step mirrors S")
	puppet.snap_facing("S")
	puppet.turn_by_pixels(60.0)
	eq(puppet.facing, "Sm", "a 60 px drag mirrors S")
	puppet.snap_facing("Sm")
	eq(puppet._visible_root().scale.x < 0.0, true, "Sm is S mirrored")
	puppet.turn(1)
	eq(puppet.facing, "B", "the second step faces B")
	puppet.snap_facing("B")
	eq(puppet._visible_root().scale.x > 0.0, true, "B is the back view, not a mirror")
	eq(str(puppet.part_node("weapon").get_parent().name), "hand_r", "the weapon hangs off the holding hand")
	puppet.turn(1)
	eq(puppet.facing, "S", "the third step returns to S")
	_assert_blades(puppet)
	_assert_joints(puppet, "base")
	_assert_welds(puppet, "base")
	for family in ["cragmaw", "tyrantjaw", "pitmaw"]:
		for slot in ["head", "chest", "legs", "boots", "weapon"]:
			puppet.clear_slots()
			puppet.snap_facing("S")
			puppet.set_slot(slot, family)
			_assert_gear_covers(puppet, family, slot)
			_assert_joints(puppet, "%s %s" % [family, slot])
			_assert_gear_weld_matches(puppet, slot)
	puppet.clear_slots()
	puppet.snap_facing("S")
	puppet.seek_anim("select", 1.15)
	var dust: Node2D = puppet.part_node("dust")
	eq(dust.modulate.a > 0.5, true, "the select slam shows the dust puff")
	puppet.set_performance(true)
	truthy(puppet.texture_path("torso").contains("_half"), "performance mode uses the half-size parts")
	eq(puppet.secondary_on(), false, "performance mode turns secondary motion off")
	puppet.seek_anim("idle_core", 1.8)
	eq(puppet.part_node("torso").scale.y > 1.001, true, "the breath still plays on the half-size puppet")
	eq(is_equal_approx(puppet.part_node("hair").rotation, 0.0), true, "hair lag is off in performance mode")
	puppet.set_body_colors(Color.html("#c68642"), Color.html("#3b2414"), Color.html("#3a6ea5"))
	puppet.set_face("sharp")
	truthy(puppet.texture_path("head").contains("head_f4"), "the sharp face uses head_f4")
	puppet.release()
	eq(get_nodes_in_group("charselect_puppet").size(), 0, "release drops the puppet group")
	puppet.free()
	_wipe_roster_files()
	var screen = _open_screen()
	screen.select_class("kestrel")
	eq(screen.uses_painted_fallback(), true, "zero puppets for this class stays on the locked sprite")
	truthy(screen.fallback_note.text.contains("Coming soon"), "a missing puppet says coming soon")
	eq(screen.pedestal_sprite.visible, true, "the locked sprite is shown")
	screen.press_create()
	eq(screen.naming, true, "create still opens the name field with no puppet")
	screen.press_cancel_name()
	screen.select_class("ironjaw")
	screen.set_gender("m")
	eq(screen.uses_painted_fallback(), false, "Ironjaw male leaves the fallback")
	eq(screen.turn_left.visible, true, "turn arrows sit under the pedestal")
	screen.free()


func _assert_gear_covers(puppet, family: String, slot: String) -> void:
	var slots: Dictionary = puppet.rig.get("slots", {})
	var names: Array = slots.get(slot, [])
	for part_name in names:
		var gear: Image = puppet.part_image(str(part_name))
		puppet.clear_slots()
		var base: Image = puppet.part_image(str(part_name))
		puppet.set_slot(slot, family)
		if gear == null or base == null:
			eq(false, true, "%s %s %s loaded" % [family, slot, part_name])
			continue
		eq(gear.get_width(), base.get_width(), "%s %s shares the base crop" % [family, part_name])
		var differ := 0.0
		var counted := 0
		var missing := 0
		for y in base.get_height():
			for x in base.get_width():
				var bp: Color = base.get_pixel(x, y)
				if bp.a <= 0.5:
					continue
				counted += 1
				var gp: Color = gear.get_pixel(x, y)
				if gp.a <= 0.5:
					missing += 1
				else:
					differ += absf(gp.r - bp.r) + absf(gp.g - bp.g) + absf(gp.b - bp.b)
		eq(missing, 0, "%s %s has no base hole" % [family, part_name])
		eq(differ / float(maxi(counted, 1)) > 0.02, true, "%s %s is not the base paint" % [family, part_name])


func _assert_blades(puppet) -> void:
	puppet.snap_facing("S")
	var weapon_blade := _sibling_image(puppet, "weapon", "_blade.png")
	var hand_blade := _sibling_image(puppet, "hand_l", "_blade.png")
	_assert_blade_cover(puppet.part_image("weapon"), weapon_blade, "S weapon")
	_assert_blade_cover(puppet.part_image("hand_l"), hand_blade, "S left hand")
	puppet.snap_facing("B")
	var back: Image = puppet.part_image("weapon")
	eq(back.get_width() > 40 and back.get_height() > 40, true, "the back axe is not a handle stub")
	eq(_opaque_count(back) > 1500, true, "the back axe keeps its head")
	var back_hand: Image = puppet.part_image("hand_l")
	eq(_opaque_count(back_hand) > 1500, true, "the other back axe keeps its head")
	puppet.snap_facing("S")


func _assert_blade_cover(image: Image, blade: Image, label: String) -> void:
	if image == null or blade == null:
		eq(false, true, "%s blade images loaded" % label)
		return
	eq(image.get_width(), blade.get_width(), "%s matches the base_S.jpg crop" % label)
	eq(image.get_height(), blade.get_height(), "%s matches the base_S.jpg crop height" % label)
	var total := 0
	var missing := 0
	for y in blade.get_height():
		for x in blade.get_width():
			if blade.get_pixel(x, y).a <= 0.5:
				continue
			total += 1
			if image.get_pixel(x, y).a <= 0.5:
				missing += 1
	eq(total > 350, true, "%s head from base_S.jpg is a real blade" % label)
	eq(missing, 0, "%s keeps the base_S.jpg head" % label)


func _opaque_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count


func _sibling_image(puppet, part: String, suffix: String) -> Image:
	var path: String = puppet.texture_path(part)
	if path == "":
		return null
	var tex := load(path.trim_suffix(".png") + suffix) as Texture2D
	if tex == null:
		return null
	return tex.get_image()


func _assert_gear_weld_matches(puppet, slot: String) -> void:
	var family := str(puppet._worn.get(slot, ""))
	var slots: Dictionary = puppet.rig.get("slots", {})
	var names: Array = slots.get(slot, [])
	for part_name in names:
		puppet.set_slot(slot, family)
		puppet.snap_facing("S")
		var gear: Image = _sibling_image(puppet, str(part_name), "_weld.png")
		puppet.clear_slots()
		var base: Image = _sibling_image(puppet, str(part_name), "_weld.png")
		if gear == null or base == null:
			eq(false, true, "%s %s weld loaded" % [slot, part_name])
			continue
		eq(gear.get_width(), base.get_width(), "%s %s weld matches the base crop" % [slot, part_name])
		var differ := 0
		for y in base.get_height():
			for x in base.get_width():
				var ba := base.get_pixel(x, y).a > 0.5
				var ga := gear.get_pixel(x, y).a > 0.5
				if ba != ga:
					differ += 1
		eq(differ, 0, "%s %s weld is the same tuck as the base" % [slot, part_name])
	puppet.set_slot(slot, family)


func _assert_welds(puppet, label: String) -> void:
	for facing in ["S", "B"]:
		puppet.snap_facing(facing)
		var images := {}
		var welds := {}
		var weld_pts := {}
		for child in _JOINTS.keys():
			var child_name := str(child)
			var parent_name := str(_JOINTS[child])
			images[child_name] = puppet.part_image(child_name)
			images[parent_name] = puppet.part_image(parent_name)
			var weld: Image = _sibling_image(puppet, child_name, "_weld.png")
			welds[child_name] = weld
			weld_pts[child_name] = _weld_points(weld)
		for anim_name in ["idle", "select"]:
			var length: float = puppet.anim_length(anim_name)
			var t := 0.0
			while t <= length + 0.0001:
				puppet.seek_anim(anim_name, t)
				puppet.force_update_transform()
				for child in _JOINTS.keys():
					var child_name := str(child)
					var parent_name := str(_JOINTS[child])
					if not _weld_inside(puppet, images, welds, weld_pts[child_name], child_name, parent_name):
						eq(false, true, "%s weld outside %s %s %.2f" % [label, child_name, facing, t])
						return
				t += 1.0 / 60.0
	eq(true, true, "%s welds stay inside the painted silhouette" % label)


func _weld_points(weld: Image) -> Array:
	var points: Array = []
	if weld == null:
		return points
	for y in weld.get_height():
		for x in weld.get_width():
			if weld.get_pixel(x, y).a > 0.5:
				points.append(Vector2i(x, y))
	return points


func _weld_inside(puppet, images: Dictionary, welds: Dictionary, points: Array, child: String, parent: String) -> bool:
	var node: Node2D = puppet.part_node(child)
	var sprite: Sprite2D = puppet.sprite_of(child)
	if node == null or sprite == null:
		return false
	var child_img: Image = images.get(child, null)
	var parent_img: Image = images.get(parent, null)
	var child_weld: Image = welds.get(child, null)
	for point in points:
		var texel := Vector2(float(point.x) + 0.5, float(point.y) + 0.5)
		var world: Vector2 = node.global_transform * (sprite.position + texel * sprite.scale)
		var on_parent := _image_hits(puppet, parent, parent_img, null, world)
		var on_child := _image_hits(puppet, child, child_img, child_weld, world)
		if not on_parent and not on_child:
			return false
	return true


func _image_hits(puppet, part: String, image: Image, weld: Image, world: Vector2) -> bool:
	var node: Node2D = puppet.part_node(part)
	var sprite: Sprite2D = puppet.sprite_of(part)
	if node == null or sprite == null or image == null:
		return false
	var local: Vector2 = node.get_global_transform().affine_inverse() * world
	var tex: Vector2 = (local - sprite.position) / sprite.scale
	var x := int(floor(tex.x))
	var y := int(floor(tex.y))
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return false
	if image.get_pixel(x, y).a <= 0.5:
		return false
	if weld != null and x < weld.get_width() and y < weld.get_height() and weld.get_pixel(x, y).a > 0.5:
		return false
	return true


func _assert_joints(puppet, label: String) -> void:
	for facing in ["S", "B"]:
		puppet.snap_facing(facing)
		for anim_name in ["idle", "select"]:
			var length: float = puppet.anim_length(anim_name)
			var cache := _puppet_images(puppet)
			var t := 0.0
			while t <= length + 0.0001:
				puppet.seek_anim(anim_name, t)
				puppet.force_update_transform()
				for child in _JOINTS.keys():
					var node: Node2D = puppet.part_node(str(child))
					if node == null:
						eq(false, true, "%s missing %s" % [label, child])
						continue
					var parent := str(_JOINTS[child])
					if not _joint_closed(puppet, cache, str(child), parent, node.global_position):
						eq(false, true, "%s hole at %s/%s %s %.2f" % [label, child, parent, facing, t])
						return
				t += 1.0 / 60.0
	eq(true, true, "%s joints stay closed" % label)


func _puppet_images(puppet) -> Dictionary:
	var images := {}
	for child in _JOINTS.keys():
		images[str(child)] = puppet.part_image(str(child))
		images[str(_JOINTS[child])] = puppet.part_image(str(_JOINTS[child]))
	return images


func _joint_closed(puppet, cache: Dictionary, child: String, parent: String, origin: Vector2) -> bool:
	var points: Array[Vector2] = [origin]
	for i in 4:
		var angle := TAU * float(i) / 4.0
		points.append(origin + Vector2(cos(angle), sin(angle)) * 4.0)
	for point in points:
		if not _sprite_hits(puppet, cache, child, point) or not _sprite_hits(puppet, cache, parent, point):
			return false
	return true


func _sprite_hits(puppet, cache: Dictionary, part: String, world: Vector2) -> bool:
	var node: Node2D = puppet.part_node(part)
	var sprite: Sprite2D = puppet.sprite_of(part)
	var image: Image = cache.get(part, null)
	if node == null or sprite == null or image == null:
		return false
	var local: Vector2 = node.get_global_transform().affine_inverse() * world
	var tex: Vector2 = (local - sprite.position) / sprite.scale
	var x := int(floor(tex.x))
	var y := int(floor(tex.y))
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return false
	return image.get_pixel(x, y).a > 0.5


const _JOINTS := {
	"head": "torso",
	"upper_arm_l": "torso",
	"upper_arm_r": "torso",
	"lower_arm_l": "upper_arm_l",
	"lower_arm_r": "upper_arm_r",
	"hand_l": "lower_arm_l",
	"hand_r": "lower_arm_r",
	"thigh_l": "torso",
	"thigh_r": "torso",
	"shin_l": "thigh_l",
	"shin_r": "thigh_r",
	"foot_l": "shin_l",
	"foot_r": "shin_r",
	"weapon": "hand_r",
}


func _open_screen():
	var screen = load(SCREEN_SCENE).instantiate()
	screen.instant = true
	screen.auto_enter_world = false
	screen.auto_quit = false
	root.add_child(screen)
	return screen


func _fill_roster() -> void:
	_wipe_roster_files()
	for char_name in ["Asha", "Bram", "Cora", "Dunn", "Edda"]:
		var made: Dictionary = Roster.create_character(char_name, "ironjaw", Roster.default_appearance())
		if not bool(made.get("ok", false)):
			eq(false, true, "fill %s (%s)" % [char_name, made.get("reason", "")])


func _write_legacy(level: int, xp: int, hero_class: String, zone_id: String, x: int, y: int) -> void:
	var doc := {
		"level": level,
		"xp": xp,
		"hero_class": hero_class,
		"world": {"zone_id": zone_id, "x": x, "y": y},
	}
	var file := FileAccess.open(Roster.LEGACY_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc))


func _scene_text_has_3d(text: String) -> bool:
	var i := 0
	while true:
		var at := text.find("type=\"", i)
		if at < 0:
			break
		var start := at + 6
		var end := text.find("\"", start)
		if end < 0:
			break
		var typ := text.substr(start, end - start)
		if typ.ends_with("3D") or typ == "WorldEnvironment":
			return true
		i = end + 1
	return text.contains("own_world_3d = true") or text.contains("own_world_3d=true")


func _assert_no_3d(node: Node, label: String) -> void:
	eq(_count_3d(node), 0, "%s has no 3D node" % label)


func _count_3d(node: Node) -> int:
	var n := 0
	var typ := node.get_class()
	if typ.ends_with("3D") or typ == "WorldEnvironment":
		n += 1
	if node is SubViewport and (node as SubViewport).own_world_3d:
		n += 1
	for child in node.get_children():
		n += _count_3d(child)
	return n


func _collect_files(root_path: String, suffix: String, out: Array) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var path := root_path.path_join(name)
			if dir.current_is_dir():
				if name != ".godot" and name != "android" and name != "builds":
					_collect_files(path, suffix, out)
			elif name.ends_with(suffix):
				out.append(path)
		name = dir.get_next()
	dir.list_dir_end()


func _wipe_roster_files() -> void:
	_remove(Roster.ROSTER_PATH)
	_remove(Roster.LEGACY_SAVE)
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var pending: Array[String] = []
	while name != "":
		if name.begins_with("pc_progress"):
			pending.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	for file_name in pending:
		_remove("user://" + file_name)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _backup() -> void:
	_had_save = FileAccess.file_exists(Progress.SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(Progress.SAVE_PATH)
	_had_visual = FileAccess.file_exists(VisualSettings.STORE)
	if _had_visual:
		_visual_backup = FileAccess.get_file_as_string(VisualSettings.STORE)


func _restore() -> void:
	if _had_save:
		var file := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_save_backup)
	else:
		_remove(Progress.SAVE_PATH)
	if _had_visual:
		var visual := FileAccess.open(VisualSettings.STORE, FileAccess.WRITE)
		if visual != null:
			visual.store_string(_visual_backup)
	else:
		_remove(VisualSettings.STORE)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s" % msg)
	else:
		_passed += 1
