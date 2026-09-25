extends RefCounted
class_name VfxRouter

## Maps combat events to effect recipes. Pure data: no nodes, no rules.
## Values come only from the event and the snapshot. This file does not roll or mitigate.

const SHAKE_SPELLS := ["crush", "aegis_break"]


static func recipes_for(events: Array, _snapshot: Dictionary = {}) -> Array:
	var out: Array = []
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var chunk: Array = _recipes_for_event(event)
		out.append_array(chunk)
	return out


static func blocking_sec(recipes: Array) -> float:
	var block := 0.0
	for item in recipes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		block = maxf(block, float(item.get("block", 0.0)))
	return minf(block, VfxBudget.LOCK_MAX)


static func assign_stacks(recipes: Array) -> Array:
	var counts: Dictionary = {}
	for item in recipes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("id", "")) != "number":
			continue
		var key := "%s|%s" % [str(item.get("seat", -1)), str(item.get("cell", Vector2i.ZERO))]
		var index := int(counts.get(key, 0))
		item["stack"] = index
		counts[key] = index + 1
	return recipes


static func cell_of(value: Variant) -> Vector2i:
	# A redacted Invisible cell is null. That is off the board, not tile (0,0).
	if value == null:
		return Vector2i(-1, -1)
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		var rec: Dictionary = value
		return Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


static func debug_beats() -> Array:
	var caster := Vector2i(2, 3)
	var target := Vector2i(4, 3)
	var pushed := Vector2i(5, 3)
	return [
		{"name": "G1 hit", "events": [_hit("strike", 16, caster, target)]},
		{"name": "G2 miss", "events": [_miss("mark_shot", caster, target)]},
		{"name": "G3 back", "events": [_hit("bash", 13, caster, target, {"back": true, "facing_mult": 1.2})]},
		{"name": "G3 backstab", "events": [_hit("cut", 18, caster, target, {"back": true, "backstab": true, "facing_mult": 1.35})]},
		{"name": "G4 push", "events": [_hit("shoulder", 6, caster, target, {"pushed": true, "push_from": target, "push_to": pushed})]},
		{"name": "G5 push blocked", "events": [{"type": "push_blocked", "seat": 0, "target_seat": 1, "from": target, "attempted": pushed, "reason": "occupied"}]},
		{"name": "G5 plant resist", "events": [{"type": "push_blocked", "seat": 0, "target_seat": 1, "from": target, "attempted": pushed, "reason": "plant_resist"}]},
		{"name": "G6 bounce", "events": [
			{"type": "push_bounce", "seat": 0, "target_seat": 1, "from": target, "attempted": pushed, "to": target, "reason": "out_of_bounds", "stagger_hp": 4, "stagger_mp": 1},
			{"type": "stagger", "target_seat": 1, "stagger_hp": 4, "stagger_mp": 1, "hp_delta": -4, "mp_delta": -1},
		]},
		{"name": "G7 lava parked", "events": [_hit("shoulder", 6, caster, target, {"pushed": true, "push_from": target, "push_to": pushed, "burn_applied": true})]},
		{"name": "G8 burn tick", "events": [{"type": "burn", "status": "burn", "target_seat": 1, "damage": 4, "hp_delta": -4, "remaining": 1}]},
		{"name": "G9 stun", "events": [{"type": "status", "status": "stun", "target_seat": 1, "remaining": 1}]},
		{"name": "G10 heal", "events": [_hit("mend", 0, caster, target, {"healed": 16, "damage": 0, "engine": "pulse", "engine_gained": 1})]},
		{"name": "G11 death", "events": [{"type": "dead", "seat": 1, "name": "Ironjaw"}, {"type": "match_over", "winner_seat": 0}]},
		{"name": "G12 resource", "events": [_hit("strike", 16, caster, target, {"engine": "impact", "engine_gained": 1})]},
		{"name": "shield absorb", "events": [_hit("strike", 4, caster, target, {"shield_absorbed": 12, "shield_remaining": 0, "shield_broken": true})]},
		{"name": "ambush blink", "events": [_hit("ambush", 30, caster, target, {"teleported": true, "origin": Vector2i(2, 4), "destination": Vector2i(4, 4), "backstab": true, "facing_mult": 1.35})]},
		{"name": "hold line", "events": [{
			"type": "hit",
			"spell": "hold_line",
			"seat": 0,
			"caster_cell": caster,
			"damage": 14,
			"bodies": 2,
			"cone": [Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 4)],
			"targets": [
				{"target_seat": 1, "cell": Vector2i(3, 3), "hit": true, "damage": 7, "back": false},
				{"target_seat": 2, "cell": Vector2i(3, 4), "hit": true, "damage": 7, "back": true, "facing_mult": 1.2},
			],
			"engine": "aegis",
			"engine_gained": 1,
		}]},
		{"name": "expire", "events": [{"type": "expire", "status": "stun", "target_seat": 1, "pos": target, "owner_seat": 1}]},
	]


static func _recipes_for_event(event: Dictionary) -> Array:
	var typ := str(event.get("type", ""))
	match typ:
		"hit":
			return _hit_recipes(event)
		"miss":
			return _miss_recipes(event)
		"push_blocked":
			return _blocked_recipes(event)
		"push_bounce":
			return _bounce_recipes(event)
		"stagger":
			return _stagger_recipes(event)
		"status":
			return _status_recipes(event)
		"burn":
			return _burn_tick_recipes(event)
		"dead":
			return [{"id": "death", "block": 0.0, "seat": int(event.get("seat", -1))}]
		"match_over":
			return [{"id": "winner", "block": 0.0, "seat": int(event.get("winner_seat", -1))}]
		"advance":
			return _resource_recipes(event, int(event.get("seat", -1)), cell_of(event.get("to", event.get("caster_cell", Vector2i.ZERO))))
		"cast":
			return _cast_recipes(event)
		"snap_wall":
			return _wall_recipes(event)
		"expire":
			return _expire_recipes(event)
		"intercept":
			return _intercept_recipes(event)
		"end_turn":
			if str(event.get("reason", "")) == "stunned":
				return [{"id": "status_pulse", "block": 0.0, "status": "stun", "seat": int(event.get("seat", -1))}]
			return []
		_:
			return []


static func _hit_recipes(event: Dictionary) -> Array:
	var spell_id := str(event.get("spell", ""))
	var out: Array = []
	if spell_id == "hold_line":
		out.append_array(_hold_line_recipes(event, true))
	elif int(event.get("healed", 0)) > 0:
		out.append_array(_heal_recipes(event))
	elif _is_shield_grant(event):
		out.append_array(_shield_grant_recipes(event))
	elif spell_id == "cleanse":
		out.append(_puff(int(event.get("target_seat", -1)), _target_cell(event), VfxPalette.MENDER_CREAM, 0.85))
	else:
		out.append_array(_damage_hit_recipes(event))
	if bool(event.get("pushed", false)):
		out.append(_slide(event, cell_of(event.get("push_from")), cell_of(event.get("push_to")), VfxBudget.BLOCK_SLIDE))
	if bool(event.get("burn_applied", false)):
		# TODO G7: lava displace splash is parked. No ember burst. Push slide and burn attach still run.
		out.append({"id": "lava_todo", "block": 0.0})
	if bool(event.get("teleported", false)) and event.has("destination"):
		var origin: Vector2i = cell_of(event.get("origin", event.get("caster_cell", Vector2i.ZERO)))
		var dest: Vector2i = cell_of(event.get("destination"))
		out.append({
			"id": "projectile",
			"block": 0.0,
			"from": origin,
			"to": dest,
			"arc": 0.0,
			"overshoot": 0.0,
			"duration": VfxBudget.BLOCK_BLINK,
			"tint": VfxPalette.GLOAM_RIM,
			"width": 4.0,
		})
		var blink := _slide(event, cell_of(event.get("caster_cell", origin)), dest, VfxBudget.BLOCK_BLINK)
		blink["seat"] = int(event.get("seat", -1))
		out.append(blink)
	out.append_array(_resource_recipes(event, int(event.get("seat", -1)), cell_of(event.get("caster_cell", Vector2i.ZERO))))
	if _wants_shake(event):
		out.append({"id": "shake", "block": 0.0, "amplitude": VfxBudget.SHAKE_PX, "duration": VfxBudget.SHAKE_SEC})
	return out


static func _damage_hit_recipes(event: Dictionary) -> Array:
	var out: Array = []
	var target_seat := int(event.get("target_seat", -1))
	var cell := _target_cell(event)
	var damage := int(event.get("damage", 0))
	var tint: Color = VfxPalette.spell_tint(str(event.get("spell", "")))
	if damage > 0:
		out.append({
			"id": "spark",
			"block": 0.0,
			"seat": target_seat,
			"cell": cell,
			"tint": tint,
			"chest": true,
		})
		out.append(_number(target_seat, cell, str(damage), "damage", 0.0, _back_scale(event), _back_text(event, str(damage)), _back_tint(event)))
		var back := _back_tag(event)
		if not back.is_empty():
			out.append(_chevron(target_seat, cell, event))
	var absorbed := int(event.get("shield_absorbed", 0))
	if absorbed > 0:
		out.append(_number(target_seat, cell, str(absorbed), "absorb", 0.0, 1.0, "", Color(0, 0, 0, 0)))
		out.append(_ring(cell, VfxPalette.SHIELD_TOP, false, 0.22, 0.0))
	if bool(event.get("shield_broken", false)):
		out.append(_puff(target_seat, cell, VfxPalette.SHIELD_TOP, 0.9))
	if bool(event.get("immunity_absorbed", false)):
		var swallowed := int(event.get("immunity_amount", 0))
		if swallowed > 0:
			out.append(_number(target_seat, cell, str(swallowed), "absorb", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	return out


static func _heal_recipes(event: Dictionary) -> Array:
	var target_seat := int(event.get("target_seat", -1))
	var cell := _target_cell(event)
	var healed := int(event.get("healed", 0))
	return [
		{"id": "motes", "block": 0.0, "seat": target_seat, "cell": cell, "tint": VfxPalette.MENDER_CREAM, "chest": true},
		_number(target_seat, cell, "+%d" % healed, "heal", 0.0, 1.0, "", Color(0, 0, 0, 0)),
	]


static func _shield_grant_recipes(event: Dictionary) -> Array:
	var target_seat := int(event.get("target_seat", -1))
	var cell := _target_cell(event)
	var amount := int(event.get("shield", 0))
	return [
		_ring(cell, VfxPalette.MENDER, false, 0.35, 0.0),
		_number(target_seat, cell, "+%d" % amount, "shield", 0.0, 1.0, "", Color(0, 0, 0, 0)),
	]


static func _hold_line_recipes(event: Dictionary, connected: bool) -> Array:
	var out: Array = []
	var cone: Array = event.get("cone", [])
	for raw in cone:
		out.append(_ring(cell_of(raw), VfxPalette.BASTION, false, 0.28, 0.0))
	if not connected:
		var at := _centroid(cone)
		if cone.is_empty():
			at = cell_of(event.get("caster_cell", Vector2i.ZERO))
		out.append(_number(-1, at, "MISS", "miss", 0.0, 1.0, "", Color(0, 0, 0, 0)))
		out.append(_puff(int(event.get("seat", -1)), cell_of(event.get("caster_cell", Vector2i.ZERO)), VfxPalette.spell_tint("hold_line"), 0.5))
		return out
	var targets: Array = event.get("targets", [])
	if targets.is_empty() and int(event.get("damage", 0)) > 0:
		out.append(_number(int(event.get("seat", -1)), cell_of(event.get("caster_cell", Vector2i.ZERO)), str(int(event.get("damage", 0))), "damage", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	for raw in targets:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		if not bool(row.get("hit", false)):
			continue
		var cell := cell_of(row.get("cell", Vector2i.ZERO))
		var seat := int(row.get("target_seat", -1))
		var damage := int(row.get("damage", 0))
		if damage <= 0:
			continue
		out.append({"id": "spark", "block": 0.0, "seat": seat, "cell": cell, "tint": VfxPalette.BASTION, "chest": true})
		out.append(_number(seat, cell, str(damage), "damage", 0.0, _back_scale(row), _back_text(row, str(damage)), _back_tint(row)))
		if not _back_tag(row).is_empty():
			out.append(_chevron(seat, cell, event))
		var absorbed := int(row.get("shield_absorbed", 0))
		if absorbed > 0:
			out.append(_number(seat, cell, str(absorbed), "absorb", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	return out


static func _miss_recipes(event: Dictionary) -> Array:
	var spell_id := str(event.get("spell", ""))
	var out: Array = []
	var caster_seat := int(event.get("seat", -1))
	var caster_cell := cell_of(event.get("caster_cell", Vector2i.ZERO))
	var tint: Color = VfxPalette.spell_tint(spell_id)
	if spell_id == "hold_line":
		out.append_array(_hold_line_recipes(event, false))
		return out
	out.append(_puff(caster_seat, caster_cell, tint, 0.5))
	var at := cell_of(event.get("to", caster_cell))
	if not event.has("to"):
		at = caster_cell
	out.append(_number(int(event.get("target_seat", -1)), at, "MISS", "miss", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	if event.has("to") or event.has("caster_cell"):
		out.append({
			"id": "projectile",
			"block": 0.0,
			"from": caster_cell,
			"to": at,
			"arc": 10.0,
			"overshoot": 12.0,
			"duration": 0.22,
			"tint": tint,
			"width": 3.0,
		})
	if event.has("origin"):
		out.append(_puff(caster_seat, cell_of(event.get("origin")), VfxPalette.GLOAM, 0.45))
	return out


static func _blocked_recipes(event: Dictionary) -> Array:
	var seat := int(event.get("target_seat", -1))
	var from_cell := cell_of(event.get("from", Vector2i.ZERO))
	var attempted := cell_of(event.get("attempted", from_cell))
	var out: Array = [{
		"id": "jolt",
		"block": VfxBudget.BLOCK_JOLT,
		"seat": seat,
		"from": from_cell,
		"attempted": attempted,
		"distance": 4.0,
	}]
	out.append(_ring(attempted, VfxPalette.IRONJAW_DUST, false, 0.18, 0.0))
	if str(event.get("reason", "")) == "plant_resist":
		out.append(_ring(from_cell, VfxPalette.BASTION, false, 0.28, 0.0))
	return out


static func _bounce_recipes(event: Dictionary) -> Array:
	var seat := int(event.get("target_seat", -1))
	var from_cell := cell_of(event.get("from", Vector2i.ZERO))
	var attempted := cell_of(event.get("attempted", from_cell))
	return [{
		"id": "bounce",
		"block": VfxBudget.BLOCK_BOUNCE,
		"seat": seat,
		"from": from_cell,
		"attempted": attempted,
		"distance": 8.0,
		"tint": VfxPalette.KESTREL_AIR,
	}]


static func _stagger_recipes(event: Dictionary) -> Array:
	var seat := int(event.get("target_seat", -1))
	var cell := cell_of(event.get("from", Vector2i.ZERO))
	var out: Array = []
	var hp := int(event.get("stagger_hp", 0))
	if hp <= 0:
		hp = absi(int(event.get("hp_delta", 0)))
	if hp > 0:
		out.append(_number(seat, cell, "-%d" % hp, "stagger", VfxBudget.STAGGER_DELAY, 1.0, "", Color(0, 0, 0, 0)))
	var mp := int(event.get("stagger_mp", 0))
	if mp <= 0:
		mp = absi(int(event.get("mp_delta", 0)))
	if mp > 0:
		out.append(_number(seat, cell, "-%d MP" % mp, "mp", VfxBudget.STAGGER_DELAY + 0.06, 1.0, "", Color(0, 0, 0, 0)))
	return out


static func _status_recipes(event: Dictionary) -> Array:
	var status := str(event.get("status", ""))
	if status != "burn" and status != "stun":
		return []
	return [{
		"id": "status_on",
		"block": 0.0,
		"status": status,
		"seat": int(event.get("target_seat", -1)),
		"cell": cell_of(event.get("pos", Vector2i.ZERO)),
	}]


static func _burn_tick_recipes(event: Dictionary) -> Array:
	var seat := int(event.get("target_seat", -1))
	var amount := int(event.get("damage", 0))
	if amount <= 0:
		amount = absi(int(event.get("hp_delta", 0)))
	var out: Array = [{
		"id": "status_on",
		"block": 0.0,
		"status": "burn",
		"seat": seat,
		"cell": cell_of(event.get("pos", Vector2i.ZERO)),
		"flare": true,
	}]
	if amount > 0:
		out.append(_number(seat, Vector2i.ZERO, "-%d" % amount, "burn", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	return out


static func _cast_recipes(event: Dictionary) -> Array:
	var spell_id := str(event.get("spell", ""))
	var out: Array = []
	var cell := cell_of(event.get("to", Vector2i.ZERO))
	if spell_id == "drop_shade" and event.has("to"):
		out.append(_ring(cell, VfxPalette.GLOAM_RIM, true, 0.0, 0.35))
	elif spell_id == "plant" and event.has("to"):
		out.append(_ring(cell, VfxPalette.BASTION, true, 0.0, 0.0))
	out.append_array(_resource_recipes(event, int(event.get("seat", -1)), cell_of(event.get("caster_cell", Vector2i.ZERO))))
	return out


static func _wall_recipes(event: Dictionary) -> Array:
	var out: Array = []
	if event.has("to"):
		out.append(_ring(cell_of(event.get("to")), VfxPalette.BASTION_BLACK, true, 0.0, 0.0))
	out.append_array(_resource_recipes(event, int(event.get("seat", -1)), cell_of(event.get("caster_cell", event.get("to", Vector2i.ZERO)))))
	return out


static func _expire_recipes(event: Dictionary) -> Array:
	var status := str(event.get("status", ""))
	var cell := cell_of(event.get("pos", Vector2i.ZERO))
	var seat := int(event.get("target_seat", event.get("owner_seat", -1)))
	return [{
		"id": "status_off",
		"block": 0.0,
		"status": status,
		"seat": seat,
		"cell": cell,
	}]


static func _intercept_recipes(event: Dictionary) -> Array:
	var seat := int(event.get("interceptor_seat", -1))
	var cell := cell_of(event.get("interceptor_cell", Vector2i.ZERO))
	var amount := int(event.get("damage", 0))
	var out: Array = []
	if amount > 0:
		out.append(_number(seat, cell, str(amount), "damage", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	if event.has("for_cell"):
		out.append({
			"id": "projectile",
			"block": 0.0,
			"from": cell_of(event.get("for_cell")),
			"to": cell,
			"arc": 0.0,
			"overshoot": 0.0,
			"duration": 0.16,
			"tint": VfxPalette.BASTION,
			"width": 2.0,
		})
	return out


static func _resource_recipes(event: Dictionary, seat: int, cell: Vector2i) -> Array:
	var out: Array = []
	var engine := _engine_name(event)
	var gained := int(event.get("engine_gained", 0))
	if gained <= 0 and int(event.get("impact_gained", 0)) > 0:
		gained = int(event.get("impact_gained", 0))
	var spent := int(event.get("engine_spent", 0))
	if spent <= 0:
		spent = int(event.get("aegis_spent", 0))
	if gained > 0 and engine != "":
		out.append(_number(seat, cell, "+%d %s" % [gained, VfxPalette.engine_label(engine)], "resource", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	if spent > 0 and engine != "":
		out.append(_number(seat, cell, "-%d %s" % [spent, VfxPalette.engine_label(engine)], "resource", 0.0, 1.0, "", Color(0, 0, 0, 0)))
		if event.has("caster_cell") and (event.has("to") or event.has("target_seat")):
			out.append({
				"id": "motes",
				"block": 0.0,
				"seat": seat,
				"cell": cell_of(event.get("caster_cell")),
				"tint": VfxPalette.spell_tint(str(event.get("spell", ""))),
				"chest": true,
			})
	return out


static func _engine_name(event: Dictionary) -> String:
	var engine := str(event.get("engine", ""))
	if engine == "" and int(event.get("impact_gained", 0)) > 0:
		engine = "impact"
	if engine == "":
		var def: Dictionary = SpellKits.spell(str(event.get("spell", "")))
		var raw := str(def.get("engine_on_connect", ""))
		if raw == "impact" or raw == "spend_impact":
			engine = "impact"
		elif raw == "mark" or raw == "consume_marks":
			engine = "mark"
		elif raw == "umbral":
			engine = "umbral"
		elif raw == "aegis" or raw == "clear_aegis" or raw == "spend_aegis":
			engine = "aegis"
		elif raw == "pulse" or raw == "spend_pulse":
			engine = "pulse"
		elif raw == "impact_if_adjacent":
			engine = "impact"
	return engine


static func _wants_shake(event: Dictionary) -> bool:
	return str(event.get("type", "")) == "hit" and str(event.get("spell", "")) in SHAKE_SPELLS


static func _is_shield_grant(event: Dictionary) -> bool:
	if int(event.get("damage", 0)) > 0 or int(event.get("healed", 0)) > 0:
		return false
	var spell_id := str(event.get("spell", ""))
	if spell_id == "ward":
		return int(event.get("shield", 0)) > 0
	var def: Dictionary = SpellKits.spell(spell_id)
	return int(def.get("shield", 0)) > 0 and int(event.get("shield", 0)) > 0


static func _target_cell(event: Dictionary) -> Vector2i:
	if event.has("to"):
		return cell_of(event.get("to"))
	if event.has("destination"):
		return cell_of(event.get("destination"))
	return cell_of(event.get("caster_cell", Vector2i.ZERO))


static func _back_tag(row: Dictionary) -> Dictionary:
	var backstab := bool(row.get("backstab", false))
	var mult := float(row.get("facing_mult", 1.0))
	var back := bool(row.get("back", false)) or backstab or mult > 1.01
	if not back:
		return {}
	if backstab or mult >= 1.3:
		return {"tag": "BACKSTAB", "scale": 1.3}
	return {"tag": "BACK", "scale": 1.15}


static func _back_scale(row: Dictionary) -> float:
	var tag := _back_tag(row)
	return float(tag.get("scale", 1.0))


static func _back_text(row: Dictionary, amount: String) -> String:
	var tag := _back_tag(row)
	if tag.is_empty():
		return amount
	return "%s %s" % [str(tag.get("tag", "")), amount]


static func _back_tint(row: Dictionary) -> Color:
	var tag := _back_tag(row)
	if str(tag.get("tag", "")) == "BACKSTAB":
		return VfxPalette.GLOAM_RIM
	return Color(0, 0, 0, 0)


static func _number(seat: int, cell: Vector2i, text: String, kind: String, delay: float, pop: float, override_text: String, tint: Color) -> Dictionary:
	var shown := override_text if override_text != "" else text
	var spec := {
		"id": "number",
		"block": 0.0,
		"seat": seat,
		"cell": cell,
		"text": shown,
		"kind": kind,
		"delay": delay,
		"scale": pop,
	}
	if tint.a > 0.0:
		spec["tint"] = tint
	return spec


static func _slide(event: Dictionary, from_cell: Vector2i, to_cell: Vector2i, block: float) -> Dictionary:
	return {
		"id": "slide",
		"block": block,
		"seat": int(event.get("target_seat", event.get("seat", -1))),
		"from": from_cell,
		"to": to_cell,
		"tint": VfxPalette.dust_tint(str(event.get("spell", ""))),
	}


static func _puff(seat: int, cell: Vector2i, tint: Color, alpha: float) -> Dictionary:
	return {
		"id": "puff",
		"block": 0.0,
		"seat": seat,
		"cell": cell,
		"tint": tint,
		"alpha": alpha,
	}


static func _ring(cell: Vector2i, tint: Color, linger: bool, life: float, swirl: float) -> Dictionary:
	return {
		"id": "ring",
		"block": 0.0,
		"cell": cell,
		"tint": tint,
		"linger": linger,
		"life": life,
		"swirl": swirl,
	}


static func _chevron(seat: int, cell: Vector2i, event: Dictionary) -> Dictionary:
	return {
		"id": "chevron",
		"block": 0.0,
		"seat": seat,
		"cell": cell,
		"from": cell_of(event.get("caster_cell", Vector2i.ZERO)),
		"tint": VfxPalette.KESTREL_AIR,
	}


static func _centroid(cells: Array) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	var x := 0
	var y := 0
	for raw in cells:
		var cell := cell_of(raw)
		x += cell.x
		y += cell.y
	return Vector2i(int(x / cells.size()), int(y / cells.size()))


static func _hit(spell_id: String, damage: int, caster: Vector2i, target: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var event := {
		"type": "hit",
		"spell": spell_id,
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": target,
		"damage": damage,
		"healed": 0,
	}
	for key in extra.keys():
		event[key] = extra[key]
	return event


static func _miss(spell_id: String, caster: Vector2i, target: Vector2i) -> Dictionary:
	return {
		"type": "miss",
		"spell": spell_id,
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": target,
		"damage": 0,
	}
