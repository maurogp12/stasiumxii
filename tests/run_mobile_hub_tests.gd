extends SceneTree

## Mobile hub shell. Koliseo opens class select. Each Stasis door opens the
## mobile dungeon run for that biome (not the coming-soon stub).
## Run: godot --headless --path . -s res://tests/run_mobile_hub_tests.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	# _ready does not run for nodes added before the first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_boot_scene()
	_test_cli_still_skips_to_koliseo_route()
	_test_hub_doors()
	_test_stasis_runs()
	_test_sources_leave_combat_alone()
	print("Mobile hub tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_boot_scene() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	truthy(project.contains('run/main_scene="res://scenes/mobile_hub.tscn"'), "main scene is the mobile hub")
	truthy(project.contains("window/size/viewport_width=960"), "viewport width stays 960")
	truthy(project.contains("window/size/viewport_height=720"), "viewport height stays 720")
	truthy(project.contains('window/stretch/mode="canvas_items"'), "stretch mode stays canvas_items")
	truthy(project.contains('window/stretch/aspect="expand"'), "stretch aspect stays expand")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	truthy(preset.contains('name="Android"'), "Android export preset is still named Android")
	truthy(preset.contains("com.maurogp12.stasiumxii.mobile"), "Android package id is unchanged")
	truthy(FileAccess.file_exists("res://scenes/class_select.tscn"), "class select scene remains")
	truthy(FileAccess.file_exists("res://scenes/mobile_hub.tscn"), "hub scene exists")
	truthy(FileAccess.file_exists("res://scenes/stasis_run.tscn"), "stasis run scene exists")
	truthy(FileAccess.file_exists("res://scenes/stasis_fight.tscn"), "stasis fight scene exists")


func _test_cli_still_skips_to_koliseo_route() -> void:
	var hub: Script = load("res://scenes/mobile_hub.gd")
	eq(hub.boot_route(PackedStringArray()), "picker", "F5 with no flags shows the hub")
	eq(hub.boot_route(PackedStringArray(["--dedicated", "7777"])), "dedicated", "--dedicated still skips the hub")
	eq(hub.boot_route(PackedStringArray(["--class", "bastion"])), "board", "--class still skips the hub")
	eq(hub.boot_route(PackedStringArray(["--host", "7777"])), "board", "--host still skips the hub")
	eq(hub.boot_route(PackedStringArray(["--join", "127.0.0.1:7777"])), "board", "--join still skips the hub")
	eq(hub.boot_route(PackedStringArray(["--queue", "127.0.0.1:7777", "--class", "kestrel"])), "board", "--queue still skips the hub")


func _test_hub_doors() -> void:
	var hub := _hub()
	eq(hub.door_count(), 6, "hub has Koliseo plus five Stasis doors")
	eq(hub.door_id(0), "koliseo", "first door is Koliseo")
	eq(hub.door_text(0), "Koliseo", "Koliseo label")
	eq(hub.door_text(1), "Crosshaven Stasis", "Crosshaven door")
	eq(hub.door_text(2), "Brinewake Stasis", "Brinewake door")
	eq(hub.door_text(3), "Slagcrown Stasis", "Slagcrown door")
	eq(hub.door_text(4), "Windmere Stasis", "Windmere door")
	eq(hub.door_text(5), "Stormspire Stasis", "Stormspire door")
	var ids: Array[String] = []
	for index in range(hub.door_count()):
		var button: Button = hub._doors[index]
		eq(button.custom_minimum_size.y >= 48, true, "%s hit target is at least 48px" % hub.door_text(index))
		if index > 0:
			ids.append(hub.door_id(index))
	eq(ids, ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"], "stasis doors use the five ship ids")
	eq(load("res://scenes/mobile_hub.gd").BIOME_IDS, ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"], "biome allowlist is the five ids")
	for map_id in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		var tags_path := "res://art/maps/arena_colosseum_v2/tiled/%s_15x15_tags.json" % map_id
		var tmx_path := "res://art/maps/arena_colosseum_v2/tiled/%s_15x15.tmx" % map_id
		eq(MobileHub.tags_path(map_id), tags_path, "%s tags path is the tiled 15x15 file" % map_id)
		eq(MobileHub.tags_path(map_id), CellTagMap.tags_path_for(map_id), "%s tags path matches the map loader" % map_id)
		eq(MobileHub.title_of(map_id), CellTagMap.label_of(map_id), "%s label is Title Case of the id" % map_id)
		truthy(FileAccess.file_exists(tags_path), "%s tags file exists" % map_id)
		truthy(FileAccess.file_exists(tmx_path), "%s tmx file exists" % map_id)
	eq(MobileHub.is_biome_id("brinehaven"), false, "brinehaven is not a biome id")
	eq(MobileHub.is_biome_id("crosswake"), false, "crosswake is not a biome id")
	eq(MobileHub.tags_path("brinehaven"), "", "a mixed spelling has no tags path")
	hub.open_stasis("brinehaven")
	eq(str(load("res://scenes/mobile_hub.gd").pending_biome_id), "", "a mixed spelling does not open Stasis")
	hub.open_koliseo()
	eq(str(load("res://scenes/mobile_hub.gd").pending_biome_id), "", "Koliseo does not keep a stasis biome")
	hub.open_stasis("windmere")
	eq(str(load("res://scenes/mobile_hub.gd").pending_biome_id), "windmere", "Stasis door stores the biome id")
	hub.open_stasis("not_a_biome")
	eq(str(load("res://scenes/mobile_hub.gd").pending_biome_id), "windmere", "unknown ids do not replace the biome")
	hub.open_stasis("crosswake")
	eq(str(load("res://scenes/mobile_hub.gd").pending_biome_id), "windmere", "a mixed spelling does not replace the biome")
	hub.free()


func _test_stasis_runs() -> void:
	var script: Script = load("res://scenes/mobile_hub.gd")
	var bosses := {
		"crosshaven": "Warden of the Sheaves",
		"brinewake": "Captain Brineclaw",
		"slagcrown": "Slagheart the Emberbrute",
		"windmere": "Serra the Gale Sentinel",
		"stormspire": "Tyrant Coilspire",
	}
	for map_id in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		script.pending_biome_id = map_id
		var run := _run_scene()
		eq(run.title_text(), StasisCatalog.door_name(map_id), "%s run titles the door" % map_id)
		eq(run.body_text().contains(bosses[map_id]), true, "%s run names the boss" % map_id)
		eq(run.body_text().contains(CellTagMap.blurb_of(map_id)), true, "%s run uses the catalog blurb" % map_id)
		for trash_name in StasisCatalog.trash_names(map_id):
			eq(run.body_text().contains(trash_name), true, "%s run names %s" % [map_id, trash_name])
		eq(run.note_text().contains("provisional"), true, "%s run labels foe numbers provisional" % map_id)
		eq(run.note_text().contains("coming soon"), false, "%s run is not the coming-soon stub" % map_id)
		eq(run.class_button_count(), 5, "%s run offers the five classes" % map_id)
		for index in run.class_button_count():
			var button: Button = run._class_buttons[index]
			eq(button.custom_minimum_size.y >= 48, true, "%s class button clears the 48px floor" % map_id)
		eq(run.pick_class("not_a_class"), false, "%s run rejects an unknown class" % map_id)
		eq(run.pick_class("kestrel"), true, "%s run can pick Kestrel" % map_id)
		eq(StasisCatalog.class_id, "kestrel", "%s pick stores the class" % map_id)
		run.back_to_hub()
		eq(StasisCatalog.biome_id, "", "%s back clears the run" % map_id)
		run.free()
	script.pending_biome_id = ""
	var empty := _run_scene()
	eq(empty.title_text(), "Stasis", "an empty door does not invent a gate")
	eq(empty.body_text().contains("coming soon"), false, "empty run is not the coming-soon stub")
	empty.free()
	script.pending_biome_id = ""


func _test_sources_leave_combat_alone() -> void:
	var hub_src := FileAccess.get_file_as_string("res://scenes/mobile_hub.gd")
	var run_src := FileAccess.get_file_as_string("res://scenes/stasis_run.gd")
	var select_src := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	var main_src := FileAccess.get_file_as_string("res://main.tscn")
	eq(hub_src.contains("func pick_map"), false, "hub has no map picker")
	eq(hub_src.contains("CombatSim"), false, "hub does not touch CombatSim")
	truthy(hub_src.contains("res://scenes/stasis_run.tscn"), "hub opens the stasis run")
	eq(hub_src.contains("stasis_stub"), false, "hub does not open the coming-soon stub")
	eq(run_src.contains("coming soon"), false, "stasis run has no coming-soon copy")
	eq(main_src.contains("stasis_"), false, "PC duel scene does not reference Stasis")
	eq(select_src.contains("stasis_"), false, "class select does not reference Stasis")
	truthy(select_src.contains("res://scenes/mobile_hub.tscn"), "class select can return to the hub")
	truthy(select_src.contains("roll_hotseat_map"), "Koliseo still rolls a hot-seat arena")
	eq(select_src.contains("func pick_map"), false, "class select still has no map picker")


func _hub() -> Node:
	var hub: Node = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	return hub


func _run_scene() -> Node:
	var run: Node = (load("res://scenes/stasis_run.tscn") as PackedScene).instantiate()
	run._auto_launch = false
	root.add_child(run)
	return run


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
