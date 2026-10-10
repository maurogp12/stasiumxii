extends SceneTree

## Dev balance tool (not a suite): runs of one dungeon per star with the hero
## bot (backend/dungeon_ai.gd) against the monster AI, solo, every class.
## Prints the win % per star for a row of [hp, damage] multipliers.
## godot --headless --path . -s res://tests/sim_dungeon_stars.gd -- [dungeon_id] <runs> [level] ["h,d;h,d;..." for ★1..★5 or "-"] [stars e.g. 4,5]
## The dungeon id may be left out (the Old Granary Cellar).

const Run := preload("res://backend/pc_dungeon_run.gd")
const Monsters := preload("res://backend/pc_monsters.gd")
const AI := preload("res://backend/dungeon_ai.gd")
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
const DEFAULT_DUNGEON := "old_granary_cellar"

## Losses per room for the star being run.
var lost_in := {}


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var dungeon_id := DEFAULT_DUNGEON
	if not args.is_empty() and not str(args[0]).is_valid_int():
		dungeon_id = str(args.pop_front())
	var runs := int(args[0]) if args.size() > 0 else 4
	var level := int(args[1]) if args.size() > 1 else 1
	var only: Array = [1, 2, 3, 4, 5]
	if args.size() > 3:
		only = []
		for part in str(args[3]).split(","):
			only.append(int(part))
	if args.size() > 2 and str(args[2]) != "-":
		var rows := str(args[2]).split(";")
		for i in rows.size():
			var hd := rows[i].split(",")
			Monsters.star_scale_override[i + 1] = [float(hd[0]), float(hd[1])]
	var sim: Node = root.get_node("CombatSim")
	print("SIM %s level %d, %d runs per class" % [dungeon_id, level, runs])
	for star in only:
		var wins := 0
		var games := 0
		var per := {}
		lost_in = {}
		for cls in CLASSES:
			var w := 0
			for seed in runs:
				var made: Dictionary = Run.create(dungeon_id, level, cls, "", star)
				if not bool(made.get("ok", false)):
					push_error("run failed: %s" % [made.get("errors", [])])
					quit(1)
					return
				var run = made["run"]
				if _play(sim, run, 7000 + seed * 13 + star) == "win":
					w += 1
				games += 1
			wins += w
			per[cls] = "%d/%d" % [w, runs]
		print("STAR %d scale %s: win %.0f%%  %s  lost in %s" % [star, str(Monsters.load_default()["monsters"].star_scale(star, dungeon_id)), 100.0 * wins / games, per, lost_in])
	quit()


func _play(sim: Node, run, seed: int) -> String:
	while true:
		sim.reset_match(run.combat_config(-1, seed + run.room_index))
		var guard := 0
		while not bool(sim.snapshot()["match_over"]) and guard < 1500:
			guard += 1
			var seat := int(sim.snapshot()["active_seat"])
			if seat == 0:
				AI.play_hero_turn(sim)
			else:
				AI.play_monster_turn(sim, seat)
		if str(sim.snapshot()["dungeon"]["result"]) != "win":
			var rid := str(sim.snapshot()["dungeon"]["room_id"])
			lost_in[rid] = int(lost_in.get(rid, 0)) + 1
			return "lose"
		if not run.advance():
			return "win"
	return ""
