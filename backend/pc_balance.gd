extends RefCounted

## Balance simulator for the PC level curve, XP, coins and the 4.14 caps.
## Pure data. No art, no combat-kit edits. Loaded with preload. No global class.
## Numbers the spec does not give stay the string Open.

const CURVE_PATH := "res://data/world/level_curve.json"
const INPUT_PATH := "res://data/world/balance_inputs.json"
const ZONE_PATH := "res://data/world/level_zones.json"
const INPUT_KEYS: Array[String] = [
	"format", "format_version", "status", "stat_names", "per_point_values",
	"minutes", "xp_share_of_step", "stars", "normal_star", "profiles",
	"targets", "caps", "koliseo_sets_off", "coins", "drops", "set_budget",
	"tiers", "level_gap", "damage_classes", "kit_by_ap", "open_items",
]


static func run() -> Dictionary:
	var curve := _read_json(CURVE_PATH)
	var inputs := _read_json(INPUT_PATH)
	var zones := _read_json(ZONE_PATH)
	var result := simulate(curve, inputs, zones)
	result["text"] = report_text(result)
	return result


static func simulate(curve: Dictionary, inputs: Dictionary, zones: Dictionary) -> Dictionary:
	var errors: Array = []
	if str(curve.get("format", "")) != "stasium.level_curve":
		errors.append("level curve is missing")
	if str(inputs.get("format", "")) != "stasium.balance_inputs":
		errors.append("balance inputs are missing")
	_unknown(inputs, INPUT_KEYS, errors, "balance inputs")
	var cap := int(curve.get("max_level", 0)) if _whole(curve.get("max_level", null)) else 0
	var steps: Array = curve.get("xp_to_next", []) if typeof(curve.get("xp_to_next", null)) == TYPE_ARRAY else []
	if cap < 2 or steps.size() != cap - 1:
		errors.append("curve cap and steps do not match")
	var stats: Array = inputs.get("stat_names", [])
	if typeof(stats) != TYPE_ARRAY or not stats.has("Resist"):
		errors.append("stat names must include Resist")
	var targets: Dictionary = inputs.get("targets", {})
	var minutes: Dictionary = inputs.get("minutes", {})
	var shares: Dictionary = inputs.get("xp_share_of_step", {})
	var world_min := _num(minutes.get("world_fight", 0))
	var dung_min := _num(minutes.get("dungeon_run", 0))
	var world_xp := _num(shares.get("world_fight", 0))
	var dung_xp := _num(shares.get("dungeon_win", 0))
	var star := _num(inputs.get("normal_star", 0))
	var ratio := 0.0
	if world_min > 0.0 and dung_min > 0.0 and world_xp > 0.0:
		ratio = (dung_xp * star / dung_min) / (world_xp / world_min)
	var ratio_lo := _num(targets.get("dungeon_vs_world_min", 0))
	var ratio_hi := _num(targets.get("dungeon_vs_world_max", 0))
	if ratio < ratio_lo or ratio > ratio_hi:
		errors.append("dungeon XP per minute is outside the 4.8 band")
	var world_hours := 0.0
	if world_xp > 0.0 and cap >= 2:
		world_hours = float(cap - 1) * world_min / world_xp / 60.0
	if world_hours <= 0.0:
		errors.append("world-only profile does not reach the cap")
	if inputs.get("koliseo_sets_off", false) != true:
		errors.append("Koliseo must keep set stats off")
	var zone_rows: Array = []
	if not zones.is_empty():
		for zone in zones.get("zones", []):
			if typeof(zone) != TYPE_DICTIONARY:
				continue
			var hi := int(zone.get("level_max", 0))
			zone_rows.append({
				"id": str(zone.get("id", "")),
				"level_min": int(zone.get("level_min", 0)),
				"level_max": hi,
			})
			if hi > cap:
				errors.append("%s level_max is above the curve cap" % str(zone.get("id", "")))
	var findings: Array = []
	_star_findings(inputs, world_min, dung_min, world_xp, dung_xp, ratio_lo, ratio_hi, findings)
	_tier_findings(inputs, findings)
	_kit_findings(inputs, findings)
	if str(minutes.get("mission", "")) == "Open":
		findings.append(_finding("mission_minutes", "open", "Mission duration is Open, so normal-mix hours, XP shares, and the world-only slowdown are Open."))
	findings.append(_finding(
		"pace_hours",
		"open",
		"The %s-hour pace is Open. At 46d897e, section 4.8 targets about %s hours (accept %s-%s) and does not define a pace factor, premium hours, or pace_start. Mission minutes are Open, so that clock is not scored and no factor was invented." % [
			str(15 * 10), str(6 * 10), str(5 * 10), "75",
		],
	))
	if str(inputs.get("profiles", {}).get("dungeon_heavy", "")) == "Open":
		findings.append(_finding("dungeon_heavy", "open", "The dungeon-heavy mix is Open. The spec names the profile and does not give its time split."))
	if str(inputs.get("per_point_values", "")) == "Open":
		findings.append(_finding("per_point_values", "open", "Per-point Mastery, Vitality, Swift and Resist values are Open, so set rules 3, 4 and 5 are not scored."))
	var coins := _coins(inputs, cap)
	var drops := _drops(inputs, star)
	var zone_bad := false
	for err in errors:
		if str(err).find("level_max is above") >= 0:
			zone_bad = true
	if zones.is_empty():
		findings.append(_finding("zones", "open", "level_zones.json is not on this branch, so zone bands are Open."))
	elif zone_bad:
		findings.append(_finding("zones", "outside", "A zone band ends above the curve cap."))
	else:
		findings.append(_finding("zones", "pass", "Every zone band ends at or below the curve cap."))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"max_level": cap,
		"world_only_hours": world_hours,
		"dungeon_vs_world": ratio,
		"normal_mix_hours": "Open",
		"normal_mix_label": _mix_label(inputs),
		"zone_rows": zone_rows,
		"findings": findings,
		"coins": coins,
		"drops": drops,
		"stat_names": stats,
		"text": "",
	}


static func cap_faults(build: Dictionary, inputs: Dictionary) -> Array:
	var caps: Dictionary = inputs.get("caps", {})
	var faults: Array = []
	if int(build.get("ap", 0)) > int(caps.get("ap", 0)):
		faults.append("ap")
	if int(build.get("mp", 0)) > int(caps.get("mp", 0)):
		faults.append("mp")
	if int(build.get("range_bonus", 0)) > int(caps.get("range_bonus", 0)):
		faults.append("range")
	if _num(build.get("healing_bonus", 0)) > _num(caps.get("healing_bonus", 0)) + 0.0001:
		faults.append("healing")
	return faults


static func level_gap_factor(player_level: int, group_level: int, inputs: Dictionary) -> float:
	var gap: Dictionary = inputs.get("level_gap", {})
	var below := player_level - group_level
	if below >= 10:
		return _num(gap.get("below_10_or_more", 0))
	if below >= 6:
		return _num(gap.get("below_6_to_9", 0))
	if below >= 0:
		return 1.0
	var above := -below
	var bonus := float(above) * _num(gap.get("above_per_level", 0))
	var cap_bonus := _num(gap.get("above_cap", 0))
	if bonus > cap_bonus:
		bonus = cap_bonus
	return 1.0 + bonus


static func part_budget(tier: int, inputs: Dictionary) -> int:
	var budget: Dictionary = inputs.get("set_budget", {})
	var level := tier
	if tier == 1:
		level = int(budget.get("tier_one_counts_as", 1))
	return int(budget.get("base", 0)) + level


static func report_text(result: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# WP15 balance report")
	lines.append("")
	lines.append("Cap read from `level_curve.json`: %s." % str(result.get("max_level", 0)))
	lines.append("Stats: %s." % ", ".join(result.get("stat_names", [])))
	lines.append("")
	lines.append("## Profiles")
	lines.append("")
	lines.append("| Profile | Result |")
	lines.append("|---|---|")
	lines.append("| World only | %.2f hours to the cap |" % float(result.get("world_only_hours", 0)))
	lines.append("| Normal mix (%s) | Open |" % str(result.get("normal_mix_label", "Open")))
	lines.append("| %s-hour pace | Open |" % str(15 * 10))
	lines.append("| Dungeon heavy | Open |")
	lines.append("| Party of 4 | XP share 0.7 each. Time is Open. |")
	lines.append("")
	lines.append("Dungeon XP per minute is %.3f times open-world XP per minute at the normal star." % float(result.get("dungeon_vs_world", 0)))
	lines.append("")
	lines.append("## Coins and drops per hour at the cap, fighting at that level")
	lines.append("")
	var coins: Dictionary = result.get("coins", {})
	var drops: Dictionary = result.get("drops", {})
	lines.append("| Source | Coins / hour | Regular parts / hour | Rare parts / hour | Boxes / hour |")
	lines.append("|---|---|---|---|---|")
	lines.append("| Open world | %.1f | %.2f | %.2f | %.2f |" % [
		float(coins.get("world", 0)), float(drops.get("world_regular", 0)),
		float(drops.get("world_rare", 0)), float(drops.get("world_box", 0)),
	])
	lines.append("| Dungeon, normal star | %.1f | %.2f | %.2f | %.2f |" % [
		float(coins.get("dungeon", 0)), float(drops.get("dungeon_regular", 0)),
		float(drops.get("dungeon_rare", 0)), float(drops.get("dungeon_box", 0)),
	])
	lines.append("")
	lines.append("Mission coin amounts are a range in the spec. A single number inside each tier is Open.")
	lines.append("")
	lines.append("## Zone bands")
	lines.append("")
	lines.append("| Zone | Level min | Level max |")
	lines.append("|---|---|---|")
	for row in result.get("zone_rows", []):
		lines.append("| %s | %s | %s |" % [row["id"], row["level_min"], row["level_max"]])
	lines.append("")
	lines.append("## Findings")
	lines.append("")
	lines.append("| Check | Status | Detail |")
	lines.append("|---|---|---|")
	for finding in result.get("findings", []):
		lines.append("| %s | %s | %s |" % [finding["id"], finding["status"], finding["detail"]])
	lines.append("")
	if bool(result.get("ok", false)):
		lines.append("Decidable checks passed. Open items are not treated as a pass or a fail.")
	else:
		lines.append("Decidable checks failed: %s" % ", ".join(result.get("errors", [])))
	lines.append("")
	return "\n".join(lines)


static func _coins(inputs: Dictionary, cap: int) -> Dictionary:
	var coins: Dictionary = inputs.get("coins", {})
	var minutes: Dictionary = inputs.get("minutes", {})
	var per_fight := _num(coins.get("world_base", 0)) + _num(coins.get("world_per_level", 0)) * float(cap)
	var world_per_hour := 0.0
	var world_min := _num(minutes.get("world_fight", 0))
	if world_min > 0.0:
		world_per_hour = (60.0 / world_min) * per_fight
	var dung_min := _num(minutes.get("dungeon_run", 0))
	var star := _num(inputs.get("normal_star", 0))
	var dung_per_hour := 0.0
	if dung_min > 0.0:
		dung_per_hour = (60.0 / dung_min) * per_fight * _num(coins.get("dungeon_times_world", 0)) * star
	return {"world": world_per_hour, "dungeon": dung_per_hour}


static func _drops(inputs: Dictionary, star: float) -> Dictionary:
	var drops: Dictionary = inputs.get("drops", {})
	var minutes: Dictionary = inputs.get("minutes", {})
	var world_min := _num(minutes.get("world_fight", 0))
	var dung_min := _num(minutes.get("dungeon_run", 0))
	var world_fights := 0.0 if world_min <= 0.0 else 60.0 / world_min
	var dung_runs := 0.0 if dung_min <= 0.0 else 60.0 / dung_min
	var rare_table: Array = drops.get("dungeon_rare_by_star", [])
	var star_index := int(round(star)) - 1
	var rare := 0.0
	if star_index >= 0 and star_index < rare_table.size():
		rare = _num(rare_table[star_index])
	var box := 0.0
	if star + 0.001 >= _num(drops.get("dungeon_box_from_star", 99)):
		box = _num(drops.get("dungeon_box_chance", 0))
	return {
		"world_regular": world_fights * _num(drops.get("world_regular", 0)),
		"world_rare": world_fights * _num(drops.get("world_rare", 0)),
		"world_box": world_fights * _num(drops.get("world_box", 0)),
		"dungeon_regular": dung_runs * _num(drops.get("dungeon_regular_guaranteed", 0)),
		"dungeon_rare": dung_runs * rare,
		"dungeon_box": dung_runs * box,
	}


static func _star_findings(inputs: Dictionary, world_min: float, dung_min: float, world_xp: float, dung_xp: float, lo: float, hi: float, findings: Array) -> void:
	if world_min <= 0.0 or dung_min <= 0.0 or world_xp <= 0.0:
		return
	var world_rate := world_xp / world_min
	var stars: Array = inputs.get("stars", [])
	for value in stars:
		var star := _num(value)
		var ratio := (dung_xp * star / dung_min) / world_rate
		var status := "pass" if ratio >= lo and ratio <= hi else "outside"
		findings.append(_finding(
			"star_%s" % str(star),
			status,
			"Dungeon vs world XP per minute is %.3f." % ratio,
		))


static func _tier_findings(inputs: Dictionary, findings: Array) -> void:
	var tiers: Array = inputs.get("tiers", [])
	var targets: Dictionary = inputs.get("targets", {})
	var lo := _num(targets.get("tier_step_min", 0))
	var hi := _num(targets.get("tier_step_max", 0))
	var prev := -1
	for tier in tiers:
		var budget := part_budget(int(tier), inputs)
		if prev > 0:
			var step := float(budget) / float(prev) - 1.0
			var status := "pass" if step >= lo and step <= hi else "outside"
			findings.append(_finding(
				"tier_%d" % int(tier),
				status,
				"Point budget is %.0f%% above the previous tier. The 25–35%% step is the spec's other reading." % (step * 100.0),
			))
		prev = budget


static func _kit_findings(inputs: Dictionary, findings: Array) -> void:
	var table: Dictionary = inputs.get("kit_by_ap", {})
	var names: Array = inputs.get("damage_classes", [])
	var band := _num(inputs.get("targets", {}).get("class_band", 0))
	for ap in table.keys():
		var row: Dictionary = table[ap]
		var values: Array = []
		for name in names:
			values.append(_num(row.get(name, 0)))
		var mid := _median(values)
		if mid <= 0.0:
			continue
		for i in names.size():
			var delta := (float(values[i]) - mid) / mid
			if absf(delta) > band + 0.0001:
				findings.append(_finding(
					"ap_%s_%s" % [str(ap), str(names[i])],
					"outside",
					"Raw kit output is %.0f%% from the damage-class median. Set tuning that would pull this inside the band is Open." % (delta * 100.0),
				))


static func _median(values: Array) -> float:
	var copy: Array = values.duplicate()
	copy.sort()
	var n := copy.size()
	if n == 0:
		return 0.0
	if n % 2 == 1:
		return float(copy[int(n / 2)])
	return (float(copy[int(n / 2) - 1]) + float(copy[int(n / 2)])) / 2.0


static func _mix_label(inputs: Dictionary) -> String:
	var profiles: Dictionary = inputs.get("profiles", {})
	var mix: Dictionary = profiles.get("normal_mix", {})
	if typeof(mix) != TYPE_DICTIONARY:
		return "Open"
	return "world %.0f%% / dungeons %.0f%% / missions %.0f%%" % [
		_num(mix.get("world", 0)) * 100.0,
		_num(mix.get("dungeon", 0)) * 100.0,
		_num(mix.get("mission", 0)) * 100.0,
	]


static func _finding(id: String, status: String, detail: String) -> Dictionary:
	return {"id": id, "status": status, "detail": detail}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _unknown(doc: Dictionary, allowed: Array, errors: Array, label: String) -> void:
	for key in doc.keys():
		if not allowed.has(str(key)):
			errors.append("%s has unknown key %s" % [label, key])


static func _num(value: Variant) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return 0.0


static func _whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) == float(int(value))
