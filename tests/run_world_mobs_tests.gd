extends SceneTree

## Open-world monsters (package Z1): world_monsters.json rules, the no-reuse
## rule against every PC dungeon, pack placement (walkable, never in the
## Crossroads, a town or a safe cell), levels by depth, pack sizes 2-10 and
## their spread, the world-cell fight board (10 enemies + hero), win / loss
## and the safe point, respawn, XP and coins by size, the gear seam,
## Performance mode, the boss clock (condition, despawn, cooldown, escort cap,
## loot), the walk cycles' planted feet and pack phase spread.
## Run: godot --headless --path . -s res://tests/run_world_mobs_tests.gd

const Mobs := preload("res://backend/world_monsters.gd")
const Levels := preload("res://backend/world_levels.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const NpcBook := preload("res://backend/world_npcs.gd")
const Dungeons := preload("res://backend/world_dungeons.gd")
const Progress := preload("res://backend/pc_progress.gd")
const AI := preload("res://backend/dungeon_ai.gd")
const Layer := preload("res://scenes/world/monster/world_mob_layer.gd")
const FightLauncher := preload("res://scenes/world/monster/world_fight_launcher.gd")
const Art := preload("res://scenes/world/dungeon/dungeon_art.gd")
const STONEFORD_PACK_CHUNKS: Array[String] = ["crosshaven_road_west", "crosshaven_stoneford_orchard", "crosshaven_stoneford_mill", "crosshaven_stoneford_fields"]
const DUNGEON_IDS: Array[String] = ["old_granary_cellar", "frostspire_archive", "saltmaw_grotto", "drowned_abbey", "heart_of_the_blight"]
const KIT := "res://art/pc/world/stoneford"

var _passed := 0
var _failed := 0
var sim: Node
var book
var levels
var atlas


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	sim = root.get_node("CombatSim")
	var loaded: Dictionary = Mobs.load_default()
	eq(bool(loaded.get("ok", false)), true, "world_monsters.json loads (%s)" % str(loaded.get("errors", [])))
	book = loaded["book"]
	levels = Levels.load_default()["levels"]
	atlas = Atlas.load_default()["atlas"]
	FightLauncher.dry_run = true
	_test_rejects()
	_test_no_dungeon_reuse()
	_test_placement()
	_test_levels_by_depth()
	_test_sizes()
	_test_fight_board()
	_test_win_and_loss()
	_test_respawn()
	_test_rewards()
	_test_drop_seam()
	_test_performance()
	_test_boss_clock()
	_test_boss_fights_and_loot()
	_test_ten_pack_speed()
	_test_walk_feet()
	_test_pack_phases()
	_finish()


func _finish() -> void:
	print("world mobs tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _zone(chunk: String) -> WorldZone:
	return atlas.map_for_chunk(chunk).zone(chunk)


func _doc() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Mobs.PATH))


# --- data ---------------------------------------------------------------------

func _test_rejects() -> void:
	var d := _doc()
	d["oops"] = 1
	eq(bool(Mobs.load_document(d).get("ok", true)), false, "an unknown top key is an error")
	d = _doc()
	(d["bosses"][0]["boss"] as Dictionary)["condition"] = {"weather": ["sunshine"]}
	eq(bool(Mobs.load_document(d).get("ok", true)), false, "an unknown weather word is an error")
	d = _doc()
	(d["zones"][0]["chunks"]["crosshaven_road_west"]["pool"] as Dictionary)["granary_rat"] = 1
	eq(bool(Mobs.load_document(d).get("ok", true)), false, "a pool naming a non-world monster is an error")


## Mauro: open-world monsters are never dungeon monsters (all 5 PC dungeons:
## room packs, escorts, summons, bosses and their art).
func _test_no_dungeon_reuse() -> void:
	eq(book.reuse_conflicts(), [], "no world monster or boss shares a dungeon monster's id, name or art")
	var dm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Mobs.DUNGEON_MONSTERS))
	var seen := {}
	for m in dm["monsters"]:
		seen[str(m["dungeon"])] = true
	for d in DUNGEON_IDS:
		eq(seen.has(d), true, "the check reads %s's monsters" % d)
	# The check bites: a world row renamed to a dungeon monster fails it.
	for probe in [["name", "Granary Rat"], ["id", "the_ratking"], ["art", "book_wraith"], ["name", "The Rotting Elder"]]:
		var d2 := _doc()
		(d2["monsters"][0] as Dictionary)[probe[0]] = probe[1]
		var b2 = Mobs.load_document(d2).get("book", null)
		var hit: Array = b2.reuse_conflicts() if b2 != null else ["load failed"]
		eq(hit.is_empty(), false, "reusing a dungeon %s (%s) is caught" % [probe[0], probe[1]])
	# Every room pack, escort and boss named in the dungeon run files is a
	# dungeon_monsters row, so the check above covers them.
	var dungeon_book = Dungeons.load_default()["dungeons"]
	for d in DUNGEON_IDS:
		var row: Dictionary = dungeon_book.by_id(d)
		var run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(row.get("run", "")))) if FileAccess.file_exists(str(row.get("run", ""))) else {}
		for room in run.get("rooms", []):
			var named: Array = (room.get("monsters", []) as Array).duplicate()
			for p in (room.get("packs", {}) as Dictionary).values():
				named.append_array(p)
			for m in named:
				eq(book.has(str(m.get("monster", ""))), false, "%s %s is not a world monster" % [d, m.get("monster", "")])
	# No world art path under the dungeon art, and no world frame is a copy
	# of any dungeon frame (a shared sheet).
	eq(book.art_path("stoneford").begins_with(Mobs.DUNGEON_ART_ROOT), false, "the Stoneford kit is not a dungeon kit")
	var dungeon_hashes := {}
	for d in DUNGEON_IDS:
		var mdir := "res://art/pc/dungeons/%s/monsters" % d
		for mid in DirAccess.get_directories_at(mdir):
			var p := "%s/%s/idle/idle_S_f00.png" % [mdir, mid]
			if FileAccess.file_exists(p):
				dungeon_hashes[FileAccess.get_md5(p)] = mid
	var checked := 0
	for mid in book.ids() + book.boss_ids():
		for act in ["idle", "walk", "attack"]:
			for face in ["S", "E"]:
				for i in 12:
					var p := "%s/monsters/%s/%s/%s_%s_f%02d.png" % [KIT, mid, act, act, face, i]
					if not FileAccess.file_exists(p):
						continue
					checked += 1
					eq(dungeon_hashes.has(FileAccess.get_md5(p)), false, "%s %s is not a dungeon frame" % [mid, p.get_file()])
	print("  no-reuse: %d world frames checked against %d dungeon sheets" % [checked, dungeon_hashes.size()])


# --- placement ----------------------------------------------------------------

func _test_placement() -> void:
	var npcs = NpcBook.load_default()["npcs"]
	var dungeon_book = Dungeons.load_default()["dungeons"]
	eq(book.chunk_cfg("crosshaven_crossroads").is_empty(), true, "the Crossroads has no packs")
	eq(book.chunk_cfg("crosshaven_stoneford").is_empty(), true, "Stoneford town has no packs")
	var town := _zone("crosshaven_stoneford")
	eq(book.place_packs(town, levels, RandomNumberGenerator.new(), {}).is_empty(), true, "no pack is placed in the town chunk")
	eq(book.place_packs(_zone("crosshaven_crossroads"), levels, RandomNumberGenerator.new(), {}).is_empty(), true, "no pack is placed in the Crossroads")
	for chunk in STONEFORD_PACK_CHUNKS:
		var z := _zone(chunk)
		var npc_cells: Array = []
		for r in npcs.for_zone(chunk):
			npc_cells.append(Vector2i(int(r["x"]), int(r["y"])))
		var doors: Array = []
		for row in dungeon_book.doors_in(chunk):
			doors.append(Dungeons.door_cell(row))
		var forbidden: Dictionary = book.forbidden_cells(z, npc_cells, doors)
		var bad := 0
		var near_safe := 0
		var bodies := 0
		var packs := 0
		for seed in 6:
			var rng := RandomNumberGenerator.new()
			rng.seed = 100 + seed
			for e in book.place_packs(z, levels, rng, forbidden):
				packs += 1
				for c in e["cells"]:
					bodies += 1
					if not z.passable_at(c):
						bad += 1
					if forbidden.has(c):
						near_safe += 1
					for n in npc_cells:
						if maxi(absi(c.x - n.x), absi(c.y - n.y)) <= 2:
							near_safe += 1
		eq(packs > 0, true, "%s gets packs" % chunk)
		eq(bad, 0, "%s: every body stands on a walkable cell (%d bodies)" % [chunk, bodies])
		eq(near_safe, 0, "%s: no body on a safe cell (exits, NPCs, doors, spawn, edge)" % chunk)


func _test_levels_by_depth() -> void:
	var last := 0
	var by_depth: Array = []
	for chunk in STONEFORD_PACK_CHUNKS:
		by_depth.append([book.chunk_depth(levels, chunk), chunk])
	by_depth.sort()
	for row in by_depth:
		var band: Array = book.chunk_levels(levels, str(row[1]))
		eq(int(band[0]) >= 1 and int(band[1]) <= 10, true, "%s levels %s sit in Stoneford's band 1-10" % [row[1], band])
		eq(int(band[0]) >= last, true, "%s (depth %d) is no lower than the shallower chunks" % [row[1], int(row[0])])
		last = int(band[0])
	eq(book.chunk_levels(levels, "crosshaven_road_west")[0], 1, "the entry chunk starts at level 1")
	eq(book.chunk_levels(levels, "crosshaven_stoneford_fields")[1], 10, "the deepest chunk reaches level 10")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		var p: Dictionary = book.make_pack(levels, "crosshaven_stoneford_orchard", rng)
		for m in p["members"]:
			if int(m["level"]) < 4 or int(m["level"]) > 6:
				eq(m["level"], "4..6", "orchard member levels stay in its depth band")


func _test_sizes() -> void:
	for chunk in STONEFORD_PACK_CHUNKS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		var counts := {"small": 0, "mid": 0, "big": 0}
		var lo := 99
		var hi := 0
		for i in 2000:
			var p: Dictionary = book.make_pack(levels, chunk, rng)
			var n := int(p["size"])
			lo = mini(lo, n)
			hi = maxi(hi, n)
			counts["small" if n <= 4 else ("mid" if n <= 7 else "big")] += 1
		var depth: int = book.chunk_depth(levels, chunk)
		var cap := int(book.chunk_cfg(chunk).get("max_size", 10))
		eq(lo >= 2 and hi <= cap, true, "%s pack sizes stay in 2..%d (%d..%d)" % [chunk, cap, lo, hi])
		eq(int(counts["small"]) > 1000, true, "%s: most packs are 2-4 (%s)" % [chunk, counts])
		if cap < 10:
			continue
		eq(int(counts["mid"]) > 100, true, "%s: some packs are 5-7" % chunk)
		if depth <= 1:
			eq(int(counts["big"]), 0, "%s (entry): no 8-10 packs" % chunk)
		else:
			eq(int(counts["big"]) > 40, true, "%s: a few 8-10 packs deeper in" % chunk)
	# Over the zone: the full 2..10 range shows up.
	var all := {}
	var rng2 := RandomNumberGenerator.new()
	for chunk in STONEFORD_PACK_CHUNKS:
		for i in 500:
			all[int(book.make_pack(levels, chunk, rng2)["size"])] = true
	for n in range(2, 11):
		eq(all.has(n), true, "Stoneford has packs of %d" % n)
	var w1: Dictionary = book.size_weights(1)
	var w5: Dictionary = book.size_weights(5)
	eq(float(w5["8-10"]) > float(w1["8-10"]), true, "big packs are more common deeper in the zone")


# --- fights -------------------------------------------------------------------

func _entry(chunk: String, size: int, seed: int) -> Dictionary:
	var z := _zone(chunk)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var forbidden: Dictionary = book.forbidden_cells(z)
	var e: Dictionary = book.place_packs(z, levels, rng, forbidden, 1)[0]
	e["pack"] = book.make_pack(levels, chunk, rng, size)
	e["cells"] = book.body_cells(z, e["home"], mini(size, 6), forbidden, {})
	return e


func _test_fight_board() -> void:
	for chunk in STONEFORD_PACK_CHUNKS:
		for seed in 4:
			var z := _zone(chunk)
			var e := _entry(chunk, 10, 30 + seed)
			var cfg: Dictionary = book.fight_config(z, e, {"class_id": "kestrel", "pos": (e["home"] as Vector2i) + Vector2i(0, 4)}, 1)
			eq(cfg.is_empty(), false, "%s seed %d: a 10-pack gets a world board" % [chunk, seed])
			if cfg.is_empty():
				continue
			var room: Dictionary = cfg["dungeon"]
			eq((room["monsters"] as Array).size(), 10, "all 10 monsters are on the board")
			var walk := {}
			for c in room["cells"]:
				if not bool(c["blocks"]):
					walk[c["pos"]] = true
			var used := {}
			var ok := true
			var hero: Vector2i = room["hero"]["pos"]
			used[hero] = true
			ok = ok and walk.has(hero)
			for m in room["monsters"]:
				var p: Vector2i = m["pos"]
				ok = ok and walk.has(p) and not used.has(p)
				used[p] = true
			eq(ok, true, "every unit stands on its own walkable cell")
			# The board is the world: a walkable board cell is a passable world cell.
			var origin: Vector2i = cfg["world_origin"]
			var mismatch := 0
			for b in walk.keys():
				if not z.passable_at(origin + b):
					mismatch += 1
			eq(mismatch, 0, "board cells are the world cells round the pack")
			sim.reset_match(cfg)
			var snap: Dictionary = sim.snapshot()
			eq(snap.has("dungeon"), true, "CombatSim starts the world fight in dungeon mode")
			var placed := 0
			for u in snap["units"]:
				if bool(u.get("alive", false)):
					placed += 1
			eq(placed, 11, "the hero and 10 monsters are live on the board")


func _play_out(limit: int = 900) -> String:
	var guard := 0
	while not bool(sim.snapshot()["match_over"]) and guard < limit:
		guard += 1
		var seat := int(sim.snapshot()["active_seat"])
		if seat == 0:
			AI.play_hero_turn(sim)
		else:
			AI.play_monster_turn(sim, seat)
	return str(sim.snapshot()["dungeon"]["result"])


func _test_win_and_loss() -> void:
	var z := _zone("crosshaven_road_west")
	var e := _entry("crosshaven_road_west", 2, 11)
	var cfg: Dictionary = book.fight_config(z, e, {"class_id": "ironjaw", "pos": (e["home"] as Vector2i) + Vector2i(0, 4)}, 3)
	sim.reset_match(cfg)
	var result := _play_out()
	eq(result, "win", "a level-2 hero beats a 2-pack on the road")
	var progress = Progress.new()
	progress.level = 2
	var xp0 := int(progress.xp)
	var coins0 := int(progress.coins)
	var paid: Dictionary = book.pay_out(e["pack"], "stoneford", "win", progress, RandomNumberGenerator.new(), false)
	eq(int(paid["xp"]) > 0 and int(progress.xp) + 0 >= xp0, true, "a win pays XP (%d)" % int(paid["xp"]))
	eq(int(progress.coins) - coins0, int(paid["coins"]), "a win pays coins (%d)" % int(paid["coins"]))
	var lost: Dictionary = book.pay_out(e["pack"], "stoneford", "lose", progress, RandomNumberGenerator.new(), false)
	eq(int(lost["xp"]) + int(lost["coins"]), 0, "a loss pays nothing")
	# A hopeless fight is lost.
	var e2 := _entry("crosshaven_stoneford_fields", 10, 12)
	var cfg2: Dictionary = book.fight_config(_zone("crosshaven_stoneford_fields"), e2, {"class_id": "kestrel", "pos": (e2["home"] as Vector2i) + Vector2i(0, 4), "hp": 6}, 4)
	sim.reset_match(cfg2)
	eq(_play_out(), "lose", "a 6 HP hero loses to a 10-pack")
	# Loss returns to the zone's safe point (Stoneford town), win stays put.
	FightLauncher.outcome = {}
	var ctx := {"entry_id": "x", "pack": e["pack"], "return_zone": "crosshaven_road_west", "return_cell": Vector2i(10, 10), "safe_zone": "crosshaven_stoneford", "safe_cell": Vector2i(5, 5)}
	FightLauncher.finish(null, ctx, "lose", {})
	var back: Dictionary = FightLauncher.take_outcome()
	eq([back["return_zone"], back["return_cell"]], ["crosshaven_stoneford", Vector2i(5, 5)], "a loss sends the hero to the safe point")
	FightLauncher.finish(null, ctx, "win", {})
	back = FightLauncher.take_outcome()
	eq([back["return_zone"], back["return_cell"]], ["crosshaven_road_west", Vector2i(10, 10)], "a win leaves the hero where they fought")
	eq(FightLauncher.enter(null, {"config": cfg, "pack": e["pack"]}).get("scene", ""), FightLauncher.FIGHT_SCENE, "a pack fight opens the world fight scene")
	FightLauncher.take_pending()


# --- map layer ----------------------------------------------------------------

func _layer() -> Node2D:
	Layer.reset_state()
	var layer := Layer.new()
	var plates := CanvasLayer.new()
	root.add_child(plates)
	root.add_child(layer)
	layer.setup(null, plates)
	return layer


func _test_respawn() -> void:
	var layer := _layer()
	var z := _zone("crosshaven_stoneford_mill")
	layer.restock(z, Vector2i.ZERO)
	var before: int = layer.live_entries().size()
	eq(before > 0, true, "the mill shows its packs (%d)" % before)
	var e: Dictionary = layer.live_entries()[0]
	layer.mark_defeated(str(e["id"]))
	eq(layer.live_entries().size(), before - 1, "a beaten pack leaves the map")
	layer.tick(30.0, {"hour": 12.0, "weather": "clear"}, Vector2i(-50, -50))
	eq(layer.live_entries().size(), before - 1, "it is still gone after 30 s")
	layer.tick(70.0, {"hour": 12.0, "weather": "clear"}, Vector2i(-50, -50))
	eq(layer.live_entries().size(), before, "it respawns after 90 s")
	# It waits while the hero stands next to its home.
	var e2: Dictionary = layer.live_entries()[0]
	layer.mark_defeated(str(e2["id"]))
	layer.tick(200.0, {"hour": 12.0, "weather": "clear"}, (e2["home"] as Vector2i))
	eq(layer.live_entries().size(), before - 1, "no respawn on top of the hero")
	layer.queue_free()


func _test_rewards() -> void:
	var prev_xp := 0
	var prev_coins := 0
	for n in range(2, 11):
		var members: Array = []
		for i in n:
			members.append({"monster": "bristleback_boar", "level": 6})
		var r: Dictionary = book.pack_rewards(book.describe_pack(members), 6)
		eq(int(r["xp"]) > prev_xp, true, "XP rises with pack size (%d: %d)" % [n, int(r["xp"])])
		eq(int(r["coins"]) >= prev_coins, true, "coins rise with pack size (%d: %d)" % [n, int(r["coins"])])
		prev_xp = int(r["xp"])
		prev_coins = int(r["coins"])
	eq(is_equal_approx(book.size_mult(3), 1.0), true, "a pack of 3 is the spec 4.8 world fight")
	eq(book.size_mult(10) < 10.0 / 3.0, true, "diminishing returns: 10 monsters pay less than 10/3 packs of 3")
	eq(book.drop_mult(10) > book.drop_mult(2), true, "the drop chance rises with pack size")
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/level_curve.json"))
	var three: Dictionary = book.describe_pack([{"monster": "mandrake_rootling", "level": 1}, {"monster": "mandrake_rootling", "level": 1}, {"monster": "mandrake_rootling", "level": 1}])
	var want := int(round(0.035 * float(curve["xp_to_next"][0]) * float(curve["pace_start"])))
	eq(int(book.pack_rewards(three, 1)["xp"]), want, "level 1 pack of 3 pays 3.5% of xp_to_next(1) x pace(1)")


class FakeGear extends RefCounted:
	var calls := 0
	var last_chance := -1.0
	var last_tier := "?"
	func roll_world_drop(zone_level: int, _rng: RandomNumberGenerator, chance: float = -1.0, tier: String = "") -> Dictionary:
		calls += 1
		last_chance = chance
		last_tier = tier
		return {"item_id": "fake_gear_%d" % zone_level, "rarity": "regular", "count": 1}


func _test_drop_seam() -> void:
	Mobs.gear_override = null
	var rng := RandomNumberGenerator.new()
	var none: Variant = book.world_drop(5, rng, 3)
	eq(typeof(none) == TYPE_DICTIONARY and (none as Dictionary).is_empty(), true, "no pc_gear.roll_world_drop yet: the seam drops nothing")
	var fake := FakeGear.new()
	Mobs.gear_override = fake
	var got: Dictionary = book.world_drop(7, rng, 4)
	eq(str(got.get("item_id", "")), "fake_gear_7", "with roll_world_drop the seam returns its drop")
	var loot: Array = book.roll_loot(book.describe_pack([{"monster": "flour_moth", "level": 7}]), "stoneford", "kestrel", null, rng)
	var found := false
	for it in loot:
		found = found or str(it.get("item_id", "")) == "fake_gear_7"
	eq(found, true, "a won pack's loot goes through the seam")
	book.world_drop(7, rng, 10)
	eq(is_equal_approx(fake.last_chance, 0.08 * 2.08), true, "a 10-pack asks for world_chance x (1 + 0.12 x 9) (%.4f)" % fake.last_chance)
	eq(fake.last_tier, "", "a normal pack passes no tier")
	book.roll_loot(book.boss_pack("thresher_stag"), "stoneford", "kestrel", null, rng)
	eq(fake.last_tier, "rowanvale", "a boss passes its tier row")
	Mobs.gear_override = null


func _test_performance() -> void:
	var layer := _layer()
	layer.performance = true
	var z := _zone("crosshaven_stoneford_fields")
	layer.restock(z, Vector2i.ZERO)
	eq(layer.playing_count(), 0, "Performance mode: no body animates")
	var homes := {}
	for e in layer.live_entries():
		homes[e["id"]] = e["home"]
	for i in 20:
		layer.tick(1.0, {"hour": 12.0, "weather": "clear"}, Vector2i(-50, -50))
	var moved := 0
	for e in layer.live_entries():
		if homes.get(e["id"]) != e["home"]:
			moved += 1
	eq(moved, 0, "Performance mode: packs do not wander")
	layer.set_performance(false)
	for i in 30:
		layer.tick(1.0, {"hour": 12.0, "weather": "clear"}, Vector2i(-50, -50))
	moved = 0
	for e in layer.live_entries():
		if homes.get(e["id"]) != e["home"]:
			moved += 1
	eq(moved > 0, true, "Full look: packs wander a little (%d moved)" % moved)
	layer.queue_free()


# --- bosses -------------------------------------------------------------------

func _test_boss_clock() -> void:
	eq(Mobs.condition_holds({"time": ["night"]}, {"hour": 23.0}), true, "23:00 is night")
	eq(Mobs.condition_holds({"time": ["night"]}, {"hour": 12.0}), false, "noon is not night")
	eq(Mobs.condition_holds({"weather": ["rain"]}, {"weather": "light_rain"}), true, "light_rain is rain")
	eq(Mobs.condition_holds({"weather": ["snow"]}, {"weather": "light_rain"}), false, "rain is not snow")
	eq(Mobs.condition_holds({"weather": ["snow"]}, {"weather": "snow"}), true, "the snow condition exists for snowy zones")
	eq(Mobs.condition_holds({"time": ["night"], "weather": ["rain"]}, {"hour": 2.0, "weather": "clear"}), false, "combined conditions all must hold")
	var d := _doc()
	for b in d["bosses"]:
		b["boss"]["roll_per_minute"] = 1.0
	var b1 = Mobs.load_document(d)["book"]
	var clock = Mobs.BossClock.new(b1, "stoneford")
	var rng := RandomNumberGenerator.new()
	var day := {"hour": 12.0, "weather": "clear"}
	var spawned := 0
	for i in 600:
		for ev in clock.tick(60.0, day, rng):
			spawned += 1
	eq(spawned, 0, "no boss spawns outside its condition (10 h of clear days)")
	var night := {"hour": 23.0, "weather": "clear"}
	var evs: Array = clock.tick(60.0, night, rng)
	eq(clock.is_up("grimhoot_orchard_owl"), true, "Grimhoot comes at night")
	eq(clock.is_up("old_gulp_millpond_toad"), false, "Old Gulp does not come on a dry night")
	var gone: Array = clock.tick(60.0, {"hour": 6.0, "weather": "clear"}, rng)
	eq(clock.is_up("grimhoot_orchard_owl"), false, "Grimhoot leaves at dawn")
	eq(str(gone[0].get("reason", "")) if not gone.is_empty() else "", "condition", "the despawn says why")
	clock.tick(60.0, night, rng)
	eq(clock.is_up("grimhoot_orchard_owl"), false, "the cooldown keeps him away the next night")
	clock.tick(14400.0, day, rng)
	clock.tick(60.0, night, rng)
	eq(clock.is_up("grimhoot_orchard_owl"), true, "after the cooldown he can come again")
	clock.tick(1800.0, night, rng)
	eq(clock.is_up("grimhoot_orchard_owl"), false, "a boss leaves after its timeout")
	clock.tick(60.0, {"hour": 12.0, "weather": "light_rain"}, rng)
	eq(clock.is_up("old_gulp_millpond_toad"), true, "Old Gulp comes in the rain")
	clock.tick(60.0, {"hour": 12.0, "weather": "wind"}, rng)
	eq(clock.is_up("thresher_stag"), true, "the Thresher Stag comes on the wind")
	# The real rate: about one sighting per 2.5 h of in-condition play.
	for id in book.boss_ids():
		var m: float = book.expected_minutes(id)
		eq(m >= 120.0 and m <= 180.0, true, "%s: expected %.0f in-condition minutes per sighting" % [id, m])
	# Forced spawn (dev command) works out of condition.
	var c2 = Mobs.BossClock.new(book, "stoneford")
	eq(str(c2.spawn("thresher_stag").get("type", "")), "spawn", "force-spawn raises a boss on demand")


func _test_boss_fights_and_loot() -> void:
	var dungeon_bosses := {}
	var dm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Mobs.DUNGEON_MONSTERS))
	for m in dm["monsters"]:
		if str(m["role"]) == "boss":
			dungeon_bosses[str(m["name"]).to_lower()] = true
	for id in book.boss_ids():
		eq(book.boss_fight_cap(id) <= 10, true, "%s: escort plus summons stay at 10 or fewer (%d)" % [id, book.boss_fight_cap(id)])
		var b: Dictionary = book.row(id)
		eq(dungeon_bosses.has(str(b["name"]).to_lower()), false, "%s is not a dungeon boss" % id)
		var lv := int((b["boss"] as Dictionary)["level"])
		eq(lv >= 10 and lv <= 12, true, "%s level %d is the zone top or up to +2" % [id, lv])
		var pack: Dictionary = book.boss_pack(id)
		var chunk := str(((b["boss"] as Dictionary)["chunks"] as Array)[0])
		var z := _zone(chunk)
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var e: Dictionary = book.place_packs(z, levels, rng, book.forbidden_cells(z), 1)[0]
		e["pack"] = pack
		e["cells"] = book.body_cells(z, e["home"], 6, book.forbidden_cells(z), {})
		var cfg: Dictionary = book.fight_config(z, e, {"class_id": "bastion", "pos": (e["home"] as Vector2i) + Vector2i(0, 4)}, 2)
		eq(cfg.is_empty(), false, "%s gets a world board" % id)
		sim.reset_match(cfg)
		eq(bool(sim.snapshot().get("dungeon", {}).is_empty()), false, "%s's fight starts" % id)
		var Rewards: GDScript = load("res://backend/pc_rewards.gd")
		var catalog = Rewards.load_default()["rewards"]
		var loot: Array = book.roll_loot(pack, "stoneford", "kestrel", catalog, rng)
		var chest := false
		var trophy := false
		for it in loot:
			chest = chest or bool(it.get("chest", false))
			trophy = trophy or str(it.get("trophy", "")) != ""
		eq(chest, true, "%s always drops its gear chest" % id)
		eq(trophy, true, "%s always drops its trophy and title" % id)
		eq(int(book.pack_rewards(pack, 10)["xp"]) > int(book.pack_rewards(book.make_pack(levels, "crosshaven_stoneford_fields", rng, int(pack["size"])), 10)["xp"]), true, "%s pays more than a normal pack" % id)
	# The epic chance uses the star_drops layer: a dungeon with star_drops
	# (the abbey) yields one at chance 1; Stoneford's own dungeon has none yet.
	var d := _doc()
	d["boss_loot"]["epic_chance"] = 1.0
	d["boss_loot"]["epic_from_dungeon"] = "drowned_abbey"
	var b2 = Mobs.load_document(d)["book"]
	var Rewards2: GDScript = load("res://backend/pc_rewards.gd")
	var cat2 = Rewards2.load_default()["rewards"]
	var epic := false
	for it in b2.boss_loot(b2.boss_pack("thresher_stag"), "kestrel", cat2, RandomNumberGenerator.new()):
		epic = epic or bool(it.get("epic", false))
	eq(epic, true, "the epic roll draws from the star_drops pools")


func _test_ten_pack_speed() -> void:
	var z := _zone("crosshaven_stoneford_fields")
	var e := _entry("crosshaven_stoneford_fields", 10, 77)
	var cfg: Dictionary = book.fight_config(z, e, {"class_id": "bastion", "pos": (e["home"] as Vector2i) + Vector2i(0, 4)}, 5)
	sim.reset_match(cfg)
	AI.play_hero_turn(sim)
	var t0 := Time.get_ticks_usec()
	var turns := 0
	while int(sim.snapshot()["active_seat"]) != 0 and not bool(sim.snapshot()["match_over"]) and turns < 12:
		AI.play_monster_turn(sim, int(sim.snapshot()["active_seat"]))
		turns += 1
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("  10-pack monster round: %d turns in %.1f ms" % [turns, ms])
	eq(turns >= 10, true, "all 10 monsters take a turn")
	eq(ms < 1500.0, true, "a 10-monster round of AI stays quick (%.0f ms)" % ms)


# --- motion -------------------------------------------------------------------

## Feet stay planted: in every walk cycle, a stance foot moves at most 2 px in
## world space while the body travels at the cycle's ground speed.
func _test_walk_feet() -> void:
	var checked := 0
	for mid in book.ids() + book.boss_ids():
		var p := "%s/monsters/%s/meta.json" % [KIT, mid]
		if not FileAccess.file_exists(p):
			continue
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p))
		if bool(meta.get("flies", false)):
			continue
		for f in (meta.get("gait", {}) as Dictionary).keys():
			var g: Dictionary = meta["gait"][f]
			var v := float(g["speed_px_per_frame"])
			var dir: Array = g["dir"]
			var worst := 0.0
			for leg in (g["feet"] as Dictionary).keys():
				var track: Array = g["feet"][leg]
				var st: Array = g["stance"][leg]
				var n := track.size()
				for i in n:
					var j := (i + 1) % n
					if not (bool(st[i]) and bool(st[j])):
						continue
					# world = cell + body travel; consecutive stance frames must agree
					var wx := float(track[j][0]) + float(dir[0]) * v - float(track[i][0])
					var wy := float(track[j][1]) + float(dir[1]) * v - float(track[i][1])
					worst = maxf(worst, Vector2(wx, wy).length())
			checked += 1
			print("  walk %s %s: %.2f cell px/frame, worst planted-foot slip %.3f px" % [mid, f, v, worst])
			eq(worst <= 2.0, true, "%s %s: planted feet slide at most 2 px per frame (worst %.2f)" % [mid, f, worst])
			eq(v > 0.0, true, "%s %s walks at a stride-locked speed (%.2f px/frame)" % [mid, f, v])
	eq(checked > 0, true, "walk cycles with planted feet were checked (%d)" % checked)


## A pack's members never animate in lockstep: start frames and speeds differ.
func _test_pack_phases() -> void:
	var layer := _layer()
	var z := _zone("crosshaven_stoneford_fields")
	layer.restock(z, Vector2i.ZERO)
	var any_pack := false
	for e in layer.live_entries():
		var node: Node = layer._nodes[e["id"]]
		var frames := {}
		var bodies := 0
		for child in node.get_children():
			if child.has_meta("monster"):
				bodies += 1
				var spr: AnimatedSprite2D = child.get_node("Body")
				frames["%d:%.3f" % [spr.frame, spr.speed_scale]] = true
		if bodies >= 3:
			any_pack = true
			eq(frames.size() > 1, true, "%s: members are not all on the same frame and speed" % e["id"])
	eq(any_pack, true, "a pack of 3+ bodies was checked")
	layer.queue_free()


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
