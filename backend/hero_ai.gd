extends RefCounted

## AI companion for a dungeon party seat (Mauro 1 Oct 2026: "if no healer is
## found give the option to fill with AI"). Cheap heuristic, phone friendly:
## no sim cloning. One call returns one intent; call again until end_turn.
##   1. Heal / shield a hurt teammate (Mender first).
##   2. The best expected hit (damage × hit chance, kill and stun bonuses).
##   3. Walk toward the class's fighting distance from the nearest enemy.
##   4. End the turn.
## Rules stay in CombatSim: everything offered comes from legal_intents.

const IDEAL_RANGE := {"kestrel": 4, "ironjaw": 1, "mender": 3, "gloam": 1, "bastion": 1}
const HEAL_BELOW := 0.65
const MIN_HIT_SCORE := 2.0


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
	# 0. Bring a fallen teammate back (Mender's Rekindle, once per match).
	for intent in casts:
		if str(SpellKits.spell(str(intent.get("spell", ""))).get("target", "")) == "fallen_ally":
			return intent
	# 1. Support a hurt teammate.
	var heal := _best_support(casts, snap, team)
	if not heal.is_empty():
		return heal
	# 2. Best expected hit.
	var best := {}
	var best_score := MIN_HIT_SCORE
	for intent in casts:
		var spell := str(intent.get("spell", ""))
		var def := SpellKits.spell(spell)
		if def.is_empty() or not str(def.get("target", "")) in ["enemy", "burst", "cone", "any"]:
			continue
		var target := _unit(snap, int(intent.get("target_seat", -1)))
		if str(def.get("target", "")) == "any" and (target.is_empty() or int(target.get("team", 0)) == team):
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
		score /= maxf(1.0, float(def.get("ap", 3)) / 3.0)
		if score > best_score:
			best_score = score
			best = intent
	if not best.is_empty():
		return best
	# 3. Walk the real route (around walls) to the class's fighting distance
	# from the enemies: melee closes in, ranged stops at its band.
	if not moves.is_empty() and int(actor.get("mp", 0)) > 0:
		var sources: Array = []
		for unit in snap.get("units", []):
			if int(unit.get("team", 0)) != team and bool(unit.get("alive", false)) and not bool(unit.get("invisible", false)) and unit.get("pos") != null:
				sources.append(_cell(unit.get("pos")))
		if not sources.is_empty():
			var field: Dictionary = sim.walk_field(sources)
			var ideal := int(IDEAL_RANGE.get(str(actor.get("class_id", "")), 1))
			var here := _cell(actor.get("pos"))
			var now_gap := absi(int(field.get(here, 99)) - ideal)
			var pick := {}
			var pick_gap := now_gap
			for intent in moves:
				var to := _cell(intent.get("to"))
				var gap := absi(int(field.get(to, 99)) - ideal)
				if gap < pick_gap:
					pick_gap = gap
					pick = intent
			if not pick.is_empty():
				return pick
	return end_turn


static func _best_support(casts: Array, snap: Dictionary, team: int) -> Dictionary:
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
		if ratio >= HEAL_BELOW:
			continue
		var need := (1.0 - ratio) * 100.0 + float(def.get("base_heal", 0)) * 0.2
		if need > best_need:
			best_need = need
			best = intent
	return best


static func _nearest_enemy(snap: Dictionary, actor: Dictionary) -> Dictionary:
	var best := {}
	var best_d := 999
	var here := _cell(actor.get("pos"))
	for unit in snap.get("units", []):
		if int(unit.get("team", 0)) == int(actor.get("team", 0)) or not bool(unit.get("alive", false)):
			continue
		if bool(unit.get("invisible", false)) or unit.get("pos") == null:
			continue
		var d := _cheb(here, _cell(unit.get("pos")))
		if d < best_d:
			best_d = d
			best = unit
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
