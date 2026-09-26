extends SceneTree

## Mobile Stasis smoke. Provisional foe numbers, Room A then Room B, and one
## CombatSim exchange. Koliseo without stasis_roster stays on Locked Strike 16.
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
	eq(StasisCatalog.current_foe()["name"], "Gale Skitter", "room A starts on the first trash")
	eq(StasisCatalog.advance_after_win(), "next", "first trash advances inside room A")
	eq(StasisCatalog.current_foe()["name"], "Gustling", "second trash")
	eq(StasisCatalog.advance_after_win(), "next", "second trash advances")
	eq(StasisCatalog.current_foe()["name"], "Frost Wisp", "third trash")
	eq(StasisCatalog.continue_caption(), "Enter Room B", "last trash offers room B")
	eq(StasisCatalog.advance_after_win(), "next", "room A ends by entering room B")
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
		eq(spawned.size(), 2, "%s has two spawn cells" % map_id)
		var config := StasisCatalog.fight_config()
		eq(str(config.get("map_id", "")), map_id, "%s fight uses that biome" % map_id)
		eq(bool(config.get("skip_deploy", false)), true, "%s fight skips Koliseo deploy" % map_id)
		var snap: Dictionary = _sim.reset_match(config)
		eq(int(snap.get("board_size", 0)), 15, "%s board is 15" % map_id)
		eq((snap.get("tiles", {}) as Dictionary).size(), 225, "%s tags board is 15×15" % map_id)
		eq(str(snap.get("phase", "")), "TURN_1", "%s starts in combat" % map_id)
		eq(bool(snap.get("combat_enabled", false)), true, "%s combat is enabled" % map_id)
		var units: Array = snap.get("units", [])
		eq(units.size(), 2, "%s duel has two seats" % map_id)
		var player: Dictionary = units[0]
		var enemy: Dictionary = units[1]
		eq(str(player.get("name", "")), "Kestrel", "%s player keeps the class name" % map_id)
		eq(int(player.get("hp", 0)), 80, "%s player starts at Locked 80 HP" % map_id)
		eq(player.has("stasis_attack_base"), false, "%s player has no provisional attack" % map_id)
		eq(str(enemy.get("name", "")), str(StasisCatalog.current_foe()["name"]), "%s foe name" % map_id)
		eq(int(enemy.get("hp", 0)), StasisCatalog.PROVISIONAL_TRASH_HP, "%s trash HP is provisional" % map_id)
		eq(int(enemy.get("max_hp", 0)), StasisCatalog.PROVISIONAL_TRASH_HP, "%s trash max HP is provisional" % map_id)
		eq(int(enemy.get("stasis_attack_base", -1)), StasisCatalog.PROVISIONAL_TRASH_ATTACK, "%s trash attack base" % map_id)
		var tiles: Dictionary = snap.get("tiles", {})
		var player_pos: Vector2i = player.get("pos", Vector2i(-1, -1))
		var enemy_pos: Vector2i = enemy.get("pos", Vector2i(-1, -1))
		eq(tiles.has(player_pos), true, "%s player stands on a tile" % map_id)
		eq(tiles.has(enemy_pos), true, "%s foe stands on a tile" % map_id)
		eq(bool(tiles[player_pos].get("walkable", false)), true, "%s player tile is walkable" % map_id)
		eq(bool(tiles[enemy_pos].get("walkable", false)), true, "%s foe tile is walkable" % map_id)
		eq(str(tiles[player_pos].get("terrain_type", "") ) == "lava", false, "%s player is not on lava" % map_id)
		eq(str(tiles[enemy_pos].get("terrain_type", "")) == "lava", false, "%s foe is not on lava" % map_id)
		var apart := maxi(absi(player_pos.x - enemy_pos.x), absi(player_pos.y - enemy_pos.y))
		eq(apart >= 3, true, "%s spawns are not already in melee" % map_id)
	_test_melee_exchange()
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
	eq(StasisCatalog.advance_after_win(), "next", "a win moves to the next trash")
	var next: Dictionary = _sim.reset_match(StasisCatalog.fight_config(pair))
	eq(str(next["units"][1]["name"]), "Grain Hound", "next foe is the grain hound")
	eq(int(next["units"][0]["hp"]), int(carried["units"][0]["hp"]), "player HP carries into the next foe")
	eq(int(next["units"][0]["max_hp"]), 80, "carried HP does not change the Locked player max")


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
