extends SceneTree

## Class-select screen state machine. P1 then P2 starts a local match
## with those class ids. Online pick calls NetSession.select_class.
## Run: godot --headless --path . -s res://tests/run_class_picker_tests.gd

var _failed: int = 0
var _passed: int = 0
var _script: GDScript


func _initialize() -> void:
	_script = load("res://scenes/class_select.gd")
	# _ready does not run for nodes added before the first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_routes()
	_test_roles_and_art()
	_test_launch_cards()
	_test_hotseat_p1_then_p2()
	_test_hotseat_default_pair()
	_test_hotseat_teams()
	_test_online_select_class()
	_test_dedicated_hides_picker()
	_test_board_uses_roster()
	print("Class-picker tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_routes() -> void:
	var net := load("res://backend/net_session.gd")
	eq(_script.route_for_plan(net.plan_from_args(PackedStringArray(["--dedicated", "7777"]))), "dedicated", "--dedicated skips the picker")
	eq(_script.route_for_plan(net.plan_from_args(PackedStringArray(["--dedicated", "7777", "--class", "mender"]))), "dedicated", "--dedicated wins over --class")
	eq(_script.route_for_plan(net.plan_from_args(PackedStringArray(["--join", "127.0.0.1:7777"]))), "board", "--join skips the picker")
	eq(_script.route_for_plan(net.plan_from_args(PackedStringArray(["--queue", "127.0.0.1:7777", "--class", "kestrel"]))), "board", "--queue skips the picker")
	eq(_script.route_for_plan(net.plan_from_args(PackedStringArray(["--class", "bastion"]))), "board", "--class skips the picker")
	eq(_script.route_for_plan(net.plan_from_args(PackedStringArray(["--host", "7777"]))), "board", "--host skips the picker")
	eq(_script.route_for_plan(net.plan_from_args(PackedStringArray([]))), "picker", "no flags show the picker")
	var project := FileAccess.get_file_as_string("res://project.godot")
	truthy(project.contains('run/main_scene="res://scenes/mobile_hub.tscn"'), "mobile branch boots the hub")
	truthy(FileAccess.file_exists("res://scenes/class_select.tscn"), "Koliseo still uses the class select scene")


func _test_roles_and_art() -> void:
	eq(_script.role_line("kestrel"), "Ranged carry", "kestrel role")
	eq(_script.role_line("ironjaw"), "Melee bruiser", "ironjaw role")
	eq(_script.role_line("mender"), "Healer", "mender role")
	eq(_script.role_line("gloam"), "Stealth assassin", "gloam role")
	eq(_script.role_line("bastion"), "Tank", "bastion role")
	eq(SpellKits.display_name("kestrel"), "Kestrel", "kestrel display name")
	eq(SpellKits.display_name("ironjaw"), "Ironjaw", "ironjaw display name")
	eq(SpellKits.display_name("mender"), "Mender", "mender display name")
	eq(SpellKits.display_name("gloam"), "Gloam", "gloam display name")
	eq(SpellKits.display_name("bastion"), "Bastion", "bastion display name")
	eq(_script.load_portrait("not_a_class"), null, "missing portrait falls back")
	eq(_script.portrait_path("not_a_class"), "", "unknown class has no portrait path")
	for class_id in SpellKits.LOCKED_ROSTER:
		for facing in ["n", "e", "s", "w"]:
			var path := "res://art/characters/%s/%s_%s.png" % [class_id, class_id, facing]
			truthy(FileAccess.file_exists(path), "sprite exists %s" % path)
		var painted := "res://art/characters/%s/idle/%s_idle_s.pngbin" % [class_id, class_id]
		eq(_script.portrait_path(class_id), painted, "%s card uses the match idle" % class_id)
		var cells: Array = StripLibrary.painted_cells(class_id, "idle", "s")
		truthy(cells.size() > 0, "%s idle sheet slices" % class_id)
		var tex: Texture2D = _script.load_portrait(class_id)
		truthy(tex != null, "%s portrait loads" % class_id)
		if tex != null and cells.size() > 0:
			eq(tex, cells[0], "%s card is the standing cell the match draws" % class_id)
			eq(tex.get_width() == 512 and tex.get_height() == 768, false, "%s card is not the old select plate" % class_id)
			var fresh := tex.get_image()
			truthy(fresh != null and not fresh.is_empty(), "%s portrait decodes" % class_id)
		var imp := FileAccess.get_file_as_string("res://art/characters/%s/%s_s.png.import" % [class_id, class_id])
		truthy(imp.contains("mipmaps/generate=false"), "%s import mipmaps off" % class_id)
	var hud_src := FileAccess.get_file_as_string("res://ui/hud.gd")
	truthy(hud_src.contains("StripLibrary.idle_portrait"), "turn chips use the locked idle")


func _test_launch_cards() -> void:
	var picker := _picker()
	eq(picker.phase_name(), "mode", "launch waits for a mode")
	eq(picker.prompt_text(), "Choose Hot-seat or Online.", "launch prompt names both modes")
	eq(picker.class_cards_visible(), true, "five cards are on the launch screen")
	eq(picker.queue_button_text(), "Play Online", "online control is Play Online")
	for class_id in SpellKits.LOCKED_ROSTER:
		eq(picker.card_title(class_id), SpellKits.display_name(class_id), "%s card uses the display name" % class_id)
		eq(picker.card_role(class_id), _script.role_line(class_id), "%s card uses the role line" % class_id)
		eq(picker.card_has_portrait(class_id), true, "%s card shows the select plate" % class_id)
		eq(picker.portrait_filter(class_id), CanvasItem.TEXTURE_FILTER_LINEAR, "%s portrait filter is linear" % class_id)
	var early: Dictionary = picker.pick_class("mender")
	eq(bool(early.get("ok", true)), false, "a card before a mode does not pick")
	eq(str(early.get("reason", "")), "mode_required", "mode is required first")
	picker.free()


func _test_hotseat_p1_then_p2() -> void:
	var picker := _picker()
	picker.choose_mode("hotseat")
	eq(picker.phase_name(), "hotseat_p1", "hot-seat starts at P1")
	eq(picker.class_cards_visible(), true, "class cards are ready with the hot-seat pick")
	truthy(picker.prompt_text().contains("P1"), "prompt names P1")
	picker.go_back()
	eq(picker.phase_name(), "mode", "back from P1 returns to the mode screen")
	picker.choose_mode("hotseat")
	eq(picker.phase_name(), "hotseat_p1", "hot-seat starts at P1")
	eq(picker.prompt_seat(), 0, "P1 uses seat 0")
	truthy(picker.prompt_text().contains("P1"), "prompt names P1")
	var p1: Dictionary = picker.pick_class("mender")
	eq(bool(p1.get("ok", false)), true, "P1 mender is accepted")
	eq(int(p1.get("seat", -1)), 0, "mender is seat 0")
	eq(picker.phase_name(), "hotseat_p2", "next pick is P2")
	eq(picker.prompt_seat(), 1, "P2 uses seat 1")
	truthy(picker.prompt_text().contains("P2"), "prompt names P2")
	picker.go_back()
	eq(picker.phase_name(), "hotseat_p1", "back from P2 returns to P1")
	picker.pick_class("mender")
	var p2: Dictionary = picker.pick_class("bastion")
	eq(bool(p2.get("ok", false)), true, "P2 bastion is accepted")
	eq(int(p2.get("seat", -1)), 1, "bastion is seat 1")
	eq(_script.hotseat_classes[0], "mender", "sealed seat 0 is mender")
	eq(_script.hotseat_classes[1], "bastion", "sealed seat 1 is bastion")
	truthy(CellTagMap.is_ship_map(str(_script.hotseat_map_id)), "sealed map is one of the five arenas")
	var sim := _sim()
	sim.reset_match(_script.local_match_config())
	var units: Array = sim.snapshot()["units"]
	eq(str(units[0]["class_id"]), "mender", "match seat 0 is mender")
	eq(str(units[1]["class_id"]), "bastion", "match seat 1 is bastion")
	eq(SpellKits.class_spells("mender").has("mend"), true, "mender kit is the locked card")
	eq(SpellKits.class_spells("bastion").has("bash"), true, "bastion kit is the locked card")
	picker.free()


func _test_hotseat_default_pair() -> void:
	var picker := _picker()
	picker.choose_mode("hotseat")
	picker.pick_class("kestrel")
	picker.pick_class("ironjaw")
	var sim := _sim()
	sim.reset_match(_script.local_match_config())
	var units: Array = sim.snapshot()["units"]
	eq(str(units[0]["class_id"]), "kestrel", "kestrel vs ironjaw seat 0")
	eq(str(units[1]["class_id"]), "ironjaw", "kestrel vs ironjaw seat 1")
	picker.free()
	var mirror := _picker()
	mirror.choose_mode("hotseat")
	mirror.pick_class("gloam")
	mirror.pick_class("gloam")
	eq(_script.hotseat_classes[0], "gloam", "same class can sit both seats")
	eq(_script.hotseat_classes[1], "gloam", "seat 1 can also be gloam")
	mirror.free()


func _test_online_select_class() -> void:
	var net := _net()
	net.selected_class_id = ""
	var picker := _picker()
	picker.choose_mode("online")
	eq(picker.phase_name(), "online", "online mode")
	eq(picker.address_field_visible(), false, "online hides the address field")
	var early: Dictionary = picker.request_queue()
	eq(bool(early.get("ok", true)), false, "queue before a class is rejected")
	eq(str(early.get("reason", "")), "class_required", "queue reason is class_required")
	eq(net.is_client(), false, "rejected queue does not connect")
	var picked: Dictionary = picker.pick_class("gloam")
	eq(bool(picked.get("ok", false)), true, "online pick accepts gloam")
	eq(str(picked.get("class_id", "")), "gloam", "online pick returns gloam")
	eq(net.selected_class_id, "gloam", "online pick calls select_class")
	truthy(picker.status_text().contains("Gloam"), "screen shows the confirmed class")
	var rejected: Dictionary = picker.pick_class("pulse")
	eq(bool(rejected.get("ok", true)), false, "online pick rejects pulse")
	eq(str(rejected.get("reason", "")), "invalid_class", "reject reason is invalid_class")
	eq(net.selected_class_id, "gloam", "reject does not clear the stored class")
	truthy(picker.reject_text().contains("pulse"), "screen shows the reject")
	var src := FileAccess.get_file_as_string("res://scenes/class_select.gd")
	truthy(src.contains("NetSession.select_class"), "online pick goes through select_class")
	truthy(src.contains("begin_auto_queue"), "Play Online joins through begin_auto_queue")
	truthy(src.contains("select_class"), "select_class stays the class RPC path")
	picker.free()
	net.selected_class_id = ""


func _test_dedicated_hides_picker() -> void:
	var net := _net()
	net.enter_dedicated_offline()
	var picker := _picker()
	eq(picker.phase_name(), "dedicated", "dedicated route has no pick phase")
	eq(picker.class_cards_visible(), false, "dedicated host does not show class cards")
	var picked: Dictionary = picker.pick_class("mender")
	eq(bool(picked.get("ok", true)), false, "dedicated host cannot pick")
	picker.free()
	net.return_to_hotseat()


func _test_board_uses_roster() -> void:
	var view := FileAccess.get_file_as_string("res://board_view.gd")
	eq(view.split("local_match_config()").size(), 3, "boot and new match read the picked roster")
	eq(view.contains("hp"), false, "board_view still does not mention hp")


func _sim() -> Node:
	return root.get_node("CombatSim")


func _test_hotseat_teams() -> void:
	# Mauro 1 Oct 2026: hot-seat 2v2 / 3v3; picks go A1 B1 A2 B2; duplicates allowed.
	var picker := _picker()
	picker.choose_mode("hotseat")
	picker.set_team_size(2)
	truthy(picker.prompt_text().contains("Team A"), "2v2 starts with Team A")
	picker.pick_class("ironjaw")
	truthy(picker.prompt_text().contains("Team B"), "then Team B picks")
	picker.pick_class("kestrel")
	picker.pick_class("ironjaw")
	picker.go_back()
	eq(picker.team_picks().size(), 2, "Back undoes the last team pick")
	picker.pick_class("ironjaw")
	var last: Dictionary = picker.pick_class("mender")
	eq(bool(last.get("ok", false)), true, "the fourth pick seals the 2v2")
	eq(_script.hotseat_classes.size(), 4, "four fighters sealed")
	eq(_script.hotseat_classes[2], "ironjaw", "a duplicate class is allowed")
	var config: Dictionary = _script.local_match_config()
	eq(int(config.get("team_size", 1)), 2, "the match config asks for 2v2")
	var sim := _sim()
	sim.reset_match(config)
	eq((sim.snapshot()["units"] as Array).size(), 4, "the 2v2 board has four fighters")
	picker.free()
	_script.hotseat_team_size = 1
	_script.hotseat_classes = [] as Array[String]


func _net() -> Node:
	return root.get_node("NetSession")


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
