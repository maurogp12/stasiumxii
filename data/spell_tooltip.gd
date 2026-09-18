extends RefCounted
class_name SpellTooltip

## Proposed attack-card chrome. Reads Locked kit + CombatSim constants only.
## No kit retunes. Mastery 0 is omitted from the worked example.
## Resist is omitted; if a caller shows it, label it provisional/Open — never Locked.

const FORMULA := "damage = Base × CritMult(1.0) × Passive(1) × Facing"
const LONG_PRESS_SEC := 0.45

## Locked Chebyshev hit bands. Same edges as CombatSim.hit_chance.
const HIT_BANDS := [
	{"lo": 1, "hi": 1, "label": "1→90%"},
	{"lo": 2, "hi": 3, "label": "2–3→80%"},
	{"lo": 4, "hi": 5, "label": "4–5→75%"},
	{"lo": 6, "hi": 8, "label": "6–8→70%"},
]


static func card_text(spell_id: String) -> String:
	return "\n".join(card_lines(spell_id))


static func card_lines(spell_id: String) -> PackedStringArray:
	var def: Dictionary = SpellKits.spell(spell_id)
	var lines: PackedStringArray = PackedStringArray()
	if def.is_empty():
		return lines
	lines.append(str(def.get("name", spell_id)))
	lines.append(_cost_range_line(def))
	var requirement := _requirement_line(def)
	if requirement != "":
		lines.append(requirement)
	lines.append(_connect_line(def))
	if bool(def.get("rolls", false)):
		lines.append(_miss_line(def))
		var bands := hit_band_line(def)
		if bands != "":
			lines.append(bands)
	if int(def.get("base_damage", 0)) > 0:
		for line in damage_example_lines(def):
			lines.append(line)
	for line in _locked_status_lines(def):
		lines.append(line)
	return lines


static func _cost_range_line(def: Dictionary) -> String:
	var metric := "Manhattan" if str(def.get("range_mode", "chebyshev")) == "manhattan" else "Chebyshev"
	return "%d AP / %d MP · range %d–%d %s" % [
		int(def.get("ap", 0)),
		int(def.get("mp", 0)),
		int(def.get("min_range", 0)),
		int(def.get("max_range", 0)),
		metric,
	]


static func _requirement_line(def: Dictionary) -> String:
	if int(def.get("requires_marks_on_target", 0)) > 0:
		return "Needs 1+ Marks on the target."
	if int(def.get("requires_impact", 0)) > 0:
		return "Needs %d Impact (spent on connect)." % int(def.get("spend_impact", def.get("requires_impact", 0)))
	return ""


static func _connect_line(def: Dictionary) -> String:
	match str(def.get("engine_on_connect", "")):
		"mark":
			return "On connect: %d %s. +1 Mark on the target." % [
				int(def.get("base_damage", 0)),
				str(def.get("element", "")).capitalize(),
			]
		"consume_marks":
			return "On connect: %d+%d×M %s. Consumes those Marks." % [
				int(def.get("base_damage", 6)),
				int(def.get("damage_per_mark", 6)),
				str(def.get("element", "")).capitalize(),
			]
		"impact":
			var push_bit := ""
			if int(def.get("push_cells", 0)) > 0:
				push_bit = " Push %d Chebyshev along the line." % int(def["push_cells"])
			return "On connect: %d %s. +1 Impact.%s" % [
				int(def.get("base_damage", 0)),
				str(def.get("element", "")).capitalize(),
				push_bit,
			]
		"spend_impact":
			var stun_bit := ""
			if int(def.get("stun_if_impact_before", 0)) > 0:
				stun_bit = " Stun %d (Locked A) if Impact was %d before the spend." % [
					int(def.get("stun_remaining", 1)),
					int(def.get("stun_if_impact_before", 4)),
				]
			return "On connect: %d %s. Spends %d Impact.%s" % [
				int(def.get("base_damage", 0)),
				str(def.get("element", "")).capitalize(),
				int(def.get("spend_impact", 2)),
				stun_bit,
			]
		"impact_if_adjacent":
			return "On landing: +1 Impact if Chebyshev-adjacent to an enemy. Facing unchanged. Dest-click teleport."
		_:
			return "On connect: —"


static func _miss_line(def: Dictionary) -> String:
	match str(def.get("engine_on_connect", "")):
		"consume_marks":
			return "On miss: Marks retained. AP/MP stay spent."
		"spend_impact":
			return "On miss: Impact retained. AP/MP stay spent."
		"mark":
			return "On miss: no Mark. AP/MP stay spent."
		"impact":
			if int(def.get("push_cells", 0)) > 0:
				return "On miss: no Impact, no push. AP/MP stay spent."
			return "On miss: no Impact. AP/MP stay spent."
		_:
			return "On miss: AP/MP stay spent."


static func hit_band_line(def: Dictionary) -> String:
	if def.is_empty() or not bool(def.get("rolls", false)):
		return ""
	var parts: Array[String] = []
	var min_r := int(def.get("min_range", 0))
	var max_r := int(def.get("max_range", 0))
	for band in HIT_BANDS:
		if int(band["hi"]) < min_r or int(band["lo"]) > max_r:
			continue
		parts.append(str(band["label"]))
	if parts.is_empty():
		return ""
	return "HIT % (Locked): " + ", ".join(PackedStringArray(parts))


static func damage_example_lines(def: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if int(def.get("base_damage", 0)) <= 0:
		return lines
	lines.append(FORMULA)
	var element := str(def.get("element", "")).capitalize()
	if str(def.get("engine_on_connect", "")) == "consume_marks":
		var per := int(def.get("damage_per_mark", 6))
		var base0 := int(def.get("base_damage", 6))
		# Locked gate is 1+ Marks. Worked example uses M=1; do not invent other M.
		var example_base: int = base0 + per * 1
		lines.append("Base %d+%d×M %s" % [base0, per, element])
		lines.append("example M=1: front/side ×1.00 → %d" % example_damage(example_base, CombatSim.FRONT_SIDE_FACING))
		lines.append("example M=1: back ×1.20 → %d" % example_damage(example_base, CombatSim.BACK_FACING))
		return lines
	var base := int(def.get("base_damage", 0))
	lines.append("Base %d %s" % [base, element])
	lines.append("front/side ×1.00 → %d" % example_damage(base, CombatSim.FRONT_SIDE_FACING))
	lines.append("back ×1.20 → %d" % example_damage(base, CombatSim.BACK_FACING))
	return lines


static func example_damage(base: int, facing: float) -> int:
	# Locked Phase A: Base × CritMult(1.0) × Passive(1) × Facing. Mastery 0 omitted.
	return roundi(float(base) * CombatSim.CRIT_MULT * CombatSim.PASSIVE * facing)


static func _locked_status_lines(def: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if int(def.get("push_cells", 0)) > 0:
		lines.append("Locked Push (1): occupied/OOB dest does not move the target; damage/Impact still apply (PushBlocked).")
	if int(def.get("stun_if_impact_before", 0)) > 0:
		lines.append("Stun %d (Locked A): blocks move + cast + face; End Turn allowed." % int(def.get("stun_remaining", 1)))
	return lines


static func has_hit_percent(spell_id: String) -> bool:
	var def: Dictionary = SpellKits.spell(spell_id)
	return not def.is_empty() and bool(def.get("rolls", false))
