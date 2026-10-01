extends SceneTree

## Dev balance tool (not a test suite): AI vs AI Koliseo TEAM fights (2v2 /
## 3v3, Mauro 1 Oct 2026) on the real CombatSim rules. Same greedy
## expected-value planner as tests/sim_duels.gd, scored for the whole team.
## Team compositions are random (duplicates allowed, as Mauro chose); the
## report is each class's win % per appearance, so it reads like the duel total.
## godot --headless --path . -s res://tests/sim_teams.gd -- <team_size 2|3> <games> [base|lvl30]

const SIM_SCRIPT := preload("res://backend/combat_sim.gd")
const CLASSES := ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
const MAPS := ["crosshaven", "brinewake", "slagcrown", "windmere", "stormspire"]
const BUILDS := {
	"kestrel": {"mastery": 40, "vitality": 16, "swift": 2},
	"ironjaw": {"mastery": 34, "vitality": 22, "swift": 2},
	"mender": {"mastery": 24, "vitality": 32, "swift": 2},
	"gloam": {"mastery": 40, "vitality": 16, "swift": 2},
	"bastion": {"mastery": 20, "vitality": 36, "swift": 2},
}
const IDEAL_RANGE := {"kestrel": 4, "ironjaw": 1, "mender": 3, "gloam": 1, "bastion": 1}
const MAX_ROUNDS := 30
const MAX_ACTIONS := 8

var _team_size := 2
var _games := 20
var _mode := "base"
var _done := false
var _class_pts := {}
var _class_n := {}
var _comp_rows: Array = []
var _stuns := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_team_size = clampi(int(args[0]), 1, 3)
	if args.size() > 1:
		_games = int(args[1])
	if args.size() > 2:
		_mode = args[2]
	GearBag.save_path = "user://teams_bag.json"
	HeroProgress.save_path = "user://teams_hero.json"
	StillVault.save_path = "user://teams_still.json"
	KoliseoWallet.save_path = "user://teams_wallet.json"


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + _team_size
	var kit := {}
	if _mode == "lvl30":
		var heroes := {}
		for c in CLASSES:
			heroes[c] = {"level": 30, "spent": BUILDS[c]}
		kit = {"worn": [], "attune": {}, "heroes": heroes}
	for g in range(_games):
		var classes: Array = []
		for _i in range(_team_size * 2):
			classes.append(CLASSES[rng.randi_range(0, CLASSES.size() - 1)])
		var map_id: String = MAPS[g % MAPS.size()]
		var res := _play(classes, map_id, 9000 + g * 13, kit)
		_record(classes, res)
		print("  game %d %s  A=%s  B=%s  winner team %d  rounds %d  (%d s)" % [g + 1, map_id, str(_team(classes, 0)), str(_team(classes, 1)), int(res["winner_team"]), int(res["rounds"]), (Time.get_ticks_msec() - t0) / 1000])
		if (g + 1) % 5 == 0 or g + 1 == _games:
			_print_table("%dv%d, %s, after %d games" % [_team_size, _team_size, "level 30 builds" if _mode == "lvl30" else "level 1", g + 1])
	quit()
	return true


func _team(classes: Array, team: int) -> Array:
	var out: Array = []
	for seat in classes.size():
		if seat % 2 == team:
			out.append(classes[seat])
	return out


func _play(classes: Array, map_id: String, seed: int, kit: Dictionary) -> Dictionary:
	var sim: Node = SIM_SCRIPT.new()
	var config := {"seed": seed, "map_id": map_id, "classes": classes, "team_size": _team_size, "first_by_init": true}
	if not kit.is_empty():
		var gear := {}
		for seat in classes.size():
			gear[seat] = kit.duplicate(true)
		config["seat_gear"] = gear
	sim.reset_match(config)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if sim.match_phase_name() != "TURN_1":
		for seat in classes.size():
			var cells: Array = sim.legal_deploy_cells(seat)
			if not cells.is_empty():
				sim.place_unit(seat, cells[rng.randi_range(0, cells.size() - 1)])
		for seat in [0, 1]:
			sim.ready_seat(seat)
	var turns := 0
	while not bool(sim.get("_match_over")) and turns < MAX_ROUNDS * classes.size():
		var seat := int(sim.get("_active_seat"))
		var stunned_before := _stunned_foes(sim, seat)
		_play_turn(sim, seat, rng)
		var cls: String = classes[seat]
		_stuns[cls] = int(_stuns.get(cls, 0)) + maxi(0, _stunned_foes(sim, seat) - stunned_before)
		if not bool(sim.get("_match_over")) and int(sim.get("_active_seat")) == seat:
			sim.submit({"type": "end_turn", "seat": seat})
		turns += 1
	var winner_team := -1
	if bool(sim.get("_match_over")):
		winner_team = int(sim.get("_winner_team"))
	else:
		var pct := [_team_hp_pct(sim, 0), _team_hp_pct(sim, 1)]
		if absf(pct[0] - pct[1]) >= 0.05:
			winner_team = 0 if pct[0] > pct[1] else 1
	sim.free()
	return {"winner_team": winner_team, "rounds": turns / classes.size()}


func _stunned_foes(sim: Node, seat: int) -> int:
	var me := _unit(sim, seat)
	var n := 0
	for u in sim.get("_units"):
		if int(u.get("team", 0)) != int(me.get("team", 0)) and int(u.get("stun_remaining", 0)) > 0:
			n += 1
	return n


func _play_turn(sim: Node, seat: int, rng: RandomNumberGenerator) -> void:
	for _k in range(MAX_ACTIONS):
		if bool(sim.get("_match_over")) or int(sim.get("_active_seat")) != seat:
			return
		var legal: Array = _trim_moves(sim, seat, sim.legal_intents(seat), rng)
		var base := _eval(sim, seat) + _followup(sim, seat, 0)
		var best: Dictionary = {}
		var best_v := base + 0.5
		for intent in legal:
			var it: Dictionary = intent
			if str(it.get("type", "")) == "end_turn":
				continue
			var v := _value(sim, seat, it, 1)
			if v > best_v:
				best_v = v
				best = it
		if best.is_empty():
			return
		var sent := best.duplicate(true)
		sent["seat"] = seat
		if not bool(sim.submit(sent).get("ok", false)):
			return


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
	var foe_pos := _nearest_foe_pos(sim, seat)
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


## Team score from the acting fighter's side.
func _eval(sim: Node, seat: int) -> float:
	var me := _unit(sim, seat)
	if me.is_empty():
		return 0.0
	var my_team := int(me.get("team", 0))
	if bool(sim.get("_match_over")):
		return 10000.0 if int(sim.get("_winner_team")) == my_team else -10000.0
	var s := 0.0
	for u in sim.get("_units"):
		var mine := int(u.get("team", 0)) == my_team
		var hp := float(u.get("hp", 0)) if bool(u.get("alive", false)) else 0.0
		if mine:
			s += hp + float(u.get("shield", 0)) * 0.8
			if not bool(u.get("alive", false)):
				s -= 120.0
		else:
			s -= hp * 1.1 + float(u.get("shield", 0)) * 0.8
			if not bool(u.get("alive", false)):
				s += 140.0
			else:
				s += float(u.get("stun_remaining", 0)) * 10.0
				s += float(u.get("marks", 0)) * 4.0
	s += float(me.get("impact", 0)) * 3.0
	s += float(me.get("umbral", 0)) * 2.0
	s += float(me.get("pulse", 0)) * 1.5
	s += float(me.get("aegis", 0)) * 3.0
	s += float(me.get("shades", 0)) * 2.5
	s += 4.0 if bool(me.get("invisible", false)) else 0.0
	var cls := str(me.get("class_id", ""))
	var ideal := int(IDEAL_RANGE.get(cls, 1))
	var mp: Vector2i = me["pos"]
	var fp := _nearest_foe_pos(sim, seat)
	var d := maxi(absi(mp.x - fp.x), absi(mp.y - fp.y))
	s -= float(absi(d - ideal)) * 1.5
	# Supports stay close to their team.
	if cls == "mender" or cls == "bastion":
		s -= float(_nearest_mate_dist(sim, seat)) * 0.5
	return s


func _nearest_foe_pos(sim: Node, seat: int) -> Vector2i:
	var me := _unit(sim, seat)
	var best := Vector2i(7, 7)
	var best_d := 999
	for u in sim.get("_units"):
		if int(u.get("team", 0)) == int(me.get("team", 0)) or not bool(u.get("alive", false)):
			continue
		var p: Vector2i = u["pos"]
		var d := maxi(absi(p.x - me["pos"].x), absi(p.y - me["pos"].y))
		if d < best_d:
			best_d = d
			best = p
	return best


func _nearest_mate_dist(sim: Node, seat: int) -> int:
	var me := _unit(sim, seat)
	var best := 0
	var found := false
	for u in sim.get("_units"):
		if int(u.get("seat", -1)) == seat or int(u.get("team", 0)) != int(me.get("team", 0)) or not bool(u.get("alive", false)):
			continue
		var p: Vector2i = u["pos"]
		var d := maxi(absi(p.x - me["pos"].x), absi(p.y - me["pos"].y))
		if not found or d < best:
			best = d
			found = true
	return best


func _team_hp_pct(sim: Node, team: int) -> float:
	var hp := 0.0
	var mx := 0.0
	for u in sim.get("_units"):
		if int(u.get("team", 0)) == team:
			hp += float(u.get("hp", 0)) if bool(u.get("alive", false)) else 0.0
			mx += float(maxi(1, int(u.get("max_hp", 1))))
	return hp / maxf(mx, 1.0)


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
	for _i in range(16):
		out.append(v)
	return out


func _unit(sim: Node, seat: int) -> Dictionary:
	for u in sim.get("_units"):
		if int((u as Dictionary).get("seat", -1)) == seat:
			return u
	return {}


func _record(classes: Array, res: Dictionary) -> void:
	var w := int(res["winner_team"])
	for seat in classes.size():
		var cls: String = classes[seat]
		var pts := 0.5 if w < 0 else (1.0 if w == seat % 2 else 0.0)
		_class_pts[cls] = float(_class_pts.get(cls, 0.0)) + pts
		_class_n[cls] = int(_class_n.get(cls, 0)) + 1


func _print_table(title: String) -> void:
	print("\n=== %s ===" % title)
	print("class      win %   (appearances)   stuns dealt")
	for c in CLASSES:
		var n := int(_class_n.get(c, 0))
		var pct := 0 if n == 0 else int(round(100.0 * float(_class_pts.get(c, 0.0)) / float(n)))
		print("  %-8s %4d%%   (%d)   %d" % [c, pct, n, int(_stuns.get(c, 0))])
