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
	eq(str(result["normal_mix_hours"]), "Open", "normal-mix hours stay Open")
	eq(str(result["premium_mix_hours"]), "Open", "premium normal-mix hours stay Open")
	near(float(curve["pace_start"]), 1.6, "pace_start is the spec factor")
	near(float(curve["pace_ratio"]), 0.9532, "pace_ratio is the spec factor")
	var expect := _paced_hours(curve, inputs)
	near(float(result["world_only_hours"]), expect, "free world-only hours use the pace factor")
	var xp_bonus := float(inputs["premium"]["xp_bonus"])
	near(float(result["premium_world_hours"]), expect / (1.0 + xp_bonus), "premium world-only hours apply the XP bonus")
	var targets: Dictionary = inputs["targets"]
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
	eq(_has_finding(result, "normal_mix_band", "open"), true, "the normal-mix band stays Open while mission minutes are Open")
	eq(Premium.is_premium(), true, "offline premium check returns true")
	eq(str(result["text"]).find("Premium target") >= 0, true, "the table prints the premium clock")
	eq(str(inputs["per_point_values"]), "Open", "per-point values stay Open")
	eq(str(inputs["minutes"]["mission"]), "Open", "mission minutes stay Open")
	eq(str(inputs["profiles"]["dungeon_heavy"]), "Open", "dungeon-heavy mix stays Open")
	eq(inputs["koliseo_sets_off"], true, "sets stay off in Koliseo")
	var ratio := float(result["dungeon_vs_world"])
	eq(ratio >= float(targets["dungeon_vs_world_min"]) and ratio <= float(targets["dungeon_vs_world_max"]), true, "normal star is inside the dungeon XP band")
	eq(float(result["world_only_hours"]) > 0.0, true, "world-only reaches the cap")
	eq(_has_finding(result, "mission_minutes", "open"), true, "mission time is reported Open")
	eq(_has_finding(result, "per_point_values", "open"), true, "per-point values are reported Open")
	eq(_has_status(result, "outside"), true, "the table records checks the raw numbers miss")
	eq(result["zone_rows"].size(), 11, "eleven zone bands are in the table")
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
