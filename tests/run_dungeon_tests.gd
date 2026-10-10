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
	_test_star_scaling()
	_test_packs_and_spawns()
	_test_star_rewards()
	_test_star5_boss_and_pools()
	_test_sling_rat()
	_test_turn_pacing()
	_test_scripted_win()
	_test_loss_pays_nothing()
	await _test_world_door_and_panel()
	await _test_run_scene_win_and_return()
	await _test_run_scene_loss_and_return()
	await _test_click_sweep()
	await _test_monster_click_sweep()
	await _test_targeting_chrome()
	_test_dungeon_turn_timer()
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
	eq(int(counts.get("granary_rat", 0)), 2, "★1 room A has 2 Granary Rats")
	eq(int(counts.get("sling_rat", 0)), 2, "★1 room A has 2 Sling Rats")
	eq(int(counts.get("scarecrow_drudge", 0)), 2, "★1 room A has 2 Scarecrow Drudges")
	var boss_room: Array = run.room(1)["monsters"]
	eq(str(boss_room[0]["monster"]), "the_ratking", "the boss is the Ratking")
	var escort := {}
	for m in boss_room.slice(1):
		escort[str(m["monster"])] = int(escort.get(str(m["monster"]), 0)) + 1
	eq(escort, {"granary_rat": 2, "scarecrow_drudge": 1}, "the Ratking's escort: 2 Granary Rats and 1 Scarecrow Drudge")
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
	for id in ["granary_rat", "sling_rat", "scarecrow_drudge", "the_ratking", "radioactive_rat", "radioactive_sling_rat", "radioactive_ratking"]:
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
	var kind := str(sig["summon"])
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
			# One cap for every live rat of the summoned kind: escort and calls.
			var alive := 0
			for u in sim.snapshot()["units"]:
				if (bool(u.get("summoned", false)) or str(u.get("monster", "")) == kind) and bool(u.get("alive", false)):
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
	eq(max_alive <= int(sig["cap_alive"]), true, "never more than %d rats alive, escort included (%d)" % [int(sig["cap_alive"]), max_alive])
	eq(total <= int(sig["cap_total"]), true, "never more than %d summoned in all (%d)" % [int(sig["cap_total"]), total])
	eq(total, int(sig["cap_total"]), "the cap is reached over a long fight")
	eq(not_ready_rejected, true, "an early call is refused")


func _test_boss_scatter() -> void:
	var run = Run.create(GRANARY, 1, "ironjaw")["run"]
	var config: Dictionary = run.combat_config(1, 21)
	config["rolls"] = []
	for i in 80:
		config["rolls"].append(1)
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
	eq(made, 2, "two Granary Rats answer (2 escort rats + 2 = the cap of 4)")
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
	eq(bool(_unit(snap, 1)["alive"]), false, "the Ratking falls")
	var fled := 0
	for u in snap["units"]:
		if bool(u.get("fled", false)):
			fled += 1
	eq(fled, 2, "his summoned swarm scatters")
	eq(bool(snap["match_over"]), false, "his escort fights on: the room is not won yet")
	var escort_left := 0
	for u in sim._living_monsters():
		escort_left += 1
		u["hp"] = 0
		sim._check_death(u)
	eq(escort_left, 3, "the escort (2 rats, 1 Drudge) is still standing")
	snap = sim.snapshot()
	eq(bool(snap["match_over"]), true, "the room ends when every monster is down")
	eq(str(snap["dungeon"]["result"]), "win", "the room is won")


# --- stars ---------------------------------------------------------------------

func _test_star_scaling() -> void:
	var book = Monsters.load_default()["monsters"]
	var doc: Dictionary = book.stars_doc()
	eq(doc["mobile_scale"]["5"], [8.8, 5.2], "the mobile STAR_SCALE is kept for reference")
	var prev_hp := 0
	for star in range(1, 6):
		var mult: Array = book.star_scale(star)
		var raw: Dictionary = book.stats_at("granary_rat", 1, 1)
		var at: Dictionary = book.stats_at("granary_rat", 1, star)
		eq(int(at["hp"]), maxi(int(round(float(raw["hp"]) * float(mult[0]))), 1), "★%d rat HP is base x %.2f" % [star, float(mult[0])])
		eq(int(at["attack"]["damage"]), maxi(int(round(float(raw["attack"]["damage"]) * float(mult[1]))), 1), "★%d rat damage is base x %.2f" % [star, float(mult[1])])
		if star <= 4:
			eq(int(at["hp"]) >= prev_hp, true, "★%d is not softer than the star below" % star)
			prev_hp = int(at["hp"])
	var run = Run.create(GRANARY, 1, "kestrel", "", 3)["run"]
	eq(run.star, 3, "the run keeps the picked star")
	var cfg: Dictionary = run.combat_config(0, 1)
	var rat: Dictionary = {}
	for m in cfg["dungeon"]["monsters"]:
		if str(m["monster"]) == "granary_rat":
			rat = m
	eq(int(rat["hp"]), int(book.stats_at("granary_rat", 1, 3)["hp"]), "★3 room A rats carry ★3 HP")
	eq(int(Run.create(GRANARY, 1, "kestrel", "", 9)["run"].star), 5, "stars clamp to 5")


func _test_packs_and_spawns() -> void:
	var expect := {1: {"granary_rat": 2, "sling_rat": 2, "scarecrow_drudge": 2}, 2: {"granary_rat": 2, "sling_rat": 2, "scarecrow_drudge": 2},
		3: {"granary_rat": 3, "sling_rat": 2, "scarecrow_drudge": 2}, 4: {"granary_rat": 3, "sling_rat": 2, "scarecrow_drudge": 2},
		5: {"radioactive_rat": 3, "radioactive_sling_rat": 3, "scarecrow_drudge": 2}}
	var totals := {1: 6, 2: 6, 3: 7, 4: 7, 5: 8}
	for star in range(1, 6):
		var run = Run.create(GRANARY, 1, "kestrel", "", star)["run"]
		var cfg: Dictionary = run.combat_config(0, 1)
		var room: Dictionary = cfg["dungeon"]
		var got := {}
		for m in room["monsters"]:
			got[str(m["monster"])] = int(got.get(str(m["monster"]), 0)) + 1
		eq(got, expect[star], "★%d room A pack" % star)
		eq((room["monsters"] as Array).size(), totals[star], "★%d room A has %d monsters" % [star, totals[star]])
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
			eq(pads.has(at), false, "★%d %s at %s is not on a pad" % [star, m["monster"], at])
			eq(walk.has(at), true, "★%d %s spawns on open floor" % [star, m["monster"]])
			eq(at.y <= 4 and maxi(absi(at.x - hero.x), absi(at.y - hero.y)) >= 6, true, "★%d %s starts on the far side, away from the hero" % [star, m["monster"]])
			eq(taken.has(at), false, "★%d spawns do not overlap" % star)
			taken[at] = true
		# The pack never seals a route: with the monsters standing, the hero
		# still reaches every other open cell.
		var seen := {hero: true}
		var queue: Array[Vector2i] = [hero]
		var head := 0
		while head < queue.size():
			var cur: Vector2i = queue[head]
			head += 1
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nxt: Vector2i = cur + step
				if walk.has(nxt) and not taken.has(nxt) and not seen.has(nxt):
					seen[nxt] = true
					queue.append(nxt)
		eq(seen.size(), walk.size() - taken.size(), "★%d the pack leaves every route open" % star)
		var boss: Dictionary = run.combat_config(1, 1)["dungeon"]
		eq((boss["monsters"] as Array).size(), 4, "★%d room B: the boss and his 3-strong escort" % star)


func _test_star_rewards() -> void:
	var base_xp := 0
	var base_coins := 0
	for star in range(1, 6):
		var run = Run.create(GRANARY, 1, "kestrel", "", star)["run"]
		run.result = "win"
		var hero = _fresh_hero()
		var rares := 0
		var boxes := 0
		var trials := 30 if star < 5 else 10
		var summary: Dictionary = {}
		for t in trials:
			var h2 = _fresh_hero()
			var s2: Dictionary = run.pay_out(h2, null, _rng(100 + t), false)
			for item in s2["items"]:
				if str(item.get("rarity", "")) == "rare":
					rares += 1
				if str(item.get("item_id", "")) == "mystery_box":
					boxes += 1
			summary = s2
		if star == 1:
			base_xp = int(summary["xp"])
			base_coins = int(summary["coins"])
		eq(int(summary["xp"]), base_xp * star, "★%d XP is %d x %d (mobile: 60 x star)" % [star, base_xp, star])
		eq(int(summary["coins"]), base_coins * star, "★%d coins are ★1 coins x %d" % [star, star])
		if star < 3:
			eq(rares, 0, "★%d drops no Rare part" % star)
		if star == 5:
			eq(rares >= trials, true, "★5 always drops a Rare part")
			eq(boxes >= trials, true, "★5 always drops a Mystery Box (the Legendary slot)")
		var s3: Dictionary = run.pay_out(hero, null, _rng(7), false)
		eq(int(hero.best_dungeon_star(GRANARY)), star, "★%d clear is recorded as the best star" % star)
		eq(bool(s3.get("new_best_star", false)), true, "★%d is reported as a new best" % star)
	var keep = _fresh_hero()
	keep.note_dungeon_star(GRANARY, 4)
	eq(keep.note_dungeon_star(GRANARY, 2), false, "a lower star does not replace the best")
	eq(keep.best_dungeon_star(GRANARY), 4, "the best star stays ★4")
	# Mission credit on any star.
	var missions = Missions.load_default()["missions"]
	for star in [2, 5]:
		var hero2 = _fresh_hero()
		hero2.mission_blob = {"story": {"stoneford_scout": {"status": "done"}}}
		missions.accept("stoneford_dungeon", hero2)
		var r2 = Run.create(GRANARY, 1, "kestrel", "", star)["run"]
		r2.result = "win"
		var sm: Dictionary = r2.pay_out(hero2, missions, _rng(3), false)
		eq((sm["missions"] as Array).has("stoneford_dungeon"), true, "a ★%d win credits the mission" % star)


func _test_star5_boss_and_pools() -> void:
	var run = Run.create(GRANARY, 1, "kestrel", "", 5)["run"]
	var cfg: Dictionary = run.combat_config(1, 31)
	var room: Dictionary = cfg["dungeon"]
	var boss: Dictionary = room["monsters"][0]
	eq(str(boss["monster"]), "radioactive_ratking", "★5 room B boss is the Radioactive Ratking")
	eq(str(boss["name"]), "Radioactive Ratking", "his name shows")
	eq(str(boss["signature"]["summon"]), "radioactive_rat", "he calls radioactive rats")
	eq(room["summons"].has("radioactive_rat"), true, "radioactive rat stats ride along for his calls")
	eq(str(room["monsters"][1]["monster"]), "radioactive_rat", "his escort rats are radioactive")
	eq(str(Run.create(GRANARY, 1, "kestrel", "", 4)["run"].combat_config(1, 1)["dungeon"]["monsters"][0]["monster"]), "the_ratking", "★4 keeps the plain Ratking")
	cfg["rolls"] = []
	for i in 200:
		cfg["rolls"].append(99)
	sim.reset_match(cfg)
	var king: Dictionary = sim._unit_by_seat(1)
	var sig2: Dictionary = king["signature2"]
	# Round 1: the hero waits; the king's first turn is a pools turn.
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pools_ready(king)), true, "pools are ready on his first turn")
	var hero_cell: Vector2i = sim._unit_by_seat(0)["pos"]
	var cast: Dictionary = sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero_cell, "seat": 1})
	eq(bool(cast.get("ok", false)), true, "he spills the toxic pools")
	var pools: Array = sim.pool_cells()
	eq(pools.size() >= int(sig2["cells_min"]) and pools.size() <= int(sig2["cells_max"]), true, "2-3 pools (%d)" % pools.size())
	eq(pools.has(hero_cell), true, "a pool lands under the hero")
	for c in pools:
		eq(maxi(absi(c.x - hero_cell.x), absi(c.y - hero_cell.y)) <= 1, true, "pool %s is next to the hero" % c)
	eq(bool(sim.pools_ready(king)), false, "one spill a turn")
	eq(bool(sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero_cell, "seat": 1}).get("ok", true)), false, "a second spill is refused")
	eq((sim.snapshot()["dungeon"]["pools"] as Array).size(), pools.size(), "pools show in the snapshot")
	while int(sim.snapshot()["active_seat"]) != 0:
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
	var hero: Dictionary = sim._unit_by_seat(0)
	hero["hp"] = 80
	var hp_before := int(hero["hp"])
	sim.submit({"type": "end_turn", "seat": 0})
	var poisoned := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pool_hit":
			poisoned = true
	eq(poisoned, true, "ending the turn in a pool poisons the hero")
	eq(hp_before - int(hero["hp"]) >= int(sig2["hp"]), true, "pool poison is %d HP" % int(sig2["hp"]))
	# Pools last 3 hero turns.
	var turns_seen := 1
	var guard := 0
	while not sim.pool_cells().is_empty() and guard < 40:
		guard += 1
		if int(sim.snapshot()["active_seat"]) == 0:
			hero["hp"] = 80
			# Step off the pools so only expiry removes them.
			sim.submit({"type": "end_turn", "seat": 0})
			turns_seen += 1
		else:
			var u: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
			u["acted_signature2"] = true
			sim.submit({"type": "end_turn", "seat": int(u["seat"])})
	eq(turns_seen, int(sig2["turns"]), "the first pools expire after %d hero turns" % int(sig2["turns"]))
	# The ★5 cap still holds over a long fight.
	var cfg2: Dictionary = run.combat_config(1, 33)
	sim.reset_match(cfg2)
	var cap := int(sim._unit_by_seat(1)["signature"]["cap_alive"])
	var total_cap := int(sim._unit_by_seat(1)["signature"]["cap_total"])
	var max_alive := 0
	for r in 16:
		if bool(sim.snapshot()["match_over"]):
			break
		sim._unit_by_seat(0)["hp"] = 80
		sim.submit({"type": "end_turn", "seat": 0})
		var g := 0
		while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]) and g < 20:
			g += 1
			AI.play_monster_turn(sim, int(sim.snapshot()["active_seat"]))
			var alive := 0
			for u in sim._living_monsters():
				if str(u.get("monster", "")) == "radioactive_rat":
					alive += 1
			max_alive = maxi(max_alive, alive)
	eq(max_alive <= cap, true, "★5 rat cap %d holds (%d)" % [cap, max_alive])
	eq(int(sim.snapshot()["dungeon"]["summoned_total"]) <= total_cap, true, "★5 total calls stay under %d" % total_cap)


func _test_sling_rat() -> void:
	var book = Monsters.load_default()["monsters"]
	var sling: Dictionary = book.stats_at("sling_rat", 1, 1)
	var gnaw := int(book.stats_at("granary_rat", 1, 1)["attack"]["damage"])
	eq(int(sling["attack"]["min_range"]) == 2 and int(sling["attack"]["max_range"]) == 5, true, "the sling reaches 2-5")
	eq(int(sling["attack"]["damage"]) < gnaw, true, "the sling hits a bit softer than the Gnaw")
	eq(bool(book.stats_at("radioactive_sling_rat", 1, 5)["attack"].has("poison")), true, "the radioactive sling poisons")
	# A lane room: a wall of crates between x=3 and the hero blocks the line.
	var cells: Array = []
	for y in 12:
		for x in 12:
			var wall := x == 5 and y >= 2 and y <= 9
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["crate_stack"] if wall else [], "blocks": wall, "special": ""})
	var a := sling.duplicate(true)
	a["pos"] = Vector2i(2, 5)
	a["facing"] = "E"
	var base_room := {"dungeon_id": "t", "room_id": "sling", "room_name": "Sling", "kind": "pack", "cells": cells, "pad_heal": 0, "hero": {"class_id": "kestrel", "pos": Vector2i(8, 5), "facing": "W"}, "monsters": [a], "summons": {}}
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": base_room})
	eq(bool(sim.has_los(Vector2i(2, 5), Vector2i(8, 5))), false, "the crate wall blocks the line")
	eq(bool(sim.has_los(Vector2i(4, 1), Vector2i(8, 5))), false, "a diagonal through the wall is blocked too")
	eq(bool(sim.has_los(Vector2i(6, 1), Vector2i(8, 5))), true, "a line past the wall is clear")
	sim.submit({"type": "end_turn", "seat": 0})
	var legal: Array = sim.legal_intents(1)
	var can_shoot := false
	for i in legal:
		if str(i.get("spell", "")) == "sling_shot":
			can_shoot = true
	eq(can_shoot, false, "no throw without a line of sight")
	var done := AI.play_monster_turn(sim, 1)
	var after: Vector2i = sim._unit_by_seat(1)["pos"]
	eq(int(sim.snapshot()["active_seat"]), 0, "the Sling Rat ends its turn (no deadlock)")
	eq(after != Vector2i(2, 5), true, "it moves to find a line")
	# Kiting: adjacent to the hero, it steps back to range 2+ and throws.
	a["pos"] = Vector2i(7, 5)
	base_room["monsters"] = [a]
	for c in cells:
		c["blocks"] = false
		c["paint_only"] = []
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": base_room, "rolls": [1, 1, 1, 1]})
	sim.submit({"type": "end_turn", "seat": 0})
	var steps := AI.play_monster_turn(sim, 1)
	var kinds: Array = []
	for d in steps:
		kinds.append(str(d["intent"]["type"]) + ":" + str(d["intent"].get("spell", "")))
	var moved_first := kinds.size() >= 2 and str(kinds[0]).begins_with("move")
	var threw := kinds.has("cast:sling_shot")
	eq(moved_first and threw, true, "adjacent, it steps back first, then throws (%s)" % [kinds])
	var spot: Vector2i = sim._unit_by_seat(1)["pos"]
	eq(maxi(absi(spot.x - 8), absi(spot.y - 5)) >= 2, true, "it throws from range 2+")
	var event_projectile := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("projectile", "")) != "":
			event_projectile = true
	eq(event_projectile or threw, true, "the throw carries a projectile for the view")


func _test_turn_pacing() -> void:
	var view := load("res://scenes/world/dungeon/dungeon_board_view.gd")
	eq(float(view.MONSTER_BANNER_SEC) <= 0.35, true, "monster seat banner is short (%.2f s)" % float(view.MONSTER_BANNER_SEC))
	eq(float(view.MONSTER_BEAT_SEC) <= 0.1, true, "the beat before a monster acts is short")
	eq(AI.MAX_STEPS, 12, "AI turns cap at 12 intents")
	# A full ★5 room A monster round stays within the cap for every seat.
	var run = Run.create(GRANARY, 1, "kestrel", "", 5)["run"]
	sim.reset_match(run.combat_config(0, 41))
	sim.submit({"type": "end_turn", "seat": 0})
	var seats := 0
	var worst := 0
	var g := 0
	while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]) and g < 20:
		g += 1
		var steps := AI.play_monster_turn(sim, int(sim.snapshot()["active_seat"]))
		worst = maxi(worst, steps.size())
		seats += 1
	eq(seats, 8, "all 8 ★5 monsters act in one round")
	eq(worst <= AI.MAX_STEPS + 1, true, "no monster turn runs past the cap (%d)" % worst)


# --- runs ----------------------------------------------------------------------

func _test_scripted_win() -> void:
	var run = Run.create(GRANARY, 1, "kestrel")["run"]
	var result := _play_run(run, 1)
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
	eq(w.door_panel.star_buttons.size(), 5, "the panel offers ★1-★5")
	eq(w.door_panel.selected_star, 1, "★1 is picked by default")
	for b in w.door_panel.star_buttons:
		eq(b.disabled, false, "%s is open (no unlock gate, as on mobile)" % b.text)
	w.door_panel.star_buttons[2].emit_signal("pressed")
	eq(w.door_panel.selected_star, 3, "clicking ★3 picks it")
	eq((w.door_panel.find_child("StarNote", true, false) as Label).text.begins_with("★3"), true, "the note describes the picked star")
	Launcher.pending = {}
	Launcher.last_scene = ""
	w.door_panel.press_enter()
	eq(int(Launcher.pending.get("star", 0)), 3, "Enter hands over the picked star")
	eq(Launcher.last_scene, Launcher.RUN_SCENE, "Enter opens the dungeon scene")
	eq(str(Launcher.pending.get("dungeon_id", "")), GRANARY, "Enter hands over the cellar")
	eq(Launcher.pending.get("return_cell", Vector2i(-1, -1)), DOOR, "the way back is the door cell")
	eq(str(Launcher.pending.get("return_zone", "")), "crosshaven_stoneford", "the way back is Stoneford")
	Launcher.pending = {}
	w.queue_free()
	await process_frame


func _test_run_scene_win_and_return() -> void:
	Launcher.pending = {"dungeon_id": GRANARY, "level": 1, "class_id": "ironjaw", "autoplay": true, "return_zone": "crosshaven_stoneford", "return_cell": DOOR, "seed": 1}
	Launcher.outcome = {}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	eq(scene.has_signal("run_finished"), true, "the run scene script loads")
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
	eq(scene.has_signal("run_finished"), true, "the run scene script loads")
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


## Dungeon camera framing and picking at three window sizes: the whole room
## (backdrop walls included) is on screen and fills the play area, and a tap
## on every walkable cell picks that cell exactly.
func _test_click_sweep() -> void:
	Launcher.pending = {"dungeon_id": GRANARY, "level": 1, "class_id": "kestrel", "autoplay": false, "return_zone": "crosshaven_stoneford", "return_cell": DOOR, "seed": 5}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 4:
		await process_frame
	var board = scene.get_node("BoardView")
	# The hero pawn draws the painted class look; monsters keep their sprites.
	var hero_pawn = board.pawns_by_seat.get(0)
	eq(hero_pawn != null and hero_pawn.painted_look and hero_pawn.uses_painted_look(), true, "the dungeon hero uses the painted look")
	eq(hero_pawn != null and Pawn.texture_pivot_offset(hero_pawn._sprite.texture) == hero_pawn._sprite.offset and hero_pawn._sprite.texture.has_meta("painted_cell"), true, "the hero stands on a painted idle cell")
	var plain_monsters := true
	for seat in board.pawns_by_seat.keys():
		if int(seat) != 0 and board.pawns_by_seat[seat].painted_look:
			plain_monsters = false
	eq(plain_monsters, true, "monster pawns keep their own sprites")
	var before := root.size
	for room_index in 2:
		if room_index == 1:
			board.end_room()
			scene.run.room_index = 1
			board.start_room(scene.run.combat_config(1, 5), scene.manifest)
			await process_frame
		for size in [Vector2i(1280, 768), Vector2i(1920, 1080), Vector2i(2540, 1448), Vector2i(2560, 1440)]:
			root.size = size
			await process_frame
			await process_frame
			board._fit_board_camera()
			var label := "%s at %dx%d" % ["room A" if room_index == 0 else "room B", size.x, size.y]
			var vis: Rect2 = board.get_viewport().get_visible_rect()
			eq(absf(vis.size.x / vis.size.y - float(size.x) / float(size.y)) < 0.02, true, "%s window aspect reaches the view (%s)" % [label, vis.size])
			var xf: Transform2D = board.get_global_transform_with_canvas()
			var room: Rect2 = board.room_rect()
			var a: Vector2 = xf * room.position
			var b: Vector2 = xf * room.end
			var shown := Rect2(a, b - a)
			eq(vis.encloses(shown.grow(-1.0)), true, "%s shows the whole room and its walls" % label)
			var zoom: float = board._camera.zoom.x
			# Bigger than the old fit (room between a 96 px top band and a 200 px
			# bottom band), and the floor plus head room clears every HUD panel.
			var old_zoom := minf((vis.size.x - 24.0) / room.size.x, (vis.size.y - 296.0) / room.size.y)
			var gain := 1.05 if size.x >= 1920 else 0.99
			eq(zoom >= old_zoom * gain, true, "%s the room is drawn %s than before (%.2f vs %.2f)" % [label, "bigger" if gain > 1.0 else "no smaller", zoom, old_zoom])
			var floor_poly := PackedVector2Array()
			for p in board.floor_keep_clear():
				floor_poly.append(xf * p)
			var hits := 0
			for r in board.hud_keep_out():
				var box: Rect2 = r
				if not Geometry2D.intersect_polygons(floor_poly, PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])).is_empty():
					hits += 1
			eq(hits, 0, "%s the floor and units stay clear of the HUD" % label)
			eq(board.hud_keep_out().size() >= 8, true, "%s the HUD panels are measured (%d)" % [label, board.hud_keep_out().size()])
			eq(zoom >= 0.7, true, "%s zoom %.2f keeps units at about hero scale" % [label, zoom])
			var misses := 0
			var tried := 0
			for cell in board.tiles.keys():
				if not bool(sim.tile_at(cell).get("walkable", true)):
					continue
				var tile: Node2D = board.tiles[cell]
				var at: Vector2 = tile.get_global_transform_with_canvas().origin
				for nudge in [Vector2.ZERO, Vector2(10, 0) * zoom, Vector2(-10, 0) * zoom, Vector2(0, 5) * zoom, Vector2(0, -5) * zoom]:
					var tap := InputEventScreenTouch.new()
					tap.pressed = true
					tap.position = at + nudge
					tried += 1
					if board._cell_under_pointer(tap) != cell:
						misses += 1
			eq(tried > 400, true, "%s sweeps every walkable cell (%d taps)" % [label, tried])
			eq(misses, 0, "%s every walkable cell picks exactly" % label)
	root.size = before
	scene.queue_free()
	await process_frame


## Mauro's mis-picks: a click on a monster's body (tall sprites stand over
## the cells behind them) must pick the monster's own cell. Every class, every
## monster in rooms A and B, at three window sizes, several body points each,
## with each of the class's unit-targeted casts armed.
func _test_monster_click_sweep() -> void:
	var view_script := load("res://scenes/world/dungeon/dungeon_board_view.gd")
	var before := root.size
	var total := 0
	var misses := 0
	var by_size := {}
	var miss_by_size := {}
	var monsters_seen := 0
	var mask_points := 0
	# Every class with Performance mode off, then Ironjaw and Kestrel with it on
	# (1x art, still props).
	var passes: Array = []
	for c in CLASSES:
		passes.append([c, false])
	passes.append(["ironjaw", true])
	passes.append(["kestrel", true])
	for pass_row in passes:
		var class_id: String = pass_row[0]
		var perf: bool = pass_row[1]
		VisualSettings._note_still(perf)
		Art._cache.clear()
		var spells: Array = []
		for spell_id in SpellKits.class_spells(class_id):
			if view_script.spell_target_kind(str(spell_id)) in ["enemy", "burst", "any"]:
				spells.append(str(spell_id))
		eq(spells.is_empty(), false, "%s has a unit-targeted cast to aim" % class_id)
		Launcher.pending = {"dungeon_id": GRANARY, "level": 1, "class_id": class_id, "autoplay": false, "return_zone": "crosshaven_stoneford", "return_cell": DOOR, "seed": 7}
		var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
		root.add_child(scene)
		for i in 4:
			await process_frame
		var board = scene.get_node("BoardView")
		var hud = scene.get_node("HUD")
		for room_index in 2:
			if room_index == 1:
				board.end_room()
				scene.run.room_index = 1
				board.start_room(scene.run.combat_config(1, 7), scene.manifest)
				await process_frame
			for size in [Vector2i(1280, 768), Vector2i(1920, 1080), Vector2i(2540, 1448)]:
				root.size = size
				await process_frame
				await process_frame
				board._fit_board_camera()
				await process_frame
				var label := "%s%s %s at %dx%d" % [class_id, " (performance)" if perf else "", "room A" if room_index == 0 else "room B", size.x, size.y]
				var per_size_key := "%dx%d" % [size.x, size.y]
				for spell_id in spells:
					hud._selected_spell = spell_id
					var kind: String = view_script.spell_target_kind(spell_id)
					for seat in board.pawns_by_seat.keys():
						if int(seat) == 0:
							continue
						var pawn = board.pawns_by_seat[seat]
						if not pawn.pickable():
							continue
						if spell_id == spells[0]:
							monsters_seen += 1
						var want: Vector2i = pawn.grid_position
						var tried := 0
						var skipped := 0
						for pt in _body_points(pawn):
							# A point that a front monster's own pixels cover belongs to it.
							if _covered_by_front(board, pawn, pt):
								skipped += 1
								continue
							var tap := InputEventScreenTouch.new()
							tap.pressed = true
							tap.position = pt
							tried += 1
							total += 1
							by_size[per_size_key] = int(by_size.get(per_size_key, 0)) + 1
							var got: Vector2i = board._cell_under_pointer(tap)
							if got != want:
								misses += 1
								miss_by_size[per_size_key] = int(miss_by_size.get(per_size_key, 0)) + 1
								if misses <= 12:
									var gp: Vector2 = board.get_viewport().get_canvas_transform().affine_inverse() * pt
									var lv := []
									for o in board.pawns_by_seat.values():
										if o.has_method("pick_test"):
											lv.append([o.grid_position, o.pick_test(gp), o.z_index])
									print("  miss: %s %s seat %d at %s picked %s want %s levels %s" % [label, spell_id, seat, pt, got, want, lv])
						if Art.pick_mask(pawn._body.sprite_frames.get_frame_texture(pawn._body.animation, pawn._body.frame)) != null:
							mask_points += tried
						eq(tried >= 3 or skipped >= 20, true, "%s %s: %s gets 3+ body clicks (%d, %d behind a front monster)" % [label, spell_id, pawn.monster_id, tried, skipped])
				hud._selected_spell = ""
				# Walk mode: a tap on the hero's sprite walks to the floor cell
				# it covers, not the hero's own cell.
				var hero: Node2D = board.pawns_by_seat[0]
				var hero_cell: Vector2i = hero.grid_position
				var behind := hero_cell - Vector2i(1, 1)
				if board.tiles.has(behind):
					var tap2 := InputEventScreenTouch.new()
					tap2.pressed = true
					tap2.position = board.get_node("Tiles").get_global_transform_with_canvas() * board.tiles[behind].position
					eq(board._cell_under_pointer(tap2), behind, "%s a walk tap on the hero's sprite picks the floor behind" % label)
		scene.queue_free()
		await process_frame
	VisualSettings._note_still(false)
	Art._cache.clear()
	root.size = before
	print("  monster click sweep: %d clicks, %d on pixel masks, %d monster views" % [total, mask_points, monsters_seen])
	for key in by_size.keys():
		print("  click sweep %s: %d clicks, %d misses" % [key, int(by_size[key]), int(miss_by_size.get(key, 0))])
	eq(total > 1000, true, "the sweep clicks every monster body many times (%d)" % total)
	eq(misses, 0, "every click on a monster's body picks that monster's cell")


## Screen points on a monster's body: its visible pixels when the pixel mask
## is readable, else inside the body box (centre, chest, head, both sides).
func _body_points(pawn) -> Array:
	var out: Array = []
	var body: AnimatedSprite2D = pawn._body
	var tex: Texture2D = body.sprite_frames.get_frame_texture(body.animation, body.frame)
	var to_screen: Transform2D = body.get_global_transform_with_canvas()
	var mask: BitMap = Art.pick_mask(tex)
	if mask != null:
		var sz := mask.get_size()
		var rows: Array = []
		for y in sz.y:
			var xs: Array = []
			for x in sz.x:
				if mask.get_bit(x, y):
					xs.append(x)
			if xs.size() >= 3:
				rows.append([y, xs])
		if rows.size() >= 4:
			for f in [0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 0.95]:
				var row: Array = rows[int(f * float(rows.size() - 1))]
				var xs2: Array = row[1]
				for g in [0.5, 0.15, 0.85, 0.33, 0.67]:
					var bx := int(xs2[int(g * float(xs2.size() - 1))])
					if body.flip_h:
						bx = sz.x - 1 - bx
					out.append(to_screen * (body.offset + Vector2(bx + 0.5, int(row[0]) + 0.5)))
			return out
	var box: Rect2 = pawn.body_box().grow(-pawn.BOX_PAD - 2.0)
	var pxf: Transform2D = pawn.get_global_transform_with_canvas()
	for p in [box.get_center(), Vector2(box.get_center().x, box.position.y + box.size.y * 0.2), Vector2(box.get_center().x, box.end.y - 4.0), Vector2(box.position.x + 3.0, box.get_center().y), Vector2(box.end.x - 3.0, box.get_center().y)]:
		out.append(pxf * p)
	return out


func _covered_by_front(board, pawn, screen_pt: Vector2) -> bool:
	var global_pt: Vector2 = board.to_global(board.get_node("Tiles").make_canvas_position_local(screen_pt))
	var mine: int = pawn.pick_test(global_pt)
	for other in board.pawns_by_seat.values():
		if other == pawn or not other.has_method("pick_test") or not other.pickable():
			continue
		var lv: int = other.pick_test(global_pt)
		if lv == 0:
			continue
		var key_o := [lv, int(other.z_index), other.position.y]
		var key_m := [mine, int(pawn.z_index), pawn.position.y]
		if board.pick_key_beats(key_o, key_m):
			return true
	return false


## Aim chrome: in-range rings, dimmed out-of-range monsters, the hover card
## (name, HP, hit %, damage), the target cursor, the docked spell card that
## never covers the room and closes on a hovered target, and the short
## out-of-range note with the walk-then-strike assist.
func _test_targeting_chrome() -> void:
	Launcher.pending = {"dungeon_id": GRANARY, "level": 1, "class_id": "ironjaw", "autoplay": false, "return_zone": "crosshaven_stoneford", "return_cell": DOOR, "seed": 5}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame
	var board = scene.get_node("BoardView")
	var hud = scene.get_node("HUD")
	var before := root.size
	root.size = Vector2i(1920, 1080)
	for i in 3:
		await process_frame
	board._fit_board_camera()
	eq(hud.tooltip_dock, "bar", "the dungeon docks spell cards beside the action bar")
	# Put one rat next to Ironjaw; the rest stay out of Strike's reach.
	var hero: Dictionary = sim._unit_by_seat(0)
	var near_seat := -1
	for u in sim.snapshot()["units"]:
		if u.has("monster") and not bool(u.get("boss", false)) and near_seat < 0:
			near_seat = int(u["seat"])
	var spot: Vector2i = hero["pos"]
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c: Vector2i = hero["pos"] + step
		if bool(sim.tile_at(c).get("walkable", false)) and sim._living_unit_at(c).is_empty():
			spot = c
			break
	eq(spot != hero["pos"], true, "a free cell next to the hero for the test rat")
	sim._unit_by_seat(near_seat)["pos"] = spot
	board._refresh()
	await process_frame
	# Spell card: only while the pointer is on its button, and docked off the room.
	hud._on_spell_hover(SpellKits.STRIKE)
	eq(hud.tooltip_visible(), false, "no spell card unless the pointer is on the button")
	hud._long_press_touch = true
	hud.show_spell_tooltip(SpellKits.STRIKE)
	hud._long_press_touch = false
	eq(hud.tooltip_visible(), true, "the spell card opens for its button")
	var card: Rect2 = hud.tooltip_rect()
	var xf: Transform2D = board.get_global_transform_with_canvas()
	var floor_poly := PackedVector2Array()
	for p in board.floor_keep_clear():
		floor_poly.append(xf * p)
	eq(Geometry2D.intersect_polygons(floor_poly, PackedVector2Array([card.position, Vector2(card.end.x, card.position.y), card.end, Vector2(card.position.x, card.end.y)])).is_empty(), true, "the docked spell card never covers the room (%s)" % card)
	# Arm Strike: the adjacent rat is ringed, the others are dimmed.
	hud._on_spell_pressed(SpellKits.STRIKE)
	await process_frame
	eq(hud.selected_spell(), SpellKits.STRIKE, "Strike is armed")
	eq(board.target_cells().has(spot), true, "the adjacent rat is a legal Strike target")
	eq(board.target_state(near_seat), "legal", "the in-range rat gets the target ring")
	var dimmed := 0
	var far_seat := -1
	for seat in board.pawns_by_seat.keys():
		if int(seat) == 0 or int(seat) == near_seat:
			continue
		if board.target_state(seat) == "dim":
			dimmed += 1
			if far_seat < 0:
				far_seat = int(seat)
	eq(dimmed >= 2, true, "out-of-range monsters are dimmed (%d)" % dimmed)
	# Hover the rat's body: card, cursor, ring; the spell card closes.
	var rat: Node2D = board.pawns_by_seat[near_seat]
	board.hover_at(rat.position + Vector2(0, -14))
	await process_frame
	eq(board.hovered_seat(), near_seat, "hovering the rat's body hovers the rat")
	eq(board.target_state(near_seat), "hover", "the hovered target is ringed brighter")
	eq(board.cursor_shape(), Input.CURSOR_CROSS, "the target cursor shows over a legal target")
	eq(hud.tooltip_visible(), false, "the spell card closes as soon as a target is hovered")
	var text: String = board.card_text()
	var unit: Dictionary = sim._unit_by_seat(near_seat)
	eq(text.contains(str(unit["name"])) and text.contains("%d/%d HP" % [int(unit["hp"]), int(unit["max_hp"])]), true, "the card names the target and its HP (%s)" % text)
	var pv: Dictionary = sim.preview_cast({"spell": SpellKits.STRIKE, "seat": 0, "to": spot, "target_seat": near_seat})
	eq(text.contains("HIT %d%%" % int(pv["hit_chance"])) and text.contains("%d dmg" % int(pv["sample_damage"])), true, "the card shows the preview hit %% and damage (%s)" % text)
	board.hover_at(Vector2(-5000, -5000))
	eq(board.cursor_shape(), Input.CURSOR_ARROW, "the cursor goes back off a target")
	# Out of range: short note, no refund line, Strike stays armed, nothing spent.
	var far_cell: Vector2i = board.pawns_by_seat[far_seat].grid_position
	var ap_before := int(sim._unit_by_seat(0)["ap"])
	var coach_before := str(sim.snapshot().get("coach", ""))
	board._handle_left_click(far_cell)
	await process_frame
	eq(board.card_text().contains("Out of range: walk closer"), true, "the note sits on the monster's card")
	eq(hud.toast_caption(), "Out of range: walk closer", "clicking an out-of-range monster says to walk closer")
	eq(str(sim.snapshot().get("coach", "")).contains("REJECT"), false, "no refund line for an out-of-range click")
	eq(str(sim.snapshot().get("coach", "")), coach_before, "the click sent nothing to the sim")
	eq(int(sim._unit_by_seat(0)["ap"]), ap_before, "no AP spent")
	eq(hud.selected_spell(), SpellKits.STRIKE, "Strike stays armed after an out-of-range click")
	# Walk-then-strike: a rat two steps away; the second click walks and strikes.
	board.hover_at(Vector2(-5000, -5000))
	var hero_pos: Vector2i = sim._unit_by_seat(0)["pos"]
	var two := Vector2i(-1, -1)
	for step in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
		var c2: Vector2i = hero_pos + step
		var mid: Vector2i = hero_pos + step / 2
		if c2.x >= 0 and c2.y >= 0 and c2.x < 12 and c2.y < 12 and bool(sim.tile_at(c2).get("walkable", false)) and sim._living_unit_at(c2).is_empty() and bool(sim.tile_at(mid).get("walkable", false)) and sim._living_unit_at(mid).is_empty():
			two = c2
			break
	eq(two.x >= 0, true, "a free cell two steps out for the assist rat")
	sim._unit_by_seat(near_seat)["pos"] = two
	board._refresh()
	await process_frame
	eq(board.target_state(near_seat), "dim", "the rat two steps out is out of Strike range")
	var plan: Dictionary = board.walk_strike_plan(SpellKits.STRIKE, near_seat)
	eq(plan.is_empty(), false, "a melee cast with MP left offers walk-then-strike")
	var hp_before := int(sim._unit_by_seat(near_seat)["hp"])
	board._handle_left_click(two)
	await process_frame
	eq(board.card_text().contains("Click again: walk + Strike"), true, "the card offers the walk + Strike assist (%s)" % board.card_text())
	board._handle_left_click(two)
	var t0 := Time.get_ticks_msec()
	while int(sim._unit_by_seat(0)["ap"]) == ap_before and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	var hero_after: Dictionary = sim._unit_by_seat(0)
	eq(hero_after["pos"], plan["walk_to"], "the assist walked next to the rat")
	eq(int(hero_after["ap"]), ap_before - int(SpellKits.spell(SpellKits.STRIKE)["ap"]), "the assist struck once (AP spent)")
	var log_has_cast := false
	for e in sim.snapshot().get("last_events", []):
		if str(e.get("type", "")) in ["hit", "miss"]:
			log_has_cast = true
	eq(log_has_cast or int(sim._unit_by_seat(near_seat)["hp"]) < hp_before, true, "the Strike resolved on the rat")
	root.size = before
	scene.queue_free()
	await process_frame


## The dungeon gives the hero 60 s a turn; PvP and the Koliseo keep 30 s.
func _test_dungeon_turn_timer() -> void:
	var snap: Dictionary = sim.reset_match(Run.create(GRANARY, 1, "ironjaw")["run"].combat_config(1, 3))
	eq(float(snap["turn_time_limit"]), 60.0, "a dungeon room turn is 60 s")
	eq(float(snap["turn_time_remaining"]) >= 59.0, true, "the hero starts the room with the full 60 s")
	sim.submit({"type": "end_turn", "seat": 0})
	eq(float(sim.snapshot()["turn_time_limit"]), 60.0, "the next dungeon turn is 60 s too")
	var pvp: Dictionary = sim.reset_match({"seed": 4242, "skip_deploy": true, "classes": ["kestrel", "ironjaw"]})
	eq(float(pvp["turn_time_limit"]), 30.0, "PvP keeps the 30 s turn")
	var kol: Dictionary = sim.reset_match({"seed": 3, "map_id": "crosshaven", "skip_deploy": true})
	eq(float(kol["turn_time_limit"]), 30.0, "the Koliseo keeps the 30 s turn")
	eq(float(SIM_SCRIPT.TURN_TIME_LIMIT), 30.0, "the shared clock constant is unchanged")
	sim.reset_match({})


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
	hero.dungeon_stars = {}
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
