extends SceneTree

## Dev balance tool (not a suite): Old Granary Cellar runs per star with the
## hero bot (backend/dungeon_ai.gd) against the monster AI, solo, every class.
## Prints the win % per star for a row of [hp, damage] multipliers.
## godot --headless --path . -s res://tests/sim_granary_stars.gd -- <runs> [level] ["h,d;h,d;..." for ★1..★5 or "-"] [stars e.g. 4,5]

const Run := preload("res://backend/pc_dungeon_run.gd")
const Monsters := preload("res://backend/pc_monsters.gd")
const AI := preload("res://backend/dungeon_ai.gd")
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
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
	for star in only:
		var wins := 0
		var games := 0
		var per := {}
		for cls in CLASSES:
			var w := 0
			for seed in runs:
				var made: Dictionary = Run.create("old_granary_cellar", level, cls, "", star)
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
		print("STAR %d scale %s: win %.0f%%  %s" % [star, str(Monsters.load_default()["monsters"].star_scale(star)), 100.0 * wins / games, per])
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
			return "lose"
		if not run.advance():
			return "win"
	return ""
