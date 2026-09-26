extends SceneTree

## Mobile Stasis smoke. Two rooms (A trash pack, B boss), package foe art,
## schematic boards, and one CombatSim exchange. Koliseo without stasis_roster
## stays on Locked Strike 16.
## Run: godot --headless --path . -s res://tests/run_stasis_tests.gd

var _failed: int = 0
var _passed: int = 0
var _fight: Node
var _fight_waits: int = 0
var _sim: Node


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_sim = root.get_node_or_null("CombatSim")
	if _sim == null:
		_sim = load("res://backend/combat_sim.gd").new()
		_sim.name = "CombatSim"
		root.add_child(_sim)
	_test_package_and_flow()
	_test_ai()
	_test_boards_and_provisional_hit()
	_test_koliseo_strike_unchanged()
	_start_fight_scene()


func _finish() -> void:
	print("Stasis tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_package_and_flow() -> void:
	var src := FileAccess.get_file_as_string("res://backend/stasis_catalog.gd")
	var sim_src := FileAccess.get_file_as_string("res://backend/combat_sim.gd")
	var board_src := FileAccess.get_file_as_string("res://board_view.gd")
	truthy(src.contains("provisional Open"), "catalog labels foe numbers provisional Open")
	truthy(src.contains("not Locked") or src.contains("Not Locked"), "catalog says the numbers are not Locked")
	truthy(src.contains("exactly 2 rooms"), "catalog locks the two-room grammar")
	truthy(src.contains("res://art/stasis/foes/"), "catalog points foe art at the package crops")
	eq(src.contains("STAND_IN_CLASS"), false, "catalog does not keep an Ironjaw stand-in constant")
	truthy(sim_src.contains("stasis_roster"), "CombatSim applies a roster only when the key is present")
	truthy(sim_src.contains("provisional Open"), "CombatSim comment keeps the provisional label")
	eq(board_src.contains("stasis_"), false, "shared board view does not reference Stasis scenes")
	eq(int(SpellKits.spell(SpellKits.STRIKE).get("base_damage", -1)), 16, "Locked Strike base stays 16")
	eq(StasisCatalog.PROVISIONAL_TRASH_HP, 22, "provisional trash HP")
	eq(StasisCatalog.PROVISIONAL_TRASH_ATTACK, 6, "provisional trash attack base")
	eq(StasisCatalog.PROVISIONAL_BOSS_HP, 56, "provisional boss HP")
	eq(StasisCatalog.PROVISIONAL_BOSS_ATTACK, 10, "provisional boss attack base")
	var expected := {
		"crosshaven": ["Threshgate", "Warden of the Sheaves", "Scarecrow Drudge", "Grain Hound", "Threshling"],
		"brinewake": ["Tidehold", "Captain Brineclaw", "Tide Skitter", "Silt Raider", "Brine Gullkin"],
		"slagcrown": ["Ashmarch", "Slagheart the Emberbrute", "Cinder Imp", "Ash Stalker", "Slag Mite"],
		"windmere": ["Galevault", "Serra the Gale Sentinel", "Gale Skitter", "Gustling", "Frost Wisp"],
		"stormspire": ["Coilgate", "Tyrant Coilspire", "Sparkin", "Volt Mote", "Coil Tick"],
	}
	for map_id in expected.keys():
		var names: Array = expected[map_id]
		eq(StasisCatalog.door_name(map_id), names[0], "%s door name" % map_id)
		eq(StasisCatalog.boss_name(map_id), names[1], "%s boss name" % map_id)
		eq(StasisCatalog.trash_names(map_id), [names[2], names[3], names[4]], "%s trash names" % map_id)
	eq(StasisCatalog.begin("brinehaven"), false, "a mixed spelling does not start a gate")
	truthy(StasisCatalog.begin("windmere"), "windmere starts a gate")
	eq(StasisCatalog.room, "a", "a gate opens on room A")
	eq(StasisCatalog.current_foe()["name"], "Gale Skitter", "room A names the first trash in the pack")
	eq(StasisCatalog.trash_names().size(), StasisCatalog.TRASH_COUNT, "room A still lists three trash")
	var banner := StasisCatalog.room_banner()
	truthy(banner.contains("Room A"), "banner names room A")
	truthy(banner.contains("Gale Skitter") and banner.contains("Gustling") and banner.contains("Frost Wisp"), "room A banner lists the whole pack")
	eq(banner.contains("/3"), false, "room A is not billed as trash 1/3")
	eq(StasisCatalog.continue_caption(), "Enter Room B", "clearing room A offers room B")
	eq(StasisCatalog.advance_after_win(), "next", "room A win is one step into room B")
	eq(StasisCatalog.room, "b", "boss room is B")
	eq(StasisCatalog.current_foe()["name"], "Serra the Gale Sentinel", "room B is the boss")
	eq(int(StasisCatalog.current_foe()["hp"]), StasisCatalog.PROVISIONAL_BOSS_HP, "boss uses the provisional HP")
	eq(StasisCatalog.advance_after_win(), "cleared", "boss win clears the gate")
	StasisCatalog.clear_run()


func _test_ai() -> void:
	var strike: Dictionary = StasisAi.choose([
		{"type": "move", "to": Vector2i(1, 0), "seat": 1},
		{"type": "cast", "spell": "advance", "to": Vector2i(2, 0), "seat": 1},
		{"type": "cast", "spell": "strike", "to": Vector2i(0, 1), "seat": 1},
		{"type": "end_turn", "seat": 1},
	], Vector2i(0, 0), Vector2i(0, 1))
	eq(str(strike.get("spell", "")), "strike", "foe strikes when Strike is legal")
	var move: Dictionary = StasisAi.choose([
		{"type": "move", "to": Vector2i(1, 1), "seat": 1},
		{"type": "move", "to": Vector2i(4, 4), "seat": 1},
		{"type": "cast", "spell": "crush", "to": Vector2i(4, 4), "seat": 1},
		{"type": "end_turn", "seat": 1},
	], Vector2i(0, 0), Vector2i(5, 5))
	eq(move.get("to", Vector2i.ZERO), Vector2i(4, 4), "foe walks toward the player and ignores Crush")
	var done: Dictionary = StasisAi.choose([
		{"type": "face", "dir": "N", "seat": 1},
		{"type": "end_turn", "seat": 1},
	], Vector2i.ZERO, Vector2i(3, 3))
	eq(str(done.get("type", "")), "end_turn", "foe ends the turn when it cannot strike or walk")


func _test_boards_and_provisional_hit() -> void:
	for map_id in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		truthy(StasisCatalog.begin(map_id), "%s begin" % map_id)
		StasisCatalog.class_id = "kestrel"
		var spawned: Array = StasisCatalog.spawn_cells(map_id)
		eq(spawned.size(), 4, "%s room A spawns the player and three trash" % map_id)
		var config := StasisCatalog.fight_config()
		eq(str(config.get("map_id", "")), map_id, "%s fight uses that biome" % map_id)
		truthy(str(config.get("cell_tags", "")).contains("res://art/maps/stasis_v1/"), "%s board is a Stasis schematic" % map_id)
		eq(str(config.get("cell_tags", "")).contains("arena_colosseum"), false, "%s does not load the Koliseo tags" % map_id)
		eq(bool(config.get("skip_deploy", false)), true, "%s fight skips Koliseo deploy" % map_id)
		var snap: Dictionary = _sim.reset_match(config)
		eq(int(snap.get("board_size", 0)), 15, "%s board is 15" % map_id)
		eq((snap.get("tiles", {}) as Dictionary).size(), 225, "%s tags board is 15×15" % map_id)
		eq(str(snap.get("phase", "")), "TURN_1", "%s starts in combat" % map_id)
		eq(bool(snap.get("combat_enabled", false)), true, "%s combat is enabled" % map_id)
		var units: Array = snap.get("units", [])
		eq(units.size(), 4, "%s room A has the player and three trash" % map_id)
		var order: Array = CombatHUD.turn_order(snap)
		eq(order.size(), 4, "%s turn strip lists the living seats" % map_id)
		eq(int(order[0].get("seat", -1)), 0, "%s turn order starts with the player" % map_id)
		eq(int(order[3].get("seat", -1)) > int(order[0].get("seat", -1)), true, "%s turn order follows seat order" % map_id)
		var player: Dictionary = units[0]
		var enemy: Dictionary = units[1]
		eq(str(player.get("name", "")), "Kestrel", "%s player keeps the class name" % map_id)
		eq(int(player.get("hp", 0)), 80, "%s player starts at Locked 80 HP" % map_id)
		eq(player.has("stasis_attack_base"), false, "%s player has no provisional attack" % map_id)
		eq(str(enemy.get("name", "")), str(StasisCatalog.current_foe()["name"]), "%s foe name" % map_id)
		eq(int(enemy.get("hp", 0)), StasisCatalog.PROVISIONAL_TRASH_HP, "%s trash HP is provisional" % map_id)
		eq(int(enemy.get("max_hp", 0)), StasisCatalog.PROVISIONAL_TRASH_HP, "%s trash max HP is provisional" % map_id)
		eq(int(enemy.get("stasis_attack_base", -1)), StasisCatalog.PROVISIONAL_TRASH_ATTACK, "%s trash attack base" % map_id)
		var seen_art := {}
		for unit in units:
			if int(unit.get("seat", -1)) == 0:
				eq(str(unit.get("stasis_sprite", "")), "", "%s player has no foe portrait" % map_id)
				continue
			var sprite := str(unit.get("stasis_sprite", ""))
			truthy(sprite.begins_with("res://art/stasis/foes/"), "%s foe art is a package crop" % map_id)
			eq(sprite.contains("ironjaw"), false, "%s foe art is not the Ironjaw sheet" % map_id)
			eq(sprite.contains("art/characters/"), false, "%s foe art is not a class turnaround" % map_id)
			truthy(FileAccess.file_exists(sprite), "%s foe portrait exists" % map_id)
			eq(seen_art.has(sprite), false, "%s pack mates use different portraits" % map_id)
			seen_art[sprite] = true
		var tiles: Dictionary = snap.get("tiles", {})
		var player_pos: Vector2i = player.get("pos", Vector2i(-1, -1))
		eq(tiles.has(player_pos), true, "%s player stands on a tile" % map_id)
		eq(bool(tiles[player_pos].get("walkable", false)), true, "%s player tile is walkable" % map_id)
		eq(str(tiles[player_pos].get("terrain_type", "")) == "lava", false, "%s player is not on lava" % map_id)
		for unit in units:
			if int(unit.get("seat", -1)) == 0:
				continue
			var foe_pos: Vector2i = unit.get("pos", Vector2i(-1, -1))
			eq(tiles.has(foe_pos), true, "%s foe stands on a tile" % map_id)
			eq(bool(tiles[foe_pos].get("walkable", false)), true, "%s foe tile is walkable" % map_id)
			eq(str(tiles[foe_pos].get("terrain_type", "")) == "lava", false, "%s foe is not on lava" % map_id)
			var apart := maxi(absi(player_pos.x - foe_pos.x), absi(player_pos.y - foe_pos.y))
			eq(apart >= 3, true, "%s spawns are not already in melee" % map_id)
		if map_id == "crosshaven":
			eq(str(tiles[Vector2i(1, 0)].get("terrain_type", "")), "mud", "Threshgate Room A opens with a mud furrow")
			eq(str(tiles[Vector2i(1, 0)].get("terrain_type", "")) == str(_koliseo_terrain(map_id, Vector2i(1, 0))), false, "Threshgate Room A is not the Koliseo cell")
		if map_id == "slagcrown":
			var lava_count := 0
			for cell in tiles.keys():
				if str(tiles[cell].get("terrain_type", "")) == "lava":
					lava_count += 1
			eq(lava_count > 8, true, "Ashmarch Room A has lava spokes")
		if map_id == "brinewake":
			var water_count := 0
			for cell in tiles.keys():
				if str(tiles[cell].get("terrain_type", "")) == "water":
					water_count += 1
			eq(water_count > 8, true, "Tidehold Room A has tidal water")
	_test_melee_exchange()
	_test_room_b_board()
	StasisCatalog.clear_run()


func _test_melee_exchange() -> void:
	truthy(StasisCatalog.begin("crosshaven"), "melee exchange begins crosshaven")
	StasisCatalog.class_id = "ironjaw"
	var pair: Array = StasisCatalog.melee_pair("crosshaven")
	eq(pair.size(), 2, "crosshaven has an adjacent ground pair")
	var config := StasisCatalog.fight_config(pair)
	config["rolls"] = [1, 1]
	var snap: Dictionary = _sim.reset_match(config)
	var enemy: Dictionary = snap["units"][1]
	var enemy_pos: Vector2i = enemy["pos"]
	eq(str(enemy.get("name", "")), "Scarecrow Drudge", "first foe is the scarecrow")
	var player_hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": enemy_pos, "seat": 0})
	truthy(bool(player_hit.get("ok", false)), "player Strike resolves (%s)" % str(player_hit.get("reason", "")))
	var player_event := _hit_event(player_hit)
	eq(int(player_event.get("base_damage", -1)), 16, "player Strike keeps Locked base 16")
	eq(int(player_event.get("damage", -1)), _faced_damage(16, float(player_event.get("facing_mult", 1.0))), "player damage uses Locked base times facing")
	var ended: Dictionary = _sim.submit({"type": "end_turn", "seat": 0})
	truthy(bool(ended.get("ok", false)), "player can end the turn")
	var after: Dictionary = _sim.snapshot()
	var player_pos: Vector2i = after["units"][0]["pos"]
	var foe_hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": player_pos, "seat": 1})
	truthy(bool(foe_hit.get("ok", false)), "foe Strike resolves (%s)" % str(foe_hit.get("reason", "")))
	var foe_event := _hit_event(foe_hit)
	eq(str(foe_event.get("spell", "")), "strike", "foe still resolves the stand-in Strike card")
	eq(int(foe_event.get("base_damage", -1)), StasisCatalog.PROVISIONAL_TRASH_ATTACK, "foe base is the provisional attack, not 16")
	eq(int(foe_event.get("damage", -1)), _faced_damage(StasisCatalog.PROVISIONAL_TRASH_ATTACK, float(foe_event.get("facing_mult", 1.0))), "foe damage is provisional base times facing")
	truthy(str(foe_event.get("coach", "")).contains("Straw Swipe"), "coach uses the provisional attack label")
	var carried: Dictionary = _sim.snapshot()
	StasisCatalog.carry_player_hp(int(carried["units"][0]["hp"]))
	_test_one_trash_does_not_clear_the_room()
	eq(StasisCatalog.advance_after_win(), "next", "a room A win enters room B")
	eq(StasisCatalog.room, "b", "the carried fight is room B")
	var next: Dictionary = _sim.reset_match(StasisCatalog.fight_config())
	eq(next["units"].size(), 2, "room B is the player and the boss")
	eq(str(next["units"][1]["name"]), "Warden of the Sheaves", "room B foe is the warden")
	eq(str(next["units"][1].get("stasis_sprite", "")).contains("ironjaw"), false, "warden portrait is not Ironjaw")
	truthy(str(next["units"][1].get("stasis_sprite", "")).ends_with("warden_of_the_sheaves.png"), "warden uses the scarecrow crop")
	eq(int(next["units"][0]["hp"]), int(carried["units"][0]["hp"]), "player HP carries into room B")
	eq(int(next["units"][0]["max_hp"]), 80, "carried HP does not change the Locked player max")


func _test_one_trash_does_not_clear_the_room() -> void:
	var spawned: Array = StasisCatalog.spawn_cells("crosshaven", "a")
	var scarecrow_pos: Vector2i = spawned[1]
	var blocked := {}
	for cell in spawned:
		blocked[cell] = true
	var stand := Vector2i(-1, -1)
	for step in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var cand: Vector2i = scarecrow_pos + step
		if cand.x < 0 or cand.y < 0 or cand.x > 14 or cand.y > 14:
			continue
		if blocked.has(cand):
			continue
		stand = cand
		break
	eq(stand.x >= 0, true, "scarecrow has an empty neighbor for a melee test")
	var config := StasisCatalog.fight_config([stand, scarecrow_pos])
	config["rolls"] = [1, 1, 1, 1]
	var snap: Dictionary = _sim.reset_match(config)
	var scarecrow: Dictionary = {}
	for unit in snap["units"]:
		if str(unit.get("name", "")) == "Scarecrow Drudge":
			scarecrow = unit
	eq(scarecrow.is_empty(), false, "pack contains the scarecrow")
	var first: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": scarecrow["pos"], "seat": 0})
	truthy(bool(first.get("ok", false)), "first pack Strike resolves (%s)" % str(first.get("reason", "")))
	var second: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": scarecrow["pos"], "seat": 0})
	truthy(bool(second.get("ok", false)), "second pack Strike resolves (%s)" % str(second.get("reason", "")))
	var after: Dictionary = _sim.snapshot()
	eq(bool(after.get("match_over", true)), false, "one trash falling does not end room A")
	var living := 0
	for unit in after["units"]:
		if int(unit.get("seat", -1)) > 0 and bool(unit.get("alive", false)):
			living += 1
	eq(living, 2, "the other two trash stay on the board")


func _test_room_b_board() -> void:
	truthy(StasisCatalog.begin("stormspire"), "coilgate room B begins")
	StasisCatalog.class_id = "kestrel"
	eq(StasisCatalog.advance_after_win(), "next", "coilgate steps into room B")
	var config := StasisCatalog.fight_config()
	var snap: Dictionary = _sim.reset_match(config)
	eq(snap["units"].size(), 2, "coilgate room B is a single boss")
	eq(str(snap["units"][1]["name"]), "Tyrant Coilspire", "coilgate boss is Coilspire")
	truthy(str(snap["units"][1].get("stasis_sprite", "")).ends_with("tyrant_coilspire.png"), "coilspire uses the package crop")
	var tiles: Dictionary = snap.get("tiles", {})
	var water := 0
	var mud := 0
	var elevated := 0
	for cell in tiles.keys():
		var terrain := str(tiles[cell].get("terrain_type", ""))
		if terrain == "water":
			water += 1
		elif terrain == "mud":
			mud += 1
		if int(tiles[cell].get("elevation", 0)) >= 2:
			elevated += 1
	eq(water > 8, true, "Coilgate Room B has the water cross")
	eq(mud > 8, true, "Coilgate Room B has the mud cross")
	eq(elevated > 0, true, "Coilgate Room B has a coil throne")


func _koliseo_terrain(map_id: String, cell: Vector2i) -> String:
	var tags := CellTagMap.load_file("res://art/maps/arena_colosseum_v2/tiled/%s_15x15_tags.json" % map_id)
	for item in tags.get("cells", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if item.get("pos", Vector2i(-1, -1)) == cell:
			return str(item.get("terrain", ""))
	return ""


func _test_koliseo_strike_unchanged() -> void:
	StasisCatalog.clear_run()
	var snap: Dictionary = _sim.reset_match({
		"skip_deploy": true,
		"flat_board": true,
		"classes": ["ironjaw", "kestrel"],
		"positions": [Vector2i(2, 2), Vector2i(3, 2)],
		"rolls": [1],
	})
	eq(str(snap["units"][0]["name"]), "Ironjaw", "Koliseo seat 0 stays Ironjaw")
	eq(str(snap["units"][1]["name"]), "Kestrel", "Koliseo seat 1 stays Kestrel")
	eq(int(snap["units"][0]["hp"]), 80, "Koliseo HP stays 80")
	eq(int(snap["units"][1]["hp"]), 80, "Koliseo foe HP stays 80")
	eq(snap["units"][1].has("stasis_attack_base"), false, "Koliseo units have no provisional attack")
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": snap["units"][1]["pos"], "seat": 0})
	truthy(bool(hit.get("ok", false)), "Koliseo Strike still resolves")
	var event := _hit_event(hit)
	eq(int(event.get("base_damage", -1)), 16, "Koliseo Strike base stays Locked 16")
	eq(str(event.get("coach", "")).contains("Straw Swipe"), false, "Koliseo coach does not use a dungeon label")


func _start_fight_scene() -> void:
	StasisCatalog.clear_run()
	MobileHub.pending_biome_id = "slagcrown"
	truthy(StasisCatalog.begin("slagcrown"), "fight scene prep")
	StasisCatalog.class_id = "mender"
	var packed := load("res://scenes/stasis_fight.tscn") as PackedScene
	_fight = packed.instantiate()
	root.add_child(_fight)
	process_frame.connect(_assert_fight_scene, CONNECT_ONE_SHOT)


func _assert_fight_scene() -> void:
	var snap: Dictionary = _sim.snapshot()
	_fight_waits += 1
	if not str(snap.get("map_id", "")).begins_with("slagcrown") and _fight_waits < 8:
		process_frame.connect(_assert_fight_scene, CONNECT_ONE_SHOT)
		return
	truthy(str(snap.get("map_id", "")).begins_with("slagcrown"), "fight scene loads the Slagcrown board")
	eq(int(snap.get("board_size", 0)), 15, "fight scene board is 15")
	eq(str(snap.get("phase", "")), "TURN_1", "fight scene skips deploy")
	eq(bool(snap.get("combat_enabled", false)), true, "fight scene combat is enabled")
	var enemy_name := ""
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == 1:
			enemy_name = str(unit.get("name", ""))
	eq(enemy_name, "Cinder Imp", "fight scene spawns Ashmarch trash")
	eq(snap.get("units", []).size(), 4, "fight scene room A is one pack, not a 1v1")
	var foe_art := ""
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == 1:
			foe_art = str(unit.get("stasis_sprite", ""))
	eq(foe_art.contains("ironjaw"), false, "fight scene foe is not drawn as Ironjaw")
	truthy(foe_art.begins_with("res://art/stasis/foes/"), "fight scene foe uses the package crop")
	var board := _fight.get_node("BoardView")
	eq(board.get_node_or_null("StasisChrome") != null, true, "fight scene has clickable stasis chrome")
	_fight.free()
	StasisCatalog.clear_run()
	_sim.reset_match({})
	_finish()


func _hit_event(result: Dictionary) -> Dictionary:
	for event in result.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "hit":
			return event
	return {}


func _faced_damage(base: int, facing_mult: float) -> int:
	return roundi(float(base) * facing_mult)


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
