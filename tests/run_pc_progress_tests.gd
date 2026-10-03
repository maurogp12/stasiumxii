extends SceneTree

## PC level curve, the level counter, and spec 4.11 points.
## The cap is max_level in the curve file. Points come from level_rewards.json.
## Run: godot --headless --path . -s res://tests/run_pc_progress_tests.gd

const Progress = preload("res://backend/pc_progress.gd")
const CURVE_PATH := "res://data/world/level_curve.json"
const REWARDS_PATH := "res://data/world/level_rewards.json"
const SCHEMA_PATH := "res://data/world/schema/level_curve.schema.json"
const REWARDS_SCHEMA_PATH := "res://data/world/schema/level_rewards.schema.json"

var _failed: int = 0
var _passed: int = 0
var _had_save := false
var _backup := ""


func _initialize() -> void:
	_backup_save()
	_run()
	_restore_save()
	print("pc progress tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	_clear_save()
	_test_schema_file()
	_test_source_has_no_frozen_cap()
	_test_curve_numbers()
	_exercise({})
	_test_rewards()
	_test_points()
	_test_respec_and_ap()
	_test_duel()
	_test_window()
	_test_higher_cap()
	_test_rejects()


func _test_schema_file() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	eq(schema["additionalProperties"], false, "schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.level_curve", "schema format")
	eq(schema["properties"]["max_level"].has("const"), false, "schema does not freeze the cap")
	eq(int(schema["properties"]["max_level"]["minimum"]), 2, "schema cap is at least 2")
	eq(schema["properties"]["xp_to_next"].has("maxItems"), false, "schema does not freeze the step count")


func _test_source_has_no_frozen_cap() -> void:
	var src := FileAccess.get_file_as_string("res://backend/pc_progress.gd")
	var frozen := str(5 * 10)
	eq(src.find("class_name") < 0, true, "no global class declaration")
	eq(src.find("stasis_catalog") < 0, true, "does not import phone stasis catalog")
	eq(src.find("res://mobile") < 0, true, "does not import a mobile script")
	eq(src.find(frozen) < 0, true, "code does not hardcode the phase-1 cap")
	var schema_src := FileAccess.get_file_as_string(SCHEMA_PATH)
	eq(schema_src.find(frozen) < 0, true, "schema does not hardcode the phase-1 cap")


func _test_curve_numbers() -> void:
	var loaded: Dictionary = Progress.load_curve()
	eq(loaded["ok"], true, "curve loads (%s)" % str(loaded["errors"]))
	if not bool(loaded["ok"]):
		return
	var steps: Array = loaded["xp_to_next"]
	var cap := int(loaded["max_level"])
	eq(steps.size(), cap - 1, "one step for each level below the cap")
	var prev := 0
	var total := 0
	for i in steps.size():
		var got := int(steps[i])
		var want := _formula(i + 1)
		eq(got, want, "xp to leave level %d" % (i + 1))
		eq(got > prev, true, "entry %d increases" % i)
		prev = got
		total += got
	eq(int(steps[0]), 100, "first step is 100")
	eq(int(steps[1]), 300, "second step is 300")
	eq(int(steps[9]), 3980, "tenth step is 3980")
	eq(int(steps[24]), 17250, "twenty-fifth step is 17250")
	eq(int(steps[steps.size() - 1]), 50620, "last shipped step is 50620")
	eq(total, 979430, "shipped curve sums to 979430")


func _test_higher_cap() -> void:
	var cap := 100
	var doc := _curve_of(cap)
	var parsed: Dictionary = Progress.parse_curve(doc)
	eq(parsed["ok"], true, "a higher cap curve parses (%s)" % str(parsed["errors"]))
	eq(int(parsed["max_level"]), cap, "higher cap is kept")
	eq((parsed["xp_to_next"] as Array).size(), cap - 1, "higher cap has one step per level below it")
	var steps: Array = parsed["xp_to_next"]
	var prev := 0
	for i in steps.size():
		var got := int(steps[i])
		eq(got, _formula(i + 1), "higher curve step %d" % (i + 1))
		eq(got > prev, true, "higher curve step %d increases" % i)
		prev = got
	_exercise(doc)


func _exercise(doc: Dictionary) -> void:
	_clear_save()
	var hero = _open(doc)
	var label := "shipped" if doc.is_empty() else "higher cap"
	eq(hero.level, 1, "%s hero starts at level 1" % label)
	eq(hero.xp, 0, "%s hero starts at 0 XP" % label)
	eq(hero.curve_ok, true, "%s curve is valid" % label)
	var first := int(hero.xp_to_next[0])
	var second := int(hero.xp_to_next[1])
	var half := int(first / 2)
	eq(hero.add_xp(0).is_empty(), true, "%s zero XP does not level" % label)
	eq(hero.add_xp(-5).is_empty(), true, "%s negative XP is ignored" % label)
	eq(hero.level, 1, "%s ignored XP leaves the level" % label)
	eq(hero.xp, 0, "%s ignored XP leaves the counter" % label)
	var partial: Array = hero.add_xp(half)
	eq(partial.is_empty(), true, "%s a partial step does not level" % label)
	eq(hero.xp, half, "%s partial XP is kept" % label)
	var once: Array = hero.add_xp(first - half)
	eq(once.size(), 1, "%s the first step emits one level-up" % label)
	eq(str(once[0]["kind"]), "level_up", "%s event kind" % label)
	eq(int(once[0]["level"]), 2, "%s event level is 2" % label)
	eq(once[0].size(), 2, "%s event has no stat fields" % label)
	eq(hero.level, 2, "%s hero is level 2" % label)
	eq(hero.xp, 0, "%s threshold XP is spent" % label)
	_clear_save()
	hero = _open(doc)
	var twice: Array = hero.add_xp(first + second)
	eq(hero.level, 3, "%s two steps reach level 3" % label)
	eq(hero.xp, 0, "%s two steps spend exactly" % label)
	eq(twice.size(), 2, "%s two level-up events" % label)
	eq(int(twice[0]["level"]), 2, "%s first event is level 2" % label)
	eq(int(twice[1]["level"]), 3, "%s second event is level 3" % label)
	_clear_save()
	hero = _open(doc)
	var total := _sum(hero)
	var events: Array = hero.add_xp(total)
	eq(hero.level, hero.max_level, "%s the full curve reaches max_level" % label)
	eq(hero.xp, 0, "%s exact XP lands on 0 past the last step" % label)
	eq(events.size(), hero.xp_to_next.size(), "%s one level-up per step" % label)
	eq(int(events[events.size() - 1]["level"]), hero.max_level, "%s last event is max_level" % label)
	eq(hero.level <= hero.max_level, true, "%s level does not exceed max_level" % label)
	var extra: Array = hero.add_xp(10)
	eq(extra.is_empty(), true, "%s XP past the cap does not level" % label)
	eq(hero.level, hero.max_level, "%s level stays at max_level" % label)
	eq(hero.xp, 10, "%s XP past the cap is kept" % label)
	var more: Array = hero.add_xp(25)
	eq(more.is_empty(), true, "%s further XP still does not level" % label)
	eq(hero.xp, 35, "%s kept XP accumulates" % label)
	_clear_save()
	hero = _open(doc)
	hero.add_xp(first + half)
	eq(hero.level, 2, "%s setup level before save" % label)
	eq(hero.xp, half, "%s setup XP before save" % label)
	eq(hero.save(), true, "%s save writes" % label)
	var again = _open(doc)
	eq(again.level, 2, "%s load restores level" % label)
	eq(again.xp, half, "%s load restores XP" % label)
	again.level = 1
	again.xp = 0
	eq(again.load(), true, "%s load() re-reads the save" % label)
	eq(again.level, 2, "%s load() restores level" % label)
	eq(again.xp, half, "%s load() restores XP" % label)
	var bad := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
	bad.store_string("{\"level\":%d,\"xp\":0}" % (hero.max_level + 1))
	bad.close()
	var ignored = _open(doc)
	eq(ignored.level, 1, "%s a level above max_level is not loaded" % label)
	eq(ignored.xp, 0, "%s a rejected save does not apply XP" % label)
	_clear_save()
	hero = _open(doc)
	hero.add_xp(_sum(hero) + 80)
	eq(hero.level, hero.max_level, "%s saved hero can sit at max_level" % label)
	eq(hero.xp, 80, "%s saved hero keeps XP past the cap" % label)
	eq(hero.save(), true, "%s max_level saves" % label)
	var capped = _open(doc)
	eq(capped.level, hero.max_level, "%s max_level round-trips" % label)
	eq(capped.xp, 80, "%s XP past the cap round-trips" % label)
	eq(capped.points_earned(), capped.points_per_level * (capped.max_level - 1), "%s points follow points_per_level" % label)
	eq(capped.points_free(), capped.points_earned(), "%s an unspent hero keeps every point" % label)
	var expect_ap := 0
	for row in capped.milestones:
		if capped.level >= int(row["level"]):
			expect_ap += int(row["ap"])
	eq(capped.milestone_ap(), expect_ap, "%s milestone AP follows the rewards file" % label)


func _test_rewards() -> void:
	var loaded: Dictionary = Progress.load_rewards()
	eq(loaded["ok"], true, "rewards load (%s)" % str(loaded["errors"]))
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REWARDS_PATH))
	eq(int(doc["points_per_level"]), 2, "two points per level")
	eq(doc["stats"], ["Mastery", "Vitality", "Swift", "Resist"], "four stats, Resist last")
	eq(str(doc["class_hp_per_level"]), "Open", "class HP growth is Open")
	eq(int(doc["respec"]["coin_per_level"]), 100, "respec costs 100 coins times the level")
	eq(int(doc["respec"]["free"]), 1, "one free respec")
	eq(float(doc["stat_per_point"]["Mastery"]["damage_done"]), 0.005, "Mastery is +0.5% damage")
	eq(float(doc["stat_per_point"]["Mastery"]["healing_done"]), 0.005, "Mastery is +0.5% healing")
	eq(float(doc["stat_per_point"]["Vitality"]["max_hp"]), 0.005, "Vitality is +0.5% of base max HP")
	eq(float(doc["stat_per_point"]["Resist"]["damage_taken"]), 0.004, "Resist is +0.4% less damage taken")
	eq(float(doc["stat_per_point"]["Resist"]["cap"]), 0.25, "Resist caps at 25%")
	eq(int(doc["stat_per_point"]["Swift"]["initiative"]), 1, "Swift is +1 Initiative")
	eq(float(doc["koliseo_duel"]["win_min"]), 0.45, "duel band starts at 45 percent")
	eq(float(doc["koliseo_duel"]["win_max"]), 0.55, "duel band ends at 55 percent")
	eq(int(doc["milestones"][0]["level"]), 30, "AP milestone level is data")
	eq(int(doc["milestones"][0]["ap"]), 1, "AP milestone grants 1")
	var text := FileAccess.get_file_as_string(REWARDS_PATH)
	eq(text.find("Ward") < 0, true, "rewards file does not name Ward")
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REWARDS_SCHEMA_PATH))
	eq(schema["additionalProperties"], false, "rewards schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.level_rewards", "rewards schema format")
	var extra := doc.duplicate(true)
	extra["bonus"] = 1
	var rejected: Dictionary = Progress.parse_rewards(extra)
	eq(rejected["ok"], false, "unknown rewards key is rejected")


func _test_points() -> void:
	_clear_save()
	var hero = _open({})
	eq(hero.rewards_ok, true, "shipped rewards are valid")
	eq(hero.points_free(), 0, "level 1 has no free points")
	eq(hero.spend("Resist", 1), false, "level 1 cannot spend")
	eq(hero.spend("Ward", 1), false, "Ward is not a bucket")
	hero.add_xp(int(hero.xp_to_next[0]))
	eq(hero.level, 2, "one step reaches level 2")
	eq(hero.points_earned(), 2, "level 2 has earned two points")
	eq(hero.spend("Resist", 1), true, "Resist takes a point")
	eq(hero.spent_in("Resist"), 1, "Resist records the point")
	eq(hero.points_free(), 1, "one point remains")
	eq(hero.spend("Mastery", 2), false, "cannot spend more than free points")
	eq(hero.spent_in("Mastery"), 0, "a rejected spend does not change Mastery")
	eq(hero.save(), true, "points save")
	var again = _open({})
	eq(again.spent_in("Resist"), 1, "load restores Resist")
	eq(again.points_free(), 1, "load restores free points")
	eq(again.level, 2, "load still restores level")


func _test_respec_and_ap() -> void:
	_clear_save()
	var hero = _open({})
	var grant := 0
	for i in 29:
		grant += int(hero.xp_to_next[i])
	hero.add_xp(grant)
	eq(hero.level, 30, "twenty-nine steps reach the milestone level")
	eq(hero.milestone_ap(), 1, "+1 AP once the data milestone is reached")
	eq(hero.points_earned(), 2 * 29, "points at the milestone level")
	hero.spend("Swift", 4)
	hero.spend("Resist", 4)
	var cleared: Dictionary = hero.respec()
	eq(bool(cleared["ok"]), true, "the free respec runs")
	eq(int(cleared["cost"]), 0, "the free respec costs nothing")
	eq(hero.points_free(), hero.points_earned(), "respec returns every point")
	eq(hero.spent_in("Swift"), 0, "Swift is cleared")
	eq(hero.spent_in("Resist"), 0, "Resist is cleared")
	hero.spend("Vitality", 3)
	var blocked: Dictionary = hero.respec()
	eq(bool(blocked["ok"]), false, "a paid respec without coins does not run")
	eq(int(blocked["cost"]), 100 * hero.level, "the price is 100 times the level")
	eq(hero.spent_in("Vitality"), 3, "the blocked respec leaves the points")
	hero.coins = int(blocked["cost"])
	var paid: Dictionary = hero.respec()
	eq(bool(paid["ok"]), true, "coins pay for the next respec")
	eq(int(paid["cost"]), 100 * 30, "the milestone level pays 100 times 30")
	eq(hero.coins, 0, "the price is spent")
	eq(hero.spent_in("Vitality"), 0, "the paid respec returns the points")
	eq(hero.save(), true, "coins and respecs save")
	var loaded = _open({})
	eq(loaded.respecs_used, hero.respecs_used, "load restores respecs used")
	eq(loaded.coins, 0, "load restores the coin count")
	_clear_save()
	var early = _open({})
	early.add_xp(int(early.xp_to_next[0]))
	eq(early.level, 2, "below the milestone")
	eq(early.milestone_ap(), 0, "no AP flag before the data milestone")
	var custom: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REWARDS_PATH))
	custom["milestones"] = [{"level": 3, "ap": 1}]
	eq(early.bind_rewards(custom), true, "a test can move the milestone")
	eq(early.level, 2, "rebinding rewards keeps the current level")
	eq(early.milestone_ap(), 0, "level 2 is still below the swapped milestone")
	early.add_xp(int(early.xp_to_next[1]))
	eq(early.level, 3, "custom milestone level")
	eq(early.milestone_ap(), 1, "AP flag follows the swapped milestone")


func _test_duel() -> void:
	_clear_save()
	var hero = _open({})
	var table: Dictionary = hero.koliseo_duel_table()
	var budget := hero.points_per_level * (hero.max_level - 1)
	eq(int(table["budget"]), budget, "the duel uses the points earned by the curve cap")
	eq(bool(table["inside"]), true, "every listed pair stays inside 45-55 (worst %s at %s)" % [table["worst_label"], table["worst_win"]])
	var pairs: Array = table["pairs"]
	eq(pairs.size(), 10, "the table is the ten spread-against-spread pairs")
	var labels: Array = []
	for row in pairs:
		var win := float(row["win"])
		labels.append(str(row["label"]))
		eq(win + 0.0000001 >= float(table["win_min"]) and win - 0.0000001 <= float(table["win_max"]), true, "%s stays in the band (%s)" % [str(row["label"]), win])
	eq(labels.has("all Mastery vs all Vitality"), true, "Mastery meets Vitality")
	eq(labels.has("all Mastery vs all Resist"), true, "Mastery meets Resist")
	eq(labels.has("all Vitality vs all Resist"), true, "Vitality meets Resist")
	eq(labels.has("mix vs all Mastery"), true, "the mix meets Mastery")
	eq(labels.has("mix vs all Vitality"), true, "the mix meets Vitality")
	eq(labels.has("mix vs all Resist"), true, "the mix meets Resist")
	eq(labels.has("mix vs all Swift"), true, "the mix meets Swift")
	eq(labels.has("all Swift vs all Mastery"), true, "Swift meets Mastery")
	eq(labels.has("all Swift vs all Vitality"), true, "Swift meets Vitality")
	eq(labels.has("all Swift vs all Resist"), true, "Swift meets Resist")
	var mix: Dictionary = table["mix"]
	eq(int(mix["Mastery"]) + int(mix["Vitality"]), budget, "the mix spends the whole budget")
	eq(int(mix["Mastery"]), int(budget / 2), "the mix puts half its points in Mastery")
	eq(int(mix["Resist"]), 0, "the mix spends nothing on Resist")
	eq(int(mix["Swift"]), 0, "the mix spends nothing on Swift")
	var mirror := float(hero.duel_win_rate(mix, mix))
	eq(absf(mirror - 0.5) < 0.0001, true, "the same spread against itself is even")
	eq(bool(table["resist_flag"]), true, "a full Resist spend wastes points past the cap")
	eq(float(table["resist_wasted"]) > 0.0, true, "wasted Resist points are reported")
	eq(absf(float(table["resist_cap_points"]) - (0.25 / 0.004)) < 0.0001, true, "the cap arrives near 63 points")
	eq(bool(table["resist_weak"]), true, "full Resist is the weaker side and is flagged")
	eq(float(table["resist_best"]) + 0.0000001 >= float(table["win_min"]), true, "the weak Resist side still stays inside the band")


func _test_window() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/world/ui/character_window.gd")
	var world := FileAccess.get_file_as_string("res://scenes/world/crosshaven/crosshaven_world.gd")
	eq(src.find("class_name") < 0, true, "character window has no global class")
	eq(src.find("Ward") < 0, true, "character window does not name Ward")
	eq(src.find("Resist") >= 0, true, "character window names Resist")
	eq(src.find("spend") >= 0, true, "character window spends through progress")
	eq(src.find("respec") >= 0, true, "character window can respec")
	eq(world.find("KEY_C") >= 0, true, "C opens the character window")
	var window = load("res://scenes/world/ui/character_window.tscn").instantiate()
	get_root().add_child(window)
	var hero = _open({})
	hero.add_xp(int(hero.xp_to_next[0]))
	window.setup(hero)
	window.refresh()
	eq(window._body.text.find("Resist") >= 0, true, "the panel lists Resist")
	eq(window._body.text.find("Free points 2") >= 0, true, "the panel shows the free points")
	window._spend("Resist")
	eq(hero.spent_in("Resist"), 1, "the panel's plus button spends a point")
	window.queue_free()


func _test_rejects() -> void:
	var doc := _curve_doc()
	doc["bonus"] = 1
	_rejects(doc, "unknown key bonus")
	var short := _curve_doc()
	(short["xp_to_next"] as Array).pop_back()
	_rejects(short, "one entry for each level below max_level")
	var flat := _curve_doc()
	flat["xp_to_next"][5] = flat["xp_to_next"][4]
	_rejects(flat, "not strictly increasing")
	var cap := _curve_doc()
	cap["max_level"] = int(cap["max_level"]) + 1
	_rejects(cap, "one entry for each level below max_level")
	eq(Progress.parse_curve([])["ok"], false, "an array is not a curve")
	var tiny := _curve_of(3)
	eq(Progress.parse_curve(tiny)["ok"], true, "a short curve is valid when its length matches")


func _open(doc: Dictionary):
	var hero = Progress.new()
	if not doc.is_empty():
		hero.bind_curve(doc)
		hero.read_save()
	return hero


func _sum(hero) -> int:
	var total := 0
	for step in hero.xp_to_next:
		total += int(step)
	return total


func _formula(level: int) -> int:
	return int(round(100.0 * pow(float(level), 1.6) / 10.0)) * 10


func _curve_of(cap: int) -> Dictionary:
	var steps: Array = []
	for level in cap - 1:
		steps.append(_formula(level + 1))
	return {
		"format": "stasium.level_curve",
		"format_version": 1,
		"status": "proposed",
		"max_level": cap,
		"xp_to_next": steps,
	}


func _curve_doc() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CURVE_PATH))
	return (parsed as Dictionary).duplicate(true)


func _rejects(doc: Dictionary, needle: String) -> void:
	var parsed: Dictionary = Progress.parse_curve(doc)
	eq(parsed["ok"], false, "rejects when %s" % needle)
	var hit := false
	for err in parsed["errors"]:
		if str(err).find(needle) >= 0:
			hit = true
	truthy(hit, "error mentions %s (%s)" % [needle, parsed["errors"]])


func _clear_save() -> void:
	if FileAccess.file_exists(Progress.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.SAVE_PATH))


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(Progress.SAVE_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_string(Progress.SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_backup)
	else:
		_clear_save()


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failed += 1
		print("FAIL: %s  (got %s expected %s)" % [msg, actual, expected])
	else:
		_passed += 1


func truthy(value: Variant, msg: String) -> void:
	if not value:
		_failed += 1
		print("FAIL: %s  (got %s)" % [msg, value])
	else:
		_passed += 1
