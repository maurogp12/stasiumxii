extends RefCounted
class_name SpellKits

## Phase A locked kit only. Later spells stay out of this table.
## Advance is Ironjaw-only (Locked). Kestrel never has Advance and never gains Impact.
## Detonate is Kestrel-only. Shoulder / Crush are Ironjaw-only.
const ADVANCE := "advance"
const STRIKE := "strike"
const MARK_SHOT := "mark_shot"
const DETONATE := "detonate"
const SHOULDER := "shoulder"
const CRUSH := "crush"

const CLASS_KESTREL := "kestrel"
const CLASS_IRONJAW := "ironjaw"

const SPELLS := {
	ADVANCE: {
		"id": ADVANCE,
		"name": "Advance",
		"class_id": CLASS_IRONJAW,
		"ap": 3,
		"mp": 0,
		"mp_mode": "none",
		"range_mode": "manhattan",
		"move_mode": "teleport",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"element": "neutral",
		"base_damage": 0,
		"target": "empty_tile",
		"engine_on_connect": "impact_if_adjacent",
	},
	STRIKE: {
		"id": STRIKE,
		"name": "Strike",
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": true,
		"element": "earth",
		"base_damage": 16,
		"target": "enemy",
		"engine_on_connect": "impact",
	},
	MARK_SHOT: {
		"id": MARK_SHOT,
		"name": "Mark Shot",
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 2,
		"max_range": 5,
		"rolls": true,
		"element": "air",
		"base_damage": 8,
		"target": "enemy",
		"engine_on_connect": "mark",
	},
	DETONATE: {
		"id": DETONATE,
		"name": "Detonate",
		"class_id": CLASS_KESTREL,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 6,
		"rolls": true,
		"element": "air",
		"base_damage": 6,
		"damage_per_mark": 6,
		"target": "enemy",
		# A01 Locked: Marks live on the target. Detonate reads/consumes that stack.
		"engine_on_connect": "consume_marks",
		"requires_marks_on_target": 1,
	},
	SHOULDER: {
		"id": SHOULDER,
		"name": "Shoulder",
		"class_id": CLASS_IRONJAW,
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": true,
		"element": "earth",
		"base_damage": 6,
		"target": "enemy",
		"engine_on_connect": "impact",
		"push_cells": 1,
	},
	CRUSH: {
		"id": CRUSH,
		"name": "Crush",
		"class_id": CLASS_IRONJAW,
		"ap": 4,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": true,
		"element": "earth",
		"base_damage": 24,
		"target": "enemy",
		# Locked: needs/spends 2 Impact on connect; miss retains Impact.
		"engine_on_connect": "spend_impact",
		"requires_impact": 2,
		"spend_impact": 2,
		# OPEN A05: Stun 1 if Impact was 4 before the spend. Suppress list not locked.
		"stun_if_impact_before": 4,
		"stun_remaining": 1,
	},
}

const CLASS_SPELLS := {
	CLASS_KESTREL: [MARK_SHOT, DETONATE],
	CLASS_IRONJAW: [ADVANCE, STRIKE, SHOULDER, CRUSH],
}

const MARKS_CAP := 5
const IMPACT_CAP := 4


static func spell(spell_id: String) -> Dictionary:
	if SPELLS.has(spell_id):
		return SPELLS[spell_id]
	return {}


static func class_spells(class_id: String) -> Array:
	if CLASS_SPELLS.has(class_id):
		return CLASS_SPELLS[class_id]
	return []


static func has_spell(class_id: String, spell_id: String) -> bool:
	return spell_id in class_spells(class_id)


static func rolls(spell_id: String) -> bool:
	var def: Dictionary = spell(spell_id)
	if def.is_empty():
		return false
	return bool(def.get("rolls", false))
