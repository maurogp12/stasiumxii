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
	# Never read the real player saves (gear / levels change fight numbers).
	GearBag.save_path = "user://test_empty_gear_stasis.json"
	HeroProgress.save_path = "user://test_empty_hero_stasis.json"
	StillVault.save_path = "user://test_still_run_stasis_tests.json"
	KoliseoWallet.save_path = "user://test_wallet_run_stasis_tests.json"
	for stale in [GearBag.save_path, HeroProgress.save_path, StillVault.save_path, KoliseoWallet.save_path]:
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(stale))
	_sim = root.get_node_or_null("CombatSim")
	if _sim == null:
		_sim = load("res://backend/combat_sim.gd").new()
		_sim.name = "CombatSim"
		root.add_child(_sim)
	_test_package_and_flow()
	_test_ai()
	_test_boards_and_provisional_hit()
	_test_threshgate_hazards()
	_test_resolve_readout_matches_hit()
	_test_koliseo_strike_unchanged()
	_test_every_room_connected()
	_test_fighters_block_sight()
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
	# Difficulty stars (Mauro: "every star should be a lvl of difficult").
	StasisCatalog.clear_run()
	truthy(StasisCatalog.begin("crosshaven"), "star test gate")
	StasisCatalog.class_id = "kestrel"
	eq(StasisCatalog.star, 1, "a new door starts at ★1")
	var one: Array = StasisCatalog.fight_config()["stasis_roster"]
	eq(int(one[1]["hp"]), StasisCatalog.PROVISIONAL_TRASH_HP, "★1 trash keeps the base HP")
	StasisCatalog.set_star(5)
	var five: Array = StasisCatalog.fight_config()["stasis_roster"]
	eq(int(five[1]["hp"]), roundi(StasisCatalog.PROVISIONAL_TRASH_HP * 3.2), "★5 trash HP x3.2")
	eq(int(five[1]["attack_base"]), roundi(StasisCatalog.PROVISIONAL_TRASH_ATTACK * 2.0), "★5 trash damage x2")
	StasisCatalog.room = "b"
	var boss5: Array = StasisCatalog.fight_config()["stasis_roster"]
	eq(int(boss5[1]["hp"]), roundi(StasisCatalog.PROVISIONAL_BOSS_HP * 3.2), "★5 boss HP x3.2")
	truthy(StasisCatalog.room_banner().contains("★5"), "the banner shows the star")
	StasisCatalog.set_star(9)
	eq(StasisCatalog.star, 5, "stars cap at 5")
	StasisCatalog.set_star(0)
	eq(StasisCatalog.star, 1, "stars floor at 1")
	for value in range(1, 6):
		truthy(StasisCatalog.hp_mult(value) >= StasisCatalog.hp_mult(maxi(value - 1, 1)), "★%d is at least as tough as the star below" % value)
	var run: Node = (load("res://scenes/stasis_run.tscn") as PackedScene).instantiate()
	run._auto_launch = false
	StasisCatalog.clear_run()
	MobileHub.pending_biome_id = "crosshaven"
	root.add_child(run)
	eq(run.star_button_count(), 5, "the door screen offers ★1–★5")
	truthy(run.star_info_text().contains("★1"), "★1 is picked by default")
	run.pick_star(3)
	eq(StasisCatalog.star, 3, "picking ★3 sets the run star")
	truthy(run.star_info_text().contains("Ironveil"), "★3 lists the Rare drops")
	truthy(run.star_info_text().contains("180 XP"), "★3 lists its XP")
	run.free()
	StasisCatalog.clear_run()
	eq(StasisCatalog.star, 1, "leaving resets the star")
	# Foe quality pass: HD art (288x320), a boss flag only on Room B.
	for art in ["warden_of_the_sheaves", "tyrant_coilspire", "cinder_imp", "grain_hound"]:
		var tex := load(StasisCatalog.art_path(art)) as Texture2D
		eq(tex.get_size(), Vector2(288, 320), "%s art is the 2x HD cut" % art)
	StasisCatalog.clear_run()
	StasisCatalog.begin("windmere")
	StasisCatalog.class_id = "kestrel"
	var trash_roster: Array = StasisCatalog.fight_config()["stasis_roster"]
	eq(bool(trash_roster[1].get("boss", false)), false, "room A trash is not a boss")
	StasisCatalog.room = "b"
	var boss_roster: Array = StasisCatalog.fight_config()["stasis_roster"]
	eq(bool(boss_roster[1].get("boss", false)), true, "room B foe is the boss")
	_sim.reset_match(StasisCatalog.fight_config())
	eq(bool(_sim._unit_by_seat(1).get("stasis_boss", false)), true, "the sim unit carries the boss view flag")
	var boss_pawn := Pawn.new()
	root.add_child(boss_pawn)
	boss_pawn.apply_snapshot(_sim._unit_by_seat(1), 0)
	truthy(boss_pawn.get_node_or_null("BossAura") != null, "the boss stands on its aura")
	var trash_pawn := Pawn.new()
	root.add_child(trash_pawn)
	var trash_unit: Dictionary = _sim._unit_by_seat(1).duplicate()
	trash_unit["stasis_boss"] = false
	trash_pawn.apply_snapshot(trash_unit, 0)
	eq(trash_pawn.get_node_or_null("BossAura"), null, "trash has no aura")
	truthy(boss_pawn.head_hp_y() < trash_pawn.head_hp_y(), "the boss name bar sits higher (bigger body)")
	boss_pawn.free()
	trash_pawn.free()
	StasisCatalog.clear_run()


## Mauro 29 Sep 2026: "make sure every room has access or a clear path".
## With the real walk rules, every standable tile and every foe is reachable
## from the player's spawn in all ten rooms.
func _test_every_room_connected() -> void:
	var never := func(_a = null, _b = null) -> bool: return false
	for biome in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		for room in ["a", "b"]:
			StasisCatalog.clear_run()
			StasisCatalog.begin(biome)
			StasisCatalog.class_id = "kestrel"
			StasisCatalog.room = room
			_sim.reset_match(StasisCatalog.fight_config())
			var board = _sim._board
			var units: Array = _sim.snapshot()["units"]
			var reach: Dictionary = board.reachable(units[0]["pos"], 9999, never)
			var lost := 0
			for y in 15:
				for x in 15:
					var c := Vector2i(x, y)
					if board.is_walkable(c) and not board.is_voluntary_impassable(c) and not reach.has(c):
						lost += 1
			eq(lost, 0, "%s room %s: every standable tile is reachable" % [biome, room])
			for u in units.slice(1):
				truthy(reach.has(u["pos"]), "%s room %s: %s stands on a reachable tile" % [biome, room, u["name"]])
			# Mauro 29 Sep 2026 ("still having issues with maps"): no single mud /
			# water tile may force a long walk around (build_tools/fix_stasis_paths.py).
			var worst := 0
			for y in 15:
				for x in 15:
					var w := Vector2i(x, y)
					if not board.is_voluntary_impassable(w) or not board.is_walkable(w):
						continue
					for d in [Vector2i(1, 0), Vector2i(0, 1)]:
						var a: Vector2i = w - d
						var b: Vector2i = w + d
						if not board.in_bounds(a) or not board.in_bounds(b):
							continue
						if not board.is_walkable(a) or board.is_voluntary_impassable(a) or not board.is_walkable(b) or board.is_voluntary_impassable(b):
							continue
						var around: Dictionary = board.reachable(a, 9999, never)
						if around.has(b):
							worst = maxi(worst, int(around[b]["cost"]) - 2)
			truthy(worst <= 6, "%s room %s: no wet tile forces a long detour (worst +%d)" % [biome, room, worst])
	StasisCatalog.clear_run()
	_sim.reset_match({})


## Mauro 30 Sep 2026 ("yes same here"): as in Dofus, a fighter standing on
## the line blocks a shot; an Invisible one does not.
func _test_fighters_block_sight() -> void:
	StasisCatalog.clear_run()
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = "a"
	var cfg: Dictionary = StasisCatalog.fight_config()
	cfg["flat_board"] = true
	_sim.reset_match(cfg)
	var units: Array = _sim._units
	truthy(units.size() >= 3, "room A has a pack to line up")
	units[0]["pos"] = Vector2i(2, 7)
	units[1]["pos"] = Vector2i(4, 7)
	units[2]["pos"] = Vector2i(6, 7)
	if units.size() > 3:
		units[3]["pos"] = Vector2i(12, 12)
	eq(_sim.sight_blocker(Vector2i(2, 7), Vector2i(6, 7)), Vector2i(4, 7), "the front foe blocks the shot at the one behind")
	eq(_has_stasis_cast(0, "mark_shot", Vector2i(6, 7)), false, "no Mark Shot through a fighter")
	eq(_has_stasis_cast(0, "mark_shot", Vector2i(4, 7)), true, "the front foe is still a target")
	units[1]["invisible"] = true
	eq(_sim.has_line_of_sight(Vector2i(2, 7), Vector2i(6, 7)), true, "an Invisible fighter does not block")
	units[1]["invisible"] = false
	units[1]["alive"] = false
	eq(_sim.has_line_of_sight(Vector2i(2, 7), Vector2i(6, 7)), true, "a fallen fighter does not block")
	StasisCatalog.clear_run()
	_sim.reset_match({})


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


func _test_threshgate_hazards() -> void:
	truthy(StasisCatalog.begin("crosshaven"), "hazard check begins Threshgate")
	StasisCatalog.class_id = "ironjaw"
	var snap: Dictionary = _sim.reset_match(StasisCatalog.fight_config())
	var tiles: Dictionary = snap["tiles"]
	var player_pos: Vector2i = snap["units"][0]["pos"]
	eq(str(tiles[player_pos].get("terrain_type", "")), "mud", "Ironjaw opens on the Threshgate mud")
	eq(bool(tiles[player_pos].get("walkable", false)), true, "opening mud stays occupiable")
	_assert_no_voluntary_hazard_walks(0, tiles, "Ironjaw")
	eq(_has_stasis_move(0, Vector2i(8, 12)), true, "Ironjaw can walk off the opening mud onto ground")
	eq(_has_stasis_move(0, Vector2i(7, 11)), false, "the next mud furrow is not a walk dest")
	# Water trough east of (8, 6). A body there stays a Strike target.
	_sim._units[0]["pos"] = Vector2i(8, 6)
	_sim._units[1]["pos"] = Vector2i(9, 6)
	eq(str(_sim.tile_at(Vector2i(9, 6)).get("terrain_type", "")), "water", "the trough cell is water")
	eq(_has_stasis_cast(0, "strike", Vector2i(9, 6)), true, "Strike offers the foe standing on water")
	var struck: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(9, 6), "seat": 0})
	eq(bool(struck.get("ok", false)), true, "Strike hits the foe on the trough (%s)" % str(struck.get("reason", "")))
	eq(_sim._units[1]["pos"], Vector2i(9, 6), "the hit does not shove them off the water")
	var water_walk: Dictionary = _sim.submit({"type": "move", "to": Vector2i(9, 7), "seat": 0})
	eq(str(water_walk.get("reason", "")), "not_walkable", "Walk onto the trough is not_walkable")
	var advanced: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(10, 6), "seat": 0})
	eq(str(advanced.get("reason", "")), "not_walkable", "Advance will not land on the water trough")
	var ground_advance: Dictionary = _sim.submit({"type": "cast", "spell": "advance", "to": Vector2i(8, 4), "seat": 0})
	eq(bool(ground_advance.get("ok", false)), true, "Advance still lands on ground two cardinal north")
	_sim.submit({"type": "end_turn", "seat": 0})
	var foe_seat := int(_sim.snapshot().get("active_seat", -1))
	var foe_tiles: Dictionary = _sim.snapshot()["tiles"]
	_assert_no_voluntary_hazard_walks(foe_seat, foe_tiles, "trash")
	var chosen: Dictionary = StasisAi.choose(_sim.legal_intents(foe_seat), _sim._units[foe_seat]["pos"], _sim._units[0]["pos"])
	if str(chosen.get("type", "")) == "move":
		var stepped := str(_sim.tile_at(chosen["to"]).get("terrain_type", ""))
		eq(stepped == "mud" or stepped == "water" or stepped == "lava", false, "trash AI walk uses the same gates")
	StasisCatalog.clear_run()


func _assert_no_voluntary_hazard_walks(seat: int, tiles: Dictionary, who: String) -> void:
	for intent in _sim.legal_intents(seat):
		if typeof(intent) != TYPE_DICTIONARY or str(intent.get("type", "")) != "move":
			continue
		var dest: Vector2i = intent["to"]
		var terrain := str(tiles[dest].get("terrain_type", ""))
		eq(terrain == "mud" or terrain == "water" or terrain == "lava", false, "%s walk %s is %s" % [who, str(dest), terrain])


func _has_stasis_move(seat: int, dest: Vector2i) -> bool:
	for intent in _sim.legal_intents(seat):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) == "move" and intent.get("to") == dest:
			return true
	return false


func _has_stasis_cast(seat: int, spell_id: String, dest: Vector2i) -> bool:
	for intent in _sim.legal_intents(seat):
		if typeof(intent) != TYPE_DICTIONARY:
			continue
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == spell_id and intent.get("to") == dest:
			return true
	return false


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
	ProjectSettings.set_setting(DebugChrome.OVERLAY_SETTING, false)
	board._sync_overlay(_sim.snapshot())
	var banner := str(board._overlay_status.text)
	eq(banner.contains("Provisional"), false, "the provisional playtest sentence stays off the APK board")
	truthy(banner.contains("Room"), "the room banner stays without the dev sentence")
	_assert_room_tonic(board)
	_fight.free()
	StasisCatalog.clear_run()
	_sim.reset_match({})
	_finish()


## Room Tonic: drinkable only once Room A is won, heals floor(30% max HP)
## without overheal, and the healed HP is what Room B carries.
func _assert_room_tonic(board: Node) -> void:
	var seat := StasisCatalog.PLAYER_SEAT
	var tonic_button := board.find_child("DrinkTonic", true, false) as Button
	truthy(tonic_button != null, "the stasis chrome has a Drink Room Tonic button")
	eq(tonic_button.visible, false, "no tonic mid-fight")
	var w := KoliseoWallet.new()
	w.tonics = 2
	w.save()
	eq(str(board.drink_tonic().get("reason", "")), "not_intermission", "cannot drink during Room A")
	var player: Dictionary = _sim._unit_by_seat(seat)
	var max_hp := int(player["max_hp"])
	player["hp"] = 10
	_sim._match_over = true
	_sim._winner_seat = seat
	board._sync_overlay(_sim.snapshot())
	eq(tonic_button.visible, true, "Room A won: the tonic button shows")
	eq(tonic_button.text, "Drink Room Tonic (2/3)", "button counts the carried tonics")
	var drank: Dictionary = board.drink_tonic()
	eq(bool(drank.get("ok", false)), true, "drink a tonic in the intermission")
	eq(int(drank.get("healed", 0)), int(floor(max_hp * 0.3)), "tonic heals floor(30% max HP)")
	eq(int(_sim._unit_by_seat(seat)["hp"]), 10 + int(floor(max_hp * 0.3)), "the heal lands on the champion")
	eq(KoliseoWallet.load_saved().tonics, 1, "one tonic used")
	_sim._unit_by_seat(seat)["hp"] = max_hp - 2
	drank = board.drink_tonic()
	eq(int(drank.get("healed", 0)), 2, "no overheal past max HP")
	eq(KoliseoWallet.load_saved().tonics, 0, "second tonic used")
	eq(str(board.drink_tonic().get("reason", "")), "no_tonic", "no tonics left")
	w = KoliseoWallet.load_saved()
	w.tonics = 1
	w.save()
	eq(str(board.drink_tonic().get("reason", "")), "full", "full HP keeps the tonic")
	eq(KoliseoWallet.load_saved().tonics, 1, "the tonic was not spent at full HP")
	_sim._winner_seat = 1
	eq(str(board.drink_tonic().get("reason", "")), "not_intermission", "a wipe cannot drink")
	eq(KoliseoWallet.load_saved().tonics, 1, "a wipe keeps the tonic")
	_sim._winner_seat = seat
	StasisCatalog.room = "b"
	eq(str(board.drink_tonic().get("reason", "")), "not_intermission", "no tonic after the boss")
	StasisCatalog.room = "a"


## HIT coach, float, and vitals are one integer. A foe Strike connect is not 0,
## and it does not take the MISS chrome. Locked Strike base stays 16; a back
## hit is that base times 1.20, which rounds to 19.
func _test_resolve_readout_matches_hit() -> void:
	var router: Script = load("res://vfx/vfx_router.gd")
	_sim.reset_match({
		"seed": 1,
		"flat_board": true,
		"rolls": [1],
		"kestrel_pos": Vector2i(3, 3),
		"ironjaw_pos": Vector2i(4, 3),
		"kestrel_facing": "W",
		"ironjaw_facing": "E",
	})
	var preview: Dictionary = _sim.preview_cast("strike", Vector2i(4, 3), Vector2i(3, 3), 0)
	eq(int(preview.get("sample_damage", -1)), 19, "back Strike sample is 16 × 1.20 = 19, not the unfaced 16")
	_sim.submit({"type": "end_turn"})
	var back: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var back_event := _hit_event(back)
	eq(int(back_event.get("damage", -1)), 19, "back Strike applies 19")
	eq(int(back_event.get("base_damage", -1)), 16, "Locked Strike base stays 16")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 61, "applied vitals are 80 − 19")
	truthy(str(back_event.get("coach", "")).begins_with("HIT 19 "), "coach HIT uses 19")
	var back_number := _damage_number(router.recipes_for(back.get("events", [])))
	truthy(str(back_number.get("text", "")).contains("19"), "float shows 19")
	eq(str(back_number.get("text", "")).contains("16"), false, "float does not show the unfaced base 16")
	eq(str(back_number.get("kind", "")), "damage", "a back HIT is not miss chrome")
	eq(_miss_number(router.recipes_for(back.get("events", []))).is_empty(), true, "a HIT event does not emit MISS")

	truthy(StasisCatalog.begin("crosshaven"), "readout fixture begins Threshgate")
	StasisCatalog.class_id = "ironjaw"
	var pair: Array = StasisCatalog.melee_pair("crosshaven")
	var config: Dictionary = StasisCatalog.fight_config(pair)
	config["rolls"] = [1, 1]
	var snap: Dictionary = _sim.reset_match(config)
	var foe: Dictionary = snap["units"][1]
	var player: Dictionary = snap["units"][0]
	var foe_preview: Dictionary = _sim.preview_cast({
		"spell": "strike",
		"from": foe["pos"],
		"to": player["pos"],
		"target_seat": 0,
		"seat": 1,
	})
	var foe_sample := int(foe_preview.get("sample_damage", -1))
	eq(foe_sample == 6 or foe_sample == 7, true, "foe aim sample is provisional 6 × facing, not Strike 16")
	var foe_hp_before := int(foe["hp"])
	var player_hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": foe["pos"], "seat": 0})
	var player_event := _hit_event(player_hit)
	var dealt := int(player_event.get("damage", -1))
	eq(dealt, _faced_damage(16, float(player_event.get("facing_mult", 1.0))), "player HIT damage is Locked base × facing")
	eq(int(_sim.snapshot()["units"][1]["hp"]), foe_hp_before - dealt, "foe vitals drop by the HIT integer")
	truthy(str(player_event.get("coach", "")).begins_with("HIT %d " % dealt), "player coach HIT matches applied damage")
	var player_number := _damage_number(router.recipes_for(player_hit.get("events", [])))
	truthy(str(player_number.get("text", "")).contains(str(dealt)), "player float matches the HIT integer")
	eq(str(player_number.get("kind", "")), "damage", "player HIT is not miss chrome")
	_sim.submit({"type": "end_turn", "seat": 0})
	var mid: Dictionary = _sim.snapshot()
	var player_before := int(mid["units"][0]["hp"])
	var foe_hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": mid["units"][0]["pos"], "seat": 1})
	var foe_event := _hit_event(foe_hit)
	var foe_dealt := int(foe_event.get("damage", 0))
	eq(foe_dealt > 0, true, "enemy Strike connect deals more than 0 to Ironjaw")
	eq(foe_dealt, _faced_damage(StasisCatalog.PROVISIONAL_TRASH_ATTACK, float(foe_event.get("facing_mult", 1.0))), "enemy damage is provisional base × facing once")
	eq(int(_sim.snapshot()["units"][0]["hp"]), player_before - foe_dealt, "Ironjaw vitals drop by the enemy HIT")
	truthy(str(foe_event.get("coach", "")).begins_with("HIT %d " % foe_dealt), "enemy coach HIT matches applied damage")
	var foe_number := _damage_number(router.recipes_for(foe_hit.get("events", [])))
	truthy(str(foe_number.get("text", "")).contains(str(foe_dealt)), "enemy float matches the HIT integer")
	eq(str(foe_number.get("kind", "")), "damage", "enemy HIT is not miss chrome")
	eq(_miss_number(router.recipes_for(foe_hit.get("events", []))).is_empty(), true, "enemy HIT does not emit MISS")
	StasisCatalog.clear_run()


func _damage_number(recipes: Array) -> Dictionary:
	for item in recipes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("id", "")) == "number" and str(item.get("kind", "")) == "damage":
			return item
	return {}


func _miss_number(recipes: Array) -> Dictionary:
	for item in recipes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("text", "")) == "MISS" or str(item.get("kind", "")) == "miss":
			return item
	return {}


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
