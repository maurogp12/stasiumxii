extends SceneTree

const FoeKits := preload("res://backend/foe_kits.gd")

## Mobile Stasis smoke. Two rooms (A trash pack, B boss), package foe art,
## schematic boards, and one CombatSim exchange. Koliseo without stasis_roster
## stays on Strike 14 (Mauro 30 Sep 2026 balance).
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
	_test_party_engine()
	_test_hero_ai_roles()
	_test_ai()
	_test_boards_and_provisional_hit()
	_test_threshgate_hazards()
	_test_resolve_readout_matches_hit()
	_test_koliseo_strike_unchanged()
	_test_every_room_connected()
	_test_fighters_block_sight()
	_test_foe_kits()
	_test_foes_walk_around_walls()
	_test_five_star_boss_forms()
	_start_fight_scene()



## Mauro 2 Oct 2026: same bosses and doors; only the 5-star run shows the
## 5-star form (Crosshaven, Brinewake, Slagcrown). Serra and Coilspire unchanged.
func _test_five_star_boss_forms() -> void:
	var want := {"crosshaven": "sheaf_sovereign", "brinewake": "brineclaw_sovereign", "slagcrown": "slagheart_caldera_crown"}
	for door_id in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		var door: Dictionary = StasisCatalog.DOORS[door_id]
		eq(StasisCatalog.boss_art_for(door, 4), str(door["boss_art"]), "%s keeps its boss below 5 stars" % door_id)
		eq(StasisCatalog.boss_art_for(door, 5), str(want.get(door_id, door["boss_art"])), "%s 5-star boss art" % door_id)
		truthy(FileAccess.file_exists(StasisCatalog.art_path(StasisCatalog.boss_art_for(door, 5))), "%s 5-star portrait exists" % door_id)
	StasisCatalog.clear_run()
	StasisCatalog.begin("brinewake")
	StasisCatalog.set_star(5)
	StasisCatalog.room = "b"
	eq(str(StasisCatalog.current_foe()["art"]), "brineclaw_sovereign", "a 5-star Brinewake run meets the 5-star Brineclaw")
	eq(str(StasisCatalog.current_foe()["name"]), "Tide-Lord Brineclaw", "the boss keeps his name")
	StasisCatalog.clear_run()


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
	eq(int(SpellKits.spell(SpellKits.STRIKE).get("base_damage", -1)), 14, "Strike base is 14 (Mauro 30 Sep 2026 balance)")
	eq(StasisCatalog.PROVISIONAL_TRASH_HP, 22, "provisional trash HP")
	eq(StasisCatalog.PROVISIONAL_TRASH_ATTACK, 6, "provisional trash attack base")
	eq(StasisCatalog.PROVISIONAL_BOSS_HP, 56, "provisional boss HP")
	eq(StasisCatalog.PROVISIONAL_BOSS_ATTACK, 10, "provisional boss attack base")
	var expected := {
		"crosshaven": ["Threshgate", "Sheaf Sovereign", "Plaza Guard", "Riot Club", "Watch Mastiff", "Scribe Bolt"],
		"brinewake": ["Tidehold", "Tide-Lord Brineclaw", "Silt Raider", "Hawser Thug", "Dock Crab", "Gullkin Hex"],
		"slagcrown": ["Ashmarch", "Slagheart (Caldera Crown)", "Cinder Imp", "Slag Mite", "Ash Stalker", "Ember Cantor"],
		"windmere": ["Galevault", "Serra White-Spire Regent", "Ice Warden", "Spire Foot", "Pack Wolf", "White Adept"],
		"stormspire": ["Coilgate", "High Coilspire", "Coil Brute", "Grid Warden", "Spark Hound", "Arc Adept"],
	}
	for map_id in expected.keys():
		var names: Array = expected[map_id]
		eq(StasisCatalog.door_name(map_id), names[0], "%s door name" % map_id)
		eq(StasisCatalog.boss_name(map_id), names[1], "%s boss name" % map_id)
		eq(StasisCatalog.trash_names(map_id, 1), [names[2], names[3], names[4], names[5]], "%s ★1 pack (2 brute, skirmish, caster)" % map_id)
		eq(StasisCatalog.trash_names(map_id, 3).size(), 5, "%s ★3 pack is 5 (3 melee + 2 casters)" % map_id)
	eq(StasisCatalog.begin("brinehaven"), false, "a mixed spelling does not start a gate")
	truthy(StasisCatalog.begin("windmere"), "windmere starts a gate")
	eq(StasisCatalog.room, "a", "a gate opens on room A")
	eq(StasisCatalog.current_foe()["name"], "Ice Warden", "room A names the first trash in the pack")
	eq(StasisCatalog.trash_names().size(), StasisCatalog.PACK_SMALL, "room A at ★1 lists four trash")
	var banner := StasisCatalog.room_banner()
	truthy(banner.contains("Room A"), "banner names room A")
	truthy(banner.contains("Ice Warden") and banner.contains("Pack Wolf") and banner.contains("White Adept"), "room A banner lists the whole pack")
	eq(banner.contains("/3"), false, "room A is not billed as trash 1/3")
	eq(StasisCatalog.continue_caption(), "Enter Room B", "clearing room A offers room B")
	eq(StasisCatalog.advance_after_win(), "next", "room A win is one step into room B")
	eq(StasisCatalog.room, "b", "boss room is B")
	eq(StasisCatalog.current_foe()["name"], "Serra White-Spire Regent", "room B is the boss")
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
	eq(int(five[1]["hp"]), roundi(StasisCatalog.PROVISIONAL_TRASH_HP * 8.8 * 3.2), "★5 trash HP x8.8 (star) x3.2 (party of 4)")
	eq(int(five[1]["attack_base"]), roundi(StasisCatalog.PROVISIONAL_TRASH_ATTACK * 5.2 * 1.6), "★5 trash damage x5.2 x1.6")
	StasisCatalog.room = "b"
	var boss5: Array = StasisCatalog.fight_config()["stasis_roster"]
	eq(int(boss5[1]["hp"]), roundi(StasisCatalog.PROVISIONAL_BOSS_HP * 8.8 * 3.2), "★5 boss HP x8.8 x3.2")
	truthy(StasisCatalog.room_banner().contains("★5"), "the banner shows the star")
	StasisCatalog.set_star(9)
	eq(StasisCatalog.star, 5, "stars cap at 5")
	StasisCatalog.set_star(0)
	eq(StasisCatalog.star, 1, "stars floor at 1")
	for value in range(1, 6):
		truthy(StasisCatalog.hp_mult(value) >= StasisCatalog.hp_mult(maxi(value - 1, 1)), "★%d is at least as tough as the star below" % value)
		truthy(StasisCatalog.dmg_mult(value) >= StasisCatalog.dmg_mult(maxi(value - 1, 1)), "★%d hits at least as hard as the star below" % value)
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


## Mauro's Stasis kit sheets + answers (29 Sep 2026): monster spells as data.
func _boss_fight(biome: String, player_pos: Vector2i, boss_pos: Vector2i, tiles: Array = [], star: int = 1) -> void:
	StasisCatalog.clear_run()
	StasisCatalog.begin(biome)
	StasisCatalog.set_star(star)
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = "b"
	var cfg: Dictionary = StasisCatalog.fight_config()
	cfg["flat_board"] = true
	cfg["positions"] = [player_pos, boss_pos]
	cfg["tiles"] = tiles
	cfg["first_by_init"] = false
	cfg["rolls"] = [1, 1, 1, 1, 1, 1]
	_sim.reset_match(cfg)
	_sim._map_id = biome
	_sim.submit({"type": "end_turn", "seat": 0})


func _has_foe_cast(seat: int, spell_id: String) -> bool:
	for intent in _sim.legal_intents(seat):
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == spell_id:
			return true
	return false


func _test_foe_kits() -> void:
	# Kits and AP on the bosses.
	for biome in FoeKits.BOSS_KITS:
		_boss_fight(biome, Vector2i(7, 12), Vector2i(7, 2))
		var boss: Dictionary = _sim._unit_by_seat(1)
		eq(boss.get("foe_kit", []), FoeKits.BOSS_KITS[biome], "%s boss carries its sheet kit" % biome)
		eq(int(boss["ap"]), 7, "%s boss has 7 AP at ★1" % biome)
	# Sheaf Sovereign: Reap Cone (AOE) then its cooldown.
	_boss_fight("crosshaven", Vector2i(7, 6), Vector2i(7, 7))
	truthy(_has_foe_cast(1, "sheaf.reap"), "Reap Cone is offered when the player stands in the cone")
	eq(str(StasisAi.plan(_sim, 1).get("spell", "")), "sheaf.reap", "the planner opens with the AOE")
	var hp0 := int(_sim._unit_by_seat(0)["hp"])
	var reap: Dictionary = _sim.submit({"type": "cast", "spell": "sheaf.reap", "to": Vector2i(7, 6), "seat": 1})
	eq(bool(reap.get("ok", false)), true, "Reap Cone resolves (%s)" % str(reap.get("reason", "")))
	truthy(int(_sim._unit_by_seat(0)["hp"]) < hp0, "Reap Cone hurts the player")
	eq(int(_sim._unit_by_seat(1)["ap"]), 3, "7 AP − 4 for the AOE leaves 3")
	eq(_has_foe_cast(1, "sheaf.reap"), false, "one AOE per turn")
	truthy(_has_foe_cast(1, "sheaf.thresh"), "Thresh (3) still fits after the AOE")
	_sim.submit({"type": "end_turn", "seat": 1})
	_sim.submit({"type": "end_turn", "seat": 0})
	eq(_has_foe_cast(1, "sheaf.reap"), false, "the AOE skips the next turn (cd)")
	_sim.submit({"type": "end_turn", "seat": 1})
	_sim.submit({"type": "end_turn", "seat": 0})
	truthy(_has_foe_cast(1, "sheaf.reap"), "the AOE is back the turn after")
	# Lunge: dash 1 beside a target at 2, then hit.
	_boss_fight("crosshaven", Vector2i(7, 5), Vector2i(7, 7))
	truthy(_has_foe_cast(1, "sheaf.lunge"), "Lunge reaches a target at 2")
	_sim.submit({"type": "cast", "spell": "sheaf.lunge", "to": Vector2i(7, 5), "seat": 1})
	eq(chebyshev_of(_sim._unit_by_seat(1)["pos"], Vector2i(7, 5)), 1, "Lunge ends beside the target")
	# Brineclaw Hook pulls into water: Breathless stack 1.
	_boss_fight("brinewake", Vector2i(7, 4), Vector2i(7, 7), [{"pos": Vector2i(7, 5), "terrain": "water", "elevation": 0}])
	truthy(_has_foe_cast(1, "brine.hook"), "Hook is a 2–5 shot")
	_sim.submit({"type": "cast", "spell": "brine.hook", "to": Vector2i(7, 4), "seat": 1})
	eq(_sim._unit_by_seat(0)["pos"], Vector2i(7, 5), "Hook pulls the player 1 tile toward Brineclaw")
	eq(int(_sim._unit_by_seat(0).get("breathless_stacks", 0)), 1, "landing in water is Breathless 1")
	eq(_has_foe_cast(1, "brine.hook"), false, "Hook has a cooldown")
	# Serra: White Fan is a line of 5; Retreat Step keeps her out of reach.
	_boss_fight("windmere", Vector2i(7, 3), Vector2i(7, 7))
	truthy(_has_foe_cast(1, "serra.fan"), "White Fan (line 1–5) reaches 4 tiles ahead")
	_boss_fight("windmere", Vector2i(7, 6), Vector2i(7, 7))
	eq(_has_foe_cast(1, "serra.shard"), false, "no Shard inside 3")
	var step := StasisAi.plan(_sim, 1)
	# White Fan also hits 1 ahead; with it on cd she steps away.
	if str(step.get("spell", "")) == "serra.fan":
		_sim.submit(step)
		step = StasisAi.plan(_sim, 1)
	eq(str(step.get("spell", "")), "serra.step", "a crowded Serra steps away")
	# Slagheart Cinder Burst hits all around.
	_boss_fight("slagcrown", Vector2i(8, 8), Vector2i(7, 7))
	truthy(_has_foe_cast(1, "slag.burst"), "Cinder Burst hits a diagonal neighbour")
	# Coilspire Grid Pulse: a Charged pad and the ground beside it.
	_boss_fight("stormspire", Vector2i(3, 3), Vector2i(10, 10), [{"pos": Vector2i(3, 4), "terrain": "water", "elevation": 0}])
	truthy(_has_foe_cast(1, "coil.pulse"), "Grid Pulse hits ground next to a Charged pad")
	_boss_fight("stormspire", Vector2i(3, 3), Vector2i(10, 10))
	eq(_has_foe_cast(1, "coil.pulse"), false, "no pad near the player, no Grid Pulse")
	# Mauro 4 Oct 2026: the 5-star forms' special attacks deal damage.
	_boss_fight("brinewake", Vector2i(7, 3), Vector2i(7, 7), [], 4)
	eq(_sim._unit_by_seat(1).get("foe_kit", []).has("brine.cannon"), false, "★4 Brineclaw has no cannon")
	_boss_fight("brinewake", Vector2i(7, 3), Vector2i(7, 7), [], 5)
	eq(_sim._unit_by_seat(1).get("foe_kit", []).has("brine.cannon"), true, "★5 Brineclaw Sovereign carries the cannon")
	truthy(_has_foe_cast(1, "brine.cannon"), "the cannon reaches a hero at 4")
	eq(str(StasisAi.plan(_sim, 1).get("spell", "")) in ["brine.cannon", "brine.fan"], true, "the planner opens with an area spell")
	var hp_c := int(_sim._unit_by_seat(0)["hp"])
	var shot: Dictionary = _sim.submit({"type": "cast", "spell": "brine.cannon", "to": Vector2i(7, 3), "seat": 1})
	eq(bool(shot.get("ok", false)), true, "the cannon fires (%s)" % str(shot.get("reason", "")))
	truthy(int(_sim._unit_by_seat(0)["hp"]) < hp_c, "the cannon hurts the hero")
	var blast_area: Array = []
	for e in shot.get("events", []):
		if str(e.get("spell", "")) == "brine.cannon":
			blast_area = e.get("area", [])
	eq(blast_area.size(), 9, "the blast covers the 3x3 around the impact")
	eq(_has_foe_cast(1, "brine.cannon"), false, "the cannon has a cooldown")
	_boss_fight("slagcrown", Vector2i(7, 5), Vector2i(7, 7), [], 5)
	eq(_sim._unit_by_seat(1).get("foe_kit", []).has("slag.caldera"), true, "★5 Caldera Crown carries the floor punch")
	truthy(_has_foe_cast(1, "slag.caldera"), "the floor punch reaches a hero 2 tiles away")
	var hp_p := int(_sim._unit_by_seat(0)["hp"])
	var punch: Dictionary = _sim.submit({"type": "cast", "spell": "slag.caldera", "to": Vector2i(7, 7), "seat": 1})
	eq(bool(punch.get("ok", false)), true, "the floor punch resolves (%s)" % str(punch.get("reason", "")))
	truthy(int(_sim._unit_by_seat(0)["hp"]) < hp_p, "the floor punch hurts the hero at 2")
	_boss_fight("slagcrown", Vector2i(7, 4), Vector2i(7, 7), [], 5)
	eq(_has_foe_cast(1, "slag.caldera"), false, "a hero 3 tiles away is outside the punch")
	# Room 1 caster: bolt 3–7 with sight; never walks into 0–1 when it can shoot.
	StasisCatalog.clear_run()
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = "a"
	var cfg: Dictionary = StasisCatalog.fight_config()
	cfg["flat_board"] = true
	cfg["first_by_init"] = false
	_sim.reset_match(cfg)
	var caster_seat := -1
	for u in _sim._units:
		if str(u.get("foe_role", "")) == "caster":
			caster_seat = int(u["seat"])
	truthy(caster_seat > 0, "the ★1 pack has a caster")
	var caster: Dictionary = _sim._unit_by_seat(caster_seat)
	eq(int(caster["max_hp"]), roundi(StasisCatalog.scaled_hp(StasisCatalog.PROVISIONAL_TRASH_HP) * 0.7), "caster HP is 70% of the brute")
	for u in _sim._units:
		if int(u["seat"]) > 0 and int(u["seat"]) != caster_seat:
			u["pos"] = Vector2i(14, int(u["seat"]))
	_sim._units[0]["pos"] = Vector2i(2, 7)
	caster["pos"] = Vector2i(7, 7)
	_sim._active_seat = caster_seat
	truthy(_has_foe_cast(caster_seat, "foe.caster_bolt"), "the caster bolts at 5")
	eq(str(StasisAi.plan(_sim, caster_seat).get("spell", "")), "foe.caster_bolt", "the caster shoots instead of walking")
	caster["pos"] = Vector2i(3, 7)
	eq(_has_foe_cast(caster_seat, "foe.caster_bolt"), false, "no bolt at 1")
	var walk := StasisAi.plan(_sim, caster_seat)
	eq(str(walk.get("type", "")), "move", "a crowded caster walks")
	truthy(chebyshev_of(walk["to"], Vector2i(2, 7)) >= 3, "…out to its bolt band")
	StasisCatalog.clear_run()
	_sim.reset_match({})


## Mauro 30 Sep 2026 ("they get stuck there"): a monster behind a wall walks
## the real route around it instead of parking at the wall.
func _test_foes_walk_around_walls() -> void:
	StasisCatalog.clear_run()
	StasisCatalog.begin("crosshaven")
	StasisCatalog.class_id = "kestrel"
	StasisCatalog.room = "a"
	var cfg: Dictionary = StasisCatalog.fight_config()
	cfg["flat_board"] = true
	cfg["first_by_init"] = false
	var wall: Array = []
	for x in range(2, 13):
		wall.append(Vector2i(x, 5))
	cfg["blockers"] = wall
	_sim.reset_match(cfg)
	var brute: Dictionary = {}
	for u in _sim._units:
		if int(u["seat"]) > 0:
			u["pos"] = Vector2i(14, int(u["seat"]) + 8)
			if brute.is_empty() and str(u.get("foe_role", "")) == "brute":
				brute = u
	brute["pos"] = Vector2i(7, 2)
	_sim._units[0]["pos"] = Vector2i(7, 9)
	var reached := false
	for turn in 8:
		_sim._active_seat = int(brute["seat"])
		brute["mp"] = 3
		brute["ap"] = 6
		for step in 6:
			var intent := StasisAi.plan(_sim, int(brute["seat"]))
			if str(intent.get("type", "")) != "move":
				break
			_sim.submit(intent)
		if chebyshev_of(brute["pos"], Vector2i(7, 9)) <= 1:
			reached = true
			break
	truthy(reached, "the brute walks around the wall and reaches the player (at %s)" % str(brute["pos"]))
	StasisCatalog.clear_run()
	_sim.reset_match({})


func chebyshev_of(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


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
		eq(units.size(), 5, "%s room A at ★1 has the player and four trash" % map_id)
		var order: Array = CombatHUD.turn_order(snap)
		eq(order.size(), 5, "%s turn strip lists the living seats" % map_id)
		eq(int(order[0].get("seat", -1)), 0, "%s turn order starts with the player" % map_id)
		eq(int(order[4].get("seat", -1)) > int(order[0].get("seat", -1)), true, "%s turn order follows seat order" % map_id)
		var cells := {}
		for u in units:
			cells[u["pos"]] = true
		eq(cells.size(), 5, "%s every fighter has its own tile" % map_id)
		var player: Dictionary = units[0]
		var enemy: Dictionary = units[1]
		eq(str(player.get("name", "")), "Kestrel", "%s player keeps the class name" % map_id)
		eq(int(player.get("hp", 0)), 75, "%s player starts at Kestrel 75 HP" % map_id)
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
	eq(str(enemy.get("name", "")), "Plaza Guard", "first foe is the Plaza Guard brute")
	var player_hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": enemy_pos, "seat": 0})
	truthy(bool(player_hit.get("ok", false)), "player Strike resolves (%s)" % str(player_hit.get("reason", "")))
	var player_event := _hit_event(player_hit)
	eq(int(player_event.get("base_damage", -1)), 14, "player Strike keeps base 14")
	eq(int(player_event.get("damage", -1)), _faced_damage(14, float(player_event.get("facing_mult", 1.0))), "player damage uses base 14 times facing")
	var ended: Dictionary = _sim.submit({"type": "end_turn", "seat": 0})
	truthy(bool(ended.get("ok", false)), "player can end the turn")
	var after: Dictionary = _sim.snapshot()
	var player_pos: Vector2i = after["units"][0]["pos"]
	eq(_has_stasis_cast(1, "strike", player_pos), false, "a brute no longer borrows the Strike card")
	var foe_hit: Dictionary = _sim.submit({"type": "cast", "spell": "foe.brute_hit", "to": player_pos, "seat": 1})
	truthy(bool(foe_hit.get("ok", false)), "brute Hit resolves (%s)" % str(foe_hit.get("reason", "")))
	var foe_event := _hit_event(foe_hit)
	eq(str(foe_event.get("spell", "")), "foe.brute_hit", "the brute swings its own kit Hit")
	eq(int(foe_event.get("damage", -1)), _faced_damage(StasisCatalog.PROVISIONAL_TRASH_ATTACK, float(foe_event.get("facing_mult", 1.0))), "brute damage is the provisional base times facing")
	truthy(str(foe_event.get("coach", "")).contains("Hit"), "coach names the Hit")
	var carried: Dictionary = _sim.snapshot()
	StasisCatalog.carry_player_hp(int(carried["units"][0]["hp"]))
	_test_one_trash_does_not_clear_the_room()
	eq(StasisCatalog.advance_after_win(), "next", "a room A win enters room B")
	eq(StasisCatalog.room, "b", "the carried fight is room B")
	var next: Dictionary = _sim.reset_match(StasisCatalog.fight_config())
	eq(next["units"].size(), 2, "room B is the player and the boss")
	eq(str(next["units"][1]["name"]), "Sheaf Sovereign", "room B foe is the Sheaf Sovereign")
	eq(int(next["units"][1].get("max_ap", 0)), 7, "a ★1 boss has 7 AP")
	eq(str(next["units"][1].get("stasis_sprite", "")).contains("ironjaw"), false, "warden portrait is not Ironjaw")
	truthy(str(next["units"][1].get("stasis_sprite", "")).ends_with("warden_of_the_sheaves.png"), "warden uses the scarecrow crop")
	eq(int(next["units"][0]["hp"]), int(carried["units"][0]["hp"]), "player HP carries into room B")
	eq(int(next["units"][0]["max_hp"]), 90, "carried HP does not change the Ironjaw max")


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
		if str(unit.get("name", "")) == "Plaza Guard":
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
	eq(living, 3, "the other three trash stay on the board")


func _test_room_b_board() -> void:
	truthy(StasisCatalog.begin("stormspire"), "coilgate room B begins")
	StasisCatalog.class_id = "kestrel"
	eq(StasisCatalog.advance_after_win(), "next", "coilgate steps into room B")
	var config := StasisCatalog.fight_config()
	var snap: Dictionary = _sim.reset_match(config)
	eq(snap["units"].size(), 2, "coilgate room B is a single boss")
	eq(str(snap["units"][1]["name"]), "High Coilspire", "coilgate boss is High Coilspire")
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
	eq(int(snap["units"][0]["hp"]), 90, "Koliseo Ironjaw HP stays 90")
	eq(int(snap["units"][1]["hp"]), 75, "Koliseo Kestrel HP stays 75")
	eq(snap["units"][1].has("stasis_attack_base"), false, "Koliseo units have no provisional attack")
	var hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": snap["units"][1]["pos"], "seat": 0})
	truthy(bool(hit.get("ok", false)), "Koliseo Strike still resolves")
	var event := _hit_event(hit)
	eq(int(event.get("base_damage", -1)), 14, "Koliseo Strike base stays 14")
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
	eq(snap.get("units", []).size(), 5, "fight scene room A is one pack, not a 1v1")
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
## and it does not take the MISS chrome. Strike base stays 14; a back
## hit is that base times 1.20, which rounds to 17.
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
	eq(int(preview.get("sample_damage", -1)), 17, "back Strike sample is 14 × 1.20 = 17, not the unfaced 14")
	_sim.submit({"type": "end_turn"})
	var back: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": Vector2i(3, 3), "seat": 1})
	var back_event := _hit_event(back)
	eq(int(back_event.get("damage", -1)), 17, "back Strike applies 17")
	eq(int(back_event.get("base_damage", -1)), 14, "Strike base stays 14")
	eq(int(_sim.snapshot()["units"][0]["hp"]), 58, "applied vitals are 75 − 17")
	truthy(str(back_event.get("coach", "")).begins_with("HIT 17 "), "coach HIT uses 17")
	var back_number := _damage_number(router.recipes_for(back.get("events", [])))
	truthy(str(back_number.get("text", "")).contains("17"), "float shows 17")
	eq(str(back_number.get("text", "")).contains("14"), false, "float does not show the unfaced base 14")
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
	eq(foe_sample == 6 or foe_sample == 7, true, "foe aim sample is provisional 6 × facing, not Strike 14")
	var foe_hp_before := int(foe["hp"])
	var player_hit: Dictionary = _sim.submit({"type": "cast", "spell": "strike", "to": foe["pos"], "seat": 0})
	var player_event := _hit_event(player_hit)
	var dealt := int(player_event.get("damage", -1))
	eq(dealt, _faced_damage(14, float(player_event.get("facing_mult", 1.0))), "player HIT damage is base 14 × facing")
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


func _test_party_engine() -> void:
	# Mauro 1 Oct 2026: dungeons for a party of up to 4 heroes (team 0) vs the
	# monsters (team 1); the run is lost only when every hero is down.
	var roster := [
		{"seat": 0, "facing": "N"},
		{"seat": 1, "facing": "N"},
		{"seat": 2, "facing": "N"},
		{"seat": 3, "name": "Brute A", "max_hp": 40, "hp": 40, "facing": "S", "foe_kit": ["foe.brute_hit"], "role": "brute", "door": "crosshaven"},
		{"seat": 4, "name": "Brute B", "max_hp": 40, "hp": 40, "facing": "S", "foe_kit": ["foe.brute_hit"], "role": "brute", "door": "crosshaven"},
	]
	_sim.reset_match({
		"seed": 3,
		"flat_board": true,
		"skip_deploy": true,
		"party_size": 3,
		"classes": ["mender", "ironjaw", "kestrel", "ironjaw"],
		"positions": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 4), Vector2i(9, 9), Vector2i(10, 9)],
		"stasis_roster": roster,
	})
	var snap: Dictionary = _sim.snapshot()
	eq(int(snap.get("party_size", 0)), 3, "the dungeon has a party of 3")
	var units: Array = snap["units"]
	eq(units.size(), 5, "3 heroes and 2 monsters")
	eq(int(units[1]["team"]), 0, "seat 1 is a hero")
	eq(int(units[2]["team"]), 0, "seat 2 is a hero")
	eq(int(units[3]["team"]), 1, "seat 3 is a monster")
	eq(int(units[4]["team"]), 1, "seat 4 is a monster")
	eq(str(units[1]["class_id"]), "ironjaw", "the second hero is the picked class")
	# The Mender heals a hurt party member.
	var active := int(snap["active_seat"])
	for unit in _sim._units:
		if int(unit["seat"]) == 1:
			unit["hp"] = 30
	if active == 0:
		var offered := false
		for intent in _sim.legal_intents(0):
			if str(intent.get("spell", "")) == SpellKits.MEND and int(intent.get("target_seat", -1)) == 1:
				offered = true
		eq(offered, true, "Mend offers a party member")
	# One hero down: the run goes on. All heroes down: the run is lost.
	for unit in _sim._units:
		if int(unit["seat"]) == 0:
			unit["hp"] = 0
			_sim._check_death(unit)
	eq(bool(_sim.snapshot()["match_over"]), false, "one fallen hero does not end the run")
	for unit in _sim._units:
		if int(unit["seat"]) in [1, 2]:
			unit["hp"] = 0
			_sim._check_death(unit)
	eq(bool(_sim.snapshot()["match_over"]), true, "every hero down ends the run")
	eq(int(_sim.snapshot()["winner_seat"]) >= 3, true, "the monsters win")
	# Solo runs are unchanged.
	_sim.reset_match(StasisCatalog.fight_config())
	eq(int(_sim.snapshot().get("party_size", 0)), 1, "a solo run keeps party 1")


## Mauro 4 Oct 2026: "the healer keeps walking towards enemy, he should stay
## range and heal, and Kestrel stay away just looking to hit from distance,
## while Ironjaw and Bastion should focus close combat".
func _hero_ai_board(brute_at: Vector2i) -> void:
	var roster := [
		{"seat": 0, "facing": "N"},
		{"seat": 1, "facing": "N"},
		{"seat": 2, "facing": "N"},
		{"seat": 3, "name": "Brute", "max_hp": 400, "hp": 400, "facing": "S", "foe_kit": ["foe.brute_hit"], "role": "brute", "door": "crosshaven"},
	]
	_sim.reset_match({
		"seed": 5,
		"flat_board": true,
		"skip_deploy": true,
		"party_size": 3,
		"classes": ["mender", "ironjaw", "kestrel", "ironjaw"],
		"positions": [Vector2i(7, 7), Vector2i(7, 9), Vector2i(8, 7), brute_at],
		"stasis_roster": roster,
	})


## Plays one AI turn for `seat`; returns every cell it stood on.
func _hero_ai_turn(seat: int) -> Array:
	_sim._active_seat = seat
	var cells: Array = []
	var HeroAi := load("res://backend/hero_ai.gd")
	for _i in 20:
		var intent: Dictionary = HeroAi.plan(_sim, seat)
		if str(intent.get("type", "")) == "end_turn":
			break
		_sim._last_events = []
		var res: Dictionary = _sim.submit(intent)
		if not bool(res.get("ok", true)):
			break
		for unit in _sim.snapshot()["units"]:
			if int(unit["seat"]) == seat:
				cells.append(unit["pos"])
	return cells


func _test_hero_ai_roles() -> void:
	var HeroAi := load("res://backend/hero_ai.gd")
	eq(HeroAi.role_of("mender"), "healer", "Mender plays the healer")
	eq(HeroAi.role_of("kestrel"), "ranged", "Kestrel plays ranged")
	eq(HeroAi.role_of("ironjaw"), "melee", "Ironjaw plays close combat")
	eq(HeroAi.role_of("bastion"), "melee", "Bastion plays close combat")
	var brute := Vector2i(7, 5)
	# Mender, nobody hurt, an enemy 2 tiles away: steps back, never walks in.
	_hero_ai_board(brute)
	_sim._active_seat = 0
	var first: Dictionary = HeroAi.plan(_sim, 0)
	eq(str(first.get("type", "")), "move", "the Mender steps back first when an enemy is 2 tiles away")
	var mender_cells := _hero_ai_turn(0)
	var closest := 99
	for c in mender_cells:
		closest = mini(closest, chebyshev_of(c, brute))
	eq(closest >= 3, true, "the Mender stays 3+ tiles from the enemy (closest %d)" % closest)
	# Mender heals early: an ally at 80% gets a heal, not a hit or a walk.
	_hero_ai_board(Vector2i(7, 2))
	for unit in _sim._units:
		if int(unit["seat"]) == 1:
			unit["hp"] = int(float(unit["max_hp"]) * 0.8)
	_sim._active_seat = 0
	var heal: Dictionary = HeroAi.plan(_sim, 0)
	eq(str(heal.get("type", "")) == "cast" and int(heal.get("target_seat", -1)) == 1, true, "the Mender heals an ally at 80%")
	# Kestrel: enemy 2 tiles away, steps back first, then shoots from range.
	_hero_ai_board(Vector2i(8, 5))
	_sim._active_seat = 2
	var kestrel_first: Dictionary = HeroAi.plan(_sim, 2)
	eq(str(kestrel_first.get("type", "")), "move", "Kestrel steps back before shooting when an enemy is close")
	var kestrel_cells := _hero_ai_turn(2)
	var k_end: Vector2i = kestrel_cells[-1] if not kestrel_cells.is_empty() else Vector2i(8, 7)
	eq(chebyshev_of(k_end, Vector2i(8, 5)) >= 3, true, "Kestrel ends her turn out of melee reach")
	# Ironjaw closes in on an enemy 4 tiles away.
	_hero_ai_board(Vector2i(7, 13))
	var ij_cells := _hero_ai_turn(1)
	var ij_end: Vector2i = ij_cells[-1] if not ij_cells.is_empty() else Vector2i(7, 9)
	eq(chebyshev_of(ij_end, Vector2i(7, 13)) < 4, true, "Ironjaw walks into close combat")
	# Mauro 4 Oct 2026 ("Bastion and Kestrel not working, the AI just stand"):
	# with the enemy far away the Mender must not walk ahead of the front line
	# (it blocked Bastion's lane), and Kestrel with no shot walks to one.
	_hero_ai_board(Vector2i(7, 1))
	_sim._active_seat = 0
	_hero_ai_turn(0)
	var mender_at: Vector2i
	var tank_at: Vector2i
	for unit in _sim.snapshot()["units"]:
		if int(unit["seat"]) == 0:
			mender_at = unit["pos"]
		if int(unit["seat"]) == 1:
			tank_at = unit["pos"]
	eq(chebyshev_of(mender_at, Vector2i(7, 1)) >= chebyshev_of(tank_at, Vector2i(7, 1)), true, "the Mender is not ahead of the melee teammate (Mender %s, Ironjaw %s)" % [mender_at, tank_at])
	eq(HeroAi._farther_move([{"type": "move", "to": Vector2i(5, 5)}, {"type": "move", "to": Vector2i(3, 3)}], Vector2i(6, 6), [Vector2i(7, 7)]).get("to"), Vector2i(3, 3), "no safe tile: Kestrel still takes the farthest step")
	eq(HeroAi._place_score(Vector2i(5, 5), "melee", [Vector2i(5, 3)], {}, Vector2i(-99, -99)) > HeroAi._place_score(Vector2i(5, 8), "melee", [Vector2i(5, 3)], {}, Vector2i(-99, -99)), true, "a blocked melee lane still walks closer")
	# Mauro 4 Oct 2026: "if anyone dies he should focus in reviving his team
	# mate". Ironjaw down 4 tiles away, Mender on full Pulse: walk into reach
	# first (no AP spent), then Rekindle.
	_hero_ai_board(Vector2i(13, 13))
	for unit in _sim._units:
		if int(unit["seat"]) == 1:
			unit["pos"] = Vector2i(7, 11)
			unit["hp"] = 0
			_sim._check_death(unit)
		if int(unit["seat"]) == 0:
			unit["pulse"] = 6
	_sim._active_seat = 0
	var go: Dictionary = HeroAi.plan(_sim, 0)
	eq(str(go.get("type", "")), "move", "the Mender walks to the fallen teammate before spending AP")
	if str(go.get("type", "")) == "move":
		eq(chebyshev_of(_cell_of(go["to"]), Vector2i(7, 11)) <= 2, true, "the Mender stops within Rekindle reach")
		_sim.submit(go)
	var raise: Dictionary = HeroAi.plan(_sim, 0)
	eq(str(raise.get("spell", "")), SpellKits.REKINDLE, "then the Mender casts Rekindle")
	# Short of Pulse: earn it with Mend, never spend it.
	_hero_ai_board(Vector2i(13, 13))
	for unit in _sim._units:
		if int(unit["seat"]) == 1:
			unit["pos"] = Vector2i(7, 11)
			unit["hp"] = 0
			_sim._check_death(unit)
		if int(unit["seat"]) == 0:
			unit["pulse"] = 3
	var spent := false
	var built := false
	_sim._active_seat = 0
	for _i in 8:
		var step: Dictionary = HeroAi.plan(_sim, 0)
		if str(step.get("type", "")) == "end_turn":
			break
		var sdef := SpellKits.spell(str(step.get("spell", "")))
		if str(sdef.get("engine_on_connect", "")) == "spend_pulse":
			spent = true
		if str(sdef.get("engine_on_connect", "")) == "pulse":
			built = true
		_sim._last_events = []
		_sim.submit(step)
	eq(built, true, "the Mender earns Pulse with Mend while a teammate is down")
	eq(spent, false, "the Mender spends no Pulse while a teammate is down")
	_sim.reset_match(StasisCatalog.fight_config())


func _cell_of(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	return Vector2i(int(value[0]), int(value[1]))


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
