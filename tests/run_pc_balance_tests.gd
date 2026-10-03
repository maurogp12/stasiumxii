extends SceneTree

## Balance simulator. Decidable 4.8 and 4.14 checks must pass.
## Items the spec leaves Open are reported as Open, not as invented numbers.
## Run: godot --headless --path . -s res://tests/run_pc_balance_tests.gd

const Balance = preload("res://backend/pc_balance.gd")
const Premium = preload("res://backend/pc_premium.gd")
const CURVE_PATH := "res://data/world/level_curve.json"
const INPUT_PATH := "res://data/world/balance_inputs.json"
const ZONE_PATH := "res://data/world/level_zones.json"
const SCHEMA_PATH := "res://data/world/schema/balance_inputs.schema.json"

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run()
	print("pc balance tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_test_source()
	_test_schema()
	var result: Dictionary = Balance.run()
	_test_shipped(result)
	_test_caps()
	_test_level_gap()
	_test_budgets()
	_test_over_cap_zone()
	_test_unknown_key()
	_test_short_curve()
	_test_no_phone_dungeon_names()


func _test_source() -> void:
	var src := FileAccess.get_file_as_string("res://backend/pc_balance.gd")
	eq(src.find("class_name") < 0, true, "no global class declaration")
	eq(src.find("Ward") < 0, true, "the stat is Resist, not Ward")
	eq(src.find(str(5 * 10)) < 0, true, "code does not hardcode the phase-1 cap")
	eq(src.find("res://mobile") < 0, true, "does not import a mobile script")


func _test_schema() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	eq(schema["additionalProperties"], false, "schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.balance_inputs", "schema format")


func _test_shipped(result: Dictionary) -> void:
	eq(result["ok"], true, "shipped numbers pass the decidable checks (%s)" % str(result["errors"]))
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CURVE_PATH))
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	eq(int(result["max_level"]), int(curve["max_level"]), "cap is the curve's max_level")
	var tiers: Array = inputs["tiers"]
	eq(int(tiers[tiers.size() - 1]), int(curve["max_level"]), "the top set tier matches the curve cap")
	var stats: Array = result["stat_names"]
	eq(stats.has("Resist"), true, "Resist is a stat")
	eq(stats.has("Ward"), false, "Ward is not a stat")
	var xp_bonus := float(inputs["premium"]["xp_bonus"])
	var targets: Dictionary = inputs["targets"]
	var mix_expect := _mix_hours(curve, inputs)
	near(float(result["normal_mix_hours"]), mix_expect, "free normal-mix hours use the mission minutes")
	near(float(result["premium_mix_hours"]), mix_expect / (1.0 + xp_bonus), "premium normal-mix hours apply the XP bonus")
	eq(Balance.in_accept_band(float(result["normal_mix_hours"]), inputs), true, "free normal-mix hours are inside 130-170")
	var prem_lo := float(targets["hours_to_cap_min"]) / (1.0 + xp_bonus)
	var prem_hi := float(targets["hours_to_cap_max"]) / (1.0 + xp_bonus)
	var prem_mix := float(result["premium_mix_hours"])
	eq(prem_mix + 0.0001 >= prem_lo and prem_mix - 0.0001 <= prem_hi, true, "premium normal-mix hours sit near 120")
	near(float(curve["pace_start"]), 1.6, "pace_start is the spec factor")
	near(float(curve["pace_ratio"]), 0.9532, "pace_ratio is the spec factor")
	var expect := _paced_hours(curve, inputs)
	near(float(result["world_only_hours"]), expect, "free world-only hours use the pace factor")
	near(float(result["premium_world_hours"]), expect / (1.0 + xp_bonus), "premium world-only hours apply the XP bonus")
	eq(float(targets["hours_to_cap"]), 150.0, "free target is 150 hours")
	eq(float(targets["hours_to_cap_min"]), 130.0, "accept band starts at 130 hours")
	eq(float(targets["hours_to_cap_max"]), 170.0, "accept band ends at 170 hours")
	eq(float(targets["premium_hours"]), 120.0, "premium target is 120 hours")
	eq(Balance.in_accept_band(float(targets["hours_to_cap"]), inputs), true, "150 hours is inside the accept band")
	eq(Balance.in_accept_band(float(targets["hours_to_cap_min"]) - 1.0, inputs), false, "one hour under the band is outside")
	eq(Balance.in_accept_band(float(targets["hours_to_cap_max"]) + 1.0, inputs), false, "one hour over the band is outside")
	near(float(targets["premium_hours"]), float(targets["hours_to_cap"]) / (1.0 + xp_bonus), "120 hours is the 150-hour clock with the XP bonus")
	eq(Balance.in_accept_band(float(result["world_only_hours"]), inputs), false, "exact-factor world-only hours are outside the 130-170 band")
	eq(absf(float(result["premium_world_hours"]) - float(targets["premium_hours"])) > 1.0, true, "premium world-only hours are reported beside the 120 hour target")
	eq(_has_finding(result, "normal_mix_band", "pass"), true, "the normal-mix clocks are scored")
	eq(_has_finding(result, "mission_minutes", "pass"), true, "mission minutes are the proposed values")
	near(float(result["world_only_slower"]), float(result["world_only_hours"]) / float(result["normal_mix_hours"]), "world-only slowdown is the ratio of the two clocks")
	eq(float(result["world_only_slower"]) + 0.0001 >= float(targets["world_only_slower_min"]), true, "world-only is at least 1.15 times the mix")
	eq(float(result["world_only_slower"]) - 0.0001 <= float(targets["world_only_slower_max"]), true, "world-only is at most 1.2 times the mix")
	var shares: Dictionary = result["xp_shares"]
	eq(float(shares["world"]) <= float(targets["max_source_share"]), true, "world XP share stays at or under half")
	eq(float(shares["dungeon"]) <= float(targets["max_source_share"]), true, "dungeon XP share stays at or under half")
	eq(float(shares["mission"]) <= float(targets["max_source_share"]), true, "mission XP share stays at or under half")
	var got_marks: Dictionary = result["milestone_hours"]
	var want_marks: Dictionary = targets["milestone_hours"]
	for key in want_marks.keys():
		var want := float(want_marks[key])
		var got := float(got_marks[key])
		eq(absf(got - want) / want <= float(targets["milestone_near"]), true, "milestone %s is near the 4.8 hour" % str(key))
	eq(absf(float(result["last_level_hours"]) - float(targets["last_level_hours"])) / float(targets["last_level_hours"]) <= float(targets["milestone_near"]), true, "the last level step is near its hour")
	eq(Premium.is_premium(), true, "offline premium check returns true")
	eq(str(result["text"]).find("Premium target") >= 0, true, "the table prints the premium clock")
	eq(str(inputs["per_point_values"]), "Open", "per-point values stay Open")
	eq(int(inputs["minutes"]["mission_talk"]), 3, "talk is 3 minutes")
	eq(int(inputs["minutes"]["mission_reach"]), 5, "reach is 5 minutes")
	eq(int(inputs["minutes"]["mission_defeat_fights"]) * int(inputs["minutes"]["mission_defeat_per_fight"]), 12, "defeat is 3 minutes times 4 fights")
	eq(int(inputs["minutes"]["mission_clear"]), 20, "clearing a dungeon is 20 minutes")
	eq(str(inputs["profiles"]["dungeon_heavy"]), "Open", "dungeon-heavy mix stays Open")
	eq(inputs["koliseo_sets_off"], true, "sets stay off in Koliseo")
	var ratio := float(result["dungeon_vs_world"])
	eq(ratio >= float(targets["dungeon_vs_world_min"]) and ratio <= float(targets["dungeon_vs_world_max"]), true, "normal star is inside the dungeon XP band")
	eq(float(result["world_only_hours"]) > 0.0, true, "world-only reaches the cap")
	eq(_has_finding(result, "mission_minutes", "open"), false, "mission time is no longer Open")
	eq(_has_finding(result, "per_point_values", "open"), true, "per-point values are reported Open")
	eq(_has_status(result, "outside"), true, "the table records checks the raw numbers miss")
	eq(result["zone_rows"].size(), 15, "fifteen zone bands are in the table")
	eq(str(result["text"]).find("Resist") >= 0, true, "the printed table names Resist")
	eq(str(result["text"]).find("Open") >= 0, true, "the printed table says Open where the spec gives no number")


func _test_caps() -> void:
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	var caps: Dictionary = inputs["caps"]
	var legal := Balance.cap_faults({
		"ap": int(caps["ap"]),
		"mp": int(caps["mp"]),
		"range_bonus": int(caps["range_bonus"]),
		"healing_bonus": float(caps["healing_bonus"]),
	}, inputs)
	eq(legal.is_empty(), true, "the 4.14 caps themselves are legal")
	var over := Balance.cap_faults({
		"ap": int(caps["ap"]) + 1,
		"mp": int(caps["mp"]) + 1,
		"range_bonus": int(caps["range_bonus"]) + 1,
		"healing_bonus": float(caps["healing_bonus"]) + 0.05,
	}, inputs)
	eq(over.has("ap"), true, "AP above the cap is rejected")
	eq(over.has("mp"), true, "MP above the cap is rejected")
	eq(over.has("range"), true, "stacked range is rejected")
	eq(over.has("healing"), true, "healing above the cap is rejected")


func _test_level_gap() -> void:
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	near(Balance.level_gap_factor(20, 20, inputs), 1.0, "same level is full XP")
	near(Balance.level_gap_factor(20, 12, inputs), 0.5, "six to nine below is half XP")
	near(Balance.level_gap_factor(20, 10, inputs), 0.1, "ten below is a tenth")
	near(Balance.level_gap_factor(20, 22, inputs), 1.1, "two above adds ten percent")
	near(Balance.level_gap_factor(20, 30, inputs), 1.25, "the above-level bonus stops at its cap")


func _test_budgets() -> void:
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	eq(Balance.part_budget(1, inputs), 5, "tier 1 budget counts the tier as 1")
	eq(Balance.part_budget(10, inputs), 14, "tier 10 budget is 4 plus the tier")
	eq(Balance.part_budget(20, inputs), 24, "tier 20 uses the same budget rule")


func _test_over_cap_zone() -> void:
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CURVE_PATH))
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	var zones: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ZONE_PATH))
	zones = zones.duplicate(true)
	zones["zones"][0]["level_max"] = int(curve["max_level"]) + 1
	var result: Dictionary = Balance.simulate(curve, inputs, zones)
	eq(result["ok"], false, "a band above the curve cap fails")
	eq(_has_finding(result, "zones", "outside"), true, "the high band is reported")


func _test_unknown_key() -> void:
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CURVE_PATH))
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	inputs = inputs.duplicate(true)
	inputs["bonus"] = 1
	var result: Dictionary = Balance.simulate(curve, inputs, {})
	eq(result["ok"], false, "an unknown balance key fails")


func _test_short_curve() -> void:
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	var cap := 4
	var steps: Array = []
	for level in cap - 1:
		steps.append(100 * (level + 1))
	var curve := {
		"format": "stasium.level_curve",
		"format_version": 1,
		"status": "proposed",
		"max_level": cap,
		"xp_to_next": steps,
	}
	var result: Dictionary = Balance.simulate(curve, inputs, {})
	eq(result["ok"], true, "a shorter curve still runs (%s)" % str(result["errors"]))
	eq(int(result["max_level"]), cap, "the short curve keeps its own cap")
	var world_xp := float(inputs["xp_share_of_step"]["world_fight"])
	var world_min := float(inputs["minutes"]["world_fight"])
	near(float(result["world_only_hours"]), float(cap - 1) * world_min / world_xp / 60.0, "hours follow the short curve's length")
	near(float(result["premium_world_hours"]), float(result["world_only_hours"]) / (1.0 + float(inputs["premium"]["xp_bonus"])), "a curve without pace still applies the premium XP bonus")


func _mix_hours(curve: Dictionary, inputs: Dictionary) -> float:
	var minutes: Dictionary = inputs["minutes"]
	var shares: Dictionary = inputs["xp_share_of_step"]
	var mix: Dictionary = inputs["profiles"]["normal_mix"]
	var defeat := float(minutes["mission_defeat_fights"]) * float(minutes["mission_defeat_per_fight"])
	var each := float(mix["mission"]) / 4.0
	var star := float(inputs["normal_star"])
	var rate := 0.0
	rate += float(mix["world"]) * float(shares["world_fight"]) / float(minutes["world_fight"])
	rate += float(mix["dungeon"]) * float(shares["dungeon_win"]) * star / float(minutes["dungeon_run"])
	rate += each * float(shares["mission_talk"]) / float(minutes["mission_talk"])
	rate += each * float(shares["mission_reach"]) / float(minutes["mission_reach"])
	rate += each * float(shares["mission_defeat"]) / defeat
	rate += each * float(shares["mission_clear_dungeon"]) / float(minutes["mission_clear"])
	var start := 1.0
	var ratio := 1.0
	if curve.has("pace_start") and curve.has("pace_ratio"):
		start = float(curve["pace_start"])
		ratio = float(curve["pace_ratio"])
	var cap := int(curve["max_level"])
	var hours := 0.0
	for level in range(1, cap):
		var pace := start * pow(ratio, float(level - 1))
		hours += 1.0 / (rate * pace) / 60.0
	return hours


func _paced_hours(curve: Dictionary, inputs: Dictionary) -> float:
	var start := float(curve["pace_start"])
	var ratio := float(curve["pace_ratio"])
	var world_xp := float(inputs["xp_share_of_step"]["world_fight"])
	var world_min := float(inputs["minutes"]["world_fight"])
	var cap := int(curve["max_level"])
	var hours := 0.0
	for level in range(1, cap):
		var pace := start * pow(ratio, float(level - 1))
		hours += world_min / (world_xp * pace) / 60.0
	return hours


func _has_finding(result: Dictionary, id: String, status: String) -> bool:
	for finding in result["findings"]:
		if str(finding["id"]) == id and str(finding["status"]) == status:
			return true
	return false


func _has_status(result: Dictionary, status: String) -> bool:
	for finding in result["findings"]:
		if str(finding["status"]) == status:
			return true
	return false


const PHONE_DUNGEON_NAMES: Array[String] = [
	"threshgate",
	"galevault",
	"tidehold",
	"ashmarch",
	"coilgate",
]
const PHONE_SCAN_ROOTS: Array[String] = [
	"res://data",
	"res://backend",
	"res://tests",
	"res://scenes",
]
const PHONE_SCAN_EXT: Array[String] = ["gd", "json", "tscn", "tres", "cfg", "godot"]


func _test_no_phone_dungeon_names() -> void:
	var hits := PackedStringArray()
	for root in PHONE_SCAN_ROOTS:
		_scan_phone_tree(root, hits)
	eq(hits.is_empty(), true, "no phone dungeon names in PC data, code, or tests (%s)" % ", ".join(hits))


func _scan_phone_tree(path: String, hits: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_navigational = false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var child := path.path_join(name)
		if dir.current_is_dir():
			_scan_phone_tree(child, hits)
		else:
			_scan_phone_file(child, hits)
		name = dir.get_next()
	dir.list_dir_end()


func _scan_phone_file(path: String, hits: PackedStringArray) -> void:
	if not PHONE_SCAN_EXT.has(path.get_extension().to_lower()):
		return
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i]
		if _is_phone_denylist_line(line):
			continue
		var lower := line.to_lower()
		for phone in PHONE_DUNGEON_NAMES:
			if lower.find(phone) >= 0:
				hits.append("%s:%d" % [path, i + 1])
				break


func _is_phone_denylist_line(line: String) -> bool:
	var trimmed := line.strip_edges()
	for phone in PHONE_DUNGEON_NAMES:
		if trimmed == "\"%s\"," % phone or trimmed == "\"%s\"" % phone:
			return true
	return false


func near(actual: float, expected: float, msg: String) -> void:
	if absf(actual - expected) > 0.02:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1
