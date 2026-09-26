extends RefCounted
class_name StasisAi

## One legal intent for a Stasis foe. Walk closer, then Strike.
## Advance, Shoulder, Crush, and class kits are ignored even if a test feeds them.
## Room A calls this once per living trash seat. CombatSim still resolves the card.


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
