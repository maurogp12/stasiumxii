extends SceneTree

## Dev balance tool (not a test suite): dungeon (Stasis) runs with AI heroes
## (backend/hero_ai.gd) against the AI monsters (StasisAi.plan) on the real
## rooms. Level-30 heroes with the duel builds and a +5 set. Reports the win %
## per star for the full party the star is tuned for, and for a solo hero.
## Targets (Mauro 1 Oct 2026): full party ★3 ≈ 80%, ★4 ≈ 65%, ★5 ≈ 50%;
## ★1 solo easy; short-handed = brutal.
## godot --headless --path . -s res://tests/sim_dungeons.gd -- <runs_per_cell> [stars e.g. 1,2,3,4,5]

const SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const HeroAi := preload("res://backend/hero_ai.gd")
const DOORS := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const BUILDS := {
	"kestrel": {"mastery": 40, "vitality": 16, "swift": 2},
	"ironjaw": {"mastery": 34, "vitality": 22, "swift": 2},
	"mender": {"mastery": 24, "vitality": 32, "swift": 2},
	"gloam": {"mastery": 40, "vitality": 16, "swift": 2},
	"bastion": {"mastery": 20, "vitality": 36, "swift": 2},
}
const SET_FOR := {"kestrel": "brightedge", "ironjaw": "brightedge", "gloam": "brightedge", "mender": "sheaf", "bastion": "ironveil"}
const PARTY_4 := ["bastion", "mender", "kestrel", "ironjaw"]
const MAX_TURNS := 400

var _runs := 4
var _stars: Array = [1, 2, 3, 4, 5]
var _done := false
## star → [level, set pieces worn, plus] (DUNGEON_HERO).
var _hero_for: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_runs = int(args[0])
	if args.size() > 1:
		_stars = []
		for part in str(args[1]).split(","):
			_stars.append(int(part))
	GearBag.save_path = "user://dungeon_sim_bag.json"
	HeroProgress.save_path = "user://dungeon_sim_hero.json"
	StillVault.save_path = "user://dungeon_sim_still.json"
	# DUNGEON_HERO="3:15,3,0;4:23,5,2" sets the party per star: level, worn
	# set pieces (of 5), fuse plus. Default: level 30, all 5 pieces, +5.
	for part in OS.get_environment("DUNGEON_HERO").split(";", false):
		var kv := part.split(":")
		var v := kv[1].split(",")
		_hero_for[int(kv[0])] = [int(v[0]), int(v[1]), int(v[2])]
	# DUNGEON_SCALE="3:3.2,2.2;5:9,5" tries other [hp, damage] star scales.
	for part in OS.get_environment("DUNGEON_SCALE").split(";", false):
		var kv := part.split(":")
		var hd := kv[1].split(",")
		StasisCatalog.star_scale_override[int(kv[0])] = [float(hd[0]), float(hd[1])]
	KoliseoWallet.save_path = "user://dungeon_sim_wallet.json"


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var t0 := Time.get_ticks_msec()
	for s in _stars:
		var star := int(s)
		var full := StasisCatalog.party_for_star(star)
		var sizes := [full] if full == 1 or OS.get_environment("DUNGEON_FULL_ONLY") != "" else [full, 1]
		for size in sizes:
			var wins := 0
			var rooms := {"a": 0, "b": 0}
			for r in range(_runs):
				var door: String = DOORS[r % DOORS.size()]
				var classes: Array = PARTY_4.slice(0, size) if size > 1 else [["kestrel", "ironjaw", "gloam", "bastion", "mender"][r % 5]]
				var won_a := _room(door, "a", star, classes, 100 + r)
				var won_b := _room(door, "b", star, classes, 200 + r) if won_a else false
				rooms["a"] += 1 if won_a else 0
				rooms["b"] += 1 if won_b else 0
				wins += 1 if won_b else 0
			print("★%d  party %d%s: run win %d%%  (Room A %d/%d, boss %d/%d)  [%d s]" % [star, size, " (tuned size)" if size == full else " (short-handed)", roundi(100.0 * wins / _runs), rooms["a"], _runs, rooms["b"], rooms["a"], (Time.get_ticks_msec() - t0) / 1000])
	quit()
	return true


func _room(door: String, room: String, star: int, classes: Array, seed: int) -> bool:
	StasisCatalog.clear_run()
	StasisCatalog.begin(door)
	StasisCatalog.set_star(star)
	StasisCatalog.room = room
	StasisCatalog.set_party(classes)
	var config: Dictionary = StasisCatalog.fight_config()
	if config.is_empty():
		print("  (no config for %s %s)" % [door, room])
		return false
	config["seed"] = int(config.get("seed", 0)) + seed
	# Level 30 + build + a +5 set for every hero, unless DUNGEON_HERO says
	# otherwise for this star (level, pieces worn, plus; points scale with level).
	var kit: Array = _hero_for.get(star, [30, 5, 5])
	var level := int(kit[0])
	var pieces := int(kit[1])
	var plus := int(kit[2])
	var share := float(level - 1) / 29.0
	var roster: Array = config["stasis_roster"]
	for rec in roster:
		var seat := int(rec["seat"])
		if seat >= classes.size():
			continue
		var cls: String = classes[seat]
		var worn: Array = []
		for slot in GearBag.SLOTS:
			if worn.size() >= pieces:
				break
			worn.append({"item_id": GearBag.item_id_for(SET_FOR[cls], slot), "plus": plus})
		var spent := {}
		for k in BUILDS[cls]:
			spent[k] = int(floor(float(BUILDS[cls][k]) * share))
		rec["gear"] = {"worn": worn, "attune": {}, "heroes": {cls: {"level": level, "spent": spent}}}
		rec.erase("hp")
	if classes.size() == 1:
		config["classes"] = [classes[0], StasisCatalog.STRIKE_CARD_CLASS]
	var sim: Node = SIM_SCRIPT.new()
	sim.reset_match(config)
	var turns := 0
	var max_turns := 40 * (sim.get("_units") as Array).size()
	while not bool(sim.get("_match_over")) and turns < max_turns:
		var seat := int(sim.get("_active_seat"))
		var unit := _unit(sim, seat)
		var hero := int(unit.get("team", 0 if seat == 0 else 1)) == 0
		var guard := 0
		while guard < 14 and not bool(sim.get("_match_over")) and int(sim.get("_active_seat")) == seat:
			var intent: Dictionary = HeroAi.plan(sim, seat) if hero else StasisAi.plan(sim, seat)
			if intent.is_empty():
				intent = {"type": "end_turn", "seat": seat}
			intent["seat"] = seat
			var res: Dictionary = sim.submit(intent)
			if not bool(res.get("ok", false)) or str(intent.get("type", "")) == "end_turn":
				if int(sim.get("_active_seat")) == seat and not bool(sim.get("_match_over")):
					sim.submit({"type": "end_turn", "seat": seat})
				break
			guard += 1
		if guard >= 14 and int(sim.get("_active_seat")) == seat and not bool(sim.get("_match_over")):
			sim.submit({"type": "end_turn", "seat": seat})
		turns += 1
	var won := bool(sim.get("_match_over")) and int(sim.get("_winner_team")) == 0
	if not bool(sim.get("_match_over")):
		# Timeout (an AI stalemate, e.g. a caster kiting forever): heroes take
		# it when they kept more of their HP than the monsters.
		won = _team_pct(sim, 0) > _team_pct(sim, 1)
	if OS.get_environment("DUNGEON_VERBOSE") != "":
		var hp := []
		for u in sim.get("_units"):
			hp.append("%s:%d/%d" % [str(u.get("name", "")).substr(0, 8), int(u.get("hp", 0)), int(u.get("max_hp", 0))])
		print("    %s %s ★%d over=%s winner_team=%d turns=%d  %s" % [door, room, star, str(sim.get("_match_over")), int(sim.get("_winner_team")), turns, " ".join(hp)])
	sim.free()
	return won


func _team_pct(sim: Node, team: int) -> float:
	var hp := 0.0
	var mx := 0.0
	for u in sim.get("_units"):
		if int(u.get("team", 0 if int(u.get("seat", 0)) == 0 else 1)) == team:
			hp += float(u.get("hp", 0)) if bool(u.get("alive", false)) else 0.0
			mx += float(maxi(1, int(u.get("max_hp", 1))))
	return hp / maxf(mx, 1.0)


func _unit(sim: Node, seat: int) -> Dictionary:
	for u in sim.get("_units"):
		if int((u as Dictionary).get("seat", -1)) == seat:
			return u
	return {}
