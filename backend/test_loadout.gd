extends RefCounted

## Balance-test kit (Mauro 30 Sep 2026). OFF for the gear rework.
## ACTIVE stays false: load_saved does not grant levels, gear, or Stills,
## and hot-seat fights get no kit loadout. The grant blocks below are dead
## while ACTIVE is false. They are not deleted yet because GearBag,
## StillVault, and HeroProgress still call sync_* on the real save paths.
##
## Turning the kit off does NOT copy test_backup back onto classes. That
## would undo the fresh start. ProgressEpoch (user://progress_epoch.json)
## is the one-time wipe to level 1 / empty bag / empty Stills. sync_* only
## strips a leftover test_grant so nothing re-grants tagged pieces.
## The Koliseo wallet was never written by this kit.
const ACTIVE := false
## TEMPORARY (Mauro 30 Sep 2026 follow-up). true = spend the 58 level-30
## points like tests/sim_duels.gd BUILDS. false = all 58 free, as in 0.1.80.
const SPEND_DUEL_BUILDS := true
const DUEL_BUILDS := {
	"kestrel": {"mastery": 40, "vitality": 16, "swift": 2},
	"gloam": {"mastery": 40, "vitality": 16, "swift": 2},
	"ironjaw": {"mastery": 34, "vitality": 22, "swift": 2},
	"mender": {"mastery": 24, "vitality": 32, "swift": 2},
	"bastion": {"mastery": 20, "vitality": 36, "swift": 2},
}
const STILL_FRAGMENTS := 99
const DEFAULT_GEAR_PATH := "user://gear_bag.json"
const DEFAULT_STILL_PATH := "user://stills.json"
const DEFAULT_HERO_PATH := "user://hero_progress.json"


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


## Called by HeroProgress.load_saved on the real save only.
static func sync_hero(hero) -> bool:
	if ACTIVE and not hero.test_grant:
		hero.test_backup = hero.classes.duplicate(true)
		for class_id in hero.GROWTH:
			var rec: Dictionary = hero.record(class_id)
			rec["level"] = hero.MAX_LEVEL
			rec["xp"] = 0
			rec["spent"] = DUEL_BUILDS[class_id].duplicate() if SPEND_DUEL_BUILDS else {}
		hero.test_grant = true
		return true
	# Do not restore test_backup. Epoch 1 already set the level floor, and
	# copying the backup would put the pre-kit levels back on the next load.
	if not ACTIVE and hero.test_grant:
		hero.test_backup = {}
		hero.test_grant = false
		return true
	return false
