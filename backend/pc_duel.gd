extends RefCounted

## Koliseo spread-against-spread, scored by seeded fights in CombatSim.
## Same class, both fighters at the full point budget. Swift's Initiative
## only decides who acts first. Its damage bonus is the rewards-file
## bonus_damage rate, applied as extra damage done. No extra turns.
## No global class. Loaded with preload.

const CombatSim = preload("res://backend/combat_sim.gd")
const CLASSES: Array[String] = ["kestrel", "ironjaw", "mender", "gloam", "bastion"]
const SEEDS := 200
const TURN_CAP := 96
const ACTION_CAP := 8

static var _sim: Node = null


static func table(hero, seeds: int = SEEDS, damage_override: float = -1.0) -> Dictionary:
	var budget := int(hero.points_per_level) * maxi(int(hero.max_level) - 1, 0)
	var half := int(budget / 2)
	var all_mastery := _spread(budget, 0, 0, 0)
	var all_vitality := _spread(0, budget, 0, 0)
	var all_resist := _spread(0, 0, budget, 0)
	var all_swift := _spread(0, 0, 0, budget)
	var mix := _spread(half, budget - half, 0, 0)
	var specs: Array = [
		["all Mastery vs all Vitality", all_mastery, all_vitality],
		["all Mastery vs all Resist", all_mastery, all_resist],
		["all Vitality vs all Resist", all_vitality, all_resist],
		["mix vs all Mastery", mix, all_mastery],
		["mix vs all Vitality", mix, all_vitality],
		["mix vs all Resist", mix, all_resist],
		["mix vs all Swift", mix, all_swift],
		["all Swift vs all Mastery", all_swift, all_mastery],
		["all Swift vs all Vitality", all_swift, all_vitality],
		["all Swift vs all Resist", all_swift, all_resist],
	]
	var pairs: Array = []
	var worst_gap := -1.0
	var worst_win := 0.5
	var worst_label := ""
	var inside := true
	var resist_best := 1.0
	var win_min := float(hero.duel_min)
	var win_max := float(hero.duel_max)
	for spec in specs:
		var row: Array = spec
		var label := str(row[0])
		var left: Dictionary = row[1]
		var right: Dictionary = row[2]
		var scored: Dictionary = win_rate(hero, left, right, seeds, damage_override)
		var win := float(scored["win"])
		pairs.append({
			"label": label,
			"left": left,
			"right": right,
			"win": win,
			"draws": float(scored["draws"]),
			"by_class": scored["by_class"],
		})
		var gap := absf(win - 0.5)
		if gap > worst_gap:
			worst_gap = gap
			worst_win = win
			worst_label = label
		if win + 0.0000001 < win_min or win - 0.0000001 > win_max:
			inside = false
		if int(left.get("Resist", 0)) == budget and int(left.get("Mastery", 0)) == 0:
			resist_best = minf(resist_best, win)
		if int(right.get("Resist", 0)) == budget and int(right.get("Mastery", 0)) == 0:
			resist_best = minf(resist_best, 1.0 - win)
	var cap_points := float(hero.resist_cap_points())
	var wasted := float(budget) - cap_points
	if wasted < 0.0:
		wasted = 0.0
	var swift_losses := 0
	for entry in pairs:
		var pair: Dictionary = entry
		var left_spend: Dictionary = pair["left"]
		if int(left_spend.get("Swift", 0)) == budget and float(pair["win"]) + 0.0000001 < win_min:
			swift_losses += 1
	var none := _spread(0, 0, 0, 0)
	var sanity: Array = [
		_sanity_row(hero, "all Mastery vs no points", all_mastery, none, seeds, damage_override),
		_sanity_row(hero, "all Vitality vs no points", all_vitality, none, seeds, damage_override),
		_sanity_row(hero, "all Resist vs no points", all_resist, none, seeds, damage_override),
		_sanity_row(hero, "all Swift vs no points", all_swift, none, seeds, damage_override),
		_sanity_row(hero, "all Mastery mirror", all_mastery, all_mastery, seeds, damage_override),
	]
	return {
		"budget": budget,
		"mix": mix,
		"pairs": pairs,
		"worst_win": worst_win,
		"worst_label": worst_label,
		"win_min": win_min,
		"win_max": win_max,
		"inside": inside,
		"resist_cap_points": cap_points,
		"resist_wasted": wasted,
		"resist_flag": wasted > 0.0,
		"resist_best": resist_best,
		"resist_weak": resist_best < 0.5,
		"swift_dead": swift_losses == 3,
		"seeds": seeds,
		"classes": CLASSES,
		"model": "combat_sim",
		"swift_damage": _swift_damage_rate(hero, damage_override),
		"class_fails": _class_fails(pairs),
		"sanity": sanity,
	}


static func _sanity_row(hero, label: String, left: Dictionary, right: Dictionary, seeds: int, damage_override: float) -> Dictionary:
	var scored: Dictionary = win_rate(hero, left, right, seeds, damage_override)
	return {"label": label, "win": float(scored["win"]), "by_class": scored["by_class"]}


static func win_rate(hero, left: Dictionary, right: Dictionary, seeds: int = SEEDS, damage_override: float = -1.0) -> Dictionary:
	var wins := 0.0
	var draws := 0.0
	var total := 0
	var by_class := {}
	var class_index := 0
	for class_id in CLASSES:
		var class_wins := 0.0
		var class_n := 0
		for n in seeds:
			var seed := class_index * 10007 + n + 1
			var result := _fight(hero, class_id, left, right, seed, damage_override)
			class_n += 1
			total += 1
			if result < 0:
				class_wins += 0.5
				wins += 0.5
				draws += 1.0
			else:
				class_wins += float(result)
				wins += float(result)
		by_class[class_id] = class_wins / float(class_n) if class_n > 0 else 0.5
		class_index += 1
	var rate := 0.5
	if total > 0:
		rate = wins / float(total)
	return {"win": rate, "draws": draws / float(maxi(total, 1)), "by_class": by_class}


static func _fight(hero, class_id: String, left: Dictionary, right: Dictionary, seed: int, damage_override: float) -> int:
	if _sim == null:
		_sim = CombatSim.new()
	var left_init := _initiative(hero, left)
	var right_init := _initiative(hero, right)
	var left_seat := 0
	if right_init > left_init:
		left_seat = 1
	elif right_init == left_init and (seed % 2) == 1:
		left_seat = 1
	_sim.reset_match({
		"seed": seed,
		"classes": [class_id, class_id],
		"positions": [Vector2i(2, 2), Vector2i(4, 2)],
		"flat_board": true,
		"quiet": true,
	})
	_apply_spread(_sim._units[0], hero, left if left_seat == 0 else right, damage_override)
	_apply_spread(_sim._units[1], hero, right if left_seat == 0 else left, damage_override)
	_sim._units[0]["facing"] = "E"
	_sim._units[1]["facing"] = "W"
	var guard := 0
	while not _sim._match_over and int(_sim._turn_index) < TURN_CAP and guard < 800:
		guard += 1
		var seat := int(_sim._active_seat)
		_play_turn(seat)
		if _sim._match_over:
			break
		if int(_sim._active_seat) == seat and int(_sim._turn_index) < TURN_CAP:
			_sim.submit({"type": "end_turn", "seat": seat})
	if not _sim._match_over:
		return -1
	if int(_sim._winner_seat) == left_seat:
		return 1
	return 0


static func _play_turn(seat: int) -> void:
	var spins := 0
	while spins < ACTION_CAP and not _sim._match_over and int(_sim._active_seat) == seat:
		spins += 1
		if not _try_action(seat):
			_sim.submit({"type": "end_turn", "seat": seat})
			return
	if not _sim._match_over and int(_sim._active_seat) == seat:
		_sim.submit({"type": "end_turn", "seat": seat})


static func _try_action(seat: int) -> bool:
	var actor: Dictionary = _sim._unit_by_seat(seat)
	var enemy: Dictionary = _sim._unit_by_seat(1 if seat == 0 else 0)
	if actor.is_empty() or enemy.is_empty():
		return false
	var class_id := str(actor.get("class_id", ""))
	var from: Vector2i = actor["pos"]
	var to: Vector2i = enemy["pos"]
	var dist := _dist(from, to)
	var ap := int(actor.get("ap", 0))
	match class_id:
		"kestrel":
			# Mark Shot starts at range 2. Stepping into melee leaves Kestrel unable to shoot.
			if dist < 2:
				return _step_away(actor, to)
			if int(enemy.get("marks", 0)) >= 1 and dist <= 4 and ap >= 3:
				return _cast(seat, "detonate", to)
			if dist <= 7 and ap >= 2:
				return _cast(seat, "mark_shot", to)
			if dist > 7:
				return _step(actor, to)
			return false
		"ironjaw":
			if int(actor.get("impact", 0)) >= 2 and dist == 1 and ap >= 4:
				return _cast(seat, "crush", to)
			if dist == 1 and ap >= 3:
				return _cast(seat, "strike", to)
			if dist == 1 and ap >= 2:
				return _cast(seat, "shoulder", to)
			return _step(actor, to)
		"mender":
			# Cleanse banks Pulse without a heal, so the mirror is a damage race
			# instead of two Mend loops that erase Heartstop.
			if int(actor.get("pulse", 0)) >= 4 and dist <= 3 and ap >= 5:
				return _cast(seat, "heartstop", to)
			if ap >= 2 and int(actor.get("pulse", 0)) < 4:
				return _cast(seat, "cleanse", from)
			if dist > 3:
				return _step(actor, to)
			return false
		"gloam":
			if dist == 1 and ap >= 3:
				return _cast(seat, "cut", to)
			return _step(actor, to)
		"bastion":
			if int(actor.get("aegis", 0)) >= 3 and dist >= 1 and dist <= 2 and ap >= 4:
				return _cast(seat, "aegis_break", to)
			if dist == 1 and ap >= 3:
				return _cast(seat, "bash", to)
			return _step(actor, to)
		_:
			return false


static func _cast(seat: int, spell: String, dest: Vector2i) -> bool:
	var result: Dictionary = _sim.submit({"type": "cast", "seat": seat, "spell": spell, "to": dest})
	return bool(result.get("ok", false))


static func _step(actor: Dictionary, goal: Vector2i) -> bool:
	if int(actor.get("mp", 0)) <= 0:
		return false
	var from: Vector2i = actor["pos"]
	var seat := int(actor.get("seat", 0))
	var best := Vector2i(-1, -1)
	var best_dist := _dist(from, goal)
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var step := delta as Vector2i
		var dest: Vector2i = from + step
		if dest == goal:
			continue
		var next := _dist(dest, goal)
		if next < best_dist:
			best_dist = next
			best = dest
	if best.x < 0:
		return false
	var result: Dictionary = _sim.submit({"type": "move", "seat": seat, "to": best})
	return bool(result.get("ok", false))


static func _step_away(actor: Dictionary, threat: Vector2i) -> bool:
	if int(actor.get("mp", 0)) <= 0:
		return false
	var from: Vector2i = actor["pos"]
	var seat := int(actor.get("seat", 0))
	var best := Vector2i(-1, -1)
	var best_dist := _dist(from, threat)
	var limit := int(CombatSim.BOARD_SIZE)
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var step := delta as Vector2i
		var dest: Vector2i = from + step
		if dest.x < 0 or dest.y < 0 or dest.x >= limit or dest.y >= limit:
			continue
		var next := _dist(dest, threat)
		if next > best_dist:
			best_dist = next
			best = dest
	if best.x < 0:
		return false
	var result: Dictionary = _sim.submit({"type": "move", "seat": seat, "to": best})
	return bool(result.get("ok", false))


static func _apply_spread(unit: Dictionary, hero, spread: Dictionary, damage_override: float) -> void:
	var mastery_pts := int(spread.get("Mastery", 0))
	var vitality_pts := int(spread.get("Vitality", 0))
	var resist_pts := int(spread.get("Resist", 0))
	var swift_pts := int(spread.get("Swift", 0))
	var per: Dictionary = hero.stat_per_point
	var mastery: Dictionary = per.get("Mastery", {})
	var vitality: Dictionary = per.get("Vitality", {})
	var resist: Dictionary = per.get("Resist", {})
	var damage_rate := float(mastery.get("damage_done", 0.0))
	var hp_rate := float(vitality.get("max_hp", 0.0))
	var taken_rate := float(resist.get("damage_taken", 0.0))
	var cap := float(resist.get("cap", 1.0))
	unit["mastery"] = damage_rate * 100.0 * float(mastery_pts)
	unit["bonus_damage"] = _swift_damage_rate(hero, damage_override) * 100.0 * float(swift_pts)
	var red := taken_rate * float(resist_pts)
	if red > cap:
		red = cap
	unit["resist"] = red * 100.0
	var hp := roundi(float(CombatSim.START_HP) * (1.0 + hp_rate * float(vitality_pts)))
	unit["hp"] = hp
	unit["max_hp"] = hp


static func _initiative(hero, spread: Dictionary) -> int:
	var swift: Dictionary = hero.stat_per_point.get("Swift", {})
	var each := int(swift.get("initiative", 0))
	return int(spread.get("Swift", 0)) * each


static func _swift_damage_rate(hero, damage_override: float) -> float:
	if damage_override >= 0.0:
		return damage_override
	var swift: Dictionary = hero.stat_per_point.get("Swift", {})
	return float(swift.get("bonus_damage", 0.0))


static func _class_fails(pairs: Array) -> Array:
	var fails: Array = []
	for entry in pairs:
		var pair: Dictionary = entry
		var by: Dictionary = pair["by_class"]
		for class_id in by.keys():
			var win := float(by[class_id])
			if win + 0.0000001 < 0.35 or win - 0.0000001 > 0.65:
				fails.append({
					"label": str(pair["label"]),
					"class": str(class_id),
					"win": win,
				})
	return fails


static func _spread(mastery: int, vitality: int, resist: int, swift: int) -> Dictionary:
	return {"Mastery": mastery, "Vitality": vitality, "Resist": resist, "Swift": swift}


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
