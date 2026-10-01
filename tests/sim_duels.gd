extends SceneTree

## Dev balance tool (not a test suite): AI vs AI Koliseo duels for every class
## pairing on the real CombatSim rules. Greedy one-turn planner: each action is
## scored by expected value (hit and miss both simulated on a cloned sim and
## weighted by the real hit chance), plus the best follow-up cast.
## godot --headless --path . -s res://tests/sim_duels.gd -- <games_per_side> [gear] [only_class]

const SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const CLASSES := ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
const MAPS := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
## Level-30 builds: 58 characteristic points spent to fit each class
## (Mastery +2 / Vitality +8 HP / Swift +1 Init / Ward only guards attuned
## gear, so no Ward without gear).
const BUILDS := {
	"kestrel": {"mastery": 40, "vitality": 16, "swift": 2},
	"ironjaw": {"mastery": 34, "vitality": 22, "swift": 2},
	"mender": {"mastery": 24, "vitality": 32, "swift": 2},
	"gloam": {"mastery": 40, "vitality": 16, "swift": 2},
	"bastion": {"mastery": 20, "vitality": 36, "swift": 2},
}
const IDEAL_RANGE := {"kestrel": 4, "ironjaw": 1, "mender": 3, "gloam": 1, "bastion": 1}
const MAX_ROUNDS := 30
const MAX_ACTIONS := 10

var _games := 4
var _mode := "base"
var _only := ""
var _seed_offset := 0
var _done := false
var _stats := {}
var _spell_use := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_games = int(args[0])
	if args.size() > 1:
		_mode = args[1]
	if args.size() > 2:
		_only = "" if args[2] == "all" else args[2]
	# Seed offset: run several processes with different seeds and add up
	# their tables (… -- 2 lvl30 all 1, … all 2, …).
	if args.size() > 3:
		_seed_offset = int(args[3]) * 100003
	GearBag.save_path = "user://duel_bag.json"
	HeroProgress.save_path = "user://duel_hero.json"
	StillVault.save_path = "user://duel_still.json"
	KoliseoWallet.save_path = "user://duel_wallet.json"


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var t0 := Time.get_ticks_msec()
	var kit := {}
	if _mode == "lvl30":
		var heroes := {}
		for c in CLASSES:
			heroes[c] = {"level": 30, "spent": BUILDS[c]}
		kit = {"worn": [], "attune": {}, "heroes": heroes}
	var n := 0
	for i in range(CLASSES.size()):
		for j in range(i + 1, CLASSES.size()):
			var a: String = CLASSES[i]
			var b: String = CLASSES[j]
			if _only != "" and a != _only and b != _only:
				continue
			for g in range(_games * 2):
				var swap := g % 2 == 1
				var classes := [b, a] if swap else [a, b]
				var map_id: String = MAPS[(g / 2) % MAPS.size()]
				var res := _play(classes, map_id, 1000 + g * 7 + i * 131 + j * 17 + _seed_offset, kit)
				_record(classes, res)
				if OS.get_environment("DUEL_VERBOSE") != "":
					print("    %s(s0) vs %s(s1) %s: winner %d, rounds %d, hp %s, dmg %s" % [classes[0], classes[1], map_id, int(res["winner"]), int(res["rounds"]), str(res["hp"]), str(res["dmg"])])
				n += 1
			print("  %s vs %s done (%d s)" % [a, b, (Time.get_ticks_msec() - t0) / 1000])
			_print_win_table("after %s vs %s (%d duels)" % [a, b, n])
	_report(n)
	quit()
	return true


func _play(classes: Array, map_id: String, seed: int, kit: Dictionary) -> Dictionary:
	var sim: Node = SIM_SCRIPT.new()
	var config := {"seed": seed, "map_id": map_id, "classes": classes, "first_by_init": true}
	if not kit.is_empty():
		config["seat_gear"] = {0: kit, 1: kit.duplicate(true)}
	sim.reset_match(config)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if sim.match_phase_name() != "play" and sim.match_phase_name() != "battle":
		for seat in [0, 1]:
			var cells: Array = sim.legal_deploy_cells(seat)
			if not cells.is_empty():
				sim.place_unit(seat, cells[rng.randi_range(0, cells.size() - 1)])
		for seat in [0, 1]:
			sim.ready_seat(seat)
	var turns := 0
	var dmg := [0, 0]
	while not bool(sim.get("_match_over")) and turns < MAX_ROUNDS * 2:
		var seat := int(sim.get("_active_seat"))
		var foe_before := _hp(sim, 1 - seat)
		_play_turn(sim, seat, rng, classes[seat])
		dmg[seat] += maxi(0, foe_before - _hp(sim, 1 - seat))
		if not bool(sim.get("_match_over")) and int(sim.get("_active_seat")) == seat:
			sim.submit({"type": "end_turn", "seat": seat})
		turns += 1
	var winner := int(sim.get("_winner_seat")) if bool(sim.get("_match_over")) else -1
	var hp := [_hp(sim, 0), _hp(sim, 1)]
	var pct := [float(hp[0]) / float(_max_hp(sim, 0)), float(hp[1]) / float(_max_hp(sim, 1))]
	sim.free()
	return {"winner": winner, "rounds": (turns + 1) / 2, "hp": hp, "pct": pct, "dmg": dmg, "map": map_id}


func _play_turn(sim: Node, seat: int, rng: RandomNumberGenerator, cls: String) -> void:
	for _k in range(MAX_ACTIONS):
		if bool(sim.get("_match_over")) or int(sim.get("_active_seat")) != seat:
			return
		var legal: Array = _trim_moves(sim, seat, sim.legal_intents(seat), rng)
		var base := _eval(sim, seat) + _followup(sim, seat, 0)
		var best: Dictionary = {}
		var best_v := base + 0.5
		for intent in legal:
			var it: Dictionary = intent
			var kind := str(it.get("type", ""))
			if kind == "end_turn":
				continue
			var v := _value(sim, seat, it, 1)
			if v > best_v:
				best_v = v
				best = it
		if best.is_empty():
			return
		var sent := best.duplicate(true)
		sent["seat"] = seat
		var res: Dictionary = sim.submit(sent)
		if not bool(res.get("ok", false)):
			return
		if str(best.get("type", "")) == "cast":
			var key := "%s:%s" % [cls, str(best.get("spell", ""))]
			_spell_use[key] = int(_spell_use.get(key, 0)) + 1


## Walks: the 4 closest and 3 farthest dests from the foe, plus 3 random.
func _trim_moves(sim: Node, seat: int, legal: Array, rng: RandomNumberGenerator) -> Array:
	var moves: Array = []
	var out: Array = []
	for it in legal:
		if str((it as Dictionary).get("type", "")) == "move":
			moves.append(it)
		else:
			out.append(it)
	if moves.size() <= 10:
		return out + moves
	var foe_pos: Vector2i = _unit(sim, 1 - seat)["pos"]
	moves.sort_custom(func(a, b): return _dist(a, foe_pos) < _dist(b, foe_pos))
	var keep := moves.slice(0, 4) + moves.slice(moves.size() - 3)
	var mid := moves.slice(4, moves.size() - 3)
	for _i in range(3):
		if mid.is_empty():
			break
		keep.append(mid.pop_at(rng.randi_range(0, mid.size() - 1)))
	return out + keep


func _dist(intent: Dictionary, foe_pos: Vector2i) -> int:
	var to = intent.get("to")
	var c: Vector2i = to if to is Vector2i else Vector2i(int(to[0]), int(to[1])) if to is Array else Vector2i(int(to.get("x", 0)), int(to.get("y", 0)))
	return maxi(absi(c.x - foe_pos.x), absi(c.y - foe_pos.y))


## Expected value of taking `intent` now (hit / miss weighted), plus the best
## follow-up cast when depth allows.
func _value(sim: Node, seat: int, intent: Dictionary, depth: int) -> float:
	var miss := _clone(sim)
	miss.set("_scripted_rolls", _rolls(100))
	var sent := intent.duplicate(true)
	sent["seat"] = seat
	var r: Dictionary = miss.submit(sent)
	if not bool(r.get("ok", false)):
		miss.free()
		return -INF
	var chance := -1
	for ev in r.get("events", []):
		if ev is Dictionary and (ev as Dictionary).has("hit_chance"):
			chance = int(ev["hit_chance"])
	var v_miss := _eval(miss, seat) + (_followup(miss, seat, depth) if depth > 0 else 0.0)
	miss.free()
	if chance < 0 or chance >= 100:
		return v_miss
	var hit := _clone(sim)
	hit.set("_scripted_rolls", _rolls(1))
	hit.submit(sent)
	var v_hit := _eval(hit, seat) + (_followup(hit, seat, depth) if depth > 0 else 0.0)
	hit.free()
	var p := float(chance) / 100.0
	return p * v_hit + (1.0 - p) * v_miss


## Best extra gain from one more cast this turn (moves excluded to stay cheap).
func _followup(sim: Node, seat: int, depth: int) -> float:
	if bool(sim.get("_match_over")) or int(sim.get("_active_seat")) != seat:
		return 0.0
	var now := _eval(sim, seat)
	var best := 0.0
	for intent in sim.legal_intents(seat):
		var it: Dictionary = intent
		if str(it.get("type", "")) != "cast":
			continue
		var v := _value(sim, seat, it, depth - 1) - now
		if v > best:
			best = v
	return best * 0.9


func _eval(sim: Node, seat: int) -> float:
	var me := _unit(sim, seat)
	var foe := _unit(sim, 1 - seat)
	if me.is_empty() or foe.is_empty():
		return 0.0
	if not bool(foe.get("alive", true)):
		return 10000.0
	if not bool(me.get("alive", true)):
		return -10000.0
	var s := float(me["hp"]) - float(foe["hp"]) * 1.1
	s += float(me.get("shield", 0)) * 0.8 - float(foe.get("shield", 0)) * 0.8
	s += float(foe.get("stun_remaining", 0)) * 10.0
	s += float(foe.get("marks", 0)) * 4.0
	s += float(me.get("impact", 0)) * 3.0
	s += float(me.get("umbral", 0)) * 2.0
	s += float(me.get("pulse", 0)) * 1.5
	s += float(me.get("aegis", 0)) * 3.0
	s += float(me.get("shades", 0)) * 2.5
	s += 4.0 if bool(me.get("invisible", false)) else 0.0
	# Positioning: each class wants its own fighting distance (melee 1,
	# Kestrel 4 = inside Mark Shot 2–5, Mender 3).
	var ideal := int(IDEAL_RANGE.get(str(me.get("class_id", "")), 1))
	var mp: Vector2i = me["pos"]
	var fp: Vector2i = foe["pos"]
	var d := maxi(absi(mp.x - fp.x), absi(mp.y - fp.y))
	s -= float(absi(d - ideal)) * 1.5
	return s


func _clone(sim: Node) -> Node:
	var c: Node = SIM_SCRIPT.new()
	for p in sim.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name := str(p["name"])
		var v = sim.get(name)
		if v is Array or v is Dictionary:
			c.set(name, v.duplicate(true))
		elif v is RandomNumberGenerator:
			var r := RandomNumberGenerator.new()
			r.randomize()
			c.set(name, r)
		elif name == "_flow":
			c.set(name, _clone_obj(v))
		else:
			c.set(name, v)
	return c


func _clone_obj(o: Object) -> Object:
	var c: Object = (o.get_script() as Script).new()
	for p in o.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = o.get(str(p["name"]))
			c.set(str(p["name"]), v.duplicate(true) if (v is Array or v is Dictionary) else v)
	return c


func _rolls(v: int) -> Array[int]:
	var out: Array[int] = []
	for _i in range(12):
		out.append(v)
	return out


func _unit(sim: Node, seat: int) -> Dictionary:
	for u in sim.get("_units"):
		if int((u as Dictionary).get("seat", -1)) == seat:
			return u
	return {}


func _hp(sim: Node, seat: int) -> int:
	return int(_unit(sim, seat).get("hp", 0))


func _max_hp(sim: Node, seat: int) -> int:
	return maxi(1, int(_unit(sim, seat).get("max_hp", 1)))


func _record(classes: Array, res: Dictionary) -> void:
	for seat in [0, 1]:
		var me: String = classes[seat]
		var foe: String = classes[1 - seat]
		var key := "%s>%s" % [me, foe]
		var row: Dictionary = _stats.get(key, {"w": 0, "l": 0, "d": 0, "rounds": 0, "dmg": 0, "n": 0, "first_w": 0, "first_n": 0})
		var w := int(res["winner"])
		if w == -1:
			# Timeout: higher remaining HP % takes it as a "points" win.
			var pct: Array = res["pct"]
			if absf(float(pct[seat]) - float(pct[1 - seat])) < 0.05:
				row["d"] += 1
			elif float(pct[seat]) > float(pct[1 - seat]):
				row["w"] += 1
			else:
				row["l"] += 1
		elif w == seat:
			row["w"] += 1
		else:
			row["l"] += 1
		row["rounds"] += int(res["rounds"])
		row["dmg"] += int(res["dmg"][seat])
		row["n"] += 1
		_stats[key] = row


func _print_win_table(title: String) -> void:
	print("\n=== %s ===" % title)
	var header := "%-9s" % ""
	for c in CLASSES:
		header += "%12s" % c
	header += "      total"
	print("win % (row vs column), n per cell:")
	print(header)
	for a in CLASSES:
		var line := "%-9s" % a
		var tw := 0
		var tn := 0
		for b in CLASSES:
			if a == b:
				line += "%12s" % "-"
				continue
			var row: Dictionary = _stats.get("%s>%s" % [a, b], {})
			if row.is_empty():
				line += "%12s" % "."
				continue
			var pts := float(row["w"]) + 0.5 * float(row["d"])
			var pct := int(round(100.0 * pts / float(row["n"])))
			line += "%12s" % ("%d%%(%d)" % [pct, int(row["n"])])
			tw += int(row["w"]) * 2 + int(row["d"])
			tn += int(row["n"]) * 2
		var games := int(tn / 2)
		var total := int(round(100.0 * tw / float(maxi(1, tn))))
		line += "   %d%%(%d)" % [total, games]
		print(line)
	# Godot 4.7 has no OS.flush_stdout. The engine logger flushes each print,
	# so this table is on disk before the next matchup starts.


func _report(n: int) -> void:
	var mode := "level 30, points spent per class, no gear" if _mode == "lvl30" else "level 1 base kits (no gear)"
	_print_win_table("%d duels, %s" % [n, mode])
	print("\navg damage dealt per match / avg rounds:")
	for a in CLASSES:
		var d := 0
		var r := 0
		var nn := 0
		for b in CLASSES:
			var row: Dictionary = _stats.get("%s>%s" % [a, b], {})
			if row.is_empty():
				continue
			d += int(row["dmg"])
			r += int(row["rounds"])
			nn += int(row["n"])
		if nn > 0:
			print("  %-8s dmg %5.1f   rounds %4.1f" % [a, float(d) / nn, float(r) / nn])
	print("\nspell casts:")
	var keys := _spell_use.keys()
	keys.sort()
	for k in keys:
		print("  %s %d" % [k, _spell_use[k]])
