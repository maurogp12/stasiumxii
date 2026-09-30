extends RefCounted

## TEMPORARY balance-test kit (Mauro 30 Sep 2026: "for now give all character
## full sets with the maximum fusion and all the stills, i want to equip them
## fully and do koliseo in order to see the balance, note this as temporary
## once i say its good and go back to normal you shall remove all sets and put
## it as the regular game is designed").
##
## ACTIVE = true: the phone's gear bag holds every set piece (6 families × 5
## slots) at max fusion +5, the Still vault holds 99 fragments of every Still,
## and hot-seat Koliseo seats wear the equipped loadout (normal game: no gear
## in hot-seat). Granted pieces are tagged `test`; the grant is recorded so it
## is added once and can be taken back.
##
## TO GO BACK TO NORMAL (only when Mauro says so): set ACTIVE = false. On the
## next load every tagged piece is removed (and unequipped) and the granted
## fragments / forged test Still are taken back; hot-seat has no gear again.
## Then delete this file and its hooks (see docs/AGENT_HANDOFF.md).
const ACTIVE := true
const STILL_FRAGMENTS := 99
const DEFAULT_GEAR_PATH := "user://gear_bag.json"
const DEFAULT_STILL_PATH := "user://stills.json"


## Called by GearBag.load_saved on the real save only (tests use other paths).
static func sync_bag(bag) -> bool:
	if ACTIVE and not bag.test_grant:
		for fam in bag.FAMILY_ORDER:
			for slot in bag.SLOTS:
				var uid: int = bag.add_item(fam, slot, bag.PLUS_CAP)
				var index: int = bag.find(uid)
				if index != -1:
					bag.items[index]["test"] = true
		bag.test_grant = true
		return true
	if not ACTIVE and bag.test_grant:
		for slot in bag.equipped.keys():
			var index: int = bag.find(int(bag.equipped[slot]))
			if index != -1 and bool(bag.items[index].get("test", false)):
				bag.equipped.erase(slot)
		bag.items = bag.items.filter(func(it): return not bool(it.get("test", false)))
		bag.test_grant = false
		return true
	return false


## Called by StillVault.load_saved on the real save only.
static func sync_vault(vault) -> bool:
	if ACTIVE and vault.test_grant.is_empty():
		for id in vault.IDS:
			vault.fragments[id] = vault.count(id) + STILL_FRAGMENTS
			vault.test_grant[id] = STILL_FRAGMENTS
		return true
	if not ACTIVE and not vault.test_grant.is_empty():
		for id in vault.test_grant.keys():
			var left: int = vault.count(id) - int(vault.test_grant[id])
			if left > 0:
				vault.fragments[id] = left
			else:
				vault.fragments.erase(id)
		# A Still forged during the test came from granted fragments.
		vault.socket = ""
		vault.mode = "intact"
		vault.test_grant = {}
		return true
	return false
