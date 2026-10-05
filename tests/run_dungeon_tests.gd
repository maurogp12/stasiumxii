extends SceneTree

## PC dungeons: dungeons.json rules, the Stoneford granary door and entry
## panel, the Old Granary Cellar rooms, monster AI, the Ratking's summon cap,
## a scripted full run (win, rewards, clear_dungeon mission), a loss back to
## town, and guards that the PvP / Koliseo / mobile paths are unchanged.
## Run: godot --headless --path . -s res://tests/run_dungeon_tests.gd

const Dungeons := preload("res://backend/world_dungeons.gd")
const Monsters := preload("res://backend/pc_monsters.gd")
const Run := preload("res://backend/pc_dungeon_run.gd")
const AI := preload("res://backend/dungeon_ai.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const NpcBook := preload("res://backend/world_npcs.gd")
const Levels := preload("res://backend/world_levels.gd")
const Missions := preload("res://backend/pc_missions.gd")
const Progress := preload("res://backend/pc_progress.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const Launcher := preload("res://scenes/world/dungeon/dungeon_launcher.gd")
const Regions := preload("res://backend/world_regions.gd")
const SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")
const RUN_SCENE_PATH := "res://scenes/world/dungeon/dungeon_run.tscn"
const SCHEMA := "res://data/world/schema/dungeons.schema.json"
const GRANARY := "old_granary_cellar"
const DOOR := Vector2i(16, 11)
const KEEPER := Vector2i(15, 11)
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]

var _passed := 0
var _failed := 0
var sim: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Regions.set_enabled(true)
	Launcher.dry_run = true
	sim = root.get_node("CombatSim")
	_test_doors_json()
	_test_door_rules_reject()
	_test_rooms()
	_test_monsters()
	_test_ai_always_acts()
	_test_ai_corridor()
	_test_summon_cap()
	_test_boss_scatter()
	_test_scripted_win()
	_test_loss_pays_nothing()
	await _test_world_door_and_panel()
	await _test_run_scene_win_and_return()
	await _test_run_scene_loss_and_return()
	_test_paths_unchanged()
	_finish()


func _finish() -> void:
	print("dungeon tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- dungeons.json -----------------------------------------------------------

func _test_doors_json() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	eq(schema["additionalProperties"], false, "dungeons schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.world_dungeons", "dungeons schema format")
	var loaded: Dictionary = Dungeons.load_default()
	eq(bool(loaded.get("ok", false)), true, "dungeons.json loads: %s" % [loaded.get("errors", [])])
	if not bool(loaded.get("ok", false)):
		return
	var book = loaded["dungeons"]
	eq(book.rows.size(), 5, "five Crosshaven town dungeons")
	var built: Array = book.built()
	eq(built.size(), 1, "one dungeon is built")
	var row: Dictionary = book.by_id(GRANARY)
	eq(str(row.get("status", "")), "built", "the Old Granary Cellar is built")
	eq(str(row["level_zone"]), "stoneford", "the cellar is Stoneford's dungeon")
	eq(int(row["level_min"]), 1, "levels from 1")
	eq(int(row["level_max"]), 10, "levels to 10")
	eq(str(row["boss"]), "The Ratking", "the boss is the Ratking")
	eq(int(row["rooms"]), 2, "two rooms")
	eq(int(row["party"]["min"]) == 1 and int(row["party"]["max"]) == 4, true, "party 1-4")
	eq(str(row["door_art"]), "door_old_granary_cellar", "door art id")
	eq(str(row["theme"]), "granary_cellar", "theme id")
	eq(Dungeons.door_cell(row), DOOR, "the hatch is at 16,11 in Stoneford")
	eq(str(row["door"]["zone_id"]), "crosshaven_stoneford", "the door is in the Stoneford chunk")
	var bands := {}
	for r in book.rows:
		bands[str(r["level_zone"])] = int(bands.get(str(r["level_zone"]), 0)) + 1
		if str(r["id"]) != GRANARY:
			eq(str(r["status"]), "planned", "%s is planned" % r["id"])
			eq(r.has("door"), false, "%s has no door yet" % r["id"])
	for band in Dungeons.TOWN_BANDS:
		eq(int(bands.get(band, 0)), 1, "band %s has exactly one dungeon" % band)
	var atlas_loaded: Dictionary = Atlas.load_default()
	var npc_loaded: Dictionary = NpcBook.load_default()
	eq(bool(atlas_loaded.get("ok", false)) and bool(npc_loaded.get("ok", false)), true, "atlas and NPCs load")
	var atlas = atlas_loaded["atlas"]
	var npcs = npc_loaded["npcs"]
	var size := Art.building_size(Art.manifest(_art_path()), Dungeons.DEFAULT_BUILDING)
	var checked: Dictionary = book.validate_world(atlas, npcs, size)
	eq(bool(checked["ok"]), true, "4.6 rules hold on the live world: %s" % [checked["errors"]])
	var zone: WorldZone = atlas.map_for_chunk("crosshaven_stoneford").zone("crosshaven_stoneford")
	eq(zone.passable_at(DOOR), true, "the hatch cell is passable")
	eq(zone.exit_link(DOOR).is_empty(), true, "the hatch is not an exit")
	eq(atlas.gate_at("crosshaven_stoneford", DOOR).is_empty(), true, "the hatch is not a gate")
	eq(DOOR != zone.spawn, true, "the hatch is not the spawn")
	var poi: Dictionary = zone.points_of_interest[0]
	var near := absi(int(poi["x"]) - DOOR.x) + absi(int(poi["y"]) - DOOR.y)
	eq(near <= 6, true, "the hatch is near Stoneford's centre (%d steps)" % near)
	for npc in npcs.for_zone("crosshaven_stoneford"):
		var at := Vector2i(int(npc["cell"]["x"]), int(npc["cell"]["y"]))
		eq(at != DOOR, true, "%s is not on the hatch" % npc["id"])
		for c in Dungeons.building_cells(row, size):
			eq(at != c, true, "%s is not under the granary" % npc["id"])
	var keeper: Dictionary = npcs.by_id("granary_door_keeper")
	eq(Vector2i(int(keeper["cell"]["x"]), int(keeper["cell"]["y"])), KEEPER, "the Door Keeper stands beside the hatch")
	eq(book.for_keeper("granary_door_keeper").get("id", ""), GRANARY, "the keeper opens the cellar")
	var lv: Dictionary = Levels.load_default()
	for r in book.rows:
		var band: Dictionary = lv["levels"].by_id[str(r["level_zone"])]
		eq(str(band.get("dungeon", "")), str(r["id"]), "%s matches level_zones.json" % r["id"])


func _test_door_rules_reject() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Dungeons.PATH))
	var atlas = Atlas.load_default()["atlas"]
	var npcs = NpcBook.load_default()["npcs"]
	var twice: Dictionary = base.duplicate(true)
	(twice["dungeons"] as Array)[1]["level_zone"] = "stoneford"
	var t_book = Dungeons.load_document(twice)["dungeons"]
	eq(bool(t_book.validate_world(atlas, npcs)["ok"]), false, "two dungeons in one band fail")
	var on_npc: Dictionary = base.duplicate(true)
	(on_npc["dungeons"] as Array)[0]["door"] = {"zone_id": "crosshaven_stoneford", "x": KEEPER.x, "y": KEEPER.y}
	eq(bool(Dungeons.load_document(on_npc)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a door on an NPC cell fails")
	var on_exit: Dictionary = base.duplicate(true)
	(on_exit["dungeons"] as Array)[0]["door"] = {"zone_id": "crosshaven_stoneford", "x": 35, "y": 15}
	eq(bool(Dungeons.load_document(on_exit)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a door on an exit fails")
	var in_water: Dictionary = base.duplicate(true)
	(in_water["dungeons"] as Array)[0]["door"] = {"zone_id": "crosshaven_stoneford", "x": 0, "y": 5}
	eq(bool(Dungeons.load_document(in_water)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a door in the water fails")
	var wrong_band: Dictionary = base.duplicate(true)
	(wrong_band["dungeons"] as Array)[0]["door"] = {"zone_id": "crosshaven_northgate", "x": 16, "y": 11}
	eq(bool(Dungeons.load_document(wrong_band)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "a door outside its band fails")
	var planned_door: Dictionary = base.duplicate(true)
	(planned_door["dungeons"] as Array)[1]["door"] = {"zone_id": "crosshaven_northgate", "x": 16, "y": 11}
	eq(bool(Dungeons.load_document(planned_door).get("ok", true)), false, "a planned dungeon with a door fails to load")
	var stray: Dictionary = base.duplicate(true)
	(stray["dungeons"] as Array)[0]["extra"] = 1
	eq(bool(Dungeons.load_document(stray).get("ok", true)), false, "unknown keys fail")


# --- rooms -------------------------------------------------------------------

func _test_rooms() -> void:
	var made: Dictionary = Run.create(GRANARY, 1, "kestrel")
	eq(bool(made.get("ok", false)), true, "the cellar run builds: %s" % [made.get("errors", [])])
	if not bool(made.get("ok", false)):
		return
	var run = made["run"]
	eq(run.room_count(), 2, "room A then room B")
	eq(str(run.room(0)["kind"]), "pack", "room A is the pack fight")
	eq(str(run.room(1)["kind"]), "boss", "room B is the boss fight")
	var counts := {}
	for m in run.room(0)["monsters"]:
		counts[str(m["monster"])] = int(counts.get(str(m["monster"]), 0)) + 1
	eq(int(counts.get("granary_rat", 0)), 2, "room A has 2 Granary Rats")
	eq(int(counts.get("scarecrow_drudge", 0)), 1, "room A has 1 Scarecrow Drudge")
	eq((run.room(1)["monsters"] as Array).size(), 1, "room B has the Ratking alone")
	eq(str(run.room(1)["monsters"][0]["monster"]), "the_ratking", "the boss is the Ratking")
	var man := Art.manifest(_art_path())
	for index in 2:
		var config: Dictionary = run.combat_config(index, 3)
		var room: Dictionary = config["dungeon"]
		var label := str(room["room_id"])
		eq(int(config["board_size"]), 12, "%s is 12x12" % label)
		var cells: Array = room["cells"]
		eq(cells.size(), 144, "%s tags list every cell" % label)
		var walk := {}
		var blocked := 0
		var pads := 0
		for rec in cells:
			var c: Vector2i = rec["pos"]
			if bool(rec["blocks"]):
				blocked += 1
				eq((rec["paint_only"] as Array).is_empty(), false, "%s blocked cell %s has a prop" % [label, c])
				eq(str(rec["special"]), "", "%s a pad is never under a prop" % label)
			else:
				walk[c] = true
			if str(rec["special"]) != "":
				pads += 1
		eq(blocked >= 6, true, "%s has prop obstacles" % label)
		eq(pads >= 4, true, "%s has glowing pads" % label)
		var hero: Vector2i = room["hero"]["pos"]
		eq(walk.has(hero), true, "%s hero spawn is open floor" % label)
		var seen := {hero: true}
		var queue: Array[Vector2i] = [hero]
		var head := 0
		while head < queue.size():
			var cur: Vector2i = queue[head]
			head += 1
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nxt: Vector2i = cur + step
				if walk.has(nxt) and not seen.has(nxt):
					seen[nxt] = true
					queue.append(nxt)
		eq(seen.size(), walk.size(), "%s every open cell is reachable from the hero spawn" % label)
		var spots := {hero: true}
		for m in room["monsters"]:
			var at: Vector2i = m["pos"]
			eq(walk.has(at), true, "%s %s spawns on open floor" % [label, m["monster"]])
			eq(spots.has(at), false, "%s spawns do not overlap" % label)
			spots[at] = true
		sim.reset_match(config)
		var snap: Dictionary = sim.snapshot()
		eq(snap.has("dungeon"), true, "%s runs in dungeon mode" % label)
		eq(int(snap["board_size"]), 12, "%s sim board is 12x12" % label)
		for rec in cells:
			if bool(rec["blocks"]):
				eq(bool(sim.tile_at(rec["pos"]).get("walkable", true)), false, "%s prop cell %s blocks walking" % [label, rec["pos"]])
		eq((snap["dungeon"]["pads"] as Array).size(), pads, "%s pads reach the sim" % label)
		# Art manifest props (when the art has landed) must stand on blocked cells.
		for e in Art.room_props(man, label):
			var pc: Vector2i = e["cell"]
			if pc.x >= 0:
				eq(bool(sim.tile_at(pc).get("walkable", true)), false, "%s manifest prop %s at %s is a blocked cell" % [label, e["id"], pc])


func _test_monsters() -> void:
	var loaded: Dictionary = Monsters.load_default()
	eq(bool(loaded.get("ok", false)), true, "dungeon monsters load: %s" % [loaded.get("errors", [])])
	if not bool(loaded.get("ok", false)):
		return
	var book = loaded["monsters"]
	for id in ["granary_rat", "scarecrow_drudge", "the_ratking"]:
		eq(book.has(id), true, "%s exists" % id)
		var lo: Dictionary = book.stats_at(id, 1)
		var hi: Dictionary = book.stats_at(id, 10)
		eq(int(lo["hp"]) > 0 and int(lo["ap"]) > 0 and int(lo["mp"]) > 0, true, "%s has HP, AP and MP" % id)
		eq(int(hi["hp"]) >= int(lo["hp"]) and int((hi["attack"] as Dictionary)["damage"]) >= int((lo["attack"] as Dictionary)["damage"]), true, "%s scales up through 1-10" % id)
		eq(int(book.stats_at(id, 30)["level"]), 10, "%s clamps to its band" % id)
	eq(bool(book.stats_at("the_ratking", 1)["boss"]), true, "the Ratking is the boss")
	eq(str((book.stats_at("the_ratking", 1)["signature"] as Dictionary)["summon"]), "granary_rat", "the Ratking summons Granary Rats")
	var check: Dictionary = book.check(1)
	eq(bool(check["ok"]), true, "level 1 numbers pass the sanity pass: %s" % [check["findings"]])


# --- AI ----------------------------------------------------------------------

## Every monster turn ends within MAX_STEPS intents and hands the turn on.
func _test_ai_always_acts() -> void:
	var stuck := 0
	var unfinished := 0
	var monster_turns := 0
	var attacks := 0
	for cls in CLASSES:
		for seed in 3:
			var run = Run.create(GRANARY, 1, cls)["run"]
			for index in 2:
				sim.reset_match(run.combat_config(index, 50 + seed))
				var guard := 0
				var limit := 1600 if cls == "mender" else 500
				while not bool(sim.snapshot()["match_over"]) and guard < limit:
					guard += 1
					var seat := int(sim.snapshot()["active_seat"])
					if seat == 0:
						AI.play_hero_turn(sim)
						continue
					monster_turns += 1
					var done := AI.play_monster_turn(sim, seat)
					for d in done:
						if str(d["intent"].get("type", "")) == "cast" and bool(d["ok"]):
							attacks += 1
						if bool(d["intent"].get("forced", false)):
							stuck += 1
					var after: Dictionary = sim.snapshot()
					if not bool(after["match_over"]) and int(after["active_seat"]) == seat:
						unfinished += 1
				if guard >= limit:
					unfinished += 1
				if not bool(sim.snapshot()["match_over"]):
					break
				if str(sim.snapshot()["dungeon"]["result"]) != "win":
					break
	eq(monster_turns > 50, true, "monster turns were played (%d)" % monster_turns)
	eq(attacks > 20, true, "monsters reach the hero and attack (%d)" % attacks)
	eq(stuck, 0, "no monster turn needed a forced end")
	eq(unfinished, 0, "every monster turn ends and every fight finishes")


## A rat boxed behind another rat in a one-wide lane still ends its turn,
## and it walks on once the lane opens.
func _test_ai_corridor() -> void:
	var cells: Array = []
	for y in 12:
		for x in 12:
			var lane := x == 5
			var row := y == 11
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": [] if (lane or row) else ["crate"], "blocks": not (lane or row), "special": ""})
	var rat: Dictionary = Monsters.load_default()["monsters"].stats_at("granary_rat", 1)
	var a := rat.duplicate(true)
	a["pos"] = Vector2i(5, 1)
	a["facing"] = "S"
	var b := rat.duplicate(true)
	b["pos"] = Vector2i(5, 0)
	b["facing"] = "S"
	sim.reset_match({"board_size": 12, "seed": 9, "dungeon": {"dungeon_id": "t", "room_id": "lane", "room_name": "Lane", "kind": "pack", "cells": cells, "pad_heal": 0, "hero": {"class_id": "kestrel", "pos": Vector2i(0, 11), "facing": "N"}, "monsters": [a, b], "summons": {}}})
	sim.submit({"type": "end_turn", "seat": 0})
	var first := AI.play_monster_turn(sim, 1)
	eq(int(sim.snapshot()["active_seat"]), 2, "the front rat ends its turn")
	var moved_first := false
	for d in first:
		if str(d["intent"]["type"]) == "move":
			moved_first = true
	eq(moved_first, true, "the front rat walks down the lane")
	var second := AI.play_monster_turn(sim, 2)
	eq(int(sim.snapshot()["active_seat"]), 0, "the rat behind ends its turn too")
	var forced := false
	for d in second:
		if bool(d["intent"].get("forced", false)):
			forced = true
	eq(forced, false, "the rat behind ends cleanly, no forced end")
	var pos_b: Vector2i = _unit(sim.snapshot(), 2)["pos"]
	eq(pos_b.y > 0, true, "the rat behind follows into the lane")


# --- Ratking -------------------------------------------------------------------

func _test_summon_cap() -> void:
	var run = Run.create(GRANARY, 1, "kestrel")["run"]
	var config: Dictionary = run.combat_config(1, 11)
	var sig: Dictionary = (config["dungeon"]["monsters"][0] as Dictionary)["signature"]
	sim.reset_match(config)
	var max_alive := 0
	var summons_on: Array = []
	var not_ready_rejected := false
	for round_n in 14:
		if bool(sim.snapshot()["match_over"]):
			break
		# The hero stands still (end turn) so only the Ratking's rhythm counts.
		sim.submit({"type": "end_turn", "seat": 0})
		var guard := 0
		while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]) and guard < 20:
			guard += 1
			var seat := int(sim.snapshot()["active_seat"])
			var king := _unit(sim.snapshot(), 1)
			if seat == 1 and not bool(sim.summon_ready(sim._unit_by_seat(1))):
				var refused: Dictionary = sim.submit({"type": "cast", "spell": str(sig["id"]), "to": king["pos"], "seat": 1})
				if not bool(refused.get("ok", true)) and str(refused.get("reason", "")) == "summon_not_ready":
					not_ready_rejected = true
			for d in AI.play_monster_turn(sim, seat):
				if str(d["intent"].get("spell", "")) == str(sig["id"]) and bool(d["ok"]):
					summons_on.append(int(sim._unit_by_seat(1)["own_turns"]))
			var alive := 0
			for u in sim.snapshot()["units"]:
				if bool(u.get("summoned", false)) and bool(u.get("alive", false)):
					alive += 1
			max_alive = maxi(max_alive, alive)
		# Keep the hero alive so the cap is tested over many turns, and clear
		# the swarm every other round (as a hero would) so the total cap shows.
		sim._unit_by_seat(0)["hp"] = 80
		if round_n % 2 == 1:
			for u in sim._living_monsters():
				if bool(u.get("summoned", false)):
					u["hp"] = 0
					u["alive"] = false
	var total := int(sim.snapshot()["dungeon"]["summoned_total"])
	eq(summons_on.is_empty(), false, "the Ratking calls the swarm")
	eq(summons_on[0] if not summons_on.is_empty() else -1, int(sig["first_turn"]), "the first call is on his turn %d" % int(sig["first_turn"]))
	for t in summons_on:
		eq((int(t) - int(sig["first_turn"])) % int(sig["every"]), 0, "calls come every %d turns (turn %d)" % [int(sig["every"]), int(t)])
	eq(max_alive <= int(sig["cap_alive"]), true, "never more than %d summoned rats alive (%d)" % [int(sig["cap_alive"]), max_alive])
	eq(total <= int(sig["cap_total"]), true, "never more than %d summoned in all (%d)" % [int(sig["cap_total"]), total])
	eq(total, int(sig["cap_total"]), "the cap is reached over a long fight")
	eq(not_ready_rejected, true, "an early call is refused")


func _test_boss_scatter() -> void:
	var run = Run.create(GRANARY, 1, "ironjaw")["run"]
	var config: Dictionary = run.combat_config(1, 21)
	sim.reset_match(config)
	# Bring the Ratking to his call turn next to the hero.
	var king: Dictionary = sim._unit_by_seat(1)
	king["pos"] = Vector2i(6, 9)
	king["own_turns"] = 1
	sim.submit({"type": "end_turn", "seat": 0})
	var spell := str((king["signature"] as Dictionary)["id"])
	var called: Dictionary = sim.submit({"type": "cast", "spell": spell, "to": king["pos"], "seat": 1})
	eq(bool(called.get("ok", false)), true, "the Ratking calls on his second turn")
	var made := 0
	for u in sim.snapshot()["units"]:
		if bool(u.get("summoned", false)):
			made += 1
	eq(made, 2, "two Granary Rats answer")
	while int(sim.snapshot()["active_seat"]) != 0:
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
	king["hp"] = 5
	var struck: Dictionary = sim.submit({"type": "cast", "spell": "strike", "to": king["pos"], "target_seat": 1, "seat": 0})
	var guard := 0
	while not bool(sim.snapshot()["match_over"]) and guard < 8:
		guard += 1
		if int(sim.snapshot()["active_seat"]) != 0:
			break
		if int(sim._unit_by_seat(0)["ap"]) < 3:
			break
		struck = sim.submit({"type": "cast", "spell": "strike", "to": king["pos"], "target_seat": 1, "seat": 0})
	var snap: Dictionary = sim.snapshot()
	eq(bool(snap["match_over"]), true, "downing the Ratking ends the room")
	eq(str(snap["dungeon"]["result"]), "win", "the room is won")
	var fled := 0
	for u in snap["units"]:
		if bool(u.get("fled", false)):
			fled += 1
	eq(fled, 2, "his swarm scatters")


# --- runs ----------------------------------------------------------------------

func _test_scripted_win() -> void:
	var run = Run.create(GRANARY, 1, "kestrel")["run"]
	var result := _play_run(run, 1000)
	eq(result, "win", "a level 1 Kestrel clears the cellar (room A, then the Ratking)")
	eq(str(run.result), "win", "the run records the win")
	var hero = _fresh_hero()
	var missions = Missions.load_default()["missions"]
	hero.mission_blob = {"story": {"stoneford_scout": {"status": "done"}}}
	eq(missions.label_for("stoneford_dungeon", hero) != "coming soon", true, "the cellar mission is no longer coming soon")
	var accepted: Dictionary = missions.accept("stoneford_dungeon", hero)
	eq(bool(accepted.get("ok", false)), true, "the cellar mission can be taken: %s" % accepted.get("reason", ""))
	eq(missions.label_for("frostspire_archive_x", hero), "", "unknown ids stay empty")
	var coins_before := int(hero.coins)
	var summary: Dictionary = run.pay_out(hero, missions, _rng(5), false)
	eq(int(summary["xp"]), run.win_xp(1), "XP is the 4.8 dungeon share")
	eq(int(summary["xp"]), 43, "level 1 win: 27% of 100 x pace 1.6 = 43 XP")
	eq(int(summary["coins"]), 8 * int(round(3.0 + 1.5)), "coins from the cellar's reward table")
	eq((summary["items"] as Array).size() >= 1, true, "at least one dungeon part drops")
	eq(int(hero.coins), coins_before + int(summary["coins"]), "coins are granted")
	eq(int(hero.xp) + 0 > 0 or not (summary["level_ups"] as Array).is_empty(), true, "XP is granted")
	eq((summary["missions"] as Array).has("stoneford_dungeon"), true, "the clear_dungeon mission is credited")
	eq(missions.status_of("stoneford_dungeon", hero), "ready", "the cellar mission is ready to turn in")
	var other = Run.create("frostspire_archive", 12, "kestrel")
	eq(bool(other.get("ok", true)), false, "a planned dungeon cannot be run")


func _test_loss_pays_nothing() -> void:
	var run = Run.create(GRANARY, 1, "kestrel")["run"]
	run.hero_hp = 1
	var result := _play_run(run, 77)
	eq(result, "lose", "a 1 HP hero is driven out")
	var hero = _fresh_hero()
	var before := [int(hero.xp), int(hero.coins), (hero.bag as Array).size()]
	var summary: Dictionary = run.pay_out(hero, null, _rng(1), false)
	eq(int(summary["xp"]), 0, "a loss gives no XP")
	eq(int(summary["coins"]), 0, "a loss gives no coins")
	eq([int(hero.xp), int(hero.coins), (hero.bag as Array).size()], before, "the hero is unchanged")
	var check: Dictionary = Run.entry_check(Dungeons.load_default()["dungeons"].by_id(GRANARY), 1)
	eq(bool(check["ok"]), true, "level 1 passes the level check")
	eq(bool(Run.entry_check(Dungeons.load_default()["dungeons"].by_id(GRANARY), 0)["ok"]), false, "level 0 fails the level check")
	eq(bool(Run.entry_check(Dungeons.load_default()["dungeons"].by_id(GRANARY), 14)["ok"]), true, "an over-band hero may still enter")
	eq(bool(Run.entry_check(Dungeons.load_default()["dungeons"].by_id("drowned_abbey"), 35)["ok"]), false, "a planned door is closed")


func _play_run(run, seed: int) -> String:
	while true:
		sim.reset_match(run.combat_config(-1, seed + run.room_index))
		var guard := 0
		while not bool(sim.snapshot()["match_over"]) and guard < 600:
			guard += 1
			var seat := int(sim.snapshot()["active_seat"])
			if seat == 0:
				AI.play_hero_turn(sim)
			else:
				AI.play_monster_turn(sim, seat)
		if str(sim.snapshot()["dungeon"]["result"]) != "win":
			run.lose()
			return "lose"
		if not run.advance():
			return "win"
	return ""


# --- world door, panel, scene ---------------------------------------------------

func _test_world_door_and_panel() -> void:
	var settings := VisualSettings.new()
	settings.apply_preset("Full")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	eq(w.dungeon_book != null, true, "the world loads dungeons.json")
	w.enter_zone("crosshaven_stoneford", Vector2i(16, 16), false)
	await process_frame
	eq(w.zone.zone_id, "crosshaven_stoneford", "the hero is in Stoneford")
	eq(w.door_nodes.has(GRANARY), true, "the granary stands in Stoneford")
	var node = w.door_nodes.get(GRANARY)
	var row: Dictionary = w.dungeon_book.by_id(GRANARY)
	var building: Array = Dungeons.building_cells(row, w.building_size_for(row))
	for c in building:
		eq(w.zone.passable_at(c), false, "granary cell %s blocks walking" % c)
	eq(w.zone.passable_at(DOOR), true, "the hatch stays walkable")
	eq(w._npc_at(KEEPER).is_empty(), false, "the Door Keeper stands beside the hatch")
	eq(w.door_at("crosshaven_stoneford", DOOR).get("id", ""), GRANARY, "the hatch is a door cell")
	eq(w.door_at("crosshaven_stoneford", building[0]).get("id", ""), GRANARY, "clicking the building finds the door")
	eq(w.door_at("crosshaven_stoneford", Vector2i(16, 16)).is_empty(), true, "the square is not a door")
	w._set_hover(w.zone, DOOR)
	eq(bool(node.hovered), true, "hovering the hatch lights it")
	w._set_hover(w.zone, Vector2i(16, 16))
	eq(bool(node.hovered), false, "the glow goes off elsewhere")
	var walk: Dictionary = w.approach_door(GRANARY)
	eq(bool(walk.get("ok", false)), true, "clicking the hatch walks there")
	eq(w.door_panel.is_open(), false, "the panel waits for arrival")
	_drive(w)
	eq(w.walker.cell, DOOR, "the hero stands on the hatch")
	eq(w.door_panel.is_open(), true, "the entry panel opens on arrival")
	var text := _panel_text(w.door_panel)
	eq(text.contains("Old Granary Cellar"), true, "panel names the dungeon")
	eq(text.contains("1–10"), true, "panel shows levels 1-10")
	eq(text.contains("Party 1–4"), true, "panel shows party 1-4")
	eq(text.to_lower().contains("solo for now"), true, "panel says runs are solo for now")
	eq(text.contains("The Ratking"), true, "panel names the boss")
	eq(bool(w.door_panel.check.get("ok", false)), true, "the level check passes at level %d" % int(w.progress.level))
	eq(w.door_panel.enter_button.disabled, false, "Enter is live")
	w.door_panel.leave_button.emit_signal("pressed")
	eq(w.door_panel.is_open(), false, "Leave closes the panel")
	# Talking to the Door Keeper opens the same panel.
	w._approach_npc(w.npc_book.by_id("granary_door_keeper"))
	_drive(w)
	eq(w.door_panel.is_open(), true, "talking to the Door Keeper opens the entry panel")
	eq(w.dialogue.is_open(), false, "the plain dialogue stays shut")
	eq(_panel_text(w.door_panel).contains("Ratking"), true, "the keeper's line shows on the panel")
	Launcher.pending = {}
	Launcher.last_scene = ""
	w.door_panel.press_enter()
	eq(Launcher.last_scene, Launcher.RUN_SCENE, "Enter opens the dungeon scene")
	eq(str(Launcher.pending.get("dungeon_id", "")), GRANARY, "Enter hands over the cellar")
	eq(Launcher.pending.get("return_cell", Vector2i(-1, -1)), DOOR, "the way back is the door cell")
	eq(str(Launcher.pending.get("return_zone", "")), "crosshaven_stoneford", "the way back is Stoneford")
	Launcher.pending = {}
	w.queue_free()
	await process_frame


func _test_run_scene_win_and_return() -> void:
	Launcher.pending = {"dungeon_id": GRANARY, "level": 1, "class_id": "ironjaw", "autoplay": true, "return_zone": "crosshaven_stoneford", "return_cell": DOOR, "seed": 7}
	Launcher.outcome = {}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	var got := {}
	scene.run_finished.connect(func(r, s): got["result"] = r; got["summary"] = s)
	root.add_child(scene)
	var rooms := {}
	var summon_seen := false
	var t0 := Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 240000:
		await process_frame
		var snap: Dictionary = sim.snapshot()
		if snap.has("dungeon"):
			rooms[str(snap["dungeon"]["room_id"])] = true
			if int(snap["dungeon"]["summoned_total"]) > 0:
				summon_seen = true
	eq(str(got.get("result", "")), "win", "the room scene plays a full run to a win")
	eq(rooms.has("room_a") and rooms.has("room_b"), true, "both rooms are played in the scene")
	eq(summon_seen, true, "the Ratking summons during the scene run")
	var summary: Dictionary = got.get("summary", {})
	eq(int(summary.get("xp", 0)) > 0 and int(summary.get("coins", 0)) > 0, true, "the scene pays XP and coins")
	eq(scene.result_text().contains("Victory"), true, "the result panel shows the victory")
	var t1 := Time.get_ticks_msec()
	while Launcher.outcome.is_empty() and Time.get_ticks_msec() - t1 < 15000:
		await process_frame
	eq(str(Launcher.outcome.get("result", "")), "win", "the scene hands the win back to the world")
	eq(Launcher.last_scene, Launcher.WORLD_SCENE, "the scene returns to the world")
	scene.queue_free()
	await process_frame
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	await process_frame
	eq(w.zone.zone_id, "crosshaven_stoneford", "back in Stoneford")
	eq(w.walker.cell, DOOR, "back on the door cell")
	eq(str(w.dungeon_outcome().get("result", "")), "win", "the world took the win")
	eq(w.reward_popup.is_open(), true, "the reward pop-up shows the drop")
	w.queue_free()
	await process_frame


func _test_run_scene_loss_and_return() -> void:
	Launcher.pending = {"dungeon_id": GRANARY, "level": 1, "class_id": "kestrel", "autoplay": true, "return_zone": "crosshaven_stoneford", "return_cell": DOOR, "seed": 3, "hero_hp": 1}
	Launcher.outcome = {}
	var hero_before = Progress.new()
	var coins_before := int(hero_before.coins)
	var xp_before := [int(hero_before.level), int(hero_before.xp)]
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	var got := {}
	scene.run_finished.connect(func(r, s): got["result"] = r; got["summary"] = s)
	root.add_child(scene)
	var t0 := Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	eq(str(got.get("result", "")), "lose", "a 1 HP hero loses the run")
	eq(int((got.get("summary", {}) as Dictionary).get("coins", -1)), 0, "no coins on a loss")
	eq(scene.result_text().contains("No rewards"), true, "the defeat panel says no rewards")
	var t1 := Time.get_ticks_msec()
	while Launcher.outcome.is_empty() and Time.get_ticks_msec() - t1 < 15000:
		await process_frame
	eq(str(Launcher.outcome.get("result", "")), "lose", "the loss goes back to the world")
	scene.queue_free()
	await process_frame
	var hero_after = Progress.new()
	eq(int(hero_after.coins), coins_before, "the saved hero kept the same coins")
	eq([int(hero_after.level), int(hero_after.xp)], xp_before, "the saved hero kept the same XP")
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	await process_frame
	eq(w.zone.zone_id, "crosshaven_stoneford", "a loss returns to Stoneford")
	eq(w.walker.cell, DOOR, "a loss returns to the door cell")
	eq(w.reward_popup.is_open(), false, "no reward pop-up after a loss")
	w.queue_free()
	await process_frame


# --- unchanged paths -------------------------------------------------------------

func _test_paths_unchanged() -> void:
	# A dungeon match leaves nothing behind for the next PvP reset.
	sim.reset_match(Run.create(GRANARY, 1, "kestrel")["run"].combat_config(0, 1))
	eq(bool(sim.is_dungeon()), true, "the autoload ran a dungeon room")
	var pvp_config := {"seed": 4242, "skip_deploy": true, "classes": ["kestrel", "ironjaw"]}
	sim.reset_match(pvp_config)
	eq(bool(sim.is_dungeon()), false, "a PvP reset clears dungeon mode")
	var after: Dictionary = sim.snapshot()
	eq(after.has("dungeon"), false, "PvP snapshots carry no dungeon block")
	eq(after.has("local_seat"), false, "PvP snapshots carry no local seat")
	eq((after["units"] as Array).size(), 2, "PvP keeps two seats")
	var fresh: Node = SIM_SCRIPT.new()
	root.add_child(fresh)
	var before: Dictionary = fresh.reset_match(pvp_config)
	var script_moves := [{"type": "move", "to": Vector2i(2, 1)}, {"type": "end_turn"}, {"type": "face", "dir": "N"}, {"type": "end_turn"}]
	var a_snaps: Array = []
	var b_snaps: Array = []
	for intent in script_moves:
		a_snaps.append(_strip_volatile(sim.submit(intent.duplicate(true)).get("snapshot", sim.snapshot())))
		b_snaps.append(_strip_volatile(fresh.submit(intent.duplicate(true)).get("snapshot", fresh.snapshot())))
	eq(a_snaps == b_snaps, true, "a PvP match after a dungeon plays exactly like a fresh sim")
	eq(sim.legal_intents(0) == fresh.legal_intents(0), true, "PvP legal intents match a fresh sim")
	eq(before.has("dungeon"), false, "fresh PvP reset has no dungeon block")
	fresh.queue_free()
	# Koliseo: every ship map still loads its tags on the 15x15 board.
	for map_id in ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]:
		var snap: Dictionary = sim.reset_match({"seed": 3, "map_id": map_id, "skip_deploy": true})
		eq(int(snap["board_size"]), 15, "%s Koliseo board stays 15x15" % map_id)
		eq(str(snap["map_id"]), "%s_15" % map_id, "%s Koliseo tags still load" % map_id)
		eq(snap.has("dungeon"), false, "%s Koliseo match has no dungeon block" % map_id)
	# The shared Koliseo / mobile view files carry no dungeon code.
	for path in ["res://board_view.gd", "res://ui/hud.gd", "res://units/pawn.gd", "res://main.tscn", "res://scenes/mobile_hub.gd", "res://scenes/class_select.gd", "res://backend/net_session.gd"]:
		eq(FileAccess.get_file_as_string(path).to_lower().contains("dungeon_board_view") or FileAccess.get_file_as_string(path).contains("pc_dungeon_run"), false, "%s has no dungeon hook" % path)
	var hub_text := FileAccess.get_file_as_string("res://scenes/mobile_hub.gd")
	eq(hub_text.contains("Stasis doors and dungeon scenes stay on the"), true, "the mobile hub note is unchanged")
	eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/mobile_hub.tscn", "the main scene is still the hub")
	var hub: Node = load("res://scenes/mobile_hub.tscn").instantiate()
	hub.set("_auto_launch", false)
	root.add_child(hub)
	eq(hub.door_count() >= 1, true, "the mobile hub still builds its doors")
	hub.queue_free()
	sim.reset_match({})


func _strip_volatile(snap: Dictionary) -> Dictionary:
	var copy := snap.duplicate(true)
	copy.erase("turn_time_remaining")
	copy.erase("turn_time_seconds")
	return copy


# --- helpers -------------------------------------------------------------------

func _art_path() -> String:
	var run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/dungeons/old_granary_cellar/run.json"))
	return str(run.get("art", ""))


func _fresh_hero():
	var hero = Progress.new()
	hero.level = 1
	hero.xp = 0
	hero.coins = 0
	hero.bag = []
	hero.bank = []
	hero.mission_blob = {}
	hero.hero_class = "kestrel"
	return hero


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func _unit(snap: Dictionary, seat: int) -> Dictionary:
	for u in snap.get("units", []):
		if int(u.get("seat", -1)) == seat:
			return u
	return {}


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
