extends SceneTree

## WP6b NPC missions. Story rules from spec 4.7, task shares from 4.8.
## Run: godot --headless --path . -s res://tests/run_pc_missions_tests.gd

const Missions = preload("res://backend/pc_missions.gd")
const Progress = preload("res://backend/pc_progress.gd")
const Maps = preload("res://backend/world_map.gd")
const Walk = preload("res://backend/world_walk.gd")
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
	_test_anti_farm(book)
	_test_scout_order(book)
	_test_pending(book)
	_test_migration(book)
	_test_cap_task(book)
	_test_ready_level(book)
	_test_story_pending(book)
	_test_walk_distance(book)
	_test_tracker(book)
	_test_task_mix(book)
	_test_rejects()
	_test_source()
	await _test_world(book)
	_test_full_bag_turn_in()
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
	eq(ids.size(), 47, "17 chain missions plus 30 sides")
	var chains := {}
	for id in ids:
		var row: Dictionary = book.mission(str(id))
		chains[str(row["chain"])] = int(chains.get(str(row["chain"]), 0)) + 1
		var rewards: Dictionary = row["rewards"]
		eq((rewards["items"] as Array).is_empty(), true, "%s has no item reward yet" % str(id))
	eq(int(chains["welcome"]), 6, "one welcome per section 00 zone")
	eq(int(chains["scout"]), 6, "one scout per section 00 zone")
	eq(int(chains["dungeon"]), 5, "one dungeon mission per town, and none at the Crossroads")
	eq(int(chains["side"]), 30, "one side per extra NPC, not the older count of 18")
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
	var east: Dictionary = book.mission("eastmarch_welcome")
	eq(str(east["steps"]).find("eastmarch_elder") < 0, true, "Eastmarch welcome does not talk to the giver again")
	var west: Dictionary = book.mission("westwatch_welcome")
	eq(str(west["steps"]).find("southbridge_elder") < 0, true, "Westwatch welcome stays out of Southbridge")
	eq(str(west["steps"][0]["npc"]), "westwatch_warden", "Westwatch welcome starts with the Warden")
	eq(str(west["steps"][1]["npc"]), "westwatch_trader", "Westwatch welcome meets the Trader")
	eq(str(west["steps"][2]["npc"]), "westwatch_door_keeper", "Westwatch welcome ends with the Door Keeper")
	var south: Dictionary = book.mission("southbridge_welcome")
	var south_steps: Array = south["steps"]
	eq(str(south["giver"]), "southbridge_elder", "the Southbridge Elder gives the welcome")
	eq(str(south_steps[south_steps.size() - 1]["npc"]), "drowned_abbey_door_keeper", "the Door Keeper is last in Southbridge")
	var banned: Array[String] = [
		"rotting_orchard_barrow", "cinderforge_depths", "sunken_mill", "thunderwell_core", "shard_hollow",
	]
	var home_zones: Array[String] = ["crossroads", "stoneford", "northgate", "eastmarch", "southbridge", "westwatch"]
	for id in ids:
		var story: Dictionary = book.mission(str(id))
		if str(story["kind"]) != "story":
			continue
		eq(home_zones.has(str(story["level_zone"])), true, "%s stays on section 00" % str(id))
		for step_value in story["steps"]:
			var story_step: Dictionary = step_value
			eq(banned.has(str(story_step.get("dungeon", ""))), false, "%s does not use an outer dungeon" % str(id))


func _test_heart_chain(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	eq(book.status_of("heart_welcome", hero), "available", "welcome is available at level 1")
	eq(book.status_of("stoneford_welcome", hero), "locked", "Stoneford stays locked at level 1")
	eq(book.status_of("stoneford_dungeon", hero), "locked", "a town dungeon stays locked before its scout")
	var took: Dictionary = book.accept("heart_welcome", hero)
	eq(bool(took["ok"]), true, "welcome can be accepted")
	eq(book.status_of("heart_welcome", hero), "active", "welcome is active")
	eq(book.mark_for("crossroads_warden", hero), "", "an active welcome is not a new !")
	var first: Array = book.on_talk("crossroads_trader", hero)
	eq(first.has("heart_welcome"), true, "talking to the trader advances the welcome")
	eq(book.status_of("heart_welcome", hero), "active", "one talk does not finish two steps")
	var early: Dictionary = book.turn_in("heart_welcome", hero)
	eq(bool(early["ok"]), false, "turn-in waits until every step is done")
	var second: Array = book.on_talk("crossroads_guide", hero)
	eq(second.has("heart_welcome"), true, "talking to the door keeper finishes the steps")
	eq(book.status_of("heart_welcome", hero), "ready", "welcome is ready to turn in")
	eq(book.mark_for("crossroads_warden", hero), "?", "the Warden shows ?")
	var quiet = Progress.new()
	quiet.mission_blob = {}
	book.accept("heart_welcome", quiet)
	book.on_talk("crossroads_trader", quiet)
	book.on_talk("crossroads_guide", quiet)
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
	eq(int(turned["coins"]), 20, "turn-in reports the coin band")
	hero.grant({"coins": int(turned["coins"]), "items": turned.get("items", [])})
	eq(int(hero.coins), coins_before + 20, "grant pays the coin band once")
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
	eq(book.on_talk("crossroads_guide", again).has("heart_welcome"), true, "the remaining step is still open")
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
	eq(book.status_of("stoneford_welcome", hero), "locked", "Stoneford stays locked until the heart scout is done")
	hero.level = 1
	var played_scouts := 0
	var index := 0
	while index < story.size():
		var welcome_id := story[index]
		var scout_id := story[index + 1]
		index += 2
		var dungeon_id := ""
		if index < story.size() and str(book.mission(story[index])["chain"]) == "dungeon":
			dungeon_id = story[index]
			index += 1
		var welcome: Dictionary = book.mission(welcome_id)
		hero.level = int(welcome["min_level"])
		if welcome_id == "stoneford_welcome":
			eq(book.status_of(welcome_id, hero), "available", "Stoneford opens once the heart scout is done and the level is met")
		eq(book.status_of(welcome_id, hero), "available", "%s is available in chain order" % welcome_id)
		if book.label_for(welcome_id, hero) == "coming soon":
			eq(str(book.accept(welcome_id, hero)["reason"]), "coming soon", "%s stays closed" % welcome_id)
			break
		eq(bool(book.accept(welcome_id, hero)["ok"]), true, "%s accepts" % welcome_id)
		for step in welcome["steps"]:
			var welcome_step: Dictionary = step
			if str(welcome_step.get("type", "")) == "reach":
				var welcome_at: Dictionary = welcome_step["cell"]
				book.on_reach(str(welcome_step["zone_id"]), Vector2i(int(welcome_at["x"]), int(welcome_at["y"])), hero)
			else:
				book.on_talk(str(welcome_step["npc"]), hero)
		eq(book.status_of(welcome_id, hero), "ready", "%s is ready" % welcome_id)
		eq(bool(book.turn_in(welcome_id, hero)["ok"]), true, "%s turns in" % welcome_id)
		if book.label_for(scout_id, hero) == "coming soon":
			eq(str(book.accept(scout_id, hero)["reason"]), "coming soon", "%s waits for a real landmark" % scout_id)
			break
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
		played_scouts += 1
		if dungeon_id != "":
			hero.level = int(book.mission(dungeon_id)["min_level"])
			var dungeon_key := str(book.mission(dungeon_id)["steps"][0]["dungeon"])
			if dungeon_key == "old_granary_cellar":
				# Built (dungeons.json): the cellar mission is live and a win credits it.
				eq(book.label_for(dungeon_id, hero) != "coming soon", true, "%s is live now its dungeon is built" % dungeon_id)
				eq(bool(book.accept(dungeon_id, hero)["ok"]), true, "%s can be taken" % dungeon_id)
				eq(book.on_dungeon_won(dungeon_key, hero).has(dungeon_id), true, "a cellar win credits %s" % dungeon_id)
				eq(book.status_of(dungeon_id, hero), "ready", "%s is ready after the win" % dungeon_id)
				eq(bool(book.turn_in(dungeon_id, hero)["ok"]), true, "%s turns in" % dungeon_id)
				continue
			eq(book.label_for(dungeon_id, hero), "coming soon", "%s shows coming soon" % dungeon_id)
			var blocked: Dictionary = book.accept(dungeon_id, hero)
			eq(bool(blocked["ok"]), false, "%s cannot be taken" % dungeon_id)
			eq(str(blocked["reason"]), "coming soon", "%s reason is coming soon" % dungeon_id)
			eq(book.on_dungeon_won(dungeon_key, hero).is_empty(), true, "a win does nothing until the mission can be taken")
	eq(played_scouts >= 2, true, "heart and towns scouts are on real ground")
	eq(book.label_for("northgate_scout", hero) != "coming soon", true, "the Northgate scout is not a coming-soon landmark")
	var north: Dictionary = book.mission("northgate_scout")["steps"][0]
	eq(str(north["zone_id"]).begins_with("crosshaven_"), true, "the Northgate scout walks Crosshaven")
	eq(bool(north.get("pending_chunk", false)), false, "the Northgate scout mark is real ground")


func _test_proximity(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 1
	book.accept("heart_welcome", hero)
	book.on_talk("crossroads_trader", hero)
	book.on_talk("crossroads_guide", hero)
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
	eq(watcher_offer.is_empty(), true, "an outer giver offers nothing while regions are closed")
	hero.level = 20
	var fisher: Dictionary = book.mission("eastmarch_fisher_errand")
	eq(book.status_of("eastmarch_fisher_errand", hero), "available", "the Fisher opens with Eastmarch")
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
	var logged := false
	for section_value in book.log_sections(hero):
		var section: Dictionary = section_value
		for row_value in section["rows"]:
			var log_row: Dictionary = row_value
			if str(log_row["name"]) == str(stored["name"]) and str(log_row["status"]) == "ready":
				logged = true
	eq(logged, true, "the J log lists the task")
	var paid: Dictionary = book.turn_in(task_id, hero)
	eq(bool(paid["ok"]), true, "the task turns in")
	var expect := _reach_payout(1)
	eq(int(paid["xp"]), int(expect["xp"]), "reach task XP is 6% of the step times pace")
	eq(int(paid["coins"]), int(expect["coins"]), "task coins are the world-fight rate times minutes over 3")
	eq(int(paid["xp"]) != 6, true, "pace changes the flat 6% payout")
	eq(hero.level, 1, "the task XP stays on level 1")
	var xp_after := int(hero.xp)
	var second: Dictionary = book.turn_in(task_id, hero)
	eq(bool(second["ok"]), false, "a task pays XP once")
	eq(int(hero.xp), xp_after, "the second task turn-in adds nothing")
	var again: Dictionary = book.accept("task_offer:crossroads_guide", hero)
	eq(bool(again["ok"]), true, "a new task appears after turn-in")
	eq(str(again["id"]) != task_id, true, "the repeat is a new task")


func _test_anti_farm(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 1
	eq(book.available_for("granary_door_keeper", hero).is_empty(), true, "a door keeper does not give a task")
	eq(book.available_for("crossroads_banker", hero)[0]["id"], "crossroads_banker_errand", "the Banker's side comes first")
	_finish_reach(book, hero, "crossroads_herald_errand")
	eq(book.available_for("crossroads_herald", hero).is_empty(), true, "the Herald does not give a task")
	_finish_reach(book, hero, "crossroads_banker_errand")
	eq(book.available_for("crossroads_banker", hero).is_empty(), true, "the Banker does not give a task")
	var pool := _heart_marks()
	var occupied: Dictionary = pool[( _hash_id("crossroads_trader") + 1) % pool.size()]
	hero.mission_blob["tasks"] = {
		"eastmarch_fisher": _seed_task("eastmarch_fisher", occupied),
	}
	var took: Dictionary = book.accept("task_offer:crossroads_trader", hero)
	eq(bool(took["ok"]), true, "the Trader still has a task when one landmark is taken")
	var given: Dictionary = hero.mission_blob["tasks"]["crossroads_trader"]
	eq(str(given["landmark"]) != str(occupied["landmark"]), true, "no two active tasks share a landmark")
	_wipe_save()
	hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 1
	var givers: Array[String] = ["crossroads_trader", "towns_trader"]
	var seen := {}
	for npc_id in givers:
		var offer: Array = book.available_for(npc_id, hero)
		eq(str(offer[0]["id"]).begins_with("task_offer:"), true, "%s offers a task" % npc_id)
		var accepted: Dictionary = book.accept(str(offer[0]["id"]), hero)
		eq(bool(accepted["ok"]), true, "%s task accepts" % npc_id)
		var stored: Dictionary = hero.mission_blob["tasks"][npc_id]
		seen[str(stored["landmark"])] = true
	eq(seen.size(), 2, "two live tasks use the two Stoneford landmarks")
	eq(book.available_for("eastmarch_fisher", hero).is_empty(), true, "a third giver waits until a Stoneford landmark is free")
	var filler := _seed_task("stoneford_smith", _heart_marks()[0])
	filler["landmark"] = "cap_filler"
	hero.mission_blob["tasks"]["stoneford_smith"] = filler
	eq(book.available_for("towns_warden", hero).is_empty(), true, "a fourth task is refused")
	eq(bool(book.accept("task_offer:towns_warden", hero)["ok"]), false, "accept refuses the fourth task")
	var tasks: Dictionary = hero.mission_blob["tasks"]
	var first: Dictionary = tasks["crossroads_trader"]
	var second: Dictionary = tasks["towns_trader"]
	second["zone_id"] = first["zone_id"]
	second["x"] = first["x"]
	second["y"] = first["y"]
	second["landmark"] = first["landmark"]
	second["proximity"] = first["proximity"]
	tasks["towns_trader"] = second
	var walked: Array = book.on_reach(str(first["zone_id"]), Vector2i(int(first["x"]), int(first["y"])), hero)
	var task_hits := 0
	for id in walked:
		if str(id).begins_with("task_"):
			task_hits += 1
	eq(task_hits, 1, "one walk can't complete more than one task")


func _test_scout_order(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	book.accept("heart_welcome", hero)
	book.on_talk("crossroads_trader", hero)
	book.on_talk("crossroads_guide", hero)
	book.turn_in("heart_welcome", hero)
	book.accept("heart_scout", hero)
	var steps: Array = book.mission("heart_scout")["steps"]
	var last: Dictionary = steps[steps.size() - 1]
	var at: Dictionary = last["cell"]
	var hit: Array = book.on_reach(str(last["zone_id"]), Vector2i(int(at["x"]), int(at["y"])), hero)
	eq(hit.has("heart_scout"), true, "a later scout mark counts before the earlier ones")
	eq(book.status_of("heart_scout", hero), "active", "one mark does not finish the scout")
	var flags: Array = hero.mission_blob["story"]["heart_scout"]["done"]
	eq(bool(flags[flags.size() - 1]), true, "the later scout step is stored")
	eq(bool(flags[0]), false, "the first scout step is still open")


func _test_pending(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 10
	eq(book.label_for("rowanvale_farmer_errand", hero), "coming soon", "a stand-in side shows coming soon")
	eq(str(book.accept("rowanvale_farmer_errand", hero)["reason"]), "coming soon", "a stand-in side cannot be accepted")
	eq(bool(book.mission("heart_scout")["steps"][0].get("pending_chunk", false)), false, "the heart scout mark is real ground")
	eq(bool(book.mission("northgate_scout")["steps"][0].get("pending_chunk", false)), false, "the Northgate scout is not a pending outer landmark")
	var outer_steps := 0
	for id in book.all_ids():
		var story: Dictionary = book.mission(str(id))
		if str(story["kind"]) != "story":
			continue
		var home_zones: Array[String] = ["crossroads", "stoneford", "northgate", "eastmarch", "southbridge", "westwatch"]
		eq(home_zones.has(str(story["level_zone"])), true, "%s level zone is section 00" % str(id))
		if str(story["chain"]) != "scout":
			continue
		for step_value in story["steps"]:
			var step_row: Dictionary = step_value
			eq(str(step_row["zone_id"]).begins_with("crosshaven_"), true, "%s stays in Crosshaven" % str(id))
			eq(bool(step_row.get("pending_chunk", false)), false, "%s is not coming soon" % str(id))
			if not str(step_row["zone_id"]).begins_with("crosshaven_"):
				outer_steps += 1
	eq(outer_steps, 0, "no story scout step keeps an outer chunk")
	var panel: Dictionary = book.panel_for("rowanvale_trader", hero)
	eq(bool(panel["soon"]), false, "an outer landmark stays out of the task pool")
	eq(book.available_for("rowanvale_trader", hero).is_empty(), true, "the stand-in task is not offered")


func _test_migration(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	var bare := {"story": {}}
	hero.mission_blob = bare
	eq(book.reconcile(hero).is_empty(), true, "a save without tasks needs no migration")
	var north: Dictionary = _heart_marks()[0]
	hero.mission_blob = {
		"tasks": {
			"crossroads_trader": {
				"id": "task_crossroads_trader_1",
				"serial": 1,
				"status": "active",
				"name": "Reach North Road",
				"landmark": str(north["landmark"]),
				"zone_id": str(north["zone_id"]),
				"level_zone": "crosshaven_heart",
				"x": 1,
				"y": 1,
				"proximity": "landmark",
			},
		},
	}
	var moved: Array = book.reconcile(hero)
	var task: Dictionary = hero.mission_blob["tasks"]["crossroads_trader"]
	eq(int(task["x"]), int(north["x"]), "a moved landmark updates the saved cell")
	eq(int(task["y"]), int(north["y"]), "a moved landmark updates the saved row")
	eq(int(task["xp_percent"]), 6, "an old task learns xp_percent")
	eq(float(task["minutes"]), 5.0, "an old task learns its minutes")
	eq(str(moved).find("moved") >= 0, true, "the move is logged")
	var pending := _pending_mark()
	var coins := int(hero.coins)
	hero.mission_blob["tasks"]["towns_trader"] = _seed_task("towns_trader", pending)
	var dropped: Array = book.reconcile(hero)
	var closed: Dictionary = hero.mission_blob["tasks"]["towns_trader"]
	eq(str(closed["status"]), "dropped", "a pending landmark drops the saved task")
	eq(int(hero.coins), coins, "the drop refunds 0")
	eq(str(dropped).find("refund 0") >= 0, true, "the drop is logged")
	hero.mission_blob["tasks"]["eastmarch_fisher"] = {
		"id": "task_eastmarch_fisher_1",
		"serial": 1,
		"status": "active",
		"name": "Gone",
		"landmark": "no_such_mark",
		"zone_id": "crosshaven_road_north",
		"level_zone": "crosshaven_heart",
		"x": 1,
		"y": 1,
		"proximity": "landmark",
		"xp_percent": 6,
		"minutes": 5,
	}
	var gone: Array = book.reconcile(hero)
	eq(str(hero.mission_blob["tasks"]["eastmarch_fisher"]["status"]), "dropped", "a missing landmark drops the saved task")
	eq(str(gone).find("landmark gone") >= 0, true, "the missing landmark is logged")
	eq(int(hero.coins), coins, "a missing landmark refunds 0")


func _test_cap_task(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.level = hero.max_level
	hero.xp = 3
	var task := _seed_task("crossroads_trader", _heart_marks()[0])
	task["status"] = "ready"
	hero.mission_blob = {"tasks": {"crossroads_trader": task}}
	book.reconcile(hero)
	var paid: Dictionary = book.turn_in(str(task["id"]), hero)
	var expect := _reach_payout(hero.max_level)
	eq(bool(paid["ok"]), true, "the cap task turns in")
	eq(int(paid["xp"]), 0, "at the cap a task pays no XP")
	eq(int(paid["coins"]), int(expect["coins"]), "at the cap a task still pays the fight-rate coins")
	eq(int(hero.xp), 3, "the cap task does not add XP")


func _test_tracker(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 40
	var ids: Array[String] = [
		"crossroads_guide_errand", "crossroads_herald_errand", "crossroads_banker_errand",
		"northgate_elder_errand", "stoneford_elder_errand", "eastmarch_elder_errand",
	]
	for mission_id in ids:
		eq(bool(book.accept(mission_id, hero)["ok"]), true, "%s is active for the tracker" % mission_id)
	var tracker = load("res://scenes/world/ui/mission_tracker.gd").new()
	root.add_child(tracker)
	tracker.setup(book, hero)
	eq(str(tracker._body.text).find("+1 more · J") >= 0, true, "the tracker caps at 5 rows")
	eq(str(tracker._body.text).find("Eastmarch square") < 0, true, "the sixth row is the more line")
	tracker.show_reward({"ok": true, "xp": 15, "coins": 20, "events": []}, false)
	eq(str(tracker._body.text).find("+15 XP") >= 0, true, "the toast replaces the rows")
	tracker.restore_rows()
	eq(str(tracker._body.text).find("+1 more · J") >= 0, true, "the rows return after the toast")
	eq(tracker._reward_card.visible, false, "the toast is gone")
	tracker.queue_free()


func _test_ready_level(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 1
	hero.xp = 0
	var took: Dictionary = book.accept("task_offer:crossroads_trader", hero)
	eq(bool(took["ok"]), true, "the trader task accepts at level 1")
	var stored: Dictionary = hero.mission_blob["tasks"]["crossroads_trader"]
	var cell := Vector2i(int(stored["x"]), int(stored["y"]))
	book.on_reach(str(stored["zone_id"]), cell, hero)
	stored = hero.mission_blob["tasks"]["crossroads_trader"]
	eq(int(stored["ready_level"]), 1, "ready stores the level when the mark is reached")
	hero.level = 10
	var paid: Dictionary = book.turn_in(str(took["id"]), hero)
	var expect := _reach_payout(1)
	var later := _reach_payout(10)
	eq(bool(paid["ok"]), true, "the ready task turns in after a level-up")
	eq(int(paid["xp"]), int(expect["xp"]), "task XP uses the ready level")
	eq(int(paid["coins"]), int(expect["coins"]), "task coins use the ready level")
	eq(int(paid["xp"]) != int(later["xp"]), true, "holding a ready task does not pay the later level")


func _test_story_pending(book) -> void:
	_wipe_save()
	var hero = Progress.new()
	hero.mission_blob = {}
	book.accept("heart_welcome", hero)
	book.on_talk("crossroads_trader", hero)
	book.on_talk("crossroads_guide", hero)
	book.turn_in("heart_welcome", hero)
	eq(bool(book.accept("heart_scout", hero)["ok"]), true, "the heart scout accepts")
	var coins := int(hero.coins)
	var flipped := false
	for row_value in book._reach:
		var row: Dictionary = row_value
		if str(row.get("landmark", "")) == "stone_ford":
			row["pending_chunk"] = true
			flipped = true
	eq(flipped, true, "the scout landmark can be marked pending")
	var dropped: Array = book.reconcile(hero)
	var state: Dictionary = hero.mission_blob["story"]["heart_scout"]
	eq(str(state["status"]), "dropped", "a pending landmark drops the story mission")
	eq(int(hero.coins), coins, "the story drop refunds 0")
	eq(str(dropped).find("landmark pending") >= 0 and str(dropped).find("refund 0") >= 0, true, "the story drop is logged")
	for row_value in book._reach:
		var row: Dictionary = row_value
		if str(row.get("landmark", "")) == "stone_ford":
			row["pending_chunk"] = false


func _test_walk_distance(book) -> void:
	var map_doc: Dictionary = Maps.load_default()
	eq(bool(map_doc.get("ok", false)), true, "the walk map loads")
	var map = map_doc["map"]
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/npcs.json"))
	var denied := {"door_keeper": true, "banker": true, "herald": true}
	var levels: Array[int] = [1, 4, 6, 9, 10, 15, 25, 40]
	for row_value in npcs["npcs"]:
		var npc: Dictionary = row_value
		var npc_id := str(npc["id"])
		if denied.has(str(npc["role"])):
			continue
		var at: Dictionary = npc["cell"]
		var from_zone := str(npc["zone_id"])
		var from_cell := Vector2i(int(at["x"]), int(at["y"]))
		if not map.zones.has(from_zone):
			for level in levels:
				var closed = Progress.new()
				closed.mission_blob = {}
				closed.level = level
				_finish_open_stories(book, closed, npc_id)
				eq(book.available_for(npc_id, closed).is_empty(), true, "%s offers nothing at level %d while regions are closed" % [npc_id, level])
			continue
		for level in levels:
			var hero = Progress.new()
			hero.mission_blob = {}
			hero.level = level
			_finish_open_stories(book, hero, npc_id)
			var guard := 0
			while guard < 8:
				guard += 1
				var offers: Array = book.available_for(npc_id, hero)
				if offers.is_empty() or not str(offers[0]["id"]).begins_with("task_offer:"):
					break
				var took: Dictionary = book.accept(str(offers[0]["id"]), hero)
				eq(bool(took["ok"]), true, "%s offers a task at level %d" % [npc_id, level])
				if not bool(took["ok"]):
					break
				var stored: Dictionary = hero.mission_blob["tasks"][npc_id]
				var to_zone := str(stored["zone_id"])
				eq(map.zones.has(to_zone), true, "%s targets a Crosshaven landmark (%s)" % [npc_id, to_zone])
				var band := str(stored.get("level_zone", ""))
				eq(_town_band(level) == band, true, "%s at level %d is the %s band (got %s)" % [npc_id, level, _town_band(level), band])
				var result: Dictionary = Walk.find_path(
					map, from_zone, from_cell, to_zone, Vector2i(int(stored["x"]), int(stored["y"]))
				)
				eq(bool(result.get("ok", false)), true, "%s can walk to %s" % [npc_id, str(stored["landmark"])])
				eq(int(result.get("length", 0)) >= 40, true, "%s to %s is at least 40 walk cells (%s)" % [npc_id, str(stored["landmark"]), str(result.get("length", 0))])
				stored["status"] = "done"
				hero.mission_blob["tasks"][npc_id] = stored
	var band_hero = Progress.new()
	band_hero.mission_blob = {}
	band_hero.level = 1
	var low: Array = book.available_for("crossroads_trader", band_hero)
	eq(str(low[0]["id"]).begins_with("task_offer:"), true, "level 1 is inside the task band")
	band_hero.level = 9
	var mid: Array = book.available_for("crossroads_trader", band_hero)
	eq(str(mid[0]["id"]).begins_with("task_offer:"), true, "level 9 is inside the task band")
	band_hero.level = 10
	var at_ten: Array = book.available_for("crossroads_trader", band_hero)
	eq(str(at_ten[0]["id"]).begins_with("task_offer:"), true, "level 10 is Northgate and still offers a task")
	band_hero.level = 25
	var at_east: Array = book.available_for("crossroads_trader", band_hero)
	eq(str(at_east[0]["id"]).begins_with("task_offer:"), true, "level 25 is Eastmarch and still offers a task")
	band_hero.level = 40
	var at_west: Array = book.available_for("crossroads_trader", band_hero)
	eq(str(at_west[0]["id"]).begins_with("task_offer:"), true, "level 40 is Westwatch and still offers a task")
	band_hero.level = 50
	var at_cap: Array = book.available_for("crossroads_trader", band_hero)
	eq(str(at_cap[0]["id"]).begins_with("task_offer:"), true, "level 50 stays inside Westwatch")


func _finish_open_stories(book, hero, npc_id: String) -> void:
	var guard := 0
	while guard < 12:
		guard += 1
		var offers: Array = book.available_for(npc_id, hero)
		if offers.is_empty() or str(offers[0]["id"]).begins_with("task_offer:"):
			return
		var mission_id := str(offers[0]["id"])
		book.accept(mission_id, hero)
		var story: Dictionary = hero.mission_blob["story"]
		var state: Dictionary = story[mission_id]
		state["status"] = "done"
		story[mission_id] = state
		hero.mission_blob["story"] = story


func _town_band(level: int) -> String:
	if level >= 40:
		return "westwatch"
	if level >= 30:
		return "southbridge"
	if level >= 20:
		return "eastmarch"
	if level >= 10:
		return "northgate"
	return "stoneford"


func _test_task_mix(book) -> void:
	var table := FileAccess.get_file_as_string("res://docs/pc/media/wp6b/task_mix.md")
	eq(table.find("1–50") >= 0, true, "the task mix names the 1-50 offer band")
	eq(table.find("Stoneford") >= 0 and table.find("Northgate") >= 0, true, "the task mix names Stoneford and Northgate")
	eq(table.find("Eastmarch") >= 0 and table.find("Southbridge") >= 0 and table.find("Westwatch") >= 0, true, "the task mix names the southern towns")
	eq(table.find("143.53") < 0, true, "the task mix does not reprint the old free-play hours")
	var hero = Progress.new()
	hero.mission_blob = {}
	hero.level = 9
	var offered: Array = book.available_for("crossroads_trader", hero)
	eq(str(offered[0]["id"]).begins_with("task_offer:"), true, "Stoneford still offers a task")
	hero.level = 10
	eq(str(book.available_for("crossroads_trader", hero)[0]["id"]).begins_with("task_offer:"), true, "Northgate still offers a task")
	hero.level = 50
	eq(str(book.available_for("crossroads_trader", hero)[0]["id"]).begins_with("task_offer:"), true, "Westwatch still offers a task at the top of the band")


func _finish_reach(book, hero, mission_id: String) -> void:
	book.accept(mission_id, hero)
	var step: Dictionary = book.mission(mission_id)["steps"][0]
	var at: Dictionary = step["cell"]
	book.on_reach(str(step["zone_id"]), Vector2i(int(at["x"]), int(at["y"])), hero)
	book.turn_in(mission_id, hero)


func _heart_marks() -> Array:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/missions.json"))
	var pool: Array = []
	for row_value in doc["reach_index"]:
		var row: Dictionary = row_value
		if str(row["zone_id"]).begins_with("crosshaven_") and not bool(row.get("pending_chunk", false)):
			pool.append(row)
	return pool


func _pending_mark() -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/missions.json"))
	for row_value in doc["reach_index"]:
		var row: Dictionary = row_value
		if bool(row.get("pending_chunk", false)):
			return row
	return {}


func _seed_task(npc_id: String, mark: Dictionary) -> Dictionary:
	return {
		"id": "task_%s_1" % npc_id,
		"serial": 1,
		"status": "active",
		"name": "Seed",
		"landmark": str(mark["landmark"]),
		"zone_id": str(mark["zone_id"]),
		"level_zone": str(mark["level_zone"]),
		"x": int(mark["x"]),
		"y": int(mark["y"]),
		"proximity": str(mark["proximity"]),
		"xp_percent": 6,
		"minutes": 5,
	}


func _hash_id(text: String) -> int:
	var n := 0
	for i in text.length():
		n = (n * 33 + text.unicode_at(i)) % 100000
	return n


func _reach_payout(level: int) -> Dictionary:
	var curve: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/level_curve.json"))
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/balance_inputs.json"))
	var xp := 0
	if level < int(curve["max_level"]):
		var pace := float(curve["pace_start"]) * pow(float(curve["pace_ratio"]), float(level - 1))
		var need := float(curve["xp_to_next"][level - 1])
		xp = int(round(need * 6.0 / 100.0 * pace))
	var per_fight := float(inputs["coins"]["world_base"]) + float(inputs["coins"]["world_per_level"]) * float(level)
	var minutes := float(inputs["minutes"]["mission_reach"])
	var fight := float(inputs["minutes"]["world_fight"])
	var coins := int(round(per_fight * (minutes / fight)))
	return {"xp": xp, "coins": coins}


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
	eq(src.find("const HALF") >= 0, true, "HALF is a named constant")
	eq(src.find("Not the level cap") >= 0, true, "HALF is commented so it is not the level cap")
	eq(src.find("pace_start") >= 0, true, "task pace is read from the level curve")
	eq(src.find("xp_percent") >= 0, true, "task XP reads xp_percent from the template")
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
	w._approach_npc(w.npc_book.by_id("crossroads_guide"))
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
	eq(w.reward_popup.is_open(), true, "turn-in opens the reward popup")
	eq(str(w.reward_popup._body.text).find("XP +15") >= 0, true, "the popup shows the XP")
	eq(str(w.reward_popup._body.text).find("Crypto Coins +20") >= 0, true, "the popup shows the coins")
	eq(w.progress.coins, 20, "the world turn-in pays the wallet")
	eq(book.status_of("heart_welcome", w.progress), "done", "the welcome is done")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_J
	w._unhandled_input(key)
	eq(w.mission_log.is_open(), true, "J opens the mission log")
	eq(str(w.mission_log._body.text).find("Crossroads") >= 0, true, "the log groups by zone")
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	w.dialogue.close()
	w._unhandled_input(esc)
	eq(w.mission_log.is_open(), false, "Esc closes the log")
	w.queue_free()


func _test_full_bag_turn_in() -> void:
	_wipe_save()
	var w: Node2D = WORLD.instantiate()
	w.instant_transitions = true
	root.add_child(w)
	w.walker.auto_advance = false
	w.weather.auto_rotate = false
	var hero = w.progress
	var missions = w.missions
	eq(missions != null and hero != null, true, "the full-bag world boots")
	if missions == null or hero == null:
		w.queue_free()
		return
	missions.accept("heart_welcome", hero)
	missions.on_talk("crossroads_trader", hero)
	missions.on_talk("crossroads_guide", hero)
	eq(missions.status_of("heart_welcome", hero), "ready", "the welcome is ready with a full bag coming")
	while hero.bag.size() < hero.bag_slots:
		hero.grant({"coins": 0, "items": [{"item_id": "plain_band", "rarity": "regular", "count": 1}]})
	eq(hero.bag.size(), hero.bag_slots, "the bag is full before turn-in")
	var rewards: Dictionary = missions._by_id["heart_welcome"]["rewards"]
	rewards["items"] = [{"item_id": "sackcloth", "rarity": "regular", "count": 1}]
	var coins_before := int(hero.coins)
	var bag_before := int(hero.bag.size())
	w._approach_npc(w.npc_book.by_id("crossroads_warden"))
	_drive(w)
	w.dialogue.press_turn_in()
	eq(missions.status_of("heart_welcome", hero), "done", "a full bag still completes the turn-in")
	eq(int(hero.coins), coins_before + 20, "the coins still land when the bag is full")
	eq(hero.bag.size(), bag_before, "the full bag does not grow")
	var banked := false
	for entry in hero.bank:
		if str(entry.get("item_id", "")) == "sackcloth":
			banked = true
	eq(banked, true, "the part overflows to the bank")
	eq(hero.bag.size() + hero.bank.size(), bag_before + 1, "the part is not lost")
	eq(w.reward_popup.is_open(), true, "the full bag still opens the popup")
	eq(str(w.reward_popup._body.text).find("Sackcloth") >= 0, true, "the popup names the overflow part")
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
