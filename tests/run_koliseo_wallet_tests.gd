extends SceneTree

## Koliseo economy: Blueprint §9 coins + Duskbrand stall, §15 trophies + shop.
## Run: godot --headless --path . -s res://tests/run_koliseo_wallet_tests.gd

const TEST_SAVE := "user://test_koliseo_wallet.json"
const TEST_BAG := "user://test_gear_bag_wallet.json"
const DAY := 86400
## Noon UTC on some day, so +/- a few hours stays inside it.
const T0 := 20000 * DAY + 43200

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	KoliseoWallet.save_path = TEST_SAVE
	GearBag.save_path = TEST_BAG
	_wipe()
	_test_daily_coins()
	_test_wallet_caps()
	_test_trophy_shop()
	_test_duskbrand_stall()
	_test_save_roundtrip()
	_test_net_payout()
	_test_hub_shop()
	_wipe()
	print("Koliseo wallet tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_daily_coins() -> void:
	var w := KoliseoWallet.new()
	eq(w.paid_wins_left(T0), 2, "a fresh day has 2 paid wins")
	var first := w.record_human_win(T0)
	eq(int(first["coins"]), 1, "first human win of the day pays 1 coin")
	eq(int(first["trophies"]), 1, "every human win pays 1 trophy")
	w.record_human_win(T0 + 60)
	eq(w.coins, 2, "second human win pays 1 coin")
	var third := w.record_human_win(T0 + 120)
	eq(int(third["coins"]), 0, "win 3+ pays 0 coins")
	eq(int(third["trophies"]), 1, "trophies have no daily cap")
	eq(w.coins, 2, "coins cap at 2 per UTC day")
	eq(w.trophies, 3, "3 wins = 3 trophies")
	eq(w.paid_wins_left(T0 + 180), 0, "no paid wins left today")
	eq(w.paid_wins_left(T0 + DAY), 2, "next UTC day resets the paid wins")
	var next_day := w.record_human_win(T0 + DAY)
	eq(int(next_day["coins"]), 1, "next UTC day pays again")
	eq(w.coins, 3, "coins carry over days")


func _test_wallet_caps() -> void:
	var w := KoliseoWallet.new()
	w.coins = KoliseoWallet.COIN_WALLET_MAX
	w.trophies = KoliseoWallet.TROPHY_WALLET_MAX
	var paid := w.record_human_win(T0)
	eq(int(paid["coins"]), 0, "a full coin wallet (120) drops the coin")
	eq(w.coins, 120, "coin wallet max 120")
	eq(w.trophies, 300, "trophy wallet max 300")
	eq(KoliseoWallet.DUSKBRAND_PART_COST, 60, "Duskbrand part costs 60 coins")


func _test_trophy_shop() -> void:
	var costs := {
		"food.hearth": 3, "food.stillwater": 5, "cos.frame.iron": 25,
		"cos.title.challenger": 40, "cos.tint.dusk": 80, "pet.mote": 150,
	}
	for sku in costs:
		eq(int(KoliseoWallet.SHOP[sku]["cost"]), int(costs[sku]), "%s costs %d trophies" % [sku, costs[sku]])
	eq(KoliseoWallet.SHOP.size(), 6, "shop has exactly the 6 Blueprint SKUs")
	for sku in KoliseoWallet.SHOP:
		var lower := str(sku).to_lower()
		var banned := lower.contains("duskbrand") or lower.begins_with("ap.") or lower.begins_with("mp.") or lower.begins_with("set.")
		eq(banned, false, "%s is not Duskbrand, AP, MP or a set part" % sku)
	var w := KoliseoWallet.new()
	w.trophies = 2
	eq(str(w.buy("food.hearth")["reason"]), "not_enough_trophies", "cannot buy without trophies")
	w.trophies = 10
	eq(bool(w.buy("food.hearth")["ok"]), true, "buy a hearth loaf")
	eq(bool(w.buy("food.hearth")["ok"]), true, "food can be bought again")
	eq(w.trophies, 4, "trophies spent 3 + 3")
	eq(int(w.owned["food.hearth"]), 2, "two loaves owned")
	w.trophies = 60
	eq(bool(w.buy("cos.frame.iron")["ok"]), true, "buy the iron frame")
	eq(str(w.buy("cos.frame.iron")["reason"]), "owned", "cosmetics are owned once")
	eq(w.trophies, 35, "second frame did not charge")
	eq(str(w.buy("nope")["reason"]), "unknown_sku", "unknown sku rejected")
	eq(w.coins, 0, "trophies never turn into coins")


func _test_duskbrand_stall() -> void:
	var w := KoliseoWallet.new()
	var bag := GearBag.new()
	w.coins = 59
	eq(str(w.buy_duskbrand("weapon", bag)["reason"]), "not_enough_coins", "59 coins cannot buy a part")
	w.coins = 120
	var bought := w.buy_duskbrand("weapon", bag)
	eq(bool(bought["ok"]), true, "60 coins buys a part")
	eq(str(bought["part"]["item_id"]), "duskbrand.weapon", "the stall sells Duskbrand parts")
	eq(int(bought["part"]["plus"]), 0, "the stall sells +0 parts")
	eq(bool(w.buy_duskbrand("weapon", bag)["ok"]), true, "duplicates allowed for fuse")
	eq(w.coins, 0, "two parts cost 120 coins")
	eq(bag.count_of("duskbrand.weapon"), 2, "two weapon parts land in the gear bag")
	eq(str(w.buy_duskbrand("cape", bag)["reason"]), "unknown_slot", "only the 5 slots")
	eq(KoliseoWallet.DUSKBRAND_SLOTS, ["weapon", "head", "chest", "legs", "boots"], "five gear slots")
	eq(w.trophies, 0, "coins never turn into trophies")


func _test_save_roundtrip() -> void:
	_wipe()
	var fresh := KoliseoWallet.load_saved()
	eq(fresh.coins + fresh.trophies, 0, "no save file = empty wallet")
	var w := KoliseoWallet.new()
	w.record_human_win(T0)
	w.trophies = 30
	w.buy("cos.frame.iron")
	w.coins = 60
	w.buy_duskbrand("boots", GearBag.new())
	truthy(w.save(), "wallet saves")
	var back := KoliseoWallet.load_saved()
	eq(back.to_dict(), w.to_dict(), "wallet reloads the same")
	var tampered := KoliseoWallet.new()
	tampered.from_dict({"coins": 999, "trophies": 999, "owned": {"ap.plus": 1}})
	eq(tampered.coins, 120, "loaded coins clamp to 120")
	eq(tampered.trophies, 300, "loaded trophies clamp to 300")
	eq(tampered.owned.size(), 0, "unknown skus dropped on load")


func _test_net_payout() -> void:
	_wipe()
	var net: Node = (load("res://backend/net_session.gd") as Script).new()
	# Hot-seat pays nothing.
	net._note_koliseo_result({"match_over": true, "winner_seat": 0})
	eq(KoliseoWallet.load_saved().trophies, 0, "hot-seat win pays nothing")
	net._note_koliseo_result({"match_over": false})
	# Online client, seat 1 wins.
	net.mode = net.Mode.CLIENT
	net.local_seat = 1
	net._note_koliseo_result({"match_over": true, "winner_seat": 1})
	var w := KoliseoWallet.load_saved()
	eq(w.coins, 1, "online win pays 1 coin")
	eq(w.trophies, 1, "online win pays 1 trophy")
	net._note_koliseo_result({"match_over": true, "winner_seat": 1})
	eq(KoliseoWallet.load_saved().trophies, 1, "the same finished match pays once")
	net._note_koliseo_result({"match_over": false})
	net._note_koliseo_result({"match_over": true, "winner_seat": 0})
	eq(KoliseoWallet.load_saved().trophies, 1, "a loss pays nothing")
	net.mode = net.Mode.DEDICATED
	net.local_seat = -1
	net._note_koliseo_result({"match_over": false})
	net._note_koliseo_result({"match_over": true, "winner_seat": 0})
	eq(KoliseoWallet.load_saved().trophies, 1, "the dedicated server pays nobody")
	net.free()
	var src := FileAccess.get_file_as_string("res://scenes/stasis_fight.gd")
	eq(src.contains("KoliseoWallet") or src.contains("record_human_win"), false, "Stasis never pays Koliseo coins")


func _test_hub_shop() -> void:
	_wipe()
	var w := KoliseoWallet.new()
	w.trophies = 10
	w.coins = 60
	w.save()
	var hub: Node = (load("res://scenes/mobile_hub.tscn") as PackedScene).instantiate()
	hub._auto_launch = false
	root.add_child(hub)
	var label := hub.find_child("WalletLabel", true, false) as Label
	truthy(label != null, "hub shows the wallet")
	eq(label.text, "Coins 60  ·  Trophies 10", "wallet label reads the save")
	var shop_button := hub.find_child("Shop", true, false) as Button
	truthy(shop_button != null, "hub has a Shop button")
	eq(shop_button.custom_minimum_size.y >= 48, true, "Shop hit target is at least 48px")
	eq(hub.door_count(), 6, "Shop is not a door")
	hub.open_shop()
	var shop := hub.find_child("KoliseoShop", true, false) as KoliseoShop
	truthy(shop != null, "Shop opens the overlay")
	eq(shop.sku_button("pet.mote").disabled, true, "pet is greyed at 10 trophies")
	eq(shop.sku_button("food.hearth").disabled, false, "loaf is buyable at 10 trophies")
	shop.buy_sku("food.hearth")
	eq(label.text, "Coins 60  ·  Trophies 7", "buying updates the hub wallet")
	shop.buy_duskbrand("head")
	eq(label.text, "Coins 0  ·  Trophies 7", "stall spends coins")
	eq(shop.slot_button("chest").disabled, true, "stall greys out at 0 coins")
	eq(GearBag.load_saved().count_of("duskbrand.head"), 1, "stall part saved in the gear bag")
	hub.free()


func _wipe() -> void:
	for path in [TEST_SAVE, TEST_BAG]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
