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
	"premium", "targets", "caps", "koliseo_sets_off", "coins", "drops",
	"set_budget", "tiers", "level_gap", "damage_classes", "kit_by_ap",
	"open_items",
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
	var world_hours := world_only_hours(curve, world_min, world_xp)
	var premium: Dictionary = inputs.get("premium", {})
	var xp_bonus := _num(premium.get("xp_bonus", 0))
	var premium_hours := world_hours
	if xp_bonus > -0.999:
		premium_hours = world_hours / (1.0 + xp_bonus)
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
	var free_target := _num(targets.get("hours_to_cap", 0))
	var band_lo := _num(targets.get("hours_to_cap_min", 0))
	var band_hi := _num(targets.get("hours_to_cap_max", 0))
	var premium_target := _num(targets.get("premium_hours", 0))
	var mix_rate := _mix_xp_per_minute(inputs)
	var mix_hours: Variant = "Open"
	var premium_mix: Variant = "Open"
	var xp_by_source: Dictionary = {}
	var milestones: Dictionary = {}
	var last_step: Variant = "Open"
	var slower: Variant = "Open"
	if mix_rate <= 0.0:
		findings.append(_finding("mission_minutes", "open", "Mission duration is Open, so normal-mix hours are not scored."))
		findings.append(_finding(
			"normal_mix_band",
			"open",
			"Free normal-mix target %.0f h (accept %.0f-%.0f) and premium target %.0f h are not scored. Mission minutes are Open." % [
				free_target, band_lo, band_hi, premium_target,
			],
		))
	else:
		var free_mix := _paced_profile_hours(curve, mix_rate)
		var prem_mix := free_mix
		if xp_bonus > -0.999:
			prem_mix = free_mix / (1.0 + xp_bonus)
		mix_hours = free_mix
		premium_mix = prem_mix
		xp_by_source = _xp_shares(inputs, mix_rate)
		milestones = _milestone_hours(curve, inputs, mix_rate)
		last_step = _last_step_hours(curve, mix_rate)
		if free_mix > 0.0:
			slower = world_hours / free_mix
		var mix_faults: Array = []
		var paced := _pace_start(curve) > 0.0 and curve.has("pace_start") and curve.has("pace_ratio")
		if paced and not in_accept_band(free_mix, inputs):
			mix_faults.append("free normal-mix hours are outside the accept band")
		var prem_lo := band_lo
		var prem_hi := band_hi
		if xp_bonus > -0.999:
			prem_lo = band_lo / (1.0 + xp_bonus)
			prem_hi = band_hi / (1.0 + xp_bonus)
		if paced and (prem_mix + 0.0001 < prem_lo or prem_mix - 0.0001 > prem_hi):
			mix_faults.append("premium normal-mix hours are outside the scaled accept band")
		var slow_lo := _num(targets.get("world_only_slower_min", 0))
		var slow_hi := _num(targets.get("world_only_slower_max", 0))
		if slow_lo > 0.0 and slow_hi > 0.0 and typeof(slower) != TYPE_STRING:
			var slow_num := float(slower)
			if slow_num + 0.0001 < slow_lo or slow_num - 0.0001 > slow_hi:
				mix_faults.append("world-only slowdown is outside the corrected band")
		var share_cap := _num(targets.get("max_source_share", 0))
		if share_cap > 0.0:
			for group in xp_by_source.keys():
				if float(xp_by_source[group]) > share_cap + 0.0001:
					mix_faults.append("%s XP share is above the source cap" % str(group))
		if paced:
			_milestone_faults(inputs, milestones, last_step, mix_faults)
		for fault in mix_faults:
			errors.append(str(fault))
		findings.append(_finding(
			"mission_minutes",
			"pass",
			"Talk 3 min, reach 5 min, defeat is fights times minutes per fight, clear 20 min. Missions split the mission share evenly.",
		))
		findings.append(_finding(
			"normal_mix_band",
			"pass" if mix_faults.is_empty() else "outside",
			"Free normal mix %.2f h (accept %.0f-%.0f). Premium normal mix %.2f h (target %.0f, scaled band %.0f-%.0f). Pace %.4f and %.4f. World-only %.2f h is not scored against that band." % [
				free_mix, band_lo, band_hi, prem_mix, premium_target, prem_lo, prem_hi,
				_pace_start(curve), _pace_ratio(curve), world_hours,
			],
		))
		findings.append(_finding(
			"xp_shares",
			"pass" if mix_faults.is_empty() else "outside",
			"XP by play time: world %.1f%%, dungeons %.1f%%, missions %.1f%%." % [
				float(xp_by_source.get("world", 0)) * 100.0,
				float(xp_by_source.get("dungeon", 0)) * 100.0,
				float(xp_by_source.get("mission", 0)) * 100.0,
			],
		))
		findings.append(_finding(
			"world_only_slower",
			"pass" if mix_faults.is_empty() else "outside",
			"World-only is %.2f times the normal mix. The corrected band is %.2f-%.2f. The pace factor is not retuned." % [
				float(slower) if typeof(slower) != TYPE_STRING else 0.0, slow_lo, slow_hi,
			],
		))
	if str(inputs.get("profiles", {}).get("dungeon_heavy", "")) == "Open":
		findings.append(_finding("dungeon_heavy", "open", "The dungeon-heavy mix is Open. The spec names the profile and does not give its time split."))
	if str(inputs.get("per_point_values", "")) == "Open":
		findings.append(_finding("per_point_values", "open", "Per-point Mastery, Vitality, Swift and Resist values are Open, so set rules 3, 4 and 5 are not scored."))
	var coins := _coins(inputs, cap)
	var drops := _drops(inputs, star)
	var premium_coins := _scaled(coins, 1.0 + _num(premium.get("coin_bonus", 0)))
	var premium_drops := _scaled(drops, 1.0 + _num(premium.get("drop_bonus", 0)))
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
		"premium_world_hours": premium_hours,
		"dungeon_vs_world": ratio,
		"normal_mix_hours": mix_hours,
		"premium_mix_hours": premium_mix,
		"xp_shares": xp_by_source,
		"milestone_hours": milestones,
		"last_level_hours": last_step,
		"world_only_slower": slower,
		"normal_mix_label": _mix_label(inputs),
		"hours_to_cap": free_target,
		"hours_to_cap_min": band_lo,
		"hours_to_cap_max": band_hi,
		"premium_hours_target": premium_target,
		"zone_rows": zone_rows,
		"findings": findings,
		"coins": coins,
		"drops": drops,
		"premium_coins": premium_coins,
		"premium_drops": premium_drops,
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
	lines.append("| World only, free | %.2f hours to the cap |" % float(result.get("world_only_hours", 0)))
	lines.append("| World only, premium | %.2f hours to the cap |" % float(result.get("premium_world_hours", 0)))
	lines.append("| Normal mix, free (%s) | %s |" % [str(result.get("normal_mix_label", "Open")), _hours_cell(result.get("normal_mix_hours", "Open"))])
	lines.append("| Normal mix, premium | %s |" % _hours_cell(result.get("premium_mix_hours", "Open")))
	lines.append("| Free target (accept %.0f-%.0f) | %.0f hours |" % [
		float(result.get("hours_to_cap_min", 0)),
		float(result.get("hours_to_cap_max", 0)),
		float(result.get("hours_to_cap", 0)),
	])
	lines.append("| Premium target | %.0f hours |" % float(result.get("premium_hours_target", 0)))
	lines.append("| Dungeon heavy | Open |")
	lines.append("| Party of 4 | XP share 0.7 each. Time is Open. |")
	lines.append("")
	lines.append("Dungeon XP per minute is %.3f times open-world XP per minute at the normal star." % float(result.get("dungeon_vs_world", 0)))
	var shares: Dictionary = result.get("xp_shares", {})
	if not shares.is_empty():
		lines.append("XP share by play time: world %.1f%%, dungeons %.1f%%, missions %.1f%%." % [
			float(shares.get("world", 0)) * 100.0,
			float(shares.get("dungeon", 0)) * 100.0,
			float(shares.get("mission", 0)) * 100.0,
		])
	var slower: Variant = result.get("world_only_slower", "Open")
	if typeof(slower) == TYPE_FLOAT or typeof(slower) == TYPE_INT:
		lines.append("World-only takes %.2f times as long as the normal mix. It is not scored against the free accept band." % float(slower))
	var milestones: Dictionary = result.get("milestone_hours", {})
	if not milestones.is_empty():
		lines.append("")
		lines.append("## Normal-mix milestones, free")
		lines.append("")
		lines.append("| Level | Hours |")
		lines.append("|---|---|")
		for key in milestones.keys():
			lines.append("| %s | %.2f |" % [str(key), float(milestones[key])])
		var last: Variant = result.get("last_level_hours", "Open")
		if typeof(last) == TYPE_FLOAT or typeof(last) == TYPE_INT:
			lines.append("")
			lines.append("Last level step: %.2f hours." % float(last))
	lines.append("")
	lines.append("## Coins and drops per hour at the cap, fighting at that level")
	lines.append("")
	var coins: Dictionary = result.get("coins", {})
	var drops: Dictionary = result.get("drops", {})
	lines.append("| Source | Coins / hour | Regular parts / hour | Rare parts / hour | Boxes / hour |")
	lines.append("|---|---|---|---|---|")
	var premium_coins: Dictionary = result.get("premium_coins", {})
	var premium_drops: Dictionary = result.get("premium_drops", {})
	lines.append("| Open world, free | %.1f | %.2f | %.2f | %.2f |" % [
		float(coins.get("world", 0)), float(drops.get("world_regular", 0)),
		float(drops.get("world_rare", 0)), float(drops.get("world_box", 0)),
	])
	lines.append("| Open world, premium | %.1f | %.2f | %.2f | %.2f |" % [
		float(premium_coins.get("world", 0)), float(premium_drops.get("world_regular", 0)),
		float(premium_drops.get("world_rare", 0)), float(premium_drops.get("world_box", 0)),
	])
	lines.append("| Dungeon, normal star, free | %.1f | %.2f | %.2f | %.2f |" % [
		float(coins.get("dungeon", 0)), float(drops.get("dungeon_regular", 0)),
		float(drops.get("dungeon_rare", 0)), float(drops.get("dungeon_box", 0)),
	])
	lines.append("| Dungeon, normal star, premium | %.1f | %.2f | %.2f | %.2f |" % [
		float(premium_coins.get("dungeon", 0)), float(premium_drops.get("dungeon_regular", 0)),
		float(premium_drops.get("dungeon_rare", 0)), float(premium_drops.get("dungeon_box", 0)),
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


static func _hours_cell(value: Variant) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return "%.2f hours to the cap" % float(value)
	return str(value)


static func _mix_rows(inputs: Dictionary) -> Array:
	var minutes: Dictionary = inputs.get("minutes", {})
	var shares: Dictionary = inputs.get("xp_share_of_step", {})
	var profiles: Dictionary = inputs.get("profiles", {})
	var mix: Variant = profiles.get("normal_mix", {})
	if typeof(mix) != TYPE_DICTIONARY:
		return []
	var talk := _num(minutes.get("mission_talk", 0))
	var reach := _num(minutes.get("mission_reach", 0))
	var fights := _num(minutes.get("mission_defeat_fights", 0))
	var per_fight := _num(minutes.get("mission_defeat_per_fight", 0))
	var clear_min := _num(minutes.get("mission_clear", 0))
	if talk <= 0.0 or reach <= 0.0 or fights <= 0.0 or per_fight <= 0.0 or clear_min <= 0.0:
		return []
	var mission_weight := _num((mix as Dictionary).get("mission", 0))
	var kinds: Array[String] = ["talk", "reach", "defeat", "clear"]
	var each := mission_weight / float(kinds.size())
	var star := _num(inputs.get("normal_star", 0))
	return [
		{
			"group": "world",
			"weight": _num((mix as Dictionary).get("world", 0)),
			"xp": _num(shares.get("world_fight", 0)),
			"minutes": _num(minutes.get("world_fight", 0)),
		},
		{
			"group": "dungeon",
			"weight": _num((mix as Dictionary).get("dungeon", 0)),
			"xp": _num(shares.get("dungeon_win", 0)) * star,
			"minutes": _num(minutes.get("dungeon_run", 0)),
		},
		{"group": "mission", "weight": each, "xp": _num(shares.get("mission_talk", 0)), "minutes": talk},
		{"group": "mission", "weight": each, "xp": _num(shares.get("mission_reach", 0)), "minutes": reach},
		{"group": "mission", "weight": each, "xp": _num(shares.get("mission_defeat", 0)), "minutes": fights * per_fight},
		{"group": "mission", "weight": each, "xp": _num(shares.get("mission_clear_dungeon", 0)), "minutes": clear_min},
	]


static func _mix_xp_per_minute(inputs: Dictionary) -> float:
	var rows := _mix_rows(inputs)
	if rows.is_empty():
		return 0.0
	var rate := 0.0
	for row in rows:
		var span := float(row["minutes"])
		if span <= 0.0:
			return 0.0
		rate += float(row["weight"]) * float(row["xp"]) / span
	return rate


static func _xp_shares(inputs: Dictionary, rate: float) -> Dictionary:
	var grouped := {"world": 0.0, "dungeon": 0.0, "mission": 0.0}
	if rate <= 0.0:
		return grouped
	for row in _mix_rows(inputs):
		var group := str(row["group"])
		grouped[group] = float(grouped[group]) + float(row["weight"]) * float(row["xp"]) / float(row["minutes"]) / rate
	return grouped


static func _paced_profile_hours(curve: Dictionary, xp_per_minute: float) -> float:
	if xp_per_minute <= 0.0:
		return 0.0
	var cap := int(curve.get("max_level", 0))
	var hours := 0.0
	for level in range(1, cap):
		var pace := _pace(curve, level)
		if pace <= 0.0:
			return 0.0
		hours += 1.0 / (xp_per_minute * pace) / 60.0
	return hours


static func _hours_until(curve: Dictionary, xp_per_minute: float, level_reached: int) -> float:
	if xp_per_minute <= 0.0:
		return 0.0
	var cap := int(curve.get("max_level", 0))
	var stop := level_reached
	if stop > cap:
		stop = cap
	var hours := 0.0
	for level in range(1, stop):
		var pace := _pace(curve, level)
		if pace <= 0.0:
			return 0.0
		hours += 1.0 / (xp_per_minute * pace) / 60.0
	return hours


static func _milestone_hours(curve: Dictionary, inputs: Dictionary, rate: float) -> Dictionary:
	var expected: Dictionary = inputs.get("targets", {}).get("milestone_hours", {})
	var cap := int(curve.get("max_level", 0))
	var out := {}
	for key in expected.keys():
		var level := cap if str(key) == "cap" else int(str(key))
		if level > cap:
			continue
		out[str(key)] = _hours_until(curve, rate, level)
	return out


static func _last_step_hours(curve: Dictionary, rate: float) -> float:
	var cap := int(curve.get("max_level", 0))
	if cap < 2 or rate <= 0.0:
		return 0.0
	var pace := _pace(curve, cap - 1)
	if pace <= 0.0:
		return 0.0
	return 1.0 / (rate * pace) / 60.0


static func _milestone_faults(inputs: Dictionary, milestones: Dictionary, last_step: Variant, faults: Array) -> void:
	var targets: Dictionary = inputs.get("targets", {})
	var near := _num(targets.get("milestone_near", 0))
	if near <= 0.0:
		return
	var expected: Dictionary = targets.get("milestone_hours", {})
	for key in milestones.keys():
		var want := _num(expected.get(key, 0))
		var got := float(milestones[key])
		if want <= 0.0:
			continue
		if absf(got - want) / want > near + 0.0001:
			faults.append("milestone %s hours are not near the target" % str(key))
	var last_want := _num(targets.get("last_level_hours", 0))
	if last_want > 0.0 and (typeof(last_step) == TYPE_FLOAT or typeof(last_step) == TYPE_INT):
		if absf(float(last_step) - last_want) / last_want > near + 0.0001:
			faults.append("the last level's hours are not near the target")


static func world_only_hours(curve: Dictionary, world_min: float, world_xp: float) -> float:
	if world_xp <= 0.0 or world_min <= 0.0:
		return 0.0
	var cap := int(curve.get("max_level", 0))
	var hours := 0.0
	for level in range(1, cap):
		var pace := _pace(curve, level)
		if pace <= 0.0:
			return 0.0
		hours += world_min / (world_xp * pace) / 60.0
	return hours


static func in_accept_band(hours: float, inputs: Dictionary) -> bool:
	var targets: Dictionary = inputs.get("targets", {})
	var lo := _num(targets.get("hours_to_cap_min", 0))
	var hi := _num(targets.get("hours_to_cap_max", 0))
	return hours + 0.0001 >= lo and hours - 0.0001 <= hi


static func _pace(curve: Dictionary, level: int) -> float:
	var start := _pace_start(curve)
	var ratio := _pace_ratio(curve)
	if start <= 0.0 or ratio <= 0.0:
		return 1.0
	return start * pow(ratio, float(level - 1))


static func _pace_start(curve: Dictionary) -> float:
	if not curve.has("pace_start") or not curve.has("pace_ratio"):
		return 1.0
	return _num(curve.get("pace_start", 1))


static func _pace_ratio(curve: Dictionary) -> float:
	if not curve.has("pace_start") or not curve.has("pace_ratio"):
		return 1.0
	return _num(curve.get("pace_ratio", 1))


static func _scaled(row: Dictionary, factor: float) -> Dictionary:
	var out := {}
	for key in row.keys():
		out[key] = _num(row[key]) * factor
	return out


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
