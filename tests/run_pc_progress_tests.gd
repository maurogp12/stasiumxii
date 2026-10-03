extends SceneTree

## PC level curve to 50 and the level counter. No stat changes (Open Q3).
## Run: godot --headless --path . -s res://tests/run_pc_progress_tests.gd

const Progress = preload("res://backend/pc_progress.gd")
const CURVE_PATH := "res://data/world/level_curve.json"
const SCHEMA_PATH := "res://data/world/schema/level_curve.schema.json"

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
	_test_source_stays_off_phone_code()
	_test_curve_numbers()
	_test_counter()
	_test_cap()
	_test_round_trip()
	_test_rejects()


func _test_schema_file() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	eq(schema["additionalProperties"], false, "schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.level_curve", "schema format")
	eq(schema["properties"]["max_level"]["const"], 50, "schema cap is 50")
	eq(schema["properties"]["xp_to_next"]["minItems"], 49, "schema has 49 steps")


func _test_source_stays_off_phone_code() -> void:
	var src := FileAccess.get_file_as_string("res://backend/pc_progress.gd")
	eq(src.find("class_name") < 0, true, "no global class declaration")
	eq(src.find("stasis_catalog") < 0, true, "does not import phone stasis catalog")
	eq(src.find("res://mobile") < 0, true, "does not import a mobile script")


func _test_curve_numbers() -> void:
	var loaded: Dictionary = Progress.load_curve()
	eq(loaded["ok"], true, "curve loads (%s)" % str(loaded["errors"]))
	if not bool(loaded["ok"]):
		return
	var steps: Array = loaded["xp_to_next"]
	eq(steps.size(), 49, "49 increasing entries")
	eq(int(loaded["max_level"]), 50, "max level is 50")
	var prev := 0
	var total := 0
	for i in steps.size():
		var got := int(steps[i])
		var want := int(round(100.0 * pow(float(i + 1), 1.6) / 10.0)) * 10
		eq(got, want, "xp to leave level %d" % (i + 1))
		eq(got > prev, true, "entry %d increases" % i)
		prev = got
		total += got
	eq(int(steps[0]), 100, "level 1 to 2 is 100")
	eq(int(steps[1]), 300, "level 2 to 3 is 300")
	eq(int(steps[9]), 3980, "level 10 to 11 is 3980")
	eq(int(steps[24]), 17250, "level 25 to 26 is 17250")
	eq(int(steps[48]), 50620, "level 49 to 50 is 50620")
	eq(total, 979430, "total XP to reach 50")


func _test_counter() -> void:
	_clear_save()
	var hero = Progress.new()
	eq(hero.level, 1, "a new hero starts at level 1")
	eq(hero.xp, 0, "a new hero starts at 0 XP")
	eq(hero.curve_ok, true, "the shipped curve is valid")
	var none: Array = hero.add_xp(0)
	eq(none.is_empty(), true, "zero XP does not level")
	eq(hero.add_xp(-5).is_empty(), true, "negative XP is ignored")
	eq(hero.level, 1, "ignored XP leaves the level")
	eq(hero.xp, 0, "ignored XP leaves the counter")
	var partial: Array = hero.add_xp(50)
	eq(partial.is_empty(), true, "50 XP does not level")
	eq(hero.level, 1, "still level 1")
	eq(hero.xp, 50, "50 XP is kept")
	var once: Array = hero.add_xp(50)
	eq(once.size(), 1, "100 XP emits one level-up")
	eq(str(once[0]["kind"]), "level_up", "event kind")
	eq(int(once[0]["level"]), 2, "event level is 2")
	eq(once[0].size(), 2, "event has no stat fields")
	eq(hero.level, 2, "hero is level 2")
	eq(hero.xp, 0, "threshold XP is spent")
	_clear_save()
	hero = Progress.new()
	var twice: Array = hero.add_xp(400)
	eq(hero.level, 3, "400 XP reaches level 3")
	eq(hero.xp, 0, "400 is exactly two steps")
	eq(twice.size(), 2, "two level-up events")
	eq(int(twice[0]["level"]), 2, "first event is level 2")
	eq(int(twice[1]["level"]), 3, "second event is level 3")


func _test_cap() -> void:
	_clear_save()
	var hero = Progress.new()
	var total := 0
	for step in hero.xp_to_next:
		total += int(step)
	var events: Array = hero.add_xp(total)
	eq(hero.level, 50, "the full curve reaches 50")
	eq(hero.xp, 0, "exact XP lands on 0 past the last step")
	eq(events.size(), 49, "49 level-ups from 1 to 50")
	eq(int(events[48]["level"]), 50, "last event is level 50")
	eq(hero.level <= 50, true, "level does not exceed 50")
	var extra: Array = hero.add_xp(10)
	eq(extra.is_empty(), true, "XP past 50 does not level")
	eq(hero.level, 50, "level stays 50")
	eq(hero.xp, 10, "XP past 50 is kept")
	var more: Array = hero.add_xp(25)
	eq(more.is_empty(), true, "further XP still does not level")
	eq(hero.xp, 35, "kept XP accumulates")
	eq(hero.level, 50, "still level 50")


func _test_round_trip() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.add_xp(150)
	eq(hero.level, 2, "setup level before save")
	eq(hero.xp, 50, "setup XP before save")
	eq(hero.save(), true, "save writes")
	var again = Progress.new()
	eq(again.level, 2, "load restores level")
	eq(again.xp, 50, "load restores XP")
	again.level = 1
	again.xp = 0
	eq(again.load(), true, "load() re-reads the save")
	eq(again.level, 2, "load() restores level")
	eq(again.xp, 50, "load() restores XP")
	again.add_xp(10)
	eq(again.save(), true, "save after more XP")
	var third = Progress.new()
	eq(third.level, 2, "second load keeps the level")
	eq(third.xp, 60, "second load keeps the XP")
	_clear_save()
	var fresh = Progress.new()
	eq(fresh.level, 1, "missing save starts at 1")
	eq(fresh.xp, 0, "missing save starts at 0 XP")
	var bad := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
	bad.store_string("{\"level\":51,\"xp\":0}")
	bad.close()
	var ignored = Progress.new()
	eq(ignored.level, 1, "a level above 50 is not loaded")
	eq(ignored.xp, 0, "a rejected save does not apply XP")
	_clear_save()
	hero = Progress.new()
	hero.add_xp(total_xp() + 80)
	eq(hero.level, 50, "saved hero can be level 50")
	eq(hero.xp, 80, "saved hero keeps XP past 50")
	eq(hero.save(), true, "level 50 saves")
	var capped = Progress.new()
	eq(capped.level, 50, "level 50 round-trips")
	eq(capped.xp, 80, "XP past 50 round-trips")


func _test_rejects() -> void:
	var doc := _curve_doc()
	doc["bonus"] = 1
	_rejects(doc, "unknown key bonus")
	var short := _curve_doc()
	(short["xp_to_next"] as Array).pop_back()
	_rejects(short, "must have 49 entries")
	var flat := _curve_doc()
	flat["xp_to_next"][5] = flat["xp_to_next"][4]
	_rejects(flat, "not strictly increasing")
	var cap := _curve_doc()
	cap["max_level"] = 30
	_rejects(cap, "max_level must be 50")
	eq(Progress.parse_curve([])["ok"], false, "an array is not a curve")


func total_xp() -> int:
	var total := 0
	for step in Progress.load_curve()["xp_to_next"]:
		total += int(step)
	return total


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
