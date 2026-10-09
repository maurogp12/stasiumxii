class_name ProgressEpoch
extends RefCounted

## One-shot fresh start for the gear rework (epoch 1).
## The first load of the real user:// saves, when user://progress_epoch.json
## is older than EPOCH, writes every class back to the level floor (1),
## 0 XP, no spent points, no element picks; an empty gear bag (loot-day
## counters kept and clamped); and an empty Still vault. The Koliseo wallet
## is not touched. The marker is written after that, so later loot, levels,
## and equipped sets stick.
##
## This is not a rule that the bag stays empty. The class-set ladder
## (Normal / Rare / Legendary per class, plus shared Ashmantle / Brightedge /
## Duskbrand), per-class loadouts, and gear crits write these same files
## after the marker is set.
##
## Tests redirect save_path, so ensure() does not run on their fixtures.
## reset_saves() always writes the current paths and is what tests call.

const EPOCH := 1
const MARKER_PATH := "user://progress_epoch.json"
const DEFAULT_HERO := "user://hero_progress.json"
const DEFAULT_GEAR := "user://gear_bag.json"
const DEFAULT_STILL := "user://stills.json"
const DEFAULT_WALLET := "user://koliseo_wallet.json"

static var marker_path: String = MARKER_PATH
## Game builds leave this true. Tests set it false to run ensure() against
## redirected save paths without touching the real user:// files.
static var enforce_real_paths: bool = true


static func saved_epoch() -> int:
	if not FileAccess.file_exists(marker_path):
		return 0
	var file := FileAccess.open(marker_path, FileAccess.READ)
	if file == null:
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int((parsed as Dictionary).get("progress_epoch", 0))


## True only when this process actually wiped the saves.
static func ensure() -> bool:
	if enforce_real_paths and not _real_paths():
		return false
	if saved_epoch() >= EPOCH:
		return false
	if not reset_saves():
		return false
	return _write_marker()


static func _real_paths() -> bool:
	return HeroProgress.save_path == DEFAULT_HERO \
		and GearBag.save_path == DEFAULT_GEAR \
		and StillVault.save_path == DEFAULT_STILL \
		and KoliseoWallet.save_path == DEFAULT_WALLET


## Wipes hero, gear, and Stills at whatever save_path they use now.
## Does not read or write the Koliseo wallet.
static func reset_saves() -> bool:
	var hero_ok := _write(HeroProgress.save_path, _fresh_hero())
	var bag_ok := _write(GearBag.save_path, _fresh_bag())
	var still_ok := _write(StillVault.save_path, _fresh_still())
	return hero_ok and bag_ok and still_ok


static func _fresh_hero() -> Dictionary:
	var classes := {}
	for class_id in HeroProgress.GROWTH:
		classes[str(class_id)] = {"xp": 0, "level": 1, "spent": {}}
	return {"classes": classes, "test_grant": false, "test_backup": {}}


static func _fresh_bag() -> Dictionary:
	var day := -1
	var clears := 0
	if FileAccess.file_exists(GearBag.save_path):
		var file := FileAccess.open(GearBag.save_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var data: Dictionary = parsed
				day = int(data.get("loot_day", -1))
				clears = int(data.get("loot_clears_today", 0))
	if day < -1:
		day = -1
	clears = clampi(clears, 0, GearBag.LOOT_CLEARS_PER_DAY)
	return {
		"items": [],
		"equipped": {},
		"attune": {},
		"next_uid": 1,
		"loot_day": day,
		"loot_clears_today": clears,
		"test_grant": false,
	}


static func _fresh_still() -> Dictionary:
	return {"fragments": {}, "socket": "", "mode": "intact", "test_grant": {}}


static func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


static func _write_marker() -> bool:
	return _write(marker_path, {"progress_epoch": EPOCH})
