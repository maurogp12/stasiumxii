class_name KoliseoWallet
extends RefCounted

## Koliseo economy. Blueprint §9 (Daily limits, LOCKED) and §15 (trophies, Soft Lock).
## Coins: the first 2 human Koliseo wins each UTC day pay 1 coin. Win 3+ = 0.
## Dummy = 0. Loss = 0. Wallet max 120. Coins cannot be bought.
## The Duskbrand stall is retired. buy_duskbrand does not spend coins.
## Trophies (id=kolitrophy): 1 per human Koliseo win, no daily cap, wallet 300.
## The trophy shop sells hub food and cosmetics only. Never Duskbrand, set parts,
## AP or MP. In-fight potions are parked. The pet is paint_only.
## A "human win" is an online match the local seat wins. Hot-seat and Stasis
## pay nothing (Mauro confirmed 29 Sep 2026: "Only online win pays").

const COINS_PER_WIN := 1
const PAID_WINS_PER_DAY := 2
const COIN_WALLET_MAX := 120
const TROPHIES_PER_WIN := 1
const TROPHY_WALLET_MAX := 300
const DUSKBRAND_PART_COST := 60
const DUSKBRAND_SLOTS: Array[String] = ["weapon", "head", "chest", "legs", "boots"]
const SECONDS_PER_DAY := 86400
## Room Tonic (consumable.room_tonic, Mauro 29 Sep 2026): 1 Koliseo coin in
## the hub shop, no trophy price, carry 3 (stacks). Drunk only in the Stasis
## intermission (Room A cleared, Room B not loaded): heal floor(30% max HP),
## no overheal. Never from chests; a wipe or leaving keeps unused tonics.
const TONIC_SKU := "consumable.room_tonic"
const TONIC_COST := 1
const TONIC_CARRY := 3
const TONIC_HEAL_PCT := 30

## Blueprint §15 SKU table. `once` = cosmetic or pet, owned at most once.
const SHOP := {
	"food.hearth": {"cost": 3, "name": "Hearth Loaf", "what": "Hub loaf. Out of fight HP.", "once": false},
	"food.stillwater": {"cost": 5, "name": "Stillwater Flask", "what": "Hub flask.", "once": false},
	"cos.frame.iron": {"cost": 25, "name": "Iron Frame", "what": "Portrait frame", "once": true},
	"cos.title.challenger": {"cost": 40, "name": "Challenger", "what": "Title", "once": true},
	"cos.tint.dusk": {"cost": 80, "name": "Dusk Tint", "what": "Tint only", "once": true},
	"pet.mote": {"cost": 150, "name": "Still-Mote", "what": "Still-Mote pet", "once": true},
}
const SHOP_ORDER: Array[String] = [
	"food.hearth", "food.stillwater", "cos.frame.iron",
	"cos.title.challenger", "cos.tint.dusk", "pet.mote",
]

static var save_path: String = "user://koliseo_wallet.json"

var coins: int = 0
var trophies: int = 0
## UTC day number (unix seconds / 86400) that `wins_today` counts.
var day: int = -1
var wins_today: int = 0
var total_wins: int = 0
## sku → count bought.
var owned: Dictionary = {}
## Room Tonics carried (0–3).
var tonics: int = 0


static func utc_day(unix_seconds: int) -> int:
	return int(floor(float(unix_seconds) / float(SECONDS_PER_DAY)))


static func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


static func load_saved() -> KoliseoWallet:
	# The epoch wipes hero / gear / Stills once. This wallet file is not part of that.
	ProgressEpoch.ensure()
	var wallet := KoliseoWallet.new()
	if not FileAccess.file_exists(save_path):
		return wallet
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return wallet
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		wallet.from_dict(parsed)
	return wallet


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"trophies": trophies,
		"day": day,
		"wins_today": wins_today,
		"total_wins": total_wins,
		"owned": owned.duplicate(true),
		"tonics": tonics,
	}


func from_dict(data: Dictionary) -> void:
	coins = clampi(int(data.get("coins", 0)), 0, COIN_WALLET_MAX)
	trophies = clampi(int(data.get("trophies", 0)), 0, TROPHY_WALLET_MAX)
	day = int(data.get("day", -1))
	wins_today = maxi(int(data.get("wins_today", 0)), 0)
	total_wins = maxi(int(data.get("total_wins", 0)), 0)
	tonics = clampi(int(data.get("tonics", 0)), 0, TONIC_CARRY)
	owned = {}
	var raw_owned: Variant = data.get("owned", {})
	if typeof(raw_owned) == TYPE_DICTIONARY:
		for sku in raw_owned:
			if SHOP.has(str(sku)):
				owned[str(sku)] = maxi(int(raw_owned[sku]), 0)


## Human Koliseo win. Coins only for the first 2 wins of the UTC day; a full
## wallet drops the coin. Trophies every win up to the 300 wallet.
func record_human_win(unix_seconds: int) -> Dictionary:
	_roll_day(unix_seconds)
	wins_today += 1
	total_wins += 1
	var coin_paid := 0
	if wins_today <= PAID_WINS_PER_DAY:
		coin_paid = mini(COINS_PER_WIN, COIN_WALLET_MAX - coins)
	coins += coin_paid
	var trophy_paid := mini(TROPHIES_PER_WIN, TROPHY_WALLET_MAX - trophies)
	trophies += trophy_paid
	return {"coins": coin_paid, "trophies": trophy_paid, "wins_today": wins_today}


## Paid wins left today (0–2).
func paid_wins_left(unix_seconds: int) -> int:
	if utc_day(unix_seconds) != day:
		return PAID_WINS_PER_DAY
	return maxi(PAID_WINS_PER_DAY - wins_today, 0)


func owns(sku: String) -> bool:
	return int(owned.get(sku, 0)) > 0


func can_buy(sku: String) -> Dictionary:
	if not SHOP.has(sku):
		return _fail("unknown_sku")
	var entry: Dictionary = SHOP[sku]
	if bool(entry.get("once", false)) and owns(sku):
		return _fail("owned")
	if trophies < int(entry["cost"]):
		return _fail("not_enough_trophies")
	return {"ok": true, "reason": ""}


func buy(sku: String) -> Dictionary:
	var gate := can_buy(sku)
	if not bool(gate["ok"]):
		return gate
	trophies -= int(SHOP[sku]["cost"])
	owned[sku] = int(owned.get(sku, 0)) + 1
	return {"ok": true, "reason": "", "sku": sku}


## Retired with the stall. Coins stay put and nothing is added to the bag.
func can_buy_duskbrand(_slot: String) -> Dictionary:
	return _fail("retired")


func buy_duskbrand(_slot: String, _bag: GearBag) -> Dictionary:
	return _fail("retired")


func can_buy_tonic() -> Dictionary:
	if tonics >= TONIC_CARRY:
		return _fail("tonic_full")
	if coins < TONIC_COST:
		return _fail("not_enough_coins")
	return {"ok": true, "reason": ""}


func buy_tonic() -> Dictionary:
	var gate := can_buy_tonic()
	if not bool(gate["ok"]):
		return gate
	coins -= TONIC_COST
	tonics += 1
	return {"ok": true, "reason": "", "tonics": tonics}


## Takes one tonic from the pack. The caller has already checked it is the
## Stasis intermission (stasis_fight.gd) and saves the wallet.
func use_tonic() -> bool:
	if tonics <= 0:
		return false
	tonics -= 1
	return true


func _roll_day(unix_seconds: int) -> void:
	var today := utc_day(unix_seconds)
	if today != day:
		day = today
		wins_today = 0


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
