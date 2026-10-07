extends RefCounted

## AI companion for a dungeon party seat (Mauro 1 Oct 2026: "if no healer is
## found give the option to fill with AI"). Cheap heuristic, phone friendly:
## no sim cloning. One call returns one intent; call again until end_turn.
## Rules stay in CombatSim: everything offered comes from legal_intents.
##
## Roles (Mauro 4 Oct 2026: "the healer keeps walking towards enemy, he should
## stay range and heal, and Kestrel stay away just looking to hit from
## distance, while Ironjaw and Bastion should focus close combat"):
##   healer (Mender)   stays behind the front line, 3+ tiles from enemies and
##                     within heal reach of the team; heals early (below 85%),
##                     wards the engaged front liner, only hits from 2+ tiles.
##   ranged (Kestrel)  keeps 4–5 tiles from the enemies; steps back first when
##                     an enemy is within 2, then shoots.
##   melee (Ironjaw, Bastion, Gloam)  closes in and fights up close; Bastion
##                     goes for the enemy nearest the back line.
## Mender, a teammate down (Mauro 4 Oct 2026: "if anyone dies he should focus
## in reviving his team mate"): Rekindle comes first. He keeps every Pulse
## (Mend / Cleanse earn it; Pulse Tap, Ward and Heartstop are skipped), walks
## to 1–2 tiles from the body without spending AP first, and casts Rekindle
## the moment it is legal (6 AP + 6 Pulse).
## Order each call: revive → support → step back (healer / ranged) → best hit
## → position → end turn.

const ROLE := {"mender": "healer", "kestrel": "ranged", "ironjaw": "melee", "bastion": "melee", "gloam": "melee"}
const IDEAL_RANGE := {"kestrel": 4, "ironjaw": 1, "mender": 3, "gloam": 1, "bastion": 1}
## Heal a teammate under this share of max HP. The healer heals earlier.
const HEAL_BELOW := 0.65
const HEALER_HEAL_BELOW := 0.85
const MIN_HIT_SCORE := 2.0
## Healer and ranged: an enemy this close (Chebyshev) is too close.
const DANGER_RANGE := 2
## Ranged band (Chebyshev to the nearest enemy).
const RANGED_BAND := Vector2i(4, 5)
## Healer: at least this far from enemies, at most this far from the ally it covers.
const HEALER_SAFE := 3
const HEALER_REACH := 3


static func role_of(class_id: String) -> String:
	return str(ROLE.get(SpellKits.normalize_class_id(class_id), "melee"))


static func plan(sim: Node, seat: int) -> Dictionary:
	var legal: Array = sim.legal_intents(seat)
	var end_turn := {"type": "end_turn", "seat": seat}
	for intent in legal:
		if bool(intent.get("auto", false)):
			return intent
	var snap: Dictionary = sim.snapshot()
	var actor := _unit(snap, seat)
	if actor.is_empty():
		return end_turn
	var team := int(actor.get("team", 0))
	var role := role_of(str(actor.get("class_id", "")))
	var casts: Array = []
	var moves: Array = []
	for intent in legal:
		match str(intent.get("type", "")):
			"cast":
				casts.append(intent)
			"move":
				moves.append(intent)
			"end_turn":
				end_turn = intent
	var enemies := _enemy_cells(snap, team)
	var here := _cell(actor.get("pos"))
	# 0. Bring a fallen teammate back (Mender's Rekindle, once per match).
	for intent in casts:
		if str(SpellKits.spell(str(intent.get("spell", ""))).get("target", "")) == "fallen_ally":
			return intent
	var saving := false
	if role == "healer":
		var body := _fallen_body(snap, actor)
		if body.x > -99:
			saving = true
			var revive := _revive_plan(casts, moves, actor, snap, team, enemies, body)
			if not revive.is_empty():
				return revive
	if saving:
		casts = _keep_pulse(casts)
	# 1. Support a hurt teammate (the healer heals earlier and wards the front).
	var heal := _best_support(casts, snap, team, HEALER_HEAL_BELOW if role == "healer" else HEAL_BELOW)
	if not heal.is_empty():
		return heal
	if role == "healer":
		var ward := _front_ward(casts, snap, team, enemies)
		if not ward.is_empty():
			return ward
	# Bastion's team Ward (Mauro 6 Oct 2026): raise it when a fight is close.
	var team_ward := _team_ward(casts, snap, team, here, enemies)
	if not team_ward.is_empty():
		return team_ward
	# 2. Healer and ranged: step out of reach before anything else. Kestrel's
	# Vault (Mauro 6 Oct 2026) is the escape when an enemy is right next to her.
	if role != "melee" and not enemies.is_empty() and _nearest(here, enemies) <= 1:
		var best_vault := {}
		var best_gap := 1
		for intent in casts:
			if str(intent.get("spell", "")) != SpellKits.VAULT:
				continue
			var gap := _nearest(_cell(intent.get("to")), enemies)
			if gap > best_gap:
				best_gap = gap
				best_vault = intent
		if not best_vault.is_empty():
			return best_vault
	if role != "melee" and not moves.is_empty() and not enemies.is_empty() and _nearest(here, enemies) <= DANGER_RANGE:
		var away := _best_move(moves, here, role, snap, team, enemies, sim, actor, true)
		if away.is_empty():
			away = _farther_move(moves, here, enemies)
		if not away.is_empty():
			return away
	# 3. Best expected hit.
	var best := _best_hit(casts, snap, team, role, here, sim)
	if not best.is_empty():
		return best
	# 4. Walk to the role's place.
	if not moves.is_empty() and int(actor.get("mp", 0)) > 0 and not enemies.is_empty():
		var pick := _best_move(moves, here, role, snap, team, enemies, sim, actor, false)
		if not pick.is_empty():
			return pick
	return end_turn


## The cell of a fallen teammate the Mender can still Rekindle, or (-99, -99).
static func _fallen_body(snap: Dictionary, actor: Dictionary) -> Vector2i:
	var cls := SpellKits.normalize_class_id(str(actor.get("class_id", "")))
	if not SpellKits.has_spell(cls, SpellKits.REKINDLE) or bool(actor.get("used_" + SpellKits.REKINDLE, false)):
		return Vector2i(-99, -99)
	var here := _cell(actor.get("pos"))
	var living := {}
	for unit in snap.get("units", []):
		if bool(unit.get("alive", false)) and unit.get("pos") != null:
			living[_cell(unit.get("pos"))] = true
	var best := Vector2i(-99, -99)
	var best_d := 999
	for unit in snap.get("units", []):
		if int(unit.get("team", 0)) != int(actor.get("team", 0)) or bool(unit.get("alive", false)) or int(unit.get("seat", -1)) == int(actor.get("seat", -1)):
			continue
		if not bool(unit.get("placed", true)) or unit.get("pos") == null:
			continue
		var cell := _cell(unit.get("pos"))
		if living.has(cell):
			continue
		var d := _cheb(here, cell)
		if d < best_d:
			best_d = d
			best = cell
	return best


## Rekindle focus. Full Pulse: walk into 1–2 of the body before spending any
## AP. Short of Pulse: earn it (Mend / Cleanse), then close in on the body.
static func _revive_plan(casts: Array, moves: Array, actor: Dictionary, snap: Dictionary, team: int, enemies: Array, body: Vector2i) -> Dictionary:
	var def := SpellKits.spell(SpellKits.REKINDLE)
	var need_pulse := int(def.get("requires_pulse", 0))
	var pulse := int(actor.get("pulse", (actor.get("resources", {}) as Dictionary).get("pulse", 0)))
	var here := _cell(actor.get("pos"))
	var reach_lo := int(def.get("min_range", 1))
	var reach_hi := int(def.get("max_range", 2))
	var in_reach := func(cell: Vector2i) -> bool:
		var d := _cheb(cell, body)
		return d >= reach_lo and d <= reach_hi
	if pulse < need_pulse:
		var build := _pulse_builder(casts, snap, team)
		if not build.is_empty():
			return build
	var anchor := body
	# Walk into reach (the safest cell there), or as close as this turn allows.
	if not in_reach.call(here) and not moves.is_empty():
		var pick := {}
		var pick_key := INF
		for intent in moves:
			var to := _cell(intent.get("to"))
			var key := float(maxi(0, _cheb(to, body) - reach_hi)) * 100.0
			if _cheb(to, body) < reach_lo:
				key += 100.0
			key -= _place_score(to, "healer", enemies, {}, anchor)
			if key < pick_key:
				pick_key = key
				pick = intent
		if not pick.is_empty() and pick_key < float(maxi(0, _cheb(here, body) - reach_hi)) * 100.0 - _place_score(here, "healer", enemies, {}, anchor):
			return pick
	return {}


## Mend (or Cleanse) earns Pulse: the most hurt ally first.
static func _pulse_builder(casts: Array, snap: Dictionary, team: int) -> Dictionary:
	var best := {}
	var best_ratio := INF
	for intent in casts:
		var def := SpellKits.spell(str(intent.get("spell", "")))
		if str(def.get("engine_on_connect", "")) != "pulse":
			continue
		var target := _unit(snap, int(intent.get("target_seat", -1)))
		if target.is_empty() or int(target.get("team", 0)) != team or not bool(target.get("alive", false)):
			continue
		var ratio := float(target.get("hp", 0)) / maxf(1.0, float(target.get("max_hp", 1)))
		if ratio < best_ratio:
			best_ratio = ratio
			best = intent
	return best


## Drop every cast that spends Pulse (saving it for Rekindle).
static func _keep_pulse(casts: Array) -> Array:
	var out: Array = []
	for intent in casts:
		var def := SpellKits.spell(str(intent.get("spell", "")))
		if str(def.get("engine_on_connect", "")) == "spend_pulse":
			continue
		out.append(intent)
	return out


static func _best_hit(casts: Array, snap: Dictionary, team: int, role: String, here: Vector2i, sim: Node) -> Dictionary:
	var best := {}
	var best_score := MIN_HIT_SCORE
	var back := _back_line(snap, team)
	for intent in casts:
		var spell := str(intent.get("spell", ""))
		var def := SpellKits.spell(spell)
		if def.is_empty() or not str(def.get("target", "")) in ["enemy", "burst", "cone", "any"]:
			continue
		var target := _unit(snap, int(intent.get("target_seat", -1)))
		if str(def.get("target", "")) == "any" and (target.is_empty() or int(target.get("team", 0)) == team):
			continue
		# The healer only hits from 2+ tiles (it never walks in to hit).
		if role == "healer" and not target.is_empty() and _cheb(here, _cell(target.get("pos"))) < DANGER_RANGE:
			continue
		var preview: Dictionary = sim.preview_cast(intent)
		var sample: Variant = preview.get("sample_damage", null)
		var dmg := float(sample) if sample != null else float(def.get("base_damage", 0))
		var chance := float(preview.get("hit_chance", 90)) / 100.0
		var score := dmg * chance
		if not target.is_empty() and dmg >= float(target.get("hp", 999)):
			score += 25.0
		if bool(preview.get("would_stun", false)):
			score += 12.0
		# Melee peels: the enemy nearest the back line is worth more.
		if role == "melee" and not target.is_empty() and not back.is_empty():
			score += maxf(0.0, 4.0 - float(_nearest(_cell(target.get("pos")), back))) * 1.5
		score /= maxf(1.0, float(def.get("ap", 3)) / 3.0)
		if score > best_score:
			best_score = score
			best = intent
	return best


## Kestrel wants a tile with a clear shot (an enemy 2–5 tiles away in sight).
static func _shot_bonus(sim: Node, cell: Vector2i, enemies: Array) -> float:
	if not sim.has_method("has_line_of_sight"):
		return 0.0
	for other in enemies:
		var d := _cheb(cell, other)
		if d >= 2 and d <= RANGED_BAND.y and bool(sim.has_line_of_sight(cell, other)):
			return 4.0
	return 0.0


## No fully safe tile: the reachable tile farthest from the enemies, if it is
## farther than here (Kestrel then has room for Mark Shot, 2+ tiles).
static func _farther_move(moves: Array, here: Vector2i, enemies: Array) -> Dictionary:
	var pick := {}
	var best := _nearest(here, enemies)
	for intent in moves:
		var d := _nearest(_cell(intent.get("to")), enemies)
		if d > best:
			best = d
			pick = intent
	return pick


## The move that best fits the role. `escape`: only moves that leave danger.
static func _best_move(moves: Array, here: Vector2i, role: String, snap: Dictionary, team: int, enemies: Array, sim: Node, actor: Dictionary, escape: bool) -> Dictionary:
	var field := {}
	if role == "melee":
		var sources: Array = enemies
		var back := _back_line(snap, team)
		# Bastion guards the back line: walk toward the enemies nearest it.
		if SpellKits.normalize_class_id(str(actor.get("class_id", ""))) == "bastion" and not back.is_empty():
			var near: Array = []
			var cut := 99
			for cell in enemies:
				cut = mini(cut, _nearest(cell, back))
			for cell in enemies:
				if _nearest(cell, back) <= cut + 1:
					near.append(cell)
			if not near.is_empty():
				sources = near
		field = sim.walk_field(sources)
	var anchor := _healer_anchor(snap, team, int(actor.get("seat", -1)), enemies) if role == "healer" else Vector2i(-99, -99)
	var front := _front_gap(snap, team, int(actor.get("seat", -1)), enemies) if role != "melee" else 99
	var now_score := _place_score(here, role, enemies, field, anchor, front)
	if role == "ranged":
		now_score += _shot_bonus(sim, here, enemies)
	var pick := {}
	var pick_score := now_score
	for intent in moves:
		var to := _cell(intent.get("to"))
		if escape and _nearest(to, enemies) <= DANGER_RANGE:
			continue
		var score := _place_score(to, role, enemies, field, anchor, front)
		if role == "ranged":
			score += _shot_bonus(sim, to, enemies)
		if score > pick_score + 0.001:
			pick_score = score
			pick = intent
	return pick


## Higher is better.
## `front`: how close the nearest melee teammate stands to the enemies (99 when
## none). Healer and ranged never step ahead of it (they used to walk into a
## lane in front of Bastion and block him).
static func _place_score(cell: Vector2i, role: String, enemies: Array, field: Dictionary, anchor: Vector2i, front: int = 99) -> float:
	var d := _nearest(cell, enemies)
	var behind := 0.0
	if front < 99 and d <= front:
		behind = -float(front + 1 - d) * 3.0
	match role:
		"melee":
			if field.has(cell):
				return -absf(float(int(field[cell]) - 1))
			# Route blocked (a teammate in the lane): at least get closer.
			return -float(d) - 20.0
		"ranged":
			var score := behind
			if d < RANGED_BAND.x:
				score -= float(RANGED_BAND.x - d) * 3.0
			elif d > RANGED_BAND.y:
				score -= float(d - RANGED_BAND.y)
			if d <= DANGER_RANGE:
				score -= 10.0
			return score
		"healer":
			var score := behind
			if d < HEALER_SAFE:
				score -= float(HEALER_SAFE - d) * 4.0
			if d <= DANGER_RANGE:
				score -= 10.0
			if anchor.x > -99:
				var reach := _cheb(cell, anchor)
				if reach > HEALER_REACH:
					score -= float(reach - HEALER_REACH) * 2.0
			return score
	return 0.0


## Nearest-enemy distance of the most forward living melee teammate.
static func _front_gap(snap: Dictionary, team: int, self_seat: int, enemies: Array) -> int:
	var best := 99
	for unit in snap.get("units", []):
		if int(unit.get("team", 0)) != team or not bool(unit.get("alive", false)) or int(unit.get("seat", -1)) == self_seat or unit.get("pos") == null:
			continue
		if role_of(str(unit.get("class_id", ""))) != "melee":
			continue
		best = mini(best, _nearest(_cell(unit.get("pos")), enemies))
	return best


## The ally the healer stays in reach of: the most hurt, else the one nearest
## the enemies (the front line).
static func _healer_anchor(snap: Dictionary, team: int, self_seat: int, enemies: Array) -> Vector2i:
	var best := Vector2i(-99, -99)
	var best_key := INF
	for unit in snap.get("units", []):
		if int(unit.get("team", 0)) != team or not bool(unit.get("alive", false)) or int(unit.get("seat", -1)) == self_seat or unit.get("pos") == null:
			continue
		var ratio := float(unit.get("hp", 0)) / maxf(1.0, float(unit.get("max_hp", 1)))
		var cell := _cell(unit.get("pos"))
		var key := ratio * 100.0 + float(_nearest(cell, enemies))
		if key < best_key:
			best_key = key
			best = cell
	return best


static func _best_support(casts: Array, snap: Dictionary, team: int, below: float) -> Dictionary:
	var best := {}
	var best_need := 0.0
	for intent in casts:
		var spell := str(intent.get("spell", ""))
		var def := SpellKits.spell(spell)
		if def.is_empty():
			continue
		var heals := int(def.get("base_heal", 0)) > 0 or int(def.get("shield", 0)) > 0
		if not heals:
			continue
		var target := _unit(snap, int(intent.get("target_seat", -1)))
		if target.is_empty() or int(target.get("team", 0)) != team or not bool(target.get("alive", false)):
			continue
		var max_hp := maxf(1.0, float(target.get("max_hp", 1)))
		var ratio := float(target.get("hp", 0)) / max_hp
		if ratio >= below:
			continue
		var need := (1.0 - ratio) * 100.0 + float(def.get("base_heal", 0)) * 0.2
		if need > best_need:
			best_need = need
			best = intent
	return best


## Healer with nothing to heal: shield the unshielded ally next to an enemy.
static func _front_ward(casts: Array, snap: Dictionary, team: int, enemies: Array) -> Dictionary:
	var best := {}
	var best_d := 2
	for intent in casts:
		var def := SpellKits.spell(str(intent.get("spell", "")))
		if int(def.get("shield", 0)) <= 0 or int(def.get("base_heal", 0)) > 0:
			continue
		var target := _unit(snap, int(intent.get("target_seat", -1)))
		if target.is_empty() or int(target.get("team", 0)) != team or not bool(target.get("alive", false)):
			continue
		if int(target.get("shield", 0)) > 0:
			continue
		var d := _nearest(_cell(target.get("pos")), enemies)
		if d < best_d:
			best_d = d
			best = intent
	return best


## Living teammates who fight from the back (healer, ranged).
static func _back_line(snap: Dictionary, team: int) -> Array:
	var out: Array = []
	for unit in snap.get("units", []):
		if int(unit.get("team", 0)) != team or not bool(unit.get("alive", false)) or unit.get("pos") == null:
			continue
		if role_of(str(unit.get("class_id", ""))) != "melee":
			out.append(_cell(unit.get("pos")))
	return out


static func _enemy_cells(snap: Dictionary, team: int) -> Array:
	var out: Array = []
	for unit in snap.get("units", []):
		if int(unit.get("team", 0)) != team and bool(unit.get("alive", false)) and not bool(unit.get("invisible", false)) and unit.get("pos") != null:
			out.append(_cell(unit.get("pos")))
	return out


static func _nearest(cell: Vector2i, cells: Array) -> int:
	var best := 99
	for other in cells:
		best = mini(best, _cheb(cell, other))
	return best


static func _unit(snap: Dictionary, seat: int) -> Dictionary:
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == seat:
			return unit
	return {}


static func _cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	return Vector2i(-99, -99)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Bastion's Ward (self cast, shields every ally within `ward_radius`): cast it
## when an enemy is within 3 tiles and someone in reach is below the cap.
static func _team_ward(casts: Array, snap: Dictionary, team: int, here: Vector2i, enemies: Array) -> Dictionary:
	for intent in casts:
		var def := SpellKits.spell(str(intent.get("spell", "")))
		if not def.has("ward_radius"):
			continue
		if enemies.is_empty() or _nearest(here, enemies) > 3:
			return {}
		var radius := int(def["ward_radius"])
		for unit in snap.get("units", []):
			if int(unit.get("team", 0)) != team or not bool(unit.get("alive", false)) or unit.get("pos") == null:
				continue
			var cell := _cell(unit.get("pos"))
			if maxi(absi(cell.x - here.x), absi(cell.y - here.y)) > radius:
				continue
			if int(unit.get("shield", 0)) < int(def.get("shield_cap", 40)):
				return intent
	return {}
