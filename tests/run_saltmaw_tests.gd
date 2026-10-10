extends SceneTree

## PC dungeon 3, the Saltmaw Grotto (Eastmarch, levels 20-30): the door and
## its grotto rock in Eastmarch, the run file and rooms (every cell reachable,
## props and the whirlpool's rock spires break lines), pack sizes per star,
## the AI always ending its turn, Drowned Harpooner line of sight and kiting,
## Old Saltmaw's Lantern Lure (signature kind pull: rhythm, range, line of
## sight, where the hero stops), the ★5 Abyssal Saltmaw and his riptide (drag
## hazard), the abyssal soak and the rinsing pads, rewards per star, the
## Eastmarch mission, a full run in the room scene, and guards that the Old
## Granary Cellar and the Frostspire Archive still play exactly as before.
## Run: godot --headless --path . -s res://tests/run_saltmaw_tests.gd

const Dungeons := preload("res://backend/world_dungeons.gd")
const Monsters := preload("res://backend/pc_monsters.gd")
const Run := preload("res://backend/pc_dungeon_run.gd")
const AI := preload("res://backend/dungeon_ai.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const NpcBook := preload("res://backend/world_npcs.gd")
const Missions := preload("res://backend/pc_missions.gd")
const Progress := preload("res://backend/pc_progress.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const Launcher := preload("res://scenes/world/dungeon/dungeon_launcher.gd")
const Regions := preload("res://backend/world_regions.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const RUN_SCENE_PATH := "res://scenes/world/dungeon/dungeon_run.tscn"
const SALT := "saltmaw_grotto"
const FROST := "frostspire_archive"
const GRANARY := "old_granary_cellar"
const ZONE := "crosshaven_eastmarch"
const DOOR := Vector2i(26, 17)
const KEEPER := Vector2i(25, 17)
const LEVEL := 22
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
## The art kit's board props (build_rooms.py KIT_PROPS), checked against the
## manifest once it lists them.
const KIT_PROPS: Array[String] = ["barnacle_rock", "coral_cluster", "sunken_crate", "barrel", "giant_clam", "anchor", "treasure_chest", "sunken_statue", "rock_spire"]
## Room A uses only the props both rooms share (the art kit's room tags).
const ROOM_A_PROPS: Array[String] = ["sunken_crate", "barrel", "coral_cluster", "anchor", "barnacle_rock"]

var _passed := 0
var _failed := 0
var sim: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Regions.set_enabled(true)
	Launcher.dry_run = true
	sim = root.get_node("CombatSim")
	_test_door_data()
	_test_run_file_and_rooms()
	_test_monsters()
	_test_packs_per_star()
	_test_ai_always_ends()
	_test_harpooner_los_and_kiting()
	_test_lantern_lure()
	_test_lure_line_and_stops()
	_test_star5_riptide()
	_test_soak_and_rinse()
	_test_rewards_per_star()
	_test_mission_credit()
	_test_others_unchanged()
	await _test_world_door_and_panel()
	await _test_run_scene_win_and_return()
	_finish()


func _finish() -> void:
	print("saltmaw tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- door ------------------------------------------------------------------------

func _test_door_data() -> void:
	var loaded: Dictionary = Dungeons.load_default()
	eq(bool(loaded.get("ok", false)), true, "dungeons.json loads: %s" % [loaded.get("errors", [])])
	var book = loaded["dungeons"]
	var row: Dictionary = book.by_id(SALT)
	eq(str(row.get("status", "")), "built", "the Saltmaw Grotto is built")
	eq(str(row["level_zone"]), "eastmarch", "it is Eastmarch's dungeon")
	eq([int(row["level_min"]), int(row["level_max"])], [20, 30], "levels 20-30")
	eq(str(row["boss"]), "Old Saltmaw", "the boss is Old Saltmaw")
	eq(Dungeons.door_cell(row), DOOR, "the grotto door is at 26,17")
	eq(str(row["door"]["zone_id"]), ZONE, "the door is in the Eastmarch chunk")
	eq(str(row["run"]), "res://data/world/dungeons/saltmaw_grotto/run.json", "the run file is named")
	var shape: Dictionary = Dungeons.building_shape(row)
	if not shape.is_empty():
		eq(shape.get("size", Vector2i.ZERO), Vector2i(3, 3), "the grotto rock is 3x3 (manifest footprint)")
		eq(shape.get("door_from_nw", Vector2i.ZERO), Vector2i(1, 3), "the door is at the footprint's (1,3), the pier end")
	var building := Dungeons.building_cells_for(row)
	eq(building.size(), 9, "nine building cells")
	eq(building.has(DOOR + Vector2i(0, -1)), true, "the cave mouth cell is just north of the door")
	for c in building:
		eq(c.x >= 25 and c.x <= 27 and c.y >= 14 and c.y <= 16, true, "building cell %s on 25-27 x 14-16" % c)
	var atlas = Atlas.load_default()["atlas"]
	var npcs = NpcBook.load_default()["npcs"]
	var checked: Dictionary = book.validate_world(atlas, npcs, Art.building_size(Art.manifest(_granary_art()), Dungeons.DEFAULT_BUILDING))
	eq(bool(checked["ok"]), true, "4.6 rules hold with all three doors: %s" % [checked["errors"]])
	var zone: WorldZone = atlas.map_for_chunk(ZONE).zone(ZONE)
	eq(zone.passable_at(DOOR), true, "the door cell is passable")
	eq(zone.in_bounds(DOOR), true, "the door is inside the chunk")
	eq(zone.exit_link(DOOR).is_empty(), true, "the door is not an exit")
	eq(atlas.gate_at(ZONE, DOOR).is_empty(), true, "the door is not a gate")
	eq(DOOR != zone.spawn, true, "the door is not the spawn")
	for c in building:
		eq(zone.passable_at(c), true, "building cell %s is open ground before the rock blocks it" % c)
	for npc in npcs.for_zone(ZONE):
		var at := Vector2i(int(npc["cell"]["x"]), int(npc["cell"]["y"]))
		eq(at != DOOR and not building.has(at), true, "%s is not on the door or the building" % npc["id"])
	var keeper: Dictionary = npcs.by_id("eastmarch_door_keeper")
	eq(str(keeper["role"]), "door_keeper", "the Eastmarch Door Keeper is a door keeper")
	eq(Vector2i(int(keeper["cell"]["x"]), int(keeper["cell"]["y"])), KEEPER, "the Door Keeper stands beside the door (origin+(0,3))")
	eq(book.for_keeper("eastmarch_door_keeper").get("id", ""), SALT, "the keeper opens the grotto")
	eq(str((keeper["lines"] as Array).back()).contains("Saltmaw"), true, "the keeper warns of Old Saltmaw")
	eq(Dungeons._door_reachable(zone, DOOR, building, npcs), true, "the door can be walked to from the chunk spawn round the rock")
	# A door moved onto the keeper or out of Eastmarch fails.
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Dungeons.PATH))
	var on_npc: Dictionary = base.duplicate(true)
	(on_npc["dungeons"] as Array)[2]["door"] = {"zone_id": ZONE, "x": KEEPER.x, "y": KEEPER.y}
	eq(bool(Dungeons.load_document(on_npc)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a grotto door on the keeper fails")
	var away: Dictionary = base.duplicate(true)
	(away["dungeons"] as Array)[2]["door"] = {"zone_id": "crosshaven_northgate", "x": 26, "y": 17}
	eq(bool(Dungeons.load_document(away)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a grotto door outside Eastmarch fails")
	eq(book.built().size(), 3, "three dungeons are built")


# --- run file and rooms --------------------------------------------------------

func _test_run_file_and_rooms() -> void:
	var made: Dictionary = Run.create(SALT, LEVEL, "kestrel")
	eq(bool(made.get("ok", false)), true, "the grotto run builds: %s" % [made.get("errors", [])])
	if not bool(made.get("ok", false)):
		return
	var run = made["run"]
	eq(run.level, LEVEL, "a level 22 hero runs at level 22")
	eq(int(Run.create(SALT, 40, "kestrel")["run"].level), 30, "an over-band hero meets level 30 monsters")
	eq(int(Run.create(SALT, 5, "kestrel")["run"].level), 20, "an under-band hero meets level 20 monsters")
	eq(run.room_count(), 2, "room A then room B")
	eq([str(run.room(0)["kind"]), str(run.room(1)["kind"])], ["pack", "boss"], "a pack room, then the boss")
	eq(str(run.run_doc["art"]), "res://art/pc/dungeons/saltmaw_grotto/manifest.json", "the art manifest is the grotto kit")
	eq(str(run.text("stairs")).contains("tide"), true, "the stairs line is the grotto's")
	eq(run.text("return_button"), "Return to Eastmarch", "the return button names Eastmarch")
	eq(str((run.run_doc["text"] as Dictionary).get("star5_rule", "")).contains("Riptide"), true, "the ★5 rule text lives in the run file")
	eq(str((run.run_doc["text"] as Dictionary).get("signature_rule", "")).contains("Lantern Lure"), true, "the lure rule text lives in the run file")
	var man := Art.manifest(str(run.run_doc["art"]))
	var kit_props := {}
	if bool(man.get("ok", false)) and typeof((man.get("raw", {}) as Dictionary).get("board", null)) == TYPE_DICTIONARY:
		for row in (man["raw"]["board"].get("props", []) as Array):
			kit_props[str(row["id"])] = row
	if kit_props.is_empty():
		for id in KIT_PROPS:
			kit_props[id] = {}
	for index in 2:
		var config: Dictionary = run.combat_config(index, 3)
		var room: Dictionary = config["dungeon"]
		var label := str(room["room_id"])
		eq(int(config["board_size"]), 12, "%s is 12x12" % label)
		eq(bool(room["pad_thaw"]), true, "%s pads rinse" % label)
		eq(int(room["pad_heal"]), 5, "%s pads heal 5" % label)
		var cells: Array = room["cells"]
		eq(cells.size(), 144, "%s tags list every cell" % label)
		var walk := {}
		var blocked := 0
		var pads := 0
		for rec in cells:
			var c: Vector2i = rec["pos"]
			if bool(rec["blocks"]):
				blocked += 1
				var prop := str((rec["paint_only"] as Array)[0]).trim_suffix(":part")
				eq(kit_props.has(prop), true, "%s prop %s at %s is an art kit prop" % [label, prop, c])
				if index == 0:
					eq(ROOM_A_PROPS.has(prop), true, "room A prop %s at %s is a shared kit prop" % [prop, c])
			else:
				walk[c] = true
			if str(rec["special"]) != "":
				pads += 1
		eq(blocked >= 6, true, "%s has prop obstacles (%d)" % [label, blocked])
		eq(pads >= 4, true, "%s has glowing pads (%d)" % [label, pads])
		var hero: Vector2i = room["hero"]["pos"]
		var seen := _flood(walk, hero, {})
		eq(seen.size(), walk.size(), "%s every walkable cell is reachable" % label)
		sim.reset_match(config)
		var snap: Dictionary = sim.snapshot()
		eq((snap["dungeon"]["pads"] as Array).size(), pads, "%s pads reach the sim" % label)
		for rec in cells:
			if bool(rec["blocks"]):
				eq(bool(sim.tile_at(rec["pos"]).get("walkable", true)), false, "%s prop cell %s blocks" % [label, rec["pos"]])
		var cut := 0
		var lines := 0
		for y in 5:
			for x in 12:
				var at := Vector2i(x, y)
				if walk.has(at):
					lines += 1
					if not bool(sim.has_los(at, hero)):
						cut += 1
		eq(cut > 0, true, "%s props cut some lines of fire onto the hero start (%d of %d)" % [label, cut, lines])
		eq(cut < lines, true, "%s props never cut every line (%d of %d)" % [label, cut, lines])
	var b_cells: Array = run.combat_config(1, 1)["dungeon"]["cells"]
	var whirl := 0
	var water := 0
	var spires := 0
	var b_walk := {}
	for rec in b_cells:
		var c: Vector2i = rec["pos"]
		if not bool(rec["blocks"]):
			b_walk[c] = true
		if (rec["paint_only"] as Array).has("whirlpool"):
			whirl += 1
			eq(c.x >= 4 and c.x <= 8 and c.y >= 4 and c.y <= 8, true, "whirlpool cell %s is on the 5x5 decal (4-8 x 4-8)" % c)
			if str(rec["special"]) != "":
				water += 1
				eq(c.x >= 5 and c.x <= 7 and c.y >= 5 and c.y <= 7, true, "pad %s is on the inner 3x3 water" % c)
		if (rec["paint_only"] as Array).has("rock_spire"):
			spires += 1
			eq((rec["paint_only"] as Array).has("whirlpool"), true, "spire %s stands on the kerb" % c)
	eq(whirl, 25, "room B's whirlpool decal covers 5x5 cells")
	eq(water, 9, "its inner 3x3 water is the room's pads")
	eq(spires, 7, "seven rock spires on the kerb, with gaps")
	eq(_flood(b_walk, Vector2i(6, 10), {}).has(Vector2i(6, 6)), true, "the whirlpool's centre is reachable through the gaps")
	var a_cells: Array = run.combat_config(0, 1)["dungeon"]["cells"]
	var coral := 0
	for rec in a_cells:
		if (rec["paint_only"] as Array).has("coral_pad"):
			coral += 1
	eq(coral >= 4, true, "room A has teal coral pads (%d)" % coral)


func _test_monsters() -> void:
	var book = Monsters.load_default()["monsters"]
	var ids: Array = book.ids_for(SALT)
	eq(ids, ["reef_crab", "drowned_sailor", "drowned_harpooner", "old_saltmaw", "abyssal_reef_crab", "abyssal_drowned_sailor", "abyssal_drowned_harpooner", "abyssal_saltmaw"], "the grotto's eight monsters")
	for id in ids:
		var lo: Dictionary = book.stats_at(id, 20)
		var hi: Dictionary = book.stats_at(id, 30)
		eq(int(lo["level"]), 20, "%s starts at level 20" % id)
		eq(int(book.stats_at(id, 1)["level"]), 20, "%s clamps up to its band" % id)
		eq(int(hi["hp"]) > int(lo["hp"]), true, "%s grows through 20-30" % id)
		eq(str(lo["dungeon"]), SALT, "%s belongs to the grotto" % id)
	var crab: Dictionary = book.stats_at("reef_crab", LEVEL)
	var sailor: Dictionary = book.stats_at("drowned_sailor", LEVEL)
	var harp: Dictionary = book.stats_at("drowned_harpooner", LEVEL)
	var boss: Dictionary = book.stats_at("old_saltmaw", LEVEL)
	eq(int(crab["mp"]), 2, "the Reef Crab is slow (2 MP)")
	eq(int(crab["hp"]) > int(sailor["hp"]) and int(crab["hp"]) > int(harp["hp"]) * 2, true, "the Reef Crab is the tank")
	eq(int(crab["attack"]["max_range"]), 1, "the Reef Crab is melee")
	eq(int(sailor["attack"]["max_range"]), 1, "the Drowned Sailor is melee")
	eq(str(sailor["attack"]["name"]), "Cutlass Slash", "the Drowned Sailor swings a cutlass")
	eq(int(sailor["ap"]) / int(sailor["attack"]["ap"]), 2, "the Drowned Sailor swings twice a turn")
	eq([int(harp["attack"]["min_range"]), int(harp["attack"]["max_range"])], [2, 5], "the Drowned Harpooner throws at 2-5")
	eq(bool(harp["attack"]["los"]), true, "the Harpoon Throw needs a line of sight")
	eq(str(harp["attack"]["projectile"]), "harpoon", "the throw flies as harpoon")
	eq(str(harp["attack"]["impact"]), "harpoon_impact", "and bursts in harpoon_impact")
	eq(bool(boss["boss"]), true, "Old Saltmaw is the boss")
	var sig: Dictionary = boss["signature"]
	eq([str(sig["name"]), str(sig["kind"])], ["Lantern Lure", "pull"], "Lantern Lure is a pull")
	eq([int(sig["cells"]), int(sig["min_range"]), int(sig["max_range"]), bool(sig["los"])], [2, 2, 6, true], "it pulls 2 cells from 2-6 with a line")
	eq([int(sig["first_turn"]), int(sig["every"])], [1, 2], "on his 1st turn and every 2nd after")
	eq(int(boss["ap"]) >= int(sig["ap"]) + int(boss["attack"]["ap"]), true, "he can lure and bite in one turn")
	var abyss: Dictionary = book.stats_at("abyssal_saltmaw", LEVEL, 5)
	eq(str(abyss["signature"]["kind"]), "pull", "the Abyssal Saltmaw lures too")
	eq(int(abyss["signature"]["cells"]) > int(sig["cells"]), true, "his lure pulls further")
	eq(str(abyss["signature2"]["kind"]), "hazard", "his second move lays a ground hazard")
	eq(str(abyss["signature2"]["hazard"]), "riptide", "the hazard is riptide")
	eq(int(abyss["signature2"]["drag"]), 1, "riptide drags 1 cell")
	eq(int(abyss["hp"]) > int(book.stats_at("old_saltmaw", LEVEL, 5)["hp"]), true, "the mutated form is tougher than Old Saltmaw at ★5")
	for id in ["abyssal_reef_crab", "abyssal_drowned_sailor", "abyssal_drowned_harpooner"]:
		var st: Dictionary = book.stats_at(id, LEVEL, 5)
		eq(str((st["attack"].get("chill", {}) as Dictionary).get("word", "")), "soaked", "%s soaks" % id)
		eq(str(st["variant_of"]) != "", true, "%s is a mutated form" % id)
	eq(str(book.stats_at("abyssal_drowned_harpooner", LEVEL, 5)["attack"]["projectile"]), "abyssal_harpoon", "abyssal harpoons fly as abyssal_harpoon")
	var check: Dictionary = book.check(LEVEL)
	eq(bool(check["ok"]), true, "level 22 numbers pass the sanity pass: %s" % [check["findings"]])
	var rows: Dictionary = book.stars_for(SALT)["scale"]
	for star in range(1, 6):
		var m: Array = book.star_scale(star, SALT)
		eq(m, [float(rows[str(star)][0]), float(rows[str(star)][1])], "★%d grotto row comes from its own star block" % star)
	var prev := 0.0
	for star in range(1, 5):
		var m2: Array = book.star_scale(star, SALT)
		eq(float(m2[0]) >= prev, true, "★%d grotto HP row is not softer than the star below" % star)
		prev = float(m2[0])
	# Bad pull rows fail the load.
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Monsters.PATH))
	for row in doc["monsters"]:
		if str(row["id"]) == "old_saltmaw":
			(row["signature"] as Dictionary).erase("cells")
	eq(bool(Monsters.load_document(doc)["ok"]), false, "a pull without cells fails the load")
	var doc2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Monsters.PATH))
	for row in doc2["monsters"]:
		if str(row["id"]) == "old_saltmaw":
			row["signature"]["kind"] = "teleport"
	eq(bool(Monsters.load_document(doc2)["ok"]), false, "an unknown signature kind fails the load")


# --- stars and packs ------------------------------------------------------------

func _test_packs_per_star() -> void:
	var expect := {
		1: {"reef_crab": 2, "drowned_sailor": 2, "drowned_harpooner": 2},
		2: {"reef_crab": 2, "drowned_sailor": 2, "drowned_harpooner": 2},
		3: {"reef_crab": 2, "drowned_sailor": 2, "drowned_harpooner": 3},
		4: {"reef_crab": 2, "drowned_sailor": 2, "drowned_harpooner": 3},
		5: {"abyssal_reef_crab": 2, "abyssal_drowned_sailor": 2, "drowned_sailor": 1, "abyssal_drowned_harpooner": 3},
	}
	var totals := {1: 6, 2: 6, 3: 7, 4: 7, 5: 8}
	var hp_by_star := {}
	for star in range(1, 6):
		var run = Run.create(SALT, LEVEL, "kestrel", "", star)["run"]
		var room: Dictionary = run.combat_config(0, 1)["dungeon"]
		var got := {}
		var ranged := 0
		var pack_hp := 0
		for m in room["monsters"]:
			got[str(m["monster"])] = int(got.get(str(m["monster"]), 0)) + 1
			pack_hp += int(m["hp"])
			if bool((m["attack"] as Dictionary).get("los", false)):
				ranged += 1
		hp_by_star[star] = pack_hp
		eq(got, expect[star], "★%d room A pack" % star)
		eq((room["monsters"] as Array).size(), totals[star], "★%d room A has %d monsters (6+)" % [star, totals[star]])
		eq(ranged >= 2, true, "★%d room A has ranged Drowned Harpooners (%d)" % [star, ranged])
		var walk := {}
		var pads := {}
		for rec in room["cells"]:
			if not bool(rec["blocks"]):
				walk[rec["pos"]] = true
			if str(rec["special"]) != "":
				pads[rec["pos"]] = true
		var hero: Vector2i = room["hero"]["pos"]
		var taken := {}
		for m in room["monsters"]:
			var at: Vector2i = m["pos"]
			eq(walk.has(at) and not pads.has(at), true, "★%d %s spawns on open floor, off the pads" % [star, m["monster"]])
			eq(at.y <= 4 and maxi(absi(at.x - hero.x), absi(at.y - hero.y)) >= 6, true, "★%d %s starts on the far rows" % [star, m["monster"]])
			eq(taken.has(at), false, "★%d spawns do not overlap" % star)
			taken[at] = true
		eq(_flood(walk, hero, taken).size(), walk.size() - taken.size(), "★%d the pack leaves every route open" % star)
		var boss_room: Dictionary = run.combat_config(1, 1)["dungeon"]
		var mons: Array = boss_room["monsters"]
		eq(mons.size(), 4, "★%d room B: the boss and a 3-strong escort" % star)
		eq(bool(mons[0]["boss"]), true, "★%d room B leads with the boss" % star)
		eq(str(mons[0]["monster"]), "abyssal_saltmaw" if star == 5 else "old_saltmaw", "★%d boss form" % star)
		var escort := {}
		for m in mons.slice(1):
			escort[str(m["monster"])] = int(escort.get(str(m["monster"]), 0)) + 1
		var want := {"abyssal_drowned_sailor": 1, "abyssal_drowned_harpooner": 1, "abyssal_reef_crab": 1} if star == 5 else {"drowned_sailor": 1, "drowned_harpooner": 1, "reef_crab": 1}
		eq(escort, want, "★%d escort: a sailor, a harpooner and a crab" % star)
		eq((boss_room["summons"] as Dictionary).has(""), false, "★%d a pull signature carries no summon stats" % star)
	for star in range(2, 5):
		eq(int(hp_by_star[star]) >= int(hp_by_star[star - 1]), true, "★%d room A pack is not weaker than ★%d" % [star, star - 1])


func _test_ai_always_ends() -> void:
	var stuck := 0
	var unfinished := 0
	var monster_turns := 0
	var shots := 0
	var lures := 0
	for cls in CLASSES:
		for star in [1, 5]:
			var run = Run.create(SALT, LEVEL, cls, "", star)["run"]
			for index in 2:
				sim.reset_match(run.combat_config(index, 60 + star))
				var guard := 0
				var limit := 1600 if cls == "mender" else 600
				while not bool(sim.snapshot()["match_over"]) and guard < limit:
					guard += 1
					var seat := int(sim.snapshot()["active_seat"])
					if seat == 0:
						AI.play_hero_turn(sim)
						continue
					monster_turns += 1
					var done := AI.play_monster_turn(sim, seat)
					if done.size() > AI.MAX_STEPS + 1:
						unfinished += 1
					for d in done:
						if bool(d["intent"].get("forced", false)):
							stuck += 1
						if str(d["intent"].get("spell", "")) in ["harpoon_throw", "abyssal_harpoon_throw"] and bool(d["ok"]):
							shots += 1
						if str(d["intent"].get("spell", "")) in ["lantern_lure", "abyssal_lure"] and bool(d["ok"]):
							lures += 1
					var after: Dictionary = sim.snapshot()
					if not bool(after["match_over"]) and int(after["active_seat"]) == seat:
						unfinished += 1
				if guard >= limit:
					unfinished += 1
				if str(sim.snapshot()["dungeon"]["result"]) != "win":
					break
	eq(monster_turns > 100, true, "monster turns were played (%d)" % monster_turns)
	eq(shots > 20, true, "Drowned Harpooners find lines and throw (%d)" % shots)
	eq(lures > 3, true, "Old Saltmaw lures in real fights (%d)" % lures)
	eq(stuck, 0, "no monster turn needed a forced end")
	eq(unfinished, 0, "every monster turn ends and every fight finishes")


func _test_harpooner_los_and_kiting() -> void:
	var book = Monsters.load_default()["monsters"]
	var harp: Dictionary = book.stats_at("drowned_harpooner", LEVEL, 1)
	var spell := str(harp["attack"]["id"])
	var cells: Array = []
	for y in 12:
		for x in 12:
			var wall := x == 5 and y >= 2 and y <= 9
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["barnacle_rock"] if wall else [], "blocks": wall, "special": ""})
	var a := harp.duplicate(true)
	a["pos"] = Vector2i(2, 5)
	a["facing"] = "E"
	var room := {"dungeon_id": "t", "room_id": "lane", "room_name": "Lane", "kind": "pack", "cells": cells, "pad_heal": 0, "hero": {"class_id": "kestrel", "pos": Vector2i(8, 5), "facing": "W"}, "monsters": [a], "summons": {}}
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room})
	eq(bool(sim.has_los(Vector2i(2, 5), Vector2i(8, 5))), false, "a rock wall blocks the harpoon's line")
	sim.submit({"type": "end_turn", "seat": 0})
	var can_throw := false
	for i in sim.legal_intents(1):
		if str(i.get("spell", "")) == spell:
			can_throw = true
	eq(can_throw, false, "no throw without a line of sight")
	AI.play_monster_turn(sim, 1)
	eq(int(sim.snapshot()["active_seat"]), 0, "the harpooner ends its turn (no deadlock)")
	eq(sim._unit_by_seat(1)["pos"] != Vector2i(2, 5), true, "it moves to find a line")
	a["pos"] = Vector2i(7, 5)
	room["monsters"] = [a]
	for c in cells:
		c["blocks"] = false
		c["paint_only"] = []
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room, "rolls": [1, 1, 1, 1]})
	sim.submit({"type": "end_turn", "seat": 0})
	var kinds: Array = []
	for d in AI.play_monster_turn(sim, 1):
		kinds.append(str(d["intent"]["type"]) + ":" + str(d["intent"].get("spell", "")))
	eq(kinds.size() >= 2 and str(kinds[0]).begins_with("move") and kinds.has("cast:" + spell), true, "adjacent, the harpooner steps back, then throws (%s)" % [kinds])
	var spot: Vector2i = sim._unit_by_seat(1)["pos"]
	eq(maxi(absi(spot.x - 8), absi(spot.y - 5)) >= 2, true, "it throws from range 2+")
	a["pos"] = Vector2i(5, 5)
	room["monsters"] = [a]
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room, "rolls": [1, 1, 1, 1]})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": spell, "to": Vector2i(8, 5), "target_seat": 0, "seat": 1})
	var projectile := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("projectile", "")) != "":
			projectile = str(e["projectile"]) + "/" + str(e.get("impact", ""))
	eq(projectile, "harpoon/harpoon_impact", "the throw event names its projectile and impact for the view")


# --- Old Saltmaw: Lantern Lure ----------------------------------------------------

## An open 12x12 room with Old Saltmaw alone at `boss_at` and the hero at `hero_at`.
func _lure_room(boss_at: Vector2i, hero_at: Vector2i, props: Dictionary = {}, extra: Array = [], star: int = 1) -> Dictionary:
	var book = Monsters.load_default()["monsters"]
	var boss: Dictionary = book.stats_at("old_saltmaw" if star < 5 else "abyssal_saltmaw", LEVEL, star)
	boss["pos"] = boss_at
	boss["facing"] = "S"
	var cells: Array = []
	for y in 12:
		for x in 12:
			var c := Vector2i(x, y)
			cells.append({"pos": c, "terrain": "ground", "elevation": 0, "paint_only": [str(props[c])] if props.has(c) else [], "blocks": props.has(c), "special": ""})
	var mons: Array = [boss]
	for e in extra:
		mons.append(e)
	var rolls: Array = []
	for i in 60:
		rolls.append(1)
	return {"board_size": 12, "seed": 5, "rolls": rolls, "dungeon": {"dungeon_id": SALT, "room_id": "lure", "room_name": "Lure", "kind": "boss", "cells": cells, "pad_heal": 0, "hero": {"class_id": "bastion", "pos": hero_at, "facing": "N"}, "monsters": mons, "summons": {}}}


func _test_lantern_lure() -> void:
	sim.reset_match(_lure_room(Vector2i(6, 2), Vector2i(6, 6)))
	var boss: Dictionary = sim._unit_by_seat(1)
	var hero: Dictionary = sim._unit_by_seat(0)
	var sig: Dictionary = boss["signature"]
	eq(bool(sim.pull_ready(boss)), false, "no lure out of the boss's turn count (turn 0)")
	var early: Dictionary = sim.submit({"type": "cast", "spell": str(sig["id"]), "to": hero["pos"], "seat": 1})
	eq(bool(early.get("ok", true)), false, "a lure out of turn is refused")
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pull_ready(boss)), true, "the lure is ready on his 1st turn")
	var lure_legal := false
	for i in sim.legal_intents(1):
		lure_legal = lure_legal or str(i.get("spell", "")) == str(sig["id"])
	eq(lure_legal, true, "the lure is a legal monster intent")
	var ap_before := int(boss["ap"])
	eq(bool(sim.submit({"type": "cast", "spell": str(sig["id"]), "to": hero["pos"], "seat": 1}).get("ok", false)), true, "he raises the lantern")
	eq(hero["pos"], Vector2i(6, 4), "the hero slides 2 cells toward him (6,6 -> 6,4)")
	eq(int(boss["ap"]), ap_before - int(sig["ap"]), "the lure costs %d AP" % int(sig["ap"]))
	var types: Array = []
	var pull: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		types.append(str(e.get("type", "")))
		if str(e.get("type", "")) == "pull":
			pull = e
	eq(types.find("lure") >= 0 and types.find("lure") < types.find("pull"), true, "the lure event comes before the slide (%s)" % [types])
	eq([pull.get("from"), pull.get("to"), int(pull.get("cells", 0)), str(pull.get("how", ""))], [Vector2i(6, 6), Vector2i(6, 4), 2, "pull"], "the pull event carries from, to, cells")
	eq((pull.get("path", []) as Array), [Vector2i(6, 5), Vector2i(6, 4)], "the pull path is cell by cell")
	eq(bool(sim.pull_ready(boss)), false, "one lure a turn")
	# The rhythm: turns 1, 3, 5 ... with the AI.
	sim.reset_match(_lure_room(Vector2i(6, 1), Vector2i(6, 11)))
	var lured_on: Array = []
	for round_n in 8:
		if bool(sim.snapshot()["match_over"]):
			break
		var h: Dictionary = sim._unit_by_seat(0)
		h["pos"] = Vector2i(6, 11) if round_n % 2 == 0 else Vector2i(2, 9)
		h["hp"] = 80
		sim.submit({"type": "end_turn", "seat": 0})
		var b: Dictionary = sim._unit_by_seat(1)
		b["pos"] = Vector2i(6, 6)
		var bit := false
		var lured := false
		for d in AI.play_monster_turn(sim, 1):
			if str(d["intent"].get("spell", "")) == str(sig["id"]) and bool(d["ok"]):
				lured = true
				lured_on.append(int(b["own_turns"]))
			if lured and str(d["intent"].get("spell", "")) == str(b["attack"]["id"]) and bool(d["ok"]):
				bit = true
		if lured and chebyshev(sim._unit_by_seat(0)["pos"], b["pos"]) <= 1:
			eq(bit, true, "after a lure into reach he bites (turn %d)" % int(b["own_turns"]))
	eq(lured_on, [1, 3, 5, 7], "the lure comes on his 1st turn and every 2nd after (%s)" % [lured_on])


func _test_lure_line_and_stops() -> void:
	# Behind a rock spire: no line, no lure.
	var spire := {Vector2i(6, 5): "rock_spire"}
	sim.reset_match(_lure_room(Vector2i(6, 2), Vector2i(6, 7), spire))
	sim.submit({"type": "end_turn", "seat": 0})
	var boss: Dictionary = sim._unit_by_seat(1)
	eq(bool(sim.has_los(boss["pos"], sim._unit_by_seat(0)["pos"])), false, "the spire cuts the lantern's line")
	eq(bool(sim.pull_ready(boss)), false, "no lure without a line of sight")
	var refused: Dictionary = sim.submit({"type": "cast", "spell": str(boss["signature"]["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	eq(str(refused.get("reason", "")), "pull_not_ready", "the lure is refused behind a spire")
	# Out of range (7 cells) and adjacent (1 cell): no lure.
	sim.reset_match(_lure_room(Vector2i(6, 1), Vector2i(6, 8)))
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pull_ready(sim._unit_by_seat(1))), false, "no lure from 7 cells")
	sim.reset_match(_lure_room(Vector2i(6, 4), Vector2i(6, 5)))
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pull_ready(sim._unit_by_seat(1))), false, "no lure on an adjacent hero")
	# 2 cells away: the hero stops next to him (1 cell), not on him.
	sim.reset_match(_lure_room(Vector2i(6, 4), Vector2i(6, 6)))
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": "lantern_lure", "to": Vector2i(6, 6), "seat": 1})
	eq(sim._unit_by_seat(0)["pos"], Vector2i(6, 5), "from 2 cells the hero stops next to him")
	# A body in the way stops the slide.
	var book = Monsters.load_default()["monsters"]
	var crab: Dictionary = book.stats_at("reef_crab", LEVEL)
	crab["pos"] = Vector2i(6, 5)
	crab["facing"] = "S"
	sim.reset_match(_lure_room(Vector2i(6, 1), Vector2i(6, 6), {}, [crab]))
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pull_ready(sim._unit_by_seat(1))), false, "a body right in front of the hero leaves no cell to slide into")
	crab["pos"] = Vector2i(6, 4)
	sim.reset_match(_lure_room(Vector2i(6, 1), Vector2i(6, 7), {}, [crab]))
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": "lantern_lure", "to": Vector2i(6, 7), "seat": 1})
	eq(sim._unit_by_seat(0)["pos"], Vector2i(6, 5), "the slide stops before the crab")
	# A diagonal gap pulls on the diagonal; a long gap pulls along its long axis.
	sim.reset_match(_lure_room(Vector2i(2, 2), Vector2i(6, 6)))
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": "lantern_lure", "to": Vector2i(6, 6), "seat": 1})
	eq(sim._unit_by_seat(0)["pos"], Vector2i(4, 4), "a square gap pulls on the diagonal")
	sim.reset_match(_lure_room(Vector2i(1, 5), Vector2i(6, 6)))
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": "lantern_lure", "to": Vector2i(6, 6), "seat": 1})
	eq(sim._unit_by_seat(0)["pos"], Vector2i(4, 6), "a long gap pulls along its long axis")
	# The Abyssal Lure pulls 3.
	sim.reset_match(_lure_room(Vector2i(6, 1), Vector2i(6, 6), {}, [], 5))
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": "abyssal_lure", "to": Vector2i(6, 6), "seat": 1})
	eq(sim._unit_by_seat(0)["pos"], Vector2i(6, 3), "the Abyssal Lure pulls 3 cells")
	# Room B: from the boss's start, the spires hide some cells round the whirlpool.
	var run = Run.create(SALT, LEVEL, "kestrel")["run"]
	sim.reset_match(run.combat_config(1, 1))
	var hidden := 0
	var open := 0
	for y in range(5, 12):
		for x in 12:
			var c := Vector2i(x, y)
			if not bool(sim.tile_at(c).get("walkable", false)):
				continue
			if bool(sim.has_los(Vector2i(6, 2), c)):
				open += 1
			else:
				hidden += 1
	eq(hidden > 0 and open > 0, true, "room B: the spires hide some cells from the lantern (%d hidden, %d open)" % [hidden, open])


# --- ★5 riptide, soak, rinse ---------------------------------------------------------

func _test_star5_riptide() -> void:
	var run = Run.create(SALT, LEVEL, "kestrel", "", 5)["run"]
	var cfg: Dictionary = run.combat_config(1, 31)
	cfg["rolls"] = []
	for i in 300:
		cfg["rolls"].append(99)
	sim.reset_match(cfg)
	var boss: Dictionary = sim._unit_by_seat(1)
	eq(str(boss["name"]), "Abyssal Saltmaw", "★5 room B boss is the Abyssal Saltmaw")
	var sig2: Dictionary = boss["signature2"]
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pools_ready(boss)), false, "no riptide on his 1st turn")
	boss["acted_signature"] = true
	while int(sim.snapshot()["active_seat"]) != 0:
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
	var hero: Dictionary = sim._unit_by_seat(0)
	hero["pos"] = Vector2i(6, 9)
	sim.submit({"type": "end_turn", "seat": 0})
	eq(int(boss["own_turns"]), 2, "his 2nd turn")
	eq(bool(sim.pools_ready(boss)), true, "the riptide is ready on his 2nd turn")
	var hero_cell: Vector2i = hero["pos"]
	eq(bool(sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero_cell, "seat": 1}).get("ok", false)), true, "he stirs the riptide")
	var cells: Array = sim.pool_cells()
	eq(cells.size() >= int(sig2["cells_min"]) and cells.size() <= int(sig2["cells_max"]), true, "2-3 riptide cells (%d)" % cells.size())
	eq(cells.has(hero_cell), true, "a riptide cell lands under the hero")
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(str(p.get("hazard", "")), "riptide", "the snapshot names the hazard riptide")
		eq(int(p.get("drag", 0)), 1, "a riptide cell drags 1")
	var lay := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pools":
			lay = str(e.get("coach", ""))
			eq(str(e.get("hazard", "")), "riptide", "the hazard event names riptide for the view")
	eq(lay.contains("churn"), true, "the lay line is the riptide's own (%s)" % lay)
	while int(sim.snapshot()["active_seat"]) != 0:
		var u: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
		u["acted_signature"] = true
		sim.submit({"type": "end_turn", "seat": int(u["seat"])})
	hero["hp"] = 80
	hero["pos"] = hero_cell
	var boss_at: Vector2i = boss["pos"]
	var before := chebyshev(hero_cell, boss_at)
	sim.submit({"type": "end_turn", "seat": 0})
	var hit: Dictionary = {}
	var drag: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pool_hit":
			hit = e
		if str(e.get("type", "")) == "pull":
			drag = e
	eq(hit.is_empty(), false, "ending the turn in the riptide hurts")
	eq(int(hit.get("damage", 0)), int(sig2["hp"]), "riptide damage is %d" % int(sig2["hp"]))
	eq(str(hit.get("coach", "")).contains("riptide"), true, "the hit line is the riptide's own")
	eq(80 - int(hero["hp"]), int(sig2["hp"]), "the hero lost the riptide damage")
	eq(str(drag.get("how", "")), "drag", "the riptide drags the hero (a pull event the view slides)")
	eq(drag.get("from"), hero_cell, "the drag starts on the riptide cell")
	eq(chebyshev(hero["pos"], boss_at), before - 1, "the hero is dragged 1 cell toward him")
	# Walking across is safe: only ending a turn there hurts; it lasts 3 hero turns.
	var hp_now := int(hero["hp"])
	var turns := 2
	var guard := 0
	while not sim.pool_cells().is_empty() and guard < 40:
		guard += 1
		if int(sim.snapshot()["active_seat"]) == 0:
			hero["pos"] = Vector2i(0, 11)
			sim.submit({"type": "end_turn", "seat": 0})
			turns += 1
		else:
			var u3: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
			u3["acted_signature"] = true
			u3["acted_signature2"] = true
			sim.submit({"type": "end_turn", "seat": int(u3["seat"])})
	eq(turns - 1, int(sig2["turns"]), "the riptide lasts %d hero turns" % int(sig2["turns"]))
	eq(int(hero["hp"]) >= hp_now - 1, true, "ending a turn off the riptide costs nothing")
	# The hero bot never ends a turn in the riptide when it can step off.
	sim.reset_match(run.combat_config(1, 35))
	sim.submit({"type": "end_turn", "seat": 0})
	var b2: Dictionary = sim._unit_by_seat(1)
	b2["own_turns"] = 2
	b2["acted_signature"] = true
	sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]):
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
	var on_before: bool = sim.pool_cells().has(sim._unit_by_seat(0)["pos"])
	AI.play_hero_turn(sim)
	var hit2 := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pool_hit":
			hit2 = true
	eq(on_before, true, "the bot starts its turn in the riptide")
	eq(hit2, false, "the hero bot steps off before ending its turn")


func _test_soak_and_rinse() -> void:
	var book = Monsters.load_default()["monsters"]
	var ah: Dictionary = book.stats_at("abyssal_drowned_harpooner", LEVEL, 5)
	var cells: Array = []
	for y in 12:
		for x in 12:
			var pad := Vector2i(x, y) == Vector2i(8, 8)
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["coral_pad"] if pad else [], "blocks": false, "special": "pad" if pad else ""})
	var a := ah.duplicate(true)
	a["pos"] = Vector2i(8, 4)
	a["facing"] = "S"
	a["mp"] = 0
	var run = Run.create(SALT, LEVEL, "kestrel", "", 5)["run"]
	var thaw_text := str(run.combat_config(0, 1)["dungeon"]["pad_thaw_text"])
	var room := {"dungeon_id": SALT, "room_id": "soak", "room_name": "Soak", "kind": "pack", "cells": cells, "pad_heal": 5, "pad_thaw": true, "pad_thaw_text": thaw_text, "hero": {"class_id": "bastion", "pos": Vector2i(5, 7), "facing": "N"}, "monsters": [a], "summons": {}}
	var rolls: Array = []
	for i in 40:
		rolls.append(1)
	sim.reset_match({"board_size": 12, "seed": 4, "dungeon": room, "rolls": rolls})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(ah["attack"]["id"]), "to": Vector2i(5, 7), "target_seat": 0, "seat": 1})
	var line := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("status", "")) == "chill":
			line = str(e.get("coach", ""))
	eq(line.contains("soaked"), true, "an abyssal hit soaks the hero (%s)" % line)
	sim.submit({"type": "end_turn", "seat": 1})
	var hero: Dictionary = sim._unit_by_seat(0)
	eq(int(hero["mp"]), int(hero["max_mp"]) - 1, "a soaked hero has 1 MP less on the next turn")
	var drain_line := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "chill":
			drain_line = str(e.get("coach", ""))
	eq(drain_line.contains("soaked"), true, "the MP loss line says soaked (%s)" % drain_line)
	hero["pos"] = Vector2i(8, 8)
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(ah["attack"]["id"]), "to": Vector2i(8, 8), "target_seat": 0, "seat": 1})
	sim.submit({"type": "end_turn", "seat": 1})
	eq(int(hero["mp"]), int(hero["max_mp"]), "a turn that starts on a coral pad keeps its full MP")
	var rinse := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "thaw":
			rinse = str(e.get("coach", ""))
	eq(rinse.contains("rinses"), true, "the pad's rinse line is the grotto's own (%s)" % rinse)


# --- rewards -----------------------------------------------------------------------

func _test_rewards_per_star() -> void:
	var base_xp := 0
	var base_coins := 0
	var parts := {}
	for star in range(1, 6):
		var run = Run.create(SALT, LEVEL, "kestrel", "", star)["run"]
		run.result = "win"
		var rares := 0
		var boxes := 0
		var trials := 30 if star < 5 else 10
		var summary: Dictionary = {}
		for t in trials:
			var h = _fresh_hero()
			var s2: Dictionary = run.pay_out(h, null, _rng(200 + t), false)
			for item in s2["items"]:
				if str(item.get("rarity", "")) == "rare":
					rares += 1
				if str(item.get("item_id", "")) == "mystery_box":
					boxes += 1
				parts[str(item.get("item_id", ""))] = true
			summary = s2
		if star == 1:
			base_xp = int(summary["xp"])
			base_coins = int(summary["coins"])
		eq(int(summary["xp"]), base_xp * star, "★%d XP is %d x %d" % [star, base_xp, star])
		eq(int(summary["coins"]), base_coins * star, "★%d coins are ★1 coins x %d" % [star, star])
		if star < 3:
			eq(rares, 0, "★%d drops no Rare part" % star)
		if star == 5:
			eq(rares >= trials, true, "★5 always drops a Rare part")
			eq(boxes >= trials, true, "★5 always drops a Mystery Box")
		var hero = _fresh_hero()
		var s3: Dictionary = run.pay_out(hero, null, _rng(7), false)
		eq(int(hero.best_dungeon_star(SALT)), star, "★%d clear is the grotto's best star" % star)
		eq(bool(s3.get("new_best_star", false)), true, "★%d is a new best" % star)
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/level_curve.json"))
	var need := float((curve["xp_to_next"] as Array)[LEVEL - 1])
	var expect_xp := int(round(0.27 * need * float(curve["pace_start"]) * pow(float(curve["pace_ratio"]), LEVEL - 1)))
	eq(base_xp, expect_xp, "level 22 ★1 XP is 27%% of xp_to_next(22) x pace (%d)" % expect_xp)
	eq(base_xp > Run.create(FROST, 12, "kestrel")["run"].win_xp(12), true, "the grotto pays more XP than the archive")
	eq(base_coins > 0, true, "a grotto win pays coins (%d)" % base_coins)
	var set_part := false
	for id in parts.keys():
		if str(id).begins_with("saltmaw_"):
			set_part = true
	eq(set_part, true, "the grotto drops Saltmaw set parts (the tier-20 set)")


func _test_mission_credit() -> void:
	var missions = Missions.load_default()["missions"]
	var hero = _fresh_hero()
	hero.level = LEVEL
	hero.mission_blob = {"story": {"eastmarch_scout": {"status": "done"}}}
	eq(missions.label_for("eastmarch_dungeon", hero) != "coming soon", true, "the Eastmarch dungeon mission is live")
	eq(bool(missions.accept("eastmarch_dungeon", hero).get("ok", false)), true, "the mission can be taken")
	var run = Run.create(SALT, LEVEL, "kestrel", "", 1)["run"]
	run.result = "win"
	var sm: Dictionary = run.pay_out(hero, missions, _rng(3), false)
	eq((sm["missions"] as Array).has("eastmarch_dungeon"), true, "a grotto win credits the clear_dungeon mission")
	var offer: Array = missions.mission("eastmarch_dungeon")["lines"]["offer"]
	eq(str(offer[0]).contains("not open yet"), false, "the offer no longer says the way is shut")


# --- the cellar and the archive are unchanged ------------------------------------------

func _test_others_unchanged() -> void:
	var book = Monsters.load_default()["monsters"]
	eq(book.ids_for(GRANARY), ["granary_rat", "sling_rat", "scarecrow_drudge", "the_ratking", "radioactive_rat", "radioactive_sling_rat", "radioactive_ratking"], "the cellar keeps its seven monsters")
	eq(book.ids_for(FROST), ["ice_construct", "book_wraith", "the_pale_archivist", "frozen_ice_construct", "frozen_book_wraith", "the_frozen_archivist"], "the archive keeps its six monsters")
	var rows := {1: [1.0, 1.0], 2: [1.1, 1.05], 3: [1.15, 1.1], 4: [1.2, 1.1], 5: [1.0, 1.0]}
	var frost_rows := {1: [1.0, 1.0], 2: [1.05, 1.0], 3: [1.05, 1.0], 4: [1.1, 1.0], 5: [0.875, 0.85]}
	for star in range(1, 6):
		eq(book.star_scale(star, GRANARY), rows[star], "the cellar's ★%d row is unchanged" % star)
		eq(book.star_scale(star, FROST), frost_rows[star], "the archive's ★%d row is unchanged" % star)
	eq([int(book.stats_at("the_pale_archivist", 12)["hp"]), int(book.stats_at("the_pale_archivist", 12)["attack"]["damage"])], [90, 11], "Archivist 90 HP, Ledger 11 at level 12")
	eq(str(book.stats_at("the_pale_archivist", 12)["signature"]["kind"]), "summon", "the Archivist still summons")
	# The archive's frost patch and chill lines are unchanged.
	var run = Run.create(FROST, 12, "kestrel", "", 5)["run"]
	var cfg: Dictionary = run.combat_config(1, 31)
	sim.reset_match(cfg)
	sim.submit({"type": "end_turn", "seat": 0})
	var boss: Dictionary = sim._unit_by_seat(1)
	sim.submit({"type": "cast", "spell": str(boss["signature2"]["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	var coach := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pools":
			coach = str(e["coach"])
	eq(coach.contains("cells freeze around"), true, "the Rime Patches line is unchanged (%s)" % coach)
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(p.has("drag") or p.has("hit_text"), false, "a frost patch record has no riptide keys")
	eq(str(cfg["dungeon"]["pad_thaw_text"]).contains("rune pad thaws"), true, "the archive's thaw line is unchanged")
	var g_run = Run.create(GRANARY, 1, "kestrel", "", 5)["run"]
	sim.reset_match(g_run.combat_config(1, 31))
	sim.submit({"type": "end_turn", "seat": 0})
	var king: Dictionary = sim._unit_by_seat(1)
	sim.submit({"type": "cast", "spell": str(king["signature2"]["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(p.has("hazard") or p.has("mp_loss") or p.has("drag"), false, "a toxic pool record is unchanged")
	eq(bool(sim.pull_ready(king)), false, "the Ratking has no pull")
	eq(Run.create(GRANARY, 1, "kestrel")["run"].text("victory"), "Old Granary Cellar is cleared at ★1. The Ratking is down.", "the cellar victory line is unchanged")


# --- world door, panel, scene --------------------------------------------------------

func _test_world_door_and_panel() -> void:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.progress.level = LEVEL
	w.enter_zone(ZONE, Vector2i(22, 19), false)
	await process_frame
	eq(w.zone.zone_id, ZONE, "the hero is in Eastmarch")
	eq(w.door_nodes.has(SALT), true, "the grotto door stands in Eastmarch")
	var row: Dictionary = w.dungeon_book.by_id(SALT)
	var building: Array = Dungeons.building_cells_for(row, w.building_size_for(row))
	for c in building:
		eq(w.zone.passable_at(c), false, "grotto cell %s blocks walking" % c)
	eq(w.zone.passable_at(DOOR), true, "the door cell stays walkable")
	eq(w.door_at(ZONE, DOOR).get("id", ""), SALT, "the door cell is a door")
	eq(w.door_at(ZONE, building[0]).get("id", ""), SALT, "clicking the rock finds the door")
	var man_ok := bool(Art.manifest("res://art/pc/dungeons/saltmaw_grotto/manifest.json").get("ok", false))
	if man_ok:
		eq(w.door_nodes[SALT].painted, true, "the door draws the painted grotto")
	eq(bool(w.approach_door(SALT).get("ok", false)), true, "clicking the door walks there")
	_drive(w)
	eq(w.walker.cell, DOOR, "the hero stands on the door cell")
	eq(w.door_panel.is_open(), true, "the entry panel opens on arrival")
	var text := _panel_text(w.door_panel)
	eq(text.contains("Saltmaw Grotto"), true, "panel names the grotto")
	eq(text.contains("20–30"), true, "panel shows levels 20-30")
	eq(text.contains("Old Saltmaw"), true, "panel names the boss")
	eq(bool(w.door_panel.check.get("ok", false)), true, "a level 22 hero passes the level check")
	eq(w.door_panel.star_buttons.size(), 5, "★1-★5 on the panel")
	w.door_panel.select_star(5)
	eq((w.door_panel.find_child("StarNote", true, false) as Label).text.contains("Abyssal Saltmaw"), true, "the ★5 note is the grotto's")
	w.door_panel.leave_button.emit_signal("pressed")
	w._approach_npc(w.npc_book.by_id("eastmarch_door_keeper"))
	_drive(w)
	eq(w.door_panel.is_open(), true, "talking to the Door Keeper opens the entry panel")
	Launcher.pending = {}
	w.door_panel.select_star(3)
	w.door_panel.press_enter()
	eq(str(Launcher.pending.get("dungeon_id", "")), SALT, "Enter hands over the grotto")
	eq(int(Launcher.pending.get("star", 0)), 3, "Enter hands over the picked star")
	eq(Launcher.pending.get("return_cell", Vector2i(-1, -1)), DOOR, "the way back is the door cell")
	eq(str(Launcher.pending.get("return_zone", "")), ZONE, "the way back is Eastmarch")
	Launcher.pending = {}
	w.queue_free()
	await process_frame


func _test_run_scene_win_and_return() -> void:
	Launcher.pending = {"dungeon_id": SALT, "level": LEVEL, "class_id": "bastion", "autoplay": true, "return_zone": ZONE, "return_cell": DOOR, "seed": 1}
	Launcher.outcome = {}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	var got := {}
	scene.run_finished.connect(func(r, s): got["result"] = r; got["summary"] = s)
	root.add_child(scene)
	var rooms := {}
	var lure_seen := false
	var harpoons := false
	var t0 := Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
		var snap: Dictionary = sim.snapshot()
		if snap.has("dungeon"):
			rooms[str(snap["dungeon"]["room_id"])] = true
			for e in snap.get("last_events", []):
				harpoons = harpoons or str(e.get("projectile", "")) == "harpoon"
				lure_seen = lure_seen or str(e.get("type", "")) == "lure"
	eq(str(got.get("result", "")), "win", "the room scene plays a full grotto run to a win")
	eq(rooms.has("room_a") and rooms.has("room_b"), true, "both rooms are played")
	eq(lure_seen, true, "Old Saltmaw lures during the scene")
	eq(harpoons, true, "Drowned Harpooner harpoons fly in the scene")
	var board = scene.get_node("BoardView")
	eq(str(board.view_cfg.get("pads", {}).keys()), str(["coral_pad", "whirlpool"]), "the board reads the grotto's pad styles")
	eq(scene.result_text().contains("Old Saltmaw is down"), true, "the result panel names Old Saltmaw")
	eq(scene.result_text().contains("Eastmarch"), true, "the result panel sends the hero back to Eastmarch")
	var t1 := Time.get_ticks_msec()
	while Launcher.outcome.is_empty() and Time.get_ticks_msec() - t1 < 15000:
		await process_frame
	eq(str(Launcher.outcome.get("result", "")), "win", "the win goes back to the world")
	scene.queue_free()
	await process_frame
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	await process_frame
	eq(w.zone.zone_id, ZONE, "back in Eastmarch")
	eq(w.walker.cell, DOOR, "back on the grotto door cell")
	eq(w.reward_popup.is_open(), true, "the reward pop-up shows the drop")
	w.queue_free()
	await process_frame


# --- helpers -----------------------------------------------------------------------

func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _flood(walk: Dictionary, start: Vector2i, taken: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + step
			if walk.has(nxt) and not taken.has(nxt) and not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	return seen


func _granary_art() -> String:
	var run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/dungeons/old_granary_cellar/run.json"))
	return str(run.get("art", ""))


func _fresh_hero():
	var hero = Progress.new()
	hero.level = LEVEL
	hero.xp = 0
	hero.coins = 0
	hero.bag = []
	hero.bank = []
	hero.mission_blob = {}
	hero.dungeon_stars = {}
	hero.hero_class = "kestrel"
	return hero


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func _panel_text(panel: CanvasLayer) -> String:
	var title: Label = panel.find_child("Title", true, false)
	var body: RichTextLabel = panel.find_child("Body", true, false)
	var check: Label = panel.find_child("LevelCheck", true, false)
	return "%s\n%s\n%s" % [title.text if title else "", body.get_parsed_text() if body else "", check.text if check else ""]


func _drive(w: Node2D) -> void:
	var n := 0
	while w.walker.is_moving() and n < 4000:
		w.walker.advance(0.05)
		n += 1


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
