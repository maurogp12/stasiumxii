extends SceneTree

## PC dungeon 4, the Drowned Abbey (Southbridge, levels 30-40): the door and
## its drowned chapel in Southbridge, the run file and rooms (every cell
## reachable, pews, statues and the rune circle's candle stands break lines,
## the 2x2 fallen bell), pack sizes per star, the AI always ending its turn,
## Mire Leech line of sight and kiting, the Mire Abbess's Rite of Rising
## (signature kind raise: rhythm, corpses, where the risen stand, the cap, a
## hero on a corpse, the risen sinking back when she falls), the ★5 Bell
## Wraith and her Grasping Mire (root hazard), the bellbound mire and the
## cleansing pads, rewards per star, the Southbridge mission, a full run in the
## room scene, and guards that the other three dungeons play exactly as before.
## Run: godot --headless --path . -s res://tests/run_abbey_tests.gd

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
const ABBEY := "drowned_abbey"
const SALT := "saltmaw_grotto"
const FROST := "frostspire_archive"
const GRANARY := "old_granary_cellar"
const ZONE := "crosshaven_southbridge"
const DOOR := Vector2i(24, 26)
const KEEPER := Vector2i(23, 26)
const LEVEL := 32
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
## The agreed board props (build_rooms.py KIT_PROPS), checked against the
## manifest once it lists them.
const KIT_PROPS: Array[String] = ["pew", "broken_pillar", "fallen_statue", "candle_cluster", "coffin", "gravestone", "gnarled_roots", "altar", "fallen_bell", "candle_stand", "floating_coffin", "saint_statue"]

var _passed := 0
var _failed := 0
var sim: Node
## The ★5 forms' ids and the ★5 boss name come from the data (variant_of +
## star_min 5, run.json text.boss_star5), so renaming the mutated forms costs
## nothing here.
var G_BOG := ""
var G_LEECH := ""
var G_BOSS := ""
var G_BOSS_NAME := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Regions.set_enabled(true)
	Launcher.dry_run = true
	sim = root.get_node("CombatSim")
	_resolve_star5_ids()
	_test_door_data()
	_test_run_file_and_rooms()
	_test_monsters()
	_test_packs_per_star()
	_test_ai_always_ends()
	_test_leech_los_and_kiting()
	_test_rite_of_rising()
	_test_rite_corpses_and_cap()
	_test_rite_scatter_and_star5()
	_test_star5_grasping_mire()
	_test_mire_and_cleanse()
	_test_rewards_per_star()
	_test_mission_credit()
	_test_others_unchanged()
	await _test_world_door_and_panel()
	await _test_run_scene_win_and_return()
	_finish()


func _finish() -> void:
	print("abbey tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- door ------------------------------------------------------------------------

func _test_door_data() -> void:
	var loaded: Dictionary = Dungeons.load_default()
	eq(bool(loaded.get("ok", false)), true, "dungeons.json loads: %s" % [loaded.get("errors", [])])
	var book = loaded["dungeons"]
	var row: Dictionary = book.by_id(ABBEY)
	eq(str(row.get("status", "")), "built", "the Drowned Abbey is built")
	eq(str(row["level_zone"]), "southbridge", "it is Southbridge's dungeon")
	eq([int(row["level_min"]), int(row["level_max"])], [30, 40], "levels 30-40")
	eq(str(row["boss"]), "The Mire Abbess", "the boss is the Mire Abbess")
	eq(Dungeons.door_cell(row), DOOR, "the abbey door is at 24,26")
	eq(str(row["door"]["zone_id"]), ZONE, "the door is in the Southbridge chunk")
	eq(str(row["run"]), "res://data/world/dungeons/drowned_abbey/run.json", "the run file is named")
	var shape: Dictionary = Dungeons.building_shape(row)
	var size: Vector2i = shape.get("size", Vector2i(3, 3))
	var from_nw: Vector2i = shape.get("door_from_nw", Vector2i(1, 3))
	if from_nw.x < 0:
		from_nw = Vector2i(int((size.x - 1) / 2), size.y)
	var building := Dungeons.building_cells_for(row)
	eq(building.size(), size.x * size.y, "%d building cells (the manifest footprint %dx%d)" % [size.x * size.y, size.x, size.y])
	eq(building.has(DOOR + Vector2i(0, -1)), true, "the chapel's doorway cell is just north of the door")
	var nw := DOOR - from_nw
	for c in building:
		eq(c.x >= nw.x and c.x < nw.x + size.x and c.y >= nw.y and c.y < nw.y + size.y, true, "building cell %s on the footprint" % c)
	var atlas = Atlas.load_default()["atlas"]
	var npcs = NpcBook.load_default()["npcs"]
	var checked: Dictionary = book.validate_world(atlas, npcs, Art.building_size(Art.manifest(_granary_art()), Dungeons.DEFAULT_BUILDING))
	eq(bool(checked["ok"]), true, "4.6 rules hold with all four doors: %s" % [checked["errors"]])
	var zone: WorldZone = atlas.map_for_chunk(ZONE).zone(ZONE)
	eq(zone.passable_at(DOOR), true, "the door cell is passable")
	eq(zone.in_bounds(DOOR), true, "the door is inside the chunk")
	eq(zone.exit_link(DOOR).is_empty(), true, "the door is not an exit")
	eq(atlas.gate_at(ZONE, DOOR).is_empty(), true, "the door is not a gate")
	eq(DOOR != zone.spawn, true, "the door is not the spawn")
	for c in building:
		eq(zone.passable_at(c), true, "building cell %s is open ground before the chapel blocks it" % c)
	for npc in npcs.for_zone(ZONE):
		var at := Vector2i(int(npc["cell"]["x"]), int(npc["cell"]["y"]))
		eq(at != DOOR and not building.has(at), true, "%s is not on the door or the building" % npc["id"])
	var keeper: Dictionary = npcs.by_id("drowned_abbey_door_keeper")
	eq(str(keeper["role"]), "door_keeper", "the Southbridge Door Keeper is a door keeper")
	eq(Vector2i(int(keeper["cell"]["x"]), int(keeper["cell"]["y"])), KEEPER, "the Door Keeper stands beside the door")
	eq(book.for_keeper("drowned_abbey_door_keeper").get("id", ""), ABBEY, "the keeper opens the abbey")
	eq(str((keeper["lines"] as Array).back()).contains("Abbess"), true, "the keeper warns of the Abbess")
	eq(Dungeons._door_reachable(zone, DOOR, building, npcs), true, "the door can be walked to from the chunk spawn round the chapel")
	# A door moved onto the keeper or out of Southbridge fails.
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Dungeons.PATH))
	var on_npc: Dictionary = base.duplicate(true)
	(on_npc["dungeons"] as Array)[3]["door"] = {"zone_id": ZONE, "x": KEEPER.x, "y": KEEPER.y}
	eq(bool(Dungeons.load_document(on_npc)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "an abbey door on the keeper fails")
	var away: Dictionary = base.duplicate(true)
	(away["dungeons"] as Array)[3]["door"] = {"zone_id": "crosshaven_eastmarch", "x": 24, "y": 26}
	eq(bool(Dungeons.load_document(away)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "an abbey door outside Southbridge fails")
	var in_water: Dictionary = base.duplicate(true)
	(in_water["dungeons"] as Array)[3]["door"] = {"zone_id": ZONE, "x": 24, "y": 28}
	eq(bool(Dungeons.load_document(in_water)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "an abbey door in the swamp water fails")
	eq(book.built().size(), 5, "five dungeons are built")


# --- run file and rooms --------------------------------------------------------

func _test_run_file_and_rooms() -> void:
	var made: Dictionary = Run.create(ABBEY, LEVEL, "kestrel")
	eq(bool(made.get("ok", false)), true, "the abbey run builds: %s" % [made.get("errors", [])])
	if not bool(made.get("ok", false)):
		return
	var run = made["run"]
	eq(run.level, LEVEL, "a level 32 hero runs at level 32")
	eq(int(Run.create(ABBEY, 50, "kestrel")["run"].level), 40, "an over-band hero meets level 40 monsters")
	eq(int(Run.create(ABBEY, 5, "kestrel")["run"].level), 30, "an under-band hero meets level 30 monsters")
	eq(run.room_count(), 2, "room A then room B")
	eq([str(run.room(0)["kind"]), str(run.room(1)["kind"])], ["pack", "boss"], "a pack room, then the boss")
	eq(str(run.run_doc["art"]), "res://art/pc/dungeons/drowned_abbey/manifest.json", "the art manifest is the abbey kit")
	eq(str(run.text("stairs")).contains("bell"), true, "the stairs line is the abbey's")
	eq(run.text("return_button"), "Return to Southbridge", "the return button names Southbridge")
	eq(str((run.run_doc["text"] as Dictionary).get("star5_rule", "")).contains("Grasping Mire"), true, "the ★5 rule text lives in the run file")
	eq(str((run.run_doc["text"] as Dictionary).get("signature_rule", "")).contains("Rite of Rising"), true, "the rite's rule text lives in the run file")
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
		eq(bool(room["pad_thaw"]), true, "%s pads cleanse" % label)
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
			else:
				walk[c] = true
			if str(rec["special"]) != "":
				pads += 1
		eq(blocked >= 10, true, "%s has prop obstacles (%d)" % [label, blocked])
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
	var circle := 0
	var glow := 0
	var stands := 0
	var bell := 0
	var b_walk := {}
	for rec in b_cells:
		var c: Vector2i = rec["pos"]
		var paint: Array = rec["paint_only"]
		if not bool(rec["blocks"]):
			b_walk[c] = true
		if paint.has("rune_circle"):
			circle += 1
			eq(c.x >= 4 and c.x <= 8 and c.y >= 4 and c.y <= 8, true, "rune circle cell %s is on the 5x5 decal (4-8 x 4-8)" % c)
			if str(rec["special"]) != "":
				glow += 1
				eq(c.x >= 5 and c.x <= 7 and c.y >= 5 and c.y <= 7, true, "pad %s is on the inner 3x3" % c)
		if paint.has("candle_stand"):
			stands += 1
			eq(paint.has("rune_circle") and (c.x == 4 or c.x == 8) and (c.y == 4 or c.y == 8), true, "candle stand %s stands on a corner of the circle" % c)
		if str(paint[0] if not paint.is_empty() else "").begins_with("fallen_bell"):
			bell += 1
			eq(bool(rec["blocks"]), true, "fallen bell cell %s blocks" % c)
	eq(circle, 25, "room B's rune circle decal covers 5x5 cells")
	eq(glow, 9, "its inner 3x3 glow is the room's pads")
	eq(stands, 4, "four candle stands on the circle's corners")
	eq(bell, 4, "the fallen bell lies on 2x2 cells")
	eq(_flood(b_walk, Vector2i(6, 10), {}).has(Vector2i(6, 6)), true, "the circle's centre is reachable")
	var a_cells: Array = run.combat_config(0, 1)["dungeon"]["cells"]
	var candles := 0
	for rec in a_cells:
		if (rec["paint_only"] as Array).has("candle_pad"):
			candles += 1
	eq(candles >= 4, true, "room A has green candle-rune pads (%d)" % candles)


func _test_monsters() -> void:
	var book = Monsters.load_default()["monsters"]
	var ids: Array = book.ids_for(ABBEY)
	eq(ids, ["bog_dead", "mire_leech", "mire_abbess", G_BOG, G_LEECH, G_BOSS], "the abbey's six monsters")
	for id in ids:
		var lo: Dictionary = book.stats_at(id, 30)
		var hi: Dictionary = book.stats_at(id, 40)
		eq(int(lo["level"]), 30, "%s starts at level 30" % id)
		eq(int(book.stats_at(id, 1)["level"]), 30, "%s clamps up to its band" % id)
		eq(int(hi["hp"]) > int(lo["hp"]), true, "%s grows through 30-40" % id)
		eq(str(lo["dungeon"]), ABBEY, "%s belongs to the abbey" % id)
	var bog: Dictionary = book.stats_at("bog_dead", LEVEL)
	var leech: Dictionary = book.stats_at("mire_leech", LEVEL)
	var boss: Dictionary = book.stats_at("mire_abbess", LEVEL)
	eq(int(bog["mp"]), 2, "the Bog Dead shambles (2 MP)")
	eq(int(bog["attack"]["max_range"]), 1, "the Bog Dead is melee")
	eq(int(bog["hp"]) > int(leech["hp"]), true, "the Bog Dead is tougher than the leech")
	eq([int(leech["attack"]["min_range"]), int(leech["attack"]["max_range"])], [2, 5], "the Mire Leech spits at 2-5")
	eq(bool(leech["attack"]["los"]), true, "the Bile Spit needs a line of sight")
	eq(str(leech["attack"]["projectile"]), "bile_spit", "the spit flies as bile_spit")
	eq(str(leech["attack"]["impact"]), "bile_impact", "and bursts in bile_impact")
	eq(bool(boss["boss"]), true, "the Mire Abbess is the boss")
	eq([int(boss["attack"]["min_range"]), int(boss["attack"]["max_range"])], [1, 2], "her Censer Lash reaches 1-2")
	var sig: Dictionary = boss["signature"]
	eq([str(sig["name"]), str(sig["kind"])], ["Rite of Rising", "raise"], "Rite of Rising is a raise")
	eq(sig["raise"], ["bog_dead"], "she raises Bog Dead")
	eq(float(sig["hp_pct"]), 0.5, "the risen come back at half HP")
	eq([int(sig["first_turn"]), int(sig["every"])], [2, 2], "from her 2nd turn, then resting a turn between rites")
	eq(int(boss["ap"]) >= int(sig["ap"]) + int(boss["attack"]["ap"]), true, "she can raise and lash in one turn")
	var grave: Dictionary = book.stats_at(G_BOSS, LEVEL, 5)
	eq(str(grave["signature"]["kind"]), "raise", "the ★5 Abbess raises too")
	eq((grave["signature"]["raise"] as Array).has(G_LEECH), true, "she raises leeches too")
	eq(int(grave["signature"]["cap_total"]) > int(sig["cap_total"]), true, "and more of them")
	eq(float(grave["signature"]["hp_pct"]) > float(sig["hp_pct"]), true, "at more HP")
	eq(str(grave["signature2"]["kind"]), "hazard", "her second move lays a ground hazard")
	eq(str(grave["signature2"]["hazard"]), "grasping_mire", "the hazard is grasping_mire")
	eq(bool(grave["signature2"]["root"]), true, "the grasping mire roots")
	eq(int(grave["hp"]) > int(book.stats_at("mire_abbess", LEVEL, 5)["hp"]), true, "the mutated form is tougher than the Mire Abbess at ★5")
	for id in [G_BOG, G_LEECH]:
		var st: Dictionary = book.stats_at(id, LEVEL, 5)
		eq(str((st["attack"].get("chill", {}) as Dictionary).get("word", "")), "mired", "%s mires" % id)
		eq(str(st["variant_of"]) != "", true, "%s is a mutated form" % id)
	eq(str(book.stats_at(G_LEECH, LEVEL, 5)["attack"]["projectile"]), "gravebound_bile", "bellbound bile flies as the art's gravebound_bile")
	var check: Dictionary = book.check(LEVEL)
	eq(bool(check["ok"]), true, "level 32 numbers pass the sanity pass: %s" % [check["findings"]])
	var rows: Dictionary = book.stars_for(ABBEY)["scale"]
	for star in range(1, 6):
		var m: Array = book.star_scale(star, ABBEY)
		eq(m, [float(rows[str(star)][0]), float(rows[str(star)][1])], "★%d abbey row comes from its own star block" % star)
	var prev := 0.0
	for star in range(1, 5):
		var m2: Array = book.star_scale(star, ABBEY)
		eq(float(m2[0]) >= prev, true, "★%d abbey HP row is not softer than the star below" % star)
		prev = float(m2[0])
	# Bad raise rows fail the load.
	for broken in ["no_raise", "bad_id", "bad_pct", "no_cap"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Monsters.PATH))
		for row in doc["monsters"]:
			if str(row["id"]) == "mire_abbess":
				var s: Dictionary = row["signature"]
				match broken:
					"no_raise": s["raise"] = []
					"bad_id": s["raise"] = ["bog_ghost"]
					"bad_pct": s["hp_pct"] = 1.5
					"no_cap": s.erase("cap_total")
		eq(bool(Monsters.load_document(doc)["ok"]), false, "a raise signature with %s fails the load" % broken)


# --- stars and packs ------------------------------------------------------------

func _test_packs_per_star() -> void:
	var expect := {
		1: {"bog_dead": 4, "mire_leech": 2},
		2: {"bog_dead": 4, "mire_leech": 3},
		3: {"bog_dead": 4, "mire_leech": 3},
		4: {"bog_dead": 4, "mire_leech": 3},
		5: {G_BOG: 4, "bog_dead": 1, G_LEECH: 3},
	}
	var totals := {1: 6, 2: 7, 3: 7, 4: 7, 5: 8}
	var hp_by_star := {}
	for star in range(1, 6):
		var run = Run.create(ABBEY, LEVEL, "kestrel", "", star)["run"]
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
		eq(ranged >= 2, true, "★%d room A has ranged Mire Leeches (%d)" % [star, ranged])
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
		eq(str(mons[0]["monster"]), G_BOSS if star == 5 else "mire_abbess", "★%d boss form" % star)
		var escort := {}
		for m in mons.slice(1):
			escort[str(m["monster"])] = int(escort.get(str(m["monster"]), 0)) + 1
		var want := {G_BOG: 2, G_LEECH: 1} if star == 5 else {"bog_dead": 2, "mire_leech": 1}
		eq(escort, want, "★%d escort: two Bog Dead and a Mire Leech" % star)
		eq((boss_room["summons"] as Dictionary).has(""), false, "★%d a raise signature carries no summon stats" % star)
	for star in range(2, 5):
		eq(int(hp_by_star[star]) >= int(hp_by_star[star - 1]), true, "★%d room A pack is not weaker than ★%d" % [star, star - 1])


func _test_ai_always_ends() -> void:
	var stuck := 0
	var unfinished := 0
	var monster_turns := 0
	var shots := 0
	var rites := 0
	var mires := 0
	var book = Monsters.load_default()["monsters"]
	var spit_ids := [str(book.raw("mire_leech")["attack"]["id"]), str(book.raw(G_LEECH)["attack"]["id"])]
	var rite_ids := [str(book.raw("mire_abbess")["signature"]["id"]), str(book.raw(G_BOSS)["signature"]["id"])]
	var mire_id := str(book.raw(G_BOSS)["signature2"]["id"])
	for cls in CLASSES:
		for star in [1, 5]:
			var run = Run.create(ABBEY, LEVEL, cls, "", star)["run"]
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
						var spell := str(d["intent"].get("spell", ""))
						if spell in spit_ids and bool(d["ok"]):
							shots += 1
						if spell in rite_ids and bool(d["ok"]):
							rites += 1
						if spell == mire_id and bool(d["ok"]):
							mires += 1
					var after: Dictionary = sim.snapshot()
					if not bool(after["match_over"]) and int(after["active_seat"]) == seat:
						unfinished += 1
				if guard >= limit:
					unfinished += 1
				if str(sim.snapshot()["dungeon"]["result"]) != "win":
					break
	eq(monster_turns > 100, true, "monster turns were played (%d)" % monster_turns)
	eq(shots > 20, true, "Mire Leeches find lines and spit (%d)" % shots)
	eq(rites > 2, true, "the Abbess raises the dead in real fights (%d)" % rites)
	eq(mires > 2, true, "the ★5 Abbess calls the mire in real fights (%d)" % mires)
	eq(stuck, 0, "no monster turn needed a forced end")
	eq(unfinished, 0, "every monster turn ends and every fight finishes")


func _test_leech_los_and_kiting() -> void:
	var book = Monsters.load_default()["monsters"]
	var leech: Dictionary = book.stats_at("mire_leech", LEVEL, 1)
	var spell := str(leech["attack"]["id"])
	var cells: Array = []
	for y in 12:
		for x in 12:
			var wall := x == 5 and y >= 2 and y <= 9
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["pew"] if wall else [], "blocks": wall, "special": ""})
	var a := leech.duplicate(true)
	a["pos"] = Vector2i(2, 5)
	a["facing"] = "E"
	var room := {"dungeon_id": "t", "room_id": "lane", "room_name": "Lane", "kind": "pack", "cells": cells, "pad_heal": 0, "hero": {"class_id": "kestrel", "pos": Vector2i(8, 5), "facing": "W"}, "monsters": [a], "summons": {}}
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room})
	eq(bool(sim.has_los(Vector2i(2, 5), Vector2i(8, 5))), false, "a row of pews blocks the spit's line")
	sim.submit({"type": "end_turn", "seat": 0})
	var can_spit := false
	for i in sim.legal_intents(1):
		if str(i.get("spell", "")) == spell:
			can_spit = true
	eq(can_spit, false, "no spit without a line of sight")
	AI.play_monster_turn(sim, 1)
	eq(int(sim.snapshot()["active_seat"]), 0, "the leech ends its turn (no deadlock)")
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
	eq(kinds.size() >= 2 and str(kinds[0]).begins_with("move") and kinds.has("cast:" + spell), true, "adjacent, the leech slithers back, then spits (%s)" % [kinds])
	var spot: Vector2i = sim._unit_by_seat(1)["pos"]
	eq(maxi(absi(spot.x - 8), absi(spot.y - 5)) >= 2, true, "it spits from range 2+")
	a["pos"] = Vector2i(5, 5)
	room["monsters"] = [a]
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room, "rolls": [1, 1, 1, 1]})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": spell, "to": Vector2i(8, 5), "target_seat": 0, "seat": 1})
	var projectile := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("projectile", "")) != "":
			projectile = str(e["projectile"]) + "/" + str(e.get("impact", ""))
	eq(projectile, "bile_spit/bile_impact", "the spit event names its projectile and impact for the view")


# --- the Mire Abbess: Rite of Rising --------------------------------------------------

## An open 12x12 room with the Abbess at `boss_at`, the hero at `hero_at` and
## Bog Dead at `bogs`.
func _rite_room(boss_at: Vector2i, hero_at: Vector2i, bogs: Array, star: int = 1, extra: Array = []) -> Dictionary:
	var book = Monsters.load_default()["monsters"]
	var boss: Dictionary = book.stats_at("mire_abbess" if star < 5 else G_BOSS, LEVEL, star)
	boss["pos"] = boss_at
	boss["facing"] = "S"
	var cells: Array = []
	for y in 12:
		for x in 12:
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": [], "blocks": false, "special": ""})
	var mons: Array = [boss]
	for at in bogs:
		var b: Dictionary = book.stats_at("bog_dead" if star < 5 else G_BOG, LEVEL, star)
		b["pos"] = at
		b["facing"] = "S"
		mons.append(b)
	for e in extra:
		mons.append(e)
	var rolls: Array = []
	for i in 80:
		rolls.append(99)
	return {"board_size": 12, "seed": 5, "rolls": rolls, "dungeon": {"dungeon_id": ABBEY, "room_id": "rite", "room_name": "Rite", "kind": "boss", "cells": cells, "pad_heal": 0, "hero": {"class_id": "bastion", "pos": hero_at, "facing": "N"}, "monsters": mons, "summons": {}}}


func _kill(seat: int) -> void:
	var u: Dictionary = sim._unit_by_seat(seat)
	u["hp"] = 0
	sim._check_death(u)


## Ends turns until the hero's turn comes round again (monsters do nothing).
func _round_to_hero() -> void:
	var guard := 0
	while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]) and guard < 20:
		guard += 1
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})


func _test_rite_of_rising() -> void:
	sim.reset_match(_rite_room(Vector2i(6, 2), Vector2i(6, 10), [Vector2i(6, 6), Vector2i(3, 6)]))
	var boss: Dictionary = sim._unit_by_seat(1)
	var sig: Dictionary = boss["signature"]
	_kill(2)
	eq(bool(sim._unit_by_seat(2)["alive"]), false, "a Bog Dead falls on 6,6")
	eq(bool(sim.raise_ready(boss)), false, "no rite out of her turn count (turn 0)")
	var early: Dictionary = sim.submit({"type": "cast", "spell": str(sig["id"]), "to": Vector2i(6, 6), "seat": 1})
	eq(bool(early.get("ok", true)), false, "a rite out of turn is refused")
	sim.submit({"type": "end_turn", "seat": 0})
	eq(int(boss["own_turns"]), 1, "her 1st turn")
	eq(bool(sim.raise_ready(boss)), false, "no rite on her 1st turn")
	_round_to_hero()
	sim.submit({"type": "end_turn", "seat": 0})
	eq(int(boss["own_turns"]), 2, "her 2nd turn")
	eq(bool(sim.raise_ready(boss)), true, "the rite is ready on her 2nd turn with a corpse down")
	var legal_to := Vector2i(-1, -1)
	for i in sim.legal_intents(1):
		if str(i.get("spell", "")) == str(sig["id"]):
			legal_to = i["to"]
	eq(legal_to, Vector2i(6, 6), "the rite is a legal monster intent aimed at the corpse")
	var ap_before := int(boss["ap"])
	var seats_before: int = (sim.snapshot()["units"] as Array).size()
	eq(bool(sim.submit({"type": "cast", "spell": str(sig["id"]), "to": legal_to, "seat": 1}).get("ok", false)), true, "she performs the rite")
	eq(int(boss["ap"]), ap_before - int(sig["ap"]), "the rite costs %d AP" % int(sig["ap"]))
	var units: Array = sim.snapshot()["units"]
	eq(units.size(), seats_before + 1, "the risen one is a new body")
	var risen: Dictionary = units.back()
	eq(str(risen["monster"]), "bog_dead", "a Bog Dead rises")
	eq(risen["pos"], Vector2i(6, 6), "it rises where it fell")
	eq(int(risen["hp"]), int(round(float(risen["max_hp"]) * float(sig["hp_pct"]))), "it rises at half HP (%d of %d)" % [int(risen["hp"]), int(risen["max_hp"])])
	eq(bool(risen["alive"]) and bool(risen["risen"]) and bool(risen["summoned"]), true, "it is alive, risen and goes with her")
	eq(bool(sim._unit_by_seat(2)["raised"]), true, "the corpse is used up")
	var raise_ev: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "raise":
			raise_ev = e
	eq([raise_ev.get("to"), int(raise_ev.get("corpse_seat", -1)), int(raise_ev.get("risen_seat", -1)), str(raise_ev.get("beam", ""))], [Vector2i(6, 6), 2, int(risen["seat"]), "rite_glow"], "the raise event carries the cell, the corpse, the risen seat and the glow")
	eq(str(raise_ev.get("coach", "")).contains("rises from the bog"), true, "the rite's line is the abbey's own (%s)" % raise_ev.get("coach", ""))
	eq(int(sim.snapshot()["dungeon"]["raised_total"]), 1, "one risen so far")
	eq(bool(sim.raise_ready(boss)), false, "one rite a turn")
	# She still lashes after the rite (2 + 4 AP).
	sim._unit_by_seat(0)["pos"] = Vector2i(6, 4)
	var lashed := false
	for d in AI.play_monster_turn(sim, 1):
		lashed = lashed or (str(d["intent"].get("spell", "")) == str(boss["attack"]["id"]) and bool(d["ok"]))
	eq(lashed, true, "after the rite she lashes a hero in reach")
	# The risen one takes its own turn this round, after the others.
	var acted := false
	var guard := 0
	while int(sim.snapshot()["active_seat"]) != 0 and guard < 10:
		guard += 1
		var seat := int(sim.snapshot()["active_seat"])
		acted = acted or seat == int(risen["seat"])
		AI.play_monster_turn(sim, seat)
	eq(acted, true, "the risen Bog Dead takes a turn")
	# With the AI, the rite comes on turns 2, 4, 6 while corpses lie free.
	var book = Monsters.load_default()["monsters"]
	var extra: Array = []
	for at in [Vector2i(1, 1), Vector2i(10, 1), Vector2i(1, 4), Vector2i(10, 4)]:
		var b: Dictionary = book.stats_at("bog_dead", LEVEL)
		b["pos"] = at
		b["facing"] = "S"
		extra.append(b)
	var cfg := _rite_room(Vector2i(6, 1), Vector2i(6, 10), [], 1, extra)
	sim.reset_match(cfg)
	sim._unit_by_seat(1)["signature"]["cap_total"] = 9
	for s in [2, 3, 4, 5]:
		_kill(s)
	var rose_on: Array = []
	for round_n in 7:
		if bool(sim.snapshot()["match_over"]):
			break
		sim._unit_by_seat(0)["pos"] = Vector2i(6, 11)
		sim._unit_by_seat(0)["hp"] = 80
		sim.submit({"type": "end_turn", "seat": 0})
		var b2: Dictionary = sim._unit_by_seat(1)
		for d in AI.play_monster_turn(sim, 1):
			if str(d["intent"].get("spell", "")) == str(sig["id"]) and bool(d["ok"]):
				rose_on.append(int(b2["own_turns"]))
		while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]):
			var u: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
			u["mp"] = 0
			sim.submit({"type": "end_turn", "seat": int(u["seat"])})
	eq(rose_on, [2, 4, 6], "with corpses always down the rite comes on her 2nd turn and every 2nd after (%s)" % [rose_on])
	# Off the beat: no corpse on her 2nd turn, one falls before her 3rd: she
	# raises it on her 3rd, then rests on her 4th.
	sim.reset_match(_rite_room(Vector2i(6, 1), Vector2i(6, 10), [Vector2i(2, 5), Vector2i(10, 5)]))
	var b3: Dictionary = sim._unit_by_seat(1)
	var got_on: Array = []
	for round_n in 5:
		if round_n == 2:
			_kill(2)
		if round_n == 3:
			_kill(3)
		sim._unit_by_seat(0)["pos"] = Vector2i(6, 11)
		sim.submit({"type": "end_turn", "seat": 0})
		if bool(sim.raise_ready(b3)):
			got_on.append(int(b3["own_turns"]))
			sim.submit({"type": "cast", "spell": str(sig["id"]), "to": sim._raise_corpse(b3)["pos"], "seat": 1})
		_round_to_hero()
	eq(got_on, [3, 5], "a corpse that falls after her 2nd turn rises on her next turn; the rite then rests a turn (%s)" % [got_on])


func _test_rite_corpses_and_cap() -> void:
	# No corpse, no rite.
	sim.reset_match(_rite_room(Vector2i(6, 2), Vector2i(6, 10), [Vector2i(3, 6)]))
	var boss: Dictionary = sim._unit_by_seat(1)
	boss["own_turns"] = 2
	eq(bool(sim.raise_ready(boss)), false, "no rite with every Bog Dead standing")
	var refused: Dictionary = sim.submit({"type": "cast", "spell": "rite_of_rising", "to": Vector2i(3, 6), "seat": 0})
	eq(bool(refused.get("ok", true)), false, "a rite cast out of turn is refused")
	# A hero standing on the corpse keeps it down.
	_kill(2)
	sim.submit({"type": "end_turn", "seat": 0})
	boss["own_turns"] = 2
	sim._unit_by_seat(0)["pos"] = Vector2i(3, 6)
	eq(bool(sim.raise_ready(boss)), false, "a hero on the corpse keeps it down")
	var on_corpse: Dictionary = sim.submit({"type": "cast", "spell": "rite_of_rising", "to": Vector2i(3, 6), "seat": 1})
	eq(str(on_corpse.get("reason", "")), "raise_not_ready", "the rite is refused while the hero stands there")
	sim._unit_by_seat(0)["pos"] = Vector2i(4, 7)
	eq(bool(sim.raise_ready(boss)), true, "stepping off lets the rite through")
	# Only the raise kinds rise: a fallen leech stays down for the Mire Abbess.
	var book = Monsters.load_default()["monsters"]
	var leech: Dictionary = book.stats_at("mire_leech", LEVEL)
	leech["pos"] = Vector2i(9, 3)
	leech["facing"] = "S"
	sim.reset_match(_rite_room(Vector2i(6, 2), Vector2i(6, 10), [], 1, [leech]))
	_kill(2)
	sim.submit({"type": "end_turn", "seat": 0})
	sim._unit_by_seat(1)["own_turns"] = 2
	eq(bool(sim.raise_ready(sim._unit_by_seat(1))), false, "the Mire Abbess does not raise a Mire Leech")
	# A risen one that falls again stays down; the cap holds.
	sim.reset_match(_rite_room(Vector2i(6, 2), Vector2i(6, 10), [Vector2i(5, 6), Vector2i(7, 6), Vector2i(9, 6)]))
	boss = sim._unit_by_seat(1)
	var cap := int(boss["signature"]["cap_total"])
	for s in [2, 3, 4]:
		_kill(s)
	var raised := 0
	for attempt in 6:
		sim.submit({"type": "end_turn", "seat": 0})
		boss["own_turns"] = 2
		boss["acted_signature"] = false
		boss.erase("last_raise_turn")
		boss["ap"] = int(boss["max_ap"])
		if bool(sim.raise_ready(boss)):
			var to: Vector2i = sim._raise_corpse(boss)["pos"]
			if bool(sim.submit({"type": "cast", "spell": "rite_of_rising", "to": to, "seat": 1}).get("ok", false)):
				raised += 1
				# Strike the risen one down again at once.
				_kill(int((sim.snapshot()["units"] as Array).back()["seat"]))
		_round_to_hero()
	eq(raised, cap, "she raises %d in a fight, no more (%d)" % [cap, raised])
	var downs := 0
	for u in sim.snapshot()["units"]:
		if bool(u.get("risen", false)):
			downs += 1
			eq(bool(u["alive"]), false, "a struck-down risen one stays down")
	eq(downs, cap, "every risen one was a new body")
	sim.submit({"type": "end_turn", "seat": 0})
	boss["own_turns"] = 2
	boss["acted_signature"] = false
	boss.erase("last_raise_turn")
	eq(bool(sim.raise_ready(boss)), false, "no rite past the cap, even with a corpse left")


func _test_rite_scatter_and_star5() -> void:
	sim.reset_match(_rite_room(Vector2i(6, 2), Vector2i(6, 10), [Vector2i(6, 6), Vector2i(3, 3)]))
	var boss: Dictionary = sim._unit_by_seat(1)
	_kill(2)
	sim.submit({"type": "end_turn", "seat": 0})
	boss["own_turns"] = 2
	sim.submit({"type": "cast", "spell": "rite_of_rising", "to": Vector2i(6, 6), "seat": 1})
	var risen: Dictionary = (sim.snapshot()["units"] as Array).back()
	_kill(1)
	var scatter: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "scatter":
			scatter = e
	eq((scatter.get("fled", []) as Array).has(int(risen["seat"])), true, "with the Abbess down, the risen sink back")
	eq(str(scatter.get("coach", "")).contains("sink back into the bog"), true, "the scatter line is the abbey's own (%s)" % scatter.get("coach", ""))
	eq(bool(sim._unit_by_seat(3)["alive"]), true, "her own escort stays and must be beaten")
	eq(bool(sim.snapshot()["match_over"]), false, "the room is not won while the escort stands")
	_kill(3)
	eq(str(sim.snapshot()["dungeon"]["result"]), "win", "the room is won when every monster is down")
	# ★5: the Tolling Rite raises a leech too, at 60%.
	var book = Monsters.load_default()["monsters"]
	var leech: Dictionary = book.stats_at(G_LEECH, LEVEL, 5)
	leech["pos"] = Vector2i(9, 3)
	leech["facing"] = "S"
	sim.reset_match(_rite_room(Vector2i(6, 2), Vector2i(6, 10), [], 5, [leech]))
	var g: Dictionary = sim._unit_by_seat(1)
	_kill(2)
	sim.submit({"type": "end_turn", "seat": 0})
	g["own_turns"] = 2
	g["acted_signature2"] = true
	eq(bool(sim.raise_ready(g)), true, "the ★5 Abbess raises a fallen leech")
	sim.submit({"type": "cast", "spell": str(g["signature"]["id"]), "to": Vector2i(9, 3), "seat": 1})
	var up: Dictionary = (sim.snapshot()["units"] as Array).back()
	eq(str(up["monster"]), G_LEECH, "a ★5 leech rises")
	eq(int(up["hp"]), int(round(float(up["max_hp"]) * 0.6)), "at 60%% HP (%d)" % int(up["hp"]))
	eq(bool((up["attack"] as Dictionary).get("los", false)), true, "it still spits with a line")


# --- ★5 grasping mire, the bellbound mire, cleansing ------------------------------------

func _test_star5_grasping_mire() -> void:
	var run = Run.create(ABBEY, LEVEL, "kestrel", "", 5)["run"]
	var cfg: Dictionary = run.combat_config(1, 31)
	cfg["rolls"] = []
	for i in 300:
		cfg["rolls"].append(99)
	sim.reset_match(cfg)
	var boss: Dictionary = sim._unit_by_seat(1)
	eq(str(boss["name"]), G_BOSS_NAME, "★5 room B boss is %s" % G_BOSS_NAME)
	var sig2: Dictionary = boss["signature2"]
	var hero: Dictionary = sim._unit_by_seat(0)
	hero["pos"] = Vector2i(6, 9)
	sim.submit({"type": "end_turn", "seat": 0})
	eq(int(boss["own_turns"]), 1, "her 1st turn")
	eq(bool(sim.pools_ready(boss)), true, "the mire is ready on her 1st turn")
	var hero_cell: Vector2i = hero["pos"]
	eq(bool(sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero_cell, "seat": 1}).get("ok", false)), true, "she calls the mire")
	var cells: Array = sim.pool_cells()
	eq(cells.size() >= int(sig2["cells_min"]) and cells.size() <= int(sig2["cells_max"]), true, "2-3 mire cells (%d)" % cells.size())
	eq(cells.has(hero_cell), true, "a mire cell lands under the hero")
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(str(p.get("hazard", "")), "grasping_mire", "the snapshot names the hazard grasping_mire")
		eq(bool(p.get("root", false)), true, "a mire cell roots")
	var lay := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pools":
			lay = str(e.get("coach", ""))
			eq(str(e.get("hazard", "")), "grasping_mire", "the hazard event names grasping_mire for the view")
	eq(lay.contains("reach for"), true, "the lay line is the mire's own (%s)" % lay)
	while int(sim.snapshot()["active_seat"]) != 0:
		var u: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
		u["acted_signature"] = true
		sim.submit({"type": "end_turn", "seat": int(u["seat"])})
	hero["hp"] = 80
	hero["pos"] = hero_cell
	sim.submit({"type": "end_turn", "seat": 0})
	var hit: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pool_hit":
			hit = e
	eq(hit.is_empty(), false, "ending the turn in the mire hurts")
	eq(int(hit.get("damage", 0)), int(sig2["hp"]), "mire damage is %d" % int(sig2["hp"]))
	eq(bool(hit.get("root", false)), true, "the hit roots the hero")
	eq(str(hit.get("coach", "")).contains("grasping mire"), true, "the hit line is the mire's own")
	eq(80 - int(hero["hp"]), int(sig2["hp"]), "the hero lost the mire damage")
	while int(sim.snapshot()["active_seat"]) != 0:
		var u2: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
		u2["acted_signature"] = true
		u2["acted_signature2"] = true
		sim.submit({"type": "end_turn", "seat": int(u2["seat"])})
	eq(int(hero["mp"]), 0, "a rooted hero has no MP on the next turn")
	var drain_line := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "chill":
			drain_line = str(e.get("coach", ""))
	eq(drain_line.contains("The mire holds"), true, "the root line is the mire's own (%s)" % drain_line)
	# Walking across is safe: only ending a turn there hurts; it lasts 3 hero turns.
	sim.reset_match(cfg)
	boss = sim._unit_by_seat(1)
	hero = sim._unit_by_seat(0)
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero["pos"], "seat": 1})
	var turns := 1
	var guard := 0
	while not sim.pool_cells().is_empty() and guard < 40:
		guard += 1
		if int(sim.snapshot()["active_seat"]) == 0:
			hero["pos"] = Vector2i(0, 11)
			hero["hp"] = 80
			sim.submit({"type": "end_turn", "seat": 0})
			turns += 1
		else:
			var u3: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
			u3["acted_signature"] = true
			u3["acted_signature2"] = true
			sim.submit({"type": "end_turn", "seat": int(u3["seat"])})
	eq(turns - 1, int(sig2["turns"]), "the mire lasts %d hero turns" % int(sig2["turns"]))
	eq(int(hero["hp"]), 80, "ending turns off the mire costs nothing")
	# The hero bot never ends a turn in the mire when it can step off.
	sim.reset_match(run.combat_config(1, 35))
	sim.submit({"type": "end_turn", "seat": 0})
	var b2: Dictionary = sim._unit_by_seat(1)
	sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	b2["acted_signature"] = true
	while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]):
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
	var on_before: bool = sim.pool_cells().has(sim._unit_by_seat(0)["pos"])
	AI.play_hero_turn(sim)
	var hit2 := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pool_hit":
			hit2 = true
	eq(on_before, true, "the bot starts its turn in the mire")
	eq(hit2, false, "the hero bot steps off before ending its turn")


func _test_mire_and_cleanse() -> void:
	var book = Monsters.load_default()["monsters"]
	var gl: Dictionary = book.stats_at(G_LEECH, LEVEL, 5)
	var cells: Array = []
	for y in 12:
		for x in 12:
			var pad := Vector2i(x, y) == Vector2i(8, 8)
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["candle_pad"] if pad else [], "blocks": false, "special": "pad" if pad else ""})
	var a := gl.duplicate(true)
	a["pos"] = Vector2i(8, 4)
	a["facing"] = "S"
	a["mp"] = 0
	var run = Run.create(ABBEY, LEVEL, "kestrel", "", 5)["run"]
	var thaw_text := str(run.combat_config(0, 1)["dungeon"]["pad_thaw_text"])
	var room := {"dungeon_id": ABBEY, "room_id": "mire", "room_name": "Mire", "kind": "pack", "cells": cells, "pad_heal": 5, "pad_thaw": true, "pad_thaw_text": thaw_text, "hero": {"class_id": "bastion", "pos": Vector2i(5, 7), "facing": "N"}, "monsters": [a], "summons": {}}
	var rolls: Array = []
	for i in 40:
		rolls.append(1)
	sim.reset_match({"board_size": 12, "seed": 4, "dungeon": room, "rolls": rolls})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(gl["attack"]["id"]), "to": Vector2i(5, 7), "target_seat": 0, "seat": 1})
	var line := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("status", "")) == "chill":
			line = str(e.get("coach", ""))
	eq(line.contains("mired"), true, "a bellbound hit mires the hero (%s)" % line)
	sim.submit({"type": "end_turn", "seat": 1})
	var hero: Dictionary = sim._unit_by_seat(0)
	eq(int(hero["mp"]), int(hero["max_mp"]) - 1, "a mired hero has 1 MP less on the next turn")
	hero["pos"] = Vector2i(8, 8)
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(gl["attack"]["id"]), "to": Vector2i(8, 8), "target_seat": 0, "seat": 1})
	sim.submit({"type": "end_turn", "seat": 1})
	eq(int(hero["mp"]), int(hero["max_mp"]), "a turn that starts on a candle pad keeps its full MP")
	var cleanse := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "thaw":
			cleanse = str(e.get("coach", ""))
	eq(cleanse.contains("cleanses"), true, "the pad's line is the abbey's own (%s)" % cleanse)
	# A root on a pad is cleansed too.
	var boss: Dictionary = book.stats_at(G_BOSS, LEVEL, 5)
	boss["pos"] = Vector2i(2, 1)
	boss["facing"] = "S"
	room["monsters"] = [boss]
	room["hero"] = {"class_id": "bastion", "pos": Vector2i(8, 8), "facing": "N"}
	sim.reset_match({"board_size": 12, "seed": 4, "dungeon": room, "rolls": rolls})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": "grasping_mire", "to": Vector2i(8, 8), "seat": 1})
	sim._unit_by_seat(1)["acted_signature"] = true
	sim.submit({"type": "end_turn", "seat": 1})
	sim.submit({"type": "end_turn", "seat": 0})
	var rooted := false
	for e in sim.snapshot()["last_events"]:
		rooted = rooted or (str(e.get("type", "")) == "pool_hit" and bool(e.get("root", false)))
	eq(rooted, true, "the hero ends a turn rooted on the pad")
	sim._unit_by_seat(1)["acted_signature"] = true
	sim._unit_by_seat(1)["acted_signature2"] = true
	sim.submit({"type": "end_turn", "seat": 1})
	hero = sim._unit_by_seat(0)
	eq(int(hero["mp"]), int(hero["max_mp"]), "the candle pad cleanses the root")


# --- rewards -----------------------------------------------------------------------

func _test_rewards_per_star() -> void:
	var base_xp := 0
	var base_coins := 0
	var parts := {}
	for star in range(1, 6):
		var run = Run.create(ABBEY, LEVEL, "kestrel", "", star)["run"]
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
				eq(str(item.get("rarity", "regular")) in ["regular", "rare", "special", ""], true, "★%d drops no epic or relic (%s)" % [star, item.get("item_id", "")])
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
		eq(int(hero.best_dungeon_star(ABBEY)), star, "★%d clear is the abbey's best star" % star)
		eq(bool(s3.get("new_best_star", false)), true, "★%d is a new best" % star)
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/level_curve.json"))
	var need := float((curve["xp_to_next"] as Array)[LEVEL - 1])
	var expect_xp := int(round(0.27 * need * float(curve["pace_start"]) * pow(float(curve["pace_ratio"]), LEVEL - 1)))
	eq(base_xp, expect_xp, "level 32 ★1 XP is 27%% of xp_to_next(32) x pace (%d)" % expect_xp)
	eq(base_xp > Run.create(SALT, 22, "kestrel")["run"].win_xp(22), true, "the abbey pays more XP than the grotto")
	eq(base_coins > 0, true, "an abbey win pays coins (%d)" % base_coins)
	var set_part := false
	for id in parts.keys():
		if str(id).begins_with("mire_abbess_"):
			set_part = true
	eq(set_part, true, "the abbey drops Mire Abbess set parts (the tier-30 set)")


func _test_mission_credit() -> void:
	var missions = Missions.load_default()["missions"]
	var hero = _fresh_hero()
	hero.level = LEVEL
	hero.mission_blob = {"story": {"southbridge_scout": {"status": "done"}}}
	eq(missions.label_for("southbridge_dungeon", hero) != "coming soon", true, "the Southbridge dungeon mission is live")
	eq(bool(missions.accept("southbridge_dungeon", hero).get("ok", false)), true, "the mission can be taken")
	var run = Run.create(ABBEY, LEVEL, "kestrel", "", 1)["run"]
	run.result = "win"
	var sm: Dictionary = run.pay_out(hero, missions, _rng(3), false)
	eq((sm["missions"] as Array).has("southbridge_dungeon"), true, "an abbey win credits the clear_dungeon mission")
	var offer: Array = missions.mission("southbridge_dungeon")["lines"]["offer"]
	eq(str(offer[0]).contains("not open yet"), false, "the offer no longer says the way is shut")


# --- the other three dungeons are unchanged ------------------------------------------

func _test_others_unchanged() -> void:
	var book = Monsters.load_default()["monsters"]
	eq(book.ids_for(GRANARY), ["granary_rat", "sling_rat", "scarecrow_drudge", "the_ratking", "radioactive_rat", "radioactive_sling_rat", "radioactive_ratking"], "the cellar keeps its seven monsters")
	eq(book.ids_for(FROST), ["ice_construct", "book_wraith", "the_pale_archivist", "frozen_ice_construct", "frozen_book_wraith", "the_frozen_archivist"], "the archive keeps its six monsters")
	eq(book.ids_for(SALT), ["reef_crab", "drowned_sailor", "drowned_harpooner", "old_saltmaw", "abyssal_reef_crab", "abyssal_drowned_sailor", "abyssal_drowned_harpooner", "abyssal_saltmaw"], "the grotto keeps its eight monsters")
	var rows := {1: [1.0, 1.0], 2: [1.1, 1.05], 3: [1.15, 1.1], 4: [1.2, 1.1], 5: [1.0, 1.0]}
	var frost_rows := {1: [1.0, 1.0], 2: [1.05, 1.0], 3: [1.05, 1.0], 4: [1.1, 1.0], 5: [0.875, 0.85]}
	var salt_rows := {1: [1.0, 1.0], 2: [1.05, 1.0], 3: [1.1, 1.05], 4: [1.25, 1.05], 5: [1.05, 1.05]}
	for star in range(1, 6):
		eq(book.star_scale(star, GRANARY), rows[star], "the cellar's ★%d row is unchanged" % star)
		eq(book.star_scale(star, FROST), frost_rows[star], "the archive's ★%d row is unchanged" % star)
		eq(book.star_scale(star, SALT), salt_rows[star], "the grotto's ★%d row is unchanged" % star)
	eq([int(book.stats_at("old_saltmaw", 22)["hp"]), int(book.stats_at("old_saltmaw", 22)["attack"]["damage"])], [92, 8], "Old Saltmaw 92 HP, Bite 8 at level 22")
	eq(str(book.stats_at("old_saltmaw", 22)["signature"]["kind"]), "pull", "Old Saltmaw still pulls")
	eq(str(book.stats_at("the_pale_archivist", 12)["signature"]["kind"]), "summon", "the Archivist still summons")
	# The grotto's riptide and the archive's frost patch keep their records and lines.
	var s_run = Run.create(SALT, 22, "kestrel", "", 5)["run"]
	sim.reset_match(s_run.combat_config(1, 31))
	sim.submit({"type": "end_turn", "seat": 0})
	var salt: Dictionary = sim._unit_by_seat(1)
	salt["own_turns"] = 2
	salt["acted_signature"] = true
	sim.submit({"type": "cast", "spell": "riptide", "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(p.has("root") or p.has("word") or p.has("drain_text"), false, "a riptide record has no mire keys")
	eq(bool(sim.raise_ready(salt)), false, "Old Saltmaw has no rite")
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
		eq(p.has("root") or p.has("drag") or p.has("hit_text"), false, "a frost patch record has no newer keys")
	var g_run = Run.create(GRANARY, 1, "kestrel", "", 5)["run"]
	sim.reset_match(g_run.combat_config(1, 31))
	sim.submit({"type": "end_turn", "seat": 0})
	var king: Dictionary = sim._unit_by_seat(1)
	eq(bool(sim.raise_ready(king)), false, "the Ratking has no rite")
	sim.submit({"type": "cast", "spell": str(king["signature2"]["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(p.has("hazard") or p.has("mp_loss") or p.has("root"), false, "a toxic pool record is unchanged")
	eq(Run.create(GRANARY, 1, "kestrel")["run"].text("victory"), "Old Granary Cellar is cleared at ★1. The Ratking is down.", "the cellar victory line is unchanged")
	eq(Run.create("heart_of_the_blight", 42, "kestrel").get("ok", false), true, "the Heart of the Blight is built now")


# --- world door, panel, scene --------------------------------------------------------

func _test_world_door_and_panel() -> void:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.progress.level = LEVEL
	w.enter_zone(ZONE, Vector2i(20, 10), false)
	await process_frame
	eq(w.zone.zone_id, ZONE, "the hero is in Southbridge")
	eq(w.door_nodes.has(ABBEY), true, "the abbey door stands in Southbridge")
	var row: Dictionary = w.dungeon_book.by_id(ABBEY)
	var building: Array = Dungeons.building_cells_for(row, w.building_size_for(row))
	for c in building:
		eq(w.zone.passable_at(c), false, "chapel cell %s blocks walking" % c)
	eq(w.zone.passable_at(DOOR), true, "the door cell stays walkable")
	eq(w.door_at(ZONE, DOOR).get("id", ""), ABBEY, "the door cell is a door")
	eq(w.door_at(ZONE, building[0]).get("id", ""), ABBEY, "clicking the chapel finds the door")
	var man_ok := bool(Art.manifest("res://art/pc/dungeons/drowned_abbey/manifest.json").get("ok", false))
	if man_ok:
		eq(w.door_nodes[ABBEY].painted, true, "the door draws the painted chapel")
	eq(bool(w.approach_door(ABBEY).get("ok", false)), true, "clicking the door walks there")
	_drive(w)
	eq(w.walker.cell, DOOR, "the hero stands on the door cell")
	eq(w.door_panel.is_open(), true, "the entry panel opens on arrival")
	var text := _panel_text(w.door_panel)
	eq(text.contains("Drowned Abbey"), true, "panel names the abbey")
	eq(text.contains("30–40"), true, "panel shows levels 30-40")
	eq(text.contains("The Mire Abbess"), true, "panel names the boss")
	eq(bool(w.door_panel.check.get("ok", false)), true, "a level 32 hero passes the level check")
	eq(w.door_panel.star_buttons.size(), 5, "★1-★5 on the panel")
	w.door_panel.select_star(5)
	eq((w.door_panel.find_child("StarNote", true, false) as Label).text.contains(G_BOSS_NAME.trim_prefix("The ")), true, "the ★5 note is the abbey's")
	w.door_panel.leave_button.emit_signal("pressed")
	w._approach_npc(w.npc_book.by_id("drowned_abbey_door_keeper"))
	_drive(w)
	eq(w.door_panel.is_open(), true, "talking to the Door Keeper opens the entry panel")
	Launcher.pending = {}
	w.door_panel.select_star(3)
	w.door_panel.press_enter()
	eq(str(Launcher.pending.get("dungeon_id", "")), ABBEY, "Enter hands over the abbey")
	eq(int(Launcher.pending.get("star", 0)), 3, "Enter hands over the picked star")
	eq(Launcher.pending.get("return_cell", Vector2i(-1, -1)), DOOR, "the way back is the door cell")
	eq(str(Launcher.pending.get("return_zone", "")), ZONE, "the way back is Southbridge")
	Launcher.pending = {}
	w.queue_free()
	await process_frame


func _test_run_scene_win_and_return() -> void:
	Launcher.pending = {"dungeon_id": ABBEY, "level": LEVEL, "class_id": "bastion", "autoplay": true, "return_zone": ZONE, "return_cell": DOOR, "seed": 1}
	Launcher.outcome = {}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	var got := {}
	scene.run_finished.connect(func(r, s): got["result"] = r; got["summary"] = s)
	root.add_child(scene)
	var rooms := {}
	var spits := false
	var t0 := Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
		var snap: Dictionary = sim.snapshot()
		if snap.has("dungeon"):
			rooms[str(snap["dungeon"]["room_id"])] = true
			for e in snap.get("last_events", []):
				spits = spits or str(e.get("projectile", "")) == "bile_spit"
	eq(str(got.get("result", "")), "win", "the room scene plays a full abbey run to a win")
	eq(rooms.has("room_a") and rooms.has("room_b"), true, "both rooms are played")
	eq(spits, true, "Mire Leech bile flies in the scene")
	var board = scene.get_node("BoardView")
	eq(str(board.view_cfg.get("pads", {}).keys()), str(["candle_pad", "rune_circle"]), "the board reads the abbey's pad styles")
	eq(scene.result_text().contains("The Mire Abbess is down"), true, "the result panel names the Mire Abbess")
	eq(scene.result_text().contains("Southbridge"), true, "the result panel sends the hero back to Southbridge")
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
	eq(w.zone.zone_id, ZONE, "back in Southbridge")
	eq(w.walker.cell, DOOR, "back on the abbey door cell")
	eq(w.reward_popup.is_open(), true, "the reward pop-up shows the drop")
	w.queue_free()
	await process_frame


# --- helpers -----------------------------------------------------------------------

func _resolve_star5_ids() -> void:
	var book = Monsters.load_default()["monsters"]
	for id in book.ids_for(ABBEY):
		var row: Dictionary = book.raw(id)
		if int(row.get("star_min", 0)) < 5:
			continue
		match str(row.get("variant_of", "")):
			"bog_dead": G_BOG = id
			"mire_leech": G_LEECH = id
			"mire_abbess": G_BOSS = id
	var run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/dungeons/drowned_abbey/run.json"))
	G_BOSS_NAME = str(run["text"]["boss_star5"])
	eq(G_BOG != "" and G_LEECH != "" and G_BOSS != "", true, "every abbey base monster has a ★5 form (%s, %s, %s)" % [G_BOG, G_LEECH, G_BOSS])
	eq(str(book.raw(G_BOSS).get("name", "")), G_BOSS_NAME, "the ★5 boss's name is the run file's boss_star5")


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
