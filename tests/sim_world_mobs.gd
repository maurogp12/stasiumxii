extends SceneTree

## Balance sim for the Stoneford world packs (package Z1). Not a suite.
## A solo hero bot (dungeon_ai hero_intent, the same bot the dungeon sims use)
## fights packs of each size at the chunk's level on real world boards.
##   godot --headless --path . -s res://tests/sim_world_mobs.gd -- [runs] [chunk]
## Targets (Mauro): 2-4 an easy or fair win, 10 dangerous solo.

const Mobs := preload("res://backend/world_monsters.gd")
const Levels := preload("res://backend/world_levels.gd")
const Atlas := preload("res://backend/world_atlas.gd")
const AI := preload("res://backend/dungeon_ai.gd")
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 6
	var chunks: Array = [args[1]] if args.size() > 1 else ["crosshaven_road_west", "crosshaven_stoneford_fields"]
	var sim: Node = root.get_node("CombatSim")
	var book = Mobs.load_default()["book"]
	var levels = Levels.load_default()["levels"]
	var atlas = Atlas.load_default()["atlas"]
	for chunk in chunks:
		var z: WorldZone = atlas.map_for_chunk(chunk).zone(chunk)
		var forbidden: Dictionary = book.forbidden_cells(z)
		print("== %s (levels %s)" % [chunk, str(book.chunk_levels(levels, chunk))])
		for n in [2, 3, 4, 5, 7, 10]:
			var wins := 0
			var total := 0
			var hp_left := 0.0
			var rounds := 0
			for cls in CLASSES:
				for r in runs:
					var rng := RandomNumberGenerator.new()
					rng.seed = 1000 * n + 17 * r + hash(cls) % 97
					var placed: Array = book.place_packs(z, levels, rng, forbidden, 1)
					if placed.is_empty():
						continue
					var e: Dictionary = placed[0]
					e["pack"] = book.make_pack(levels, chunk, rng, n)
					e["cells"] = book.body_cells(z, e["home"], mini(n, 6), forbidden, {})
					var cfg: Dictionary = book.fight_config(z, e, {"class_id": cls, "pos": (e["home"] as Vector2i) + Vector2i(0, 4)}, int(rng.seed))
					if cfg.is_empty():
						continue
					sim.reset_match(cfg)
					var guard := 0
					while not bool(sim.snapshot()["match_over"]) and guard < 2000:
						guard += 1
						var seat := int(sim.snapshot()["active_seat"])
						if seat == 0:
							AI.play_hero_turn(sim)
						else:
							AI.play_monster_turn(sim, seat)
					var snap: Dictionary = sim.snapshot()
					total += 1
					rounds += int(snap["dungeon"].get("round", 0))
					if str(snap["dungeon"]["result"]) == "win":
						wins += 1
						for u in snap["units"]:
							if int(u["seat"]) == 0:
								hp_left += float(u["hp"]) / float(u["max_hp"])
			print("  pack %2d: win %3d%% (%d/%d), hero HP left on a win %3d%%, rounds %.1f" % [n, int(100.0 * wins / maxf(total, 1)), wins, total, int(100.0 * hp_left / maxf(wins, 1)), float(rounds) / maxf(total, 1)])
	quit()
