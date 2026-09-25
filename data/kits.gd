extends RefCounted
class_name SpellKits

## Phase A locked kit only. Later spells stay out of this table.
## Advance is Ironjaw-only (Locked). Legal dests are the 4 ortho neighbors
## (N/S/E/W): Chebyshev 1 and Manhattan 1, cardinal only. No Manhattan 2,
## no diagonal / (1,1). Kestrel never has Advance and never gains Impact.
## Detonate is Kestrel-only. Shoulder / Crush are Ironjaw-only.
const ADVANCE := "advance"
const STRIKE := "strike"
const MARK_SHOT := "mark_shot"
const DETONATE := "detonate"
const SHOULDER := "shoulder"
const CRUSH := "crush"

const CLASS_KESTREL := "kestrel"
const CLASS_IRONJAW := "ironjaw"
const CLASS_MENDER := "mender"
const CLASS_GLOAM := "gloam"
const CLASS_BASTION := "bastion"
## SELECT_CLASS allowlist (workbook SELECT_CLASS_Lock). Server rejects anything else.
const LOCKED_ROSTER: Array[String] = [
	CLASS_KESTREL,
	CLASS_IRONJAW,
	CLASS_MENDER,
	CLASS_GLOAM,
	CLASS_BASTION,
]
## Workbook v0.6 SELECT_CLASS_Lock. Numeric card wins. See
## data/select_class_lock_kits_v0.6.json.
const UMBRAL_CAP := 4
const SHADE_CAP := 2
const PULSE_CAP := 6
const AEGIS_CAP := 4
const BACKSTAB_MULT := 1.35
const TRIAGE_MULT := 1.25
const TRIAGE_HP_THRESHOLD := 0.4
const INTERCEPT_TRANSFER := 0.4

const MEND := "mend"
const PULSE_TAP := "pulse_tap"
const WARD := "ward"
const CLEANSE := "cleanse"
const HEARTSTOP := "heartstop"
const CUT := "cut"
const DROP_SHADE := "drop_shade"
const AMBUSH := "ambush"
const FADE := "fade"
const NIGHTFOLD := "nightfold"
const BASH := "bash"
const PLANT := "plant"
const HOLD_LINE := "hold_line"
const SNAP_WALL := "snap_wall"
const AEGIS_BREAK := "aegis_break"

## TODO open_can_wait: do not resolve these. No silent default.
const OPEN_CAN_WAIT: Array[String] = [
	"nightfold_miss_shade_vs_global_refund",
	"intercept_reset_multi_guard_pipeline",
	"neutral_primary_scope",
	"aoe_vs_invisible",
	"heartstop_immunity_clock_cc_priority_heal_overflow_shield_stack",
	"water_ward_rider_24_vs_ward_base_20",
	"cone_ward_masks",
]

const SPELLS := {
	ADVANCE: {
		"id": ADVANCE,
		"name": "Advance",
		"class_id": CLASS_IRONJAW,
		"ap": 3,
		"mp": 0,
		"mp_mode": "none",
		# Cardinal only: Chebyshev 1 and Manhattan 1 (the 4 ortho neighbors).
		"range_mode": "cardinal",
		"move_mode": "teleport",
		"min_range": 1,
		"max_range": 1,
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
		"max_range": 7,
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
		"max_range": 4,
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
		# CombatSim applies +1 after a clean push, or +2 only on bounce (not both).
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
		# Locked Stun (A′): Stun 1 if Impact was 4 before the spend. Blocks move + cast + face.
		"stun_if_impact_before": 4,
		"stun_remaining": 1,
	},
	MEND: {
		"id": MEND,
		"name": "Mend",
		"class_id": CLASS_MENDER,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 4,
		"rolls": true,
		"element": "water",
		"base_heal": 16,
		"target": "ally",
		"engine_on_connect": "pulse",
		"no_facing": true,
		"triage": true,
	},
	PULSE_TAP: {
		"id": PULSE_TAP,
		"name": "Pulse Tap",
		"class_id": CLASS_MENDER,
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 3,
		"rolls": true,
		"element": "water",
		"base_heal": 10,
		"target": "ally",
		"engine_on_connect": "spend_pulse",
		"requires_pulse": 1,
		"spend_pulse": 1,
		"triage": true,
	},
	WARD: {
		"id": WARD,
		"name": "Ward",
		"class_id": CLASS_MENDER,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 3,
		"rolls": true,
		"element": "water",
		"base_heal": 0,
		"shield": 20,
		"shield_turns": 2,
		"target": "ally",
		"engine_on_connect": "spend_pulse",
		"requires_pulse": 2,
		"spend_pulse": 2,
		"no_crit": true,
	},
	CLEANSE: {
		"id": CLEANSE,
		"name": "Cleanse",
		"class_id": CLASS_MENDER,
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 4,
		"rolls": false,
		"element": "neutral",
		"target": "ally",
		"engine_on_connect": "pulse",
		"remove_cc": 1,
	},
	HEARTSTOP: {
		"id": HEARTSTOP,
		"name": "Heartstop",
		"class_id": CLASS_MENDER,
		"ap": 5,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 3,
		"rolls": true,
		"element": "water",
		"base_heal": 32,
		"base_damage": 10,
		"target": "any",
		"engine_on_connect": "spend_pulse",
		"requires_pulse": 4,
		"spend_pulse": 4,
		"triage": true,
		"ally_immunity_hits": 1,
		"enemy_skip_mp": true,
	},
	CUT: {
		"id": CUT,
		"name": "Cut",
		"class_id": CLASS_GLOAM,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": true,
		"element": "air",
		"base_damage": 13,
		"target": "enemy",
		"engine_on_connect": "umbral",
	},
	DROP_SHADE: {
		"id": DROP_SHADE,
		"name": "Drop Shade",
		"class_id": CLASS_GLOAM,
		"ap": 1,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"element": "neutral",
		"target": "empty_tile",
		"shade_turns": 3,
	},
	AMBUSH: {
		"id": AMBUSH,
		"name": "Ambush",
		"class_id": CLASS_GLOAM,
		"ap": 4,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 4,
		"rolls": true,
		"element": "air",
		"base_damage": 22,
		"target": "enemy",
		"engine_on_connect": "ambush",
	},
	FADE: {
		"id": FADE,
		"name": "Fade",
		"class_id": CLASS_GLOAM,
		"ap": 2,
		"mp": 1,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 0,
		"rolls": false,
		"element": "neutral",
		"target": "self",
		"engine_on_connect": "umbral",
	},
	# Nightfold's miss/Shade refund is open_can_wait. Gated: not resolved.
	NIGHTFOLD: {
		"id": NIGHTFOLD,
		"name": "Nightfold",
		"class_id": CLASS_GLOAM,
		"ap": 4,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 6,
		"rolls": true,
		"element": "air",
		"base_damage": 22,
		"target": "enemy",
		"gated": true,
		"open_id": "nightfold_miss_shade_vs_global_refund",
	},
	BASH: {
		"id": BASH,
		"name": "Bash",
		"class_id": CLASS_BASTION,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": true,
		"element": "earth",
		"base_damage": 11,
		"target": "enemy",
		"engine_on_connect": "aegis",
	},
	PLANT: {
		"id": PLANT,
		"name": "Plant",
		"class_id": CLASS_BASTION,
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"element": "neutral",
		"target": "tile",
		"engine_on_connect": "aegis",
		"plant_turns": 3,
	},
	HOLD_LINE: {
		"id": HOLD_LINE,
		"name": "Hold Line",
		"class_id": CLASS_BASTION,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": true,
		"element": "earth",
		"base_damage": 7,
		"target": "cone",
		"engine_on_connect": "aegis",
		"cone": 3,
		"exit_tax_mp": 1,
		"exit_tax_turns": 1,
	},
	SNAP_WALL: {
		"id": SNAP_WALL,
		"name": "Snap Wall",
		"class_id": CLASS_BASTION,
		"ap": 1,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"element": "neutral",
		"target": "empty_tile",
		"engine_on_connect": "spend_aegis",
		"requires_aegis": 2,
		"spend_aegis": 2,
		# Locked: 2 owner Bastion turn-starts remaining (Burn tick family). Not every seat turn.
		"wall_turns": 2,
	},
	AEGIS_BREAK: {
		"id": AEGIS_BREAK,
		"name": "Aegis Break",
		"class_id": CLASS_BASTION,
		"ap": 4,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": true,
		"element": "earth",
		"base_damage": 26,
		# Locked v0.6 "26D/body": every enemy in the range band, one roll.
		"target": "burst",
		"engine_on_connect": "clear_aegis",
		"requires_aegis": 3,
		"push_cells": 1,
	},
}

const CLASS_SPELLS := {
	CLASS_KESTREL: [MARK_SHOT, DETONATE],
	CLASS_IRONJAW: [ADVANCE, STRIKE, SHOULDER, CRUSH],
	CLASS_MENDER: [MEND, PULSE_TAP, WARD, CLEANSE, HEARTSTOP],
	CLASS_GLOAM: [CUT, DROP_SHADE, AMBUSH, FADE, NIGHTFOLD],
	CLASS_BASTION: [BASH, PLANT, HOLD_LINE, SNAP_WALL, AEGIS_BREAK],
}

const MARKS_CAP := 5
const IMPACT_CAP := 4


static func normalize_class_id(class_id: String) -> String:
	return class_id.strip_edges().to_lower()


static func is_roster_class(class_id: String) -> bool:
	return LOCKED_ROSTER.has(normalize_class_id(class_id))


static func display_name(class_id: String) -> String:
	match normalize_class_id(class_id):
		CLASS_KESTREL:
			return "Kestrel"
		CLASS_IRONJAW:
			return "Ironjaw"
		CLASS_MENDER:
			return "Mender"
		CLASS_GLOAM:
			return "Gloam"
		CLASS_BASTION:
			return "Bastion"
		_:
			return ""


## Display name for a snapshot resource field. The value comes from the unit.
static func resource_label(resource_id: String) -> String:
	match resource_id:
		"pulse":
			return "Pulse"
		"umbral":
			return "Umbral"
		"shades":
			return "Shades"
		"aegis":
			return "Aegis"
		_:
			return ""


static func element_of(class_id: String) -> String:
	match normalize_class_id(class_id):
		CLASS_KESTREL:
			return "air"
		CLASS_IRONJAW:
			return "earth"
		CLASS_MENDER:
			return "water"
		CLASS_GLOAM:
			return "air"
		CLASS_BASTION:
			return "earth"
		_:
			return ""


static func is_gated(spell_id: String) -> bool:
	var def: Dictionary = spell(spell_id)
	return bool(def.get("gated", false))


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


## Player-facing band. Internal range_mode stays chebyshev / manhattan / cardinal.
## Advance is cardinal: exactly the 4 orthogonal neighbors (N/S/E/W).
static func range_text(def: Dictionary) -> String:
	var lo := int(def.get("min_range", 0))
	var hi := int(def.get("max_range", 0))
	var mode := str(def.get("range_mode", "chebyshev"))
	if mode == "cardinal":
		return "4 orthogonal neighbors"
	if mode == "manhattan":
		return "range %d–%d Manhattan" % [lo, hi]
	return "range %d–%d" % [lo, hi]
