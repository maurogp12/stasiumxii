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
## Server allowlist for SELECT_CLASS. Chrome may still show CHROME_ROSTER.
const LOCKED_ROSTER: Array[String] = [CLASS_KESTREL, CLASS_IRONJAW]
## Display roster. mender / gloam / bastion wait on the server allowlist.
const CHROME_ROSTER: Array[String] = [
	CLASS_KESTREL,
	CLASS_IRONJAW,
	CLASS_MENDER,
	CLASS_GLOAM,
	CLASS_BASTION,
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
	# Card rows below are Locked workbook v0.6 data for chrome.
	# awaits_backend: CombatSim must not resolve them. Open items stay unimplemented.
	"mend": {
		"id": "mend",
		"name": "Mend",
		"class_id": CLASS_MENDER,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 4,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 pulse",
		"effect": "16H FLEX ally",
		"notes": "miss/crit OK; no facing",
	},
	"pulse_tap": {
		"id": "pulse_tap",
		"name": "Pulse Tap",
		"class_id": CLASS_MENDER,
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 3,
		"rolls": false,
		"awaits_backend": true,
		"engine": "spend 1 pulse",
		"effect": "10H FLEX ally",
		"notes": "miss/crit OK",
	},
	"ward": {
		"id": "ward",
		"name": "Ward",
		"class_id": CLASS_MENDER,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 3,
		"rolls": false,
		"awaits_backend": true,
		"engine": "spend 2 pulse",
		"effect": "20HP shield 2 turns FLEX",
		"notes": "miss OK; no crit",
	},
	"cleanse": {
		"id": "cleanse",
		"name": "Cleanse",
		"class_id": CLASS_MENDER,
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 4,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 pulse",
		"effect": "LOCK Neutral remove 1 CC",
		"notes": "no roll",
	},
	"heartstop": {
		"id": "heartstop",
		"name": "Heartstop",
		"class_id": CLASS_MENDER,
		"ap": 5,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 3,
		"rolls": false,
		"awaits_backend": true,
		"engine": "spend 4 pulse",
		"effect": "Ally: 32H + immunity 1 hit; Enemy: base_dmg=10 + skip next MP",
		"enemy_base_damage": 10,
		"notes": "FLEX; miss/crit OK",
	},
	"cut": {
		"id": "cut",
		"name": "Cut",
		"class_id": CLASS_GLOAM,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 umbral",
		"effect": "13D FLEX weapon",
		"notes": "backstab applies",
	},
	"drop_shade": {
		"id": "drop_shade",
		"name": "Drop Shade",
		"class_id": CLASS_GLOAM,
		"ap": 1,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 shade max 2",
		"effect": "LOCK Neutral Shade 3 turns",
		"notes": "no roll",
	},
	"ambush": {
		"id": "ambush",
		"name": "Ambush",
		"class_id": CLASS_GLOAM,
		"ap": 4,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 4,
		"rolls": false,
		"awaits_backend": true,
		"engine": "spend shade only if origin shade",
		"effect": "22D after jump FLEX",
		"card_damage": 22,
		"notes": "origin=self if Invisible else Shade; dest empty back; MISS: no teleport, shade kept, invisible kept, 4AP spent",
	},
	"fade": {
		"id": "fade",
		"name": "Fade",
		"class_id": CLASS_GLOAM,
		"ap": 2,
		"mp": 1,
		"range_mode": "self",
		"min_range": 0,
		"max_range": 0,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 umbral",
		"effect": "LOCK Neutral Invisible",
		"notes": "no roll",
	},
	"nightfold": {
		"id": "nightfold",
		"name": "Nightfold",
		"class_id": CLASS_GLOAM,
		"ap": 4,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 0,
		"max_range": 6,
		"rolls": false,
		"awaits_backend": true,
		"engine": "shade + umbral 2+; clear umbral",
		"effect": "22D each adjacent after blink to Shade",
		"card_damage": 22,
		"notes": "can-wait: shade commit-on-cast vs global miss refund",
	},
	"bash": {
		"id": "bash",
		"name": "Bash",
		"class_id": CLASS_BASTION,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 aegis",
		"effect": "11D FLEX melee",
	},
	"plant": {
		"id": "plant",
		"name": "Plant",
		"class_id": CLASS_BASTION,
		"ap": 2,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 aegis",
		"effect": "LOCK Neutral ward tile 3 turns; allies resist next push",
		"notes": "no roll",
	},
	"hold_line": {
		"id": "hold_line",
		"name": "Hold Line",
		"class_id": CLASS_BASTION,
		"ap": 3,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 1,
		"rolls": false,
		"awaits_backend": true,
		"engine": "+1 aegis",
		"effect": "7D/body FLEX front cone 3; +1MP exit tax 1 turn on connect",
	},
	"snap_wall": {
		"id": "snap_wall",
		"name": "Snap Wall",
		"class_id": CLASS_BASTION,
		"ap": 1,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"awaits_backend": true,
		"engine": "spend 2 aegis",
		"effect": "LOCK Neutral 1-tile blocked 2 turns",
		"blocked_tiles": 1,
		"blocked_turns": 2,
		"notes": "blocks walk/Gust; ships with Bastion; 2-class board stays wall-less",
	},
	"aegis_break": {
		"id": "aegis_break",
		"name": "Aegis Break",
		"class_id": CLASS_BASTION,
		"ap": 4,
		"mp": 0,
		"range_mode": "chebyshev",
		"min_range": 1,
		"max_range": 2,
		"rolls": false,
		"awaits_backend": true,
		"engine": "gate aegis 3+",
		"effect": "HIT: 26D/body + push1 + clear ALL aegis; MISS: spend 0",
		"card_damage": 26,
		"miss_spend": 0,
	},
}

const CLASS_SPELLS := {
	CLASS_KESTREL: [MARK_SHOT, DETONATE],
	CLASS_IRONJAW: [ADVANCE, STRIKE, SHOULDER, CRUSH],
	CLASS_MENDER: ["mend", "pulse_tap", "ward", "cleanse", "heartstop"],
	CLASS_GLOAM: ["cut", "drop_shade", "ambush", "fade", "nightfold"],
	CLASS_BASTION: ["bash", "plant", "hold_line", "snap_wall", "aegis_break"],
}

## Display + caps from the Locked cards. Current value is read from the snapshot.
const CLASS_RESOURCES := {
	CLASS_MENDER: [
		{"id": "pulse", "label": "Pulse", "min": 0, "max": 6},
	],
	CLASS_GLOAM: [
		{"id": "umbral", "label": "Umbral", "min": 0, "max": 4},
		{"id": "shades", "label": "Shades", "min": 0, "max": 2},
	],
	CLASS_BASTION: [
		{"id": "aegis", "label": "Aegis", "min": 0, "max": 4},
	],
}

## Proto stamp. Not a damage formula.
const CLASS_PROTO := {
	CLASS_MENDER: {"hp": 80, "mastery": 0, "resist": 0},
	CLASS_GLOAM: {"hp": 80, "mastery": 0, "resist": 0},
	CLASS_BASTION: {"hp": 80, "mastery": 0, "resist": 0},
}

## Stored so the card is not dropped. CombatSim does not apply these.
const CLASS_PASSIVES := {
	CLASS_MENDER: {
		"id": "triage",
		"heal_mult": 1.25,
		"hp_threshold": 0.4,
		"applies_to_ally_heartstop": true,
		"applies_to_enemy_heartstop": false,
	},
	CLASS_GLOAM: {"id": "backstab", "mult": 1.35, "replaces_back": 1.2},
	CLASS_BASTION: {
		"id": "intercept",
		"transfer": 0.4,
		"once_per_bastion_turn_cycle": true,
		"excludes": ["miss", "magma_ticks", "self_damage"],
	},
}

const MARKS_CAP := 5
const IMPACT_CAP := 4


static func normalize_class_id(class_id: String) -> String:
	return class_id.strip_edges().to_lower()


## Dedicated queue allowlist. kestrel and ironjaw only until Backend expands it.
static func is_roster_class(class_id: String) -> bool:
	var id := normalize_class_id(class_id)
	return id == CLASS_KESTREL or id == CLASS_IRONJAW


## Chrome roster, including classes the server still rejects.
static func is_chrome_class(class_id: String) -> bool:
	return normalize_class_id(class_id) in CHROME_ROSTER


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


static func class_label(class_id: String) -> String:
	return display_name(class_id)


static func element_of(class_id: String) -> String:
	match normalize_class_id(class_id):
		CLASS_KESTREL:
			return "air"
		CLASS_IRONJAW:
			return "earth"
		_:
			return ""


## Card element pair. Kestrel and Ironjaw keep their single sim element.
static func class_element_text(class_id: String) -> String:
	match normalize_class_id(class_id):
		CLASS_MENDER:
			return "Water/Water"
		CLASS_GLOAM:
			return "Air/Neutral"
		CLASS_BASTION:
			return "Earth/Earth"
		_:
			return ""


static func class_resources(class_id: String) -> Array:
	var id := normalize_class_id(class_id)
	if CLASS_RESOURCES.has(id):
		return CLASS_RESOURCES[id]
	return []


static func class_proto(class_id: String) -> Dictionary:
	var id := normalize_class_id(class_id)
	if CLASS_PROTO.has(id):
		return CLASS_PROTO[id]
	return {}


static func class_passive(class_id: String) -> Dictionary:
	var id := normalize_class_id(class_id)
	if CLASS_PASSIVES.has(id):
		return CLASS_PASSIVES[id]
	return {}


## True when the row is card data only. CombatSim must reject instead of resolving.
static func awaits_backend(spell_id: String) -> bool:
	return bool(spell(spell_id).get("awaits_backend", false))


## Snapshot current, else the card minimum. Does not invent a gain.
static func resource_amount(unit: Dictionary, spec: Dictionary) -> int:
	var id := str(spec.get("id", ""))
	var floor_n := int(spec.get("min", 0))
	if id != "" and unit.has(id):
		return int(unit[id])
	var bag: Variant = unit.get("resources", null)
	if typeof(bag) == TYPE_DICTIONARY and (bag as Dictionary).has(id):
		var entry: Variant = (bag as Dictionary)[id]
		if typeof(entry) == TYPE_DICTIONARY:
			return int((entry as Dictionary).get("current", (entry as Dictionary).get("value", floor_n)))
		return int(entry)
	if typeof(bag) == TYPE_ARRAY:
		for raw in bag:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw
			var row_id := str(row.get("id", ""))
			if row_id == id or (row_id == "" and str(row.get("label", "")) == str(spec.get("label", ""))):
				return int(row.get("current", floor_n))
	return floor_n


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
	if mode == "self":
		return "self"
	if mode == "cardinal":
		return "4 orthogonal neighbors"
	if mode == "manhattan":
		return "range %d–%d Manhattan" % [lo, hi]
	return "range %d–%d" % [lo, hi]
