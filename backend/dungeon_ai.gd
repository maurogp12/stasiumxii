extends RefCounted

## Monster AI for PC dungeon rooms (and a simple hero bot for tests and the
## capture movie). Preload. No global class.
##
## Monster rule, one intent per call (the caller submits it and asks again):
## 1. Boss signature (summon) when CombatSim says it is ready.
## 2. Attack the hero when in range and AP covers it.
## 3. Walk: pick the reachable cell with the shortest walking distance to a
##    cell that can attack the hero. Distances are a breadth-first flood over
##    walkable cells, so crates and walls are walked round, not pushed into.
##    Live bodies only block the final stand cell, so a monster stuck behind
##    another one still closes in on the next free lane.
## 4. Face the hero once, then end the turn.
## Every call either spends AP or MP, turns to face, or ends the turn, so a
## monster turn always ends. The driver also caps a turn at MAX_STEPS.

const MAX_STEPS := 12
const UNREACHED := 1 << 20


static func next_intent(sim: Node, seat: int, faced: bool = false) -> Dictionary:
	var snap: Dictionary = sim.snapshot()
	var end := {"type": "end_turn", "seat": seat}
	if bool(snap.get("match_over", false)) or int(snap.get("active_seat", -1)) != seat:
		return {}
	var legal: Array = sim.legal_intents(seat)
	if legal.is_empty():
		return {}
	var actor := _unit(snap, seat)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return end
	for intent in legal:
		if str(intent.get("type", "")) == "end_turn" and bool(intent.get("auto", false)):
			return intent
	var sig: Dictionary = actor.get("signature", {})
	var attack: Dictionary = actor.get("attack", {})
	for intent in legal:
		if str(intent.get("type", "")) == "cast" and not sig.is_empty() and str(intent.get("spell", "")) == str(sig.get("id", "")):
			return intent
	for intent in legal:
		if str(intent.get("type", "")) == "cast" and str(intent.get("spell", "")) == str(attack.get("id", "")):
			return intent
	var hero := _unit(snap, 0)
	if hero.is_empty() or not bool(hero.get("alive", false)):
		return end
	var moves: Array = []
	for intent in legal:
		if str(intent.get("type", "")) == "move":
			moves.append(intent)
	if not moves.is_empty() and int(actor.get("ap", 0)) >= int(attack.get("ap", 0)):
		var field := attack_field(snap, hero["pos"], int(attack.get("min_range", 1)), int(attack.get("max_range", 1)))
		var here: Vector2i = _cell(actor["pos"])
		var here_d := int(field.get(here, UNREACHED))
		var best: Dictionary = {}
		var best_key := [here_d, _cheb(here, _cell(hero["pos"])), 0]
		for intent in moves:
			var to := _cell(intent["to"])
			var d := int(field.get(to, UNREACHED))
			var key := [d, _cheb(to, _cell(hero["pos"])), to.y * 100 + to.x]
			if _less(key, best_key):
				best_key = key
				best = intent
		if not best.is_empty():
			return best
	elif not moves.is_empty():
		# No AP left for the attack: still close the gap for next turn.
		var near: Dictionary = {}
		var near_d := _cheb(_cell(actor["pos"]), _cell(hero["pos"]))
		for intent in moves:
			var d := _cheb(_cell(intent["to"]), _cell(hero["pos"]))
			if d < near_d and d >= 1:
				near_d = d
				near = intent
		if not near.is_empty():
			return near
	if not faced:
		var face := face_toward(_cell(actor["pos"]), _cell(hero["pos"]))
		if face != "" and face != str(actor.get("facing", "")):
			return {"type": "face", "dir": face, "seat": seat}
	return end


## Walking distance (ortho steps over walkable cells) from every cell to the
## nearest cell that can hit `target` with an attack of that range. Bodies are
## ignored here; legal_intents already keeps them off the stand cells.
static func attack_field(snap: Dictionary, target: Variant, min_range: int, max_range: int) -> Dictionary:
	var size := int(snap.get("board_size", 12))
	var walk := walkable_cells(snap)
	var goal := _cell(target)
	var dist := {}
	var queue: Array[Vector2i] = []
	for cell in walk.keys():
		var c: Vector2i = cell
		var d := _cheb(c, goal)
		if d >= min_range and d <= max_range:
			dist[c] = 0
			queue.append(c)
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + step
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= size or nxt.y >= size:
				continue
			if not walk.has(nxt) or dist.has(nxt):
				continue
			dist[nxt] = int(dist[cur]) + 1
			queue.append(nxt)
	return dist


static func walkable_cells(snap: Dictionary) -> Dictionary:
	var out := {}
	var tiles: Variant = snap.get("tiles", {})
	if typeof(tiles) == TYPE_DICTIONARY:
		for key in (tiles as Dictionary).keys():
			var rec: Dictionary = tiles[key]
			if bool(rec.get("walkable", true)):
				out[_cell(rec.get("pos", key))] = true
	return out


static func face_toward(from: Vector2i, to: Vector2i) -> String:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return ""
	if absi(delta.x) >= absi(delta.y):
		return "E" if delta.x > 0 else "W"
	return "S" if delta.y > 0 else "N"


## Plays one whole monster turn on the sim with no view. Returns the intents
## it submitted. Used by tests and by the headless run; the room view plays
## the same intents one at a time with animation.
static func play_monster_turn(sim: Node, seat: int) -> Array:
	var done: Array = []
	var faced := false
	for i in MAX_STEPS:
		var intent := next_intent(sim, seat, faced)
		if intent.is_empty():
			return done
		if str(intent.get("type", "")) == "face":
			faced = true
		var result: Dictionary = sim.submit(intent)
		done.append({"intent": intent, "ok": bool(result.get("ok", false))})
		if str(intent.get("type", "")) == "end_turn":
			return done
		if not bool(result.get("ok", false)):
			break
	var snap: Dictionary = sim.snapshot()
	if not bool(snap.get("match_over", false)) and int(snap.get("active_seat", -1)) == seat:
		var forced: Dictionary = sim.submit({"type": "end_turn", "seat": seat})
		done.append({"intent": {"type": "end_turn", "seat": seat, "forced": true}, "ok": bool(forced.get("ok", false))})
	return done


# --- Hero bot (tests, capture movie). Not used by a player. ---------------

## One hero intent: heal when low, else the strongest legal hit on the
## weakest monster, else walk toward the nearest monster, else end turn.
static func hero_intent(sim: Node) -> Dictionary:
	var snap: Dictionary = sim.snapshot()
	if bool(snap.get("match_over", false)) or int(snap.get("active_seat", -1)) != 0:
		return {}
	var legal: Array = sim.legal_intents(0)
	var hero := _unit(snap, 0)
	if hero.is_empty():
		return {}
	for intent in legal:
		if bool(intent.get("auto", false)):
			return intent
	var low := float(hero.get("hp", 0)) < float(hero.get("max_hp", 80)) * 0.45
	var best: Dictionary = {}
	var best_score := -1.0
	for intent in legal:
		if str(intent.get("type", "")) != "cast":
			continue
		var def: Dictionary = SpellKits.spell(str(intent.get("spell", "")))
		if def.is_empty():
			continue
		var target_seat := int(intent.get("target_seat", -1))
		var score := -1.0
		if target_seat == 0:
			if low and int(def.get("base_heal", 0)) > 0:
				score = 100.0 + float(def.get("base_heal", 0))
			elif str(def.get("engine_on_connect", "")) == "pulse":
				# Builds the resource a finisher spends (Mender's Pulse).
				score = 1.0
		elif target_seat > 0:
			var foe := _unit(snap, target_seat)
			var dmg := float(def.get("base_damage", 0))
			if str(def.get("id", "")) == SpellKits.DETONATE:
				dmg += 4.0 * float(foe.get("marks", 0))
			if dmg <= 0.0:
				continue
			score = dmg * 2.0 - float(foe.get("hp", 0)) * 0.05
			if bool(foe.get("boss", false)):
				score += 6.0
		elif str(def.get("target", "")) in ["cone", "burst"]:
			score = float(def.get("base_damage", 0)) * 1.5
		if score > best_score:
			best_score = score
			best = intent
	if not best.is_empty():
		return best
	var reach := _hero_reach(hero)
	var reach_min := 1
	var reach_max := 1
	if not reach.is_empty():
		reach_min = int(reach[0])
		reach_max = int(reach[1])
	var moves: Array = []
	for intent in legal:
		if str(intent.get("type", "")) == "move":
			moves.append(intent)
	if not moves.is_empty() and int(hero.get("ap", 0)) >= 3:
		var foes: Array = []
		for unit in snap.get("units", []):
			if int(unit.get("seat", 0)) > 0 and bool(unit.get("alive", false)):
				foes.append(unit)
		if not foes.is_empty():
			var fields: Array = []
			for foe in foes:
				fields.append(attack_field(snap, foe["pos"], reach_min, reach_max))
			var here := _cell(hero["pos"])
			var best_d := _field_min(fields, here)
			var pick: Dictionary = {}
			for intent in moves:
				var d := _field_min(fields, _cell(intent["to"]))
				if d < best_d:
					best_d = d
					pick = intent
			if not pick.is_empty():
				return pick
	return {"type": "end_turn", "seat": 0}


static func play_hero_turn(sim: Node) -> Array:
	var done: Array = []
	for i in MAX_STEPS:
		var intent := hero_intent(sim)
		if intent.is_empty():
			return done
		var result: Dictionary = sim.submit(intent)
		done.append({"intent": intent, "ok": bool(result.get("ok", false))})
		if str(intent.get("type", "")) == "end_turn" or not bool(result.get("ok", false)):
			break
	var snap: Dictionary = sim.snapshot()
	if not bool(snap.get("match_over", false)) and int(snap.get("active_seat", -1)) == 0:
		sim.submit({"type": "end_turn", "seat": 0})
	return done


## Range band [min, max] of the hero's hardest-hitting single-target spell.
static func _hero_reach(hero: Dictionary) -> Array:
	var best := -1
	var out: Array = []
	for spell_id in hero.get("spells", []):
		var def: Dictionary = SpellKits.spell(str(spell_id))
		var target := str(def.get("target", "enemy"))
		if int(def.get("base_damage", 0)) <= 0 or not target in ["enemy", "any", "burst"]:
			continue
		if str(spell_id) == SpellKits.AMBUSH or SpellKits.is_gated(str(spell_id)):
			continue
		var dmg := int(def.get("base_damage", 0)) * maxi(6 / maxi(int(def.get("ap", 6)), 1), 1)
		if dmg > best:
			best = dmg
			out = [maxi(int(def.get("min_range", 1)), 1), mini(int(def.get("max_range", 1)), 5)]
	return out


static func _field_min(fields: Array, cell: Vector2i) -> int:
	var best := UNREACHED
	for field in fields:
		best = mini(best, int((field as Dictionary).get(cell, UNREACHED)))
	return best


static func _unit(snap: Dictionary, seat: int) -> Dictionary:
	for unit in snap.get("units", []):
		if int(unit.get("seat", -1)) == seat:
			return unit
	return {}


static func _cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _less(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false
