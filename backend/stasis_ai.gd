extends RefCounted
class_name StasisAi

## One legal intent for a Stasis foe. Walk closer, then Strike.
## Advance, Shoulder, Crush, and class kits are ignored even if a test feeds them.
## Room A calls this once per living trash seat. CombatSim still resolves the card.
## Walk choices come from legal_intents. Those use the player WalkBoard
## gates: mud, water, and lava are voluntary impassable.


static func choose(legal: Array, actor_pos: Vector2i, foe_pos: Vector2i) -> Dictionary:
	var strike: Dictionary = {}
	var best_move: Dictionary = {}
	var best_score := 1 << 30
	var end_turn: Dictionary = {}
	for item in legal:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = item
		var kind := str(intent.get("type", ""))
		if kind == "cast" and str(intent.get("spell", "")) == StasisCatalog.STRIKE_CARD:
			strike = intent
		elif kind == "move":
			var dest: Vector2i = _cell(intent.get("to", actor_pos))
			var score := _chebyshev(dest, foe_pos) * 100 + absi(dest.x - foe_pos.x) + absi(dest.y - foe_pos.y)
			if score < best_score:
				best_score = score
				best_move = intent
		elif kind == "end_turn":
			end_turn = intent
	if not strike.is_empty():
		return strike
	if not best_move.is_empty():
		return best_move
	if not end_turn.is_empty():
		return end_turn
	return {"type": "end_turn", "seat": StasisCatalog.ENEMY_SEAT}


## Kit planner (Mauro's Stasis kit sheets, 29 Sep 2026). One intent per call;
## the fight scene calls again until the monster ends its turn.
##  - An area spell that is ready and hits the player goes first (answers:
##    "AOE first if it hits 2+ bodies"; solo Stasis has one body, so it fires
##    whenever it connects, then waits a turn on its cooldown).
##  - Then the hardest single hit that is legal.
##  - Casters and ranged bosses never walk into 0–1 when a shot is legal; with
##    no shot they walk to a tile 3+ away that sees the player.
##  - Melee bodies walk in. Serra / Coilspire step away when crowded.
##  - Sheaf Wall when there is AP left and nothing to hit.
const FoeKits := preload("res://backend/foe_kits.gd")


static func plan(sim: Node, seat: int) -> Dictionary:
	var legal: Array = sim.legal_intents(seat)
	var snap: Dictionary = sim.snapshot()
	var actor := _unit(snap, seat)
	var kit: Array = actor.get("foe_kit", []) if actor.get("foe_kit", []) is Array else []
	var player := _unit(snap, 0)
	var actor_pos: Vector2i = _cell(actor.get("pos", Vector2i.ZERO))
	var foe_pos: Vector2i = _cell(player.get("pos", Vector2i.ZERO))
	if kit.is_empty():
		return choose(legal, actor_pos, foe_pos)
	for intent in legal:
		if bool(intent.get("auto", false)):
			return intent
	var role := str(actor.get("foe_role", ""))
	var door := str(actor.get("foe_door", ""))
	var ranged := role == "caster" or (role == "boss" and FoeKits.RANGED_BOSS.has(door))
	var casts: Array = []
	var moves: Array = []
	var end_turn := {"type": "end_turn", "seat": seat}
	for intent in legal:
		match str(intent.get("type", "")):
			"cast":
				casts.append(intent)
			"move":
				moves.append(intent)
			"end_turn":
				end_turn = intent
	var dist := _chebyshev(actor_pos, foe_pos)
	# 1. Area spell that connects.
	for intent in casts:
		if FoeKits.is_aoe(str(intent["spell"])):
			return intent
	# 2. Hardest single hit.
	var best := {}
	var best_dmg := -1
	for intent in casts:
		var def := FoeKits.spell(str(intent["spell"]))
		var shape := str(def.get("shape", ""))
		if shape in ["step", "self"]:
			continue
		var dmg := int(def.get("damage", 0))
		if dmg <= 0:
			dmg = 1
		if dmg > best_dmg:
			best_dmg = dmg
			best = intent
	if not best.is_empty():
		return best
	# 3. Crowded ranged boss: step away.
	if ranged and dist <= 2:
		var away := _best_step(casts, foe_pos, actor_pos)
		if not away.is_empty():
			return away
	# 4. Walk.
	if not moves.is_empty() and int(actor.get("mp", 0)) > 0:
		var walk := _ranged_walk(sim, moves, actor_pos, foe_pos, kit) if ranged else _melee_walk(moves, actor_pos, foe_pos)
		if not walk.is_empty():
			return walk
	# 5. Ward with spare AP.
	for intent in casts:
		if str(FoeKits.spell(str(intent["spell"])).get("shape", "")) == "self":
			return intent
	return end_turn


static func _melee_walk(moves: Array, actor_pos: Vector2i, foe_pos: Vector2i) -> Dictionary:
	var best := {}
	var best_score := _chebyshev(actor_pos, foe_pos) * 100 + absi(actor_pos.x - foe_pos.x) + absi(actor_pos.y - foe_pos.y)
	for intent in moves:
		var dest: Vector2i = _cell(intent.get("to", actor_pos))
		var score := _chebyshev(dest, foe_pos) * 100 + absi(dest.x - foe_pos.x) + absi(dest.y - foe_pos.y)
		if score < best_score:
			best_score = score
			best = intent
	return best


## Walk to a tile that has a legal shot: in the band and in sight. Prefer the
## band's middle and the shortest walk. Else close the gap (or open it).
static func _ranged_walk(sim: Node, moves: Array, actor_pos: Vector2i, foe_pos: Vector2i, kit: Array) -> Dictionary:
	var lo := 99
	var hi := 0
	for id in kit:
		var def := FoeKits.spell(str(id))
		if str(def.get("shape", "")) == "shot":
			lo = mini(lo, int(def.get("min", 3)))
			hi = maxi(hi, int(def.get("max", 7)))
	if hi == 0:
		return _melee_walk(moves, actor_pos, foe_pos)
	var best := {}
	var best_score := 1 << 30
	var here := _chebyshev(actor_pos, foe_pos)
	for intent in moves:
		var dest: Vector2i = _cell(intent.get("to", actor_pos))
		var d := _chebyshev(dest, foe_pos)
		var score := 0
		if d >= maxi(lo, 3) and d <= hi and sim.has_line_of_sight(dest, foe_pos):
			score = absi(d - (maxi(lo, 3) + 1)) * 10 + _chebyshev(dest, actor_pos)
		else:
			var gap := (maxi(lo, 3) - d) if d < maxi(lo, 3) else (d - hi if d > hi else 0)
			score = 1000 + gap * 100 + (0 if d <= hi else d)
		if score < best_score:
			best_score = score
			best = intent
	if best.is_empty():
		return {}
	# Do not shuffle in place: only walk when it helps.
	var now_ok: bool = here >= maxi(lo, 3) and here <= hi and sim.has_line_of_sight(actor_pos, foe_pos)
	if now_ok:
		return {}
	var cur_gap := (maxi(lo, 3) - here) if here < maxi(lo, 3) else (here - hi if here > hi else 0)
	if best_score >= 1000 and best_score >= 1000 + cur_gap * 100:
		return {}
	return best


static func _best_step(casts: Array, foe_pos: Vector2i, actor_pos: Vector2i) -> Dictionary:
	var best := {}
	var best_d := _chebyshev(actor_pos, foe_pos)
	for intent in casts:
		if str(FoeKits.spell(str(intent["spell"])).get("shape", "")) != "step":
			continue
		var d := _chebyshev(_cell(intent["to"]), foe_pos)
		if d > best_d:
			best_d = d
			best = intent
	return best


static func _unit(snap: Dictionary, seat: int) -> Dictionary:
	for unit in snap.get("units", []):
		if typeof(unit) == TYPE_DICTIONARY and int(unit.get("seat", -1)) == seat:
			return unit
	return {}


static func _cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int((value as Array)[0]), int((value as Array)[1]))
	return Vector2i.ZERO


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
