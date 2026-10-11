extends SceneTree

## PC dungeon 5, the Heart of the Blight (Westwatch, levels 40-50): the door
## and its rotting stump on Westwatch's blighted west plain, the run file and
## rooms (every cell reachable, root knots, the root mound and the rune
## circle's crystal spires break lines), pack sizes per star, the AI always
## ending its turn, Blight Horror line of sight and kiting, the Rotting
## Elder's Root Wall (signature kind wall: rhythm, where the roots rise, what
## they block, how long they stand, never on a pad, a body or a corpse, never
## sealing anyone in), the ★5 Crystal Colossus and his Crystal Bloom (fused
## pods: the telegraph, the burst, the splash, the wither), the crystal
## wither and the cleansing pads, rewards per star, the Westwatch mission, a
## full run in the room scene, and guards that the other four dungeons play
## exactly as before.
## Run: godot --headless --path . -s res://tests/run_blight_tests.gd

const Dungeons := preload("res://backend/world_dungeons.gd")
const Monsters := preload("res://backend/pc_monsters.gd")
const Run := preload("res://backend/pc_dungeon_run.gd")
const AI := preload("res://backend/dungeon_ai.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const NpcBook := preload("res://backend/world_npcs.gd")
const Missions := preload("res://backend/pc_missions.gd")
const Progress := preload("res://backend/pc_progress.gd")
const Rewards := preload("res://backend/pc_rewards.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const Launcher := preload("res://scenes/world/dungeon/dungeon_launcher.gd")
const Regions := preload("res://backend/world_regions.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const RUN_SCENE_PATH := "res://scenes/world/dungeon/dungeon_run.tscn"
const BLIGHT := "heart_of_the_blight"
const ABBEY := "drowned_abbey"
const SALT := "saltmaw_grotto"
const FROST := "frostspire_archive"
const GRANARY := "old_granary_cellar"
const ZONE := "crosshaven_westwatch"
const DOOR := Vector2i(5, 13)
const KEEPER := Vector2i(6, 13)
const LEVEL := 42
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]

var _passed := 0
var _failed := 0
var sim: Node
## The ★5 forms' ids and the ★5 boss name come from the data (variant_of +
## star_min 5, run.json text.boss_star5), so renaming the mutated forms costs
## nothing here.
var G_HOUND := ""
var G_HORROR := ""
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
	_test_horror_los_and_kiting()
	_test_root_wall()
	_test_root_wall_rhythm_and_ai()
	_test_root_wall_never_seals()
	_test_star5_crystal_bloom()
	_test_wither_and_cleanse()
	_test_rewards_per_star()
	_test_loot_tiers()
	_test_star_drop_rates()
	_test_mission_credit()
	_test_others_unchanged()
	await _test_world_door_and_panel()
	await _test_run_scene_win_and_return()
	_finish()


func _finish() -> void:
	print("blight tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- door ------------------------------------------------------------------------

func _test_door_data() -> void:
	var loaded: Dictionary = Dungeons.load_default()
	eq(bool(loaded.get("ok", false)), true, "dungeons.json loads: %s" % [loaded.get("errors", [])])
	var book = loaded["dungeons"]
	var row: Dictionary = book.by_id(BLIGHT)
	eq(str(row.get("status", "")), "built", "the Heart of the Blight is built")
	eq(str(row["level_zone"]), "westwatch", "it is Westwatch's dungeon")
	eq([int(row["level_min"]), int(row["level_max"])], [40, 50], "levels 40-50")
	eq(str(row["boss"]), "The Rotting Elder", "the boss is the Rotting Elder")
	eq(Dungeons.door_cell(row), DOOR, "the blight door is at 5,13")
	eq(str(row["door"]["zone_id"]), ZONE, "the door is in the Westwatch chunk")
	eq(str(row["run"]), "res://data/world/dungeons/heart_of_the_blight/run.json", "the run file is named")
	var shape: Dictionary = Dungeons.building_shape(row)
	var size: Vector2i = shape.get("size", Vector2i(3, 3))
	var from_nw: Vector2i = shape.get("door_from_nw", Vector2i(1, 3))
	if from_nw.x < 0:
		from_nw = Vector2i(int((size.x - 1) / 2), size.y)
	var building := Dungeons.building_cells_for(row)
	eq(building.size(), size.x * size.y, "%d building cells (the manifest footprint %dx%d)" % [size.x * size.y, size.x, size.y])
	eq(building.has(DOOR + Vector2i(0, -1)), true, "the stump's mouth cell is just north of the door")
	var nw := DOOR - from_nw
	for c in building:
		eq(c.x >= nw.x and c.x < nw.x + size.x and c.y >= nw.y and c.y < nw.y + size.y, true, "building cell %s on the footprint" % c)
	var atlas = Atlas.load_default()["atlas"]
	var npcs = NpcBook.load_default()["npcs"]
	var checked: Dictionary = book.validate_world(atlas, npcs, Art.building_size(Art.manifest(_granary_art()), Dungeons.DEFAULT_BUILDING))
	eq(bool(checked["ok"]), true, "4.6 rules hold with all five doors: %s" % [checked["errors"]])
	var zone: WorldZone = atlas.map_for_chunk(ZONE).zone(ZONE)
	eq(zone.passable_at(DOOR), true, "the door cell is passable")
	eq(zone.in_bounds(DOOR), true, "the door is inside the chunk")
	eq(zone.exit_link(DOOR).is_empty(), true, "the door is not an exit")
	eq(atlas.gate_at(ZONE, DOOR).is_empty(), true, "the door is not a gate")
	eq(DOOR != zone.spawn, true, "the door is not the spawn")
	eq(DOOR.x < zone.spawn.x, true, "the door is on the west (blighted) side of the town")
	for c in building:
		eq(zone.passable_at(c), true, "building cell %s is open ground before the stump blocks it" % c)
	for npc in npcs.for_zone(ZONE):
		var at := Vector2i(int(npc["cell"]["x"]), int(npc["cell"]["y"]))
		eq(at != DOOR and not building.has(at), true, "%s is not on the door or the building" % npc["id"])
	var keeper: Dictionary = npcs.by_id("westwatch_door_keeper")
	eq(str(keeper["role"]), "door_keeper", "the Westwatch Door Keeper is a door keeper")
	eq(Vector2i(int(keeper["cell"]["x"]), int(keeper["cell"]["y"])), KEEPER, "the Door Keeper stands beside the door")
	eq(book.for_keeper("westwatch_door_keeper").get("id", ""), BLIGHT, "the keeper opens the blight")
	eq(str((keeper["lines"] as Array).back()).contains("roots"), true, "the keeper warns of the roots")
	eq(Dungeons._door_reachable(zone, DOOR, building, npcs), true, "the door can be walked to from the chunk spawn round the stump")
	# A door moved onto the keeper, out of Westwatch or into the cliffs fails.
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Dungeons.PATH))
	var idx := -1
	for i in (base["dungeons"] as Array).size():
		if str(base["dungeons"][i]["id"]) == BLIGHT:
			idx = i
	var on_npc: Dictionary = base.duplicate(true)
	(on_npc["dungeons"] as Array)[idx]["door"] = {"zone_id": ZONE, "x": KEEPER.x, "y": KEEPER.y}
	eq(bool(Dungeons.load_document(on_npc)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a blight door on the keeper fails")
	var away: Dictionary = base.duplicate(true)
	(away["dungeons"] as Array)[idx]["door"] = {"zone_id": "crosshaven_southbridge", "x": 5, "y": 13}
	eq(bool(Dungeons.load_document(away)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a blight door outside Westwatch fails")
	var in_cliff: Dictionary = base.duplicate(true)
	(in_cliff["dungeons"] as Array)[idx]["door"] = {"zone_id": ZONE, "x": 5, "y": 30}
	eq(bool(Dungeons.load_document(in_cliff)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a blight door in the cliffs fails")
	var on_spawn: Dictionary = base.duplicate(true)
	(on_spawn["dungeons"] as Array)[idx]["door"] = {"zone_id": ZONE, "x": zone.spawn.x, "y": zone.spawn.y}
	eq(bool(Dungeons.load_document(on_spawn)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a blight door on the spawn fails")
	eq(book.built().size(), 5, "all five dungeons are built")


# --- run file and rooms --------------------------------------------------------

func _test_run_file_and_rooms() -> void:
	var made: Dictionary = Run.create(BLIGHT, LEVEL, "kestrel")
	eq(bool(made.get("ok", false)), true, "the blight run builds: %s" % [made.get("errors", [])])
	if not bool(made.get("ok", false)):
		return
	var run = made["run"]
	eq(run.level, LEVEL, "a level 42 hero runs at level 42")
	eq(int(Run.create(BLIGHT, 60, "kestrel")["run"].level), 50, "an over-band hero meets level 50 monsters")
	eq(int(Run.create(BLIGHT, 5, "kestrel")["run"].level), 40, "an under-band hero meets level 40 monsters")
	eq(run.room_count(), 2, "room A then room B")
	eq([str(run.room(0)["kind"]), str(run.room(1)["kind"])], ["pack", "boss"], "a pack room, then the boss")
	eq(str(run.run_doc["art"]), "res://art/pc/dungeons/heart_of_the_blight/manifest.json", "the art manifest is the blight kit")
	eq(str(run.text("stairs")).contains("root stair"), true, "the stairs line is the blight's")
	eq(run.text("return_button"), "Return to Westwatch", "the return button names Westwatch")
	eq(str((run.run_doc["text"] as Dictionary).get("star5_rule", "")).contains("Crystal Bloom"), true, "the ★5 rule text lives in the run file")
	eq(str((run.run_doc["text"] as Dictionary).get("signature_rule", "")).contains("Root Wall"), true, "the Root Wall's rule text lives in the run file")
	var man := Art.manifest(str(run.run_doc["art"]))
	eq(bool(man.get("ok", false)), true, "the blight art manifest loads")
	var raw: Dictionary = man.get("raw", {})
	var kit_props := {}
	for row in ((raw.get("board", {}) as Dictionary).get("props", []) as Array):
		kit_props[str(row["id"])] = row
	var room_props := {}
	for letter in ["a", "b"]:
		room_props["room_" + letter] = (((raw.get("board", {}) as Dictionary).get("rooms", {}) as Dictionary).get(letter, {}) as Dictionary).get("props", [])
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
				eq((room_props[label] as Array).has(prop), true, "%s prop %s is on the manifest's %s list" % [label, prop, label])
			else:
				walk[c] = true
			if str(rec["special"]) != "":
				pads += 1
		eq(blocked >= 10, true, "%s has prop obstacles (%d)" % [label, blocked])
		eq(pads >= 6, true, "%s has glowing pads (%d)" % [label, pads])
		var hero: Vector2i = room["hero"]["pos"]
		var seen := _flood(walk, hero, {})
		eq(seen.size(), walk.size(), "%s every walkable cell is reachable" % label)
		sim.reset_match(config)
		var snap: Dictionary = sim.snapshot()
		eq((snap["dungeon"]["pads"] as Array).size(), pads, "%s pads reach the sim" % label)
		eq((snap["dungeon"]["walls"] as Array).is_empty(), true, "%s starts with no root wall" % label)
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
	var spires := 0
	var b_walk := {}
	for rec in b_cells:
		var c: Vector2i = rec["pos"]
		var paint: Array = rec["paint_only"]
		if not bool(rec["blocks"]):
			b_walk[c] = true
		if paint.has("root_rune_circle"):
			circle += 1
			eq(c.x >= 4 and c.x <= 8 and c.y >= 4 and c.y <= 8, true, "rune circle cell %s is on the 5x5 decal (4-8 x 4-8)" % c)
			if str(rec["special"]) != "":
				glow += 1
				eq(c.x >= 5 and c.x <= 7 and c.y >= 5 and c.y <= 7, true, "pad %s is on the inner 3x3" % c)
		if paint.has("crystal_spire"):
			spires += 1
			eq(paint.has("root_rune_circle") and (c.x == 4 or c.x == 8) and (c.y == 4 or c.y == 8), true, "crystal spire %s stands on a corner of the circle" % c)
	eq(circle, 25, "room B's rune circle decal covers 5x5 cells")
	eq(glow, 9, "its inner 3x3 glow is the room's pads")
	eq(spires, 4, "four crystal spires on the circle's corners")
	eq(_flood(b_walk, Vector2i(6, 10), {}).has(Vector2i(6, 6)), true, "the circle's centre is reachable")
	var a_cells: Array = run.combat_config(0, 1)["dungeon"]["cells"]
	var blight_pads := 0
	var mound := 0
	for rec in a_cells:
		if (rec["paint_only"] as Array).has("blight_pad"):
			blight_pads += 1
		if str((rec["paint_only"] as Array)[0] if not (rec["paint_only"] as Array).is_empty() else "").begins_with("root_mound"):
			mound += 1
			eq(bool(rec["blocks"]), true, "root mound cell %s blocks" % rec["pos"])
	eq(blight_pads, 6, "room A has six violet blight pads")
	eq(mound, 4, "the root mound lies on 2x2 cells")
	var styles: Dictionary = run.run_doc["view"]["pads"]
	eq(bool(styles["root_rune_circle"].get("glow", false)), true, "the rune circle's pads draw the pad glow")


func _test_monsters() -> void:
	var book = Monsters.load_default()["monsters"]
	var ids: Array = book.ids_for(BLIGHT)
	eq(ids, ["blight_hound", "blight_horror", "rotting_elder", G_HOUND, G_HORROR, G_BOSS], "the blight's six monsters")
	for id in ids:
		var lo: Dictionary = book.stats_at(id, 40)
		var hi: Dictionary = book.stats_at(id, 50)
		eq(int(lo["level"]), 40, "%s starts at level 40" % id)
		eq(int(book.stats_at(id, 1)["level"]), 40, "%s clamps up to its band" % id)
		eq(int(hi["hp"]) > int(lo["hp"]), true, "%s grows through 40-50" % id)
		eq(str(lo["dungeon"]), BLIGHT, "%s belongs to the blight" % id)
	var hound: Dictionary = book.stats_at("blight_hound", LEVEL)
	var horror: Dictionary = book.stats_at("blight_horror", LEVEL)
	var boss: Dictionary = book.stats_at("rotting_elder", LEVEL)
	var abbey_bog: Dictionary = book.stats_at("bog_dead", 40)
	eq(int(hound["mp"]) > int(horror["mp"]) and int(hound["mp"]) > int(abbey_bog["mp"]), true, "the Blight Hound is fast (%d MP)" % int(hound["mp"]))
	eq(int(hound["attack"]["max_range"]), 1, "the Blight Hound is melee")
	eq(int(hound["hp"]) > int(horror["hp"]), true, "the hound is tougher than the horror")
	eq([int(horror["attack"]["min_range"]), int(horror["attack"]["max_range"])], [2, 5], "the Blight Horror throws at 2-5")
	eq(bool(horror["attack"]["los"]), true, "the Spore Bolt needs a line of sight")
	eq(str(horror["attack"]["projectile"]), "spore_bolt", "the bolt flies as spore_bolt")
	eq(str(horror["attack"]["impact"]), "spore_impact", "and bursts in spore_impact")
	eq(bool(boss["boss"]), true, "the Rotting Elder is the boss")
	eq([str(boss["attack"]["name"]), int(boss["attack"]["max_range"])], ["Root Claw", 1], "his Root Claw is melee")
	var sig: Dictionary = boss["signature"]
	eq([str(sig["name"]), str(sig["kind"])], ["Root Wall", "wall"], "Root Wall is a wall")
	eq([int(sig["cells"]), int(sig["turns"])], [3, 2], "3 root cells for 2 hero turns")
	eq([int(sig["first_turn"]), int(sig["every"])], [1, 3], "from his 1st turn and every 3rd after")
	eq([str(sig["prop"]), str(sig["beam"])], ["root_wall", "root_crack"], "the wall draws the kit's root_wall and root_crack")
	eq(int(boss["ap"]) >= int(sig["ap"]) + int(boss["attack"]["ap"]), true, "he can raise the wall and claw in one turn")
	var colossus: Dictionary = book.stats_at(G_BOSS, LEVEL, 5)
	eq(str(colossus["signature"]["kind"]), "wall", "the ★5 boss walls too")
	eq(int(colossus["signature"]["cells"]) > int(sig["cells"]), true, "with more root cells")
	eq(str(colossus["signature"]["prop"]), "crystal_wall", "his wall is the crystal wall")
	eq([str(colossus["attack"]["name"]), int(colossus["attack"]["max_range"])], ["Crystal Lance", 2], "his Crystal Lance reaches 1-2")
	var s2: Dictionary = colossus["signature2"]
	eq([str(s2["kind"]), str(s2["hazard"])], ["hazard", "crystal_bloom"], "his second move lays the crystal bloom")
	eq([int(s2["fuse"]), int(s2["splash"]), int(s2["ap_loss"])], [1, 1, 2], "a pod bursts after 1 hero turn, splashes 1 cell and takes 2 AP")
	eq(int(colossus["hp"]) > int(book.stats_at("rotting_elder", LEVEL, 5)["hp"]), true, "the Colossus is tougher than the Elder at ★5")
	var gh: Dictionary = book.stats_at(G_HORROR, LEVEL, 5)
	eq(str((gh["attack"].get("wither", {}) as Dictionary).get("word", "")), "crystallised", "Crystal Horror shards crystallise")
	eq(int((gh["attack"]["wither"] as Dictionary)["ap"]), 1, "1 AP")
	eq(str(gh["attack"]["projectile"]), "crystal_shard", "crystal shards fly as the art's crystal_shard")
	for id in [G_HOUND, G_HORROR, G_BOSS]:
		eq(str(book.stats_at(id, LEVEL, 5)["variant_of"]) != "", true, "%s is a mutated form" % id)
		eq(Art.monster_frames(Art.manifest("res://art/pc/dungeons/heart_of_the_blight/manifest.json"), id).get("painted", false), true, "%s has its own painted frames" % id)
	var check: Dictionary = book.check(LEVEL)
	eq(bool(check["ok"]), true, "level 42 numbers pass the sanity pass: %s" % [check["findings"]])
	var rows: Dictionary = book.stars_for(BLIGHT)["scale"]
	for star in range(1, 6):
		var m: Array = book.star_scale(star, BLIGHT)
		eq(m, [float(rows[str(star)][0]), float(rows[str(star)][1])], "★%d blight row comes from its own star block" % star)
	var prev := 0.0
	for star in range(1, 5):
		var m2: Array = book.star_scale(star, BLIGHT)
		eq(float(m2[0]) >= prev, true, "★%d blight HP row is not softer than the star below" % star)
		prev = float(m2[0])
	# Bad wall rows fail the load.
	for broken in ["no_cells", "zero_turns", "no_every", "bad_kind"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Monsters.PATH))
		for row in doc["monsters"]:
			if str(row["id"]) == "rotting_elder":
				var s: Dictionary = row["signature"]
				match broken:
					"no_cells": s.erase("cells")
					"zero_turns": s["turns"] = 0
					"no_every": s.erase("every")
					"bad_kind": s["kind"] = "hedge"
		eq(bool(Monsters.load_document(doc)["ok"]), false, "a wall signature with %s fails the load" % broken)


# --- stars and packs ------------------------------------------------------------

func _test_packs_per_star() -> void:
	var expect := {
		1: {"blight_hound": 4, "blight_horror": 2},
		2: {"blight_hound": 4, "blight_horror": 3},
		3: {"blight_hound": 4, "blight_horror": 3},
		4: {"blight_hound": 4, "blight_horror": 3},
		5: {G_HOUND: 4, G_HORROR: 4},
	}
	var totals := {1: 6, 2: 7, 3: 7, 4: 7, 5: 8}
	var hp_by_star := {}
	for star in range(1, 6):
		var run = Run.create(BLIGHT, LEVEL, "kestrel", "", star)["run"]
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
		eq(ranged >= 2, true, "★%d room A has ranged Blight Horrors (%d)" % [star, ranged])
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
		eq(str(mons[0]["monster"]), G_BOSS if star == 5 else "rotting_elder", "★%d boss form" % star)
		var escort := {}
		for m in mons.slice(1):
			escort[str(m["monster"])] = int(escort.get(str(m["monster"]), 0)) + 1
		var want := {G_HOUND: 2, G_HORROR: 1} if star == 5 else {"blight_hound": 2, "blight_horror": 1}
		eq(escort, want, "★%d escort: two hounds and a horror" % star)
		eq((boss_room["summons"] as Dictionary).is_empty(), true, "★%d a wall signature carries no summon stats" % star)
	for star in range(2, 5):
		eq(int(hp_by_star[star]) >= int(hp_by_star[star - 1]), true, "★%d room A pack is not weaker than ★%d" % [star, star - 1])


func _test_ai_always_ends() -> void:
	var stuck := 0
	var unfinished := 0
	var monster_turns := 0
	var shots := 0
	var walls := 0
	var blooms := 0
	var sealed := 0
	var book = Monsters.load_default()["monsters"]
	var bolt_ids := [str(book.raw("blight_horror")["attack"]["id"]), str(book.raw(G_HORROR)["attack"]["id"])]
	var wall_ids := [str(book.raw("rotting_elder")["signature"]["id"]), str(book.raw(G_BOSS)["signature"]["id"])]
	var bloom_id := str(book.raw(G_BOSS)["signature2"]["id"])
	for cls in CLASSES:
		for star in [1, 5]:
			var run = Run.create(BLIGHT, LEVEL, cls, "", star)["run"]
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
						if spell in bolt_ids and bool(d["ok"]):
							shots += 1
						if spell in wall_ids and bool(d["ok"]):
							walls += 1
							if not _all_connected():
								sealed += 1
						if spell == bloom_id and bool(d["ok"]):
							blooms += 1
					var after: Dictionary = sim.snapshot()
					if not bool(after["match_over"]) and int(after["active_seat"]) == seat:
						unfinished += 1
				if guard >= limit:
					unfinished += 1
				if str(sim.snapshot()["dungeon"]["result"]) != "win":
					break
	eq(monster_turns > 100, true, "monster turns were played (%d)" % monster_turns)
	eq(shots > 20, true, "Blight Horrors find lines and throw (%d)" % shots)
	eq(walls > 2, true, "the Elder raises root walls in real fights (%d)" % walls)
	eq(blooms > 2, true, "the ★5 Colossus swells crystal blooms in real fights (%d)" % blooms)
	eq(sealed, 0, "no root wall ever sealed a unit off")
	eq(stuck, 0, "no monster turn needed a forced end")
	eq(unfinished, 0, "every monster turn ends and every fight finishes")


func _test_horror_los_and_kiting() -> void:
	var book = Monsters.load_default()["monsters"]
	var horror: Dictionary = book.stats_at("blight_horror", LEVEL, 1)
	var spell := str(horror["attack"]["id"])
	var cells: Array = []
	for y in 12:
		for x in 12:
			var wall := x == 5 and y >= 2 and y <= 9
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["root_knot"] if wall else [], "blocks": wall, "special": ""})
	var a := horror.duplicate(true)
	a["pos"] = Vector2i(2, 5)
	a["facing"] = "E"
	var room := {"dungeon_id": "t", "room_id": "lane", "room_name": "Lane", "kind": "pack", "cells": cells, "pad_heal": 0, "hero": {"class_id": "kestrel", "pos": Vector2i(8, 5), "facing": "W"}, "monsters": [a], "summons": {}}
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room})
	eq(bool(sim.has_los(Vector2i(2, 5), Vector2i(8, 5))), false, "a row of root knots blocks the bolt's line")
	sim.submit({"type": "end_turn", "seat": 0})
	var can_throw := false
	for i in sim.legal_intents(1):
		if str(i.get("spell", "")) == spell:
			can_throw = true
	eq(can_throw, false, "no bolt without a line of sight")
	AI.play_monster_turn(sim, 1)
	eq(int(sim.snapshot()["active_seat"]), 0, "the horror ends its turn (no deadlock)")
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
	eq(kinds.size() >= 2 and str(kinds[0]).begins_with("move") and kinds.has("cast:" + spell), true, "adjacent, the horror steps back, then throws (%s)" % [kinds])
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
	eq(projectile, "spore_bolt/spore_impact", "the bolt event names its projectile and impact for the view")


# --- the Rotting Elder: Root Wall ---------------------------------------------------

## An open 12x12 room with the boss at `boss_at`, the hero at `hero_at`,
## hounds at `hounds` and pads at `pads`.
func _wall_room(boss_at: Vector2i, hero_at: Vector2i, hounds: Array = [], star: int = 1, pads: Array = [], blocks: Array = []) -> Dictionary:
	var book = Monsters.load_default()["monsters"]
	var boss: Dictionary = book.stats_at("rotting_elder" if star < 5 else G_BOSS, LEVEL, star)
	boss["pos"] = boss_at
	boss["facing"] = "S"
	var cells: Array = []
	for y in 12:
		for x in 12:
			var c := Vector2i(x, y)
			var pad := pads.has(c)
			var wall := blocks.has(c)
			cells.append({"pos": c, "terrain": "ground", "elevation": 0, "paint_only": ["blight_pad"] if pad else (["root_knot"] if wall else []), "blocks": wall, "special": "pad" if pad else ""})
	var mons: Array = [boss]
	for at in hounds:
		var h: Dictionary = book.stats_at("blight_hound" if star < 5 else G_HOUND, LEVEL, star)
		h["pos"] = at
		h["facing"] = "S"
		mons.append(h)
	var rolls: Array = []
	for i in 120:
		rolls.append(99)
	return {"board_size": 12, "seed": 5, "rolls": rolls, "dungeon": {"dungeon_id": BLIGHT, "room_id": "wall", "room_name": "Wall", "kind": "boss", "cells": cells, "pad_heal": 5, "pad_thaw": true, "hero": {"class_id": "bastion", "pos": hero_at, "facing": "N"}, "monsters": mons, "summons": {}}}


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


func _test_root_wall() -> void:
	sim.reset_match(_wall_room(Vector2i(6, 2), Vector2i(6, 8)))
	var boss: Dictionary = sim._unit_by_seat(1)
	var sig: Dictionary = boss["signature"]
	eq(bool(sim.wall_ready(boss)), false, "no wall out of his turn count (turn 0)")
	var early: Dictionary = sim.submit({"type": "cast", "spell": str(sig["id"]), "to": Vector2i(6, 8), "seat": 1})
	eq(bool(early.get("ok", true)), false, "a wall out of turn is refused")
	sim.submit({"type": "end_turn", "seat": 0})
	eq(int(boss["own_turns"]), 1, "his 1st turn")
	eq(bool(sim.wall_ready(boss)), true, "the wall is ready on his 1st turn")
	var legal_to := Vector2i(-1, -1)
	for i in sim.legal_intents(1):
		if str(i.get("spell", "")) == str(sig["id"]):
			legal_to = i["to"]
	eq(legal_to, Vector2i(6, 8), "the wall is a legal monster intent aimed at the hero")
	var ap_before := int(boss["ap"])
	eq(bool(sim.submit({"type": "cast", "spell": str(sig["id"]), "to": legal_to, "seat": 1}).get("ok", false)), true, "he raises the wall")
	eq(int(boss["ap"]), ap_before - int(sig["ap"]), "the wall costs %d AP" % int(sig["ap"]))
	var walls: Array = sim.wall_cells()
	eq(walls.size(), int(sig["cells"]), "%d root cells rise" % int(sig["cells"]))
	eq(walls, [Vector2i(5, 9), Vector2i(7, 9), Vector2i(6, 9)], "they rise on the hero's back row, the side away from him (%s)" % [walls])
	for c in walls:
		eq(chebyshev(c, Vector2i(6, 8)), 1, "root cell %s is next to the hero" % c)
		eq(bool(sim.tile_at(c).get("walkable", true)), false, "root cell %s blocks walking" % c)
	var wall_ev: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "wall":
			wall_ev = e
	eq([wall_ev.get("cells", []), str(wall_ev.get("prop", "")), str(wall_ev.get("beam", "")), int(wall_ev.get("turns", 0))], [walls, "root_wall", "root_crack", 2], "the wall event carries the cells, the prop, the crack and the turns")
	eq(str(wall_ev.get("coach", "")).contains("Roots burst up"), true, "the wall's line is the blight's own (%s)" % wall_ev.get("coach", ""))
	eq(bool(sim.wall_ready(boss)), false, "one wall a turn")
	var snap_walls: Array = sim.snapshot()["dungeon"]["walls"]
	eq(snap_walls.size(), walls.size(), "the snapshot lists the walls for the view")
	# He still claws after the wall (2 + 4 AP).
	sim._unit_by_seat(0)["pos"] = Vector2i(6, 3)
	var clawed := false
	for d in AI.play_monster_turn(sim, 1):
		clawed = clawed or (str(d["intent"].get("spell", "")) == str(boss["attack"]["id"]) and bool(d["ok"]))
	eq(clawed, true, "after the wall he claws a hero in reach")
	sim._unit_by_seat(0)["pos"] = Vector2i(6, 8)
	# The hero cannot walk through the roots.
	var through := false
	for i in sim.legal_intents(0):
		if str(i.get("type", "")) == "move" and walls.has(i.get("to")):
			through = true
	eq(through, false, "no legal hero move lands on a root cell")
	var moved: Dictionary = sim.submit({"type": "move", "to": Vector2i(6, 10), "seat": 0})
	eq(bool(moved.get("ok", false)) and sim._unit_by_seat(0)["pos"] == Vector2i(6, 10), false, "the hero cannot walk straight back through the wall")
	# Roots cut lines of sight both ways.
	eq(bool(sim.has_los(Vector2i(6, 11), Vector2i(6, 7))), false, "a root wall cuts a line of fire")
	# They stand until the hero has ended 2 turns, then wither and open.
	sim.submit({"type": "end_turn", "seat": 0})
	eq(sim.wall_cells().size(), walls.size(), "after 1 hero turn the wall still stands")
	_round_to_hero()
	sim.submit({"type": "end_turn", "seat": 0})
	eq(sim.wall_cells().is_empty(), true, "after 2 hero turns the wall withers")
	var wither := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "wall_wither":
			wither = str(e.get("coach", ""))
			eq(e.get("cells", []), walls, "the wither event names the cells")
	eq(wither.contains("withers back"), true, "the wither line is the blight's own (%s)" % wither)
	for c in walls:
		eq(bool(sim.tile_at(c).get("walkable", false)), true, "root cell %s is open again" % c)
	eq(bool(sim.has_los(Vector2i(6, 11), Vector2i(6, 7))), true, "the line is open again")
	# Never on a pad, a body or a corpse; pads stay usable.
	var pads: Array = [Vector2i(6, 9)]
	sim.reset_match(_wall_room(Vector2i(6, 2), Vector2i(6, 8), [Vector2i(5, 9), Vector2i(9, 9)], 1, pads))
	_kill(3)
	sim._unit_by_seat(3)["pos"] = Vector2i(7, 9)
	sim.submit({"type": "end_turn", "seat": 0})
	boss = sim._unit_by_seat(1)
	sim.submit({"type": "cast", "spell": str(sig["id"]), "to": Vector2i(6, 8), "seat": 1})
	var cells2: Array = sim.wall_cells()
	eq(cells2.has(Vector2i(6, 9)), false, "no root on a pad")
	eq(cells2.has(Vector2i(5, 9)), false, "no root under a body")
	eq(cells2.has(Vector2i(7, 9)), false, "no root on a corpse")
	eq(cells2.size(), int(sig["cells"]), "the wall still finds %d cells round the hero (%s)" % [int(sig["cells"]), cells2])
	# A hero boxed by props has fewer free cells; with none the wall waits.
	var box: Array = []
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		box.append(Vector2i(6, 8) + d)
	box.erase(Vector2i(6, 7))
	sim.reset_match(_wall_room(Vector2i(6, 2), Vector2i(6, 8), [], 1, [], box))
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.wall_ready(sim._unit_by_seat(1))), false, "no wall when the hero's only free neighbour is his way out")
	# ★5: the Colossus's wall is the crystal wall, 4 cells.
	sim.reset_match(_wall_room(Vector2i(6, 2), Vector2i(6, 8), [], 5))
	sim.submit({"type": "end_turn", "seat": 0})
	var col: Dictionary = sim._unit_by_seat(1)
	sim.submit({"type": "cast", "spell": str(col["signature"]["id"]), "to": Vector2i(6, 8), "seat": 1})
	eq(sim.wall_cells().size(), 4, "the ★5 wall raises 4 cells")
	eq(str((sim.snapshot()["dungeon"]["walls"] as Array)[0]["prop"]), "crystal_wall", "as the crystal wall")


func _test_root_wall_rhythm_and_ai() -> void:
	sim.reset_match(_wall_room(Vector2i(6, 1), Vector2i(6, 9)))
	var sig: Dictionary = sim._unit_by_seat(1)["signature"]
	var rose_on: Array = []
	for round_n in 8:
		if bool(sim.snapshot()["match_over"]):
			break
		sim._unit_by_seat(0)["hp"] = 80
		sim.submit({"type": "end_turn", "seat": 0})
		var b: Dictionary = sim._unit_by_seat(1)
		for d in AI.play_monster_turn(sim, 1):
			if str(d["intent"].get("spell", "")) == str(sig["id"]) and bool(d["ok"]):
				rose_on.append(int(b["own_turns"]))
		b["pos"] = Vector2i(6, 1)
		_round_to_hero()
	eq(rose_on, [1, 4, 7], "with the AI the wall rises on his 1st turn and every 3rd after (%s)" % [rose_on])
	# The hero bot plays on with walls up: every turn still ends.
	var run = Run.create(BLIGHT, LEVEL, "ironjaw", "", 1)["run"]
	sim.reset_match(run.combat_config(1, 9))
	var seen_walls := 0
	var guard := 0
	while not bool(sim.snapshot()["match_over"]) and guard < 400:
		guard += 1
		var seat := int(sim.snapshot()["active_seat"])
		if seat == 0:
			seen_walls = maxi(seen_walls, (sim.snapshot()["dungeon"]["walls"] as Array).size())
			AI.play_hero_turn(sim)
		else:
			AI.play_monster_turn(sim, seat)
	eq(bool(sim.snapshot()["match_over"]), true, "a room B fight with root walls finishes")
	eq(seen_walls > 0, true, "the hero bot played turns with a root wall up (%d cells)" % seen_walls)


func _test_root_wall_never_seals() -> void:
	# A corridor: the hero stands in a 1-wide lane; walls on both lane cells
	# would cut the hero off from the Elder. Only cells that keep a path rise.
	var blocks: Array = []
	for y in 12:
		for x in 12:
			if x != 6 and y >= 5 and y <= 10 and not (y == 10):
				blocks.append(Vector2i(x, y))
	sim.reset_match(_wall_room(Vector2i(6, 1), Vector2i(6, 7), [], 1, [], blocks))
	sim.submit({"type": "end_turn", "seat": 0})
	var boss: Dictionary = sim._unit_by_seat(1)
	if bool(sim.wall_ready(boss)):
		sim.submit({"type": "cast", "spell": str(boss["signature"]["id"]), "to": Vector2i(6, 7), "seat": 1})
	eq(sim.wall_cells().has(Vector2i(6, 6)), false, "no root seals the lane between the hero and the Elder")
	eq(_all_connected(), true, "every live unit can still reach every other")
	# A unit in a pocket keeps its way out too.
	sim.reset_match(_wall_room(Vector2i(6, 1), Vector2i(1, 1), [Vector2i(0, 0)], 1, [], [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(0, 3)]))
	eq(_all_connected(), true, "the pocket opens at 1,3 before the wall")
	sim.submit({"type": "end_turn", "seat": 0})
	boss = sim._unit_by_seat(1)
	if bool(sim.wall_ready(boss)):
		sim.submit({"type": "cast", "spell": str(boss["signature"]["id"]), "to": Vector2i(1, 1), "seat": 1})
	eq(_all_connected(), true, "a hound in the hero's pocket is never sealed in")


# --- ★5 crystal bloom, the crystal wither, cleansing -------------------------------------

func _test_star5_crystal_bloom() -> void:
	var run = Run.create(BLIGHT, LEVEL, "kestrel", "", 5)["run"]
	var cfg: Dictionary = run.combat_config(1, 31)
	cfg["rolls"] = []
	for i in 300:
		cfg["rolls"].append(99)
	sim.reset_match(cfg)
	var boss: Dictionary = sim._unit_by_seat(1)
	eq(str(boss["name"]), G_BOSS_NAME, "★5 room B boss is %s" % G_BOSS_NAME)
	var sig2: Dictionary = boss["signature2"]
	var hero: Dictionary = sim._unit_by_seat(0)
	hero["pos"] = Vector2i(2, 10)
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pools_ready(boss)), true, "the bloom is ready on his 1st turn")
	var hero_cell: Vector2i = hero["pos"]
	eq(bool(sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero_cell, "seat": 1}).get("ok", false)), true, "he swells the bloom")
	var cells: Array = sim.pool_cells()
	eq(cells.size() >= int(sig2["cells_min"]) and cells.size() <= int(sig2["cells_max"]), true, "2-3 pods (%d)" % cells.size())
	eq(cells.has(hero_cell), true, "a pod swells under the hero")
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(str(p.get("hazard", "")), "crystal_bloom", "the snapshot names the hazard crystal_bloom")
		eq([int(p.get("fuse", 0)), int(p.get("turns", 0)), int(p.get("splash", 0))], [1, 1, 1], "a pod's fuse is 1 hero turn, splash 1")
		eq(bool(sim.tile_at(p["cell"]).get("walkable", false)), true, "a pod does not block")
	var lay := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pools":
			lay = str(e.get("coach", ""))
			eq(str(e.get("hazard", "")), "crystal_bloom", "the hazard event names crystal_bloom for the view")
	eq(lay.contains("crystal pods swell"), true, "the lay line is the bloom's own (%s)" % lay)
	while int(sim.snapshot()["active_seat"]) != 0:
		var u: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
		u["acted_signature"] = true
		sim.submit({"type": "end_turn", "seat": int(u["seat"])})
	# The hero stays on a pod: the pods burst at the end of the hero's turn.
	hero["hp"] = 80
	hero["pos"] = hero_cell
	var pool_hits := 0
	sim.submit({"type": "end_turn", "seat": 0})
	var burst: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "bloom":
			burst = e
		if str(e.get("type", "")) == "pool_hit":
			pool_hits += 1
	eq(pool_hits, 0, "a pod does not hurt like a pool: only its burst does")
	eq(burst.is_empty(), false, "the pods burst when the hero's turn ends")
	eq(bool(burst.get("hit", false)), true, "a hero on a pod is caught")
	eq(int(burst.get("damage", 0)), int(sig2["hp"]), "bloom damage is %d (one hit, not one per pod)" % int(sig2["hp"]))
	eq(80 - int(hero["hp"]), int(sig2["hp"]), "the hero lost the bloom damage once")
	eq((burst.get("cells", []) as Array).size(), cells.size(), "every pod bursts")
	eq(str(burst.get("coach", "")).contains("crystallised"), true, "the burst line is the bloom's own (%s)" % burst.get("coach", ""))
	eq(sim.pool_cells().is_empty(), true, "burst pods are gone")
	while int(sim.snapshot()["active_seat"]) != 0:
		var u2: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
		u2["acted_signature"] = true
		u2["acted_signature2"] = true
		sim.submit({"type": "end_turn", "seat": int(u2["seat"])})
	eq(int(hero["ap"]), int(hero["max_ap"]) - int(sig2["ap_loss"]), "a crystallised hero has %d AP less on the next turn" % int(sig2["ap_loss"]))
	eq(int(hero["mp"]), int(hero["max_mp"]), "the bloom takes AP, not MP")
	var wither_line := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "wither":
			wither_line = str(e.get("coach", ""))
	eq(wither_line.contains("crystallised"), true, "the AP line names the wither (%s)" % wither_line)
	# Next to a pod is caught too; two cells clear is safe.
	for case in [[Vector2i(1, 0), true], [Vector2i(2, 0), false], [Vector2i(0, -2), false]]:
		sim.reset_match(cfg)
		boss = sim._unit_by_seat(1)
		hero = sim._unit_by_seat(0)
		hero["pos"] = Vector2i(2, 10)
		sim.submit({"type": "end_turn", "seat": 0})
		sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero["pos"], "seat": 1})
		var pods: Array = sim.pool_cells()
		while int(sim.snapshot()["active_seat"]) != 0:
			var u3: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
			u3["acted_signature"] = true
			sim.submit({"type": "end_turn", "seat": int(u3["seat"])})
		var near := 99
		var spot := Vector2i(2, 10) + Vector2i(case[0])
		for p in pods:
			near = mini(near, chebyshev(p, spot))
		hero["pos"] = spot
		hero["hp"] = 80
		sim.submit({"type": "end_turn", "seat": 0})
		var caught := false
		for e in sim.snapshot()["last_events"]:
			if str(e.get("type", "")) == "bloom":
				caught = bool(e.get("hit", false))
		eq(caught, near <= 1, "a hero %d cell(s) from the nearest pod is %s" % [near, "caught" if near <= 1 else "clear"])
	# The hero bot steps clear of a bursting bloom when it can.
	var caught_bot := 0
	var tries := 0
	for seed in [35, 36, 37, 38]:
		sim.reset_match(run.combat_config(1, seed))
		sim.submit({"type": "end_turn", "seat": 0})
		var b2: Dictionary = sim._unit_by_seat(1)
		sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
		b2["acted_signature"] = true
		while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]):
			sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
		tries += 1
		AI.play_hero_turn(sim)
		for e in sim.snapshot()["last_events"]:
			if str(e.get("type", "")) == "bloom" and bool(e.get("hit", false)):
				caught_bot += 1
	eq(caught_bot, 0, "the hero bot steps clear of the bloom before ending its turn (%d of %d caught)" % [caught_bot, tries])


func _test_wither_and_cleanse() -> void:
	var book = Monsters.load_default()["monsters"]
	var gh: Dictionary = book.stats_at(G_HORROR, LEVEL, 5)
	var cells: Array = []
	for y in 12:
		for x in 12:
			var pad := Vector2i(x, y) == Vector2i(8, 8)
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["blight_pad"] if pad else [], "blocks": false, "special": "pad" if pad else ""})
	var a := gh.duplicate(true)
	a["pos"] = Vector2i(8, 4)
	a["facing"] = "S"
	a["mp"] = 0
	var run = Run.create(BLIGHT, LEVEL, "kestrel", "", 5)["run"]
	var thaw_text := str(run.combat_config(0, 1)["dungeon"]["pad_thaw_text"])
	var room := {"dungeon_id": BLIGHT, "room_id": "wither", "room_name": "Wither", "kind": "pack", "cells": cells, "pad_heal": 5, "pad_thaw": true, "pad_thaw_text": thaw_text, "hero": {"class_id": "bastion", "pos": Vector2i(5, 7), "facing": "N"}, "monsters": [a], "summons": {}}
	var rolls: Array = []
	for i in 40:
		rolls.append(1)
	sim.reset_match({"board_size": 12, "seed": 4, "dungeon": room, "rolls": rolls})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(gh["attack"]["id"]), "to": Vector2i(5, 7), "target_seat": 0, "seat": 1})
	var line := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("status", "")) == "wither":
			line = str(e.get("coach", ""))
	eq(line.contains("crystallised"), true, "a crystal shard crystallises the hero (%s)" % line)
	sim.submit({"type": "end_turn", "seat": 1})
	var hero: Dictionary = sim._unit_by_seat(0)
	eq(int(hero["ap"]), int(hero["max_ap"]) - 1, "a crystallised hero has 1 AP less on the next turn")
	eq(int(hero["mp"]), int(hero["max_mp"]), "and keeps its MP")
	# Two hits in a row do not stack.
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(gh["attack"]["id"]), "to": Vector2i(5, 7), "target_seat": 0, "seat": 1})
	sim._unit_by_seat(1)["ap"] = 9
	sim.submit({"type": "cast", "spell": str(gh["attack"]["id"]), "to": Vector2i(5, 7), "target_seat": 0, "seat": 1})
	sim.submit({"type": "end_turn", "seat": 1})
	eq(int(hero["ap"]), int(hero["max_ap"]) - 1, "two shards in a turn still take 1 AP (no stacking)")
	hero["pos"] = Vector2i(8, 8)
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(gh["attack"]["id"]), "to": Vector2i(8, 8), "target_seat": 0, "seat": 1})
	sim.submit({"type": "end_turn", "seat": 1})
	eq(int(hero["ap"]), int(hero["max_ap"]), "a turn that starts on a blight pad keeps its full AP")
	var cleanse := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "thaw":
			cleanse = str(e.get("coach", ""))
	eq(cleanse.contains("blight pad"), true, "the pad's line is the blight's own (%s)" % cleanse)
	# A bloom's wither on a pad is cleansed too.
	var boss: Dictionary = book.stats_at(G_BOSS, LEVEL, 5)
	boss["pos"] = Vector2i(2, 1)
	boss["facing"] = "S"
	room["monsters"] = [boss]
	room["hero"] = {"class_id": "bastion", "pos": Vector2i(8, 8), "facing": "N"}
	sim.reset_match({"board_size": 12, "seed": 4, "dungeon": room, "rolls": rolls})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(boss["signature2"]["id"]), "to": Vector2i(8, 8), "seat": 1})
	sim._unit_by_seat(1)["acted_signature"] = true
	sim.submit({"type": "end_turn", "seat": 1})
	sim.submit({"type": "end_turn", "seat": 0})
	var caught := false
	for e in sim.snapshot()["last_events"]:
		caught = caught or (str(e.get("type", "")) == "bloom" and bool(e.get("hit", false)))
	eq(caught, true, "the hero ends a turn caught by the bloom on the pad")
	sim._unit_by_seat(1)["acted_signature"] = true
	sim._unit_by_seat(1)["acted_signature2"] = true
	sim.submit({"type": "end_turn", "seat": 1})
	hero = sim._unit_by_seat(0)
	eq(int(hero["ap"]), int(hero["max_ap"]), "the blight pad cleanses the bloom's wither")


# --- rewards -----------------------------------------------------------------------

func _test_rewards_per_star() -> void:
	var base_xp := 0
	var base_coins := 0
	var parts := {}
	for star in range(1, 6):
		var run = Run.create(BLIGHT, LEVEL, "kestrel", "", star)["run"]
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
				var rarity := str(item.get("rarity", "regular"))
				if star < 4:
					eq(rarity in ["regular", "rare", "special", ""], true, "★%d drops no epic or relic (%s)" % [star, item.get("item_id", "")])
				elif star == 4:
					eq(rarity != "relic", true, "★4 drops no relic (%s)" % item.get("item_id", ""))
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
		eq(int(hero.best_dungeon_star(BLIGHT)), star, "★%d clear is the blight's best star" % star)
		eq(bool(s3.get("new_best_star", false)), true, "★%d is a new best" % star)
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/level_curve.json"))
	var need := float((curve["xp_to_next"] as Array)[LEVEL - 1])
	var expect_xp := int(round(0.27 * need * float(curve["pace_start"]) * pow(float(curve["pace_ratio"]), LEVEL - 1)))
	eq(base_xp, expect_xp, "level 42 ★1 XP is 27%% of xp_to_next(42) x pace (%d)" % expect_xp)
	eq(base_xp > Run.create(ABBEY, LEVEL, "kestrel")["run"].win_xp(LEVEL), true, "for the same hero the blight pays more XP than the abbey")
	eq(base_coins > 0, true, "a blight win pays coins (%d)" % base_coins)
	var tier40 := false
	for id in parts.keys():
		eq(str(id).begins_with("rotting_elder_"), false, "%s: no Rotting Elder part below a level-50 run" % id)
		eq(str(id) in ["crown_of_crosshaven", "abbess_rosary"], false, "%s does not drop in the blight" % id)
		for suffix in ["galecrest", "mountainmaw", "deepspring", "voidshroud", "rampart_lord"]:
			tier40 = tier40 or str(id).contains("_%s_" % suffix)
	eq(tier40, true, "the blight drops tier-40 class set parts")


# --- loot: wearable sets, epics and relics (Mauro, 11 Oct 2026: "Si a todo") ------

## Mirrors pay_out: the rewards roll at the run level, then the star gate.
var _loot_book = null
var _loot_runs := {}


func _loot(dungeon: String, level: int, star: int, seed: int) -> Dictionary:
	if _loot_book == null:
		_loot_book = Rewards.load_default()["rewards"]
	var book = _loot_book
	var key := "%s/%d/%d" % [dungeon, level, star]
	if not _loot_runs.has(key):
		_loot_runs[key] = Run.create(dungeon, level, "kestrel", "", star)["run"]
	var run = _loot_runs[key]
	var rng := _rng(seed)
	var drop: Dictionary = book.roll("dungeon", {"dungeon_id": dungeon, "level": run.level, "stars": star, "class_id": "kestrel", "zone_id": ZONE}, rng)
	drop["items"] = run.star_loot(book, drop["items"], rng)
	return drop


func _test_loot_tiers() -> void:
	var book = Rewards.load_default()["rewards"]
	var row: Dictionary = {}
	for r in book.dungeons():
		if str(r["id"]) == BLIGHT:
			row = r
	eq([int(row["class_tier"]), int(row["coin_level"])], [40, 40], "the blight pays tier-40 class sets at coin level 40")
	eq(str(row["set_id"]), "rotting_elder", "the Rotting Elder is still the blight's own set")
	eq(int(book.set_by_id("rotting_elder")["tier"]), 50, "the Rotting Elder set stays tier 50 (spec 4.9)")
	eq(float(row["guaranteed_split"]["class_set"]), 1.0, "the guaranteed part is always a class set")
	eq(str(row["star_drops"]["status"]), "proposed", "the star drops are Proposed")
	var coins40 := int(round(3.0 + 1.5 * 40.0)) * 8
	var books := Rewards.load_default()
	eq(bool(books["ok"]), true, "rewards.json loads with the star drops: %s" % [books.get("errors", [])])
	for level in [40, 42, 45, 49]:
		for star in range(1, 6):
			var gear := 0
			for t in 40:
				var drop := _loot(BLIGHT, level, star, 5000 + 97 * level + 13 * star + t)
				eq(int(drop["coins"]), coins40 * star, "level %d ★%d coins are coin level 40 x star" % [level, star])
				for item in drop["items"]:
					var id := str(item["item_id"])
					var def: Dictionary = book.item(id)
					if str(def.get("set_id", "")) == "":
						continue
					gear += 1
					var set_def: Dictionary = book.set_by_id(str(def["set_id"]))
					eq([str(set_def["kind"]), int(set_def["tier"])], ["class", 40], "level %d ★%d set part %s is a tier-40 class part" % [level, star, id])
					eq(int(def["min_level"]) <= level, true, "level %d ★%d set part %s is wearable" % [level, star, id])
			eq(gear >= 40, true, "level %d ★%d: every win gives a set part (%d)" % [level, star, gear])
	# A level-50 run: still no tier-50 set part below ★5.
	for star in range(1, 5):
		for t in 60:
			for item in _loot(BLIGHT, 50, star, 7000 + 100 * star + t)["items"]:
				eq(str(item["item_id"]).begins_with("rotting_elder_"), false, "level 50 ★%d drops no Rotting Elder part" % star)
				eq(str(book.item(str(item["item_id"])).get("rarity", "")) != "relic", true, "level 50 ★%d: no relic" % star)
	# ★5 keeps its Mystery Box and its Rare part, and the Rare part is wearable.
	for t in 30:
		var items: Array = _loot(BLIGHT, 42, 5, 8000 + t)["items"]
		var box := false
		var rare_ok := false
		for item in items:
			box = box or str(item["item_id"]) == "mystery_box"
			if str(item["rarity"]) == "rare":
				rare_ok = rare_ok or int(book.item(str(item["item_id"]))["min_level"]) == 40
		eq(box, true, "★5 still gives a Mystery Box")
		eq(rare_ok, true, "★5's Rare part is a tier-40 part")
	# above_run_level "drop": a level-50 relic dropped on a level-42 run waits in the bag.
	eq(str(book.can_wear("heart_of_the_elder", "relic", 42, "Kestrel")["reason"]), "level", "a level-42 hero cannot wear Heart of the Elder yet")
	eq(bool(book.can_wear("heart_of_the_elder", "relic", 50, "Kestrel")["ok"]), true, "a level-50 hero can")
	eq(str(book.item("crown_of_crosshaven")["drop"]), "Open", "Crown of Crosshaven has no source yet")
	for id in ["gale_signet", "ember_crown", "stormheart_gauntlet", "prism_striders", "heart_of_the_elder", "blightroot_ring"]:
		eq(str(book.item(id)["drop"]), "rolled", "%s now drops" % id)


func _test_star_drop_rates() -> void:
	var book = Rewards.load_default()["rewards"]
	var low := ["gale_signet", "ember_crown", "stormheart_gauntlet"]
	var relics := ["heart_of_the_elder", "blightroot_ring"]
	var n := 4000
	for level in [42, 50]:
		for star in range(1, 6):
			var count := {}
			var elder := 0
			for t in n:
				var epics := 0
				var rel := 0
				for item in _loot(BLIGHT, level, star, 100000 + 10000 * star + t + level * 1000000)["items"]:
					var id := str(item["item_id"])
					var rarity := str(book.item(id).get("rarity", ""))
					if rarity == "epic":
						epics += 1
						eq(str(item["rarity"]), "epic", "an epic drops as epic")
					if rarity == "relic":
						rel += 1
						eq(str(item["rarity"]), "relic", "a relic drops as relic")
					if id.begins_with("rotting_elder_"):
						elder += 1
					count[id] = int(count.get(id, 0)) + 1
				if epics > 1 or rel > 1:
					eq([epics, rel], [1, 1], "level %d ★%d: at most one epic and one relic a run" % [level, star])
			var low_n := 0
			for id in low:
				low_n += int(count.get(id, 0))
			var rate := float(low_n) / n
			var expect_low: float = {4: 0.10, 5: 0.20}.get(star, 0.0)
			eq(absf(rate - expect_low) <= 0.02, true, "level %d ★%d: Gale / Ember / Stormheart %.3f (~%.2f)" % [level, star, rate, expect_low])
			var expect_5 := 0.05 if star == 5 else 0.0
			for id in ["prism_striders"] + relics:
				var r := float(count.get(id, 0)) / n
				eq(absf(r - expect_5) <= 0.015, true, "level %d ★%d: %s %.3f (~%.2f)" % [level, star, id, r, expect_5])
			eq(count.has("crown_of_crosshaven") or count.has("abbess_rosary"), false, "level %d ★%d: no Crown, no Rosary" % [level, star])
			var expect_elder := 0.10 if (star == 5 and level == 50) else 0.0
			var er := float(elder) / n
			print("  blight level %d ★%d over %d wins: Gale/Ember/Stormheart %.3f, Prism %.3f, Heart %.3f, Blightroot %.3f, Rotting Elder part %.3f" % [level, star, n, rate, float(count.get("prism_striders", 0)) / n, float(count.get("heart_of_the_elder", 0)) / n, float(count.get("blightroot_ring", 0)) / n, er])
			eq(absf(er - expect_elder) <= 0.02, true, "level %d ★%d: Rotting Elder part %.3f (~%.2f)" % [level, star, er, expect_elder])
			if star == 5 and level == 42:
				for id in low:
					eq(int(count.get(id, 0)) > 0, true, "★5 at level 42 drops %s too (drop above the run level)" % id)
	# The draws are seeded: the same seed gives the same drop.
	eq(JSON.stringify(_loot(BLIGHT, 42, 5, 31)), JSON.stringify(_loot(BLIGHT, 42, 5, 31)), "a seeded ★5 drop is fixed")


func _test_mission_credit() -> void:
	var missions = Missions.load_default()["missions"]
	var hero = _fresh_hero()
	hero.level = LEVEL
	hero.mission_blob = {"story": {"westwatch_scout": {"status": "done"}}}
	eq(missions.label_for("westwatch_dungeon", hero) != "coming soon", true, "the Westwatch dungeon mission is live")
	eq(bool(missions.accept("westwatch_dungeon", hero).get("ok", false)), true, "the mission can be taken")
	var run = Run.create(BLIGHT, LEVEL, "kestrel", "", 1)["run"]
	run.result = "win"
	var sm: Dictionary = run.pay_out(hero, missions, _rng(3), false)
	eq((sm["missions"] as Array).has("westwatch_dungeon"), true, "a blight win credits the clear_dungeon mission")
	var offer: Array = missions.mission("westwatch_dungeon")["lines"]["offer"]
	eq(str(offer[0]).contains("not open yet"), false, "the offer no longer says the way is shut")


# --- the other four dungeons are unchanged -------------------------------------------

func _test_others_unchanged() -> void:
	# Rewards: seeded roll + star gate fingerprints taken at bdde0da4, before the
	# loot change (60 seeds per star, level 1 / 12 / 22).
	var pins := {
		GRANARY: ["a805e2ac16dd784996eb45867ff87b96", "b0506a5408594687b477a61de2b4cb50", "27703bdc76b03275dde3cab67b1ea2bd", "e331f7e652393579737119ac1dd3bbbe", "ec613b8978ea1805f738a22024f7c0c6"],
		FROST: ["c911006047cb30b2cb8caef2e073ebc6", "27b04b1700202db1e9eae607a1d89896", "e1cc11dc17e0f0f845394340f2ced02c", "16e6f4c3ae006408eb1cc595dcfc33ec", "f94a96fc5f4709e3beaccde347344707"],
		SALT: ["87edc23f2a22f5aa75e1716a5aad2958", "751a86cf8b4d7d870ccf5ecf7ea89447", "5dddd1a84898b1d12bb86d8ba2f975bb", "4f575fa1a1f68a9796099c09626db0c0", "7ce5f29ab5244e4a9d5c144632e0225c"],
	}
	var levels := {GRANARY: 1, FROST: 12, SALT: 22}
	for dungeon in pins.keys():
		for star in range(1, 6):
			eq(_loot_fingerprint(str(dungeon), int(levels[dungeon]), star), str(pins[dungeon][star - 1]), "%s ★%d rewards are unchanged" % [dungeon, star])
	var book = Monsters.load_default()["monsters"]
	eq(book.ids_for(GRANARY), ["granary_rat", "sling_rat", "scarecrow_drudge", "the_ratking", "radioactive_rat", "radioactive_sling_rat", "radioactive_ratking"], "the cellar keeps its seven monsters")
	eq(book.ids_for(FROST), ["ice_construct", "book_wraith", "the_pale_archivist", "frozen_ice_construct", "frozen_book_wraith", "the_frozen_archivist"], "the archive keeps its six monsters")
	eq(book.ids_for(SALT), ["reef_crab", "drowned_sailor", "drowned_harpooner", "old_saltmaw", "abyssal_reef_crab", "abyssal_drowned_sailor", "abyssal_drowned_harpooner", "abyssal_saltmaw"], "the grotto keeps its eight monsters")
	eq(book.ids_for(ABBEY), ["bog_dead", "mire_leech", "mire_abbess", "bellbound_bog_dead", "bellbound_mire_leech", "bell_wraith"], "the abbey keeps its six monsters")
	var rows := {1: [1.0, 1.0], 2: [1.1, 1.05], 3: [1.15, 1.1], 4: [1.2, 1.1], 5: [1.0, 1.0]}
	var frost_rows := {1: [1.0, 1.0], 2: [1.05, 1.0], 3: [1.05, 1.0], 4: [1.1, 1.0], 5: [0.875, 0.85]}
	var salt_rows := {1: [1.0, 1.0], 2: [1.05, 1.0], 3: [1.1, 1.05], 4: [1.25, 1.05], 5: [1.05, 1.05]}
	var abbey_rows := {1: [1.0, 1.0], 2: [1.05, 1.0], 3: [1.1, 1.05], 4: [1.12, 1.05], 5: [1.0, 0.9]}
	for star in range(1, 6):
		eq(book.star_scale(star, GRANARY), rows[star], "the cellar's ★%d row is unchanged" % star)
		eq(book.star_scale(star, FROST), frost_rows[star], "the archive's ★%d row is unchanged" % star)
		eq(book.star_scale(star, SALT), salt_rows[star], "the grotto's ★%d row is unchanged" % star)
		eq(book.star_scale(star, ABBEY), abbey_rows[star], "the abbey's ★%d row is unchanged" % star)
	eq([int(book.stats_at("mire_abbess", 32)["hp"]), int(book.stats_at("mire_abbess", 32)["attack"]["damage"])], [92, 8], "the Mire Abbess 92 HP, Lash 8 at level 32")
	eq(str(book.stats_at("mire_abbess", 32)["signature"]["kind"]), "raise", "the Abbess still raises")
	eq(str(book.stats_at("old_saltmaw", 22)["signature"]["kind"]), "pull", "Old Saltmaw still pulls")
	eq(str(book.stats_at("the_pale_archivist", 12)["signature"]["kind"]), "summon", "the Archivist still summons")
	# No other boss raises a root wall; their hazard records carry no pod keys.
	for pair in [[GRANARY, 1], [FROST, 12], [SALT, 22], [ABBEY, 32]]:
		var run = Run.create(str(pair[0]), int(pair[1]), "kestrel", "", 5)["run"]
		sim.reset_match(run.combat_config(1, 31))
		sim.submit({"type": "end_turn", "seat": 0})
		var boss: Dictionary = sim._unit_by_seat(1)
		boss["own_turns"] = 2
		eq(bool(sim.wall_ready(boss)), false, "%s's boss raises no root wall" % pair[0])
		boss["acted_signature"] = true
		boss["own_turns"] = 1 if str(pair[0]) != SALT else 2
		if not (boss.get("signature2", {}) as Dictionary).is_empty() and bool(sim.pools_ready(boss)):
			sim.submit({"type": "cast", "spell": str(boss["signature2"]["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
		for p in sim.snapshot()["dungeon"]["pools"]:
			eq(p.has("fuse") or p.has("splash") or p.has("ap_loss"), false, "%s's hazard record has no pod keys" % pair[0])
		eq((sim.snapshot()["dungeon"]["walls"] as Array).is_empty(), true, "%s has no walls" % pair[0])
	# A bellbound hit still mires (MP), never withers (AP).
	var bl: Dictionary = book.stats_at("bellbound_mire_leech", 32, 5)
	eq((bl["attack"] as Dictionary).has("wither"), false, "bellbound bile does not wither")
	eq(Run.create(GRANARY, 1, "kestrel")["run"].text("victory"), "Old Granary Cellar is cleared at ★1. The Ratking is down.", "the cellar victory line is unchanged")
	eq(Run.create(ABBEY, 32, "kestrel")["run"].text("return_button"), "Return to Southbridge", "the abbey's lines are unchanged")


# --- world door, panel, scene --------------------------------------------------------

func _test_world_door_and_panel() -> void:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.progress.level = LEVEL
	w.enter_zone(ZONE, Vector2i(16, 10), false)
	await process_frame
	eq(w.zone.zone_id, ZONE, "the hero is in Westwatch")
	eq(w.door_nodes.has(BLIGHT), true, "the blight door stands in Westwatch")
	var row: Dictionary = w.dungeon_book.by_id(BLIGHT)
	var building: Array = Dungeons.building_cells_for(row, w.building_size_for(row))
	eq(building.size(), 16, "the stump stands on 4x4 cells")
	for c in building:
		eq(w.zone.passable_at(c), false, "stump cell %s blocks walking" % c)
	eq(w.zone.passable_at(DOOR), true, "the door cell stays walkable")
	eq(w.door_at(ZONE, DOOR).get("id", ""), BLIGHT, "the door cell is a door")
	eq(w.door_at(ZONE, building[0]).get("id", ""), BLIGHT, "clicking the stump finds the door")
	eq(w.door_nodes[BLIGHT].painted, true, "the door draws the painted stump")
	eq(bool(w.approach_door(BLIGHT).get("ok", false)), true, "clicking the door walks there")
	_drive(w)
	eq(w.walker.cell, DOOR, "the hero stands on the door cell")
	eq(w.door_panel.is_open(), true, "the entry panel opens on arrival")
	var text := _panel_text(w.door_panel)
	eq(text.contains("Heart of the Blight"), true, "panel names the blight")
	eq(text.contains("40–50"), true, "panel shows levels 40-50")
	eq(text.contains("The Rotting Elder"), true, "panel names the boss")
	eq(bool(w.door_panel.check.get("ok", false)), true, "a level 42 hero passes the level check")
	eq(w.door_panel.star_buttons.size(), 5, "★1-★5 on the panel")
	w.door_panel.select_star(5)
	eq((w.door_panel.find_child("StarNote", true, false) as Label).text.contains(G_BOSS_NAME.trim_prefix("The ")), true, "the ★5 note is the blight's")
	w.door_panel.leave_button.emit_signal("pressed")
	w._approach_npc(w.npc_book.by_id("westwatch_door_keeper"))
	_drive(w)
	eq(w.door_panel.is_open(), true, "talking to the Door Keeper opens the entry panel")
	Launcher.pending = {}
	w.door_panel.select_star(4)
	w.door_panel.press_enter()
	eq(str(Launcher.pending.get("dungeon_id", "")), BLIGHT, "Enter hands over the blight")
	eq(int(Launcher.pending.get("star", 0)), 4, "Enter hands over the picked star")
	eq(Launcher.pending.get("return_cell", Vector2i(-1, -1)), DOOR, "the way back is the door cell")
	eq(str(Launcher.pending.get("return_zone", "")), ZONE, "the way back is Westwatch")
	Launcher.pending = {}
	w.queue_free()
	await process_frame


func _test_run_scene_win_and_return() -> void:
	Launcher.pending = {"dungeon_id": BLIGHT, "level": LEVEL, "class_id": "ironjaw", "autoplay": true, "return_zone": ZONE, "return_cell": DOOR, "seed": 1}
	Launcher.outcome = {}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	var got := {}
	scene.run_finished.connect(func(r, s): got["result"] = r; got["summary"] = s)
	root.add_child(scene)
	var rooms := {}
	var bolts := false
	var wall_views := 0
	var board = scene.get_node("BoardView")
	var t0 := Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 400000:
		await process_frame
		var snap: Dictionary = sim.snapshot()
		if snap.has("dungeon"):
			rooms[str(snap["dungeon"]["room_id"])] = true
			for e in snap.get("last_events", []):
				bolts = bolts or str(e.get("projectile", "")) == "spore_bolt"
			if not (snap["dungeon"].get("walls", []) as Array).is_empty():
				wall_views = maxi(wall_views, (board.wall_nodes() as Dictionary).size())
	eq(str(got.get("result", "")), "win", "the room scene plays a full blight run to a win")
	eq(rooms.has("room_a") and rooms.has("room_b"), true, "both rooms are played")
	eq(bolts, true, "Blight Horror spore bolts fly in the scene")
	eq(wall_views > 0, true, "the board draws the root wall (%d wall nodes)" % wall_views)
	eq(str(board.view_cfg.get("pads", {}).keys()), str(["blight_pad", "root_rune_circle"]), "the board reads the blight's pad styles")
	eq(scene.result_text().contains("The Rotting Elder is down"), true, "the result panel names the Rotting Elder")
	eq(scene.result_text().contains("Westwatch"), true, "the result panel sends the hero back to Westwatch")
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
	eq(w.zone.zone_id, ZONE, "back in Westwatch")
	eq(w.walker.cell, DOOR, "back on the blight door cell")
	eq(w.reward_popup.is_open(), true, "the reward pop-up shows the drop")
	w.queue_free()
	await process_frame


# --- helpers -----------------------------------------------------------------------

func _resolve_star5_ids() -> void:
	var book = Monsters.load_default()["monsters"]
	for id in book.ids_for(BLIGHT):
		var row: Dictionary = book.raw(id)
		if int(row.get("star_min", 0)) < 5:
			continue
		match str(row.get("variant_of", "")):
			"blight_hound": G_HOUND = id
			"blight_horror": G_HORROR = id
			"rotting_elder": G_BOSS = id
	var run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/dungeons/heart_of_the_blight/run.json"))
	G_BOSS_NAME = str(run["text"]["boss_star5"])
	eq(G_HOUND != "" and G_HORROR != "" and G_BOSS != "", true, "every blight base monster has a ★5 form (%s, %s, %s)" % [G_HOUND, G_HORROR, G_BOSS])
	eq(str(book.raw(G_BOSS).get("name", "")), G_BOSS_NAME, "the ★5 boss's name is the run file's boss_star5")


## True when every live unit in the sim can walk to every other.
func _all_connected() -> bool:
	return bool(sim._units_connected([] as Array[Vector2i]))


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


## 60 seeded rolls (coins + items after the star gate), hashed.
func _loot_fingerprint(dungeon: String, level: int, star: int) -> String:
	var text := ""
	for seed in 60:
		var drop := _loot(dungeon, level, star, 9000 + seed)
		text += "%d|%s;" % [int(drop["coins"]), JSON.stringify(drop["items"])]
	return text.md5_text()


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
