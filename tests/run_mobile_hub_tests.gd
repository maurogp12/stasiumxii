extends SceneTree

## Hub on PC main. Koliseo opens class select. Stasis doors and dungeon
## scenes stay on the mobile branch.
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
	_test_sources_leave_combat_and_dungeons_out()
	print("Mobile hub tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_boot_scene() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	truthy(project.contains('run/main_scene="res://scenes/mobile_hub.tscn"'), "main scene is the hub")
	truthy(project.contains("window/size/viewport_width=960"), "viewport width stays 960")
	truthy(project.contains("window/size/viewport_height=720"), "viewport height stays 720")
	truthy(project.contains('window/stretch/mode="canvas_items"'), "stretch mode stays canvas_items")
	truthy(project.contains('window/stretch/aspect="expand"'), "stretch aspect stays expand")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	truthy(preset.contains('name="Android"'), "Android export preset is still named Android")
	truthy(preset.contains("com.maurogp12.stasiumxii.mobile"), "Android package id is unchanged")
	truthy(FileAccess.file_exists("res://scenes/class_select.tscn"), "class select scene remains")
	truthy(FileAccess.file_exists("res://scenes/mobile_hub.tscn"), "hub scene exists")
	eq(FileAccess.file_exists("res://scenes/stasis_run.tscn"), false, "stasis run scene is not on PC main")
	eq(FileAccess.file_exists("res://scenes/stasis_fight.tscn"), false, "stasis fight scene is not on PC main")
	eq(FileAccess.file_exists("res://scenes/stasis_stub.tscn"), false, "stasis stub scene is not on PC main")


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
	eq(hub.door_count(), 1, "hub has the Koliseo door only")
	eq(hub.door_id(0), "koliseo", "the door is Koliseo")
	eq(hub.door_text(0), "Koliseo", "Koliseo label")
	var button: Button = hub._doors[0]
	eq(button.custom_minimum_size.y >= 48, true, "Koliseo hit target is at least 48px")
	eq(load("res://scenes/mobile_hub.gd").BIOME_IDS, ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"], "biome allowlist is the five Koliseo ids")
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
	hub.free()


func _test_sources_leave_combat_and_dungeons_out() -> void:
	var hub_src := FileAccess.get_file_as_string("res://scenes/mobile_hub.gd")
	var select_src := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	var main_src := FileAccess.get_file_as_string("res://main.tscn")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	eq(hub_src.contains("func pick_map"), false, "hub has no map picker")
	eq(hub_src.contains("CombatSim"), false, "hub does not touch CombatSim")
	eq(hub_src.contains("stasis"), false, "hub does not reference Stasis")
	eq(hub_src.contains("open_stasis"), false, "hub has no Stasis door")
	truthy(hub_src.contains("res://scenes/class_select.tscn"), "hub opens Koliseo")
	eq(main_src.contains("stasis_"), false, "PC duel scene does not reference Stasis")
	eq(select_src.contains("stasis_"), false, "class select does not reference Stasis scenes")
	truthy(select_src.contains("res://scenes/mobile_hub.tscn"), "class select can return to the hub")
	truthy(select_src.contains("roll_hotseat_map"), "Koliseo still rolls a hot-seat arena")
	eq(select_src.contains("func pick_map"), false, "class select still has no map picker")
	eq(sim_src.contains("stasis_roster"), false, "CombatSim has no dungeon roster hook")
	eq(sim_src.contains("stasis_attack_base"), false, "CombatSim has no provisional foe attack")
	eq(FileAccess.file_exists("res://backend/stasis_catalog.gd"), false, "dungeon catalog is not on PC main")
	eq(FileAccess.file_exists("res://backend/stasis_ai.gd"), false, "dungeon AI is not on PC main")
	eq(FileAccess.file_exists("res://tests/run_stasis_tests.gd"), false, "dungeon tests are not on PC main")
	eq(FileAccess.file_exists("res://docs/mobile_stasis.md"), false, "dungeon doc is not on PC main")


func _hub() -> Node:
	var hub: Node = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	return hub


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
