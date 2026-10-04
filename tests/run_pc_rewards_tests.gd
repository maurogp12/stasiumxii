extends SceneTree

## WP14 Crypto Coins, set parts and Mystery Boxes.
## Run: godot --headless --path . -s res://tests/run_pc_rewards_tests.gd

const Rewards = preload("res://backend/pc_rewards.gd")
const Progress = preload("res://backend/pc_progress.gd")
const PATH := "res://data/world/rewards.json"
const SCHEMA := "res://data/world/schema/rewards.schema.json"

var _passed := 0
var _failed := 0
var _had_save := false
var _backup := ""


func _initialize() -> void:
	_backup_save()
	_clear_save()
	_run.call_deferred()


func _run() -> void:
	_test_schema()
	var loaded: Dictionary = Rewards.load_default()
	eq(bool(loaded.get("ok", false)), true, "rewards load (%s)" % str(loaded.get("errors", [])))
	if not bool(loaded.get("ok", false)):
		return
	var book = loaded["rewards"]
	_test_catalog(book)
	_test_tables()
	_test_rolls(book)
	_test_box(book)
	_test_bias(book)
	_test_gear()
	_test_save()
	_test_window()
	_test_load_safety()
	_test_bank_ring_destroy()
	_test_caps()
	_test_mender_sets(book)
	_test_turn_in()
	_test_carry_limits()
	_test_sources()
	_restore_save()
	print("pc rewards tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_schema() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	eq(schema["additionalProperties"], false, "schema rejects unknown keys")
	eq(schema["properties"]["format"]["const"], "stasium.world_rewards", "schema format")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	doc["bonus"] = 1
	var rejected: Dictionary = Rewards.load_document(doc)
	eq(bool(rejected.get("ok", false)), false, "unknown key is rejected")


func _test_catalog(book) -> void:
	var rows: Array = book.sets()
	eq(rows.size(), 43, "43 sets")
	var class_n := 0
	var dungeon_n := 0
	var shared_n := 0
	var parts := 0
	var budgets := {}
	for row in rows:
		var set_def: Dictionary = row
		var kind := str(set_def["kind"])
		if kind == "class":
			class_n += 1
		elif kind == "dungeon":
			dungeon_n += 1
		elif kind == "shared":
			shared_n += 1
		parts += (set_def["parts"] as Array).size()
		var tier := int(set_def["tier"])
		var budget := int(set_def["budget"])
		var full := int(set_def["full_budget"])
		eq(full, _full_budget(tier), "%s full set is B(T)" % str(set_def["id"]))
		var total := _set_total(set_def)
		eq(absi(total - full) <= 1, true, "%s total stays within 1 of B(T)" % str(set_def["id"]))
		if budgets.has(tier):
			eq(int(budgets[tier]), full, "tier %d shares one full budget" % tier)
		else:
			budgets[tier] = full
		var regular: Dictionary = set_def["stats"]["regular"]
		var rare: Dictionary = set_def["stats"]["rare"]
		eq(_sum(regular), budget, "%s regular points" % str(set_def["id"]))
		eq(_sum(rare), int(round(1.5 * float(budget))) + 1, "%s rare points" % str(set_def["id"]))
		eq(bool(set_def["bonuses"]["5"]["applies"]), false, "%s five-part effect is not applied" % str(set_def["id"]))
	eq(class_n, 30, "30 class sets")
	eq(dungeon_n, 11, "11 dungeon sets")
	eq(shared_n, 2, "Wayfarer and Townguard")
	eq(parts, 215, "five parts on every set")
	var gloam: Dictionary = book.set_by_id("gloam_umbral_fang")
	eq(gloam["leans"], ["Swift", "Resist"], "Gloam from tier 30 leans Swift and Resist")
	var sky: Dictionary = book.set_by_id("kestrel_skyfeather")
	eq(str(sky["bonuses"]["5"]["text"]).find("Mark Shot") >= 0, true, "Kestrel's tier-20 signature is stored")
	var mill: Dictionary = book.set_by_id("millwright")
	eq(str(mill["bonuses"]["5"]["text"]).find("Mastery") >= 0, true, "Millwright keeps its approved line")
	var dungeons: Array = book.dungeons()
	for tier in budgets.keys():
		var higher := int(tier) + 10
		if not budgets.has(higher):
			continue
		var ratio := float(budgets[higher]) / float(budgets[tier]) - 1.0
		eq(ratio >= 0.25 and ratio <= 0.35, true, "tier %s to %s steps 25 to 35 percent" % [str(tier), str(higher)])
	eq(dungeons.size(), 10, "ten dungeon tables after Millrace is dropped")
	var seen := {}
	var millrace := false
	var granary: Dictionary = {}
	for row in dungeons:
		var dungeon: Dictionary = row
		var set_id := str(dungeon["set_id"])
		eq(seen.has(set_id), false, "%s has its own set" % str(dungeon["id"]))
		seen[set_id] = true
		if str(dungeon["id"]) == "millrace_vaults":
			millrace = true
		if str(dungeon["id"]) == "old_granary_cellar":
			granary = dungeon
	eq(millrace, false, "Millrace is not a reward source")
	eq(str(granary.get("also_set_id", "")), "millwright", "the cellar also drops Millwright")
	var granary_extras: Array = granary["extras"]
	eq(granary_extras.has("sackcloth"), true, "the cellar keeps its own extras")
	eq(granary_extras.has("millstone_stew") and granary_extras.has("gear_cog") and granary_extras.has("water_wheel_model"), true, "Millrace extras sit on the cellar")


func _test_tables() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var box := 0.0
	for row in doc["box"]:
		box += float(row["chance"])
	eq(absf(box - 1.0) < 0.001, true, "a Mystery Box table sums to 100%")
	for row in doc["mission_ranks"]:
		var total := float(row["regular"]) + float(row["rare"]) + float(row["box"])
		eq(total <= 1.0 + 0.001, true, "mission rank %s sums to at most 100%%" % str(row["rank"]))
	eq(float(doc["world_part_chance"]) <= 1.0, true, "world part chance is at most 100%")
	for key in doc["dungeon_rare_by_stars"].keys():
		eq(float(doc["dungeon_rare_by_stars"][key]) <= 1.0, true, "rare star %s" % str(key))
	for key in doc["dungeon_box_by_stars"].keys():
		eq(float(doc["dungeon_box_by_stars"][key]) <= 1.0, true, "box star %s" % str(key))
	var split: Dictionary = doc["guaranteed_split"]
	var split_sum := float(split["dungeon_set"]) + float(split["class_set"])
	eq(absf(split_sum - 1.0) < 0.001, true, "the guaranteed part split sums to 100%")
	eq(float(doc["dungeon_rare_by_stars"]["1"]), 0.0, "star 1 has no rare part")
	eq(absf(float(doc["dungeon_rare_by_stars"]["5"]) - 0.35) < 0.001, true, "star 5 rare chance is 35%")
	eq(float(doc["dungeon_box_by_stars"]["3"]), 0.0, "star 3 has no box")
	eq(absf(float(doc["dungeon_box_by_stars"]["4"]) - 0.10) < 0.001, true, "star 4 box chance is 10%")


func _test_rolls(book) -> void:
	var ctx := {"level": 1, "class_id": "Ironjaw", "zone_id": "crosshaven_crossroads"}
	var first: Dictionary = book.roll("world", ctx, _rng(1))
	var again: Dictionary = book.roll("world", ctx, _rng(1))
	eq(int(first["coins"]), int(round(3.0 + 1.5)), "level 1 world coins")
	eq(JSON.stringify(first["items"]), JSON.stringify(again["items"]), "a seeded world roll is fixed")
	var by_zone: Dictionary = book.roll("world", {"level": 1, "class_id": "Ironjaw", "zone_id": "crosshaven_heart"}, _rng(1))
	eq(JSON.stringify(first["items"]), JSON.stringify(by_zone["items"]), "a chunk id uses its level zone")
	var granary: Dictionary = book.roll("dungeon", {
		"dungeon_id": "old_granary_cellar", "stars": 1, "class_id": "Ironjaw", "level": 1,
	}, _rng(2))
	eq(int(granary["coins"]), 8 * int(round(3.0 + 1.5)), "granary star 1 coins")
	eq((granary["items"] as Array).size() >= 1, true, "a dungeon win gives a part")
	var starred: Dictionary = book.roll("dungeon", {
		"dungeon_id": "old_granary_cellar", "stars": 2, "class_id": "Kestrel", "level": 1,
	}, _rng(2))
	eq(int(starred["coins"]), int(granary["coins"]) * 2, "dungeon coins scale with stars")
	var tenth: Dictionary = book.roll("mission", {
		"level": 4, "class_id": "Ironjaw", "zone_id": "crosshaven_heart", "missions_finished": 9,
	}, _rng(4))
	eq((tenth["items"] as Array).size(), 1, "the 10th mission gives one item")
	eq(str(tenth["items"][0]["item_id"]), "mystery_box", "the 10th mission gives a box")
	var ninth: Dictionary = book.roll("mission", {
		"level": 4, "class_id": "Ironjaw", "zone_id": "crosshaven_heart", "missions_finished": 8,
	}, _rng(4))
	var ninth_box := false
	for item in ninth["items"]:
		if str(item["item_id"]) == "mystery_box":
			ninth_box = true
	eq(ninth_box, false, "rank 1 does not give a box")
	eq(int(ninth["coins"]) >= 20 and int(ninth["coins"]) <= 40, true, "tier-1 mission coins stay in band")
	var extras := {"sackcloth": true, "granary_bread": true, "old_grain_barrel": true, "millstone_stew": true, "gear_cog": true, "water_wheel_model": true}
	var saw_rat := false
	var saw_mill := false
	for n in 80:
		var probe: Dictionary = book.roll("dungeon", {
			"dungeon_id": "old_granary_cellar", "stars": 1, "class_id": "Ironjaw", "level": 1,
		}, _rng(400 + n))
		var probe_id := str((probe["items"] as Array)[0]["item_id"])
		if probe_id.begins_with("ratcatcher_"):
			saw_rat = true
		if probe_id.begins_with("millwright_"):
			saw_mill = true
	eq(saw_rat and saw_mill, true, "the cellar drops Ratcatcher and Millwright")
	for n in 40:
		var drop: Dictionary = book.roll("dungeon", {
			"dungeon_id": "old_granary_cellar", "stars": 5, "class_id": "Bastion", "level": 1,
		}, _rng(20 + n))
		for item in drop["items"]:
			eq(extras.has(str(item["item_id"])), false, "an Open extra is not rolled")


func _test_box(book) -> void:
	for n in 80:
		var got: Dictionary = book.open_box({"level": 12, "class_id": "Mender"}, _rng(100 + n))
		var coins := int(got["coins"])
		var items: Array = got["items"]
		var things := (1 if coins > 0 else 0) + items.size()
		eq(things, 1, "a box gives exactly one thing")
		if coins > 0:
			eq(items.is_empty(), true, "a coin box has no part")
		else:
			eq(items.size(), 1, "a part box has one part")
	var again: Dictionary = book.open_box({"level": 12, "class_id": "Mender"}, _rng(7))
	var twice: Dictionary = book.open_box({"level": 12, "class_id": "Mender"}, _rng(7))
	eq(JSON.stringify(again), JSON.stringify(twice), "a seeded box is fixed")


func _test_bias(book) -> void:
	var rng := _rng(99)
	var hits := 0
	var classes: Array = ["Kestrel", "Ironjaw", "Mender", "Gloam", "Bastion"]
	var n := 800
	for _i in n:
		if book.pick_class(rng, "Mender", classes) == "Mender":
			hits += 1
	var rate := float(hits) / float(n)
	eq(rate > 0.5 and rate < 0.7, true, "class parts favour the hero's class (%.3f)" % rate)


func _test_gear() -> void:
	_clear_save()
	var loaded: Dictionary = Rewards.load_default()
	var book = loaded["rewards"]
	var fledgling: Dictionary = book.set_by_id("kestrel_fledgling")
	var hero = Progress.new()
	eq(hero.hero_class, "", "the hero has no class until one is chosen")
	eq(hero.set_hero_class("ironjaw"), true, "a roster id sets the class")
	eq(hero.hero_class, "Ironjaw", "the stored class is the display name")
	var blocked: Dictionary = hero.equip_uid(_give(hero, "kestrel_fledgling_head", "regular"))
	eq(bool(blocked.get("ok", false)), false, "another class's part stays in the bag")
	eq(str(blocked.get("reason", "")), "class", "the reason is the class")
	hero.set_hero_class("kestrel")
	var low: Dictionary = hero.equip_uid(_give(hero, "kestrel_windrunner_head", "regular"))
	eq(str(low.get("reason", "")), "level", "a higher tier cannot be worn yet")
	var slots := ["head", "cape", "belt", "boots", "amulet"]
	var uids: Array = []
	for slot in slots:
		uids.append(_give(hero, "kestrel_fledgling_%s" % slot, "regular"))
	hero.equip_uid(int(uids[0]))
	hero.equip_uid(int(uids[1]))
	var two: Dictionary = hero.gear_view()["stats"]
	eq(two, _expect_stats(fledgling, 2), "two parts include the 2-part bonus")
	hero.equip_uid(int(uids[2]))
	var three: Dictionary = hero.gear_view()["stats"]
	eq(three, _expect_stats(fledgling, 3), "three parts include the 3-part bonus")
	hero.equip_uid(int(uids[3]))
	var four: Dictionary = hero.gear_view()["stats"]
	hero.equip_uid(int(uids[4]))
	var five: Dictionary = hero.gear_view()
	eq(five["stats"], _expect_stats(fledgling, 5), "five parts add no further set bonus")
	eq(_sum(five["stats"]) - _sum(four), _sum(fledgling["stats"]["regular"]), "the fifth part adds only its own stats")
	eq(bool(five["sets"][0]["five_applies"]), false, "the five-part line stays out of the stats")
	eq(hero.spent_in("Mastery"), 0, "gear does not spend characteristic points")
	eq(hero.spent_in("Swift"), 0, "gear does not spend Swift")
	_clear_save()
	var rare = Progress.new()
	rare.set_hero_class("ironjaw")
	rare.level = 30
	var rare_slots := ["head", "cape", "belt", "boots", "amulet"]
	for slot in rare_slots:
		var uid := _give(rare, "ironjaw_ironclad_ram_%s" % slot, "rare")
		var wore: Dictionary = rare.equip_uid(uid)
		eq(bool(wore.get("ok", false)), true, "rare %s equips (%s)" % [slot, str(wore.get("reason", ""))])
	eq(int(rare.sheet_view()["ap"]), 7, "no AP until the Rare set choice")
	var choice: Dictionary = rare.choose_rare("ap")
	eq(bool(choice.get("ok", false)), true, "the first AP or MP choice is free")
	eq(int(rare.sheet_view()["ap"]), 8, "a full Rare tier-30 set adds the chosen AP")
	var switched: Dictionary = rare.choose_rare("mp")
	eq(bool(switched.get("ok", false)), false, "switching the choice does not invent a price")
	eq(str(switched.get("reason", "")), "switch cost is Open", "the switch price stays Open")
	_clear_save()
	var mp_hero = Progress.new()
	mp_hero.set_hero_class("ironjaw")
	mp_hero.level = 30
	for slot in rare_slots:
		mp_hero.equip_uid(_give(mp_hero, "ironjaw_ironclad_ram_%s" % slot, "rare"))
	mp_hero.choose_rare("mp")
	eq(int(mp_hero.sheet_view()["mp"]), 4, "the same set can add MP instead")
	eq(int(mp_hero.sheet_view()["ap"]), 7, "the MP choice does not also add AP")


func _test_save() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.grant({"coins": 40, "items": [{"item_id": "sackcloth", "rarity": "regular", "count": 2}]})
	eq(hero.bag.size(), 1, "a material stacks in one slot")
	eq(int(hero.bag[0]["count"]), 2, "the stack counts both")
	hero.bag_slots = 1
	hero.grant({"coins": 0, "items": [
		{"item_id": "kestrel_fledgling_head", "rarity": "regular", "count": 1},
		{"item_id": "kestrel_fledgling_cape", "rarity": "regular", "count": 1},
	]})
	eq(hero.bag.size(), 1, "a full bag does not take another slot")
	eq(hero.bank.size() >= 1, true, "the overflow goes to the bank")
	eq(hero.save(), true, "coins and items save")
	var loaded = Progress.new()
	eq(loaded.coins, 40, "load restores coins")
	eq(loaded.bag.size(), 1, "load restores the bag")
	eq(int(loaded.bag[0]["count"]), 2, "load restores the stack")
	eq(loaded.bank.size() >= 1, true, "load restores the bank")
	_clear_save()
	var opener = Progress.new()
	opener.grant({"coins": 0, "items": [{"item_id": "mystery_box", "rarity": "regular", "count": 1}]})
	var opened: Dictionary = opener.open_mystery_box(_rng(3))
	eq(bool(opened.get("ok", false)), true, "a box in the bag opens")
	var reward: Dictionary = opened["reward"]
	var things := (1 if int(reward.get("coins", 0)) > 0 else 0) + (reward["items"] as Array).size()
	eq(things, 1, "opening a box grants one thing")
	var again: Dictionary = opener.open_mystery_box(_rng(3))
	eq(bool(again.get("ok", false)), false, "the box is consumed")


func _test_window() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("kestrel")
	_give(hero, "kestrel_fledgling_head", "regular")
	hero.grant({"coins": 15, "items": [{"item_id": "mystery_box", "rarity": "regular", "count": 1}]})
	var window = load("res://scenes/world/ui/inventory_window.gd").new()
	get_root().add_child(window)
	window.setup(hero)
	window.refresh()
	eq(window._coins.text.find("Crypto Coins 15") >= 0, true, "the panel shows coins")
	eq(window._slots.get_child_count(), 8, "eight equipment slots")
	eq(window._bank.disabled, true, "the bank stays dark away from the Crossroads")
	eq(window._withdraw.disabled, true, "withdraw stays dark away from the banker")
	window.set_at_bank(true)
	eq(window._bank.disabled, false, "the bank lights at the banker")
	eq(window._withdraw.disabled, false, "withdraw lights at the banker")
	eq(window._filter != null and window._search != null, true, "filter and search are on the panel")
	eq(window.get_node_or_null("InventoryPanel/Card") != null, true, "the inventory card is built")
	window.show_category("special")
	eq(window._grid.get_child_count(), 1, "the box tab shows the Mystery Box")
	window.queue_free()
	var world := FileAccess.get_file_as_string("res://scenes/world/crosshaven/crosshaven_world.gd")
	eq(world.find("KEY_I") >= 0, true, "I opens the inventory")
	eq(world.find("\"wp14\"") >= 0, true, "the reward clip has a movie mode")


func _test_sources() -> void:
	var src := FileAccess.get_file_as_string("res://backend/pc_rewards.gd")
	eq(src.find("class_name") < 0, true, "rewards has no global class")
	eq(src.find("res://mobile") < 0, true, "rewards does not import mobile")
	var progress := FileAccess.get_file_as_string("res://backend/pc_progress.gd")
	eq(progress.find(str(5 * 10)) < 0, true, "progress does not hardcode the phase-1 cap")
	eq(progress.find("\"Ironjaw\"") < 0, true, "the hero class is not hardcoded")
	var window := FileAccess.get_file_as_string("res://scenes/world/ui/inventory_window.gd")
	eq(window.find("destroy_uid") >= 0, true, "destroy goes through progress")
	eq(window.find("withdraw_uid") >= 0, true, "withdraw goes through progress")
	eq(window.find("bag.remove_at") < 0, true, "the window does not edit the bag")
	var world := FileAccess.get_file_as_string("res://scenes/world/crosshaven/crosshaven_world.gd")
	eq(world.find("grant_turn_in") >= 0, true, "the mission turn-in hook is ready")
	eq(world.find("return absi") < 0, true, "the banker check keeps looking until the hero is beside one")


func _test_load_safety() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("kestrel")
	var kept := _give(hero, "sackcloth", "regular")
	var good := FileAccess.get_file_as_string(Progress.SAVE_PATH)
	var dup: Dictionary = JSON.parse_string(good)
	(dup["bag"] as Array).append((dup["bag"][0] as Dictionary).duplicate())
	_write_save(dup)
	eq(hero.load(), false, "a duplicate uid is rejected")
	eq(int(hero.bag[0]["uid"]), kept, "the rejected save leaves the bag")
	var unknown: Dictionary = JSON.parse_string(good)
	unknown["bag"][0]["item_id"] = "not_a_real_item"
	_write_save(unknown)
	eq(hero.load(), false, "an unknown item id is rejected")
	eq(str(hero.bag[0]["item_id"]), "sackcloth", "the unknown id is not applied")
	var low: Dictionary = JSON.parse_string(good)
	low["next_uid"] = 2
	low["bag"] = [
		{"uid": 4, "item_id": "sackcloth", "rarity": "regular", "count": 1, "upgrade": 0},
		{"uid": 9, "item_id": "mystery_box", "rarity": "regular", "count": 1, "upgrade": 0},
	]
	_write_save(low)
	var bumped = Progress.new()
	eq(bumped._uid, 10, "the next uid sits above the highest saved uid")
	var high: Dictionary = JSON.parse_string(good)
	high["next_uid"] = 12
	high["bag"] = [{"uid": 3, "item_id": "sackcloth", "rarity": "regular", "count": 1, "upgrade": 0}]
	_write_save(high)
	var kept_high = Progress.new()
	eq(kept_high._uid, 12, "a higher saved next uid is kept")
	_write_save({
		"level": 1, "xp": 0, "coins": 0, "hero_class": "Mender", "rare_choice": "", "next_uid": 3,
		"bag": [], "bank": [],
		"equipped": {
			"head": {"uid": 2, "item_id": "kestrel_fledgling_head", "rarity": "regular", "upgrade": 0, "seq": 1},
		},
	})
	var moved = Progress.new()
	eq(moved.equipped.has("head"), false, "another class's worn part leaves the slot")
	eq(moved.bag.size(), 1, "that part is put in the bag")
	eq(str(moved.bag[0]["item_id"]), "kestrel_fledgling_head", "the moved part keeps its id")
	_write_save({
		"level": 1, "xp": 0, "coins": 0, "hero_class": "Kestrel", "rare_choice": "", "next_uid": 3,
		"bag": [], "bank": [],
		"equipped": {
			"head": {"uid": 2, "item_id": "kestrel_windrunner_head", "rarity": "regular", "upgrade": 0, "seq": 1},
		},
	})
	var leveled = Progress.new()
	eq(leveled.equipped.has("head"), false, "a part above the hero's level leaves the slot")
	eq(str(leveled.bag[0]["item_id"]), "kestrel_windrunner_head", "the high part waits in the bag")
	_write_save({
		"level": 45, "xp": 0, "coins": 0, "hero_class": "Kestrel", "rare_choice": "", "next_uid": 4,
		"bag": [], "bank": [],
		"equipped": {
			"head": {"uid": 1, "item_id": "ember_crown", "rarity": "epic", "upgrade": 0, "seq": 1},
			"ring": {"uid": 2, "item_id": "gale_signet", "rarity": "epic", "upgrade": 0, "seq": 2},
		},
	})
	var epics = Progress.new()
	eq(epics.equipped.has("head"), true, "the first epic stays worn")
	eq(epics.equipped.has("ring"), false, "a second epic is not worn")
	eq(epics.bag.size(), 1, "the second epic is in the bag")
	_write_save({
		"level": epics.max_level, "xp": 0, "coins": 0, "hero_class": "Kestrel", "rare_choice": "", "next_uid": 4,
		"bag": [], "bank": [],
		"equipped": {
			"amulet": {"uid": 1, "item_id": "heart_of_the_elder", "rarity": "relic", "upgrade": 0, "seq": 1},
			"ring": {"uid": 2, "item_id": "blightroot_ring", "rarity": "relic", "upgrade": 0, "seq": 2},
		},
	})
	var relic_hero = Progress.new()
	eq(relic_hero.equipped.size(), 1, "only one relic stays worn")
	eq(relic_hero.bag.size(), 1, "the extra relic is in the bag")


func _test_bank_ring_destroy() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("kestrel")
	hero.grant({"coins": 0, "items": [{"item_id": "sackcloth", "rarity": "regular", "count": 2}]})
	var stack := int(hero.bag[0]["uid"])
	var destroyed: Dictionary = hero.destroy_uid(stack, 1)
	eq(bool(destroyed.get("ok", false)), true, "destroy removes one item")
	eq(int(hero.bag[0]["count"]), 1, "the rest of the stack stays")
	var again = Progress.new()
	eq(int(again.bag[0]["count"]), 1, "destroy autosaves")
	hero.bag_slots = 0
	var took := 0
	for _i in hero.bank_slots:
		var placed: Dictionary = hero.grant({
			"coins": 0,
			"items": [{"item_id": "plain_band", "rarity": "regular", "count": 1}],
		})
		if bool(placed.get("ok", false)):
			took += 1
	eq(took, hero.bank_slots, "the bank accepts one item per slot")
	var full: Dictionary = hero.grant({
		"coins": 0,
		"items": [{"item_id": "plain_band", "rarity": "regular", "count": 1}],
	})
	eq(bool(full.get("ok", false)), false, "a full bank refuses the deposit")
	eq(str(full.get("reason", "")), "The bank is full (%d slots)." % hero.bank_slots, "the refusal names the limit")
	eq(hero.bank.size(), hero.bank_slots, "the bank does not grow past its slots")
	_clear_save()
	var rings = Progress.new()
	var first := _give(rings, "plain_band", "regular")
	var second := _give(rings, "plain_band", "regular")
	var third := _give(rings, "plain_band", "regular")
	eq(bool(rings.equip_uid(first).get("ok", false)), true, "the first ring equips")
	eq(bool(rings.equip_uid(second).get("ok", false)), true, "the second ring fills the other slot")
	var swapped: Dictionary = rings.equip_uid(third)
	eq(bool(swapped.get("ok", false)), true, "a third ring swaps the older one")
	var back := false
	for entry in rings.bag:
		if int(entry.get("uid", -1)) == first:
			back = true
	eq(back, true, "the older ring returns to the bag")


func _test_caps() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("mender")
	hero.level = hero.max_level
	eq(hero.spend("Resist", hero.points_free()), true, "every point can go to Resist")
	var rate := float(hero.stat_per_point["Resist"]["damage_taken"])
	var cap := float(hero.stat_per_point["Resist"]["cap"])
	eq(float(hero.spent_in("Resist")) * rate > cap, true, "a full Resist spend is past the cap before clamping")
	var uid := _give(hero, "mender_dewdrop_head", "regular")
	eq(bool(hero.equip_uid(uid).get("ok", false)), true, "a Mender part equips")
	var view: Dictionary = hero.sheet_view()
	eq(float(view["resist"]) <= cap, true, "Resist from gear plus points stays at or under 33 percent")
	var caps: Dictionary = view["caps"]
	eq(int(caps["ap"]), 8, "the AP cap is 8")
	eq(int(caps["mp"]), 5, "the MP cap is 5")
	hero.sheet["ap"] = int(caps["ap"])
	eq(int(hero.sheet_view()["ap"]), int(caps["ap"]), "AP over 8 clamps")
	hero.sheet["mp"] = int(caps["mp"]) + 1
	eq(int(hero.sheet_view()["mp"]), int(caps["mp"]), "MP over 5 clamps")
	var closed: Dictionary = hero.sheet_view(true)
	eq(bool(closed["koliseo"]), true, "the koliseo flag is explicit")
	eq(int(closed["gear"]["stats"]["Resist"]), 0, "koliseo drops gear Resist")
	eq(int(closed["gear"]["stats"]["Vitality"]), 0, "koliseo drops gear Vitality")
	eq(int(view["gear"]["stats"]["Resist"]) + int(view["gear"]["stats"]["Vitality"]) > 0, true, "the open-world sheet keeps the part")
	_clear_save()
	var wearer = Progress.new()
	wearer.set_hero_class("kestrel")
	wearer.level = 45
	var epic_one: Dictionary = wearer.equip_uid(_give(wearer, "gale_signet", "epic"))
	eq(bool(epic_one.get("ok", false)), true, "the first epic equips")
	var epic_two: Dictionary = wearer.equip_uid(_give(wearer, "ember_crown", "epic"))
	eq(bool(epic_two.get("ok", false)), false, "a second epic is refused")
	eq(str(epic_two.get("reason", "")).find("epic") >= 0, true, "the refusal names the epic rule")
	wearer.level = wearer.max_level
	var relic_one: Dictionary = wearer.equip_uid(_give(wearer, "heart_of_the_elder", "relic"))
	eq(bool(relic_one.get("ok", false)), true, "the first relic equips")
	var relic_two: Dictionary = wearer.equip_uid(_give(wearer, "blightroot_ring", "relic"))
	eq(bool(relic_two.get("ok", false)), false, "a second relic is refused")
	eq(str(relic_two.get("reason", "")).find("relic") >= 0, true, "the refusal names the relic rule")


func _test_mender_sets(book) -> void:
	_clear_save()
	var hero = Progress.new()
	eq(hero.set_hero_class("mender"), true, "the hero can be a Mender")
	eq(hero.hero_class, "Mender", "Mender is stored as the display name")
	var hits := 0
	var parts := 0
	for i in 800:
		var drop: Dictionary = book.roll("mission", {
			"level": 15,
			"class_id": hero.hero_class,
			"zone_id": "rowanvale",
			"missions_finished": 30,
		}, _rng(3000 + i))
		for item in drop["items"]:
			var item_id := str(item["item_id"])
			if item_id == "mystery_box":
				continue
			var def: Dictionary = book.item(item_id)
			var classes: Array = def.get("classes", [])
			if classes.is_empty():
				continue
			parts += 1
			if classes.has(hero.hero_class):
				hits += 1
	eq(parts > 100, true, "rowanvale missions drop class parts")
	var rate := float(hits) / float(parts)
	eq(rate > 0.5 and rate < 0.7, true, "a Mender gets Mender sets near 60 percent (%.3f)" % rate)


func _test_turn_in() -> void:
	_clear_save()
	var world = load("res://scenes/world/crosshaven/crosshaven_world.tscn").instantiate()
	world.instant_transitions = true
	get_root().add_child(world)
	eq(world.progress != null, true, "the world boots a hero (%s)" % str(world.load_errors))
	if world.progress == null:
		world.queue_free()
		return
	world.progress.set_hero_class("mender")
	world.grant_turn_in({
		"coins": 17,
		"items": [{"item_id": "sackcloth", "rarity": "regular", "count": 1}],
	})
	eq(world.reward_popup.is_open(), true, "turn-in opens the reward popup")
	eq(world.progress.coins, 17, "turn-in pays the wallet")
	world.enter_zone("crosshaven_stoneford", Vector2i(3, 3), false)
	world.queue_free()
	var loaded = Progress.new()
	eq(loaded.coins, 17, "a zone change keeps the wallet without the test calling save")
	eq(loaded.hero_class, "Mender", "the reloaded hero is a Mender")
	eq(loaded.bag.size(), 1, "the turn-in item is still in the bag")


func _test_carry_limits() -> void:
	_clear_save()
	var hero = Progress.new()
	hero.set_hero_class("kestrel")
	hero.bag_slots = 1
	var band := _give(hero, "plain_band", "regular")
	eq(bool(hero.deposit_uid(band).get("ok", false)), true, "a ring deposits at the bank")
	eq(hero.bag.is_empty(), true, "the deposited ring leaves the bag")
	eq(hero.bank.size(), 1, "the bank holds the deposited ring")
	var bank_uid := int(hero.bank[0]["uid"])
	_give(hero, "plain_band", "regular")
	var blocked: Dictionary = hero.withdraw_uid(bank_uid, 1)
	eq(bool(blocked.get("ok", false)), false, "a full bag refuses a withdrawal")
	eq(str(blocked.get("reason", "")), "bag full", "withdraw says bag full")
	eq(hero.bank.size(), 1, "the refused ring stays in the bank")
	eq(int(hero.bank[0]["uid"]), bank_uid, "the bank uid is unchanged")
	hero.bag.clear()
	var back: Dictionary = hero.withdraw_uid(bank_uid, 1)
	eq(bool(back.get("ok", false)), true, "withdraw returns the ring")
	eq(int(back.get("count", 0)), 1, "withdraw moves one ring")
	eq(hero.bank.is_empty(), true, "the bank slot is free")
	eq(int(hero.bag[0]["uid"]), bank_uid, "withdraw keeps the same uid")
	var window = load("res://scenes/world/ui/inventory_window.gd").new()
	get_root().add_child(window)
	window.setup(hero)
	window.show_category("equipment")
	eq(window._withdraw.disabled, true, "the withdraw button is dark away from the banker")
	hero.deposit_uid(bank_uid)
	window.set_at_bank(true)
	eq(window._withdraw.disabled, false, "the withdraw button lights at the banker")
	eq(window._grid.get_child_count() >= 1, true, "the banker shows bank rows")
	eq(str(window._grid.get_child(0).text).find("Bank:") >= 0, true, "a bank row is labeled")
	window._selected = int(hero.bank[0]["uid"])
	window._withdraw_selected()
	eq(hero.bank.is_empty(), true, "the button withdraws the selected ring")
	eq(hero.bag.size(), 1, "the withdrawn ring is in the bag")
	window.queue_free()
	_clear_save()
	var opener = Progress.new()
	opener.set_hero_class("kestrel")
	opener.level = 12
	var item_seed := -1
	for n in 80:
		var roll: Dictionary = opener._catalog.open_box({"level": opener.level, "class_id": opener.hero_class}, _rng(n))
		if (roll.get("items", []) as Array).size() == 1:
			item_seed = n
			break
	eq(item_seed >= 0, true, "a seeded box grants a part")
	opener.bag_slots = 1
	opener.grant({"coins": 0, "items": [{"item_id": "mystery_box", "rarity": "regular", "count": 2}]})
	for _i in opener.bank_slots:
		opener.grant({"coins": 0, "items": [{"item_id": "plain_band", "rarity": "regular", "count": 1}]})
	eq(opener.bank.size(), opener.bank_slots, "the bank is full before the box opens")
	eq(int(opener.bag[0]["count"]), 2, "the box stack still holds two")
	var closed: Dictionary = opener.open_mystery_box(_rng(item_seed))
	eq(bool(closed.get("ok", false)), false, "a box with no room stays closed")
	eq(str(closed.get("reason", "")), "bag full", "the player sees bag full")
	eq(str(opener.bag[0]["item_id"]), "mystery_box", "the box is still in the bag")
	eq(int(opener.bag[0]["count"]), 2, "the box was not consumed")
	eq(opener.bank.size(), opener.bank_slots, "the full bank is unchanged")
	_clear_save()
	var wearer = Progress.new()
	wearer.set_hero_class("kestrel")
	wearer.bag_slots = 1
	var worn := _give(wearer, "kestrel_fledgling_head", "regular")
	eq(bool(wearer.equip_uid(worn).get("ok", false)), true, "a part equips before the bag is filled")
	var incoming := _give(wearer, "kestrel_fledgling_head", "regular")
	eq(wearer.bag.size(), wearer.bag_slots, "the bag is at its slot count")
	var off: Dictionary = wearer.unequip("head")
	eq(bool(off.get("ok", false)), false, "unequip refuses a full bag")
	eq(str(off.get("reason", "")), "bag full", "unequip says bag full")
	eq(wearer.equipped.has("head"), true, "the part stays worn")
	eq(wearer.bag.size(), wearer.bag_slots, "unequip does not push the bag")
	for entry in wearer.bag:
		if int(entry.get("uid", -1)) == incoming:
			entry["count"] = 2
	var swap: Dictionary = wearer.equip_uid(incoming)
	eq(bool(swap.get("ok", false)), false, "equip refuses when the worn part cannot return")
	eq(str(swap.get("reason", "")), "bag full", "the failed equip says bag full")
	eq(int(wearer.equipped["head"]["uid"]), worn, "the worn part stays")
	eq(wearer.bag.size(), wearer.bag_slots, "the failed equip leaves the bag size")
	var fresh = Progress.new()
	var slots := int(fresh.bag_slots)
	var bank_cap := int(fresh.bank_slots)
	_write_save({
		"level": 1, "xp": 0, "coins": 0, "hero_class": "Kestrel", "rare_choice": "",
		"bag": _rows(slots + 1, 1),
		"bank": [],
		"next_uid": slots + 3,
	})
	var moved = Progress.new()
	eq(moved.bag.size(), slots, "load keeps the bag at its slot count")
	eq(moved.bank.size(), 1, "the extra bag item moves to the bank")
	eq(str(moved.load_log).find("moved") >= 0, true, "the move is in the load log")
	eq(moved.bag.size() + moved.bank.size(), slots + 1, "the extra item is not deleted")
	_write_save({
		"level": 1, "xp": 0, "coins": 0, "hero_class": "Kestrel", "rare_choice": "",
		"bag": _rows(slots + 1, 1),
		"bank": _rows(bank_cap, 1000),
		"next_uid": 1000 + bank_cap + 2,
	})
	var kept = Progress.new()
	eq(kept.bag.size(), slots + 1, "a full bank leaves the extra bag item")
	eq(kept.bank.size(), bank_cap, "the full bank stays at its count")
	eq(str(kept.load_log).find("kept") >= 0, true, "the leftover is reported")
	eq(kept.bag.size() + kept.bank.size(), slots + 1 + bank_cap, "overflow is not deleted")
	_write_save({
		"level": 1, "xp": 0, "coins": 0, "hero_class": "Kestrel", "rare_choice": "",
		"bag": _rows(1, 1),
		"bank": _rows(bank_cap + 1, 1000),
		"next_uid": 1000 + bank_cap + 3,
	})
	var bank_over = Progress.new()
	eq(bank_over.bank.size(), bank_cap + 1, "a bank over its cap is kept")
	eq(bank_over.bag.size(), 1, "the bag item stays")
	eq(str(bank_over.load_log).find("bank over cap") >= 0, true, "the bank overflow is logged")


func _rows(n: int, start_uid: int) -> Array:
	var rows: Array = []
	for i in n:
		rows.append({
			"uid": start_uid + i,
			"item_id": "plain_band",
			"rarity": "regular",
			"count": 1,
			"upgrade": 0,
		})
	return rows


func _expect_stats(set_def: Dictionary, count: int) -> Dictionary:
	var stats := {"Mastery": 0, "Vitality": 0, "Swift": 0, "Resist": 0}
	var regular: Dictionary = set_def["stats"]["regular"]
	for stat in regular.keys():
		stats[str(stat)] = int(stats[str(stat)]) + int(regular[stat]) * count
	if count >= 2:
		_add_stats(stats, set_def["bonuses"]["2"])
	if count >= 3:
		_add_stats(stats, set_def["bonuses"]["3"])
	return stats


func _add_stats(stats: Dictionary, block: Dictionary) -> void:
	for stat in block.keys():
		var name := str(stat)
		stats[name] = int(stats.get(name, 0)) + int(block[stat])


func _set_total(set_def: Dictionary) -> int:
	return 5 * _sum(set_def["stats"]["regular"]) + _sum(set_def["bonuses"]["2"]) + _sum(set_def["bonuses"]["3"])


func _full_budget(tier: int) -> int:
	return int(round(98.0 * pow(1.3, (float(tier) - 50.0) / 10.0)))


func _write_save(doc: Dictionary) -> void:
	var file := FileAccess.open(Progress.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(doc))


func _give(hero, item_id: String, rarity: String) -> int:
	hero.grant({"coins": 0, "items": [{"item_id": item_id, "rarity": rarity, "count": 1}]})
	return int(hero.bag[hero.bag.size() - 1]["uid"])


func _sum(block: Dictionary) -> int:
	var total := 0
	for key in block.keys():
		total += int(block[key])
	return total


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


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
		print("FAIL %s (got %s, expected %s)" % [msg, str(actual), str(expected)])
	else:
		_passed += 1
