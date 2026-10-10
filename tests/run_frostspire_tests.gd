extends SceneTree

## PC dungeon 2, the Frostspire Archive (Northgate, levels 10-20): the door
## and its building in Northgate, the run file and rooms (every cell
## reachable, shelves break the Book Wraiths' lines), pack sizes per star,
## the AI always ending its turn, Book Wraith line of sight and kiting, the
## Pale Archivist's Unbound Pages and its shared cap, the ★5 Frozen
## Archivist and his frost patches (damage, MP loss, thawing pads), chill,
## rewards per star, a full run in the room scene, and guards that the Old
## Granary Cellar still plays exactly as before.
## Run: godot --headless --path . -s res://tests/run_frostspire_tests.gd

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
const FROST := "frostspire_archive"
const GRANARY := "old_granary_cellar"
const ZONE := "crosshaven_northgate"
const DOOR := Vector2i(21, 10)
const KEEPER := Vector2i(20, 10)
const LEVEL := 12
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
	_test_door_data()
	_test_run_file_and_rooms()
	_test_monsters()
	_test_packs_per_star()
	_test_ai_always_ends()
	_test_wraith_los_and_kiting()
	_test_signature_cap()
	_test_boss_scatter()
	_test_star5_frost_patches()
	_test_chill_and_thaw()
	_test_rewards_per_star()
	_test_mission_credit()
	_test_granary_unchanged()
	await _test_world_door_and_panel()
	await _test_run_scene_win_and_return()
	_finish()


func _finish() -> void:
	print("frostspire tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- door ------------------------------------------------------------------------

func _test_door_data() -> void:
	var loaded: Dictionary = Dungeons.load_default()
	eq(bool(loaded.get("ok", false)), true, "dungeons.json loads: %s" % [loaded.get("errors", [])])
	var book = loaded["dungeons"]
	var row: Dictionary = book.by_id(FROST)
	eq(str(row.get("status", "")), "built", "the Frostspire Archive is built")
	eq(str(row["level_zone"]), "northgate", "it is Northgate's dungeon")
	eq([int(row["level_min"]), int(row["level_max"])], [10, 20], "levels 10-20")
	eq(str(row["boss"]), "The Pale Archivist", "the boss is the Pale Archivist")
	eq(Dungeons.door_cell(row), DOOR, "the archive door is at 21,10")
	eq(str(row["door"]["zone_id"]), ZONE, "the door is in the Northgate chunk")
	eq(str(row["run"]), "res://data/world/dungeons/frostspire_archive/run.json", "the run file is named")
	var shape: Dictionary = Dungeons.building_shape(row)
	eq(shape.get("size", Vector2i.ZERO), Vector2i(3, 3), "the building is 3x3 (manifest footprint)")
	eq(shape.get("door_from_nw", Vector2i.ZERO), Vector2i(2, 3), "the door is at the footprint's (2,3), in front of the steps")
	var building := Dungeons.building_cells_for(row)
	eq(building.size(), 9, "nine building cells")
	eq(building.has(DOOR + Vector2i(0, -1)), true, "the steps cell is just north of the door")
	for c in building:
		eq(c.x >= 19 and c.x <= 21 and c.y >= 7 and c.y <= 9, true, "building cell %s on 19-21 x 7-9" % c)
	var granary_row: Dictionary = book.by_id(GRANARY)
	eq(Dungeons.building_cells_for(granary_row), Dungeons.building_cells(granary_row, Vector2i(3, 3)), "the granary keeps its centred 3x3 footprint")
	var atlas = Atlas.load_default()["atlas"]
	var npcs = NpcBook.load_default()["npcs"]
	var checked: Dictionary = book.validate_world(atlas, npcs, Art.building_size(Art.manifest(_granary_art()), Dungeons.DEFAULT_BUILDING))
	eq(bool(checked["ok"]), true, "4.6 rules hold with both doors: %s" % [checked["errors"]])
	var zone: WorldZone = atlas.map_for_chunk(ZONE).zone(ZONE)
	eq(zone.passable_at(DOOR), true, "the door cell is passable")
	eq(zone.exit_link(DOOR).is_empty(), true, "the door is not an exit")
	eq(atlas.gate_at(ZONE, DOOR).is_empty(), true, "the door is not a gate")
	eq(DOOR != zone.spawn, true, "the door is not the spawn")
	for npc in npcs.for_zone(ZONE):
		var at := Vector2i(int(npc["cell"]["x"]), int(npc["cell"]["y"]))
		eq(at != DOOR and not building.has(at), true, "%s is not on the door or the building" % npc["id"])
	var keeper: Dictionary = npcs.by_id("northgate_door_keeper")
	eq(str(keeper["role"]), "door_keeper", "the Northgate Door Keeper is a door keeper")
	eq(Vector2i(int(keeper["cell"]["x"]), int(keeper["cell"]["y"])), KEEPER, "the Door Keeper stands beside the door (origin+(1,3))")
	eq(book.for_keeper("northgate_door_keeper").get("id", ""), FROST, "the keeper opens the archive")
	eq(str((keeper["lines"] as Array).back()).contains("Archivist"), true, "the keeper warns of the Archivist")
	# A door moved onto the keeper or out of Northgate fails.
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Dungeons.PATH))
	var on_npc: Dictionary = base.duplicate(true)
	(on_npc["dungeons"] as Array)[1]["door"] = {"zone_id": ZONE, "x": KEEPER.x, "y": KEEPER.y}
	eq(bool(Dungeons.load_document(on_npc)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "an archive door on the keeper fails")
	var away: Dictionary = base.duplicate(true)
	(away["dungeons"] as Array)[1]["door"] = {"zone_id": "crosshaven_stoneford", "x": 20, "y": 16}
	eq(bool(Dungeons.load_document(away)["dungeons"].validate_world(atlas, npcs)["ok"]), false, "an archive door outside Northgate fails")


# --- run file and rooms --------------------------------------------------------

func _test_run_file_and_rooms() -> void:
	var made: Dictionary = Run.create(FROST, LEVEL, "kestrel")
	eq(bool(made.get("ok", false)), true, "the archive run builds: %s" % [made.get("errors", [])])
	if not bool(made.get("ok", false)):
		return
	var run = made["run"]
	eq(run.level, LEVEL, "a level 12 hero runs at level 12")
	eq(int(Run.create(FROST, 30, "kestrel")["run"].level), 20, "an over-band hero meets level 20 monsters")
	eq(run.room_count(), 2, "room A then room B")
	eq([str(run.room(0)["kind"]), str(run.room(1)["kind"])], ["pack", "boss"], "a pack room, then the boss")
	eq(str(run.run_doc["art"]), "res://art/pc/dungeons/frostspire_archive/manifest.json", "the art manifest is the archive kit")
	eq(Art.manifest(str(run.run_doc["art"]))["ok"], true, "the archive art manifest loads")
	eq(str(run.text("stairs")).contains("frozen"), true, "the stairs line is the archive's")
	eq(run.text("return_button"), "Return to Northgate", "the return button names Northgate")
	eq(str((run.run_doc["text"] as Dictionary).get("star5_rule", "")).contains("Rime Patches"), true, "the ★5 rule text lives in the run file")
	var man := Art.manifest(str(run.run_doc["art"]))
	var kit_props := {}
	for row in (man["raw"]["board"]["props"] as Array):
		kit_props[str(row["id"])] = row
	for index in 2:
		var config: Dictionary = run.combat_config(index, 3)
		var room: Dictionary = config["dungeon"]
		var label := str(room["room_id"])
		eq(int(config["board_size"]), 12, "%s is 12x12" % label)
		eq(bool(room["pad_thaw"]), true, "%s pads thaw" % label)
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
		eq(blocked >= 6, true, "%s has prop obstacles (%d)" % [label, blocked])
		eq(pads >= 4, true, "%s has rune pads (%d)" % [label, pads])
		var hero: Vector2i = room["hero"]["pos"]
		var seen := _flood(walk, hero, {})
		eq(seen.size(), walk.size(), "%s every walkable cell is reachable" % label)
		sim.reset_match(config)
		var snap: Dictionary = sim.snapshot()
		eq((snap["dungeon"]["pads"] as Array).size(), pads, "%s pads reach the sim" % label)
		for rec in cells:
			if bool(rec["blocks"]):
				eq(bool(sim.tile_at(rec["pos"]).get("walkable", true)), false, "%s prop cell %s blocks" % [label, rec["pos"]])
		# Props break lines of fire: from the far rows, some lines to the hero
		# start are blocked, and every far-row cell still sees some open cell.
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
	for rec in b_cells:
		if (rec["paint_only"] as Array).has("rune_circle"):
			circle += 1
	eq(circle, 9, "room B's rune circle covers 3x3 pad cells")
	var thrones := 0
	for rec in b_cells:
		if str((rec["paint_only"] as Array).front() if not (rec["paint_only"] as Array).is_empty() else "").begins_with("ice_throne"):
			thrones += 1
	eq(thrones, 0, "no throne prop on the board (the room B shell paints it)")


func _test_monsters() -> void:
	var book = Monsters.load_default()["monsters"]
	var ids: Array = book.ids_for(FROST)
	eq(ids, ["ice_construct", "book_wraith", "the_pale_archivist", "frozen_ice_construct", "frozen_book_wraith", "the_frozen_archivist"], "the archive's six monsters")
	for id in ids:
		var lo: Dictionary = book.stats_at(id, 10)
		var hi: Dictionary = book.stats_at(id, 20)
		eq(int(lo["level"]), 10, "%s starts at level 10" % id)
		eq(int(book.stats_at(id, 1)["level"]), 10, "%s clamps up to its band" % id)
		eq(int(hi["hp"]) > int(lo["hp"]), true, "%s grows through 10-20" % id)
		eq(str(lo["dungeon"]), FROST, "%s belongs to the archive" % id)
	var construct: Dictionary = book.stats_at("ice_construct", LEVEL)
	var wraith: Dictionary = book.stats_at("book_wraith", LEVEL)
	var boss: Dictionary = book.stats_at("the_pale_archivist", LEVEL)
	eq(int(construct["mp"]), 2, "the Ice Construct is slow (2 MP)")
	eq(int(construct["hp"]) > int(wraith["hp"]) * 2, true, "the Ice Construct is the tank")
	eq(int(construct["attack"]["max_range"]), 1, "the Ice Construct is melee")
	eq([int(wraith["attack"]["min_range"]), int(wraith["attack"]["max_range"])], [2, 5], "the Book Wraith shoots at 2-5")
	eq(bool(wraith["attack"]["los"]), true, "the Frost Bolt needs a line of sight")
	eq(str(wraith["attack"]["projectile"]), "frost_bolt", "the Frost Bolt flies as frost_bolt")
	eq(str(wraith["attack"]["impact"]), "frost_bolt_impact", "and bursts in frost_bolt_impact")
	eq(bool(boss["boss"]), true, "the Pale Archivist is the boss")
	var sig: Dictionary = boss["signature"]
	eq([str(sig["name"]), str(sig["kind"]), str(sig["summon"])], ["Unbound Pages", "summon", "book_wraith"], "Unbound Pages calls Book Wraiths")
	var frozen: Dictionary = book.stats_at("the_frozen_archivist", LEVEL, 5)
	eq(str(frozen["signature"]["summon"]), "frozen_book_wraith", "the Frozen Archivist calls frozen wraiths")
	eq(int(frozen["signature"]["cap_total"]) > int(sig["cap_total"]), true, "his call is stronger (more wraiths in all)")
	eq(str(frozen["signature2"]["kind"]), "hazard", "his second move lays a ground hazard")
	eq(str(frozen["signature2"]["hazard"]), "frost_patch", "the hazard is frost patches")
	eq(int(frozen["signature2"]["mp_loss"]), 2, "a frost patch costs 2 MP")
	eq(bool(book.stats_at("frozen_book_wraith", LEVEL, 5)["attack"].has("chill")), true, "frozen wraiths chill")
	var check: Dictionary = book.check(LEVEL)
	eq(bool(check["ok"]), true, "level 12 numbers pass the sanity pass: %s" % [check["findings"]])
	var rows: Dictionary = book.stars_for(FROST)["scale"]
	for star in range(1, 6):
		var m: Array = book.star_scale(star, FROST)
		eq(m, [float(rows[str(star)][0]), float(rows[str(star)][1])], "★%d archive row comes from its own star block" % star)
	var prev := 0.0
	for star in range(1, 5):
		var m2: Array = book.star_scale(star, FROST)
		eq(float(m2[0]) >= prev, true, "★%d archive HP row is not softer than the star below" % star)
		prev = float(m2[0])
	var mult: Array = book.star_scale(3, FROST)
	var raw: Dictionary = book.stats_at("book_wraith", LEVEL, 1)
	eq(int(book.stats_at("book_wraith", LEVEL, 3)["hp"]), maxi(int(round(float(raw["hp"]) * float(mult[0]))), 1), "★3 wraith HP is the band HP x the archive's ★3 row")


# --- stars and packs ------------------------------------------------------------

func _test_packs_per_star() -> void:
	var expect := {
		1: {"ice_construct": 2, "book_wraith": 4},
		2: {"ice_construct": 2, "book_wraith": 4},
		3: {"ice_construct": 3, "book_wraith": 4},
		4: {"ice_construct": 3, "book_wraith": 4},
		5: {"frozen_ice_construct": 2, "ice_construct": 1, "frozen_book_wraith": 4, "book_wraith": 1},
	}
	var totals := {1: 6, 2: 6, 3: 7, 4: 7, 5: 8}
	for star in range(1, 6):
		var run = Run.create(FROST, LEVEL, "kestrel", "", star)["run"]
		var room: Dictionary = run.combat_config(0, 1)["dungeon"]
		var got := {}
		var ranged := 0
		for m in room["monsters"]:
			got[str(m["monster"])] = int(got.get(str(m["monster"]), 0)) + 1
			if bool((m["attack"] as Dictionary).get("los", false)):
				ranged += 1
		eq(got, expect[star], "★%d room A pack" % star)
		eq((room["monsters"] as Array).size(), totals[star], "★%d room A has %d monsters (6+)" % [star, totals[star]])
		eq(ranged >= 4, true, "★%d room A has ranged Book Wraiths (%d)" % [star, ranged])
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
		eq(str(mons[0]["monster"]), "the_frozen_archivist" if star == 5 else "the_pale_archivist", "★%d boss form" % star)
		var escort := {}
		for m in mons.slice(1):
			escort[str(m["monster"])] = int(escort.get(str(m["monster"]), 0)) + 1
		var want := {"frozen_book_wraith": 2, "frozen_ice_construct": 1} if star == 5 else {"book_wraith": 2, "ice_construct": 1}
		eq(escort, want, "★%d escort: 2 wraiths and an Ice Construct" % star)
		var sig: Dictionary = mons[0]["signature"]
		eq((boss_room["summons"] as Dictionary).has(str(sig["summon"])), true, "★%d the called wraith's stats ride along" % star)


func _test_ai_always_ends() -> void:
	var stuck := 0
	var unfinished := 0
	var monster_turns := 0
	var shots := 0
	for cls in CLASSES:
		for star in [1, 5]:
			var run = Run.create(FROST, LEVEL, cls, "", star)["run"]
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
						if str(d["intent"].get("spell", "")) in ["wraith_bolt", "frozen_bolt"] and bool(d["ok"]):
							shots += 1
					var after: Dictionary = sim.snapshot()
					if not bool(after["match_over"]) and int(after["active_seat"]) == seat:
						unfinished += 1
				if guard >= limit:
					unfinished += 1
				if str(sim.snapshot()["dungeon"]["result"]) != "win":
					break
	eq(monster_turns > 100, true, "monster turns were played (%d)" % monster_turns)
	eq(shots > 20, true, "Book Wraiths find lines and shoot (%d)" % shots)
	eq(stuck, 0, "no monster turn needed a forced end")
	eq(unfinished, 0, "every monster turn ends and every fight finishes")


func _test_wraith_los_and_kiting() -> void:
	var book = Monsters.load_default()["monsters"]
	var wraith: Dictionary = book.stats_at("book_wraith", LEVEL, 1)
	var spell := str(wraith["attack"]["id"])
	var cells: Array = []
	for y in 12:
		for x in 12:
			var wall := x == 5 and y >= 2 and y <= 9
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["frozen_bookshelf"] if wall else [], "blocks": wall, "special": ""})
	var a := wraith.duplicate(true)
	a["pos"] = Vector2i(2, 5)
	a["facing"] = "E"
	var room := {"dungeon_id": "t", "room_id": "lane", "room_name": "Lane", "kind": "pack", "cells": cells, "pad_heal": 0, "hero": {"class_id": "kestrel", "pos": Vector2i(8, 5), "facing": "W"}, "monsters": [a], "summons": {}}
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room})
	eq(bool(sim.has_los(Vector2i(2, 5), Vector2i(8, 5))), false, "a shelf wall blocks the Frost Bolt's line")
	sim.submit({"type": "end_turn", "seat": 0})
	var can_shoot := false
	for i in sim.legal_intents(1):
		if str(i.get("spell", "")) == spell:
			can_shoot = true
	eq(can_shoot, false, "no bolt without a line of sight")
	AI.play_monster_turn(sim, 1)
	eq(int(sim.snapshot()["active_seat"]), 0, "the wraith ends its turn (no deadlock)")
	eq(sim._unit_by_seat(1)["pos"] != Vector2i(2, 5), true, "it moves to find a line")
	# Kiting: adjacent to the hero it steps back to range 2+, then shoots.
	a["pos"] = Vector2i(7, 5)
	room["monsters"] = [a]
	for c in cells:
		c["blocks"] = false
		c["paint_only"] = []
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room, "rolls": [1, 1, 1, 1]})
	sim.submit({"type": "end_turn", "seat": 0})
	var kinds: Array = []
	var projectile := ""
	for d in AI.play_monster_turn(sim, 1):
		kinds.append(str(d["intent"]["type"]) + ":" + str(d["intent"].get("spell", "")))
	eq(kinds.size() >= 2 and str(kinds[0]).begins_with("move") and kinds.has("cast:" + spell), true, "adjacent, the wraith steps back, then shoots (%s)" % [kinds])
	var spot: Vector2i = sim._unit_by_seat(1)["pos"]
	eq(maxi(absi(spot.x - 8), absi(spot.y - 5)) >= 2, true, "it shoots from range 2+")
	# A bolt in the open: the hit event carries the projectile and its impact.
	a["pos"] = Vector2i(5, 5)
	room["monsters"] = [a]
	sim.reset_match({"board_size": 12, "seed": 2, "dungeon": room, "rolls": [1, 1, 1, 1]})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": spell, "to": Vector2i(8, 5), "target_seat": 0, "seat": 1})
	for e in sim.snapshot()["last_events"]:
		if str(e.get("projectile", "")) != "":
			projectile = str(e["projectile"]) + "/" + str(e.get("impact", ""))
	eq(projectile, "frost_bolt/frost_bolt_impact", "the bolt event names its projectile and impact for the view")


# --- the Pale Archivist ---------------------------------------------------------

func _test_signature_cap() -> void:
	var run = Run.create(FROST, LEVEL, "kestrel")["run"]
	var config: Dictionary = run.combat_config(1, 11)
	var sig: Dictionary = (config["dungeon"]["monsters"][0] as Dictionary)["signature"]
	var kind := str(sig["summon"])
	sim.reset_match(config)
	var max_alive := 0
	var calls_on: Array = []
	var refused := false
	for round_n in 16:
		if bool(sim.snapshot()["match_over"]):
			break
		sim.submit({"type": "end_turn", "seat": 0})
		var guard := 0
		while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]) and guard < 20:
			guard += 1
			var seat := int(sim.snapshot()["active_seat"])
			if seat == 1 and not bool(sim.summon_ready(sim._unit_by_seat(1))):
				var r: Dictionary = sim.submit({"type": "cast", "spell": str(sig["id"]), "to": sim._unit_by_seat(1)["pos"], "seat": 1})
				refused = refused or (not bool(r.get("ok", true)) and str(r.get("reason", "")) == "summon_not_ready")
			for d in AI.play_monster_turn(sim, seat):
				if str(d["intent"].get("spell", "")) == str(sig["id"]) and bool(d["ok"]):
					calls_on.append(int(sim._unit_by_seat(1)["own_turns"]))
			var alive := 0
			for u in sim.snapshot()["units"]:
				if (bool(u.get("summoned", false)) or str(u.get("monster", "")) == kind) and bool(u.get("alive", false)):
					alive += 1
			max_alive = maxi(max_alive, alive)
		sim._unit_by_seat(0)["hp"] = 80
		if round_n % 2 == 1:
			for u in sim._living_monsters():
				if bool(u.get("summoned", false)) or str(u.get("monster", "")) == kind:
					u["hp"] = 0
					u["alive"] = false
	var total := int(sim.snapshot()["dungeon"]["summoned_total"])
	eq(calls_on.is_empty(), false, "the Archivist calls his pages")
	eq(calls_on[0] if not calls_on.is_empty() else -1, int(sig["first_turn"]), "the first call is on his turn %d" % int(sig["first_turn"]))
	for t in calls_on:
		eq((int(t) - int(sig["first_turn"])) % int(sig["every"]), 0, "calls come every %d turns (turn %d)" % [int(sig["every"]), int(t)])
	eq(max_alive <= int(sig["cap_alive"]), true, "never more than %d wraiths alive, escort included (%d)" % [int(sig["cap_alive"]), max_alive])
	eq(total <= int(sig["cap_total"]), true, "never more than %d called in all (%d)" % [int(sig["cap_total"]), total])
	eq(total, int(sig["cap_total"]), "the cap is reached over a long fight")
	eq(refused, true, "an early call is refused")
	# With both escort wraiths alive the shared cap leaves room for one more.
	sim.reset_match(run.combat_config(1, 12))
	var boss: Dictionary = sim._unit_by_seat(1)
	boss["own_turns"] = int(sig["first_turn"]) - 1
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.summon_ready(boss)), true, "the call is ready on his turn %d" % int(sig["first_turn"]))
	sim.submit({"type": "cast", "spell": str(sig["id"]), "to": boss["pos"], "seat": 1})
	var made := 0
	for u in sim.snapshot()["units"]:
		if bool(u.get("summoned", false)):
			made += 1
	eq(made, int(sig["cap_alive"]) - 2, "2 escort wraiths + %d called = the cap of %d" % [made, int(sig["cap_alive"])])
	var ev: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "summon":
			ev = e
	eq(str(ev.get("spell", "")), "archivist_pages", "the summon event names Unbound Pages for the view")


func _test_boss_scatter() -> void:
	var run = Run.create(FROST, LEVEL, "ironjaw")["run"]
	var config: Dictionary = run.combat_config(1, 21)
	config["rolls"] = []
	for i in 80:
		config["rolls"].append(1)
	sim.reset_match(config)
	var boss: Dictionary = sim._unit_by_seat(1)
	boss["pos"] = Vector2i(6, 9)
	boss["own_turns"] = 1
	# Make room under the cap so he can call: one escort wraith is down.
	sim._unit_by_seat(2)["hp"] = 0
	sim._unit_by_seat(2)["alive"] = false
	sim.submit({"type": "end_turn", "seat": 0})
	var spell := str((boss["signature"] as Dictionary)["id"])
	eq(bool(sim.submit({"type": "cast", "spell": spell, "to": boss["pos"], "seat": 1}).get("ok", false)), true, "the Archivist calls on his second turn")
	while int(sim.snapshot()["active_seat"]) != 0:
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
	boss["hp"] = 4
	var guard := 0
	while bool(boss.get("alive", true)) and guard < 6 and int(sim._unit_by_seat(0)["ap"]) >= 3:
		guard += 1
		sim.submit({"type": "cast", "spell": "strike", "to": boss["pos"], "target_seat": 1, "seat": 0})
	var snap: Dictionary = sim.snapshot()
	eq(bool(_unit(snap, 1)["alive"]), false, "the Archivist falls")
	var fled := 0
	for u in snap["units"]:
		if bool(u.get("fled", false)):
			fled += 1
	eq(fled >= 1, true, "his called pages scatter (%d)" % fled)
	eq(bool(snap["match_over"]), false, "his escort fights on")
	for u in sim._living_monsters():
		u["hp"] = 0
		sim._check_death(u)
	eq(str(sim.snapshot()["dungeon"]["result"]), "win", "the room is won when every monster is down")


# --- ★5 frost patches, chill, thaw ------------------------------------------------

func _test_star5_frost_patches() -> void:
	var run = Run.create(FROST, LEVEL, "kestrel", "", 5)["run"]
	var cfg: Dictionary = run.combat_config(1, 31)
	cfg["rolls"] = []
	for i in 300:
		cfg["rolls"].append(99)
	sim.reset_match(cfg)
	var boss: Dictionary = sim._unit_by_seat(1)
	eq(str(boss["name"]), "The Frozen Archivist", "★5 room B boss is the Frozen Archivist")
	var sig2: Dictionary = boss["signature2"]
	sim.submit({"type": "end_turn", "seat": 0})
	eq(bool(sim.pools_ready(boss)), true, "frost patches are ready on his first turn")
	var hero: Dictionary = sim._unit_by_seat(0)
	var hero_cell: Vector2i = hero["pos"]
	eq(bool(sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": hero_cell, "seat": 1}).get("ok", false)), true, "he lays Rime Patches")
	var patches: Array = sim.pool_cells()
	eq(patches.size() >= int(sig2["cells_min"]) and patches.size() <= int(sig2["cells_max"]), true, "2-3 frost patches (%d)" % patches.size())
	eq(patches.has(hero_cell), true, "a patch lands under the hero")
	for c in patches:
		eq(maxi(absi(c.x - hero_cell.x), absi(c.y - hero_cell.y)) <= 1, true, "patch %s is next to the hero" % c)
	for p in sim.snapshot()["dungeon"]["pools"]:
		eq(str(p.get("hazard", "")), "frost_patch", "the snapshot names the hazard frost_patch")
	var laid := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pools" and str(e.get("hazard", "")) == "frost_patch":
			laid = true
	eq(laid, true, "the hazard event names frost_patch for the view")
	eq(bool(sim.pools_ready(boss)), false, "one lay a turn")
	while int(sim.snapshot()["active_seat"]) != 0:
		var u: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
		sim.submit({"type": "end_turn", "seat": int(u["seat"])})
	hero["hp"] = 80
	var max_mp := int(hero["max_mp"])
	sim.submit({"type": "end_turn", "seat": 0})
	var hit: Dictionary = {}
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pool_hit":
			hit = e
	eq(hit.is_empty(), false, "ending the turn on frost hurts")
	eq(int(hit.get("damage", 0)), int(sig2["hp"]), "frost damage is %d" % int(sig2["hp"]))
	eq(int(hit.get("mp_loss", 0)), 2, "and costs 2 MP")
	eq(80 - int(hero["hp"]), int(sig2["hp"]), "the hero lost the frost damage")
	while int(sim.snapshot()["active_seat"]) != 0:
		var u2: Dictionary = sim._unit_by_seat(int(sim.snapshot()["active_seat"]))
		u2["acted_signature2"] = true
		sim.submit({"type": "end_turn", "seat": int(u2["seat"])})
	eq(int(hero["mp"]), max_mp - 2, "the next turn starts with 2 MP less")
	var chilled := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "chill":
			chilled = true
	eq(chilled, true, "the MP loss shows as a chill event")
	# Walking across a patch is safe: only ending a turn there hurts.
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
			u3["acted_signature2"] = true
			sim.submit({"type": "end_turn", "seat": int(u3["seat"])})
	eq(turns - 1, int(sig2["turns"]), "the patches last %d hero turns" % int(sig2["turns"]))
	eq(int(hero["hp"]) >= hp_now - 1, true, "ending a turn off the patches costs nothing")
	# The hero bot never ends a turn on a patch when it can step off.
	sim.reset_match(run.combat_config(1, 35))
	sim.submit({"type": "end_turn", "seat": 0})
	var b2: Dictionary = sim._unit_by_seat(1)
	sim.submit({"type": "cast", "spell": str(sig2["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]):
		sim.submit({"type": "end_turn", "seat": int(sim.snapshot()["active_seat"])})
	var on_before: bool = sim.pool_cells().has(sim._unit_by_seat(0)["pos"])
	var cells_before: Array = sim.pool_cells()
	var hero_bot_turn := AI.play_hero_turn(sim)
	var hit2 := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pool_hit":
			hit2 = true
	eq(on_before, true, "the bot starts its turn on a patch")
	eq(hit2, false, "the hero bot steps off before ending its turn (%d steps, patches %s)" % [hero_bot_turn.size(), cells_before])
	eq(b2.is_empty(), false, "the boss is in the room")


func _test_chill_and_thaw() -> void:
	var book = Monsters.load_default()["monsters"]
	var fw: Dictionary = book.stats_at("frozen_book_wraith", LEVEL, 5)
	var cells: Array = []
	for y in 12:
		for x in 12:
			var pad := Vector2i(x, y) == Vector2i(8, 8)
			cells.append({"pos": Vector2i(x, y), "terrain": "ground", "elevation": 0, "paint_only": ["rune_pad"] if pad else [], "blocks": false, "special": "pad" if pad else ""})
	var a := fw.duplicate(true)
	a["pos"] = Vector2i(8, 4)
	a["facing"] = "S"
	a["mp"] = 0
	var room := {"dungeon_id": FROST, "room_id": "chill", "room_name": "Chill", "kind": "pack", "cells": cells, "pad_heal": 5, "pad_thaw": true, "hero": {"class_id": "bastion", "pos": Vector2i(5, 7), "facing": "N"}, "monsters": [a], "summons": {}}
	var rolls: Array = []
	for i in 40:
		rolls.append(1)
	sim.reset_match({"board_size": 12, "seed": 4, "dungeon": room, "rolls": rolls})
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(fw["attack"]["id"]), "to": Vector2i(5, 7), "target_seat": 0, "seat": 1})
	var status := false
	for e in sim.snapshot()["last_events"]:
		if str(e.get("status", "")) == "chill":
			status = true
	eq(status, true, "a frozen wraith's hit chills the hero")
	sim.submit({"type": "end_turn", "seat": 1})
	var hero: Dictionary = sim._unit_by_seat(0)
	eq(int(hero["mp"]), int(hero["max_mp"]) - 1, "a chilled hero has 1 MP less on the next turn")
	# Chilled again, the hero ends on a rune pad: the pad thaws it.
	hero["pos"] = Vector2i(8, 8)
	sim.submit({"type": "end_turn", "seat": 0})
	sim.submit({"type": "cast", "spell": str(fw["attack"]["id"]), "to": Vector2i(8, 8), "target_seat": 0, "seat": 1})
	eq(int(hero.get("mp_drain", 0)), 1, "the second hit chills again")
	sim.submit({"type": "end_turn", "seat": 1})
	eq(int(hero["mp"]), int(hero["max_mp"]), "a turn that starts on a rune pad keeps its full MP")
	var thawed := false
	var healed := false
	for e in sim.snapshot()["last_events"]:
		thawed = thawed or str(e.get("type", "")) == "thaw"
		healed = healed or str(e.get("type", "")) == "pad"
	eq(thawed, true, "the pad's thaw shows as an event")
	eq(healed or int(hero["hp"]) == int(hero["max_hp"]), true, "the rune pad also heals")


# --- rewards -----------------------------------------------------------------------

func _test_rewards_per_star() -> void:
	var base_xp := 0
	var base_coins := 0
	var parts := {}
	for star in range(1, 6):
		var run = Run.create(FROST, LEVEL, "kestrel", "", star)["run"]
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
		eq(int(hero.best_dungeon_star(FROST)), star, "★%d clear is the archive's best star" % star)
		eq(bool(s3.get("new_best_star", false)), true, "★%d is a new best" % star)
	var expect_xp := int(round(0.27 * 5330.0 * 1.6 * pow(0.9532, LEVEL - 1)))
	eq(base_xp, expect_xp, "level 12 ★1 XP is 27%% of xp_to_next(12) x pace (%d)" % expect_xp)
	eq(base_xp > Run.create(GRANARY, 1, "kestrel")["run"].win_xp(1), true, "the archive pays more XP than the cellar")
	var set_part := false
	for id in parts.keys():
		if str(id).begins_with("pale_archivist_"):
			set_part = true
	eq(set_part, true, "the archive drops Pale Archivist set parts (the tier-15 set)")


func _test_mission_credit() -> void:
	var missions = Missions.load_default()["missions"]
	var hero = _fresh_hero()
	hero.level = LEVEL
	hero.mission_blob = {"story": {"northgate_scout": {"status": "done"}}}
	eq(missions.label_for("northgate_dungeon", hero) != "coming soon", true, "the Northgate dungeon mission is live")
	eq(bool(missions.accept("northgate_dungeon", hero).get("ok", false)), true, "the mission can be taken")
	var run = Run.create(FROST, LEVEL, "kestrel", "", 2)["run"]
	run.result = "win"
	var sm: Dictionary = run.pay_out(hero, missions, _rng(3), false)
	eq((sm["missions"] as Array).has("northgate_dungeon"), true, "an archive win credits the clear_dungeon mission")


# --- the Granary is unchanged ------------------------------------------------------

func _test_granary_unchanged() -> void:
	var book = Monsters.load_default()["monsters"]
	eq(book.ids_for(GRANARY), ["granary_rat", "sling_rat", "scarecrow_drudge", "the_ratking", "radioactive_rat", "radioactive_sling_rat", "radioactive_ratking"], "the cellar keeps its seven monsters")
	var rows := {1: [1.0, 1.0], 2: [1.1, 1.05], 3: [1.15, 1.1], 4: [1.2, 1.1], 5: [1.0, 1.0]}
	for star in range(1, 6):
		eq(book.star_scale(star), rows[star], "the cellar's ★%d row is unchanged" % star)
		eq(book.star_scale(star, GRANARY), rows[star], "the cellar's own lookup is the same row")
	eq([int(book.stats_at("granary_rat", 1)["hp"]), int(book.stats_at("granary_rat", 1)["attack"]["damage"])], [13, 4], "rat 13 HP, Gnaw 4")
	eq([int(book.stats_at("the_ratking", 1)["hp"]), int(book.stats_at("the_ratking", 1)["attack"]["damage"])], [82, 10], "Ratking 82 HP, Crook 10")
	eq(int(book.stats_at("radioactive_ratking", 1, 5)["signature2"]["hp"]), 6, "toxic pools still 6 poison")
	var run = Run.create(GRANARY, 1, "kestrel", "", 5)["run"]
	var room: Dictionary = run.combat_config(1, 31)["dungeon"]
	eq(bool(room.get("pad_thaw", false)), false, "cellar pads do not thaw")
	eq(int(room["pad_heal"]), 4, "cellar pads still heal 4")
	room["rolls"] = []
	var cfg: Dictionary = run.combat_config(1, 31)
	sim.reset_match(cfg)
	sim.submit({"type": "end_turn", "seat": 0})
	var king: Dictionary = sim._unit_by_seat(1)
	sim.submit({"type": "cast", "spell": str(king["signature2"]["id"]), "to": sim._unit_by_seat(0)["pos"], "seat": 1})
	var pools: Array = sim.snapshot()["dungeon"]["pools"]
	eq(pools.is_empty(), false, "the Radioactive Ratking still spills pools")
	for p in pools:
		eq(p.has("hazard") or p.has("mp_loss"), false, "a toxic pool record is unchanged (no hazard keys)")
	var coach := ""
	for e in sim.snapshot()["last_events"]:
		if str(e.get("type", "")) == "pools":
			coach = str(e["coach"])
			eq(e.has("hazard"), false, "the pools event is unchanged")
	eq(coach.contains("toxic pools"), true, "the coach line still says toxic pools")
	var g_run = Run.create(GRANARY, 1, "kestrel")["run"]
	eq(g_run.text("stairs"), "Down the old stairs, deeper under the granary...", "the cellar stairs line is unchanged")
	eq(g_run.text("return_button"), "Return to Stoneford", "the cellar return button is unchanged")
	eq(g_run.text("victory"), "Old Granary Cellar is cleared at ★1. The Ratking is down.", "the cellar victory line is unchanged")
	var sling: Dictionary = book.stats_at("sling_rat", 1)
	eq(str(sling["attack"]["impact"]), "sling_impact_puff", "the sling's impact puff moved into data")
	eq(str((Art.monster_spec("sling_rat")["stand_in"] as Dictionary)["art"]), "granary_rat", "the Sling Rat's stand-in moved into data")
	eq(Art.placeholder_height("the_ratking"), 128.0, "the Ratking placeholder height is unchanged")


# --- world door, panel, scene --------------------------------------------------------

func _test_world_door_and_panel() -> void:
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	w.progress.level = LEVEL
	w.enter_zone(ZONE, Vector2i(20, 15), false)
	await process_frame
	eq(w.zone.zone_id, ZONE, "the hero is in Northgate")
	eq(w.door_nodes.has(FROST), true, "the archive door stands in Northgate")
	var row: Dictionary = w.dungeon_book.by_id(FROST)
	var building: Array = Dungeons.building_cells_for(row, w.building_size_for(row))
	for c in building:
		eq(w.zone.passable_at(c), false, "archive cell %s blocks walking" % c)
	eq(w.zone.passable_at(DOOR), true, "the door cell stays walkable")
	eq(w.door_at(ZONE, DOOR).get("id", ""), FROST, "the door cell is a door")
	eq(w.door_at(ZONE, building[0]).get("id", ""), FROST, "clicking the building finds the door")
	eq(w.door_nodes[FROST].painted, true, "the door draws the painted archive tower")
	eq(bool(w.approach_door(FROST).get("ok", false)), true, "clicking the door walks there")
	_drive(w)
	eq(w.walker.cell, DOOR, "the hero stands on the door cell")
	eq(w.door_panel.is_open(), true, "the entry panel opens on arrival")
	var text := _panel_text(w.door_panel)
	eq(text.contains("Frostspire Archive"), true, "panel names the archive")
	eq(text.contains("10–20"), true, "panel shows levels 10-20")
	eq(text.contains("The Pale Archivist"), true, "panel names the boss")
	eq(bool(w.door_panel.check.get("ok", false)), true, "a level 12 hero passes the level check")
	eq(w.door_panel.star_buttons.size(), 5, "★1-★5 on the panel")
	w.door_panel.select_star(5)
	eq((w.door_panel.find_child("StarNote", true, false) as Label).text.contains("Frozen Archivist"), true, "the ★5 note is the archive's")
	w.door_panel.leave_button.emit_signal("pressed")
	w._approach_npc(w.npc_book.by_id("northgate_door_keeper"))
	_drive(w)
	eq(w.door_panel.is_open(), true, "talking to the Door Keeper opens the entry panel")
	Launcher.pending = {}
	w.door_panel.select_star(2)
	w.door_panel.press_enter()
	eq(str(Launcher.pending.get("dungeon_id", "")), FROST, "Enter hands over the archive")
	eq(int(Launcher.pending.get("star", 0)), 2, "Enter hands over the picked star")
	eq(Launcher.pending.get("return_cell", Vector2i(-1, -1)), DOOR, "the way back is the door cell")
	eq(str(Launcher.pending.get("return_zone", "")), ZONE, "the way back is Northgate")
	Launcher.pending = {}
	w.queue_free()
	await process_frame


func _test_run_scene_win_and_return() -> void:
	Launcher.pending = {"dungeon_id": FROST, "level": LEVEL, "class_id": "bastion", "autoplay": true, "return_zone": ZONE, "return_cell": DOOR, "seed": 1}
	Launcher.outcome = {}
	var scene: Node = (load(RUN_SCENE_PATH) as PackedScene).instantiate()
	var got := {}
	scene.run_finished.connect(func(r, s): got["result"] = r; got["summary"] = s)
	root.add_child(scene)
	var rooms := {}
	var summon_seen := false
	var bolts := false
	var t0 := Time.get_ticks_msec()
	while got.is_empty() and Time.get_ticks_msec() - t0 < 300000:
		await process_frame
		var snap: Dictionary = sim.snapshot()
		if snap.has("dungeon"):
			rooms[str(snap["dungeon"]["room_id"])] = true
			summon_seen = summon_seen or int(snap["dungeon"]["summoned_total"]) > 0
			for e in snap.get("last_events", []):
				bolts = bolts or str(e.get("projectile", "")) == "frost_bolt"
	eq(str(got.get("result", "")), "win", "the room scene plays a full archive run to a win")
	eq(rooms.has("room_a") and rooms.has("room_b"), true, "both rooms are played")
	eq(summon_seen, true, "the Archivist calls his pages during the scene")
	eq(bolts, true, "Book Wraith bolts fly in the scene")
	var board = scene.get_node("BoardView")
	eq(str(board.view_cfg.get("pads", {}).keys()), str(["rune_pad", "rune_circle"]), "the board reads the archive's pad styles")
	eq(scene.result_text().contains("The Pale Archivist is down"), true, "the result panel names the Archivist")
	eq(scene.result_text().contains("Northgate"), true, "the result panel sends the hero back to Northgate")
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
	eq(w.zone.zone_id, ZONE, "back in Northgate")
	eq(w.walker.cell, DOOR, "back on the archive door cell")
	eq(w.reward_popup.is_open(), true, "the reward pop-up shows the drop")
	w.queue_free()
	await process_frame


# --- helpers -----------------------------------------------------------------------

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
