extends RefCounted
class_name VfxRouter

## Maps combat events to effect recipes. Pure data: no nodes, no rules.
## Values come only from the event and the snapshot. This file does not roll or mitigate.

const SHAKE_SPELLS := ["crush", "aegis_break"]
const STRIPS := preload("res://units/strip_library.gd")
## Camera shake on heavy connects. Crush and Aegis Break always shake.
const HEAVY_HIT_DAMAGE := 20
## Bolt travel after the arrow leaves. Contact is this gap later, inside 0.2–0.4s.
## Not a kit number. The cast strip itself stays the 300ms holds.
const MARK_FLIGHT_SEC := 0.24
const STAMP := preload("res://vfx/vfx_stamp.gd")


## Departure dust for a successful Ambush. The board plays this when the
## collapse starts, not when the slash is armed. A miss has no departure.
static func ambush_collapse_specs(event: Dictionary) -> Array:
	if str(event.get("spell", "")) != "ambush" and str(event.get("spell", "")) != SpellKits.AMBUSH:
		return []
	if str(event.get("type", "")) != "hit":
		return []
	var row := event.duplicate(true)
	row["present_phase"] = "collapse"
	row["teleported"] = true
	var specs: Array = []
	for item in recipes_for([row]):
		if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == "puff":
			specs.append(item)
	return specs


static func recipes_for(events: Array, snapshot: Dictionary = {}) -> Array:
	var out: Array = []
	var boss_fx_seen := {}
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var chunk: Array = _recipes_for_event(event)
		chunk.append_array(_choreography(event, snapshot))
		for spec in chunk:
			# One painted boss effect per cast, however many heroes it hits.
			if typeof(spec) == TYPE_DICTIONARY and str(spec.get("id", "")) == "boss_fx":
				var key := "%s|%s|%s" % [spec.get("path", ""), spec.get("cell", ""), spec.get("seat", -1)]
				if boss_fx_seen.has(key):
					continue
				boss_fx_seen[key] = true
			out.append(spec)
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
		{"name": "K1 Mark Shot", "events": [_hit("mark_shot", 8, caster, target, {"engine": "mark", "engine_gained": 1})]},
		{"name": "K2 Detonate", "events": [_hit("detonate", 24, caster, target, {"marks_consumed": 3, "marks_remaining": 0, "engine": "mark", "engine_spent": 3})]},
		{"name": "K2 Detonate miss", "events": [_miss("detonate", caster, target, {"marks_retained": true, "marks_on_target": 2})]},
		{"name": "I1 Advance", "events": [{"type": "advance", "seat": 0, "from": caster, "to": Vector2i(2, 4), "teleport": true, "impact_gained": 1, "adjacent": true}]},
		{"name": "I2 Strike", "events": [_hit("strike", 16, caster, target, {"engine": "impact", "engine_gained": 1})]},
		{"name": "I3 Shoulder", "events": [_hit("shoulder", 6, caster, target, {"pushed": true, "push_from": target, "push_to": pushed, "engine": "impact", "engine_gained": 1})]},
		{"name": "I4 Crush", "events": [_hit("crush", 24, caster, target, {"impact_before": 4, "impact_spent": 2, "stun_applied": 1, "engine": "impact", "engine_spent": 2})]},
		{"name": "M1 Mend", "events": [_hit("mend", 0, caster, target, {"healed": 16, "damage": 0, "engine": "pulse", "engine_gained": 1})]},
		{"name": "M1 Mend triage", "events": [_hit("mend", 0, caster, target, {"healed": 20, "damage": 0, "triage": true, "engine": "pulse", "engine_gained": 1})]},
		{"name": "M2 Pulse Tap", "events": [_hit("pulse_tap", 0, caster, caster, {"target_seat": 0, "healed": 10, "damage": 0, "to": caster, "engine": "pulse", "engine_spent": 1})]},
		{"name": "M3 Ward", "events": [_hit("ward", 0, caster, caster, {"target_seat": 0, "healed": 0, "damage": 0, "to": caster, "shield": 20, "engine": "pulse", "engine_spent": 2})]},
		{"name": "M4 Cleanse", "events": [_hit("cleanse", 0, caster, target, {"healed": 0, "damage": 0, "cc_removed": ["stun"], "engine": "pulse", "engine_gained": 1})]},
		{"name": "M4 Cleanse empty", "events": [_hit("cleanse", 0, caster, target, {"healed": 0, "damage": 0, "cc_removed": [], "engine": "pulse", "engine_gained": 1})]},
		{"name": "M5 Heartstop ally", "events": [_hit("heartstop", 0, caster, caster, {"target_seat": 0, "healed": 40, "damage": 0, "to": caster, "triage": true, "hit_immunity": 1, "engine": "pulse", "engine_spent": 4})]},
		{"name": "M5 Heartstop enemy", "events": [_hit("heartstop", 10, caster, target, {"skip_next_mp": true, "engine": "pulse", "engine_spent": 4})]},
		{"name": "Gl1 Cut", "events": [_hit("cut", 13, caster, target, {"engine": "umbral", "engine_gained": 1})]},
		{"name": "Gl2 Drop Shade", "events": [{"type": "cast", "spell": "drop_shade", "seat": 0, "caster_cell": caster, "to": Vector2i(3, 4), "shades": 1}]},
		{"name": "Gl3 Ambush", "events": [_hit("ambush", 30, caster, target, {"teleported": true, "origin": Vector2i(2, 4), "destination": Vector2i(4, 4), "backstab": true, "facing_mult": 1.35})]},
		{"name": "Gl4 Fade", "events": [{"type": "cast", "spell": "fade", "seat": 0, "caster_cell": caster, "invisible": true, "engine": "umbral", "engine_gained": 1}]},
		{"name": "Gl5 Nightfold parked", "events": [{"type": "cast", "spell": "nightfold", "seat": 0, "caster_cell": caster, "to": Vector2i(3, 5)}]},
		{"name": "B1 Bash", "events": [_hit("bash", 11, caster, target, {"engine": "aegis", "engine_gained": 1})]},
		{"name": "B2 Plant", "events": [{"type": "cast", "spell": "plant", "seat": 0, "caster_cell": caster, "to": Vector2i(3, 3), "engine": "aegis", "engine_gained": 1}]},
		{"name": "B3 Hold Line", "events": [{
			"type": "hit", "spell": "hold_line", "seat": 0, "caster_cell": caster, "damage": 7, "bodies": 1,
			"cone": [Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 4)],
			"targets": [{"target_seat": 1, "cell": target, "hit": true, "damage": 7, "exit_tax": 1, "back": false}],
			"engine": "aegis", "engine_gained": 1,
		}]},
		{"name": "B4 Snap Wall", "events": [{"type": "snap_wall", "spell": "snap_wall", "seat": 0, "caster_cell": caster, "to": Vector2i(3, 2), "aegis_spent": 2, "turns": 2}]},
		{"name": "B5 Aegis Break", "events": [_hit("aegis_break", 26, caster, Vector2i(4, 3), {"aegis_spent": 4, "stacks_cleared": true, "engine": "aegis", "engine_spent": 4})]},
		{"name": "B6 Intercept", "events": [{"type": "intercept", "interceptor_seat": 0, "for_seat": 1, "interceptor_cell": caster, "for_cell": target, "damage": 4, "hp": 76}]},
		{"name": "G11 burn", "events": [{"type": "dead", "seat": 1, "name": "Kestrel", "cause": "burn"}]},
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
			return [{
				"id": "death",
				"block": 0.0,
				"seat": int(event.get("seat", -1)),
				"cause": str(event.get("cause", "damage")),
			}]
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
		"blend":
			return _blend_recipes(event)
		"magma":
			var at := cell_of(event.get("to", Vector2i.ZERO))
			return [_number(int(event.get("target_seat", -1)), at, "-%d MAGMA" % int(event.get("damage", 0)), "damage", 0.0, 1.0, "", Color(1.0, 0.42, 0.1))]
		"end_turn":
			if str(event.get("reason", "")) == "stunned":
				return [{"id": "status_pulse", "block": 0.0, "status": "stun", "seat": int(event.get("seat", -1))}]
			return []
		_:
			return []


## Elements Step 3: the Blend name pops over the target in the pair's colours,
## a ring flares, and a Drift-Pin / Spark slide moves the body.
const BLEND_TINT := {
	"drift_pin": Color(0.66, 0.74, 0.58), "spark": Color(1.0, 0.7, 0.35), "sleet": Color(0.5, 0.8, 1.0),
	"magma": Color(1.0, 0.42, 0.1), "mire": Color(0.5, 0.55, 0.45), "steam": Color(0.88, 0.92, 0.96),
}


## Painted Blend effects (build_tools/art/blend_fx.py, Mauro 5 Oct 2026:
## "Can you add some visual effect to every element blend?"). 192x192 cells,
## anchor = the target's feet. `ground` effects draw under the fighter.
const BLEND_FX_DIR := "res://art/vfx/blends/"
const BLEND_FX_ANCHOR := Vector2(96, 150)
## World px per cell px: a 192 cell covers about 1.6 tiles.
const BLEND_FX_SCALE := 0.55
const BLEND_FX := {
	"drift_pin": {"frames": 12, "fps": 16.0, "ground": false},
	"spark": {"frames": 12, "fps": 18.0, "ground": false},
	"sleet": {"frames": 12, "fps": 15.0, "ground": false},
	"magma": {"frames": 12, "fps": 15.0, "ground": true},
	"mire": {"frames": 12, "fps": 15.0, "ground": true},
	"steam": {"frames": 12, "fps": 13.0, "ground": false},
}
## Lingering tiles: looping ground strips while the tile is on the board.
const BLEND_TILE_FX := {
	"magma": {"frames": 8, "fps": 9.0},
	"steam": {"frames": 8, "fps": 8.0},
}


static func blend_fx_path(blend: String) -> String:
	return BLEND_FX_DIR + "blend_%s.png" % blend


static func blend_tile_spec(kind: String, cell: Vector2i) -> Dictionary:
	var fx: Dictionary = BLEND_TILE_FX.get(kind, {})
	if fx.is_empty():
		return {}
	return {
		"pool": "strip",
		"cell": cell,
		"path": BLEND_FX_DIR + "blend_%s_loop.png" % kind,
		"frames": int(fx["frames"]),
		"fps": float(fx["fps"]),
		"anchor": BLEND_FX_ANCHOR,
		"scale": BLEND_FX_SCALE,
		"loop": true,
	}


static func _blend_recipes(event: Dictionary) -> Array:
	var seat := int(event.get("target_seat", -1))
	var to := cell_of(event.get("to", Vector2i.ZERO))
	var blend := str(event.get("blend", ""))
	var tint: Color = BLEND_TINT.get(blend, Color.WHITE)
	var out: Array = []
	var from := cell_of(event.get("from", to))
	if from != to:
		out.append(_slide(event, from, to, VfxBudget.BLOCK_SLIDE))
	if BLEND_FX.has(blend):
		var fx: Dictionary = BLEND_FX[blend]
		out.append({
			"id": "blend_fx",
			"block": 0.0,
			"seat": seat,
			"cell": to,
			"path": blend_fx_path(blend),
			"frames": int(fx["frames"]),
			"fps": float(fx["fps"]),
			"anchor": BLEND_FX_ANCHOR,
			"scale": BLEND_FX_SCALE,
			"ground": bool(fx["ground"]),
			"delay": 0.05,
		})
	out.append(_ring(to, tint, false, 0.45, 0.8, "sigil"))
	out.append(_number(seat, to, str(event.get("name", "BLEND")).to_upper() + "!", "triage", 0.1, 1.3, "", tint))
	if int(event.get("chip", 0)) > 0:
		out.append(_number(seat, to, "-%d" % int(event.get("chip", 0)), "damage", 0.35, 1.0, "", Color(0, 0, 0, 0)))
	if int(event.get("collision_hp", 0)) > 0:
		out.append(_number(seat, to, "-%d" % int(event.get("collision_hp", 0)), "damage", 0.35, 1.0, "", Color(0, 0, 0, 0)))
	return out


static func _hit_recipes(event: Dictionary) -> Array:
	var spell_id := str(event.get("spell", ""))
	if spell_id == "nightfold":
		# Gated. No per-body damage until the rule is stamped.
		return []
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
	if bool(event.get("teleported", false)) and event.has("destination") and str(event.get("spell", "")) != "ambush":
		# Streak only. The body snaps in BoardView. A slide from caster_cell
		# was a dash from Gloam instead of an instant teleport.
		# Ambush does not streak. It collapses, snaps, then slashes.
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
	out.append_array(_resource_recipes(event, int(event.get("seat", -1)), cell_of(event.get("caster_cell", Vector2i.ZERO))))
	if _wants_shake(event):
		out.append({"id": "shake", "block": 0.0, "amplitude": VfxBudget.SHAKE_PX, "duration": VfxBudget.SHAKE_SEC})
	return out


static func _damage_hit_recipes(event: Dictionary) -> Array:
	var out: Array = []
	var target_seat := int(event.get("target_seat", -1))
	var cell := _target_cell(event)
	var damage := int(event.get("damage", 0))
	var spell_id := str(event.get("spell", ""))
	var tint: Color = VfxPalette.foe_tint(event) if bool(event.get("foe", false)) else VfxPalette.spell_tint(spell_id)
	if damage > 0:
		var spark := {
			"id": "spark",
			"block": 0.0,
			"seat": target_seat,
			"cell": cell,
			"tint": tint,
			"chest": true,
		}
		if spell_id == "strike" or spell_id == "shoulder" or spell_id == "crush":
			spark["delay"] = STRIPS.release_sec("ironjaw", "attack")
		elif spell_id == "cut":
			spark["delay"] = STRIPS.release_sec("gloam", "attack")
		elif spell_id == "ambush":
			# Armed after the snap. The number is the existing facing resolution.
			spark["delay"] = ViewMotion.ambush_contact_sec()
		elif spell_id == "mark_shot":
			spark["delay"] = _mark_impact_delay()
		elif spell_id == "detonate":
			spark["delay"] = STRIPS.release_sec("kestrel", "cast")
		elif bool(event.get("foe", false)) and _foe_is_bolt(spell_id):
			spark["delay"] = _foe_bolt_land(event)
		elif bool(event.get("foe", false)) and BOSS_FX.has(spell_id):
			spark["delay"] = boss_fx_impact_sec(spell_id)
		if spell_id == "detonate":
			var marks := maxi(int(event.get("marks_consumed", 1)), 1)
			spark["amount"] = clampi(8 + (marks - 1) * 4, 8, VfxBudget.SPARK_CAP)
		out.append(spark)
		var number_delay := float(spark.get("delay", 0.0))
		out.append(_hit_flash(target_seat, cell, number_delay))
		out.append(_damage_float(target_seat, cell, number_delay))
		out.append(_number(target_seat, cell, str(damage), "damage", number_delay, _back_scale(event), _back_text(event, str(damage)), _back_tint(event)))
		var back := _back_tag(event)
		if not back.is_empty():
			out.append(_chevron(target_seat, cell, event))
	var absorbed := int(event.get("shield_absorbed", 0))
	if absorbed > 0:
		out.append(_number(target_seat, cell, str(absorbed), "absorb", 0.0, 1.0, "", Color(0, 0, 0, 0)))
		out.append(_ring(cell, VfxPalette.SHIELD_TOP, false, 0.22, 0.0))
		out.append({"id": "status_pulse", "block": 0.0, "status": "shield", "seat": target_seat})
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
		out.append(_hit_flash(seat, cell, 0.0))
		out.append(_damage_float(seat, cell, 0.0))
		out.append(_number(seat, cell, str(damage), "damage", 0.0, _back_scale(row), _back_text(row, str(damage)), _back_tint(row)))
		if not _back_tag(row).is_empty():
			out.append(_chevron(seat, cell, event))
		var absorbed := int(row.get("shield_absorbed", 0))
		if absorbed > 0:
			out.append(_number(seat, cell, str(absorbed), "absorb", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	return out


static func _miss_recipes(event: Dictionary) -> Array:
	var spell_id := str(event.get("spell", ""))
	if spell_id == "nightfold":
		return []
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
	# Invisible Ambush aims from Gloam. A miss does not throw a slash at the
	# enemy: the whiff and the MISS stay on the caster tile. A Shade miss
	# also does not streak onto the prey. That streak was the remote slash.
	var ambush_origin := caster_cell
	var ambush_self := false
	if spell_id == "ambush":
		if event.has("origin"):
			ambush_origin = cell_of(event.get("origin"))
		ambush_self = ambush_origin == caster_cell
		if ambush_self:
			at = caster_cell
	out.append(_number(int(event.get("target_seat", -1)), at, "MISS", "miss", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	if spell_id != "ambush" and (event.has("to") or event.has("caster_cell")):
		var whiff_from := caster_cell
		var whiff_arc := 10.0
		var whiff_overshoot := 12.0
		var whiff_duration := 0.22
		if spell_id == "ambush" and event.has("origin"):
			whiff_from = ambush_origin
			whiff_arc = 0.0
			whiff_overshoot = 0.0
			whiff_duration = VfxBudget.BLOCK_BLINK
		var whiff := {
			"id": "projectile",
			"block": 0.0,
			"from": whiff_from,
			"to": at,
			"arc": whiff_arc,
			"overshoot": whiff_overshoot,
			"duration": whiff_duration,
			"tint": tint,
			"width": 3.0,
			"whiff": whiff_overshoot > 0.0,
		}
		if spell_id == "mark_shot" or spell_id == "detonate":
			whiff["hand"] = true
			whiff["seat"] = caster_seat
		if spell_id == "mark_shot":
			whiff["delay"] = _mark_windup_sec()
		elif spell_id == "detonate":
			whiff["delay"] = STRIPS.release_sec("kestrel", "cast")
		out.append(whiff)
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
		out.append(_hit_flash(seat, cell, VfxBudget.STAGGER_DELAY))
		out.append(_damage_float(seat, cell, VfxBudget.STAGGER_DELAY))
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
		var burn_cell := cell_of(event.get("pos", Vector2i.ZERO))
		out.append(_hit_flash(seat, burn_cell, 0.0))
		out.append(_damage_float(seat, burn_cell, 0.0))
		out.append(_number(seat, Vector2i.ZERO, "-%d" % amount, "burn", 0.0, 1.0, "", Color(0, 0, 0, 0)))
	return out


static func _cast_recipes(event: Dictionary) -> Array:
	var spell_id := str(event.get("spell", ""))
	var out: Array = []
	var cell := cell_of(event.get("to", Vector2i.ZERO))
	if spell_id == "plant" and event.has("to"):
		out.append(_ring(cell, VfxPalette.BASTION, true, 0.0, 0.0, "sigil"))
	out.append_array(_resource_recipes(event, int(event.get("seat", -1)), cell_of(event.get("caster_cell", Vector2i.ZERO))))
	return out


static func _wall_recipes(event: Dictionary) -> Array:
	var out: Array = []
	if event.has("to"):
		out.append(_ring(cell_of(event.get("to")), VfxPalette.BASTION_BLACK, true, 0.0, 0.0, "slab"))
	out.append_array(_resource_recipes(event, int(event.get("seat", -1)), cell_of(event.get("caster_cell", event.get("to", Vector2i.ZERO)))))
	return out


static func _expire_recipes(event: Dictionary) -> Array:
	var status := str(event.get("status", ""))
	# A redacted (secret) Shade has no cell for this viewer: nothing to show.
	if status == "shade" and not event.has("pos"):
		return []
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
		out.append(_hit_flash(seat, cell, 0.0))
		out.append(_damage_float(seat, cell, 0.0))
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
	if str(event.get("type", "")) != "hit":
		return false
	if str(event.get("spell", "")) in SHAKE_SPELLS:
		return true
	return int(event.get("damage", 0)) >= HEAVY_HIT_DAMAGE


static func _is_shield_grant(event: Dictionary) -> bool:
	if int(event.get("damage", 0)) > 0 or int(event.get("healed", 0)) > 0:
		return false
	var spell_id := str(event.get("spell", ""))
	if spell_id == "ward":
		return int(event.get("shield", 0)) > 0
	var def: Dictionary = SpellKits.spell(spell_id)
	return int(def.get("shield", 0)) > 0 and int(event.get("shield", 0)) > 0


static func _target_cell(event: Dictionary) -> Vector2i:
	# Ambush `to` / `destination` are the back tile. The struck body is `from`.
	if str(event.get("spell", "")) == "ambush" and event.has("from"):
		return cell_of(event.get("from"))
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
		return {"tag": "BACKSTAB", "scale": 1.55}
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


static func _ring(cell: Vector2i, tint: Color, linger: bool, life: float, swirl: float, style: String = "") -> Dictionary:
	var spec := {
		"id": "ring",
		"block": 0.0,
		"cell": cell,
		"tint": tint,
		"linger": linger,
		"life": life,
		"swirl": swirl,
	}
	if style != "":
		spec["style"] = style
	return spec


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


## Per-class beats from the VFX plan. Appended after the generic recipes so
## pass-1 numbers, shakes, and slides stay first. Nothing here rolls or mitigates.
static func _choreography(event: Dictionary, snapshot: Dictionary) -> Array:
	var spell_id := str(event.get("spell", ""))
	var typ := str(event.get("type", ""))
	var out: Array = []
	if bool(event.get("foe", false)):
		return _foe_choreography(event)
	var caster := int(event.get("seat", -1))
	var caster_cell := cell_of(event.get("caster_cell", Vector2i.ZERO))
	var target := int(event.get("target_seat", -1))
	var to_cell := cell_of(event.get("to", caster_cell)) if event.has("to") else caster_cell
	if typ == "advance":
		var origin := cell_of(event.get("from", caster_cell))
		var dest := cell_of(event.get("to", origin))
		out.append(_puff(caster, origin, VfxPalette.IRONJAW_EARTH, 0.8))
		out.append(_ring(dest, VfxPalette.IRONJAW_DUST, false, 0.22, 0.0, "crack"))
		if int(event.get("impact_gained", 0)) > 0:
			out.append(_status_on("impact", caster, dest, _stack_count(snapshot, caster, "impact", int(event.get("impact_gained", 1)))))
		return out
	if typ == "intercept":
		out.append(_ring(cell_of(event.get("interceptor_cell", Vector2i.ZERO)), VfxPalette.BASTION, false, 0.24, 0.0))
		return out
	if (typ == "hit" or typ == "miss") and _shows_melee_windup(spell_id):
		# Anticipation on the caster. Life meets the contact instant so the
		# flash, burst, float, and flinch still share that resolve.
		var wind_life := ViewMotion.damage_resolve_sec(spell_id)
		if wind_life < 0.12:
			wind_life = 0.18
		var wind := _stamp("melee_windup", caster, caster_cell, 0.0, VfxBudget.STAMP_MELEE_PX, wind_life)
		wind["aim"] = to_cell
		out.append(wind)
	match spell_id:
		"mark_shot":
			if typ == "hit" or typ == "miss":
				out.append(_mark_cast_stamp(caster, caster_cell, to_cell))
			if typ == "hit":
				var bolt := _shot(caster_cell, to_cell, VfxPalette.KESTREL_AIR, 10.0, MARK_FLIGHT_SEC, 2.5)
				bolt["hand"] = true
				bolt["seat"] = caster
				bolt["delay"] = _mark_windup_sec()
				out.append(bolt)
				# Rings and the burst sit on the tile. The bolt still leaves the weapon.
				var impact := _stamp("mark_shot_impact", target, to_cell, _mark_impact_delay(), VfxBudget.STAMP_MARK_PX, VfxBudget.STAMP_SPELL_LIFE)
				impact["chest"] = false
				impact["ground"] = true
				out.append(impact)
				out.append(_status_on("marks", target, to_cell, _stack_count(snapshot, target, "marks", maxi(int(event.get("engine_gained", 1)), 1))))
		"detonate":
			if typ == "hit":
				var line := _shot(caster_cell, to_cell, VfxPalette.KESTREL_AIR, 0.0, 0.08, 2.0, false)
				line["hand"] = true
				line["seat"] = caster
				line["delay"] = STRIPS.release_sec("kestrel", "cast")
				out.append(line)
				out.append(_stamp("detonate_burst", target, to_cell, STRIPS.release_sec("kestrel", "cast"), VfxBudget.STAMP_DETONATE_PX, VfxBudget.STAMP_SPELL_LIFE))
				if event.has("marks_remaining") and int(event.get("marks_remaining", 0)) <= 0:
					out.append(_status_off("marks", target, to_cell))
				elif int(event.get("marks_remaining", 0)) > 0:
					out.append(_status_on("marks", target, to_cell, int(event.get("marks_remaining", 0))))
			elif typ == "miss" and bool(event.get("marks_retained", false)):
				out.append(_ring(to_cell, VfxPalette.KESTREL, false, 0.16, 0.0))
		"strike":
			if typ == "hit":
				out.append(_ring(to_cell, VfxPalette.IRONJAW, false, 0.24, 0.0, "crack"))
				out.append(_puff(target, to_cell, VfxPalette.IRONJAW_EARTH, 0.7))
				if int(event.get("engine_gained", 0)) > 0:
					out.append(_status_on("impact", caster, caster_cell, _stack_count(snapshot, caster, "impact", int(event.get("engine_gained", 1)))))
			elif typ == "miss":
				out.append(_ring(to_cell, VfxPalette.IRONJAW_DUST, false, 0.18, 0.0, "crack"))
		"shoulder":
			if typ == "hit" or typ == "miss":
				out.append(_shot(caster_cell, to_cell, VfxPalette.IRONJAW, 0.0, 0.1, 5.0))
			if typ == "hit" and int(event.get("engine_gained", 0)) > 0:
				out.append(_status_on("impact", caster, caster_cell, _stack_count(snapshot, caster, "impact", int(event.get("engine_gained", 1)))))
		"crush":
			if typ == "hit":
				out.append(_ring(to_cell, VfxPalette.IRONJAW_EARTH, false, 0.32, 0.0, "crack"))
				var left := _stack_count(snapshot, caster, "impact", -1)
				if left < 0 and event.has("impact_before"):
					left = maxi(int(event.get("impact_before", 0)) - int(event.get("impact_spent", 0)), 0)
				if left == 0:
					out.append(_status_off("impact", caster, caster_cell))
				elif left > 0:
					var pip := _status_on("impact", caster, caster_cell, left)
					if int(event.get("impact_before", 0)) >= 4:
						pip["glow"] = true
					out.append(pip)
			elif typ == "miss":
				out.append(_ring(to_cell, VfxPalette.IRONJAW_DUST, false, 0.2, 0.0, "crack"))
		"mend", "pulse_tap":
			if typ == "hit":
				out.append(_ring(caster_cell, VfxPalette.MENDER_CREAM if spell_id == "mend" else VfxPalette.MENDER, false, 0.18, 0.0))
				if not _same_cell(caster_cell, to_cell):
					var travel: Color = VfxPalette.MENDER_CREAM if spell_id == "mend" else VfxPalette.MENDER
					out.append(_shot(caster_cell, to_cell, travel, 8.0 if spell_id == "mend" else 6.0, 0.2 if spell_id == "mend" else 0.15, 2.0))
				if bool(event.get("triage", false)):
					out.append(_number(target, to_cell, "x1.25", "triage", 0.0, 1.0, "", Color(0, 0, 0, 0)))
				if spell_id == "mend" and int(event.get("engine_gained", 0)) > 0:
					out.append(_status_on("pulse", caster, caster_cell, _stack_count(snapshot, caster, "pulse", int(event.get("engine_gained", 1)))))
				if spell_id == "pulse_tap":
					var pulses := _stack_count(snapshot, caster, "pulse", -1)
					if pulses == 0:
						out.append(_status_off("pulse", caster, caster_cell))
					elif pulses > 0:
						out.append(_status_on("pulse", caster, caster_cell, pulses))
		"ward":
			if typ == "hit" and not _same_cell(caster_cell, to_cell):
				out.append(_shot(caster_cell, to_cell, VfxPalette.MENDER_CREAM, 6.0, 0.16, 2.0))
			elif typ == "miss":
				out.append(_ring(to_cell, VfxPalette.MENDER_CREAM, false, 0.18, 0.0))
		"rekindle":
			if typ == "hit":
				out.append(_ring(to_cell, VfxPalette.MENDER, false, 0.5, 0.6))
				out.append(_flash("wash", target, to_cell, 0.4))
				out.append(_number(target, to_cell, "REVIVED", "cleansed", 0.0, 1.2, "", Color(0, 0, 0, 0)))
		"cleanse":
			if typ == "hit":
				out.append(_flash("wash", target, to_cell, 0.28))
				if _removed_stun(event):
					out.append(_number(target, to_cell, "CLEANSED", "cleansed", 0.0, 1.0, "", Color(0, 0, 0, 0)))
					out.append(_status_off("stun", target, to_cell))
		"heartstop":
			if typ == "hit" and not _same_cell(caster_cell, to_cell):
				var tint: Color = VfxPalette.MENDER_DEEP if bool(event.get("skip_next_mp", false)) else VfxPalette.MENDER
				out.append(_shot(caster_cell, to_cell, tint, 4.0, 0.15, 2.5))
			if typ == "hit" and event.has("hit_immunity"):
				out.append(_status_on("hit_immunity", target, to_cell, maxi(int(event.get("hit_immunity", 1)), 1)))
				out.append(_ring(to_cell, VfxPalette.MENDER, false, 0.28, 0.0))
			if typ == "hit" and bool(event.get("skip_next_mp", false)):
				out.append(_status_on("skip_next_mp", target, to_cell, 1))
				out.append(_puff(target, to_cell, VfxPalette.MENDER_DEEP, 0.9))
			if typ == "hit" and bool(event.get("triage", false)) and not bool(event.get("skip_next_mp", false)):
				out.append(_number(target, to_cell, "x1.25", "triage", 0.0, 1.0, "", Color(0, 0, 0, 0)))
		"cut":
			if typ == "hit" or typ == "miss":
				out.append(_flash("slash", target if typ == "hit" else caster, to_cell, 0.28))
			if typ == "hit" and int(event.get("engine_gained", 0)) > 0:
				out.append(_status_on("umbral", caster, caster_cell, _stack_count(snapshot, caster, "umbral", int(event.get("engine_gained", 1)))))
		"drop_shade":
			if typ == "cast" and event.has("to"):
				# Snappy board piece. No travel from Gloam to the tile.
				# Puff only: no "Shade" floater text (Mauro 29 Sep 2026).
				out.append(_puff(caster, to_cell, VfxPalette.GLOAM_RIM, 1.15))
		"ambush":
			if typ == "hit" and bool(event.get("teleported", false)):
				var origin_cell := cell_of(event.get("origin", caster_cell))
				var phase := str(event.get("present_phase", ""))
				# Empty phase is the full recipe (tests, debug). Live presentation
				# splits it: the puff is the collapse, the slash is the contact.
				if phase != "contact":
					out.append(_puff(caster, origin_cell, VfxPalette.GLOAM, 0.85))
				if phase != "collapse":
					var struck := _target_cell(event)
					out.append(_flash("slash", target, struck, 0.26))
					# Shade origin and Invisible self-origin share this hit beat.
					# BoardView arms this only after the body is planted on the back tile.
					# The strip starts with that slash. Anticipate and wind fill the
					# beat, and the SNAP cell opens on the contact. The anchor is
					# the planted Gloam, facing the struck body. Not the cast cell.
					var back := to_cell
					if event.has("destination"):
						back = cell_of(event.get("destination"))
					var lead := STAMP.lead_sec("ambush_slash", 2)
					var slash_delay := maxf(ViewMotion.ambush_contact_sec() - lead, 0.0)
					var slash := _stamp("ambush_slash", caster, back, slash_delay, VfxBudget.STAMP_AMBUSH_PX, STAMP.windup_sec("ambush_slash"))
					slash["chest"] = false
					slash["hand"] = true
					slash["aim"] = struck
					out.append(slash)
		"fade":
			if typ == "cast" and bool(event.get("invisible", false)):
				out.append(_status_on("invisible", caster, caster_cell, 1))
				out.append(_puff(caster, caster_cell, VfxPalette.GLOAM_RIM, 0.8))
		"nightfold":
			# Parked until the cast is ungated. Swirl only: no bodies, no damage.
			var at := to_cell if event.has("to") else caster_cell
			out.append(_ring(at, VfxPalette.GLOAM_RIM, false, 0.3, 0.55, "pool"))
			out.append(_puff(caster, caster_cell, VfxPalette.GLOAM, 0.55))
		"bash":
			if typ == "hit":
				out.append(_ring(to_cell, VfxPalette.BASTION, false, 0.22, 0.0))
				if int(event.get("engine_gained", 0)) > 0:
					out.append(_status_on("aegis", caster, caster_cell, _stack_count(snapshot, caster, "aegis", int(event.get("engine_gained", 1)))))
			elif typ == "miss":
				out.append(_puff(caster, caster_cell, VfxPalette.BASTION, 0.45))
		"plant":
			if typ == "cast" and event.has("to"):
				out.append(_shot(caster_cell, to_cell, VfxPalette.BASTION, 0.0, 0.12, 2.0))
				if int(event.get("engine_gained", 0)) > 0:
					out.append(_status_on("aegis", caster, caster_cell, _stack_count(snapshot, caster, "aegis", int(event.get("engine_gained", 1)))))
		"hold_line":
			if typ == "hit":
				for raw in event.get("targets", []):
					if typeof(raw) != TYPE_DICTIONARY:
						continue
					var row: Dictionary = raw
					if int(row.get("exit_tax", 0)) <= 0:
						continue
					out.append(_status_on("exit_tax", int(row.get("target_seat", -1)), cell_of(row.get("cell", Vector2i.ZERO)), int(row.get("exit_tax", 1))))
		"snap_wall":
			if typ == "snap_wall" and event.has("to"):
				out.append(_puff(caster, cell_of(event.get("to")), VfxPalette.IRONJAW_DUST, 0.7))
		"aegis_break":
			if typ == "hit":
				if _chebyshev(caster_cell, to_cell) >= 2:
					out.append(_shot(caster_cell, to_cell, VfxPalette.BASTION_PALE, 0.0, 0.1, 8.0))
				out.append(_ring(to_cell, VfxPalette.BASTION, false, 0.3, 0.0, "crack"))
				if bool(event.get("stacks_cleared", false)) or int(event.get("aegis_spent", 0)) > 0:
					out.append(_status_off("aegis", caster, caster_cell))
			elif typ == "miss":
				out.append(_ring(caster_cell, VfxPalette.BASTION, false, 0.18, 0.0))
	return out


## ---- Stasis monster spells (Mauro's kit + Caster Bolt VFX sheets) --------
const _FoeKits := preload("res://backend/foe_kits.gd")


static func _foe_is_bolt(spell_id: String) -> bool:
	return bool(_FoeKits.spell(spell_id).get("bolt", false))


static func _foe_bolt_land(event: Dictionary) -> float:
	var tiles := _chebyshev(cell_of(event.get("caster_cell", Vector2i.ZERO)), cell_of(event.get("to", Vector2i.ZERO)))
	return ViewMotion.FOE_BOLT_CAST_SEC + ViewMotion.foe_bolt_travel_sec(tiles)


static func _foe_choreography(event: Dictionary) -> Array:
	var out: Array = []
	var spell_id := str(event.get("spell", ""))
	var typ := str(event.get("type", ""))
	var caster := int(event.get("seat", -1))
	var caster_cell := cell_of(event.get("caster_cell", Vector2i.ZERO))
	var to_cell := cell_of(event.get("to", caster_cell))
	var tint := VfxPalette.foe_tint(event)
	var def: Dictionary = _FoeKits.spell(spell_id)
	var shape := str(def.get("shape", ""))
	if typ != "hit" and typ != "miss":
		return out
	if bool(def.get("bolt", false)):
		# Cast: hand / staff flash in the door colour, the body stays put.
		out.append(_puff(caster, caster_cell, tint, 0.75))
		var tiles := _chebyshev(caster_cell, to_cell)
		var travel := ViewMotion.foe_bolt_travel_sec(tiles)
		var bolt := _shot(caster_cell, to_cell, tint, 7.0, travel, 5.5)
		bolt["delay"] = ViewMotion.FOE_BOLT_CAST_SEC
		bolt["hand"] = true
		bolt["seat"] = caster
		if typ == "miss":
			# MISS: the bolt skips past the tile and fades. No pop, no number.
			bolt["overshoot"] = 34.0
			bolt["whiff"] = true
		out.append(bolt)
		if typ == "hit":
			var pop := _ring(to_cell, tint, false, 0.18, 0.0, "crack")
			pop["delay_spawn"] = ViewMotion.FOE_BOLT_CAST_SEC + travel
			out.append(pop)
		return out
	if bool(def.get("aoe", false)):
		# Area spell: every covered tile flashes, a shock ring at the caster,
		# the boss sigil flares.
		# A painted boss effect lands later (fire frame, flight): the tiles,
		# ring and shake wait for that impact.
		var impact := 0.0
		if BOSS_FX.has(spell_id):
			out.append_array(_boss_fx_recipes(spell_id, caster, caster_cell, to_cell))
			impact = boss_fx_impact_sec(spell_id)
		elif shape == "blast":
			# Cannon: a shot to the impact, then the blast tiles flash.
			out.append(_shot(caster_cell, to_cell, tint, 9.0, 0.22, 6.0))
		var late: Array = []
		for raw in event.get("area", []):
			late.append(_ring(cell_of(raw), tint, false, 0.32, 0.0))
		late.append(_ring(caster_cell, tint, false, 0.42, 0.0, "crack"))
		if bool(event.get("boss", false)):
			out.append({"id": "boss_flare", "block": 0.0, "seat": caster})
			late.append({"id": "shake", "block": 0.0, "amplitude": VfxBudget.SHAKE_PX * 1.4, "duration": VfxBudget.SHAKE_SEC})
		for spec in late:
			if impact > 0.0:
				spec["delay_spawn"] = impact
			out.append(spec)
		return out
	if event.has("dash_from"):
		var dash := _shot(cell_of(event["dash_from"]), cell_of(event["dash_to"]), tint, 0.0, 0.12, 4.0, false)
		out.append(dash)
	if shape in ["melee", "dash"] and typ == "hit":
		out.append(_ring(to_cell, tint, false, 0.22, 0.0, "crack"))
		if bool(event.get("boss", false)):
			out.append({"id": "shake", "block": 0.0, "amplitude": VfxBudget.SHAKE_PX, "duration": VfxBudget.SHAKE_SEC})
	return out


## Painted 5-star boss effects (Technical Artist, boss round 1; Mauro: "hook
## up the boss effects"). Cell pixels, anchors and fire frames are the
## artist's NOTES. `mul` is the size on the board in boss-cell scale (the
## artist's preview sizes). Damage and area stay the kit numbers.
const BOSS_FX_DIR := "res://art/stasis/bosses/"
const BOSS_FX := {
	# Ghostfire Cannon: cast strip fires on frame 3 of 8; the ball lobs from
	# the muzzle and the explosion's bottom centre lands on the impact tile.
	"brine.cannon": {
		"ball": {
			"path": BOSS_FX_DIR + "brineclaw_sovereign/brineclaw_sovereign_fx_cannonball.png",
			"frames": 4,
			"anchor": Vector2(40, 32),
			"fps": 16.0,
			"mul": 1.0,
		},
		# Muzzle on the fire frame, cell px, by the artist's file letter.
		"muzzle": {
			"s": Vector2(239.7, 118.1),
			"w": Vector2(48.3, 118.1),
			"e": Vector2(51.0, 113.3),
			"n": Vector2(237.0, 113.3),
		},
		"arc_px": 90.0,
		"burst": {
			"path": BOSS_FX_DIR + "brineclaw_sovereign/brineclaw_sovereign_fx_explosion.png",
			"frames": 10,
			"anchor": Vector2(96, 150),
			"fps": 16.0,
			"mul": 1.6,
			"ground": false,
		},
	},
	# Caldera Punch: the eruption starts on attack frame 2 (fist on the
	# floor), on the floor layer under the boss, with the camera shake.
	"slag.caldera": {
		"burst": {
			"path": BOSS_FX_DIR + "slagheart_caldera_crown/slagheart_caldera_crown_fx_eruption.png",
			"frames": 10,
			"anchor": Vector2(96, 112),
			"fps": 15.0,
			"mul": 2.6,
			"ground": true,
		},
	},
}


## Timing lives in ViewMotion (the target flinch waits for the same impact).
static func boss_fx_fire_sec(spell_id: String) -> float:
	return ViewMotion.boss_fx_fire_sec(spell_id)


static func boss_fx_impact_sec(spell_id: String) -> float:
	return ViewMotion.boss_fx_impact_sec(spell_id)


static func _boss_fx_recipes(spell_id: String, caster: int, caster_cell: Vector2i, to_cell: Vector2i) -> Array:
	var out: Array = []
	var fx: Dictionary = BOSS_FX[spell_id]
	var fire := boss_fx_fire_sec(spell_id)
	var land := fire
	if fx.has("ball"):
		var ball: Dictionary = (fx["ball"] as Dictionary).duplicate()
		ball["id"] = "boss_fx"
		ball["block"] = 0.0
		ball["seat"] = caster
		ball["cell"] = caster_cell
		ball["to_cell"] = to_cell
		ball["muzzle"] = fx.get("muzzle", {})
		ball["duration"] = ViewMotion.boss_fx_flight_sec(spell_id)
		ball["arc"] = float(fx.get("arc_px", 0.0))
		ball["delay"] = fire
		out.append(ball)
	land = boss_fx_impact_sec(spell_id)
	var burst: Dictionary = (fx["burst"] as Dictionary).duplicate()
	burst["id"] = "boss_fx"
	burst["block"] = 0.0
	burst["seat"] = caster
	burst["cell"] = to_cell if fx.has("ball") else caster_cell
	burst["delay"] = land
	out.append(burst)
	return out


static func _stack_count(snapshot: Dictionary, seat: int, field: String, fallback: int) -> int:
	for unit in snapshot.get("units", []):
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = unit
		if int(rec.get("seat", -2)) != seat:
			continue
		if rec.has(field):
			return int(rec[field])
		return fallback
	return fallback


static func _same_cell(a: Vector2i, b: Vector2i) -> bool:
	return a == b


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _removed_stun(event: Dictionary) -> bool:
	if not event.has("cc_removed"):
		return false
	var removed: Variant = event.get("cc_removed", [])
	return removed is Array and removed.has("stun")


static func _mark_windup_sec() -> float:
	return STAMP.windup_sec("mark_shot_cast")


static func _mark_impact_delay() -> float:
	return _mark_windup_sec() + MARK_FLIGHT_SEC


## The four holds, including the arrow-tip release. The bolt is the next tick.
static func _mark_cast_life() -> float:
	return _mark_windup_sec()


static func _mark_cast_stamp(seat: int, cell: Vector2i, aim: Vector2i) -> Dictionary:
	var spec := _stamp("mark_shot_cast", seat, cell, 0.0, VfxBudget.STAMP_MARK_CAST_PX, _mark_cast_life())
	spec["chest"] = false
	spec["hand"] = true
	spec["aim"] = aim
	return spec


## Standing melee only. Ambush slashes after the plant. Mark Shot uses the bow.
static func _shows_melee_windup(spell_id: String) -> bool:
	if spell_id == "ambush" or spell_id == SpellKits.AMBUSH:
		return false
	if spell_id == "mark_shot" or spell_id == SpellKits.MARK_SHOT:
		return false
	return ViewMotion.caster_motion(spell_id) == "attack"


static func _hit_flash(seat: int, cell: Vector2i, delay: float) -> Dictionary:
	return _stamp("hit_flash", seat, cell, delay, VfxBudget.STAMP_HIT_PX, VfxBudget.STAMP_HIT_LIFE, 0.92)


## Accent on the rising number. Same contact instant as the flash and the spark.
## Head anchor, so it does not stack a second chest plate on the flash.
static func _damage_float(seat: int, cell: Vector2i, delay: float) -> Dictionary:
	var spec := _stamp("damage_float", seat, cell, delay, VfxBudget.STAMP_FLOAT_PX, VfxBudget.STAMP_FLOAT_LIFE, 0.92)
	spec["chest"] = false
	spec["head"] = true
	return spec


static func _stamp(sheet: String, seat: int, cell: Vector2i, delay: float, px: float, life: float, alpha: float = 1.0) -> Dictionary:
	return {
		"id": "stamp",
		"block": 0.0,
		"sheet": sheet,
		"seat": seat,
		"cell": cell,
		"delay": delay,
		"px": px,
		"life": life,
		"alpha": alpha,
		"chest": true,
	}


static func _shot(from_cell: Vector2i, to_cell: Vector2i, tint: Color, arc: float, duration: float, width: float, head: bool = true) -> Dictionary:
	var spec := {
		"id": "projectile",
		"block": 0.0,
		"from": from_cell,
		"to": to_cell,
		"arc": arc,
		"overshoot": 0.0,
		"duration": duration,
		"tint": tint,
		"width": width,
	}
	if not head:
		spec["head"] = false
	return spec


static func _status_on(status: String, seat: int, cell: Vector2i, count: int) -> Dictionary:
	return {
		"id": "status_on",
		"block": 0.0,
		"pool": "status",
		"status": status,
		"seat": seat,
		"cell": cell,
		"count": count,
	}


static func _status_off(status: String, seat: int, cell: Vector2i) -> Dictionary:
	return {
		"id": "status_off",
		"block": 0.0,
		"status": status,
		"seat": seat,
		"cell": cell,
	}


static func _flash(status: String, seat: int, cell: Vector2i, life: float) -> Dictionary:
	return {
		"id": "status_flash",
		"block": 0.0,
		"status": status,
		"seat": seat,
		"cell": cell,
		"life": life,
	}


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


static func _miss(spell_id: String, caster: Vector2i, target: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var event := {
		"type": "miss",
		"spell": spell_id,
		"seat": 0,
		"target_seat": 1,
		"caster_cell": caster,
		"to": target,
		"damage": 0,
	}
	for key in extra.keys():
		event[key] = extra[key]
	return event
