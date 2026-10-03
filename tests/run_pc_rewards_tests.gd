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
	_run()
	_restore_save()
	print("pc rewards tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


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
	_test_sources()


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
		eq(budget, 4 + tier, "%s budget is 4 plus its tier" % str(set_def["id"]))
		if budgets.has(tier):
			eq(int(budgets[tier]), budget, "tier %d shares one budget" % tier)
		else:
			budgets[tier] = budget
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
	eq(dungeons.size(), 11, "eleven dungeon tables")
	var seen := {}
	for row in dungeons:
		var dungeon: Dictionary = row
		var set_id := str(dungeon["set_id"])
		eq(seen.has(set_id), false, "%s has its own set" % str(dungeon["id"]))
		seen[set_id] = true


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
	var extras := {"sackcloth": true, "granary_bread": true, "old_grain_barrel": true}
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
	var hero = Progress.new()
	eq(hero.hero_class, "Ironjaw", "the hero starts as Ironjaw")
	var blocked: Dictionary = hero.equip_uid(_give(hero, "kestrel_fledgling_head", "regular"))
	eq(bool(blocked.get("ok", false)), false, "another class's part stays in the bag")
	eq(str(blocked.get("reason", "")), "class", "the reason is the class")
	hero.hero_class = "Kestrel"
	var low: Dictionary = hero.equip_uid(_give(hero, "kestrel_windrunner_head", "regular"))
	eq(str(low.get("reason", "")), "level", "a higher tier cannot be worn yet")
	var slots := ["head", "cape", "belt", "boots", "amulet"]
	var uids: Array = []
	for slot in slots:
		uids.append(_give(hero, "kestrel_fledgling_%s" % slot, "regular"))
	hero.equip_uid(int(uids[0]))
	hero.equip_uid(int(uids[1]))
	var two: Dictionary = hero.gear_view()["stats"]
	eq(int(two["Mastery"]), 9, "two parts include the 2-part bonus")
	eq(int(two["Swift"]), 6, "two parts include the Swift bonus")
	hero.equip_uid(int(uids[2]))
	var three: Dictionary = hero.gear_view()["stats"]
	eq(int(three["Mastery"]), 16, "three parts include the 3-part bonus")
	eq(int(three["Swift"]), 12, "three parts include the Swift 3-part bonus")
	hero.equip_uid(int(uids[3]))
	hero.equip_uid(int(uids[4]))
	var five: Dictionary = hero.gear_view()
	eq(int(five["stats"]["Mastery"]), 22, "five parts add no further set bonus")
	eq(int(five["stats"]["Swift"]), 16, "five parts add no further Swift bonus")
	eq(bool(five["sets"][0]["five_applies"]), false, "the five-part line stays out of the stats")
	eq(hero.spent_in("Mastery"), 0, "gear does not spend characteristic points")
	eq(hero.spent_in("Swift"), 0, "gear does not spend Swift")
	_clear_save()
	var rare = Progress.new()
	rare.hero_class = "Ironjaw"
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
	mp_hero.hero_class = "Ironjaw"
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
	hero.hero_class = "Kestrel"
	_give(hero, "kestrel_fledgling_head", "regular")
	hero.grant({"coins": 15, "items": [{"item_id": "mystery_box", "rarity": "regular", "count": 1}]})
	var window = load("res://scenes/world/ui/inventory_window.gd").new()
	get_root().add_child(window)
	window.setup(hero)
	window.refresh()
	eq(window._coins.text.find("Crypto Coins 15") >= 0, true, "the panel shows coins")
	eq(window._slots.get_child_count(), 8, "eight equipment slots")
	eq(window._bank.disabled, true, "the bank stays dark away from the Crossroads")
	window.set_at_bank(true)
	eq(window._bank.disabled, false, "the bank lights at the banker")
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
