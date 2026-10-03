extends SceneTree

## WP6b NPC missions. Story rules from spec 4.7, task shares from 4.8.
## Run: godot --headless --path . -s res://tests/run_pc_missions_tests.gd

const Missions = preload("res://backend/pc_missions.gd")
const Progress = preload("res://backend/pc_progress.gd")
const WORLD := preload("res://scenes/world/crosshaven/crosshaven_world.tscn")

const SCHEMA := "res://data/world/schema/missions.schema.json"
const TEMPLATE_SCHEMA := "res://data/world/schema/task_templates.schema.json"

var _passed := 0
var _failed := 0
var _had_save := false
var _backup := ""


func _initialize() -> void:
	_backup_save()
	_run.call_deferred()


func _run() -> void:
	_test_schema()
	var loaded: Dictionary = Missions.load_default()
	eq(bool(loaded.get("ok", false)), true, "missions load (%s)" % str(loaded.get("errors", [])))
	if not bool(loaded.get("ok", false)):
		_finish()
		return
	var book = loaded["missions"]
	_test_roster(book)
	_test_heart_chain(book)
	_test_save(book)
	_test_chain(book)
	_test_proximity(book)
	_test_sides(book)
	_test_tasks(book)
	_test_rejects()
	_test_source()
	await _test_world(book)
	_finish()


func _finish() -> void:
	_restore_save()
	print("pc missions tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_schema() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	eq(schema["additionalProperties"], false, "mission schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.world_missions", "mission format")
	var templates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATE_SCHEMA))
	eq(templates["additionalProperties"], false, "template schema rejects unknown keys")
	eq(templates["properties"]["format"]["const"], "stasium.world_task_templates", "template format")
	var tracker: Resource = load("res://scenes/world/ui/mission_tracker.tscn")
	var log: Resource = load("res://scenes/world/ui/mission_log.tscn")
	eq(tracker != null, true, "tracker scene loads")
	eq(log != null, true, "log scene loads")


func _test_roster(book) -> void:
	var ids: Array = book.all_ids()
	eq(ids.size(), 53, "33 chain missions plus 20 sides")
	var chains := {}
	for id in ids:
		var row: Dictionary = book.mission(str(id))
		chains[str(row["chain"])] = int(chains.get(str(row["chain"]), 0)) + 1
		var rewards: Dictionary = row["rewards"]
		eq((rewards["items"] as Array).is_empty(), true, "%s has no item reward yet" % str(id))
	eq(int(chains["welcome"]), 11, "one welcome per zone")
	eq(int(chains["scout"]), 11, "one scout per zone")
	eq(int(chains["dungeon"]), 11, "one dungeon mission per zone")
	eq(int(chains["side"]), 20, "one side per extra NPC, not the older count of 18")
	var welcome: Dictionary = book.mission("heart_welcome")
	eq(str(welcome["name"]), "Welcome to Crosshaven", "heart welcome name")
	eq(int(welcome["rewards"]["xp"]), 15, "talk-only XP is 15% of the first step, not the sample 40")
	eq(int(welcome["rewards"]["coins"]), 20, "level 1 coins are the low end of the band")
	eq(str(welcome["giver"]), "crossroads_warden", "the Warden gives the welcome")
	var notes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/missions.json"))["notes"]
	var joined := "\n".join(notes)
	eq(joined.find("18") >= 0 and joined.find("20") >= 0, true, "the note explains 20 sides against the summary of 18")
	var fisher: Dictionary = book.mission("eastmarch_fisher_errand")
	eq(str(fisher["steps"][0]["place"]), "Eastmarch docks", "the Fisher sends you to the docks")
	var guide: Dictionary = book.mission("fen_edge_guide_errand")
	eq(str(guide["steps"][0]["landmark"]).find("door") >= 0, true, "the Fen Guide walks you to the swamp gate")
	var watcher: Dictionary = book.mission("blightwood_last_watcher_errand")
	eq(str(watcher["steps"][0]["zone_id"]), "blightwood_hollow_door", "the Last Watcher sends you to the deepest chunk")


func _test_heart_chain(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	eq(book.status_of("heart_welcome", hero), "available", "welcome is available at level 1")
	eq(book.status_of("towns_welcome", hero), "locked", "towns stay locked at level 1")
	eq(book.status_of("heart_dungeon", hero), "locked", "the dungeon mission is locked before the scout")
	var took: Dictionary = book.accept("heart_welcome", hero)
	eq(bool(took["ok"]), true, "welcome can be accepted")
	eq(book.status_of("heart_welcome", hero), "active", "welcome is active")
	eq(book.mark_for("crossroads_warden", hero), "", "an active welcome is not a new !")
	var first: Array = book.on_talk("crossroads_trader", hero)
	eq(first.has("heart_welcome"), true, "talking to the trader advances the welcome")
	eq(book.status_of("heart_welcome", hero), "active", "one talk does not finish two steps")
	var early: Dictionary = book.turn_in("heart_welcome", hero)
	eq(bool(early["ok"]), false, "turn-in waits until every step is done")
	var second: Array = book.on_talk("granary_door_keeper", hero)
	eq(second.has("heart_welcome"), true, "talking to the door keeper finishes the steps")
	eq(book.status_of("heart_welcome", hero), "ready", "welcome is ready to turn in")
	eq(book.mark_for("crossroads_warden", hero), "?", "the Warden shows ?")
	var quiet = Progress.new()
	quiet.mission_blob = {}
	book.accept("heart_welcome", quiet)
	book.on_talk("crossroads_trader", quiet)
	book.on_talk("granary_door_keeper", quiet)
	var raw: Dictionary = book.turn_in("heart_welcome", quiet)
	eq(bool(raw["ok"]), true, "turn-in pays the stored XP")
	eq(int(raw["xp"]), 15, "the payout is 15 XP")
	eq(quiet.level, 1, "15 XP does not leave level 1 on its own")
	eq(quiet.xp, 15, "the XP is kept")
	hero.add_xp(100 - 15)
	eq(hero.level, 1, "the bar is primed just short of the next level")
	var coins_before := int(hero.coins)
	var turned: Dictionary = book.turn_in("heart_welcome", hero)
	eq(bool(turned["ok"]), true, "primed turn-in succeeds")
	eq((turned["events"] as Array).size(), 1, "turn-in emits one level-up")
	eq(int(turned["events"][0]["level"]), 2, "the level-up event is level 2")
	eq(hero.level, 2, "the hero is level 2")
	eq(int(hero.coins), coins_before + 20, "turn-in pays the coin band once")
	var xp_after := int(hero.xp)
	var again: Dictionary = book.turn_in("heart_welcome", hero)
	eq(bool(again["ok"]), false, "turning in twice does not pay again")
	eq(int(hero.xp), xp_after, "the second turn-in adds no XP")
	eq(hero.level, 2, "the second turn-in adds no level")


func _test_save(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	book.accept("heart_welcome", hero)
	book.on_talk("crossroads_trader", hero)
	eq(hero.save(), true, "mission progress saves")
	var again = Progress.new()
	eq(book.status_of("heart_welcome", again), "active", "save and load keep the active mission")
	eq(book.on_talk("crossroads_trader", again).is_empty(), true, "the trader step stays done")
	eq(book.on_talk("granary_door_keeper", again).has("heart_welcome"), true, "the remaining step is still open")
	var old := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
	old.store_string("{\"level\":1,\"xp\":4}")
	old.close()
	var legacy = Progress.new()
	eq(legacy.level, 1, "an old save still loads")
	eq(legacy.xp, 4, "an old save keeps XP")
	eq(legacy.mission_blob.is_empty(), true, "an old save starts with a clear mission blob")


func _test_chain(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	var ids: Array = book.all_ids()
	var story: Array[String] = []
	for id in ids:
		var row: Dictionary = book.mission(str(id))
		if str(row["kind"]) == "story":
			story.append(str(id))
	hero.level = 5
	eq(book.status_of("towns_welcome", hero), "locked", "towns stay locked until the heart scout is done")
	hero.level = 1
	var index := 0
	while index < story.size():
		var welcome_id := story[index]
		var scout_id := story[index + 1]
		var dungeon_id := story[index + 2]
		index += 3
		var welcome: Dictionary = book.mission(welcome_id)
		hero.level = int(welcome["min_level"])
		if welcome_id == "towns_welcome":
			eq(book.status_of(welcome_id, hero), "available", "towns open once the heart scout is done and the level is met")
		eq(book.status_of(welcome_id, hero), "available", "%s is available in chain order" % welcome_id)
		eq(bool(book.accept(welcome_id, hero)["ok"]), true, "%s accepts" % welcome_id)
		for step in welcome["steps"]:
			book.on_talk(str(step["npc"]), hero)
		eq(book.status_of(welcome_id, hero), "ready", "%s is ready" % welcome_id)
		eq(bool(book.turn_in(welcome_id, hero)["ok"]), true, "%s turns in" % welcome_id)
		var scout: Dictionary = book.mission(scout_id)
		eq(bool(book.accept(scout_id, hero)["ok"]), true, "%s accepts" % scout_id)
		for step in scout["steps"]:
			var step_row: Dictionary = step
			var at: Dictionary = step_row["cell"]
			var cell := Vector2i(int(at["x"]), int(at["y"]))
			if str(step_row.get("landmark", "")) == "":
				var missed: Array = book.on_reach(str(step_row["zone_id"]), cell + Vector2i(1, 0), hero)
				eq(missed.has(scout_id), false, "%s cell step ignores a neighbour" % scout_id)
			book.on_reach(str(step_row["zone_id"]), cell, hero)
		eq(book.status_of(scout_id, hero), "ready", "%s is ready" % scout_id)
		eq(bool(book.turn_in(scout_id, hero)["ok"]), true, "%s turns in" % scout_id)
		hero.level = int(book.mission(dungeon_id)["min_level"])
		eq(book.label_for(dungeon_id, hero), "coming soon", "%s shows coming soon" % dungeon_id)
		var blocked: Dictionary = book.accept(dungeon_id, hero)
		eq(bool(blocked["ok"]), false, "%s cannot be taken" % dungeon_id)
		eq(str(blocked["reason"]), "coming soon", "%s reason is coming soon" % dungeon_id)
		eq(book.on_dungeon_won(str(book.mission(dungeon_id)["steps"][0]["dungeon"]), hero).is_empty(), true, "a win does nothing until the mission can be taken")


func _test_proximity(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 1
	book.accept("heart_welcome", hero)
	book.on_talk("crossroads_trader", hero)
	book.on_talk("granary_door_keeper", hero)
	book.turn_in("heart_welcome", hero)
	book.accept("heart_scout", hero)
	var step: Dictionary = book.mission("heart_scout")["steps"][0]
	var at: Dictionary = step["cell"]
	var cell := Vector2i(int(at["x"]), int(at["y"]))
	var far: Array = book.on_reach(str(step["zone_id"]), cell + Vector2i(2, 0), hero)
	eq(far.has("heart_scout"), false, "two cells away does not reach a landmark")
	var near: Array = book.on_reach(str(step["zone_id"]), cell + Vector2i(1, 0), hero)
	eq(near.has("heart_scout"), true, "next to a landmark completes the reach")


func _test_sides(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 1
	eq(book.status_of("blightwood_last_watcher_errand", hero), "locked", "a high-zone side stays locked")
	var watcher_offer: Array = book.available_for("blightwood_last_watcher", hero)
	eq(watcher_offer.size(), 1, "a locked side still leaves the NPC a task")
	eq(str(watcher_offer[0]["id"]).begins_with("task_offer:"), true, "the level 1 task is the offer, not the side")
	hero.level = 5
	var fisher: Dictionary = book.mission("eastmarch_fisher_errand")
	eq(book.status_of("eastmarch_fisher_errand", hero), "available", "the Fisher opens with the towns")
	eq(bool(book.accept("eastmarch_fisher_errand", hero)["ok"]), true, "the Fisher errand accepts")
	var step: Dictionary = fisher["steps"][0]
	var at: Dictionary = step["cell"]
	var docks := Vector2i(int(at["x"]), int(at["y"]))
	eq(book.on_reach("crosshaven_eastmarch", docks + Vector2i(0, 1), hero).is_empty(), true, "the docks are an exact cell")
	eq(book.on_reach("crosshaven_eastmarch", docks, hero).has("eastmarch_fisher_errand"), true, "standing on the docks finishes the errand")
	_assert_docks_passable(docks)
	_assert_landmarks(book)


func _test_tasks(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 1
	hero.xp = 0
	eq(book.available_for("crossroads_guide", hero)[0]["id"], "crossroads_guide_errand", "the Guide's side comes before a repeatable task")
	book.accept("crossroads_guide_errand", hero)
	book.on_talk("crossroads_trader", hero)
	book.turn_in("crossroads_guide_errand", hero)
	var offer: Array = book.available_for("crossroads_guide", hero)
	eq(str(offer[0]["id"]), "task_offer:crossroads_guide", "a finished side reveals one task")
	var took: Dictionary = book.accept("task_offer:crossroads_guide", hero)
	eq(bool(took["ok"]), true, "the task accepts")
	var task_id := str(took["id"])
	eq(book.available_for("crossroads_guide", hero).is_empty(), true, "one task at a time")
	var preview_zone := ""
	var preview_cell := Vector2i.ZERO
	var tasks: Dictionary = hero.mission_blob["tasks"]
	var stored: Dictionary = tasks["crossroads_guide"]
	preview_zone = str(stored["zone_id"])
	preview_cell = Vector2i(int(stored["x"]), int(stored["y"]))
	eq(book.on_reach(preview_zone, preview_cell + Vector2i(3, 0), hero).is_empty(), true, "the task ignores a far cell")
	var hit: Array = book.on_reach(preview_zone, preview_cell, hero)
	eq(hit.has(task_id), true, "standing on the mark readies the task")
	var paid: Dictionary = book.turn_in(task_id, hero)
	eq(bool(paid["ok"]), true, "the task turns in")
	eq(int(paid["xp"]), 6, "reach task XP is 6% of the first step")
	eq(int(paid["coins"]), 20, "task coins use the hero's band")
	eq(hero.level, 1, "the task XP stays on level 1")
	var xp_after := int(hero.xp)
	var second: Dictionary = book.turn_in(task_id, hero)
	eq(bool(second["ok"]), false, "a task pays XP once")
	eq(int(hero.xp), xp_after, "the second task turn-in adds nothing")
	var again: Dictionary = book.accept("task_offer:crossroads_guide", hero)
	eq(bool(again["ok"]), true, "a new task appears after turn-in")
	eq(str(again["id"]) != task_id, true, "the repeat is a new task")


func _test_rejects() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/missions.json"))
	var templates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/task_templates.json"))
	var cycled: Dictionary = doc.duplicate(true)
	for row in cycled["missions"]:
		var mission: Dictionary = row
		if str(mission["id"]) == "heart_welcome":
			mission["requires"] = ["heart_scout"]
		if str(mission["id"]) == "heart_scout":
			mission["requires"] = ["heart_welcome"]
	var bad: Dictionary = Missions.load_documents(cycled, templates)
	eq(bool(bad["ok"]), false, "a require cycle fails")
	eq(str(bad["errors"]).find("cycle") >= 0, true, "the cycle error is named")
	var missing: Dictionary = doc.duplicate(true)
	for row in missing["missions"]:
		var mission: Dictionary = row
		if str(mission["id"]) == "heart_welcome":
			mission["giver"] = "no_such_npc"
	var unknown: Dictionary = Missions.load_documents(missing, templates)
	eq(bool(unknown["ok"]), false, "an unknown giver fails")


func _test_source() -> void:
	var src := FileAccess.get_file_as_string("res://backend/pc_missions.gd")
	eq(src.find("class_name") < 0, true, "missions have no global class")
	eq(src.find("res://mobile") < 0, true, "missions do not import a mobile script")
	var progress := FileAccess.get_file_as_string("res://backend/pc_progress.gd")
	eq(progress.find(str(5 * 10)) < 0, true, "progress still does not hardcode the phase-1 cap")


func _test_world(book) -> void:
	_wipe_save()
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	eq(w.missions != null, true, "the world loads missions")
	var marked := ""
	for node in w.npcs_root.get_children():
		if str(node.npc_id) == "crossroads_warden":
			marked = str(node.mark)
	eq(marked, "!", "the Warden shows !")
	w._approach_npc(w.npc_book.by_id("crossroads_warden"))
	_drive(w)
	eq(w.dialogue.is_open(), true, "the Warden dialogue opens")
	var accept: Button = w.dialogue.find_child("Accept", true, false)
	eq(accept != null and accept.visible, true, "Accept is on the welcome")
	w.dialogue.press_accept()
	eq(book.status_of("heart_welcome", w.progress), "active", "Accept starts the welcome")
	eq(str(w.tracker._body.text).find("Welcome to Crosshaven") >= 0, true, "the tracker names the welcome")
	w.dialogue.close()
	w._approach_npc(w.npc_book.by_id("crossroads_trader"))
	_drive(w)
	eq(w.dialogue.is_open(), true, "the Trader dialogue opens")
	eq(str(w.dialogue._body.text).find("Warden") >= 0, true, "the Trader answers the welcome")
	w.dialogue.close()
	w._approach_npc(w.npc_book.by_id("granary_door_keeper"))
	_drive(w)
	w.dialogue.close()
	eq(book.status_of("heart_welcome", w.progress), "ready", "the world chain reaches ready")
	var question := ""
	for node in w.npcs_root.get_children():
		if str(node.npc_id) == "crossroads_warden":
			question = str(node.mark)
	eq(question, "?", "the Warden shows ?")
	w._approach_npc(w.npc_book.by_id("crossroads_warden"))
	_drive(w)
	var turn: Button = w.dialogue.find_child("TurnIn", true, false)
	eq(turn != null and turn.visible, true, "Turn in is on the ready welcome")
	w.progress.xp = 100 - 15
	w.dialogue.press_turn_in()
	eq(w.progress.level, 2, "the world turn-in levels up")
	eq(str(w.tracker._reward.text).find("Level 2") >= 0, true, "the reward line shows the level")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_J
	w._unhandled_input(key)
	eq(w.mission_log.is_open(), true, "J opens the mission log")
	eq(str(w.mission_log._body.text).find("Crosshaven Heart") >= 0, true, "the log groups by zone")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	w.dialogue.close()
	w._unhandled_input(esc)
	eq(w.mission_log.is_open(), false, "Esc closes the log")
	w.queue_free()


func _assert_landmarks(book) -> void:
	var cache := {}
	for id in book.all_ids():
		var row: Dictionary = book.mission(str(id))
		for step_value in row["steps"]:
			var step: Dictionary = step_value
			if str(step.get("type", "")) != "reach" or str(step.get("landmark", "")) == "":
				continue
			var chunk := str(step["zone_id"])
			if not cache.has(chunk):
				cache[chunk] = _zone_json(chunk)
			var doc: Dictionary = cache[chunk]
			var at: Dictionary = step["cell"]
			var found := false
			for poi_value in doc["points_of_interest"]:
				var poi: Dictionary = poi_value
				if str(poi.get("kind", "")) != "landmark":
					continue
				if str(poi["id"]) == str(step["landmark"]) and int(poi["x"]) == int(at["x"]) and int(poi["y"]) == int(at["y"]):
					found = true
			eq(found, true, "%s landmark %s matches the chunk" % [str(id), str(step["landmark"])])


func _assert_docks_passable(cell: Vector2i) -> void:
	var doc: Dictionary = _zone_json("crosshaven_eastmarch")
	var parsed: Dictionary = WorldZone.parse(doc)
	eq(bool(parsed["ok"]), true, "Eastmarch still parses")
	if not bool(parsed["ok"]):
		return
	var zone: WorldZone = parsed["zone"]
	eq(zone.passable_at(cell), true, "the Eastmarch docks cell is passable")


func _zone_json(chunk: String) -> Dictionary:
	var path := _find_zone(chunk, "res://data/world")
	eq(path != "", true, "%s zone file exists" % chunk)
	if path == "":
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _find_zone(chunk: String, path: String) -> String:
	var dir := DirAccess.open(path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child := path.path_join(entry)
		if dir.current_is_dir():
			var nested := _find_zone(chunk, child)
			if nested != "":
				return nested
		elif entry == chunk + ".json":
			return child
		entry = dir.get_next()
	return ""


func _drive(w: Node2D) -> void:
	var n := 0
	while w.walker.is_moving() and n < 4000:
		w.walker.advance(0.05)
		n += 1


func _wipe_save() -> void:
	if FileAccess.file_exists(Progress.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.SAVE_PATH))


func _backup_save() -> void:
	var path := ProjectSettings.globalize_path(Progress.SAVE_PATH)
	_had_save = FileAccess.file_exists(Progress.SAVE_PATH)
	if _had_save:
		_backup = FileAccess.get_file_as_string(Progress.SAVE_PATH)
		DirAccess.remove_absolute(path)


func _restore_save() -> void:
	var path := ProjectSettings.globalize_path(Progress.SAVE_PATH)
	if _had_save:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(_backup)
	else:
		_wipe_save()


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s (got %s expected %s)" % [msg, str(actual), str(expected)])
