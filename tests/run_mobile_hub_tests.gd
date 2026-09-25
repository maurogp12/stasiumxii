extends SceneTree

## Mobile hub shell. Koliseo opens class select. Each Stasis door is a stub
## that can read that biome's 15×15 tags. No combat changes.
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
	_test_stasis_stubs()
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
	truthy(FileAccess.file_exists("res://scenes/stasis_stub.tscn"), "stasis stub scene exists")


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


func _test_stasis_stubs() -> void:
	var script: Script = load("res://scenes/mobile_hub.gd")
	for map_id in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		script.pending_biome_id = map_id
		var stub := _stub()
		eq(stub.biome_id(), map_id, "%s stub keeps the biome id" % map_id)
		eq(stub.title_text(), "%s Stasis" % MobileHub.title_of(map_id), "%s stub titles the biome" % map_id)
		eq(stub.tags_ok(), true, "%s tags board loads" % map_id)
		eq(stub.loaded_tags_path(), "res://art/maps/arena_colosseum_v2/tiled/%s_15x15_tags.json" % map_id, "%s stub loads that id's tags file" % map_id)
		eq(stub.board_size(), Vector2i(15, 15), "%s preview is 15×15" % map_id)
		eq(stub.preview_cells(), 225, "%s preview keeps every tags cell" % map_id)
		eq(stub._blurb.text, CellTagMap.blurb_of(map_id), "%s stub uses the catalog blurb" % map_id)
		truthy(stub.status_text().contains("Stasis coming soon"), "%s stub says Stasis is not ready" % map_id)
		truthy(stub.status_text().contains("not a fight"), "%s preview is non-combat" % map_id)
		stub.back_to_hub()
		stub.free()
	script.pending_biome_id = ""
	var empty := _stub()
	eq(empty.tags_ok(), false, "an empty door does not invent a board")
	truthy(empty.status_text().contains("Stasis coming soon"), "empty stub still says coming soon")
	empty.free()
	script.pending_biome_id = ""


func _test_sources_leave_combat_alone() -> void:
	var hub_src := FileAccess.get_file_as_string("res://scenes/mobile_hub.gd")
	var stub_src := FileAccess.get_file_as_string("res://scenes/stasis_stub.gd")
	var select_src := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	eq(hub_src.contains("func pick_map"), false, "hub has no map picker")
	eq(hub_src.contains("CombatSim"), false, "hub does not touch CombatSim")
	eq(stub_src.contains("CombatSim"), false, "stasis stub does not touch CombatSim")
	eq(stub_src.contains("reset_match"), false, "stasis stub does not start a match")
	truthy(select_src.contains("res://scenes/mobile_hub.tscn"), "class select can return to the hub")
	truthy(select_src.contains("roll_hotseat_map"), "Koliseo still rolls a hot-seat arena")
	eq(select_src.contains("func pick_map"), false, "class select still has no map picker")


func _hub() -> Node:
	var hub: Node = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	return hub


func _stub() -> Node:
	var stub: Node = (load("res://scenes/stasis_stub.tscn") as PackedScene).instantiate()
	stub._auto_launch = false
	root.add_child(stub)
	return stub


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
